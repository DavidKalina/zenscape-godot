#!/usr/bin/env python3
"""Lays out the flight study's sky pack (scripts/flight_pack_sky.gd): greybox
stations built from floating islands, spires, rope spans and a pierced isle,
with open sky and the cloud floor below.

Each station is laid out line first, as `sundered_flow` was: a smooth line
through the sky (a natural cubic spline through a few control points,
parametrised by chord length, leaving the entry heading north and level),
then the masses stood round it so it passes under rims and keels, between
two islands' edges, through a bore and round a spire, then the tokens every
`step` m along it. The checker rebuilds the line the study measures
(FlightMetrics `line`: a centripetal Catmull-Rom through the entry and the
tokens, with a 10 m lead-in) and reports, per station:

  room       the least clearance (m) of that line to any solid, less half
             the wingspan, and where; and each token's clearance
  need       the line's yaw and pitch rate at cruise, smoothed over 0.2 s,
             as shares of TURN_RATE and PITCH_SPEED (peak and mean)
  still      the share of the line swinging under 6 deg/s at cruise, the
             longest such stretch (s), and the sideways share of the swing
  thread     the share of the line threading (solids within 8 m both sides,
             or 12 m above), as FlightMetrics `threading_at` reads it
  past       tokens the run's "3 m past it" miss rule would drop early
             (before the line reaches them), within the station's
             `miss_near` m if it has one

  python3 tools/flight_sky_layout.py --check            # every station's numbers
  python3 tools/flight_sky_layout.py --check --station sky_spire --gaps
  python3 tools/flight_sky_layout.py --write            # rewrite the STATIONS block
"""
import argparse
import math
import re
import sys

CRUISE = 14.0
TURN_RATE = 1.6
PITCH_SPEED = 1.4
HALF_SPAN = 0.7
LEAD_IN = 10.0
STEP = 0.5
SMOOTH = 0.2
STILL = 6.0
PAST = 3.0
THREAD_SIDE = 8.0
THREAD_UP = 12.0

# The pack's geometry (scripts/flight_pack_sky.gd), mirrored.
ISLE_TOP = 1.5
KEEL_TIERS = [0.66, 0.46, 0.3, 0.16]
SPAN_SEGMENTS = 6
DECK = 0.35
RAIL_UP = 0.9
RAIL = 0.12

PATH = "scripts/flight_pack_sky.gd"
BEGIN = "# >>> sky stations: written by tools/flight_sky_layout.py --write"
END = "# <<< sky stations"


# --- Vectors and bases ----------------------------------------------------------------

def add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def mul(a, k): return (a[0] * k, a[1] * k, a[2] * k)
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def length(a): return math.sqrt(dot(a, a))
def lerp(a, b, t): return add(a, mul(sub(b, a), t))


def norm(a):
	n = length(a)
	return mul(a, 1.0 / n) if n > 1e-9 else (0.0, 0.0, -1.0)


def turned(yaw, pitch):
	"""Basis(UP, yaw) * Basis(RIGHT, pitch) as three columns (x, y, z)."""
	cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
	ry = ((cy, 0.0, -sy), (0.0, 1.0, 0.0), (sy, 0.0, cy))        # columns of R_y
	rx = ((1.0, 0.0, 0.0), (0.0, cp, sp), (0.0, -sp, cp))         # columns of R_x
	return tuple(apply(ry, c) for c in rx)


def apply(basis, v):
	return add(add(mul(basis[0], v[0]), mul(basis[1], v[1])), mul(basis[2], v[2]))


def apply_t(basis, v):
	return (dot(basis[0], v), dot(basis[1], v), dot(basis[2], v))


def heading_of(d):
	return math.atan2(-d[0], -d[2])


def pitch_of(d):
	return math.atan2(d[1], math.hypot(d[0], d[2]))


# --- Solids (FlightCourse `solids`, FlightPackSky `solids_of`) ---------------------------

def box(middle, size, basis):
	return {"kind": "box", "middle": middle, "size": size, "basis": basis}


def cyl(middle, radius, height):
	return {"kind": "cyl", "middle": middle, "radius": radius, "height": height}


def isle(top, radius, keel):
	out = [cyl(sub(top, (0.0, ISLE_TOP * 0.5, 0.0)), radius, ISLE_TOP)]
	step = (keel - ISLE_TOP) / len(KEEL_TIERS)
	for i, share in enumerate(KEEL_TIERS):
		y = top[1] - ISLE_TOP - step * (i + 0.5)
		out.append(cyl((top[0], y, top[2]), radius * share, step + 0.02))
	return out


def deck(a, b, sag, t):
	p = lerp(a, b, t)
	return (p[0], p[1] - 4.0 * sag * t * (1.0 - t), p[2])


