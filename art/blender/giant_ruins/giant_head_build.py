"""Giant stone heads and torsos for the Amberlands (headless), rough stage.

    python3 tools/blender.py run art/blender/giant_ruins/giant_head_build.py \
        -- [--pieces elder,warden_torso,...] [--voxel 0.75] [--out scratch/giant_heads]

Each head is a signed distance field on a numpy grid, meshed with surface nets
and written as a glb. A field gives real hollows (mouth, throat, chamber, eye
shafts, a way out the back) and carved blends, and later cuts (a split, a
break) are one more field. Metres, Blender axes: the face looks down -Y, Z up,
the base stands on z = 0. A head is 120 m tall, a torso about 200 m; the plane
spans 2.8 m. Each piece writes <name>.glb (the field's full mesh) and
<name>_low.glb (the worn field without its cracks, meshed on a grid STRIDE
times coarser: even triangles, and no route pinched as cutting the full mesh
down did), and prints the room on its flight lines measured on both meshes.

Then the game's set: each of POSES tilts a low piece, sinks it until `show` of
its height is above the ground and cuts it off CUT m under, into
assets/models/giants/<id>.glb. assets/models/giants/ruins.json holds where each
stands and a grid of its signed distance, which is what the plane flies
against (scripts/endless/giant_ruins.gd); poses.json what the layout and the
land heaped round each need (scripts/endless/giant_swells.gd).
"""
import argparse
import base64
import json
import sys
import zlib
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
TALL = 120.0
STRIDE = {"head": 6, "torso": 5}
CUT = 16.0
COURSE = 9.0
BLOCK = 15.0
RING = 60.0
BAKE_NORMAL = 2048
BAKE_AO = 1024
SWELL_MOST = 16.0
CELL = 4.0
# id, piece, ground spot (Blender x, y), tilt in degrees, share of height showing.
POSES = [
    ("warden_torso_rearing", "warden_torso", (20, 330), (0, -35, 20), 0.58),
    ("elder_on_its_back", "elder", (-340, -60), (-58, 12, 30), 0.46),
    ("mourner_watching", "mourner", (-90, -220), (-10, -16, -12), 0.70),
    ("warden_on_its_ear", "warden", (220, -130), (0, 84, 24), 0.68),
    ("elder_torso_toppled", "elder_torso", (-480, 350), (0, 74, -20), 0.64),
    ("mourner_torso_bowed", "mourner_torso", (460, 220), (-16, -24, 30), 0.44),
    ("elder_brow", "elder", (420, -320), (-14, -30, -40), 0.33),
    ("warden_crown", "warden", (-660, -320), (70, 10, 60), 0.34),
]
HEADS = ("elder", "warden", "mourner")
TORSOS = ("elder_torso", "warden_torso", "mourner_torso")


