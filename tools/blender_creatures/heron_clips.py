"""Clips for the grey heron, baked by heron.py.

The heron is patience and then speed. It carries the ambient Bigfoot's method
(tools/blender_bigfoot/ambient_clips.py) over to a bird:
- Key poses with travel and hold beats. Moves ease in, overshoot a touch and settle;
  big ones start with a small anticipation the other way (the coil before the strike,
  the crouch before the jump).
- The head leads and then holds still in space. A heron's head is stabilised: the body
  sways, breathes and bobs under it while the neck soaks the motion up. The neck is
  solved each frame to put the head joint where the look wants it (neck_to).
- Overlap: the head turns first, the neck follows, the body answers last. Wings fold
  in stages, arm before forearm before hand.
- Follow-through: the crest plumes, breast plumes, tail and primaries ride damped
  springs driven by the posed body (springs), simulated over three loops on looping
  clips so every loop stays seamless.
- Moving holds: breath and a slow drift never stop, even while the eye is fixed.
Angles are degrees about armature axes (Blender Z up, facing -Y). For the body and
neck, pitch + tips forward and down; for the head, pitch + points the bill down.
Side +1 is the heron's left (+X).
"""
import bpy, math
from mathutils import Vector, Quaternion, Matrix

from ambient_clips import quat, local, set_rot, add_loc, put, clamp, smooth, beats, spline, pulses, breath, drift, blink

FPS = 30
SIDES = ((1, 'L'), (-1, 'R'))
POLE_ANGLE = 90  # the ankle bends back toward its pole; found by probing (heron_review.py --probe-pole)
FLIGHT_PITCH = 26.0  # tips the leaning standing body level for flight

STAND_T = 300
STALK_T = 120
STALK_DISTANCE = 0.34  # metres forward over the two steps, along -Y (Godot +Z)
STALK_STEPS = (56, 96)  # frames each foot is set down
STRIKE_T = 105
STRIKE_CONTACT = 34  # frame the bill enters the water
STRIKE_REACH = 0.5  # metres ahead of the feet the bill goes in
FLY_T = 30
GLIDE_T = 90
LAND_T = 105
LAND_TOUCH = 36  # frame the feet meet the ground
TAKEOFF_T = 66
TAKEOFF_LEAD = 12  # frames of crouch before the heron leaves the ground

WING = ('UpperWing', 'Forewing', 'Hand', 'Tert', 'Sec1', 'Sec2', 'Sec3', 'Sec4', 'Prim1', 'Prim2', 'Prim3', 'Prim4', 'Prim5')
NECK_BONES = ('Neck1', 'Neck2', 'Neck3')
LEG_CONSTRAINTS = [(f'Tarsus_{s}', 'LegIK') for _, s in SIDES] + [(f'Toes_{s}', 'ToesIK') for _, s in SIDES]


# ---------------------------------------------------------------- rig access

def R(axis, degrees):
	return Quaternion(Vector(axis), math.radians(degrees))


def raise_(deg):
	"""Left wing tip up about the body's long axis."""
	return R((0, 1, 0), -deg)


def back(deg):
	"""Left wing tip swept back."""
	return R((0, 0, 1), deg)


def nose(deg):
	"""Leading edge down about the span."""
	return R((1, 0, 0), deg)


def blend_q(a, b, t):
	"""a to b by t along the shortest arc; t past 1 overshoots."""
	d = a.inverted() @ b
	if d.w < 0:
		d.negate()
	return a @ Quaternion(d.axis, d.angle * t) if d.angle > 1e-9 else a.copy()


def mirror_q(q):
	return Quaternion((q.w, q.x, -q.y, -q.z))


def mirror_v(v):
	return Vector((-v.x, v.y, v.z))


def fk(rig, name):
	"""Armature-space pose matrix from the basis channels alone (constraints ignored)."""
	bone = rig.data.bones[name]
	basis = rig.pose.bones[name].matrix_basis
	if bone.parent is None:
		return bone.matrix_local @ basis
	return fk(rig, bone.parent.name) @ bone.parent.matrix_local.inverted() @ bone.matrix_local @ basis


def delta(rig, name):
	"""A bone's posed rotation relative to its rest, in armature axes."""
	return fk(rig, name).to_quaternion() @ rig.data.bones[name].matrix_local.to_quaternion().inverted()


def orient(rig, name, q):
	"""Pose a bone so its rotation relative to rest, in armature axes, is q."""
	bone = rig.data.bones[name]
	rest = bone.matrix_local.to_quaternion()
	if bone.parent:
		carry = fk(rig, bone.parent.name).to_quaternion() @ bone.parent.matrix_local.to_quaternion().inverted()
	else:
		carry = Quaternion()
	rig.pose.bones[name].rotation_quaternion = rest.inverted() @ carry.inverted() @ q @ rest


def nudge(rig, name, offset):
	"""Translate a loose bone by an armature-space offset, on top of what is there."""
	bone = rig.data.bones[name]
	carry = Quaternion()
	if bone.parent:
		carry = fk(rig, bone.parent.name).to_quaternion() @ bone.parent.matrix_local.to_quaternion().inverted()
	rest = bone.matrix_local.to_quaternion()
	rig.pose.bones[name].location += (carry @ rest).inverted() @ Vector(offset)


def carried(rig, bone, point):
	"""Where a rest-space point sits once the named bone is posed (basis channels only)."""
	return fk(rig, bone) @ (rig.data.bones[bone].matrix_local.inverted() @ Vector(point))


def tail_of(rig, name):
	return fk(rig, name) @ Vector((0, rig.data.bones[name].length, 0))


def frame_q(rest_dir, rest_normal, d, n):
	y0 = Vector(rest_dir).normalized()
	n0 = Vector(rest_normal)
	n0 = (n0 - y0 * n0.dot(y0)).normalized()
	y1 = Vector(d).normalized()
	n1 = Vector(n)
	n1 = (n1 - y1 * n1.dot(y1)).normalized()
	m0 = Matrix((y0, n0, y0.cross(n0))).transposed()
	m1 = Matrix((y1, n1, y1.cross(n1))).transposed()
	return (m1 @ m0.transposed()).to_quaternion()


