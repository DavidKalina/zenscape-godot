extends "res://studies/aqueduct_isle_sky.gd"
## The sky round the Olmec field (studies/olmec_field.gd): the aqueduct
## isle's (clouds, airships, CPU planes, sky life; every --no-... flag),
## with no plane tokens (the aqueduct's slalom isn't here).

func plane_tokens() -> Array:
	return []

func token_source() -> String:
	return "olmec_field"
