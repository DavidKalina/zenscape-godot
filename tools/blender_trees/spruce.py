"""Faceted spruce family: six variants at the source conifer's scale (foliage.js, ADR 0015).

Each tier is a closed bicone with a star rim (bough tips and notches) that droops at the
edge. Canopy colour is baked as greyscale light and shade only: the game tints conifers
per instance, and a green bake would multiply tint on tint. Bark is greyscale for the
same reason. One .glb holds every variant as its own root node at the origin.

Run: blender -b --factory-startup --python tools/blender_trees/spruce.py [-- --no-render]
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy, bmesh
from mathutils import Vector
import kit
from kit import rng, srgb, mix, ARGS

kit.seed(31)
WIND = Vector((1, 0, 0))

VARIANTS = {
	# height, bole, tiers, spread, taper, boughs, droop
	'mature': dict(H=2.8, b=0.45, T=6, spread=0.62, taper=0.78, n=8, droop=0.35),
	'young': dict(H=1.7, b=0.12, T=4, spread=0.6, taper=0.7, n=7, droop=0.25),
	'windswept': dict(H=2.6, b=0.5, T=6, spread=0.6, taper=0.78, n=8, droop=0.3, lean=0.3),
	'dead-top': dict(H=3.0, b=0.55, T=5, spread=0.6, taper=0.7, n=8, droop=0.35, live=0.7),
	'sparse': dict(H=2.9, b=0.8, T=5, spread=0.62, taper=0.75, n=7, droop=0.45, gaps=2),
	'spire': dict(H=3.3, b=0.35, T=8, spread=0.46, taper=0.82, n=8, droop=0.3),
}


def axis_at(z, P):
	"""Trunk centreline; the windswept tree bends downwind with height."""
	lean = P.get('lean', 0.0) * (max(z, 0.0) / P['H']) ** 1.6
	return Vector((0.03 * math.sin(z * 2.1), 0.03 * math.cos(z * 1.7), 0)) + WIND * lean + Vector((0, 0, z))


def tier(bm, P, z0, z_top, r, n, droop, gaps):
	apex = axis_at(z_top, P)
	under = axis_at(z0 + 0.2 * (z_top - z0), P)
	centre = axis_at(z0, P)
	twist = rng.uniform(0, math.tau)
	rim = []
	for j in range(2 * n):
		a = twist + j * math.pi / n + rng.uniform(-0.12, 0.12)
		d = Vector((math.cos(a), math.sin(a), 0))
		if j % 2 == 0:
			reach = r * rng.uniform(0.92, 1.1)
			if P.get('lean'):
				# Boughs on the windward side are short and the lee side streams out.
				reach *= 1.0 - 0.3 * d.dot(-WIND) if d.dot(-WIND) > 0 else 1.0 + 0.25 * d.dot(WIND)
			if j // 2 in gaps:
				reach *= 0.4
			z = z0 - droop * reach * rng.uniform(0.8, 1.2)
		else:
			reach = r * 0.68
			z = z0 + 0.1 * r
		rim.append(bm.verts.new(centre + d * reach + Vector((0, 0, z - z0))))
	top, bottom = bm.verts.new(apex), bm.verts.new(under)
	for j in range(2 * n):
		a, b = rim[j], rim[(j + 1) % (2 * n)]
		bm.faces.new((a, b, top))
		bm.faces.new((b, a, bottom))


def build(name, P):
	crown, wood = bmesh.new(), bmesh.new()
	H, b, T = P['H'], P['b'], P['T']
	live_top = H * P.get('live', 1.0)
	span = live_top - b
	step = span / (T - 0.35)
	for i in range(T):
		t = i / (T - 1)
		z0 = b + i * step
		r = P['spread'] * (1 - P['taper'] * t)
		h = step * (1.45 - 0.35 * t)
		gaps = set(rng.sample(range(P['n']), P.get('gaps', 0))) if i < T - 1 else set()
		tier(crown, P, z0, min(z0 + h, live_top + 0.2 if 'live' in P else H), r, P['n'], P['droop'] * (1 - 0.4 * t), gaps)
	# Trunk runs up into the crown; the leader is a thin crooked spike above it.
	zs = [-0.05, b * 0.5, b + step, H * 0.75, H + 0.12]
	kit.tube(wood, [axis_at(z, P) for z in zs], [0.13, 0.11, 0.08, 0.045, 0.012], 5, gnarl=0.06)
	if 'live' in P:
		for z in (live_top + 0.15, live_top + 0.4, live_top + 0.62):
			a = rng.uniform(0, math.tau)
			d = Vector((math.cos(a), math.sin(a), -0.25)).normalized()
			start = axis_at(z, P)
			kit.tube(wood, [start, start + d * rng.uniform(0.18, 0.3)], [0.025, 0.008], 4, gnarl=0.05)
	bmesh.ops.recalc_face_normals(crown, faces=crown.faces)
	return crown, wood


def canopy_value(zmin, zmax):
	def value(poly):
		c, n = poly.center, poly.normal
		h = (c.z - zmin) / max(zmax - zmin, 0.01)
		v = 0.62 + 0.28 * max(n.z, 0) - 0.18 * max(-n.z, 0) + 0.1 * h
		v = max(0.45, min(1.0, v * rng.uniform(0.94, 1.05)))
		return Vector((v, v, v))
	return value


def bark_value(dead_above):
	def value(poly):
		v = rng.uniform(0.72, 1.0)
		if poly.center.z > dead_above:
			v = 1.25 * v  # weathered silver on the dead top
		return Vector((v, v, v))
	return value


def tinted(name, tint, roughness):
	"""Preview-only material: greyscale vertex colour times a stand tint, as the game does."""
	mat = kit.material(name, roughness)
	nodes, links = mat.node_tree.nodes, mat.node_tree.links
	mult = nodes.new('ShaderNodeMix')
	mult.data_type = 'RGBA'
	mult.blend_type = 'MULTIPLY'
	mult.inputs['Factor'].default_value = 1.0
	mult.inputs['B'].default_value = (*tint, 1)
	links.new(nodes['Color Attribute'].outputs['Color'], mult.inputs['A'])
	links.new(mult.outputs['Result'], nodes['Principled BSDF'].inputs['Base Color'])
	return mat


asset = kit.fresh_scene('EXPORT - spruce family')
roots = {}
faces = {}
for name, P in VARIANTS.items():
	crown_bm, wood_bm = build(name, P)
	crown = kit.to_object(crown_bm, f'{name} canopy', asset)
	trunk = kit.to_object(wood_bm, f'{name} trunk', asset)
	zs = [v.co.z for v in crown.data.vertices]
	kit.paint(crown, canopy_value(min(zs), max(zs)))
	kit.paint(trunk, bark_value(P['H'] * P.get('live', 2.0)))
	root = bpy.data.objects.new(f'Spruce_{name.replace("-", "_")}', None)
	asset.objects.link(root)
	root['height_m'] = round(P['H'] + 0.12, 2)
	root['description'] = 'Greyscale canopy and bark: multiply by the stand tint. Origin at ground contact.'
	crown.parent = root
	trunk.parent = root
	roots[name] = (root, crown, trunk)
	faces[name] = len(crown.data.polygons) + len(trunk.data.polygons)
print('SPRUCE faces', faces)

# Export first, every variant at the origin.
glb = kit.ROOT / 'assets/models/zenscape-spruce-family.glb'
bpy.ops.object.select_all(action='DESELECT')
for root, crown, trunk in roots.values():
	crown.data.materials.append(kit.material('Canopy', 0.9))
	trunk.data.materials.append(kit.material('Bark', 0.95))
	for o in (root, crown, trunk):
		o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True,
	export_animations=False, export_cameras=False, export_lights=False, export_extras=True,
	export_yup=True, export_vertex_color='ACTIVE')
print('SPRUCE_EXPORT', glb)

# ---------------------------------------------------------------- preview stage
scene = bpy.context.scene
stage = bpy.data.collections.new('PREVIEW - stage')
scene.collection.children.link(stage)
kit.ground(stage, 9, srgb('5f8c3c'), srgb('86ad4e'))
# Source pine at source scale (2.45 m, three six-sided cones) for comparison.
src = bmesh.new()
kit.tube(src, [(0, 0, -0.02), (0, 0, 0.7)], [0.13, 0.08], 5, gnarl=0.0)
for i in range(3):
	t = i / 2
	step = 1.9 / 2.65
	r, h = 0.55 * (1 - 0.55 * t), step * (1.45 - 0.35 * t)
	cone = bmesh.ops.create_cone(src, cap_ends=True, segments=6, radius1=r, radius2=0.0, depth=h)
	for v in cone['verts']:
		v.co.z += 0.55 + i * step + h / 2
source = kit.to_object(src, 'Source pine', stage)
kit.paint(source, lambda p: Vector((1, 1, 1)))
source.data.materials.append(tinted('Source', srgb('3f7a3c'), 0.9))
source.location = (-4.6, 0, 0)

greens = [srgb(h) for h in ('35683a', '3f7a3c', '2f5f3a', '46784a', '3a6c40', '2f6a44')]
bark_tint = srgb('635c56')
for i, (name, (root, crown, trunk)) in enumerate(roots.items()):
	crown.data.materials.clear()
	trunk.data.materials.clear()
	crown.data.materials.append(tinted(f'{name} green', greens[i], 0.9))
	trunk.data.materials.append(tinted(f'{name} bark', bark_tint, 0.95))
	root.location = (-3.0 + i * 1.55, 0, 0)

# A grove: linked copies with per-instance scale, spin and tint, the way the game scatters them.
grove = bpy.data.collections.new('PREVIEW - grove')
scene.collection.children.link(grove)
names = list(roots)
placed = []
while len(placed) < 34:
	p = Vector((rng.uniform(-8, 8), rng.uniform(3.2, 8.5), 0))
	if any((p - q).length < 1.05 for q in placed):
		continue
	placed.append(p)
	name = rng.choice(names)
	root, crown, trunk = roots[name]
	holder = bpy.data.objects.new(f'grove {len(placed)}', None)
	grove.objects.link(holder)
	holder.location = p
	holder.rotation_euler.z = rng.uniform(0, math.tau)
	holder.scale = (rng.uniform(0.85, 1.2),) * 3
	for part in (crown, trunk):
		copy = part.copy()
		grove.objects.link(copy)
		copy.parent = holder
		if part is crown:
			copy.data = part.data.copy()
			copy.data.materials.clear()
			copy.data.materials.append(tinted('grove green', greens[rng.randrange(len(greens))] * rng.uniform(0.9, 1.1), 0.9))

bpy.ops.wm.save_as_mainfile(filepath=str(kit.ROOT / 'art/blender/trees/zenscape-spruce-family.blend'))
if '--no-render' in ARGS:
	raise SystemExit

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
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
scene.view_settings.view_transform = 'Standard'
cam_data = bpy.data.cameras.new('Cam')
cam = bpy.data.objects.new('Cam', cam_data)
stage.objects.link(cam)
scene.camera = cam
out = Path('/tmp/zs-tree-previews/spruce-family')
out.mkdir(parents=True, exist_ok=True)
views = {
	'lineup': ((0.3, -9.5, 1.9), (0.3, 0, 1.45), 40),
	'grove': ((0, -14, 9), (0, 4.5, 0.8), 40),
	'grove-low': ((1.5, -3.5, 1.1), (0, 6, 1.6), 28),
}
for view, (loc, target, lens) in views.items():
	grove.hide_render = view == 'lineup'
	cam.location = loc
	cam_data.lens = lens
	cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
	scene.render.filepath = str(out / f'{view}.png')
	bpy.ops.render.render(write_still=True)
print('SPRUCE_RENDERS', out)
