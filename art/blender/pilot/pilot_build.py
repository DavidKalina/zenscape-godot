"""Build the pilot on foot: one of the sky folk, rigged and animated, for the
third-person walker (scripts/pilot_figure.gd).

The body is the islanders' own (scripts/islander_figure.gd, the parts from
scripts/person_kit.gd), part for part and at the pilot's SCALE of them: the
big head in its leather cap with ear flaps and brass goggles, a nose, the
jacket with its sheepskin collar and shoulder pads, the scarf wound at the
neck with two tails behind, mittened hands, canvas trousers belted with
brass, and pebble boots on short legs. Every part is where person_kit.gd puts
it and as big, but cut with more facets than the islanders' (flat shaded
still, faceted solids, but rounder: rings of 12-16 sides with more rings
between, limbs of 10 rounded off at the joints, balls for the kit's gems), as
the hero seen up close. Each part rides one bone (weight 1), so nothing
stretches.

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
        bent near square and pumping against the legs (mitts up to the
        chest in front, back past the hip), the scarf streaming;
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
| Pilot                  | the skinned mesh; surfaces named after PersonKit.outfit keys |
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
RUN_SPEED = 4.0        # m/s, scripts/pilot_motor.gd RUN
RUN_CYCLE = 0.3333333333333333
RUN_STANCE = 0.3
IDLE_LENGTH = 18.0
SKID_LENGTH = 0.35
SKID_DROP = 0.055      # m the hips drop skidding
# The ledge (scripts/pilot_motor.gd keeps copies): hanging, the lip's edge
# stands HANG_OUT ahead of the feet (the origin) and HANG_DROP over them; the
# climb ends standing CLIMB_IN in from the edge, on the lip's height.
HANG_DROP = 1.0
HANG_OUT = 0.22
HANG_LENGTH = 4.0
SHIMMY_SPEED = 0.7     # m/s along the lip
SHIMMY_CYCLE = 0.5     # seconds a full cycle, both hands
SHIMMY_STANCE = 0.57   # the share of the cycle a hand grips
CLIMB_LENGTH = 0.9
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
HIPS_BUILD = 0.17      # the islander's hips, standing
NECK = 0.15
SHOULDER = (0.085, 0.125, 0.0)
KNOT = (0.0, 0.152, 0.06)
HIP_X = 0.042
LEG = (0.09, 0.088)
ARM = (0.085, 0.08)
ANKLE_BUILD = 0.024
TAIL_LENGTH = 0.036
# In rest the legs hang straight, so the hips stand higher than they ever
# do in play.
REST_HIPS = LEG[0] + LEG[1] + ANKLE_BUILD
TORSO_UP = 0.025
HEAD_UP = 0.035
HEAD_SIZE = 0.9

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
HEEL = -0.05
BALL = 0.068

# ------------------------------------------------------------------ colours
# PersonKit's palette; the game swaps in its own materials by these names.
PALETTE = {
    "skin": "e8c39e", "jacket": "4a2a1e", "leather": "5e3522", "strap": "6b3b28",
    "brass": "d6ad62", "lens": "3b6370", "fleece": "e6d8bb", "trousers": "6b6250",
    "boots": "3a2a22", "scarf": "d9573a",
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
    bsdf = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.3 if key in ("brass", "lens") else 0.8
        bsdf.inputs["Metallic"].default_value = 1.0 if key == "brass" else 0.0
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
    d = Vector((0.16 * s, -1.0, 0.0)).normalized()
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
    at = torso_at(KNOT[0] + 0.011 * s, KNOT[1] - 0.004, KNOT[2])
    parent = "chest"
    for i in range(3):
        BONES[f"tail.{n}.{i}"] = (g(at), g(at - Vector((0, TAIL_LENGTH, 0))), parent)
        parent = f"tail.{n}.{i}"
        at = at - Vector((0, TAIL_LENGTH, 0))
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
# person_kit.gd's shapes in the game's frame, at the same sizes and places,
# cut with more facets: its rings with more sides and more rings between
# (along a smooth curve through its own), its frusta rounder, its
# six-pointed gems as round solids. A polygon of more sides stands wider
# between its corners, so each radius is trimmed to keep the part's mean
# width (it reads as big as it did); a gem's ball, sized the same way, is
# 0.83 of its points.
def keep_width(r, was, sides):
    """A radius drawn at `was` sides, for `sides`, as wide on the mean."""
    return r * (was * math.sin(math.pi / was)) / (sides * math.sin(math.pi / sides))

GEM_BALL = 0.83

def smooth_rings(rings, between, apex=False):
    """`between` more rings between each pair, on a Catmull-Rom curve
    through them (the profile rounds out, its ends stay put). `apex`: the
    last ring is a point on the axis, and the curve meets it square, a
    round dome."""
    pts = [Vector(r) for r in rings]
    out = []
    for i in range(len(pts) - 1):
        p0, p1, p2 = pts[max(i - 1, 0)], pts[i], pts[i + 1]
        if i + 2 < len(pts):
            p3 = pts[i + 2]
        elif apex:
            p3 = Vector((p1.x, -p1.y, -p1.z))
        else:
            p3 = p2
        for k in range(between + 1):
            t = k / (between + 1)
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-1])
    return [(v.x, max(v.y, 0.0), max(v.z, 0.0)) for v in out]

def ring_hull(rings, sides, was=None, between=0, apex=False):
    """FacetMesh.hull: rings (along, radius x, radius y) round local Z;
    drawn at `was` sides in person_kit.gd."""
    k = keep_width(1.0, was, sides) if was else 1.0
    pts = []
    for z, rx, ry in smooth_rings(rings, between, apex):
        for i in range(sides):
            a = math.tau * (i + 0.5) / sides
            pts.append(Vector((math.cos(a) * rx * k, math.sin(a) * ry * k, z)))
        pts.append(Vector((0, 0, z)))
    return pts

def frustum(bottom, top, height, sides, was=None):
    """GliderFigure._frustum, along Y, centred; drawn at `was` sides."""
    k = keep_width(1.0, was, sides) if was else 1.0
    pts = []
    for i in range(sides):
        a = math.tau * i / sides
        pts.append(Vector((math.cos(a) * bottom * k, -height * 0.5, math.sin(a) * bottom * k)))
        pts.append(Vector((math.cos(a) * top * k, height * 0.5, math.sin(a) * top * k)))
    return pts

def limb(near, far, length, sides, was):
    """A limb's frustum, unit tall along Y (for bone_between), its ends
    rounded off past the joints (into the next part) so a bent knee or
    elbow stays whole; drawn at `was` sides."""
    near, far = keep_width(near, was, sides), keep_width(far, was, sides)
    rings = [(-0.5 - 0.42 * near / length, 0.55 * near), (-0.5 - 0.2 * near / length, 0.9 * near),
             (-0.5, near), (0.5, far), (0.5 + 0.2 * far / length, 0.9 * far), (0.5 + 0.42 * far / length, 0.55 * far)]
    pts = []
    for y, r in rings:
        for i in range(sides):
            a = math.tau * i / sides
            pts.append(Vector((math.cos(a) * r, y, math.sin(a) * r)))
    return pts

def ball(r, sides=12, bands=6, up=1.15, front=1.1):
    """A round solid in a gem's place: GliderFigure._gem(r) as a ball as
    wide on the mean, `up` and `front` stretching its top and front halves
    as the gem's points are."""
    r *= GEM_BALL
    pts = [Vector((0, r * up, 0)), Vector((0, -r, 0))]
    for b in range(1, bands):
        lat = math.pi * (b / bands - 0.5)
        y = math.sin(lat) * r * (up if lat > 0 else 1.0)
        for i in range(sides):
            a = math.tau * (i + 0.5 * (b % 2)) / sides
            z = math.sin(a) * math.cos(lat) * r
            pts.append(Vector((math.cos(a) * math.cos(lat) * r, y, z * (front if z < 0 else 1.0))))
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

