"""The heritage batch's decals and bake (scripts/endless/skins/heritage.py).
Run: python tools/blender.py run art/blender/hero_plane/skins/heritage.py"""
import math
import numpy as np
from hero_plane.hero_plane_decal import COWL_L, FRONT, Decal

OUT = "assets/models/hero_plane/skins/heritage/"

WING = (0.0, 0.7), (0.0, 0.3)
TAIL = (0.0, 0.26), (0.0, 0.135)

def fill(d, c):
	"""The top wings, the tailplane and the fin in the livery's own colour,
	so a skin's wings are its own colour from above (the atlas's cloth is cream)."""
	d.rect("wings", c, *WING)
	d.rect("tail", c, *TAIL)

# Pennant: cobalt wings crossed by two bold cream bands, twin cream stripes
# down the spine and over the tailplane, a big 7 on the fin.
d = Decal()
fill(d, "2f6bc0")
d.rect("fin", "2f6bc0", (0.47, 0.76), (0.05, 0.3))
for x0 in (0.18, 0.40):
	d.band("wings_top", "f4ecd6", (x0, x0 + 0.09))
d.band("wings_top", "f4ecd6", (0.58, 0.62))
d.stripe("body", "f4ecd6", z=(-0.48, 0.70), s=(0.0, 0.035))
d.stripe("body", "f4ecd6", z=(-0.48, 0.70), s=(0.075, 0.095))
d.band("tail", "f4ecd6", (0.08, 0.17))
d.text("fin", "7", "f4ecd6", at=(0.60, 0.17), height=0.15)
d.save(OUT + "pennant_decal.png")

# Courier: forest-green wings with mustard bands across the tips and middle,
# a mustard tailplane, MAIL on the fin.
d = Decal()
fill(d, "2f5d46")
d.rect("fin", "2f5d46", (0.47, 0.76), (0.05, 0.3))
d.band("wings_top", "e0a93a", (0.52, 0.70))
d.band("wings_top", "e0a93a", (0.22, 0.30))
d.band("wings_top", "e0a93a", (0.0, 0.08))
d.rect("tail", "e0a93a", (0.12, 0.26), (0.0, 0.135))
d.stripe("body", "e0a93a", z=(-0.48, 0.70), s=(0.0, 0.03))
d.band("body", "e0a93a", (-0.40, -0.36))
d.band("body", "e0a93a", (0.62, 0.66))
d.text("fin", "MAIL", "e0a93a", at=(0.62, 0.16), height=0.055)
d.save(OUT + "courier_decal.png")

# Clubman: ivory wings with plum scallops along the leading edge and plum
# tips, a plum tailplane edge, plum lower body under a scalloped cowl.
def scal(a, b, side):
	edge = 0.07 + 0.035 * np.cos(a * 2 * math.pi / 0.1)
	return np.clip((edge - b) * 60, 0, 1)
d = Decal()
fill(d, "ece4cf")
d.mask("wings_top", "6e2c48", scal)
d.band("wings_top", "6e2c48", (0.56, 0.70))
d.mask("tail", "6e2c48", scal)
d.rect("tail", "ece4cf", (0.0, 0.26), (0.11, 0.135))
d.scallop("cowl", "6e2c48", a=(0.0, 0.5), b=(FRONT + 0.02, COWL_L - 0.04), n=7, depth=0.03)
d.rect("body", "6e2c48", a=(-0.5, 0.72), b=(0.30, 0.6))
d.stripe("body", "e9dfc4", z=(-0.48, 0.70), s=(0.285, 0.30))
d.save(OUT + "clubman_decal.png")

# Barnstormer: an orange wing under a sunburst whose rays run to the tips.
def rays(ph):
	def fn(a, b, side):
		ang = np.arctan2(b - 0.15, a)
		r = np.hypot(a, b - 0.15)
		return np.clip(np.sin(ang * 7 + ph) * 6.0, 0, 1) * np.clip((r - 0.05) * 40, 0, 1)
	return fn
d = Decal()
fill(d, "d9772a")
d.mask("wings_top", "f5cf3a", rays(0.0))
d.mask("wings_top", "8f2418", rays(math.pi))
d.disc("wings_top", "8f2418", at=(0.0, 0.15), r=0.075)
d.disc("wings_top", "f5cf3a", at=(0.0, 0.15), r=0.05)
d.rect("tail", "f5cf3a", (0.0, 0.26), (0.0, 0.05))
d.stripe("body", "f2c230", z=(-0.48, 0.70), s=(0.10, 0.13))
d.stripe("body", "8f2418", z=(-0.48, 0.70), s=(0.14, 0.16))
d.save(OUT + "barnstormer_decal.png")

# Meridian: deep navy and gold. A compass rose over the top wing's centre, a
# meridian line tip to tip, gold caps, fine lines, a small name on the fin.
NAVY, GOLD = "141c3a", "d4a64a"
def rose(a, b, side):
	x, y = a, b - 0.15
	r = np.hypot(x, y)
	pts = np.clip(1.0 - (np.abs(x) + np.abs(y) * 4.0) / 0.13, 0, 1) + np.clip(1.0 - (np.abs(y) + np.abs(x) * 4.0) / 0.13, 0, 1)
	return np.clip(pts * 8, 0, 1)
d = Decal()
fill(d, NAVY)
d.rect("fin", NAVY, (0.47, 0.76), (0.05, 0.3))
d.rect("body", NAVY, a=(0.20, 0.70), b=(0.08, 0.34))      # hides the plane's own 27
d.disc("wings_top", GOLD, at=(0.0, 0.15), r=0.10, ring=0.09)
d.disc("wings_top", GOLD, at=(0.0, 0.15), r=0.06, ring=0.055)
d.mask("wings_top", GOLD, rose)
d.rect("wings_top", GOLD, (0.0, 0.7), (0.145, 0.155))
d.band("wings_top", GOLD, (0.60, 0.70))
d.band("wings_top", GOLD, (0.34, 0.345))
d.band("wings_top", GOLD, (0.46, 0.465))
d.rect("tail", GOLD, (0.20, 0.26), (0.0, 0.135))
d.rect("tail", GOLD, (0.0, 0.26), (0.065, 0.07))
d.stripe("body", GOLD, z=(-0.40, 0.70), s=(0.255, 0.265))
d.stripe("body", GOLD, z=(-0.48, 0.70), s=(0.0, 0.012))
d.stripe("body", GOLD, z=(-0.48, 0.70), s=(0.07, 0.078))
d.text("fin", "MERIDIAN", GOLD, at=(0.615, 0.17), height=0.034)
d.save(OUT + "meridian_decal.png")
# The bake is slow (minutes): made only when its maps are missing.
from pathlib import Path
from hero_plane.hero_plane_bake import ROOT, bake
if not (ROOT / (OUT + "meridian_albedo.jpg")).exists():
	bake(OUT + "meridian", wear=0.1, dirt=0.15)
