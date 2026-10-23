"""Spruce family, bough sprays: the six variants of spruce.py rebuilt bough by bough.

Each crown tier is a whorl of drooping boughs. A bough is one thin tented sheet, a
tapering spray whose edges are a sawtooth needle fringe in real geometry (no alpha),
so the silhouette breaks into many needle tips. A second, shorter whorl fills the tier
up toward its apex, and a dark core cone inside each tier closes the view through, so
the gaps between boughs read dark and their tips light. Same node names, sizes and
overall silhouettes as spruce.py, so the glb drops in (hero_trees.gd `--spruce=sprays`).

Canopy colour is greyscale light and shade, per vertex (dark at the trunk, light at the
tips): the game tints conifers per instance.

Run: python3 tools/blender.py run tools/blender_trees/spruce_sprays.py [-- --no-render]
"""
import sys, math, zlib, random
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy, bmesh
from mathutils import Vector
import kit
from kit import rng, srgb, ARGS

WIND = Vector((1, 0, 0))
Z = Vector((0, 0, 1))

# Same table as spruce.py: height, bole, tiers, spread, taper, boughs, droop.
VARIANTS = {
	'mature': dict(H=2.8, b=0.45, T=6, spread=0.62, taper=0.78, n=8, droop=0.35),
	'young': dict(H=1.7, b=0.12, T=4, spread=0.6, taper=0.7, n=7, droop=0.25),
	'windswept': dict(H=2.6, b=0.5, T=6, spread=0.6, taper=0.78, n=8, droop=0.3, lean=0.3),
	'dead-top': dict(H=3.0, b=0.55, T=5, spread=0.6, taper=0.7, n=8, droop=0.35, live=0.7),
	'sparse': dict(H=2.9, b=0.8, T=5, spread=0.62, taper=0.75, n=7, droop=0.45, gaps=2),
	'spire': dict(H=3.3, b=0.35, T=8, spread=0.46, taper=0.82, n=8, droop=0.3),
}

# Knobs (all model units; the game scales the family about 3-4.5x).
# Per level of detail: whorls per tier as (reach of r, boughs per n), the spacing of
# the needle teeth along a bough, the fewest teeth a bough has, and the bough width.
# "near" is the close tree; "far" stands in past the game's detail distance
# (land_trees.gd), the same tree with fewer, coarser boughs.
LODS = {
	'near': dict(whorls=((1.08, 1.6), (0.8, 1.3), (0.5, 1.0), (0.28, 0.7)), tooth=0.07, kmin=3, wide=0.36),
	'far': dict(whorls=((1.08, 1.0), (0.64, 0.75)), tooth=0.2, kmin=2, wide=0.46),
	# The distance crowns (land_trees.gd): the same tiers, each one skirt from the
	# tier's top on the trunk down to `skirt` drooping bough tips, notched in and up
	# between them, so a tree reads as the near crown's mass with its jagged tiers
	# (thin tents read see-through and dark at range). "mid" per variant, 200 to
	# 400 m; "low" the mid and far rings past 400 m. (bough_low's tents are kept for
	# a LOD with 'tent'.)
	'mid': dict(skirt=6),
	'low': dict(skirt=4),
}
LOW_LIFT = 1.0     # the distance crowns' bake over the near crown's (the shader eases the bake at range)
LOD = LODS['near']
BARE = 0.3         # the inner part of a bough (hidden under the boughs above) has no teeth
NOTCH = 0.4        # the notches between teeth, of the half width
ARCH = 1.25        # how far a bough's edges hang below its spine, of the half width
CORE = 0.45        # the dark core cone's radius, of the tier's reach
V_CORE = 0.42      # bake: the core's value
V_ROOT, V_TIP = 0.55, 1.02    # bake: a bough's value at the trunk and at its tips
# Bough space for the game's texture (hero_trees.gd --spruce-texture): per vertex
# UV = (along the bough 0..1, the bough's own hash 0..1) and UV2 = (across: 0 on
# the spine, +-NOTCH at a notch, +-1 at a tooth's tip; the bough's length).
# Written as Godot reads them (glTF flips v), so Godot's UV.y is the hash, UV2.y the length.
FACETS = False     # the "b" crown: each sheet cell and tooth split into small jittered facets
FACET_JIT = 0.35   # the facets' jitter, of the local half width (sheets) and tooth size
jit = random.Random(7)


