"""The leaping fish: a salmonid lofted along its spine, one metre nose to tail.

    python tools/blender.py run art/blender/fish/fish_build.py
    python tools/godot.py --headless --editor --import

Writes assets/models/fish/hero_fish.glb and hero_fish_skin.png. The game bends
and paints it itself (shaders/wake_fish.gdshader): the glb is one mesh, one
surface, nose along +Z, the spine on the z axis, 0.42 m of it before the origin.

The vertex colours say what a vertex is: R a fin, G an eye (its UV then a disc),
B a paired fin's root-to-tip. The body's UV is x along the fish (0 at the nose, 1
at the tail's tip) and y round it (0 the belly's keel, 1 the back), both flanks
on the same paint. A fin's UV is x along its base, y root to tip.

The skin is masks, not colours, so one mesh gives several fish:
R the dark of the back, G the spots, B the lines (the lateral line, the gill
cover, the mouth), A the scales.
"""
import json
import math
import random
import struct
from pathlib import Path

import bpy
import numpy as np

OUT = Path("assets/models/fish/hero_fish.glb")
SKIN = Path("assets/models/fish/hero_fish_skin.png")
SKIN_SIZE = (1024, 256)

## Where the spine's z is 0, from the nose (m), and where the body ends and the
## tail fin takes over.
NOSE = 0.42
BODY = 0.82
## Round the body, and the rings along it (s from the nose, dense at the head
## where the outline turns fast).
SIDES = 12
RINGS = [0.0, 0.012, 0.03, 0.06, 0.1, 0.16, 0.23, 0.31, 0.4, 0.49, 0.58, 0.66, 0.73, 0.78, 0.82]
## The outline, as shares of the body's length: (x, over the spine, under it, half width).
OUTLINE = [
	(0.00, 0.002, 0.002, 0.002),
	(0.015, 0.018, 0.014, 0.014),
	(0.04, 0.034, 0.028, 0.026),
	(0.08, 0.052, 0.046, 0.036),
	(0.14, 0.070, 0.066, 0.046),
	(0.22, 0.086, 0.086, 0.054),
	(0.32, 0.098, 0.100, 0.060),
	(0.44, 0.100, 0.104, 0.060),
	(0.56, 0.090, 0.094, 0.054),
	(0.68, 0.072, 0.074, 0.044),
	(0.80, 0.054, 0.054, 0.031),
	(0.90, 0.040, 0.040, 0.020),
	(1.00, 0.033, 0.033, 0.011),
]


def gd(x, y, z):
	"""Godot's axes to Blender's: the exporter's y-up turns them back."""
	return (x, -z, y)


def outline(s):
	"""(over, under, half width) at s m from the nose."""
	x = min(s / BODY, 1.0)
	for a, b in zip(OUTLINE, OUTLINE[1:]):
		if x <= b[0]:
			k = (x - a[0]) / max(b[0] - a[0], 1e-6)
			k = k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65
			return tuple((a[i] + (b[i] - a[i]) * k) * BODY for i in (1, 2, 3))
	return tuple(OUTLINE[-1][i] * BODY for i in (1, 2, 3))


def round_out(angle):
	"""A section: 0 the belly's keel, PI the back. Flat-sided, as a salmon is."""
	sn = math.sin(angle)
	cs = -math.cos(angle)
	# A superellipse: fuller at the shoulders than an ellipse.
	x = math.copysign(abs(sn) ** 0.82, sn)
	y = math.copysign(abs(cs) ** 0.9, cs)
	return x, y


class Build:
	def __init__(self):
		self.verts = []
		self.uvs = []
		self.cols = []
		self.faces = []
		self.smooth = []

	def vert(self, at, uv, col):
		self.verts.append(gd(*at))
		self.uvs.append(uv)
		self.cols.append(col)
		return len(self.verts) - 1

	def face(self, loop, smooth):
		self.faces.append(tuple(loop))
		self.smooth.append(smooth)


