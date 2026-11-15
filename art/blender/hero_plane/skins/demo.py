"""Stage 1's decal demo (scripts/endless/skins/demo.gd, paint/chequer): a
racer's marks over a deep red. Run: python tools/blender.py run
art/blender/hero_plane/skins/demo.py"""
from hero_plane.hero_plane_decal import COWL_L, FRONT, Decal

CREAM = "f2ead6"
INK = "1d1f24"

d = Decal()
# A checkered cowl, its skirt only; two cream lines trailing back down the body.
d.checker("cowl", INK, a=(0.0, 0.5), b=(FRONT + 0.02, COWL_L), cell=0.04)
d.stripe("body", CREAM, z=(-0.48, 0.68), s=(0.075, 0.092))
d.stripe("body", CREAM, z=(-0.48, 0.68), s=(0.105, 0.115))
# The race number in a cream disc on each side, and on the fin.
d.disc("body", CREAM, at=(0.25, 0.2), r=0.055)
d.text("body", "9", INK, at=(0.25, 0.2), height=0.07)
d.text("fin", "9", CREAM, at=(0.648, 0.125), height=0.07)
# Wing tips banded in ink with a cream edge.
d.band("wings_top", INK, (0.5, 0.56))
d.band("wings_top", CREAM, (0.56, 0.575))
# Ink scallops behind the cowl, down both sides.
d.scallop("body", INK, a=(-0.45, -0.38), b=(0.0, 0.45), n=5, depth=0.05)
d.save("assets/models/hero_plane/skins/demo/chequer_decal.png")
