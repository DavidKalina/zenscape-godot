"""Build the coast's two models: the lighthouse and the moored boat.

Faceted low poly, one colour a material, no textures: the game bakes each
material's colour into vertex colours and lays the weathering on top
(scripts/endless/coast_sites.gd `_bake`). 1 unit = 1 m.

    python tools/blender.py run art/blender/coast/coast_build.py [-- lighthouse|boat]

Writes assets/models/lighthouse.glb and assets/models/boat.glb.

Lighthouse: origin at the rock under the door; Blender +Z up; lamp at
z = LAMP (scripts/endless/coast_sites.gd LAMP_Y must match).

Boat: origin on the waterline amidships, bow toward Blender +Y (Godot -Z),
deck at z = DECK (coast_sites.gd DECK_Y). The clear deck runs from the bow
plate to the house: the plane lands on it bow to stern.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[3]
MODELS = ROOT / "assets/models"
LAMP = 50.0
DECK = 4.6
# Half length and half beam of the hull (m).
HL = 56.0
HB = 10.5


def mat(name, rgb, rough=0.85):
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	b.inputs["Base Color"].default_value = (*rgb, 1.0)
	b.inputs["Roughness"].default_value = rough
	return m


def obj(name, bm, mats):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for m in mats:
		me.materials.append(m)
	o = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(o)
	return o


def ring(bm, r, z, n=20, cx=0.0, cy=0.0, wob=0.0, rng=None, ph=0.0):
	vs = []
	for i in range(n):
		a = ph + i * math.tau / n
		k = r + (rng.uniform(-wob, wob) if rng else 0.0)
		vs.append(bm.verts.new((cx + math.cos(a) * k, cy + math.sin(a) * k, z)))
	return vs


def band(bm, a, b, m):
	n = len(a)
	for i in range(n):
		f = bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
		f.material_index = m


def cap(bm, r, m, flip=False):
	f = bm.faces.new(list(reversed(r)) if flip else r)
	f.material_index = m


def box(bm, x0, x1, y0, y1, z0, z1, m):
	v = [bm.verts.new(p) for p in (
		(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
		(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
	for q in ((3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
		bm.faces.new([v[i] for i in q]).material_index = m


def post(bm, x0, y0, z0, x1, y1, z1, r, m, n=6):
	"""A thin strut from one point to another (world axes)."""
	a = ring_at(bm, x0, y0, z0, x1 - x0, y1 - y0, z1 - z0, r, n)
	b = [bm.verts.new((v.co.x + x1 - x0, v.co.y + y1 - y0, v.co.z + z1 - z0)) for v in a]
	band(bm, a, b, m)


def ring_at(bm, x, y, z, dx, dy, dz, r, n):
	import mathutils
	d = mathutils.Vector((dx, dy, dz)).normalized()
	u = d.orthogonal().normalized()
	w = d.cross(u)
	vs = []
	for i in range(n):
		a = i * math.tau / n
		p = mathutils.Vector((x, y, z)) + (u * math.cos(a) + w * math.sin(a)) * r
		vs.append(bm.verts.new(p))
	return vs


def lighthouse():
	rng = random.Random(7)
	mats = [
		mat("white", (0.70, 0.68, 0.62)),     # 0 limewash
		mat("oxblood", (0.30, 0.075, 0.055)), # 1 the bands
		mat("stone", (0.27, 0.26, 0.25)),     # 2 plinth, keeper's walls
		mat("iron", (0.055, 0.06, 0.06), 0.6),# 3 gallery, lantern frame
		mat("glass", (0.12, 0.13, 0.11), 0.2),# 4 lantern panes
		mat("slate", (0.13, 0.14, 0.16)),     # 5 roofs
		mat("window", (0.03, 0.035, 0.04)),   # 6 windows, door
		mat("copper", (0.17, 0.30, 0.26)),    # 7 the dome, gone green
	]
	bm = bmesh.new()
	# The plinth, rough stone, its foot sunk into the rock.
	r0 = ring(bm, 13.5, -5.0, 12, wob=0.6, rng=rng)
	r1 = ring(bm, 12.6, 3.2, 12, wob=0.5, rng=rng)
	r2 = ring(bm, 10.6, 4.0, 12)
	band(bm, r0, r1, 2)
	band(bm, r1, r2, 2)
	# The tower: bands of limewash and oxblood, tapered; the waist drawn in.
	n = 20
	h = 42.0
	bands = [0, 1, 0, 1, 0, 1, 0]
	rows = 28
	prev = ring(bm, 9.2, 4.0, n)
	for i in range(1, rows + 1):
		t = i / rows
		r = 9.2 - 4.3 * t + 0.9 * t * t * t
		cur = ring(bm, r, 4.0 + h * t, n, wob=0.03, rng=rng)
		band(bm, prev, cur, bands[min(int((i - 1) / rows * len(bands)), len(bands) - 1)])
		prev = cur
	top_r = 9.2 - 4.3 + 0.9
	ztop = 4.0 + h
	# The gallery: corbelled out, a deck, a rail.
	g0 = ring(bm, top_r + 2.3, ztop + 0.9, n)
	g1 = ring(bm, top_r + 2.3, ztop + 1.3, n)
	band(bm, prev, g0, 3)
	band(bm, g0, g1, 3)
	cap(bm, g1, 3)
	for i in range(0, n, 2):
		a = i * math.tau / n
		x, y = math.cos(a) * (top_r + 2.1), math.sin(a) * (top_r + 2.1)
		post(bm, x, y, ztop + 1.3, x, y, ztop + 2.6, 0.07, 3, 4)
	rail = ring(bm, top_r + 2.1, ztop + 2.5, n)
	rail2 = ring(bm, top_r + 2.1, ztop + 2.65, n)
	band(bm, rail, rail2, 3)
	band(bm, ring(bm, top_r + 2.0, ztop + 2.65, n), ring(bm, top_r + 2.0, ztop + 2.5, n), 3)
	# The lantern room: a dark drum of panes, iron bars, the green dome.
	zl = ztop + 1.3
	base0 = ring(bm, 3.4, zl, 12)
	base1 = ring(bm, 3.4, zl + 1.0, 12)
	band(bm, base0, base1, 3)
	glass = ring(bm, 3.2, zl + 1.0, 12)
	glass1 = ring(bm, 3.2, zl + 4.4, 12)
	band(bm, glass, glass1, 4)
	for i in range(12):
		a = i * math.tau / 12
		x, y = math.cos(a) * 3.25, math.sin(a) * 3.25
		post(bm, x, y, zl + 1.0, x, y, zl + 4.4, 0.09, 3, 4)
	d0 = ring(bm, 3.7, zl + 4.4, 12)
	d1 = ring(bm, 3.0, zl + 5.5, 12)
	d2 = ring(bm, 1.2, zl + 6.6, 12)
	d3 = ring(bm, 0.25, zl + 7.1, 12)
	band(bm, d0, d1, 7)
	band(bm, d1, d2, 7)
	band(bm, d2, d3, 7)
	cap(bm, d3, 7)
	post(bm, 0, 0, zl + 7.0, 0, 0, zl + 9.4, 0.12, 3, 6)
	# The windows up the stair, turning round the tower, and the door.
	for i in range(8):
		t = 0.08 + i * 0.115
		z = 4.0 + h * t
		r = 9.2 - 4.3 * t + 0.9 * t * t * t
		a = 1.3 + i * 2.2
		c, s = math.cos(a), math.sin(a)
		w = 0.7
		q = [bm.verts.new((c * (r + 0.06) - s * w * sx, s * (r + 0.06) + c * w * sx, z + sz))
			for sx, sz in ((-1, -1.3), (1, -1.3), (1, 1.3), (-1, 1.3))]
		bm.faces.new(q).material_index = 6
	box(bm, -1.2, 1.2, -9.7, -8.9, 4.0, 7.2, 6)
	o = [obj("tower", bm, mats)]
	# The keeper's house against the tower, low, slated.
	bm = bmesh.new()
	box(bm, -15.0, -5.0, -7.0, 4.0, -3.0, 7.5, 2)
	a = [bm.verts.new(p) for p in ((-15.8, -7.6, 7.5), (-4.5, -7.6, 7.5), (-4.5, 4.6, 7.5), (-15.8, 4.6, 7.5))]
	b = [bm.verts.new(p) for p in ((-15.8, -1.5, 11.4), (-4.5, -1.5, 11.4))]
	for f, m in (((a[0], a[1], b[1], b[0]), 5), ((a[1], a[2], b[1]), 5), ((a[2], a[3], b[0], b[1]), 5), ((a[3], a[0], b[0]), 5)):
		bm.faces.new(f).material_index = m
	box(bm, -13.5, -11.9, -2.4, -0.8, 8.0, 13.6, 2)
	for x in (-13.0, -9.0):
		box(bm, x, x + 1.8, -7.08, -6.98, 3.0, 5.2, 6)
	o.append(obj("keeper", bm, mats))
	return o


def hull_section(y):
	"""Half beam at the deck and at the bilge, and the deck's rise, at station y."""
	t = y / HL
	bow = max(0.0, (t - 0.45) / 0.55)
	stern = max(0.0, (-t - 0.72) / 0.28)
	deck = HB * (1.0 - bow ** 2.1 * 0.97) * (1.0 - 0.3 * stern ** 2)
	bilge = HB * 0.93 * (1.0 - bow ** 1.25 * 0.995) * (1.0 - 0.75 * stern ** 1.5)
	return deck, bilge, 0.0


