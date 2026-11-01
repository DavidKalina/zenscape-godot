"""Build the headless body (scripts/enemies/headless_body.gd): the inhaler head's lost
stone body, rigged and animated.

The figure is the head's stone (art/blender/inhaler_head/inhaler_head_build.py):
the same rounded masonry blocks, laid in courses with their joints showing,
weathered by the same low noise and broken corners, shaded smooth. A hulking
Olmec figure: a pelvis course under a belt of five blocks and a hanging
loincloth slab, a round belly in two courses, a broad chest with a pectoral
plaque (the head's band boss again), a shoulder slab, a short neck stump cut
raw on top, boulder shoulders, heavy forearms with a bracelet each, big
square hands with four chunky fingers and a thumb, thick legs and slab feet.
Every block rides one bone (weight 1): stone does not bend.

The proportions are round 2's (headless_body.gd `_size`, at its default
knobs and `head_size` 3, so HH = 3 x 1.12 m): legs 0.75 HH, torso 1.2 HH,
the neck's cut at 1.95 HH, breadth 1.3 HH, depth 0.72 HH, the shoulders'
pivots where the greybox had them. The head (3.36 m in the game) sits on the
stump's cut at SEAT.

Rig (bones, Blender +Y forward, +Z up; the game's -Z front, +X right):
  root                                 not deforming; its scale is the squash
  hips  spine  chest  neck             the trunk; neck carries the stump
  upper_arm forearm hand fingers thumb  (.L/.R)
  thigh shin foot                      (.L/.R)
Every bone's local X is the figure's right in rest (as the pilot's), so a
positive turn about X swings a hanging limb forward and tips an upright one
back.

The clips (pose to pose: key poses with eased spans, holds, overshoots, the
arms and the stump trailing the trunk a few frames; legs and, where they
grip, hands by two-bone IK; baked on every frame). The game seeks every clip
itself (headless_body_look.gd), so a clip's length is only its span:
  idle         loop: breathing, a weight shift, the fingers flexing
  listen       once, LISTEN s (the `listen` knob; round 4): no gesture:
               a breath out, settled still and held, then "heard it": the
               stump up, the fists closed
  turn_*       once, STEP s (round 4): one step of a turn on the spot
               (open: the foot on the turn's side steps out; close: the
               other comes round), the game turning the root
  turn_45/90/180_l/r  once (olmec-turn): a whole turn on the spot, the
               root yawed through it (the game reads the yaw and keeps it
               out of the pose), the feet stepping round on the ground
               (their section; TURN_PLANS)
  feel         once, FEEL s (round 4): a hand laid flat on the wall before
               a climb, slid up, a nod
  walk         loop over two steps of WALK_STEP m (the phase from distance)
  stomp        loop, STOMP_LEN s over two steps of STOMP_STEP m: the stomper's
               walk at 250 m, a sink and a hold on each plant
  stride       loop over two steps of STRIDE_STEP m: homing, arms out for it
  hunt_stride  loop over two steps of STRIDE_STEP m: whole, hunting: upright,
               chest up, arms hung heavy at his sides, a held drop each step
  shoulder_run loop over two steps of RUN_STEP m (Olmec boss): whole, hunting,
               the right shoulder leading, that arm tucked, the far one pumping
  charge_tell  once, CHARGE_TELL s (the boss's charge): planted, the shoulder
               dropped, the back foot scraping twice, a held coiled beat
  charge_run   loop over two steps of CHARGE_STEP m: the shoulder run lower,
               harder and longer
  charge_skid  once, CHARGE_SKID s: missed, dug in and slid, pitched on, a
               hand down, held heaving, up
  charge_stagger once, CHARGE_STAGGER s: stopped short, jammed, rocked back
               two steps, dazed, squared
  climb        loop over two hand moves, CLIMB_RISE m up: hand over hand,
               the feet pushing on the wall CLIMB_WALL m ahead of the middle
  haul         loop: both hands on the lip (the game pins them), heaving
  spawn_haul   loop: the same from a cliff spawn, wilder
  mantle       once, MANTLE s: the press, a knee over, up, the stomp
  windup       once, WINDUP s: a rise, the deep crouch with arms back, the coil
  jump_air     once over a jump's flight: stretch, tuck, legs down to land
  drop_air     once over a drop's flight: fists clasped overhead, a plunge
  land         once, LAND s: the squash and rebound, the recovery
  drop_land    once, LAND s: a fist driven into the ground, a knee down
  reach        once, SETTLE s: gathers, arms up for the head, guides it down
  triumph      once, TRIUMPH s: a crouch, arms flung up, the fists down
  scope_lift   once, SCOPE_LIFT s (Olmec periscope round 1): his own head
               lifted off the stump and heaved up overhead in both hands
  scope_look   loop, SCOPE_LOOK s: held up there, straining a little
  scope_lower  once, SCOPE_LOWER s: lowered carefully, seated, let go
  teeter_catch, teeter (loop), teeter_back, topple, rim_leap, rim_land,
  back_hit     the knock-off (Olmec boss): thrown to the rim, windmilling on
               his toes, back from it or over it head first, the leap back
               up and the heavy landing, the hit in the back (their section;
               the edge clips tip the whole figure about the toes, `tp`)
The phase-driven loops start on their first contact (walk and stride: the
left foot down; climb: the left hand on the wall).

    python tools/blender.py run art/blender/headless_body/headless_body_build.py -- [--out=DIR] [--blend] [--no-bake] [--render=DIR] [--clips=a,b]

Writes assets/models/headless_body.glb (or into DIR), printing BODY_TRIS
and each clip; --blend also saves art/blender/headless_body/headless_body.blend;
--render writes workbench stills into DIR (the rest pose from four sides and
each clip in frames, --clips= picks which).
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector, noise

V = Vector
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ROOT / "assets/models"
SAVE_BLEND = False
BAKE = True
RENDER = ""
ONLY = []
for a in _args:
    if a.startswith("--out="): OUT = Path(a.split("=", 1)[1])
    elif a == "--blend": SAVE_BLEND = True
    elif a == "--no-bake": BAKE = False
    elif a.startswith("--render="): RENDER = a.split("=", 1)[1]
    elif a.startswith("--clips="): ONLY = a.split("=", 1)[1].split(",")
## --damage: only the knock-off's damage pieces (headless_body_damage.glb),
## the body's glb left alone.
DAMAGE = "--damage" in _args
GLB = OUT / "headless_body.glb"
FPS = 30

# ------------------------------------------------------------------ the measures
## A head height (m): the head's `size` 3 x the walker's 1.12 m.
HH = 3.36
LEGS = 0.75 * HH            # the hips' pivot over the ground
TORSO = 1.2 * HH
NECK = LEGS + TORSO         # the neck's cut (round 2's neck_h)
BREADTH = 1.3 * HH
DEPTH = 0.72 * HH
ARM_W = 0.3 * HH
## Where the head's chin sits (round 2's seat), over the ground.
SEAT = NECK + 0.06 * HH
SHOULDER_X = BREADTH * 0.5 + ARM_W * 0.45
SHOULDER_Y = LEGS + TORSO * 0.88
HIP_X = BREADTH * 0.26
UPPER = 1.75                # shoulder to elbow
FORE = 1.5                  # elbow to wrist
PALM = 0.7                  # wrist to knuckles
FINGER = 0.72
ANKLE = 0.3
THIGH = (LEGS - ANKLE) * 0.52
SHIN = (LEGS - ANKLE) - THIGH
## The clips' measures, for the game (headless_body_look.gd keeps copies).
WALK_STEP = 0.5 * HH        # m a step, walking
STRIDE_STEP = 0.68 * HH     # m a step, striding home
RUN_STEP = 0.8 * HH         # m a step, the whole Olmec's shoulder-led run
CLIMB_RISE = 2.0 * (1.1 * HH) * 0.45   # m up over the climb's loop (two hand moves)
CLIMB_WALL = DEPTH * 0.5 + 0.25        # the wall ahead of the middle, climbing
LISTEN = 2.6
WINDUP = 1.1
LAND = 1.0
MANTLE = 1.4
SETTLE = 2.2
TRIUMPH = 1.8
## The mantle's way, as the game moves it at the defaults: up, then over.
MANTLE_UP = NECK * 0.55
MANTLE_OVER = CLIMB_WALL + DEPTH * 0.5 + 0.6

SPACING = 0.3
ROUND_STEPS = 4
WEAR = 0.035
WEAR_SIZE = 0.9
rng = random.Random(29)


def G(p):
    """The game's frame (Y up, -Z front) to Blender's (Z up, +Y front)."""
    return V((p[0], -p[2], p[1]))


def F(x, up, fwd):
    """A point in Blender's frame by the figure's words: right, up, forward."""
    return V((x, fwd, up))


# ------------------------------------------------------------------ materials
PALETTE = {
    "stone": ("5a5d63", 0.95),
    "cut": ("8a6f5c", 1.0),
}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS
scene.render.fps_base = 1.0
materials = {}
for key, (h, rough) in PALETTE.items():
    m = bpy.data.materials.new(key)
    rgb = [srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    m.diffuse_color = (*rgb, 1.0)
    m.roughness = rough
    materials[key] = m


# ------------------------------------------------------------------ rounded boxes (the head's)
def _axis(half, r, spacing):
    r = min(r, half * 0.98)
    inner = half - r
    out = []
    for i in range(ROUND_STEPS):
        out.append(-half + r * (i / ROUND_STEPS))
    n = max(1, int(math.ceil(2.0 * inner / spacing)))
    for i in range(n + 1):
        out.append(-inner + 2.0 * inner * i / n)
    for i in range(ROUND_STEPS - 1, -1, -1):
        out.append(half - r * (i / ROUND_STEPS))
    return sorted(set(round(c, 6) for c in out))


class Part:
    def __init__(self, bone):
        self.bone = bone
        self.verts = []
        self.faces = []
        self.mats = []

    def add(self, verts, faces, mat):
        base = len(self.verts)
        self.verts.extend(verts)
        self.faces.extend([tuple(base + i for i in f) for f in faces])
        self.mats.extend([mat] * len(faces))


PARTS = {}


def part(bone):
    if bone not in PARTS: PARTS[bone] = Part(bone)
    return PARTS[bone]


def rbox(bone, center, half, r, mat="stone", shape=None, wear=1.0, chunks=0, seed=0, spacing=SPACING):
    """The head's rounded box (inhaler_head_build.py `rbox`), on `bone`:
    centre and half extents in the game's frame, arris radius `r`, moved by
    `shape(local, u)`, weathered, `chunks` corners broken off."""
    center = V(center)
    hx, hy, hz = half
    ax = [_axis(hx, r, spacing), _axis(hy, r, spacing), _axis(hz, r, spacing)]
    verts = []
    faces = []
    index = {}

    def vid(p):
        key = (round(p[0], 5), round(p[1], 5), round(p[2], 5))
        if key not in index:
            index[key] = len(verts)
            verts.append(V(p))
        return index[key]

    for axis, sign in ((0, 1), (0, -1), (1, 1), (1, -1), (2, 1), (2, -1)):
        a, b = [(1, 2), (2, 0), (0, 1)][axis]
        if sign < 0: a, b = b, a
        ca, cb = ax[a], ax[b]
        for i in range(len(ca) - 1):
            for j in range(len(cb) - 1):
                quad = []
                for (ii, jj) in ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)):
                    p = [0.0, 0.0, 0.0]
                    p[axis] = half[axis] * sign
                    p[a] = ca[ii]
                    p[b] = cb[jj]
                    quad.append(vid(p))
                faces.append(quad)
    rr = [min(r, h * 0.98) for h in half]
    out = []
    for p in verts:
        inner = V((max(-hx + rr[0], min(hx - rr[0], p.x)),
                   max(-hy + rr[1], min(hy - rr[1], p.y)),
                   max(-hz + rr[2], min(hz - rr[2], p.z))))
        d = p - inner
        if d.length > 1e-9:
            d = V((d.x / rr[0], d.y / rr[1], d.z / rr[2]))
            d.normalize()
            q = inner + V((d.x * rr[0], d.y * rr[1], d.z * rr[2]))
        else:
            q = V(p)
        out.append(q)
    if shape is not None:
        out = [shape(q, V((q.x / hx, q.y / hy, q.z / hz))) for q in out]
    crng = random.Random(seed)
    cuts = []
    for k in range(chunks):
        corner = V((crng.choice((-1, 1)) * hx, crng.choice((-1, 1)) * hy, crng.choice((-1, 1)) * hz))
        if corner.z > 0 and crng.random() < 0.6: corner.z = -corner.z
        nrm = V((corner.x / hx + crng.uniform(-0.4, 0.4), corner.y / hy + crng.uniform(-0.4, 0.4),
                 corner.z / hz + crng.uniform(-0.4, 0.4))).normalized()
        depth = crng.uniform(0.1, 0.28)
        cuts.append((corner, nrm, depth))
    for i, q in enumerate(out):
        for corner, nrm, depth in cuts:
            plane = corner.dot(nrm) - depth - r * 0.6
            over = q.dot(nrm) - plane
            if over > 0: q = q - nrm * over
        out[i] = q
    verts_w = []
    for q in out:
        w = center + q
        n = noise.noise(w / WEAR_SIZE) * 0.7 + noise.noise(w / (WEAR_SIZE * 0.3)) * 0.3
        away = V((q.x / hx, q.y / hy, q.z / hz))
        if away.length > 1e-6: away.normalize()
        verts_w.append(w + away * n * WEAR * wear)
    part(bone).add(verts_w, faces, mat)


def smooth01(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# ================================================================== the figure
# Written in the game's frame: x right, y up, z back (-z the front). Big
# rounded blocks (soft arrises, so it reads chunky and smooth from far off),
# the trunk barrel-shaped, the shoulders boulders, the hands huge.

# --- The pelvis course (hips), the belt and the loincloth.
def pelvis(q, u):
    # Rounded under, a little narrower at its foot.
    return V((q.x * (0.88 + 0.12 * smooth01(-1.0, 0.4, u.y)), q.y, q.z))


rbox("hips", (0, LEGS + 0.2, 0.02), (1.78, 0.46, 1.1), 0.3, shape=pelvis, chunks=1, seed=1)
BELT_Y = LEGS + 0.66
bx = [-1.92, -1.14, -0.38, 0.38, 1.14, 1.92]
for i in range(5):
    x0, x1 = bx[i] + 0.025, bx[i + 1] - 0.025
    def bend_belt(q, u, i=i, x0=x0, x1=x1):
        # Wrapping round the belly's curve.
        x = (x0 + x1) * 0.5 + q.x
        return q + V((0, 0, 0.12 * (x / 1.9) ** 2))
    rbox("hips", ((x0 + x1) * 0.5, BELT_Y, -1.14), ((x1 - x0) * 0.5, 0.22, 0.19), 0.09, shape=bend_belt,
         chunks=1 if i != 2 else 0, seed=2 + i, wear=1.2)
for s in (-1, 1):
    rbox("hips", (s * 1.86, BELT_Y, 0.0), (0.14, 0.22, 1.02), 0.09, chunks=1, seed=8 + s)
rbox("hips", (0, BELT_Y, 1.12), (1.8, 0.22, 0.13), 0.09, seed=10)
# The belt's boss, the head's band boss again.
rbox("hips", (0, BELT_Y, -1.36), (0.3, 0.17, 0.06), 0.05, seed=11)
rbox("hips", (0, BELT_Y, -1.42), (0.15, 0.08, 0.035), 0.03, seed=12)


def cloth(q, u):
    # Hanging: a little wider at the foot, bowed out.
    q = V((q.x * (0.88 + 0.14 * smooth01(1.0, -1.0, u.y)), q.y, q.z))
    return q + V((0, 0, -0.08 * (1 - u.x * u.x)))


rbox("hips", (0, LEGS - 0.4, -1.08), (0.5, 0.62, 0.11), 0.09, shape=cloth, chunks=1, seed=13)

# --- The belly (spine): two courses, the middle block of each swelling.
def belly(q, u):
    if u.z < 0:
        full = (1 - u.x * u.x * 0.75) * (1 - u.y * u.y * 0.45)
        q = q + V((0, 0, -0.34 * full * (-u.z) ** 2))
    return q


def side_round(s):
    def f(q, u):
        # The outer blocks rounding back into the barrel.
        out = max(0.0, u.x * s)
        return q + V((0, 0, 0.12 * out * out * (1 if u.z > 0 else -1) * 0.0)) + V((-s * 0.06 * out * abs(u.z) ** 2, 0, 0))
    return f


B1 = LEGS + 1.35
rbox("spine", (0, B1, -0.02), (1.22, 0.49, 1.14), 0.28, shape=belly, chunks=1, seed=14)
for s in (-1, 1):
    rbox("spine", (s * 1.72, B1, 0.04), (0.44, 0.48, 1.04), 0.26, shape=side_round(s), chunks=1, seed=15 + s)
B2 = LEGS + 2.28
rbox("spine", (0, B2, -0.02), (1.36, 0.43, 1.18), 0.26, shape=belly, chunks=1, seed=17)
for s in (-1, 1):
    rbox("spine", (s * 1.93, B2, 0.03), (0.4, 0.42, 1.1), 0.24, shape=side_round(s), chunks=1, seed=18 + s)

# --- The chest (chest): a broad course, the pectoral plaque, the shoulder slab.
def chest_mid(q, u):
    if u.z < 0:
        q = q + V((0, 0, -0.16 * (1 - u.x * u.x) * (1 - u.y * u.y * 0.4) * (-u.z) ** 2))
    return q


C1 = LEGS + 3.22
rbox("chest", (0, C1, 0.0), (1.1, 0.53, 1.24), 0.28, shape=chest_mid, chunks=1, seed=20)
for s in (-1, 1):
    def flank(q, u, s=s):
        # The outer blocks rise toward the shoulders.
        return q + V((0, 0.1 * smooth01(0.0, 1.0, u.x * s) * max(0.0, u.y), 0))
    rbox("chest", (s * 1.74, C1, 0.04), (0.6, 0.53, 1.16), 0.28, shape=flank, chunks=1, seed=21 + s)
rbox("chest", (0, C1 + 0.02, -1.38), (0.7, 0.38, 0.09), 0.08, chunks=1, seed=23, wear=1.2)
rbox("chest", (0, C1 + 0.02, -1.47), (0.32, 0.2, 0.06), 0.05, seed=24)
rbox("chest", (0, C1 + 0.02, -1.53), (0.14, 0.09, 0.035), 0.03, seed=25)


def slab(q, u):
    # The shoulder slab: domed, its ends turned down over the shoulders.
    q = q + V((0, 0.1 * (1 - u.x * u.x) * max(0.0, u.y), 0))
    return q + V((0, -0.16 * u.x ** 4, 0))


rbox("chest", (0, NECK - 0.25, 0.02), (2.2, 0.3, 1.14), 0.3, shape=slab, chunks=3, seed=26, wear=1.3)

# --- The stump (neck): a short neck block, its top cut raw.
rbox("neck", (0, NECK + 0.14, 0.04), (0.94, 0.21, 0.86), 0.12, chunks=2, seed=27, wear=1.4)


def raw(q, u):
    # The break: a jagged top, higher at the back, a dip in the middle.
    w = q
    jag = noise.noise(V((w.x * 1.8, w.z * 1.8, 3.1))) * 0.08 + noise.noise(V((w.x * 5.0, w.z * 5.0, 7.3))) * 0.035
    if u.y > 0:
        q = q + V((0, jag + 0.06 * u.z - 0.05 * (1 - u.x * u.x) * (1 - u.z * u.z), 0))
    return q


rbox("neck", (0, NECK + 0.34, 0.04), (0.86, 0.05, 0.79), 0.03, mat="cut", shape=raw, wear=0.6, seed=28,
     spacing=0.1)

# --- The arms.
for s, n in ((-1, "L"), (1, "R")):
    sx = s * SHOULDER_X
    # The shoulder's boulder, big and round.
    def boulder(q, u, s=s):
        return q + V((0, 0.08 * max(0.0, u.y), 0))
    rbox(f"upper_arm.{n}", (sx + s * 0.08, SHOULDER_Y + 0.05, 0.0), (0.8, 0.72, 0.8), 0.42, shape=boulder,
         chunks=1, seed=30 + s)
    rbox(f"upper_arm.{n}", (sx, SHOULDER_Y - 1.08, 0.0), (0.52, 0.6, 0.54), 0.2, chunks=1, seed=32 + s)
    # The forearm: heavier toward the wrist, the bracelet.
    el = SHOULDER_Y - UPPER

    def fore(q, u):
        k = 0.84 + 0.2 * smooth01(1.0, -1.0, u.y)
        return V((q.x * k, q.y, q.z * k))
    rbox(f"forearm.{n}", (sx, el - 0.62, 0.0), (0.6, 0.66, 0.62), 0.24, shape=fore, chunks=1, seed=34 + s)
    # The elbow: a rounded knuckle of stone, so the joint stays closed bent.
    rbox(f"forearm.{n}", (sx, el + 0.02, 0.06), (0.48, 0.42, 0.48), 0.36, seed=70 + s, wear=0.8)
    rbox(f"forearm.{n}", (sx, el - FORE + 0.14, 0.0), (0.7, 0.15, 0.71), 0.08, chunks=1, seed=36 + s, wear=1.3)
    # The hand: the palm across the way (front to back, its face inward),
    # four fingers on their own bone, the thumb at its front.
    wr = el - FORE
    rbox(f"hand.{n}", (sx, wr - PALM * 0.5, 0.0), (0.38, PALM * 0.56, 0.78), 0.2, chunks=1, seed=38 + s)
    kn = wr - PALM
    for i, z in enumerate((-0.57, -0.19, 0.19, 0.57)):
        long = FINGER * (0.86 if i in (0, 3) else 1.0)
        rbox(f"fingers.{n}", (sx, kn - long * 0.5 + 0.04, z), (0.34, long * 0.5, 0.18), 0.15,
             seed=40 + i + s * 4, wear=0.7, spacing=0.16)
    rbox(f"thumb.{n}", (sx - s * 0.24, wr - 0.5, -0.9), (0.26, 0.36, 0.22), 0.16, seed=50 + s, wear=0.7,
         spacing=0.16)

# --- The legs: thick, the knees a boss, slab feet.
for s, n in ((-1, "L"), (1, "R")):
    hx = s * HIP_X
    kn = LEGS - THIGH
    rbox(f"thigh.{n}", (hx, LEGS - THIGH * 0.46, 0.0), (0.76, THIGH * 0.6, 0.76), 0.28, chunks=1, seed=60 + s)
    rbox(f"shin.{n}", (hx, kn - SHIN * 0.5, 0.0), (0.68, SHIN * 0.54, 0.7), 0.24, chunks=1, seed=62 + s)
    rbox(f"shin.{n}", (hx, kn - 0.04, -0.68), (0.4, 0.28, 0.11), 0.1, seed=64 + s)
    rbox(f"shin.{n}", (hx, kn + 0.05, 0.0), (0.6, 0.45, 0.6), 0.4, seed=72 + s, wear=0.8)

    def foot(q, u):
        # The toes' end rounded down.
        return q + V((0, -0.1 * max(0.0, -u.z) ** 3 * max(0.0, u.y), 0))
    rbox(f"foot.{n}", (hx, 0.2, -0.36), (0.78, 0.2, 1.08), 0.16, shape=foot, chunks=1, seed=66 + s)
    rbox(f"foot.{n}", (hx, 0.44, 0.12), (0.66, 0.14, 0.6), 0.12, seed=68 + s)


# ================================================================== the rig
BONES = [
    # name, parent, head, tail (game's frame)
    ("root", None, (0, 0, 0), (0, 0, -0.8)),
    ("hips", "root", (0, LEGS, 0), (0, LEGS + 0.7, 0)),
    ("spine", "hips", (0, LEGS + 0.7, 0), (0, LEGS + 2.5, 0)),
    ("chest", "spine", (0, LEGS + 2.5, 0), (0, NECK, 0)),
    ("neck", "chest", (0, NECK, 0), (0, NECK + 0.45, 0)),
]
for s, n in ((-1, "L"), (1, "R")):
    sx = s * SHOULDER_X
    el = SHOULDER_Y - UPPER
    wr = el - FORE
    kn = wr - PALM
    BONES += [
        (f"upper_arm.{n}", "chest", (sx, SHOULDER_Y, 0), (sx, el, 0)),
        (f"forearm.{n}", f"upper_arm.{n}", (sx, el, 0), (sx, wr, 0)),
        (f"hand.{n}", f"forearm.{n}", (sx, wr, 0), (sx, kn, 0)),
        (f"fingers.{n}", f"hand.{n}", (sx, kn, 0), (sx, kn - FINGER, 0)),
        (f"thumb.{n}", f"hand.{n}", (sx - s * 0.24, wr - 0.2, -0.75), (sx - s * 0.28, wr - 0.85, -1.0)),
        (f"thigh.{n}", "hips", (s * HIP_X, LEGS, 0), (s * HIP_X, LEGS - THIGH, 0)),
        (f"shin.{n}", f"thigh.{n}", (s * HIP_X, LEGS - THIGH, 0), (s * HIP_X, ANKLE, 0)),
        (f"foot.{n}", f"shin.{n}", (s * HIP_X, ANKLE, 0), (s * HIP_X, 0.12, -0.85)),
    ]

arm_data = bpy.data.armatures.new("HeadlessBodyRig")
rig = bpy.data.objects.new("HeadlessBodyRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for name, parent, h, t in BONES:
    eb = arm_data.edit_bones.new(name)
    eb.head = G(V(h))
    eb.tail = G(V(t))
    y = (eb.tail - eb.head).normalized()
    # Local X the figure's right: Z = X x Y.
    z = V((1, 0, 0)).cross(y)
    if z.length < 1e-4: z = V((0, 0, 1))
    eb.align_roll(z.normalized())
    if parent: eb.parent = arm_data.edit_bones[parent]
    eb.use_connect = False
    eb.use_deform = name != "root"
bpy.ops.object.mode_set(mode="OBJECT")
ORDER = [b[0] for b in BONES]
PARENT = {b[0]: b[1] for b in BONES}
REST = {b.name: b.matrix_local.copy() for b in arm_data.bones}
LEN = {b.name: b.length for b in arm_data.bones}

# ------------------------------------------------------------------ the damage (--damage)
# The Olmec boss's second knock-off (loop olmec-knockoff): his right arm
# snapped off at the shoulder. headless_body_damage.glb holds, in the body
# model's rest space (the body glb's own frame, before its scale):
#   ShoulderBreak_R     what is left at the shoulder: the boulder's broken
#                       root, its end a raw jagged cut (the "cut" stone),
#                       a chip hanging; it rides the chest
#   ArmRubble_R_upper   the arm's own blocks as rubble, each at its bone's
#   ArmRubble_R_fore    rest (upper_arm.R; forearm.R; hand.R with the
#   ArmRubble_R_hand    fingers and thumb, closed as they rest)
# The body hides its own arm (the game scales upper_arm.R to nothing).
DAMAGE_PARTS = {}


def damage_part(name):
    if name not in DAMAGE_PARTS: DAMAGE_PARTS[name] = Part(name)
    return DAMAGE_PARTS[name]


if DAMAGE:
    # The rubble: copies of the arm's blocks.
    for piece, bones in (("ArmRubble_R_upper", ("upper_arm.R",)), ("ArmRubble_R_fore", ("forearm.R",)),
                         ("ArmRubble_R_hand", ("hand.R", "fingers.R", "thumb.R"))):
        dp = damage_part(piece)
        for b in bones:
            src = PARTS[b]
            dp.add([V(q) for q in src.verts], src.faces, "stone")
            dp.mats[-len(src.faces):] = src.mats
    # The shoulder's break: the boulder's root, broken off jagged at its outer end.
    BX = SHOULDER_X - 0.3

    def broken_root(q, u):
        if u.x > 0.2:
            w = q
            jag = noise.noise(V((w.y * 2.2, w.z * 2.2, 5.1))) * 0.16 + noise.noise(V((w.y * 6.0, w.z * 6.0, 9.7))) * 0.06
            q = q + V((jag * (u.x - 0.2) / 0.8, 0, 0))
        return q + V((0, 0.06 * max(0.0, u.y), 0))

    def raw_x(q, u):
        w = q
        jag = noise.noise(V((w.y * 2.2, w.z * 2.2, 5.1))) * 0.16 + noise.noise(V((w.y * 6.0, w.z * 6.0, 9.7))) * 0.06
        dip = -0.08 * (1 - u.y * u.y) * (1 - u.z * u.z)
        return q + V(((jag + dip) * max(0.0, u.x + 0.2), 0, 0))

    rbox("_break", (BX, SHOULDER_Y + 0.02, 0.0), (0.42, 0.66, 0.74), 0.3, shape=broken_root, chunks=2, seed=81)
    rbox("_break", (BX + 0.4, SHOULDER_Y + 0.0, 0.0), (0.06, 0.56, 0.62), 0.04, mat="cut", shape=raw_x,
         wear=0.6, seed=82, spacing=0.1)
    # A chip hanging off its foot, and one off its top.
    rbox("_break", (BX + 0.28, SHOULDER_Y - 0.62, 0.18), (0.18, 0.14, 0.2), 0.06, chunks=1, seed=83)
    rbox("_break", (BX + 0.18, SHOULDER_Y + 0.66, -0.22), (0.2, 0.1, 0.18), 0.06, chunks=1, seed=84)
    br = PARTS.pop("_break")
    dp = damage_part("ShoulderBreak_R")
    dp.add(br.verts, br.faces, "stone")
    dp.mats[-len(br.faces):] = br.mats
    dobs = []
    for name, dpart in DAMAGE_PARTS.items():
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        vs = [bm.verts.new(G(q)) for q in dpart.verts]
        bm.verts.ensure_lookup_table()
        names = ["stone", "cut"]
        for f, m in zip(dpart.faces, dpart.mats):
            try:
                face = bm.faces.new([vs[i] for i in f])
            except ValueError:
                continue
            face.material_index = names.index(m)
            face.smooth = True
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        for nm in names: me.materials.append(materials[nm])
        ob = bpy.data.objects.new(name, me)
        scene.collection.objects.link(ob)
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.material_slot_remove_unused()
        ob.select_set(False)
        attr = me.color_attributes.new("AO", "BYTE_COLOR", "POINT")
        me.color_attributes.active_color = attr
        dobs.append(ob)
    # Occlusion, each piece alone.
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.world = bpy.data.worlds.new("World")
    try:
        scene.world.light_settings.distance = 1.4
    except Exception:
        pass
    tris = 0
    for ob in dobs:
        for o in dobs: o.hide_render = o is not ob
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
        n = sum(len(pl.vertices) - 2 for pl in ob.data.polygons)
        tris += n
        print("DAMAGE_TRIS", ob.name, n)
    for o in dobs: o.hide_render = False
    print("DAMAGE_TRIS total", tris)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in dobs: ob.select_set(True)
    bpy.context.view_layer.objects.active = dobs[0]
    out = OUT / "headless_body_damage.glb"
    OUT.mkdir(parents=True, exist_ok=True)
    kw = dict(filepath=str(out), export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
              export_animations=False, export_materials="EXPORT", export_normals=True, export_extras=False)
    try:
        bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**kw, export_colors=True)
    print("DAMAGE_EXPORTED", out)
    if RENDER:
        # A still: the break on the body with its right arm hidden, and the rubble laid beside.
        for b in ("upper_arm.R", "forearm.R", "hand.R", "fingers.R", "thumb.R"):
            PARTS.pop(b)
        rest = []
        for bone, pp in PARTS.items():
            for q in pp.verts: rest.append(q)
        me = bpy.data.meshes.new("BodyNoArm")
        verts, faces = [], []
        for bone, pp in PARTS.items():
            base = len(verts)
            verts += [G(q) for q in pp.verts]
            faces += [tuple(base + i for i in f) for f in pp.faces]
        me.from_pydata(verts, [], faces)
        me.materials.append(materials["stone"])
        for pl in me.polygons: pl.use_smooth = True
        bo = bpy.data.objects.new("BodyNoArm", me)
        scene.collection.objects.link(bo)
        for ob in dobs:
            if ob.name.startswith("ArmRubble"):
                ob.location = (4.5, 0.0, 0.0)
                ob.rotation_euler = (0.0, math.radians(-80.0), 0.0)
        bpy.data.objects["ArmRubble_R_upper"].location = (6.4, 1.0, -5.8)
        bpy.data.objects["ArmRubble_R_fore"].location = (6.2, -1.5, -2.3)
        bpy.data.objects["ArmRubble_R_hand"].location = (5.8, -4.0, 0.6)
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "MATERIAL"
        scene.display.shading.show_cavity = True
        scene.render.resolution_x = 900
        scene.render.resolution_y = 900
        cam_data = bpy.data.cameras.new("Cam")
        cam_data.lens = 38
        cam = bpy.data.objects.new("Cam", cam_data)
        scene.collection.objects.link(cam)
        scene.camera = cam
        Path(RENDER).mkdir(parents=True, exist_ok=True)
        for nm, frm in (("front", F(14, 9.0, 16)), ("side", F(20, 7.5, 1.0))):
            cam.location = frm
            cam.rotation_euler = (F(3.0, 4.5, 0) - frm).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(Path(RENDER) / f"damage_{nm}.png")
            bpy.ops.render.render(write_still=True)
        print("DAMAGE_RENDERED", RENDER)
    raise SystemExit(0)

# ------------------------------------------------------------------ the skin
objects = []
for bone, p in PARTS.items():
    me = bpy.data.meshes.new(bone)
    bm = bmesh.new()
    vs = [bm.verts.new(G(q)) for q in p.verts]
    bm.verts.ensure_lookup_table()
    names = ["stone", "cut"]
    for f, m in zip(p.faces, p.mats):
        try:
            face = bm.faces.new([vs[i] for i in f])
        except ValueError:
            continue
        face.material_index = names.index(m)
        face.smooth = True
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for nm in names: me.materials.append(materials[nm])
    ob = bpy.data.objects.new(bone, me)
    scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    objects.append(ob)
bpy.ops.object.select_all(action="DESELECT")
for ob in objects: ob.select_set(True)
bpy.context.view_layer.objects.active = objects[0]
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = body.data.name = "Body"
bpy.ops.object.material_slot_remove_unused()
body.parent = rig
body.modifiers.new("Rig", "ARMATURE").object = rig
TRIS = sum(len(p.vertices) - 2 for p in body.data.polygons)
print("BODY_TRIS", TRIS)

# ------------------------------------------------------------------ occlusion (rest pose)
attr = body.data.color_attributes.new("AO", "BYTE_COLOR", "POINT")
body.data.color_attributes.active_color = attr
try:
    body.data.color_attributes.render_color_index = body.data.color_attributes.active_color_index
except Exception:
    pass
if BAKE:
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.world = bpy.data.worlds.new("World")
    try:
        scene.world.light_settings.distance = 1.4
    except Exception:
        pass
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
    vals = [d.color[0] for d in body.data.color_attributes["AO"].data]
    print("BODY_AO", round(min(vals), 3), round(sum(vals) / len(vals), 3), round(max(vals), 3))
else:
    for d in body.data.color_attributes["AO"].data: d.color = (1, 1, 1, 1)


# ================================================================== posing
def deg(d): return math.radians(d)


def qaxis(axis, a): return Quaternion(axis, a)


UPRIGHT = {"hips", "spine", "chest", "neck"}


def local_turn(bone, pitch=0.0, side=0.0, twist=0.0, s=1):
    """A bone's turn in its own frame, in the figure's words (degrees):
    upright bones: pitch + leans forward, side + leans to the figure's
    right, twist + turns left (as the game's facing); hanging bones (arms):
    pitch + swings forward, side + outward, twist + turns the thumb in."""
    X, Y, Z = V((1, 0, 0)), V((0, 1, 0)), V((0, 0, 1))
    if bone in UPRIGHT or bone == "root":
        return qaxis(Z, deg(-side)) @ qaxis(X, deg(-pitch)) @ qaxis(Y, deg(twist))
    # Out first, then the swing: a raised arm keeps its spread.
    return qaxis(X, deg(pitch)) @ qaxis(Z, deg(-s * side)) @ qaxis(Y, deg(-s * twist))


def two_bone(a_pt, goal, la, lb, pole):
    to = goal - a_pt
    d = max(min(to.length, (la + lb) * 0.9995), abs(la - lb) + 1e-3)
    n = to.normalized()
    along = (la * la - lb * lb + d * d) / (2 * d)
    out = math.sqrt(max(la * la - along * along, 0.0))
    bend = pole - n * pole.dot(n)
    if bend.length < 1e-6: bend = V((0, 1, 0)) - n * n.y
    bend.normalize()
    mid = a_pt + n * along + bend * out
    return mid, a_pt + n * d


def frame(origin, y, x_hint):
    """A bone's matrix: Y along `y`, X as near `x_hint` as it can be."""
    y = y.normalized()
    x = x_hint - y * x_hint.dot(y)
    if x.length < 1e-6: x = V((1, 0, 0)) - y * y.x
    x.normalize()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = origin
    return m


class Pose:
    def __init__(self):
        self.turns = {}           # bone -> Quaternion (bone frame)
        self.hips = V((0, 0, 0))  # offset (Blender frame)
        self.squash = 1.0         # root's height scale (its breadth kept by volume)
        self.feet = {}            # side -> (ankle goal, foot turn Quaternion (armature axes))
        self.knee = {}            # side -> pole
        self.hands = {}           # side -> (wrist goal, elbow pole, weight)
        self.palm = {}            # side -> (finger way, palm way) hand's frame in armature axes
        # The whole figure tipped about a point on the ground (knock-off
        # round): (pitch + forward, roll + to its right, the pivot this far
        # ahead of the feet's middle). None for the clips before it, which
        # keep their exact old path.
        self.tip = None
        self.root_m = None        # the root's matrix, for a tip
        self.leg_x = {}           # side -> the leg's right, for its frame (a turned leg: olmec-turn)


def tip_matrix(tip):
    """The tip's turn about its pivot, armature space."""
    pitch, roll, fwd = tip
    piv = F(0.0, 0.0, fwd)
    q = Quaternion((0, 1, 0), deg(roll)) @ Quaternion((1, 0, 0), deg(-pitch))
    return Matrix.Translation(piv) @ q.to_matrix().to_4x4() @ Matrix.Translation(piv * -1.0)


SIDES = (("L", -1), ("R", 1))


def solve(pose):
    if pose.tip is not None: return _solve_tipped(pose)
    P = {}
    reach = 0.0
    for name in ORDER:
        parent = PARENT[name]
        if name.startswith(("thigh", "shin", "foot")):
            continue
        carried = REST[name] if parent is None else P[parent] @ (REST[parent].inverted() @ REST[name])
        q = pose.turns.get(name, Quaternion())
        m = carried @ q.to_matrix().to_4x4()
        if name == "root" and pose.root_m is not None: m = pose.root_m.copy()
        if name == "hips":
            m.translation = carried.translation + pose.hips
        P[name] = m
        if name == "root" and pose.root_m is not None: P["_tip"] = True
        if name.startswith("forearm."):
            n = name.split(".")[1]
            s = -1 if n == "L" else 1
            if n in pose.hands and pose.hands[n][2] > 0.0:
                goal, pole, w = pose.hands[n]
                sh = P[f"upper_arm.{n}"].translation
                wr_fk = (P[name] @ Matrix.Translation(V((0, LEN[name], 0)))).translation
                target = wr_fk.lerp(goal, w)
                el, wr = two_bone(sh, target, LEN[f"upper_arm.{n}"], LEN[name], pole)
                # The bend's plane: its normal the bones' X (the elbow bends
                # about it, flexion + about X: the forearm toward the upper
                # arm's local +Z).
                xh = P[f"upper_arm.{n}"].to_3x3() @ V((1, 0, 0))
                nrm = (el - sh).cross(wr - el)
                if nrm.length > 1e-4:
                    xh = nrm.normalized()
                    up_m = frame(sh, el - sh, xh)
                    if (up_m.to_3x3().inverted() @ (wr - el)).z < 0: xh = -xh
                P[f"upper_arm.{n}"] = frame(sh, el - sh, xh)
                P[name] = frame(el, wr - el, xh)
    # The legs, by IK from the hips.
    for n, s in SIDES:
        th = f"thigh.{n}"
        hip = (P["hips"] @ (REST["hips"].inverted() @ REST[th])).translation
        rest_ankle = REST[f"foot.{n}"].translation
        goal, fq = pose.feet.get(n, (rest_ankle.copy(), Quaternion()))
        pole = pose.knee.get(n, V((s * 0.25, 1.0, 0.0)))
        reach = max(reach, (goal - hip).length / (THIGH + SHIN))
        knee, ankle = two_bone(hip, goal, LEN[th], LEN[f"shin.{n}"], pole)
        xh = (goal - hip).cross(pole)
        if xh.length < 1e-6: xh = V((1, 0, 0))
        xh = xh.normalized()
        if xh.dot(pose.leg_x.get(n, V((1, 0, 0)))) < 0: xh = -xh
        P[th] = frame(hip, knee - hip, xh)
        P[f"shin.{n}"] = frame(knee, ankle - knee, xh)
        fm = (fq.to_matrix() @ REST[f"foot.{n}"].to_3x3()).to_4x4()
        fm.translation = ankle
        P[f"foot.{n}"] = fm
    # The hands and what they carry, after an IK'd forearm: their own
    # frame if given, else the turn under the forearm.
    for n, s in SIDES:
        hn = f"hand.{n}"
        fa = f"forearm.{n}"
        carried = P[fa] @ (REST[fa].inverted() @ REST[hn])
        if n in pose.palm:
            fway, pway, w = pose.palm[n]
            m = frame(carried.translation, fway, pway * (-s))
            fk = carried @ pose.turns.get(hn, Quaternion()).to_matrix().to_4x4()
            qa = fk.to_quaternion().slerp(m.to_quaternion(), w)
            m = qa.to_matrix().to_4x4()
            m.translation = carried.translation
            P[hn] = m
        else:
            P[hn] = carried @ pose.turns.get(hn, Quaternion()).to_matrix().to_4x4()
        for c in (f"fingers.{n}", f"thumb.{n}"):
            cm = P[hn] @ (REST[hn].inverted() @ REST[c])
            P[c] = cm @ pose.turns.get(c, Quaternion()).to_matrix().to_4x4()
    return P, reach


def _solve_tipped(pose):
    """`solve` with the whole figure turned by its tip: the root carries the
    trunk and arms, and every goal given in the root's frame (the feet, their
    turns, the knees' poles, the hands and their palms) is turned with it."""
    M = tip_matrix(pose.tip)
    R3 = M.to_3x3()
    Rq = R3.to_quaternion()
    q = Pose()
    q.turns = pose.turns
    q.squash = pose.squash
    q.hips = R3 @ pose.hips
    for n, s in SIDES:
        goal, fq = pose.feet.get(n, (REST[f"foot.{n}"].translation.copy(), Quaternion()))
        q.feet[n] = (M @ goal, Rq @ fq)
        q.knee[n] = R3 @ pose.knee.get(n, V((s * 0.25, 1.0, 0.0)))
        if n in pose.hands:
            g, pole, w = pose.hands[n]
            q.hands[n] = (M @ g, R3 @ pole, w)
        if n in pose.palm:
            fw, pw, w = pose.palm[n]
            q.palm[n] = (R3 @ fw, R3 @ pw, w)
    # The root turned about the pivot, not its own head.
    q.root_m = M @ REST["root"]
    P, reach = solve(q)
    P["_tip"] = True
    return P, reach


def basis(P):
    """Each bone's pose relative to its rest under its parent."""
    out = {}
    for name in ORDER:
        parent = PARENT[name]
        if parent is None:
            # The root's own turn (only a tip gives it one).
            out[name] = REST[name].inverted() @ P[name] if "_tip" in P else Matrix.Identity(4)
            continue
        rel = REST[parent].inverted() @ REST[name]
        out[name] = rel.inverted() @ P[parent].inverted() @ P[name]
    return out


# ------------------------------------------------------------------ key poses and their spans
class Track:
    """A channel through keys (t, value, ease): cubic between them, the
    slope at a key Catmull-Rom's unless its ease is "h" (a hold: flat in
    and out), "i" (flat in), "o" (flat out). Loops wrap; one-shots clamp."""

    def __init__(self, keys, length, loop):
        self.keys = sorted(keys, key=lambda k: k[0])
        self.length = length
        self.loop = loop

    def _slope(self, i):
        ks = self.keys
        n = len(ks)
        t, v, e = ks[i]
        if e in ("h",): return 0.0
        if self.loop:
            pt, pv, _ = ks[i - 1] if i > 0 else (ks[-1][0] - self.length, ks[-1][1], "")
            nt, nv, _ = ks[i + 1] if i < n - 1 else (ks[0][0] + self.length, ks[0][1], "")
        else:
            if i == 0 or i == n - 1: return 0.0
            pt, pv, _ = ks[i - 1]
            nt, nv, _ = ks[i + 1]
        if nt - pt < 1e-9: return 0.0
        return (nv - pv) / (nt - pt)

    def at(self, t):
        ks = self.keys
        if len(ks) == 1: return ks[0][1]
        if self.loop:
            t = t % self.length
            if t < ks[0][0]:
                a, b = len(ks) - 1, 0
                t0, t1 = ks[a][0] - self.length, ks[b][0]
            elif t >= ks[-1][0]:
                a, b = len(ks) - 1, 0
                t0, t1 = ks[a][0], ks[b][0] + self.length
            else:
                b = next(i for i, k in enumerate(ks) if k[0] > t)
                a = b - 1
                t0, t1 = ks[a][0], ks[b][0]
        else:
            if t <= ks[0][0]: return ks[0][1]
            if t >= ks[-1][0]: return ks[-1][1]
            b = next(i for i, k in enumerate(ks) if k[0] > t)
            a = b - 1
            t0, t1 = ks[a][0], ks[b][0]
        span = t1 - t0
        u = (t - t0) / span
        v0, v1 = ks[a][1], ks[b][1]
        m0 = 0.0 if ks[a][2] in ("h", "o") else self._slope(a) * span
        m1 = 0.0 if ks[b][2] in ("h", "i") else self._slope(b) * span
        u2, u3 = u * u, u * u * u
        return (2 * u3 - 3 * u2 + 1) * v0 + (u3 - 2 * u2 + u) * m0 + (-2 * u3 + 3 * u2) * v1 + (u3 - u2) * m1


## The standing pose every key starts from (channels: see `pose_of`).
BASE = {
    "sq": 1.0, "hx": 0.0, "hy": -0.1, "hz": 0.0, "hp": 0.0, "hr": 0.0, "ht": 0.0,
    "sp": 5.0, "sr": 0.0, "st": 0.0, "cp": 5.0, "cr": 0.0, "ct": 0.0, "np": 0.0, "nr": 0.0, "nt": 0.0,
    # The whole figure's tip (knock-off round): pitch + forward, roll + to
    # its right (degrees), about a pivot on the ground `tf` m ahead of the
    # feet's middle (the toes ~0.85, the heels ~-0.4).
    "tp": 0.0, "tr": 0.0, "tf": 0.0,
}
for n, s in SIDES:
    BASE.update({
        f"a{n}p": 4.0, f"a{n}o": 11.0, f"a{n}t": 0.0, f"e{n}": 14.0, f"w{n}p": 0.0, f"w{n}o": 0.0, f"w{n}t": 0.0,
        f"f{n}": 28.0, f"t{n}": 10.0,
        # The ankle off its rest (x out, up, forward) and the foot's pitch (+ toes up).
        f"k{n}x": 0.12, f"k{n}y": 0.0, f"k{n}z": 0.0, f"k{n}p": 0.0, f"k{n}r": 0.0,
        # Hand IK: the wrist's goal (x, up, forward, in the root's frame) and its weight.
        f"h{n}x": s * 1.6, f"h{n}y": 4.0, f"h{n}z": 1.0, f"h{n}w": 0.0,
        # The hand's own frame: weight, finger way (x, up, fwd), palm way.
        f"p{n}w": 0.0, f"p{n}fx": 0.0, f"p{n}fy": 1.0, f"p{n}fz": 0.0, f"p{n}nx": 0.0, f"p{n}ny": 0.0, f"p{n}nz": 1.0,
    })
## The overlap: channels that trail the trunk (s), so a move arrives in
## the shoulders, then the elbows, then the hands and fingers.
LAG = {"np": 0.07, "nr": 0.08, "nt": 0.06, "cp": 0.03, "cr": 0.03, "ct": 0.03}
for n, s in SIDES:
    LAG.update({f"a{n}p": 0.03, f"a{n}o": 0.03, f"e{n}": 0.07, f"w{n}p": 0.1, f"w{n}o": 0.1, f"f{n}": 0.12, f"t{n}": 0.12})


class Clip:
    """Key poses (time, {channel: value}, ease) over BASE; extra channels
    added by `extra(t, values)` (procedural paths: feet and hands)."""

    def __init__(self, name, length, keys, loop=False, extra=None, lag=True, lag_scale=1.0):
        self.name = name
        self.length = length
        self.loop = loop
        self.extra = extra
        self.lag = lag
        self.lag_scale = lag_scale
        chans = set(BASE)
        for _, p, _ in keys: chans |= set(p) - {"_base"}
        self.tracks = {}
        for c in chans:
            ks = []
            last = BASE.get(c, 0.0)
            for t, p, e in keys:
                if c in p: last = p[c]
                elif p.get("_base"): last = BASE.get(c, 0.0)
                ks.append((t, last, e))
            self.tracks[c] = Track(ks, length, loop)

    def values(self, t):
        out = {}
        for c, tr in self.tracks.items():
            lag = LAG.get(c, 0.0) * self.lag_scale if self.lag else 0.0
            out[c] = tr.at(t - lag)
        if self.extra: self.extra(t, out)
        return out


def pose_of(v):
    p = Pose()
    p.squash = v["sq"]
    p.hips = F(v["hx"], v["hy"], v["hz"])
    # Olmec turn: the whole figure yawed on the spot (`ry`, + left), its
    # hips' offsets in the turned frame; the feet then given on the ground
    # in the clip's start frame (`g*`), so a planted foot stays put.
    yaw = v.get("ry", 0.0)
    yq = Quaternion((0, 0, 1), deg(yaw))
    if "ry" in v:
        p.root_m = yq.to_matrix().to_4x4() @ REST["root"]
        p.hips = yq.to_matrix() @ p.hips
    p.turns["hips"] = local_turn("hips", v["hp"], v["hr"], v["ht"])
    p.turns["spine"] = local_turn("spine", v["sp"], v["sr"], v["st"])
    p.turns["chest"] = local_turn("chest", v["cp"], v["cr"], v["ct"])
    p.turns["neck"] = local_turn("neck", v["np"], v["nr"], v["nt"])
    if abs(v["tp"]) > 1e-6 or abs(v["tr"]) > 1e-6:
        p.tip = (v["tp"], v["tr"], v["tf"])
    for n, s in SIDES:
        p.turns[f"upper_arm.{n}"] = local_turn("arm", v[f"a{n}p"], v[f"a{n}o"], v[f"a{n}t"], s)
        p.turns[f"forearm.{n}"] = local_turn("arm", v[f"e{n}"], 0.0, 0.0, s)
        p.turns[f"hand.{n}"] = local_turn("arm", v[f"w{n}p"], v[f"w{n}o"], v[f"w{n}t"], s)
        # The fingers curl into the palm (inward), the thumb across it.
        p.turns[f"fingers.{n}"] = local_turn("arm", 0.0, -v[f"f{n}"], 0.0, s)
        p.turns[f"thumb.{n}"] = local_turn("arm", v[f"t{n}"] * 0.4, -v[f"t{n}"], 0.0, s)
        rest_ankle = REST[f"foot.{n}"].translation
        goal = rest_ankle + F(s * v[f"k{n}x"], v[f"k{n}y"], v[f"k{n}z"])
        fq = Quaternion((1, 0, 0), deg(v[f"k{n}p"])) @ Quaternion((0, 1, 0), deg(s * v[f"k{n}r"]))
        p.feet[n] = (goal, fq)
        p.knee[n] = V((s * 0.3, 1.0, 0.0))
        if f"g{n}x" in v:
            fy = Quaternion((0, 0, 1), deg(v[f"g{n}a"]))
            p.feet[n] = (F(v[f"g{n}x"], ANKLE + v[f"g{n}y"], v[f"g{n}z"]), fy @ Quaternion((1, 0, 0), deg(v[f"g{n}p"])))
            # The knee over the foot's way, a little out with the hips'.
            kq = Quaternion((0, 0, 1), deg((v[f"g{n}a"] + yaw) * 0.5))
            p.knee[n] = kq.to_matrix() @ V((s * 0.3, 1.0, 0.0))
            p.leg_x[n] = kq.to_matrix() @ V((1.0, 0.0, 0.0))
        if v[f"h{n}w"] > 0.0:
            p.hands[n] = (F(v[f"h{n}x"], v[f"h{n}y"], v[f"h{n}z"]), V((s * 1.0, -0.5, -0.6)), min(1.0, v[f"h{n}w"]))
        if v[f"p{n}w"] > 0.0:
            p.palm[n] = (F(v[f"p{n}fx"], v[f"p{n}fy"], v[f"p{n}fz"]), F(v[f"p{n}nx"], v[f"p{n}ny"], v[f"p{n}nz"]),
                         min(1.0, v[f"p{n}w"]))
    return p


def tremble(t, amount, hz=13.0, seed=0.0):
    return amount * (math.sin(t * hz * 6.283 + seed) * 0.6 + math.sin(t * hz * 1.7 * 6.283 + seed * 2.0) * 0.4)


CLIPS = []


def clip(c):
    CLIPS.append(c)
    return c


# ------------------------------------------------------------------ idle
def _idle_extra(t, v):
    # Breathing: two slow breaths and a sigh, the shoulders with the chest.
    b = math.sin(t / 4.0 * 6.283 * 2 - 1.2)
    v["cp"] += -1.6 * b
    v["sp"] += -0.6 * b
    v["hy"] += 0.025 * b
    for n, s in SIDES:
        v[f"a{n}o"] += 1.2 * b


clip(Clip("idle", 4.0, [
    (0.0, {"hx": -0.05, "hr": -1.0, "nt": 3.0}, ""),
    (1.3, {"hx": 0.04, "hr": 1.0, "nt": -4.0, "nr": 2.0}, ""),
    (2.0, {"fL": 18.0, "fR": 34.0}, ""),
    (2.6, {"fL": 34.0, "fR": 22.0, "nt": -1.0}, ""),
    (3.2, {"hx": 0.0, "hr": 0.0, "nr": -1.0, "nt": 2.0}, ""),
], loop=True, extra=_idle_extra))

# ------------------------------------------------------------------ listen
def _cup(n, s, up=0.0, tilt=0.0):
    """A hand cupped by the stump's side: the wrist there, the palm turned
    forward and out to gather the sound."""
    return {f"h{n}x": s * 2.05, f"h{n}y": SEAT + 1.2 + up, f"h{n}z": -0.1, f"h{n}w": 1.0,
            f"p{n}w": 1.0, f"p{n}fx": s * 0.15, f"p{n}fy": 1.0, f"p{n}fz": 0.15,
            f"p{n}nx": s * 0.55, f"p{n}ny": 0.0, f"p{n}nz": 0.85, f"f{n}": 48.0, f"t{n}": 30.0}


def _down(n):
    return {f"h{n}w": 0.0, f"p{n}w": 0.0, f"f{n}": 30.0, f"t{n}": 10.0}


## Round 4: no gesture. He goes
## still to listen: a slow breath out, the weight sinking a little, the
## arms hanging slack, held; on "heard" (as the game turns him) a small
## lift of the stump and the fists closing, then back to standing. No arm
## raised, no twist.
L_ = LISTEN
clip(Clip("listen", L_, [
    (0.0, {}, ""),
    (0.5 * L_ / 2.6, {"hy": -0.16, "sq": 0.98, "sp": 8.0, "cp": 3.0, "np": 5.0, "aLo": 8.0, "aRo": 8.0,
                      "eL": 10.0, "eR": 10.0, "fL": 18.0, "fR": 18.0}, "o"),            # settled, still
    (1.2 * L_ / 2.6, {"hy": -0.18, "np": 6.0}, "h"),
    (1.72 * L_ / 2.6, {"hy": -0.18, "np": 6.0}, "h"),
    # Heard: the stump comes up, the fists close.
    (1.88 * L_ / 2.6, {"hy": -0.1, "sq": 1.01, "np": -3.0, "sp": 5.0, "cp": 4.0, "fL": 60.0, "fR": 60.0,
                       "tL": 30.0, "tR": 30.0}, "o"),
    (L_, {"_base": 1}, ""),
]))


# ------------------------------------------------------------------ mirrors
def _mirror(v):
    """A pose's values mirrored left to right: each side's channels swapped,
    the root-frame x's and the trunk's side leans and twists negated."""
    out = {}
    for c, x in v.items():
        if len(c) >= 2 and c[1] in "LR":
            m = c[0] + ("R" if c[1] == "L" else "L") + c[2:]
            out[m] = -x if c[0] + c[2:] in ("hx", "pfx", "pnx", "gx", "ga") else x
        elif c in ("hx", "hr", "ht", "sr", "st", "cr", "ct", "nr", "nt", "tr", "ry"):
            out[c] = -x
        else:
            out[c] = x
    return out


class Mirror:
    """Clip `of` mirrored left to right, as `name`."""

    def __init__(self, name, of):
        self.name = name
        self.of = of
        self.length = of.length
        self.loop = of.loop

    def values(self, t):
        return _mirror(self.of.values(t))


# ------------------------------------------------------------------ walk and stride
def gait(step, stance, lift, swing_ease=0.85):
    """The feet over a cycle of two steps of `step` m (left down at 0, the
    right at 0.5), planted for `stance` of it (going back under the body at
    the ground's pace), lifted `lift` m between, coming down fast and flat."""
    D = step * stance  # half the planted foot's travel (the cycle covers 2 steps)

    def feet(u, v):
        for n, off in (("L", 0.0), ("R", 0.5)):
            w = (u - off) % 1.0
            if w < stance:
                k = w / stance
                z = D - 2 * D * k
                y = 0.0
                p = -14.0 * smooth01(0.75, 1.0, k)   # the heel coming up
            else:
                k = (w - stance) / (1 - stance)
                z = -D + 2 * D * smooth01(0.1, swing_ease, k)
                a = k ** 0.8
                y = lift * 4 * a * (1 - a)
                p = -22.0 * (1 - smooth01(0.0, 0.45, k)) + 10.0 * math.sin(math.pi * smooth01(0.3, 0.9, k))
            v[f"k{n}z"] = z
            v[f"k{n}y"] = y
            v[f"k{n}p"] = p
    return feet


def walk_extra(step, stance, lift, sway, twist, arm, base_arm, arm_out, elbow):
    feet = gait(step, stance, lift)

    def extra(t, v, length=[None]):
        u = t / CYCLE_OF[extra]
        feet(u % 1.0, v)
        c = math.cos(2 * math.pi * u)
        sn = math.sin(2 * math.pi * u + 0.35)
        v["hx"] += -sway * sn
        v["hr"] += -5.0 * sn
        v["sr"] += 2.5 * sn
        v["cr"] += 2.0 * math.sin(2 * math.pi * (u - 0.05) + 0.35)
        v["ht"] += -twist * c
        v["ct"] += twist * 1.3 * math.cos(2 * math.pi * (u - 0.05))
        # The arms opposite the legs, the forearms trailing.
        for n, sgn in (("L", -1), ("R", 1)):
            sw = sgn * arm * math.cos(2 * math.pi * (u - 0.05))
            v[f"a{n}p"] = base_arm + sw
            v[f"a{n}o"] = arm_out
            v[f"e{n}"] = elbow + 0.4 * max(0.0, sgn * arm * math.cos(2 * math.pi * (u - 0.12)))
    return extra


CYCLE_OF = {}
WALK_LEN = 2.4
_wx = walk_extra(WALK_STEP, 0.56, 0.5, 0.2, 8.0, 22.0, 4.0, 8.0, 16.0)
CYCLE_OF[_wx] = WALK_LEN


def _gait_keys(contact, down, passing, up, extra_down=None, extra_contact=None):
    """The body's beats on each step: contact, the heavy drop (held a
    moment), passing, up; at 0 and 0.5 of the loop."""
    keys = []
    for o in (0.0, 0.5):
        keys += [
            (o + 0.0, {"hy": contact, "sq": 1.0, "np": 2.0, **(extra_contact or {})}, ""),
            (o + 0.07, {"hy": down, "sq": 0.965, "np": 6.0, **(extra_down or {})}, "h"),
            (o + 0.13, {"hy": down + 0.04, "sq": 0.98}, ""),
            (o + 0.27, {"hy": passing, "sq": 1.0, "np": 1.0}, ""),
            (o + 0.40, {"hy": up, "sq": 1.01, "np": 0.0}, ""),
        ]
    return [(t * WALK_LEN, p, e) for t, p, e in keys]


clip(Clip("walk", WALK_LEN, _gait_keys(-0.36, -0.58, -0.28, -0.22, {"sp": 9.0}, {"sp": 6.0}), loop=True, extra=_wx))

# ------------------------------------------------------------------ stomp
## The stomper's walk (spec-stomper.md), for a body 250 m tall: two long slow
## steps. The game plants the feet on the real ground and moves the body by the
## planted foot's way, so this clip is the weight: the foot comes down flat and
## fast, the body sinks into it and holds while the far foot peels, then rolls
## up over the leg and falls into the next step. stomper.gd keeps copies of
## STOMP_LEN and STOMP_STANCE.
STOMP_LEN = 16.0            # s for the two steps
STOMP_STEP = 2.6            # m a step
STOMP_STANCE = 0.62         # of the cycle a foot is down
STOMP_LIFT = 0.85           # m the ankle clears at the top of its swing
STOMP_HEEL = 0.7            # m, ankle to the ball of the foot


def stomp_way(w):
    """The share of a step the body has made `w` of the way through it: the
    speed carried into the plant dies in the sink, a hold, then the roll and
    the fall. Monotone cubic spans (w, share, slope)."""
    pts = ((0.0, 0.0, 1.7), (0.1, 0.085, 0.25), (0.28, 0.12, 0.2), (0.62, 0.52, 1.6), (1.0, 1.0, 1.7))
    for (a, x0, m0), (b, x1, m1) in zip(pts, pts[1:]):
        if w <= b:
            d = b - a
            u = (w - a) / d
            u2, u3 = u * u, u * u * u
            return (2 * u3 - 3 * u2 + 1) * x0 + (u3 - 2 * u2 + u) * m0 * d + (-2 * u3 + 3 * u2) * x1 + (u3 - u2) * m1 * d
    return 1.0


def stomp_far(u):
    """The body's way in steps over the cycle (0 to 2)."""
    s = u * 2.0
    i = math.floor(s)
    return i + stomp_way(s - i)


def stomp_extra(t, v):
    u = (t / STOMP_LEN) % 1.0
    travel = stomp_far(STOMP_STANCE)
    # The feet by where they stand on the ground, less where the body is: a
    # planted foot goes back under it at exactly its pace, holds and all.
    for n, off in (("L", 0.0), ("R", 0.5)):
        w = (u - off) % 1.0
        far = stomp_far(w)
        if w < STOMP_STANCE:
            ground = travel * 0.5
            y = 0.0
            p = -20.0 * smooth01(0.7, 1.0, w / STOMP_STANCE)
        else:
            k = (w - STOMP_STANCE) / (1.0 - STOMP_STANCE)
            ground = travel * 0.5 + 2.0 * smooth01(0.0, 0.84, k)
            a = k ** 2.1
            y = STOMP_LIFT * 4.0 * a * (1.0 - a)
            p = -20.0 * (1.0 - smooth01(0.0, 0.42, k)) + 11.0 * math.sin(math.pi * smooth01(0.3, 0.92, k))
        v[f"k{n}z"] = STOMP_STEP * (ground - far)
        v[f"k{n}y"] = y + STOMP_HEEL * math.sin(deg(max(0.0, -p)))
        v[f"k{n}p"] = p
    # The weight goes side to side with the body's way, so it holds with it.
    far = stomp_far(u) / 2.0
    side = math.sin(2 * math.pi * far + 0.35)
    v["hx"] += -0.3 * side
    v["hr"] += -6.0 * side
    v["sr"] += 3.5 * side
    v["cr"] += 2.5 * math.sin(2 * math.pi * (far - 0.04) + 0.35)
    turn = math.cos(2 * math.pi * far)
    v["ht"] += -14.0 * turn
    v["ct"] += 20.0 * math.cos(2 * math.pi * (far - 0.05))
    # The arms hang and swing on through the hold, opposite the legs, the
    # forearms trailing them.
    for n, sgn in (("L", -1), ("R", 1)):
        sw = sgn * 24.0 * math.cos(2 * math.pi * (u - 0.07))
        v[f"a{n}p"] = 3.0 + sw
        v[f"a{n}o"] = 17.0
        v[f"e{n}"] = 16.0 + 0.6 * max(0.0, sgn * 24.0 * math.cos(2 * math.pi * (u - 0.13)))


def _stomp_keys():
    """The body's beats on each step: down on the plant, sunk and held, up over
    the leg, tipping into the next."""
    keys = []
    for o in (0.0, 0.5):
        keys += [
            (o + 0.0, {"hy": -0.58, "sp": 9.0, "cp": 5.0}, ""),
            (o + 0.045, {"hy": -0.82, "sp": 16.0, "cp": 12.0}, "h"),
            (o + 0.12, {"hy": -0.78, "sp": 15.0, "cp": 11.0}, "h"),
            (o + 0.31, {"hy": -0.18, "sp": 4.0, "cp": 2.0}, ""),
            (o + 0.43, {"hy": -0.3, "sp": 6.0, "cp": 3.5}, ""),
        ]
    return [(t * STOMP_LEN, p, e) for t, p, e in keys]


clip(Clip("stomp", STOMP_LEN, _stomp_keys(), loop=True, extra=stomp_extra, lag_scale=6.0))

STRIDE_LEN = 1.6
_sx = walk_extra(STRIDE_STEP, 0.5, 0.62, 0.16, 7.0, 10.0, 58.0, -4.0, 30.0)
CYCLE_OF[_sx] = STRIDE_LEN


def _stride_keys():
    keys = []
    for o in (0.0, 0.5):
        keys += [
            (o + 0.0, {"hy": -0.5, "sq": 1.0, "np": 10.0, "sp": 14.0, "cp": 6.0, "fL": 12.0, "fR": 12.0}, ""),
            (o + 0.07, {"hy": -0.74, "sq": 0.96, "np": 15.0, "sp": 17.0}, "h"),
            (o + 0.13, {"hy": -0.7, "sq": 0.98}, ""),
            (o + 0.27, {"hy": -0.42, "sq": 1.0, "np": 10.0, "sp": 14.0, "fL": 30.0, "fR": 30.0}, ""),
            (o + 0.40, {"hy": -0.36, "sq": 1.01, "np": 9.0}, ""),
        ]
    return [(t * STRIDE_LEN, p, e) for t, p, e in keys]


clip(Clip("stride", STRIDE_LEN, _stride_keys(), loop=True, extra=_sx))

# ------------------------------------------------------------------ the shoulder-led run (Olmec boss, phase 2)
## Whole, he hunts shoulder first: the trunk turned a quarter so the right
## shoulder leads, dropped and forward; that arm tucked in with the fist at
## the chest; the left (far) arm pumping hard with the strides; the head
## down behind the shoulder; heavy strides with a deep drop on each
## contact and a short float between. Loop over two steps of RUN_STEP m.
RUN_LEN = 1.0
## The trunk's held turn and lean (degrees), on every key.
_RUN_HOLD = {"hp": 8.0, "ht": 14.0, "st": 12.0, "ct": 26.0, "sr": 3.0, "cr": 8.0, "nt": -38.0, "nr": -12.0,
             "aRo": 3.0, "aRt": 40.0, "fR": 72.0, "tR": 34.0, "fL": 62.0, "tL": 30.0}


def run_extra(step, stance, lift):
    feet = gait(step, stance, lift, 0.78)

    def extra(t, v):
        u = t / RUN_LEN
        feet(u % 1.0, v)
        sn = math.sin(2 * math.pi * u + 0.35)
        # The weight thrown over each planted foot, rolling the hips.
        v["hx"] += -0.26 * sn
        v["hr"] += -6.0 * sn
        v["sr"] += 3.0 * sn
        v["cr"] += 2.0 * math.sin(2 * math.pi * (u - 0.06) + 0.35)
        # The trunk winds with the legs on top of its held quarter turn.
        c = math.cos(2 * math.pi * u)
        v["ht"] += -7.0 * c
        v["ct"] += 8.0 * math.cos(2 * math.pi * (u - 0.06))
        # The far arm pumps against the left leg (back as that foot lands),
        # bent, its elbow opening on the back swing.
        pump = math.cos(2 * math.pi * (u - 0.07))
        v["aLp"] = 12.0 - 50.0 * pump
        v["aLo"] = 10.0 + 2.0 * max(0.0, pump)
        v["eL"] = 72.0 + 26.0 * max(0.0, -pump)
        # The near arm tucked, fist up at the chest, braced: a small jolt
        # down on each contact.
        jolt = math.cos(2 * math.pi * 2 * (u - 0.09))
        v["aRp"] = 8.0 + 5.0 * jolt
        v["eR"] = 92.0 - 6.0 * jolt
    return extra


_rx = run_extra(RUN_STEP, 0.4, 0.95)


def _run_keys():
    """The beats of each step, heavy: contact, the deep drop (held), the
    push off and the float."""
    keys = []
    for o in (0.0, 0.5):
        keys += [
            (o + 0.0, {**_RUN_HOLD, "hy": -0.62, "sq": 1.0, "sp": 20.0, "cp": 12.0, "np": -6.0}, ""),
            (o + 0.07, {"hy": -1.0, "sq": 0.965, "sp": 22.5, "cp": 13.0, "np": -4.0}, "h"),
            (o + 0.14, {"hy": -0.92, "sq": 0.98, "sp": 21.5}, ""),
            (o + 0.28, {"hy": -0.46, "sq": 1.01, "sp": 19.5, "cp": 11.5, "np": -7.0}, ""),
            (o + 0.40, {"hy": -0.34, "sq": 1.02, "sp": 19.0, "np": -8.0}, ""),
        ]
    return [(t * RUN_LEN, p, e) for t, p, e in keys]


clip(Clip("shoulder_run", RUN_LEN, _run_keys(), loop=True, extra=_rx))

# ------------------------------------------------------------------ the hunt stride (whole, chasing)
## Whole and hunting (olmec-look lane): a tall, deliberate stride at the
## stride's step (STRIDE_STEP, so the feet match the game's phase). He
## stays upright, chest up and shoulders square, the stump level so his
## head rides high and looks straight ahead; the menace is his height and
## weight. The arms hang heavy at his sides, a little out from the bulk,
## fists closed, swinging short and late against the legs, the forearms
## trailing. Each footfall lands like a block set down: the hips drop and
## hold, the shoulders roll over the planted foot, the stump nods with the
## impact and comes back after. No arms out in front, no crouch.
HUNT_LEN = 1.8
## Held on every key: the fists closed (degrees).
_HUNT_HOLD = {"hp": 1.0, "fL": 78.0, "fR": 78.0, "tL": 36.0, "tR": 36.0}


def hunt_extra(step, stance, lift):
    feet = gait(step, stance, lift, 0.8)

    def extra(t, v):
        u = t / HUNT_LEN
        feet(u % 1.0, v)
        sn = math.sin(2 * math.pi * u + 0.35)
        # The weight thrown over each planted foot: a heavy sway, the hips
        # and the shoulders rolling over it.
        v["hx"] += -0.3 * sn
        v["hr"] += -7.0 * sn
        v["sr"] += 3.0 * sn
        v["cr"] += 4.5 * math.sin(2 * math.pi * (u - 0.07) + 0.35)
        # The shoulders wind against the hips, late.
        c = math.cos(2 * math.pi * u)
        v["ht"] += -8.0 * c
        v["ct"] += 11.0 * math.cos(2 * math.pi * (u - 0.08))
        # The stump counters the chest's roll and twist, so the head stays
        # on its mark while the body rolls under it.
        v["nr"] += -3.5 * math.sin(2 * math.pi * (u - 0.07) + 0.35)
        v["nt"] += -8.0 * math.cos(2 * math.pi * (u - 0.08))
        # The arms: heavy at his sides, out from the bulk, swinging short
        # against the legs and late (dragged), the forearm trailing further
        # on the back swing.
        for n, sgn in (("L", -1), ("R", 1)):
            sw = sgn * math.cos(2 * math.pi * (u - 0.1))
            v[f"a{n}p"] = -2.0 + 17.0 * sw
            v[f"a{n}o"] = 17.0 + 3.0 * max(0.0, -sw)
            v[f"a{n}t"] = -8.0
            v[f"e{n}"] = 18.0 + 18.0 * max(0.0, sgn * math.cos(2 * math.pi * (u - 0.2)))
    return extra


_hx = hunt_extra(STRIDE_STEP, 0.56, 0.48)


def _hunt_keys():
    """Each step: contact, the drop (held: the weight landing), the body
    coming back up over the foot, the tall passing pose."""
    keys = []
    for o in (0.0, 0.5):
        keys += [
            (o + 0.0, {**_HUNT_HOLD, "hy": -0.3, "sq": 1.0, "sp": 3.0, "cp": -2.0, "np": 1.0}, ""),
            (o + 0.07, {"hy": -0.62, "sq": 0.955, "sp": 5.0, "cp": -1.0, "np": 5.0}, "h"),
            (o + 0.15, {"hy": -0.58, "sq": 0.975, "sp": 5.0, "np": 4.0}, ""),
            (o + 0.30, {"hy": -0.22, "sq": 1.0, "sp": 3.0, "cp": -2.0, "np": 0.0}, ""),
            (o + 0.42, {"hy": -0.14, "sq": 1.012, "sp": 2.5, "cp": -2.5, "np": 0.0}, ""),
        ]
    return [(t * HUNT_LEN, p, e) for t, p, e in keys]


clip(Clip("hunt_stride", HUNT_LEN, _hunt_keys(), loop=True, extra=_hx))

# ------------------------------------------------------------------ the charge (Olmec boss, phase 2)
## The tell, CHARGE_TELL s: he plants wide, the right foot ahead, drops the
## right shoulder low and forward (the run's quarter turn, deeper), the
## left fist cocked back; the back (left) foot scrapes the turf twice like
## a bull's (the game puffs dust at CHARGE_SCRAPES), then a held, coiled
## beat with a shiver through it. The game holds the last frame.
CHARGE_TELL = 1.25
CHARGE_SCRAPES = (0.6, 0.84)
_CH_COIL = {"hy": -1.12, "sq": 0.94, "hp": 10.0, "ht": 18.0, "hr": 2.0, "sp": 27.0, "st": 14.0, "sr": 4.0,
            "cp": 14.0, "ct": 30.0, "cr": 12.0, "np": -10.0, "nt": -42.0, "nr": -13.0,
            "aRp": 6.0, "aRo": 4.0, "aRt": 42.0, "eR": 98.0, "fR": 90.0, "tR": 40.0,
            "aLp": -46.0, "aLo": 16.0, "eL": 84.0, "fL": 92.0, "tL": 40.0,
            "kRz": 0.75, "kRx": 0.32, "kRp": 0.0, "kLz": -0.95, "kLx": 0.3, "kLy": 0.0, "kLp": -18.0}


def _tell_extra(t, v):
    k = smooth01(0.88, 0.98, t)
    v["hy"] += tremble(t, 0.022 * k)
    v["cr"] += tremble(t, 1.4 * k, 9.0, 1.0)
    v["aLp"] += tremble(t, 2.0 * k, 11.0, 2.0)
    v["np"] += tremble(t, 1.0 * k, 8.0, 3.0)


clip(Clip("charge_tell", CHARGE_TELL, [
    (0.0, {}, ""),
    # Planted: up a hair, chest high, the stump lifted at him.
    (0.16, {"hy": -0.32, "sq": 1.03, "sp": -2.0, "cp": -3.0, "np": -8.0, "kRz": 0.5, "kRx": 0.3, "kLz": -0.6,
            "kLx": 0.28, "aLp": 14.0, "aRp": 14.0, "eL": 30.0, "eR": 30.0, "fL": 70.0, "fR": 70.0}, ""),
    # The shoulder drops.
    (0.38, {**_CH_COIL, "hy": -1.2, "sq": 0.92, "cr": 15.0}, "o"),
    (0.46, {"hy": -1.06, "sq": 0.95, "cr": 12.0, "kLz": -0.95, "kLy": 0.0}, ""),
    # Scrape, scrape: the back foot drawn forward, then dragged back flat.
    (0.52, {"kLz": -0.45, "kLy": 0.32, "kLp": 8.0, "hy": -1.02}, ""),
    (CHARGE_SCRAPES[0], {"kLz": -1.45, "kLy": 0.0, "kLp": -24.0, "hy": -1.14, "sq": 0.93, "ct": 33.0}, "o"),
    (0.74, {"kLz": -0.5, "kLy": 0.3, "kLp": 8.0, "hy": -1.04, "ct": 30.0}, ""),
    (CHARGE_SCRAPES[1], {"kLz": -1.5, "kLy": 0.0, "kLp": -26.0, "hy": -1.16, "sq": 0.93, "ct": 34.0}, "o"),
    # The held beat, coiled lowest, leaning into it.
    (0.96, {"kLz": -1.2, "kLp": -20.0, "hy": -1.22, "sq": 0.92, "sp": 30.0, "hz": 0.15, "np": -12.0}, ""),
    (CHARGE_TELL, {"kLz": -1.2, "hy": -1.24, "sq": 0.92, "sp": 31.0, "hz": 0.2, "np": -12.0}, "h"),
], extra=_tell_extra))

## The charge's run: loop over two steps of CHARGE_STEP m, the shoulder
## run's lines pushed further: lower, pitched harder, the right shoulder
## turned further ahead and the arm locked in, the left arm driving short
## and hard, longer and flatter strides with a deeper drop on each contact.
CHARGE_STEP = 1.0 * HH
CHARGE_LEN = 0.84
_CH_HOLD = {"hp": 12.0, "ht": 18.0, "st": 14.0, "ct": 32.0, "sr": 4.0, "cr": 12.0, "nt": -44.0, "nr": -14.0,
            "aRo": 4.0, "aRt": 44.0, "fR": 88.0, "tR": 40.0, "fL": 80.0, "tL": 36.0}


def charge_extra(step, stance, lift):
    feet = gait(step, stance, lift, 0.74)

    def extra(t, v):
        u = t / CHARGE_LEN
        feet(u % 1.0, v)
        sn = math.sin(2 * math.pi * u + 0.35)
        v["hx"] += -0.22 * sn
        v["hr"] += -5.0 * sn
        v["sr"] += 2.5 * sn
        v["cr"] += 2.0 * math.sin(2 * math.pi * (u - 0.06) + 0.35)
        c = math.cos(2 * math.pi * u)
        v["ht"] += -6.0 * c
        v["ct"] += 6.0 * math.cos(2 * math.pi * (u - 0.06))
        pump = math.cos(2 * math.pi * (u - 0.07))
        v["aLp"] = 6.0 - 42.0 * pump
        v["aLo"] = 12.0 + 3.0 * max(0.0, pump)
        v["eL"] = 84.0 + 20.0 * max(0.0, -pump)
        jolt = math.cos(2 * math.pi * 2 * (u - 0.09))
        v["aRp"] = 4.0 + 4.0 * jolt
        v["eR"] = 100.0 - 5.0 * jolt
    return extra


_cx = charge_extra(CHARGE_STEP, 0.38, 0.85)


def _charge_keys():
    keys = []
    for o in (0.0, 0.5):
        keys += [
            (o + 0.0, {**_CH_HOLD, "hy": -0.9, "sq": 1.0, "sp": 28.0, "cp": 14.0, "np": -12.0}, ""),
            (o + 0.07, {"hy": -1.22, "sq": 0.955, "sp": 30.0, "cp": 15.0, "np": -10.0}, "h"),
            (o + 0.14, {"hy": -1.14, "sq": 0.975, "sp": 29.0}, ""),
            (o + 0.28, {"hy": -0.74, "sq": 1.015, "sp": 27.0, "cp": 13.0, "np": -13.0}, ""),
            (o + 0.40, {"hy": -0.62, "sq": 1.025, "sp": 26.5, "np": -14.0}, ""),
        ]
    return [(t * CHARGE_LEN, p, e) for t, p, e in keys]


clip(Clip("charge_run", CHARGE_LEN, _charge_keys(), loop=True, extra=_cx))

## The overrun, CHARGE_SKID s: missed, he throws his weight back and digs
## the leading foot in (the game slides him to a stop over CHARGE_SLIDE s),
## arms flung out for balance; his own speed pitches him on, a staggering
## step with the left, a hand slapped down on the turf to catch himself;
## held there bent over, heaving (the window to shoot him), then up.
CHARGE_SKID = 2.3
CHARGE_SLIDE = 0.62


def _skid_extra(t, v):
    # The slide's judder, then heaving breaths while he is down.
    k = smooth01(0.08, 0.14, t) * (1 - smooth01(0.5, 0.62, t))
    v["hy"] += tremble(t, 0.035 * k, 14.0)
    v["cr"] += tremble(t, 2.0 * k, 10.0, 1.0)
    b = smooth01(0.98, 1.1, t) * (1 - smooth01(1.7, 1.95, t))
    br = math.sin((t - 0.98) * 6.283 / 0.55)
    v["cp"] += -4.0 * br * b
    v["sp"] += -2.0 * br * b
    v["hy"] += 0.05 * br * b
    v["np"] += 3.0 * br * b


clip(Clip("charge_skid", CHARGE_SKID, [
    (0.0, {**_CH_HOLD, "hy": -0.9, "sp": 28.0, "cp": 14.0, "np": -12.0, "aRp": 6.0, "eR": 98.0, "aLp": 0.0,
           "eL": 88.0}, ""),
    # Dug in: the right heel driven ahead, the weight thrown back, the
    # shoulder squared, the arms flung out.
    (0.1, {"hy": -1.25, "sq": 0.9, "hz": -0.5, "hp": -6.0, "ht": 6.0, "sp": -10.0, "cp": -14.0, "ct": 8.0,
           "cr": 0.0, "st": 4.0, "np": 10.0, "nt": -10.0, "nr": 0.0,
           "kRz": 1.35, "kRy": 0.0, "kRp": 26.0, "kRx": 0.3, "kLz": -1.05, "kLy": 0.0, "kLp": -26.0, "kLx": 0.3,
           "aLp": 52.0, "aLo": 62.0, "eL": 30.0, "aRp": 40.0, "aRo": 58.0, "aRt": 10.0, "eR": 36.0,
           "fL": 30.0, "fR": 30.0, "tL": 20.0, "tR": 20.0}, "o"),
    (CHARGE_SLIDE - 0.08, {"hy": -1.2, "sq": 0.92, "hz": -0.45, "sp": -8.0, "cp": -12.0, "np": 8.0,
                           "aLo": 66.0, "aRo": 62.0}, "h"),
    # Pitched on: the left steps through, the trunk tips over.
    (CHARGE_SLIDE + 0.1, {"hy": -0.95, "sq": 1.03, "hz": 0.2, "hp": 10.0, "sp": 30.0, "cp": 16.0, "np": 16.0,
                          "kLz": 0.6, "kLy": 0.75, "kLp": 10.0, "kRz": 0.4, "kRp": 0.0,
                          "aLp": 40.0, "aLo": 40.0, "aRp": 60.0, "aRo": 30.0, "eR": 30.0}, ""),
    # Down: the foot slammed, the right hand on the turf, sunk.
    (CHARGE_SLIDE + 0.24, {"hy": -1.45, "sq": 0.86, "hz": 0.35, "hp": 14.0, "sp": 42.0, "cp": 14.0, "np": 26.0,
                           "ct": 4.0, "kLz": 1.15, "kLy": 0.0, "kLp": 0.0, "kRz": -0.55, "kRp": -40.0,
                           "hRx": 1.35, "hRy": 0.45, "hRz": 2.3, "hRw": 1.0, "fR": 70.0, "tR": 30.0,
                           "aLp": -30.0, "aLo": 44.0, "eL": 40.0, "fL": 70.0}, "i"),
    (CHARGE_SLIDE + 0.32, {"hy": -1.52, "sq": 0.84, "sp": 44.0, "np": 30.0, "hRy": 0.4}, "h"),
    # Held there, heaving (the window).
    (CHARGE_SLIDE + 0.5, {"hy": -1.38, "sq": 0.98, "sp": 40.0, "np": 24.0, "aLp": -20.0, "eL": 50.0}, ""),
    (1.75, {"hy": -1.36, "sq": 0.98, "sp": 40.0, "np": 22.0, "hRy": 0.5, "hRw": 1.0}, "h"),
    # Up: shoved off the hand, the stump shaken, squared.
    (1.98, {"hy": -0.55, "sq": 1.02, "hz": 0.1, "hp": 4.0, "sp": 14.0, "cp": 2.0, "np": 0.0, "nt": 8.0,
            "hRw": 0.0, "aRp": 10.0, "aRo": 18.0, "eR": 30.0, "aLp": 0.0, "aLo": 16.0, "eL": 24.0,
            "fL": 60.0, "fR": 60.0, "kLz": 0.35, "kRz": -0.25, "kRp": 0.0, "kRy": 0.0}, ""),
    (CHARGE_SKID, {"_base": 1}, ""),
], extra=_skid_extra))

## The impact stagger, CHARGE_STAGGER s: stopped short (a big stone, the
## rim's edge), the shoulder jams in, the whole of him squashed, the stump
## snapping back late; rocked back two steps, arms thrown out, dazed (a
## sway and a shake of the stump), then gathered and squared.
CHARGE_STAGGER = 1.7


def _stagger_extra(t, v):
    k = smooth01(0.5, 0.65, t) * (1 - smooth01(1.05, 1.25, t))
    v["nt"] += 16.0 * k * math.sin((t - 0.5) * 6.283 * 2.2)
    v["nr"] += 6.0 * k * math.sin((t - 0.5) * 6.283 * 1.1 + 0.6)
    v["sr"] += 5.0 * k * math.sin((t - 0.5) * 6.283 * 1.1)


clip(Clip("charge_stagger", CHARGE_STAGGER, [
    (0.0, {**_CH_HOLD, "hy": -0.9, "sp": 28.0, "cp": 14.0, "np": -12.0, "aRp": 6.0, "eR": 98.0, "aLp": 0.0,
           "eL": 88.0}, ""),
    # The blow: jammed into the shoulder, squashed flat.
    (0.06, {"hy": -1.35, "sq": 0.82, "hz": 0.2, "sp": 34.0, "cp": 18.0, "ct": 40.0, "cr": 16.0, "np": -18.0,
            "aRp": -10.0, "aRo": 20.0, "eR": 80.0, "aLp": 30.0, "aLo": 30.0, "eL": 50.0, "fR": 95.0}, "o"),
    # Rocked back: up and over backward, the stump snapping back late.
    (0.22, {"hy": -0.45, "sq": 1.06, "hz": -0.45, "hp": -8.0, "sp": -10.0, "cp": -14.0, "ct": 12.0, "cr": 2.0,
            "ht": 6.0, "st": 4.0, "np": -24.0, "nt": -14.0, "nr": 4.0,
            "aLp": 50.0, "aLo": 70.0, "eL": 30.0, "aRp": 40.0, "aRo": 64.0, "aRt": 10.0, "eR": 34.0,
            "fL": 30.0, "fR": 30.0, "kRz": 0.5, "kRy": 0.35, "kRp": 10.0, "kLz": -0.6}, ""),
    # A step back with the right, planted; then the left.
    (0.36, {"hy": -0.95, "sq": 0.93, "hz": -0.55, "sp": 4.0, "cp": -6.0, "np": -6.0, "kRz": -0.85, "kRy": 0.0,
            "kRp": 0.0, "kLz": -0.2}, "o"),
    (0.5, {"kLz": -0.4, "kLy": 0.45, "hy": -0.75, "sq": 1.0}, ""),
    (0.62, {"kLz": -1.0, "kLy": 0.0, "hy": -1.0, "sq": 0.95, "sp": 14.0, "cp": 4.0, "np": 8.0,
            "aLp": 20.0, "aLo": 40.0, "aRp": 18.0, "aRo": 40.0, "eL": 50.0, "eR": 50.0, "fL": 50.0,
            "fR": 50.0}, "o"),
    # Dazed, swaying; then gathered, the fists closed.
    (1.0, {"hy": -0.9, "sp": 16.0, "np": 10.0, "aLo": 30.0, "aRo": 30.0}, ""),
    (1.3, {"hy": -0.5, "sq": 1.02, "sp": 10.0, "cp": 6.0, "np": -4.0, "ct": 0.0, "fL": 85.0, "fR": 85.0,
           "kLz": -0.45, "kRz": -0.4, "aLp": 6.0, "aRp": 6.0, "aLo": 16.0, "aRo": 16.0, "eL": 30.0, "eR": 30.0}, ""),
    (CHARGE_STAGGER, {"_base": 1}, ""),
], extra=_stagger_extra))

# ------------------------------------------------------------------ climb
CLIMB_LEN = 2.0
WALL_WRIST = CLIMB_WALL - 0.42
WALL_ANKLE = CLIMB_WALL - 0.95


def climb_extra(t, v):
    """Hand over hand: each hand planted at the top of its reach and held
    to the wall as the body rises past it, then let go and slapped up
    again; the feet push on the wall the same way, a beat after the other
    hand. The root rises CLIMB_RISE over the loop."""
    u = (t / CLIMB_LEN) % 1.0
    plant = 0.7
    top, bottom = SHOULDER_Y + 2.0, SHOULDER_Y + 2.0 - plant * CLIMB_RISE
    for n, s, off in (("L", -1, 0.0), ("R", 1, 0.5)):
        w = (u - off) % 1.0
        if w < plant:
            y = top - CLIMB_RISE * w
            z = WALL_WRIST
            f = 55.0
        else:
            k = (w - plant) / (1 - plant)
            e = smooth01(0.0, 0.8, k)
            y = bottom + (top - bottom) * e
            z = WALL_WRIST - 0.75 * math.sin(math.pi * min(1.0, k / 0.85))
            f = 55.0 - 50.0 * math.sin(math.pi * min(1.0, k / 0.9))
        v[f"h{n}x"] = s * 1.55
        v[f"h{n}y"] = y + v["hy"] * 0.0
        v[f"h{n}z"] = z
        v[f"h{n}w"] = 1.0
        v[f"p{n}w"] = 1.0
        v[f"p{n}fx"], v[f"p{n}fy"], v[f"p{n}fz"] = s * 0.1, 1.0, 0.0
        v[f"p{n}nx"], v[f"p{n}ny"], v[f"p{n}nz"] = 0.0, 0.0, 1.0
        v[f"f{n}"] = f
        v[f"t{n}"] = 20.0
    # Feet: the right with the left hand, a beat later.
    fplant = 0.62
    ftop = 1.7
    for n, s, off in (("R", 1, 0.08), ("L", -1, 0.58)):
        w = (u - off) % 1.0
        if w < fplant:
            y = ftop - CLIMB_RISE * w
            z = WALL_ANKLE
            p = 8.0
        else:
            k = (w - fplant) / (1 - fplant)
            e = smooth01(0.05, 0.85, k)
            y = ftop - CLIMB_RISE * fplant + CLIMB_RISE * fplant * e
            z = WALL_ANKLE - 0.55 * math.sin(math.pi * k)
            p = -25.0 * math.sin(math.pi * k)
        v[f"k{n}y"] = y
        v[f"k{n}z"] = z
        v[f"k{n}p"] = p
        v[f"k{n}x"] = 0.05
    # The body sways to the pulling hand and heaves after each grab.
    v["hx"] += 0.22 * math.sin(2 * math.pi * u - 0.6)
    v["sr"] += 4.0 * math.sin(2 * math.pi * u - 0.9)
    v["ct"] += 7.0 * math.sin(2 * math.pi * u - 1.1)
    v["nr"] += -5.0 * math.sin(2 * math.pi * u - 1.5)
    heave = math.sin(4 * math.pi * u - 0.9)
    v["hy"] += 0.12 * heave
    v["cp"] += -2.5 * heave


clip(Clip("climb", CLIMB_LEN, [
    (0.0, {"hy": -0.2, "sp": -2.0, "cp": -4.0, "np": -14.0, "hz": -0.1}, ""),
], loop=True, extra=climb_extra))


# ------------------------------------------------------------------ haul (hands on the lip)
def haul_extra(wild):
    def extra(t, v):
        u = (t / 2.4) % 1.0
        for n, s in SIDES:
            v[f"h{n}x"] = s * 1.5
            v[f"h{n}y"] = SHOULDER_Y + 2.3
            v[f"h{n}z"] = CLIMB_WALL + 0.25
            v[f"h{n}w"] = 1.0
            v[f"p{n}w"] = 1.0
            v[f"p{n}fx"], v[f"p{n}fy"], v[f"p{n}fz"] = s * 0.1, 0.0, 1.0
            v[f"p{n}nx"], v[f"p{n}ny"], v[f"p{n}nz"] = 0.0, -1.0, 0.0
            v[f"f{n}"] = 75.0
            v[f"t{n}"] = 35.0
        # The legs scrabbling at the wall, out of step with the heaves.
        for n, s, off in (("L", -1, 0.0), ("R", 1, 0.45)):
            w = (u - off) % 1.0
            kick = math.sin(2 * math.pi * w) * (1.0 + 0.6 * wild)
            v[f"k{n}y"] = 0.9 + 0.55 * kick + 0.4 * wild * math.sin(4 * math.pi * w + 1.0)
            v[f"k{n}z"] = WALL_ANKLE - 0.15 - 0.3 * max(0.0, -kick)
            v[f"k{n}p"] = -20.0 * kick
            v[f"k{n}x"] = 0.1 + 0.15 * wild * math.sin(2 * math.pi * w)
        # Two heaves a loop: the body gathers, then hauls (held at the top).
        for o in (0.0, 0.5):
            w = (u - o) % 1.0
            h = smooth01(0.0, 0.12, w) * (1 - smooth01(0.3, 0.5, w))
            g = math.sin(math.pi * smooth01(0.38, 0.5, w))
            v["hy"] += (0.22 + 0.2 * wild) * h - 0.1 * g
            v["cp"] += -6.0 * h
            v["np"] += -(8.0 + 10 * wild) * h
            side = 1 if o == 0.0 else -1
            v["cr"] += side * (3.0 + 4 * wild) * h
            v["ct"] += side * (5.0 + 5 * wild) * h
            v["nr"] += -side * (4.0 + 6 * wild) * h
            v["sq"] *= 1.0 + 0.03 * h
        v["nt"] += 6.0 * wild * math.sin(2 * math.pi * u * 2 + 0.4)
    return extra


clip(Clip("haul", 2.4, [(0.0, {"hy": -0.1, "sp": -2.0, "cp": -6.0, "np": -12.0, "hz": -0.15}, "")],
          loop=True, extra=haul_extra(0.0)))
clip(Clip("spawn_haul", 2.4, [(0.0, {"hy": -0.1, "sp": -4.0, "cp": -8.0, "np": -18.0, "hz": -0.15}, "")],
          loop=True, extra=haul_extra(1.0)))


# ------------------------------------------------------------------ mantle (round 4)
## Up over the lip, MANTLE s, two ways (the game's `mantle_pull` knob):
##   mantle       the press: from the climb's end, hands on the lip at his
##                chest. A gather (he sinks, the elbows bend, the stump
##                bows), a hard press down through the arms that pops him up
##                (the hands leave the lip at the top of the press), the
##                legs tucked under him as he rises past the lip, a held
##                beat at the top, then down onto it: a heavy squash, held,
##                a rebound and the settle.
##   mantle_pull  the pull-up: from a hang (his hands just slapped onto a
##                lip over his head). Knees tucked, a hard pull that brings
##                his chest to the lip, let go, popped on up past it, the
##                feet swung under him, then the same landing.
## The game moves the root on these same curves (headless_body.gd
## `_mantle_up`), rise R from where it started to the top (MANTLE_UP or
## PULL_UP here) and over MANTLE_OVER, and pins the hands on the real lip
## till they let go. LAND_K is when the feet come down on the top.
PULL_UP = SHOULDER_Y + 2.0
## The wrists on the lip: this far out from the face (the forearm up the face
## outside it, the hand laid flat over the edge), 0.5 over the top.
LIP_OUT = 0.65
LAND_K = 0.66
PULL_LAND_K = 0.68


def mantle_up(k, pull=False):
    """The root's rise over the mantle at `k` (0 to 1), a share of the
    whole rise (over 1 at the top of the pop)."""
    if not pull:
        if k < 0.2: return -0.07 * smooth01(0.0, 0.2, k)
        if k < 0.36:
            e = (k - 0.2) / 0.16
            return -0.07 + 0.40 * e * e
        if k < 0.5:
            e = (k - 0.36) / 0.14
            return 0.33 + 0.78 * (1 - (1 - e) ** 2)
        if k < 0.56: return 1.11
        if k < LAND_K:
            e = (k - 0.56) / (LAND_K - 0.56)
            return 1.11 - 0.11 * e * e
        return 1.0
    if k < 0.18: return -0.03 * smooth01(0.0, 0.18, k)
    if k < 0.4: return -0.03 + 0.4 * smooth01(0.18, 0.4, k)
    if k < 0.56:
        e = (k - 0.4) / 0.16
        return 0.37 + 0.71 * (1 - (1 - e) ** 2)
    if k < 0.6: return 1.08
    if k < PULL_LAND_K:
        e = (k - 0.6) / (PULL_LAND_K - 0.6)
        return 1.08 - 0.08 * e * e
    return 1.0


def mantle_over(k, pull=False):
    return smooth01(0.48, 0.66, k) if pull else smooth01(0.42, 0.64, k)


def mantle_root(k, pull=False):
    """Where the game has the root over the mantle (at the defaults):
    (up, forward) off where it started."""
    return (PULL_UP if pull else MANTLE_UP) * mantle_up(k, pull), MANTLE_OVER * mantle_over(k, pull)


def mantle_release(k, pull=False):
    """The hands' hold on the lip (1 planted, 0 let go)."""
    return 1.0 - (smooth01(0.38, 0.44, k) if pull else smooth01(0.34, 0.42, k))


def mantle_extra_of(pull):
    rise = PULL_UP if pull else MANTLE_UP

    def extra(t, v):
        k = t / MANTLE
        up, over = mantle_root(k, pull)
        w = mantle_release(k, pull)
        for n, s in SIDES:
            if w > 0.0:
                v[f"h{n}x"] = s * 1.7
                v[f"h{n}y"] = rise + 0.5 - up
                v[f"h{n}z"] = CLIMB_WALL - LIP_OUT - over
                v[f"h{n}w"] = w
                v[f"p{n}w"] = w
                v[f"p{n}fx"], v[f"p{n}fy"], v[f"p{n}fz"] = s * 0.2, 0.0, 1.0
                v[f"p{n}nx"], v[f"p{n}ny"], v[f"p{n}nz"] = 0.0, -1.0, 0.0
                v[f"f{n}"] = 4.0
                v[f"t{n}"] = 8.0
    return extra


def _landing(k0):
    """The heavy landing on the top, from `k0` (shares of MANTLE)."""
    return [
        (k0, {"hy": -1.0, "sq": 0.8, "sp": 26.0, "cp": 8.0, "np": 18.0, "aLp": -10.0, "aRp": -10.0, "aLo": 38.0,
              "aRo": 38.0, "eL": 14.0, "eR": 14.0, "fL": 90.0, "fR": 90.0, "kLx": 0.3, "kRx": 0.3, "kLy": 0.0,
              "kRy": 0.0, "kLz": 0.15, "kRz": -0.1, "kLp": 0.0, "kRp": 0.0}, "i"),
        (k0 + 0.06, {"hy": -1.12, "sq": 0.77, "sp": 30.0, "np": 22.0}, "h"),
        (k0 + 0.16, {"hy": -0.62, "sq": 1.04, "sp": 18.0, "np": 8.0, "aLo": 28.0, "aRo": 28.0}, ""),
        (k0 + 0.24, {"hy": -0.74, "sq": 0.98, "sp": 20.0, "np": 10.0, "aLp": 4.0, "aRp": 4.0, "fL": 60.0,
                     "fR": 60.0}, "o"),
        (1.0, {"_base": 1, "hy": -0.2, "sp": 8.0}, ""),
    ]


def _mk(keys):
    return [(k * MANTLE, p, e) for k, p, e in keys]


clip(Clip("mantle", MANTLE, _mk([
    # From the climb's end: hands on the lip at his chest, feet on the face.
    (0.0, {"hy": -0.1, "sp": -2.0, "cp": -4.0, "np": -10.0, "kLy": 0.4, "kLz": -0.25, "kRy": 0.5,
           "kRz": -0.25}, ""),
    # The gather: sunk, the elbows bent, the stump bowed, the legs hanging.
    (0.2, {"hy": -0.45, "sq": 0.93, "sp": -4.0, "cp": -5.0, "np": 12.0, "kLy": 0.25, "kRy": 0.3, "kLz": -0.35,
           "kRz": -0.35}, "h"),
    # The press: up and long, the legs driving down.
    (0.36, {"hy": 0.05, "sq": 1.1, "sp": -8.0, "cp": -6.0, "np": -10.0, "kLy": 0.0, "kRy": 0.0, "kLz": -0.3,
            "kRz": -0.3, "kLp": -30.0, "kRp": -30.0}, ""),
    # Popped: the hands off, the arms flung out, the knees tucked under.
    (0.47, {"hy": 0.1, "sq": 1.0, "sp": 16.0, "cp": 6.0, "np": 6.0, "kLy": 1.7, "kRy": 1.7, "kLz": 0.2,
            "kRz": 0.2, "kLp": 10.0, "kRp": 10.0, "aLp": 30.0, "aRp": 30.0, "aLo": 48.0, "aRo": 48.0, "eL": 40.0,
            "eR": 40.0, "fL": 85.0, "fR": 85.0}, "o"),
    (0.56, {"kLy": 1.6, "kRy": 1.6, "aLo": 52.0, "aRo": 52.0}, "h"),
    # The legs down for the top.
    (0.62, {"hy": -0.05, "sq": 1.05, "sp": 10.0, "np": 2.0, "kLy": 0.35, "kRy": 0.3, "kLz": 0.15, "kRz": -0.05,
            "kLx": 0.25, "kRx": 0.25, "aLp": 10.0, "aRp": 10.0, "aLo": 56.0, "aRo": 56.0}, ""),
] + _landing(LAND_K)), extra=mantle_extra_of(False)))

clip(Clip("mantle_pull", MANTLE, _mk([
    # From the hang: hands on the lip over his head, legs on the face.
    (0.0, {"hy": -0.1, "sp": -4.0, "cp": -6.0, "np": -12.0, "kLy": 0.35, "kRy": 0.25, "kLz": -0.3,
           "kRz": -0.3, "kLp": -10.0, "kRp": -10.0}, ""),
    # The gather: knees tucked, the stump tipped up at the lip.
    (0.18, {"hy": 0.1, "sq": 0.94, "sp": -4.0, "cp": -6.0, "np": -18.0, "kLy": 1.3, "kRy": 1.3, "kLz": -0.6,
            "kRz": -0.6, "kLp": 15.0, "kRp": 15.0}, "h"),
    # The pull: chest to the lip, the legs kicked down and straight.
    (0.4, {"hy": 0.2, "sq": 1.08, "sp": -12.0, "cp": -10.0, "np": -8.0, "kLy": 0.1, "kRy": 0.1, "kLz": -0.4,
           "kRz": -0.4, "kLp": -30.0, "kRp": -30.0, "aLp": 150.0, "aRp": 150.0, "aLo": 25.0, "aRo": 25.0,
           "eL": 20.0, "eR": 20.0, "fL": 30.0, "fR": 30.0}, ""),
    # Let go and popped: arms flung up and out, knees up under him.
    (0.5, {"hy": 0.1, "sq": 1.0, "sp": 18.0, "cp": 6.0, "np": 8.0, "kLy": 1.8, "kRy": 1.8, "kLz": 0.3,
           "kRz": 0.3, "kLp": 10.0, "kRp": 10.0, "aLp": 70.0, "aRp": 70.0, "aLo": 65.0, "aRo": 65.0, "eL": 40.0,
           "eR": 40.0, "fL": 85.0, "fR": 85.0}, "o"),
    (0.6, {"kLy": 1.7, "kRy": 1.7, "aLo": 54.0, "aRo": 54.0}, "h"),
    (0.64, {"hy": -0.05, "sq": 1.05, "sp": 10.0, "np": 2.0, "kLy": 0.35, "kRy": 0.3, "kLz": 0.15, "kRz": -0.05,
            "kLx": 0.25, "kRx": 0.25, "aLp": 10.0, "aRp": 10.0, "aLo": 56.0, "aRo": 56.0}, ""),
] + _landing(PULL_LAND_K)), extra=mantle_extra_of(True)))

# ------------------------------------------------------------------ windup
W_ = WINDUP


def windup_extra(t, v):
    # Coiled: a shiver through it.
    k = smooth01(0.4, 0.55, t) * (1 - smooth01(1.0, 1.1, t))
    v["hy"] += tremble(t, 0.018 * k)
    for n, s in SIDES:
        v[f"a{n}p"] += tremble(t, 1.6 * k, 11.0, 1.0 + s)
    v["np"] += tremble(t, 1.2 * k, 9.0, 2.0)


clip(Clip("windup", W_, [
    (0.0, {}, ""),
    (0.12, {"hy": 0.05, "sp": -3.0, "cp": -4.0, "np": -6.0, "aLp": 18.0, "aRp": 18.0, "eL": 24.0, "eR": 24.0,
            "sq": 1.03}, ""),
    (0.36, {"hy": -1.0, "sp": 26.0, "cp": 14.0, "np": 18.0, "aLp": -62.0, "aRp": -62.0, "aLo": 18.0,
            "aRo": 18.0, "eL": 12.0, "eR": 12.0, "kLx": 0.25, "kRx": 0.25, "kLz": -0.3, "kRz": 0.25,
            "fL": 80.0, "fR": 80.0, "sq": 0.95}, "o"),
    (0.84, {"hy": -1.1, "sp": 29.0, "cp": 15.0, "np": 20.0, "aLp": -74.0, "aRp": -74.0, "sq": 0.94}, ""),
    (0.98, {"hy": -1.16, "sp": 31.0, "aLp": -84.0, "aRp": -84.0, "aLo": 22.0, "aRo": 22.0, "sq": 0.93}, "h"),
    (1.1, {"hy": -0.75, "sp": 20.0, "cp": 6.0, "np": 6.0, "aLp": -10.0, "aRp": -10.0, "eL": 30.0, "eR": 30.0,
           "sq": 1.0}, ""),
], extra=windup_extra))

# ------------------------------------------------------------------ in the air
AIR = 1.2
clip(Clip("jump_air", AIR, [
    (0.0, {"hy": -0.05, "sp": 14.0, "cp": 4.0, "np": -4.0, "aLp": 150.0, "aRp": 150.0, "aLo": 14.0, "aRo": 14.0,
           "eL": 20.0, "eR": 20.0, "kLy": -0.05, "kRy": -0.1, "kLz": -0.7, "kRz": -0.5, "kLp": -45.0,
           "kRp": -40.0, "sq": 1.1, "fL": 20.0, "fR": 20.0}, ""),
    (0.16 * AIR, {"aLp": 168.0, "aRp": 168.0, "sp": 4.0, "sq": 1.06}, ""),
    (0.4 * AIR, {"hy": 0.1, "sp": -6.0, "cp": -6.0, "np": -10.0, "aLp": 70.0, "aRp": 70.0, "aLo": 72.0,
                 "aRo": 72.0, "eL": 28.0, "eR": 28.0, "kLy": 1.15, "kRy": 1.0, "kLz": 0.45, "kRz": 0.25,
                 "kLp": 10.0, "kRp": 5.0, "sq": 1.0, "fL": 10.0, "fR": 10.0}, ""),
    (0.62 * AIR, {"aLo": 78.0, "aRo": 78.0, "kLy": 1.2, "kRy": 1.05}, ""),
    (0.84 * AIR, {"hy": 0.0, "sp": 6.0, "np": 4.0, "aLp": 130.0, "aRp": 130.0, "aLo": 30.0, "aRo": 30.0,
                  "eL": 25.0, "eR": 25.0, "kLy": 0.1, "kRy": 0.05, "kLz": 0.25, "kRz": 0.1, "kLp": 0.0,
                  "kRp": 0.0, "kLx": 0.3, "kRx": 0.3, "fL": 85.0, "fR": 85.0}, ""),
    (AIR, {"aLp": 148.0, "aRp": 148.0, "kLy": -0.08, "kRy": -0.08, "sq": 1.04}, ""),
]))
clip(Clip("drop_air", AIR, [
    (0.0, {"hy": -0.3, "sp": 22.0, "cp": 8.0, "np": 12.0, "aLp": 60.0, "aRp": 60.0, "kLz": -0.4, "kLy": 0.3,
           "kLp": -30.0, "sq": 1.05}, ""),
    (0.2 * AIR, {"hy": 0.0, "sp": -2.0, "cp": -4.0, "np": -8.0, "aLp": 170.0, "aRp": 170.0, "aLo": -16.0,
                 "aRo": -16.0, "eL": 30.0, "eR": 30.0, "fL": 95.0, "fR": 95.0, "tL": 45.0, "tR": 45.0,
                 "kLx": -0.25, "kRx": -0.25, "kLy": -0.1, "kRy": -0.1, "kLz": 0.0, "kLp": -35.0, "kRp": -35.0,
                 "sq": 1.1}, "o"),
    (0.6 * AIR, {"sp": 0.0, "aLp": 176.0, "aRp": 176.0, "sq": 1.12}, ""),
    (0.88 * AIR, {"sp": 6.0, "np": 4.0, "aLp": 180.0, "aRp": 180.0, "eL": 40.0, "eR": 40.0, "kLy": 0.2,
                  "kRy": 0.2, "kLp": -10.0, "kRp": -10.0, "kLx": 0.1, "kRx": 0.1, "sq": 1.08}, ""),
    (AIR, {"aLp": 182.0, "aRp": 182.0, "eL": 46.0, "eR": 46.0}, ""),
], extra=lambda t, v: v.__setitem__("np", v["np"] + tremble(t, 1.5, 3.0))))

# ------------------------------------------------------------------ landings
clip(Clip("land", LAND, [
    (0.0, {"hy": -1.05, "sp": 28.0, "cp": 10.0, "np": 16.0, "aLp": -12.0, "aRp": -12.0, "aLo": 38.0,
           "aRo": 38.0, "eL": 10.0, "eR": 10.0, "fL": 92.0, "fR": 92.0, "kLx": 0.33, "kRx": 0.33,
           "kLz": 0.1, "kRz": -0.1, "sq": 0.8}, ""),
    (0.05, {"hy": -1.22, "sp": 32.0, "np": 22.0, "sq": 0.76}, "h"),
    (0.17, {"hy": -0.72, "sp": 20.0, "np": 8.0, "sq": 1.05, "aLo": 30.0, "aRo": 30.0}, ""),
    (0.28, {"hy": -0.86, "sp": 24.0, "np": 12.0, "sq": 0.98, "aLp": 6.0, "aRp": 6.0, "eL": 22.0, "eR": 22.0}, "o"),
    (0.6, {"hy": -0.8, "sp": 22.0, "cp": 6.0, "np": 10.0, "sq": 1.0, "fL": 70.0, "fR": 70.0}, ""),
    (0.84, {"hy": -0.18, "sp": 6.0, "cp": -5.0, "np": -4.0, "aLp": -6.0, "aRp": -6.0, "aLo": 12.0,
            "aRo": 12.0, "kLx": 0.15, "kRx": 0.15, "kLz": 0.0, "kRz": 0.0, "fL": 35.0, "fR": 35.0}, ""),
    (1.0, {"_base": 1}, ""),
]))
clip(Clip("drop_land", LAND, [
    # A fist into the ground, the left knee down, the left arm flung back.
    (0.0, {"hy": -1.3, "hz": -0.1, "sp": 40.0, "cp": 12.0, "np": 24.0, "ct": -10.0,
           "hRx": 1.25, "hRy": 0.55, "hRz": 1.65, "hRw": 1.0, "fR": 95.0, "tR": 45.0,
           "aLp": -50.0, "aLo": 52.0, "eL": 20.0, "fL": 60.0,
           "kRz": 0.75, "kRx": 0.2, "kLz": -1.25, "kLy": -0.05, "kLp": -55.0, "sq": 0.78}, ""),
    (0.06, {"hy": -1.4, "sp": 44.0, "np": 30.0, "sq": 0.74, "hRy": 0.45}, "h"),
    (0.18, {"hy": -1.25, "sp": 38.0, "np": 20.0, "sq": 1.02, "aLp": -40.0}, ""),
    (0.55, {"hy": -1.28, "sp": 40.0, "np": 22.0, "sq": 1.0, "aLp": -44.0}, "o"),
    (0.78, {"hy": -0.5, "hz": 0.0, "sp": 14.0, "cp": 2.0, "np": 4.0, "ct": 0.0, "hRw": 0.0, "fR": 60.0,
            "aRp": 10.0, "aRo": 14.0, "aLp": -5.0, "aLo": 14.0, "kRz": 0.25, "kLz": -0.3, "kLy": 0.0,
            "kLp": 0.0, "sq": 1.02}, ""),
    (1.0, {"_base": 1}, ""),
]))

# ------------------------------------------------------------------ reunion
S_ = SETTLE
clip(Clip("reach", S_, [
    (0.0, {"aLp": 66.0, "aRp": 66.0, "aLo": 16.0, "aRo": 16.0, "eL": 28.0, "eR": 28.0, "sp": 12.0, "np": 8.0}, ""),
    (0.24, {"hy": -0.42, "sp": 18.0, "cp": 6.0, "np": 10.0, "aLp": 8.0, "aRp": 8.0, "aLo": 10.0, "aRo": 10.0,
            "eL": 30.0, "eR": 30.0, "sq": 0.96}, ""),
    (0.6, {"hy": -0.05, "sp": -8.0, "cp": -8.0, "np": -20.0, "aLp": 162.0, "aRp": 162.0, "aLo": 26.0,
           "aRo": 26.0, "eL": 30.0, "eR": 30.0, "fL": 8.0, "fR": 8.0, "tL": 0.0, "tR": 0.0, "wLt": 40.0,
           "wRt": 40.0, "sq": 1.03}, "o"),
    (1.2, {"aLp": 150.0, "aRp": 150.0, "aLo": 30.0, "aRo": 30.0, "np": -14.0, "sp": -4.0}, ""),
    (1.85, {"aLp": 124.0, "aRp": 124.0, "aLo": 40.0, "aRo": 40.0, "eL": 70.0, "eR": 70.0, "np": -2.0,
            "sp": 2.0, "cp": -2.0, "fL": 30.0, "fR": 30.0}, ""),
    (2.1, {"aLp": 112.0, "aRp": 112.0, "aLo": 44.0, "aRo": 44.0, "eL": 86.0, "eR": 86.0, "np": 0.0,
           "hy": -0.12}, ""),
    (2.2, {"hy": -0.3, "sq": 0.93, "fL": 45.0, "fR": 45.0}, "h"),
], extra=lambda t, v: [v.__setitem__(c, v[c] + tremble(t, 1.4 * smooth01(0.6, 0.8, t) * (1 - smooth01(1.6, 1.85, t)), 12.0, i))
                      for i, c in enumerate(("aLp", "aRp", "np"))]))
T_ = TRIUMPH
clip(Clip("triumph", T_, [
    (0.0, {"hy": -0.3, "sq": 0.95, "aLp": 112.0, "aRp": 112.0, "aLo": 44.0, "aRo": 44.0, "eL": 86.0, "eR": 86.0,
           "fL": 45.0, "fR": 45.0}, ""),
    (0.2, {"hy": -0.62, "sp": 24.0, "cp": 10.0, "np": 16.0, "aLp": 40.0, "aRp": 40.0, "aLo": 8.0, "aRo": 8.0,
           "eL": 125.0, "eR": 125.0, "fL": 96.0, "fR": 96.0, "tL": 45.0, "tR": 45.0, "sq": 0.94}, "o"),
    (0.38, {"hy": 0.08, "sp": -14.0, "cp": -10.0, "np": -16.0, "aLp": 166.0, "aRp": 166.0, "aLo": 46.0,
            "aRo": 46.0, "eL": 10.0, "eR": 10.0, "sq": 1.08}, ""),
    (0.5, {"hy": 0.0, "sp": -12.0, "sq": 1.03}, ""),
    (1.05, {"sp": -13.0, "np": -14.0, "aLp": 170.0, "aRp": 170.0}, "h"),
    # Then both fists down, a thud.
    (1.18, {"hy": 0.05, "aLp": 178.0, "aRp": 178.0, "eL": 40.0, "eR": 40.0, "sp": -8.0}, ""),
    (1.34, {"hy": -0.5, "sp": 22.0, "cp": 8.0, "np": 12.0, "aLp": -6.0, "aRp": -6.0, "aLo": 26.0, "aRo": 26.0,
            "eL": 14.0, "eR": 14.0, "sq": 0.9, "kLx": 0.3, "kRx": 0.3}, "i"),
    (1.42, {"hy": -0.56, "sq": 0.89}, "h"),
    (1.8, {"_base": 1}, ""),
], extra=lambda t, v: [v.__setitem__(c, v[c] + tremble(t, 1.6 * smooth01(0.45, 0.55, t) * (1 - smooth01(1.0, 1.1, t)), 13.0, i))
                      for i, c in enumerate(("aLp", "aRp", "np"))]))

# ------------------------------------------------------------------ turning on the spot (round 4)
## One step of a turn, STEP s: the game turns him (the root) through the
## step's angle while the swing foot is up (from 0.18 to 0.6 of it) and
## holds the other foot where it stands; these are the body's beats over
## it. The anticipation (the weight onto the standing foot, a dip, the hips
## turned a hair against the turn), the lift (the hips leading into the
## turn, the shoulders and the stump lagging), the plant (fast and flat, a
## squash held, the shoulders swinging past), the settle. The feet here go
## up and down on their spot; the game carries them round (the swing foot
## from where it stood to under the turned hips). Only the trunk and legs
## are blended in (the arms keep what the body is doing).
##   turn_open_l   turning left, the left foot stepping out (on the right)
##   turn_close_l  turning left, the right foot stepping round (on the left)
##   turn_open_r / turn_close_r  their mirrors
STEP = 0.66


def _step_keys(n, s, lift, lead, lag):
    """A step of foot `n` (side `s`) turning toward the stepping foot's side
    (s = -1 left), `lift` m up, the hips `lead` deg ahead, the shoulders
    `lag` deg behind. Twists are + left, so a left turn's lead is +.

    Olmec round 1: the
    poses pushed so they read on a 10 m stone giant at play distance. The
    weight goes well over onto the standing leg and he sinks into it (the
    game holds this pose through a turn's lead-in); the foot comes up high,
    knee forward, the hips swung into the turn, the shoulders and stump left
    behind and the arms swinging with them; the foot comes down flat and
    hard into a deep held squash, the shoulders and arms swinging on past;
    then he rises and settles."""
    t = -s     # + turning left
    o = "R" if n == "L" else "L"
    keys = [
        (0.0, {}, ""),
        # Anticipation: the weight over onto the standing foot, sunk, the
        # hips turned a little against the turn, the stepping heel up.
        (0.15, {"hx": -s * 0.55, "hy": -0.42, "sq": 0.95, "hr": -s * 6.0, "sr": -s * 4.0, "cr": -s * 2.0,
                "ht": -t * 4.0, "ct": t * 3.0, f"k{n}p": -10.0, f"k{n}y": 0.27,
                f"a{n}o": 17.0, f"a{o}o": 8.0, "np": 4.0}, ""),
        # The lift: the foot up high, knee forward, the hips swung into the
        # turn and up off the standing leg; shoulders and stump left behind;
        # the arms swung by them (the outside arm across, the inside out).
        (0.32, {f"k{n}y": lift, f"k{n}z": 0.35, f"k{n}p": 10.0, f"k{n}x": 0.3, "ht": t * lead, "ct": -t * lag,
                "nt": -t * lag * 0.6, "hy": 0.02, "sq": 1.04, "hx": -s * 0.5, "hr": -s * 3.0, "sr": -s * 2.0,
                "sp": 2.0, f"a{n}o": 26.0, f"a{n}p": -10.0, f"e{n}": 20.0, f"a{o}p": 20.0, f"e{o}": 26.0}, ""),
        (0.47, {f"k{n}y": lift * 0.55, f"k{n}z": 0.2, f"k{n}p": 6.0, "ht": t * lead * 0.7, "ct": -t * lag * 0.2,
                "nt": -t * lag * 0.3, "hy": -0.08, "sq": 1.01, "hx": -s * 0.3}, ""),
        # The plant: flat and hard, the weight dropped between the feet into
        # a deep squash; the shoulders, stump and arms swing on past.
        (0.6, {f"k{n}y": 0.0, f"k{n}z": 0.0, f"k{n}p": 0.0, f"k{n}x": 0.2, "hy": -0.5, "sq": 0.91, "hx": -s * 0.08,
               "hr": 0.0, "sr": 0.0, "cr": 0.0, "ht": t * 3.0, "ct": t * lag * 0.6, "nt": t * lag * 0.6, "sp": 9.0,
               "np": 3.0, f"a{n}o": 14.0, f"a{n}p": 12.0, f"e{n}": 22.0, f"a{o}p": -8.0, f"e{o}": 18.0}, "i"),
        (0.7, {"hy": -0.52, "sq": 0.905}, "h"),
        # Up and settled.
        (0.86, {"hy": -0.1, "sq": 1.01, "ct": t * 1.0, "nt": t * 1.5, "hx": -s * 0.02, "ht": 0.0,
                f"k{n}x": 0.12, "sp": 5.0, f"a{n}p": 6.0, f"a{o}p": 2.0}, ""),
        (1.0, {"_base": 1}, ""),
    ]
    return [(u * STEP, p, e) for u, p, e in keys]


clip(Clip("turn_open_l", STEP, _step_keys("L", -1, 0.8, 14.0, 10.0)))
# The closing step: the right foot comes round under him, the weight on the
# left (the turn still to the left: the leads keep their sign).
clip(Clip("turn_close_l", STEP, [
    (t, {c: (-x if c in ("ht", "ct", "nt") else x) for c, x in p.items()}, e) for t, p, e in _step_keys("R", 1, 0.62, 10.0, 7.0)
]))
clip(Mirror("turn_open_r", CLIPS[-2]))
clip(Mirror("turn_close_r", CLIPS[-2]))

# ------------------------------------------------------------------ whole turns on the spot (olmec-turn)
## A whole turn authored as one clip, the root yawed through it (`ry`): the
## game reads the yaw off the root's track, turns the figure by it and keeps
## the root's own turn out of the pose (headless_body_steps.gd), so the
## feet, planted in the clip's start frame, stay where they are on the
## ground while the trunk comes round over them. Each step's foot swings on
## an arc round the middle, from its stance at one yaw to its stance at the
## next; the root's yaw is the feet's mean, eased from lift to plant. The
## trunk's beats are keyed per clip: the weight loaded onto the pivot foot
## and a sink, the shoulders wound against the turn, then leading it, each
## plant dropped flat and hard into a held squash, the shoulders and arms
## swinging on past and settling.
##   turn_90_l    a quarter turn left: the left foot opens back, the right comes round
##   turn_180_l   a half turn left in three steps: left open, right round in front, left home
##   turn_45_l    a small shuffle left: two short steps
##   *_r          their mirrors
## TURN_PLANS: clip -> (length s, yaw deg, [(foot, lift s, plant s, to deg,
## lift m)]); headless_body_steps.gd TURN_CLIPS mirrors the feet's windows.
STANCE_X = HIP_X + 0.12


def _turn_feet(steps):
    """The feet and the root's yaw through `steps` [(foot, t0, t1, to, lift)]."""
    def feet(t, v):
        at = {"L": 0.0, "R": 0.0}
        swing = {}
        for n, t0, t1, to, lift in steps:
            if t >= t1: at[n] = to
            elif t > t0: swing[n] = (at[n], to, (t - t0) / (t1 - t0), lift)
        for n, s in SIDES:
            a = at[n]
            y = 0.0
            pitch = 0.0
            out = 0.0
            if n in swing:
                a0, a1, u, lift = swing[n]
                # Off the ground quick, carried round, set down flat and late.
                k = smooth01(0.08, 0.92, u)
                a = a0 + (a1 - a0) * k
                h = math.sin(math.pi * min(1.0, u ** 0.8))
                y = lift * h
                out = 0.18 * h
                pitch = -18.0 * (1 - smooth01(0.0, 0.4, u)) + 12.0 * math.sin(math.pi * smooth01(0.35, 0.95, u))
            else:
                # The heel peels just before its lift.
                for m, t0, t1, to, lift in steps:
                    if m == n and t0 - 0.16 < t <= t0:
                        pitch = -14.0 * smooth01(t0 - 0.16, t0, t)
            # Toes down, the ankle up on them (the toes stay on the ground).
            if pitch < 0.0: y = max(y, 1.44 * math.sin(deg(-pitch)))
            r = STANCE_X + out
            ca, sa = math.cos(deg(a)), math.sin(deg(a))
            x0 = s * r
            v[f"g{n}x"] = x0 * ca
            v[f"g{n}z"] = x0 * sa
            v[f"g{n}y"] = y
            v[f"g{n}a"] = a
            v[f"g{n}p"] = pitch
        # The root's yaw: the feet's mean, eased from each lift to just past
        # its plant (the hips come round over the new foot).
        yaw = 0.0
        prev = {"L": 0.0, "R": 0.0}
        for n, t0, t1, to, lift in steps:
            mean0 = (prev["L"] + prev["R"]) * 0.5
            prev[n] = to
            mean1 = (prev["L"] + prev["R"]) * 0.5
            yaw = mean0 + (mean1 - mean0) * smooth01(t0 + 0.04, t1 + 0.1, t)
            if t < t1 + 0.1: break
        v["ry"] = yaw
    return feet


TURN_PLANS = {}


def turn_clip(name, length, steps, keys):
    TURN_PLANS[name] = (length, steps[-1][3], steps)
    return clip(Clip(name, length, keys, extra=_turn_feet(steps)))


# turn_90_l: the left (pivot side) foot opens back and out to the quarter,
# the weight rolls onto it, the right comes round in front. ~1.9 s.
T90 = 1.9
turn_clip("turn_90_l", T90, [("L", 0.36, 0.82, 90.0, 0.7), ("R", 1.06, 1.5, 90.0, 0.62)], [
    (0.0, {}, ""),
    # Loaded: the weight onto the right, sunk, the shoulders wound right
    # against the turn, the stump down, the left heel coming up.
    (0.3, {"hx": 0.5, "hy": -0.46, "sq": 0.95, "hr": 2.5, "sr": 1.5, "ht": -5.0, "ct": -9.0, "nt": -4.0,
           "sp": 6.5, "np": 2.5, "aLo": 16.0, "aRo": 13.0, "aLp": -4.0, "aRp": 8.0}, "h"),
    (0.36, {"hy": -0.48, "sq": 0.945}, ""),
    # The lift: up off the right, the hips swung round, the shoulders leading
    # them, the left arm thrown out and back, the right across.
    (0.58, {"hx": 0.35, "hy": -0.04, "sq": 1.04, "hr": 1.5, "sr": 1.0, "ht": 8.0, "ct": 16.0, "nt": 10.0,
            "sp": 1.5, "np": 0.0, "aLo": 30.0, "aLp": -18.0, "eL": 22.0, "aRp": 24.0, "eR": 30.0, "aRo": 6.0}, ""),
    # The plant: flat and hard, dropped into a held squash, the shoulders
    # and arms swinging on.
    (0.82, {"hx": 0.0, "hy": -0.62, "sq": 0.91, "hr": 0.0, "sr": 0.0, "ht": 4.0, "ct": 20.0, "nt": 12.0,
            "sp": 8.0, "np": 3.0, "aLo": 20.0, "aLp": 6.0, "aRp": 14.0}, "i"),
    (0.96, {"hy": -0.6, "sq": 0.915}, "h"),
    # The weight rolled over onto the left (the new pivot), the right heel up.
    (1.06, {"hx": -0.45, "hy": -0.4, "sq": 0.96, "hr": -2.0, "sr": -1.0, "ht": 0.0, "ct": 6.0, "nt": 6.0,
            "sp": 6.0, "aLp": 0.0, "aRp": 4.0}, ""),
    # The right comes round: the hips after it, the shoulders ahead again.
    (1.28, {"hx": -0.3, "hy": -0.08, "sq": 1.03, "hr": -1.0, "ht": 6.0, "ct": 14.0, "nt": 8.0, "sp": 1.5,
            "aRp": 22.0, "eR": 26.0, "aLp": -14.0, "aLo": 24.0}, ""),
    (1.5, {"hx": 0.0, "hy": -0.58, "sq": 0.92, "hr": 0.0, "ht": 2.0, "ct": 9.0, "nt": 8.0, "sp": 7.5, "np": 2.5,
           "aRp": 8.0, "aLp": 10.0, "aLo": 14.0}, "i"),
    (1.62, {"hy": -0.56, "sq": 0.925, "ct": 5.0}, "h"),
    # Up, the shoulders settling back past square and home.
    (1.78, {"hy": -0.12, "sq": 1.01, "ct": -2.5, "nt": -2.0, "ht": 0.0, "sp": 2.5, "np": 0.0}, ""),
    (T90, {"_base": 1}, ""),
])

# turn_180_l: three steps: the left opens back to the quarter, the right
# comes all the way round in front to the half (the big one, the trunk
# thrown round after it), the left comes home beside it. ~2.7 s.
T180 = 2.7
turn_clip("turn_180_l", T180, [("L", 0.42, 0.88, 90.0, 0.7), ("R", 1.12, 1.74, 180.0, 0.82),
                               ("L", 1.98, 2.34, 180.0, 0.55)], [
    (0.0, {}, ""),
    (0.36, {"hx": 0.55, "hy": -0.52, "sq": 0.94, "hr": 3.0, "sr": 1.5, "ht": -7.0, "ct": -13.0, "nt": -6.0,
            "sp": 7.0, "np": 3.0, "aLo": 17.0, "aRo": 14.0, "aLp": -6.0, "aRp": 10.0}, "h"),
    (0.42, {"hy": -0.54, "sq": 0.935}, ""),
    (0.64, {"hx": 0.35, "hy": -0.04, "sq": 1.04, "hr": 1.5, "ht": 10.0, "ct": 20.0, "nt": 12.0, "sp": 1.5,
            "np": 0.0, "aLo": 32.0, "aLp": -20.0, "eL": 22.0, "aRp": 26.0, "eR": 30.0, "aRo": 6.0}, ""),
    (0.88, {"hx": 0.0, "hy": -0.6, "sq": 0.915, "hr": 0.0, "sr": 0.0, "ht": 6.0, "ct": 24.0, "nt": 14.0,
            "sp": 8.0, "np": 3.0, "aLo": 20.0, "aLp": 6.0, "aRp": 16.0}, "i"),
    (1.0, {"hy": -0.58, "sq": 0.92}, "h"),
    (1.12, {"hx": -0.5, "hy": -0.44, "sq": 0.955, "hr": -2.5, "sr": -1.0, "ht": 4.0, "ct": 16.0, "nt": 10.0,
            "sp": 6.5, "aRp": 6.0}, ""),
    # The big one: the right swung right round in front, high; the trunk
    # thrown round with it, the shoulders well ahead, the arms flung.
    (1.42, {"hx": -0.35, "hy": 0.02, "sq": 1.05, "hr": -1.5, "ht": 12.0, "ct": 26.0, "nt": 16.0, "sp": 1.0,
            "aRp": 30.0, "eR": 32.0, "aRo": 4.0, "aLp": -22.0, "aLo": 30.0, "eL": 24.0}, ""),
    (1.74, {"hx": 0.0, "hy": -0.66, "sq": 0.9, "hr": 0.0, "ht": 6.0, "ct": 22.0, "nt": 14.0, "sp": 8.5,
            "np": 3.5, "aRp": 14.0, "aLp": 10.0, "aLo": 18.0}, "i"),
    (1.88, {"hy": -0.64, "sq": 0.905}, "h"),
    (1.98, {"hx": 0.4, "hy": -0.42, "sq": 0.96, "hr": 2.0, "ht": 3.0, "ct": 10.0, "nt": 8.0, "sp": 6.5}, ""),
    (2.16, {"hx": 0.25, "hy": -0.12, "sq": 1.02, "ht": 4.0, "ct": 10.0, "nt": 6.0, "aLp": -10.0, "aLo": 22.0,
            "aRp": 12.0}, ""),
    (2.34, {"hx": 0.0, "hy": -0.5, "sq": 0.93, "ht": 1.0, "ct": 6.0, "nt": 6.0, "sp": 7.0, "np": 2.0,
            "aLp": 8.0, "aRp": 4.0}, "i"),
    (2.44, {"hy": -0.48, "sq": 0.935, "ct": 3.0}, "h"),
    (2.58, {"hy": -0.12, "sq": 1.01, "ct": -3.0, "nt": -2.5, "ht": 0.0, "sp": 2.5, "np": 0.0}, ""),
    (T180, {"_base": 1}, ""),
])

# turn_45_l: a shuffle, the left out a little and the right after it, low
# and quick, the shoulders leading. ~1.1 s.
T45 = 1.1
turn_clip("turn_45_l", T45, [("L", 0.2, 0.46, 45.0, 0.38), ("R", 0.56, 0.84, 45.0, 0.34)], [
    (0.0, {}, ""),
    (0.18, {"hx": 0.35, "hy": -0.34, "sq": 0.965, "hr": 1.5, "ht": -3.0, "ct": -5.0, "nt": -2.0, "sp": 6.0}, ""),
    (0.32, {"hx": 0.2, "hy": -0.14, "sq": 1.02, "ht": 5.0, "ct": 11.0, "nt": 7.0, "aLo": 20.0, "aLp": -8.0,
            "aRp": 14.0}, ""),
    (0.46, {"hx": -0.1, "hy": -0.44, "sq": 0.945, "hr": -1.0, "ht": 3.0, "ct": 10.0, "nt": 6.0, "sp": 7.0}, "i"),
    (0.56, {"hx": -0.3, "hy": -0.32, "sq": 0.965, "hr": -1.5}, ""),
    (0.7, {"hx": -0.15, "hy": -0.12, "sq": 1.02, "ct": 8.0, "aRp": 12.0, "aLp": -6.0}, ""),
    (0.84, {"hx": 0.0, "hy": -0.4, "sq": 0.95, "hr": 0.0, "ht": 0.0, "ct": 4.0, "nt": 4.0, "sp": 6.5}, "i"),
    (0.92, {"hy": -0.38, "sq": 0.955}, "h"),
    (1.02, {"hy": -0.12, "ct": -1.5, "sq": 1.0}, ""),
    (T45, {"_base": 1}, ""),
])
for _n in ("turn_90", "turn_180", "turn_45"):
    _of = next(c for c in CLIPS if c.name == _n + "_l")
    clip(Mirror(_n + "_r", _of))
    TURN_PLANS[_n + "_r"] = (_of.length, -TURN_PLANS[_n + "_l"][1],
                             [("R" if f == "L" else "L", a, b, -to, li) for f, a, b, to, li in TURN_PLANS[_n + "_l"][2]])

# ------------------------------------------------------------------ feeling the wall (round 4)
## Before a climb, FEEL s: he lays his right hand flat on the face, presses,
## slides it up and in a little, holds as if sensing it, gives a small nod
## ("here"), and his left arm flexes ready for the climb. The wall is
## FEEL_WALL m ahead of his middle here: the climb's standoff and half a
## metre more, where the game stands him while he feels it (measured off the
## face's nearest point over his height), and the game puts the palm on the
## real face (headless_body.gd `_feel`, `_hands`). He leans in only a little
## and nothing but the right hand reaches the wall.
FEEL = 1.0
FEEL_WALL = CLIMB_WALL + 0.5
_fw = FEEL_WALL - 0.9    # the wrist off the face, the palm flat on it (the game's FEEL_PALM)
_palm = {"pRw": 1.0, "pRfx": 0.1, "pRfy": 1.0, "pRfz": 0.0, "pRnx": 0.0, "pRny": 0.0, "pRnz": 1.0}
clip(Clip("feel", FEEL, [
    (0.0, {}, ""),
    # The hand drawn up close by his side, its fingers turned up and the palm
    # to the face before it goes out (the fingers never swing into it).
    (0.12, {"hy": -0.16, "sq": 0.98, "sp": 4.0, "np": 4.0, "hz": -0.05, "hRw": 0.75, "hRx": 2.45,
            "hRy": SHOULDER_Y - 2.4, "hRz": 0.3, **_palm, "fR": 12.0, "aLo": 4.0, "aLp": 0.0}, ""),
    (0.22, {"hRw": 0.9, "hRx": 2.3, "hRy": SHOULDER_Y - 1.8, "hRz": _fw - 0.6, "fR": 10.0}, ""),
    (0.3, {"hRw": 1.0, "hRx": 2.2, "hRy": SHOULDER_Y - 1.5, "hRz": _fw, **_palm, "fR": 6.0, "tR": 14.0,
           "hy": -0.12, "sp": 4.0, "hz": 0.0, "cp": 1.0, "np": 2.0, "nr": 3.0, "nt": -3.0}, "o"),
    (0.4, {"hy": -0.18, "sq": 0.975, "fR": 2.0}, "h"),
    (0.66, {"hRy": SHOULDER_Y - 1.2, "hRx": 2.05, "nr": 6.0, "nt": -5.0, "np": 1.0, "fR": 4.0, "hy": -0.16}, ""),
    (0.8, {"nr": 6.0, "nt": -5.0}, "h"),
    (0.88, {"np": 6.0, "hy": -0.2, "sq": 0.97, "fR": 14.0, "aLp": 2.0, "aLo": 6.0, "eL": 18.0}, ""),
    (1.0, {"np": 1.0, "hy": -0.14, "sq": 1.0, "aLp": 3.0, "eL": 20.0, "aLo": 8.0, "fL": 70.0}, ""),
]))

# ------------------------------------------------------------------ the periscope (Olmec periscope round 1)
## Whole, his sight broken, he lifts his own head off his shoulders and
# holds it up overhead in both hands to see past the cover. The hands grip the
## head's sides, the wrists SCOPE_GRIP over its chin, the palms flat on it
## and the fingers up; the game carries the head between them (the wrists'
## middle, SCOPE_GRIP down) from the grip (SCOPE_TAKE of the lift) till it
## is seated again (SCOPE_SEAT of the lower), and turns the trunk and the
## head on top of the look to where he is searching.
##   scope_lift   once, SCOPE_LIFT s: hands up to the head, the grip, a pry
##                with a tremble, the dip, the heave up overhead (a stretch,
##                overshot), the weight of it settling him into the key pose
##   scope_look   loop, SCOPE_LOOK s: the key pose held, the arms straining
##                a little under it, a breath and a weight shift
##   scope_lower  once, SCOPE_LOWER s: a small lift, then down slowly and
##                carefully, the seat (a clunk, a squash), a pat, let go
SCOPE_LIFT = 1.7
SCOPE_LOOK = 3.0
SCOPE_LOWER = 1.6
SCOPE_HEAD_W = 2.6 * 1.12 * 1.04   # the head it wears (inhaler_head.gd: size 2.6, width 1.04 of it)
SCOPE_X = SCOPE_HEAD_W * 0.5 + 0.28  # the wrist off the head's middle: the palm on its side
SCOPE_GRIP = 0.3                     # the wrists over its chin
SCOPE_UP = 9.1                       # the wrists held up (the key pose)
SCOPE_FWD = 0.55
SCOPE_TAKE = 0.42 / 1.7
SCOPE_SEAT = 0.92 / 1.6


def _grip(y, fwd=0.0, x=SCOPE_X, w=1.0, curl=12.0):
    """Both wrists at the head's sides, `y` up, `fwd` forward; palms in,
    fingers up."""
    out = {}
    for n, s in SIDES:
        out.update({f"h{n}x": s * x, f"h{n}y": y, f"h{n}z": fwd, f"h{n}w": w,
                    f"p{n}w": w, f"p{n}fx": 0.0, f"p{n}fy": 1.0, f"p{n}fz": 0.08,
                    f"p{n}nx": -s * 1.0, f"p{n}ny": 0.0, f"p{n}nz": 0.0, f"f{n}": curl, f"t{n}": 24.0})
    return out


## The key pose: the head up in both hands over the empty stump, the arms
## near straight, the elbows out, the chest arched a little back, the
## weight sunk a hair under it.
SCOPE_KEY = {"hy": -0.12, "sq": 0.985, "sp": 2.0, "cp": -4.0, "np": -4.0, "kLx": 0.22, "kRx": 0.22,
             **_grip(SCOPE_UP, SCOPE_FWD)}


def _scope_lift_extra(t, v):
    # The pry: a shiver through the arms as the head cracks off the stump.
    k = smooth01(0.42, 0.5, t) * (1 - smooth01(0.6, 0.68, t))
    for n, s in SIDES:
        v[f"h{n}y"] += tremble(t, 0.045 * k, 12.0, 1.0 + s)
    v["hy"] += tremble(t, 0.02 * k, 9.0, 3.0)
    # Held up there: the strain.
    k2 = smooth01(1.15, 1.35, t)
    for n, s in SIDES:
        v[f"h{n}y"] += tremble(t, 0.02 * k2, 7.0, 2.0 + s)


clip(Clip("scope_lift", SCOPE_LIFT, [
    (0.0, {}, ""),
    # The reach: both hands up to the head's sides, a little sink.
    (0.3, {"hy": -0.2, "sq": 0.975, "sp": 7.0, "cp": 5.0, "np": 3.0, **_grip(SEAT + 0.15, 0.15, SCOPE_X + 0.22, 0.95, 8.0)}, ""),
    # The grip: palms flat on it, the fingers closing, the shoulders hunched.
    (0.42, {"hy": -0.24, "sp": 8.0, "cp": 8.0, "np": 2.0, **_grip(SEAT + SCOPE_GRIP, 0.0)}, "o"),
    # The pry: it cracks off the stump (the game's tremble on top).
    (0.6, {"hy": -0.2, "sp": 7.0, "cp": 6.0, **_grip(SEAT + SCOPE_GRIP + 0.14, 0.02, curl=22.0)}, ""),
    # The dip: down with it, knees bent, coiled under the weight.
    (0.8, {"hy": -0.66, "sq": 0.935, "sp": 12.0, "cp": 6.0, "np": 6.0, "kLx": 0.3, "kRx": 0.3,
           **_grip(SEAT + SCOPE_GRIP + 0.14 - 0.6, 0.18, curl=22.0)}, "o"),
    # The heave: up overhead, stretched tall, overshot.
    (1.02, {"hy": 0.04, "sq": 1.06, "sp": -3.0, "cp": -8.0, "np": -8.0, "kLx": 0.22, "kRx": 0.22,
            **_grip(SCOPE_UP + 0.28, SCOPE_FWD - 0.1)}, ""),
    # Its weight comes down on him: he sinks into the key pose.
    (1.24, {"hy": -0.22, "sq": 0.965, "sp": 3.0, "cp": -3.0, "np": -3.0, **_grip(SCOPE_UP - 0.18, SCOPE_FWD)}, ""),
    (1.45, SCOPE_KEY, "o"),
    (SCOPE_LIFT, SCOPE_KEY, "h"),
], extra=_scope_lift_extra))


def _scope_look_extra(t, v):
    b = math.sin(t / SCOPE_LOOK * 6.283 - 0.6)
    v["cp"] += -1.4 * b
    v["hy"] += 0.03 * b
    v["hx"] += 0.06 * math.sin(t / SCOPE_LOOK * 6.283 * 0.5)
    for n, s in SIDES:
        v[f"h{n}y"] += 0.04 * b + tremble(t, 0.018, 6.0, 1.5 + s)


clip(Clip("scope_look", SCOPE_LOOK, [
    (0.0, SCOPE_KEY, ""),
    (SCOPE_LOOK * 0.5, {**SCOPE_KEY, "hy": -0.16, "sq": 0.98}, ""),
], loop=True, extra=_scope_look_extra))

SL_ = SCOPE_LOWER
clip(Clip("scope_lower", SL_, [
    (0.0, SCOPE_KEY, ""),
    # A small lift first (the anticipation), then down, slow and careful.
    (0.18, {**SCOPE_KEY, "hy": -0.04, "sq": 1.0, **_grip(SCOPE_UP + 0.16, SCOPE_FWD)}, ""),
    (0.55, {"hy": -0.2, "sq": 0.98, "sp": 6.0, "cp": 4.0, "np": 2.0, **_grip(SEAT + SCOPE_GRIP + 0.9, 0.3)}, ""),
    (0.8, {"hy": -0.28, "sq": 0.97, "sp": 8.0, "cp": 6.0, "np": 3.0, **_grip(SEAT + SCOPE_GRIP + 0.2, 0.06)}, "i"),
    # The seat: a clunk, squashed under it, held.
    (0.92, {"hy": -0.48, "sq": 0.93, "sp": 7.0, "cp": 4.0, "np": 1.0, **_grip(SEAT + SCOPE_GRIP - 0.04, 0.0, curl=22.0)}, "h"),
    (1.06, {"hy": -0.42, "sq": 0.945, "np": 4.0, **_grip(SEAT + SCOPE_GRIP, 0.0, curl=20.0)}, "h"),
    # Let go: the hands open and drop, a nod to settle it.
    (1.24, {"hy": -0.2, "sq": 0.99, "sp": 6.0, "cp": 3.0, "np": -3.0,
            **_grip(SEAT - 0.6, 0.3, SCOPE_X + 0.5, 0.45, 4.0)}, ""),
    (1.42, {"hy": -0.1, "np": 2.0, "hLw": 0.0, "hRw": 0.0, "pLw": 0.0, "pRw": 0.0, "fL": 30.0, "fR": 30.0,
            "aLo": 14.0, "aRo": 14.0, "eL": 22.0, "eR": 22.0}, ""),
    (SL_, {"_base": 1}, ""),
]))


# ------------------------------------------------------------------ the knock-off (Olmec boss, loop olmec-knockoff)
## Shoved to the rim he teeters, goes over or comes back from it; from below
## he leaps up over the rim and lands heavy; hit in the back he lurches on.
## The edge clips tip the whole figure about a point on the ground (the
## `tp`/`tr`/`tf` channels): TOES m ahead of his feet's middle, so the game
## stands him with his toes on the rim (the edge EDGE_AT m ahead of the
## origin) and his pose does the tipping; the game only drops him once he is
## over (TOPPLE_GO s into `topple`).
##   teeter_catch  once, TEETER_CATCH s: thrown onto his toes at the brink,
##                 the arms flung, a leg kicked back; ends on `teeter`'s start
##   teeter        loop, TEETER s: windmilling (both arms circling forward,
##                 a quarter apart), rocking on his toes over the drop, the
##                 back leg cocked out for balance, the stump looking down
##   teeter_back   once, TEETER_BACK s: from `teeter`'s start, a last heave
##                 rocks him back onto his heels, a step back, sunk in
##                 relief, up and squared
##   topple        once, TOPPLE s: from `teeter`'s start, the arms stall high
##                 (the "uh-oh" hold), then he tips past the toes, slow then
##                 fast, head first over the rim, flailing; the last frame
##                 holds (pitched TOPPLE_PITCH, still flailing in the hold)
##   rim_leap      once over the leap's flight (RIM_LEAP s at the defaults):
##                 from below the rim, reaching up long, knees tucked over the
##                 lip, fists raised, legs down for the top
##   rim_land      once, RIM_LAND s: the heavy landing, both fists driven into
##                 the ground at RIM_SLAM s (the shockwave), held, then up
##                 and roaring (chest out, arms spread, the stump up), into a
##                 hunched angry ready
##   back_hit      once, BACK_HIT s: hit from behind, the back caved in, the
##                 stump whipped back, then lurched forward two stumbling
##                 steps, hands out, caught, a shake of the stump
TOES = 0.85
EDGE_AT = TOES
TEETER = 1.8
TEETER_CATCH = 0.9
TEETER_BACK = 1.6
TOPPLE = 1.6
TOPPLE_GO = 0.75
TOPPLE_PITCH = 112.0
RIM_LEAP = 1.2
RIM_LAND = 1.8
RIM_SLAM = 0.07
BACK_HIT = 1.4
## The windmill: one circle of the arms in WINDMILL s.
WINDMILL = TEETER / 2.0

_TEETER = {"tp": 13.0, "tf": TOES, "tr": 0.0, "hy": -0.5, "hz": -0.55, "hp": 6.0, "sp": 20.0, "cp": 8.0,
           "np": 22.0, "nt": 0.0, "sq": 1.0,
           "aLo": 34.0, "aRo": 34.0, "eL": 30.0, "eR": 30.0, "fL": 6.0, "fR": 6.0, "tL": 4.0, "tR": 4.0,
           "wLp": -10.0, "wRp": -10.0,
           # The left leg cocked out behind for balance, the right on its toes.
           "kLz": -1.35, "kLy": 1.45, "kLx": 0.6, "kLp": -45.0, "kRz": 0.0, "kRx": 0.14, "kRp": 0.0}


def _windmill(t, v, w=1.0, speed=1.0):
    """Both arms circling forward (up behind, over the top, down in front),
    a quarter circle apart, quicker on the down stroke; blended in by `w`."""
    for n, s, off in (("L", -1, 0.0), ("R", 1, 0.25)):
        u = t * speed / WINDMILL + off
        th = 150.0 - 360.0 * (u + 0.07 * math.sin(2 * math.pi * u))
        up = math.cos(math.radians(th - 180.0))           # 1 overhead, -1 down
        v[f"a{n}p"] = v[f"a{n}p"] * (1 - w) + th * w
        v[f"a{n}o"] += w * (14.0 + 10.0 * up)
        v[f"e{n}"] += w * 18.0 * max(0.0, -math.sin(math.radians(th)))
        v[f"f{n}"] += w * tremble(t, 4.0, 7.0, 1.0 + s)


def _teeter_extra(t, v):
    u = t / TEETER
    rock = math.sin(2 * math.pi * u)
    v["tp"] += 3.5 * rock
    v["tr"] += 2.5 * math.sin(2 * math.pi * u * 2 + 0.7)
    # Over too far: the chest throws back, the hips further out behind.
    v["cp"] += -5.0 * rock
    v["hz"] += -0.12 * rock
    v["np"] += 6.0 * math.sin(2 * math.pi * (u - 0.06)) + tremble(t, 1.5, 4.0)
    v["nr"] += 7.0 * math.sin(2 * math.pi * u * 2 + 0.2)
    v["kLy"] += 0.22 * math.sin(2 * math.pi * u * 2 + 1.4)
    v["kLz"] += -0.15 * math.sin(2 * math.pi * u * 2 + 1.4)
    _windmill(t, v)


TEETER_CLIP = clip(Clip("teeter", TEETER, [
    (0.0, _TEETER, ""),
    (TEETER * 0.5, {**_TEETER, "hy": -0.56, "sq": 0.98}, ""),
], loop=True, extra=_teeter_extra))


def _into_teeter(start, end):
    """An extra blending into `teeter` (its time 0 at `end`) from `start`."""
    def extra(t, v):
        w = smooth01(start, end, t)
        if w <= 0.0: return
        tv = TEETER_CLIP.values(t - end)
        for c in v:
            if c in tv: v[c] = v[c] * (1 - w) + tv[c] * w
    return extra


def _from_teeter(end, more=None):
    """An extra starting in `teeter` (its time 0 at t 0), handing over to
    the clip's own keys by `end`; `more(t, v)` after."""
    def extra(t, v):
        w = 1.0 - smooth01(0.0, end, t)
        if w > 0.0:
            tv = TEETER_CLIP.values(t)
            for c in v:
                if c in tv: v[c] = v[c] * (1 - w) + tv[c] * w
        if more: more(t, v)
    return extra


clip(Clip("teeter_catch", TEETER_CATCH, [
    (0.0, {"hy": -0.6, "sp": 22.0, "cp": 10.0, "np": 6.0, "aLp": 20.0, "aRp": 20.0, "eL": 30.0, "eR": 30.0}, ""),
    # Thrown on: up onto his toes, pitched over, the arms flung back.
    (0.14, {"tp": 15.0, "tf": TOES, "hy": -0.3, "sq": 1.06, "hz": -0.2, "sp": 26.0, "cp": 12.0, "np": 30.0,
            "aLp": -48.0, "aRp": -40.0, "aLo": 40.0, "aRo": 40.0, "eL": 20.0, "eR": 20.0, "fL": 4.0, "fR": 4.0,
            "kLz": -0.5, "kLy": 0.5, "kLp": -20.0}, "o"),
    # The catch: the hips thrown out behind, the leg kicked up, arms up.
    (0.34, {"tp": 13.0, "hy": -0.55, "sq": 0.96, "hz": -0.5, "hp": 8.0, "sp": 22.0, "cp": 6.0, "np": 26.0,
            "aLp": 120.0, "aRp": 100.0, "aLo": 52.0, "aRo": 52.0, "eL": 26.0, "eR": 26.0,
            "kLz": -1.35, "kLy": 1.3, "kLp": -40.0}, ""),
], extra=_into_teeter(0.42, TEETER_CATCH)))


def _back_more(t, v):
    k = smooth01(1.0, 1.08, t) * (1 - smooth01(1.3, 1.45, t))
    v["nt"] += 14.0 * k * math.sin((t - 1.0) * 6.283 * 2.4)


clip(Clip("teeter_back", TEETER_BACK, [
    (0.0, _TEETER, ""),
    # A last heave: both arms swung down and back hard, rocking him back.
    (0.24, {**_TEETER, "tp": 4.0, "hy": -0.62, "sq": 0.95, "hz": -0.3, "sp": 12.0, "cp": -4.0, "np": 12.0,
            "aLp": -60.0, "aRp": -54.0, "aLo": 30.0, "aRo": 30.0, "eL": 20.0, "eR": 20.0,
            "kLz": -1.0, "kLy": 0.4, "kLp": -10.0}, "o"),
    # Back over the heels: the left foot slammed down behind, onto the heels.
    (0.42, {"tp": -4.0, "tf": -0.4, "hy": -0.3, "sq": 1.04, "hz": 0.1, "hp": -4.0, "sp": -6.0, "cp": -8.0,
            "np": -10.0, "aLp": 40.0, "aRp": 46.0, "aLo": 44.0, "aRo": 44.0, "eL": 30.0, "eR": 30.0,
            "kLz": -0.9, "kLy": 0.0, "kLp": 0.0, "kRp": 14.0}, ""),
    # The step back with the right, sunk in relief.
    (0.6, {"tp": -2.0, "hy": -0.5, "sq": 1.0, "kRz": -0.5, "kRy": 0.45, "kRp": 0.0}, ""),
    (0.76, {"tp": 0.0, "tf": 0.0, "hy": -0.85, "sq": 0.92, "hz": -0.2, "hp": 4.0, "sp": 22.0, "cp": 10.0,
            "np": 14.0, "kRz": -0.75, "kRy": 0.0, "kLz": -0.55, "aLp": 10.0, "aRp": 10.0, "aLo": 22.0,
            "aRo": 22.0, "eL": 40.0, "eR": 40.0, "fL": 50.0, "fR": 50.0}, "o"),
    (1.0, {"hy": -0.8, "sq": 0.95, "sp": 20.0, "np": 12.0}, ""),
    # Up and squared, the fists closed: angry now.
    (1.3, {"hy": -0.35, "sq": 1.02, "hz": 0.0, "hp": 0.0, "sp": 12.0, "cp": 4.0, "np": -6.0, "kRz": -0.35,
           "kLz": -0.25, "aLp": 8.0, "aRp": 8.0, "aLo": 18.0, "aRo": 18.0, "eL": 34.0, "eR": 34.0, "fL": 88.0,
           "fR": 88.0}, ""),
    (TEETER_BACK, {"_base": 1, "kRz": -0.3, "kLz": -0.2, "sp": 9.0, "fL": 70.0, "fR": 70.0}, ""),
], extra=_from_teeter(0.2, _back_more)))


def _topple_more(t, v):
    # Flailing once over: the arms clawing, the legs pedalling (it holds).
    k = smooth01(0.6, 0.9, t)
    if k <= 0.0: return
    for n, s, off in (("L", -1, 0.0), ("R", 1, 0.5)):
        ph = 2 * math.pi * (t / 0.5 + off)
        v[f"a{n}p"] += k * 26.0 * math.sin(ph)
        v[f"a{n}o"] += k * 12.0 * math.cos(ph)
        v[f"e{n}"] += k * 16.0 * max(0.0, math.sin(ph + 1.0))
        v[f"k{n}y"] += k * 0.35 * (0.5 + 0.5 * math.sin(ph + 0.6))
        v[f"k{n}z"] += k * 0.4 * math.cos(ph + 0.6)
    v["np"] += k * 6.0 * math.sin(2 * math.pi * t / 0.7)


clip(Clip("topple", TOPPLE, [
    (0.0, _TEETER, ""),
    # Uh-oh: the arms stall high mid-circle, stiff, the stump looking down.
    (0.22, {**_TEETER, "tp": 19.0, "hy": -0.4, "sq": 1.04, "hz": -0.35, "sp": 16.0, "cp": 2.0, "np": 34.0,
            "aLp": 168.0, "aRp": 150.0, "aLo": 40.0, "aRo": 46.0, "eL": 12.0, "eR": 14.0, "fL": 0.0, "fR": 0.0,
            "tL": 0.0, "tR": 0.0, "kLz": -1.1, "kLy": 1.0}, "o"),
    (0.4, {"tp": 22.0, "np": 36.0, "aLp": 170.0, "aRp": 154.0}, "h"),
    # Over: past the toes, slow then fast, the back leg flung up behind.
    (0.78, {"tp": 52.0, "hy": -0.25, "sq": 1.06, "hz": -0.1, "sp": 10.0, "cp": -6.0, "np": 10.0,
            "aLp": 200.0, "aRp": 190.0, "aLo": 60.0, "aRo": 62.0, "eL": 30.0, "eR": 30.0, "fL": 10.0, "fR": 10.0,
            "kLz": -1.0, "kLy": 1.5, "kLp": -30.0, "kRz": -0.2, "kRy": 0.4, "kRp": -30.0}, "i"),
    (1.05, {"tp": 92.0, "sp": 6.0, "cp": -10.0, "np": -8.0, "aLp": 205.0, "aRp": 200.0, "aLo": 76.0,
            "aRo": 78.0, "kLz": -0.5, "kLy": 1.2, "kRz": -0.6, "kRy": 1.0, "kLp": -20.0, "kRp": -20.0}, ""),
    (TOPPLE, {"tp": TOPPLE_PITCH, "np": -14.0}, "h"),
], extra=_from_teeter(0.18, _topple_more)))


## The leap back up (RIM_LEAP s over the game's flight): bursting up from
## below the rim at full stretch, both arms reaching up; the arms thrown
## down and the knees tucked up as he clears the lip, pitched over it, both
## fists raised overhead for the slam; the legs down to land.
clip(Clip("rim_leap", RIM_LEAP, [
    (0.0, {"hy": -0.1, "sq": 1.1, "sp": -6.0, "cp": -8.0, "np": -22.0,
           "aLp": 172.0, "aRp": 168.0, "aLo": 14.0, "aRo": 14.0, "eL": 10.0, "eR": 10.0, "fL": 20.0, "fR": 20.0,
           "kLy": -0.05, "kRy": -0.05, "kLz": -0.45, "kRz": -0.3, "kLp": -50.0, "kRp": -45.0}, ""),
    (0.12 * RIM_LEAP, {"sq": 1.14, "aLp": 178.0, "aRp": 176.0, "np": -26.0}, ""),
    # Clearing the lip: the knees tucked high, pitched over it, the arms swung down and back.
    (0.42 * RIM_LEAP, {"tp": 16.0, "tf": 0.0, "hy": 0.3, "sq": 0.96, "sp": 26.0, "cp": 10.0, "np": 14.0,
                       "aLp": -38.0, "aRp": -34.0, "aLo": 40.0, "aRo": 40.0, "eL": 30.0, "eR": 30.0,
                       "fL": 80.0, "fR": 80.0, "kLy": 1.75, "kRy": 1.7, "kLz": 0.55, "kRz": 0.45,
                       "kLp": 10.0, "kRp": 10.0}, ""),
    # The top: fists raised overhead, chest up, held a beat.
    (0.62 * RIM_LEAP, {"tp": 6.0, "hy": 0.25, "sq": 1.0, "sp": -4.0, "cp": -10.0, "np": -14.0,
                       "aLp": 160.0, "aRp": 160.0, "aLo": 22.0, "aRo": 22.0, "eL": 50.0, "eR": 50.0,
                       "fL": 95.0, "fR": 95.0, "tL": 45.0, "tR": 45.0, "kLy": 1.3, "kRy": 1.25, "kLz": 0.3,
                       "kRz": 0.2}, "o"),
    (0.78 * RIM_LEAP, {"tp": 4.0, "aLp": 168.0, "aRp": 168.0, "np": -16.0}, "h"),
    # The legs driven down for the top, the fists coming over.
    (RIM_LEAP, {"tp": 0.0, "hy": 0.0, "sq": 1.06, "sp": 16.0, "cp": 6.0, "np": 6.0, "aLp": 120.0, "aRp": 120.0,
                "aLo": 26.0, "aRo": 26.0, "eL": 40.0, "eR": 40.0, "kLy": 0.05, "kRy": 0.05, "kLz": 0.2,
                "kRz": -0.1, "kLx": 0.32, "kRx": 0.32, "kLp": 0.0, "kRp": 0.0}, ""),
]))


def _land_extra(t, v):
    # Held in the ground, trembling with it; then the roar's shake.
    k = smooth01(0.1, 0.16, t) * (1 - smooth01(0.5, 0.6, t))
    v["hy"] += tremble(t, 0.03 * k, 12.0)
    v["cr"] += tremble(t, 1.4 * k, 9.0, 1.0)
    r = smooth01(0.82, 0.9, t) * (1 - smooth01(1.2, 1.3, t))
    v["np"] += tremble(t, 2.5 * r, 7.0, 2.0)
    v["cp"] += tremble(t, 1.5 * r, 6.0, 3.0)
    for n, s in SIDES:
        v[f"a{n}p"] += tremble(t, 2.5 * r, 9.0, 1.0 + s)


## The heavy landing on the top, RIM_LAND s: down squashed, both fists
## hammered into the ground ahead at RIM_SLAM s (the game's shockwave),
## held there trembling, then heaved up into a roar (the chest thrown out,
## arms flung wide, fists closed, the stump up), held, and down into a
## hunched angry ready.
clip(Clip("rim_land", RIM_LAND, [
    (0.0, {"hy": -0.7, "sq": 0.9, "sp": 26.0, "cp": 8.0, "np": 10.0, "aLp": 110.0, "aRp": 110.0,
           "aLo": 26.0, "aRo": 26.0, "eL": 40.0, "eR": 40.0, "fL": 95.0, "fR": 95.0, "tL": 45.0, "tR": 45.0,
           "kLx": 0.34, "kRx": 0.34, "kLz": 0.2, "kRz": -0.1}, ""),
    # The slam: sunk, squashed, both fists in the ground ahead.
    (RIM_SLAM, {"hy": -1.45, "sq": 0.74, "hz": 0.1, "sp": 38.0, "cp": 12.0, "np": 18.0,
                "hLx": -1.2, "hLy": 0.5, "hLz": 2.1, "hLw": 1.0, "hRx": 1.2, "hRy": 0.5, "hRz": 2.1, "hRw": 1.0,
                "kLz": 0.15, "kRz": -0.25}, "i"),
    (RIM_SLAM + 0.08, {"hy": -1.52, "sq": 0.76, "sp": 40.0, "np": 22.0, "hLy": 0.42, "hRy": 0.42}, "h"),
    (0.5, {"hy": -1.4, "sq": 0.95, "sp": 37.0, "np": 18.0, "hLy": 0.46, "hRy": 0.46}, "h"),
    # Heaved up: the fists torn out, rising.
    (0.68, {"hy": -0.6, "sq": 1.04, "hz": 0.0, "sp": 10.0, "cp": 0.0, "np": 0.0, "hLw": 0.0, "hRw": 0.0,
            "aLp": 30.0, "aRp": 30.0, "aLo": 40.0, "aRo": 40.0, "eL": 70.0, "eR": 70.0}, ""),
    # The roar: up tall, the chest thrown out, the arms wide, the stump back.
    (0.84, {"hy": -0.15, "sq": 1.07, "sp": -10.0, "cp": -14.0, "np": -26.0, "aLp": 40.0, "aRp": 40.0,
            "aLo": 78.0, "aRo": 78.0, "eL": 50.0, "eR": 50.0, "wLp": -20.0, "wRp": -20.0}, "o"),
    (1.22, {"hy": -0.2, "sq": 1.06, "sp": -12.0, "cp": -16.0, "np": -28.0, "aLo": 82.0, "aRo": 82.0}, "h"),
    # Down into the hunch: angry, fists forward, ready to come on.
    (1.46, {"hy": -0.62, "sq": 0.97, "sp": 20.0, "cp": 10.0, "np": 8.0, "aLp": 22.0, "aRp": 22.0,
            "aLo": 26.0, "aRo": 26.0, "eL": 60.0, "eR": 60.0, "wLp": 0.0, "wRp": 0.0}, ""),
    (RIM_LAND, {"_base": 1, "hy": -0.45, "sp": 16.0, "cp": 8.0, "np": 6.0, "aLp": 16.0, "aRp": 16.0,
                "aLo": 22.0, "aRo": 22.0, "eL": 50.0, "eR": 50.0, "fL": 90.0, "fR": 90.0, "tL": 40.0,
                "tR": 40.0}, ""),
], extra=_land_extra))


def _back_hit_extra(t, v):
    k = smooth01(0.85, 0.95, t) * (1 - smooth01(1.15, 1.3, t))
    v["nt"] += 14.0 * k * math.sin((t - 0.85) * 6.283 * 2.6)
    v["nr"] += 5.0 * k * math.sin((t - 0.85) * 6.283 * 1.3 + 0.6)


## Hit in the back, BACK_HIT s: the blow caves his back in (the hips
## punched forward, the chest and stump whipped back, the arms flung out
## behind), then the whiplash pitches him on: two lurching steps (left,
## right) as the game shoves him on, the hands thrown out ahead, caught low,
## a shake of the stump, squared.
clip(Clip("back_hit", BACK_HIT, [
    (0.0, {}, ""),
    (0.06, {"hy": -0.3, "sq": 0.9, "hz": 0.55, "hp": -10.0, "sp": -22.0, "cp": -16.0, "np": -30.0,
            "aLp": -46.0, "aRp": -46.0, "aLo": 34.0, "aRo": 34.0, "eL": 16.0, "eR": 16.0, "fL": 8.0, "fR": 8.0,
            "tL": 4.0, "tR": 4.0}, "o"),
    (0.13, {"hy": -0.36, "sq": 0.92, "hz": 0.6, "sp": -24.0, "np": -34.0, "aLp": -52.0, "aRp": -52.0}, "h"),
    # The whiplash: pitched on, the left foot thrown ahead.
    (0.27, {"tp": 8.0, "tf": TOES, "hy": -0.4, "sq": 1.04, "hz": 0.6, "hp": 10.0, "sp": 30.0, "cp": 16.0,
            "np": 6.0, "aLp": 70.0, "aRp": 50.0, "aLo": 40.0, "aRo": 44.0, "eL": 30.0, "eR": 34.0,
            "kLz": 0.9, "kLy": 0.55, "kLp": 10.0}, ""),
    (0.4, {"tp": 0.0, "tf": 0.0, "hy": -0.95, "sq": 0.9, "hz": 0.45, "sp": 32.0, "cp": 14.0, "np": 16.0,
            "kLz": 1.15, "kLy": 0.0, "kLp": 0.0, "kRz": -0.4, "aLp": 50.0, "aRp": 64.0}, "o"),
    # The second step: the right comes through.
    (0.52, {"hy": -0.65, "sq": 1.0, "kRz": 0.6, "kRy": 0.5, "kLz": 0.4, "sp": 28.0, "aLp": 60.0, "aRp": 40.0}, ""),
    (0.66, {"hy": -1.0, "sq": 0.92, "hz": 0.2, "sp": 34.0, "cp": 14.0, "np": 18.0, "kRz": 0.9, "kRy": 0.0,
            "kLz": -0.3, "aLp": 44.0, "aRp": 48.0, "aLo": 34.0, "aRo": 34.0, "eL": 40.0, "eR": 40.0,
            "fL": 30.0, "fR": 30.0}, "o"),
    (0.85, {"hy": -0.95, "sq": 0.95, "sp": 30.0, "np": 16.0}, ""),
    # Squared: the stump shaken, the fists closed.
    (1.15, {"hy": -0.4, "sq": 1.02, "hz": 0.0, "hp": 0.0, "sp": 12.0, "cp": 4.0, "np": -2.0, "kRz": 0.4,
            "kLz": -0.25, "aLp": 10.0, "aRp": 10.0, "aLo": 18.0, "aRo": 18.0, "eL": 34.0, "eR": 34.0,
            "fL": 85.0, "fR": 85.0}, ""),
    (BACK_HIT, {"_base": 1, "kRz": 0.25, "kLz": -0.15, "sp": 9.0, "fL": 70.0, "fR": 70.0}, ""),
], extra=_back_hit_extra))


# ================================================================== keying
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"


def bake(c):
    frames = max(1, round(c.length * FPS))
    action = bpy.data.actions.new(c.name)
    action.use_fake_user = True
    rig.animation_data.action = action
    worst, worst_at = 0.0, 0
    last = {}
    for f in range(frames + 1):
        t = c.length * f / frames
        v = c.values(t)
        pose = pose_of(v)
        P, reach = solve(pose)
        if reach > worst: worst, worst_at = reach, f
        B = basis(P)
        for pb in rig.pose.bones:
            loc, rot, _ = B[pb.name].decompose()
            if pb.name in last and last[pb.name].dot(rot) < 0: rot.negate()
            last[pb.name] = rot
            pb.location = loc
            pb.rotation_quaternion = rot
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
            if pb.name == "root":
                sq = pose.squash
                w = 1.0 / math.sqrt(max(sq, 0.2))
                pb.scale = (w, w, sq)
                pb.keyframe_insert("scale", frame=f)
    action.frame_range = (0, frames)
    rig.animation_data.nla_tracks.new().strips.new(c.name, 0, action)
    rig.animation_data.action = None
    print(f"BODY_CLIP {c.name} frames={frames} seconds={c.length:.3f} worst_leg_reach={worst:.3f} at frame {worst_at}")
    return action


ACTIONS = {}
for c in CLIPS:
    if ONLY and c.name not in ONLY and not RENDER: pass
    ACTIONS[c.name] = bake(c)
for pb in rig.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.scale = (1, 1, 1)

rig["SEAT"] = SEAT
if SAVE_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "headless_body.blend"))

