"""The rune knight's silhouette options (docs/design/rune-knight/
spec-rune-knight-body.md, task 1): three blocked-out takes on him at his
real size, beside the wanderer (assets/models/pilot.glb) and the mind's
block stand-in (scripts/enemies/rune_knight_body_standin.gd, rebuilt here
box for box), rendered from the game camera's distance and up close.

    /opt/homebrew/bin/blender -b --python art/blender/rune_knight/rune_knight_options.py -- [--render=DIR] [--blend]

Sizes: the wanderer is WorldScale.WANDERER_TALL 1.19 m, the knight
`tall_ratio` 1.6 times that (1.904 m), as scripts/enemies/rune_knight.gd
sets them. Every take keeps the stand-in's leg lengths, hip height and
shoulder height (fractions of his height), so the mind's stride, reach and
room hold for whichever is picked.

Each take is made of separate stone pieces (helm, plates, limb segments):
the body must come apart for `crumble` and `shatter`.

- A, "bastion": a bucket great-helm with a tall fin crest and a T slit,
  boulder pauldrons with lames under them, a keeled barrel chest, heavy
  flared vambraces and block gauntlets, a skirt of hanging slabs with a
  long front and back tabard. A wide, square, heavy top.
- B, "idol": carved like the isle's old faces: a square head under a broad
  stepped headdress with ear flares, a deep brow over the eye line,
  stepped (ziggurat) pauldrons, a slab torso with tiered chest plates,
  banded round arms into huge cuffed gauntlets, a belt with a long front
  and back hanging panel, short planted column legs.
- C, "warden": gothic: a tall bascinet with a pointed beak visor and a
  crest blade sweeping back, high flared gardbraces rising past the helm's
  cheek (a V top), a narrow waist, a bell skirt of lames, a fin along each
  vambrace, pointed knee cops and sabatons.

Stills (DIR, default scratch/rk_options): lineup_mid (studio light, turf,
sky), lineup_sil (black on sky), far_15m / far_30m (the game camera's
70 degree view at its real pixel scale, a 900 px tall window, the isle's
grey stone behind the right half), and close_<take> (front, three-quarter,
side) for the stand-in and each take.
"""
import bpy
import bmesh
import math
import sys
from pathlib import Path
from mathutils import Vector as V, Matrix, Euler

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent
RENDER = ROOT / "scratch" / "rk_options"
SAVE_BLEND = False
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for a in argv:
    if a.startswith("--render="): RENDER = Path(a.split("=", 1)[1])
    elif a == "--blend": SAVE_BLEND = True

WANDERER_TALL = 1.19
H = WANDERER_TALL * 1.6          # his height (m)
GAP = 2.6                        # lineup spacing (m)

# ------------------------------------------------------------------ scene
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
coll = scene.collection


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def mat(name, hexcol, emit=None):
    m = bpy.data.materials.new(name)
    rgb = srgb(hexcol)
    m.diffuse_color = (*rgb, 1.0)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*srgb(emit), 1.0)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    return m


STONE = mat("stone", "6a645d")
STONE_LT = mat("stone_light", "7d776e")
DARK = mat("stone_dark", "3d3934")
SLIT = mat("slit", "0d0d0e")
RUNE = mat("rune", "73d9ff", emit="73d9ff")
TURF = mat("turf", "5f7a3e")
WALL = mat("wall", "8a857c")

OFF = V((0, 0, 0))     # the figure being built's place in the lineup
GROUP = None           # its collection


def link(name, bm, m):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    (GROUP or coll).objects.link(ob)
    return ob


def place(bm, at, rot=None, q=None):
    M = Matrix.Translation(V(at) + OFF)
    if q is not None:
        M = M @ q.to_matrix().to_4x4()
    elif rot is not None:
        M = M @ Euler(rot, "XYZ").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)


def bevel(bm, b):
    if b <= 0: return
    try:
        bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=b, segments=1,
                        affect="EDGES", clamp_overlap=True, profile=0.5)
    except TypeError:
        pass


