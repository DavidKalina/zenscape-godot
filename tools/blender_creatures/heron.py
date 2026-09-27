"""Grey heron: one skinned, faceted mesh on a small rig; clips come from heron_clips.py.

Run: blender -b --python tools/blender_creatures/heron.py -- [--no-render] [--no-anim]

The body, neck and head are one metaball family converted to a mesh and decimated into
large facets like the ambient Bigfoot. The dagger bill, eyes, crest, breast plumes, legs,
toes and every wing feather are built as faceted plates on top, each rigidly weighted to
its own bone, so a wing folds feather by feather instead of bending like cloth.
Saves art/blender/creatures/zenscape-heron.blend, exports assets/models/zenscape-heron.glb
and renders rest views to /tmp/zs-heron-previews/rest/ (clips: heron_review.py).
Metres, origin between the feet, Blender Z-up, facing -Y (Godot +Z after export). The
proportions follow the code-built heron in scripts/life_models.gd: hips 0.72 m up, crown
about 1.3 m, bill tip about 0.36 m ahead of the feet.
"""
import bpy, bmesh, math, random, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, noise
from mathutils.kdtree import KDTree

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'blender_trees'))
sys.path.insert(0, str(HERE.parent / 'blender_bigfoot'))
sys.path.insert(0, str(HERE))
import kit
from kit import srgb, mix
import heron_clips as clips

ROOT = kit.ROOT
ARGS = kit.ARGS
FPS = clips.FPS
rng = random.Random(11)
kit.rng.seed(11)

# ---------------------------------------------------------------- landmarks
# Left side (+X); the right side mirrors. The body leans about 26 degrees, breast up.
HIP = Vector((0.05, 0.05, 0.72))
ANKLE = Vector((0.056, 0.105, 0.37))  # the backward "knee" is the ankle
FOOT = Vector((0.06, 0.02, 0.034))
TOE = Vector((0.06, -0.08, 0.01))
SHOULDER = Vector((0.07, -0.03, 0.905))
ELBOW = Vector((0.28, -0.005, 0.905))
WRIST = Vector((0.53, -0.03, 0.905))
TIP = Vector((0.71, -0.012, 0.905))
# The neck rests in a deep S; laid straight it is long enough to take the bill to the water.
NECK = [Vector((0, -0.07, 0.915)), Vector((0, -0.205, 1.005)), Vector((0, -0.085, 1.125)), Vector((0, -0.135, 1.245))]
SKULL = Vector((0, -0.163, 1.268))
EYE = Vector((0.02, -0.182, 1.276))
EYE_R = 0.0085
GAPE = Vector((0, -0.197, 1.256))
BILL_TIP = Vector((0, -0.39, 1.234))
CREST = Vector((0, -0.128, 1.29))
PLUMES = Vector((0, -0.232, 0.985))
BODY_TILT = math.atan2(0.15, 0.31)

GREY = srgb('8b95a0')
GREY_LIGHT = srgb('aab2bb')
GREY_DARK = srgb('59606a')
BLACK = srgb('24272c')
WHITE = srgb('e4e4df')
NECK_GREY = srgb('c3c7ca')
BELLY = srgb('d2d4d2')
BILL = srgb('d9a33a')
BILL_DARK = srgb('8f7236')
LEG = srgb('76683f')
IRIS = srgb('e6c43a')
PUPIL = srgb('131313')
SILVER = srgb('b9c2c4')


def mirror(v):
	return Vector((-v.x, v.y, v.z))


def sided(v, s):
	return Vector(v) if s > 0 else mirror(Vector(v))


def jitter(c, amount=0.04):
	return c * (1 + rng.uniform(-amount, amount))


# ---------------------------------------------------------------- body
SURFACE = 0.575  # surface radius of a lone ball per unit of influence radius
TARGET_FACES = 720


def ball(mb, co, r, stiffness=2.0):
	e = mb.elements.new(type='BALL')
	e.co, e.radius, e.stiffness = co, r / SURFACE, stiffness
	return e


def ellipsoid(mb, co, axes, tilt=0.0, stiffness=2.0):
	r = max(axes)
	e = mb.elements.new(type='ELLIPSOID')
	e.co, e.radius, e.stiffness = co, r / SURFACE, stiffness
	e.size_x, e.size_y, e.size_z = axes[0] / r, axes[1] / r, axes[2] / r
	if tilt:
		e.rotation = Quaternion((1, 0, 0), -tilt)
	return e


def neck_curve(t):
	"""Point on the resting neck's S from its base (0) to the head joint (1)."""
	pts = NECK
	x = t * (len(pts) - 1)
	i = min(int(x), len(pts) - 2)
	u = x - i
	p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
	return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)


