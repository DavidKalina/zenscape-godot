#!/usr/bin/env python3
"""How long streamed pieces took to be drawn on a flight, and where they waited.

    python tools/stream_report.py scratch/f1.csv.stream.csv [other.stream.csv] [--skip S]

Reads the log scripts/stream_log.gd writes beside a --frame-log. One line per
layer and level: how many pieces, the wait from wanted to drawn (median, p90,
worst, s), the share of all waiting spent in each part (queue: waiting to be
asked of the pool; pool: waiting for a worker; build: the worker's work;
commit: waiting for the main thread; hold: a mesh waiting to be drawn), the
median build (ms) and the median distance from the eye when wanted and when
drawn (m). --skip S drops the first S seconds (the takeoff).
"""
import csv
import sys
from collections import defaultdict

PARTS = ["queue_ms", "pool_ms", "build_ms", "commit_ms", "hold_ms"]


def pct(values, p):
    if not values:
        return 0.0
    s = sorted(values)
    return s[min(len(s) - 1, int(p * len(s)))]


def report(path, skip):
    groups = defaultdict(list)
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            if float(row["t"]) < skip:
                continue
            groups[(row["layer"], int(row["level"]))].append(row)
    print(f"== {path}")
    if not groups:
        print("   no rows")
        return
    print(f"{'layer':<10} {'lvl':>3} {'n':>5} {'med s':>6} {'p90 s':>6} {'max s':>6}  "
          f"{'queue':>5} {'pool':>5} {'build':>5} {'commit':>6} {'hold':>5}  {'build ms':>8} {'want m':>6} {'drawn m':>7}")
    for (layer, level), rows in sorted(groups.items()):
        total = [float(r["total_ms"]) / 1000.0 for r in rows]
        sums = {p: sum(float(r[p]) for r in rows) for p in PARTS}
        whole = sum(sums.values()) or 1.0
        share = [f"{100.0 * sums[p] / whole:.0f}%" for p in PARTS]
        print(f"{layer:<10} {level:>3} {len(rows):>5} {pct(total, 0.5):>6.2f} {pct(total, 0.9):>6.2f} {max(total):>6.2f}  "
              f"{share[0]:>5} {share[1]:>5} {share[2]:>5} {share[3]:>6} {share[4]:>5}  "
              f"{pct([float(r['build_ms']) for r in rows], 0.5):>8.1f} "
              f"{pct([float(r['dist_want']) for r in rows], 0.5):>6.0f} {pct([float(r['dist_show']) for r in rows], 0.5):>7.0f}")


def main():
    args = sys.argv[1:]
    skip = 0.0
    if "--skip" in args:
        i = args.index("--skip")
        skip = float(args[i + 1])
        del args[i:i + 2]
    if not args:
        print(__doc__)
        return 2
    for path in args:
        report(path, skip)
    return 0


if __name__ == "__main__":
    sys.exit(main())
