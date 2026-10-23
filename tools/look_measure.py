#!/usr/bin/env python3
"""Measure the look of a still, and flag where it leaves the world's ranges.

    python tools/look_measure.py shot.png                       # ranges and flags
    python tools/look_measure.py before.png after.png           # side by side
    python tools/look_measure.py shot.png --crop 0.3,0.4,0.7,0.9   # a region (fractions x0,y0,x1,y1)
    python tools/look_measure.py --build-ranges docs/art/look-breakdown/day/*.png
    python tools/look_measure.py shot.png --json               # the raw numbers

Pixel work is done in headless Godot (tools/harness/look_measure.gd, the
Image API), so nothing is installed: no Pillow, no numpy. Each still is
scaled to 720 px wide first, so scales (px) compare across window sizes.
Pixels are sorted into rough material classes by hue, saturation, value and
where they sit against the horizon (the median over columns of how far sky
runs down): sky, cloud (pale above the horizon), water, grass (green land),
rock_sand (brown or grey land), flower (saturated spots), other. The rough
sort is good enough for ranges, not a segmentation: a crop is the way to
measure one thing (a tree's crown, say) exactly.

Measures: per class, value and saturation percentiles, mean hue, the lit
side (brightest tenth) against the shaded (darkest tenth) as a luma ratio,
the blotch scale (std of block-mean luma at 8 and 32 px over the std at
1 px: how much of the pixel noise is left at coarse scales), and edge
softness (luma gradient per px: median, 90th percentile, share above 0.08).
Whole picture: luma percentiles and the hue of the darkest 2 percent.
Aerial: the grass's saturation, value and hue from the nearest rows to the
farthest.

Ranges: docs/art/look-breakdown/ranges.json is the min and max of each
measure over the committed world stills (seed 1, default mood and hour,
main's endless flight, no trees). A measure outside that, by more than 5%
of the range's width, is flagged LOW or HIGH. With few stills the ranges
are loose; read a flag as "the world never looked like this in these
stills", not as an error.
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot  # noqa: E402

RANGES = godot.ROOT / "docs" / "art" / "look-breakdown" / "ranges.json"
MIN_SHARE = 0.02  # a class under this share of the picture is not compared


def run(files, crop, classes=True):
    args = ["-s", "res://tools/harness/look_measure.gd", "--", "--in=" + ",".join(str(Path(f).resolve()) for f in files)]
    if crop:
        args.append("--crop=" + crop)
    if not classes:
        args.append("--classes=0")
    r = godot.run(args)
    out = []
    for line in r["output"].splitlines():
        if line.startswith("LOOK "):
            out.append(json.loads(line[5:]))
    if len(out) != len(files):
        print("\n".join(godot.filtered(r["output"], only=True)[0]))
        sys.exit("look_measure: Godot gave %d results for %d files" % (len(out), len(files)))
    return out


def flat(m):
    """One image's numbers as {"grass.V.p50": x}."""
    f = {}
    for cname, c in m["classes"].items():
        if c["share"] < MIN_SHARE:
            continue
        for q in ("p5", "p50", "p95"):
            f["%s.V.%s" % (cname, q)] = c["V"][q]
            f["%s.S.%s" % (cname, q)] = c["S"][q]
        f[cname + ".hue"] = c["hue_mean"]
        f[cname + ".lit_dark"] = c["lit_dark_L_ratio"]
        s = c.get("scale", {})
        if "1" in s and "8" in s:
            f[cname + ".blotch8"] = round(s["8"] / s["1"], 3)
        if "1" in s and "32" in s:
            f[cname + ".blotch32"] = round(s["32"] / s["1"], 3)
        for k in ("1", "2", "4"):
            if k in s:
                f["%s.std%s" % (cname, k)] = s[k]
        for k, v in c.get("local", {}).items():
            f["%s.local%s" % (cname, k)] = v
        e = c.get("edges", {})
        for k in ("p50", "p90", "hard_share"):
            if k in e:
                f["%s.edge_%s" % (cname, k)] = e[k]
        f[cname + ".dark10_hue"] = c["dark10"]["hue"]
        f[cname + ".dark10_V"] = c["dark10"]["V"]
    w = m["whole"]
    for q in ("p1", "p5", "p50", "p95"):
        f["whole.L." + q] = w["L"][q]
    f["whole.dark2_hue"] = w["darkest2pct_hue"]
    a = m.get("aerial") or []
    if len(a) >= 2:
        n, fa = a[0], a[-1]
        f["aerial.dS"] = round(fa["S"] - n["S"], 3)
        f["aerial.dV"] = round(fa["V"] - n["V"], 3)
        f["aerial.dhue"] = round(((fa["hue"] - n["hue"] + 180) % 360) - 180, 1)
    return f