def build_body(collection):
	mb = bpy.data.metaballs.new('BodyBall')
	mb.resolution = mb.render_resolution = 0.009
	mb.threshold = 0.6
	obj = bpy.data.objects.new('BodyBall', mb)
	collection.objects.link(obj)
	# A long, leaning teardrop: a full breast, the back sloping to a short tail.
	ellipsoid(mb, (0, -0.045, 0.852), (0.094, 0.105, 0.115), BODY_TILT)
	ellipsoid(mb, (0, 0.07, 0.806), (0.11, 0.18, 0.106), BODY_TILT)
	ellipsoid(mb, (0, 0.215, 0.738), (0.075, 0.13, 0.058), BODY_TILT)
	ellipsoid(mb, (0, 0.07, 0.752), (0.08, 0.12, 0.066), BODY_TILT)
	# The neck: thick with plumes at the base, slender under the head.
	for i in range(19):
		t = i / 18
		r = 0.047 - 0.02 * min(1.0, t / 0.45) - 0.003 * max(0.0, t - 0.45)
		ball(mb, neck_curve(t), r)
	# Head: a small, flat-crowned wedge that runs straight into the bill.
	ellipsoid(mb, SKULL, (0.028, 0.05, 0.03))
	ellipsoid(mb, SKULL + Vector((0, -0.032, -0.006)), (0.02, 0.03, 0.022))
	ellipsoid(mb, SKULL + Vector((0, 0.022, -0.012)), (0.024, 0.03, 0.024))
	dg = bpy.context.evaluated_depsgraph_get()
	mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
	bpy.data.objects.remove(obj)
	bpy.data.metaballs.remove(mb)
	mesh.name = 'Body'
	body = bpy.data.objects.new('Body', mesh)
	collection.objects.link(body)
	dec = body.modifiers.new('Facets', 'DECIMATE')
	dec.ratio = TARGET_FACES / max(1, len(mesh.polygons))
	bpy.context.view_layer.objects.active = body
	bpy.ops.object.modifier_apply(modifier=dec.name)
	bm = bmesh.new()
	bm.from_mesh(body.data)
	bmesh.ops.triangulate(bm, faces=bm.faces)
	for v in bm.verts:
		v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.0025
	bm.to_mesh(body.data)
	bm.free()
	return body


# ---------------------------------------------------------------- colour

def body_colour(poly):
	p, n = poly.center, poly.normal
	x, ax = p.x, abs(p.x)
	if p.z > 1.2 and p.y < -0.08:
		return head_colour(p, n)
	if p.z > 0.93 or (p.y < -0.06 and p.z > 0.9 and n.y < -0.2):
		# Neck: white in front with a dark streaked stripe, grey-washed behind.
		front = n.y < -0.35
		if front and ax < 0.02 and p.z < 1.16 and noise.noise(Vector((x * 60, 0, p.z * 38))) > 0.05:
			return jitter(mix(WHITE, BLACK, 0.8))
		if front:
			return jitter(WHITE, 0.03)
		return jitter(mix(NECK_GREY, WHITE, 0.35 + 0.3 * max(0.0, -n.y)), 0.03)
	# Body. The upper flanks read as the folded wing; the breast is pale with a black patch
	# at the bend of the wing and a black stripe down the side; underneath is pale grey.
	if -0.13 < p.y < -0.075 and ax > 0.055 and 0.86 < p.z < 0.92 and abs(n.x) > 0.6:
		return jitter(mix(BLACK, GREY_DARK, 0.3), 0.05)
	if p.y < -0.03 and n.y < -0.25 and n.z > -0.55:
		return jitter(mix(WHITE, BELLY, 0.4), 0.03)
	if n.z < -0.35 or p.z < 0.72 - 0.25 * (p.y - 0.05):
		return jitter(BELLY, 0.04)
	shade = 0.94 + 0.1 * max(0.0, n.z) + 0.05 * noise.noise(p * 14)
	return mix(GREY, GREY_LIGHT, 0.25 * max(0.0, n.z)) * shade


def head_colour(p, n):
	ax = abs(p.x)
	# The black stripe from above the eye back to the nape and into the crest.
	if p.z > EYE.z - 0.005 and p.y > EYE.y - 0.006 and ax > 0.012 and n.z < 0.85:
		return jitter(BLACK, 0.05)
	if p.y > SKULL.y + 0.035 and p.z > SKULL.z - 0.01:
		return jitter(BLACK, 0.05)
	return jitter(WHITE, 0.03)


# ---------------------------------------------------------------- plates