def reset(rig):
	for pb in rig.pose.bones:
		pb.location = (0, 0, 0)
		pb.rotation_quaternion = (1, 0, 0, 0)
		pb.scale = (1, 1, 1)
	for bone, con in LEG_CONSTRAINTS:
		rig.pose.bones[bone].constraints[con].influence = 1.0
	# The caught fish only shows in the strike.
	rig.pose.bones['Catch'].scale = (0.001, 0.001, 0.001)


def key_all(rig, frame):
	for pb in rig.pose.bones:
		pb.keyframe_insert('location', frame=frame)
		pb.keyframe_insert('rotation_quaternion', frame=frame)
		pb.keyframe_insert('scale', frame=frame)
	for bone, con in LEG_CONSTRAINTS:
		rig.pose.bones[bone].constraints[con].keyframe_insert('influence', frame=frame)


def mix(a, b, t):
	return a + (b - a) * t


# ---------------------------------------------------------------- wings

# Folded, in the standing body's frame, for the left wing: (bone direction, top-surface
# normal). The arm runs back along the flank, the forearm forward to the bend of the wing
# at the breast, and the hand back again; every feather lies back and down along the body,
# closing toward the rump so the black primaries cross over the tail.
FOLD = {
	# The arm and tertials lie over the back like a roof, top up, trailing edge inward.
	'UpperWing': ((0.1, 0.92, -0.36), (0.25, 0.1, 1)),
	'Tert': ((-0.1, 0.93, -0.33), (0.35, 0.1, 1)),
	# The forearm runs forward along the top of the flank to the bend of the wing; its
	# coverts hang down over the flank, top outward. The hand folds back under it, turned
	# over so its coverts hang down too.
	'Forewing': ((-0.08, -0.93, 0.36), (1, 0, 0.12)),
	'Hand': ((-0.06, 0.92, -0.38), (-1, 0, -0.12)),
	# The flight feathers lie back along the flank, nearly parallel, so their tips make
	# one clean edge; the primaries close in over the tail.
	'Sec1': ((-0.09, 0.93, -0.36), (1, 0, 0.15)),
	'Sec2': ((-0.095, 0.925, -0.37), (1, 0, 0.14)),
	'Sec3': ((-0.1, 0.92, -0.38), (1, 0, 0.13)),
	'Sec4': ((-0.1, 0.92, -0.39), (1, 0, 0.12)),
	'Prim1': ((-0.1, 0.93, -0.36), (1, 0, 0.15)),
	'Prim2': ((-0.105, 0.93, -0.365), (1, 0, 0.15)),
	'Prim3': ((-0.11, 0.93, -0.37), (1, 0, 0.15)),
	'Prim4': ((-0.115, 0.93, -0.375), (1, 0, 0.15)),
	'Prim5': ((-0.12, 0.93, -0.38), (1, 0, 0.15)),
}
# Folded feathers stack like shingles, the inner ones outermost; each is pushed out along
# its folded normal by this much so no two lie in one plane.
NUDGE = {'Tert': 0.024, 'Sec1': 0.02, 'Sec2': 0.017, 'Sec3': 0.014, 'Sec4': 0.011,
	'Prim1': 0.008, 'Prim2': 0.006, 'Prim3': 0.004, 'Prim4': 0.002, 'Prim5': 0.0}
_fold_cache = {}


def fold_q(rig, name):
	if name not in _fold_cache:
		bone = rig.data.bones[f'{name}_L']
		d, n = FOLD[name]
		_fold_cache[name] = frame_q(bone.tail_local - bone.head_local, (0, 0, 1), d, n)
	return _fold_cache[name]


def body_q(rig):
	return delta(rig, 'Body')


def wing(rig, suffix, fold=0.0, flap=0.0, sweep=0.0, twist=0.0, cup=0.0, bend=0.0, hand=0.0, hand_twist=0.0,
		spread=0.0, lift=0.0):
	"""Pose one wing in the body's frame. fold is 0 spread .. 1 folded, or (arm, forearm,
	hand) to fold in stages. The open shape: flap raises the wing, sweep takes it back,
	twist tips the leading edge down, cup arches the outer wing down, bend flexes the
	elbow back, hand sweeps the hand back at the wrist (the upstroke flick), hand_twist
	turns the hand leading edge down, spread fans the primaries open. lift rolls the
	whole wing up off the body (a shrug)."""
	f = fold if isinstance(fold, (tuple, list)) else (fold, fold, fold)
	qu = raise_(flap) @ nose(twist) @ back(sweep)
	qf = qu @ raise_(-cup) @ back(bend)
	qh = qf @ raise_(-1.5 * cup) @ back(hand) @ nose(hand_twist)
	shapes = {'UpperWing': (qu, f[0]), 'Tert': (qu, f[0]), 'Forewing': (qf, f[1]), 'Hand': (qh, f[2])}
	for i in range(1, 5):
		shapes[f'Sec{i}'] = (qf @ back(-spread * 0.15 * (i - 1)), f[1])
	for i in range(1, 6):
		shapes[f'Prim{i}'] = (qh @ back(-spread * (i - 1) / 4), f[2])
	qb = body_q(rig)
	sign = 1 if suffix == 'L' else -1
	shrug = raise_(lift)
	for name in WING:
		q_open, amount = shapes[name]
		amount = clamp(amount, 0.0, 1.2)
		q = shrug @ blend_q(q_open, fold_q(rig, name), amount)
		if sign < 0:
			q = mirror_q(q)
		bone = f'{name}_{suffix}'
		orient(rig, bone, qb @ q)
		if name in NUDGE and amount > 0:
			d, n = FOLD[name]
			out = Vector(n).normalized() * NUDGE[name] * clamp(amount)
			nudge(rig, bone, qb @ (out if sign > 0 else mirror_v(out)))


def wings(rig, **kw):
	for _, suffix in SIDES:
		wing(rig, suffix, **kw)


