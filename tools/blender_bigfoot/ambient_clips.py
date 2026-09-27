"""Clips for the ambient Bigfoot, baked by build_ambient_bigfoot.py.

He is a neutral woodland presence: unhurried, curious and hard to read, never a monster
and never a mascot. The motion aims for the polish of hand-keyed game idles:
- Key poses with travel and hold beats. Moves ease in, overshoot a touch and settle;
  bigger ones start with a small anticipation the other way.
- Overlap: a gaze is spread down the spine with a delay per joint. The head arrives
  first and counter-turns to hold its target while the chest catches up, and head
  turns dip slightly on the way (an arc, not a swivel).
- Follow-through: arms, forearms and hands are damped springs driven by the posed body,
  simulated over three loops so every clip stays seamless.
- Moving holds: breath and a slow drift never stop, even while his eyes are fixed.
Angles are degrees about armature axes (Blender Z up, facing -Y): yaw + turns his face
to his left (+X), pitch + bows the head, tilt + drops his left ear. Side +1 is his left.
"""
import bpy, math
from mathutils import Vector, Quaternion, Matrix

FPS = 30
SIDES = ((1, 'L'), (-1, 'R'))
PALM = Vector((0.008, -0.035, -0.09))  # palm centre from the wrist, left hand (build_ambient_bigfoot)
PEEK_TRUNK = (Vector((0.0, -0.92)), 0.42)  # trunk axis (x, y) and radius the peeks are authored against


# ---------------------------------------------------------------- rig access

def quat(*pairs):
	q = Quaternion()
	for axis, degrees in pairs:
		q = Quaternion(Vector(axis), math.radians(degrees)) @ q
	return q


def local(rig, name, q_arm):
	"""A rotation given in armature axes, expressed in the bone's rest frame."""
	rest = rig.data.bones[name].matrix_local.to_3x3().to_quaternion()
	return rest.inverted() @ q_arm @ rest


def set_rot(rig, name, *pairs):
	pb = rig.pose.bones[name]
	pb.rotation_quaternion = local(rig, name, quat(*pairs)) @ pb.rotation_quaternion


def add_loc(rig, name, offset):
	"""Translate a bone by an armature-space offset, on top of what is there."""
	rest = rig.data.bones[name].matrix_local.to_3x3()
	rig.pose.bones[name].location += rest.inverted() @ Vector(offset)


def put(rig, name, point):
	"""Place a Root-level control's head at an armature-space point."""
	bone = rig.data.bones[name]
	rig.pose.bones[name].location = bone.matrix_local.to_3x3().inverted() @ (Vector(point) - bone.head_local)


IK_CONSTRAINTS = [(f'Forearm_{s}', 'ArmIK') for _, s in SIDES] + [(f'Hand_{s}', 'ArmIKHand') for _, s in SIDES]


def reset(rig):
	for pb in rig.pose.bones:
		pb.location = (0, 0, 0)
		pb.rotation_quaternion = (1, 0, 0, 0)
		pb.scale = (1, 1, 1)
	for bone, con in IK_CONSTRAINTS:
		rig.pose.bones[bone].constraints[con].influence = 0.0


def key_all(rig, frame):
	for pb in rig.pose.bones:
		pb.keyframe_insert('location', frame=frame)
		pb.keyframe_insert('rotation_quaternion', frame=frame)
	for bone, con in IK_CONSTRAINTS:
		rig.pose.bones[bone].constraints[con].keyframe_insert('influence', frame=frame)


# ---------------------------------------------------------------- curves

def clamp(x, a=0.0, b=1.0):
	return max(a, min(b, x))


def smooth(x):
	x = clamp(x)
	return x * x * (3 - 2 * x)


def settle(x, over=0.0, anti=0.0):
	"""0..1 ease. With over it arrives early, overshoots by that fraction and settles;
	with anti it first dips the other way."""
	x = clamp(x)
	if over <= 0 and anti <= 0:
		return smooth(x)
	v = smooth(x / 0.72) if over > 0 else smooth(x)
	if over > 0 and x > 0.5:
		v += over * math.sin(math.pi * (x - 0.5) / 0.5) ** 2
	if anti > 0 and x < 0.3:
		v -= anti * math.sin(math.pi * x / 0.3) ** 2
	return v


def beats(t, keys, period=None, over=0.0, anti=0.0):
	"""Value at frame t through (frame, value[, overshoot]) keys. Each segment eases with
	settle(); equal neighbours hold. Values may be numbers or tuples. t wraps on period."""
	if period:
		t %= period
	vec = not isinstance(keys[0][1], (int, float))
	val = (lambda v: Vector(v)) if vec else (lambda v: v)
	if t <= keys[0][0]:
		return val(keys[0][1])
	for a, b in zip(keys, keys[1:]):
		if t <= b[0]:
			o = b[2] if len(b) > 2 else over
			u = settle((t - a[0]) / max(1e-6, b[0] - a[0]), o, anti)
			return val(a[1]) + (val(b[1]) - val(a[1])) * u
	return val(keys[-1][1])


