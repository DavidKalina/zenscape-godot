#!/usr/bin/env python3
"""What a --frame-log file says about stutter: the pace, the spikes and their causes.

python tools/frame_report.py LOG.csv [BEFORE.csv] [--skip SECONDS] [--top N]

A hitch here is a frame over twice the median of the second round it. Jitter
is the middle 90% of the change from one frame to the next, which is what the
eye reads as uneven motion even when the average is fine. Each hitch names
the tick part that took the most (`scripts/frame_log.gd`) or, when the tick
wasn't it, the engine's: pipelines compiled, physics, render, or wait. With a
BEFORE log the two are printed side by side.
"""
import argparse, csv, statistics


def load(path, skip):
    # The log heads itself again when a new part turns up.
    rows, head = [], []
    with open(path, newline="") as f:
        for line in csv.reader(f):
            if line[0] == "t":
                head = line
            elif len(line) >= len(head):
                rows.append({"drawn": 1.0} | {k: _num(v) for k, v in zip(head, line)})
    known = set().union(*(r.keys() for r in rows))
    rows = [{k: 0.0 for k in known} | r for r in rows]
    # A long gap with more physics steps than a frame can hold (8) is the
    # flight held by photo mode or the logbook, frames going on without a tick.
    return [r for r in rows if r["t"] >= skip and r["drawn"] <= 1 and r["physics_steps"] <= 8]


def _num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def pct(sorted_values, p):
    return sorted_values[min(len(sorted_values) - 1, int(len(sorted_values) * p))]


FIXED = ("t", "frame", "tick", "drawn", "physics_steps", "physics_ms", "render_cpu", "render_gpu", "pipelines",
         "draws", "objects", "nodes", "vram_mb", "x", "y", "z", "speed")


def summary(rows):
    fr = sorted(r["frame"] for r in rows)
    steps = sorted(abs(b["frame"] - a["frame"]) for a, b in zip(rows, rows[1:]))
    seconds = sum(fr) / 1000.0
    return {
        "frames": len(rows), "seconds": round(seconds, 1), "fps": round(len(rows) / seconds, 1),
        "median": round(pct(fr, 0.5), 2), "p95": round(pct(fr, 0.95), 2), "p99": round(pct(fr, 0.99), 2),
        "p99.9": round(pct(fr, 0.999), 2), "worst": round(fr[-1], 1),
        "jitter_p50": round(pct(steps, 0.5), 2), "jitter_p95": round(pct(steps, 0.95), 2),
        "over_16.7": sum(1 for v in fr if v > 16.7), "over_25": sum(1 for v in fr if v > 25.0),
        "over_33": sum(1 for v in fr if v > 33.3), "over_50": sum(1 for v in fr if v > 50.0),
        "hitches_per_min": round(len(hitches(rows)) / seconds * 60.0, 1),
    }


def hitches(rows):
    out = []
    window = 240
    for i, r in enumerate(rows):
        near = sorted(x["frame"] for x in rows[max(0, i - window // 2):i + window // 2])
        floor = max(2.0 * near[len(near) // 2], 12.0)
        if r["frame"] > floor:
            out.append((i, r, near[len(near) // 2]))
    return out


def cause(rows, i, parts):
    # The frame interval closes at this tick's end: the render it shows is the
    # one that came before this tick, so a slow present lands on the same row.
    r = rows[i]
    prev = rows[i - 1] if i > 0 else r
    named = sorted(((r[p], p) for p in parts), reverse=True)[:2]
    outside = r["frame"] - r["tick"]
    bits = []
    if r["pipelines"] or prev["pipelines"]:
        bits.append("pipelines %d" % (r["pipelines"] + prev["pipelines"]))
    if r["physics_steps"] > 1:
        bits.append("%d physics steps" % r["physics_steps"])
    if r["tick"] > outside:
        return "tick: " + ", ".join("%s %.1f" % (p, v) for v, p in named if v > 0.5), bits
    return "outside tick %.1f (render cpu %.1f gpu %.1f)" % (outside, prev["render_cpu"], prev["render_gpu"]), bits


def report(path, skip, top):
    rows = load(path, skip)
    parts = [k for k in rows[0] if k not in FIXED]
    s = summary(rows)
    print("==", path)
    print(" ", " ".join("%s=%s" % kv for kv in s.items()))
    n = len(rows)
    print("  main: tick %.2f (p99 %.2f), physics %.2f, render_cpu %.2f, gpu %.2f, outside tick %.2f; pipelines %d; draws %.0f, objects %.0f" % (
        statistics.mean(r["tick"] for r in rows), pct(sorted(r["tick"] for r in rows), 0.99),
        statistics.mean(r["physics_ms"] for r in rows),
        statistics.mean(r["render_cpu"] for r in rows), statistics.mean(r["render_gpu"] for r in rows),
        statistics.mean(r["frame"] - r["tick"] for r in rows),
        sum(r["pipelines"] for r in rows), statistics.mean(r["draws"] for r in rows), statistics.mean(r["objects"] for r in rows)))
    means = sorted(((sum(r[p] for r in rows) / n, max(r[p] for r in rows), p) for p in parts), reverse=True)
    print("  parts, mean / worst ms:", ", ".join("%s %.2f/%.1f" % (p, m, w) for m, w, p in means[:16]))
    hs = hitches(rows)
    print("  %d hitches, worst %d:" % (len(hs), min(top, len(hs))))
    for i, r, base in sorted(hs, key=lambda h: -h[1]["frame"])[:top]:
        why, bits = cause(rows, i, parts)
        print("   t=%6.1f %6.1f ms (around %.1f) at %d,%d alt %d: %s%s" % (
            r["t"], r["frame"], base, r["x"], r["z"], r["y"], why, " [" + ", ".join(bits) + "]" if bits else ""))
    return s


def main():
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("logs", nargs="+")
    a.add_argument("--skip", type=float, default=2.0, help="seconds dropped from the start")
    a.add_argument("--top", type=int, default=25)
    o = a.parse_args()
    all_s = [report(p, o.skip, o.top) for p in o.logs]
    if len(all_s) == 2:
        print("== before -> after")
        for k in all_s[0]:
            print("  %-16s %10s %10s" % (k, all_s[0][k], all_s[1][k]))


if __name__ == "__main__":
    main()