def feather(bm, base, direction, length, width, normal, camber=0.15, thick=0.006, tip=0.35):
	"""A faceted feather: a shallow inverted V along its shaft, rounded at the tip.
	Returns its new faces, top first."""
	d = Vector(direction).normalized()
	n = Vector(normal)
	n = (n - d * n.dot(d)).normalized()
	s = n.cross(d).normalized()
	stations = [(0.0, 0.34), (0.55, 0.5), (0.86, tip), (1.0, 0.0)]
	outline_l, outline_r, ridge_t, ridge_b = [], [], [], []
	for f, w in stations:
		c = Vector(base) + d * length * f
		droop = -n * width * camber * w
		if w > 0:
			outline_l.append(bm.verts.new(c + s * width * w + droop))
			outline_r.append(bm.verts.new(c - s * width * w + droop))
		else:
			tip_v = bm.verts.new(c + droop * 0)
			outline_l.append(tip_v)
			outline_r.append(tip_v)
		if f < 1.0:
			ridge_t.append(bm.verts.new(c + n * thick))
			ridge_b.append(bm.verts.new(c - n * thick * 0.6))
		else:
			ridge_t.append(tip_v)
			ridge_b.append(tip_v)
	top, bottom = [], []
	for i in range(len(stations) - 1):
		for out, flip in ((outline_l, False), (outline_r, True)):
			quad = [ridge_t[i], out[i], out[i + 1], ridge_t[i + 1]]
			bquad = [ridge_b[i], ridge_b[i + 1], out[i + 1], out[i]]
			if flip:
				quad.reverse()
				bquad.reverse()
			for q, bucket in ((quad, top), (bquad, bottom)):
				verts = []
				for v in q:
					if v not in verts:
						verts.append(v)
				if len(verts) >= 3:
					bucket.append(bm.faces.new(verts))
	# Close the base.
	for out, a, b in ((outline_l, ridge_t[0], ridge_b[0]), (outline_r, ridge_b[0], ridge_t[0])):
		bottom.append(bm.faces.new((a, out[0], b) if out is outline_l else (a, out[0], b)))
	return top, bottom


def covert(bm, a, b, chord, normal, lift=0.012, lead=0.022, width=(1.0, 1.0)):
	"""A covert slab over a wing segment from a to b: a thick rounded leading edge that
	thins back over the feathers. chord points back across the wing."""
	a, b, chord, n = Vector(a), Vector(b), Vector(chord).normalized(), Vector(normal).normalized()
	rows = []
	for t, w in ((0.0, width[0]), (0.5, (width[0] + width[1]) / 2), (1.0, width[1])):
		c = a.lerp(b, t)
		rows.append([bm.verts.new(c - chord * lead * w), bm.verts.new(c + n * lift * 1.5 - chord * lead * 0.2 * w),
			bm.verts.new(c + n * lift + chord * 0.08 * w), bm.verts.new(c + n * lift * 0.4 + chord * 0.13 * w),
			bm.verts.new(c - n * lift * 0.5 + chord * 0.05 * w)])
	faces = []
	for r0, r1 in zip(rows, rows[1:]):
		for k in range(5):
			faces.append(bm.faces.new((r0[k], r0[(k + 1) % 5], r1[(k + 1) % 5], r1[k])))
	faces.append(bm.faces.new(list(reversed(rows[0]))))
	faces.append(bm.faces.new(rows[-1]))
	return faces


def islands_of(bm):
	seen, out = set(), []
	for v in bm.verts:
		if v.index in seen:
			continue
		stack, island = [v], []
		seen.add(v.index)
		while stack:
			cur = stack.pop()
			island.append(cur.index)
			for e in cur.link_edges:
				o = e.other_vert(cur)
				if o.index not in seen:
					seen.add(o.index)
					stack.append(o)
		out.append(island)
	return out


class Part:
	"""A detail mesh built in bmesh with a colour and a weighting per face group."""

	def __init__(self, name):
		self.name = name
		self.bm = bmesh.new()
		self.colours = {}
		self.weights = {}  # vertex index -> {bone: weight}

	def paint(self, faces, colour, amount=0.04):
		for f in faces:
			self.colours[f] = jitter(colour, amount)

	def bind(self, verts, weights):
		for v in verts:
			self.weights[v] = dict(weights)

	def new_verts(self, since):
		self.bm.verts.ensure_lookup_table()
		return [v for v in self.bm.verts[since:]]

	def mark(self):
		self.bm.verts.ensure_lookup_table()
		return len(self.bm.verts)


def feather_specs():
	"""(bone, parent, base, direction, length, width, colour, underside) for the left wing."""
	specs = []
	for i, (t, lean, length) in enumerate(((0.1, 2, 0.3), (0.36, 5, 0.3), (0.62, 9, 0.29), (0.88, 14, 0.28))):
		a = math.radians(lean)
		specs.append((f'Sec{i + 1}', 'Forewing', ELBOW.lerp(WRIST, t) + Vector((0, 0.008, 0)),
			Vector((math.sin(a), math.cos(a), 0)), length, 0.1, GREY_DARK, GREY))
	for i, (t, angle, length, width) in enumerate(((0.08, 24, 0.31, 0.082), (0.3, 38, 0.34, 0.08),
			(0.52, 52, 0.36, 0.076), (0.74, 66, 0.36, 0.07), (0.96, 80, 0.33, 0.064))):
		a = math.radians(angle)
		specs.append((f'Prim{i + 1}', 'Hand', WRIST.lerp(TIP, t) + Vector((0, 0.004, 0)),
			Vector((math.sin(a), math.cos(a), 0)), length, width, BLACK, GREY_DARK))
	return specs


