#!/usr/bin/env python3
"""The railroad's line: the drafted route (docs/design/endless-flight/railroad/)
refined at the land's own resolution into the rail path the game reads.

python tools/rail_line.py [--grid scratch/rail/world10.json] [--fresh-grid]
                          [--out assets/railroad/rail_line.json]
                          [--map docs/design/endless-flight/railroad/rail-line.jpg]

1. The plan view: the draft's points become the control points of a closed
   cubic B-spline (one every CTRL m), smoothed where it bends tighter than
   R_MIN, then measured and resampled every STEP m: the exact curve.
2. The land under it: tools/harness/rail_sample.gd reads the live field's
   height (and river water) at every sample, on the centre line and both bed
   edges. The 10 m grid (tools/site_map.py's JSON) is only for the picture.
3. The bed: the ground averaged over AVG m, kept off the sea, raised over the
   bay to BAY_UP over the sea, graded to GRADE both ways, then eased.
4. Each stretch's kind (grade, cut, fill, tunnel, trestle, bridge) and the
   named pieces (`rail/<piece>`, the handles scripts/endless/rail_line.gd
   hands to LayoutOverrides).
5. The map (kinds on the site map, pieces and nearby finds named) and the
   height profile beside it (FILE-profile.png).

Needs numpy and PIL (the Mac's python3 lacks PIL:
zenscape-godot/scratch/.venv/bin/python). Seed 1 only: the line is laid for
seed 1's land.
"""
import argparse, json, math, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import site_map  # noqa: E402

DRAFT = "docs/design/endless-flight/railroad/route-line.json"
BOX = "-5400,-3800,2000,2800"
CTRL = 40.0        # draft metres per control point
R_MIN = 160.0      # the tightest curve laid (rails want 150 or more)
STEP = 4.0         # metres between the path's samples
EDGE = 12.5        # bed edge from the centre line (track gap 13, a car, a shoulder: rail_bed.gd HALF)
AVG = 300.0        # the bed follows the ground averaged over this
EASE = 120.0       # then eased over this
GRADE = 0.0345     # laid a little under 3.5% so the curve between samples stays under it
SEA_UP = 6.0       # the bed's least height over the sea
WATER_UP = 12.0    # over open water (trestles stand clear of the swell)
BAY_UP = 40.0      # the bay bridge's deck over the sea
BAY = (148.0, 836.0, 700.0)   # the bay bridge's zone: x, z, radius
TUNNEL, CUT, FILL, TRESTLE = 22.0, 4.0, 4.0, 12.0
SHORT = 60.0       # tunnels, trestles and bridges shorter than this become cut or fill

# The seven places, in the line's order (spec-railroad.md). Stations and towns
# get a piece each; the rest name the stretches near them.
PLACES = [
    ("start-station", "station", 1350.0, 350.0),
    ("shore", "", 1050.0, -1100.0),
    ("farm-town", "town", -2500.0, -3300.0),
    ("west", "", -4707.0, -857.0),
    ("mine-town", "town", -4500.0, 700.0),
    ("cattle-town", "town", -2500.0, 2300.0),
    ("bay", "", 148.0, 836.0),
]
HEADLINE = {("west", "tunnel"): "west-tunnel", ("mine-town", "trestle"): "mine-trestle",
            ("bay", "bridge"): "bay-bridge"}
KEEP_OFF = ["first-cairn", "east-room", "meadow-dash"]
FINDS_NEAR = ["bay-ring", "sea-arch-ring", "stack-top", "saddle-ring"]
COL = {"tunnel": (150, 60, 255), "cut": (255, 200, 60), "grade": (250, 250, 250),
       "fill": (255, 170, 120), "trestle": (255, 70, 40), "bridge": (60, 230, 255)}


def rel(p):
    return os.path.join(ROOT, p)


# --- 1. the plan view -------------------------------------------------------

def resample_closed(P, ds):
    """Points every `ds` m along a closed polyline (the last joins the first)."""
    Q = np.vstack([P, P[:1]])
    seg = np.hypot(*np.diff(Q, axis=0).T)
    cum = np.concatenate([[0.0], np.cumsum(seg)])
    L = cum[-1]
    n = max(4, int(round(L / ds)))
    s = np.arange(n) * (L / n)
    x = np.interp(s, cum, Q[:, 0])
    z = np.interp(s, cum, Q[:, 1])
    return np.stack([x, z], axis=1), L


