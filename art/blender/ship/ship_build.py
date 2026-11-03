"""Build the pirate ship: a hollow gun deck flown end to end.

    python3 tools/blender.py run art/blender/ship/ship_build.py [-- --fast]

Writes assets/models/pirate_ship.glb and, in assets/models/pirate_ship/, its
textures, shaders and materials (pirate_ship.glb.import points each material
name at its .tres), then reads the glb back and proves the corridor clear
(exits 1 if not). Every size is a constant in the first block: a retune is an
edit there and a rerun, then a headless import. --fast halves the textures.

Origin on the waterline at the corridor's midpoint. Bow toward Blender +Y
(Godot -Z), up +Z (Godot +Y), 1 unit = 1 m. The hull is the concept's
(ship_concept_build.py, ship-look-concept.md): a sheer up to the stern castle
and the forecastle, a round bilge with tumblehome, a raked counter aft and a
pointed prow forward. Both ends are breakable, each with a plug of shards
filling the corridor's end at y +-56.5: the transom aft, upright round the
exit, and a bulkhead forward at the back of a short tunnel cut through the
prow, out under its upper lip and over its lower one. The numbers follow
"Contract for the model" in docs/design/endless-flight/pirate-ship-handoff.md.
Blender (x, y, z) is the contract's (x, -z, y).

Textures are painted here in numpy: `hull` and `stern` are unique maps (one
for a side's elevation, shared by both sides, one for both flat ends),
projected straight on, so stains run across the planks; `wood` tiles; `sail`
is an atlas of patched canvas, its few shot holes and frayed hem a cut-out alpha. Vertex colours carry baked darkness,
shade under decks; the gun deck's light is drawn by its `deck` shader.
"""
import json
import math
import random
import struct
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/models/pirate_ship.glb"
TEX = ROOT / "assets/models/pirate_ship"     # textures and materials
RES = "res://assets/models/pirate_ship"

# --- The numbers --------------------------------------------------------------

# The hull (m), the concept's shape (ship_concept_build.py, its numbers turned into
# this frame: y = -its z, z = its y). The plates stay at y +-56.5: the transom round
# the stern's exit, and the bulkhead at the back of the prow's tunnel.
LENGTH = 113.0            # plate to plate
STERN_U = LENGTH * 0.5    # the transom round the exit, upright at the plate
Y_BOW = LENGTH * 0.5      # the bow's plate, at the back of the tunnel
Y_STERN = -STERN_U
BEAM = 29.0               # 14.5 m half breadth at 8 m up
WIDEN = 24.75 / 22.0      # hand-set x numbers below were set on a 22 m beam (the corridor kept 18)
KEEL_Z = -5.8             # the strakes' first line: 2.6 and 13.4 fall on strake lines
# The midship section's half breadth by height: a round belly, tumblehome above.
SECTION = ((-6.0, 1.5), (-5.0, 4.5), (-4.0, 7.2), (-2.5, 10.0), (-1.0, 11.8), (0.5, 13.0), (2.5, 13.9),
	(5.0, 14.4), (8.0, 14.5), (11.0, 14.0), (13.4, 13.3), (15.0, 12.6), (17.0, 11.8), (24.0, 10.4), (32.0, 9.2), (40.0, 8.4))
# The sheer: the rail's height along her (y, z), up to the stern castle and the forecastle.
SHEER = ((-STERN_U, 32.0), (-48.5, 30.5), (-40.0, 27.5), (-30.0, 23.0), (-22.0, 19.5), (-12.0, 17.5), (0.0, 17.0),
	(15.0, 17.6), (30.0, 19.5), (40.0, 22.5), (48.0, 24.0), (57.0, 25.0))
RUN_FROM = 34.0           # aft of this the run narrows: the bottom tucks in, the castle squares off
PROW_FROM = 40.0          # forward of this the prow closes to the stem
STEM_Y0 = 72.0            # the stem at the waterline; it rakes forward STEM_RAKE a metre up
STEM_RAKE = 0.25
RAKE_FROM = 40.0          # aft of this the counter leans out over the exit, the sternpost tucks in
COUNTER = 0.32            # m out a metre up, above COUNTER_Z
COUNTER_Z = 14.0
TUCK = 0.45               # m in a metre down, below TUCK_Z
TUCK_Z = 2.6
KEEL_RISE = 0.5           # the keel's depth lost at each end
WOBBLE = 0.12             # strake lines wander this much: by hand, not by rule
# The prow's tunnel: the corridor runs on past the bow's plate between walls lined in
# dark wood, under the upper lip and over the lower one, out where the sides close in.
TUNNEL_X = 10.4
TUNNEL_LO = 2.6
TUNNEL_HI = 13.4
CUT_R = 0.6               # the framing timbers round the cut, centred this far outside it

# The corridor: straight along the keel line, a clear box, nothing in it.
COR_LEN = 110.0
COR_W = 18.0
COR_H = 10.0
COR_FLOOR = 3.0
COR_TOP = COR_FLOOR + COR_H
COR_Z = COR_FLOOR + COR_H * 0.5   # the flight line's height
# The plugs: each fills the corridor's end, this big, in the flat of that end.
CRACK_W = 18.0
CRACK_H = 10.0
EXIT_CLEAR = 30.0         # how far past each end the rectangle is kept clear
OPEN_MARGIN = 0.25        # the torn edge stands at least this far off that rectangle
TOOTH = 0.2               # splinters reach this far into the hole, at most
PLUG_RECESS = -0.02       # a plug's face over the hull's, flush (negative: proud)
PLUG_THICK = 1.2          # the plate's depth, to its rear face
SHARDS = 30               # shards in each plug
# The wound: how a plug's strakes break. WOUND_OPEN is how open the plate is at its
# middle (0-1), WOUND_LUMP how much the holes wander and join up, WOUND_EDGE where
# across the plate (0 middle, 1 edge) the planking turns sound. FRAME_X: the frames
# behind the planks that keep it shut, snapped here and there.
WOUND_OPEN = 0.62
WOUND_LUMP = 0.8
WOUND_CUT = 0.33          # raise for more planking left
WOUND_EDGE = 0.72
BOARD_T = 0.24            # a loose board's thickness
BOARD_LEN = 2.3           # the longest piece; a shard is a board or two
FINGER = 1.1              # the longest splinter off a broken end, along the grain
SPRUNG = 1.5              # how far a broken end stands out of the hull, at most
SAG = 0.55                # how far it hangs into the hole, at most
HANGERS = 7               # planks torn loose, hanging from one end
FRAME_X = tuple(x * WIDEN for x in (-5.6, -1.9, 2.3, 5.9))
FRAME_W = 0.55
COVER_BACK = 0.95         # the black sheet's depth behind the plug's face
PLUG_TONE = 1.0           # the plug's planks against the hull's: shadowed, sooty
BROKE = (0.86, 0.74, 0.62)   # a broken face, over the stern's own weathered map

# The hull's shell and frame.
STRAKE = 1.2              # a plank's height; the ports, the tunnel's lips and decks fall on these lines
LINER_T = 0.7             # the shell's thickness, outer plank to inner
RIB_PITCH = 4.0
RIB_FIRST = 2.0           # ribs fall at +-2, +-6...: between the ports
PLANK_LIP = 0.11          # each strake stands this proud of the one above
WALE_LIP = 0.34
CEIL = COR_TOP + 1.8      # the underside of the upper deck's planks
DECK_Z = 15.0             # the upper deck (waist)

# Decks along the ship: the waist, the quarterdeck and poop aft, the forecastle.
BREAK_POOP = -30.0        # the quarterdeck's break
BREAK_HIGH = -44.0        # the poop's, over the quarterdeck
BREAK_FORE = 38.0
DECK_POOP = 22.0          # the quarterdeck
DECK_HIGH = 28.0          # the poop
DECK_FORE = 21.0
CROWN = 3.2               # the transom's arc over the poop rail

# Guns: six a side, on a ledge along each wall, muzzles out past the hull.
PORTS = (-40.0, -24.0, -8.0, 8.0, 24.0, 40.0)    # y; stern first
DUMMIES = (-48.0, -32.0, -16.0, 0.0, 16.0, 32.0)  # shut ports between, no gun behind
PORT_W = 3.0
PORT_ROWS = 3             # strakes tall
PORT_ROW = 10             # strake index of the port's sill: 6.2 to 9.8, round the bore
GUN_Z = 8.0
GUN_X = 16.25             # the muzzle's reach
GUN_LEN = 5.5
GUN_BORE_R = 0.5          # the barrel's reach at the muzzle
LEDGE_Z = 5.9             # the gun ledge along each wall

# The gun deck's light: drawn in ship_deck's shader, no real lights. Lanterns in the
# bays between the guns, sun through the gun ports (`PORTS`, on the sun's side). The
# relic's bay has no lantern, so it hangs in gloom. Lantern: x, height, pitch, the
# bays lit. Kept in step with the shader by write_materials.
LAMP_X = COR_W * 0.5 + 0.4
LAMP_Z = COR_TOP - 1.2
LAMP_BAYS = (-48.0, -32.0, -16.0, 16.0, 32.0, 48.0)
LAMP_PITCH = 16.0

# The masts: y, lower top, topmast top, truck. Trucks at the collision boxes' tops.
MASTS = (
	(22.0, 36.0, 48.0, 55.0),    # Mast_1, fore
	(-6.0, 38.0, 51.0, 59.0),    # Mast_2, main
	(-42.0, 39.0, 51.0, 51.0),   # Mast_3, mizzen, its topgallant shot away
)
MAST_R = 1.0
BRACE = -24.0             # the yards swung round (deg), so sails show from abeam
# Each mast's sails: (name, yard z, yard length, foot z, foot width, atlas cell, tilt deg).
SAILS = (
	(("1a", 34.0, 34.0, 21.5, 36.0, 0, 1.5), ("1b", 46.0, 26.0, 36.0, 33.0, 1, -3.0), ("1c", 54.0, 16.0, 47.0, 24.0, 2, 4.0)),
	(("2a", 36.0, 38.0, 19.5, 41.0, 1, -1.0), ("2b", 49.0, 30.0, 38.0, 37.0, 2, 2.0), ("2c", 57.5, 18.0, 50.0, 28.0, 0, -6.0)),
	(("3a", 37.0, 28.0, 27.0, 30.0, 2, 3.0), ("3b", 49.0, 22.0, 40.0, 27.0, 0, -9.0)),
)
BOWSPRIT = ((0.0, 47.0, 19.0), (0.0, 88.0, 35.0))

# Textures (px wide).
HULL_TEX = 4096
STERN_TEX = 2048
WOOD_TEX = 1024
WOOD_TILE = 6.0           # the tile's size (m)
SAIL_TEX = 2048
SAIL_CELL = (1.6, 0.9)    # a sail's mesh at most this coarse (m across, m down), before crowding to its edges
SAIL_MIN = (12, 8)        # and at least this many columns and rows
SAIL_SIZE = 64.0          # the vertex colour's scale: a sail's size (m) / this

WHITE = (1.0, 1.0, 1.0)
RAW = (0.95, 0.76, 0.54)    # fresh-broken wood, on the wood tile


def sstep(a, b, x):
	t = max(0.0, min(1.0, (x - a) / (b - a)))
	return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
	return a + (b - a) * t


def frange(a, b, step):
	n = max(1, int(round((b - a) / step)))
	return [a + (b - a) * i / n for i in range(n + 1)]


# --- The hull's shape ---------------------------------------------------------
# A station u along her (u = y off the rake), a base height z (the strake lines);
# `Side.p` lifts, rakes and wobbles them into the real surface.

def table(t, x):
	if x <= t[0][0]:
		return t[0][1]
	for (x0, y0), (x1, y1) in zip(t, t[1:]):
		if x <= x1:
			return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
	return t[-1][1]


def rail(u):
	"""The rail's height at station u: the sheer."""
	return table(SHEER, u)


def stem_y(z):
	"""The stem, raked: further forward the higher it goes."""
	return STEM_Y0 + STEM_RAKE * z


def ends(u):
	"""0 amidships, 1 at the stern's plate and the stem: how far the keel has risen."""
	return max(min(1.0, (-u - 30.0) / (STERN_U - 30.0)), min(1.0, (u - 30.0) / 42.0), 0.0) ** 2


def lift(u, z):
	"""A base height at station u, the keel risen toward both ends."""
	return z * (1.0 - KEEL_RISE * ends(u)) if z < 0.0 else z


def rake(u, z):
	"""How far aft (+) the counter leans out at station u, real height z; the sternpost
	tucks forward (-) under the exit."""
	if u >= -RAKE_FROM:
		return 0.0
	t = min(1.0, (-u - RAKE_FROM) / (STERN_U - RAKE_FROM)) ** 2
	return t * (COUNTER * max(0.0, z - COUNTER_Z) - TUCK * max(0.0, TUCK_Z - z))


def stern_y(z):
	"""The transom at real height z: upright round the exit, raked above and below."""
	return -STERN_U - rake(-STERN_U, z)


def half_beam(u, z):
	"""The hull's half width at station u, base height z (m): a plan that narrows all
	along, a run aft, and a prow that closes to the raked stem."""
	u = max(u, -STERN_U)
	w = table(SECTION, z) * (1.0 - 0.06 * (u / 58.0) ** 2)
	if u < -RUN_FROM:
		t = (-u - RUN_FROM) / (STERN_U - RUN_FROM)
		w *= 1.0 - lerp(0.55, 0.12, sstep(1.0, 3.8, z)) * t * t
		if z < 3.0:
			w = max(w, 1.0)
	if u > PROW_FROM:
		t = min(1.0, (u - PROW_FROM) / (stem_y(z) - PROW_FROM))
		w *= max(0.0, 1.0 - t ** 2.2) ** 0.5
	return w


def u_at(y, z):
	"""The station whose raked side stands at y, at real height z."""
	u = y
	for _ in range(4):
		u = y + rake(u, z)
	return u


def half_at(y, z):
	"""The hull's half width at a real y and height z (decks, galleries, dress)."""
	return half_beam(u_at(y, z), z)


def cross_y(z, x=TUNNEL_X):
	"""Where the prow's side at base height z comes in to x: the tunnel's mouth."""
	lo, hi = Y_BOW, stem_y(z)
	for _ in range(40):
		mid = (lo + hi) * 0.5
		if half_beam(mid, z) > x:
			lo = mid
		else:
			hi = mid
	return lo


def wobble(u, z):
	"""The hand-laid wander of strake line z, none at the cut's lips, the rail or the keel."""
	j = (z - KEEL_Z) / STRAKE
	k = sstep(0.4, 1.4, z) * min(1.0, abs(z - TUNNEL_LO) / STRAKE) * min(1.0, abs(z - TUNNEL_HI) / STRAKE)
	k *= min(1.0, max(0.0, rail(u) - z) / STRAKE)
	return WOBBLE * k * math.sin(u * 0.23 + j * 1.3)


def base_deck(y):
	if y < BREAK_HIGH:
		return DECK_HIGH
	if y < BREAK_POOP:
		return DECK_POOP
	if y > BREAK_FORE:
		return DECK_FORE
	return DECK_Z


class Surface:
	"""A hull face: p(u, z) with z a base height. n points outward."""
	out = (0.0, 0.0, 0.0)

	def p(self, u, z):
		raise NotImplementedError

	def n(self, u, z):
		e = 0.06
		a = self.p(u + e, z) - self.p(u - e, z)
		b = self.p(u, z + e) - self.p(u, z - e)
		nn = a.cross(b)
		if nn.length < 1e-9:
			return Vector(self.out)
		nn.normalize()
		return nn if nn.dot(self.out) >= 0 else -nn

	def uv(self, pt):
		raise NotImplementedError

	def stations(self, u0, u1):
		return frange(u0, u1, 2.5)


Z_BOT, Z_TOP = -8.0, 38.0
Y_BACK, Y_FORE = -76.0, 80.0


def hull_uv(pt):
	return ((pt.y - Y_BACK) / (Y_FORE - Y_BACK), (pt.z - Z_BOT) / (Z_TOP - Z_BOT))


class Side(Surface):
	"""A side of the hull, u from the transom to the stem, its top clipped to the rail."""

	def __init__(self, side, clip=True):
		self.s = side
		self.clip = clip
		self.out = (side, 0.0, 0.0)

	def p(self, u, z):
		u = min(u, stem_y(z))
		if self.clip:
			z = min(z, rail(u))
		zz = lift(u, z) + wobble(u, z)
		return Vector((self.s * half_beam(u, z), u + -rake(u, zz), zz))

	def uv(self, pt):
		return hull_uv(pt)

	def stations(self, u0, u1):
		# Close together round the prow and the stern's turn, closer still at the stem.
		out = [u0]
		y = u0
		while True:
			t = abs(y) / Y_BOW
			y += 1.1 if (y > 0 and t > 0.72) else (2.0 if t > 0.62 else 4.0)
			if y >= u1 - 0.3:
				break
			out.append(y)
		out.append(u1)
		if u1 > PROW_FROM + 20.0:
			out = sorted(set(q for q in out if q < u1 - 3.6) | {u1 - d for d in (3.4, 2.4, 1.6, 1.0, 0.55, 0.25, 0.08)} | {u1})
			out = [q for q in out if q >= u0]
		return out


class End(Surface):
	"""u is x. A flat end of the ship: the transom (-1), raked, or the bow's plate (+1)
	at the back of the tunnel."""

	def __init__(self, sign):
		self.sign = sign
		self.out = (0.0, sign, 0.0)

	def p(self, u, z):
		if self.sign > 0:
			return Vector((u, Y_BOW, z))
		zz = lift(-STERN_U, z)
		return Vector((u, stern_y(zz), zz))

	def half_w(self, z):
		return half_beam(Y_BOW if self.sign > 0 else -STERN_U, z)

	def uv(self, pt):
		return stern_uv(pt.x, pt.z)


END_SPAN = 30.0


def stern_uv(x, z):
	return ((x + END_SPAN * 0.5) / END_SPAN, (z - Z_BOT) / (Z_TOP - Z_BOT))


# --- The wound --------------------------------------------------------------

