#!/usr/bin/env python3
"""repos.py — clone / sync / inspect the repos listed in repos.toml.

  python3 ops/repos.py bootstrap   clone missing repos (+ `upstream` remote, local commit identity)
  python3 ops/repos.py sync        fetch upstream; fast-forward local `ref` when possible (never pushes)
  python3 ops/repos.py status      branch, dirty state, ahead/behind upstream for each repo
"""
from __future__ import annotations

import subprocess
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME, EMAIL = "Yuval Hefetz", "194224445+Yuvalhefetz44@users.noreply.github.com"


def git(path: Path, *args: str, check: bool = True) -> str:
    r = subprocess.run(["git", "-C", str(path), *args], capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"git {' '.join(args)} in {path}: {r.stderr.strip()}")
    return r.stdout.strip()


def repos() -> list[dict]:
    with (ROOT / "repos.toml").open("rb") as f:
        return [r for r in tomllib.load(f)["repo"] if r.get("clone", True)]


def bootstrap() -> None:
    for r in repos():
        p = ROOT / r["path"]
        if (p / ".git").exists():
            print(f"ok      {r['path']}")
            continue
        p.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "clone", "-q", "-b", r["ref"], r["origin"], str(p)], check=True)
        if r.get("upstream"):
            git(p, "remote", "add", "upstream", r["upstream"])
        git(p, "config", "user.name", NAME)
        git(p, "config", "user.email", EMAIL)
        print(f"cloned  {r['path']}")


def sync() -> None:
    for r in repos():
        p = ROOT / r["path"]
        if not r.get("upstream") or not (p / ".git").exists():
            continue
        git(p, "fetch", "-q", "upstream")
        up = f"upstream/{r['ref']}"
        behind = git(p, "rev-list", "--count", f"{r['ref']}..{up}", check=False) or "?"
        if behind in ("0", "?"):
            print(f"current {r['path']}")
            continue
        if git(p, "symbolic-ref", "--short", "HEAD") == r["ref"] and not git(p, "status", "--porcelain"):
            git(p, "merge", "-q", "--ff-only", up)
            print(f"ff +{behind:<4} {r['path']}  (fork on GitHub: `gh repo sync` or push yourself)")
        else:
            print(f"behind {behind} {r['path']}  (not on {r['ref']} or dirty; skipped)")


def status() -> None:
    for r in repos():
        p = ROOT / r["path"]
        if not (p / ".git").exists():
            print(f"{r['path']:<32} MISSING (run make bootstrap)")
            continue
        branch = git(p, "symbolic-ref", "--short", "HEAD", check=False)
        dirty = "dirty" if git(p, "status", "--porcelain") else "clean"
        ab = ""
        if r.get("upstream") and git(p, "rev-parse", "-q", "--verify", f"upstream/{r['ref']}", check=False):
            ab = git(p, "rev-list", "--left-right", "--count", f"{r['ref']}...upstream/{r['ref']}", check=False)
            ab = "ahead/behind upstream " + ab.replace("\t", "/")
        print(f"{r['path']:<32} {branch:<10} {dirty:<6} {ab}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    {"bootstrap": bootstrap, "sync": sync, "status": status}.get(cmd, status)()
