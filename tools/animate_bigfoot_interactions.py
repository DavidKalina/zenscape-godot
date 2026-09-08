"""Author Bigfoot interaction actions on a copy of the classic Blender rig.

Run with Blender --background --python tools/animate_bigfoot_interactions.py.
The classic source is never modified. Regeneration needs --replace-generated;
do not use that flag after manually editing the resulting Blender file.
"""
import bpy
import json
import math
import struct
import sys
from pathlib import Path
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'art/blender/bigfoot/zenscape-bigfoot-interactions.blend'
EXPORT = ROOT / 'assets/models/zenscape-bigfoot-interactions.glb'
REPORT = ROOT / 'docs/bigfoot-playground/animation-validation.json'
if TARGET.exists() and '--replace-generated' not in sys.argv:
    raise RuntimeError('Preserve authored interactions; regeneration requires --replace-generated.')
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/blender/bigfoot/zenscape-bigfoot-classic.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['Bigfoot_Rig']
work = bpy.data.collections['EDIT - rigged Wanderer']
meshes = [o for o in work.objects if o.type == 'MESH']
walk = rig.animation_data.action
assert walk.name == 'Walk'
walk.use_fake_user = True
FPS = 30
scene.render.fps = FPS

def translation(name, xyz):
    rig.pose.bones[name].location = rig.data.bones[name].matrix_local.to_3x3().inverted() @ Vector(xyz)

def rotate(name, axis, angle):
    pb = rig.pose.bones[name]
    rest = rig.data.bones[name].matrix_local.to_quaternion()
    pb.rotation_quaternion = rest.inverted() @ Quaternion(Vector(axis), angle) @ rest

def reset():
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_mode = 'XYZ' if pb.name.startswith('Foot_CTRL_') else 'QUATERNION'
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)

def idle(phase):
    breath = math.sin(math.tau * phase)
    translation('Pelvis', (0, 0, -.026 + .006 * breath))
    rotate('Spine', (1, 0, 0), .008 * breath)
    rotate('Head', (0, 0, 1), .022 * math.sin(math.tau * phase))
    for side, sign in [('R', -1), ('L', 1)]:
        rotate('UpperArm_' + side, (0, 1, 0), sign * .025)
        rotate('Forearm_' + side, (1, 0, 0), -.025 + .009 * breath)

