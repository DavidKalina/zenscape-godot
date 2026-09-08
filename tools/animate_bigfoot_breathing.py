"""Replace only Idle on a copy of the approved woodland rig; preserve other clips.
Blender --background --python tools/animate_bigfoot_breathing.py
"""
import bpy,math,json,struct
from pathlib import Path
from mathutils import Vector,Quaternion,Matrix
ROOT=Path(__file__).resolve().parents[1];ART=ROOT/'art/blender/bigfoot'
TARGET=ART/'zenscape-bigfoot-breathing.blend';EXPORT=ROOT/'assets/models/zenscape-bigfoot-breathing.glb'
if TARGET.exists():raise RuntimeError('Preserve the authored breathing source; edit it instead of regenerating.')
bpy.ops.wm.open_mainfile(filepath=str(ART/'zenscape-bigfoot-woodland.blend'))
scene=bpy.context.scene;rig=bpy.data.objects['Bigfoot_Rig'];work=bpy.data.collections['EDIT - rigged Wanderer']
meshes=[o for o in work.objects if o.type=='MESH']
old=bpy.data.actions['Idle'];rig.animation_data.action=old;scene.frame_set(1)
base={pb.name:(pb.location.copy(),pb.rotation_quaternion.copy(),pb.rotation_euler.copy(),pb.scale.copy(),pb.rotation_mode) for pb in rig.pose.bones}
head=next(o for o in meshes if '_n5_' in o.name)
mouth_bind=head.matrix_world @ Vector((0,-.284,.050))
bpy.data.actions.remove(old)
action=bpy.data.actions.new('Idle');action.use_fake_user=True;rig.animation_data.action=action
FRAMES=156;scene.render.fps=30

def smooth(t):return .5-.5*math.cos(math.pi*max(0,min(1,t)))
def translation(name,xyz):rig.pose.bones[name].location=rig.data.bones[name].matrix_local.to_3x3().inverted()@Vector(xyz)
def rotate(name,axis,angle):
 rest=rig.data.bones[name].matrix_local.to_quaternion()
 rig.pose.bones[name].rotation_quaternion=rest.inverted()@Quaternion(Vector(axis),angle)@rest
for frame in range(1,FRAMES+2):
 t=(frame-1)/FRAMES
 breath=smooth(t/.4) if t<.4 else 1-smooth((t-.4)/.5)
 for pb in rig.pose.bones:
  loc,quat,euler,scale,mode=base[pb.name];pb.rotation_mode=mode;pb.location=loc;pb.rotation_quaternion=quat;pb.rotation_euler=euler;pb.scale=scale
 translation('Pelvis',(0,0,-.042+.036*breath))
 rotate('Spine',(1,0,0),.010*(1-breath))
 rotate('Head',(1,0,0),.008*(1-breath))
 for side,sign in [('R',-1),('L',1)]:
  rotate('UpperArm_'+side,(0,1,0),sign*(.025+.008*breath))
  rotate('Forearm_'+side,(1,0,0),-.025+.012*breath)
 for pb in rig.pose.bones:
  pb.keyframe_insert('location',frame=frame,group=pb.name)
  pb.keyframe_insert('rotation_euler' if pb.rotation_mode=='XYZ' else 'rotation_quaternion',frame=frame,group=pb.name)
for layer in action.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for curve in bag.fcurves:
    for key in curve.keyframe_points:key.interpolation='LINEAR'
# Measure the actual evaluated foot transforms and loop, including baked IK.
feet=[];head_heights=[];first=None;seam=0
for frame in range(1,FRAMES+2):
 scene.frame_set(frame);bpy.context.view_layer.update();evaluated=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
 feet.append([evaluated.pose.bones[n].matrix.translation.copy() for n in ['Foot_R','Foot_L']])
 head_heights.append(evaluated.pose.bones['Head'].matrix.translation.z)
 pose=[v for pb in evaluated.pose.bones if pb.bone.use_deform for row in pb.matrix for v in row]
 if first is None:first=pose
 if frame==FRAMES+1:seam=max(abs(a-b) for a,b in zip(first,pose))
foot_drift=max((sample[i]-feet[0][i]).length for sample in feet for i in range(2))
assert foot_drift<.0001 and seam<.00001,(foot_drift,seam)
scene.frame_start=1;scene.frame_end=FRAMES;scene.frame_set(1)
# Bone-parented mouth marker exports as an attachment, not another deformation bone.
marker=bpy.data.objects.new('BreathOrigin',None);work.objects.link(marker)
marker.parent=rig;marker.parent_type='BONE';marker.parent_bone='Head'
bpy.context.view_layer.update()
deform=rig.pose.bones['Head'].matrix @ rig.data.bones['Head'].matrix_local.inverted()
marker.matrix_world=deform @ Matrix.Translation(mouth_bind)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);marker.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(EXPORT),export_format='GLB',use_selection=True,export_animations=True,
 export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,
 export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
report={'idle_seconds':FRAMES/30,'head_bob_metres':max(head_heights)-min(head_heights),'foot_drift_metres':foot_drift,'loop_seam':seam,'mouth_bind_blender':list(mouth_bind)}
(ART/'breathing-validation.json').write_text(json.dumps(report,indent=2)+'\n');print('BREATHING IDLE',json.dumps(report))
