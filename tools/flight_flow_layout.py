#!/usr/bin/env python3
"""Lays out the `sundered_flow` station (scripts/flight_course.gd) and prints
its parts and tokens as GDScript, to paste into FlightCourse.STATIONS.

The line is designed first and the hall stood round it. Each hall piece is
a run of greybox bays (FlightCourse `_bay`) along a curving nave (its yaw
changes by `kappa` rad per metre; the real hall's radius is >= 70 m).
Inside a piece the line is a slow corkscrew in the nave's own frame,

    across(s) = side * sin(W (s - s0))          (m, + the right)
    up(s)     = MID_Y + RISE * cos(W (s - s0))  (m over the piece's floor)

with W = pi / HALF (from one tie to the next). The sideways swing is
largest where the height is level and the climb steepest where the line
crosses the nave, so the flown direction never stops swinging (the user:
continuous movement, not straight, climb, straight, drop, straight). The
ties sit where the line crosses the nave's middle at its top (a high tie
flown over) and bottom (a low tie flown under); inner columns stand at the
bay lines where the line is out to one side, so it weaves round them. The
nave's own curve keeps the direction turning even at the crossings.
Between the pieces the line is a cubic Hermite swoop that turns and drops
at once. Piece B's last stretch climbs out through the apse's open roof
while the line still weaves and the nave still curves (a climbing turn).

  python3 tools/flight_flow_layout.py            # GDScript to paste
  python3 tools/flight_flow_layout.py --check    # the line's rates at cruise, per token
  python3 tools/flight_flow_layout.py --station mix [--check | --write]   # round 4, below
"""
import argparse
import math

BAY = 8.0
HALF = 24.0
W = math.pi / HALF
MID_Y = 5.4
RISE = 3.0
SIDE = 4.0
CRUISE = 14.0
TURN_RATE = 1.6
PITCH_SPEED = 1.4

# Piece A: 9 bays curving left (radius RA); piece B: 6 bays curving right
# (radius RB), DROP m lower, turned right by B_TURN from A's end, its line
# starting GAP m (straight-line) on from A's.
RA = 110.0
RB = 80.0
DROP = 5.0
B_TURN = 0.75
GAP = 20.0
A_IN = -16.0          # the entry, m before A's gate line: the corkscrew's low point, level
A_OUT = 72.0          # A's line ends at its far (torn) bay line
B_IN = -8.0           # B's line starts 8 m before its torn mouth
B_CLIMB = 8.0         # B climbs from its low tie on, out of the apse roof
B_CLIMB_LEN = 64.0
B_TOP = 20.4
B_OUT = 56.0


def fwd(yaw):
	return (-math.sin(yaw), -math.cos(yaw))


def right(yaw):
	return (math.cos(yaw), -math.sin(yaw))


class Piece:
	"""A hall piece: its first bay line's middle on its floor, its yaw there,
	its curvature (rad/m, + to the left), its bays."""

	def __init__(self, x, floor, z, yaw, kappa, bays):
		self.x, self.floor, self.z, self.yaw, self.kappa, self.bays = x, floor, z, yaw, kappa, bays

	def frame(self, s):
		if abs(self.kappa) < 1e-9:
			f = fwd(self.yaw)
			return (self.x + f[0] * s, self.z + f[1] * s), self.yaw
		y1 = self.yaw + self.kappa * s
		x = self.x + (math.cos(y1) - math.cos(self.yaw)) / self.kappa
		z = self.z + (-math.sin(y1) + math.sin(self.yaw)) / self.kappa
		return (x, z), y1

	def point(self, s, across, up):
		(cx, cz), yaw = self.frame(s)
		r = right(yaw)
		return (cx + r[0] * across, self.floor + up, cz + r[1] * across)

	def bay_line(self, i):
		(ax, az), _ = self.frame(i * BAY)
		(bx, bz), _ = self.frame((i + 1) * BAY)
		return (ax, self.floor, az), math.atan2(-(bx - ax), -(bz - az))


def a_local(s):
	ph = W * (s - 8.0)
	return SIDE * math.sin(ph), MID_Y + RISE * math.cos(ph)


def b_local(s):
	ph = W * (s + 16.0)
	across = -SIDE * math.sin(ph)
	if s <= B_CLIMB:
		return across, MID_Y + RISE * math.cos(ph)
	low = MID_Y - RISE
	return across, low + 0.5 * B_TOP * (1.0 - math.cos(math.pi * (s - B_CLIMB) / B_CLIMB_LEN))


def tangent(piece, local, s, h=0.05):
	a = piece.point(s - h, *local(s - h))
	b = piece.point(s + h, *local(s + h))
	d = [b[i] - a[i] for i in range(3)]
	n = math.sqrt(sum(v * v for v in d))
	return [v / n for v in d]


