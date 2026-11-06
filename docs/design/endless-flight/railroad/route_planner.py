#!/usr/bin/env python3
"""Throwaway rail route planner over a site_map JSON (heights + sites).

scratch/.venv/bin/python scratch/rail/route.py scratch/rail/world.json route.json out.png

route.json: {"loop": true, "grade": 0.035, "stops": [{"name": "...", "x": .., "z": .., "kind": "town|station|via"}, ...]}
Each leg is the least-cost path over the land (length, climbing, water),
then smoothed, graded to the max grade (cut where the land is above the bed,
fill where below), and each stretch labelled: tunnel, cut, grade, fill,
trestle (over land) or bridge (over water).
"""
import heapq, json, math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

CELL = 50.0          # routing grid (m)
TUNNEL = 22.0        # land this far over the bed: tunnel
CUT = 4.0
FILL = 4.0
TRESTLE = 12.0       # bed this far over the land: trestle / bridge
COL = {"tunnel": (150, 60, 255), "cut": (255, 200, 60), "grade": (250, 250, 250),
       "fill": (255, 170, 120), "trestle": (255, 70, 40), "bridge": (60, 230, 255)}


def load(path):
    d = json.load(open(path))
    h = np.array(d["heights"], dtype=np.float32).reshape(d["nz"], d["nx"])
    return d, h


def sampler(d, h):
    x0, z0, x1, z1 = d["box"]
    nz, nx = h.shape
    sx, sz = (x1 - x0) / (nx - 1), (z1 - z0) / (nz - 1)

    def at(x, z):
        fx = np.clip((x - x0) / sx, 0, nx - 1.001)
        fz = np.clip((z - z0) / sz, 0, nz - 1.001)
        ix, iz = int(fx), int(fz)
        tx, tz = fx - ix, fz - iz
        a = h[iz, ix] * (1 - tx) + h[iz, ix + 1] * tx
        b = h[iz + 1, ix] * (1 - tx) + h[iz + 1, ix + 1] * tx
        return float(a * (1 - tz) + b * tz)
    return at


def grid(d, at):
    x0, z0, x1, z1 = d["box"]
    nx, nz = int((x1 - x0) / CELL) + 1, int((z1 - z0) / CELL) + 1
    g = np.zeros((nz, nx), dtype=np.float32)
    for j in range(nz):
        for i in range(nx):
            g[j, i] = at(x0 + i * CELL, z0 + j * CELL)
    return g


STEPS = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1),
         (2, 1), (2, -1), (-2, 1), (-2, -1), (1, 2), (1, -2), (-1, 2), (-1, -2)]


def leg(g, sea, a, b, avoid):
    """Dijkstra/A* from cell a to b. Cost: length, climbing (both ways), steep, water."""
    nz, nx = g.shape
    INF = 1e18
    dist = {a: 0.0}
    q = [(0.0, a)]
    prev = {}
    bx, bz = b
    while q:
        c, cur = heapq.heappop(q)
        if cur == b:
            break
        if c > dist.get(cur, INF) + 1e-6 + math.hypot(cur[0] - bx, cur[1] - bz) * CELL:
            pass
        i, j = cur
        g0 = dist[cur]
        for di, dj in STEPS:
            ni, nj = i + di, j + dj
            if not (0 <= ni < nx and 0 <= nj < nz):
                continue
            ln = math.hypot(di, dj) * CELL
            dh = abs(float(g[nj, ni] - g[j, i]))
            grade = dh / ln
            cost = ln + 6.0 * dh + (ln * 8.0 * (grade - 0.06) / 0.06 if grade > 0.06 else 0.0)
            hn = float(g[nj, ni])
            if hn < sea + 1.0:
                cost += ln * (14.0 if hn < sea - 12 else 4.0)  # deep water far dearer
            cost += avoid.get((ni // 4, nj // 4), 0.0) * ln
            nd = g0 + cost
            if nd < dist.get((ni, nj), INF):
                dist[(ni, nj)] = nd
                prev[(ni, nj)] = cur
                heapq.heappush(q, (nd + math.hypot(ni - bx, nj - bz) * CELL, (ni, nj)))
    path = [b]
    while path[-1] != a:
        path.append(prev[path[-1]])
    return path[::-1]


def smooth(pts, passes=6):
    for _ in range(passes):  # Chaikin
        out = [pts[0]]
        for p, q in zip(pts, pts[1:]):
            out += [(0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1]),
                    (0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1])]
        out.append(pts[-1])
        pts = out
    return pts


