#!/usr/bin/env bash
# agent.sh — what the login/15-min agent runs: bring services up (idempotent), then back up if the
# newest backup is older than 20h. Started via the "OpenBB Platform Agent" applet (see ops/launchd.sh).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
echo "--- $(date '+%F %T') agent"
"$ROOT/ops/run.sh" up | grep -v "already running" || true
newest=$(ls -1t "$HOME/Backups/openbb-platform"/openbb-platform-*.tar.gz 2>/dev/null | head -1)
if [ -z "$newest" ] || [ $(( $(date +%s) - $(stat -f %m "$newest") )) -gt 72000 ]; then
  "$ROOT/ops/backup.sh"
fi
