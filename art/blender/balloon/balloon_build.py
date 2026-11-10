"""Build the hot air balloon: a gored canvas envelope, load ropes, a burner
frame and a wicker basket with ballast bags and a trailing line.

    python tools/blender.py run art/blender/balloon/balloon_build.py
    python tools/godot.py --headless --editor --import

Writes assets/models/balloon/balloon.glb with four objects, all sized for the
endless world (the plane's span is 2.8 m, its pilot 1.2 m tall):

- Envelope: the cloth, its origin at the middle of the widest ring. UV.x
  counts gores (0..GORES, a whole number on each load tape), UV.y runs 0 at
  the crown to 1 at the mouth; shaders/balloon_canvas.gdshader paints the
  pattern, patches, seams and stains from them, so one mesh wears every
  variant.
- Gondola: ropes, burner frame, burner, basket, bags and line, its origin at
  the mouth's middle (it swings from there). Vertex colour is the part's
  tint; UV in metres on the wicker (UV.x >= 0), UV.x -1 elsewhere; alpha is
  how much of the burner's light the part catches.
- Flame: the burner's flame, a crossed cone, origin as the gondola's.
- Far: the far version, a plain 16-sided envelope and a box basket (two
  surfaces, the same materials).

The glb carries material names only (canvas, gear, flame);
scripts/endless/endless_balloons.gd sets the shaders. Keep the numbers below
on EndlessBalloons' (R, MOUTH_Y, FLOOR_Y).
"""
import json
import math
import struct
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/models/balloon/balloon.glb"

# --- The numbers (m; z up here, the envelope's widest ring at z 0) -------------

R = 6.5               # the envelope's widest radius
TOP = 6.1             # the crown over the widest ring
MOUTH_Z = -9.2        # the mouth's ring
MOUTH_R = 1.3
GORES = 16
GORE_CUTS = 6         # quads across a gore
RINGS = 30            # crown to mouth
BULGE = 0.05          # how far a gore swells between its tapes, of its radius
SHOULDER = math.radians(104.0)   # the ellipse runs from the crown to here

FRAME_Z = -10.85      # the burner frame's square
FRAME_HALF = 0.5
RIM_Z = -11.85        # the basket's rim
FLOOR_Z = -12.7       # its floor
BASKET_HALF = (0.78, 0.6)        # x, y at the rim
BASKET_TAPER = 0.9    # the floor's size over the rim's
ROPE_R = 0.022
POLE_R = 0.03
LINE_DROP = 5.5       # the trailing line under the floor

# Tints (linear, the gear shader multiplies its own grain in).
WICKER = (0.36, 0.24, 0.13)
WICKER_DARK = (0.22, 0.145, 0.085)
LEATHER = (0.17, 0.10, 0.065)
ROPE = (0.45, 0.37, 0.25)
IRON = (0.085, 0.085, 0.09)
BRASS = (0.42, 0.31, 0.14)
SACK = (0.33, 0.28, 0.2)
WOOD = (0.25, 0.17, 0.10)

FAR_SIDES = 16
FAR_RINGS = 10


# --- The envelope's profile -----------------------------------------------------

def _profile_points(n=400):
	"""(r, z) from the crown to the mouth: an ellipse to the shoulder, then a
	Hermite curve down to the mouth."""
	pts = []
	a0 = (R * math.sin(SHOULDER), TOP * math.cos(SHOULDER))
	t0 = (R * math.cos(SHOULDER), -TOP * math.sin(SHOULDER))
	l0 = math.hypot(*t0)
	a1 = (MOUTH_R, MOUTH_Z)
	reach = math.hypot(a1[0] - a0[0], a1[1] - a0[1])
	t0 = (t0[0] / l0 * reach * 1.15, t0[1] / l0 * reach * 1.15)
	t1 = (-0.42 * reach * 0.8, -0.91 * reach * 0.8)
	top_n = n // 2
	for i in range(top_n):
		a = SHOULDER * i / top_n
		pts.append((R * math.sin(a), TOP * math.cos(a)))
	for i in range(n - top_n + 1):
		s = i / (n - top_n)
		h00 = 2 * s ** 3 - 3 * s ** 2 + 1
		h10 = s ** 3 - 2 * s ** 2 + s
		h01 = -2 * s ** 3 + 3 * s ** 2
		h11 = s ** 3 - s ** 2
		pts.append((h00 * a0[0] + h10 * t0[0] + h01 * a1[0] + h11 * t1[0],
			h00 * a0[1] + h10 * t0[1] + h01 * a1[1] + h11 * t1[1]))
	return pts


