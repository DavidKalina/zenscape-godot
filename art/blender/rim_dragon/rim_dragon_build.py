"""Build the rim dragon (scripts/rim_dragon.gd, docs/design/rim-dragon.md): a
giant sentinel that grips an island's rim with its claws and rears its head
over the edge, wings arching up behind. Only the head, the neck, the two
clawed forelimbs and the wings are made; the body stays out of sight under
the rim (a chest blob closes the neck, arms and wings off down there).

The look is the Ruined Kingdom dragon's in Mario Odyssey translated into
this game: dark basalt-violet hide, a heavy brow with horns swept back, a
ridged scaly snout, ivory fangs over red gums. Each fleshy part is an
organic metaball union (skull, brow, cheeks, snout, nostrils; the jaw a
trough round the tongue) turned into a mesh, sculpted with two displaces
(lumps, then scale plates from a Voronoi crackle), decimated into
irregular facets and flat shaded, so it reads carved rather than blocky.
Horns, teeth and claws are swept, ringed tubes and curved cones.

Rig (rigid parts weighted by distance to their bones, so the neck and
limbs bend smoothly):
  root                    the rim's lip, between the claws
  neck.0 neck.1 neck.2    the neck, up out of the chest under the rim
  head                    the skull, its head at the occiput, pointing forward
  jaw                     the lower jaw, its head at the hinge
  upper_arm.L/R forearm.L/R hand.L/R   the forelimbs, the hands on the rim
  wing.L/R wing_tip.L/R   the wings, shoulder to wrist and wrist to tip
Every bone's local X is the dragon's right in rest (wings: local Z up), so
a turn about X pitches. No clips: the game poses the bones.

Conventions: 1 unit = 1 m. Blender Z up, facing +Y (the glTF exporter turns
that into Godot's -Z). The origin is on the rim's lip midway between the
hands; the island lies ahead (+Y), the drop behind and below. In rest the
head stands reared and level, the jaw shut.

    /opt/homebrew/bin/blender -b --python art/blender/rim_dragon/rim_dragon_build.py [-- DIR]

Writes art/blender/rim_dragon/rim_dragon.blend and assets/models/rim_dragon.glb
(or both into DIR), printing DRAGON_TRIS and each part's count.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BLEND = HERE / "rim_dragon.blend"
GLB = ROOT / "assets/models/rim_dragon.glb"
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if _args:
    BLEND, GLB = Path(_args[0]) / "rim_dragon.blend", Path(_args[0]) / "rim_dragon.glb"

rng = random.Random(7)

# ------------------------------------------------------------------ palette
# The game paints by material name (scripts/rim_dragon.gd keeps its own
# glossy versions); these are for Blender's stills.
PALETTE = {
    "dragon_hide": ("2b2236", 0.3),
    "dragon_horn": ("3a3340", 0.45),
    "dragon_tooth": ("e8dcc0", 0.35),
    "dragon_gum": ("9a2a2e", 0.25),
    "dragon_tongue": ("7a2430", 0.3),
    "dragon_eye": ("d9a441", 0.2),
    "dragon_membrane": ("231c2c", 0.55),
    "dragon_claw": ("1e1a22", 0.3),
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
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
    materials[key] = m

# ------------------------------------------------------------------ skeleton
V = Vector
HEAD0 = V((0.0, -1.0, 6.0))          # the occiput in rest
HINGE = HEAD0 + V((0.0, 1.4, -1.3))  # the jaw's hinge
BONES = {
    "root": (V((0, 0, 0)), V((0, 1.0, 0)), None),
    "neck.0": (V((0, -6.0, -9.0)), V((0, -4.8, -3.6)), "root"),
    "neck.1": (V((0, -4.8, -3.6)), V((0, -3.2, 1.6)), "neck.0"),
    "neck.2": (V((0, -3.2, 1.6)), HEAD0.copy(), "neck.1"),
    "head": (HEAD0.copy(), HEAD0 + V((0, 4.0, 0)), "neck.2"),
    "jaw": (HINGE.copy(), HINGE + V((0, 4.0, 0)), "head"),
}
for n, s in (("L", -1.0), ("R", 1.0)):
    sh, el, wr = V((6.0 * s, -6.0, -8.0)), V((10.0 * s, -3.6, -3.4)), V((9.0 * s, 0.6, 0.9))
    BONES[f"upper_arm.{n}"] = (sh, el, "root")
    BONES[f"forearm.{n}"] = (el, wr, f"upper_arm.{n}")
    BONES[f"hand.{n}"] = (wr, V((9.0 * s, 3.6, 0.5)), f"forearm.{n}")
    ws, ww, wt = V((4.0 * s, -8.0, -3.0)), V((15.0 * s, -12.0, 9.0)), V((26.0 * s, -16.0, 14.0))
    BONES[f"wing.{n}"] = (ws, ww, "root")
    BONES[f"wing_tip.{n}"] = (ww, wt, f"wing.{n}")
ORDER = list(BONES)

arm_data = bpy.data.armatures.new("DragonRig")
rig = bpy.data.objects.new("DragonRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for name in ORDER:
    head, tail, parent = BONES[name]
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = head, tail
    along = (tail - head).normalized()
    if name.startswith("wing"):
        eb.align_roll(V((0, 0, 1)) - along * along.z)     # local Z = up
    else:
        eb.align_roll(V((1, 0, 0)).cross(along))         # local X = right
    eb.use_deform = name != "root"
    if parent:
        eb.parent = arm_data.edit_bones[parent]
        eb.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")

def segment_distance(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length

# ------------------------------------------------------------------ helpers
parts = []

def finish(me, mat_of_face, weights, name):
    """Mesh `me` (faces' material keys from `mat_of_face`, a key or a
    function of the face's centre) as a part, weighted: `weights` a bone
    name (rigid) or a list of bones (by distance to each, the nearest two
    blended)."""
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    keys = []
    for poly in me.polygons:
        key = mat_of_face if isinstance(mat_of_face, str) else mat_of_face(poly.center)
        if key not in keys:
            keys.append(key)
            ob.data.materials.append(materials[key])
        poly.material_index = keys.index(key)
        poly.use_smooth = False
    if isinstance(weights, str):
        ob.vertex_groups.new(name=weights).add(range(len(me.vertices)), 1.0, "REPLACE")
    else:
        groups = {b: ob.vertex_groups.new(name=b) for b in weights}
        for v in me.vertices:
            d = sorted((segment_distance(v.co, BONES[b][0], BONES[b][1]), b) for b in weights)
            near = d[:2]
            if len(near) == 1 or near[1][0] - near[0][0] > 2.5:
                groups[near[0][1]].add([v.index], 1.0, "REPLACE")
                continue
            # Blend over 2.5 m round the seam between the two nearest.
            w0 = 0.5 + 0.5 * min(1.0, (near[1][0] - near[0][0]) / 2.5)
            groups[near[0][1]].add([v.index], w0, "REPLACE")
            groups[near[1][1]].add([v.index], 1.0 - w0, "REPLACE")
    parts.append(ob)
    print(f"DRAGON_PART {name} tris={sum(len(p.vertices) - 2 for p in me.polygons)}")
    return ob

def metaball_mesh(name, elements, resolution=0.2, threshold=0.6):
    """The surface of `elements` ([(centre, size xyz, rotation euler or
    None, negative)]), as a mesh."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = threshold
    for co, size, rot, neg in elements:
        el = mb.elements.new(type="ELLIPSOID")
        el.co = co
        # At stiffness 2 and threshold 0.6 a lone element's surface stands
        # at 0.574 radius x size, so this radius makes `size` its half
        # extents (overlapping ones swell and blend).
        el.radius = 1.0 / 0.574
        el.stiffness = 2.0
        el.size_x, el.size_y, el.size_z = size
        if rot is not None:
            el.rotation = rot.to_quaternion() if hasattr(rot, "to_quaternion") else rot
        el.use_negative = neg
    ob = bpy.data.objects.new(name, mb)
    scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    return me

def sculpt(me, name, target_tris, lump=0.25, lump_size=1.6, scale=0.12, scale_size=0.55):
    """Lumps, scale plates and irregular facets on `me`."""
    ob = bpy.data.objects.new(name + "_tmp", me)
    scene.collection.objects.link(ob)
    clouds = bpy.data.textures.new(name + "_lumps", "CLOUDS")
    clouds.noise_scale = lump_size
    clouds.noise_depth = 2
    d1 = ob.modifiers.new("lumps", "DISPLACE")
    d1.texture = clouds
    d1.texture_coords = "GLOBAL"
    d1.strength = lump
    vor = bpy.data.textures.new(name + "_scales", "VORONOI")
    vor.noise_scale = scale_size
    vor.distance_metric = "DISTANCE"
    vor.weight_1 = 1.0
    vor.weight_2 = 0.0
    d2 = ob.modifiers.new("scales", "DISPLACE")
    d2.texture = vor
    d2.texture_coords = "GLOBAL"
    d2.strength = -scale
    d2.mid_level = 0.3
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    if tris > target_tris:
        dec = ob.modifiers.new("facets", "DECIMATE")
        dec.ratio = target_tris / tris
    tri = ob.modifiers.new("tri", "TRIANGULATE")
    dg = bpy.context.evaluated_depsgraph_get()
    out = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    return out

def tube_mesh(points, sides=10, ridges=0.0, ridge_every=0.5, tip=True, twist=0.0, step=0.12):
    """A tube through `points` ((point, radius) pairs) on a Catmull-Rom
    curve, ringed (radius swelling `ridges` every `ridge_every` m), closed
    at the start and drawn to a point at the end if `tip`."""
    pts = [p for p, _ in points]
    rad = [r for _, r in points]
    samples = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
        r1, r2 = rad[i], rad[i + 1]
        steps = max(3, int((p2 - p1).length / step))
        for k in range(steps):
            t = k / steps
            t2, t3 = t * t, t * t * t
            p = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            samples.append((p, r1 + (r2 - r1) * t))
    samples.append((pts[-1], rad[-1]))
    bm = bmesh.new()
    rings = []
    run = 0.0
    up = V((0, 0, 1))
    for i, (p, r) in enumerate(samples):
        if i > 0: run += (p - samples[i - 1][0]).length
        nxt = samples[min(i + 1, len(samples) - 1)][0]
        prv = samples[max(i - 1, 0)][0]
        d = (nxt - prv).normalized()
        side = d.cross(up)
        if side.length < 1e-4: side = d.cross(V((1, 0, 0)))
        side.normalize()
        nrm = side.cross(d).normalized()
        swell = 1.0 + ridges * (0.5 + 0.5 * math.cos(run / ridge_every * math.tau))
        rr = r * swell
        if tip and i == len(samples) - 1: rr = 0.0
        ring = []
        for k in range(sides):
            a = k / sides * math.tau + twist * run
            ring.append(bm.verts.new(p + (side * math.cos(a) + nrm * math.sin(a)) * rr))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    if not tip:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new("tube")
    bm.to_mesh(me)
    bm.free()
    return me

def merge(meshes, name):
    bm = bmesh.new()
    for me in meshes:
        bm.from_mesh(me)
    out = bpy.data.meshes.new(name)
    bm.to_mesh(out)
    bm.free()
    return out

def moved(me, m):
    me.transform(m)
    return me

def fang(base, down, length, radius, curl=0.25, sides=7):
    """A curved fang from `base` along `down`, curling back by `curl`."""
    back = V((0, -1, 0))
    pts = []
    for k in range(5):
        t = k / 4
        p = base + down * (length * t) + back * (curl * length * t * t)
        pts.append((p, radius * (1.0 - 0.85 * t) + 0.01))
    return tube_mesh(pts, sides=sides, tip=True)

# ================================================================== the head
# Head-local: the occiput at the origin, +Y forward, +Z up (rest = world
# offset by HEAD0).
H = lambda x, y, z: HEAD0 + V((x, y, z))
E = lambda x, y, z: __import__("mathutils").Euler((math.radians(x), math.radians(y), math.radians(z)))

skull = [
    (H(0, 1.6, 1.4), (3.6, 3.0, 2.9), None, False),       # the cranium
    (H(0, 0.0, 0.6), (2.8, 2.2, 2.6), None, False),       # the back of the head, into the neck
    (H(-2.2, 4.5, 2.5), (2.2, 1.7, 1.35), E(0, 12, -10), False),   # the brows, heavy
    (H(2.2, 4.5, 2.5), (2.2, 1.7, 1.35), E(0, -12, 10), False),
    (H(0, 4.6, 2.0), (1.4, 1.4, 1.0), None, False),       # between the brows
    (H(-3.3, 2.9, -0.3), (1.9, 2.6, 2.0), None, False),   # the cheeks
    (H(3.3, 2.9, -0.3), (1.9, 2.6, 2.0), None, False),
    (H(0, 6.4, 0.4), (3.0, 3.2, 1.75), None, False),      # the snout
    (H(0, 8.6, 0.2), (2.9, 1.5, 1.55), None, False),      # its end, broad
    (H(-1.4, 9.3, 1.0), (1.0, 0.95, 0.8), None, False),   # the nostrils' bulges
    (H(1.4, 9.3, 1.0), (1.0, 0.95, 0.8), None, False),
    (H(0, 6.0, -0.9), (2.95, 4.0, 0.8), None, False),     # the upper jaw's underside
    (H(-1.3, 9.95, 1.15), (0.38, 0.35, 0.3), None, True), # the nostrils
    (H(1.3, 9.95, 1.15), (0.38, 0.35, 0.3), None, True),
    (H(-2.5, 5.7, 1.3), (0.8, 0.6, 0.5), None, True),     # the eye sockets under the brow
    (H(2.5, 5.7, 1.3), (0.8, 0.6, 0.5), None, True),
    (H(0, 5.6, -2.2), (3.2, 5.6, 1.1), None, True),       # the mouth's roof cut flat
]
# The snout's ridge: knuckles down its midline, and rows of bosses either side.
for k in range(8):
    t = k / 7
    skull.append((H(0, 4.9 + t * 4.4, 2.1 - t * 0.7), (0.55 - 0.2 * t, 0.5, 0.45), None, False))
    for s in (-1, 1):
        skull.append((H(s * (1.3 + 0.4 * math.sin(t * 3)), 5.2 + t * 4.0, 1.5 - t * 0.6), (0.4, 0.45, 0.35), None, False))
# The brow's crown: plates rising behind the brows, toward the horns.
for k in range(5):
    a = (k - 2) / 2
    skull.append((H(a * 2.2, 2.4 - abs(a) * 0.6, 3.6 - abs(a) * 0.5), (0.9, 0.9, 0.6), None, False))
# Cheek plates flaring back and out.
for s in (-1, 1):
    for k in range(3):
        skull.append((H(s * (3.9 + k * 0.3), 1.6 - k * 1.0, -0.6 + k * 0.2), (0.7, 0.9, 0.9 - k * 0.15), None, False))

def head_mat(c):
    return "dragon_hide"

head_me = sculpt(metaball_mesh("Skull", skull, 0.16), "skull", 22000, lump=0.22, scale=0.13, scale_size=0.5)
finish(head_me, head_mat, ["head", "neck.2"], "skull")

# The eyes, dark amber, sunk under the brows.
for s in (-1, 1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.3)
    me = bpy.data.meshes.new("eye")
    bm.to_mesh(me)
    bm.free()
    me.transform(Matrix.Translation(H(s * 2.45, 5.8, 1.25)) @ Matrix.Diagonal((1.0, 0.8, 0.7, 1.0)))
    finish(me, "dragon_eye", "head", "eye")

# The horns: a great pair swept back off the crown, a lesser pair off the cheeks.
horns = []
for s in (-1, 1):
    horns.append(tube_mesh([(H(s * 2.3, 2.6, 3.0), 1.15), (H(s * 3.1, 0.9, 4.4), 1.0), (H(s * 4.1, -1.6, 5.3), 0.8),
                            (H(s * 5.2, -4.0, 5.1), 0.55), (H(s * 6.0, -5.8, 4.0), 0.3), (H(s * 6.3, -6.6, 2.9), 0.1)],
                           sides=11, ridges=0.12, ridge_every=0.55))
    horns.append(tube_mesh([(H(s * 3.6, 1.6, 0.6), 0.6), (H(s * 4.6, -0.2, 0.9), 0.45), (H(s * 5.4, -2.0, 0.6), 0.25),
                            (H(s * 5.8, -3.0, 0.1), 0.06)], sides=9, ridges=0.12, ridge_every=0.45))
    # Spikes down the back of the head.
for k in range(4):
    horns.append(tube_mesh([(H(0, 0.6 - k * 1.1, 3.3 - k * 0.5), 0.45 - k * 0.06), (H(0, -0.4 - k * 1.1, 4.4 - k * 0.6), 0.2),
                            (H(0, -1.0 - k * 1.1, 4.8 - k * 0.6), 0.03)], sides=7))
finish(merge(horns, "horns"), "dragon_horn", "head", "horns")

# The upper teeth and gum, along the mouth's U.
def mouth_line(u, y0, ry, rx, z):
    """The mouth's U at u in [-1, 1] (left to right round the front)."""
    a = u * math.radians(100)
    return H(rx * math.sin(a), y0 + ry * math.cos(a), z)

UPPER_Z = -1.15
gum = [(mouth_line(u / 10.0, 4.6, 4.5, 2.55, UPPER_Z + 0.05), 0.32) for u in range(-10, 11)]
finish(tube_mesh(gum, sides=8, tip=False, step=0.3), "dragon_gum", "head", "upper_gum")
teeth = []
for i in range(17):
    u = -0.92 + i * (1.84 / 16)
    big = 1.0 if i in (3, 13) else (0.8 if i in (7, 9) else 0.55 + 0.15 * rng.random())
    p = mouth_line(u, 4.6, 4.5, 2.55, UPPER_Z - 0.2)
    teeth.append(fang(p, V((0, 0.15, -1)).normalized(), 1.25 * big, 0.28 * big ** 0.5, curl=0.18))
finish(merge(teeth, "upper_teeth"), "dragon_tooth", "head", "upper_teeth")

# ================================================================== the jaw
J = lambda x, y, z: HINGE + V((x, y, z))
jaw = [
    (J(0, 4.0, -1.4), (3.0, 4.4, 1.05), None, False),     # the mandible
    (J(0, 7.6, -1.3), (2.5, 1.3, 1.0), None, False),      # the chin
    (J(-2.5, 0.8, -0.6), (1.1, 1.6, 1.3), None, False),   # its back, to the hinge
    (J(2.5, 0.8, -0.6), (1.1, 1.6, 1.3), None, False),
    (J(0, 4.1, -0.2), (2.25, 4.0, 0.75), None, True),     # the trough
]
for s in (-1, 1):
    for k in range(4):
        jaw.append((J(s * (2.4 - k * 0.15), 1.5 + k * 1.6, -2.0), (0.5, 0.7, 0.45), None, False))   # jowl scales
jaw_me = sculpt(metaball_mesh("Jaw", jaw, 0.15), "jaw", 7000, lump=0.15, scale=0.1, scale_size=0.45)
finish(jaw_me, "dragon_hide", "jaw", "jaw")
tongue = metaball_mesh("Tongue", [(J(0, 4.0, -0.75), (1.6, 3.2, 0.42), None, False), (J(0, 6.8, -0.75), (1.0, 1.2, 0.35), None, False)], 0.15)
tongue = sculpt(tongue, "tongue", 1500, lump=0.05, scale=0.02, scale_size=0.4)
finish(tongue, "dragon_tongue", "jaw", "tongue")
LOWER_Z = -0.45
gum = [(J(2.4 * math.sin(u / 10 * math.radians(100)), 3.7 + 4.1 * math.cos(u / 10 * math.radians(100)), LOWER_Z - 0.1), 0.22) for u in range(-10, 11)]
finish(tube_mesh(gum, sides=8, tip=False, step=0.3), "dragon_gum", "jaw", "lower_gum")
teeth = []
for i in range(13):
    u = -0.9 + i * (1.8 / 12)
    a = u * math.radians(100)
    p = J(2.35 * math.sin(a), 3.7 + 4.1 * math.cos(a), LOWER_Z + 0.1)
    big = 1.0 if i in (2, 10) else 0.5 + 0.2 * rng.random()
    teeth.append(fang(p, V((0, 0.1, 1)).normalized(), 0.8 * big, 0.22 * big ** 0.5, curl=-0.15))
finish(merge(teeth, "lower_teeth"), "dragon_tooth", "jaw", "lower_teeth")

# ================================================================== neck, chest
neck = [(V((0, -7.0, -12.0)), (6.0, 4.5, 4.5), None, False)]     # the chest, out of sight
for k in range(14):
    t = k / 13
    # Up the neck's bones to the back of the head.
    pts = [BONES["neck.0"][0], BONES["neck.1"][0], BONES["neck.2"][0], HEAD0]
    seg = min(int(t * 3), 2)
    lt = t * 3 - seg
    p = pts[seg].lerp(pts[seg + 1], lt)
    r = 3.3 - 0.9 * t
    neck.append((p, (r, r * 0.9, r), None, False))
    # The throat's plates in front and the ridge behind.
    neck.append((p + V((0, r * 0.75, -0.3)), (r * 0.55, 0.6, 0.55), None, False))
    neck.append((p + V((0, -r * 0.85, 0.2)), (0.5, 0.5, 0.6), None, False))
neck_me = sculpt(metaball_mesh("Neck", neck, 0.22), "neck", 9000, lump=0.25, scale=0.13, scale_size=0.6)
finish(neck_me, "dragon_hide", ["neck.0", "neck.1", "neck.2", "head", "upper_arm.L", "upper_arm.R"], "neck")
spines = []
for k in range(7):
    t = (k + 0.5) / 7
    pts = [BONES["neck.0"][0], BONES["neck.1"][0], BONES["neck.2"][0], HEAD0]
    seg = min(int(t * 3), 2)
    p = pts[seg].lerp(pts[seg + 1], t * 3 - seg)
    r = 3.3 - 0.9 * t
    base = p + V((0, -r * 1.05, 0.3))
    spines.append(tube_mesh([(base, 0.5), (base + V((0, -1.2, 0.9)), 0.25), (base + V((0, -1.9, 1.3)), 0.03)], sides=7))
finish(merge(spines, "neck_spines"), "dragon_horn", ["neck.0", "neck.1", "neck.2"], "neck_spines")

# ================================================================== forelimbs
for n, s in (("L", -1.0), ("R", 1.0)):
    sh, el = BONES[f"upper_arm.{n}"][0], BONES[f"upper_arm.{n}"][1]
    wr, hand_end = BONES[f"hand.{n}"][0], BONES[f"hand.{n}"][1]
    els = []
    for k in range(9):
        t = k / 8
        els.append((sh.lerp(el, t), (1.9 - 0.4 * t,) * 3, None, False))
        els.append((el.lerp(wr, t), (1.5 - 0.35 * t,) * 3, None, False))
    els.append((el + V((s * 0.6, -0.6, 0.0)), (1.2, 1.2, 1.2), None, False))      # the elbow's knob
    # The hand: a heavy palm on the rim, its heel over the lip.
    palm = wr.lerp(hand_end, 0.35) + V((0, 0, 0.2))
    els.append((palm, (1.6, 1.5, 0.75), None, False))
    els.append((wr + V((0, 0, -0.1)), (1.3, 1.1, 1.0), None, False))
    arm_me = sculpt(metaball_mesh(f"Arm{n}", els, 0.18), f"arm{n}", 7000, lump=0.18, scale=0.12, scale_size=0.5)
    finish(arm_me, "dragon_hide", [f"upper_arm.{n}", f"forearm.{n}", f"hand.{n}"], f"arm.{n}")
    # Four fingers fanned over the turf, curling down into it at the ends,
    # each with a dark hooked claw; the thumb hooks under the lip.
    fingers, claws = [], []
    for f in range(4):
        spread = (f - 1.5) * 0.36
        d = V((math.sin(spread) * s * -1.0, math.cos(spread), 0.0))
        d = V((d.x, d.y, 0))
        if f == 3:
            # The thumb, round the lip and down the cliff.
            base = wr + V((-s * 1.2, 0.4, -0.2))
            pts = [(base, 0.55), (base + V((-s * 0.6, 0.3, -1.0)), 0.45), (base + V((-s * 0.8, -0.2, -1.9)), 0.35)]
            tipd = V((0, -0.6, -1)).normalized()
        else:
            base = palm + d * 1.0 + V((0, 0, 0.1))
            k1 = base + d * 1.3 + V((0, 0, 0.35))
            k2 = k1 + d * 1.2 + V((0, 0, -0.35))
            k3 = k2 + d * 0.8 + V((0, 0, -0.45))
            pts = [(base, 0.62), (k1, 0.52), (k2, 0.42), (k3, 0.34)]
            tipd = (d * 0.4 + V((0, 0, -1))).normalized()
        fingers.append(tube_mesh(pts, sides=9, ridges=0.15, ridge_every=0.5, tip=False))
        end = pts[-1][0]
        claw_pts = [(end, 0.33), (end + tipd * 0.6 + d * 0.3, 0.22), (end + tipd * 1.2, 0.08), (end + tipd * 1.45 - d * 0.15, 0.01)]
        claws.append(tube_mesh(claw_pts, sides=8))
    fm = sculpt(merge(fingers, "fingers"), f"fingers{n}", 4000, lump=0.04, scale=0.05, scale_size=0.35)
    finish(fm, "dragon_hide", f"hand.{n}", f"fingers.{n}")
    finish(merge(claws, "claws"), "dragon_claw", f"hand.{n}", f"claws.{n}")

# ================================================================== wings
def loft_panel(bm, a0, a1, b0, b1, scallop, billow, nu=8, nv=6):
    """A membrane panel between spokes a0->a1 and b0->b1, its outer edge
    (a1 to b1) scalloped in toward the spokes' roots by `scallop`, billowed
    `billow` along its normal."""
    n = (a1 - a0).cross(b1 - b0)
    n = n.normalized() if n.length > 1e-6 else V((0, 0, 1))
    grid = []
    for i in range(nu + 1):
        s = i / nu
        row = []
        for j in range(nv + 1):
            t = j / nv
            a = a0.lerp(a1, s)
            b = b0.lerp(b1, s)
            p = a.lerp(b, t)
            pull = scallop * math.sin(math.pi * t) * s ** 3
            root = a0.lerp(b0, t)
            p = p.lerp(root, pull)
            p += n * billow * math.sin(math.pi * t) * math.sin(math.pi * min(s, 1.0) * 0.9)
            row.append(bm.verts.new(p))
        grid.append(row)
    for i in range(nu):
        for j in range(nv):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))