class Field:
    """A grid and the shapes measured on it."""

    def __init__(self, lo, hi, voxel, seed):
        self.lo = np.array(lo, np.float32)
        self.h = voxel
        n = np.ceil((np.array(hi) - self.lo) / voxel).astype(int) + 1
        self.xs, self.ys, self.zs = (self.lo[i] + np.arange(n[i], dtype=np.float32) * voxel for i in range(3))
        self.X = self.xs[:, None, None]
        self.Y = self.ys[None, :, None]
        self.Z = self.zs[None, None, :]
        self.seed = seed

    def ell(self, c, r):
        dx, dy, dz = (self.X - c[0]) / r[0], (self.Y - c[1]) / r[1], (self.Z - c[2]) / r[2]
        k0 = np.sqrt(dx * dx + dy * dy + dz * dz)
        k1 = np.sqrt((dx / r[0]) ** 2 + (dy / r[1]) ** 2 + (dz / r[2]) ** 2)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-5)

    def box(self, c, half, r=0.0):
        qx = np.abs(self.X - c[0]) - (half[0] - r)
        qy = np.abs(self.Y - c[1]) - (half[1] - r)
        qz = np.abs(self.Z - c[2]) - (half[2] - r)
        out = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2 + np.maximum(qz, 0) ** 2)
        return out + np.minimum(np.maximum(np.maximum(qx, qy), qz), 0) - r

    def bar(self, a, b, ra, rb=None, squash=1.0):
        """A rod from a to b, radius ra to rb; squash < 1 flattens it in z."""
        rb = ra if rb is None else rb
        a, b = np.array(a, np.float32), np.array(b, np.float32)
        ab = b - a
        ax, ay, az = self.X - a[0], self.Y - a[1], (self.Z - a[2])
        t = np.clip((ax * ab[0] + ay * ab[1] + az * ab[2]) / float(ab @ ab), 0, 1)
        qx, qy, qz = ax - t * ab[0], ay - t * ab[1], (az - t * ab[2]) / squash
        return np.sqrt(qx * qx + qy * qy + qz * qz) - (ra + (rb - ra) * t)

    def noise(self, cell, seed=0):
        """Value noise, 0..1, on a lattice of `cell` metres."""
        rng = np.random.default_rng(self.seed * 1009 + seed)
        fx, fy, fz = self.xs / cell, self.ys / cell, self.zs / cell
        ox, oy, oz = fx.min(), fy.min(), fz.min()
        fx, fy, fz = fx - ox, fy - oy, fz - oz
        lat = rng.random((int(fx.max()) + 3, int(fy.max()) + 3, int(fz.max()) + 3), dtype=np.float32)
        ix, iy, iz = fx.astype(int), fy.astype(int), fz.astype(int)
        sx, sy, sz = (lambda t: t * t * (3 - 2 * t))(fx - ix), (lambda t: t * t * (3 - 2 * t))(fy - iy), (lambda t: t * t * (3 - 2 * t))(fz - iz)
        total = 0
        for a, wx in ((0, 1 - sx), (1, sx)):
            for b, wy in ((0, 1 - sy), (1, sy)):
                for c, wz in ((0, 1 - sz), (1, sz)):
                    total = total + lat[np.ix_(ix + a, iy + b, iz + c)] * wx[:, None, None] * wy[None, :, None] * wz[None, None, :]
        return total

    def fbm(self, cell, octaves=3, seed=0):
        total, amp, sum_amp = 0, 1.0, 0.0
        for i in range(octaves):
            total = total + self.noise(cell / 2 ** i, seed + i) * amp
            sum_amp += amp
            amp *= 0.5
        return total / sum_amp


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b + (a - b) * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def carve(d, cut, k=2.0):
    return smax(d, -cut, k)


def passage(f, d, mouth_z, wide, tall, chamber):
    """Mouth, throat, chamber and the way out of the back of the skull."""
    cx, cy, cz, rx, ry, rz = chamber
    d = carve(d, f.bar((0, -80, mouth_z), (0, cy - 10, cz - 6), wide, wide * 0.72, squash=tall / wide), 2.5)
    d = carve(d, f.ell((cx, cy, cz), (rx, ry, rz)), 5.0)
    d = carve(d, f.bar((0, cy, cz + 2), (0, 80, cz + 6), 19.0, 23.0, squash=0.85), 3.0)
    return d


def eyes(f, d, x, z, y_face, chamber, socket, shaft):
    """A deep socket each side and a shaft down into the chamber."""
    cx, cy, cz = chamber[:3]
    for s in (-1, 1):
        d = carve(d, f.ell((s * x, y_face, z), socket), 2.5)
        d = carve(d, f.bar((s * x, y_face - 8, z), (s * x * 0.55, cy, cz + 6), shaft, shaft * 1.2), 2.0)
    return d


