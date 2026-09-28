"""Clips for the God Hand, baked by god_hand.py.

The hand is a gentle, unhurried god. It floats, reaches and lets go; it never grabs or
claws. The motion keeps the rules of the ambient Bigfoot and the heron:
- Key poses with travel and hold beats, easing in, overshooting a touch and settling. Big
  moves start with a small anticipation the other way: the fingers open before a pinch,
  the hand lifts before it presses, it rolls away before it turns over, it draws back
  before it throws.
- Overlap and follow-through: the hand leads and the fingers trail. Every finger rides a
  damped spring driven by the acceleration of its own knuckle, so a lift leaves the
  fingers hanging a beat and a stop lets them swing through and settle. While fingers
  touch something (a pinch, the clay) their springs are pinned.
- Moving holds: the float, the breath and the drift never stop, even mid-pinch.

Every clip is placed against the anchor, the armature origin: the point on the ground
under the pointer. The game puts the anchor there and turns it so the reach (-Y) leads
left and away on screen, with the thumb side (+X) toward the camera. The pinch closes on
the anchor, the palm presses onto it, the orb is carried above it and pollen is thrown
from above it. The game lifts the anchor with the land (a rising pinch, a summit).

Each gesture is In (one shot), Hold (a loop) and Out (one shot). In clips start on Idle's
first pose, Hold loops start on the pose their In ends on, and Out clips start on the
Hold's first pose and end on Idle's first. Idle's variations (IdleStretch and the rest)
start and end on Idle's first pose too, so the game can play one whenever Idle comes
round. The game crossfades anything else.

A clip is a function of the frame giving (placement, shape, pin[, marks]):
- placement: (x, y, z, pitch, roll, yaw), where the handle H (mid-palm) goes and the
  hand's attitude, in degrees. pitch + tips the fingers down, roll + drops the thumb side
  (-180 is palm up), yaw + turns the reach to the left (+X).
- shape: the fingers, {finger: [curl1, curl2, curl3, spread], 'Thumb': [curl1, curl2,
  curl3, swing, turn], 'cup': palm arch}; curls + into the palm, spread + toward the thumb,
  thumb swing - out wide.
- pin: 0..1, how firmly the fingers are held by what they touch.
- marks: what the game needs to know besides the hand, carried by non-deforming bones:
  'ball' (centre, touch, weight): where the clip takes the water orb to be, the point
  on its surface the hand touches, and how firmly the hand keeps to it (0 once it has
  popped). The game puts the Ball bone on the real ball and the BallTouch bone on its
  surface, so the hand holds and pokes a ball of any size.
  'handful' 0..1: pollen is held in the palm (the Handful bone); a drop to 0 throws it.
  The weights ride on the bones' scale.
"""
import math
from mathutils import Vector, Matrix

from ambient_clips import clamp, settle, smooth, drift, pulses, spline
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
HANDFUL_POINT = BUNCH_POINT  # a pinch of seed, held in the gathered fingertips
# Solved against the rig by prepare(): the index tip of the pointing hand.
POKE_TIP = None


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
	if isinstance(a, Vector):
		return a.lerp(b, u)
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


def diff(a, b):
	"""Shape a less shape b: an overlay to lay over another shape with plus()."""
	return {k: ([x - y for x, y in zip(a[k], b[k])] if isinstance(a[k], list) else a[k] - b[k]) for k in a}


def plus(s, d, w=1.0):
	return {k: ([x + w * y for x, y in zip(s[k], d[k])] if isinstance(s[k], list) else s[k] + w * d[k]) for k in s}


# Hovering: a cascading curl, index leading, the fingers fanned a touch.
RELAX = shape((8, 10, 5, 4), (14, 18, 9, 0), (20, 24, 12, -3), (26, 28, 15, -7), (4, 8, 10, -4, 0), 2)
ZERO = diff(RELAX, RELAX)
# Opened in anticipation: fingers long and fanned, the thumb swung wide.
OPEN = shape((-4, 2, 2, 8), (0, 4, 2, 1), (2, 5, 3, -5), (4, 6, 4, -12), (-8, 0, 2, -18, -5), 0)
# Pressing palm first: every finger long and bent back up off the ground, fanned, the
# thumb out flat; and bearing down harder, bent further back and wider.
PRESS = shape((-18, -5, -2, 7), (-18, -5, -2, 1), (-17, -5, -2, -6), (-16, -4, -2, -13), (-10, -3, 0, -30, -4), -5)
PRESS_HARD = shape((-27, -8, -3, 10), (-27, -8, -3, 2), (-26, -8, -3, -8), (-25, -7, -3, -17), (-14, -5, -1, -34, -6), -7)
# Cupped round the orb, fingers closed together, thumb along the rim; and opened to let it go.
CUP = shape((22, 26, 12, -3), (24, 28, 12, 0), (26, 30, 14, 3), (30, 32, 16, 6), (12, 14, 10, -8, 10), 8)
CUP_OPEN = shape((-6, 0, 0, 8), (-5, 0, 0, 1), (-4, 0, 0, -5), (-3, 0, 0, -12), (-6, 0, 0, -20, 0), 0)
# Letting go with every finger fanned wide and long.
BLOOM = shape((-12, -6, -4, 12), (-12, -6, -4, 3), (-11, -6, -4, -8), (-10, -5, -4, -18), (-10, -4, 0, -30, -10), -3)
# Pointing, to pop the orb: the index long, the others folded, the thumb laid over the middle.
POINT = shape((-4, -2, 0, 3), (64, 80, 40, 0), (70, 84, 42, -3), (74, 86, 44, -6), (18, 26, 20, 10, 10), 4)
# Flung open as the handful leaves: long, fanned and bent back a touch.
FLING = shape((-16, -9, -6, 13), (-16, -9, -6, 3), (-15, -9, -6, -9), (-14, -8, -6, -19), (-12, -6, -2, -32, -8), -5)
# A soft fist, a wide stretch, and a relaxed hand turned to look at.
FIST = shape((62, 78, 42, -2), (66, 82, 44, 0), (70, 84, 46, 2), (74, 86, 48, 4), (24, 32, 24, 14, 12), 8)
STRETCH = shape((-20, -11, -7, 15), (-20, -11, -7, 3), (-19, -11, -7, -11), (-18, -10, -7, -22), (-14, -8, -4, -38, -8), -7)
PEEK = shape((14, 18, 8, 7), (18, 22, 10, 1), (22, 26, 12, -5), (26, 30, 14, -11), (0, 6, 8, -14, 0), 4)
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
	"""Solve the shapes whose fingertips must meet, and find the pointing tip."""
	global PINCH, SQUEEZE, BUNCH, RUB_A, RUB_B, POKE_TIP
	# The middle tucks in past the index; ring and little finger fan out behind, clear of the ground.
	guess = shape((40, 60, 25, 0), (60, 68, 30, -3), (52, 60, 28, -8), (40, 46, 22, -15), (15, 15, 15, 15, 0), 3)
	PINCH, err = solve_shape(rig, guess, free_finger('Index') + FREE_THUMB,
		[('Index3', PINCH_POINT), ('Thumb3', PINCH_POINT + Vector((0.02, 0.035, -0.045)))])
	print('HAND_SOLVE pinch', round(err, 4))
	# Squeezing it: the three behind fold in tighter too, well up off the ground.
	SQUEEZE = add(PINCH, {'Middle': (12, 0), 'Ring': (20, 0), 'Pinky': (26, 0), 'Index': (3, 0), 'Thumb': (4, 0)})
	guess = shape((40, 55, 25, -2), (40, 55, 25, -2), (45, 55, 25, 2), (50, 60, 28, -2), (15, 15, 15, 15, 0), 5)
	BUNCH, err = solve_shape(rig, guess, free_finger('Index') + free_finger('Middle') + FREE_THUMB,
		[('Index3', BUNCH_POINT + Vector((0.035, 0, 0))), ('Middle3', BUNCH_POINT + Vector((-0.035, -0.01, 0))),
		('Thumb3', BUNCH_POINT + Vector((0.0, 0.045, -0.035)))])
	print('HAND_SOLVE bunch', round(err, 4))
	RUB_A, err = solve_shape(rig, BUNCH, FREE_THUMB, [('Thumb3', BUNCH_POINT + Vector((0.035, 0.035, -0.04)))])
	print('HAND_SOLVE rub_a', round(err, 4))
	RUB_B, err = solve_shape(rig, BUNCH, FREE_THUMB, [('Thumb3', BUNCH_POINT + Vector((-0.03, 0.03, -0.04)))])
	print('HAND_SOLVE rub_b', round(err, 4))
	reset(rig)
	apply_shape(rig, POINT)
	POKE_TIP = tail_of(rig, 'Index3').copy()
	reset(rig)
	prepare_shake(rig)


