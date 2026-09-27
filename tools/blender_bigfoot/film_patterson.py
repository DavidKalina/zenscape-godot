"""Film the ambient Bigfoot the way the famous 1967 footage saw him: side-on across a
clearing, a hand-held pan following him as he strides past, turns to look at the camera
without breaking step, and walks on. Stride, StrideLookL, Stride.

Run after build_ambient_bigfoot.py:
  blender -b --python tools/blender_bigfoot/film_patterson.py -- [--still=110] [--scale=0.6]

Writes /tmp/zs-bigfoot-previews/patterson.mp4 (or patterson-<frame>.png with --still).
Does not save the .blend.
"""
import bpy, math, random, sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / 'blender_trees'))
import ambient_clips as clips
import kit
from kit import srgb

ARGS = dict(a.lstrip('-').split('=', 1) if '=' in a else (a.lstrip('-'), '1') for a in kit.ARGS)
OUT = Path('/tmp/zs-bigfoot-previews')
FPS = clips.FPS
LEAD = 2 * clips.STRIDE_FRAMES         # strides before the look
LOOK = clips.CLIPS['StrideLookL'][0]
TOTAL = LEAD + LOOK + 2 * clips.STRIDE_FRAMES
CAMERA = Vector((11.0, 0.0, 1.45))     # on his left, where the look turns
rng = random.Random(1967)

bpy.ops.wm.open_mainfile(filepath=str(kit.ROOT / 'art/blender/bigfoot/zenscape-bigfoot-ambient.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['BigfootRig']
speed = rig['stride_speed_mps']

# ---- stage: a sandbar clearing, the treeline behind him
if 'Backdrop' in bpy.data.objects:
	bpy.data.objects.remove(bpy.data.objects['Backdrop'])
floor = bpy.data.objects['Floor']
floor.scale = (4, 4, 1)
col = floor.data.color_attributes[0]
for i, _ in enumerate(col.data):
	g = srgb('8a8364')
	k = rng.uniform(0.9, 1.08)
	col.data[i].color = (g[0] * k, g[1] * k, g[2] * k, 1)


def place(name, loc, rot, scale):
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=str(kit.ROOT / f'assets/models/{name}.glb'))
	for r in [o for o in bpy.data.objects if o not in before and o.parent is None]:
		r.location, r.rotation_euler, r.scale = loc, (0, 0, rot), (scale,) * 3


for x, y, name, scale in ((-9.0, -8.0, 'zenscape-hero-oak', 1.4), (-11.0, 1.0, 'zenscape-hero-oak', 1.6),
		(-8.5, 8.0, 'zenscape-hero-oak', 1.3), (-17.0, -3.0, 'zenscape-hero-redwood', 0.5),
		(-18.0, 10.0, 'zenscape-hero-redwood', 0.45), (-15.0, -14.0, 'zenscape-hero-oak', 1.9)):
	place(name, Vector((x, y, -0.02)), rng.uniform(0, math.tau), scale)

# ---- clips back to back on one track: each begins on the same left heel strike
ad = rig.animation_data
for t in list(ad.nla_tracks):
	ad.nla_tracks.remove(t)
ad.action = None
track = ad.nla_tracks.new()
start = 0
for name, repeat in (('Stride', 2), ('StrideLookL', 1), ('Stride', 2)):
	strip = track.strips.new(f'{name}{start}', start, bpy.data.actions[name])
	strip.repeat = repeat
	start = int(strip.frame_end)

# ---- root motion: straight across, facing -Y (screen left from the camera)
for f in range(TOTAL + 1):
	rig.location = (0, 5.2 - speed * f / FPS, 0)
	rig.keyframe_insert('location', frame=f)

# ---- light and a hand-held camera that pans after him, a little late
world = bpy.data.worlds.new('Overcast')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (*srgb('b4bcc0'), 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.1
scene.world = world
sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
sun.data.energy, sun.data.color, sun.data.angle = 3.0, srgb('fff1dc'), math.radians(6)
sun.rotation_euler = (math.radians(50), 0, math.radians(60))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
cam.data.lens = 58
scene.collection.objects.link(cam)
scene.camera = cam
aim = Vector((0, 5.2, 1.1))
for f in range(TOTAL + 1):
	aim = aim.lerp(Vector((0, 5.2 - speed * f / FPS - 0.5, 1.1)), 0.06)
	shake = Vector([0.012 * math.sin(f * a + b) + 0.006 * math.sin(f * 2.7 * a + 2 * b)
		for a, b in ((0.21, 0.3), (0.17, 1.9), (0.23, 4.1))])
	cam.location = CAMERA + shake * 0.5
	cam.rotation_euler = (aim + shake - cam.location).to_track_quat('-Z', 'Y').to_euler()
	cam.keyframe_insert('location', frame=f)
	cam.keyframe_insert('rotation_euler', frame=f)

scene.render.engine = 'BLENDER_EEVEE'
scene.view_settings.view_transform = 'Standard'
scene.render.fps = FPS
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.render.resolution_percentage = int(float(ARGS.get('scale', 1.0)) * 100)
scene.frame_start, scene.frame_end = 0, TOTAL
OUT.mkdir(parents=True, exist_ok=True)
if 'still' in ARGS:
	for f in (int(x) for x in ARGS['still'].split(',')):
		scene.frame_set(f)
		scene.render.filepath = str(OUT / f'patterson-{f}.png')
		bpy.ops.render.render(write_still=True)
else:
	scene.render.image_settings.media_type = 'VIDEO'
	scene.render.image_settings.file_format = 'FFMPEG'
	scene.render.ffmpeg.format = 'MPEG4'
	scene.render.ffmpeg.codec = 'H264'
	scene.render.ffmpeg.constant_rate_factor = 'HIGH'
	scene.render.filepath = str(OUT / 'patterson.mp4')
	bpy.ops.render.render(animation=True)
print('FILM_DONE', OUT)
