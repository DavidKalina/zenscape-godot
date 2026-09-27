"""Numeric checks on the baked ambient Bigfoot clips. Run after build_ambient_bigfoot.py:

  blender -b --python tools/blender_bigfoot/check_ambient_bigfoot.py -- [--clip=PeekL] [--every=10] [--trace]

For every clip: the lowest vertex (floor penetration), foot drift on planted clips, the loop
seam, and for peeks the deepest vertex inside the stand-in trunk, how far the near eye clears
the trunk's silhouette from straight ahead, and the palm's distance from the bark.
--trace prints the peek measurements per sampled frame.
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / 'blender_trees'))
import ambient_clips as clips
import kit

ARGS = dict(a.lstrip('-').split('=', 1) if '=' in a else (a.lstrip('-'), '1') for a in kit.ARGS)
EVERY = int(ARGS.get('every', 10))

bpy.ops.wm.open_mainfile(filepath=str(kit.ROOT / 'art/blender/bigfoot/zenscape-bigfoot-ambient.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['BigfootRig']
body = bpy.data.objects['Bigfoot']
eye_rest = {}
head_rest = rig.data.bones['Head'].matrix_local
# Eye centres: the rig's lid bones sit on them.
for s, suffix in clips.SIDES:
	eye_rest[suffix] = head_rest.inverted() @ rig.data.bones[f'Lid_{suffix}'].head_local


def solo(name):
	# Assign the action: toggling NLA mutes does not re-evaluate in background mode.
	for track in rig.animation_data.nla_tracks:
		track.mute = True
	rig.animation_data.action = bpy.data.actions[name]


def verts():
	dg = bpy.context.evaluated_depsgraph_get()
	ev = body.evaluated_get(dg)
	mesh = ev.to_mesh()
	pts = [body.matrix_world @ v.co for v in mesh.vertices]
	ev.to_mesh_clear()
	return pts


def posed():
	return rig.evaluated_get(bpy.context.evaluated_depsgraph_get())


def bone_pose(name):
	return posed().pose.bones[name].matrix


report = {}
names = [ARGS['clip']] if 'clip' in ARGS else list(clips.CLIPS)
for name in names:
	frames, _ = clips.CLIPS[name]
	solo(name)
	r = {'frames': frames, 'min_z': 9.0}
	feet0 = None
	drift = 0.0
	peek = name.startswith('Peek')
	side = 1 if name == 'PeekL' else -1
	suffix = 'L' if side > 0 else 'R'
	if peek:
		centre, radius = clips.PEEK_TRUNK
		r.update(inside=0.0, eye_clear=-9.0, palm_gap=[])
	for f in list(range(0, frames, EVERY)) + [frames]:
		scene.frame_set(f)
		pts = verts()
		low = min(p.z for p in pts)
		if low < r['min_z']:
			r['min_z'], r['min_z_frame'] = low, f
			r['min_z_at'] = [round(c, 3) for c in min(pts, key=lambda q: q.z)]
		feet = [bone_pose(f'Foot_{s}').translation.copy() for s in 'LR']
		if feet0 is None:
			feet0 = feet
		if not name.startswith(('Walk', 'Stride')):
			drift = max(drift, max((a - b).length for a, b in zip(feet, feet0)))
		if peek:
			deepest, where = 0.0, None
			for p in pts:
				if p.z < 6.0:
					d = radius - (Vector((p.x, p.y)) - centre).length
					if d > deepest:
						deepest, where = d, p
			r['inside'] = max(r['inside'], deepest)
			eye = bone_pose('Head') @ eye_rest[suffix]
			clear = side * eye.x - radius
			r['eye_clear'] = max(r['eye_clear'], clear)
			ik = posed().pose.bones[f'Forearm_{suffix}'].constraints['ArmIK'].influence
			if ik > 0.99:
				hand = bone_pose(f'Hand_{suffix}')
				palm = hand.translation + hand.to_3x3() @ (rig.data.bones[f'Hand_{suffix}'].matrix_local.to_3x3().inverted()
					@ Vector((clips.PALM.x * side, clips.PALM.y, clips.PALM.z)))
				r['palm_gap'].append(round((Vector((palm.x, palm.y)) - centre).length - radius, 3))
			if 'trace' in ARGS:
				print(f'  {name} f{f:3d} eye x {eye.x:+.3f} y {eye.y:+.3f} z {eye.z:.3f} clear {clear:+.3f} '
					f'inside {deepest:.3f} at {tuple(round(c, 2) for c in where) if where else None} ik {ik:.2f} '
					f'low {tuple(round(c, 3) for c in min(pts, key=lambda q: q.z))}')
	# Smoothness: joint accelerations every frame, across the loop seam too.
	joints = ('Head', 'Chest', 'Hand_L', 'Hand_R', 'Forearm_L', 'Forearm_R')
	track = []
	for f in range(frames):
		scene.frame_set(f)
		ev = posed()
		track.append([ev.pose.bones[j].matrix.translation.copy() for j in joints])
	worst = (0.0, None, None)
	fps = clips.FPS
	for f in range(frames):
		for k, j in enumerate(joints):
			a = (track[(f + 1) % frames][k] - 2 * track[f][k] + track[f - 1][k]).length * fps * fps
			if a > worst[0]:
				worst = (a, j, f)
	r['max_accel'] = [round(worst[0], 2), worst[1], worst[2]]
	scene.frame_set(frames)
	ev = posed()
	r['seam'] = round(max((ev.pose.bones[j].matrix.translation - track[0][k]).length for k, j in enumerate(joints)), 5)
	r['foot_drift'] = round(drift, 4)
	r['min_z'] = round(r['min_z'], 4)
	if peek:
		r['inside'] = round(r['inside'], 3)
		r['eye_clear'] = round(r['eye_clear'], 3)
		r['palm_gap'] = [min(r['palm_gap'], default=None), max(r['palm_gap'], default=None)]
	report[name] = r
print('BIGFOOT_CHECK', json.dumps(report, indent=1))
