#!/usr/bin/env python3
"""Lays out the flight study's nature pack (scripts/flight_pack_nature.gd):
greybox landforms (canyon walls, sea stacks, natural arches, a ridge, a
waterfall cove, a sea cave) stood round a line designed first.

Each station's line is drawn by its direction, not by points: the heading
(degrees, + to the right) and the climb (the flight path's angle, rad, +
up) are given as knots along the line's length and eased between them
(half a cosine; the heading blended TURN_LIN toward straight, so an S
flips its turn at the knot), plus a gentle `bob` whose pitch swings
hardest where the turn flips, then integrated from the entry, which is at
0, 0, 0 heading north (-z), level, as the plane is set down. So the line
keeps swinging (round 3's flow) and the climbs stay long and gentle (the
user: tight vertical jinks feel abrupt). The rock is then placed in the
line's own frame: a wall at so many metres to its left or right, a stack
beside a bend, an arch across it, so the room round the line is set by
design. Tokens sit at the moments (through a gap, under an arch, round a
stack) and evenly between them.

Part kinds (FlightPackNature `part_solids` expands them to the course's
boxes and drums; this file expands them the same way to check the room):
  ["wall", [Vector3(x, top, z), ...], thick, side]   a strip of rock along
      the points, from the floor up to each top; its face on the points,
      the rock `side` of them (+1 right of the way they run, -1 left, 0
      centred)
  ["stack", Vector2(x, z), base radius, top radius, top, hole]   a tapered
      stack of drums from the floor; `hole` {} or {"y", "w", "h", "yaw"}: a
      tunnel w x h through it from y, running along yaw
  ["arch", Vector3 the opening's bottom middle, width, height, depth, yaw,
      crown, sill, (leg)]   a natural arch: legs (`leg` m wide, LEG if left
      out) from the floor to `crown`, an
      arched soffit over a width x height opening, `depth` along yaw; with
      `sill` rock under the opening too (a hole through a rib), without it
      open below (a bridge)
  ["box", middle, size, yaw]   as the course's

  python3 tools/flight_nature_layout.py --check            # every station's numbers
  python3 tools/flight_nature_layout.py --check --station canyon
  python3 tools/flight_nature_layout.py --png /tmp/n       # top views, /tmp/n_<id>.png
  python3 tools/flight_nature_layout.py --station ridge --png /tmp/n --zoom 50,120 --px 0.25
  python3 tools/flight_nature_layout.py --write            # rewrite the pack's stations
"""
import argparse
import math
import struct
import zlib

CRUISE = 14.0
TURN_RATE = 1.6
PITCH_SPEED = 1.4
ALT = 40.0
FLOOR = -ALT
SPAN = 1.4
REACH = 1.7
DS = 0.25
TOKEN = 9.0
# Part expansion (the same numbers as FlightPackNature).
TIER = 7.0
OVERLAP = 0.6
LEG = 3.0
ARCH_SLICES = 8
ARCH_SPRING = 0.4
# Flow (FlightMetrics FLOW_*).
STILL = math.radians(6.0)
# The heading eases between its knots this far toward straight
# interpolation, so an S flips its turn at the knot instead of lingering
# near none (a near-straight the flow metric counts as still).
TURN_LIN = 0.5


def ease(knots, s, lin=0.0):
	"""The knots' value at s, eased between them by half a cosine, blended
	`lin` of the way to straight interpolation (so the rate doesn't fall
	to 0 at a knot)."""
	if s <= knots[0][0]:
		return knots[0][1]
	for (s0, v0), (s1, v1) in zip(knots, knots[1:]):
		if s <= s1:
			u = (s - s0) / (s1 - s0)
			return v0 + (v1 - v0) * ((1.0 - lin) * (0.5 - 0.5 * math.cos(math.pi * u)) + lin * u)
	return knots[-1][1]


class Line:
	"""The line, integrated from its turn and climb knots every DS m."""

	def __init__(self, length, headings, climbs, bob=0.0):
		self.length = length
		self.headings = headings
		# The bob: a gentle up-and-down whose pitch swings hardest where the
		# turn eases through its knots (half way between bob knots), so the
		# flown direction keeps moving there (round 3's hand-over).
		if bob:
			marks = [(a[0] + b[0]) * 0.5 for a, b in zip(headings, headings[1:])]
			wave = [(m, bob * (1 if j % 2 == 0 else -1)) for j, m in enumerate(marks)]
			wave = [(0.0, 0.0)] + wave
			self.climbs = lambda s: ease(climbs, s) + ease(wave, s)
		else:
			self.climbs = lambda s: ease(climbs, s)
		self.p, self.psi, self.gam, self.k = [], [], [], []
		x = y = z = 0.0
		n = int(round(length / DS))

		def head(s):
			return math.radians(ease(headings, s, TURN_LIN))

		for i in range(n + 1):
			s = i * DS
			psi = head(s)
			g = self.climbs(s)
			self.p.append((x, y, z))
			self.psi.append(psi)
			self.gam.append(g)
			self.k.append((head(s + DS * 0.5) - head(s - DS * 0.5)) / DS)
			pm = head(s + DS * 0.5)
			gm = self.climbs(s + DS * 0.5)
			x += math.sin(pm) * math.cos(gm) * DS
			y += math.sin(gm) * DS
			z += -math.cos(pm) * math.cos(gm) * DS

	def i(self, s):
		return max(0, min(len(self.p) - 1, int(round(s / DS))))

	def P(self, s):
		return self.p[self.i(s)]

	def heading(self, s):
		return self.psi[self.i(s)]

	def yaw(self, s):
		"""The Godot yaw (Basis(UP, yaw)) whose -z runs along the line."""
		return -self.psi[self.i(s)]

	def right(self, s):
		a = self.psi[self.i(s)]
		return (math.cos(a), 0.0, math.sin(a))

	def fwd(self, s):
		a = self.psi[self.i(s)]
		g = self.gam[self.i(s)]
		return (math.sin(a) * math.cos(g), math.sin(g), -math.cos(a) * math.cos(g))

	def off(self, s, across=0.0, up=0.0):
		p = self.P(s)
		r = self.right(s)
		return (p[0] + r[0] * across, p[1] + up, p[2] + r[2] * across)

	def samples(self):
		return [(i * DS, self.p[i]) for i in range(len(self.p))]