# ---------------------------------------------------------------- placement

Z6 = (0.0,) * 6


def attitude(pitch, roll, yaw):
	return R((0, 0, 1), yaw) @ R((1, 0, 0), pitch) @ R((0, 1, 0), roll)


def contact(point, at, pitch, roll, yaw=0.0):
	"""The placement that puts a rest-space point at `at` with this attitude."""
	h = Vector(at) - attitude(pitch, roll, yaw) @ (Vector(point) - H)
	return (h.x, h.y, h.z, pitch, roll, yaw)


def moved(p, dx=0.0, dy=0.0, dz=0.0, pitch=0.0, roll=0.0, yaw=0.0):
	return (p[0] + dx, p[1] + dy, p[2] + dz, p[3] + pitch, p[4] + roll, p[5] + yaw)


def over(p, o):
	"""A placement moved by an overlay (dx, dy, dz, pitch, roll, yaw)."""
	return moved(p, *o)


def add6(a, b):
	return tuple(x + y for x, y in zip(a, b))


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


def flow(t, keys, periodic=False):
	"""Value at frame t through (frame, value) keys on a curve that keeps moving through
	them, unlike track(): a throw is quickest as it lets go. Values may be numbers or
	tuples; a one-shot starts and ends at rest."""
	ends = None if periodic else 0.0
	first = keys[0][1]
	if isinstance(first, (int, float)):
		return spline(t, keys, ends, ends, periodic)
	return tuple(spline(t, [(f, v[i]) for f, v in keys], ends, ends, periodic) for i in range(len(first)))


def window(t, a, b, c, d):
	"""0 before a, easing up to 1 at b, 1 until c, easing back to 0 at d."""
	if t <= a or t >= d:
		return 0.0
	if t < b:
		return smooth((t - a) / (b - a))
	if t > c:
		return smooth((d - t) / (d - c))
	return 1.0


# ---------------------------------------------------------------- idle

IDLE_T = 180
HOVER = contact(PINCH_POINT, (0, 0, 0.42), 22, -12)  # the pinch point hovers over the anchor


def idle_place(t):
	"""Floating: a slow bob twice a loop with the fingertips trailing it (tipped down on
	the way up), a lazy sway and bank once a loop, and drift under it all."""
	t %= IDLE_T
	u = math.tau * t / IDLE_T
	d = drift(t, IDLE_T, 0)
	bob = math.sin(2 * u)
	return moved(HOVER, 0.022 * math.sin(u + 0.6) + 0.004 * d[0], 0.015 * math.sin(2 * u + 1.9) + 0.004 * d[1],
		0.05 * bob, pitch=4.5 * math.cos(2 * u) + 1.0 * d[2], roll=5.5 * math.sin(u + 1.1),
		yaw=3.5 * math.sin(u + 2.4) + 1.0 * d[1])


def idle_shape(t, ripple=True):
	"""Relaxed, curling a touch with the bob. Plain Idle adds a slow ripple once a loop
	(little finger to index, each lifting and settling in turn) and later the thumb
	brushing the side of the index twice."""
	t %= IDLE_T
	s = copy(RELAX)
	if ripple:
		for i, name in enumerate(('Pinky', 'Ring', 'Middle', 'Index')):
			lift = pulses(t, [36 + 7 * i], 28)
			for j, k in enumerate((11, 8, 4)):
				s[name][j] -= k * lift
		brush = pulses(t, [110, 128], 18)
		s['Thumb'][3] += 7 * brush
		s['Thumb'][2] += 6 * brush
	b = math.sin(math.tau * 2 * t / IDLE_T)
	for name in FINGER_NAMES:
		s[name][1] += 2.5 * b
	return s


