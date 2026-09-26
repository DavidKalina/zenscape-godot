"""Build the faceted hero oak, save its .blend, export the .glb and render previews.

Run: blender -b --factory-startup --python tools/build_hero_oak.py [-- --no-render]
Metres, origin at the ground contact, Blender Z-up (the glTF exporter makes it Y-up).
Colours are baked per face into COLOR_0 so Godot's palette and lighting stay in charge.
"""
import bpy, bmesh, math, random, sys
from pathlib import Path
from mathutils import Vector, Matrix, noise

ROOT = Path(__file__).resolve().parents[1]
BLEND = ROOT / 'art/blender/trees/zenscape-hero-oak.blend'
GLB = ROOT / 'assets/models/zenscape-hero-oak.glb'
PREVIEWS = Path('/tmp/zs-hero-oak-previews')
SEED = 7
rng = random.Random(SEED)
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []


def srgb(hex_value):
	c = [int(hex_value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	return Vector([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c])


LEAF_DARK, LEAF_MID, LEAF_LIGHT, LEAF_WARM = srgb('2c5429'), srgb('4a8436'), srgb('8ab54c'), srgb('a7b347')
BARK_DARK, BARK_LIGHT = srgb('3a2419'), srgb('7a4c33')
GRASS, GRASS_LIGHT = srgb('5f8c3c'), srgb('86ad4e')


def mix(a, b, t):
	return a.lerp(b, max(0.0, min(1.0, t)))


# ---------------------------------------------------------------- wood

def tube(bm, points, radii, sides, gnarl=0.1, cap=True):
	"""Faceted tube along a polyline. Rings are parallel-transported, twisted and jittered."""
	points = [Vector(p) for p in points]
	rings = []
	tangent = (points[1] - points[0]).normalized()
	side = tangent.orthogonal().normalized()
	twist = rng.uniform(0, math.tau)
	for i, (p, r) in enumerate(zip(points, radii)):
		if i < len(points) - 1:
			new_tangent = (points[i + 1] - p).normalized()
			if i > 0:
				new_tangent = ((points[i + 1] - points[i - 1])).normalized()
		else:
			new_tangent = (p - points[i - 1]).normalized()
		side = (side - new_tangent * side.dot(new_tangent)).normalized()
		tangent = new_tangent
		up = tangent.cross(side)
		twist += rng.uniform(0.15, 0.45)
		ring = []
		for k in range(sides):
			a = twist + k * math.tau / sides
			wobble = 1.0 + rng.uniform(-gnarl, gnarl)
			ring.append(bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * r * wobble))
		rings.append(ring)
	for a, b in zip(rings, rings[1:]):
		for k in range(sides):
			bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
	if cap:
		tip = bm.verts.new(points[-1] + tangent * radii[-1] * 0.8)
		last = rings[-1]
		for k in range(sides):
			bm.faces.new((last[k], last[(k + 1) % sides], tip))
	return rings


def lerp_points(a, b, bow, steps):
	"""Points from a to b bowed sideways/upwards, so limbs curve like they reached for light."""
	a, b = Vector(a), Vector(b)
	out = []
	for i in range(steps + 1):
		t = i / steps
		p = a.lerp(b, t) + Vector(bow) * math.sin(t * math.pi)
		out.append(p)
	return out


def taper(r0, r1, count):
	return [r0 + (r1 - r0) * (i / (count - 1)) ** 0.8 for i in range(count)]


def build_wood():
	bm = bmesh.new()
	T = Vector((0.1, 0.05, 1.75))
	# Trunk with a buttressed base: lobed first ring, then a slight lean and twist.
	trunk = [Vector((0, 0, -0.1)), Vector((0.02, 0, 0.35)), Vector((0.06, 0.02, 0.9)), Vector((0.04, 0.07, 1.35)), T, T + Vector((0.02, 0.02, 0.32))]
	tube(bm, trunk, [0.44, 0.33, 0.28, 0.26, 0.24, 0.17], 7, gnarl=0.07)
	# Roots flare out and sink below the ground line.
	for k in range(5):
		a = k * math.tau / 5 + rng.uniform(-0.3, 0.3)
		d = Vector((math.cos(a), math.sin(a), 0))
		length = rng.uniform(0.75, 1.0)
		pts = [d * 0.1 + Vector((0, 0, 0.6)), d * 0.36 + Vector((0, 0, 0.2)),
			d * (0.62 * length + 0.1) + Vector((0, 0, 0.02)), d * (0.95 * length + 0.1) + Vector((0, 0, -0.06))]
		tube(bm, pts, [0.2, 0.15, 0.08, 0.03], 5, gnarl=0.1)
	limbs = {
		'east': (T, T + Vector((1.75, 0.45, 1.5)), (0.15, -0.1, 0.35)),
		'west': (T, T + Vector((-1.55, 1.0, 1.35)), (-0.1, 0.1, 0.35)),
		'south': (T, T + Vector((-0.35, -1.6, 1.55)), (0.1, -0.05, 0.3)),
		'leader': (T, T + Vector((-0.12, 0.05, 2.15)), (0.18, 0.05, 0.0)),
	}
	tips = {}
	for name, (a, b, bow) in limbs.items():
		pts = lerp_points(a - Vector((0, 0, 0.3)), b, bow, 4)
		r0 = 0.19 if name != 'leader' else 0.16
		tube(bm, pts, taper(r0, 0.05, len(pts)), 6 if name != 'leader' else 5, gnarl=0.08)
		tips[name] = pts
	# Secondary branches leave the limbs part-way and end inside their own clumps.
	sub = [
		('east', 2, Vector((0.95, -0.55, 2.05)), (0, -0.1, 0.25)),
		('west', 2, Vector((-0.7, 1.55, 1.25)), (0, 0.1, 0.2)),
		('south', 2, Vector((0.65, -1.2, 1.85)), (0.1, 0, 0.2)),
		('south', 1, Vector((-1.25, -0.95, 0.95)), (-0.1, 0, 0.15)),
		('east', 1, Vector((1.25, 1.1, 1.05)), (0, 0.1, 0.15)),
	]
	sub_tips = []
	for limb, index, offset, bow in sub:
		start = tips[limb][index]
		end = T + offset
		pts = lerp_points(start, end, bow, 3)
		tube(bm, pts, taper(0.1, 0.035, len(pts)), 5, gnarl=0.1)
		sub_tips.append(end)
	return bm, T, tips, sub_tips


# ---------------------------------------------------------------- leaves

def clump(bm, centre, radius, squash=0.8, points=30):
	"""Faceted leaf clump: convex hull of jittered points, so facets vary in size like hand-cut low poly."""
	centre = Vector(centre)
	offset = Vector((rng.uniform(-50, 50), rng.uniform(-50, 50), rng.uniform(-50, 50)))
	floor = -0.38 * radius * squash
	verts = []
	golden = math.pi * (3 - math.sqrt(5))
	for i in range(points):
		z = 1 - 2 * (i + rng.uniform(0.2, 0.8)) / points
		ring = math.sqrt(max(0.0, 1 - z * z))
		a = i * golden + rng.uniform(-0.35, 0.35)
		d = Vector((math.cos(a) * ring, math.sin(a) * ring, z))
		r = radius * (1.0 + 0.13 * noise.noise(d * 1.3 + offset) + rng.uniform(-0.05, 0.05))
		local = Vector((d.x * r, d.y * r, d.z * r * squash))
		if local.z < floor:
			local.z = floor + (local.z - floor) * 0.25
		verts.append(bm.verts.new(centre + local))
	result = bmesh.ops.convex_hull(bm, input=verts)
	loose = [v for v in result['geom_interior'] + result['geom_unused'] if isinstance(v, bmesh.types.BMVert)]
	bmesh.ops.delete(bm, geom=loose, context='VERTS')


def build_leaves(T, tips, sub_tips):
	"""One oak crown: clumps on every limb tip, a domed top tier and fillers where the ring gaps."""
	bm = bmesh.new()
	clumps = [(tips[n][-1] + Vector((0, 0, 0.12)), r) for n, r in (('east', 1.0), ('west', 1.0), ('south', 1.0))]
	clumps += [(p + Vector((0, 0, 0.12)), r) for p, r in zip(sub_tips, (0.95, 0.85, 0.9, 0.75, 0.78))]
	for angle, reach, z, radius in ((75, 1.55, 3.35, 0.9), (185, 1.65, 3.2, 0.9)):
		a = math.radians(angle)
		clumps.append((Vector((math.cos(a) * reach, math.sin(a) * reach, z)), radius))
	# Domed top tier.
	clumps += [
		(Vector((0.0, 0.1, 4.25)), 1.15),
		(Vector((0.95, -0.3, 4.0)), 0.95),
		(Vector((-0.85, 0.65, 3.95)), 1.0),
		(Vector((0.1, -0.95, 3.9)), 0.92),
		(Vector((0.35, 1.05, 3.85)), 0.88),
	]
	for centre, radius in clumps:
		clump(bm, centre, radius * rng.uniform(0.95, 1.05))
	return bm


# ---------------------------------------------------------------- colour

def paint(obj, colour_for_face):
	mesh = obj.data
	attr = mesh.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
	for poly in mesh.polygons:
		c = colour_for_face(poly)
		for li in poly.loop_indices:
			attr.data[li].color = (c.x, c.y, c.z, 1.0)
	mesh.color_attributes.active_color = attr
	mesh.color_attributes.render_color_index = 0
	for poly in mesh.polygons:
		poly.use_smooth = False


def leaf_colour(bounds):
	zmin, zmax, spread = bounds

	def colour(poly):
		c, n = poly.center, poly.normal
		h = (c.z - zmin) / (zmax - zmin)
		outward = min(1.0, Vector((c.x, c.y)).length / spread)
		light = 0.45 * h + 0.3 * outward + 0.35 * max(n.z, 0.0) - 0.25 * max(-n.z, 0.0)
		base = mix(LEAF_DARK, LEAF_MID, light * 1.4) if light < 0.7 else mix(LEAF_MID, LEAF_LIGHT, (light - 0.7) * 2.2)
		if rng.random() < 0.06:
			base = mix(base, LEAF_WARM, 0.22)
		return base * rng.uniform(0.94, 1.05)
	return colour


def bark_colour(poly):
	c, n = poly.center, poly.normal
	h = min(1.0, max(0.0, c.z / 3.0))
	lit = 0.35 + 0.45 * h + 0.2 * max(n.z, 0.0)
	return mix(BARK_DARK, BARK_LIGHT, lit) * rng.uniform(0.88, 1.1)


def material(name, roughness):
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	nodes = mat.node_tree.nodes
	bsdf = nodes['Principled BSDF']
	bsdf.inputs['Roughness'].default_value = roughness
	vc = nodes.new('ShaderNodeVertexColor')
	vc.layer_name = 'Col'
	mat.node_tree.links.new(vc.outputs['Color'], bsdf.inputs['Base Color'])
	return mat


def to_object(bm, name, collection):
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(name, mesh)
	collection.objects.link(obj)
	return obj


# ---------------------------------------------------------------- build

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
asset = bpy.data.collections.new('EXPORT - hero oak')
scene.collection.children.link(asset)

wood_bm, T, tips, sub_tips = build_wood()
leaf_bm = build_leaves(T, tips, sub_tips)
bark = to_object(wood_bm, 'Bark', asset)
leaves = to_object(leaf_bm, 'Leaves', asset)
def merge_crown(obj):
	"""Union the clumps: drops hidden interior faces and the slivers where a clump tip pokes through."""
	bpy.context.view_layer.objects.active = obj
	mod = obj.modifiers.new('Union', 'BOOLEAN')
	mod.operation = 'UNION'
	mod.operand_type = 'COLLECTION'
	mod.solver = 'EXACT'
	mod.use_self = True
	bpy.ops.object.modifier_apply(modifier=mod.name)
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.04)
	bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.02)
	bmesh.ops.triangulate(bm, faces=bm.faces)
	bm.to_mesh(obj.data)
	bm.free()