class Opening:
	"""An end of the ship: where the hull stops for the plug, what's left of the plug."""

	def __init__(self, surface, seed, shards):
		self.surf = surface
		self.rng = random.Random(seed)
		rng = random.Random(seed + 1)
		self.phase = [rng.uniform(0.0, math.tau) for _ in range(6)]
		self.seeds = []
		hw, hh = CRACK_W * 0.5, CRACK_H * 0.5
		while len(self.seeds) < shards:
			p = (rng.uniform(-hw, hw), rng.uniform(COR_Z - hh, COR_Z + hh))
			if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 > (hw * hh * 0.9 / shards) for q in self.seeds):
				self.seeds.append(p)
		self.memo = {}

	def shard_of(self, x, z):
		return min(range(len(self.seeds)), key=lambda i: (self.seeds[i][0] - x) ** 2 + ((self.seeds[i][1] - z) * 1.3) ** 2)

	def open_at(self, x, z):
		"""Whether the planking's gone here: round the middle, in wandering lumps."""
		f = self.phase
		lump = 0.5 + 0.25 * math.sin(x * 0.8 + f[0] + 1.4 * math.sin(z * 0.62 + f[1])) + 0.25 * math.sin(z * 1.25 + f[2] + 1.1 * math.sin(x * 0.55 + f[3]))
		e = ((abs(x) / (CRACK_W * 0.5)) ** 4 + (abs(z - COR_Z) / (CRACK_H * 0.5)) ** 4) ** 0.25
		return WOUND_OPEN * sstep(1.0, WOUND_EDGE, e) + WOUND_LUMP * (lump - 0.5) > WOUND_CUT

	def extent(self, j):
		"""The plug's reach (a, b) in x on strake j, or None."""
		if j in self.memo:
			return self.memo[j]
		z0, z1 = row_z(j), row_z(j + 1)
		zm = (z0 + z1) * 0.5
		rng = self.rng
		hit = None
		hw = CRACK_W * 0.5
		if z1 > COR_Z - CRACK_H * 0.5 + 0.01 and z0 < COR_Z + CRACK_H * 0.5 - 0.01:
			w = min(self.surf.half_w(zm), TUNNEL_X) - 0.25
			hit = (-min(w, hw + OPEN_MARGIN + rng.uniform(0.0, 0.9)), min(w, hw + OPEN_MARGIN + rng.uniform(0.0, 0.9)))
		self.memo[j] = hit
		return hit

	def runs(self, j):
		"""What stands of strake j: (x0, x1, torn at x0, torn at x1), in pieces."""
		a, b = self.extent(j)
		zm = (row_z(j) + row_z(j + 1)) * 0.5
		rng = self.rng
		out = []
		x = a
		was_open = False
		while x < b - 0.2:
			step = min(b - x, rng.uniform(0.7, BOARD_LEN))
			if b - x - step < 0.5:
				step = b - x
			gone = self.open_at(x + step * 0.5, zm)
			if not gone:
				out.append([x, x + step, was_open, False])
			elif out and out[-1][1] == x:
				out[-1][3] = True
			was_open = gone
			x += step
		return out


def row_z(j):
	return KEEL_Z + j * STRAKE


ROWS = int((rail(-STERN_U) - KEEL_Z) / STRAKE) + 1


def inner_light(p):
	"""Grime baked on the gun deck (0-1): the hold's corners and overhead. The light
	itself is the deck shader's, drawn over this, so no bay starves."""
	over = sstep(COR_TOP - 1.0, CEIL, p.z)
	wall = sstep(7.5 * WIDEN, 10.0 * WIDEN, abs(p.x))
	return 1.0 - 0.45 * over - 0.3 * wall


def inner(tint=WHITE, k=1.0):
	def f(p):
		l = inner_light(p) * k
		return (tint[0] * l, tint[1] * l, tint[2] * l)
	return f


# --- Mesh building ------------------------------------------------------------

MAT_NAMES = ("hull", "stern", "wood", "wood_in", "iron", "sail", "rope", "glass", "dark", "paint", "iron_in", "lamp", "plug")
M = {n: i for i, n in enumerate(MAT_NAMES)}


class Geo:
	"""A mesh by hand. Shared vertices shade smooth, unshared ones hard."""

	def __init__(self):
		self.v = []
		self.uv = []
		self.c = []
		self.f = []
		self.m = []

	def vert(self, p, uv=(0.0, 0.0), c=WHITE):
		self.v.append((p[0], p[1], p[2]))
		self.uv.append(uv)
		self.c.append(c(Vector(p)) if callable(c) else c)
		return len(self.v) - 1

	def face(self, ids, mat, hint=None):
		if hint is not None:
			a, b, c = (Vector(self.v[i]) for i in ids[:3])
			if (b - a).cross(c - a).dot(hint) < 0:
				ids = list(reversed(ids))
		self.f.append(tuple(ids))
		self.m.append(M[mat])

	def quad(self, a, b, c, d, mat, col=WHITE, hint=None, uvs=None, scale=None):
		"""A hard quad. The uvs, in metres over the tile unless given."""
		s = WOOD_TILE if scale is None else scale
		if uvs is None:
			w = (b - a).length / s
			h = (d - a).length / s
			r = (a.x * 0.13 + a.z * 0.11) % 1.0
			uvs = ((r, 0.0 + a.y * 0.07), (r + w, a.y * 0.07), (r + w, h + a.y * 0.07), (r, h + a.y * 0.07))
		ids = [self.vert(p, uv, col) for p, uv in zip((a, b, c, d), uvs)]
		self.face(ids, mat, hint)

	def beam(self, p0, p1, w, h, mat="wood", col=WHITE, up=(0.0, 0.0, 1.0)):
		"""A squared timber from p0 to p1, w wide across, h deep along `up`."""
		p0, p1 = Vector(p0), Vector(p1)
		d = (p1 - p0).normalized()
		upv = Vector(up)
		if abs(d.dot(upv)) > 0.98:
			upv = Vector((0.0, 1.0, 0.0)) if abs(d.y) < 0.9 else Vector((1.0, 0.0, 0.0))
		s = upv.cross(d).normalized() * (w * 0.5)
		u = d.cross(s).normalized() * (h * 0.5)
		c0 = [p0 - s - u, p0 + s - u, p0 + s + u, p0 - s + u]
		c1 = [p1 - s - u, p1 + s - u, p1 + s + u, p1 - s + u]
		mid = (p0 + p1) * 0.5
		for i in range(4):
			j = (i + 1) % 4
			hint = ((c0[i] + c0[j]) * 0.5 - p0)
			self.quad(c0[i], c0[j], c1[j], c1[i], mat, col, hint)
		self.quad(c0[0], c0[1], c0[2], c0[3], mat, col, p0 - mid)
		self.quad(c1[0], c1[1], c1[2], c1[3], mat, col, p1 - mid)

	def box(self, x0, x1, y0, y1, z0, z1, mat="wood", col=WHITE):
		self.beam(((x0 + x1) * 0.5, y0, (z0 + z1) * 0.5), ((x0 + x1) * 0.5, y1, (z0 + z1) * 0.5), x1 - x0, z1 - z0, mat, col)

	def tube(self, pts, radii, n=8, mat="wood", col=WHITE, cap=True, up=(0.0, 0.0, 1.0), squash=1.0):
		"""A smooth pipe through pts, a ring of n round each."""
		pts = [Vector(p) for p in pts]
		rings = []
		length = 0.0
		for i, p in enumerate(pts):
			d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
			if i:
				length += (p - pts[i - 1]).length
			upv = Vector(up)
			if abs(d.dot(upv)) > 0.95:
				upv = Vector((1.0, 0.0, 0.0)) if abs(d.x) < 0.9 else Vector((0.0, 1.0, 0.0))
			s = upv.cross(d).normalized()
			u = d.cross(s).normalized()
			ring = []
			for k in range(n + 1):
				a = k * math.tau / n
				q = p + (s * math.cos(a) + u * math.sin(a) * squash) * radii[i]
				ring.append(self.vert(q, (k / n * 1.2, length / WOOD_TILE), col))
			rings.append(ring)
		for a, b in zip(rings, rings[1:]):
			for k in range(n):
				self.face([a[k], a[k + 1], b[k + 1], b[k]], mat)
		if cap:
			for ring, p, sign in ((rings[0], pts[0], -1.0), (rings[-1], pts[-1], 1.0)):
				d = (pts[-1] - pts[0]).normalized() * sign
				ids = [self.vert(self.v[i], self.uv[i], col) for i in ring[:-1]]
				self.face(ids, mat, d)


def plank(g, S, u0, u1, z0, z1, mat="hull", col=WHITE, lip=PLANK_LIP, back=0.0, offset=0.0, jag=(False, False), peel=(0.0, 0.0), rng=None, teeth=None, stations=None, inward=False, tooth_off=0.0, end_col=(0.55, 0.42, 0.28), raw=None):
	"""One run of a strake on surface S, from u0 to u1, between base heights.

	`peel` springs an end out from the hull. `jag` leaves that end torn, its
	splinters added to `teeth` (a Geo, or g). `back` gives it a rear face that
	far inside, and ends; the plug's shards need it.
	"""
	if u1 - u0 < 0.05:
		return
	us = stations if stations is not None else S.stations(u0, u1)
	if peel[0] or peel[1]:
		us = sorted(set(us) | set(frange(u0, u1, 0.8)))
	zm = (z0 + z1) * 0.5
	L = 5.0
	rows = []
	for u in us:
		n = S.n(u, zm)
		off = offset + peel[0] * max(0.0, 1.0 - (u - u0) / L) ** 2 + peel[1] * max(0.0, 1.0 - (u1 - u) / L) ** 2
		a = S.p(u, z0)
		b = S.p(u, z1)
		lo = a + n * (off + lip)
		hi = b + n * off
		und = a + n * off
		rows.append((a, b, lo, hi, und, n, off))
	def vert(p):
		return g.vert(p, S.uv(p) if mat in ("hull", "stern", "wood_in", "wood") else (p.y / WOOD_TILE + p.x / WOOD_TILE, p.z / WOOD_TILE), col)
	ids = [(vert(r[2]), vert(r[3]), vert(r[4])) for r in rows]
	for k in range(len(ids) - 1):
		lo0, hi0, un0 = ids[k]
		lo1, hi1, un1 = ids[k + 1]
		hint = -rows[k][5] if inward else rows[k][5]
		g.face([lo0, lo1, hi1, hi0], mat, hint)
		if lip > 0.01:
			g.face([un0, un1, lo1, lo0], mat, Vector((0.0, 0.0, -1.0)))
	if back > 0.0:
		dark = (0.1, 0.09, 0.08)
		bk = [(g.vert(r[0] + r[5] * (r[6] - back), S.uv(r[0]) if mat in ("hull", "stern") else (0, 0), dark),
			g.vert(r[1] + r[5] * (r[6] - back), S.uv(r[1]) if mat in ("hull", "stern") else (0, 0), dark)) for r in rows]
		for k in range(len(bk) - 1):
			g.face([bk[k][0], bk[k][1], bk[k + 1][1], bk[k + 1][0]], mat, -rows[k][5])
			g.quad(rows[k][2], rows[k + 1][2], rows[k + 1][4] + rows[k + 1][5] * (-back), rows[k][4] + rows[k][5] * (-back), "wood", col=(0.1, 0.08, 0.07), hint=Vector((0, 0, -1)))
			g.quad(rows[k][3], rows[k + 1][3], rows[k + 1][1] + rows[k + 1][5] * (rows[k + 1][6] - back), rows[k][1] + rows[k][5] * (rows[k][6] - back), "wood", col=(0.1, 0.08, 0.07), hint=Vector((0, 0, 1)))
	# The ends.
	for end, sign, r in ((0, -1.0, rows[0]), (1, 1.0, rows[-1])) if not inward else ():
		along = S.p(us[0 if end == 0 else -1] + sign * 0.1, zm) - S.p(us[0 if end == 0 else -1], zm)
		if along.length > 1e-6:
			g.quad(r[2], r[3], r[1] + r[5] * (r[6] - max(back, 0.25)), r[0] + r[5] * (r[6] - max(back, 0.25)), "wood", col=end_col, hint=along)
		if jag[end] and rng is not None:
			splinters(teeth if teeth is not None else g, S, us[0 if end == 0 else -1], sign, z0, z1, r[6] + tooth_off, rng, TOOTH if teeth is not None else 1.9, raw)


def splinters(g, S, u, sign, z0, z1, off, rng, tooth=TOOTH, raw=None):
	"""Torn wood at a plank's end: tapered tips, by default in fresh-broken colour."""
	n = rng.randint(2, 4)
	edges = sorted([z0, z1] + [rng.uniform(z0, z1) for i in range(n - 1)])
	for a, b in zip(edges, edges[1:]):
		reach = rng.uniform(0.2, 1.0) ** 1.6 * tooth
		zt = lerp(a, b, rng.random())
		nn = S.n(u, (a + b) * 0.5)
		root_a = S.p(u, a) + nn * off
		root_b = S.p(u, b) + nn * off
		tip = S.p(u + sign * reach, zt) + nn * (off + rng.uniform(0.0, 0.35))
		back_a = root_a - nn * 0.22
		back_b = root_b - nn * 0.22
		root_lip_a = root_a + nn * PLANK_LIP
		tint = rng.uniform(0.75, 1.15)
		base = RAW if raw is None else raw
		c = (base[0] * tint, base[1] * tint, base[2] * tint)
		along = Vector(tip - (root_a + root_b) * 0.5)
		for tri in ((root_lip_a, root_b, tip), (back_b, back_a, tip), (root_a, back_a, tip), (back_b, root_b, tip)):
			ids = [g.vert(p, (p.x * 0.3, p.z * 0.3 + p.y * 0.3), c) for p in tri]
			g.face(ids, "wood")


# --- The shell ----------------------------------------------------------------

def spans_of(cuts, a, b):
	"""[a, b] with the (lo, hi) `cuts` taken out, with which ends are torn."""
	out = []
	at, torn = a, False
	for lo, hi in sorted(cuts):
		if hi <= at or lo >= b:
			continue
		if lo > at:
			out.append((at, lo, torn, True))
		at, torn = max(at, hi), True
	if at < b:
		out.append((at, b, torn, False))
	return out


def rail_spans(z0, u0=-STERN_U, u1=90.0):
	"""Stretches of stations where a strake from base height z0 stands under the rail:
	each runs out to a sliver where the sheer comes down to it."""
	def under(u):
		return rail(u) > z0 + 0.05
	us = frange(u0, u1, 0.5)
	out = []
	start = u0 if under(u0) else None
	for a, b in zip(us, us[1:]):
		if under(a) != under(b):
			lo, hi = a, b
			for _ in range(30):
				m = (lo + hi) * 0.5
				if under(m) == under(a):
					lo = m
				else:
					hi = m
			x = (lo + hi) * 0.5
			if start is None:
				start = x
			else:
				out.append((start, x))
				start = None
	if start is not None:
		out.append((start, u1))
	return out


def strake_end(z0, z1):
	"""How far forward strake z0..z1 runs: to the stem, or to the tunnel's mouth."""
	if z0 >= TUNNEL_LO - 0.01 and z1 <= TUNNEL_HI + 0.01:
		return cross_y((z0 + z1) * 0.5)
	return stem_y(max(z0, z1))


def shot_holes(rng):
	"""Holes in the hull, (side, row, y0, y1), dark behind the liner."""
	out = []
	for side in (-1, 1):
		for _ in range(7):
			y = rng.uniform(-46.0, 44.0)
			j = rng.randrange(PORT_ROW + PORT_ROWS + 1, int((DECK_Z - KEEL_Z) / STRAKE) + 1)
			for k in range(rng.randint(1, 3)):
				w = rng.uniform(1.2, 3.4)
				dy = rng.uniform(-1.0, 1.0)
				out.append((side, j + k, y + dy - w * 0.5, y + dy + w * 0.5))
	return out


def build_end(g, teeth, shards, sign, op, rng):
	"""A flat end across the ship, strake by strake, round the plug: the whole transom
	aft, the tunnel's back forward."""
	T = op.surf
	if sign < 0:
		top, crown, bottom = rail(-STERN_U), CROWN, KEEL_Z
	else:
		top, crown, bottom = TUNNEL_HI, 0.0, TUNNEL_LO
	for j in range(ROWS + 4):
		z0, z1 = row_z(j), row_z(j + 1)
		zm = (z0 + z1) * 0.5
		if z0 < bottom - 0.01 or z0 > top + crown - 0.01 or (sign > 0 and z1 > top + 0.01):
			continue
		w = T.half_w(zm)
		if w < 0.5:
			continue
		if zm > top:
			w *= math.sqrt(max(0.0, 1.0 - ((zm - top) / max(crown, 0.1)) ** 2))
		if w < 0.3:
			continue
		ext = op.extent(j)
		cuts = [ext] if ext else []
		for a, b, t0, t1 in spans_of(cuts, -w, w):
			plank(g, T, a, b, z0, z1, "stern", lip=0.08, jag=(t0, t1), rng=rng, teeth=teeth, stations=frange(a, b, 3.0), tooth_off=-PLUG_RECESS - 0.3, end_col=WEATHERED, raw=WEATHERED)
	build_plug(op, shards, rng)


WEATHERED = (0.2, 0.155, 0.115)    # a torn hull plank's end, on the wood tile


def board(g, at, uv, s0, s1, t0, t1, rng, torn=(False, False), spring=(0.0, 0.0), sag=(0.0, 0.0), tone=1.0, thick=BOARD_T):
	"""A plank, broken by hand: slivers along the grain, s along it, t across.

	`at(s, t, off)` is a point, `off` out of the hull; `uv` its map place. A torn
	end leaves the slivers at different lengths, tapering, the way wood goes; it
	stands out by `spring` and hangs by `sag`, over the last few metres.
	"""
	n = 3 if t1 - t0 > 0.6 else 2
	cuts = sorted([t0, t1] + [rng.uniform(t0 + 0.12, t1 - 0.12) for _ in range(n - 1)])
	face = (0.5 * (t0 + t1))
	length = s1 - s0
	for a, b in zip(cuts, cuts[1:]):
		reach = [rng.uniform(0.15, 1.0) ** 2.2 * FINGER if torn[e] else 0.0 for e in (0, 1)]
		sa, sb = s0 + reach[0], s1 - reach[1]
		if sb - sa < 0.15:
			continue
		nudge = rng.uniform(-0.05, 0.05)
		sts = frange(sa, sb, 1.0 if spring[0] or spring[1] or sag[0] or sag[1] else 99.0)
		def row(st, end):
			w0 = max(0.0, 1.0 - (st - s0) / max(length, 2.0)) ** 2
			w1 = max(0.0, 1.0 - (s1 - st) / max(length, 2.0)) ** 2
			off = nudge + spring[0] * w0 + spring[1] * w1
			drop = sag[0] * w0 + sag[1] * w1
			ta, tb = a, b
			if end is not None and torn[end]:
				tip = lerp(a, b, rng.uniform(0.15, 0.85))
				k = rng.uniform(0.45, 0.95)
				ta, tb = lerp(a, tip, k), lerp(b, tip, k)
			return ((at(st, ta - drop, off), at(st, tb - drop, off)), (at(st, ta - drop, off - thick), at(st, tb - drop, off - thick)))
		rows = [row(st, 0 if i == 0 else (1 if i == len(sts) - 1 else None)) for i, st in enumerate(sts)]
		lit = (tone, tone, tone)
		side = (tone * BROKE[0], tone * BROKE[1], tone * BROKE[2])
		rear = (0.5, 0.42, 0.34)
		def tag(p, c):
			return g.vert(p, uv(p), c)
		def clean(p, c):
			# The back and the torn edges: the map's clear wood, up the transom.
			u, v = uv(p)
			return g.vert(p, (u, v + 0.42), c)
		for k in range(len(rows) - 1):
			(fa, fb), (ba, bb) = rows[k]
			(fc, fd), (bc, bd) = rows[k + 1]
			out = (fc - fa).cross(fb - fa)
			if out.dot(Vector(at(s0, face, 1.0)) - Vector(at(s0, face, 0.0))) < 0:
				out = -out
			g.face([tag(fa, lit), tag(fc, lit), tag(fd, lit), tag(fb, lit)], "plug", out)
			g.face([clean(ba, rear), clean(bc, rear), clean(bd, rear), clean(bb, rear)], "plug", -out)
			for p, q, r, t, way in ((fa, fc, bc, ba, fa - fb), (fb, fd, bd, bb, fb - fa)):
				g.face([clean(p, side), clean(q, side), clean(r, side), clean(t, side)], "plug", way)
		for e, idx, way in ((0, 0, -1.0), (1, -1, 1.0)):
			(fa, fb), (ba, bb) = rows[idx]
			along = Vector(at(s1, face, 0.0)) - Vector(at(s0, face, 0.0))
			g.face([clean(fa, side), clean(fb, side), clean(bb, side), clean(ba, side)], "plug", along * way)


