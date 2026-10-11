"""Build the sky dragon (scripts/sky_dragon.gd, docs/design/rim-dragon.md,
round 3): a wyvern after Smaug, in one of three dresses over one body and
one rig.

Round 3's body: the wings are the forelimbs (no forelegs), each with a big
hooked thumb claw at the wrist that it would walk on. A long, thick,
serpentine neck; a massive deep chest and shoulders where the wing muscles
anchor; a lean waist into heavy hips and two hind legs; a tail longer than
head to hips, thick at the root and tapering to a whip with a blade. The
head is a long wedge under a heavy brow with horns swept back, so it reads
from the side and head on, not only from behind. The wings are enormous:
about 124 m span and 20 m chord at the arm before the game's scale.

The mouth has no lipstick: the lips are the hide, the palate and tongue a
deep maroon to near black, the teeth ivory. Cheek skin webs from the upper
lip to the jaw at the back of the mouth (weighted between the head and
the jaw, so it stretches when the jaw drops), and the jaw's front half is
its own bone (jaw.tip) so the lower lip can follow through on a spring.

Everything is lofted from a few cross sections and flat shaded, so it
reads as large crisp planes like the islands and basalt peaks.

Dresses (--style=):
  a  angular: the fewest planes, few spikes.
  b  carved: more rings, banded neck and belly, a double row of back
     plates.
  c  stone and glow (the game's default): a's solids, a matte stone hide,
     soft smooth glowing membranes and glowing back fins.

Rig (Blender +Y forward, +Z up; the glTF exporter turns it into Godot -Z
forward). The origin is the body's middle between the wing roots.
  root                                         not deforming
  chest  spine.2  neck.0 .. neck.4  head  jaw  jaw.tip
  hips   tail.0 .. tail.7
  wing_arm wing_fore wing_hand wing_f1 wing_f1b wing_f2 wing_f3 wing_f4 (.L/.R)
  hind_upper hind_lower hind_foot (.L/.R)
Rest = gliding: wings spread flat, legs hanging. No clips; the game poses
the bones.

    /opt/homebrew/bin/blender -b --python art/blender/rim_dragon/dragon_body_build.py -- --style=c [--out=DIR] [--blend]

Writes assets/models/rim_dragon_<style>.glb (or into DIR), printing
DRAGON_TRIS and each part's count; --blend also saves
art/blender/rim_dragon/rim_dragon_<style>.blend.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

V = Vector
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
STYLE = "c"
OUT = ROOT / "assets/models"
SAVE_BLEND = False
for a in _args:
    if a.startswith("--style="): STYLE = a.split("=", 1)[1]
    elif a.startswith("--out="): OUT = Path(a.split("=", 1)[1])
    elif a == "--blend": SAVE_BLEND = True
assert STYLE in ("a", "b", "c"), STYLE
GLB = OUT / f"rim_dragon_{STYLE}.glb"
rng = random.Random(11)

DRESS = {
    "a": dict(ring=2.3, body_sides=8, tube=5, mem=(5, 3), jitter=0.06, smooth_mem=False),
    "b": dict(ring=1.45, body_sides=12, tube=6, mem=(7, 5), jitter=0.05, smooth_mem=False),
    "c": dict(ring=2.0, body_sides=8, tube=5, mem=(14, 9), jitter=0.06, smooth_mem=True),
}[STYLE]

# ------------------------------------------------------------------ palette
# The game paints by material name (scripts/sky_dragon.gd keeps its own
# versions); these are for Blender's stills.
PALETTE = {
    "dragon_hide": ("5a4a6e", 0.55),
    "dragon_belly": ("7a6a82", 0.6),
    "dragon_horn": ("8c8290", 0.5),
    "dragon_tooth": ("efe6d2", 0.4),
    "dragon_claw": ("d6ccb8", 0.45),
    "dragon_mouth": ("2a1218", 0.6),
    "dragon_tongue": ("3e1a22", 0.5),
    "dragon_eye": ("ffc54a", 0.3),
    "dragon_membrane": ("3c2c4c", 0.7),
    "dragon_membrane_glow": ("8a5ab0", 0.7),
    "dragon_glow": ("ffb060", 0.4),
}

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials = {}
for key, (h, rough) in PALETTE.items():
    m = bpy.data.materials.new(key)
    rgb = [srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    m.diffuse_color = (*rgb, 1.0)
    m.roughness = rough
    try:
        m.use_nodes = True
    except Exception:
        pass
    if m.node_tree:
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
            bsdf.inputs["Roughness"].default_value = rough
    materials[key] = m

# ------------------------------------------------------------------ skeleton
# The body's line, the occiput to the tail tip. The neck rises in a long,
# shallow S from the chest and carries the head out level.
NECK = [V((0, 24.5, 6.4)), V((0, 20.6, 7.6)), V((0, 16.2, 6.9)), V((0, 11.9, 4.6)), V((0, 7.5, 1.9))]
C1 = V((0, 3.0, 0.6))      # the chest: deep, massive, the wing muscles' anchor
C0 = V((0, -3.5, 0.7))     # the waist: lean
P0 = V((0, -8.5, 0.4))     # the hips
TAIL = [V((0, -13.5, -0.1)), V((0, -19.0, -0.5)), V((0, -24.5, -0.8)), V((0, -30.0, -0.9)),
        V((0, -35.5, -0.8)), V((0, -41.0, -0.6)), V((0, -46.5, -0.4)), V((0, -51.5, -0.2))]
LINE = NECK + [C1, C0, P0] + TAIL
HEAD0 = NECK[0].copy()
# Half width, height over the line, depth under it, the dorsal ridge's rise.
SECTION = [
    (2.1, 2.1, 2.3, 0.25),   # the occiput (inside the head)
    (2.5, 2.3, 2.6, 0.35),
    (3.0, 2.6, 3.1, 0.4),
    (3.7, 2.95, 3.8, 0.45),
    (4.7, 3.3, 4.6, 0.5),    # the neck's root, swelling into the chest
    (6.0, 3.7, 5.7, 0.55),   # the chest: deep and broad
    (3.5, 2.7, 3.0, 0.45),   # the waist
    (3.7, 2.6, 2.7, 0.4),    # the hips
    (2.9, 2.1, 2.1, 0.35),
    (2.25, 1.7, 1.6, 0.32),
    (1.75, 1.32, 1.2, 0.28),
    (1.32, 1.02, 0.9, 0.25),
    (0.96, 0.76, 0.66, 0.22),
    (0.64, 0.52, 0.45, 0.18),
    (0.36, 0.3, 0.27, 0.12),
    (0.1, 0.1, 0.08, 0.04),
]
assert len(SECTION) == len(LINE)
HINGE = HEAD0 + V((0, 0.4, -1.25))
JAW_TIP0 = HEAD0 + V((0, 5.2, -1.6))
NN = len(NECK)

def side_pts(n, s):
    """Mirror a right-side point to side s (+1 right, -1 left)."""
    return V((n.x * s, n.y, n.z))

BONES = {
    "root": (V((0, 0, 0)), V((0, 1, 0)), None),
    "chest": (C0, C1, "root"),
    "spine.2": (C1, NECK[-1], "chest"),
}
# neck.0 at the root out to neck.4 at the head.
prev, parent = NECK[-1], "spine.2"
for i in range(NN - 1):
    p = NECK[NN - 2 - i]
    BONES[f"neck.{i}"] = (prev, p, parent)
    prev, parent = p, f"neck.{i}"
BONES["head"] = (HEAD0, HEAD0 + V((0, 4.0, 0)), parent)
BONES["jaw"] = (HINGE, JAW_TIP0, "head")
BONES["jaw.tip"] = (JAW_TIP0, JAW_TIP0 + V((0, 4.5, 0.4)), "jaw")
BONES["hips"] = (C0 + V((0, -0.01, 0)), P0, "root")
prev = P0
for i, t in enumerate(TAIL):
    BONES[f"tail.{i}"] = (prev, t, "hips" if i == 0 else f"tail.{i - 1}")
    prev = t

# The wing (right side; the left mirrored): the forelimb. A heavy upper arm
# off the shoulder, a long forearm, the wrist with its thumb, the fingers.
W = dict(
    SH=V((3.8, 3.4, 3.3)), EL=V((17.0, -3.8, 4.4)), WR=V((33.0, 3.2, 4.8)), KN=V((35.0, 2.2, 4.8)),
    F1M=V((45.0, -3.6, 4.2)), F1T=V((61.0, -12.5, 3.0)), F2T=V((54.0, -29.0, 3.4)),
    F3T=V((41.5, -36.0, 3.6)), F4T=V((26.0, -31.5, 3.6)),
    TRAIL=V((3.8, -10.5, 0.8)),
)
# The hind legs (right side): a heavy thigh, the knee forward, the hock.
LEG = dict(HS=V((3.4, -8.0, -0.4)), HK=V((4.8, -4.6, -4.6)), HH=V((4.6, -9.2, -7.6)), HT=V((4.6, -6.6, -9.4)))
for n, s in (("L", -1.0), ("R", 1.0)):
    m = {k: side_pts(v, s) for k, v in W.items()}
    BONES[f"wing_arm.{n}"] = (m["SH"], m["EL"], "chest")
    BONES[f"wing_fore.{n}"] = (m["EL"], m["WR"], f"wing_arm.{n}")
    BONES[f"wing_hand.{n}"] = (m["WR"], m["KN"], f"wing_fore.{n}")
    BONES[f"wing_f1.{n}"] = (m["KN"], m["F1M"], f"wing_hand.{n}")
    BONES[f"wing_f1b.{n}"] = (m["F1M"], m["F1T"], f"wing_f1.{n}")
    for f in (2, 3, 4):
        BONES[f"wing_f{f}.{n}"] = (m["KN"], m[f"F{f}T"], f"wing_hand.{n}")
    l = {k: side_pts(v, s) for k, v in LEG.items()}
    BONES[f"hind_upper.{n}"] = (l["HS"], l["HK"], "hips")
    BONES[f"hind_lower.{n}"] = (l["HK"], l["HH"], f"hind_upper.{n}")
    BONES[f"hind_foot.{n}"] = (l["HH"], l["HT"], f"hind_lower.{n}")

arm_data = bpy.data.armatures.new("DragonRig")
rig = bpy.data.objects.new("DragonRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for name, (head, tail, parent) in BONES.items():
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = head, tail
    along = (tail - head).normalized()
    ref = V((0, 0, 1)) if abs(along.z) < 0.9 else V((0, 1, 0))
    eb.align_roll(ref - along * along.dot(ref))
    eb.use_deform = name != "root"
    if parent:
        eb.parent = arm_data.edit_bones[parent]
        eb.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")

def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length

def weights_at(p, bones, soft=0.8, power=4.0, keep=3):
    """Bone weights for a point: inverse distance to each bone's segment,
    the nearest `keep`, normalised."""
    ws = sorted(((1.0 / (seg_dist(p, BONES[b][0], BONES[b][1]) + soft) ** power, b) for b in bones), reverse=True)[:keep]
    tot = sum(w for w, _ in ws)
    return {b: w / tot for w, b in ws if w / tot > 0.02}

# ------------------------------------------------------------------ parts
parts = []

class Part:
    """A mesh under construction: vertices, faces (each with a material
    key), each vertex's weights."""
    def __init__(self, name, smooth=False):
        self.name, self.smooth = name, smooth
        self.verts, self.faces, self.mats, self.weights, self.uvs = [], [], [], [], []

    def v(self, p, w):
        self.verts.append(V(p))
        self.weights.append(w)
        return len(self.verts) - 1

    def f(self, idx, mat, uv=None):
        self.faces.append(tuple(idx))
        self.mats.append(mat)
        self.uvs.append(uv)

