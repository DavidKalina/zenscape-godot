extends "res://studies/aqueduct_isle_sky.gd"
## The sky round the Hollow Keel (studies/hollow_keel_isle.gd): the aqueduct
## isle's sky (studies/aqueduct_isle_sky.gd) unchanged, its tokens this
## isle's own: the plane's line down the undercroft's lane, out through a
## breach, and one under the keel (HollowKeelArt `plane_tokens`). Same flags.
const Keel = preload("res://studies/hollow_keel_isle_art.gd")

func plane_tokens() -> Array:
	return Keel.plane_tokens()

func token_source() -> String:
	return "hollow_keel"
