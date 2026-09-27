"""Clips for the deer, baked by deer.py.

A doe at the edge of a wood: quiet, watchful, and never still. The motion follows the
ambient Bigfoot's (tools/blender_bigfoot/ambient_clips.py), whose curve helpers it reuses:
- Key poses with travel and hold beats. Moves ease in, overshoot a touch and settle;
  the snap of an alert starts with a small dip the other way.
- Overlap: a look is spread down the neck with a delay per joint. The head arrives first
  and counter-turns to hold its target while the neck and shoulders catch up; head turns
  dip slightly on the way.
- Follow-through: ears and tail are damped springs driven by the head and hips, simulated
  over three loops so looping clips stay seamless.
- Moving holds: breath, a slow drift, ear swivels and tail flicks never stop.
Legs are solved here, not by Blender constraints: each hoof has a target (toe point, hoof
pitch, joint flex) and solve_legs() places the joints in closed form. The hind leg keeps
its cannon at a fixed angle to the thigh, so the stifle and hock fold together like a real
deer's; the fore leg keeps its knee straight unless flexed.
Angles are degrees about armature axes (Blender Z up, facing -Y): yaw + turns her face to
her left (+X), pitch + bows the head (and pitches the body nose-down), tilt + drops her
left ear. Side +1 is her left.
"""
import bpy, cmath, math
from mathutils import Vector, Quaternion

from ambient_clips import quat, local, set_rot, add_loc, clamp, smooth, beats, spline, pulses, breath, drift, blink, Spring, posed, gaze

FPS = 30
SIDES = ((1, 'L'), (-1, 'R'))
LEGS = {'LF': ('F', 'L'), 'RF': ('F', 'R'), 'LH': ('H', 'L'), 'RH': ('H', 'R')}
CHAIN = {'F': ('UpperArm', 'Forearm', 'FrontCannon', 'FrontHoof'), 'H': ('Thigh', 'Shin', 'HindCannon', 'HindHoof')}
LEG_BONES = {f'{b}_{s}' for k in CHAIN.values() for b in k for s in 'LR'}

# Each hoof's goal this frame: toe point (armature space), hoof pitch (+ lifts the heel over
# the toe), and flex (+ folds the knee or hock beyond the leg's rest shape).
TARGETS = {}
REPORT = {'reach': 0.0}


# ---------------------------------------------------------------- rig access

def reset(rig):
	for pb in rig.pose.bones:
		pb.location = (0, 0, 0)
		pb.rotation_quaternion = (1, 0, 0, 0)
		pb.scale = (1, 1, 1)
	TARGETS.clear()
	for leg in LEGS:
		TARGETS[leg] = {'toe': rest_data(rig, leg)['toe'].copy(), 'pitch': 0.0, 'flex': 0.0}


def key_all(rig, frame):
	for pb in rig.pose.bones:
		pb.keyframe_insert('location', frame=frame)
		pb.keyframe_insert('rotation_quaternion', frame=frame)


def snapshot(rig):
	bones = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in rig.pose.bones}
	targets = {leg: {k: (v.copy() if isinstance(v, Vector) else v) for k, v in tgt.items()} for leg, tgt in TARGETS.items()}
	return bones, targets


def restore(rig, snap):
	bones, targets = snap
	for name, (loc, rot) in bones.items():
		rig.pose.bones[name].location = loc
		rig.pose.bones[name].rotation_quaternion = rot


def axis(rig, key, suffix):
	return Vector(rig[key][0 if suffix == 'L' else 1]).normalized()


# ---------------------------------------------------------------- legs

_REST = {}


def signed(x, y, n):
	return math.atan2(x.cross(y).dot(n), x.dot(y))


def rest_data(rig, leg):
	key = (rig.name, leg)
	if key in _REST:
		return _REST[key]
	kind, suffix = LEGS[leg]
	names = [f'{b}_{suffix}' for b in CHAIN[kind]]
	bones = [rig.data.bones[n] for n in names]
	p0, j1, j2, fet = (b.head_local.copy() for b in bones)
	toe = bones[3].tail_local.copy()
	a, b, c = (j1 - p0).length, (j2 - j1).length, (fet - j2).length
	d = (fet - p0).normalized()
	u, v, w = (j1 - p0).normalized(), (j2 - j1).normalized(), (fet - j2).normalized()
	# The hind leg bends at a virtual joint (thigh and cannon added), the fore at the elbow.
	mid = p0 + (j1 - p0) + (fet - j2) if kind == 'H' else j1
	pole = mid - p0
	pole = (pole - d * pole.dot(d)).normalized()
	n = d.cross(pole).normalized()
	rel = signed(u, w, n) if kind == 'H' else signed(v, w, n)
	parent = bones[0].parent
	data = {'names': names, 'kind': kind, 'lengths': (a, b, c), 'rel': rel, 'parent': parent.name,
		'pole': parent.matrix_local.to_3x3().inverted() @ pole, 'hoof': fet - toe, 'toe': toe,
		'reach': None}
	_REST[key] = data
	return data


