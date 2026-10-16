"""Build the Face's colossus (the `face` motif, scripts/kit_isle/greybox/gb_face.gd): a seated
Olmec lord the size of a hill, cut out of a basalt cliff over the abyss, who has
sat in the dark for centuries.

He is carved the way the Olmec carved: great rounded pillows of basalt, one
figure from every side. Cross-legged on a seat of rock, his knees broad domes
(cut flat on top for the fire daises), his shins crossed in front, his thighs
running back to the hips; a belly, a chest and a heavy yoke of shoulders, the
right shoulder higher and round, the left cut flat and grassed. His upper arms
hang clear of his body (air between arm and flank), the elbows out, the
forearms laid along the outer thighs to the hands, palms down on the knees'
fronts, fingers over them. His head IS the inhaler head's carving made a
colossus (the brow band and its glyph, the slot eyes, the wedge nose, the
thick lips), a little taller, tipped forward so he looks down at the ledge.

Time has had him: chipped edges and cracks everywhere; the top of his right
shoulder broke away and lies on the ledge by his knee with its rubble; moss
lies on every face that looks up (`Moss`, a thin shell drawn as the isles'
turf), grass grows in the hollows of his tops (`Tuft_NN`, where the game grows
the ground cover's tufts), and roots crawl down his head, shoulders, arms and
knees and hang from the rock he sits on into the dark (`Roots`).

STAND-IN for a kit piece (the card's "Kit asks"): the motif stands the city kit's
real pieces in notches cut into him, so this mass carries none of the lanes'
numbers itself:
  - the shins' notch: the facing sheet wall (maker_skin) between his feet,
  - the lap: a KitLand turf island between his knees,
  - the chest: the relief cliff (city_relief), its top the collar shelf,
  - the left shoulder cut flat for a KitLand turf cap, the hauling lip
    (city_lip) as the back of his head,
  - the knee daises cut flat for the great cressets,
  - the crown cut flat for the high terrace's turf.
The notches' numbers are NOTCH below; gb_face.gd's LAYOUT carries the same.

Each mass is a superellipsoid (a rounded pillow, a little lumpy), cut by any
notch it meets (exact booleans, mass by mass); the head is the inhaler head's
mesh decimated. Baked into vertex colours (BVH rays): R occlusion, G convexity,
B the broken faces (paler, no moss).

Conventions: 1 unit = 1 m, written in the game's frame (x right/east, y up, z
toward the arrival/south) and turned into Blender's by `G`. Origin: the middle
of the skin wall's foot.

Objects (the game finds them by name):
  Colossus   the drawn mesh (stone)
  Hull       a coarse copy for his trimesh collision (the fallen piece and
             its rubble in it; never the moss, the roots or the tufts)
  Moss       the moss shell on his up-faces (vertex colour: the turf's tint)
  Roots      the roots (vertex colour: bark)
  Tuft_NN    flat polygons where grass tufts grow (the game reads the corners)
  Hold_NN    her bosses up the head's west flank (empties: middle and size)

    python tools/blender.py run art/blender/face_colossus/colossus_build.py -- [--render=PNG] [--hull=8000] [--head=14000]

Writes assets/models/face_colossus.glb, printing COLOSSUS_TRIS.
"""
import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix, Euler, noise
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GLB = ROOT / "assets" / "models" / "face_colossus.glb"
HEAD_GLB = ROOT / "assets" / "models" / "inhaler_head.glb"
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER = ""
HULL_TRIS = 9000
HEAD_TRIS = 14000
for a in _args:
    if a.startswith("--render="): RENDER = a.split("=", 1)[1]
    if a.startswith("--hull="): HULL_TRIS = int(a.split("=", 1)[1])
    if a.startswith("--head="): HEAD_TRIS = int(a.split("=", 1)[1])

# The notches the kit's pieces stand in (game frame, m). Kept in step with
# gb_face.gd LAYOUT.
LAP_Y = 9.6           # the skin wall's top, the lap's turf
COLLAR_Y = 27.2       # the relief's top: the collar shelf, the left shoulder
CROWN_Y = 46.4        # the head's flat top: the high terrace
KNEE_Y = 11.2         # the knee daises
HEAD_FRONT = -22.8    # the face's front (z) at its foot
HEAD_TALL = 20.6      # the head's height before the crown's cut (tipped, it
                      # still fills the crown's flat)
HEAD_TIP = 5.0        # degrees he bows his head (its top forward)
NOTCH = {
    # [x0, x1, y0, y1, z0, z1]
    "skin":   [-9.6, 7.6, -0.5, LAP_Y + 0.1, -6.2, 40.0],
    "lap":    [-12.4, 12.4, LAP_Y - 0.25, 26.0, -15.0, 40.0],
    # The relief: its carved panel and a hand's width of cliff (gb_face
    # LAYOUT.relief.width 15); his chest wraps it.
    "relief": [-7.7, 7.7, LAP_Y - 0.25, COLLAR_Y + 0.05, -16.0, 40.0],
    "collar": [-12.2, 12.2, COLLAR_Y - 0.25, COLLAR_Y + 3.2, -22.6, 40.0],
    # His left shoulder, flat from the head's flank out (the turf cap).
    "shoulder_w": [-40.0, -10.4, COLLAR_Y - 0.25, 60.0, -40.0, 40.0],
    "knee_w": [-23.8, -12.2, KNEE_Y, 60.0, -7.8, 3.8],
    "knee_e": [12.4, 24.0, KNEE_Y, 60.0, -8.2, 3.4],
    "crown":  [-30.0, 30.0, CROWN_Y, 90.0, -60.0, 40.0],
    "back":   [-16.0, 16.0, COLLAR_Y - 0.25, 60.0, -60.0, -40.3],
}
SO = 1.6              # the wanderer's set-off (RuinKit.SET_OFF at size 1)
# Her bosses up the head's west flank: one a set-off over the last, beside
# it (z alternating), from the shoulder to under the crown's edge.
HOLDS_Z = (-30.6, -32.5)
HOLD_W = 1.5          # along the flank (z)
HOLD_OUT = 1.3        # out of the stone (x)
HOLD_T = 0.5          # thick

def G(p):
    """The game's (x, y, z) in Blender's frame."""
    return Vector((p[0], -p[2], p[1]))

