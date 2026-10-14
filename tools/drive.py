#!/usr/bin/env python3
"""Runs a driver (a script extending tools/harness/drive.gd), headless, and
prints what it reported: its check lines, ROW and RESULT lines, the errors,
and a summary. The rest of the log goes to --log or is dropped.

  python tools/drive.py scratch/gap_check.gd
  python tools/drive.py scratch/gap_check.gd -- --seed=2 --scene-args --shape=ring
  python tools/drive.py scratch/gap_check.gd --all       # the whole log
  python tools/drive.py scratch/gap_check.gd --rendered  # a window, for shot()

A script that doesn't parse fails in a second with its error (and a hint for
the untyped `:=` warning the project treats as an error). Exit: the driver's
(0 all checks passed, 1 a check failed, 2 its timeout), or 1 on errors.
Throwaway drivers go in scratch/ (git-ignored, Godot doesn't scan it).
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot  # noqa: E402


def res_path(script: str) -> str:
    s = script.replace("\\", "/")
    if s.startswith("res://"):
        return s
    p = Path(s).resolve()
    try:
        return "res://" + p.relative_to(godot.ROOT).as_posix()
    except ValueError:
        return p.as_posix()  # outside the project: by its own path


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    argv = sys.argv[1:]
    driver_args: list[str] = []
    if "--" in argv:
        i = argv.index("--")
        argv, driver_args = argv[:i], argv[i + 1:]
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("script")
    p.add_argument("--timeout", type=int, default=240, help="wall-clock seconds")
    p.add_argument("--rendered", action="store_true", help="a window (shots); one at a time")
    p.add_argument("--all", action="store_true", help="print the whole log (noise dropped)")
    p.add_argument("--log", help="write the full log here")
    p.add_argument("--no-fixed-fps", action="store_true", help="real time, not --fixed-fps 60")
    args = p.parse_args(argv)
    script = res_path(args.script)
    why = godot.import_needed()
    if why:
        print(f"== import needed: {why}", flush=True)
        godot.run_import(godot.find_godot())
    run_args = ["-s", script]
    if not args.no_fixed_fps:
        run_args += ["--fixed-fps", "60"]
    if args.rendered:
        run_args += ["--rendering-method", "forward_plus", "--windowed", "--resolution", "1440x900"]
    run_args += ["--", f"--timeout={args.timeout}", *driver_args]
    r = godot.run(run_args, rendered=args.rendered, timeout=args.timeout + 30, check_import=False)
    if args.log:
        Path(args.log).parent.mkdir(parents=True, exist_ok=True)
        Path(args.log).write_text(r["output"], encoding="utf-8")
    shown, dropped = godot.filtered(r["output"], only=not args.all)
    print("\n".join(shown))
    if "inferred from a Variant value" in r["output"] or "Cannot infer the type" in r["output"]:
        print("== hint: type it: `var x: T = ...` (or `var x: Variant = ...`), not `var x := ...`")
    print(godot.summary(r, dropped))
    return godot.status(r)


if __name__ == "__main__":
    raise SystemExit(main())
