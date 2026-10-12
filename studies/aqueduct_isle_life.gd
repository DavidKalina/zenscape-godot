extends "res://scripts/kit_isle/kit_life.gd"
## Life on the aqueduct isle (docs/scenic/aqueduct-isle-life.md): the kit
## isles' life (scripts/kit_isle/kit_life.gd: undergrowth, butterflies,
## fireflies, songbirds on the stones, the wind made visible, on-foot
## tokens; every --no-... flag) with this isle's songbirds' perches
## (studies/aqueduct_isle_birds.gd), its tokens (studies/
## aqueduct_isle_tokens.gd), its meadow and its ruins' feet.
const Birds = preload("res://studies/aqueduct_isle_birds.gd")
const Tokens = preload("res://studies/aqueduct_isle_tokens.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")

## The meadow the chaff lies on (world rect).
const CHAFF_MEADOW := Rect2(80.0,-24.0,47.0,41.0)

func make_birds() -> Node3D:
	return Birds.new()

func make_tokens() -> Node3D:
	return Tokens.new()

func chaff_meadow() -> Rect2:
	return CHAFF_MEADOW

## The feet of the ruins the walker passes: the castellum, the blind wall,
## the heel stone, the gate.
func leaf_spots() -> Array:
	return [Vector2(97.6,3.4),Vector2(98.0,-6.0),Vector2(102.0,-11.0),Vector2(117.0,1.6),Vector2(100.0,-60.6-Art.FAR_SHIFT),Vector2(92.4,-1.0),Vector2(80.0,6.0),Vector2(79.0,-6.5)]
