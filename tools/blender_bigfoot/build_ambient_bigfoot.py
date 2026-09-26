"""Ambient Bigfoot: a single skinned, faceted mesh with a small rig and a few quiet clips.

Run: blender -b --python tools/blender_bigfoot/build_ambient_bigfoot.py -- [--no-render] [--no-anim]

The body is one metaball family (torso, head, limbs, palms, feet) converted to a mesh and
decimated into large facets like the hero trees. Hanging fur locks, fingers, eyes and
blinking lids are added on top, rigidly weighted to the nearest skinned body vertex.
Saves art/blender/bigfoot/zenscape-bigfoot-ambient.blend, exports
assets/models/zenscape-bigfoot-ambient.glb and renders previews to /tmp/zs-bigfoot-previews/.
Metres, origin between the feet, Blender Z-up, facing -Y (Godot +Z after export).
"""
import bpy, bmesh, math, random, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, noise
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'blender_trees'))
import kit
from kit import srgb, mix

ROOT = kit.ROOT
ARGS = kit.ARGS
NAME = 'bigfoot-ambient'
FPS = 30
rng = random.Random(7)
kit.rng.seed(7)

# ---------------------------------------------------------------- landmarks
# Left side (+X); the right side mirrors. Surface radii, not metaball influence radii.
SHOULDER = Vector((0.36, 0.03, 1.75))
ELBOW = Vector((0.44, 0.06, 1.31))
WRIST = Vector((0.47, -0.02, 0.90))
HIP = Vector((0.15, 0.03, 1.03))
KNEE = Vector((0.17, -0.03, 0.58))
ANKLE = Vector((0.18, 0.04, 0.13))
HEAD = Vector((0.0, -0.11, 2.03))
EYE_X, EYE_Z, EYE_R = 0.07, 2.04, 0.02

COAT_TOP = srgb('775842')
COAT_MID = srgb('5e4333')
COAT_LOW = srgb('412e24')
COAT_GREY = srgb('917a68')
SKIN = srgb('4f3d34')
SKIN_DARK = srgb('2d221d')
PALM = srgb('4f3b32')
MOSS = srgb('6f7d3a')


def mirror(v):
	return Vector((-v.x, v.y, v.z))


def sided(v, s):
	return Vector(v) if s > 0 else mirror(Vector(v))


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
	if rotation:
		e.rotation = rotation
	return e


def limb(mb, a, b, r0, r1, count, bulge=0.0, bulge_at=0.4, bulge_dir=(0, 0, 0)):
	"""A chain of balls from a to b with tapering radius and an optional muscle bulge."""
	for i in range(count + 1):
		t = i / count
		r = r0 + (r1 - r0) * t + bulge * math.exp(-((t - bulge_at) / 0.22) ** 2)
		offset = Vector(bulge_dir) * bulge * math.exp(-((t - bulge_at) / 0.22) ** 2)
		ball(mb, a.lerp(b, t) + offset, r)