def axis_at(z, P):
	"""Trunk centreline; the windswept tree bends downwind with height."""
	lean = P.get('lean', 0.0) * (max(z, 0.0) / P['H']) ** 1.6
	return Vector((0.03 * math.sin(z * 2.1), 0.03 * math.cos(z * 1.7), 0)) + WIND * lean + Vector((0, 0, z))


def width_at(t):
	# Narrow at the trunk, widest a little inside the middle, a point at the tip.
	a, b = 0.55, 0.9
	peak = (a / (a + b)) ** a * (b / (a + b)) ** b
	return (t ** a) * ((1 - t) ** b) / peak


class Crown:
	"""A bmesh plus a value per vertex for the bake."""
	def __init__(self):
		self.bm = bmesh.new()
		self.value = {}
		self.uv = {}

	def vert(self, co, v, uv=(0.0, 0.0, 0.0, 0.0)):
		vert = self.bm.verts.new(co)
		self.value[vert] = v
		self.uv[vert] = uv
		return vert

	def face(self, *verts):
		try:
			return self.bm.faces.new(verts)
		except ValueError:
			return None

	def sheet(self, *verts):
		"""A bough face, turned to face up (the sheets are drawn from both sides)."""
		f = self.face(*verts)
		if f is not None:
			f.normal_update()
			if f.normal.z < 0:
				f.normal_flip()


def bough(c, root, d, L, droop, rise, bright, K=None):
	"""One spray from root along horizontal direction d, length L.
	Tented sheet: spine on top, edges hang; sawtooth teeth point out and forward."""
	side = Vector((-d.y, d.x, 0)).normalized()
	hb = jit.random()  # the bough's own hash (its own rng, so the tree's shape keeps its seed)
	K = K or max(LOD['kmin'], min(10, round((1 - BARE) * L / LOD['tooth'])))
	W = LOD['wide'] * L * rng.uniform(0.85, 1.15)
	roll = rng.uniform(-0.25, 0.25)  # one edge hangs lower than the other

	def spine(t):
		return root + d * (L * t) + Z * (L * (rise * t - (rise + droop) * t * t))

	def edge(t, s, out):
		w = W * width_at(t) * out
		hang = ARCH * w * (1 + s * roll) + 0.08 * L * t * out
		# Edges sweep back a little toward the trunk so the spray reads as a frond.
		return spine(t) + side * (s * w) - Z * hang - d * (0.15 * w)

	def val(t, extra=0.0):
		return (V_ROOT + (V_TIP - V_ROOT) * t ** 0.85) * bright + extra

	ts = [0.0] + [BARE + (1 - BARE) * k / K for k in range(K + 1)]
	spine_v = [c.vert(spine(t), val(t, 0.03), (t, hb, 0.0, L)) for t in ts]
	last = len(ts) - 1

	def facet_mid(p, q, tq, sq, w):
		"""A vertex between p and q pushed off the sheet a little (the "b" facets)."""
		co = (p.co + q.co) * 0.5 + Z * (jit.uniform(-1, 1) * FACET_JIT * w) + d * (jit.uniform(-0.5, 0.5) * FACET_JIT * w)
		return c.vert(co, (c.value[p] + c.value[q]) * 0.5, (tq, hb, sq, L))

	for s in (1, -1):
		notches = [spine_v[0]] + [c.vert(edge(t, s, NOTCH), val(t, -0.08), (t, hb, s * NOTCH, L)) for t in ts[1:-1]] + [spine_v[-1]]
		mids = None
		if FACETS:
			# A row between spine and notches, each pushed up or down: four facets a cell.
			mids = [None] + [facet_mid(spine_v[k], notches[k], ts[k], s * NOTCH * 0.5, W * width_at(ts[k]) * NOTCH) for k in range(1, last)] + [None]
		for k in range(last):
			a, b, e0, e1 = spine_v[k], spine_v[k + 1], notches[k], notches[k + 1]
			if k == 0:
				if mids: c.sheet(a, mids[1], e1); c.sheet(a, b, mids[1])
				else: c.sheet(a, b, e1)
			elif k == last - 1:
				if mids: c.sheet(a, b, mids[k]); c.sheet(mids[k], b, e0)
				else: c.sheet(a, b, e0)
			else:
				if mids:
					c.sheet(a, b, mids[k + 1], mids[k])
					c.sheet(mids[k], mids[k + 1], e1, e0)
				else:
					c.sheet(a, b, e1, e0)
		# Teeth: one per segment past the bare part, notch to notch, tip out and forward.
		for k in range(1, last):
			t = min(ts[k] + 0.8 * (ts[k + 1] - ts[k]), 0.97)
			tip = c.vert(edge(t, s, 1.0) + d * (0.5 * (1 - BARE) * L / K), val(t, 0.12), (t, hb, float(s), L))
			if FACETS:
				# The tooth in three facets round a jittered centre.
				n0, n1 = notches[k], notches[k + 1]
				size = (tip.co - (n0.co + n1.co) * 0.5).length
				co = (n0.co + n1.co + tip.co) / 3 + Z * (jit.uniform(-1, 1) * FACET_JIT * 0.5 * size)
				mid = c.vert(co, (c.value[n0] + c.value[n1] + c.value[tip]) / 3, ((ts[k] + ts[k + 1] + t) / 3, hb, s * (2 * NOTCH + 1) / 3, L))
				c.sheet(n0, tip, mid); c.sheet(tip, n1, mid); c.sheet(n1, n0, mid)
			else:
				c.sheet(notches[k], tip, notches[k + 1])
	return K


