"""The metal batch (scripts/endless/skins/metal.gd): four bakes and a decal.
Run: python tools/blender.py run art/blender/hero_plane/skins/metal.py
(one name after `--` remakes only that one: rust, copper, brass, gold, gunmetal)

Copper and Gold are skinned in metal nose to tail (cloth "bare"); Brass bares
only the forward body and cowl, the rest dark wood tones. Each row's finish
`bare` puts the mirror on the bared metal (spec-skins.md, Finishes)."""
import sys

from hero_plane.hero_plane_bake import bake
from hero_plane.hero_plane_decal import Decal

OUT = "assets/models/hero_plane/skins/metal/"
only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def want(name):
	return not only or name in only


if want("rust"):
	# Chips through to steel, the steel rusted and rust gathered in the seams.
	bake(OUT + "rust", wear=2.0, dirt=0.6, bare=0.35, bare_c="5e5a55", rust=1.0)
if want("copper"):
	# Polished copper all over, verdigris in the seams and the chips.
	bake(OUT + "copper", wear=0.35, dirt=0.3, bare=1.0, bare_c="d97f48", rust=0.7,
		rust_c="4f9a7a", cloth="bare")
if want("brass"):
	# Bare brass forward, duller and greener than gold; the cloth stays doped.
	bake(OUT + "brass", wear=0.4, dirt=0.5, bare=1.0, bare_c="a8964a")
if want("gold"):
	# Fresh gold nose to tail.
	bake(OUT + "gold", wear=0.0, dirt=0.0, bare=1.0, bare_c="ffc23a", cloth="bare")

if want("gunmetal"):
	# Gunmetal: a pale rule on the painted parts.
	d = Decal()
	d.stripe("body", "9aa3ad", z=(-0.48, 0.68), s=(0.085, 0.095))
	d.band("wings_top", "9aa3ad", (0.5, 0.52))
	d.save(OUT + "gunmetal_decal.png")