def body(b):
	first = len(b.verts)
	for s in RINGS:
		over, under, wide = outline(s)
		for i in range(SIDES):
			a = math.tau * i / SIDES
			x, y = round_out(a)
			# The head's a touch flatter across the top.
			y = y * (over if y > 0.0 else under)
			b.vert((x * wide, y, NOSE - s), (s, 1.0 - abs((i / SIDES) * 2.0 - 1.0)), (0.0, 0.0, 0.0, 1.0))
	for r in range(len(RINGS) - 1):
		for i in range(SIDES):
			j = (i + 1) % SIDES
			p = first + r * SIDES
			q = p + SIDES
			b.face((p + i, p + j, q + j, q + i), True)
	# The nose's cap and the end at the tail's root.
	n = b.vert((0.0, 0.0, NOSE + 0.002), (0.0, 0.5), (0.0, 0.0, 0.0, 1.0))
	for i in range(SIDES):
		b.face((first + (i + 1) % SIDES, first + i, n), True)
	last = first + (len(RINGS) - 1) * SIDES
	b.face([last + i for i in range(SIDES)], True)


def fin(b, base, tip, weight=0.0):
	"""A fin: the base line and the tip line, sampled alike, its verts by rows
	across so the spine can bend it."""
	rows = len(base)
	mid = [tuple((p[k] + q[k]) * 0.5 for k in range(3)) for p, q in zip(base, tip)]
	first = len(b.verts)
	for line, up in ((base, 0.0), (mid, 0.5), (tip, 1.0)):
		for i, at in enumerate(line):
			b.vert(at, (i / max(rows - 1, 1), up), (1.0, 0.0, weight * up, 1.0))
	for i in range(rows - 1):
		for k in range(2):
			p = first + k * rows + i
			q = p + rows
			b.face((p, q, q + 1, p + 1), False)


def line(a, b, n):
	return [tuple(a[k] + (b[k] - a[k]) * i / (n - 1) for k in range(3)) for i in range(n)]


def on_back(s, under=False, x=0.0, sink=0.006):
	over, down, _ = outline(s)
	return (x, -down + sink if under else over - sink, NOSE - s)


def fins(b):
	# The tail: forked, its two lobes swept, four rows so the last of the spine
	# carries it through a beat.
	rows = [0.80, 0.86, 0.92, 0.975]
	base = []
	tip = []
	for s in rows:
		k = (s - 0.80) / 0.175
		base.append((0.0, 0.016 * (1.0 - k) + 0.05 * k * k, NOSE - s))
		tip.append((0.0, 0.03 + 0.092 * k, NOSE - s - 0.03 * k))
	fin(b, base, tip)
	base = [(p[0], -p[1], p[2]) for p in base]
	tip = [(p[0], -p[1], p[2]) for p in tip]
	# (Mirrored, so wound the other way.)
	fin(b, tip, base)
	# The fork's root between them.
	a = base[0]
	fin(b, [a, (0.0, 0.0, NOSE - 0.84), (0.0, -a[1], a[2])], [(0.0, -0.05, NOSE - 0.905), (0.0, 0.0, NOSE - 0.875), (0.0, 0.05, NOSE - 0.905)])
	# The dorsal, high at the front and raked back.
	stations = [0.36, 0.42, 0.48, 0.53]
	base = [on_back(s) for s in stations]
	tip = [(0.0, on_back(s)[1] + h, NOSE - s - r) for s, h, r in zip(stations, [0.085, 0.078, 0.052, 0.022], [0.05, 0.05, 0.04, 0.02])]
	fin(b, base, tip)
	# The adipose: the small fleshy tab behind it.
	stations = [0.665, 0.695]
	base = [on_back(s) for s in stations]
	tip = [(0.0, on_back(0.665)[1] + 0.024, NOSE - 0.685), (0.0, on_back(0.695)[1] + 0.02, NOSE - 0.715)]
	fin(b, base, tip)
	# The anal fin.
	stations = [0.57, 0.62, 0.67]
	base = [on_back(s, True) for s in stations]
	tip = [(0.0, on_back(s, True)[1] - h, NOSE - s - 0.035) for s, h in zip(stations, [0.062, 0.05, 0.025])]
	fin(b, tip, base)
	# The pectorals and pelvics, a pair of each, splayed off the low flank.
	for side in (-1.0, 1.0):
		for s0, s1, reach, low, drop in ((0.185, 0.225, 0.105, 0.045, 0.028), (0.47, 0.505, 0.072, 0.075, 0.02)):
			over, under, wide = outline(s0)
			a = (side * wide * 0.72, -low, NOSE - s0)
			c = (side * wide * 0.72, -low, NOSE - s1)
			tip_a = (side * (wide * 0.72 + reach * 0.7), -low - drop, NOSE - s0 - reach * 0.75)
			tip_c = (side * (wide * 0.72 + reach * 0.55), -low - drop * 1.4, NOSE - s1 - reach * 0.55)
			base = line(a, c, 2)
			tip = line(tip_a, tip_c, 2)
			if side > 0.0:
				fin(b, base, tip, 1.0)
			else:
				fin(b, tip, base, 1.0)
				# (Flipped: the weight stays with the far row.)
				n = len(b.verts)
				for i in range(n - 6, n):
					k = (i - (n - 6)) // 2
					b.cols[i] = (1.0, 0.0, 1.0 - k * 0.5, 1.0)
	# The eyes: a low disc proud of the head.
	s = 0.062
	over, under, wide = outline(s)
	for side in (-1.0, 1.0):
		c = (side * (wide * 0.94 + 0.002), over * 0.28, NOSE - s)
		r = 0.0125
		mid = b.vert(c, (0.5, 0.5), (0.0, 1.0, 0.0, 1.0))
		ring = []
		for i in range(7):
			a = math.tau * i / 7.0
			ring.append(b.vert((c[0] - side * 0.002, c[1] + math.sin(a) * r, c[2] + math.cos(a) * r), (0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a)), (0.0, 1.0, 0.0, 1.0)))
		for i in range(7):
			j = (i + 1) % 7
			b.face((mid, ring[i], ring[j]) if side > 0.0 else (mid, ring[j], ring[i]), True)