def bspline(C, per=24):
    """A closed uniform cubic B-spline over control points C: points, first and
    second derivatives (per unit of the spline's own parameter)."""
    n = len(C)
    t = np.arange(per) / per
    b = np.stack([(1 - t) ** 3, 3 * t ** 3 - 6 * t ** 2 + 4, -3 * t ** 3 + 3 * t ** 2 + 3 * t + 1, t ** 3], 1) / 6
    d1 = np.stack([-3 * (1 - t) ** 2, 9 * t ** 2 - 12 * t, -9 * t ** 2 + 6 * t + 3, 3 * t ** 2], 1) / 6
    d2 = np.stack([6 * (1 - t), 18 * t - 12, -18 * t + 6, 6 * t], 1) / 6
    idx = (np.arange(n)[:, None] + np.arange(-1, 3)[None, :]) % n      # n x 4
    G = C[idx]                                                          # n x 4 x 2
    P = np.einsum("tk,nkd->ntd", b, G).reshape(-1, 2)
    D1 = np.einsum("tk,nkd->ntd", d1, G).reshape(-1, 2)
    D2 = np.einsum("tk,nkd->ntd", d2, G).reshape(-1, 2)
    return P, D1, D2


def curvature(D1, D2):
    return (D1[:, 0] * D2[:, 1] - D1[:, 1] * D2[:, 0]) / np.maximum(np.hypot(D1[:, 0], D1[:, 1]) ** 3, 1e-9)


def plan_view(draft):
    C, _ = resample_closed(np.array(draft["pts"], dtype=float), CTRL)
    per = 24
    for it in range(400):
        _, D1, D2 = bspline(C, per)
        k = np.abs(curvature(D1, D2)).reshape(len(C), per).max(axis=1)
        bad = np.where(k > 1.0 / R_MIN)[0]
        if len(bad) == 0:
            break
        mask = np.zeros(len(C), bool)
        for i in bad:  # ease the control points around each tight spot
            mask[[(i + j) % len(C) for j in range(-3, 5)]] = True
        lap = (np.roll(C, 1, 0) + np.roll(C, -1, 0)) / 2 - C
        C = C + 0.5 * lap * mask[:, None]
    per = 400  # fine enough that the resampled points sit on the curve
    P, D1, D2 = bspline(C, per)
    pts, L = resample_closed(P, STEP)
    # the curvature at the resampled points, from the dense spline
    Q = np.vstack([P, P[:1]])
    cum = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(Q, axis=0).T))])
    kd = curvature(D1, D2)
    s = np.arange(len(pts)) * (L / len(pts))
    k = np.interp(s, cum[:-1], kd)
    return C, pts, L, k, it


def frames(pts):
    """Unit travel direction and right-hand side (XZ) at each sample."""
    t = np.roll(pts, -1, 0) - np.roll(pts, 1, 0)
    t /= np.hypot(t[:, 0], t[:, 1])[:, None]
    right = np.stack([-t[:, 1], t[:, 0]], 1)
    return t, right


# --- 2. the land under it -----------------------------------------------------

def sample_land(points, scene_args):
    inp = rel("scratch/rail/sample_in.json")
    out = rel("scratch/rail/sample_out.json")
    os.makedirs(os.path.dirname(inp), exist_ok=True)
    json.dump({"pts": [[round(float(x), 2), round(float(z), 2)] for x, z in points]}, open(inp, "w"))
    cmd = [sys.executable, rel("tools/drive.py"), "tools/harness/rail_sample.gd", "--",
           "--in=" + inp.replace("\\", "/"), "--out=" + out.replace("\\", "/"), "--timeout=480"]
    if scene_args:
        cmd += ["--scene-args"] + scene_args
    r = subprocess.run(cmd, cwd=ROOT)
    if r.returncode != 0:
        sys.exit("rail_sample failed (%d)" % r.returncode)
    d = json.load(open(out))
    river = np.array([np.nan if v is None else v for v in d["river"]], dtype=float)
    return np.array(d["ground"], dtype=float), river, float(d["sea"])


# --- 3. the bed ------------------------------------------------------------------

def cyclic_mean(a, win):
    w = int(win / STEP / 2)
    pad = np.concatenate([a[-w:], a, a[:w]])
    c = np.cumsum(np.concatenate([[0.0], pad]))
    return (c[2 * w + 1:] - c[:-2 * w - 1]) / (2 * w + 1)


