# openbb-platform

Wiring for a fully local OpenBB research platform: Open Data Platform API + MCP, a private research
backend, a self-hosted Workspace, community apps, and a local agent. All on 127.0.0.1.

```bash
git clone https://github.com/yuval-openbb/openbb-platform.git ~/Documents/openbb-platform
cd ~/Documents/openbb-platform
make bootstrap                      # clones research/, ecosystem/, apps/ from repos.toml
cd research && uv venv .venv --python 3.14 && uv pip install --python .venv/bin/python -r requirements.lock && make patch && cd ..
make up && make health
```
See [docs/PLATFORM.md](docs/PLATFORM.md).
