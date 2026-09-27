"""Deer: a rigged, faceted doe and her fawn for the life that answers the land
(docs/scenic/life.md). Clips come from deer_clips.py, after the ambient Bigfoot's.

Run: blender -b --python tools/blender_creatures/deer.py -- [--no-render] [--no-anim]

The body, neck and head are one metaball family converted to a mesh and decimated into
large facets like the Bigfoot and the hero trees. Legs, ears, tail, eyes and lids are
faceted pieces on top, each weighted by distance to its own bones. The doe and the fawn
are the same skinned mesh painted twice (the fawn lighter and spotted); life_moments
scales the fawn to 0.62. Colours are raw linear values, the same numbers the Godot
reference_surface material reads, so the coat matches the old code-built deer.

Saves art/blender/creatures/zenscape-deer.blend, exports assets/models/zenscape-deer.glb
and renders rest views to /tmp/zs-deer-previews/rest/ (clips: deer_review.py; numbers:
deer_check.py). Metres, origin between the hooves, Blender Z-up, facing -Y (Godot +Z).
"""
import bpy, bmesh, math, random, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, noise
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'blender_trees'))
sys.path.insert(0, str(HERE.parent / 'blender_bigfoot'))
sys.path.insert(0, str(HERE))
import kit
import deer_clips as clips

ROOT = kit.ROOT
ARGS = kit.ARGS
FPS = clips.FPS
rng = random.Random(11)

# ---------------------------------------------------------------- landmarks
# Left side (+X); the right mirrors. Hind leg: hip joint, stifle (the knee, pointing
# forward), hock (the heel, pointing back), fetlock and the toe of the hoof. Fore leg: the
# top of the shoulder blade, shoulder joint, elbow, carpus (the "knee"), fetlock and toe.
# Proportions keep the old code-built deer's: back about 0.95 m, legs 0.76 m, hind hooves
# 0.25 m behind the middle and fore hooves 0.29 m ahead.
HIP = Vector((0.075, 0.28, 0.78))
STIFLE = Vector((0.085, 0.19, 0.55))
HOCK = Vector((0.075, 0.33, 0.30))
HIND_FETLOCK = Vector((0.07, 0.31, 0.075))
HIND_TOE = Vector((0.07, 0.25, 0.0))
BLADE = Vector((0.06, -0.14, 0.96))
SHOULDER = Vector((0.085, -0.30, 0.76))
ELBOW = Vector((0.085, -0.18, 0.60))
CARPUS = Vector((0.075, -0.22, 0.31))
FORE_FETLOCK = Vector((0.07, -0.23, 0.075))
FORE_TOE = Vector((0.07, -0.29, 0.0))
# Neck and head along the vertebrae: the neck rises at about 60 degrees and is long enough
# for the nose to reach the grass; the face hangs about 50 degrees nose-down from the poll.
# The vertebrae leave the chest low, at the point of the shoulder, rise steeply and curve
# forward under the poll.
def _run(start, length, degrees):
	a = math.radians(degrees)
	return start + Vector((0, -math.cos(a), math.sin(a))) * length


NECK_BASE = Vector((0, -0.32, 0.74))
NECK_MID = _run(NECK_BASE, 0.273, 65)
POLL = _run(NECK_MID, 0.233, 50)
HEAD_LEN = 0.275
NOSE = _run(POLL, HEAD_LEN, -52)
HEAD_AXIS = (NOSE - POLL).normalized()
HEAD_DOWN = Vector((0, -HEAD_AXIS.z, HEAD_AXIS.y))  # ventral: toward the jaw and throat
EYE_AT, EYE_X, EYE_R = 0.36, 0.05, 0.017
EAR_LEN = 0.16
TAIL_BASE = Vector((0, 0.43, 0.9))
TAIL_TIP = Vector((0, 0.52, 0.72))

# Raw linear colours, as Godot's COLOR reads them. COAT and FAWN_COAT are the old deer's.
COAT = Vector((0.58, 0.38, 0.22))
FAWN_COAT = Vector((0.66, 0.46, 0.28))
PALE = Vector((0.86, 0.8, 0.7))
WHITE = Vector((0.93, 0.91, 0.87))
NOSE_BLACK = Vector((0.05, 0.045, 0.045))
HOOF = Vector((0.07, 0.06, 0.055))
EYE = Vector((0.03, 0.025, 0.022))
INNER_EAR = Vector((0.78, 0.68, 0.6))

PART_BODY, PART_EAR, PART_EYE, PART_LID, PART_TAIL, PART_LEG = 0, 1, 2, 3, 4, 10
LEG_NAMES = ('LF', 'RF', 'LH', 'RH')


def mirror(v):
	return Vector((-v.x, v.y, v.z))


def sided(v, s):
	return Vector(v) if s > 0 else mirror(Vector(v))


def head_point(along, down=0.0, side=0.0):
	"""A point in the head's frame: metres along the face from the poll, toward the jaw, and out."""
	return POLL + HEAD_AXIS * along + HEAD_DOWN * down + Vector((side, 0, 0))


