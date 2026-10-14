#!/usr/bin/env bash
# run.sh — start/stop/status/logs for every local platform service (all bound to 127.0.0.1).
#   ops/run.sh up [svc...] | down [svc...] | restart [svc...] | status | logs <svc>
# Add a service: one line in SERVICES  ->  name|port|working dir|command
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$ROOT/.run"; mkdir -p "$RUN"
export DOCKER_CONTEXT="${DOCKER_CONTEXT:-orbstack}"   # Workspace runs on OrbStack
VENV="$ROOT/research/.venv/bin"

SERVICES=(
  "openbb-api|6900|$ROOT/research|$VENV/openbb-api --host 127.0.0.1 --port 6900"
  "openbb-mcp|8001|$ROOT/research|$VENV/openbb-mcp --host 127.0.0.1 --port 8001 --tool-discovery"
  "workspace|3000|$ROOT|compose:ops/compose/workspace.yml"
  "research-backend|7779|$ROOT/research|$VENV/uvicorn backends.yuval_research.main:app --host 127.0.0.1 --port 7779"
  # E7 community apps (own venv each; built per docs/PLATFORM.md)
  "demo-risk|7801|$ROOT/apps/demo-risk|.venv/bin/openbb-api --app demo_risk/app.py --host 127.0.0.1 --port 7801"
  "dharmatech|7802|$ROOT/apps/dharmatech-openbb|$ROOT/ops/with-fred-key.sh .venv/bin/uvicorn main:app --host 127.0.0.1 --port 7802"
  "opening-bell|7803|$ROOT/apps/opening-bell-daily-openbb|.venv/bin/uvicorn main:app --host 127.0.0.1 --port 7803"
  "datamule|7804|$ROOT/apps/openbb-datamule-indicators|.venv/bin/uvicorn main:app --host 127.0.0.1 --port 7804"
)

field() { echo "$1" | cut -d'|' -f"$2"; }
listening() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }
pid_of() { [ -f "$RUN/$1.pid" ] && cat "$RUN/$1.pid"; }
alive() { local p; p=$(pid_of "$1") && kill -0 "$p" 2>/dev/null; }
ctr_running() { [ "$(docker inspect -f '{{.State.Running}}' "openbb-$1" 2>/dev/null)" = true ]; }   # compose services: container openbb-<name>
selected() { local n=$1; shift; [ $# -eq 0 ] && return 0; for s in "$@"; do [ "$s" = "$n" ] && return 0; done; return 1; }

up() {
  for s in "${SERVICES[@]}"; do
    n=$(field "$s" 1); port=$(field "$s" 2); dir=$(field "$s" 3); cmd=$(field "$s" 4)
    selected "$n" "$@" || continue
    if [[ $cmd == compose:* ]]; then
      if ctr_running "$n"; then echo "  $n already running (:$port)"; continue; fi
      orb status 2>/dev/null | grep -q Running || orb start >/dev/null 2>&1
      (cd "$dir" && docker compose -f "${cmd#compose:}" up -d >"$RUN/$n.log" 2>&1)
    else
      if alive "$n" || listening "$port"; then echo "  $n already running (:$port)"; continue; fi
      (cd "$dir" && nohup $cmd >"$RUN/$n.log" 2>&1 & echo $! >"$RUN/$n.pid")
    fi
    for _ in $(seq 1 60); do listening "$port" && break; alive "$n" || break; sleep 1; done
    if listening "$port"; then echo "  $n up on 127.0.0.1:$port"; else echo "  $n FAILED (see: ops/run.sh logs $n)"; fi
  done
}

down() {
  for s in "${SERVICES[@]}"; do
    n=$(field "$s" 1); port=$(field "$s" 2); cmd=$(field "$s" 4); selected "$n" "$@" || continue
    if [[ $cmd == compose:* ]]; then
      (cd "$ROOT" && docker compose -f "${cmd#compose:}" stop >/dev/null 2>&1) && echo "  $n stopped"; continue
    fi
    stopped=""
    alive "$n" && kill "$(pid_of "$n")" 2>/dev/null && stopped=1
    # venv python is a launcher stub: the real server is a child holding the port.
    for p in $(lsof -t -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null); do
      ps -o args= -p "$p" | grep -q -E -- "$n|yuval_research|--port $port" && kill "$p" 2>/dev/null && stopped=1
    done
    for _ in $(seq 1 20); do listening "$port" || break; sleep 0.5; done
    rm -f "$RUN/$n.pid"
    if listening "$port"; then echo "  $n STILL on :$port (not ours?)"; elif [ -n "$stopped" ]; then echo "  $n stopped"; else echo "  $n not running"; fi
  done
}

status() {
  printf "  %-14s %-6s %-8s %s\n" SERVICE PORT STATE PID
  for s in "${SERVICES[@]}"; do
    n=$(field "$s" 1); port=$(field "$s" 2); cmd=$(field "$s" 4)
    state=down
    if [[ $cmd == compose:* ]]; then ctr_running "$n" && state=up; else listening "$port" && state=up; fi
    printf "  %-14s %-6s %-8s %s\n" "$n" "$port" "$state" "$(alive "$n" && pid_of "$n" || echo -)"
  done
}

case "${1:-status}" in
  up) shift; up "$@" ;;
  down) shift; down "$@" ;;
  restart) shift; down "$@"; up "$@" ;;
  status) status ;;
  logs) if [ "${2:-}" = workspace ]; then docker logs --tail 50 openbb-workspace; else tail -n 50 "$RUN/${2:?service name}.log"; fi ;;
  *) echo "usage: $0 up|down|restart [svc...] | status | logs <svc>"; exit 1 ;;
esac
