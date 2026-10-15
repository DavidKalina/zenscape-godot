"""Build the Face's colossus (the `face` motif, scripts/kit_isle/greybox/gb_face.gd;
card docs/design/roguelike/brainstorm/round3-olmec-city/motif-face.md): a seated
Olmec lord the size of a hill, cut out of a basalt cliff over the abyss.

He is made the way the Olmec himself is made (assets/models/headless_body.glb,
inhaler_head.glb): stacked pillow blocks of basalt. His head IS the inhaler
head's carving, scaled to a colossus (the brow band and its glyph, the slot
eyes, the wedge nose, the thick lips, the side flaps); the body is coursed
blocks: three courses of torso, a belt, shoulder blocks, arms of two blocks
each hanging and then laid along the thighs, fists on the knees, crossed legs
(thigh blocks, knee blocks, the shins crossed in front), on a seat of slabs
and a ragged root of the old cliff dropping into the dark. He leans a little
to his right; his left shoulder is cut flat (a turf terrace).

STAND-IN for a kit piece (the card's "Kit asks"): the motif stands the city kit's
real pieces in notches cut into him, so this mass carries none of the lanes'
numbers itself:
  - the shins' notch: the facing sheet wall (maker_skin) between his feet,
  - the lap: a KitLand turf island between his knees,
  - the chest: the relief cliff (city_relief), its top the collar shelf,
  - the left shoulder cut flat for a KitLand turf cap, the hauling lip
    (city_lip) over the head's west flap,
  - the knee daises cut flat for the great cressets,
  - the crown cut flat for the high terrace's turf.
The notches' numbers are NOTCH below; gb_face.gd's LAYOUT carries the same.

Each block is a beveled box (its own seed's small turn and size), cut by any
notch it meets (exact booleans, block by block); the head is the inhaler
head's mesh decimated. Baked into vertex colours (BVH rays): R occlusion,
G convexity.

Conventions: 1 unit = 1 m, written in the game's frame (x right/east, y up, z
toward the arrival/south) and turned into Blender's by `G`. Origin: the middle
of the skin wall's foot.

Objects (the game finds them by name):
  Colossus   the drawn mesh (stone)
  Hull       a coarse copy for his trimesh collision

    /opt/homebrew/bin/blender -b --python art/blender/face_colossus/colossus_build.py -- [--render=PNG] [--hull=8000] [--head=14000]

Writes assets/models/face_colossus.glb, printing COLOSSUS_TRIS.
"""
import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GLB = ROOT / "assets" / "models" / "face_colossus.glb"
HEAD_GLB = ROOT / "assets" / "models" / "inhaler_head.glb"
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER = ""
HULL_TRIS = 8000
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
HEAD_FRONT = -22.8    # the face's front (z)
NOTCH = {
    # [x0, x1, y0, y1, z0, z1]
    "skin":   [-9.6, 7.6, -0.5, LAP_Y + 0.1, -6.2, 40.0],
    "lap":    [-12.4, 12.4, LAP_Y - 0.25, 26.0, -16.0, 40.0],
    "relief": [-12.2, 12.2, LAP_Y - 0.25, COLLAR_Y + 0.05, -16.0, 40.0],
    "collar": [-12.2, 12.2, COLLAR_Y - 0.25, COLLAR_Y + 3.2, -22.6, 40.0],
    "shoulder_w": [-40.0, -15.0, COLLAR_Y - 0.25, 60.0, -40.0, 40.0],
    "shoulder_link": [-15.5, -12.0, COLLAR_Y - 0.25, 60.0, -22.6, 40.0],
    "knee_w": [-25.0, -12.4, KNEE_Y, 60.0, -9.0, 7.0],
    "knee_e": [12.4, 25.0, KNEE_Y, 60.0, -9.0, 7.0],
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

scene = bpy.context.scene
for ob in list(bpy.data.objects): bpy.data.objects.remove(ob, do_unlink=True)
rng = random.Random(77)
blocks = []

def blk(c, half, rot=(0.0, 0.0, 0.0), bevel=None, jitter=1.0):
    """A pillow block: a box of half-size `half` (game x, y, z) at `c`, turned
    `rot` degrees (about the game's x, y, z, plus a small settling jitter), its
    edges rounded (`bevel`, m: a share of its least side if None)."""
    me = bpy.data.meshes.new("b")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("b", me)
    scene.collection.objects.link(ob)
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
    return ob

def course(y0, y1, x0, x1, z0, z1, cuts, gap=0.12, bevel=None):
    """One course of blocks from x0 to x1 (split at `cuts`), y0..y1, z0..z1."""
    xs = [x0] + list(cuts) + [x1]
    for i in range(len(xs) - 1):
        a, b = xs[i] + gap * 0.5, xs[i + 1] - gap * 0.5
        blk(((a + b) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), ((b - a) * 0.5, (y1 - y0) * 0.5 - gap * 0.5, (z1 - z0) * 0.5), bevel=bevel)

# ------------------------------------------------------------------ the root
# The cliff he was cut from: raw rock, a ragged stem dropping into the dark,
# under the carved blocks.
def rock(c, half, seed, rot=(0.0, 0.0, 0.0), rough=1.6):
    me = bpy.data.meshes.new("r")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=7, use_grid_fill=True)
    for v in bm.verts: v.co = v.co.normalized() * (0.55 + 0.45 * max(abs(v.co.x), abs(v.co.y), abs(v.co.z)))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("r", me)
    scene.collection.objects.link(ob)
    ob.scale = (half[0], half[2], half[1])
    ob.rotation_mode = "XYZ"
    ob.rotation_euler = (math.radians(rot[0]), -math.radians(rot[2]), math.radians(rot[1]))
    ob.location = G(c)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    tex = bpy.data.textures.new("rk%d" % seed, "VORONOI")
    tex.noise_scale = 9.0
    tex.distance_metric = "DISTANCE"
    m = ob.modifiers.new("d", "DISPLACE")
    m.texture = tex
    m.strength = rough * 2.2
    m.mid_level = 0.6
    m.texture_coords = "GLOBAL"
    bpy.ops.object.modifier_apply(modifier=m.name)
    tex2 = bpy.data.textures.new("rf%d" % seed, "CLOUDS")
    tex2.noise_scale = 3.0
    m = ob.modifiers.new("d2", "DISPLACE")
    m.texture = tex2
    m.strength = rough * 0.9
    m.texture_coords = "GLOBAL"
    bpy.ops.object.modifier_apply(modifier=m.name)
    blocks.append(ob)
    return ob