# --- Parts ------------------------------------------------------------------------------


def wall(line, s0, s1, side, offset, top, thick=6.0, step=4.0):
	"""Rock along the line from s0 to s1, its face `offset(s)` m to the
	line's right (side +1) or left (side -1), up to `top(s)` (local y)."""
	pts = []
	n = max(1, int(math.ceil((s1 - s0) / step)))
	for j in range(n + 1):
		s = s0 + (s1 - s0) * j / n
		p = line.off(s, side * offset(s))
		pts.append((p[0], top(s), p[2]))
	return ["wall", pts, thick, float(side)]


def across_arch(line, s, width, soffit, depth, crown, sill=False, drop=8.0, shift=0.0, leg=None):
	"""A natural arch square across the line at s, its soffit `soffit` m
	over the line; the opening's bottom `drop` m under it."""
	p = line.off(s, shift)
	y = p[1] - drop
	out = ["arch", (p[0], y, p[2]), width, soffit + drop, depth, line.yaw(s), crown, sill]
	if leg is not None:
		out.append(leg)
	return out


def stack_at(line, s, across, radius, top, base=None, hole=None):
	"""A stack whose surface (at the line's height) stands `across` m from
	the line at s (+ right), so its middle is `across` + radius out."""
	base = base if base is not None else radius * 1.35
	p = line.P(s)
	r = line.right(s)
	# The radius at the line's height.
	u = (p[1] - FLOOR) / (top - FLOOR)
	at = base + (radius - base) * u
	d = across + math.copysign(at, across)
	x, z = p[0] + r[0] * d, p[2] + r[2] * d
	return ["stack", (x, z), base, radius, top, hole or {}]


def expand(part):
	"""The part as the course's solids: ("box", middle, size, yaw) or
	("cyl", middle, radius, height). Must match FlightPackNature."""
	kind = part[0]
	out = []
	if kind == "box":
		out.append(("box", part[1], part[2], part[3]))
	elif kind == "wall":
		pts, thick, side = part[1], part[2], part[3]
		for i, (a, b) in enumerate(zip(pts, pts[1:])):
			dx, dz = b[0] - a[0], b[2] - a[2]
			length = math.hypot(dx, dz)
			if length < 0.01:
				continue
			nx, nz = dx / length, dz / length
			rx, rz = -nz, nx
			top = (a[1] + b[1]) * 0.5
			mx = (a[0] + b[0]) * 0.5 + rx * side * thick * 0.5
			mz = (a[2] + b[2]) * 0.5 + rz * side * thick * 0.5
			out.append(("box", (mx, (FLOOR + top) * 0.5, mz), (thick, top - FLOOR, length + OVERLAP), math.atan2(-nx, -nz)))
			if i > 0:
				ox = a[0] + rx * side * thick * 0.5
				oz = a[2] + rz * side * thick * 0.5
				out.append(("cyl", (ox, (FLOOR + a[1]) * 0.5, oz), thick * 0.5, a[1] - FLOOR))
	elif kind == "stack":
		(x, z), base, radius, top, hole = part[1], part[2], part[3], part[4], part[5]

		def r_at(y):
			return base + (radius - base) * (y - FLOOR) / (top - FLOOR)

		bands = [(FLOOR, top, False)]
		if hole:
			hy, hh = hole["y"], hole["h"]
			bands = [(FLOOR, hy, False), (hy, hy + hh, True), (hy + hh, top, False)]
		for y0, y1, is_hole in bands:
			if y1 - y0 < 0.01:
				continue
			if is_hole:
				mid = (y0 + y1) * 0.5
				big = r_at(mid)
				half = hole["w"] * 0.5
				yaw = hole["yaw"]
				for side in (-1.0, 1.0):
					lx = side * (half + (big - half) * 0.5)
					out.append(("box", (x + math.cos(yaw) * lx, mid, z - math.sin(yaw) * lx), (big - half, y1 - y0, 2.0 * big), yaw))
				continue
			n = max(1, int(math.ceil((y1 - y0) / TIER)))
			for j in range(n):
				ya = y0 + (y1 - y0) * j / n
				yb = y0 + (y1 - y0) * (j + 1) / n
				out.append(("cyl", (x, (ya + yb) * 0.5, z), r_at((ya + yb) * 0.5), yb - ya))
	elif kind == "arch":
		(x, y, z), w, h, depth, yaw, crown, sill = part[1:8]
		leg = part[8] if len(part) > 8 else LEG
		c, s = math.cos(yaw), math.sin(yaw)

		def at(lx, my):
			return (x + c * lx, my, z - s * lx)

		for side in (-1.0, 1.0):
			out.append(("box", at(side * (w * 0.5 + leg * 0.5), (FLOOR + crown) * 0.5), (leg, crown - FLOOR, depth), yaw))
		spring = ARCH_SPRING * h
		for j in range(ARCH_SLICES):
			xc = -w * 0.5 + (j + 0.5) * w / ARCH_SLICES
			u = xc / (w * 0.5)
			ys = y + spring + (h - spring) * math.sqrt(max(0.0, 1.0 - u * u))
			out.append(("box", at(xc, (ys + crown) * 0.5), (w / ARCH_SLICES + 0.02, crown - ys, depth), yaw))
		if sill:
			out.append(("box", at(0.0, (FLOOR + y) * 0.5), (w, y - FLOOR, depth), yaw))
	return out


def distance(solid, p):
	if solid[0] == "box":
		_, m, size, yaw = solid
		qx, qy, qz = p[0] - m[0], p[1] - m[1], p[2] - m[2]
		c, s = math.cos(yaw), math.sin(yaw)
		lx = qx * c - qz * s
		lz = qx * s + qz * c
		d = (abs(lx) - size[0] * 0.5, abs(qy) - size[1] * 0.5, abs(lz) - size[2] * 0.5)
		out = math.sqrt(sum(max(v, 0.0) ** 2 for v in d))
		return out + min(max(d), 0.0)
	_, m, radius, height = solid
	dx = math.hypot(p[0] - m[0], p[2] - m[2]) - radius
	dy = abs(p[1] - m[1]) - height * 0.5
	return math.hypot(max(dx, 0.0), max(dy, 0.0)) + min(max(dx, dy), 0.0)


