#!/usr/bin/env python3
"""Crop matching regions out of two same-size captures and compare them.

    python3 tools/compare_captures.py A.png B.png OUTDIR [--regions=name:x,y,w,h ...]

Uses only macOS `sips` (crops) and `ffmpeg` (raw pixel readback), because the
system Python has no PIL. For every region it writes OUTDIR/<A>-<name>.png and
OUTDIR/<B>-<name>.png at 100 % and prints the mean RGB of each side, the mean
absolute per-channel difference, and an edge-busyness figure (mean absolute
horizontal neighbour difference) that rises with aliasing and dither.
"""
import os
import subprocess
import sys

DEFAULT_REGIONS = {
    "A-treeline": (850, 500, 500, 300),
    "B-summit": (1050, 380, 400, 300),
    "C-meadow": (1300, 1120, 500, 300),
    "D-falls": (1250, 700, 300, 320),
    "sky": (100, 100, 200, 200),
    "sky-low": (2200, 400, 200, 200),
    "soil": (500, 1300, 100, 100),
}


def raw(path, x, y, w, h):
    out = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-vf", "crop=%d:%d:%d:%d" % (w, h, x, y), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True, check=True).stdout
    return out, w, h


def stats(buf, w, h):
    n = len(buf) // 3
    mean = [sum(buf[c::3]) / n for c in range(3)]
    busy = 0
    count = 0
    for row in range(h):
        base = row * w * 3
        line = buf[base:base + w * 3]
        for i in range(3, len(line)):
            busy += abs(line[i] - line[i - 3])
            count += 1
    return mean, busy / max(1, count)


def main():
    a, b, outdir = sys.argv[1:4]
    regions = dict(DEFAULT_REGIONS)
    for arg in sys.argv[4:]:
        if arg.startswith("--regions="):
            regions = {}
            for spec in arg[len("--regions="):].split(";"):
                name, nums = spec.split(":")
                regions[name] = tuple(int(v) for v in nums.split(","))
        elif arg.startswith("--region="):
            name, nums = arg[len("--region="):].split(":")
            regions[name] = tuple(int(v) for v in nums.split(","))
    os.makedirs(outdir, exist_ok=True)
    stem_a = os.path.splitext(os.path.basename(a))[0]
    stem_b = os.path.splitext(os.path.basename(b))[0]
    print("%-12s %-22s %-22s %-8s %-7s %-7s" % ("region", stem_a[:22] + " mean", stem_b[:22] + " mean", "|diff|", "busyA", "busyB"))
    for name, (x, y, w, h) in regions.items():
        for path, stem in ((a, stem_a), (b, stem_b)):
            if w >= 200 and h >= 200:
                subprocess.run(["sips", "-c", str(h), str(w), "--cropOffset", str(y), str(x), path, "--out", os.path.join(outdir, "%s-%s.png" % (stem, name))],
                               capture_output=True, check=True)
        ra, _, _ = raw(a, x, y, w, h)
        rb, _, _ = raw(b, x, y, w, h)
        ma, busy_a = stats(ra, w, h)
        mb, busy_b = stats(rb, w, h)
        diff = sum(abs(p - q) for p, q in zip(ra, rb)) / len(ra)
        print("%-12s %5.1f %5.1f %5.1f      %5.1f %5.1f %5.1f      %6.2f   %5.2f   %5.2f" % (name, *ma, *mb, diff, busy_a, busy_b))


if __name__ == "__main__":
    main()