def smoothstep(a, b, x):
	t = max(0.0, min(1.0, (x - a) / (b - a)))
	return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- body
SURFACE = 0.575  # surface radius of a lone ball per unit of influence radius


def ball(mb, co, r, stiffness=2.0):
	e = mb.elements.new(type='BALL')
	e.co, e.radius, e.stiffness = co, r / SURFACE, stiffness
	return e


def ellipsoid(mb, co, axes, rotation=None, stiffness=2.0):
	r = max(axes)
	e = mb.elements.new(type='ELLIPSOID')
	e.co, e.radius, e.stiffness = co, r / SURFACE, stiffness
	e.size_x, e.size_y, e.size_z = axes[0] / r, axes[1] / r, axes[2] / r
	if rotation is not None:
		e.rotation = rotation
	return e


def along(direction):
	"""Rotation taking local Y to direction, with local X kept across the body."""
	y = Vector(direction).normalized()
	x = Vector((1, 0, 0))
	x = (x - y * x.dot(y)).normalized()
	z = x.cross(y)
	return Matrix((x, y, z)).transposed().to_quaternion()


def neck_point(t):
	"""The neck's centreline, deep at the chest and slim under the poll."""
	a, b, c = NECK_BASE + Vector((0, 0.03, 0.03)), NECK_MID + Vector((0, -0.025, 0.0)), POLL + Vector((0, 0.01, -0.03))
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


def build_body(collection):
	mb = bpy.data.metaballs.new('BodyBall')
	mb.resolution = mb.render_resolution = 0.011
	mb.threshold = 0.6
	obj = bpy.data.objects.new('BodyBall', mb)
	collection.objects.link(obj)
	# Barrel: ribs and belly, tucked up toward the flank.
	ellipsoid(mb, (0, 0.0, 0.815), (0.122, 0.25, 0.14))
	ellipsoid(mb, (0, 0.14, 0.84), (0.11, 0.14, 0.115))
	# The deep chest and brisket between the shoulders, the withers above.
	ellipsoid(mb, (0, -0.21, 0.80), (0.112, 0.13, 0.165))
	ellipsoid(mb, (0, -0.16, 0.92), (0.08, 0.13, 0.07))
	# Croup: the back rises a touch to the rump, then rounds down to the tail.
	ellipsoid(mb, (0, 0.26, 0.86), (0.115, 0.14, 0.12))
	ellipsoid(mb, (0, 0.36, 0.84), (0.095, 0.08, 0.1))
	for s in (1, -1):
		# Hams: the thighs, down to the stifle.
		ellipsoid(mb, (0.068 * s, 0.30, 0.71), (0.056, 0.1, 0.15))
		ellipsoid(mb, (0.078 * s, 0.24, 0.60), (0.044, 0.07, 0.075))
		# Shoulder and upper arm, down to the elbow.
		ellipsoid(mb, (0.078 * s, -0.23, 0.79), (0.05, 0.095, 0.14))
		ellipsoid(mb, (0.082 * s, -0.19, 0.665), (0.043, 0.06, 0.065))
	# Neck: deep front to back, narrow across, tapering to the head.
	for i in range(9):
		t = i / 8
		p = neck_point(t)
		d = neck_point(min(1.0, t + 0.05)) - neck_point(max(0.0, t - 0.05))
		depth = 0.135 + (0.07 - 0.135) * t ** 0.8
		width = 0.088 + (0.052 - 0.088) * t
		ellipsoid(mb, p, (width, depth * 0.9, depth), along(d))
	# Head: a rounded cranium, full cheeks, and a long muzzle that tapers to the nose.
	q = along(HEAD_AXIS)
	k, g = HEAD_LEN / 0.262, 1.1
	ellipsoid(mb, head_point(0.035 * k, -0.012), (0.066, 0.08, 0.066), q)
	ellipsoid(mb, head_point(0.1 * k, 0.012), (0.05 * g, 0.075 * g, 0.05 * g), q)
	for s in (1, -1):
		ellipsoid(mb, head_point(0.095 * k, 0.022, 0.024 * s), (0.032, 0.055, 0.036), q)
	ellipsoid(mb, head_point(0.17 * k, 0.004), (0.037 * g, 0.075, 0.039 * g), q)
	ellipsoid(mb, head_point(0.228 * k, 0.004), (0.027, 0.034, 0.028), q)
	# The lower jaw and chin, a little apart from the muzzle so the mouth reads.
	ellipsoid(mb, head_point(0.17 * k, 0.032), (0.027, 0.075, 0.019), q)
	dg = bpy.context.evaluated_depsgraph_get()
	mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
	bpy.data.objects.remove(obj)
	bpy.data.metaballs.remove(mb)
	body = bpy.data.objects.new('Body', mesh)
	collection.objects.link(body)
	# Big facets, then a slight jitter so no two faces share a plane.
	dec = body.modifiers.new('Facets', 'DECIMATE')
	dec.ratio = TARGET_FACES / max(1, len(mesh.polygons))
	bpy.context.view_layer.objects.active = body
	bpy.ops.object.modifier_apply(modifier=dec.name)
	bm = bmesh.new()
	bm.from_mesh(body.data)
	bmesh.ops.triangulate(bm, faces=bm.faces)
	for v in bm.verts:
		v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.0035
	bm.to_mesh(body.data)
	bm.free()
	return body


