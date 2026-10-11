"""The sky dragon's dresses side by side (art/blender/rim_dragon/
dragon_body_build.py): a sheet with a row per dress and a column per view
(side, head on, three-quarter, head close-up, top).

    /opt/homebrew/bin/blender -b --python art/blender/rim_dragon/dragon_body_sheet.py -- [OUT.png] [--styles=c] [--jaw=0.5] [--tiles]

Reads assets/models/rim_dragon_<style>.glb; writes OUT.png (default
docs/design/rim-dragon/dragon_sheet.png). --jaw=<rad> opens the jaw to
check the mouth; --tiles also keeps each view as OUT_<style>_<view>.png.
"""
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ROOT / "docs/design/rim-dragon/dragon_sheet.png"
STYLES = "c"
JAW = 0.0
TILES = False
for a in args:
    if a == "--tiles": TILES = True
    if a.startswith("--styles="): STYLES = a.split("=", 1)[1]
    elif a.startswith("--jaw="): JAW = float(a.split("=", 1)[1])
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
scene.render.resolution_x, scene.render.resolution_y = W, H
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.55, 0.65, 0.78)
sh.background_type = "WORLD"

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

dresses = {}
for st in STYLES:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / f"assets/models/rim_dragon_{st}.glb"))
    dresses[st] = [o for o in bpy.data.objects if o not in before]
    rig = next((o for o in dresses[st] if o.type == "ARMATURE"), None)
    if rig and JAW:
        b = rig.pose.bones.get("jaw")
        b.rotation_mode = "XYZ"
        b.rotation_euler = (JAW, 0, 0)
for m in bpy.data.materials:
    if m.node_tree:
        b = m.node_tree.nodes.get("Principled BSDF")
        if b: m.diffuse_color = b.inputs["Base Color"].default_value[:]

HEAD = Vector((0, 29.5, 6.5))
VIEWS = [
    ("side", Vector((170, -10, 4)), Vector((0, -10, 1)), 112.0),
    ("front", Vector((0, 160, 10)), Vector((0, 0, 3)), 130.0),
    ("three", Vector((-95, 95, 55)), Vector((0, -8, 0)), 0.0),
    ("head", Vector((22, 46, 12)), HEAD, 0.0),
    ("top", Vector((0, -10, 200)), Vector((0, -10.01, 0)), 130.0),
]

def show(st):
    for k, objs in dresses.items():
        for o in objs:
            o.hide_render = k != st

tiles = []
tmp = Path(bpy.app.tempdir or "/tmp")
for st in STYLES:
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
            cam_data.lens = 30 if view == "three" else 40
        cam_data.clip_end = 1000
        path = (OUT.parent / f"{OUT.stem}_{st}_{view}.png") if TILES else (tmp / f"dragon_{st}_{view}.png")
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(str(path))
        row.append(np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4))
        bpy.data.images.remove(img)
    tiles.append(row)

gap = 6
nr = len(tiles)
sheet = np.ones((H * nr + gap * (nr - 1), W * len(VIEWS) + gap * (len(VIEWS) - 1), 4), dtype=np.float32)
for r, row in enumerate(tiles):
    for c, px in enumerate(row):
        y0 = (nr - 1 - r) * (H + gap)
        x0 = c * (W + gap)
        sheet[y0:y0 + H, x0:x0 + W] = px
out = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0], alpha=True)
out.pixels = sheet.ravel()
out.filepath_raw = str(OUT)
out.file_format = "PNG"
out.save()
print("DRAGON_SHEET", OUT)
