"""Renders of the plane concepts (plane_build.py) for choosing between them.

    python tools/blender.py run --blend art/blender/plane/plane.blend art/blender/plane/plane_render.py -- [OUT_DIR] [SHOT ...]

Writes OUT_DIR (default art/blender/plane/renders) PNGs:
  <D>_hero.png    3/4 front, banking, the stone seated and glowing, a ruin
                  island beyond
  <D>_side.png    side profile, orthographic, level
  <D>_chase.png   the game's chase camera (scripts/glide_camera.gd: 5.2 m
                  back, 1.4 m over the flight, looking 2.5 m + 0.12 s of
                  speed ahead, 0.35 up; the figure hangs 0.2 m under the
                  flight; vertical FOV 70 widening with speed), at 22 m/s
                  in a gentle bank, flying at a ruin the stone points to
  lineup.png      the three side by side
  <D>_cradle_empty.png, <D>_cradle_seated.png  close-ups of the cradle
  <D>_chase_dusk.png, <D>_chase_empty.png  for the recommended direction
SHOT names limit it: hero, side, chase, lineup, cradle, extra; and A, B, C
limit the directions. The recommended direction for the extras is BEST.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(args[0]) if args and not args[0].isalpha() else HERE / "renders"
WANT = set(a for a in args if a.isalpha())
OUT.mkdir(parents=True, exist_ok=True)
DIRS = [d for d in "ABC" if d in WANT] or list("ABC")
SHOTS = (WANT - set("ABC")) or {"hero", "side", "chase", "lineup", "cradle", "extra"}
BEST = "A"

C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CRADLE = Vector((0.0, 0.455, -0.07))


def G(p):
    return Vector((p[0], -p[2], p[1]))


def T(x=0.0, y=0.0, z=0.0, rx=0.0, ry=0.0, rz=0.0):
    return (Matrix.Translation((x, y, z)) @ Matrix.Rotation(ry, 4, "Y")
            @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(rz, 4, "Z"))


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


scene = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        continue
scene.eevee.taa_render_samples = 64
try:
    scene.eevee.use_shadows = True
    scene.eevee.use_raytracing = False
except AttributeError:
    pass
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.view_settings.exposure = -0.3

# The ruin: the game's own kit (ruin_export.gd), on the island
# plane_build.py made. Its colours are in the vertex colours.
RUIN_GLB = Path("/tmp/ruin_vignette.glb")
if RUIN_GLB.exists():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(RUIN_GLB))
    kit = bpy.data.materials.new("ruin_kit")
    kit.use_nodes = True
    kn = kit.node_tree
    attr = kn.nodes.new("ShaderNodeVertexColor")
    pb = kn.nodes["Principled BSDF"]
    kn.links.new(attr.outputs["Color"], pb.inputs["Base Color"])
    pb.inputs["Roughness"].default_value = 0.9
    ruin_root = bpy.data.objects["Root_Ruin"]
    for ob in set(bpy.data.objects) - before:
        for c in ob.users_collection:
            c.objects.unlink(ob)
        bpy.data.collections["Ruin"].objects.link(ob)
        if ob.parent is None:
            ob.parent = ruin_root
        if ob.type == "MESH":
            ob.data.materials.clear()
            ob.data.materials.append(kit)
else:
    print("NO RUIN GLB: run ruin_export.gd first")
scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
scene.render.film_transparent = False

# The sky: a gradient by the view's height, pale at the horizon, blue
# overhead, a soft cloud-sea white below.
world = bpy.data.worlds.new("sky")
scene.world = world
world.use_nodes = True
nt = world.node_tree
nt.nodes.clear()
tc = nt.nodes.new("ShaderNodeTexCoord")
sep = nt.nodes.new("ShaderNodeSeparateXYZ")
nt.links.new(tc.outputs["Generated"], sep.inputs[0])
ramp = nt.nodes.new("ShaderNodeValToRGB")
half = nt.nodes.new("ShaderNodeMath")
half.operation = "MULTIPLY_ADD"
half.inputs[1].default_value = 0.5
half.inputs[2].default_value = 0.5
nt.links.new(sep.outputs["Z"], half.inputs[0])
nt.links.new(half.outputs[0], ramp.inputs[0])
els = ramp.color_ramp.elements
els[0].position, els[0].color = 0.38, (*srgb("e9e4dc"), 1)
els[1].position, els[1].color = 0.75, (*srgb("5f8fc4"), 1)
e = els.new(0.5)
e.color = (*srgb("c9d6df"), 1)
e = els.new(0.47)
e.color = (*srgb("e3e1dc"), 1)
bg = nt.nodes.new("ShaderNodeBackground")
bg.inputs["Strength"].default_value = 1.0
nt.links.new(ramp.outputs[0], bg.inputs[0])
out = nt.nodes.new("ShaderNodeOutputWorld")
nt.links.new(bg.outputs[0], out.inputs[0])

sun_data = bpy.data.lights.new("sun", "SUN")
sun_data.energy = 4.0
sun_data.angle = math.radians(1.5)
sun_data.color = srgb("fff1dc")
sun = bpy.data.objects.new("sun", sun_data)
scene.collection.objects.link(sun)

cam_data = bpy.data.cameras.new("cam")
cam_data.sensor_fit = "VERTICAL"
cam_data.clip_start = 0.02
cam_data.clip_end = 500
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def set_sun(elev, azim, energy=4.0, color="fff1dc"):
    """Sun from game-frame direction: elevation, azimuth (0 = from -Z, the
    nose's way, going round toward +X)."""
    d = Vector((math.sin(azim) * math.cos(elev), math.sin(elev), -math.cos(azim) * math.cos(elev)))
    to = -G(d)
    sun.rotation_euler = to.to_track_quat("-Z", "Y").to_euler()
    sun_data.energy = energy
    sun_data.color = srgb(color)


def look(eye_game, at_game, fov=None, ortho=None, roll=0.0):
    eye, at = G(eye_game), G(at_game)
    cam.location = eye
    q = (at - eye).to_track_quat("-Z", "Y")
    cam.rotation_euler = q.to_euler()
    if roll:
        cam.rotation_euler = (q @ __import__("mathutils").Quaternion((0, 0, 1), roll)).to_euler()
    if ortho:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho
    else:
        cam_data.type = "PERSP"
        cam_data.sensor_height = 24
        cam_data.lens = 12 / math.tan(math.radians(fov) / 2)


def place(name, x=0, y=0, z=0, heading=0.0, pitch=0.0, roll=0.0):
    """Places a root in the game's frame, posed as PlaneFigure.pose does."""
    ob = bpy.data.objects[name]
    ob.matrix_world = C @ T(x, y, z, rx=pitch, ry=heading, rz=-roll) @ C.inverted()
    return ob


def show(names, stone=True):
    for coll in bpy.data.collections:
        coll.hide_render = coll.name not in names
    for D in "ABC":
        for ob in [bpy.data.objects[f"Stone_{D}"]] + list(bpy.data.objects[f"Stone_{D}"].children_recursive):
            ob.hide_render = not stone


def aim(D, target_game):
    """Turns the hoop and tips the stone toward a point in the game frame."""
    bpy.context.view_layer.update()
    root = bpy.data.objects[f"Root_{D}"]
    at = root.matrix_world @ G(CRADLE)
    d = root.matrix_world.to_3x3().inverted() @ (G(target_game) - at)
    d.normalize()
    yaw = math.atan2(-d.x, d.y)
    pitch = math.atan2(d.z, math.hypot(d.x, d.y))
    bpy.data.objects[f"Hoop_{D}"].rotation_euler = (0, 0, yaw)
    bpy.data.objects[f"Stone_{D}"].rotation_euler = (pitch, 0, 0)


def glow(far):
    """The glow's strength by the camera's distance: gentle up close, bold
    from the chase camera (in the game, scaled by distance to the eye), so
    it never blows out the stone near and still reads 5 m back."""
    halo, wisp, widen = (0.55, 2.2, 3.6) if far else (0.1, 0.3, 1.0)
    bpy.data.materials["halo"].node_tree.nodes["glow_k"].inputs[1].default_value = halo
    bpy.data.materials["wisp"].node_tree.nodes["glow_k"].inputs[1].default_value = wisp
    for D in "ABC":
        for ob in bpy.data.objects[f"Glow_{D}"].children:
            if ob.name.startswith("Wisp"):
                ob.scale = (widen, 1.0, widen)
            elif ob.name.startswith("Halo"):
                ob.scale = (1.0 + (widen - 1) * 0.5,) * 3
        bpy.data.lights[f"StoneLight_{D}"].energy = 3.0 if far else 1.0


def render(name, w=1920, h=1080):
    glow("chase" in name)
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.filepath = str(OUT / f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)


def hide_ruin():
    place("Root_Ruin", 0, -500, 0)


# The chase camera at the plane's cruise (scripts/sky_plane.gd CRUISE_SPEED
# 14 m/s: glide_camera.gd's tuck is 0 below 16 m/s) and at full boost
# (22 m/s: tuck 0.3, so it pulls in to 4.15 m back, 1.12 up).
SPEED = 14.0


def chase(speed):
    tuck = max(0.0, min(1.0, (speed - 16.0) / 14.0)) * 0.7
    back = 5.2 + (1.7 - 5.2) * tuck
    up = 1.4 + (0.45 - 1.4) * tuck
    t = max(0.0, min(1.0, (speed - 8.0) / 32.0))
    fov = 70 + 10 * (1 - (1 - t) ** 2)
    return back, up, 2.5 + 0.12 * speed, fov
for D in DIRS:
    if "hero" in SHOTS:
        show({f"Plane_{D}", "Ruin"})
        place(f"Root_{D}", 0, 0, 0, heading=0.25, pitch=0.06, roll=0.3)
        place("Root_Ruin", 24, -14, 46, heading=2.6)
        aim(D, (-12, 8, -20))
        set_sun(math.radians(40), math.radians(-120))
        look((-2.1, 0.75, -2.5), (0.05, 0.1, 0.0), fov=30)
        render(f"{D}_hero")
    if "side" in SHOTS:
        show({f"Plane_{D}"})
        place(f"Root_{D}", 0, 0, 0)
        aim(D, (0, 3, -10))
        set_sun(math.radians(45), math.radians(60))
        look((6, 0.05, 0.0), (0, 0.05, 0.0), ortho=1.75)
        render(f"{D}_side", 1600, 1000)
    if "chase" in SHOTS:
        show({f"Plane_{D}", "Ruin"})
        bank = math.radians(12)
        place(f"Root_{D}", 0, -0.2, 0, heading=0.0, pitch=0.0, roll=bank)
        place("Root_Ruin", -16, -17, -44, heading=0.6)
        aim(D, (-16, -11.5, -44))
        set_sun(math.radians(38), math.radians(-150))
        back, up, ahead, fov = chase(SPEED)
        look((0, up, back), (0, 0.35, -ahead), fov=fov, roll=-0.4 * bank)
        render(f"{D}_chase")
if "lineup" in SHOTS:
    show({"Plane_A", "Plane_B", "Plane_C"})
    for i, D in enumerate("ABC"):
        place(f"Root_{D}", (i - 1) * 1.8, 0, 0, heading=0.0)
        aim(D, (-6, 5, -12))
    set_sun(math.radians(40), math.radians(-120))
    look((-2.8, 1.35, -3.6), (0.0, 0.05, 0.0), fov=38)
    render("lineup", 2400, 1000)
    for i, D in enumerate("ABC"):
        place(f"Root_{D}", 0, 0, 0)
for D in DIRS:
    if "cradle" in SHOTS and D == BEST or "cradleall" in SHOTS:
        place(f"Root_{D}", 0, 0, 0)
        set_sun(math.radians(40), math.radians(-140))
        show({f"Plane_{D}"}, stone=False)
        bpy.data.objects[f"Hoop_{D}"].rotation_euler = (0, 0, 0)
        look((-0.32, 0.72, 0.62), (0.0, 0.43, -0.07), fov=28)
        render(f"{D}_cradle_empty", 1400, 1100)
        show({f"Plane_{D}"}, stone=True)
        aim(D, (-4, 4, -8))
        render(f"{D}_cradle_seated", 1400, 1100)
    if "extra" in SHOTS and D == BEST:
        # Dusk, and the empty socket, from the chase camera.
        bank = math.radians(-10)
        show({f"Plane_{D}", "Ruin"})
        place(f"Root_{D}", 0, -0.2, 0, roll=bank)
        place("Root_Ruin", 10, -6, -30, heading=-0.5)
        aim(D, (10, 1.5, -30))
        set_sun(math.radians(7), math.radians(-60), 2.2, "ffb98a")
        world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45
        back, up, ahead, fov = chase(SPEED)
        look((0, up, back), (0, 0.35, -ahead), fov=fov, roll=-0.4 * bank)
        render(f"{D}_chase_dusk")
        world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
        set_sun(math.radians(38), math.radians(-150))
        show({f"Plane_{D}", "Ruin"}, stone=False)
        render(f"{D}_chase_empty")
        # Full boost: the camera pulls in.
        show({f"Plane_{D}", "Ruin"})
        place(f"Root_{D}", 0, -0.2, 0, roll=math.radians(15))
        place("Root_Ruin", -16, -17, -44, heading=0.6)
        aim(D, (-16, -11.5, -44))
        back, up, ahead, fov = chase(22.0)
        look((0, up, back), (0, 0.35, -ahead), fov=fov, roll=-0.4 * math.radians(15))
        render(f"{D}_chase_boost")