TARGET_FACES = 900


# ---------------------------------------------------------------- pieces

def ring_tube(bm, points, radii, sides, lateral=Vector((1, 0, 0)), shape=None, twist=0.0):
	"""A faceted tube along points with rings framed by a fixed lateral axis (not parallel
	transport), so vertex k of every ring faces the same way and shape(i, k, dir) can push
	single vertices (the point of the hock). Capped at the end. Returns the rings."""
	rings = []
	for i, (p, r) in enumerate(zip(points, radii)):
		p = Vector(p)
		a = Vector(points[max(0, i - 1)])
		b = Vector(points[min(len(points) - 1, i + 1)])
		tangent = (b - a).normalized()
		side = (lateral - tangent * lateral.dot(tangent)).normalized()
		up = tangent.cross(side)
		ring = []
		for k in range(sides):
			ang = twist + (i % 2) * math.pi / sides + k * math.tau / sides
			d = side * math.cos(ang) + up * math.sin(ang)
			extra = shape(i, k, d) if shape else Vector()
			ring.append(bm.verts.new(p + d * r + extra))
		rings.append(ring)
	for a, b in zip(rings, rings[1:]):
		for k in range(sides):
			bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
	return rings


def cap(bm, ring, tip):
	t = bm.verts.new(Vector(tip))
	for k in range(len(ring)):
		bm.faces.new((ring[k], ring[(k + 1) % len(ring)], t))


def leg(bm, fore, s):
	"""One faceted leg from inside the ham or elbow down to the hoof."""
	if fore:
		top, j1, j2, fet, toe = sided(ELBOW, s), sided(ELBOW, s), sided(CARPUS, s), sided(FORE_FETLOCK, s), sided(FORE_TOE, s)
		pts = [top + Vector((0, -0.01, 0.075)), j1, j1.lerp(j2, 0.45), j1.lerp(j2, 0.86), j2, j2.lerp(fet, 0.18),
			j2.lerp(fet, 0.62), fet + Vector((0, 0.004, 0.016)), fet]
		radii = [0.036, 0.035, 0.028, 0.02, 0.022, 0.018, 0.0155, 0.017, 0.0185]
	else:
		top, j1, j2, fet, toe = sided(STIFLE, s), sided(STIFLE, s), sided(HOCK, s), sided(HIND_FETLOCK, s), sided(HIND_TOE, s)
		pts = [top + Vector((0, 0.03, 0.08)), j1 + Vector((0, 0.015, 0.0)), j1.lerp(j2, 0.42), j1.lerp(j2, 0.84), j2,
			j2.lerp(fet, 0.2), j2.lerp(fet, 0.62), fet + Vector((0, 0.004, 0.016)), fet]
		radii = [0.042, 0.04, 0.031, 0.021, 0.022, 0.018, 0.0155, 0.017, 0.0185]
	# Pastern, then the hoof: a dark wedge whose toe rests on the ground.
	pts += [fet.lerp(toe, 0.4), fet.lerp(toe, 0.62), fet.lerp(toe, 0.84)]
	radii += [0.0145, 0.018, 0.02]
	hock = 4

	def shape(i, k, d):
		if not fore and i == hock and d.y > 0.5:  # the point of the hock
			return Vector((0, 0.022, 0.012))
		if fore and i == 4 and d.y < -0.5:  # the front of the knee
			return Vector((0, -0.006, 0))
		return Vector()

	start = len(bm.verts)
	rings = ring_tube(bm, pts, radii, 5, shape=shape, twist=0.3)
	# Close the top inside the body, and bring the hoof to a point at the toe.
	top_centre = bm.verts.new(pts[0] + Vector((0, 0, 0.02)))
	for k in range(5):
		bm.faces.new((rings[0][(k + 1) % 5], rings[0][k], top_centre))
	cap(bm, rings[-1], toe + Vector((0, 0, 0.002)))
	return start