def build_body(collection):
	mb = bpy.data.metaballs.new('BodyBall')
	mb.resolution = mb.render_resolution = 0.018
	mb.threshold = 0.6
	obj = bpy.data.objects.new('BodyBall', mb)
	collection.objects.link(obj)
	# Torso: a soft belly, deep chest and broad shoulders with only a slight hunch.
	ellipsoid(mb, (0, 0.03, 1.07), (0.21, 0.16, 0.16))
	ellipsoid(mb, (0, -0.02, 1.29), (0.22, 0.18, 0.19))
	ellipsoid(mb, (0, 0.01, 1.56), (0.26, 0.18, 0.22))
	ellipsoid(mb, (0, 0.07, 1.75), (0.25, 0.14, 0.13))
	ellipsoid(mb, (0, 0.02, 1.87), (0.18, 0.14, 0.12))
	for s in (1, -1):
		ball(mb, sided(SHOULDER, s), 0.11)
		ball(mb, Vector((0.11 * s, 0.11, 1.02)), 0.115)  # glutes
		ellipsoid(mb, (0.16 * s, 0.06, 1.52), (0.09, 0.11, 0.17))  # lats
	# Head, after the earlier classic model: a big round helmet dome, a sharp brow visor
	# jutting forward like a cap brim, a recessed face with a broad wedge nose, and a deep
	# rounded jaw. The back of the dome melts into the shoulder hump; no neck, no crest peak.
	ellipsoid(mb, (0, -0.1, 2.09), (0.2, 0.18, 0.18))
	ellipsoid(mb, (0, 0.0, 1.97), (0.16, 0.13, 0.13))
	ellipsoid(mb, (0, -0.265, 2.09), (0.18, 0.07, 0.032))
	ellipsoid(mb, (0, -0.225, 1.98), (0.14, 0.08, 0.09))
	ellipsoid(mb, (0, -0.31, 1.995), (0.055, 0.032, 0.032))
	ellipsoid(mb, (0, -0.235, 1.91), (0.13, 0.085, 0.065))
	ellipsoid(mb, (0, -0.18, 1.86), (0.14, 0.09, 0.055))
	for s in (1, -1):
		ball(mb, (0.13 * s, -0.19, 1.93), 0.075)  # full cheeks and jaw keep the face square
	# Arms, left and right.
	for side in (SHOULDER, mirror(SHOULDER)):
		s = 1 if side.x > 0 else -1
		sh, el, wr = side, ELBOW if s > 0 else mirror(ELBOW), WRIST if s > 0 else mirror(WRIST)
		limb(mb, sh, el, 0.095, 0.08, 8, bulge=0.01, bulge_at=0.35, bulge_dir=(0.01 * s, 0, 0))
		limb(mb, el, wr, 0.085, 0.065, 7, bulge=0.012, bulge_at=0.3, bulge_dir=(0, -0.01, 0))
		palm = wr + Vector((0.008 * s, -0.035, -0.09))
		ellipsoid(mb, palm, (0.05, 0.09, 0.1))
		ball(mb, wr + Vector((0.0, -0.02, -0.02)), 0.06)
	# Legs and the big flat feet, each with five toe pads.
	for s in (1, -1):
		hip, knee, ankle = sided(HIP, s), sided(KNEE, s), sided(ANKLE, s)
		limb(mb, hip, knee, 0.13, 0.095, 8, bulge=0.01, bulge_at=0.3, bulge_dir=(0.01 * s, -0.01, 0))
		limb(mb, knee, ankle, 0.09, 0.065, 8, bulge=0.02, bulge_at=0.3, bulge_dir=(0, 0.035, 0))
		ellipsoid(mb, (0.18 * s, -0.08, 0.055), (0.085, 0.17, 0.055))
		ellipsoid(mb, (0.18 * s, 0.07, 0.065), (0.07, 0.07, 0.065))
		for k, (dx, dy, r) in enumerate(((-0.055, -0.235, 0.034), (-0.02, -0.25, 0.027), (0.013, -0.245, 0.025),
				(0.043, -0.232, 0.023), (0.068, -0.212, 0.021))):
			ball(mb, (0.18 * s + dx * s, dy, 0.03 + r * 0.4), r)
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
		v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.009
	bm.to_mesh(body.data)
	bm.free()
	return body


TARGET_FACES = 800

# ---------------------------------------------------------------- colour


def region(p, n):
	"""Region label for a body point with normal n."""
	x, y, z = abs(p.x), p.y, p.z
	if y < -0.2 and n.y < 0.25 and (x / 0.15) ** 2 + ((z - 1.98) / (0.09 if z > 1.98 else 0.11)) ** 2 < 1:
		return 'face'
	if z < 0.12 or (z < 0.2 and y < -0.15):
		return 'foot'
	if z < 0.88 and x > 0.36:
		return 'hand'
	return 'coat'


def coat_colour(p, n):
	t = max(0.0, min(1.0, (p.z - 0.3) / 1.5))
	base = mix(COAT_LOW, COAT_MID, t * 1.6) if t < 0.62 else mix(COAT_MID, COAT_TOP, (t - 0.62) / 0.38)
	if abs(p.x) > 0.32 and p.z < 1.45:  # forearms darker
		base = mix(base, COAT_LOW, 0.45)
	if p.z > 1.8 and p.y < -0.12 and abs(p.x) < 0.14:  # a slightly lighter chin
		base = mix(base, COAT_GREY, 0.12)
	if p.x > 0.2 and p.z > 1.74 and p.y > 0.0 and noise.noise(p * 7) > 0.25:  # a little moss on one shoulder
		base = mix(base, MOSS, 0.4)
	mottle = 1.0 + 0.06 * noise.noise(p * 5.0) + rng.uniform(-0.03, 0.03)
	lift = 0.94 + 0.12 * max(0.0, n.z)
	return base * mottle * lift


def face_colour(p, n):
	c = SKIN * (1.0 + rng.uniform(-0.04, 0.04))
	if 1.96 < p.z < 2.03 and abs(p.x) < 0.055 and p.y < -0.3 and n.z > -0.4:  # broad flat nose
		c = mix(c, SKIN_DARK, 0.6)
	elif p.z < 1.93 and abs(p.x) < 0.07 and n.z < 0.3:  # quiet mouth line
		c = mix(c, SKIN_DARK, 0.55)
	if p.z > 2.05:  # brow a touch warmer, blending into the coat
		c = mix(c, COAT_MID, 0.25)
	return c


