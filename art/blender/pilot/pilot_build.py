"""Build the pilot on foot: one of the sky folk, rigged and animated, for the
third-person walker (scripts/pilot_figure.gd).

The wanderer of the character sheet (docs/design/wanderer-look/round1.md),
drawn soft, rounded and smooth shaded for the painterly paint: a big round
dark head with no face to see (the glowing eyes are painted on it by
shaders/pilot_paint.gdshader) under a wide terracotta felt hat, its brim
drooping softly with a rolled edge; chunky navy scarf rolls; a stocky
charcoal-brown jacket with soft folds, a strap across it, a belt and a
satchel; gold bracelets with a glowing stripe; big round mitts; denim
trousers into chunky boots with fleece cuffs; a torn charcoal cape from the
shoulders. Inside the old helmeted pilot's envelope (as tall, as wide).
About 84k triangles. Each part rides one bone (weight 1), so nothing
stretches, but the cape, skinned across its bones so it bends as cloth.

The clips, each a seamless loop, in place (the game moves the body), walk and
run starting on the left boot's touchdown so the game can blend them in step:
  idle  IDLE_LENGTH s of standing about, never twice the same in a loop: the
        weight going onto one boot and settling, glances left and right
        (the head leading, the chest following), a look up at the sky, the
        free boot shuffled out and later back, a rock back on the heels, a
        sigh, breaths at an uneven pace, holds of different lengths between;
        the game may start it anywhere;
  walk  a happy amble (Mario's walk), for a light touch on the stick, made
        for WALK_SPEED m/s: short quick steps, bouncing up off each, the arms
        hanging at the sides and swinging a little, loose at the elbow;
  run   the pace he goes by default, made for RUN_SPEED m/s (the motor's
        RUN): fairly upright, leaning in a little, knees up and heels kicked
        back, a moment in the air every step, the head steady, the arms
        held out wide and bent sharp, pumping out at the sides against the
        legs (Mario's in Odyssey), the scarf streaming;
  skid  SKID_LENGTH s, braking hard out of a run (the game slides the body
        and turns it round after): a held pose juddering, facing the way it
        ran, dropped low and leaning back, the left boot braced in front on
        its heel, the arms flung back and out, the scarf tails thrown up;
  hang  HANG_LENGTH s hanging from a lip by both mitts (reached to it by
        IK), the cap peeking over, swaying under the hands, legs dangling;
  shimmy_left, shimmy_right  hand over hand along the lip, made for
        SHIMMY_SPEED m/s, a gripping mitt fixed to the lip as the walk's
        boots are to the ground;
  climb CLIMB_LENGTH s, once (not a loop): from the hang's first frame up
        over the lip (pull, press, a knee over, stand) to the idle's first
        frame stood CLIMB_IN in on the top; the body moves in the clip.
        Played back, it lowers him from the top into the hang.
  crouch, long_jump, wall_slide, wall_kick, pump  the moves beyond running
        and jumping (see "the moves" below);
  jump_rise, jump_fall, twirl, slide, side_flip  the air and the tricks
        (see "round three" below).
Walking and running, each planted boot stays fixed to the ground (touchdown,
flat, rolling over the ball), so played at the right pace nothing slides;
standing, a boot only moves lifted.

Every channel is a periodic smooth curve of the clip's phase (whole
harmonics, or periodic monotone splines through keyed poses), so a loop has
no seam and no corner. Legs are posed by two-bone IK to the boots; the rest
by FK. Poses are computed here and keyed on every frame, then exported.

Regenerates art/blender/pilot/pilot.blend and assets/models/pilot.glb (or,
given a directory after `--`, writes them there), printing PILOT_TRIS and
each clip's length and the legs' worst reach; pilot_preview.py renders
stills of it:

    /opt/homebrew/bin/blender -b --python art/blender/pilot/pilot_build.py [-- DIR]

Conventions: 1 unit = 1 m, real size (about 1.1 m tall). Blender Z up, facing
+Y (the glTF exporter turns that into Godot's -Z), the right hand at +X; the
origin on the ground between the feet. The parts are written in the game's
frame and build units, as person_kit.gd has them (Y up, facing -Z), and
turned into Blender's here (`G`). Every bone's local X is the figure's
right in rest, so a positive turn about X swings a hanging limb forward and
tips an upright one back.

Contract with the game (scripts/pilot_figure.gd), which keeps copies of the
numbers:
| Name                   | What                                              |
|------------------------|---------------------------------------------------|
| Pilot                  | the skinned mesh; surfaces named after PilotPaint.SURFACES keys (scripts/pilot_paint.gd) |
| idle, walk, run, skid  | the clips, loops; walk and run start on the left touchdown |
| WALK_SPEED, WALK_CYCLE | the walk's ground speed (m/s) and its loop (s)    |
| RUN_SPEED, RUN_CYCLE   | the run's                                         |
| IDLE_LENGTH            | the idle's loop (s), not kept by the game         |
| SKID_LENGTH, SKID_DROP | the skid's loop (s) and its hips' drop (m), not kept by the game |
| HIPS                   | the pelvis over the ground (m), standing          |
| hang, shimmy_left, shimmy_right, climb | the ledge's clips; the climb doesn't loop |
| HANG_DROP, HANG_OUT    | the lip over the feet and ahead of them, hanging (m) |
| CLIMB_LENGTH, CLIMB_IN | the climb (s) and where it stands him in from the edge (m) |
| SHIMMY_SPEED, SHIMMY_CYCLE, HANG_LENGTH | the shimmy's pace (m/s) and loop (s); the hang's loop |
| crouch, long_jump, wall_slide, wall_kick, pump | the moves' clips (see "the moves"); wall_kick and pump don't loop |
| CROUCH_LENGTH, LONG_LENGTH, WALL_LENGTH, KICK_LENGTH, PUMP_LENGTH | their lengths (s) |
| jump_rise, jump_fall, twirl, slide, side_flip | the air's and the tricks' clips; side_flip doesn't loop |
| JUMP_LENGTH, TWIRL_LENGTH, SLIDE_LENGTH, FLIP_LENGTH | their lengths (s) |
| WALL_GAP               | the wall ahead of the feet, sliding down it (m)   |
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BLEND = HERE / "pilot.blend"
GLB = ROOT / "assets/models/pilot.glb"
# `-- DIR` writes both into DIR instead, for trying things out.
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if _args:
    BLEND, GLB = Path(_args[0]) / "pilot.blend", Path(_args[0]) / "pilot.glb"
FPS = 60

# ------------------------------------------------------------------ the clips
WALK_SPEED = 1.4       # m/s
WALK_CYCLE = 0.5       # seconds a full cycle, both feet
WALK_STANCE = 0.58     # the share of the cycle a boot is planted
RUN_SPEED = 4.8        # m/s, scripts/pilot_motor.gd RUN
RUN_CYCLE = 0.3
RUN_STANCE = 0.28
IDLE_LENGTH = 18.0
SKID_LENGTH = 0.35
SKID_DROP = 0.055      # m the hips drop skidding
# The ledge (scripts/pilot_motor.gd keeps copies): hanging, the lip's edge
# stands HANG_OUT ahead of the feet (the origin) and HANG_DROP over them; the
# climb ends standing CLIMB_IN in from the edge, on the lip's height.
HANG_DROP = 0.825
HANG_OUT = 0.22
HANG_LENGTH = 4.0
SHIMMY_SPEED = 0.7     # m/s along the lip
SHIMMY_CYCLE = 0.5     # seconds a full cycle, both hands
SHIMMY_STANCE = 0.57   # the share of the cycle a hand grips
CLIMB_LENGTH = 0.4     # Mario quick: was 0.9
CLIMB_IN = 0.3
# Where the mitts grip: the wrists this far in over the edge and up off the
# top, this far either side of the middle.
GRIP_IN = 0.03
GRIP_UP = 0.035
GRIP_X = 0.17

# ------------------------------------------------------------------ the body
# Build units (person_kit.gd, islander_figure.gd) and the pilot's scale of
# them (the islanders stand at 1.9).
SCALE = 2.2
# The wanderer's sheet (docs/design/wanderer-look/round1.md): a big round
# head under a wide hat on a short, stocky body, big round mitts and chunky
# boots; inside the old figure's envelope (the hat's top where the old
# helmet's was, about as wide). The legs (and so the hips, the gait and the
# ledge's and the water's measures) are the old ones: the sheet's legs are
# a third of him, as these are; the torso NECK is shorter by what the
# bigger head and the hat took, the arms longer by what the shoulders
# dropped, so the mitts still hang at the hips and reach a lip.
HIPS_BUILD = 0.1945    # the hips, standing near straight legged (walking and running lower)
NECK = 0.106
SHOULDER = (0.08, NECK - 0.022, 0.0)
HIP_X = 0.058
LEG = (0.095, 0.091)
# Arms hanging near straight, the mitts about at the hips.
ARM = (0.068, 0.062)
# The arms hang out from the shoulders this much (x over down, a lateral
# raise of 11 degrees), clear of the belly.
ARM_OUT = 0.2
ANKLE_BUILD = 0.024
# In rest the legs hang straight, so the hips stand higher than they ever
# do in play.
REST_HIPS = LEG[0] + LEG[1] + ANKLE_BUILD
TORSO_UP = 0.025
HEAD_UP = 0.027
HEAD_SIZE = 1.15

def G(x, y, z):
    """A point in the game's frame, build units, as Blender metres."""
    return Vector((x, -z, y)) * SCALE

# The same numbers in Blender metres, for posing.
THIGH = LEG[0] * SCALE
SHIN = LEG[1] * SCALE
UPPER = ARM[0] * SCALE
FORE = ARM[1] * SCALE
ANKLE = ANKLE_BUILD * SCALE
HIPS = HIPS_BUILD * SCALE + 0.005
# The boot's sole: the heel behind the ankle and the ball before it, where
# it rocks.
HEEL = -0.056
BALL = 0.076

# ------------------------------------------------------------------ colours
# The pilot's own palette, not the islanders': the game paints each surface
# by its material's name (scripts/pilot_paint.gd, shaders/pilot_paint.gdshader,
# which keep these colours); here they are matte, for Blender's stills.
PALETTE = {
    "pilot_face": "3b2a22", "pilot_hat": "c9644a", "pilot_hat_band": "4a2f24", "pilot_scarf": "2e4fa3",
    "pilot_jacket": "4a403c", "pilot_strap": "5a3a2c", "pilot_gold": "d9a441", "pilot_glow": "5fe6e6",
    "pilot_mitt": "7a4e38", "pilot_trousers": "2c3b62", "pilot_boots": "7a4a32", "pilot_fleece": "d9bc9c",
    "pilot_cape": "4a4848",
}

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

# ================================================================== scene
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.render.fps = FPS

materials = {}
for key, h in PALETTE.items():
    m = bpy.data.materials.new(key)
    rgb = [srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    m.diffuse_color = (*rgb, 1.0)
    m.roughness = 1.0
    m.metallic = 0.0
    m.specular_intensity = 0.0
    bsdf = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = 1.0
        bsdf.inputs["Metallic"].default_value = 0.0
    m.use_backface_culling = True
    materials[key] = m

# ================================================================== skeleton
L, R = -1.0, 1.0
SIDES = {"L": L, "R": R}

def torso_at(x, y, z):
    """A point in the torso's frame (build units, rest) in the game's."""
    return Vector((x, y + REST_HIPS + TORSO_UP, z))

def arm_joints(s):
    sh = torso_at(SHOULDER[0] * s, SHOULDER[1], SHOULDER[2])
    d = Vector((ARM_OUT * s, -1.0, 0.0)).normalized()
    el = sh + d * ARM[0]
    return sh, el, el + d * ARM[1]

def leg_joints(s):
    hp = Vector((HIP_X * s, REST_HIPS, 0.0))
    kn = hp - Vector((0, LEG[0], 0))
    return hp, kn, kn - Vector((0, LEG[1], 0))

NECK_AT = torso_at(0, NECK, 0)
HEAD_AT = NECK_AT + Vector((0, HEAD_UP, 0))

def g(v):
    return G(*v)

# The cape (build units, the torso's frame, rest): from under the scarf at
# the shoulders, CAPE_LENGTH down to its torn hem, wrapped round the back
# (`u` -1 the left edge to 1 the right, `v` 0 the top to 1 the hem) and
# flaring out from the back as it falls. Its bones (tail.L.*, tail.R.*: the
# old scarf tails' names, so the clips keep their channels) run down the
# middle of each half.
CAPE_TOP = NECK - 0.014
CAPE_LENGTH = 0.215
CAPE_SEGMENTS = 3
CAPE_THICK = 0.0045

def cape_point(u, v):
    """A point on the cape, in the torso's frame."""
    wx = 0.088 + 0.03 * v
    wz = 0.06 + 0.05 * v ** 0.8
    th = u * math.radians(84.0 - 16.0 * v)
    return (wx * math.sin(th), CAPE_TOP - CAPE_LENGTH * v, wz * math.cos(th))

def cape_tear(u):
    """How far up (in `v`) the hem is torn at `u`: jagged points, uneven."""
    teeth = 4.6
    k = math.floor((u + 1.0) * teeth)
    f = (u + 1.0) * teeth - k
    depth = 0.15 * (0.65 + 0.35 * math.sin(k * 2.3 + 0.7))
    return depth * (1.0 - abs(2.0 * f - 1.0))

BONES = {
    "root": (Vector((0, 0, 0)), Vector((0, 0.25, 0)), None),
    "hips": (G(0, REST_HIPS, 0), G(0, REST_HIPS + TORSO_UP, 0), "root"),
    "chest": (G(0, REST_HIPS + TORSO_UP, 0), g(NECK_AT), "hips"),
    "neck": (g(NECK_AT), g(HEAD_AT), "chest"),
    "head": (g(HEAD_AT), g(HEAD_AT + Vector((0, 0.17, 0))), "neck"),
}
for n, s in SIDES.items():
    sh, el, wr = arm_joints(s)
    BONES[f"upper_arm.{n}"] = (g(sh), g(el), "chest")
    BONES[f"forearm.{n}"] = (g(el), g(wr), f"upper_arm.{n}")
    BONES[f"hand.{n}"] = (g(wr), g(wr + (wr - el).normalized() * 0.03), f"forearm.{n}")
    hp, kn, an = leg_joints(s)
    BONES[f"thigh.{n}"] = (g(hp), g(kn), "hips")
    BONES[f"shin.{n}"] = (g(kn), g(an), f"thigh.{n}")
    BONES[f"foot.{n}"] = (g(an), g(an + Vector((0, -0.012, -0.04))), f"shin.{n}")
    parent = "chest"
    for i in range(CAPE_SEGMENTS):
        top, low = cape_point(0.45 * s, i / CAPE_SEGMENTS), cape_point(0.45 * s, (i + 1) / CAPE_SEGMENTS)
        BONES[f"tail.{n}.{i}"] = (g(torso_at(*top)), g(torso_at(*low)), parent)
        parent = f"tail.{n}.{i}"
ORDER = list(BONES)

arm_data = bpy.data.armatures.new("PilotRig")
rig = bpy.data.objects.new("PilotRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for name in ORDER:
    head, tail, parent = BONES[name]
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = head, tail
    eb.align_roll(Vector((1, 0, 0)).cross((tail - head).normalized()))   # local X = the figure's right
    eb.use_deform = name != "root"
    if parent:
        eb.parent = arm_data.edit_bones[parent]
        eb.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")
REST = {b.name: b.matrix_local.copy() for b in arm_data.bones}
PARENT = {name: BONES[name][2] for name in ORDER}

# ================================================================== the parts
# Soft, rounded solids at person_kit.gd's places and the kit's head size:
# each the convex hull of dense rings or an ellipsoid (or a tube swept
# along a curve: the trim, the scarf's turns), every end rounded off (no
# flat caps), smooth shaded all over; only the goggles' brass rims keep a
# crisp edge (CRISP).
CRISP = math.radians(60.0)

def smooth_rings(rings, between):
    """`between` more rings between each pair, on a Catmull-Rom curve
    through them (the profile rounds out, its ends stay put)."""
    pts = [Vector(r) for r in rings]
    out = []
    for i in range(len(pts) - 1):
        p0, p1, p2 = pts[max(i - 1, 0)], pts[i], pts[i + 1]
        p3 = pts[i + 2] if i + 2 < len(pts) else p2
        for k in range(between + 1):
            t = k / (between + 1)
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-1])
    return [(v.x, max(v.y, 0.0), max(v.z, 0.0)) for v in out]

