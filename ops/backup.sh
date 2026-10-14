#!/usr/bin/env bash
# backup.sh — snapshot the private, non-git state of the platform into one archive.
#   Workspace Lite: SQLite DB (online backup) + secrets.env (needed to decrypt stored connector headers)
#   research/data:  holdings + generated outputs (gitignored)
#   ~/.openbb_platform: API keys, .env (secrets!)
# Output: ~/Backups/openbb-platform/openbb-platform-<stamp>.tar.gz (mode 600, dir 700), newest $KEEP kept.
# Restore Workspace: ops/run.sh down workspace; docker cp <db> openbb-workspace:/data/openbb.db (+ secrets.env); up.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${BACKUP_DIR:-$HOME/Backups/openbb-platform}"; KEEP="${KEEP:-14}"
export DOCKER_CONTEXT="${DOCKER_CONTEXT:-orbstack}"
umask 077; mkdir -p "$DEST"; chmod 700 "$DEST"
stamp=$(date +%Y%m%d-%H%M%S); tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/workspace"

if [ "$(docker inspect -f '{{.State.Running}}' openbb-workspace 2>/dev/null)" = true ]; then
  docker exec -u appuser openbb-workspace /opt/.venv/bin/python -c '
import sqlite3; s=sqlite3.connect("file:/data/openbb.db?mode=ro",uri=True); d=sqlite3.connect("/tmp/openbb-backup.db"); s.backup(d); d.close()'
  docker cp -q openbb-workspace:/tmp/openbb-backup.db "$tmp/workspace/openbb.db"
  docker cp -q openbb-workspace:/data/secrets.env "$tmp/workspace/secrets.env"
  docker exec openbb-workspace rm -f /tmp/openbb-backup.db
else
  echo "warn: workspace container not running; skipping its DB" >&2
fi
cp -R "$ROOT/research/data" "$tmp/research-data"
cp -R "$HOME/.openbb_platform" "$tmp/openbb_platform"

out="$DEST/openbb-platform-$stamp.tar.gz"
tar -czf "$out" -C "$tmp" .
chmod 600 "$out"
ls -1t "$DEST"/openbb-platform-*.tar.gz | tail -n +$((KEEP + 1)) | while read -r old; do rm -f "$old"; done
echo "backup: $out ($(du -h "$out" | cut -f1)); kept $(ls -1 "$DEST"/openbb-platform-*.tar.gz | wc -l | tr -d ' ')"