def build(part, recalc=True):
    me = bpy.data.meshes.new(part.name)
    me.from_pydata([tuple(v) for v in part.verts], [], part.faces)
    me.update()
    ob = bpy.data.objects.new(part.name, me)
    scene.collection.objects.link(ob)
    keys = []
    for k in part.mats:
        if k not in keys:
            keys.append(k)
            me.materials.append(materials[k])
    for i, poly in enumerate(me.polygons):
        poly.material_index = keys.index(part.mats[i])
        poly.use_smooth = part.smooth
    if any(uv is not None for uv in part.uvs):
        layer = me.uv_layers.new(name="UVMap")
        for i, poly in enumerate(me.polygons):
            uv = part.uvs[i]
            for k, li in enumerate(poly.loop_indices):
                layer.data[li].uv = uv[k] if uv else (0.0, 0.0)
    groups = {}
    for vi, w in enumerate(part.weights):
        for b, x in w.items():
            if b not in groups: groups[b] = ob.vertex_groups.new(name=b)
            groups[b].add([vi], x, "REPLACE")
    if recalc:
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
    parts.append(ob)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print(f"DRAGON_PART {part.name} tris={tris}")
    return ob

def loft(part, rings, mat_of, weight_of, cap_start=True, cap_end=True, tip_end=None):
    """Faces between consecutive rings (lists of points, the same count);
    `mat_of(ring_i, k)` the material of the quad from ring i, side k;
    `weight_of(ring_i, point)` a vertex's weights. Ends capped (a fan to
    the centre), or the end drawn to `tip_end` (a point)."""
    idx = [[part.v(p, weight_of(i, p)) for p in ring] for i, ring in enumerate(rings)]
    n = len(rings[0])
    for i in range(len(rings) - 1):
        for k in range(n):
            part.f((idx[i][k], idx[i][(k + 1) % n], idx[i + 1][(k + 1) % n], idx[i + 1][k]), mat_of(i, k))
    if cap_start:
        c = sum(rings[0], V()) / n
        ci = part.v(c, weight_of(0, c))
        for k in range(n):
            part.f((ci, idx[0][(k + 1) % n], idx[0][k]), mat_of(0, k))
    last = len(rings) - 1
    if tip_end is not None:
        ti = part.v(tip_end, weight_of(last, tip_end))
        for k in range(n):
            part.f((idx[last][k], idx[last][(k + 1) % n], ti), mat_of(last, k))
    elif cap_end:
        c = sum(rings[last], V()) / n
        ci = part.v(c, weight_of(last, c))
        for k in range(n):
            part.f((idx[last][k], idx[last][(k + 1) % n], ci), mat_of(last, k))
    return idx