def aim_chain(rig, names, parent_matrix, parent_rest, dirs):
	"""Rotate each bone of a connected chain so it points along dirs[i], with the least turn
	from where its parent carries it."""
	parent_rot = parent_matrix.to_3x3().normalized()
	parent_rest = parent_rest.to_3x3().normalized()
	for name, want in zip(names, dirs):
		rest = rig.data.bones[name].matrix_local.to_3x3().normalized()
		base = parent_rot @ parent_rest.inverted() @ rest
		y0 = Vector(base.col[1]).normalized()
		q = y0.rotation_difference(want)
		bq = base.to_quaternion()
		rig.pose.bones[name].rotation_quaternion = bq.inverted() @ q @ bq
		parent_rot = q.to_matrix() @ base
		parent_rest = rest


def solve_legs(rig):
	"""Place every leg on its target, after the body is posed. Returns the evaluated rig as
	it stood before the legs were set (the legs carry nothing else)."""
	bpy.context.view_layer.update()
	ev = posed(rig)
	for leg in LEGS:
		R = rest_data(rig, leg)
		tgt = TARGETS[leg]
		mp = ev.pose.bones[R['parent']].matrix.copy()
		prest = rig.data.bones[R['parent']].matrix_local
		p0 = mp @ (prest.inverted() @ rig.data.bones[R['names'][0]].head_local)
		toe = Vector(tgt['toe'])
		fet = toe + Quaternion((1, 0, 0), math.radians(tgt['pitch'])) @ R['hoof']
		a, b, c = R['lengths']
		span = fet - p0
		D = span.length
		d = span / D
		pole = mp.to_3x3().normalized() @ R['pole']
		pole = (pole - d * pole.dot(d)).normalized()
		n = d.cross(pole).normalized()
		bend = R['rel'] + math.radians(tgt['flex'])
		if R['kind'] == 'H':
			z = a + c * cmath.exp(1j * bend)
			first, second = abs(z), b
		else:
			z = b + c * cmath.exp(1j * bend)
			first, second = a, abs(z)
		eps = cmath.phase(z)
		lo, hi = abs(first - second) + 1e-4, (first + second) * 0.9995
		reach = D / (first + second)
		REPORT['reach'] = max(REPORT['reach'], reach)
		Dc = min(max(D, lo), hi)
		alpha = math.acos(clamp((first ** 2 + Dc ** 2 - second ** 2) / (2 * first * Dc), -1.0, 1.0))
		w1 = d * math.cos(alpha) + pole * math.sin(alpha)
		mid = p0 + w1 * first
		w2 = (fet - mid).normalized()
		turn = lambda x, ang: Quaternion(n, ang) @ x
		if R['kind'] == 'H':
			u = turn(w1, -eps)
			v = w2
			w = turn(u, bend)
		else:
			u = w1
			v = turn(w2, -eps)
			w = turn(v, bend)
		end = p0 + u * a + v * b + w * c
		aim_chain(rig, R['names'], mp, prest, [u, v, w, (toe - end).normalized()])
	return ev


def place(leg, offset=(0, 0, 0), pitch=0.0, flex=0.0):
	tgt = TARGETS[leg]
	tgt['toe'] = tgt['toe'] + Vector(offset)
	tgt['pitch'] += pitch
	tgt['flex'] += flex


def step_arc(x, lift, reach=(0, 0, 0)):
	"""A hoof lifted and set down: x runs 0..1 over the move; returns (offset, pitch, flex)."""
	up = math.sin(math.pi * clamp(x)) ** 1.3
	# The hoof leaves the ground before it travels, and lands before it stops.
	return Vector(reach) * smooth((x - 0.12) / 0.76) + Vector((0, 0, lift * up)), 38 * up, 62 * up


# ---------------------------------------------------------------- body layers

DEER_GAZE = (('Spine', 0.05, 0.0, 10), ('Chest', 0.08, 0.04, 7), ('Neck1', 0.3, 0.3, 4), ('Neck2', 0.3, 0.3, 2))