for n, s in (("L", -1.0), ("R", 1.0)):
    ws, ww = BONES[f"wing.{n}"][0], BONES[f"wing.{n}"][1]
    wt = BONES[f"wing_tip.{n}"][1]
    # The fingers off the wrist: the leading one to the tip, three fanned
    # down and back, and the body's edge.
    tips = [wt,
            ww + V((s * 9.0, -6.0, -2.0)),
            ww + V((s * 6.0, -7.5, -7.0)),
            ww + V((s * 2.5, -6.0, -11.0))]
    body_edge = ws + V((s * 0.5, -3.5, -5.0))
    bones_mesh = [tube_mesh([(ws, 1.1), (ws.lerp(ww, 0.5) + V((0, 0, 0.6)), 0.85), (ww, 0.7)], sides=10, ridges=0.04, ridge_every=0.8, tip=False),
                  tube_mesh([(ww, 0.75), (ww + V((-s * 0.3, 0.9, 1.0)), 0.55), (ww + V((-s * 0.2, 1.6, 1.6)), 0.05)], sides=8)]   # the wrist's hook
    for k, tip in enumerate(tips):
        mid = ww.lerp(tip, 0.5) + V((0, 0, 0.6 if k == 0 else 0.0))
        bones_mesh.append(tube_mesh([(ww, 0.55 if k == 0 else 0.4), (mid, 0.35 if k == 0 else 0.25), (tip, 0.04)], sides=8, ridges=0.03, ridge_every=0.9))
    bm_ = sculpt(merge(bones_mesh, "wing_bones"), f"wingbones{n}", 5000, lump=0.05, scale=0.05, scale_size=0.4)
    finish(bm_, "dragon_hide", [f"wing.{n}", f"wing_tip.{n}"], f"wing_bones.{n}")
    bm = bmesh.new()
    spokes = tips + [body_edge]
    for k in range(len(spokes) - 1):
        loft_panel(bm, ww, spokes[k], ww, spokes[k + 1], 0.22, 0.5 * s * -1.0)
    # The inner panel: shoulder to wrist to the body's edge.
    loft_panel(bm, ws, ww, ws, body_edge, 0.05, 0.4 * s * -1.0, nu=6, nv=6)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    # Two-sided: a back face for every face.
    back = bmesh.ops.duplicate(bm, geom=bm.faces[:])
    bmesh.ops.reverse_faces(bm, faces=[g for g in back["geom"] if isinstance(g, bmesh.types.BMFace)])
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new("membrane")
    bm.to_mesh(me)
    bm.free()
    finish(me, "dragon_membrane", [f"wing.{n}", f"wing_tip.{n}"], f"membrane.{n}")

