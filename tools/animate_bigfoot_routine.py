"""Author daily-life actions on a copy; existing authored interactions stay intact.
Blender --background --python tools/animate_bigfoot_routine.py [-- --replace-generated]
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT/'art/blender/bigfoot/zenscape-bigfoot-routine.blend'
EXPORT = ROOT/'assets/models/zenscape-bigfoot-routine.glb'
REPORT = ROOT/'docs/fidelity-life/routine-animation-validation.json'
if TARGET.exists() and '--replace-generated' not in sys.argv:
    raise RuntimeError('Preserve authored routine; explicitly regenerate only this generated copy.')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/bigfoot/zenscape-bigfoot-interactions.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['Bigfoot_Rig']
meshes = [o for o in bpy.data.collections['EDIT - rigged Wanderer'].objects if o.type == 'MESH']
scene.render.fps = 30

def translation(name, xyz):
    rig.pose.bones[name].location = rig.data.bones[name].matrix_local.to_3x3().inverted() @ Vector(xyz)

def rotate(name, axis, angle):
    pb = rig.pose.bones[name]
    rest = rig.data.bones[name].matrix_local.to_quaternion()
    pb.rotation_quaternion = rest.inverted() @ Quaternion(Vector(axis), angle) @ rest

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

def seated(weight, breath=0, asleep=0):
    translation('Pelvis',(0,.18*weight,-.026-.78*weight+breath))
    rotate('Spine',(1,0,0),(.10+.22*asleep)*weight)
    rotate('Head',(1,0,0),(.05+.30*asleep)*weight)
    for side,sign in [('R',-1),('L',1)]:
        translation('Foot_CTRL_'+side,(sign*.08*weight,-.48*weight,.015*weight))
        rotate('UpperArm_'+side,(1,0,0),(-.10-.15*asleep)*weight)
        rotate('Forearm_'+side,(1,0,0),(-1.05-.30*asleep)*weight)
        rotate('Hand_'+side,(1,0,0),.22*weight)

def pose(name, seconds, duration):
    t = seconds/duration
    if name in ['SitDown','Sit','StandUp','Sleep']:
        weight = smooth(t) if name == 'SitDown' else 1-smooth(t) if name == 'StandUp' else 1
        breath = .008*math.sin(math.tau*t) if name in ['Sit','Sleep'] else 0
        seated(weight,breath,1 if name == 'Sleep' else 0)
        if name == 'Sit': rotate('Head',(0,0,1),.16*math.sin(math.tau*t))
    elif name in ['StoneThrow','FishCatch']:
        bend = envelope(seconds,0,.9,1.4,2.2)
        translation('Pelvis',(0,(-.20 if name == 'FishCatch' else .06)*bend,-.026-(.55 if name == 'FishCatch' else .20)*bend))
        rotate('Spine',(1,0,0),(.95 if name == 'FishCatch' else .75)*bend)
        rotate('Head',(1,0,0),-.15*bend)
        lift = envelope(seconds,1.4,2.3,2.65,3.2)
        swing = envelope(seconds,2.7,2.95,3.05,3.8) if name == 'StoneThrow' else 0
        rotate('UpperArm_R',(1,0,0),-.50*bend+1.10*lift-1.95*swing)
        rotate('Forearm_R',(1,0,0),-.65*bend-1.45*lift-.25*swing)
        rotate('UpperArm_L',(1,0,0),-.65*bend-.28*lift)
        rotate('Forearm_L',(1,0,0),(-1.25 if name == 'FishCatch' else -.65)*bend-.35*lift)
        rotate('Spine',(0,0,1),-.20*lift+.25*swing) if bend < .01 else None
        grip = envelope(seconds,.85,1.1,2.8,3.1)
        for finger in range(1,5):
            rotate(f'Finger_R_{finger}',(1,0,0),.65*grip)
            rotate(f'Finger_R_{finger}_Tip',(1,0,0),.50*grip)
        if name == 'FishCatch':
            hold = envelope(seconds,1.6,2.2,3.2,4.3)
            rotate('UpperArm_R',(1,0,0),-.50*bend-.65*hold)
            rotate('Forearm_R',(1,0,0),-.65*bend-1.15*hold)
            rotate('Head',(1,0,0),.2*hold)
    elif name == 'TreeShake':
        grip = envelope(seconds,0,.75,3.4,4.1)
        shake = math.sin((seconds-.8)*math.tau*2.8)*envelope(seconds,.75,1,3.1,3.4)
        translation('Pelvis',(0,.035*shake,-.026-.035*grip))
        rotate('Spine',(1,0,0),(.06+.035*shake)*grip)
        for side,sign in [('R',-1),('L',1)]:
            rotate('UpperArm_'+side,(1,0,0),(-.95+.06*shake)*grip)
            rotate('Forearm_'+side,(1,0,0),(-.55-.10*shake)*grip)
            for finger in range(1,5):
                rotate(f'Finger_{side}_{finger}',(1,0,0),.65*grip)
                rotate(f'Finger_{side}_{finger}_Tip',(1,0,0),.5*grip)

clips = {'SitDown':1.4,'Sit':4.0,'StandUp':1.5,'Sleep':6.0,'StoneThrow':4.2,'TreeShake':4.2,'FishCatch':4.8}
report = {'source':'zenscape-bigfoot-interactions.blend','clips':{},'events':{'StoneThrow':{'grasp':1.05,'release':2.95},'TreeShake':{'grip':.8,'release':3.4},'FishCatch':{'grasp':1.05,'return':3.4}}}
for name,duration in clips.items():
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    frames = round(duration*30)
    for frame in range(frames+1):
        reset()
        pose(name,frame/30,duration)
        for pb in rig.pose.bones:
            pb.keyframe_insert('location',frame=frame+1,group=pb.name)
            pb.keyframe_insert('rotation_euler' if pb.rotation_mode=='XYZ' else 'rotation_quaternion',frame=frame+1,group=pb.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    floor = float('inf')
    foot_floor = float('inf')
    lowest = None
    hands = {}
    for frame in range(0,frames+1,3):
        scene.frame_set(frame+1)
        bpy.context.view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()
        evaluated_rig = rig.evaluated_get(deps)
        if frame in [30,33,87,90]:
            hands[str(frame/30)] = {side:list(evaluated_rig.pose.bones['Hand_'+side].tail) for side in ['R','L']}
        for obj in meshes:
            ev = obj.evaluated_get(deps)
            mesh = ev.to_mesh()
            value = min((ev.matrix_world@v.co).z for v in mesh.vertices)
            if any(g.name in ['Foot_R','Foot_L'] for g in obj.vertex_groups): foot_floor = min(foot_floor,value)
            if value < floor:
                floor = value
                lowest = (frame/30,obj.name)
            ev.to_mesh_clear()
    assert foot_floor > -.008, (name, 'foot penetration', foot_floor)
    # Fishing reaches below the bank into water; dry-ground actions never do.
    assert floor > (-.6 if name == 'FishCatch' else -.008), (name, 'floor penetration', floor, lowest)
    report['clips'][name] = {'duration':duration,'minimum_height':floor,'minimum_foot_height':foot_floor,'hand_tips_blender':hands}
    print('ROUTINE CLIP',name,'floor',floor,flush=True)
rig.animation_data.action = bpy.data.actions['Sit']
scene.frame_start=1
scene.frame_end=120
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in meshes: obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(EXPORT),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
    export_frame_range=False,export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
REPORT.write_text(json.dumps(report,indent=2)+'\n')
print('ROUTINE EXPORT',EXPORT,flush=True)
