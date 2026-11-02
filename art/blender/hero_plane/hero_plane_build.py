"""Build the hero plane: the wanderer's own biplane, an authored, painted model.

    python3 tools/blender.py run art/blender/hero_plane/hero_plane_build.py [-- --fast]

Writes assets/models/hero_plane/hero_plane.glb and, beside it, its textures,
shaders and materials (hero_plane.glb.import points each material name at its
.tres). --fast halves the textures. Every size is a constant in the first
block; the ones under HOLDS are the old figure's (scripts/plane_figure.gd,
scripts/plane_strip.gd) and don't move: the flight, landing and the world's
openings are sized off them.

Units are toy units. The geometry is written in the game's own axes, x right,
y up, z aft (the nose toward -z), and turned to Blender's on the way out
(Blender (x, -z, y)), so the numbers read straight against plane_figure.gd.

Nodes, each its own mesh with its origin on its hinge or axle: Airframe (body,
wings, tail, struts, the fixed fittings), Cowl (the cowl, the engine in it and
the exhaust stubs; it trembles on its own), Prop (the hub and spinner, turns
about its local z) with Blades under it (they alone hide for the blur disc, so
the spinner stays), AileronL/R and Elevator (hinge along local x), Rudder (hinge
along local y), GearL/R (the sprung legs), WheelL/R (axle along local x), Glass,
Wires. Left is -x. No spin, hinge or spring is keyed here: the game drives them.

One atlas for the whole plane, painted here in numpy: albedo, normal, and two
data maps at half size: `mask` (RGBA: how much of the body, trim, wing and dark
livery colours each texel is) and `orm` (R roughness, G metal, B lacquer). The
albedo holds the plane's own colours; the shader tints by slot/default through
the mask, so the shop's liveries repaint it and keep every stain, and bared
metal and exhaust soot (mask 0) stay what they are. Vertex colours carry baked
darkness: wing roots, the inside of the cowl.
"""
import math
import struct
import sys
import zlib
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
TEX = ROOT / "assets/models/hero_plane"
OUT = TEX / "hero_plane.glb"
RES = "res://assets/models/hero_plane"

# --- HOLDS: the old figure's numbers ------------------------------------------
SPAN = 1.4
LOWER_SPAN = 1.26
CHORD = 0.3
LOWER_Y = -0.1
UPPER_Y = 0.31
STAGGER = -0.06
PROP_Z = -0.68
PROP_R = 0.275
WHEEL_Z = -0.28
WHEEL_X = 0.205
AXLE_Y = -0.33
WHEEL_R = 0.08            # the tyre's bottom on WHEEL_DROP (-0.41)
SKID_TIP = (0.0, -0.13, 0.66)   # plane_strip TAIL: where it rests

# --- The shape ----------------------------------------------------------------
WING_T = 0.024            # thickness: 8% of the chord; the old wing was 10% and fat
WING_CAM = 0.012          # camber
TIP_FROM = 0.84           # of the half span: past it the tip rakes in
RIBS_UP = 9               # ribs a side
RIBS_LO = 8
SAG = 0.07                # the cloth's dip between ribs, of the thickness
SCALLOP = 0.0035          # the trailing edge's bow between ribs
DIHEDRAL = 0.028          # the lower wing's lift, a toy unit out
AIL = (0.30, 0.60)        # the ailerons, x out along the upper wing
AIL_H = 0.76              # their hinge, of the chord
TAIL_Y = 0.052            # the tailplane
TAIL_Z = 0.56             # its leading edge
TAIL_SPAN = 0.26          # half
TAIL_CHORD = 0.135
ELEV_H = 0.62             # the elevator's hinge, of the chord
FIN_HINGE = 0.685         # the rudder's hinge line (z)
CYLINDERS = 7

# Body: (z, half width, top, bottom); the deck rises behind the cockpit.
BODY = (
	(-0.500, 0.118, 0.122, -0.122),
	(-0.420, 0.126, 0.132, -0.136),
	(-0.300, 0.129, 0.138, -0.146),
	(-0.150, 0.128, 0.141, -0.150),
	(-0.020, 0.124, 0.146, -0.148),
	(0.100, 0.116, 0.156, -0.138),
	(0.220, 0.103, 0.170, -0.122),
	(0.330, 0.086, 0.170, -0.100),
	(0.430, 0.068, 0.140, -0.078),
	(0.530, 0.050, 0.104, -0.052),
	(0.620, 0.033, 0.080, -0.026),
	(0.690, 0.016, 0.066, -0.006),
	(0.725, 0.004, 0.058, 0.014),
)
BODY_SIDES = 48           # four to a stringer's bay
BODY_STRINGERS = 12
STRINGER_SAG = 0.042      # how far the cloth falls between them, of the radius
FABRIC_FROM = -0.02       # metal forward of this, doped cloth aft

# Cowl: (z, radius) round the outside, the lip's inside first.
COWL = (
	(-0.545, 0.139), (-0.590, 0.131), (-0.618, 0.127), (-0.632, 0.128), (-0.640, 0.134),
	(-0.641, 0.141), (-0.635, 0.148), (-0.617, 0.155), (-0.590, 0.160), (-0.555, 0.162),
	(-0.520, 0.160), (-0.485, 0.154), (-0.455, 0.146), (-0.438, 0.141),
)
COWL_SIDES = 63           # nine to a cylinder's bay

# --- The atlas ----------------------------------------------------------------
AW, AH = 4096, 2600
D = 1800.0                # px a toy unit, on the flat parts
REG = {
	"up_top": (8, 8, 1290, 560),
	"up_under": (8, 578, 1290, 560),
	"lo_top": (8, 1148, 1290, 560),
	"lo_under": (8, 1718, 1290, 560),
	"body": (1320, 8, 2760, 1620),
	"cowl": (1320, 1640, 1660, 470),
	"fin_r": (3000, 1640, 540, 560),
	"fin_l": (3545, 1640, 540, 560),
	"tail": (1320, 2120, 480, 290),
	"prop": (1810, 2120, 520, 100),
	"wheel": (2340, 2120, 300, 300),
	"tread": (1810, 2230, 520, 90),
}
SWATCH = 190
SW_NAMES = ("dark", "trim", "body", "wing", "brass", "steel", "alu", "burnt", "rubber", "black", "fin_alu", "red", "green", "wire")
SW = {n: (2660 + (i % 7) * SWATCH, 2210 if i < 7 else 2400) for i, n in enumerate(SW_NAMES)}

# The plane's colours, the old figure's (sRGB).
def hexc(s):
	return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


BODY_C = hexc("b9583b")
DARK_C = hexc("2f4a4f")
TRIM_C = hexc("2f6670")
WING_C = hexc("ece2c8")
BRASS_C = hexc("c9a35a")
PROP_C = hexc("70432a")
STEEL_C = hexc("33302d")
ALU_C = np.array((0.62, 0.62, 0.60), dtype=np.float32)
SOOT_C = np.array((0.07, 0.06, 0.055), dtype=np.float32)
OIL_C = np.array((0.16, 0.11, 0.07), dtype=np.float32)
DUST_C = np.array((0.46, 0.39, 0.30), dtype=np.float32)
PRIMER_C = np.array((0.56, 0.55, 0.47), dtype=np.float32)

# --- Geometry -----------------------------------------------------------------

def uv_px(col, row):
	return (col / AW, 1.0 - row / AH)


def sw(name):
	"""UVs inside a swatch, a and b taken 0..1 round and round."""
	x, y = SW[name]
	def f(a, b):
		a = 0.1 + 0.8 * abs(((a * 0.5) % 1.0) * 2.0 - 1.0)
		b = 0.1 + 0.8 * abs(((b * 0.5) % 1.0) * 2.0 - 1.0)
		return uv_px(x + a * SWATCH, y + b * SWATCH)
	return f


