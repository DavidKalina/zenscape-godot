#!/usr/bin/env python3
"""Run Godot tests, headless by default, and retain evidence.

Examples:
  python3 tools/check_bigfoot_living_regressions.py --list
  python3 tools/check_bigfoot_living_regressions.py --output /tmp/living-full-suite
  python3 tools/check_bigfoot_living_regressions.py --tests 'test_bigfoot_*.gd'
  python3 tools/check_bigfoot_living_regressions.py --jobs 8

Tests run one at a time unless --jobs asks for more. Parallel workers each get
their own HOME under the output directory, so user:// (saves, settings) never
collides between tests running at once. Timing-sensitive tests may run slower
under load; raise --timeout if a parallel run times out where a serial one did not.

Use --rendered only for an intentional graphical run: it opens Godot windows
and may steal focus. Tests requiring GPU image readback or MultiMesh transforms
may fail or time out headless; they are never retried graphically or counted as
passing merely because rendering is unavailable. A classified renderer
issue is recorded as pass_with_known_engine_error, never as a clean pass. All
other engine errors, script errors, assertion failures and timeouts fail a test.
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
import time

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = "/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot"
ANSI = re.compile(r"\x1b\[[0-9;]*m")
ERROR_START = re.compile(r"^(?:SCRIPT ERROR:|ERROR:|USER ERROR:|FATAL:|Parse Error:)", re.M)


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
        else:
            real_errors.append(block)
    failures = [line for line in lines if re.match(r"^FAIL(?:\b|:)", line)]
    failures += [line for line in lines if re.search(r"\bfailures\s*=\s*[1-9][0-9]*\b", line)]
    skipped = [line for line in lines if line.startswith("SKIP:")]
    return dict(errors=real_errors, known_engine_errors=known_errors,
                warnings=warnings, assertion_failures=failures, skips=skipped)


def select_tests(patterns: list[str]) -> list[Path]:
    tests = {path for pattern in patterns for path in (ROOT / "tests").glob(pattern)
             if path.is_file() and path.name.startswith("test_") and path.suffix == ".gd"}
    return sorted(tests)


def write_report(path: Path, report: dict) -> None:
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(report, indent=2) + "\n")
    temporary.replace(path)


def run_one(test: Path, args: argparse.Namespace, output_dir: Path, home: Path | None = None) -> dict:
    name = test.stem
    stdout_path = output_dir / f"{name}.stdout.log"
    engine_path = output_dir / f"{name}.godot.log"
    display_args = ["--rendering-method", "forward_plus"] if args.rendered else ["--headless"]
    command = [args.godot, *display_args, "--path", str(ROOT),
               "--resolution", "640x480", "--log-file", str(engine_path),
               "--script", str(test.relative_to(ROOT))]
    timeout = args.timeout
    started = time.monotonic()
    timed_out = False
    env = None
    if home is not None:
        env = dict(os.environ, HOME=str(home))
    with stdout_path.open("w") as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True, env=env)
        try:
            process.wait(timeout=timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            # Kill this test's own process group, never another agent's Godot.
            os.killpg(process.pid, signal.SIGKILL)
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
    parser.add_argument("--timeout", type=float, default=120.0, help="Wall-clock seconds per test (default: 120)")
    parser.add_argument("--tests", action="append", default=[], help="Glob under tests/; repeat for multiple patterns")
    parser.add_argument("--output", type=Path, default=Path("/tmp") / ("bigfoot-living-regressions-" + datetime.now().strftime("%Y%m%d-%H%M%S")))
    parser.add_argument("--list", action="store_true", help="List selected scripts without launching Godot")
    parser.add_argument("--jobs", "-j", type=int, default=1, help="Tests to run at once (default: 1); each worker gets its own HOME")
    parser.add_argument("--strict-engine-errors", action="store_true", help="Also fail known renderer/environment error signatures")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    if args.jobs < 1:
        parser.error("--jobs must be at least 1")
    tests = select_tests(args.tests or ["test_*.gd"])
    if not tests:
        parser.error("No test scripts matched")
    if args.list:
        for test in tests:
            print(test.relative_to(ROOT))
        print(f"{len(tests)} {'native Forward+' if args.rendered else 'headless'} test scripts")
        return 0
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
                  expected_tests=len(tests), complete=False, passed=False, results=[])
    write_report(report_path, report)
    def show(index: int, test: Path, result: dict) -> None:
        print(f"[{index}/{len(tests)}] {result['status'].upper()} {test.name} ({result['seconds']}s)", flush=True)
        for issue in result["errors"] + result["assertion_failures"]:
            print(issue, flush=True)
        for issue in result["known_engine_errors"]:
            print(f"  classified, retained in log: {issue['kind']}", flush=True)

    try:
        if args.jobs == 1:
            for index, test in enumerate(tests, 1):
                print(f"[{index}/{len(tests)}] RUN {test.name}", flush=True)
                result = run_one(test, args, output_dir)
                report["results"].append(result)
                write_report(report_path, report)
                show(index, test, result)
        else:
            # Each worker borrows a HOME slot for the length of one test.
            homes: queue.Queue[Path] = queue.Queue()
            for slot in range(args.jobs):
                home = output_dir / "homes" / f"worker{slot}"
                home.mkdir(parents=True, exist_ok=True)
                homes.put(home)

            def work(test: Path) -> dict:
                home = homes.get()
                try:
                    return run_one(test, args, output_dir, home)
                finally:
                    homes.put(home)

            done = 0
            with ThreadPoolExecutor(max_workers=args.jobs) as pool:
                futures = {pool.submit(work, test): test for test in tests}
                for future in futures_completed(futures):
                    test = futures[future]
                    result = future.result()
                    done += 1
                    report["results"].append(result)
                    write_report(report_path, report)
                    show(done, test, result)
            order = {str(test.relative_to(ROOT)): i for i, test in enumerate(tests)}
            report["results"].sort(key=lambda result: order[result["test"]])
    except KeyboardInterrupt:
        report["interrupted"] = True
        write_report(report_path, report)
        print(f"Interrupted; partial evidence saved in {report_path}", file=sys.stderr)
        return 130
    report["complete"] = True
    report["passed"] = all(result["passed"] for result in report["results"])
    report["finished_at"] = datetime.now(timezone.utc).isoformat()
    report["summary"] = {status: sum(result["status"] == status for result in report["results"])
                         for status in ["passed", "pass_with_known_engine_error", "failed", "timeout"]}
    write_report(report_path, report)
    print(json.dumps(report["summary"], sort_keys=True), flush=True)
    print(f"Full output and diagnostics: {report_path}", flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