def idle(t):
	return idle_place(t), idle_shape(t), 0.0


IDLE0 = idle_place(0)


def idle0_shape():
	return idle_shape(0)


# Idle's variations: each is Idle's float with something played over it, IDLE_T long, so
# it starts and ends where Idle does.

def idle_stretch(t):
	"""A stretch: the fingers curl in, then reach out long and wide with the wrist bent
	back, the back of the hand turned to the camera so the fan shows, hold there with a
	quiver, let go and shake out loose."""
	o = track(t, [(0, Z6), (28, Z6), (44, (0, 0, -0.02, 7, -6, 0)), (62, (0, 0.01, 0.07, -18, 46, 0), 0.12),
		(92, (0, 0.012, 0.08, -20, 50, 2)), (102, (0, 0, 0.04, -4, 18, 0)), (140, (0, 0, 0.01, 0, 2, 0)), (165, Z6)])
	shake = window(t, 102, 106, 122, 138) * math.sin(math.tau * (t - 102) / 7)
	quiver = window(t, 64, 70, 88, 94) * math.sin(math.tau * t / 5)
	o = add6(o, (0, 0, 0.005 * shake, 1.5 * shake, 8 * shake + 0.6 * quiver, 2 * shake))
	d = track(t, [(0, ZERO), (28, ZERO), (44, diff(lerp(RELAX, FIST, 0.4), RELAX)), (62, diff(STRETCH, RELAX), 0.1),
		(92, diff(STRETCH, RELAX)), (102, diff(lerp(STRETCH, RELAX, 0.7), RELAX)), (140, ZERO)])
	return over(idle_place(t), o), plus(idle_shape(t, False), d), 0.0


def idle_peek(t):
	"""A look at itself: it rolls away a touch, then turns its palm up to the camera,
	tilts one way and the other as if curious, wiggles its fingers and turns back."""
	o = track(t, [(0, Z6), (24, Z6), (36, (0, 0, -0.012, 4, 9, 0)), (60, (0, 0.02, 0.05, -14, -108, 4), 0.1),
		(80, (0, 0.02, 0.055, -10, -104, 16)), (100, (0, 0.02, 0.05, -16, -110, -8)), (114, (0, 0.02, 0.05, -12, -106, 0)),
		(136, (0, 0, 0.01, 3, 7, 0), 0.08), (160, Z6)])
	s = plus(idle_shape(t, False), track(t, [(0, ZERO), (40, ZERO), (60, diff(PEEK, RELAX)), (114, diff(PEEK, RELAX)), (136, ZERO)]))
	w = window(t, 68, 76, 102, 112)
	for i, name in enumerate(FINGER_NAMES):
		c = 16 * w * math.sin(math.tau * (t - 68) / 12 - 1.3 * i)
		for j, k in enumerate((0.5, 0.35, 0.2)):
			s[name][j] += c * k
	return over(idle_place(t), o), s, 0.0


def idle_ripple(t):
	"""A cascade: the hand lifts and the fingers roll through a wave, little finger to
	thumb, twice, the wrist nodding as each wave passes."""
	o = track(t, [(0, Z6), (28, Z6), (42, (0, 0, 0.035, -8, -8, 0), 0.08), (112, (0, 0, 0.03, -5, -8, 0)), (142, Z6)])
	o = add6(o, (0, 0, 0, 6 * pulses(t, [52, 86], 22), 0, 0))
	s = idle_shape(t, False)
	for k, name in enumerate(('Pinky', 'Ring', 'Middle', 'Index', 'Thumb')):
		c = pulses(t, [46 + 4 * k, 80 + 4 * k], 18)
		if name == 'Thumb':
			for j, deg in enumerate((8, 18, 16, 10)):
				s[name][j] += deg * c
		else:
			for j, deg in enumerate((40, 46, 26)):
				s[name][j] += deg * c
	return over(idle_place(t), o), s, 0.0


def idle_gather(t):
	"""Gathering: the fingers close one by one into a soft fist as the hand draws in,
	it holds with a tremble, then blooms open with a little pop upward, turning its palm
	up to the camera like a flower, and floats down."""
	o = track(t, [(0, Z6), (20, Z6), (66, (0, 0.01, -0.03, 9, 6, 0)), (88, (0, 0.012, -0.04, 10, 8, 0)),
		(97, (0, 0, 0.075, -14, -66, 0), 0.12), (122, (0, 0, 0.06, -10, -60, 0)), (150, (0, 0, 0.01, -2, -6, 0)), (166, Z6)])
	tremble = window(t, 68, 74, 84, 89) * math.sin(math.tau * t / 5)
	o = add6(o, (0, 0, 0.002 * tremble, 0, 0.8 * tremble, 0))
	s = idle_shape(t, False)
	bloom = track(t, [(0, 0.0), (89, 0.0), (97, 1.0, 0.15), (122, 1.0), (158, 0.0)])
	squeeze = pulses(t, [72, 80], 8)
	for k, name in enumerate(('Pinky', 'Ring', 'Middle', 'Index', 'Thumb')):
		close = track(t, [(0, 0.0), (22 + 7 * k, 0.0), (44 + 7 * k, 1.0), (89, 1.0), (94, 0.0)])
		s[name] = lerp(lerp(s[name], FIST[name], close), BLOOM[name], bloom)
		for j in range(3):
			s[name][j] += 5 * squeeze * close
	s['cup'] = lerp(lerp(s['cup'], FIST['cup'], track(t, [(0, 0.0), (22, 0.0), (72, 1.0), (89, 1.0), (94, 0.0)])), BLOOM['cup'], bloom)
	return over(idle_place(t), o), s, 0.0


def _wander(f):
	q = smooth(clamp((f - 14) / 150))
	a = math.tau * q
	return Vector((0.2 * math.sin(a), 0.1 * math.sin(2 * a), 0.03 * (1 - math.cos(a))))


def idle_drift(t):
	"""A lazy wander: the hand glides out and round a figure of eight and home, banking
	into each turn and looking a little where it goes."""
	w = _wander(t)
	v = (_wander(t + 1) - _wander(t - 1)) * (FPS / 2)
	a = (_wander(t + 1) - 2 * w + _wander(t - 1)) * FPS * FPS
	o = (w.x, w.y, w.z, -9 * a.y, 14 * a.x, 16 * v.x)
	return over(idle_place(t), o), idle_shape(t, False), 0.0


