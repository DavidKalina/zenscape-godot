"""Create the first blocky-bear rig and loop from the approved static source.
Run with Blender --background --python tools/rig_bear.py. Never overwrites an
existing authored rig; subsequent animation edits belong in the .blend file.
"""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'art/blender/bear'
TARGET = ART / 'zenscape-bear-walk.blend'
if TARGET.exists():
    raise RuntimeError('Rig already exists; edit it in Blender instead of regenerating it.')
bpy.ops.wm.open_mainfile(filepath=str(ART / 'zenscape-bear-blocky.blend'))
scene = bpy.context.scene
collection = bpy.data.collections['EDIT - blocky bear']
collection.name = 'EDIT - rigged bear'
meshes = [o for o in collection.objects if o.type == 'MESH']

arm = bpy.data.armatures.new('Bear Skeleton')
rig = bpy.data.objects.new('Bear_Rig', arm)
collection.objects.link(rig)
rig.show_in_front = True
arm.display_type = 'OCTAHEDRAL'
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')

def bone(name, head, tail, parent=None, deform=True):
    b = arm.edit_bones.new(name)
    b.head, b.tail = head, tail
    b.use_deform = deform
    if parent:
        b.parent = arm.edit_bones[parent]
    return b

bone('Root', (0,0,0), (0,0,.18), deform=False)
bone('Body', (0,0,.48), (0,-.38,.50), 'Root')
bone('Head', (0,-.64,.56), (0,-.96,.56), 'Body')
bone('Tail', (0,.60,.48), (0,.74,.48), 'Body')
legs = []
for x, side in [(-.245,'R'),(.245,'L')]:
    for y, end in [(-.40,'Front'),(.40,'Rear')]:
        label = end + '_' + side
        hip = Vector((x,y,.45))
        knee = Vector((x,y + (.10 if end=='Front' else -.10),.26))
        ankle = Vector((x,y,.068))
        bone('Upper_'+label,hip,knee,'Body')
        bone('Lower_'+label,knee,ankle,'Upper_'+label)
        bone('Paw_'+label,ankle,ankle+Vector((0,-.16,0)),'Lower_'+label)
        bone('Foot_CTRL_'+label,ankle,ankle+Vector((0,-.16,0)),'Root',False)
        pole = knee + Vector((0,.6 if end=='Front' else -.6,0))
        bone('Knee_CTRL_'+label,pole,pole+Vector((0,0,.12)),'Root',False)
        legs.append(dict(label=label,home=ankle,knee=knee,offset=0 if side=='L' else .5))
bpy.ops.object.mode_set(mode='OBJECT')

# Preserve the accepted faceted silhouette. Add only transverse knee rings so
# deformation can bend the leg without stretching a single tall quad.
for obj in meshes:
    world = obj.matrix_world.copy()
    if obj.name.startswith('Bear_Leg_'):
        bm = bmesh.new(); bm.from_mesh(obj.data)
        inv = world.inverted()
        for height in [.20,.28,.36]:
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                dist=1e-6,plane_co=inv@Vector((0,0,height)),
                plane_no=world.to_3x3().transposed()@Vector((0,0,1)),
                clear_inner=False,clear_outer=False)
        bm.to_mesh(obj.data); bm.free(); obj.data.update()
        label = obj.name.removeprefix('Bear_Leg_')
        upper = obj.vertex_groups.new(name='Upper_'+label)
        lower = obj.vertex_groups.new(name='Lower_'+label)
        for v in obj.data.vertices:
            z = (world @ v.co).z
            w = max(0,min(1,(z-.20)/.16))
            if w>0: upper.add([v.index],w,'REPLACE')
            if w<1: lower.add([v.index],1-w,'REPLACE')
    else:
        if obj.name.startswith('Bear_Paw_'):
            name = 'Paw_'+obj.name.removeprefix('Bear_Paw_')
        elif obj.name=='Bear_Body': name='Body'
        elif obj.name=='Bear_Tail': name='Tail'
        else: name='Head'
        obj.vertex_groups.new(name=name).add(list(range(len(obj.data.vertices))),1,'REPLACE')
    mod = obj.modifiers.new('Bear skin','ARMATURE'); mod.object=rig
    obj.parent=rig; obj.matrix_world=world

for leg in legs:
    label=leg['label']
    ik=rig.pose.bones['Lower_'+label].constraints.new('IK')
    ik.name='Planted paw - two bone IK';ik.target=rig;ik.subtarget='Foot_CTRL_'+label
    ik.pole_target=rig;ik.pole_subtarget='Knee_CTRL_'+label;ik.chain_count=2
    ik.use_stretch=False
    rig.pose.bones['Upper_'+label].ik_stretch=0
    rig.pose.bones['Lower_'+label].ik_stretch=0
    # Match each pole angle to this leg's rest bend, independently of bone roll.
    options=[]
    for angle in [0,math.pi/2,-math.pi/2,math.pi]:
        ik.pole_angle=angle;bpy.context.view_layer.update()
        evaluated=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
        options.append(((evaluated.pose.bones['Upper_'+label].tail-leg['knee']).length,angle))
    ik.pole_angle=min(options)[1]
    copy=rig.pose.bones['Paw_'+label].constraints.new('COPY_ROTATION')
    copy.name='Keep sole level during stance';copy.target=rig;copy.subtarget='Foot_CTRL_'+label
    copy.target_space='POSE';copy.owner_space='POSE'

FPS=30
FRAMES=48
DUTY=.72
STRIDE=.30
DURATION=FRAMES/FPS
SPEED=STRIDE/(DUTY*DURATION)
scene.render.fps=FPS
scene.frame_start=1;scene.frame_end=FRAMES
rig.animation_data_create()
action=bpy.data.actions.new('Walk')
rig.animation_data.action=action