def box(name, at, size, m=STONE, rot=None, top=(1.0, 1.0), shift=(0.0, 0.0), b=0.01):
    """A box `size` (x, y, z) centred at `at`; its top face scaled by `top`
    and slid by `shift` (x, y) for wedges and tapers; bevelled `b`."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.x = v.co.x * top[0] + shift[0] / size[0]
            v.co.y = v.co.y * top[1] + shift[1] / size[1]
        v.co.x *= size[0]; v.co.y *= size[1]; v.co.z *= size[2]
    bevel(bm, min(b, min(size) * 0.3))
    place(bm, at, rot)
    return link(name, bm, m)


def seg(name, a, b_, w0, d0, w1=None, d1=None, m=STONE, bev=0.012, roll=0.0):
    """A tapered box from point a to point b_ (its depth facing +y, his
    front), w x d at a and w1 x d1 at b_."""
    a, b_ = V(a), V(b_)
    w1 = w0 if w1 is None else w1
    d1 = d0 if d1 is None else d1
    L = (b_ - a).length
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        top = v.co.z > 0
        v.co.x *= (w1 if top else w0)
        v.co.y *= (d1 if top else d0)
        v.co.z = (v.co.z + 0.5) * L
    bevel(bm, min(bev, min(w0, d0, w1, d1) * 0.3))
    d = (b_ - a).normalized()
    q = d.to_track_quat("Z", "Y")
    if roll: q = q @ Euler((0, 0, roll)).to_quaternion()
    place(bm, a, q=q)
    return link(name, bm, m)


def cyl(name, a, b_, r0, r1=None, n=8, m=STONE, sx=1.0):
    a, b_ = V(a), V(b_)
    r1 = r0 if r1 is None else r1
    L = (b_ - a).length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=n, radius1=r0, radius2=r1, depth=L)
    for v in bm.verts:
        v.co.z += L * 0.5
        v.co.x *= sx
    q = (b_ - a).normalized().to_track_quat("Z", "Y")
    place(bm, a, q=q)
    return link(name, bm, m)


def blob(name, at, size, m=STONE, rot=None, cut=None, u=10, v=6):
    """An ellipsoid of radii `size`; `cut` keeps only z > cut (local, of 1)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    if cut is not None:
        for vt in bm.verts:
            vt.co.z = max(vt.co.z, cut)
    for vt in bm.verts:
        vt.co.x *= size[0]; vt.co.y *= size[1]; vt.co.z *= size[2]
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    place(bm, at, rot)
    return link(name, bm, m)


def mirror(fn):
    """Call fn(s, side) for his left (s=-1, 'L') and right (s=+1, 'R')."""
    for s, side in ((-1.0, "L"), (1.0, "R")):
        fn(s, side)


def group(name, x):
    global OFF, GROUP
    OFF = V((x, 0, 0))
    GROUP = bpy.data.collections.new(name)
    coll.children.link(GROUP)


# His frame (Blender): +z up, +y his front (glTF export turns it to
# Godot's -z), +x his right. The stand-in's proportions, shared:
h = H
THIGH, SHIN, ANKLE = 0.22 * h, 0.21 * h, 0.045 * h
HIP_X = 0.085 * h
HIP_Y = ANKLE + (THIGH + SHIN) * 0.97
SH_Y = HIP_Y + 0.03 * h + 0.27 * h      # shoulder pivot height
SH_X = 0.23 * h
NECK_Y = HIP_Y + 0.03 * h + 0.33 * h


def legs(knee_fwd=0.02, foot_fn=None, thigh_fn=None, shin_fn=None, x=HIP_X):
    """Planted legs, the knee a touch forward; the parts by the take's fns."""
    def one(s, side):
        hip = V((s * x, 0, HIP_Y))
        ankle = V((s * x * 1.08, 0.0, ANKLE))
        knee = V((s * x * 1.05, knee_fwd * h, ANKLE + SHIN))
        thigh_fn(side, hip, knee)
        shin_fn(side, knee, ankle)
        foot_fn(side, ankle)
    mirror(one)


def arms(hand_fn, upper_fn, fore_fn, spread=0.16, bend=0.3, x=SH_X):
    """Arms hung as REST: a little out, forearms a little bent forward."""
    def one(s, side):
        sh = V((s * x, 0, SH_Y))
        el = sh + V((s * math.sin(spread), 0.0, -math.cos(spread))) * 0.16 * h
        fdir = V((s * math.sin(spread * 0.7), math.sin(bend), -math.cos(bend))).normalized()
        wr = el + fdir * 0.15 * h
        upper_fn(side, sh, el)
        fore_fn(side, el, wr, fdir)
        hand_fn(side, wr, fdir)
    mirror(one)


