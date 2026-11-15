"""The heritage batch's decals and bake (scripts/endless/skins/heritage.py).
Run: python tools/blender.py run art/blender/hero_plane/skins/heritage.py"""
import math
import numpy as np
from hero_plane.hero_plane_decal import COWL_L, FRONT, Decal

OUT = "assets/models/hero_plane/skins/heritage/"

# Pennant: twin cream stripes the length of the body, a 7 on the fin.
d = Decal()
d.stripe("body", "f1e8d0", z=(-0.48, 0.70), s=(0.07, 0.09))
d.stripe("body", "f1e8d0", z=(-0.48, 0.70), s=(0.105, 0.115))
d.text("fin", "7", "f1e8d0", at=(0.60, 0.17), height=0.09)
d.save(OUT + "pennant_decal.png")

# Courier: mustard bands on the wings and body, a route word down the side.
d = Decal()
d.band("wings_top", "e0a93a", (0.20, 0.27))
d.band("wings_top", "e0a93a", (0.46, 0.53))
d.band("wings_under", "e0a93a", (0.20, 0.27))
d.band("wings_under", "e0a93a", (0.46, 0.53))
d.band("body", "e0a93a", (-0.40, -0.36))
d.band("body", "e0a93a", (0.62, 0.66))
d.text("body", "VALE MAIL", "f0e6c8", at=(-0.02, 0.22), height=0.085)
d.text("fin", "MAIL", "e0a93a", at=(0.60, 0.17), height=0.05)
d.save(OUT + "courier_decal.png")

# Clubman: plum lower body under a scalloped edge, scalloped cowl, a plain band.
d = Decal()
d.scallop("cowl", "6e2c48", a=(0.0, 0.5), b=(FRONT + 0.02, COWL_L - 0.04), n=7, depth=0.03)
d.rect("body", "6e2c48", a=(-0.5, 0.72), b=(0.30, 0.6))
d.stripe("body", "e9dfc4", z=(-0.48, 0.70), s=(0.285, 0.30))
d.band("wings_top", "6e2c48", (0.50, 0.56))
d.band("tail", "6e2c48", (0.08, 0.135))
d.save(OUT + "clubman_decal.png")

# Barnstormer: a sunburst over the top wings, a disc of it on each body side.
def rays(cx, cy, n, sq=1.0):
	def fn(a, b, side):
		ang = np.arctan2((b - cy) * sq, (a - cx))
		r = np.hypot(a - cx, (b - cy) * sq)
		t = np.sin(ang * n) * 6.0
		return np.clip(t, 0, 1) * np.clip((r - 0.03) * 40, 0, 1)
	return fn
d = Decal()
d.mask("wings_top", "f2c230", rays(0.0, 0.15, 7, 1.0))
d.mask("wings_top", "9a2b1c", lambda a, b, s: np.clip(np.sin(np.arctan2(b - 0.15, a) * 7 + math.pi) * 6, 0, 1)
	* np.clip((np.hypot(a, b - 0.15) - 0.03) * 40, 0, 1) * (np.hypot(a, b - 0.15) < 0.42))
d.disc("wings_top", "9a2b1c", at=(0.0, 0.15), r=0.07)
d.disc("wings_top", "f2c230", at=(0.0, 0.15), r=0.045)
d.stripe("body", "f2c230", z=(-0.48, 0.70), s=(0.10, 0.13))
d.stripe("body", "9a2b1c", z=(-0.48, 0.70), s=(0.14, 0.16))
d.band("tail", "f2c230", (0.0, 0.05))
d.save(OUT + "barnstormer_decal.png")

# Meridian: bare of ornament, one line and a name down the side.
d = Decal()
d.stripe("body", "f0e6c8", z=(-0.40, 0.70), s=(0.255, 0.27))
d.text("body", "MERIDIAN", "f0e6c8", at=(-0.1, 0.2), height=0.065)
d.save(OUT + "meridian_decal.png")
# The bake is slow (minutes): made only when its maps are missing.
from pathlib import Path
from hero_plane.hero_plane_bake import ROOT, bake
if not (ROOT / (OUT + "meridian_albedo.jpg")).exists():
	bake(OUT + "meridian", wear=0.1, dirt=0.15)
