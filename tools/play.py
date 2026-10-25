#!/usr/bin/env python3
"""Play the game (or a study) in a window, on the Mac or Windows.

  python tools/play.py                                 # endless flight
  python tools/play.py -- --weight=heavy               # with launch flags
  python tools/play.py studies/flight_study.tscn -- --pack=lines

Finds Godot the way the harness does (tools/godot.py: $GODOT, the WinGet
install, C:\\Tools\\Godot, the Mac app), imports first if the checkout needs
it, then opens a Forward+ 1440x900 window with `--no-title` and no timeout.
On Windows, `run-endless-flight.cmd` wraps this (double-click, or
`.\\run-endless-flight.cmd --weight=heavy` from PowerShell).
"""
from __future__ import annotations
import subprocess
import sys

from godot import ROOT, find_godot, import_needed, run_import

DEFAULT_SCENE = "res://studies/endless_flight.tscn"


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    scene = DEFAULT_SCENE
    if argv and argv[0] != "--" and not argv[0].startswith("-"):
        scene = argv.pop(0)
        if not scene.startswith("res://"):
            scene = "res://" + scene.replace("\\", "/")
    if argv and argv[0] == "--":
        argv.pop(0)
    godot = find_godot()
    why = import_needed()
    if why:
        print(f"== importing first ({why})...")
        code = run_import(godot)
        if code != 0:
            return code
    args = [godot, "--path", str(ROOT), "--rendering-method", "forward_plus",
            "--windowed", "--resolution", "1440x900", scene, "--", "--no-title", *argv]
    print(f"== opening {scene}")
    return subprocess.call(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
