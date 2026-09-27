"""Review renders, numbers and probes for the heron. Run after heron.py:

  blender -b --python tools/blender_creatures/heron_review.py -- --clip=Strike
      [--frames=0,30,34] [--count=8] [--view=hero] [--video] [--scale=1]
  blender -b --python tools/blender_creatures/heron_review.py -- --check [--clip=Stand]
  blender -b --python tools/blender_creatures/heron_review.py -- --probe=fold|pole|neck

Stills go to /tmp/zs-heron-previews/review/<clip>-<view>.png as one contact sheet (evenly
spaced frames unless --frames is given); --video renders every frame to <clip>-<view>.mp4.
Flying clips follow the bird with the camera. --check prints, per clip: the lowest vertex
(standing clips should not sink into the floor), foot drift on planted clips, the largest
joint acceleration (pops) including across the loop seam, and the seam gap.
Does not save the .blend.
"""
import bpy, json, math, shutil, subprocess, sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'blender_trees'))
sys.path.insert(0, str(HERE.parent / 'blender_bigfoot'))
sys.path.insert(0, str(HERE))
import kit
import heron_clips as clips
import heron as build

ARGS = dict(a.lstrip('-').split('=', 1) if '=' in a else (a.lstrip('-'), '1') for a in kit.ARGS)
CLIP = ARGS.get('clip', 'Stand')
VIEW = ARGS.get('view', 'hero')
OUT = Path('/tmp/zs-heron-previews/review')

VIEWS = dict(build.VIEWS)
VIEWS.update({
	'close': ((1.5, -1.9, 1.3), (0, -0.1, 0.9), 45),
	'strike': ((3.2, -0.7, 0.95), (0, -0.2, 0.72), 36),
	'low': ((1.9, -2.3, 0.45), (0, -0.1, 0.7), 40),
	'flyside': ((4.0, 0.0, 0.9), (0, 0.1, 0.8), 55),
	'flyhero': ((2.8, -2.6, 1.8), (0, 0.1, 0.8), 55),
	'flyfront': ((0.3, -4.2, 1.1), (0, 0.0, 0.8), 50),
	'flytop': ((0.0, 0.3, 4.4), (0, 0.1, 0.8), 45),
	'flyunder': ((1.2, -2.2, -0.6), (0, 0.1, 0.8), 45),
	'land': ((4.2, -1.2, 1.3), (0, -0.2, 0.75), 38),
	'bill': ((1.0, -1.25, 1.25), (0, -0.3, 1.05), 45),
	'stand': ((2.0, -2.2, 1.35), (0, -0.05, 0.95), 45),
})