def pulses(t, starts, length=8):
	"""Sum of soft bumps (0..1) starting at the given frames: sniffs, taps."""
	v = 0.0
	for s in starts:
		u = (t - s) / length
		if 0 <= u <= 1:
			v += math.sin(math.pi * u) ** 2
	return v


def breath(t, period, cycles):
	"""0 empty .. 1 full. A slower exhale than inhale, with a rest at the bottom."""
	phase = (t * cycles / period) % 1.0
	return beats(phase, [(0, 0), (0.38, 1), (0.86, 0), (1, 0)])


def drift(t, period, seed=0):
	"""Three slow, seamless wander channels, roughly -1..1."""
	out = []
	for c in range(3):
		v = 0.0
		for k, a in ((1, 0.62), (2, 0.28), (3, 0.14)):
			v += a * math.sin(math.tau * k * t / period + 1.7 * c + 2.3 * k + seed)
		out.append(v)
	return out


def blink(t, starts):
	"""0 open .. 1 closed. A start may be (frame, slowness) for a slow, calm blink."""
	value = 0.0
	for s in starts:
		s, k = (s, 1.0) if isinstance(s, (int, float)) else s
		close, hold, open_ = 3 * k, 1 * k, 5 * k
		d = t - s
		if 0 <= d < close:
			value = max(value, smooth(d / close))
		elif close <= d < close + hold:
			value = 1.0
		elif close + hold <= d < close + hold + open_:
			value = max(value, 1 - smooth((d - close - hold) / open_))
	return value


# ---------------------------------------------------------------- body layers

def curl(rig, suffix, degrees, thumb=None):
	"""Fingers into the palm (+) or spread (-)."""
	s = 1 if suffix == 'L' else -1
	set_rot(rig, f'Fingers_{suffix}', ((0, 1, 0), s * degrees))
	set_rot(rig, f'Thumb_{suffix}', ((0, 0, 1), -s * 0.5 * (degrees if thumb is None else thumb)))


def roll(rig, suffix, degrees):
	"""Roll a foot: + lifts the heel over the ball of the foot, - lifts the toes over the
	heel. The pivot stays put, so neither end digs into the ground."""
	if degrees == 0:
		return
	ankle = rig.data.bones[f'FootIK_{suffix}'].head_local
	pivot = Vector((ankle.x, -0.17, 0.02) if degrees > 0 else (ankle.x, 0.11, 0.01))
	q = quat(((1, 0, 0), degrees))
	add_loc(rig, f'FootIK_{suffix}', q @ (ankle - pivot) - (ankle - pivot))
	set_rot(rig, f'FootIK_{suffix}', ((1, 0, 0), degrees))


def heel(rig, suffix, degrees):
	"""Roll a planted foot up onto its ball."""
	if degrees > 0:
		roll(rig, suffix, degrees)


def stand(rig, t, T, weight=0.0, knees=0.035, breaths=3, breath_amp=1.0, lid=0.22, blinks=(),
		lean=0.0, hunch=0.0, arms_out=4.0, curl_l=12.0, curl_r=12.0, seed=0):
	"""The shared standing pose, alive in every hold. weight -1..1 carries him over his
	right..left foot; lean + tips the whole trunk forward. Returns the breath (0..1)."""
	b = breath(t, T, breaths) * breath_amp
	d = drift(t, T, seed)
	# Soft knees that sink a little on each exhale; the hip drops on the free side.
	add_loc(rig, 'Pelvis', (0.045 * weight + 0.006 * d[0], 0.005 * d[1], -knees - 0.006 * (1 - b)))
	set_rot(rig, 'Pelvis', ((1, 0, 0), 2 + 0.3 * lean), ((0, 1, 0), -3.0 * weight))
	# Breath lifts and opens the chest; the head rides it and stays bowed, looking out
	# from under the brow.
	set_rot(rig, 'Spine', ((1, 0, 0), 1.5 - 1.0 * b + 0.5 * d[2] + 0.4 * lean + hunch), ((0, 1, 0), 2.2 * weight))
	set_rot(rig, 'Chest', ((1, 0, 0), 1.0 - 1.6 * b + 0.3 * lean + hunch), ((0, 1, 0), 0.9 * weight))
	set_rot(rig, 'Neck', ((1, 0, 0), -1.0 + 0.5 * b - 0.5 * lean - hunch))
	set_rot(rig, 'Head', ((1, 0, 0), 2.5 + 0.8 * b + 0.6 * d[1] - 0.2 * lean - hunch))
	for s, suffix in SIDES:
		set_rot(rig, f'Shoulder_{suffix}', ((0, 1, 0), -s * 1.3 * b))
		set_rot(rig, f'UpperArm_{suffix}', ((1, 0, 0), -3), ((0, 1, 0), -s * arms_out))
		set_rot(rig, f'Forearm_{suffix}', ((1, 0, 0), -12))
		set_rot(rig, f'Hand_{suffix}', ((1, 0, 0), -5), ((0, 1, 0), -s * 3))
		curl(rig, suffix, (curl_l if s > 0 else curl_r) + 4 * b)
		closed = max(lid, blink(t, blinks))
		set_rot(rig, f'Lid_{suffix}', ((1, 0, 0), -70 * closed))
	# The unloaded foot rolls onto its ball.
	heel(rig, 'L', 6 * clamp(-weight - 0.2) / 0.8)
	heel(rig, 'R', 6 * clamp(weight - 0.2) / 0.8)
	return b


