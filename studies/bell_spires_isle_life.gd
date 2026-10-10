extends "res://scripts/kit_isle/kit_life.gd"
## Life on the bell spires (docs/scenic/bell-spires.md): the kit isles'
## (scripts/kit_isle/kit_life.gd: undergrowth, butterflies, fireflies,
## songbirds, the wind made visible, on-foot tokens; every --no-... flag)
## with this isle's perches (studies/bell_spires_isle_birds.gd), tokens
## (studies/bell_spires_isle_tokens.gd), meadow and spires' feet.
const Art = preload("res://studies/bell_spires_isle_art.gd")
const Birds = preload("res://studies/bell_spires_isle_birds.gd")
const Tokens = preload("res://studies/bell_spires_isle_tokens.gd")

## The meadow the chaff lies on (world rect).
const CHAFF_MEADOW := Rect2(88.0,-14.0,22.0,16.0)

func make_birds() -> Node3D:
	return Birds.new()

func make_tokens() -> Node3D:
	return Tokens.new()

func chaff_meadow() -> Rect2:
	return CHAFF_MEADOW

## The loose bits ride up the spires: a taller box.
func wind_box() -> Vector2:
	return Vector2(6.0,44.0)

## The start and the spires' feet toward it.
func leaf_spots() -> Array:
	var anchors: Array = []
	var l: Dictionary = Art.layout()
	anchors.append(Vector2(l.start.x,l.start.z))
	for name: String in ["hero","low","fin_low","fin_high"]:
		var s: Dictionary = l.spires[name]
		var c: Vector2 = s.c
		var toward := (Vector2(l.start.x,l.start.z)-c).normalized()
		anchors.append(c+toward*(float(s.r)*1.18+0.6))
	return anchors
