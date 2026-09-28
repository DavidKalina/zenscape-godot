"""Clips for the God Hand, baked by god_hand.py.

The hand is a gentle, unhurried god. It hovers, reaches and lets go; it never grabs or
claws. The motion keeps the rules of the ambient Bigfoot and the heron:
- Key poses with travel and hold beats, easing in, overshooting a touch and settling. Big
  moves start with a small anticipation the other way: the fingers open before a pinch,
  the hand lifts before it presses, it rolls away before it turns over.
- Overlap and follow-through: the hand leads and the fingers trail. Every finger rides a
  damped spring driven by the acceleration of its own knuckle, so a lift leaves the
  fingers hanging a beat and a stop lets them swing through and settle. While fingers
  touch something (a pinch, the clay) their springs are pinned.
- Moving holds: a slow breath and drift never stop, even mid-pinch.

Every clip is placed against the anchor, the armature origin: the point on the ground
under the pointer. The game puts the anchor there and turns it so the reach (-Y) leads
left and away on screen, with the thumb side (+X) toward the camera. The pinch closes on
the anchor, the palm presses onto it, the orb is carried above it and pollen falls from
above it. The game may lift the anchor with the land (a rising pinch).

Each gesture is In (one shot), Hold (a loop) and Out (one shot). In clips start on Idle's
first pose, Hold loops start on the pose their In ends on, and Out clips start on the
Hold's first pose and end on Idle's first. The game crossfades anything else.

A clip is a function of the frame giving (placement, shape, pin):
- placement: (x, y, z, pitch, roll, yaw), where the handle H (mid-palm) goes and the
  hand's attitude, in degrees. pitch + tips the fingers down, roll + drops the thumb side
  (-180 is palm up), yaw + turns the reach to the left (+X).
- shape: the fingers, {finger: [curl1, curl2, curl3, spread], 'Thumb': [curl1, curl2,
  curl3, swing, turn], 'cup': palm arch}; curls + into the palm, spread + toward the thumb.
- pin: 0..1, how firmly the fingers are held by what they touch.
"""
import math
from mathutils import Vector, Matrix

from ambient_clips import clamp, settle, drift, pulses
from heron_clips import R, tail_of

FPS = 30
FINGER_NAMES = ('Index', 'Middle', 'Ring', 'Pinky')
DIGITS = FINGER_NAMES + ('Thumb',)

# Rest-space landmarks (palm down, fingers along -Y, thumb on +X; 1.0 = wrist to middle tip).
H = Vector((0.0, -0.30, 0.0))  # the handle every placement is given for
PINCH_POINT = Vector((0.12, -0.60, -0.17))  # where the thumb and index tips meet
PALM_POINT = Vector((0.0, -0.30, -0.09))  # the middle of the palm's inside surface
ORB_R = 0.2
ORB_CENTRE = PALM_POINT + Vector((0.0, -0.02, -ORB_R - 0.02))  # an orb resting in the cupped palm
BUNCH_POINT = Vector((0.09, -0.57, -0.18))  # where thumb, index and middle tips gather


# ---------------------------------------------------------------- shapes

def shape(index, middle, ring, pinky, thumb, cup=0.0):
	return {'Index': list(index), 'Middle': list(middle), 'Ring': list(ring), 'Pinky': list(pinky),
		'Thumb': list(thumb), 'cup': cup}


def copy(s):
	return {k: (list(v) if isinstance(v, list) else v) for k, v in s.items()}


def lerp(a, b, u):
	if isinstance(a, dict):
		return {k: lerp(a[k], b[k], u) for k in a}
	if isinstance(a, (tuple, list)):
		return type(a)(lerp(x, y, u) for x, y in zip(a, b))
	return a + (b - a) * u


def add(s, offsets):
	"""A shape with per-digit (curl, spread) offsets spread down each digit's joints."""
	out = copy(s)
	for name, (c, sp) in offsets.items():
		split = (0.2, 0.4, 0.4) if name == 'Thumb' else (0.45, 0.35, 0.2)
		for i, k in enumerate(split):
			out[name][i] += c * k
		out[name][3] += sp
	return out


