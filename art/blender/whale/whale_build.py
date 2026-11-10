"""The whale of the open sea: a humpback's shape lofted along its spine, rigged,
with one clip, `dive` (a surface roll into a fluke-up dive).

    python tools/blender.py run art/blender/whale/whale_build.py
    python tools/blender.py run art/blender/whale/whale_build.py -- --render=scratch/whale
    python tools/godot.py --headless --editor --import

Writes assets/models/whale/whale.glb and whale_skin.png (and whale.blend beside
this script). scripts/endless/whale_body.gd plays it; its contract is
docs/design/whale/spec-whale.md.

Blender's axes here: +Y the nose's way, +Z up, the spine on the y axis with the
root (the chest, PIVOT of the way from the nose) at the origin. The exporter
turns that to Godot's: the nose along -Z.

The clip's frame: the origin is on the still water where the tail stock goes
under, the whale swimming along +Y (Godot -Z). CLIP times are seconds; the
beats (BEATS) are printed and are the ones whale_body.gd names.

Vertex colour: R a barnacle (its own pale crust), G the creases' shade.
UV: the body's is x nose to tail, y belly (0) to back (0.5), both flanks on the
same paint; the flukes' and flippers' is x tip to tip, y the chord, the upper
side in 0.5..0.75 and the under side in 0.75..1.
"""
import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Quaternion, Vector

OUT = Path("assets/models/whale/whale.glb")
SKIN = Path("assets/models/whale/whale_skin.png")
BLEND = Path("art/blender/whale/whale.blend")
SKIN_SIZE = 1024
FPS = 30

## Nose to the tail stock's end (m), the flukes' span tip to tip, and where the
## root sits along the spine (a share from the nose).
LENGTH = 56.0
FLUKE_SPAN = 26.0
PIVOT = 0.45
FLUKE_AT = 0.945
SIDES = 20
RINGS = [0.0, 0.008, 0.025, 0.05, 0.09, 0.14, 0.2, 0.26, 0.32, 0.38, 0.44, 0.5, 0.56, 0.61, 0.64, 0.66, 0.68,
	0.71, 0.74, 0.77, 0.8, 0.83, 0.86, 0.89, 0.92, 0.95, 0.975, 1.0]
## The outline, as shares of LENGTH: (along, over the spine, under it, half width).
OUTLINE = [
	(0.00, 0.004, 0.004, 0.004),
	(0.02, 0.022, 0.030, 0.036),
	(0.06, 0.040, 0.058, 0.064),
	(0.12, 0.056, 0.084, 0.084),
	(0.20, 0.070, 0.104, 0.096),
	(0.32, 0.084, 0.108, 0.100),
	(0.45, 0.090, 0.098, 0.094),
	(0.58, 0.084, 0.080, 0.078),
	(0.70, 0.068, 0.058, 0.052),
	(0.80, 0.050, 0.042, 0.037),
	(0.88, 0.036, 0.031, 0.027),
	(0.94, 0.025, 0.022, 0.021),
	(0.975, 0.013, 0.012, 0.030),
	(1.00, 0.005, 0.005, 0.020),
]
## The spine's joints: bone, where it starts (share from the nose). The fore
## chain runs root > neck > head, the aft chain root > lumbar > tail1..3 > fluke.
FORE = [("neck", 0.36), ("head", 0.22)]
AFT = [("lumbar", 0.58), ("tail1", 0.68), ("tail2", 0.77), ("tail3", 0.85), ("fluke", 0.925)]
BLEND_HALF = 0.035