TERTIALS = ((0.34, -12, 0.25), (0.7, -4, 0.27))


def build_wings(part):
	"""Both wings, spread flat in the rest pose. Each flight feather is its own island bound
	to its own bone; the coverts ride the arm, forearm and hand."""
	up = Vector((0, 0, 1))
	for s, suffix in ((1, 'L'), (-1, 'R')):
		for bone, parent, base, d, length, width, colour, under in feather_specs():
			mark = part.mark()
			top, bottom = feather(part.bm, sided(base, s), sided(d, s), length, width, up)
			part.paint(top, colour)
			part.paint(bottom, under)
			part.bind(part.new_verts(mark), {f'{bone}_{suffix}': 1.0})
		for t, lean, length in TERTIALS:
			a = math.radians(lean)
			mark = part.mark()
			base = SHOULDER.lerp(ELBOW, t) + Vector((0, 0.01, 0.004))
			top, bottom = feather(part.bm, sided(base, s), sided(Vector((math.sin(a), math.cos(a), 0)), s), length, 0.1, up)
			part.paint(top, GREY)
			part.paint(bottom, GREY_LIGHT)
			part.bind(part.new_verts(mark), {f'Tert_{suffix}': 1.0})
		for bone, a, b, width, colour in (('UpperWing', SHOULDER + Vector((-0.02, 0, 0)), ELBOW + Vector((0.02, 0, 0)), (1.2, 1.0), GREY),
				('Forewing', ELBOW + Vector((-0.02, 0, 0)), WRIST + Vector((0.02, 0, 0)), (1.0, 0.9), GREY),
				('Hand', WRIST + Vector((-0.02, 0, 0)), TIP + Vector((-0.02, 0, 0)), (0.9, 0.55), GREY_DARK)):
			mark = part.mark()
			faces = covert(part.bm, sided(a, s), sided(b, s), (0, 1, 0), up, width=width)
			part.paint(faces, colour)
			# The white leading edge at the bend of the wing.
			for f in faces:
				c = f.calc_center_median()
				if bone == 'Forewing' and (c - sided(WRIST, s)).length < 0.09 and c.y < sided(WRIST, s).y:
					part.colours[f] = jitter(WHITE, 0.03)
			part.bind(part.new_verts(mark), {f'{bone}_{suffix}': 1.0})


def build_legs(part):
	for s, suffix in ((1, 'L'), (-1, 'R')):
		hip, ankle, foot = sided(HIP, s), sided(ANKLE, s), sided(FOOT, s)
		mark = part.mark()
		pts = [hip + Vector((0, 0, 0.03)), hip.lerp(ankle, 0.35), hip.lerp(ankle, 0.75), ankle, ankle.lerp(foot, 0.5), foot]
		rings = kit.tube(part.bm, pts, [0.022, 0.017, 0.012, 0.012, 0.0095, 0.009], 5, gnarl=0.03)
		faces = list({f for ring in rings for v in ring for f in v.link_faces})
		part.paint(faces, LEG, 0.05)
		verts = part.new_verts(mark)
		# Distance weights over the ankle, like the Bigfoot arms.
		segs = ((f'Tibia_{suffix}', hip, ankle), (f'Tarsus_{suffix}', ankle, foot))
		for v in verts:
			raw = []
			for name, a, b in segs:
				ab = b - a
				t = max(0.0, min(1.0, (v.co - a).dot(ab) / ab.length_squared))
				raw.append(1.0 / ((v.co - (a + ab * t)).length ** 6 + 1e-12))
			total = sum(raw)
			ws = {name: w / total for (name, _, _), w in zip(segs, raw) if w / total > 0.05}
			norm = sum(ws.values())
			part.weights[v] = {k: w / norm for k, w in ws.items()}
		# Three long front toes and a hind toe, flat on the ground.
		mark = part.mark()
		for angle, length in ((-30, 0.085), (0, 0.1), (30, 0.085), (180, 0.05)):
			a = math.radians(angle)
			d = Vector((math.sin(a) * s, -math.cos(a), 0))
			start = foot + Vector((0, 0, -0.02))
			kit.tube(part.bm, [start, start + d * length * 0.55 + Vector((0, 0, -0.008)), start + d * length + Vector((0, 0, -0.013))],
				[0.0075, 0.006, 0.004], 3, gnarl=0.02)
		verts = part.new_verts(mark)
		faces = list({f for v in verts for f in v.link_faces})
		part.paint(faces, mix(LEG, BLACK, 0.2), 0.05)
		part.bind(verts, {f'Toes_{suffix}': 1.0})


