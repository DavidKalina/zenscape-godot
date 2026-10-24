extends "res://scripts/endless/world/world_profile.gd"
## TEST PROFILE, not a world to play: proves the engine/profile seam
## (--world=test_dry). The same engine as wilderness with a drier palette,
## a thinner forest, fewer flowers, no rivers and lower hills
## (docs/design/endless-flight/world-profiles-handoff.md).

const Field = preload("res://scripts/endless/land_field.gd")

func _init() -> void:
	id = "test_dry"
	title = "Test: dry"
	test = true
	land = Field.recipe_defaults()
	land.merge({"rivers":0.0,"ponds":0.4},true)
	# A recipe number through the native field's configure: lower hills.
	land.hill_tall = 10.0
	flora = {"forest":0.35,"forest_meadows":0.5,"tree_weights":PackedFloat32Array(),"grass":0.8,"flowers":false}
	paint = {"mood":"desert_afternoon","hour":-1.0,
		"ground":{"wc_paint":0.6,"carpet_tone_top":Vector3(1.12,1.02,0.78),"carpet_tone_low":Vector3(1.05,0.95,0.72)},
		"sea":{"tint_shallow":Color(0.45,0.80,0.70)},
		"globals":{"zs_palette_grass":Vector3(1.18,1.04,0.72)}}
	layers = {"trees":true,"grass":true,"birds":true,"fish":false,"arches":1.0,"traffic":-1}
	spawn = {"at":Vector2.ZERO,"alt":45.0,"heading":0.0}
