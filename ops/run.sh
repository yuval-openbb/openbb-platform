#!/usr/bin/env bash
# run.sh — start/stop/status/logs for every local platform service (all bound to 127.0.0.1).
#   ops/run.sh up [svc...] | down [svc...] | restart [svc...] | status | logs <svc>
# Add a service: one line in SERVICES  ->  name|port|working dir|command
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$ROOT/.run"; mkdir -p "$RUN"
VENV="$ROOT/research/.venv/bin"

SERVICES=(
  "openbb-api|6900|$ROOT/research|$VENV/openbb-api --host 127.0.0.1 --port 6900"
  "openbb-mcp|8001|$ROOT/research|$VENV/openbb-mcp --host 127.0.0.1 --port 8001 --tool-discovery"
)

field() { echo "$1" | cut -d'|' -f"$2"; }
listening() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }
pid_of() { [ -f "$RUN/$1.pid" ] && cat "$RUN/$1.pid"; }
alive() { local p; p=$(pid_of "$1") && kill -0 "$p" 2>/dev/null; }
selected() { local n=$1; shift; [ $# -eq 0 ] && return 0; for s in "$@"; do [ "$s" = "$n" ] && return 0; done; return 1; }

up() {
  for s in "${SERVICES[@]}"; do
    n=$(field "$s" 1); port=$(field "$s" 2); dir=$(field "$s" 3); cmd=$(field "$s" 4)
    selected "$n" "$@" || continue
    if alive "$n" || listening "$port"; then echo "  $n already running (:$port)"; continue; fi
    (cd "$dir" && nohup $cmd >"$RUN/$n.log" 2>&1 & echo $! >"$RUN/$n.pid")
    for _ in $(seq 1 60); do listening "$port" && break; alive "$n" || break; sleep 1; done
    if listening "$port"; then echo "  $n up on 127.0.0.1:$port"; else echo "  $n FAILED (see: ops/run.sh logs $n)"; fi
  done
}

down() {
  for s in "${SERVICES[@]}"; do
    n=$(field "$s" 1); port=$(field "$s" 2); selected "$n" "$@" || continue
    stopped=""
    alive "$n" && kill "$(pid_of "$n")" 2>/dev/null && stopped=1
    # venv python is a launcher stub: the real server is a child holding the port.
    for p in $(lsof -t -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null); do
      ps -o args= -p "$p" | grep -q -- "$n" && kill "$p" 2>/dev/null && stopped=1
    done
    for _ in $(seq 1 20); do listening "$port" || break; sleep 0.5; done
    rm -f "$RUN/$n.pid"
    if listening "$port"; then echo "  $n STILL on :$port (not ours?)"; elif [ -n "$stopped" ]; then echo "  $n stopped"; else echo "  $n not running"; fi
  done
}

status() {
  printf "  %-14s %-6s %-8s %s\n" SERVICE PORT STATE PID
  for s in "${SERVICES[@]}"; do
    n=$(field "$s" 1); port=$(field "$s" 2)
    state=down; listening "$port" && state=up
    printf "  %-14s %-6s %-8s %s\n" "$n" "$port" "$state" "$(alive "$n" && pid_of "$n" || echo -)"
  done
}

case "${1:-status}" in
  up) shift; up "$@" ;;
  down) shift; down "$@" ;;
  restart) shift; down "$@"; up "$@" ;;
  status) status ;;
  logs) tail -n 50 "$RUN/${2:?service name}.log" ;;
  *) echo "usage: $0 up|down|restart [svc...] | status | logs <svc>"; exit 1 ;;
esac
