"""The stomper's body: the ruins' field and weather on the walking skeleton, and a
still beside a 120 m head and a 55 m head (headless).

    python3 tools/blender.py run art/blender/giant_ruins/stomper_body_build.py \
        -- [--voxel 1.0] [--out scratch/stomper_body] [--quick]

With --swap it also bakes the body and puts it in the game: a coarse mesh of the
bare field (--stride cells of --voxel, as the ruins build theirs), weights by which
mass each vertex lies in, maps in assets/textures/giants/stomper_*.png, and the
mesh replaced inside assets/models/stomper_body.glb, whose skeleton and clips stay
byte for byte. Use --voxel 0.46 --stride 9.

It grew from `elder_torso` (giant_head_build.py): the heads and torsos are carved
masses, so the walker is too, with the elder's sloped shoulders, snapped neck and
stove-in chest. Rounded masses come first (Mass, lofted through ovals), then stone
that wraps each in rings round its own axis (wrapped), not level beds. Same axes
as the ruins, so it looks down -Y; the skeleton looks down +Y, which skinning turns
round. Sizes are play metres on stomper_body.glb's bones: hip 90, knee 49, ankle
11, shoulder 216 at x 94, elbow 154, wrist 100, fingers' end 50, hips 40 apart
each side of the middle, 250 tall and about 125 either side. Limbs stay apart
from the trunk, except at the shoulder, so that each moves with one bone.
"""
import argparse
import json
import math
import struct
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import giant_head_build as ruin  # noqa: E402
from giant_head_build import Field, carve, smax, smin  # noqa: E402

ROOT = ruin.ROOT
SIZE_55 = 55.0 / ruin.TALL
STONE_55 = 0.5
STONE_BODY = 1.5
BOUNDS = ((-138, -66, -2), (138, 66, 256))
WAIST = 124.0
CALM = 1.7                                                                     # legs and pelvis: long stone, few courses
TOPS = {-1: 214, 1: 226}                                                       # the shoulders' tops: unequal, one dropped


def plane(f, n, at):
    """Metres out from a plane through `at`, its normal n."""
    k = 1.0 / math.sqrt(sum(v * v for v in n))
    return ((f.X - at[0]) * n[0] + (f.Y - at[1]) * n[1] + (f.Z - at[2]) * n[2]) * k