def bbox(ob):
    lo = Vector((1e9, 1e9, 1e9)); hi = -lo
    for c in ob.bound_box:
        w = ob.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi

def meets(a, b, pad=0.0):
    alo, ahi = bbox(a)
    blo, bhi = bbox(b)
    return not any(ahi[i] + pad <= blo[i] or alo[i] - pad >= bhi[i] for i in range(3))

scene = bpy.context.scene
for ob in list(bpy.data.objects): bpy.data.objects.remove(ob, do_unlink=True)
rng = random.Random(77)
blocks = []
# What may be chipped and cracked (the carved masses, not the root rock).
carved = []

def _mat(name, colour):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = colour
    return m
M_STONE = _mat("Stone", (0.5, 0.5, 0.5, 1.0))
M_CHIP = _mat("Chip", (0.7, 0.6, 0.5, 1.0))
M_BREAK = _mat("Break", (0.8, 0.6, 0.4, 1.0))
M_CUT = _mat("Cut", (0.5, 0.5, 0.6, 1.0))

def _link(me, name, mat=M_STONE):
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob

def shape(mat, half, p=3.0, cuts=7, lump=0.0, seed=0, name="p", mat_slot=M_STONE, taper=0.0, lean=0.0):
    """A superellipsoid of exponent `p` (a rounded pillow; 2 a ball, large a
    box), half-sizes `half` in its own (Blender) axes, placed by `mat`; its
    surface pushed `lump` m in and out by a slow noise (hand-carved, worn).
    `taper`: its width (x) grows by that share toward its top (+z), `lean`
    its depth (y) the same."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    for v in bm.verts:
        a = v.co
        n = (abs(a.x) ** p + abs(a.y) ** p + abs(a.z) ** p) ** (1.0 / p)
        t = a.z / n
        v.co = Vector((a.x / n * half[0] * (1.0 + taper * t), a.y / n * half[1] * (1.0 + lean * t), t * half[2]))
    bmesh.ops.transform(bm, matrix=mat, verts=bm.verts)
    bm.normal_update()
    if lump > 0.0:
        off = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
        for v in bm.verts:
            q = v.co * 0.11 + off
            v.co += v.normal * lump * (noise.noise(q) + 0.5 * noise.noise(q * 2.7))
    bm.to_mesh(me)
    bm.free()
    for f in me.polygons: f.use_smooth = True
    return _link(me, name, mat_slot)

def pillow(c, half, rot=(0.0, 0.0, 0.0), p=3.0, cuts=7, lump=0.25, chip=True, taper=0.0, lean=0.0):
    """A rounded mass of half-size `half` (game x, y, z) at `c`, turned `rot`
    degrees (about the game's x, y, z, plus a little settling)."""
    rx = rot[0] + rng.uniform(-1.0, 1.0)
    ry = rot[1] + rng.uniform(-1.0, 1.0)
    rz = rot[2] + rng.uniform(-0.8, 0.8)
    r = Euler((math.radians(rx), -math.radians(rz), math.radians(ry)), "XYZ").to_matrix().to_4x4()
    ob = shape(Matrix.Translation(G(c)) @ r, (half[0], half[2], half[1]), p, cuts, lump, len(blocks), taper=taper, lean=lean)
    blocks.append(ob)
    if chip: carved.append(ob)
    return ob

def limb(a, b, r, p=2.8, cuts=7, over=0.8, lump=0.2, chip=True):
    """A rounded mass from game point `a` to `b`, `r` (across, the other way)
    its half-thickness (across lies level), `over` m past each end."""
    A, B = G(a), G(b)
    w = (B - A).normalized()
    up = Vector((0.0, 0.0, 1.0)) if abs(w.z) < 0.8 else Vector((0.0, -1.0, 0.0))
    x = up.cross(w).normalized()
    y = w.cross(x)
    rot = Matrix((x, y, w)).transposed().to_4x4()
    L = (B - A).length * 0.5 + over
    ob = shape(Matrix.Translation((A + B) * 0.5) @ rot, (r[0], r[1], L), p, cuts, lump, len(blocks))
    blocks.append(ob)
    if chip: carved.append(ob)
    return ob

def blk(c, half, rot=(0.0, 0.0, 0.0), bevel=None, jitter=1.0):
    """A dressed block (the throne's coursed back): a box of half-size `half`
    (game x, y, z) at `c`, turned `rot` degrees, its edges rounded."""
    me = bpy.data.meshes.new("b")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bm.to_mesh(me)
    bm.free()
    ob = _link(me, "b")
    j = jitter
    hx, hy, hz = (h * (1.0 + rng.uniform(-0.03, 0.03) * j) for h in half)
    ob.scale = (hx, hz, hy)
    ob.rotation_mode = "XYZ"
    rx = rot[0] + rng.uniform(-1.5, 1.5) * j
    ry = rot[1] + rng.uniform(-1.5, 1.5) * j
    rz = rot[2] + rng.uniform(-1.2, 1.2) * j
    ob.rotation_euler = (math.radians(rx), -math.radians(rz), math.radians(ry))
    ob.location = G(c)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    m = ob.modifiers.new("bv", "BEVEL")
    m.width = bevel if bevel is not None else min(hx, hy, hz) * rng.uniform(0.22, 0.3)
    m.segments = 3
    m.limit_method = "NONE"
    bpy.ops.object.modifier_apply(modifier=m.name)
    blocks.append(ob)
    carved.append(ob)
    return ob

def course(y0, y1, x0, x1, z0, z1, cuts, gap=0.12, bevel=None):
    """One course of blocks from x0 to x1 (split at `cuts`), y0..y1, z0..z1."""
    xs = [x0] + list(cuts) + [x1]
    for i in range(len(xs) - 1):
        a, b = xs[i] + gap * 0.5, xs[i + 1] - gap * 0.5
        blk(((a + b) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), ((b - a) * 0.5, (y1 - y0) * 0.5 - gap * 0.5, (z1 - z0) * 0.5), bevel=bevel)

def rock(c, half, seed, rot=(0.0, 0.0, 0.0), rough=1.6, cuts=7, mat=M_STONE, keep=True):
    """Raw rock: a lumpy, voronoi-broken mass."""
    me = bpy.data.meshes.new("r")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    for v in bm.verts: v.co = v.co.normalized() * (0.55 + 0.45 * max(abs(v.co.x), abs(v.co.y), abs(v.co.z)))
    bm.to_mesh(me)
    bm.free()
    ob = _link(me, "r", mat)
    ob.scale = (half[0], half[2], half[1])
    ob.rotation_mode = "XYZ"
    ob.rotation_euler = (math.radians(rot[0]), -math.radians(rot[2]), math.radians(rot[1]))
    ob.location = G(c)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    tex = bpy.data.textures.new("rk%d" % seed, "VORONOI")
    tex.noise_scale = 9.0 * max(min(half) / 6.0, 0.15)
    tex.distance_metric = "DISTANCE"
    m = ob.modifiers.new("d", "DISPLACE")
    m.texture = tex
    m.strength = rough * 2.2
    m.mid_level = 0.6
    m.texture_coords = "GLOBAL"
    bpy.ops.object.modifier_apply(modifier=m.name)
    tex2 = bpy.data.textures.new("rf%d" % seed, "CLOUDS")
    tex2.noise_scale = 3.0 * max(min(half) / 6.0, 0.15)
    m = ob.modifiers.new("d2", "DISPLACE")
    m.texture = tex2
    m.strength = rough * 0.9
    m.texture_coords = "GLOBAL"
    bpy.ops.object.modifier_apply(modifier=m.name)
    if keep: blocks.append(ob)
    return ob

# ------------------------------------------------------------------ the root
# The cliff he was cut from: raw rock, a ragged stem dropping into the dark,
# under the carved masses.
for i, (y, hx, hy, hz, dx, dz, turn) in enumerate([
        (-7.0, 24.0, 6.0, 23.0, 0.0, -19.0, 0.0), (-12.0, 21.0, 8.0, 21.0, -3.0, -20.0, 20.0),
        (-24.0, 18.0, 9.0, 17.0, 3.0, -21.0, -15.0), (-38.0, 14.0, 10.0, 13.0, -2.0, -22.0, 30.0),
        (-52.0, 10.0, 9.0, 9.5, 2.0, -20.0, -20.0), (-64.0, 6.5, 8.0, 6.5, -1.0, -21.0, 10.0),
        (-6.0, 11.0, 7.0, 10.0, 18.0, -34.0, 25.0), (-8.0, 9.0, 6.0, 9.0, -19.0, -6.0, -30.0),
        (6.0, 15.0, 11.0, 7.0, 0.0, -47.0, 0.0), (18.0, 10.0, 6.0, 5.0, -3.0, -46.0, 10.0)]):
    rock((dx, y, dz), (hx, hy, hz), 10 + i, rot=(0.0, turn, 0.0))

# ------------------------------------------------------------------ the legs
# The seat under him, the thighs from the hips out to the knees, the knees
# broad domes (their tops cut flat for the daises), the shins crossed in
# front (the skin wall's notch takes their middle).
pillow((0.0, 4.8, -26.0), (13.5, 4.4, 10.5), p=3.2, cuts=8)
# The seat's foot: fills under the seat and the thighs down into the root
# rock (no crawl space under him for a knocked walker to end up in).
pillow((0.0, -0.4, -21.0), (21.0, 2.6, 16.0), p=3.0, cuts=7, chip=False)
for s in (-1.0, 1.0):
    limb((s * 7.0, 5.6, -25.0), (s * 17.5, 5.8, -4.0), (5.2, 4.3), p=2.7, cuts=8)
    pillow((s * 18.0, 6.2, -2.0), (6.4, 6.4, 6.6), p=2.6, cuts=8, lump=0.3)
    limb((s * 15.5, 3.3, 2.2), (-s * 3.0, 2.9, 6.2), (3.0, 3.1), p=2.6, cuts=7)

# ------------------------------------------------------------------ the body
# One trunk from the belt to the shoulders, broadening as it rises (the
# relief is his chest's face), the belt round his waist.
pillow((0.0, 10.4, -28.0), (14.2, 1.4, 12.4), p=4.0, cuts=8, lump=0.1)
pillow((0.0, 19.0, -29.4), (13.4, 9.6, 13.2), p=3.2, cuts=10, taper=0.16, lean=0.05, lump=0.35)
# The chest either side of the relief, wrapping its edges (a panel carved
# in his chest, not a box set before him); its tops cut flat at the collar
# (the collar's turf) and rising round on his right.
for s in (-1.0, 1.0):
    pillow((s * 11.2, 18.6, -19.6), (4.2, 10.0, 4.6), p=3.2, cuts=8, lump=0.3, taper=0.12)
# The throne's back behind him: a shelf at the collar's height (the hauling
# lip stands on it, the ridge comes to it).
course(20.0, 27.4, -15.0, 15.0, -51.0, -40.0, [-6.0, 3.5])
course(12.6, 20.0, -14.0, 14.0, -50.0, -42.0, [1.0])

# ------------------------------------------------------------------ shoulders and arms
# He leans to his right: that shoulder rides higher and round; his left is
# cut flat (the turf). The shoulders sit back of the head: he leans his
# head out over the ledge.
pillow((-19.2, 24.6, -30.6), (5.4, 5.4, 7.0), p=2.6, cuts=7)
pillow((19.6, 26.2, -30.2), (5.6, 5.6, 7.2), rot=(0.0, 0.0, -8.0), p=2.5, cuts=7)
for s in (-1.0, 1.0):
    # The upper arm hangs clear of his flank, the elbow out.
    limb((s * 20.4, 24.0, -30.6), (s * 23.8, 12.0, -21.2), (3.5, 4.0), p=3.0, over=1.4, lump=0.35)
    pillow((s * 24.0, 11.4, -20.8), (3.5, 3.5, 3.7), p=2.6, cuts=6)
    # The forearm along the outer thigh to the hand on the knee.
    limb((s * 24.8, 10.4, -20.0), (s * 23.6, 7.4, 1.2), (2.9, 2.7), p=3.2, over=0.8, lump=0.3)
    # The hand: palm down on the knee's outer front, broad fingers laid
    # over it side by side.
    pillow((s * 22.4, 7.7, 3.2), (3.2, 1.9, 3.0), rot=(10.0, s * 18.0, 0.0), p=3.0, cuts=6, lump=0.1, chip=False)
    for k in range(4):
        fx = s * (24.2 - k * 1.5)
        limb((fx, 8.2, 5.4), (fx + s * 0.1, 5.6, 6.1 - 0.1 * k), (0.72, 0.62), p=3.0, cuts=4, over=0.5, lump=0.03, chip=False)
    limb((s * 20.0, 8.2, 2.2), (s * 19.2, 9.2, 3.9), (0.8, 0.7), p=3.0, cuts=4, over=0.5, lump=0.03, chip=False)

# ------------------------------------------------------------------ what fell
# The top of his right shoulder broke away and lies on the ledge by his right
# knee in its rubble.
fallen = pillow((26.8, 2.2, 9.6), (3.6, 2.5, 3.1), rot=(18.0, 35.0, -22.0), p=2.6, cuts=6, lump=0.25, chip=False)
# A knuckle of his left hand, long fallen, lies by his left shin: the lee
# where you wait, out of the Olmec's sight, while the channel burns.
pillow((-13.6, 1.5, 9.2), (2.4, 1.8, 2.0), rot=(8.0, 30.0, -12.0), p=2.6, cuts=6, lump=0.25, chip=False)
for i, (x, z, r) in enumerate([(-11.2, 10.8, 0.6), (-16.4, 10.6, 0.5)]):
    rock((x, r * 0.35, z), (r * 1.2, r * 0.8, r), 60 + i, rot=(rng.uniform(-20, 20), rng.uniform(0, 180), rng.uniform(-20, 20)), rough=0.35, cuts=4)
for i, (x, z, r) in enumerate([(23.4, 12.4, 1.1), (30.2, 7.2, 0.9), (29.0, 12.8, 0.7), (24.6, 6.8, 0.6), (31.0, 10.6, 0.55), (21.6, 9.2, 0.5)]):
    rock((x, r * 0.35, z), (r * 1.2, r * 0.8, r), 40 + i, rot=(rng.uniform(-20, 20), rng.uniform(0, 180), rng.uniform(-20, 20)), rough=0.35, cuts=4)

# ------------------------------------------------------------------ the head
# The inhaler head's carving, made a colossus: its foot on the collar, its
# face at HEAD_FRONT, bowed HEAD_TIP degrees (he looks down at the ledge),
# its top past the crown (cut flat).
bpy.ops.object.select_all(action="DESELECT")
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(HEAD_GLB))
got = [o for o in bpy.data.objects if o not in before]
parts = [o for o in got if o.type == "MESH" and (o.name.startswith("Head") or o.name.startswith("Jaw") or o.name.startswith("Eyes"))]
for o in parts:
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
for o in got:
    if o not in parts: bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if len(parts) > 1: bpy.ops.object.join()