def bound(solid):
	"""A circle round the solid's footprint: middle x, z and radius; its y
	span."""
	if solid[0] == "box":
		_, m, size, _ = solid
		return m[0], m[2], 0.5 * math.hypot(size[0], size[2]), m[1] - size[1] * 0.5, m[1] + size[1] * 0.5
	_, m, radius, height = solid
	return m[0], m[2], radius, m[1] - height * 0.5, m[1] + height * 0.5


class Field:
	"""The solids, with a coarse grid for nearby lookups."""

	CELL = 8.0

	def __init__(self, solids):
		self.solids = solids
		self.grid = {}
		for k, sol in enumerate(solids):
			x, z, r, _, _ = bound(sol)
			for gx in range(int(math.floor((x - r) / self.CELL)), int(math.floor((x + r) / self.CELL)) + 1):
				for gz in range(int(math.floor((z - r) / self.CELL)), int(math.floor((z + r) / self.CELL)) + 1):
					self.grid.setdefault((gx, gz), []).append(k)

	def clearance(self, p, reach=16.0):
		best = p[1] - FLOOR
		seen = set()
		g0x, g0z = int(math.floor((p[0] - reach) / self.CELL)), int(math.floor((p[2] - reach) / self.CELL))
		g1x, g1z = int(math.floor((p[0] + reach) / self.CELL)), int(math.floor((p[2] + reach) / self.CELL))
		for gx in range(g0x, g1x + 1):
			for gz in range(g0z, g1z + 1):
				for k in self.grid.get((gx, gz), ()):
					if k in seen:
						continue
					seen.add(k)
					best = min(best, distance(self.solids[k], p))
		return min(best, reach)

	def hit(self, p):
		return self.clearance(p, 2.0) < 0.0


# --- The stations -----------------------------------------------------------------------


def tokens_on(line, first=10.0, every=TOKEN, last=None, skip=(), at=()):
	"""Where the tokens sit along the line (s): one at each of `at` (the
	moments: through a gap, under an arch, round a stack), and between them
	evenly, about `every` m apart, from `first` to `last`."""
	last = line.length - 2.0 if last is None else last
	marks = sorted(set([first] + [s for s in at if first <= s <= last] + [last]))
	out = []
	for a, b in zip(marks, marks[1:]):
		n = max(1, int(round((b - a) / every)))
		for j in range(n):
			s = a + (b - a) * j / n
			if not any(lo <= s <= hi for lo, hi in skip):
				out.append(s)
	out.append(last)
	return out


def station_canyon():
	"""A winding river canyon, carved round the line: S-bends hugging the
	inside wall, under a natural arch, up and out over a low saddle where
	the walls fall away, back down into the next reach, through a narrow
	slot and out under a natural bridge, climbing."""
	L = 330.0
	headings = [
		(0, 0), (26, 32), (58, -28), (92, 30), (122, -6), (150, -34),
		(180, 20), (210, -24), (240, 26), (268, -24), (296, 22), (320, -10), (345, 16),
	]
	climbs = [
		(0, 0.0), (24, -0.11), (80, -0.11), (112, 0.0),
		(164, 0.19), (190, 0.0), (206, -0.17), (236, -0.04),
		(262, 0.0), (288, 0.06), (312, 0.18), (330, 0.18),
	]
	line = Line(L, headings, climbs, bob=0.13)
	parts = []
	# The canyon's half width at the line: 6 m, the inside of each bend
	# closer (down to 4.2 m), the outside further (up to 7.8).
	K = 0.05

	def lean(s):
		return max(-1.0, min(1.0, line.k[line.i(s)] / K))

	def inside(side):
		return lambda s: 6.0 - 1.8 * side * lean(s)

	def rim(rise):
		return lambda s: line.P(s)[1] + rise(s)

	# The rim over the line: high in the first reach, falling away over the
	# saddle (s 150-205), up again as the line drops back in, low by the
	# last bridge.
	def rise(s):
		return ease([(0, 9.0), (140, 9.0), (166, 1.0), (180, -4.0), (200, -4.0), (214, 2.0), (236, 9.0), (290, 9.0), (320, 4.0)], s)

	for a, b in ((-12, 150), (196, 312)):
		for side in (-1, 1):
			parts.append(wall(line, a, b, side, inside(side), rim(rise), thick=6.0, step=5.0))
	# The saddle under the line, between the reaches.
	for side in (-1, 1):
		parts.append(wall(line, 150, 196, side, lambda s: 9.0, rim(rise), thick=5.0, step=6.0))
	parts.append(wall(line, 156, 192, 0, lambda s: 0.0, lambda s: line.P(s)[1] - 5.5, thick=14.0, step=6.0))
	# Benches set back over the walls, so the canyon reads stepped.
	for a, b in ((-12, 140), (236, 300)):
		for side in (-1, 1):
			parts.append(wall(line, a, b, side, lambda s, side=side: inside(side)(s) + 6.0, rim(lambda s: rise(s) + 6.0), thick=6.0, step=8.0))
	# The natural arch over the first reach and the bridge at the end.
	parts.append(across_arch(line, 118.0, 13.0, 4.6, 5.0, line.P(118)[1] + 9.0))
	parts.append(across_arch(line, 318.0, 12.0, 5.0, 5.0, line.P(318)[1] + 8.5))
	# Hoodoos on the saddle to skim past.
	parts.append(stack_at(line, 172.0, 5.0, 1.6, line.P(172)[1] + 3.0))
	parts.append(stack_at(line, 186.0, -5.0, 1.6, line.P(186)[1] + 2.0))
	# Tokens at each bend's apex (hugging the inside wall), under both
	# arches and past the hoodoos.
	apex = [(a[0] + b[0]) * 0.5 for a, b in zip(headings, headings[1:])]
	toks = tokens_on(line, every=10.0, at=apex + [118.0, 172.0, 186.0, 318.0])
	return {"id": "nature_canyon", "name": "River canyon (bends, an arch, out over the saddle and back in, a bridge)", "intent": "medium",
		"line": line, "parts": parts, "tokens": toks}


