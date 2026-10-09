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


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--check", action="store_true")
	args = ap.parse_args()
	A, B, pts, tokens = line_and_tokens()
	a_plans, b_plans = plans()
	if args.check:
		r = rates(pts)
		swing = [math.degrees(math.hypot(y, p)) for y, p in r]
		print(f"line {sum(math.dist(pts[i], pts[i+1]) for i in range(len(pts)-1)):.0f} m, {len(tokens)} tokens")
		print(f"turn need peak {max(abs(y) for y, _ in r)/TURN_RATE:.2f}, pitch need peak {max(abs(p) for _, p in r)/PITCH_SPEED:.2f}")
		print(f"line swing deg/s: min {min(swing):.1f} mean {sum(swing)/len(swing):.1f}; still (<6) {sum(1 for s in swing if s < 6)/len(swing):.0%}")
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


if __name__ == "__main__":
	main()