before = len(leaves.data.polygons)
merge_crown(leaves)
print('HERO_OAK crown faces', before, '->', len(leaves.data.polygons))
zs = [v.co.z for v in leaves.data.vertices]
spread = max(Vector((v.co.x, v.co.y)).length for v in leaves.data.vertices)
paint(leaves, leaf_colour((min(zs), max(zs), spread)))
paint(bark, bark_colour)
bark.data.materials.append(material('Bark', 0.95))
leaves.data.materials.append(material('Leaves', 0.85))
root = bpy.data.objects.new('HeroOak', None)
asset.objects.link(root)
root['description'] = 'Faceted hero oak; origin at ground contact. Leaves palette_role 2, bark palette_role 4.'
root['crown_top_m'] = round(max(zs), 2)
root['crown_bottom_m'] = round(min(zs), 2)
bark.parent = root
leaves.parent = root
print('HERO_OAK faces bark', len(bark.data.polygons), 'leaves', len(leaves.data.polygons),
	'height', round(max(zs), 2), 'spread', round(spread, 2))

# ---------------------------------------------------------------- preview stage (not exported)

stage = bpy.data.collections.new('PREVIEW - stage')
scene.collection.children.link(stage)
ground_bm = bmesh.new()
bmesh.ops.create_grid(ground_bm, x_segments=14, y_segments=14, size=7.5)
for v in ground_bm.verts:
	v.co.z = 0.12 * noise.noise(v.co * 0.35) + rng.uniform(-0.03, 0.03) - 0.02
	v.co.x += rng.uniform(-0.15, 0.15)
	v.co.y += rng.uniform(-0.15, 0.15)
