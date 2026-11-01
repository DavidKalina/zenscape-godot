"""The stomper's body, rough stage: the ruins' field and weather on the walking
skeleton, and a still beside a 120 m head and a 55 m head (headless).

    python3 tools/blender.py run art/blender/giant_ruins/stomper_body_build.py \
        -- [--voxel 1.0] [--out scratch/stomper_body]

It grew from `elder_torso` (giant_head_build.py): the heads and torsos are carved
masses, so the walker is too, with the elder's sloped shoulders, snapped neck,
stove-in chest and collar of beads. Same axes as the ruins, so it looks down -Y; the skeleton looks down +Y, which skinning turns
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
BOUNDS = ((-138, -66, -2), (138, 66, 256))
HIP_X = 40.4
ARM_X = 94.0


def trunk(f):
    """elder_torso on the walker's skeleton: bare and heavy, the neck snapped."""
    d = f.ell((0, 0, 174), (78, 50, 58))                                       # the chest
    d = smin(d, f.ell((0, -3, 122), (56, 41, 44)), 12)                         # belly
    d = smin(d, f.ell((0, 2, 92), (60, 40, 27)), 10)                           # pelvis
    d = smin(d, f.bar((0, 1, 214), (0, 3, 266), 25, 19), 8)                    # neck
    for s in (-1, 1):
        d = smin(d, f.bar((s * 24, 3, 212), (s * 92, 2, 210), 17, 25), 12)     # the slope down to the shoulder
        d = smin(d, f.ell((s * 37, -41, 180), (39, 15, 26)), 6)                # chest
        d = smin(d, f.ell((s * 42, 40, 186), (36, 10, 30)), 16)                # shoulder blade
    for i in range(9):                                                         # the elder's collar of carved beads
        a = np.pi * (0.1 + 0.8 * i / 8)
        d = smin(d, f.ell((np.cos(a) * 54, -np.sin(a) * 52, 223 - np.sin(a) * 15), (9.5, 8.5, 9.5)), 0.6)
    belt = smax(f.ell((0, 0, 106), (67, 49, 200)), np.abs(f.Z - 106) - 7, 1.5)
    d = smin(d, belt, 1.2)                                                     # a plain belt, a band of stone
    d = smax(d, f.Z + f.X * 0.3 - 245, 1.5)                                    # the neck's snapped top
    d = carve(d, f.bar((-2, 2, 266), (0, 3, 228), 10, 8), 2)                   # down the neck, a little way
    d = carve(d, f.ell((24, -56, 172), (30, 19, 30)), 3)                       # stove in
    return carve(d, f.box((0, 54, 150), (2.4, 12, 46), 0.8), 2)                # the back's groove


def arm(f, s):
    """A heavy arm hung straight down its bones, cut through at no joint."""
    d = f.bar((s * 93, 2, 212), (s * 96, 0, 158), 27, 22)                      # upper arm
    d = smin(d, f.bar((s * 96, 0, 152), (s * ARM_X, -2, 108), 24, 19), 5)      # forearm
    band = f.bar((s * 95, 1, 186), (s * 95, 1, 170), 26.5, 25.5)
    d = smin(d, smax(band, np.abs(f.Z - 178) - 6, 1), 1)                       # a band above the elbow
    d = smin(d, smax(f.bar((s * ARM_X, -2, 124), (s * ARM_X, -2, 104), 23.5), np.abs(f.Z - 112) - 5, 1), 1)  # a cuff
    d = smin(d, f.box((s * ARM_X, -5, 80), (21, 23, 24), 10), 5)               # fist
    for i in (-1, 0, 1):
        d = carve(d, f.box((s * (ARM_X + i * 10.5), -28, 64), (1.0, 7, 11)), 0.8)  # its fingers, carved in
    return d


def leg(f, s):
    """A column with a calf, on a foot like a plinth."""
    d = f.bar((s * HIP_X, 0, 96), (s * HIP_X, 0, 54), 31, 24)                  # thigh
    d = smin(d, f.box((s * HIP_X, -12, 49), (16, 15, 11), 7), 4)               # knee
    d = smin(d, f.bar((s * HIP_X, 3, 46), (s * HIP_X, 0, 16), 24, 20), 5)      # calf
    d = smin(d, f.box((s * HIP_X, -13, 8), (29, 40, 11), 6), 7)                # foot
    return carve(d, f.box((s * HIP_X, -13, -40), (60, 60, 40)), 0.5)


def stomper(f):
    arms = [arm(f, s) for s in (-1, 1)]
    legs = [leg(f, s) for s in (-1, 1)]
    d = trunk(f)
    d = np.minimum(d, np.minimum(legs[0], legs[1]))
    for one in arms:
        joined = smin(d, one, 10.0)
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
    full, soft = ruin.weather(f, stomper(f))
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
    f, d = scaled(ruin.warden, ruin.BOUNDS["warden"], args.voxel, 13, SIZE_55)
    place("head_55", ruin.weather(f, d)[0], f, (215, -90, 0), stone, -14)
    f, d = scaled(ruin.mourner, ruin.BOUNDS["mourner"], args.voxel, 17, SIZE_55)
    place("head_55b", ruin.weather(f, d)[0], f, (300, -10, 0), stone, -30)
    marker((90, -220, 60))
    shot(scene, out, "front", (0, -1150, 70), (0, 0, 118), 50)
    shot(scene, out, "three_quarter", (620, -940, 150), (40, 0, 112), 50)
    shot(scene, out, "close", (240, -420, 40), (20, 0, 150), 42)
    shot(scene, out, "back", (-420, 900, 90), (0, 0, 118), 50)


if __name__ == "__main__":
    main()