def build_head_details(part):
	# The dagger bill: upper mandible on the head, lower on the jaw.
	# The mandibles meet a hair apart and the lower is a touch narrower, so they never
	# share a plane (a shared plane shimmers).
	for bone, z0, z1, colour, w in (('Head', 0.0, 0.017, BILL, 1.0), ('Jaw', -0.017, -0.0025, mix(BILL, WHITE, 0.15), 0.85)):
		mark = part.mark()
		base = GAPE + Vector((0, 0.012, 0))
		tip = BILL_TIP + Vector((0, 0, 0.004 if bone == 'Head' else -0.002))
		ring = []
		for k, (x, z) in enumerate(((0.0, z1), (0.0135 * w, (z0 + z1) / 2), (0.0, z0), (-0.0135 * w, (z0 + z1) / 2))):
			ring.append(part.bm.verts.new(base + Vector((x, 0, z))))
		mid = []
		for x, z in ((0.0, z1 * 0.8), (0.009 * w, (z0 + z1) / 2 * 0.8), (0.0, z0 * 0.8), (-0.009 * w, (z0 + z1) / 2 * 0.8)):
			mid.append(part.bm.verts.new(base.lerp(tip, 0.55) + Vector((x, 0, z - 0.004))))
		t = part.bm.verts.new(tip)
		faces = []
		for k in range(4):
			faces.append(part.bm.faces.new((ring[k], ring[(k + 1) % 4], mid[(k + 1) % 4], mid[k])))
			faces.append(part.bm.faces.new((mid[k], mid[(k + 1) % 4], t)))
		faces.append(part.bm.faces.new(list(reversed(ring))))
		part.paint(faces, colour, 0.04)
		for f in faces:  # a darker ridge along the culmen
			if bone == 'Head' and f.calc_center_median().z > GAPE.z + 0.006 and f.normal.z > 0.5:
				part.colours[f] = jitter(mix(colour, BILL_DARK, 0.45))
		part.bind(part.new_verts(mark), {bone: 1.0})
	# Eyes: a yellow iris round a black pupil, with a lid bone to blink.
	for s, suffix in ((1, 'L'), (-1, 'R')):
		c = sided(EYE, s)
		mark = part.mark()
		ico = bmesh.ops.create_icosphere(part.bm, subdivisions=1, radius=EYE_R)
		for v in ico['verts']:
			v.co += c
		faces = list({f for v in ico['verts'] for f in v.link_faces})
		for f in faces:
			out = (f.calc_center_median() - c).normalized()
			part.colours[f] = PUPIL if out.dot(Vector((s * 0.85, -0.5, 0.1)).normalized()) > 0.8 else IRIS
		part.bind(part.new_verts(mark), {'Head': 1.0})
		mark = part.mark()
		rows, cols, cap = 3, 8, math.radians(82)
		grid = []
		for i in range(rows + 1):
			theta = cap * i / rows
			ring = []
			for j in range(cols):
				phi = math.tau * j / cols
				d = Vector((math.sin(theta) * math.cos(phi), math.sin(theta) * math.sin(phi), math.cos(theta)))
				d = Matrix.Rotation(math.radians(-35 * s), 3, 'Y') @ d  # open: over the top, tipped in
				ring.append(part.bm.verts.new(c + d * EYE_R * 1.2))
			grid.append(ring)
		faces = []
		for a, b in zip(grid, grid[1:]):
			for j in range(cols):
				faces.append(part.bm.faces.new((a[j], a[(j + 1) % cols], b[(j + 1) % cols], b[j])))
		part.paint(faces, WHITE, 0.02)
		part.bind(part.new_verts(mark), {f'Lid_{suffix}': 1.0})
	# The crest: two long black plumes from the nape, one a little shorter.
	c1 = CREST
	for lean, length, width in ((0.005, 0.2, 0.014), (-0.006, 0.16, 0.011)):
		mark = part.mark()
		d = Vector((lean, 1.0, -0.22)).normalized()
		top, bottom = feather(part.bm, c1 + Vector((lean * 2, 0, 0)), d, length, width, Vector((0, 0.2, 1)), camber=0.1, thick=0.003, tip=0.4)
		part.paint(top + bottom, BLACK)
		for v in part.new_verts(mark):
			u = (v.co - c1).dot(d) / 0.07
			w2 = max(0.0, min(1.0, u - 0.4))
			part.weights[v] = {'Crest1': 1 - w2, 'Crest2': w2} if w2 > 0 else {'Crest1': 1.0}
	# Breast plumes hanging over the chest.
	for dx, length in ((0.0, 0.15), (0.016, 0.12), (-0.016, 0.125), (0.008, 0.1), (-0.008, 0.11)):
		mark = part.mark()
		base = PLUMES + Vector((dx, 0, 0))
		top, bottom = feather(part.bm, base, Vector((dx * 3, 0.25, -1)), length, 0.028, Vector((0, -1, 0.25)), camber=0.15, thick=0.003, tip=0.25)
		part.paint(top + bottom, mix(WHITE, NECK_GREY, 0.5))
		part.bind(part.new_verts(mark), {'Plumes': 1.0})
	# A short tail under the wingtips.
	mark = part.mark()
	top, bottom = feather(part.bm, Vector((0, 0.27, 0.735)), Vector((0, 0.9, -0.3)), 0.17, 0.07, Vector((0, 0.3, 1)), camber=0.2, thick=0.006)
	part.paint(top, GREY_DARK)
	part.paint(bottom, GREY)
	part.bind(part.new_verts(mark), {'Tail': 1.0})
	# The catch: a small silver fish held across the bill tip, hidden until a strike lands.
	mark = part.mark()
	fish_c = Vector((0, BILL_TIP.y + 0.035, BILL_TIP.z - 0.002))
	kit.tube(part.bm, [fish_c + Vector((-0.045, 0, 0)), fish_c + Vector((-0.01, 0, 0.002)), fish_c + Vector((0.03, 0, 0))],
		[0.004, 0.011, 0.005], 5, gnarl=0.02)
	verts = part.new_verts(mark)
	tail = [part.bm.verts.new(fish_c + Vector((0.03, 0, 0))), part.bm.verts.new(fish_c + Vector((0.05, 0, 0.012))),
		part.bm.verts.new(fish_c + Vector((0.05, 0, -0.012)))]
	f = part.bm.faces.new(tail)
	verts += tail
	faces = list({f for v in verts for f in v.link_faces})
	part.paint(faces, SILVER, 0.08)
	part.bind(verts, {'Catch': 1.0})


