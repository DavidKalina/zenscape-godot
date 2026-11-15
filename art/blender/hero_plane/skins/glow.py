"""The glow batch's decals (scripts/endless/skins/glow.gd): five skins that
light after dark. Each decal is drawn in its lit colours over a dark livery.
Run: python tools/blender.py run art/blender/hero_plane/skins/glow.py"""
import math

import numpy as np
from hero_plane.hero_plane_decal import COWL_L, FRONT, Decal

OUT = "assets/models/hero_plane/skins/glow/"


def hash2(i, j, seed):
	h = np.sin(i * 127.1 + j * 311.7 + seed * 74.7) * 43758.5453
	g = np.sin(i * 269.5 + j * 183.3 + seed * 41.3) * 24634.6345
	return h - np.floor(h), g - np.floor(g)


def cells(a, b, cell, seed):
	"""Nearest and second nearest jittered grid point distances, and the nearest's cell ids."""
	ia, ib = np.floor(a / cell), np.floor(b / cell)
	d1 = np.full(a.shape, 9.0, np.float32)
	d2 = d1.copy()
	for da in (-1, 0, 1):
		for db in (-1, 0, 1):
			ja, jb = ia + da, ib + db
			ra, rb = hash2(ja, jb, seed)
			d = np.hypot(a - (ja + 0.15 + 0.7 * ra) * cell, b - (jb + 0.15 + 0.7 * rb) * cell)
			new1 = d < d1
			d2 = np.where(new1, d1, np.minimum(d2, d))
			d1 = np.where(new1, d, d1)
	return d1, d2


def stars(cell, size, seed, keep, soft=0.0012):
	"""Dots scattered one to a cell where hash < keep; a few big."""
	def fn(a, b, side):
		ia, ib = np.floor(a / cell), np.floor(b / cell)
		out = np.zeros(a.shape, np.float32)
		for da in (-1, 0, 1):
			for db in (-1, 0, 1):
				ja, jb = ia + da, ib + db
				ra, rb = hash2(ja, jb, seed)
				rs, rk = hash2(ja, jb, seed + 9)
				on = (rk < keep).astype(np.float32)
				r = size * (0.5 + 1.1 * rs * rs)
				d = np.hypot(a - (ja + 0.1 + 0.8 * ra) * cell, b - (jb + 0.1 + 0.8 * rb) * cell)
				out = np.maximum(out, on * np.clip((r + soft - d) / (2 * soft), 0, 1))
		return out
	return fn


def sparkles(cell, size, seed, keep):
	"""A few four-point stars: a dot with a cross."""
	def fn(a, b, side):
		ia, ib = np.floor(a / cell), np.floor(b / cell)
		out = np.zeros(a.shape, np.float32)
		for da in (-1, 0, 1):
			for db in (-1, 0, 1):
				ja, jb = ia + da, ib + db
				ra, rb = hash2(ja, jb, seed)
				rs, rk = hash2(ja, jb, seed + 9)
				on = (rk < keep).astype(np.float32)
				x = np.abs(a - (ja + 0.1 + 0.8 * ra) * cell)
				y = np.abs(b - (jb + 0.1 + 0.8 * rb) * cell)
				r = size * (0.8 + 0.5 * rs)
				arm = np.maximum(0, 1 - np.maximum(x, y) / r) * (np.minimum(x, y) < 0.006).astype(np.float32)
				core = np.clip(1 - np.hypot(x, y) / (r * 0.35), 0, 1)
				out = np.maximum(out, on * np.maximum(arm, core))
		return out
	return fn


