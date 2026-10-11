extends "res://studies/aqueduct_isle_sky.gd"
## The sky round the bell spires isle: the aqueduct isle's (far isles,
## airships, CPU planes, open-air life, motes; every --no-... flag), its
## tokens for the plane this isle's own, each a line through the spires.
const Spires = preload("res://studies/bell_spires_isle_art.gd")
const Motif = preload("res://scripts/kit_isle/motif_bell_spires.gd")

## The plane's tokens: [line id, category, kind, points (world)]: the
## motif's (scripts/kit_isle/motif_bell_spires.gd `spire_tokens`).
static func spire_tokens() -> Array:
	return Motif.spire_tokens()

func plane_tokens() -> Array:
	return spire_tokens()

func token_source() -> String:
	return "bell_spires"
