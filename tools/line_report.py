#!/usr/bin/env python3
"""Re-score a near-miss line log and print each line as a card.

A log comes from the game's `--line-log=res://scratch/line1.csv` (scripts/
endless/line_log.gd: one row per moment, one per line's end). This re-scores
it from the raw columns with the formula in scripts/endless/line_tune.json (the
same steps as scripts/endless/line_score.gd), so a tuning change can be tried
on a flight already flown.

  python3 tools/line_report.py scratch/line1.csv
  python3 tools/line_report.py scratch/easy.csv scratch/hard.csv     # side by side
  python3 tools/line_report.py scratch/line1.csv --set run_scale=0.15 --set base.thread=1.5
  python3 tools/line_report.py scratch/line1.csv --check   # re-scored = logged totals?

A card: the line's parts in order (a run: kind x n at pace, its moments and
bonus; a flourish: its kind and top two factors; plain moments), the
multiplier, the top factors (their averages over the line) and the total, in
the score's units. With two logs, the last line of each prints the ratio of
their best lines. --check exits 1 when a re-scored running total misses the
logged one (with the tuning as logged: no --set).
"""
import argparse
import csv
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TUNE_PATH = os.path.join(ROOT, "scripts", "endless", "line_tune.json")
FACTORS = ["close", "fast", "knife", "low", "under"]
TAGS = {"close": "CLOSE", "fast": "FAST", "knife": "KNIFE", "low": "LOW", "under": "UNDER"}


def load_tune(sets):
    with open(TUNE_PATH) as f:
        tune = json.load(f)
    for s in sets:
        key, _, value = s.partition("=")
        try:
            v = json.loads(value)
        except json.JSONDecodeError:
            v = value
        node = tune
        parts = key.split(".")
        for p in parts[:-1]:
            node = node.setdefault(p, {})
        node[parts[-1]] = v
    return tune


def ramp(x, a, b, cap):
    if abs(a - b) < 1e-9:
        return 1.0
    return 1.0 + (cap - 1.0) * min(max((x - a) / (b - a), 0.0), 1.0)


def factors(r, t):
    k = min(max(r["k"], 0.0), 1.0)
    f = {
        "close": 1.0 + (t["close_cap"] - 1.0) * math.pow(k, t["close_pow"]),
        "fast": ramp(r["speed"], r["cruise"], r["top"], t["fast_cap"]),
        "knife": ramp(min(abs(r["roll_deg"]), 90.0), t["knife_from"], t["knife_to"], t["knife_cap"]),
        "low": ramp(r["height"], t["low_from"], t["low_to"], t["low_cap"]),
        "under": t["under"] if r["under"] else 1.0,
    }
    p = 1.0
    for n in FACTORS:
        p *= f[n]
    f["product"] = p
    return f


def run_bonus(n, sum_fast, t):
    if n < int(t["run_min"]):
        return 0.0
    return t["run_scale"] * math.pow(n, t["run_pow"]) * sum_fast / n


def num(v, default=0.0):
    try:
        return float(v) if v != "" else default
    except ValueError:
        return default


