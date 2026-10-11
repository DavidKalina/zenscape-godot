"""The sky dragon's three dresses side by side (art/blender/rim_dragon/
dragon_body_build.py): a sheet with a row per dress (a, b, c, top to
bottom) and a column per view (side, three-quarter, head close-up, top).

    /opt/homebrew/bin/blender -b --python art/blender/rim_dragon/dragon_body_sheet.py -- [OUT.png] [--pose=glide|beat]

Reads assets/models/rim_dragon_<a|b|c>.glb; writes OUT.png (default
docs/design/rim-dragon/dragon_sheet.png). --pose=beat poses the wings half
way through a downstroke and tucks the legs, roughly as the game flies it.
"""
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Euler, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ROOT / "docs/design/rim-dragon/dragon_sheet.png"
POSE = "glide"
for a in args:
    if a.startswith("--pose="): POSE = a.split("=", 1)[1]
    elif not a.startswith("--"): OUT = Path(a)
OUT.parent.mkdir(parents=True, exist_ok=True)
W, H = 960, 640

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
sh = scene.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL"
sh.show_specular_highlight = True
sh.show_shadows = True
sh.shadow_intensity = 0.4
sh.show_cavity = False
scene.render.resolution_x, scene.render.resolution_y = W, H
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.55, 0.65, 0.78)
sh.background_type = "WORLD"

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

dresses = {}
for st in "abc":
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / f"assets/models/rim_dragon_{st}.glb"))
    dresses[st] = [o for o in bpy.data.objects if o not in before]
for m in bpy.data.materials:
    if m.node_tree:
        b = m.node_tree.nodes.get("Principled BSDF")
        if b: m.diffuse_color = b.inputs["Base Color"].default_value[:]

def pose(objs):
    rig = next((o for o in objs if o.type == "ARMATURE"), None)
    if rig is None or POSE != "beat": return
    pb = rig.pose.bones
    def turn(name, axis, deg):
        b = pb.get(name)
        if b is None: return
        b.rotation_mode = "XYZ"
        e = list(b.rotation_euler)
        e["XYZ".index(axis)] += math.radians(deg)
        b.rotation_euler = e
    # Bone-local axes (the build rolls each bone's Z toward world up):
    # turning about local Y twists along the bone, about local X pitches.
    for n, s in (("L", -1), ("R", 1)):
        turn(f"wing_arm.{n}", "Y", -25 * s)
        turn(f"wing_fore.{n}", "Y", -15 * s)
        turn(f"fore_upper.{n}", "X", 70)
        turn(f"fore_lower.{n}", "X", -110)
        turn(f"hind_upper.{n}", "X", -60)
        turn(f"hind_lower.{n}", "X", 40)

for objs in dresses.values(): pose(objs)

HEAD = Vector((0, 18.5, 7.5))
VIEWS = [
    ("side", Vector((110, -6, 6)), Vector((0, -7, 1)), 66.0),
    ("three", Vector((-70, 72, 40)), Vector((0, -6, 0)), 0.0),
    ("head", Vector((19, 37, 13)), HEAD, 0.0),
    ("top", Vector((0, -6, 150)), Vector((0, -6.01, 0)), 92.0),
]

def show(st):
    for k, objs in dresses.items():
        for o in objs:
            o.hide_render = k != st

tiles = []
tmp = Path(bpy.app.tempdir or "/tmp")
for st in "abc":
    show(st)
    row = []
    for view, at, look, ortho in VIEWS:
        cam.location = at
        cam.rotation_euler = (look - at).to_track_quat("-Z", "Y").to_euler()
        if ortho:
            cam_data.type = "ORTHO"
            cam_data.ortho_scale = ortho
        else:
            cam_data.type = "PERSP"
            cam_data.lens = 34 if view == "three" else 40
        path = tmp / f"dragon_{st}_{view}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(str(path))
        px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
        row.append(px)
        bpy.data.images.remove(img)
    tiles.append(row)

# Blender's pixels run bottom row first: stack rows so a is on top.
gap = 6
sheet = np.ones((H * 3 + gap * 2, W * len(VIEWS) + gap * (len(VIEWS) - 1), 4), dtype=np.float32)
for r, row in enumerate(tiles):
    for c, px in enumerate(row):
        y0 = (2 - r) * (H + gap)
        x0 = c * (W + gap)
        sheet[y0:y0 + H, x0:x0 + W] = px
out = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0], alpha=True)
out.pixels = sheet.ravel()
out.filepath_raw = str(OUT)
out.file_format = "PNG"
out.save()
print("DRAGON_SHEET", OUT)
