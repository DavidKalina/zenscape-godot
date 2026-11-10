#!/usr/bin/env python3
"""Where the land could carry a waterfall fed by a lake, and a tunnel behind it.

Searches a grid of the flight's natural land (tools/harness/land_dump.gd) for
hollows that would hold water as the land stands, follows each one's lowest
way out, and keeps those that drop steeply soon after leaving the hollow: a
lake, a short outlet, a fall. For each it also looks for a bore from the
fall's foot through the rock behind it to open ground at about the foot's
height.

  python tools/fall_sites.py                    # dump 10 km round the start, then search
  python tools/fall_sites.py --r 15000 --step 20
  python tools/fall_sites.py --grid scratch/land_10k.bin   # search a dump already made
  python tools/fall_sites.py --grid G --near 650,-550      # the hollow nearest a point, in full

The dump runs the game headless with --no-placed, so the hand-placed sites'
own cuts are not in it. The grid is coarse (20 m by default): a row here is a
lead. Refine the foot, heading, lip and shore on a fine grid before placing
(scripts/endless/world/wilderness/placed.gd; the kind scripts/endless/kinds/
curtain.gd and its land curtain_land.gd).

Columns: the lake (centre, area, deepest, level), the fall (lip, foot, drop,
the outlet's length from the hollow's edge to the lip, the creek's length
from the foot to the nearest river or the sea), the site heading (the
placed list's: degrees, 0 faces north, 90 west), and two bores, each as its
length, its bearing off straight into the wall and the least rock over a
22 m vault away from its mouths (under 8 m is too thin): the shortest within
30 degrees of straight in, and the shortest at any bearing up to 75 degrees,
which often comes back out of the same wall further along.
"""
import argparse, array, heapq, json, math, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def dump(path, r, step, cx, cz):
    rel = os.path.relpath(path, ROOT)
    cmd = [sys.executable, os.path.join(ROOT, "tools", "drive.py"), "tools/harness/land_dump.gd",
           "--timeout", "1800", "--", "--out=res://" + rel.replace(os.sep, "/"), "--r=%g" % r,
           "--step=%g" % step, "--cx=%g" % cx, "--cz=%g" % cz, "--scene-args", "--no-placed"]
    print("dumping the land:", " ".join(cmd[1:]), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def load(path):
    with open(path, "rb") as f:
        head = json.loads(f.readline())
        n = int(head["n"])
        h = array.array("f"); h.frombytes(f.read(4 * n * n))
        w = array.array("f"); w.frombytes(f.read(4 * n * n))
    return head, h, w


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--grid", help="a dump already made (else one is made in scratch/)")
    ap.add_argument("--r", type=float, default=10000.0, help="half the square searched, m")
    ap.add_argument("--step", type=float, default=20.0, help="grid spacing, m")
    ap.add_argument("--at", default="0,0", help="the square's centre, x,z")
    ap.add_argument("--min-area", type=float, default=3000.0, help="least lake, m2")
    ap.add_argument("--min-deep", type=float, default=3.0, help="least depth at the lake's deepest, m")
    ap.add_argument("--min-drop", type=float, default=40.0, help="least fall, m")
    ap.add_argument("--reach", type=float, default=100.0, help="the fall's drop is measured within this far, m")
    ap.add_argument("--outlet", type=float, default=300.0, help="the lip is looked for within this far of the hollow, m")
    ap.add_argument("--near", help="x,z: print only the hollow nearest this point, whatever it scores")
    a = ap.parse_args()

    path = a.grid
    if not path:
        cx, cz = (float(v) for v in a.at.split(","))
        path = os.path.join(ROOT, "scratch", "land_%d_%d.bin" % (a.r, a.step))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        dump(path, a.r, a.step, cx, cz)
    head, H, W = load(path)
    n, S, sea = int(head["n"]), float(head["step"]), float(head["sea"])
    x0, z0 = head["cx"] - head["r"], head["cz"] - head["r"]
    N = n * n
    wet = [not math.isnan(v) for v in W]

    def xz(k):
        return (x0 + (k % n) * S, z0 + (k // n) * S)

    # Priority flood: each cell's water level is its lowest way out, to the
    # square's edge or the sea. `parent` is the cell the flood came from, so
    # a chain of parents is a way out, downhill of the level.
    F = array.array("f", [0.0]) * N
    parent = array.array("i", [-1]) * N
    seen = bytearray(N)
    heap = []
    for k in range(N):
        i, j = k % n, k // n
        if i == 0 or j == 0 or i == n - 1 or j == n - 1 or H[k] < sea + 0.5:
            F[k] = H[k]; seen[k] = 1
            heap.append((H[k], k))
    heapq.heapify(heap)
    push, pop = heapq.heappush, heapq.heappop
    while heap:
        lv, k = pop(heap)
        i = k % n
        for q in (k - 1 if i > 0 else -1, k + 1 if i < n - 1 else -1, k - n, k + n):
            if q < 0 or q >= N or seen[q]:
                continue
            seen[q] = 1
            v = H[q] if H[q] > lv else lv
            F[q] = v; parent[q] = k
            push(heap, (v, q))

    # The hollows: connected cells standing over 1 m under their level.
    mark = bytearray(N)
    found = []
    for k0 in range(N):
        if mark[k0] or F[k0] - H[k0] <= 1.0:
            continue
        cells = [k0]; mark[k0] = 1
        at = 0
        while at < len(cells):
            k = cells[at]; at += 1
            i = k % n
            for q in (k - 1 if i > 0 else -1, k + 1 if i < n - 1 else -1, k - n, k + n):
                if 0 <= q < N and not mark[q] and F[q] - H[q] > 1.0:
                    mark[q] = 1; cells.append(q)
        area = len(cells) * S * S
        deep = max(F[k] - H[k] for k in cells)
        if not a.near and (area < a.min_area or deep < a.min_deep):
            continue
        found.append((cells, area, deep))

    rows = []
    for cells, area, deep in found:
        inside = set(cells)
        level = max(F[k] for k in cells)
        cx = sum(xz(k)[0] for k in cells) / len(cells)
        cz = sum(xz(k)[1] for k in cells) / len(cells)
        # The way out: the first cell the flood reached in the hollow, then
        # its parents.
        first = min(cells, key=lambda k: (F[k] - H[k]))
        k = first
        while k >= 0 and k in inside:
            k = parent[k]
        chain = []
        while k >= 0 and len(chain) < 400:
            chain.append(k); k = parent[k]
        if len(chain) < 3:
            continue
        # The fall: the greatest drop between two cells of the way out no
        # more than `reach` apart, its top within `outlet` of the hollow.
        best = None
        edge = xz(chain[0])
        for i, ki in enumerate(chain):
            xi, zi = xz(ki)
            if math.hypot(xi - edge[0], zi - edge[1]) > a.outlet:
                break
            for j in range(i + 1, min(i + 16, len(chain))):
                xj, zj = xz(chain[j])
                if math.hypot(xj - xi, zj - zi) > a.reach:
                    continue
                d = H[ki] - H[chain[j]]
                if best is None or d > best[0]:
                    best = (d, i, j)
        if best is None:
            continue
        drop, li, fi = best
        # The lip as high up the drop as it starts, the foot where it ends.
        while fi + 1 < len(chain) and H[chain[fi]] - H[chain[fi + 1]] > 0.35 * S and fi - li < 15:
            fi += 1
        lip, foot = chain[li], chain[fi]
        drop = H[lip] - H[foot]
        lx, lz = xz(lip); fx, fz = xz(foot)
        out_len = sum(math.hypot(xz(chain[t + 1])[0] - xz(chain[t])[0], xz(chain[t + 1])[1] - xz(chain[t])[1]) for t in range(li))
        # The creek: on down the way out to a river, a pond or the sea.
        creek = None
        run = 0.0
        for t in range(fi, len(chain) - 1):
            if wet[chain[t]] or H[chain[t]] < sea + 0.5:
                creek = run; break
            run += math.hypot(xz(chain[t + 1])[0] - xz(chain[t])[0], xz(chain[t + 1])[1] - xz(chain[t])[1])
        # The bore: from the foot into the wall at the foot's height, over
        # a fan of bearings, to open ground at about that height.
        ux, uz = lx - fx, lz - fz
        if li > 0:
            px, pz = xz(chain[max(0, li - 2)])
            ux, uz = px - fx, pz - fz
        m = math.hypot(ux, uz) or 1.0
        ux, uz = ux / m, uz / m
        fy = H[foot]
        # Two answers: the shortest bore within 30 degrees of straight in
        # (through the rock to its far side) and the shortest at any bearing
        # (often out of the same wall further along).
        bore = None
        through = None
        for deg in range(-75, 76, 15):
            c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
            bx, bz = ux * c - uz * s, ux * s + uz * c
            over = []
            d = 60.0
            under = False
            while d <= 3000.0:
                gi = int(round((fx + bx * d - x0) / S)); gj = int(round((fz + bz * d - z0) / S))
                if gi < 0 or gj < 0 or gi >= n or gj >= n:
                    break
                g = H[gj * n + gi]
                if g < sea + 2.0:
                    break
                if g < fy + 10.0:
                    if under and d >= 150.0:
                        # The least rock over the vault, the 80 m at each mouth aside.
                        mid = [v for (dd, v) in over if 100.0 <= dd <= d - 80.0]
                        hit = (d, deg, min(mid) if mid else 0.0)
                        if bore is None or d < bore[0]:
                            bore = hit
                        if abs(deg) <= 30 and (through is None or d < through[0]):
                            through = hit
                    break
                if g > fy + 30.0:
                    under = True
                over.append((d, g - (fy + 22.0)))
                d += S
        rows.append({
            "lake": (cx, cz), "area": area, "deep": deep, "level": level, "lip": (lx, lz), "lip_y": H[lip],
            "foot": (fx, fz), "foot_y": fy, "drop": drop, "outlet": out_len, "creek": creek,
            "heading": math.degrees(math.atan2(ux, uz)), "bore": bore, "through": through, "ponded": any(wet[k] for k in cells),
            "from_start": math.hypot(fx, fz),
        })

    if a.near:
        px, pz = (float(v) for v in a.near.split(","))
        rows.sort(key=lambda r: math.hypot(r["lake"][0] - px, r["lake"][1] - pz))
        rows = rows[:1]
    else:
        rows = [r for r in rows if r["drop"] >= a.min_drop]
        rows.sort(key=lambda r: -(min(r["drop"], 120.0) + (40.0 if r["bore"] else 0.0) + min(r["area"], 30000.0) / 1000.0))
    print("%d x %d at %.0f m round (%.0f, %.0f); %d hollows of %.0f m2 and %.0f m deep or more; %d with a fall of %.0f m or more"
          % (n, n, S, head["cx"], head["cz"], len(found), a.min_area, a.min_deep, len(rows), a.min_drop))
    print("%-15s %7s %5s %6s | %-15s %-15s %5s %6s %6s %7s | %-22s | %-22s | %s" % (
        "lake x,z", "area", "deep", "level", "lip x,z", "foot x,z", "drop", "outlet", "creek", "heading",
        "bore through", "shortest bore", "from start"))
    for r in rows:
        def bore_text(b):
            return "none" if b is None else "%.0f m, %+d deg, %.0f m" % b
        print("%-15s %7.0f %5.1f %6.1f | %-15s %-15s %5.0f %6.0f %6s %7.0f | %-22s | %-22s | %6.0f%s" % (
            "%.0f,%.0f" % r["lake"], r["area"], r["deep"], r["level"], "%.0f,%.0f" % r["lip"], "%.0f,%.0f" % r["foot"],
            r["drop"], r["outlet"], "-" if r["creek"] is None else "%.0f" % r["creek"], r["heading"],
            bore_text(r["through"]), bore_text(r["bore"]), r["from_start"],
            "  (holds a pond already)" if r["ponded"] else ""))


if __name__ == "__main__":
    main()