PROFILE = _profile_points()
_ARC = [0.0]
for _i in range(1, len(PROFILE)):
	_ARC.append(_ARC[-1] + math.hypot(PROFILE[_i][0] - PROFILE[_i - 1][0], PROFILE[_i][1] - PROFILE[_i - 1][1]))


def profile(t):
	"""(r, z) at `t` of the arc from the crown (0) to the mouth (1)."""
	want = t * _ARC[-1]
	lo, hi = 0, len(_ARC) - 1
	while hi - lo > 1:
		mid = (lo + hi) // 2
		if _ARC[mid] <= want:
			lo = mid
		else:
			hi = mid
	f = (want - _ARC[lo]) / max(_ARC[hi] - _ARC[lo], 1e-9)
	return (PROFILE[lo][0] + (PROFILE[hi][0] - PROFILE[lo][0]) * f, PROFILE[lo][1] + (PROFILE[hi][1] - PROFILE[lo][1]) * f)


# --- A mesh under way -----------------------------------------------------------

class Geo:
	def __init__(self):
		self.verts = []
		self.faces = []
		self.uvs = []       # one per face corner
		self.cols = []      # one per face corner (r, g, b, a)
		self.mats = []      # one per face
		self.smooth = []

	def quad(self, pts, uvs=None, col=(1, 1, 1, 0), mat=0, smooth=False):
		base = len(self.verts)
		self.verts.extend(pts)
		self.faces.append(tuple(range(base, base + len(pts))))
		self.uvs.extend(uvs if uvs else [(-1.0, -1.0)] * len(pts))
		self.cols.extend([col] * len(pts))
		self.mats.append(mat)
		self.smooth.append(smooth)

	def tube(self, a, b, r, sides=5, col=(1, 1, 1, 0), r2=None, cap=False):
		"""A prism from `a` to `b`."""
		r2 = r if r2 is None else r2
		ax = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
		l = math.sqrt(sum(c * c for c in ax))
		if l < 1e-6:
			return
		ax = tuple(c / l for c in ax)
		ref = (0.0, 0.0, 1.0) if abs(ax[2]) < 0.9 else (1.0, 0.0, 0.0)
		u = _norm(_cross(ax, ref))
		v = _cross(ax, u)
		ring_a, ring_b = [], []
		for i in range(sides):
			an = math.tau * i / sides
			c, s = math.cos(an), math.sin(an)
			ring_a.append(tuple(a[k] + (u[k] * c + v[k] * s) * r for k in range(3)))
			ring_b.append(tuple(b[k] + (u[k] * c + v[k] * s) * r2 for k in range(3)))
		for i in range(sides):
			j = (i + 1) % sides
			self.quad([ring_a[i], ring_a[j], ring_b[j], ring_b[i]], col=col, smooth=True)
		if cap:
			self.quad(list(reversed(ring_a)), col=col)
			self.quad(ring_b, col=col)

	def box(self, lo, hi, col=(1, 1, 1, 0)):
		x0, y0, z0 = lo
		x1, y1, z1 = hi
		p = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
		for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
			self.quad([p[i] for i in f], col=col)

	def emit(self, name, mats, origin=(0.0, 0.0, 0.0), weld=True):
		mesh = bpy.data.meshes.new(name)
		verts = [(v[0] - origin[0], v[1] - origin[1], v[2] - origin[2]) for v in self.verts]
		mesh.from_pydata(verts, [], self.faces)
		mesh.update()
		layer = mesh.uv_layers.new(name="UV")
		# The exporter flips v (glTF's runs down): written flipped here, so the
		# shaders read the v given above.
		for i, uv in enumerate(self.uvs):
			layer.data[i].uv = (uv[0], 1.0 - uv[1])
		ca = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
		for i, c in enumerate(self.cols):
			ca.data[i].color = c
		mesh.color_attributes.active_color = ca
		mesh.polygons.foreach_set("use_smooth", self.smooth)
		mesh.polygons.foreach_set("material_index", self.mats)
		for m in mats:
			mesh.materials.append(m)
		mesh.update()
		ob = bpy.data.objects.new(name, mesh)
		ob.location = origin
		bpy.context.collection.objects.link(ob)
		if weld:
			bpy.context.view_layer.objects.active = ob
			ob.select_set(True)
			bpy.ops.object.mode_set(mode="EDIT")
			bpy.ops.mesh.select_all(action="SELECT")
			bpy.ops.mesh.remove_doubles(threshold=0.0005)
			bpy.ops.object.mode_set(mode="OBJECT")
			ob.select_set(False)
		return ob


