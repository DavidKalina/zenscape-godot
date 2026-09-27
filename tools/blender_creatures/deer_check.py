"""Numeric checks on the baked deer clips. Run after deer.py:

  blender -b --python tools/blender_creatures/deer_check.py -- [--clip=Walk]

For every clip: the lowest vertex (hooves through the ground), how far planted hooves slide
(in the world, with Walk moving at its speed), the loop seam, the worst joint acceleration
(pops) and where it happens, and for Graze how high the nose rides above the ground.
"""
import bpy, json, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / 'blender_trees'))
sys.path.insert(0, str(HERE.parent / 'blender_bigfoot'))
import deer_clips as clips
import kit

ARGS = dict(a.lstrip('-').split('=', 1) if '=' in a else (a.lstrip('-'), '1') for a in kit.ARGS)

bpy.ops.wm.open_mainfile(filepath=str(kit.ROOT / 'art/blender/creatures/zenscape-deer.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['DeerRig']
body = bpy.data.objects['Deer']
for track in rig.animation_data.nla_tracks:
	track.mute = True

HOOVES = {leg: f'{"FrontHoof" if leg[1] == "F" else "HindHoof"}_{leg[0]}' for leg in clips.LEGS}
JOINTS = ('Head', 'Neck2', 'Chest', 'Hips', 'Ear_L', 'Ear_R', 'Tail2', 'FrontCannon_L', 'HindCannon_R', 'Jaw')


def posed():
	return rig.evaluated_get(bpy.context.evaluated_depsgraph_get())


def lowest():
	dg = bpy.context.evaluated_depsgraph_get()
	ev = body.evaluated_get(dg)
	mesh = ev.to_mesh()
	low = min(v.co.z for v in mesh.vertices)
	ev.to_mesh_clear()
	return low


report = {}
names = [ARGS['clip']] if 'clip' in ARGS else list(clips.ALL_CLIPS)
for name in names:
	frames, loop = clips.ALL_CLIPS[name]
	rig.animation_data.action = bpy.data.actions[name]
	walking = name == 'Walk'
	speed = clips.WALK_SPEED / clips.FPS if walking else 0.0
	r = {'frames': frames, 'min_z': 9.0}
	track, toes = [], []
	for f in range(frames + 1):
		scene.frame_set(f)
		ev = posed()
		track.append([ev.pose.bones[j].matrix.translation.copy() for j in JOINTS])
		toe = {}
		for leg, bone in HOOVES.items():
			m = ev.pose.bones[bone]
			p = m.matrix @ clips.Vector((0, m.length, 0))
			p.y -= speed * f  # into the world: the root moves forward (-Y) at walk speed
			toe[leg] = p
		toes.append(toe)
		if f % 4 == 0:
			low = lowest()
			if low < r['min_z']:
				r['min_z'], r['min_z_frame'] = round(low, 4), f
		if name == 'Graze':
			nose = ev.pose.bones['Head'].matrix @ clips.Vector((0, ev.pose.bones['Head'].length, 0))
			r['nose_min'] = round(min(r.get('nose_min', 9), nose.z), 3)
			r['nose_max'] = round(max(r.get('nose_max', -9), nose.z), 3)
	# A hoof is planted when it is on the ground; while planted it must not slide.
	slide = {}
	for leg in HOOVES:
		worst = 0.0
		for f in range(1, frames + 1):
			a, b = toes[f - 1][leg], toes[f][leg]
			if a.z < 0.004 and b.z < 0.004:
				worst = max(worst, (b - a).length * clips.FPS)
		slide[leg] = round(worst, 3)
	r['planted_slide_mps'] = slide
	worst = (0.0, None, None)
	n = frames if loop else frames + 1
	for f in range(n):
		for k, j in enumerate(JOINTS):
			if loop:
				p0, p1, p2 = track[(f - 1) % frames][k], track[f][k], track[(f + 1) % frames][k]
			else:
				p0, p1, p2 = track[max(f - 1, 0)][k], track[f][k], track[min(f + 1, frames)][k]
			a = (p2 - 2 * p1 + p0).length * clips.FPS ** 2
			if a > worst[0]:
				worst = (a, j, f)
	r['max_accel'] = [round(worst[0], 2), worst[1], worst[2]]
	if loop:
		r['seam'] = round(max((track[frames][k] - track[0][k]).length for k in range(len(JOINTS))), 5)
	report[name] = r
print('DEER_CHECK', json.dumps(report, indent=1))