parts = []

def part(points, mat, bone, m):
    bm = bmesh.new()
    for p in points:
        q = m @ p
        bm.verts.new(G(q.x, q.y, q.z))
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    me = bpy.data.meshes.new(bone)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new(bone, me)
    scene.collection.objects.link(ob)
    ob.data.materials.append(materials[mat])
    ob.vertex_groups.new(name=bone).add(range(len(me.vertices)), 1.0, "REPLACE")
    parts.append(ob)

def aligned(at, y_dir):
    """A frame at `at` whose Y runs along `y_dir`, its X the figure's right."""
    y = y_dir.normalized()
    z = Vector((1, 0, 0)).cross(y).normalized()
    m = Matrix((y.cross(z), y, z)).transposed().to_4x4()
    m.translation = at
    return m

UP = (-math.pi * 0.5, 0, 0)
hips = place((0, REST_HIPS, 0))
# The hips in canvas, belted, a brass buckle.
part(ring_hull([(-0.03, 0.06, 0.045), (0.0, 0.072, 0.052), (0.035, 0.07, 0.055)], 16, was=8, between=1), "trousers", "hips", hips @ place(turn=UP))
part(frustum(0.075, 0.075, 0.014, 16, was=8), "strap", "hips", hips @ place((0, 0.03, 0), size=(1, 1, 0.78)))
part(ball(0.011, 8, 4), "brass", "hips", hips @ place((0, 0.03, -0.058), size=(1.3, 1, 0.6)))
# The chest: the jacket tapering to the shoulders, the collar, the scarf.
torso = hips @ place((0, TORSO_UP, 0))
part(ring_hull([(0.0, 0.07, 0.055), (0.08, 0.085, 0.062), (0.125, 0.092, 0.058), (0.152, 0.05, 0.04)], 16, was=8, between=1), "jacket", "chest", torso @ place(turn=UP))
for s in (L, R):
    part(ball(0.036, 12, 6), "jacket", "chest", torso @ place((SHOULDER[0] * s, SHOULDER[1] + 0.005, 0), size=(1.05, 0.82, 1.0)))