# Hovering: a cascading curl, index leading, the fingers fanned a touch.
RELAX = shape((8, 10, 5, 4), (14, 18, 9, 0), (20, 24, 12, -3), (26, 28, 15, -7), (4, 8, 10, -4, 0), 2)
# Opened in anticipation: fingers long and fanned, the thumb swung wide.
OPEN = shape((-4, 2, 2, 8), (0, 4, 2, 1), (2, 5, 3, -5), (4, 6, 4, -12), (-8, 0, 2, -18, -5), 0)
# Flat for pressing, and splayed where the press lands.
FLAT = shape((-6, -3, -2, 6), (-6, -3, -2, 1), (-5, -3, -2, -4), (-4, -2, -2, -10), (-5, 0, 0, -22, 0), -4)
SPLAY = shape((-10, -6, -4, 10), (-10, -6, -4, 2), (-9, -6, -4, -7), (-8, -5, -4, -15), (-8, -2, 0, -28, -4), -6)
PRESSED = lerp(FLAT, SPLAY, 0.4)
# Kneading: the fingers work the clay in pairs.
KNEAD_A = shape((10, 12, 6, 5), (9, 11, 6, 1), (-6, -3, -2, -4), (-5, -3, -2, -10), (4, 4, 3, -14, 0), 0)
KNEAD_B = shape((-6, -3, -2, 6), (-5, -3, -2, 1), (10, 12, 6, -3), (11, 13, 7, -8), (-6, 0, 0, -24, 0), 2)
# Cupped round the orb, fingers closed together, thumb along the rim; and opened to let it go.
CUP = shape((22, 26, 12, -3), (24, 28, 12, 0), (26, 30, 14, 3), (30, 32, 16, 6), (12, 14, 10, -8, 10), 8)
CUP_OPEN = shape((-6, 0, 0, 8), (-5, 0, 0, 1), (-4, 0, 0, -5), (-3, 0, 0, -12), (-6, 0, 0, -20, 0), 0)
# Letting the pollen go: every finger fanned wide and long.
BLOOM = shape((-12, -6, -4, 12), (-12, -6, -4, 3), (-11, -6, -4, -8), (-10, -5, -4, -18), (-10, -4, 0, -30, -10), -3)
# Solved against the rig by prepare(): the pinch and the pinch of salt.
PINCH = SQUEEZE = BUNCH = RUB_A = RUB_B = None


def flex(deg):
	return R((1, 0, 0), -deg)


def apply_shape(rig, s):
	pb = rig.pose.bones
	for name in FINGER_NAMES:
		c1, c2, c3, spread = s[name]
		pb[f'{name}1'].rotation_quaternion = R((0, 0, 1), spread) @ flex(c1)
		pb[f'{name}2'].rotation_quaternion = flex(c2)
		pb[f'{name}3'].rotation_quaternion = flex(c3)
	c1, c2, c3, swing, turn = s['Thumb']
	pb['Thumb1'].rotation_quaternion = R((0, 1, 0), turn) @ R((0, 0, 1), swing) @ flex(c1)
	pb['Thumb2'].rotation_quaternion = flex(c2)
	pb['Thumb3'].rotation_quaternion = flex(c3)
	# The palm arches: the little-finger side most, the index side a little the other way.
	cup = s['cup']
	pb['MetaPinky'].rotation_quaternion = R((0, 1, 0), cup)
	pb['MetaRing'].rotation_quaternion = R((0, 1, 0), 0.55 * cup)
	pb['MetaMiddle'].rotation_quaternion = R((0, 1, 0), 0.1 * cup)
	pb['MetaIndex'].rotation_quaternion = R((0, 1, 0), -0.3 * cup)


def reset(rig):
	for pb in rig.pose.bones:
		pb.location = (0, 0, 0)
		pb.rotation_quaternion = (1, 0, 0, 0)
		pb.scale = (1, 1, 1)