## The clip: (t s, forward m, the root's height m, nose down deg, the head's
## bend deg, the aft chain's bends deg (tail down +), the lobes' droop deg).
CLIP_LENGTH = 16.0
KEYS = [
	(0.0, -50.0, -6.4, -9.0, 0.0, (0, 0, 0, 0, 0), 0),
	(0.5, -47.5, -4.7, -11.0, -2.0, (0, 0, 0, 0, 0), 0),
	(2.0, -40.0, -7.0, -3.0, 2.0, (1, 1, 1, 1, 0), 0),
	(3.0, -35.0, -4.6, 3.0, 8.0, (2, 3, 3, 3, 2), 0),
	(4.5, -27.0, -0.8, 8.0, 15.0, (5, 6, 7, 7, 4), 2),
	(6.0, -19.0, -1.2, 15.0, 19.0, (10, 12, 13, 11, 6), 4),
	(7.5, -11.0, -6.8, 40.0, 14.0, (7, 7, 4, 0, -5), 8),
	(9.0, -3.5, -14.6, 60.0, 8.0, (0, -3, -6, -8, -10), 12),
	(10.0, 1.5, -16.4, 73.0, 4.0, (-2, -4, -6, -8, -10), 7),
	(12.0, 4.0, -18.6, 77.0, 2.0, (-1, -2, -4, -5, -6), 4),
	(14.5, 7.0, -36.0, 82.0, 0.0, (0, 0, -1, -2, -2), 2),
	(16.0, 9.0, -52.0, 84.0, 0.0, (0, 0, 0, 0, 0), 0),
]
BEATS = {"blow": 0.4, "back.show": 3.0, "fluke.up": 7.5, "fluke.top": 10.0, "fluke.slide": 12.0, "gone": 15.0}