part(frustum(0.07, 0.056, 0.03, 16, was=10), "fleece", "chest", torso @ place((0, NECK - 0.012, 0.006), size=(1, 1, 0.92)))
part(ball(0.05, 16, 5), "scarf", "chest", torso @ place((0, NECK, 0), size=(1.3, 0.55, 1.2)))
part(ball(0.024, 10, 5), "scarf", "chest", torso @ place((0, 0.152, 0.05)))
# The neck, and the head in its cap.
neck = torso @ place((0, NECK, 0))
part(frustum(0.026, 0.023, 0.05, 12, was=6), "skin", "neck", neck @ place((0, 0.02, 0)))
head = neck @ place((0, HEAD_UP, 0), size=(HEAD_SIZE,) * 3)
mid = Vector((0, 0.055, 0))
part(ring_hull([(-0.08, 0.03, 0.03), (-0.05, 0.064, 0.064), (0.0, 0.075, 0.075), (0.045, 0.066, 0.068), (0.078, 0.03, 0.034)], 16, was=8, between=1), "skin", "head", head @ place(mid, UP))
part(ring_hull([(-0.005, 0.081, 0.083), (0.04, 0.073, 0.076), (0.072, 0.045, 0.048), (0.09, 0.0, 0.0)], 16, was=8, between=2, apex=True), "leather", "head", head @ place(mid + Vector((0, 0.012, 0.012)), UP))
for s in (L, R):
    part(ball(0.03, 10, 5), "leather", "head", head @ place(mid + Vector((0.078 * s, -0.02, 0.007)), size=(0.45, 1.3, 0.9)))
part(frustum(0.085, 0.085, 0.016, 16, was=10), "strap", "head", head @ place(mid + Vector((0, 0.012, 0.01))))
for s in (L, R):
    turn = (math.pi * 0.5, 0.35 * s, 0)
    part(frustum(0.025, 0.025, 0.014, 14, was=8), "brass", "head", head @ place(mid + Vector((0.03 * s, 0.012, -0.073)), turn))
    part(frustum(0.019, 0.019, 0.016, 14, was=8), "lens", "head", head @ place(mid + Vector((0.031 * s, 0.012, -0.076)), turn))