def stand(rig, t, T, weight=0.0, fore=0.0, rise=0.0, breaths=4, breath_amp=1.0, lid=0.12, blinks=(), seed=0,
		drift_amp=1.0):
	"""The shared standing pose, alive in every hold. weight -1..1 carries her over her
	right..left side; fore + over her forelegs. Returns the breath (0..1)."""
	b = breath(t, T, breaths) * breath_amp
	d = [x * drift_amp for x in drift(t, T, seed)]
	# The body sways over planted hooves; the legs take it up.
	add_loc(rig, 'Hips', (0.014 * weight + 0.003 * d[0], -0.016 * fore + 0.002 * d[1], rise - 0.006 + 0.003 * b))
	set_rot(rig, 'Hips', ((0, 1, 0), 2.0 * weight), ((1, 0, 0), 1.4 * fore + 0.35 * d[2]))
	# Breath lifts the chest; the neck rides it, and the head keeps its level.
	set_rot(rig, 'Spine', ((1, 0, 0), -0.9 * b), ((0, 1, 0), -1.0 * weight))
	set_rot(rig, 'Chest', ((1, 0, 0), -0.7 * b), ((0, 1, 0), -0.6 * weight))
	set_rot(rig, 'Neck1', ((1, 0, 0), 0.9 * b + 0.8 * d[1]), ((0, 0, 1), 1.4 * d[0]))
	set_rot(rig, 'Neck2', ((1, 0, 0), -0.4 * b))
	set_rot(rig, 'Head', ((1, 0, 0), -0.7 * b + 0.8 * d[2]), ((0, 1, 0), 1.2 * d[0]))
	for s, suffix in SIDES:
		set_rot(rig, f'Scapula_{suffix}', ((1, 0, 0), -1.2 * fore))
		closed = max(lid, blink(t, blinks))
		set_rot(rig, f'Lid_{suffix}', (axis(rig, 'lid_axes', suffix), 72 * closed))
	return b


def ear(rig, suffix, swivel=0.0, perk=0.0, spread=0.0):
	"""swivel + turns the ear's opening back, toward a sound behind; perk + raises it and
	brings it forward (- lays it back); spread + lays it out to the side."""
	s = 1 if suffix == 'L' else -1
	set_rot(rig, f'Ear_{suffix}', (axis(rig, 'ear_axes', suffix), s * swivel), ((1, 0, 0), perk), ((0, 1, 0), s * spread))


def flick(t, starts, length=6):
	"""A quick ear or tail flick: out fast, back with a little bounce."""
	v = 0.0
	for start in starts:
		u = (t - start) / length
		if 0 <= u < 1:
			v += math.sin(0.5 * math.pi * u / 0.35) if u < 0.35 else (1 - smooth((u - 0.35) / 0.65)) * math.cos(9 * (u - 0.35)) ** 2
	return v


def ears(rig, t, left=(), right=(), flicks_l=(), flicks_r=(), perk=0.0, T=None):
	"""Ears on their own time. left/right are beats of (swivel, perk) keys; flicks shake an ear."""
	for suffix, keys, flicks in (('L', left, flicks_l), ('R', right, flicks_r)):
		sw, pk = beats(t, keys, T) if keys else Vector((0, 0))
		f = flick(t, flicks)
		ear(rig, suffix, swivel=sw + 18 * f, perk=pk + perk - 22 * f, spread=6 * f)


def tail(rig, t, flag=0.0, swish=0.0, flicks=()):
	"""flag + raises the tail (the alarm shows its white underside); swish + to her left."""
	f = sum((1 if i % 2 == 0 else -1) * flick(t, (start,), 7) for i, start in enumerate(flicks))
	set_rot(rig, 'Tail1', ((1, 0, 0), flag), ((0, 0, 1), swish + 16 * f))
	set_rot(rig, 'Tail2', ((1, 0, 0), 0.4 * flag), ((0, 0, 1), 0.5 * swish + 10 * f))


def chew(rig, t, amount, rate=2.3):
	"""Jaw open and a sideways grind, rate chews per second."""
	if amount <= 0:
		return
	phase = t * rate / FPS
	open_ = 0.5 - 0.5 * math.cos(math.tau * phase)
	set_rot(rig, 'Jaw', ((1, 0, 0), 6 * open_ * amount), ((0, 0, 1), 3.5 * math.sin(math.tau * phase - 0.8) * amount))


# The neck bows to the grass: Neck1, Neck2, Head (deg), the neck nearly straight and the
# head turned back up against it so the face hangs nose-down. The neck is short, so the
# forequarters come down to meet it: the body tips forward over the forelegs, the weight
# goes forward, the shoulders dip and the fore knees soften.
GRAZE = (115.0, 0.0, -86.0)