def scatter(line, seed, count, near, far, s0, s1, radius=(2.0, 4.5), top=(-14.0, 18.0), keep=()):
	"""Stacks scattered off the line (a field, not the way): `count` tries,
	each `near`-`far` m to either side, never within `near` of the line,
	nor nearer than 3 m to another (`keep` too)."""
	rnd = seed
	out = []
	placed = list(keep)

	def rand():
		nonlocal rnd
		rnd = (rnd * 1103515245 + 12345) % 2147483648
		return rnd / 2147483648.0

	track = line.samples()[::8]
	for _ in range(count):
		s = s0 + (s1 - s0) * rand()
		side = -1 if rand() < 0.5 else 1
		d = near + (far - near) * rand()
		r = radius[0] + (radius[1] - radius[0]) * rand()
		p = line.off(s, side * (d + r))
		h = line.P(s)[1] + top[0] + (top[1] - top[0]) * rand()
		if any(math.hypot(p[0] - q[0], p[2] - q[2]) < r * 1.35 + q[3] + 3.0 for q in placed):
			continue
		# Never near the line anywhere (it curves).
		if min(math.hypot(p[0] - lp[0], p[2] - lp[2]) for _, lp in track) < near + r * 1.35:
			continue
		placed.append((p[0], 0.0, p[2], r * 1.35))
		out.append(["stack", (p[0], p[2]), r * 1.35, r, h, {}])
	return out


def station_stacks():
	"""A field of sea stacks: a long lazy weave, each bend wrapped round a
	stack on its inside with another across the way to pass between, down
	low among the stacks' feet, through a tunnel in a big stack, then a
	long climb out under a sea arch."""
	L = 320.0
	headings = [(0, 0), (24, 22), (66, -22), (108, 24), (150, -20), (192, 22), (234, -24), (276, 20), (312, -6), (330, 0)]
	climbs = [(0, 0.0), (20, -0.1), (100, -0.1), (150, 0.0), (200, 0.12), (280, 0.12), (320, 0.04)]
	line = Line(L, headings, climbs, bob=0.14)
	parts = []
	stacks = []
	# Each bend's apex (half way between heading knots): a stack on its
	# inside, 4.5 m off the line; one across the way, 7 m off.
	for (sa, ha), (sb, hb) in zip(headings, headings[1:]):
		if abs(hb - ha) < 20 or sa > 300:
			continue
		s = (sa + sb) * 0.5
		inside = 1 if hb > ha else -1
		y = line.P(s)[1]
		stacks.append(stack_at(line, s, inside * 4.5, 3.2, y + 10.0 + (s % 7)))
		stacks.append(stack_at(line, s + 4.0, -inside * 7.0, 2.4, y + 4.0 + (s % 5)))
	# Gates where the weave crosses over (the heading knots): a pair of
	# slimmer stacks either side, 5.5 m off.
	for s in (66.0, 108.0, 192.0, 234.0, 276.0):
		y = line.P(s)[1]
		stacks.append(stack_at(line, s, -5.5, 1.8, y + 6.0 + (s % 4)))
		stacks.append(stack_at(line, s + 2.0, 5.5, 1.8, y + 3.0 + (s % 6)))
	# The tunnel: a big stack on the line at s 172 (a heading knot, the line
	# straight through it), a 7 x 6.5 m hole.
	st = 150.0
	p = line.P(st)
	hole = {"y": p[1] - 3.2, "w": 7.0, "h": 6.5, "yaw": line.yaw(st)}
	stacks.append(["stack", (p[0], p[2]), 10.5, 6.5, p[1] + 16.0, hole])
	parts += stacks
	# The sea arch over the climb, its legs from the sea.
	sa_ = 286.0
	parts.append(across_arch(line, sa_, 11.0, 5.0, 4.0, line.P(sa_)[1] + 9.0, drop=12.0))
	keep = [(q[1][0], 0.0, q[1][1], q[2]) for q in stacks]
	parts += scatter(line, 11, 55, 9.0, 34.0, -10.0, 320.0, keep=keep)
	# Tokens round each wrapped stack, through each gate, in the tunnel and
	# under the arch.
	apex = [(a[0] + b[0]) * 0.5 for a, b in zip(headings, headings[1:]) if abs(b[1] - a[1]) >= 20 and a[0] <= 300]
	toks = tokens_on(line, every=11.0, at=apex + [66.0, 108.0, 192.0, 234.0, 276.0, st - 6.0, st + 6.0, sa_])
	return {"id": "nature_stacks", "name": "Sea stacks (a lazy weave round them, a tunnel through one, a sea arch)", "intent": "easy", "ease": 1.3,
		"line": line, "parts": parts, "tokens": toks}


def station_cove():
	"""A waterfall cove: along a sea cliff, turning in to it, diving round
	the back of the cove behind the fall, then up and out through an arch
	in the far headland."""
	L = 270.0
	headings = [(0, 0), (22, -16), (52, 16), (92, 60), (146, -8), (184, -44), (216, 8), (244, -18), (270, 4), (290, 0)]
	climbs = [(0, 0.0), (50, 0.0), (80, -0.2), (118, -0.2), (142, 0.0), (162, 0.12), (204, 0.12), (232, 0.16), (270, 0.1)]
	line = Line(L, headings, climbs, bob=0.1)
	parts = []
	RIM = 15.0
	# The cliff on the right, 5.5 m off, its top level (the line dives below it).
	parts.append(wall(line, -14.0, 206.0, 1, lambda s: 5.5, lambda s: RIM, thick=10.0, step=4.0))
	# Further along, past the headland, lower.
	parts.append(wall(line, 206.0, 268.0, 1, lambda s: 6.5, lambda s: ease([(206, RIM), (268, line.P(268)[1] - 4.0)], s), thick=10.0, step=6.0))
	# The fall: a sheet from the rim, 4.5 m left of the line, the way behind
	# it 10 m wide.
	parts.append(wall(line, 122.0, 146.0, -1, lambda s: 4.5, lambda s: RIM - 1.0, thick=0.8, step=3.0))
	# Stacks off the cove's mouth to pass between.
	parts.append(stack_at(line, 44.0, -5.0, 2.6, 8.0))
	parts.append(stack_at(line, 98.0, -5.0, 2.8, 4.0))
	parts.append(stack_at(line, 112.0, -9.0, 2.2, 1.0))
	# More along the open side, so the cliff and a stack make a gap.
	for s, d, top in ((18.0, -5.0, 6.0), (70.0, -5.5, 3.0), (164.0, -5.0, 2.0), (218.0, -5.0, 9.0), (244.0, -5.0, 12.0)):
		parts.append(stack_at(line, s, d, 2.2, line.P(s)[1] + top))
	# The headland: a rib from the cliff out to sea, an arch through it.
	sh = 192.0
	parts.append(across_arch(line, sh, 9.0, 3.6, 8.0, RIM, sill=True, drop=3.6))
	a = line.off(sh, -(4.5 + 3.0))
	b = line.off(sh, -(4.5 + 3.0 + 22.0))
	parts.append(["wall", [(a[0], RIM, a[2]), (b[0], RIM - 8.0, b[2])], 8.0, 0.0])
	keep = [(q[1][0], 0.0, q[1][1], q[2]) for q in parts if q[0] == "stack"]
	parts += scatter(line, 5, 30, 12.0, 34.0, 20.0, 260.0, radius=(2.0, 4.0), top=(-16.0, 6.0), keep=keep)
	# Tokens between the cliff and each stack, behind the fall and through
	# the headland.
	toks = tokens_on(line, every=10.0, at=[18.0, 44.0, 70.0, 98.0, 124.0, 134.0, 144.0, 164.0, sh, 218.0, 244.0])
	return {"id": "nature_cove", "name": "Waterfall cove (along the cliff, round behind the fall, out through the headland)", "intent": "easy", "ease": 1.3,
		"line": line, "parts": parts, "tokens": toks}