def solve_shape(rig, base, free, goals, iters=60):
	"""Damped least squares on a shape: free is [(digit, slot, lo, hi)], goals are
	[(bone, rest-space point)] for bone tails, with the hand at rest. Stays near base."""
	s = copy(base)
	theta = [s[k][i] for k, i, *_ in free]
	start = list(theta)

	def residual(th):
		for (k, i, *_), v in zip(free, th):
			s[k][i] = v
		reset(rig)
		apply_shape(rig, s)
		r = []
		for bone, target in goals:
			r.extend(tail_of(rig, bone) - Vector(target))
		return r

	n, h, reg, damp = len(theta), 0.5, 2e-8, 1e-7
	for _ in range(iters):
		r = residual(theta)
		J = []
		for j in range(n):
			th = list(theta)
			th[j] += h
			J.append([(a - b) / h for a, b in zip(residual(th), r)])
		A = [[sum(J[i][k] * J[j][k] for k in range(len(r))) + (reg + damp if i == j else 0.0) for j in range(n)] for i in range(n)]
		g = [-sum(J[i][k] * r[k] for k in range(len(r))) - reg * (theta[i] - start[i]) for i in range(n)]
		step = gauss(A, g)
		theta = [clamp(t + d, f[2], f[3]) for f, t, d in zip(free, theta, step)]
	r = residual(theta)
	reset(rig)
	return s, math.sqrt(sum(x * x for x in r) / len(goals))


def gauss(A, b):
	n = len(b)
	M = [row[:] + [b[i]] for i, row in enumerate(A)]
	for c in range(n):
		p = max(range(c, n), key=lambda i: abs(M[i][c]))
		M[c], M[p] = M[p], M[c]
		for i in range(c + 1, n):
			f = M[i][c] / M[c][c]
			for k in range(c, n + 1):
				M[i][k] -= f * M[c][k]
	x = [0.0] * n
	for i in reversed(range(n)):
		x[i] = (M[i][n] - sum(M[i][k] * x[k] for k in range(i + 1, n))) / M[i][i]
	return x


def free_finger(name):
	return [(name, 0, -10, 95), (name, 1, 0, 105), (name, 2, 0, 80), (name, 3, -15, 15)]


FREE_THUMB = [('Thumb', 0, -30, 60), ('Thumb', 1, -5, 70), ('Thumb', 2, -10, 80), ('Thumb', 3, -45, 45), ('Thumb', 4, -50, 50)]


def prepare(rig):
	"""Solve the shapes whose fingertips must meet."""
	global PINCH, SQUEEZE, BUNCH, RUB_A, RUB_B
	# The middle tucks in past the index; ring and little finger fan out behind, clear of the ground.
	guess = shape((40, 60, 25, 0), (60, 68, 30, -3), (52, 60, 28, -8), (40, 46, 22, -15), (15, 15, 15, 15, 0), 3)
	PINCH, err = solve_shape(rig, guess, free_finger('Index') + FREE_THUMB,
		[('Index3', PINCH_POINT), ('Thumb3', PINCH_POINT + Vector((0.02, 0.035, -0.045)))])
	print('HAND_SOLVE pinch', round(err, 4))
	SQUEEZE = add(PINCH, {'Middle': (6, 0), 'Ring': (6, 0), 'Pinky': (6, 0), 'Index': (3, 0), 'Thumb': (4, 0)})
	guess = shape((40, 55, 25, -2), (40, 55, 25, -2), (45, 55, 25, 2), (50, 60, 28, -2), (15, 15, 15, 15, 0), 5)
	BUNCH, err = solve_shape(rig, guess, free_finger('Index') + free_finger('Middle') + FREE_THUMB,
		[('Index3', BUNCH_POINT + Vector((0.035, 0, 0))), ('Middle3', BUNCH_POINT + Vector((-0.035, -0.01, 0))),
		('Thumb3', BUNCH_POINT + Vector((0.0, 0.045, -0.035)))])
	print('HAND_SOLVE bunch', round(err, 4))
	RUB_A, err = solve_shape(rig, BUNCH, FREE_THUMB, [('Thumb3', BUNCH_POINT + Vector((0.035, 0.035, -0.04)))])
	print('HAND_SOLVE rub_a', round(err, 4))
	RUB_B, err = solve_shape(rig, BUNCH, FREE_THUMB, [('Thumb3', BUNCH_POINT + Vector((-0.03, 0.03, -0.04)))])
	print('HAND_SOLVE rub_b', round(err, 4))