def catmull(pts, t):
    """Point on a Catmull-Rom curve through `pts` at t in [0, len-1]."""
    i = min(int(t), len(pts) - 2)
    u = t - i
    p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u)

def sample_line(pts, step=0.05):
    """Dense (t, point, arclength) along a Catmull-Rom line."""
    out = []
    total = 0.0
    last = None
    n = int((len(pts) - 1) / step * 1.0) + 1
    for k in range(n + 1):
        t = min(k * step, len(pts) - 1)
        p = catmull(pts, t)
        if last is not None: total += (p - last).length
        out.append((t, p, total))
        last = p
    return out

def at_length(samples, s):
    for i in range(1, len(samples)):
        if samples[i][2] >= s:
            a, b = samples[i - 1], samples[i]
            u = (s - a[2]) / max(b[2] - a[2], 1e-9)
            return a[0] + (b[0] - a[0]) * u, a[1].lerp(b[1], u), (b[1] - a[1]).normalized()
    a, b = samples[-2], samples[-1]
    return b[0], b[1], (b[1] - a[1]).normalized()

def tube(part, pts, radii, sides, mat, bones, tip=True, rings_per=None, flat=1.0, rot=0.0):
    """A tube along a Catmull-Rom line through `pts`, radii per point,
    `sides` sides (`flat` squashes it vertically), drawn to a point at the
    end if `tip`, weighted among `bones`."""
    samples = sample_line(pts, 0.05)
    total = samples[-1][2]
    count = rings_per if rings_per else max(2, len(pts))
    rings = []
    for k in range(count):
        s = total * k / (count - 1)
        if tip and k == count - 1: break
        t, p, d = at_length(samples, s)
        i = min(int(t), len(radii) - 2)
        r = radii[i] + (radii[i + 1] - radii[i]) * (t - i)
        side = d.cross(V((0, 0, 1)))
        if side.length < 1e-3: side = d.cross(V((1, 0, 0)))
        side.normalize()
        up = side.cross(d).normalized()
        rings.append([p + (side * math.cos(a) + up * math.sin(a) * flat) * r
                      for a in (j / sides * math.tau + rot for j in range(sides))])
    endp = samples[-1][1]
    wfun = (lambda i, p: {bones: 1.0}) if isinstance(bones, str) else (lambda i, p: weights_at(p, bones))
    loft(part, rings, lambda i, k: mat, wfun, cap_start=True, cap_end=not tip, tip_end=endp if tip else None)