def _cross(a, b):
	return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _norm(a):
	l = math.sqrt(sum(c * c for c in a))
	return tuple(c / l for c in a)


def material(name):
	m = bpy.data.materials.get(name)
	return m if m else bpy.data.materials.new(name)


# --- The envelope ---------------------------------------------------------------

def envelope_point(t, u, bulge):
	"""The cloth at arc `t` and gore coordinate `u` (0..GORES)."""
	r, z = profile(t)
	f = u - math.floor(u)
	swell = 1.0 + bulge * (math.sin(math.pi * f) - 0.55) * math.sin(math.pi * min(max(t, 0.0), 1.0)) ** 0.6
	a = math.tau * u / GORES
	return (r * swell * math.cos(a), r * swell * math.sin(a), z)


def build_envelope(name, around, rings, bulge, mats, mat=0, geo=None):
	own = geo is None
	geo = geo or Geo()
	t0 = 0.012     # the crown ring: a small flat cap closes it
	for j in range(rings):
		ta = t0 + (1.0 - t0) * j / rings
		tb = t0 + (1.0 - t0) * (j + 1) / rings
		for i in range(around):
			ua = GORES * i / around
			ub = GORES * (i + 1) / around
			geo.quad([envelope_point(ta, ua, bulge), envelope_point(tb, ua, bulge), envelope_point(tb, ub, bulge), envelope_point(ta, ub, bulge)],
				uvs=[(ua, ta), (ua, tb), (ub, tb), (ub, ta)], mat=mat, smooth=True)
	cap = [envelope_point(t0, GORES * i / around, bulge) for i in range(around)]
	mid = (0.0, 0.0, profile(0.0)[1])
	for i in range(around):
		j = (i + 1) % around
		geo.quad([mid, cap[i], cap[j]], uvs=[(GORES * (i + 0.5) / around, 0.0), (GORES * i / around, t0), (GORES * (i + 1) / around, t0)], mat=mat, smooth=True)
	return geo.emit(name, mats) if own else None


# --- The gondola ----------------------------------------------------------------

def basket_ring(z, grow=1.0, sides=24):
	"""The basket's outline at height `z`: a rounded rectangle, wider at the rim."""
	f = (z - FLOOR_Z) / (RIM_Z - FLOOR_Z)
	k = (BASKET_TAPER + (1.0 - BASKET_TAPER) * f) * grow
	hx, hy = BASKET_HALF[0] * k, BASKET_HALF[1] * k
	pts = []
	for i in range(sides):
		a = math.tau * (i + 0.5) / sides
		c, s = math.cos(a), math.sin(a)
		# A superellipse: square with soft corners.
		e = 0.38
		pts.append((hx * math.copysign(abs(c) ** e, c), hy * math.copysign(abs(s) ** e, s), z))
	return pts