# ---------------------------------------------------------------- placement

def attitude(pitch, roll, yaw):
	return R((0, 0, 1), yaw) @ R((1, 0, 0), pitch) @ R((0, 1, 0), roll)


def contact(point, at, pitch, roll, yaw=0.0):
	"""The placement that puts a rest-space point at `at` with this attitude."""
	h = Vector(at) - attitude(pitch, roll, yaw) @ (Vector(point) - H)
	return (h.x, h.y, h.z, pitch, roll, yaw)


def moved(p, dx=0.0, dy=0.0, dz=0.0, pitch=0.0, roll=0.0, yaw=0.0):
	return (p[0] + dx, p[1] + dy, p[2] + dz, p[3] + pitch, p[4] + roll, p[5] + yaw)


def matrix(p):
	"""Armature-space transform of the hand for a placement."""
	q = attitude(*p[3:])
	return Matrix.Translation(Vector(p[:3]) - q @ H) @ q.to_matrix().to_4x4()


def place(rig, p):
	w0 = rig.data.bones['Wrist'].matrix_local
	rig.pose.bones['Wrist'].matrix_basis = w0.inverted() @ matrix(p) @ w0


def breathing(p, t, T, cycles, amp=1.0, seed=0):
	"""A placement with its moving hold: breath rises and tips it, drift wanders it."""
	b = math.sin(math.tau * cycles * t / T)
	d = drift(t, T, seed)
	return moved(p, 0.006 * d[0] * amp, 0.006 * d[1] * amp, 0.012 * b * amp,
		pitch=(0.8 * b + 1.2 * d[2]) * amp, roll=1.5 * d[0] * amp, yaw=1.0 * d[1] * amp)


def track(t, keys, anti=0.0):
	"""Value at frame t through (frame, value[, overshoot]) keys, each segment eased with
	settle(). Values may be numbers, tuples or shapes."""
	if t <= keys[0][0]:
		return keys[0][1]
	for a, b in zip(keys, keys[1:]):
		if t <= b[0]:
			o = b[2] if len(b) > 2 else 0.0
			return lerp(a[1], b[1], settle((t - a[0]) / max(1e-6, b[0] - a[0]), o, anti))
	return keys[-1][1]


# ---------------------------------------------------------------- idle

IDLE_T = 240
HOVER = contact(PINCH_POINT, (0, 0, 0.42), 22, -12)  # the pinch point hovers over the anchor


def idle_place(t):
	return breathing(HOVER, t % IDLE_T, IDLE_T, 2)


def idle_shape(t):
	"""Relaxed, with a slow ripple once a loop (little finger to index, each lifting and
	settling in turn) and later the thumb brushing the side of the index twice."""
	t %= IDLE_T
	s = copy(RELAX)
	for i, name in enumerate(('Pinky', 'Ring', 'Middle', 'Index')):
		lift = pulses(t, [40 + 8 * i], 30)
		for j, k in enumerate((11, 8, 4)):
			s[name][j] -= k * lift
	brush = pulses(t, [150, 170], 20)
	s['Thumb'][3] += 7 * brush
	s['Thumb'][2] += 6 * brush
	b = math.sin(math.tau * 2 * t / IDLE_T)
	for name in FINGER_NAMES:
		s[name][1] += 2.0 * b
	return s


def idle(t):
	return idle_place(t), idle_shape(t), 0.0


IDLE0 = idle_place(0)


def idle0_shape():
	return idle_shape(0)


# ---------------------------------------------------------------- pinch: raising land