def cross(line, s0, s1, a, b):
	"""Where the line's ground track between s0 and s1 crosses the segment
	a-b (x, z): (s, the share along a-b), or None."""
	prev = None
	s = s0
	while s <= s1:
		p = line.P(s)
		if prev is not None:
			q = prev[1]
			d1 = (p[0] - q[0], p[2] - q[2])
			d2 = (b[0] - a[0], b[2] - a[2])
			den = d1[0] * d2[1] - d1[1] * d2[0]
			if abs(den) > 1e-9:
				t = ((a[0] - q[0]) * d2[1] - (a[2] - q[2]) * d2[0]) / den
				u = ((a[0] - q[0]) * d1[1] - (a[2] - q[2]) * d1[0]) / den
				if 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0:
					return prev[0] + t * DS, u
		prev = (s, p)
		s += DS
	return None


def station_ridge():
	"""A long ridge: hugging its east face, through a notch to the west
	side, under an overhang along the west face, back through a tunnel to
	the east, and up over its low end."""
	L = 320.0
	headings = [(0, 0), (18, -14), (42, 14), (86, -64), (122, 8), (146, -14), (170, 14), (200, -8), (234, 62), (266, -8), (294, -28), (325, -14)]
	climbs = [(0, 0.0), (40, -0.06), (70, -0.06), (100, 0.0), (190, 0.0), (220, 0.04), (262, 0.0), (276, 0.16), (320, 0.16)]
	line = Line(L, headings, climbs, bob=0.14)
	parts = []
	T = 18.0
	HALF = T * 0.5
	FACE = 4.5
	TOP = 13.0

	def axis(s0, s1, side, step=4.0):
		n = max(1, int(math.ceil((s1 - s0) / step)))
		return [line.off(s0 + (s1 - s0) * j / n, side * (FACE + HALF)) for j in range(n + 1)]

	a = axis(-20.0, 62.0, -1)
	b = axis(118.0, 204.0, 1)
	c = axis(262.0, 282.0, -1)
	# C runs on straight past the line's last turn, so the line crosses it.
	c_dir = (c[-1][0] - c[-2][0], c[-1][2] - c[-2][2])
	n_ = math.hypot(*c_dir)
	for j in range(1, 8):
		c.append((c[-1][0] + c_dir[0] / n_ * 6.0, 0.0, c[-1][2] + c_dir[1] / n_ * 6.0))

	def top_pts(pts, top):
		return [(p[0], top(j, p), p[2]) for j, p in enumerate(pts)]

	def angle(p, q, s_hit):
		"""The sine and cosine of the angle the line crosses p-q at."""
		d = (q[0] - p[0], q[2] - p[2])
		ln = math.hypot(*d)
		w = line.fwd(s_hit)
		sin_a = abs((d[0] * w[2] - d[1] * w[0]) / ln / math.hypot(w[0], w[2]))
		return sin_a, math.sqrt(max(0.0, 1.0 - sin_a * sin_a))

	def cut(p, q, u, lateral, sin_a):
		"""The two points on p-q either side of the crossing at share u,
		`lateral` m to either side of the line."""
		d = (q[0] - p[0], q[2] - p[2])
		ln = math.hypot(*d)
		h = lateral / max(0.3, sin_a)
		m = (p[0] + d[0] * u, p[2] + d[1] * u)
		e = (d[0] / ln, d[1] / ln)
		return (m[0] - e[0] * h, m[1] - e[1] * h), (m[0] + e[0] * h, m[1] + e[1] * h)

	# The notch between A and B: the ridge cut so its nearest corners stand
	# NOTCH m either side of the line, a sill 5 m under it.
	NOTCH = 6.0
	s_n, u_n = cross(line, 60.0, 124.0, a[-1], b[0])
	sin_n, cos_n = angle(a[-1], b[0], s_n)
	n0, n1 = cut(a[-1], b[0], u_n, NOTCH + HALF * cos_n, sin_n)
	yn = line.P(s_n)[1]
	ridge_a = a + [(n0[0], 0.0, n0[1])]
	ridge_b0 = [(n1[0], 0.0, n1[1])] + b
	parts.append(["wall", [(n0[0], yn - 5.0, n0[1]), (n1[0], yn - 5.0, n1[1])], T, 0.0])
	# The way back between B and C: a second notch, a natural bridge over
	# it (its soffit BRIDGE m over the line), its legs in the notch.
	BRIDGE = 4.4
	s_t, u_t = cross(line, 200.0, 270.0, b[-1], c[0])
	sin_t, cos_t = angle(b[-1], c[0], s_t)
	t0, t1 = cut(b[-1], c[0], u_t, NOTCH + 1.0 + HALF * cos_t, sin_t)
	ridge_b = ridge_b0 + [(t0[0], 0.0, t0[1])]
	ridge_c = [(t1[0], 0.0, t1[1])] + c
	yt = line.P(s_t)[1]
	parts.append(["wall", [(t0[0], yt - 6.0, t0[1]), (t1[0], yt - 6.0, t1[1])], T, 0.0])
	parts.append(across_arch(line, s_t, 2.0 * (NOTCH + 1.0), BRIDGE, 7.0, TOP - 2.0, drop=6.0))
	# The ridge's tops: TOP, the last piece falling away under the climb.
	parts.append(["wall", top_pts(ridge_a, lambda j, p: TOP), T, 0.0])
	parts.append(["wall", top_pts(ridge_b, lambda j, p: TOP), T, 0.0])
	end_y = line.P(296.0)[1] - 9.0
	parts.append(["wall", top_pts(ridge_c, lambda j, p: TOP + (end_y - TOP) * min(1.0, j / (len(ridge_c) - 1.0)) ** 0.6), T, 0.0])
	# Pinnacles on the open side, 5 m off, so the face and a pinnacle make
	# a gap to pass through.
	for s, d in ((16.0, 5.0), (40.0, 5.0), (128.0, -5.0), (190.0, -5.0), (276.0, 5.0)):
		parts.append(stack_at(line, s, d, 2.0, line.P(s)[1] + 7.0))
	# The overhang along the west face (s 140-176): a shelf 3.6 m over the
	# line, from the face out 2.5 m past it.
	for s in range(140, 176, 6):
		mid = line.off(s + 3.0, (FACE - 2.5) * 0.5 + 1.0)
		parts.append(["box", (mid[0], line.P(s + 3.0)[1] + 3.6 + 2.0, mid[2]), (FACE + 2.5 + 2.0, 4.0, 6.6), line.yaw(s + 3.0)])
	# Tokens past each pinnacle, through both notches and under the
	# overhang.
	toks = tokens_on(line, every=10.0, at=[16.0, 40.0, s_n, 128.0, 146.0, 158.0, 170.0, 190.0, s_t, 276.0])
	st = {"id": "nature_ridge", "name": "Ridge (along the face, through a notch, under an overhang, back under a natural bridge, over the end)", "intent": "medium",
		"line": line, "parts": parts, "tokens": toks}
	st["notes"] = f"notch at s {s_n:.0f} (crossing {math.degrees(math.asin(min(1.0, sin_n))):.0f} deg), bridge at s {s_t:.0f} ({math.degrees(math.asin(min(1.0, sin_t))):.0f} deg)"
	return st