class Geo:
	"""A mesh by hand, in toy units. Shared vertices shade smooth, unshared
	ones hard. UVs live on the face corners, so a seam needn't split a normal."""

	def __init__(self):
		self.v = []
		self.c = []
		self.f = []
		self.uv = []

	def vert(self, p, col=1.0):
		p = (float(p[0]), float(p[1]), float(p[2]))
		self.v.append(p)
		self.c.append(float(col(p)) if callable(col) else float(col))
		return len(self.v) - 1

	def face(self, ids, uvs):
		self.f.append(tuple(ids))
		self.uv.append(tuple(uvs))

	def orient(self, start):
		"""The faces since `start` turned outward, by the signed volume of the shell."""
		vol = 0.0
		ctr = Vector((0.0, 0.0, 0.0))
		n = 0
		for f in self.f[start:]:
			for i in f:
				ctr += Vector(self.v[i])
				n += 1
		ctr /= max(n, 1)
		for f in self.f[start:]:
			a = Vector(self.v[f[0]]) - ctr
			for j in range(1, len(f) - 1):
				b = Vector(self.v[f[j]]) - ctr
				c = Vector(self.v[f[j + 1]]) - ctr
				vol += a.dot(b.cross(c))
		if vol < 0.0:
			for k in range(start, len(self.f)):
				self.f[k] = tuple(reversed(self.f[k]))
				self.uv[k] = tuple(reversed(self.uv[k]))


def loft(g, rings, uvf, closed=True, cap0=False, cap1=False, col=1.0, capuv=None):
	"""Rings of points, same count, joined smooth. uvf(i, k) a corner's uv; a
	closed ring's seam takes uvf(i, n) on its far side."""
	start = len(g.f)
	ids = [[g.vert(p, col) for p in r] for r in rings]
	n = len(rings[0])
	last = n if closed else n - 1
	for i in range(len(rings) - 1):
		for k in range(last):
			k1 = (k + 1) % n
			g.face((ids[i][k], ids[i][k1], ids[i + 1][k1], ids[i + 1][k]),
				(uvf(i, k), uvf(i, k + 1), uvf(i + 1, k + 1), uvf(i + 1, k)))
	for flag, i in ((cap0, 0), (cap1, len(rings) - 1)):
		if not flag:
			continue
		c = Vector((0.0, 0.0, 0.0))
		for p in rings[i]:
			c += Vector(p)
		c /= n
		hub = g.vert(c, col)
		f = capuv or (lambda ii, kk: uvf(i, 0))
		for k in range(n):
			g.face((hub, ids[i][k], ids[i][(k + 1) % n]), (f(i, 0), f(i, k), f(i, k + 1)))
	g.orient(start)


def frame(d, up=None):
	d = Vector(d).normalized()
	r = Vector(up or (0.0, 0.0, 1.0))
	if abs(d.dot(r)) > 0.9:
		r = Vector((1.0, 0.0, 0.0)) if abs(d.x) < 0.9 else Vector((0.0, 1.0, 0.0))
	a = (r - d * d.dot(r)).normalized()
	return a, d.cross(a).normalized()


def tube(g, pts, radii, n, swatch, aft=1.0, cap=True, col=1.0, up=None, thin=0.62):
	"""A pipe through pts, n round. `aft` > 1 draws it a teardrop, `aft` long
	against the wind (+z) and thin across it: a streamlined strut."""
	pts = [Vector(p) for p in pts]
	if not isinstance(radii, (list, tuple)):
		radii = [radii] * len(pts)
	rings = []
	f = sw(swatch)
	for i, p in enumerate(pts):
		d = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
		a, b = frame(d, up)
		ring = []
		for k in range(n):
			t = k * math.tau / n
			ca, sa = math.cos(t), math.sin(t)
			if aft > 1.0:
				ring.append(p + a * (ca * radii[i] * (aft if ca > 0.0 else 1.0)) + b * (sa * radii[i] * thin))
			else:
				ring.append(p + a * (ca * radii[i]) + b * (sa * radii[i]))
		rings.append(ring)
	length = (pts[-1] - pts[0]).length
	loft(g, rings, lambda i, k: f(i / max(len(pts) - 1, 1) * length * 4.0, k / n), True, cap, cap, col)


def lathe(g, prof, n, centre, axis, uvf, col=1.0, bump=None, cap0=False, cap1=False):
	"""A solid of revolution round `axis` ("z" or "x"); prof is (along, radius)."""
	c = Vector(centre)
	rings = []
	for s, (al, r) in enumerate(prof):
		ring = []
		for k in range(n):
			t = k * math.tau / n
			rr = r * (bump(al, t) if bump else 1.0)
			if axis == "z":
				ring.append(c + Vector((math.sin(t) * rr, math.cos(t) * rr, al)))
			else:
				ring.append(c + Vector((al, math.cos(t) * rr, math.sin(t) * rr)))
		rings.append(ring)
	loft(g, rings, uvf, True, cap0, cap1, col)


US = (0.0, 0.012, 0.035, 0.08, 0.15, 0.25, 0.37, 0.5, 0.63, 0.76, 0.88, 1.0)


def yt(u):
	return 5.0 * (0.2969 * math.sqrt(u) - 0.126 * u - 0.3516 * u * u + 0.2843 * u ** 3 - 0.1015 * u ** 4)


def camber(u):
	return 4.0 * u * (1.0 - u) * (1.0 - 0.3 * u)


def panel(g, stations, uv_top, uv_under, n=(0.0, 1.0, 0.0), col=1.0, cap_root=False, cap_tip=True, us=US):
	"""A lifting surface from chord stations, each {le, te, t, cam, lo, hi}: the
	foil from lo to hi of the chord. Top from hi round the nose to under hi; a
	surface cut short (lo > 0 or hi < 1) is closed square across the cut, with
	the far edge a hard edge in every case."""
	n = Vector(n)
	lo0 = stations[0].get("lo", 0.0)
	rings = []
	for s in stations:
		le, te = Vector(s["le"]), Vector(s["te"])
		lo, hi = s.get("lo", 0.0), s.get("hi", 1.0)
		ring = []
		top = []
		under = []
		for u0 in us:
			u = lo + (hi - lo) * u0
			p = le + (te - le) * u
			c = s["cam"] * camber(u)
			top.append(p + n * (c + s["t"] * yt(u)))
			under.append(p + n * (c - s["t"] * yt(u)))
		ring = list(reversed(top)) + (under[1:] if lo0 == 0.0 else under)
		rings.append(ring)
	m = len(us)
	count = len(rings[0])
	start = len(g.f)
	ids = [[g.vert(p, col) for p in r] for r in rings]

	def uv(i, k):
		p = rings[i][k]
		return uv_top(p) if k < m else uv_under(p)

	for i in range(len(rings) - 1):
		for k in range(count - 1):
			a, b = (uv_top, uv_top) if k < m - 1 else (uv_under, uv_under)
			g.face((ids[i][k], ids[i][k + 1], ids[i + 1][k + 1], ids[i + 1][k]),
				(a(rings[i][k]), a(rings[i][k + 1]), a(rings[i + 1][k + 1]), a(rings[i + 1][k])))
		# The back of the section: only where it stands open.
		if stations[i].get("hi", 1.0) < 1.0 and stations[i + 1].get("hi", 1.0) < 1.0:
			f = sw("black")
			g.face((ids[i][count - 1], ids[i][0], ids[i + 1][0], ids[i + 1][count - 1]),
				(f(0, 0), f(1, 0), f(1, 1), f(0, 1)))
	for flag, i in ((cap_root, 0), (cap_tip, len(rings) - 1)):
		if flag:
			f = sw("black") if flag == "dark" else uv_top
			hub = Vector((0.0, 0.0, 0.0))
			for p in rings[i]:
				hub += p
			hub /= count
			h = g.vert(hub, col)
			for k in range(count):
				k1 = (k + 1) % count
				if flag == "dark":
					g.face((h, ids[i][k], ids[i][k1]), (f(0, 0), f(0, 1), f(1, 1)))
				else:
					g.face((h, ids[i][k], ids[i][k1]), (uv_top(hub), uv_top(rings[i][k]), uv_top(rings[i][k1])))
	g.orient(start)


