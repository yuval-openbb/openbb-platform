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
| Research backend | http://127.0.0.1:7779 | research/.venv | API key header | E5 |
| Workspace Lite | http://127.0.0.1:3000 | Docker (OrbStack) | admin login | E6 |
| Community apps | :7801+ | apps/<app>/.venv | — | E7 |
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

## Troubleshooting
| Symptom | Fix |
|---|---|
| `openbb-api` exits at startup with `'NoneType' ... strip` in `cftc_router.py` | `make -C research patch` |
| `make health` shows 401 with auth | the API was started before the `.env` change; `make restart` |
| Claude Code `openbb` MCP not connected | `claude mcp get openbb`; the path must be `research/.venv/bin/openbb-mcp` |