def station_cave():
	"""A sea cave through a rock: in at its mouth, weaving, up and out
	through a skylight in its roof, over the roof between pinnacles, back
	down in through a second skylight, and out at the far mouth."""
	L = 280.0
	headings = [(0, 0), (24, 18), (52, -18), (80, 18), (108, -26), (136, 22), (168, -16), (200, 18), (230, -16), (256, 16), (284, -8)]
	climbs = [(0, 0.0), (50, 0.0), (77, 0.44), (104, 0.0), (126, 0.0), (153, -0.44), (180, 0.0), (234, 0.0), (250, 0.14), (280, 0.14)]
	line = Line(L, headings, climbs, bob=0.12)
	parts = []
	MOUTH, FAR = 20.0, 234.0
	inside_ys = [line.P(s)[1] for s in range(int(MOUTH), 56)] + [line.P(s)[1] for s in range(184, int(FAR))]
	SOFFIT = max(inside_ys) + 4.0
	THICK = 2.5
	TOP = SOFFIT + THICK
	WIDE = 6.0
	# The cave's walls: the rock either side, 6 m off the line (the inside
	# of a bend 1.5 m closer), up to the roof's top.
	K = 0.05

	def lean(s):
		return max(-1.0, min(1.0, line.k[line.i(s)] / K))

	for side in (-1, 1):
		parts.append(wall(line, MOUTH, FAR, side, lambda s, side=side: WIDE - 1.5 * side * lean(s), lambda s: TOP, thick=10.0, step=5.0))
	# The roof, a slab per 4 m of line, left out where the line passes
	# through its height (the skylights).
	step = 4.0
	mids = []
	s = MOUTH
	while s < FAR - 0.01:
		mids.append(s + step * 0.5)
		s += step
	through = []
	for m in mids:
		ys = [line.P(m + step * (j / 8.0 - 0.5))[1] for j in range(9)]
		through.append(max(ys) > SOFFIT - 3.0 and min(ys) < TOP + 2.0)
	# One more slab left out either side of each skylight.
	open_ = [through[j] or (j > 0 and through[j - 1]) or (j + 1 < len(through) and through[j + 1]) for j in range(len(through))]
	runs = []
	for j, m in enumerate(mids):
		if open_[j]:
			if runs and runs[-1][1] == mids[j - 1]:
				runs[-1][1] = m
			else:
				runs.append([m, m])
			continue
		p = line.P(m)
		parts.append(["box", (p[0], SOFFIT + THICK * 0.5, p[2]), (2.0 * (WIDE + 3.0), THICK, step + 0.3), line.yaw(m)])
	# Pinnacles on the roof, either side of the way over it.
	pins = []
	for s, d in ((112.0, 4.5), (124.0, -4.5)):
		p = line.off(s, d)
		parts.append(["box", (p[0], TOP + 3.5, p[2]), (3.0, 7.0, 3.0), line.yaw(s) + 0.4])
		pins.append(s)
	st = {"id": "nature_cave", "name": "Sea cave (in at the mouth, out through a skylight, over the roof, back in, out the far mouth)", "intent": "medium",
		"line": line, "parts": parts}
	# Tokens at the mouth, through both skylights, past the pinnacles, and
	# at the far mouth.
	assert len(runs) == 2, runs
	st["tokens"] = tokens_on(line, every=10.0, at=[MOUTH, FAR] + pins + [(a + b) * 0.5 for a, b in runs])
	st["notes"] = f"roof soffit {SOFFIT:.1f}, top {TOP:.1f}; skylights over s " + " and ".join(f"{a - 2:.0f}-{b + 2:.0f}" for a, b in runs)
	return st


STATIONS = {"canyon": station_canyon, "stacks": station_stacks, "cove": station_cove, "ridge": station_ridge, "cave": station_cave}


# --- Checks -----------------------------------------------------------------------------


