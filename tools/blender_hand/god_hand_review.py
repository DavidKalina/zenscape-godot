"""Review renders and numbers for the God Hand. Run after god_hand.py:

  blender -b --python tools/blender_hand/god_hand_review.py -- --reel [--view=game] [--scale=1]
  blender -b --python tools/blender_hand/god_hand_review.py -- --clip=PinchIn [--count=8] [--view=side]
  blender -b --python tools/blender_hand/god_hand_review.py -- --check
  blender -b --python tools/blender_hand/god_hand_review.py -- --heights=PinchIn,PressHold

The reel plays every gesture the way the game would chain them: Idle, then each In, its
Hold twice and its Out, with a short crossfade where Idle is cut. Stand-ins show what the
hand works: a mound that rises under the pinch (the anchor rising with it, as the game will
lift it) and that the press then kneads back down, the water orb that condenses, rides and
drops straight down, and pollen motes falling from the pinch of salt. It goes to
/tmp/zs-hand-previews/review/reel-<view>.mp4; --clip renders a contact sheet instead.
--check prints each clip's largest joint accelerations (pops), loop seam gaps, and the gaps
where clips should hand off exactly.
Poses come from god_hand_clips.evaluate(), the same frames the bake keys. Does not save.
"""
import bpy, bmesh, math, random, shutil, subprocess, sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
for folder in ('blender_trees', 'blender_bigfoot', 'blender_creatures'):
	sys.path.insert(0, str(HERE.parent / folder))
sys.path.insert(0, str(HERE))
import kit
from kit import srgb, mix
import god_hand_clips as clips
from heron_clips import fk
from ambient_clips import smooth

ARGS = dict(a.lstrip('-').split('=', 1) if '=' in a else (a.lstrip('-'), '1') for a in kit.ARGS)
VIEW = ARGS.get('view', 'game')
OUT = Path('/tmp/zs-hand-previews/review')