def lower(rig, k1, k2=None, k3=None, kb=None):
	k2 = k1 if k2 is None else k2
	k3 = k1 if k3 is None else k3
	kb = k1 if kb is None else kb
	set_rot(rig, 'Neck1', ((1, 0, 0), GRAZE[0] * k1))
	set_rot(rig, 'Neck2', ((1, 0, 0), GRAZE[1] * k2))
	set_rot(rig, 'Head', ((1, 0, 0), GRAZE[2] * k3))
	set_rot(rig, 'Chest', ((1, 0, 0), 7 * kb))
	set_rot(rig, 'Hips', ((1, 0, 0), 10 * kb))
	add_loc(rig, 'Hips', (0, -0.03 * kb, -0.03 * kb))
	for s, suffix in SIDES:
		set_rot(rig, f'Scapula_{suffix}', ((1, 0, 0), 5 * kb))
		place(f'{suffix}F', flex=14 * kb)


# ---------------------------------------------------------------- follow-through

# bone: (carrier, spring hz, damping, gain, cap in degrees)
SPRINGS = {
	'Ear_L': ('Head', 2.4, 0.26, 1.0, 22),
	'Ear_R': ('Head', 2.4, 0.26, 1.0, 22),
	'Tail1': ('Hips', 1.9, 0.3, 0.8, 24),
	'Tail2': ('Tail1', 2.8, 0.34, 0.7, 20),
}


def sample(rig, ev):
	out = {}
	for name, (carrier, *_) in SPRINGS.items():
		cm = ev.pose.bones[carrier].matrix
		crest = rig.data.bones[carrier].matrix_local
		tip = cm @ (crest.inverted() @ rig.data.bones[name].tail_local)
		out[name] = (tip, ev.pose.bones[name].matrix.to_3x3().normalized())
	return out


def follow_through(rig, frames, pose, periodic=True, loops=3):
	"""Per-frame (about-X, about-Z) spring offsets in each spring bone's own frame, driven by
	the acceleration of its tip as the carrier alone would move it."""
	samples = []
	for f in range(frames):
		reset(rig)
		pose(rig, f)
		samples.append(sample(rig, solve_legs(rig)))
	dt = 1 / FPS
	out = [dict() for _ in range(frames)]
	at = (lambda f: samples[f % frames]) if periodic else (lambda f: samples[min(max(f, 0), frames - 1)])
	for name, (carrier, hz, damping, gain, cap) in SPRINGS.items():
		spring = Spring(hz, damping)
		length = rig.data.bones[name].length
		lim = math.radians(cap)
		for loop in range(loops if periodic else 1):
			for f in range(frames):
				acc = (at(f + 1)[name][0] - 2 * at(f)[name][0] + at(f - 1)[name][0]) / dt ** 2
				rel = at(f)[name][1].inverted() @ acc
				x = spring.step(Vector((0, 0)), dt, Vector((-rel.z, rel.x)) * gain / length)
				if loop == (loops - 1 if periodic else 0):
					window = 1.0 if periodic else smooth(f / 6) * smooth((frames - 1 - f) / 8)
					out[f][name] = Vector((clamp(x.x, -lim, lim), clamp(x.y, -lim, lim))) * window
	return out


def apply_follow(rig, offsets):
	for name, o in offsets.items():
		pb = rig.pose.bones[name]
		pb.rotation_quaternion = pb.rotation_quaternion @ Quaternion((1, 0, 0), o.x) @ Quaternion((0, 0, 1), o.y)


# ---------------------------------------------------------------- baking

BAKED = {}  # clip name -> snapshots per frame, for transitions


def bake_clip(rig, name, frames, pose, loop=True):
	rig.animation_data_create()
	rig.animation_data.action = None
	count = frames if loop else frames + 1
	offsets = follow_through(rig, count, pose, periodic=loop)
	snaps = []
	for f in range(count):
		reset(rig)
		pose(rig, f)
		solve_legs(rig)
		apply_follow(rig, offsets[f])
		snaps.append(snapshot(rig))
	action = bpy.data.actions.new(name)
	action.use_fake_user = True
	rig.animation_data.action = action
	for f in range(frames + 1):
		restore(rig, snaps[f % count])
		key_all(rig, f)
	action.frame_range = (0, frames)
	action.use_frame_range = True
	track = rig.animation_data.nla_tracks.new()
	track.name = name
	track.strips.new(name, 0, action)
	track.mute = True
	rig.animation_data.action = None
	BAKED[name] = snaps
	return action