def wing_uv(reg, half_chord_z):
	x0, y0, w, h = REG[reg]
	def f(p):
		return uv_px(x0 + 6.0 + abs(p.x) * D, y0 + 10.0 + (p.z - half_chord_z) * D)
	return f


def rib_x(half, ribs, x0):
	"""The stations out a wing: four to a bay inboard, then the tip's curve."""
	edge = half * TIP_FROM
	p = half / ribs
	xs = []
	k = 0
	while k * p / 3.0 < edge - 1e-6:
		xs.append(k * p / 3.0)
		k += 1
	xs += [edge + (half - edge) * q for q in (0.0, 0.2, 0.42, 0.62, 0.78, 0.9, 0.97, 1.0)]
	return [x for x in xs if x >= x0 - 1e-6]


def wing_station(half, ribs, x, le0, y0, side, dihedral=0.0):
	a = abs(x)
	edge = half * TIP_FROM
	p = half / ribs
	bay = (a % p) / p
	between = math.sin(bay * math.pi) if a < edge else 0.0
	c = CHORD - SCALLOP * between
	t = WING_T
	le = le0
	if a > edge:
		q = (a - edge) / (half - edge)
		e = math.sqrt(max(1.0 - q * q, 0.0))
		# The tip rakes: the leading edge comes back and the trailing edge stays
		# long, so it ends swept, not round.
		le = le0 + CHORD * (1.0 - e) * 0.72
		c = max(CHORD * (0.72 * e + 0.28 * e * e) * 1.0, 0.012) if q < 1.0 else 0.012
		c = max(min(c, CHORD - (le - le0) + 0.004), 0.012)
		t = WING_T * max(e, 0.22)
	y = y0 + dihedral * a
	return {
		"le": (x, y, le), "te": (x, y, le + c),
		"t": t * (1.0 - SAG * between), "cam": WING_CAM * (t / WING_T) * (1.0 - SAG * 0.5 * between),
	}


def build_wings(g, ail):
	le_up = STAGGER - CHORD * 0.5
	le_lo = -CHORD * 0.5
	for side in (-1.0, 1.0):
		# Upper: through the centre section, the aileron's cut in its back edge.
		xs = rib_x(SPAN * 0.5, RIBS_UP, 0.0)
		xs += [AIL[0] - 0.0005, AIL[0] + 0.0005, AIL[1] - 0.0005, AIL[1] + 0.0005]
		xs = sorted(set(round(x, 5) for x in xs))
		st = []
		for x in xs:
			s = wing_station(SPAN * 0.5, RIBS_UP, x * side, le_up, UPPER_Y, side)
			if AIL[0] < x < AIL[1]:
				s["hi"] = AIL_H
			st.append(s)
		fade = lambda p: 1.0 - 0.32 * max(0.0, 1.0 - abs(p[0]) / 0.16) ** 2 
		panel(g, st, wing_uv("up_top", le_up), wing_uv("up_under", le_up), col=fade, cap_root=False)
		# Lower: from the body out, a little dihedral.
		xs = [x for x in rib_x(LOWER_SPAN * 0.5, RIBS_LO, 0.08)]
		st = [wing_station(LOWER_SPAN * 0.5, RIBS_LO, x * side, le_lo, LOWER_Y, side, DIHEDRAL) for x in xs]
		shade = lambda p: 1.0 - 0.38 * max(0.0, 1.0 - (abs(p[0]) - 0.08) / 0.14) ** 2
		panel(g, st, wing_uv("lo_top", le_lo), wing_uv("lo_under", le_lo), col=shade, cap_root="dark")
		# The aileron, hinge line to trailing edge, on its own node.
		h = ail[side]
		xs = sorted(set([AIL[0] + 0.003] + [x for x in rib_x(SPAN * 0.5, RIBS_UP, 0.0) if AIL[0] + 0.004 < x < AIL[1] - 0.004] + [AIL[1] - 0.003]))
		st = []
		for x in xs:
			s = wing_station(SPAN * 0.5, RIBS_UP, x * side, le_up, UPPER_Y, side)
			s["lo"] = AIL_H + 0.004
			st.append(s)
		panel(h, st, wing_uv("up_top", le_up), wing_uv("up_under", le_up), cap_root="dark", cap_tip="dark", us=(0.0, 0.3, 0.6, 0.85, 1.0))
		# A horn under it and a little over: the cable's two ends.
		for sgn in (1.0, -1.0):
			hx = (AIL[0] + 0.07) * side
			hz = le_up + CHORD * (AIL_H + 0.05)
			tube(h, [(hx, UPPER_Y, hz), (hx, UPPER_Y + 0.034 * sgn, hz - 0.012)], 0.0028, 5, "steel")


def body_section(z):
	"""The body's half width, top and bottom at z."""
	b = BODY
	if z <= b[0][0]:
		return b[0][1:]
	for p, q in zip(b, b[1:]):
		if z <= q[0]:
			t = (z - p[0]) / (q[0] - p[0])
			# Catmull-free: a soft ease keeps the fair line without overshoot.
			t = t * t * (3.0 - 2.0 * t) * 0.35 + t * 0.65
			return tuple(p[i] + (q[i] - p[i]) * t for i in (1, 2, 3))
	return b[-1][1:]


def body_point(z, th):
	hw, top, bot = body_section(z)
	mid = (top + bot) * 0.5
	ht = (top - bot) * 0.5
	# Toward the tail the section comes in to a deck and a keel, stringers
	# standing the cloth off a pointed oval; forward it is round.
	rear = min(max((z - FABRIC_FROM) / 0.16, 0.0), 1.0)
	s, c = math.sin(th), math.cos(th)
	e = 2.0 + 0.5 * rear
	k = (abs(s) ** e + abs(c) ** e) ** (-1.0 / e)
	sag = 1.0 - STRINGER_SAG * rear * abs(math.sin(th * BODY_STRINGERS * 0.5)) ** 0.75
	return Vector((s * hw * k * sag, mid + c * ht * k * sag, z))


def build_body(g):
	x0, y0, w, h = REG["body"]
	zs = [-0.5, -0.46, -0.42, -0.38, -0.34, -0.3, -0.25, -0.2, -0.15, -0.1, -0.05, -0.02]
	z = 0.02
	while z < 0.725:
		zs.append(z)
		z += 0.042
	zs.append(0.725)
	rings = [[body_point(z, k * math.tau / BODY_SIDES) for k in range(BODY_SIDES)] for z in zs]
	f = 2190.0
	def uv(i, k):
		return uv_px(x0 + 8.0 + (zs[i] + 0.5) * f, y0 + 8.0 + k / BODY_SIDES * (h - 16.0))
	def shade(p):
		# Under the lower wing's root and the upper's shadow, a little dark.
		under = max(0.0, 1.0 - abs(p[1] - LOWER_Y) / 0.05) * max(0.0, 1.0 - abs(p[2]) / 0.2)
		return 1.0 - 0.3 * under
	loft(g, rings, uv, True, False, True, shade)