def bough_low(c, root, d, L, droop, rise, bright):
	"""A distance crown's bough (LOD 'tent' 1 or 2): the spray's spine and hanging
	edges with no teeth, its tip drooped as the near bough's."""
	side = Vector((-d.y, d.x, 0)).normalized()
	hb = jit.random()
	W = LOD['wide'] * L * rng.uniform(0.85, 1.15)

	def spine(t):
		return root + d * (L * t) + Z * (L * (rise * t - (rise + droop) * t * t))

	def val(t, extra=0.0):
		return ((V_ROOT + (V_TIP - V_ROOT) * t ** 0.85) * bright + extra) * LOW_LIFT

	tm = 0.5
	w = W * width_at(tm)
	R = c.vert(spine(0.0), val(0.0, 0.03), (0.0, hb, 0.0, L))
	T = c.vert(spine(1.0), val(1.0, 0.12), (1.0, hb, 0.0, L))
	E = [c.vert(spine(tm) + side * (s * w) - Z * (ARCH * w) - d * (0.15 * w), val(tm, -0.08), (tm, hb, float(s), L)) for s in (1, -1)]
	if LOD['tent'] == 1:
		for e in E:
			c.sheet(R, T, e)
	else:
		M = c.vert(spine(tm), val(tm, 0.03), (tm, hb, 0.0, L))
		for e in E:
			c.sheet(R, M, e)
			c.sheet(M, T, e)


def skirt(c, P, z0, z_top, r, droop, bright, twist):
	"""A distance crown's tier (LOD 'skirt'): from the tier's top on the trunk down
	to K drooping bough tips at the rim, the rim notched in and up between them."""
	K = LOD['skirt']
	apex = c.vert(axis_at(z_top, P), (V_ROOT + 0.05) * bright * LOW_LIFT, (0.0, jit.random(), 0.0, 0.0))
	rim = []
	for j in range(2 * K):
		a = twist + j * math.pi / K + rng.uniform(-0.12, 0.12)
		d = Vector((math.cos(a), math.sin(a), 0))
		reach = r * 1.05 * rng.uniform(0.9, 1.1)
		if P.get('lean'):
			reach *= 1.0 - 0.3 * d.dot(-WIND) if d.dot(-WIND) > 0 else 1.0 + 0.25 * d.dot(WIND)
		if j % 2 == 0:   # a bough's tip, drooped
			co = axis_at(z0, P) + d * reach - Z * (droop * reach)
			v = V_TIP * bright
		else:            # the notch between two tips
			co = axis_at(z0 + 0.3 * (z_top - z0), P) + d * (reach * 0.55)
			v = (V_ROOT + 0.6 * (V_TIP - V_ROOT)) * bright
		rim.append(c.vert(co, v * LOW_LIFT, (1.0 if j % 2 == 0 else 0.5, jit.random(), 0.0, reach)))
	for j in range(2 * K):
		c.sheet(apex, rim[j], rim[(j + 1) % (2 * K)])