PINCH_CONTACT = 12  # frame the tips close on the anchor
PINCH_HOLD_T = 60
PINCHED = contact(PINCH_POINT, (0, 0, 0.03), 40, 0)  # tugging up a touch


def pinch_hold_place(t):
	t %= PINCH_HOLD_T
	return moved(breathing(PINCHED, t, PINCH_HOLD_T, 1, amp=0.35, seed=1), roll=2.5 * math.sin(math.tau * t / PINCH_HOLD_T))


def pinch_hold_shape(t):
	return lerp(PINCH, SQUEEZE, 0.35 + 0.3 * math.sin(math.pi * (t % PINCH_HOLD_T) / 30) ** 2)


def pinch_open(others):
	"""Thumb and index opened wide for the pinch, the other three held as given."""
	s = copy(OPEN)
	for name in ('Middle', 'Ring', 'Pinky'):
		s[name] = list(others[name])
	return s


def pinch_in(t):
	lift = moved(IDLE0, dz=0.06, pitch=-6)
	ready = pinch_open(lerp(RELAX, PINCH, 0.55))  # the others start tucking on the lift
	touch = contact(PINCH_POINT, (0, 0, 0), 42, 0)
	# The other three fold in on the way down, ahead of the tips, so they clear the ground.
	early = lerp(OPEN, PINCH, 0.6)
	for name in ('Middle', 'Ring', 'Pinky'):
		early[name] = list(PINCH[name])
	p = track(t, [(0, IDLE0), (6, lift), (PINCH_CONTACT, touch), (26, pinch_hold_place(0), 0.1)])
	s = track(t, [(0, idle0_shape()), (6, ready), (10, early), (PINCH_CONTACT, PINCH), (17, SQUEEZE), (26, pinch_hold_shape(0))])
	return p, s, track(t, [(0, 0.0), (PINCH_CONTACT - 2, 0.0), (PINCH_CONTACT, 1.0)])


def pinch_hold(t):
	return pinch_hold_place(t), pinch_hold_shape(t), 1.0


def pinch_out(t):
	start = pinch_hold_place(0)
	p = track(t, [(0, start), (4, moved(start, dz=-0.01, pitch=2)), (14, moved(IDLE0, dz=0.07, pitch=-4)), (34, IDLE0)])
	release = pinch_open(RELAX)
	s = track(t, [(0, pinch_hold_shape(0)), (4, SQUEEZE), (7, lerp(SQUEEZE, release, 0.25)), (15, release, 0.12), (34, idle0_shape())])
	return p, s, track(t, [(0, 1.0), (4, 1.0), (8, 0.0)])


# ---------------------------------------------------------------- press: smushing land like clay

PRESS_CONTACT = 13
PRESS_HOLD_T = 72
PRESSING = contact(PALM_POINT, (0, 0, -0.008), 0, 0)


def press_hold_place(t):
	"""Kneading: the palm rocks round a slow circle, fingers pushing then the heel, the
	little-finger side then the thumb's, twice a loop."""
	t %= PRESS_HOLD_T
	u = math.tau * t / 36
	p = moved(PRESSING, 0.012 * math.cos(u), 0.012 * math.sin(u), 0, pitch=3.0 * math.sin(u), roll=2.5 * math.cos(u))
	return breathing(p, t, PRESS_HOLD_T, 1, amp=0.3, seed=2)


def press_hold_shape(t):
	k = 0.5 - 0.5 * math.cos(math.tau * (t % PRESS_HOLD_T) / 36)
	return lerp(PRESSED, lerp(KNEAD_A, KNEAD_B, k), 0.55)


def press_in(t):
	rise = contact(PALM_POINT, (0, 0.04, 0.32), -4, 0)  # lifted, flattened, loading
	touch = contact(PALM_POINT, (0, 0, -0.014), 3, 0)  # a hair into the clay
	p = track(t, [(0, IDLE0), (8, rise), (PRESS_CONTACT, touch), (27, press_hold_place(0))])
	s = track(t, [(0, idle0_shape()), (8, FLAT), (PRESS_CONTACT, SPLAY), (27, press_hold_shape(0))])
	return p, s, track(t, [(0, 0.0), (PRESS_CONTACT - 2, 0.0), (PRESS_CONTACT, 1.0)])


