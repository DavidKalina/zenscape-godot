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
	for r, cell in (("body", 0.075), ("wings", 0.07), ("tail", 0.05), ("cowl", 0.06)):
		d.mask(r, G, stars(cell, 0.0115, 3, 0.6))
	d.mask("body", W, sparkles(0.17, 0.05, 11, 0.9))
	d.mask("wings", W, sparkles(0.2, 0.045, 5, 0.8))
	d.mask("fin", G, stars(0.05, 0.01, 2, 0.6))
	d.mask("fin", W, sparkles(0.2, 0.035, 8, 0.5))
	# A faint arc of the milky way over the shoulder: dense small dots in a band.
	def milky(a, b, side):
		z, s = a, np.abs(b)
		centre = 0.09 + 0.05 * np.sin(z * 5.0)
		on = (np.abs(s - centre) < 0.04).astype(np.float32)
		return on * stars(0.026, 0.006, 21, 0.6)(a, b, side)
	d.mask("body", "9fb4ff", milky)
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
		d.mask(r, "ff5a14", cracks(cell, 4, w), mirror=True)
		d.mask(r, "ffb040", cracks(cell, 4, w * 0.35), mirror=True)
	d.mask("fin", "ff5a14", cracks(0.1, 6, 0.02))
	d.mask("fin", "ffb040", cracks(0.1, 6, 0.007))
	d.save(OUT + "cinder_decal.png")


def borealis():
	d = Decal()
	def ribbon(centre, amp, k, ph, width, seed_vary=0.0):
		def fn(a, b, side):
			s = np.abs(b)
			c = centre + amp * np.sin(a * k + ph)
			t = np.clip(1 - np.abs(s - c) / width, 0, 1)
			return t * t * (0.6 + 0.4 * np.sin(a * 17.0 + ph))
		return fn
	d.mask("body", "28e6a4", ribbon(0.10, 0.04, 5.0, 0.0, 0.075))
	d.mask("body", "9a6bff", ribbon(0.20, 0.05, 4.0, 1.5, 0.07))
	d.mask("body", "7affc8", ribbon(0.31, 0.04, 6.0, 3.0, 0.055))
	def wing(c0, col, ph):
		def fn(a, b, side):
			cc = c0 + 0.03 * np.sin(a * 11.0 + ph)
			return np.clip(1 - np.abs(b - cc) / 0.04, 0, 1) ** 1.2
		return fn
	d.mask("wings", "28e6a4", wing(0.10, 0, 0.0))
	d.mask("wings", "9a6bff", wing(0.21, 0, 2.0))
	d.mask("tail", "28e6a4", wing(0.05, 0, 0.5))
	d.band("cowl", "28e6a4", (FRONT + 0.01, FRONT + 0.04))
	def fin(a, b, side):
		return np.clip(1 - np.abs(b - (0.17 + 0.03 * np.sin(a * 22))) / 0.04, 0, 1) ** 1.2
	d.mask("fin", "28e6a4", fin)
	d.save(OUT + "borealis_decal.png")


def abyss():
	d = Decal()
	C, W = "28c8ff", "b8f4ff"
	# Rows of photophores: a lateral row, a belly row, a few above.
	for z in np.arange(-0.40, 0.66, 0.062):
		d.disc("body", C, (z, 0.17), 0.02)
		d.disc("body", W, (z, 0.17), 0.009)
	for z in np.arange(-0.38, 0.62, 0.05):
		d.disc("body", C, (z, 0.31), 0.014)
	for z in np.arange(-0.34, 0.5, 0.14):
		d.disc("body", C, (z, 0.07), 0.014)
	d.stripe("body", C, z=(-0.46, 0.7), s=(0.116, 0.128))   # a faint lateral line
	for x in np.arange(0.06, 0.66, 0.07):
		for c in (0.06, 0.2):
			d.disc("wings_top", C, (x, c), 0.018)
		d.disc("wings_under", C, (x, 0.13), 0.016)
	d.disc("wings", W, (0.66, 0.1), 0.024)
	for x in np.arange(0.04, 0.25, 0.05):
		d.disc("tail", C, (x, 0.07), 0.015)
	for z in np.arange(0.5, 0.74, 0.045):
		d.disc("fin", C, (z, 0.16), 0.015)
	for s in np.arange(0.06, 0.5, 0.11):
		d.disc("cowl", C, (s, FRONT + 0.03), 0.015)
	d.save(OUT + "abyss_decal.png")


import sys
_want = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for _n, _f in (("filament", filament), ("vesper", vesper), ("cinder", cinder), ("borealis", borealis), ("abyss", abyss)):
	if not _want or _n in _want:
		_f()