def build_ranges(files, out):
    per = [flat(m) for m in run(files, None)]
    keys = sorted({k for p in per for k in p})
    rng = {}
    for k in keys:
        v = [p[k] for p in per if k in p]
        rng[k] = {"min": min(v), "max": max(v), "n": len(v)}
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"stills": [Path(f).name for f in files], "ranges": rng}, indent=1, sort_keys=True))
    print("wrote %s: %d measures over %d stills" % (out, len(rng), len(files)))


def flag(k, v, ranges):
    r = ranges.get(k)
    if r is None or r["n"] < 2:
        return ""
    w = max(r["max"] - r["min"], 0.02 if "hue" not in k else 5.0)
    if k.endswith("hue") or "_hue" in k or "dhue" in k:
        # Hue wraps: compare on the circle around the range's midpoint.
        mid = (r["min"] + r["max"]) / 2
        d = ((v - mid + 180) % 360) - 180
        half = (r["max"] - r["min"]) / 2
        if d > half + 0.05 * w:
            return "HIGH"
        if d < -half - 0.05 * w:
            return "LOW"
        return ""
    if v < r["min"] - 0.05 * w:
        return "LOW"
    if v > r["max"] + 0.05 * w:
        return "HIGH"
    return ""


def table(names, flats, ranges, only_flags):
    keys = sorted({k for f in flats for k in f}, key=lambda k: (k.split(".")[0], k))
    order = ["whole", "aerial", "sky", "cloud", "water", "grass", "rock_sand", "flower", "other"]
    keys.sort(key=lambda k: (order.index(k.split(".")[0]) if k.split(".")[0] in order else 99, k))
    head = "%-24s" % "measure" + "".join("%-18s" % n[:17] for n in names) + ("   world range" if ranges else "")
    print(head)
    last = None
    for k in keys:
        cells, flags = [], []
        for f in flats:
            v = f.get(k)
            fl = flag(k, v, ranges) if (v is not None and ranges) else ""
            flags.append(fl)
            cells.append("%-18s" % ("-" if v is None else "%g%s" % (v, " " + fl if fl else "")))
        if only_flags and not any(flags):
            continue
        grp = k.split(".")[0]
        if grp != last:
            print("  [%s]" % grp)
            last = grp
        r = ranges.get(k) if ranges else None
        rs = "   %g .. %g" % (r["min"], r["max"]) if r else ""
        print("%-24s" % k + "".join(cells) + rs)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0], formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    ap.add_argument("stills", nargs="*", help="one still, or two to compare")
    ap.add_argument("--crop", help="x0,y0,x1,y1 as fractions of the picture (e.g. a tree's crown)")
    ap.add_argument("--ranges", default=str(RANGES), help="the world's ranges (default: docs/art/look-breakdown/ranges.json)")
    ap.add_argument("--build-ranges", action="store_true", help="write the ranges from these stills (the world's)")
    ap.add_argument("--out", help="where --build-ranges writes")
    ap.add_argument("--flags-only", action="store_true", help="print only the measures outside the ranges")
    ap.add_argument("--json", action="store_true", help="print the raw numbers")
    ap.add_argument("--no-classes", action="store_true", help="one class, all pixels (for a crop of one thing)")
    a = ap.parse_args()
    if not a.stills:
        ap.error("give a still")
    if a.build_ranges:
        build_ranges(a.stills, Path(a.out) if a.out else RANGES)
        return
    res = run(a.stills, a.crop, not a.no_classes)
    if a.json:
        print(json.dumps(res, indent=1))
        return
    rp = Path(a.ranges)
    ranges = json.loads(rp.read_text())["ranges"] if rp.exists() and not a.no_classes else {}
    if a.no_classes and rp.exists():
        # One class named "all": compare it against the world's grass by name.
        ranges = {k.replace("grass.", "all.", 1): v for k, v in json.loads(rp.read_text())["ranges"].items() if k.startswith("grass.")}
    for m in res:
        print("%s  measured at %dx%d (crop %s), horizon at %.0f%% down" % (m["file"], m["measured"][0], m["measured"][1], m["crop"], m["horizon"] * 100))
        print("  class shares: " + ", ".join("%s %.0f%%" % (k, v["share"] * 100) for k, v in m["classes"].items()))
        print("  darkest 2%% of pixels: rgb %s, hue %.0f; luma p0.1 %.3f" % (m["whole"]["darkest2pct_rgb"], m["whole"]["darkest2pct_hue"], m["whole"]["darkest_L_p0_1"]))
    table([m["file"] for m in res], [flat(m) for m in res], ranges, a.flags_only)


if __name__ == "__main__":
    main()
