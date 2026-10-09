#!/usr/bin/env python3
"""Writes the flight study's token-placement pack, scripts/flight_pack_tokens.gd.

One question: in the same space, which placement of tokens makes flying it
fun? Every station in the pack copies an existing station's parts unchanged
and varies only where the tokens go. Two geometries:

  the hall   sundered_flow's (key 0, the user's only 5/5): the corkscrew nave
             of piece A, the swoop, piece B and its climbing turn out of the
             apse (tools/flight_flow_layout.py builds it; this script reuses
             its frame, so a point is given as (piece, s, across, up) in the
             nave's own metres: s along the nave from the first bay line,
             across + to the right, up over the piece's floor)
  the swoop  open_swoop's (key 7): two lone pillars in open air

A station's token list is its ROUTE: the designer's line, in order. Each
route point is a token (drawn, must be taken to clear) or a GUIDE (not
drawn, not counted: it only shapes the line the metrics measure and the
bots fly; FlightCourse `guides`). BONUS tokens sit off the route, are
optional, unordered and never missed (FlightCourse `bonus`). So the dense,
sparse and gate-only hall variants share one route (sundered_flow's 21
tokens) and differ only in which of its points are drawn.

  python3 tools/flight_tokens_layout.py            # rewrite scripts/flight_pack_tokens.gd
  python3 tools/flight_tokens_layout.py --print    # print it instead
"""
import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flight_flow_layout as F  # noqa: E402

OUT = "scripts/flight_pack_tokens.gd"
PACK = "tokens"
# The pack's row: its own origins (FlightCourse `origin`), well south of the
# main row (which runs along z 0 and flies north), SPACING apart along x.
ROW_Z = 1300.0
SPACING = 260.0
ALT = 40.0

A, B, _PTS, BASE = F.line_and_tokens()
A_PLANS, B_PLANS = F.plans()

# sundered_flow's route, labelled: A's bay lines (s 0-72), the swoop's two
# points, B's (s -8-56).
LABELS = [f"A{s}" for s in range(0, 73, 8)] + ["S1", "S2"] + [f"B{s}" for s in range(-8, 57, 8)]
assert len(LABELS) == len(BASE) == 21


def at(piece, s, across, up):
	return (A if piece == "A" else B).point(s, across, up)


def hall_parts():
	out = []
	for piece, ps in ((A, A_PLANS), (B, B_PLANS)):
		for i, plan in enumerate(ps):
			p, yaw = piece.bay_line(i)
			out.append(f'["bay",{F.v3(p)},{yaw:.4f},{F.gd_plan(plan)}]')
	return out


def base_index(label):
	return LABELS.index(label)


# --- The hall's variants ------------------------------------------------------------

# Openings on sundered_flow's line, as route labels: the gate's roofed
# mouth, over the first high tie, under the low tie, over the second high
# tie, out of A's torn end, into B's torn mouth, under B's low tie, over B's
# high tie, up out of the apse's open roof.
GATES = ["A0", "A8", "A32", "A56", "A72", "B0", "B8", "B32", "B48"]
# Sparse: five hints, each at an opening that tells you which way to go
# through it (over the first tie, under the low one, out the torn end, under
# B's low tie, out of the roof). The rest of the line is yours to find.
SPARSE = ["A8", "A32", "A72", "B8", "B48"]


def guides_except(shown):
	return [i for i, name in enumerate(LABELS) if name not in shown]


