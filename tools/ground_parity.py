#!/usr/bin/env python3
"""The native ground layers against their GDScript, bit for bit: the ground
composite's broad phase (ZenScapeGround, scripts/endless/ground_native.gd)
and the trees' flight solid (ZenScapeTreeSolid, land_trees.gd).

  python tools/ground_parity.py                  # both checks (~9 min)
  python tools/ground_parity.py --only trees     # one (trees ~1 min, ground ~8)
  python tools/ground_parity.py --break          # the control: must FAIL
  python tools/ground_parity.py -- --seed=1      # args after -- go to the scene

Runs tools/harness/ground_parity.gd headless through tools/drive.py, one
Godot per check, and prints each check's points and mismatches. Exit 0 when
every check ran and found 0 mismatches, else 1 (so --break exits 1; it
exits 3 if the control found nothing, i.e. the check doesn't bite). Run it after touching a
ground owner's ground / inside / land_y or what it publishes (arches, rocks,
the Peak's towers and stair, the ice tunnel), or the tree solid. It needs the
native library built and current; without it the checks FAIL, saying so.
Longer than a tool call allows? `python tools/bg.py start gp -- python tools/ground_parity.py`.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
DRIVER = "tools/harness/ground_parity.gd"
CHECKS = {"ground": 900, "trees": 300}
LINE = re.compile(r"GROUND_PARITY (\w+) points (\d+) mismatches (\d+)\s*(.*)")


def run(check: str, broken: bool, scene_args: list[str], timeout: int) -> tuple[int, int | None, str]:
    """(points, mismatches or None when the check didn't finish, the log)."""
    cmd = [sys.executable, str(HERE / "drive.py"), DRIVER, "--timeout", str(timeout), "--", f"--check={check}"]
    if broken:
        cmd.append("--break")
    if scene_args:
        cmd += ["--scene-args", *scene_args]
    r = subprocess.run(cmd, cwd=HERE.parent, capture_output=True, text=True)
    out = r.stdout + r.stderr
    for line in out.splitlines():
        m = LINE.search(line)
        if m and m.group(1) == check:
            return int(m.group(2)), int(m.group(3)), m.group(4).strip()
    return 0, None, out


def main(argv: list[str]) -> int:
    scene_args: list[str] = []
    if "--" in argv:
        i = argv.index("--")
        argv, scene_args = argv[:i], argv[i + 1:]
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--only", choices=sorted(CHECKS), action="append", help="run just this check (repeatable)")
    p.add_argument("--break", dest="broken", action="store_true",
                   help="the control: unpublish part of each native side, so every check must FAIL")
    args = p.parse_args(argv)
    ok = True
    for check in args.only or list(CHECKS):
        points, bad, detail = run(check, args.broken, scene_args, CHECKS[check])
        if bad is None:
            ok = False
            print(f"FAIL {check}: no result line; the driver's output:")
            print(detail.rstrip())
            continue
        verdict = "PASS" if bad == 0 and points > 0 else "FAIL"
        ok = ok and verdict == "PASS"
        print(f"{verdict} {check}: points {points} mismatches {bad}  ({detail})")
    if args.broken:
        print("control (--break): " + ("FAILED as it should" if not ok else "PASSED, so the check doesn't bite (exit 3)"))
        return 1 if not ok else 3
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
