extends "res://studies/aqueduct_isle_sky.gd"
## The sky round the Broken Ring (studies/broken_ring_isle.gd): the aqueduct
## isle's (airships, CPU planes, sky life, motes; every --no-... flag), its
## tokens for the plane this isle's own: a slalom through the gaps of the
## ring, under its bridges, through the break and over the circle.
const Motif = preload("res://scripts/kit_isle/motif_broken_ring.gd")

func plane_tokens() -> Array:
	return Motif.Ring.plane_tokens()

func token_source() -> String:
	return "broken_ring"