def press_hold(t):
	return press_hold_place(t), press_hold_shape(t), 1.0


def press_out(t):
	start = press_hold_place(0)
	peel = contact(PALM_POINT, (0, -0.02, 0.05), 16, 0)  # the heel lifts first, the fingertips last
	p = track(t, [(0, start), (7, peel), (17, moved(IDLE0, dz=0.06, pitch=-3)), (34, IDLE0)])
	s = track(t, [(0, press_hold_shape(0)), (7, FLAT), (17, OPEN), (34, idle0_shape())])
	return p, s, track(t, [(0, 1.0), (4, 1.0), (8, 0.0)])


# ---------------------------------------------------------------- cup: carrying the water orb

CUP_FORMED = 21
CUP_HOLD_T = 60
CUP_TOSS = 9  # frame of the release hop that lets the orb go
CARRY = contact(ORB_CENTRE, (0, 0, 0.95), -8, -178)  # palm up, the orb held high over the anchor


def cup_hold_place(t):
	t %= CUP_HOLD_T
	u = math.tau * t / CUP_HOLD_T
	return moved(breathing(CARRY, t, CUP_HOLD_T, 1, amp=0.6, seed=3), roll=3.0 * math.sin(u), pitch=2.0 * math.cos(u))


def cup_hold_shape(t):
	t %= CUP_HOLD_T
	s = add(CUP, {name: (3.0 * math.sin(math.tau * t / CUP_HOLD_T + 0.4 * i), 0) for i, name in enumerate(FINGER_NAMES)})
	regrip = pulses(t, [26], 18)
	s['Thumb'][3] -= 6 * regrip
	s['Thumb'][1] += 5 * regrip
	return s


def cup_in(t):
	dip = moved(IDLE0, dz=-0.04, pitch=4, roll=12)  # rolls the other way before turning over
	turning = contact(ORB_CENTRE, (0, 0.02, 0.7), 6, -95)  # thumb up, halfway over, rising
	end = cup_hold_place(0)
	p = track(t, [(0, IDLE0), (6, dip), (14, turning), (CUP_FORMED, moved(end, dz=0.03)), (32, end)])
	s = track(t, [(0, idle0_shape()), (6, lerp(idle0_shape(), OPEN, 0.5)), (15, CUP_OPEN), (CUP_FORMED, CUP, 0.1),
		(32, cup_hold_shape(0))])
	return p, s, track(t, [(0, 0.0), (CUP_FORMED, 0.0), (32, 0.5)])


def cup_hold(t):
	return cup_hold_place(t), cup_hold_shape(t), 0.5


def cup_out(t):
	"""The release hop: a dip, a small toss that lifts the orb clear, and the hand draws
	back and up out of its way, turning over, so the orb falls straight down. It waits
	there, opening, until the orb has landed (the game's ball is down about 18 frames
	after the toss) and only then drifts home."""
	start = cup_hold_place(0)
	away = contact(ORB_CENTRE, (0.05, 0.9, 0.9), 8, -100)
	p = track(t, [(0, start), (5, moved(start, dz=-0.05, pitch=3)), (CUP_TOSS, moved(start, dz=0.05)),
		(22, away, 0.08), (32, moved(away, dz=0.02, roll=6)), (52, IDLE0)])
	s = track(t, [(0, cup_hold_shape(0)), (5, add(CUP, {n: (6, 0) for n in FINGER_NAMES})), (CUP_TOSS, CUP),
		(17, CUP_OPEN, 0.12), (32, lerp(CUP_OPEN, RELAX, 0.5)), (52, idle0_shape())])
	return p, s, track(t, [(0, 0.5), (CUP_TOSS, 0.5), (CUP_TOSS + 2, 0.0)])


# ---------------------------------------------------------------- sprinkle: laying pollen