def ease(rows, zs, soft):
    """Each column of `rows` (z first) read at zs, the knots rounded off over `soft` metres."""
    rows = np.array(sorted(rows), np.float32)
    fine = np.arange(rows[0, 0] - 3 * soft, rows[-1, 0] + 3 * soft, 0.5, dtype=np.float32)
    bell = np.exp(-0.5 * (np.arange(-3 * soft, 3 * soft + 0.25, 0.5) / soft) ** 2)
    bell /= bell.sum()
    out = []
    for c in range(1, rows.shape[1]):
        line = np.interp(fine, rows[:, 0], rows[:, c])
        line = np.convolve(np.pad(line, len(bell) // 2, "edge"), bell, "valid")
        out.append(np.interp(zs, fine, line[:len(fine)]).astype(np.float32))
    return out


class Mass:
    """A rounded mass lofted up z through oval sections (z, x, y, half x, half
    y), and how its stone lies: rings round its axis. `lean` tips the rings
    per z as (z, dz per m of x, dz per m of y), `sag` bows them, dz per m of x
    squared, and `size` scales their blocks."""

    def __init__(self, f, rows, soft=5.0, size=1.0, lean=None, sag=None, sign=1):
        self.f, self.size, self.sign = f, size, sign
        self.z0, self.z1 = min(r[0] for r in rows), max(r[0] for r in rows)
        self.x, self.y, self.rx, self.ry = ease(rows, f.zs, soft)
        lean = lean or ((0, 0, 0), (260, 0, 0))
        self.lean_x, self.lean_y = ease(lean, f.zs, 8.0)
        self.sag = ease(sag or ((0, 0), (260, 0)), f.zs, 8.0)[0]

    def field(self):
        f = self.f
        rx, ry = self.rx[None, None, :], self.ry[None, None, :]
        dx, dy = f.X - self.x[None, None, :], f.Y - self.y[None, None, :]
        k0 = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)
        k1 = np.sqrt((dx / rx ** 2) ** 2 + (dy / ry ** 2) ** 2)
        slope = np.gradient(rx[0, 0], f.h)
        d = k0 * (k0 - 1) / np.maximum(k1, 1e-5) / np.sqrt(1 + slope ** 2)[None, None, :]
        return smax(d, np.abs(f.Z - (self.z0 + self.z1) / 2) - (self.z1 - self.z0) / 2, 4.0)

    def lay(self, x, y, z, iz):
        """(metres along the courses, angle round, metres per radian, girth)."""
        dx, dy = x - self.x[iz], y - self.y[iz]
        rx, ry = self.rx[iz], self.ry[iz]
        t = z + self.sign * self.lean_x[iz] * dx + self.lean_y[iz] * dy + self.sag[iz] * dx * dx
        phi = np.arctan2(dy / ry, dx / rx)
        return t, phi, np.sqrt((rx * np.sin(phi)) ** 2 + (ry * np.cos(phi)) ** 2), 2 * np.pi * np.sqrt((rx * rx + ry * ry) / 2) + 0 * x


class Dome:
    """Stone laid in rings of latitude round a pole, on a shoulder or a foot."""

    def __init__(self, at, pole, reach, size=1.0):
        self.at, self.reach, self.size = np.array(at, np.float32), reach, size
        self.pole = np.array(pole, np.float32) / np.linalg.norm(pole)
        side = np.cross(self.pole, (0, 1, 0))
        self.a = side / np.linalg.norm(side)
        self.b = np.cross(self.pole, self.a)

    def lay(self, x, y, z, iz):
        v = (x - self.at[0], y - self.at[1], z - self.at[2])
        h = sum(v[i] * self.pole[i] for i in range(3))
        a = sum(v[i] * self.a[i] for i in range(3))
        b = sum(v[i] * self.b[i] for i in range(3))
        r = np.sqrt(a * a + b * b)
        t = np.clip(np.arctan2(r, h), 0.55, 1.75) * self.reach                 # no little disc on the pole, no target at its far end
        return t, np.arctan2(b, a), np.maximum(r, 1.0), 2 * np.pi * r


def wrapped(f, d, parts, stone):
    """The masonry of `parts`, each (field, laid-by): courses and joints that go
    round each mass in its own frame, a seam where two masses meet. weather()
    takes this in place of blocks()."""
    rng = np.random.default_rng(f.seed * 104729 + 3)
    shape = d.shape
    cell = np.zeros(shape, np.int32)
    face = np.full(shape, 99.0, np.float32)
    u, v = np.zeros(shape, np.float32), np.zeros(shape, np.float32)
    hu, hv = np.full(shape, 9.0, np.float32), np.full(shape, 9.0, np.float32)
    row = np.zeros(shape, np.int32)
    band = np.nonzero(np.abs(d) < 5.0 * f.h + 9.0 * stone + 2.0)
    near = np.stack([p[0][band] for p in parts])
    order = np.argsort(near, 0)
    pick, second = order[0], order[1]
    seam = (np.take_along_axis(near, order[1:2], 0)[0] - np.take_along_axis(near, order[:1], 0)[0]) / 2
    del near, order
    x, y, z = f.xs[band[0]], f.ys[band[1]], f.zs[band[2]]
    base, rows = 1, 1
    for p, (_, laid) in enumerate(parts):
        mine = np.nonzero(pick == p)[0]
        t, phi, per, girth = laid.lay(x[mine], y[mine], z[mine], band[2][mine])
        beds = ruin.cuts(float(t.min()), float(t.max()), [c * stone * laid.size for c in ruin.COURSES], rng)
        i = np.searchsorted(beds, t, side="right") - 1
        lo, hi = beds[i], beds[i + 1]
        f_course = np.minimum(t - lo, hi - t)
        cu, ju, half = np.zeros(len(mine), np.float32), np.full(len(mine), 99.0, np.float32), np.full(len(mine), 9.0, np.float32)
        ids = np.zeros(len(mine), np.int32)
        for r in np.unique(i):
            ring = np.nonzero(i == r)[0]
            joints = ruin.cuts(0.0, float(girth[ring].mean()), [b * stone * laid.size for b in ruin.BLOCKS], rng)
            joints = joints[joints > 0]
            if len(joints) < 3:
                ids[ring] = base                                               # one stone right round, a cap
                base += 1
                continue
            joints = np.concatenate(([0.0], joints / joints[-1] * 2 * np.pi))
            a = (phi[ring] + rng.uniform(0, 2 * np.pi)) % (2 * np.pi)
            j = np.searchsorted(joints, a, side="right") - 1
            j = np.minimum(j, len(joints) - 2)
            e0, e1 = joints[j], joints[j + 1]
            m = per[ring]
            ju[ring] = np.minimum(a - e0, e1 - a) * m
            cu[ring] = (a - (e0 + e1) / 2) / ((e1 - e0) / 2)
            half[ring] = (e1 - e0) / 2 * m
            ids[ring] = base + j
            base += len(joints)
        at = tuple(b[mine] for b in band)
        cell[at] = ids
        face[at] = np.minimum(np.minimum(f_course, ju), seam[mine])
        u[at] = cu
        v[at] = (t - (lo + hi) / 2) / np.maximum((hi - lo) / 2, 0.01)
        hu[at] = half
        hv[at] = (hi - lo) / 2
        row[at] = rows + i
        rows += len(beds) + 1
    _, cell = np.unique(cell, return_inverse=True)
    w = np.zeros(shape, np.float32)
    return cell.reshape(shape).astype(np.int32), face, (u, v, w), (hu, hv, np.full(shape, 99.0, np.float32)), row


def ease_walls(d):
    """One 1-2-1 blur in each axis, no more or the stone goes soft: a lost
    block's wall is a jump in the field, which a surface net draws as a stair."""
    for axis in range(3):
        d = (np.roll(d, 1, axis) + 2 * d + np.roll(d, -1, axis)) / 4
    return d


def trunk(f):
    """From elder_torso, its bare mass grown into a body: ribs that turn from
    front to side to back, a waist well in from them, the pelvis under it."""
    rows = (                                         # z, x, y, half x, half y
        (76, 0, 2, 40, 26), (92, 0, 3, 60, 32), (106, 0, 3, 60, 33), (120, 0, 2, 53, 33),
        (134, 0, 0, 47, 32), (152, 0, -3, 51, 35), (176, 0, -5, 60, 42), (194, 0, -4, 66, 45),
        (208, 0, -1, 64, 43), (220, 0, 1, 46, 36), (231, 0, 3, 31, 29), (258, 0, 5, 27, 25))
    ribs = Mass(f, rows, 7.0, 1.0, lean=((130, 0, -0.1), (200, 0, 0.1)), sag=((132, 0), (190, 0.0055), (235, 0.007)))
    pelvis = Mass(f, rows, 7.0, CALM)
    d = ribs.field()
    for s in (-1, 1):
        d = smin(d, f.ell((s * 33, -38, 190), (34, 11, 24)), 10)               # the chest, a plate each side, low
        d = smin(d, f.ell((s * 44, 27, 186), (30, 15, 44)), 14)                # shoulder blade and lat
        d = smin(d, f.ell((s * 32, 12, 96), (27, 21, 24)), 10)                 # the seat
        d = smin(d, f.bar((s * 18, 4, 221), (s * 84, 1, TOPS[s] - 17), 20, 20, 0.85), 12)  # the slope from neck to shoulder
    d = carve(d, f.bar((0, -56, 216), (0, -51, 150), 3.2, 2.0), 3)             # breastbone
    d = carve(d, f.bar((0, 53, 224), (0, 42, 112), 3.4, 2.6), 3)               # the spine's groove
    d = smax(d, plane(f, (0.26, 0.1, 1), (0, 0, 246)), 1.0)                    # the snapped neck
    d = carve(d, f.bar((-2, 4, 268), (0, 5, 240), 10, 8), 1)                   # down the neck, a little way
    d = carve(d, f.ell((-60, -12, 138), (22, 40, 36)), 9)                      # one flank worn deeper
    return d, ribs, pelvis


def arm(f, s):
    """Hung clear of the trunk: a round shoulder, an upper arm and a forearm
    that taper to the elbow and the wrist, and a small closed hand."""
    top = TOPS[s]
    length = Mass(f, ((212, s * 96, 1, 22, 24), (186, s * 97, 1, 21, 23.5), (166, s * 97, 2, 16, 19),
                      (155, s * 97, 3, 15, 18.5), (142, s * 96, 1, 18, 20.5), (124, s * 95, -2, 15, 17),
                      (107, s * 94, -3, 11.5, 13.5), (101, s * 94, -3, 11.5, 13.5)),
                  3.5, 0.8, lean=((190, 0, -0.18), (155, 0, 0.0), (120, 0, 0.2)), sign=s)
    d = smin(length.field(), f.ell((s * 97, 18, 155), (10, 8, 11)), 5)         # the elbow's point, behind
    shoulder = f.ell((s * 96, 0, top - 32), (24, 28, 33))
    cap = Dome((s * 88, 0, top - 36), (s * 0.75, 0, 0.66), 38, 1.0)
    hand = Mass(f, ((108, s * 94, -3, 11, 13), (92, s * 94, -5, 14.5, 17), (74, s * 94, -7, 14, 16.5), (64, s * 94, -7, 12.5, 15), (58, s * 94, -7, 10, 12)),
                3.0, 0.8, lean=((60, 0, 0.3), (110, 0, 0.3)), sign=s)
    fist = smax(hand.field(), plane(f, (0, -0.55, -1), (0, -14, 64)), 2.0)     # the knuckles' plane
    fist = smin(fist, f.bar((s * 82, -13, 100), (s * 84, -14, 76), 5.5, 4.5), 2)  # thumb along it
    return (d, length), (shoulder, cap), (fist, hand)


def leg(f, s):
    """A great thigh narrowing to a knee that shows, a calf, an ankle and a
    foot cut from one block. Long stone with little fan to it: thin rings
    round a thigh read as bandages."""
    length = Mass(f, ((98, s * 36, 2, 25, 31), (84, s * 37, 1, 26.5, 31), (70, s * 41, -1, 25, 28.5), (60, s * 44, -3, 19.5, 24),
                      (49, s * 44, -4, 20.5, 24), (41, s * 44, -2, 16, 20), (32, s * 44, 3, 17.5, 22), (22, s * 44, 3, 14, 17),
                      (13, s * 44, 1, 13, 15.5), (6, s * 44, 1, 13, 15.5)),
                  3.0, CALM, lean=((80, 0, -0.06), (50, 0, 0.0), (25, 0, 0.07)), sign=s)
    d = smin(length.field(), f.ell((s * 44, -25, 50), (13, 8, 10)), 4)          # the knee's cap
    d = carve(d, f.bar((s * 22, -26, 62), (s * 66, -26, 62), 1.6), 3)          # over it
    return (d, length), foot(f, s * 44)


class Block:
    """Level courses, their joints round a block's middle."""

    def __init__(self, x, y, size):
        self.x, self.y, self.size = x, y, size

    def lay(self, x, y, z, iz):
        dx, dy = x - self.x, y - self.y
        r = np.sqrt(dx * dx + dy * dy)
        return z, np.arctan2(dy, dx), np.maximum(r, 1.0), 2 * np.pi * np.maximum(r, 30.0)


def foot(f, x):
    """One hard block, every face a plane: a plinth under a battered wedge that
    climbs from the toe to the ankle, the corners struck off. Front is -y."""
    over = np.abs(f.X - x)

    def walls(grow):
        cut = [over - 27 - grow + 0.1 * f.Z, f.Y - 26 - grow + 0.1 * f.Z, -f.Y - 50 - grow + 0.26 * f.Z,
               (over - f.Y - 62 - grow * 1.41) / 1.414, (over + f.Y - 43 - grow * 1.41) / 1.414]
        d = cut[0]
        for c in cut[1:]:
            d = smax(d, c, 0.7)
        return d

    upper = smax(walls(0.0), f.Z - (15 + (f.Y + 50) * 0.42), 0.7)              # up from the toe
    upper = smax(upper, f.Z - (33 - (f.Y - 2) * 0.8), 0.7)                     # and down the heel
    upper = smax(upper, f.Z - 34, 0.7)
    sole = smax(walls(2.6), f.Z - 7.5, 0.7)
    return smax(np.minimum(upper, sole), -1 - f.Z, 0.7), Block(x, -12, 1.2)


# Where the stone has come away: the chest stove in as the elder's is, the dropped
# shoulder's back, a hip, a forearm, a shin, the ribs behind.
LOSSES = [((30, -46, 190), 30, 9), ((-110, 18, 198), 28, 9), ((56, 34, 100), 16, 6),
          ((-94, -6, 128), 12, 4), ((60, 12, 30), 10, 3.5), ((34, 44, 180), 15, 5)]


# Across the big masses, not along a limb, where one reads as a zip.
FRACTURES = [((-34, -42, 170), 60), ((24, 44, 160), 70), ((40, -33, 104), 34), ((-58, 8, 72), 26)]


def stomper(f):
    """The field, its masses and how each lays its stone, and what each is."""
    d, ribs, pelvis = trunk(f)
    parts = [(np.maximum(d, WAIST - f.Z), ribs), (np.maximum(d, f.Z - WAIST), pelvis)]
    kinds = [("ribs", 0), ("pelvis", 0)]
    for s in (-1, 1):
        for mass, kind in zip(leg(f, s), ("leg", "foot")):
            d = np.minimum(d, mass[0])
            parts.append(mass)
            kinds.append((kind, s))
    for s in (-1, 1):
        (length, shoulder, hand) = arm(f, s)
        one = np.minimum(np.minimum(length[0], shoulder[0]), hand[0])
        joined = smin(d, one, 12.0)
        apart = np.minimum(d, one)
        high = np.clip((f.Z - 190) / 16, 0, 1)                                 # arms fuse at the shoulder, nowhere else
        d = apart + (joined - apart) * high
        parts += [length, shoulder, hand]
        kinds += [("arm", s), ("shoulder", s), ("hand", s)]
    return d, parts, kinds


# The skin's joints in stomper_body.glb, in its order. The skeleton looks down +Y, so
# the field's +x, turned round, is the skeleton's left.
JOINTS = ("root", "hips", "spine", "chest", "neck",
          "upper_arm.L", "forearm.L", "hand.L", "fingers.L", "thumb.L",
          "upper_arm.R", "forearm.R", "hand.R", "fingers.R", "thumb.R",
          "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R")
MODEL_SCALE = 250.0 / 7.02                                                     # stomper.gd: HEIGHT/MODEL_HEIGHT
GLB = "assets/models/stomper_body.glb"
SMOOTH_WEIGHTS = 2


def step(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def weights(co, label, kinds, edges):
    """(joints, weights), four each per vertex: rigid in each mass, turning over at
    the waist, shoulder, hip, knee, ankle, elbow and wrist, then a little smoothing
    along the mesh's edges, so no seam of two masses is a cliff."""
    w = np.zeros((len(co), len(JOINTS)), np.float32)
    x, z = np.abs(co[:, 0]), co[:, 2]
    bone = {n: i for i, n in enumerate(JOINTS)}
    def add(mask, name, share):
        w[mask, bone[name]] += share[mask]
    for k, (kind, s) in enumerate(kinds):
        at = label == k
        tag = ".L" if s > 0 else ".R"
        if kind in ("ribs", "pelvis"):
            spine, chest, neck = step(102, 126, z), step(156, 186, z), step(228, 240, z)
            add(at, "hips", 1 - spine)
            add(at, "spine", spine * (1 - chest))
            add(at, "chest", chest * (1 - neck))
            add(at, "neck", neck)
        elif kind == "leg":
            front = step(-2, -18, co[:, 1])                                    # the knee's cap goes with the shin, the crease over it takes the bend
            hip, shin, foot = step(84, 100, z), 1 - step(42 + 16 * front, 52 + 16 * front, z), 1 - step(7, 20, z)
            add(at, "hips", hip)
            add(at, "thigh" + tag, (1 - hip) * (1 - shin))
            add(at, "shin" + tag, shin * (1 - foot))
            add(at, "foot" + tag, foot)
        elif kind == "foot":
            add(at, "foot" + tag, np.ones_like(z))
        elif kind == "arm":
            upper, hand = step(145, 165, z), 1 - step(100, 112, z)
            add(at, "upper_arm" + tag, upper)
            add(at, "forearm" + tag, (1 - upper) * (1 - hand))
            add(at, "hand" + tag, hand)
        elif kind == "shoulder":
            arm = step(66, 86, x)
            add(at, "chest", 1 - arm)
            add(at, "upper_arm" + tag, arm)
        elif kind == "hand":
            add(at, "hand" + tag, np.ones_like(z))
    a, b = edges[:, 0], edges[:, 1]
    for _ in range(SMOOTH_WEIGHTS):
        total = w.copy()
        count = np.ones(len(co), np.float32)
        np.add.at(total, a, w[b])
        np.add.at(total, b, w[a])
        np.add.at(count, a, 1)
        np.add.at(count, b, 1)
        w = total / count[:, None]
    order = np.argsort(-w, 1)[:, :4]
    top = np.take_along_axis(w, order, 1)
    top[top < 0.02] = 0
    return order.astype(np.uint8), (top / top.sum(1, keepdims=True)).astype(np.float32)


def swap_mesh(path, position, normal, uv, joints, weight, tris):
    """stomper_body.glb's mesh replaced, one surface, all else as it was."""
    raw = Path(path).read_bytes()
    size = struct.unpack("<I", raw[12:16])[0]
    gltf = json.loads(raw[20:20 + size])
    data = raw[20 + size + 8:]
    old = set()
    for prim in gltf["meshes"][0]["primitives"]:
        old |= set(prim["attributes"].values()) | {prim["indices"]}
    keep = [i for i in range(len(gltf["accessors"])) if i not in old]
    remap = {a: n for n, a in enumerate(keep)}
    out, views, accessors = bytearray(), [], []
    def put(blob, target=None):
        while len(out) % 4:
            out.append(0)
        view = {"buffer": 0, "byteOffset": len(out), "byteLength": len(blob)}
        if target:
            view["target"] = target
        out.extend(blob)
        views.append(view)
        return len(views) - 1
    for i in keep:
        acc = dict(gltf["accessors"][i])
        view = gltf["bufferViews"][acc["bufferView"]]
        start = view.get("byteOffset", 0)
        acc["bufferView"] = put(data[start:start + view["byteLength"]])
        accessors.append(acc)
    def add(a, type_, component, target=34962, bounds=False):
        acc = {"bufferView": put(a.tobytes(), target), "componentType": component, "count": len(a), "type": type_}
        if bounds:
            acc["min"], acc["max"] = a.min(0).tolist(), a.max(0).tolist()
        accessors.append(acc)
        return len(accessors) - 1
    prim = {"attributes": {"POSITION": add(position, "VEC3", 5126, bounds=True), "NORMAL": add(normal, "VEC3", 5126),
                           "TEXCOORD_0": add(uv, "VEC2", 5126), "JOINTS_0": add(joints, "VEC4", 5121),
                           "WEIGHTS_0": add(weight, "VEC4", 5126)},
            "indices": add(tris.ravel(), "SCALAR", 5125, 34963), "material": 0}
    gltf["meshes"][0]["primitives"] = [prim]
    gltf["materials"] = gltf["materials"][:1]
    gltf["accessors"], gltf["bufferViews"] = accessors, views
    gltf["buffers"][0]["byteLength"] = len(out)
    for skin in gltf["skins"]:
        skin["inverseBindMatrices"] = remap[skin["inverseBindMatrices"]]
    for anim in gltf["animations"]:
        for sampler in anim["samplers"]:
            sampler["input"], sampler["output"] = remap[sampler["input"]], remap[sampler["output"]]
    text = json.dumps(gltf, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    out.extend(b"\0" * (-len(out) % 4))
    with open(path, "wb") as fh:
        fh.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(text) + 8 + len(out)))
        fh.write(struct.pack("<II", len(text), 0x4E4F534A) + text)
        fh.write(struct.pack("<II", len(out), 0x004E4942) + bytes(out))


def swap(f, soft, high, parts, kinds, stride):
    """Bake the body onto a coarse mesh of `soft` and put it in the game."""
    low = ruin.to_object("stomper_low", *ruin.surface_nets(smax(soft, -f.Z, 0.5)[::stride, ::stride, ::stride], f.lo, f.h * stride))
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.2, island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    me = low.data
    n = len(me.vertices)
    print(f"low: {len(me.polygons)} tris on a {f.h * stride:.2f} m grid", flush=True)
    co = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    normals = np.empty(n * 3, np.float32)
    me.vertex_normals.foreach_get("vector", normals)
    normals = normals.reshape(-1, 3)
    tris = np.empty(len(me.polygons) * 3, np.int32)
    me.polygons.foreach_get("vertices", tris)
    tris = tris.reshape(-1, 3)
    edges = np.empty(len(me.edges) * 2, np.int32)
    me.edges.foreach_get("vertices", edges)
    uv = np.empty(len(me.loops) * 2, np.float32)
    me.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    cell = tuple(np.clip(np.round((co - f.lo) / f.h).astype(int), 0, np.array(soft.shape) - 1).T)
    label = np.stack([p[0][cell] for p in parts]).argmin(0)
    joints, weight = weights(co, label, kinds, edges.reshape(-1, 2))
    # A vertex per position and uv: split along the uvs' seams only.
    key = np.column_stack((tris.ravel(), np.round(uv * 65536).astype(np.int64)))
    _, first, back = np.unique(key, axis=0, return_index=True, return_inverse=True)
    at = tris.ravel()[first]
    flip = lambda a: np.column_stack((-a[:, 0], a[:, 2], a[:, 1]))             # the field looks down -Y, the skeleton +Y, and to glTF's Y up
    texcoord = uv[first] * (1, -1) + (0, 1)
    ruin.bake(high, low, "stomper")
    swap_mesh(ROOT / GLB, (flip(co[at]) / MODEL_SCALE).astype(np.float32), flip(normals[at]).astype(np.float32), texcoord.astype(np.float32),
              joints[at], weight[at], back.reshape(-1, 3).astype(np.uint32))
    np.savez(ROOT / "scratch/stomper_body/low.npz", co=co, label=label, kinds=np.array([k[0] + str(k[1]) for k in kinds]))
    print(f"swapped: {len(at)} verts, {len(tris)} tris in {GLB}", flush=True)


def scaled(fn, bounds, voxel, seed, k):
    """A piece's field at k of its size, its weather in true metres."""
    lo, hi = (np.array(b, np.float32) for b in bounds)
    big = Field(lo, hi, voxel / k, seed)
    small = Field(lo * k, hi * k, voxel, seed)
    return small, fn(big) * k


def place(name, full, f, at, material, turn=0.0):
    base = -f.Z
    ob = ruin.to_object(name, *ruin.surface_nets(smax(full, base, 0.5), f.lo, f.h))
    ob.location = at
    ob.rotation_euler = (0, 0, math.radians(turn))
    ob.data.materials.append(material)
    ob.data.set_sharp_from_angle(angle=math.radians(38))                       # keep what's cut, cut
    print(f"{name}: {len(ob.data.polygons)} tris", flush=True)
    return ob


def material(name, rgb):
    m = bpy.data.materials.new(name)
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Roughness"].default_value = 0.95
    return m


def marker(at):
    """The plane, true to scale, in orange."""
    mark = material("plane", (1.0, 0.28, 0.02))
    for size in ((2.8, 0.7, 0.2), (0.4, 2.2, 0.3)):
        bpy.ops.mesh.primitive_cube_add(location=at)
        bpy.context.object.scale = [v / 2 for v in size]
        bpy.context.object.data.materials.append(mark)


def shot(scene, out, name, at, look, lens):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    cam.clip_end = 12000
    ob = bpy.data.objects.new(name, cam)
    scene.collection.objects.link(ob)
    ob.location = at
    ob.rotation_euler = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = ob
    scene.render.filepath = str(out / f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print("wrote", scene.render.filepath, flush=True)


def stage():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 1600, 900
    bpy.ops.mesh.primitive_plane_add(size=12000)
    bpy.context.object.data.materials.append(material("plain", (0.33, 0.20, 0.07)))
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 4.0
    sun.color = (1.0, 0.86, 0.66)
    sun.angle = math.radians(2)
    so = bpy.data.objects.new("sun", sun)
    scene.collection.objects.link(so)
    so.rotation_euler = (math.radians(62), 0, math.radians(-38))
    world = bpy.data.worlds.new("world")
    scene.world = world
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.82, 0.66, 0.5, 1)
    bg.inputs[1].default_value = 0.7
    return scene


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--voxel", type=float, default=1.0)
    ap.add_argument("--out", default="scratch/stomper_body")
    ap.add_argument("--quick", action="store_true", help="the body alone, stone and black outline, to judge the shape")
    ap.add_argument("--swap", action="store_true", help="bake the body and swap it into the game; no stills")
    ap.add_argument("--stride", type=int, default=9)
    args = ap.parse_args(argv)
    out = ROOT / args.out
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = stage()
    stone = material("stone", (0.20, 0.155, 0.115))
    f = Field(*BOUNDS, args.voxel, 7)
    d, parts, kinds = stomper(f)
    full, soft = ruin.weather(f, d, stone=STONE_BODY, losses=LOSSES, breaks=0, fractures=FRACTURES, masonry=wrapped(f, d, parts, STONE_BODY))
    full = ease_walls(full)
    body = place("stomper", full, f, (0, 0, 0), stone)
    co = np.empty(len(body.data.vertices) * 3)
    body.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    print("bounds", co.min(0).round(1), co.max(0).round(1))
    if args.swap:
        swap(f, soft, body, parts, kinds, args.stride)
        return
    if args.quick:
        scene.render.resolution_x, scene.render.resolution_y = 900, 900
        shot(scene, out, "q_chest", (40, -300, 190), (20, 0, 196), 60)
        scene.cycles.samples = 8
        shot(scene, out, "q_front", (0, -1150, 120), (0, 0, 122), 115)
        shot(scene, out, "q_quarter", (620, -940, 150), (0, 0, 122), 115)
        shot(scene, out, "q_side", (1150, 0, 120), (0, 0, 122), 115)
        shot(scene, out, "q_back", (-420, 900, 90), (0, 0, 122), 115)
        return
    for k in (3, 4, 5):                                                        # what a coarse field mesh would cost
        me = ruin.to_object("try", *ruin.surface_nets(smax(soft, -f.Z, 0.5)[::k, ::k, ::k], f.lo, f.h * k))
        print(f"coarse mesh, a {f.h * k:.1f} m grid: {len(me.data.polygons)} tris", flush=True)
        bpy.data.objects.remove(me)
    f = Field(*ruin.BOUNDS["elder"], args.voxel, 11)
    place("head_120", ruin.weather(f, ruin.elder(f))[0], f, (-300, -40, 0), stone, 18)
    fine = args.voxel * 0.55                                                   # finer stone on a finer grid and no blocks lost from the face, or it goes to mush
    f, d = scaled(ruin.warden, ruin.BOUNDS["warden"], fine, 13, SIZE_55)
    place("head_55", ruin.weather(f, d, stone=STONE_55, losses=(((17, -6, 50), 11, 3), ((16, 16, 6), 10, 3)), breaks=0, cracks=3)[0], f, (215, -90, 0), stone, -14)
    f, d = scaled(ruin.mourner, ruin.BOUNDS["mourner"], fine, 17, SIZE_55)
    place("head_55b", ruin.weather(f, d, stone=STONE_55, losses=(((-20, 12, 44), 11, 3), ((20, 16, 8), 10, 3)), breaks=0, cracks=3)[0], f, (300, -10, 0), stone, -30)
    marker((90, -220, 60))
    shot(scene, out, "front", (0, -1150, 70), (0, 0, 118), 50)
    shot(scene, out, "three_quarter", (620, -940, 150), (40, 0, 112), 50)
    shot(scene, out, "close", (240, -420, 40), (20, 0, 150), 42)
    shot(scene, out, "back", (-420, 900, 90), (0, 0, 118), 50)
    for ob in scene.objects:
        ob.hide_render = ob.name.startswith("head_")                           # they stand in the way from the side
    shot(scene, out, "side", (-1150, -60, 110), (0, 0, 118), 75)
    for ob in scene.objects:
        ob.hide_render = False
    shot(scene, out, "heads", (250, -290, 24), (250, -50, 26), 50)


if __name__ == "__main__":
    main()
