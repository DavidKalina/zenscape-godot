"""God Hand: one faceted right hand of light on a finger rig, the creation tools' hand.

Run: blender -b --python tools/blender_hand/god_hand.py -- [--no-render] [--no-anim]

A gentle Master Hand: soft, chubby and slow, never clawed, and made of light, so it never
hides the land or the mark under it. The palm is a metaball family and each finger a
smooth lofted tube; a voxel remesh fuses them into one shell, decimated into large facets
like the heron and the ambient Bigfoot. Weights come from distance to the bone segments,
blended only along a finger's own chain, so a curl bends at the knuckles and never drags
a neighbouring finger along. The wrist fades to nothing: COLOR_0 alpha carries the fade.

Clips come from god_hand_clips.py; god_hand_review.py renders and checks them.
Saves art/blender/hand/zenscape-god-hand.blend and exports assets/models/zenscape-god-hand.glb.
Units: 1.0 = wrist to middle fingertip. Blender Z-up, palm down, fingers along -Y (Godot
+Z after export), thumb on +X; the armature origin is the anchor the clips are placed on.
Non-deforming bones mark where the game attaches things: Orb (the water orb's centre),
Palm (the press), Pinch (where the tips meet), Pollen (where the pinch of salt gathers)
and Handful (pollen held in the palm; its scale is 1 while held, and a drop throws it).
Ball and BallTouch hang off Root, not the hand: where a clip takes the water orb to be and
the point on it the hand touches, Ball's scale how firmly the hand keeps to it
(god_hand_clips.py, the marks).
"""
import bpy, bmesh, math, random, sys
from pathlib import Path
from mathutils import Vector, Quaternion

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'blender_trees'))
sys.path.insert(0, str(HERE.parent / 'blender_bigfoot'))
sys.path.insert(0, str(HERE.parent / 'blender_creatures'))
sys.path.insert(0, str(HERE))
import kit
from kit import srgb
import god_hand_clips as clips

ROOT = kit.ROOT
ARGS = kit.ARGS
rng = random.Random(7)
kit.rng.seed(7)

# ---------------------------------------------------------------- landmarks
SURFACE = 0.575  # surface radius of a lone ball per unit of influence radius
TARGET_FACES = 2400
VOXEL = 0.007

# Per finger: knuckle (MCP), direction, phalanx lengths, surface radius per phalanx and
# the rest curl at each joint in degrees. Chubby and a little short, like a glove.
FINGERS = {
	'Index': ((0.188, -0.455, 0.012), (0.04, -1, 0), (0.205, 0.145, 0.120), (0.062, 0.058, 0.054), (5, 7, 4)),
	'Middle': ((0.063, -0.480, 0.018), (0.0, -1, 0), (0.220, 0.155, 0.125), (0.064, 0.060, 0.056), (5, 7, 4)),
	'Ring': ((-0.063, -0.465, 0.012), (-0.045, -1, 0), (0.210, 0.150, 0.120), (0.061, 0.057, 0.053), (6, 8, 5)),
	'Pinky': ((-0.184, -0.420, -0.004), (-0.10, -1, 0), (0.165, 0.115, 0.100), (0.054, 0.051, 0.048), (7, 9, 5)),
}
THUMB_CMC = Vector((0.130, -0.110, -0.020))
THUMB_DIR = Vector((0.60, -0.78, -0.15))
THUMB_NAIL = Vector((0.6, 0.0, 0.8))  # the thumbnail's outward normal, relaxed
THUMB_LENGTHS = (0.20, 0.16, 0.135)
THUMB_RADII = (0.075, 0.066, 0.060)
THUMB_CURL = (0, 12, 10)

UP = Vector((0, 0, 1))