def plate_at(T, u, z):
	"""A point in the plate's plane. Below the corridor's floor the bow's real
	surface runs out along the beak, which this ignores."""
	mid = T.p(0.0, COR_Z)
	up = T.p(0.0, COR_Z + 1.0).y - mid.y
	return Vector((u, mid.y + up * (z - COR_Z), z))


def build_cover(op):
	"""Black behind the plug, facing out only, so a gap is dark from every range and
	the far end's daylight stays out of it. From inside it isn't there, so the exit
	shows through the gaps. Code hides it on a burst."""
	T = op.surf
	g = Geo()
	nrm = T.n(0.0, COR_Z)
	w, lo, hi = CRACK_W * 0.5 + OPEN_MARGIN + 1.0, COR_Z - CRACK_H * 0.5 - 0.05, COR_Z + CRACK_H * 0.5 + 0.05
	c = [plate_at(T, x, z) - nrm * COVER_BACK for x, z in ((-w, lo), (w, lo), (w, hi), (-w, hi))]
	g.quad(*c, "dark", (0.008, 0.007, 0.006), hint=nrm)
	return g


def build_plug(op, shards, rng):
	"""What's left of the planking in a plate, and the frames that keep it shut.

	Thin boards on thin frames, nothing past the plate's depth. Every piece is
	short, so a shard is a board or two and a burst throws wood, not panels.
	"""
	T = op.surf
	nrm = T.n(0.0, COR_Z)
	def at_row(u, z, off):
		return plate_at(T, u, z) + nrm * (off - PLUG_RECESS)
	def uv(p):
		return T.uv(p)
	total = kept = 0.0
	loose = []
	for j in range(ROWS + 4):
		if op.extent(j) is None:
			continue
		z0, z1 = row_z(j), row_z(j + 1)
		zm = (z0 + z1) * 0.5
		a, b = op.extent(j)
		total += b - a
		for x0, x1, t0, t1 in op.runs(j):
			kept += x1 - x0
			tone = PLUG_TONE * rng.uniform(0.75, 1.2)
			spring = (rng.uniform(0.15, SPRUNG) if t0 and rng.random() < 0.5 else 0.0, rng.uniform(0.15, SPRUNG) if t1 and rng.random() < 0.5 else 0.0)
			sag = (rng.uniform(0.1, SAG) if t0 and rng.random() < 0.55 else 0.0, rng.uniform(0.1, SAG) if t1 and rng.random() < 0.55 else 0.0)
			lab = op.shard_of((x0 + x1) * 0.5, zm)
			board(shards[lab], at_row, uv, x0, x1, z0 + 0.012, z1 - 0.012, rng, (t0, t1), spring, sag, tone)
			if t0 or t1:
				loose.append((x0 if t0 else x1, zm, -1.0 if t0 else 1.0))
	# Frames, behind the planks: long timbers in short lengths, a snap in each.
	for fx in FRAME_X:
		zlo, zhi = COR_Z - CRACK_H * 0.5 - 0.1, COR_Z + CRACK_H * 0.5 + 0.1
		z = zlo
		lean = rng.uniform(-0.05, 0.05)
		while z < zhi - 0.3:
			step = min(zhi - z, rng.uniform(1.6, 2.8))
			gap = rng.uniform(0.0, 0.9) if rng.random() < 0.3 else 0.0
			def at_frame(s, t, off, fx=fx, lean=lean):
				return at_row(fx + t + (s - COR_Z) * lean, s, off - 0.36)
			lab = op.shard_of(fx, z + step * 0.5)
			tone = PLUG_TONE * rng.uniform(0.55, 0.85)
			board(shards[lab], at_frame, uv, z + gap, z + step, -FRAME_W * 0.5, FRAME_W * 0.5, rng, (gap > 0.0, gap > 0.0 or rng.random() < 0.2), tone=tone, thick=0.42)
			z += step
	# Planks torn loose: each hangs from a broken end, down across the hole.
	rng.shuffle(loose)
	for x, z, way in loose[:HANGERS]:
		a = math.radians(rng.uniform(52.0, 118.0)) * way
		ln = rng.uniform(1.6, BOARD_LEN + 0.5)
		root = Vector((x, 0.0, z))
		d = Vector((math.sin(a), 0.0, -abs(math.cos(a))))
		side = d.cross(Vector((0.0, 1.0, 0.0))).normalized()
		out = rng.uniform(0.08, 0.5)
		def at_hang(s, t, off, root=root, d=d, side=side, out=out):
			q = root + d * s + side * t
			return plate_at(T, q.x, q.z) + nrm * (off + out * s - PLUG_RECESS)
		lab = op.shard_of(x + d.x * ln * 0.5, z + d.z * ln * 0.5)
		board(shards[lab], at_hang, uv, -0.3, ln, -0.3, 0.3, rng, (False, True), tone=PLUG_TONE * rng.uniform(0.7, 1.1))
	print(f"plug: {kept / total:.0%} of the plate's planking stands")


def build_hull(crack_s, crack_b, shards):
	rng = random.Random(11)
	g = Geo()          # the shell
	teeth = Geo()      # torn ends, on the wood tile: part of Hull
	holes = shot_holes(rng)
	for side in (-1.0, 1.0):
		S = Side(side)
		for j in range(ROWS):
			z0, z1 = row_z(j), row_z(j + 1)
			for ra, rb in rail_spans(z0):
				y0 = max(ra, -STERN_U)
				y1 = min(rb, strake_end(z0, z1))
				if y1 - y0 < 0.1:
					continue
				cuts = []
				if PORT_ROW <= j < PORT_ROW + PORT_ROWS:
					for py in PORTS:
						cuts.append((py - PORT_W * 0.5, py + PORT_W * 0.5))
				for hs, hj, h0, h1 in holes:
					if hs == side and hj == j:
						cuts.append((h0, h1))
				wale = j in (ROW_LO, ROW_HI - 1, ROW_RAIL - 1)
				lip = WALE_LIP if wale else PLANK_LIP
				for a, b, t0, t1 in spans_of(cuts, y0, y1):
					near_port = PORT_ROW <= j < PORT_ROW + PORT_ROWS
					plank(g, S, a, b, z0, z1, "hull", lip=lip, jag=(t0 and not near_port, t1 and not near_port), rng=rng, teeth=teeth)
	build_end(g, teeth, shards[0], -1.0, crack_s, rng)
	build_end(g, teeth, shards[1], 1.0, crack_b, rng)
	build_bottom(g)
	return g, teeth


ROW_LO = int(round((TUNNEL_LO - KEEL_Z) / STRAKE))     # the strake on the tunnel's floor
ROW_HI = int(round((TUNNEL_HI - KEEL_Z) / STRAKE))     # the one over its roof
ROW_RAIL = int(round((17.0 - KEEL_Z) / STRAKE))        # the waist's rail


def build_bottom(g):
	"""The flat of her floor between the garboards, the keel's line risen at the ends."""
	S0, S1 = Side(-1.0), Side(1.0)
	z = KEEL_Z
	us = frange(-STERN_U, stem_y(z), 2.0)
	for a, b in zip(us, us[1:]):
		g.quad(S0.p(a, z), S1.p(a, z), S1.p(b, z), S0.p(b, z), "hull", (0.5, 0.45, 0.4), hint=Vector((0, 0, -1)), uvs=[hull_uv(S0.p(a, z)), hull_uv(S1.p(a, z)), hull_uv(S1.p(b, z)), hull_uv(S0.p(b, z))])


def build_tunnel(g):
	"""The prow's cut: walls back to the bow's plate, the lips' faces over and under the
	way out, and timbers round the opening, all outside the exit's rectangle."""
	lining = (0.16, 0.12, 0.095)
	rng = random.Random(71)
	for s in (-1.0, 1.0):
		# The walls: planks along her at x +-TUNNEL_X, from the plate to the mouth.
		for j in range(ROW_LO, ROW_HI):
			z0, z1 = row_z(j), row_z(j + 1)
			y1 = cross_y((z0 + z1) * 0.5)
			t = rng.uniform(0.75, 1.1)
			a, b = Vector((s * TUNNEL_X, Y_BOW - 0.3, z0)), Vector((s * TUNNEL_X, y1 + 0.2, z0))
			c, d = Vector((s * TUNNEL_X, y1 + 0.2, z1 - 0.03)), Vector((s * TUNNEL_X, Y_BOW - 0.3, z1 - 0.03))
			g.quad(a, b, c, d, "wood", (lining[0] * t, lining[1] * t, lining[2] * t), hint=Vector((-s, 0, 0)))
		# The cut's edge up the side, a timber, and one along each lip to the stem.
		side = [(s * TUNNEL_X + s * 0.2, cross_y(z), z) for z in frange(TUNNEL_LO - 0.3, TUNNEL_HI + 0.3, 1.2)]
		g.tube(side, [CUT_R] * len(side), 8, "wood", (0.2, 0.15, 0.11))
		for z, zt in ((TUNNEL_LO, TUNNEL_LO - CUT_R), (TUNNEL_HI, TUNNEL_HI + CUT_R)):
			edge = [(s * (half_beam(y, z) + 0.1), y, zt) for y in frange(cross_y(z), stem_y(z) - 0.6, 1.4)]
			g.tube(edge, [CUT_R] * len(edge), 8, "wood", (0.2, 0.15, 0.11))
	# The lips' faces: the floor up, the roof down, the hull's width to the stem.
	for z, up, col in ((TUNNEL_LO, 1.0, (0.2, 0.165, 0.13)), (TUNNEL_HI, -1.0, lining)):
		ys = frange(Y_BOW - 0.3, stem_y(z) - 0.02, 1.0)
		for a, b in zip(ys, ys[1:]):
			wa, wb = half_beam(a, z), half_beam(b, z)
			g.quad(Vector((-wa, a, z)), Vector((wa, a, z)), Vector((wb, b, z)), Vector((-wb, b, z)), "wood", col, hint=Vector((0, 0, up)))
	# A stone boss at the stem's head, over the cut.
	y = stem_y(14.0)
	g.box(-1.6, 1.6, y - 2.4, y + 0.6, 13.6, 16.6, "paint", STONE)


STONE = (0.14, 0.138, 0.134)


def build_timbers(g):
	"""Keel, stem, sternpost, rudder, the transom's corner posts."""
	dk = (0.05, 0.036, 0.027)
	tim = (0.34, 0.28, 0.22)
	# The stem, up the prow's edge: under the cut, and from over it to the rail.
	for z0, z1 in ((KEEL_Z, TUNNEL_LO - 0.2), (TUNNEL_HI + 0.2, rail(Y_BOW) + 0.8)):
		zs = frange(z0, z1, 1.0)
		pts = [(0.0, stem_y(z) - 0.15, lift(stem_y(z), z)) for z in zs]
		for a, b in zip(pts, pts[1:]):
			g.beam(a, b, 0.8, 0.8, "wood", tim, up=(1.0, 0.0, 0.0))
	# The keel, rising to both ends.
	us = frange(-STERN_U + 1.0, stem_y(KEEL_Z), 4.0)
	pts = [(0.0, u, lift(u, KEEL_Z) - 0.2) for u in us]
	for a, b in zip(pts, pts[1:]):
		g.beam(a, b, 1.0, 0.5, "wood", tim)
	# The rudder, hung on the tucked sternpost: its head stops short of the plug.
	for z0, z1, w in ((lift(-STERN_U, KEEL_Z), -0.5, 4.0), (-0.5, COR_FLOOR - 0.6, 2.6)):
		zm = (z0 + z1) * 0.5
		ry = stern_y(zm) - 0.15
		g.beam((0.0, ry - w * 0.5, z0), (0.0, ry - w * 0.5, z1), 0.7, w, "wood", tim, up=(0.0, 1.0, 0.0))
	# The transom's corner posts, up the counter's lean.
	for s in (-1.0, 1.0):
		zs = frange(3.8, rail(-STERN_U), 1.5)    # above the tuck's flare, clear of the exit
		pts = [(s * half_beam(-STERN_U, z), stern_y(lift(-STERN_U, z)), lift(-STERN_U, z)) for z in zs]
		for a, b in zip(pts, pts[1:]):
			g.beam(a, b, 1.0, 1.0, "paint", dk, up=(0.0, 1.0, 0.0))


def build_port_frames(g):
	"""The reveal through the shell at each port, and the sill's timber."""
	for side in (-1.0, 1.0):
		S = Side(side)
		z0, z1 = row_z(PORT_ROW), row_z(PORT_ROW + PORT_ROWS)
		for y in sorted(PORTS + DUMMIES):
			a0, a1 = y - PORT_W * 0.5, y + PORT_W * 0.5
			n = S.n(y, (z0 + z1) * 0.5)
			c = [S.p(a0, z0), S.p(a1, z0), S.p(a1, z1), S.p(a0, z1)]
			i = [p - n * LINER_T for p in c]
			dk = (0.08, 0.06, 0.05)
			if y in PORTS:
				for k in range(4):
					m = (k + 1) % 4
					mid = (c[k] + c[m]) * 0.5
					cen = (c[0] + c[2]) * 0.5
					g.quad(c[k], c[m], i[m], i[k], "wood", dk, hint=cen - mid)
			else:
				# Shut: a lid in its frame, no hole, no gun.
				g.quad(c[0] + n * 0.12, c[1] + n * 0.12, c[2] + n * 0.12, c[3] + n * 0.12, "wood", (0.1, 0.075, 0.055), hint=n)
			# Timber round the port, standing proud: the row of squares that says gun deck.
			o = n * 0.16
			frame = (0.075, 0.055, 0.042)
			g.beam(c[0] + o, c[1] + o, 0.34, 0.3, "wood", frame, up=n)
			g.beam(c[3] + o, c[2] + o, 0.34, 0.3, "wood", frame, up=n)
			g.beam(c[0] + o, c[3] + o, 0.34, 0.3, "wood", frame, up=n)
			g.beam(c[1] + o, c[2] + o, 0.34, 0.3, "wood", frame, up=n)


def build_lids():
	"""One lid a port, hinged at its head, raised. Red inside, as they were."""
	out = []
	rng = random.Random(31)
	h = (row_z(PORT_ROW + PORT_ROWS) - row_z(PORT_ROW))
	for side in (-1.0, 1.0):
		S = Side(side)
		label = "R" if side > 0 else "L"
		for i, y in enumerate(PORTS):
			roll = rng.random()
			if side < 0 and i == 3:
				continue    # torn off
			z1 = row_z(PORT_ROW + PORT_ROWS)
			hinge = S.p(y, z1) + S.n(y, z1) * 0.1
			g = Geo()
			w = PORT_W * 0.54
			open_a = math.radians(rng.uniform(58.0, 82.0))
			skew = math.radians(rng.uniform(-3.0, 3.0))
			if roll < 0.28:
				open_a = math.radians(rng.uniform(5.0, 28.0))
				skew = math.radians(rng.uniform(-18.0, 18.0))
			out_v = S.n(y, z1)
			along = Vector((0.0, 1.0, 0.0))
			down = -math.cos(open_a) * Vector((0.0, 0.0, 1.0)) + math.sin(open_a) * out_v
			along2 = along * math.cos(skew) + Vector((0.0, 0.0, 1.0)) * math.sin(skew)
			nn = along2.cross(down).normalized()
			if nn.dot(out_v) < 0:
				nn = -nn
			corners = [along2 * -w, along2 * w, along2 * w + down * h, along2 * -w + down * h]
			t = nn * 0.2
			outer = (0.13, 0.095, 0.07)
			red = (0.09, 0.085, 0.08)
			g.quad(*corners, "wood", outer, hint=nn + Vector((0, 0, 0.001)))
			back = [p - t for p in corners]
			g.quad(*back, "paint", red, hint=-nn)
			for k in range(4):
				m = (k + 1) % 4
				g.quad(corners[k], corners[m], back[m], back[k], "wood", outer, hint=(corners[k] + corners[m]) * 0.5 - (corners[0] + corners[2]) * 0.5)
			out.append((f"PortLid_{label}_{i + 1:02d}", g, hinge))
	return out


def liner(g, upper):
	"""The shell's inner face: dark on the gun deck, plain over the upper deck."""
	for side in (-1.0, 1.0):
		class Inner(Side):
			def uv(self, pt):
				return (pt.y / WOOD_TILE, pt.z / WOOD_TILE)
		S = Inner(side)
		for j in range(ROWS):
			z0, z1 = row_z(j), row_z(j + 1)
			zm = (z0 + z1) * 0.5
			if z1 < COR_FLOOR - 0.1:
				continue
			gun_deck = z0 < DECK_Z
			for ra, rb in rail_spans(z0):
				y0 = max(ra, -STERN_U) + 0.3
				y1 = min(rb, Y_BOW if TUNNEL_LO - 0.01 <= z0 and z1 <= TUNNEL_HI + 0.01 else strake_end(z0, z1)) - 0.3
				if y1 - y0 < 0.1:
					continue
				cuts = []
				if PORT_ROW <= j < PORT_ROW + PORT_ROWS:
					cuts = [(py - PORT_W * 0.5, py + PORT_W * 0.5) for py in PORTS]
				for a, b, _, _ in spans_of(cuts, y0, y1):
					col = inner((0.75, 0.62, 0.5)) if gun_deck else (0.42, 0.34, 0.27)
					plank(g if gun_deck else upper, S, a, b, z0, z1, "wood_in" if gun_deck else "wood", col=col, lip=0.0, offset=-LINER_T, inward=True, stations=frange(a, b, 2.0 if gun_deck else 5.0))