def between(rig, a, b, weight_of, extra=None):
	"""A pose between two baked snapshots, bone by bone: weight_of(bone) may run past 0..1
	for anticipation and overshoot. Leg bones are left to solve_legs, on blended targets."""
	(bones_a, targets_a), (bones_b, targets_b) = a, b
	for name, (la, ra) in bones_a.items():
		if name in LEG_BONES:
			continue
		lb, rb = bones_b[name]
		w = weight_of(name)
		delta = rb @ ra.inverted()
		if delta.w < 0:
			delta.negate()
		ax, ang = delta.to_axis_angle()
		pb = rig.pose.bones[name]
		pb.location = la.lerp(lb, w)
		pb.rotation_quaternion = Quaternion(ax, ang * w) @ ra
	for leg in LEGS:
		ta, tb = targets_a[leg], targets_b[leg]
		w = weight_of('body')
		TARGETS[leg] = {'toe': ta['toe'].lerp(tb['toe'], w), 'pitch': ta['pitch'] + (tb['pitch'] - ta['pitch']) * w,
			'flex': ta['flex'] + (tb['flex'] - ta['flex']) * w}
	if extra:
		extra()


# ---------------------------------------------------------------- clips

def idle(rig, t):
	"""Sixteen seconds at the edge of the wood: the weight wanders foot to foot, the head
	travels and holds (right, a sniff of the air, left), ears turn on their own to sounds,
	a forefoot shifts, the tail flicks at a fly."""
	T = 480
	weight = beats(t, [(0, 0.0), (40, 0.0), (95, 0.55, 0.1), (215, 0.55), (270, -0.45, 0.1), (385, -0.45), (440, 0.0, 0.05), (480, 0.0)], T)
	fore = beats(t, [(0, 0.0), (150, 0.0), (195, 0.45, 0.08), (300, 0.45), (345, 0.0), (480, 0.0)], T)
	stand(rig, t, T, weight=weight, fore=fore, breaths=4, blinks=(50, 168, 175, 292, 404), seed=1)
	look = lambda u: beats(u, [(0, (0, 0, 0)), (55, (0, 0, 0)), (80, (-26, -3, -4), 0.1), (165, (-26, -3, -4)),
		(186, (-20, 2, -1)), (228, (-20, 2, -1)), (258, (4, -1, 1), 0.05), (325, (4, -1, 1)),
		(350, (32, 1, 6), 0.1), (418, (32, 1, 6)), (455, (0, 0, 0), 0.04), (480, (0, 0, 0))], T)
	gaze(rig, t, look, chain=DEER_GAZE, arc=1.6)
	sniff = pulses(t, (196, 205, 214), 8)
	set_rot(rig, 'Head', ((1, 0, 0), -2.8 * sniff))
	ears(rig, t, T=T,
		left=[(0, (0, 0)), (70, (0, 0)), (76, (38, 4), 0.2), (150, (38, 4)), (158, (0, 0), 0.1), (300, (0, 0)),
			(305, (-12, 8), 0.15), (380, (-12, 8)), (390, (0, 0)), (480, (0, 0))],
		right=[(0, (0, 0)), (120, (0, 0)), (126, (42, 2), 0.2), (200, (42, 2)), (210, (0, 0), 0.1), (340, (0, 0)),
			(346, (30, -6), 0.2), (430, (30, -6)), (440, (0, 0)), (480, (0, 0))],
		flicks_l=(110, 262), flicks_r=(238, 245, 452))
	tail(rig, t, swish=2 * math.sin(math.tau * t / T), flicks=(128, 134, 322))
	# The right forefoot, unloaded while her weight is on the left, shifts forward and back.
	forward = Vector((0, -0.035, 0))
	for (a, b), start, reach in (((110, 126), Vector(), forward), ((196, 212), forward, -forward)):
		if a <= t <= b:
			off, pitch, flex = step_arc((t - a) / (b - a), 0.03, reach)
			place('RF', start + off, pitch, flex)
	if 126 < t < 196:
		place('RF', forward)