# ============================================================ the wanderer
def wanderer(x):
    group("wanderer", x)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/models/pilot.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        for c in o.users_collection: c.objects.unlink(o)
        GROUP.objects.link(o)
    for o in [o for o in new if o.name.startswith("Icosphere")]:
        new.remove(o)
        bpy.data.objects.remove(o)
    # pilot.glb is in metres at the clips' size (WorldScale.WANDERER 1):
    # placed as is, not scaled.
    # It faces Blender -y as imported: turned to face his front (+y), and
    # its bind pose's feet (0.05 m up) set on the turf.
    roots = [o for o in new if o.parent is None]
    for r in roots:
        r.rotation_euler.z += math.pi
        r.location = V((x, 0, 0))
    bpy.context.view_layer.update()
    zs = [(o.matrix_world @ V(c)).z for o in new if o.type == "MESH" for c in o.bound_box]
    tall = max(zs) - min(zs)
    for r in roots:
        r.location.z -= min(zs)
    print("RK_WANDERER mesh bounds tall", round(tall, 3))


# ============================================================ the stand-in
def standin(x):
    """scripts/enemies/rune_knight_body_standin.gd's boxes at REST,
    Godot (x, y, z) -> Blender (x, -z, y)."""
    group("standin", x)
    def gb(name, at, size, m=STONE, rx=0.0, rz=0.0):
        box(name, (at[0], -at[2], at[1]), (size[0], size[2], size[1]), m, rot=(-rx, 0, rz), b=0.004)
    hy = HIP_Y
    gb("pelvis", (0, hy, 0), V((0.3, 0.09, 0.17)) * h, DARK)
    gb("tasset", (0, hy - 0.06 * h, -0.02 * h), V((0.32, 0.08, 0.2)) * h, STONE, rx=0.12)
    for sx in (-1, 1):
        x0 = HIP_X * sx
        gb("thigh", (x0, hy - THIGH * 0.5, 0), (0.12 * h, THIGH * 1.02, 0.13 * h))
        gb("knee", (x0, hy - THIGH, -0.02 * h), V((0.11, 0.07, 0.09)) * h, DARK)
        gb("shin", (x0, hy - THIGH - SHIN * 0.5, 0), (0.115 * h, SHIN, 0.125 * h))
        gb("sabaton", (x0, ANKLE * 0.5, -0.035 * h), (0.13 * h, ANKLE, 0.22 * h), DARK)
    wy = hy + 0.03 * h
    gb("belly", (0, wy + 0.07 * h, 0), V((0.24, 0.12, 0.16)) * h, DARK)
    gb("chest", (0, wy + 0.21 * h, -0.005 * h), V((0.38, 0.18, 0.22)) * h, STONE, rx=-0.05)
    gb("gorget", (0, wy + 0.31 * h, 0), V((0.16, 0.04, 0.14)) * h, DARK)
    gb("rune", (0, wy + 0.2 * h, -0.117 * h), V((0.012, 0.12, 0.01)) * h, RUNE)
    hd = wy + 0.33 * h
    gb("helm", (0, hd + 0.08 * h, 0.005 * h), V((0.14, 0.15, 0.16)) * h)
    gb("brow", (0, hd + 0.115 * h, -0.075 * h), V((0.15, 0.035, 0.03)) * h, DARK)
    gb("visor", (0, hd + 0.085 * h, -0.076 * h), V((0.11, 0.016, 0.01)) * h, SLIT)
    gb("crest", (0, hd + 0.165 * h, 0.015 * h), V((0.022, 0.03, 0.15)) * h, DARK)
    for sx in (-1, 1):
        shy = wy + 0.27 * h
        sh = (0.23 * h * sx, shy, 0)
        gb("pauldron", (sh[0] + 0.02 * h * sx, shy + 0.035 * h, 0), V((0.13, 0.06, 0.19)) * h, DARK, rz=-0.45 * sx)
        gb("lame", (sh[0] + 0.065 * h * sx, shy - 0.015 * h, 0), V((0.1, 0.05, 0.17)) * h, STONE, rz=-0.9 * sx)
        # arm hung at REST (spread 0.12, forearm bent 0.25): approximated straight-ish
        ax = sh[0] + 0.02 * h * sx
        gb("upper", (ax, shy - 0.08 * h, 0), V((0.09, 0.17, 0.1)) * h)
        gb("fore", (ax + 0.01 * h * sx, shy - 0.225 * h, -0.02 * h), V((0.095, 0.14, 0.1)) * h)
        gb("fist", (ax + 0.015 * h * sx, shy - 0.345 * h, -0.04 * h), V((0.13, 0.12, 0.13)) * h, DARK)


