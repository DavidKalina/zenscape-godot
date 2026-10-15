#!/usr/bin/env python3
"""Rendered stills of a scene, to look at (Read the PNG) and judge by eye.
One Forward+ window, short, killed by a watchdog (AGENTS.md); a lock keeps it
to one window at a time across agents.

  python tools/shot.py studies/character_study.tscn                   # its own camera
  python tools/shot.py studies/character_study.tscn --frame walker --view three,top,close --sheet
  python tools/shot.py studies/kit_isle.tscn --at 0,30,60 --look 0,0,0 --out captures/shots/isle
  python tools/shot.py studies/character_study.tscn --place 0,1,4,180 --frame walker --view front,left
  python tools/shot.py studies/stun_yard.tscn --settle 300 -- --seed=2
  python tools/shot.py --sheet-of a.png b.png c.png --out captures/shots/sheet.png   # headless

Args after `--` are the scene's launch flags. Prints the files saved.
--frame PATTERN frames the meshes under nodes whose name, class or script
path contains it ("walker": him, "all": the scene; tools/harness/shot.gd).
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot  # noqa: E402

LOCK = godot.ROOT / ".godot" / "harness-window.lock"


def window_lock() -> None:
    LOCK.parent.mkdir(exist_ok=True)
    began = time.time()
    while True:
        try:
            fd = os.open(LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            return
        except FileExistsError:
            if time.time() - LOCK.stat().st_mtime > 300:
                LOCK.unlink(missing_ok=True)
                continue
            if time.time() - began > 600:
                sys.exit("another agent's window has held the lock for 10 minutes")
            if time.time() - began < 1:
                print("== waiting for another agent's window to close", flush=True)
            time.sleep(1)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    argv = sys.argv[1:]
    scene_args: list[str] = []
    if "--" in argv:
        i = argv.index("--")
        argv, scene_args = argv[:i], argv[i + 1:]
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("scene", nargs="?")
    p.add_argument("--out", help="file prefix (default captures/shots/<scene>)")
    p.add_argument("--at")
    p.add_argument("--look", default="0,0,0")
    p.add_argument("--frame")
    p.add_argument("--view", default="three")
    p.add_argument("--place")
    p.add_argument("--settle", type=int, default=150)
    p.add_argument("--fov", type=float, default=50)
    p.add_argument("--dist", type=float, default=1.0)
    p.add_argument("--sheet", action="store_true")
    p.add_argument("--hud", action="store_true")
    p.add_argument("--size", default="1440x900")
    p.add_argument("--timeout", type=int, default=150)
    p.add_argument("--sheet-of", nargs="+", metavar="PNG", help="just make a sheet of these")
    args = p.parse_args(argv)
    if args.sheet_of:
        out = args.out or "captures/shots/sheet.png"
        r = godot.run(["-s", "res://tools/harness/sheet.gd", "--",
                       "--in=" + ",".join(str(Path(f).resolve()) for f in args.sheet_of), f"--out={out}"])
        print("\n".join(godot.filtered(r["output"], only=True)[0]))
        return godot.status(r)
    if not args.scene:
        p.error("a scene, or --sheet-of")
    scene = args.scene.replace("\\", "/").removeprefix("res://")
    out = args.out or f"captures/shots/{Path(scene).stem}"
    driver = [f"--scene={scene}", f"--out={out}", f"--settle={args.settle}", f"--view={args.view}",
              f"--fov={args.fov}", f"--dist={args.dist}", f"--timeout={args.timeout}", f"--size={args.size}"]
    if args.at:
        driver += [f"--at={args.at}", f"--look={args.look}"]
    if args.frame:
        driver.append(f"--frame={args.frame}")
    if args.place:
        driver.append(f"--place={args.place}")
    if args.sheet:
        driver.append("--sheet")
    if args.hud:
        driver.append("--hud")
    if scene_args:
        driver += ["--scene-args", *scene_args]
    why = godot.import_needed()
    if why:
        print(f"== import needed: {why}", flush=True)
        godot.run_import(godot.find_godot())
    window_lock()
    try:
        r = godot.run(["-s", "res://tools/harness/shot.gd", "--rendering-method", "forward_plus",
                       "--windowed", "--resolution", args.size, "--", *driver],
                      rendered=True, timeout=args.timeout + 30, check_import=False)
    finally:
        LOCK.unlink(missing_ok=True)
    shown, dropped = godot.filtered(r["output"], only=True)
    print("\n".join(shown))
    print(godot.summary(r, dropped))
    return godot.status(r)


if __name__ == "__main__":
    raise SystemExit(main())
