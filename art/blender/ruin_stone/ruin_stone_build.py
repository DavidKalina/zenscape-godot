"""Bake the ruins' stone tile (assets/textures/ruin_stone_normal.png, ruin_stone_mask.png).

Run: python tools/blender.py run art/blender/ruin_stone/ruin_stone_build.py [-- --seed=3 --tex=1024 --preview=scratch/ruin_stone]

A tile of coursed ashlar TILE m square: courses of cut blocks in a running
bond, each block bevelled, its arrises chipped (boolean bites), remeshed and
eroded with noise; a mortar bed sunk behind. The tile is laid 3x3 (each
block once, linked into the eight neighbours) so the centre tile's edges
see the same stone the next tile has: the bake tiles without a seam. Cycles
bakes the centre tile onto a plane: the height (EMIT), each block's tone
(EMIT, 0 the mortar) and the ambient occlusion (AO). The normal is taken
from the height here (numpy), so its convention is known:

  ruin_stone_normal.png  RGB: the normal, x along u (the image's columns,
                         rightward), y along v (its rows, UPWARD: Blender's
                         v), z out of the face; 0.5 is flat.
  ruin_stone_mask.png    R ambient occlusion (1 open), G height (0 the mortar
                         bed's floor, 1 the proudest face), B the block's tone
                         (0 mortar, 0.2..1 a block).

--preview=DIR also renders the 3x3 in a raking light (preview.png) to judge.
"""
import bpy
import bmesh
import mathutils
import math
import random
import sys
from pathlib import Path

import numpy as np

ARGS = dict(a[2:].split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:] if a.startswith("--") and "=" in a) if "--" in sys.argv else {}
SEED = int(ARGS.get("seed", "3"))
TEX = int(ARGS.get("tex", "1024"))
PREVIEW = ARGS.get("preview", "")

TILE = 2.4                 # m, the tile's side
COURSES = [0.62, 0.54, 0.66, 0.58]   # course heights (sum TILE)
LENGTH = (0.6, 1.3)        # a block's length
JOINT = 0.022              # the gap between blocks (m)
DEPTH = 0.32               # how deep a block runs back
BED = -0.045               # the mortar's face (m, behind the blocks' faces at 0)
H_LO, H_HI = -0.06, 0.025  # the height bake's range (m)
VOXEL = 0.011              # remesh size (m)

rng = random.Random(SEED)
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "textures"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def link(ob):
    scene.collection.objects.link(ob)
    return ob


def box(name, sx, sy, sz, at=(0, 0, 0)):
    """A box sx x sy x sz centred on `at`, as its own object."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    ob.location = at
    return ob


def flake(name, sx, sy, sz, at):
    """A lumpy ellipsoid sx x sy x sz (full sizes) at `at`: a chip's or a
    spall's bite, so the scar is a shell-shaped scoop, not a cut plane."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.5)
    for v in bm.verts:
        lump = 1.0 + 0.18 * mathutils.noise.noise(v.co * 3.0 + mathutils.Vector((rng.uniform(0, 50), 0, 0)))
        v.co.x *= sx * lump
        v.co.y *= sy * lump
        v.co.z *= sz * lump
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    ob.location = at
    return ob