def build_gondola(mats):
	geo = Geo()
	sides = 24
	# The wicker wall, inside and out, UV in metres round and up.
	levels = [FLOOR_Z + (RIM_Z - FLOOR_Z) * i / 4 for i in range(5)]
	for inner in (False, True):
		grow = 0.93 if inner else 1.0
		tint = WICKER_DARK if inner else WICKER
		for k in range(4):
			lo = basket_ring(levels[k], grow, sides)
			hi = basket_ring(levels[k + 1], grow, sides)
			run = 0.0
			for i in range(sides):
				j = (i + 1) % sides
				step = math.dist(hi[i], hi[j])
				quad = [lo[i], lo[j], hi[j], hi[i]]
				uv = [(run, levels[k] - FLOOR_Z), (run + step, levels[k] - FLOOR_Z), (run + step, levels[k + 1] - FLOOR_Z), (run, levels[k + 1] - FLOOR_Z)]
				if inner:
					quad.reverse()
					uv.reverse()
				geo.quad(quad, uvs=uv, col=(*tint, 0.5 if inner else 0.15), smooth=True)
				run += step
	# The floor (wood) and its two skids.
	floor = basket_ring(FLOOR_Z + 0.03, 0.94, sides)
	geo.quad(floor, col=(*WOOD, 0.4))
	geo.quad(list(reversed(basket_ring(FLOOR_Z, 1.0, sides))), col=(*WOOD, 0.0))
	for y in (-0.36, 0.36):
		geo.box((-BASKET_HALF[0] * 0.95, y - 0.045, FLOOR_Z - 0.07), (BASKET_HALF[0] * 0.95, y + 0.045, FLOOR_Z), col=(*WOOD, 0.0))
	# The rim: a leather roll round the top.
	rim_mid = basket_ring(RIM_Z, 0.965, sides)
	roll = 0.062
	rsides = 6
	for i in range(sides):
		j = (i + 1) % sides
		oi = _norm((rim_mid[i][0], rim_mid[i][1], 0.0))
		oj = _norm((rim_mid[j][0], rim_mid[j][1], 0.0))
		for k in range(rsides):
			a0 = math.tau * k / rsides
			a1 = math.tau * (k + 1) / rsides

			def at(p, o, a):
				return (p[0] + o[0] * math.cos(a) * roll, p[1] + o[1] * math.cos(a) * roll, p[2] + math.sin(a) * roll)
			geo.quad([at(rim_mid[i], oi, a0), at(rim_mid[j], oj, a0), at(rim_mid[j], oj, a1), at(rim_mid[i], oi, a1)], col=(*LEATHER, 0.6), smooth=True)
	# Leather-bound corners and a scuffed kick band along the floor's edge.
	band_lo = basket_ring(FLOOR_Z, 1.012, sides)
	band_hi = basket_ring(FLOOR_Z + 0.11, 1.012, sides)
	for i in range(sides):
		j = (i + 1) % sides
		geo.quad([band_lo[i], band_lo[j], band_hi[j], band_hi[i]], col=(*LEATHER, 0.0), smooth=True)

	# The frame: four poles from the rim's corners up to a square of tube, the
	# burner's two cans on a cross bar, a coil round each.
	corners = []
	for sx in (-1, 1):
		for sy in (-1, 1):
			foot = (sx * BASKET_HALF[0] * 0.86, sy * BASKET_HALF[1] * 0.84, RIM_Z - 0.3)
			head = (sx * FRAME_HALF, sy * FRAME_HALF * 0.8, FRAME_Z)
			corners.append(head)
			geo.tube(foot, head, POLE_R, 6, col=(*WOOD, 0.7))
			# Leather sleeve where the pole meets the rim.
			sleeve = tuple(foot[k] + (head[k] - foot[k]) * 0.28 for k in range(3))
			geo.tube(foot, sleeve, POLE_R * 1.7, 6, col=(*LEATHER, 0.5))
	order = [0, 1, 3, 2]
	for i in range(4):
		geo.tube(corners[order[i]], corners[order[(i + 1) % 4]], POLE_R * 0.9, 6, col=(*IRON, 1.0))
	geo.tube((-FRAME_HALF, 0.0, FRAME_Z), (FRAME_HALF, 0.0, FRAME_Z), POLE_R * 0.9, 6, col=(*IRON, 1.0))
	for sx in (-1, 1):
		x = sx * 0.17
		geo.tube((x, 0.0, FRAME_Z - 0.1), (x, 0.0, FRAME_Z + 0.26), 0.085, 10, col=(*BRASS, 1.0), r2=0.1, cap=True)
		geo.tube((x, 0.0, FRAME_Z + 0.26), (x, 0.0, FRAME_Z + 0.34), 0.1, 10, col=(*IRON, 1.0), r2=0.12)
		coil = []
		for k in range(25):
			a = math.tau * k / 8.0
			coil.append((x + math.cos(a) * 0.115, math.sin(a) * 0.115, FRAME_Z - 0.06 + 0.3 * k / 24.0))
		for k in range(24):
			geo.tube(coil[k], coil[k + 1], 0.012, 4, col=(*IRON, 1.0))
		# The fuel hose down to a tank in the basket.
		geo.tube((x, 0.0, FRAME_Z - 0.1), (sx * 0.42, 0.28, RIM_Z - 0.25), 0.014, 4, col=(*IRON, 0.6))
	for sx in (-1, 1):
		geo.tube((sx * 0.42, 0.3, FLOOR_Z + 0.04), (sx * 0.42, 0.3, RIM_Z - 0.2), 0.13, 10, col=(*IRON, 0.5), cap=True)

	# The load ropes: from every other tape at the mouth down to the frame's
	# corners, then on down the poles to the basket's foot (drawn to the rim).
	for g in range(0, GORES, 2):
		a = math.tau * g / GORES
		top = (MOUTH_R * math.cos(a) * 0.985, MOUTH_R * math.sin(a) * 0.985, MOUTH_Z + 0.06)
		best = min(corners, key=lambda c: math.dist((c[0], c[1]), (top[0], top[1])))
		geo.tube(top, best, ROPE_R, 4, col=(*ROPE, 0.9))
	# The tapes between: short stays to the frame's mid sides, slack and thinner.
	for g in range(1, GORES, 4):
		a = math.tau * g / GORES
		top = (MOUTH_R * math.cos(a) * 0.985, MOUTH_R * math.sin(a) * 0.985, MOUTH_Z + 0.06)
		mid = (math.copysign(FRAME_HALF, top[0]) if abs(top[0]) > abs(top[1]) else 0.0, 0.0 if abs(top[0]) > abs(top[1]) else math.copysign(FRAME_HALF * 0.8, top[1]), FRAME_Z)
		geo.tube(top, mid, ROPE_R * 0.7, 4, col=(*ROPE, 0.9))
	# Rope lashing round the basket under the rim, and four hand loops.
	lash = basket_ring(RIM_Z - 0.16, 1.02, sides)
	for i in range(sides):
		geo.tube(lash[i], lash[(i + 1) % sides], ROPE_R * 1.1, 4, col=(*ROPE, 0.2))

	# Ballast: sandbags hung outside from the rim, each a lumpy sack on a cord.
	for sx, sy, drop in ((1, 0.45, 0.42), (-1, -0.4, 0.5), (0.5, -1, 0.38), (-0.45, 1, 0.55), (1, -0.5, 0.6)):
		if abs(sx) == 1:
			x, y = sx * (BASKET_HALF[0] + 0.1), sy * BASKET_HALF[1]
		else:
			x, y = sx * BASKET_HALF[0], sy * (BASKET_HALF[1] + 0.1)
		hang = (x, y, RIM_Z - 0.02)
		neck = (x, y, RIM_Z - drop)
		geo.tube(hang, neck, ROPE_R * 0.8, 4, col=(*ROPE, 0.1))
		rings = [(0.03, 0.0), (0.035, -0.03), (0.07, -0.07), (0.095, -0.13), (0.1, -0.2), (0.075, -0.255), (0.02, -0.27)]
		for k in range(len(rings) - 1):
			a_pt = (x, y, neck[2] + rings[k][1])
			b_pt = (x, y, neck[2] + rings[k + 1][1])
			geo.tube(a_pt, b_pt, rings[k][0], 9, col=(*SACK, 0.1), r2=rings[k + 1][0])

	# The trailing line: off one corner, hanging in a slow curve to a knot.
	start = (BASKET_HALF[0] * 0.8, -BASKET_HALF[1] * 0.8, FLOOR_Z + 0.2)
	prev = start
	n = 10
	for k in range(1, n + 1):
		f = k / n
		p = (start[0] + 0.35 * math.sin(f * 2.2) + 0.25 * f, start[1] - 0.2 * f - 0.12 * math.sin(f * 3.4), start[2] - 0.2 - LINE_DROP * f)
		geo.tube(prev, p, ROPE_R * 0.9, 4, col=(*ROPE, 0.0))
		prev = p
	geo.tube(prev, (prev[0], prev[1], prev[2] - 0.22), 0.06, 5, col=(*ROPE, 0.0), r2=0.03)
	return geo.emit("Gondola", mats, origin=(0.0, 0.0, MOUTH_Z))