part(ball(0.011, 8, 4), "skin", "head", head @ place(mid + Vector((0, -0.012, -0.074)), size=(0.8, 1, 1.2)))
# Arms in the jacket, mittened hands (a thumb forward); legs in canvas,
# pebble boots with a flat to the sole.
BOOT = [(-0.055, 0.014, 0.01), (-0.035, 0.028, 0.02), (0.015, 0.027, 0.024), (0.03, 0.02, 0.02)]
def boot():
    return [Vector((p.x, max(p.y * 1.1, -ANKLE_BUILD), p.z)) if p.y < 0 else p
            for p in ring_hull(BOOT, 12, was=6, between=1)]
for n, s in SIDES.items():
    sh, el, wr = arm_joints(s)
    part(limb(0.02, 0.017, ARM[0], 10, was=5), "jacket", f"upper_arm.{n}", bone_between(sh, el))
    part(limb(0.017, 0.015, ARM[1], 10, was=5), "jacket", f"forearm.{n}", bone_between(el, wr))
    hand = aligned(wr, el - wr)
    part(ball(0.021, 10, 6, up=1.1, front=1.0), "leather", f"hand.{n}", hand @ place((0, -0.003, 0), size=(0.95, 1.05, 1.0)))
    part(ball(0.0085, 8, 4), "leather", f"hand.{n}", hand @ place((-0.007 * s, -0.001, -0.013)))
    hp, kn, an = leg_joints(s)
    part(limb(0.03, 0.026, LEG[0], 10, was=5), "trousers", f"thigh.{n}", bone_between(hp, kn))
    part(limb(0.025, 0.021, LEG[1], 10, was=5), "trousers", f"shin.{n}", bone_between(kn, an))
    part(boot(), "boots", f"foot.{n}", place(an))
    # The scarf's tails, hinged strips from the knot.
    at = place(torso_at(KNOT[0] + 0.011 * s, KNOT[1] - 0.004, KNOT[2]))
    for i in range(3):
        part(frustum(0.017 - i * 0.002, 0.015 - i * 0.002, TAIL_LENGTH, 8, was=4), "scarf", f"tail.{n}.{i}", at @ place((0, -TAIL_LENGTH * 0.5, 0), size=(1, 1, 0.3)))
        at = at @ place((0, -TAIL_LENGTH, 0))

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

