"""A look at the cabin at zenscape's scale (headless): docs/scenic/cabin-render.png.

    /opt/homebrew/bin/blender -b --python art/blender/cabin_render.py

Imports assets/models/cabin.glb (what Godot gets) at the game's 0.8 and stands
grey scale markers beside it: a 1 m post (the stone lamp), a 0.62 m post (a
fence post) and a 4 m faceted cone (a tree). Three tiles: the front
three-quarter by day, the chimney side, and a dusk tile with the window's
`glow` lit. EEVEE renders, not the game's lighting, and without the footing
stones scripts/cabin.gd adds. The PNG is git-ignored.
"""
import math
import tempfile
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "assets/models"
OUT = ROOT / "docs/scenic"
OUT.mkdir(parents=True, exist_ok=True)
TMP = Path(tempfile.mkdtemp(prefix="cabin_render_"))
UNIT = 0.8

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_EEVEE"
except TypeError:
    scene.render.engine = "BLENDER_WORKBENCH"
scene.view_settings.view_transform = "Standard"

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(MODELS / "cabin.glb"))
for o in bpy.data.objects:
    if o not in before and o.parent is None:
        o.scale = (UNIT, UNIT, UNIT)
        o.location = o.location * UNIT


def flat(name, hexcol):
    m = bpy.data.materials.new(name)
    c = [int(hexcol[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*c, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    return m


grey = flat("marker", "a39e93")
green = flat("tree", "5f7a4a")
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.12, depth=1.0, location=(2.6, -1.0, 0.5))
bpy.context.object.data.materials.append(grey)            # the stone lamp, 1 m
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.06, depth=0.62, location=(2.6, -2.0, 0.31))
bpy.context.object.data.materials.append(grey)            # a fence post, 0.62 m
bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=1.1, depth=4.0, location=(-3.6, 2.4, 2.0))
bpy.context.object.data.materials.append(green)           # a tree, 4 m

bpy.ops.mesh.primitive_plane_add(size=300)
floor = bpy.context.object
floor.data.materials.append(flat("floor", "8c9a6a"))

world = bpy.data.worlds.new("sky")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.55, 0.6, 0.65, 1)
bg.inputs["Strength"].default_value = 1.0

sun_data = bpy.data.lights.new("sun", "SUN")
sun_data.energy = 3.5
sun_data.angle = math.radians(8)
sun = bpy.data.objects.new("sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, math.radians(-35))

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def aim(loc, target, lens=40):
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = lens


def shot(path, w, h):
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(str(path))
    a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
    bpy.data.images.remove(img)
    return a


row = []
aim((7.5, -10.0, 6.5), (0.0, -0.3, 1.1))
row.append(shot(TMP / "front.png", 780, 600))
aim((-9.0, 7.5, 6.0), (-0.3, 0.3, 1.2))
row.append(shot(TMP / "back.png", 780, 600))
glow = bpy.data.materials.get("glow")
bsdf = glow.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Emission Color"].default_value = (1.0, 0.7, 0.4, 1)
bsdf.inputs["Emission Strength"].default_value = 6.0
sun_data.energy = 0.4
sun_data.color = (0.7, 0.75, 1.0)
bg.inputs["Strength"].default_value = 0.15
aim((10.0, -5.0, 4.5), (0.4, -0.3, 1.1))
dusk = shot(TMP / "dusk.png", 1560, 520)

strips = [np.concatenate(row, axis=1), dusk]
full = np.concatenate(list(reversed(strips)), axis=0)
h, w = full.shape[:2]
img = bpy.data.images.new("sheet", w, h, alpha=True)
img.pixels = full.ravel()
img.filepath_raw = str(OUT / "cabin-render.png")
img.file_format = "PNG"
img.save()
print("CABIN_RENDER", OUT / "cabin-render.png")