def body_colour(poly, matrix=None):
	p, n = poly.center, poly.normal
	kind = region(p, n)
	if kind == 'face':
		return face_colour(p, n)
	if kind == 'foot':
		return mix(PALM, SKIN_DARK, 0.3 + 0.4 * max(0.0, -n.z)) * (1 + rng.uniform(-0.04, 0.04))
	if kind == 'hand':
		palm_side = (p.x > 0 and n.x < -0.2) or (p.x < 0 and n.x > 0.2) or n.z < -0.4
		return (PALM if palm_side else mix(PALM, COAT_LOW, 0.5)) * (1 + rng.uniform(-0.04, 0.04))
	return coat_colour(p, n)


# ---------------------------------------------------------------- details


def locks(body):
	"""A few broad, flat fur plates on the crown and shoulder mantle. At this facet count
	the body already reads as fur; more plates turn into spikes."""
	bm = bmesh.new()
	colours = []
	src = body.data
	for poly in src.polygons:
		p, n = poly.center, poly.normal
		if region(p, n) != 'coat' or n.z < -0.55:
			continue
		if p.z > 1.92:
			chance, length = 0.45, (0.04, 0.07)
			if p.y < -0.12:  # keep the brow and face clear
				continue
		elif p.z > 1.62:
			chance, length = 0.7, (0.07, 0.12)
			if p.y < -0.08 and abs(p.x) < 0.2:  # no flap hanging off the chin
				continue
		else:
			continue
		clump = noise.noise(p * 4.5)
		if clump < -0.15 or rng.random() > chance * 0.2:
			continue
		length = (length[0] * 1.7, length[1] * 1.7)
		down = Vector((0, 0, -1))
		tangent = down - n * down.dot(n)
		if tangent.length < 0.25:
			tangent = (Vector((0, 1, -0.3)) - n * n.y).normalized()
		direction = (tangent.normalized() * 0.97 + n * 0.06).normalized()
		direction += noise.noise_vector(p * 6.0) * 0.08
		direction.normalize()
		side = n.cross(direction).normalized()
		size = rng.uniform(*length)
		width = size * rng.uniform(0.6, 0.8)
		c = p - n * 0.012
		b0 = bm.verts.new(c + side * width)
		b1 = bm.verts.new(c - side * width)
		ridge = bm.verts.new(c + n * width * 0.12 + direction * size * 0.25)
		mid = c + direction * size * 0.55 - n * size * 0.02 + side * rng.uniform(-0.2, 0.2) * width
		tip = bm.verts.new(c + direction * size - n * size * 0.22)
		m0 = bm.verts.new(mid + side * width * 0.45)
		m1 = bm.verts.new(mid - side * width * 0.45)
		faces = [(b0, ridge, m0), (ridge, b1, m1), (ridge, m1, m0), (m0, m1, tip), (b1, b0, m0), (b1, m0, m1), (b0, b1, ridge)]
		base = coat_colour(p, n)
		for f in faces:
			face = bm.faces.new(f)
			colours.append(base * rng.uniform(0.92, 1.06))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	obj = kit.to_object(bm, 'Locks', body.users_collection[0])
	it = iter(colours)
	kit.paint(obj, lambda poly: next(it))
	return obj


def surface_point(bvh, origin, direction):
	hit = bvh.ray_cast(origin, direction)
	return hit[0]


def fingers(body_bvh, collection):
	"""Four relaxed, slightly curled fingers and a thumb per hand, as faceted tubes."""
	bm = bmesh.new()
	groups = []  # (vertex slice start, end, side, part)
	for s in (1, -1):
		wr = WRIST if s > 0 else mirror(WRIST)
		palm = wr + Vector((0.008 * s, -0.035, -0.09))
		for k, dy in enumerate((-0.068, -0.024, 0.019, 0.058)):
			length = (0.15, 0.165, 0.155, 0.125)[k]
			knuckle = palm + Vector((0.0, dy, -0.06))
			pts = [knuckle + Vector((0.0, 0.0, 0.03)), knuckle,
				knuckle + Vector((-0.008 * s, -0.004, -length * 0.5)),
				knuckle + Vector((-0.03 * s, -0.012, -length * 0.9))]
			start = len(bm.verts)
			kit.tube(bm, pts, [0.027, 0.026, 0.022, 0.018], 4, gnarl=0.06)
			groups.append((start, len(bm.verts), s, 'Fingers'))
		base = palm + Vector((-0.012 * s, -0.07, 0.02))
		pts = [base, base + Vector((-0.012 * s, -0.035, -0.05)), base + Vector((-0.03 * s, -0.045, -0.1))]
		start = len(bm.verts)
		kit.tube(bm, pts, [0.026, 0.021, 0.017], 4, gnarl=0.06)
		groups.append((start, len(bm.verts), s, 'Thumb'))
	obj = kit.to_object(bm, 'Fingers', collection)
	kit.paint(obj, lambda poly: mix(PALM, COAT_LOW, 0.35) * (1 + rng.uniform(-0.05, 0.05)))
	return obj, groups


