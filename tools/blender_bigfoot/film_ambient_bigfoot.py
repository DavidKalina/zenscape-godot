"""Film the ambient Bigfoot wandering among the hero trees, then stopping to watch.

Run after build_ambient_bigfoot.py:
  blender -b --python tools/blender_bigfoot/film_ambient_bigfoot.py -- [--still] [--frames=N]

Writes /tmp/zs-bigfoot-previews/walkabout.mp4 (or walkabout-still.png with --still).
Does not save the .blend.
"""
import bpy, math, random, sys
from pathlib import Path
from mathutils import Vector, Euler

ROOT = Path(__file__).resolve().parents[2]
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = Path('/tmp/zs-bigfoot-previews')
rng = random.Random(3)


def srgb(h):
	c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def smooth(x):
	x = max(0.0, min(1.0, x))
	return x * x * (3 - 2 * x)


bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/blender/bigfoot/zenscape-bigfoot-ambient.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['BigfootRig']
speed = rig['walk_speed_mps']
FPS = 30
WALK_END = 420          # frames of walking (a little over four cycles)
STOP = 18               # frames to settle into the look
LOOK = 420             # the Watch clip
TOTAL = WALK_END + LOOK

# ---- stage: drop the studio backdrop, lay a mossy ground, plant trees
for name in ('Backdrop',):
	if name in bpy.data.objects:
		bpy.data.objects.remove(bpy.data.objects[name])
floor = bpy.data.objects['Floor']
floor.scale = (3, 3, 1)
col = floor.data.color_attributes[0]
for i, _ in enumerate(col.data):
	g = srgb('6f7d4a')
	k = rng.uniform(0.85, 1.1)
	col.data[i].color = (g[0] * k, g[1] * k, g[2] * k, 1)


def import_glb(name):
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=str(ROOT / f'assets/models/{name}.glb'))
	new = [o for o in bpy.data.objects if o not in before]
	return [o for o in new if o.parent is None]


# ---- clips on the NLA: walk loops, then the watch blends in
ad = rig.animation_data
for t in list(ad.nla_tracks):
	ad.nla_tracks.remove(t)
ad.action = None
walk = ad.nla_tracks.new(); walk.name = 'WalkTrack'
ws = walk.strips.new('Walk', 0, bpy.data.actions['Walk'])
ws.repeat = (WALK_END + STOP) / (ws.action_frame_end - ws.action_frame_start)
ws.extrapolation = 'HOLD_FORWARD'
look = ad.nla_tracks.new(); look.name = 'LookTrack'
ls = look.strips.new('Watch', WALK_END - STOP // 2, bpy.data.actions['Watch'])
ls.blend_in = STOP
ls.extrapolation = 'HOLD'

# ---- root motion: a gentle meandering path, easing to a stop
pos = Vector((-1.5, 3.0, 0))
heading = math.radians(-15)
rig.animation_data_create()
path = []
for f in range(TOTAL + 1):
	v = speed / FPS * (1 - smooth((f - (WALK_END - STOP)) / STOP))
	turn = math.radians(0.28) * math.sin(f / 140 * math.pi) - math.radians(0.12)
	heading += turn * (v / (speed / FPS))
	pos = pos + Vector((math.sin(heading), -math.cos(heading), 0)) * v
	path.append((pos.copy(), heading))
# The rig object is animated directly, separate from the pose NLA.
for f, (p, h) in enumerate(path):
	rig.location = p
	rig.rotation_euler = (0, 0, h)
	rig.keyframe_insert('location', frame=f)
	rig.keyframe_insert('rotation_euler', frame=f)

# ---- trees planted along the route, a few beside it and more behind
def place(name, loc, rot, scale):
	for r in import_glb(name):
		r.location = loc
		r.rotation_euler = (0, 0, rot)
		r.scale = (scale,) * 3


# The camera orbits on his right, so trees stand to his left and ahead of him.
for f, side, name, scale in ((90, -2.4, 'zenscape-hero-oak', 1.5), (230, -3.2, 'zenscape-hero-oak', 1.7),
		(360, -2.6, 'zenscape-hero-oak', 1.4), (520, -3.4, 'zenscape-hero-oak', 1.8),
		(160, -7.5, 'zenscape-hero-oak', 2.0), (420, -8.0, 'zenscape-hero-oak', 2.2),
		(300, -14.0, 'zenscape-hero-redwood', 0.5), (600, -15.0, 'zenscape-hero-redwood', 0.45)):
	p, h = path[min(f, TOTAL)]
	right = Vector((math.cos(h), math.sin(h), 0))
	place(name, p + right * side + Vector((0, 0, -0.02)), rng.uniform(0, math.tau), scale)

# ---- light and camera
world = bpy.data.worlds.new('Forest')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (*srgb('a9b8c4'), 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
scene.world = world
sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
sun.data.energy, sun.data.color, sun.data.angle = 3.6, srgb('ffe8c8'), math.radians(4)
sun.rotation_euler = (math.radians(55), 0, math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
cam.data.lens = 32
scene.collection.objects.link(cam)
scene.camera = cam
target = path[0][0].copy()
for f in range(TOTAL + 1):
	p, h = path[f]
	target = target.lerp(p, 0.08)  # lazy follow so the camera feels hand-held but calm
	orbit = h + math.radians(35 + 55 * smooth(f / TOTAL))
	offset = Vector((math.sin(orbit), -math.cos(orbit), 0)) * 7.5 + Vector((0, 0, 2.3))
	cam.location = target + offset
	look_at = target + Vector((0, 0, 1.15))
	cam.rotation_euler = (look_at - cam.location).to_track_quat('-Z', 'Y').to_euler()
	cam.keyframe_insert('location', frame=f)
	cam.keyframe_insert('rotation_euler', frame=f)

scene.render.engine = 'BLENDER_EEVEE'
scene.view_settings.view_transform = 'AgX' if '--agx' in ARGS else 'Standard'
scene.render.fps = FPS
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.frame_start, scene.frame_end = 0, TOTAL
for a in ARGS:
	if a.startswith('--frames='):
		scene.frame_end = int(a.split('=')[1])
OUT.mkdir(parents=True, exist_ok=True)
if '--still' in ARGS:
	for f in (60, 300, 560):
		scene.frame_set(f)
		scene.render.filepath = str(OUT / f'walkabout-still-{f}.png')
		bpy.ops.render.render(write_still=True)
else:
	scene.render.image_settings.media_type = 'VIDEO'
	scene.render.image_settings.file_format = 'FFMPEG'
	scene.render.ffmpeg.format = 'MPEG4'
	scene.render.ffmpeg.codec = 'H264'
	scene.render.ffmpeg.constant_rate_factor = 'HIGH'
	scene.render.filepath = str(OUT / 'walkabout.mp4')
	bpy.ops.render.render(animation=True)
print('FILM_DONE', OUT)