SPRINKLE_HOLD_T = 48
RUB_T = 12  # one rub of the thumb across the fingertips and back
SPRINKLING = contact(BUNCH_POINT, (0, 0, 0.62), 38, -10)


def sprinkle_hold_place(t):
	t %= SPRINKLE_HOLD_T
	u = math.tau * t / RUB_T
	p = moved(SPRINKLING, dz=0.006 * math.sin(u + 1.0), roll=1.5 * math.sin(u))
	return breathing(p, t, SPRINKLE_HOLD_T, 1, amp=0.4, seed=4)


def sprinkle_hold_shape(t):
	return lerp(RUB_A, RUB_B, 0.5 - 0.5 * math.cos(math.tau * (t % SPRINKLE_HOLD_T) / RUB_T))


def sprinkle_in(t):
	p = track(t, [(0, IDLE0), (6, moved(IDLE0, dz=0.02, pitch=-4)), (18, sprinkle_hold_place(0), 0.08)])
	s = track(t, [(0, idle0_shape()), (6, lerp(idle0_shape(), OPEN, 0.6)), (14, BUNCH, 0.1), (18, sprinkle_hold_shape(0))])
	return p, s, track(t, [(0, 0.0), (14, 0.0), (18, 0.6)])


def sprinkle_hold(t):
	return sprinkle_hold_place(t), sprinkle_hold_shape(t), 0.6


def sprinkle_out(t):
	"""Letting it go: the fingertips gather once more, then the hand lifts and turns up
	with every finger fanned, floats a moment while the veil settles, and comes home."""
	start = sprinkle_hold_place(0)
	bloom = contact(BUNCH_POINT, (0, 0.05, 0.85), -10, -120)
	p = track(t, [(0, start), (5, moved(start, dz=-0.02, pitch=4)), (17, bloom, 0.1), (29, moved(bloom, dz=0.02, roll=4)),
		(48, IDLE0)])
	s = track(t, [(0, sprinkle_hold_shape(0)), (5, BUNCH), (16, BLOOM, 0.12), (29, BLOOM), (48, idle0_shape())])
	return p, s, track(t, [(0, 0.6), (5, 0.6), (8, 0.0)])


# ---------------------------------------------------------------- follow-through

# Finger springs: frequency in Hz and damping ratio; heavier fingers are a little slower.
SPRING = {'Index': (2.6, 0.32), 'Middle': (2.4, 0.3), 'Ring': (2.35, 0.3), 'Pinky': (2.7, 0.33), 'Thumb': (3.0, 0.38)}
LAG = 0.7  # degrees of curl per unit/s^2 of knuckle acceleration toward the back of the hand
SPREAD_LAG = 0.35


def follow_through(rig, frames, loop, start=None, end=None, blend=10):
	"""Per-frame {digit: (curl, spread)} offsets from springs driven by each knuckle's
	acceleration, and each frame's spring state. Loops run three times so the last pass is
	periodic. A one-shot starts from the state start gives ({digit: (x, v)}, the clip it
	follows on from) and eases its last blend frames onto the offsets end gives, so hand-offs
	meet exactly. Pins hold the springs still."""
	n = len(frames)
	dt = 1 / FPS
	mats = [matrix(p) for p, _, _ in frames]
	offsets = [dict() for _ in range(n)]
	states = [dict() for _ in range(n)]
	for name in DIGITS:
		knuckle = rig.data.bones[f'{name}1'].head_local
		hz, zeta = SPRING[name]
		w = math.tau * hz
		pos = [m @ knuckle for m in mats]
		x, v = (start[name][0].copy(), start[name][1].copy()) if start else (Vector((0, 0)), Vector((0, 0)))
		for _ in range(3 if loop else 1):
			for f in range(n):
				pin = frames[f][2]
				x *= 1 - pin
				v *= 1 - pin
				offsets[f][name] = Vector((clamp(x.x, -15, 15), clamp(x.y, -8, 8)))
				states[f][name] = (x.copy(), v.copy())
				if loop:
					a = (pos[(f + 1) % n] - 2 * pos[f] + pos[(f - 1) % n]) / dt ** 2
				else:
					a = (pos[min(f + 1, n - 1)] - 2 * pos[f] + pos[max(f - 1, 0)]) / dt ** 2
				m = mats[f].to_3x3()
				target = Vector((clamp(LAG * a.dot(m @ Vector((0, 0, 1))), -18, 18),
					clamp(-SPREAD_LAG * a.dot(m @ Vector((1, 0, 0))), -10, 10)))
				v += (w * w * (target - x) - 2 * zeta * w * v) * dt
				x += v * dt
		if end and not loop:
			for f in range(max(0, n - blend), n):
				u = settle((f - (n - 1 - blend)) / blend)
				offsets[f][name] = offsets[f][name].lerp(end[name], u)
	return offsets, states