def span(a, b, width, sag):
	out = []
	for i in range(SPAN_SEGMENTS):
		p = deck(a, b, sag, i / SPAN_SEGMENTS)
		q = deck(a, b, sag, (i + 1) / SPAN_SEGMENTS)
		d = sub(q, p)
		basis = turned(math.atan2(-d[0], -d[2]), math.atan2(d[1], math.hypot(d[0], d[2])))
		mid = mul(add(p, q), 0.5)
		out.append(box(sub(mid, mul(basis[1], DECK * 0.5)), (width, DECK, length(d) + 0.15), basis))
		for side in (-1.0, 1.0):
			out.append(box(add(add(mid, mul(basis[0], side * width * 0.5)), mul(basis[1], RAIL_UP)), (RAIL, RAIL, length(d) + 0.1), basis))
	return out


def bore(start, yaw, pitch, ln, width, height, wall):
	basis = turned(yaw, pitch)
	mid = add(start, apply(basis, (0.0, 0.0, -ln * 0.5)))
	put = lambda local, size: box(add(mid, apply(basis, local)), size, basis)
	return [
		put((0.0, -(height + wall) * 0.5, 0.0), (width + 2.0 * wall, wall, ln)),
		put((0.0, (height + wall) * 0.5, 0.0), (width + 2.0 * wall, wall, ln)),
		put((-(width + wall) * 0.5, 0.0, 0.0), (wall, height, ln)),
		put(((width + wall) * 0.5, 0.0, 0.0), (wall, height, ln)),
	]


def solids(parts):
	out = []
	for p in parts:
		k = p[0]
		if k == "rock": out.append(cyl(p[1], p[2], p[3]))
		elif k == "isle": out += isle(p[1], p[2], p[3])
		elif k == "span": out += span(p[1], p[2], p[3], p[4])
		elif k == "bore": out += bore(*p[1:])
		elif k == "slab": out.append(box(p[1], p[2], turned(p[3], p[4])))
		elif k == "box": out.append(box(p[1], p[2], turned(p[3], 0.0)))
		else: raise ValueError(k)
	return out


def distance(s, p):
	if s["kind"] == "box":
		local = apply_t(s["basis"], sub(p, s["middle"]))
		q = [abs(local[i]) - s["size"][i] * 0.5 for i in range(3)]
		outside = math.sqrt(sum(max(v, 0.0) ** 2 for v in q))
		return outside + min(max(q), 0.0)
	m = s["middle"]
	dx = math.hypot(p[0] - m[0], p[2] - m[2]) - s["radius"]
	dy = abs(p[1] - m[1]) - s["height"] * 0.5
	return math.hypot(max(dx, 0.0), max(dy, 0.0)) + min(max(dx, dy), 0.0)


def clearance(all_solids, p, floor=-40.0):
	best = p[1] - floor
	for s in all_solids: best = min(best, distance(s, p))
	return best


def ray_hits(s, frm, d, ln):
	lo, hi = 0.0, ln
	if s["kind"] == "box":
		o = apply_t(s["basis"], sub(frm, s["middle"]))
		dd = apply_t(s["basis"], d)
		for a in range(3):
			half = s["size"][a] * 0.5
			if abs(dd[a]) < 1e-9:
				if abs(o[a]) > half: return False
				continue
			t0, t1 = (-half - o[a]) / dd[a], (half - o[a]) / dd[a]
			lo, hi = max(lo, min(t0, t1)), min(hi, max(t0, t1))
			if lo > hi: return False
		return True
	m = s["middle"]
	r, hh = s["radius"], s["height"] * 0.5
	if abs(d[1]) < 1e-9:
		if abs(frm[1] - m[1]) > hh: return False
	else:
		t0, t1 = (m[1] - hh - frm[1]) / d[1], (m[1] + hh - frm[1]) / d[1]
		lo, hi = max(lo, min(t0, t1)), min(hi, max(t0, t1))
		if lo > hi: return False
	ox, oz = frm[0] - m[0], frm[2] - m[2]
	a = d[0] * d[0] + d[2] * d[2]
	c = ox * ox + oz * oz - r * r
	if a < 1e-12: return c <= 0.0
	b = 2.0 * (ox * d[0] + oz * d[2])
	disc = b * b - 4.0 * a * c
	if disc < 0.0: return False
	sq = math.sqrt(disc)
	t0, t1 = (-b - sq) / (2.0 * a), (-b + sq) / (2.0 * a)
	lo, hi = max(lo, t0), min(hi, t1)
	return lo <= hi


def threading_at(all_solids, p, heading):
	side = (math.cos(heading), 0.0, -math.sin(heading))
	left = any(ray_hits(s, p, mul(side, -1.0), THREAD_SIDE) for s in all_solids)
	right = left and any(ray_hits(s, p, side, THREAD_SIDE) for s in all_solids)
	if left and right: return True
	return any(ray_hits(s, p, (0.0, 1.0, 0.0), THREAD_UP) for s in all_solids)


# --- Lines ----------------------------------------------------------------------------

