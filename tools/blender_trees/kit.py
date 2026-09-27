"""Shared faceted-plant helpers for the Blender species builders in this folder.

Each species script builds bmeshes with these helpers, then calls finish(), which bakes
per-face colour into COLOR_0, saves art/blender/trees/<name>.blend, exports
assets/models/<name>.glb and, unless --no-render is passed, renders previews to
/tmp/zs-tree-previews/<name>/. Metres, origin at the ground contact, Blender Z-up.
"""
import bpy, bmesh, math, random, sys
from pathlib import Path
from mathutils import Vector, Matrix, noise

ROOT = Path(__file__).resolve().parents[2]
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
rng = random.Random(0)


def seed(value):
	rng.seed(value)


def srgb(hex_value):
	c = [int(hex_value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	return Vector([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c])


def mix(a, b, t):
	return a.lerp(b, max(0.0, min(1.0, t)))


def tube(bm, points, radii, sides, gnarl=0.1, cap=True, profile=None, twist_step=(0.15, 0.45)):
	"""Faceted tube along a polyline; rings are parallel-transported, twisted and jittered.
	profile(k, i) scales ring vertex k of ring i, e.g. for fluted trunks. Returns the rings."""
	points = [Vector(p) for p in points]
	rings = []
	tangent = (points[1] - points[0]).normalized()
	side = tangent.orthogonal().normalized()
	twist = rng.uniform(0, math.tau)
	for i, (p, r) in enumerate(zip(points, radii)):
		if i == 0:
			new_tangent = (points[1] - p).normalized()
		elif i < len(points) - 1:
			new_tangent = (points[i + 1] - points[i - 1]).normalized()
		else:
			new_tangent = (p - points[i - 1]).normalized()
		side = (side - new_tangent * side.dot(new_tangent)).normalized()
		tangent = new_tangent
		up = tangent.cross(side)
		twist += rng.uniform(*twist_step)
		ring = []
		for k in range(sides):
			a = twist + k * math.tau / sides
			scale = (1.0 + rng.uniform(-gnarl, gnarl)) * (profile(k, i) if profile else 1.0)
			ring.append(bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * r * scale))
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


def bowed(a, b, bow, steps):
	"""Points from a to b bowed by the vector bow at the middle."""
	a, b = Vector(a), Vector(b)
	return [a.lerp(b, i / steps) + Vector(bow) * math.sin(i / steps * math.pi) for i in range(steps + 1)]


def taper(r0, r1, count, power=0.8):
	return [r0 + (r1 - r0) * (i / (count - 1)) ** power for i in range(count)]


def clump(bm, centre, radius, squash=0.8, points=30, floor=-0.38, stretch=(1.0, 1.0)):
	"""Faceted foliage clump: convex hull of jittered points, flattened underneath."""
	centre = Vector(centre)
	offset = Vector((rng.uniform(-50, 50), rng.uniform(-50, 50), rng.uniform(-50, 50)))
	spin = rng.uniform(0, math.tau)
	floor_z = floor * radius * squash
	golden = math.pi * (3 - math.sqrt(5))
	verts = []
	for i in range(points):
		z = 1 - 2 * (i + rng.uniform(0.2, 0.8)) / points
		ring = math.sqrt(max(0.0, 1 - z * z))
		a = i * golden + rng.uniform(-0.35, 0.35)
		d = Vector((math.cos(a) * ring, math.sin(a) * ring, z))
		r = radius * (1.0 + 0.13 * noise.noise(d * 1.3 + offset) + rng.uniform(-0.05, 0.05))
		x, y = d.x * r * stretch[0], d.y * r * stretch[1]
		local = Vector((x * math.cos(spin) - y * math.sin(spin), x * math.sin(spin) + y * math.cos(spin), d.z * r * squash))
		if local.z < floor_z:
			local.z = floor_z + (local.z - floor_z) * 0.25
		verts.append(bm.verts.new(centre + local))
	result = bmesh.ops.convex_hull(bm, input=verts)
	loose = [v for v in result['geom_interior'] + result['geom_unused'] if isinstance(v, bmesh.types.BMVert)]
	bmesh.ops.delete(bm, geom=loose, context='VERTS')


def spike(bm, base, direction, length, width, sides=3):
	"""A thin faceted blade (Joshua and yucca leaves)."""
	direction = Vector(direction).normalized()
	side = direction.orthogonal().normalized()
	up = direction.cross(side)
	twist = rng.uniform(0, math.tau)
	ring = []
	for k in range(sides):
		a = twist + k * math.tau / sides
		ring.append(bm.verts.new(Vector(base) + (side * math.cos(a) + up * math.sin(a)) * width))
	tip = bm.verts.new(Vector(base) + direction * length)
	for k in range(sides):
		bm.faces.new((ring[k], ring[(k + 1) % sides], tip))


def to_object(bm, name, collection):
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(name, mesh)
	collection.objects.link(obj)
	return obj


def merge_shell(obj, weld=0.04, planar=0.0):
	"""Union overlapping clumps into one watertight shell with no hidden interior faces.
	planar (degrees) re-merges the coplanar slivers the union cuts, keeping the budget."""
	bpy.context.view_layer.objects.active = obj
	mod = obj.modifiers.new('Union', 'BOOLEAN')
	mod.operation = 'UNION'
	mod.operand_type = 'COLLECTION'
	mod.solver = 'EXACT'
	mod.use_self = True
	bpy.ops.object.modifier_apply(modifier=mod.name)
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=weld)
	bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.02)
	if planar > 0.0:
		bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(planar), verts=bm.verts, edges=bm.edges)
	bmesh.ops.triangulate(bm, faces=bm.faces)
	bm.to_mesh(obj.data)
	boundary = sum(1 for e in bm.edges if e.is_boundary)
	bm.free()
	return boundary


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