bmesh.ops.triangulate(ground_bm, faces=ground_bm.faces)
ground = to_object(ground_bm, 'Ground', stage)
paint(ground, lambda p: mix(GRASS, GRASS_LIGHT, rng.random()) * rng.uniform(0.92, 1.05))
ground.data.materials.append(material('Ground', 1.0))

# A source-style conifer next to it, for scale and style comparison.
pine_bm = bmesh.new()
tube(pine_bm, [(0, 0, -0.1), (0, 0, 1.2)], [0.16, 0.12], 6, gnarl=0.02)
for z, r, h in ((1.0, 1.25, 2.2), (2.1, 1.0, 1.9), (3.1, 0.75, 1.7), (4.0, 0.5, 1.5)):
	cone = bmesh.ops.create_cone(pine_bm, cap_ends=True, segments=7, radius1=r, radius2=0.0, depth=h)
	for v in cone['verts']:
		v.co.z += z + h / 2
pine = to_object(pine_bm, 'Pine', stage)
pine.location = (4.2, 2.6, 0)
pine.scale = (1.0, 1.0, 1.1)
paint(pine, lambda p: (BARK_LIGHT if p.center.z < 1.05 and abs(p.normal.z) < 0.9 and Vector((p.center.x, p.center.y)).length < 0.2
	else mix(srgb('2f6a34'), srgb('4f8a44'), 0.5 + 0.5 * p.normal.z) * rng.uniform(0.9, 1.08)))
