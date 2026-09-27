"""Render the snake probe's dump (tools/probe_snake.gd -- --dump=DIR) in Blender:

  blender -b --python tools/render_snake_probe.py -- --dir=/tmp/zs-snake-previews/frames
      --view=close|far|top [--from=F] [--to=F] [--every=N] [--sheet=COUNT] [--video]
      [--name=NAME] [--scale=1.0]

Builds the ground from the dumped height grid (faceted and painted green), the
pond from the view's own pond triangles, stand-ins for the plants, and the
snake's mesh posed on the CPU the way the game skins it: every vertex belongs
to one bone and moves with that frame's bone pose. Ripple rings fade as the
game's do. Godot's y-up plate metres become Blender's z-up as (x, -z, y).

`close` follows the snake from 2.6 m; `far` sits 43 m off at the game's default
camera angle, with a field of view that gives the same metres per pixel as the
full 1440x900 game frame (the render is a crop of it); `top` looks straight down.
`--sheet=N` renders N evenly spaced frames to /tmp/zs-snake-previews/<name>.png;
`--video` renders every `--every`th frame to <name>.mp4 at 30 fps.
"""
import bpy, json, math, shutil, subprocess, sys
from pathlib import Path
import numpy as np
from mathutils import Vector

ARGV = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ARGS = dict(a.lstrip('-').split('=', 1) if '=' in a else (a.lstrip('-'), '1') for a in ARGV)
DIR = Path(ARGS.get('dir', '/tmp/zs-snake-previews/frames'))
OUT = Path(ARGS.get('out', '/tmp/zs-snake-previews'))
VIEW = ARGS.get('view', 'close')
NAME = ARGS.get('name', VIEW)
EVERY = int(ARGS.get('every', 1))
SCALE = float(ARGS.get('scale', 1.0))


def srgb(hex_value):
	c = [int(hex_value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


def b(x, y, z):
	return (x, -z, y)


frames = [json.loads(line) for line in open(DIR / 'frames.jsonl')]
mesh_data = json.load(open(DIR / 'mesh.json'))
world = json.load(open(DIR / 'scene.json'))
FIRST = int(ARGS.get('from', 0))
LAST = min(int(ARGS.get('to', len(frames) - 1)), len(frames) - 1)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = int(640 * SCALE), int(360 * SCALE)
scene.render.fps = 30
scene.view_settings.view_transform = 'Standard'
try:
	scene.eevee.taa_render_samples = 12
except AttributeError:
	pass
sky = bpy.data.worlds.new('Sky')
sky.use_nodes = True
sky.node_tree.nodes['Background'].inputs['Color'].default_value = (*srgb('8e9aa6'), 1)
sky.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.85
scene.world = sky
sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
sun.data.energy, sun.data.color, sun.data.angle = 3.2, srgb('fff1dc'), math.radians(3)
sun.rotation_euler = (math.radians(48), 0, math.radians(-150))
scene.collection.objects.link(sun)


def material(name, color=None, roughness=0.7, vertex=True, alpha=1.0):
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	nodes = mat.node_tree.nodes
	bsdf = nodes['Principled BSDF']
	bsdf.inputs['Roughness'].default_value = roughness
	if vertex:
		vc = nodes.new('ShaderNodeVertexColor')
		vc.layer_name = 'Col'
		mat.node_tree.links.new(vc.outputs['Color'], bsdf.inputs['Base Color'])
	elif color:
		bsdf.inputs['Base Color'].default_value = (*color, 1)
	if alpha < 1.0:
		bsdf.inputs['Alpha'].default_value = alpha
		mat.surface_render_method = 'BLENDED'
	return mat


def triangles(name, verts, colors, mat):
	me = bpy.data.meshes.new(name)
	n = len(verts) // 3
	me.from_pydata(verts, [], [(3 * i, 3 * i + 1, 3 * i + 2) for i in range(n)])
	attr = me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
	flat = []
	for c in colors:
		flat += [c[0], c[1], c[2], 1.0]
	attr.data.foreach_set('color', flat)
	me.materials.append(mat)
	obj = bpy.data.objects.new(name, me)
	scene.collection.objects.link(obj)
	return obj


def hash01(*values):
	h = 0x9E3779B9
	for v in values:
		h = ((h ^ (int(v) & 0xFFFFFFFF)) * 0x85EBCA6B) & 0xFFFFFFFF
		h ^= h >> 13
	return h / 4294967296.0


# The ground: exact heights every 10 cm, painted in 0.45 m blocks like the
# game's faceted ground.
ox, oz = world['origin']
step, nx, nz = world['step'], world['nx'], world['nz']
H = np.array(world['heights']).reshape(nz, nx)
greens = [srgb(h) for h in ('4f8246', '5a8c4c', '47783f', '628f52', '53854a', '4a7d43')]
verts, colors = [], []
for iz in range(nz - 1):
	for ix in range(nx - 1):
		x0, z0 = ox + ix * step, oz + iz * step
		p00 = b(x0, H[iz, ix], z0)
		p10 = b(x0 + step, H[iz, ix + 1], z0)
		p01 = b(x0, H[iz + 1, ix], z0 + step)
		p11 = b(x0 + step, H[iz + 1, ix + 1], z0 + step)
		bx, bz = math.floor(x0 / 0.45), math.floor(z0 / 0.45)
		upper = ((x0 / 0.45) % 1.0) > ((z0 / 0.45) % 1.0)
		c = greens[int(hash01(bx, bz, upper) * len(greens))]
		verts += [p00, p10, p11, p00, p11, p01]
		colors += [c] * 6
ground = triangles('Ground', verts, colors, material('Ground', roughness=0.9))

# The pond, from the view's own triangles.
w = world['water']
if w:
	wv = [b(w[i], w[i + 1] + 0.002, w[i + 2]) for i in range(0, len(w), 3)]
	triangles('Pond', wv, [srgb('2f6f73')] * len(wv), material('Water', roughness=0.08, alpha=0.72))

# Plants: simple stand-ins in the right places.
bark = material('Bark', srgb('5b4636'), vertex=False)
leaf = material('Leaf', srgb('3f6b35'), vertex=False, roughness=0.8)
shrub = material('Shrub', srgb('4d7a3c'), vertex=False, roughness=0.8)
for kind, x, y, z, size in world['plants']:
	if kind in ('tree', 'broadleaf', 'layered_tree', 'redwood'):
		tall = 2.6 * size if kind == 'broadleaf' else 3.4 * size
		bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.1 * size, depth=tall * 0.6, location=b(x, y + tall * 0.3, z))
		bpy.context.object.data.materials.append(bark)
		bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.9 * size if kind == 'broadleaf' else 0.7 * size, location=b(x, y + tall * 0.75, z))
		bpy.context.object.data.materials.append(leaf)
		if kind != 'broadleaf':
			bpy.context.object.scale = (0.8, 0.8, 1.6)
	elif kind in ('shrub', 'fern', 'reeds', 'bank_grass', 'grass_tuft'):
		bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.32 * size, location=b(x, y + 0.18 * size, z))
		bpy.context.object.scale = (1.0, 1.0, 0.7)
		bpy.context.object.data.materials.append(shrub)