bpy.ops.wm.open_mainfile(filepath=str(kit.ROOT / 'art/blender/creatures/zenscape-heron.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['HeronRig']
body = bpy.data.objects['Heron']


def solo(name):
	# Assign the action: toggling NLA mutes does not re-evaluate in background mode.
	rig.animation_data_create()
	for track in rig.animation_data.nla_tracks:
		track.mute = True
	rig.animation_data.action = bpy.data.actions[name] if name else None


def posed():
	return rig.evaluated_get(bpy.context.evaluated_depsgraph_get())


def verts():
	ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
	mesh = ev.to_mesh()
	pts = [body.matrix_world @ v.co for v in mesh.vertices]
	ev.to_mesh_clear()
	return pts


def fmt(v):
	return '(' + ', '.join(f'{c:+.3f}' for c in v) + ')'


if 'probe' in ARGS:
	kind = ARGS['probe']
	solo(None)
	if kind == 'fold':
		clips.rest_pose(rig)
		ev = posed()
		for n in clips.WING:
			pb = ev.pose.bones[n + '_L']
			m = pb.matrix
			print(f'FOLD {n:10s} head {fmt(m.translation)} tail {fmt(pb.tail)} normal {fmt(m.col[2].xyz)} chord {fmt(-m.col[0].xyz)}')
		for n in ('Body', 'Neck1', 'Neck2', 'Neck3', 'Head', 'Tibia_L', 'Tarsus_L', 'Toes_L'):
			pb = ev.pose.bones[n]
			print(f'FOLD {n:10s} head {fmt(pb.head)} tail {fmt(pb.tail)}')
	elif kind == 'pole':
		# Sink the body and see which way each pole angle bends the ankle.
		for angle in (-90, 0, 90, 180):
			for s in 'LR':
				rig.pose.bones[f'Tarsus_{s}'].constraints['LegIK'].pole_angle = math.radians(angle)
			clips.reset(rig)
			clips.stand(rig, 0, dip=0.12)
			bpy.context.view_layer.update()
			ev = posed()
			for s in 'LR':
				hip, ankle, foot = ev.pose.bones[f'Tibia_{s}'].head, ev.pose.bones[f'Tibia_{s}'].tail, ev.pose.bones[f'Tarsus_{s}'].tail
				print(f'POLE {angle:+4d} {s} ankle {fmt(ankle)} hip {fmt(hip)} foot {fmt(foot)} ankle-behind {ankle.y - (hip.y + foot.y) / 2:+.3f}')
	sys.exit(0)

frames, _, loop = clips.CLIPS[CLIP]
solo(CLIP)
scene.frame_start, scene.frame_end = 0, frames

if 'check' in ARGS:
	report = {}
	names = [ARGS['clip']] if 'clip' in ARGS else list(clips.CLIPS)
	for name in names:
		frames, _, loop = clips.CLIPS[name]
		solo(name)
		r = {'frames': frames, 'min_z': 9.0}
		feet0, drift = None, 0.0
		grounded = name in ('Stand', 'Strike')
		for f in list(range(0, frames, int(ARGS.get('every', 10)))) + [frames]:
			scene.frame_set(f)
			if grounded or name == 'Stalk':
				low = min(p.z for p in verts())
				if low < r['min_z']:
					r['min_z'], r['min_z_frame'] = round(low, 4), f
			ev = posed()
			feet = [ev.pose.bones[f'Tarsus_{s}'].tail.copy() for s in 'LR']
			if feet0 is None:
				feet0 = feet
			if grounded:
				drift = max(drift, max((a - b).length for a, b in zip(feet, feet0)))
		joints = ('Head', 'Neck2', 'Body', 'Hand_L', 'Prim5_L', 'Crest2', 'Tarsus_L', 'Toes_R')
		track = []
		for f in range(frames + 1):
			scene.frame_set(f)
			ev = posed()
			track.append([ev.pose.bones[j].tail.copy() for j in joints])
		worst = (0.0, None, None)
		span = range(frames) if loop else range(1, frames)
		for f in span:
			for k, j in enumerate(joints):
				prev = track[(f - 1) % frames] if loop else track[f - 1]
				a = (track[f + 1][k] - 2 * track[f][k] + prev[k]).length * clips.FPS ** 2
				if a > worst[0]:
					worst = (a, j, f)
		r['max_accel'] = [round(worst[0], 1), worst[1], worst[2]]
		r['seam'] = round(max((track[frames][k] - track[0][k]).length for k in range(len(joints))), 5) if loop else None
		r['foot_drift'] = round(drift, 4) if grounded else None
		report[name] = r
	# Hand-offs: a one-shot's last frame against the first frame of the clip it hands to
	# (Stalk's end is moved back by its distance, as LifeMoments moves the heron on).
	deform = [b.name for b in rig.data.bones if b.use_deform]

	def pose_at(name, f, shift=0.0):
		solo(name)
		scene.frame_set(f)
		ev = posed()
		return {b: ev.pose.bones[b].tail + Vector((0, shift, 0)) for b in deform}

	for a, b, shift in (('Land', 'Stand', 0.0), ('Stalk', 'Stand', clips.STALK_DISTANCE), ('TakeOff', 'Fly', 0.0), ('Strike', 'Stand', 0.0)):
		end, start = pose_at(a, clips.CLIPS[a][0], shift), pose_at(b, 0)
		worst = max(deform, key=lambda k: (end[k] - start[k]).length)
		report[f'{a}->{b}'] = [round((end[worst] - start[worst]).length, 4), worst]
	print('HERON_CHECK', json.dumps(report, indent=1))
	sys.exit(0)

build.setup_studio(float(ARGS.get('scale', 1.0)))
flying = CLIP in ('Fly', 'Glide')
view_names = ARGS.get('view', 'flyhero' if flying else VIEW).split(',')


def render(frame_list, folder):
	if folder.exists():
		shutil.rmtree(folder)
	folder.mkdir(parents=True)
	for i, f in enumerate(frame_list):
		scene.frame_set(f)
		scene.render.filepath = str(folder / f'{i:04d}.png')
		bpy.ops.render.render(write_still=True)


OUT.mkdir(parents=True, exist_ok=True)
sheets = []
for view in view_names:
	build.aim_camera(*VIEWS[view])
	if 'video' in ARGS:
		folder = OUT / f'{CLIP}-{view}-video'
		render(range(frames + (0 if loop else 1)), folder)
		video = OUT / f'{CLIP}-{view}.mp4'
		subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-framerate', str(clips.FPS), '-i', str(folder / '%04d.png'),
			'-vf', 'pad=ceil(iw/2)*2:ceil(ih/2)*2', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', str(video)], check=True)
		print('HERON_REVIEW', video)
		continue
	if 'frames' in ARGS:
		frame_list = [int(f) for f in ARGS['frames'].split(',')]
	else:
		count = int(ARGS.get('count', 8))
		frame_list = [round(i * frames / count) for i in range(count)]
	folder = OUT / f'{CLIP}-{view}-stills'
	render(frame_list, folder)
	cols = min(len(frame_list), int(ARGS.get('cols', 4)))
	rows = math.ceil(len(frame_list) / cols)
	sheet = OUT / f'{CLIP}-{view}.png'
	subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(folder / '%04d.png'),
		'-vf', f'tile={cols}x{rows}', '-frames:v', '1', str(sheet)], check=True)
	sheets.append(sheet)
	print('HERON_REVIEW', sheet, 'frames', frame_list)
if len(sheets) > 1:
	both = OUT / f'{CLIP}-sheet.png'
	inputs = [a for sheet in sheets for a in ('-i', str(sheet))]
	subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', *inputs, '-filter_complex', f'vstack=inputs={len(sheets)}', str(both)], check=True)
	print('HERON_REVIEW', both)
