#!/usr/bin/env python3
"""Play the game (or a study) in a window, on the Mac or Windows.

  python tools/play.py                                 # endless flight
  python tools/play.py -- --weight=heavy               # with launch flags
  python tools/play.py studies/flight_study.tscn -- --pack=lines
  python tools/play.py --editor                        # the Godot editor on the project

First brings main up to date: in a checkout on main it pulls origin's main,
fast-forward only, and says what came in; when it can't (offline, local
changes in the way, a diverged main) it says why and plays what is here.
Another branch (an agent's worktree) is never pulled. `--no-pull` skips it.
Then it warns when the native terrain kernels are older than the C++ here
(tools/native_stamp.py: a pull brings new C++, never a new build).
Finds Godot the way the harness does (tools/godot.py: $GODOT, the WinGet
install, C:\\Tools\\Godot, the Mac app), imports first, then opens a Forward+
1440x900 window with no timeout (`--editor`: the editor instead, which
imports on its own, left running). Endless flight opens on its main menu
(pass `--no-title` to start in the air). The import runs on every
launch (about a second and a half when nothing changed), so shaders, models
and classes a merge brought in are never missing; `--no-import` skips it.
Godot's output is shown and kept in the temp folder
(zenscape-<scene>-launch.log); a run that printed script errors exits 1
even when Godot exits 0, and names the log. `run-endless-flight.command`
(Mac) and `run-endless-flight.cmd` (Windows) wrap this: double-click, or
add launch flags after them; `open-godot.command` / `open-godot.cmd` wrap
`--editor`.
"""
from __future__ import annotations
from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile

from godot import ROOT, find_godot, run_import
import native_stamp

DEFAULT_SCENE = "res://studies/endless_flight.tscn"
# Godot can report script-load failures while returning a zero exit status.
FAILED = re.compile(r"SCRIPT ERROR:|ERROR: Failed to load")


def _git(*args: str, timeout: float = 60.0) -> subprocess.CompletedProcess:
    # No credential prompt can hang a double-clicked launcher.
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0")
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=timeout, env=env)


def _restat_unchanged() -> None:
    """Re-records files git only thinks changed, so they never block the pull.

    On Windows git checks text files out with CRLF and Godot rewrites its own
    (.import, .uid) with LF. The content still matches the commit, but the size
    git recorded doesn't, and git then calls the file modified without looking
    (`update-index --refresh` can't clear it). `git add` on such a file stages
    nothing; it only re-records its size."""
    stat_dirty = set(_git("ls-files", "-m", "-z").stdout.split("\0")) - {""}
    if not stat_dirty:
        return
    changed = set(_git("diff", "--name-only", "-z").stdout.split("\0"))
    same = sorted(stat_dirty - changed)
    if same:
        _git("-c", "core.safecrlf=false", "add", "--", *same)


def pull_main() -> None:
    """Fast-forwards a checkout on main to origin's main; says what happened."""
    try:
        branch = _git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
        if branch != "main":
            print(f"== on branch {branch}, not main: not pulling", flush=True)
            return
        before = _git("rev-parse", "HEAD").stdout.strip()
        _restat_unchanged()
        print("== pulling main...", flush=True)
        r = _git("pull", "--ff-only", "--quiet", "origin", "main")
    except (OSError, subprocess.SubprocessError) as e:
        print(f"== WARNING: couldn't pull main ({e}); playing what's here", flush=True)
        return
    if r.returncode != 0:
        lines = [line.strip() for line in (r.stderr or r.stdout).splitlines() if line.strip()]
        why = next((line for line in lines if line.startswith(("fatal:", "error:"))),
                   next((line for line in lines if not line.startswith("hint:")), "git failed"))
        print(f"== WARNING: couldn't pull main ({why}); playing what's here", flush=True)
        return
    after = _git("rev-parse", "HEAD").stdout.strip()
    if after == before:
        print("== main is up to date", flush=True)
        return
    count = _git("rev-list", "--count", f"{before}..{after}").stdout.strip()
    latest = _git("log", "-1", "--format=%s", after).stdout.strip()
    print(f"== pulled {count} new commit(s); latest: {latest[:120]}", flush=True)


def check_native() -> None:
    state, line = native_stamp.check()
    if state in ("stale", "maybe"):
        print(f"== WARNING: {line}", flush=True)


def open_editor(godot: str) -> int:
    """The editor on the project, left running; the GUI build when it sits
    beside the console one (Windows), so no console window stays open."""
    exe = Path(godot)
    gui = exe.with_name(exe.name.replace("_console", ""))
    if gui != exe and gui.exists():
        exe = gui
    print(f"== opening the Godot editor on {ROOT}", flush=True)
    flags = 0
    if sys.platform == "win32":
        flags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
    subprocess.Popen([str(exe), "--path", str(ROOT), "--editor"], stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=flags,
                     start_new_session=sys.platform != "win32")
    return 0


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    do_import = True
    do_pull = True
    editor = False
    while argv and argv[0] in ("--no-import", "--no-pull", "--editor"):
        flag = argv.pop(0)
        do_import = do_import and flag != "--no-import"
        do_pull = do_pull and flag != "--no-pull"
        editor = editor or flag == "--editor"
    scene = DEFAULT_SCENE
    if argv and argv[0] != "--" and not argv[0].startswith("-"):
        scene = argv.pop(0)
        if not scene.startswith("res://"):
            scene = "res://" + scene.replace("\\", "/")
    if argv and argv[0] == "--":
        argv.pop(0)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")  # a Windows console's code page
    if do_pull:
        pull_main()
    check_native()
    godot = find_godot()
    if editor:
        return open_editor(godot)
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