def boat():
	rng = random.Random(3)
	mats = [
		mat("hull", (0.055, 0.06, 0.065)),      # 0 tarred plates
		mat("rust", (0.25, 0.10, 0.05)),        # 1 the boot-top
		mat("deck", (0.26, 0.24, 0.215)),       # 2 worn steel
		mat("house", (0.60, 0.57, 0.50)),       # 3 the house, old cream
		mat("window", (0.03, 0.035, 0.04)),     # 4
		mat("funnel", (0.10, 0.10, 0.10)),      # 5
		mat("hatch", (0.17, 0.155, 0.13)),      # 6 hatch boards
		mat("band", (0.42, 0.20, 0.07)),        # 7 funnel band, ochre
		mat("plate", (0.20, 0.19, 0.175)),      # 8 deck plates, a second tone
	]
	bm = bmesh.new()
	# The hull: stations along y, keel to deck edge to the far side.
	st = 22
	rows = []
	for i in range(st + 1):
		y = -HL + 2.0 * HL * i / st
		d, b, _ = hull_section(y)
		t = y / HL
		sheer = 0.0
		keel = -6.0 + 3.0 * max(0.0, t - 0.8) / 0.2
		line = -0.5 if t < 0.9 else -0.5
		pts = [(0.0, keel), (b * 0.8, keel + 0.5), (b, -2.6), (d * 0.985, line), (d * 0.99, 0.9), (d, DECK + sheer)]
		rows.append([bm.verts.new((sign * x, y, z)) for sign in (1,) for x, z in pts]
			+ [bm.verts.new((-x, y, z)) for x, z in reversed(pts[:-0 or None])])
	m_of = [0, 0, 1, 0, 0]
	for i in range(st):
		a, b = rows[i], rows[i + 1]
		k = len(pts)
		for j in range(k - 1):
			# Starboard, then port (its row reversed).
			f = bm.faces.new((a[j], a[j + 1], b[j + 1], b[j]))
			f.material_index = m_of[j]
			g = bm.faces.new((a[k + j], b[k + j], b[k + j + 1], a[k + j + 1]))
			g.material_index = m_of[k - 2 - j]
	# Stem and transom.
	e = rows[0]
	bm.faces.new(list(reversed(e[1:len(pts)] + e[len(pts):-1]))).material_index = 0
	e = rows[-1]
	bm.faces.new(e[1:len(pts)] + e[len(pts):-1]).material_index = 0
	# The deck: runs edge to edge, plates in two tones.
	for i in range(st):
		ya = -HL + 2.0 * HL * i / st
		yb = ya + 2.0 * HL / st
		da = hull_section(ya)[0]
		db = hull_section(yb)[0]
		for s0, s1, m in ((-1.0, -0.33, 2), (-0.33, 0.33, 8 if i % 2 else 2), (0.33, 1.0, 2)):
			q = [bm.verts.new((da * s0, ya, DECK)), bm.verts.new((da * s1, ya, DECK)), bm.verts.new((db * s1, yb, DECK)), bm.verts.new((db * s0, yb, DECK))]
			bm.faces.new(q).material_index = m
	# The bulwark: low, knee high, broken in two places; the side's silhouette.
	for side in (-1.0, 1.0):
		i = 0
		while i < st:
			if i in (6, 7, 13):
				i += 1
				continue
			ya = -HL + 2.0 * HL * i / st
			yb = ya + 2.0 * HL / st
			da = hull_section(ya)[0]
			db = hull_section(yb)[0]
			h0 = 0.55 + rng.uniform(-0.08, 0.08)
			h1 = 0.55 + rng.uniform(-0.08, 0.08)
			q = [bm.verts.new((side * da, ya, DECK)), bm.verts.new((side * db, yb, DECK)),
				bm.verts.new((side * db, yb, DECK + h1)), bm.verts.new((side * da, ya, DECK + h0))]
			bm.faces.new(q if side > 0 else list(reversed(q))).material_index = 0
			q2 = [bm.verts.new((side * (da - 0.1), ya, DECK)), bm.verts.new((side * (db - 0.1), yb, DECK)),
				bm.verts.new((side * (db - 0.1), yb, DECK + h1)), bm.verts.new((side * (da - 0.1), ya, DECK + h0))]
			bm.faces.new(q2 if side < 0 else list(reversed(q2))).material_index = 0
			i += 1
	# Flush hatch boards, painted on the run of the deck; bollards at the rail.
	for y0 in (-18.0, 2.0, 22.0):
		box(bm, -5.0, 5.0, y0, y0 + 12.0, DECK, DECK + 0.04, 6)
		for x in (-5.0, -1.7, 1.7, 5.0):
			box(bm, x - 0.05, x + 0.05, y0, y0 + 12.0, DECK, DECK + 0.06, 0)
	for y in (-26.0, 12.0, 34.0):
		for s in (-1.0, 1.0):
			box(bm, s * 9.4 - 0.25, s * 9.4 + 0.25, y - 0.25, y + 0.25, DECK, DECK + 0.6, 0)
	o = [obj("hull", bm, mats)]
	# The house aft, two decks and a bridge, the funnel, the mast behind them.
	bm = bmesh.new()
	yh = -28.0
	box(bm, -8.0, 8.0, yh - 18.0, yh, DECK, DECK + 3.2, 3)
	box(bm, -6.0, 6.0, yh - 14.0, yh - 1.0, DECK + 3.2, DECK + 6.2, 3)
	box(bm, -6.4, 6.4, yh - 14.4, yh - 0.6, DECK + 6.2, DECK + 6.5, 5)
	box(bm, -4.0, 4.0, yh - 7.0, yh - 2.0, DECK + 6.5, DECK + 9.0, 3)
	box(bm, -4.4, 4.4, yh - 7.4, yh - 1.6, DECK + 9.0, DECK + 9.3, 5)
	# The bridge's windows, a dark strip round it; a line of ports below.
	box(bm, -3.6, 3.6, yh - 2.04, yh - 1.96, DECK + 7.5, DECK + 8.6, 4)
	for side in (-1.0, 1.0):
		box(bm, side * 4.0 - 0.04, side * 4.0 + 0.04, yh - 6.6, yh - 2.4, DECK + 7.5, DECK + 8.6, 4)
	for x in range(-5, 6, 2):
		box(bm, x - 0.3, x + 0.3, yh - 0.04, yh + 0.04, DECK + 1.4, DECK + 2.2, 4)
		box(bm, x * 0.9 - 0.3, x * 0.9 + 0.3, yh - 1.04, yh - 0.96, DECK + 4.2, DECK + 5.0, 4)
	r0 = ring(bm, 1.9, DECK + 6.5, 10, 0.0, yh - 11.0)
	r1 = ring(bm, 1.8, DECK + 12.0, 10, 0.0, yh - 11.4)
	r2 = ring(bm, 1.8, DECK + 13.2, 10, 0.0, yh - 11.5)
	r3 = ring(bm, 1.7, DECK + 15.0, 10, 0.0, yh - 11.7)
	band(bm, r0, r1, 5)
	band(bm, r1, r2, 7)
	band(bm, r2, r3, 5)
	cap(bm, r3, 5)
	o.append(obj("house", bm, mats))
	# Masts, a derrick, the stays and the anchor chain: thin, for the outline.
	bm = bmesh.new()
	post(bm, 0, yh - 20.0, DECK, 0, yh - 20.0, DECK + 19.0, 0.22, 0)
	# King posts at the rails, the derricks swung out of the way, so she reads
	# as a ship from far off and leaves the deck clear.
	for y in (14.0, -12.0):
		for s in (-1.0, 1.0):
			post(bm, s * 9.6, y, DECK, s * 9.6, y, DECK + 12.0, 0.26, 0)
			post(bm, s * 9.6, y, DECK + 1.2, s * 10.4, y - 13.0, DECK + 7.5, 0.1, 0)
			post(bm, s * 9.6, y, DECK + 11.8, s * 10.4, y - 13.0, DECK + 7.5, 0.035, 0, 4)
	post(bm, -2.6, yh - 20.0, DECK + 14.0, 2.6, yh - 20.0, DECK + 14.0, 0.09, 0)
	post(bm, 0, yh - 20.0, DECK + 18.5, 8.0, yh - 19.0, DECK + 0.3, 0.035, 0, 4)
	post(bm, 0, yh - 20.0, DECK + 18.5, -8.0, yh - 19.0, DECK + 0.3, 0.035, 0, 4)
	post(bm, 0, yh - 20.0, DECK + 18.5, 0, yh - 7.0, DECK + 9.3, 0.035, 0, 4)
	for s, sag in ((-1.0, 0.0), (1.0, 2.0)):
		x0, y0, z0 = s * 2.6, 51.0, DECK - 0.8
		x1, y1, z1 = s * 7.5, 66.0 + sag, -4.0
		for i in range(9):
			t0, t1 = i / 9, (i + 1) / 9
			p0 = (x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0, z0 + (z1 - z0) * t0 - math.sin(t0 * math.pi) * 1.2)
			p1 = (x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1, z0 + (z1 - z0) * t1 - math.sin(t1 * math.pi) * 1.2)
			post(bm, *p0, *p1, 0.16, 1, 4)
	o.append(obj("rigging", bm, mats))
	return o


def export(name, objs):
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	tris = 0
	for o in objs:
		o.data.calc_loop_triangles()
		tris += len(o.data.loop_triangles)
	MODELS.mkdir(parents=True, exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=str(MODELS / f"{name}.glb"), export_format="GLB", use_selection=True, export_apply=True)
	print(f"{name}: {tris} triangles")


def main():
	want = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	bpy.ops.wm.read_factory_settings(use_empty=True)
	if not want or "lighthouse" in want:
		export("lighthouse", lighthouse())
	bpy.ops.wm.read_factory_settings(use_empty=True)
	if not want or "boat" in want:
		export("boat", boat())


main()