def build_tail(g, elevator, rudder):
	# Tailplane: a blunt taper, in two halves meeting the body.
	x0, y0, w, h = REG["tail"]
	def uv(p):
		return uv_px(x0 + 6.0 + abs(p.x) * D, y0 + 6.0 + (p.z - TAIL_Z) * D)
	hinge = TAIL_Z + TAIL_CHORD * ELEV_H
	for side in (-1.0, 1.0):
		st = []
		for x in (0.012, 0.05, 0.1, 0.15, 0.19, 0.22, 0.24, 0.252, 0.26):
			q = max(0.0, (x - 0.17) / 0.09)
			e = math.sqrt(max(1.0 - q * q, 0.0))
			le = TAIL_Z + 0.075 * (1.0 - e) + 0.04 * x
			te = TAIL_Z + TAIL_CHORD * (0.28 + 0.72 * max(e, 0.15)) - 0.015 * x
			u_h = (hinge - le) / max(te - le, 0.001)
			hi = max(min(u_h, 1.0), 0.4)
			st.append({"le": (x * side, TAIL_Y, le), "te": (x * side, TAIL_Y, te), "t": 0.0125 * max(e, 0.3), "cam": 0.0, "hi": hi if hi < 1.0 else 0.999})
		panel(g, st, uv, uv, cap_tip=True, cap_root=False)
		st = []
		for x in (0.012, 0.05, 0.1, 0.15, 0.19, 0.22, 0.24):
			q = max(0.0, (x - 0.17) / 0.09)
			e = math.sqrt(max(1.0 - q * q, 0.0))
			le = TAIL_Z + 0.075 * (1.0 - e) + 0.04 * x
			te = TAIL_Z + TAIL_CHORD * (0.28 + 0.72 * max(e, 0.15)) - 0.015 * x
			u_h = (hinge + 0.002 - le) / max(te - le, 0.001)
			st.append({"le": (x * side, TAIL_Y, le), "te": (x * side, TAIL_Y, te), "t": 0.0125 * max(e, 0.3), "cam": 0.0, "lo": max(min(u_h, 0.97), 0.1)})
		panel(elevator, st, uv, uv, cap_root="dark", cap_tip="dark", us=(0.0, 0.3, 0.6, 0.85, 1.0))
		tube(elevator, [(0.03 * side, TAIL_Y - 0.004, hinge + 0.015), (0.03 * side, TAIL_Y - 0.05, hinge - 0.006)], 0.0026, 5, "steel")
		tube(elevator, [(0.03 * side, TAIL_Y + 0.004, hinge + 0.015), (0.03 * side, TAIL_Y + 0.05, hinge - 0.006)], 0.0026, 5, "steel")
		# A strut under the tailplane, and its bracing wires are in Wires.
		tube(g, [(0.018 * side, -0.0, 0.60), (0.11 * side, TAIL_Y - 0.008, 0.615)], 0.0048, 6, "dark", aft=1.8)
	# Fin and rudder: lofted up from the deck. Each side's UV is its own, so
	# the number reads on both.
	def fin_uv(reg):
		xr, yr, wr, hr = REG[reg]
		right = reg == "fin_r"
		def f(p):
			col = (0.77 - p.z) if right else (p.z - 0.47)
			return uv_px(xr + 5.0 + col * D, yr + 8.0 + (0.312 - p.y) * D)
		return f
	def fin_stations():
		out = []
		for y, le in ((0.05, 0.47), (0.075, 0.535), (0.11, 0.572), (0.15, 0.598), (0.19, 0.618), (0.225, 0.634), (0.255, 0.648), (0.278, 0.661), (0.292, 0.671)):
			out.append({"le": (0.0, y, le), "te": (0.0, y, FIN_HINGE - 0.002), "t": 0.0085 * (0.5 + 0.5 * (0.3 - y) / 0.25), "cam": 0.0, "hi": 0.999})
		return out
	# Two half skins, split on the fin's plane, would double it: one panel with
	# its normal across, and each face's corners sent to its side's own region.
	r_uv, l_uv = fin_uv("fin_r"), fin_uv("fin_l")
	panel(g, fin_stations(), r_uv, l_uv, n=(1.0, 0.0, 0.0), cap_tip=True)
	hinge_z = FIN_HINGE
	st = []
	for y, te in ((-0.012, 0.7), (0.012, 0.735), (0.05, 0.752), (0.11, 0.762), (0.17, 0.762), (0.225, 0.75), (0.262, 0.732), (0.286, 0.708), (0.299, 0.682)):
		le = hinge_z + 0.002 if y < 0.286 else hinge_z - 0.012
		st.append({"le": (0.0, y, le), "te": (0.0, y, max(te, le + 0.006)), "t": 0.0072, "cam": 0.0, "lo": 0.0})
	panel(rudder, st, r_uv, l_uv, n=(1.0, 0.0, 0.0), cap_root="dark", cap_tip=True, us=(0.0, 0.08, 0.25, 0.5, 0.75, 1.0))
	tube(rudder, [(0.0, 0.06, hinge_z + 0.01), (0.05, 0.05, hinge_z - 0.012)], 0.0026, 5, "steel")
	tube(rudder, [(0.0, 0.06, hinge_z + 0.01), (-0.05, 0.05, hinge_z - 0.012)], 0.0026, 5, "steel")


def build_cowl(g):
	x0, y0, w, h = REG["cowl"]
	s = [0.0]
	for p, q in zip(COWL, COWL[1:]):
		s.append(s[-1] + math.hypot(q[0] - p[0], q[1] - p[1]))
	total = s[-1]
	bay = math.tau / CYLINDERS
	def bump(al, t):
		# The rocker blisters: a teardrop over each cylinder's head.
		if al > -0.5 or al < -0.636:
			return 1.0
		d = ((t + bay * 0.5) % bay) - bay * 0.5
		along = (al + 0.575) / 0.052
		return 1.0 + 0.052 * math.exp(-(d / 0.15) ** 2) * math.exp(-along * along)
	prof = [(z, r) for z, r in COWL]
	def uv(i, k):
		return uv_px(x0 + 6.0 + k / COWL_SIDES * (w - 12.0), y0 + 6.0 + s[i] / total * (h - 12.0))
	def shade(p):
		return 0.3 if math.hypot(p[0], p[1]) < 0.136 and p[2] > -0.625 else 1.0
	lathe(g, prof, COWL_SIDES, (0.0, 0.0, 0.0), "z", uv, shade, bump)
	# The engine: a back plate, the crankcase, the cylinders with their fins.
	f = sw("black")
	lathe(g, [(-0.542, 0.141), (-0.541, 0.0)], 16, (0.0, 0.0, 0.0), "z", lambda i, k: f(i, k / 16.0), 0.4)
	al = sw("fin_alu")
	lathe(g, [(-0.542, 0.074), (-0.575, 0.08), (-0.597, 0.076), (-0.6, 0.066), (-0.612, 0.062), (-0.615, 0.052), (-0.628, 0.046), (-0.63, 0.03)], 21, (0.0, 0.0, 0.0), "z", lambda i, k: al(i * 0.2, k / 21.0 * 2.0), 0.85, cap1=True)
	fins = sw("fin_alu")
	for c in range(CYLINDERS):
		t = c * bay
		d = Vector((math.sin(t), math.cos(t), 0.0))
		side = Vector((math.cos(t), -math.sin(t), 0.0))
		prof2 = [(0.072, 0.024)]
		for i in range(5):
			prof2 += [(0.077 + i * 0.0078, 0.0325), (0.0805 + i * 0.0078, 0.0325), (0.0815 + i * 0.0078, 0.0245)]
		prof2 += [(0.118, 0.0255), (0.128, 0.022), (0.133, 0.012), (0.134, 0.004)]
		ctr = Vector((0.0, 0.0, -0.578))
		rings = []
		for rho, r in prof2:
			rings.append([ctr + d * rho + (side * math.cos(k * math.tau / 8) + Vector((0, 0, 1)) * math.sin(k * math.tau / 8)) * r for k in range(8)])
		loft(g, rings, lambda i, k: fins(i * 0.31, k / 8.0), True, False, True, lambda p: 0.85)
		# A pushrod down the cylinder's flank.
		tube(g, [(math.sin(t + 0.42) * 0.075, math.cos(t + 0.42) * 0.075, -0.562), (math.sin(t + 0.24) * 0.126, math.cos(t + 0.24) * 0.126, -0.566)], 0.0032, 5, "steel")
	# Exhaust stubs: three a side low on the flanks, curling back out of the
	# cowl's skirt, flared and burnt.
	for side in (-1.0, 1.0):
		for a in (1.85, 2.2, 2.55):
			t = a * side
			d = Vector((math.sin(t), math.cos(t), 0.0))
			at = lambda r, z: tuple(d * r + Vector((0.0, 0.0, z)))
			pts = [at(0.13, -0.5), at(0.147, -0.47), at(0.162, -0.44), at(0.171, -0.405), at(0.175, -0.372), at(0.1755, -0.358)]
			tube(g, pts, [0.0115, 0.0115, 0.0112, 0.0105, 0.0108, 0.0122], 8, "burnt", cap=False)
			# The dark throat.
			tube(g, [at(0.1755, -0.3585), at(0.175, -0.372)], [0.0098, 0.0092], 8, "black", cap=True)