def deck_strip(g, z_fn, y0, y1, width_fn, col, step=4.0, plank_w=1.1, mat="wood"):
	"""A deck of long planks across the hull's width, y0 to y1."""
	wmax = max(width_fn(y) for y in frange(y0, y1, 3.0))
	n = int(wmax * 2.0 / plank_w) + 1
	rng = random.Random(int(abs(y0 * 7 + y1)) + 3)
	for i in range(n):
		a, b = -wmax + i * plank_w, -wmax + (i + 1) * plank_w
		ta = rng.uniform(0.75, 1.1)
		def tinted(p, t=ta):
			c = col(p) if callable(col) else col
			return (c[0] * t, c[1] * t, c[2] * t)
		prev = None
		for y in frange(y0, y1, step):
			w = max(0.05, width_fn(y))
			xa, xb = max(-w, min(w, a)), max(-w, min(w, b))
			z = z_fn(y)
			r = (g.vert((xa, y, z), (xa * 0.5 / WOOD_TILE * 3.0, y / WOOD_TILE), tinted), g.vert((xb - 0.04, y, z), ((xb - 0.04) * 0.5 / WOOD_TILE * 3.0, y / WOOD_TILE), tinted))
			if prev is not None and xb - xa > 0.02:
				g.face([prev[0], prev[1], r[1], r[0]], mat, Vector((0.0, 0.0, 1.0 if z > COR_FLOOR + 1 and z > CEIL + 0.1 or z < COR_FLOOR else -1.0)))
			prev = r


def crate(g, side, x, y, z, s, hh, rng, col, band):
	a = rng.uniform(-0.15, 0.15)
	c, sn = math.cos(a), math.sin(a)
	px = (side * (x - s * 0.5 * c), y - s * 0.5 * sn, z + hh * 0.5)
	qx = (side * (x + s * 0.5 * c), y + s * 0.5 * sn, z + hh * 0.5)
	g.beam(px, qx, s, hh, "wood_in", col)
	g.beam(px, qx, s + 0.05, 0.14, "iron_in", band)


def barrel(g, side, x, y, z, r, col, band):
	h = r * 2.5
	pts = [(side * x, y, z + h * t) for t in (0.0, 0.26, 0.5, 0.74, 1.0)]
	g.tube(pts, [r * 0.82, r, r * 1.04, r, r * 0.82], 8, "wood_in", col)
	for t in (0.2, 0.8):
		g.tube([(side * x, y, z + h * t - 0.06), (side * x, y, z + h * t + 0.06)], [r * 1.0, r * 1.0], 8, "iron_in", band, cap=False)


def build_interior(g):
	"""The gun deck: floor, ceiling, beams, ribs, posts, ledges, cargo. All outside the corridor."""
	half_cor = COR_W * 0.5
	wall = half_cor + 0.06       # nothing stands nearer the middle than this
	inner_end = COR_LEN * 0.5
	for z, up in ((COR_FLOOR - 0.12, 1.0), (CEIL + 0.1, -1.0)):
		w = BEAM * 0.5 - 1.3
		g.quad(Vector((-w, -inner_end, z)), Vector((w, -inner_end, z)), Vector((w, inner_end, z)), Vector((-w, inner_end, z)), "dark", (0.008, 0.007, 0.006), hint=Vector((0, 0, up)))
	floor_w = lambda y: half_beam(y, COR_FLOOR + 0.6) - LINER_T
	y0, y1 = -inner_end - 1.0, inner_end + 1.0
	# The floor, with a worn pale run down the middle so speed shows on it.
	def worn(p):
		l = inner_light(p)
		k = 1.0 + 0.6 * max(0.0, 1.0 - abs(p.x) / (5.0 * WIDEN))
		return (0.62 * l * k, 0.52 * l * k, 0.42 * l * k)
	deck_strip(g, lambda y: COR_FLOOR - 0.03, y0, y1, floor_w, worn, 2.0, 1.25, mat="wood_in")
	ceil_w = lambda y: half_beam(y, CEIL - 0.3) - LINER_T
	def under(p):
		l = inner_light(p) * 0.55
		return (0.5 * l, 0.42 * l, 0.33 * l)
	deck_strip(g, lambda y: CEIL, y0, y1, ceil_w, under, 3.0, 1.6, mat="wood_in")
	c_beam = inner((0.52, 0.43, 0.33))
	c_rib = inner((0.6, 0.47, 0.34))
	c_iron = inner((0.14, 0.14, 0.145))
	dark_rib = inner((0.34, 0.27, 0.2))
	# Gratings let into the floor, flush, a dark beat down the middle.
	for y in frange(-48.0, 48.0, 24.0):
		g.quad(Vector((-3.0, y - 3.0, COR_FLOOR - 0.01)), Vector((3.0, y - 3.0, COR_FLOOR - 0.01)), Vector((3.0, y + 3.0, COR_FLOOR - 0.01)), Vector((-3.0, y + 3.0, COR_FLOOR - 0.01)), "dark", (0.01, 0.009, 0.008), hint=Vector((0, 0, 1)))
		for x in frange(-2.8, 2.8, 0.8):
			g.quad(Vector((x - 0.14, y - 3.0, COR_FLOOR - 0.005)), Vector((x + 0.14, y - 3.0, COR_FLOOR - 0.005)), Vector((x + 0.14, y + 3.0, COR_FLOOR - 0.005)), Vector((x - 0.14, y + 3.0, COR_FLOOR - 0.005)), "wood_in", dark_rib, hint=Vector((0, 0, 1)))
	ribs = []
	y = RIB_FIRST
	while y < inner_end + 0.5:
		ribs += [y, -y]
		y += RIB_PITCH
	ribs.sort()
	for i, y in enumerate(ribs):
		w = half_beam(y, COR_TOP) - LINER_T
		# The deck beam, above the corridor's roof.
		g.beam((-w, y, COR_TOP + 0.62), (w, y, COR_TOP + 0.62), 0.75, 1.1, "wood_in", c_beam)
		for side in (-1.0, 1.0):
			# The rib, up the inside of the shell.
			pts = [(side * max(half_beam(y, z) - LINER_T - 0.28, wall + 0.28), y, z) for z in frange(COR_FLOOR, CEIL, 2.4)]
			for a, b in zip(pts, pts[1:]):
				g.beam(a, b, 0.5, 0.56, "wood_in", c_rib, up=(0.0, 1.0, 0.0))
			# The hanging knee.
			g.beam((side * wall - side * 0.0 + side * 0.25, y, COR_TOP + 0.25), (side * (w - 0.1), y, COR_TOP - 1.5 if w > wall + 1.0 else COR_TOP + 0.25), 0.4, 0.4, "wood_in", c_rib)
			# A post down the wall's line every second rib, and at the ledge.
			if i % 2 == 0:
				x = side * (wall + 0.27)
				g.beam((x, y, COR_FLOOR), (x, y, COR_TOP + 0.1), 0.52, 0.52, "wood_in", c_rib)
				g.beam((x, y - 0.4, COR_TOP - 1.6), (x, y + 0.4, COR_TOP - 1.6), 0.54, 0.16, "iron_in", c_iron)
	for side in (-1.0, 1.0):
		x = side * (wall + 0.27)
		g.beam((x, -inner_end, COR_TOP + 0.3), (x, inner_end, COR_TOP + 0.3), 0.54, 0.35, "wood_in", c_beam)
		# The gun ledge, wall to shell, and its edge timber.
		xo = half_beam(0.0, LEDGE_Z) - LINER_T
		deck = Geo()
		for y0_, y1_ in zip(frange(-inner_end, inner_end, 4.0), frange(-inner_end, inner_end, 4.0)[1:]):
			xa = side * wall
			xb0 = side * (half_beam(y0_, LEDGE_Z) - LINER_T)
			xb1 = side * (half_beam(y1_, LEDGE_Z) - LINER_T)
			a, b, c, d = Vector((xa, y0_, LEDGE_Z)), Vector((xb0, y0_, LEDGE_Z)), Vector((xb1, y1_, LEDGE_Z)), Vector((xa, y1_, LEDGE_Z))
			g.quad(a, b, c, d, "wood_in", c_beam, hint=Vector((0, 0, 1)))
			g.quad(a, b, c, d, "wood_in", dark_rib, hint=Vector((0, 0, -1)))
		g.beam((side * (wall + 0.17), -inner_end, LEDGE_Z - 0.22), (side * (wall + 0.17), inner_end, LEDGE_Z - 0.22), 0.34, 0.44, "wood_in", c_rib)
	# Cargo in the wall's bays, on the ledge and under it. None of it past the posts.
	rng = random.Random(23)
	cr = inner((0.62, 0.5, 0.37))
	ba = inner((0.5, 0.38, 0.27))
	for side in (-1.0, 1.0):
		for by in frange(-52.0, 52.0, 4.0):
			if rng.random() < 0.15:
				continue
			gun_bay = any(abs(by - p) < 2.5 for p in PORTS)
			far = half_beam(by, LEDGE_Z) - LINER_T - 0.1
			for z in ((COR_FLOOR,) if gun_bay else (COR_FLOOR, LEDGE_Z)):
				kind = rng.random()
				room = far - wall - 0.5
				if kind < 0.45 and room > 0.8:
					s = min(room, rng.uniform(1.0, 1.6))
					crate(g, side, far - s * 0.5, by + rng.uniform(-0.3, 0.3), z, s, rng.uniform(0.9, 1.4), rng, cr, c_iron)
				elif kind < 0.85:
					r = min(room * 0.5, rng.uniform(0.45, 0.6))
					for k in range(2):
						barrel(g, side, far - r, by + (k - 0.5) * r * 2.3, z, r, ba, c_iron)
		# Lanterns in the bays between the guns, kept to the wall.
		for py in LAMP_BAYS:
			x = side * LAMP_X
			g.tube([(x, py, CEIL - 2.2), (x, py, LAMP_Z + 0.55)], [0.05, 0.05], 3, "rope", c_iron, cap=False)
			g.tube([(x, py, LAMP_Z + 0.55), (x, py, LAMP_Z + 0.32)], [0.1, 0.25], 6, "iron_in", c_iron)
			g.tube([(x, py, LAMP_Z + 0.32), (x, py, LAMP_Z - 0.32)], [0.2, 0.2], 6, "lamp", WHITE)
			g.tube([(x, py, LAMP_Z - 0.32), (x, py, LAMP_Z - 0.44)], [0.25, 0.22], 6, "iron_in", c_iron)


def cannon(g, side, y, x_muzzle, z, col_iron, col_wood):
	"""A gun on its carriage, muzzle at x_muzzle, pointing out along side."""
	L = GUN_LEN
	xb = x_muzzle - L
	def X(d):
		return side * (xb + d)
	r = GUN_BORE_R
	prof = [(-0.36, 0.14), (-0.3, 0.28), (-0.12, r * 1.28), (0.0, r * 1.48), (0.32, r * 1.5), (0.4, r * 1.4), (1.9, r * 1.28), (1.95, r * 1.38), (2.15, r * 1.26), (3.9, r * 1.04), (3.95, r * 1.14), (4.1, r * 0.98), (L - 0.5, r * 0.86), (L - 0.42, r * 1.1), (L - 0.05, r * 1.15), (L, r * 0.92)]
	g.tube([(X(d), y, z) for d, _ in prof], [q for _, q in prof], 10, "iron_in", col_iron, up=(0.0, 1.0, 0.0))
	# The bore's dark.
	g.tube([(X(L - 0.02), y, z), (X(L + 0.005), y, z)], [0.5, 0.5], 8, "dark", (0.01, 0.01, 0.01), cap=True, up=(0.0, 1.0, 0.0))
	g.tube([(X(1.75), y - 1.1, z), (X(1.75), y + 1.1, z)], [0.3, 0.3], 6, "iron_in", col_iron, up=(1.0, 0.0, 0.0))
	# The carriage: two stepped cheeks, a bed, four trucks.
	zf = LEDGE_Z
	for s in (-1.0, 1.0):
		cy = y + s * 0.9
		g.beam((side * (xb + 0.6), cy, (zf + 0.5 + z) * 0.5), (side * (xb + 3.4), cy, (zf + 0.5 + z) * 0.5), 0.34, z - zf - 0.5 + 0.18, "wood_in", col_wood)
		g.beam((side * (xb + 0.05), cy, zf + 1.0), (side * (xb + 0.6), cy, zf + 1.0), 0.34, 0.75, "wood_in", col_wood)
		for d in (0.75, 3.1):
			g.tube([(side * (xb + d), cy - 0.2, zf + 0.42), (side * (xb + d), cy + 0.2, zf + 0.42)], [0.42, 0.42], 8, "wood_in", col_wood, up=(1.0, 0.0, 0.0))
	g.beam((side * (xb + 0.5), y, zf + 0.68), (side * (xb + 3.5), y, zf + 0.68), 1.8, 0.24, "wood_in", col_wood)


def build_guns():
	g = Geo()
	empties = []
	ci = inner((0.1, 0.1, 0.105))
	cw = inner((0.62, 0.34, 0.21))
	for side in (-1.0, 1.0):
		label = "R" if side > 0 else "L"
		for i, y in enumerate(PORTS):
			x = GUN_X
			# Out of the shell the iron has the day on it, not the deck's dark.
			def col_i(p, base=ci):
				if abs(p.x) > half_beam(p.y, GUN_Z) - 0.8:
					return (0.07, 0.07, 0.075)
				return base(p)
			cannon(g, side, y, x, GUN_Z, col_i, cw)
			empties.append((f"Gun_{label}_{i + 1:02d}", (side * x, y, GUN_Z), side))
	return g, empties


# --- Above the deck -----------------------------------------------------------

def build_decks(g):
	col_d = (0.74, 0.64, 0.52)
	def dw(z):
		return lambda y: half_at(y, z) - 0.1
	# Waist, quarterdeck, poop, forecastle: flat, each a step up the sheer.
	deck_strip(g, lambda y: DECK_Z, BREAK_POOP - 0.2, BREAK_FORE + 0.2, dw(DECK_Z), col_d, 4.0)
	deck_strip(g, lambda y: DECK_POOP, BREAK_HIGH - 0.2, BREAK_POOP, dw(DECK_POOP), col_d, 3.0)
	deck_strip(g, lambda y: DECK_HIGH, stern_y(DECK_HIGH) + 0.1, BREAK_HIGH, dw(DECK_HIGH), col_d, 3.0)
	deck_strip(g, lambda y: DECK_FORE, BREAK_FORE, stem_y(DECK_FORE) - 0.4, dw(DECK_FORE), col_d, 2.0)
	bulk = (0.42, 0.31, 0.22)
	def bulkhead(y, z0, z1, face):
		n = max(1, int((z1 - z0) / STRAKE))
		rng = random.Random(int(y * 3 + 91))
		for i in range(n):
			a, b = lerp(z0, z1, i / n), lerp(z0, z1, (i + 1) / n)
			w = half_at(y, (a + b) * 0.5) - 0.2
			t = rng.uniform(0.75, 1.1)
			g.beam((-w, y, (a + b) * 0.5), (w, y, (a + b) * 0.5), 0.3, b - a - 0.05, "wood", (bulk[0] * t, bulk[1] * t, bulk[2] * t), up=(0.0, 0.0, 1.0))
		# The door and windows of a cabin front; a dark rail along its head.
		w = half_at(y, z1) - 0.4
		for x in (-w * 0.72, -w * 0.32, w * 0.32, w * 0.72):
			g.box(x - 0.8, x + 0.8, y + face * 0.3 - 0.06, y + face * 0.3 + 0.06, z0 + (z1 - z0) * 0.42, z0 + (z1 - z0) * 0.78, "dark", (0.012, 0.014, 0.018))
			g.box(x - 1.0, x + 1.0, y + face * 0.28 - 0.1, y + face * 0.28 + 0.1, z0 + (z1 - z0) * 0.39, z0 + (z1 - z0) * 0.42, "wood", (0.2, 0.15, 0.1))
		g.box(-1.3, 1.3, y + face * 0.3 - 0.07, y + face * 0.3 + 0.07, z0, z0 + (z1 - z0) * 0.74, "dark", (0.02, 0.016, 0.014))
		g.beam((-w, y + face * 0.2, z1), (w, y + face * 0.2, z1), 0.8, 0.5, "paint", TRIM)
	bulkhead(BREAK_POOP, DECK_Z, DECK_POOP, 1.0)
	bulkhead(BREAK_HIGH, DECK_POOP, DECK_HIGH, 1.0)
	bulkhead(BREAK_FORE, DECK_Z, DECK_FORE, -1.0)
	cap = (0.045, 0.032, 0.024)
	for side in (-1.0, 1.0):
		S = Side(side)
		# Cap rail: a heavy timber along the sheer, stern to stem; a sheer wale under it.
		us = frange(-STERN_U, stem_y(rail(Y_BOW)) - 0.3, 2.0)
		for drop, w, h, col in ((0.0, 0.8, 0.4, cap), (2.2, 0.5, 0.5, (0.06, 0.045, 0.034))):
			pts = []
			for u in us:
				q = S.p(u, rail(u) - drop)
				pts.append((q.x + side * (0.15 if drop else 0.0), q.y, q.z + (0.1 if not drop else 0.0)))
			for a, b in zip(pts, pts[1:]):
				if (Vector(a) - Vector(b)).length > 0.05:
					g.beam(a, b, w, h, "paint", col, up=(0.0, 0.0, 1.0))
		# The channels: plank shelves outboard of the masts that spread the shrouds.
		for my, _, _, _ in MASTS:
			c0, c1 = my - 5.5, my + 5.5
			z = DECK_Z + 1.9
			g.beam((side * (half_at(c0, z) + 0.9), c0, z), (side * (half_at(c1, z) + 0.9), c1, z), 1.9, 0.3, "wood", (0.2, 0.15, 0.11))
	hatch = (0.2, 0.15, 0.11)
	for y, w, l in ((-18.0, 6.0, 8.0), (8.0, 7.0, 10.0), (29.0, 5.0, 6.0)):
		g.box(-w * 0.5 - 0.3, w * 0.5 + 0.3, y - l * 0.5 - 0.3, y + l * 0.5 + 0.3, DECK_Z, DECK_Z + 0.7, "wood", (0.3, 0.23, 0.17))
		g.box(-w * 0.5, w * 0.5, y - l * 0.5, y + l * 0.5, DECK_Z + 0.66, DECK_Z + 0.78, "dark", (0.015, 0.013, 0.012))
		for x in frange(-w * 0.5 + 0.5, w * 0.5 - 0.5, 1.2):
			g.box(x - 0.2, x + 0.2, y - l * 0.5, y + l * 0.5, DECK_Z + 0.78, DECK_Z + 0.9, "wood", hatch)
		for yy in frange(y - l * 0.5 + 0.5, y + l * 0.5 - 0.5, 1.2):
			g.box(-w * 0.5, w * 0.5, yy - 0.2, yy + 0.2, DECK_Z + 0.78, DECK_Z + 0.9, "wood", hatch)
	# Capstan on the waist, the wheel on the poop, stairs up to each.
	g.tube([(0.0, -26.0, DECK_Z), (0.0, -26.0, DECK_Z + 1.6), (0.0, -26.0, DECK_Z + 2.0)], [1.1, 0.8, 1.3], 10, "wood", (0.3, 0.22, 0.16))
	wy, wz = -36.0, DECK_POOP + 2.1
	g.tube([(-1.1, wy, wz), (1.1, wy, wz)], [0.2, 0.2], 6, "wood", (0.2, 0.14, 0.1))
	for a in range(16):
		t0, t1 = a * math.tau / 16, (a + 1) * math.tau / 16
		g.beam((0.15, wy + math.cos(t0) * 1.6, wz + math.sin(t0) * 1.6), (0.15, wy + math.cos(t1) * 1.6, wz + math.sin(t1) * 1.6), 0.26, 0.26, "wood", (0.22, 0.15, 0.1))
		if a % 4 == 0:
			g.beam((0.15, wy, wz), (0.15, wy + math.cos(t0) * 1.6, wz + math.sin(t0) * 1.6), 0.18, 0.18, "wood", (0.22, 0.15, 0.1))
	for s in (-1.0, 1.0):
		x = s * 6.5 * WIDEN
		for yy, z1, d, run in ((BREAK_POOP + 10.0, DECK_POOP, -1.0, 10.0), (BREAK_FORE - 5.5, DECK_FORE, 1.0, 5.5)):
			n = int(run / 0.75)
			for i in range(n):
				t = (i + 1) / n
				g.box(x - 1.4, x + 1.4, yy + d * run * t - 0.4, yy + d * run * t + 0.4, lerp(DECK_Z, z1, t) - 0.2, lerp(DECK_Z, z1, t), "wood", (0.3, 0.23, 0.16))
			for dx in (-1.5, 1.5):
				g.beam((x + dx, yy, DECK_Z + 1.1), (x + dx, yy + d * run, z1 + 1.1), 0.2, 0.3, "wood", (0.2, 0.15, 0.1))
	# A ship's boat, stove in, lashed on the main hatch.
	bz = DECK_Z + 2.0
	ring = [((0.0, 8.0 + t * 6.0, bz + z), w) for t, w, z in ((-1.0, 0.25, 0.8), (-0.7, 1.3, 0.25), (-0.3, 1.8, 0.0), (0.3, 1.75, 0.0), (0.75, 1.1, 0.25), (1.0, 0.18, 0.9))]
	g.tube([p for p, _ in ring], [w for _, w in ring], 8, "paint", (0.05, 0.04, 0.033), squash=0.55)