def scarf(pose, p, n, s, back, flutter, flap, beat=2):
    """The scarf's tails: blown back `back` degrees, fluttering with the
    steps, each strip a beat behind the one above."""
    for i in range(3):
        lag = 0.08 * (i + 1) + (0.035 if n == "R" else 0.0)
        pose.turns[f"tail.{n}.{i}"] = turn(
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
    pose.hips_at = Vector((-0.016 * sine(p, 1, 0.02), 0.005 * wave(p, 2, 0.12), HIPS + 0.006 + 0.018 * bounce))
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
        pose.feet[n] = boot_on(Vector((s * 0.105, y, 0.0)), lift, pitch, -7.0 * s)
        pose.pole[n] = qz(deg(-6.0 * s)) @ Vector((0, 1, 0.1))
        # Against its leg, a small swing, the forearm and the mitt trailing
        # it; flung out a touch as the body comes down on each step.
        a = (q + 0.5) % 1.0
        pose.turns[f"upper_arm.{n}"] = turn(pitch=2.0 + 14.0 * wave(a, 1, 0.07), roll=-s * (4.5 + 1.5 * wave(p, 2, 0.14)))
        pose.turns[f"forearm.{n}"] = turn(pitch=10.0 + 7.0 * (0.5 + 0.5 * wave(a, 1, 0.17)))
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
    head steady and looking ahead; the arms bent near square at the elbow,
    pumping against the legs, the mitt up in front of the chest on the
    swing forward and back past the hip on the swing back."""
    pose = Pose()
    # Lowest over the planted boot, highest in the air between steps.
    bob = 0.03 * wave(p, 2, RUN_STANCE * 0.5 + 0.25)
    pose.hips_at = Vector((-0.008 * sine(p, 1, 0.05), 0.012 * wave(p, 2, 0.2), HIPS + 0.012 + bob))
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
        pose.feet[n] = boot_on(Vector((s * 0.09, y, 0.0)), lift, pitch, -5.0 * s)
        pose.pole[n] = qz(deg(-4.0 * s)) @ Vector((0, 1, 0.0))
        # The arm pumps against its leg, close in by the body, the elbow
        # bent near square (closing a little on the swing forward, opening
        # on the swing back), the mitt coming up in front of the chest and
        # in a little, then back past the hip.
        a = (q + 0.5) % 1.0
        swing = wave(a, 1, 0.06)
        pose.turns[f"upper_arm.{n}"] = turn(pitch=-6.0 + 52.0 * swing, roll=-s * (10.0 - 4.0 * swing + 2.0 * wave(p, 2, 0.22)), yaw=-s * 10.0 * (0.5 + 0.5 * swing))
        pose.turns[f"forearm.{n}"] = turn(pitch=90.0 + 12.0 * wave(a, 1, 0.1), yaw=s * 6.0)
        pose.turns[f"hand.{n}"] = turn(pitch=-6.0 + 6.0 * wave(a, 1, 0.2))
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
    pose.feet["L"] = boot_on(Vector((-0.1, 0.2, 0.0)), 0.004 * chatter, 30.0 + 4.0 * shake, 14.0)
    pose.feet["R"] = boot_on(Vector((0.085, -0.08, 0.0)), 0.0, -12.0 + 2.0 * shake, -18.0)
    pose.pole["L"] = Vector((-0.1, 1.0, 0.5))
    pose.pole["R"] = Vector((0.2, 1.0, 0.0))
    for n, s in SIDES.items():
        flail = sine(p, 2, 0.1 + (0.12 if n == "R" else 0.0))
        pose.turns[f"upper_arm.{n}"] = turn(pitch=-70.0 + 8.0 * flail, roll=-s * (55.0 + 5.0 * sine(p, 3, 0.2)))
        pose.turns[f"forearm.{n}"] = turn(pitch=25.0 + 8.0 * flail)
        pose.turns[f"hand.{n}"] = turn(pitch=-10.0 + 14.0 * sine(p, 3, 0.3))
        for i in range(3):
            flick = sine(p, 2, 0.2 + 0.08 * i + (0.05 if n == "R" else 0.0))
            pose.turns[f"tail.{n}.{i}"] = turn(
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
    pose.feet["L"] = boot_on(Vector((-0.11, 0.02, 0.0)), 0.0, rock - 4.0 * max(w, 0.0) ** 2, 10.0)
    pose.feet["R"] = boot_on(Vector((0.11 + step[0], -0.015 + step[1], 0.0)), step[2],
                             rock - 4.0 * max(-w, 0.0) ** 2 - 12.0 * step[2] / 0.035, IDLE_STEP_TURN(p))
    for n, s in SIDES.items():
        pose.pole[n] = qz(deg(-12.0 * s)) @ Vector((0, 1, 0.0))
        # Hanging loose, swinging a little after the hips as the weight
        # moves, forward as he rocks back, up with the sigh.
        pose.turns[f"upper_arm.{n}"] = turn(pitch=2.0 + 1.0 * breath + 0.8 * rock + 2.0 * sigh,
                                            roll=-s * (4.0 + 1.0 * breath + 3.5 * sigh) + 4.0 * (w - w_late))
        pose.turns[f"forearm.{n}"] = turn(pitch=12.0 + 2.0 * breath + 1.5 * sine(p, 2, 0.14 + 0.1 * (s > 0)) + 3.0 * sigh)
        pose.turns[f"hand.{n}"] = turn(pitch=5.0 + 2.0 * sine(p, 3, 0.2 + 0.07 * (s > 0)))
        for i in range(3):
            lag = 0.012 * (i + 1) + (0.008 if n == "R" else 0.0)
            breeze = IDLE_BREEZE(p - lag)
            stir = breeze * (2.5 * sine(p, 9, lag) + 1.5 * sine(p, 16, lag * 1.3) + 1.5 * sine(p, 5, lag))
            pose.turns[f"tail.{n}.{i}"] = turn(pitch=-(10.0 if i == 0 else 3.0) + stir,
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
    ankle = hips + Vector((s * (0.075 + out), 0.03 + kick, -0.365))
    pose.feet[n] = (ankle, qz(deg(-6.0 * s)) @ qx(deg(toe)))
    pose.pole[n] = Vector((0.15 * s, 1.0, 0.1))

HANG_HIPS = Vector((0.0, HANG_OUT - 0.17, HANG_DROP - 0.575))

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
                         {"L": (H + Vector((-0.1, 0.03, -0.32)), -20.0, WIDE_KNEE), "R": (H + Vector((0.1, 0.04, -0.32)), -20.0, WIDE_KNEE)},
                         (0.9, -0.5, -0.6))
    pulled = climb_stage(Vector((0.0, e - 0.19, t - 0.3)), -4.0, -6.0, 22.0,
                         {"L": (Vector((-0.1, e - 0.17, t - 0.64)), -25.0, WIDE_KNEE), "R": (Vector((0.11, e - 0.15, t - 0.58)), -15.0, WIDE_KNEE)},
                         (0.7, -0.9, -0.9))
    pressed = climb_stage(Vector((0.0, e - 0.16, t - 0.06)), -16.0, -30.0, 14.0,
                          {"L": (Vector((-0.1, e - 0.15, t - 0.38)), -25.0, WIDE_KNEE), "R": (Vector((0.11, e - 0.14, t - 0.34)), -15.0, WIDE_KNEE)},
                          (0.5, -1.0, 0.7))
    swung = climb_stage(Vector((0.0, e - 0.12, t + 0.0)), -22.0, -30.0, 12.0,
                        {"L": (Vector((-0.1, e - 0.15, t - 0.36)), -25.0, WIDE_KNEE), "R": (Vector((0.11, e - 0.1, t + 0.1)), 10.0, HIGH_KNEE)},
                        (0.5, -1.0, 0.8))
    planted = climb_stage(Vector((0.02, e - 0.02, t + 0.06)), -24.0, -26.0, 10.0,
                          {"L": (Vector((-0.1, e - 0.14, t - 0.3)), -25.0, WIDE_KNEE), "R": (right, 0.0, HIGH_KNEE)},
                          (0.5, -1.0, 0.8))
    drawn = climb_stage(Vector((0.04, e + 0.04, t + 0.13)), -16.0, -16.0, 8.0,
                        {"L": (Vector((-0.1, e - 0.05, t + 0.09)), 5.0, HIGH_KNEE), "R": (right, 0.0, HIGH_KNEE)},
                        (0.5, -1.0, 0.6), hands=0.7, hand_lift=0.03)
    risen = climb_stage(Vector((0.03, e + 0.22, t + 0.3)), -8.0, -8.0, 4.0,
                        {"L": (left + Vector((0.0, -0.06, 0.05)), -6.0, FORWARD_KNEE), "R": (right, 0.0, FORWARD_KNEE)},
                        (0.6, -1.0, 0.0), hands=0.3, hand_lift=0.1, hand_pitch=0.0, tails=12.0)
    # The right boot plants as it stands at the end, and stays.
    for st in (planted, drawn, risen):
        st.feet["R"] = stand.feet["R"]
    return keyed([(0.0, hang_pose(0.0)), (0.12, gather), (0.34, pulled), (0.5, pressed), (0.58, swung),
                  (0.66, planted), (0.75, drawn), (0.85, risen), (1.0, stand)])

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
for value in (WALK_CYCLE, RUN_CYCLE, SKID_LENGTH, HANG_LENGTH, SHIMMY_CYCLE, CLIMB_LENGTH):
    assert abs(round(value * FPS) - value * FPS) < 1e-6, "a cycle must be whole frames"
bake("idle", IDLE_LENGTH, idle_pose)
bake("walk", WALK_CYCLE, walk_pose)
bake("run", RUN_CYCLE, run_pose)
bake("skid", SKID_LENGTH, skid_pose)
bake("hang", HANG_LENGTH, hang_pose)
bake("shimmy_left", SHIMMY_CYCLE, lambda p: shimmy_pose(p, -1.0))
bake("shimmy_right", SHIMMY_CYCLE, lambda p: shimmy_pose(p, 1.0))
bake("climb", CLIMB_LENGTH, climb_clip())
for pb in rig.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_quaternion = (1, 0, 0, 0)

# The ledge's measures, for pilot_preview.py's block (not exported).
for key in ("HANG_DROP", "HANG_OUT", "CLIMB_IN"):
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