def elder(f):
    """Broad and heavy: flat nose, thick lips, a banded cap, lobed ears."""
    d = f.ell((0, 6, 70), (54, 52, 48))
    d = smin(d, f.box((0, 0, 30), (55, 56, 34), 14), 14)                       # the heavy jaw, wide at the ground
    for s in (-1, 1):
        d = smin(d, f.ell((s * 33, -38, 42), (17, 15, 15)), 8)                 # cheek
        d = smin(d, f.bar((s * 4, -55, 74), (s * 40, -44, 72), 7.5, 6), 5)     # brow
        d = smin(d, f.ell((s * 56, 6, 54), (6, 13, 22)), 3)                    # ear
        d = smin(d, f.bar((s * 57, 6, 40), (s * 62, 6, 28), 6, 7.5), 2)        # lobe
        d = smin(d, f.ell((s * 13, -60, 40), (9.5, 9, 8)), 3)                  # nostril wing
    d = smin(d, f.bar((0, -53, 73), (0, -66, 45), 7, 11), 4)                   # nose
    d = smin(d, f.bar((-24, -55, 31), (24, -55, 31), 6.5), 3)                  # upper lip
    d = smin(d, f.bar((-22, -54, 17), (22, -54, 17), 7.5), 3)                  # lower lip
    d = smin(d, f.ell((0, -44, 6), (24, 16, 11)), 8)                           # chin
    cap = smax(f.ell((0, 6, 72), (59, 57, 49)), 85.0 - f.Z, 1.0)               # a cap, its rim a ledge
    d = smin(d, cap, 0.8)
    d = smin(d, f.box((0, -54, 89), (10, 6, 6), 2), 1)                         # the cap's boss
    for s in (-1, 1):
        d = carve(d, f.bar((s * 13, -80, 37), (s * 13, -56, 38), 2.8), 1.5)    # nostril
    chamber = (0, 12, 50, 34, 34, 30)
    d = passage(f, d, 24.0, 21.0, 8.5, chamber)
    return eyes(f, d, 23, 60, -48, chamber, (14, 13, 12), 9.0)


def warden(f):
    """Long and square: a stepped crown, slit eyes, a block of beard."""
    d = f.box((0, 4, 50), (38, 44, 50), 10)
    for i, (z, w) in enumerate(((94, 42), (104, 34), (114, 24))):              # stepped crown
        d = smin(d, f.box((0, 4, z), (w, w + 4, 6.5), 2), 1.0)
    d = smin(d, f.box((0, -30, 10), (21, 22, 10), 3), 2)                       # beard
    d = smin(d, f.box((0, -44, 73), (31, 7, 4.5), 2), 1.5)                     # brow slab
    d = smin(d, f.bar((0, -43, 72), (0, -54, 44), 5, 7.5), 2)                  # nose
    for s in (-1, 1):
        d = smin(d, f.box((s * 41, 4, 56), (4, 12, 24), 2), 1)                 # slab ears
        for z in (10, 20):
            d = carve(d, f.box((s * 8, -54, z), (0.9, 12, 13)), 0.5)           # beard's grooves
    d = smin(d, f.box((0, -45, 41), (20, 5, 2.5), 1.2), 1.2)                   # lip slab
    for s in (-1, 1):
        d = carve(d, f.bar((s * 7, -70, 42), (s * 6, -50, 43), 1.8), 1)
    chamber = (0, 12, 48, 28, 30, 30)
    d = carve(d, f.box((0, -30, 29), (17, 34, 10), 1.5), 1.5)                  # a straight, letterbox mouth
    d = carve(d, f.ell(chamber[:3], chamber[3:]), 4)
    d = carve(d, f.box((0, 40, 50), (17, 30, 19), 2), 2)                       # a square way out
    for s in (-1, 1):
        d = carve(d, f.box((s * 18, -46, 63), (10, 8, 3.2), 1), 1)             # slit
        d = carve(d, f.bar((s * 18, -42, 63), (s * 10, 10, 58), 4.5, 6), 2)
    return d


