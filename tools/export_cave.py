"""Export the approved cave meshes; never save over the editable Blender study."""
import bpy, json
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/blender/cave/zenscape-cave-study.blend'
TARGET = ROOT / 'assets/models/zenscape-cave.glb'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bpy.ops.object.select_all(action='DESELECT')
parts = [o for name in ['EDIT - cave stone and interior', 'EDIT - moss on stone']
         for o in bpy.data.collections[name].objects if o.type == 'MESH']
assert parts and any(o.name.startswith('Interior -') for o in parts)
root = bpy.data.objects.new('Cave', None)
bpy.context.scene.collection.objects.link(root)
root['description'] = 'Approved woodland cave; entrance pivot, metres, forward +Z in Godot.'
root['entrance_width_m'] = 3.7
root['entrance_height_m'] = 3.6
# Entrance floor becomes the origin. Blender -Y faces Godot +Z after export.
for o in parts:
    o.parent = root
    o.location += Vector((0, 3.7, .07))
    o.select_set(True)
root.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=str(TARGET), export_format='GLB',
    use_selection=True, export_animations=False, export_cameras=False,
    export_lights=False, export_extras=True, export_yup=True)
# Exact irregular mouth outline for the in-game black threshold.
interior = bpy.data.objects['Interior - curved sheltered passage']
outline = []
for vertex in list(interior.data.vertices)[:13]:
    point = interior.matrix_world @ vertex.co
    outline.append([point.x, point.z, -point.y])
(ROOT/'assets/models/zenscape-cave-entrance.json').write_text(json.dumps(outline,indent=2)+'\n')
print('CAVE_EXPORT', TARGET, 'meshes', len(parts))
