"""Concept blockout of the redesigned pirate ship, for stills only.

    python3 tools/blender.py run art/blender/ship/ship_concept_build.py -- [--out scratch/ship_concept]

Rough geometry for the new outline (a sheer sweeping up to a tall stern castle,
a raised forecastle, a bellied hull, a carved head at the bow whose open jaws
frame the gun deck's exit, tall masts, big painted sails, flags, deck guns),
written once per paint scheme as <out>/ship_<scheme>.glb. The shape is the same
in every scheme; colours, sail glyphs and the friezes differ. Not the build:
nothing here is checked against the corridor or `solids()` beyond keeping the
jaws outside the exit rectangle. The shipped pirate_ship.glb is untouched.

Numbers are in the ship's frame as the game has it (Godot axes: x across,
y up from the waterline, bow toward -z); `bv` turns them into Blender's.
"""
import math
import sys
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[3]

# The gun deck corridor (pirate_ship.gd at plane scale 1): 18 x 10 m, floor y 3.
COR_W = 18.0
COR_FLOOR = 3.0
COR_TOP = 13.0
COR_END = 56.5          # the crack plates at both ends

STERN_Z = 58.0          # the transom
BOW_Z = -57.0           # the hull's end behind the head
# The sheer: the rail's height along the hull (z, y).
SHEER = [(-57, 25.0), (-48, 24.0), (-40, 22.5), (-30, 19.5), (-15, 17.6), (0, 17.0),
		 (12, 17.5), (22, 19.5), (30, 23.0), (40, 27.5), (50, 30.5), (58, 32.0)]
# The midship section's half breadth by height: a round belly, tumblehome above.
SECTION = [(-6.0, 1.5), (-5.0, 4.5), (-4.0, 7.2), (-2.5, 10.0), (-1.0, 11.8), (0.5, 13.0), (2.5, 13.9),
		   (5.0, 14.4), (8.0, 14.5), (11.0, 14.0), (13.4, 13.3), (15.0, 12.6), (17.0, 11.8), (24.0, 10.4), (32.0, 9.2)]
ROWS = [-6.0, -5.0, -4.0, -2.5, -1.0, 0.0, 0.8, 2.6, 4.0, 5.0, 7.0, 9.0, 11.0, 12.0, 13.4, 14.0, 14.6, 16.4, 17.0]
UPPER = [0.0, 0.55, 0.62, 0.86, 1.0]   # rows above 17 m, as shares of the way to the rail
DECKS = [  # (name, top y, z from, z to)
	("main", 15.0, -40.0, 30.0), ("quarter", 22.0, 30.0, 58.0), ("poop", 28.0, 44.0, 58.0),
	("fore", 21.0, -57.0, -38.0)]
MASTS = [  # (z, foot y, height top y, [(yard y, drop, top width, foot width, glyph)])
	(-30.0, 15.0, 92.0, [(40.0, 17.0, 42.0, 47.0, "fore"), (61.0, 18.0, 34.0, 41.0, "plain"), (78.0, 14.0, 25.0, 31.0, "plain")]),
	(2.0, 15.0, 104.0, [(44.0, 20.0, 47.0, 53.0, "sun"), (67.0, 20.0, 39.0, 46.0, "plain"), (86.0, 16.0, 29.0, 36.0, "plain"), (100.0, 11.0, 20.0, 26.0, "plain")]),
	(33.0, 22.0, 80.0, [(48.0, 16.0, 31.0, 35.0, "plain"), (66.0, 15.0, 24.0, 29.0, "plain")]),
]
BRACE = math.radians(34.0)
HULL_GUNS = (-32.0, 0.0, 32.0)        # Gun_*_01..03, y 8
SHUT_PORTS = (-16.0, 16.0, 44.0, -46.0)
DECK_GUNS = (-12.0, 16.0)             # DeckGun_*_01..02 on the main deck
# The carved head at the bow is parked (--head brings it back); without it the bow
# is a framed portal round the exit, a beak under it, and a bowsprit.
HEAD = "--head" in sys.argv
# The fore course's glyph (--fore spiral|serpent|sun): the options for the user to pick.
FORE = sys.argv[sys.argv.index("--fore") + 1] if "--fore" in sys.argv else "spiral"
SPRIT_TIP = (0.0, 44.0, -100.0)

# Dark brown wood with grey stone and iron, no yellow; they differ in how dark the
# hull is, the sails' canvas, and the accent (none, faded teal, a little red).
# g1, g2: the glyphs' two fills; acc: a glyph's small centres.
SCHEMES = {
	# The darkest: tarred hull, grey canvas, no colour at all.
	"tar_slate": {
		"hull": "221d1a", "upper": "272220", "band": "1f1a17", "wale": "151210", "boot": "5c5650", "bottom": "2a2420",
		"rail": "5f5a54", "deck": "4e4136", "wood": "2e2621", "iron": "2b2c2e", "plug": "2e2620", "glass": "2c3238",
		"stone": "6b6a67", "pig1": "4f4d4a", "pig2": "3e3c3a", "bone": "b3ada2", "dark": "141312",
		"sail": "65696e", "ink": "1f1d1b", "g1": "3e342c", "g2": "5e5952", "acc": "c4beb2", "flag1": "3a332d", "flag2": "6e6a64",
		"frieze": ("4a3e34", "8f8b84", "2a2420"),
	},
	# Dark brown hull and canvas, light glyphs, a little faded teal.
	"umber_verdigris": {
		"hull": "3b2a1d", "upper": "433022", "band": "36271b", "wale": "211810", "boot": "6a655d", "bottom": "2f2822",
		"rail": "3a2e24", "deck": "66533f", "wood": "3d3026", "iron": "2a2b2d", "plug": "2e2620", "glass": "2c3238",
		"stone": "6f6e6a", "pig1": "56716a", "pig2": "4b4844", "bone": "aca698", "dark": "121110",
		"sail": "5a4636", "ink": "221b16", "g1": "a39d90", "g2": "60817a", "acc": "60817a", "flag1": "2c2520", "flag2": "60817a",
		"frieze": ("45362a", "6b8c84", "2a211a"),
	},
	# Grey-brown hull, ash canvas, dark glyphs, red only in small touches.
	"ash_rust": {
		"hull": "57524b", "upper": "5f5a53", "band": "514c45", "wale": "2e2b28", "boot": "77726a", "bottom": "3a2c26",
		"rail": "38302a", "deck": "6a5745", "wood": "42352b", "iron": "2b2c2e", "plug": "302822", "glass": "2c3238",
		"stone": "7b7a76", "pig1": "7a3a2e", "pig2": "55524d", "bone": "b8b2a6", "dark": "131211",
		"sail": "7c7f82", "ink": "2b2520", "g1": "4a3c31", "g2": "6a655e", "acc": "7a3a2e", "flag1": "3a302a", "flag2": "7a3a2e",
		"frieze": ("4e4236", "8f8a82", "2d2620"),
	},
}
# The wear each material gets: plank wood, painted wood, carved stone (None: flat).
KIND = {"hull": "paint", "upper": "paint", "band": "paint", "boot": "paint", "bottom": "paint", "rail": "paint",
		"wale": "wood", "deck": "wood", "wood": "wood", "plug": "wood", "stone": "stone", "pig1": "stone",
		"pig2": "stone", "bone": "stone"}


def rgb(h):
	return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def bv(p):
	"""Ship frame (Godot) to Blender."""
	return (p[0], -p[2], p[1])


def lerp_table(table, x):
	if x <= table[0][0]:
		return table[0][1]
	for (x0, y0), (x1, y1) in zip(table, table[1:]):
		if x <= x1:
			t = (x - x0) / (x1 - x0)
			return y0 + (y1 - y0) * t
	return table[-1][1]


def rail(z):
	return lerp_table(SHEER, z)


def stem_z(y):
	"""The stem, raked: further forward the higher it goes."""
	return -72.0 - 0.25 * y