head = bpy.context.view_layer.objects.active
for a in list(head.data.color_attributes): head.data.color_attributes.remove(a)
lo = Vector((1e9, 1e9, 1e9)); hi = -lo
for v in head.data.vertices:
    lo = Vector(map(min, lo, v.co)); hi = Vector(map(max, hi, v.co))
k = (CROWN_Y - COLLAR_Y) / (hi.z - lo.z)
ky = HEAD_TALL / (hi.z - lo.z)
# Its face is toward Blender +y (the game's -z): turn it round to face the
# arrival, its face's front on z 0, then back to HEAD_FRONT, bowed about its
# front foot.
mat = (Matrix.Translation(G((0.0, COLLAR_Y, HEAD_FRONT))) @ Matrix.Rotation(math.radians(HEAD_TIP), 4, "X")
       @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Diagonal((k, k, ky, 1.0)) @ Matrix.Translation(Vector((-(lo.x + hi.x) * 0.5, -hi.y, -lo.z))))
head.data.transform(mat)
head.data.update()
head.data.materials.clear()
head.data.materials.append(M_STONE)
bpy.context.view_layer.update()
if "--debug" in _args: print("HEADBOX placed", [tuple(round(x, 2) for x in v) for v in bbox(head)], len(head.data.polygons))
bpy.context.view_layer.objects.active = head
m = head.modifiers.new("dec", "DECIMATE")
m.decimate_type = "COLLAPSE"
m.ratio = min(1.0, HEAD_TRIS / max(len(head.data.polygons) * 2, 1))
bpy.ops.object.modifier_apply(modifier=m.name)
# Her bosses: each found on the flank by a ray from the west, its back set
# into the stone.
hbm = bmesh.new()
hbm.from_mesh(head.data)
htree = BVHTree.FromBMesh(hbm)
holds = []
if "--scan" in _args:
    for yy in (29.0, 32.0, 36.0, 40.0, 44.0):
        row = []
        for zz in [-23.0 - 0.5 * j for j in range(36)]:
            hit = htree.ray_cast(G((-40.0, yy, zz)), Vector((1.0, 0.0, 0.0)), 60.0)
            row.append("%.1f" % hit[0].x if hit[0] is not None else "  -  ")
        print("COLOSSUS_SCAN y %.0f:" % yy, " ".join(row))