CAP_ANGLES = (25, 50, 72, 88)

def capped(rings, depth=0.6, start=True, end=True):
    """The rings (along, radius x, radius y) closed off at either end by a
    dome `depth` of the end ring's smaller radius deep, so no flat cap."""
    out = list(rings)
    if start:
        z, a, b = rings[0]
        d = min(a, b) * depth
        out = [(z - d * math.sin(math.radians(t)), a * math.cos(math.radians(t)), b * math.cos(math.radians(t)))
               for t in reversed(CAP_ANGLES)] + out
    if end:
        z, a, b = rings[-1]
        d = min(a, b) * depth
        out += [(z + d * math.sin(math.radians(t)), a * math.cos(math.radians(t)), b * math.cos(math.radians(t)))
                for t in CAP_ANGLES]
    return out

def ring_hull(rings, sides, between=0):
    """Rings (along, radius x, radius y) round local Z, `between` more on a
    smooth curve between each pair."""
    pts = []
    for z, rx, ry in smooth_rings(rings, between):
        for i in range(sides):
            a = math.tau * (i + 0.5) / sides
            pts.append(Vector((math.cos(a) * rx, math.sin(a) * ry, z)))
    return pts

def blob(rx, ry, rz, sides=24, bands=12, down=None, front=None):
    """An ellipsoid about the origin (Y up, -Z the front): `down` the lower
    half's Y radius, `front` the front half's Z radius."""
    down = ry if down is None else down
    front = rz if front is None else front
    pts = [Vector((0, ry, 0)), Vector((0, -down, 0))]
    for k in range(1, bands):
        lat = math.pi * (k / bands - 0.5)
        y = math.sin(lat) * (ry if lat > 0 else down)
        c = math.cos(lat)
        for i in range(sides):
            a = math.tau * (i + 0.5 * (k % 2)) / sides
            z = math.sin(a) * c
            pts.append(Vector((math.cos(a) * c * rx, y, z * (front if z < 0 else rz))))
    return pts

def limb(near, far, length, sides=20):
    """A limb unit tall along Y (for bone_between), tapering from `near` to
    `far`, each end a round dome centred on its joint, so a bent knee or
    elbow stays whole and round."""
    pts = []
    rings = [(-0.5 - near / length * math.sin(math.radians(t)), near * math.cos(math.radians(t))) for t in (85, 60, 30)]
    rings += [(-0.5, near), (0.5, far)]
    rings += [(0.5 + far / length * math.sin(math.radians(t)), far * math.cos(math.radians(t))) for t in (30, 60, 85)]
    for y, r in rings:
        for i in range(sides):
            a = math.tau * i / sides
            pts.append(Vector((math.cos(a) * r, y, math.sin(a) * r)))
    return pts

def place(at=(0, 0, 0), turn=(0, 0, 0), size=(1, 1, 1)):
    """A Node3D's transform: position, rotation (Godot's YXZ order), scale."""
    rot = Euler(turn, "YXZ").to_matrix().to_4x4()
    return Matrix.Translation(Vector(at)) @ rot @ Matrix.Diagonal((*size, 1.0))

def bone_between(a, b):
    """PersonKit.bone: a unit-tall part stretched from a to b."""
    y = b - a
    other = Vector((0, 0, -1)) if abs(y.normalized().dot(Vector((0, 0, -1)))) < 0.9 else Vector((1, 0, 0))
    x = y.cross(other).normalized()
    z = x.cross(y.normalized()).normalized()
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = (a + b) * 0.5
    return m

def aligned(at, y_dir):
    """A frame at `at` whose Y runs along `y_dir`, its X the figure's right."""
    y = y_dir.normalized()
    z = Vector((1, 0, 0)).cross(y).normalized()
    m = Matrix((y.cross(z), y, z)).transposed().to_4x4()
    m.translation = at
    return m

def frame(at, normal, up=Vector((0, 1, 0))):
    """A frame at `at` whose Z runs out along `normal`, its Y up."""
    z = normal.normalized()
    x = up.cross(z).normalized()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = at
    return m

parts = []

def part(points, mat, bone, m, crisp=False):
    """The convex hull of `points` (the game's frame, build units) through
    `m`, riding `bone`, smooth shaded; `crisp` keeps its edges sharper than
    CRISP."""
    bm = bmesh.new()
    for p in points:
        q = m @ p
        bm.verts.new(G(q.x, q.y, q.z))
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    bm.normal_update()
    if crisp:
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.link_faces[0].normal.angle(e.link_faces[1].normal, 0.0) > CRISP:
                e.smooth = False
    add(bm, mat, bone)

def add(bm, mat, bone, weights=None):
    """`bm` as a part riding `bone`, smooth shaded (or, given `weights`, a
    {bone: weight} for each of its vertices in order, skinned across them:
    the cape alone bends). Its two UV maps carry where each corner stands
    in rest (x, y; z) and a number of its own (for the paint's noise, which
    so stays on the body as it moves)."""
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new(bone)
    bm.to_mesh(me)
    bm.free()
    own = ((len(parts) * 0.618034) % 1.0)
    rest_xy, rest_z = me.uv_layers.new(name="rest_xy"), me.uv_layers.new(name="rest_z")
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        rest_xy.data[loop.index].uv = (co.x, co.y)
        rest_z.data[loop.index].uv = (co.z, own)
    ob = bpy.data.objects.new(bone, me)
    scene.collection.objects.link(ob)
    ob.data.materials.append(materials[mat])
    if weights is None:
        ob.vertex_groups.new(name=bone).add(range(len(me.vertices)), 1.0, "REPLACE")
    else:
        groups = {}
        for k, w in enumerate(weights):
            for name, x in w.items():
                if x <= 1e-4:
                    continue
                if name not in groups:
                    groups[name] = ob.vertex_groups.new(name=name)
                groups[name].add([k], x, "REPLACE")
    parts.append(ob)