# ================================================================== export
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = rig
GLB.parent.mkdir(parents=True, exist_ok=True)
kw = dict(filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
          export_apply=False, export_animations=True, export_animation_mode="ACTIONS",
          export_force_sampling=True, export_frame_step=1, export_materials="EXPORT",
          export_normals=True, export_extras=False, export_def_bones=False)
try:
    bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE")
except TypeError:
    bpy.ops.export_scene.gltf(**kw, export_colors=True)
print("BODY_EXPORTED", GLB)

# ================================================================== stills
if RENDER:
    out = Path(RENDER)
    out.mkdir(parents=True, exist_ok=True)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 640
    scene.render.resolution_y = 800
    scene.render.film_transparent = False
    # A floor and, for the climbs, the wall.
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    floor = bpy.context.active_object
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, CLIMB_WALL + 4.0, 0))
    wall = bpy.context.active_object
    wall.scale = (12, 8, 30)
    wall.hide_render = True
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 42
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    def look(frm, at):
        cam.location = frm
        cam.rotation_euler = (at - frm).to_track_quat("-Z", "Y").to_euler()

    def shot(path):
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)

    ## The head he wears whole (inhaler_head.gd at size 3: x, up, depth).
    WORN_HEAD = (3.36 * 1.04, 3.36, 3.36 * 0.84)
    WORN_CLIPS = ("hunt_stride", "shoulder_run", "charge_tell", "charge_run", "charge_skid", "charge_stagger")
    ## The knock-off's clips: worn too, the edge ones on a ledge (its rim
    ## EDGE_AT ahead; the leap's rim behind where he comes up), the root's
    ## way as the game would move it (`knock_root`).
    KNOCK_CLIPS = ("teeter_catch", "teeter", "teeter_back", "topple", "rim_leap", "rim_land", "back_hit")
    WORN_CLIPS = WORN_CLIPS + KNOCK_CLIPS
    LEDGE_AT = {"teeter_catch": EDGE_AT, "teeter": EDGE_AT, "teeter_back": EDGE_AT, "topple": EDGE_AT,
                "rim_leap": -1.2}
    bpy.ops.mesh.primitive_cube_add(size=1)
    ledge = bpy.context.active_object
    ledge.scale = (40, 40, 30)
    ledge.hide_render = True

    def knock_root(name, t):
        """(up, forward) of the root, for the stills."""
        if name == "topple" and t > TOPPLE_GO:
            d = t - TOPPLE_GO
            return -0.5 * 14.0 * d * d, 1.2 * d
        if name == "rim_leap":
            k = t / RIM_LEAP
            return -7.5 + 7.5 * k + 18.0 * k * (1 - k), -4.6 + 4.6 * smooth01(0.0, 1.0, k)
        return 0.0, 0.0
    rig.animation_data.action = None
    rig.animation_data.use_nla = False
    for tr in rig.animation_data.nla_tracks: tr.mute = True
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    scene.frame_set(0)
    for nm, frm in (("front", F(-9, 6.5, 22)), ("side", F(-24, 6.0, 0.5)), ("back", F(8, 7, -22)), ("high", F(-12, 18, 14))):
        look(frm, F(0, 4.5, 0))
        shot(out / f"rest_{nm}.png")
    for c in CLIPS:
        if ONLY and c.name not in ONLY: continue
        rig.animation_data.action = ACTIONS[c.name]
        frames = round(c.length * FPS)
        climbing = c.name in ("climb", "haul", "spawn_haul", "mantle", "mantle_pull")
        wall.hide_render = not climbing
        if c.name in ("mantle", "mantle_pull"):
            wall.location = (0, CLIMB_WALL + 4.0, (PULL_UP if c.name == "mantle_pull" else MANTLE_UP) - 15.0)
        else:
            wall.location = (0, CLIMB_WALL + 4.0, (SHOULDER_Y + 2.3 if c.name != "climb" else 30.0) - 15.0)
        floor.hide_render = climbing
        # The periscope: a stand-in for the head it wears, on the stump or
        # held between the wrists (as the game carries it).
        scoping = c.name.startswith("scope_")
        if scoping and "ScopeHead" not in bpy.data.objects:
            bpy.ops.mesh.primitive_cube_add(size=1)
            hd = bpy.context.active_object
            hd.name = "ScopeHead"
            hd.scale = (SCOPE_HEAD_W, 2.6 * 1.12 * 0.84, 2.6 * 1.12)
        if "ScopeHead" in bpy.data.objects: bpy.data.objects["ScopeHead"].hide_render = not scoping
        # The whole Olmec's clips: his head (a stand-in box) worn on the
        # stump, turned with the neck; shot from the side, the front, head on (as the wanderer sees him come) and
        # behind and above (as the play camera chases him).
        worn = c.name in WORN_CLIPS
        if worn and "WornHead" not in bpy.data.objects:
            bpy.ops.mesh.primitive_cube_add(size=1)
            bpy.context.active_object.name = "WornHead"
        if "WornHead" in bpy.data.objects: bpy.data.objects["WornHead"].hide_render = not worn
        views = (("", None),) if not worn else (("side_", F(-24, 6.5, 0.5)), ("front_", F(-10, 6.0, 12)), ("toward_", F(1.5, 8.5, 24)), ("chase_", F(5, 13, -21)))
        knock = c.name in KNOCK_CLIPS
        if knock:
            views = (("side_", F(-21, 5.0, 1.5)), ("front_", F(-12, 7.0, 15)))
            if c.name == "back_hit": views = (("side_", F(-21, 5.0, 1.5)), ("chase_", F(10, 10, -17)))
        ledge.hide_render = c.name not in LEDGE_AT
        if c.name in LEDGE_AT:
            ledge.location = (0, LEDGE_AT[c.name] - 20.0, -15.0)
        floor.hide_render = floor.hide_render or c.name in LEDGE_AT
        n = 8
        for i in range(n):
            f = round(frames * i / (n - 1)) if not c.loop else round(frames * i / n)
            scene.frame_set(f)
            # The root's way as the game moves it, so the stills show it.
            rig.location = (0, 0, 0)
            if knock:
                up, fwd = knock_root(c.name, c.length * f / max(frames, 1))
                rig.location = (0, fwd, up)
            if worn:
                bpy.context.view_layer.update()
                hm = rig.matrix_world @ rig.pose.bones["neck"].matrix @ Matrix.Translation(V((0, SEAT - NECK + WORN_HEAD[1] * 0.5, 0)))
                hd = bpy.data.objects["WornHead"]
                hd.matrix_world = hm @ Matrix.Diagonal(V((WORN_HEAD[0], WORN_HEAD[1], WORN_HEAD[2], 1.0)))
                for pre, frm in views:
                    look(frm, F(0, 4.6, 0) if not knock else F(0, 3.8 + rig.location.z * 0.6, 1.0 + rig.location.y * 0.6))
                    shot(out / f"{c.name}_{pre}{i:02d}.png")
                continue
            if c.name in ("mantle", "mantle_pull"):
                up, over = mantle_root(f / frames, c.name == "mantle_pull")
                rig.location = (0, over, up)
            elif c.name == "climb":
                rig.location = (0, 0, CLIMB_RISE * f / frames)
            if climbing:
                look(F(-15, 6.0, -8), F(0, 5.0, 0.5))
            elif scoping:
                look(F(-12, 8.0, 17), F(0, 6.4, 0))
            else:
                look(F(-10, 6.0, 12), F(0, 4.3, 0))
            if scoping:
                bpy.context.view_layer.update()
                pbs = rig.pose.bones
                u = f / max(frames, 1)
                held = (c.name == "scope_lift" and u >= SCOPE_TAKE) or c.name == "scope_look" or \
                    (c.name == "scope_lower" and u < SCOPE_SEAT)
                if held:
                    chin = (pbs["hand.L"].head + pbs["hand.R"].head) * 0.5 - V((0, 0, SCOPE_GRIP * pbs["root"].scale[2]))
                else:
                    chin = pbs["neck"].matrix @ V((0, SEAT - NECK, 0))
                bpy.data.objects["ScopeHead"].location = rig.matrix_world @ chin + V((0, 0, 2.6 * 1.12 * 0.5))
            shot(out / f"{c.name}_{i:02d}.png")
        print("BODY_RENDERED", c.name)