IDLE_VARIANTS = ('IdleStretch', 'IdlePeek', 'IdleRipple', 'IdleGather', 'IdleDrift')


# ---------------------------------------------------------------- pinch: pulling land up

PINCH_CONTACT = 14  # frame the tips close on the anchor
PINCH_HOLD_T = 72
PULL_PITCH = 64  # steep, from above, so the palm and knuckles stay clear of the ground


def tug(t):
	"""0..1 effort of a tug, two a hold loop: it gathers, draws up with a little
	overshoot, holds with a quiver and eases off."""
	return track(t % 36, [(0, 0.0), (4, 0.0), (14, 1.0, 0.1), (21, 0.92), (34, 0.0), (36, 0.0)])


def pinch_hold_place(t):
	"""Pulling the land up by a pinch: each tug squeezes, draws the pinch up a touch and
	leans the hand back round it, the little-finger side rising, quivering with the
	effort, then eases. The attitude turns about the pinch point, so the tips keep their
	hold."""
	t %= PINCH_HOLD_T
	k = tug(t)
	u = math.tau * t / PINCH_HOLD_T
	d = drift(t, PINCH_HOLD_T, 1)
	quiver = window(t % 36, 12, 15, 20, 24) * math.sin(math.tau * t / 6)
	return contact(PINCH_POINT, (0, 0, 0.01 + 0.032 * k), PULL_PITCH - 20 * k + 1.2 * d[2] + 1.0 * quiver,
		-10 + 4 * k + 1.5 * d[0] + 0.8 * quiver, 2.5 * math.sin(u) + d[1])


def pinch_hold_shape(t):
	return lerp(PINCH, SQUEEZE, 0.3 + 0.7 * tug(t % PINCH_HOLD_T))


def pinch_open(others):
	"""Thumb and index opened wide for the pinch, the other three held as given."""
	s = copy(OPEN)
	for name in ('Middle', 'Ring', 'Pinky'):
		s[name] = list(others[name])
	return s


def pinch_in(t):
	"""It rises and opens thumb and index wide, tips over to look down on the spot, and
	swoops down steeply to close on it, the other three tucked well up."""
	lift = moved(IDLE0, dz=0.08, pitch=-8)
	above = contact(PINCH_POINT, (0, 0.02, 0.16), 54, -8)
	touch = contact(PINCH_POINT, (0, 0, 0), PULL_PITCH + 2, -10)
	ready = pinch_open(lerp(RELAX, SQUEEZE, 0.55))  # the others start tucking on the lift
	early = lerp(OPEN, PINCH, 0.55)
	for name in ('Middle', 'Ring', 'Pinky'):
		early[name] = list(SQUEEZE[name])
	p = track(t, [(0, IDLE0), (5, lift), (10, above), (PINCH_CONTACT, touch), (26, pinch_hold_place(0), 0.1)])
	s = track(t, [(0, idle0_shape()), (5, ready), (10, early), (PINCH_CONTACT, PINCH), (18, SQUEEZE), (26, pinch_hold_shape(0))])
	return p, s, track(t, [(0, 0.0), (PINCH_CONTACT - 2, 0.0), (PINCH_CONTACT, 1.0)])


def pinch_hold(t):
	return pinch_hold_place(t), pinch_hold_shape(t), 1.0


def pinch_out(t):
	"""Letting go: one last squeeze and tug, then the tips spring apart and the hand
	pops up and back, tipping level, and floats home."""
	start = pinch_hold_place(0)
	tugged = contact(PINCH_POINT, (0, 0, 0.03), PULL_PITCH - 8, -12)
	p = track(t, [(0, start), (4, tugged), (11, moved(IDLE0, dz=0.12, pitch=-14), 0.1), (34, IDLE0)])
	release = pinch_open(RELAX)
	s = track(t, [(0, pinch_hold_shape(0)), (4, SQUEEZE), (7, lerp(SQUEEZE, release, 0.25)), (13, release, 0.14), (34, idle0_shape())])
	return p, s, track(t, [(0, 1.0), (4, 1.0), (8, 0.0)])


# ---------------------------------------------------------------- press: smushing land like clay

PRESS_CONTACT = 13
PRESS_HOLD_T = 72


def press_push(t):
	"""0..1, twice a hold loop: bearing down on the palm, then easing."""
	return 0.5 - 0.5 * math.cos(math.tau * (t % PRESS_HOLD_T) / 36)


def press_hold_place(t):
	"""Bearing down palm first: twice a loop the palm presses harder, the heel rocking down
	and the fingers lifting further, while it works round a slow circle, the little-finger
	side then the thumb's."""
	t %= PRESS_HOLD_T
	u = math.tau * t / 36
	k = press_push(t)
	d = drift(t, PRESS_HOLD_T, 2)
	return contact(PALM_POINT, (0.01 * math.cos(u) + 0.004 * d[0], 0.01 * math.sin(u) + 0.004 * d[1], -0.008 - 0.014 * k),
		-2 - 4 * k + 0.8 * d[2], 2.5 * math.cos(u), 0.8 * d[1])


def press_hold_shape(t):
	return lerp(PRESS, PRESS_HARD, press_push(t))


def press_in(t):
	"""It rises, opening, the fingers stretching long and lifting, then comes down palm
	first and bears down, the fingers flaring up on the impact."""
	rise = contact(PALM_POINT, (0, 0.04, 0.3), -10, 0)
	touch = contact(PALM_POINT, (0, 0, -0.016), -4, 0)
	p = track(t, [(0, IDLE0), (8, rise), (PRESS_CONTACT, touch), (17, contact(PALM_POINT, (0, 0, -0.02), -6, 0)),
		(27, press_hold_place(0))])
	s = track(t, [(0, idle0_shape()), (6, OPEN), (10, PRESS), (PRESS_CONTACT, PRESS_HARD, 0.12), (27, press_hold_shape(0))])
	return p, s, track(t, [(0, 0.0), (PRESS_CONTACT - 2, 0.0), (PRESS_CONTACT, 1.0)])


def press_hold(t):
	return press_hold_place(t), press_hold_shape(t), 1.0