def filament():
	d = Decal()
	P, W = "e0349f", "ffc4e8"
	# Body: a long cheat line, a fine one under it, and the keel line.
	d.stripe("body", P, z=(-0.47, 0.70), s=(0.105, 0.130))
	d.stripe("body", W, z=(-0.47, 0.70), s=(0.113, 0.122))
	d.stripe("body", P, z=(-0.30, 0.66), s=(0.165, 0.180))
	d.stripe("body", P, z=(-0.47, 0.70), s=(0.0, 0.016))  # the spine
	d.band("body", P, (-0.34, -0.32))
	d.band("body", P, (0.02, 0.036))
	# Cowl: a ring of light at the lip and the skirt.
	d.band("cowl", P, (FRONT + 0.012, FRONT + 0.03))
	d.band("cowl", P, (COWL_L - 0.03, COWL_L - 0.014))
	# Wings: the edges, a mid line, the tip frame.
	for r in ("wings_top", "wings_under"):
		d.rect(r, P, (0.0, 0.7), (0.0, 0.02))                  # leading edge
		d.rect(r, P, (0.0, 0.7), (0.10, 0.116))                # a chord line
		d.rect(r, P, (0.0, 0.7), (0.272, 0.292))                # trailing edge
		d.band(r, P, (0.5, 0.52))
		d.band(r, W, (0.53, 0.534))
		d.band(r, P, (0.08, 0.1))
	d.rect("tail", P, (0.0, 0.26), (0.0, 0.01))
	d.rect("tail", P, (0.0, 0.26), (0.125, 0.135))
	d.rect("tail", P, (0.0, 0.01), (0.0, 0.135))
	d.rect("tail", P, (0.25, 0.26), (0.0, 0.135))
	# Fin: an outline and the rudder's hinge.
	d.band("fin", P, (0.682, 0.69))
	d.rect("fin", P, (0.47, 0.76), (0.05, 0.058))
	d.rect("fin", P, (0.47, 0.76), (0.285, 0.298))
	d.save(OUT + "filament_decal.png")


def vesper():
	d = Decal()
	G, W = "ffe7a6", "fff6e0"
	for r, cell, sz in (("body", 0.07, 0.012), ("wings_top", 0.055, 0.013), ("wings_under", 0.07, 0.011), ("tail", 0.04, 0.014), ("cowl", 0.06, 0.011)):
		d.mask(r, G, stars(cell, sz, 3, 0.55))
	d.mask("body", W, sparkles(0.17, 0.05, 11, 0.9))
	d.mask("wings_top", W, sparkles(0.13, 0.06, 5, 0.9))
	d.mask("tail", W, sparkles(0.09, 0.05, 6, 0.9))
	d.mask("fin", G, stars(0.05, 0.012, 2, 0.7))
	d.mask("fin", W, sparkles(0.15, 0.04, 8, 0.7))
	# The milky way: a dense band of small stars over the shoulder and across the top wings and tail.
	def milky(a, b, side):
		z, s = a, np.abs(b)
		centre = 0.09 + 0.05 * np.sin(z * 5.0)
		on = (np.abs(s - centre) < 0.05).astype(np.float32)
		return on * stars(0.026, 0.007, 21, 0.7)(a, b, side)
	d.mask("body", "9fb4ff", milky)
	def band(a, b, side):
		c = 0.15 + 0.04 * np.sin(a * 9.0)
		on = (np.abs(b - c) < 0.05).astype(np.float32)
		return on * stars(0.03, 0.007, 33, 0.6)(a, b, side)
	d.mask("wings_top", "9fb4ff", band)
	d.mask("tail", "9fb4ff", lambda a, b, side: ((np.abs(b - 0.07) < 0.03).astype(np.float32)) * stars(0.022, 0.007, 34, 0.75)(a, b, side))
	d.save(OUT + "vesper_decal.png")


def cinder():
	d = Decal()
	def cracks(cell, seed, width):
		def fn(a, b, side):
			d1, d2 = cells(a, b, cell, seed)
			e = d2 - d1
			return np.clip(1 - e / width, 0, 1) ** 1.5
		return fn
	for r, cell, w in (("body", 0.17, 0.03), ("wings", 0.16, 0.028), ("cowl", 0.12, 0.022), ("tail", 0.1, 0.02)):
		d.mask(r, "c8420f", cracks(cell, 4, w), mirror=True)
		d.mask(r, "ff8a2a", cracks(cell, 4, w * 0.35), mirror=True)
	d.mask("fin", "c8420f", cracks(0.1, 6, 0.02))
	d.mask("fin", "ff8a2a", cracks(0.1, 6, 0.007))
	d.save(OUT + "cinder_decal.png")


