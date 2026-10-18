#!/usr/bin/env python3
"""The smoke check every round runs: each scene opened headless the way the
game opens it, 400 frames of its own loop, no script or engine errors.

  python tools/smoke.py studies/trap_yard.tscn
  python tools/smoke.py studies/motif_yard.tscn -- --motif=plumb_well
  python tools/smoke.py studies/greybox/*.tscn -j 4 --frames 600
  python tools/smoke.py --greybox                 # every greybox study

One line per scene, then its errors (the first few, with where):
  PASS studies/trap_yard.tscn  ready in 2 frames (3.1 s), 400 frames in 6.0 s, 0 errors
  FAIL studies/benchfall.tscn  12 errors
       SCRIPT ERROR: Invalid access to property 'motor' ...
          at: tick (res://studies/benchfall.gd:88)
Args after `--` are the scene's launch flags (each scene gets them).
Exit 0 when every scene passes. Full logs: --logs DIR. The import runs first
if it's needed (tools/godot.py).
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import glob
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot  # noqa: E402


def scene_path(s: str) -> str:
    s = s.replace("\\", "/")
    if s.startswith("res://"):
        return s[6:]
    root = str(godot.ROOT).replace("\\", "/") + "/"
    return s[len(root):] if s.startswith(root) else s


def result_line(output: str) -> dict:
    for line in reversed(output.splitlines()):
        if line.startswith("RESULT "):
            try:
                return json.loads(line[7:])
            except ValueError:
                return {}
    return {}


def smoke(scene: str, args: argparse.Namespace, scene_args: list[str]) -> tuple[bool, str, dict]:
    driver = ["-s", "res://tools/harness/smoke.gd", "--fixed-fps", "60", "--",
              f"--scene={scene}", f"--frames={args.frames}", f"--timeout={args.timeout}"]
    if scene_args:
        driver += ["--scene-args", *scene_args]
    r = godot.run(driver, timeout=args.timeout + 30, check_import=False)
    res = result_line(r["output"])
    errors = r["diag"]["errors"]
    fails = r["diag"]["assertion_failures"]
    ok = r["code"] == 0 and not errors and not fails and res.get("failures", 1) == 0
    if r["timed_out"] or "TIMEOUT" in r["output"]:
        head = f"timed out after {r['seconds']:.0f} s"
        ok = False
    elif res:
        ready = res.get("ready_frames", -1)
        head = (f"ready in {ready} frames ({res.get('ready_s')} s), " if res.get("walker") else "no walker, ") \
            + f"{args.frames} frames in {res.get('run_s')} s, {len(errors)} errors"
    else:
        head = f"exit {r['code']}, no result line, {len(errors)} errors"
    lines = [f"{'PASS' if ok else 'FAIL'} {scene}  {head}"]
    for f in fails[:args.show]:
        lines.append("     " + f)
    for e in errors[:args.show]:
        lines.append("     " + e.replace("\n", "\n     "))
    if len(errors) > args.show:
        lines.append(f"     ... {len(errors) - args.show} more errors (--show N, or --logs DIR)")
    if args.logs:
        out = Path(args.logs) / (scene.replace("/", "_") + ".log")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(r["output"], encoding="utf-8")
    return ok, "\n".join(lines), res


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    argv = sys.argv[1:]
    scene_args: list[str] = []
    if "--" in argv:
        i = argv.index("--")
        argv, scene_args = argv[:i], argv[i + 1:]
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("scenes", nargs="*", help="scene paths or globs (studies/x.tscn or res://...)")
    p.add_argument("--frames", type=int, default=400)
    p.add_argument("--timeout", type=int, default=240, help="seconds per scene")
    p.add_argument("-j", "--jobs", type=int, default=4)
    p.add_argument("--show", type=int, default=5, help="errors shown per scene")
    p.add_argument("--logs", help="write each scene's full log here")
    p.add_argument("--greybox", action="store_true", help="every studies/greybox/*.tscn but the hub")
    p.add_argument("--json", action="store_true", help="print the result lines as JSON too")
    args = p.parse_args(argv)
    scenes: list[str] = []
    for s in args.scenes:
        hits = sorted(glob.glob(s, root_dir=godot.ROOT)) if any(c in s for c in "*?[") else [s]
        scenes += [scene_path(h) for h in hits]
    if args.greybox:
        scenes += [scene_path(h) for h in sorted(glob.glob("studies/greybox/*.tscn", root_dir=godot.ROOT))
                   if not h.replace("\\", "/").endswith("/hub.tscn")]
    if not scenes:
        p.error("no scenes")
    missing = [s for s in scenes if not (godot.ROOT / s).is_file()]
    if missing:
        p.error("no such scene: " + ", ".join(missing))
    why = godot.import_needed()
    if why:
        print(f"== import needed: {why}", flush=True)
        godot.run_import(godot.find_godot())
    passed = 0
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        for ok, text, res in pool.map(lambda s: smoke(s, args, scene_args), scenes):
            passed += ok
            print(text, flush=True)
            if args.json:
                print(json.dumps(res))
    print(f"== smoke: {passed}/{len(scenes)} passed")
    return 0 if passed == len(scenes) else 1


if __name__ == "__main__":
    raise SystemExit(main())
