#!/usr/bin/env python3
"""Bakes the map page's land picture (scripts/endless/ui/map_page.gd).

python tools/map_bake.py [--from-json scratch/world_map.json] [--box x0,z0,x1,z1] [--px 2048]

Dumps the land's heights over the box with tools/site_map.py's dump
(tools/harness/site_dump.gd, headless, about 40 s; or reuses a dump with
--from-json) and draws it as a painted chart: the land coloured by height (sand, meadow, dry
hills, rock, snow) and shaded, contours (fine every 50 m, firm every 250 m), the sea a teal
wash with depth lines off the coast, ponds as water, an inked coast. No names
or marks: the page draws those itself. Writes assets/ui/map/land_seed1.png
(x right, z down: north, -z, up) and scripts/endless/ui/map_land.gd (the
seed, the box, the start). After a bake, import (python tools/godot.py --import).
Needs PIL and numpy.
"""
import argparse, json, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "map", "land_seed1")
META = os.path.join(ROOT, "scripts", "endless", "ui", "map_land.gd")
BOX = "-7500,-7500,5500,5500"
META_GD = '''extends RefCounted
## Written by tools/map_bake.py with the picture beside it: what the map
## page's land picture (assets/ui/map/land_seed1.png) covers. Bake again
## rather than edit.

const PICTURE := "res://assets/ui/map/land_seed1.png"
## The land it was drawn from: this seed, the profile holding the start.
const SEED := %d
const WORLD := "wilderness"
## The picture's box, world x and z (m): x right, z down.
const BOX := Rect2(%.1f,%.1f,%.1f,%.1f)
## Where a game starts (the title's spot).
const START := Vector2(%.1f,%.1f)
'''

# A painted chart: the land's own colours by height (sand at the shore, meadow
# green, dry hills, brown and grey rock, snow), a teal sea darker with depth.
RAMP_M = [0.0, 6.0, 14.0, 60.0, 140.0, 260.0, 450.0, 700.0, 900.0]
RAMP = np.array([[233, 216, 160], [233, 216, 160], [146, 188, 98], [168, 200, 108], [200, 198, 118],
                 [206, 172, 116], [176, 140, 108], [140, 128, 128], [238, 240, 242.0]])
SHALLOW = np.array([124, 198, 196.0])
DEEP = np.array([44, 112, 150.0])
CONTOUR = np.array([70, 58, 34.0])
WATERLINE = np.array([28, 78, 108.0])
COAST = np.array([40, 36, 30.0])


def dump(box, step):
    jpath = os.path.join(ROOT, "scratch", "map_bake.json")
    cmd = [sys.executable, os.path.join(ROOT, "tools", "drive.py"), "tools/harness/site_dump.gd", "--",
           "--box=" + box, "--step=%g" % step, "--out=" + jpath.replace("\\", "/"), "--timeout=480"]
    r = subprocess.run(cmd, cwd=ROOT)
    if r.returncode != 0:
        sys.exit(r.returncode)
    return jpath


def lines(h, every, sea_only=None):
    """Where `h` crosses a multiple of `every` between neighbours (a 0..1 mask)."""
    band = np.floor(h / every)
    edge = np.zeros(h.shape, dtype=bool)
    edge[:, 1:] |= band[:, 1:] != band[:, :-1]
    edge[1:, :] |= band[1:, :] != band[:-1, :]
    if sea_only is not None:
        edge &= sea_only
    return edge.astype(np.float32)


def blur(h, r):
    """A box blur `r` px each way, twice (near a gaussian)."""
    out = h.astype(np.float64)
    w = 2 * r + 1
    for _ in range(2):
        c = np.cumsum(np.pad(out, ((r + 1, r), (0, 0)), mode="edge"), axis=0)
        out = (c[w:] - c[:-w]) / w
        c = np.cumsum(np.pad(out, ((0, 0), (r + 1, r)), mode="edge"), axis=1)
        out = (c[:, w:] - c[:, :-w]) / w
    return out.astype(np.float32)


def thicken(m):
    out = m.copy()
    out[:, 1:] = np.maximum(out[:, 1:], m[:, :-1])
    out[1:, :] = np.maximum(out[1:, :], m[:-1, :])
    return out


def over(rgb, mask, col, a):
    m = (mask * a)[..., None]
    return rgb * (1 - m) + col * m