def half(y, z):
	"""Half breadth at height y, station z: a plan that narrows all along, a run
	aft, and a prow that closes to the raked stem."""
	w = lerp_table(SECTION, y) * (1.0 - 0.06 * (z / 58.0) ** 2)
	if z > 34.0:   # the run aft: the bottom tucks in, the castle squares off
		t = (z - 34.0) / (STERN_Z - 34.0)
		w *= 1.0 - (0.55 * t * t if y < 3.0 else 0.12 * t * t)
		if y < 3.0:
			w = max(w, 1.0)
	if z < -40.0:  # the prow
		t = min(1.0, (-40.0 - z) / (-40.0 - stem_z(y)))
		w *= max(0.0, 1.0 - t ** 2.2) ** 0.5
	return w


def rake(p):
	"""The stern rakes: the counter over the exit leans out aft, the sternpost tucks in."""
	x, y, z = p
	if z > 40.0:
		t = min(1.0, (z - 40.0) / (STERN_Z - 40.0)) ** 2
		z += t * (0.32 * max(0.0, y - 14.0) - 0.45 * max(0.0, 2.6 - y))
	return (x, y, z)


def cross_z(y, x=10.4):
	"""Where the prow's side at height y comes in to x: the exit's edge."""
	lo, hi = stem_z(y), -40.0
	for _ in range(30):
		mid = (lo + hi) * 0.5
		if half(y, mid) < x:
			lo = mid
		else:
			hi = mid
	return hi


# --- Images -----------------------------------------------------------------------