def check(name, st, verbose=True):
	line = st["line"]
	solids = [s for part in st["parts"] for s in expand(part)]
	field = Field(solids)
	toks = st["tokens"]
	samples = line.samples()
	# Needs, at cruise.
	turn = [abs(k) * CRUISE / TURN_RATE for k in line.k]
	pitch = []
	for i in range(len(line.gam)):
		a = line.gam[max(0, i - 1)]
		b = line.gam[min(len(line.gam) - 1, i + 1)]
		pitch.append(abs(b - a) / (2 * DS) * CRUISE / PITCH_SPEED)
	swing = [CRUISE * math.hypot(t * TURN_RATE / CRUISE, p * PITCH_SPEED / CRUISE) for t, p in zip(turn, pitch)]
	still = [w < STILL for w in swing]
	longest = run = 0.0
	for st_ in still:
		run = run + DS / CRUISE if st_ else 0.0
		longest = max(longest, run)
	yaw_sum = sum(t * TURN_RATE for t in turn)
	pitch_sum = sum(p * PITCH_SPEED for p in pitch)
	# Room along the line.
	rooms = []
	for s, p in samples[::2]:
		rooms.append((s, field.clearance(p) - SPAN * 0.5))
	least = min(rooms, key=lambda r: r[1])
	tight = [r for r in rooms if r[1] < REACH]
	# Threading (FlightMetrics `threading_at`, sampled): rock within 8 m
	# both left and right, level, or 12 m above.
	thread = 0
	total = 0
	for s, p in samples[::8]:
		total += 1
		r = line.right(s)

		def ray(d, far):
			for j in range(1, int(far / 0.5) + 1):
				q = (p[0] + d[0] * j * 0.5, p[1] + d[1] * j * 0.5, p[2] + d[2] * j * 0.5)
				if field.hit(q):
					return True
			return False

		if ray((0, 1, 0), 12.0) or (ray(r, 8.0) and ray((-r[0], 0, -r[2]), 8.0)):
			thread += 1
	# Tokens: clear of the rock, and never "3 m past" from earlier on the line.
	worst_past = -1e9
	worst_at = None
	for s in toks:
		t = line.P(s)
		w = line.fwd(s)
		for s2, p in samples[: line.i(s - 6.0)]:
			d = sum(w[j] * (p[j] - t[j]) for j in range(3))
			if d > worst_past:
				worst_past, worst_at = d, (s, s2)
	tok_clear = min(field.clearance(line.P(s)) for s in toks)
	xs = [b for sol in solids for b in (bound(sol)[0] - bound(sol)[2], bound(sol)[0] + bound(sol)[2])]
	zs = [b for sol in solids for b in (bound(sol)[1] - bound(sol)[2], bound(sol)[1] + bound(sol)[2])]
	ys = [p[1] for _, p in samples]
	out = {
		"tokens": len(toks), "length": line.length, "time": line.length / CRUISE, "solids": len(solids),
		"turn_peak": max(turn), "pitch_peak": max(pitch), "still": sum(still) / len(still), "longest": longest,
		"yaw_share": yaw_sum / max(1e-9, yaw_sum + pitch_sum), "room_min": least, "tight": len(tight) / len(rooms),
		"threading": thread / total, "token_clear": tok_clear, "past": worst_past, "past_at": worst_at,
		"x": (min(xs), max(xs)), "z": (min(zs), max(zs)), "y": (min(ys), max(ys)),
		"heading": (math.degrees(min(line.psi)), math.degrees(max(line.psi))),
	}
	if verbose:
		print(f"{st['id']}: {out['tokens']} tokens, {out['length']:.0f} m (~{out['time']:.1f} s), {out['solids']} solids")
		print(f"  need: turn peak {out['turn_peak']:.2f}, pitch peak {out['pitch_peak']:.2f}; still {out['still']:.0%}, longest {out['longest']:.2f} s, sideways {out['yaw_share']:.0%}")
		print(f"  room: least {least[1]:.2f} m at s {least[0]:.0f}; under reach {out['tight']:.0%} of the line; threading ~{out['threading']:.0%}")
		print(f"  tokens clear by {tok_clear:.2f} m; worst 'past' {worst_past:.1f} m (token at s {worst_at[0] if worst_at else '-'}); heading {out['heading'][0]:.0f}..{out['heading'][1]:.0f} deg")
		if st.get("notes"):
			print("  " + st["notes"])
		print(f"  extent x {out['x'][0]:.0f}..{out['x'][1]:.0f}, z {out['z'][0]:.0f}..{out['z'][1]:.0f}; line y {out['y'][0]:.1f}..{out['y'][1]:.1f}")
		low = []
		prev = None
		for s, rm in rooms:
			if rm < REACH:
				if prev is None or s - prev > 3.0:
					low.append([s, s, rm])
				low[-1][1] = s
				low[-1][2] = min(low[-1][2], rm)
				prev = s
		if low:
			print("  under reach: " + ", ".join(f"s {a:.0f}-{b:.0f} ({m:.2f})" for a, b, m in low[:12]))
	return out


# --- GDScript ---------------------------------------------------------------------------


def num(v):
	t = f"{v:.2f}"
	return "0.00" if t == "-0.00" else t


def gd(v):
	if isinstance(v, bool):
		return "true" if v else "false"
	if isinstance(v, (int, float)):
		return num(float(v))
	if isinstance(v, dict):
		return "{" + ",".join(f'"{k}":{gd(x)}' for k, x in v.items()) + "}"
	if isinstance(v, tuple):
		if len(v) == 2:
			return f"Vector2({num(v[0])},{num(v[1])})"
		return f"Vector3({num(v[0])},{num(v[1])},{num(v[2])})"
	if isinstance(v, list):
		if v and isinstance(v[0], tuple) and len(v[0]) == 3:
			return "[" + ",".join(gd(x) for x in v) + "]"
		return "[" + ",".join(gd(x) for x in v) + "]"
	if isinstance(v, str):
		return f'"{v}"'
	raise TypeError(v)