def build():
	A = Piece(0.0, 0.0, 0.0, 0.0, 1.0 / RA, 9)
	p = A.point(A_IN, *a_local(A_IN))
	A.x, A.floor, A.z = -p[0], -p[1], -p[2]
	out_p = A.point(A_OUT, *a_local(A_OUT))
	out_t = tangent(A, a_local, A_OUT)
	(_, _), a_yaw = A.frame(A_OUT)
	b_yaw = a_yaw - B_TURN
	B = Piece(0.0, A.floor - DROP, 0.0, b_yaw, -1.0 / RB, 6)
	# Put B's line start GAP m on from A's end, along the mean of A's way
	# out and B's way in.
	q = B.point(B_IN, *b_local(B_IN))
	in_t = tangent(B, b_local, B_IN)
	ha = math.atan2(-out_t[0], -out_t[2])
	hb = math.atan2(-in_t[0], -in_t[2])
	f = fwd((ha + hb) * 0.5)
	target = (out_p[0] + f[0] * GAP, 0.0, out_p[2] + f[1] * GAP)
	B.x += target[0] - q[0]
	B.z += target[2] - q[2]
	in_p = B.point(B_IN, *b_local(B_IN))
	# Turn the whole station round the entry so the line leaves it heading
	# north (-z), as the plane is set down.
	t0 = tangent(A, a_local, A_IN)
	turn = -math.atan2(-t0[0], -t0[2])
	for piece in (A, B):
		piece.x, piece.z = spin(piece.x, piece.z, turn)
		piece.yaw += turn
	out_p, in_p = spin3(out_p, turn), spin3(in_p, turn)
	out_t, in_t = spin3(out_t, turn), spin3(in_t, turn)
	return A, B, out_p, out_t, in_p, in_t


def spin(x, z, a):
	"""(x, z) turned by `a` round y, as Basis(Vector3.UP, a) turns it."""
	return x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a)


def spin3(p, a):
	x, z = spin(p[0], p[2], a)
	return (x, p[1], z)


def hermite(p0, t0, p1, t1, u, scale):
	h00 = 2 * u ** 3 - 3 * u ** 2 + 1
	h10 = u ** 3 - 2 * u ** 2 + u
	h01 = -2 * u ** 3 + 3 * u ** 2
	h11 = u ** 3 - u ** 2
	return tuple(h00 * p0[i] + h10 * scale * t0[i] + h01 * p1[i] + h11 * scale * t1[i] for i in range(3))


def line_and_tokens():
	A, B, out_p, out_t, in_p, in_t = build()
	chord = math.dist(out_p, in_p)
	pts, tokens = [], []
	s = A_IN
	while s < A_OUT:
		pts.append(A.point(s, *a_local(s)))
		s += 0.5
	for s in range(0, int(A_OUT) + 1, 8):  # the first at the gate, 16 m in
		tokens.append(A.point(s, *a_local(s)))
	n = 40
	gap_tokens = 2
	for i in range(n):
		pts.append(hermite(out_p, out_t, in_p, in_t, i / n, chord))
	for k in range(1, gap_tokens + 1):
		tokens.append(hermite(out_p, out_t, in_p, in_t, k / (gap_tokens + 1), chord))
	s = B_IN
	while s <= B_OUT:
		pts.append(B.point(s, *b_local(s)))
		s += 0.5
	for s in range(int(B_IN), int(B_OUT) + 1, 8):
		tokens.append(B.point(s, *b_local(s)))
	return A, B, pts, tokens


def plans():
	# Piece A: gate, high tie, weave round the middle columns, low tie, the
	# cloister's open bays, high tie, torn end.
	a = [
		{"roof": "whole", "inner": []},
		{"roof": "whole", "tie": "high", "inner": []},
		{"roof": "broken", "gaps": [3, 4], "inner": [0.0]},
		{"roof": "whole", "inner": [0.0]},
		{"roof": "whole", "tie": "low", "inner": []},
		{"roof": "broken", "gaps": [2, 3], "inner": [0.0]},
		{"roof": "open", "inner": [0.0], "breach": ["arch", ""]},
		{"roof": "open", "tie": "high", "inner": []},
		{"roof": "open", "beam": False, "torn": 2, "last": True, "inner": [0.0]},
	]
	# Piece B: torn mouth, low tie, the slit act (screens on the left, the
	# line weaving out right of them), high tie, the apse open to the sky.
	b = [
		{"roof": "open", "torn": 1, "inner": []},
		{"roof": "whole", "tie": "low", "inner": []},
		{"roof": "broken", "gaps": [1, 2], "screen": True, "inner": [-2.6]},
		{"roof": "whole", "screen": True, "inner": [-2.6]},
		{"roof": "open", "tie": "high", "beam": False, "inner": []},
		{"roof": "open", "beam": False, "torn": 2, "last": True, "inner": []},
	]
	return a, b