def graze(rig, t):
	"""Head down in the grass: crop, crop, crop, lift a little and chew with the ears
	turning, move the nose to a new patch, crop again. A forefoot steps forward and back."""
	T = 360
	weight = beats(t, [(0, 0.1), (120, 0.1), (150, -0.35, 0.08), (260, -0.35), (300, 0.1), (360, 0.1)], T)
	stand(rig, t, T, weight=weight, fore=0.6, breaths=3, blinks=(40, 150, 262), seed=2, drift_amp=0.6)
	lift = beats(t, [(0, 0), (58, 0), (78, 1, 0.05), (178, 1), (198, 0), (246, 0), (266, 1, 0.05), (336, 1), (356, 0), (360, 0)], T)
	lower(rig, 1.0 - 0.08 * lift, 1.0 - 0.1 * lift, 1.0 - 0.06 * lift, 1.0)
	patch = beats(t, [(0, (0, 0, 0)), (186, (0, 0, 0)), (204, (14, 0, 3), 0.06), (330, (14, 0, 3)), (352, (0, 0, 0), 0.04), (360, (0, 0, 0))], T)
	set_rot(rig, 'Neck1', ((0, 0, 1), 0.5 * patch.x))
	set_rot(rig, 'Neck2', ((0, 0, 1), 0.5 * patch.x), ((0, 1, 0), patch.z))
	# Each crop: the jaw opens, closes on the grass and the head tugs up and aside.
	crops = (14, 27, 40, 210, 223, 236)
	tug = pulses(t, crops, 9)
	bite = pulses(t, [c - 5 for c in crops], 7)
	side = sum((1 if i % 2 else -1) * pulses(t, (c,), 9) for i, c in enumerate(crops))
	set_rot(rig, 'Head', ((1, 0, 0), -7 * tug), ((0, 1, 0), 5 * side))
	set_rot(rig, 'Neck2', ((1, 0, 0), -3 * tug))
	set_rot(rig, 'Jaw', ((1, 0, 0), 9 * bite))
	chewing = beats(t, [(0, 0), (60, 0), (72, 1), (176, 1), (190, 0), (250, 0), (262, 1), (340, 1), (352, 0), (360, 0)], T)
	chew(rig, t, chewing)
	ears(rig, t, T=T,
		left=[(0, (0, 0)), (88, (0, 0)), (94, (40, 4), 0.2), (168, (40, 4)), (176, (0, 0), 0.1), (360, (0, 0))],
		right=[(0, (8, 0)), (138, (8, 0)), (144, (-18, 6), 0.2), (236, (-18, 6)), (246, (40, 0), 0.15), (318, (40, 0)),
			(330, (8, 0)), (360, (8, 0))],
		flicks_l=(60, 300), flicks_r=(274, 280))
	tail(rig, t, swish=1.5 * math.sin(math.tau * t / T + 1), flicks=(48, 54, 190, 302, 308))
	forward = Vector((0, -0.05, 0))
	for (a, b), start, reach in (((100, 118), Vector(), forward), ((286, 304), forward, -forward)):
		if a <= t <= b:
			off, pitch, flex = step_arc((t - a) / (b - a), 0.035, reach)
			place('RF', start + off, pitch, flex)
	if 118 < t < 286:
		place('RF', forward)


def alert(rig, t):
	"""Something in the trees: a tiny freeze, then the head snaps up and the ears lock
	forward, the tail half raised. A tense hold that still breathes; the head adjusts, one
	ear turns back and forward; a forefoot stomps. Then she lets it go with a sigh."""
	T = 180
	up = beats(t, [(0, 0), (5, 0), (9, -0.1), (15, 1, 0.14), (118, 1), (156, 0), (180, 0)], T)
	sigh = beats(t, [(0, 0), (116, 0), (128, 1), (134, 1), (164, 0), (180, 0)], T)
	stand(rig, t, T, rise=0.005 * up, weight=-0.12 * up, breaths=2, breath_amp=1 - 0.6 * up, lid=0.12 - 0.12 * up,
		blinks=(46, 142), seed=3, drift_amp=1 - 0.7 * up)
	set_rot(rig, 'Neck1', ((1, 0, 0), -15 * up + 4 * sigh))
	set_rot(rig, 'Neck2', ((1, 0, 0), -8 * up))
	set_rot(rig, 'Head', ((1, 0, 0), -16 * up + 3 * sigh))
	set_rot(rig, 'Chest', ((1, 0, 0), 2.5 * sigh))
	look = lambda u: beats(u, [(0, (0, 0, 0)), (32, (0, 0, 0)), (40, (-10, -2, -4), 0.15), (64, (-10, -2, -4)),
		(70, (-4, -1, 3), 0.2), (112, (-4, -1, 3)), (150, (0, 0, 0)), (180, (0, 0, 0))], T)
	gaze(rig, t, look, chain=DEER_GAZE, arc=1.0)
	# The head tips back as it rises; the ears perk past that to point at the sound.
	ears(rig, t, T=T, perk=36 * up,
		left=[(0, (0, 0)), (14, (-14, 0), 0.1), (120, (-14, 0)), (150, (0, 0)), (180, (0, 0))],
		right=[(0, (0, 0)), (14, (-14, 0), 0.1), (70, (-14, 0)), (75, (36, 0), 0.2), (96, (36, 0)), (100, (-14, 0), 0.15),
			(120, (-14, 0)), (150, (0, 0)), (180, (0, 0))],
		flicks_l=(160,))
	tail(rig, t, flag=32 * up, flicks=(150,))
	# The stomp: the left forefoot lifts high and strikes down hard; the body takes the jolt.
	if 82 <= t <= 95:
		x = (t - 82) / 8 if t <= 90 else 1 - ((t - 90) / 5) ** 2
		x = clamp(x)
		place('LF', (0, -0.012 * x, 0.075 * smooth(x)), 30 * x, 80 * smooth(x))
	jolt = pulses(t, (95,), 6)
	add_loc(rig, 'Hips', (0, 0, -0.006 * jolt))
	set_rot(rig, 'Head', ((1, 0, 0), 2.5 * jolt))


