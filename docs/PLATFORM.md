# OpenBB Platform — local setup

Everything runs on this Mac and binds to **127.0.0.1**. No paid API keys.
Repos: GitHub org [`yuval-openbb`](https://github.com/yuval-openbb). The manifest is `repos.toml`.

## Layout
```
~/Documents/openbb-platform/        this repo (yuval-openbb/openbb-platform, PRIVATE): ops/wiring only
  research/     yuval-openbb/openbb-research (PRIVATE): scripts, reports, research backend; .venv = THE ODP venv
  ecosystem/    public fork clones used as frameworks/reference
  apps/         public fork clones of community apps that run as services (own venv each)
  ops/          run.sh · health.sh · repos.py · .env.example
  .run/         pidfiles + logs (gitignored)
```

## Services
| Service | URL | Runs from | Auth | Status |
|---|---|---|---|---|
| ODP REST `openbb-api` | http://127.0.0.1:6900 (docs: `/docs`) | research/.venv | HTTP Basic (`OPENBB_API_USERNAME/PASSWORD`) | ✅ E3 |
| ODP MCP `openbb-mcp` | http://127.0.0.1:8001/mcp | research/.venv | loopback only | ✅ E4 |
| Claude Code `openbb` MCP | stdio (started by Claude Code) | research/.venv | — | ✅ E4 |
| Research backend (19 widgets) | http://127.0.0.1:7779 | research/.venv | `X-API-Key: $RESEARCH_BACKEND_API_KEY` | ✅ E5 |
| Workspace Lite | http://127.0.0.1:3000 | Docker (OrbStack), `ops/compose/workspace.yml`, image built from fork branch `yuval/lite-bun-build` | admin login (`docker --context orbstack exec openbb-workspace credentials`) | ✅ E6 |
| demo-risk (portfolio risk, Fama-French) | http://127.0.0.1:7801 | apps/demo-risk/.venv (py3.12) | — | ✅ E7 |
| dharmatech (Fed net liquidity, TGA, MTS) | http://127.0.0.1:7802 | apps/dharmatech-openbb/.venv (py3.11) | — (FRED key injected by `ops/with-fred-key.sh`) | ✅ E7 |
| opening-bell daily (market snapshot) | http://127.0.0.1:7803 | apps/opening-bell-daily-openbb/.venv (py3.12, openbb 4.7.2) | Workspace header `X-FRED-API-KEY` for the FRED widget | ✅ E7 |
| datamule indicators (SEC-derived) | http://127.0.0.1:7804 | apps/openbb-datamule-indicators/.venv (py3.12) | — | ✅ E7 |
| agent-rita / its MCP | :7777 / :8787 | ecosystem/agent-rita (bun) | — | E9 |
| Ollama | :11434 | Homebrew service | — | E9 |

Secrets: `~/.openbb_platform/.env` (API auth, Finnhub, Gmail) and `~/.openbb_platform/user_settings.json`
(FMP, FRED); both mode 600. `ops/.env.example` lists the variable names.

## Daily use
```bash
make up        # start all services
make status    # what's running
make health    # functional checks (auth enforced, data flows, loopback-only)
make logs S=openbb-api
make down
make -C research report     # regenerate the research report
```
In Claude Code, just ask for data ("use openbb: 10Y yield since September"); tool categories activate on demand.

## Add a service
1. Add one line to `SERVICES` in `ops/run.sh`: `name|port|working dir|command` (bind to 127.0.0.1).
2. Add a functional check to `ops/health.sh`.
3. Add a row to the table above.

## Add a repo
Fork it into `yuval-openbb`, add a `[[repo]]` block to `repos.toml`, run `make bootstrap`.
Keep the fork's `main` equal to upstream; put local changes on `yuval/<topic>` and pin that branch as `ref`.

## Maintenance
- `make sync` fast-forwards forks locally from upstream. Update the GitHub fork with `gh repo sync yuval-openbb/<name>`, or push it yourself.
- After rebuilding `research/.venv`, run `make -C research patch` (it re-applies the cftc fix).
- Never move a folder that contains a venv. Recreate the venv instead.
- OpenBB is pinned at 4.7.2. For the V5 path, see `research/docs/V5_MIGRATION.md`.

## Workspace: connect backends (once, in the browser)
Workspace → **Apps / Data Connectors → Connect backend**:
| Name | URL | Auth |
|---|---|---|
| OpenBB ODP | `http://127.0.0.1:6900` | Basic: `OPENBB_API_USERNAME` / `OPENBB_API_PASSWORD` (send as header `Authorization: Basic <base64 user:pass>` if no Basic option) |
| Yuval Research | `http://127.0.0.1:7779` | header `X-API-Key: <RESEARCH_BACKEND_API_KEY>` |
| Demo Risk | `http://127.0.0.1:7801` | none |
| Dharmatech | `http://127.0.0.1:7802` | none |
| Opening Bell | `http://127.0.0.1:7803` | header `X-FRED-API-KEY: <fred_api_key>` (from `user_settings.json`) |
| Datamule Indicators | `http://127.0.0.1:7804` | none |
The values are in `~/.openbb_platform/.env`. Workspace calls backends **from the browser** (verified: CORS preflights from `localhost:3000`), so `127.0.0.1` URLs are correct.
The Authorization value must include the scheme: `Basic <base64 of user:password>` (make it with `printf %s 'user:pass' | base64`; `echo` adds a newline).

Rebuild Workspace after upstream changes: `make sync`, rebase `yuval/lite-bun-build`, then rebuild (see `ops/compose/workspace.yml`).

## E7 app venvs (rebuild recipe)
Each app has its own venv (gitignored or listed in `.git/info/exclude`). Three apps run on fork branch `yuval/local-workspace` (CORS for localhost:3000).
```bash
cd apps/demo-risk                  && uv venv --python 3.12 .venv && uv pip install --python .venv/bin/python -e .
cd apps/dharmatech-openbb          && uv venv --python 3.11 .venv && uv pip install --python .venv/bin/python -r requirements.txt --override ../../ops/constraints/dharmatech-openbb.txt
cd apps/opening-bell-daily-openbb  && uv venv --python 3.12 .venv && uv pip install --python .venv/bin/python -r requirements.txt -c ../../research/requirements.lock
cd apps/openbb-datamule-indicators && uv venv --python 3.12 .venv && uv pip install --python .venv/bin/python -r requirements.txt
```
Dharmatech's first `transactions` call downloads Treasury data (about 5 min) and caches `*.pkl` in its folder.

## Troubleshooting
| Symptom | Fix |
|---|---|
| `openbb-api` exits at startup with `'NoneType' ... strip` in `cftc_router.py` | `make -C research patch` |
| `make health` shows 401 with auth | the API was started before the `.env` change; `make restart` |
| ODP widgets show "Not authenticated" but the connector test passes | the test only fetches the public `widgets.json`; the header value lacks `Basic ` |
| An app widget shows `'App' object has no attribute 'equity'` | the venv resolved openbb V5; rebuild with `-c ../../research/requirements.lock` |
| Workspace container `unhealthy` | the upstream healthcheck needs curl; use the compose file (it overrides the check) |
| `make up` doesn't start Workspace | OrbStack must be running (`orb start`); run.sh does this |
| Claude Code `openbb` MCP not connected | `claude mcp get openbb`; the path must be `research/.venv/bin/openbb-mcp` |