def gd_value(v):
	if isinstance(v, bool):
		return "true" if v else "false"
	if isinstance(v, str):
		return f'"{v}"'
	if isinstance(v, float):
		return f"{v:.1f}" if abs(v - round(v, 1)) < 1e-9 else f"{v:.3f}"
	if isinstance(v, int):
		return str(v)
	if isinstance(v, list):
		return "[" + ",".join(gd_value(x) for x in v) + "]"
	raise TypeError(v)


def gd_plan(plan):
	return "{" + ",".join(f'"{k}":{gd_value(v)}' for k, v in plan.items()) + "}"


def v3(p):
	return "Vector3(%s)" % ",".join(f"{round(c, 2):.2f}" for c in p)


def rates(pts):
	out = []
	for i in range(1, len(pts) - 1):
		a = [pts[i][k] - pts[i - 1][k] for k in range(3)]
		b = [pts[i + 1][k] - pts[i][k] for k in range(3)]
		ya = math.atan2(-a[0], -a[2]); yb = math.atan2(-b[0], -b[2])
		pa = math.atan2(a[1], math.hypot(a[0], a[2])); pb = math.atan2(b[1], math.hypot(b[0], b[2]))
		ds = 0.5 * (math.dist(pts[i - 1], pts[i]) + math.dist(pts[i], pts[i + 1]))
		dy = (yb - ya + math.pi) % (2 * math.pi) - math.pi
		out.append((dy / ds * CRUISE, (pb - pa) / ds * CRUISE))
	return out


# ---------------------------------------------------------------------------
# Round 4: a line built from move segments (`sundered_mix`).
#
# The user liked the corkscrew hall but wants a mix of moves: side to side,
# up and down, corkscrew, and the knife edge (Q/E) through the slits. Here a
# piece's line is a run of SEGMENTS, each a move with its own rhythm. Every
# move is the same machine, a pair of alternating beats in the nave's own
# frame: `across` swings between +side and -side (each beat an extreme,
# `half` m apart) and `up` swings round `mid` by `rise`, its beats half a
# beat later (90 degrees out of phase, so one axis is turning hardest where
# the other has levelled off and the line never settles). A natural cubic
# spline through each axis's beats joins the segments with no corner and no
# flat: a new segment only changes the size and spacing of the beats to come.
#
#   weave      side-to-side between the columns: big `side`, a small `rise`
#              (a bob) that keeps the line moving where the weave crosses
#   wave       up and down over and under the ties: big `rise`, a small
#              `side` (a sway)
#   corkscrew  both, as round 3 (side 4, rise 3, half 24)
#   knife      the next across beat is the slit (SLIT_ACROSS, left of the
#              nave, on a bay line with a screen) and the next up beat lands
#              on it too at SLIT_UP, so the line swings into the slit from
#              the right, threads it at the bottom of a dip, and swings out;
#              a positive beat is put in first if the rhythm is the wrong
#              way round. The slit is 1.15 m (the real kit's KNIFE): on edge
#              the plane is 0.3 m thick and 1.4 m tall, so it clears 0.42 m a
#              side and 0.95 m up and down; level, its wings don't fit.
#   climb      (a piece's `climb`) from the first up trough after `after`,
#              the height rises by `top` in a half cosine over `len` while
#              the across beats go on: out through an open roof
# A piece's nave curves by `kappa` (rad/m, + left) from the s given; a
# tighter `kappa` past the hall's end makes the climb-out a banked turn.
# Between pieces the line is the round-3 Hermite swoop, which turns `turn`
# rad right and drops `drop` m. The bays' plans follow the line (`auto_plan`):
# a screen where it threads a slit, a low tie where it dips under 4 m, a
# high tie where it crests over 6.9 m or ducks under 6 m, inner columns at
# the bay lines it swings wide of, roofs open where it rises past the beams
# and otherwise a whole/broken/open rhythm for openings.
#
#   python3 tools/flight_flow_layout.py --station mix --check
#   python3 tools/flight_flow_layout.py --station mix --write   # into flight_course.gd
# ---------------------------------------------------------------------------