# ================================================================== join
bpy.ops.object.select_all(action="DESELECT")
for ob in parts:
    ob.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = body.data.name = "RimDragon"
by_name = {}
for i, slot in enumerate(body.material_slots):
    by_name.setdefault(slot.material.name.split(".")[0], []).append(i)
keep = {k: v[0] for k, v in by_name.items()}
remap = {i: keep[k] for k, v in by_name.items() for i in v}
for poly in body.data.polygons:
    poly.material_index = remap[poly.material_index]
    poly.use_smooth = False
bpy.ops.object.material_slot_remove_unused()
body.parent = rig
body.modifiers.new("Rig", "ARMATURE").object = rig
lo = V((min(v.co.x for v in body.data.vertices), min(v.co.y for v in body.data.vertices), min(v.co.z for v in body.data.vertices)))
hi = V((max(v.co.x for v in body.data.vertices), max(v.co.y for v in body.data.vertices), max(v.co.z for v in body.data.vertices)))
print("DRAGON_TRIS", sum(len(p.vertices) - 2 for p in body.data.polygons), "bounds", tuple(round(c, 2) for c in lo), tuple(round(c, 2) for c in hi))
for b in ("head", "jaw"):
    vs = [v.co for v in body.data.vertices if any(body.vertex_groups[g.group].name == b and g.weight > 0.5 for g in v.groups)]
    print(f"DRAGON_BOUNDS {b} z {min(c.z for c in vs):.2f}..{max(c.z for c in vs):.2f} y {min(c.y for c in vs):.2f}..{max(c.y for c in vs):.2f} x {min(c.x for c in vs):.2f}..{max(c.x for c in vs):.2f}")

# ================================================================== save, export
BLEND.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = rig
GLB.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
    export_apply=False, export_animations=False, export_materials="EXPORT",
    export_normals=True, export_extras=False, export_def_bones=False)
print("DRAGON_EXPORTED", GLB)
