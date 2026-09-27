"""Render tools/dump_life_models.gd's dump as a contact sheet in Blender:

  blender -b --python tools/render_life_models.py -- --in=/tmp/zs-life-models/models.json
      [--out=/tmp/zs-life-models/sheet.png] [--group=fish|frog|spawn] [--views=game,side,top,close]
      [--tile=320]

One row per specimen, one column per view: `game` looks down at the game's
default pitch from far enough that the creature is the size it is on screen
at a close zoom; `side`, `top` and `close` (a low 3/4 from the front) are for
judging the design. The raw vertex colour times the instance tint goes in as
linear albedo, as reference_surface takes it. Godot's y-up metres become
Blender's z-up as (x, -z, y). Fish sit under a pale water tint over a pond
bed; frogs and spawn sit on a bank.
"""
import bpy, json, math, sys
from pathlib import Path
import numpy as np
from mathutils import Vector

ARGV = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ARGS = dict(a.lstrip('-').split('=', 1) if '=' in a else (a.lstrip('-'), '1') for a in ARGV)
SOURCE = Path(ARGS.get('in', '/tmp/zs-life-models/models.json'))
OUT = Path(ARGS.get('out', str(SOURCE.with_suffix('.png'))))
GROUP = ARGS.get('group', '')
VIEWS = ARGS.get('views', 'game,side,top,close').split(',')
TILE = int(ARGS.get('tile', 320))
ONLY = ARGS.get('only', '')

specimens = json.load(open(SOURCE))
if GROUP: specimens = [s for s in specimens if s['group'] in GROUP.split(',')]
if ONLY: specimens = [s for s in specimens if any(k in s['name'] for k in ONLY.split(','))]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = TILE
scene.render.resolution_y = int(TILE * 0.75)
scene.view_settings.view_transform = 'Standard'
try: scene.eevee.taa_render_samples = 16
except AttributeError: pass
world = bpy.data.worlds.new('sky')
scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (0.42, 0.52, 0.66, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = 0.55

sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
sun.data.energy = 3.2
sun.data.color = (1.0, 0.9, 0.78)
sun.data.angle = math.radians(3)
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
scene.collection.objects.link(sun)
fill = bpy.data.objects.new('fill', bpy.data.lights.new('fill', 'SUN'))
fill.data.energy = 0.6
fill.data.color = (0.6, 0.72, 0.95)
fill.rotation_euler = (math.radians(-60), 0, math.radians(200))
scene.collection.objects.link(fill)


def b(x, y, z):
	return (x, -z, y)


def flat_material(name, rgb, alpha=1.0):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes['Principled BSDF']
	bsdf.inputs['Base Color'].default_value = (*rgb, 1)
	bsdf.inputs['Roughness'].default_value = 0.9
	if alpha < 1.0:
		bsdf.inputs['Alpha'].default_value = alpha
		try: m.surface_render_method = 'BLENDED'
		except AttributeError: m.blend_method = 'BLEND'
	return m


def plane(name, z, size, material):
	mesh = bpy.data.meshes.new(name)
	h = size / 2
	mesh.from_pydata([(-h, -h, z), (h, -h, z), (h, h, z), (-h, h, z)], [], [(0, 1, 2, 3)])
	obj = bpy.data.objects.new(name, mesh)
	obj.data.materials.append(material)
	scene.collection.objects.link(obj)
	return obj


bank = plane('bank', 0.0, 6, flat_material('bank', (0.16, 0.2, 0.09)))
bed = plane('bed', -0.34, 6, flat_material('bed', (0.12, 0.13, 0.09)))
water = plane('water', 0.07, 6, flat_material('water', (0.3, 0.45, 0.5), 0.28))

creature_material = bpy.data.materials.new('creature')
creature_material.use_nodes = True
nodes = creature_material.node_tree.nodes
links = creature_material.node_tree.links
bsdf = nodes['Principled BSDF']
bsdf.inputs['Roughness'].default_value = 0.72
attr = nodes.new('ShaderNodeVertexColor')
attr.layer_name = 'paint'
links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])