def eyes(body_bvh, collection):
	"""Glossy dark eyes set under the brow, plus lids that cover their top third at rest."""
	eye_bm, lid_bm = bmesh.new(), bmesh.new()
	centres = []
	for s in (1, -1):
		origin = Vector((EYE_X * s, -0.6, EYE_Z))
		hit = surface_point(body_bvh, origin, Vector((0, 1, 0)))
		centre = Vector((EYE_X * s, hit.y + EYE_R * 0.55, EYE_Z))
		centres.append(centre)
		ico = bmesh.ops.create_icosphere(eye_bm, subdivisions=1, radius=EYE_R)
		for v in ico['verts']:
			v.co += centre
		# Lid: a spherical cap around the pole, tilted forward so its edge rests above the pupil.
		rows, cols, cap = 5, 12, math.radians(80)
		grid = []
		for i in range(rows + 1):
			theta = cap * i / rows
			ring = []
			for j in range(cols):
				phi = math.tau * j / cols
				d = Vector((math.sin(theta) * math.cos(phi), math.sin(theta) * math.sin(phi), math.cos(theta)))
				d = Matrix.Rotation(math.radians(-28), 3, 'X') @ d
				ring.append(lid_bm.verts.new(centre + d * EYE_R * 1.16))
			grid.append(ring)
		for a, b in zip(grid, grid[1:]):
			for j in range(cols):
				lid_bm.faces.new((a[j], a[(j + 1) % cols], b[(j + 1) % cols], b[j]))
	bmesh.ops.recalc_face_normals(lid_bm, faces=lid_bm.faces)
	eye_obj = kit.to_object(eye_bm, 'Eyes', collection)
	lid_obj = kit.to_object(lid_bm, 'Lids', collection)
	kit.paint(eye_obj, lambda poly: srgb('1a110b'))
	kit.paint(lid_obj, lambda poly: SKIN * 0.95)
	# Close the lid cap's open side so it is solid from any angle.
	lid_obj.data.update()
	return eye_obj, lid_obj, centres


def leaves(collection):
	"""Two small leaves caught in the crown fur and one on the shoulder: a little charm."""
	bm = bmesh.new()
	spots = [(Vector((0.07, 0.0, 2.2)), Vector((0.4, 0.6, 0.3)), srgb('a8742c')),
		(Vector((-0.1, 0.05, 2.14)), Vector((-0.5, 0.4, 0.4)), srgb('7d8a3a')),
		(Vector((0.3, 0.12, 1.84)), Vector((0.3, 0.5, 0.7)), srgb('b0582c'))]
	colours = []
	for base, direction, colour in spots:
		direction = direction.normalized()
		side = direction.orthogonal().normalized()
		up = direction.cross(side) * 0.3
		verts = [bm.verts.new(base), bm.verts.new(base + direction * 0.03 + side * 0.018 + up * 0.01),
			bm.verts.new(base + direction * 0.065), bm.verts.new(base + direction * 0.03 - side * 0.018 + up * 0.01)]
		bm.faces.new(verts)
		back = [bm.verts.new(v.co - up * 0.01) for v in verts]
		bm.faces.new(list(reversed(back)))
		colours += [colour, colour * 0.85]
	obj = kit.to_object(bm, 'Leaves', collection)
	it = iter(colours)
	kit.paint(obj, lambda poly: next(it))
	return obj


# ---------------------------------------------------------------- rig

BONES = {}