def natural_spline(xs, ys):
	"""Second derivatives of the natural cubic spline through (xs, ys)."""
	n = len(xs)
	m = [0.0] * n
	if n < 3: return m
	a, b, c, r = [0.0] * n, [1.0] * n, [0.0] * n, [0.0] * n
	for i in range(1, n - 1):
		h0, h1 = xs[i] - xs[i - 1], xs[i + 1] - xs[i]
		a[i], b[i], c[i] = h0 / 6.0, (h0 + h1) / 3.0, h1 / 6.0
		r[i] = (ys[i + 1] - ys[i]) / h1 - (ys[i] - ys[i - 1]) / h0
	for i in range(1, n):
		w = a[i] / b[i - 1]
		b[i] -= w * c[i - 1]
		r[i] -= w * r[i - 1]
	m[n - 1] = r[n - 1] / b[n - 1]
	for i in range(n - 2, -1, -1):
		m[i] = (r[i] - c[i] * m[i + 1]) / b[i]
	return m


def spline_eval(xs, ys, m, x):
	i = max(0, min(len(xs) - 2, next((k for k in range(len(xs) - 1) if x <= xs[k + 1]), len(xs) - 2)))
	h = xs[i + 1] - xs[i]
	t0, t1 = xs[i + 1] - x, x - xs[i]
	return (m[i] * t0 ** 3 + m[i + 1] * t1 ** 3) / (6.0 * h) + (ys[i] / h - m[i] * h / 6.0) * t0 + (ys[i + 1] / h - m[i + 1] * h / 6.0) * t1


def design(ctrl, dense=0.25):
	"""The design line: a natural cubic spline through `ctrl` (the first
	point a lead-in behind the entry, which is the second), by chord length,
	sampled every ~`dense` m from the entry on."""
	u = [0.0]
	for i in range(1, len(ctrl)): u.append(u[-1] + length(sub(ctrl[i], ctrl[i - 1])))
	axes = []
	for k in range(3):
		ys = [p[k] for p in ctrl]
		axes.append((ys, natural_spline(u, ys)))
	out = []
	x = u[1]
	while x <= u[-1] + 1e-6:
		out.append(tuple(spline_eval(u, ys, m, x) for ys, m in axes))
		x += dense
	return out


def resample(points, step, first, last=None):
	"""Points every `step` m of arc along `points`, from `first` m on."""
	out, along, want = [], 0.0, first
	for i in range(1, len(points)):
		seg = length(sub(points[i], points[i - 1]))
		while along + seg >= want - 1e-9 and seg > 0.0:
			out.append(lerp(points[i - 1], points[i], (want - along) / seg))
			want += step
			if last is not None and want > last + 1e-6: return out
		along += seg
	return out


def centripetal(a, b, c, d, t):
	t0 = 0.0
	t1 = t0 + max(math.sqrt(length(sub(a, b))), 0.001)
	t2 = t1 + max(math.sqrt(length(sub(b, c))), 0.001)
	t3 = t2 + max(math.sqrt(length(sub(c, d))), 0.001)
	u = t1 + (t2 - t1) * t
	a1 = add(mul(a, (t1 - u) / (t1 - t0)), mul(b, (u - t0) / (t1 - t0)))
	a2 = add(mul(b, (t2 - u) / (t2 - t1)), mul(c, (u - t1) / (t2 - t1)))
	a3 = add(mul(c, (t3 - u) / (t3 - t2)), mul(d, (u - t2) / (t3 - t2)))
	b1 = add(mul(a1, (t2 - u) / (t2 - t0)), mul(a2, (u - t0) / (t2 - t0)))
	b2 = add(mul(a2, (t3 - u) / (t3 - t1)), mul(a3, (u - t1) / (t3 - t1)))
	return add(mul(b1, (t2 - u) / (t2 - t1)), mul(b2, (u - t1) / (t2 - t1)))


def study_line(tokens):
	"""FlightMetrics `line`: [(point, gap)] from the entry (0,0,0) north."""
	pts = [(0.0, 0.0, LEAD_IN), (0.0, 0.0, 0.0)] + list(tokens)
	n = len(pts)
	pts.append(add(pts[-1], sub(pts[-1], pts[-2])))
	out = []
	for g in range(n - 2):
		a, b, c, d = pts[g], pts[g + 1], pts[g + 2], pts[g + 3]
		count = max(2, math.ceil(length(sub(b, c)) / STEP))
		for i in range(count): out.append((centripetal(a, b, c, d, i / count), g))
	out.append((pts[n - 1], n - 3))
	return out


# --- Checks ---------------------------------------------------------------------------