def smooth(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def outline(s):
	"""(over, under, half width) in m at share `s` from the nose."""
	for a, b in zip(OUTLINE, OUTLINE[1:]):
		if s <= b[0]:
			k = (s - a[0]) / max(b[0] - a[0], 1e-6)
			k = k * k * (3.0 - 2.0 * k) * 0.4 + k * 0.6
			return tuple((a[i] + (b[i] - a[i]) * k) * LENGTH for i in (1, 2, 3))
	return tuple(OUTLINE[-1][i] * LENGTH for i in (1, 2, 3))


def spine_y(s):
	return (PIVOT - s) * LENGTH


def body_point(s, phi):
	"""A point of the skin: `phi` 0 the belly's keel, pi the back."""
	over, under, half = outline(s)
	top = max(0.0, -math.cos(phi)) ** 6
	# The dorsal hump and its small fin, and the knuckles down the tail stock.
	over += 0.020 * LENGTH * math.exp(-((s - 0.665) / 0.022) ** 2) * top
	if 0.70 < s < 0.93:
		over += 0.004 * LENGTH * max(0.0, math.sin((s - 0.70) * math.tau / 0.04)) * top
	n = 2.5
	sn, cs = math.sin(phi), math.cos(phi)
	x = half * math.copysign(abs(sn) ** (2.0 / n), sn)
	z = -(under if cs > 0.0 else over) * math.copysign(abs(cs) ** (2.0 / n), cs)
	return Vector((x, spine_y(s), z))


def spine_weights(s):
	"""{bone: weight} for a point `s` along the spine."""
	joints = [("head", 0.0), ("neck", FORE[1][1]), ("root", FORE[0][1])] + AFT
	out = {}
	for i, (name, start) in enumerate(joints):
		end = joints[i + 1][1] if i + 1 < len(joints) else 9.0
		w = 1.0
		if i > 0:
			w *= float(smooth(start - BLEND_HALF, start + BLEND_HALF, s))
		if i + 1 < len(joints):
			w *= 1.0 - float(smooth(end - BLEND_HALF, end + BLEND_HALF, s))
		if w > 1e-4:
			out[name] = w
	total = sum(out.values())
	return {k: v / total for k, v in out.items()}


class Build:
	def __init__(self):
		self.verts, self.faces, self.uvs, self.cols, self.weights = [], [], [], [], []

	def vert(self, co, uv, col, weights):
		self.verts.append(tuple(co))
		self.uvs.append(uv)
		self.cols.append(col)
		self.weights.append(weights)
		return len(self.verts) - 1


def fluke_edges(t):
	"""How far aft of the flukes' root the leading and trailing edges lie at
	span share `t` (m)."""
	b = FLUKE_SPAN * 0.5
	lead = b * (-0.10 + 0.80 * t ** 1.3)
	trail = b * (0.42 + 0.28 * t + 0.09 * math.sin(math.pi * t)) - 0.09 * b * math.exp(-(t / 0.07) ** 2)
	# The trailing edge's ragged scallops.
	trail += b * 0.012 * math.sin(t * 46.0) * math.sin(math.pi * t)
	return lead, max(trail, lead + 0.02)


def fluke_weights(side, t):
	lobe = 0.92 * float(smooth(0.12, 0.6, t))
	return {"fluke": 1.0 - lobe, "lobe_l" if side < 0 else "lobe_r": lobe}


def fluke_point(side, t, c, face):
	"""A fluke's skin: `side` -1 left 1 right, `t` the span's share, `c` the
	chord's (0 leading), `face` 1 the upper side, -1 the under."""
	b = FLUKE_SPAN * 0.5
	lead, trail = fluke_edges(t)
	d = lead + (trail - lead) * c
	thick = (0.05 * b * (1.0 - t) ** 1.3 + 0.012 * b * (1.0 - t) + 0.02) * (c ** 0.45) * (1.0 - c) * 2.2
	return Vector((side * b * t, spine_y(FLUKE_AT) - d, face * thick))


def add_body(m):
	rings = []
	for s in RINGS:
		ring = []
		w = spine_weights(s)
		for k in range(SIDES + 1):
			phi = math.tau * k / SIDES
			v = min(k, SIDES - k) / (SIDES * 0.5) * 0.5
			# The throat's pleats shade the belly forward of the flippers.
			crease = 1.0
			if s < 0.42 and abs(math.cos(phi)) > 0.0 and math.cos(phi) > 0.25:
				crease = 0.75 + 0.25 * (0.5 + 0.5 * math.cos(k * math.pi))
			ring.append(m.vert(body_point(s, phi), (s, v), (0.0, crease, 0.0, 1.0), w))
		rings.append(ring)
	for a, b in zip(rings, rings[1:]):
		for k in range(SIDES):
			m.faces.append((a[k], a[k + 1], b[k + 1], b[k]))


def add_plate(m, point, weights, spans, chords, v0):
	"""A lens-shaped plate (a fluke, a flipper): `point(t, c, face)`, its upper
	side painted from v0, its under side from v0 + 0.25. `weights(t)`."""
	for face in (1, -1):
		grid = []
		for i in range(spans + 1):
			t = i / spans
			row = []
			for j in range(chords + 1):
				c = j / chords
				co, u = point(t, c, face)
				row.append(m.vert(co, (u, v0 + (0.0 if face > 0 else 0.25) + c * 0.25), (0.0, 1.0, 0.0, 1.0), weights(t)))
			grid.append(row)
		for a, b in zip(grid, grid[1:]):
			for j in range(chords):
				m.faces.append((a[j], a[j + 1], b[j + 1], b[j]) if face > 0 else (a[j], b[j], b[j + 1], a[j + 1]))


def add_flukes(m):
	for side in (-1, 1):
		add_plate(m, lambda t, c, face, side=side: (fluke_point(side, t, c, face), 0.5 + side * 0.5 * t),
			lambda t, side=side: fluke_weights(side, t), 12, 7, 0.5)


def flipper_point(side, t, c, face):
	"""A long knobbed flipper, from the flank at 0.3 out, down and back."""
	root = body_point(0.30, math.pi * 0.5 * 0.55)
	root.x = abs(root.x) * side * 0.9
	long = 0.27 * LENGTH
	chord = 0.062 * LENGTH * (1.0 - 0.75 * t ** 1.6)
	out = Vector((side * 0.62, -0.62, -0.48)).normalized()
	aft = Vector((side * 0.55, 0.78, 0.0)).normalized() * -1.0
	knobs = 0.012 * LENGTH * abs(math.sin(t * 22.0)) * (1.0 - c)
	p = root + out * long * t + aft * (chord * (c - 0.3) - knobs)
	thick = (0.012 * LENGTH * (1.0 - t) + 0.05) * (c ** 0.5) * (1.0 - c) * 2.2
	normal = out.cross(aft).normalized()
	return p + normal * face * thick * side


def add_flippers(m):
	w = spine_weights(0.33)
	for side in (-1, 1):
		add_plate(m, lambda t, c, face, side=side: (flipper_point(side, t, c, face), 0.5 + side * (0.04 + 0.4 * t)),
			lambda t: w, 8, 4, 0.5)


def add_crust(m, at, normal, size, weights, rng, uv, crust=1.0):
	"""A barnacle (or a tubercle, `crust` 0): a squat six-sided cone."""
	n = normal.normalized()
	a = n.cross(Vector((0.3, 0.9, 0.2))).normalized()
	b = n.cross(a)
	turn = rng.uniform(0.0, math.tau)
	col = (crust, 0.8, 0.0, 1.0)
	base, lip = [], []
	for k in range(6):
		ang = turn + math.tau * k / 6
		r = size * rng.uniform(0.85, 1.15)
		way = a * math.cos(ang) + b * math.sin(ang)
		base.append(m.vert(at + way * r - n * size * 0.15, uv, (crust, 0.45, 0.0, 1.0), weights))
		lip.append(m.vert(at + way * r * 0.45 + n * size * 0.55, uv, col, weights))
	top = m.vert(at + n * size * (0.3 if crust > 0.5 else 0.62), uv, (crust, 0.3 if crust > 0.5 else 1.0, 0.0, 1.0), weights)
	for k in range(6):
		k1 = (k + 1) % 6
		m.faces.append((base[k], base[k1], lip[k1], lip[k]))
		m.faces.append((lip[k], lip[k1], top))


def add_growths(m):
	rng = random.Random(11)
	def on_body(s, phi, size, crust):
		at = body_point(s, phi)
		normal = (at - body_point(s, phi + math.pi)).normalized()
		v = min(phi % math.tau, math.tau - phi % math.tau) / math.pi * 0.5
		add_crust(m, at, normal, size, spine_weights(s), rng, (s, v), crust)
	# The head's tubercles, the chin's and the tail stock's barnacles.
	for _ in range(34):
		on_body(rng.uniform(0.015, 0.16), math.pi + rng.uniform(-0.9, 0.9), rng.uniform(0.2, 0.34), 0.0)
	for _ in range(40):
		on_body(rng.uniform(0.01, 0.12), rng.uniform(-0.8, 0.8), rng.uniform(0.12, 0.3), 1.0)
	for _ in range(46):
		s = rng.uniform(0.74, 0.94)
		on_body(s, rng.choice((0.0, math.pi)) + rng.uniform(-0.45, 0.45), rng.uniform(0.1, 0.24), 1.0)
	# Clusters on the flukes: the tips, the trailing edge, the leading edge's root.
	for _ in range(150):
		side = rng.choice((-1, 1))
		kind = rng.random()
		if kind < 0.45:
			t, c = rng.uniform(0.72, 0.99), rng.uniform(0.05, 0.9)
		elif kind < 0.8:
			t, c = rng.uniform(0.1, 0.95), rng.uniform(0.82, 0.98)
		else:
			t, c = rng.uniform(0.05, 0.6), rng.uniform(0.02, 0.14)
		face = rng.choice((-1, 1))
		at = fluke_point(side, t, c, face)
		add_crust(m, at, Vector((0, 0, face)), rng.uniform(0.07, 0.2), fluke_weights(side, t), rng,
			(0.5 + side * 0.5 * t, 0.5 + (0.0 if face > 0 else 0.25) + c * 0.25), 1.0)


def paint_skin():
	n = SKIN_SIZE
	rng = np.random.default_rng(5)
	yy, xx = np.mgrid[0:n, 0:n]
	uu = (xx + 0.5) / n
	vv = (yy + 0.5) / n

	def wander(cells_x, cells_y, seed):
		r = np.random.default_rng(seed)
		grid = r.random((cells_y + 1, cells_x + 1))
		x = uu * cells_x
		y = vv * cells_y
		x0 = np.floor(x).astype(int).clip(0, cells_x - 1)
		y0 = np.floor(y).astype(int).clip(0, cells_y - 1)
		fx = smooth(0.0, 1.0, x - x0)
		fy = smooth(0.0, 1.0, y - y0)
		return (grid[y0, x0] * (1 - fx) + grid[y0, x0 + 1] * fx) * (1 - fy) + (grid[y0 + 1, x0] * (1 - fx) + grid[y0 + 1, x0 + 1] * fx) * fy

	def fbm(cx, cy, seed):
		return wander(cx, cy, seed) * 0.5 + wander(cx * 2, cy * 2, seed + 1) * 0.28 + wander(cx * 5, cy * 5, seed + 2) * 0.14 + wander(cx * 12, cy * 12, seed + 3) * 0.08

	# value: 0 the dark of the back, 1 the pale of the belly and the flukes' under side.
	body = vv < 0.5
	v_body = vv / 0.5
	edge = 0.30 + (fbm(9, 5, 1) - 0.5) * 0.34 - 0.16 * smooth(0.45, 0.9, uu)
	pale = smooth(edge + 0.06, edge - 0.08, v_body) * (0.75 + 0.25 * fbm(30, 14, 7))
	# The flukes: the upper side dark, the under side with its white field, dark
	# round the edges and down the middle, eaten into by blotches.
	under = vv >= 0.75
	c = np.where(under, (vv - 0.75) / 0.25, (vv - 0.5) / 0.25)
	t = np.abs(uu - 0.5) * 2.0
	field = smooth(0.18, 0.42, c) * smooth(0.99, 0.84, c) * smooth(0.06, 0.2, t) * smooth(0.97, 0.7, t)
	field = smooth(0.55, 0.8, field * (0.3 + 1.1 * fbm(12, 9, 21))) * (0.5 + 0.5 * fbm(40, 30, 61))
	pale = np.where(body, pale, np.where(under, field, 0.0))

	dark = np.array([0.29, 0.31, 0.335])
	light = np.array([0.47, 0.49, 0.5])
	mottle = fbm(22, 22, 31)
	tone = 0.82 + 0.36 * mottle
	col = (dark[None, None, :] * (1 - pale[..., None]) + light[None, None, :] * pale[..., None]) * tone[..., None]
	# A brown-green film of algae along the back and the flukes' upper side.
	film = smooth(0.6, 0.85, fbm(7, 7, 41)) * (1.0 - pale) * 0.3
	col = col * (1 - film[..., None]) + np.array([0.27, 0.26, 0.19])[None, None, :] * film[..., None]

	# Scars: pale scratches (rakes in threes), and small ringed pits.
	scar = np.zeros((n, n))
	r = np.random.default_rng(9)
	def stroke(x0, y0, ang, length, bend, wide, strength):
		steps = int(length)
		for i in range(steps):
			k = i / max(steps - 1, 1)
			a = ang + bend * (k - 0.5)
			x = x0 + math.cos(ang) * length * k + math.sin(a) * bend * 6.0 * k
			y = y0 + math.sin(ang) * length * k
			xi, yi = int(x) % n, int(y)
			if 0 <= yi < n - 1:
				fade = math.sin(math.pi * k) ** 0.6 * strength
				for dy in range(-wide, wide + 1):
					for dx in range(-wide, wide + 1):
						yj, xj = min(max(yi + dy, 0), n - 1), (xi + dx) % n
						scar[yj, xj] = max(scar[yj, xj], fade * (1.0 - 0.45 * (abs(dx) + abs(dy)) / max(wide, 1)))
	for _ in range(170):
		x0, y0 = r.uniform(0, n), r.uniform(0, n)
		ang = r.uniform(-0.5, 0.5) if r.random() < 0.7 else r.uniform(0, math.tau)
		length = r.uniform(18, 110)
		bend = r.uniform(-0.6, 0.6)
		rake = 3 if r.random() < 0.3 else 1
		for k in range(rake):
			stroke(x0, y0 + k * 5.0, ang, length, bend, 1, r.uniform(0.35, 0.9))
	for _ in range(120):
		x0, y0 = r.uniform(0, n), r.uniform(0, n)
		rad = r.uniform(2.5, 6.0)
		d = np.sqrt((xx - x0) ** 2 + (yy - y0) ** 2)
		ring = smooth(rad + 1.5, rad, d) * smooth(rad - 2.5, rad - 0.5, d)
		scar = np.maximum(scar, ring * r.uniform(0.3, 0.7))
	# A scratch is pale on the dark, dark on the pale.
	scar_col = np.where(pale[..., None] > 0.5, 0.2, 0.46) * np.array([1.0, 0.98, 0.94])[None, None, :]
	col = col * (1 - scar[..., None] * 0.75) + scar_col * scar[..., None] * 0.75
	# Barnacle rash: pale speckle in patches, thick at the head and the tail's end.
	rash_where = smooth(0.62, 0.8, fbm(11, 11, 51)) * np.where(body, smooth(0.14, 0.0, uu) + smooth(0.8, 0.95, uu) + 0.25, smooth(0.6, 0.95, t) + smooth(0.8, 0.98, c) + 0.2)
	speck = (r.random((n, n)) > 0.86).astype(float)
	speck = np.maximum(speck, np.roll(speck, 1, 0) * 0.6)
	rash = np.clip(rash_where, 0.0, 1.0) * speck
	col = col * (1 - rash[..., None] * 0.7) + np.array([0.58, 0.56, 0.5])[None, None, :] * rash[..., None] * 0.7
	# Alpha: how rough (dry crust, scars) against the wet skin.
	rough = np.clip(0.25 + scar * 0.4 + rash * 0.6 + film * 0.3, 0.0, 1.0)
	pixels = np.concatenate([np.clip(col, 0.0, 1.0), rough[..., None]], axis=-1)
	img = bpy.data.images.new("whale_skin", n, n, alpha=True, float_buffer=False)
	img.alpha_mode = "STRAIGHT"
	img.pixels.foreach_set(pixels[::-1].astype(np.float32).ravel())
	img.filepath_raw = str(SKIN.resolve())
	img.file_format = "PNG"
	SKIN.parent.mkdir(parents=True, exist_ok=True)
	img.save()
	return img


def catmull(keys, t, pick):
	"""The keys' value at `t`, a Catmull-Rom through them (uneven times)."""
	i = 0
	while i + 2 < len(keys) and keys[i + 1][0] <= t:
		i += 1
	k0, k1, k2, k3 = keys[max(i - 1, 0)], keys[i], keys[i + 1], keys[min(i + 2, len(keys) - 1)]
	span = k2[0] - k1[0]
	u = min(max((t - k1[0]) / span, 0.0), 1.0)
	p1, p2 = pick(k1), pick(k2)
	m1 = (p2 - pick(k0)) / max(k2[0] - k0[0], 1e-6) * span if k1 is not k0 else (p2 - p1)
	m2 = (pick(k3) - p1) / max(k3[0] - k1[0], 1e-6) * span if k3 is not k2 else (p2 - p1)
	u2, u3 = u * u, u * u * u
	return (2 * u3 - 3 * u2 + 1) * p1 + (u3 - 2 * u2 + u) * m1 + (-2 * u3 + 3 * u2) * p2 + (u3 - u2) * m2


def main():
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	render_to = next((a.split("=", 1)[1] for a in args if a.startswith("--render=")), "")
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.context.scene.render.fps = FPS

	m = Build()
	add_body(m)
	add_flukes(m)
	add_flippers(m)
	add_growths(m)
	mesh = bpy.data.meshes.new("Whale")
	mesh.from_pydata(m.verts, [], m.faces)
	uv = mesh.uv_layers.new(name="UVMap")
	col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
	for loop in mesh.loops:
		u, v = m.uvs[loop.vertex_index]
		uv.data[loop.index].uv = (u, 1.0 - v)
		col.data[loop.index].color = m.cols[loop.vertex_index]
	for poly in mesh.polygons:
		poly.use_smooth = True
	bm = bmesh.new()
	bm.from_mesh(mesh)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	body = bpy.data.objects.new("Whale", mesh)
	bpy.context.scene.collection.objects.link(body)

	skin = paint_skin()
	mat = bpy.data.materials.new("WhaleSkin")
	mat.use_nodes = True
	bsdf = mat.node_tree.nodes["Principled BSDF"]
	tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
	tex.image = skin
	mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	bsdf.inputs["Roughness"].default_value = 0.35
	mesh.materials.append(mat)

	# The rig.
	arm = bpy.data.armatures.new("WhaleRig")
	rig = bpy.data.objects.new("WhaleRig", arm)
	bpy.context.scene.collection.objects.link(rig)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.mode_set(mode="EDIT")
	b = FLUKE_SPAN * 0.5
	fluke_y = spine_y(FLUKE_AT)
	bones = {"root": (Vector((0, 0, 0)), Vector((0, spine_y(0.36), 0)), None)}
	chain = [("root", PIVOT)] + FORE + [("nose", 0.0)]
	for (name, start), (_, end) in zip(chain[1:], chain[2:]):
		bones[name] = (Vector((0, spine_y(start), 0)), Vector((0, spine_y(end), 0)), "root" if name == "neck" else "neck")
	chain = AFT + [("end", 1.04)]
	parent = "root"
	for (name, start), (_, end) in zip(chain, chain[1:]):
		bones[name] = (Vector((0, spine_y(start), 0)), Vector((0, spine_y(end), 0)), parent)
		parent = name
	for side, tag in ((-1, "l"), (1, "r")):
		bones["lobe_" + tag] = (Vector((side * b * 0.12, fluke_y, 0)), Vector((side * b * 0.12, fluke_y - 3.0, 0)), "fluke")
		lead, trail = fluke_edges(0.97)
		bones["tip_" + tag] = (Vector((side * b * 0.97, fluke_y - (lead + trail) * 0.5, 0)), Vector((side * b * 0.97, fluke_y - (lead + trail) * 0.5 - 1.0, 0)), "lobe_" + tag)
	blow = body_point(0.13, math.pi)
	bones["blowhole"] = (blow, blow + Vector((0, 0, 1.0)), "head")
	for name, (head, tail, parent) in bones.items():
		eb = arm.edit_bones.new(name)
		eb.head, eb.tail, eb.roll = head, tail, 0.0
		if parent:
			eb.parent = arm.edit_bones[parent]
			eb.use_connect = False
	bpy.ops.object.mode_set(mode="OBJECT")
	groups = {}
	for i, w in enumerate(m.weights):
		for name, weight in w.items():
			if name not in groups:
				groups[name] = body.vertex_groups.new(name=name)
			groups[name].add([i], weight, "REPLACE")
	body.parent = rig
	body.modifiers.new("Rig", "ARMATURE").object = rig

	# The clip.
	rig.animation_data_create()
	for pb in rig.pose.bones:
		pb.rotation_mode = "QUATERNION"
	rest = {bn.name: bn.matrix_local.copy() for bn in arm.bones}
	across = {name: (rest[name].to_3x3().inverted() @ Vector((1, 0, 0))).normalized() for name in rest}
	along = {name: (rest[name].to_3x3().inverted() @ Vector((0, -1, 0))).normalized() for name in rest}

	def pose(t):
		fwd = catmull(KEYS, t, lambda k: k[1])
		up = catmull(KEYS, t, lambda k: k[2])
		down = math.radians(catmull(KEYS, t, lambda k: k[3]))
		head = math.radians(catmull(KEYS, t, lambda k: k[4]))
		bends = [math.radians(catmull(KEYS, t, lambda k, i=i: float(k[5][i]))) for i in range(5)]
		droop = math.radians(catmull(KEYS, t, lambda k: float(k[6])))
		world = Matrix.Translation(Vector((0.0, fwd, up))) @ Matrix.Rotation(-down, 4, "X")
		out = {"root": (world @ rest["root"], None)}
		# The head's bend, nose down, over its two bones.
		for name in ("neck", "head"):
			out[name] = (None, Quaternion(across[name], -head * 0.5))
		for (name, _), a in zip(AFT, bends):
			out[name] = (None, Quaternion(across[name], a))
		out["lobe_r"] = (None, Quaternion(along["lobe_r"], -droop))
		out["lobe_l"] = (None, Quaternion(along["lobe_l"], droop))
		return out

	frames = round(CLIP_LENGTH * FPS)
	action = bpy.data.actions.new("dive")
	action.use_fake_user = True
	rig.animation_data.action = action
	last = {}
	for f in range(frames + 1):
		for name, (matrix, quat) in pose(f / FPS).items():
			pb = rig.pose.bones[name]
			if matrix is not None:
				pb.matrix = matrix
				quat = pb.rotation_quaternion.copy()
			if name in last and last[name].dot(quat) < 0:
				quat.negate()
			last[name] = quat.copy()
			pb.rotation_quaternion = quat
			pb.keyframe_insert("rotation_quaternion", frame=f)
			if matrix is not None:
				pb.keyframe_insert("location", frame=f)
	action.frame_range = (0, frames)
	for name, t in BEATS.items():
		action.pose_markers.new(name).frame = round(t * FPS)

	if render_to:
		render(rig, body, Path(render_to))

	rig.animation_data.nla_tracks.new().strips.new("dive", 0, action)
	rig.animation_data.action = None
	for pb in rig.pose.bones:
		pb.location = (0, 0, 0)
		pb.rotation_quaternion = (1, 0, 0, 0)
	bpy.context.scene.frame_set(0)
	bpy.ops.wm.save_as_mainfile(filepath=str(BLEND.resolve()))
	bpy.ops.object.select_all(action="DESELECT")
	rig.select_set(True)
	body.select_set(True)
	bpy.context.view_layer.objects.active = rig
	OUT.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=str(OUT.resolve()), export_format="GLB", use_selection=True, export_yup=True,
		export_apply=False, export_animations=True, export_animation_mode="ACTIONS",
		export_force_sampling=True, export_frame_step=1, export_materials="EXPORT", export_image_format="NONE",
		export_normals=True, export_extras=False, export_def_bones=False, export_vertex_color="ACTIVE",
		export_all_vertex_colors=True, export_active_vertex_color_when_no_material=True)
	print(f"WHALE tris={sum(len(p.vertices) - 2 for p in mesh.polygons)} verts={len(mesh.vertices)} bones={len(arm.bones)}")
	print(f"WHALE_CLIP dive seconds={CLIP_LENGTH} beats={BEATS}")
	print("WHALE_EXPORTED", OUT)


