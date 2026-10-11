"""Stills of the rim dragon for checking by eye, in rest (jaw shut) and with
the jaw open.

    /opt/homebrew/bin/blender -b art/blender/rim_dragon/rim_dragon.blend --python art/blender/rim_dragon/rim_dragon_preview.py -- [OUT_DIR]

Writes OUT_DIR/<view>.png (default /tmp/rim_dragon_preview).
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(args[0] if args else "/tmp/rim_dragon_preview")
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
rig = bpy.data.objects["DragonRig"]

scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_specular_highlight = True
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.render.resolution_x, scene.render.resolution_y = 1100, 800
scene.world = bpy.data.worlds.new("w") if scene.world is None else scene.world
scene.world.color = (0.62, 0.66, 0.72)

# The island's top up to the rim (y > 0), for scale.
bpy.ops.mesh.primitive_cube_add(size=1)
ground = bpy.context.object
ground.scale = (60, 30, 4)
ground.location = (0, 15, -2)
mat = bpy.data.materials.new("ground")
mat.diffuse_color = (0.33, 0.4, 0.28, 1)
ground.data.materials.append(mat)

cam_data = bpy.data.cameras.new("cam")
cam_data.lens = 30
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

VIEWS = {
    "front": (Vector((0, 30, 4)), Vector((0, 0, 6))),
    "three": (Vector((18, 26, 6)), Vector((0, 0, 6))),
    "side": (Vector((34, 2, 6)), Vector((0, 0, 4))),
    "close": (Vector((5, 17, 3)), Vector((0, 4, 5))),
    "back": (Vector((10, -40, 10)), Vector((0, -6, 2))),
}

def shoot(tag):
    for view, (at, look) in VIEWS.items():
        cam.location = at
        cam.rotation_euler = (look - at).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(OUT / f"{tag}_{view}.png")
        bpy.ops.render.render(write_still=True)

shoot("rest")
# Panting: the head lowered over the rim, the jaw dropped open.
pb = rig.pose.bones
for name, deg in (("neck.0", 10), ("neck.1", 18), ("neck.2", 12), ("head", -10)):
    pb[name].rotation_mode = "XYZ"
    pb[name].rotation_euler = (math.radians(deg), 0, 0)
pb["jaw"].rotation_mode = "XYZ"
pb["jaw"].rotation_euler = (math.radians(-32), 0, 0)
shoot("open")
