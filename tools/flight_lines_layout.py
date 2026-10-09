#!/usr/bin/env python3
"""Lays out the flight study's `lines` pack (scripts/flight_pack_lines.gd):
greybox halls with three token lines through the same stone, laid out
flow-first (the lines are designed, then the hall stood round them).

  green   the forgiving main line: lazy sways, wide openings, never close
  yellow  branches off green for more threading and rejoins it
  red     the tight mastery line: knife-edge slits and close skims

A line is two lists of beats in the nave's own frame, `across` (m, + the
right of the nave's middle) and `up` (m over the nave's floor there), each
beat an extreme the line swings to. Between two beats the line follows a
half cosine, so its slope is nil on a beat and it swings hardest between
them; the up beats sit half a beat off the across beats, so one axis is
swinging while the other turns round and the line never flies straight.
Because a half cosine only depends on the two beats round it, a line that
shares green's beats up to some s and from some later s on flies exactly
green's line outside that stretch: a branch leaves green and rejoins it,
and the shared tokens are the very same points.

The nave curves in plan (`kappa`, rad/m, + left, as steps) and its floor
bends up and down along its length (`floor`: beats of the floor's height,
half cosines between them), so the hall itself rises and dips as one long
gentle curve and every bay is tilted along it (FlightCourse `_bay` `pitch`).
A line with |across| past the wall (12.4 m) is outside the hall: the exits
and re-entries are where it crosses the wall, through breaches in the bays'
plans, with the row column there left out (`rows`) so the way out is wide.

  python3 tools/flight_lines_layout.py --check              # every station's lines: needs, swing, crossings
  python3 tools/flight_lines_layout.py --write              # into scripts/flight_pack_lines.gd
  python3 tools/flight_lines_layout.py --station lines_bend --check
"""
import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from flight_flow_layout import BAY, CRUISE, TURN_RATE, PITCH_SPEED, Nave, fwd, gd_plan, spin, v3  # noqa: E402

WALL_Z = 12.4
ROW_Z = 9.4
COLLAPSE_REACH = 9.0
ROW_REACH = 7.0
ARCH_ROW_REACH = 4.5
LINES = ("green", "yellow", "red")
PACK_FILE = "scripts/flight_pack_lines.gd"


def cosine_beats(beats):
	"""A function of s through [(s, v), ...] (s rising): a half cosine between
	each pair of beats, held flat before the first and after the last."""
	beats = sorted(beats)

	def f(s):
		if s <= beats[0][0]:
			return beats[0][1]
		for (s0, v0), (s1, v1) in zip(beats, beats[1:]):
			if s <= s1:
				u = (s - s0) / (s1 - s0)
				return v0 + (v1 - v0) * 0.5 * (1.0 - math.cos(math.pi * u))
		return beats[-1][1]
	return f


def merge(base, replace):
	"""`base` beats with those in [first, last] of `replace` swapped for it:
	the branch's own beats between the two beats it shares with base."""
	lo, hi = replace[0][0], replace[-1][0]
	assert replace[0] in base and replace[-1] in base, "a branch starts and ends on green's beats: %s %s" % (replace[0], replace[-1])
	return sorted([b for b in base if b[0] < lo or b[0] > hi] + list(replace))


def mirrored(spec):
	"""`spec` left for right (`mirror`): across, curvature, spires, gates,
	screens and inner columns flipped, so a layout can turn away from its
	neighbour without being laid out again."""
	out = dict(spec)
	out["mirror"] = False
	flip = lambda beats: [(s, -a) for s, a in beats]
	out["kappa"] = [(s, -k) for s, k in spec["kappa"]]
	lines = {}
	for name, ln in spec["lines"].items():
		ln = dict(ln)
		if "across" in ln:
			ln["across"] = flip(ln["across"]) if name == "green" else [flip(r) for r in ln["across"]]
		lines[name] = ln
	out["lines"] = lines
	out["spires"] = [(s, -a, r) for s, a, r in spec.get("spires", [])]
	out["gates"] = [(s, -a, sill, w, h) for s, a, sill, w, h in spec.get("gates", [])]
	plans = {}
	for i, plan in spec.get("plans", {}).items():
		plan = dict(plan)
		if "screen" in plan:
			plan["screen"] = True if plan["screen"] == "right" else "right"
		if "inner" in plan:
			plan["inner"] = [-z for z in plan["inner"]]
		if "gaps" in plan:
			plan["gaps"] = [5 - g for g in plan["gaps"]]
		plans[i] = plan
	out["plans"] = plans
	return out