bpy.ops.wm.open_mainfile(filepath=str(kit.ROOT / 'art/blender/hand/zenscape-god-hand.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['GodHandRig']
hand = bpy.data.objects['GodHand']
rig.animation_data_create()
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
	track.mute = True
clips.prepare(rig)

# The game camera sits on the thumb side, a little behind the reach, 25 degrees up.
GAME_DIR = Vector((0.868, 0.26, 0.423))
VIEWS = {
	'game': (GAME_DIR * 2.7 + Vector((0, -0.1, 0.42)), (0, -0.1, 0.42), 35),
	'far': (GAME_DIR * 8.0 + Vector((0, -0.1, 0.3)), (0, -0.1, 0.3), 35),
	'side': ((3.4, -0.25, 0.45), (0, -0.25, 0.4), 35),
	'front': ((0.35, -3.4, 0.7), (0, -0.2, 0.4), 35),
}


def studio(scale):
	scene.render.engine = 'BLENDER_EEVEE'
	scene.render.resolution_x, scene.render.resolution_y = 960, 540
	scene.render.resolution_percentage = int(100 * scale)
	scene.eevee.taa_render_samples = 16
	scene.view_settings.view_transform = 'Standard'
	scene.render.fps = clips.FPS
	world = bpy.data.worlds.new('Sky')
	world.use_nodes = True
	world.node_tree.nodes['Background'].inputs['Color'].default_value = (*srgb('a9bccb'), 1)
	world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
	scene.world = world
	sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
	sun.data.energy, sun.data.color, sun.data.angle = 3.2, srgb('fff0d8'), math.radians(3)
	sun.rotation_euler = (math.radians(48), 0, math.radians(60))
	scene.collection.objects.link(sun)
	cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
	scene.collection.objects.link(cam)
	scene.camera = cam
	loc, target, lens = VIEWS[VIEW]
	cam.location = Vector(loc)
	cam.data.lens = lens
	cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()


def flat_material(name, colour, alpha=1.0, glow=0.0):
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	bsdf = mat.node_tree.nodes['Principled BSDF']
	bsdf.inputs['Base Color'].default_value = (*colour, 1)
	bsdf.inputs['Roughness'].default_value = 0.2 if alpha < 1 else 0.95
	if alpha < 1:
		bsdf.inputs['Alpha'].default_value = alpha
		mat.surface_render_method = 'BLENDED'
	if glow:
		bsdf.inputs['Emission Color'].default_value = (*colour, 1)
		bsdf.inputs['Emission Strength'].default_value = glow
	return mat


class Stage:
	"""Stand-ins for what the hand works on."""

	def __init__(self):
		c = bpy.data.collections.new('PREVIEW - review')
		scene.collection.children.link(c)
		kit.rng.seed(3)
		kit.ground(c, 4, srgb('5f8c3c'), srgb('86ad4e'), relief=0.0)
		bm = bmesh.new()
		bmesh.ops.create_circle(bm, cap_ends=True, segments=12, radius=0.09)
		self.mark = kit.to_object(bm, 'Mark', c)
		self.mark.data.materials.append(flat_material('Mark', srgb('3d5a2a'), 0.55))
		bm = bmesh.new()
		bmesh.ops.create_cone(bm, cap_ends=True, segments=9, radius1=1.0, radius2=0.0, depth=1.0)
		for v in bm.verts:
			v.co.z += 0.5
		self.mound = kit.to_object(bm, 'Mound', c)
		kit.paint(self.mound, lambda p: mix(srgb('6f7d4a'), srgb('9aa56a'), 0.5 + 0.5 * p.normal.z))
		self.mound.data.materials.append(kit.material('Mound', 1.0))
		bm = bmesh.new()
		bmesh.ops.create_icosphere(bm, subdivisions=2, radius=clips.ORB_R)
		self.orb = kit.to_object(bm, 'Orb', c)
		self.orb.data.materials.append(flat_material('Orb', srgb('5aa7c9'), 0.72, 0.25))
		self.motes = []
		pollen = flat_material('Pollen', srgb('ffe9a0'), 1.0, 1.5)
		for i in range(160):
			bm = bmesh.new()
			bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.011)
			m = kit.to_object(bm, f'Mote{i}', c)
			m.data.materials.append(pollen)
			self.motes.append(m)
		self.height = 0.0

	def show(self, height, orb, motes):
		self.height = height
		self.mound.scale = (0.1 + 1.1 * height, 0.1 + 1.1 * height, max(height, 1e-4))
		self.mound.hide_render = height < 0.01
		self.mark.location = (0, 0, height + 0.003)
		rig.location = (0, 0, height)
		if orb:
			self.orb.location, size = orb
			self.orb.scale = (max(size, 1e-3),) * 3
		self.orb.hide_render = not orb or orb[1] < 0.02
		for m, spot in zip(self.motes, motes + [None] * len(self.motes)):
			m.hide_render = spot is None
			if spot is not None:
				m.location = spot


def world_of(bone, point=(0, 0, 0)):
	return rig.matrix_world @ (fk(rig, bone) @ Vector(point))


# ---------------------------------------------------------------- reel

SEQUENCE = [('Idle', 110), ('PinchIn', None), ('PinchHold', 120), ('PinchOut', None), ('Idle', 40),
	('PressIn', None), ('PressHold', 144), ('PressOut', None), ('Idle', 40),
	('CupIn', None), ('CupHold', 120), ('CupOut', None), ('Idle', 45),
	('SprinkleIn', None), ('SprinkleHold', 144), ('SprinkleOut', None), ('Idle', 90)]
XFADE = 6


def reel_frames():
	"""(clip, frame in clip, placement, shape) for every reel frame, crossfading out of a
	cut Idle the way the game would."""
	cache = {}
	out = []
	for i, (name, length) in enumerate(SEQUENCE):
		if name not in cache:
			cache[name] = clips.evaluate(rig, name)
		frames = cache[name]
		T, _, loop, _, _ = clips.CLIPS[name]
		count = length if length is not None else T + 1
		for f in range(count):
			p, s = frames[f % len(frames)]
			if f < XFADE and i > 0 and SEQUENCE[i - 1][0] == 'Idle' and out:
				prev_name, prev_f = out[-1][0], out[-1][1]
				pp, ps = cache[prev_name][(prev_f + 1 + f) % len(cache[prev_name])]
				w = smooth((f + 1) / (XFADE + 1))
				p, s = clips.lerp(pp, p, w), clips.lerp(ps, s, w)
			out.append((name, f, p, s))
	return out


def reel():
	scale = float(ARGS.get('scale', '1'))
	studio(scale)
	stage = Stage()
	frames = reel_frames()
	folder = OUT / f'reel-{VIEW}'
	shutil.rmtree(folder, ignore_errors=True)
	folder.mkdir(parents=True)
	rng = random.Random(5)
	height = 0.0
	orb_drop = None
	motes = []  # [born frame, x, y, z, phase]
	# The game's ball (scripts/water_ball.gd): hops up at 1.4 m/s and falls at 18 m/s^2;
	# here a hand is taken to be 2.5 m long, about right for a half-metre ball.
	hop, g = 1.4 / 2.5, 18.0 / 2.5
	for n, (name, f, p, s) in enumerate(frames):
		T = clips.CLIPS[name][0]
		# The land: rises under a held pinch, kneads back down under a held press.
		if name == 'PinchHold':
			height = min(0.5, height + 0.5 / 240)
		elif name == 'PressHold':
			height = max(0.0, height - 0.5 / 288 * 1.0)
		elif name == 'PressOut' and f == 0:
			height = max(0.0, height)
		rig.location = (0, 0, height)
		clips.pose(rig, p, s)
		bpy.context.view_layer.update()
		orb = None
		if name == 'CupIn':
			orb = (world_of('Orb'), smooth((f - 9) / 14))
		elif name == 'CupHold' or (name == 'CupOut' and f <= clips.CUP_TOSS + 2):
			orb = (world_of('Orb'), 1.0)
			if name == 'CupOut':
				orb_drop = (world_of('Orb'), n)
		elif orb_drop is not None:
			start, born = orb_drop
			dt = (n - born) / clips.FPS
			z = start.z + hop * dt - 0.5 * g * dt * dt
			if z > height + clips.ORB_R * 0.4:
				orb = (Vector((start.x, start.y, z)), 1.0)
			else:
				orb_drop = None
		if name in ('SprinkleIn', 'SprinkleHold') and (name == 'SprinkleHold' or f > 10):
			at = world_of('Pollen')
			for _ in range(2):
				motes.append([n, at.x + rng.uniform(-0.03, 0.03), at.y + rng.uniform(-0.03, 0.03), at.z - 0.03, rng.uniform(0, 6.28)])
		spots = []
		keep = []
		for m in motes:
			age = (n - m[0]) / clips.FPS
			z = m[3] - 0.13 * age
			if z > height + 0.01 and age < 6:
				sway = 0.02 * math.sin(2.1 * age + m[4])
				spots.append(Vector((m[1] + sway, m[2] + 0.015 * math.cos(1.7 * age + m[4]), z)))
				keep.append(m)
		motes = keep[-len(stage.motes):]
		stage.show(height, orb, spots[-len(stage.motes):])
		scene.render.filepath = str(folder / f'{n:04d}.png')
		bpy.ops.render.render(write_still=True)
	mp4 = OUT / f'reel-{VIEW}.mp4'
	subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-framerate', str(clips.FPS), '-i', str(folder / '%04d.png'),
		'-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', str(mp4)], check=True)
	print('HAND_REEL', mp4, len(frames), 'frames')