# ======================================================== A, "bastion"
def take_a(x):
    group("A_bastion", x)
    # legs: columns with a knee cop, wedge sabatons
    legs(thigh_fn=lambda sd, a, b: seg(f"thigh.{sd}", a, b, 0.13 * h, 0.14 * h, 0.12 * h, 0.13 * h),
         shin_fn=lambda sd, a, b: (seg(f"greave.{sd}", a, b, 0.125 * h, 0.13 * h, 0.105 * h, 0.11 * h),
                                   blob(f"kneecop.{sd}", a + V((0, 0.05 * h, 0)), (0.065 * h, 0.05 * h, 0.06 * h), DARK)),
         foot_fn=lambda sd, a: box(f"sabaton.{sd}", a + V((0, 0.05 * h, -ANKLE * 0.5)), (0.14 * h, 0.26 * h, ANKLE * 1.1),
                                   DARK, top=(0.8, 0.6), shift=(0, -0.03 * h)))
    # belt and the slab skirt: front and back tabard long, side slabs short
    box("belt", (0, 0, HIP_Y + 0.01 * h), (0.31 * h, 0.2 * h, 0.06 * h), DARK, b=0.02)
    box("tabard.F", (0, 0.105 * h, HIP_Y - 0.15 * h), (0.15 * h, 0.03 * h, 0.3 * h), STONE, rot=(0.05, 0, 0), top=(1.15, 1))
    box("tabard.B", (0, -0.105 * h, HIP_Y - 0.15 * h), (0.16 * h, 0.03 * h, 0.3 * h), STONE, rot=(-0.05, 0, 0), top=(1.15, 1))
    def slabs(s, sd):
        for i, (yy, ang) in enumerate(((0.06, 0.25), (-0.04, 0.3))):
            box(f"skirt{i}.{sd}", (s * 0.15 * h, yy * h, HIP_Y - 0.09 * h), (0.035 * h, 0.11 * h, 0.19 * h),
                STONE_LT if i else STONE, rot=(0, -s * ang, 0), top=(1, 1.1))
    mirror(slabs)
    # torso: narrow belly, keeled barrel chest wider at the top
    box("belly", (0, 0, HIP_Y + 0.1 * h), (0.25 * h, 0.17 * h, 0.12 * h), DARK, top=(1.25, 1.15), b=0.02)
    box("chest", (0, 0.0, HIP_Y + 0.24 * h), (0.32 * h, 0.22 * h, 0.17 * h), STONE, top=(1.25, 1.0), b=0.03)
    box("keel", (0, 0.11 * h, HIP_Y + 0.24 * h), (0.06 * h, 0.04 * h, 0.17 * h), STONE_LT, top=(0.5, 0.3), rot=(0.12, 0, 0))
    box("gorget", (0, 0, NECK_Y - 0.015 * h), (0.17 * h, 0.15 * h, 0.05 * h), DARK, b=0.02)
    # runes: chest line and chevrons, a band on each gauntlet below
    box("rune.chest", (0, 0.132 * h, HIP_Y + 0.24 * h), (0.012 * h, 0.01 * h, 0.12 * h), RUNE, rot=(0.12, 0, 0), b=0)
    for s in (-1, 1):
        box("rune.chev", (s * 0.03 * h, 0.128 * h, HIP_Y + 0.285 * h), (0.012 * h, 0.01 * h, 0.06 * h), RUNE, rot=(0.12, s * 0.7, 0), b=0)
    # helm: bucket, tall fin crest, T slit
    hy = NECK_Y
    cyl("helm", (0, 0, hy), (0, 0, hy + 0.17 * h), 0.085 * h, 0.078 * h, n=8)
    box("helmtop", (0, 0, hy + 0.175 * h), (0.13 * h, 0.14 * h, 0.02 * h), DARK, top=(0.8, 0.8))
    box("crest", (0, -0.01 * h, hy + 0.23 * h), (0.025 * h, 0.17 * h, 0.1 * h), DARK, top=(0.6, 0.7), shift=(0, -0.03 * h))
    box("slit", (0, 0.082 * h, hy + 0.115 * h), (0.12 * h, 0.012 * h, 0.014 * h), SLIT, b=0)
    box("breath", (0, 0.082 * h, hy + 0.07 * h), (0.014 * h, 0.012 * h, 0.07 * h), SLIT, b=0)
    box("brow", (0, 0.08 * h, hy + 0.135 * h), (0.15 * h, 0.03 * h, 0.022 * h), STONE_LT)
    # boulder pauldrons and lames
    def pauldron(s, sd):
        blob(f"pauldron.{sd}", (s * 0.22 * h, 0, SH_Y + 0.01 * h), (0.12 * h, 0.12 * h, 0.09 * h), STONE, rot=(0, s * 0.35, 0), cut=-0.25)
        for i in range(2):
            box(f"lame{i}.{sd}", (s * (0.27 + 0.02 * i) * h, 0, SH_Y - (0.06 + 0.045 * i) * h), (0.09 * h, 0.2 * h, 0.035 * h),
                DARK if i else STONE_LT, rot=(0, s * (0.55 + 0.15 * i), 0), b=0.01)
    mirror(pauldron)
    arms(upper_fn=lambda sd, a, b: seg(f"upper.{sd}", a, b, 0.09 * h, 0.1 * h),
         fore_fn=lambda sd, a, b, d: seg(f"vambrace.{sd}", a, b, 0.1 * h, 0.105 * h, 0.13 * h, 0.13 * h),
         hand_fn=lambda sd, a, d: (seg(f"gauntlet.{sd}", a, a + d * 0.12 * h, 0.14 * h, 0.13 * h, 0.13 * h, 0.12 * h, DARK),
                                   box(f"rune.{sd}", a + d * 0.06 * h + V((0, 0.066 * h, 0)), (0.06 * h, 0.01 * h, 0.012 * h), RUNE, b=0)),
         x=SH_X + 0.03 * h)