for obj in bpy.context.scene.objects:
	if obj.type == 'MESH' and obj.name not in ('Ground', 'Pond'):
		for poly in obj.data.polygons:
			poly.use_smooth = False

# The snake, posed per frame from its bones.
V = np.array(mesh_data['vertices'], dtype=np.float64).reshape(-1, 3)
C = np.array(mesh_data['colors'], dtype=np.float64).reshape(-1, 3)
B = np.array(mesh_data['bones'], dtype=np.int64)
snake = triangles('Snake', [tuple(v) for v in V], [tuple(c) for c in C], material('Snake', roughness=0.55))
snake_mesh = snake.data


def pose(frame):
	bones = np.array(frame['bones'], dtype=np.float64).reshape(-1, 12)
	X, Y, Z, O = bones[:, 0:3], bones[:, 3:6], bones[:, 6:9], bones[:, 9:12]
	W = O[B] + X[B] * V[:, 0:1] + Y[B] * V[:, 1:2] + Z[B] * V[:, 2:3]
	return np.stack([W[:, 0], -W[:, 2], W[:, 1]], axis=1)


# Ripple rings: a pool of annuli whose alpha comes from the object colour.
ring_mat = bpy.data.materials.new('Ring')
ring_mat.use_nodes = True
nt = ring_mat.node_tree
for node in list(nt.nodes):
	if node.type != 'OUTPUT_MATERIAL':
		nt.nodes.remove(node)
info = nt.nodes.new('ShaderNodeObjectInfo')
emit = nt.nodes.new('ShaderNodeEmission')
emit.inputs['Color'].default_value = (0.9, 0.95, 1.0, 1)
emit.inputs['Strength'].default_value = 1.2
clear = nt.nodes.new('ShaderNodeBsdfTransparent')
mix = nt.nodes.new('ShaderNodeMixShader')
nt.links.new(info.outputs['Alpha'], mix.inputs['Fac'])
nt.links.new(clear.outputs[0], mix.inputs[1])
nt.links.new(emit.outputs[0], mix.inputs[2])
nt.links.new(mix.outputs[0], nt.nodes['Material Output'].inputs['Surface'])
ring_mat.surface_render_method = 'BLENDED'
rings = []
for i in range(14):
	bpy.ops.mesh.primitive_circle_add(vertices=40, radius=1.0, fill_type='NOTHING')
	obj = bpy.context.object
	obj.name = f'Ring{i}'
	mod = obj.modifiers.new('Width', 'SOLIDIFY')
	obj.data.materials.append(ring_mat)
	# A flat annulus: extrude the circle inward.
	me = obj.data
	import bmesh
	bm = bmesh.new()
	bm.from_mesh(me)
	edges = list(bm.edges)
	ret = bmesh.ops.extrude_edge_only(bm, edges=edges)
	for v in [e for e in ret['geom'] if isinstance(e, bmesh.types.BMVert)]:
		v.co *= 0.94
	bm.to_mesh(me)
	bm.free()
	obj.modifiers.remove(mod)
	obj.hide_render = True
	rings.append(obj)


