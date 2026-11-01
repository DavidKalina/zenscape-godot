"""The stomper's body, rough stage: the ruins' field and weather on the walking
skeleton, and a still beside a 120 m head and a 55 m head (headless).

    python3 tools/blender.py run art/blender/giant_ruins/stomper_body_build.py \
        -- [--voxel 1.0] [--out scratch/stomper_body]

It grew from `elder_torso` (giant_head_build.py): the heads and torsos are carved
masses, so the walker is too, with the elder's sloped shoulders, snapped neck and
stove-in chest, recut in flat planes. Same axes as the ruins, so it looks down -Y;
the skeleton looks down +Y, which skinning turns round. Sizes are play metres on stomper_body.glb's bones: hip 90, knee 49, ankle
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
HIP_X = 40.4
ARM_X = 94.0


def plane(f, n, at):
    """Metres out from a plane through `at`, its normal n."""
    k = 1.0 / math.sqrt(sum(v * v for v in n))
    return ((f.X - at[0]) * n[0] + (f.Y - at[1]) * n[1] + (f.Z - at[2]) * n[2]) * k


def block(f, z0, z1, lo, hi, chamfer=0.0):
    """A cut block from z0 to z1 with flat sides: its section (x, y, half x,
    half y) goes from `lo` to `hi`, its corners cut back by `chamfer`."""
    t = (f.Z - z0) / (z1 - z0)
    cx, cy, hx, hy = (a + (b - a) * t for a, b in zip(lo, hi))
    ax, ay = np.abs(f.X - cx), np.abs(f.Y - cy)
    d = np.maximum(np.maximum(ax - hx, ay - hy), np.abs(f.Z - (z0 + z1) / 2) - abs(z1 - z0) / 2)
    if chamfer:
        d = np.maximum(d, (ax + ay - hx - hy + chamfer) / 1.414)
    return d


def trunk(f):
    """From elder_torso, the same bare mass, recut in planes: a wedge from the
    waist to the shoulders on broad, low hips, the neck snapped."""
    d = block(f, 72, 102, (0, 3, 34, 34), (0, 2, 64, 43), 12)                  # the hips, low and broad
    d = np.minimum(d, block(f, 102, 132, (0, 2, 64, 43), (0, 0, 57, 38), 12))
    d = np.minimum(d, block(f, 130, 214, (0, 0, 57, 38), (0, 0, 84, 47), 15))  # the wedge of the back and ribs
    d = np.minimum(d, block(f, 209, 236, (0, 1, 112, 46), (0, 3, 50, 34), 28)) # the long slope, neck to shoulder
    d = np.minimum(d, block(f, 226, 264, (0, 3, 31, 28), (0, 3, 26, 24), 8))   # neck
    d = np.minimum(d, block(f, 126, 134, (0, 0, 59.5, 40.5), (0, 0, 59, 40), 12))  # a girdle at the waist
    for s in (-1, 1):
        d = np.minimum(d, block(f, 168, 216, (s * 34, -37, 30, 14), (s * 40, -39, 39, 13), 6))  # flat chest, a hard ledge under it
        d = np.minimum(d, block(f, 146, 212, (s * 52, 36, 22, 8), (s * 48, 38, 32, 10), 5))     # shoulder blade
        d = carve(d, f.bar((s * 66, -43, 124), (s * 6, -37, 74), 3.2), 0.6)    # the line of the leg, up to the hip
    d = carve(d, f.box((0, -55, 182), (2.2, 14, 34)), 0.5)                     # breastbone
    d = carve(d, f.box((0, 50, 160), (2.4, 12, 54)), 0.5)                      # spine
    d = smax(d, plane(f, (0.24, 0.1, 1), (0, 0, 245)), 0.4)                    # the snapped neck
    d = carve(d, f.bar((-2, 2, 266), (0, 3, 238), 9, 7), 1)                    # down the neck, a little way
    stove = np.maximum(np.maximum(plane(f, (0.5, 0.75, 0.4), (30, -38, 190)), plane(f, (-0.8, -0.3, 0.1), (-2, -50, 190))),
                       np.maximum(plane(f, (0.1, -0.2, -1), (0, 0, 160)), plane(f, (0.75, -0.2, 0.6), (58, -44, 206))))
    return carve(d, stove, 0.5)                                                # the elder's chest, stove in, a clean break


def arm(f, s):
    """Hung straight down its bones, cut through at no joint: a shoulder under
    the long slope, tapered to a wrist, and a small closed hand."""
    d = block(f, 178, 232, (s * 97, 2, 25, 27), (s * 96, 2, 28, 34), 13)       # shoulder
    d = smax(d, plane(f, (s * 0.47, 0, 1), (s * 96, 0, 219)), 0.5)             # the neck's slope carries on over it
    d = np.minimum(d, block(f, 152, 192, (s * 96, 1, 21, 23), (s * 96, 2, 24, 26), 9))    # upper arm
    d = np.minimum(d, block(f, 170, 180, (s * 96, 1.5, 25.5, 27.5), (s * 96, 1.5, 26, 28), 10))  # a band above the elbow
    d = np.minimum(d, block(f, 104, 154, (s * ARM_X, -2, 15, 17), (s * 96, 0, 21.5, 23.5), 8))   # forearm
    d = np.minimum(d, block(f, 107, 118, (s * ARM_X, -2, 18, 20), (s * ARM_X, -2, 18, 20), 7))   # a cuff
    hand = block(f, 58, 106, (s * ARM_X, -6, 12, 15), (s * ARM_X, -3, 15, 17.5), 7)       # a closed hand
    hand = smax(hand, plane(f, (0, -0.8, -1), (0, -14, 66)), 0.5)              # the knuckles' plane
    hand = np.minimum(hand, block(f, 74, 102, (s * (ARM_X - 12), -12, 4.5, 7), (s * (ARM_X - 11), -9, 6, 8), 2))  # thumb along it
    return np.minimum(d, hand)


def leg(f, s):
    """A great thigh down from the hip, narrowing to a hard knee, a calf, and a
    heavy foot."""
    d = block(f, 52, 92, (s * 43, -2, 22, 26), (s * 44, 0, 27, 43), 13)        # thigh, its widest under the hip
    d = np.minimum(d, block(f, 92, 120, (s * 44, 0, 27, 43), (s * 40, 1, 24, 40), 13))
    d = np.minimum(d, block(f, 40, 56, (s * 43, -6, 21, 23), (s * 43, -6, 23, 25), 8))  # knee
    d = np.minimum(d, block(f, 12, 46, (s * 44, 1, 18, 20), (s * 43, 2, 22, 26), 8))    # calf
    foot = block(f, 0, 22, (s * 44, -11, 24, 37), (s * 44, -11, 22, 35), 7)
    return np.minimum(d, smax(foot, plane(f, (0, -0.24, 1), (0, 10, 20)), 0.5))  # a heavy foot, falling to the toes


# Where the stone has come away: the elder's stove-in chest, a shoulder, a hip.
LOSSES = [((-112, 18, 222), 26, 7), ((-64, -38, 108), 15, 5),
          ((60, 44, 200), 18, 6), ((114, -18, 140), 13, 4), ((-58, -20, 22), 12, 4)]


def stomper(f):
    arms = [arm(f, s) for s in (-1, 1)]
    legs = [leg(f, s) for s in (-1, 1)]
    d = trunk(f)
    d = np.minimum(d, np.minimum(legs[0], legs[1]))
    for one in arms:
        joined = smin(d, one, 3.0)
        apart = np.minimum(d, one)
        high = np.clip((f.Z - 168) / 14, 0, 1)                                 # arms fuse at the shoulder, nowhere else
        d = apart + (joined - apart) * high
    return d


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
    args = ap.parse_args(argv)
    out = ROOT / args.out
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = stage()
    stone = material("stone", (0.20, 0.155, 0.115))
    f = Field(*BOUNDS, args.voxel, 7)
    full, soft = ruin.weather(f, stomper(f), stone=STONE_BODY, losses=LOSSES, breaks=2, cracks=5)
    body = place("stomper", full, f, (0, 0, 0), stone)
    co = np.empty(len(body.data.vertices) * 3)
    body.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    print("bounds", co.min(0).round(1), co.max(0).round(1))
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
    shot(scene, out, "heads", (250, -290, 24), (250, -50, 26), 50)


if __name__ == "__main__":
    main()