GAZE_CHAIN = (('Spine', 0.1, 0.03, 12), ('Chest', 0.2, 0.1, 7), ('Neck', 0.28, 0.3, 3))


def gaze(rig, t, look, chain=GAZE_CHAIN, arc=2.2):
	"""look(t) -> (yaw, pitch, tilt) the head should face, in degrees. Each joint takes a
	share of a delayed copy; the head takes the rest, so it leads and then holds steady as
	the body catches up. Turns dip the head by arc degrees per degree-per-frame of yaw."""
	def at(u):
		v = Vector(look(u))
		v.y += arc * abs(Vector(look(u + 1)).x - Vector(look(u - 1)).x) * 0.5
		return v
	target = at(t)
	used = Vector()
	for bone, yaw_share, pitch_share, lag in chain:
		g = at(t - lag)
		part = Vector((g.x * yaw_share, g.y * pitch_share, g.z * pitch_share))
		set_rot(rig, bone, ((0, 0, 1), part.x), ((1, 0, 0), part.y), ((0, 1, 0), part.z))
		used += part
	h = target - used
	set_rot(rig, 'Head', ((0, 0, 1), h.x), ((1, 0, 0), h.y), ((0, 1, 0), h.z))


def hand_turn(rig, suffix, fingers, palm):
	"""Rotation (armature axes) taking the rest hand to fingers pointing along `fingers`
	with the palm facing `palm`."""
	s = 1 if suffix == 'L' else -1
	bone = rig.data.bones[f'Hand_{suffix}']
	y0 = (bone.tail_local - bone.head_local).normalized()
	n0 = Vector((-s, 0, 0))
	n0 = (n0 - y0 * n0.dot(y0)).normalized()
	y1 = Vector(fingers).normalized()
	n1 = Vector(palm)
	n1 = (n1 - y1 * n1.dot(y1)).normalized()
	m0 = Matrix((y0, n0, y0.cross(n0))).transposed()
	m1 = Matrix((y1, n1, y1.cross(n1))).transposed()
	return (m1 @ m0.transposed()).to_quaternion()


def hanging_palm(rig, suffix):
	"""Where the palm hangs in the pose so far, before any IK: reaches start and end here."""
	s = 1 if suffix == 'L' else -1
	return carried(rig, f'Hand_{suffix}', rig.data.bones[f'Hand_{suffix}'].head_local + Vector((PALM.x * s, PALM.y, PALM.z)))


def reach(rig, suffix, amount, palm_point, turn, pole=(1.3, 0.3, 0.7)):
	"""Blend an arm onto IK with the palm centre at an armature-space point. The elbow
	bends toward pole, given for the left arm and mirrored for the right."""
	if amount <= 0:
		return
	s = 1 if suffix == 'L' else -1
	offset = Vector((PALM.x * s, PALM.y, PALM.z))
	put(rig, f'HandIK_{suffix}', Vector(palm_point) - turn @ offset)
	put(rig, f'ElbowPole_{suffix}', Vector((pole[0] * s, pole[1], pole[2])))
	pb = rig.pose.bones[f'HandIK_{suffix}']
	pb.rotation_quaternion = local(rig, f'HandIK_{suffix}', turn)
	rig.pose.bones[f'Forearm_{suffix}'].constraints['ArmIK'].influence = amount
	rig.pose.bones[f'Hand_{suffix}'].constraints['ArmIKHand'].influence = amount


# ---------------------------------------------------------------- follow-through

class Spring:
	"""A damped 2D spring on (about-X, about-Y) angles, in radians."""

	def __init__(self, hz, damping):
		self.w, self.z = math.tau * hz, damping
		self.x, self.v = Vector((0, 0)), Vector((0, 0))

	def step(self, target, dt, force=Vector((0, 0))):
		h = dt / 4
		for _ in range(4):
			a = (target - self.x) * self.w ** 2 - self.v * (2 * self.z * self.w) + force
			self.v += a * h
			self.x += self.v * h
		return self.x


def hang_angles(d):
	"""(about-X, about-Y) rotation that takes straight down to direction d."""
	return Vector((math.atan2(d.y, -d.z), math.atan2(-d.x, -d.z)))


def posed(rig):
	"""The evaluated rig, after bpy.context.view_layer.update()."""
	return rig.evaluated_get(bpy.context.evaluated_depsgraph_get())


def carried(rig, bone, point):
	"""Where an armature rest-space point sits once the named bone is posed. Poses applied
	so far count; call it mid-pose to aim a hand at the body."""
	bpy.context.view_layer.update()
	rest = rig.data.bones[bone].matrix_local
	return posed(rig).pose.bones[bone].matrix @ (rest.inverted() @ Vector(point))