def build_stern(g):
	"""The transom's dress: gallery windows, balconies, the crown, the lanterns."""
	trim = (0.16, 0.15, 0.14)
	dark_wood = (0.05, 0.036, 0.028)
	oxblood = TRIM
	top = rail(-STERN_U)
	for rz in GALLERIES:
		h = 3.5
		wtop = half_beam(stern_y(rz + h) * 0.999, rz + h) - 0.4
		wbot = half_beam(stern_y(rz) * 0.999, rz) - 0.4
		y = stern_y(rz)
		yt = stern_y(rz + h)
		n = 7
		pitch = wbot * 2.0 / n
		# The band of panes.
		g.quad(Vector((-wbot, y - 0.18, rz)), Vector((wbot, y - 0.18, rz)), Vector((wtop, yt - 0.18, rz + h)), Vector((-wtop, yt - 0.18, rz + h)), "glass", (0.075, 0.09, 0.1), hint=Vector((0, -1, 0)))
		# Lattice and posts.
		for i in range(n + 1):
			t = i / n
			x0 = lerp(-wbot, wbot, t)
			x1 = lerp(-wtop, wtop, t)
			g.beam((x0, y - 0.32, rz), (x1, yt - 0.32, rz + h), 0.62, 0.34, "paint", trim, up=(0.0, 1.0, 0.0))
		for i in range(n * 3):
			if i % 3 == 0:
				continue
			t = i / (n * 3)
			g.beam((lerp(-wbot, wbot, t), y - 0.26, rz), (lerp(-wtop, wtop, t), yt - 0.26, rz + h), 0.1, 0.1, "paint", dark_wood, up=(0.0, 1.0, 0.0))
		for zt in (1.0 / 3.0, 2.0 / 3.0):
			zz = rz + h * zt
			ww = lerp(wbot, wtop, zt)
			g.beam((-ww, lerp(y, yt, zt) - 0.26, zz), (ww, lerp(y, yt, zt) - 0.26, zz), 0.1, 0.1, "paint", dark_wood)
		# The sill and head, and a balcony with its balusters.
		g.beam((-wbot - 0.4, y - 0.4, rz - 0.15), (wbot + 0.4, y - 0.4, rz - 0.15), 0.9, 0.5, "paint", oxblood)
		g.beam((-wtop - 0.4, yt - 0.4, rz + h + 0.15), (wtop + 0.4, yt - 0.4, rz + h + 0.15), 0.9, 0.5, "paint", oxblood)
		walk = 1.8
		g.beam((-wbot - 0.3, y - walk * 0.5, rz - 0.55), (wbot + 0.3, y - walk * 0.5, rz - 0.55), 0.42, walk + 0.2, "wood", (0.2, 0.15, 0.1), up=(0.0, 1.0, 0.0))
		for k in range(n * 3 + 1):
			x = lerp(-wbot, wbot, k / (n * 3))
			g.tube([(x, y - walk, rz - 0.4), (x, y - walk, rz + 0.1), (x, y - walk, rz + 0.45), (x, y - walk, rz + 1.1)], [0.1, 0.16, 0.11, 0.09], 5, "paint", dark_wood, cap=False)
		g.beam((-wbot, y - walk, rz + 1.15), (wbot, y - walk, rz + 1.15), 0.3, 0.18, "paint", dark_wood)
		# Brackets under the balcony.
		for k in range(n + 1):
			x = lerp(-wbot, wbot, k / n)
			g.beam((x, y - 0.1, rz - 1.6), (x, y - walk + 0.1, rz - 0.7), 0.42, 0.42, "paint", dark_wood, up=(0.0, 1.0, 0.0))
	# Taffrail along the crown's arc, three lanterns standing over it, unlit.
	pts = []
	wc = half_beam(stern_y(top) * 0.999, top)
	for t in frange(-1.0, 1.0, 0.1):
		pts.append((t * wc, stern_y(top) - 0.1, top + CROWN * math.sqrt(max(0.0, 1.0 - t * t))))
	for a, b in zip(pts, pts[1:]):
		g.beam(a, b, 1.0, 0.7, "paint", oxblood, up=(0.0, 1.0, 0.0))
	for x, z, r in ((0.0, top + CROWN + 0.35, 1.0), (-wc * 0.72, top + CROWN * 0.7 + 0.35, 0.72), (wc * 0.72, top + CROWN * 0.7 + 0.35, 0.72)):
		y = stern_y(top) + 0.2
		g.tube([(x, y, z), (x, y, z + 1.0 * r)], [0.22 * r, 0.3 * r], 6, "iron", (0.09, 0.09, 0.09))
		g.tube([(x, y, z + 1.0 * r), (x, y, z + 1.15 * r), (x, y, z + 3.4 * r), (x, y, z + 3.55 * r), (x, y, z + 4.3 * r), (x, y, z + 5.0 * r)], [0.3 * r, 1.0 * r, 1.25 * r, 1.25 * r, 0.5 * r, 0.1 * r], 6, "iron", (0.075, 0.075, 0.08))
	# Quarter galleries: the stern's corners, a bulge of windows on each side, leaning
	# out with the counter.
	for s in (-1.0, 1.0):
		S = Side(s)
		u0, u1 = -STERN_U + 1.5, -STERN_U + 11.0
		zs = (GALLERIES[0] - 0.4, GALLERIES[1] - 0.6, GALLERIES[1] + 4.0)
		for k in range(2):
			z0, z1 = zs[k], zs[k + 1] - 0.6
			h0, i0, h1, i1 = S.p(u0, z0), S.p(u1, z0), S.p(u0, z1), S.p(u1, z1)
			o = Vector((s * 1.1, 0.0, 0.0))
			a0, b0, a1, b1 = h0 + o, i0 + o, h1 + o, i1 + o
			g.quad(a0, b0, b1, a1, "glass", (0.075, 0.09, 0.1), hint=Vector((s, 0, 0)))
			for t in frange(0.0, 1.0, 0.25):
				g.beam(a0.lerp(b0, t) + Vector((s * 0.1, 0, 0)), a1.lerp(b1, t) + Vector((s * 0.1, 0, 0)), 0.5, 0.26, "paint", trim, up=(1.0, 0.0, 0.0))
			# The sill, the head, and the skirt of planks back to the hull.
			for q0, q1, hz in ((a0, b0, -0.3), (a1, b1, 0.3)):
				g.beam(q0 + Vector((s * 0.2, 0, hz)), q1 + Vector((s * 0.2, 0, hz)), 0.6, 0.6, "paint", oxblood)
			for p0, p1 in ((h0, a0), (i0, b0)):
				g.beam(p0, p1, 0.2, 0.3, "paint", dark_wood)
			g.quad(h1 + Vector((-s * 0.2, 0, 0.6)), i1 + Vector((-s * 0.2, 0, 0.6)), b1 + Vector((s * 0.6, 0, 0.6)), a1 + Vector((s * 0.6, 0, 0.6)), "wood", (0.17, 0.12, 0.09), hint=Vector((0, 0, 1)))
			g.quad(h0 + Vector((-s * 0.2, 0, -1.6)), i0 + Vector((-s * 0.2, 0, -1.6)), b0 + Vector((s * 0.4, 0, -0.5)), a0 + Vector((s * 0.4, 0, -0.5)), "wood", (0.14, 0.1, 0.08), hint=Vector((s, 0, -1)))
			# Ends.
			g.quad(h0, a0, a1, h1, "wood", (0.14, 0.1, 0.08), hint=Vector((0, -1, 0)))
			g.quad(i0, b0, b1, i1, "wood", (0.14, 0.1, 0.08), hint=Vector((0, 1, 0)))


GALLERIES = (16.6, 23.4)      # the sills of the transom's two window rows
TRIM = (0.13, 0.125, 0.12)    # dark iron-grey paint where the old build had oxblood


def build_backing(g):
	"""Dark sheets behind each end, over and under the corridor, so a gap reads as depth."""
	dark = (0.012, 0.011, 0.01)
	for y, face, top in ((stern_y(COR_Z) + 1.3, -1.0, DECK_POOP), (Y_BOW - 1.3, 1.0, DECK_FORE)):
		for z0, z1 in ((COR_TOP + 0.05, top), (0.0, COR_FLOOR - 0.05)):
			w = min(half_beam(y, z0), half_beam(y, z1)) - 0.2
			if w > 0.5:
				g.quad(Vector((-w, y, z0)), Vector((w, y, z0)), Vector((w, y, z1)), Vector((-w, y, z1)), "dark", dark, hint=Vector((0, face, 0)))


def build_beak(g):
	"""The prow's dress: catheads off the forecastle, an anchor hanging from each, clear
	of the cut."""
	dk = (0.05, 0.036, 0.027)
	for s in (-1.0, 1.0):
		y0, y1, z = 49.0, 52.5, 19.0
		x = half_at(y0, z)
		g.beam((s * (x - 1.2), y0, z), (s * (x + 3.0), y1, z + 0.4), 0.8, 0.8, "paint", dk, up=(0.0, 0.0, 1.0))
		ax, ay = s * (half_at(y1, z) + 2.4), y1 - 0.4
		g.tube([(ax, ay, z - 0.3), (ax, ay, z - 1.0)], [0.06, 0.06], 3, "iron", (0.03, 0.03, 0.03), cap=False)
		g.beam((ax, ay, z - 0.9), (ax, ay, z - 8.1), 0.34, 0.34, "iron", (0.035, 0.035, 0.035), up=(0.0, 1.0, 0.0))
		g.beam((ax, ay - 1.7, z - 6.9), (ax, ay, z - 8.2), 0.3, 0.3, "iron", (0.035, 0.035, 0.035), up=(1.0, 0.0, 0.0))
		g.beam((ax, ay + 1.7, z - 6.9), (ax, ay, z - 8.2), 0.3, 0.3, "iron", (0.035, 0.035, 0.035), up=(1.0, 0.0, 0.0))
		g.beam((ax - 1.0, ay, z - 1.4), (ax + 1.0, ay, z - 1.4), 0.3, 0.3, "wood", (0.2, 0.15, 0.1))


# --- Masts, sails, rigging ----------------------------------------------------

def yard_axis(tilt):
	b = math.radians(BRACE)
	return Vector((math.cos(tilt) * math.cos(b), math.cos(tilt) * math.sin(b), math.sin(tilt)))


def mast_geo(index, spec, sails):
	y, top1, top2, truck = spec
	g = Geo()
	wood = (0.28, 0.2, 0.135)
	dark = (0.1, 0.075, 0.06)
	foot = base_deck(y)
	r0 = MAST_R * (1.0 if index == 1 else 0.88)
	# The lower mast, doubled at the top by the topmast's heel.
	g.tube([(0.0, y, 0.0 + foot), (0.0, y, foot + 12.0), (0.0, y, top1 - 1.0), (0.0, y, top1 + 2.0)], [r0, r0 * 1.0, r0 * 0.72, r0 * 0.68], 12, "wood", wood)
	# Iron bands, the partners.
	for z in frange(foot + 3.0, top1 - 5.0, 7.0):
		g.tube([(0.0, y, z - 0.18), (0.0, y, z + 0.18)], [lerp(r0, r0 * 0.7, (z - foot) / (top1 - foot)) + 0.04] * 2, 12, "iron", (0.09, 0.09, 0.09), cap=False)
	g.box(-r0 - 0.7, r0 + 0.7, y - r0 - 0.7, y + r0 + 0.7, foot, foot + 0.6, "wood", dark)
	# The top: a round platform with a rail, the crosstrees under it.
	pr = r0 * 3.1
	g.tube([(0.0, y, top1 - 1.3), (0.0, y, top1 - 0.4), (0.0, y, top1 - 0.2), (0.0, y, top1 + 0.05)], [pr * 0.45, pr * 0.88, pr, pr], 12, "wood", dark)
	g.tube([(0.0, y, top1 + 0.05), (0.0, y, top1 + 1.5), (0.0, y, top1 + 1.8)], [pr * 0.98, pr * 1.06, pr * 1.06], 12, "wood", (0.13, 0.095, 0.07))
	# The topmast, and the topgallant unless she has lost it.
	r1 = r0 * 0.62
	z2 = top2 + 2.0 if truck > top2 else top2
	if truck > top2:
		g.tube([(r0 * 0.9, y, top1 - 3.5), (r0 * 0.9 * 0.8, y, top1 + 8.0), (0.0, y, top2 - 2.0), (0.0, y, top2 + 1.5)], [r1, r1 * 0.95, r1 * 0.58, r1 * 0.55], 10, "wood", wood)
		r2 = r1 * 0.5
		g.tube([(r1 * 0.6, y, top2 - 3.0), (0.0, y, top2 + 2.0), (0.0, y, truck)], [r2, r2 * 0.92, r2 * 0.32], 8, "wood", wood)
		g.tube([(0.0, y, top2 - 0.3), (0.0, y, top2 + 0.2)], [r1 * 1.7, r1 * 1.7], 8, "wood", dark)
	else:
		# Shot through: a splintered stump, its broken top leaning off.
		g.tube([(r0 * 0.9, y, top1 - 3.5), (r0 * 0.7, y, top1 + 8.0), (0.5, y, top2 - 2.0), (0.8, y, top2 + 0.2)], [r1, r1 * 0.95, r1 * 0.62, r1 * 0.2], 10, "wood", wood)
		rng = random.Random(index + 7)
		for k in range(7):
			a = k * math.tau / 7
			p = Vector((0.5 + math.cos(a) * r1 * 0.5, y + math.sin(a) * r1 * 0.5, top2 - 2.6))
			tip = p + Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, rng.uniform(1.0, 3.8)))
			g.tube([p, tip], [r1 * 0.28, 0.02], 4, "wood", (0.8, 0.62, 0.42), cap=False)
	# The yards, cross the mast forward of it.
	yard_out = []
	for name, zy, w, zb, wb, cell, tilt in sails:
		t = math.radians(tilt)
		ax = yard_axis(t)
		c = Vector((0.0, y + r0 + 0.4, zy))
		half = w * 0.5 + 1.5
		r = 0.62 * (w / 40.0) ** 0.5
		pts = [c - ax * half, c - ax * half * 0.5, c, c + ax * half * 0.5, c + ax * half]
		g.tube(pts, [r * 0.42, r * 0.84, r, r * 0.84, r * 0.42], 8, "wood", (0.16, 0.115, 0.08), up=(0.0, 1.0, 0.0))
		yard_out.append((name, c.copy(), w, zb, wb, cell, tilt))
	return g, yard_out