def build_flame(mats):
	geo = Geo()
	base = FRAME_Z + 0.3
	tip = MOUTH_Z + 1.5
	sides = 8
	rings = [(0.0, 0.07), (0.12, 0.2), (0.35, 0.3), (0.7, 0.2), (1.0, 0.02)]
	for k in range(len(rings) - 1):
		za = base + (tip - base) * rings[k][0]
		zb = base + (tip - base) * rings[k + 1][0]
		for i in range(sides):
			a0 = math.tau * i / sides
			a1 = math.tau * (i + 1) / sides
			geo.quad([(math.cos(a0) * rings[k][1], math.sin(a0) * rings[k][1], za), (math.cos(a1) * rings[k][1], math.sin(a1) * rings[k][1], za),
				(math.cos(a1) * rings[k + 1][1], math.sin(a1) * rings[k + 1][1], zb), (math.cos(a0) * rings[k + 1][1], math.sin(a0) * rings[k + 1][1], zb)],
				uvs=[(i / sides, rings[k][0]), ((i + 1) / sides, rings[k][0]), ((i + 1) / sides, rings[k + 1][0]), (i / sides, rings[k + 1][0])], smooth=True)
	return geo.emit("Flame", mats, origin=(0.0, 0.0, MOUTH_Z))


def build_far(canvas, gear):
	geo = Geo()
	build_envelope("Far", FAR_SIDES, FAR_RINGS, 0.0, None, mat=0, geo=geo)
	k = BASKET_TAPER
	x0, y0 = BASKET_HALF
	lo = [(-x0 * k, -y0 * k, FLOOR_Z), (x0 * k, -y0 * k, FLOOR_Z), (x0 * k, y0 * k, FLOOR_Z), (-x0 * k, y0 * k, FLOOR_Z)]
	hi = [(-x0, -y0, RIM_Z), (x0, -y0, RIM_Z), (x0, y0, RIM_Z), (-x0, y0, RIM_Z)]
	for i in range(4):
		j = (i + 1) % 4
		geo.quad([lo[i], lo[j], hi[j], hi[i]], col=(*WICKER, 0.0), mat=1)
	geo.quad(list(reversed(lo)), col=(*WOOD, 0.0), mat=1)
	geo.quad(hi, col=(*WICKER_DARK, 0.0), mat=1)
	# The ropes and frame as four thin posts from the basket to the mouth, so
	# the basket doesn't float loose under the cloth.
	for i in range(4):
		a = math.tau * (i + 0.5) / 4
		top = (MOUTH_R * math.cos(a), MOUTH_R * math.sin(a), MOUTH_Z)
		for p, q in ((hi[i], top),):
			d = 0.05
			geo.quad([(p[0] - d, p[1], p[2]), (p[0] + d, p[1], p[2]), (q[0] + d, q[1], q[2]), (q[0] - d, q[1], q[2])], col=(*ROPE, 0.0), mat=1)
			geo.quad([(p[0], p[1] - d, p[2]), (p[0], p[1] + d, p[2]), (q[0], q[1] + d, q[2]), (q[0], q[1] - d, q[2])], col=(*ROPE, 0.0), mat=1)
	return geo.emit("Far", [canvas, gear])


