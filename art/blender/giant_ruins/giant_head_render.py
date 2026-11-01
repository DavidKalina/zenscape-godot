"""A look at the cheap giant pieces (headless): scratch/giant_heads/*.png.

    python3 tools/blender.py run art/blender/giant_ruins/giant_head_render.py

Imports the _low glbs on an amber plain under a low sun, with 25 m spruce cones
and the plane as an orange marker (true to scale, 2.8 m span) for size. Writes
the heads in a row, the torsos in a row and a ruin field with pieces toppled
and half sunk. EEVEE, not the game's lighting.
"""
import math
from pathlib import Path

import bpy
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[3]
DIR = ROOT / "scratch/giant_heads"


def material(name, rgb):
    m = bpy.data.materials.new(name)
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Roughness"].default_value = 0.95
    return m


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 1600, 760
    bpy.ops.mesh.primitive_plane_add(size=12000)
    bpy.context.object.data.materials.append(material("plain", (0.33, 0.20, 0.07)))
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 5.0
    sun.color = (1.0, 0.82, 0.58)
    sun.angle = math.radians(2)
    so = bpy.data.objects.new("sun", sun)
    scene.collection.objects.link(so)
    so.rotation_euler = (math.radians(74), 0, math.radians(-58))
    world = bpy.data.worlds.new("world")
    scene.world = world
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.82, 0.62, 0.42, 1)
    bg.inputs[1].default_value = 0.55
    return scene


def place(name, at, rot=(0, 0, 0)):
    """A low piece, its origin at `at`, turned by `rot` degrees."""
    stone = bpy.data.materials.get("stone") or material("stone", (0.20, 0.155, 0.115))
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(DIR / f"{name}_low.glb"))
    for o in set(bpy.data.objects) - before:
        o.rotation_mode = "XYZ"
        o.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
        o.location = at
        if o.type == "MESH":
            o.data.materials.clear()
            o.data.materials.append(stone)


def trees(spots):
    tree = bpy.data.materials.get("tree") or material("tree", (0.14, 0.22, 0.13))
    for x, y in spots:
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=5, depth=25, location=(x, y, 12.5))
        bpy.context.object.data.materials.append(tree)


def marker(at):
    mark = material("plane", (1.0, 0.28, 0.02))
    for size in ((2.8, 0.7, 0.2), (0.4, 2.2, 0.3)):
        bpy.ops.mesh.primitive_cube_add(location=at)
        bpy.context.object.scale = [v / 2 for v in size]
        bpy.context.object.data.materials.append(mark)


def shot(scene, name, at, look, lens):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    cam.clip_end = 12000
    ob = bpy.data.objects.new(name, cam)
    scene.collection.objects.link(ob)
    ob.location = at
    ob.rotation_euler = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = ob
    scene.render.filepath = str(DIR / f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print("wrote", scene.render.filepath)


scene = setup()
for i, n in enumerate(("elder", "warden", "mourner")):
    place(n, ((i - 1) * 175, 0, 0))
trees(((-120, -135), (40, -125), (225, -100)))
shot(scene, "low_heads", (0, -560, 22), (0, 0, 60), 36)

scene = setup()
for i, n in enumerate(("elder_torso", "warden_torso", "mourner_torso")):
    place(n, ((i - 1) * 420, 0, 0))
trees(((-230, -160), (210, -170), (-20, -200)))
shot(scene, "torsos_front", (0, -1450, 40), (0, 0, 100), 36)
shot(scene, "torsos_back", (0, 1450, 40), (0, 0, 100), 36)
shot(scene, "torso_loop", (112 + 12, -240, 96), (112, 0, 96), 26)

scene = setup()
place("warden_torso", (0, 300, -30), (0, 0, 14))                 # upright, sunk to the belt
place("elder_torso", (-430, 80, 60), (0, 96, 22))                # toppled on its side
place("mourner", (260, -40, -46), (10, -14, -30))                # half sunk, looking up
place("warden", (-90, -240, 22), (0, 88, 40))                    # rolled on its ear
place("elder", (-420, -330, -66), (24, 6, 20))                   # only the brow and cap above ground
place("mourner_torso", (520, 460, -60), (0, 0, -24))             # buried to the arms
trees(((-120, -420), (120, -300), (330, -240), (-300, -130), (40, -90)))
shot(scene, "ruin_field", (60, -820, 40), (0, 80, 90), 30)
shot(scene, "ruin_field_high", (-260, -900, 420), (20, 60, 20), 34)