def sail_geo(w, h, wb, cell):
	"""A flat sheet hanging from the yard (the origin) down -Z; `ship_cloth.gdshader` bellies it.

	Rows and columns crowd toward the foot and the leeches, where the cloth ripples.
	The vertex colour is the sheet's size for the shader: h, head and foot width over SAIL_SIZE.
	"""
	g = Geo()
	nx = max(SAIL_MIN[0], round(max(w, wb) / SAIL_CELL[0]))
	ny = max(SAIL_MIN[1], round(h / SAIL_CELL[1]))
	cu, cv = (cell % 2) * 0.5, (1 - (cell // 2)) * 0.5
	size = (h / SAIL_SIZE, w / SAIL_SIZE, wb / SAIL_SIZE)
	ids = []
	for j in range(ny + 1):
		t = 1.0 - (1.0 - j / ny) ** 1.3
		row = []
		for i in range(nx + 1):
			a = i / nx * 2.0 - 1.0
			s = math.copysign(1.0 - (1.0 - abs(a)) ** 1.35, a)
			x = s * lerp(w, wb, t) * 0.5
			uv = (cu + (s * 0.5 + 0.5) * 0.5, cv + (1.0 - t) * 0.5)
			row.append(g.vert((x, 0.35, -h * t), uv, size))
		ids.append(row)
	for j in range(ny):
		for i in range(nx):
			g.face([ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]], "sail", Vector((0.0, 1.0, 0.0)))
	return g


def rope(g, a, b, r=0.17, sag=0.0, n=3):
	a, b = Vector(a), Vector(b)
	if sag <= 0.0:
		g.tube([a, b], [r, r], n, "rope", (0.05, 0.042, 0.035), cap=False)
		return
	pts = []
	for t in frange(0.0, 1.0, 0.2):
		p = a.lerp(b, t)
		p.z -= sag * 4.0 * t * (1.0 - t)
		pts.append(p)
	g.tube(pts, [r] * len(pts), n, "rope", (0.05, 0.042, 0.035), cap=False)


def build_rigging(g, stays, yards):
	"""Shrouds, ratlines, stays. Fine lines are `g`; `stays` are thick and stay on at a distance."""
	rng = random.Random(5)
	for idx, (y, top1, top2, truck) in enumerate(MASTS):
		foot = DECK_Z + 1.9
		for side in (-1.0, 1.0):
			hb = half_beam(y, foot) + 1.3
			feet = [Vector((side * hb, y + d, foot)) for d in (-5.0, -3.0, -1.0, 1.0)]
			head = Vector((side * 1.0, y - 0.2, top1 - 0.6))
			for f in feet:
				rope(g, f, head, 0.19)
			# Ratlines: one rod across the shrouds per rung.
			rungs = int((head.z - foot) / 1.8)
			for k in range(2, rungs):
				t = k / rungs
				rope(g, feet[0].lerp(head, t), feet[-1].lerp(head, t), 0.08)
			# Topmast shrouds to the top's rim.
			rim = Vector((side * MAST_R * 3.0, y, top1 + 1.0))
			t2 = Vector((side * 0.6, y, top2 - 1.0))
			for d in (-1.8, 0.0, 1.8):
				rope(g, rim + Vector((0.0, d, 0.0)), t2, 0.13)
			# A backstay down to the rail.
			rope(g, Vector((side * 0.8, y - 0.5, top2 + 0.5)), Vector((side * hb, y - 12.0, foot + 0.3)), 0.14)
	# The stays: thick, down the ship's middle: the lines that survive distance.
	fy, f1, f2, ft = MASTS[0]
	my, m1, m2, mt = MASTS[1]
	zy, z1, z2, zt = MASTS[2]
	sp_a, sp_b = Vector(BOWSPRIT[0]), Vector(BOWSPRIT[1])
	sp_mid = sp_a.lerp(sp_b, 0.72)
	rope(stays, (0.0, fy + 1.0, f1 + 0.5), sp_mid, 0.34, 1.5, 5)
	rope(stays, (0.0, fy + 0.8, f2 + 0.5), sp_b, 0.26, 1.2, 5)
	rope(stays, (0.0, my + 1.0, m1 + 0.5), (0.0, fy - 1.0, DECK_Z + 9.0), 0.3, 1.0, 5)
	rope(stays, (0.0, my + 0.8, m2 + 0.5), (0.0, fy, f1 + 0.3), 0.26, 1.0, 5)
	rope(stays, (0.0, my + 0.4, mt - 2.0), (0.0, fy, f2 + 0.3), 0.2, 0.8, 5)
	rope(stays, (0.0, zy + 1.0, z1 + 0.5), (0.0, my - 1.0, DECK_Z + 9.0), 0.28, 1.0, 5)
	rope(stays, (0.0, zy + 0.6, z2 - 2.0), (0.0, my, m1 + 0.3), 0.22, 0.9, 5)
	# No bobstay: it would cross the bow's way out.
		# Lifts from the yards to the masts, braces trailing aft, a few cut ends.
	for idx, mast_yards in enumerate(yards):
		y = MASTS[idx][0]
		for name, c, w, zb, wb, cell, tilt in mast_yards:
			t = math.radians(tilt)
			for s in (-1.0, 1.0):
				arm = c + yard_axis(t) * (s * w * 0.5)
				rope(g, arm, (0.0, y + 0.5, c.z + 5.0), 0.12)
				if rng.random() < 0.7:
					yy = max(y - 18.0, -54.0)
					to = Vector((s * half_at(yy, 20.0), yy, rail(yy)))
					rope(g, arm, to, 0.11, 1.4)
				else:
					# A brace shot away: it hangs.
					rope(g, arm, arm + Vector((rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), -rng.uniform(5.0, 12.0))), 0.11)


def build_bowsprit(g):
	a, b = Vector(BOWSPRIT[0]), Vector(BOWSPRIT[1])
	wood = (0.26, 0.19, 0.13)
	mid = a.lerp(b, 0.62)
	g.tube([a, a.lerp(b, 0.3), mid], [0.95, 0.85, 0.6], 10, "wood", wood)
	g.tube([a.lerp(b, 0.52) + Vector((0.3, 0.0, 0.7)), mid, b], [0.58, 0.5, 0.18], 8, "wood", wood)
	for t in (0.14, 0.3, 0.46):
		p0 = a.lerp(b, t)
		r = lerp(0.95, 0.65, t / 0.62) + 0.05
		g.tube([p0 - (b - a).normalized() * 0.2, p0 + (b - a).normalized() * 0.2], [r, r], 10, "iron", (0.09, 0.09, 0.09), cap=False)
	# The spritsail's yard, slung under it, at an angle she didn't choose.
	c = a.lerp(b, 0.74) - Vector((0.0, 0.0, 1.8))
	ax = Vector((math.cos(0.12), 0.0, math.sin(0.12)))
	g.tube([c - ax * 11.0, c, c + ax * 11.0], [0.2, 0.42, 0.2], 8, "wood", (0.16, 0.115, 0.08), up=(0.0, 1.0, 0.0))
	return c, 0.12


# --- Textures -----------------------------------------------------------------

def spectral(h, w, beta, seed, sx=1.0, sy=1.0):
	"""Tileable noise, 0..1 about 0.5, 1/f^beta; sx > 1 stretches it along x."""
	rng = np.random.default_rng(seed)
	f = np.fft.rfft2(rng.standard_normal((h, w)).astype(np.float32))
	fy = np.fft.fftfreq(h)[:, None] * h / max(h, w) * sy
	fx = np.fft.rfftfreq(w)[None, :] * w / max(h, w) * sx
	r = np.sqrt(fx * fx + fy * fy)
	r[0, 0] = 1e9
	out = np.fft.irfft2(f / (r ** beta), s=(h, w))
	out = (out - out.mean()) / (out.std() + 1e-9)
	return np.clip(out * 0.2 + 0.5, 0.0, 1.0).astype(np.float32)


def blur(a, px):
	h, w = a.shape
	fy = np.fft.fftfreq(h)[:, None]
	fx = np.fft.rfftfreq(w)[None, :]
	g = np.exp(-2.0 * (math.pi * px) ** 2 * (fx * fx + fy * fy))
	return np.fft.irfft2(np.fft.rfft2(a) * g, s=(h, w)).astype(np.float32)


def sst(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
	return a * (1.0 - t[..., None]) + b * t[..., None]


def C(r, g, b):
	return np.array((r, g, b), dtype=np.float32)


def planks(rows_f, along, seed, plank_len=11.0):
	"""Plank tints, seams and butts, from float row coords and metres along.

	Returns per-pixel: tint (0..1), seam darkness (0..1), plank id noise.
	"""
	rng = np.random.default_rng(seed)
	r = np.floor(rows_f).astype(np.int32)
	frac = rows_f - r
	offs = rng.uniform(0.0, plank_len, 512)[np.mod(r, 512)]
	pos = (along + offs) / plank_len
	pid = np.floor(pos).astype(np.int32)
	pf = pos - pid
	table = rng.uniform(0.0, 1.0, 4096)
	tint = table[np.mod(r * 31 + pid * 17, 4096)].astype(np.float32)
	seam = np.maximum(sst(0.09, 0.0, frac), sst(0.93, 1.0, frac))
	butt = np.maximum(sst(0.006, 0.0, pf), sst(0.994, 1.0, pf))
	return tint, seam, butt.astype(np.float32), frac.astype(np.float32), pf.astype(np.float32)


def paint_hull(W):
	"""The hull's side, straight on: planks, paint, stains. Shared by both sides."""
	H = int(W * (Z_TOP - Z_BOT) / (Y_FORE - Y_BACK))
	ys = np.linspace(Y_BACK, Y_FORE, W, dtype=np.float32)
	zs = np.linspace(Z_TOP, Z_BOT, H, dtype=np.float32)
	Y, Z = np.meshgrid(ys, zs)
	# Back to base heights: the keel's rise at the ends, the strakes' wobble.
	e = np.clip(np.maximum(np.minimum(1.0, (-Y - 30.0) / (STERN_U - 30.0)), np.minimum(1.0, (Y - 30.0) / 42.0)), 0.0, None) ** 2
	base = np.where(Z < 0.0, Z / (1.0 - KEEL_RISE * e), Z)
	rl = np.interp(Y, [q[0] for q in SHEER], [q[1] for q in SHEER]).astype(np.float32)
	for _ in range(2):
		k = sst(0.4, 1.4, base) * np.minimum(1.0, np.abs(base - TUNNEL_LO) / STRAKE) * np.minimum(1.0, np.abs(base - TUNNEL_HI) / STRAKE)
		k *= np.minimum(1.0, np.clip(rl - base, 0.0, None) / STRAKE)
		base = Z - WOBBLE * k * np.sin(Y * 0.23 + (base - KEEL_Z) / STRAKE * 1.3)
	base = np.where(Z < 0.0, Z / (1.0 - KEEL_RISE * e), base)
	rows_f = (base - KEEL_Z) / STRAKE
	tint, seam, butt, frac, pf = planks(rows_f, Y, 3)
	grain = spectral(H, W, 0.9, 1, sx=26.0)
	grain2 = spectral(H, W, 0.55, 2, sx=46.0)
	wash = spectral(H, W, 1.9, 3)
	blot = spectral(H, W, 1.4, 4)
	drip = spectral(H, W, 1.1, 5, sy=30.0)
	drip2 = spectral(H, W, 0.8, 6, sy=60.0)
	fine = spectral(H, W, 0.45, 7)
	# Bare weathered wood under everything: dark, grey-brown.
	wood = mix(C(0.19, 0.165, 0.14)[None, None], C(0.33, 0.29, 0.25)[None, None], np.clip(0.2 + 0.7 * tint * 0.7 + 0.5 * (grain - 0.5), 0, 1))
	# Tar and slate: near-black tar on the gun strakes and below, a step lighter above
	# the deck, a grey boot-top over the waterline. No colour.
	tar = mix(C(0.095, 0.082, 0.074)[None, None], C(0.17, 0.148, 0.132)[None, None], tint * 0.8 + 0.2 * grain)
	upper = mix(C(0.115, 0.1, 0.09)[None, None], C(0.2, 0.175, 0.157)[None, None], tint * 0.75 + 0.25 * wash)
	boot = mix(C(0.27, 0.255, 0.235)[None, None], C(0.38, 0.36, 0.335)[None, None], tint * 0.6 + 0.4 * wash)
	col = np.where((base >= DECK_Z)[..., None], upper, tar)
	col = np.where(((base > 0.8) & (base < TUNNEL_LO))[..., None], boot, col)
	band = (base > row_z(PORT_ROW) - STRAKE) & (base < row_z(PORT_ROW + PORT_ROWS) + STRAKE)
	# Paint worn through to wood: patches, plank edges, and more at the band.
	edge = np.maximum(sst(0.22, 0.0, frac), sst(0.82, 1.0, frac))
	wear = (blot * 0.75 + fine * 0.5 + edge * 0.2) + grain2 * 0.3
	bite = sst(0.92, 1.0, wear + np.where(band, -0.1, 0.0))
	col = mix(col, wood, bite)
	col *= (0.8 + 0.4 * grain)[..., None]
	col *= (0.82 + 0.36 * wash)[..., None]
	# Rain and tar down the planks, then what runs from each port.
	s = sst(0.58, 0.8, drip * 0.7 + drip2 * 0.5)
	col = mix(col, col * 0.5, s * 0.7)
	salt = sst(0.62, 0.84, drip2 * 0.6 + drip * 0.5) * sst(9.0, 1.5, base) * sst(-0.5, 1.5, base)
	col = mix(col, C(0.42, 0.42, 0.38)[None, None], salt * 0.42)
	run = np.zeros((H, W), dtype=np.float32)
	zp = row_z(PORT_ROW)
	for y in PORTS:
		dy = np.abs(Y - y)
		width = 1.8 + 1.5 * sst(0.3, 0.8, drip)
		run = np.maximum(run, sst(width, 0.3, dy) * sst(zp + 0.3, zp - 0.2, base) * sst(zp - 13.0, zp - 3.0, base))
		# Soot fans up from the muzzle.
		up = sst(row_z(PORT_ROW + PORT_ROWS) + 5.0, row_z(PORT_ROW + PORT_ROWS), base) * sst(row_z(PORT_ROW + PORT_ROWS) - 0.5, row_z(PORT_ROW + PORT_ROWS) + 0.1, base)
		fan = sst(3.0, 1.0, dy) * up
		col = mix(col, C(0.03, 0.028, 0.026)[None, None], fan * (0.45 + 0.6 * fine) * 0.8)
	col = mix(col, col * 0.35 + C(0.05, 0.03, 0.02)[None, None], np.clip(run * (0.35 + 1.0 * drip), 0, 1) * 0.85)
	# Fouling at the waterline: weed black-green, a ragged edge, barnacle specks.
	wl = 0.3 + 1.0 * (blot - 0.5) + 0.9 * (drip - 0.5)
	foul = sst(wl + 0.6, wl - 0.5, Z)
	col = mix(col, mix(C(0.03, 0.04, 0.032)[None, None], C(0.08, 0.095, 0.06)[None, None], grain), foul * 0.92)
	spots = spectral(H, W, 0.2, 8)
	bar = sst(0.74, 0.8, spots) * sst(3.0, 0.8, Z) * sst(0.32, 0.6, blot)
	col = mix(col, C(0.46, 0.45, 0.4)[None, None], bar * 0.7)
	# Seams: black caulk; butts; trenail dots.
	col = mix(col, C(0.012, 0.01, 0.009)[None, None], seam * 0.92)
	col = mix(col, C(0.015, 0.012, 0.01)[None, None], butt * 0.8)
	# Height, for the normal map.
	hgt = 0.5 + (grain - 0.5) * 0.9 + (grain2 - 0.5) * 0.45 + (fine - 0.5) * 0.3 - seam * 1.3 - butt * 1.0 + bar * 0.5
	return np.clip(col, 0, 1), hgt


def paint_stern(W):
	"""A flat end straight on: x over END_SPAN, z over the hull's map range."""
	H = int(W * (Z_TOP - Z_BOT) / END_SPAN)
	xs = np.linspace(-END_SPAN * 0.5, END_SPAN * 0.5, W, dtype=np.float32)
	zs = np.linspace(Z_TOP, Z_BOT, H, dtype=np.float32)
	X, Z = np.meshgrid(xs, zs)
	rows_f = (Z - KEEL_Z) / STRAKE
	tint, seam, butt, frac, pf = planks(rows_f, X, 9, 8.0)
	grain = spectral(H, W, 0.9, 11, sx=22.0)
	grain2 = spectral(H, W, 0.55, 12, sx=40.0)
	wash = spectral(H, W, 1.9, 13)
	blot = spectral(H, W, 1.4, 14)
	drip = spectral(H, W, 1.1, 15, sy=26.0)
	fine = spectral(H, W, 0.45, 16)
	wood = mix(C(0.19, 0.165, 0.14)[None, None], C(0.33, 0.29, 0.25)[None, None], np.clip(0.2 + 0.5 * tint + 0.5 * (grain - 0.5), 0, 1))
	tar = mix(C(0.11, 0.095, 0.085)[None, None], C(0.2, 0.175, 0.157)[None, None], tint * 0.8 + 0.2 * grain)
	wear = blot * 0.75 + fine * 0.5 + grain2 * 0.3
	col = mix(tar, wood, sst(0.8, 1.0, wear))
	col *= (0.8 + 0.4 * grain)[..., None]
	col *= (0.82 + 0.36 * wash)[..., None]
	# Tide stains run down the transom.
	s = sst(0.56, 0.8, drip)
	col = mix(col, col * 0.5, s * 0.75)
	wl = 0.9 + 1.9 * (blot - 0.5) + 1.8 * (drip - 0.5)
	foul = sst(wl + 0.6, wl - 0.5, Z)
	col = mix(col, mix(C(0.03, 0.05, 0.035)[None, None], C(0.09, 0.115, 0.06)[None, None], grain), foul * 0.92)
	col = mix(col, C(0.012, 0.01, 0.009)[None, None], seam * 0.92)
	col = mix(col, C(0.015, 0.012, 0.01)[None, None], butt * 0.8)
	hgt = 0.5 + (grain - 0.5) * 0.9 + (grain2 - 0.5) * 0.45 + (fine - 0.5) * 0.3 - seam * 1.3 - butt
	return np.clip(col, 0, 1), hgt


def paint_wood(W):
	"""A tile of light-toned plank, for the vertex colours to darken."""
	H = W
	v, u = np.mgrid[0:H, 0:W].astype(np.float32)
	u /= W
	v /= H
	rows_f = v * 6.0
	tint, seam, butt, frac, pf = planks(rows_f, u * 6.0, 21, 6.0)
	# Tiling: the plank table must wrap, and row and butt ids do by construction here.
	grain = spectral(H, W, 0.9, 21, sx=20.0)
	grain2 = spectral(H, W, 0.5, 22, sx=36.0)
	knots = spectral(H, W, 1.6, 23)
	base = mix(C(0.42, 0.33, 0.24)[None, None], C(0.74, 0.62, 0.48)[None, None], np.clip(0.25 + 0.55 * tint + 0.8 * (grain - 0.5), 0, 1))
	base *= (0.8 + 0.4 * grain2)[..., None]
	base *= (0.85 + 0.3 * knots)[..., None]
	col = base
	hgt = 0.5 + (grain - 0.5) + (grain2 - 0.5) * 0.5
	return np.clip(col, 0, 1), hgt


def paint_sails(W):
	"""Four whole, weathered cloths in a 2 x 2 atlas: RGB and a hard alpha for shot holes and a frayed hem."""
	cw = W // 2
	col = np.zeros((W, W, 3), dtype=np.float32)
	alpha = np.zeros((W, W), dtype=np.float32)
	for cell in range(4):
		rng = np.random.default_rng(100 + cell)
		v, u = np.mgrid[0:cw, 0:cw].astype(np.float32)
		s = u / cw * 2.0 - 1.0
		t = v / cw
		grain = spectral(cw, cw, 0.8, 200 + cell, sy=8.0)
		weave = spectral(cw, cw, 0.35, 205 + cell)
		wash = spectral(cw, cw, 1.8, 210 + cell)
		wash2 = spectral(cw, cw, 1.3, 220 + cell, sy=2.4)
		fray = spectral(cw, cw, 1.15, 230 + cell)
		blot = spectral(cw, cw, 1.6, 240 + cell)
		# Cloth: tanned canvas, bleached in great soft patches where the sun has it.
		base = mix(C(0.47, 0.41, 0.34)[None, None], C(0.66, 0.59, 0.49)[None, None], np.clip(wash * 1.4 - 0.2, 0, 1))
		base *= (0.84 + 0.32 * grain)[..., None] * (0.92 + 0.16 * weave)[..., None]
		# The cloths, seam by seam, each a touch different.
		n = 15
		idx = np.floor((s * 0.5 + 0.5) * n).astype(np.int32)
		tone = rng.uniform(0.84, 1.12, n + 1)[np.clip(idx, 0, n)].astype(np.float32)
		base *= tone[..., None]
		sf = (s * 0.5 + 0.5) * n - idx
		seamx = np.maximum(sst(0.05, 0.0, sf), sst(0.95, 1.0, sf))
		base = mix(base, base * 0.55, seamx * 0.65)
		# Reef bands, stitched across, a row of reef points under each.
		for bz in (0.27, 0.5, 0.74):
			base = mix(base, base * 0.68, sst(0.014, 0.0, np.abs(t - bz)) * 0.55)
			base = mix(base, base * 0.42, sst(0.003, 0.0, np.abs(t - bz - 0.016)) * sst(0.32, 0.5, np.abs(np.sin(s * 72.0))) * 0.8)
		# Patches sewn on, in another cloth, their stitching dark.
		for _ in range(11):
			px, pz = rng.uniform(-0.82, 0.82), rng.uniform(0.08, 0.9)
			w, h = rng.uniform(0.04, 0.13), rng.uniform(0.025, 0.08)
			d = np.maximum(np.abs(s - px) - w, np.abs(t - pz) - h)
			tint = rng.choice([0.72, 0.84, 1.08, 1.2]) * np.array((1.0, 0.93, 0.82), dtype=np.float32)
			base = np.where((d < 0.0)[..., None], np.clip(base * tint, 0, 1), base)
			base = mix(base, base * 0.62, sst(0.004, 0.0, np.abs(d)) * 0.7)
		# Rain and salt run down the cloth, tar and rust from the yard, mildew at the foot.
		streak = spectral(cw, cw, 1.1, 250 + cell, sx=0.1, sy=1.0)
		base = mix(base, base * 0.6, sst(0.52, 0.8, wash2) * (0.3 + 0.5 * t))
		base = mix(base, base * C(0.62, 0.48, 0.36)[None, None], sst(0.55, 0.78, streak) * (1.0 - t) ** 1.5 * 0.85)
		base = mix(base, base * C(0.5, 0.54, 0.44)[None, None], sst(0.5, 0.74, blot) * sst(0.5, 1.0, t) * 0.8)
		base = mix(base, base * 0.72, sst(0.82, 1.0, t) * 0.55)
		# The hem and bolt rope, dark and doubled round the edge.
		hem = np.minimum(np.minimum(1.0 - np.abs(s), t * 1.4), 1.0 - t)
		base = mix(base, base * 0.5, sst(0.022, 0.012, hem) * 0.7)
		# What's gone: a frayed foot and leech, a very little, and a few small shot holes.
		keep = hem - (fray - 0.5) * 0.022 - 0.004
		soot = np.zeros((cw, cw), dtype=np.float32)
		for _ in range(4):
			px, pz = rng.uniform(-0.8, 0.8), rng.uniform(0.14, 0.86)
			r = rng.uniform(0.006, 0.013)
			d = np.sqrt((s - px) ** 2 + (t - pz) ** 2) - r + (fray - 0.5) * 0.012
			keep = np.minimum(keep, d)
			soot = np.maximum(soot, sst(0.016, 0.0, d))
		base = mix(base, C(0.05, 0.042, 0.036)[None, None], soot * 0.8)
		a = sst(-0.002, 0.002, keep)
		y0 = (cell // 2) * cw
		x0 = (cell % 2) * cw
		col[y0:y0 + cw, x0:x0 + cw] = np.clip(base, 0, 1)
		alpha[y0:y0 + cw, x0:x0 + cw] = a
	return col, alpha


def normal_from(hgt, strength):
	gx = np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)
	gy = np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)
	nx = -gx * strength
	ny = gy * strength
	nz = np.ones_like(hgt)
	l = np.sqrt(nx * nx + ny * ny + nz * nz)
	return np.stack((nx / l * 0.5 + 0.5, ny / l * 0.5 + 0.5, nz / l * 0.5 + 0.5), axis=-1)