# Risk detours: an easy line plus bonus tokens off it that need a tight move
# to take. The line is the gate-only one less the openings a detour takes
# the other way (over the first high tie, under B's low tie and over B's
# high tie, round the slits), so taking a bonus never makes you miss a
# token: each detour rejoins before the next one. 6 tokens.
DETOUR_SHOWN = ["A0", "A32", "A56", "A72", "B0", "B48"]
DETOURS = [
	# Under A's first high tie (soffit 6 m) where the line goes over it: a
	# dip of about 4 m and back up.
	("under the first high tie", ("A", 8.0, 0.0, 4.4)),
	# In the 1.2 m gap between the right row's column and the wall at A's
	# bay line 24 (a knife-edge gap: level wings don't fit), about 8 m right
	# of the line, in view from the high tie as the line swings right.
	("aisle gap, knife edge", ("A", 24.0, 11.2, 3.0)),
	# Through B's two knife-edge slits (left, at bay lines 16 and 24), where
	# the line weaves out right of the screens.
	("B's first slit", ("B", 16.0, -6.0, 2.65)),
	("B's second slit", ("B", 24.0, -6.0, 2.65)),
]

# Hidden: the same gate-only line, plus bonus tokens tucked where the line
# never shows them: you see them only by looking round, on a second pass,
# or from outside the hall.
HIDDEN = [
	# On top of A's whole roof (bays 3-4), seen only from above the hall.
	("on A's roof", ("A", 32.0, 0.0, 12.6)),
	# In the lee of A's middle column at bay line 24, the side the line
	# doesn't pass, just past it (the line passes 3.5 m right of it,
	# swinging right, so the column hides it until it's behind you).
	("behind a column", ("A", 26.2, -0.6, 3.0)),
	# Outside A's left wall, just through the arch breach (bay 6).
	("outside the arch", ("A", 52.0, -15.5, 2.6)),
	# Under A's floor (the podium slab), just short of its torn end.
	("under A's floor", ("A", 68.0, 0.0, -3.4)),
	# In B's right aisle, between the row's columns at bay lines 24 and 32.
	("B's right aisle", ("B", 28.0, 10.6, 3.6)),
]

# Out and back in: the line leaves A through the arch breach in its left
# wall, runs outside along the wall, turns back in over the torn wall of
# A's last bay and out of its torn end into the swoop. A breadcrumb trail
# (a token every 6-8 m), as dense as the baseline, so only the route
# differs.
#
# The arch is 5.2 m wide (s 49.4-54.6) and 5.4 m tall; the row's columns
# either side of it stand at s 48 and 56. So the line stays inside the row
# until past the s 48 column, crosses the row and the wall at about 50
# degrees to the nave, then has about 15 m outside to turn back the other
# way (a 100 degree swing at under TURN_RATE), and comes in over bay 8's
# torn wall (3 m) between the s 64 column and the snapped ones at s 72.
OUT_ARCH = 52.9        # s where the line crosses the wall's middle, outward
OUT_ANGLE = 60.0       # degrees to the nave, there and coming back in
OUT_R = 9.5            # m: the loop outside (about 0.9 x TURN_RATE at cruise)
OUT_CLEAR = 0.0        # m: straight on past the wall before the loop bends back


def outback_loop(steps=6):
	"""The loop outside, a circular arc in the nave's frame from OUT_CLEAR m
	past the arch round to the wall again (over bay 8's torn wall), its start
	and `steps` pieces."""
	a = math.radians(OUT_ANGLE)
	s0 = OUT_ARCH + OUT_CLEAR * math.cos(a)
	c0 = -12.4 - OUT_CLEAR * math.sin(a)
	mid_s = s0 + OUT_R * math.sin(a)
	mid_across = c0 + OUT_R * math.cos(a)
	pts = []
	for k in range(1, steps + 1):
		th = -a + 2 * a * k / steps
		up = 2.9 + 2.0 * k / steps
		pts.append(("A", mid_s + OUT_R * math.sin(th), mid_across - OUT_R * math.cos(th), up))
	return pts


# The swing from the nave's corkscrew to the arch (past the inner column at
# s 40 on its left and the row's column at s 48 on its right).
OUT_APPROACH = [("A", 40.0, -3.0, 3.3), ("A", 44.0, -3.6, 3.4), ("A", 47.6, -5.4, 3.2), ("A", 50.2, -8.2, 3.0)]