def look(rig, t):
	"""A long look back over her left shoulder: a small counter-turn, the head leads round
	and the neck follows, a curious tilt, a second tilt the other way, and back."""
	T = 240
	weight = beats(t, [(0, 0), (30, 0), (70, 0.3), (190, 0.3), (225, 0), (240, 0)], T)
	stand(rig, t, T, weight=weight, breaths=3, blinks=(62, 178), seed=4)
	turn = lambda u: beats(u, [(0, (0, 0, 0)), (24, (0, 0, 0)), (30, (-4, 2, 0)), (58, (54, -4, 5), 0.08), (120, (54, -4, 5)),
		(136, (57, -2, 14), 0.12), (182, (57, -2, 14)), (214, (0, 0, 0), 0.04), (240, (0, 0, 0))], T)
	gaze(rig, t, turn, chain=DEER_GAZE, arc=1.8)
	toward = beats(t, [(0, 0), (30, 0), (54, 1, 0.1), (188, 1), (212, 0), (240, 0)], T)
	ear(rig, 'L', swivel=-10 * toward, perk=10 * toward)
	ear(rig, 'R', swivel=30 * toward + 12 * flick(t, (150,)), perk=-4 * toward)
	tail(rig, t, flicks=(100,))


WALK_FRAMES = 44
STRIDE = 0.616  # metres the body travels per cycle
WALK_SPEED = STRIDE / (WALK_FRAMES / FPS)
DUTY = 0.64
PHASES = {'LH': 0.0, 'LF': 0.25, 'RH': 0.5, 'RF': 0.75}  # lateral sequence: each forefoot follows its hind


def walk(rig, t):
	"""A careful lateral-sequence walk (left hind, left fore, right hind, right fore), in place:
	move the root at WALK_SPEED. Hooves lift high with the knees folded and flick back; the
	head nods with each forefoot and otherwise holds its line."""
	T = WALK_FRAMES
	w = math.tau * t / T
	h = WALK_SPEED * DUTY * T / FPS / 2
	ground = 2 * h * (1 - DUTY) / DUTY  # stance speed in swing units, so the hoof leaves and lands without a kink
	for leg, start in PHASES.items():
		fore = leg[1] == 'F'
		p = (t / T - start) % 1.0
		if p < DUTY:
			q = p / DUTY
			y = -h + 2 * h * q
			lift = 0.0
			pitch = 34 * clamp((q - 0.72) / 0.28) ** 2
			flex = (12 if fore else 4) * clamp((q - 0.8) / 0.2) ** 2
		else:
			q = (p - DUTY) / (1 - DUTY)
			y = spline(q, [(0, h), (0.22, h - 0.01), (0.6, -0.45 * h), (0.86, -h - 0.012), (1, -h)], ground, ground)
			peak = 0.085 if fore else 0.06
			lift = spline(q, [(0, 0), (0.36, peak), (0.64, peak * 0.78), (0.88, peak * 0.22), (1, 0)], None, 0)
			pitch = spline(q, [(0, 34), (0.3, 70), (0.64, 40), (0.88, 6), (1, 0)], None, 0)
			flex = spline(q, [(0, 12), (0.36, 72), (0.7, 30), (0.9, 4), (1, 0)] if fore else
				[(0, 4), (0.36, 24), (0.7, 9), (1, 0)], None, 0)
		place(leg, (0, y, lift), pitch, flex)
		if fore:  # the shoulder blade swings with its leg
			s = 1 if leg[0] == 'L' else -1
			set_rot(rig, f'Scapula_{leg[0]}', ((1, 0, 0), 7 * y / h))
	# Small, soft body motion: it dips as each forefoot takes the weight and rolls over the hind.
	bob = math.cos(2 * (w - math.tau * 0.3))
	add_loc(rig, 'Hips', (0.006 * math.sin(w - 0.6), 0, -0.02 + 0.005 * bob))
	set_rot(rig, 'Hips', ((0, 1, 0), 1.6 * math.sin(w)), ((0, 0, 1), 1.4 * math.cos(w)), ((1, 0, 0), 1.0))
	set_rot(rig, 'Spine', ((0, 0, 1), -1.0 * math.cos(w - 0.3)), ((0, 1, 0), -0.8 * math.sin(w - 0.3)))
	set_rot(rig, 'Chest', ((0, 0, 1), -0.8 * math.cos(w - 0.5)), ((1, 0, 0), -0.4 * bob))
	nod = math.cos(2 * (w - math.tau * (0.25 + 0.1)))
	set_rot(rig, 'Neck1', ((1, 0, 0), 4 + 2.4 * nod), ((0, 0, 1), -0.8 * math.cos(w - 0.8)))
	set_rot(rig, 'Neck2', ((1, 0, 0), 1.2 * math.cos(2 * (w - math.tau * 0.4))))
	set_rot(rig, 'Head', ((1, 0, 0), -3 - 2.0 * nod))
	for s, suffix in SIDES:
		closed = max(0.12, blink(t, (30,)))
		set_rot(rig, f'Lid_{suffix}', (axis(rig, 'lid_axes', suffix), 72 * closed))
		ear(rig, suffix, swivel=4 * math.sin(w + (0 if s > 0 else 2.0)), perk=3 + 2 * nod)
	tail(rig, t, swish=4 * math.sin(w - 0.5))