# ======================================================== B, "idol"
def take_b(x):
    group("B_idol", x)
    def thigh(sd, a, b):
        cyl(f"thigh.{sd}", a, b, 0.07 * h, 0.065 * h, n=8)
    def shin(sd, a, b):
        cyl(f"shin.{sd}", a, b, 0.07 * h, 0.075 * h, n=8)
        cyl(f"anklet.{sd}", b + V((0, 0, 0.02 * h)), b + V((0, 0, 0.06 * h)), 0.085 * h, n=8, m=DARK)
        cyl(f"kneeband.{sd}", a + V((0, 0, -0.02 * h)), a + V((0, 0, 0.03 * h)), 0.08 * h, n=8, m=STONE_LT)
    legs(thigh_fn=thigh, shin_fn=shin, x=HIP_X * 1.15, knee_fwd=0.0,
         foot_fn=lambda sd, a: box(f"foot.{sd}", a + V((0, 0.03 * h, -ANKLE * 0.5)), (0.16 * h, 0.24 * h, ANKLE * 1.2), DARK, b=0.015))
    # belt, and the long front/back panel: the walk's swing
    box("belt", (0, 0, HIP_Y + 0.02 * h), (0.36 * h, 0.22 * h, 0.08 * h), DARK, b=0.01)
    box("belt.knot", (0, 0.115 * h, HIP_Y + 0.02 * h), (0.09 * h, 0.03 * h, 0.09 * h), STONE_LT, b=0.01)
    box("panel.F", (0, 0.1 * h, HIP_Y - 0.2 * h), (0.17 * h, 0.025 * h, 0.4 * h), STONE, top=(1.2, 1), b=0.008)
    box("panel.B", (0, -0.1 * h, HIP_Y - 0.19 * h), (0.19 * h, 0.025 * h, 0.38 * h), STONE, top=(1.2, 1), b=0.008)
    for i in range(3):   # carved bands across the front panel
        box(f"panelband{i}", (0, 0.114 * h, HIP_Y - (0.08 + 0.12 * i) * h), (0.175 * h, 0.01 * h, 0.018 * h), DARK, b=0)
    # slab torso, tiered chest
    box("torso", (0, 0, HIP_Y + 0.17 * h), (0.36 * h, 0.2 * h, 0.24 * h), STONE, top=(1.1, 1.0), b=0.012)
    for i in range(3):
        box(f"tier{i}", (0, (0.105 + 0.012 * i) * h, HIP_Y + (0.15 + 0.045 * i) * h), ((0.3 - 0.06 * i) * h, 0.03 * h, 0.04 * h),
            STONE_LT if i % 2 else DARK, b=0.006)
    box("rune.chest", (0, 0.148 * h, HIP_Y + 0.25 * h), (0.07 * h, 0.01 * h, 0.012 * h), RUNE, b=0)
    box("rune.chest2", (0, 0.148 * h, HIP_Y + 0.22 * h), (0.012 * h, 0.01 * h, 0.05 * h), RUNE, b=0)
    box("collar", (0, 0, NECK_Y - 0.01 * h), (0.24 * h, 0.17 * h, 0.05 * h), DARK, b=0.01)
    # square head under a broad stepped headdress with ear flares
    hy = NECK_Y
    box("head", (0, 0.005 * h, hy + 0.08 * h), (0.15 * h, 0.15 * h, 0.15 * h), STONE, b=0.01)
    box("brow", (0, 0.07 * h, hy + 0.13 * h), (0.18 * h, 0.05 * h, 0.04 * h), DARK, b=0.006)
    box("eyeslit", (0, 0.081 * h, hy + 0.1 * h), (0.12 * h, 0.01 * h, 0.016 * h), SLIT, b=0)
    box("dress0", (0, 0, hy + 0.175 * h), (0.3 * h, 0.17 * h, 0.035 * h), STONE_LT, b=0.008)
    box("dress1", (0, -0.005 * h, hy + 0.205 * h), (0.22 * h, 0.15 * h, 0.03 * h), STONE, b=0.008)
    box("dress2", (0, -0.01 * h, hy + 0.235 * h), (0.12 * h, 0.12 * h, 0.035 * h), DARK, b=0.008)
    mirror(lambda s, sd: box(f"earflare.{sd}", (s * 0.105 * h, 0.0, hy + 0.08 * h), (0.035 * h, 0.08 * h, 0.17 * h), DARK, b=0.008))
    # stepped pauldrons
    def pauldron(s, sd):
        for i in range(3):
            box(f"step{i}.{sd}", (s * (0.235 + 0.008 * i) * h, 0, SH_Y + (0.04 - 0.045 * i) * h),
                ((0.12 + 0.03 * i) * h, (0.16 + 0.03 * i) * h, 0.04 * h), STONE_LT if i == 1 else STONE, b=0.008)
    mirror(pauldron)
    def fore(sd, a, b, d):
        cyl(f"fore.{sd}", a, b, 0.055 * h, 0.06 * h, n=8)
        cyl(f"band.{sd}", a + d * 0.03 * h, a + d * 0.06 * h, 0.062 * h, n=8, m=DARK)
    def hand(sd, a, d):
        cyl(f"cuff.{sd}", a - d * 0.04 * h, a + d * 0.02 * h, 0.08 * h, 0.085 * h, n=8, m=STONE_LT)
        seg(f"gauntlet.{sd}", a, a + d * 0.13 * h, 0.15 * h, 0.12 * h, 0.15 * h, 0.11 * h, DARK, bev=0.02)
        box(f"rune.{sd}", a + d * 0.07 * h + V((0, 0.061 * h, 0)), (0.012 * h, 0.01 * h, 0.07 * h), RUNE, b=0)
    arms(upper_fn=lambda sd, a, b: cyl(f"upper.{sd}", a, b, 0.055 * h, n=8),
         fore_fn=fore, hand_fn=hand, x=SH_X + 0.025 * h, spread=0.2)