def build(spec):
	p = spec['positions']
	c = spec['colors']
	tint = spec['tint']
	verts = [b(p[i], p[i + 1], p[i + 2]) for i in range(0, len(p), 3)]
	faces = [(i, i + 1, i + 2) for i in range(0, len(verts), 3)]
	mesh = bpy.data.meshes.new(spec['name'])
	mesh.from_pydata(verts, [], faces)
	layer = mesh.color_attributes.new('paint', 'FLOAT_COLOR', 'POINT')
	for i in range(len(verts)):
		layer.data[i].color = (c[i * 3] * tint[0], c[i * 3 + 1] * tint[1], c[i * 3 + 2] * tint[2], 1)
	mesh.materials.append(creature_material)
	obj = bpy.data.objects.new(spec['name'], mesh)
	scene.collection.objects.link(obj)
	return obj, verts


camera = bpy.data.objects.new('camera', bpy.data.cameras.new('camera'))
scene.collection.objects.link(camera)
scene.camera = camera


def aim(eye, target, lens):
	camera.location = eye
	direction = Vector(target) - Vector(eye)
	camera.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
	camera.data.lens = lens


def pond(company, frogs, name):
	"""A round pond at the game's camera pitch: `company` fish swimming in it,
	`frogs` [name, place] on and off its bank ('bank', 'leap' or 'swim')."""
	for o in (bank, bed, water): o.hide_render = False
	bank.location.z = 0.0
	bed.location.z = -0.1
	water.location.z = 0.0
	# A bank with a round hole cut through it for the water.
	import bmesh
	ring = bpy.data.meshes.new('ring')
	bm = bmesh.new()
	inner, outer, n = 1.6, 3.0, 40
	vs = [(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0.03 if r == inner else 0.0))) for a in [i * math.tau / n for i in range(n)] for r in (inner, outer)]
	for i in range(n):
		a, b2, c, d = vs[2 * i], vs[2 * i + 1], vs[(2 * i + 3) % (2 * n)], vs[(2 * i + 2) % (2 * n)]
		bm.faces.new((a, b2, c, d))
	bm.to_mesh(ring)
	ring_obj = bpy.data.objects.new('ring', ring)
	ring_obj.data.materials.append(bank.data.materials[0])
	scene.collection.objects.link(ring_obj)
	bank.hide_render = True
	placed = []
	rng = __import__('random').Random(7)
	for k, kind in enumerate(company):
		spec = next(s for s in specimens if s['name'] == kind)
		obj, _ = build(spec)
		angle = k * math.tau / len(company) + rng.uniform(-0.3, 0.3)
		r = rng.uniform(0.35, 1.15)
		size = rng.uniform(0.85, 1.15)
		obj.scale = (size, size, size)
		obj.location = (math.cos(angle) * r, math.sin(angle) * r, -0.1)
		obj.rotation_euler = (0, 0, angle + math.pi * rng.choice((0.5, -0.5)) + rng.uniform(-0.4, 0.4))
		placed.append(obj)
	for k, (kind, place) in enumerate(frogs):
		spec = next(s for s in specimens if s['name'] == kind)
		obj, _ = build(spec)
		angle = 0.4 + k * 1.3
		size = rng.uniform(1.0, 1.3)  # land_life's range; the dump already holds the kind's size
		obj.scale = (size, size, size)
		out = 1.95 if place == 'bank' else (1.55 if place == 'leap' else 1.2)
		obj.location = (math.cos(angle) * out, math.sin(angle) * out, 0.03 if place == 'bank' else (0.3 if place == 'leap' else -0.14 * size))
		# Frogs face the water; a leaper faces out over it.
		obj.rotation_euler = (math.radians(-12) if place == 'leap' else 0, 0, angle + math.pi / 2 + (math.pi if place != 'swim' else 0) + rng.uniform(-0.3, 0.3))
		placed.append(obj)
	pitch = math.radians(42)
	yaw = math.radians(-30)
	d = 7.5
	eye = Vector((math.sin(yaw) * math.cos(pitch) * d, -math.cos(yaw) * math.cos(pitch) * d, math.sin(pitch) * d))
	aim(eye, (0, 0, 0), 50)
	scene.render.resolution_x, scene.render.resolution_y = TILE * 2, int(TILE * 1.25)
	scene.render.filepath = str(OUT.parent / f'{name}.png')
	bpy.ops.render.render(write_still=True)
	for o in placed + [ring_obj]: bpy.data.objects.remove(o)
	print('pond', OUT.parent / f'{name}.png')


