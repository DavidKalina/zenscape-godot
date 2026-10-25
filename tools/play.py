#!/usr/bin/env python3
"""Play the game (or a study) in a window, on the Mac or Windows.

  python tools/play.py                                 # endless flight
  python tools/play.py -- --weight=heavy               # with launch flags
  python tools/play.py studies/flight_study.tscn -- --pack=lines

Finds Godot the way the harness does (tools/godot.py: $GODOT, the WinGet
install, C:\\Tools\\Godot, the Mac app), imports first, then opens a Forward+
1440x900 window with no timeout. Endless flight opens on its main menu
(pass `--no-title` to start in the air). The import runs on every
launch (about a second and a half when nothing changed), so shaders, models
and classes a merge brought in are never missing; `--no-import` skips it.
Godot's output is shown and kept in the temp folder
(zenscape-<scene>-launch.log); a run that printed script errors exits 1
even when Godot exits 0, and names the log. `run-endless-flight.command`
(Mac) and `run-endless-flight.cmd` (Windows) wrap this: double-click, or
add launch flags after them.
"""
from __future__ import annotations
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from godot import ROOT, find_godot, run_import

DEFAULT_SCENE = "res://studies/endless_flight.tscn"
# Godot can report script-load failures while returning a zero exit status.
FAILED = re.compile(r"SCRIPT ERROR:|ERROR: Failed to load")


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    do_import = True
    if argv and argv[0] == "--no-import":
        do_import = False
        argv.pop(0)
    scene = DEFAULT_SCENE
    if argv and argv[0] != "--" and not argv[0].startswith("-"):
        scene = argv.pop(0)
        if not scene.startswith("res://"):
            scene = "res://" + scene.replace("\\", "/")
    if argv and argv[0] == "--":
        argv.pop(0)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")  # a Windows console's code page
    godot = find_godot()
    if do_import:
        code = run_import(godot)
        if code != 0:
            print(f"== the import failed (exit {code})")
            return code
    log = Path(tempfile.gettempdir()) / f"zenscape-{Path(scene).stem.replace('_', '-')}-launch.log"
    args = [godot, "--path", str(ROOT), "--rendering-method", "forward_plus",
            "--windowed", "--resolution", "1440x900", scene, "--", *argv]
    print(f"== opening {scene} (launch log: {log})", flush=True)
    failed = False
    with open(log, "w", encoding="utf-8") as out:
        proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, encoding="utf-8", errors="replace")
        try:
            for line in proc.stdout:
                sys.stdout.write(line)
                sys.stdout.flush()
                out.write(line)
                failed = failed or bool(FAILED.search(line))
        except KeyboardInterrupt:
            pass
        code = proc.wait()
    if code == 0 and failed:
        code = 1
    if code != 0:
        print(f"== ZenScape stopped with an error (exit {code}). Launch log: {log}")
    return code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
