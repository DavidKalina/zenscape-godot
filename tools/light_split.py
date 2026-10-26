#!/usr/bin/env python3
"""Read tools/harness/light_split.gd's runs.

  python tools/light_split.py shares LOG [LOG...]     # each light's share per class, summed over the views
  python tools/light_split.py views LOG [LOG...]      # the same per view, with the view's bearing to the sun
  python tools/light_split.py stats BEFORE_LOG AFTER_LOG [--views a,b]   # each run's own classes, not pixel-matched
  python tools/light_split.py match BEFORE AFTER [--views a,b] [--min-agree 0.8]   # pixel-matched V, S, B/R over BEFORE's masks

A LOG is the light_split run's output (drive.py ... > LOG). BEFORE and AFTER
are its --out folders; BEFORE's run needs --save-mask. With AFTER's masks
too, a view where under --min-agree of the classed pixels keep their class
is skipped: the land and trees stream in on worker threads, and now and then
a run holds a view with them in a different state (and the clouds' places
can differ run to run: --no-clouds for land numbers). Classes: grass, rock,
tree, each _lit (the sun gives over 60%) or _shade (under 10%), and
haze_far (far land, the depth fog over 40% of its light).
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


def stats(blog, alog, views):
    """Each class's on-screen median V and S (n-weighted over the views) and
    its linear B/R, in two runs' own classes: not pixel-matched, so steady
    when the runs' frames differ a little."""
    def agg(path):
        t = {}
        for r in rows(path):
            if views and r["view"] not in views:
                continue
            for k, c in r["classes"].items():
                a = t.setdefault(k, {"n": 0, "V": 0.0, "S": 0.0, "f": [0.0, 0.0, 0.0]})
                n = c["n"]
                a["n"] += n
                a["V"] += c["V"] * n
                a["S"] += c["S"] * n
                for i in range(3):
                    a["f"][i] += c["full"][i] * n
        return t
    A, B = agg(blog), agg(alog)
    print("== %s -> %s (%s)" % (blog, alog, ",".join(views) if views else "all views"))
    for k in sorted(set(A) | set(B)):
        if k not in A or k not in B:
            print("  %-12s only in %s" % (k, "before" if k in A else "after"))
            continue
        a, b = A[k], B[k]
        V, V2 = a["V"] / a["n"], b["V"] / b["n"]
        S, S2 = a["S"] / a["n"], b["S"] / b["n"]
        br = a["f"][2] / max(a["f"][0], 1e-6)
        br2 = b["f"][2] / max(b["f"][0], 1e-6)
        print("  %-12s n %6d -> %6d  V %.3f -> %.3f (%+5.1f%%)  S %.3f -> %.3f (%+5.1f%%)  B/R(lin) %.2f -> %.2f" % (
            k, a["n"], b["n"], V, V2, (V2 / V - 1) * 100, S, S2, (S2 / S - 1) * 100, br, br2))


def match(bdir, adir, views, min_agree=0.8):
    if not views:
        views = sorted(p.stem[:-5] for p in Path(bdir).glob("*_mask.png"))
    tot = {}
    for v in views:
        m = os.path.abspath(f"{bdir}/{v}_mask.png")
        a = os.path.abspath(f"{bdir}/{v}.png")
        b = os.path.abspath(f"{adir}/{v}.png")
        if not (os.path.exists(m) and os.path.exists(b)):
            continue
        m2 = os.path.abspath(f"{adir}/{v}_mask.png")
        extra = ["--mask2=" + m2] if os.path.exists(m2) else []
        r = godot.run(["-s", "res://tools/harness/light_match.gd", "--", "--mask=" + m, *extra, a, b])
        lines = [x for x in r["output"].splitlines() if x.startswith("CMP ")]
        if not lines:
            print("no CMP line for", v)
            continue
        d = json.loads(lines[0][4:])
        agree = d.get("agree")
        if agree is not None and agree < min_agree:
            print("  (skipped %s: only %.0f%% of its pixels keep their class: the runs' land or trees differ)" % (v, agree * 100))
            continue
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
    if not a or a[0] not in ("shares", "views", "match", "stats"):
        print(__doc__)
        return 1
    if a[0] in ("shares", "views"):
        shares(a[1:], a[0] == "views")
    elif a[0] == "stats":
        views = []
        if "--views" in a:
            i = a.index("--views")
            views = a[i + 1].split(",")
            del a[i:i + 2]
        stats(a[1], a[2], views)
    else:
        views = []
        if "--views" in a:
            i = a.index("--views")
            views = a[i + 1].split(",")
            del a[i:i + 2]
        min_agree = 0.8
        if "--min-agree" in a:
            i = a.index("--min-agree")
            min_agree = float(a[i + 1])
            del a[i:i + 2]
        match(a[1], a[2], views, min_agree)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
