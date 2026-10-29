"""Render the ruins' ivy cards (assets/textures/ivy_cards.png).

Run: python tools/blender.py run art/blender/ivy_cards/ivy_cards_build.py [-- --seed=5 --cell=512 --preview=scratch/ivy_cards]

Four hanging clusters of ivy, one to a cell of a 2x2 atlas: a curling stem
from the top of the cell, lobed leaves on short stalks off it, alternating,
cupped and folded along the midrib, turned this way and that so they catch a
soft top light differently and shade one another. Rendered in Cycles from the
front, orthographic, on a clear film.

  ivy_cards.png  R the light (0.5 is the clusters' mean, so the shader
                 multiplies the strand's own colour by 2R and keeps its tint),
                 G the same, B 1 on a leaf and 0 on a stem, A coverage.

A card's v runs down the cell from the stem's top (where it hangs from) to
the tip; u across. Cell k (0..3) is at column k % 2, row k / 2 from the top.
"""
import bpy
import bmesh
import math
import random
import sys
from pathlib import Path

import mathutils
import numpy as np

ARGS = dict(a[2:].split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:] if a.startswith("--") and "=" in a) if "--" in sys.argv else {}
SEED = int(ARGS.get("seed", "5"))
CELL = int(ARGS.get("cell", "512"))
PREVIEW = ARGS.get("preview", "")

rng = random.Random(SEED)
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "textures"
TMP = ROOT / "scratch" / "ivy_cards_tmp"
TMP.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def link(ob):
    scene.collection.objects.link(ob)
    return ob


def leaf(name, size, lobes):
    """A lobed ivy leaf `size` across, its tip down (-y), its stalk's end at
    the origin (the heart-shaped notch at its top), cupped and folded."""
    rings, steps = 7, 72
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    centre = bm.verts.new((0, 0, 0))
    grid = []
    # Lobes as pointed peaks round the blade: the tip, a pair either side,
    # (on a five-lobed leaf) a small pair at the back; the notch at the top.
    tip = rng.uniform(0.2, 0.28)
    side_h = rng.uniform(0.12, 0.2)
    side_at = math.radians(rng.uniform(58, 72))
    back_h = rng.uniform(0.05, 0.1) if lobes == 5 else 0.0
    back_at = math.radians(rng.uniform(118, 132))
    width = rng.uniform(0.26, 0.34)
    skew = rng.uniform(-0.08, 0.08)
    for j in range(1, rings + 1):
        f = j / rings
        row = []
        for i in range(steps):
            th = -math.pi + 2 * math.pi * i / steps          # 0 at the tip (down)
            a = abs(th)
            r = 0.27
            r += tip * math.exp(-a / width)
            r += side_h * math.exp(-abs(a - side_at) / (width * 0.8))
            r += back_h * math.exp(-abs(a - back_at) / (width * 0.7))
            r *= 1.0 - 0.55 * math.exp(-((a - math.pi) / 0.3) ** 2)   # the notch
            x = math.sin(th + skew) * r * f
            y = -math.cos(th + skew) * r * f
            z = -0.12 * (f * r) ** 2 * 2 - 0.08 * abs(x)                    # cupped, folded
            row.append(bm.verts.new((x * size, y * size, z * size)))
        grid.append(row)
    for i in range(steps):
        bm.faces.new((centre, grid[0][i], grid[0][(i + 1) % steps]))
    for j in range(rings - 1):
        for i in range(steps):
            a, b = grid[j][i], grid[j][(i + 1) % steps]
            c, d = grid[j + 1][(i + 1) % steps], grid[j + 1][i]
            bm.faces.new((a, b, c, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = link(bpy.data.objects.new(name, me))
    # Its stalk joins at the notch: move the leaf so the notch is the origin.
    top = 0.5 * size * 0.58
    ob.data.transform(mathutils.Matrix.Translation((0, -top, 0)))
    return ob


def tube(name, pts, r):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 2
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts):
        p.co = (q[0], q[1], q[2], 1)
    return link(bpy.data.objects.new(name, cu))


def material(name, colour, leafy):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = colour
    b.inputs["Roughness"].default_value = 0.55 if leafy else 0.8
    return m


def cluster(k):
    """Cell k's cluster, centred on the origin in [-0.5, 0.5]^2."""
    obs = []
    top = (rng.uniform(-0.08, 0.08), 0.5, 0.0)
    n = rng.randint(8, 11)
    stem = [top]
    bend = rng.uniform(-0.25, 0.25)
    for i in range(1, 12):
        t = i / 11
        stem.append((top[0] + bend * math.sin(t * 2.2) * 0.4 + rng.uniform(-0.01, 0.01), 0.5 - t * 0.9, -0.02 * t))
    obs.append(tube(f"stem{k}", stem, 0.007))
    for i in range(n):
        t = 0.08 + 0.86 * i / max(1, n - 1) + rng.uniform(-0.03, 0.03)
        j = min(10, int(t * 10))
        s0 = mathutils.Vector(stem[j])
        side = 1 if i % 2 == 0 else -1
        size = rng.uniform(0.32, 0.46) * (1.0 - 0.3 * t)
        stalk = rng.uniform(0.04, 0.09)
        end = s0 + mathutils.Vector((side * stalk, -stalk * 0.4, rng.uniform(0.0, 0.04)))
        obs.append(tube(f"stalk{k}_{i}", [tuple(s0), tuple((s0 + end) / 2 + mathutils.Vector((0, 0.01, 0.01))), tuple(end)], 0.004))
        lf = leaf(f"leaf{k}_{i}", size, 5 if rng.random() < 0.5 else 3)
        lf.location = end
        lf.rotation_euler = (math.radians(rng.uniform(-45, 45)), math.radians(rng.uniform(-40, 40)),
                             math.radians(side * rng.uniform(5, 70) + rng.uniform(-15, 15)))
        lf["tone"] = rng.uniform(0.62, 1.12)
        obs.append(lf)
    return obs


# Materials: leaves a light grey-green each its own tone, stems darker.
stem_mat = material("stem", (0.18, 0.16, 0.12, 1), False)
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 64
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = CELL
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "16"
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.58, 0.6, 1)
sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 3.2
sun.angle = math.radians(12)
so = link(bpy.data.objects.new("sun", sun))
so.rotation_euler = (math.radians(-40), math.radians(-18), 0)   # from above and the front
cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
cam.ortho_scale = 1.0
co = link(bpy.data.objects.new("cam", cam))
co.location = (0, 0, 3)
scene.camera = co