def mourner(f):
    """Round and sunken: great round sockets, drooped brows, a small round mouth."""
    d = f.ell((0, 4, 70), (50, 49, 49))
    d = smin(d, f.box((0, 6, 24), (46, 50, 28), 16), 18)                       # sagging down to the ground
    for s in (-1, 1):
        d = smin(d, f.bar((s * 6, -47, 86), (s * 42, -30, 62), 7, 5), 7)       # drooped brow
        d = smin(d, f.ell((s * 34, -32, 34), (14, 14, 18)), 10)                # jowl
        d = smin(d, f.bar((s * 50, 8, 70), (s * 53, 8, 34), 4.5, 7), 3)        # long ear
    d = smin(d, f.bar((0, -47, 74), (0, -56, 48), 5, 6.5), 4)                  # thin nose
    d = smin(d, f.bar((0, -44, 24), (0, -46, 8), 8, 10), 8)                    # chin
    d = smin(d, np.abs(f.bar((0, -50, 28), (0, -46, 28), 14)) - 3.4, 2.5)      # lips, a ring
    chamber = (0, 10, 52, 33, 33, 34)
    d = carve(d, f.bar((0, -80, 28), (0, 0, 40), 11, 16), 2)
    d = carve(d, f.ell(chamber[:3], chamber[3:]), 5)
    d = carve(d, f.bar((0, chamber[1], 58), (0, 80, 60), 19, 23), 2)
    for s in (-1, 1):
        d = carve(d, f.ell((s * 23, -44, 62), (15.5, 17, 15.5)), 2)            # round socket
        d = carve(d, f.bar((s * 23, -50, 62), (s * 12, 12, 58), 9.5, 10), 2)
    return d


def elder_torso(f):
    """Bare and massive, the neck and arms broken off, the chest stove in."""
    d = f.ell((0, 0, 104), (92, 60, 100))
    d = smin(d, f.ell((0, -8, 36), (84, 62, 56)), 24)                          # belly
    for s in (-1, 1):
        d = smin(d, f.ell((s * 92, 0, 142), (38, 42, 34)), 22)                 # shoulder
        d = smin(d, f.ell((s * 40, -50, 126), (40, 18, 28)), 7)                # chest
        d = smin(d, f.bar((s * 102, 0, 134), (s * 122, -8, 60), 30, 27), 8)    # upper arm
        d = carve(d, f.box((s * 150, -8, 40 + s * 8), (48, 70, 34)), 2)        # broken off
    d = smin(d, f.bar((0, 2, 165), (0, 2, 232), 40, 35), 14)                   # neck
    for i in range(13):                                                        # a collar of carved beads
        a = np.pi * (0.2 + 0.6 * i / 12)
        d = smin(d, f.ell((np.cos(a) * 68, -np.sin(a) * 58, 164 - np.sin(a) * 24), (11, 9, 11)), 1.5)
    d = smax(d, f.Z + f.X * 0.28 - 222, 1.5)                                   # the neck's snapped top
    d = carve(d, f.ell((0, 6, 105), (58, 40, 58)), 7)                          # chest cavity
    d = carve(d, f.ell((20, -62, 100), (32, 38, 32)), 3)                       # stove in
    d = carve(d, f.bar((-5, 30, 101), (-8, 80, 100), 25, 28), 3)               # out the back
    return carve(d, f.bar((0, 2, 240), (0, 6, 130), 22, 20), 3)                # down the neck