# ---------------------------------------------------------------- clips

# name: (frames, function, loops, the clip it starts from, the clip it hands off to)
CLIPS = {
	'Idle': (IDLE_T, idle, True, None, None),
	'PinchIn': (26, pinch_in, False, 'Idle', 'PinchHold'),
	'PinchHold': (PINCH_HOLD_T, pinch_hold, True, None, None),
	'PinchOut': (34, pinch_out, False, 'PinchHold', 'Idle'),
	'PressIn': (27, press_in, False, 'Idle', 'PressHold'),
	'PressHold': (PRESS_HOLD_T, press_hold, True, None, None),
	'PressOut': (34, press_out, False, 'PressHold', 'Idle'),
	'CupIn': (32, cup_in, False, 'Idle', 'CupHold'),
	'CupHold': (CUP_HOLD_T, cup_hold, True, None, None),
	'CupOut': (52, cup_out, False, 'CupHold', 'Idle'),
	'SprinkleIn': (18, sprinkle_in, False, 'Idle', 'SprinkleHold'),
	'SprinkleHold': (SPRINKLE_HOLD_T, sprinkle_hold, True, None, None),
	'SprinkleOut': (48, sprinkle_out, False, 'SprinkleHold', 'Idle'),
}


_springs = {}


def springs(rig, name):
	"""(offsets, states) for a clip, chained through its neighbours; cached."""
	if name not in _springs:
		T, fn, loop, before, after = CLIPS[name]
		frames = [fn(f) for f in range(T if loop else T + 1)]
		start = springs(rig, before)[1][0] if before else None
		end = springs(rig, after)[0][0] if after else None
		_springs[name] = follow_through(rig, frames, loop, start, end)
	return _springs[name]


def evaluate(rig, name):
	"""[(placement, shape)] for every frame of a clip, springs included. A loop gives its
	frames once (frame T is frame 0 again); a one-shot includes its last frame."""
	T, fn, loop, _, _ = CLIPS[name]
	frames = [fn(f) for f in range(T if loop else T + 1)]
	offsets = springs(rig, name)[0]
	return [(p, add(s, {k: tuple(o) for k, o in off.items()})) for (p, s, _), off in zip(frames, offsets)]


def pose(rig, p, s):
	reset(rig)
	place(rig, p)
	apply_shape(rig, s)


def key_all(rig, frame):
	for pb in rig.pose.bones:
		pb.keyframe_insert('location', frame=frame)
		pb.keyframe_insert('rotation_quaternion', frame=frame)
		pb.keyframe_insert('scale', frame=frame)


def bake_clip(rig, name):
	import bpy
	T, _, loop, _, _ = CLIPS[name]
	frames = evaluate(rig, name)
	rig.animation_data_create()
	action = bpy.data.actions.new(name)
	action.use_fake_user = True
	rig.animation_data.action = action
	for f in range(T + 1):
		pose(rig, *frames[f % len(frames)])
		key_all(rig, f)
	action.frame_range = (0, T)
	action.use_frame_range = True
	action.use_cyclic = loop
	track = rig.animation_data.nla_tracks.new()
	track.name = name
	track.strips.new(name, 0, action)
	track.mute = True
	rig.animation_data.action = None
	return action