def ear(bm, s):
	"""A big cupped ear: an oval pinna, hollow toward the front and out, that tapers to a point."""
	base = POLL + Vector((0.042 * s, 0.02, 0.03))
	direction = Vector((0.62 * s, 0.36, 0.7)).normalized()
	opening = Vector((0.35 * s, -0.93, 0.15))
	opening = (opening - direction * opening.dot(direction)).normalized()
	side = direction.cross(opening).normalized()
	length = EAR_LEN
	stations = [(0.0, 0.018, 0.015), (0.12, 0.03, 0.013), (0.42, 0.046, 0.011), (0.72, 0.038, 0.009), (0.9, 0.02, 0.006)]
	rings = []
	for f, w, d in stations:
		c = base + direction * length * f
		ring = []
		for k in range(6):
			a = k * math.tau / 6 + 0.26
			x, y = math.cos(a) * w, math.sin(a) * d
			if y > 0:  # the front of the pinna dips in: a cup, not a leaf
				y -= d * 1.9 * (1 - abs(math.cos(a)))
			ring.append(bm.verts.new(c + side * x + opening * y))
		rings.append(ring)
	for a, b in zip(rings, rings[1:]):
		for k in range(6):
			bm.faces.new((a[k], a[(k + 1) % 6], b[(k + 1) % 6], b[k]))
	cap(bm, rings[-1], base + direction * length)
	for k in range(1, 5):
		bm.faces.new((rings[0][0], rings[0][k + 1], rings[0][k]))
	return base, direction, opening


def tail(bm):
	"""A short flat tail, brown above and white beneath."""
	d = (TAIL_TIP - TAIL_BASE).normalized()
	pts = [TAIL_BASE - d * 0.03, TAIL_BASE, TAIL_BASE.lerp(TAIL_TIP, 0.4), TAIL_BASE.lerp(TAIL_TIP, 0.78)]
	radii = [0.022, 0.026, 0.032, 0.022]

	def flat(i, k, direction):
		# Wide across, thin front to back.
		across = Vector((direction.x, 0, 0))
		return across * radii[i] * 0.6 - (direction - across) * radii[i] * 0.55

	rings = ring_tube(bm, pts, radii, 6, shape=flat)
	cap(bm, rings[-1], TAIL_TIP)
	for k in range(1, 5):
		bm.faces.new((rings[0][0], rings[0][k + 1], rings[0][k]))


def eyes(body_bvh):
	"""Large dark eyes on the sides of the head, and lids that close over them."""
	eye_bm, lid_bm = bmesh.new(), bmesh.new()
	found = []
	for s in (1, -1):
		guess = head_point(EYE_AT * HEAD_LEN, -0.014, EYE_X * s)
		hit = body_bvh.ray_cast(guess + Vector((0.2 * s, 0, 0)), Vector((-s, 0, 0)))[0]
		centre = Vector((hit.x - s * EYE_R * 0.45, hit.y, hit.z)) if hit else guess
		gaze = Vector((0.82 * s, -0.5, 0.06)).normalized()
		up = (Vector((0, 0.35, 1)) - gaze * Vector((0, 0.35, 1)).dot(gaze)).normalized()
		found.append((centre, gaze, up))
		ico = bmesh.ops.create_icosphere(eye_bm, subdivisions=2, radius=EYE_R)
		for v in ico['verts']:
			v.co += centre
		# Lid: a cap around "up", its edge resting just above the pupil.
		rows, cols, span = 4, 10, math.radians(96)
		tilt = Quaternion(up.cross(gaze).normalized(), math.radians(-24))
		grid = []
		for i in range(rows + 1):
			theta = span * i / rows
			ring = []
			for j in range(cols):
				phi = math.tau * j / cols
				ortho = gaze * math.cos(phi) + up.cross(gaze).normalized() * math.sin(phi)
				d = tilt @ (up * math.cos(theta) + ortho * math.sin(theta))
				ring.append(lid_bm.verts.new(centre + d * EYE_R * 1.18))
			grid.append(ring)
		for a, b in zip(grid, grid[1:]):
			for j in range(cols):
				lid_bm.faces.new((a[j], a[(j + 1) % cols], b[(j + 1) % cols], b[j]))
	bmesh.ops.recalc_face_normals(lid_bm, faces=lid_bm.faces)
	return eye_bm, lid_bm, found


# ---------------------------------------------------------------- colour

def neck_t(p):
	"""How far up the neck a point is (0 chest .. 1 poll), by its height between the two."""
	return (p.z - NECK_BASE.z) / (POLL.z - NECK_BASE.z)


def head_frame(p):
	rel = p - POLL
	return rel.dot(HEAD_AXIS), rel.dot(HEAD_DOWN), abs(rel.x)


HEAD_SPLIT = Vector((0, -1, 0.35)).normalized()  # a plane through the poll and the throat latch


def in_head(p):
	return (p - POLL).dot(HEAD_SPLIT) > -0.025 and p.z > POLL.z - 0.3