def resample(pts, ds=10.0):
    out = [pts[0]]
    carry = 0.0
    for p, q in zip(pts, pts[1:]):
        L = math.hypot(q[0] - p[0], q[1] - p[1])
        t = ds - carry
        while t <= L:
            out.append((p[0] + (q[0] - p[0]) * t / L, p[1] + (q[1] - p[1]) * t / L))
            t += ds
        carry = (carry + L) % ds if L > 0 else carry
    return out


def grade_bed(ground, ds, gmax, sea, loop):
    n = len(ground)
    win = int(300 / ds)
    k = np.ones(2 * win + 1) / (2 * win + 1)
    gpad = np.concatenate([ground[-win:], ground, ground[:win]]) if loop else np.pad(ground, win, mode="edge")
    bed = np.convolve(gpad, k, mode="valid")[:n]
    bed = np.maximum(bed, sea + 6.0)
    step = gmax * ds
    for _ in range(4):  # clamp grade both ways
        for i in range(1, n):
            bed[i] = min(max(bed[i], bed[i - 1] - step), bed[i - 1] + step)
        for i in range(n - 2, -1, -1):
            bed[i] = min(max(bed[i], bed[i + 1] - step), bed[i + 1] + step)
    return bed


def main():
    d, h = load(sys.argv[1])
    spec = json.load(open(sys.argv[2]))
    out = sys.argv[3]
    sea = d["sea"]
    at = sampler(d, h)
    g = grid(d, at)
    x0, z0, x1, z1 = d["box"]
    cell = lambda x, z: (int(round((x - x0) / CELL)), int(round((z - z0) / CELL)))
    stops = spec["stops"]
    seq = stops + ([stops[0]] if spec.get("loop") else [])
    # keep away from the sites the line must not run over (finds, doors, start)
    avoid = {}
    for s in d["sites"]:
        if s["kind"] in ("find", "door", "start", "hall", "tunnel", "split"):
            c = cell(s["x"], s["z"])
            avoid[(c[0] // 4, c[1] // 4)] = 3.0
    pts = []
    for a, b in zip(seq, seq[1:]):
        if a.get("direct"):
            n = max(2, int(math.hypot(b["x"] - a["x"], b["z"] - a["z"]) / CELL))
            w = [(a["x"] + (b["x"] - a["x"]) * t / n, a["z"] + (b["z"] - a["z"]) * t / n) for t in range(n + 1)]
        else:
            p = leg(g, sea, cell(a["x"], a["z"]), cell(b["x"], b["z"]), avoid)
            w = [(x0 + i * CELL, z0 + j * CELL) for i, j in p]
        pts += w if not pts else w[1:]
    pts = resample(smooth(pts), 10.0)
    P = np.array(pts)
    w = int(spec.get("ease", 160) / 10)
    for _ in range(3):  # wide easing so curves suit a train
        if spec.get("loop"):
            Q = np.concatenate([P[-w:], P, P[:w]])
        else:
            Q = np.concatenate([np.repeat(P[:1], w, 0), P, np.repeat(P[-1:], w, 0)])
        c = np.cumsum(np.vstack([np.zeros((1, 2)), Q]), axis=0)
        P = (c[2 * w + 1:] - c[:-2 * w - 1]) / (2 * w + 1)
    pts = resample([tuple(p) for p in P], 10.0)
    ground = np.array([at(x, z) for x, z in pts])
    bed = grade_bed(ground, 10.0, spec.get("grade", 0.035), sea, spec.get("loop"))
    kinds = []
    for gr, bd in zip(ground, bed):
        dv = gr - bd
        if dv > TUNNEL: kinds.append("tunnel")
        elif dv > CUT: kinds.append("cut")
        elif -dv > TRESTLE: kinds.append("bridge" if gr < sea else "trestle")
        elif -dv > FILL: kinds.append("fill")
        else: kinds.append("grade")
    # tidy: drop stretches shorter than 60 m into their neighbours
    runs = []
    for i, k in enumerate(kinds):
        if runs and runs[-1][0] == k: runs[-1][2] = i
        else: runs.append([k, i, i])
    for r in runs:
        if r[2] - r[1] < 6 and r[0] in ("tunnel", "trestle", "bridge"):
            for i in range(r[1], r[2] + 1): kinds[i] = "cut" if r[0] == "tunnel" else "fill"
    runs = []
    for i, k in enumerate(kinds):
        if runs and runs[-1][0] == k: runs[-1][2] = i
        else: runs.append([k, i, i])
    # curvature
    rmin, rat = 1e9, None
    for i in range(10, len(pts) - 10):
        a, b, c = pts[i - 10], pts[i], pts[i + 10]
        ab = math.hypot(b[0] - a[0], b[1] - a[1]); bc = math.hypot(c[0] - b[0], c[1] - b[1]); ca = math.hypot(a[0] - c[0], a[1] - c[1])
        area = abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])) / 2
        if area > 1e-3:
            r = ab * bc * ca / (4 * area)
            if r < rmin: rmin, rat = r, b
    L = 10.0 * (len(pts) - 1)
    tot = {}
    for k, i, j in runs:
        tot.setdefault(k, []).append((j - i + 1) * 10.0)
    print("length %.1f km, lap at 30 m/s %.1f min, at 37 m/s %.1f min" % (L / 1000, L / 30 / 60, L / 37 / 60))
    print("bed %.0f..%.0f m, ground %.0f..%.0f m, sea %.0f, tightest curve r=%.0f m at %s" % (bed.min(), bed.max(), ground.min(), ground.max(), sea, rmin, (round(rat[0]), round(rat[1])) if rat else None))
    for k in ("tunnel", "trestle", "bridge", "cut", "fill", "grade"):
        if k in tot:
            big = [round(v) for v in sorted(tot[k], reverse=True) if v >= 100][:8]
            print("  %-8s %2d stretches, %5.2f km  longest %s" % (k, len(tot[k]), sum(tot[k]) / 1000, big))
    for k, i, j in runs:
        if k in ("tunnel", "trestle", "bridge") and (j - i) >= 10:
            m = (i + j) // 2
            print("    %-7s %4d m at (%5d,%5d)  depth/height %3.0f m" % (k, (j - i + 1) * 10, pts[m][0], pts[m][1], abs(ground[m] - bed[m])))
    # draw
    base = Image.open(sys.argv[4] if len(sys.argv) > 4 else sys.argv[1].replace(".json", ".png")).convert("RGB")
    W, H = base.size
    scale = W / (x1 - x0)
    to = lambda x, z: ((x - x0) * scale, (z - z0) * scale)
    dr = ImageDraw.Draw(base)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    for k, i, j in runs:
        seg = [to(*pts[t]) for t in range(i, min(j + 2, len(pts)))]
        if len(seg) > 1:
            dr.line(seg, fill=(20, 20, 20), width=11)
    for k, i, j in runs:
        seg = [to(*pts[t]) for t in range(i, min(j + 2, len(pts)))]
        if len(seg) > 1:
            dr.line(seg, fill=COL[k], width=6 if k != "tunnel" else 8)
    for s in stops:
        px, pz = to(s["x"], s["z"])
        if s.get("kind") == "via":
            continue
        r = 13 if s.get("kind") == "town" else 9
        dr.rectangle([px - r, pz - r, px + r, pz + r], fill=(200, 40, 40) if s.get("kind") == "town" else (240, 240, 240), outline=(0, 0, 0), width=3)
        dr.text((px + r + 6, pz - 12), s["name"], fill=(255, 255, 255), font=font, stroke_width=3, stroke_fill=(0, 0, 0))
    ly = 20
    for k in ("grade", "cut", "fill", "tunnel", "trestle", "bridge"):
        dr.rectangle([20, ly, 60, ly + 14], fill=COL[k], outline=(0, 0, 0))
        dr.text((70, ly - 5), k, fill=(255, 255, 255), font=font, stroke_width=3, stroke_fill=(0, 0, 0))
        ly += 30
    base.save(out)
    json.dump({"pts": [[round(x, 1), round(z, 1)] for x, z in pts], "bed": [round(float(b), 1) for b in bed],
               "kinds": kinds}, open(out.replace(".png", ".line.json"), "w"))
    print("wrote", out)


if __name__ == "__main__":
    main()