def apply_all(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def noise_tex(name, kind, size, **kw):
    t = bpy.data.textures.new(name, kind)
    t.noise_scale = size
    for k, v in kw.items():
        setattr(t, k, v)
    return t


T_BIG = noise_tex("undulate", "CLOUDS", 0.35, noise_depth=2)
T_PIT = noise_tex("pits", "VORONOI", 0.05, distance_metric="DISTANCE")
T_GRAIN = noise_tex("grain", "CLOUDS", 0.012, noise_depth=1)
T_ERODE = noise_tex("erode", "CLOUDS", 0.09, noise_depth=3)


def block(name, x0, x1, y0, y1):
    """One cut block over [x0,x1] x [y0,y1] (its face near z 0), chipped and
    worn; its mesh offset by a random vector so its noise is its own."""
    w = (x1 - x0) - JOINT
    h = (y1 - y0) - JOINT
    proud = rng.uniform(-0.012, 0.006)
    ob = box(name, w, h, DEPTH)
    # A little out of true, turned about its own middle.
    tilt = mathutils.Euler((rng.uniform(-0.008, 0.008), rng.uniform(-0.008, 0.008), rng.uniform(-0.004, 0.004)))
    ob.data.transform(tilt.to_matrix().to_4x4())
    # Its own patch of the noise: the mesh moved by `shift`, the object back.
    shift = (rng.uniform(-40, 40), rng.uniform(-40, 40), rng.uniform(-40, 40))
    ob.data.transform(mathutils.Matrix.Translation(shift))
    ob.location = (0.5 * (x0 + x1) - shift[0], 0.5 * (y0 + y1) - shift[1], proud - DEPTH * 0.5 - shift[2])
    # Bevel: the worn arris, wider on some blocks.
    bv = ob.modifiers.new("bevel", "BEVEL")
    bv.width = rng.uniform(0.02, 0.07)
    bv.segments = 3
    bv.limit_method = "NONE"
    apply_all(ob)
    # Chips: bites out of the front arrises and corners.
    cx, cy = 0.5 * (x0 + x1), 0.5 * (y0 + y1)
    for k in range(rng.randint(3, 8)):
        edge = rng.random()
        if edge < 0.5:   # along a long (top or bottom) arris
            px = cx + rng.uniform(-0.45, 0.45) * w
            py = cy + (0.5 if rng.random() < 0.5 else -0.5) * h
        else:            # along a short (side) arris
            px = cx + (0.5 if rng.random() < 0.5 else -0.5) * w
            py = cy + rng.uniform(-0.45, 0.45) * h
        s = rng.uniform(0.05, 0.17) * (1.8 if rng.random() < 0.2 else 1.0)
        bite = flake(f"{name}_chip{k}", s * 1.4, s * rng.uniform(0.8, 1.5), s * 0.9, (px, py, proud + rng.uniform(-0.01, 0.03)))
        bite.rotation_euler = (rng.uniform(0, 6.3), rng.uniform(0, 6.3), rng.uniform(0, 6.3))
        bo = ob.modifiers.new(f"chip{k}", "BOOLEAN")
        bo.operation = "DIFFERENCE"
        bo.solver = "EXACT"
        bo.object = bite
        apply_all(ob)
        bpy.data.objects.remove(bite)
    # Spalls: now and then a shallow flake gone off the face.
    for k in range(2 if rng.random() < 0.3 else (1 if rng.random() < 0.4 else 0)):
        sw, sh = rng.uniform(0.15, 0.4) * w, rng.uniform(0.25, 0.6) * h
        sp = flake(f"{name}_spall{k}", sw, sh, 0.08, (cx + rng.uniform(-0.3, 0.3) * w, cy + rng.uniform(-0.3, 0.3) * h, proud + 0.04 - rng.uniform(0.006, 0.016)))
        sp.rotation_euler = (rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), rng.uniform(0, 6.3))
        bo = ob.modifiers.new(f"spall{k}", "BOOLEAN")
        bo.operation = "DIFFERENCE"
        bo.solver = "EXACT"
        bo.object = sp
        apply_all(ob)
        bpy.data.objects.remove(sp)
    rm = ob.modifiers.new("remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = VOXEL
    apply_all(ob)
    # Erosion: broad undulation, softened arrises eaten in (stronger noise
    # pulled along the normals), pits and a fine grain.
    for tex, strength, mid in ((T_BIG, rng.uniform(0.003, 0.008), 0.5),
                               (T_ERODE, rng.uniform(0.004, 0.01), 0.6),
                               (T_PIT, rng.uniform(0.0008, 0.002), 0.0),
                               (T_GRAIN, 0.0008, 0.5)):
        d = ob.modifiers.new(tex.name, "DISPLACE")
        d.texture = tex
        d.texture_coords = "LOCAL"
        d.strength = strength
        d.mid_level = mid
    apply_all(ob)
    ob.color = (rng.uniform(0.2, 1.0), 0, 0, 1)
    return ob


# The centre tile's blocks: courses in a running bond, wrapping round TILE.
blocks = []
y = 0.0
for ci, ch in enumerate(COURSES):
    start = rng.uniform(0, TILE)
    cuts = [start]
    while True:
        nxt = cuts[-1] + rng.uniform(*LENGTH)
        if nxt >= start + TILE - LENGTH[0] * 0.8:
            cuts.append(start + TILE)
            break
        cuts.append(nxt)
    for k in range(len(cuts) - 1):
        blocks.append(block(f"b{ci}_{k}", cuts[k] - TILE * (1 if cuts[k] >= TILE else 0),
                            cuts[k + 1] - TILE * (1 if cuts[k] >= TILE else 0), y, y + ch))
    y += ch
print("RUIN_STONE blocks", len(blocks), "tris", sum(len(b.data.polygons) for b in blocks))

# The mortar bed, three tiles each way.
bed = box("bed", TILE * 3, TILE * 3, 0.02, (TILE * 0.5, TILE * 0.5, BED - 0.01))
bpy.context.view_layer.objects.active = bed
sd = bed.modifiers.new("sub", "SUBSURF")
sd.subdivision_type = "SIMPLE"
sd.levels = 7
sd.render_levels = 7
dm = bed.modifiers.new("rough", "DISPLACE")
dm.texture = T_ERODE
dm.texture_coords = "GLOBAL"
dm.strength = 0.01
apply_all(bed)
bed.color = (0, 0, 0, 1)

# The neighbours: each block linked in eight times, a tile over.
high = [bed] + blocks
for b in blocks:
    for i in (-1, 0, 1):
        for j in (-1, 0, 1):
            if i == 0 and j == 0:
                continue
            c = b.copy()
            c.location = (b.location.x + i * TILE, b.location.y + j * TILE, b.location.z)
            link(c)
            high.append(c)

# ------------------------------------------------------------------ the bake
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (1, 1, 1, 1)
world.light_settings.distance = 0.25

hm = bpy.data.materials.new("stone_high")
hm.use_nodes = True
nt = hm.node_tree
nt.nodes.clear()
geo = nt.nodes.new("ShaderNodeNewGeometry")
sep = nt.nodes.new("ShaderNodeSeparateXYZ")
rmap = nt.nodes.new("ShaderNodeMapRange")
rmap.inputs["From Min"].default_value = H_LO
rmap.inputs["From Max"].default_value = H_HI
info = nt.nodes.new("ShaderNodeObjectInfo")
em = nt.nodes.new("ShaderNodeEmission")
df = nt.nodes.new("ShaderNodeBsdfDiffuse")
df.inputs["Color"].default_value = (0.55, 0.5, 0.42, 1)
add = nt.nodes.new("ShaderNodeAddShader")
out = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(geo.outputs["Position"], sep.inputs[0])
nt.links.new(sep.outputs["Z"], rmap.inputs["Value"])
nt.links.new(em.outputs[0], add.inputs[0])
nt.links.new(df.outputs[0], add.inputs[1])
nt.links.new(add.outputs[0], out.inputs["Surface"])
for ob in high:
    if ob.data.materials:
        ob.data.materials[0] = hm
    else:
        ob.data.materials.append(hm)


def emit(source):
    for l in list(em.inputs["Color"].links):
        nt.links.remove(l)
    nt.links.new(source, em.inputs["Color"])


me = bpy.data.meshes.new("low")
bm = bmesh.new()
uvl = bm.loops.layers.uv.new()
vs = [bm.verts.new(p) for p in ((0, 0, 0), (TILE, 0, 0), (TILE, TILE, 0), (0, TILE, 0))]
f = bm.faces.new(vs)
for loop, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
    loop[uvl].uv = uv
bm.to_mesh(me)
bm.free()
low = link(bpy.data.objects.new("low", me))
lm = bpy.data.materials.new("stone_low")
lm.use_nodes = True
target = lm.node_tree.nodes.new("ShaderNodeTexImage")
lm.node_tree.nodes.active = target
low.data.materials.append(lm)


def bake(kind, samples):
    img = bpy.data.images.new(kind, TEX, TEX, alpha=False, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    target.image = img
    scene.cycles.samples = samples
    bpy.ops.object.select_all(action="DESELECT")
    for ob in high:
        ob.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type="AO" if kind == "ao" else "EMIT", use_selected_to_active=True,
                        cage_extrusion=0.12, max_ray_distance=0.3, margin=0)
    px = np.empty(TEX * TEX * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    print("RUIN_STONE baked", kind)
    return px.reshape(TEX, TEX, 4)[:, :, 0].copy()   # [v, u], v upward


emit(rmap.outputs[0])
height = bake("height", 1)
emit(info.outputs["Color"])
tone = bake("tone", 1)
ao = bake("ao", 96)

# The normal from the height (metres), wrapping round the tile.
hm_m = H_LO + height * (H_HI - H_LO)
step = TILE / TEX
du = (np.roll(hm_m, -1, axis=1) - np.roll(hm_m, 1, axis=1)) / (2 * step)
dv = (np.roll(hm_m, -1, axis=0) - np.roll(hm_m, 1, axis=0)) / (2 * step)
n = np.stack([-du, -dv, np.ones_like(du)], axis=-1)
n /= np.linalg.norm(n, axis=-1, keepdims=True)
h01 = (height - height.min()) / max(1e-6, height.max() - height.min())


def save(name, rgb):
    img = bpy.data.images.new(name, TEX, TEX, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    px = np.ones((TEX, TEX, 4), dtype=np.float32)
    px[:, :, :3] = np.clip(rgb, 0, 1)
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = str(OUT / f"{name}.png")
    img.file_format = "PNG"
    scene.render.image_settings.color_depth = "8"
    img.save()
    print("RUIN_STONE saved", img.filepath_raw)


OUT.mkdir(parents=True, exist_ok=True)
save("ruin_stone_normal", n * 0.5 + 0.5)
save("ruin_stone_mask", np.stack([ao, h01, tone], axis=-1))

if PREVIEW:
    pdir = (ROOT / PREVIEW)
    pdir.mkdir(parents=True, exist_ok=True)
    nt.links.remove(add.inputs[0].links[0])
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 4.0
    so = link(bpy.data.objects.new("sun", sun))
    so.rotation_euler = (math.radians(68), 0, math.radians(35))
    bg.inputs[1].default_value = 0.25
    cam = bpy.data.cameras.new("cam")
    cam.lens = 35
    co = link(bpy.data.objects.new("cam", cam))
    co.location = (TILE * 0.5 - 1.2, TILE * 0.5 - 3.6, 2.6)
    co.rotation_euler = (math.radians(52), 0, math.radians(-18))
    scene.camera = co
    scene.render.resolution_x, scene.render.resolution_y = 900, 600
    scene.cycles.samples = 32
    low.hide_render = True
    scene.render.filepath = str(pdir / "preview.png")
    bpy.ops.render.render(write_still=True)
    print("RUIN_STONE preview", scene.render.filepath)