# ---------------------------------------------------------------- neck and head

def solve(A, b):
	n = len(b)
	M = [row[:] + [b[i]] for i, row in enumerate(A)]
	for c in range(n):
		p = max(range(c, n), key=lambda r: abs(M[r][c]))
		M[c], M[p] = M[p], M[c]
		if abs(M[c][c]) < 1e-15:
			continue
		for r in range(n):
			if r != c:
				k = M[r][c] / M[c][c]
				for j in range(c, n + 1):
					M[r][j] -= k * M[c][j]
	return [M[i][n] / M[i][i] if abs(M[i][i]) > 1e-15 else 0.0 for i in range(n)]


def _set_neck(rig, a):
	for k, name in enumerate(NECK_BONES):
		rig.pose.bones[name].rotation_quaternion = local(rig, name, quat(((0, 0, 1), a[2 * k + 1]), ((1, 0, 0), a[2 * k])))


def neck_to(rig, target, pref=(0, 0, 0, 0, 0, 0), freedom=(1, 1, 1, 1, 1, 1), stiff=4e-7, iterations=10):
	"""Bend the neck so the head joint (Neck3's tail) reaches target, in armature space.
	Each neck bone carries (pitch, yaw) degrees on top of its rest; the solve stays near
	pref, and a joint with more freedom gives more of the bend."""
	target = Vector(target)
	a = list(pref)
	for _ in range(iterations):
		_set_neck(rig, a)
		tip = tail_of(rig, 'Neck3')
		r = tip - target
		J = []
		for k in range(6):
			a[k] += 0.5
			_set_neck(rig, a)
			J.append((tail_of(rig, 'Neck3') - tip) / 0.5)
			a[k] -= 0.5
		A = [[sum(J[i][c] * J[j][c] for c in range(3)) + (stiff / freedom[i] if i == j else 0.0) for j in range(6)] for i in range(6)]
		b = [-sum(J[i][c] * r[c] for c in range(3)) - stiff / freedom[i] * (a[i] - pref[i]) for i in range(6)]
		step = solve(A, b)
		a = [x + max(-25.0, min(25.0, s)) for x, s in zip(a, step)]
	_set_neck(rig, a)
	return a


def head_to(rig, yaw=0.0, pitch=0.0, roll=0.0):
	"""Hold the head at an absolute angle to its rest, in armature axes, whatever the neck
	does: yaw + turns the bill to the heron's left, pitch + points it down, roll + drops the
	left eye."""
	orient(rig, 'Head', quat(((0, 1, 0), roll), ((1, 0, 0), pitch), ((0, 0, 1), yaw)))


def bill_offset(rig, yaw, pitch, roll):
	"""Armature-space vector from the head joint to the bill tip at that head angle."""
	head = rig.data.bones['Head']
	tip = rig.data.bones['Jaw'].tail_local + Vector((0, -0.01, 0.006))
	return quat(((0, 1, 0), roll), ((1, 0, 0), pitch), ((0, 0, 1), yaw)) @ (tip - head.head_local)


def look(rig, head, angles, pref=(0, 0, 0, 0, 0, 0), freedom=(1, 1, 1, 1, 1, 1)):
	"""The head joint to `head`, then the head to `angles` (yaw, pitch, roll)."""
	yaw, pitch, roll = angles
	# Yaw is carried down the neck, mostly low, so a turned head does not twist on a stalk.
	p = list(pref)
	p[1] += yaw * 0.25
	p[3] += yaw * 0.2
	p[5] += yaw * 0.15
	neck_to(rig, head, p, freedom)
	head_to(rig, yaw, pitch, roll)


def lids(rig, closed):
	"""0 open .. 1 shut: each lid swings down over the side of its eye."""
	for s, suffix in SIDES:
		set_rot(rig, f'Lid_{suffix}', ((0, 1, 0), s * 100 * closed))


# ---------------------------------------------------------------- legs

def plant(rig, suffix, offset=(0, 0, 0), lift=0.0, toes=1.0, heel=0.0):
	"""Put a foot's IK control at its standing place plus an offset, raised by lift. toes
	0..1 closes the toes together as a heron does lifting a foot from water; heel tips the
	toes up (+) or down."""
	name = f'FootIK_{suffix}'
	put(rig, name, rig.data.bones[name].head_local + Vector(offset) + Vector((0, 0, lift)))
	set_rot(rig, name, ((1, 0, 0), -heel))
	rig.pose.bones[f'Toes_{suffix}'].scale = (0.35 + 0.65 * toes, 1.0, 1.0)


def poles(rig):
	"""Keep each ankle pole behind its ankle as the body moves."""
	for s, suffix in SIDES:
		rest = rig.data.bones[f'Tibia_{suffix}'].tail_local + Vector((0, 0.6, 0.0))
		put(rig, f'AnklePole_{suffix}', carried(rig, 'Body', rest))


def leg_ik(rig, suffix, amount):
	rig.pose.bones[f'Tarsus_{suffix}'].constraints['LegIK'].influence = amount
	rig.pose.bones[f'Toes_{suffix}'].constraints['ToesIK'].influence = amount


def aim_leg(rig, suffix, tibia, tarsus, toes):
	"""Free (FK) legs by armature-space directions: trailing in flight, reaching to land."""
	for name, d in ((f'Tibia_{suffix}', tibia), (f'Tarsus_{suffix}', tarsus), (f'Toes_{suffix}', toes)):
		bone = rig.data.bones[name]
		rest = (bone.tail_local - bone.head_local).normalized()
		orient(rig, name, rest.rotation_difference(Vector(d).normalized()))


def foot_point(rig, suffix):
	return tail_of(rig, f'Tarsus_{suffix}')


# ---------------------------------------------------------------- the standing heron

STAND_HEAD = Vector((0, -0.14, 1.228))  # head joint, peering down into the water
STAND_LOOK = (0.0, 26.0, 0.0)