def warden_torso(f):
    """Square armour, a stepped collar, one fist on the hip: fly the arm's loop."""
    d = f.box((0, 0, 140), (84, 56, 56), 10)                                   # chest
    d = smin(d, f.box((0, 0, 50), (66, 50, 52), 8), 6)                         # waist
    d = smin(d, f.box((0, -2, 34), (78, 58, 13), 3), 1)                        # belt
    for i, (z, w) in enumerate(((198, 66), (211, 50), (224, 34))):             # stepped collar
        d = smin(d, f.box((0, 0, z), (w, w - 6, 8), 2), 1)
    d = smin(d, f.box((0, -56, 132), (62, 12, 46), 3), 1.5)                    # breastplate
    d = carve(d, f.box((0, -72, 132), (38, 12, 26), 1.5), 1)                   # its sunk panel
    for s in (-1, 1):
        d = smin(d, f.box((s * 104, 0, 172), (34, 50, 20), 5), 2)              # pauldron
        d = smin(d, f.box((s * 112, 0, 148), (30, 44, 12), 4), 1)              # its lower tier
    d = smin(d, f.bar((112, 0, 140), (150, -8, 82), 25, 24), 5)                # upper arm
    d = smin(d, f.bar((150, -8, 82), (84, -30, 44), 24, 21), 5)                # forearm
    d = smin(d, f.ell((76, -30, 44), (24, 20, 20)), 4)                         # fist on the hip
    d = smin(d, f.bar((-112, 0, 140), (-124, -4, 60), 25, 24), 5)              # the other arm
    d = carve(d, f.box((-150, -4, 56), (48, 70, 30)), 2)                       # broken off
    d = carve(d, f.box((0, 0, 70), (22, 90, 30), 2), 1.5)                      # a gate through the belly
    return carve(d, f.box((0, 0, 70), (40, 30, 30), 2), 2)                     # its hall


def mourner_torso(f):
    """A hunched robe, arms crossed: in under the hem, out of the neck."""
    d = f.ell((0, 10, 84), (106, 74, 112))
    d = smin(d, f.box((0, 10, 14), (108, 78, 22), 12), 24)                     # the robe's hem spreads
    for s in (-1, 1):
        d = smin(d, f.ell((s * 92, 4, 142), (42, 42, 36)), 20)                 # shoulder
        d = smin(d, f.bar((s * 104, -40, 124), (-s * 34, -84, 96 + s * 9), 24, 21), 6)  # crossed arm
    folds = np.sin(np.arctan2(f.Y - 10, f.X) * 15 + (f.fbm(50, 2, 41) - 0.5) * 3) * np.clip((150 - f.Z) / 90, 0, 1)
    d = d + folds * 2.6
    d = smin(d, f.bar((0, -24, 165), (0, -46, 200), 30, 27), 14)               # bowed neck
    d = smax(d, f.Z - f.X * 0.18 - 192, 1.5)                                   # the neck's snapped top
    d = carve(d, f.bar((0, -130, 0), (0, 10, 24), 36, 32), 3)                  # under the hem
    d = carve(d, f.ell((0, 8, 86), (72, 46, 72)), 7)
    return carve(d, f.bar((0, 4, 130), (0, -52, 214), 24, 25), 3)              # up the neck


BOUNDS = {name: ((-72, -82, -2), (72, 72, TALL + 3)) for name in HEADS}
BOUNDS.update({name: ((-190, -112, -2), (190, 112, 246)) for name in TORSOS})
BOUNDS["mourner_torso"] = ((-180, -150, -2), (180, 112, 246))


def weather(f, d):
    """(full, soft): old stone, and the same without what a bake carries."""
    soft = d + (f.fbm(38, 2, 11) - 0.5) * 3.0
    # Masonry: courses, the joints staggered course by course, each block a
    # little proud or sunk of its neighbours.
    bed = (f.Z + (f.fbm(46, 2, 21) - 0.5) * 8) / COURSE
    row = np.floor(bed)
    round_it = np.arctan2(f.Y, f.X) * RING / BLOCK + row * 0.5 + (f.fbm(60, 2, 23) - 0.5) * 0.5
    col = np.floor(round_it)
    to_bed = (0.5 - np.abs(bed - row - 0.5)) * COURSE
    to_end = (0.5 - np.abs(round_it - col - 0.5)) * BLOCK
    joint = np.minimum(to_bed, to_end)
    block = np.modf(np.sin(row * 12.9898 + col * 78.233) * 43758.5453)[0]
    full = soft + block * 0.45
    full = full + np.clip(1.1 - joint, 0, 1.1) * 0.9                           # the joint's groove
    full = full + (f.fbm(5, 3, 27) - 0.5) * 1.3                                # pits
    crack = np.abs(f.fbm(40, 2, 31) - 0.5) * 90.0 - 1.0
    crack2 = np.abs(f.fbm(17, 2, 33) - 0.5) * 60.0 - 0.5
    return smax(smax(full, -crack, 1.2), -crack2, 0.8), soft