# ---------------------------------------------------------------- stills

def contact_sheet(name):
	studio(0.5)
	stage = Stage()
	frames = clips.evaluate(rig, name)
	T, _, loop, _, _ = clips.CLIPS[name]
	if 'frames' in ARGS:
		picks = [int(x) for x in ARGS['frames'].split(',')]
	else:
		count = int(ARGS.get('count', '8'))
		picks = [round(i * (T if not loop else T - 1) / (count - 1)) for i in range(count)]
	folder = OUT / f'{name}-{VIEW}'
	shutil.rmtree(folder, ignore_errors=True)
	folder.mkdir(parents=True)
	for i, f in enumerate(picks):
		clips.pose(rig, *frames[f % len(frames)])
		bpy.context.view_layer.update()
		orb = (world_of('Orb'), 1.0) if name.startswith('Cup') else None
		stage.show(0.0, orb, [])
		scene.render.filepath = str(folder / f'{i:02d}.png')
		bpy.ops.render.render(write_still=True)
	cols = 4
	rows = (len(picks) + cols - 1) // cols
	inputs = []
	for i in range(rows * cols):
		inputs += ['-i', str(folder / f'{min(i, len(picks) - 1):02d}.png')]
	layout = '|'.join(_cell(i % cols, i // cols) for i in range(rows * cols))
	sheet = OUT / f'{name}-{VIEW}.png'
	subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', *inputs, '-filter_complex',
		f'xstack=inputs={rows * cols}:layout={layout}', str(sheet)], check=True)
	print('HAND_SHEET', sheet, 'frames', picks)