SLIT_ACROSS = -6.0          # -(Hall.ROW_Z + Hall.INNER_Z) / 2
SLIT_UP = 2.65              # Hall.KNIFE.y + Hall.KNIFE.z / 2
LOW_TIE = (4.0, 4.9)        # soffit, top (Hall TIE_LOW, TIE_DEPTH)
HIGH_TIE = (6.0, 6.9)
BEAM_SOFFIT = 10.0          # Hall COLUMN_H
CLEAR = 0.7 + 0.6           # half the wingspan plus a margin
CLIMB_BLEND = 12.0          # m: the climb's hand-over from the beats
HOLD_EASE = 0.15            # m: the hold's half beats sit this far off the slit's line
MIN_BEAT = 10.0             # m: beats closer than this swing too hard

MIX = {
	"id": "sundered_mix", "key": 10,
	"name": "Sundered hall, mixed moves (weave, corkscrew, knife slits, wave, climbing turn)",
	"intent": "medium",
	"token_step": 8.0,      # a token every bay line ...
	"slit_tokens": 4.0,     # ... and one this far either side of a slit
	"pieces": [
		# Piece A, 11 bays curving left: a wide weave in from the gate, a
		# corkscrew, then a swing right-to-left into the first slit.
		{"bays": 11, "floor": 0.0, "kappa": [(-99.0, -1.0 / 70.0)], "entry": -16.0, "first_token": 0.0,
		 "start": {"up": -1, "across": -1},
		 "segments": [
			{"move": "weave", "len": 40.0, "half": 20.0, "side": 4.2, "rise": 0.5, "mid": 5.0},
			{"move": "corkscrew", "len": 40.0, "half": 20.0, "side": 3.6, "rise": 1.6, "mid": 5.2},
			{"move": "knife", "bay": 10, "approach": 28.0, "approach_up": 30.0, "hold": 8.0, "side_in": -1.5, "rise_in": 6.0},
			{"move": "weave", "exit": 22.0, "half": 18.0, "side": 1.5, "rise": 0.6, "mid": 5.0},
		 ],
		 "out": 88.0, "plans": {}},
		# The swoop between: a banked turn right, dropping 5 m.
		# Piece B, 11 bays curving right: a wave over and under the ties, a
		# quick weave, the second slit, then the climbing turn out of the
		# open roof, tightening past the hall's end.
		{"bays": 15, "drop": 5.0, "turn": -1.4, "gap": 24.0, "kappa": [(-99.0, -1.0 / 70.0), (120.0, 1.0 / 30.0)],
		 "in": -8.0, "first_token": -8.0,
		 "start": {"up": 1, "across": 1},
		 "segments": [
			{"move": "wave", "len": 46.0, "half": 22.5, "side": 1.5, "rise": 2.9, "mid": 5.4},
			{"move": "weave", "len": 40.0, "half": 16.0, "side": 3.0, "rise": 0.6, "mid": 5.0},
			{"move": "knife", "bay": 13, "approach": 26.0, "approach_up": 28.0, "hold": 8.0, "side_in": -0.5, "rise_in": 5.6},
			{"move": "weave", "exit": 22.0, "half": 18.0, "side": 3.0, "rise": 0.5, "mid": 5.0},
		 ],
		 "climb": {"after": 104.0, "len": 48.0, "top": 9.0},
		 "out": 130.0, "plans": {}},
	],
}


class Nave:
	"""A hall piece's nave: its first bay line's middle at (x, floor, z),
	its yaw there, its curvature (rad/m, + to the left) as steps
	[(from s, kappa), ...], integrated numerically."""

	STEP = 0.05

	def __init__(self, x, floor, z, yaw, kappa):
		self.x, self.floor, self.z, self.yaw, self.kappa = x, floor, z, yaw, kappa
		self._cache = {}

	def k(self, s):
		out = self.kappa[0][1]
		for at, k in self.kappa:
			if s >= at:
				out = k
		return out

	def frame(self, s):
		"""((x, z), yaw) of the nave's middle line at s."""
		n = int(round(abs(s) / self.STEP))
		h = self.STEP if s >= 0 else -self.STEP
		px, pz, yaw = 0.0, 0.0, 0.0
		key = (n, h > 0)
		if key in self._cache:
			px, pz, yaw = self._cache[key]
		else:
			u = 0.0
			for _ in range(n):
				mid_yaw = yaw + 0.5 * self.k(u + 0.5 * h) * h
				f = fwd(self.yaw + mid_yaw)
				px += f[0] * h
				pz += f[1] * h
				yaw += self.k(u + 0.5 * h) * h
				u += h
			self._cache[key] = (px, pz, yaw)
		return (self.x + px, self.z + pz), self.yaw + yaw

	def point(self, s, across, up):
		(cx, cz), yaw = self.frame(s)
		r = right(yaw)
		return (cx + r[0] * across, self.floor + up, cz + r[1] * across)

	def bay_line(self, i):
		(ax, az), _ = self.frame(i * BAY)
		(bx, bz), _ = self.frame((i + 1) * BAY)
		return (ax, self.floor, az), math.atan2(-(bx - ax), -(bz - az))