ROUTES = {
    "elder": {"mouth to back": [(0, -85, 24), (0, 12, 44), (0, 75, 56)], "left eye in": [(-23, -62, 60), (-13, 12, 56)], "right eye in": [(23, -62, 60), (13, 12, 56)]},
    "warden": {"mouth to back": [(0, -85, 29), (0, -20, 29), (0, 12, 44), (0, 75, 50)]},  # its slit eyes only let in light
    "mourner": {"mouth to back": [(0, -85, 28), (0, 10, 50), (0, 75, 60)], "left eye in": [(-23, -62, 62), (-12, 12, 58)], "right eye in": [(23, -62, 62), (12, 12, 58)]},
    "elder_torso": {"through the chest": [(20, -105, 100), (0, 6, 103), (-8, 100, 100)], "down the neck": [(0, 2, 242), (0, 6, 105)]},
    "warden_torso": {"gate": [(0, -105, 66), (0, 105, 66)], "arm's loop": [(102, -105, 90), (102, 105, 90)]},
    "mourner_torso": {"hem to neck": [(0, -140, 12), (0, -20, 22), (0, 8, 70), (0, -52, 214)]},
}


def clearance(me, name, label):
    """Free metres round each flight line on this mesh; under 7 m is tight."""
    bm = bmesh.new()
    bm.from_mesh(me)
    tree = BVHTree.FromBMesh(bm)
    for route, pts in ROUTES[name].items():
        least, hit = 1e9, False
        for a, b in zip(pts, pts[1:]):
            a, b = Vector(a), Vector(b)
            if tree.ray_cast(a, (b - a).normalized(), (b - a).length)[0] is not None:
                hit = True
            for t in np.linspace(0, 1, 200):
                least = min(least, tree.find_nearest(a.lerp(b, float(t)))[3])
        print(f"  {name} {route} ({label}): {least:.1f} m clear" + (" BLOCKED" if hit else ""))
    bm.free()


def surface_nets(d, lo, h):
    """(verts, quads) of d's zero set. The grid must enclose it."""
    inside = d < 0
    n = np.array(d.shape)
    corners = np.zeros(n - 1, np.uint8)
    for o in np.ndindex(2, 2, 2):
        corners += inside[o[0]:n[0] - 1 + o[0], o[1]:n[1] - 1 + o[1], o[2]:n[2] - 1 + o[2]]
    active = (corners > 0) & (corners < 8)
    index = -np.ones(active.shape, np.int32)
    cells = np.argwhere(active)
    index[active] = np.arange(len(cells), dtype=np.int32)
    total, count = np.zeros((len(cells), 3), np.float32), np.zeros(len(cells), np.float32)
    for axis in range(3):
        step = np.eye(3, dtype=int)[axis]
        others = [i for i in range(3) if i != axis]
        for a, b in np.ndindex(2, 2):
            offset = np.zeros(3, int)
            offset[others[0]], offset[others[1]] = a, b
            p0 = cells + offset
            p1 = p0 + step
            d0, d1 = d[tuple(p0.T)], d[tuple(p1.T)]
            hit = (d0 < 0) != (d1 < 0)
            t = d0[hit] / (d0[hit] - d1[hit])
            total[hit] += p0[hit] + step * t[:, None]
            count[hit] += 1
    verts = lo + (total / count[:, None]) * h
    quads = []
    for axis in range(3):
        step = np.eye(3, dtype=int)[axis]
        u, v = [i for i in range(3) if i != axis]
        slices = [slice(1, -1)] * 3
        slices[axis] = slice(None, -1)
        s = tuple(slices)
        ahead = tuple(slice(1, None) if i == axis else slices[i] for i in range(3))
        cross = inside[s] != inside[ahead]
        at = np.argwhere(cross) + np.array([0 if i == axis else 1 for i in range(3)])
        flip = inside[tuple(at.T)]
        eu, ev = np.eye(3, dtype=int)[u], np.eye(3, dtype=int)[v]
        c = [index[tuple((at - x).T)] for x in (0 * eu, eu, eu + ev, ev)]
        q = np.stack(c, 1)
        q[flip] = q[flip][:, ::-1]
        quads.append(q)
    return verts, np.concatenate(quads)