def core(c, P, z0, z_top, r, droop, bright):
	"""The dark bicone inside the tier that stops the eye between boughs."""
	apex = axis_at(z0 + 0.9 * (z_top - z0), P)
	centre = axis_at(z0, P)
	under = axis_at(z0 - 0.05, P)
	sides = LOD.get('core', 6)
	if sides == 0:
		return
	twist = rng.uniform(0, math.tau)
	rr = CORE * r
	hc = (0.0, jit.random(), 0.0, 0.0)
	rim = []
	for j in range(sides):
		a = twist + j * math.tau / sides
		d = Vector((math.cos(a), math.sin(a), 0))
		rim.append(c.vert(centre + d * rr - Z * (droop * rr * 0.9), V_CORE * bright, hc))
	top, bottom = c.vert(apex, V_CORE * bright * 1.15, hc), c.vert(under, V_CORE * bright * 0.9, hc)
	for j in range(sides):
		a, b = rim[j], rim[(j + 1) % sides]
		c.face(a, b, top)
		if 'core' not in LOD:
			c.face(b, a, bottom)


def whorl(c, P, z, r, count, droop, rise, gaps, bright, twist, spread_k=1.0):
	centre = axis_at(z, P)
	for j in range(count):
		a = twist + j * math.tau / count + rng.uniform(-0.16, 0.16)
		d = Vector((math.cos(a), math.sin(a), 0))
		reach = r * rng.uniform(0.9, 1.1) * spread_k
		if P.get('lean'):
			# Boughs on the windward side are short and the lee side streams out.
			reach *= 1.0 - 0.3 * d.dot(-WIND) if d.dot(-WIND) > 0 else 1.0 + 0.25 * d.dot(WIND)
		if j in gaps:
			reach *= 0.4
		start = 0.05 * r
		root = centre + d * start + Z * rng.uniform(-0.02, 0.02)
		(bough_low if 'tent' in LOD else bough)(c, root, d, max(reach - start, 0.05), droop * rng.uniform(0.8, 1.2), rise,
			bright * rng.uniform(0.93, 1.06))


def build(name, P):
	c, wood = Crown(), bmesh.new()
	H, b, T = P['H'], P['b'], P['T']
	live_top = H * P.get('live', 1.0)
	span = live_top - b
	step = span / (T - 0.35)
	for i in range(T):
		t = i / (T - 1)
		z0 = b + i * step
		r = P['spread'] * (1 - P['taper'] * t)
		h = step * (1.45 - 0.35 * t)
		z_top = min(z0 + h, live_top + 0.2 if 'live' in P else H)
		droop = P['droop'] * (1 - 0.4 * t)
		bright = 0.92 + 0.12 * t  # the crown is lighter toward the top
		size_k = 0.55 + 0.45 * r / P['spread']
		gaps = P.get('gaps', 0) if i < T - 1 else 0
		twist = rng.uniform(0, math.tau)
		if 'skirt' in LOD:
			skirt(c, P, z0, z_top, r, droop, bright, twist)
			continue
		core(c, P, z0, z_top, r, droop, bright)
		for w, (k, per) in enumerate(LOD['whorls']):
			count = LOD['count'] if 'count' in LOD else max(3 if 'tent' in LOD else 4, round(P['n'] * per * size_k))
			# Each whorl's tips land on the tier's cone, from its rim up to its apex.
			tip_z = z0 - droop * r + (1 - k) * (z_top - z0 + droop * r)
			wdroop = droop * (1 + 0.3 * w)
			whorl(c, P, tip_z + wdroop * k * r, k * r, count, wdroop, 0.12,
				set(rng.sample(range(count), gaps)) if w == 0 else set(), bright * (1 + 0.03 * w),
				twist + w * math.pi / count)
		if i == T - 1:
			# The top: a small whorl near the apex, boughs angled up round the leader.
			whorl(c, P, z0 + 0.8 * (z_top - z0), r * 0.22, LOD.get('count', 5), -0.3, 0.3, set(), bright * 1.06,
				rng.uniform(0, math.tau))
	# Trunk runs up into the crown; the leader is a thin crooked spike above it.
	zs = [-0.05, b * 0.5, b + step, H * 0.75, H + 0.12]
	kit.tube(wood, [axis_at(z, P) for z in zs], [0.13, 0.11, 0.08, 0.045, 0.012], 5, gnarl=0.06)
	if 'live' in P:
		for z in (live_top + 0.15, live_top + 0.4, live_top + 0.62):
			a = rng.uniform(0, math.tau)
			d = Vector((math.cos(a), math.sin(a), -0.25)).normalized()
			start = axis_at(z, P)
			kit.tube(wood, [start, start + d * rng.uniform(0.18, 0.3)], [0.025, 0.008], 4, gnarl=0.05)
	bmesh.ops.triangulate(c.bm, faces=c.bm.faces)
	return c, wood