# ======================================================== C, "warden"
def take_c(x):
    group("C_warden", x)
    def shin(sd, a, b):
        seg(f"greave.{sd}", a, b, 0.11 * h, 0.12 * h, 0.08 * h, 0.09 * h)
        box(f"poleyn.{sd}", a + V((0, 0.055 * h, 0.0)), (0.08 * h, 0.06 * h, 0.08 * h), DARK, top=(0.4, 0.2), shift=(0, 0.04 * h), b=0.005)
    legs(thigh_fn=lambda sd, a, b: seg(f"thigh.{sd}", a, b, 0.115 * h, 0.12 * h, 0.1 * h, 0.11 * h),
         shin_fn=shin, knee_fwd=0.03,
         foot_fn=lambda sd, a: box(f"sabaton.{sd}", a + V((0, 0.08 * h, -ANKLE * 0.5)), (0.11 * h, 0.3 * h, ANKLE),
                                   DARK, top=(0.5, 0.5), shift=(0, -0.05 * h), rot=(0, 0, 0)))
    # bell skirt of lames, then tassets
    for i in range(3):
        cyl(f"lame{i}", (0, 0, HIP_Y + (0.04 - 0.055 * i) * h), (0, 0, HIP_Y + (-0.01 - 0.055 * i) * h),
            (0.14 + 0.025 * i) * h, (0.17 + 0.025 * i) * h, n=10, m=STONE_LT if i % 2 else STONE, sx=1.0)
    mirror(lambda s, sd: box(f"tasset.{sd}", (s * 0.09 * h, 0.08 * h, HIP_Y - 0.2 * h), (0.1 * h, 0.03 * h, 0.12 * h), DARK, rot=(0.25, s * 0.15, 0)))
    # narrow waist, pigeon breast
    box("waist", (0, 0, HIP_Y + 0.09 * h), (0.18 * h, 0.14 * h, 0.12 * h), DARK, top=(1.4, 1.2), b=0.015)
    blob("breast", (0, 0.02 * h, HIP_Y + 0.24 * h), (0.16 * h, 0.12 * h, 0.12 * h), STONE, u=10, v=6)
    box("plackart", (0, 0.08 * h, HIP_Y + 0.17 * h), (0.12 * h, 0.04 * h, 0.1 * h), STONE_LT, top=(1.4, 1), rot=(-0.2, 0, 0))
    box("rune.chest", (0, 0.14 * h, HIP_Y + 0.25 * h), (0.012 * h, 0.01 * h, 0.13 * h), RUNE, b=0)
    for s in (-1, 1):
        box("rune.wing", (s * 0.04 * h, 0.135 * h, HIP_Y + 0.22 * h), (0.012 * h, 0.01 * h, 0.07 * h), RUNE, rot=(0, -s * 0.8, 0), b=0)
    cyl("gorget", (0, 0, NECK_Y - 0.04 * h), (0, 0, NECK_Y + 0.01 * h), 0.09 * h, 0.065 * h, n=10, m=DARK)
    # tall bascinet, pointed beak visor, a crest sweeping back
    hy = NECK_Y
    blob("helm", (0, -0.005 * h, hy + 0.1 * h), (0.075 * h, 0.085 * h, 0.12 * h), STONE, u=10, v=7)
    box("helmpeak", (0, -0.01 * h, hy + 0.2 * h), (0.07 * h, 0.08 * h, 0.06 * h), STONE, top=(0.05, 0.1), shift=(0, -0.02 * h))
    seg("beak", (0, 0.04 * h, hy + 0.09 * h), (0, 0.15 * h, hy + 0.07 * h), 0.11 * h, 0.1 * h, 0.012 * h, 0.012 * h, STONE_LT)
    box("slit", (0, 0.075 * h, hy + 0.125 * h), (0.11 * h, 0.04 * h, 0.012 * h), SLIT, b=0)
    for i in range(5):   # the crest, a blade arching up and back
        t = i / 4.0
        a = math.radians(-20 + 110 * t)
        r = 0.13 * h
        p = V((0, r * math.sin(a) * 0.9 + 0.0, hy + 0.1 * h + r * math.cos(a)))
        box(f"crest{i}", p, (0.018 * h, 0.06 * h, (0.06 - 0.008 * i) * h), DARK, rot=(-a, 0, 0), b=0.003)
    # high flared gardbraces: the V
    def pauldron(s, sd):
        blob(f"pauldron.{sd}", (s * 0.2 * h, 0, SH_Y), (0.1 * h, 0.11 * h, 0.06 * h), STONE, rot=(0, s * 0.3, 0))
        # the upswept wing of the gardbrace, its outer edge high: the V
        box(f"gard.{sd}", (s * 0.235 * h, 0, SH_Y + 0.07 * h), (0.15 * h, 0.17 * h, 0.03 * h), STONE_LT,
            rot=(0, -s * 0.7, 0), top=(1, 0.8), b=0.006)
        for i in range(2):
            box(f"lame{i}.{sd}", (s * (0.25 + 0.015 * i) * h, 0, SH_Y - (0.05 + 0.04 * i) * h), (0.08 * h, 0.17 * h, 0.03 * h),
                DARK if i else STONE, rot=(0, s * (0.6 + 0.15 * i), 0))
    mirror(pauldron)
    def fore(sd, a, b, d):
        seg(f"vambrace.{sd}", a, b, 0.085 * h, 0.09 * h, 0.105 * h, 0.105 * h)
        s = 1.0 if sd == "R" else -1.0
        out = V((s, 0, 0))
        seg(f"fin.{sd}", a + out * 0.045 * h + d * 0.02 * h, b + out * 0.06 * h, 0.05 * h, 0.012 * h, 0.012 * h, 0.012 * h, DARK, roll=math.pi / 2)
    arms(upper_fn=lambda sd, a, b: seg(f"upper.{sd}", a, b, 0.08 * h, 0.09 * h),
         fore_fn=fore,
         hand_fn=lambda sd, a, d: (seg(f"gauntlet.{sd}", a, a + d * 0.12 * h, 0.12 * h, 0.115 * h, 0.1 * h, 0.1 * h, DARK),
                                   box(f"rune.{sd}", a + d * 0.06 * h + V((0, 0.06 * h, 0)), (0.012 * h, 0.01 * h, 0.06 * h), RUNE, b=0)),
         x=SH_X - 0.005 * h, spread=0.18)