def build_rig(collection, eye_centres):
	arm_data = bpy.data.armatures.new('BigfootRig')
	rig = bpy.data.objects.new('BigfootRig', arm_data)
	collection.objects.link(rig)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.mode_set(mode='EDIT')
	eb = arm_data.edit_bones

	def bone(name, head, tail, parent=None, deform=True, connect=False, roll=0.0):
		b = eb.new(name)
		b.head, b.tail, b.roll = Vector(head), Vector(tail), roll
		if parent:
			b.parent = eb[parent]
			b.use_connect = connect
		b.use_deform = deform
		return b

	bone('Root', (0, 0, 0), (0, 0.3, 0), deform=False)
	bone('Pelvis', (0, 0.03, 1.0), (0, 0.02, 1.2), 'Root')
	bone('Spine', (0, 0.02, 1.2), (0, 0.01, 1.5), 'Pelvis', connect=True)
	bone('Chest', (0, 0.01, 1.5), (0, 0.04, 1.8), 'Spine', connect=True)
	bone('Neck', (0, 0.04, 1.8), (0, -0.05, 1.93), 'Chest', connect=True)
	bone('Head', (0, -0.05, 1.93), (0, -0.08, 2.28), 'Neck', connect=True)
	for s, suffix in ((1, 'L'), (-1, 'R')):
		sh, el, wr = sided(SHOULDER, s), sided(ELBOW, s), sided(WRIST, s)
		palm = wr + Vector((0.008 * s, -0.035, -0.09))
		ec = eye_centres[0 if s > 0 else 1]
		bone(f'Lid_{suffix}', ec, ec + Vector((0, -0.05, 0)), 'Head')
		bone(f'Shoulder_{suffix}', (0.08 * s, 0.03, 1.8), sh, 'Chest')
		bone(f'UpperArm_{suffix}', sh, el, f'Shoulder_{suffix}', connect=True)
		bone(f'Forearm_{suffix}', el, wr, f'UpperArm_{suffix}', connect=True)
		bone(f'Hand_{suffix}', wr, palm + Vector((0, 0, -0.06)), f'Forearm_{suffix}', connect=True)
		bone(f'Fingers_{suffix}', palm + Vector((0, 0, -0.06)), palm + Vector((-0.02 * s, -0.01, -0.19)), f'Hand_{suffix}', connect=True)
		bone(f'Thumb_{suffix}', palm + Vector((-0.012 * s, -0.07, 0.02)), palm + Vector((-0.03 * s, -0.115, -0.08)), f'Hand_{suffix}')
		bone(f'Thigh_{suffix}', sided(HIP, s), sided(KNEE, s), 'Pelvis')
		bone(f'Shin_{suffix}', sided(KNEE, s), sided(ANKLE, s), f'Thigh_{suffix}', connect=True)
		bone(f'Foot_{suffix}', sided(ANKLE, s), Vector((0.18 * s, -0.17, 0.04)), f'Shin_{suffix}', connect=True)
		bone(f'Toes_{suffix}', Vector((0.18 * s, -0.17, 0.04)), Vector((0.18 * s, -0.28, 0.035)), f'Foot_{suffix}', connect=True)
		bone(f'FootIK_{suffix}', sided(ANKLE, s), sided(ANKLE, s) + Vector((0, -0.18, 0)), 'Root', deform=False)
		bone(f'KneePole_{suffix}', sided(KNEE, s) + Vector((0, -0.6, 0)), sided(KNEE, s) + Vector((0, -0.7, 0)), 'Root', deform=False)
	# Consistent rolls: bones' local Z points backward (+Y) or up, so X is the bend axis.
	for b in eb:
		b.align_roll(Vector((0, 1, 0)) if abs(b.vector.normalized().z) > 0.5 else Vector((0, 0, 1)))
	bpy.ops.object.mode_set(mode='POSE')
	for suffix in ('L', 'R'):
		shin = rig.pose.bones[f'Shin_{suffix}']
		c = shin.constraints.new('IK')
		c.target, c.subtarget = rig, f'FootIK_{suffix}'
		c.pole_target, c.pole_subtarget = rig, f'KneePole_{suffix}'
		c.pole_angle = math.radians(-90)
		c.chain_count = 2
		foot = rig.pose.bones[f'Foot_{suffix}']
		c = foot.constraints.new('COPY_ROTATION')
		c.target, c.subtarget = rig, f'FootIK_{suffix}'
	for pb in rig.pose.bones:
		pb.rotation_mode = 'QUATERNION'
	bpy.ops.object.mode_set(mode='OBJECT')
	return rig


def skin(rig, body, extras):
	"""Heat weights for the body; every extra piece copies the weights of its nearest body vertex."""
	bpy.ops.object.select_all(action='DESELECT')
	body.select_set(True)
	rig.select_set(True)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.parent_set(type='ARMATURE_AUTO')
	deform = [b.name for b in rig.data.bones if b.use_deform]
	for name in deform:
		if name not in body.vertex_groups:
			body.vertex_groups.new(name=name)
	# Heat weighting lets the lid bones claim the brow and cheeks, so every blink dragged
	# the face. Only the lid meshes follow the lids; the skin around them follows the head.
	head = body.vertex_groups['Head']
	for suffix in ('L', 'R'):
		lid = body.vertex_groups[f'Lid_{suffix}']
		for v in body.data.vertices:
			for g in v.groups:
				if g.group == lid.index and g.weight > 0:
					head.add([v.index], g.weight, 'ADD')
		lid.remove([v.index for v in body.data.vertices])
	tree = KDTree(len(body.data.vertices))
	for v in body.data.vertices:
		tree.insert(v.co, v.index)
	tree.balance()
	names = {g.index: g.name for g in body.vertex_groups}
	for obj, override in extras:
		for name in deform:
			obj.vertex_groups.new(name=name)
		bm = bmesh.new()
		bm.from_mesh(obj.data)
		islands = []
		seen = set()
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
			islands.append(island)
		for island in islands:
			centre = sum((obj.data.vertices[i].co for i in island), Vector()) / len(island)
			weights = override(centre, island) if override else None
			if weights is None:
				_, index, _ = tree.find(centre)
				weights = {names[g.group]: g.weight for g in body.data.vertices[index].groups if g.weight > 0.02}
			for name, w in weights.items():
				obj.vertex_groups[name].add(island, w, 'REPLACE')
		bm.free()
	return deform


# ---------------------------------------------------------------- animation