def transition(a, b, lags, length, over=0.06, anti=0.0, arc=None):
	"""A one-shot pose between the first frames of two baked clips; lags delay each bone."""
	def pose(rig, t):
		def weight(name):
			lag = lags.get(name, lags.get(name.split('_')[0], lags['body']))
			return beats(t - lag, [(0, 0), (length, 1)], over=over, anti=anti if lag <= 2 else 0.0)
		between(rig, BAKED[a][0], BAKED[b][0], weight, extra=(lambda: arc(rig, t)) if arc else None)
	return pose


def head_down_arc(rig, t):
	# The nose reaches a little forward as it drops, so it travels on a curve, not a hinge.
	u = clamp((t - 3) / 24)
	set_rot(rig, 'Neck2', ((1, 0, 0), -5 * math.sin(math.pi * u)))
	chew(rig, t, pulses(t, (26,), 10))


def head_up_arc(rig, t):
	u = clamp(t / 22)
	set_rot(rig, 'Head', ((1, 0, 0), 3 * math.sin(math.pi * u)))
	chew(rig, t, clamp(1 - t / 30))


CLIPS = {  # name: (frames, pose, loops)
	'Idle': (480, idle, True),
	'Graze': (360, graze, True),
	'Look': (240, look, False),
	'Alert': (180, alert, False),
	'Walk': (WALK_FRAMES, walk, True),
}
TRANSITIONS = {  # name: (frames, from, to, lags per bone, arc)
	# The neck leads both ways and the face turns last: down to the grass, up to level.
	'HeadDown': (40, 'Idle', 'Graze', {'Neck1': 0, 'Neck2': 1, 'Head': 4, 'Jaw': 4, 'Lid': 0, 'Ear': 5, 'Chest': 3,
		'Scapula': 7, 'Spine': 8, 'Hips': 9, 'Tail1': 10, 'Tail2': 12, 'body': 8}, head_down_arc, 0.02, 0.06),
	'HeadUp': (36, 'Graze', 'Idle', {'Neck1': 0, 'Neck2': 1, 'Head': 4, 'Jaw': 4, 'Lid': 0, 'Ear': 3, 'Chest': 2,
		'Scapula': 5, 'Spine': 6, 'Hips': 7, 'Tail1': 8, 'Tail2': 10, 'body': 6}, head_up_arc, 0.1, 0.0),
}


def bake_all(rig):
	for name, (frames, pose, loop) in CLIPS.items():
		bake_clip(rig, name, frames, pose, loop)
		print('DEER_CLIP', name, frames, 'reach', round(REPORT['reach'], 4))
		REPORT['reach'] = 0.0
	for name, (frames, a, b, lags, arc, over, anti) in TRANSITIONS.items():
		move = 26 if name == 'HeadDown' else 22
		bake_clip(rig, name, frames, transition(a, b, lags, move, over, anti, arc), loop=False)
		print('DEER_CLIP', name, frames, 'reach', round(REPORT['reach'], 4))
		REPORT['reach'] = 0.0


ALL_CLIPS = {**{k: (v[0], v[2]) for k, v in CLIPS.items()}, **{k: (v[0], False) for k, v in TRANSITIONS.items()}}