# --- Out --------------------------------------------------------------------------

def export():
	OUT.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=str(OUT), export_format="GLB", use_selection=False, export_apply=False,
		export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
		export_normals=True, export_tangents=False, export_animations=False, export_cameras=False, export_lights=False,
		export_morph=False, export_skins=False)


def prove():
	raw = OUT.read_bytes()
	jlen = struct.unpack_from("<I", raw, 12)[0]
	doc = json.loads(raw[20:20 + jlen].decode("utf8"))
	bad = 0
	names = {n["name"]: n for n in doc["nodes"]}
	for want in ("Envelope", "Gondola", "Flame", "Far"):
		if want not in names:
			print("FAIL no node", want)
			bad = 1
			continue
		mesh = doc["meshes"][names[want]["mesh"]]
		tris = 0
		lo = [1e9] * 3
		hi = [-1e9] * 3
		for prim in mesh["primitives"]:
			tris += doc["accessors"][prim["indices"]]["count"] // 3
			pos = doc["accessors"][prim["attributes"]["POSITION"]]
			lo = [min(lo[i], pos["min"][i]) for i in range(3)]
			hi = [max(hi[i], pos["max"][i]) for i in range(3)]
			if want in ("Gondola", "Far") and "COLOR_0" not in prim["attributes"] and doc["materials"][prim["material"]]["name"] == "gear":
				print("FAIL no vertex colour on", want)
				bad = 1
		at = names[want].get("translation", [0, 0, 0])
		print(f"{want}: {tris} triangles, {len(mesh['primitives'])} surface(s), y {lo[1] + at[1]:.2f}..{hi[1] + at[1]:.2f}, across {hi[0] - lo[0]:.2f} m, origin y {at[1]:.2f}")
	mats = sorted(m["name"] for m in doc["materials"])
	print("materials:", mats)
	if mats != ["canvas", "flame", "gear"]:
		print("FAIL the materials")
		bad = 1
	print(f"balloon: {TOP - FLOOR_Z + 0.07:.2f} m crown to skids, envelope {2 * R:.1f} m across, mouth y {MOUTH_Z}, floor y {FLOOR_Z}")
	return bad


def main():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.scene.new(type="NEW")
	canvas, gear, flame = material("canvas"), material("gear"), material("flame")
	build_envelope("Envelope", GORES * GORE_CUTS, RINGS, BULGE, [canvas])
	build_gondola([gear])
	build_flame([flame])
	build_far(canvas, gear)
	export()
	sys.exit(prove())


main()