def sample(rig):
	out = {}
	ev = posed(rig)
	for s, suffix in SIDES:
		bones = [ev.pose.bones[f'{p}_{suffix}'] for p in ('UpperArm', 'Forearm', 'Hand')]
		out[suffix] = {
			'angles': [hang_angles(pb.matrix.to_3x3() @ Vector((0, 1, 0))) for pb in bones],
			'shoulder': bones[0].matrix.translation.copy(),
			'ik': ev.pose.bones[f'Forearm_{suffix}'].constraints['ArmIK'].influence,
		}
	return out


def follow_through(rig, frames, pose, loops=3):
	"""Per-frame (upper arm, forearm, hand) angle offsets for both arms, from springs driven
	by the posed body over several loops. The last loop is periodic, so clips stay seamless."""
	samples = []
	for f in range(frames):
		reset(rig)
		pose(rig, f)
		bpy.context.view_layer.update()
		samples.append(sample(rig))
	dt = 1 / FPS
	out = [dict() for _ in range(frames)]
	for s, suffix in SIDES:
		upper, fore, hand = Spring(0.75, 0.32), Spring(1.15, 0.38), Spring(1.8, 0.45)
		first = samples[0][suffix]['angles']
		upper.x, fore.x, hand.x = first[0].copy(), first[1].copy(), first[2].copy()
		for loop in range(loops):
			for f in range(frames):
				cur = samples[f][suffix]
				p0 = samples[(f - 1) % frames][suffix]['shoulder']
				p2 = samples[(f + 1) % frames][suffix]['shoulder']
				acc = (p2 - 2 * cur['shoulder'] + p0) / dt ** 2
				a1, a2, a3 = cur['angles']
				# A hand that holds something steadies its arm: no swing builds up to be
				# released when it lets go.
				for spring, target in ((upper, a1), (fore, a2), (hand, a3)):
					spring.x = spring.x.lerp(target, cur['ik'])
					spring.v *= 1 - cur['ik']
				x1 = upper.step(a1, dt, Vector((-acc.y, acc.x)) / 0.55)
				o1 = x1 - a1
				x2 = fore.step(a2 + o1, dt)
				o2 = x2 - (a2 + o1)
				x3 = hand.step(a3 + o1 + o2, dt)
				o3 = x3 - (a3 + o1 + o2)
				if loop == loops - 1:
					free = 1 - cur['ik']
					lim = math.radians(25)
					cap = lambda o, side=1.0: Vector((clamp(o.x, -lim, lim), side * clamp(o.y, -lim, lim))) * free
					out[f][suffix] = (cap(o1), cap(o2, 0.3), cap(o3, 0.5))
	return out


def apply_follow(rig, offsets):
	for suffix, parts in offsets.items():
		for bone, o in zip(('UpperArm', 'Forearm', 'Hand'), parts):
			set_rot(rig, f'{bone}_{suffix}', ((1, 0, 0), math.degrees(o.x)), ((0, 1, 0), math.degrees(o.y)))


def snapshot(rig):
	bones = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in rig.pose.bones}
	cons = {k: rig.pose.bones[k[0]].constraints[k[1]].influence for k in IK_CONSTRAINTS}
	return bones, cons


def restore(rig, snap):
	bones, cons = snap
	for name, (loc, rot) in bones.items():
		rig.pose.bones[name].location = loc
		rig.pose.bones[name].rotation_quaternion = rot
	for (bone, con), value in cons.items():
		rig.pose.bones[bone].constraints[con].influence = value


def bake_clip(rig, name, frames, pose):
	# Pose every frame with no action assigned: poses that measure the body mid-way
	# (carried) update the depsgraph, which would otherwise re-apply the action's keys.
	rig.animation_data_create()
	rig.animation_data.action = None
	offsets = follow_through(rig, frames, pose)
	snaps = []
	for f in range(frames):
		reset(rig)
		pose(rig, f)
		apply_follow(rig, offsets[f])
		snaps.append(snapshot(rig))
	action = bpy.data.actions.new(name)
	action.use_fake_user = True
	rig.animation_data.action = action
	for f in range(frames + 1):
		restore(rig, snaps[f % frames])
		key_all(rig, f)
	action.frame_range = (0, frames)
	action.use_frame_range = True
	track = rig.animation_data.nla_tracks.new()
	track.name = name
	track.strips.new(name, 0, action)
	track.mute = True
	rig.animation_data.action = None
	return action


# ---------------------------------------------------------------- clips