def stand_body(rig, t, T=STAND_T, breaths=3, amp=1.0, sway=1.0, seed=0, weight=0.0, dip=0.0, lean=0.0,
		forward=0.0):
	"""The body over planted feet, alive in every hold: breath lifts the breast, a slow
	drift sways it, weight -1..1 carries it over the right..left foot, dip sinks it on
	bending ankles, lean + tips it forward, forward moves it ahead (-Y). Returns breath."""
	b = breath(t, T, breaths) * amp
	d = drift(t, T, seed)
	add_loc(rig, 'Body', (0.014 * weight + 0.004 * d[0] * sway, -forward + 0.003 * d[1] * sway,
		-0.005 * (1 - b) - dip))
	set_rot(rig, 'Body', ((1, 0, 0), -1.4 * b + 0.9 * d[2] * sway + lean), ((0, 1, 0), 1.6 * d[0] * sway - 2.5 * weight))
	set_rot(rig, 'Tail', ((1, 0, 0), 2.5 * b + 1.5 * d[1] * sway))
	poles(rig)
	return b


def stand(rig, t, head=None, angles=None, fold=1.0, lift=0.0, blinks=(), **body):
	"""The shared standing heron: body, folded wings, planted feet, a steady head."""
	stand_body(rig, t, **body)
	for _, suffix in SIDES:
		plant(rig, suffix)
	wings(rig, fold=fold, lift=lift)
	look(rig, STAND_HEAD if head is None else head, STAND_LOOK if angles is None else angles)
	lids(rig, blink(t, blinks))


def rest_pose(rig):
	reset(rig)
	stand(rig, 0)
	bpy.context.view_layer.update()


def stand_clip(rig, t):
	"""Ten seconds by the water. The head holds still in space while the body breathes and
	sways under it. It peers ahead, travels a little to the left and cocks the head to look
	down with one eye, holds; comes back; then creeps the head forward and down, very slowly,
	and holds that, perfectly still, before easing back. Mid-way the feathers settle: a
	shrug of both wings, a shiver, a flick of the tail, and the head never moves."""
	T = STAND_T
	weight = beats(t, [(0, -0.25), (130, -0.25), (175, 0.3, 0.1), (262, 0.3), (296, -0.25), (300, -0.25)], T)
	shiver = pulses(t, (120,), 22)
	shake = math.sin(t * math.tau / 5.5) * shiver
	lift = 7 * beats(t, [(0, 0), (108, 0), (116, 1, 0.2), (132, 1), (146, 0, 0.15), (300, 0)], T)
	stand_body(rig, t, weight=weight)
	set_rot(rig, 'Body', ((0, 1, 0), 2.2 * shake))
	set_rot(rig, 'Tail', ((0, 0, 1), 9 * (pulses(t, (141,), 7) - pulses(t, (148,), 7))))
	for _, suffix in SIDES:
		plant(rig, suffix)
	wings(rig, fold=1.0, lift=lift + 1.5 * shake)
	# Where the head is (x left, y back, z up offsets from STAND_HEAD) and how it is turned.
	pos = lambda u: beats(u, [(0, (0, 0, 0)), (58, (0, 0, 0)), (78, (0.03, -0.012, -0.012), 0.08), (148, (0.03, -0.012, -0.012)),
		(172, (0, 0, 0), 0.05), (186, (0, 0, 0)), (228, (0, -0.045, -0.035)), (262, (0, -0.045, -0.035)),
		(288, (0, 0, 0), 0.03), (300, (0, 0, 0))], T)
	ang = lambda u: beats(u, [(0, (0, 0, 0)), (54, (0, 0, 0)), (70, (20, 4, 0), 0.1), (84, (20, 4, 0)), (98, (22, 8, 16), 0.15),
		(146, (22, 8, 16)), (166, (0, 0, 0), 0.06), (186, (0, 0, 0)), (228, (0, 12, 0)), (262, (0, 12, 0)),
		(290, (0, 0, 0), 0.03), (300, (0, 0, 0))], T)
	head = STAND_HEAD + pos(t - 4)  # the eyes lead; the neck follows a few frames on
	a = Vector(STAND_LOOK) + ang(t)
	look(rig, head, tuple(a))
	lids(rig, blink(t, (40, 157, (240, 2.2), 283)))


# ---------------------------------------------------------------- strike

