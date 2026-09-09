"""Author a dedicated stone performance on a new copy of the existing Bigfoot rig.
Blender --background --python tools/animate_bigfoot_stone.py
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
    crouch=envelope(t,.05,.85,1.15,1.9)
    load=envelope(t,1.65,2.5,2.55,3.15)
    send=envelope(t,2.55,3.02,3.15,4.2)
    translation('Pelvis',(0,.055*crouch-.045*send,-.026-.38*crouch-.045*load))
    rotate('Spine',(1,0,0),.75*crouch-.08*load+.19*send)
    rotate('Spine',(0,0,1),-.22*load+.25*send)
    rotate('Head',(1,0,0),-.10*crouch-.05*load)
    rotate('Head',(0,0,1),.12*load-.08*send)
    rotate('UpperArm_R',(1,0,0),-.4*crouch-.45*load-1.0*send)
    rotate('Forearm_R',(1,0,0),-.35*crouch-1.25*load-.35*send)
    rotate('UpperArm_L',(1,0,0),-.18*crouch-.25*load+.2*send)
    rotate('Forearm_L',(1,0,0),-.35*crouch-.45*load-.15*send)
    grip=envelope(t,.7,1.05,2.85,3.12)
    for finger in range(1,5):
        rotate(f'Finger_R_{finger}',(1,0,0),.62*grip)
        rotate(f'Finger_R_{finger}_Tip',(1,0,0),.48*grip)

clips={'StoneHeave':4.2}
report={'clips':{},'events':{'grasp':1.05,'release':2.95}}
for name,duration in clips.items():
    action=bpy.data.actions.new(name)
    action.use_fake_user=True
    rig.animation_data.action=action
    for frame in range(round(duration*30)+1):
        reset()
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
rig.animation_data.action=bpy.data.actions['StoneHeave']
scene.frame_start=1
scene.frame_end=127
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in meshes: obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bigfoot-stone.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bigfoot/zenscape-bigfoot-stone.blend'))
(ROOT/'docs/stone-animation/animation.json').write_text(json.dumps(report,indent=2)+'\n')