def natural_spline(knots):
	"""A natural cubic spline through [(s, v), ...] (s rising): a function of s."""
	xs = [k[0] for k in knots]
	ys = [k[1] for k in knots]
	n = len(xs)
	h = [xs[i + 1] - xs[i] for i in range(n - 1)]
	alpha = [0.0] * n
	for i in range(1, n - 1):
		alpha[i] = 3.0 / h[i] * (ys[i + 1] - ys[i]) - 3.0 / h[i - 1] * (ys[i] - ys[i - 1])
	l, mu, z = [1.0] + [0.0] * (n - 1), [0.0] * n, [0.0] * n
	for i in range(1, n - 1):
		l[i] = 2.0 * (xs[i + 1] - xs[i - 1]) - h[i - 1] * mu[i - 1]
		mu[i] = h[i] / l[i]
		z[i] = (alpha[i] - h[i - 1] * z[i - 1]) / l[i]
	l[n - 1] = 1.0
	c, b, d = [0.0] * n, [0.0] * n, [0.0] * n
	for j in range(n - 2, -1, -1):
		c[j] = z[j] - mu[j] * c[j + 1]
		b[j] = (ys[j + 1] - ys[j]) / h[j] - h[j] * (c[j + 1] + 2.0 * c[j]) / 3.0
		d[j] = (c[j + 1] - c[j]) / (3.0 * h[j])

	def f(s):
		j = 0
		while j < n - 2 and s > xs[j + 1]:
			j += 1
		u = s - xs[j]
		return ys[j] + b[j] * u + c[j] * u * u + d[j] * u ** 3
	return f


def beats(piece):
	"""The piece's across and up beats [(s, value)], and its slits' s, from
	its segments (see the header). A segment before a knife runs until
	`approach` m before the slit; then the knife makes sure the beat before
	the slit is a high one that far back (it drops a low beat too close to
	the slit, or adds a high one at `side_in` / `rise_in`)."""
	segs = piece["segments"]
	start = piece.get("entry", piece.get("in", 0.0))
	a_sign = piece.get("start", {}).get("across", 1)
	u_sign = piece.get("start", {}).get("up", -1)
	across, up, slits = [], [], []
	# The first up beat at the line's start (so it starts level), the first
	# across beat half a beat on.
	next_u = start
	next_a = start + 0.5 * segs[0]["half"]
	s0 = start
	for k, seg in enumerate(segs):
		if seg["move"] == "knife":
			slit = seg["bay"] * BAY
			for beats_, sign, approach, high, low in ((across, a_sign, seg["approach"], seg["side_in"], SLIT_ACROSS),
					(up, u_sign, seg.get("approach_up", seg["approach"]), seg["rise_in"], SLIT_UP)):
				if sign > 0:   # the beat before is a low one
					if beats_ and beats_[-1][0] > slit - seg["approach"] - MIN_BEAT and len(beats_) > 1:
						beats_.pop()
					else:
						beats_.append((slit - approach, high))
				# The beat before the slit swings only as far as `high`, so
				# the line is not still swinging hard as it threads it.
				beats_[-1] = (beats_[-1][0], min(beats_[-1][1], high))
				beats_.append((slit, low))
			# Sideways, the line runs in line with the slit for `hold` m
			# either side (half beats a hair off it, so the spline lies
			# flat): time to line up and roll on edge, while the dip
			# through the slit keeps it swinging.
			hold = seg.get("hold", 0.0)
			if hold > 0.0:
				across.insert(len(across) - 1, (slit - hold, SLIT_ACROSS + HOLD_EASE))
				across.append((slit + hold, SLIT_ACROSS + HOLD_EASE))
			slits.append(slit)
			a_sign, u_sign = 1, 1
			s0 = slit
			nxt = segs[k + 1]
			# Out of the slit both axes swing back, the height more slowly,
			# so they fall out of step again (in step, both would level off
			# at once: a straight).
			next_a = slit + seg.get("hold", 0.0) + nxt.get("exit", nxt["half"])
			next_u = slit + 1.5 * nxt["half"]
			continue
		end = s0 + seg.get("len", 0.0)
		end_a = end_u = end
		if k + 1 < len(segs) and segs[k + 1]["move"] == "knife":
			kn = segs[k + 1]
			end_a = kn["bay"] * BAY - kn["approach"] + 1e-6
			end_u = kn["bay"] * BAY - kn.get("approach_up", kn["approach"]) + 1e-6
			end = min(end_a, end_u)
		centre = seg.get("centre", 0.0)
		while next_a < end_a:
			across.append((next_a, centre + a_sign * seg["side"]))
			a_sign = -a_sign
			next_a += seg["half"]
		while next_u < end_u:
			up.append((next_u, seg["mid"] + u_sign * seg["rise"]))
			u_sign = -u_sign
			next_u += seg["half"]
		s0 = end
	# Beats on past the line's end, so the spline doesn't flatten (natural
	# ends) or run wild (past its last knot) inside the line.
	last = segs[-1]
	end = piece["out"] + MIN_BEAT
	while not across or across[-1][0] < end:
		across.append((next_a, last.get("centre", 0.0) + a_sign * last["side"]))
		a_sign = -a_sign
		next_a += last["half"]
	while not up or up[-1][0] < end:
		up.append((next_u, last["mid"] + u_sign * last["rise"]))
		u_sign = -u_sign
		next_u += last["half"]
	for name, bs in (("across", across), ("up", up)):
		for i in range(1, len(bs)):
			swing = abs(bs[i][1] - bs[i - 1][1]) > 1.0
			assert bs[i][0] > bs[i - 1][0] and (not swing or bs[i][0] - bs[i - 1][0] >= MIN_BEAT - 1e-6), f"{name} beats too close: {bs[i - 1]} {bs[i]}"
	return across, up, slits


