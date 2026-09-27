"""Review renders of the deer clips. Run after deer.py:

  blender -b --python tools/blender_creatures/deer_review.py -- --clip=Idle
      [--view=three] [--frames=0,100,190] [--count=8] [--video] [--fawn] [--eevee] [--size=640x360]
      [--chain=HeadDown,Graze,HeadUp]

Stills go to /tmp/zs-deer-previews/review/<clip>-<view>.png as one contact sheet (evenly
spaced frames unless --frames is given); --video renders every frame to <clip>-<view>.mp4.
--chain plays clips back to back as the game would sequence them (a video named after the
chain). Walk is shown travelling at its speed so hoof slide shows. Workbench by default,
which is quick and light; --eevee for a lit look. Does not save the .blend.
"""
import bpy, math, shutil, subprocess, sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import deer as build
import deer_clips as clips
import kit

ARGS = dict(a.lstrip('-').split('=', 1) if '=' in a else (a.lstrip('-'), '1') for a in kit.ARGS)
CLIP = ARGS.get('clip', 'Idle')
VIEW = ARGS.get('view', 'three')
OUT = Path('/tmp/zs-deer-previews/review')

bpy.ops.wm.open_mainfile(filepath=str(kit.ROOT / 'art/blender/creatures/zenscape-deer.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['DeerRig']
doe, fawn = bpy.data.objects['Deer'], bpy.data.objects['Fawn']
doe.hide_render = 'fawn' in ARGS
fawn.hide_render = 'fawn' not in ARGS
cam = build.setup_studio('BLENDER_EEVEE' if 'eevee' in ARGS else 'BLENDER_WORKBENCH')
w, h = (int(x) for x in ARGS.get('size', '640x360').split('x'))
scene.render.resolution_x, scene.render.resolution_y = w, h
build.aim(cam, VIEW)
for track in rig.animation_data.nla_tracks:
	track.mute = True

chain = ARGS['chain'].split(',') if 'chain' in ARGS else [CLIP]
timeline = []  # (clip, frame, travelled)
travelled = 0.0
for name in chain:
	frames, loop = clips.ALL_CLIPS[name]
	repeat = int(ARGS.get('repeat', 2 if name == 'Walk' else 1))
	for r in range(repeat):
		for f in range(frames):
			timeline.append((name, f, travelled))
			if name == 'Walk':
				travelled += clips.WALK_SPEED / clips.FPS
	if not loop or name == chain[-1]:
		timeline.append((name, frames, travelled))


def show(entry):
	name, f, moved = entry
	rig.animation_data.action = bpy.data.actions[name]
	scene.frame_set(f)
	rig.location = (0, -moved, 0)


def render(entries, folder):
	if folder.exists():
		shutil.rmtree(folder)
	folder.mkdir(parents=True)
	base = Vector(cam.location)
	for i, entry in enumerate(entries):
		show(entry)
		cam.location = base + Vector((0, -entry[2], 0))
		scene.render.filepath = str(folder / f'{i:04d}.png')
		bpy.ops.render.render(write_still=True)
	cam.location = base


OUT.mkdir(parents=True, exist_ok=True)
tag = '-'.join(chain) + ('-fawn' if 'fawn' in ARGS else '')
if 'video' in ARGS:
	folder = OUT / f'{tag}-{VIEW}-video'
	render(timeline, folder)
	video = OUT / f'{tag}-{VIEW}.mp4'
	subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-framerate', str(clips.FPS), '-i', str(folder / '%04d.png'),
		'-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', str(video)], check=True)
	shutil.rmtree(folder)
	print('DEER_REVIEW', video)
else:
	if 'frames' in ARGS:
		picks = [int(x) for x in ARGS['frames'].split(',')]
	else:
		count = int(ARGS.get('count', 8))
		picks = [round(i * (len(timeline) - 1) / max(1, count - 1)) for i in range(count)]
	folder = OUT / f'{tag}-{VIEW}-stills'
	render([timeline[i] for i in picks], folder)
	cols = min(len(picks), int(ARGS.get('cols', 4)))
	rows = math.ceil(len(picks) / cols)
	sheet = OUT / f'{tag}-{VIEW}.png'
	subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(folder / '%04d.png'),
		'-vf', f'tile={cols}x{rows}', '-frames:v', '1', str(sheet)], check=True)
	print('DEER_REVIEW', sheet, 'frames', [timeline[i][:2] for i in picks])