def idle(rig, t):
	"""Sixteen seconds of quiet attention: weight wanders foot to foot, the head travels and
	holds (right, a pause to sniff the air, left), the shoulders follow late."""
	T = 480
	weight = beats(t, [(0, -0.5), (70, -0.5), (128, 0.55, 0.12), (290, 0.55), (350, -0.5, 0.12), (480, -0.5)], T)
	# A little dip as the weight travels: the knees take it.
	travel = abs(beats(t + 1, [(0, -0.5), (70, -0.5), (128, 0.55), (290, 0.55), (350, -0.5), (480, -0.5)], T)
		- beats(t - 1, [(0, -0.5), (70, -0.5), (128, 0.55), (290, 0.55), (350, -0.5), (480, -0.5)], T))
	flex = beats(t, [(0, 0), (318, 0), (334, -1), (350, -1), (372, 1.2, 0.1), (400, 0), (480, 0)], T)
	stand(rig, t, T, weight=weight, knees=0.035 + 0.25 * travel, breaths=4,
		blinks=(42, 186, 193, 277, 412), curl_r=12 + 10 * flex)
	look = lambda u: beats(u, [(0, (-8, 2, 0)), (40, (-8, 2, 0)), (88, (-36, 1, -3), 0.06), (150, (-36, 1, -3)),
		(188, (-3, -1, 1), 0.05), (236, (-3, -1, 1)), (275, (30, 1, 4), 0.06), (360, (30, 1, 4)),
		(410, (-8, 2, 0), 0.04), (480, (-8, 2, 0))], T)
	gaze(rig, t, look)
	sniff = pulses(t, (198, 207, 216), 8)
	set_rot(rig, 'Head', ((1, 0, 0), -2.2 * sniff))
	set_rot(rig, 'Chest', ((1, 0, 0), -0.6 * sniff))


def watch(rig, t):
	"""The encounter beat: a glance, a slow full turn to face you, a long still look with a
	curious tilt and a slow blink, then he loses interest and looks back the way he was."""
	T = 420
	look = lambda u: beats(u, [(0, (38, 2, 2)), (40, (38, 2, 2)), (46, (39, 3.5, 2)),
		(58, (18, 0, 0), 0.14), (96, (18, 0, 0)), (152, (0, -1, 0), 0.05), (190, (0, -1, 0)),
		(228, (0, -1, -7)), (292, (0, -1, -7)), (318, (-3, 1, -3)), (376, (38, 5, 2)), (420, (38, 2, 2))], T)
	back = beats(t, [(0, 0), (96, 0), (160, 1), (318, 1), (380, 0), (420, 0)], T)
	weight = beats(t, [(0, -0.4), (96, -0.4), (160, -0.1), (330, -0.1), (390, -0.4), (420, -0.4)], T)
	grip = beats(t, [(0, 0), (160, 0), (205, 1), (296, 1), (332, 0), (420, 0)], T)
	stand(rig, t, T, weight=weight, breaths=3, breath_amp=1 - 0.4 * back, lid=0.22 - 0.07 * back,
		blinks=(48, (252, 2.6), 381), curl_r=12 + 12 * grip, curl_l=12 + 6 * grip)
	# Wary, not hostile: his weight settles back onto his heels while he looks.
	add_loc(rig, 'Pelvis', (0, 0.022 * back, 0))
	set_rot(rig, 'Spine', ((1, 0, 0), -1.5 * back))
	gaze(rig, t, look)


def listen(rig, t):
	"""Something off to his left: he rises a little, finds it with small head adjustments,
	holds his breath, sniffs, then lets it go with a sigh."""
	T = 360
	look = lambda u: beats(u, [(0, (-5, 3, 0)), (34, (-5, 3, 0)), (40, (-5, 4.5, 0)), (56, (22, -8, 3), 0.1),
		(76, (22, -8, 3)), (82, (27, -9, 5), 0.25), (104, (27, -9, 5)), (110, (24, -7, 4), 0.25),
		(262, (24, -7, 4)), (304, (-5, 4, 0), 0.04), (360, (-5, 3, 0))], T)
	alert = beats(t, [(0, 0), (40, 0), (58, 1, 0.1), (262, 1), (312, 0), (360, 0)], T)
	sigh_in = beats(t, [(0, 0), (258, 0), (280, 1), (286, 1), (330, 0), (360, 0)], T)
	sniff = pulses(t, (124, 135, 146, 180, 191), 9)
	stand(rig, t, T, knees=0.035 - 0.022 * alert, breaths=3, breath_amp=1 - 0.7 * alert,
		lean=-2.5 * alert, blinks=(42, 106, 290), curl_l=12 - 9 * alert, curl_r=12 - 7 * alert)
	gaze(rig, t, look)
	set_rot(rig, 'Head', ((1, 0, 0), -2.4 * sniff))
	set_rot(rig, 'Chest', ((1, 0, 0), -0.8 * sniff - 3.0 * sigh_in))
	for s, suffix in SIDES:
		set_rot(rig, f'Shoulder_{suffix}', ((0, 1, 0), -s * 3.5 * sigh_in))