def blade(part, base0, base1, apex, thick, mat, w):
    """A thin faceted blade: a wedge from the base line up to `apex`."""
    d = (base1 - base0)
    side = d.cross(apex - base0).normalized() * thick
    mid = (base0 + base1) * 0.5
    a, b = part.v(base0, w), part.v(base1, w)
    l, r = part.v(mid + side, w), part.v(mid - side, w)
    t = part.v(apex, w)
    for f in ((a, l, t), (l, b, t), (b, r, t), (r, a, t), (a, r, b), (a, b, l)):
        part.f(f, mat)

def cone(part, base, axis, length, radius, sides, mat, w, curl=V((0, 0, 0))):
    """A curved cone (tooth, claw, spike) from `base` along `axis`, the
    tip bent by `curl`."""
    axis = axis.normalized()
    side = axis.cross(V((0, 0, 1)))
    if side.length < 1e-3: side = axis.cross(V((1, 0, 0)))
    side.normalize()
    up = side.cross(axis).normalized()
    mid = base + axis * length * 0.5 + curl * 0.3
    tipp = base + axis * length + curl
    rings = [[base + (side * math.cos(a) + up * math.sin(a)) * radius for a in (j / sides * math.tau for j in range(sides))],
             [mid + (side * math.cos(a) + up * math.sin(a)) * radius * 0.6 for a in (j / sides * math.tau for j in range(sides))]]
    loft(part, rings, lambda i, k: mat, lambda i, p: w, cap_start=True, tip_end=tipp)

# ================================================================== the body
# One loft from the head's base down the neck, the chest and waist, and out
# along the tail to its tip. Each ring's weights follow the bones along
# the line by the ring's centre (so a deep chest ring moves as one).
CHAIN = ["head"] + [f"neck.{i}" for i in reversed(range(NN - 1))] + ["spine.2", "chest", "hips"] + [f"tail.{i}" for i in range(len(TAIL))]
line = sample_line(LINE, 0.02)
line_len = line[-1][2]

def section_at(t):
    i = min(int(t), len(SECTION) - 2)
    u = t - i
    u = u * u * (3 - 2 * u) * 0.5 + u * 0.5
    return [SECTION[i][j] + (SECTION[i + 1][j] - SECTION[i][j]) * u for j in range(4)]

TEMPLATE = {
    8: [(0.0, 1.0), (0.70, 0.74), (1.0, 0.02), (0.74, -0.72), (0.0, -1.0)],
    12: [(0.0, 1.0), (0.42, 0.93), (0.80, 0.62), (1.0, 0.08), (0.88, -0.48), (0.50, -0.90), (0.0, -1.0)],
}[DRESS["body_sides"]]

def outline(w, top, bot, ridge, jit):
    right = []
    for k, (fx, fz) in enumerate(TEMPLATE):
        x = fx * w
        z = fz * (top if fz >= 0 else bot)
        if k == 0: z += ridge
        if 0 < k < len(TEMPLATE) - 1:
            x += jit[k][0] * w
            z += jit[k][1] * w
        right.append((x, z))
    return right + [(-x, z) for x, z in reversed(right[1:-1])]

def ring_at(s, scale=1.0, belly=0.0, jit=None):
    t, c, d = at_length(line, s)
    w, top, bot, ridge = section_at(t)
    side = d.cross(V((0, 0, 1))).normalized()
    up = side.cross(d).normalized()
    pts = outline(w * scale, top * scale, bot * scale + belly, ridge * scale, jit)
    return t, c, d, side, up, [c + side * x + up * z for x, z in pts]

body = Part("body")
step = DRESS["ring"]
count = max(8, int(line_len / step))
ring_s = [line_len * k / count for k in range(count)]
rings, centres, ts = [], [], []
nt = len(TEMPLATE)
for k, s in enumerate(ring_s):
    jit = [(rng.uniform(-1, 1) * DRESS["jitter"], rng.uniform(-1, 1) * DRESS["jitter"]) for _ in range(nt)]
    band, belly = 1.0, 0.0
    if STYLE == "b":
        band = 1.04 if k % 2 == 0 else 0.985
        belly = 0.14 if k % 2 == 0 else 0.0
    t, c, d, side, up, ring = ring_at(s, band, belly, jit)
    rings.append(ring)
    centres.append(c)
    ts.append(t)
n_side = len(rings[0])
belly_k = set()
half = len(TEMPLATE) - 1
for k in range(n_side):
    if k in (half - 1, half) or (STYLE == "b" and k in (half - 2, half + 1)):
        belly_k.add(k)

def body_mat(i, k):
    # The belly's plates from the throat to the tail's root.
    if k in belly_k and 0.5 < ts[i] < NN + 4.5: return "dragon_belly"
    return "dragon_hide"

def body_w(i, p):
    c = centres[i] if i < len(centres) else p
    return weights_at(c, CHAIN, soft=0.9, power=3.0, keep=2)

tip = line[-1][1] + (line[-1][1] - line[-5][1]).normalized() * 0.6
loft(body, rings, body_mat, body_w, cap_start=True, tip_end=tip)
build(body)

# The shoulders: a heavy mass of wing muscle over each side of the chest.
shoulders = Part("shoulders")
for n, s in (("L", -1.0), ("R", 1.0)):
    m = {k: side_pts(v, s) for k, v in W.items()}
    tube(shoulders, [V((s * 1.2, 5.6, 2.4)), V((s * 3.0, 3.4, 3.2)), m["SH"] + V((s * 0.6, -0.6, -0.2)), V((s * 3.4, -1.2, 1.2))],
         [1.6, 3.0, 2.7, 1.2], DRESS["tube"] + 1, "dragon_hide", ["chest", f"wing_arm.{n}"], tip=False, rings_per=5, flat=0.75)
build(shoulders)