def body_colour(p, n, coat, fawn, eyes_at):
	c = Vector(coat)
	a, d, x = head_frame(p)
	head = in_head(p) and d < 0.075
	# Countershading: darker along the back and the top of the neck, paler down the sides.
	top = smoothstep(0.2, 0.85, n.z) * smoothstep(0.78, 0.95, p.z)
	c = c.lerp(coat * 0.72, 0.55 * top)
	# Belly, the inside of the legs and the chest between the forelegs.
	if (n.z < -0.6 and p.z < 0.74 and -0.3 < p.y < 0.3) or (abs(p.x) < 0.03 and p.z < 0.7 and n.z < 0.2):
		c = c.lerp(PALE, 0.75)
	# The white rump patch under the tail and down the backs of the thighs.
	if p.y > 0.34 and abs(p.x) < 0.065 and 0.6 < p.z < 0.9 and n.y > 0.2:
		c = c.lerp(WHITE, 0.9 * smoothstep(0.6, 0.7, p.z))
	if head:
		# A darker face with a pale band round the muzzle, a black nose and a white chin.
		c = c.lerp(coat * 0.78, 0.4 * smoothstep(0.02, 0.08, a) * (1 - smoothstep(0.15, 0.2, a)))
		if a > 0.2:
			c = c.lerp(PALE, 0.7)
		if a > 0.24 and d < 0.022:
			c = NOSE_BLACK * (1 + rng.uniform(-0.1, 0.1))
		if a > 0.12 and d > 0.028:
			c = c.lerp(WHITE, 0.85)
		for centre, gaze, up in eyes_at:  # the pale ring round each eye
			r = (p - centre).length
			if EYE_R * 0.9 < r < EYE_R * 1.75 and (p - centre).dot(gaze) > 0:
				c = c.lerp(PALE, 0.75)
	elif 0.72 < neck_t(p) < 1.05:
		# The white throat patch, just under the jaw.
		throat = (p - neck_point(min(1.0, neck_t(p)))).dot(Vector((0, -0.8, -0.6)))
		if throat > 0.035 and n.dot(Vector((0, -0.8, -0.6))) > 0.45:
			c = c.lerp(WHITE, 0.85)
	if fawn and not head and p.z > 0.72 and -0.28 < p.y < 0.38:
		for spot in FAWN_SPOTS:
			if (p - spot).length < 0.022:
				c = c.lerp(WHITE, 0.82)
				break
	mottle = 1.0 + 0.05 * noise.noise(p * 9.0) + rng.uniform(-0.025, 0.025)
	return c * mottle


def leg_colour(p, n, coat, s):
	c = Vector(coat).lerp(coat * 0.85, smoothstep(0.5, 0.2, p.z))
	inside = n.x * s < -0.35
	if inside:
		c = c.lerp(PALE, 0.6)
	if p.z < 0.2 and not inside:  # the lower legs go grey-brown, darker at the front
		c = c.lerp(Vector((0.36, 0.3, 0.25)), 0.35 + 0.25 * max(0.0, -n.y))
	return c * (1 + rng.uniform(-0.03, 0.03))


def fawn_spots():
	"""Two rows of white spots along the fawn's back and a scatter down the flanks."""
	spots = []
	r = random.Random(4)
	for s in (1, -1):
		for i in range(9):
			y = -0.22 + i * 0.07 + r.uniform(-0.012, 0.012)
			spots.append(Vector((0.04 * s, y, 0.955 - 0.1 * (y - 0.05) ** 2)))
		for i in range(16):
			y = r.uniform(-0.22, 0.36)
			z = r.uniform(0.76, 0.9)
			spots.append(Vector((0.115 * s, y, z)))
	return spots


FAWN_SPOTS = fawn_spots()


def paint(obj, fawn, eyes_at, ears):
	coat = FAWN_COAT if fawn else COAT
	part = obj.data.attributes['part'].data
	rng.seed(21)

	def colour(poly):
		p, n, k = poly.center, poly.normal, part[poly.index].value
		if k == PART_BODY:
			return body_colour(p, n, coat, fawn, eyes_at)
		if k >= PART_LEG:
			s = 1 if k in (PART_LEG, PART_LEG + 2) else -1
			if p.z < 0.035:
				return HOOF * (1 + rng.uniform(-0.1, 0.1))
			return leg_colour(p, n, coat, s)
		if k == PART_EAR:
			s = 1 if p.x > 0 else -1
			base, direction, opening = ears[0 if s > 0 else 1]
			f = (p - base).dot(direction) / EAR_LEN
			c = Vector(coat) * 0.92
			if n.dot(opening) > 0.25:
				c = INNER_EAR.lerp(PALE, 0.3)
			if f > 0.78:  # dark tips and rims
				c = c.lerp(NOSE_BLACK, 0.6)
			return c * (1 + rng.uniform(-0.03, 0.03))
		if k == PART_EYE:
			return EYE
		if k == PART_LID:
			return Vector(coat) * 0.6
		if k == PART_TAIL:
			under = n.dot(Vector((0, -0.8, -0.6))) > 0.1
			return WHITE if under else Vector(coat) * 0.78
		return Vector(coat)

	kit.paint(obj, colour)
	for poly in obj.data.polygons:
		if part[poly.index].value == PART_EYE:
			poly.use_smooth = True


# ---------------------------------------------------------------- rig