def skin():
	"""The masks (the module's header), painted over (u along the fish, v round it)."""
	w, h = SKIN_SIZE
	rng = random.Random(7)
	np_rng = np.random.default_rng(7)
	u = (np.arange(w) + 0.5) / w
	v = (np.arange(h) + 0.5) / h
	uu, vv = np.meshgrid(u, v)

	def smooth(a, b, x):
		t = np.clip((x - a) / (b - a), 0.0, 1.0)
		return t * t * (3.0 - 2.0 * t)

	def wander(cells, seed):
		"""Soft noise, `cells` to the fish's length."""
		r = np.random.default_rng(seed)
		grid = r.random((max(cells // 4, 3), cells))
		x = uu * (cells - 1)
		y = vv * (grid.shape[0] - 1)
		x0 = np.floor(x).astype(int).clip(0, cells - 2)
		y0 = np.floor(y).astype(int).clip(0, grid.shape[0] - 2)
		fx = smooth(0.0, 1.0, x - x0)
		fy = smooth(0.0, 1.0, y - y0)
		return (grid[y0, x0] * (1 - fx) + grid[y0, x0 + 1] * fx) * (1 - fy) + (grid[y0 + 1, x0] * (1 - fx) + grid[y0 + 1, x0 + 1] * fx) * fy

	# The back: the dark comes down to about the lateral line, higher at the head.
	edge = 0.71 + 0.07 * smooth(0.25, 0.0, uu) + (wander(40, 1) - 0.5) * 0.09 + (wander(120, 2) - 0.5) * 0.04
	back = smooth(edge - 0.05, edge + 0.1, vv)
	# The spots, thick on the back and the tail end, thinning down the flank.
	spots = np.zeros((h, w))
	yy, xx = np.mgrid[0:h, 0:w]
	for _ in range(150):
		cu = rng.uniform(0.09, 0.8)
		cv = 1.0 - rng.random() ** 1.5 * 0.62
		cr = rng.uniform(0.0035, 0.0085)
		x0 = cu * w
		y0 = cv * h
		ru = cr * w
		rv = cr * w * 0.9
		lo = (int(max(y0 - rv * 2, 0)), int(min(y0 + rv * 2, h)), int(max(x0 - ru * 2, 0)), int(min(x0 + ru * 2, w)))
		yy_part = yy[lo[0]:lo[1], lo[2]:lo[3]]
		xx_part = xx[lo[0]:lo[1], lo[2]:lo[3]]
		d = np.sqrt(((xx_part - x0) / ru) ** 2 + ((yy_part - y0) / rv) ** 2)
		spots[lo[0]:lo[1], lo[2]:lo[3]] = np.maximum(spots[lo[0]:lo[1], lo[2]:lo[3]], smooth(1.1, 0.75, d))
	# The lines: the lateral line, the gill cover's arc, the mouth.
	lateral = smooth(0.012, 0.0, np.abs(vv - (0.57 + 0.02 * np.sin(uu * 7.0)))) * smooth(0.19, 0.24, uu) * smooth(0.84, 0.76, uu) * 0.55
	arc = np.abs(uu - (0.178 - 0.1 * (vv - 0.46) ** 2 * 2.2))
	gill = smooth(0.006, 0.0, arc) * smooth(0.08, 0.22, vv) * smooth(0.86, 0.72, vv)
	mouth = smooth(0.016, 0.0, np.abs(vv - (0.38 + uu * 0.3))) * smooth(0.078, 0.06, uu) * 0.9
	lines = np.maximum(np.maximum(lateral, gill), mouth)
	# The scales: rows offset by half, each a little dome, tiny on the head.
	cell_u = 110.0
	cell_v = 34.0
	row = np.floor(vv * cell_v)
	shift = np.where(np.mod(row, 2.0) > 0.5, 0.5, 0.0)
	fu = np.mod(uu * cell_u + shift, 1.0) - 0.5
	fv = np.mod(vv * cell_v, 1.0) - 0.5
	scales = 1.0 - np.clip(np.sqrt(fu * fu + fv * fv) * 1.6, 0.0, 1.0)
	scales = scales * smooth(0.16, 0.24, uu) * smooth(0.84, 0.78, uu)
	scales = np.clip(scales + (np_rng.random((h, w)) - 0.5) * 0.25 * (scales > 0.02), 0.0, 1.0)

	pixels = np.stack([back, spots, lines, scales], axis=-1)
	img = bpy.data.images.new("hero_fish_skin", w, h, alpha=True, float_buffer=False)
	img.colorspace_settings.name = "Non-Color"
	img.alpha_mode = "NONE"
	img.pixels.foreach_set(np.clip(pixels, 0.0, 1.0).astype(np.float32).ravel())
	img.filepath_raw = str(SKIN.resolve())
	img.file_format = "PNG"
	SKIN.parent.mkdir(parents=True, exist_ok=True)
	img.save()


def export(b):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	mesh = bpy.data.meshes.new("HeroFish")
	mesh.from_pydata(b.verts, [], b.faces)
	mesh.update()
	mesh.polygons.foreach_set("use_smooth", b.smooth)
	uv = mesh.uv_layers.new(name="UVMap")
	col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
	mesh.color_attributes.active_color_index = 0
	for i, c in enumerate(b.cols):
		col.data[i].color = c
	for loop in mesh.loops:
		uv.data[loop.index].uv = b.uvs[loop.vertex_index]
	mesh.update()
	mat = bpy.data.materials.new("fish")
	mesh.materials.append(mat)
	ob = bpy.data.objects.new("HeroFish", mesh)
	bpy.context.collection.objects.link(ob)
	OUT.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=str(OUT), export_format="GLB", use_selection=False, export_apply=False,
		export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
		export_normals=True, export_tangents=False, export_animations=False, export_cameras=False,
		export_lights=False, export_morph=False, export_skins=False)
	raw = OUT.read_bytes()
	jlen = struct.unpack_from("<I", raw, 12)[0]
	doc = json.loads(raw[20:20 + jlen].decode("utf8"))
	prim = doc["meshes"][0]["primitives"][0]
	print("hero fish: %d tris, %d verts, %d bytes, attributes %s" % (
		doc["accessors"][prim["indices"]]["count"] // 3, doc["accessors"][prim["attributes"]["POSITION"]]["count"],
		len(raw), sorted(prim["attributes"].keys())))


b = Build()
body(b)
fins(b)
export(b)
skin()
print("wrote", OUT, SKIN)
