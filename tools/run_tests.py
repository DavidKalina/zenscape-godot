#!/usr/bin/env python3
"""Run the Godot test scripts, headless by default, and retain evidence.

Examples:
  python3 tools/run_tests.py                    # every headless test, 8 at a time
  python3 tools/run_tests.py --quick            # skip tests tagged slow
  python3 tools/run_tests.py --tests 'test_sky_*.gd'
  python3 tools/run_tests.py --list
  python3 tools/run_tests.py --rendered --gpu-only   # opens windows; only on request

Tags. A test declares what it needs in its top comment block:
  ## suite: gpu    needs a real renderer (pixel readback, MultiMesh transforms,
                   global shader parameters). Skipped headless, never counted
                   as passing there.
  ## suite: slow   legitimately takes over a minute headless. --quick skips it;
                   it gets three times the --timeout.
  ## suite: serial frame-time or wall-clock budgets that fail under load. Runs
                   alone, after the parallel tests.

Known failures. tests/known_failures.txt lists tests that fail for a recorded
reason (one `test_x.gd  # reason` per line). They still run; a failure there
is reported as known and doesn't fail the run, and one that now passes is
called out so the line can go. Anything else that fails, fails the run.

Each worker gets its own HOME (APPDATA on Windows) under the output directory, so user:// never
collides between tests running at once. Slow tests start first.

A classified engine message (a renderer light unpair, the macOS certificate
store, an unmapped controller plugged into the host, resources or RIDs still
alive at exit) is recorded as
pass_with_known_engine_error, never as a clean pass; --strict-engine-errors
fails them. All other engine errors, script errors, assertion failures and
timeouts fail a test. Headless runs never fall back to a graphical renderer.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed as futures_completed
from datetime import datetime, timezone
import json
import os
import queue
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = os.environ.get("GODOT", "/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot")
KNOWN_FAILURES = ROOT / "tests" / "known_failures.txt"
NATIVE = ROOT / "native" / "terrain_kernels"
ANSI = re.compile(r"\x1b\[[0-9;]*m")
ERROR_START = re.compile(r"^(?:SCRIPT ERROR:|ERROR:|USER ERROR:|FATAL:|Parse Error:)", re.M)
SUITE_TAG = re.compile(r"^##\s*suite:\s*(.+)$")
EXIT_LEAK = re.compile(r"^ERROR: (?:\d+ resources still in use at exit|\d+ RID allocations of type .* were leaked at exit)")


def diagnostics(output: str) -> dict:
    """Classify exact known signatures without suppressing the original log."""
    lines = ANSI.sub("", output).splitlines()
    real_errors, known_errors, warnings = [], [], []
    for index, line in enumerate(lines):
        if line.startswith("WARNING:"):
            warnings.append(line)
        if not ERROR_START.match(line):
            continue
        block = "\n".join(lines[index:index + 3])
        if (line == "ERROR: BUG, indexing did not unpair geometries from light."
                and "renderer_scene_cull.cpp:" in block
                and ("instance_set_scenario" in block or "instance_set_base" in block)):
            known_errors.append({"kind": "renderer_light_unpair", "diagnostic": block})
        elif (line == 'ERROR: Condition "ret != noErr" is true. Returning: ""'
                and "get_system_ca_certificates (platform/macos/os_macos.mm:" in block):
            known_errors.append({"kind": "macos_certificate_environment", "diagnostic": block})
        elif line.startswith("ERROR: Error opening gamepad at index ") and "Couldn't find mapping" in line:
            known_errors.append({"kind": "host_gamepad_unmapped", "diagnostic": block})
        elif EXIT_LEAK.match(line):
            known_errors.append({"kind": "exit_leak", "diagnostic": block})
        else:
            real_errors.append(block)
    failures = [line for line in lines if re.match(r"^FAIL(?:\b|:)", line)]
    failures += [line for line in lines if re.search(r"\bfailures\s*=\s*[1-9][0-9]*\b", line)]
    skipped = [line for line in lines if line.startswith("SKIP:")]
    return dict(errors=real_errors, known_engine_errors=known_errors,
                warnings=warnings, assertion_failures=failures, skips=skipped)


def suite_tags(test: Path) -> set[str]:
    """Tags from `## suite:` lines in the script's leading comment block."""
    tags: set[str] = set()
    for line in test.read_text(errors="replace").splitlines()[:60]:
        match = SUITE_TAG.match(line.strip())
        if match:
            tags.update(re.split(r"[\s,]+", match.group(1).strip()))
    return tags


def known_failures() -> dict[str, str]:
    if not KNOWN_FAILURES.is_file():
        return {}
    known = {}
    for line in KNOWN_FAILURES.read_text().splitlines():
        name, _, reason = line.partition("#")
        if name.strip():
            known[name.strip()] = reason.strip()
    return known


