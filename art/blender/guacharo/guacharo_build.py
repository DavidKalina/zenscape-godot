"""Build the guacharo (scripts/enemies/guacharo.gd, guacharo_look.gd,
docs/design/guacharo/spec-guacharo.md): the giant oilbird.

A real oilbird's silhouette: a short, strongly hooked beak with a wide gape
and rictal bristles, big dark eyes, a slim rufous body spotted white, long
broad wings with five slotted primaries at the tip (fingers) and a long
graduated fan tail. The feet are small, but its talons are a hunter's.

Sized from the procedural body it replaces (guacharo_look.gd): HALF_SPAN
2.15 design units from the middle to a wing tip, about 1.9 from the beak to
the tail's tip; the game scales it with `size_to(span)`.

The plumage is a painted atlas (made here, 512 px, embedded in the glb):
body (rufous, darker over the back, white teardrop spots ringed dark),
coverts (rows of spots) and a feather strip (a dark shaft, buff bars, a
white spot on the outer vane, a dusky tip). The feathers are cards with a
pointed tip in the geometry (no alpha), double-sided.

Rig (Blender +Y forward, +Z up; glTF turns it into Godot -Z forward). The
origin is the body's middle between the wing roots.
  root
  chest  neck  head  jaw
  chest  pelvis  tail  tail.0 .. tail.9           (one bone a tail feather)
  chest  upperarm forearm hand  prim.0 .. prim.9   (.L/.R, one bone a primary)
  pelvis thigh shin foot toes                      (.L/.R)
Rest = gliding: wings spread, tail half fanned, legs tucked.

    /opt/homebrew/bin/blender -b --python art/blender/guacharo/guacharo_build.py -- [--out=DIR] [--blend] [--render=DIR]

Writes assets/models/guacharo.glb (or into DIR), printing GUACHARO_TRIS;
--render=DIR also writes Workbench stills of the rest pose there.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector, Matrix

V = Vector
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ROOT / "assets/models"
SAVE_BLEND = False
RENDER = None
for a in _args:
    if a.startswith("--out="): OUT = Path(a.split("=", 1)[1])
    elif a == "--blend": SAVE_BLEND = True
    elif a.startswith("--render="): RENDER = Path(a.split("=", 1)[1])
GLB = OUT / "guacharo.glb"
rng = random.Random(7)

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def hexrgb(h):
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ------------------------------------------------------------------ the atlas
# Regions in u: body 0..0.5, coverts 0.5..0.75, feather 0.75..1 (v the whole
# height each). Painted in sRGB.
TEX = 512
RUFOUS = hexrgb("6a2e12")
RUFOUS_DARK = hexrgb("3a1a0c")
RUFOUS_LIGHT = hexrgb("84461e")
BUFF = hexrgb("b9814a")
SPOT = hexrgb("e6dac0")
RIM = hexrgb("24140b")
DUSK = hexrgb("2c1a10")

def paint_atlas():
    import numpy as np
    px = np.zeros((TEX, TEX, 3), dtype=np.float32)   # [v][u]
    vv, uu = np.mgrid[0:TEX, 0:TEX].astype(np.float32)
    vv = (vv + 0.5) / TEX
    uu = (uu + 0.5) / TEX
    noise = np.random.default_rng(3).random((TEX, TEX)).astype(np.float32)

    def lerp(a, b, t):
        return a[None, None, :] * (1 - t[..., None]) + b[None, None, :] * t[..., None]

    # The body: u 0..0.5 is round the ring (0 and 0.5 the belly's middle,
    # 0.25 the back), v along the body (0 the tail root, 1 the beak).
    bu = uu / 0.5
    back = np.clip(1.0 - np.abs(bu - 0.5) * 2.0, 0, 1) ** 1.3        # 1 over the back
    base = lerp(np.array(RUFOUS_LIGHT), np.array(RUFOUS_DARK), back)
    # the face and crown a touch darker, a faint barring
    base *= (0.96 + 0.04 * np.sin(vv * 140.0 + bu * 9.0))[..., None]
    base *= (0.94 + 0.12 * noise)[..., None]
    # The coverts: u 0.5..0.75 (0 the leading edge, 1 the trailing), v along
    # the span. Scaled rows.
    cu = (uu - 0.5) / 0.25
    cov = lerp(np.array(RUFOUS), np.array(RUFOUS_DARK), np.clip(0.6 - cu * 0.4, 0, 1))
    scale = 0.5 + 0.5 * np.abs(np.sin(cu * math.pi * 3.0))
    cov *= (0.86 + 0.14 * scale)[..., None] * (0.94 + 0.1 * noise)[..., None]
    # The feather strip: u 0.75..1 across the vane (0.5 the shaft), v from
    # the base (0) to the tip (1).
    fu = (uu - 0.75) / 0.25
    fea = np.tile(np.array(RUFOUS, dtype=np.float32), (TEX, TEX, 1))
    bars = 0.5 + 0.5 * np.sin(vv * math.pi * 7.0 + np.sin(fu * 3.0) * 0.8)
    fea = lerp(np.array(RUFOUS), np.array(BUFF), np.clip((bars - 0.6) * 1.2, 0, 1) * 0.4 * (vv < 0.75))
    fea *= (0.9 + 0.1 * noise)[..., None]
    tip = np.clip((vv - 0.72) / 0.2, 0, 1)
    fea = fea * (1 - tip[..., None]) + np.array(DUSK)[None, None, :] * tip[..., None]
    shaft = np.abs(fu - 0.5) < 0.035
    fea[shaft] = fea[shaft] * 0.45 + np.array(BUFF) * 0.25
    edge = np.clip((np.abs(fu - 0.5) - 0.42) / 0.08, 0, 1)
    fea *= (1.0 - 0.25 * edge)[..., None]
    # the wings darker than the body's flanks: a sooty rufous
    px[:] = base
    px[uu >= 0.5] = cov[uu >= 0.5] * 0.82
    px[uu >= 0.75] = fea[uu >= 0.75] * 0.72

    # Spots: teardrops, white ringed dark. Body: scattered, thicker on the
    # head and the back; coverts: in rows; feathers: one on the outer vane.
    def spot(cx, cy, rx, ry, sharp=True):
        x0, x1 = int((cx - rx * 1.6) * TEX), int((cx + rx * 1.6) * TEX) + 1
        y0, y1 = int((cy - ry * 1.6) * TEX), int((cy + ry * 1.6) * TEX) + 1
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, TEX), min(y1, TEX)
        if x1 <= x0 or y1 <= y0: return
        sx = (uu[y0:y1, x0:x1] - cx) / rx
        sy = (vv[y0:y1, x0:x1] - cy) / ry
        # a teardrop pointing down the body (towards the tail, -v)
        d = sx * sx * (1.0 + 0.6 * np.clip(-sy, 0, 2)) + sy * sy
        blk = px[y0:y1, x0:x1]
        ring = (d < 1.55) & (d >= 1.0)
        inner = d < 1.0
        blk[ring] = blk[ring] * 0.35 + np.array(RIM) * 0.65
        blk[inner] = np.array(SPOT) * (0.9 + 0.1 * noise[y0:y1, x0:x1][inner][:, None])

    srng = random.Random(5)
    for _ in range(170):
        cu_ = srng.uniform(0.04, 0.46)
        cv_ = srng.uniform(0.06, 0.97)
        bk = 1.0 - abs(cu_ / 0.5 - 0.5) * 2.0
        if srng.random() > 0.35 + 0.6 * bk and cv_ < 0.8: continue
        r = srng.uniform(0.006, 0.011) * (0.7 if cv_ > 0.82 else 1.0)
        spot(cu_, cv_, r, r * 1.5)
    for row in range(4):
        for k in range(26):
            spot(0.52 + row * 0.055 + srng.uniform(-0.005, 0.005), 0.03 + k * 0.038 + srng.uniform(-0.006, 0.006), 0.008, 0.011)
    for k in range(3):
        spot(0.75 + 0.25 * 0.78, 0.38 + k * 0.13, 0.25 * 0.07, 0.022)

    img = bpy.data.images.new("guacharo_plumage", TEX, TEX, alpha=False)
    rgba = np.ones((TEX, TEX, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(px, 0, 1)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img

ATLAS = paint_atlas()

def make_mat(name, rgb_hex=None, rough=0.6, image=None, spec=0.5):
    m = bpy.data.materials.new(name)
    m.use_backface_culling = False
    rgb = [srgb_to_linear(c) for c in hexrgb(rgb_hex)] if rgb_hex else [0.8, 0.8, 0.8]
    m.diffuse_color = (*rgb, 1.0)
    m.roughness = rough
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rough
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    if image is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    return m

materials = {
    "guacharo_plumage": make_mat("guacharo_plumage", rough=0.9, image=ATLAS, spec=0.12),
    "guacharo_horn": make_mat("guacharo_horn", "3a2c20", 0.4),
    "guacharo_mouth": make_mat("guacharo_mouth", "4a1c1c", 0.55),
    "guacharo_eye": make_mat("guacharo_eye", "070504", 0.05, spec=1.0),
    "guacharo_foot": make_mat("guacharo_foot", "5a4636", 0.7),
}

# ------------------------------------------------------------------ joints
# Design units (guacharo_look.gd's): x the right wing, y forward, z up.
SH = V((0.11, 0.15, 0.07))     # the shoulder
EL = V((0.46, 0.06, 0.07))     # the elbow
WR = V((0.92, 0.15, 0.065))    # the wrist (the leading edge's bend)
KN = V((1.22, 0.09, 0.06))     # the hand's end (the primaries' root)
HIP = V((0.065, -0.10, -0.07))
KNEE = V((0.075, -0.05, -0.13))
ANKLE = V((0.07, -0.21, -0.13))
TOE = V((0.07, -0.27, -0.125))
NECK0 = V((0, 0.30, 0.03))
HEAD0 = V((0, 0.44, 0.06))
HEAD1 = V((0, 0.66, 0.07))
HINGE = V((0, 0.58, 0.015))
JAW1 = V((0, 0.79, -0.035))
TAIL0 = V((0, -0.34, 0.03))
NPRIM, NTAIL = 10, 10

BONES = {}   # name -> (head, tail, parent, deform)

def bone(name, head, tail, parent=None, deform=True):
    BONES[name] = (V(head), V(tail), parent, deform)

def mx(p, s):
    return V((p.x * s, p.y, p.z))

bone("root", (0, -0.1, 0), (0, 0.1, 0), None, False)
bone("chest", (0, -0.04, 0.0), (0, 0.30, 0.03), "root")
bone("pelvis", (0, -0.04, 0.0), (0, -0.33, 0.03), "chest")
bone("tail", TAIL0, TAIL0 + V((0, -0.12, 0)), "pelvis")
bone("neck", NECK0, HEAD0, "chest")
bone("head", HEAD0, HEAD1, "neck")
bone("jaw", HINGE, JAW1, "head")

def prim_dir(i):
    t = i / (NPRIM - 1)
    th = math.radians(26 + 56 * t ** 0.85)     # from the back (inner) to the span (outer)
    return V((math.sin(th), -math.cos(th), -0.02)).normalized()

def prim_base(i):
    t = i / (NPRIM - 1)
    return WR.lerp(KN, 0.1 + 0.9 * t) + V((0, -0.015, -0.004 * i))

def prim_len(i):
    t = i / (NPRIM - 1)
    return 0.6 + 0.42 * t ** 0.8 - (0.08 if i == NPRIM - 1 else 0.0)

def tail_dir(i, fan=1.0):
    t = i / (NTAIL - 1) - 0.5
    a = t * 0.95 * fan
    return V((math.sin(a), -math.cos(a), 0.0))

def tail_len(i):
    t = abs(i / (NTAIL - 1) - 0.5) * 2.0
    return 0.78 - 0.22 * t * t

for n, s in (("L", -1.0), ("R", 1.0)):
    bone(f"upperarm.{n}", mx(SH, s), mx(EL, s), "chest")
    bone(f"forearm.{n}", mx(EL, s), mx(WR, s), f"upperarm.{n}")
    bone(f"hand.{n}", mx(WR, s), mx(KN, s), f"forearm.{n}")
    for i in range(NPRIM):
        b = prim_base(i)
        bone(f"prim.{i}.{n}", mx(b, s), mx(b + prim_dir(i) * prim_len(i) * 0.5, s), f"hand.{n}")
    bone(f"thigh.{n}", mx(HIP, s), mx(KNEE, s), "pelvis")
    bone(f"shin.{n}", mx(KNEE, s), mx(ANKLE, s), f"thigh.{n}")
    bone(f"foot.{n}", mx(ANKLE, s), mx(TOE, s), f"shin.{n}")
    bone(f"toes.{n}", mx(TOE, s), mx(TOE + V((0, -0.06, -0.01)), s), f"foot.{n}")
for i in range(NTAIL):
    b = TAIL0 + V(((i / (NTAIL - 1) - 0.5) * 0.07, -0.02, 0.0))
    bone(f"tail.{i}", b, b + tail_dir(i) * tail_len(i) * 0.5, "tail")

def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length

def weights_at(p, bones, soft=0.05, power=4.0, keep=3):
    ws = sorted(((1.0 / (seg_dist(p, BONES[b][0], BONES[b][1]) + soft) ** power, b) for b in bones), reverse=True)[:keep]
    tot = sum(w for w, _ in ws)
    return {b: w / tot for w, b in ws if w / tot > 0.02}

# ------------------------------------------------------------------ parts
parts = []

class Part:
    def __init__(self, name, smooth=True):
        self.name, self.smooth = name, smooth
        self.verts, self.faces, self.mats, self.weights, self.uvs = [], [], [], [], []

    def v(self, p, w):
        self.verts.append(V(p))
        self.weights.append(w if isinstance(w, dict) else {w: 1.0})
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
    layer = me.uv_layers.new(name="UVMap")
    for i, poly in enumerate(me.polygons):
        uv = part.uvs[i]
        for k, li in enumerate(poly.loop_indices):
            layer.data[li].uv = uv[k] if uv else (0.1, 0.5)
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
    print(f"GUACHARO_PART {part.name} tris={sum(len(p.vertices) - 2 for p in me.polygons)}")
    return ob

def loft(part, rings, ring_uv, mat, weight_of, cap_start=None, cap_end=None):
    """Quads between rings (lists of points, the same count); ring_uv(i, k)
    the uv of ring i's point k (k may be n, the seam's copy). Ends drawn to
    a point (cap_* a point) or left open."""
    n = len(rings[0])
    idx = [[part.v(p, weight_of(i, p)) for p in ring] for i, ring in enumerate(rings)]
    for i in range(len(rings) - 1):
        for k in range(n):
            k1 = (k + 1) % n
            part.f((idx[i][k], idx[i][k1], idx[i + 1][k1], idx[i + 1][k]), mat,
                   (ring_uv(i, k), ring_uv(i, k + 1), ring_uv(i + 1, k + 1), ring_uv(i + 1, k)))
    for cap, i, flip in ((cap_start, 0, True), (cap_end, len(rings) - 1, False)):
        if cap is None: continue
        ci = part.v(cap, weight_of(i, cap))
        for k in range(n):
            k1 = (k + 1) % n
            tri = (idx[i][k], idx[i][k1], ci) if not flip else (idx[i][k1], idx[i][k], ci)
            part.f(tri, mat, (ring_uv(i, k), ring_uv(i, k + 1), ring_uv(i, k + 0.5)) if not flip else
                   (ring_uv(i, k + 1), ring_uv(i, k), ring_uv(i, k + 0.5)))
    return idx

def ring(c, w, top, bot, sides, squash=2.4, rot=0.0):
    """A rounded section round centre c (in the x-z plane), half width w,
    height top over c and depth bot under it; point 0 under the belly, going
    round by the right side to the back."""
    pts = []
    for k in range(sides):
        a = 2 * math.pi * k / sides + rot
        sx, cz = math.sin(a), -math.cos(a)
        e = 2.0 / squash
        x = math.copysign(abs(sx) ** e, sx) * w
        z = math.copysign(abs(cz) ** e, cz) * (top if cz > 0 else bot)
        pts.append(c + V((x, 0, z)))
    return pts

# ================================================================== body
# Stations from the face to the tail root: y, half width, top, depth, z of
# the centre. The head is round and big-eyed, the neck short and thick, the
# chest deep where the wings anchor, the waist slim into the tail root.
STATIONS = [
    (0.715, 0.050, 0.040, 0.035, 0.040),
    (0.690, 0.085, 0.070, 0.060, 0.050),
    (0.650, 0.112, 0.098, 0.085, 0.058),
    (0.600, 0.128, 0.115, 0.100, 0.062),
    (0.545, 0.130, 0.118, 0.108, 0.060),
    (0.490, 0.122, 0.108, 0.112, 0.052),
    (0.430, 0.120, 0.100, 0.122, 0.040),
    (0.350, 0.145, 0.112, 0.148, 0.028),
    (0.250, 0.175, 0.135, 0.170, 0.014),
    (0.130, 0.190, 0.150, 0.175, 0.006),
    (0.000, 0.180, 0.145, 0.158, 0.006),
    (-0.120, 0.150, 0.125, 0.125, 0.012),
    (-0.230, 0.112, 0.098, 0.088, 0.020),
    (-0.320, 0.078, 0.064, 0.050, 0.028),
    (-0.390, 0.052, 0.036, 0.026, 0.032),
]
SIDES = 16
Y0, Y1 = STATIONS[-1][0], STATIONS[0][0]

def body_w(i, p):
    if p.y > 0.47:
        w = weights_at(p, ["head", "neck"], soft=0.04)
        # the chin's front rides the jaw a little (the gape opens)
        if p.y > 0.6 and p.z < 0.02:
            j = min(1.0, (p.y - 0.6) / 0.1) * min(1.0, (0.02 - p.z) / 0.04) * 0.85
            w = {k: x * (1 - j) for k, x in w.items()}
            w["jaw"] = w.get("jaw", 0.0) + j
        return w
    return weights_at(p, ["chest", "pelvis", "neck", "tail"], soft=0.12, power=3.0)

body = Part("body")
rings = [ring(V((0, y, cz)), w, t, b, SIDES) for y, w, t, b, cz in STATIONS]
def body_uv(i, k):
    y = STATIONS[min(int(i), len(STATIONS) - 1)][0]
    return (0.5 * k / SIDES, (y - Y0) / (Y1 - Y0) * 0.96 + 0.02)
loft(body, rings, body_uv, "guacharo_plumage", body_w,
     cap_start=V((0, 0.725, 0.04)), cap_end=V((0, -0.40, 0.032)))
build(body)

# ================================================================== beak
# The upper mandible: broad at the gape, arched and hooked hard down at the
# tip. The lower: flatter, inside it, hinged at the gape (the jaw bone).
beak = Part("beak", smooth=True)
def mandible(path, widths, heights, bone_w, mat, sides=8, flat_bottom=0.4):
    rings_ = []
    for p, w, h in zip(path, widths, heights):
        rings_.append(ring(p, w, h, h * flat_bottom, sides, squash=2.2))
    return loft(beak, rings_, lambda i, k: (0.3, 0.5), mat, lambda i, p: bone_w,
                cap_start=None, cap_end=path[-1] + (path[-1] - path[-2]).normalized() * 0.012)
upper = [V((0, 0.66, 0.045)), V((0, 0.72, 0.048)), V((0, 0.775, 0.036)), V((0, 0.81, 0.010)),
         V((0, 0.822, -0.022)), V((0, 0.815, -0.050))]
mandible(upper, [0.072, 0.052, 0.034, 0.020, 0.012, 0.006], [0.042, 0.034, 0.026, 0.018, 0.012, 0.006],
         {"head": 1.0}, "guacharo_horn")
lower = [V((0, 0.62, 0.008)), V((0, 0.69, 0.002)), V((0, 0.75, -0.008)), V((0, 0.785, -0.016))]
mandible(lower, [0.070, 0.050, 0.030, 0.014], [0.018, 0.016, 0.012, 0.007], {"jaw": 1.0}, "guacharo_horn", flat_bottom=1.0)
# The gape: a dark web each side from the hinge to the mandibles' bases (it
# stretches as the jaw drops), and the palate between.
for s in (-1.0, 1.0):
    a = beak.v(V((s * 0.085, 0.585, 0.03)), {"head": 1.0})
    b = beak.v(V((s * 0.062, 0.70, 0.03)), {"head": 1.0})
    c = beak.v(V((s * 0.058, 0.68, 0.006)), {"jaw": 1.0})
    d = beak.v(V((s * 0.080, 0.60, 0.012)), {"jaw": 0.7, "head": 0.3})
    beak.f((a, b, c, d), "guacharo_mouth")
roof = [beak.v(V((s * 0.058, y, 0.032)), {"head": 1.0}) for s, y in ((-1, 0.6), (1, 0.6), (0.6, 0.76), (-0.6, 0.76))]
beak.f(roof, "guacharo_mouth")
floor_ = [beak.v(V((s * 0.055, y, 0.01)), {"jaw": 1.0}) for s, y in ((-1, 0.61), (1, 0.61), (0.4, 0.75), (-0.4, 0.75))]
beak.f(floor_, "guacharo_mouth")
build(beak, recalc=False)

# Rictal bristles: long stiff hairs fanned forward round the gape.
bristles = Part("bristles", smooth=False)
for s in (-1.0, 1.0):
    for k in range(4):
        root_ = V((s * (0.068 - k * 0.004), 0.665 + k * 0.012, 0.04 - k * 0.008))
        d = V((s * (0.35 - k * 0.06), 1.0, 0.05 - k * 0.12)).normalized()
        tip = root_ + d * (0.11 + 0.02 * (k % 2))
        side = d.cross(V((0, 0, 1))).normalized() * 0.004
        i0 = bristles.v(root_ - side, {"head": 1.0})
        i1 = bristles.v(root_ + side, {"head": 1.0})
        i2 = bristles.v(tip, {"head": 1.0})
        bristles.f((i0, i1, i2), "guacharo_horn")
build(bristles, recalc=False)

# ================================================================== eyes
eyes = Part("eyes")
for s in (-1.0, 1.0):
    c = V((s * 0.088, 0.612, 0.078))
    r = 0.056
    out = V((s * 0.8, 0.45, 0.25)).normalized()
    up = V((0, 0, 1))
    u = out.cross(up).normalized()
    w = out.cross(u).normalized()
    rings_ = []
    for j in range(1, 6):
        a = math.pi * j / 6
        rr = r * math.sin(a)
        rings_.append([c + out * (r * math.cos(a) * 0.75) + (u * math.cos(b) + w * math.sin(b)) * rr
                       for b in (2 * math.pi * k / 10 for k in range(10))])
    loft(eyes, rings_, lambda i, k: (0.3, 0.5), "guacharo_eye", lambda i, p: {"head": 1.0},
         cap_start=c + out * r * 0.75, cap_end=c - out * r * 0.75)
build(eyes)

# ================================================================== feathers
feathers = Part("feathers", smooth=True)
FEA_U0 = 0.75

def feather(base, along, side, length, width, camber, bone_w, segs=3, notch=0.0, twist=0.0, u0=FEA_U0, u1=1.0):
    """A feather card from base along `along` (unit), `width` across `side`
    (unit), cambered down by camber*length at the tip, its tip drawn to a
    point (or narrowed past `notch`, the emargination, for the fingers)."""
    along = along.normalized()
    side = (side - along * side.dot(along)).normalized()
    normal = side.cross(along).normalized()
    if normal.z < 0: normal = -normal
    rows = []
    for i in range(segs + 1):
        t = i / segs
        w = width
        if notch > 0 and t > notch: w = width * (1.0 - 0.55 * (t - notch) / (1 - notch))
        if i == segs: w *= 0.35
        mid = base + along * length * t - normal * camber * length * t * t
        sd = (side * math.cos(twist * t) + normal * math.sin(twist * t))
        rows.append([mid - sd * w * 0.5, mid + sd * w * 0.5, t])
    idx = []
    for a, b, t in rows:
        idx.append((feathers.v(a, bone_w), feathers.v(b, bone_w), t))
    tip = base + along * length * 1.06 - normal * camber * length
    ti = feathers.v(tip, bone_w)
    for i in range(segs):
        (a0, b0, t0), (a1, b1, t1) = idx[i], idx[i + 1]
        feathers.f((a0, b0, b1, a1), "guacharo_plumage",
                   ((u0, t0 * 0.94), (u1, t0 * 0.94), (u1, t1 * 0.94), (u0, t1 * 0.94)))
    a0, b0, t0 = idx[-1]
    feathers.f((a0, b0, ti), "guacharo_plumage", ((u0, 0.94), (u1, 0.94), ((u0 + u1) * 0.5, 1.0)))

for n, s in (("L", -1.0), ("R", 1.0)):
    arm = [f"upperarm.{n}", f"forearm.{n}", f"hand.{n}"]
    # Primaries: ten, fanned from the back of the hand to the tip, the outer
    # five emarginated into slotted fingers. Each rides its own bone.
    for i in range(NPRIM):
        t = i / (NPRIM - 1)
        d = prim_dir(i)
        sd = V((-d.y, d.x, 0.0))   # towards the leading edge... and back
        base = prim_base(i)
        feather(mx(base, s), mx(d, s), mx(sd, s), prim_len(i), 0.15 - 0.03 * t, 0.05,
                {f"prim.{i}.{n}": 1.0}, segs=4, notch=(0.45 if i >= 5 else 0.0), twist=0.08 * s * t)
    # Secondaries and tertials: along the arm's trailing edge, pointing back.
    for i in range(13):
        t = i / 12
        if t < 0.35: base = SH.lerp(EL, t / 0.35)
        else: base = EL.lerp(WR + V((0.0, -0.03, 0)), (t - 0.35) / 0.65)
        base = base + V((0, -0.035, -0.006 * (i % 2)))
        d = V((0.08 + 0.22 * t ** 2, -1.0, -0.03)).normalized()
        length = (0.58 if i > 2 else 0.64) + rng.uniform(-0.02, 0.02)
        fb = [arm[0], arm[1]] if t < 0.5 else [arm[1], arm[2]]
        w = weights_at(base, fb, soft=0.15, power=2.0)
        feather(mx(base, s), mx(d, s), V((1, 0, 0)), length, 0.13, 0.07, w, segs=3)
    # Greater coverts: a row of short cards over the remiges' roots.
    for i in range(14):
        t = i / 13
        base = SH.lerp(KN, t) + V((0.0, -0.01, 0.012))
        if t > 0.6: base = base + V((0, 0.02, 0))
        d = V((0.12 + 0.5 * t ** 3, -1.0, -0.04)).normalized()
        w = weights_at(base, arm, soft=0.12, power=2.0)
        feather(mx(base, s), mx(d, s), V((1, 0, 0)), 0.26 - 0.06 * t, 0.12, 0.1, w, segs=2)

# The tail: ten, graduated, each on its bone.
for i in range(NTAIL):
    b = BONES[f"tail.{i}"][0]
    d = tail_dir(i)
    feather(b + V((0, 0, 0.004 * (i % 2))), d, V((-d.y, d.x, 0)), tail_len(i), 0.13, 0.04, {f"tail.{i}": 1.0}, segs=3)
build(feathers, recalc=False)

# ================================================================== the wing's covert surface
# A thin airfoil from the body over the arm and hand: the leading edge from
# the shoulder to the wrist and on to the hand's end, the trailing edge over
# the remiges' roots. The marginal coverts' spots run in rows along it.
cov = Part("coverts", smooth=True)
def lead_at(u):
    pts = [SH + V((0, 0.03, 0)), WR + V((0, 0.035, 0)), KN + V((0.03, 0.01, 0))]
    if u < 0.75: return pts[0].lerp(pts[1], u / 0.75)
    return pts[1].lerp(pts[2], (u - 0.75) / 0.25)
def trail_at(u):
    pts = [SH + V((0.0, -0.17, 0)), EL + V((0, -0.14, 0)), WR + V((0, -0.16, 0)), KN + V((0.0, -0.05, 0))]
    if u < 0.35: return pts[0].lerp(pts[1], u / 0.35)
    if u < 0.75: return pts[1].lerp(pts[2], (u - 0.35) / 0.4)
    return pts[2].lerp(pts[3], (u - 0.75) / 0.25)
NU, NV = 9, 4
for n, s in (("L", -1.0), ("R", 1.0)):
    arm = [f"upperarm.{n}", f"forearm.{n}", f"hand.{n}"]
    grid = []
    for i in range(NU + 1):
        u = i / NU
        a, b = lead_at(u), trail_at(u)
        row = []
        for j in range(NV + 1):
            v = j / NV
            p = a.lerp(b, v)
            thick = 0.028 * (1 - u * 0.6) * math.sin(math.pi * (0.15 + 0.85 * v)) ** 0.5
            top = p + V((0, 0, thick * 0.7))
            bot = p - V((0, 0, thick * 0.3))
            w = weights_at(p, arm + ["chest"] if u < 0.08 else arm, soft=0.1, power=3.0)
            row.append((cov.v(mx(top, s), w), cov.v(mx(bot, s), w), (0.5 + 0.25 * v, u)))
        grid.append(row)
    for i in range(NU):
        for j in range(NV):
            (t00, b00, uv00), (t01, b01, uv01) = grid[i][j], grid[i][j + 1]
            (t10, b10, uv10), (t11, b11, uv11) = grid[i + 1][j], grid[i + 1][j + 1]
            cov.f((t00, t10, t11, t01), "guacharo_plumage", (uv00, uv10, uv11, uv01))
            cov.f((b00, b01, b11, b10), "guacharo_plumage", (uv00, uv01, uv11, uv10))
    for i in range(NU):   # the leading edge closed
        (t0, b0, uv0), (t1, b1, uv1) = grid[i][0], grid[i + 1][0]
        cov.f((t0, b0, b1, t1), "guacharo_plumage", (uv0, uv0, uv1, uv1))
build(cov)

# ================================================================== legs and talons
legs = Part("legs")
for n, s in (("L", -1.0), ("R", 1.0)):
    hb = f"thigh.{n}"
    for (p0, p1, r0, r1, bw) in ((HIP, KNEE, 0.03, 0.022, {f"thigh.{n}": 1.0}),
                                  (KNEE, ANKLE, 0.016, 0.013, {f"shin.{n}": 1.0}),
                                  (ANKLE, TOE, 0.014, 0.012, {f"foot.{n}": 1.0})):
        d = (p1 - p0).normalized()
        u = d.cross(V((1, 0, 0))).normalized()
        w = d.cross(u).normalized()
        rs = [[mx(p + (u * math.cos(a) + w * math.sin(a)) * r, s) for a in (2 * math.pi * k / 6 for k in range(6))]
              for p, r in ((p0, r0), (p1, r1))]
        loft(legs, rs, lambda i, k: (0.3, 0.5), "guacharo_foot", lambda i, p, bw=bw: bw)
    # three toes forward, one back, each with a hooked talon
    for k, (dx, dy) in enumerate(((-0.35, -1.0), (0.0, -1.0), (0.35, -1.0), (0.0, 1.0))):
        bw = {f"toes.{n}": 1.0} if k < 3 else {f"foot.{n}": 1.0}
        d = V((dx, dy, -0.15)).normalized()
        p0 = TOE + V((0, 0, 0))
        p1 = p0 + d * (0.05 if k < 3 else 0.035)
        uu = d.cross(V((0, 0, 1))).normalized()
        ww = d.cross(uu).normalized()
        rs = [[mx(p + (uu * math.cos(a) + ww * math.sin(a)) * r, s) for a in (2 * math.pi * j / 5 for j in range(5))]
              for p, r in ((p0, 0.009), (p1, 0.008))]
        loft(legs, rs, lambda i, k: (0.3, 0.5), "guacharo_foot", lambda i, p, bw=bw: bw)
        # the talon: a curved cone hooking down
        c0 = p1
        rr = [0.008, 0.006, 0.0035]
        pts = [c0, c0 + d * 0.022 + V((0, 0, -0.006)), c0 + d * 0.034 + V((0, 0, -0.024))]
        rs = []
        for p, r in zip(pts, rr):
            rs.append([mx(p + (uu * math.cos(a) + ww * math.sin(a)) * r, s) for a in (2 * math.pi * j / 5 for j in range(5))])
        tipp = mx(c0 + d * 0.036 + V((0, 0, -0.04)), s)
        loft(legs, rs, lambda i, k: (0.3, 0.5), "guacharo_horn", lambda i, p, bw=bw: bw, cap_end=tipp)
build(legs)

# ================================================================== the rig
arm_data = bpy.data.armatures.new("GuacharoRig")
rig = bpy.data.objects.new("GuacharoRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for name, (h, t, parent, deform) in BONES.items():
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = h, t
    b.use_deform = deform
    b.roll = 0.0
    eb[name] = b
for name, (h, t, parent, deform) in BONES.items():
    if parent:
        eb[name].parent = eb[parent]
        eb[name].use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")

# ================================================================== join
bpy.ops.object.select_all(action="DESELECT")
for ob in parts:
    ob.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body_ob = bpy.context.view_layer.objects.active
body_ob.name = body_ob.data.name = "Guacharo"
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
print("GUACHARO_TRIS", sum(len(p.vertices) - 2 for p in body_ob.data.polygons), "bones", len(BONES),
      "bounds", tuple(round(c, 3) for c in lo), tuple(round(c, 3) for c in hi))

if SAVE_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "guacharo.blend"))

# ================================================================== stills
if RENDER:
    RENDER.mkdir(parents=True, exist_ok=True)
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "TEXTURE"
    sh.show_shadows = False
    sh.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 1000, 700
    world = bpy.data.worlds.new("w")
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = {
        "top": (V((0, 0.1, 5.0)), V((0, 0.1, 0)), 35),
        "side": (V((4.5, 0.2, 0.1)), V((0, 0.15, 0)), 70),
        "front": (V((0.0, 5.0, 0.6)), V((0, 0, 0)), 40),
        "three": (V((2.6, 2.8, 1.6)), V((0.3, 0.1, 0)), 35),
        "below": (V((1.0, -1.5, -4.0)), V((0, 0.1, 0)), 35),
        "head": (V((0.9, 1.4, 0.35)), V((0, 0.62, 0.04)), 70),
    }
    for view, (eye, at, lens) in views.items():
        cam.location = eye
        d = (at - eye).normalized()
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = lens
        scene.render.filepath = str(RENDER / f"guacharo_{view}.png")
        bpy.ops.render.render(write_still=True)
    print("GUACHARO_STILLS", RENDER)

bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
body_ob.select_set(True)
bpy.context.view_layer.objects.active = rig
GLB.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
    export_apply=False, export_animations=False, export_materials="EXPORT",
    export_normals=True, export_extras=False, export_def_bones=False)
print("GUACHARO_EXPORTED", GLB)