def save_tex(name, rgb, alpha=None, data=False):
	"""To a file and into Blender; JPEG if no alpha, to keep the glb small."""
	TEX.mkdir(parents=True, exist_ok=True)
	h, w = rgb.shape[:2]
	img = bpy.data.images.new(name, w, h, alpha=alpha is not None)
	a = np.ones((h, w), dtype=np.float32) if alpha is None else alpha
	px = np.dstack((rgb, a))[::-1].astype(np.float32)
	img.pixels.foreach_set(px.ravel())
	img.update()
	path = TEX / (name + (".png" if alpha is not None else ".jpg"))
	settings = bpy.context.scene.render.image_settings
	settings.file_format = "PNG" if alpha is not None else "JPEG"
	settings.color_mode = "RGBA" if alpha is not None else "RGB"
	settings.quality = 88
	img.file_format = settings.file_format
	img.save_render(str(path))
	bpy.data.images.remove(img)


# The plug's planks, a shade over the hull's so black gaps have something to bite on.
SKIN_X = half_beam(0.0, GUN_Z)   # the hull's outer planks at the gun ports
PLUG_FILL = 18.0

# The gun deck's light, by eye: the hold's own dim fill, a lantern and a slat of sun
# (over base colour), the distance (m) it all fades to gloom over.
DECK_FILL = 0.7
DECK_LAMP = 2.0
DECK_SLAT = 3.5
DECK_GLOOM = 28.0

# Each material: its shader, albedo, normal, then uniforms. The game takes no
# ambient light, so these fill the shade from the sky's hemisphere as its own
# surfaces do; the glb carries names only and its .import points each at a .tres.
MATERIALS = {
	"hull": ("surface", "ship_hull", "ship_hull_n", {"normal_depth": 1.0, "roughness_value": 0.88, "fill": 10.0}),
	"stern": ("surface", "ship_stern", "ship_stern_n", {"normal_depth": 1.0, "roughness_value": 0.88, "fill": 7.0}),
	"plug": ("surface", "ship_stern", "ship_stern_n", {"normal_depth": 1.0, "roughness_value": 0.88, "fill": PLUG_FILL}),
	"wood": ("surface", "ship_wood", "ship_wood_n", {"normal_depth": 1.0, "roughness_value": 0.9, "fill": 6.0}),
	"wood_in": ("deck", "ship_wood", "ship_wood_n", {"normal_depth": 0.6, "roughness_value": 0.9, "fill": 7.0, "rim": 0.0, "fill_in": DECK_FILL, "lamp_power": DECK_LAMP, "slat_power": DECK_SLAT, "calm": 0.35, "seam": 0.75, "liner": 0.55}),
	"iron_in": ("deck", None, None, {"roughness_value": 0.5, "metallic_value": 0.35, "fill": 1.7, "rim": 0.3, "fill_in": DECK_FILL, "lamp_power": DECK_LAMP * 1.6, "slat_power": DECK_SLAT * 0.3, "glint": 0.2, "inside_x": SKIN_X - 0.46}),
	"lamp": ("lamp", None, None, {}),
	"iron": ("surface", None, None, {"roughness_value": 0.5, "metallic_value": 0.35, "fill": 1.7}),
	"sail": ("cloth", "ship_sail", None, {"fill": 3.6}),
	"rope": ("surface", None, None, {"roughness_value": 0.95, "fill": 1.7, "rim": 0.0}),
	"glass": ("surface", None, None, {"roughness_value": 0.14, "metallic_value": 0.3, "fill": 1.0}),
	"dark": ("surface", None, None, {"roughness_value": 0.95, "fill": 0.0, "rim": 0.0}),
	"paint": ("surface", None, None, {"roughness_value": 0.85, "fill": 6.0}),
}


SHADER_HEAD = """shader_type spatial;
// Written by art/blender/ship/ship_build.py. Lit as the world is: no ambient,
// the sky's hemisphere added as emission (shaders/folk_surface.gdshaderinc),
// so a stock material would go black out of the sun.
render_mode %s;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float fill = 1.6;
uniform float rim = 0.3;
"""
SHADER_FILL = """	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = base * hemi * fill + base * zs_hemi_sky * zs_hemi_energy * edge * rim;
"""
# The gun deck's light, no real lights: everything is worked out on the pixel from
# where it stands in her frame, so a lantern or a port costs a few sums and shadows
# nothing. Lanterns stand in fixed bays, so the two nearest along her are found by
# rounding, not a loop. A slat traces back along the sun to the wall on the sun's
# side and asks if it came through a gun port. The sun's line moves as she turns.
# Past `inside_x`, the hull's skin, this is the plain surface: the guns' barrels.
DECK_CODE = """uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
global uniform vec3 zs_sun_direction;
global uniform vec3 zs_sun_hue;
uniform float normal_depth = 0.0;
uniform float roughness_value = 0.9;
uniform float metallic_value = 0.0;
uniform float fill_in = 1.5;
uniform float lamp_power = 8.0;
uniform float slat_power = 6.0;
uniform float glint = 0.0;
uniform float inside_x = 99.0;
uniform float calm = 0.0;
uniform float seam = 0.0;
uniform float liner = 1.0;
const float KEEL = %(keel)s;
const float STRAKE = %(strake)s;
const float GLOOM = %(gloom)s;
const float LAMP_X = %(lamp_x)s;
const float LAMP_Y = %(lamp_y)s;
const float PITCH = %(pitch)s;
const float LAST = %(last)s;
const float PORT_W = %(port_w)s;
const float PORT_LO = %(port_lo)s;
const float PORT_HI = %(port_hi)s;
const float PORT_X = %(port_x)s;
const float PORT_FIRST = %(port_first)s;
const float PORT_LAST = %(port_last)s;
const vec3 FLAME = vec3(1.0, 0.58, 0.28);
varying vec3 at;
varying vec3 way;
varying flat vec3 sun;
varying flat float eyes;
void vertex() {
	at = VERTEX;
	way = NORMAL;
	mat3 back = transpose(mat3(MODEL_MATRIX));
	sun = normalize(back * zs_sun_direction);
	// An eye out in the day sees a hold as black; it opens up as it comes in.
	vec3 eye = abs(back * (CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz));
	eyes = 1.0 - smoothstep(4.0, 40.0, max(eye.z - 55.0, max(eye.x - %(deck_x)s, 0.0)));
}
// The lantern at bay `z` on side `s`, here: wrapped so ribs turn into shade, not off.
float lantern(vec3 n, float z, float s) {
	if (abs(z) < 1.0 || abs(z) > LAST) return 0.0;
	vec3 l = vec3(s * LAMP_X, LAMP_Y, z) - at;
	float d2 = dot(l, l);
	float near = max(1.0 - d2 / %(lamp_reach)s, 0.0);
	float a = dot(n, l) / sqrt(d2);
	float beat = 0.9 + 0.1 * sin(TIME * (7.0 + fract(z * 0.37 + s) * 5.0) + z);
	return (max(a, 0.0) * 0.8 + 0.2) * near * near * beat;
}
void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	base = mix(base, vec3(0.5, 0.41, 0.31), calm);
	// A strake's seam along the liner: the tile's rows don't fall on them.
	if (abs(way.x) > 0.6) base *= liner * (1.0 - seam * smoothstep(0.42, 0.47, abs(fract((at.y - KEEL) / STRAKE) - 0.5)));
	base *= COLOR.rgb;
	ALBEDO = base;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	if (normal_depth > 0.0) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	vec3 outside = base * hemi * fill + base * zs_hemi_sky * zs_hemi_energy * edge * rim;
	float inside = 1.0 - smoothstep(inside_x, inside_x + 0.4, abs(at.x));
	if (inside > 0.0) {
		vec3 nl = normalize(way);
		float d = length(VERTEX);
		float gloom = 1.0 / (1.0 + d * d / (GLOOM * GLOOM));
		// The two bays either side of here, a lantern each side of the deck.
		float b = floor(at.z / PITCH) * PITCH;
		float s = at.x < 0.0 ? -1.0 : 1.0;
		float lamps = lantern(nl, b, s) + lantern(nl, b + PITCH, s)
			+ 0.55 * (lantern(nl, b, -s) + lantern(nl, b + PITCH, -s));
		// The sun, back along its line to the wall on its side, through a port?
		float slat = 0.0;
		if (sun.y > 0.03 && abs(sun.x) > 0.05) {
			float t = (sign(sun.x) * PORT_X - at.x) / sun.x;
			vec3 h = at + sun * t;
			float pz = clamp(round((h.z + PITCH * 0.5) / PITCH) * PITCH - PITCH * 0.5, PORT_FIRST, PORT_LAST);
			vec2 q = vec2(abs(h.z - pz) - PORT_W * 0.5, max(PORT_LO - h.y, h.y - PORT_HI));
			float through = smoothstep(0.1, -0.1, q.x) * smoothstep(0.1, -0.1, q.y);
			float barrel = smoothstep(0.5, 0.75, length(vec2(h.z - pz, h.y - %(gun)s)));
			slat = t > 0.0 ? through * barrel * max(dot(nl, sun), 0.0) : 0.0;
		}
		vec3 sunlit = zs_sun_hue * slat * slat_power;
		// The fill falls off with the eye's distance, so the hold keeps its gloom.
		vec3 hold = hemi * fill_in * (0.25 + 0.75 * gloom);
		vec3 lit = FLAME * lamps * lamp_power * (0.12 + 0.88 * gloom) + sunlit * (0.3 + 0.7 * gloom);
		vec3 glance = FLAME * lamps * glint * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		EMISSION = mix(outside, (base * (hold + lit) + glance) * eyes, inside);
	} else {
		EMISSION = outside;
	}
}
""" % {"gloom": DECK_GLOOM, "lamp_x": LAMP_X, "lamp_y": LAMP_Z, "pitch": LAMP_PITCH, "last": max(LAMP_BAYS) + 0.5,
	"port_w": PORT_W, "port_lo": row_z(PORT_ROW), "port_hi": row_z(PORT_ROW + PORT_ROWS), "port_x": SKIN_X - 0.56, "deck_x": COR_W * 0.5, "lamp_reach": 140.0 * WIDEN ** 2,
	"port_first": PORTS[0], "port_last": PORTS[-1], "gun": GUN_Z, "keel": KEEL_Z, "strake": STRAKE}
LAMP_CODE = """shader_type spatial;
// Written by art/blender/ship/ship_build.py: a lantern's horn pane, and its beat.
render_mode unshaded, shadows_disabled, fog_disabled;
varying float beat;
void vertex() {
	float z = round(VERTEX.z / 16.0) * 16.0;
	beat = 0.85 + 0.15 * sin(TIME * (7.0 + fract(z * 0.37 + sign(VERTEX.x)) * 5.0) + z);
}
void fragment() {
	float d = length(VERTEX);
	ALBEDO = vec3(1.0, 0.46, 0.14) * 1.5 * beat * (0.03 + 0.97 / (1.0 + d * d / 1600.0));
}
"""

SAIL_CODE = """// A sail: a flat sheet (ship_build.py `sail_geo`) shaped here and nowhere else,
// from the wind every ship sees and her own heading and speed. Pinned at the
// yard, it fills forward; it never bulges aft, it goes slack or flogs instead.
//   COLOR.rgb    the sheet's height, head width and foot width / SAIL_SIZE
//   ship_way     her bow (x, z), her speed (m/s), her turn (rad/s): per ship, scripts/endless/ship_sails.gd
//   ship_slack   1 in a sink: no wind in her, the cloth hangs where gravity has it
global uniform float zs_wind_strength;
global uniform vec2 zs_wind_direction;
global uniform float zs_gust_distance;
instance uniform vec4 ship_way;
instance uniform float ship_slack;
// The true wind (m/s) at zs_wind_strength 1, and how much of it a gust adds or takes.
uniform float wind_ms = 20.0;
uniform float gust_swing = 0.42;
// Her speed's share of the air on the cloth.
uniform float ship_share = 1.0;
// How far (as cos of the angle from the bow) the air must come aft to start filling, and to fill.
uniform float draws_from = -1.0;
uniform float draws_full = -0.55;
// The air (m/s) that fills a sail about two thirds.
uniform float fills_at = 11.0;
// The belly at no air and at full, as a share of her height.
uniform float belly_least = 0.06;
uniform float belly_full = 0.4;
// The farthest aft the cloth goes behind its yard (m).
const float AFT = 0.5;
varying float v_form;
const float SIZE = """ + str(SAIL_SIZE) + r""";

struct Cloth {
	float h;
	float w;
	float wb;
	float seed;
	float fill;
	float depth;
	float lean;
	float flog;
	float taut;
	float air;
	float clock;
	float slack;
	vec3 hang;
};

float sail_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float sail_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(sail_hash(i), sail_hash(i + vec2(1.0, 0.0)), f.x),
		mix(sail_hash(i + vec2(0.0, 1.0)), sail_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The land's gust field (zs_gust_field_at) at a sail's size: the same air, the
// same run downwind, in parcels a sail can feel. -1 a lull, 1 a gust.
float sail_gust(vec2 p) {
	vec2 dir = zs_wind_direction;
	vec2 q = p - dir * zs_gust_distance;
	vec2 e = vec2(dot(q, dir), dot(q, vec2(-dir.y, dir.x))) * vec2(0.016, 0.028);
	float field = sail_noise(e) * 0.62 + sail_noise(e * 2.3 + vec2(3.7, 9.1)) * 0.38;
	return smoothstep(0.28, 0.72, field) * 2.0 - 1.0;
}

// The cloth at s (-1..1 across), t (0 yard .. 1 foot).
vec3 sail_at(float s, float t, Cloth c) {
	float s2 = s * s;
	float hw = mix(c.w, c.wb, t) * 0.5;
	// The deepest of the belly slides to leeward; the leeches keep theirs.
	float sh = s - c.lean * 0.45 * (1.0 - s2);
	float spine = pow(sin(1.5708 * min(t * 1.12, 1.0)), 0.75) * mix(1.0, 0.42, smoothstep(0.62, 1.0, t));
	float leech = 0.92 * pow(sin(3.14159 * min(t * 1.04, 1.0)), 0.9);
	float breathe = 1.0 + 0.07 * sin(c.clock * 0.31 + c.seed * 6.3 - t * 2.6);
	float belly = c.depth * breathe * (spine * (1.0 - sh * sh) + leech * sh * sh);
	// The cloth the belly takes comes off its width and height; the sheets draw
	// the foot in and the foot arches between them.
	float x = s * hw * (1.0 - c.fill * (0.2 * t * t + 0.03 * sin(3.14159 * t)));
	x += c.lean * c.fill * 0.05 * hw * sin(3.14159 * t);
	float take = c.depth / c.h;
	float y = -c.h * t * (1.0 - 0.9 * take * take) + c.h * 0.1 * c.fill * (1.0 - s2) * t * t * t;
	// Slack, it hangs in long folds.
	float along = s * hw;
	float pleat = (0.7 * sin(along * 0.62 + c.seed * 9.0) + 0.3 * sin(along * 1.37 - c.seed * 5.0));
	pleat *= (0.12 + 0.028 * c.h) * (1.0 - c.taut) * smoothstep(0.0, 0.5, t);
	// Flogging: waves run down and across it, biggest at the leeches and the foot.
	float q = (c.h * t + along * 0.5) * 0.5 - c.clock * 1.7 + c.seed * 11.0;
	float flog = sin(q + 0.7 * sin(q)) + 0.3 * sin(1.7 * q + s * 2.5);
	flog *= c.flog * c.h * 0.06 * (0.18 + 0.82 * t) * (0.4 + 0.6 * s2) * smoothstep(0.0, 0.14, t);
	// The leech and foot never quite stop: quick ripples run out along them,
	// flattest when the cloth is taut.
	float edge = max(smoothstep(0.62, 1.0, abs(s)) * smoothstep(0.0, 0.35, t), smoothstep(0.7, 1.0, t));
	float rq = (abs(s) * hw + c.h * t) * 0.85 - c.clock * 2.2 + c.seed * 20.0;
	float ripple = (sin(rq) + 0.35 * sin(1.83 * rq + s * 4.0)) * edge * (0.09 + 0.02 * min(c.air, 16.0)) * (1.35 - c.taut);
	float out_of = max(belly + pleat + flog + ripple, -AFT * smoothstep(0.0, 0.2, t));
	vec3 p = vec3(x, y, -out_of);
	// In a sink it swings to the true down, about the yard; never aft through the mast.
	vec3 swing = (c.hang - vec3(0.0, -1.0, 0.0)) * vec3(1.0, 1.0, c.hang.z > 0.0 ? 0.15 : 1.0);
	return p + swing * c.h * t * c.slack;
}

void vertex() {
	Cloth c;
	c.h = COLOR.r * SIZE;
	c.w = COLOR.g * SIZE;
	c.wb = COLOR.b * SIZE;
	c.seed = fract((c.h * 3.1 + c.w * 0.77 + c.wb * 0.31) * 0.61803);
	float t = clamp(-VERTEX.y / c.h, 0.0, 1.0);
	float s = clamp(VERTEX.x / max(mix(c.w, c.wb, t) * 0.5, 0.01), -1.0, 1.0);
	mat3 m = mat3(MODEL_MATRIX);
	vec3 side = normalize(m[0]);
	float gust = sail_gust(MODEL_MATRIX[3].xz);
	// The air on the cloth: the true wind less her own way through it.
	vec2 air = zs_wind_direction * zs_wind_strength * wind_ms * (1.0 + gust_swing * gust) - ship_way.xy * ship_way.z * ship_share;
	float speed = length(air);
	vec2 way = air / max(speed, 0.01);
	float draw = smoothstep(draws_from, draws_full, dot(way, ship_way.xy));
	float power = 1.0 - exp(-pow(speed / fills_at, 1.5));
	c.slack = clamp(ship_slack, 0.0, 1.0);
	c.fill = draw * power * (1.0 - c.slack);
	c.taut = c.fill * (0.72 + 0.28 * gust);
	c.depth = c.h * mix(belly_least, belly_full * (1.0 + 0.18 * gust), c.fill);
	c.lean = clamp((way.x * side.x + way.y * side.z) * 1.1 - ship_way.w * 7.0, -1.0, 1.0) * draw;
	c.flog = (1.0 - draw) * min(speed / 14.0, 1.0) * (1.0 - c.slack * 0.75);
	c.air = speed;
	c.clock = zs_gust_distance * 2.0;
	c.hang = normalize(transpose(m) * vec3(0.0, -1.0, 0.0));
	float ds = 0.04;
	float dt = 0.03;
	vec3 p = sail_at(s, t, c);
	vec3 pu = (s < 1.0 - ds) ? sail_at(s + ds, t, c) - p : p - sail_at(s - ds, t, c);
	vec3 pv = (t < 1.0 - dt) ? sail_at(s, t + dt, c) - p : p - sail_at(s, t - dt, c);
	VERTEX = vec3(p.x, p.y, VERTEX.z + p.z);
	NORMAL = normalize(cross(pu, pv));
	// How far the cloth has turned from its flat: the belly's form, whatever the light.
	v_form = 1.0 - abs(NORMAL.z);
}
"""