for i, (y, hx, hy, hz, dx, dz, turn) in enumerate([
        (-7.0, 24.0, 6.0, 23.0, 0.0, -19.0, 0.0), (-12.0, 21.0, 8.0, 21.0, -3.0, -20.0, 20.0),
        (-24.0, 18.0, 9.0, 17.0, 3.0, -21.0, -15.0), (-38.0, 14.0, 10.0, 13.0, -2.0, -22.0, 30.0),
        (-52.0, 10.0, 9.0, 9.5, 2.0, -20.0, -20.0), (-64.0, 6.5, 8.0, 6.5, -1.0, -21.0, 10.0),
        (-6.0, 11.0, 7.0, 10.0, 18.0, -34.0, 25.0), (-8.0, 9.0, 6.0, 9.0, -19.0, -6.0, -30.0),
        (6.0, 15.0, 11.0, 7.0, 0.0, -47.0, 0.0), (18.0, 10.0, 6.0, 5.0, -3.0, -46.0, 10.0)]):
    rock((dx, y, dz), (hx, hy, hz), 10 + i, rot=(0.0, turn, 0.0))

# ------------------------------------------------------------------ the legs
# Thighs: long blocks from the hips out to the knees.
blk((-10.5, 5.2, -13.0), (4.8, 3.8, 10.0), rot=(0.0, 30.0, 0.0))
blk((10.5, 5.2, -13.5), (4.8, 3.8, 10.0), rot=(0.0, -30.0, 0.0))
blk((0.0, 4.6, -24.0), (12.5, 3.6, 8.0))
# Knees: squat blocks, cut flat on top for the daises.
blk((-17.5, 6.2, -1.5), (5.9, 5.0, 6.2), rot=(0.0, 12.0, 0.0))
blk((18.0, 6.2, -2.0), (5.9, 5.0, 6.2), rot=(0.0, -14.0, 0.0))
# The shins crossed in front: each from its knee to the foot by the other knee.
blk((-11.0, 3.3, 3.6), (7.6, 3.1, 2.9), rot=(0.0, -10.0, 0.0))
blk((11.0, 3.2, 3.2), (7.6, 3.0, 2.9), rot=(0.0, 12.0, 0.0))
blk((-5.0, 2.2, 5.8), (3.0, 2.2, 2.0), rot=(0.0, 20.0, 0.0))          # the feet, soles up
blk((5.0, 2.2, 5.4), (3.0, 2.2, 2.0), rot=(0.0, -20.0, 0.0))