def press_out(t):
	"""Lifting off: one last push, then the palm comes up flat, the fingers easing down from
	their lift as it floats home."""
	start = press_hold_place(0)
	p = track(t, [(0, start), (4, contact(PALM_POINT, (0, 0, -0.02), -6, 0)), (12, contact(PALM_POINT, (0, 0.01, 0.1), -8, 0)),
		(22, moved(IDLE0, dz=0.05, pitch=-3)), (36, IDLE0)])
	s = track(t, [(0, press_hold_shape(0)), (4, PRESS_HARD), (12, PRESS), (22, OPEN), (36, idle0_shape())])
	return p, s, track(t, [(0, 1.0), (4, 1.0), (9, 0.0)])


# ---------------------------------------------------------------- cup: carrying and popping the water orb

CUP_FORMED = 21
CUP_HOLD_T = 120
B0 = Vector((0.0, 0.0, 0.95))  # the orb's centre while it is carried, over the anchor
UNDER = Vector((0.0, 0.0, -ORB_R))  # from its centre to where the palm holds it
CARRY = contact(ORB_CENTRE, B0, -8, -178)  # palm up under the orb
# The release: the palm tosses the orb up TOSS on an easing arc, and the index pokes it
# on its wrist side (+Y) at CUP_POP, where it pops. The game's ball rises and pops on
# the same beat (scripts/water_ball.gd TOSS, POP_SECONDS).
CUP_POP = 13
TOSS = 0.18
BESIDE = Vector((0.0, ORB_R, 0.0))


def carried(weight):
	return {'ball': (B0, B0 + UNDER, weight)}


def cup_hold_place(t):
	"""Working the orb: the palm circles under it twice a loop, rolling it round, and the
	hand turns under it once a loop like a globe being turned. Every attitude turns
	about the orb's centre, so the palm keeps to it."""
	t %= CUP_HOLD_T
	u = math.tau * t / CUP_HOLD_T
	d = drift(t, CUP_HOLD_T, 3)
	return contact(ORB_CENTRE, B0, -8 + 8 * math.sin(2 * u) + d[0], -178 + 7 * math.cos(2 * u) + d[1], 20 * math.sin(u) + 1.5 * d[2])


def cup_hold_shape(t):
	"""The fingers roll a wave round the orb, little finger to index, three a loop, the
	thumb sweeps over its side twice, and once a loop the hand settles its grip."""
	t %= CUP_HOLD_T
	u = math.tau * t / CUP_HOLD_T
	s = add(CUP, {name: (16 * math.sin(3 * u - 0.9 * i), 3.0 * math.cos(3 * u - 0.9 * i))
		for i, name in enumerate(('Pinky', 'Ring', 'Middle', 'Index'))})
	sweep = math.sin(2 * u + 0.5)
	s['Thumb'][3] += 12 * sweep
	s['Thumb'][1] += 7 * sweep
	s['Thumb'][2] += 4 * math.sin(2 * u + 1.3)
	regrip = pulses(t, [64], 20)
	s = add(s, {name: (8 * regrip, 0) for name in DIGITS})
	s['cup'] += 3 * regrip
	return s


def cup_in(t):
	dip = moved(IDLE0, dz=-0.04, pitch=4, roll=12)  # rolls the other way before turning over
	turning = contact(ORB_CENTRE, B0 + Vector((0, 0.02, -0.25)), 6, -95)  # thumb up, halfway over, rising
	end = cup_hold_place(0)
	p = track(t, [(0, IDLE0), (6, dip), (14, turning), (CUP_FORMED, moved(end, dz=0.03)), (32, end)])
	s = track(t, [(0, idle0_shape()), (6, lerp(idle0_shape(), OPEN, 0.5)), (15, CUP_OPEN), (CUP_FORMED, CUP, 0.1),
		(32, cup_hold_shape(0))])
	pin = track(t, [(0, 0.0), (CUP_FORMED, 0.0), (32, 0.5)])
	return p, s, pin, carried(track(t, [(0, 0.0), (9, 0.0), (CUP_FORMED, 1.0)]))


def cup_hold(t):
	return cup_hold_place(t), cup_hold_shape(t), 0.5, carried(1.0)


def tossed(t):
	"""The orb's centre on its toss, up to the pop."""
	u = clamp(t / CUP_POP)
	return B0 + Vector((0, 0, TOSS * (1 - (1 - u) ** 2)))


def cup_out(t):
	"""The release: the palm tosses the orb up, drops away round to its side turning
	thumb up, the index draws back and pokes it: it pops. The hand recoils with its
	fingers flung open, shakes the wet off and floats home."""
	pop = tossed(CUP_POP)
	start = cup_hold_place(0)
	push = contact(ORB_CENTRE, tossed(3), -24, -174)
	under = contact(ORB_CENTRE, tossed(6) + Vector((0, 0.16, -0.2)), -14, -148)  # drops clear below it first
	aside = contact(POKE_TIP, tossed(9) + BESIDE + Vector((0, 0.17, -0.06)), -6, -96)
	drawn = contact(POKE_TIP, pop + BESIDE + Vector((0, 0.2, -0.02)), -4, -94)
	touch = contact(POKE_TIP, pop + BESIDE, 0, -92)
	through = contact(POKE_TIP, pop + BESIDE + Vector((0, -0.05, 0.004)), 2, -92)
	recoil = contact(POKE_TIP, pop + BESIDE + Vector((0, 0.13, 0.06)), -12, -104)
	p = track(t, [(0, start), (3, push), (6, under), (9, aside), (11, drawn), (CUP_POP, touch), (15, through), (22, recoil, 0.1),
		(30, moved(recoil, dz=0.012, roll=4)), (58, IDLE0)])
	shake = window(t, 30, 33, 38, 44) * math.sin(math.tau * (t - 30) / 6)
	p = moved(p, dz=0.004 * shake, roll=7 * shake, yaw=2 * shake)
	s = track(t, [(0, cup_hold_shape(0)), (3, lerp(CUP, CUP_OPEN, 0.7)), (7, lerp(CUP_OPEN, POINT, 0.6)), (10, POINT),
		(CUP_POP, POINT), (16, POINT), (21, BLOOM, 0.14), (32, lerp(BLOOM, RELAX, 0.5)), (58, idle0_shape())])
	pin = track(t, [(0, 0.5), (3, 0.5), (6, 0.0), (11, 0.0), (CUP_POP, 0.6), (15, 0.6), (18, 0.0)])
	direction = track(t, [(0, UNDER), (3, UNDER), (9, BESIDE)]).normalized() * ORB_R
	centre = tossed(t)
	weight = track(t, [(0, 1.0), (CUP_POP + 1, 1.0), (CUP_POP + 4, 0.0)])
	return p, s, pin, {'ball': (centre, centre + direction, weight)}