def strike_clip(rig, t):
	"""The strike. It sees something: the head turns onto it, then the neck draws back into
	a tight S as the body leans in. A long, still hold. Then the lunge: body, neck and bill
	in one line, the bill into the water (frame STRIKE_CONTACT). It comes up with a small
	fish across the bill, tosses it, gulps it down with two jerks of the head, shakes the
	water off and settles back to peering."""
	T = STRIKE_T
	C = STRIKE_CONTACT
	env = lambda keys: beats(t, keys)
	lean = env([(0, 0), (8, 0), (20, 7, 0.1), (29, 7), (33, 46), (40, 46), (50, 8), (70, 0, 0.08), (105, 0)])
	dip = env([(0, 0), (8, 0), (20, 0.02), (29, 0.02), (33, 0.11), (42, 0.11), (54, 0.01), (70, 0), (105, 0)])
	stand_body(rig, t - T, amp=1 - 0.8 * env([(0, 0), (12, 1), (60, 1), (80, 0), (105, 0)]), lean=lean, dip=dip,
		sway=1 - env([(0, 0), (12, 1), (60, 1), (80, 0), (105, 0)]))
	for _, suffix in SIDES:
		plant(rig, suffix)
	# The wings lift off the back a touch as it lunges, and settle.
	wings(rig, fold=1.0, lift=6 * env([(0, 0), (30, 0), (34, 1), (44, 1), (60, 0, 0.2), (105, 0)]))
	fish = Vector((0, -STRIKE_REACH, 0.05))
	# Head angle: onto the target, the coil tips the bill further down, the lunge is
	# nearly vertical, then level, the toss throws it up, and back to peering.
	ang = env([(0, (0, 26, 0)), (6, (0, 26, 0)), (14, (4, 44, -6), 0.1), (29, (4, 46, -6)), (33, (0, 74, 0)), (40, (0, 74, 0)),
		(48, (0, 40, 0)), (56, (0, 8, 0)), (62, (0, -32, 0), 0.15), (66, (0, -18, 0)), (70, (0, -36, 0), 0.2), (76, (0, 0, 0)),
		(88, (0, 26, 0), 0.05), (105, (0, 26, 0))])
	# Head joint: back into the S, hold, out to the fish, up and back.
	coil = STAND_HEAD + Vector((0, 0.07, -0.045))
	strike = fish - bill_offset(rig, 0, 74, 0)
	raised = STAND_HEAD + Vector((0, -0.04, 0.02))
	pos = env([(0, STAND_HEAD), (8, STAND_HEAD), (20, coil, 0.06), (29, coil + Vector((0, 0.004, -0.004))), (33, strike),
		(40, strike + Vector((0, 0.01, 0.02))), (54, raised), (76, raised + Vector((0, 0.01, 0.02))), (92, STAND_HEAD, 0.04),
		(105, STAND_HEAD)])
	# The strike stretches the neck straight; the coil folds it hard.
	coiled = env([(0, 0), (8, 0), (20, 1), (29, 1), (33, 0), (105, 0)])
	pref = (18 * coiled, 0, -40 * coiled, 0, 30 * coiled, 0)
	look(rig, pos, tuple(ang), pref=pref, freedom=(1, 1, 1, 1, 1.4, 1))
	# A head shake to shed the water.
	shake = pulses(t, (78,), 14)
	set_rot(rig, 'Head', ((0, 0, 1), 14 * math.sin((t - 78) * math.tau / 5.0) * shake))
	# Bill: shut for the lunge, a gape to toss the fish and two gulps.
	gape = env([(0, 0), (54, 0), (58, 1), (63, 0.6), (67, 1), (72, 0), (105, 0)])
	set_rot(rig, 'Jaw', ((1, 0, 0), 12 * gape))
	# The catch: there as the bill comes up, tossed to the gape and gone down.
	caught = env([(0, 0.001), (38, 0.001), (40, 1), (66, 1), (71, 0.001), (105, 0.001)])
	rig.pose.bones['Catch'].scale = (caught, caught, caught)
	add_loc(rig, 'Catch', Vector((0, 0.09, 0.0)) * env([(0, 0), (56, 0), (68, 1), (105, 1)]))
	set_rot(rig, 'Catch', ((0, 0, 1), 25 * math.sin(t * 1.9) * env([(0, 0), (40, 1), (56, 1), (60, 0), (105, 0)])))
	# The swallow runs down the neck.
	gulp = pulses(t, (68,), 8) + pulses(t, (74,), 8)
	set_rot(rig, 'Neck3', ((1, 0, 0), -5 * gulp))
	set_rot(rig, 'Neck2', ((1, 0, 0), 4 * pulses(t, (72, 78), 8)))
	lids(rig, max(blink(t, (31, 84)), 0.0))


# ---------------------------------------------------------------- stalk

def stalk_clip(rig, t):
	"""Two slow wading steps, STALK_DISTANCE forward in all. The head goes first and glides
	ahead on its own; the left foot lifts high with its toes closed, swings through and is
	set down without a ripple, toes opening; the body follows over it; then the right. Ends
	in the standing pose moved forward, to hand straight back to Stand."""
	T = STALK_T
	D = STALK_DISTANCE
	env = lambda keys: beats(t, keys)
	half = D / 2
	forward = env([(0, 0), (22, 0), (56, 0.14), (72, 0.19), (96, 0.26), (112, D, 0.03), (120, D)])
	dip = 0.03 * env([(0, 0), (24, 1), (100, 1), (120, 0)])
	weight = env([(0, 0), (12, -0.35), (40, -0.35), (60, 0.35), (80, 0.35), (100, -0.1), (120, 0)])
	lean = env([(0, 0), (20, 4), (100, 4), (120, 0)])
	stand_body(rig, t - T, weight=weight, lean=lean, forward=forward, dip=dip, sway=0.5)
	for s, suffix in SIDES:
		up, down = (18, STALK_STEPS[0]) if s > 0 else (60, STALK_STEPS[1])
		start, end = 0.0, D
		u = clamp((t - up) / (down - up))
		# Up and back first, a high arc forward, then down slowly.
		y = mix(start, end, spline(u, [(0, 0), (0.25, -0.12), (0.7, 0.9), (1, 1)], 0, 0))
		lift = 0.19 * spline(u, [(0, 0), (0.3, 0.8), (0.55, 1), (0.85, 0.3), (1, 0)], 0, 0)
		toes = 1 - smooth(u / 0.2) * (1 - smooth((u - 0.82) / 0.18))
		plant(rig, suffix, offset=(0, -y, 0), lift=lift, toes=toes if 0 < u < 1 else 1.0, heel=-35 * math.sin(math.pi * u) ** 2)
	wings(rig, fold=1.0)
	head = STAND_HEAD + Vector((0, -env([(0, 0), (22, 0.08, 0.05), (48, 0.1), (78, half + 0.1), (96, half + 0.12),
		(118, D, 0.03), (120, D)]), -0.015 * env([(0, 0), (22, 1), (100, 1), (120, 0)])))
	look(rig, head, (0, 26 + 6 * env([(0, 0), (22, 1), (100, 1), (120, 0)]), 0))
	lids(rig, blink(t, (8, 104)))


# ---------------------------------------------------------------- flight

FLY_HEAD = Vector((0, -0.23, 0.9))  # the head drawn back onto the shoulders
FLY_PREF = (50, 0, -70, 0, -10, 0)