def pine(stage, location, height=6.0):
	"""The source scenes' cone-stack conifer, for scale and style comparison."""
	bm = bmesh.new()
	tube(bm, [(0, 0, -0.1), (0, 0, 1.2)], [0.16, 0.12], 6, gnarl=0.02)
	for z, r, h in ((1.0, 1.25, 2.2), (2.1, 1.0, 1.9), (3.1, 0.75, 1.7), (4.0, 0.5, 1.5)):
		cone = bmesh.ops.create_cone(bm, cap_ends=True, segments=7, radius1=r, radius2=0.0, depth=h)
		for v in cone['verts']:
			v.co.z += z + h / 2
	obj = to_object(bm, 'Pine', stage)
	obj.location = location
	obj.scale = (height / 5.5,) * 3
	trunk, dark, light = srgb('7a4c33'), srgb('2f6a34'), srgb('4f8a44')
	paint(obj, lambda p: trunk if p.center.z < 1.05 and Vector((p.center.x, p.center.y)).length < 0.2
		else mix(dark, light, 0.5 + 0.5 * p.normal.z) * rng.uniform(0.9, 1.08))
	obj.data.materials.append(material('Pine', 0.9))
	return obj


def ground(stage, size, low, high, relief=0.12):
	bm = bmesh.new()
	bmesh.ops.create_grid(bm, x_segments=16, y_segments=16, size=size)
	cell = size / 8
	for v in bm.verts:
		v.co.z = relief * noise.noise(v.co * (2.6 / size)) + rng.uniform(-0.03, 0.03) - 0.02
		v.co.x += rng.uniform(-0.12, 0.12) * cell
		v.co.y += rng.uniform(-0.12, 0.12) * cell
	bmesh.ops.triangulate(bm, faces=bm.faces)
	obj = to_object(bm, 'Ground', stage)
	paint(obj, lambda p: mix(low, high, rng.random()) * rng.uniform(0.92, 1.05))
	obj.data.materials.append(material('Ground', 1.0))
	return obj


def finish(name, parts, extras, stage_builder, views, sun_rotation=(50, 0, 35)):
	"""parts: list of (object, material name, roughness). Saves, exports and renders."""
	scene = bpy.context.scene
	root = bpy.data.objects.new(name.title().replace('-', ''), None)
	parts[0][0].users_collection[0].objects.link(root)
	for key, value in extras.items():
		root[key] = value
	for obj, mat_name, rough in parts:
		obj.data.materials.append(material(mat_name, rough))
		obj.parent = root
	stage = bpy.data.collections.new('PREVIEW - stage')
	scene.collection.children.link(stage)
	stage_builder(stage)
	blend = ROOT / f'art/blender/trees/zenscape-{name}.blend'
	glb = ROOT / f'assets/models/zenscape-{name}.glb'
	blend.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=str(blend))
	bpy.ops.object.select_all(action='DESELECT')
	root.select_set(True)
	for obj, _, _ in parts:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = root
	glb.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True,
		export_animations=False, export_cameras=False, export_lights=False, export_extras=True,
		export_yup=True, export_vertex_color='ACTIVE')
	faces = {obj.name: len(obj.data.polygons) for obj, _, _ in parts}
	print('TREE_EXPORT', name, glb, faces)
	if '--no-render' in ARGS:
		return
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
	sun.rotation_euler = [math.radians(a) for a in sun_rotation]
	scene.render.engine = 'BLENDER_EEVEE'
	scene.render.resolution_x, scene.render.resolution_y = 1280, 960
	scene.view_settings.view_transform = 'Standard'
	cam_data = bpy.data.cameras.new('Cam')
	cam = bpy.data.objects.new('Cam', cam_data)
	stage.objects.link(cam)
	scene.camera = cam
	out = Path('/tmp/zs-tree-previews') / name
	out.mkdir(parents=True, exist_ok=True)
	for view, (loc, target, lens) in views.items():
		cam.location = loc
		cam_data.lens = lens
		cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
		scene.render.filepath = str(out / f'{view}.png')
		bpy.ops.render.render(write_still=True)
	print('TREE_RENDERS', out)


def fresh_scene(collection_name):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	asset = bpy.data.collections.new(collection_name)
	bpy.context.scene.collection.children.link(asset)
	return asset