class MixPiece:
	def __init__(self, spec):
		self.spec = spec
		self.across_beats, self.up_beats, self.slits = beats(spec)
		self.across = natural_spline(self.across_beats)
		up = natural_spline(self.up_beats)
		climb = spec.get("climb")
		if climb:
			troughs = [s for s, v in self.up_beats if s >= climb["after"] and v < min(spec["segments"][-1]["mid"], 9.0)]
			s_c = troughs[0]
			low = up(s_c)

			def climbing(s, up=up, s_c=s_c, low=low):
				if s <= s_c:
					return up(s)
				# The climb takes over from the beats over CLIMB_BLEND m.
				u = min(1.0, (s - s_c) / climb["len"])
				rise = low + 0.5 * climb["top"] * (1.0 - math.cos(math.pi * u))
				w = min(1.0, (s - s_c) / CLIMB_BLEND)
				w = w * w * (3.0 - 2.0 * w)
				return up(s) * (1.0 - w) + rise * w
			self.up = climbing
			self.climb_from = s_c
		else:
			self.up = up
			self.climb_from = None
		self.nave = None

	def local(self, s):
		return self.across(s), self.up(s)

	def point(self, s):
		return self.nave.point(s, *self.local(s))

	def tangent(self, s, h=0.05):
		a, b = self.point(s - h), self.point(s + h)
		d = [b[i] - a[i] for i in range(3)]
		n = math.sqrt(sum(v * v for v in d))
		return [v / n for v in d]


def mix_build(layout=MIX):
	pa, pb = (MixPiece(p) for p in layout["pieces"])
	sa, sb = pa.spec, pb.spec
	pa.nave = Nave(0.0, sa["floor"], 0.0, 0.0, sa["kappa"])
	p = pa.point(sa["entry"])
	pa.nave.x, pa.nave.floor, pa.nave.z = -p[0], sa["floor"] - p[1], -p[2]
	out_p, out_t = pa.point(sa["out"]), pa.tangent(sa["out"])
	_, a_yaw = pa.nave.frame(sa["out"])
	pb.nave = Nave(0.0, pa.nave.floor - sb["drop"], 0.0, a_yaw - sb["turn"], sb["kappa"])
	q, in_t = pb.point(sb["in"]), pb.tangent(sb["in"])
	ha = math.atan2(-out_t[0], -out_t[2])
	hb = math.atan2(-in_t[0], -in_t[2])
	f = fwd((ha + hb) * 0.5)
	target = (out_p[0] + f[0] * sb["gap"], out_p[2] + f[1] * sb["gap"])
	pb.nave.x += target[0] - q[0]
	pb.nave.z += target[1] - q[2]
	in_p = pb.point(sb["in"])
	# Turn the station round the entry so the line leaves it heading north.
	t0 = pa.tangent(sa["entry"])
	turn = -math.atan2(-t0[0], -t0[2])
	for piece in (pa, pb):
		piece.nave.x, piece.nave.z = spin(piece.nave.x, piece.nave.z, turn)
		piece.nave.yaw += turn
		piece.nave._cache = {}
	out_p, in_p = pa.point(sa["out"]), pb.point(sb["in"])
	out_t, in_t = pa.tangent(sa["out"]), pb.tangent(sb["in"])
	return pa, pb, out_p, out_t, in_p, in_t


