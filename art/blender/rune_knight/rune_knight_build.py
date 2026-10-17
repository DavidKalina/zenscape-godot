"""Build the rune knight (scripts/enemies/rune_knight.gd; docs/design/
rune-knight/spec-rune-knight-body.md, task 2): take A, "bastion", of
rune_knight_options.py, carved in the Olmec's stone.

    /opt/homebrew/bin/blender -b --python art/blender/rune_knight/rune_knight_build.py -- [--out=DIR] [--blend] [--render=DIR]

Writes assets/models/rune_knight.glb (rest pose, the rig and the clips of
rune_knight_clips.py), printing RK_PIECE / RK_TRIS / RK_CLIP / RK_WALK_SLIDE;
--render writes Workbench stills (a turntable, a close pair, a sheet a
clip `clip_<name>.png`) to DIR (default scratch/rk_model); --blend saves
rune_knight.blend here.

The forms are the Olmec's (art/blender/inhaler_head/inhaler_head_build.py,
headless_body_build.py): every piece is a rounded box (a grid mapped onto a
box with big soft arrises) swollen and tapered by its own shape, then
weathered: a low noise along the way out and a few corners broken off as
flat facets (real chips; the stone shader paints the rest). The bastion's
proportions, a little exaggerated as the Olmec's features are: the bucket
helm with its fin crest and T slit (cut in with a boolean, its floor the
dark `slit` material), boulder pauldrons over two lames, a keeled barrel
chest, flared vambraces into block gauntlets, a belt, a slab skirt and a
long front and back tabard, column legs with knee cops and wedge sabatons.

Sizes: WorldScale.WANDERER_TALL 1.19 m x `tall_ratio` 1.6 = H 1.904 m to
the helm's crown (the crest stands over it); the stand-in's thigh, shin and
ankle lengths and its hip and shoulder heights (fractions of H), so the
mind's stride, reach and room hold.

Frame (Blender): +z up, +y his front (glTF -> Godot -z), +x his right.

Pieces: every piece is its own object, named `<bone>-<piece>` (a dash:
Godot node names take no dots), its origin at its bone's joint in rest, no
rotation; each is skinned rigidly (one vertex group, weight 1) to its
bone of `RuneKnightRig` (task 3), sockets bone-parented. Stone does not bend: each piece rides one bone, and the
body throws pieces loose for `crumble` and `shatter`.
  bones: hips spine chest head shoulder_l/r upper_arm_l/r forearm_l/r
         hand_l/r thigh_l/r shin_l/r foot_l/r tabard_f tabard_b skirt_l/r
Materials: `stone`, `slit` (the visor's dark), `eye` (the back wall of
the visor's bar, where the eye glows), `rune` (the three rune
tablets: chest-rune, hand_l-rune, hand_r-rune). A tablet's front carries
its glyph square in UV (u along its row of RUNE_GLYPHS glyphs, v across,
both 0..1; -1 off the front); the game turns that into the rune data the
stone shader reads (scripts/enemies/rune_knight_look.gd).
Occlusion: baked into COLOR_0 (Cycles AO, the pieces occluding each
other), as the Olmec's.
Sockets (empties `socket-<name>`): hand_r, hand_l, hands_mid, blade,
chest_rune, eye.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector, Matrix, Euler, noise

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
    elif a.startswith("--render"): RENDER = Path(a.split("=", 1)[1]) if "=" in a else ROOT / "scratch/rk_model"
GLB = OUT / "rune_knight.glb"

WANDERER_TALL = 1.19
H = WANDERER_TALL * 1.6
h = H
## The grid's interior spacing (m) and the samples round an arris.
SPACING = 0.1
ROUND_STEPS = 3
## The weathering: the noise's depth and size (m).
WEAR = 0.011
WEAR_SIZE = 0.16
## Glyphs on each rune tablet.
RUNE_GLYPHS = {"chest": 3, "hand_l": 2, "hand_r": 2}

# The stand-in's proportions (rune_knight_options.py).
THIGH, SHIN, ANKLE = 0.22 * h, 0.21 * h, 0.045 * h
HIP_X = 0.085 * h
HIP_Y = ANKLE + (THIGH + SHIN) * 0.97
SH_Y = HIP_Y + 0.03 * h + 0.27 * h
SH_X = 0.23 * h + 0.03 * h
NECK_Y = HIP_Y + 0.03 * h + 0.33 * h

# ------------------------------------------------------------------ scene
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def srgb(hx):
    hx = hx.lstrip("#")
    c = [int(hx[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


MATS = {}
for key, hx, rough in (("stone", "5a5d63", 0.95), ("slit", "0c0b0b", 1.0), ("rune", "5a5d63", 0.95), ("eye", "0c0b0b", 1.0)):
    m = bpy.data.materials.new(key)
    m.diffuse_color = (*srgb(hx), 1.0)
    m.roughness = rough
    MATS[key] = m

# ------------------------------------------------------------------ joints
JOINT = {
    "hips": V((0, 0, HIP_Y)),
    "spine": V((0, 0, HIP_Y + 0.03 * h)),
    "chest": V((0, 0, HIP_Y + 0.17 * h)),
    "head": V((0, 0, NECK_Y)),
    "tabard_f": V((0, 0.1 * h, HIP_Y - 0.01 * h)),
    "tabard_b": V((0, -0.1 * h, HIP_Y - 0.01 * h)),
}
ARM = {}
for s, sd in ((-1.0, "l"), (1.0, "r")):
    hip = V((s * HIP_X, 0, HIP_Y))
    knee = V((s * HIP_X * 1.05, 0.02 * h, ANKLE + SHIN))
    ankle = V((s * HIP_X * 1.08, 0.0, ANKLE))
    JOINT[f"thigh_{sd}"] = hip
    JOINT[f"shin_{sd}"] = knee
    JOINT[f"foot_{sd}"] = ankle
    JOINT[f"skirt_{sd}"] = V((s * 0.13 * h, 0, HIP_Y - 0.01 * h))
    spread, bend = 0.16, 0.3
    sh = V((s * SH_X, 0, SH_Y))
    el = sh + V((s * math.sin(spread), 0.0, -math.cos(spread))) * 0.16 * h
    fdir = V((s * math.sin(spread * 0.7), math.sin(bend), -math.cos(bend))).normalized()
    wr = el + fdir * 0.15 * h
    JOINT[f"shoulder_{sd}"] = sh + V((-s * 0.03 * h, 0, 0))
    JOINT[f"upper_arm_{sd}"] = sh
    JOINT[f"forearm_{sd}"] = el
    JOINT[f"hand_{sd}"] = wr
    ARM[sd] = (s, sh, el, wr, fdir)


# ------------------------------------------------------------------ rounded boxes
def _axis(half, r, spacing, steps):
    r = min(r, half * 0.98)
    inner = half - r
    out = []
    for i in range(steps):
        t = i / steps
        out.append(-half + r * (1.0 - math.cos(t * math.pi * 0.5)))
    n = max(1, int(math.ceil(2.0 * inner / spacing)))
    for i in range(n + 1):
        out.append(-inner + 2.0 * inner * i / n)
    for i in range(steps - 1, -1, -1):
        t = i / steps
        out.append(half - r * (1.0 - math.cos(t * math.pi * 0.5)))
    return sorted(set(round(c, 6) for c in out))


PIECES = []   # (name, bone, bmesh, material, rune key or None)


def rbox(bone, name, center, half, r, mat="stone", shape=None, wear=1.0, chunks=0, seed=0,
         rot=None, spacing=SPACING, steps=ROUND_STEPS, rune=None):
    """A rounded box: centre `center`, half extents `half`, arris radius `r`
    (a number, or one per axis), its points moved by `shape(local, u)`
    (local off the centre, u that over the half extents, -1..1), turned by
    `rot` (a 3x3 Matrix) about its centre, `chunks` corners broken off as
    flat facets and weathered by `wear` of WEAR."""
    hx, hy, hz = half
    rr = list(r) if isinstance(r, (tuple, list)) else [r, r, r]
    rr = [min(rr[i], half[i] * 0.98) for i in range(3)]
    ax = [_axis(half[i], rr[i], spacing, steps) for i in range(3)]
    verts, faces, index = [], [], {}

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
    out = []
    for p in verts:
        inner = V((max(-hx + rr[0], min(hx - rr[0], p.x)),
                   max(-hy + rr[1], min(hy - rr[1], p.y)),
                   max(-hz + rr[2], min(hz - rr[2], p.z))))
        d = p - inner
        if d.length > 1e-9:
            d = V((d.x / rr[0] if rr[0] > 0 else 0, d.y / rr[1] if rr[1] > 0 else 0, d.z / rr[2] if rr[2] > 0 else 0))
            d.normalize()
            out.append(inner + V((d.x * rr[0], d.y * rr[1], d.z * rr[2])))
        else:
            out.append(V(p))
    if shape is not None:
        out = [shape(q, V((q.x / hx, q.y / hy, q.z / hz))) for q in out]
    # Chunks: a corner's points past a plane laid onto it, a flat break.
    crng = random.Random(seed * 7919 + 13)
    cuts = []
    for k in range(chunks):
        corner = V((crng.choice((-1, 1)) * hx, crng.choice((-1, 1)) * hy, crng.choice((-1, 1)) * hz))
        nrm = V((corner.x / hx + crng.uniform(-0.5, 0.5), corner.y / hy + crng.uniform(-0.5, 0.5),
                 corner.z / hz + crng.uniform(-0.5, 0.5))).normalized()
        size = min(half)
        depth = crng.uniform(0.25, 0.5) * size
        cuts.append((corner, nrm, depth))
    for i, q in enumerate(out):
        for corner, nrm, depth in cuts:
            plane = corner.dot(nrm) - depth - min(rr) * 0.5
            over = q.dot(nrm) - plane
            if over > 0: q = q - nrm * over
        out[i] = q
    M = rot if rot is not None else Matrix.Identity(3)
    c = V(center)
    bm = bmesh.new()
    bvs = []
    for q in out:
        w = c + M @ q
        n = noise.noise(w / WEAR_SIZE) * 0.7 + noise.noise(w / (WEAR_SIZE * 0.3)) * 0.3
        away = V((q.x / hx, q.y / hy, q.z / hz))
        if away.length > 1e-6: away.normalize()
        bvs.append(bm.verts.new(w + (M @ away) * n * WEAR * wear))
    bm.verts.ensure_lookup_table()
    for f in faces:
        try:
            bm.faces.new([bvs[i] for i in f])
        except ValueError:
            pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # A rune tablet's glyph square: on its front (+y local), u along its row
    # of glyphs (left to right as seen from in front: his right to his
    # left, -x local), v across, foot to top (world up, whichever way the
    # tablet's local z points), so the glyphs stand upright.
    uvl = bm.loops.layers.uv.new("UVMap")
    Minv = M.inverted()
    up = 1.0 if (Minv @ V((0, 0, 1))).z >= 0.0 else -1.0
    for f in bm.faces:
        ln = Minv @ f.normal
        for lp in f.loops:
            if rune and ln.y > 0.6:
                q = Minv @ (lp.vert.co - c)
                lp[uvl].uv = ((hx - q.x) / (2 * hx), (up * q.z + hz) / (2 * hz))
            else:
                lp[uvl].uv = (-1.0, -1.0)
    PIECES.append([f"{bone}-{name}", bone, bm, mat, rune])
    return bm


def seg_rot(a, b):
    """The turn taking local +z along a->b (local +y kept toward his front)."""
    d = (V(b) - V(a)).normalized()
    return d.to_track_quat("Z", "Y").to_matrix()


def limb(bone, name, a, b, w0, d0, w1, d1, r, bulge=0.0, back=0.0, **kw):
    """A rounded column from a to b, w x d at a tapering to w1 x d1 at b,
    swollen `bulge` (share) at its middle and `back` toward his back."""
    a, b = V(a), V(b)
    L = (b - a).length
    hw, hd = max(w0, w1) / 2, max(d0, d1) / 2
    def shape(q, u):
        t = (u.z + 1) * 0.5   # 0 at a (local -z), 1 at b
        sx = (w0 + (w1 - w0) * t) / (2 * hw)
        sy = (d0 + (d1 - d0) * t) / (2 * hd)
        sw = 1.0 + bulge * math.sin(t * math.pi)
        y = q.y * sy * sw
        if back and q.y < 0: y *= 1.0 + back * math.sin(t * math.pi)
        return V((q.x * sx * sw, y, q.z))
    return rbox(bone, name, (a + b) * 0.5, (hw, hd, L / 2), r, shape=shape, rot=seg_rot(a, b), **kw)


def smooth01(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def turn(rx=0.0, ry=0.0, rz=0.0):
    return Euler((rx, ry, rz), "XYZ").to_matrix()


# ================================================================ the knight
# --- legs: columns with a knee cop, wedge sabatons
for s, sd in ((-1.0, "l"), (1.0, "r")):
    hip, knee, ankle = JOINT[f"thigh_{sd}"], JOINT[f"shin_{sd}"], JOINT[f"foot_{sd}"]
    k = 0 if sd == "l" else 50
    limb(f"thigh_{sd}", "thigh", hip, knee, 0.135 * h, 0.145 * h, 0.12 * h, 0.13 * h, 0.06, bulge=0.06, seed=k + 1)
    limb(f"shin_{sd}", "greave", knee + V((0, 0, -0.01 * h)), ankle + V((0, 0, 0.015 * h)),
         0.13 * h, 0.14 * h, 0.105 * h, 0.115 * h, 0.06, bulge=0.05, back=0.25, chunks=1, seed=k + 2)
    rbox(f"shin_{sd}", "kneecop", knee + V((s * 0.004, 0.06 * h, 0.01 * h)), (0.072 * h, 0.05 * h, 0.07 * h),
         (0.11, 0.08, 0.11), seed=k + 3, chunks=1,
         shape=lambda q, u: V((q.x, q.y + 0.025 * (1 - u.z * u.z) * (1 - u.x * u.x), q.z)))
    # The sabaton: a wedge, its toe low and forward, its heel square.
    def sab(q, u):
        t = (u.y + 1) * 0.5      # 0 heel, 1 toe
        top = q.z * (1.0 - 0.45 * t) if q.z > 0 else q.z
        return V((q.x * (1.0 - 0.12 * t), q.y, top - 0.012 * t))
    rbox(f"foot_{sd}", "sabaton", ankle + V((0, 0.045 * h, -ANKLE * 0.4)), (0.078 * h, 0.12 * h, ANKLE * 0.66),
         (0.05, 0.07, 0.04), shape=sab, chunks=2, seed=k + 4)

# --- the belt, the skirt's side slabs and the long tabard
def belt_shape(q, u):
    return V((q.x, q.y * (1.0 + 0.08 * (1 - u.x * u.x)), q.z))
rbox("hips", "belt", (0, 0, HIP_Y + 0.012 * h), (0.165 * h, 0.108 * h, 0.036 * h), (0.07, 0.07, 0.025),
     shape=belt_shape, chunks=2, seed=5)
rbox("hips", "buckle", (0, 0.112 * h, HIP_Y + 0.012 * h), (0.045 * h, 0.022 * h, 0.04 * h), 0.03, chunks=1, seed=6)


def tabard_shape(sign):
    def f(q, u):
        t = (1 - u.z) * 0.5      # 0 top, 1 hem
        x = q.x * (1.0 + 0.22 * t)
        # bowed out over the thighs, the hem kicked a little out
        y = q.y + sign * (0.02 * math.sin(t * math.pi) + 0.03 * t * t)
        return V((x, y, q.z))
    return f
for nm, sign in (("tabard_f", 1.0), ("tabard_b", -1.0)):
    j = JOINT[nm]
    rbox(nm, "slab", j + V((0, sign * 0.012 * h, -0.155 * h)), (0.08 * h, 0.018 * h, 0.155 * h),
         (0.04, 0.016, 0.04), shape=tabard_shape(sign), chunks=2, seed=7 if sign > 0 else 8)
    # a carved band across it under the belt
    rbox(nm, "band", j + V((0, sign * 0.03 * h, -0.05 * h)), (0.085 * h, 0.014 * h, 0.018 * h), 0.012, seed=9, steps=2)

for s, sd in ((-1.0, "l"), (1.0, "r")):
    j = JOINT[f"skirt_{sd}"]
    for i, (yy, ang, tall) in enumerate(((0.055, 0.22, 0.2), (-0.05, 0.28, 0.18))):
        def slab_shape(q, u, s=s):
            t = (1 - u.z) * 0.5
            return V((q.x + s * 0.025 * t * t, q.y * (1.0 + 0.15 * t), q.z))
        rbox(f"skirt_{sd}", f"slab{i}", j + V((s * 0.03 * h, yy * h, -0.09 * h)),
             (0.022 * h, 0.06 * h, tall * 0.5 * h), (0.02, 0.04, 0.035), shape=slab_shape,
             rot=turn(ry=-s * ang), chunks=1, seed=20 + i + (0 if sd == "l" else 5))

# --- trunk: a narrow belly, the keeled barrel chest wider at the top
def belly_shape(q, u):
    t = (u.z + 1) * 0.5
    w = 1.0 + 0.18 * t
    return V((q.x * w, q.y * (1.0 + 0.12 * t) + 0.012 * (1 - u.x * u.x) * (q.y > 0), q.z))
rbox("spine", "belly", (0, 0, HIP_Y + 0.1 * h), (0.13 * h, 0.088 * h, 0.065 * h), (0.07, 0.06, 0.05),
     shape=belly_shape, seed=10)


def chest_shape(q, u):
    t = (u.z + 1) * 0.5                 # 0 bottom, 1 top
    w = 0.82 + 0.3 * smooth01(0.0, 0.8, t)  # barrel: widest high
    x = q.x * w
    y = q.y * (0.9 + 0.18 * math.sin(t * math.pi))
    if q.y > 0:
        # the keel: the front's middle pushed forward, sharpest low
        keel = (1.0 - min(1.0, abs(u.x) * 1.4)) ** 1.6
        y += keel * 0.05 * (0.6 + 0.4 * math.sin(t * math.pi))
    # the top's shoulders swell up
    z = q.z + 0.02 * (u.x * u.x) * (u.z > 0)
    return V((x, y, z))
rbox("chest", "barrel", (0, 0, HIP_Y + 0.245 * h), (0.18 * h, 0.11 * h, 0.088 * h), (0.15, 0.12, 0.09),
     shape=chest_shape, chunks=2, seed=11)
rbox("chest", "gorget", (0, -0.005 * h, NECK_Y - 0.012 * h), (0.09 * h, 0.08 * h, 0.03 * h), (0.06, 0.06, 0.025),
     seed=12, chunks=1)
# the chest's rune tablet, set into the keel
# (a row of glyphs across, each cell about 0.8 as long as it is high)
rbox("chest", "rune", (0, 0.137 * h, HIP_Y + 0.245 * h), (0.068 * h, 0.012 * h, 0.03 * h), (0.02, 0.008, 0.02),
     mat="rune", rot=turn(rx=0.14), seed=13, wear=0.4, rune="chest", steps=2)

# --- the helm: a swollen bucket, a fin crest, the T slit cut in
HY = NECK_Y
def helm_shape(q, u):
    t = (u.z + 1) * 0.5
    w = 1.0 - 0.08 * t * t + 0.04 * math.sin(t * math.pi)
    y = q.y * w
    if q.y > 0: y *= 0.92 + 0.08 * (1 - abs(u.x))   # a flatter, faceted face
    return V((q.x * w, y, q.z + 0.012 * (1 - u.x * u.x) * (1 - u.y * u.y) * (u.z > 0)))
HELM_C = V((0, 0.004 * h, HY + 0.095 * h))
HELM_HALF = (0.108 * h, 0.105 * h, 0.098 * h)
rbox("head", "helm", HELM_C, HELM_HALF, (0.12, 0.11, 0.075), shape=helm_shape, chunks=2, seed=14)
rbox("head", "brow", (0, 0.098 * h, HY + 0.142 * h), (0.098 * h, 0.022 * h, 0.017 * h), (0.02, 0.02, 0.016),
     shape=lambda q, u: V((q.x, q.y - 0.02 * u.x * u.x, q.z + 0.006 * (1 - u.x * u.x))), seed=15, chunks=1)
# The fin crest: a slab along his middle, swept back, its top rounded,
# rising from the helm's crown.
def crest_shape(q, u):
    fy = (u.y + 1) * 0.5       # 0 back, 1 front
    t = (u.z + 1) * 0.5        # 0 foot, 1 top
    # its top an arc: highest a little ahead of the middle, sweeping down
    # behind past the helm's back
    prof = 0.25 + 0.75 * math.sin(math.pi * min(1.0, 0.12 + fy * 0.95)) ** 0.7
    hz = 0.065 * h
    z = -hz + (q.z + hz) * prof
    z -= 0.06 * (1 - fy) ** 2 * (1 - t)       # its foot follows the helm's back down
    x = q.x * (1.0 - 0.4 * t)
    return V((x, q.y, z))
rbox("head", "crest", (0, -0.03 * h, HY + 0.215 * h), (0.017 * h, 0.115 * h, 0.065 * h), (0.014, 0.05, 0.03),
     shape=crest_shape, chunks=2, seed=16)

# --- boulder pauldrons over two lames
for s, sd in ((-1.0, "l"), (1.0, "r")):
    k = 0 if sd == "l" else 50
    def boulder(q, u, s=s):
        z = q.z if q.z > -0.4 * 0.095 * h else -0.4 * 0.095 * h + (q.z + 0.4 * 0.095 * h) * 0.25   # flat under
        return V((q.x * (1.0 + 0.1 * (u.z < 0)), q.y, z + 0.015 * (1 - u.x * u.x - u.y * u.y)))
    rbox(f"shoulder_{sd}", "pauldron", (s * (SH_X - 0.01 * h), 0, SH_Y + 0.02 * h), (0.14 * h, 0.14 * h, 0.105 * h),
         (0.25, 0.25, 0.19), shape=boulder, rot=turn(ry=s * 0.38), chunks=2, seed=k + 30)
    for i in range(2):
        def lame_shape(q, u):
            return V((q.x, q.y, q.z - 0.02 * u.y * u.y))   # curved round the arm
        rbox(f"shoulder_{sd}", f"lame{i}", (s * (SH_X + (0.045 + 0.02 * i) * h), 0, SH_Y - (0.055 + 0.045 * i) * h),
             (0.05 * h, (0.105 - 0.01 * i) * h, 0.018 * h), (0.03, 0.06, 0.016), shape=lame_shape,
             rot=turn(ry=s * (0.6 + 0.18 * i)), chunks=1, seed=k + 31 + i, steps=2)

# --- arms: the upper arm, the flared vambrace, the block gauntlet
for sd in ("l", "r"):
    s, sh, el, wr, fdir = ARM[sd]
    k = 0 if sd == "l" else 50
    limb(f"upper_arm_{sd}", "upper", sh + V((0, 0, -0.02 * h)), el, 0.1 * h, 0.105 * h, 0.09 * h, 0.095 * h, 0.06,
         bulge=0.06, seed=k + 40)
    limb(f"forearm_{sd}", "vambrace", el, wr - fdir * 0.01 * h, 0.1 * h, 0.105 * h, 0.15 * h, 0.145 * h, 0.06,
         chunks=1, seed=k + 41)
    # the vambrace's cuff ring at the wrist: a lip that flares
    limb(f"forearm_{sd}", "cuff", wr - fdir * 0.035 * h, wr + fdir * 0.005 * h, 0.165 * h, 0.16 * h, 0.16 * h, 0.155 * h,
         0.05, steps=2, chunks=1, seed=k + 42)
    # the gauntlet: a block fist, the knuckles a ridge at its far end
    gc = wr + fdir * 0.075 * h
    R = seg_rot(wr, wr + fdir)
    def fist(q, u):
        t = (u.z + 1) * 0.5     # 0 wrist, 1 knuckles
        y = q.y
        if q.y > 0: y += 0.015 * math.exp(-((t - 0.82) / 0.12) ** 2)   # the knuckle ridge
        return V((q.x * (0.95 + 0.1 * t), y * (0.92 + 0.1 * t), q.z))
    rbox(f"hand_{sd}", "gauntlet", gc, (0.085 * h, 0.08 * h, 0.075 * h), (0.1, 0.09, 0.08), shape=fist, rot=R,
         chunks=2, seed=k + 43)
    rbox(f"hand_{sd}", "thumb", gc + R @ V((-s * 0.065 * h, 0.04 * h, -0.01 * h)), (0.022 * h, 0.03 * h, 0.042 * h),
         0.02, rot=R @ turn(ry=s * 0.3), seed=k + 44, steps=2)
    # the gauntlet's rune tablet, on its back (his front at rest)
    rbox(f"hand_{sd}", "rune", gc + R @ V((0, 0.079 * h, -0.01 * h)), (0.05 * h, 0.01 * h, 0.03 * h),
         (0.018, 0.007, 0.018), mat="rune", rot=R, seed=k + 45, wear=0.4, rune=f"hand_{sd}", steps=2)

# ------------------------------------------------------------------ objects
objs = {}
for name, bone, bm, mat, rune in PIECES:
    me = bpy.data.meshes.new(name)
    origin = JOINT[bone]
    bmesh.ops.translate(bm, verts=bm.verts, vec=-origin)
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MATS[mat])
    if mat == "rune":
        me.materials.append(MATS["stone"])
    ob = bpy.data.objects.new(name, me)
    ob.location = origin
    ob["bone"] = bone
    if rune: ob["rune"] = rune
    scene.collection.objects.link(ob)
    objs[name] = ob

# Rune tablets: only the front is `rune`, the rest stone.
for name, ob in objs.items():
    if ob.data.materials[0].name != "rune": continue
    uv = ob.data.uv_layers["UVMap"]
    for p in ob.data.polygons:
        front = all(uv.data[li].uv.x >= 0.0 for li in p.loop_indices)
        p.material_index = 0 if front else 1

# The T slit, cut into the helm with a boolean: its floor and walls the
# dark `slit` material.
def cutter(name, center, half):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    for v in bm.verts:
        v.co = V((v.co.x * half[0], v.co.y * half[1], v.co.z * half[2])) + V(center)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MATS["slit"])
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob

helm = objs["head-helm"]
front_y = HELM_C.y + HELM_HALF[1]
# Cut deep (about 6 cm behind the face) so it reads as a dark gash with the
# eye's light at its back; the bar a little taller than the stem is wide.
SLIT_Z = HY + 0.112 * h
SLIT_HALF_Z = 0.012 * h
slit_bar = cutter("cut_bar", (0, front_y, SLIT_Z), (0.072 * h, 0.045 * h, SLIT_HALF_Z))
slit_stem = cutter("cut_stem", (0, front_y, HY + 0.07 * h), (0.0105 * h, 0.04 * h, 0.04 * h))
helm.data.materials.append(MATS["slit"])
bpy.context.view_layer.objects.active = helm
for c in (slit_bar, slit_stem):
    mod = helm.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = c
    mod.solver = "EXACT"
    try:
        mod.material_mode = "TRANSFER"
    except Exception:
        pass
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(c)
# The bar's back wall is the eye (material `eye`, lit by the game's
# eye_glow); the rest of the cut stays the dark `slit`.
helm.data.materials.append(MATS["eye"])
eye_i = len(helm.data.materials) - 1
for p in helm.data.polygons:
    is_slit = helm.data.materials[p.material_index].name == "slit"
    p.use_smooth = not is_slit
    if is_slit and p.normal.y > 0.7 and p.center.z + helm.location.z > SLIT_Z - SLIT_HALF_Z - 1e-4:
        p.material_index = eye_i

# ------------------------------------------------------------------ sockets
def socket(name, bone, at):
    e = bpy.data.objects.new(f"socket-{name}", None)
    e.empty_display_size = 0.05
    e.location = V(at)
    e["bone"] = bone
    scene.collection.objects.link(e)
    return e
s_, sh_r, el_r, wr_r, fd_r = ARM["r"]
s_, sh_l, el_l, wr_l, fd_l = ARM["l"]
sockets = [
    socket("hand_r", "hand_r", wr_r + fd_r * 0.08 * h),
    socket("hand_l", "hand_l", wr_l + fd_l * 0.08 * h),
    socket("hands_mid", "chest", V((0, 0.3 * h, HIP_Y + 0.2 * h))),
    socket("blade", "forearm_r", (el_r + wr_r) * 0.5 + V((0.06 * h, 0, 0))),
    socket("chest_rune", "chest", V((0, 0.145 * h, HIP_Y + 0.245 * h))),
    socket("eye", "head", V((0, front_y, HY + 0.112 * h))),
]

# ------------------------------------------------------------------ occlusion
meshes = [o for o in scene.objects if o.type == "MESH"]
for ob in meshes:
    attr = ob.data.color_attributes.new("AO", "BYTE_COLOR", "POINT")
    ob.data.color_attributes.active_color = attr
    try:
        ob.data.color_attributes.render_color_index = ob.data.color_attributes.active_color_index
    except Exception:
        pass
scene.render.engine = "CYCLES"
scene.cycles.samples = 40
scene.cycles.device = "CPU"
world = bpy.data.worlds.new("World")
scene.world = world
try:
    world.light_settings.distance = 0.15
except Exception:
    pass
bpy.ops.object.select_all(action="DESELECT")
for ob in meshes: ob.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
allv = []
for ob in meshes:
    allv += [d.color[0] for d in ob.data.color_attributes["AO"].data]
print("RK_AO min/mean/max", round(min(allv), 3), round(sum(allv) / len(allv), 3), round(max(allv), 3))

tris = 0
for ob in meshes:
    n = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    tris += n
    print("RK_PIECE", ob.name, n)
print("RK_TRIS pieces", len(meshes), "total", tris)
zs = [(ob.matrix_world @ v.co).z for ob in meshes for v in ob.data.vertices]
print("RK_BOUNDS z", round(min(zs), 3), round(max(zs), 3), "helm crown", round(HELM_C.z + HELM_HALF[2], 3))

# ------------------------------------------------------------------ the rig
# Bones from JOINT (rune_knight_clips.py poses them). Each piece rides its
# bone rigidly: one vertex group, weight 1, under an Armature modifier, so
# it stays its own object (the body throws pieces loose). Sockets ride
# their bones as bone-parented empties.
UP = V((0, 0, 1))
BONES = {   # name: (head, tail, parent)
    "root": (V((0, 0, 0)), V((0, 0.15 * h, 0)), None),
    "hips": (JOINT["hips"], JOINT["hips"] + UP * 0.03 * h, "root"),
    "spine": (JOINT["spine"], JOINT["chest"], "hips"),
    "chest": (JOINT["chest"], JOINT["head"], "spine"),
    "head": (JOINT["head"], JOINT["head"] + UP * 0.15 * h, "chest"),
    "tabard_f": (JOINT["tabard_f"], JOINT["tabard_f"] - UP * 0.2 * h, "hips"),
    "tabard_b": (JOINT["tabard_b"], JOINT["tabard_b"] - UP * 0.2 * h, "hips"),
}
for sd in ("l", "r"):
    s, sh, el, wr, fdir = ARM[sd]
    BONES[f"shoulder_{sd}"] = (JOINT[f"shoulder_{sd}"], JOINT[f"shoulder_{sd}"] + V((s * 0.08 * h, 0, 0)), "chest")
    BONES[f"upper_arm_{sd}"] = (sh, el, "chest")
    BONES[f"forearm_{sd}"] = (el, wr, f"upper_arm_{sd}")
    BONES[f"hand_{sd}"] = (wr, wr + fdir * 0.08 * h, f"forearm_{sd}")
    BONES[f"thigh_{sd}"] = (JOINT[f"thigh_{sd}"], JOINT[f"shin_{sd}"], "hips")
    BONES[f"shin_{sd}"] = (JOINT[f"shin_{sd}"], JOINT[f"foot_{sd}"], f"thigh_{sd}")
    BONES[f"foot_{sd}"] = (JOINT[f"foot_{sd}"], JOINT[f"foot_{sd}"] + V((0, 0.12 * h, -ANKLE * 0.5)), f"shin_{sd}")
    BONES[f"skirt_{sd}"] = (JOINT[f"skirt_{sd}"], JOINT[f"skirt_{sd}"] - UP * 0.15 * h, "hips")
arm_data = bpy.data.armatures.new("RuneKnightRig")
rig = bpy.data.objects.new("RuneKnightRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for name, (hd, tl, parent) in BONES.items():
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = hd, tl
    b.roll = 0.0
    b.use_deform = name != "root"
    eb[name] = b
for name, (hd, tl, parent) in BONES.items():
    if parent:
        eb[name].parent = eb[parent]
        eb[name].use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")
for ob in meshes:
    bone = ob["bone"]
    assert bone in BONES, (ob.name, bone)
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = rig
    ob.modifiers.new("Rig", "ARMATURE").object = rig
for e in sockets:
    mw = e.matrix_world.copy()
    e.parent = rig
    e.parent_type = "BONE"
    e.parent_bone = e["bone"]
    bpy.context.view_layer.update()
    e.matrix_world = mw
print("RK_RIG bones", len(BONES))

# ------------------------------------------------------------------ clips
sys.path.insert(0, str(HERE))
import rune_knight_clips as kc  # noqa: E402
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"
KRIG = kc.Rig(rig, JOINT, ARM)
CLIPS = kc.clips()
ACTIONS = {c.name: kc.bake(KRIG, c) for c in CLIPS}
kc.reset(rig)
# The walk's planted feet, checked: the sole under a flat foot (ankle down
# SOLE) carried forward at the mind's pace must not move.
wc = next(c for c in CLIPS if c.name == "walk")
slide = 0.0
prev = None
for f in range(int(wc.length * kc.FPS) + 1):
    t = f / kc.FPS
    D = KRIG.moves(wc, t)
    v = wc.values(t)
    p = D["foot_l"] @ JOINT["foot_l"] + V((0, kc.PACE * t, 0))
    flat = abs(v["pitch.l"]) < 0.5 and v["fz.l"] < 1e-4
    if flat and prev is not None:
        slide = max(slide, (p - prev).length)
    prev = p if flat else None
print("RK_WALK_SLIDE max per frame (m)", round(slide, 5))

if SAVE_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "rune_knight.blend"))

# ------------------------------------------------------------------ export
bpy.ops.object.select_all(action="DESELECT")
for ob in meshes + sockets + [rig]: ob.select_set(True)
bpy.context.view_layer.objects.active = rig
GLB.parent.mkdir(parents=True, exist_ok=True)
# Keyed a frame per 1/FPS s; the export reads time from the scene rate.
scene.render.fps = kc.FPS
scene.render.fps_base = 1.0
kw = dict(filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
          export_apply=False, export_animations=True, export_animation_mode="ACTIONS",
          export_force_sampling=True, export_frame_step=1, export_def_bones=False,
          export_materials="EXPORT",
          export_normals=True, export_extras=True, export_texcoords=True)
try:
    bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE")
except TypeError:
    bpy.ops.export_scene.gltf(**kw, export_colors=True)
print("RK_EXPORTED", GLB)

# ------------------------------------------------------------------ stills
if RENDER:
    import numpy as np
    RENDER.mkdir(parents=True, exist_ok=True)
    scene.render.engine = "BLENDER_WORKBENCH"
    shd = scene.display.shading
    shd.light = "STUDIO"
    shd.color_type = "VERTEX"
    shd.show_cavity = True
    shd.cavity_type = "BOTH"
    shd.show_shadows = True
    shd.shadow_intensity = 0.4
    world.color = srgb("a9c6dc")
    scene.view_settings.view_transform = "Standard"
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    def shoot(path, eye, at, lens=55, res=(560, 760)):
        cam.location = V(eye)
        cam.rotation_euler = (V(at) - V(eye)).normalized().to_track_quat("-Z", "Y").to_euler()
        scene.render.resolution_x, scene.render.resolution_y = res
        cam_data.lens = lens
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(str(path), check_existing=False)
        a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
        bpy.data.images.remove(img)
        return a

    def save(a, fp):
        out = bpy.data.images.new(fp.stem, a.shape[1], a.shape[0])
        out.pixels = a.ravel()
        out.filepath_raw = str(fp)
        out.file_format = "PNG"
        out.save()

    for tr_ in rig.animation_data.nla_tracks:
        tr_.mute = True      # else the strips pose him
    kc.reset(rig)
    cells = []
    for ang in (0, 45, 90, 135, 180, 270):
        a = math.radians(ang)
        eye = V((math.sin(a) * 5.2, math.cos(a) * 5.2, 1.4))
        cells.append(shoot(RENDER / "_cell.png", eye, (0, 0, 1.0)))
    save(np.concatenate(cells, axis=1), RENDER / "turntable.png")
    # close: the helm and the chest, three-quarter; the gauntlet
    c1 = shoot(RENDER / "_cell.png", (1.1, 1.9, 1.85), (0, 0, 1.55), lens=60, res=(700, 700))
    c2 = shoot(RENDER / "_cell.png", (1.6, 1.6, 0.9), (0.5, 0.2, 0.85), lens=60, res=(700, 700))
    save(np.concatenate([c1, c2], axis=1), RENDER / "close.png")
    print("RK_STILLS", RENDER)

    # A sheet a clip: SHEET_N frames across; rows: three-quarter front, his
    # left side (carried forward at the mind's pace in the walk, so planted
    # feet stand still in the frame), a floor line under him.
    floor_me = bpy.data.meshes.new("floor")
    bmf = bmesh.new()
    bmesh.ops.create_grid(bmf, x_segments=24, y_segments=24, size=3.0)
    bmf.to_mesh(floor_me)
    bmf.free()
    floor = bpy.data.objects.new("floor", floor_me)
    scene.collection.objects.link(floor)
    shd.show_xray = False
    SHEET_N = 6
    rows_v = [((2.3, 3.3, 1.45), (0, 0.15, 0.95), 42), ((-4.6, 0.3, 0.95), (0, 0.3, 0.9), 42)]
    for c in CLIPS:
        rows = []
        for ri, (eye, at, lens) in enumerate(rows_v):
            row = []
            for j in range(SHEET_N):
                t = c.length * j / (SHEET_N if c.loop else SHEET_N - 1)
                KRIG.apply(c, t)
                carry = kc.PACE * t if (c.name == "walk" and ri == 1) else 0.0
                rig.location = (0, carry - (kc.PACE * c.length * 0.5 if c.name == "walk" and ri == 1 else 0.0), 0)
                bpy.context.view_layer.update()
                row.append(shoot(RENDER / "_cell.png", eye, at, lens=lens, res=(400, 520)))
            rows.append(np.concatenate(row, axis=1))
        rig.location = (0, 0, 0)
        save(np.concatenate(rows[::-1], axis=0), RENDER / f"clip_{c.name}.png")
        print("RK_SHEET", c.name, RENDER / f"clip_{c.name}.png")
    kc.reset(rig)
    bpy.data.objects.remove(floor)
