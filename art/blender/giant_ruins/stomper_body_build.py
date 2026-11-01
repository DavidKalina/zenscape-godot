"""The stomper's body, rough stage: the ruins' field and weather on the walking
skeleton, and a still beside a 120 m head and a 55 m head (headless).

    python3 tools/blender.py run art/blender/giant_ruins/stomper_body_build.py \
        -- [--voxel 1.0] [--out scratch/stomper_body] [--quick]

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
import math
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
        (76, 0, 2, 40, 28), (92, 0, 4, 60, 38), (106, 0, 4, 60, 38), (120, 0, 2, 53, 35),
        (134, 0, 0, 47, 32), (152, 0, -3, 51, 35), (176, 0, -5, 60, 42), (194, 0, -4, 66, 45),
        (208, 0, -1, 64, 43), (220, 0, 1, 46, 36), (231, 0, 3, 31, 29), (258, 0, 5, 27, 25))
    ribs = Mass(f, rows, 7.0, 1.0, lean=((130, 0, -0.1), (200, 0, 0.1)), sag=((132, 0), (190, 0.0055), (235, 0.007)))
    pelvis = Mass(f, rows, 7.0, 0.8, lean=((80, 0, 0.14), (124, 0, 0.08)), sag=((80, -0.007), (124, -0.003)))
    d = ribs.field()
    for s in (-1, 1):
        d = smin(d, f.ell((s * 33, -38, 190), (34, 11, 24)), 10)               # the chest, a plate each side, low
        d = smin(d, f.ell((s * 44, 27, 186), (30, 15, 44)), 14)                # shoulder blade and lat
        d = smin(d, f.ell((s * 32, 18, 94), (27, 17, 24)), 10)                 # the seat
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
    heavy foot."""
    length = Mass(f, ((98, s * 36, 2, 25, 37), (84, s * 37, 0, 27, 38), (70, s * 41, -1, 25.5, 33), (60, s * 44, -3, 19.5, 24),
                      (49, s * 44, -4, 20.5, 24), (41, s * 44, -2, 16, 20), (32, s * 44, 3, 17.5, 22), (22, s * 44, 3, 14, 17),
                      (13, s * 44, 1, 13, 15.5), (6, s * 44, 1, 13, 15.5)),
                  3.0, 0.9, lean=((80, 0, -0.2), (50, 0, 0.0), (25, 0, 0.22)), sign=s)
    d = smin(length.field(), f.ell((s * 44, -25, 50), (13, 8, 10)), 4)          # the knee's cap
    d = carve(d, f.bar((s * 22, -26, 62), (s * 66, -26, 62), 1.6), 3)          # over it
    foot = Mass(f, ((-1, s * 44, -11, 25, 37), (7, s * 44, -11, 25, 37), (15, s * 44, -7, 20, 28), (24, s * 44, 0, 15, 17), (30, s * 44, 1, 13, 15)),
                2.5, 0.7, lean=((0, 0, 0), (30, 0, 0.3)), sign=s)
    return (d, length), (foot.field(), foot)


# Where the stone has come away: the chest stove in as the elder's is, the dropped
# shoulder's back, a hip, a forearm, a shin, the ribs behind.
LOSSES = [((30, -46, 190), 30, 9), ((-110, 18, 198), 28, 9), ((56, 40, 100), 16, 6),
          ((-94, -6, 128), 12, 4), ((60, 12, 30), 10, 3.5), ((34, 44, 180), 15, 5)]


# Across the big masses, not along a limb, where one reads as a zip.
FRACTURES = [((-34, -42, 170), 60), ((24, 44, 160), 70), ((40, -33, 104), 34), ((-58, 8, 72), 26)]


def stomper(f):
    """The field, and its masses and how each lays its stone."""
    d, ribs, pelvis = trunk(f)
    parts = [(np.maximum(d, WAIST - f.Z), ribs), (np.maximum(d, f.Z - WAIST), pelvis)]
    for s in (-1, 1):
        for mass in leg(f, s):
            d = np.minimum(d, mass[0])
            parts.append(mass)
    for s in (-1, 1):
        (length, shoulder, hand) = arm(f, s)
        one = np.minimum(np.minimum(length[0], shoulder[0]), hand[0])
        joined = smin(d, one, 12.0)
        apart = np.minimum(d, one)
        high = np.clip((f.Z - 190) / 16, 0, 1)                                 # arms fuse at the shoulder, nowhere else
        d = apart + (joined - apart) * high
        parts += [length, shoulder, hand]
    return d, parts


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
    args = ap.parse_args(argv)
    out = ROOT / args.out
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = stage()
    stone = material("stone", (0.20, 0.155, 0.115))
    f = Field(*BOUNDS, args.voxel, 7)
    d, parts = stomper(f)
    full, soft = ruin.weather(f, d, stone=STONE_BODY, losses=LOSSES, breaks=0, fractures=FRACTURES, masonry=wrapped(f, d, parts, STONE_BODY))
    full = ease_walls(full)
    body = place("stomper", full, f, (0, 0, 0), stone)
    co = np.empty(len(body.data.vertices) * 3)
    body.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    print("bounds", co.min(0).round(1), co.max(0).round(1))
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