def mix_line(layout=MIX):
	pa, pb, out_p, out_t, in_p, in_t = mix_build(layout)
	sa, sb = pa.spec, pb.spec
	chord = math.dist(out_p, in_p)
	pts, tokens, kinds = [], [], []
	step = layout["token_step"]

	def piece_tokens(piece, s_from, s_to):
		ss = []
		s = s_from
		while s <= s_to + 1e-6:
			ss.append(s)
			s += step
		for slit in piece.slits:
			ss += [slit - layout["slit_tokens"], slit + layout["slit_tokens"]]
		for s in sorted(set(round(v, 3) for v in ss)):
			if s_from - 1e-6 <= s <= s_to + 1e-6:
				tokens.append(piece.point(s))
				kinds.append("slit" if any(abs(s - k) < 1e-6 for k in piece.slits) else "")

	s = sa["entry"]
	while s < sa["out"]:
		pts.append(pa.point(s))
		s += 0.5
	piece_tokens(pa, sa["first_token"], sa["out"])
	n = 40
	gap_tokens = 2
	for i in range(n):
		pts.append(hermite(out_p, out_t, in_p, in_t, i / n, chord))
	for k in range(1, gap_tokens + 1):
		tokens.append(hermite(out_p, out_t, in_p, in_t, k / (gap_tokens + 1), chord))
		kinds.append("")
	s = sb["in"]
	while s <= sb["out"]:
		pts.append(pb.point(s))
		s += 0.5
	piece_tokens(pb, sb["first_token"], sb["out"])
	return pa, pb, pts, tokens, kinds


ROOFS = ["whole", "broken", "whole", "open", "broken", "whole"]


def auto_plan(piece, i, last):
	"""Bay i's plan from the line through it (see the header)."""
	s = i * BAY
	a, u = piece.local(s)
	top = max(piece.up(s + k * 0.5) for k in range(0, 17))
	plan = {}
	slit = any(abs(s - k) < 1e-6 for k in piece.slits)
	roof = ROOFS[i % len(ROOFS)]
	if top > BEAM_SOFFIT - CLEAR or (piece.climb_from is not None and s + BAY > piece.climb_from + 8.0):
		roof = "open"
	plan["roof"] = roof
	if roof == "broken":
		plan["gaps"] = [2, 3] if i % 2 else [3, 4]
	beam_ok = u < BEAM_SOFFIT - CLEAR
	if slit:
		plan["screen"] = True
		plan["inner"] = [-2.6]
	else:
		if u <= LOW_TIE[0] - CLEAR:
			plan["tie"] = "low"
		elif HIGH_TIE[1] + CLEAR <= u <= BEAM_SOFFIT - CLEAR:
			plan["tie"] = "high"
		elif CLEAR <= u <= HIGH_TIE[0] - CLEAR and i % 2 == 0:
			plan["tie"] = "high"
		inner = []
		if abs(a) >= 1.2 + CLEAR + 0.5:
			inner.append(0.0)
		if abs(a + 2.6) >= 1.2 + CLEAR + 0.8 and abs(a) >= 3.5 and a > 0:
			inner.append(-2.6)
		if abs(a - 2.6) >= 1.2 + CLEAR + 0.8 and abs(a) >= 3.5 and a < 0:
			inner.append(2.6)
		plan["inner"] = inner
	if not beam_ok or roof == "open" and i > 0 and piece.up(s) > BEAM_SOFFIT - CLEAR - 1.0:
		plan["beam"] = False
	if i == 0 and piece.spec.get("in") is not None:
		plan["torn"] = 1
	if last:
		# The piece ends torn: its far columns snapped, its walls low.
		plan["torn"] = 2
		plan["last"] = True
	plan.update(piece.spec.get("plans", {}).get(i, {}))
	return plan


def mix_station(layout=MIX):
	pa, pb, pts, tokens, kinds = mix_line(layout)
	lines = [f'\t{{"id":"{layout["id"]}","key":{layout["key"]},"name":"{layout["name"]}","intent":"{layout["intent"]}","parts":[']
	for piece in (pa, pb):
		n = piece.spec["bays"]
		for i in range(n):
			at, yaw = piece.nave.bay_line(i)
			lines.append(f'\t\t["bay",{v3(at)},{yaw:.4f},{gd_plan(auto_plan(piece, i, i == n - 1))}],')
	lines.append('\t],"tokens":[')
	for i in range(0, len(tokens), 4):
		lines.append("\t\t" + ",".join(v3(t) for t in tokens[i:i + 4]) + ",")
	lines.append("\t]},")
	return "\n".join(lines), pa, pb, pts, tokens, kinds


BEGIN = "\t# >>> sundered_mix: written by tools/flight_flow_layout.py --station mix --write"
END = "\t# <<< sundered_mix"