def chain(start, direction, lengths, curls, up=UP):
	"""Joint positions from the knuckle to the tip, bending toward the palm by the curls."""
	d = Vector(direction).normalized()
	up = (Vector(up) - d * Vector(up).dot(d)).normalized()
	axis = up.cross(d).normalized()
	points = [Vector(start)]
	for length, curl in zip(lengths, curls):
		d = Quaternion(axis, math.radians(curl)) @ d
		points.append(points[-1] + d * length)
	return points


def finger_points(name):
	mcp, direction, lengths, _, curls = FINGERS[name]
	return chain(mcp, direction, lengths, curls)


def thumb_points():
	return chain(THUMB_CMC, THUMB_DIR, THUMB_LENGTHS, THUMB_CURL, THUMB_NAIL)


# ---------------------------------------------------------------- shell

def ellipsoid(mb, co, axes, stiffness=2.0):
	r = max(axes)
	e = mb.elements.new(type='ELLIPSOID')
	e.co, e.radius, e.stiffness = co, r / SURFACE, stiffness
	e.size_x, e.size_y, e.size_z = axes[0] / r, axes[1] / r, axes[2] / r
	return e


def capsule(mb, a, b, r, stiffness=2.0):
	a, b = Vector(a), Vector(b)
	e = mb.elements.new(type='CAPSULE')
	e.co = (a + b) / 2
	e.radius, e.stiffness = r / SURFACE, stiffness
	e.size_x = (b - a).length / 2
	e.rotation = Vector((1, 0, 0)).rotation_difference((b - a).normalized())
	return e


def digit(bm, points, radii, up=UP, sides=16, step=0.012, flat=0.88, root=0.05):
	"""A smooth finger tube from the knuckle to a round tip: oval in section (a little
	flatter than wide), easing between the phalanx radii with a soft bulge at each joint.
	It starts root inside the palm so the remesh fuses it in."""
	lengths = [(b - a).length for a, b in zip(points, points[1:])]
	total = sum(lengths)
	tip_r = radii[-1] * 0.96

	def at(s):
		"""Centre, direction and radius at arc length s (negative runs back into the palm)."""
		if s <= 0:
			d = (points[1] - points[0]).normalized()
			return points[0] + d * s, d, radii[0] * 1.02
		acc = 0.0
		for i, length in enumerate(lengths):
			if s <= acc + length or i == len(lengths) - 1:
				u = min(1.0, (s - acc) / length)
				d = (points[i + 1] - points[i]).normalized()
				nxt = radii[i + 1] if i + 1 < len(radii) else tip_r
				r = radii[i] + (nxt - radii[i]) * u
				knuckle = min(u, 1.0 - u) * length
				r *= 1.0 + 0.045 * math.exp(-(knuckle / 0.03) ** 2) * (i > 0 or u > 0.5)
				return points[i] + d * u * length, d, r
			acc += length

	end = total - tip_r
	samples = [-root + i * step for i in range(int((end + root) / step) + 1)] + [end]
	rings = []
	for s in samples:
		c, d, r = at(s)
		u = (Vector(up) - d * Vector(up).dot(d)).normalized()
		side = d.cross(u)
		rings.append([bm.verts.new(c + (side * math.cos(k * math.tau / sides) + u * math.sin(k * math.tau / sides) * flat) * r)
			for k in range(sides)])
	c, d, r = at(end)
	u = (Vector(up) - d * Vector(up).dot(d)).normalized()
	side = d.cross(u)
	for j in range(1, 5):
		a = j / 5 * math.pi / 2
		rr = r * math.cos(a)
		rings.append([bm.verts.new(c + d * r * math.sin(a) + (side * math.cos(k * math.tau / sides) + u * math.sin(k * math.tau / sides) * flat) * rr)
			for k in range(sides)])
	tip = bm.verts.new(c + d * r)
	for a, b in zip(rings, rings[1:]):
		for k in range(sides):
			bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
	for k in range(sides):
		bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], tip))
	back = bm.verts.new(at(-root)[0])
	for k in range(sides):
		bm.faces.new((rings[0][(k + 1) % sides], rings[0][k], back))