def peek(rig, t, side):
	"""Behind a trunk (PEEK_TRUNK): he settles onto the far foot, takes hold of the bark,
	steps the near foot out and leans, slowly, head last. Seeing you there, a small take;
	a long still look with a curious tilt; then the head ducks back first, the body follows
	and the foot steps home."""
	T = 480
	s = side
	suffix, other = ('L', 'R') if s > 0 else ('R', 'L')
	env = lambda keys, lag=0: beats(t - lag, keys, T)
	BODY = [(0, 0), (112, 0), (184, 1), (346, 1), (398, 0), (480, 0)]
	HEAD = [(0, 0), (124, 0), (194, 1), (338, 1), (364, 0), (480, 0)]
	NOTICE = [(0, 0), (192, 0), (202, 1, 0.18), (344, 1), (372, 0), (480, 0)]
	CURIOUS = [(0, 0), (232, 0), (268, 1), (318, 1), (340, 0), (480, 0)]
	body, head, notice = env(BODY), env(HEAD), env(NOTICE)
	take_hold = env([(0, 0), (52, 0), (100, 1), (480, 1)])
	let_go = env([(0, 0), (416, 0), (468, 1), (480, 1)])
	hold = take_hold * (1 - let_go)
	take = pulses(t, (196,), 16)
	step = env([(0, 0), (98, 0), (128, 1), (378, 1), (408, 0), (480, 0)])
	counter = env([(0, 0), (36, 0), (58, 1), (120, 1), (146, 0), (362, 0), (384, 1), (414, 1), (440, 0), (480, 0)])
	squeeze = env([(0, 0), (250, 0), (260, 1), (288, 1), (302, 0), (480, 0)])
	stand(rig, t, T, weight=s * (0.8 * body - 0.4 * counter), breaths=4, breath_amp=1 - 0.4 * notice,
		lid=0.22 - 0.15 * notice, blinks=(62, 205, (276, 2.4), 402), arms_out=4)
	# The near foot steps out to carry the lean, lifting on the way.
	add_loc(rig, f'FootIK_{suffix}', (s * 0.13 * step, -0.03 * step, 0.07 * 4 * clamp(step) * (1 - clamp(step))))
	# Lean out: the pelvis goes first, each joint above it a little later.
	add_loc(rig, 'Pelvis', (s * 0.085 * body, -0.02 * body, -0.012 * body))
	set_rot(rig, 'Pelvis', ((0, 1, 0), s * 5 * body))
	set_rot(rig, 'Spine', ((0, 1, 0), s * 11 * env(BODY, 4)), ((1, 0, 0), 2 * body))
	set_rot(rig, 'Chest', ((0, 1, 0), s * 10 * env(BODY, 9)), ((1, 0, 0), 3 * body))
	set_rot(rig, 'Neck', ((0, 1, 0), s * 9 * head))
	# The head comes out tilted, levels a little as it notices, and tilts again, curious.
	look = lambda u: Vector((-s * 3 * beats(u, NOTICE, T), -3 * beats(u, NOTICE, T) + 4 * (1 - beats(u, HEAD, T)),
		-s * 14 * beats(u, HEAD, T) + s * 7 * beats(u, CURIOUS, T)))
	gaze(rig, t, look, chain=(), arc=0)
	# The take: a small lift of the chin and a pull back at the first sight of you.
	set_rot(rig, 'Head', ((1, 0, 0), -3.5 * take))
	set_rot(rig, 'Neck', ((1, 0, 0), -2.0 * take))
	# The free arm hangs under gravity as the trunk rolls away from it.
	set_rot(rig, f'UpperArm_{other}', ((0, 1, 0), -s * 24 * body))
	# The near hand on the bark, a little behind the widest point, fingers forward and up.
	centre, radius = PEEK_TRUNK
	a = math.radians(28)
	on_bark = Vector((centre.x + s * radius * math.cos(a), centre.y + radius * math.sin(a), 1.32))
	out = Vector((s * math.cos(a), math.sin(a), 0))
	around = Vector((s * math.sin(a), -math.cos(a), 0))
	if hold > 0:
		# The hand travels on arcs: out, up and over to take hold; letting go, it drops and
		# slides off the bark rather than swinging out.
		lift = (math.sin(math.pi * take_hold) * Vector((s * 0.08, 0.05, 0.06))
			+ math.sin(math.pi * let_go) * Vector((s * 0.02, 0.0, -0.05)))
		palm = hanging_palm(rig, suffix).lerp(on_bark + out * 0.07, hold) + lift
		turn = hand_turn(rig, suffix, around * math.cos(math.radians(25)) + Vector((0, 0, math.sin(math.radians(25)))), -out)
		# The elbow points out and down on the bark, and back as the arm comes home.
		pole = Vector((1.3, -0.2, 0.7)).lerp(Vector((0.5, 1.2, 0.9)), 1 - hold)
		reach(rig, suffix, smooth(clamp(take_hold * 1.25)) * (1 - let_go), palm, Quaternion().slerp(turn, hold), pole=pole)
	grab = env([(0, 0), (60, 0), (84, -1), (98, -1), (108, 1, 0.2), (420, 1), (432, -0.6), (446, 0), (480, 0)])
	curl(rig, suffix, 9 * grab + 4 * squeeze)