def show_rings(frame):
	for obj in rings:
		obj.hide_render = True
	for i, (x, y, z, age, size) in enumerate(frame['rings'][:len(rings)]):
		u = min(max(age / (1.3 + size * 0.9), 0.0), 1.0)
		if u >= 1.0:
			continue
		radius = (0.08 + math.sqrt(u) * 0.95) * size
		obj = rings[i]
		obj.hide_render = False
		obj.location = b(x, y + 0.004, z)
		obj.scale = (radius, radius, 1)
		obj.color = (1, 1, 1, (1 - u) * (1 - u) * 0.75)


# Camera: follows a smoothed centre of the body.
centers = []
for frame in frames:
	bones = np.array(frame['bones']).reshape(-1, 12)
	# `--target=head` frames the head and neck instead of the whole body.
	o = bones[-2, 9:12] if ARGS.get('target') == 'head' else bones[:-2, 9:12].mean(axis=0)
	centers.append(np.array(b(*o)))
keep = float(ARGS.get('smooth', 0.96))
smooth = [centers[0]]
for c in centers[1:]:
	smooth.append(smooth[-1] * keep + c * (1 - keep))
back = [smooth[-1]]
for c in reversed(smooth[:-1]):
	back.append(back[-1] * keep + c * (1 - keep))
smooth = list(reversed(back))
cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
scene.collection.objects.link(cam)
scene.camera = cam
# The game's default camera looks from +x, a little -z, 25 degrees down.
game_dir = Vector(b(36.95, 18.35, -12.12)).normalized()
if 'mirror' in ARGS:  # the same angle from the opposite side
	game_dir = Vector((-game_dir.x, -game_dir.y, game_dir.z))
if VIEW == 'far':
	cam.data.sensor_fit = 'VERTICAL'
	cam.data.angle_y = 2 * math.atan(7.125 / 43.0)
	cam.data.clip_end = 200
elif VIEW == 'top':
	cam.data.type = 'ORTHO'
	cam.data.ortho_scale = float(ARGS.get('ortho', 3.2))
else:
	cam.data.lens = 35
span = np.array(smooth[FIRST:LAST + 1])
still = Vector(tuple(span.mean(axis=0)))


def aim(i):
	target = Vector(tuple(smooth[i]))
	if VIEW == 'far':
		target = still
		cam.location = target + game_dir * 43.0
	elif VIEW == 'top':
		cam.location = target + Vector((0, 0, 20))
	else:
		distance = float(ARGS.get('distance', 2.6))
		azimuth = math.radians(float(ARGS.get('azimuth', -35)))
		elevation = math.radians(float(ARGS.get('elevation', 34)))
		cam.location = target + Vector((math.cos(elevation) * math.cos(azimuth), math.cos(elevation) * math.sin(azimuth), math.sin(elevation))) * distance
		cam.data.clip_start = 0.01
	cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()


def render(indices, folder):
	if folder.exists():
		shutil.rmtree(folder)
	folder.mkdir(parents=True)
	for n, i in enumerate(indices):
		frame = frames[i]
		snake_mesh.vertices.foreach_set('co', pose(frame).ravel())
		snake_mesh.update()
		show_rings(frame)
		aim(i)
		scene.render.filepath = str(folder / f'{n:04d}.png')
		bpy.ops.render.render(write_still=True)


OUT.mkdir(parents=True, exist_ok=True)
if 'video' in ARGS:
	folder = OUT / f'{NAME}-video'
	render(range(FIRST, LAST + 1, EVERY), folder)
	video = OUT / f'{NAME}.mp4'
	subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-framerate', '30', '-i', str(folder / '%04d.png'),
		'-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', str(video)], check=True)
	print('SNAKE_REVIEW', video, 'frames', FIRST, LAST, 'every', EVERY)
else:
	count = int(ARGS.get('sheet', 8))
	indices = [round(FIRST + k * (LAST - FIRST) / max(count - 1, 1)) for k in range(count)]
	folder = OUT / f'{NAME}-stills'
	render(indices, folder)
	cols = min(count, int(ARGS.get('cols', 4)))
	rows = math.ceil(count / cols)
	sheet = OUT / f'{NAME}.png'
	subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(folder / '%04d.png'),
		'-vf', f'tile={cols}x{rows}', '-frames:v', '1', str(sheet)], check=True)
	print('SNAKE_REVIEW', sheet, 'frames', indices, [frames[i]['phase'] for i in indices])