def vnoise(n, cx, cy, rng):
	"""Tiling value noise, n x n, cx by cy cells."""
	g = rng.random((cy, cx)).astype(np.float32)
	def axis(c):
		t = np.arange(n) * c / n
		i0 = t.astype(int)
		f = t - i0
		return i0 % c, (i0 + 1) % c, f * f * (3 - 2 * f)
	y0, y1, fy = axis(cy)
	x0, x1, fx = axis(cx)
	fx, fy = fx[None, :], fy[:, None]
	a, b = g[y0][:, x0], g[y0][:, x1]
	c, d = g[y1][:, x0], g[y1][:, x1]
	return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def wear(kind, col, chip, seed, n=256):
	"""A tinted tile with value variation: planks, painted planks with chips, or stone courses."""
	rng = np.random.default_rng(seed)
	Y, X = np.mgrid[0:n, 0:n]
	v = np.ones((n, n), np.float32)
	mott = vnoise(n, 4, 4, rng) - 0.5
	if kind in ("wood", "paint"):
		ph = n // 8
		plank = Y // ph
		jit = rng.uniform(-1, 1, 8)[plank]
		off = rng.integers(0, n, 8)[plank]
		grain = vnoise(n, 3, 48, rng) - 0.5
		k = 0.11 if kind == "wood" else 0.05
		v *= 1.0 + k * jit + (0.1 if kind == "wood" else 0.04) * grain + 0.14 * mott
		v[(Y % ph) < 2] *= 0.62 if kind == "wood" else 0.8
		v[((X + off) % (n // 2)) < 2] *= 0.72 if kind == "wood" else 0.86
	else:
		v *= 1.0 + 0.2 * mott + 0.1 * (vnoise(n, 12, 12, rng) - 0.5) + 0.06 * (vnoise(n, 48, 48, rng) - 0.5)
		v[np.abs(vnoise(n, 5, 5, rng) - 0.5) < 0.008] *= 0.55     # hairline cracks
	out = np.clip(np.array(col)[None, None, :] * v[..., None], 0, 1)
	if kind == "paint":   # the paint worn through to the wood here and there
		m = (vnoise(n, 20, 20, rng) > 0.78) & (vnoise(n, 6, 6, rng) > 0.45)
		out[m] = out[m] * 0.35 + np.array(chip) * 0.65
	return out.astype(np.float32)


class Canvas:
	"""A numpy raster; coordinates in 0..1, v down."""

	def __init__(self, w, h, col):
		self.w, self.h = w, h
		self.a = np.zeros((h, w, 3), np.float32)
		self.a[:] = col
		ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
		self.X = (xs + 0.5) / w
		self.Y = (ys + 0.5) / h

	def put(self, m, col):
		self.a[m] = col

	def rect(self, x0, y0, x1, y1, col):
		self.put((self.X >= x0) & (self.X < x1) & (self.Y >= y0) & (self.Y < y1), col)

	def disc(self, cx, cy, r, col, sy=1.0):
		self.put(((self.X - cx) ** 2 + ((self.Y - cy) * sy) ** 2) < r * r, col)

	def ring(self, cx, cy, r0, r1, col, sy=1.0):
		d = ((self.X - cx) ** 2 + ((self.Y - cy) * sy) ** 2)
		self.put((d < r1 * r1) & (d >= r0 * r0), col)

	def poly(self, pts, col):
		inside = np.zeros(self.X.shape, bool)
		n = len(pts)
		for i in range(n):
			x0, y0 = pts[i]
			x1, y1 = pts[(i + 1) % n]
			c = ((y0 > self.Y) != (y1 > self.Y)) & (self.X < (x1 - x0) * (self.Y - y0) / (y1 - y0 + 1e-9) + x0)
			inside ^= c
		self.put(inside, col)

	def fret(self, x0, y0, x1, y1, n, fg, bg, flip=False):
		"""A band of stepped frets: a stair and a square hook per cell."""
		self.rect(x0, y0, x1, y1, bg)
		cw = (x1 - x0) / n
		h = y1 - y0
		for i in range(n):
			cx = x0 + i * cw
			for s in range(4):   # the stair
				sx = cx + s * cw * 0.12
				self.rect(sx, y0 + h * (0.75 - s * 0.17), sx + cw * 0.12, y1, fg)
			hx = cx + cw * 0.48    # the hook: a squared spiral
			t = cw * 0.09
			self.rect(hx, y0 + h * 0.12, hx + cw * 0.44, y0 + h * 0.12 + h * 0.14, fg)
			self.rect(hx + cw * 0.44 - t, y0 + h * 0.12, hx + cw * 0.44, y1 - h * 0.1, fg)
			self.rect(hx + cw * 0.12, y1 - h * 0.24, hx + cw * 0.44, y1 - h * 0.1, fg)
			self.rect(hx + cw * 0.12, y0 + h * 0.42, hx + cw * 0.12 + t, y1 - h * 0.1, fg)
			self.rect(hx + cw * 0.12, y0 + h * 0.42, hx + cw * 0.3, y0 + h * 0.54, fg)
		if flip:
			self.a[int(y0 * self.h):int(y1 * self.h)] = self.a[int(y0 * self.h):int(y1 * self.h)][::-1]

	def weather(self, seed, k=0.08):
		"""Canvas or paint with some value in it: panel seams, a mottle."""
		rng = np.random.default_rng(seed)
		n = max(self.w, self.h)
		m = 1.0 + k * (vnoise(n, 3, 3, rng) - 0.5) * 2.0
		m *= 1.0 + 0.03 * (vnoise(n, 48, 48, rng) - 0.5)
		m = m[:self.h, :self.w]
		if self.w == self.h:
			m[:, (np.arange(self.w) % (self.w // 12)) < 2] *= 0.9
		self.a *= m[..., None]

	def save(self, path):
		img = bpy.data.images.new(path.stem, self.w, self.h, alpha=True)
		px = np.ones((self.h, self.w, 4), np.float32)
		px[..., :3] = np.clip(self.a[::-1], 0.0, 1.0)  # Blender rows go up
		img.pixels.foreach_set(px.ravel())
		img.filepath_raw = str(path)
		img.file_format = "PNG"
		img.save()
		return img


def face_glyph(c, x0, y0, x1, y1, ink, a, b, bone, acc):
	"""A face in a cartouche: headdress steps, ring eyes, nose bar, a toothed mouth, ear spools."""
	w, h = x1 - x0, y1 - y0
	X = lambda u: x0 + u * w
	Y = lambda v: y0 + v * h
	c.rect(X(0.06), Y(0.02), X(0.94), Y(0.98), ink)                  # the cartouche
	c.rect(X(0.1), Y(0.06), X(0.9), Y(0.94), b)
	c.rect(X(0.2), Y(0.06), X(0.8), Y(0.16), a)                      # headdress steps
	c.rect(X(0.3), Y(0.0), X(0.7), Y(0.08), a)
	c.rect(X(0.42), Y(-0.04), X(0.58), Y(0.02), a)
	c.rect(X(0.16), Y(0.2), X(0.84), Y(0.86), bone)                 # the face
	c.rect(X(0.16), Y(0.2), X(0.84), Y(0.3), ink)                   # brow band
	for i in range(6):
		c.rect(X(0.2 + i * 0.11), Y(0.22), X(0.26 + i * 0.11), Y(0.28), a)
	for s in (-1, 1):
		ex = 0.5 + s * 0.17
		c.disc(X(ex), Y(0.42), w * 0.12, ink, h / w)                  # ring eyes
		c.disc(X(ex), Y(0.42), w * 0.085, b, h / w)
		c.disc(X(ex), Y(0.42), w * 0.04, ink, h / w)
		c.disc(X(0.5 + s * 0.42), Y(0.5), w * 0.1, ink, h / w)        # ear spools
		c.disc(X(0.5 + s * 0.42), Y(0.5), w * 0.065, a, h / w)
		c.disc(X(0.5 + s * 0.42), Y(0.5), w * 0.03, acc, h / w)
		c.rect(X(0.5 + s * 0.42 - 0.03), Y(0.58), X(0.5 + s * 0.42 + 0.03), Y(0.72), a)
	c.poly([(X(0.44), Y(0.36)), (X(0.56), Y(0.36)), (X(0.6), Y(0.6)), (X(0.4), Y(0.6))], a)  # nose
	c.rect(X(0.46), Y(0.4), X(0.54), Y(0.46), acc)
	c.rect(X(0.36), Y(0.58), X(0.64), Y(0.62), ink)                 # nose bar
	c.rect(X(0.28), Y(0.66), X(0.72), Y(0.82), ink)                 # the open mouth
	for i in range(5):
		c.rect(X(0.31 + i * 0.084), Y(0.66), X(0.36 + i * 0.084), Y(0.7), bone)
		c.rect(X(0.31 + i * 0.084), Y(0.78), X(0.36 + i * 0.084), Y(0.82), bone)
	c.rect(X(0.28), Y(0.66), X(0.31), Y(0.76), bone)                 # fangs
	c.rect(X(0.69), Y(0.66), X(0.72), Y(0.76), bone)


def sun_glyph(c, cx, cy, r, ink, a, b, bone, acc, sy=1.0):
	"""A sun disc: cardinal blades, diagonal points, rings, an eye at the centre."""
	for k in range(8):
		ang = k * math.pi / 4.0
		ca, sa = math.cos(ang), math.sin(ang)
		px, py = -sa, ca
		rr = r * (1.0 if k % 2 == 0 else 0.86)
		wd = r * (0.2 if k % 2 == 0 else 0.13)
		col = a if k % 2 == 0 else b
		pts = [(cx + px * wd, cy + py * wd / sy), (cx + ca * rr, cy + sa * rr / sy), (cx - px * wd, cy - py * wd / sy)]
		c.poly(pts, ink)
		pts2 = [(cx + px * wd * 0.6, cy + py * wd * 0.6 / sy), (cx + ca * rr * 0.9, cy + sa * rr * 0.9 / sy),
				(cx - px * wd * 0.6, cy - py * wd * 0.6 / sy)]
		c.poly(pts2, col)
	c.disc(cx, cy, r * 0.6, ink, sy)
	c.disc(cx, cy, r * 0.54, a, sy)
	c.ring(cx, cy, r * 0.4, r * 0.46, ink, sy)
	for k in range(12):
		ang = k * math.pi / 6.0
		c.disc(cx + math.cos(ang) * r * 0.5, cy + math.sin(ang) * r * 0.5 / sy, r * 0.03, bone, sy)
	c.disc(cx, cy, r * 0.36, bone, sy)
	c.disc(cx, cy, r * 0.22, acc, sy)
	c.disc(cx, cy, r * 0.1, ink, sy)


class Glyph:
	"""A square brush-painted glyph: colour and coverage, painted in strokes."""

	def __init__(self, n=512):
		self.n = n
		self.a = np.zeros((n, n, 3), np.float32)
		self.m = np.zeros((n, n), np.float32)
		ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
		self.X, self.Y = (xs + 0.5) / n, (ys + 0.5) / n
		self.rng = np.random.default_rng(11)

	def put(self, mask, col):
		if col is None:
			self.m[mask] = 0.0
		else:
			self.a[mask] = col
			self.m[mask] = 1.0

	def stroke(self, pts, ws, col):
		"""A brush stroke along pts, its width ws at each point, a little uneven."""
		pts = np.array(pts, np.float32)
		ws = np.array(ws, np.float32) * (1.0 + 0.18 * (self.rng.random(len(pts)) - 0.5))
		mask = np.zeros(self.X.shape, bool)
		for i in range(len(pts) - 1):
			(x0, y0), (x1, y1) = pts[i], pts[i + 1]
			r = max(ws[i], ws[i + 1])
			lo_x, hi_x = int(max(0, (min(x0, x1) - r) * self.n)), int(min(self.n, (max(x0, x1) + r) * self.n + 1))
			lo_y, hi_y = int(max(0, (min(y0, y1) - r) * self.n)), int(min(self.n, (max(y0, y1) + r) * self.n + 1))
			if lo_x >= hi_x or lo_y >= hi_y:
				continue
			X, Y = self.X[lo_y:hi_y, lo_x:hi_x], self.Y[lo_y:hi_y, lo_x:hi_x]
			dx, dy = x1 - x0, y1 - y0
			t = np.clip(((X - x0) * dx + (Y - y0) * dy) / (dx * dx + dy * dy + 1e-9), 0, 1)
			d = np.hypot(X - (x0 + t * dx), Y - (y0 + t * dy))
			mask[lo_y:hi_y, lo_x:hi_x] |= d < ws[i] + (ws[i + 1] - ws[i]) * t
		self.put(mask, col)

	def disc(self, cx, cy, r, col):
		self.put((self.X - cx) ** 2 + (self.Y - cy) ** 2 < r * r, col)

	def arc(self, cx, cy, r, a0, a1, w0, w1, col, n=40, wob=0.0):
		ts = np.linspace(0, 1, n)
		ang = a0 + (a1 - a0) * ts
		rr = r + wob * np.sin(ts * 9.0)
		self.stroke(list(zip(cx + np.cos(ang) * rr, cy + np.sin(ang) * rr)), list(w0 + (w1 - w0) * ts), col)

	def worn(self):
		"""Worn into the canvas: patchy coverage, a few bare flecks."""
		fleck = vnoise(self.n, 48, 48, self.rng) > 0.8
		patch = 0.75 + 0.25 * vnoise(self.n, 5, 5, self.rng)
		self.m *= np.where(fleck, 0.25, patch)


def glyph_art(kind, ink, a, b, acc):
	g = Glyph()
	if kind == "spiral":   # wind: a breath spiral in an uneven ring, curls on the four quarters
		g.arc(0.5, 0.5, 0.42, 0, 2 * math.pi, 0.03, 0.03, ink, 90, 0.008)
		ts = np.linspace(0, 1, 120)
		ang = 0.4 + ts * 3.3 * math.pi
		rr = 0.04 + 0.27 * ts
		g.stroke(list(zip(0.5 + np.cos(ang) * rr, 0.5 + np.sin(ang) * rr)), list(0.018 + 0.045 * ts), ink)
		g.disc(0.5, 0.5, 0.05, acc)
		for k in range(4):
			c = k * math.pi / 2 + math.pi / 4
			cx, cy = 0.5 + math.cos(c) * 0.42, 0.5 + math.sin(c) * 0.42
			g.arc(cx + math.cos(c) * 0.04, cy + math.sin(c) * 0.04, 0.05, c + math.pi, c + 2.6 * math.pi, 0.022, 0.006, b, 30)
	elif kind == "serpent":   # a serpent in profile, its body in an S, a crest of feathers
		ts = np.linspace(0, 1, 90)
		xs = 0.06 + 0.64 * ts
		ys = 0.56 + 0.2 * np.sin(ts * 2.0 * math.pi + 0.3) * (0.4 + 0.6 * ts)
		g.stroke(list(zip(xs, ys)), list(0.022 + 0.075 * ts ** 0.7), ink)
		for k in range(6):   # crest along the back
			t = 0.25 + k * 0.12
			i = int(t * 89)
			x, y = xs[i], ys[i]
			g.stroke([(x, y - 0.04), (x - 0.05, y - 0.19), (x - 0.1, y - 0.23)], [0.03, 0.02, 0.006], b)
		hx, hy = 0.74, ys[-1] - 0.02
		g.disc(hx, hy, 0.12, ink)
		g.stroke([(hx - 0.02, hy - 0.04), (hx + 0.12, hy - 0.07), (hx + 0.16, hy - 0.04)], [0.05, 0.04, 0.02], ink)  # upper jaw
		g.stroke([(hx, hy + 0.04), (hx + 0.11, hy + 0.07), (hx + 0.14, hy + 0.11)], [0.04, 0.03, 0.012], ink)       # lower jaw
		g.stroke([(hx + 0.08, hy + 0.0), (hx + 0.16, hy + 0.01), (hx + 0.2, hy - 0.01)], [0.008, 0.006, 0.003], acc)  # tongue
		g.disc(hx + 0.02, hy - 0.035, 0.024, acc)
		g.disc(hx + 0.025, hy - 0.035, 0.01, ink)
	else:   # the sun with curved rays
		for k in range(12):
			c = k * math.pi / 6
			g.arc(0.5, 0.5, 0.0, 0, 0, 0, 0, ink, 2)
			ts = np.linspace(0, 1, 24)
			ang = c + 0.45 * ts
			rr = 0.25 + 0.2 * ts
			g.stroke(list(zip(0.5 + np.cos(ang) * rr, 0.5 + np.sin(ang) * rr)), list(0.04 - 0.034 * ts), ink if k % 2 == 0 else b)
		g.disc(0.5, 0.5, 0.2, ink)
		g.arc(0.5, 0.5, 0.15, 0, 2 * math.pi, 0.012, 0.012, acc, 60, 0.004)
		g.disc(0.5, 0.5, 0.07, b)
	g.worn()
	return g


def sail_image(s, glyph, path, aspect=3.0):
	"""Canvas with a plain border; a course carries one glyph at its own aspect
	(aspect: the sail's width over its depth), centred."""
	sail, ink, a, b, bone, acc = (rgb(s[k]) for k in ("sail", "ink", "g1", "g2", "bone", "acc"))
	c = Canvas(1024, 512, sail)
	c.rect(0, 0, 1, 0.03, ink)
	c.rect(0, 0.97, 1, 1, ink)
	c.rect(0, 0, 0.012, 1, ink)
	c.rect(0.988, 0, 1, 1, ink)
	if glyph != "plain":
		g = glyph_art(glyph, np.array(ink), np.array(a), np.array(b), np.array(acc))
		gh = 0.8                              # of the sail's depth
		gw = gh / aspect                      # of its width: the glyph stays square on the cloth
		rows = int(gh * c.h)
		cols = int(gw * c.w)
		r0, c0 = (c.h - rows) // 2, (c.w - cols) // 2
		ri = (np.arange(rows) * g.n / rows).astype(int)
		ci = (np.arange(cols) * g.n / cols).astype(int)
		col = g.a[ri][:, ci]
		m = g.m[ri][:, ci][..., None]
		region = c.a[r0:r0 + rows, c0:c0 + cols]
		c.a[r0:r0 + rows, c0:c0 + cols] = region * (1 - m) + col * m
	c.weather(len(glyph) * 7 + 1)
	return c.save(path)


def frieze_image(s, path):
	bg, fg, fg2 = (rgb(h) for h in s["frieze"])
	c = Canvas(512, 128, bg)
	c.rect(0, 0, 1, 0.1, fg2)
	c.rect(0, 0.9, 1, 1, fg2)
	c.fret(0.0, 0.14, 1.0, 0.86, 2, fg, bg)
	c.weather(5, 0.12)
	return c.save(path)


def flag_image(s, path):
	c = Canvas(256, 256, rgb(s["flag1"]))
	c.rect(0, 0, 0.16, 1, rgb(s["flag2"]))
	c.fret(0.16, 0.62, 1.0, 0.86, 3, rgb(s["flag2"]), rgb(s["flag1"]))
	c.weather(9, 0.12)
	return c.save(path)


# --- Meshes -----------------------------------------------------------------------

class Mesh:
	def __init__(self, name):
		self.name = name
		self.v, self.f, self.mi, self.uv = [], [], [], []
		self.mats = []

	def m(self, mat):
		if mat not in self.mats:
			self.mats.append(mat)
		return self.mats.index(mat)

	def face(self, pts, mat, uvs=None):
		i0 = len(self.v)
		self.v.extend(pts)
		self.f.append(tuple(range(i0, i0 + len(pts))))
		self.mi.append(self.m(mat))
		self.uv.append(uvs or [(p[0] * 0.25 + p[2] * 0.25, p[1] * 0.25) for p in pts])

	def quad(self, a, b, c, d, mat, uvs=None):
		self.face([a, b, c, d], mat, uvs)

	def box(self, lo, hi, mat, front=None, xf=None):
		x0, y0, z0 = lo
		x1, y1, z1 = hi
		P = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
		if xf:
			P = [xf(p) for p in P]
		full = [(0, 0), (1, 0), (1, 1), (0, 1)]
		for idx, which in (((0, 3, 2, 1), "back"), ((4, 5, 6, 7), "front_z"), ((0, 1, 5, 4), "bottom"),
						   ((3, 7, 6, 2), "top"), ((0, 4, 7, 3), "left"), ((1, 2, 6, 5), "right")):
			# "back" is the -z face: the face toward the bow
			if front and which == "back":
				self.face([P[i] for i in idx], front, [(1, 0), (1, 1), (0, 1), (0, 0)])
			else:
				self.face([P[i] for i in idx], mat)

	def cyl(self, a, b, r0, r1, mat, n=10, caps=True):
		a, b = np.array(a, float), np.array(b, float)
		ax = b - a
		ln = np.linalg.norm(ax)
		ax /= ln
		ref = np.array([0, 1, 0]) if abs(ax[1]) < 0.9 else np.array([1, 0, 0])
		u = np.cross(ax, ref)
		u /= np.linalg.norm(u)
		w = np.cross(ax, u)
		ring = lambda c, r: [tuple(c + (u * math.cos(k * 2 * math.pi / n) + w * math.sin(k * 2 * math.pi / n)) * r) for k in range(n)]
		ra, rb = ring(a, r0), ring(b, r1)
		for k in range(n):
			k2 = (k + 1) % n
			self.quad(ra[k], ra[k2], rb[k2], rb[k], mat)
		if caps:
			self.face(ra[::-1], mat)
			self.face(rb, mat)

	def disc_z(self, cx, cy, z, r, mat, depth=0.6, n=16):
		"""A round boss facing the bow (-z), standing depth proud of z."""
		self.cyl((cx, cy, z), (cx, cy, z - depth), r, r, mat, n)

	def build(self, mats, bevel=0.0, segments=2, warp=None, split=40.0):
		import bmesh
		me = bpy.data.meshes.new(self.name)
		me.from_pydata([bv(warp(p) if warp else p) for p in self.v], [], self.f)
		me.update()
		uvl = me.uv_layers.new(name="UV")
		k = 0
		for poly, uvs in zip(me.polygons, self.uv):
			for li, uv in zip(poly.loop_indices, uvs):
				uvl.data[li].uv = uv
		for name in self.mats:
			me.materials.append(mats[name])
		for poly, mi in zip(me.polygons, self.mi):
			poly.material_index = mi
		bm = bmesh.new()
		bm.from_mesh(me)
		bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.002)
		bm.to_mesh(me)
		bm.free()
		for poly in me.polygons:
			poly.use_smooth = True
		ob = bpy.data.objects.new(self.name, me)
		bpy.context.scene.collection.objects.link(ob)
		if bevel > 0.0:
			mod = ob.modifiers.new("bevel", "BEVEL")
			mod.width = bevel
			mod.segments = segments
			mod.limit_method = "ANGLE"
		if split > 0.0:
			mod = ob.modifiers.new("split", "EDGE_SPLIT")
			mod.split_angle = math.radians(split)
		return ob


def sb(M, s, xa, xb, y0, y1, z0, z1, mat):
	"""A box from x xa..xb on the side s (+1 or -1)."""
	if s > 0:
		M.box((xa, y0, z0), (xb, y1, z1), mat)
	else:
		M.box((-xb, y0, z0), (-xa, y1, z1), mat)


def hull(M, U):
	zs = list(np.linspace(STERN_Z, -40.0, 46)) + list(np.linspace(-40.8, stem_z(32.0), 46))
	grid = []
	for z in zs:
		r = rail(z)
		ys = ROWS + [17.0 + t * max(r - 17.0, 0.01) for t in UPPER[1:]]
		end = max(min(1.0, (z - 30.0) / 28.0), min(1.0, (-z - 30.0) / 42.0), 0.0) ** 2
		row = []
		for j, y in enumerate(ys):
			zz = max(z, stem_z(y))
			yy = y * (1.0 - 0.5 * end) if y < 0.0 else y     # the keel rises toward the ends
			yy += 0.16 * math.sin(z * 0.23 + j * 1.3) if 0.5 < y and j < len(ys) - 1 and abs(y - 2.6) > 0.1 and abs(y - 13.4) > 0.1 else 0.0
			row.append((half(y, zz), yy, zz))
		grid.append(row)
	band = []
	for y0, y1 in zip(ROWS, ROWS[1:]):
		mid = (y0 + y1) * 0.5
		band.append("bottom" if mid < 0.8 else "boot" if mid < 2.6 else "wale" if mid < 4.0 else "band" if mid < 12.0
					else "wale" if mid < 13.4 else "hull" if mid < 14.6 else "frieze" if mid < 16.4 else "wale")
	band += ["upper", "frieze", "upper", "rail"]
	for s in (1, -1):
		for i in range(len(zs) - 1):
			for j in range(len(grid[0]) - 1):
				a, b = grid[i][j], grid[i + 1][j]
				c, d = grid[i + 1][j + 1], grid[i][j + 1]
				if 2.5 < (a[1] + d[1]) * 0.5 < 13.5 and ROWS[0] <= a[1] and a[2] < -50.0 and max(q[0] for q in (a, b, c, d)) < 10.45:
					continue   # the exit cut through the prow
				P = [(s * p[0], p[1], p[2]) for p in (a, b, c, d)]
				if s < 0:
					P = P[::-1]
				mat = band[j]
				uvs = None
				if mat == "frieze":
					u0, u1 = -a[2] / 6.0, -b[2] / 6.0
					uvs = [(u0, 0), (u1, 0), (u1, 1), (u0, 1)]
					if s < 0:
						uvs = uvs[::-1]
				M.quad(*P, mat, uvs)
	M = U
	# the ends: the transom aft, a dark bulkhead behind the head
	for idx, z, mat in ((0, STERN_Z, "upper"),):
		col = grid[idx]
		pts = [(p[0], p[1], z) for p in col] + [(-p[0], p[1], z) for p in col[::-1]]
		M.face(pts if idx == 0 else pts[::-1], mat)
	# the waist's inner bulwark and the decks
	for name, top, z0, z1 in DECKS:
		zz = np.linspace(z0, z1, 6)
		w = min(half(top, z) for z in zz) - 0.4
		M.box((-w, top - 1.5 if name == "main" else 13.5, z0), (w, top, z1), "deck")
	# stern: the plug plate, galleries, windows, the sun disc
	M.box((-COR_W / 2 - 0.4, COR_FLOOR - 0.4, STERN_Z), (COR_W / 2 + 0.4, COR_TOP + 0.4, STERN_Z + 0.25), "plug")
	for k in range(7):
		x = -COR_W / 2 + 0.6 + k * 2.75
		M.box((x, COR_FLOOR, STERN_Z + 0.2), (x + 2.1, COR_TOP, STERN_Z + 0.45), "wood")
	M.box((-11.5, 15.0, STERN_Z - 1.0), (11.5, 16.0, STERN_Z + 3.0), "rail")
	M.box((-11.0, 16.0, STERN_Z), (11.0, 30.0, STERN_Z + 2.4), "upper")
	M.box((-11.5, 22.5, STERN_Z - 1.0), (11.5, 23.4, STERN_Z + 3.4), "rail")
	M.box((-11.8, 30.0, STERN_Z - 2.0), (11.8, 31.0, STERN_Z + 3.0), "rail")
	for row, y0 in enumerate((17.0, 24.6)):
		for k in range(7):
			x = -9.6 + k * 2.9
			M.box((x, y0, STERN_Z + 2.4), (x + 1.8, y0 + 3.8, STERN_Z + 2.7), "glass")
	M.box((-6.0, 31.0, STERN_Z - 1.0), (6.0, 36.0, STERN_Z + 2.6), "upper")   # the crown
	zq = STERN_Z + 2.65
	M.quad((5.0, 31.3, zq), (-5.0, 31.3, zq), (-5.0, 35.8, zq), (5.0, 35.8, zq), "sail_sun",
		   [(0.05, 0.12), (0.95, 0.12), (0.95, 0.78), (0.05, 0.78)])
	M.quad((10.5, 15.2, STERN_Z + 3.05), (-10.5, 15.2, STERN_Z + 3.05), (-10.5, 15.95, STERN_Z + 3.05), (10.5, 15.95, STERN_Z + 3.05), "frieze",
		   [(0, 0), (4, 0), (4, 1), (0, 1)])
	for s in (1, -1):   # quarter galleries
		sb(M, s, 11.0, 13.4, 16.5, 28.5, 46.0, 57.0, "upper")
		sb(M, s, 10.8, 13.8, 28.5, 29.5, 45.5, 57.5, "rail")
		sb(M, s, 10.8, 13.8, 15.5, 16.5, 45.5, 57.5, "rail")
		for k in range(3):
			z = 47.2 + k * 3.3
			sb(M, s, 13.4, 13.6, 19.0, 26.0, z, z + 2.2, "glass")
	for x in (-9.0, 0.0, 9.0):   # lanterns
		M.cyl((x, 31.0, STERN_Z + 1.5), (x, 34.0, STERN_Z + 1.5), 0.6, 0.9, "glass", 8)
		M.cyl((x, 34.0, STERN_Z + 1.5), (x, 35.2, STERN_Z + 1.5), 0.9, 0.2, "iron", 8)
	# rails along the decks' edges: posts and caps
	for z in np.arange(-36.0, 30.0, 3.0):
		for s in (1, -1):
			w = half(rail(z), z)
			M.box((s * w - 0.25, rail(z) - 0.2, z - 0.25), (s * w + 0.25, rail(z) + 0.8, z + 0.25), "rail")
	# guns and ports
	for side, s in (("L", -1), ("R", 1)):
		for z in HULL_GUNS:
			w = half(8.0, z)
			sb(M, s, w - 0.8, w + 0.3, 6.4, 9.6, z - 1.6, z + 1.6, "dark")
			sb(M, s, w - 0.2, w + 0.6, 9.6, 12.2, z - 1.9, z + 1.9, "wale")
			M.cyl((s * (w - 1.0), 8.0, z), (s * (w + 1.6), 8.0, z), 0.75, 0.6, "iron", 10)
			M.cyl((s * (w + 1.4), 8.0, z), (s * (w + 1.75), 8.0, z), 0.8, 0.8, "iron", 10)
		for z in SHUT_PORTS:
			w = half(8.0, z)
			sb(M, s, w - 0.6, w + 0.3, 6.6, 9.4, z - 1.5, z + 1.5, "wale")
		for z in DECK_GUNS:
			w = half(16.0, z) - 2.6
			M.box((s * w - 1.2, 15.0, z - 1.2), (s * w + 1.2, 16.6, z + 1.2), "wood")
			M.cyl((s * (w - 1.4), 17.4, z), (s * (w + 4.4), 17.7, z), 0.55, 0.45, "iron", 10)
			M.cyl((s * (w - 0.6), 16.6, z - 1.0), (s * (w - 0.6), 17.4, z - 1.0), 0.3, 0.3, "wood", 6)
			M.cyl((s * (w - 0.6), 16.6, z + 1.0), (s * (w - 0.6), 17.4, z + 1.0), 0.3, 0.3, "wood", 6)


def lean(p):
	"""The head leans out over the sea above its lip; the jaws stay square on the exit."""
	x, y, z = p
	return (x, y, z - 0.16 * max(y - 14.6, 0.0))


def taper(y0, y1, k, front=-62.0):
	"""Narrows a block toward its top and its front: a carved mass, not a crate."""
	def f(p):
		x, y, z = p
		t = (y - y0) / (y1 - y0)
		fz = max(0.0, min(1.0, (-57.0 - z) / (-57.0 - front)))
		return (x * (1.0 - k * t) * (1.0 - 0.08 * fz), y, z)
	return f


def bow(M, Mast, Sails):
	"""The bow without a head: a raked prow with the exit cut through it, a short tunnel
	lined in dark wood back to the plate, a timber surround, catheads, bowsprit and jib.
	Nothing enters the exit's rectangle (|x| < 9, 3 < y < 13) carried forward."""
	z0 = BOW_Z
	M.box((-COR_W / 2 - 0.4, COR_FLOOR - 0.4, z0 - 0.3), (COR_W / 2 + 0.4, COR_TOP + 0.4, z0), "plug")   # the bow's plate
	for k in range(7):
		x = -COR_W / 2 + 0.6 + k * 2.75
		M.box((x, COR_FLOOR, z0 - 0.55), (x + 2.1, COR_TOP, z0 - 0.3), "wood")
	zc = max(cross_z(y) for y in np.linspace(2.6, 13.4, 9))
	for s_ in (1, -1):   # the tunnel's walls, back to the plate
		sb(M, s_, 10.4, 11.2, 2.6, 13.4, zc, z0, "wale")
	for y, mat, up in ((2.6, "deck", True), (13.4, "wale", False)):   # its floor, the prow's lip over it
		zz = np.linspace(z0 + 0.5, stem_z(y), 18)
		ring = [(half(y, z), y, z) for z in zz]
		pts = ring + [(-p[0], p[1], p[2]) for p in ring[::-1]]
		M.face(pts[::-1] if up else pts, mat)
	for s_ in (1, -1):   # the surround: timbers round the cut
		side = [(s_ * 10.4, y, cross_z(y)) for y in np.linspace(2.6, 13.4, 7)]
		for p0, p1 in zip(side, side[1:]):
			M.cyl(p0, p1, 0.6, 0.6, "wood", 8)
		for y, yt in ((2.6, 2.0), (13.4, 14.0)):   # centred 0.6 m off the lips, clear of the exit
			edge = [(s_ * half(y, z), yt, z) for z in np.linspace(cross_z(y), stem_z(y), 9)]
			for p0, p1 in zip(edge, edge[1:]):
				M.cyl(p0, p1, 0.6, 0.6, "wood", 8)
	M.box((-1.6, 13.6, stem_z(14.0) - 0.6), (1.6, 16.6, stem_z(14.0) + 2.4), "stone")   # a stone boss at the stem's head
	ring = [(half(21.0, z) - 0.3, 21.0, z) for z in np.linspace(-38.0, stem_z(21.0) + 0.6, 16)]   # the forecastle's deck
	M.face([(-p[0], p[1], p[2]) for p in ring] + ring[::-1], "deck")
	hw = half(19.0, -52.0)
	for s_ in (1, -1):   # catheads
		M.cyl((s_ * (hw - 1.0), 19.0, -50.0), (s_ * (hw + 3.2), 19.4, -52.5), 0.7, 0.6, "wood", 8)
	Mast.cyl((0, 21.0, -50.0), SPRIT_TIP, 1.2, 0.5, "wood", 10)
	tack, head_, clew = (0.0, 37.0, -84.0), (0.0, 45.0, -42.0), (2.0, 28.0, -57.0)
	Sails.face([tuple(np.array(tack) + (0, -0.6, 0)), head_, clew], "sail_plain", [(1, 0), (0.5, 1), (0, 0)])


def head(M, D):
	"""The figurehead: a carved face whose open jaws frame the corridor's exit.

	M holds the big masses (beveled round), D the carving on them."""
	FZ = -62.0                     # the face's front
	# jaws: the mouth is 21 x 13.2 m, the corridor 18 x 10 inside it
	M.box((-12.6, -3.0, -69.5), (12.6, 1.4, -57.0), "stone", xf=taper(-3.0, 1.4, -0.06, -69.5))   # lower jaw, its chin in the sea
	M.box((-13.4, 14.6, -67.5), (13.4, 17.6, -57.0), "stone", xf=taper(14.6, 17.6, -0.04, -67.5))  # upper jaw, the snout's lip
	for s in (1, -1):
		sb(M, s, 10.4, 14.6, -2.0, 17.6, -64.0, -57.0, "stone")   # cheeks
		sb(D, s, 10.4, 11.0, 1.4, 14.6, -64.0, -57.5, "pig1")     # gums
		# fangs, outside the exit's rectangle (x 9..10.4)
		D.cyl((s * 9.95, 15.0, -66.3), (s * 10.1, 9.8, -66.5), 0.7, 0.15, "bone", 6)
		D.cyl((s * 9.95, 1.0, -67.9), (s * 10.05, 6.0, -67.7), 0.7, 0.15, "bone", 6)
	rng = np.random.default_rng(3)
	for k in range(8):                                                     # teeth, uneven, worn
		x = -8.4 + k * 2.4 + rng.uniform(-0.3, 0.3)
		D.cyl((x, 15.0, -65.9), (x + rng.uniform(-0.3, 0.3), 13.35 + rng.uniform(0, 0.4), -65.9), rng.uniform(0.7, 0.95), rng.uniform(0.25, 0.45), "bone", 5)
		D.cyl((x, 1.0, -68.1), (x + rng.uniform(-0.3, 0.3), 2.55 - rng.uniform(0, 0.5), -68.1), rng.uniform(0.7, 0.95), rng.uniform(0.25, 0.45), "bone", 5)
	D.box((-10.4, 1.4, -57.6), (10.4, 14.6, -57.2), "dark")           # the throat, over the bow plate
	# the face above the lip
	M.box((-14.2, 17.6, FZ), (14.2, 34.0, -57.0), "stone", xf=taper(17.6, 34.0, 0.1))
	M.box((-4.0, 17.6, FZ - 3.8), (4.0, 22.0, FZ + 0.5), "stone", xf=taper(17.6, 22.0, 0.25, FZ - 3.8))  # the nose, broad and flat
	M.box((-3.0, 21.0, FZ - 2.6), (3.0, 28.0, FZ + 0.5), "stone", xf=taper(21.0, 28.0, 0.3, FZ - 2.6))
	for s in (1, -1):
		D.disc_z(s * 1.8, 19.6, FZ - 3.8, 0.9, "dark", 0.2, 10)        # nostrils
		ex = s * 7.6
		M.disc_z(ex, 26.0, FZ, 4.0, "stone", 0.8, 20)                 # the socket's carved rim
		D.disc_z(ex, 25.6, FZ - 0.8, 2.8, "bone", 0.3, 20)
		M.box((ex - 4.2, 26.2, FZ - 1.9), (ex + 4.2, 29.6, FZ - 0.4), "stone")   # a heavy lid over the eye
		D.box((ex - 1.6, 24.4, FZ - 1.25), (ex + 1.6, 25.6, FZ - 1.0), "dark")   # the slit under it
		sb(D, s, 9.0, 13.2, 18.6, 20.8, FZ - 1.2, FZ + 0.5, "pig1")     # cheek bars
		M.disc_z(s * 10.6, 20.0, FZ, 3.6, "stone", 1.4, 14)             # swollen cheeks
		# ear spools and their pendants
		M.cyl((s * 14.0, 25.0, -60.0), (s * 15.6, 25.0, -60.0), 4.4, 4.4, "stone", 20)
		D.cyl((s * 15.6, 25.0, -60.0), (s * 16.1, 25.0, -60.0), 2.8, 2.8, "pig2", 16)
		D.cyl((s * 16.1, 25.0, -60.0), (s * 16.4, 25.0, -60.0), 1.2, 1.2, "dark", 12)
		sb(M, s, 14.4, 15.8, 11.0, 20.6, -61.4, -58.6, "pig2")
		sb(D, s, 14.2, 16.0, 9.0, 11.0, -61.8, -58.2, "bone")
	M.box((-14.8, 30.4, FZ - 2.4), (14.8, 34.0, FZ + 0.5), "stone")
	M.box((-13.0, 29.0, FZ - 3.4), (13.0, 31.4, FZ - 1.8), "stone")    # the brow, heavy over the eyes  # the brow, carved with frets
	# the headdress: a band, then a fan of feather slabs
	M.box((-15.4, 34.0, -63.0), (15.4, 37.6, -56.0), "stone")
	for k in range(7):
		x = -12.0 + k * 4.0
		M.disc_z(x, 35.6, -63.0, 1.2, "stone", 0.9, 8)
	n = 11
	for k in range(n):
		a = math.radians(-75 + 150 * k / (n - 1))
		ln = 19.0 if k % 2 == 0 else 15.0
		root = np.array([0.0, 36.0, -59.5])
		d = np.array([math.sin(a), math.cos(a), 0.12])
		d /= np.linalg.norm(d)
		tip = root + d * ln
		mid = root + d * (ln * 0.72)
		side = np.cross(d, [0, 0, 1.0])
		side /= np.linalg.norm(side)
		wd = 2.3
		col = "pig2" if k % 2 == 0 else "pig1"
		p0, p1 = root + d * 1.0, tip
		q = [tuple(p0 - side * wd), tuple(p0 + side * wd), tuple(p1 + side * wd * 0.8), tuple(p1 - side * wd * 0.8)]
		back = [tuple(np.array(p) + np.array([0, 0, 1.1])) for p in q]
		M.quad(*q, "stone")
		M.quad(*back[::-1], "stone")
		for i in range(4):
			j = (i + 1) % 4
			M.quad(q[i], back[i], back[j], q[j], "stone")


def sail_sheet(M, cx, cz, yard, drop, wt, wf, mat, brace, belly=0.2, nx=14, ny=10):
	grid = []
	for j in range(ny + 1):
		v = j / ny
		row = []
		for i in range(nx + 1):
			u = i / nx * 2.0 - 1.0
			hw = (wt + (wf - wt) * v) * 0.5
			x = u * hw
			y = yard - v * drop
			bz = -belly * drop * (1.0 - u * u * 0.85) * math.sin(math.pi * (0.12 + 0.8 * v))
			ca, sa = math.cos(brace), math.sin(brace)
			row.append((cx + x * ca - bz * sa, y, cz + x * sa + bz * ca))
		grid.append(row)
	for j in range(ny):
		for i in range(nx):
			uvs = [(i / nx, 1 - j / ny), ((i + 1) / nx, 1 - j / ny), ((i + 1) / nx, 1 - (j + 1) / ny), (i / nx, 1 - (j + 1) / ny)]
			M.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i], mat, uvs)


def rig(Mast, Sails, Ropes, Flags):
	tops = []
	for mi, (z, foot, top, sails) in enumerate(MASTS):
		Mast.cyl((0, foot - 2, z), (0, top * 0.55, z), 1.5, 1.2, "wood", 12)
		Mast.cyl((0, top * 0.53, z), (0, top * 0.82, z), 1.0, 0.8, "wood", 10)
		Mast.cyl((0, top * 0.8, z), (0, top, z), 0.65, 0.4, "wood", 8)
		for frac in (0.53, 0.8):
			y = top * frac
			Mast.cyl((0, y - 0.6, z), (0, y + 0.6, z), 4.6, 4.6, "wood", 16)
			Mast.cyl((0, y + 0.6, z), (0, y + 1.9, z), 4.6, 4.6, "rail", 16, caps=False)
		Mast.cyl((0, top, z), (0, top + 1.0, z), 0.9, 0.9, "rail", 10)
		brace = BRACE * (1.0 if mi != 2 else 0.8)
		for yard, drop, wt, wf, glyph in sails:
			hw = wt * 0.5 + 1.5
			ca, sa = math.cos(brace), math.sin(brace)
			Mast.cyl((-hw * ca, yard + 0.3, z - hw * sa), (hw * ca, yard + 0.3, z + hw * sa), 0.45, 0.45, "wood", 8)
			sail_sheet(Sails, 0.0, z - 1.2, yard, drop, wt, wf, "sail_" + glyph, brace)
		tops.append((z, top))
		# shrouds: lines from the tops to the rail
		for s in (1, -1):
			for k in range(5):
				zz = z - 3.0 + k * 2.2
				Ropes.cyl((s * 4.4, top * 0.53, z - 1.6 + k * 0.8), (s * (half(rail(zz), zz) + 0.3), rail(zz) + 0.4, zz), 0.13, 0.13, "rope", 4, False)
				Ropes.cyl((s * 4.4, top * 0.8, z - 1.6 + k * 0.8), (s * 4.4, top * 0.53 + 2.0, z - 1.6 + k * 0.8), 0.1, 0.1, "rope", 4, False)
		# a pennant streaming aft from the truck
		ln = 30.0 if mi == 1 else 22.0
		pts = []
		for k in range(11):
			t = k / 10
			pts.append((math.sin(t * 6.0) * 1.2 * t, top + 0.6 - t * 2.0, z + t * ln))
		wd = 2.6 if mi == 1 else 2.0
		for k in range(10):
			a, b = pts[k], pts[k + 1]
			w0, w1 = wd * (1 - k / 10.0 * 0.85), wd * (1 - (k + 1) / 10.0 * 0.85)
			col = "flag1" if (k // 2) % 2 == 0 else "flag2"
			Flags.quad((a[0], a[1], a[2]), (b[0], b[1], b[2]), (b[0], b[1] - w1, b[2]), (a[0], a[1] - w0, a[2]), col)
	(fz, ft), (mz, mt), (az, at) = tops
	stay = (0, 37.0, -59.0) if HEAD else SPRIT_TIP                                       # to the crown, or the bowsprit
	Ropes.cyl((0, ft * 0.98, fz), stay, 0.22, 0.22, "rope", 5, False)
	Ropes.cyl((0, ft * 0.6, fz), (0, 30.0, -57.0) if HEAD else (0, 33.0, BOW_Z - 16.0), 0.22, 0.22, "rope", 5, False)
	Ropes.cyl((0, mt * 0.98, mz), (0, ft * 0.82, fz), 0.2, 0.2, "rope", 5, False)
	Ropes.cyl((0, mt * 0.55, mz), (0, ft * 0.5, fz), 0.2, 0.2, "rope", 5, False)
	Ropes.cyl((0, at * 0.98, az), (0, mt * 0.8, mz), 0.2, 0.2, "rope", 5, False)
	for s in (1, -1):
		for (z, t) in tops:
			zz = z + 14.0
			Ropes.cyl((0, t * 0.97, z), (s * (half(rail(zz), zz) + 0.2), rail(zz), zz), 0.16, 0.16, "rope", 4, False)
	# the ensign over the stern
	Mast.cyl((0, 31.0, STERN_Z + 1.0), (0, 46.0, STERN_Z + 3.0), 0.35, 0.25, "wood", 6)
	for k in range(6):
		t0, t1 = k / 6, (k + 1) / 6
		z0, z1 = STERN_Z + 3.0 + t0 * 13.0, STERN_Z + 3.0 + t1 * 13.0
		x0, x1 = math.sin(t0 * 5.0) * 0.8, math.sin(t1 * 5.0) * 0.8
		Flags.quad((x0, 45.6 - t0 * 0.8, z0), (x1, 45.6 - t1 * 0.8, z1), (x1, 36.6 - t1 * 0.8, z1), (x0, 36.6 - t0 * 0.8, z0),
				   "ensign", [(t0, 1), (t1, 1), (t1, 0), (t0, 0)])


def noise3(P, scale, seed):
	"""Value noise in 3D at the points P (n x 3), cells of `scale` m."""
	q = P / scale
	i = np.floor(q).astype(np.int64)
	f = q - i
	f = f * f * (3 - 2 * f)
	def h(ix, iy, iz):
		n = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
		n &= 0xFFFFFFFF
		n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
		return (n & 0xFFFF) / 65535.0
	out = 0.0
	for dx in (0, 1):
		for dy in (0, 1):
			for dz in (0, 1):
				w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
				out = out + w * h(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz)
	return out


def crude(ob, voxel=0.42, keep=0.3):
	"""One carved mass from the blocks: remeshed into one skin, then swollen, gouged,
	chipped and cracked by noise, its value in vertex colour."""
	r = ob.modifiers.new("remesh", "REMESH")
	r.mode = "VOXEL"
	r.voxel_size = voxel
	dg = bpy.context.evaluated_depsgraph_get()
	me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
	ob.modifiers.clear()
	old = ob.data
	ob.data = me
	me.materials.clear()
	me.materials.append(old.materials[0])
	n = len(me.vertices)
	P = np.empty(n * 3, np.float32)
	N = np.empty(n * 3, np.float32)
	me.vertices.foreach_get("co", P)
	me.vertices.foreach_get("normal", N)
	P, N = P.reshape(-1, 3).astype(np.float64), N.reshape(-1, 3)
	d = 1.3 * (noise3(P, 9.0, 1) - 0.5) + 0.8 * (noise3(P, 3.2, 2) - 0.5) + 0.3 * (noise3(P, 1.1, 3) - 0.5)
	chip = noise3(P, 2.2, 4) > 0.74
	d = np.where(chip, np.minimum(d, -0.15) - 0.35, d)
	crack = np.abs(noise3(P, 7.0, 5) - 0.5) < 0.016
	d = np.where(crack, d - 0.45, d)
	P = P + N * d[:, None]
	me.vertices.foreach_set("co", P.astype(np.float32).ravel())
	v = 0.88 + 0.36 * (noise3(P, 4.0, 6) - 0.5) + 0.12 * (noise3(P, 0.9, 7) - 0.5)
	v *= np.clip(1.0 + 0.3 * d, 0.6, 1.12)
	v = np.where(crack, v * 0.45, np.where(chip, v * 0.82, v))
	col = np.ones((n, 4), np.float32)
	col[:, :3] = np.clip(v, 0, 1.2)[:, None]
	attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
	attr.data.foreach_set("color", col.ravel())
	me.color_attributes.active_color = attr
	for poly in me.polygons:
		poly.use_smooth = True
	me.update()
	dec = ob.modifiers.new("decimate", "DECIMATE")
	dec.ratio = keep


def material(name, col=None, img=None, emit=0.0, tex=None, chip=None):
	if tex is not None and KIND.get(name):
		c = Canvas(256, 256, (0, 0, 0))
		c.a = wear(KIND[name], col, chip, sum(map(ord, name)))
		img = c.save(tex / ("wear_%s.png" % name))
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Roughness"].default_value = 0.85
	if img is not None:
		tex = m.node_tree.nodes.new("ShaderNodeTexImage")
		tex.image = img
		m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	else:
		bsdf.inputs["Base Color"].default_value = (*[c ** 2.2 for c in col], 1.0)
	if emit > 0.0:
		bsdf.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in col], 1.0)
		bsdf.inputs["Emission Strength"].default_value = emit
	return m


def build(scheme, out):
	s = SCHEMES[scheme]
	bpy.ops.wm.read_factory_settings(use_empty=True)
	tex = out / scheme
	tex.mkdir(parents=True, exist_ok=True)
	mats = {}
	for k in ("hull", "upper", "band", "wale", "boot", "bottom", "rail", "deck", "wood", "iron", "plug", "stone", "pig1",
			  "pig2", "bone", "dark", "flag1", "flag2"):
		mats[k] = material(k, rgb(s[k]), tex=tex, chip=rgb(s["wood"]))
	mats["glass"] = material("glass", rgb(s["glass"]))
	mats["rope"] = material("rope", rgb("2b241d"))
	mats["frieze"] = material("frieze", img=frieze_image(s, tex / "frieze.png"))
	mats["sail_plain"] = material("sail_plain", img=sail_image(s, "plain", tex / "sail_plain.png"))
	for _, _, _, sails in MASTS:
		for yard, drop, wt, wf, g in sails:
			if g != "plain":
				art = FORE if g == "fore" else g
				mats["sail_" + g] = material("sail_" + g, img=sail_image(s, art, tex / ("sail_%s_%s.png" % (g, art)), (wt + wf) * 0.5 / drop))
	mats["ensign"] = material("ensign", img=flag_image(s, tex / "ensign.png"))
	H, U, Hd, Hc, Ma, Sa, Ro, Fl = (Mesh(n) for n in ("Hull", "Upperworks", "Figurehead", "Carving", "Masts", "Sails", "Rigging", "Flags"))
	hull(H, U)
	if HEAD:
		head(Hd, Hc)
	else:
		bow(U, Ma, Sa)
	rig(Ma, Sa, Ro, Fl)
	H.build(mats, split=50.0, warp=rake)
	u = U.build(mats, bevel=0.35, warp=rake)
	tex2 = bpy.data.textures.new("warp", "CLOUDS")
	tex2.noise_scale = 3.0
	dm2 = u.modifiers.new("warp", "DISPLACE")
	dm2.texture = tex2
	dm2.texture_coords = "GLOBAL"
	dm2.strength = 0.14
	if HEAD:
		figurehead(mats, Hd, Hc)
	Ma.build(mats)
	Sa.build(mats, split=0.0)
	Ro.build(mats)
	Fl.build(mats, split=0.0)
	# empties the game names, for the build round to aim at
	for side, s_ in (("L", -1), ("R", 1)):
		for i, z in enumerate(HULL_GUNS):
			e = bpy.data.objects.new("Gun_%s_%02d" % (side, i + 1), None)
			e.location = bv((s_ * (half(8.0, z) + 1.75), 8.0, z))
			bpy.context.scene.collection.objects.link(e)
		for i, z in enumerate(DECK_GUNS):
			e = bpy.data.objects.new("DeckGun_%s_%02d" % (side, i + 1), None)
			e.location = bv((s_ * (half(16.0, z) + 1.8), 17.6, z))
			bpy.context.scene.collection.objects.link(e)
	path = out / ("ship_%s%s.glb" % (scheme, "" if FORE == "spiral" else "_" + FORE))
	bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=False, export_apply=True,
							  export_yup=True, export_materials="EXPORT", export_normals=True, export_vertex_color="ACTIVE", export_animations=False,
							  export_cameras=False, export_lights=False, export_image_format="AUTO")
	tris = sum(sum(len(p.vertices) - 2 for p in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.polygons)
			   for o in bpy.context.scene.objects if o.type == "MESH")
	print("wrote %s (%d triangles)" % (path, tris))



def figurehead(mats, Hd, Hc):
	crude(Hd.build(mats, warp=lean, split=0.0))
	hc = Hc.build(mats, bevel=0.4, segments=3, warp=lean, split=0.0)
	tex = bpy.data.textures.new("rough", "CLOUDS")
	tex.noise_scale = 1.4
	dm = hc.modifiers.new("rough", "DISPLACE")
	dm.texture = tex
	dm.texture_coords = "LOCAL"
	dm.strength = 0.25


def main():
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	out = ROOT / "scratch/ship_concept"
	schemes = list(SCHEMES)
	for i, a in enumerate(argv):
		if a == "--out":
			out = ROOT / argv[i + 1]
		if a == "--schemes":
			schemes = argv[i + 1].split(",")
	out.mkdir(parents=True, exist_ok=True)
	for sc in schemes:
		build(sc, out)


main()