def borealis():
	d = Decal()
	GR, VI, TE = "28e6a4", "9a6bff", "5cf0d0"
	def ribbon(centre, amp, k, ph, width):
		def fn(a, b, side):
			c = centre + amp * np.sin(a * k + ph)
			t = np.clip(1 - np.abs(np.abs(b) - c) / width, 0, 1)
			return t ** 1.2 * (0.7 + 0.3 * np.sin(a * 17.0 + ph))
		return fn
	d.mask("body", GR, ribbon(0.04, 0.03, 5.0, 0.0, 0.07))     # the back, seen from the chase camera
	d.mask("body", VI, ribbon(0.17, 0.05, 4.0, 1.5, 0.07))
	d.mask("body", TE, ribbon(0.30, 0.04, 6.0, 3.0, 0.055))
	# Top wings: broad ribbons running span-wise (b = chord position, a = span).
	d.mask("wings_top", GR, ribbon(0.07, 0.03, 9.0, 0.0, 0.065))
	d.mask("wings_top", VI, ribbon(0.18, 0.035, 7.0, 2.0, 0.06))
	d.mask("wings_top", TE, ribbon(0.27, 0.02, 11.0, 4.0, 0.035))
	d.mask("wings_under", GR, ribbon(0.10, 0.03, 9.0, 0.0, 0.05))
	d.mask("tail", GR, ribbon(0.04, 0.015, 14.0, 0.5, 0.045))
	d.mask("tail", VI, ribbon(0.10, 0.015, 12.0, 2.5, 0.04))
	d.band("cowl", GR, (FRONT + 0.01, FRONT + 0.04))
	d.mask("fin", GR, lambda a, b, side: np.clip(1 - np.abs(b - (0.12 + 0.03 * np.sin(a * 22))) / 0.05, 0, 1) ** 1.2)
	d.mask("fin", VI, lambda a, b, side: np.clip(1 - np.abs(b - (0.22 + 0.03 * np.sin(a * 18 + 2))) / 0.04, 0, 1) ** 1.2)
	d.save(OUT + "borealis_decal.png")


def abyss():
	d = Decal()
	C, W = "28c8ff", "b8f4ff"
	for z in np.arange(-0.40, 0.66, 0.062):
		d.disc("body", C, (z, 0.17), 0.02)
		d.disc("body", W, (z, 0.17), 0.009)
	for z in np.arange(-0.38, 0.62, 0.05):
		d.disc("body", C, (z, 0.31), 0.014)
	for z in np.arange(-0.34, 0.5, 0.14):
		d.disc("body", C, (z, 0.07), 0.014)
	d.stripe("body", C, z=(-0.46, 0.7), s=(0.116, 0.128))
	d.stripe("body", C, z=(-0.46, 0.7), s=(0.0, 0.026))     # a lit spine along the back
	# The top wings: rows of large lights along the span, three chord lines, a tip light.
	for c in (0.05, 0.13, 0.21, 0.28):
		for x in np.arange(0.05, 0.66, 0.065):
			d.disc("wings_top", C, (x, c), 0.024)
			d.disc("wings_top", W, (x, c), 0.01)
	for x in np.arange(0.06, 0.66, 0.07):
		d.disc("wings_under", C, (x, 0.13), 0.016)
	d.disc("wings", W, (0.66, 0.1), 0.026)
	d.rect("wings_top", C, (0.0, 0.7), (0.0, 0.016))
	for x in np.arange(0.03, 0.25, 0.045):
		for c in (0.035, 0.1):
			d.disc("tail", C, (x, c), 0.019)
			d.disc("tail", W, (x, c), 0.008)
	d.rect("tail", C, (0.0, 0.26), (0.0, 0.014))
	for z in np.arange(0.5, 0.74, 0.04):
		d.disc("fin", C, (z, 0.12), 0.017)
		d.disc("fin", C, (z, 0.22), 0.017)
	d.stripe("fin", C, z=(0.47, 0.76), s=(0.05, 0.065))
	for s_ in np.arange(0.06, 0.5, 0.11):
		d.disc("cowl", C, (s_, FRONT + 0.03), 0.015)
	d.save(OUT + "abyss_decal.png")


import sys
_want = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for _n, _f in (("filament", filament), ("vesper", vesper), ("cinder", cinder), ("borealis", borealis), ("abyss", abyss)):
	if not _want or _n in _want:
		_f()