# ---- dorsal blades: the neck, the back, the tail.
spikes = Part("spines", smooth=False)
glow = Part("glow_fins", smooth=True)

def top_at(s):
    t, c, d, side, up, ring = ring_at(s, 1.0, 0.0, [(0, 0)] * nt)
    return ring[0], d, up, side, section_at(t)[0]

def spike_row(s0, s1, count, h0, h1, lean=0.6, offset=0.0, mat="dragon_horn", target=None):
    target = target or spikes
    for k in range(count):
        u = k / max(count - 1, 1)
        s = s0 + (s1 - s0) * u
        h = h0 + (h1 - h0) * u
        top, d, up, side, w = top_at(s)
        base = top + side * offset * w - up * 0.15
        L = max(h * 0.9, 0.6)
        w8 = weights_at(base, CHAIN, soft=0.9, power=3.0, keep=2)
        blade(target, base - d * L * 0.5, base + d * L * 0.5, base + up * h + d * h * lean, max(0.08, h * 0.12), mat, w8)

def s_of(point):
    return min(line, key=lambda x: (x[1] - point).length)[2]

s_head, s_n0, s_c0, s_p0 = s_of(NECK[0]), s_of(NECK[-1]), s_of(C0), s_of(P0)
fin_target = glow if STYLE == "c" else spikes
fin_mat = "dragon_glow" if STYLE == "c" else "dragon_horn"
if STYLE == "b":
    spike_row(s_head + 2.0, s_n0, 9, 1.0, 1.6)
    spike_row(s_n0 + 1.0, s_p0, 8, 1.9, 1.4)
    spike_row(s_p0 + 1.2, line_len - 4.0, 16, 1.3, 0.3)
    for off in (-0.42, 0.42):
        spike_row(s_head + 2.6, s_p0 + 3.0, 14, 0.55, 0.5, lean=0.9, offset=off)
else:
    spike_row(s_head + 2.4, s_n0, 6, 1.0, 1.6, target=fin_target, mat=fin_mat)
    spike_row(s_n0 + 1.2, s_p0, 5, 2.1, 1.5, target=fin_target, mat=fin_mat)
    spike_row(s_p0 + 1.5, line_len - 5.0, 11, 1.3, 0.35, target=fin_target, mat=fin_mat)
# The tail's blade: a flat spade at the whip's end.
tt = line[-1][1]
td = (line[-1][1] - line[-12][1]).normalized()
w_tail = {f"tail.{len(TAIL) - 1}": 1.0}
for up_s in (1.0, -1.0):
    tgt = glow if STYLE == "c" else spikes
    blade(tgt, tt - td * 4.0, tt + td * 0.6, tt - td * 1.4 + V((0, 0, 1.9 * up_s)), 0.12,
          "dragon_glow" if STYLE == "c" else "dragon_horn", w_tail)
build(spikes) if spikes.faces else None
build(glow) if glow.faces else None

# ================================================================== the head
# A long wedge: the skull broad behind the cheeks, the brow peaked out over
# the eyes, the top falling in a straight line to a narrow snout.
H = lambda x, y, z: HEAD0 + V((x, y, z))
# (y, top z, (x, z) x4 down the right side: upper side, widest, cheek, the
# lip's edge; the palate's middle z).
HEAD_SECTIONS = [
    (-1.4, 2.2, (1.6, 1.9), (2.2, 0.5), (2.0, -0.8), (1.4, -1.5), -1.7),
    (0.6, 2.9, (2.2, 2.7), (3.0, 0.9), (2.9, -0.6), (2.4, -1.2), -1.3),
    (2.6, 3.15, (3.25, 3.35), (3.3, 1.4), (2.9, -0.4), (2.45, -1.1), -1.2),
    (3.9, 2.75, (2.7, 2.75), (2.8, 1.3), (2.5, -0.4), (2.2, -1.05), -1.15),
    (5.6, 2.15, (1.9, 1.95), (2.2, 0.8), (2.1, -0.5), (1.9, -1.0), -1.1),
    (7.6, 1.6, (1.5, 1.45), (1.8, 0.5), (1.75, -0.55), (1.55, -0.95), -1.05),
    (9.5, 1.1, (1.15, 1.0), (1.45, 0.3), (1.4, -0.55), (1.2, -0.9), -1.0),
    (10.7, 0.5, (0.7, 0.45), (0.9, 0.0), (0.85, -0.6), (0.6, -0.85), -0.9),
]
if STYLE == "b":
    HEAD_SECTIONS.insert(4, (4.7, 2.45, (2.3, 2.35), (2.5, 1.05), (2.3, -0.45), (2.05, -1.02), -1.12))
    HEAD_SECTIONS.insert(6, (6.6, 1.88, (1.7, 1.7), (2.0, 0.65), (1.92, -0.52), (1.72, -0.97), -1.07))

def head_ring(sec):
    y, zt, a, b, c, d, zb = sec
    right = [(0.0, zt), a, b, c, d]
    pts = right + [(0.0, zb)] + [(-x, z) for x, z in reversed(right[1:])]
    return [H(x, y, z) for x, z in pts]

head = Part("head")
hr = [head_ring(s) for s in HEAD_SECTIONS]

def head_mat(i, k):
    # The palate (round the bottom point) dark; the lips stay hide.
    return "dragon_mouth" if k in (4, 5) else "dragon_hide"

loft(head, hr, head_mat, lambda i, p: {"head": 1.0})
build(head)

def head_edge(y, j):
    """The head's outline point j (1..4) at y along the head."""
    for i in range(len(HEAD_SECTIONS) - 1):
        a, b = HEAD_SECTIONS[i], HEAD_SECTIONS[i + 1]
        if a[0] <= y <= b[0]:
            u = (y - a[0]) / (b[0] - a[0])
            return a[1 + j][0] + (b[1 + j][0] - a[1 + j][0]) * u, a[1 + j][1] + (b[1 + j][1] - a[1 + j][1]) * u
    return HEAD_SECTIONS[-1][1 + j]