LINE = [("wanderer", wanderer), ("standin", standin), ("A_bastion", take_a), ("B_idol", take_b), ("C_warden", take_c)]
for i, (n, fn) in enumerate(LINE):
    fn(-(i - 2) * GAP)   # the camera looks down -y: +x is the frame's left
GROUP = None
OFF = V((0, 0, 0))

for g in bpy.data.collections:
    if g.name.startswith("glTF"): continue
    tris = 0
    for o in g.objects:
        if o.type == "MESH":
            tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("RK_OPTION", g.name, "pieces", len([o for o in g.objects if o.type == "MESH"]), "tris", tris)

# ground: turf, and a stretch of the aqueduct's grey stone behind the right half
gp = box("turf", (0, 0, -0.05), (60, 60, 0.1), TURF, b=0)
wall = box("wall", (-6.5, -4.0, 2.5), (9.0, 1.5, 5.0), WALL, b=0)

if SAVE_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "rune_knight_options.blend"))

# ================================================================== stills
import numpy as np
RENDER.mkdir(parents=True, exist_ok=True)
scene.render.engine = "BLENDER_WORKBENCH"
sh = scene.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL"
sh.show_shadows = True
sh.shadow_intensity = 0.4
sh.show_cavity = True
sh.cavity_type = "BOTH"
world = bpy.data.worlds.new("w")
world.color = srgb("a9c6dc")
scene.world = world
scene.display_settings.display_device = "sRGB"
scene.view_settings.view_transform = "Standard"
scene.view_settings.exposure = 0.5     # Workbench reads the kit stone darker than the isle's light does
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
coll.objects.link(cam)
scene.camera = cam