def build_shell(collection):
	families = []

	def family(name):
		mb = bpy.data.metaballs.new(name)
		mb.resolution = mb.render_resolution = 0.01
		mb.threshold = 0.6
		obj = bpy.data.objects.new(name, mb)
		collection.objects.link(obj)
		families.append((obj, mb))
		return mb

	# One family per finger so the fingers never web together; the voxel remesh unions them.
	palm = family('PalmBall')
	ellipsoid(palm, (0.0, -0.34, 0.0), (0.2, 0.15, 0.062))  # the knuckle end, thinning to the fingers
	ellipsoid(palm, (0.0, -0.17, -0.005), (0.175, 0.16, 0.075))  # the heel end
	ellipsoid(palm, (0.10, -0.15, -0.045), (0.10, 0.13, 0.07))  # the thumb's heel
	ellipsoid(palm, (-0.12, -0.20, -0.03), (0.08, 0.16, 0.065))  # the pinky's heel
	ellipsoid(palm, (0.0, 0.0, 0.0), (0.14, 0.12, 0.09))  # wrist
	ellipsoid(palm, (0.0, 0.12, 0.0), (0.11, 0.10, 0.08))  # forearm, hidden by the cuff
	for name, (mcp, *_) in FINGERS.items():
		ellipsoid(palm, (mcp[0], mcp[1] + 0.02, 0.028), (0.045, 0.04, 0.03))  # knuckle bump
	pts = thumb_points()
	capsule(palm, THUMB_CMC.lerp(pts[1], 0.4), pts[1], THUMB_RADII[0])  # the thumb's root, in the heel

	dg = bpy.context.evaluated_depsgraph_get()
	bm = bmesh.new()
	for obj, _ in families:
		mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
		bm.from_mesh(mesh)
		bpy.data.meshes.remove(mesh)
	for name, (_, _, _, radii, _) in FINGERS.items():
		digit(bm, finger_points(name), radii)
	digit(bm, pts[1:], THUMB_RADII[1:], up=THUMB_NAIL, flat=0.9, root=0.06)
	for obj, mb in families:
		bpy.data.objects.remove(obj)
		bpy.data.metaballs.remove(mb)
	shell = kit.to_object(bm, 'Hand', collection)
	bpy.context.view_layer.objects.active = shell
	fuse = shell.modifiers.new('Fuse', 'REMESH')
	fuse.mode, fuse.voxel_size, fuse.adaptivity = 'VOXEL', VOXEL, 0.0
	bpy.ops.object.modifier_apply(modifier=fuse.name)
	dec = shell.modifiers.new('Facets', 'DECIMATE')
	dec.ratio = TARGET_FACES / max(1, 2 * len(shell.data.polygons))
	bpy.ops.object.modifier_apply(modifier=dec.name)
	bm = bmesh.new()
	bm.from_mesh(shell.data)
	bmesh.ops.triangulate(bm, faces=bm.faces)
	for v in bm.verts:
		v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.002
	bm.to_mesh(shell.data)
	bm.free()
	return shell


# ---------------------------------------------------------------- rig

