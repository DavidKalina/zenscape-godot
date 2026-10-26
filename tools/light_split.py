#!/usr/bin/env python3
"""Read tools/harness/light_split.gd's runs.

  python tools/light_split.py shares LOG [LOG...]     # each light's share per class, summed over the views
  python tools/light_split.py views LOG [LOG...]      # the same per view, with the view's bearing to the sun
  python tools/light_split.py match BEFORE AFTER [--views a,b]   # pixel-matched V, S, B/R over BEFORE's masks

A LOG is the light_split run's output (drive.py ... > LOG). BEFORE and AFTER
are its --out folders; BEFORE's run needs --save-mask. Classes: grass, rock,
tree, each _lit (the sun gives over 60%) or _shade (under 10%).
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot  # noqa: E402


def luma(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def rel(c):
    lu = luma(c)
    return "(%.2f,%.2f,%.2f)" % tuple(x / lu for x in c) if lu > 1e-6 else "-"


def rows(path):
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("ROW "):
            yield json.loads(line[4:])


def shares(paths, per_view=False):
    for path in paths:
        groups = {}
        meta = None
        for r in rows(path):
            meta = meta or r
            key = r["view"] if per_view else ""
            g = groups.setdefault(key, ({}, r))
            for k, c in r["classes"].items():
                a = g[0].setdefault(k, {"n": 0, **{t: [0.0, 0.0, 0.0] for t in ("full", "sun", "fill", "rim", "none", "fog")}})
                n = c["n"]
                a["n"] += n
                for t in ("full", "sun", "fill", "rim", "none", "fog"):
                    for i in range(3):
                        a[t][i] += c.get(t, [0, 0, 0])[i] * n
        if meta is None:
            print("==", path, "no ROW lines")
            continue
        print("==", path, meta["mood"], meta["hour"], "h, sun_y", meta["sun_y"], "fog", meta.get("fog"), "aerial", meta.get("fog_aerial"), "scatter", meta.get("fog_scatter"), meta.get("window"))
        for key, (agg, r) in groups.items():
            if per_view:
                print(" -- %s (to_sun %s)" % (key, r.get("to_sun")))
            for k in sorted(agg):
                a = agg[k]
                n = a["n"]
                f, s, l, ri, no, fo = ([x / n for x in a[t]] for t in ("full", "sun", "fill", "rim", "none", "fog"))
                F = luma(f)
                print("  %-12s n=%6d full=%.4f  sun %3.0f%%  fill %3.0f%%  rim %3.0f%%  other %3.0f%% (fog %3.0f%%)  sun:fill %5.1f  hue %s  fog hue %s" % (
                    k, n, F, 100 * luma(s) / F, 100 * luma(l) / F, 100 * luma(ri) / F, 100 * luma(no) / F, 100 * luma(fo) / F,
                    luma(s) / max(luma(l), 1e-5), rel(f), rel(fo)))


def match(bdir, adir, views):
    if not views:
        views = sorted(p.stem[:-5] for p in Path(bdir).glob("*_mask.png"))
    tot = {}
    for v in views:
        m = os.path.abspath(f"{bdir}/{v}_mask.png")
        a = os.path.abspath(f"{bdir}/{v}.png")
        b = os.path.abspath(f"{adir}/{v}.png")
        if not (os.path.exists(m) and os.path.exists(b)):
            continue
        r = godot.run(["-s", "res://tools/harness/light_match.gd", "--", "--mask=" + m, a, b])
        lines = [x for x in r["output"].splitlines() if x.startswith("CMP ")]
        if not lines:
            print("no CMP line for", v)
            continue
        d = json.loads(lines[0][4:])
        for k, c in d[a].items():
            c2 = d[b].get(k)
            if not c2:
                continue
            t = tot.setdefault(k, {"n": 0, "V": 0, "S": 0, "V2": 0, "S2": 0, "rgb": [0, 0, 0], "rgb2": [0, 0, 0]})
            n = c["n"]
            t["n"] += n
            for i in range(3):
                t["rgb"][i] += c["rgb"][i] * n
                t["rgb2"][i] += c2["rgb"][i] * n
            for key, src in (("V", c["V"]), ("S", c["S"]), ("V2", c2["V"]), ("S2", c2["S"])):
                t[key] += src * n
    print("== %s -> %s (%s)" % (bdir, adir, ",".join(views)))
    for k in sorted(tot):
        t = tot[k]
        n = t["n"]
        V, S, V2, S2 = (t[x] / n for x in ("V", "S", "V2", "S2"))
        a = [x / n for x in t["rgb"]]
        b = [x / n for x in t["rgb2"]]
        print("  %-12s n=%6d  V %.3f -> %.3f (%+5.1f%%)  S %.3f -> %.3f (%+5.1f%%)  B/R %.2f -> %.2f" % (
            k, n, V, V2, (V2 / V - 1) * 100, S, S2, (S2 / S - 1) * 100, a[2] / a[0], b[2] / b[0]))


def main() -> int:
    a = sys.argv[1:]
    if not a or a[0] not in ("shares", "views", "match"):
        print(__doc__)
        return 1
    if a[0] in ("shares", "views"):
        shares(a[1:], a[0] == "views")
    else:
        views = []
        if "--views" in a:
            i = a.index("--views")
            views = a[i + 1].split(",")
            del a[i:i + 2]
        match(a[1], a[2], views)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