def build_rig(collection, eyes_at, ears):
	arm_data = bpy.data.armatures.new('DeerRig')
	rig = bpy.data.objects.new('DeerRig', arm_data)
	collection.objects.link(rig)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.mode_set(mode='EDIT')
	eb = arm_data.edit_bones

	def bone(name, head, tail, parent=None, deform=True, connect=False):
		b = eb.new(name)
		b.head, b.tail = Vector(head), Vector(tail)
		if parent:
			b.parent = eb[parent]
			b.use_connect = connect
		b.use_deform = deform
		return b

	bone('Root', (0, 0, 0), (0, 0.25, 0), deform=False)
	# Hips carries the whole body from its middle, so a turn of it pitches or rolls the lot.
	bone('Hips', (0, 0.05, 0.86), (0, 0.38, 0.87), 'Root')
	bone('Tail1', TAIL_BASE, TAIL_BASE.lerp(TAIL_TIP, 0.45), 'Hips')
	bone('Tail2', TAIL_BASE.lerp(TAIL_TIP, 0.45), TAIL_TIP, 'Tail1', connect=True)
	bone('Spine', (0, 0.05, 0.86), (0, -0.15, 0.87), 'Hips')
	bone('Chest', (0, -0.15, 0.87), NECK_BASE + Vector((0, 0.02, 0.02)), 'Spine', connect=True)
	bone('Neck1', NECK_BASE, NECK_MID, 'Chest')
	bone('Neck2', NECK_MID, POLL, 'Neck1', connect=True)
	bone('Head', POLL, NOSE, 'Neck2', connect=True)
	bone('Jaw', head_point(0.07, 0.03), head_point(0.25, 0.032), 'Head')
	for s, suffix in ((1, 'L'), (-1, 'R')):
		base, direction, opening = ears[0 if s > 0 else 1]
		bone(f'Ear_{suffix}', base, base + direction * EAR_LEN * 0.9, 'Head')
		centre, gaze, up = eyes_at[0 if s > 0 else 1]
		bone(f'Lid_{suffix}', centre, centre + gaze * 0.04, 'Head')
		bone(f'Scapula_{suffix}', sided(BLADE, s), sided(SHOULDER, s), 'Chest')
		bone(f'UpperArm_{suffix}', sided(SHOULDER, s), sided(ELBOW, s), f'Scapula_{suffix}', connect=True)
		bone(f'Forearm_{suffix}', sided(ELBOW, s), sided(CARPUS, s), f'UpperArm_{suffix}', connect=True)
		bone(f'FrontCannon_{suffix}', sided(CARPUS, s), sided(FORE_FETLOCK, s), f'Forearm_{suffix}', connect=True)
		bone(f'FrontHoof_{suffix}', sided(FORE_FETLOCK, s), sided(FORE_TOE, s), f'FrontCannon_{suffix}', connect=True)
		bone(f'Thigh_{suffix}', sided(HIP, s), sided(STIFLE, s), 'Hips')
		bone(f'Shin_{suffix}', sided(STIFLE, s), sided(HOCK, s), f'Thigh_{suffix}', connect=True)
		bone(f'HindCannon_{suffix}', sided(HOCK, s), sided(HIND_FETLOCK, s), f'Shin_{suffix}', connect=True)
		bone(f'HindHoof_{suffix}', sided(HIND_FETLOCK, s), sided(HIND_TOE, s), f'HindCannon_{suffix}', connect=True)
	for b in eb:
		b.align_roll(Vector((0, 1, 0)) if abs(b.vector.normalized().z) > 0.7 else Vector((0, 0, 1)))
	bpy.ops.object.mode_set(mode='POSE')
	for pb in rig.pose.bones:
		pb.rotation_mode = 'QUATERNION'
	bpy.ops.object.mode_set(mode='OBJECT')
	rig['ear_axes'] = [list(e[1]) for e in ears]
	rig['lid_axes'] = [list(up.cross(gaze).normalized()) for _, gaze, up in eyes_at]
	return rig


# ---------------------------------------------------------------- weights

def segment_distance(p, a, b):
	ab = b - a
	t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
	return (p - (a + ab * t)).length


BODY_BONES = {  # bone: reach (larger claims more of the surface around it)
	'Hips': 1.5, 'Spine': 1.5, 'Chest': 1.4, 'Neck1': 1.1, 'Neck2': 1.1, 'Head': 1.2,
	'Scapula': 0.9, 'UpperArm': 0.85, 'Forearm': 0.6, 'Thigh': 0.95, 'Shin': 0.6,
}
LEG_BONES = {'F': ('UpperArm', 'Forearm', 'FrontCannon', 'FrontHoof'), 'H': ('Thigh', 'Shin', 'HindCannon', 'HindHoof')}


