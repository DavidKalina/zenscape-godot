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
	d.stripe("body", "eef2f4", s=(0.28, 0.6), soft=0.03)
	d.stripe("up_under", "eef2f4", s=(-1, 9))
	d.stripe("lo_under", "eef2f4", s=(-1, 9))
	for i in range(4):
		z = -0.36 + i * 0.05
		d.rect("body", "1c2329", (z, z + 0.016), (0.06, 0.2))
	# A wide mouth round the cowl: black rim, red inside, bold white teeth.
	M0, M1 = FRONT + 0.005, FRONT + 0.15
	def lip(a, b, side):
		return sst(0.08, 0.14, a) * inside(b, M0, M1 + 0.02, 0.006)
	d.mask("cowl", "16191c", lip)
	def gape(a, b, side):
		return sst(0.09, 0.15, a) * inside(b, M0 + 0.015, M1 - 0.01, 0.006)
	d.mask("cowl", "c4261f", gape)
	def teeth(a, b, side):
		period = 0.09
		tri = 1.0 - np.abs((a % period) / period - 0.5) * 2.0
		edge = M1 - 0.01
		return sst(0.09, 0.15, a) * (b < edge) * (b > edge - 0.12 * tri)
	d.mask("cowl", "fbfcfb", teeth)
	def teeth_up(a, b, side):
		period = 0.09
		tri = 1.0 - np.abs(((a + 0.045) % period) / period - 0.5) * 2.0
		edge = M0 + 0.015
		return sst(0.09, 0.15, a) * (b > edge) * (b < edge + 0.07 * tri)
	d.mask("cowl", "fbfcfb", teeth_up)
	# The eye above the mouth: white with a black pupil.
	d.disc("cowl", "fbfcfb", at=(0.04, FRONT + 0.235), r=0.045)
	d.disc("cowl", "0b0d10", at=(0.04, FRONT + 0.24), r=0.028)
	# Seen from behind: dark dorsal stripe, dark wing and tail tips, dark fin tip.
	d.stripe("body", "28333b", s=(0, 0.1), soft=0.04, z=(-0.2, 0.7))
	d.band("wings_top", "28333b", (0.52, 0.72))
	d.band("wings_under", "28333b", (0.52, 0.72))
	d.rect("tail", "28333b", (0.17, 0.3), (-1, 9))
	d.rect("fin", "28333b", (-9, 9), (0.2, 0.4))
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
	for x0 in (0.08, 0.26, 0.44, 0.60):
		d.band("wings_top", "17120d", (x0, x0 + 0.09))
	d.band("tail", "17120d", (0.0, 0.07))
	d.rect("fin", "17120d", (-9, 9), (0.15, 0.4))
	d.save(OUT + "bee_decal.png")


def moth():
	d = Decal()
	CR, RUST, BRN, INK = "f3ead0", "d0652a", "3a2416", "120c08"

	def eye(on, at, r, off):
		d.disc(on, BRN, at=at, r=r)
		d.disc(on, RUST, at=at, r=r * 0.82)
		d.disc(on, CR, at=at, r=r * 0.62)
		d.disc(on, "6aa0c0", at=at, r=r * 0.42)
		px, py = at[0] + off[0] * r, at[1] + off[1] * r
		d.disc(on, INK, at=(px, py), r=r * 0.27)
		# a pale crescent opposite the pupil's drift
		d.disc(on, CR, at=(px - off[0] * r * 0.45, py - off[1] * r * 0.45), r=r * 0.08)

	eye("up_top", (0.40, 0.155), 0.135, (0.18, 0.1))
	eye("lo_top", (0.36, 0.15), 0.115, (0.18, 0.1))
	# Dark feathered trailing edge and a rust leading band on every wing.
	def feather(a, b, side):
		edge = 0.235 + 0.03 * np.sin(a * 70.0) ** 2
		return sst(0.012, 0.0, edge - b) * (b > 0) + 0.0
	def fe(a, b, side):
		edge = 0.225 + 0.03 * np.abs(np.sin(a * 55.0))
		return sst(edge - 0.01, edge + 0.01, b)
	d.mask("wings_top", BRN, fe)
	d.mask("tail", BRN, fe)
	d.rect("wings_top", RUST, (0.0, 0.72), (0.0, 0.035))
	d.rect("wings_under", BRN, (0.0, 0.72), (0.2, 0.4), soft=0.01)
	# Pale furry body line and belly.
	d.stripe("body", "f0e8c8", s=(0, 0.09), soft=0.03, z=(-0.3, 0.7))
	d.stripe("body", "f0e8c8", s=(0.24, 0.6), soft=0.05)
	d.rect("fin", BRN, (-9, 9), (0.2, 0.4))
	d.save(OUT + "moth_decal.png")


def koi():
	d = Decal()
	RED, INK, GOLD = "d8301a", "17161a", "dcae3c"

	def ell(cx, cy, rx, ry, seed):
		"""A clean-edged patch: an ellipse with a gentle wobble."""
		def f(a, b, side):
			w = 1.0 + 0.22 * (vnoise(a, b, 0.12, seed) - 0.5)
			q = ((a - cx) / rx) ** 2 + ((b - cy) / ry) ** 2
			return sst(1.04, 0.96, q * w)
		return f
	# Big patches on the top wings (mirrored left and right) and the tail.
	d.mask("up_top", RED, ell(0.17, 0.15, 0.2, 0.16, 1))
	d.mask("up_top", INK, ell(0.45, 0.12, 0.1, 0.09, 2))
	d.mask("up_top", RED, ell(0.62, 0.14, 0.09, 0.13, 3))
	d.mask("lo_top", RED, ell(0.2, 0.14, 0.17, 0.15, 4))
	d.mask("lo_top", INK, ell(0.46, 0.12, 0.1, 0.1, 5))
	d.mask("up_under", RED, ell(0.3, 0.15, 0.25, 0.15, 6))
	d.mask("lo_under", RED, ell(0.3, 0.15, 0.25, 0.15, 7))
	d.mask("tail", RED, ell(0.09, 0.07, 0.11, 0.07, 8))
	d.mask("tail", INK, ell(0.22, 0.07, 0.05, 0.06, 9))
	d.mask("fin", RED, ell(0.62, 0.15, 0.12, 0.09, 10))
	# The body: a few large flank patches.
	d.mask("body", RED, ell(-0.12, 0.2, 0.2, 0.12, 11))
	d.mask("body", INK, ell(0.2, 0.17, 0.12, 0.09, 12))
	d.mask("body", RED, ell(0.5, 0.2, 0.14, 0.11, 13))
	d.mask("body", RED, ell(0.05, 0.0, 0.3, 0.07, 14))
	d.disc("cowl", RED, at=(0.0, FRONT + 0.14), r=0.11)
	d.disc("cowl", INK, at=(0.27, FRONT + 0.13), r=0.06)
	# Gold: wing tips, fin top, a scale edging behind the cowl.
	d.band("wings_top", GOLD, (0.58, 0.68))
	d.band("wings_under", GOLD, (0.58, 0.68))
	d.rect("fin", GOLD, (-9, 9), (0.27, 0.4))
	d.rect("tail", GOLD, (0.23, 0.3), (-1, 9))
	d.scallop("body", GOLD, a=(-0.47, -0.45), b=(0.0, 0.5), n=6, depth=0.035)
	d.stripe("body", GOLD, s=(0.0, 0.012), z=(-0.45, 0.7))
	d.save(OUT + "koi_decal.png")


for f in (shark, kingfisher, bee, moth, koi):
	f()
