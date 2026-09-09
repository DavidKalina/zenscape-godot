"""Author Walk/Idle personality on a new editable copy of the breathing rig.
Blender --background --python tools/animate_bigfoot_personality.py
Only this worktree's personality outputs are regenerated; original sources stay intact.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'art/blender/bigfoot'
bpy.ops.wm.open_mainfile(filepath=str(ART/'zenscape-bigfoot-breathing.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['Bigfoot_Rig']
work = bpy.data.collections['EDIT - rigged Wanderer']
meshes = [o for o in work.objects if o.type == 'MESH']
scene.render.fps = 30
# Explicit pose beats, with holds encoded by equal successive values.
def curve(t, keys):
    for (a,x),(b,y) in zip(keys,keys[1:]):
        if t <= b:
            u = max(0,min(1,(t-a)/(b-a)))
            return x+(y-x)*u*u*(3-2*u)
    return keys[-1][1]
def move(name, xyz):
    rig.pose.bones[name].location = rig.data.bones[name].matrix_local.to_3x3().inverted() @ Vector(xyz)
def rotate(name, axis, angle):
    pb = rig.pose.bones[name]
    rest = rig.data.bones[name].matrix_local.to_quaternion()
    pb.rotation_quaternion = pb.rotation_quaternion @ (rest.inverted() @ Quaternion(Vector(axis),angle) @ rest)
def reset():
    for pb in rig.pose.bones:
        pb.location=(0,0,0);pb.scale=(1,1,1)
        pb.rotation_mode='XYZ' if pb.name.startswith('Foot_CTRL_') else 'QUATERNION'
        pb.rotation_quaternion=(1,0,0,0);pb.rotation_euler=(0,0,0)
def fingers(side, curl):
    for f in range(1,5):
        rotate(f'Finger_{side}_{f}',(1,0,0),curl*(0.8+f*.09))
        rotate(f'Finger_{side}_{f}_Tip',(1,0,0),curl*.65)
DURATION=3.6;DUTY=.62;STRIDE=.54;SPEED=STRIDE/(DUTY*DURATION)
def walk(t):
    phase=(t/DURATION)%1
    step=(phase*2)%1
    # Contact, compression, rise, held high point, and weight into the next foot.
    height=curve(step,[(0,-.055),(.13,-.115),(.40,-.035),(.62,-.020),(.80,-.028),(1,-.055)])
    move('Pelvis',(-.065*math.sin(math.tau*phase),0,height))
    rotate('Pelvis',(0,0,1),.060*math.sin(math.tau*phase))
    rotate('Pelvis',(0,1,0),.030*math.sin(math.tau*phase))
    rotate('Spine',(0,0,1),-.075*math.sin(math.tau*phase-.40))
    rotate('Spine',(0,1,0),-.045*math.sin(math.tau*phase-.48))
    rotate('Spine',(1,0,0),.045+.028*math.sin(math.tau*step-.6))
    rotate('Head',(0,0,1),.038*math.sin(math.tau*phase-.85))
    rotate('Head',(1,0,0),-.035-.020*math.sin(math.tau*step-1.0))
    for side,offset,sign in [('R',0,-1),('L',.5,1)]:
        u=(phase+offset)%1
        if u<DUTY:
            y=-STRIDE/2+STRIDE*u/DUTY;lift=0;pitch=0
        else:
            s=(u-DUTY)/(1-DUTY);slope=STRIDE*(1-DUTY)/DUTY
            y=(2*s**3-3*s*s+1)*STRIDE/2+(s**3-2*s*s+s)*slope+(-2*s**3+3*s*s)*(-STRIDE/2)+(s**3-s*s)*slope
            lift=.165*math.sin(math.pi*s)**2
            pitch=curve(s,[(0,0),(.23,.20),(.60,-.12),(.86,-.08),(1,0)])
        move('Foot_CTRL_'+side,(0,y,lift))
        rig.pose.bones['Foot_CTRL_'+side].rotation_euler.x=pitch
        # A soft elbow changes the silhouette; the forearm catches the shoulder
        # late, then opens as the arm falls back. Avoid an almost straight rod.
        arm_phase=(u-.035)%1
        swing=curve(arm_phase,[(0,1),(.12,.94),(.48,-1),(.60,-.96),(1,1)])
        rotate('UpperArm_'+side,(1,0,0),(.34 if side=='R' else .38)*swing)
        outward=curve(u,[(0,.10),(.28,.15),(.55,.12),(.78,.16),(1,.10)])
        rotate('UpperArm_'+side,(0,1,0),sign*outward)
        elbow=curve(u,[(0,.24),(.16,.13),(.32,.28),(.51,.61),(.64,.74),(.84,.42),(1,.24)])
        rotate('Forearm_'+side,(1,0,0),-elbow*(1.0 if side=='R' else .92))
        # Small outward arcs keep the long hands clear of the thighs. Wrist and
        # fingers trail the forearm's reversal, rather than sharing its curve.
        rotate('Forearm_'+side,(0,0,1),sign*.075*math.sin(math.tau*u-.9))
        wrist=curve(u,[(0,.08),(.22,.20),(.44,.045),(.64,-.18),(.82,-.07),(1,.08)])
        rotate('Hand_'+side,(1,0,0),wrist)
        rotate('Hand_'+side,(0,1,0),sign*.085*math.sin(math.tau*u-1.4))
        curl=curve(u,[(0,.12),(.30,.10),(.58,.24),(.72,.22),(1,.12)])
        fingers(side,curl)

def idle(t):
    # Three slow breaths underneath a 15.6-second sequence of attention.
    phase=(t/5.2)%1
    breath=curve(phase,[(0,0),(.4,1),(.9,0),(1,0)])
    weight=curve(t,[(0,0),(1.4,0),(2.3,.065),(5.7,.065),(6.5,-.045),(11.4,-.045),(12.6,0),(15.6,0)])
    move('Pelvis',(weight,0,-.075+.023*breath))
    rotate('Pelvis',(0,1,0),-weight*.42)
    rotate('Spine',(0,1,0),weight*.60)
    rotate('Spine',(1,0,0),.022*(1-breath))
    look=curve(t,[(0,0),(2.45,0),(2.72,-.28),(2.87,-.235),(4.4,-.235),(4.85,0),(8.0,0),(8.32,.34),(8.5,.29),(10.25,.29),(10.75,0),(15.6,0)])
    chest=curve(t,[(0,0),(2.75,0),(3.4,-.065),(4.45,-.065),(5.3,0),(8.45,0),(9.15,.065),(10.4,.065),(11.2,0),(15.6,0)])
    tilt=curve(t,[(0,0),(3.0,0),(3.5,.10),(4.35,.10),(4.9,0),(8.7,0),(9.2,-.09),(10.25,-.09),(10.85,0),(15.6,0)])
    rotate('Spine',(0,0,1),chest)
    rotate('Head',(0,0,1),look-chest)
    rotate('Head',(0,1,0),tilt)
    rotate('Head',(1,0,0),.014*(1-breath))
    for side,sign in [('R',-1),('L',1)]:
        rotate('UpperArm_'+side,(0,1,0),sign*(.045+.008*breath)-weight*.20)
        rotate('UpperArm_'+side,(1,0,0),(-.025 if side=='R' else .035)-chest*.28)
        rotate('Forearm_'+side,(1,0,0),-.10+.012*breath)
        rotate('Hand_'+side,(1,0,0),.025+weight*.45)
        uncurl=curve(t,[(0,0),(11.8,0),(12.15,1),(12.6,1),(13.15,0),(15.6,0)]) if side=='R' else 0
        fingers(side,.18-.12*uncurl)
def held(t):
    # Continuous, futile air-swimming. Feet scramble faster than the arms;
    # periodic tempo drift keeps the seamless loop from becoming a tidy exercise.
    cycle=t/7.2
    effort=math.sin(math.tau*cycle)
    roll=.10*math.sin(math.tau*(8*cycle)-.85)+.035*math.sin(math.tau*cycle)
    pitch=.065*math.sin(math.tau*(14*cycle)-1.1)
    rotate('Pelvis',(0,1,0),roll)
    rotate('Pelvis',(1,0,0),pitch)
    rotate('Spine',(0,1,0),-roll*.38)
    rotate('Spine',(1,0,0),-.045+.045*math.sin(math.tau*(8*cycle)-1.3))
    # Let the heavy body trail the paddling while the scalp stays at the cursor.
    bpy.context.view_layer.update()
    anchor=rig.data.bones['Head'].matrix_local.copy()
    anchor.translation.z-=.026
    correction=anchor.translation-rig.pose.bones['Head'].matrix.translation
    move('Pelvis',correction)
    bpy.context.view_layer.update()
    rig.pose.bones['Head'].matrix=anchor
    for side,sign,offset in [('R',-1,0),('L',1,.52)]:
        pedal=math.tau*(14*cycle+offset+.16*effort+.035*math.sin(math.tau*2*cycle+offset*math.tau))
        # Lift, reach, kick down and scramble back: a full foot loop, with floppy toes.
        move('Foot_CTRL_'+side,(sign*(.09+.045*math.sin(pedal-.65)),
             -.12-.40*math.sin(pedal),.40+.29*math.cos(pedal)))
        rig.pose.bones['Foot_CTRL_'+side].rotation_euler.x=.32*math.sin(pedal-.75)-.08
        rig.pose.bones['Foot_CTRL_'+side].rotation_euler.z=sign*.10*math.sin(pedal-1.2)
        # Arms scoop at nothing. Different stroke counts let them slip out of
        # coordination and briefly catch up, while feet never stop bicycling.
        paddle=((8 if side=='R' else 9)*cycle+offset+.13*effort)%1
        shoulder=curve(paddle,[(0,-1.05),(.18,-.65),(.48,.45),(.62,.25),(.80,-.80),(1,-1.05)])
        spread=curve(paddle,[(0,.50),(.22,.68),(.48,.38),(.67,.76),(.84,.60),(1,.50)])
        elbow=curve(paddle,[(0,.35),(.20,.70),(.48,.20),(.65,1.15),(.82,.95),(1,.35)])
        rotate('UpperArm_'+side,(0,1,0),-sign*spread)
        rotate('UpperArm_'+side,(1,0,0),shoulder)
        rotate('Forearm_'+side,(1,0,0),-elbow)
        wrist=curve(paddle,[(0,.16),(.25,-.30),(.50,-.12),(.70,.28),(.86,.20),(1,.16)])
        rotate('Hand_'+side,(1,0,0),wrist)
        rotate('Hand_'+side,(0,0,1),sign*(.12+.12*math.sin(math.tau*paddle-.7)))
        fingers(side,curve(paddle,[(0,.025),(.28,.22),(.55,.16),(.78,.04),(1,.025)]))

def rest_pose(name,t):
    weight=curve(t,[(0,0),(.25,.08),(.9,1.04),(1.4,1)]) if name=='SitDown' else curve(t,[(0,1),(.3,1.05),(1.2,.03),(1.5,0)]) if name=='StandUp' else 1
    asleep=name=='Sleep'
    phase=t/(6.0 if asleep else 8.0)
    breath=(1-math.cos(math.tau*phase))*.5 if name in ['Sit','Sleep'] else 0
    glance=curve(t,[(0,0),(1.4,0),(1.8,.22),(3.5,.22),(4.0,-.13),(5.8,-.13),(6.4,0),(8,0)]) if name=='Sit' else 0
    nod=curve(t,[(0,0),(2,.035),(3.7,.13),(4.25,.02),(6,0)]) if asleep else 0
    move('Pelvis',(.025*breath,.18*weight,-.026-.78*weight+.015*breath))
    rotate('Spine',(1,0,0),(.10+.22*asleep)*weight-.025*breath)
    rotate('Spine',(0,1,0),.025*breath)
    rotate('Head',(1,0,0),(.05+.30*asleep)*weight+nod-.02*breath)
    rotate('Head',(0,0,1),glance+.035*breath*asleep)
    for side,sign in [('R',-1),('L',1)]:
        move('Foot_CTRL_'+side,(sign*.08*weight,-.48*weight,.015*weight))
        rotate('UpperArm_'+side,(1,0,0),(-.10-.15*asleep)*weight-.025*breath)
        rotate('Forearm_'+side,(1,0,0),(-1.05-.30*asleep)*weight+.045*breath)
        rotate('Hand_'+side,(1,0,0),.22*weight+.04*breath)
        fingers(side,.10*weight+.045*breath)

def tremor(t):
    shock=curve(t,[(0,0),(.12,1),(.28,.65),(.55,.2),(1.2,0),(2.3,0)])
    wobble=curve(t,[(0,0),(.2,.30),(.52,-.24),(.9,.16),(1.3,-.07),(1.7,.02),(2.3,0)])
    recover=curve(t,[(0,0),(.1,.7),(.35,1),(.75,.55),(1.5,.15),(2.3,0)])
    move('Pelvis',(.06*wobble,0,-.026-.16*recover))
    rotate('Spine',(0,1,0),wobble)
    rotate('Spine',(1,0,0),.12*recover)
    rotate('Head',(0,1,0),-.65*wobble)
    rotate('Head',(1,0,0),-.17*shock)
    for side,sign in [('R',-1),('L',1)]:
        rotate('UpperArm_'+side,(0,1,0),-sign*(.65*recover+.22*shock))
        rotate('UpperArm_'+side,(1,0,0),-.25*recover+sign*.3*wobble)
        rotate('Forearm_'+side,(1,0,0),-.15-.55*recover-sign*.4*wobble)
        rotate('Hand_'+side,(1,0,0),.22*shock+sign*.3*wobble)
        fingers(side,-.10*shock)

def action_pose(name,t):
    if name=='LogCarry':
        walk(t)
        # Let the new gait carry the load, with the free arm still swinging.
        rotate('Spine',(1,0,0),-.06)
        rotate('Spine',(0,1,0),.065)
        for bone in ['UpperArm_R','Forearm_R','Hand_R']:
            rig.pose.bones[bone].rotation_quaternion=(1,0,0,0)
        rotate('UpperArm_R',(1,0,0),-.5)
        rotate('Forearm_R',(1,0,0),-1.05)
        return
    if name in ['StoneHeave','StoneThrow']:
        crouch=curve(t,[(0,0),(.15,.08),(.62,1),(1.18,1),(1.85,0),(4.2,0)])
        load=curve(t,[(0,0),(1.65,0),(2.35,1),(2.65,1),(2.98,0),(4.2,0)])
        send=curve(t,[(0,0),(2.65,0),(2.84,.35),(3.07,1),(3.28,.8),(4.2,0)])
        absorb=curve(t,[(0,0),(3.02,0),(3.22,1),(3.65,0),(4.2,0)])
        move('Pelvis',(.07*load-.055*send,.10*crouch+.045*load-.08*send,-.026-.42*crouch-.10*load-.075*absorb))
        rotate('Pelvis',(0,0,1),-.09*load+.09*send)
        rotate('Spine',(1,0,0),.66*crouch-.19*load+.33*send)
        rotate('Spine',(0,0,1),-.38*load+.36*send)
        rotate('Head',(1,0,0),-.14*crouch+.08*load-.10*send)
        rotate('Head',(0,0,1),.21*load-.13*send)
        rotate('UpperArm_R',(1,0,0),-.75*crouch-.50*load-1.15*send)
        rotate('Forearm_R',(1,0,0),-.12-.75*crouch-.90*load-.30*send)
        rotate('UpperArm_L',(1,0,0),-.70*crouch-.65*load+.48*send)
        rotate('UpperArm_L',(0,1,0),-.12*load-.18*send)
        rotate('Forearm_L',(1,0,0),-.12-.85*crouch-.35*load-.35*send)
        grip=curve(t,[(0,0),(.70,0),(1.05,1),(2.90,1),(3.04,0),(4.2,0)])
        fingers('R',.60*grip)
        fingers('L',.12)
    elif name=='LogLift':
        crouch=curve(t,[(0,0),(.18,.05),(.8,1),(1.15,1),(1.38,1.12),(1.95,.1),(2.3,0),(4.7,0)])
        lift=curve(t,[(0,0),(1.4,0),(2.15,1),(2.5,.9),(3.05,0),(4.7,0)])
        overhead=curve(t,[(0,0),(2.4,0),(3.05,1),(3.6,1),(4.25,0),(4.7,0)])
        receive=curve(t,[(0,0),(3.6,0),(4.1,1),(4.25,1),(4.7,.3)])
        shoulder=curve(t,[(0,0),(3.3,0),(4.4,1),(4.7,1)])
        move('Pelvis',(0,.09*crouch-.035*overhead,-.026-.43*crouch-.12*receive-.04*shoulder))
        rotate('Spine',(1,0,0),.62*crouch-.06*lift-.10*overhead-.06*shoulder+.10*receive)
        rotate('Spine',(0,1,0),.065*shoulder)
        rotate('Head',(1,0,0),-.12*crouch-.09*overhead-.025*shoulder)
        for side,sign in [('R',-1),('L',1)]:
            rotate('UpperArm_'+side,(1,0,0),-.85*crouch-.70*lift-1.45*overhead-.50*shoulder)
            rotate('UpperArm_'+side,(0,1,0),-sign*.16*overhead)
            rotate('Forearm_'+side,(1,0,0),-.12-.80*crouch-.85*lift-.35*overhead-(.95 if side=='R' else .1)*shoulder)
            fingers(side,.48*curve(t,[(0,0),(.65,0),(1.15,1),(4.7,1)]))
    elif name in ['LogToss','LogSlam']:
        power=1.25 if name=='LogSlam' else 1.0
        load=curve(t,[(0,0),(.24,.85),(.45,1),(.58,.85),(.79,0),(1.8,0)])
        send=curve(t,[(0,0),(.47,0),(.65,.20),(.78,.83),(.92,1),(1.15,.65),(1.8,0)])
        absorb=curve(t,[(0,0),(.88,0),(1.02,1),(1.32,0),(1.8,0)])
        settle=curve(t,[(0,0),(.95,0),(1.8,1)])
        move('Pelvis',(0,.07*load-.11*send,-.026-.04*(1-settle)-.14*load*power-.085*absorb))
        rotate('Spine',(1,0,0),-.06*(1-settle)-.16*load*power+.34*send*power)
        rotate('Spine',(0,0,1),-.12*load+.20*send)
        rotate('Spine',(0,1,0),.065*(1-settle))
        rotate('Head',(1,0,0),-.04*(1-settle)+.10*load-.09*send)
        for side in ['R','L']:
            rotate('UpperArm_'+side,(1,0,0),-.50*(1-settle)-.30*load-1.0*send if side=='R' else -.45*load+.5*send)
            rotate('Forearm_'+side,(1,0,0),(-1.05 if side=='R' else -.2)*(1-settle)-.25*send)
            fingers(side,.48*(1-curve(t,[(0,0),(.73,0),(.87,1),(1.8,1)])))
    elif name=='TreeShake':
        grip=curve(t,[(0,0),(.2,.12),(.65,1),(2.9,1),(3.02,0),(4.2,0)])
        # Sit back once and keep the pelvis there through the release. The
        # effort reads as a shoulder-led rope pull, never a pelvic thrust.
        brace=curve(t,[(0,0),(.65,1),(3.35,1),(4.2,0)])
        pull=curve(t,[(0,0),(.7,0),(1.35,.35),(2.35,1),(2.95,1),(3.45,0),(4.2,0)])
        recoil=curve(t,[(0,0),(2.95,0),(3.12,1),(3.5,.35),(3.9,0),(4.2,0)])
        move('Pelvis',(.045*brace,.18*brace,-.026-.15*brace))
        rotate('Spine',(1,0,0),.08*grip-.24*pull-.06*recoil)
        rotate('Spine',(0,0,1),.12*pull+.10*recoil)
        rotate('Spine',(0,1,0),.07*pull+.10*recoil)
        rotate('Head',(1,0,0),-.04*grip+.08*pull)
        rotate('Head',(0,0,1),-.10*pull-.06*recoil)
        for side,sign in [('R',-1),('L',1)]:
            rotate('UpperArm_'+side,(1,0,0),-1.0*grip-.85*recoil)
            rotate('UpperArm_'+side,(0,1,0),-sign*.32*recoil)
            rotate('Forearm_'+side,(1,0,0),-.15-.65*pull-.35*grip-.55*recoil)
            fingers(side,.55*grip)

# The source rig already contains TreeShake. Remove it before authoring so
# Blender does not suffix the replacement and export the stale source action.
for name in ['TreeShake','SitDown','Sit','StandUp','Sleep','Tremor']:
    if bpy.data.actions.get(name): bpy.data.actions.remove(bpy.data.actions[name])
report={}
for name,duration,pose in [('PersonalityWalk',3.6,walk),('PersonalityIdle',15.6,idle),('PersonalityHeld',7.2,held),('Tremor',2.3,tremor)]+[(n,d,lambda t,n=n: rest_pose(n,t)) for n,d in [('SitDown',1.4),('Sit',8.0),('StandUp',1.5),('Sleep',6.0)]]+[(n,d,lambda t,n=n: action_pose(n,t)) for n,d in [('StoneHeave',4.2),('StoneThrow',4.2),('LogLift',4.7),('LogCarry',3.6),('LogToss',1.8),('LogSlam',1.8),('TreeShake',4.2)]]:
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
    frames=round(duration*30)
    for frame in range(frames+1):
        reset();pose(frame/30)
        for pb in rig.pose.bones:
            pb.keyframe_insert('location',frame=frame+1,group=pb.name)
            pb.keyframe_insert('rotation_euler' if pb.rotation_mode=='XYZ' else 'rotation_quaternion',frame=frame+1,group=pb.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points:key.interpolation='LINEAR'
    first=None;anchors={};slip=0;floor=1e6;head=[]
    for frame in range(frames+1):
        scene.frame_set(frame+1);bpy.context.view_layer.update()
        deps=bpy.context.evaluated_depsgraph_get();ev=rig.evaluated_get(deps)
        values=[v for pb in ev.pose.bones if pb.bone.use_deform for row in pb.matrix for v in row]
        if first is None:first=values
        if frame==frames: seam=max(abs(a-b) for a,b in zip(first,values))
        head.append(ev.pose.bones['Head'].matrix.translation.z)
        for side,offset in [('R',0),('L',.5)]:
            phase=(frame/30)/3.6+offset
            planted=name=='PersonalityIdle' or (name=='PersonalityWalk' and phase%1<DUTY)
            if planted:
                position=ev.pose.bones['Foot_'+side].matrix.translation.copy()
                if name=='PersonalityWalk':position.y-=SPEED*frame/30
                key=(side,math.floor(phase) if name=='PersonalityWalk' else 0)
                if key not in anchors:anchors[key]=position
                slip=max(slip,(position-anchors[key]).length)
        if frame%3==0:
            for obj in meshes:
                evmesh=obj.evaluated_get(deps);mesh=evmesh.to_mesh()
                floor=min(floor,min((evmesh.matrix_world@v.co).z for v in mesh.vertices))
                evmesh.to_mesh_clear()
    report[name]={'seconds':duration,'stance_slip':slip,'floor':floor,'seam':seam,'head_range':max(head)-min(head)}
    print(name,report[name],flush=True)
    assert slip<.003,(name,'stance slips',slip)
    assert floor>-.012,(name,'floor penetration',floor)
    if name in ['PersonalityWalk','PersonalityIdle','PersonalityHeld','LogCarry','Sit','Sleep']: assert seam<.0001,(name,'loop seam',seam)
# Export only the new clips; source geometry makes the export retargetable.
rig.animation_data.action=None
for action in list(bpy.data.actions):
    if action.name not in ['PersonalityWalk','PersonalityIdle','PersonalityHeld','StoneHeave','StoneThrow','LogLift','LogCarry','LogToss','LogSlam','TreeShake','SitDown','Sit','StandUp','Sleep','Tremor']:bpy.data.actions.remove(action)
rig.animation_data.action=bpy.data.actions['PersonalityWalk']
scene.frame_start=1;scene.frame_end=108;scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bigfoot-personality.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'zenscape-bigfoot-personality.blend'))
(ROOT/'docs/tree-personality/bigfoot-validation.json').write_text(json.dumps(report,indent=2)+'\n')