def write_station(text, path="scripts/flight_course.gd"):
	src = open(path).read()
	block = BEGIN + "\n" + text + "\n" + END
	if BEGIN in src:
		a = src.index(BEGIN)
		b = src.index(END) + len(END)
		src = src[:a] + block + src[b:]
	else:
		anchor = "\n]\n\n## The station with `id`"
		a = src.index(anchor)
		src = src[:a] + "\n" + block + src[a:]
	open(path, "w").write(src)


def segment_marks(layout=MIX):
	"""Where each move starts along its piece (s, m), as [(piece, move, s)]:
	a knife's swing in starts `approach` m before its slit and its own
	mark is the slit; the climb starts at its trough."""
	pa, pb = (MixPiece(p) for p in layout["pieces"])
	out = []
	for piece, name in ((pa, "A"), (pb, "B")):
		spec = piece.spec
		s = spec.get("entry", spec.get("in"))
		segs = spec["segments"]
		for k, seg in enumerate(segs):
			if seg["move"] == "knife":
				slit = seg["bay"] * BAY
				out.append((name, "knife in", slit - seg["approach"]))
				out.append((name, "knife slit", slit))
				s = slit + seg.get("hold", 0.0)
				continue
			if k > 0 and segs[k - 1]["move"] == "knife":
				out.append((name, seg["move"] + " (out)", s))
			else:
				out.append((name, seg["move"], s))
			s += seg.get("len", 0.0)
		if piece.climb_from is not None:
			out.append((name, "climb-turn", piece.climb_from))
		out.append((name, "end", spec["out"]))
	return out


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--check", action="store_true")
	ap.add_argument("--station", default="flow", choices=["flow", "mix"])
	ap.add_argument("--write", action="store_true", help="mix: write the station into scripts/flight_course.gd")
	args = ap.parse_args()
	if args.station == "mix":
		text, pa, pb, pts, tokens, kinds = mix_station()
		if args.check:
			check(pts, tokens)
			for piece, name in ((pa, "A"), (pb, "B")):
				print(f"{name} across beats", [(round(s, 1), round(v, 1)) for s, v in piece.across_beats])
				print(f"{name} up beats    ", [(round(s, 1), round(v, 1)) for s, v in piece.up_beats])
				print(f"{name} slits at s", piece.slits, "climb from", piece.climb_from)
			print("slit tokens", [i for i, k in enumerate(kinds) if k == "slit"])
			return
		if args.write:
			write_station(text)
			print("wrote sundered_mix into scripts/flight_course.gd")
			return
		print(text)
		return
	A, B, pts, tokens = line_and_tokens()
	a_plans, b_plans = plans()
	if args.check:
		check(pts, tokens)
		for t in tokens:
			print(v3(t))
		return
	print('\t{"id":"sundered_flow","key":0,"name":"Sundered hall, flowing (corkscrew nave, swoop, climbing turn)","intent":"medium","parts":[')
	for piece, ps in ((A, a_plans), (B, b_plans)):
		for i, plan in enumerate(ps):
			at, yaw = piece.bay_line(i)
			print(f'\t\t["bay",{v3(at)},{yaw:.4f},{gd_plan(plan)}],')
	print('\t],"tokens":[')
	for i in range(0, len(tokens), 4):
		print("\t\t" + ",".join(v3(t) for t in tokens[i:i + 4]) + ",")
	print("\t]},")


def check(pts, tokens):
	r = rates(pts)
	swing = [math.degrees(math.hypot(y, p)) for y, p in r]
	yaw = sum(abs(y) for y, _ in r)
	pit = sum(abs(p) for _, p in r)
	length = sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))
	print(f"line {length:.0f} m ({length / CRUISE:.1f} s at cruise), {len(tokens)} tokens")
	print(f"turn need peak {max(abs(y) for y, _ in r)/TURN_RATE:.2f}, pitch need peak {max(abs(p) for _, p in r)/PITCH_SPEED:.2f}")
	print(f"line swing deg/s: min {min(swing):.1f} mean {sum(swing)/len(swing):.1f}; still (<6) {sum(1 for s in swing if s < 6)/len(swing):.0%}; yaw share {yaw / (yaw + pit):.0%}")
	# Per second of line at cruise: the turn and pitch needs' peaks.
	per = int(CRUISE / 0.5)
	row = []
	for k in range(0, len(r), per):
		w = r[k:k + per]
		row.append(f"{k // per:>2}s t{max(abs(y) for y, _ in w) / TURN_RATE:.2f} p{max(abs(p) for _, p in w) / PITCH_SPEED:.2f} h{pts[k][1]:+.1f}")
	for k in range(0, len(row), 6):
		print("  " + " | ".join(row[k:k + 6]))


if __name__ == "__main__":
	main()