def to_object(name, verts, quads):
    """A smooth object of the field's one big piece; a field can leave crumbs."""
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts.tolist(), [], quads.tolist())
    bm = bmesh.new()
    bm.from_mesh(me)
    seen, largest = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, part = [v], []
        seen.add(v.index)
        while stack:
            w = stack.pop()
            part.append(w)
            for e in w.link_edges:
                o = e.other_vert(w)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        if len(part) > len(largest):
            largest = part
    keep = set(v.index for v in largest)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    return ob


def build(name, voxel, seed, out, bake_it):
    f = Field(*BOUNDS[name], voxel, seed)
    full, soft = weather(f, globals()[name](f))
    base = -f.Z
    ob = to_object(name, *surface_nets(smax(full, base, 0.5), f.lo, f.h))
    export(name, out / f"{name}.glb")
    print(f"{name}: {len(ob.data.polygons)} tris")
    clearance(ob.data, name, "full")
    full_ob = ob
    k = STRIDE["torso" if name in TORSOS else "head"]
    coarse = smax(soft, base, 0.5)[::k, ::k, ::k]
    ob = to_object(f"{name}_low", *surface_nets(coarse, f.lo, f.h * k))
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.2, island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    export(name, out / f"{name}_low.glb")
    print(f"{name}_low: {len(ob.data.polygons)} tris")
    clearance(ob.data, name, "low")
    n = len(ob.data.vertices)
    co = np.empty(n * 3)
    ob.data.vertices.foreach_get("co", co)
    tris = np.empty(len(ob.data.polygons) * 3, int)
    ob.data.polygons.foreach_get("vertices", tris)
    uv = np.empty(len(ob.data.loops) * 2)
    ob.data.uv_layers[0].data.foreach_get("uv", uv)
    if bake_it:
        bake(full_ob, ob, name)
    return {"f": f, "soft": soft, "co": co.reshape(-1, 3), "tris": tris.reshape(-1, 3), "uv": uv.reshape(-1, 3, 2)}


def bake(high, low, name):
    """The full mesh's relief and shade onto the low mesh's uvs."""
    game = ROOT / "assets/textures/giants"
    game.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    mat = bpy.data.materials.new("bake")
    low.data.materials.append(mat)
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    mat.node_tree.nodes.active = node
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    for kind, size, samples, tag in (("NORMAL", BAKE_NORMAL, 1, "normal"), ("AO", BAKE_AO, 24, "ao")):
        img = bpy.data.images.new(f"{name}_{tag}", size, size, alpha=False)
        img.colorspace_settings.name = "Non-Color"
        node.image = img
        scene.cycles.samples = samples
        bpy.ops.object.bake(type=kind, use_selected_to_active=True, cage_extrusion=4.0, max_ray_distance=9.0,
                            normal_space="TANGENT", margin=8, use_clear=True)
        img.filepath_raw = str(game / f"{name}_{tag}.png")
        img.file_format = "PNG"
        img.save()
        print(f"baked {name} {tag}", flush=True)