def _cell(c, r):
	x = '+'.join(['w0'] * c) or '0'
	y = '+'.join(['h0'] * r) or '0'
	return f'{x}_{y}'


# ---------------------------------------------------------------- numbers

POINTS = [b.name for b in rig.data.bones if b.use_deform]


def points_for(p, s):
	clips.pose(rig, p, s)
	return [fk(rig, b) @ Vector((0, rig.data.bones[b].length, 0)) for b in POINTS]


def check():
	first, last = {}, {}
	for name, (T, _, loop, _, _) in clips.CLIPS.items():
		frames = clips.evaluate(rig, name)
		pts = [points_for(p, s) for p, s in frames]
		n = len(pts)
		worst = []
		for f in range(n):
			if not loop and (f == 0 or f == n - 1):
				continue
			a, b, c = pts[(f - 1) % n], pts[f], pts[(f + 1) % n]
			acc = max(((x - 2 * y + z).length, POINTS[i]) for i, (x, y, z) in enumerate(zip(a, b, c)))
			worst.append((acc[0], f, acc[1]))
		worst.sort(reverse=True)
		seam = max((x - y).length for x, y in zip(pts[0], pts[-1])) if loop else 0.0
		step = max(max((x - y).length for x, y in zip(pts[f], pts[f - 1])) for f in range(1, n))
		print(f'HAND_CHECK {name:13s} peak accel ' + ', '.join(f'{a:.4f}@{f} {b}' for a, f, b in worst[:3])
			+ f' | max step {step:.4f}' + (f' | seam {seam:.4f}' if loop else ''))
		first[name], last[name] = pts[0], pts[-1] if not loop else pts[0]
	pairs = [('Idle', 'PinchIn'), ('PinchIn', 'PinchHold'), ('PinchHold', 'PinchOut'), ('PinchOut', 'Idle'),
		('Idle', 'PressIn'), ('PressIn', 'PressHold'), ('PressHold', 'PressOut'), ('PressOut', 'Idle'),
		('Idle', 'CupIn'), ('CupIn', 'CupHold'), ('CupHold', 'CupOut'), ('CupOut', 'Idle'),
		('Idle', 'SprinkleIn'), ('SprinkleIn', 'SprinkleHold'), ('SprinkleHold', 'SprinkleOut'), ('SprinkleOut', 'Idle')]
	for a, b in pairs:
		gap = max((x - y).length for x, y in zip(last[a], first[b]))
		print(f'HAND_HANDOFF {a:>12s} -> {b:12s} {gap:.4f}')


def heights(name):
	"""Each fingertip's lowest height over a clip, in hand lengths above the anchor."""
	frames = clips.evaluate(rig, name)
	low = {}
	for f, (p, s) in enumerate(frames):
		clips.pose(rig, p, s)
		for d in clips.DIGITS:
			z = (fk(rig, f'{d}3') @ Vector((0, rig.data.bones[f'{d}3'].length, 0))).z
			if d not in low or z < low[d][0]:
				low[d] = (z, f)
	print(f'HAND_HEIGHTS {name}: ' + ', '.join(f'{d} {z:+.3f}@{f}' for d, (z, f) in low.items()))


if 'heights' in ARGS:
	for name in ARGS['heights'].split(','):
		heights(name)
elif 'check' in ARGS:
	check()
elif 'reel' in ARGS:
	reel()
elif 'clip' in ARGS:
	contact_sheet(ARGS['clip'])