def local_delta(name,delta):
    return arm.bones[name].matrix_local.to_3x3().inverted() @ Vector(delta)

def foot_target(leg,phase):
    u=(phase+leg['offset'])%1
    home=leg['home']
    if u<DUTY:
        return home+Vector((0,-STRIDE/2+STRIDE*u/DUTY,0)),0,u
    s=(u-DUTY)/(1-DUTY)
    # Hermite swing matches stance velocity at both contacts.
    slope=STRIDE*(1-DUTY)/DUTY
    y=(2*s**3-3*s**2+1)*STRIDE/2+(s**3-2*s*s+s)*slope+(-2*s**3+3*s*s)*(-STRIDE/2)+(s**3-s*s)*slope
    lift=.072*math.sin(math.pi*s)**2
    pitch=.16*math.sin(2*math.pi*s)*math.sin(math.pi*s)
    return home+Vector((0,y,lift)),pitch,u

for frame in range(1,FRAMES+2):
    phase=(frame-1)/FRAMES
    for leg in legs:
        name='Foot_CTRL_'+leg['label']
        p,pitch,u=foot_target(leg,phase)
        pb=rig.pose.bones[name]
        pb.location=local_delta(name,p-leg['home'])
        pb.rotation_mode='XYZ';pb.rotation_euler=(pitch,0,0)
        pb.keyframe_insert('location',frame=frame,group=name)
        pb.keyframe_insert('rotation_euler',frame=frame,group=name)
    body=rig.pose.bones['Body'];body.rotation_mode='XYZ'
    body.location=local_delta('Body',(.012*math.sin(math.tau*phase),0,-.009+.007*math.cos(2*math.tau*phase)))
    body.rotation_euler=(.008*math.sin(2*math.tau*phase),.022*math.sin(math.tau*phase),0)
    body.keyframe_insert('location',frame=frame,group='Body')
    body.keyframe_insert('rotation_euler',frame=frame,group='Body')
    head=rig.pose.bones['Head'];head.rotation_mode='XYZ'
    head.rotation_euler=(.018*math.sin(2*math.tau*phase+.4),-.012*math.sin(math.tau*phase),.014*math.sin(math.tau*phase+.6))
    head.keyframe_insert('rotation_euler',frame=frame,group='Head')
    tail=rig.pose.bones['Tail'];tail.rotation_mode='XYZ'
    tail.rotation_euler=(0,0,.03*math.sin(math.tau*phase))
    tail.keyframe_insert('rotation_euler',frame=frame,group='Tail')
# Dense baked control keys use linear interpolation to retain exact stance speed.
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for fc in bag.fcurves:
                for key in fc.keyframe_points:key.interpolation='LINEAR'

# Numeric checks: IK targets, weight coverage, world-space stance slip, loop seam.
max_target_error=0;max_slip=0
anchors={};first=None;last=None
for frame in range(1,FRAMES+2):
    scene.frame_set(frame);bpy.context.view_layer.update()
    evaluated=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
    phase=(frame-1)/FRAMES
    poses={b.name:list(v for row in b.matrix for v in row) for b in evaluated.pose.bones if b.bone.use_deform}
    if frame==1:first=poses
    if frame==FRAMES+1:last=poses
    for leg in legs:
        p,pitch,u=foot_target(leg,phase)
        actual=evaluated.pose.bones['Paw_'+leg['label']].head.copy()
        max_target_error=max(max_target_error,(actual-p).length)
        world=actual+Vector((0,-SPEED*(frame-1)/FPS,0))
        if u<DUTY:
            # Treat wrapped stance intervals as separate contacts.
            contact=math.floor(phase+leg['offset'])
            key=(leg['label'],contact)
            if key not in anchors:anchors[key]=world
            max_slip=max(max_slip,(world-anchors[key]).length)
for obj in meshes:
    for v in obj.data.vertices:
        assert abs(sum(g.weight for g in v.groups)-1)<1e-5, (obj.name,v.index)
seam=max(abs(a-b) for name in first for a,b in zip(first[name],last[name]))
assert max_target_error<.003, f'IK target error: {max_target_error}'
assert max_slip<.003, f'Planted paw slipped: {max_slip}'
assert seam<1e-4,f'Loop seam: {seam}'
report=dict(animation='Walk',duration_seconds=DURATION,fps=FPS,frames=FRAMES,
    intended_forward_speed_mps=SPEED,direction='Godot +Z / Blender -Y',
    duty_factor=DUTY,foot_lift_m=.072,max_ik_target_error_m=max_target_error,
    max_stance_slip_m=max_slip,max_loop_matrix_delta=seam,
    bones=len(arm.bones),deform_bones=sum(b.use_deform for b in arm.bones),
    mesh_objects=len(meshes),scope='In-place flat-ground walk. Game terrain IK and behavior not integrated.')
(ART/'walk-validation.json').write_text(json.dumps(report,indent=2)+'\n')
rig['walk_speed_mps']=SPEED
rig['walk_cycle_seconds']=DURATION
rig['instructions']='Space plays Walk. Pose Mode: move Foot_CTRL bones; Knee_CTRL sets bend direction. Root moves whole animal. Flat terrain only.'
# The closing key is exported at frame 49; the Blender playback range omits the
# duplicate endpoint so Space loops without an extra held frame.
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bear-walk.glb'),
    export_format='GLB',use_selection=True,export_animations=True,
    export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,
    export_anim_slide_to_zero=True,
    export_def_bones=True,export_skins=True)
# Open the rig in material preview; bones can be toggled with viewport overlays.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
scene.render.filepath=str(ART/'bear-walk-pose.png')
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
bpy.ops.render.render(write_still=True)
print('BEAR_RIG_VALIDATED',json.dumps(report))