def outback_route():
	return ([("A", 0.0), ("A", 8.0), ("A", 16.0), ("A", 24.0), ("A", 32.0)] + OUT_APPROACH
		+ [("A", OUT_ARCH, -12.4, 2.9)] + outback_loop()
		+ [("A", 75.0, -8.6, 4.6), ("A", 81.0, -4.2, 3.0), "B-8", "B0", "B8", "B16", "B24", "B32", "B40", "B48", "B56"])


def route_point(spec):
	if isinstance(spec, str):
		return BASE[base_index(spec)]
	if len(spec) == 2:
		return BASE[base_index(f"{spec[0]}{int(spec[1])}")]
	return at(*spec)


def hall_variants():
	base = list(BASE)
	gates = guides_except(GATES)
	return [
		{"id": "tokens_hall_dense", "name": "Tokens: hall, dense trail (baseline: sundered_flow's 21)",
		 "style": "dense", "tokens": base, "guides": [], "bonus": []},
		{"id": "tokens_hall_sparse", "name": "Tokens: hall, sparse hints (5 at openings, find the line)",
		 "style": "sparse", "tokens": base, "guides": guides_except(SPARSE), "bonus": []},
		{"id": "tokens_hall_gates", "name": "Tokens: hall, gate-only (9, one per opening)",
		 "style": "gates", "tokens": base, "guides": gates, "bonus": []},
		{"id": "tokens_hall_detours", "name": "Tokens: hall, risk detours (6 easy tokens + 4 bonus: under a tie, aisle gap, two slits)",
		 "style": "detours", "tokens": base, "guides": guides_except(DETOUR_SHOWN), "bonus": [(n, at(*p)) for n, p in DETOURS]},
		{"id": "tokens_hall_hidden", "name": "Tokens: hall, hidden (gate line + 5 bonus: roof, column, outside, under, aisle)",
		 "style": "hidden", "tokens": base, "guides": gates, "bonus": [(n, at(*p)) for n, p in HIDDEN]},
		{"id": "tokens_hall_outback", "name": "Tokens: hall, out and back in (out the arch, along the wall, back over it)",
		 "style": "outback", "tokens": [route_point(p) for p in outback_route()], "guides": [], "bonus": []},
	]


# --- The open swoop's variants --------------------------------------------------------

SWOOP_PARTS = ['["pillar",Vector2(-30.0,-40.0),2.0]', '["pillar",Vector2(40.0,-90.0),2.0]']
SWOOP_BASE = [(0.0, 0.0, -14.0), (-3.0, -3.0, -30.0), (-10.0, -7.0, -45.0), (-14.0, -9.0, -62.0),
	(-11.0, -8.0, -80.0), (-2.0, -5.0, -95.0), (10.0, -1.0, -106.0), (24.0, 3.0, -112.0)]
# Skim the rock: a wider S than the baseline's, swung out so it passes each
# lone pillar close (the line about 1.8 m from its face, so the wingtip
# about 1 m), the first on its inside as the line turns left, the second
# as it sweeps right; a token at each pass, the rest guides.
SWOOP_SKIM = [(-3.0, 0.0, -14.0), (-12.0, -2.0, -24.0), (-21.0, -4.0, -33.0), (-26.3, -6.0, -41.0),
	(-26.0, -7.0, -52.0), (-18.0, -8.0, -63.0), (-4.0, -7.0, -71.0), (12.0, -5.0, -77.0),
	(25.5, -3.0, -83.0), (35.2, -1.0, -90.0), (41.5, 1.0, -100.0), (46.0, 3.0, -112.0)]
SWOOP_SKIM_SHOWN = [3, 9]   # the two skims; the rest are guides
SWOOP_DETOURS = [
	# The baseline trail, plus a bonus tight on each pillar's near face and
	# one looped round behind the second.
	("skim the first pillar", (-26.6, -8.0, -40.0)),
	("skim the second pillar", (36.4, -2.0, -90.0)),
	("behind the second pillar", (43.6, 1.0, -92.0)),
]