def build_prop():
	"""In the prop's own frame, its hub at the origin, blades along +-y: the
	hub and spinner, and the blades on their own, which hide for the blur."""
	g = Geo()
	blades = Geo()
	x0, y0, w, h = REG["prop"]
	for sgn in (1.0, -1.0):
		rings = []
		st = ((0.04, 0.015, 0.0, 0.014), (0.06, 0.016, 0.1, 0.013), (0.085, 0.024, 0.42, 0.0115), (0.115, 0.03, 0.5, 0.0098), (0.15, 0.031, 0.44, 0.0082),
			(0.19, 0.03, 0.36, 0.0068), (0.225, 0.027, 0.3, 0.0055), (0.25, 0.022, 0.26, 0.0042), (0.265, 0.016, 0.24, 0.003), (0.273, 0.009, 0.23, 0.002), (PROP_R, 0.002, 0.22, 0.0012))
		sect = ((-1.0, 0.0), (-0.75, 0.55), (-0.2, 1.0), (0.45, 0.72), (1.0, 0.0), (0.45, -0.25), (-0.2, -0.32), (-0.75, -0.2))
		for r, cw, tw, th in st:
			ct, sn = math.cos(tw), math.sin(tw)
			ring = []
			for a, b in sect:
				px = a * cw
				pz = b * th
				ring.append((sgn * (px * ct - pz * sn), sgn * r, px * sn * sgn + pz * ct - 0.002))
			rings.append(ring)
		def uv(i, k):
			r = st[i][0]
			a = sect[k % len(sect)][0]
			return uv_px(x0 + 6.0 + r * D, y0 + 50.0 + a * 38.0)
		loft(blades, rings, uv, True, False, True)
	# The hub and the spinner dome, with its bolts.
	b = sw("brass")
	prof = [(-0.088, 0.0004), (-0.084, 0.008), (-0.072, 0.019), (-0.054, 0.031), (-0.034, 0.041), (-0.014, 0.047), (0.004, 0.049), (0.006, 0.054), (0.03, 0.054), (0.046, 0.05), (0.05, 0.04)]
	lathe(g, prof, 22, (0.0, 0.0, 0.0), "z", lambda i, k: b(i * 0.2, k / 22.0), 1.0, cap1=False)
	for k in range(6):
		t = k * math.tau / 6
		tube(g, [(math.sin(t) * 0.04, math.cos(t) * 0.04, 0.0), (math.sin(t) * 0.04, math.cos(t) * 0.04, 0.009)], 0.0038, 6, "steel")
	return g, blades


def wheel_geo(side):
	"""Round its own axle at the origin, along x."""
	g = Geo()
	x0, y0, w, h = REG["wheel"]
	tx, ty, tw, th = REG["tread"]
	def disc(p):
		return uv_px(x0 + w * 0.5 + p.z * D, y0 + h * 0.5 - p.y * D)
	# Sidewall to sidewall, a soft tyre; the disc dished, the hub standing proud.
	tyre = [(-0.03, 0.054), (-0.034, 0.064), (-0.03, 0.073), (-0.02, 0.0785), (-0.008, 0.08), (0.008, 0.08), (0.02, 0.0785), (0.03, 0.073), (0.034, 0.064), (0.03, 0.054)]
	n = 26
	rings = []
	for al, r in tyre:
		rings.append([(al, math.cos(k * math.tau / n) * r, math.sin(k * math.tau / n) * r) for k in range(n)])
	def tuv(i, k):
		return uv_px(tx + 6.0 + k / n * (tw - 12.0), ty + 6.0 + i / (len(tyre) - 1) * (th - 12.0))
	loft(g, rings, tuv, True)
	for sgn in (-1.0, 1.0):
		prof = [(0.03 * sgn, 0.056), (0.026 * sgn, 0.05), (0.018 * sgn, 0.03), (0.024 * sgn, 0.02), (0.03 * sgn, 0.0185), (0.034 * sgn, 0.014), (0.0345 * sgn, 0.0005)]
		rings = [[(al, math.cos(k * math.tau / n) * r, math.sin(k * math.tau / n) * r) for k in range(n)] for al, r in prof]
		def duv(i, k):
			return disc(Vector((0.0, rings[i][k % n][1], rings[i][k % n][2])))
		loft(g, rings, duv, True)
	return g


def gear_geo(side):
	"""One leg's V and its telescopic strut, placed as on the plane."""
	g = Geo()
	axle = (WHEEL_X * side - 0.03 * side, AXLE_Y, WHEEL_Z)
	stub = (WHEEL_X * side + 0.012 * side, AXLE_Y, WHEEL_Z)
	tube(g, [axle, stub], 0.0085, 8, "steel")
	# The V, faired: front and rear legs to the belly.
	tube(g, [(0.05 * side, -0.14, -0.40), axle], 0.0105, 8, "dark", aft=1.6)
	tube(g, [(0.05 * side, -0.145, -0.17), axle], 0.0105, 8, "dark", aft=1.6)
	# The spring leg: from the lower wing's root down, a boot, a polished rod
	# and a fairing collar.
	top = (0.135 * side, -0.092, -0.285)
	dn = Vector(axle) - Vector(top)
	knee = Vector(top) + dn * 0.56
	rod = Vector(top) + dn * 0.74
	tube(g, [top, knee], [0.0125, 0.0135], 10, "dark")
	tube(g, [knee, knee + dn * 0.02, knee + dn * 0.04], [0.0165, 0.0165, 0.0135], 10, "brass")
	tube(g, [knee + dn * 0.04, rod], 0.0085, 8, "alu")
	tube(g, [rod, Vector(axle)], 0.012, 8, "dark")
	# The spreader tube to the middle (a half each side, meeting).
	tube(g, [axle, (0.0, AXLE_Y + 0.004, WHEEL_Z)], 0.0072, 6, "dark")
	return g


def wire(g, a, b, r=0.0017):
	tube(g, [a, b], r, 3, "wire", cap=False)


