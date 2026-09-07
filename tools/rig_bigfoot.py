"""Rig the existing Wanderer without changing its geometry or proportions.
Run through Blender. Refuses to overwrite the authored Blender rig.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'art/blender/bigfoot';ART.mkdir(exist_ok=True)
TARGET=ART/'zenscape-bigfoot-walk.blend'
if TARGET.exists(): raise RuntimeError('Edit the existing rig; do not regenerate over authored work.')
bpy.ops.wm.open_mainfile(filepath=str(ART/'bigfoot-source.blend'))
scene=bpy.context.scene
source_objects=list(scene.objects)
by_id={int(o.name.split('_')[0][1:]):o for o in source_objects}
points={i:o.matrix_world.translation.copy() for i,o in by_id.items()}
reference=bpy.data.collections.new('REFERENCE - original Wanderer');scene.collection.children.link(reference)
work=bpy.data.collections.new('EDIT - rigged Wanderer');scene.collection.children.link(work)
for o in source_objects:
 for c in list(o.users_collection):c.objects.unlink(o)
 reference.objects.link(o)
reference.hide_viewport=True;reference.hide_render=True
arm=bpy.data.armatures.new('Wanderer Skeleton');rig=bpy.data.objects.new('Bigfoot_Rig',arm);work.objects.link(rig)
rig.show_in_front=True;arm.display_type='OCTAHEDRAL'
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None,deform=True):
 b=arm.edit_bones.new(name);b.head=head;b.tail=tail;b.use_deform=deform
 if parent:b.parent=arm.edit_bones[parent]
 return b
bone('Root',(0,0,0),(0,0,.20),deform=False)
bone('Pelvis',points[1],points[1]+Vector((0,0,.22)),'Root')
bone('Spine',points[2],points[4],'Pelvis')
bone('Head',points[4],points[4]+Vector((0,-.02,.34)),'Spine')
mapping={1:'Pelvis',2:'Spine',4:'Head',6:'Head'}
legs=[]
for side,shoulder,elbow,wrist,finger,hip,knee,ankle in [('R',9,11,13,14,53,55,57),('L',31,33,35,36,59,61,63)]:
 bone('UpperArm_'+side,points[shoulder],points[elbow],'Spine')
 bone('Forearm_'+side,points[elbow],points[wrist],'UpperArm_'+side)
 bone('Hand_'+side,points[wrist],points[wrist]+Vector((0,-.02,-.19)),'Forearm_'+side)
 mapping.update({shoulder:'UpperArm_'+side,elbow:'Forearm_'+side,wrist:'Hand_'+side})
 for f in range(4):
  start=finger+4*f;end=start+2
  name='Finger_'+side+'_'+str(f+1)
  bone(name,points[start],points[end],'Hand_'+side)
  bone(name+'_Tip',points[end],points[end]+Vector((0,0,-.035)),name)
  mapping[start]=name;mapping[end]=name+'_Tip'
 bone('Thigh_'+side,points[hip],points[knee],'Pelvis')
 bone('Calf_'+side,points[knee],points[ankle],'Thigh_'+side)
 bone('Foot_'+side,points[ankle],points[ankle]+Vector((0,-.30,0)),'Calf_'+side)
 bone('Foot_CTRL_'+side,points[ankle],points[ankle]+Vector((0,-.30,0)),'Root',False)
 pole=points[knee]+Vector((0,-.65,0))
 bone('Knee_CTRL_'+side,pole,pole+Vector((0,0,.15)),'Root',False)
 mapping.update({hip:'Thigh_'+side,knee:'Calf_'+side,ankle:'Foot_'+side})
 legs.append(dict(side=side,home=points[ankle],knee=points[knee],offset=0 if side=='R' else .5))
bpy.ops.object.mode_set(mode='OBJECT')
meshes=[];foot_objects={}
for src in source_objects:
 if src.type!='MESH':continue
 parent=src.parent
 while parent:
  pid=int(parent.name.split('_')[0][1:])
  if pid in mapping:break
  parent=parent.parent
 if parent is None:raise RuntimeError('No joint mapping: '+src.name)
 joint=mapping[pid]
 obj=src.copy();obj.data=src.data.copy();obj.name='Wanderer_'+src.name
 world=src.matrix_world.copy();obj.parent=rig;work.objects.link(obj);obj.matrix_world=world
 obj.vertex_groups.clear();obj.vertex_groups.new(name=joint).add(list(range(len(obj.data.vertices))),1,'REPLACE')
 mod=obj.modifiers.new('Wanderer skin','ARMATURE');mod.object=rig
 meshes.append(obj)
 if joint in ['Foot_L','Foot_R']:foot_objects[joint[-1]]=obj
for leg in legs:
 side=leg['side'];ik=rig.pose.bones['Calf_'+side].constraints.new('IK')
 ik.name='Planted foot';ik.target=rig;ik.subtarget='Foot_CTRL_'+side;ik.chain_count=2
 ik.pole_target=rig;ik.pole_subtarget='Knee_CTRL_'+side;ik.use_stretch=False
 rig.pose.bones['Thigh_'+side].ik_stretch=0;rig.pose.bones['Calf_'+side].ik_stretch=0
 scores=[]
 for angle in [0,math.pi/2,-math.pi/2,math.pi]:
  ik.pole_angle=angle;bpy.context.view_layer.update()
  evaluated=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
  scores.append(((evaluated.pose.bones['Thigh_'+side].tail-leg['knee']).length,angle))
 ik.pole_angle=min(scores)[1]
 copy=rig.pose.bones['Foot_'+side].constraints.new('COPY_ROTATION');copy.name='Level sole'
 copy.target=rig;copy.subtarget='Foot_CTRL_'+side;copy.target_space='POSE';copy.owner_space='POSE'

def delta(name,xyz):return arm.bones[name].matrix_local.to_3x3().inverted()@Vector(xyz)
def rotate_world(name,axis,angle):
 pb=rig.pose.bones[name];pb.rotation_mode='QUATERNION'
 q=arm.bones[name].matrix_local.to_quaternion()
 pb.rotation_quaternion=q.inverted()@Quaternion(Vector(axis),angle)@q
 return pb
FPS=30;FRAMES=108;DURATION=3.6;DUTY=.62;STRIDE=.54;SPEED=STRIDE/(DUTY*DURATION)
scene.render.fps=FPS;scene.frame_start=1;scene.frame_end=FRAMES
rig.animation_data_create();action=bpy.data.actions.new('Walk');rig.animation_data.action=action

def target(leg,phase):
 u=(phase+leg['offset'])%1;home=leg['home']
 if u<DUTY:return home+Vector((0,-STRIDE/2+STRIDE*u/DUTY,0)),0,u
 s=(u-DUTY)/(1-DUTY);slope=STRIDE*(1-DUTY)/DUTY
 y=(2*s**3-3*s*s+1)*STRIDE/2+(s**3-2*s*s+s)*slope+(-2*s**3+3*s*s)*(-STRIDE/2)+(s**3-s*s)*slope
 lift=.11*math.sin(math.pi*s)**2
 return home+Vector((0,y,lift)),.07*math.sin(2*math.pi*s)*math.sin(math.pi*s),u

for frame in range(1,FRAMES+2):
 phase=(frame-1)/FRAMES
 for leg in legs:
  side=leg['side'];p,pitch,u=target(leg,phase);name='Foot_CTRL_'+side
  pb=rig.pose.bones[name];pb.location=delta(name,p-leg['home']);pb.rotation_mode='XYZ';pb.rotation_euler=(pitch,0,0)
  pb.keyframe_insert('location',frame=frame,group=name);pb.keyframe_insert('rotation_euler',frame=frame,group=name)
 pelvis=rotate_world('Pelvis',(0,0,1),.020*math.sin(math.tau*phase))
 pelvis.location=delta('Pelvis',(-.032*math.sin(math.tau*phase),0,-.025+.007*math.cos(2*math.tau*phase)))
 pelvis.keyframe_insert('location',frame=frame,group='Pelvis');pelvis.keyframe_insert('rotation_quaternion',frame=frame,group='Pelvis')
 for name,axis,angle in [('Spine',(0,0,1),-.027*math.sin(math.tau*phase)),('Head',(0,0,1),.018*math.sin(math.tau*phase+.4))]:
  rotate_world(name,axis,angle).keyframe_insert('rotation_quaternion',frame=frame,group=name)
 for side,offset in [('R',0),('L',.5)]:
  # An arm travels back as the same-side leg reaches forward.
  swing=math.cos(math.tau*(phase+offset))
  for name,angle in [('UpperArm_'+side,.19*swing),('Forearm_'+side,.040*math.sin(math.tau*(phase+offset)-.5)),('Hand_'+side,.016*math.sin(math.tau*(phase+offset)-.8))]:
   rotate_world(name,(1,0,0),angle).keyframe_insert('rotation_quaternion',frame=frame,group=name)
for layer in action.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for fc in bag.fcurves:
    for key in fc.keyframe_points:key.interpolation='LINEAR'
max_error=0;max_slip=0;min_sole=0;anchors={};first=None;last=None
for frame in range(1,FRAMES+2):
 scene.frame_set(frame);bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();ev=rig.evaluated_get(deps)
 phase=(frame-1)/FRAMES
 poses={b.name:[v for row in b.matrix for v in row] for b in ev.pose.bones if b.bone.use_deform}
 if frame==1:first=poses
 if frame==FRAMES+1:last=poses
 for leg in legs:
  side=leg['side'];p,pitch,u=target(leg,phase);actual=ev.pose.bones['Foot_'+side].head.copy()
  max_error=max(max_error,(actual-p).length)
  foot=foot_objects[side].evaluated_get(deps);deformed=foot.to_mesh()
  min_sole=min(min_sole,min((foot.matrix_world@v.co).z for v in deformed.vertices));foot.to_mesh_clear()
  if u<DUTY:
   key=(side,math.floor(phase+leg['offset']));world=actual+Vector((0,-SPEED*(frame-1)/FPS,0))
   if key not in anchors:anchors[key]=world
   max_slip=max(max_slip,(world-anchors[key]).length)
seam=max(abs(a-b) for n in first for a,b in zip(first[n],last[n]))
assert max_error<.003,('IK target error',max_error)
assert max_slip<.003,('Stance slip',max_slip)
assert min_sole>-.005,('Sole penetrates floor',min_sole)
assert seam<1e-4,('Loop seam',seam)
for obj in meshes:
 for v in obj.data.vertices:assert abs(sum(g.weight for g in v.groups)-1)<1e-5
report=dict(animation='Walk',duration_seconds=DURATION,fps=FPS,frames=FRAMES,
 forward_speed_mps=SPEED,direction='Godot +Z / Blender -Y',duty_factor=DUTY,
 bones=len(arm.bones),deform_bones=sum(b.use_deform for b in arm.bones),
 skinned_meshes=len(meshes),faces=sum(len(o.data.polygons) for o in meshes),
 max_ik_target_error_m=max_error,max_stance_slip_m=max_slip,
 min_sole_height_m=min_sole,max_loop_matrix_delta=seam,
 scope='Existing Wanderer geometry preserved; flat-ground walk; game behavior not replaced.')
(ART/'walk-validation.json').write_text(json.dumps(report,indent=2)+'\n')
rig['walk_speed_mps']=SPEED;rig['walk_cycle_seconds']=DURATION
rig['instructions']='Space plays Walk. Pose Mode: Foot_CTRL and Knee_CTRL plant feet. UpperArm/Forearm/Hand and individual Finger bones control gestures.'
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bigfoot-walk.glb'),export_format='GLB',use_selection=True,
 export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
 export_frame_range=False,export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
# Presentation helpers live outside the exported rig collection.
studio=bpy.data.collections.new('STUDIO - not exported');scene.collection.children.link(studio)
def studio_object(o):
 for c in list(o.users_collection):c.objects.unlink(o)
 studio.objects.link(o)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.01));floor=bpy.context.object;floor.name='Studio ground';studio_object(floor)
mat=bpy.data.materials.new('Warm studio floor');mat.diffuse_color=(.30,.29,.26,1);mat.use_nodes=True
mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.30,.29,.26,1)
mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9;floor.data.materials.append(mat)
bpy.ops.object.camera_add(location=(4.3,-7,3.3));cam=bpy.context.object;cam.name='Study camera';studio_object(cam)
cam.rotation_euler=(Vector((0,-.1,1.35))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.7;scene.camera=cam
for name,loc,power,size in [('Key',(-3,-4,6),850,4),('Fill',(4,-1,4),300,3),('Rim',(1,4,5),1100,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.size=size
 o.rotation_euler=(Vector((0,0,1.3))-o.location).to_track_quat('-Z','Y').to_euler();studio_object(o)
scene.world=bpy.data.worlds.new('Studio world');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.23,.25,.28,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
studio.hide_viewport=True
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.shading.type='MATERIAL';space.region_3d.view_distance=4.7
   space.region_3d.view_location=(0,-.1,1.35);space.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
scene.render.filepath=str(ART/'bigfoot-walk-pose.png')
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET));bpy.ops.render.render(write_still=True)
print('BIGFOOT_RIG_VALIDATED',json.dumps(report))