def swoop_variants():
	return [
		{"id": "tokens_swoop_dense", "name": "Tokens: open swoop, dense trail (baseline: open_swoop's 8)",
		 "style": "dense", "parts": SWOOP_PARTS, "tokens": SWOOP_BASE, "guides": [], "bonus": []},
		{"id": "tokens_swoop_skim", "name": "Tokens: open swoop, skim the rock (2 tokens, each tight past a pillar)",
		 "style": "gates", "parts": SWOOP_PARTS, "tokens": SWOOP_SKIM,
		 "guides": [i for i in range(len(SWOOP_SKIM)) if i not in SWOOP_SKIM_SHOWN], "bonus": []},
		{"id": "tokens_swoop_detours", "name": "Tokens: open swoop, risk detours (baseline + 3 bonus tight on the pillars)",
		 "style": "detours", "parts": SWOOP_PARTS, "tokens": SWOOP_BASE, "guides": [], "bonus": SWOOP_DETOURS},
	]


# --- Writing ----------------------------------------------------------------------------

def gd_station(i, v, parts):
	lines = []
	origin = f"Vector3({i * SPACING:.1f},{ALT:.1f},{ROW_Z:.1f})"
	lines.append(f'\t{{"id":"{v["id"]}","key":-1,"pack":"{PACK}","style":"{v["style"]}","origin":{origin},'
		f'"name":"{v["name"]}","intent":"medium","parts":[')
	for p in parts:
		lines.append(f"\t\t{p},")
	lines.append('\t],"tokens":[')
	toks = v["tokens"]
	for k in range(0, len(toks), 4):
		lines.append("\t\t" + ",".join(F.v3(t) for t in toks[k:k + 4]) + ",")
	lines.append("\t],")
	if v["guides"]:
		lines.append('\t"guides":[' + ",".join(str(g) for g in v["guides"]) + "],")
	if v["bonus"]:
		lines.append('\t"bonus":[')
		for name, p in v["bonus"]:
			lines.append(f"\t\t{F.v3(p)},   # {name}")
		lines.append("\t],")
	lines.append("\t},")
	return lines


HEADER = '''extends RefCounted
## The flight study's token-placement pack (studies/flight_study.gd
## `--pack=tokens`; docs/design/flight-study-tokens.md). Written by
## tools/flight_tokens_layout.py: edit that and rerun it, not this.
##
## Same geometry, different token placement: each station copies an existing
## station's parts (sundered_flow's hall, open_swoop's two pillars) and
## varies only where the tokens go. FlightCourse appends these to its
## STATIONS; they have no digit key (key -1), stand at their own `origin`
## (a row south of the main one) and are reached with N inside the pack,
## `--station=<id>` or `--pack=tokens`.
##
## Keys on top of a station's usual ones (FlightCourse):
##   pack    "tokens"
##   style   dense, sparse, gates, detours, hidden or outback
##   origin  where its entry stands in the world
##   guides  indices into `tokens` that are guides: not drawn, not counted,
##           only shaping the line (metrics) and the bots' route
##   bonus   optional tokens off the line: unordered, never missed, not
##           needed to clear (FlightRun `bonus_state`)

const STATIONS := [
'''


def build_text():
	out = [HEADER]
	stations = [(v, hall_parts()) for v in hall_variants()] + [(v, v["parts"]) for v in swoop_variants()]
	for i, (v, parts) in enumerate(stations):
		out.append("\n".join(gd_station(i, v, parts)) + "\n")
	out.append("]\n")
	return "".join(out)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--print", action="store_true")
	args = ap.parse_args()
	text = build_text()
	if args.print:
		print(text)
		return
	root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
	with open(os.path.join(root, OUT), "w") as f:
		f.write(text)
	print(f"wrote {OUT}")


if __name__ == "__main__":
	main()
