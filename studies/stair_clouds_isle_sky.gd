extends "res://studies/aqueduct_isle_sky.gd"
## The sky round the Stair to the Clouds (studies/stair_clouds_isle.gd): the
## aqueduct isle's sky unchanged, its tokens this isle's own: the slot
## between the summit's wall and the pinnacle, and the corkscrew round the
## outside of the stair (Stair.plane_tokens()). Same flags.

const Stair = preload("res://studies/stair_clouds_isle_art.gd")

func plane_tokens() -> Array:
	return Stair.plane_tokens()

func token_source() -> String:
	return "stair_clouds"