def bake(data, px):
    x0, z0, x1, z1 = data["box"]
    nx, nz, sea = data["nx"], data["nz"], data["sea"]
    big = px * 2  # drawn at twice the size, then halved: smooth lines
    h0 = np.array(data["heights"], dtype=np.float32).reshape(nz, nx)
    h = np.asarray(Image.fromarray(h0, mode="F").resize((big, big), Image.BICUBIC), dtype=np.float32)
    # A softened copy for the shade and the contours: the land's small grain
    # reads as noise at this scale.
    soft = blur(h, 5)
    step = (x1 - x0) / big
    land = h > sea
    # Ponds: water discs at their level (the dump's sites).
    yy, xx = np.mgrid[0:big, 0:big]
    pond = np.zeros(h.shape, dtype=bool)
    for s in data["sites"]:
        if s["kind"] != "pond":
            continue
        cx, cz, r = (s["x"] - x0) / step, (s["z"] - z0) / step, s["radius"] / step
        i0, i1 = max(int(cz - r - 2), 0), min(int(cz + r + 3), big)
        j0, j1 = max(int(cx - r - 2), 0), min(int(cx + r + 3), big)
        pond[i0:i1, j0:j1] |= (yy[i0:i1, j0:j1] - cz) ** 2 + (xx[i0:i1, j0:j1] - cx) ** 2 <= r * r
    # Height tint: the shore's sand runs smoothly, above it 20 m layers as a
    # printed map's.
    rel = soft - sea
    rel = np.where(rel < 20.0, rel, np.floor(rel / 20.0) * 20.0)
    rgb = np.dstack([np.interp(rel, RAMP_M, RAMP[:, i]) for i in range(3)])
    # Shade from the north-west, light: ink on paper, not a photo.
    gz, gx = np.gradient(soft, step)
    n = np.dstack((-gx, -gz, np.ones_like(h) * 1.6))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    flat = 1.6 / np.sqrt(1.6 * 1.6)
    lit = n @ np.array([-0.5, -0.55, 0.67]) - 0.67 * flat
    shade = np.clip(1.0 + 0.95 * lit, 0.62, 1.12)[..., None]
    rgb = rgb * shade
    # Contours on land.
    rgb = over(rgb, lines(soft - sea, 50.0, land) * (1 - pond), CONTOUR, 0.24)
    rgb = over(rgb, thicken(lines(soft - sea, 250.0, land)) * (1 - pond), CONTOUR, 0.42)
    # The sea: a wash darker with depth, lines off the coast.
    depth = np.clip((sea - h) / 120.0, 0, 1)[..., None]
    water = SHALLOW * (1 - depth) + DEEP * depth
    wet = (~land) | pond
    rgb = np.where(wet[..., None], water, rgb)
    for d, al in ((6.0, 0.42), (22.0, 0.26), (60.0, 0.15)):
        edge = np.zeros(h.shape, dtype=bool)
        below = h < sea - d
        edge[:, 1:] |= below[:, 1:] != below[:, :-1]
        edge[1:, :] |= below[1:, :] != below[:-1, :]
        rgb = over(rgb, (edge & ~land).astype(np.float32), WATERLINE, al)
    # The coast, and the ponds' shores, inked.
    coast = np.zeros(h.shape, dtype=bool)
    coast[:, 1:] |= wet[:, 1:] != wet[:, :-1]
    coast[1:, :] |= wet[1:, :] != wet[:-1, :]
    rgb = over(rgb, thicken(coast.astype(np.float32)), COAST, 0.8)
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    return img.resize((px, px), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--box", default=BOX, help="x0,z0,x1,z1 (world m), square")
    ap.add_argument("--px", type=int, default=2048, help="the picture's side")
    ap.add_argument("--step", type=float, default=0.0, help="height spacing for the dump (m); default box/700")
    ap.add_argument("--from-json", default="", help="a site_dump JSON already made (its box is used)")
    args = ap.parse_args()
    if args.from_json:
        jpath = args.from_json
    else:
        box = [float(v) for v in args.box.split(",")]
        jpath = dump(args.box, args.step or (box[2] - box[0]) / 700.0)
    with open(jpath) as f:
        data = json.load(f)
    if int(data.get("seed", 1)) != 1:
        print("map_bake: the dump is seed %s; the page shows its picture on seed 1 only" % data.get("seed"))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    # 256 colours, dithered: half the file, no difference to see.
    img = bake(data, args.px).quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    img.save(OUT + ".png", optimize=True)
    start = next(([s["x"], s["z"]] for s in data["sites"] if s["kind"] == "start"), [0.0, 0.0])
    x0, z0, x1, z1 = data["box"]
    with open(META, "w", newline="\n") as f:
        f.write(META_GD % (int(data.get("seed", 1)), x0, z0, x1 - x0, z1 - z0, start[0], start[1]))
    print("map_bake: %s.png (%d px, %.1f m a px), %.1f MB" % (OUT, args.px, (data["box"][2] - data["box"][0]) / args.px,
                                                          os.path.getsize(OUT + ".png") / 1e6))


if __name__ == "__main__":
    main()