def read_log(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


class Line:
    def __init__(self, ident):
        self.id = ident
        self.units = 0.0
        self.mult = 1.0
        self.runs = []      # dicts: kind surface n sum_fast sum_product last_t moments(list)
        self.parts = []     # ("run", run) or ("flourish", moment) in order of first appearance
        self.moments = []
        self.end = None

    def add(self, m, t):
        last = self.runs[-1] if self.runs else None
        same = last is not None and last["kind"] == m["kind"] and last["surface"] == m["surface"]
        flourish = False
        if same and m["t"] - last["last_t"] <= t["run_echo"]:
            last["last_t"] = m["t"]
            last["moments"].append(m)
            run = last
        elif same and m["t"] - last["last_t"] <= t["run_gap"]:
            last["n"] += 1
            last["sum_fast"] += m["f"]["fast"]
            last["sum_product"] += m["f"]["product"]
            last["last_t"] = m["t"]
            last["moments"].append(m)
            run = last
        else:
            ref = next((r for r in reversed(self.runs) if r["n"] >= int(t["flourish_min_run"])), None)
            if ref is not None and not ref.get("spent") and (ref["kind"] != m["kind"] or ref["surface"] != m["surface"]):
                avg = ref["sum_product"] / ref["n"]
                if m["f"]["product"] > avg * t["flourish_margin"]:
                    flourish = True
                    ref["spent"] = True
                    self.mult = min(self.mult + t["flourish_step"], t["line_cap"])
            run = {"kind": m["kind"], "surface": m["surface"], "n": 1, "sum_fast": m["f"]["fast"],
                   "sum_product": m["f"]["product"], "last_t": m["t"], "moments": [m], "flourish": flourish}
            self.runs.append(run)
        m["flourish"] = flourish
        self.units += m["units"]
        self.moments.append(m)
        return run

    def raw(self, t):
        return self.units + sum(run_bonus(r["n"], r["sum_fast"], t) for r in self.runs)

    def total(self, t):
        return self.raw(t) * self.mult


def run_name(kind, surface):
    if kind == "graze":
        return {"tree": "TREES", "stone": "STONE", "land": "LAND", "water": "WAVES"}.get(surface, "GRAZES")
    if kind == "thread":
        return "ARCHES" if surface == "stone" else "THREADS"
    if kind == "pull-out":
        return "SKIPS" if surface == "water" else "PULL-OUTS"
    return kind.upper()


def moment(r, t):
    """A log row's moment, re-scored from its raw columns."""
    raw = {"k": num(r["k"]), "speed": num(r["speed"]), "cruise": num(r["cruise"], 1.0), "top": num(r["top"], 1.0),
           "roll_deg": num(r["roll_deg"]), "height": num(r["height"], 1e9), "under": r["under"] == "1"}
    f = factors(raw, t)
    base = t["base"].get(r["kind"], t["base"]["default"])
    units = base * t["band"].get(r["band"], 1.0) * f["product"] * num(r["hold"], 1.0) * num(r["farm"], 1.0)
    return {"kind": r["kind"], "move": r["move"], "surface": r["surface"], "band": r["band"], "t": num(r["t"]),
            "f": f, "units": units, "speed": raw["speed"], "cruise": raw["cruise"], "clear": num(r["clear"])}


def replay(rows, t):
    """The log's lines re-scored in order, and the misses against the logged
    columns [(line, where, logged, ours)]."""
    lines = {}
    order = []
    misses = []
    skip = set(t.get("skip", []))

    def same(ident, where, logged, ours):
        if abs(logged - ours) > 1e-3 * max(1.0, abs(logged)):
            misses.append((ident, where, logged, ours))

    for r in rows:
        ident = r["line"]
        if ident not in lines:
            lines[ident] = Line(ident)
            order.append(ident)
        line = lines[ident]
        if r["row"] == "end":
            line.end = r.get("reason", "")
        elif r["kind"] in skip:
            continue
        else:
            m = moment(r, t)
            line.add(m, t)
            same(ident, r["t"] + " points", num(r["points"]), m["units"])
            same(ident, r["t"] + " mult", num(r["mult"]), line.mult)
        same(ident, r["t"] + " total", num(r["line_total"]), line.total(t))
    return [lines[i] for i in order], misses


def card(line, t):
    out = []
    total = line.total(t)
    secs = line.moments[-1]["t"] - line.moments[0]["t"] if line.moments else 0.0
    out.append("LINE %s  %.1f  x%.1f  %d moments %.1f s%s" % (
        line.id, total, line.mult, len(line.moments), secs, ("  [" + line.end + "]") if line.end else ""))
    for r in line.runs:
        ms = r["moments"]
        units = sum(m["units"] for m in ms)
        if r["flourish"]:
            m = ms[0]
            top = sorted(FACTORS, key=lambda n: -m["f"][n])[:2]
            out.append("  * FLOURISH %s/%s %s  %s  %.2f" % (
                m["move"], m["surface"], m["band"], " ".join("%s %.2f" % (TAGS[n], m["f"][n]) for n in top), m["units"]))
            if len(ms) > 1:
                rest = ms[1:]
                out.append("    then x%d more  %.2f" % (len(rest), sum(x["units"] for x in rest)))
            if r["n"] >= int(t["run_min"]):
                out.append("    (run x%d bonus %.2f)" % (r["n"], run_bonus(r["n"], r["sum_fast"], t)))
        elif r["n"] >= int(t["run_min"]):
            pace = sum(m["speed"] / max(m["cruise"], 1.0) for m in ms) / len(ms)
            bonus = run_bonus(r["n"], r["sum_fast"], t)
            out.append("  run %s x%d at pace %.2f  %.2f + bonus %.2f" % (
                run_name(r["kind"], r["surface"]), r["n"], pace, units, bonus))
        else:
            for m in ms:
                top = sorted(FACTORS, key=lambda n: -m["f"][n])[:2]
                tags = " ".join("%s %.2f" % (TAGS[n], m["f"][n]) for n in top if m["f"][n] > 1.0)
                out.append("  %s/%s %s %.1fm  %s  %.2f" % (m["move"], m["surface"], m["band"], m["clear"], tags, m["units"]))
    if line.moments:
        avg = {n: sum(m["f"][n] for m in line.moments) / len(line.moments) for n in FACTORS}
        top = sorted(FACTORS, key=lambda n: -avg[n])[:3]
        out.append("  factors: " + "  ".join("%s %.2f" % (TAGS[n], avg[n]) for n in top))
    out.append("  = %.2f  (%.2f x%.1f)" % (total, line.raw(t), line.mult))
    return out


def report(path, t):
    rows = read_log(path)
    lines, _ = replay(rows, t)
    text = [os.path.basename(path), ""]
    for line in lines:
        text += card(line, t) + [""]
    best = max((l.total(t) for l in lines), default=0.0)
    return text, best, lines


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("logs", nargs="+")
    ap.add_argument("--set", action="append", default=[], help="key=value over line_tune.json (base.thread=1.5)")
    ap.add_argument("--check", action="store_true", help="re-scored running totals must match the logged ones")
    ap.add_argument("--width", type=int, default=64)
    a = ap.parse_args()
    t = load_tune(a.set)
    if a.check:
        bad = 0
        for p in a.logs:
            rows = read_log(p)
            _, misses = replay(rows, t)
            n = sum(1 for r in rows if r["row"] == "moment")
            if misses:
                bad += 1
                print("FAIL %s: %d of %d rows off" % (p, len(misses), len(rows)))
                for ident, tt, logged, ours in misses[:8]:
                    print("  line %s t %s logged %.4f re-scored %.4f" % (ident, tt, logged, ours))
            else:
                print("OK   %s: %d moments, %d lines, every running total matches" % (
                    p, n, len({r["line"] for r in rows})))
        sys.exit(1 if bad else 0)
    reports = [report(p, t) for p in a.logs]
    if len(reports) == 1:
        print("\n".join(reports[0][0]))
        return
    cols = [r[0] for r in reports]
    h = max(len(c) for c in cols)
    w = a.width
    for i in range(h):
        print("  ".join((c[i] if i < len(c) else "")[:w].ljust(w) for c in cols).rstrip())
    bests = [r[1] for r in reports]
    print("best lines: " + "  ".join("%.2f" % b for b in bests) +
          ("   ratio %.1fx" % (max(bests) / min(bests)) if min(bests) > 0 else ""))


if __name__ == "__main__":
    main()