for i in range(int(round((CROWN_Y - COLLAR_Y) / SO)) - 1):
    top = COLLAR_Y + SO * (i + 1)
    z = HOLDS_Z[i % 2]
    face_x = None
    for dz in (-0.5, 0.0, 0.5):
        hit = htree.ray_cast(G((-40.0, top - HOLD_T * 0.5, z + dz)), Vector((1.0, 0.0, 0.0)), 60.0)
        if hit[0] is not None:
            face_x = hit[0].x if face_x is None else min(face_x, hit[0].x)
    if face_x is None: continue
    holds.append([face_x, top, z])
hbm.free()
# One line of bosses: each stands out to the flank's common face (a boss
# over a recess runs back into it).
line_x = sorted(h[0] for h in holds)[len(holds) // 2] if holds else 0.0
holds = [((min(line_x, fx) - HOLD_OUT, fx + 0.3), top, z) for fx, top, z in holds]
print("COLOSSUS_HOLDS", len(holds), [round(h[0][0], 2) for h in holds])
print("COLOSSUS_HEAD scale %.2f x %.2f, %d faces, %.1f wide %.1f deep" % (k, ky, len(head.data.polygons), (hi.x - lo.x) * k, (hi.y - lo.y) * k))
blocks.append(head)

# ------------------------------------------------------------------ the breaks
# Where he broke: the top of his right shoulder (gone to the ledge), the
# east flank of his head (her bosses are on the west: kept whole).
def cutter_rock(c, half, seed, mat):
    ob = rock(c, half, 100 + seed, rot=(rng.uniform(-30, 30), rng.uniform(0, 180), rng.uniform(-30, 30)), rough=0.5, cuts=3, mat=mat, keep=False)
    return ob

def cut(ob, cutter):
    bpy.context.view_layer.objects.active = ob
    m = ob.modifiers.new("c", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.object = cutter
    m.solver = "EXACT"
    # The head's mesh is open (the inhaler head's shells): hole tolerant.
    if ob is head: m.use_hole_tolerant = True
    try:
        m.material_mode = "TRANSFER"
    except Exception:
        pass
    bpy.ops.object.modifier_apply(modifier=m.name)

def slab(c, half, rot, mat):
    """A box cutter (a clean shear), `rot` degrees about the game's x, y, z."""
    me = bpy.data.meshes.new("s")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
    for v in bm.verts: v.co += Vector((noise.noise(v.co * 3.0), noise.noise(v.co * 3.0 + Vector((4, 0, 0)))*0.0, noise.noise(v.co * 3.0 + Vector((0, 9, 0))))) * 0.06
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("s", me)
    scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    ob.scale = (half[0], half[2], half[1])
    ob.rotation_euler = (math.radians(rot[0]), -math.radians(rot[2]), math.radians(rot[1]))
    ob.location = G(c)
    return ob

# His right shoulder's top sheared off, falling away outward and forward.
breaks = [slab((26.0, 33.6, -27.0), (6.0, 4.0, 9.0), (-12.0, 0.0, -24.0), M_BREAK)]
# The head's east flank: a lost corner of the brow, a bite out of the
# cheek, the ear flap's foot. Its mesh is open shells (the inhaler head's):
# no booleans; the stone is pressed in (a worn break) and the faces marked.
def dent(ob, c, r, depth, seed):
    C = G(c)
    mesh = ob.data
    if len(mesh.materials) < 2: mesh.materials.append(M_CHIP)
    off = Vector((seed * 5.3, seed * 2.9, 0.0))
    hit = set()
    for v in mesh.vertices:
        d = (v.co - C).length
        if d >= r: continue
        f = (1.0 - d / r) ** 1.5
        v.co -= v.normal * depth * f * (0.7 + 0.6 * (noise.noise(v.co * 0.9 + off) * 0.5 + 0.5))
        hit.add(v.index)
    for poly in mesh.polygons:
        if all(i in hit for i in poly.vertices): poly.material_index = 1
    mesh.update()
for i, (c, r, d) in enumerate([((9.4, 46.0, -22.0), 2.6, 1.6), ((9.9, 38.0, -27.6), 2.2, 1.0), ((9.8, 31.0, -35.0), 2.4, 1.2), ((5.0, 46.6, -38.6), 2.0, 1.0)]):
    dent(head, c, r, d, i)
# Chips on the carved masses' edges and cracks across them, at random.
chips = []
for i, ob in enumerate(list(carved)):
    vs = ob.data.vertices
    if len(vs) == 0: continue
    for j in range(rng.randint(1, 3)):
        v = vs[rng.randrange(len(vs))]
        if v.normal.z < -0.3: continue
        size = rng.uniform(0.6, 1.8) * (1.4 if ob.dimensions.length > 20.0 else 1.0)
        c = v.co + v.normal * size * 0.35
        game = (c.x, c.z, -c.y)
        chips.append(cutter_rock(game, (size, size * 0.8, size), 20 + len(chips), M_CHIP))
cracks = []
for i in range(14):
    ob = carved[rng.randrange(len(carved))]
    vs = ob.data.vertices
    v = vs[rng.randrange(len(vs))]
    if abs(v.normal.z) > 0.7: continue
    me = bpy.data.meshes.new("k")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bm.to_mesh(me)
    bm.free()
    cr = bpy.data.objects.new("k", me)
    scene.collection.objects.link(cr)
    cr.data.materials.append(M_STONE)
    tall = rng.uniform(2.5, 6.0)
    cr.scale = (0.14, 1.6, tall * 0.5)
    # A slot across the face (thin along it), into the stone.
    ang = math.atan2(v.normal.y, v.normal.x) - math.pi * 0.5
    cr.rotation_euler = (0.0, rng.uniform(-0.35, 0.35), ang)
    cr.location = v.co
    cracks.append(cr)
bpy.context.view_layer.update()
cut_n = 0
for ob in list(blocks):
    for cutter in breaks + chips + cracks:
        if ob is head: continue
        if not meets(ob, cutter): continue
        cut(ob, cutter)
        cut_n += 1
for cutter in breaks + chips + cracks: bpy.data.objects.remove(cutter, do_unlink=True)
if "--debug" in _args: print("HEADBOX after breaks", [tuple(round(x, 2) for x in v) for v in bbox(head)], len(head.data.polygons))
print("COLOSSUS_BREAKS", len(breaks), "chips", len(chips), "cracks", len(cracks), "cuts", cut_n)

# ------------------------------------------------------------------ the notches
cutters = []
for key, (x0, x1, y0, y1, z0, z1) in NOTCH.items():
    me = bpy.data.meshes.new("n")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bm.to_mesh(me)
    bm.free()
    nb = bpy.data.objects.new("n_" + key, me)
    nb.data.materials.append(M_CUT)
    nb.scale = ((x1 - x0) * 0.5, (z1 - z0) * 0.5, (y1 - y0) * 0.5)
    nb.location = G(((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5))
    scene.collection.objects.link(nb)
    cutters.append((key, nb))
bpy.context.view_layer.update()
if "--debug" in _args:
    print("HEADBOX", [tuple(round(x, 2) for x in v) for v in bbox(head)], head.matrix_world)
    for key, nb in cutters: print("NOTCHBOX", key, [tuple(round(x, 2) for x in v) for v in bbox(nb)])
cut_n = 0
for ob in list(blocks):
    for key, nb in cutters:
        if ob is head or not meets(ob, nb): continue
        before_n = len(ob.data.polygons)
        cut(ob, nb)
        if "--debug" in _args: print("NOTCH", key, ob.name, before_n, "->", len(ob.data.polygons))
        cut_n += 1
    if len(ob.data.polygons) == 0:
        blocks.remove(ob)
        bpy.data.objects.remove(ob, do_unlink=True)
for key, nb in cutters: bpy.data.objects.remove(nb, do_unlink=True)
# The crown: the head cut flat (a plane through its open shells, the cut
# filled; the crown's turf lies on it).
hb = bmesh.new()
hb.from_mesh(head.data)
res = bmesh.ops.bisect_plane(hb, geom=hb.verts[:] + hb.edges[:] + hb.faces[:], dist=0.001,
                             plane_co=Vector((0.0, 0.0, CROWN_Y)), plane_no=Vector((0.0, 0.0, 1.0)), clear_outer=True)
edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
filled = bmesh.ops.holes_fill(hb, edges=edges, sides=0)
for f in filled["faces"]: f.material_index = 0
bmesh.ops.triangulate(hb, faces=filled["faces"])
hb.to_mesh(head.data)
hb.free()
head.data.update()
print("COLOSSUS_CUTS", cut_n, "blocks", len(blocks), "crown fill", len(filled["faces"]))

# The carved masses thinned where they are smooth (the budget: a pillow's
# grid is even, its curvature is not); the head keeps its carving.
for ob in blocks:
    if ob is head or len(ob.data.polygons) < 200: continue
    bpy.context.view_layer.objects.active = ob
    m = ob.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = 0.42
    bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.object.select_all(action="DESELECT")
for ob in blocks: ob.select_set(True)
bpy.context.view_layer.objects.active = blocks[0]
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = "Colossus"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for a in list(body.data.color_attributes): body.data.color_attributes.remove(a)

def tris(ob):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode="OBJECT")
    return len(ob.data.polygons)

low_tris = tris(body)
bpy.ops.object.select_all(action="DESELECT")
hull = body.copy()
hull.data = body.data.copy()
hull.name = "Hull"
scene.collection.objects.link(hull)
bpy.context.view_layer.objects.active = hull
m = hull.modifiers.new("dec", "DECIMATE")
m.decimate_type = "COLLAPSE"
m.ratio = min(1.0, HULL_TRIS / max(low_tris, 1))
bpy.ops.object.modifier_apply(modifier=m.name)
hull_tris = tris(hull)
hull.data.materials.clear()
# Smooth within a mass, sharp at its creases: split by angle.
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
try:
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(50))
except Exception as e:
    print("COLOSSUS_SMOOTH", e)
    for p in body.data.polygons: p.use_smooth = True
print("COLOSSUS_TRIS low", low_tris, "hull", hull_tris)

# ------------------------------------------------------------------ the bake
me = body.data
mat_of = [me.materials[p.material_index].name if me.materials and me.materials[p.material_index] else "Stone" for p in me.polygons]
n = len(me.vertices)
co = np.zeros(n * 3, dtype=np.float32)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
nm = np.zeros(n * 3, dtype=np.float32)
me.vertices.foreach_get("normal", nm)
nm = nm.reshape(-1, 3)
bm = bmesh.new()
bm.from_mesh(me)
tree = BVHTree.FromBMesh(bm)
dirs = []
for i in range(14):
    t = (i + 0.5) / 14.0
    phi = i * 2.399963
    r = math.sqrt(1.0 - t)
    dirs.append(Vector((r * math.cos(phi), r * math.sin(phi), math.sqrt(t))))
occ = np.zeros(n, dtype=np.float32)
for i in range(n):
    p = Vector(co[i])
    nv = Vector(nm[i])
    q = nv.to_track_quat("Z", "Y")
    hits = 0
    for d in dirs:
        hit = tree.ray_cast(p + nv * 0.08, q @ d, 6.0)
        if hit[0] is not None: hits += 1
    occ[i] = 1.0 - hits / len(dirs)
nb_sum = np.zeros((n, 3), dtype=np.float64)
nb_cnt = np.zeros(n, dtype=np.float64)
for e in bm.edges:
    a, b = e.verts[0].index, e.verts[1].index
    nb_sum[a] += co[b]; nb_sum[b] += co[a]
    nb_cnt[a] += 1; nb_cnt[b] += 1
mean = nb_sum / np.maximum(nb_cnt, 1)[:, None]
conv = np.sum((co - mean) * nm, axis=1)
conv = np.clip(conv / 0.2 * 0.5 + 0.5, 0.0, 1.0)
# The broken faces: the shoulder's break and the head's paler, the chips a
# little (B: the relief's polish, paler and never mossed).
brk = np.zeros(n, dtype=np.float32)
for f in bm.faces:
    w = {"Break": 0.55, "Chip": 0.3}.get(mat_of[f.index], 0.0)
    if w > 0.0:
        for v in f.verts: brk[v.index] = max(brk[v.index], w)
bm.free()
attr = me.color_attributes.new("AO", "BYTE_COLOR", "POINT")
cols = np.stack([occ, conv, brk, np.ones_like(occ)], axis=1).astype(np.float32)
attr.data.foreach_set("color", cols.ravel())
me.color_attributes.active_color = attr
try:
    me.color_attributes.render_color_index = me.color_attributes.active_color_index
except Exception:
    pass
print("COLOSSUS_AO", round(float(occ.min()), 3), round(float(occ.mean()), 3), round(float(occ.max()), 3), "broken verts", int((brk > 0).sum()))

# ------------------------------------------------------------------ the growth
# Kept off the turf's own flats (the lap, the collar and left shoulder, the
# crown: KitLand's turf lies there) and off the fresh breaks.
TURF_FLATS = (LAP_Y, COLLAR_Y, CROWN_Y)

def on_turf_flat(c, nz):
    return nz > 0.95 and any(abs(c.z - y) < 0.4 for y in TURF_FLATS)

def moss_mask(c):
    q = Vector((c.x, c.y, c.z)) * 0.16
    return noise.noise(q) + 0.45 * noise.noise(q * 3.1) + 0.2

# The moss shell: the faces that look up, in patches, lifted off the stone.
sbm = bmesh.new()
sbm.from_mesh(me)
sbm.faces.ensure_lookup_table()
drop = []
for f in sbm.faces:
    c = f.calc_center_median()
    nz = f.normal.z
    keep = nz > 0.55 and mat_of[f.index] not in ("Break",) and not on_turf_flat(c, nz)
    if keep:
        keep = moss_mask(c) > (0.55 - 0.9 * nz)
    if not keep: drop.append(f)
bmesh.ops.delete(sbm, geom=drop, context="FACES")
sbm.normal_update()
for v in sbm.verts:
    v.co += v.normal * (0.07 + 0.06 * (noise.noise(v.co * 0.5) + 1.0))
mme = bpy.data.meshes.new("Moss")
sbm.to_mesh(mme)
sbm.free()
for a in list(mme.color_attributes): mme.color_attributes.remove(a)
mme.materials.clear()
moss = bpy.data.objects.new("Moss", mme)
scene.collection.objects.link(moss)
# Its colour: rgb a shade, alpha how deep in its patch (0 on the patch's
# edge; the game's moss shader breaks the edge with noise and cuts it).
edge_v = set()
ebm = bmesh.new()
ebm.from_mesh(mme)
for e in ebm.edges:
    if len(e.link_faces) < 2:
        edge_v.add(e.verts[0].index)
        edge_v.add(e.verts[1].index)
ebm.free()
ca = mme.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
mc = []
for v in mme.vertices:
    t = noise.noise(v.co * 0.3) * 0.5 + 0.5
    shade = 0.85 + 0.15 * t
    margin = moss_mask(v.co) - (0.55 - 0.9 * max(v.normal.z, 0.0))
    a = 0.0 if v.index in edge_v else min(max(0.62 + margin * 0.9, 0.0), 1.0)
    mc += [shade, shade, shade, a]
ca.data.foreach_set("color", mc)
mme.color_attributes.active_color = ca
for f in mme.polygons: f.use_smooth = True
moss_tris = tris(moss)
print("COLOSSUS_MOSS tris", moss_tris)

# Grass in the hollows of his tops: a grid of rays down; level hits in the
# moss's patches, joined by neighbour and height, each group a flat polygon.
STEP = 1.5
lo_b, hi_b = bbox(body)
cells = {}
gx0, gx1 = int(lo_b.x / STEP) - 1, int(hi_b.x / STEP) + 1
gy0, gy1 = int(lo_b.y / STEP) - 1, int(hi_b.y / STEP) + 1
# A fresh tree of the body for the rays (the bake's bmesh is freed).
tbm = bmesh.new()
tbm.from_mesh(me)
ttree = BVHTree.FromBMesh(tbm)
tbm.free()
for ix in range(gx0, gx1 + 1):
    for iy in range(gy0, gy1 + 1):
        o = Vector((ix * STEP, iy * STEP, 80.0))
        loc, nrm, idx, d = ttree.ray_cast(o, Vector((0.0, 0.0, -1.0)), 200.0)
        if loc is None or nrm.z < 0.8 or loc.z < 1.2: continue
        if on_turf_flat(loc, nrm.z) or mat_of[idx] == "Break": continue
        if moss_mask(loc) < -0.05: continue
        cells[(ix, iy)] = loc.z
groups = []
seen = set()
for key in cells:
    if key in seen: continue
    stack = [key]
    seen.add(key)
    g = []
    while stack:
        c = stack.pop()
        g.append(c)
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nk = (c[0] + d[0], c[1] + d[1])
            if nk in cells and nk not in seen and abs(cells[nk] - cells[c]) < 0.8:
                seen.add(nk)
                stack.append(nk)
    if len(g) >= 3: groups.append(g)
tufts = []
for gi, g in enumerate(groups):
    pts = [Vector((c[0] * STEP, c[1] * STEP)) for c in g]
    ys = sorted(cells[c] for c in g)
    y = ys[len(ys) // 4]
    # The group's outline: its cells' convex hull, pulled in a little.
    from mathutils.geometry import convex_hull_2d
    hull_i = convex_hull_2d(pts)
    ring = [pts[i] for i in hull_i]
    mid = sum(ring, Vector((0.0, 0.0))) / len(ring)
    ring = [mid + (p - mid) * 0.9 for p in ring]
    tme = bpy.data.meshes.new("Tuft")
    tme.from_pydata([(p.x, p.y, y) for p in ring], [], [list(range(len(ring)))])
    ob = bpy.data.objects.new("Tuft_%02d" % gi, tme)
    scene.collection.objects.link(ob)
    tufts.append(ob)
print("COLOSSUS_TUFTS", len(tufts), "cells", len(cells))

# The roots: each crawls down his stone from where it took hold (pressed to
# the surface, wandering), and hangs free where the stone falls away.
def crawl(start, steps, step, r0, seed, down=Vector((0.0, 0.0, -1.0)), hang=8.0):
    p = G(start)
    loc, nrm, idx, d = ttree.find_nearest(p)
    if loc is None: return []
    pts = []
    free = 0.0
    off = Vector((seed * 3.1, seed * 1.7, seed * 0.9))
    for i in range(steps):
        t = i / max(steps - 1, 1)
        r = r0 * (1.0 - 0.75 * t)
        loc, nrm, idx, d = ttree.find_nearest(p)
        if loc is not None and d < r * 2.5 + 0.6 and free <= 0.0:
            p = loc + nrm * r * 0.7
            tdir = down - nrm * down.dot(nrm)
            if tdir.length < 0.25:
                tdir = Vector((nrm.x, nrm.y, 0.0)) if Vector((nrm.x, nrm.y)).length > 0.05 else Vector((1.0, 0.0, 0.0))
            tdir.normalize()
        else:
            free += step
            tdir = Vector((0.0, 0.0, -1.0))
            if free > hang: break
        # Roots never climb.
        if pts and p.z > pts[-1][0].z + 0.25: break
        pts.append((p.copy(), r))
        w = Vector((noise.noise(p * 0.09 + off), noise.noise(p * 0.09 + off + Vector((5.0, 0.0, 0.0))), noise.noise(p * 0.3 + off) * 0.3))
        p = p + (tdir + w * 1.1).normalized() * step
        # A root that reaches the ledge goes into it.
        if start[1] > 0.0 and p.z < 0.25: break
    return pts

ROOTS = [
    # The crown's east edge down the head's east flank and onto the right
    # shoulder; one over the brow's east corner, down his cheek.
    ((9.4, 46.8, -25.8), 34, 0.55), ((9.6, 46.8, -30.5), 38, 0.6), ((9.2, 46.8, -35.6), 36, 0.5),
    # The back of his head and the throne's back, down into the dark.
    ((-12.0, 27.6, -50.8), 40, 0.6), ((3.0, 27.6, -51.0), 40, 0.7), ((12.6, 27.6, -50.6), 36, 0.5),
    # His right shoulder down the arm; his left shoulder's outer edge down
    # the hanging arm (never the head's west flank: her bosses).
    ((22.0, 31.2, -30.0), 40, 0.55), ((19.2, 30.4, -33.0), 34, 0.45), ((25.6, 28.0, -26.0), 30, 0.4),
    ((-22.6, 27.4, -27.0), 36, 0.5), ((-21.8, 27.4, -34.0), 34, 0.45),
    # The knees' outer flanks to the ground; the thighs' backs.
    ((-23.0, 11.4, -6.0), 18, 0.35), ((23.2, 11.4, -6.4), 18, 0.35), ((-24.0, 10.6, -2.0), 14, 0.3),
    # Seen from the ledge: down his knees' fronts, his chest beside the
    # relief, the front of his left shoulder, his right forearm.
    ((-21.0, 11.4, 1.6), 16, 0.32), ((15.5, 11.4, 2.6), 16, 0.3), ((-13.6, 27.0, -16.4), 26, 0.4),
    ((13.8, 27.6, -16.8), 24, 0.36), ((-23.4, 27.0, -25.0), 28, 0.42), ((25.2, 10.8, -12.0), 14, 0.3),
    # Under him: the rock he sits on, roots hanging into the abyss.
    ((-14.0, -6.0, -36.0), 26, 0.7), ((10.0, -8.0, -38.0), 30, 0.8), ((-2.0, -12.0, -8.0), 26, 0.6),
    ((18.0, -10.0, -24.0), 24, 0.55), ((-20.0, -10.0, -18.0), 24, 0.6), ((4.0, -20.0, -30.0), 28, 0.7),
]
rcu = bpy.data.curves.new("Roots", "CURVE")
rcu.dimensions = "3D"
rcu.bevel_depth = 1.0
rcu.bevel_resolution = 0
rcu.use_fill_caps = True
root_n = 0
for i, (start, steps, r0) in enumerate(ROOTS):
    pts = crawl(start, steps, 1.0, r0 * 1.5, i)
    if len(pts) < 3: continue
    sp = rcu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for j, (p, r) in enumerate(pts):
        sp.points[j].co = (p.x, p.y, p.z, 1.0)
        sp.points[j].radius = r
    root_n += 1
    # A side shoot or two from the thicker roots.
    if r0 >= 0.45 and len(pts) > 10:
        for b in range(2):
            j0 = rng.randrange(3, len(pts) - 5)
            p0, rr = pts[j0]
            q = (p0.x, p0.z, -p0.y)
            sub = crawl(q, steps // 2, 0.8, rr * 0.55, 50 + i * 3 + b)
            if len(sub) >= 3:
                sp = rcu.splines.new("POLY")
                sp.points.add(len(sub) - 1)
                for jj, (pp, r) in enumerate(sub):
                    sp.points[jj].co = (pp.x, pp.y, pp.z, 1.0)
                    sp.points[jj].radius = r
                root_n += 1
rob = bpy.data.objects.new("RootsCurve", rcu)
scene.collection.objects.link(rob)
bpy.ops.object.select_all(action="DESELECT")
rob.select_set(True)
bpy.context.view_layer.objects.active = rob
bpy.ops.object.convert(target="MESH")
roots = bpy.context.view_layer.objects.active
roots.name = "Roots"
roots.data.name = "Roots"
for a in list(roots.data.color_attributes): roots.data.color_attributes.remove(a)
rc = roots.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
cc = []
for v in roots.data.vertices:
    t = noise.noise(v.co * 0.7) * 0.5 + 0.5
    cc += [0.06 + 0.03 * t, 0.052 + 0.024 * t, 0.042 + 0.016 * t, 1.0]
rc.data.foreach_set("color", cc)
roots.data.color_attributes.active_color = rc
for f in roots.data.polygons: f.use_smooth = True
roots_tris = tris(roots)
print("COLOSSUS_ROOTS", root_n, "tris", roots_tris)

# The materials go: the game dresses each by name (export_materials NONE).
me.materials.clear()

empties = []
for i, ((x0, x1), top, z) in enumerate(holds):
    e = bpy.data.objects.new("Hold_%02d" % i, None)
    e.location = G(((x0 + x1) * 0.5, top - HOLD_T * 0.5, z))
    e.scale = (x1 - x0, HOLD_W, HOLD_T)   # Blender's (x, y, z) = the game's (x, z, y)
    scene.collection.objects.link(e)
    empties.append(e)
bpy.ops.object.select_all(action="DESELECT")
for ob in [body, hull, moss, roots] + tufts + empties: ob.select_set(True)
bpy.context.view_layer.objects.active = body
GLB.parent.mkdir(parents=True, exist_ok=True)
kw = dict(filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
          export_apply=False, export_animations=False, export_materials="NONE",
          export_normals=True, export_extras=False)
try:
    bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE")
except TypeError:
    bpy.ops.export_scene.gltf(**kw, export_colors=True)
print("COLOSSUS_EXPORTED", GLB, "drawn", low_tris + moss_tris + roots_tris)

if RENDER:
    hull.hide_render = True
    for t in tufts: t.hide_render = True
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "OBJECT"
    scene.display.shading.show_cavity = True
    body.color = (0.55, 0.55, 0.56, 1.0)
    moss.color = (0.3, 0.45, 0.2, 1.0)
    roots.color = (0.3, 0.2, 0.12, 1.0)
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1000
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 35
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for tag, at, look in (("front", (-30.0, 6.0, 85.0), (0.0, 22.0, -20.0)), ("side", (90.0, 22.0, 10.0), (0.0, 22.0, -20.0)),
                          ("face", (-8.0, 34.0, 22.0), (0.0, 36.0, -24.0)), ("arrival", (-24.0, 2.6, 34.0), (-2.0, 18.0, -14.0)),
                          ("back", (-40.0, 40.0, -95.0), (0.0, 20.0, -25.0))):
        cam.location = G(at)
        d = G(look) - cam.location
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = RENDER.replace(".png", "_%s.png" % tag)
        bpy.ops.render.render(write_still=True)
        print("COLOSSUS_RENDERED", scene.render.filepath)