def paint_uvs(obj, uv_of_vert):
	"""Bough space (see FACETS's note) per corner from the per-vertex values."""
	mesh = obj.data
	a, b = mesh.uv_layers.new(name='UVMap'), mesh.uv_layers.new(name='UV2')
	for li, loop in enumerate(mesh.loops):
		t, h, s, L = uv_of_vert[loop.vertex_index]
		a.data[li].uv = (t, 1.0 - h)
		b.data[li].uv = (s, 1.0 - L)


def paint_values(obj, value_of_vert):
	"""Per-corner greyscale from the per-vertex values, so corners share vertices."""
	mesh = obj.data
	attr = mesh.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
	for poly in mesh.polygons:
		for li in poly.loop_indices:
			v = value_of_vert[mesh.loops[li].vertex_index]
			v = max(0.22, min(1.1, v))
			attr.data[li].color = (v, v, v, 1.0)
		# Shared vertices (a third of the flat export's): the game's canopy shader
		# shades each face flat from its own derivatives (reference_surface flat_faces).
		poly.use_smooth = True
	mesh.color_attributes.active_color = attr
	mesh.color_attributes.render_color_index = 0


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
	mat.use_backface_culling = False
	return mat


asset = kit.fresh_scene('EXPORT - spruce sprays')
roots = {}
faces = {}
faceted_objs = []
for name, P in VARIANTS.items():
	objs = {}
	for lod in ('near', 'far', 'b', 'mid', 'low'):
		# The same seed for all levels, so the far tree keeps the near one's trunk and lean
		# and the "b" (faceted) crown is the near one with its sheets split.
		kit.seed(zlib.crc32(name.encode()))
		jit.seed(zlib.crc32(name.encode()) + 1)
		LOD = LODS['near' if lod == 'b' else lod]
		FACETS = lod == 'b'
		c, wood_bm = build(name, P)
		# Vertex values survive to_object in creation order.
		order = [c.value[v] for v in c.bm.verts]
		uvs = [c.uv[v] for v in c.bm.verts]
		objs[lod] = kit.to_object(c.bm, f'{name} canopy' + {'near': '', 'far': ' far', 'b': ' b', 'mid': ' mid', 'low': ' low'}[lod], asset)
		paint_values(objs[lod], order)
		paint_uvs(objs[lod], uvs)
		if lod == 'near':
			trunk = kit.to_object(wood_bm, f'{name} trunk', asset)
		else:
			wood_bm.free()
	crown, far, faceted = objs['near'], objs['far'], objs['b']
	extra = [objs['mid'], objs['low']]
	kit.paint(trunk, bark_value(P['H'] * P.get('live', 2.0)))
	root = bpy.data.objects.new(f'Spruce_{name.replace("-", "_")}', None)
	asset.objects.link(root)
	root['height_m'] = round(P['H'] + 0.12, 2)
	root['description'] = 'Bough sprays. Greyscale canopy and bark: multiply by the stand tint. Origin at ground contact. "<variant> canopy far" is the far level of detail.'
	for o in (crown, trunk, far, faceted, *extra):
		o.parent = root
	roots[name] = (root, crown, trunk, far)
	faces[name] = (len(crown.data.polygons), len(far.data.polygons), len(trunk.data.polygons), len(faceted.data.polygons), len(extra[0].data.polygons), len(extra[1].data.polygons))
	faceted_objs.extend([faceted, *extra])