def stale_native_kernels() -> list[str]:
    """Native sources edited since the local kernel library was built."""
    built = list((NATIVE / "bin").glob("libzenscape_kernels.*"))
    if not built:
        return []
    oldest = min(path.stat().st_mtime for path in built)
    return [path.name for path in [NATIVE / "kernels.cpp", NATIVE / "water_flow.h"]
            if path.is_file() and path.stat().st_mtime > oldest]


def select_tests(patterns: list[str]) -> list[Path]:
    tests = {path for pattern in patterns for path in (ROOT / "tests").glob(pattern)
             if path.is_file() and path.name.startswith("test_") and path.suffix == ".gd"}
    return sorted(tests)


def write_report(path: Path, report: dict) -> None:
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(report, indent=2) + "\n")
    temporary.replace(path)


def run_one(test: Path, args: argparse.Namespace, output_dir: Path, home: Path | None = None,
            slow: bool = False) -> dict:
    name = test.stem
    stdout_path = output_dir / f"{name}.stdout.log"
    engine_path = output_dir / f"{name}.godot.log"
    display_args = ["--rendering-method", "forward_plus"] if args.rendered else ["--headless"]
    command = [args.godot, *display_args, "--path", str(ROOT),
               "--resolution", "640x480", "--log-file", str(engine_path),
               "--script", str(test.relative_to(ROOT))]
    timeout = args.timeout * (3 if slow else 1)
    started = time.monotonic()
    timed_out = False
    env = None
    if home is not None:
        # Windows Godot keeps user:// under APPDATA, not HOME.
        env = dict(os.environ, HOME=str(home), APPDATA=str(home))
    with stdout_path.open("w") as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True, env=env)
        try:
            process.wait(timeout=timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            # Kill this test's own process group, never another agent's Godot.
            if hasattr(os, "killpg"):
                os.killpg(process.pid, signal.SIGKILL)
            else:  # Windows: no process groups; the test's Godot is the one process.
                process.kill()
            process.wait()
            if isinstance(error, KeyboardInterrupt):
                raise
            timed_out = True
    captured = stdout_path.read_text(errors="replace")
    findings = diagnostics(captured)
    passed = (process.returncode == 0 and not timed_out and not findings["errors"]
              and not findings["assertion_failures"] and not findings["skips"])
    if args.strict_engine_errors and findings["known_engine_errors"]:
        passed = False
    status = "timeout" if timed_out else "failed" if not passed else (
        "pass_with_known_engine_error" if findings["known_engine_errors"] else "passed")
    return dict(test=str(test.relative_to(ROOT)), status=status, passed=passed,
                exit_code=process.returncode, seconds=round(time.monotonic() - started, 3),
                command=command, timeout_seconds=timeout, stdout_log=str(stdout_path), engine_log=str(engine_path),
                **findings)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", default=DEFAULT_GODOT)
    parser.add_argument("--rendered", action="store_true", help="Use native Forward+; opens windows and may steal focus")
    parser.add_argument("--gpu-only", action="store_true", help="Only tests tagged gpu (needs --rendered)")
    parser.add_argument("--quick", action="store_true", help="Skip tests tagged slow")
    parser.add_argument("--timeout", type=float, default=180.0, help="Wall-clock seconds per test (default: 180)")
    parser.add_argument("--tests", action="append", default=[], help="Glob under tests/; repeat for multiple patterns")
    parser.add_argument("--output", type=Path, default=Path(tempfile.gettempdir()) / ("zs-tests-" + datetime.now().strftime("%Y%m%d-%H%M%S")))
    parser.add_argument("--list", action="store_true", help="List selected scripts and their tags without launching Godot")
    parser.add_argument("--jobs", "-j", type=int, default=8, help="Tests to run at once (default: 8); each worker gets its own HOME")
    parser.add_argument("--strict-engine-errors", action="store_true", help="Also fail known renderer/environment/exit-leak signatures")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    if args.jobs < 1:
        parser.error("--jobs must be at least 1")
    if args.gpu_only and not args.rendered:
        parser.error("--gpu-only needs --rendered: gpu tests can't pass headless")
    candidates = select_tests(args.tests or ["test_*.gd"])
    if not candidates:
        parser.error("No test scripts matched")
    tags = {test: suite_tags(test) for test in candidates}
    known = known_failures()
    tests, skipped = [], []
    for test in candidates:
        if not args.rendered and "gpu" in tags[test]:
            skipped.append((test, "gpu"))
        elif args.gpu_only and "gpu" not in tags[test]:
            continue
        elif args.quick and "slow" in tags[test]:
            skipped.append((test, "slow"))
        else:
            tests.append(test)
    if args.list:
        for test in candidates:
            marks = sorted(tags[test]) + (["known-failure"] if test.name in known else [])
            state = "skip" if any(test == s for s, _ in skipped) else "run"
            if test in tests or state == "skip":
                print(f"{state:4} {test.relative_to(ROOT)}{'  [' + ' '.join(marks) + ']' if marks else ''}")
        print(f"{len(tests)} to run {'native Forward+' if args.rendered else 'headless'}, {len(skipped)} skipped")
        return 0
    if not tests:
        parser.error("Every matched test is skipped in this mode")
    if not Path(args.godot).is_file():
        parser.error(f"Godot executable does not exist: {args.godot}")
    output_dir = args.output.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = output_dir / "results.json"
    if report_path.exists():
        parser.error(f"Output already contains results; select a fresh --output: {output_dir}")
    report = dict(started_at=datetime.now(timezone.utc).isoformat(), project=str(ROOT),
                  renderer="forward_plus" if args.rendered else "dummy", headless=not args.rendered,
                  resolution="640x480", timeout_seconds=args.timeout, jobs=args.jobs,
                  expected_tests=len(tests), complete=False, passed=False, results=[],
                  skipped=[dict(test=str(test.relative_to(ROOT)), reason=reason) for test, reason in skipped])
    write_report(report_path, report)
    began = time.monotonic()
    stale = stale_native_kernels()
    if stale:
        print(f"WARNING: {', '.join(stale)} changed after the native kernel library in "
              f"{NATIVE.relative_to(ROOT)}/bin was built; native-vs-GDScript tests will fail "
              "until it is rebuilt (tools/build_native_kernels.py)", flush=True)

    def show(index: int, test: Path, result: dict) -> None:
        status = result["status"].upper()
        if not result["passed"] and test.name in known:
            status += " (known)"
        print(f"[{index}/{len(tests)}] {status} {test.name} ({result['seconds']}s)", flush=True)
        if test.name in known and not result["passed"]:
            return
        for issue in result["errors"] + result["assertion_failures"]:
            print(issue, flush=True)
        for issue in result["known_engine_errors"]:
            print(f"  classified, retained in log: {issue['kind']}", flush=True)

    # Slow tests first so they don't trail the run on one worker.
    ordered = sorted(tests, key=lambda test: "slow" not in tags[test])
    try:
        homes: queue.Queue[Path] = queue.Queue()
        for slot in range(args.jobs):
            home = output_dir / "homes" / f"worker{slot}"
            home.mkdir(parents=True, exist_ok=True)
            homes.put(home)

        def work(test: Path) -> dict:
            home = homes.get()
            try:
                return run_one(test, args, output_dir, home, "slow" in tags[test])
            finally:
                homes.put(home)

        done = 0

        def record(test: Path, result: dict) -> None:
            nonlocal done
            result["known_failure"] = known.get(test.name)
            done += 1
            report["results"].append(result)
            write_report(report_path, report)
            show(done, test, result)

        parallel = [test for test in ordered if "serial" not in tags[test]]
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = {pool.submit(work, test): test for test in parallel}
            for future in futures_completed(futures):
                record(futures[future], future.result())
        for test in ordered:
            if "serial" in tags[test]:
                record(test, work(test))
        order = {str(test.relative_to(ROOT)): i for i, test in enumerate(tests)}
        report["results"].sort(key=lambda result: order[result["test"]])
    except KeyboardInterrupt:
        report["interrupted"] = True
        write_report(report_path, report)
        print(f"Interrupted; partial evidence saved in {report_path}", file=sys.stderr)
        return 130
    results = report["results"]
    new_failures = [r for r in results if not r["passed"] and r["known_failure"] is None]
    known_failed = [r for r in results if not r["passed"] and r["known_failure"] is not None]
    fixed = [r for r in results if r["passed"] and r["known_failure"] is not None]
    report["complete"] = True
    report["passed"] = not new_failures
    report["finished_at"] = datetime.now(timezone.utc).isoformat()
    report["summary"] = {status: sum(result["status"] == status for result in results)
                         for status in ["passed", "pass_with_known_engine_error", "failed", "timeout"]}
    report["summary"].update(known_failures=len(known_failed), new_failures=len(new_failures),
                             skipped=len(skipped), wall_seconds=round(time.monotonic() - began, 1))
    write_report(report_path, report)
    print(flush=True)
    for result in sorted(results, key=lambda r: -r["seconds"])[:5]:
        print(f"slowest: {Path(result['test']).name} {result['seconds']:.0f}s")
    for result in known_failed:
        print(f"known failure: {Path(result['test']).name}  # {result['known_failure']}")
    for result in fixed:
        print(f"NOW PASSES, drop it from tests/known_failures.txt: {Path(result['test']).name}")
    for result in new_failures:
        print(f"FAILED: {Path(result['test']).name} ({result['status']}) log: {result['stdout_log']}")
    if skipped:
        reasons = {reason: sum(r == reason for _, r in skipped) for _, reason in skipped}
        print("skipped: " + ", ".join(f"{count} {reason}" for reason, count in reasons.items()))
    print(json.dumps(report["summary"], sort_keys=True), flush=True)
    print(f"Full output and diagnostics: {report_path}", flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
