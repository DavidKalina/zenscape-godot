#!/usr/bin/env python3
"""Run Godot for this project: the exe found, the import done, the log read.

The harness's base (tools/README.md). The other harness tools import it;
run it yourself for any Godot command they don't cover.

  python tools/godot.py --where                       # the exe it would run
  python tools/godot.py --import                      # import now (waits on another's)
  python tools/godot.py res://studies/trap_yard.tscn --quit-after 400 -- --no-title
  python tools/godot.py -s tools/layer_dump.gd -- --seed=3
  python tools/godot.py --rendered --timeout 90 -s my_capture.gd -- --out=captures/x

Headless unless --rendered. `--path <repo>` is added. Before the run, the
import is checked: with no import yet, or a `class_name` script newer than
the class cache, it runs `--import` first (a lock keeps two agents from
importing at once). A missing import is what gives the phantom
`Could not find type "NativeTerrainData"` parse errors.

The output is printed with the exit noise dropped (RID / resources leaked at
exit, the gamepad and certificate messages tools/run_tests.py classifies)
and ends in a summary line:
  == godot exit 0 in 12.3 s: 0 errors, 0 FAIL lines (2 exit-noise lines dropped)
Exit status: Godot's, or 1 if it exited 0 with script or engine errors, or
124 on the timeout (the process is killed).

Harness flags (before the Godot args):
  --where          print the exe and quit
  --import         import, then quit (or then run, if Godot args follow)
  --no-import      skip the import check
  --rendered       no --headless: a window (one at a time, AGENTS.md)
  --timeout S      kill after S seconds (default 300, 120 rendered)
  --log FILE       also write the full, unfiltered log there
  --only           print only check lines (OK/FAIL/SKIP/RESULT), errors and
                   the summary
  --raw            print the log unfiltered

Godot is found from $GODOT, then the WinGet install, C:\\Tools\\Godot, the
Mac app paths, then `godot` on PATH.
"""
from __future__ import annotations

import glob
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_tests import ANSI, diagnostics  # noqa: E402

CANDIDATES = [
    os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4*_console.exe"),
    r"C:\Tools\Godot\Godot_v4*_console.exe",
    r"C:\Tools\Godot\*\Godot_v4*_console.exe",
    os.path.expanduser("~/Applications/Godot.app/Contents/MacOS/Godot"),
    "/Applications/Godot.app/Contents/MacOS/Godot",
]
CLASS_CACHE = ROOT / ".godot" / "global_script_class_cache.cfg"
LOCK = ROOT / ".godot" / "harness-import.lock"
# Lines dropped from the shown log: exit-time leak reports and their
# `at:` lines, the classified host noise.
NOISE = re.compile(
    r"^(?:ERROR: \d+ resources still in use at exit"
    r"|ERROR: \d+ RID allocations of type .* were leaked at exit"
    r"|WARNING: ObjectDB instances leaked at exit"
    r"|ERROR: Error opening gamepad at index .*Couldn't find mapping"
    r"|Leaked instance:|Resource still in use:"
    r"|Orphan StringName:|StringName: \d+ unclaimed"
    r"|ERROR: Pages in use exist at exit)")
CHECK_LINE = re.compile(r"^(?:OK |FAIL|SKIP|RESULT |ROW |WARN |TIMEOUT|== |\| |\[f\d+\] |saved )")
SKIP_DIRS = {".godot", ".git", ".claude", "captures", "builds", "node_modules", "scratch"}


def find_godot() -> str:
    """The Godot console exe to run, or exits with how to set it."""
    env = os.environ.get("GODOT")
    if env:
        if Path(env).is_file():
            return env
        sys.exit(f"$GODOT is set but missing: {env}")
    for pattern in CANDIDATES:
        hits = sorted(glob.glob(pattern))
        if hits:
            return hits[-1]
    on_path = shutil.which("godot") or shutil.which("godot4")
    if on_path:
        return on_path
    sys.exit("Godot not found: set $GODOT to the console exe (see AGENTS.md, Running on Windows)")


def _newest_class_script() -> tuple[float, str]:
    newest, name = 0.0, ""
    for folder, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if not f.endswith(".gd"):
                continue
            p = os.path.join(folder, f)
            m = os.path.getmtime(p)
            if m <= newest:
                continue
            try:
                with open(p, encoding="utf-8", errors="replace") as fh:
                    head = fh.read(4000)
            except OSError:
                continue
            if re.search(r"^class_name\s", head, re.M):
                newest, name = m, p
    return newest, name


def import_needed() -> str:
    """Why an import is needed, or "" if it isn't."""
    if not CLASS_CACHE.is_file():
        return "no import yet in this checkout"
    newest, name = _newest_class_script()
    if newest > CLASS_CACHE.stat().st_mtime:
        return f"{Path(name).relative_to(ROOT)} is newer than the class cache"
    return ""


