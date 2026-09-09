"""Author a dedicated log performance on a new copy of the existing Bigfoot rig.
Blender --background --python tools/animate_bigfoot_log.py
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/bigfoot/zenscape-bigfoot-interactions.blend'))
scene=bpy.context.scene
rig=bpy.data.objects['Bigfoot_Rig']
meshes=[o for o in bpy.data.collections['EDIT - rigged Wanderer'].objects if o.type=='MESH']
scene.render.fps=30
def translation(name, xyz):
    rig.pose.bones[name].location = rig.data.bones[name].matrix_local.to_3x3().inverted() @ Vector(xyz)

def rotate(name, axis, angle):
    pb = rig.pose.bones[name]
    rest = rig.data.bones[name].matrix_local.to_quaternion()
    pb.rotation_quaternion = pb.rotation_quaternion @ (rest.inverted() @ Quaternion(Vector(axis), angle) @ rest)

def reset():
    for pb in rig.pose.bones:
        pb.location = (0,0,0)
        pb.rotation_mode = 'XYZ' if pb.name.startswith('Foot_CTRL_') else 'QUATERNION'
        pb.rotation_quaternion = (1,0,0,0)
        pb.rotation_euler = (0,0,0)
        pb.scale = (1,1,1)
    translation('Pelvis',(0,0,-.026))

def smooth(t):
    t = max(0,min(1,t))
    return t*t*(3-2*t)

def envelope(t, start, up, down, end):
    return smooth((t-start)/(up-start))*(1-smooth((t-down)/(end-down)))


def pose(name,t):
    if name=='LogLift':
        crouch=envelope(t,0.1,1.0,1.5,2.7)
        effort=envelope(t,1.1,1.6,2.1,3.1)
        shoulder=smooth((t-2.3)/1.5)
        translation('Pelvis',(0,.055*crouch,-.026-.24*crouch-.025*effort))
        rotate('Spine',(1,0,0),.40*crouch-.08*effort-.055*shoulder)
        rotate('Spine',(0,1,0),.045*shoulder)
        rotate('Head',(1,0,0),.12*crouch-.07*shoulder)
        for side,sign in [('R',-1),('L',1)]:
            rotate('UpperArm_'+side,(1,0,0),-.42*crouch-.7*effort-.50*shoulder)
            rotate('Forearm_'+side,(1,0,0),-.30*crouch-.9*effort-(1.05 if side=='R' else .15)*shoulder)
            rotate('UpperArm_'+side,(0,1,0),sign*.06*effort)
    elif name=='LogCarry':
        # The existing walk supplies the legs. Add restrained counterbalance,
        # not an entirely new walk cycle, to preserve the successful gait.
        rotate('Spine',(1,0,0),-.055)
        rotate('Spine',(0,1,0),.045)
        rotate('UpperArm_R',(1,0,0),-.50)
        rotate('Forearm_R',(1,0,0),-1.05)
        rotate('Head',(1,0,0),-.07)
    else:
        load=envelope(t,0,.30,.40,.8)
        send=envelope(t,.38,.72,.9,1.65)
        settle=smooth(t/1.8)
        translation('Pelvis',(0,.07*send,-.026-.07*load))
        rotate('Spine',(1,0,0),-.055*(1-settle)-.1*load+.18*send)
        rotate('Spine',(0,1,0),.045*(1-settle))
        rotate('Head',(1,0,0),-.07*(1-settle)+.03*send)
        for side in ['R','L']:
            rotate('UpperArm_'+side,(1,0,0),-.50*(1-settle)-.65*send)
            rotate('Forearm_'+side,(1,0,0),(-1.05 if side=='R' else -.15)*(1-settle)-.35*send)
    grip=smooth((t-.7)/.45) if name=='LogLift' else 1.0 if name=='LogCarry' else 1-smooth((t-.72)/.25)
    for side in ['R','L']:
        for finger in range(1,5):
            rotate(f'Finger_{side}_{finger}',(1,0,0),.48*grip)
            rotate(f'Finger_{side}_{finger}_Tip',(1,0,0),.38*grip)

walk=bpy.data.actions['Walk']
walk_duration=(walk.frame_range[1]-walk.frame_range[0])/30
# Bake the source stride before authoring the loaded upper body.
walk_samples=[]
for frame in range(round(walk_duration*30)+1):
    rig.animation_data.action=walk
    scene.frame_set(round(walk.frame_range[0])+frame)
    walk_samples.append({p.name:(p.location.copy(),p.rotation_quaternion.copy(),p.rotation_euler.copy(),p.rotation_mode) for p in rig.pose.bones})
clips={'LogLift':4.2,'LogCarry':walk_duration,'LogToss':1.8}
report={'clips':{},'events':{'grasp':1.15,'shoulder':3.8,'release_in_toss':.78}}
for name,duration in clips.items():
    action=bpy.data.actions.new(name)
    action.use_fake_user=True
    rig.animation_data.action=action
    for frame in range(round(duration*30)+1):
        reset()
        if name=='LogCarry':
            for pb in rig.pose.bones:
                loc,quat,euler,mode=walk_samples[frame][pb.name]
                pb.rotation_mode=mode
                pb.location=loc
                pb.rotation_quaternion=quat
                pb.rotation_euler=euler
        pose(name,frame/30)
        for pb in rig.pose.bones:
            pb.keyframe_insert('location',frame=frame+1,group=pb.name)
            pb.keyframe_insert('rotation_euler' if pb.rotation_mode=='XYZ' else 'rotation_quaternion',frame=frame+1,group=pb.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    report['clips'][name]={'duration':duration,'frames':round(duration*30)+1}
rig.animation_data.action=bpy.data.actions['LogLift']
scene.frame_start=1
scene.frame_end=127
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in meshes: obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bigfoot-log.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bigfoot/zenscape-bigfoot-log.blend'))
(ROOT/'docs/log-animation/animation.json').write_text(json.dumps(report,indent=2)+'\n')
