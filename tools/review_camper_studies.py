"""Render v01 beside the actual editor Bigfoot mesh; does not change source assets."""
import bpy,json,struct
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'art/blender/campers'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'zenscape-campers-v01.blend'))
scene=bpy.context.scene
bpy.data.collections['EDIT - Ochre ridge tent'].hide_render=True
for name,x in [('EDIT - Field photographer',1.1),('EDIT - Trail backpacker',2.05)]:
    c=bpy.data.collections[name]
    # Already positioned in the source layout.
    for o in c.objects:o.location.y+=.35
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bigfoot-breathing.glb'))
imported=set(bpy.data.objects)-before
for o in imported:
    if o.type=='MESH' and not o.name.startswith('Wanderer'): o.hide_render=True
    if o.animation_data: o.animation_data_clear()
    if o.type=='ARMATURE':
        for bone in o.pose.bones: bone.matrix_basis.identity()
print('REFERENCE_OBJECTS',[(o.name,o.type) for o in imported])
ref=bpy.data.collections.new('REFERENCE - current editor Bigfoot');scene.collection.children.link(ref)
for o in imported:
    for c in list(o.users_collection):c.objects.unlink(o)
    ref.objects.link(o)
for o in imported:
    if o.parent is None:o.location.x-=.65
scene.frame_set(1)
cam=scene.camera;cam.location=(5,-10,4.5);cam.rotation_euler=(Vector((.6,0,1.25))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=4.6
scene.render.filepath=str(OUT/'current-bigfoot-comparison-v01.png');bpy.ops.render.render(write_still=True)
# Reimport each GLB in a clean scene to verify export geometry/materials and bounds.
report={}
for slug in ['camper-photographer','camper-backpacker','tent-ochre']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path=ROOT/'assets/models'/f'zenscape-{slug}-v01.glb'
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    points=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]
    assert meshes and all(o.data.materials for o in meshes)
    assert all(len(p.vertices)==3 for o in meshes for p in o.data.polygons)
    report[slug]={'meshes':len(meshes),'triangles':sum(len(o.data.polygons) for o in meshes),'bounds_m':[[round(min(p[i] for p in points),3),round(max(p[i] for p in points),3)] for i in range(3)],'materials_present':True}
(OUT/'export-validation-v01.json').write_text(json.dumps(report,indent=2)+'\n')
print('EXPORT_REIMPORT_OK',report)
