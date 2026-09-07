"""Render the authored walk beside a rest-pose control. Does not save the rig."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'art/blender/bear'
FRAMES=Path('/tmp/zenscape-bear-walk-film');FRAMES.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ART/'zenscape-bear-walk.blend'))
scene=bpy.context.scene
rig=bpy.data.objects['Bear_Rig']
collection=bpy.data.collections['EDIT - rigged bear']
bpy.ops.object.select_all(action='DESELECT')
for obj in collection.objects:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bear-walk.glb'),
 export_format='GLB',use_selection=True,export_animations=True,
 export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,
 export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
scene.render.resolution_x=800;scene.render.resolution_y=640
scene.cycles.samples=12
# Subtle world-space floor tiles make contact visible. Two tiles equal one
# cycle's forward travel, allowing this one-cycle tracking shot to repeat.
floor=bpy.data.objects['Studio ground']
mat=floor.data.materials[0].copy();mat.name='Walk contact floor';floor.data.materials[0]=mat
nodes=mat.node_tree.nodes;links=mat.node_tree.links
geo=nodes.new('ShaderNodeNewGeometry');checker=nodes.new('ShaderNodeTexChecker')
checker.inputs['Color1'].default_value=(.30,.29,.26,1)
checker.inputs['Color2'].default_value=(.34,.33,.30,1)
checker.inputs['Scale'].default_value=2/(rig['walk_speed_mps']*1.6)
links.new(geo.outputs['Position'],checker.inputs['Vector'])
links.new(checker.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
scene.frame_set(1)
rig.data.pose_position='REST'
scene.render.filepath=str(ART/'bear-walk-control.png')
bpy.ops.render.render(write_still=True)
rig.data.pose_position='POSE'
helpers=[scene.camera]+[o for o in scene.objects if o.type=='LIGHT']
base={o.name:o.location.copy() for o in helpers}
for frame in range(1,49):
 scene.frame_set(frame)
 travel=Vector((0,-rig['walk_speed_mps']*(frame-1)/30,0))
 rig.location=travel
 for obj in helpers:obj.location=base[obj.name]+travel
 scene.render.filepath=str(FRAMES/f'{frame:04d}.png')
 bpy.ops.render.render(write_still=True)
 if frame in [1,13,25,39,48]:print('WALK_FILM_FRAME',frame,flush=True)
print('WALK_FILM_READY',str(FRAMES),flush=True)