def render(rig, body, out):
	"""Side and astern stills of the clip's key times over a sheet of water."""
	out.mkdir(parents=True, exist_ok=True)
	scene = bpy.context.scene
	water = bpy.data.meshes.new("Water")
	water.from_pydata([(-90, -90, 0), (90, -90, 0), (90, 90, 0), (-90, 90, 0)], [], [(0, 1, 2, 3)])
	sheet = bpy.data.objects.new("Water", water)
	wm = bpy.data.materials.new("Water")
	wm.diffuse_color = (0.1, 0.3, 0.45, 0.55)
	water.materials.append(wm)
	scene.collection.objects.link(sheet)
	cam_data = bpy.data.cameras.new("Cam")
	cam_data.type = "ORTHO"
	cam_data.ortho_scale = 90.0
	cam_data.clip_end = 1000.0
	cam = bpy.data.objects.new("Cam", cam_data)
	scene.collection.objects.link(cam)
	scene.camera = cam
	scene.render.engine = "BLENDER_WORKBENCH"
	scene.display.shading.light = "STUDIO"
	scene.display.shading.color_type = "TEXTURE"
	scene.display.shading.show_xray = False
	scene.render.resolution_x = 1100
	scene.render.resolution_y = 620
	scene.render.film_transparent = False
	views = {
		"side": (Vector((300.0, -15.0, 6.0)), (math.radians(88.5), 0.0, math.radians(90.0))),
		"astern": (Vector((0.0, -300.0, 30.0)), (math.radians(84.0), 0.0, 0.0)),
	}
	for t in (0.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.0, 12.0, 13.5):
		scene.frame_set(round(t * FPS))
		for name, (at, turn) in views.items():
			cam.location = at
			cam.rotation_euler = turn
			cam_data.ortho_scale = 90.0 if name == "side" else 60.0
			scene.render.filepath = str((out / f"whale_{name}_{t:04.1f}.png").resolve())
			bpy.ops.render.render(write_still=True)
	bpy.data.objects.remove(sheet)
	bpy.data.objects.remove(cam)


main()