def forage(rig, t):
	"""Something on a low plant ahead: eyes first, then he folds down, steadying himself with
	a hand on his knee, and picks at it (tug, tug, pull). He brings it up to his nose, sniffs,
	and in the middle of that notices you: a still look over his hand. Then he lets it fall
	and straightens, and glances down where it went."""
	T = 450
	crouch = beats(t, [(0, 0), (48, 0), (118, 1, 0.05), (352, 1), (410, 0), (450, 0)], T)
	grab = beats(t, [(0, 0), (70, 0), (112, -1), (122, 1.3, 0.15), (356, 1.3), (366, -0.8), (392, 0), (450, 0)], T)
	tug = pulses(t, (138, 152), 10) + beats(t, [(0, 0), (164, 0), (176, 1, 0.2), (196, 1), (230, 0), (450, 0)], T)
	engage = beats(t, [(0, 0), (60, 0), (112, 1), (350, 1), (392, 0), (450, 0)], T)
	up = beats(t, [(0, 0), (188, 0), (236, 1, 0.04), (420, 1), (440, 0), (450, 0)], T)
	knee = beats(t, [(0, 0), (70, 0), (112, 1), (360, 1), (402, 0), (450, 0)], T)
	sniff = pulses(t, (248, 259, 270), 9)
	caught = beats(t, [(0, 0), (286, 0), (298, 1, 0.12), (348, 1), (372, 0), (450, 0)], T)
	stand(rig, t, T, weight=beats(t, [(0, 0.3), (40, 0.3), (110, 0.1), (400, 0.1), (450, 0.3)], T), breaths=4,
		breath_amp=1 - 0.5 * caught, lid=0.22 - 0.1 * caught, blinks=(44, 214, (318, 2.2), 420),
		curl_r=12 + 16 * grab, curl_l=12)
	# Fold down: hips back and low, the back rounds forward, the neck lifts the face.
	add_loc(rig, 'Pelvis', (0, 0.12 * crouch, -0.3 * crouch))
	set_rot(rig, 'Pelvis', ((1, 0, 0), 14 * crouch))
	set_rot(rig, 'Spine', ((1, 0, 0), 12 * beats(t - 5, [(0, 0), (48, 0), (118, 1), (352, 1), (410, 0), (450, 0)], T)))
	set_rot(rig, 'Chest', ((1, 0, 0), 8 * beats(t - 9, [(0, 0), (48, 0), (118, 1), (352, 1), (410, 0), (450, 0)], T)))
	look = lambda u: (beats(u, [(0, (10, 8, 0)), (30, (10, 8, 0)), (46, (-14, 30, -4), 0.08), (190, (-14, 30, -4)),
			(232, (-6, 14, 3)), (286, (-6, 14, 3)), (298, (4, -14, -2), 0.12), (348, (4, -14, -2)),
			(380, (-8, 22, 0)), (418, (-8, 22, 0)), (450, (10, 8, 0))], T)
		- Vector((0, 30, 0)) * beats(u, [(0, 0), (48, 0), (118, 1), (352, 1), (410, 0), (450, 0)], T))
	gaze(rig, t, look)
	set_rot(rig, 'Head', ((1, 0, 0), -2.4 * sniff))
	# The left hand steadies him on his knee.
	if knee > 0:
		kp = carried(rig, 'Shin_L', rig.data.bones['Shin_L'].head_local + Vector((0.01, -0.05, 0.11)))
		turn = hand_turn(rig, 'L', (0.1, -1, -0.35), (0, 0, -1))
		reach(rig, 'L', knee, kp + Vector((0, 0, 0.06)), Quaternion().slerp(turn, clamp(knee)), pole=(1.3, 0.6, 0.9))
	# The right hand: down to the plant, tug, then up to his nose.
	if engage > 0:
		plant = Vector((-0.2, -0.54, 0.42)) + Vector((0, 0.03, 0.04)) * tug
		eyes = (rig.data.bones['Lid_L'].head_local + rig.data.bones['Lid_R'].head_local) / 2
		# Held up in front of his nose, but carried by the chest: when his head moves (sniffs,
		# looks up at you) the hand stays put.
		held = carried(rig, 'Chest', eyes + Vector((-0.05, -0.3, -0.22)))
		held += Vector((0.02, -0.03, -0.12)) * caught  # his attention leaves it; the hand sinks
		palm = plant.lerp(held, clamp(up)) + math.sin(math.pi * clamp(up)) * Vector((-0.1, -0.08, 0.0))
		at_plant = hand_turn(rig, 'R', (0, -0.5, -1), (1, 0, 0))
		at_face = hand_turn(rig, 'R', (0.25, -0.15, 1), (0, 1, 0.2))
		turn = at_plant.slerp(at_face, clamp(up))
		# Reaching and letting go both run between the hanging hand and the path.
		palm = hanging_palm(rig, 'R').lerp(palm, engage)
		reach(rig, 'R', smooth(clamp(engage * 1.4)), palm, Quaternion().slerp(turn, clamp(engage)), pole=(1.2, 0.4, 0.5))


def peek_left(rig, t):
	peek(rig, t, 1)


def peek_right(rig, t):
	peek(rig, t, -1)


WALK_FRAMES = 100
STEP = 0.56  # metres per step; two steps per cycle
WALK_SPEED = 2 * STEP / (WALK_FRAMES / FPS)