def build_rig(collection):
	data = bpy.data.armatures.new('GodHandRig')
	rig = bpy.data.objects.new('GodHandRig', data)
	collection.objects.link(rig)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.mode_set(mode='EDIT')
	eb = data.edit_bones

	def bone(name, head, tail, parent=None, deform=True, connect=False, roll_up=UP):
		b = eb.new(name)
		b.head, b.tail = Vector(head), Vector(tail)
		if parent:
			b.parent = eb[parent]
			b.use_connect = connect
		b.use_deform = deform
		b.align_roll(Vector(roll_up))
		return b

	bone('Root', (0, 0, 0), (0, 0.15, 0), deform=False)
	bone('Wrist', (0, 0.28, 0), (0, 0.02, 0), 'Root')
	bone('Hand', (0, 0.02, 0), (0, -0.30, 0), 'Wrist', connect=True)
	for name in FINGERS:
		p = finger_points(name)
		bone(f'Meta{name}', (p[0].x * 0.4, -0.06, 0), p[0], 'Hand')
		for i in range(3):
			bone(f'{name}{i + 1}', p[i], p[i + 1], f'Meta{name}' if i == 0 else f'{name}{i}', connect=True)
	p = thumb_points()
	for i in range(3):
		bone(f'Thumb{i + 1}', p[i], p[i + 1], 'Hand' if i == 0 else f'Thumb{i}', connect=i > 0, roll_up=THUMB_NAIL)
	for name, point in (('Orb', clips.ORB_CENTRE), ('Palm', clips.PALM_POINT), ('Pinch', clips.PINCH_POINT),
			('Pollen', clips.BUNCH_POINT), ('Handful', clips.HANDFUL_POINT)):
		bone(name, point, point + Vector((0, -0.08, 0)), 'Hand', deform=False)
	# Marks the clips move on their own, off the hand: the orb as the clip takes it to be.
	for name, point in (('Ball', clips.B0), ('BallTouch', clips.B0 + clips.UNDER)):
		bone(name, point, point + Vector((0, -0.08, 0)), 'Root', deform=False)
	bpy.ops.object.mode_set(mode='POSE')
	for pb in rig.pose.bones:
		pb.rotation_mode = 'QUATERNION'
	bpy.ops.object.mode_set(mode='OBJECT')
	return rig


def seg_distance(p, a, b):
	ab = b - a
	t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
	return (a + ab * t - p).length


METAS = [f'Meta{name}' for name in FINGERS]


def skin(shell, rig):
	"""Each vertex blends its nearest bone with that bone's parent and children (and, in
	the palm, the neighbouring metacarpals), by how much farther they are."""
	bones = {b.name: b for b in rig.data.bones if b.use_deform}
	segments = {n: (b.head_local.copy(), b.tail_local.copy()) for n, b in bones.items()}
	for n in bones:
		shell.vertex_groups.new(name=n)
	for v in shell.data.vertices:
		d = {n: seg_distance(v.co, *s) for n, s in segments.items()}
		near = min(d, key=d.get)
		b = bones[near]
		family = {near} | {c.name for c in b.children if c.name in bones}
		if b.parent and b.parent.name in bones:
			family.add(b.parent.name)
		if near in METAS:
			i = METAS.index(near)
			family |= {METAS[j] for j in (i - 1, i + 1) if 0 <= j < len(METAS)}
		tau = 0.03 if near in METAS or near in ('Hand', 'Wrist', 'Thumb1') else 0.02
		w = sorted(((n, math.exp(-(d[n] - d[near]) / tau)) for n in family), key=lambda kv: -kv[1])[:4]
		w = [(n, x) for n, x in w if x > 0.03]
		total = sum(x for _, x in w)
		for n, x in w:
			shell.vertex_groups[n].add([v.index], x / total, 'REPLACE')


def bind(obj, rig):
	mod = obj.modifiers.new('Rig', 'ARMATURE')
	mod.object = rig
	obj.parent = rig


# ---------------------------------------------------------------- look

LIGHT = srgb('fff1d2')
FADE = (-0.01, 0.2)  # the wrist fades out between these rest y


def paint_light(hand):
	"""One warm colour; alpha is the fade from the fingers (1) to past the wrist (0)."""
	kit.paint(hand, lambda p: LIGHT)
	attr = hand.data.color_attributes['Col']
	for loop in hand.data.loops:
		y = hand.data.vertices[loop.vertex_index].co.y
		c = attr.data[loop.index].color
		attr.data[loop.index].color = (c[0], c[1], c[2], 1.0 - smoothstep(*FADE, y))


def smoothstep(a, b, x):
	t = max(0.0, min(1.0, (x - a) / (b - a)))
	return t * t * (3 - 2 * t)


