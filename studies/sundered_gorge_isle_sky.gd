extends "res://studies/aqueduct_isle_sky.gd"
## The sky round the Sundered gorge isle: the aqueduct isle's (studies/
## aqueduct_isle_sky.gd: far isles, clusters, the pierced isle, airships,
## CPU planes, open-air life, motes; the same --no-... flags), its middle
## close enough to this isle's that the far ring stands clear of it, with
## this isle's own tokens for the plane (GORGE_TOKENS): the gorge's line.
const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")

## The tokens: [line id, category, kind, points (world)]: the motif's
## (scripts/kit_isle/motif_sundered_gorge.gd).
const GORGE_TOKENS := preload("res://scripts/kit_isle/motif_sundered_gorge.gd").GORGE_TOKENS

func plane_tokens() -> Array:
	return GORGE_TOKENS

func token_source() -> String:
	return "sundered_gorge"
