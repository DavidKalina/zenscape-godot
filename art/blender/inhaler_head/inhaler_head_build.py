"""Build the inhaler head (scripts/enemies/inhaler_head.gd): a colossal carved stone head, Olmec
in spirit (helmet-like headdress with a forehead band and ear flaps, a heavy
furrowed brow, heavy-lidded almond eyes, a broad flat nose, full downturned
lips, full cheeks, a solemn face) but squared off into the ruin kit's
coursed masonry: the face mass is laid in courses of blocks with their
joints showing, the band is five blocks, the jaw is its own bottom course
and drops on a hinge so the mouth opens.

Everything is rounded boxes (a subdivided cube mapped onto a box with round
arrises, dense where the arris turns), deformed by a part's own shape
(taper, bulge, downturned corners), then weathered: a low noise over every
face and a few chunks broken off corners as flat facets, like the kit's
eroded stone. Shaded smooth: the kit's stone material in the game colours
it face by face (scripts/ruin_stone_style.gd `shade`) and the baked
occlusion in COLOR_0 darkens the carving's crevices.

Conventions: 1 unit = 1 m, written in the game's frame (Y up, the face
toward -Z, right +X) and turned into Blender's by `G`. Authored HEIGHT m
tall (chin to crown); the game scales it from the wanderer's height. The
origin is the chin's foot (its bottom, middle).

Objects (the game finds them by name):
  Head    the face, helmet and courses (stone)
  Jaw     the bottom course with the lower lip and chin; its origin is the
          hinge, so turning it about its own +X drops the mouth open
  Eyes    the two eyeballs (the game lights them when it locks on)
  Maw     the dark throat behind the lips and the nostrils
  Mouth   an empty at the lips' parting, the way in

    python tools/blender.py run art/blender/inhaler_head/inhaler_head_build.py -- [--out=DIR] [--blend] [--render=PNG] [--open=RAD]

Writes assets/models/inhaler_head.glb, printing INHALER_TRIS per object;
--blend saves art/blender/inhaler_head/inhaler_head.blend; --render writes a
workbench still (the jaw opened --open= rad for the still only).
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector, noise

V = Vector
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ROOT / "assets/models"
SAVE_BLEND = False
RENDER = ""
OPEN = 0.0
for a in _args:
    if a.startswith("--out="): OUT = Path(a.split("=", 1)[1])
    elif a == "--blend": SAVE_BLEND = True
    elif a.startswith("--render="): RENDER = a.split("=", 1)[1]
    elif a.startswith("--open="): OPEN = float(a.split("=", 1)[1])
GLB = OUT / "inhaler_head.glb"
rng = random.Random(23)

HEIGHT = 3.2
## The jaw's hinge (game frame): behind the cheeks, at the course line.
HINGE = V((0.0, 0.84, 0.55))
## The lips' parting, the way in.
MOUTH = V((0.0, 0.96, -1.5))
## The interior spacing of a box's grid (m) and the samples round an arris.
SPACING = 0.17
ROUND_STEPS = 4
## The weathering: the noise's depth (m) and size (m), and the chunks.
WEAR = 0.02
WEAR_SIZE = 0.55


def G(p):
    """The game's frame (Y up, -Z front) to Blender's (Z up, -Y front... +Y)."""
    return V((p[0], -p[2], p[1]))


# ------------------------------------------------------------------ materials
PALETTE = {
    "stone": ("5a5d63", 0.95),
    "eye": ("d8c48a", 0.6),
    "maw": ("120e0c", 1.0),
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


# ------------------------------------------------------------------ rounded boxes
def _axis(half, r, spacing):
    """Coordinates along one axis of a box: ROUND_STEPS through each arris'
    band, the interior at about `spacing`."""
    r = min(r, half * 0.98)
    inner = half - r
    out = []
    for i in range(ROUND_STEPS):
        out.append(-half + r * (i / ROUND_STEPS) ** 1.0)
    n = max(1, int(math.ceil(2.0 * inner / spacing)))
    for i in range(n + 1):
        out.append(-inner + 2.0 * inner * i / n)
    for i in range(ROUND_STEPS - 1, -1, -1):
        out.append(half - r * (i / ROUND_STEPS))
    # Unique, sorted.
    out = sorted(set(round(c, 6) for c in out))
    return out


class Part:
    """A mesh being gathered: verts (game frame) and quads."""

    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []
        self.mats = []

    def add(self, verts, faces, mat):
        base = len(self.verts)
        self.verts.extend(verts)
        self.faces.extend([tuple(base + i for i in f) for f in faces])
        self.mats.extend([mat] * len(faces))


def rbox(part, center, half, r, mat="stone", shape=None, wear=1.0, chunks=0, seed=0):
    """A rounded box, centre `center`, half extents `half`, arris radius `r`,
    its points moved by `shape(local, u)` (local: off the centre, u: that over
    the half extents, -1..1), weathered by `wear` of WEAR and `chunks` corners
    broken off."""
    hx, hy, hz = half
    ax = [_axis(hx, r, SPACING), _axis(hy, r, SPACING), _axis(hz, r, SPACING)]
    verts = []
    faces = []
    index = {}

    def vid(p):
        key = (round(p[0], 5), round(p[1], 5), round(p[2], 5))
        if key not in index:
            index[key] = len(verts)
            verts.append(V(p))
        return index[key]

    # The six faces: (fixed axis, sign, the other two axes in winding order).
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
    # Onto the rounded box.
    rr = [min(r, h * 0.98) for h in half]
    out = []
    for p in verts:
        inner = V((max(-hx + rr[0], min(hx - rr[0], p.x)),
                   max(-hy + rr[1], min(hy - rr[1], p.y)),
                   max(-hz + rr[2], min(hz - rr[2], p.z))))
        d = p - inner
        if d.length > 1e-9:
            d = V((d.x / rr[0] if rr[0] > 0 else 0, d.y / rr[1] if rr[1] > 0 else 0, d.z / rr[2] if rr[2] > 0 else 0))
            d.normalize()
            q = inner + V((d.x * rr[0], d.y * rr[1], d.z * rr[2]))
        else:
            q = V(p)
        out.append(q)
    # The part's own shape.
    if shape is not None:
        out = [shape(q, V((q.x / hx, q.y / hy, q.z / hz))) for q in out]
    # The chunks: a corner's points past a plane laid onto it, a flat break.
    crng = random.Random(seed)
    cuts = []
    for k in range(chunks):
        corner = V((crng.choice((-1, 1)) * hx, crng.choice((-1, 1)) * hy, crng.choice((-1, 1)) * hz))
        if corner.z > 0 and crng.random() < 0.6: corner.z = -corner.z  # mostly the front, where it is seen
        nrm = V((corner.x / hx + crng.uniform(-0.4, 0.4), corner.y / hy + crng.uniform(-0.4, 0.4),
                 corner.z / hz + crng.uniform(-0.4, 0.4))).normalized()
        depth = crng.uniform(0.08, 0.22)
        cuts.append((corner, nrm, depth))
    for i, q in enumerate(out):
        for corner, nrm, depth in cuts:
            # The plane through the corner pulled in `depth` along the normal.
            plane = corner.dot(nrm) - depth - r * 0.6
            over = q.dot(nrm) - plane
            if over > 0: q = q - nrm * over
        out[i] = q
    # The noise, along the way out from the box's middle.
    verts_w = []
    for q in out:
        w = center + q
        n = noise.noise(w / WEAR_SIZE) * 0.7 + noise.noise(w / (WEAR_SIZE * 0.3)) * 0.3
        away = V((q.x / hx, q.y / hy, q.z / hz))
        if away.length > 1e-6: away.normalize()
        verts_w.append(w + away * n * WEAR * wear)
    part.add(verts_w, faces, mat)


def smooth01(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ the head
head = Part("Head")
jaw = Part("Jaw")
eyes = Part("Eyes")
maw = Part("Maw")

# Course A, the cheeks' course: y 0.80..1.48. Its middle block carries the
# cheeks (a bulge forward) and its side blocks stand back.
def cheeks(q, u):
    if u.z < 0:
        full = math.exp(-((abs(q.x) - 0.62) / 0.34) ** 2) * (1 - u.y * u.y * 0.6)
        q = q + V((0, 0, -0.11 * full * (-u.z) ** 2))
    return q


rbox(head, V((0, 1.14, 0.02)), V((0.9, 0.34, 1.13)), 0.07, shape=cheeks, chunks=1, seed=1)
for s in (-1, 1):
    rbox(head, V((s * 1.1, 1.14, 0.05)), V((0.18, 0.34, 1.1)), 0.06, chunks=1, seed=2 + s)

# Course B, the eyes' course: y 1.50..2.30, its joints further out.
def temples(q, u):
    if u.z < 0:
        q = q + V((0, 0, -0.04 * (1 - u.x * u.x) * (-u.z) ** 2))
    return q


rbox(head, V((0, 1.9, 0.03)), V((1.0, 0.4, 1.12)), 0.07, shape=temples, chunks=1, seed=4)
for s in (-1, 1):
    rbox(head, V((s * 1.17, 1.9, 0.05)), V((0.15, 0.4, 1.08)), 0.05, chunks=1, seed=5 + s)

# The helmet: a cap a little proud of the courses, domed, then the band of
# five blocks across the front and one down each side, the middle block
# bearing a square boss.
def dome(q, u):
    if u.y > 0:
        q = q + V((0, 0.09 * (1 - u.x * u.x) * (1 - u.z * u.z) * u.y, 0))
    # Squared, but swelling a little at the crown's front.
    return q


rbox(head, V((0, 2.76, 0.0)), V((1.42, 0.44, 1.32)), 0.11, shape=dome, chunks=3, seed=7, wear=1.3)
BAND_Y = 2.44
BAND_H = 0.19
xs = [-1.46, -0.88, -0.29, 0.29, 0.88, 1.46]
for i in range(5):
    x0, x1 = xs[i] + 0.016, xs[i + 1] - 0.016
    def band(q, u, i=i):
        # The outer blocks turn back with the head's corners.
        if i in (0, 4) and u.z < 0:
            q = q + V((0, 0, 0.05 * ((q.x + (x0 + x1) * 0.5) / 1.46) ** 4))
        return q
    rbox(head, V(((x0 + x1) * 0.5, BAND_Y, -1.2)), V(((x1 - x0) * 0.5, BAND_H, 0.24)), 0.05,
         shape=band, chunks=1 if i != 2 else 0, seed=10 + i, wear=1.2)
rbox(head, V((0, BAND_Y, -1.45)), V((0.2, 0.13, 0.05)), 0.04, seed=16)
rbox(head, V((0, BAND_Y, -1.5)), V((0.1, 0.06, 0.03)), 0.025, seed=17)
for s in (-1, 1):
    rbox(head, V((s * 1.4, BAND_Y, 0.02)), V((0.1, BAND_H, 1.12)), 0.05, chunks=1, seed=18 + s, wear=1.2)

# The ear flaps: tall slabs hanging from the band to the jaw's course, each
# with a square spool (two plaques, the inner proud of the outer).
for s in (-1, 1):
    def flap(q, u, s=s):
        # Narrower at the foot, a little out at the bottom like a hanging cloth.
        q = q + V((s * 0.04 * smooth01(0.3, -1.0, u.y), 0, 0))
        q = V((q.x, q.y, q.z * (0.86 + 0.14 * smooth01(-1.0, 0.6, u.y))))
        return q
    rbox(head, V((s * 1.43, 1.4, -0.05)), V((0.11, 0.92, 0.7)), 0.06, shape=flap, chunks=1, seed=20 + s)
    rbox(head, V((s * 1.56, 1.52, -0.1)), V((0.05, 0.22, 0.22)), 0.04, seed=22 + s)
    rbox(head, V((s * 1.62, 1.52, -0.1)), V((0.04, 0.11, 0.11)), 0.03, seed=24 + s)

# The brow: a heavy ridge, furrowed down at the middle, overhanging the eyes.
def brow(q, u):
    q = q + V((0, -0.05 * (1 - min(1.0, abs(u.x))) ** 2, 0))
    if u.y < 0 and u.z < 0:
        q = q + V((0, 0, -0.06 * (-u.y) * (-u.z)))
    # Each half arched a little over its eye.
    q = q + V((0, 0.025 * math.exp(-((abs(q.x) - 0.5) / 0.3) ** 2), 0))
    return q


rbox(head, V((0, 2.12, -1.13)), V((1.06, 0.13, 0.24)), 0.1, shape=brow, chunks=2, seed=26)

# The eyes: heavy upper lids drooping at the outer corners, thin lower lids,
# the eyeballs (their own object) set back between them.
EYE_X = 0.5
EYE_Y = 1.76
for s in (-1, 1):
    def lid(q, u, s=s):
        out = u.x * s  # +1 at the outer corner
        q = q + V((0, -0.05 * max(0.0, out) ** 2 + 0.02 * (1 - u.x * u.x), 0))
        if u.z < 0: q = q + V((0, 0, -0.02 * (1 - u.x * u.x)))
        return q
    rbox(head, V((s * EYE_X, EYE_Y + 0.105, -1.2)), V((0.29, 0.065, 0.1)), 0.055, shape=lid, seed=30 + s)
    def low(q, u, s=s):
        return q + V((0, 0.02 * u.x * u.x, 0))
    rbox(head, V((s * EYE_X, EYE_Y - 0.1, -1.18)), V((0.26, 0.04, 0.07)), 0.035, shape=low, seed=32 + s)
    def ball(q, u, s=s):
        # Almond: its ends pinched.
        return V((q.x, q.y * (1 - 0.55 * u.x * u.x), q.z))
    rbox(eyes, V((s * EYE_X, EYE_Y, -1.19)), V((0.24, 0.09, 0.07)), 0.06, mat="eye", shape=ball, wear=0.4, seed=34 + s)

# The nose: broad and flat, narrow at the bridge and spreading to wide
# nostril wings, its tip forward of the lips.
def nose(q, u):
    t = (u.y + 1) * 0.5  # 0 at the foot, 1 at the bridge
    q = V((q.x * (1.0 - 0.5 * t), q.y, q.z))
    if u.z < 0:
        q = q + V((0, 0, (0.14 * (1 - t) - 0.06 * t) * (-u.z)))
    return q


rbox(head, V((0, 1.66, -1.33)), V((0.46, 0.36, 0.2)), 0.12, shape=nose, seed=36)
for s in (-1, 1):
    rbox(head, V((s * 0.42, 1.39, -1.37)), V((0.13, 0.1, 0.13)), 0.09, seed=37 + s)
    # The nostrils: dark, under the wings.
    rbox(maw, V((s * 0.22, 1.3, -1.42)), V((0.08, 0.025, 0.05)), 0.02, mat="maw", wear=0.0, seed=39 + s)

# The upper lip: thick, wide, its corners turned down, a dip at its middle.
def upper_lip(q, u):
    q = q + V((0, -0.09 * u.x * u.x, 0))
    if u.z < 0: q = q + V((0, 0, -0.06 * (1 - u.x * u.x) * (-u.z)))
    if u.y > 0: q = q + V((0, -0.025 * math.exp(-(q.x / 0.09) ** 2) * u.y, 0))
    return q


rbox(head, V((0, 1.11, -1.3)), V((0.74, 0.13, 0.24)), 0.11, shape=upper_lip, seed=41)

# The maw: the dark throat behind the lips, seen through their parting and
# when the jaw drops.
rbox(maw, V((0, 0.68, -0.45)), V((0.68, 0.34, 0.78)), 0.12, mat="maw", wear=0.0, seed=42)

# ------------------------------------------------------------------ the jaw
# The bottom course, narrower at its foot; the lower lip pouting, its
# corners down; the chin a square boss.
def jaw_block(q, u):
    q = V((q.x * (0.86 + 0.14 * smooth01(-1.0, 0.5, u.y)), q.y, q.z))
    if u.z < 0:
        q = q + V((0, 0, -0.05 * (1 - u.x * u.x) * (-u.z)))
        # The chin: a broad square swell under the lip.
        chin = smooth01(0.75, 0.35, abs(u.x)) * smooth01(-1.0, -0.5, u.y) * smooth01(0.6, 0.0, u.y)
        q = q + V((0, 0, -0.1 * chin * (-u.z) ** 2))
    return q


rbox(jaw, V((0, 0.4, 0.0)), V((1.22, 0.4, 1.1)), 0.08, shape=jaw_block, chunks=2, seed=44)


def lower_lip(q, u):
    q = q + V((0, -0.07 * u.x * u.x, 0))
    if u.z < 0: q = q + V((0, 0, -0.07 * (1 - u.x * u.x) * (-u.z)))
    if u.y < 0: q = q + V((0, 0, -0.03 * (1 - u.x * u.x)))
    return q


rbox(jaw, V((0, 0.8, -1.3)), V((0.64, 0.13, 0.24)), 0.11, shape=lower_lip, seed=45)


# ------------------------------------------------------------------ to Blender
def make_object(part, origin=V((0, 0, 0))):
    me = bpy.data.meshes.new(part.name)
    bm = bmesh.new()
    vs = [bm.verts.new(G(p - origin)) for p in part.verts]
    bm.verts.ensure_lookup_table()
    names = sorted(set(part.mats))
    for f, m in zip(part.faces, part.mats):
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
    for n in names: me.materials.append(materials[n])
    ob = bpy.data.objects.new(part.name, me)
    ob.location = G(origin)
    scene.collection.objects.link(ob)
    return ob


head_ob = make_object(head)
jaw_ob = make_object(jaw, HINGE)
eyes_ob = make_object(eyes)
maw_ob = make_object(maw)
mouth = bpy.data.objects.new("Mouth", None)
mouth.location = G(MOUTH)
scene.collection.objects.link(mouth)
meshes = [head_ob, jaw_ob, eyes_ob, maw_ob]

# ------------------------------------------------------------------ occlusion
# Baked into COLOR_0 (Cycles, the parts occluding each other), the jaw shut.
for ob in meshes:
    attr = ob.data.color_attributes.new("AO", "BYTE_COLOR", "POINT")
    ob.data.color_attributes.active_color = attr
    try:
        ob.data.color_attributes.render_color_index = ob.data.color_attributes.active_color_index
    except Exception:
        pass
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.device = "CPU"
world = bpy.data.worlds.new("World")
scene.world = world
scene.render.bake.use_selected_to_active = False
bpy.ops.object.select_all(action="DESELECT")
for ob in meshes: ob.select_set(True)
bpy.context.view_layer.objects.active = head_ob
try:
    scene.world.light_settings.distance = 0.9
except Exception:
    pass
bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
print("INHALER_BAKED")
for ob in meshes:
    vals = [d.color[0] for d in ob.data.color_attributes["AO"].data]
    print("INHALER_AO", ob.name, round(min(vals), 3), round(sum(vals) / len(vals), 3), round(max(vals), 3))

tris = 0
for ob in meshes:
    n = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    tris += n
    print("INHALER_TRIS", ob.name, n)
print("INHALER_TRIS total", tris)
lo = V((min(v.co.x for v in head_ob.data.vertices), min(v.co.y for v in head_ob.data.vertices), min(v.co.z for v in head_ob.data.vertices)))
hi = V((max(v.co.x for v in head_ob.data.vertices), max(v.co.y for v in head_ob.data.vertices), max(v.co.z for v in head_ob.data.vertices)))
print("INHALER_BOUNDS head (blender)", tuple(round(c, 2) for c in lo), tuple(round(c, 2) for c in hi))

if SAVE_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "inhaler_head.blend"))

bpy.ops.object.select_all(action="DESELECT")
for ob in meshes + [mouth]: ob.select_set(True)
bpy.context.view_layer.objects.active = head_ob
GLB.parent.mkdir(parents=True, exist_ok=True)
kw = dict(filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
          export_apply=False, export_animations=False, export_materials="EXPORT",
          export_normals=True, export_extras=False)
try:
    bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE")
except TypeError:
    bpy.ops.export_scene.gltf(**kw, export_colors=True)
print("INHALER_EXPORTED", GLB)

# ------------------------------------------------------------------ a still
if RENDER:
    jaw_ob.rotation_euler = (-OPEN, 0, 0)  # Blender's X: the front (-Y... +Y) drops
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    target = G(V((0, 1.6, 0)))
    cam.location = G(V((-4.6, 2.6, -8.2)))
    d = target - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = RENDER
    bpy.ops.render.render(write_still=True)
    print("INHALER_RENDERED", RENDER)
