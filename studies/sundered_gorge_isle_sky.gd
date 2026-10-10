extends "res://studies/aqueduct_isle_sky.gd"
## The sky round the Sundered gorge isle: the aqueduct isle's (studies/
## aqueduct_isle_sky.gd: far isles, clusters, the pierced isle, airships,
## CPU planes, open-air life, motes; the same --no-... flags), its middle
## close enough to this isle's that the far ring stands clear of it, with
## this isle's own tokens for the plane (GORGE_TOKENS): the gorge's line.
const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")

## The tokens: [line id, category, kind, points (world)].
const GORGE_TOKENS := [
	# The gorge's line: in at the narrow north mouth, past the curtain, under
	# the lower crossing's fragments, under the broken bridge (between its
	# snapped ends and the fallen crown), out past the spur at the south mouth.
	["sg:gorge","air","thread",[Vector3(86.6,24.0,-61.0),Vector3(87.2,21.0,-47.0),Vector3(88.3,23.5,-15.0),Vector3(87.0,24.5,4.0)]],
	# Close by the curtain, where it falls past the lower ledge.
	["sg:curtain","air","break",[Vector3(83.6,23.0,-56.0)]],
	# Under the split, between the two halves' hanging keels.
	["sg:keel","under","keel",[Vector3(88.0,2.0,-22.0)]],
]

func _build_tokens() -> void:
	collectibles = SkyCollectibles.new()
	collectibles.cells = SkyCells.new()
	collectibles.seed_value = TOKEN_SEED
	collectibles._trails_laid = true
	add_child(collectibles)
	var lines: Array = []
	for t: Array in GORGE_TOKENS:
		lines.append(Lines.line(t[0],t[1],t[2],PackedVector3Array(t[3]),TOKEN_SEED))
	collectibles.add_source("sundered_gorge",lines)
