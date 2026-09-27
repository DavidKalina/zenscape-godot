"""Hero weeping willow: a short furrowed trunk that splits low into arching limbs under a
soft, lumpy dome. Long narrow strands start high on the dome, run over its shoulder and
fall nearly to the ground in three layers, ragged in length and drifting a little with
the wind; a few short gaps let the trunk show through.

Run: blender -b --factory-startup --python tools/blender_trees/willow.py [-- --no-render]
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh
from mathutils import Vector, noise
import kit
from kit import rng, srgb, mix

kit.seed(57)
LEAF_DARK, LEAF_MID, LEAF_LIGHT = srgb('4c6e2e'), srgb('86a445'), srgb('c2d27a')
BARK_DARK, BARK_LIGHT = srgb('3f3329'), srgb('7d6a55')

asset = kit.fresh_scene('EXPORT - hero willow')
wood, leaves = bmesh.new(), bmesh.new()
# Per-face shade: 0 dome, 1 outer strands, 2 middle, 3 inner. Only drives the bake.
shade = leaves.faces.layers.int.new('shade')

# The dome's envelope: rounded top, shoulder at SHOULDER_R, underside rising to the rim.
TOP, SHOULDER_R, SHOULDER_Z, UNDER_Z = 6.0, 2.35, 4.55, 3.85
WIND = Vector((0.22, 0.08, 0))  # the whole curtain drifts a touch downwind


def dome_z(r):
	return TOP - (TOP - SHOULDER_Z) * (r / SHOULDER_R) ** 2


def lump(d):
	return 1.0 + 0.1 * noise.noise(d * 1.6 + Vector((3.1, 7.3, 1.7)))


def dome():
	"""A faceted, lumpy dome: rings of jittered verts over the envelope, closed below."""
	segs = 15
	rings = []
	profile = [(0.55, None), (1.1, None), (1.65, None), (2.1, None), (SHOULDER_R, None),
		(SHOULDER_R * 0.93, SHOULDER_Z - 0.35), (1.5, UNDER_Z + 0.15)]
	for j, (r, z) in enumerate(profile):
		ring = []
		for k in range(segs):
			a = (k + 0.5 * j + rng.uniform(-0.2, 0.2)) * math.tau / segs
			d = Vector((math.cos(a), math.sin(a), 0))
			rr = r * lump(d * r) * rng.uniform(0.97, 1.03)
			zz = (dome_z(r) if z is None else z) + rng.uniform(-0.06, 0.06)
			ring.append(leaves.verts.new(d * rr + Vector((0, 0, zz))))
		rings.append(ring)
	top = leaves.verts.new(Vector((0.22, -0.14, TOP + 0.02)))
	bottom = leaves.verts.new(Vector((0.1, 0.05, UNDER_Z)))
	faces = []
	first, last = rings[0], rings[-1]
	for k in range(segs):
		faces.append(leaves.faces.new((top, first[k], first[(k + 1) % segs])))
		faces.append(leaves.faces.new((bottom, last[(k + 1) % segs], last[k])))
	for a, b in zip(rings, rings[1:]):
		for k in range(segs):
			faces.append(leaves.faces.new((a[k], b[k], b[(k + 1) % segs], a[(k + 1) % segs])))
	for f in faces:
		f[shade] = 0


def strand(points, widths, layer, thick=0.06):
	"""A narrow blade along a polyline: a flat triangular section with its ridge facing away
	from the dome, so light breaks it into two facets; closed at both ends, blunt tip."""
	rings = []
	for i, p in enumerate(points):
		if i == 0:
			t = points[1] - p
		elif i == len(points) - 1:
			t = p - points[i - 1]
		else:
			t = points[i + 1] - points[i - 1]
		t.normalize()
		radial = Vector((p.x, p.y, 0))
		radial = radial.normalized() if radial.length > 0.01 else Vector((1, 0, 0))
		side = t.cross(radial)
		if side.length < 0.1:
			side = Vector((-radial.y, radial.x, 0))
		side.normalize()
		face = side.cross(t).normalized()
		if face.dot(radial) + face.z < 0:
			face = -face
		w = widths[i]
		ring = [leaves.verts.new(p + side * w - face * thick * 0.35),
			leaves.verts.new(p - side * w - face * thick * 0.35),
			leaves.verts.new(p + face * thick * (0.4 + 2.0 * w) + side * w * 0.15)]
		rings.append(ring)
	faces = [leaves.faces.new(rings[0]), leaves.faces.new(rings[-1][::-1])]
	for a, b in zip(rings, rings[1:]):
		for k in range(3):
			faces.append(leaves.faces.new((a[k], a[(k + 1) % 3], b[(k + 1) % 3], b[k])))
	for f in faces:
		f[shade] = layer


def hang(a, r0, z0, r_knee, z_knee, reach, drop, width, layer, over=()):
	"""A strand at angle a: optionally lying over the dome at radii `over`, then leaving it
	at the knee and falling `drop` metres, swinging `reach` outward and drifting with the wind."""
	out = Vector((math.cos(a), math.sin(a), 0))
	side = Vector((-out.y, out.x, 0))
	curl = rng.uniform(-0.25, 0.25)
	pts = []
	for j, r in enumerate(over):
		# The first point sinks into the dome, so the strand grows out of it.
		pts.append(out * r * lump(out * r) + Vector((0, 0, dome_z(r) + (0.08 if j else -0.06))))
	knee = out * r_knee + Vector((0, 0, z_knee))
	pts.append(knee)
	fall = (0.12, 0.35, 0.62, 0.86, 1.0) if drop > 1.6 else (0.3, 0.7, 1.0)
	for s in fall:
		swing = reach * (1 - (1 - s) ** 2.2)
		pts.append(knee + out * swing + (WIND + side * curl) * s ** 1.6 - Vector((0, 0, drop * s ** 1.08)))
	n = len(pts)
	w_top = width
	widths = []
	for i in range(n):
		t = i / (n - 1)
		widths.append(w_top * (1.0 - 0.62 * t ** 1.4) * rng.uniform(0.9, 1.1))
	if over:
		widths[0] *= 0.55
	widths[-1] = min(widths[-1], 0.07)
	strand(pts, widths, layer)


# ---------------------------------------------------------------- wood
fork = Vector((0.15, 0.05, 1.9))
kit.tube(wood, [(0, 0, -0.1), (0.04, 0.0, 0.6), (0.1, 0.03, 1.3), fork], [0.42, 0.34, 0.31, 0.3], 8, gnarl=0.12)
for k in range(4):
	a = k * math.tau / 4 + rng.uniform(-0.3, 0.3)
	d = Vector((math.cos(a), math.sin(a), 0))
	kit.tube(wood, [d * 0.12 + Vector((0, 0, 0.45)), d * 0.45 + Vector((0, 0, 0.08)), d * 0.8 + Vector((0, 0, -0.08))], [0.18, 0.1, 0.04], 5, gnarl=0.1)
for k in range(5):
	a = k * math.tau / 5 + rng.uniform(-0.25, 0.25)
	d = Vector((math.cos(a), math.sin(a), 0))
	end = fork + d * rng.uniform(1.3, 1.7) + Vector((0, 0, rng.uniform(2.45, 2.75)))
	pts = kit.bowed(fork - Vector((0, 0, 0.25)), end, d * -0.2 + Vector((0, 0, 0.35)), 4)
	kit.tube(wood, pts, kit.taper(0.19, 0.06, len(pts)), 6, gnarl=0.1)

# ---------------------------------------------------------------- crown
dome()
# Gaps: two sectors where the curtain hangs short, so the trunk shows through.
gaps = [rng.uniform(0, math.tau)]
gaps.append(gaps[0] + rng.uniform(2.2, 3.2))


def in_gap(a, half=0.3):
	return any(abs((a - g + math.pi) % math.tau - math.pi) < half for g in gaps)


# Outer layer: long strands that start high on the dome, run over the shoulder and fall.
OUTER = 34
for i in range(OUTER):
	a = (i + rng.uniform(-0.3, 0.3)) * math.tau / OUTER
	r0 = rng.uniform(0.55, 1.6)
	over = (r0, (r0 + SHOULDER_R) * 0.5 + rng.uniform(-0.1, 0.1))
	r_knee = SHOULDER_R + rng.uniform(0.05, 0.2)
	z_knee = SHOULDER_Z - rng.uniform(0.05, 0.25)
	ragged = 0.5 + 0.5 * noise.noise(Vector((math.cos(a), math.sin(a), 0)) * 1.8 + Vector((5.0, 1.0, 2.0)))
	drop = 2.4 + 1.2 * ragged + rng.uniform(-0.45, 0.45)
	if in_gap(a):
		drop = rng.uniform(0.9, 1.5)
	hang(a, r0, 0, r_knee, z_knee, rng.uniform(0.25, 0.5), drop, rng.uniform(0.17, 0.24), 1, over)
# Middle layer: hangs from under the shoulder, a little shorter, between the outer strands.
MIDDLE = 22
for i in range(MIDDLE):
	a = (i + 0.5 + rng.uniform(-0.3, 0.3)) * math.tau / MIDDLE
	drop = rng.uniform(1.9, 3.1)
	if in_gap(a, 0.35):
		drop = rng.uniform(0.7, 1.1)
	hang(a, 0, 0, rng.uniform(1.85, 2.1), SHOULDER_Z - rng.uniform(0.3, 0.45), rng.uniform(0.15, 0.3), drop,
		rng.uniform(0.16, 0.22), 2)
# Inner layer: short, dark strands deep inside the curtain, round the trunk.
INNER = 12
for i in range(INNER):
	a = (i + rng.uniform(-0.3, 0.3)) * math.tau / INNER
	if in_gap(a, 0.4):
		continue
	hang(a, 0, 0, rng.uniform(1.25, 1.55), UNDER_Z + rng.uniform(0.2, 0.35), rng.uniform(0.1, 0.2),
		rng.uniform(1.3, 2.2), rng.uniform(0.15, 0.2), 3)

bmesh.ops.recalc_face_normals(leaves, faces=leaves.faces)
bmesh.ops.triangulate(leaves, faces=leaves.faces)
bark = kit.to_object(wood, 'Bark', asset)
crown = kit.to_object(leaves, 'Crown', asset)
layer_of = [d.value for d in crown.data.attributes['shade'].data]
check = bmesh.new()
check.from_mesh(crown.data)
holes = sum(1 for e in check.edges if e.is_boundary)
check.free()
zs = [v.co.z for v in crown.data.vertices]
zmin, zmax = min(zs), max(zs)
spread = max(Vector((v.co.x, v.co.y)).length for v in crown.data.vertices)
print('WILLOW crown faces', len(crown.data.polygons), 'boundary edges', holes,
	'bark', len(bark.data.polygons), 'height', round(zmax, 2), 'spread', round(spread, 2), 'crown bottom', round(zmin, 2))


def leaf_colour(poly):
	# Strands are lighter than the dome under them, so they read as streaks from above;
	# the deeper layers of the curtain stay dark, and strand tips catch a little light.
	c, n = poly.center, poly.normal
	layer = layer_of[poly.index]
	h = (c.z - zmin) / (zmax - zmin)
	radial = Vector((c.x, c.y, 0)).normalized() if c.xy.length > 0.01 else Vector((0, 0, 1))
	outer = max(0.0, n.dot(radial))
	light = 0.3 * h + 0.3 * outer + 0.35 * max(n.z, 0) - 0.25 * max(-n.z, 0)
	light += (-0.12, 0.12, -0.05, -0.22)[layer]
	if layer and outer < 0.2:
		light -= 0.12
	base = mix(LEAF_DARK, LEAF_MID, light * 1.5) if light < 0.66 else mix(LEAF_MID, LEAF_LIGHT, (light - 0.66) * 2.4)
	return base * rng.uniform(0.93, 1.06)


def bark_colour(poly):
	lit = 0.3 + 0.4 * rng.random() + 0.3 * max(poly.normal.z, 0)
	return mix(BARK_DARK, BARK_LIGHT, lit) * rng.uniform(0.9, 1.06)


kit.paint(crown, leaf_colour)
kit.paint(bark, bark_colour)
crown.data.attributes.remove(crown.data.attributes['shade'])


def stage(collection):
	kit.ground(collection, 12, srgb('5f8c3c'), srgb('86ad4e'))
	kit.pine(collection, (6.0, 4.5, 0), 6.0)


kit.finish('hero-willow', [(bark, 'Bark', 0.95), (crown, 'Crown', 0.85)],
	{'description': 'Faceted hero weeping willow; origin at ground contact. Crown palette_role 2 (tinted per tree), bark palette_role 4.',
		'height_m': round(zmax, 2), 'crown_bottom_m': round(zmin, 2)},
	stage,
	{
		'three-quarter': ((13, -14, 7.5), (0.3, 0.3, 2.8), 45),
		'low-hero': ((6, -8, 0.9), (0.3, 0.3, 2.8), 24),
		'diorama': ((12, -12, 16), (0.3, 0.3, 1.8), 42),
		'above': ((7, -7, 17), (0.3, 0.3, 2.0), 42),
		'side': ((-15, -4, 3.5), (0.3, 0.3, 2.8), 45),
	})