def run_import(godot: str, quiet: bool = False) -> int:
    """`--import`, under a lock; waits on an import another agent started."""
    LOCK.parent.mkdir(exist_ok=True)
    began = time.time()
    while True:
        try:
            fd = os.open(LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            break
        except FileExistsError:
            # A lock older than 15 minutes is a crashed import's.
            if time.time() - LOCK.stat().st_mtime > 900:
                LOCK.unlink(missing_ok=True)
                continue
            if time.time() - began > 900:
                print("== import lock held for 15 min; going on without it", flush=True)
                break
            time.sleep(2)
    if time.time() - began > 3 and not import_needed():
        LOCK.unlink(missing_ok=True)
        return 0  # another agent's import covered it
    try:
        if not quiet:
            print("== importing (headless)...", flush=True)
        t = time.time()
        proc = subprocess.run([godot, "--headless", "--editor", "--path", str(ROOT), "--import"],
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                              encoding="utf-8", errors="replace", timeout=900)
        errors = diagnostics(proc.stdout)["errors"]
        if not quiet:
            print(f"== import done in {time.time() - t:.1f} s, {len(errors)} errors", flush=True)
            for e in errors[:10]:
                print(e)
        # The import may leave the cache untouched when nothing changed.
        if CLASS_CACHE.is_file():
            os.utime(CLASS_CACHE)
        return proc.returncode
    finally:
        LOCK.unlink(missing_ok=True)


def run(godot_args: list[str], *, rendered: bool = False, timeout: float | None = None,
        check_import: bool = True, env: dict | None = None) -> dict:
    """Runs Godot; returns {code, seconds, output, diag, timed_out, command}."""
    godot = find_godot()
    if check_import:
        why = import_needed()
        if why:
            print(f"== import needed: {why}", flush=True)
            run_import(godot)
    args = list(godot_args)
    if "--path" not in args:
        args = ["--path", str(ROOT), *args]
    if not rendered and "--headless" not in args:
        args = ["--headless", *args]
    timeout = timeout or (120 if rendered else 300)
    command = [godot, *args]
    t = time.time()
    timed_out = False
    proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", errors="replace", cwd=ROOT,
                            env={**os.environ, **(env or {})})
    try:
        output, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        output, _ = proc.communicate()
        timed_out = True
    output = ANSI.sub("", output or "")
    return dict(code=124 if timed_out else proc.returncode, seconds=time.time() - t,
                output=output, diag=diagnostics(output), timed_out=timed_out, command=command)


def filtered(output: str, only: bool = False) -> tuple[list[str], int]:
    """The log's lines worth reading, and how many noise lines were dropped."""
    shown, dropped, skip_at = [], 0, False
    lines = output.splitlines()
    for i, line in enumerate(lines):
        if NOISE.match(line):
            dropped, skip_at = dropped + 1, True
            continue
        if skip_at and line.lstrip().startswith("at:"):
            dropped += 1
            continue
        skip_at = False
        if only:
            is_error = re.match(r"^(?:SCRIPT ERROR:|ERROR:|USER ERROR:|FATAL:|Parse Error:)", line)
            follows_error = i > 0 and re.match(r"^(?:SCRIPT ERROR:|ERROR:|USER ERROR:|Parse Error:)", lines[i - 1])
            if not (CHECK_LINE.match(line) or is_error or (follows_error and line.lstrip().startswith("at:"))):
                continue
        shown.append(line)
    return shown, dropped


def summary(result: dict, dropped: int = 0) -> str:
    d = result["diag"]
    what = "TIMEOUT after" if result["timed_out"] else f"exit {result['code']} in"
    return (f"== godot {what} {result['seconds']:.1f} s: {len(d['errors'])} errors, "
            f"{len(d['assertion_failures'])} FAIL lines ({dropped} exit-noise lines dropped)")


def status(result: dict) -> int:
    if result["timed_out"]:
        return 124
    if result["code"] != 0:
        return result["code"]
    return 1 if result["diag"]["errors"] else 0


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    rendered = only = raw = do_import = False
    check_import, timeout, log = True, None, None
    while argv and argv[0] in ("--where", "--import", "--no-import", "--rendered",
                               "--timeout", "--log", "--only", "--raw", "-h", "--help"):
        flag = argv.pop(0)
        if flag in ("-h", "--help"):
            print(__doc__)
            return 0
        if flag == "--where":
            print(find_godot())
            return 0
        if flag == "--import":
            do_import = True
        elif flag == "--no-import":
            check_import = False
        elif flag == "--rendered":
            rendered = True
        elif flag == "--only":
            only = True
        elif flag == "--raw":
            raw = True
        elif flag == "--timeout":
            timeout = float(argv.pop(0))
        elif flag == "--log":
            log = argv.pop(0)
    if do_import:
        code = run_import(find_godot())
        if not argv:
            return code
        check_import = False
    if not argv:
        print(__doc__)
        return 2
    result = run(argv, rendered=rendered, timeout=timeout, check_import=check_import)
    if log:
        Path(log).parent.mkdir(parents=True, exist_ok=True)
        Path(log).write_text(result["output"], encoding="utf-8")
    if raw:
        print(result["output"])
        dropped = 0
    else:
        shown, dropped = filtered(result["output"], only)
        print("\n".join(shown))
    print(summary(result, dropped))
    return status(result)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