class Station:
	def __init__(self, spec):
		if spec.get("mirror"):
			spec = mirrored(spec)
		self.spec = spec
		self.floor = cosine_beats(spec["floor"])
		self.lines = {}
		green = spec["lines"]["green"]
		for name in LINES:
			ln = spec["lines"].get(name)
			if ln is None:
				continue
			if name == "green":
				across, up = ln["across"], ln["up"]
			else:
				across = green["across"]
				for rep in ln.get("across", []):
					across = merge(across, rep)
				up = green["up"]
				for rep in ln.get("up", []):
					up = merge(up, rep)
			self.lines[name] = (cosine_beats(across), cosine_beats(up))
		self.nave = Nave(0.0, 0.0, 0.0, 0.0, spec["kappa"])
		entry = spec["entry"]
		p = self.point("green", entry)
		self.nave.x, self.nave.floor, self.nave.z = -p[0], -p[1], -p[2]
		t0 = self.tangent("green", entry)
		turn = -math.atan2(-t0[0], -t0[2])
		self.nave.x, self.nave.z = spin(self.nave.x, self.nave.z, turn)
		self.nave.yaw += turn
		self.nave._cache = {}

	def local(self, name, s):
		a, u = self.lines[name]
		return a(s), u(s)

	def point(self, name, s):
		a, u = self.local(name, s)
		return self.nave.point(s, a, self.floor(s) + u)

	def tangent(self, name, s, h=0.05):
		a, b = self.point(name, s - h), self.point(name, s + h)
		d = [b[i] - a[i] for i in range(3)]
		n = math.sqrt(sum(v * v for v in d))
		return [v / n for v in d]

	def samples(self, name, step=0.5):
		s = self.spec["entry"]
		out = []
		while s <= self.spec["out"] + 1e-6:
			out.append((s, self.point(name, s)))
			s += step
		return out

	def token_s(self, name):
		"""The s of the line's tokens: green's grid, plus the line's own."""
		spec = self.spec
		ss = []
		s = spec["first_token"]
		while s <= spec["out"] + 1e-6:
			ss.append(round(s, 3))
			s += spec["token_step"]
		ln = spec["lines"].get(name, {})
		ss += ln.get("tokens_at", [])
		drop = set(round(v, 3) for v in ln.get("drop_tokens", []))
		return sorted(set(v for v in ss if round(v, 3) not in drop))

	def tokens(self, name):
		out = []
		green = self.token_s("green")
		for s in self.token_s(name):
			p = self.point(name, s)
			# Where the line runs on green's, its token is green's very point.
			if name != "green" and s in green:
				g = self.point("green", s)
				if math.dist(p, g) < 0.3:
					p = g
			out.append(p)
		return out

	def bays(self):
		"""[(at (x, y, z), yaw, plan)] of every bay, tilted along the floor."""
		out = []
		for i in range(self.spec["bays"]):
			at, yaw = self.nave.bay_line(i)
			s0, s1 = i * BAY, (i + 1) * BAY
			f0, f1 = self.floor(s0), self.floor(s1)
			(ax, az), _ = self.nave.frame(s0)
			(bx, bz), _ = self.nave.frame(s1)
			pitch = math.atan2(f1 - f0, math.hypot(bx - ax, bz - az))
			plan = dict(self.openings().get(i, {}))
			plan.update(self.spec["plans"].get(i, {}))
			plan.setdefault("roof", "whole")
			plan.setdefault("inner", [])
			for i0, i1 in self.spec.get("open_roof", []):
				if i0 <= i <= i1:
					plan["roof"] = "open"
					plan.pop("gaps", None)
					if i > i0:
						plan["beam"] = False
			if abs(pitch) > 1e-4:
				plan["pitch"] = round(pitch, 4)
			if i == self.spec["bays"] - 1:
				plan["torn"] = 2
				plan["last"] = True
			out.append(((at[0], self.nave.floor + f0, at[2]), yaw, plan))
		return out

	def crossings(self, name):
		"""Where line `name` crosses the walls and the outer rows:
		[(kind "out"/"in", side -1 left / 1 right, s at the wall, s at the row)]."""
		walls, rows = [], []
		prev = None
		s = self.spec["entry"]
		while s <= self.spec["out"] + 1e-6:
			a, _u = self.local(name, s)
			if prev is not None:
				if (abs(prev) > ROW_Z) != (abs(a) > ROW_Z):
					rows.append(s)
				if (abs(prev) > WALL_Z) != (abs(a) > WALL_Z):
					walls.append(("out" if abs(a) > WALL_Z else "in", -1 if a < 0 else 1, s))
			prev = a
			s += 0.25
		out = []
		for way, side, s_w in walls:
			if way == "out":
				r = max([v for v in rows if v <= s_w], default=None)
			else:
				r = min([v for v in rows if v >= s_w], default=None)
			out.append((way, side, s_w, r))
		return out

	def openings(self):
		"""The bays' breaches and fallen columns where the lines cross the
		walls (`openings`: [(line, kind)]): "collapse" opens every bay within
		COLLAPSE_REACH m of the wall crossing (roof open, wall down) and
		drops the row's columns within ROW_REACH m of the row crossing;
		"arch" opens the one bay the crossing is in, dropping the row column
		only if the row crossing is within 3 m of it."""
		plans = {}
		for name, kind in self.spec.get("openings", []):
			for _way, side, s_w, s_r in self.crossings(name):
				k = 0 if side < 0 else 1
				if kind == "collapse":
					bays = [i for i in range(self.spec["bays"]) if i * BAY < s_w + COLLAPSE_REACH and (i + 1) * BAY > s_w - COLLAPSE_REACH]
				else:
					bays = [int(s_w // BAY)]
				for i in bays:
					plan = plans.setdefault(i, {})
					breach = plan.setdefault("breach", ["", ""])
					if breach[k] != "collapse":
						breach[k] = kind
					if kind == "collapse":
						plan["roof"] = "open"
				reach = ROW_REACH if kind == "collapse" else ARCH_ROW_REACH
				for i in range(self.spec["bays"]):
					if s_r is not None and abs(i * BAY - s_r) < reach:
						plan = plans.setdefault(i, {})
						rows = plan.setdefault("rows", [-1, 1])
						if (-1 if k == 0 else 1) in rows:
							rows.remove(-1 if k == 0 else 1)
		return plans

	def pillars(self):
		"""Outside spires: [(x, z), radius], placed in the nave's frame."""
		out = []
		for s, a, r in self.spec.get("spires", []):
			p = self.nave.point(s, a, 0.0)
			out.append(((p[0], p[2]), r))
		return out

	def gates(self):
		"""Gates (FlightCourse "gate": posts, lintel and sill round a w x h
		opening) standing on the roof: [(middle, w, h, yaw)], each given as
		(s, across, sill height over the floor, w, h), square to the nave."""
		out = []
		for s, a, sill, w, h in self.spec.get("gates", []):
			_, yaw = self.nave.frame(s)
			out.append((self.nave.point(s, a, self.floor(s) + sill + 1.0 + h * 0.5), w, h, yaw))
		return out


def gd_plan_sorted(plan):
	keys = ["roof", "gaps", "tie", "inner", "rows", "breach", "screen", "torn", "beam", "last", "pitch"]
	ordered = {k: plan[k] for k in keys if k in plan}
	ordered.update({k: v for k, v in plan.items() if k not in ordered})
	return gd_plan(ordered)


def gd_tokens(tokens, indent):
	lines = []
	for i in range(0, len(tokens), 4):
		lines.append(indent + ",".join(v3(t) for t in tokens[i:i + 4]) + ",")
	return lines


def gd_ease(line):
	"""A line's `ease` (FlightCourse `reach`: its tokens' reach widened), as a key."""
	return f'"ease":{line["ease"]},' if line.get("ease") else ""


def station_text(st):
	spec = st.spec
	ease = gd_ease(spec["lines"]["green"])
	out = [f'\t{{"id":"{spec["id"]}","key":-1,"pack":"lines","name":"{spec["name"]}","intent":"{spec["lines"]["green"]["intent"]}",{ease}"parts":[']
	for at, yaw, plan in st.bays():
		out.append(f'\t\t["bay",{v3(at)},{yaw:.4f},{gd_plan_sorted(plan)}],')
	for (x, z), r in st.pillars():
		out.append(f'\t\t["pillar",Vector2({x:.2f},{z:.2f}),{r:.1f}],')
	for mid, w, h, yaw in st.gates():
		out.append(f'\t\t["gate",{v3(mid)},{w:.2f},{h:.2f},{yaw:.4f}],')
	out.append('\t],"tokens":[')
	out += gd_tokens(st.tokens("green"), "\t\t")
	out.append('\t],"lines":{')
	for name in LINES[1:]:
		if name not in st.lines:
			continue
		ease = gd_ease(spec["lines"][name])
		out.append(f'\t\t"{name}":{{"intent":"{spec["lines"][name]["intent"]}",{ease}"tokens":[')
		out += gd_tokens(st.tokens(name), "\t\t\t")
		out.append("\t\t]},")
	out.append("\t}},")
	return "\n".join(out)


def rates(pts):
	out = []
	for i in range(1, len(pts) - 1):
		a = [pts[i][k] - pts[i - 1][k] for k in range(3)]
		b = [pts[i + 1][k] - pts[i][k] for k in range(3)]
		ya = math.atan2(-a[0], -a[2])
		yb = math.atan2(-b[0], -b[2])
		pa = math.atan2(a[1], math.hypot(a[0], a[2]))
		pb = math.atan2(b[1], math.hypot(b[0], b[2]))
		ds = 0.5 * (math.dist(pts[i - 1], pts[i]) + math.dist(pts[i], pts[i + 1]))
		dy = (yb - ya + math.pi) % (2 * math.pi) - math.pi
		out.append((dy / ds * CRUISE, (pb - pa) / ds * CRUISE))
	return out


def check(st):
	spec = st.spec
	print(f"== {spec['id']}: {spec['name']}")
	fl = [st.floor(i * BAY) for i in range(spec["bays"] + 1)]
	slopes = [math.degrees(math.atan2(fl[i + 1] - fl[i], BAY)) for i in range(len(fl) - 1)]
	print(f"floor {min(fl):+.1f}..{max(fl):+.1f} m, slope {min(slopes):+.1f}..{max(slopes):+.1f} deg")
	for name in LINES:
		if name not in st.lines:
			continue
		smp = st.samples(name)
		pts = [p for _, p in smp]
		r = rates(pts)
		# Smooth over 0.2 s of flight, as the metrics do.
		k = max(1, int(0.2 * CRUISE / 0.5))
		ys = [sum(abs(y) for y, _ in r[max(0, i - k):i + 1]) / len(r[max(0, i - k):i + 1]) for i in range(len(r))]
		ps = [sum(abs(p) for _, p in r[max(0, i - k):i + 1]) / len(r[max(0, i - k):i + 1]) for i in range(len(r))]
		swing = [math.degrees(math.hypot(y, p)) for y, p in r]
		length = sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))
		yaw = sum(abs(y) for y, _ in r)
		pit = sum(abs(p) for _, p in r)
		toks = st.tokens(name)
		print(f"  {name:6s} {length:5.0f} m ({length / CRUISE:4.1f} s) {len(toks):2d} tokens | turn need {max(ys) / TURN_RATE:.2f} pitch need {max(ps) / PITCH_SPEED:.2f} | "
		      f"still {sum(1 for v in swing if v < 6) / len(swing):.0%} swing {sum(swing) / len(swing):.0f} deg/s yaw share {yaw / (yaw + pit):.0%}")
		cross = [f"{w} {'L' if side < 0 else 'R'} wall {s_w:.0f} row {s_r if s_r is None else round(s_r)}" for w, side, s_w, s_r in st.crossings(name)]
		if cross:
			print("         crossings: " + ", ".join(cross))
		row = []
		per = int(CRUISE / 0.5)
		for i in range(0, len(r), per):
			s = smp[i + 1][0]
			a, u = st.local(name, s)
			row.append(f"{s:4.0f} t{max(ys[i:i + per]) / TURN_RATE:.2f} a{a:+5.1f} u{u:4.1f}")
		for i in range(0, len(row), 5):
			print("         " + " | ".join(row[i:i + 5]))