def weigh(rig, obj):
	bones = rig.data.bones
	groups = {b.name: obj.vertex_groups.new(name=b.name) for b in bones if b.use_deform}
	part_of = {}
	part = obj.data.attributes['part'].data
	for poly in obj.data.polygons:
		for v in poly.vertices:
			part_of[v] = part[poly.index].value
	seg = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in bones}

	def blend(p, names, power, reach=None):
		raw = []
		for name in names:
			d = segment_distance(p, *seg[name]) / (reach[name] if reach else 1.0)
			raw.append(1.0 / (d ** power + 1e-9))
		total = sum(raw)
		ws = [w / total for w in raw]
		ws = [w if w > 0.03 else 0.0 for w in ws]
		total = sum(ws)
		return {n: w / total for n, w in zip(names, ws) if w > 0}

	for v in obj.data.vertices:
		p, k = v.co, part_of.get(v.index, PART_BODY)
		if k == PART_BODY:
			names, reach = [], {}
			for base, r in BODY_BONES.items():
				if base in ('Scapula', 'UpperArm', 'Forearm', 'Thigh', 'Shin'):
					for s, suffix in ((1, 'L'), (-1, 'R')):
						if p.x * s > -0.025:
							names.append(f'{base}_{suffix}')
							reach[f'{base}_{suffix}'] = r
				else:
					names.append(base)
					reach[base] = r
			w = blend(p, names, 5, reach)
			# The lower jaw: the face below the mouth line, ahead of the cheek.
			if w.get('Head', 0) > 0.3:
				a, d, x = head_frame(p)
				jaw = smoothstep(0.018, 0.026, d) * smoothstep(0.07, 0.12, a)
				if jaw > 0:
					move = w['Head'] * jaw
					w['Head'] -= move
					w['Jaw'] = move
		elif k >= PART_LEG:
			leg_name = LEG_NAMES[k - PART_LEG]
			suffix = leg_name[0]
			w = blend(p, [f'{b}_{suffix}' for b in LEG_BONES[leg_name[1]]], 6)
		elif k == PART_EAR:
			w = {f'Ear_{"L" if p.x > 0 else "R"}': 1.0}
		elif k == PART_EYE:
			w = {'Head': 1.0}
		elif k == PART_LID:
			w = {f'Lid_{"L" if p.x > 0 else "R"}': 1.0}
		elif k == PART_TAIL:
			w = blend(p, ['Tail1', 'Tail2', 'Hips'], 6, {'Tail1': 1.0, 'Tail2': 1.0, 'Hips': 0.5})
		# Godot skins with four bones a vertex: keep the strongest four.
		top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
		total = sum(value for _, value in top)
		for name, value in top:
			if value > 0:
				groups[name].add([v.index], value / total, 'REPLACE')


# ---------------------------------------------------------------- preview

def setup_studio(engine='BLENDER_EEVEE'):
	scene = bpy.context.scene
	scene.render.engine = engine
	scene.render.resolution_x, scene.render.resolution_y = 640, 360
	scene.view_settings.view_transform = 'Standard'
	scene.render.fps = FPS
	world = bpy.data.worlds.new('Studio')
	world.use_nodes = True
	world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.42, 0.47, 0.54, 1)
	world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9
	world.color = (0.42, 0.47, 0.54)
	scene.world = world
	sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
	sun.data.energy, sun.data.color, sun.data.angle = 3.4, kit.srgb('fff0d8'), math.radians(4)
	sun.rotation_euler = (math.radians(52), 0, math.radians(-38))
	scene.collection.objects.link(sun)
	if engine == 'BLENDER_WORKBENCH':
		shading = scene.display.shading
		shading.light = 'STUDIO'
		shading.color_type = 'VERTEX'
		shading.show_shadows = True
		shading.shadow_intensity = 0.45
		shading.show_cavity = False
		scene.display.light_direction = (-0.45, 0.35, 0.82)
	else:
		scene.eevee.taa_render_samples = 16
	cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
	scene.collection.objects.link(cam)
	scene.camera = cam
	return cam


def stage(collection):
	bm = bmesh.new()
	bmesh.ops.create_grid(bm, x_segments=12, y_segments=12, size=10)
	for v in bm.verts:
		v.co.x += rng.uniform(-0.25, 0.25)
		v.co.y += rng.uniform(-0.25, 0.25)
	bmesh.ops.triangulate(bm, faces=bm.faces)
	floor = kit.to_object(bm, 'Floor', collection)
	green = Vector((0.11, 0.2, 0.07))
	kit.paint(floor, lambda p: green * rng.uniform(0.85, 1.12))
	floor.data.materials.append(kit.material('Floor', 1.0))


VIEWS = {  # location, target, vertical field of view (the game's camera is 45 degrees)
	'side': ((4.4, -0.15, 0.8), (0, -0.12, 0.64), 22),
	'three': ((2.4, -2.9, 1.5), (0, -0.12, 0.7), 24),
	'front': ((0.3, -3.8, 1.05), (0, -0.2, 0.8), 22),
	'back': ((-1.9, 2.8, 1.6), (0, 0.0, 0.7), 24),
	'head': ((1.1, -1.35, 1.3), (0, -0.62, 1.12), 18),
	'mid': ((3.7, -4.7, 4.3), (0, -0.1, 0.55), 22),
	'far': ((9.6, -11.2, 10.2), (0, 0, 0.5), 45),
}


def aim(cam, view):
	loc, target, fov = VIEWS[view]
	cam.location = Vector(loc)
	cam.data.sensor_fit = 'VERTICAL'
	cam.data.angle = math.radians(fov)
	cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()