def walk(rig, t, blinks=(30,), clock=None):
	"""Slow, heavy amble in place on soft knees; move the root forward at WALK_SPEED. The
	head stays level and facing ahead while the pelvis and chest twist under it."""
	period = WALK_FRAMES
	clock = t if clock is None else clock
	w = math.tau * t / period
	stance = 0.64
	for s, suffix, offset in ((1, 'L', 0.0), (-1, 'R', 0.5)):
		p = (t / period + offset) % 1.0
		travel = WALK_SPEED * stance * period / FPS
		if p < stance:
			q = p / stance
			y = -travel / 2 + travel * q
			lift = 0.0
			pitch = 14 * (1 - smooth(q / 0.16)) - 20 * smooth((q - 0.72) / 0.28)
		else:
			q = (p - stance) / (1 - stance)
			y = travel / 2 - travel * smooth(q)
			lift = 0.09 * math.sin(math.pi * q) ** 1.2
			pitch = -20 * (1 - smooth(q / 0.4)) + 14 * smooth((q - 0.55) / 0.45)
		# pitch > 0 lifts the toe (a heel strike), < 0 the heel (push-off).
		put(rig, f'FootIK_{suffix}', rig.data.bones[f'FootIK_{suffix}'].head_local + Vector((0.0, y, lift)))
		roll(rig, suffix, -pitch)
		# The toes stay flat through push-off and relax only once the foot is clear.
		flat = 1.0 if p < stance else 1 - smooth(q / 0.35)
		set_rot(rig, f'Toes_{suffix}', ((1, 0, 0), -max(0.0, -pitch) * flat))
	# Each step lands, compresses and rises; the weight is carried low.
	step = (2 * t / period) % 1.0
	height = beats(step, [(0, -0.045), (0.14, -0.07), (0.42, -0.035), (0.64, -0.03), (0.84, -0.038), (1, -0.045)])
	sway = math.sin(w)
	add_loc(rig, 'Pelvis', (0.028 * sway, 0.0, height))
	set_rot(rig, 'Pelvis', ((0, 0, 1), 6 * math.cos(w)), ((0, 1, 0), 3.2 * sway), ((1, 0, 0), 3))
	set_rot(rig, 'Spine', ((0, 0, 1), -4 * math.cos(w - 0.3)), ((1, 0, 0), 6 + 1.2 * math.cos(2 * w - 0.8)), ((0, 1, 0), -2.2 * sway))
	set_rot(rig, 'Chest', ((0, 0, 1), -4.5 * math.cos(w - 0.45)), ((1, 0, 0), 4), ((0, 1, 0), -1.4 * math.sin(w - 0.4)))
	# Undo the twist and bob at the neck: the eyes stay on the path.
	twist = 6 * math.cos(w) - 4 * math.cos(w - 0.3) - 4.5 * math.cos(w - 0.45)
	set_rot(rig, 'Neck', ((1, 0, 0), -5), ((0, 0, 1), -0.6 * twist), ((0, 1, 0), 1.5 * sway))
	set_rot(rig, 'Head', ((1, 0, 0), -1 - 1.2 * math.cos(2 * w - 0.8)), ((0, 0, 1), -0.4 * twist), ((0, 1, 0), 1.2 * sway))
	for s, suffix in SIDES:
		swing = math.cos(w + (0 if s < 0 else math.pi))
		set_rot(rig, f'Shoulder_{suffix}', ((0, 0, 1), -s * 2.5 * swing))
		set_rot(rig, f'UpperArm_{suffix}', ((1, 0, 0), -3 + 11 * swing), ((0, 1, 0), -s * 5))
		set_rot(rig, f'Forearm_{suffix}', ((1, 0, 0), -15 + 6 * math.cos(w + (0 if s < 0 else math.pi) - 0.9)))
		set_rot(rig, f'Hand_{suffix}', ((1, 0, 0), -6))
		curl(rig, suffix, 14)
		set_rot(rig, f'Lid_{suffix}', ((1, 0, 0), -70 * max(0.2, blink(clock, blinks))))


def walk_glance(rig, t):
	"""Three steps of the walk with the look back: head, then shoulders, turn to his left
	toward the watcher for a long moment, then back to the path."""
	T = 3 * WALK_FRAMES
	walk(rig, t % WALK_FRAMES, blinks=(64, 200), clock=t)
	look = lambda u: beats(u, [(0, (0, 0, 0)), (60, (0, 0, 0)), (112, (68, -2, 3), 0.05), (196, (68, -2, 3)),
		(246, (0, 0, 0), 0.03), (300, (0, 0, 0))], T)
	gaze(rig, t, look, chain=(('Spine', 0.14, 0.0, 14), ('Chest', 0.24, 0.05, 8), ('Neck', 0.26, 0.3, 3)))


CLIPS = {
	'Idle': (480, idle),
	'Watch': (420, watch),
	'Listen': (360, listen),
	'PeekL': (480, peek_left),
	'PeekR': (480, peek_right),
	'Forage': (450, forage),
	'Walk': (WALK_FRAMES, walk),
	'WalkGlance': (3 * WALK_FRAMES, walk_glance),
}