def set_pose(entry, piece, out):
    """The posed, cut mesh and the entry for ruins.json."""
    pose_id, name, spot, tilt, show = entry
    co = piece["co"]
    pivot = (co.max(0) + co.min(0)) / 2
    rot = np.array(Euler([np.radians(t) for t in tilt], "XYZ").to_matrix())
    world = (co - pivot) @ rot.T
    top, bottom = world[:, 2].max(), world[:, 2].min()
    ground = top - (top - bottom) * show
    world[:, 2] -= ground
    bpy.ops.wm.read_factory_settings(use_empty=True)
    me = bpy.data.meshes.new(pose_id)
    me.from_pydata(world.tolist(), [], piece["tris"].tolist())
    me.uv_layers.new(name="UVMap").data.foreach_set("uv", piece["uv"].ravel())
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, -CUT), plane_no=(0, 0, 1), clear_inner=True)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    ob = bpy.data.objects.new(pose_id, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    export(pose_id, out / f"{pose_id}.glb")
    kept = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", kept)
    kept = kept.reshape(-1, 3)
    # The grid in Godot's axes: x, y up, z = -Blender's y.
    lo = np.array((kept[:, 0].min(), -CUT, -kept[:, 1].max())) - CELL * 2
    hi = np.array((kept[:, 0].max(), kept[:, 2].max(), -kept[:, 1].min())) + CELL * 2
    size = (np.ceil((hi - lo) / CELL) + 1).astype(int)
    z, y, x = np.meshgrid(*(lo[i] + np.arange(size[i]) * CELL for i in (2, 1, 0)), indexing="ij")
    posed = np.stack((x.ravel(), -z.ravel(), y.ravel() + ground), 1)
    f = piece["f"]
    local = posed @ rot + pivot                                                # rot's inverse is its transpose
    at = np.round((local - f.lo) / f.h).astype(int)
    shape = np.array(piece["soft"].shape)
    good = np.all((at >= 0) & (at < shape), 1)
    dist = np.full(len(at), 60.0, np.float32)
    dist[good] = piece["soft"][tuple(at[good].T)]
    grid = np.clip(np.round(dist * 2), -127, 127).astype(np.int8)
    rim = kept[np.abs(kept[:, 2]) < 14, :2]                                    # the waterline
    middle = rim.mean(0)
    reach = float(np.sqrt(((rim - middle) ** 2).sum(1)).max())
    print(f"{pose_id}: {len(me.polygons)} tris, {len(piece['tris'])} before the cut, {top - ground:.0f} m showing, grid {size.tolist()}")
    return {"id": pose_id, "piece": name, "x": spot[0], "z": -spot[1], "rim_x": float(middle[0]), "rim_z": -float(middle[1]), "reach": reach,
            "origin": lo.tolist(), "cell": CELL, "size": size.tolist(),
            "d": base64.b64encode(grid.tobytes()).decode()}


def export(name, path):
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_animations=False, export_materials="NONE")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--pieces", default=",".join(HEADS + TORSOS))
    ap.add_argument("--voxel", type=float, default=0.75)
    ap.add_argument("--out", default="scratch/giant_heads")
    ap.add_argument("--bake", action="store_true")
    args = ap.parse_args(argv)
    out = ROOT / args.out
    out.mkdir(parents=True, exist_ok=True)
    (out / "routes.json").write_text(json.dumps(ROUTES))
    pieces = {}
    for name in args.pieces.split(","):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        pieces[name] = build(name, args.voxel * (1.6 if name in TORSOS else 1.0), zlib.crc32(name.encode()) % 1000, out, args.bake)
    if set(pieces) >= set(HEADS + TORSOS):
        game = ROOT / "assets/models/giants"
        game.mkdir(parents=True, exist_ok=True)
        ruins = [set_pose(entry, pieces[entry[1]], game) for entry in POSES]
        (game / "ruins.json").write_text(json.dumps(ruins))
        poses = [{"reach": r["reach"], "lift": round(min(r["reach"] * 0.16, SWELL_MOST), 2), "rim_x": r["rim_x"], "rim_z": r["rim_z"]} for r in ruins]
        (game / "poses.json").write_text(json.dumps(poses))


main()