# ------------------------------------------------------------------ the torso
# Courses up to the shoulders, wider as they rise; the front is the relief's.
blk((0.0, 10.4, -27.0), (13.6, 1.1, 12.0), bevel=0.35)                  # the belt
for k in range(4):
    blk((-10.2 + k * 6.8, 10.4, -14.8), (2.4, 0.9, 0.5), bevel=0.25)    # its studs
course(11.5, 17.0, -13.6, 13.6, -40.0, -15.6, [-4.0, 5.0])
course(17.0, 22.4, -14.4, 14.4, -40.5, -15.6, [-1.0])
course(22.4, 27.0, -15.2, 15.2, -41.0, -15.4, [-6.0, 4.5])
# The back's courses, and the throne's back behind him: a shelf at the
# collar's height (the hauling lip stands on it, the ridge comes to it).
course(11.5, 25.0, -13.0, 13.0, -44.0, -39.0, [0.0])
course(20.0, 27.4, -15.0, 15.0, -51.0, -40.0, [-6.0, 3.5])
course(12.6, 20.0, -14.0, 14.0, -50.0, -42.0, [1.0])

# ------------------------------------------------------------------ shoulders and arms
# He leans toward his right: the right shoulder rides higher.
blk((-16.8, 25.4, -28.0), (4.6, 3.6, 8.0))
blk((17.2, 26.6, -27.5), (4.8, 4.2, 8.0), rot=(0.0, 0.0, -6.0))
# Upper arms: two blocks each, hanging, a little out.
blk((-19.8, 20.0, -27.0), (3.9, 4.6, 5.2), rot=(0.0, 0.0, 6.0))
blk((-20.6, 13.8, -24.5), (3.7, 3.6, 5.2), rot=(14.0, 0.0, 8.0))
blk((20.4, 21.0, -26.5), (4.0, 4.8, 5.2), rot=(0.0, 0.0, -8.0))
blk((21.2, 14.4, -24.0), (3.8, 3.8, 5.2), rot=(14.0, 0.0, -9.0))
# Forearms laid along the thighs to the knees.
blk((-19.8, 10.9, -12.0), (3.4, 3.0, 8.0), rot=(-8.0, 6.0, 0.0))
blk((20.4, 11.3, -12.5), (3.5, 3.1, 8.0), rot=(-8.0, -6.0, 0.0))
# Fists over the knees' outer fronts, knuckles forward.
for s in (-1.0, 1.0):
    fx = s * 20.8
    blk((fx, 8.0, 3.6), (3.1, 3.0, 2.8), rot=(0.0, s * -10.0, 0.0))
    for k in range(4):
        blk((fx - s * 1.9 + s * k * 1.25, 9.3 - k * 0.15, 6.5), (0.56, 1.05, 0.5), bevel=0.22, jitter=0.5)
    blk((fx - s * 3.3, 9.6, 3.0), (0.75, 1.3, 1.5), rot=(0.0, 0.0, s * 12.0), bevel=0.3)   # the thumb

# ------------------------------------------------------------------ the head
# The inhaler head's carving, made a colossus: its foot on the collar, its
# top the crown, its face at HEAD_FRONT.
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
# Its face is toward Blender +y (the game's -z): turn it round to face the
# arrival, its face's front on z 0, then back to HEAD_FRONT.
mat = Matrix.Translation(G((0.0, COLLAR_Y, HEAD_FRONT))) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Scale(k, 4) @ Matrix.Translation(Vector((-(lo.x + hi.x) * 0.5, -hi.y, -lo.z)))
head.data.transform(mat)
head.data.update()
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
print("COLOSSUS_HEAD scale %.2f, %d faces, %.1f wide %.1f deep" % (k, len(head.data.polygons), (hi.x - lo.x) * k, (hi.y - lo.y) * k))
blocks.append(head)