# The eyes: amber slits sunk under the brow's overhang.
eyes = Part("eyes")
for s in (-1, 1):
    x, z = head_edge(3.4, 1)
    c = H(s * (x - 0.05), 3.4, 1.95)
    pts = [c + V((s * 0.18, 0, 0)), c + V((0, 0.65, -0.05)), c + V((0, 0, 0.22)), c + V((0, -0.55, 0.05)), c + V((0, 0, -0.2))]
    i = [eyes.v(p, {"head": 1.0}) for p in pts]
    for f in ((0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1)):
        eyes.f([i[x] for x in f], "dragon_eye")
build(eyes)

# The horns: the great pair swept back off the crown; a lesser pair off
# the cheeks; a ridge of blades over each brow; nostril bosses.
horns = Part("horns")
ts_ = DRESS["tube"]
for s in (-1, 1):
    pts = [H(s * 2.3, 1.6, 2.9), H(s * 3.3, -0.6, 3.8), H(s * 4.1, -3.4, 4.1), H(s * 4.6, -6.4, 3.7),
           H(s * 4.7, -8.6, 2.9), H(s * 4.6, -9.8, 2.2)]
    tube(horns, pts, [1.15, 0.95, 0.72, 0.48, 0.24, 0.05], ts_, "dragon_horn", "head", rings_per=14 if STYLE == "b" else 7)
    pts = [H(s * 2.9, 0.4, -0.3), H(s * 3.8, -1.4, 0.0), H(s * 4.3, -3.2, -0.4), H(s * 4.4, -4.2, -1.0)]
    tube(horns, pts, [0.6, 0.42, 0.22, 0.05], ts_, "dragon_horn", "head", rings_per=5)
    # The brow ridge: blades raked back over the eye.
    for k in range(3):
        base = H(s * (3.1 - k * 0.25), 3.3 - k * 1.0, 3.1 + k * 0.05)
        blade(horns, base + V((0, 0.55, 0)), base - V((0, 0.55, 0)), base + V((s * 0.45, -1.1, 0.55)), 0.13, "dragon_horn", {"head": 1.0})
    # Cheek spikes fanned back off the jaw's corner.
    for k in range(2):
        base = H(s * 2.85, 0.9 - k * 0.9, -0.9 - k * 0.2)
        blade(horns, base + V((0, 0.4, 0)), base - V((0, 0.4, 0)), base + V((s * 0.9, -1.4, -0.2)), 0.12, "dragon_horn", {"head": 1.0})
    # The nostril's boss.
    cone(horns, H(s * 0.85, 9.6, 0.95), V((s * 0.3, 0.4, 1.0)), 0.55, 0.3, 4, "dragon_horn", {"head": 1.0})
# Spikes down the back of the skull.
for k in range(3 if STYLE != "b" else 5):
    base = H(0, 0.6 - k * 0.9, 2.95 - k * 0.3)
    blade(horns, base + V((0, 0.5, 0)), base - V((0, 0.5, 0)), base + V((0, -1.0, 1.0 - k * 0.12)), 0.12, "dragon_horn", {"head": 1.0})
build(horns)

# The upper teeth along the lip's edge, fangs at the front and middle.
teeth = Part("teeth")
tooth_sides = 4 if STYLE != "b" else 5
for s in (-1, 1):
    for k, y in enumerate((2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0)):
        x, z = head_edge(y, 4)
        big = 1.0 if k in (3, 7) else 0.55
        cone(teeth, H(s * (x - 0.2), y, z + 0.08), V((0, 0.12, -1)), 1.05 * big, 0.22 * big ** 0.5, tooth_sides, "dragon_tooth", {"head": 1.0},
             curl=V((0, -0.12, 0)))
for x in (-0.35, 0.35):
    cone(teeth, H(x, 10.45, -0.8), V((0, 0.2, -1)), 0.55, 0.15, tooth_sides, "dragon_tooth", {"head": 1.0})
build(teeth)

# ================================================================== the jaw
# (y, top z, top x, (side x, z), (bottom x, z), bottom middle z). The rear
# weighted to jaw, the front half to jaw.tip (the lower lip's follow).
JAW = [
    (-0.6, -1.05, 2.0, (2.4, -1.9), (1.6, -2.8), -3.0),
    (1.5, -1.15, 2.35, (2.7, -2.2), (2.0, -3.1), -3.3),
    (4.0, -1.15, 2.1, (2.35, -2.0), (1.7, -2.75), -2.9),
    (6.5, -1.1, 1.75, (1.95, -1.8), (1.35, -2.4), -2.5),
    (8.8, -1.05, 1.4, (1.55, -1.6), (1.0, -2.05), -2.15),
    (10.4, -0.95, 0.8, (0.92, -1.32), (0.58, -1.65), -1.72),
]

def jaw_w(y):
    u = max(0.0, min(1.0, (y - 3.6) / 3.2))
    return {"jaw": 1.0 - u, "jaw.tip": u} if 0.0 < u < 1.0 else ({"jaw": 1.0} if u <= 0.0 else {"jaw.tip": 1.0})

def jaw_ring(sec):
    y, zt, xt, side, bot, zb = sec
    right = [(0.0, zt - 0.15), (xt, zt), side, bot]
    pts = right + [(0.0, zb)] + [(-x, z) for x, z in reversed(right[1:])]
    return [H(x, y, z) for x, z in pts]

