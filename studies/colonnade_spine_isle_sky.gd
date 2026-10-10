extends "res://studies/aqueduct_isle_sky.gd"
## The sky round the colonnade spine (studies/colonnade_spine_isle.gd): the
## aqueduct isle's sky (studies/aqueduct_isle_sky.gd: far isles, clusters,
## the pierced isle, airships, CPU planes, sky life, motes) unchanged, its
## tokens this isle's own: a slalom for the plane down the colonnade (in
## and out between its piers, under its lintels, through its portal
## arches) and on down the curling tail (TOKENS). Same flags.

const Spine = preload("res://studies/colonnade_spine_isle_art.gd")

func _build_tokens() -> void:
	collectibles = SkyCollectibles.new()
	collectibles.cells = SkyCells.new()
	collectibles.seed_value = TOKEN_SEED
	collectibles._trails_laid = true
	add_child(collectibles)
	var lines: Array = []
	for t: Array in Spine.plane_tokens():
		lines.append(Lines.line(t[0],t[1],t[2],PackedVector3Array(t[3]),TOKEN_SEED))
	collectibles.add_source("colonnade",lines)