def clamp_grade(bed, floor=None):
    """Grade both ways at GRADE, round the loop; a floor is lifted, never cut."""
    step = GRADE * STEP
    n = len(bed)
    b = bed.copy()
    for _ in range(3):
        for i in range(2 * n):
            j, p = i % n, (i - 1) % n
            b[j] = min(max(b[j], b[p] - step), b[p] + step)
        for i in range(2 * n, 0, -1):
            j, p = i % n, (i + 1) % n
            b[j] = min(max(b[j], b[p] - step), b[p] + step)
    if floor is not None:
        f = floor.copy()
        for _ in range(2):
            for i in range(2 * n):
                f[i % n] = max(f[i % n], f[(i - 1) % n] - step)
            for i in range(2 * n, 0, -1):
                f[i % n] = max(f[i % n], f[(i + 1) % n] - step)
        b = np.maximum(b, f)
    return b


def lay_bed(pts, ground, sea):
    floor = np.full(len(pts), sea + SEA_UP)
    floor = np.where(ground < sea, sea + WATER_UP, floor)
    bay = np.hypot(pts[:, 0] - BAY[0], pts[:, 1] - BAY[1]) < BAY[2]
    floor = np.where(bay & (ground < sea), sea + BAY_UP, floor)
    bed = clamp_grade(np.maximum(cyclic_mean(ground, AVG), sea + SEA_UP), floor)
    bed = clamp_grade(cyclic_mean(bed, EASE), floor)
    bed = cyclic_mean(bed, 40.0)  # no kinks left for the game's spline to overshoot
    return bed, floor


def as_played(pts, bed, sub=8):
    """What scripts/endless/rail_line.gd draws from the samples (Catmull-Rom
    through them): the tightest radius, steepest grade and how evenly s runs."""
    P = np.stack([pts[:, 0], bed, pts[:, 1]], 1)
    p0, p1, p2, p3 = np.roll(P, 1, 0), P, np.roll(P, -1, 0), np.roll(P, -2, 0)
    rs, gs, sp = [], [], []
    for t in np.arange(sub) / sub:
        d = 0.5 * ((p2 - p0) + 2 * (2 * p0 - 5 * p1 + 4 * p2 - p3) * t + 3 * (3 * p1 - p0 - 3 * p2 + p3) * t * t)
        dd = 0.5 * (2 * (2 * p0 - 5 * p1 + 4 * p2 - p3) + 6 * (3 * p1 - p0 - 3 * p2 + p3) * t)
        h = np.hypot(d[:, 0], d[:, 2])
        k = np.abs(d[:, 0] * dd[:, 2] - d[:, 2] * dd[:, 0]) / h ** 3
        rs.append(1 / np.maximum(k, 1e-9)); gs.append(np.abs(d[:, 1]) / h); sp.append(np.linalg.norm(d, axis=1) / STEP)
    rs, gs, sp = np.array(rs), np.array(gs), np.array(sp)
    return float(rs.min()), int(np.argmin(rs.min(axis=0))), float(gs.max()), float(sp.min()), float(sp.max())


# --- 4. kinds and pieces -----------------------------------------------------------

def runs_of(kinds, seam=True):
    """Runs of one kind: [kind, i, j] (j inclusive); with `seam`, a run across
    the loop's start is one run, its i negative."""
    runs = []
    for i, k in enumerate(kinds):
        if runs and runs[-1][0] == k:
            runs[-1][2] = i
        else:
            runs.append([k, i, i])
    if seam and len(runs) > 1 and runs[0][0] == runs[-1][0]:
        runs[0][1] = runs[-1][1] - len(kinds)
        runs.pop()
    return runs


def classify(ground, bed, sea, river):
    dv = ground - bed
    kinds = np.where(dv > TUNNEL, "tunnel", np.where(dv > CUT, "cut", np.where(
        -dv > TRESTLE, np.where(ground < sea, "bridge", "trestle"), np.where(-dv > FILL, "fill", "grade")))).astype(object)
    wet = ~np.isnan(river)
    low = np.isin(kinds, ["grade", "cut", "fill"])
    kinds[wet & low & (bed - river > 3.0)] = "bridge"  # a river crossed on the bed: a span, never a dam
    for _ in range(2):
        for k, i, j in runs_of(list(kinds)):
            if k in ("tunnel", "trestle", "bridge") and (j - i + 1) * STEP < SHORT:
                if k == "bridge" and wet[[t % len(kinds) for t in range(i, j + 1)]].any():
                    continue
                for t in range(i, j + 1):
                    kinds[t % len(kinds)] = "cut" if k == "tunnel" else "fill"
    return list(kinds)