def light_material():
	"""Blender's stand-in for the game shader: a faint warm core, brighter toward the
	silhouette where the light is seen edge-on, faded out at the wrist."""
	mat = bpy.data.materials.new('HandLight')
	mat.use_nodes = True
	nodes, links = mat.node_tree.nodes, mat.node_tree.links
	bsdf = nodes['Principled BSDF']
	bsdf.inputs['Base Color'].default_value = (*LIGHT, 1)
	bsdf.inputs['Emission Color'].default_value = (*LIGHT, 1)
	bsdf.inputs['Roughness'].default_value = 0.6
	facing = nodes.new('ShaderNodeLayerWeight')
	facing.inputs['Blend'].default_value = 0.45
	rim = nodes.new('ShaderNodeMapRange')
	rim.inputs['To Min'].default_value = 0.22
	rim.inputs['To Max'].default_value = 1.0
	links.new(facing.outputs['Facing'], rim.inputs['Value'])
	fade = nodes.new('ShaderNodeAttribute')
	fade.attribute_name = 'Col'
	alpha = nodes.new('ShaderNodeMath')
	alpha.operation = 'MULTIPLY'
	links.new(rim.outputs['Result'], alpha.inputs[0])
	links.new(fade.outputs['Alpha'], alpha.inputs[1])
	links.new(fade.outputs['Color'], bsdf.inputs['Base Color'])
	links.new(fade.outputs['Color'], bsdf.inputs['Emission Color'])
	links.new(alpha.outputs['Value'], bsdf.inputs['Alpha'])
	glow = nodes.new('ShaderNodeMath')
	glow.operation = 'MULTIPLY_ADD'
	links.new(rim.outputs['Result'], glow.inputs[0])
	glow.inputs[1].default_value = 1.1
	glow.inputs[2].default_value = 0.25
	links.new(glow.outputs['Value'], bsdf.inputs['Emission Strength'])
	mat.surface_render_method = 'BLENDED'
	mat.use_backface_culling = True
	return mat


# ---------------------------------------------------------------- main

def main():
	asset = kit.fresh_scene('EDIT - god hand')
	hand = build_shell(asset)
	rig = build_rig(asset)
	skin(hand, rig)
	paint_light(hand)
	hand.data.materials.append(light_material())
	bind(hand, rig)
	hand.name = hand.data.name = 'GodHand'
	clips.prepare(rig)
	rig['length_m'] = 1.0
	rig['pinch_contact_s'] = clips.PINCH_CONTACT / clips.FPS
	rig['press_contact_s'] = clips.PRESS_CONTACT / clips.FPS
	rig['cup_formed_s'] = clips.CUP_FORMED / clips.FPS
	rig['cup_pop_s'] = clips.CUP_POP / clips.FPS
	rig['sprinkle_release_s'] = clips.THROW_RELEASE / clips.FPS
	rig['idle_variants'] = ','.join(clips.IDLE_VARIANTS)
	if '--no-anim' not in ARGS:
		for name in clips.CLIPS:
			clips.bake_clip(rig, name)
	clips.reset(rig)
	bpy.context.scene.render.fps = clips.FPS
	blend = ROOT / 'art/blender/hand/zenscape-god-hand.blend'
	glb = ROOT / 'assets/models/zenscape-god-hand.glb'
	blend.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=str(blend))
	bpy.ops.object.select_all(action='DESELECT')
	rig.select_set(True)
	hand.select_set(True)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True,
		export_animations='--no-anim' not in ARGS, export_animation_mode='ACTIONS', export_force_sampling=True,
		export_def_bones=False, export_cameras=False, export_lights=False, export_extras=True,
		export_yup=True, export_vertex_color='ACTIVE', export_skins=True)
	print('HAND_EXPORT', glb, 'tris', len(hand.data.polygons), 'bones', len(rig.data.bones),
		'clips', len(clips.CLIPS))


if __name__ == '__main__':
	main()