def build_struts(g, w):
	le_up = STAGGER - CHORD * 0.5
	out = SPAN * 0.325
	lo_y = LOWER_Y + DIHEDRAL * out * 0.93
	for side in (-1.0, 1.0):
		x_low = out * 0.93 * side
		x_up = out * side
		for ch in (0.2, 0.68):
			lo = (x_low, lo_y + 0.008, -CHORD * 0.5 + CHORD * ch)
			up = (x_up, UPPER_Y - 0.002, le_up + CHORD * ch)
			# Thick enough across the wind to stay whole from straight behind at chase.
			tube(g, [lo, up], 0.0095, 8, "dark", aft=2.0, thin=0.95)
			# The fittings: a small plate at each end.
			for e in (lo, up):
				tube(g, [(e[0], e[1] - 0.003, e[2] - 0.016), (e[0], e[1] - 0.003, e[2] + 0.022)], 0.0058, 5, "steel")
		# Cabane: an N from the wing's centre to the body's shoulders.
		for ch, zb in ((0.12, -0.36), (0.62, -0.17)):
			base = (0.1 * side, 0.094, zb)
			top = (0.105 * side, UPPER_Y - 0.004, le_up + CHORD * ch)
			tube(g, [base, top], 0.0072, 8, "dark", aft=1.8, thin=0.95)
		# Flying and landing wires, a doubled pair in the bay, and the incidence X.
		for ch, dz in ((0.2, -0.006), (0.2, 0.006), (0.68, -0.006), (0.68, 0.006)):
			wing_z_up = le_up + CHORD * ch + dz
			wing_z_lo = -CHORD * 0.5 + CHORD * ch + dz
			wire(w, (0.1 * side, -0.088, wing_z_lo), (x_up, UPPER_Y - 0.008, wing_z_up))
			wire(w, (x_low, lo_y + 0.012, wing_z_lo), (0.115 * side, UPPER_Y - 0.006, wing_z_up))
		a = (x_low, lo_y + 0.014, -CHORD * 0.5 + CHORD * 0.2)
		b = (x_up, UPPER_Y - 0.006, le_up + CHORD * 0.68)
		c = (x_low, lo_y + 0.014, -CHORD * 0.5 + CHORD * 0.68)
		d = (x_up, UPPER_Y - 0.006, le_up + CHORD * 0.2)
		wire(w, a, b)
		wire(w, c, d)
		# The gear's cross bracing, tail wires and the cables.
		wire(w, (0.05 * side, -0.142, -0.4), (WHEEL_X * side * 0.2, AXLE_Y + 0.006, WHEEL_Z), 0.0014)
		wire(w, (0.05 * side, -0.145, -0.17), (WHEEL_X * side * 0.2, AXLE_Y + 0.006, WHEEL_Z), 0.0014)
		wire(w, (0.004 * side, 0.215, 0.645), (0.13 * side, TAIL_Y + 0.008, 0.625), 0.0014)
		wire(w, (0.004 * side, 0.02, 0.63), (0.13 * side, TAIL_Y - 0.006, 0.625), 0.0014)
		# Cables out of the body to the rudder and elevator horns.
		wire(w, (0.04 * side, 0.055, 0.5), (0.05 * side, 0.05, FIN_HINGE - 0.012), 0.0013)
		wire(w, (0.024 * side, 0.098, 0.5), (0.03 * side, TAIL_Y + 0.05, TAIL_Z + TAIL_CHORD * ELEV_H - 0.006), 0.0013)
		wire(w, (0.024 * side, 0.0, 0.5), (0.03 * side, TAIL_Y - 0.05, TAIL_Z + TAIL_CHORD * ELEV_H - 0.006), 0.0013)
		# And up to the aileron's horn from the strut's foot.
		hx = (AIL[0] + 0.07) * side
		hz = le_up + CHORD * (AIL_H + 0.05)
		wire(w, (x_up, UPPER_Y - 0.03, le_up + CHORD * 0.68 + 0.012), (hx, UPPER_Y - 0.034, hz - 0.012), 0.0013)