def shoot(path, eye, at, lens=None, res=(1600, 700), vfov=None):
    cam.location = V(eye)
    cam.rotation_euler = (V(at) - V(eye)).normalized().to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    if vfov is not None:
        cam_data.sensor_fit = "VERTICAL"
        cam_data.angle_y = vfov
    else:
        cam_data.sensor_fit = "AUTO"
        cam_data.lens = lens
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return path


def load(fp):
    img = bpy.data.images.load(str(fp), check_existing=False)
    a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
    bpy.data.images.remove(img)
    return a


def save(a, fp):
    out = bpy.data.images.new(fp.stem, a.shape[1], a.shape[0])
    out.pixels = a.ravel()
    out.filepath_raw = str(fp)
    out.file_format = "PNG"
    out.save()


# The lineup, studio light, then black on sky.
shoot(RENDER / "lineup_mid.png", (0, 16.0, 1.8), (0, 0, 1.0), lens=42)
mats = [m for m in bpy.data.materials]
keep = {m.name: tuple(m.diffuse_color) for m in mats}
for m in mats:
    if m.name not in ("turf", "wall"):
        m.diffuse_color = (0.02, 0.02, 0.02, 1)
sh.light = "FLAT"
sh.show_cavity = False
sh.show_shadows = False
wall.hide_render = True
shoot(RENDER / "lineup_sil.png", (0, 16.0, 0.6), (0, 0, 1.2), lens=42)
for m in mats:
    m.diffuse_color = keep[m.name]
wall.hide_render = False
sh.light = "STUDIO"
sh.show_cavity = True
sh.show_shadows = True

# The game camera: a 70 degree view, 900 px tall; crops at its pixel scale.
PX_PER_RAD = 450.0 / math.tan(math.radians(35.0))
for dist, res in ((15.0, (900, 300)), (30.0, (560, 200))):
    vf = 2.0 * math.atan(res[1] * 0.5 / PX_PER_RAD)
    shoot(RENDER / f"far_{int(dist)}m.png", (0, dist, 3.0), (0, 0, 1.0), res=res, vfov=vf)

# Close: front, three-quarter (front right, above), side (his right).
for i, (n, fn) in enumerate(LINE):
    x = -(i - 2) * GAP
    for g in bpy.data.collections:
        for o in g.objects:
            o.hide_render = g.name != n
    wall.hide_render = True
    cells = []
    for v, (eye, at) in {"front": ((x, 5.0, 1.1), (x, 0, 1.0)),
                          "three": ((x + 3.4, 3.6, 2.3), (x, 0, 0.95)),
                          "side": ((x + 5.0, 0.0, 1.1), (x, 0, 1.0))}.items():
        cells.append(load(shoot(RENDER / "_cell.png", eye, at, lens=55, res=(560, 760))))
    save(np.concatenate(cells, axis=1), RENDER / f"close_{n}.png")
    for g in bpy.data.collections:
        for o in g.objects:
            o.hide_render = False
    wall.hide_render = False
print("RK_STILLS", RENDER)