lum_cells, mask_cells, alpha_cells = [], [], []
for k in range(4):
    obs = cluster(k)
    for ob in obs:
        if ob.name.startswith("leaf"):
            t = ob["tone"]
            m = material(f"leaf_m_{ob.name}", (0.42 * t, 0.47 * t, 0.36 * t, 1), True)
            ob.data.materials.append(m)
        else:
            ob.data.materials.append(stem_mat)
    # Fit the cluster in the cell (a margin round it).
    lo = mathutils.Vector((9, 9, 9))
    hi = mathutils.Vector((-9, -9, -9))
    bpy.context.view_layer.update()
    for ob in obs:
        for c in ob.bound_box:
            w = ob.matrix_world @ mathutils.Vector(c)
            lo = mathutils.Vector(map(min, lo, w))
            hi = mathutils.Vector(map(max, hi, w))
    span = max(hi.x - lo.x, hi.y - lo.y)
    s = 0.94 / span
    pivot = bpy.data.objects.new(f"pivot{k}", None)
    link(pivot)
    for ob in obs:
        ob.parent = pivot
    pivot.scale = (s, s, s)
    pivot.location = (-(lo.x + hi.x) / 2 * s, 0.5 - 0.02 - hi.y * s, 0)
    path = TMP / f"cell{k}.png"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    # Which pixels are leaf: the stems hidden, rendered again for the alpha.
    for ob in obs:
        if not ob.name.startswith("leaf"):
            ob.hide_render = True
    scene.render.filepath = str(TMP / f"cell{k}_leaf.png")
    scene.cycles.samples = 8
    bpy.ops.render.render(write_still=True)
    scene.cycles.samples = 64
    img = bpy.data.images.load(str(path))
    px = np.array(img.pixels[:], dtype=np.float32).reshape(CELL, CELL, 4)   # rows from the bottom
    img2 = bpy.data.images.load(str(TMP / f"cell{k}_leaf.png"))
    px2 = np.array(img2.pixels[:], dtype=np.float32).reshape(CELL, CELL, 4)
    lum = px[:, :, 0] * 0.3 + px[:, :, 1] * 0.55 + px[:, :, 2] * 0.15
    lum_cells.append(lum)
    alpha_cells.append(px[:, :, 3])
    mask_cells.append(px2[:, :, 3])
    for ob in obs:
        bpy.data.objects.remove(ob)
    bpy.data.objects.remove(pivot)
    print("IVY cell", k)

# The atlas: cell k at column k % 2, row k // 2 from the top (bpy rows run up).
atlas = np.zeros((CELL * 2, CELL * 2, 4), dtype=np.float32)
cover = np.concatenate([a.ravel() for a in alpha_cells])
lums = np.concatenate([l.ravel() for l in lum_cells])
# The light (a PNG keeps it straight, not premultiplied), its mean over the
# covered pixels at 0.5.
mean = float((lums * cover).sum() / max(1e-6, cover.sum()))
for k in range(4):
    col, row = k % 2, k // 2
    r0 = (1 - row) * CELL
    c0 = col * CELL
    a = alpha_cells[k]
    straight = np.where(a > 1e-3, lum_cells[k], mean)
    light = np.clip(0.5 * straight / mean, 0, 1)
    atlas[r0:r0 + CELL, c0:c0 + CELL, 0] = light
    atlas[r0:r0 + CELL, c0:c0 + CELL, 1] = light
    atlas[r0:r0 + CELL, c0:c0 + CELL, 2] = np.clip(mask_cells[k] / np.maximum(a, 1e-3), 0, 1)
    atlas[r0:r0 + CELL, c0:c0 + CELL, 3] = a
# Under the clear parts, the nearest light (so the mips don't fringe dark):
# spread the covered light out a few times.
rgb = atlas[:, :, :3].copy()
a = atlas[:, :, 3]
known = a > 0.02
for _ in range(24):
    acc = np.zeros_like(rgb)
    cnt = np.zeros(a.shape, dtype=np.float32)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(np.roll(known, dy, 0), dx, 1)
        acc += np.roll(np.roll(rgb, dy, 0), dx, 1) * sh[:, :, None]
        cnt += sh
    fill = (~known) & (cnt > 0)
    rgb[fill] = acc[fill] / cnt[fill][:, None]
    known = known | fill
rgb[~known] = 0.5
atlas[:, :, :3] = rgb
out = bpy.data.images.new("ivy_cards", CELL * 2, CELL * 2, alpha=True)
out.colorspace_settings.name = "Non-Color"
out.alpha_mode = "STRAIGHT"
out.pixels.foreach_set(atlas.ravel())
OUT.mkdir(parents=True, exist_ok=True)
out.filepath_raw = str(OUT / "ivy_cards.png")
out.file_format = "PNG"
out.save()
print("IVY saved", out.filepath_raw, "mean", round(mean, 3))