def quat(*pairs):
	q = Quaternion()
	for axis, degrees in pairs:
		q = Quaternion(Vector(axis), math.radians(degrees)) @ q
	return q


def local(rig, name, q_arm):
	"""A rotation given in armature axes, expressed in the bone's rest frame."""
	rest = rig.data.bones[name].matrix_local.to_3x3().to_quaternion()
	return rest.inverted() @ q_arm @ rest


def reset(rig):
	for pb in rig.pose.bones:
		pb.location = (0, 0, 0)
		pb.rotation_quaternion = (1, 0, 0, 0)
		pb.scale = (1, 1, 1)


def key_all(rig, frame):
	for pb in rig.pose.bones:
		pb.keyframe_insert('location', frame=frame)
		pb.keyframe_insert('rotation_quaternion', frame=frame)


def set_rot(rig, name, *pairs):
	pb = rig.pose.bones[name]
	pb.rotation_quaternion = local(rig, name, quat(*pairs)) @ pb.rotation_quaternion


def set_loc(rig, name, offset):
	"""Translate a bone by an armature-space offset."""
	rest = rig.data.bones[name].matrix_local.to_3x3()
	rig.pose.bones[name].location = rest.inverted() @ Vector(offset)


def smooth(x):
	x = max(0.0, min(1.0, x))
	return x * x * (3 - 2 * x)


def blink(t, starts, close=3, hold=1, open_=5):
	"""0 open .. 1 closed for blinks starting at the given frames."""
	value = 0.0
	for s in starts:
		d = t - s
		if 0 <= d < close:
			value = max(value, d / close)
		elif close <= d < close + hold:
			value = 1.0
		elif close + hold <= d < close + hold + open_:
			value = max(value, 1 - (d - close - hold) / open_)
	return value


def base_pose(rig, t, period, breath_cycles, sway_cycles=1, blinks=(), lid_rest=6):
	"""Shared standing pose: slow breath, weight drifting between the feet, arms hanging."""
	w = math.tau * t / period
	breath = math.sin(w * breath_cycles)
	sway = math.sin(w * sway_cycles)
	# Posture: a gentle forward lean, head held level and slightly low.
	set_loc(rig, 'Pelvis', (0.012 * sway, 0, -0.012 + 0.003 * breath))
	set_rot(rig, 'Pelvis', ((0, 1, 0), 1.5 * sway))
	set_rot(rig, 'Spine', ((1, 0, 0), 3 + 0.8 * breath), ((0, 1, 0), -1.0 * sway))
	set_rot(rig, 'Chest', ((1, 0, 0), 2 - 1.4 * breath), ((0, 1, 0), -0.8 * sway))
	set_rot(rig, 'Neck', ((1, 0, 0), -5 + 0.6 * breath))
	set_rot(rig, 'Head', ((1, 0, 0), -3 + 1.0 * breath), ((0, 1, 0), 1.5 * sway))
	for s, suffix in ((1, 'L'), (-1, 'R')):
		set_rot(rig, f'Shoulder_{suffix}', ((0, 1, 0), s * (-1.5 * breath)))
		set_rot(rig, f'UpperArm_{suffix}', ((1, 0, 0), -3 + 1.5 * math.sin(w * sway_cycles + 0.6 * s)), ((0, 1, 0), s * 2))
		set_rot(rig, f'Forearm_{suffix}', ((1, 0, 0), -10 + 2 * math.sin(w * sway_cycles + 1.1 * s)))
		set_rot(rig, f'Hand_{suffix}', ((1, 0, 0), -4), ((0, 1, 0), s * -3))
		set_rot(rig, f'Fingers_{suffix}', ((1, 0, 0), -8 - 3 * breath))
		lid = max(lid_rest / 70, blink(t, blinks))
		set_rot(rig, f'Lid_{suffix}', ((1, 0, 0), -70 * lid))
	for s, suffix in ((1, 'L'), (-1, 'R')):
		set_loc(rig, f'FootIK_{suffix}', (0, 0, 0))
	return breath, sway


def bake_clip(rig, name, frames, pose, step=2):
	action = bpy.data.actions.new(name)
	action.use_fake_user = True
	rig.animation_data_create()
	rig.animation_data.action = action
	for f in list(range(0, frames, step)) + [frames]:
		reset(rig)
		pose(rig, f % frames)
		key_all(rig, f)
	action.frame_range = (0, frames)
	action.use_frame_range = True
	track = rig.animation_data.nla_tracks.new()
	track.name = name
	strip = track.strips.new(name, 0, action)
	track.mute = True
	rig.animation_data.action = None
	return action


def idle(rig, t):
	base_pose(rig, t, 240, breath_cycles=2, blinks=(52, 176))