# ------------------------------------------------------------------ the notches
cutters = []
for key, (x0, x1, y0, y1, z0, z1) in NOTCH.items():
    me = bpy.data.meshes.new("n")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bm.to_mesh(me)
    bm.free()
    nb = bpy.data.objects.new("n_" + key, me)
    nb.scale = ((x1 - x0) * 0.5, (z1 - z0) * 0.5, (y1 - y0) * 0.5)
    nb.location = G(((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5))
    scene.collection.objects.link(nb)
    lo_b = G((x0, y0, z1)); hi_b = G((x1, y1, z0))
    cutters.append((key, nb, lo_b, hi_b))

def bbox(ob):
    lo = Vector((1e9, 1e9, 1e9)); hi = -lo
    for c in ob.bound_box:
        w = ob.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi

cut_n = 0
for ob in list(blocks):
    for key, nb, nlo, nhi in cutters:
        lo, hi = bbox(ob)
        if any(hi[i] <= nlo[i] or lo[i] >= nhi[i] for i in range(3)): continue
        bpy.context.view_layer.objects.active = ob
        m = ob.modifiers.new("n", "BOOLEAN")
        m.operation = "DIFFERENCE"
        m.object = nb
        m.solver = "EXACT"
        bpy.ops.object.modifier_apply(modifier=m.name)
        cut_n += 1
    if len(ob.data.polygons) == 0:
        blocks.remove(ob)
        bpy.data.objects.remove(ob, do_unlink=True)
for key, nb, a, b in cutters: bpy.data.objects.remove(nb, do_unlink=True)
print("COLOSSUS_CUTS", cut_n, "blocks", len(blocks))

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
# Smooth within a block, sharp at its creases: split by angle.
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
bm.free()
attr = me.color_attributes.new("AO", "BYTE_COLOR", "POINT")
cols = np.stack([occ, conv, np.zeros_like(occ), np.ones_like(occ)], axis=1).astype(np.float32)
attr.data.foreach_set("color", cols.ravel())
me.color_attributes.active_color = attr
try:
    me.color_attributes.render_color_index = me.color_attributes.active_color_index
except Exception:
    pass
print("COLOSSUS_AO", round(float(occ.min()), 3), round(float(occ.mean()), 3), round(float(occ.max()), 3))

empties = []
for i, ((x0, x1), top, z) in enumerate(holds):
    e = bpy.data.objects.new("Hold_%02d" % i, None)
    e.location = G(((x0 + x1) * 0.5, top - HOLD_T * 0.5, z))
    e.scale = (x1 - x0, HOLD_W, HOLD_T)   # Blender's (x, y, z) = the game's (x, z, y)
    scene.collection.objects.link(e)
    empties.append(e)
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
hull.select_set(True)
for e in empties: e.select_set(True)
bpy.context.view_layer.objects.active = body
GLB.parent.mkdir(parents=True, exist_ok=True)
kw = dict(filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
          export_apply=False, export_animations=False, export_materials="NONE",
          export_normals=True, export_extras=False)
try:
    bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE")
except TypeError:
    bpy.ops.export_scene.gltf(**kw, export_colors=True)
print("COLOSSUS_EXPORTED", GLB)

if RENDER:
    hull.hide_render = True
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1000
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 35
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for tag, at, look in (("front", (-30.0, 6.0, 85.0), (0.0, 22.0, -20.0)), ("side", (90.0, 22.0, 10.0), (0.0, 22.0, -20.0)),
                          ("face", (-8.0, 34.0, 22.0), (0.0, 36.0, -24.0))):
        cam.location = G(at)
        d = G(look) - cam.location
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = RENDER.replace(".png", "_%s.png" % tag)
        bpy.ops.render.render(write_still=True)
        print("COLOSSUS_RENDERED", scene.render.filepath)