def check(st, gaps=False):
	parts, tokens = st["parts"], st["tokens"]
	all_solids = solids(parts)
	line = study_line(tokens)
	n = len(line)
	yaw, pit, ds, heads = [0.0], [0.0], [], []
	for i in range(n - 1):
		d = sub(line[i + 1][0], line[i][0])
		ds.append(max(length(d), 1e-4))
		heads.append((heading_of(d), pitch_of(d)))
		if i > 0:
			dh = (heads[i][0] - heads[i - 1][0] + math.pi) % math.tau - math.pi
			yaw.append(abs(dh))
			pit.append(abs(heads[i][1] - heads[i - 1][1]))
	window = max(1, round(SMOOTH * CRUISE / STEP))
	rows = []
	for i in range(n - 1):
		lo, hi = max(0, i - window // 2), min(n - 1, i + window // 2 + 1)
		along = sum(ds[lo:hi])
		yr = sum(yaw[lo:hi]) / along * CRUISE
		pr = sum(pit[lo:hi]) / along * CRUISE
		rows.append((yr, pr))
	room = [clearance(all_solids, p) - HALF_SPAN for p, _ in line]
	thread = [threading_at(all_solids, line[i][0], heads[min(i, len(heads) - 1)][0]) for i in range(n)]
	# The share of the line swinging under STILL deg/s, its longest stretch.
	still, run, longest, yaw_sum, pit_sum = 0.0, 0.0, 0.0, 0.0, 0.0
	total = sum(ds)
	for i, (yr, pr) in enumerate(rows):
		swing = math.degrees(math.hypot(yr, pr))
		yaw_sum += yr * ds[i]
		pit_sum += pr * ds[i]
		if swing < STILL:
			still += ds[i]
			run += ds[i]
			longest = max(longest, run)
		else:
			run = 0.0
	# Tokens the run's miss rule would drop before the line reaches them.
	near = st.get("miss_near", 0.0)
	ways = []
	for i, t in enumerate(tokens):
		before = (0.0, 0.0, 0.0) if i == 0 else tokens[i - 1]
		after = tokens[i + 1] if i + 1 < len(tokens) else add(t, sub(t, before))
		ways.append(norm(sub(after, before)))
	early = []
	for i, t in enumerate(tokens):
		for p, g in line:
			if g >= i: break
			if dot(ways[i], sub(p, t)) > PAST and (near <= 0.0 or length(sub(p, t)) < near):
				early.append(i)
				break
	tok_clear = [clearance(all_solids, t) for t in tokens]
	worst = min(range(n), key=lambda i: room[i])
	xs = [p[0] for p, _ in line] + [p for s in all_solids for p in (s["middle"][0],)]
	zs = [p[2] for p, _ in line]
	ys = [p[1] for p, _ in line]
	out = {
		"id": st["id"], "solids": len(all_solids), "tokens": len(tokens), "length": total, "time": total / CRUISE,
		"room_min": room[worst], "room_at": (line[worst][1], line[worst][0]),
		"token_clear_min": min(tok_clear),
		"turn_peak": max(r[0] for r in rows) / TURN_RATE, "pitch_peak": max(r[1] for r in rows) / PITCH_SPEED,
		"turn_mean": yaw_sum / total / TURN_RATE, "pitch_mean": pit_sum / total / PITCH_SPEED,
		"still": still / total, "longest": longest / CRUISE, "yaw_share": yaw_sum / max(yaw_sum + pit_sum, 1e-9),
		"thread": sum(thread) / n, "early": early,
		"x": (min(xs), max(xs)), "y": (min(ys), max(ys)), "z": (min(zs), max(zs)),
	}
	print("%-12s %3d solids %2d tokens  %5.0f m %5.1f s  room min %5.2f (gap %d)  token clear %4.1f  turn %.2f/%.2f  pitch %.2f/%.2f  still %3.0f%% longest %.2f s  sideways %3.0f%%  thread %3.0f%%  x %.0f..%.0f y %.0f..%.0f z %.0f..%.0f%s" % (
		out["id"], out["solids"], out["tokens"], total, out["time"], out["room_min"], out["room_at"][0], out["token_clear_min"],
		out["turn_peak"], out["turn_mean"], out["pitch_peak"], out["pitch_mean"], out["still"] * 100, out["longest"], out["yaw_share"] * 100,
		out["thread"] * 100, out["x"][0], out["x"][1], out["y"][0], out["y"][1], out["z"][0], out["z"][1],
		("  EARLY MISS %s" % early) if early else ""))
	if gaps:
		for g in range(len(tokens)):
			idx = [i for i in range(n - 1) if line[i][1] == g]
			if not idx: continue
			print("   gap %2d -> token %2d at (%6.1f %5.1f %6.1f)  turn %.2f  pitch %.2f  room %5.2f  thread %3.0f%%  token clear %4.1f" % (
				g, g, tokens[g][0], tokens[g][1], tokens[g][2], max(rows[i][0] for i in idx) / TURN_RATE,
				max(rows[i][1] for i in idx) / PITCH_SPEED, min(room[i] for i in idx), 100.0 * sum(thread[i] for i in idx) / len(idx), tok_clear[g]))
	return out


# --- The stations ---------------------------------------------------------------------

def helix(centre, r_of, y_of, a0, a1, count):
	"""Points round `centre` (x, z) turning left as a increases: a = 0 is
	east of the centre, heading north."""
	out = []
	for i in range(count + 1):
		a = a0 + (a1 - a0) * i / count
		r = r_of(a)
		out.append((centre[0] + r * math.cos(a), y_of(a), centre[1] - r * math.sin(a)))
	return out


class Line:
	"""The design line, with where each metre of it is: `at(s)` gives the
	point s m along it from the entry, its way, and its level right."""

	def __init__(self, ctrl):
		self.pts = design(ctrl)
		self.s = [0.0]
		for i in range(1, len(self.pts)): self.s.append(self.s[-1] + length(sub(self.pts[i], self.pts[i - 1])))
		self.length = self.s[-1]

	def at(self, s):
		i = max(1, min(len(self.pts) - 1, next((k for k in range(1, len(self.s)) if self.s[k] >= s), len(self.s) - 1)))
		t = (s - self.s[i - 1]) / max(self.s[i] - self.s[i - 1], 1e-9)
		p = lerp(self.pts[i - 1], self.pts[i], max(0.0, min(1.0, t)))
		way = norm(sub(self.pts[i], self.pts[i - 1]))
		right = norm((-way[2], 0.0, way[0]))
		return p, way, right

	def tokens(self, step, first, last=None):
		return [tuple(round(v, 2) for v in p) for p in resample(self.pts, step, first, last)]

	# Masses placed against the line at s m along it. `side` +1 right, -1 left.
	def under_rim(self, s, side, radius, overhang, keel, ceiling=2.4):
		"""An islet beside the line whose rim reaches `overhang` m over it:
		the line ducks under its edge, its keel's top drum `ceiling` m over
		the line (so the top is that, the drum and ISLE_TOP over it)."""
		p, _, r = self.at(s)
		c = add(p, mul(r, side * (radius - overhang)))
		above = ISLE_TOP + (keel - ISLE_TOP) / len(KEEL_TIERS) + ceiling
		return ("isle", (c[0], p[1] + above, c[2]), radius, keel)

	def beside(self, s, side, radius, gap, top, keel):
		"""An islet beside the line, its rim `gap` m off it, its top `top` m
		over the line's height there (flown round, at its flank)."""
		p, _, r = self.at(s)
		c = add(p, mul(r, side * (radius + gap)))
		return ("isle", (c[0], p[1] + top, c[2]), radius, keel)

	def under_keel(self, s, radius, clear, keel, off=0.0):
		"""An islet over the line, its keel's tip `clear` m over it."""
		p, _, r = self.at(s)
		c = add(p, mul(r, off))
		return ("isle", (c[0], p[1] + clear + keel, c[2]), radius, keel)

	def span_over(self, s, half, under, sag, width=2.4, skew=0.0, tilt=0.0):
		"""A rope span across the line at s, its deck `under` m over the line
		at the crossing (its sag counted), `half` m either side, turned
		`skew` rad from square, its ends `tilt` m apart in height."""
		p, way, r = self.at(s)
		c, sn = math.cos(skew), math.sin(skew)
		d = norm(add(mul(r, c), mul((way[0], 0.0, way[2]), sn)))
		mid_y = p[1] + under + sag
		a = add((p[0], mid_y, p[2]), mul(d, -half))
		b = add((p[0], mid_y, p[2]), mul(d, half))
		return ("span", (a[0], a[1] - tilt * 0.5, a[2]), (b[0], b[1] + tilt * 0.5, b[2]), width, sag), (a, b)

	def near_s(self, point):
		"""The s of the line's sample nearest `point`."""
		i = min(range(len(self.pts)), key=lambda k: length(sub(self.pts[k], point)))
		return self.s[i]

	def stacks(self, s, gap, radius, height, rise=0.0):
		"""Two floating rock stacks either side of the line, their faces `gap`
		m off it: a gate of rock to fly between."""
		p, _, r = self.at(s)
		out = []
		for side in (-1.0, 1.0):
			c = add(p, mul(r, side * (gap + radius)))
			out.append(("rock", (c[0], p[1] + rise, c[2]), radius, height))
		return out

	def bore_along(self, s0, s1, seg, width, height, wall, lift=0.0):
		"""A tunnel round the line from s0 to s1, in stretches of about `seg`
		m that follow its way, the opening's middle `lift` m over the line."""
		count = max(1, round((s1 - s0) / seg))
		step = (s1 - s0) / count
		out = []
		for i in range(count):
			a, _, _ = self.at(s0 + i * step)
			b, _, _ = self.at(s0 + (i + 1) * step)
			d = sub(b, a)
			# Each stretch reaches back into the one before, so the outside
			# of a bend has no chink.
			back = 0.6 if i > 0 else 0.0
			start = sub(a, mul(norm(d), back))
			out.append(("bore", (start[0], start[1] + lift, start[2]), round(heading_of(d), 4), round(pitch_of(d), 4),
				round(length(d) + back, 2), width, height, wall))
		return out


def weave_ctrl(total, side, half, rise, ramp, curl=0.0, step=4.0, start=6.0, bend=0.0):
	"""Control points for a corkscrew weave north from the entry: across
	side*sin, up rise*cos (half a beat later, so one axis turns hardest where
	the other has levelled), both grown in over `ramp` m so the line leaves
	the entry level and straight on; `curl` rad/m bends the whole weave
	(+ left), and `bend` rad/m more at the entry, fading out over the ramp,
	so the line is already turning while the weave grows in. Crossings
	(across 0) at start + k*half, peaks between."""
	out = [(0.0, 0.0, LEAD_IN)]
	yaw, x, z, s = 0.0, 0.0, 0.0, 0.0
	while s <= total + 1e-6:
		yaw += bend * max(0.0, 1.0 - s / ramp) * step if ramp > 0.0 else 0.0
		g = min(1.0, s / ramp) if ramp > 0.0 else 1.0
		g = g * g * (3.0 - 2.0 * g)
		ph = math.pi * (s - start) / half
		across = g * side * math.sin(ph)
		up = g * rise * math.cos(ph)
		r = (math.cos(yaw), -math.sin(yaw))
		out.append((x + r[0] * across, up, z + r[1] * across))
		x += -math.sin(yaw) * step
		z += -math.cos(yaw) * step
		yaw += curl * step
		s += step
	return out


def sky_weave():
	"""An islet weave: the line is a lazy corkscrew through a scatter of
	floating islets. At each swing out it rounds an islet on the inside of
	the bend, at its flank or under its rim (an `under` pass); where it
	crosses back it ducks under a hanging keel at the bottom of the bob, or
	threads the gap between a pair's edges at the top (an `air` gap)."""
	half = 38.0
	L = Line(weave_ctrl(220.0, 5.0, half, 2.0, 55.0, curl=0.003, bend=-0.01))
	peak = lambda k: 6.0 + half * (k - 0.5)
	cross = lambda k: 6.0 + half * k
	# The inside of the bend at peak k: swinging right on odd peaks, so
	# the inside is the left.
	inside = lambda k: -1 if k % 2 == 1 else 1
	parts = [
		L.beside(peak(1), inside(1), 6.0, 3.0, 0.5, 8.0),
		L.under_keel(cross(1), 9.0, 3.6, 9.0),
		L.under_rim(peak(2), inside(2), 10.0, 2.6, 10.0),
		L.beside(cross(2), -1, 5.0, 3.4, 1.0, 7.0), L.beside(cross(2), 1, 6.0, 3.4, 1.5, 8.0),
		L.beside(peak(3), inside(3), 7.0, 3.0, 1.0, 9.0),
		L.under_keel(cross(3), 11.0, 3.6, 10.0),
		L.under_rim(peak(4), inside(4), 11.0, 2.8, 11.0),
		L.beside(cross(4), -1, 6.0, 3.0, 1.5, 8.0), L.beside(cross(4), 1, 5.0, 3.0, 0.5, 7.0),
		L.beside(peak(5), inside(5), 6.0, 3.0, 0.5, 8.0),
		# The last crossing: under a big isle's keel and away.
		L.under_keel(cross(5), 14.0, 3.6, 12.0),
	]
	return {"id": "sky_weave", "name": "Islet weave (round islets, under rims and keels, between pairs)", "intent": "easy",
		"ease": 1.25, "parts": parts, "tokens": L.tokens(10.0, 11.0, cross(5) + 20.0)}


def sky_spans():
	"""A chain of spans: five islands down a long curve, on alternate sides,
	each tied to the next by a sagging rope bridge that crosses the way. The
	line weaves round each island's flank (out of the chain) and back in under
	the next bridge (an `air` line under a bridge), five times, the bridges
	stepping up and down so the line rises and falls with them."""
	half = 36.0
	side = 6.5
	L = Line(weave_ctrl(230.0, side, half, 2.4, 55.0, curl=-0.0035))
	peak = lambda k: 6.0 + half * (k - 0.5)
	cross = lambda k: 6.0 + half * k
	inside = lambda k: -1 if k % 2 == 1 else 1
	# The islands at the peaks, the line round their flanks; the third one
	# hangs lower and the line ducks under its rim instead.
	isles = []
	for k in range(1, 7):
		p, _, r = L.at(peak(k))
		if k == 3:
			isles.append(L.under_rim(peak(k), inside(k), 10.0, 2.4, 10.0))
		else:
			radius = (8.0, 9.0, 0, 8.5, 9.5, 8.0)[k - 1]
			isles.append(L.beside(peak(k), inside(k), radius, 3.2, 3.0, 10.0))
	parts = list(isles)
	# A bridge from each island to the next. Where it crosses the line its
	# deck must stand UNDER m over it: the islands are raised until it does
	# (twice round, as each island holds two bridges).
	sag, under = 0.9, 3.6
	tops = [i[1][1] for i in isles]
	ends = []
	for k in range(1, 6):
		ca, cb = isles[k - 1][1], isles[k][1]
		d = norm(sub((cb[0], 0.0, cb[2]), (ca[0], 0.0, ca[2])))
		ends.append((add((ca[0], 0.0, ca[2]), mul(d, isles[k - 1][2] - 0.6)), add((cb[0], 0.0, cb[2]), mul(d, -(isles[k][2] - 0.6)))))
	def crossing(ea, eb):
		best = None
		for i in range(41):
			t = i / 40.0
			q = lerp(ea, eb, t)
			s = L.near_s(q)
			p, _, _ = L.at(s)
			flat = math.hypot(p[0] - q[0], p[2] - q[2])
			if best is None or flat < best[0]: best = (flat, t, p[1])
		return best
	cross_at = [crossing(*e) for e in ends]
	for _ in range(3):
		for k in range(5):
			_, t, line_y = cross_at[k]
			deck = tops[k] + (tops[k + 1] - tops[k]) * t - 4.0 * sag * t * (1.0 - t)
			short = line_y + under - deck
			if short > 0.0:
				tops[k] += short
				tops[k + 1] += short
	parts = []
	for k, i in enumerate(isles):
		parts.append(("isle", (i[1][0], round(tops[k], 2), i[1][2]), i[2], i[3] + (tops[k] - i[1][1]) * 0.5))
	for k, (ea, eb) in enumerate(ends):
		parts.append(("span", (ea[0], round(tops[k], 2), ea[2]), (eb[0], round(tops[k + 1], 2), eb[2]), 2.4, sag))
	return {"id": "sky_spans", "name": "Chain of spans (round each island, back in under each rope bridge)", "intent": "medium",
		"parts": parts, "tokens": L.tokens(10.0, 11.0, peak(6))}


def sky_pierced():
	"""The pierced isle: the line dips under a small islet's keel, swings
	into a tunnel mouth under a big isle's rim, through the rock on a long
	climbing right bend, out into the open, round in a wide falling turn
	(leaving it) and back in under its hanging keel, then west through the
	veil between two islands' edges and up away."""
	level = 1.5
	mouth, out = (-2.0, level, -61.0), (13.5, level, -109.0)
	ctrl = [(0.0, 0.0, LEAD_IN), (0.0, 0.0, 0.0), (2.5, -1.5, -16.0), (2.5, -3.0, -30.0), (1.0, -1.5, -46.0),
		mouth,
		# The bore: a long S, left then right, level.
		(-5.5, level, -73.0), (-6.5, level, -85.0), (-3.0, level, -96.0), (4.0, level, -104.0), out,
		# Out, round to the right and falling (leaving the isle).
		(25.0, 1.0, -114.0), (37.0, -0.5, -117.0), (48.0, -2.5, -111.0), (53.0, -5.0, -99.0),
		(51.0, -7.5, -87.0), (43.0, -10.0, -78.0), (31.0, -13.0, -75.0),
		# Back in under its keel, west.
		(18.0, -15.5, -77.0), (5.0, -16.5, -80.0), (-8.0, -16.5, -82.0), (-20.0, -14.5, -81.0),
		# The veil between two islands' edges, then up and away.
		(-32.0, -11.0, -79.0), (-44.0, -8.5, -78.0), (-56.0, -6.0, -81.0), (-68.0, -3.5, -79.0)]
	L = Line(ctrl)
	parts = [L.under_keel(30.0, 6.5, 3.6, 8.0)]
	s0, s1 = L.near_s(mouth), L.near_s(out)
	width, height, wall = 9.0, 7.0, 5.0
	parts += L.bore_along(s0, s1, 7.0, width, height, wall, lift=0.5)
	# The isle round the bore: a broad flat top resting on its roof that
	# reaches out over both mouths (in from under the rim), and a hanging
	# keel under its floor.
	mid, _, _ = L.at((s0 + s1) * 0.5)
	roof = level + 0.5 + height * 0.5 + wall
	floor = level + 0.5 - height * 0.5 - wall
	centre = (mid[0] - 2.0, mid[2])
	parts.append(("rock", (centre[0], roof + 2.0, centre[1]), 24.0, 4.0))
	parts.append(("isle", (centre[0], floor, centre[1]), 20.0, 7.0))
	# The veil: two islands, their edges 3.2 m either side of the way.
	sv = L.near_s((-32.0, -11.0, -79.0))
	parts.append(L.beside(sv, -1, 9.0, 3.2, 2.5, 11.0))
	parts.append(L.beside(sv + 2.0, 1, 8.0, 3.2, 3.5, 10.0))
	# Out on the loop: under the rim of an outrider islet, then between two
	# stacks, so leaving the isle is still threading.
	parts.append(L.under_rim(L.near_s((37.0, -0.5, -117.0)), -1, 8.0, 2.4, 8.0))
	parts += L.stacks(L.near_s((51.0, -7.5, -87.0)), 3.4, 2.4, 12.0, rise=-1.0)
	return {"id": "sky_pierced", "name": "Pierced isle (a tunnel in from under the rim, round and back under the keel, the veil)", "intent": "medium",
		"miss_near": 10.0, "parts": parts, "tokens": L.tokens(10.0, 11.0, L.length - 14.0)}


def sky_spire():
	"""A spire spiral: a tall floating spire, the line climbing round it one
	and a quarter times, in under three ledges that jut from it (`under`),
	out under rope spans to two outrider islets, then off past a crown
	islet: the game's spire `air` line, as a whole climb."""
	cx, cz = -30.0, -20.0
	turns = 2.5 * math.pi
	climb = 30.0
	def r_of(a): return 24.0 + 4.0 * math.cos(2.0 * a)
	def y_of(a): return climb * max(0.0, a) / turns
	def on(a): return (cx + r_of(a) * math.cos(a), y_of(a), cz - r_of(a) * math.sin(a))
	pts = helix((cx, cz), r_of, y_of, 0.3, turns, 32)
	first = next(i for i, p in enumerate(pts) if p[2] < -8.0)
	ctrl = [(0.0, 0.0, 10.0), (0.0, 0.0, 0.0)] + pts[first:]
	L = Line(ctrl)
	parts = [("rock", (cx, 4.0, cz), 5.0, 68.0)]
	# A ledge jutting from the spire over each pinch.
	for a in (0.5 * math.pi, 1.5 * math.pi, 2.5 * math.pi - 0.3):
		parts.append(L.under_rim(L.near_s(on(a)), -1, 10.0, 2.6, 9.0))
	# Out wide at each bulge, under a span from a ledge on the spire to an
	# outrider islet.
	for a in (math.pi, 2.0 * math.pi):
		span, (inner, outer) = L.span_over(L.near_s(on(a)), 11.0, 3.6, 0.8)
		out = norm(sub(outer, inner))
		parts.append(("isle", add(inner, mul(out, -3.0)), 3.5, 6.0))
		parts.append(("isle", add(outer, mul(out, 5.5)), 6.5, 9.0))
		parts.append(span)
	# Between, a gate of two stacks.
	for a in (0.75 * math.pi, 1.25 * math.pi, 1.75 * math.pi, 2.25 * math.pi):
		parts += L.stacks(L.near_s(on(a)), 3.4, 2.2, 12.0, rise=-1.0)
	return {"id": "sky_spire", "name": "Spire spiral (round a floating spire: under its ledges, between stacks, under spans)", "intent": "easy",
		"ease": 1.25, "miss_near": 16.0, "parts": parts, "tokens": L.tokens(9.0, 10.0)}


STATIONS = [sky_weave, sky_spire, sky_spans, sky_pierced]


# --- Writing --------------------------------------------------------------------------

def gd_v(v):
	return "Vector3(%.2f,%.2f,%.2f)" % v


def gd_value(v):
	if isinstance(v, tuple) and len(v) == 3 and all(isinstance(x, (int, float)) for x in v): return gd_v(v)
	if isinstance(v, str): return '"%s"' % v
	if isinstance(v, float):
		s = ("%.3f" % v).rstrip("0")
		return s + "0" if s.endswith(".") else s
	if isinstance(v, int): return "%d.0" % v
	raise TypeError(v)


def gd_station(st):
	head = '\t{"id":"%s","key":NO_KEY,"pack":PACK,"name":"%s","intent":"%s"' % (st["id"], st["name"], st["intent"])
	for k in ("ease", "miss_near"):
		if k in st: head += ',"%s":%s' % (k, gd_value(float(st[k])))
	lines = [head + ',"parts":[']
	for p in st["parts"]:
		lines.append('\t\t["%s",%s],' % (p[0], ",".join(gd_value(float(x) if isinstance(x, int) else x) for x in p[1:])))
	lines.append('\t],"tokens":[')
	toks = st["tokens"]
	for i in range(0, len(toks), 4):
		lines.append("\t\t" + ",".join(gd_v(t) for t in toks[i:i + 4]) + ",")
	lines.append("\t]},")
	return "\n".join(lines)


def write(stations, path=PATH):
	with open(path) as f: text = f.read()
	block = BEGIN + "\nconst STATIONS := [\n" + "\n".join(gd_station(s) for s in stations) + "\n]\n" + END
	new, n = re.subn(re.escape(BEGIN) + r".*?" + re.escape(END), lambda _: block, text, flags=re.S)
	if n != 1: sys.exit("markers not found in %s" % path)
	with open(path, "w") as f: f.write(new)
	print("wrote %d stations to %s" % (len(stations), path))


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--check", action="store_true")
	ap.add_argument("--write", action="store_true")
	ap.add_argument("--station", default="all")
	ap.add_argument("--gaps", action="store_true")
	args = ap.parse_args()
	built = [f() for f in STATIONS]
	pick = [s for s in built if args.station in ("all", s["id"])]
	if args.check or not args.write:
		for s in pick: check(s, args.gaps)
	if args.write: write(built)


if __name__ == "__main__":
	main()
