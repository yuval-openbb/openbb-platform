# CLAUDE.md — openbb-platform

Ops/wiring repo for Yuval's local OpenBB platform (GitHub `yuval-openbb/openbb-platform`, PRIVATE).
It contains **no data and no vendored code**. `research/`, `ecosystem/` and `apps/` are separate git repos
(listed in `repos.toml`, gitignored here). Read `docs/PLATFORM.md` first.

## Rules
- Everything binds to 127.0.0.1. Auth stays on for `openbb-api` and the research backend.
- Secrets live only in `~/.openbb_platform/.env` and `~/.openbb_platform/user_settings.json` (mode 600).
  Never print their values; `ops/.env.example` lists names only.
- Personal portfolio data lives only in `research/data/` (gitignored). Never copy it into this repo or a fork.
- Forks are public: never commit personal data to `ecosystem/` or `apps/`. Keep fork `main` == upstream;
  changes go on `yuval/<topic>` branches.
- Commit identity: `Yuval Hefetz <194224445+Yuvalhefetz44@users.noreply.github.com>` (local config).
  Yuval pushes himself. `gh repo create`, forks and transfers need his explicit yes.
- No paid API keys (Max subscription). Local LLMs run via Ollama.
- New service = a line in `ops/run.sh` + a check in `ops/health.sh` + a row in `docs/PLATFORM.md`.
- Run `make secrets` (gitleaks) before every commit.