def trailing(rig, t, bounce=0.0, amount=1.0, reach=0.0):
	"""Free legs: hanging (amount 0) to trailing straight back past the tail (amount 1),
	then toward reaching forward and down to land (reach 1), with a lagging bounce."""
	hang = (Vector((0, 0.25, -0.97)), Vector((0, 0.4, -0.92)), Vector((0, 0.5, -0.87)))
	trail = (Vector((0, 0.9, -0.42 + 0.04 * bounce)), Vector((0, 0.99, -0.1 + 0.05 * bounce)), Vector((0, 0.99, -0.02)))
	land = (Vector((0, -0.18, -0.98)), Vector((0, -0.1, -0.99)), Vector((0, -0.95, -0.3)))
	dirs = [h.lerp(b, amount).lerp(l, reach) for h, b, l in zip(hang, trail, land)]
	for s, suffix in SIDES:
		leg_ik(rig, suffix, 0.0)
		aim_leg(rig, suffix, *dirs)
		rig.pose.bones[f'Toes_{suffix}'].scale = (0.4 + 0.6 * reach, 1, 1)


def flight_body(rig, pitch=FLIGHT_PITCH, bob=0.0, roll=0.0, rise=0.0):
	add_loc(rig, 'Body', (0, 0, bob + rise))
	set_rot(rig, 'Body', ((1, 0, 0), pitch), ((0, 1, 0), roll))


def beat(phase):
	"""Wing shape through one heavy wingbeat, phase 0..1 from the top of the stroke. The
	downstroke is deep, slow and arched; the upstroke flexes the wrist and slices up."""
	p = phase % 1.0
	sp = lambda keys: spline(p, keys, periodic=True)
	return dict(
		flap=sp([(0, 42), (0.12, 36), (0.32, 4), (0.5, -28), (0.58, -31), (0.7, -18), (0.86, 18), (1, 42)]),
		cup=sp([(0, 4), (0.28, 11), (0.52, 10), (0.72, 3), (1, 4)]),
		hand=sp([(0, 12), (0.25, 0), (0.55, 4), (0.72, 42), (0.88, 30), (1, 12)]),
		hand_twist=sp([(0, 0), (0.5, 4), (0.72, -26), (0.9, -10), (1, 0)]),
		bend=sp([(0, 6), (0.45, 0), (0.75, 20), (1, 6)]),
		spread=sp([(0, 6), (0.35, 16), (0.55, 12), (0.75, -8), (1, 6)]),
		sweep=sp([(0, -10), (0.5, 4), (0.8, 2), (1, -10)]),
		twist=-FLIGHT_PITCH + sp([(0, 2), (0.3, 8), (0.55, 4), (0.75, -6), (1, 2)]),
	)


def blend_shape(a, b, u):
	return {k: mix(a[k], b[k], u) for k in a}


def fly_pose(rig, t, blinks=()):
	p = (t % FLY_T) / FLY_T
	# The body rides up on each downstroke and sinks through the upstroke; the head holds.
	bob = spline(p, [(0, -0.012), (0.3, 0.0), (0.58, 0.024), (0.8, 0.01), (1, -0.012)], periodic=True)
	flight_body(rig, pitch=FLIGHT_PITCH + 2.0 * math.sin(math.tau * (p - 0.2)), bob=bob)
	set_rot(rig, 'Tail', ((1, 0, 0), -3 * math.sin(math.tau * (p - 0.35))))
	trailing(rig, t, bounce=math.sin(math.tau * (p - 0.45)))
	wings(rig, **beat(p))
	look(rig, FLY_HEAD + Vector((0, 0, 0.3 * bob)), (0, 4, 0), pref=FLY_PREF)
	lids(rig, blink(t, blinks))


def fly_clip(rig, t):
	"""One slow, deep wingbeat a second, neck drawn in, legs trailing."""
	fly_pose(rig, t)


GLIDE_SHAPE = dict(flap=3.0, cup=12.0, hand=6.0, hand_twist=0.0, bend=2.0, spread=9.0, sweep=-4.0, twist=-FLIGHT_PITCH + 4.0)


def glide_pose(rig, t, T=GLIDE_T):
	d = drift(t, T, 3)
	roll = 3.0 * d[0]
	flight_body(rig, pitch=FLIGHT_PITCH - 1.0 + 1.2 * d[1], roll=roll, bob=0.006 * d[2])
	set_rot(rig, 'Tail', ((0, 0, 1), 4 * d[0]), ((1, 0, 0), 2 * d[2]))
	trailing(rig, t, bounce=0.3 * d[2])
	for s, suffix in SIDES:
		shape = dict(GLIDE_SHAPE)
		# Balancing: the low wing lifts, the high one flattens, the hands trim.
		shape['flap'] += s * 2.5 * d[0] + 1.5 * d[1]
		shape['hand_twist'] += 3 * d[2] * s
		shape['spread'] += 3 * d[1]
		wing(rig, suffix, **shape)
	look(rig, FLY_HEAD + Vector((0, 0, 0.004 * d[1])), (-2.5 * d[0], 4 + 1.5 * d[2], -roll), pref=FLY_PREF)
	lids(rig, blink(t, (50,)))


def glide_clip(rig, t):
	"""Wings set and bowed, gliding in: small balancing trims, the head level and steady."""
	glide_pose(rig, t)


# ---------------------------------------------------------------- landing