# ---------------------------------------------------------------- sprinkle: tossing seed

# Tossing a pinch of salt: palm down, the seed held in the gathered tips of thumb, index
# and middle (BUNCH, solved against the rig), ring and little finger tucked. Each toss
# draws back and up with the wrist cocked, the fingertips curled down and in, then swings
# forward, the wrist flicking the fingertips up and out, and at the release the fingers
# spring apart and the pinch flies on. It follows through, then the fingertips gather a
# fresh pinch, the thumb rolling over them, and it draws back again. The arm and the
# wrist toss; the fingers only open to let go.
SPRINKLE_HOLD_T = 80
THROW_T = 40  # one toss
THROW_RELEASE = 9  # frame in a toss the pinch leaves
THROW_CLOSED = 25  # frame the fingertips have gathered the next pinch
SOW_AT = Vector((0.0, 0.02, 0.62))  # where the palm is, over the anchor, while tossing
SOW_ROLL = -14  # palm down, the thumb side a little up so the pinch shows
# One toss, from the top of the draw back: the palm's way (dy, dz), the wrist (pitch,
# + fingertips down), which trails the swing and flicks at the release, and the turn into
# the toss (yaw). The loop starts drawn back, so the gathering of a pinch ends there and
# the first toss comes at once.
THROW_PATH = [(0, (0.14, 0.05)), (THROW_RELEASE, (-0.1, 0.08)), (16, (-0.2, 0.12)), (THROW_CLOSED, (-0.05, -0.02)),
	(30, (0.0, 0.0)), (36, (0.1, 0.03)), (THROW_T, (0.14, 0.05))]
THROW_WRIST = [(0, 50.0), (5, 44.0), (THROW_RELEASE, 2.0), (15, -14.0), (22, 12.0), (28, 26.0), (36, 46.0), (THROW_T, 50.0)]
THROW_TURN = [(0, -12.0), (THROW_RELEASE, 6.0), (16, 12.0), (30, 0.0), (THROW_T, -12.0)]


def sow(dy=0.0, dz=0.0, pitch=0.0, yaw=0.0):
	"""Palm down, SOW_AT over the anchor, moved and turned about the palm."""
	return contact(PALM_POINT, SOW_AT + Vector((0, dy, dz)), 30 + pitch, SOW_ROLL, yaw)


def throw_shape(f):
	"""The pinch held, rolled once between thumb and fingertips as the wrist cocks, sprung
	open at the release and gathered again."""
	return track(f, [(0, BUNCH), (4, RUB_A), (THROW_RELEASE - 2, BUNCH), (THROW_RELEASE + 3, FLING, 0.15), (16, FLING),
		(THROW_CLOSED, BUNCH, 0.06), (30, RUB_B), (36, BUNCH), (THROW_T, BUNCH)])


def throw_held(f):
	"""1 while a pinch is in the fingertips, 0 from the release until they gather again."""
	return 0.0 if THROW_RELEASE <= f < THROW_CLOSED else 1.0


def sprinkle_hold_place(t):
	"""Two tosses a loop, the first a little left, the second a little right and higher,
	the float going on under them."""
	t %= SPRINKLE_HOLD_T
	f = t % THROW_T
	dy, dz = flow(f, THROW_PATH, periodic=True)
	side = math.cos(math.tau * (t - THROW_RELEASE) / SPRINKLE_HOLD_T)
	lift = 0.015 * (1 - side)
	yaw = flow(f, THROW_TURN, periodic=True) - 10 * side
	return breathing(sow(dy, dz + lift, flow(f, THROW_WRIST, periodic=True) - 30, yaw), t, SPRINKLE_HOLD_T, 1, amp=0.3, seed=4)


def sprinkle_hold_shape(t):
	return throw_shape(t % THROW_T)


def sprinkle_in(t):
	"""Taking a pinch: the hand dips, thumb and fingertips parting, and they close on a
	pinch as it comes up and draws back to toss."""
	dip = sow(0.02, -0.12, 30)
	p = track(t, [(0, IDLE0), (8, dip, 0.05), (13, moved(dip, dz=0.02)), (20, sprinkle_hold_place(0))])
	s = track(t, [(0, idle0_shape()), (7, lerp(OPEN, BUNCH, 0.35)), (12, BUNCH, 0.08), (20, sprinkle_hold_shape(0))])
	return p, s, 0.0, {'handful': 1.0}


def sprinkle_hold(t):
	return sprinkle_hold_place(t), sprinkle_hold_shape(t), 0.0, {'handful': throw_held(t % THROW_T)}


SPRINKLE_OUT_RELEASE = 8
SPRINKLE_OUT_T = 46


