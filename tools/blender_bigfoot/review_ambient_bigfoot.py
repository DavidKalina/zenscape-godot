"""Review renders of the ambient Bigfoot clips. Run after build_ambient_bigfoot.py:

  blender -b --python tools/blender_bigfoot/review_ambient_bigfoot.py -- --clip=PeekL
      [--frames=0,100,190] [--count=8] [--view=peek] [--video] [--scale=0.5]

Stills go to /tmp/zs-bigfoot-previews/review/<clip>-<view>.png as one contact sheet
(evenly spaced frames unless --frames is given); --video renders every frame to
<clip>-<view>.mp4. Peek clips stand behind a stand-in trunk (clips.PEEK_TRUNK), which
is not part of the asset. Does not save the .blend.
"""
import bpy, bmesh, math, shutil, subprocess, sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build_ambient_bigfoot as build
import ambient_clips as clips
import kit

ARGS = dict(a.lstrip('-').split('=', 1) if '=' in a else (a.lstrip('-'), '1') for a in kit.ARGS)
CLIP = ARGS.get('clip', 'Idle')
VIEW = ARGS.get('view', 'hero')
SCALE = float(ARGS.get('scale', 0.5))
OUT = Path('/tmp/zs-bigfoot-previews/review')

VIEWS = dict(build.VIEWS)
VIEWS.update({
	'peek': ((0.5, -5.2, 1.7), (0.25, -0.9, 1.55), 55),  # a viewer in front of the trunk
	'peekwide': ((1.0, -8.0, 1.6), (0.1, -0.9, 1.3), 40),
	'top': ((0.25, -0.45, 7.0), (0.25, -0.44, 0.0), 32),
	'three': ((3.2, -3.6, 1.9), (0, -0.1, 1.2), 40),
	'close': ((1.4, -2.9, 1.9), (0, -0.2, 1.55), 45),
	'feet': ((1.5, -0.9, 0.3), (0.1, -0.08, 0.08), 45),
	'feetside': ((2.4, -0.05, 0.35), (0.0, -0.05, 0.2), 40),
	'low': ((1.1, -2.5, 1.25), (-0.1, -0.3, 0.95), 45),
	'lowfront': ((-0.2, -2.8, 1.2), (-0.1, -0.3, 1.0), 45),
	'peekclose': ((0.9, -3.4, 1.85), (0.45, -0.6, 1.7), 50),
	'wide': ((1.2, -9.0, 1.6), (0, -0.9, 1.2), 35),
})
# Mirrored viewers for the right-hand peek.
VIEWS.update({f'{k}R': ((-l[0], l[1], l[2]), (-t[0], t[1], t[2]), f) for k, (l, t, f) in list(VIEWS.items()) if k.startswith('peek')})

bpy.ops.wm.open_mainfile(filepath=str(kit.ROOT / 'art/blender/bigfoot/zenscape-bigfoot-ambient.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['BigfootRig']
build.setup_studio()
if CLIP == 'PeekL':  # light the side he leans out on, not the trunk's shadow
	bpy.data.objects['Sun'].rotation_euler.z = math.radians(40)
scene.render.resolution_percentage = int(SCALE * 100)

if CLIP.startswith('Peek'):
	centre, radius = clips.PEEK_TRUNK
	bm = bmesh.new()
	kit.rng.seed(3)
	kit.tube(bm, [(centre.x, centre.y, -0.1), (centre.x, centre.y, 3.0), (centre.x, centre.y, 6.0)],
		[radius * 1.08, radius, radius * 0.85], 10, gnarl=0.02)
	trunk = kit.to_object(bm, 'Stand-in trunk', scene.collection)
	kit.paint(trunk, lambda poly: kit.srgb('5b4636') * (0.9 + 0.2 * kit.rng.random()))
	trunk.data.materials.append(kit.material('Bark', 0.95))

frames, _ = clips.CLIPS[CLIP]
for track in rig.animation_data.nla_tracks:
	track.mute = True
rig.animation_data.action = bpy.data.actions[CLIP]
scene.frame_start, scene.frame_end = 0, frames

loc, target, lens = VIEWS[VIEW]
cam = scene.camera
cam.location = Vector(loc)
cam.data.lens = lens
cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()


def render(frame_list, folder):
	if folder.exists():
		shutil.rmtree(folder)
	folder.mkdir(parents=True)
	for i, f in enumerate(frame_list):
		scene.frame_set(f)
		scene.render.filepath = str(folder / f'{i:04d}.png')
		bpy.ops.render.render(write_still=True)


OUT.mkdir(parents=True, exist_ok=True)
if 'video' in ARGS:
	folder = OUT / f'{CLIP}-{VIEW}-video'
	render(range(frames), folder)
	video = OUT / f'{CLIP}-{VIEW}.mp4'
	subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-framerate', str(clips.FPS), '-i', str(folder / '%04d.png'),
		'-vf', 'pad=ceil(iw/2)*2:ceil(ih/2)*2', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', str(video)], check=True)
	print('BIGFOOT_REVIEW', video)
else:
	if 'frames' in ARGS:
		frame_list = [int(f) for f in ARGS['frames'].split(',')]
	else:
		count = int(ARGS.get('count', 8))
		frame_list = [round(i * frames / count) for i in range(count)]
	folder = OUT / f'{CLIP}-{VIEW}-stills'
	render(frame_list, folder)
	cols = min(len(frame_list), int(ARGS.get('cols', 4)))
	rows = math.ceil(len(frame_list) / cols)
	sheet = OUT / f'{CLIP}-{VIEW}.png'
	subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(folder / '%04d.png'),
		'-vf', f'tile={cols}x{rows}', '-frames:v', '1', str(sheet)], check=True)
	print('BIGFOOT_REVIEW', sheet, 'frames', frame_list)