def land_clip(rig, t):
	"""Gliding in, it flares: the body swings upright, the wings cup and sweep forward to
	brake with two short beats, the legs come forward and down. Touchdown at LAND_TOUCH: the
	ankles give, the body dips and pitches over, the wings stay up for balance; then it rises,
	and the wings fold in stages, arm, forearm, hand, with a last shrug to tuck them in.
	Ends in the Stand clip's first frame."""
	T = LAND_T
	TD = LAND_TOUCH
	env = lambda keys: beats(t, keys)
	air = t < TD
	flare = env([(0, 0), (4, 0), (26, 1), (TD, 1), (T, 1)])
	down = env([(0, 0), (TD, 0), (T, 1)])
	# Body: level, then swung up past standing, then down over its feet with an overshoot.
	pitch = env([(0, FLIGHT_PITCH), (4, FLIGHT_PITCH), (26, -18), (TD, -10), (44, 9), (56, -2, 0.1), (70, 0), (T, 0)])
	dip = env([(0, 0), (TD - 2, 0), (44, 0.1), (54, -0.004), (64, 0.012), (76, 0), (T, 0)])
	if air:
		flight_body(rig, pitch=pitch, bob=0.0)
		poles(rig)
	else:
		stand_body(rig, t - T, lean=pitch, dip=dip, amp=smooth((t - TD) / 40), sway=smooth((t - TD) / 60))
	# Wings: glide, then flare (raised, cupped, swept forward, nose up) with two braking
	# beats, then held up after touchdown for balance, then folded in stages.
	brake = pulses(t, (12, 22), 10)
	glide = dict(GLIDE_SHAPE)
	flared = dict(flap=26.0, cup=24.0, hand=-6.0, hand_twist=-10.0, bend=-8.0, spread=18.0, sweep=-18.0, twist=-FLIGHT_PITCH - 20.0)
	held = dict(flap=42.0, cup=10.0, hand=18.0, hand_twist=-6.0, bend=12.0, spread=8.0, sweep=4.0, twist=-12.0)
	shape = blend_shape(glide, flared, flare)
	shape['flap'] -= 44 * brake
	shape['cup'] += 6 * brake
	after = env([(0, 0), (TD - 4, 0), (TD + 6, 1, 0.1), (T, 1)])
	shape = blend_shape(shape, held, after)
	fold = (env([(0, 0), (54, 0), (70, 1, 0.06), (T, 1)]), env([(0, 0), (58, 0), (76, 1, 0.06), (T, 1)]),
		env([(0, 0), (62, 0), (84, 1, 0.05), (T, 1)]))
	tuck = 7 * pulses(t, (84,), 16)
	shape['flap'] *= 1 - env([(0, 0), (52, 0), (72, 1), (T, 1)])
	for _, suffix in SIDES:
		wing(rig, suffix, fold=fold, lift=tuck, **shape)
	# Legs: trailing, swung forward and down to reach, planted from touchdown.
	reach = env([(0, 0), (6, 0), (28, 1), (T, 1)])
	if t < TD:
		trailing(rig, t, amount=1 - reach, reach=reach)
		ik = smooth((t - (TD - 8)) / 8)
		for s, suffix in SIDES:
			fk_foot = foot_point(rig, suffix)
			rest = rig.data.bones[f'FootIK_{suffix}'].head_local
			put(rig, f'FootIK_{suffix}', fk_foot.lerp(rest, ik))
			leg_ik(rig, suffix, ik)
			rig.pose.bones[f'Toes_{suffix}'].scale = (0.4 + 0.6 * reach, 1, 1)
	else:
		for _, suffix in SIDES:
			plant(rig, suffix)
	# Head: steady on the approach, raised to watch the landing spot, then it bobs forward
	# after the body with the dip and settles to peering.
	fly_head = FLY_HEAD
	up_head = STAND_HEAD + Vector((0, 0.0, 0.05))
	head = env([(0, fly_head), (6, fly_head), (28, up_head, 0.04), (TD, up_head), (46, STAND_HEAD + Vector((0, -0.05, -0.06)), 0.1),
		(60, STAND_HEAD + Vector((0, 0.01, 0.01))), (80, STAND_HEAD, 0.05), (T, STAND_HEAD)])
	ang = env([(0, (0, 4, 0)), (6, (0, 4, 0)), (28, (0, 22, 0), 0.05), (TD, (0, 24, 0)), (48, (0, 34, 0), 0.1), (62, (0, 22, 0)),
		(84, STAND_LOOK, 0.05), (T, STAND_LOOK)])
	prefs = [mix(a, 0.0, smooth(t / 40)) for a in FLY_PREF]
	look(rig, head, tuple(ang), pref=tuple(prefs))
	lids(rig, blink(t, (TD + 2, 96)))


# ---------------------------------------------------------------- take-off

def takeoff_clip(rig, t):
	"""A crouch, the wings opening arm first; the spring (TAKEOFF_LEAD) with the first heavy
	downstroke; legs dangle and draw back, the neck folds in, the body levels; two more
	labouring beats. Ends in the Fly clip's first frame."""
	T = TAKEOFF_T
	L = TAKEOFF_LEAD
	env = lambda keys: beats(t, keys)
	crouch = env([(0, 0), (10, 1, 0.05), (L, 1), (L + 4, 0), (T, 0)])
	hop = env([(0, 0), (L, 0), (L + 10, 0.22, 0.02), (40, 0.14), (T, 0)])
	level = env([(0, 0), (L, 0), (48, 1), (T, 1)])
	pitch = mix(10 * crouch, FLIGHT_PITCH, level)
	ground = t < L + 5
	lift_off = smooth((t - L) / 5)
	if ground:
		stand_body(rig, t - T, lean=pitch, dip=0.075 * crouch - 0.03 * smooth((t - L) / 4), amp=0.5)
		# The free pose the legs let go into as the feet leave, so nothing snaps.
		trailing(rig, t, amount=0.0)
		for _, suffix in SIDES:
			plant(rig, suffix, heel=-20 * smooth((t - L + 1) / 4), toes=1 - 0.92 * lift_off)
			leg_ik(rig, suffix, 1 - lift_off)
	else:
		flight_body(rig, pitch=pitch, rise=hop)
		poles(rig)
	# Wings: opening in stages from a shrug, then beats that settle into the Fly cycle.
	fold = (env([(0, 1), (2, 1), (12, 0, 0.05), (T, 0)]), env([(0, 1), (4, 1), (14, 0, 0.05), (T, 0)]),
		env([(0, 1), (6, 1), (16, 0), (T, 0)]))
	# Beats: phase runs 0 at frame L, a slow first stroke, then catches the Fly cycle so
	# that frame T is Fly's frame 0.
	def stroke(phase, deep):
		shape = beat(phase)
		# The first strokes are deeper; the wing's pitch levels with the body.
		shape['flap'] *= 1 + 0.2 * deep
		shape['cup'] += 6 * deep
		shape['twist'] = mix(-8.0 + (shape['twist'] + FLIGHT_PITCH), shape['twist'], level)
		return shape
	if t >= L:
		phase = spline(t, [(L, 0.0), (31, 0.55), (T, 2.0)], 1.0 / 30, 1.0 / FLY_T)
		shape = stroke(phase, 1 - smooth((t - L) / 40))
	else:
		phase = 0.0
		zero = dict(flap=0.0, cup=0.0, hand=0.0, hand_twist=0.0, bend=0.0, spread=0.0, sweep=0.0, twist=0.0)
		shape = blend_shape(zero, stroke(0.0, 1.0), smooth(t / L))
	for _, suffix in SIDES:
		wing(rig, suffix, fold=fold, lift=5 * crouch, **shape)
	# Legs: planted, pushing off, dangling, then trailing.
	if not ground:
		trail = env([(0, 0), (L + 5, 0), (44, 1), (T, 1)])
		trailing(rig, t, amount=trail, bounce=math.sin(math.tau * (phase - 0.45)) * trail)
	set_rot(rig, 'Tail', ((1, 0, 0), -10 * crouch))
	# Head: dips with the crouch and looks up and out, then draws back for flight.
	head = env([(0, STAND_HEAD), (10, STAND_HEAD + Vector((0, 0.03, -0.05)), 0.05), (L, STAND_HEAD + Vector((0, 0.03, -0.05))),
		(L + 10, STAND_HEAD + Vector((0, -0.02, 0.04))), (48, FLY_HEAD, 0.04), (T, FLY_HEAD)])
	ang = env([(0, STAND_LOOK), (8, (0, 6, 0), 0.08), (L + 10, (0, 0, 0)), (48, (0, 4, 0)), (T, (0, 4, 0))])
	prefs = [mix(0.0, a, level) for a in FLY_PREF]
	look(rig, head, tuple(ang), pref=tuple(prefs))
	lids(rig, blink(t, (4,)))