def nearest_place(x, z):
    return min(PLACES, key=lambda p: math.hypot(p[2] - x, p[3] - z))[0]


PLATFORM = 160.0   # a station's level stretch
def station_at(pts, kinds, bed, ground, x, z):
    """The sample nearest (x, z) with a platform's length of plain bed round it
    (no tunnel, trestle or bridge), searched up to 800 m."""
    n = len(pts)
    i0 = int(np.argmin(np.hypot(pts[:, 0] - x, pts[:, 1] - z)))
    h = int(PLATFORM / STEP / 2)
    for d in range(0, int(800 / STEP)):
        for i in (i0 + d, i0 - d):
            idx = [(i + t) % n for t in range(-h, h + 1)]
            if all(kinds[t] in ("grade", "cut", "fill") for t in idx):
                return i % n
    return i0


def pieces_of(pts, L, kinds, bed, ground):
    n = len(pts)
    out = []
    for name, kind, x, z in PLACES:
        if kind:
            i = station_at(pts, kinds, bed, ground, x, z)
            out.append({"name": "rail/" + name, "kind": kind, "s0": round(i * STEP, 1), "s1": round(i * STEP, 1),
                        "x": x, "z": z, "y": round(float(bed[i]), 2)})
    # spans: a tunnel, or trestles and bridges end to end as one structure,
    # its kind the one it is most of
    spans = []
    for k, i, j in runs_of(["span" if k in ("trestle", "bridge") else k for k in kinds]):
        if k not in ("tunnel", "span"):
            continue
        idx = [t % n for t in range(i, j + 1)]
        if k == "span":
            k = "bridge" if sum(kinds[t] == "bridge" for t in idx) * 2 > len(idx) else "trestle"
        m = ((i + j) // 2) % n
        spans.append((nearest_place(*pts[m]), k, i, j, idx))
    best = {}  # the headline span of its place and kind is the longest one there
    for sp in spans:
        key = (sp[0], sp[1])
        if key in HEADLINE and (key not in best or sp[3] - sp[2] > best[key][3] - best[key][2]):
            best[key] = sp
    count = {}
    for sp in sorted(spans, key=lambda sp: sp[2] % n):
        place, k, i, j, idx = sp
        if best.get((place, k)) is sp:
            name = HEADLINE[(place, k)]
        else:
            count[(place, k)] = count.get((place, k), 0) + 1
            name = "%s-%s-%d" % (place, k, count[(place, k)])
        s0 = (i % n) * STEP
        out.append({"name": "rail/" + name, "kind": k, "s0": round(s0, 1), "s1": round(s0 + (j - i + 1) * STEP, 1),
                    "depth": round(float(np.max(np.abs(ground[idx] - bed[idx]))), 1)})
    return out


# --- 5. the pictures --------------------------------------------------------------

def font(size):
    for f in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", "arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def draw(grid, pts, kinds, pieces, finds, out, px=1600):
    tmp = os.path.splitext(out)[0] + ".base.png"
    site_map.draw_map(grid, tmp, px, [])
    img = Image.open(tmp).convert("RGB")
    os.remove(tmp)
    x0, z0, x1, z1 = grid["box"]
    scale = px / max(x1 - x0, z1 - z0)
    to = lambda x, z: ((x - x0) * scale, (z - z0) * scale)
    d = ImageDraw.Draw(img)
    n = len(pts)
    runs = runs_of(kinds)
    for width, colour in ((11, None), (6, True)):
        for k, i, j in runs:
            seg = [to(*pts[t % n]) for t in range(i, j + 2)]
            d.line(seg, fill=COL[k] if colour else (20, 20, 20), width=width if colour or k != "tunnel" else 13)
    f = font(20)
    for p in pieces:
        i = int(((p["s0"] + p["s1"]) / 2) / STEP) % n
        x, z = to(*pts[i])
        label = p["name"][5:]
        if p["kind"] in ("station", "town"):
            r = 12
            d.rectangle([x - r, z - r, x + r, z + r], fill=(200, 40, 40) if p["kind"] == "town" else (240, 240, 240),
                        outline=(0, 0, 0), width=3)
        elif p["s1"] - p["s0"] < 150:
            continue
        else:
            label += " %dm" % (p["s1"] - p["s0"])
        d.text((x + 16, z - 10), label, fill=(255, 255, 255), font=f, stroke_width=3, stroke_fill=(0, 0, 0))
    for name, (fx, fz), dist in finds:
        x, z = to(fx, fz)
        d.ellipse([x - 6, z - 6, x + 6, z + 6], outline=(255, 225, 60), width=3)
    ly = 20
    for k in ("grade", "cut", "fill", "tunnel", "trestle", "bridge"):
        d.rectangle([20, ly, 60, ly + 14], fill=COL[k], outline=(0, 0, 0))
        d.text((70, ly - 5), k, fill=(255, 255, 255), font=f, stroke_width=3, stroke_fill=(0, 0, 0))
        ly += 30
    img.save(out, quality=90)  # a JPEG keeps the picture small and its colours true


def draw_profile(L, ground, bed, sea, kinds, pieces, out, w=2400, h=560):
    img = Image.new("RGB", (w, h), (24, 30, 40))
    d = ImageDraw.Draw(img)
    lo, hi = sea - 20.0, max(float(ground.max()), float(bed.max())) + 20.0
    sx = (w - 80) / L
    sy = (h - 60) / (hi - lo)
    X = lambda s: 60 + s * sx
    Y = lambda y: h - 30 - (y - lo) * sy
    n = len(bed)
    d.rectangle([X(0), Y(sea), X(L), Y(lo)], fill=(40, 80, 120))
    for i in range(n):
        d.line([X(i * STEP), Y(lo), X(i * STEP), Y(max(ground[i], lo))], fill=(110, 96, 70))
    for i in range(n - 1):
        d.line([X(i * STEP), Y(bed[i]), X((i + 1) * STEP), Y(bed[i + 1])], fill=COL[kinds[i]], width=3)
    f = font(16)
    for v in range(int(math.ceil(lo / 50.0)) * 50, int(hi), 50):
        d.text((4, Y(v) - 8), "%d" % v, fill=(200, 200, 200), font=f)
        d.line([X(0), Y(v), X(L), Y(v)], fill=(60, 66, 76))
    for p in pieces:
        if p["kind"] in ("station", "town") or p["name"][5:] in HEADLINE.values():
            s = (p["s0"] + p["s1"]) / 2
            d.line([X(s), 4, X(s), h - 30], fill=(160, 160, 160))
            d.text((X(s) + 4, 6 + 18 * (pieces.index(p) % 2)), p["name"][5:], fill=(255, 255, 255), font=f)
    for km in range(0, int(L / 1000) + 1):
        d.text((X(km * 1000) - 6, h - 24), "%dkm" % km, fill=(200, 200, 200), font=f)
    img.save(out)


# --- main -----------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--grid", default="scratch/rail/world10.json", help="tools/site_map.py's JSON of the loop's box")
    ap.add_argument("--fresh-grid", action="store_true", help="remake the grid (site_map.py, 10 m)")
    ap.add_argument("--out", default="assets/railroad/rail_line.json")
    ap.add_argument("--map", default="docs/design/endless-flight/railroad/rail-line.jpg")
    args, rest = ap.parse_known_args()
    # the land as it is without the railroad: the line is laid on main's land
    scene_args = ["--seed=1", "--no-railroad"] + (rest[1:] if rest[:1] == ["--"] else rest)
    gpath = rel(args.grid)
    if args.fresh_grid or not os.path.exists(gpath):
        r = subprocess.run([sys.executable, rel("tools/site_map.py"), "--box=" + BOX, "--step=10", "--px", "2200",
                            "--out", os.path.splitext(gpath)[0] + ".png", "--"] + scene_args, cwd=ROOT)
        if r.returncode != 0:
            sys.exit(r.returncode)
    grid = json.load(open(gpath))
    draft = json.load(open(rel(DRAFT)))

    C, pts, L, k, iters = plan_view(draft)
    i0 = int(np.argmin(np.hypot(pts[:, 0] - PLACES[0][2], pts[:, 1] - PLACES[0][3])))
    pts, k = np.roll(pts, -i0, 0), np.roll(k, -i0)  # s = 0 at the start station
    t, right = frames(pts)
    probe = np.concatenate([pts, pts + right * EDGE, pts - right * EDGE])
    g_all, river_all, sea = sample_land(probe, scene_args)
    n = len(pts)
    ground, g_r, g_l = g_all[:n], g_all[n:2 * n], g_all[2 * n:]
    river = river_all[:n]
    bed, floor = lay_bed(pts, ground, sea)
    kinds = classify(ground, bed, sea, river)
    pieces = pieces_of(pts, L, kinds, bed, ground)

    sites = {s["name"]: s for s in grid["sites"]}
    finds = []
    for name in FINDS_NEAR + KEEP_OFF:
        if name in sites:
            s = sites[name]
            dd = np.hypot(pts[:, 0] - s["x"], pts[:, 1] - s["z"])
            i = int(np.argmin(dd))
            finds.append((name, (s["x"], s["z"]), float(dd[i])))
            print("  %-14s %5.0f m from the line at s=%5.0f, its y %6.1f, the bed %6.1f, ground %6.1f%s" % (
                name, dd[i], i * STEP, s.get("y", 0.0), bed[i], ground[i], "  (keep off)" if name in KEEP_OFF else ""))

    pts, bed = np.round(pts, 3), np.round(bed, 3)  # as stored: mm, or the rounding bends the curve
    r_min, ri, g_max, sp0, sp1 = as_played(pts, bed)
    at = pts[ri]
    print("line %.2f km (%d samples every %g m), lap %.1f min at 32 m/s; %d easing passes" % (L / 1000, n, STEP, L / 32 / 60, iters))
    print("as played: tightest curve r=%.0f m at s=%.0f (%.0f, %.0f); steepest grade %.2f%%; s runs at %.3f..%.3f m/m" % (
        r_min, ri * STEP, at[0], at[1], 100 * g_max, sp0, sp1))
    print("bed %.1f..%.1f m, sea %.0f" % (bed.min(), bed.max(), sea))
    tot = {}
    for kk, i, j in runs_of(kinds):
        tot.setdefault(kk, []).append((j - i + 1) * STEP)
    for kk in ("grade", "cut", "fill", "tunnel", "trestle", "bridge"):
        if kk in tot:
            print("  %-8s %2d stretches, %5.2f km" % (kk, len(tot[kk]), sum(tot[kk]) / 1000))
    wet = np.where(~np.isnan(river))[0]
    print("river water under the line at %d samples%s" % (len(wet), (": s=" + ", ".join("%.0f" % (i * STEP) for i in wet[::5])) if len(wet) else ""))
    for p in pieces:
        print("  %-28s %-8s s %7.1f..%7.1f  %s" % (p["name"], p["kind"], p["s0"], p["s1"],
                                                  ("%.0f m long, %.0f m deep/high" % (p["s1"] - p["s0"], p["depth"])) if "depth" in p else ""))

    os.makedirs(os.path.dirname(rel(args.out)), exist_ok=True)
    doc = {
        "about": "The railroad's line for seed 1, made by tools/rail_line.py from the draft; read by scripts/endless/rail_line.gd. "
                 "x, z: the centre between the two tracks every `step` m round the loop (s = 0 at the start station); "
                 "y: the bed's top there (world); kinds: [kind, s0, s1]; pieces: the named handles (rail/<piece>).",
        "seed": 1, "step": STEP, "length": n * STEP,
        "x": [round(float(v), 3) for v in pts[:, 0]], "z": [round(float(v), 3) for v in pts[:, 1]],
        "y": [round(float(v), 3) for v in bed],
        "kinds": [[kk, round(i * STEP, 1), round((j + 1) * STEP, 1)] for kk, i, j in runs_of(kinds, False)],
        "pieces": pieces,
        "ctrl": [[round(float(x), 2), round(float(z), 2)] for x, z in C],
    }
    with open(rel(args.out), "w") as fh:
        fh.write(json.dumps(doc, separators=(",", ":")))
    os.makedirs(os.path.dirname(rel(args.map)), exist_ok=True)
    draw(grid, pts, kinds, pieces, finds, rel(args.map))
    draw_profile(L, ground, bed, sea, kinds, pieces, os.path.splitext(rel(args.map))[0] + "-profile.png")
    print("wrote", args.out, args.map)


if __name__ == "__main__":
    main()