SHADERS = {
	"surface": SHADER_HEAD % "diffuse_lambert, specular_schlick_ggx" + """uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_depth = 0.0;
uniform float roughness_value = 0.9;
uniform float metallic_value = 0.0;
void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb * COLOR.rgb;
	ALBEDO = base;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	if (normal_depth > 0.0) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
""" + SHADER_FILL + "}\n",
	"deck": SHADER_HEAD % "diffuse_lambert, specular_schlick_ggx" + DECK_CODE,
	"lamp": LAMP_CODE,
	"cloth": SHADER_HEAD % "diffuse_lambert, cull_disabled" + SAIL_CODE + """uniform float through = 0.4;
uniform float form = 0.75;
void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec3 base = t.rgb;
	ALBEDO = base;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	BACKLIGHT = base * through;
	ALBEDO *= 1.0 - v_form * form;
""" + SHADER_FILL.replace("vec3 n =", "base *= 1.0 - v_form * form;\n\tvec3 n =") + "}\n",
}


def write_materials():
	TEX.mkdir(parents=True, exist_ok=True)
	for name, code in SHADERS.items():
		(TEX / f"ship_{name}.gdshader").write_text(code)
	for name, (shader, alb, nrm, params) in MATERIALS.items():
		ext = [f'[ext_resource type="Shader" path="{RES}/ship_{shader}.gdshader" id="1"]']
		lines = ['shader = ExtResource("1")']
		for key, tex, i in (("albedo_tex", alb, 2), ("normal_tex", nrm, 3)):
			if tex:
				suffix = ".png" if tex == "ship_sail" else ".jpg"
				ext.append(f'[ext_resource type="Texture2D" path="{RES}/{tex}{suffix}" id="{i}"]')
				lines.append(f'shader_parameter/{key} = ExtResource("{i}")')
		for k, v in params.items():
			lines.append(f"shader_parameter/{k} = {v}")
		text = f'[gd_resource type="ShaderMaterial" format=3]\n\n' + "\n".join(ext) + "\n\n[resource]\n" + "\n".join(lines) + "\n"
		(TEX / f"{name}.tres").write_text(text)


def make_mats(scale):
	print("painting textures...")
	c, h = paint_hull(int(HULL_TEX * scale))
	save_tex("ship_hull", c)
	save_tex("ship_hull_n", normal_from(_half(h), 3.0), data=True)
	c, h = paint_stern(int(STERN_TEX * scale))
	save_tex("ship_stern", c)
	save_tex("ship_stern_n", normal_from(_half(h), 3.0), data=True)
	c, h = paint_wood(int(WOOD_TEX * scale))
	save_tex("ship_wood", c)
	save_tex("ship_wood_n", normal_from(h, 3.0), data=True)
	c, a = paint_sails(int(SAIL_TEX * scale))
	save_tex("ship_sail", c, a)
	write_materials()
	mats = {}
	for name in MAT_NAMES:
		m = bpy.data.materials.new(name)
		mats[name] = m
	return mats


def _half(h):
	"""The height map at half size: the normal maps don't need the albedo's pixels."""
	return h[::2, ::2]


# --- To Blender ---------------------------------------------------------------

STATS = {}


def emit(name, geo, mats, group=None, parent=None, origin=None, extra=(), local=False):
	geos = [geo, *extra]
	vs, uvs, cols, fs, ms = [], [], [], [], []
	for g in geos:
		base = len(vs)
		vs += g.v
		uvs += g.uv
		cols += g.c
		fs += [tuple(i + base for i in f) for f in g.f]
		ms += g.m
	if origin is None:
		origin = Vector((0.0, 0.0, 0.0))
	used = sorted(set(ms))
	remap = {m: i for i, m in enumerate(used)}
	shift = (0.0, 0.0, 0.0) if local else origin
	verts = [(v[0] - shift[0], v[1] - shift[1], v[2] - shift[2]) for v in vs]
	me = bpy.data.meshes.new(name)
	me.from_pydata(verts, [], fs)
	for m in used:
		me.materials.append(mats[MAT_NAMES[m]])
	me.polygons.foreach_set("material_index", [remap[m] for m in ms])
	me.polygons.foreach_set("use_smooth", [True] * len(fs))
	layer = me.uv_layers.new(name="UVMap")
	lv = np.zeros(len(me.loops), dtype=np.int32)
	me.loops.foreach_get("vertex_index", lv)
	uvarr = np.array(uvs, dtype=np.float32)[lv].ravel()
	layer.uv.foreach_set("vector", uvarr)
	ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
	carr = np.ones((len(vs), 4), dtype=np.float32)
	carr[:, :3] = np.array(cols, dtype=np.float32)
	ca.data.foreach_set("color", carr.ravel())
	me.color_attributes.active_color = ca
	me.update()
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	ob.location = origin
	if parent is not None:
		ob.parent = parent
		ob.location = Vector(origin) - parent.matrix_world.translation
	me.calc_loop_triangles()
	key = group or name
	STATS[key] = STATS.get(key, 0) + len(me.loop_triangles)
	return ob


def empty(name, at, parent=None, rot=None):
	ob = bpy.data.objects.new(name, None)
	bpy.context.scene.collection.objects.link(ob)
	ob.location = at
	if rot is not None:
		ob.rotation_euler = rot
	if parent is not None:
		ob.parent = parent
	return ob


def build(fast):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	crack_s = Opening(End(-1.0), 41, SHARDS)
	crack_b = Opening(End(1.0), 57, SHARDS)
	mats = make_mats(0.5 if fast else 1.0)
	print("building...")
	shard_s = [Geo() for _ in range(SHARDS)]
	shard_b = [Geo() for _ in range(SHARDS)]
	hull, teeth = build_hull(crack_s, crack_b, (shard_s, shard_b))
	build_timbers(hull)
	build_port_frames(hull)
	inside = Geo()
	upper = Geo()
	liner(inside, upper)
	build_interior(inside)
	build_decks(upper)
	build_stern(upper)
	build_backing(inside)
	build_beak(upper)
	build_tunnel(hull)
	emit("Hull", hull, mats, extra=(teeth,))
	emit("Upperworks", upper, mats)
	emit("Interior", inside, mats)
	guns, gun_empties = build_guns()
	emit("Cannons", guns, mats)
	for name, g, hinge in build_lids():
		emit(name, g, mats, group="PortLids", origin=hinge, local=True)
	# The plugs: a parent each at the end, shards round their own centres.
	for label, y, gs, tag in (("CrackPlug_Stern", stern_y(COR_Z), shard_s, "S"), ("CrackPlug_Bow", Y_BOW, shard_b, "B")):
		par = empty(label, Vector((0.0, y, COR_Z)))
		bpy.context.view_layer.update()
		for i, g in enumerate(gs):
			if not g.v:
				continue
			mid = Vector(np.array(g.v).mean(axis=0))
			emit(f"Shard_{tag}{i + 1:02d}", g, mats, group=label, parent=par, origin=mid)
		emit(f"Cover_{tag}", build_cover(crack_s if tag == "S" else crack_b), mats, group=label, parent=par, origin=Vector((0.0, y, COR_Z)))
	# Masts.
	yards = []
	for i, spec in enumerate(MASTS):
		g, out = mast_geo(i, spec, SAILS[i])
		mast = emit(f"Mast_{i + 1}", g, mats, group="Masts", origin=(0.0, spec[0], base_deck(spec[0])))
		bpy.context.view_layer.update()
		yards.append(out)
		for k, (name, c, w, zb, wb, cell, tilt) in enumerate(out):
			sg = sail_geo(w, c.z - zb, wb, cell)
			sob = emit(f"Sail_{name}", sg, mats, group="Sails", parent=mast, origin=c, local=True)
			sob.rotation_euler = (0.0, -math.radians(tilt), math.radians(BRACE))
	# Bowsprit and its sail.
	g = Geo()
	c, tilt = build_bowsprit(g)
	sprit = emit("Bowsprit", g, mats, origin=BOWSPRIT[0])
	bpy.context.view_layer.update()
	sob = emit("Sail_0a", sail_geo(20.0, 7.0, 21.0, 3), mats, group="Sails", parent=sprit, origin=c, local=True)
	sob.rotation_euler = (0.0, -tilt, 0.0)
	# Rigging: the fine lines hide at a distance, the stays do not.
	fine, stays = Geo(), Geo()
	build_rigging(fine, stays, yards)
	emit("Rigging", fine, mats)
	emit("Stays", stays, mats)
	# The anchors for code.
	for name, at, side in gun_empties:
		empty(name, at, rot=(0.0, 0.0, -side * math.pi * 0.5))
	empty("Relic", (0.0, 0.0, COR_Z))
	empty("CorridorStart", (0.0, -COR_LEN * 0.5, COR_Z))   # the stern's end, Godot z +55
	empty("CorridorEnd", (0.0, COR_LEN * 0.5, COR_Z))      # the bow's end, Godot z -55


def export():
	OUT.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=str(OUT), export_format="GLB", use_selection=False, export_apply=False,
		export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
		export_normals=True, export_tangents=False, export_animations=False, export_cameras=False, export_lights=False,
		export_image_format="AUTO", export_morph=False, export_skins=False)


def read_glb(path):
	raw = Path(path).read_bytes()
	jlen = struct.unpack_from("<I", raw, 12)[0]
	doc = json.loads(raw[20:20 + jlen].decode("utf8"))
	blen = struct.unpack_from("<I", raw, 20 + jlen)[0]
	return doc, raw[28 + jlen:28 + jlen + blen]


# --- Proof, off the written file ----------------------------------------------

def accessor(doc, bin_, i):
	a = doc["accessors"][i]
	v = doc["bufferViews"][a["bufferView"]]
	comp = {5126: "f4", 5125: "u4", 5123: "u2", 5121: "u1"}[a["componentType"]]
	n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
	stride = v.get("byteStride", 0)
	off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
	if stride and stride != np.dtype(comp).itemsize * n:
		raise RuntimeError("interleaved accessor")
	return np.frombuffer(bin_, dtype=comp, count=a["count"] * n, offset=off).reshape(-1, n)


def node_matrix(n):
	if "matrix" in n:
		return np.array(n["matrix"], dtype=np.float64).reshape(4, 4).T
	t = n.get("translation", (0, 0, 0))
	q = n.get("rotation", (0, 0, 0, 1))
	s = n.get("scale", (1, 1, 1))
	x, y, z, w = q
	r = np.array((
		(1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
		(2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
		(2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y))))
	m = np.eye(4)
	m[:3, :3] = r * np.array(s)
	m[:3, 3] = t
	return m


def world_tris(doc, bin_):
	"""Every node's triangles in glTF world space: {top node name: [array n,3,3]}."""
	out = {}
	def walk(i, pm, top):
		n = doc["nodes"][i]
		m = pm @ node_matrix(n)
		name = n.get("name", "")
		t = top or name
		if "mesh" in n:
			for pr in doc["meshes"][n["mesh"]]["primitives"]:
				pos = accessor(doc, bin_, pr["attributes"]["POSITION"]).astype(np.float64)
				idx = accessor(doc, bin_, pr["indices"]).ravel().astype(np.int64)
				w = (pos @ m[:3, :3].T) + m[:3, 3]
				out.setdefault(t, []).append(w[idx].reshape(-1, 3, 3))
		for c in n.get("children", ()):
			walk(c, m, t)
	for i in doc["scenes"][0]["nodes"]:
		walk(i, np.eye(4), None)
	return {k: np.concatenate(v) for k, v in out.items()}


def tri_hits_box(tris, lo, hi):
	"""Which triangles touch the box lo..hi (separating axes, vectorised)."""
	c = (lo + hi) * 0.5
	e = (hi - lo) * 0.5
	v = tris - c
	keep = np.all(v.min(axis=1) <= e, axis=1) & np.all(v.max(axis=1) >= -e, axis=1)
	v = v[keep]
	ids = np.nonzero(keep)[0]
	if len(v) == 0:
		return ids
	f = np.stack((v[:, 1] - v[:, 0], v[:, 2] - v[:, 1], v[:, 0] - v[:, 2]), axis=1)
	nrm = np.cross(f[:, 0], f[:, 1])
	axes = [nrm[:, None, :]]
	ok = np.ones(len(v), dtype=bool)
	for ax in np.eye(3):
		cr = np.cross(f, ax)
		axes.append(cr)
	for a in axes:
		for k in range(a.shape[1]):
			ak = a[:, k]
			p = np.einsum("ij,ikj->ik", ak, v)
			r = (np.abs(ak) * e).sum(axis=1)
			ok &= ~((p.min(axis=1) > r) | (p.max(axis=1) < -r))
	return ids[ok]


def prove():
	"""Off the glb: the corridor is empty, the mouths clear, the nodes all there."""
	doc, bin_ = read_glb(OUT)
	bad = 0
	tris = world_tris(doc, bin_)
	# glTF: x, y up, z = -Blender y.
	def box(xw, y0, y1, z0, z1):
		return np.array((-xw, z0, -y1)), np.array((xw, z1, -y0))
	def check(label, lo, hi, skip):
		nonlocal bad
		for name, t in tris.items():
			if name in skip:
				continue
			hits = tri_hits_box(t, lo, hi)
			if len(hits):
				bad += 1
				p = t[hits].reshape(-1, 3)
				print(f"FAIL {label}: {name} has {len(hits)} triangles in it, e.g. {p[0]}")
	plugs = {"CrackPlug_Stern", "CrackPlug_Bow"}
	cl = COR_LEN * 0.5
	check("corridor", *box(COR_W * 0.5, -cl, cl, COR_FLOOR, COR_TOP), set())
	# Past the corridor's ends, out through each mouth, the crack's rectangle is clear.
	# (A plank's edge on the rectangle's line touches, it doesn't intrude: 4 cm grace.)
	e = 0.04
	check("stern mouth", *box(CRACK_W * 0.5 - e, -cl - EXIT_CLEAR, -cl, COR_Z - CRACK_H * 0.5 + e, COR_Z + CRACK_H * 0.5 - e), plugs)
	check("bow mouth", *box(CRACK_W * 0.5 - e, cl, cl + EXIT_CLEAR, COR_Z - CRACK_H * 0.5 + e, COR_Z + CRACK_H * 0.5 - e), plugs)
	names = [n.get("name", "") for n in doc["nodes"]]
	want = ["Hull", "CrackPlug_Stern", "CrackPlug_Bow", "Mast_1", "Mast_2", "Mast_3", "Relic", "CorridorStart", "CorridorEnd", "Gun_L_01", "Gun_R_01"]
	for w in want:
		if w not in names:
			print("FAIL missing node", w)
			bad += 1
	# The guns' muzzles against the contract: x +-GUN_X, at y GUN_Z.
	for n in doc["nodes"]:
		if n.get("name", "").startswith("Gun_"):
			t = n["translation"]
			if abs(abs(t[0]) - GUN_X) > 1e-3 or abs(t[1] - GUN_Z) > 1e-3:
				print("FAIL gun", n["name"], t)
				bad += 1
	total = sum(len(t) for t in tris.values())
	print(f"triangles (glb): {total}")
	print(f"guns a side: {len(PORTS)}")
	for k, v in sorted(STATS.items(), key=lambda kv: -kv[1]):
		print(f"  {k}: {v}")
	print("corridor clear: " + ("no" if bad else "yes"))
	return bad


def main():
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	build("--fast" in args)
	export()
	sys.exit(1 if prove() else 0)


main()
