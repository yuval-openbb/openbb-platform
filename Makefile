# openbb-platform — one place to bootstrap, run and check the local OpenBB platform.
.PHONY: help bootstrap sync repos up down restart status health logs secrets backup agent-install agent-uninstall agent-status

help:
	@echo "make bootstrap   clone every repo in repos.toml (missing ones only)"
	@echo "make sync        fetch upstreams, fast-forward forks locally (never pushes)"
	@echo "make repos       branch / dirty / ahead-behind for each repo"
	@echo "make up | down | restart | status    services (ops/run.sh)"
	@echo "make health      functional checks for every service"
	@echo "make logs S=openbb-api"
	@echo "make secrets     gitleaks over this repo"
	@echo "make backup      snapshot Workspace DB + research/data + ~/.openbb_platform to ~/Backups"
	@echo "make agent-install | agent-uninstall | agent-status   start at login + self-heal every 15 min"

bootstrap: ; python3 ops/repos.py bootstrap
sync:      ; python3 ops/repos.py sync
repos:     ; python3 ops/repos.py status
up:        ; ops/run.sh up
down:      ; ops/run.sh down
restart:   ; ops/run.sh restart
status:    ; ops/run.sh status
health:    ; ops/health.sh
logs:      ; ops/run.sh logs $(S)
backup:          ; ops/backup.sh
agent-install:   ; ops/launchd.sh install
agent-uninstall: ; ops/launchd.sh uninstall
agent-status:    ; ops/launchd.sh status
secrets:
	gitleaks dir . --redact --no-banner
	gitleaks git . --redact --no-banner