def gd_station(st):
	line = st["line"]
	ease_ = f'"ease":{num(st["ease"])},' if "ease" in st else ""
	lines = [f'\t{{"id":"{st["id"]}","key":-1,"pack":"nature","name":"{st["name"]}","intent":"{st["intent"]}",{ease_}"parts":[']
	for part in st["parts"]:
		if part[0] == "box":
			lines.append(f'\t\t["box",{gd(tuple(part[1]))},{gd(tuple(part[2]))},{num(part[3])}],')
		elif part[0] == "wall":
			pts = part[1]
			body = ",".join(gd(p) for p in pts)
			lines.append(f'\t\t["wall",[{body}],{num(part[2])},{num(part[3])}],')
		elif part[0] == "stack":
			lines.append(f'\t\t["stack",{gd(tuple(part[1]))},{num(part[2])},{num(part[3])},{num(part[4])},{gd(part[5])}],')
		elif part[0] == "arch":
			leg = f",{num(part[8])}" if len(part) > 8 else ""
			lines.append(f'\t\t["arch",{gd(tuple(part[1]))},{num(part[2])},{num(part[3])},{num(part[4])},{num(part[5])},{num(part[6])},{gd(part[7])}{leg}],')
	lines.append('\t],"tokens":[')
	toks = [line.P(s) for s in st["tokens"]]
	for j in range(0, len(toks), 4):
		lines.append("\t\t" + ",".join(gd(t) for t in toks[j:j + 4]) + ",")
	lines.append("\t]},")
	return "\n".join(lines)


BEGIN = "\t# >>> nature stations: written by tools/flight_nature_layout.py --write"
END = "\t# <<< nature stations"
PACK = "scripts/flight_pack_nature.gd"


def write(stations, path=PACK):
	with open(path) as f:
		text = f.read()
	a = text.index(BEGIN)
	b = text.index(END)
	body = "\n".join(gd_station(st) for st in stations)
	text = text[:a] + BEGIN + "\n" + body + "\n" + text[b:]
	with open(path, "w") as f:
		f.write(text)
	print(f"wrote {len(stations)} station(s) into {path}")


# --- A top view (PNG) -------------------------------------------------------------------


def png(path, w, h, rgb):
	raw = b"".join(b"\x00" + bytes(rgb[y * w * 3:(y + 1) * w * 3]) for y in range(h))
	def chunk(t, d):
		c = struct.pack(">I", len(d)) + t + d
		return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
	data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
	with open(path, "wb") as f:
		f.write(data)


def top_view(st, path, px=0.5, zoom=None):
	"""North up. Rock dark where it stands over the line's height nearby,
	light where the line passes over it; the line blue, red where its room
	is under the reach; tokens yellow; a black tick every 20 m of line, a
	big one every 100."""
	line = st["line"]
	solids = [s for part in st["parts"] for s in expand(part)]
	field = Field(solids)
	pts = line.p if zoom is None else [line.P(s) for s in range(int(zoom[0]), int(zoom[1]) + 1)]
	xs = [p[0] for p in pts] + ([] if zoom else [bound(s)[0] for s in solids])
	zs = [p[2] for p in pts] + ([] if zoom else [bound(s)[1] for s in solids])
	x0, x1 = min(xs) - 15, max(xs) + 15
	z0, z1 = min(zs) - 15, max(zs) + 15
	w, h = int((x1 - x0) / px), int((z1 - z0) / px)
	rgb = bytearray([235, 235, 228] * (w * h))
	track = line.samples()[::8]

	def put(i, j, c):
		if 0 <= i < w and 0 <= j < h:
			k = (j * w + i) * 3
			rgb[k:k + 3] = bytes(c)

	for sol in sorted(solids, key=lambda q: bound(q)[4]):
		bx, bz, br, b_lo, b_hi = bound(sol)
		if bx + br < x0 or bx - br > x1 or bz + br < z0 or bz - br > z1:
			continue
		near = min(track, key=lambda q: math.hypot(q[1][0] - bx, q[1][2] - bz))[1]
		c = (90, 70, 55) if b_hi > near[1] - 1.0 else (190, 170, 140)
		for j in range(max(0, int((bz - br - z0) / px)), min(h, int((bz + br - z0) / px) + 1)):
			for i in range(max(0, int((bx - br - x0) / px)), min(w, int((bx + br - x0) / px) + 1)):
				x, z = x0 + i * px, z0 + j * px
				if sol[0] == "box":
					_, m, size, yaw = sol
					qx, qz = x - m[0], z - m[2]
					c_, s_ = math.cos(yaw), math.sin(yaw)
					if abs(qx * c_ - qz * s_) <= size[0] * 0.5 and abs(qx * s_ + qz * c_) <= size[2] * 0.5:
						put(i, j, c)
				elif math.hypot(x - sol[1][0], z - sol[1][2]) <= sol[2]:
					put(i, j, c)
	for s, p in line.samples()[::2]:
		tight = field.clearance(p) - SPAN * 0.5 < REACH
		put(int((p[0] - x0) / px), int((p[2] - z0) / px), (230, 20, 20) if tight else (40, 80, 220))
		if abs(s % 20.0) < 1e-6:
			big = 3 if abs(s % 100.0) < 1e-6 else 1
			r = line.right(s)
			for k in range(-big * 6, big * 6 + 1):
				put(int((p[0] + r[0] * k * px - x0) / px), int((p[2] + r[2] * k * px - z0) / px), (0, 0, 0))
	for s in st["tokens"]:
		p = line.P(s)
		ci, cj = int((p[0] - x0) / px), int((p[2] - z0) / px)
		for di in range(-2, 3):
			for dj in range(-2, 3):
				put(ci + di, cj + dj, (250, 200, 40))
	png(path, w, h, rgb)
	print(f"top view: {path} ({w}x{h}, {px} m/px, north up)")


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--station", default="all")
	ap.add_argument("--check", action="store_true")
	ap.add_argument("--write", action="store_true")
	ap.add_argument("--png")
	ap.add_argument("--zoom", help="s0,s1: the top view round that stretch of line only")
	ap.add_argument("--px", type=float, default=0.5)
	a = ap.parse_args()
	keys = list(STATIONS) if a.station == "all" else a.station.split(",")
	built = [STATIONS[k]() for k in keys]
	if a.check or not (a.write or a.png):
		for st in built:
			check(st["id"], st)
	if a.png:
		for st in built:
			zoom = [float(v) for v in a.zoom.split(",")] if a.zoom else None
			top_view(st, f"{a.png}_{st['id']}.png", a.px, zoom)
	if a.write:
		if a.station != "all":
			raise SystemExit("--write rewrites every station: leave out --station")
		write(built)


if __name__ == "__main__":
	main()
