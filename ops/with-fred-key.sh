#!/usr/bin/env bash
# with-fred-key.sh <cmd...> — exec <cmd> with FRED_API_KEY taken from ~/.openbb_platform/user_settings.json
# (single source of truth for the key; never printed). Used by apps that read FRED_API_KEY from env.
FRED_API_KEY="$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.openbb_platform/user_settings.json")))["credentials"].get("fred_api_key") or "")')"
export FRED_API_KEY
exec "$@"