clips = [('Idle', 120), ('Held', 90), ('Land', 21), ('Alert', 36)]
report = {'fps': FPS, 'forward': 'Godot +Z / Blender -Y', 'clips': {}, 'source': 'zenscape-bigfoot-classic.blend'}
for name, frames in clips:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in range(1, frames + 2):
        t = (frame - 1) / frames
        reset()
        idle(t if name == 'Idle' else 0)
        if name == 'Held':
            # The cursor holds the scalp. Keep the head/spine fixed while
            # different limb rhythms make his suspended struggle feel playful.
            for side, sign, offset, frequency in [('R', -1, .15, 2), ('L', 1, .63, 3)]:
                phase = math.tau * (frequency * t + offset)
                flail = math.sin(phase)
                rest = rig.data.bones['UpperArm_' + side].matrix_local.to_quaternion()
                outward = Quaternion(Vector((0, 1, 0)), -sign * (.68 + .30 * flail))
                reach = Quaternion(Vector((1, 0, 0)), -.23 + .34 * math.cos(phase))
                rig.pose.bones['UpperArm_' + side].rotation_quaternion = rest.inverted() @ reach @ outward @ rest
                rotate('Forearm_' + side, (1, 0, 0), -.38 - .27 * math.sin(phase + .8))
                rotate('Hand_' + side, (0, 1, 0), sign * .17 * math.sin(phase - .5))
                translation('Foot_CTRL_' + side,
                            (sign * (.035 + .035 * math.sin(phase + .5)),
                             -.12 + .22 * math.cos(phase + .7),
                             .24 + .14 * math.sin(phase + .3)))
                rig.pose.bones['Foot_CTRL_' + side].rotation_euler.x = -.10 + .13 * math.cos(phase)
                for finger in range(1, 5):
                    rotate(f'Finger_{side}_{finger}', (1, 0, 0), .12 + .10 * math.sin(phase + finger * .3))
                    rotate(f'Finger_{side}_{finger}_Tip', (1, 0, 0), .16)
        elif name == 'Land':
            # Quick weight absorption, then an unhurried return to the standing pose.
            squash = math.sin(math.pi * min(t / .28, 1) / 2) if t < .28 else (1 - (t - .28) / .72) ** 2
            translation('Pelvis', (0, -.035 * squash, -.026 - .16 * squash))
            rotate('Spine', (1, 0, 0), .12 * squash)
            rotate('Head', (1, 0, 0), -.09 * squash)
            for side, sign in [('R', -1), ('L', 1)]:
                rotate('UpperArm_' + side, (0, 1, 0), sign * (.025 + .12 * squash))
                rotate('Forearm_' + side, (1, 0, 0), -.025 - .16 * squash)
        elif name == 'Alert':
            notice = math.sin(math.pi * t) ** 2
            rotate('Head', (0, 0, 1), .24 * notice)
            rotate('Spine', (0, 0, 1), .055 * notice)
            translation('Pelvis', (0, 0, -.026 + .012 * notice))
        for pb in rig.pose.bones:
            pb.keyframe_insert('location', frame=frame, group=pb.name)
            pb.keyframe_insert('rotation_euler' if pb.rotation_mode == 'XYZ' else 'rotation_quaternion', frame=frame, group=pb.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points:
                        key.interpolation = 'LINEAR'
    minimum = float('inf')
    first = None
    max_seam = 0
    bounds_min = Vector((1e6, 1e6, 1e6))
    bounds_max = -bounds_min
    hand_samples = []
    for frame in range(1, frames + 2):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()
        ev = rig.evaluated_get(deps)
        pose = [v for pb in ev.pose.bones if pb.bone.use_deform for row in pb.matrix for v in row]
        if first is None:
            first = pose
            hand_samples = [list(ev.pose.bones['Hand_' + side].head) for side in ['R', 'L']]
        if frame == frames + 1:
            max_seam = max(abs(a - b) for a, b in zip(first, pose))
        for obj in meshes:
            evaluated = obj.evaluated_get(deps)
            mesh = evaluated.to_mesh()
            for v in mesh.vertices:
                p = evaluated.matrix_world @ v.co
                minimum = min(minimum, p.z)
                for axis in range(3):
                    bounds_min[axis] = min(bounds_min[axis], p[axis])
                    bounds_max[axis] = max(bounds_max[axis], p[axis])
            evaluated.to_mesh_clear()
    assert minimum > -.008, (name, 'floor penetration', minimum)
    assert max_seam < 1e-4, (name, 'endpoint mismatch', max_seam)
    report['clips'][name] = {'duration': frames / FPS, 'loop': name in ['Idle', 'Held'], 'minimum_height': minimum,
                             'endpoint_matrix_delta': max_seam, 'bounds_blender': [list(bounds_min), list(bounds_max)],
                             'hand_heads_blender_first_frame': hand_samples}
rig.animation_data.action = bpy.data.actions['Idle']
scene.frame_start = 1
scene.frame_end = 120
scene.frame_set(1)
rig['interaction_notes'] = 'Idle/Held loop. Land/Alert play once. Held is suspended by the scalp at Godot y=2.70; head and torso remain stable while limbs flail. Forward is Godot +Z.'
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_range=False, export_anim_slide_to_zero=True, export_def_bones=True, export_skins=True)
data = EXPORT.read_bytes()
length = struct.unpack_from('<I', data, 12)[0]
gltf = json.loads(data[20:20 + length])
names = [a['name'] for a in gltf['animations']]
assert set(names) == {'Walk', 'Idle', 'Held', 'Land', 'Alert'}, names
report['export_animations'] = names
report['exported_bones'] = len(gltf['skins'][0]['joints'])
report['bone_names'] = [gltf['nodes'][j]['name'] for j in gltf['skins'][0]['joints']]
assert report['exported_bones'] == 31
# Existing locomotion must remain byte-for-byte equivalent at sampled values.
def walk_channels(path):
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    blob = raw[28 + size:]
    def values(index):
        accessor = doc['accessors'][index]
        view = doc['bufferViews'][accessor['bufferView']]
        width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
        assert accessor['componentType'] == 5126
        return struct.unpack_from('<' + 'f' * (accessor['count'] * width), blob,
                                  view.get('byteOffset', 0) + accessor.get('byteOffset', 0))
    animation = next(a for a in doc['animations'] if a['name'] == 'Walk')
    result = {}
    for channel in animation['channels']:
        sampler = animation['samplers'][channel['sampler']]
        key = (doc['nodes'][channel['target']['node']]['name'], channel['target']['path'])
        result[key] = (values(sampler['input']), values(sampler['output']))
    return result
original_walk = walk_channels(ROOT / 'assets/models/zenscape-bigfoot-classic.glb')
exported_walk = walk_channels(EXPORT)
assert original_walk == exported_walk, 'Interaction export changed existing Walk samples'
report['walk_channels_preserved_exactly'] = len(original_walk)
REPORT.parent.mkdir(parents=True, exist_ok=True)
REPORT.write_text(json.dumps(report, indent=2) + '\n')
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
print('BIGFOOT_INTERACTIONS_VALIDATED', json.dumps(report))
