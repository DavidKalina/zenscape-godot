"""The wild batch's decals (scripts/endless/skins/wild.gd): shark, kingfisher,
bee, moth, koi. Run: python tools/blender.py run art/blender/hero_plane/skins/wild.py"""
import numpy as np
from hero_plane.hero_plane_decal import COWL_L, FRONT, Decal, inside, sst

OUT = "assets/models/hero_plane/skins/wild/"


def vnoise(a, b, scale, seed):
	"""Smooth value noise 0..1 over (a, b) with cells `scale` wide."""
	x, y = a / scale + seed * 17.3, b / scale + seed * 9.1
	xi, yi = np.floor(x), np.floor(y)
	fx, fy = x - xi, y - yi
	fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)

	def h(i, j):
		n = np.sin(i * 127.1 + j * 311.7 + seed * 74.7) * 43758.5453
		return n - np.floor(n)
	return ((h(xi, yi) * (1 - fx) + h(xi + 1, yi) * fx) * (1 - fy)
		+ (h(xi, yi + 1) * (1 - fx) + h(xi + 1, yi + 1) * fx) * fy)


def blobs(scale, seed, lo, hi):
	"""A patch mask: noise thresholded to soft-edged blobs."""
	return lambda a, b, side: sst(lo, hi, vnoise(a, b, scale, seed) * 0.65 + vnoise(a, b, scale * 0.45, seed + 3) * 0.35)


def shark():
	d = Decal()
	# Pale belly along the keel and under the wings.
	d.stripe("body", "e9eef0", s=(0.30, 0.6), soft=0.03)
	d.stripe("up_under", "e9eef0", s=(-1, 9))
	d.stripe("lo_under", "e9eef0", s=(-1, 9))
	# Gill slits behind the cowl.
	for i in range(4):
		z = -0.36 + i * 0.05
		d.rect("body", "1c2329", (z, z + 0.016), (0.06, 0.2))
	# The mouth: a dark grin round the lower cowl, teeth hanging aft of it.
	LINE = FRONT + 0.03
	def grin(a, b, side):
		line = LINE + 0.05 * sst(0.2, 0.49, a)
		return sst(0.14, 0.2, a) * inside(b, line, line + 0.06, 0.008)
	d.mask("cowl", "15191d", grin)
	def teeth(a, b, side):
		line = LINE + 0.05 * sst(0.2, 0.49, a) + 0.055
		period = 0.07
		tri = 1.0 - np.abs((a % period) / period - 0.5) * 2.0
		return sst(0.14, 0.2, a) * (b > line) * (b < line + 0.065 * tri)
	d.mask("cowl", "f6f8f6", teeth)
	# The eye: black with a pale ring and a glint, high on the cowl.
	d.disc("cowl", "f2f4f2", at=(0.11, FRONT + 0.15), r=0.048)
	d.disc("cowl", "0b0d10", at=(0.11, FRONT + 0.15), r=0.036)
	d.disc("cowl", "ffffff", at=(0.10, FRONT + 0.14), r=0.009)
	# A dark back and dark fin.
	d.stripe("body", "3a4852", s=(0, 0.1), soft=0.04)
	d.stripe("fin", "3a4852", s=(-9, 9))
	d.save(OUT + "shark_decal.png")


def kingfisher():
	d = Decal()
	# Orange belly and cheek, white throat patch on the cowl.
	d.stripe("body", "f08a1c", s=(0.26, 0.6), soft=0.04)
	d.rect("cowl", "f6f2e6", (0.0, 0.2), (FRONT, COWL_L), soft=0.03)
	d.stripe("lo_under", "f08a1c", s=(-1, 9))
	# A bright electric stripe down the back, wing coverts speckled.
	d.stripe("body", "3fd0e0", s=(0, 0.055), soft=0.02, z=(-0.2, 0.7))
	d.band("wings_top", "2fb8d0", (0.0, 0.05))
	d.save(OUT + "kingfisher_decal.png")


def bee():
	d = Decal()
	# Black bands round the abdomen, fuzzy edged; a dark nose.
	for z0 in (-0.30, -0.08, 0.14, 0.36):
		d.band("body", "17120d", (z0, z0 + 0.09), soft=0.012)
	d.rect("cowl", "17120d", (0.0, 0.6), (FRONT - 0.05, COWL_L), soft=0.02)
	# Bands across the wings.
	d.band("wings_top", "17120d", (0.08, 0.13))
	d.band("wings_top", "17120d", (0.2, 0.25))
	d.band("tail", "17120d", (0.0, 0.05))
	d.save(OUT + "bee_decal.png")


def moth():
	d = Decal()
	# Eye spots on the upper wing: concentric rings, a pale pupil.
	for r, c in ((0.11, "e8dcc0"), (0.088, "2c2118"), (0.062, "d4a050"), (0.034, "15100c")):
		d.disc("up_top", c, at=(0.43, 0.14), r=r)
		d.disc("lo_top", c, at=(0.38, 0.12), r=r * 0.8)
	d.disc("up_top", "f4ecd8", at=(0.415, 0.125), r=0.012)
	# A dusty edge to the wings and a pale band across them.
	d.band("wings_top", "b49a76", (0.58, 0.7))
	d.band("wings_top", "6b5640", (0.28, 0.3))
	# A furry body: pale thorax saddle, dark dorsal line.
	d.stripe("body", "8a7459", s=(0, 0.09), soft=0.03)
	d.stripe("body", "d8c8a4", s=(0.2, 0.6), soft=0.05)
	d.scallop("wings_top", "6b5640", a=(0.0, 0.04), b=(0.0, 0.3), n=1, depth=0.0) if False else None
	d.save(OUT + "moth_decal.png")


def koi():
	d = Decal()
	# Red and black patches, drifting as noise-cut islands, over white.
	for on, seed, sc in (("body", 1, 0.13), ("up_top", 2, 0.1), ("lo_top", 5, 0.1),
			("up_under", 9, 0.1), ("lo_under", 11, 0.1), ("tail", 7, 0.07), ("cowl", 4, 0.1)):
		d.mask(on, "d8321c", blobs(sc, seed, 0.60, 0.65))
		d.mask(on, "16151a", blobs(sc * 0.8, seed + 20, 0.67, 0.71))
	d.mask("fin", "d8321c", blobs(0.1, 3, 0.6, 0.65))
	# A red head cap on the cowl, as a tancho's mark.
	d.disc("cowl", "d8321c", at=(0.0, FRONT + 0.13), r=0.1)
	d.save(OUT + "koi_decal.png")


for f in (shark, kingfisher, bee, moth, koi):
	f()