def sprinkle_out(t):
	"""The last of it: straight from the draw back, a toss of whatever is in the fingertips,
	then it floats up, dusts them off and comes home."""
	start = sprinkle_hold_place(0)
	f = min(t, 20)
	dy, dz = flow(f, [(0, (0.0, 0.0)), (SPRINKLE_OUT_RELEASE, (-0.26, 0.04)), (15, (-0.36, 0.08)), (20, (-0.37, 0.085))])
	wrist = flow(f, [(0, 0.0), (4, -5.0), (SPRINKLE_OUT_RELEASE, -48.0), (14, -64.0), (20, -62.0)])
	thrown = moved(start, dy=dy, dz=dz, pitch=wrist)
	p = thrown if t < 20 else track(t, [(20, thrown), (32, moved(IDLE0, dz=0.05, pitch=-8)), (SPRINKLE_OUT_T, IDLE0)])
	dust = window(t, 22, 25, 30, 36) * math.sin(math.tau * (t - 22) / 5)
	p = moved(p, roll=5 * dust, pitch=2 * dust)
	s = track(t, [(0, sprinkle_hold_shape(0)), (SPRINKLE_OUT_RELEASE - 2, BUNCH), (SPRINKLE_OUT_RELEASE + 3, FLING, 0.15),
		(20, FLING), (32, lerp(FLING, RELAX, 0.6)), (SPRINKLE_OUT_T, idle0_shape())])
	return p, s, 0.0, {'handful': 1.0 if t < SPRINKLE_OUT_RELEASE else 0.0}


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
	mats = [matrix(fr[0]) for fr in frames]
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
	'IdleStretch': (IDLE_T, idle_stretch, False, 'Idle', 'Idle'),
	'IdlePeek': (IDLE_T, idle_peek, False, 'Idle', 'Idle'),
	'IdleRipple': (IDLE_T, idle_ripple, False, 'Idle', 'Idle'),
	'IdleGather': (IDLE_T, idle_gather, False, 'Idle', 'Idle'),
	'IdleDrift': (IDLE_T, idle_drift, False, 'Idle', 'Idle'),
	'PinchIn': (26, pinch_in, False, 'Idle', 'PinchHold'),
	'PinchHold': (PINCH_HOLD_T, pinch_hold, True, None, None),
	'PinchOut': (34, pinch_out, False, 'PinchHold', 'Idle'),
	'PressIn': (27, press_in, False, 'Idle', 'PressHold'),
	'PressHold': (PRESS_HOLD_T, press_hold, True, None, None),
	'PressOut': (36, press_out, False, 'PressHold', 'Idle'),
	'CupIn': (32, cup_in, False, 'Idle', 'CupHold'),
	'CupHold': (CUP_HOLD_T, cup_hold, True, None, None),
	'CupOut': (58, cup_out, False, 'CupHold', 'Idle'),
	'SprinkleIn': (20, sprinkle_in, False, 'Idle', 'SprinkleHold'),
	'SprinkleHold': (SPRINKLE_HOLD_T, sprinkle_hold, True, None, None),
	'SprinkleOut': (SPRINKLE_OUT_T, sprinkle_out, False, 'SprinkleHold', 'Idle'),
}


# ---------------------------------------------------------------- shake: the snow globe (hand-world)

# Shaking the diorama like a snow globe (docs/scenic/hand-snow-globe.md). The anchor is a
# point on the rim's outer lip, and the game turns the hand so its reach (-Y) points in
# across the lip: the plate's top is z = 0 for y < 0 and the earth block's wall is y = 0
# below it. The hand hangs on the outside of the wall with its palm to it, the four
# fingers hooked over the lip onto the top and the thumb braced on the wall, a ledge grip
# the camera sees from the back. The game shakes the diorama itself (the camera rings on
# a spring); the clips give the hand's side of it: the grip, the effort in the wrist while
# it shakes, and the let-go. The hold is a short loop the game plays faster or slower
# with how hard the drag shakes (god_hand.gd `reach_pace`).
SHAKE_CONTACT = 12  # frame the fingers hook over the lip
SHAKE_IN_T = 22
SHAKE_HOLD_T = 24  # two shakes a loop, 2.5 a second at pace 1
SHAKE_OUT_T = 42
GRIP_PITCH = -84  # fingers up the wall, leaning a touch over the plate
GRIP_PALM = Vector((0.0, 0.045, -0.2))  # the middle of the palm, just off the wall
# Where each fingertip hooks over onto the plate's top, and the thumb on the wall.
GRIP_TIPS = {'Index': (0.19, -0.11, 0.022), 'Middle': (0.06, -0.14, 0.022), 'Ring': (-0.075, -0.12, 0.022),
	'Pinky': (-0.19, -0.075, 0.022), 'Thumb': (0.3, 0.075, -0.16)}
GRIP_AT = Vector(GRIP_TIPS['Middle'])  # the point the grip holds the lip by
# Solved against the rig by prepare_shake(): the grip, the grip squeezed, and the middle
# fingertip in the hand's own frame under the grip.
GRIP = GRIP_HARD = None
GRIP_TIP = None


def grip_place(dx=0.0, dy=0.0, dz=0.0, pitch=0.0, roll=0.0, yaw=0.0):
	"""The grip, turned about the hooked fingertips so they keep to the lip."""
	return contact(GRIP_TIP, GRIP_AT + Vector((dx, dy, dz)), GRIP_PITCH + pitch, roll, yaw)


def prepare_shake(rig):
	"""Solve the ledge grip: palm to the wall, fingertips hooked onto the plate's top,
	thumb braced on the wall."""
	global GRIP, GRIP_HARD, GRIP_TIP
	p = contact(PALM_POINT, GRIP_PALM, GRIP_PITCH, 0.0)
	q = attitude(*p[3:])
	h = Vector(p[:3])
	goals = [(f'{name}3', q.inverted() @ (Vector(at) - h) + H) for name, at in GRIP_TIPS.items()]
	guess = shape((40, 50, 30, 2), (40, 52, 30, 0), (40, 52, 30, -3), (38, 50, 28, -7), (6, 10, 10, -20, 0), 3)
	free = free_finger('Index') + free_finger('Middle') + free_finger('Ring') + free_finger('Pinky') + FREE_THUMB
	GRIP, err = solve_shape(rig, guess, free, goals)
	print('HAND_SOLVE grip', round(err, 4))
	apply_shape(rig, GRIP)
	GRIP_TIP = tail_of(rig, 'Middle3').copy()
	reset(rig)
	GRIP_HARD = add(GRIP, {'Index': (7, 0), 'Middle': (7, 0), 'Ring': (8, 0), 'Pinky': (9, 0), 'Thumb': (5, 0)})


def shake_wave(t):
	"""The shake at frame t of the hold, -1..1, two a loop: near a sine, with a little
	snap as each stroke turns."""
	u = math.tau * 2 * (t % SHAKE_HOLD_T) / SHAKE_HOLD_T
	return (math.sin(u) + 0.18 * math.sin(3 * u)) / 1.03


