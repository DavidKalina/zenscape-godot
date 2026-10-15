#!/usr/bin/env python3
"""Long runs past the 10-minute tool-call limit: start one in the background,
then wait on it in slices that each end before the limit, with the log's
tail. No sleep/until polling loops.

  python tools/bg.py start suite -- python tools/run_tests.py --quick
  python tools/bg.py start sweep1 -- python tools/sweep.py scratch/gap_check.gd --seed 1..40
  python tools/bg.py wait suite            # up to 540 s; prints the tail and the state
  python tools/bg.py wait suite --for 120 --lines 60
  python tools/bg.py tail suite --lines 200
  python tools/bg.py list
  python tools/bg.py stop suite

The log and the state are in scratch/bg/<name>.log and <name>.json. `wait`
exits 0 when the run is done and passed, 1 when it is done and failed, 3
while it still runs (call wait again). A name already running is refused.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / "scratch" / "bg"


def state_path(name: str) -> Path:
    return DIR / f"{name}.json"


def load(name: str) -> dict:
    p = state_path(name)
    if not p.is_file():
        sys.exit(f"no run named {name} (python tools/bg.py list)")
    return json.loads(p.read_text(encoding="utf-8"))


def alive(pid: int) -> bool:
    if os.name == "nt":
        out = subprocess.run(["tasklist", "/FI", f"PID eq {pid}", "/NH"], capture_output=True, text=True).stdout
        return str(pid) in out
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def status(st: dict) -> str:
    if "code" in st:
        return f"done, exit {st['code']}"
    if alive(st["runner"]):
        return "running"
    return "gone (killed, no exit code)"


def tail(name: str, lines: int) -> str:
    log = DIR / f"{name}.log"
    if not log.is_file():
        return ""
    with open(log, "rb") as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(max(0, size - 200 * lines))
        text = f.read().decode("utf-8", errors="replace")
    return "\n".join(text.splitlines()[-lines:])


def cmd_start(name: str, command: list[str]) -> int:
    DIR.mkdir(parents=True, exist_ok=True)
    if state_path(name).is_file() and status(load(name)) == "running":
        sys.exit(f"{name} is still running (wait, stop, or another name)")
    log = DIR / f"{name}.log"
    log.write_text("", encoding="utf-8")
    kw: dict = {}
    if os.name == "nt":
        kw["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
    else:
        kw["start_new_session"] = True
    runner = subprocess.Popen([sys.executable, __file__, "_run", name, "--", *command], cwd=ROOT,
                              stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **kw)
    state_path(name).write_text(json.dumps({"name": name, "command": command, "runner": runner.pid,
                                            "started": datetime.now().isoformat(timespec="seconds")}), encoding="utf-8")
    print(f"started {name} (pid {runner.pid}); log scratch/bg/{name}.log; then: python tools/bg.py wait {name}")
    return 0


def cmd_run(name: str, command: list[str]) -> int:
    """The detached runner: runs the command, logs it, records its exit."""
    log = DIR / f"{name}.log"
    t = time.time()
    env = {**os.environ, "PYTHONUNBUFFERED": "1", "PYTHONIOENCODING": "utf-8"}
    with open(log, "ab") as out:
        proc = subprocess.Popen(command, cwd=ROOT, stdout=out, stderr=subprocess.STDOUT, env=env,
                                shell=(os.name == "nt" and len(command) == 1))
        for _ in range(50):  # the starter writes the state just after it spawns us
            if state_path(name).is_file():
                break
            time.sleep(0.1)
        st = json.loads(state_path(name).read_text(encoding="utf-8"))
        st["child"] = proc.pid
        state_path(name).write_text(json.dumps(st), encoding="utf-8")
        code = proc.wait()
    st = json.loads(state_path(name).read_text(encoding="utf-8"))
    st.update(code=code, seconds=round(time.time() - t, 1))
    state_path(name).write_text(json.dumps(st), encoding="utf-8")
    return code


def cmd_wait(name: str, limit: float, lines: int) -> int:
    t = time.time()
    st = load(name)
    while time.time() - t < limit:
        st = load(name)
        if "code" in st or status(st) != "running":
            break
        time.sleep(2)
    st = load(name)
    if "code" not in st and status(st) != "running":
        time.sleep(1.5)  # the runner may be writing the exit code as it goes
        st = load(name)
    print(tail(name, lines))
    s = status(st)
    took = f" after {st['seconds']} s" if "seconds" in st else ""
    print(f"== {name}: {s}{took}")
    if s == "running":
        print(f"== still running; call `python tools/bg.py wait {name}` again")
        return 3
    return 0 if st.get("code") == 0 else 1


def cmd_stop(name: str) -> int:
    st = load(name)
    for key in ("child", "runner"):
        pid = st.get(key)
        if pid and alive(pid):
            if os.name == "nt":
                subprocess.run(["taskkill", "/T", "/F", "/PID", str(pid)], capture_output=True)
            else:
                os.killpg(os.getpgid(pid), signal.SIGTERM)
    print(f"stopped {name}")
    return 0


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    argv = sys.argv[1:]
    command: list[str] = []
    if "--" in argv:
        i = argv.index("--")
        argv, command = argv[:i], argv[i + 1:]
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("action", choices=["start", "wait", "tail", "list", "stop", "_run"])
    p.add_argument("name", nargs="?")
    p.add_argument("--for", dest="limit", type=float, default=540, help="seconds wait blocks (default 540)")
    p.add_argument("--lines", type=int, default=30)
    args = p.parse_args(argv)
    if args.action == "list":
        DIR.mkdir(parents=True, exist_ok=True)
        for f in sorted(DIR.glob("*.json")):
            st = json.loads(f.read_text(encoding="utf-8"))
            print(f"{st['name']:16} {status(st):28} {st['started']}  {' '.join(st['command'])[:80]}")
        return 0
    if not args.name:
        p.error("a name")
    if args.action == "start":
        if not command:
            p.error("start NAME -- <command>")
        return cmd_start(args.name, command)
    if args.action == "_run":
        return cmd_run(args.name, command)
    if args.action == "wait":
        return cmd_wait(args.name, args.limit, args.lines)
    if args.action == "tail":
        print(tail(args.name, args.lines))
        print(f"== {args.name}: {status(load(args.name))}")
        return 0
    return cmd_stop(args.name)


if __name__ == "__main__":
    raise SystemExit(main())
