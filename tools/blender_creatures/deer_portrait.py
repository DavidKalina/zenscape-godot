"""A lit still of the doe and her fawn together, for review. Run after deer.py:

  blender -b --python tools/blender_creatures/deer_portrait.py -- [--doe=Idle:0] [--fawn=Graze:40] [--view=three]

Poses each from a baked clip frame, stands the fawn (at the game's 0.62 scale) beside the doe
and renders /tmp/zs-deer-previews/portrait-<view>.png with EEVEE. Does not save the .blend.
"""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import deer as build
import kit

ARGS = dict(a.lstrip('-').split('=', 1) if '=' in a else (a.lstrip('-'), '1') for a in kit.ARGS)
VIEW = ARGS.get('view', 'three')

bpy.ops.wm.open_mainfile(filepath=str(kit.ROOT / 'art/blender/creatures/zenscape-deer.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['DeerRig']
doe, fawn = bpy.data.objects['Deer'], bpy.data.objects['Fawn']
for track in rig.animation_data.nla_tracks:
	track.mute = True
# A second rig for the fawn: copy the armature object, pose it from its own clip.
fawn_rig = rig.copy()
fawn_rig.animation_data_create()
scene.collection.objects.link(fawn_rig)
fawn.parent = fawn_rig
fawn.modifiers['Armature'].object = fawn_rig
fawn.hide_render = False
fawn_rig.scale = (0.62, 0.62, 0.62)
fawn_rig.location = (0.45, 0.35, 0)
fawn_rig.rotation_euler = (0, 0, math.radians(-25))
for who, key, default in ((rig, 'doe', 'Idle:0'), (fawn_rig, 'fawn', 'Graze:40')):
	clip, frame = ARGS.get(key, default).split(':')
	who.animation_data.action = bpy.data.actions[clip]
	who['frame'] = int(frame)
# Both rigs read the scene frame; pose each at its own frame by baking one into a pose copy.
scene.frame_set(fawn_rig['frame'])
bpy.context.view_layer.update()
held = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in fawn_rig.pose.bones}
fawn_rig.animation_data.action = None
for name, (loc, rot) in held.items():
	fawn_rig.pose.bones[name].location = loc
	fawn_rig.pose.bones[name].rotation_quaternion = rot
scene.frame_set(rig['frame'])
cam = build.setup_studio('BLENDER_EEVEE')
scene.render.resolution_x, scene.render.resolution_y = 960, 540
build.aim(cam, VIEW)
cam.data.angle = math.radians(28)
out = Path('/tmp/zs-deer-previews') / f'portrait-{VIEW}.png'
scene.render.filepath = str(out)
bpy.ops.render.render(write_still=True)
print('DEER_PORTRAIT', out)