def look(rig, t):
	"""Senses something, turns head then shoulders toward it, tilts curiously, turns back."""
	base_pose(rig, t, 300, breath_cycles=2, blinks=(44, 132, 214))
	turn = smooth((t - 40) / 50) - smooth((t - 200) / 60)
	chest_turn = smooth((t - 55) / 60) - smooth((t - 210) / 60)
	tilt = smooth((t - 110) / 30) - smooth((t - 170) / 25)
	set_rot(rig, 'Spine', ((0, 0, 1), 8 * chest_turn))
	set_rot(rig, 'Chest', ((0, 0, 1), 10 * chest_turn))
	set_rot(rig, 'Neck', ((0, 0, 1), 18 * turn), ((1, 0, 0), -3 * turn))
	set_rot(rig, 'Head', ((0, 0, 1), 26 * turn), ((0, 1, 0), -11 * tilt), ((1, 0, 0), 4 * tilt))
	set_rot(rig, 'UpperArm_R', ((1, 0, 0), -6 * chest_turn))


WALK_FRAMES = 100
STEP = 0.56  # metres per step; two steps per cycle
WALK_SPEED = 2 * STEP / (WALK_FRAMES / FPS)


def walk(rig, t):
	"""Slow, heavy amble in place. Move the root forward at WALK_SPEED."""
	period = WALK_FRAMES
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
		# pitch > 0 lifts the toe; positive rotation about X drops it.
		set_loc(rig, f'FootIK_{suffix}', (0.0, y, lift + max(0.0, -pitch) * 0.0025))
		set_rot(rig, f'FootIK_{suffix}', ((1, 0, 0), -pitch))
		set_rot(rig, f'Toes_{suffix}', ((1, 0, 0), -max(0.0, -pitch) if p < stance else 0.0))
	bob = math.cos(2 * w)
	sway = math.sin(w)
	set_loc(rig, 'Pelvis', (0.03 * sway, 0.0, -0.01 + 0.012 * bob))
	set_rot(rig, 'Pelvis', ((0, 0, 1), 6 * math.cos(w)), ((0, 1, 0), 3.5 * sway))
	set_rot(rig, 'Spine', ((0, 0, 1), -4 * math.cos(w)), ((1, 0, 0), 7 - 1.2 * bob), ((0, 1, 0), -2.5 * sway))
	set_rot(rig, 'Chest', ((0, 0, 1), -5 * math.cos(w)), ((1, 0, 0), 5), ((0, 1, 0), -1.5 * sway))
	set_rot(rig, 'Neck', ((1, 0, 0), -4 + 1.2 * bob), ((0, 0, 1), 3 * math.cos(w)))
	set_rot(rig, 'Head', ((1, 0, 0), -2 + 1.5 * bob), ((0, 0, 1), 2 * math.cos(w)), ((0, 1, 0), -1.5 * sway))
	for s, suffix in ((1, 'L'), (-1, 'R')):
		swing = math.cos(w + (0 if s < 0 else math.pi))
		set_rot(rig, f'UpperArm_{suffix}', ((1, 0, 0), -2 + 14 * swing), ((0, 1, 0), s * 3))
		set_rot(rig, f'Forearm_{suffix}', ((1, 0, 0), -14 + 7 * math.cos(w + (0 if s < 0 else math.pi) - 0.8)))
		set_rot(rig, f'Hand_{suffix}', ((1, 0, 0), -6 + 5 * math.cos(w + (0 if s < 0 else math.pi) - 1.4)))
		set_rot(rig, f'Fingers_{suffix}', ((1, 0, 0), -12))
		set_rot(rig, f'Lid_{suffix}', ((1, 0, 0), -6 - 70 * blink(t, (30,))))


CLIPS = {'Idle': (240, idle), 'Look': (300, look), 'Walk': (WALK_FRAMES, walk)}


# ---------------------------------------------------------------- preview


def stage(collection):
	bm = bmesh.new()
	bmesh.ops.create_grid(bm, x_segments=2, y_segments=2, size=12)
	floor = kit.to_object(bm, 'Floor', collection)
	kit.paint(floor, lambda p: srgb('8c8a84'))
	floor.data.materials.append(kit.material('Floor', 1.0))
	bm = bmesh.new()
	bmesh.ops.create_grid(bm, x_segments=2, y_segments=2, size=12)
	wall = kit.to_object(bm, 'Backdrop', collection)
	wall.rotation_euler = (math.radians(90), 0, 0)
	wall.location = (0, 6, 0)
	kit.paint(wall, lambda p: srgb('6d6c68'))
	wall.data.materials.append(kit.material('Backdrop', 1.0))


def setup_studio():
	scene = bpy.context.scene
	scene.render.engine = 'BLENDER_EEVEE'
	scene.render.resolution_x, scene.render.resolution_y = 900, 1000
	scene.view_settings.view_transform = 'Standard'
	scene.render.fps = FPS
	world = bpy.data.worlds.new('Studio')
	world.use_nodes = True
	world.node_tree.nodes['Background'].inputs['Color'].default_value = (*srgb('9aa6b4'), 1)
	world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9
	scene.world = world
	sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
	sun.data.energy, sun.data.color, sun.data.angle = 3.4, srgb('fff0d8'), math.radians(4)
	sun.rotation_euler = (math.radians(52), 0, math.radians(-38))
	scene.collection.objects.link(sun)
	cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
	scene.collection.objects.link(cam)
	scene.camera = cam


