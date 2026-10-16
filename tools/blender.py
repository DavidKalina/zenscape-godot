#!/usr/bin/env python3
"""Run a Blender script headless, on the Mac and on Windows (Store build too).

  python tools/blender.py --where                         # the Blender it runs, and how
  python tools/blender.py run art/blender/guacharo/guacharo_build.py -- --out=scratch/g
  python tools/blender.py run --blend art/blender/plane/plane.blend art/blender/plane/plane_render.py -- scratch/r
  python tools/blender.py --expr "import bpy; print(bpy.app.version_string)"
  python tools/blender.py run --timeout 600 x.py          # kill after 600 s (exit 124)

The script runs with `-b`. It waits for the script, prints its output as it
comes and exits with the script's exit code: 0, the code a `sys.exit(n)`
gives, or 1 on an uncaught exception (traceback printed). Blender itself
exits 0 after a failed --python script; this doesn't.

The script sees the args after `--` the usual way:
`sys.argv[sys.argv.index("--") + 1:]`. Its own folder is on `sys.path`, and
so is `art/blender/` (the shared helpers: `import blendkit as bk`;
art/blender/blendkit/README.md). The working directory is the repo root.

Blender is found from $BLENDER, then the usual installs:
  Windows  C:\\Program Files\\Blender Foundation\\Blender */blender.exe,
           then the Microsoft Store build's launcher,
           %LOCALAPPDATA%\\Microsoft\\WindowsApps\\blender-launcher.exe
  Mac      /Applications/Blender.app, ~/Applications/Blender.app,
           /opt/homebrew/bin/blender
  then `blender` on PATH.

The Store build's blender.exe (in Program Files\\WindowsApps) gives "Access
denied"; only the launcher runs, and it detaches, dropping the output and
the exit code. So the script always runs inside a small bootstrap that
writes its output to a log and its exit code to a done-marker, which this
tool follows and relays. That works the same for a plain install.

Flags (after `run`, before the script):
  --blend FILE     open FILE first (`blender -b FILE --python script`)
  --timeout S      kill after S seconds, exit 124 (default 1800, or
                   $BLENDER_TIMEOUT)
  --factory        add --factory-startup (no user prefs or add-ons)
"""
from __future__ import annotations

import glob
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "art" / "blender"
STORE_LAUNCHER = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\WindowsApps\blender-launcher.exe")
CANDIDATES = [
    r"C:\Program Files\Blender Foundation\Blender *\blender.exe",
    STORE_LAUNCHER,
    "/Applications/Blender.app/Contents/MacOS/Blender",
    os.path.expanduser("~/Applications/Blender.app/Contents/MacOS/Blender"),
    "/opt/homebrew/bin/blender",
    "/usr/local/bin/blender",
]

# The bootstrap Blender runs with --python. Its first lines set LOG, DONE,
# PIDF, SCRIPT, ARGS, EXPR, CWD, PATHS.
BOOT = r'''
import os, sys, runpy, traceback
os.chdir(CWD)
log = open(LOG, "w", encoding="utf-8", buffering=1)
sys.stdout = sys.stderr = log
open(PIDF, "w").write(str(os.getpid()))
for p in PATHS:
    if p not in sys.path:
        sys.path.insert(0, p)
code = 0
try:
    if EXPR is not None:
        sys.argv = [sys.argv[0], "--"] + ARGS
        exec(compile(EXPR, "<expr>", "exec"), {"__name__": "__main__"})
    else:
        sys.argv = [sys.argv[0], "-b", "--python", SCRIPT, "--"] + ARGS
        runpy.run_path(SCRIPT, run_name="__main__")
except SystemExit as e:
    code = e.code if isinstance(e.code, int) else (0 if e.code is None else 1)
    if not isinstance(e.code, (int, type(None))):
        print(e.code)
except BaseException:
    traceback.print_exc()
    code = 1
log.flush()
log.close()
with open(DONE + ".tmp", "w") as f:
    f.write(str(code))
os.replace(DONE + ".tmp", DONE)
os._exit(code)
'''


def find_blender() -> str | None:
    env = os.environ.get("BLENDER")
    if env:
        return env
    for pat in CANDIDATES:
        hits = sorted(glob.glob(pat))
        if hits:
            return hits[-1]     # the newest "Blender 5.x" folder sorts last
    return shutil.which("blender")


def is_launcher(exe: str) -> bool:
    return Path(exe).name.lower() == "blender-launcher.exe"


def _kill(pid: int) -> None:
    try:
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(pid)], capture_output=True)
        else:
            os.kill(pid, signal.SIGKILL)
    except (OSError, ProcessLookupError):
        pass