def shake_hold_place(t):
	"""Working the rim: the heel of the hand swings along the lip and back about the
	hooked fingertips, the wrist rolling into each stroke, and the palm pumps against the
	wall at the turns. The fingertips keep their hold."""
	t %= SHAKE_HOLD_T
	w = shake_wave(t)
	lag = shake_wave(t - 2)  # the wrist trails the heel
	u = math.tau * 2 * t / SHAKE_HOLD_T
	return grip_place(0.012 * w, 0.006 * math.cos(2 * u), -0.004 * abs(w),
		pitch=3.0 * math.cos(2 * u), roll=9.0 * lag, yaw=7.0 * w)


def shake_hold_shape(t):
	"""The grip squeezes at each turn; the thumb flaps a beat behind the stroke and the
	little finger lifts off at the far end and hooks back."""
	t %= SHAKE_HOLD_T
	w = shake_wave(t)
	u = math.tau * 2 * t / SHAKE_HOLD_T
	s = lerp(GRIP, GRIP_HARD, 0.5 + 0.5 * math.cos(2 * u))
	lag = shake_wave(t - 3)
	s['Thumb'][3] += 9 * lag
	s['Thumb'][1] += 5 * lag
	lift = max(0.0, lag)
	s['Pinky'][0] -= 12 * lift
	s['Pinky'][1] -= 8 * lift
	return s


def shake_in(t):
	"""Taking hold: it rises and opens wide as it draws back from the rim, swings out over
	the lip with the palm to the wall and the fingers long and up, then drops and hooks them
	over, squeezing past the grip and easing back."""
	lift = moved(IDLE0, dy=-0.03, dz=0.08, pitch=-18, roll=6)
	out = grip_place(dy=0.16, dz=0.2, pitch=-8, roll=-4)
	over = grip_place(dy=0.03, dz=0.05, pitch=-4)
	p = track(t, [(0, IDLE0), (5, lift), (9, out), (SHAKE_CONTACT, over), (15, grip_place(dz=-0.012, pitch=2), 0.1),
		(SHAKE_IN_T, shake_hold_place(0))])
	s = track(t, [(0, idle0_shape()), (5, OPEN), (9, lerp(OPEN, BLOOM, 0.5)), (SHAKE_CONTACT, lerp(OPEN, GRIP, 0.8)),
		(15, GRIP_HARD, 0.12), (SHAKE_IN_T, shake_hold_shape(0))])
	return p, s, track(t, [(0, 0.0), (SHAKE_CONTACT - 1, 0.0), (15, 1.0)])


def shake_hold(t):
	return shake_hold_place(t), shake_hold_shape(t), 1.0


def shake_out(t):
	"""Letting go: one last squeeze with the heel dipping, then the fingers unhook and
	fling open as the hand springs up and back off the rim, shakes itself out loose from
	the wrist, and floats home."""
	start = shake_hold_place(0)
	squeeze = grip_place(dz=-0.02, pitch=4)
	unhook = grip_place(dy=0.1, dz=0.1, pitch=-14)
	sprung = moved(IDLE0, dy=0.18, dz=0.2, pitch=-30, roll=-10)
	p = track(t, [(0, start), (3, squeeze), (6, unhook), (12, sprung, 0.12), (24, moved(IDLE0, dy=0.06, dz=0.08, pitch=-10)),
		(SHAKE_OUT_T, IDLE0)])
	loose = window(t, 13, 16, 22, 27) * math.sin(math.tau * (t - 13) / 5)
	p = moved(p, dx=0.006 * loose, roll=12 * loose, yaw=4 * loose)
	s = track(t, [(0, shake_hold_shape(0)), (3, GRIP_HARD), (6, lerp(GRIP, OPEN, 0.5)), (11, FLING, 0.15),
		(24, lerp(FLING, RELAX, 0.6)), (SHAKE_OUT_T, idle0_shape())])
	for name in FINGER_NAMES:
		for j, k in enumerate((10, 8, 5)):
			s[name][j] += k * loose
	return p, s, track(t, [(0, 1.0), (3, 1.0), (7, 0.0)])


CLIPS.update({
	'ShakeIn': (SHAKE_IN_T, shake_in, False, 'Idle', 'ShakeHold'),
	'ShakeHold': (SHAKE_HOLD_T, shake_hold, True, None, None),
	'ShakeOut': (SHAKE_OUT_T, shake_out, False, 'ShakeHold', 'Idle'),
})


def frame(name, f):
	"""(placement, shape, pin, marks) for frame f of a clip."""
	out = CLIPS[name][1](f)
	return out if len(out) == 4 else (*out, {})


_springs = {}


def springs(rig, name):
	"""(offsets, states) for a clip, chained through its neighbours; cached."""
	if name not in _springs:
		T, fn, loop, before, after = CLIPS[name]
		frames = [frame(name, f) for f in range(T if loop else T + 1)]
		start = springs(rig, before)[1][0] if before else None
		end = springs(rig, after)[0][0] if after else None
		_springs[name] = follow_through(rig, frames, loop, start, end)
	return _springs[name]


def evaluate(rig, name):
	"""[(placement, shape, marks)] for every frame of a clip, springs included. A loop gives
	its frames once (frame T is frame 0 again); a one-shot includes its last frame."""
	T, fn, loop, _, _ = CLIPS[name]
	frames = [frame(name, f) for f in range(T if loop else T + 1)]
	offsets = springs(rig, name)[0]
	return [(p, add(s, {k: tuple(o) for k, o in off.items()}), marks) for (p, s, _, marks), off in zip(frames, offsets)]


# The weights on the marks' bones never reach 0, so their matrices stay invertible.
LEAST = 0.001


def set_at(rig, bone, point, weight=1.0):
	"""Put a mark bone (a child of Root) at an armature-space point, scaled by weight."""
	rest = rig.data.bones[bone].matrix_local
	m = rest.copy()
	m.translation = Vector(point)
	rig.pose.bones[bone].matrix_basis = rest.inverted() @ m @ Matrix.Scale(max(weight, LEAST), 4)


def pose(rig, p, s, marks=None):
	reset(rig)
	place(rig, p)
	apply_shape(rig, s)
	marks = marks or {}
	centre, touch, weight = marks.get('ball', (B0, B0 + UNDER, 0.0))
	set_at(rig, 'Ball', centre, weight)
	set_at(rig, 'BallTouch', touch)
	held = max(marks.get('handful', 0.0), LEAST)
	rig.pose.bones['Handful'].scale = (held, held, held)


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