def tube(points, mat, bone, m, sides=12, between=3, lumps=0.0):
    """A rolled band through `points` ((point, radius) pairs), on a smooth
    curve with `between` more rings between each, its radius swelling and
    pinching `lumps` of itself between them (sheepskin), each end a dome."""
    pts = [Vector(p) for p, r in points]
    radii = [r for p, r in points]
    path, rad = [], []
    for i in range(len(pts) - 1):
        p0, p1, p2 = pts[max(i - 1, 0)], pts[i], pts[i + 1]
        p3 = pts[min(i + 2, len(pts) - 1)]
        for k in range(between + 1):
            t = k / (between + 1)
            path.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                               + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
            rad.append((radii[i] * (1 - t) + radii[i + 1] * t) * (1.0 + lumps * math.cos(math.tau * t)))
    path.append(pts[-1])
    rad.append(radii[-1] * (1.0 + lumps))
    # Domes on the ends.
    first, last = (path[0] - path[1]).normalized(), (path[-1] - path[-2]).normalized()
    for a in (35, 65, 85):
        c = math.cos(math.radians(a))
        path.insert(0, pts[0] + first * radii[0] * (1.0 + lumps) * math.sin(math.radians(a)))
        rad.insert(0, radii[0] * (1.0 + lumps) * c)
    for a in (35, 65, 85):
        c = math.cos(math.radians(a))
        path.append(pts[-1] + last * radii[-1] * (1.0 + lumps) * math.sin(math.radians(a)))
        rad.append(radii[-1] * (1.0 + lumps) * c)
    bm = bmesh.new()
    rings = []
    normal = None
    for i, p in enumerate(path):
        along = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        if normal is None:
            normal = along.orthogonal().normalized()
        normal = (normal - along * normal.dot(along)).normalized()
        side = along.cross(normal)
        ring = []
        for k in range(sides):
            a = math.tau * k / sides
            q = m @ (p + (normal * math.cos(a) + side * math.sin(a)) * rad[i])
            ring.append(bm.verts.new(G(q.x, q.y, q.z)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((r0[k], r0[(k + 1) % sides], r1[(k + 1) % sides], r1[k]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    add(bm, mat, bone)

def slab(at, nu, nv, thick, mat, bone, m, wrap=False, weigh=None):
    """A thin sheet with a thickness (the hat's brim, the cape): its top
    face through the grid `at(i, j)` (i across, `nu` of them, round and
    closed if `wrap`; j along, `nv`), its underside `thick(i, j)` under it
    along the sheet's normal, the edges closed between them; skinned by
    `weigh(i, j)` ({bone: weight}) if given, else riding `bone`."""
    top = [[m @ at(i, j) for i in range(nu)] for j in range(nv)]
    def nb(i):
        return i % nu if wrap else min(max(i, 0), nu - 1)
    bm = bmesh.new()
    upper, lower, weights = [], [], []
    for j in range(nv):
        ru, rl = [], []
        for i in range(nu):
            across = top[j][nb(i + 1)] - top[j][nb(i - 1)]
            along = top[min(j + 1, nv - 1)][i] - top[max(j - 1, 0)][i]
            normal = across.cross(along).normalized()
            p = top[j][i]
            q = p - normal * thick(i, j)
            ru.append(bm.verts.new(G(p.x, p.y, p.z)))
            rl.append(bm.verts.new(G(q.x, q.y, q.z)))
            if weigh is not None:
                weights.extend([weigh(i, j)] * 2)
        upper.append(ru)
        lower.append(rl)
    span = nu if wrap else nu - 1
    for j in range(nv - 1):
        for i in range(span):
            k = (i + 1) % nu
            bm.faces.new((upper[j][i], upper[j][k], upper[j + 1][k], upper[j + 1][i]))
            bm.faces.new((lower[j][i], lower[j + 1][i], lower[j + 1][k], lower[j][k]))
    # The edges: along j at both ends of j, and (open) along i at both ends.
    for j in (0, nv - 1):
        for i in range(span):
            k = (i + 1) % nu
            bm.faces.new((upper[j][i], lower[j][i], lower[j][k], upper[j][k]))
    if not wrap:
        for i in (0, nu - 1):
            for j in range(nv - 1):
                bm.faces.new((upper[j][i], upper[j + 1][i], lower[j + 1][i], lower[j][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    add(bm, mat, bone, weights if weigh is not None else None)

UP = (-math.pi * 0.5, 0, 0)
hips = place((0, REST_HIPS, 0))
torso = hips @ place((0, TORSO_UP, 0))

# ---------------------------------------------------------------- hips
# The seat of the denim trousers, broad and rounded under the jacket's
# skirt, the legs hung from its sides; the satchel at the left hip.
part(ring_hull(capped([(-0.034, 0.072, 0.047), (-0.012, 0.084, 0.055), (0.02, 0.086, 0.058)], 0.7), 48),
     "pilot_trousers", "hips", hips @ place(turn=UP))
SATCHEL = hips @ place((-0.093, -0.002, -0.016), (0.0, -0.35, 0.06))
part(ring_hull(capped([(-0.011, 0.024, 0.021), (0.0, 0.026, 0.023), (0.011, 0.024, 0.021)], 0.35), 20),
     "pilot_strap", "hips", SATCHEL @ place(turn=(0.0, math.pi * 0.5, 0.0)))
# Its flap over the top and front, and a little gold clasp.
part(blob(0.027, 0.006, 0.014, 18, 6), "pilot_strap", "hips", SATCHEL @ place((0.0, 0.021, -0.003)))
part(blob(0.0045, 0.006, 0.0025, 10, 6), "pilot_gold", "hips", SATCHEL @ place((0.0, 0.012, -0.0135)))

# ---------------------------------------------------------------- chest
# A dark charcoal-brown jacket, a soft pear: fullest at the belly over the
# hips, easing in up the chest to narrow shoulders and rounding over into
# them (the arms' domes under them: no balls), its skirt under the belt.
JACKET = [(y * NECK / 0.13, x * 1.08, z * 1.05) for y, x, z in (
    (-0.006, 0.079, 0.06), (0.01, 0.083, 0.064), (0.036, 0.081, 0.064), (0.065, 0.075, 0.061),
    (0.088, 0.067, 0.056), (0.107, 0.057, 0.048), (0.124, 0.043, 0.035), (0.136, 0.03, 0.026))]
part(ring_hull(capped(JACKET, 0.5, start=False), 56, between=3), "pilot_jacket", "chest", torso @ place(turn=UP))
part(ring_hull([(-0.036, 0.083, 0.062), (-0.024, 0.088, 0.066), (-0.008, 0.09, 0.067), (0.004, 0.09, 0.067)], 64),
     "pilot_jacket", "chest", torso @ place(turn=UP))

def jacket_at(y):
    """The jacket's radii (x, z) at height `y` of the torso."""
    pts = JACKET
    if y <= pts[0][0]:
        return pts[0][1], pts[0][2]
    for (y0, x0, z0), (y1, x1, z1) in zip(pts, pts[1:]):
        if y <= y1:
            t = (y - y0) / (y1 - y0)
            return x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
    return pts[-1][1], pts[-1][2]

# Soft folds in the cloth: gathered under the belt and hanging down the
# skirt below it, round the front and sides; creases across the chest
# under the arms.
for k in range(9):
    a = math.radians(-118 + 236 * k / 8 + 7 * math.sin(k * 1.7))
    fold = []
    for y, r, out in ((-0.003, 0.0026, 0.99), (-0.016, 0.0036, 1.0), (-0.033, 0.0026, 0.995)):
        rx, rz = jacket_at(y)
        fold.append((Vector((rx * math.sin(a), y, -rz * math.cos(a))) * out, r))
    tube(fold, "pilot_jacket", "chest", torso, 12, 4)
for s_ in (L, R):
    for y, a0, a1 in ((0.07 * NECK / 0.13, 50, 80), (0.052 * NECK / 0.13, 46, 82)):
        crease = []
        for k in range(5):
            a = math.radians((a0 + (a1 - a0) * k / 4) * s_)
            rx, rz = jacket_at(y)
            crease.append((Vector((rx * math.sin(a), y + 0.0008 * k, -rz * math.cos(a))) * 0.99, 0.0022 * (0.5 + math.sin(math.pi * k / 4))))
        tube(crease, "pilot_jacket", "chest", torso, 10, 3)

# The belt round the waist, a gold buckle at the front.
BELT_Y = 0.006
bx, bz = jacket_at(BELT_Y)
part(ring_hull([(-0.0065, bx + 0.0035, bz + 0.0035), (0.0065, bx + 0.0035, bz + 0.0035)], 64),
     "pilot_strap", "chest", torso @ place((0, BELT_Y, 0), UP))
part(blob(0.011, 0.0085, 0.003, 12, 6), "pilot_gold", "chest", torso @ place((0, BELT_Y, -bz - 0.0055)))
# The strap across him, from the right shoulder down over the chest to the
# left hip and round the back: where the jacket meets a slanting plane.
STRAP_SLOPE = 1.2
STRAP_AT = 0.088 * NECK / 0.13

def strap_point(a):
    """The strap's middle at angle `a` round the torso (0 the front, the
    figure's right positive), on the jacket's surface."""
    lo, hi = -0.004, NECK
    for _ in range(40):
        y = (lo + hi) * 0.5
        rx, rz = jacket_at(y)
        if y - STRAP_SLOPE * rx * math.sin(a) - STRAP_AT > 0.0:
            hi = y
        else:
            lo = y
    rx, rz = jacket_at(y)
    return Vector((rx * math.sin(a) * 1.04, y, -rz * math.cos(a) * 1.04))

tube([(strap_point(math.tau * k / 40), 0.0042) for k in range(42)], "pilot_strap", "chest", torso, 12, 3)
# A gold buckle on the strap over the chest.
sp = strap_point(math.radians(18))
part(blob(0.006, 0.0075, 0.0028, 10, 6), "pilot_gold", "chest", torso @ frame(sp, Vector((sp.x, 0, sp.z)).normalized()))

# The scarf, chunky navy rolls wound round the neck, the lower two on the
# chest, the top one riding the neck: each a fat round band.
def roll(R, r, sides=72):
    """A fat round band of radius `R` about local Z, `r` thick (rings for
    ring_hull)."""
    rings = []
    for k in range(13):
        a = math.radians(-86 + 172 * k / 12)
        rings.append((r * math.sin(a), R + r * math.cos(a), (R + r * math.cos(a)) * 0.94))
    return ring_hull(rings, sides)

part(roll(0.056, 0.02), "pilot_scarf", "chest", torso @ place((0, NECK - 0.013, 0.004), (-math.pi * 0.5 + 0.1, 0, 0.04)))
part(roll(0.05, 0.019), "pilot_scarf", "chest", torso @ place((0, NECK + 0.011, 0.003), (-math.pi * 0.5 - 0.08, 0, -0.05)))

# ---------------------------------------------------------------- neck, head
neck = torso @ place((0, NECK, 0))
part(ring_hull([(-0.028, 0.026, 0.026), (0.028, 0.023, 0.023)], 32), "pilot_face", "neck", neck @ place((0, 0.02, 0), UP))
part(roll(0.043, 0.018), "pilot_scarf", "neck", neck @ place((0, 0.032, 0.002), (-math.pi * 0.5 + 0.12, 0, 0.03)))
head = neck @ place((0, HEAD_UP, 0), size=(HEAD_SIZE,) * 3)
C = Vector((0, 0.055, 0))
# No face to see: a dark brown round head in the hat's shade, a touch
# taller than wide, the eyes painted on it glowing (shaders/pilot_paint.gdshader
# `eyes`, placed by EYE_* below).
HR = (0.075, 0.078, 0.08, 0.075)       # x, up, down, z
part(blob(HR[0], HR[1], HR[3], 56, 28, down=HR[2]), "pilot_face", "head", head @ place(C))
# The eyes (head units, off the head's middle): their middles this far out
# either side and down, and their half height.
EYE_X = 0.026
EYE_Y = -0.034
EYE_H = 0.018
HAT_BASE = 0.012                       # the hat brim's root over the head's middle
_eye = head @ (C + Vector((0, EYE_Y, -HR[3])))
_hat = head @ (C + Vector((0, HAT_BASE, 0)))
# For scripts/pilot_paint.gd (the face's eyes, in the paint's rest
# coordinates: Blender metres, x right, y forward, z up) and
# scripts/pocket_sail_figure.gd (where the hat sits, in the game's metres).
print("PILOT_EYES at", tuple(round(c, 4) for c in G(*_eye)), "apart", round(EYE_X * HEAD_SIZE * SCALE, 4),
      "half height", round(EYE_H * HEAD_SIZE * SCALE, 4), "head radius", round(HR[3] * HEAD_SIZE * SCALE, 4))
print("PILOT_HAT at", tuple(round(c * SCALE, 4) for c in _hat), "(standing, less", round(REST_HIPS * SCALE - HIPS, 4), "m)")

# The hat (the cap, more than a hat): soft terracotta felt, a round crown
# over the head, a dark band with a little buckle loop, and a wide brim
# that droops softly all round, more at the front and back, tipped a touch
# down at the front.
HAT_TILT = -0.06
BRIM_IN, BRIM_OUT = 0.066, 0.114
BRIM_DROOP = 0.015
hat = head @ place(C, (HAT_TILT, 0, 0))
part(ring_hull(capped([(HAT_BASE - 0.004, 0.077, 0.075), (0.045, 0.077, 0.075), (0.07, 0.067, 0.065)], 0.4, start=False), 72, between=4),
     "pilot_hat", "head", hat @ place(turn=UP))
part(ring_hull([(HAT_BASE + 0.0005, 0.0806, 0.0786), (HAT_BASE + 0.02, 0.0796, 0.0776)], 96),
     "pilot_hat_band", "head", hat @ place(turn=UP))

def brim_point(a, r):
    """The brim's top at angle `a` round (0 the front, the figure's right
    positive) and `r` out, in the hat's frame."""
    k = (r - BRIM_IN) / (BRIM_OUT - BRIM_IN)
    droop = BRIM_DROOP * k ** 1.6 * (0.62 + 0.38 * math.cos(2 * a)) + 0.0035 * k ** 2 * math.sin(3 * a + 0.7)
    return Vector((r * math.sin(a), HAT_BASE + 0.002 - droop, -r * math.cos(a)))

BRIM_AROUND, BRIM_ACROSS = 160, 12
slab(lambda i, j: brim_point(math.tau * i / BRIM_AROUND, BRIM_IN + (BRIM_OUT - BRIM_IN) * j / (BRIM_ACROSS - 1)),
     BRIM_AROUND, BRIM_ACROSS, lambda i, j: 0.0075 - 0.0035 * j / (BRIM_ACROSS - 1), "pilot_hat", "head", hat, wrap=True)
# The brim's edge rolled over, thick and soft.
tube([(brim_point(math.tau * k / BRIM_AROUND, BRIM_OUT) - Vector((0, 0.0035, 0)), 0.0052) for k in range(BRIM_AROUND + 3)],
     "pilot_hat", "head", hat, 16, 1)
# The band's buckle loop, front left as seen.
la = math.radians(-38)
lp = Vector((0.0806 * math.sin(la), HAT_BASE + 0.0102, -0.0786 * math.cos(la)))
loop = frame(lp, Vector((math.sin(la), 0, -math.cos(la))))
tube([(Vector(p), 0.0016) for p in ((-0.006, -0.0075, 0.001), (0.006, -0.0075, 0.001), (0.006, 0.0075, 0.001), (-0.006, 0.0075, 0.001), (-0.006, -0.0075, 0.001))],
     "pilot_hat_band", "head", hat @ loop, 6, 1)

# ---------------------------------------------------------------- limbs
# Sleeves to gold bracelets with a glowing stripe (a sign of the wanderer),
# big round mitts (a thumb forward); denim trousers into chunky boots with
# rolled fleece tops, round toes and a soft flat sole.
BOOT = [(-0.079, 0.019, 0.016), (-0.065, 0.035, 0.029), (-0.034, 0.038, 0.034), (0.006, 0.035, 0.034), (0.034, 0.03, 0.029), (0.043, 0.018, 0.017)]
SOLE = 0.006       # the sole's rounding (build units)
MITT = 1.2         # the mitts over the old ones
BOOTS = 1.12       # the boots' length and width over the old ones

def sole(y):
    """Flattens what is under the sole onto it, softly."""
    f = -ANKLE_BUILD + SOLE
    return y if y > f else f - SOLE * math.tanh((f - y) / SOLE)

def boot():
    return [Vector((p.x * BOOTS, sole(p.y * 1.08), p.z * BOOTS)) for p in ring_hull(capped(BOOT, 0.5), 36, between=2)]

def mitt(hand, s, bone):
    """A mitten on the wrist's frame `hand` (Y up the arm, -Z forward, X
    the figure's right), side `s`: a broad flat paddle (wider fore and aft
    than thick, the palm in), its rounded tip curled a little in towards
    the palm past the knuckles, and a thumb lobe of its own off the front
    edge on the palm's side, angled forward and in."""
    part(ring_hull(capped([(0.0, 0.021, 0.026), (0.017, 0.023, 0.031), (0.032, 0.0225, 0.032)], 0.6), 36, between=3),
         "pilot_mitt", bone, hand @ place(turn=(math.pi * 0.5, 0, 0)))
    knuckles = hand @ place((0.0, -0.03, 0.0), (0.0, 0.0, -0.32 * s))
    part(ring_hull(capped([(0.0, 0.0215, 0.032), (0.015, 0.02, 0.0305), (0.026, 0.0165, 0.026)], 0.85), 36, between=3),
         "pilot_mitt", bone, knuckles @ place(turn=(math.pi * 0.5, 0, 0)))
    thumb = hand @ place((-0.008 * s, -0.012, -0.025), (0.85, 0.4 * s, 0.0))
    part(ring_hull(capped([(0.0, 0.0105, 0.0115), (0.017, 0.0105, 0.0115)], 0.9), 24), "pilot_mitt", bone,
         thumb @ place(turn=(math.pi * 0.5, 0, 0)))

for n, s in SIDES.items():
    sh, el, wr = arm_joints(s)
    part(limb(0.024, 0.023, ARM[0], 32), "pilot_jacket", f"upper_arm.{n}", bone_between(sh, el))
    part(limb(0.023, 0.021, ARM[1], 32), "pilot_jacket", f"forearm.{n}", bone_between(el, wr))
    hand = aligned(wr, el - wr)
    # The bracelet, chunky gold, its stripe glowing round its middle.
    part(ring_hull(capped([(-0.0115, 0.0295, 0.0295), (0.0115, 0.0295, 0.0295)], 0.25), 48),
         "pilot_gold", f"forearm.{n}", hand @ place((0, 0.012, 0), UP))
    part(ring_hull([(-0.0028, 0.031, 0.031), (0.0028, 0.031, 0.031)], 48),
         "pilot_glow", f"forearm.{n}", hand @ place((0, 0.012, 0), UP))
    mitt(hand @ place(size=(MITT,) * 3), s, f"hand.{n}")
    hp, kn, an = leg_joints(s)
    part(limb(0.043, 0.038, LEG[0], 32), "pilot_trousers", f"thigh.{n}", bone_between(hp, kn))
    part(limb(0.038, 0.029, LEG[1], 32), "pilot_trousers", f"shin.{n}", bone_between(kn, an))
    part(boot(), "pilot_boots", f"foot.{n}", place(an))
    part(ring_hull(capped([(-0.026, 0.038, 0.038), (0.026, 0.035, 0.035)], 0.4), 36), "pilot_boots", f"foot.{n}", place(an + Vector((0, 0.024, 0.004)), UP))
    # The fleece rolled over the boot's top, round the shin.
    part(roll(0.03, 0.013, 48), "pilot_fleece", f"foot.{n}", place(an + Vector((0, 0.052, 0.004)), UP))

# ---------------------------------------------------------------- the cape
# A tattered dark grey cape from the shoulders, wrapped round the back and
# flaring out down it, its hem torn into jagged points: one sheet, skinned
# (the one part that bends) to the two chains of hinged bones down its
# halves (tail.L.*, tail.R.*), blended across its middle and between each
# strip and the next, so it bends and streams as cloth.
CAPE_NU, CAPE_NV = 97, 31

def cape_grid(a, b):
    u = -1.0 + 2.0 * a / (CAPE_NU - 1)
    return torso_at(*cape_point(u, (1.0 - cape_tear(u)) * b / (CAPE_NV - 1)))

def cape_weigh(a, b):
    u = -1.0 + 2.0 * a / (CAPE_NU - 1)
    v = (1.0 - cape_tear(u)) * b / (CAPE_NV - 1)
    right = min(max((u + 0.3) / 0.6, 0.0), 1.0)
    right = right * right * (3.0 - 2.0 * right)
    # Down the chain: each strip's own over its middle, blended to the next
    # across the joint.
    t = min(max(v * CAPE_SEGMENTS - 0.5, 0.0), CAPE_SEGMENTS - 1.0)
    i = min(int(t), CAPE_SEGMENTS - 2)
    f = t - i
    out = {}
    for n, side in (("L", 1.0 - right), ("R", right)):
        out[f"tail.{n}.{i}"] = side * (1.0 - f)
        out[f"tail.{n}.{i + 1}"] = side * f
    return out

slab(cape_grid, CAPE_NU, CAPE_NV, lambda a, b: CAPE_THICK, "pilot_cape", "tail.L.0", Matrix.Identity(4), weigh=cape_weigh)

# One mesh, skinned to the rig, one material slot per colour.
bpy.ops.object.select_all(action="DESELECT")
for ob in parts:
    ob.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = body.data.name = "Pilot"
by_name = {}
for i, slot in enumerate(body.material_slots):
    by_name.setdefault(slot.material.name.split(".")[0], []).append(i)
keep = {k: v[0] for k, v in by_name.items()}
remap = {i: keep[k] for k, v in by_name.items() for i in v}
for poly in body.data.polygons:
    poly.material_index = remap[poly.material_index]
bpy.ops.object.material_slot_remove_unused()
body.parent = rig
body.modifiers.new("Rig", "ARMATURE").object = rig
print("PILOT_TRIS", sum(len(p.vertices) - 2 for p in body.data.polygons))

# ================================================================== posing
def qx(a): return Quaternion((1, 0, 0), a)
def qz(a): return Quaternion((0, 0, 1), a)
def deg(d): return math.radians(d)

def turn(pitch=0.0, roll=0.0, yaw=0.0):
    """A turn in the figure's axes, degrees: pitch about X (a hanging limb
    forward, an upright one back), roll about Y (an upright one to the right,
    a hanging one outward on the left), yaw about Z (the right side forward)."""
    return qz(deg(yaw)) @ qx(deg(pitch)) @ Quaternion((0, 1, 0), deg(roll))

def matrix(origin, y_axis, z_hint):
    y = y_axis.normalized()
    x = y.cross(z_hint).normalized()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = origin
    return m

def two_bone(hip, ankle, a, b, pole):
    to = ankle - hip
    d = min(to.length, (a + b) * 0.9995)
    n = to.normalized()
    along = (a * a - b * b + d * d) / (2 * d)
    out = math.sqrt(max(a * a - along * along, 0.0))
    bend = (pole - n * pole.dot(n)).normalized()
    knee = hip + n * along + bend * out
    return knee, hip + n * d, bend, to.length / (a + b)

class Pose:
    """One frame: FK turns (in the figure's axes, relative to the parent),
    where the hips are, and IK goals for the boots."""
    def __init__(self):
        self.turns = {}
        self.hips_at = Vector((0, 0, HIPS))
        self.feet = {}      # side -> (ankle, the boot's turn)
        self.pole = {}      # side -> the knee's way
        self.hands = {}     # side -> (wrist, the elbow's way, how much: 0 FK to 1 on the wrist)

def solve(pose):
    """Armature-space matrices for every bone, and the legs' worst reach.
    An arm with a goal in `pose.hands` is reached to its wrist by two-bone
    IK (the elbow out its way), mixed with its FK turns by the goal's
    weight; its mitt rides on as FK."""
    P = {}
    for name in ORDER:
        if name.startswith(("thigh", "shin", "foot")):
            continue
        rest = REST[name]
        parent = PARENT[name]
        rot3 = rest.to_3x3()
        q = pose.turns.get(name, Quaternion())
        local = (rot3.inverted() @ q.to_matrix() @ rot3).to_4x4()
        if name == "hips":
            local.translation = rot3.inverted() @ (pose.hips_at - rest.translation)
        carried = rest if parent is None else P[parent] @ (REST[parent].inverted() @ rest)
        P[name] = carried @ local
        side = name.split(".")[-1]
        if name.startswith("forearm.") and side in pose.hands:
            reach_arm(P, side, *pose.hands[side])
    reach = 0.0
    for n in SIDES:
        hip = (P["hips"] @ (REST["hips"].inverted() @ REST[f"thigh.{n}"])).translation
        ankle, foot_rot = pose.feet[n]
        knee, ankle, bend, r = two_bone(hip, ankle, THIGH, SHIN, pose.pole[n])
        reach = max(reach, r)
        P[f"thigh.{n}"] = matrix(hip, knee - hip, bend)
        P[f"shin.{n}"] = matrix(knee, ankle - knee, bend)
        foot = (foot_rot.to_matrix() @ REST[f"foot.{n}"].to_3x3()).to_4x4()
        foot.translation = ankle
        P[f"foot.{n}"] = foot
    return P, reach

ARM_REACH = [0.0]

def reach_arm(P, n, wrist, pole, weight):
    """The arm on side `n` reached to `wrist` (its elbow out towards
    `pole`), mixed `weight` of the way from its FK pose."""
    upper, fore = f"upper_arm.{n}", f"forearm.{n}"
    sh = P[upper].translation
    elbow, reached, bend, r = two_bone(sh, wrist, UPPER, FORE, pole)
    ARM_REACH[0] = max(ARM_REACH[0], r * weight)
    # The bend's side is the forearm's fold, the bones' +Z as the legs'.
    up_ik = matrix(sh, elbow - sh, -bend).to_quaternion()
    fore_ik = matrix(elbow, reached - elbow, -bend).to_quaternion()
    def mix(fk, ik):
        if fk.dot(ik) < 0:
            ik = -ik
        return fk.slerp(ik, weight)
    up_q = mix(P[upper].to_quaternion(), up_ik)
    fore_q = mix(P[fore].to_quaternion(), fore_ik)
    P[upper] = Matrix.Translation(sh) @ up_q.to_matrix().to_4x4()
    at = sh + up_q @ Vector((0, UPPER, 0))
    P[fore] = Matrix.Translation(at) @ fore_q.to_matrix().to_4x4()

def basis(P):
    out = {}
    for name in ORDER:
        parent = PARENT[name]
        rest = REST[name]
        out[name] = rest.inverted() @ P[name] if parent is None else \
            (REST[parent].inverted() @ rest).inverted() @ P[parent].inverted() @ P[name]
    return out

def boot_on(base, lift, pitch, yaw):
    """The ankle and the boot's turn for a boot whose sole would stand at
    `base` (under the ankle), lifted `lift`, pitched `pitch` degrees (toe up
    positive): toe up it rocks on its heel, toe down on its ball."""
    rot = qz(deg(yaw)) @ qx(deg(pitch))
    pivot = HEEL if pitch > 0 else BALL
    fwd = qz(deg(yaw)) @ Vector((0, 1, 0))
    p = base + fwd * pivot + Vector((0, 0, lift))
    return p + rot @ Vector((0, -pivot, ANKLE)), rot

# ------------------------------------------------------------------ curves
def periodic(keys):
    """A smooth periodic curve through (phase, value) keys over [0, 1):
    monotone cubic (Fritsch-Carlson), so a flat run stays flat."""
    keys = sorted(keys)
    n = len(keys)
    xs = [k[0] - 1 for k in keys[-2:]] + [k[0] for k in keys] + [k[0] + 1 for k in keys[:2]]
    ys = [k[1] for k in keys[-2:]] + [k[1] for k in keys] + [k[1] for k in keys[:2]]
    sec = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(len(xs) - 1)]
    tan = [0.0] * len(xs)
    for i in range(1, len(xs) - 1):
        a, b = sec[i - 1], sec[i]
        h0, h1 = xs[i] - xs[i - 1], xs[i + 1] - xs[i]
        tan[i] = 0.0 if a * b <= 0 else 3 * (h0 + h1) / ((2 * h1 + h0) / a + (h1 + 2 * h0) / b)
    def f(t):
        t = t % 1.0
        i = 1 + n
        for j in range(2, 2 + n):
            if t < xs[j + 1]:
                i = j
                break
        h = xs[i + 1] - xs[i]
        u = (t - xs[i]) / h
        return ((2 * u ** 3 - 3 * u ** 2 + 1) * ys[i] + (u ** 3 - 2 * u ** 2 + u) * h * tan[i]
                + (-2 * u ** 3 + 3 * u ** 2) * ys[i + 1] + (u ** 3 - u ** 2) * h * tan[i + 1])
    return f

def wave(p, harmonic=1, at=0.0):
    """cos, one at phase `at`, `harmonic` times a loop."""
    return math.cos(math.tau * harmonic * (p - at))

def sine(p, harmonic=1, at=0.0):
    return math.sin(math.tau * harmonic * (p - at))

class Gait:
    """One boot's path through its own cycle (q 0 at touchdown): planted for
    `stance` of it, sliding back at `speed`; then swung forward, leaving and
    meeting the ground at `tangent` of the ground's speed (1, no jolt; less,
    it reaches less far past where it lands), lifted `lift` at most, `peak`
    of the way through the swing."""
    def __init__(self, speed, cycle, stance, lift, peak, pitch, ahead=0.0, tangent=1.0):
        self.speed, self.cycle, self.stance = speed, cycle, stance
        self.lift, self.pitch = lift, periodic(pitch)
        self.travel = speed * stance * cycle
        self.ahead = ahead
        self.tangent = tangent
        # The lift's shape u^a (1-u)^2 peaks at a/(a+2).
        self.a = 2.0 * peak / (1.0 - peak)
        self.norm = (peak ** self.a) * ((1 - peak) ** 2)

    def at(self, q):
        s = self.stance
        if q < s:
            y, lift = self.travel * (0.5 - q / s), 0.0
        else:
            u = (q - s) / (1 - s)
            m = -self.speed * (1 - s) * self.cycle * self.tangent
            a, b = -self.travel * 0.5, self.travel * 0.5
            y = (2 * u ** 3 - 3 * u ** 2 + 1) * a + (u ** 3 - 2 * u ** 2 + u) * m + (-2 * u ** 3 + 3 * u ** 2) * b + (u ** 3 - u ** 2) * m
            lift = self.lift * (u ** self.a) * (1 - u) ** 2 / self.norm
        return y + self.ahead, lift, self.pitch(q)

def cape_turn(i, pitch=0.0, roll=0.0, yaw=0.0):
    """A turn for the cape's strip `i` (the clips were keyed for the old
    scarf's light tails): never swung forward into the legs nor thrown up
    over the hat, the top strip carrying most of it, the lower ones
    following it with a little more curl, so the cape streams back in one
    sweep rather than coiling."""
    if i == 0:
        pitch = min(max(pitch, -92.0), -3.0)
        roll = min(max(roll, -30.0), 30.0)
    else:
        pitch = min(max(pitch * 0.45, -12.0), 6.0)
        roll = min(max(roll * 0.5, -10.0), 10.0)
    return turn(pitch=pitch, roll=roll, yaw=yaw * 0.5)

def scarf(pose, p, n, s, back, flutter, flap, beat=2):
    """The cape's halves (the old scarf's tails' channels): blown back
    `back` degrees, fluttering with the steps, each strip a beat behind the
    one above."""
    for i in range(CAPE_SEGMENTS):
        lag = 0.08 * (i + 1) + (0.035 if n == "R" else 0.0)
        pose.turns[f"tail.{n}.{i}"] = cape_turn(i,
            pitch=-(back if i == 0 else back * 0.35) - flutter * (1 + 0.4 * i) * wave(p, beat, 0.1 + lag),
            roll=flap * sine(p, 1, 0.08 + lag) + 3.0 * s,
            yaw=flap * 0.5 * wave(p, 1, lag))

# ------------------------------------------------------------------ walk
WALK = Gait(WALK_SPEED, WALK_CYCLE, WALK_STANCE, lift=0.05, peak=0.42,
            pitch=[(0.0, 12.0), (0.1, 0.0), (0.33, 0.0), (WALK_STANCE, -32.0), (0.7, -18.0), (0.86, 2.0), (0.95, 10.0)],
            ahead=0.004)

def walk_pose(p):
    """A happy amble (Mario's walk): short quick steps, the body bouncing up
    off each and swaying over it, the head bobbing and tipping with it, the
    arms hanging at the sides and swinging a little, loose at the elbow and
    the wrist."""
    pose = Pose()
    # Lowest just after a boot lands and springing up off it: a sharp
    # bottom, a rounder top.
    bounce = -wave(p, 2, 0.06) - 0.3 * wave(p, 4, 0.06)
    pose.hips_at = Vector((-0.016 * sine(p, 1, 0.02), 0.005 * wave(p, 2, 0.12), HIPS - 0.024 + 0.018 * bounce))
    pelvis_yaw = -8.0 * wave(p)
    pose.turns["hips"] = turn(pitch=-2.0, roll=6.0 * sine(p), yaw=pelvis_yaw)
    chest_yaw = 9.0 * wave(p, 1, 0.03)
    pose.turns["chest"] = turn(pitch=-3.0 - 2.0 * wave(p, 2, 0.16), roll=-4.0 * sine(p, 1, 0.04), yaw=chest_yaw)
    net = pelvis_yaw + chest_yaw
    pose.turns["neck"] = turn(pitch=3.0 - 1.5 * wave(p, 2, 0.22), yaw=-net * 0.4, roll=1.5 * sine(p, 1, 0.1))
    pose.turns["head"] = turn(pitch=3.0 - 3.0 * wave(p, 2, 0.28), yaw=-net * 0.4, roll=-3.0 * sine(p, 1, 0.14))
    for n, s in SIDES.items():
        q = (p + (0.0 if n == "L" else 0.5)) % 1.0
        y, lift, pitch = WALK.at(q)
        pose.feet[n] = boot_on(Vector((s * 0.135, y, 0.0)), lift, pitch, -7.0 * s)
        pose.pole[n] = qz(deg(-6.0 * s)) @ Vector((0, 1, 0.1))
        # Against its leg, a small swing, the forearm and the mitt trailing
        # it; flung out a touch as the body comes down on each step.
        a = (q + 0.5) % 1.0
        pose.turns[f"upper_arm.{n}"] = turn(pitch=2.0 + 16.0 * wave(a, 1, 0.07), roll=-s * (3.5 + 1.5 * wave(p, 2, 0.14)))
        pose.turns[f"forearm.{n}"] = turn(pitch=5.0 + 5.0 * (0.5 + 0.5 * wave(a, 1, 0.17)))
        pose.turns[f"hand.{n}"] = turn(pitch=5.0 + 8.0 * wave(a, 1, 0.25))
        scarf(pose, p, n, s, back=14.0, flutter=6.0, flap=8.0)
    return pose

# ------------------------------------------------------------------ run
RUN = Gait(RUN_SPEED, RUN_CYCLE, RUN_STANCE, lift=0.17, peak=0.36,
           pitch=[(0.0, 6.0), (0.07, 0.0), (0.16, 0.0), (RUN_STANCE, -48.0), (0.48, -55.0), (0.72, -10.0), (0.88, 12.0)],
           ahead=-0.05, tangent=0.55)

def run_pose(p):
    """A cartoon hero's run (Mario's, A Short Hike's): fairly upright,
    leaning in only a little, the knees driving up and the heels kicking
    back, low over each planted boot and up through the leap between, the
    head steady and looking ahead; the arms held out wide from the body
    and bent sharp at the elbow, pumping forward and back out at the sides
    against the legs, the mitts loose about chest high."""
    pose = Pose()
    # Lowest over the planted boot, highest in the air between steps.
    bob = 0.03 * wave(p, 2, RUN_STANCE * 0.5 + 0.25)
    pose.hips_at = Vector((-0.008 * sine(p, 1, 0.05), 0.012 * wave(p, 2, 0.2), HIPS - 0.018 + bob))
    pelvis_yaw = -13.0 * wave(p, 1, 0.02)
    pose.turns["hips"] = turn(pitch=-4.0 + 1.5 * wave(p, 2, 0.15), roll=4.0 * sine(p, 1, 0.02), yaw=pelvis_yaw)
    chest_yaw = 16.0 * wave(p, 1, 0.05)
    pose.turns["chest"] = turn(pitch=-3.0 - 2.0 * wave(p, 2, 0.24), roll=-3.0 * sine(p, 1, 0.07), yaw=chest_yaw)
    net = pelvis_yaw + chest_yaw
    # The head kept level against the bob and the chest's dip, looking ahead.
    pose.turns["neck"] = turn(pitch=3.0 + 1.0 * wave(p, 2, 0.24), yaw=-net * 0.45, roll=1.0 * sine(p, 1, 0.12))
    pose.turns["head"] = turn(pitch=3.0 + 1.0 * wave(p, 2, 0.3), yaw=-net * 0.4, roll=-1.5 * sine(p, 1, 0.16))
    for n, s in SIDES.items():
        q = (p + (0.0 if n == "L" else 0.5)) % 1.0
        y, lift, pitch = RUN.at(q)
        pose.feet[n] = boot_on(Vector((s * 0.12, y, 0.0)), lift, pitch, -5.0 * s)
        pose.pole[n] = qz(deg(-4.0 * s)) @ Vector((0, 1, 0.0))
        # Mario's arms (Odyssey): held out from the body, near straight
        # (a little give at the elbow), swinging forward and back from the
        # shoulder out at the sides against the legs, loose and lagging;
        # flung out a little wider as the body comes down on each step.
        # (The rest already holds them ARM_OUT out, 11 degrees: the roll is
        # on top of it, about 21 in all.)
        a = (q + 0.5) % 1.0
        swing = wave(a, 1, 0.06)
        pose.turns[f"upper_arm.{n}"] = turn(pitch=2.0 + 38.0 * swing, roll=-s * (10.0 + 3.0 * swing + 4.0 * wave(p, 2, 0.22)))
        pose.turns[f"forearm.{n}"] = turn(pitch=20.0 + 6.0 * wave(a, 1, 0.12), yaw=-s * 3.0)
        pose.turns[f"hand.{n}"] = turn(pitch=-4.0 + 10.0 * wave(a, 1, 0.24), roll=-s * 4.0 * wave(p, 2, 0.3))
        scarf(pose, p, n, s, back=62.0, flutter=9.0, flap=10.0)
    return pose

# ------------------------------------------------------------------ skid
def skid_pose(p):
    """Braking hard out of a run, Mario's slide (the game slides the body
    and turns it round after; the clip stands in place, facing the way it
    ran): dropped low and leaning right back, the left boot braced out in
    front on its heel, toe up, the right under the body, the arms flung
    back and out for balance, the scarf thrown up and forward; all of it
    juddering as the boots chatter over the ground."""
    pose = Pose()
    shake = 0.6 * sine(p, 2) + 0.4 * sine(p, 3, 0.15)
    chatter = (0.5 + 0.5 * sine(p, 3, 0.05)) ** 2
    pose.hips_at = Vector((0.012, -0.05 + 0.003 * sine(p, 2, 0.1), HIPS - SKID_DROP + 0.005 * shake))
    pose.turns["hips"] = turn(pitch=10.0 + 1.5 * shake, roll=2.0, yaw=-14.0)
    pose.turns["chest"] = turn(pitch=9.0 + 2.5 * sine(p, 2, 0.12), roll=-3.0, yaw=10.0 + 1.5 * sine(p, 3, 0.1))
    pose.turns["neck"] = turn(pitch=-6.0, yaw=2.0)
    pose.turns["head"] = turn(pitch=-9.0 + 3.0 * sine(p, 2, 0.2), roll=-4.0 + 2.0 * sine(p, 3, 0.3))
    pose.feet["L"] = boot_on(Vector((-0.13, 0.2, 0.0)), 0.004 * chatter, 30.0 + 4.0 * shake, 14.0)
    pose.feet["R"] = boot_on(Vector((0.115, -0.08, 0.0)), 0.0, -12.0 + 2.0 * shake, -18.0)
    pose.pole["L"] = Vector((-0.1, 1.0, 0.5))
    pose.pole["R"] = Vector((0.2, 1.0, 0.0))
    for n, s in SIDES.items():
        flail = sine(p, 2, 0.1 + (0.12 if n == "R" else 0.0))
        pose.turns[f"upper_arm.{n}"] = turn(pitch=-70.0 + 8.0 * flail, roll=-s * (49.0 + 5.0 * sine(p, 3, 0.2)))
        pose.turns[f"forearm.{n}"] = turn(pitch=25.0 + 8.0 * flail)
        pose.turns[f"hand.{n}"] = turn(pitch=-10.0 + 14.0 * sine(p, 3, 0.3))
        for i in range(3):
            flick = sine(p, 2, 0.2 + 0.08 * i + (0.05 if n == "R" else 0.0))
            pose.turns[f"tail.{n}.{i}"] = cape_turn(i, 
                pitch=(-162.0 if i == 0 else -18.0) + 12.0 * flick,
                roll=-s * (22.0 if i == 0 else 5.0) + 5.0 * sine(p, 3, 0.1 * i),
                yaw=3.0 * flick)
    return pose

# ------------------------------------------------------------------ idle
# A long loop with things happening in it at odd times between holds of
# different lengths, so it never reads as a metronome (and the game starts it
# anywhere): the weight goes onto one boot and settles there, he glances
# left, shifts onto the other and shuffles the free boot out a little,
# glances right, looks up at the sky a while, rocks back on his heels,
# shuffles the boot back, and sighs. Each is a periodic curve through keyed
# (second, value) poses, flat between them.
def idle_curve(*keys):
    return periodic([(t / IDLE_LENGTH, v) for t, v in keys])

# The weight, -1 on the left boot to 1 on the right.
IDLE_WEIGHT = idle_curve((0.0, 0.15), (2.0, 0.15), (2.8, 1.0), (3.3, 0.85), (5.6, 0.85), (6.3, -1.0), (6.6, -0.9),
                         (7.4, -0.9), (7.9, -0.55), (12.8, -0.5), (13.5, 0.75), (13.9, 0.65), (15.1, 0.65),
                         (15.7, -0.95), (16.5, -0.9), (17.3, 0.15))
# Where he looks: degrees to his left, and up; his head's tilt to his right.
IDLE_LOOK = idle_curve((0.0, 0.0), (3.4, 0.0), (3.9, 30.0), (4.5, 30.0), (4.8, 25.0), (5.0, 25.0), (5.6, 3.0),
                       (6.4, -6.0), (7.4, -6.0), (8.0, 0.0), (9.0, 2.0), (9.5, -28.0), (10.1, -28.0), (10.8, -10.0),
                       (12.3, 8.0), (13.0, 0.0), (15.8, 0.0), (16.1, -5.0), (16.6, -4.0), (17.2, 0.0))
IDLE_TIP = idle_curve((0.0, -2.0), (3.4, -2.0), (3.9, 0.0), (5.0, 0.0), (5.6, -2.0), (6.4, -7.0), (7.4, -7.0),
                      (8.0, -2.0), (9.5, 1.0), (10.1, 1.0), (10.8, 26.0), (12.3, 22.0), (13.0, -2.0), (15.6, -2.0),
                      (16.0, -7.0), (16.6, -6.0), (17.2, 0.0), (17.5, 2.0), (17.95, -2.0))
IDLE_TILT = idle_curve((0.0, 0.0), (3.9, 0.0), (4.5, 5.0), (5.0, 5.0), (5.6, 0.0), (9.5, 0.0), (10.1, -3.0),
                       (10.8, 0.0))
# Rocking back on his heels, the toes' lift (degrees).
IDLE_ROCK = idle_curve((0.0, 0.0), (13.9, 0.0), (14.25, 10.0), (14.6, 0.0), (14.8, 3.5), (15.05, 0.0))
# The right boot shuffled out and later back: how far out and forward, its
# lift and its turn.
IDLE_STEP_OUT = idle_curve((0.0, 0.0), (6.6, 0.0), (7.2, 0.025), (15.8, 0.025), (16.4, 0.0))
IDLE_STEP_ON = idle_curve((0.0, 0.0), (6.6, 0.0), (7.2, 0.018), (15.8, 0.018), (16.4, 0.0))
IDLE_STEP_LIFT = idle_curve((0.0, 0.0), (6.55, 0.0), (6.9, 0.035), (7.25, 0.0), (15.75, 0.0), (16.1, 0.022), (16.45, 0.0))
IDLE_STEP_TURN = idle_curve((0.0, -10.0), (6.6, -10.0), (7.2, -16.0), (15.8, -16.0), (16.4, -10.0))
# A sigh, the shoulders rising and falling; the breaths' depth; the breeze.
IDLE_SIGH = idle_curve((0.0, 0.0), (16.6, 0.0), (17.2, 1.0), (17.9, 0.0))
IDLE_DEPTH = idle_curve((0.0, 1.0), (9.5, 1.0), (10.8, 0.6), (12.3, 0.6), (13.2, 1.0))
IDLE_BREEZE = idle_curve((0.0, 0.7), (4.0, 1.3), (7.0, 0.6), (11.0, 1.6), (14.0, 0.8))

def idle_pose(p):
    """Standing, the weight on one boot or the other, glancing about,
    breathing at an uneven pace; see the curves above."""
    pose = Pose()
    late = 0.3 / IDLE_LENGTH                   # the body following the head, the arms the hips
    w, w_late = IDLE_WEIGHT(p), IDLE_WEIGHT(p - late)
    look, tip, tilt = IDLE_LOOK(p), IDLE_TIP(p), IDLE_TILT(p)
    look += 1.2 * sine(p, 5, 0.1) + 0.6 * sine(p, 11, 0.3)
    rock, sigh = IDLE_ROCK(p), IDLE_SIGH(p)
    # Eight breaths a loop, some quicker, some slower.
    phase = 8 * p + 0.4 * math.sin(math.tau * p) + 0.2 * math.sin(2 * math.tau * p + 1.0)
    breath = -math.cos(math.tau * phase) * IDLE_DEPTH(p)
    pose.hips_at = Vector((0.012 * w + 0.0015 * sine(p, 3, 0.1) + 0.001 * sine(p, 7, 0.3),
                           0.003 * wave(p, 2, 0.4) - 0.0015 * rock,
                           HIPS - 0.005 * w * w + 0.0025 * breath + 0.004 * sigh + 0.0007 * rock))
    hips_yaw = 3.0 * w + 1.0 * sine(p, 4, 0.2)
    pose.turns["hips"] = turn(pitch=-1.0 + 0.4 * rock, roll=-2.6 * w, yaw=hips_yaw)
    chest_yaw = 0.25 * IDLE_LOOK(p - late)
    pose.turns["chest"] = turn(pitch=-1.5 + 1.8 * breath + 2.5 * sigh + 0.15 * IDLE_TIP(p - late),
                               roll=2.2 * w, yaw=chest_yaw - hips_yaw)
    turned = look - chest_yaw
    pose.turns["neck"] = turn(pitch=0.4 * tip - 0.5 * breath, yaw=0.4 * turned, roll=-1.0 * w)
    pose.turns["head"] = turn(pitch=0.6 * tip - 0.3 * rock, yaw=0.6 * turned, roll=-1.5 * w + tilt)
    step = (IDLE_STEP_OUT(p), IDLE_STEP_ON(p), IDLE_STEP_LIFT(p))
    # The boot without the weight eases up on its ball.
    pose.feet["L"] = boot_on(Vector((-0.145, 0.02, 0.0)), 0.0, rock - 4.0 * max(w, 0.0) ** 2, 10.0)
    pose.feet["R"] = boot_on(Vector((0.145 + step[0], -0.015 + step[1], 0.0)), step[2],
                             rock - 4.0 * max(-w, 0.0) ** 2 - 12.0 * step[2] / 0.035, IDLE_STEP_TURN(p))
    for n, s in SIDES.items():
        pose.pole[n] = qz(deg(-12.0 * s)) @ Vector((0, 1, 0.0))
        # Hanging loose, swinging a little after the hips as the weight
        # moves, forward as he rocks back, up with the sigh.
        pose.turns[f"upper_arm.{n}"] = turn(pitch=2.0 + 1.0 * breath + 0.8 * rock + 2.0 * sigh,
                                            roll=-s * (3.0 + 1.0 * breath + 3.5 * sigh) + 4.0 * (w - w_late))
        pose.turns[f"forearm.{n}"] = turn(pitch=6.0 + 1.5 * breath + 1.5 * sine(p, 2, 0.14 + 0.1 * (s > 0)) + 3.0 * sigh)
        pose.turns[f"hand.{n}"] = turn(pitch=5.0 + 2.0 * sine(p, 3, 0.2 + 0.07 * (s > 0)))
        for i in range(3):
            lag = 0.012 * (i + 1) + (0.008 if n == "R" else 0.0)
            breeze = IDLE_BREEZE(p - lag)
            stir = breeze * (2.5 * sine(p, 9, lag) + 1.5 * sine(p, 16, lag * 1.3) + 1.5 * sine(p, 5, lag))
            pose.turns[f"tail.{n}.{i}"] = cape_turn(i, pitch=-(10.0 if i == 0 else 3.0) + stir,
                                               roll=-2.0 * w_late + 3.0 * s + 1.5 * breeze * sine(p, 7, lag))
    return pose

# ------------------------------------------------------------------ the ledge
# Hanging from a lip and climbing up onto it. The clip's frame: the feet (the
# origin) hang HANG_DROP under the lip's top and HANG_OUT out from its edge,
# facing it (+Y), the wall straight down from the edge. The mitts grip over
# the edge (GRIP); the arms are reached to them by IK.
def grip(s, along=0.0, lift=0.0, back=0.0):
    """Where the mitt on side `s` grips: `along` the lip from its own
    place, lifted `lift` off it and pulled `back` out from the edge."""
    return Vector((s * GRIP_X + along, HANG_OUT + GRIP_IN - back, HANG_DROP + GRIP_UP + lift))

def dangle(pose, n, s, hips, kick=0.0, out=0.0, toe=-28.0):
    """A boot hanging under the hips, the knee a little bent, the toe
    down; `kick` swings it forward, `out` to its side."""
    ankle = hips + Vector((s * (0.1 + out), 0.03 + kick, -0.385))
    pose.feet[n] = (ankle, qz(deg(-6.0 * s)) @ qx(deg(toe)))
    pose.pole[n] = Vector((0.15 * s, 1.0, 0.1))

HANG_HIPS = Vector((0.0, HANG_OUT - 0.17, HANG_DROP - 0.325))

def hang_pose(p):
    """Hanging by both mitts from the lip, the arms near straight up over
    the head (the cap peeking over the edge), the elbows out; swaying a
    little side to side and to and fro under the hands, the legs dangling
    and swinging lazily after the body, a glance along the lip and back, a
    breath; the scarf tails stirring down the back."""
    pose = Pose()
    sway = sine(p, 1)
    swing = sine(p, 2, 0.1)
    breath = -wave(p, 3)
    hips = HANG_HIPS + Vector((0.014 * sway, 0.006 * swing, 0.003 * breath))
    pose.hips_at = hips
    # Swung out to a side, it hangs at a slant from the hands.
    pose.turns["hips"] = turn(pitch=-1.0 - 1.5 * swing, roll=-3.0 * sway, yaw=2.0 * sine(p, 1, 0.3))
    pose.turns["chest"] = turn(pitch=1.0 + 1.2 * breath, roll=1.5 * sway, yaw=-1.5 * sine(p, 1, 0.3))
    glance = 14.0 * idle_like(p)
    pose.turns["neck"] = turn(pitch=6.0, yaw=0.4 * glance)
    pose.turns["head"] = turn(pitch=10.0 + 2.0 * swing, yaw=0.6 * glance, roll=-2.0 * sway)
    for n, s in SIDES.items():
        pose.hands[n] = (grip(s), Vector((0.9 * s, -0.5, -0.5)), 1.0)
        pose.turns[f"hand.{n}"] = turn(pitch=-25.0)
        late = 0.06 + (0.03 if n == "R" else 0.0)
        dangle(pose, n, s, hips, kick=0.03 * sine(p, 2, 0.1 + late) - 0.01 * swing, out=0.006 * sine(p, 1, late))
        scarf(pose, p, n, s, back=6.0, flutter=4.0, flap=4.0, beat=6)
    return pose

def idle_like(p):
    """A glance along the lip and back once a loop, held a while each way."""
    return periodic([(0.0, 0.0), (0.2, 0.0), (0.3, 1.0), (0.5, 1.0), (0.6, -0.6), (0.75, -0.6), (0.85, 0.0)])(p)

SHIMMY = Gait(SHIMMY_SPEED, SHIMMY_CYCLE, SHIMMY_STANCE, lift=0.035, peak=0.45,
              pitch=[(0.0, 0.0), (0.5, 0.0)], tangent=0.6)

def shimmy_pose(p, way):
    """Hand over hand along the lip, `way` 1 to the right, -1 to the left
    (in place: the game moves the body): each mitt in turn lifts, reaches
    on and grips, the other hanging on; the body rocks under the gripping
    hand and lifts a touch as both grip, the legs trail the way and swing,
    the head looks where it goes."""
    pose = Pose()
    rock = sine(p, 2, 0.05)
    hips = HANG_HIPS + Vector((-way * 0.012 + 0.01 * rock, 0.0, 0.04 + 0.008 * wave(p, 2, 0.35)))
    pose.hips_at = hips
    pose.turns["hips"] = turn(pitch=-1.0, roll=way * 3.0 - 2.5 * rock, yaw=-way * 2.0)
    pose.turns["chest"] = turn(pitch=1.0 + 1.0 * wave(p, 2, 0.2), roll=2.0 * rock, yaw=-way * 1.0)
    pose.turns["neck"] = turn(pitch=5.0, yaw=-way * 8.0)
    pose.turns["head"] = turn(pitch=8.0 - 2.0 * wave(p, 2, 0.3), yaw=-way * 14.0, roll=-1.5 * rock)
    for n, s in SIDES.items():
        q = (p + (0.0 if s == way else 0.5)) % 1.0
        along, lift, _ = SHIMMY.at(q)
        pose.hands[n] = (grip(s, way * along, lift, back=0.4 * lift), Vector((0.9 * s, -0.5, -0.5)), 1.0)
        pose.turns[f"hand.{n}"] = turn(pitch=-25.0 + 120.0 * lift)
        # The legs trail the way, swinging after the body.
        late = 0.12 + (0.04 if n == "R" else 0.0)
        dangle(pose, n, s, hips + Vector((-way * (0.03 + 0.012 * wave(p, 2, late)), 0, 0)),
               kick=0.02 * sine(p, 2, late))
        scarf(pose, p, n, s, back=8.0, flutter=5.0, flap=6.0)
    return pose

# The climb: keyed poses, every channel eased through them (flat at the
# ends, so it leaves the hang and comes to the stand at rest). It starts as
# the hang (its first frame) and ends as the idle's first frame, stood
# CLIMB_IN in on the lip, so the game takes either up without a pop; played
# backwards it lowers him from standing on the lip into the hang.
TOP = Vector((0.0, HANG_OUT + CLIMB_IN, HANG_DROP))

def channels(pose):
    """A pose as flat channels of numbers (the quaternions as they are)."""
    out = {"hips": list(pose.hips_at)}
    for name in ORDER:
        if not name.startswith(("thigh", "shin", "foot")):
            out["turn:" + name] = list(pose.turns.get(name, Quaternion()))
    for n in SIDES:
        ankle, rot = pose.feet[n]
        out["foot:" + n] = list(ankle) + list(rot)
        out["pole:" + n] = list(pose.pole[n])
        if n in pose.hands:
            wrist, elbow, weight = pose.hands[n]
            out["hand:" + n] = list(wrist) + list(elbow) + [weight]
    return out

def from_channels(c):
    pose = Pose()
    pose.hips_at = Vector(c["hips"])
    for key, v in c.items():
        if key.startswith("turn:"):
            pose.turns[key[5:]] = Quaternion(v).normalized()
    for n in SIDES:
        v = c["foot:" + n]
        pose.feet[n] = (Vector(v[:3]), Quaternion(v[3:]).normalized())
        pose.pole[n] = Vector(c["pole:" + n])
        v = c.get("hand:" + n)
        if v and v[6] > 0.0005:
            pose.hands[n] = (Vector(v[:3]), Vector(v[3:6]), min(v[6], 1.0))
    return pose

def eased(keys):
    """A monotone cubic through (t, value) keys over [0, 1], flat at both
    ends and wherever a key is a turning point."""
    xs = [k[0] for k in keys]
    ys = [k[1] for k in keys]
    sec = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(len(xs) - 1)]
    tan = [0.0] * len(xs)
    for i in range(1, len(xs) - 1):
        a, b = sec[i - 1], sec[i]
        h0, h1 = xs[i] - xs[i - 1], xs[i + 1] - xs[i]
        tan[i] = 0.0 if a * b <= 0 else 3 * (h0 + h1) / ((2 * h1 + h0) / a + (h1 + 2 * h0) / b)
    def f(t):
        i = 0
        while i < len(xs) - 2 and t > xs[i + 1]:
            i += 1
        h = xs[i + 1] - xs[i]
        u = min(max((t - xs[i]) / h, 0.0), 1.0)
        return ((2 * u ** 3 - 3 * u ** 2 + 1) * ys[i] + (u ** 3 - 2 * u ** 2 + u) * h * tan[i]
                + (-2 * u ** 3 + 3 * u ** 2) * ys[i + 1] + (u ** 3 - u ** 2) * h * tan[i + 1])
    return f

def keyed(stages):
    """A clip through `stages`, (t, Pose) from t 0 to 1: each channel eased
    through its keys; a quaternion kept on the side of the one before it; a
    hand let go of (no goal) keeps its last grip, unweighted."""
    flat = [(t, channels(pose)) for t, pose in stages]
    for i, (_, c) in enumerate(flat):
        for n in SIDES:
            if "hand:" + n not in c:
                near = min((j for j in range(len(flat)) if "hand:" + n in flat[j][1]), key=lambda j: abs(j - i))
                c["hand:" + n] = flat[near][1]["hand:" + n][:6] + [0.0]
        if i:
            for key, v in c.items():
                if key.startswith("turn:") and sum(a * b for a, b in zip(v, flat[i - 1][1][key])) < 0:
                    c[key] = [-x for x in v]
                if key.startswith("foot:") and sum(a * b for a, b in zip(v[3:], flat[i - 1][1][key][3:])) < 0:
                    c[key] = v[:3] + [-x for x in v[3:]]
    curves = {key: [eased([(t, c[key][k]) for t, c in flat]) for k in range(len(v))] for key, v in flat[0][1].items()}
    return lambda t: from_channels({key: [f(t) for f in fs] for key, fs in curves.items()})

def lifted(pose, by):
    """`pose` moved by `by` (the hips and the boots)."""
    pose.hips_at = pose.hips_at + by
    for n in SIDES:
        ankle, rot = pose.feet[n]
        pose.feet[n] = (ankle + by, rot)
    return pose

def climb_stage(hips, hips_turn, chest, head, feet, elbows, hands=1.0, hand_lift=0.0, hand_pitch=-25.0, tails=8.0):
    """One of the climb's keyed poses: the hips' place and turn, the chest's
    and head's pitch, each boot's (ankle, toe pitch, the knee's way) and the
    elbows' way; the mitts on the lip by `hands` (lifted off it
    `hand_lift`)."""
    pose = Pose()
    pose.hips_at = hips
    pose.turns["hips"] = turn(pitch=hips_turn)
    pose.turns["chest"] = turn(pitch=chest)
    pose.turns["neck"] = turn(pitch=0.4 * head)
    pose.turns["head"] = turn(pitch=0.6 * head)
    for n, s in SIDES.items():
        ankle, toe, knee = feet[n]
        pose.feet[n] = (ankle, qz(deg(-6.0 * s)) @ qx(deg(toe)))
        pose.pole[n] = Vector((knee[0] * s, knee[1], knee[2]))
        if hands > 0.0:
            pose.hands[n] = (grip(s, lift=hand_lift), Vector((elbows[0] * s, elbows[1], elbows[2])), hands)
        pose.turns[f"hand.{n}"] = turn(pitch=hand_pitch)
        scarf(pose, 0.0, n, s, back=tails, flutter=0.0, flap=0.0)
    return pose

FORWARD_KNEE = (0.15, 1.0, 0.1)
# Dangling against the wall, the knees go out to the sides, not into it.
WIDE_KNEE = (1.0, 0.25, 0.0)
HIGH_KNEE = (0.35, 0.3, 1.0)

def climb_clip():
    """Up from the hang onto the lip: a gather (a dip, the knees drawn up),
    the pull (the shoulders up to the lip, the elbows bending down and back),
    the press up over the hands (the chest tipped over the lip, the elbows
    up behind), the right knee swung up over the edge and its boot set on
    the top, the left drawn up after it over the edge, stood up onto them as
    the mitts let go, and settled into standing."""
    stand = lifted(idle_pose(0.0), TOP)
    right, left = stand.feet["R"][0], stand.feet["L"][0]
    e = HANG_OUT
    t = HANG_DROP
    H = HANG_HIPS
    gather = climb_stage(H + Vector((0, 0.01, 0.025)), -2.0, 2.0, 18.0,
                         {"L": (H + Vector((-0.13, 0.03, -0.35)), -20.0, WIDE_KNEE), "R": (H + Vector((0.13, 0.04, -0.35)), -20.0, WIDE_KNEE)},
                         (0.9, -0.5, -0.6))
    pulled = climb_stage(Vector((0.0, e - 0.19, t - 0.22)), -4.0, -6.0, 22.0,
                         {"L": (Vector((-0.13, e - 0.17, t - 0.57)), -25.0, WIDE_KNEE), "R": (Vector((0.14, e - 0.15, t - 0.52)), -15.0, WIDE_KNEE)},
                         (0.7, -0.9, -0.9))
    pressed = climb_stage(Vector((0.0, e - 0.16, t - 0.06)), -16.0, -30.0, 14.0,
                          {"L": (Vector((-0.13, e - 0.15, t - 0.38)), -25.0, WIDE_KNEE), "R": (Vector((0.14, e - 0.14, t - 0.34)), -15.0, WIDE_KNEE)},
                          (0.5, -1.0, 0.7))
    swung = climb_stage(Vector((0.0, e - 0.12, t + 0.0)), -22.0, -30.0, 12.0,
                        {"L": (Vector((-0.13, e - 0.15, t - 0.36)), -25.0, WIDE_KNEE), "R": (Vector((0.14, e - 0.1, t + 0.1)), 10.0, HIGH_KNEE)},
                        (0.5, -1.0, 0.8))
    planted = climb_stage(Vector((0.02, e - 0.06, t + 0.02)), -24.0, -26.0, 10.0,
                          {"L": (Vector((-0.13, e - 0.14, t - 0.3)), -25.0, WIDE_KNEE), "R": (right, 0.0, HIGH_KNEE)},
                          (0.5, -1.0, 0.8))
    drawn = climb_stage(Vector((0.04, e + 0.04, t + 0.13)), -16.0, -16.0, 8.0,
                        {"L": (Vector((-0.13, e - 0.05, t + 0.09)), 5.0, HIGH_KNEE), "R": (right, 0.0, HIGH_KNEE)},
                        (0.5, -1.0, 0.6), hands=0.25, hand_lift=0.08)
    risen = climb_stage(Vector((0.03, e + 0.22, t + 0.3)), -8.0, -8.0, 4.0,
                        {"L": (left + Vector((0.0, -0.06, 0.05)), -6.0, FORWARD_KNEE), "R": (right, 0.0, FORWARD_KNEE)},
                        (0.6, -1.0, 0.0), hands=0.0, hand_pitch=0.0, tails=12.0)
    # The right boot plants as it stands at the end, and stays.
    for st in (planted, drawn, risen):
        st.feet["R"] = stand.feet["R"]
    # Keyed by how far the body goes between them, so the quick climb
    # (CLIMB_LENGTH) never darts: a short gather, then the pull and the stand
    # each given their share.
    return keyed([(0.0, hang_pose(0.0)), (0.08, gather), (0.26, pulled), (0.4, pressed), (0.47, swung),
                  (0.53, planted), (0.65, drawn), (0.84, risen), (1.0, stand)])

# ------------------------------------------------------------------ the moves
# The moves beyond running and jumping (scripts/pilot_motor.gd `move`,
# scripts/pilot_figure.gd blends them over the rest and keeps copies of the
# lengths): held poses alive with a little motion, and two once-through
# leaps. Never stiff: each leans into what it does, and the game's springs
# overshoot and settle on top.
#   crouch     CROUCH_LENGTH s, a loop: dropped low on bent knees, set wide,
#              leant forward, the head up to look ahead, the mitts down
#              between the knees, breathing;
#   long_jump  LONG_LENGTH s, a loop: Mario's long jump, stretched out flat
#              and diving forward, the arms reaching out ahead over the
#              head, the legs trailing straight behind, toes pointed, the
#              scarf streaming;
#   wall_slide WALL_LENGTH s, a loop: facing the wall (WALL_GAP ahead of the
#              feet), turned a little side on to it, the right mitt flat on
#              it at the head's height, the boots braced against it, the
#              left arm out for balance, looking down over the left
#              shoulder at the ground coming, juddering as he slides, the
#              scarf blown up;
#   wall_kick  KICK_LENGTH s, once: kicked off the wall now behind him (the
#              game turns him round as it starts): gathered against it, the
#              legs driving back off it and the arms flung up and forward,
#              then spread wide, rising;
#   pump       PUMP_LENGTH s, once: the pump's "yahoo": a gather, then
#              stretched up, the right fist punched high, the left arm out,
#              the right knee drawn up, then both arms up and wide.
CROUCH_LENGTH = 1.0
LONG_LENGTH = 0.5
WALL_LENGTH = 0.5
WALL_GAP = 0.3
KICK_LENGTH = 0.4
PUMP_LENGTH = 0.5

def crouch_pose(p):
    pose = Pose()
    breath = -wave(p, 1)
    pose.hips_at = Vector((0.0, -0.035, 0.3 + 0.006 * breath))
    pose.turns["hips"] = turn(pitch=-22.0 - 1.0 * breath, roll=1.0 * sine(p, 1, 0.2))
    pose.turns["chest"] = turn(pitch=-12.0 - 2.0 * breath, roll=-1.0 * sine(p, 1, 0.2))
    pose.turns["neck"] = turn(pitch=14.0)
    pose.turns["head"] = turn(pitch=16.0 + 1.5 * breath, yaw=4.0 * sine(p, 1, 0.3))
    for n, s in SIDES.items():
        pose.feet[n] = boot_on(Vector((s * 0.15, 0.03, 0.0)), 0.0, 0.0, -12.0 * s)
        pose.pole[n] = Vector((0.45 * s, 1.0, 0.15))
        pose.turns[f"upper_arm.{n}"] = turn(pitch=38.0 + 2.0 * breath, roll=-s * 6.0)
        pose.turns[f"forearm.{n}"] = turn(pitch=28.0, yaw=-s * 6.0)
        pose.turns[f"hand.{n}"] = turn(pitch=12.0)
        scarf(pose, p, n, s, back=10.0, flutter=3.0, flap=3.0)
    return pose

def long_jump_pose(p):
    pose = Pose()
    flutter = sine(p, 1)
    pose.hips_at = Vector((0.0, 0.0, 0.46 + 0.006 * flutter))
    pose.turns["hips"] = turn(pitch=-58.0 + 1.5 * flutter, roll=1.5 * sine(p, 1, 0.25))
    pose.turns["chest"] = turn(pitch=-8.0, roll=-1.5 * sine(p, 1, 0.25))
    # The head held up out of the dive, looking ahead.
    pose.turns["neck"] = turn(pitch=28.0)
    pose.turns["head"] = turn(pitch=30.0 + 2.0 * sine(p, 1, 0.1))
    for n, s in SIDES.items():
        late = 0.08 if n == "R" else 0.0
        pose.turns[f"upper_arm.{n}"] = turn(pitch=150.0 + 4.0 * sine(p, 1, late), roll=-s * (14.0 + 3.0 * sine(p, 1, 0.2 + late)))
        pose.turns[f"forearm.{n}"] = turn(pitch=8.0)
        pose.turns[f"hand.{n}"] = turn(pitch=-6.0)
        kick = 0.02 * sine(p, 1, 0.1 + 0.5 * (n == "R"))
        pose.feet[n] = (Vector((s * 0.1, -0.34 + kick, 0.27 - kick)), qz(deg(-4.0 * s)) @ qx(deg(-95.0)))
        pose.pole[n] = Vector((0.15 * s, 0.2, -1.0))
        scarf(pose, p, n, s, back=88.0, flutter=12.0, flap=10.0, beat=3)
    return pose

def wall_slide_pose(p):
    pose = Pose()
    shake = 0.6 * sine(p, 2) + 0.4 * sine(p, 3, 0.15)
    chatter = (0.5 + 0.5 * sine(p, 3, 0.05)) ** 2
    w = WALL_GAP
    pose.hips_at = Vector((0.02, -0.04, 0.43 + 0.004 * shake))
    # Turned side on, the right shoulder to the wall, leant back off it from
    # the hips, the chest into it.
    pose.turns["hips"] = turn(pitch=8.0 + 1.0 * shake, roll=-3.0, yaw=28.0)
    pose.turns["chest"] = turn(pitch=-14.0, roll=4.0, yaw=8.0 + 1.5 * sine(p, 2, 0.1))
    pose.turns["neck"] = turn(pitch=-8.0, yaw=-22.0)
    pose.turns["head"] = turn(pitch=-16.0 + 2.0 * sine(p, 3, 0.2), yaw=-26.0, roll=-5.0)
    # The boots braced flat on the wall, the right higher.
    pose.feet["R"] = (Vector((0.13, w - 0.08, 0.3 + 0.004 * chatter)), qz(deg(-10.0)) @ qx(deg(72.0 + 3.0 * shake)))
    pose.feet["L"] = (Vector((-0.1, w - 0.12, 0.2 + 0.004 * chatter)), qz(deg(8.0)) @ qx(deg(48.0)))
    pose.pole["R"] = Vector((0.5, 1.0, 0.4))
    pose.pole["L"] = Vector((-0.3, 1.0, 0.0))
    # The right mitt on the wall, the left out for balance.
    pose.hands["R"] = (Vector((0.16, w - 0.035, 0.83 + 0.006 * shake)), Vector((0.9, -0.2, -0.6)), 1.0)
    pose.turns["hand.R"] = turn(pitch=-70.0, roll=-10.0)
    flail = sine(p, 2, 0.1)
    pose.turns["upper_arm.L"] = turn(pitch=-25.0 + 6.0 * flail, roll=58.0 + 4.0 * sine(p, 3, 0.2))
    pose.turns["forearm.L"] = turn(pitch=35.0 + 6.0 * flail)
    pose.turns["hand.L"] = turn(pitch=-10.0)
    for n, s in SIDES.items():
        for i in range(3):
            flick = sine(p, 2, 0.2 + 0.08 * i + (0.05 if n == "R" else 0.0))
            pose.turns[f"tail.{n}.{i}"] = cape_turn(i, 
                pitch=(-150.0 if i == 0 else -16.0) + 12.0 * flick,
                roll=-s * (18.0 if i == 0 else 5.0) + 5.0 * sine(p, 3, 0.1 * i),
                yaw=3.0 * flick)
    return pose

def no_hands(pose):
    """No reach for either mitt (the arms are FK); `keyed` needs the channel."""
    for n, s in SIDES.items():
        pose.hands[n] = (Vector((s * 0.2, 0.0, 0.5)), Vector((s, 0.0, 0.0)), 0.0)
    return pose

def move_stage(hips, hips_turn, chest, head, feet, arms, tails=40.0):
    """One keyed pose of a leap: the hips' place and turn (pitch, roll, yaw),
    the chest's pitch and the head's, each boot's (ankle, toe pitch, the
    knee's way), each arm's (upper pitch, roll out, forearm pitch)."""
    pose = Pose()
    pose.hips_at = hips
    pose.turns["hips"] = turn(*hips_turn)
    pose.turns["chest"] = turn(pitch=chest)
    pose.turns["neck"] = turn(pitch=0.4 * head)
    pose.turns["head"] = turn(pitch=0.6 * head)
    for n, s in SIDES.items():
        ankle, toe, knee = feet[n]
        pose.feet[n] = (ankle, qz(deg(-6.0 * s)) @ qx(deg(toe)))
        pose.pole[n] = Vector((knee[0] * s, knee[1], knee[2]))
        up, out, fore = arms[n]
        pose.turns[f"upper_arm.{n}"] = turn(pitch=up, roll=-s * out)
        pose.turns[f"forearm.{n}"] = turn(pitch=fore)
        pose.turns[f"hand.{n}"] = turn(pitch=-5.0)
        scarf(pose, 0.0, n, s, back=tails, flutter=0.0, flap=0.0)
    return no_hands(pose)

def wall_kick_clip():
    gathered = move_stage(Vector((0.0, 0.04, 0.4)), (-24.0, 0.0, 0.0), -10.0, 16.0,
                          {"L": (Vector((-0.12, -0.24, 0.2)), -60.0, (0.3, 0.2, -1.0)),
                           "R": (Vector((0.12, -0.24, 0.26)), -60.0, (0.3, 0.2, -1.0))},
                          {"L": (-40.0, 25.0, 30.0), "R": (-40.0, 25.0, 30.0)}, tails=-20.0)
    driven = move_stage(Vector((0.0, 0.02, 0.44)), (-12.0, 0.0, 0.0), -2.0, 18.0,
                        {"L": (Vector((-0.11, -0.24, 0.16)), -75.0, (0.2, 0.1, -1.0)),
                         "R": (Vector((0.11, -0.22, 0.2)), -75.0, (0.2, 0.1, -1.0))},
                        {"L": (125.0, 35.0, 15.0), "R": (125.0, 35.0, 15.0)}, tails=-60.0)
    spread = move_stage(Vector((0.0, 0.02, 0.46)), (-4.0, 0.0, 0.0), 2.0, 12.0,
                        {"L": (Vector((-0.13, -0.08, 0.16)), -30.0, (0.3, 1.0, 0.1)),
                         "R": (Vector((0.13, -0.04, 0.2)), -25.0, (0.3, 1.0, 0.1))},
                        {"L": (70.0, 62.0, 25.0), "R": (70.0, 62.0, 25.0)}, tails=-40.0)
    return keyed([(0.0, gathered), (0.3, driven), (0.65, spread), (1.0, spread)])

def pump_clip():
    gather = move_stage(Vector((0.0, 0.0, 0.38)), (-12.0, 0.0, 0.0), -8.0, 6.0,
                        {"L": (Vector((-0.13, 0.0, 0.06)), -10.0, (0.3, 1.0, 0.1)),
                         "R": (Vector((0.13, 0.0, 0.06)), -10.0, (0.3, 1.0, 0.1))},
                        {"L": (-35.0, 20.0, 25.0), "R": (-35.0, 20.0, 25.0)}, tails=20.0)
    punched = move_stage(Vector((0.0, 0.0, 0.47)), (4.0, -3.0, 6.0), 6.0, 20.0,
                         {"L": (Vector((-0.11, -0.06, 0.1)), -45.0, (0.2, 1.0, 0.0)),
                          "R": (Vector((0.13, 0.1, 0.24)), -20.0, (0.2, 1.0, 0.3))},
                         {"L": (-5.0, 55.0, 30.0), "R": (155.0, 32.0, 4.0)}, tails=-50.0)
    wide = move_stage(Vector((0.0, 0.0, 0.46)), (0.0, 0.0, 0.0), 2.0, 14.0,
                      {"L": (Vector((-0.13, 0.02, 0.18)), -28.0, (0.3, 1.0, 0.2)),
                       "R": (Vector((0.13, 0.04, 0.2)), -25.0, (0.3, 1.0, 0.2))},
                      {"L": (125.0, 45.0, 20.0), "R": (135.0, 40.0, 15.0)}, tails=-35.0)
    punched.turns["hand.R"] = turn(pitch=10.0)
    return keyed([(0.0, gather), (0.32, punched), (0.62, punched), (1.0, wide)])

# ------------------------------------------------------------------ round three
# The air and the tricks (scripts/pilot_motor.gd "jump", "twirl", "slide",
# "flip"; scripts/pilot_figure.gd blends them and keeps copies of the
# lengths):
#   jump_rise  JUMP_LENGTH s, a loop: going up, stretched, the right knee
#              driven up and the left leg trailing, the arms swept up and
#              out ahead, the head up, the scarf streaming down;
#   jump_fall  JUMP_LENGTH s, a loop: coming down, the arms up and out wide
#              and paddling the air, the legs a little apart and bent,
#              reaching for the ground, looking down at it, the scarf blown
#              up; the game blends the two by the rise, so the top of a
#              jump is half of each;
#   twirl      TWIRL_LENGTH s, a loop: spun round (the game turns the body),
#              upright and stretched, the arms flung straight out to the
#              sides, the legs together and crossed at the ankle, toes
#              pointed, the scarf thrown out flat;
#   slide      SLIDE_LENGTH s, a loop: boot-surfing down a slope, standing,
#              the knees bent, the boots apart and pointed down the fall
#              line, the left a little ahead, the hips turned a touch side
#              on, the arms out for balance (the left ahead, the right
#              back), wobbling, the scarf streaming;
#   side_flip  FLIP_LENGTH s, once: the side flip's shape (the game rolls
#              the body over): sprung up straight, the arms up; tucked
#              tight, the knees to the chest and the mitts on the shins;
#              opened out, the legs down for the landing and the arms wide.
JUMP_LENGTH = 0.5
TWIRL_LENGTH = 0.4
SLIDE_LENGTH = 0.8
FLIP_LENGTH = 0.7

def jump_rise_pose(p):
    pose = Pose()
    stir = sine(p, 1)
    pose.hips_at = Vector((0.0, 0.0, 0.46 + 0.004 * stir))
    pose.turns["hips"] = turn(pitch=-6.0 + 1.0 * stir, roll=-2.0, yaw=6.0)
    pose.turns["chest"] = turn(pitch=-2.0, roll=2.0, yaw=-8.0)
    pose.turns["neck"] = turn(pitch=8.0)
    pose.turns["head"] = turn(pitch=12.0 + 1.5 * sine(p, 1, 0.1))
    pose.feet["R"] = (Vector((0.12, 0.12, 0.27 + 0.006 * stir)), qz(deg(-6.0)) @ qx(deg(-25.0)))
    pose.feet["L"] = (Vector((-0.1, -0.08, 0.1 - 0.004 * stir)), qz(deg(6.0)) @ qx(deg(-55.0)))
    pose.pole["R"] = Vector((0.2, 1.0, 0.4))
    pose.pole["L"] = Vector((-0.15, 1.0, -0.1))
    for n, s in SIDES.items():
        late = 0.08 if n == "R" else 0.0
        pose.turns[f"upper_arm.{n}"] = turn(pitch=(70.0 if n == "L" else 40.0) + 5.0 * sine(p, 1, late), roll=-s * (42.0 + 3.0 * sine(p, 1, 0.2 + late)))
        pose.turns[f"forearm.{n}"] = turn(pitch=30.0 + 4.0 * sine(p, 1, 0.15 + late))
        pose.turns[f"hand.{n}"] = turn(pitch=-8.0)
        scarf(pose, p, n, s, back=-30.0, flutter=6.0, flap=6.0, beat=2)
    return pose

def jump_fall_pose(p):
    pose = Pose()
    paddle = sine(p, 1)
    pose.hips_at = Vector((0.0, 0.0, 0.45 + 0.005 * paddle))
    pose.turns["hips"] = turn(pitch=2.0 + 1.5 * paddle, roll=1.5 * sine(p, 1, 0.25))
    pose.turns["chest"] = turn(pitch=4.0, roll=-1.5 * sine(p, 1, 0.25))
    pose.turns["neck"] = turn(pitch=-6.0)
    pose.turns["head"] = turn(pitch=-10.0 + 2.0 * sine(p, 1, 0.3))
    for n, s in SIDES.items():
        late = 0.25 if n == "R" else 0.0
        kick = 0.02 * sine(p, 1, 0.1 + late)
        pose.feet[n] = (Vector((s * 0.14, 0.04 + kick, 0.1 - kick)), qz(deg(-8.0 * s)) @ qx(deg(-22.0)))
        pose.pole[n] = Vector((0.45 * s, 1.0, 0.2))
        flap = sine(p, 1, late)
        pose.turns[f"upper_arm.{n}"] = turn(pitch=95.0 + 10.0 * flap, roll=-s * (62.0 + 8.0 * sine(p, 1, 0.2 + late)))
        pose.turns[f"forearm.{n}"] = turn(pitch=25.0 + 10.0 * flap)
        pose.turns[f"hand.{n}"] = turn(pitch=-15.0 + 12.0 * sine(p, 1, 0.3 + late))
        for i in range(3):
            flick = sine(p, 2, 0.2 + 0.08 * i + (0.05 if n == "R" else 0.0))
            pose.turns[f"tail.{n}.{i}"] = cape_turn(i, 
                pitch=(-145.0 if i == 0 else -14.0) + 10.0 * flick,
                roll=-s * (16.0 if i == 0 else 4.0) + 4.0 * sine(p, 3, 0.1 * i),
                yaw=3.0 * flick)
    return pose

def twirl_pose(p):
    pose = Pose()
    stir = sine(p, 1)
    pose.hips_at = Vector((0.0, 0.0, 0.45 + 0.004 * stir))
    pose.turns["hips"] = turn(pitch=2.0, roll=1.0 * stir)
    pose.turns["chest"] = turn(pitch=5.0, roll=-1.5 * stir)
    pose.turns["neck"] = turn(pitch=6.0)
    pose.turns["head"] = turn(pitch=12.0, roll=3.0 * sine(p, 1, 0.2))
    # The legs together, the right ankle crossed over the left's front.
    pose.feet["L"] = (Vector((-0.045, -0.01, 0.1)), qz(deg(4.0)) @ qx(deg(-48.0)))
    pose.feet["R"] = (Vector((0.01, 0.035, 0.15)), qz(deg(-14.0)) @ qx(deg(-40.0)))
    pose.pole["L"] = Vector((-0.2, 1.0, 0.0))
    pose.pole["R"] = Vector((0.1, 1.0, 0.25))
    for n, s in SIDES.items():
        late = 0.1 if n == "R" else 0.0
        pose.turns[f"upper_arm.{n}"] = turn(pitch=8.0 + 4.0 * sine(p, 1, late), roll=-s * (72.0 + 3.0 * sine(p, 2, 0.2 + late)))
        pose.turns[f"forearm.{n}"] = turn(pitch=6.0, yaw=-s * 8.0)
        pose.turns[f"hand.{n}"] = turn(pitch=-4.0, roll=-s * 10.0)
        for i in range(3):
            flick = sine(p, 2, 0.15 + 0.08 * i + (0.05 if n == "R" else 0.0))
            pose.turns[f"tail.{n}.{i}"] = cape_turn(i, 
                pitch=(-80.0 if i == 0 else -10.0) + 8.0 * flick,
                roll=-s * (60.0 if i == 0 else 8.0) + 6.0 * sine(p, 2, 0.1 * i),
                yaw=4.0 * flick)
    return pose

def slide_pose(p):
    pose = Pose()
    wobble = 0.6 * sine(p, 1) + 0.4 * sine(p, 2, 0.15)
    chatter = (0.5 + 0.5 * sine(p, 3, 0.05)) ** 2
    pose.hips_at = Vector((0.01 * wobble, -0.02, 0.35 + 0.006 * wobble))
    # A touch side on, the left leading, leant in over the bent knees.
    pose.turns["hips"] = turn(pitch=-14.0 + 1.5 * wobble, roll=2.0 * wobble, yaw=-22.0)
    pose.turns["chest"] = turn(pitch=-4.0, roll=-3.0 * wobble, yaw=12.0 + 2.0 * sine(p, 1, 0.1))
    pose.turns["neck"] = turn(pitch=8.0, yaw=5.0)
    pose.turns["head"] = turn(pitch=12.0 + 1.5 * sine(p, 2, 0.2), yaw=5.0, roll=-2.0 * wobble)
    # The boots apart, pointed down the fall line, the left ahead.
    pose.feet["L"] = boot_on(Vector((-0.13, 0.1, 0.0)), 0.003 * chatter, -2.0, 8.0)
    pose.feet["R"] = boot_on(Vector((0.13, -0.1, 0.0)), 0.0, 2.0, -6.0)
    pose.pole["L"] = Vector((-0.3, 1.0, 0.1))
    pose.pole["R"] = Vector((0.45, 1.0, 0.1))
    flail = sine(p, 1, 0.1)
    pose.turns["upper_arm.L"] = turn(pitch=40.0 + 6.0 * flail, roll=55.0 + 5.0 * sine(p, 2, 0.2))
    pose.turns["forearm.L"] = turn(pitch=25.0 + 5.0 * flail)
    pose.turns["hand.L"] = turn(pitch=-10.0)
    pose.turns["upper_arm.R"] = turn(pitch=-35.0 - 6.0 * flail, roll=-(58.0 + 5.0 * sine(p, 2, 0.4)))
    pose.turns["forearm.R"] = turn(pitch=30.0 - 5.0 * flail)
    pose.turns["hand.R"] = turn(pitch=-10.0)
    for n, s in SIDES.items():
        scarf(pose, p, n, s, back=80.0, flutter=12.0, flap=10.0, beat=3)
    return pose

def side_flip_clip():
    sprung = move_stage(Vector((0.0, 0.0, 0.45)), (2.0, 0.0, 0.0), 6.0, 14.0,
                        {"L": (Vector((-0.08, 0.0, 0.1)), -45.0, (0.2, 1.0, 0.0)),
                         "R": (Vector((0.08, 0.0, 0.1)), -45.0, (0.2, 1.0, 0.0))},
                        {"L": (165.0, 18.0, 6.0), "R": (165.0, 18.0, 6.0)}, tails=-60.0)
    tucked = move_stage(Vector((0.0, 0.03, 0.5)), (-18.0, 0.0, 0.0), -28.0, -12.0,
                        {"L": (Vector((-0.09, 0.1, 0.33)), -35.0, (0.3, 1.0, 0.6)),
                         "R": (Vector((0.09, 0.1, 0.33)), -35.0, (0.3, 1.0, 0.6))},
                        {"L": (55.0, 14.0, 75.0), "R": (55.0, 14.0, 75.0)}, tails=-20.0)
    opened = move_stage(Vector((0.0, 0.0, 0.45)), (-2.0, 0.0, 0.0), 2.0, -6.0,
                        {"L": (Vector((-0.13, 0.04, 0.08)), -12.0, (0.4, 1.0, 0.2)),
                         "R": (Vector((0.13, 0.04, 0.08)), -12.0, (0.4, 1.0, 0.2))},
                        {"L": (80.0, 70.0, 20.0), "R": (80.0, 70.0, 20.0)}, tails=-120.0)
    return keyed([(0.0, sprung), (0.12, sprung), (0.32, tucked), (0.6, tucked), (0.82, opened), (1.0, opened)])

# ------------------------------------------------------------------ the water
# Afloat in deep water (scripts/pilot_motor.gd swims him, scripts/
# pilot_figure.gd keeps copies of the numbers): the feet (the origin) stand
# SWIM_DRAFT under the water's top, so the head and the shoulders are out of
# it. Both clips are posed from the joints where the rig puts them (the
# shoulders and the hips, `joints`), the limbs reached by IK, so they keep up
# with the body's measures.
#   swim   a doggy paddle, made for SWIM_SPEED m/s, a loop of SWIM_CYCLE s
#          (both mitts): lying forward SWIM_LEAN degrees, the head held up
#          and looking ahead, the mitts paddling in turn in little circles
#          under the chin, reaching forward over the top and pulling down
#          and back, the boots kicking behind, the scarf's tails trailing;
#   tread  treading water, TREAD_LENGTH s: nearly upright, the legs
#          pedalling under him, the mitts sculling out at his sides just
#          under the surface, bobbing with the kicks, glancing about.
SWIM_SPEED = 1.2
SWIM_CYCLE = 0.8
TREAD_LENGTH = 1.6
SWIM_DRAFT = 0.58
SWIM_LEAN = 30.0

def joints(pose):
    """Where `pose` puts the shoulders and the hips' joints (armature space,
    by side), before any reach: its FK, the legs stood anywhere."""
    for n, s in SIDES.items():
        pose.feet.setdefault(n, (Vector((s * 0.1, 0.0, 0.0)), Quaternion()))
        pose.pole.setdefault(n, Vector((0, 1, 0)))
    P, _ = solve(pose)
    shoulders = {n: P[f"upper_arm.{n}"].translation.copy() for n in SIDES}
    hips = {n: (P["hips"] @ (REST["hips"].inverted() @ REST[f"thigh.{n}"])).translation.copy() for n in SIDES}
    return shoulders, hips

# The swim and tread strokes were laid out for arms 0.337 m long; they are
# drawn in to the arms as they are.
SWIM_FIT = (UPPER + FORE) / 0.337


def swim_pose(p):
    """A doggy paddle (see above): `p` 0 at the left mitt's reach over the
    top of its circle."""
    pose = Pose()
    # Surging a little on each pull.
    surge = wave(p, 2, 0.15)
    pose.hips_at = Vector((0.0, -0.02 + 0.006 * surge, HIPS + 0.008 * surge))
    pose.turns["hips"] = turn(pitch=-SWIM_LEAN, roll=2.5 * sine(p), yaw=3.0 * sine(p, 1, 0.1))
    pose.turns["chest"] = turn(pitch=-6.0 - 2.0 * surge, roll=-3.0 * sine(p, 1, 0.05), yaw=-5.0 * sine(p, 1, 0.08))
    # The head held up out of it, looking ahead.
    pose.turns["neck"] = turn(pitch=16.0, yaw=2.0 * sine(p, 1, 0.1))
    pose.turns["head"] = turn(pitch=18.0 + 2.0 * surge, roll=-2.0 * sine(p, 1, 0.12))
    for n, s in SIDES.items():
        scarf(pose, p, n, s, back=25.0, flutter=4.0, flap=5.0)
    shoulders, hips = joints(pose)
    for n, s in SIDES.items():
        q = (p + (0.0 if n == "L" else 0.5)) % 1.0
        a = math.tau * q + math.pi * 0.5
        sh = shoulders[n]
        # A little circle under the chin: forward over the top, down and
        # back under it.
        middle = sh + Vector((-s * 0.04, 0.19, -0.12)) * SWIM_FIT
        wrist = middle + Vector((0.0, -0.09 * math.cos(a), 0.06 * math.sin(a))) * SWIM_FIT
        pose.hands[n] = (wrist, Vector((0.9 * s, -0.3, -0.6)), 1.0)
        pose.turns[f"hand.{n}"] = turn(pitch=-35.0 - 20.0 * math.sin(a), roll=-s * 10.0)
        # The boots kicking behind, each against its own side's mitt.
        k = math.tau * q
        ankle = hips[n] + Vector((s * 0.02, -0.22 - 0.03 * math.sin(k), -0.24 + 0.06 * math.cos(k)))
        pose.feet[n] = (ankle, qz(deg(-6.0 * s)) @ qx(deg(-55.0 + 12.0 * math.sin(k))))
        pose.pole[n] = Vector((0.15 * s, 1.0, -0.2))
    return pose

def tread_pose(p):
    """Treading water (see above): two kicks of each leg a loop."""
    pose = Pose()
    bob = wave(p, 4, 0.1)
    pose.hips_at = Vector((0.004 * sine(p, 2), 0.0, HIPS + 0.01 * bob))
    pose.turns["hips"] = turn(pitch=-9.0 + 1.5 * bob, roll=2.0 * sine(p, 2, 0.1))
    pose.turns["chest"] = turn(pitch=-3.0 - 1.5 * bob, roll=-1.5 * sine(p, 2, 0.15))
    look = 14.0 * sine(p, 1, 0.1)
    pose.turns["neck"] = turn(pitch=5.0, yaw=0.4 * look)
    pose.turns["head"] = turn(pitch=6.0 + 1.5 * bob, yaw=0.6 * look, roll=-2.0 * sine(p, 1, 0.3))
    for n, s in SIDES.items():
        scarf(pose, p, n, s, back=10.0, flutter=4.0, flap=4.0, beat=4)
    shoulders, hips = joints(pose)
    for n, s in SIDES.items():
        q = (p + (0.0 if n == "L" else 0.25)) % 1.0
        # Pedalling: each ankle round a little upright circle under its hip.
        k = math.tau * 2.0 * (p + (0.0 if n == "L" else 0.25))
        ankle = hips[n] + Vector((s * 0.03, 0.03 + 0.07 * math.cos(k), -0.3 + 0.06 * math.sin(k)))
        pose.feet[n] = (ankle, qz(deg(-8.0 * s)) @ qx(deg(-35.0 + 10.0 * math.sin(k))))
        pose.pole[n] = Vector((0.25 * s, 1.0, 0.1))
        # Sculling: the mitts swept in and out at his sides under the
        # water's top, palms tipping each way.
        c = math.tau * 2.0 * q
        sh = shoulders[n]
        wrist = sh + Vector((s * (0.15 + 0.06 * math.cos(c)), 0.13 + 0.03 * math.sin(2.0 * c), -0.17)) * SWIM_FIT
        pose.hands[n] = (wrist, Vector((1.0 * s, -0.2, -0.4)), 1.0)
        pose.turns[f"hand.{n}"] = turn(pitch=-10.0, roll=s * 18.0 * math.sin(c))
    return pose

# ================================================================== keying
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"

def bake(name, length, pose_at):
    frames = round(length * FPS)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    worst, worst_at = 0.0, 0
    arms, arms_at = 0.0, 0
    last = {}
    for f in range(frames + 1):
        ARM_REACH[0] = 0.0
        P, reach = solve(pose_at(f / frames))
        if reach > worst:
            worst, worst_at = reach, f
        if ARM_REACH[0] > arms:
            arms, arms_at = ARM_REACH[0], f
        B = basis(P)
        for pb in rig.pose.bones:
            loc, rot, _ = B[pb.name].decompose()
            # Keep each quaternion on the same side as the last, so nothing spins.
            if pb.name in last and last[pb.name].dot(rot) < 0:
                rot.negate()
            last[pb.name] = rot
            pb.location = loc
            pb.rotation_quaternion = rot
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
    action.frame_range = (0, frames)
    rig.animation_data.nla_tracks.new().strips.new(name, 0, action)
    rig.animation_data.action = None
    print(f"PILOT_CLIP {name} frames={frames} seconds={frames / FPS:.3f} worst_reach={worst:.3f} at frame {worst_at}"
          + (f", the arms' {arms:.3f} at frame {arms_at}" if arms else ""))

# The cycles must be whole frames: their lengths are what is baked.
for value in (WALK_CYCLE, RUN_CYCLE, SKID_LENGTH, HANG_LENGTH, SHIMMY_CYCLE, CLIMB_LENGTH,
              CROUCH_LENGTH, LONG_LENGTH, WALL_LENGTH, KICK_LENGTH, PUMP_LENGTH):
    assert abs(round(value * FPS) - value * FPS) < 1e-6, "a cycle must be whole frames"
bake("idle", IDLE_LENGTH, idle_pose)
bake("walk", WALK_CYCLE, walk_pose)
bake("run", RUN_CYCLE, run_pose)
bake("skid", SKID_LENGTH, skid_pose)
bake("hang", HANG_LENGTH, hang_pose)
bake("shimmy_left", SHIMMY_CYCLE, lambda p: shimmy_pose(p, -1.0))
bake("shimmy_right", SHIMMY_CYCLE, lambda p: shimmy_pose(p, 1.0))
bake("climb", CLIMB_LENGTH, climb_clip())
bake("crouch", CROUCH_LENGTH, crouch_pose)
bake("long_jump", LONG_LENGTH, long_jump_pose)
bake("wall_slide", WALL_LENGTH, wall_slide_pose)
bake("wall_kick", KICK_LENGTH, wall_kick_clip())
bake("pump", PUMP_LENGTH, pump_clip())
for value in (JUMP_LENGTH, TWIRL_LENGTH, SLIDE_LENGTH, FLIP_LENGTH):
    assert abs(round(value * FPS) - value * FPS) < 1e-6, "a cycle must be whole frames"
bake("jump_rise", JUMP_LENGTH, jump_rise_pose)
bake("jump_fall", JUMP_LENGTH, jump_fall_pose)
bake("twirl", TWIRL_LENGTH, twirl_pose)
bake("slide", SLIDE_LENGTH, slide_pose)
bake("side_flip", FLIP_LENGTH, side_flip_clip())
for value in (SWIM_CYCLE, TREAD_LENGTH):
    assert abs(round(value * FPS) - value * FPS) < 1e-6, "a cycle must be whole frames"
bake("swim", SWIM_CYCLE, swim_pose)
bake("tread", TREAD_LENGTH, tread_pose)
# How far out of the water the shoulders and the chin stand, afloat.
for clip, at in (("swim", swim_pose), ("tread", tread_pose)):
    P, _ = solve(at(0.0))
    top = min(P[f"upper_arm.{n}"].translation.z for n in SIDES)
    chin = P["head"].translation.z
    print(f"PILOT_AFLOAT {clip} shoulders {top - SWIM_DRAFT:+.3f} m, head's base {chin - SWIM_DRAFT:+.3f} m over the water")
for pb in rig.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_quaternion = (1, 0, 0, 0)

# The ledge's measures, for pilot_preview.py's block (not exported).
for key in ("HANG_DROP", "HANG_OUT", "CLIMB_IN", "WALL_GAP"):
    rig[key] = globals()[key]

# ================================================================== save, export
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = rig
GLB.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
    export_apply=False, export_animations=True, export_animation_mode="ACTIONS",
    export_force_sampling=True, export_frame_step=1, export_materials="EXPORT",
    export_normals=True, export_extras=False, export_def_bones=False)
print("PILOT_EXPORTED", GLB)
