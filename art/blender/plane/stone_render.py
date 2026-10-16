"""Renders of the stone plane concepts (stone_build.py).

    python tools/blender.py run --blend art/blender/plane/stone.blend art/blender/plane/stone_render.py -- [OUT_DIR] [A B C] [SHOT ...]

OUT_DIR defaults to art/blender/plane/renders/stone (PNGs are gitignored).
Shots (all by default):
  hero    <D>_hero.png     3/4 front, banking, beside the ruin island
  side    <D>_side.png     side profile, orthographic, level
  chase   <D>_chase.png    the game's chase camera at cruise, target ahead
                           and slightly left (the ruin)
  lineup  lineup.png       the three side by side
  best    for BEST only: <D>_chase_left/right/up/behind, _chase_empty,
          _chase_bright, _chase_dusk, _chase_raw (no glow ribbons),
          _chase_wisp (with the optional wisp), _needle, _needle_empty
          (close-ups of the heart chamber)

The chase camera is plane_render.py's (scripts/glide_camera.gd and
scripts/sky_plane.gd maths): at cruise (14 m/s) 5.2 m back, 1.4 m up,
looking 4.2 m ahead and 0.35 m up, vertical FOV about 73 degrees; the
figure hangs 0.2 m under the flight.

The compass (`compass`) is the design's rule, written to port as is.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(args[0]) if args and "/" in args[0] else HERE / "renders" / "stone"
WANT = set(a for a in args if "/" not in a)
OUT.mkdir(parents=True, exist_ok=True)
DIRS = [d for d in "ABC" if d in WANT] or list("ABC")
SHOTS = (WANT - set("ABC")) or {"hero", "side", "chase", "lineup", "best"}
BEST = "A"

C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CHANNELS = ("L", "R", "UP", "DN", "BK", "RING", "GAP")


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
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 64
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.view_settings.exposure = -0.3
scene.render.film_transparent = False

# The ruin: the game's own kit (ruin_export.gd).
RUIN_GLB = Path("/tmp/ruin_vignette_stone.glb")
if not RUIN_GLB.exists():
    RUIN_GLB = Path("/tmp/ruin_vignette.glb")
if RUIN_GLB.exists():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(RUIN_GLB))
    kit = bpy.data.materials.new("ruin_kit")
    kit.use_nodes = True
    kn = kit.node_tree
    attr = kn.nodes.new("ShaderNodeVertexColor")
    pbsdf = kn.nodes["Principled BSDF"]
    kn.links.new(attr.outputs["Color"], pbsdf.inputs["Base Color"])
    pbsdf.inputs["Roughness"].default_value = 0.9
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

# The sky: a gradient by height (plane_render.py's), with presets.
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
els.new(0.5)
els.new(0.47)
bg = nt.nodes.new("ShaderNodeBackground")
nt.links.new(ramp.outputs[0], bg.inputs[0])
wout = nt.nodes.new("ShaderNodeOutputWorld")
nt.links.new(bg.outputs[0], wout.inputs[0])
SKIES = {
    # (low cloud sea, horizon low, horizon, overhead), strength
    "day": (("e9e4dc", 0.38), ("e3e1dc", 0.47), ("c9d6df", 0.5), ("5f8fc4", 0.75), 1.0),
    # Round 1's worst case: a bright white overcast sky behind the plane.
    "bright": (("f6f5f2", 0.38), ("fbfaf7", 0.47), ("f4f4f2", 0.5), ("dfe6ec", 0.75), 1.25),
    "dusk": (("6d5a5e", 0.38), ("c98a6a", 0.47), ("d9a07a", 0.5), ("3d4f78", 0.75), 0.5),
}


def set_sky(name):
    *stops, strength = SKIES[name]
    for e, (col, pos) in zip(sorted(els, key=lambda e: e.position), stops):
        e.position = pos
        e.color = (*srgb(col), 1)
    bg.inputs["Strength"].default_value = strength


sun_data = bpy.data.lights.new("sun", "SUN")
sun_data.angle = math.radians(1.5)
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
    d = Vector((math.sin(azim) * math.cos(elev), math.sin(elev), -math.cos(azim) * math.cos(elev)))
    sun.rotation_euler = (-G(d)).to_track_quat("-Z", "Y").to_euler()
    sun_data.energy = energy
    sun_data.color = srgb(color)


def look(eye_game, at_game, fov=None, ortho=None, roll=0.0):
    eye, at = G(eye_game), G(at_game)
    cam.location = eye
    q = (at - eye).to_track_quat("-Z", "Y")
    if roll:
        q = q @ Quaternion((0, 0, 1), roll)
    cam.rotation_euler = q.to_euler()
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


def show(names):
    for coll in bpy.data.collections:
        coll.hide_render = coll.name not in names


# ------------------------------------------------------------- the compass
def compass(d):
    """The seam compass from the target's direction in the plane's frame
    (game axes: +X right, +Y up, -Z ahead; d need not be unit). Returns a
    level 0..1 per channel.

      bearing b (+ right) and elevation e of the target;
      L, R   both 0.3 on course; the side toward the target rises to 1 by
             30 degrees off while the other falls toward 0.05; behind
             (|b| > 90), the turn side is full, the other dark;
      UP/DN  0 to 1 over 0 to 30 degrees above or below;
      BK     0 at 90 degrees off, 1 at 135 and beyond (the tail lights);
      RING   0.35, flaring to 1 within 12 degrees of dead ahead;
      GAP    a steady 0.6 while a stone is seated.
    """
    b = math.atan2(d[0], -d[2])
    e = math.atan2(d[1], math.hypot(d[0], d[2]))
    ab = abs(b)
    base = 0.3
    if ab <= math.pi / 2:
        t = min(1.0, ab / math.radians(30))
        near, far = base + (1 - base) * t, base * (1 - t) + 0.05 * t
    else:
        near, far = 1.0, 0.0
    lvl = {"L": near if b < 0 else far, "R": near if b >= 0 else far}
    lvl["UP"] = max(0.0, min(1.0, e / math.radians(30)))
    lvl["DN"] = max(0.0, min(1.0, -e / math.radians(30)))
    lvl["BK"] = max(0.0, min(1.0, (ab - math.pi / 2) / math.radians(45)))
    on = max(0.0, 1 - math.hypot(b, e) / math.radians(12))
    lvl["RING"] = 0.35 + 0.65 * on
    lvl["GAP"] = 0.6
    return lvl


CORE_MAX = 9.0     # emission at level 1, on a level^2.5 curve so the two
CORE_FLOOR = 0.15  # sides part clearly; the floor keeps a seated stone's seams faintly gold
CURVE = 2.5
GAP_GLOW = 1.1     # the gaps' steady warm-white light
BAND_MAX = {"far": 2.6, "near": 0.12}


def apply(lvl, far, seated=True, speed=14.0):
    """Sets the seam cores and ribbons. `far`: the chase distance (ribbons
    at full, standing in for the game's distance-scaled glow)."""
    for ch in CHANNELS:
        l = lvl.get(ch, 0.0) if seated else 0.0
        core = bpy.data.materials[f"core_{ch}"].node_tree.nodes["core"]
        e = GAP_GLOW * (1.0 if far else 0.45) if ch == "GAP" else CORE_FLOOR + CORE_MAX * l ** CURVE
        core.inputs["Emission Strength"].default_value = e if seated else 0.0
        bm = bpy.data.materials.get(f"band_{ch}")
        if bm:
            k = 0.35 if ch == "GAP" else l ** CURVE
            bm.node_tree.nodes["glow_k"].inputs[1].default_value = BAND_MAX["far" if far else "near"] * k
    blur = bpy.data.materials["ring_blur"].node_tree.nodes["glow_k"].inputs[1]
    blur.default_value = (0.25 + 0.5 * min(1.0, speed / 22.0)) * (1.0 if far else 0.35) if seated else 0.0
    for name in ("halo", "wisp"):
        m = bpy.data.materials.get(name)
        if m:
            m.node_tree.nodes["glow_k"].inputs[1].default_value = (0.4 if name == "halo" else (2.0 if far else 0.4)) if seated else 0.0


def seat(D, seated):
    for ob in bpy.data.collections[f"Stone_{D}"].objects:
        if ob.name.startswith(("Heart_", "HeartHalo_", "HeartLight_", "NeedleMesh_")):
            ob.hide_render = not seated


def wisp(D, on):
    for ob in bpy.data.objects[f"Wisp_{D}"].children:
        ob.hide_render = not on


def aim_at(obj, target_game):
    """Turns an empty (child of the root, axes in the root's Blender frame)
    so its -Z game axis (Blender +Y) points at a world point."""
    bpy.context.view_layer.update()
    root = obj.parent
    while not root.name.startswith("Root_"):
        root = root.parent
    root_m = root.matrix_world
    at = obj.matrix_world.translation
    d = root_m.to_3x3().inverted() @ (G(target_game) - at)
    d.normalize()
    yaw = math.atan2(-d.x, d.y)
    pitch = math.atan2(d.z, math.hypot(d.x, d.y))
    obj.rotation_euler = (pitch, 0, yaw)


def point(D, target_game, far, seated=True, speed=14.0, ring_spin=0.4):
    """Aims the needle and wisp, sets the compass from the target."""
    bpy.context.view_layer.update()
    root = bpy.data.objects[f"Root_{D}"]
    ch = bpy.data.objects[f"Chamber_{D}"]
    d = root.matrix_world.to_3x3().inverted() @ (G(target_game) - ch.matrix_world.translation)
    lvl = compass((d.x, d.z, -d.y))
    apply(lvl, far, seated, speed)
    aim_at(bpy.data.objects[f"Needle_{D}"], target_game)
    aim_at(bpy.data.objects[f"Wisp_{D}"], target_game)
    bpy.data.objects[f"Ring_{D}"].rotation_euler = (0, ring_spin, 0)
    seat(D, seated)
    print("COMPASS", D, {k: round(v, 2) for k, v in lvl.items()})
    return lvl


def render(name, w=1920, h=1080):
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.filepath = str(OUT / f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)


def chase_cam(speed=14.0):
    tuck = max(0.0, min(1.0, (speed - 16.0) / 14.0)) * 0.7
    back = 5.2 + (1.7 - 5.2) * tuck
    up = 1.4 + (0.45 - 1.4) * tuck
    t = max(0.0, min(1.0, (speed - 8.0) / 32.0))
    fov = 70 + 10 * (1 - (1 - t) ** 2)
    return back, up, 2.5 + 0.12 * speed, fov


def chase(D, name, target, bank=12.0, ruin=None, sky="day", sun=(38, -150, 4.0, "fff1dc"),
          seated=True, wisp_on=False, bands=True):
    set_sky(sky)
    show({f"Stone_{D}", "Ruin"} if ruin else {f"Stone_{D}"})
    if ruin:
        place("Root_Ruin", *ruin[:3], heading=ruin[3])
    b = math.radians(bank)
    place(f"Root_{D}", 0, -0.2, 0, roll=b)
    set_sun(math.radians(sun[0]), math.radians(sun[1]), sun[2], sun[3])
    wisp(D, wisp_on)
    point(D, target, far=True, seated=seated)
    if not bands:
        for ch in CHANNELS:
            m = bpy.data.materials.get(f"band_{ch}")
            if m:
                m.node_tree.nodes["glow_k"].inputs[1].default_value = 0.0
        bpy.data.materials["ring_blur"].node_tree.nodes["glow_k"].inputs[1].default_value = 0.0
    back, up, ahead, fov = chase_cam()
    look((0, up, back), (0, 0.35, -ahead), fov=fov, roll=-0.4 * b)
    render(name)


AHEAD_LEFT = (-12.0, -7.0, -46.0)   # the ruin's gable: ahead, slightly left and below
RUIN_AHEAD = (-14, -16, -44, 0.6)

for D in DIRS:
    for ob in bpy.data.objects:
        if ob.name.startswith("Wisp_"):
            wisp(ob.name.split("_")[1], False)
    if "hero" in SHOTS:
        set_sky("day")
        show({f"Stone_{D}", "Ruin"})
        place(f"Root_{D}", 0, 0, 0, heading=0.25, pitch=0.06, roll=0.3)
        place("Root_Ruin", 24, -14, 46, heading=2.6)
        set_sun(math.radians(40), math.radians(-120))
        point(D, (-12, 8, -20), far=False)
        look((-2.6, 0.95, -3.0), (0.05, 0.05, 0.0), fov=30)
        render(f"{D}_hero")
    if "side" in SHOTS:
        set_sky("day")
        show({f"Stone_{D}"})
        place(f"Root_{D}", 0, 0, 0)
        set_sun(math.radians(45), math.radians(60))
        point(D, (0, 3, -10), far=False, speed=0)
        look((6, 0.05, 0.0), (0, 0.05, 0.0), ortho=1.75)
        render(f"{D}_side", 1600, 1000)
    if "chase" in SHOTS:
        chase(D, f"{D}_chase", AHEAD_LEFT, ruin=RUIN_AHEAD)

if "lineup" in SHOTS:
    set_sky("day")
    show({"Stone_A", "Stone_B", "Stone_C"})
    for i, D in enumerate("ABC"):
        place(f"Root_{D}", (i - 1) * 1.8, 0, 0)
    set_sun(math.radians(40), math.radians(-120))
    for D in "ABC":
        point(D, (-6, 5, -12), far=False)
    look((-2.8, 1.35, -3.6), (0.0, 0.05, 0.0), fov=38)
    render("lineup", 2400, 1000)
    for D in "ABC":
        place(f"Root_{D}", 0, 0, 0)

if "best" in SHOTS:
    D = BEST
    # The four directions (no ruin in view: the target is off screen).
    chase(D, f"{D}_chase_left", (-40, -2, -25), bank=-8)
    chase(D, f"{D}_chase_right", (40, -2, -25), bank=8)
    chase(D, f"{D}_chase_up", (-2, 30, -40), bank=0)
    chase(D, f"{D}_chase_behind", (-12, 0, 45), bank=-6)
    chase(D, f"{D}_chase_empty", AHEAD_LEFT, ruin=RUIN_AHEAD, seated=False)
    chase(D, f"{D}_chase_bright", AHEAD_LEFT, ruin=RUIN_AHEAD, sky="bright", sun=(55, -160, 5.0, "ffffff"))
    chase(D, f"{D}_chase_dusk", (10, -4, -30), bank=-10, ruin=(10, -9, -30, -0.5), sky="dusk", sun=(7, -60, 2.2, "ffb98a"))
    chase(D, f"{D}_chase_raw", AHEAD_LEFT, ruin=RUIN_AHEAD, bands=False)
    chase(D, f"{D}_chase_wisp", AHEAD_LEFT, ruin=RUIN_AHEAD, wisp_on=True)
    # Close-ups of the heart chamber: the needle hovering over the stone.
    set_sky("day")
    show({f"Stone_{D}"})
    wisp(D, False)
    place(f"Root_{D}", 0, 0, 0)
    set_sun(math.radians(42), math.radians(-135))
    ch = bpy.data.objects[f"Chamber_{D}"]
    bpy.context.view_layer.update()
    c = ch.matrix_world.translation
    cg = (c.x, c.z, -c.y)
    # The target off to the right and up, so the needle shows its length.
    point(D, (8, 3, -4), far=False, speed=0)
    look((cg[0] - 0.2, cg[1] + 0.42, cg[2] - 0.3), (cg[0], cg[1] + 0.06, cg[2] + 0.01), fov=30)
    render(f"{D}_needle", 1400, 1100)
    point(D, (8, 3, -4), far=False, seated=False, speed=0)
    render(f"{D}_needle_empty", 1400, 1100)