CLIPS = {
	'Stand': (STAND_T, stand_clip, True),
	'Strike': (STRIKE_T, strike_clip, False),
	'Stalk': (STALK_T, stalk_clip, False),
	'Fly': (FLY_T, fly_clip, True),
	'Glide': (GLIDE_T, glide_clip, True),
	'Land': (LAND_T, land_clip, False),
	'TakeOff': (TAKEOFF_T, takeoff_clip, False),
}


# ---------------------------------------------------------------- follow-through

# (bone, spring hz, damping ratio, most degrees it may swing off its pose)
SPRINGS = [('Crest1', 2.0, 0.3, 30), ('Crest2', 2.6, 0.3, 35), ('Plumes', 1.7, 0.35, 25), ('Tail', 2.6, 0.45, 12)] + [
	(f'Prim{i}_{s}', 3.2 + 0.2 * i, 0.4, 16) for i in range(1, 6) for s in 'LR']


def snapshot(rig):
	bones = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in rig.pose.bones}
	cons = {k: rig.pose.bones[k[0]].constraints[k[1]].influence for k in LEG_CONSTRAINTS}
	return bones, cons


def restore(rig, snap):
	bones, cons = snap
	for name, (loc, rot, scale) in bones.items():
		pb = rig.pose.bones[name]
		pb.location, pb.rotation_quaternion, pb.scale = loc, rot, scale
	for (bone, con), value in cons.items():
		rig.pose.bones[bone].constraints[con].influence = value


def follow_through(rig, snaps, loop):
	"""Each spring bone's tip is a damped particle chasing where the pose puts it; the bone
	turns toward the particle. Parents come first, so a crest's tip rides its base's swing.
	Looping clips run three times so the last pass is periodic."""
	frames = len(snaps)
	dt = 1 / FPS
	state = {}
	out = [dict() for _ in range(frames)]
	loops = 3 if loop else 1
	for n in range(loops):
		for f in range(frames):
			restore(rig, snaps[f])
			for name, hz, zeta, limit in SPRINGS:
				M = fk(rig, name)
				length = rig.data.bones[name].length
				h = M.translation
				target = M @ Vector((0, length, 0))
				if name not in state:
					state[name] = (target.copy(), Vector())
				p, v = state[name]
				w = math.tau * hz
				for _ in range(4):
					a = (target - p) * w * w - v * (2 * zeta * w)
					v = v + a * (dt / 4)
					p = p + v * (dt / 4)
				radial = (p - h).normalized() if (p - h).length > 1e-9 else (target - h).normalized()
				p = h + radial * length
				v = v - radial * v.dot(radial)
				state[name] = (p, v)
				q = (target - h).rotation_difference(p - h)
				if q.angle > math.radians(limit):
					q = Quaternion(q.axis, math.radians(limit))
				orient(rig, name, q @ delta(rig, name))
				if n == loops - 1:
					out[f][name] = rig.pose.bones[name].rotation_quaternion.copy()
	return out


def bake_clip(rig, name, frames, pose, loop):
	# Pose every frame with no action assigned (the Bigfoot's lesson: a mid-pose depsgraph
	# update would re-apply the action's keys), then key.
	rig.animation_data_create()
	rig.animation_data.action = None
	snaps = []
	for f in range(frames + (0 if loop else 1)):
		reset(rig)
		pose(rig, f)
		snaps.append(snapshot(rig))
	offsets = follow_through(rig, snaps, loop)
	for f, springs in enumerate(offsets):
		restore(rig, snaps[f])
		for bone, rot in springs.items():
			rig.pose.bones[bone].rotation_quaternion = rot
		snaps[f] = snapshot(rig)
	action = bpy.data.actions.new(name)
	action.use_fake_user = True
	rig.animation_data.action = action
	for f in range(frames + 1):
		restore(rig, snaps[f % len(snaps)] if loop else snaps[min(f, len(snaps) - 1)])
		key_all(rig, f)
	action.frame_range = (0, frames)
	action.use_frame_range = True
	track = rig.animation_data.nla_tracks.new()
	track.name = name
	track.strips.new(name, 0, action)
	track.mute = True
	rig.animation_data.action = None
	print('HERON_CLIP', name, frames, 'loop' if loop else 'once')
	return action
