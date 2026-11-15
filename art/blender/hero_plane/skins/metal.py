"""The metal batch (scripts/endless/skins/metal.gd): four bakes and a decal.
Run: python tools/blender.py run art/blender/hero_plane/skins/metal.py"""
from hero_plane.hero_plane_bake import bake
from hero_plane.hero_plane_decal import Decal

OUT = "assets/models/hero_plane/skins/metal/"
bake(OUT + "rust", wear=1.8, dirt=1.5, bare=0.0, rust=0.9)
bake(OUT + "copper", wear=0.5, dirt=0.5, bare=1.0, bare_c="b87333", rust=0.2)
bake(OUT + "brass", wear=0.25, dirt=0.4, bare=1.0, bare_c="c9a23c")
bake(OUT + "gold", wear=0.0, dirt=0.0, bare=1.0, bare_c="e0a830", cloth="doped")

# Gunmetal: a small mark on the painted parts, a pale rule and a number.
d = Decal()
d.stripe("body", "9aa3ad", z=(-0.48, 0.68), s=(0.085, 0.095))
d.band("wings_top", "9aa3ad", (0.5, 0.52))
d.save(OUT + "gunmetal_decal.png")