def write(stations, path=PACK_FILE):
	src = open(path).read()
	for st in stations:
		sid = st.spec["id"]
		begin = f"\t# >>> {sid}: written by tools/flight_lines_layout.py --write"
		end = f"\t# <<< {sid}"
		block = begin + "\n" + station_text(st) + "\n" + end
		if begin in src:
			a = src.index(begin)
			b = src.index(end) + len(end)
			src = src[:a] + block + src[b:]
		else:
			anchor = "\n]\n"
			a = src.index("const STATIONS := [")
			a = src.index(anchor, a)
			src = src[:a] + "\n" + block + src[a:]
	open(path, "w").write(src)


# ---------------------------------------------------------------------------
# The stations.
# ---------------------------------------------------------------------------

# 1. The bending nave: a hall whose floor climbs 11 m to a crest and falls
# 16 m to a trough as one long curve, while it curves left in plan. Green
# sways up the middle of the nave, leaves it past the crest through a wide
# collapse on the inside of the bend, swoops down outside between the wall
# and a spire, and comes back in through a second collapse as the hall
# dips. Yellow leaves earlier, out through an arch on the right while the
# hall climbs, past a spire, back in through another arch, then goes round
# the far side of green's spire. Red stays in when the others leave: under
# a low tie, through a knife-edge slit, a hard swing right and back, and a
# second slit.
BEND = {
	"id": "lines_bend", "name": "Bending nave: three lines (crest exit, spires, re-entry)", "mirror": True,
	"bays": 27, "entry": -16.0, "first_token": 0.0, "token_step": 12.0, "out": 222.0,
	"kappa": [(-99.0, 1.0 / 120.0), (124.0, -1.0 / 70.0)],
	"floor": [(0.0, 0.0), (64.0, 11.0), (152.0, -5.0)],
	"lines": {
		"green": {"intent": "easy", "ease": 1.3,
			"across": [(-16.0, 0.0), (8.0, 1.5), (32.0, -2.5), (52.0, 2.0), (108.0, -18.5), (164.0, 3.5), (186.0, 1.8), (208.0, 4.0), (230.0, 2.0), (252.0, 3.0)],
			"up": [(-16.0, 5.0), (20.0, 4.2), (44.0, 5.6), (68.0, 4.4), (96.0, 3.0), (124.0, 4.4), (150.0, 5.4), (176.0, 4.2), (200.0, 5.4), (226.0, 4.4), (250.0, 5.2)]},
		"yellow": {"intent": "medium",
			"across": [[(32.0, -2.5), (64.0, -17.0), (100.0, -28.5), (164.0, 3.5)]],
			"up": [[(20.0, 4.2), (52.0, 2.8), (68.0, 4.4)]]},
		"red": {"intent": "hard", "ease": 0.75,
			"across": [[(52.0, 2.0), (78.0, -2.5), (99.0, -6.0), (109.0, -6.0), (132.0, 3.0), (155.0, -6.0), (165.0, -6.0), (208.0, 4.0)]],
			"up": [[(44.0, 5.6), (88.0, 2.6), (96.0, 3.4), (104.0, 2.65), (128.0, 4.6), (144.0, 3.8), (160.0, 2.65), (176.0, 4.2)]],
			"tokens_at": [88.0, 104.0, 118.0, 142.0, 160.0]},
	},
	"openings": [("green", "collapse"), ("yellow", "arch")],
	"plans": {
		0: {"roof": "whole"},
		2: {"roof": "broken", "gaps": [2, 3]},
		7: {"roof": "broken", "gaps": [3, 4]},
		11: {"roof": "broken", "gaps": [1, 2], "tie": "low"},
		13: {"roof": "whole", "screen": True, "inner": [-2.6]},
		20: {"roof": "whole", "screen": True, "inner": [-2.6]},
		23: {"roof": "broken", "gaps": [3, 4]},
	},
	"spires": [(78.0, -25.5, 2.0), (104.0, -24.5, 2.0)],
}
# 2. The stitching hall: a long hall climbing gently (9 m over 160 m) and
# curving a little right, with its walls broken through on both sides.
# Green stitches through them in one big flowing S: out the left wall, in
# again, across the nave and out the right, in, out the left and home,
# passing inside a spire every time it is out. Yellow takes the same breaches
# but swings wide round the far side of the second and third spires. Red
# stays in and threads three knife-edge slits, left, right, left, swinging
# across the nave between them while the others are outside.
STITCH = {
	"id": "lines_stitch", "name": "Stitching hall: three lines (out and in through both walls)",
	"bays": 27, "entry": -16.0, "first_token": 0.0, "token_step": 12.0, "out": 214.0,
	"kappa": [(-99.0, -1.0 / 110.0), (100.0, 1.0 / 110.0)],
	"floor": [(8.0, 0.0), (64.0, 6.0), (120.0, 0.0), (176.0, 6.0)],
	"lines": {
		"green": {"intent": "easy", "ease": 1.3,
			"across": [(-16.0, 0.0), (36.0, -17.0), (92.0, 17.0), (148.0, -17.0), (200.0, 0.0), (228.0, 2.5)],
			"up": [(-16.0, 5.0), (16.0, 4.2), (44.0, 5.4), (72.0, 4.0), (100.0, 5.4), (128.0, 4.0), (156.0, 5.4), (184.0, 4.2), (212.0, 5.2), (240.0, 4.4)]},
		"yellow": {"intent": "medium",
			"across": [[(36.0, -17.0), (92.0, 29.0), (148.0, -29.0), (200.0, 0.0)]]},
		"red": {"intent": "hard", "ease": 0.75,
			"across": [[(-16.0, 0.0), (10.0, 2.5), (36.0, -6.0), (44.0, -6.0), (92.0, 6.0), (100.0, 6.0), (148.0, -6.0), (156.0, -6.0), (200.0, 0.0)]],
			"up": [[(-16.0, 5.0), (40.0, 2.65), (68.0, 4.6), (96.0, 2.65), (124.0, 4.6), (152.0, 2.65), (184.0, 4.2)]],
			"tokens_at": [40.0, 96.0, 152.0]},
	},
	"openings": [("green", "collapse"), ("yellow", "collapse")],
	"plans": {
		0: {"roof": "whole"},
		5: {"roof": "whole", "screen": True, "inner": [-2.6]},
		9: {"roof": "broken", "gaps": [2, 3]},
		12: {"roof": "whole", "screen": "right", "inner": [2.6]},
		16: {"roof": "broken", "gaps": [3, 4]},
		19: {"roof": "whole", "screen": True, "inner": [-2.6]},
		23: {"roof": "broken", "gaps": [2, 3]},
	},
	"spires": [(36.0, -23.5, 2.0), (92.0, 23.5, 2.0), (148.0, -23.5, 2.0)],
}
# 3. Over the crest: a hall arched like a bridge, its floor rising 8 m to a
# crest and falling again, curving a little right. Green climbs out through
# the open roof as the hall rises, flies over the roofed crest through three
# big gates standing on the roof (the climb rings, on top of a building),
# and dives back in through the open roof on the far side. Yellow stays in
# under the roof, weaving round inner columns over the hump. Red goes over
# the roof with green but beside it, on its knife edge through the slit
# gates that flank the big ones.
CREST = {
	"id": "lines_crest", "name": "Over the crest: three lines (out the roof through gates, back in)",
	"bays": 21, "entry": -16.0, "first_token": 0.0, "token_step": 12.0, "out": 180.0,
	"kappa": [(-99.0, 1.0 / 200.0), (48.0, -1.0 / 80.0), (112.0, 1.0 / 200.0)],
	"floor": [(0.0, 0.0), (80.0, 8.0), (160.0, 0.0)],
	"lines": {
		"green": {"intent": "easy", "ease": 1.3,
			"across": [(-16.0, 0.0), (8.0, 2.0), (36.0, -1.5), (64.0, 0.0), (96.0, 0.0), (124.0, 1.5), (152.0, -2.0), (176.0, 1.5), (200.0, -1.0)],
			"up": [(-16.0, 5.0), (12.0, 4.4), (62.0, 15.3), (98.0, 15.3), (148.0, 4.4), (176.0, 5.2), (204.0, 4.6)]},
		"yellow": {"intent": "medium",
			"across": [[(36.0, -1.5), (56.0, 3.5), (80.0, -3.5), (104.0, 3.5), (124.0, 1.5)]],
			"up": [[(12.0, 4.4), (40.0, 6.0), (68.0, 3.6), (92.0, 6.0), (120.0, 3.8), (148.0, 4.4)]]},
		"red": {"intent": "hard", "ease": 0.75,
			"across": [[(36.0, -1.5), (58.0, -6.0), (102.0, -6.0), (124.0, 1.5)]],
			"up": [[(12.0, 4.4), (62.0, 14.25), (98.0, 14.25), (148.0, 4.4)]],
			"tokens_at": [64.0, 80.0, 96.0]},
	},
	"plans": {
		0: {"roof": "whole"},
		2: {"roof": "broken", "gaps": [2, 3]},
		7: {"roof": "whole", "inner": [0.0]},
		10: {"roof": "whole", "inner": [0.0]},
		13: {"roof": "whole", "inner": [0.0]},
		17: {"roof": "broken", "gaps": [3, 4]},
	},
	"open_roof": [(3, 6), (13, 16)],
	"gates": [(64.0, 0.0, 11.6, 7.0, 5.5), (80.0, 0.0, 11.6, 7.0, 5.5), (96.0, 0.0, 11.6, 7.0, 5.5),
		(64.0, -6.0, 11.6, 1.15, 3.3), (80.0, -6.0, 11.6, 1.15, 3.3), (96.0, -6.0, 11.6, 1.15, 3.3)],
}
LAYOUTS = [BEND, STITCH, CREST]


def stations(only=None):
	out = []
	for spec in LAYOUTS:
		if only and spec["id"] != only:
			continue
		out.append(Station(spec))
	return out


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--station", default=None)
	ap.add_argument("--check", action="store_true")
	ap.add_argument("--write", action="store_true")
	args = ap.parse_args()
	sts = stations(args.station)
	if args.check:
		for st in sts:
			check(st)
		return
	if args.write:
		write(sts)
		print("wrote " + ", ".join(st.spec["id"] for st in sts) + " into " + PACK_FILE)
		return
	for st in sts:
		print(station_text(st))


if __name__ == "__main__":
	main()
