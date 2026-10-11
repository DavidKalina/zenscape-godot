extends "res://studies/aqueduct_isle_sky.gd"
## The sky round the colonnade spine (studies/colonnade_spine_isle.gd): the
## aqueduct isle's sky (studies/aqueduct_isle_sky.gd: far isles, clusters,
## the pierced isle, airships, CPU planes, sky life, motes) unchanged, its
## tokens this isle's own: a slalom for the plane down the colonnade (in
## and out between its piers, under its lintels, through its portal
## arches) and on down the curling tail (TOKENS). Same flags.

const Spine = preload("res://studies/colonnade_spine_isle_art.gd")

func plane_tokens() -> Array:
	return Spine.plane_tokens()

func token_source() -> String:
	return "colonnade"
