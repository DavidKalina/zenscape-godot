#!/usr/bin/env python3
"""Check the continuously animated ten-second God Mode capture for held frames."""
import argparse
import json
import shutil
import subprocess


def check(path):
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("ffmpeg is required to inspect decoded video frames")
    output = subprocess.check_output(
        [ffmpeg, "-v", "error", "-i", path, "-an", "-f", "framemd5", "-"],
        text=True,
    )
    hashes = [line.rsplit(",", 1)[-1].strip() for line in output.splitlines()
              if line and not line.startswith("#")]
    duplicates = sum(a == b for a, b in zip(hashes, hashes[1:]))
    run = longest = 1
    for a, b in zip(hashes, hashes[1:]):
        run = run + 1 if a == b else 1
        longest = max(longest, run)
    fraction = duplicates / max(1, len(hashes))
    result = {"frames": len(hashes), "duplicate_frames": duplicates,
              "duplicate_fraction": fraction, "longest_identical_run": longest,
              "passed": len(hashes) >= 590 and fraction <= 0.02 and longest <= 2}
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video")
    args = parser.parse_args()
    result = check(args.video)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["passed"] else 1)