def encode_srgb(obj):
	"""Store the colours sRGB-encoded. The life creatures in life_models.gd hand their
	colours to the shared surface shader as plain sRGB numbers, and Godot keeps glTF vertex
	colours as they are, so this makes the same hex read the same in game."""
	attr = obj.data.color_attributes['Col']
	for item in attr.data:
		c = item.color
		item.color = (*(to_srgb(x) for x in c[:3]), c[3])


def to_srgb(x):
	x = max(0.0, x)
	return 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055


def preview_material():
	"""Vertex colours decoded back to linear for Blender's own renders."""
	mat = kit.material('Heron', 0.9)
	nodes, links = mat.node_tree.nodes, mat.node_tree.links
	gamma = nodes.new('ShaderNodeGamma')
	gamma.inputs['Gamma'].default_value = 2.2
	links.new(nodes['Color Attribute'].outputs['Color'] if 'Color Attribute' in nodes else
		[n for n in nodes if n.type == 'VERTEX_COLOR'][0].outputs['Color'], gamma.inputs['Color'])
	links.new(gamma.outputs['Color'], nodes['Principled BSDF'].inputs['Base Color'])
	return mat


# ---------------------------------------------------------------- rig

def build_rig(collection):
	arm_data = bpy.data.armatures.new('HeronRig')
	rig = bpy.data.objects.new('HeronRig', arm_data)
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

	bone('Root', (0, 0, 0), (0, 0.3, 0), deform=False)
	bone('Body', (0, 0.06, 0.745), (0, -0.06, 0.86), 'Root')
	bone('Tail', (0, 0.27, 0.735), (0, 0.42, 0.685), 'Body')
	bone('Neck1', NECK[0], NECK[1], 'Body')
	bone('Neck2', NECK[1], NECK[2], 'Neck1', connect=True)
	bone('Neck3', NECK[2], NECK[3], 'Neck2', connect=True)
	bone('Head', NECK[3], (0, -0.225, 1.266), 'Neck3', connect=True)
	bone('Jaw', GAPE, BILL_TIP + Vector((0, 0.01, -0.006)), 'Head')
	bone('Catch', BILL_TIP + Vector((0, 0.035, -0.002)), BILL_TIP + Vector((0, 0.035, -0.04)), 'Head')
	bone('Crest1', CREST, CREST + Vector((0, 0.069, -0.012)), 'Head')
	bone('Crest2', CREST + Vector((0, 0.069, -0.012)), CREST + Vector((0, 0.19, -0.04)), 'Crest1', connect=True)
	bone('Plumes', PLUMES, PLUMES + Vector((0, 0.03, -0.12)), 'Neck1')
	for s, suffix in ((1, 'L'), (-1, 'R')):
		e = sided(EYE, s)
		bone(f'Lid_{suffix}', e, e + Vector((0, -0.02, 0)), 'Head')
		bone(f'UpperWing_{suffix}', sided(SHOULDER, s), sided(ELBOW, s), 'Body')
		bone(f'Forewing_{suffix}', sided(ELBOW, s), sided(WRIST, s), f'UpperWing_{suffix}', connect=True)
		bone(f'Hand_{suffix}', sided(WRIST, s), sided(TIP, s), f'Forewing_{suffix}', connect=True)
		for name, parent, base, d, length, *_ in feather_specs():
			bone(f'{name}_{suffix}', sided(base, s), sided(base + d * length, s), f'{parent}_{suffix}')
		t0, t1 = TERTIALS[0][0], TERTIALS[1][0]
		base = SHOULDER.lerp(ELBOW, (t0 + t1) / 2) + Vector((0, 0.01, 0.004))
		bone(f'Tert_{suffix}', sided(base, s), sided(base + Vector((-0.035, 0.26, 0)), s), f'UpperWing_{suffix}')
		bone(f'Tibia_{suffix}', sided(HIP, s), sided(ANKLE, s), 'Body')
		bone(f'Tarsus_{suffix}', sided(ANKLE, s), sided(FOOT, s), f'Tibia_{suffix}', connect=True)
		bone(f'Toes_{suffix}', sided(FOOT, s), sided(TOE, s), f'Tarsus_{suffix}', connect=True)
		# Same head, tail and roll as the toes: the toes copy this control's rotation.
		bone(f'FootIK_{suffix}', sided(FOOT, s), sided(TOE, s), 'Root', deform=False)
		bone(f'AnklePole_{suffix}', sided(ANKLE, s) + Vector((0, 0.6, 0)), sided(ANKLE, s) + Vector((0, 0.7, 0)), 'Root', deform=False)
	# Consistent rolls: local Z points back (+Y) on upright bones and up on level ones.
	for b in eb:
		b.align_roll(Vector((0, 1, 0)) if abs(b.vector.normalized().z) > 0.5 else Vector((0, 0, 1)))
	bpy.ops.object.mode_set(mode='POSE')
	for suffix in ('L', 'R'):
		c = rig.pose.bones[f'Tarsus_{suffix}'].constraints.new('IK')
		c.name = 'LegIK'
		c.target, c.subtarget = rig, f'FootIK_{suffix}'
		c.pole_target, c.pole_subtarget = rig, f'AnklePole_{suffix}'
		c.pole_angle = math.radians(clips.POLE_ANGLE)
		c.chain_count = 2
		c = rig.pose.bones[f'Toes_{suffix}'].constraints.new('COPY_ROTATION')
		c.name = 'ToesIK'
		c.target, c.subtarget = rig, f'FootIK_{suffix}'
	for pb in rig.pose.bones:
		pb.rotation_mode = 'QUATERNION'
	bpy.ops.object.mode_set(mode='OBJECT')
	return rig