def build_canopy(g, glass):
	"""A framed hood: a glazed shell (its own node), the frames on the airframe."""
	sta = ((-0.035, 0.08, 0.152), (-0.0, 0.082, 0.178), (0.07, 0.084, 0.222), (0.12, 0.084, 0.232), (0.2, 0.082, 0.236), (0.28, 0.072, 0.226), (0.34, 0.05, 0.198), (0.365, 0.02, 0.178))
	def base(z):
		return body_section(z)[1] - 0.042
	n = 16
	def point(i, k):
		z, hw, top = sta[i]
		phi = -math.pi * 0.5 + math.pi * k / n
		s, c = math.sin(phi), math.cos(phi)
		e = 2.7
		r = (abs(s) ** e + abs(c) ** e) ** (-1.0 / e)
		b = base(z)
		return Vector((s * r * hw, b + c * r * (top - b), z))
	rings = [[point(i, k) for k in range(n + 1)] for i in range(len(sta))]
	f = sw("black")
	loft(glass, rings, lambda i, k: f(i, k), False, False, False)
	# Frames: three hoops, the screen's bow, sills and a spine, proud of the glass.
	for i, r in ((0, 0.0055), (2, 0.0052), (4, 0.0042), (5, 0.0042)):
		tube(g, [tuple(p + Vector((0, 0.0012, 0))) for p in rings[i]], r, 6, "body")
	for k in (0, n):
		tube(g, [tuple(rings[i][k]) for i in range(len(sta))], 0.0055, 6, "body")
	for k in (n // 2 - 3, n // 2 + 3):
		tube(g, [tuple(rings[i][k] + Vector((0, 0.001, 0))) for i in range(0, 3)], 0.0038, 6, "body")
	tube(g, [tuple(rings[i][n // 2] + Vector((0, 0.001, 0))) for i in range(2, len(sta) - 1)], 0.0036, 6, "body")
	# A dark well under the glass, so nothing's seen through it but dark.
	tub = [[(math.sin(-math.pi * 0.5 + math.pi * k / 8) * sta[i][1] * 0.92, base(sta[i][0]) + 0.004 + math.cos(-math.pi * 0.5 + math.pi * k / 8) * 0.02, sta[i][0]) for k in range(9)] for i in range(len(sta) - 1)]
	loft(g, tub, lambda i, k: f(i, k), False, False, False, 0.5)


def build_fittings(g):
	# The tail skid: a sprung shoe to the contact point, a brass tip.
	tube(g, [(0.0, 0.0, 0.565), (0.0, -0.05, 0.60), (0.0, -0.1, 0.645), (SKID_TIP[0], SKID_TIP[1] + 0.012, SKID_TIP[2])], [0.0085, 0.0075, 0.0066, 0.0062], 7, "dark", up=(1.0, 0.0, 0.0))
	tube(g, [(0.0, -0.105, 0.642), (0.0, SKID_TIP[1] + 0.004, SKID_TIP[2]), (0.0, SKID_TIP[1] + 0.001, SKID_TIP[2] + 0.018)], [0.0078, 0.0062, 0.0035], 7, "brass", up=(1.0, 0.0, 0.0))
	tube(g, [(0.0, 0.005, 0.62), (0.0, -0.075, 0.625)], 0.0042, 6, "dark", up=(1.0, 0.0, 0.0))
	# The fuel filler ahead of the screen: a brass cap on a raised neck.
	b = sw("brass")
	top = body_section(-0.16)[1]
	for x, z, r in ((0.0, -0.16, 0.024),):
		rings = []
		for yy, rr in ((top - 0.004, r * 1.2), (top + 0.003, r * 1.15), (top + 0.0035, r), (top + 0.008, r * 0.95), (top + 0.0085, r * 0.55)):
			rings.append([(x + math.cos(k * math.tau / 12) * rr, yy, z + math.sin(k * math.tau / 12) * rr) for k in range(12)])
		loft(g, rings, lambda i, k: b(i * 0.2, k / 12.0), True, False, True)
		tube(g, [(x - 0.015, top + 0.01, z), (x + 0.015, top + 0.01, z)], 0.0028, 5, "brass")
	# A step let into the left flank, a grab bar over it.
	y = -0.03
	tube(g, [(-0.128, y, 0.015), (-0.142, y - 0.002, 0.018), (-0.142, y - 0.002, 0.058), (-0.124, y, 0.062)], 0.0034, 5, "brass")
	# A pitot on the right forward strut, a thin arm into the wind.
	le_up = STAGGER - CHORD * 0.5
	px = SPAN * 0.325
	tube(g, [(px, 0.2, le_up + CHORD * 0.2), (px, 0.2, le_up - 0.04)], [0.0028, 0.0028], 5, "brass")
	tube(g, [(px, 0.2, le_up - 0.04), (px, 0.2, le_up - 0.075)], [0.0042, 0.0036], 6, "brass")
	# Oil cooler scoop under the nose: a low flattened lip.
	s = sw("trim")
	rings = []
	zs = (-0.44, -0.40, -0.34, -0.27, -0.21)
	wd = (0.03, 0.05, 0.056, 0.05, 0.01)
	dp = (0.004, 0.02, 0.028, 0.02, 0.002)
	for z, ww, dd in zip(zs, wd, dp):
		yb = body_section(z)[2] + 0.006
		rings.append([(math.cos(k * math.tau / 10) * ww, yb - dd + math.sin(k * math.tau / 10) * dd, z) for k in range(10)])
	loft(g, rings, lambda i, k: s(i * 0.25, k / 10.0), True, True, True)
	# Nav lamps at the upper tips.
	for side, name in ((-1.0, "red"), (1.0, "green")):
		x = SPAN * 0.5 - 0.022
		z = STAGGER + 0.045
		tube(g, [(x * side, UPPER_Y + 0.003, z - 0.012), (x * side, UPPER_Y + 0.003, z + 0.012)], [0.0015, 0.004], 6, name)


# --- To Blender ---------------------------------------------------------------

STATS = {}


def emit(name, g, mat, origin=(0.0, 0.0, 0.0), rot=None):
	ox, oy, oz = origin
	verts = [(v[0] - ox, -(v[2] - oz), v[1] - oy) for v in g.v]
	me = bpy.data.meshes.new(name)
	me.from_pydata(verts, [], g.f)
	me.materials.append(mat)
	me.polygons.foreach_set("use_smooth", [True] * len(g.f))
	layer = me.uv_layers.new(name="UVMap")
	uvs = [c for f in g.uv for uv in f for c in uv]
	layer.uv.foreach_set("vector", np.array(uvs, dtype=np.float32))
	ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
	c = np.ones((len(g.v), 4), dtype=np.float32)
	c[:, 0] = c[:, 1] = c[:, 2] = np.array(g.c, dtype=np.float32)
	ca.data.foreach_set("color", c.ravel())
	me.color_attributes.active_color = ca
	me.update()
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	ob.location = (ox, -oz, oy)
	me.calc_loop_triangles()
	STATS[name] = len(me.loop_triangles)
	return ob


def build():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.context.scene.view_settings.view_transform = "Standard"
	bpy.context.scene.view_settings.look = "None"
	mats = {n: bpy.data.materials.new(n) for n in ("hero", "glass", "wire")}
	frame_g, glass, wires = Geo(), Geo(), Geo()
	ail = {-1.0: Geo(), 1.0: Geo()}
	elevator, rudder = Geo(), Geo()
	cowl = Geo()
	build_body(frame_g)
	build_wings(frame_g, ail)
	build_tail(frame_g, elevator, rudder)
	build_struts(frame_g, wires)
	build_canopy(frame_g, glass)
	build_fittings(frame_g)
	build_cowl(cowl)
	le_up = STAGGER - CHORD * 0.5
	ail_z = le_up + CHORD * AIL_H
	emit("Airframe", frame_g, mats["hero"])
	emit("Cowl", cowl, mats["hero"], (0.0, 0.0, -0.5))
	hub, blades = build_prop()
	prop = emit("Prop", hub, mats["hero"])
	prop.location = (0.0, -PROP_Z, 0.0)
	emit("Blades", blades, mats["hero"]).parent = prop
	emit("AileronL", ail[-1.0], mats["hero"], (-(AIL[0] + AIL[1]) * 0.5, UPPER_Y, ail_z))
	emit("AileronR", ail[1.0], mats["hero"], ((AIL[0] + AIL[1]) * 0.5, UPPER_Y, ail_z))
	emit("Elevator", elevator, mats["hero"], (0.0, TAIL_Y, TAIL_Z + TAIL_CHORD * ELEV_H))
	emit("Rudder", rudder, mats["hero"], (0.0, 0.05, FIN_HINGE))
	emit("GearL", gear_geo(-1.0), mats["hero"])
	emit("GearR", gear_geo(1.0), mats["hero"])
	for side, name in ((-1.0, "WheelL"), (1.0, "WheelR")):
		ob = emit(name, wheel_geo(side), mats["hero"])
		ob.location = (WHEEL_X * side, -WHEEL_Z, AXLE_Y)
	emit("Glass", glass, mats["glass"])
	emit("Wires", wires, mats["wire"])


def export():
	TEX.mkdir(parents=True, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=str(OUT), export_format="GLB", use_selection=False, export_apply=False,
		export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
		export_normals=True, export_tangents=False, export_animations=False, export_cameras=False, export_lights=False,
		export_image_format="AUTO", export_morph=False, export_skins=False)


# --- Paint --------------------------------------------------------------------

import hero_plane_paint as paint  # noqa: E402  (art/blender/hero_plane/, it needs nothing from Blender but save_tex)


def save_tex(name, rgb, data=False):
	"""A JPEG through Blender, no colour management: the file holds these numbers."""
	h, w = rgb.shape[:2]
	img = bpy.data.images.new(name, w, h, alpha=False)
	if data:
		img.colorspace_settings.name = "Non-Color"
	px = np.dstack((rgb, np.ones((h, w), dtype=np.float32)))[::-1].astype(np.float32)
	img.pixels.foreach_set(px.ravel())
	img.update()
	settings = bpy.context.scene.render.image_settings
	settings.file_format = "JPEG"
	settings.color_mode = "RGB"
	settings.quality = 90
	img.file_format = "JPEG"
	img.save_render(str(TEX / (name + ".jpg")))
	bpy.data.images.remove(img)


def save_png(name, rgba):
	"""RGBA bytes as they are: Blender's writers would touch hidden colours."""
	h, w = rgba.shape[:2]
	b = (np.clip(rgba, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
	raw = np.zeros((h, w * 4 + 1), dtype=np.uint8)
	raw[:, 1:] = b.reshape(h, -1)
	def chunk(tag, data):
		return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
	out = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw.tobytes(), 6)) + chunk(b"IEND", b"")
	(TEX / (name + ".png")).write_bytes(out)


SHADER = """shader_type spatial;
// Written by art/blender/hero_plane/hero_plane_build.py. Lit as the world is: no
// ambient, the sky's hemisphere added as emission (shaders/folk_surface.
// gdshaderinc). The albedo is the plane's own paint; the livery tints by
// slot/default through the mask (R body, G trim, B wing, A dark), so stains and
// wear stay and bared metal doesn't take the paint. COLOR is baked darkness.
render_mode diffuse_lambert, specular_schlick_ggx;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform vec3 zs_key_direction;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 paint_body : source_color = vec3(0.725, 0.345, 0.231);
uniform vec3 paint_trim : source_color = vec3(0.184, 0.4, 0.439);
uniform vec3 paint_wing : source_color = vec3(0.925, 0.886, 0.784);
uniform vec3 paint_dark : source_color = vec3(0.184, 0.29, 0.31);
const vec3 BASE_BODY = vec3(0.485, 0.0976, 0.0437);
const vec3 BASE_TRIM = vec3(0.0284, 0.133, 0.162);
const vec3 BASE_WING = vec3(0.838, 0.76, 0.578);
const vec3 BASE_DARK = vec3(0.0284, 0.0685, 0.0781);
uniform float normal_depth = 1.0;
uniform float fill = 2.2;
uniform float rim = 0.3;
uniform float bounce = 4.0;
// The side turned from the sun. The world's fill is about a twentieth of the
// sun in the red and blue besides, so a saturated paint in it goes to black: a
// near-neutral light scaled off the sky's own, so moods and night reach it,
// strongest away from the sun and a little of it on the lit side, so cast
// shadows lift too without washing the lit paint out.
uniform float shade_lift = 3.0;
uniform float shade_lit = 0.3;
uniform float shade_neutral = 0.7;
uniform float coat_roughness = 0.08;
// set_wear: 0 new; faded, dusty and dull at 1, as the old paint did.
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform vec3 wear_dust : source_color = vec3(0.71, 0.65, 0.55);
uniform float flex = 0.0;
void vertex() {
	float span_out = max(abs(VERTEX.x) - 0.16, 0.0);
	VERTEX.y += flex * span_out * span_out * 0.35;
}
void fragment() {
	vec4 m = texture(mask_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	vec3 base = texture(albedo_tex, UV).rgb;
	vec3 tint = vec3(1.0);
	tint = mix(tint, paint_body / BASE_BODY, m.r);
	tint = mix(tint, paint_trim / BASE_TRIM, m.g);
	tint = mix(tint, paint_wing / BASE_WING, m.b);
	tint = mix(tint, paint_dark / BASE_DARK, m.a);
	base *= tint;
	vec3 up = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float dull = 0.0;
	if (wear > 0.0) {
		float painted = clamp(m.r + m.g + m.b + m.a, 0.0, 1.0);
		base = mix(base, vec3(dot(base, vec3(0.3, 0.55, 0.15))), 0.28 * wear * painted);
		float dust = smoothstep(0.15, 0.85, up.y) * wear;
		base = mix(base, wear_dust, dust * 0.34);
		dull = wear * 0.7;
	}
	base *= COLOR.r;
	ALBEDO = base;
	ROUGHNESS = clamp(mix(orm.r, 1.0, dull * 0.6), 0.0, 1.0);
	// The sky isn't in the reflections, so a true metal would go black: a
	// third of one keeps its colour and its sheen.
	METALLIC = orm.g * 0.35;
	CLEARCOAT = orm.b * (1.0 - dull * 0.8);
	CLEARCOAT_ROUGHNESS = coat_roughness;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	// What looks down takes the sunlit land's bounce: a thin wing with nothing but
	// the world's dark ground term under it reads black, where a round body didn't.
	vec3 hemi = mix(zs_hemi_ground * bounce, zs_hemi_sky, up.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 diffuse = base * (1.0 - orm.g * 0.3);
	float sunward = clamp(dot(up, zs_key_direction), 0.0, 1.0);
	vec3 lift = mix(zs_hemi_sky, vec3(dot(zs_hemi_sky, vec3(0.2126, 0.7152, 0.0722))), shade_neutral) * zs_hemi_energy * shade_lift * mix(1.0, shade_lit, sunward);
	EMISSION = diffuse * (hemi * fill + lift) + mix(diffuse, vec3(0.5), 0.4) * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
"""

WIRE = """shader_type spatial;
// Written by art/blender/hero_plane/hero_plane_build.py. The wires, far under a
// pixel wide at chase, where they broke into dashes: each is held to `min_px`
// on screen, pushed out along its normal, and fades by what it really covers,
// so a far wire is a faint whole line. Lit as hero_surface.gdshader.
render_mode diffuse_lambert, specular_schlick_ggx, blend_mix, depth_draw_never, shadows_disabled;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform vec3 zs_key_direction;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float wire_r = 0.0016;
uniform float min_px = 1.5;
uniform float darkest = 1.3;
uniform float fill = 2.2;
uniform float shade_lift = 3.0;
uniform float shade_lit = 0.3;
varying float cover;
void vertex() {
	float depth = max(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z, 0.01);
	float toy_px = 2.0 * depth / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y) / length(MODEL_MATRIX[0].xyz);
	// A three-sided tube of radius r stands about 1.6 r wide.
	float want = min_px * toy_px / 1.6;
	VERTEX += NORMAL * max(want - wire_r, 0.0);
	cover = clamp(wire_r / want * darkest, 0.0, 1.0);
}
void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb * COLOR.r;
	ALBEDO = base;
	ROUGHNESS = 0.45;
	METALLIC = 0.0;
	ALPHA = cover;
	vec3 up = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, up.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float sunward = clamp(dot(up, zs_key_direction), 0.0, 1.0);
	EMISSION = base * (hemi * fill + zs_hemi_sky * zs_hemi_energy * shade_lift * mix(1.0, shade_lit, sunward));
}
"""

GLASS = """shader_type spatial;
// The canopy's panes: a deep tinted glass that gives back the sky at a slant.
// Written by art/blender/hero_plane/hero_plane_build.py.
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx, depth_draw_always;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform vec3 tint : source_color = vec3(0.13, 0.21, 0.27);
uniform float depth = 0.78;
void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 r = reflect(-(INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz, n);
	vec3 sky = mix(zs_hemi_ground, zs_hemi_sky, r.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	ALBEDO = tint;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	ALPHA = mix(depth, 0.97, edge);
	EMISSION = sky * (0.25 + 1.4 * edge) + tint * sky * 0.8;
}
"""


def write_materials():
	(TEX / "hero_surface.gdshader").write_text(SHADER)
	(TEX / "hero_glass.gdshader").write_text(GLASS)
	(TEX / "hero_wire.gdshader").write_text(WIRE)
	tex = (("albedo_tex", "hero_albedo.jpg", 2), ("normal_tex", "hero_normal.jpg", 3), ("mask_tex", "hero_mask.png", 4), ("orm_tex", "hero_orm.png", 5))
	for name, shader, maps in (("hero", "hero_surface", tex), ("wire", "hero_wire", tex[:1])):
		ext = [f'[ext_resource type="Shader" path="{RES}/{shader}.gdshader" id="1"]']
		lines = ['shader = ExtResource("1")']
		for key, file, i in maps:
			ext.append(f'[ext_resource type="Texture2D" path="{RES}/{file}" id="{i}"]')
			lines.append(f'shader_parameter/{key} = ExtResource("{i}")')
		(TEX / f"{name}.tres").write_text('[gd_resource type="ShaderMaterial" format=3]\n\n' + "\n".join(ext) + "\n\n[resource]\n" + "\n".join(lines) + "\n")
	(TEX / "glass.tres").write_text(f'[gd_resource type="ShaderMaterial" format=3]\n\n[ext_resource type="Shader" path="{RES}/hero_glass.gdshader" id="1"]\n\n[resource]\nshader = ExtResource("1")\n')
	# The imports: only the params; Godot fills in the rest on its first import.
	subs = ",\n".join(f'"{n}": {{\n"use_external/enabled": true,\n"use_external/fallback_path": "{RES}/{n}.tres",\n"use_external/path": "{RES}/{n}.tres"\n}}' for n in ("hero", "glass", "wire"))
	glb = TEX / "hero_plane.glb.import"
	if not glb.exists():
		glb.write_text('[remap]\n\nimporter="scene"\n\n[params]\n\nmeshes/ensure_tangents=true\nmeshes/generate_lods=false\nmeshes/create_shadow_meshes=true\n_subresources={\n"materials": {\n' + subs + '\n}\n}\n')
	for file, normal in (("hero_albedo.jpg", 0), ("hero_normal.jpg", 1), ("hero_mask.png", 0), ("hero_orm.png", 0)):
		p = TEX / (file + ".import")
		if not p.exists():
			mode = 0 if file.endswith(".png") else 2
			p.write_text(f'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode={mode}\ncompress/normal_map={normal}\nmipmaps/generate=true\nprocess/fix_alpha_border=false\ndetect_3d/compress_to=0\n')


def main():
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	fast = "--fast" in argv
	build()
	TEX.mkdir(parents=True, exist_ok=True)
	if "--no-paint" not in argv:
		maps = paint.paint_all(globals(), 2 if fast else 1)
		save_tex("hero_albedo", maps["albedo"])
		save_tex("hero_normal", maps["normal"], True)
		save_png("hero_mask", maps["mask"])
		save_png("hero_orm", maps["orm"])
	write_materials()
	export()
	total = sum(STATS.values())
	for k, v in STATS.items():
		print(f"  {k:10s} {v:6d} tris")
	print(f"HERO PLANE {total} tris, {len(STATS)} nodes -> {OUT}")


main()