def render_views(rig, views, folder, frames=None):
	scene = bpy.context.scene
	cam = scene.camera
	out = Path('/tmp/zs-bigfoot-previews') / folder
	out.mkdir(parents=True, exist_ok=True)
	for view, (loc, target, lens) in views.items():
		cam.location = loc
		cam.data.lens = lens
		cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
		for f in frames or [None]:
			if f is not None:
				scene.frame_set(f)
			scene.render.filepath = str(out / (f'{view}.png' if f is None else f'{view}-{f:03d}.png'))
			bpy.ops.render.render(write_still=True)
	print('BIGFOOT_RENDERS', out)


VIEWS = {
	'hero': ((2.6, -4.6, 1.7), (0, 0, 1.18), 42),
	'front': ((0, -5.2, 1.3), (0, 0, 1.18), 42),
	'side': ((5.2, -0.1, 1.3), (0, 0, 1.18), 42),
	'back': ((-2.0, 3.6, 1.8), (0, 0, 1.2), 34),
	'face': ((0.55, -1.55, 2.08), (0, -0.15, 2.02), 60),
	'hands': ((1.6, -1.6, 0.8), (0.45, 0, 0.55), 45),
}


# ---------------------------------------------------------------- main


def main():
	asset = kit.fresh_scene('EDIT - ambient Bigfoot')
	body = build_body(asset)
	kit.paint(body, body_colour)
	bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
	fur = locks(body)
	hands, finger_groups = fingers(bvh, asset)
	eye_obj, lid_obj, centres = eyes(bvh, asset)
	leaf = leaves(asset)
	rig = build_rig(asset, centres)

	def finger_weights(centre, island):
		s = 'L' if centre.x > 0 else 'R'
		thumb = centre.y < (WRIST.y - 0.09)
		return {f'Thumb_{s}' if thumb else f'Fingers_{s}': 1.0}

	def eye_weights(centre, island):
		return {'Head': 1.0}

	def lid_weights(centre, island):
		return {f'Lid_{"L" if centre.x > 0 else "R"}': 1.0}

	skin(rig, body, [(fur, None), (hands, finger_weights), (eye_obj, eye_weights), (lid_obj, lid_weights), (leaf, None)])
	coat = kit.material('Bigfoot coat', 0.92)
	eye_mat = kit.material('Bigfoot eyes', 0.18)
	eye_mat.node_tree.nodes['Principled BSDF'].inputs['Specular IOR Level'].default_value = 0.8
	for obj in (body, fur, hands, lid_obj, leaf):
		obj.data.materials.append(coat)
	eye_obj.data.materials.append(eye_mat)
	bpy.ops.object.select_all(action='DESELECT')
	for obj in (body, fur, hands, eye_obj, lid_obj, leaf):
		obj.select_set(True)
	bpy.context.view_layer.objects.active = body
	bpy.ops.object.join()
	body.name = body.data.name = 'Bigfoot'
	for m in body.modifiers:
		if m.type == 'ARMATURE':
			m.object = rig
	if not body.modifiers:
		m = body.modifiers.new('Armature', 'ARMATURE')
		m.object = rig
	body.parent = rig
	rig['walk_speed_mps'] = WALK_SPEED
	rig['height_m'] = max((v.co.z for v in body.data.vertices))
	if '--no-anim' not in ARGS:
		for name, (frames, pose) in CLIPS.items():
			bake_clip(rig, name, frames, pose)
	reset(rig)
	bpy.context.scene.render.fps = FPS

	blend = ROOT / 'art/blender/bigfoot/zenscape-bigfoot-ambient.blend'
	glb = ROOT / 'assets/models/zenscape-bigfoot-ambient.glb'
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
	print('BIGFOOT_EXPORT', glb, 'faces', len(body.data.polygons), 'height', rig['height_m'],
		'walk_speed', WALK_SPEED, 'bones', sum(1 for b in rig.data.bones if b.use_deform))
	if '--no-render' in ARGS:
		return
	setup_studio()
	render_views(rig, VIEWS, 'rest')
	if '--no-anim' not in ARGS:
		track = rig.animation_data.nla_tracks
		for name, (frames, _) in CLIPS.items():
			for t in track:
				t.mute = t.name != name
			sample = [0, frames // 4, frames // 2, 3 * frames // 4] if name == 'Walk' else [0, frames * 2 // 5, frames * 3 // 5]
			views = {'clip-' + name.lower(): VIEWS['hero'], f'clip-{name.lower()}-side': VIEWS['side']}
			render_views(rig, views, 'clips', sample)


main()