CORE_BONES = ('Body', 'Tail', 'Neck1', 'Neck2', 'Neck3', 'Head')


def skin(rig, body, part_obj, part):
	"""Heat weights for the body from the trunk, neck and head bones only; every detail
	vertex takes the weights its part gave it."""
	deform = [b.name for b in rig.data.bones if b.use_deform]
	for b in rig.data.bones:
		b.use_deform = b.name in CORE_BONES
	bpy.ops.object.select_all(action='DESELECT')
	body.select_set(True)
	rig.select_set(True)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.parent_set(type='ARMATURE_AUTO')
	for b in rig.data.bones:
		b.use_deform = b.name in deform
	for name in deform:
		if name not in body.vertex_groups:
			body.vertex_groups.new(name=name)
		part_obj.vertex_groups.new(name=name)
	for index, weights in part.weights.items():
		for name, w in weights.items():
			part_obj.vertex_groups[name].add([index], w, 'REPLACE')
	missing = [v.index for v in part_obj.data.vertices if not v.groups]
	assert not missing, f'{len(missing)} detail vertices have no bone'
	return deform


# ---------------------------------------------------------------- preview

def stage(collection):
	bm = bmesh.new()
	bmesh.ops.create_grid(bm, x_segments=2, y_segments=2, size=14)
	floor = kit.to_object(bm, 'Floor', collection)
	kit.paint(floor, lambda p: srgb('7d8a7f'))
	floor.data.materials.append(kit.material('Floor', 1.0))


def setup_studio(scale=1.0):
	scene = bpy.context.scene
	scene.render.engine = 'BLENDER_EEVEE'
	scene.render.resolution_x, scene.render.resolution_y = 640, 360
	scene.render.resolution_percentage = int(100 * scale)
	scene.eevee.taa_render_samples = 16
	scene.view_settings.view_transform = 'Standard'
	scene.render.fps = FPS
	world = bpy.data.worlds.new('Studio')
	world.use_nodes = True
	world.node_tree.nodes['Background'].inputs['Color'].default_value = (*srgb('9aa6b4'), 1)
	world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9
	scene.world = world
	sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
	sun.data.energy, sun.data.color, sun.data.angle = 3.4, srgb('fff0d8'), math.radians(4)
	sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
	scene.collection.objects.link(sun)
	cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
	scene.collection.objects.link(cam)
	scene.camera = cam