pine.data.materials.append(material('Pine', 0.9))

BLEND.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

# ---------------------------------------------------------------- export

bpy.ops.object.select_all(action='DESELECT')
for o in (root, bark, leaves):
	o.select_set(True)
bpy.context.view_layer.objects.active = root
GLB.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(GLB), export_format='GLB', use_selection=True,
	export_animations=False, export_cameras=False, export_lights=False, export_extras=True,
	export_yup=True, export_vertex_color='ACTIVE')
print('HERO_OAK_EXPORT', GLB)

if '--no-render' in args:
	raise SystemExit

# ---------------------------------------------------------------- previews

world = bpy.data.worlds.new('Dusk')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (*srgb('4a3c44'), 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.4
scene.world = world
sun_data = bpy.data.lights.new('Sun', 'SUN')
sun_data.energy = 3.2
sun_data.color = srgb('fff0d8')
sun_data.angle = math.radians(3)
sun = bpy.data.objects.new('Sun', sun_data)
stage.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, math.radians(35))
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1280, 960
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
try:
	scene.eevee.taa_render_samples = 32
except AttributeError:
	pass
cam_data = bpy.data.cameras.new('Cam')
cam = bpy.data.objects.new('Cam', cam_data)
stage.objects.link(cam)
scene.camera = cam
PREVIEWS.mkdir(parents=True, exist_ok=True)
views = {
	'three-quarter': ((9.5, -10.5, 6.8), (0.6, 0.4, 2.2), 50),
	'low-hero': ((4.6, -6.2, 0.9), (0.0, 0.0, 2.7), 30),
	'diorama': ((8.5, -8.5, 12.0), (0.8, 0.5, 1.5), 45),
	'side': ((-11.0, -3.0, 3.2), (0.3, 0.3, 2.4), 45),
}
for name, (loc, target, lens) in views.items():
	cam.location = loc
	cam_data.lens = lens
	cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
	scene.render.filepath = str(PREVIEWS / f'{name}.png')
	bpy.ops.render.render(write_still=True)
	print('HERO_OAK_RENDER', scene.render.filepath)