# ---------------------------------------------------------------- main

def mark(obj, value):
	attr = obj.data.attributes.new('part', 'INT', 'FACE')
	for i in range(len(obj.data.polygons)):
		attr.data[i].value = value if not callable(value) else value(i)


def main():
	asset = kit.fresh_scene('EDIT - deer')
	body = build_body(asset)
	mark(body, PART_BODY)
	bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
	FAWN_SPOTS[:] = [bvh.find_nearest(spot)[0] for spot in FAWN_SPOTS]
	pieces = [body]
	# Legs: LF, RF, LH, RH, one object each so they carry their own part number.
	for i, name in enumerate(LEG_NAMES):
		bm = bmesh.new()
		leg(bm, name[1] == 'F', 1 if name[0] == 'L' else -1)
		obj = kit.to_object(bm, f'Leg{name}', asset)
		mark(obj, PART_LEG + i)
		pieces.append(obj)
	bm = bmesh.new()
	ears = [ear(bm, 1), ear(bm, -1)]
	obj = kit.to_object(bm, 'Ears', asset)
	mark(obj, PART_EAR)
	pieces.append(obj)
	bm = bmesh.new()
	tail(bm)
	obj = kit.to_object(bm, 'Tail', asset)
	mark(obj, PART_TAIL)
	pieces.append(obj)
	eye_bm, lid_bm, eyes_at = eyes(bvh)
	for bm, name, part in ((eye_bm, 'Eyes', PART_EYE), (lid_bm, 'Lids', PART_LID)):
		obj = kit.to_object(bm, name, asset)
		mark(obj, part)
		pieces.append(obj)
	for obj in pieces:
		m = obj.data
		bm = bmesh.new()
		bm.from_mesh(m)
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		bm.to_mesh(m)
		bm.free()
	bpy.ops.object.select_all(action='DESELECT')
	for obj in pieces:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = body
	bpy.ops.object.join()
	deer = body
	deer.name = deer.data.name = 'Deer'
	bm = bmesh.new()
	bm.from_mesh(deer.data)
	bmesh.ops.triangulate(bm, faces=bm.faces)
	bm.to_mesh(deer.data)
	bm.free()
	rig = build_rig(asset, eyes_at, ears)
	weigh(rig, deer)
	fawn = deer.copy()
	fawn.data = deer.data.copy()
	fawn.name = fawn.data.name = 'Fawn'
	asset.objects.link(fawn)
	paint(deer, False, eyes_at, ears)
	paint(fawn, True, eyes_at, ears)
	coat = kit.material('Deer coat', 0.9)
	for obj in (deer, fawn):
		obj.data.materials.append(coat)
		m = obj.modifiers.new('Armature', 'ARMATURE')
		m.object = rig
		obj.parent = rig
	fawn.hide_render = True
	rig['walk_speed_mps'] = clips.WALK_SPEED
	rig['walk_frames'] = clips.WALK_FRAMES
	rig['height_m'] = max(v.co.z for v in deer.data.vertices)
	if '--no-anim' not in ARGS:
		clips.bake_all(rig)
	clips.reset(rig)
	bpy.context.scene.render.fps = FPS

	blend = ROOT / 'art/blender/creatures/zenscape-deer.blend'
	glb = ROOT / 'assets/models/zenscape-deer.glb'
	blend.parent.mkdir(parents=True, exist_ok=True)
	previews = bpy.data.collections.new('PREVIEW - stage')
	bpy.context.scene.collection.children.link(previews)
	stage(previews)
	bpy.ops.wm.save_as_mainfile(filepath=str(blend))
	fawn.hide_render = False
	bpy.ops.object.select_all(action='DESELECT')
	for obj in (rig, deer, fawn):
		obj.select_set(True)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True,
		export_animations='--no-anim' not in ARGS, export_animation_mode='ACTIONS', export_force_sampling=True,
		export_def_bones=True, export_cameras=False, export_lights=False, export_extras=True,
		export_yup=True, export_vertex_color='ACTIVE', export_skins=True)
	fawn.hide_render = True
	print('DEER_EXPORT', glb, 'faces', len(deer.data.polygons), 'height', round(rig['height_m'], 3),
		'walk_speed', clips.WALK_SPEED, 'bones', sum(1 for b in rig.data.bones if b.use_deform))
	if '--no-render' in ARGS:
		return
	cam = setup_studio('BLENDER_WORKBENCH')
	out = Path('/tmp/zs-deer-previews/rest')
	out.mkdir(parents=True, exist_ok=True)
	for who in ('doe', 'fawn'):
		deer.hide_render = who == 'fawn'
		fawn.hide_render = who == 'doe'
		for view in (('side', 'three', 'front', 'back', 'head') if who == 'doe' else ('side', 'three')):
			aim(cam, view)
			bpy.context.scene.render.filepath = str(out / f'{who}-{view}.png')
			bpy.ops.render.render(write_still=True)
	print('DEER_RENDERS', out)


if __name__ == '__main__':
	main()