if 'pond' in ARGS:
	pond(['kohaku 0', 'kohaku 1', 'sanke 0', 'sanke 2', 'showa 1', 'ogon 0', 'asagi 0', 'chagoi 0'], [['pool sit', 'bank'], ['common leap', 'leap'], ['pool leap', 'swim']], 'pond-koi')
	pond(['rudd 0', 'rudd 0', 'perch 0', 'perch 0', 'carp 0', 'tench 0', 'goldfish 0'], [['toad sit', 'bank'], ['common sit', 'bank'], ['leopard leap', 'swim']], 'pond-wild')
	sys.exit(0)

tiles = []
rows = []
tmp = OUT.parent / 'tiles'
tmp.mkdir(parents=True, exist_ok=True)
for index, spec in enumerate(specimens):
	obj, verts = build(spec)
	xs = [v[0] for v in verts]; ys = [v[1] for v in verts]; zs = [v[2] for v in verts]
	center = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2))
	size = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
	fish = spec['group'] == 'fish'
	if fish:
		obj.location = (0, 0, -0.07)
		center.z -= 0.07
	bank.hide_render = fish
	bed.hide_render = not fish
	water.hide_render = not fish
	row = []
	for view in VIEWS:
		reach = size * 2.6
		if view == 'game':
			# The game's default camera looks down ~35 degrees; at close zoom a
			# fish or frog is ~40 px long in a 1440 px frame.
			pitch = math.radians(35)
			yaw = math.radians(-35)
			d = size * 12.0
			eye = center + Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch))) * d
			aim(eye, center, 50)
		elif view == 'side':
			aim(center + Vector((reach, 0, 0.02)), center, 50)
		elif view == 'top':
			aim(center + Vector((0, -0.001, reach * 1.05)), center, 50)
		else:
			yaw = math.radians(-40)
			eye = center + Vector((math.sin(yaw) * reach * 0.8, -math.cos(yaw) * reach * 0.8, reach * 0.42))
			aim(eye, center, 50)
		path = tmp / f'{index:02d}-{view}.png'
		scene.render.filepath = str(path)
		bpy.ops.render.render(write_still=True)
		row.append(path)
	rows.append(row)
	bpy.data.objects.remove(obj)
	print(f'row {index}: {spec["name"]}')

W, H = TILE, int(TILE * 0.75)
sheet = np.ones((H * len(rows), W * len(VIEWS), 4), dtype=np.float32)
for r, row in enumerate(rows):
	for k, path in enumerate(row):
		image = bpy.data.images.load(str(path))
		pixels = np.array(image.pixels[:], dtype=np.float32).reshape(H, W, 4)
		y0 = (len(rows) - 1 - r) * H
		sheet[y0:y0 + H, k * W:(k + 1) * W] = pixels
		bpy.data.images.remove(image)
out = bpy.data.images.new('sheet', W * len(VIEWS), H * len(rows), alpha=True)
out.pixels = sheet.ravel()
out.filepath_raw = str(OUT)
out.file_format = 'PNG'
out.save()
print('sheet', OUT)