jaw = Part("jaw")
jr = [jaw_ring(s) for s in JAW]
loft(jaw, jr, lambda i, k: "dragon_tongue" if k in (0, 7) else "dragon_hide", lambda i, p: jaw_w(p.y - HEAD0.y))
build(jaw)
lteeth = Part("lower_teeth")
for s in (-1, 1):
    for k, y in enumerate((2.4, 3.6, 4.8, 6.0, 7.2, 8.4, 9.6)):
        for i in range(len(JAW) - 1):
            if JAW[i][0] <= y <= JAW[i + 1][0]:
                u = (y - JAW[i][0]) / (JAW[i + 1][0] - JAW[i][0])
                xt = JAW[i][2] + (JAW[i + 1][2] - JAW[i][2]) * u
        big = 1.0 if k in (4,) else 0.6
        cone(lteeth, H(s * (xt - 0.22), y, -1.2), V((0, 0.1, 1)), 0.85 * big, 0.2 * big ** 0.5, tooth_sides, "dragon_tooth", jaw_w(y))
build(lteeth)

# The cheek skin: a web from the upper lip down to the jaw's edge at the
# back of the mouth, weighted from the head to the jaw so it stretches
# open with the jaw. Two-sided (both windings).
cheek = Part("cheek")
for s in (-1, 1):
    ys = [0.0, 1.5, 3.0, 4.4]
    rows = 3
    grid = []
    for j in range(rows + 1):
        v = j / rows
        row = []
        for y in ys:
            ux, uz = head_edge(max(y, -1.39), 4)
            lx = 2.0 + (2.35 - 2.0) * max(0.0, min(1.0, (y + 0.6) / 2.1))
            top = H(s * (ux - 0.12), y, uz + 0.05)
            bot = H(s * (lx - 0.1), y, -1.15)
            # The front edge pinches in to the lip's corner.
            frontness = max(0.0, (y - 3.0)) / 1.4
            p = top.lerp(bot, v * (1.0 - 0.8 * frontness))
            w = 1.0 - v * (1.0 - 0.8 * frontness)
            row.append(cheek.v(p, {"head": w, "jaw": 1.0 - w} if 0.01 < w < 0.99 else ({"head": 1.0} if w >= 0.99 else {"jaw": 1.0})))
        grid.append(row)
    for j in range(rows):
        for i in range(len(ys) - 1):
            q = (grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
            cheek.f(q, "dragon_hide")
            cheek.f(tuple(reversed(q)), "dragon_hide")
build(cheek, recalc=False)

# ================================================================== wings
sides_t = DRESS["tube"]
for n, s in (("L", -1.0), ("R", 1.0)):
    m = {k: side_pts(v, s) for k, v in W.items()}
    arm = Part(f"wing_bones.{n}")
    wb = [f"wing_arm.{n}", f"wing_fore.{n}", f"wing_hand.{n}"]
    tube(arm, [m["SH"] + V((-s * 0.4, 0.3, -0.2)), m["SH"].lerp(m["EL"], 0.4) + V((0, 0, 0.6)), m["EL"]], [2.5, 1.55, 1.05], sides_t,
         "dragon_hide", ["chest", f"wing_arm.{n}"], tip=False, rings_per=4 if STYLE != "b" else 6, flat=0.8)
    tube(arm, [m["EL"], m["EL"].lerp(m["WR"], 0.5) + V((0, 0, 0.3)), m["WR"]], [1.1, 0.82, 0.78], sides_t,
         "dragon_hide", wb[:2], tip=False, rings_per=4 if STYLE != "b" else 6, flat=0.8)
    tube(arm, [m["WR"], m["KN"]], [0.95, 0.68], sides_t, "dragon_hide", wb[1:], tip=False, rings_per=2)
    # The thumb: a big hooked claw forward and down off the wrist, the one
    # it walks on.
    tube(arm, [m["WR"] + V((0, 0.2, 0)), m["WR"] + V((s * 0.3, 1.6, -0.3))], [0.6, 0.45], 4, "dragon_hide", f"wing_hand.{n}", tip=False, rings_per=2)
    cone(arm, m["WR"] + V((s * 0.3, 1.5, -0.3)), V((s * 0.1, 1.0, -0.5)), 2.6, 0.45, 4, "dragon_claw", {f"wing_hand.{n}": 1.0}, curl=V((0, -0.2, -0.9)))
    tube(arm, [m["KN"], m["F1M"], m["F1T"]], [0.62, 0.42, 0.08], sides_t, "dragon_hide", [f"wing_f1.{n}", f"wing_f1b.{n}"], rings_per=5)
    for f in (2, 3, 4):
        tube(arm, [m["KN"], m["KN"].lerp(m[f"F{f}T"], 0.5), m[f"F{f}T"]], [0.5, 0.32, 0.06], max(4, sides_t - 1),
             "dragon_hide", f"wing_f{f}.{n}", rings_per=4)
    build(arm)

    nu, nv = DRESS["mem"]
    mat = "dragon_membrane_glow" if STYLE == "c" else "dragon_membrane"
    mem = Part(f"membrane.{n}", smooth=DRESS["smooth_mem"])
    mb = [f"wing_arm.{n}", f"wing_fore.{n}", f"wing_hand.{n}", f"wing_f4.{n}", "chest", "hips"]

    def poly(points, u):
        lens = [0.0]
        for a, b in zip(points, points[1:]): lens.append(lens[-1] + (b - a).length)
        x = u * lens[-1]
        for i in range(1, len(points)):
            if x <= lens[i] or i == len(points) - 1:
                return points[i - 1].lerp(points[i], (x - lens[i - 1]) / max(lens[i] - lens[i - 1], 1e-9))

    def panel(lead, trail, bones, scallop, billow, nu, nv, scallop_at_u=False):
        grid = []
        for i in range(nu + 1):
            u = i / nu
            a = lead(u)
            b = trail(u)
            row = []
            for j in range(nv + 1):
                v = j / nv
                p = a.lerp(b, v)
                if scallop_at_u:
                    p = p.lerp(lead(0.0), scallop * math.sin(math.pi * v) * u ** 3)
                else:
                    p = p.lerp(a, scallop * v ** 2 * math.sin(math.pi * u))
                p = p + V((0, 0, billow * math.sin(math.pi * v) * math.sin(math.pi * min(u, 1.0))))
                row.append((p, (u, v)))
            grid.append(row)
        idx = [[mem.v(p, weights_at(p, bones, soft=1.2, power=3.0, keep=4)) for p, _ in row] for row in grid]
        uvs = [[uv for _, uv in row] for row in grid]
        for i in range(nu):
            for j in range(nv):
                mem.f((idx[i][j], idx[i + 1][j], idx[i + 1][j + 1], idx[i][j + 1]), mat,
                      (uvs[i][j], uvs[i + 1][j], uvs[i + 1][j + 1], uvs[i][j + 1]))

    lead_arm = [m["SH"], m["EL"], m["WR"], m["KN"]]
    panel(lambda u: poly(lead_arm, u), lambda u: m["TRAIL"].lerp(m["F4T"], u), mb, 0.26, 0.8, nu + 1, nv)
    spokes = [[m["KN"], m["F4T"]], [m["KN"], m["F3T"]], [m["KN"], m["F2T"]], [m["KN"], m["F1M"], m["F1T"]]]
    names = [f"wing_f4.{n}", f"wing_f3.{n}", f"wing_f2.{n}", f"wing_f1b.{n}"]
    for k in range(3):
        A, B = spokes[k], spokes[k + 1]
        bones = [names[k], names[k + 1], f"wing_hand.{n}"] + ([f"wing_f1.{n}"] if k == 2 else [])
        panel(lambda u, B=B: poly(B, u), lambda u, A=A: poly(A, u), bones, 0.16, 0.45, nu, max(2, nv - 1), scallop_at_u=True)
    panel(lambda u: m["SH"].lerp(m["WR"], u), lambda u: poly([m["SH"], m["EL"], m["WR"]], u),
          [f"wing_arm.{n}", f"wing_fore.{n}", "chest"], 0.0, 0.1, max(3, nu - 1), 1)
    build(mem, recalc=False)
    me = parts[-1].data
    for p in me.polygons:
        if p.normal.z < 0: p.flip()
    me.update()

# ================================================================== hind legs
for n, s in (("L", -1.0), ("R", 1.0)):
    l = {k: side_pts(v, s) for k, v in LEG.items()}
    legs = Part(f"legs.{n}")
    hb = [f"hind_upper.{n}", f"hind_lower.{n}", f"hind_foot.{n}"]
    rp = 4 if STYLE != "b" else 6
    tube(legs, [l["HS"] + V((0, 0.6, 0.8)), l["HS"].lerp(l["HK"], 0.45) + V((0, 0.5, 0)), l["HK"]], [3.3, 2.6, 1.5], sides_t + 1, "dragon_hide", ["hips"] + hb[:1], tip=False, rings_per=rp)
    tube(legs, [l["HK"], l["HK"].lerp(l["HH"], 0.5), l["HH"]], [1.45, 1.1, 0.9], sides_t, "dragon_hide", hb[:2], tip=False, rings_per=rp)
    tube(legs, [l["HH"], l["HT"]], [0.85, 0.6], sides_t, "dragon_hide", hb[2], tip=False, rings_per=2, flat=0.6)
    d = (l["HT"] - l["HH"]).normalized()
    for k in (-1, 0, 1):
        dd = (d + V((k * 0.45, 0, 0))).normalized()
        base = l["HT"] + V((k * 0.5, 0, 0))
        toe_end = base + dd * 1.1
        tube(legs, [base - dd * 0.4, toe_end], [0.36, 0.28], 4, "dragon_hide", hb[2], tip=False, rings_per=2)
        cone(legs, toe_end, (dd + V((0, 0, -0.7))).normalized(), 1.1, 0.26, 4, "dragon_claw", {hb[2]: 1.0}, curl=V((0, -0.1, -0.25)))
    build(legs)

# ================================================================== join
bpy.ops.object.select_all(action="DESELECT")
for ob in parts:
    ob.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body_ob = bpy.context.view_layer.objects.active
body_ob.name = body_ob.data.name = f"SkyDragon_{STYLE}"
by_name = {}
for i, slot in enumerate(body_ob.material_slots):
    if slot.material is None: continue
    by_name.setdefault(slot.material.name.split(".")[0], []).append(i)
keep = {k: v[0] for k, v in by_name.items()}
remap = {i: keep[k] for k, v in by_name.items() for i in v}
for poly in body_ob.data.polygons:
    poly.material_index = remap[poly.material_index]
bpy.ops.object.material_slot_remove_unused()
body_ob.parent = rig
body_ob.modifiers.new("Rig", "ARMATURE").object = rig
vs = body_ob.data.vertices
lo = V((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
hi = V((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
print("DRAGON_TRIS", STYLE, sum(len(p.vertices) - 2 for p in body_ob.data.polygons),
      "bounds", tuple(round(c, 2) for c in lo), tuple(round(c, 2) for c in hi))

if SAVE_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / f"rim_dragon_{STYLE}.blend"))
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
body_ob.select_set(True)
bpy.context.view_layer.objects.active = rig
GLB.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
    export_apply=False, export_animations=False, export_materials="EXPORT",
    export_normals=True, export_extras=False, export_def_bones=False)
print("DRAGON_EXPORTED", GLB)
