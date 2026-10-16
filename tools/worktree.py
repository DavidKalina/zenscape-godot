#!/usr/bin/env python3
"""Make a fresh worktree runnable: the git-ignored native kernels copied in,
named build caches with them, then the headless import (AGENTS.md, Fresh
worktrees).

  python tools/worktree.py setup <path>                        # kernels + import
  python tools/worktree.py setup <path> --cache toad_tex --cache toad_low
  python tools/worktree.py setup . --cache toad_tex --from ../lane-toad-body
  python tools/worktree.py check <path>                        # what it lacks, no changes

Copied from the main checkout (the first `git worktree list` entry), or
--from DIR:
  native/terrain_kernels/bin/  zenscape_kernels.gdextension  its .uid
  scratch/cache/<NAME>/ for each --cache NAME (a build's cached stages; a
  NAME with no stage there is looked for as scratch/<NAME> too, for the
  older loose caches like scratch/toad_tex/ or scratch/toad_low.blend);
  --cache all copies every stage.
Files already there and the same size and age are skipped. Then
`tools/godot.py --import` runs in <path> (--no-import skips it). Exits 1 if
anything asked for is missing at the source or the import fails.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

KERNELS = [
    "native/terrain_kernels/bin",
    "native/terrain_kernels/zenscape_kernels.gdextension",
    "native/terrain_kernels/zenscape_kernels.gdextension.uid",
]


def main_checkout(near: Path) -> Path:
    r = subprocess.run(["git", "-C", str(near), "worktree", "list", "--porcelain"],
                       capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.startswith("worktree "):
            return Path(line[len("worktree "):]).resolve()
    sys.exit("worktree.py: not in a git checkout (give --from)")


def _same(a: Path, b: Path) -> bool:
    if not b.exists():
        return False
    sa, sb = a.stat(), b.stat()
    return sa.st_size == sb.st_size and int(sa.st_mtime) == int(sb.st_mtime)


def copy(src: Path, dst: Path) -> tuple[int, int]:
    """(copied, skipped) files."""
    if src.resolve() == dst.resolve():
        return 0, 0
    if src.is_file():
        if _same(src, dst):
            return 0, 1
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        return 1, 0
    done = skipped = 0
    for f in src.rglob("*"):
        if f.is_file():
            c, s = copy(f, dst / f.relative_to(src))
            done += c
            skipped += s
    return done, skipped


def cache_source(src: Path, name: str) -> Path | None:
    for cand in (src / "scratch" / "cache" / name, src / "scratch" / name):
        if cand.exists():
            return cand
    return None


def wanted(src: Path, caches: list[str]) -> list[tuple[str, Path | None, str]]:
    """[(label, source or None, path relative to the checkout)]."""
    out = [(k, src / k if (src / k).exists() else None, k) for k in KERNELS]
    names = list(caches)
    if "all" in names:
        names.remove("all")
        root = src / "scratch" / "cache"
        names += sorted(p.name for p in root.iterdir() if p.is_dir()) if root.exists() else []
    for n in names:
        s = cache_source(src, n)
        rel = s.relative_to(src).as_posix() if s else f"scratch/cache/{n}"
        out.append((f"cache {n}", s, rel))
    return out


def run(cmd: str, path: Path, src: Path, caches: list[str], do_import: bool) -> int:
    if not (path / "project.godot").exists():
        print(f"worktree.py: {path} has no project.godot")
        return 1
    bad = 0
    for label, s, rel in wanted(src, caches):
        dst = path / rel
        if s is None:
            print(f"MISSING  {label}: not in {src}")
            bad += 1
            continue
        if cmd == "check":
            have = dst.exists()
            print(f"{'OK' if have else 'LACKS':8} {label}: {dst}")
            bad += 0 if have else 1
            continue
        c, k = copy(s, dst)
        print(f"COPIED   {label}: {c} file(s){f', {k} already there' if k else ''} -> {dst}")
    if cmd == "check":
        return 1 if bad else 0
    if do_import:
        print(f"== import in {path}", flush=True)
        r = subprocess.run([sys.executable, str(path / "tools" / "godot.py"), "--import"], cwd=path)
        if r.returncode != 0:
            print(f"FAIL import exited {r.returncode}")
            return 1
    print(f"== {path} ready" + (" (with missing pieces)" if bad else ""))
    return 1 if bad else 0


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("cmd", choices=["setup", "check"])
    p.add_argument("path")
    p.add_argument("--from", dest="src", help="the checkout to copy from (default: the main checkout)")
    p.add_argument("--cache", action="append", default=[], help="a scratch cache stage to copy (repeat; 'all')")
    p.add_argument("--no-import", action="store_true")
    a = p.parse_args(argv)
    path = Path(a.path).resolve()
    src = Path(a.src).resolve() if a.src else main_checkout(path if path.exists() else Path.cwd())
    print(f"== from {src}")
    return run(a.cmd, path, src, a.cache, not a.no_import)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