print('SPRUCE_SPRAYS faces (canopy, far canopy, trunk, canopy b, canopy mid, canopy low)', faces)

glb = kit.ROOT / 'assets/models/zenscape-spruce-sprays.glb'
bpy.ops.object.select_all(action='DESELECT')
for o in faceted_objs:
	o.data.materials.append(kit.material('Canopy', 0.9))
	o.select_set(True)
for root, crown, trunk, far in roots.values():
	crown.data.materials.append(kit.material('Canopy', 0.9))
	far.data.materials.append(kit.material('Canopy', 0.9))
	trunk.data.materials.append(kit.material('Bark', 0.95))
	for o in (root, crown, trunk, far):
		o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True,
	export_animations=False, export_cameras=False, export_lights=False, export_extras=True,
	export_yup=True, export_vertex_color='ACTIVE')
print('SPRUCE_SPRAYS_EXPORT', glb)

# ---------------------------------------------------------------- preview stage
scene = bpy.context.scene
stage = bpy.data.collections.new('PREVIEW - stage')
scene.collection.children.link(stage)
kit.ground(stage, 9, srgb('5f8c3c'), srgb('86ad4e'))
greens = [srgb(h) for h in ('35683a', '3f7a3c', '2f5f3a', '46784a', '3a6c40', '2f6a44')]
bark_tint = srgb('635c56')
for o in faceted_objs:
	o.hide_render = True
for i, (name, (root, crown, trunk, far)) in enumerate(roots.items()):
	for o in (crown, trunk, far):
		o.data.materials.clear()
	crown.data.materials.append(tinted(f'{name} green', greens[i], 0.9))
	far.data.materials.append(tinted(f'{name} far green', greens[i], 0.9))
	trunk.data.materials.append(tinted(f'{name} bark', bark_tint, 0.95))
	root.location = (-3.9 + i * 1.55, 0, 0)

# The current family's trees beside them (preview only), the same tints, for the silhouette.
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(kit.ROOT / 'assets/models/zenscape-spruce-family.glb'))
old = [o for o in bpy.data.objects if o not in before]
for o in old:
	for coll in list(o.users_collection):
		coll.objects.unlink(o)
	stage.objects.link(o)
	if o.type == 'MESH':
		o.data.materials.clear()
		mat = tinted('old ' + o.name, bark_tint if 'trunk' in o.name else greens[0], 0.9)
		mat.node_tree.nodes['Color Attribute'].layer_name = o.data.color_attributes[0].name
		o.data.materials.append(mat)
	if o.parent is None:
		o.hide_render = not o.name.startswith('Spruce_mature')
		o.location = (-3.9, 2.2, 0)
for o in old:
	if o.parent is not None and o.parent.hide_render:
		o.hide_render = True

bpy.ops.wm.save_as_mainfile(filepath=str(kit.ROOT / 'art/blender/trees/zenscape-spruce-sprays.blend'))
if '--no-render' in ARGS:
	raise SystemExit

world = bpy.data.worlds.new('Day')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (*srgb('9db8d0'), 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9
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
out = Path(ARGS[ARGS.index('--out') + 1]) if '--out' in ARGS else Path('/tmp/zs-tree-previews/spruce-sprays')
out.mkdir(parents=True, exist_ok=True)
views = {
	'lineup': ((0.0, -9.5, 1.9), (0.0, 0, 1.45), 40),
	'close': ((-3.9 + 0.2, -2.6, 0.55), (-3.9, 0, 1.5), 30),
	'pair': ((-3.9 + 6.5, 1.1, 1.0), (-3.9, 1.1, 1.5), 40),
	'lods': ((0.0, -6.5, 1.6), (0.0, 1.5, 1.45), 32),
	'above': ((-3.9 + 1.5, -3.0, 4.6), (-3.9, 0, 1.3), 35),
}
for view, (loc, target, lens) in views.items():
	# 'lods': the far level of detail alone, beside nothing else.
	for root, crown, trunk, far in roots.values():
		crown.hide_render = view == 'lods'
		far.hide_render = view != 'lods'
	cam.location = loc
	cam_data.lens = lens
	cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
	scene.render.filepath = str(out / f'{view}.png')
	bpy.ops.render.render(write_still=True)
print('SPRUCE_SPRAYS_RENDERS', out)
