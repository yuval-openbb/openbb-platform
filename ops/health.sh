#!/usr/bin/env bash
# health.sh — functional checks (not just "port open") for every platform service.
# Credentials are read from ~/.openbb_platform/.env and never printed.
set -uo pipefail
ENV_FILE="$HOME/.openbb_platform/.env"
[ -f "$ENV_FILE" ] && { set -a; . "$ENV_FILE"; set +a; }
AUTH="${OPENBB_API_USERNAME:-}:${OPENBB_API_PASSWORD:-}"
fail=0

check() {  # name  expected_code  curl-args...
  local name=$1 want=$2; shift 2
  local got; got=$(curl -s -o /dev/null -m 15 -w '%{http_code}' "$@")
  if [ "$got" = "$want" ]; then printf "  ✅ %-34s %s\n" "$name" "$got"; else printf "  ❌ %-34s got %s, want %s\n" "$name" "$got" "$want"; fail=1; fi
}

echo "openbb-api :6900"
check "widgets.json"                    200 http://127.0.0.1:6900/widgets.json
check "data route rejects no-auth"      401 "http://127.0.0.1:6900/api/v1/economy/fred_series?symbol=DGS10&provider=fred"
check "data route with auth (FRED)"     200 -u "$AUTH" "http://127.0.0.1:6900/api/v1/economy/fred_series?symbol=DGS10&provider=fred&start_date=$(date -v-14d +%F)"

echo "openbb-mcp :8001"
check "MCP initialize"                  200 -X POST http://127.0.0.1:8001/mcp \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"health","version":"0"}}}'

echo "bind check (nothing on 0.0.0.0 / *)"
exposed=$(lsof -nP -iTCP:6900,8001,7779,3000,7777,8787,7801,7802 -sTCP:LISTEN 2>/dev/null | awk 'NR>1 && $9 !~ /^(127\.0\.0\.1|\[::1\]|localhost):/ {print $1" "$9}')
if [ -z "$exposed" ]; then echo "  ✅ all listeners are loopback-only"; else echo "  ❌ exposed: $exposed"; fail=1; fi

exit $fail