def run(script: str | None, args: list[str], expr: str | None = None, blend: str | None = None,
        timeout: float = 1800.0, factory: bool = False) -> int:
    exe = find_blender()
    if not exe:
        print("blender.py: no Blender found; set BLENDER to its executable", file=sys.stderr)
        return 127
    paths = [str(LIB)]
    if script:
        script = str(Path(script).resolve())
        if not Path(script).exists():
            print(f"blender.py: no such script {script}", file=sys.stderr)
            return 2
        paths.append(str(Path(script).parent))
    tmp = Path(tempfile.gettempdir())
    tag = uuid.uuid4().hex[:12]
    log, done, pidf, boot, errf = (str(tmp / f"blrun_{tag}.{x}") for x in ("log", "done", "pid", "py", "err"))
    with open(boot, "w", encoding="utf-8") as f:
        f.write(f"LOG={log!r}\nDONE={done!r}\nPIDF={pidf!r}\nSCRIPT={script!r}\nARGS={args!r}\n"
                f"EXPR={expr!r}\nCWD={str(ROOT)!r}\nPATHS={paths!r}\n" + BOOT)
    cmd = [exe, "-b"]
    if factory:
        cmd.append("--factory-startup")
    if blend:
        cmd.append(str(Path(blend).resolve()))
    cmd += ["--python", boot]
    errh = open(errf, "w", encoding="utf-8", errors="replace")
    proc = subprocess.Popen(cmd, cwd=str(ROOT), stdout=errh, stderr=errh)
    t0, pos, code = time.time(), 0, None

    def relay() -> None:
        nonlocal pos
        if os.path.exists(log):
            with open(log, encoding="utf-8", errors="replace") as fh:
                fh.seek(pos)
                chunk = fh.read()
                pos = fh.tell()
            if chunk:
                sys.stdout.write(chunk)
                sys.stdout.flush()

    try:
        while not os.path.exists(done):
            relay()
            # A plain Blender that died before the bootstrap ran (a bad
            # .blend, a crash) leaves no marker: stop on its exit.
            if not is_launcher(exe) and proc.poll() is not None and not os.path.exists(done):
                time.sleep(0.3)
                if os.path.exists(done):
                    break
                relay()
                errh.flush()
                print(Path(errf).read_text(encoding="utf-8", errors="replace")[-4000:], end="")
                print(f"\nblender.py: Blender exited {proc.returncode} before the script finished")
                return proc.returncode or 1
            if is_launcher(exe) and time.time() - t0 > 60 and not os.path.exists(pidf):
                print("\nblender.py: the launcher started no Blender in 60 s")
                return 1
            if time.time() - t0 > timeout:
                relay()
                if os.path.exists(pidf):
                    _kill(int(open(pidf).read().strip() or 0))
                _kill(proc.pid)
                print(f"\nblender.py: timed out after {timeout:.0f} s (killed)")
                return 124
            time.sleep(0.25)
        time.sleep(0.2)
        relay()
        code = int(open(done).read().strip() or 1)
    finally:
        try:
            proc.wait(timeout=20)
        except subprocess.TimeoutExpired:
            pass
        errh.close()
        for p in (log, done, pidf, boot, errf):
            try:
                os.remove(p)
            except OSError:
                pass
    print(f"== blender exit {code} in {time.time() - t0:.1f} s")
    return code


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0 if argv else 2
    if argv[0] == "--where":
        exe = find_blender()
        if not exe:
            print("no Blender found (set BLENDER)")
            return 1
        how = "Store launcher (detaches; output relayed through a log)" if is_launcher(exe) else "direct"
        print(f"{exe}\n  {how}")
        return 0
    timeout = float(os.environ.get("BLENDER_TIMEOUT", "1800"))
    rest = argv[1:] if argv[0] == "run" else argv
    blend, factory, expr, script, args = None, False, None, None, []
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == "--":
            args = rest[i + 1:]
            break
        if a == "--blend":
            blend = rest[i + 1]; i += 2; continue
        if a == "--timeout":
            timeout = float(rest[i + 1]); i += 2; continue
        if a == "--factory":
            factory = True; i += 1; continue
        if a == "--expr":
            expr = rest[i + 1]; i += 2; continue
        if script is None and expr is None:
            script = a; i += 1; continue
        print(f"blender.py: unexpected argument {a!r} (script args go after --)", file=sys.stderr)
        return 2
    if script is None and expr is None:
        print("blender.py: give a script or --expr", file=sys.stderr)
        return 2
    return run(script, args, expr=expr, blend=blend, timeout=timeout, factory=factory)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