def aim_camera(loc, target, lens):
	cam = bpy.context.scene.camera
	cam.location = Vector(loc)
	cam.data.lens = lens
	cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()


# The in-game camera sits about 43 m out at 25 degrees up with a ~45 degree field of view.
VIEWS = {
	'hero': ((2.2, -3.0, 1.5), (0, 0, 0.75), 45),
	'side': ((3.6, 0.0, 0.85), (0, 0.02, 0.75), 45),
	'front': ((0.0, -3.6, 0.95), (0, 0, 0.75), 45),
	'back': ((-1.8, 3.0, 1.4), (0, 0, 0.75), 45),
	'top': ((0.0, 0.05, 4.5), (0, 0.05, 0.6), 45),
	'head': ((0.9, -1.2, 1.42), (0, -0.2, 1.24), 80),
	'body': ((1.6, -0.35, 1.05), (0, 0.08, 0.82), 55),
	'bodyback': ((-0.9, 1.3, 1.5), (0, 0.1, 0.82), 50),
	'mid': ((5.5, -12.0, 5.5), (0, 0, 0.7), 45),
	'far': ((14.0, -37.0, 18.0), (0, 0, 0.7), 45),
}


def render_views(views, folder):
	scene = bpy.context.scene
	out = Path('/tmp/zs-heron-previews') / folder
	out.mkdir(parents=True, exist_ok=True)
	for view, (loc, target, lens) in views.items():
		aim_camera(loc, target, lens)
		scene.render.filepath = str(out / f'{view}.png')
		bpy.ops.render.render(write_still=True)
	print('HERON_RENDERS', out)


# ---------------------------------------------------------------- main

def main():
	asset = kit.fresh_scene('EDIT - heron')
	body = build_body(asset)
	kit.paint(body, body_colour)
	part = Part('Details')
	build_wings(part)
	build_legs(part)
	build_head_details(part)
	part.bm.verts.ensure_lookup_table()
	part.bm.verts.index_update()
	weights = {v.index: w for v, w in part.weights.items()}
	colours = {f: c for f, c in part.colours.items()}
	face_order = list(part.bm.faces)
	face_colours = [colours.get(f, GREY) for f in face_order]
	bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces)
	details = kit.to_object(part.bm, 'Details', asset)
	it = iter(face_colours)
	kit.paint(details, lambda poly: next(it))
	part.weights = weights
	rig = build_rig(asset)
	skin(rig, body, details, part)
	mat = preview_material()
	for obj in (body, details):
		obj.data.materials.append(mat)
	bpy.ops.object.select_all(action='DESELECT')
	body.select_set(True)
	details.select_set(True)
	bpy.context.view_layer.objects.active = body
	bpy.ops.object.join()
	body.name = body.data.name = 'Heron'
	for m in body.modifiers:
		if m.type == 'ARMATURE':
			m.object = rig
	body.parent = rig
	encode_srgb(body)
	rig['height_m'] = max(v.co.z for v in body.data.vertices)
	rig['strike_contact_s'] = clips.STRIKE_CONTACT / FPS
	rig['land_touch_s'] = clips.LAND_TOUCH / FPS
	rig['takeoff_lead_s'] = clips.TAKEOFF_LEAD / FPS
	rig['stalk_distance_m'] = clips.STALK_DISTANCE
	if '--no-anim' not in ARGS:
		for name, (frames, pose, loop) in clips.CLIPS.items():
			clips.bake_clip(rig, name, frames, pose, loop)
	clips.reset(rig)
	bpy.context.scene.render.fps = FPS

	blend = ROOT / 'art/blender/creatures/zenscape-heron.blend'
	glb = ROOT / 'assets/models/zenscape-heron.glb'
	blend.parent.mkdir(parents=True, exist_ok=True)
	previews = bpy.data.collections.new('PREVIEW - stage')
	bpy.context.scene.collection.children.link(previews)
	stage(previews)
	bpy.ops.wm.save_as_mainfile(filepath=str(blend))
	bpy.ops.object.select_all(action='DESELECT')
	rig.select_set(True)
	body.select_set(True)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True,
		export_animations='--no-anim' not in ARGS, export_animation_mode='ACTIONS', export_force_sampling=True,
		export_def_bones=True, export_cameras=False, export_lights=False, export_extras=True,
		export_yup=True, export_vertex_color='ACTIVE', export_skins=True)
	print('HERON_EXPORT', glb, 'tris', len(body.data.polygons), 'height', round(rig['height_m'], 3),
		'bones', sum(1 for b in rig.data.bones if b.use_deform))
	if '--no-render' in ARGS:
		return
	setup_studio()
	clips.reset(rig)
	if '--open' not in ARGS:
		clips.rest_pose(rig)
	render_views(VIEWS, 'rest')


if __name__ == '__main__':
	main()
