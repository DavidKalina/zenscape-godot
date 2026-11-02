extends "res://scripts/endless/world/world_profile.gd"
## Wilderness: the endless world as tagged world-wilderness-v1 (hills,
## ranges, meadows, valleys, rivers, ponds and coast; spruce woods and a
## flowered carpet; the alpine morning). The default world, and the template
## to copy for a new one (docs/design/endless-flight/world-profiles-handoff.md).
## Every value here is the engine's stock value, past the coast: change one
## and the world changes.

const Field = preload("res://scripts/endless/land_field.gd")

func _init() -> void:
	id = "wilderness"
	title = "Wilderness"
	# The land: LandField's recipe constants (continents, hills, ranges,
	# peaks, meadows, valleys, snow) and the flags' knobs at 1.
	land = Field.recipe_defaults()
	land.merge({"mountains":1.0,"peaks":1.0,"valleys":1.0,"carve":1.0,"carve_blocks":1.0,"carve_ledges":1.0,"carve_gullies":1.0,
		"rivers":1.0,"river_width":1.0,"river_drop":1.0,"river_cut":1.0,"river_fill":1.0,"river_mouth":1.0,"river_flare":1.0,"ponds":1.0})
	# The edge: land sinks into open sea round a 17 km rounded square centred on
	# the placed content (--no-coast takes it off, --coast-half=m sizes it).
	land.merge({"coast_x":-1000.0,"coast_z":600.0,"coast_half":8500.0,"coast_corner":3000.0,"coast_ramp":1400.0,"coast_depth":240.0,"coast_wobble":500.0})
	# The flora: the spruce woods at their share, HeroTrees.SPRUCE's own
	# variant weights (empty), the carpet's tufts and its flowers.
	flora = {"forest":1.0,"forest_meadows":1.0,"tree_weights":PackedFloat32Array(),"grass":1.0,"flowers":true}
	# The paint: the alpine morning at 8.6 (EndlessLook MOOD, HOUR), the
	# ground and sea shaders' own defaults (the watercolour meadows, the high
	# paint, the sea's tints), no shader globals past the season reset.
	paint = {"mood":"alpine_morning","hour":8.6,"ground":{},"sea":{},"globals":{}}
	# Every dressing layer. The rock shapes: sea stacks along the coasts
	# (--no-rocks turns them off). No hoodoos (taken out 2026-10-27: they
	# read as clay; --hoodoos=2.5 brings back the pockets they had).
	layers = {"trees":true,"grass":true,"birds":true,"fish":true,"tunnels":1.0,"arches":1.0,"splits":1.0,"split_kinds":{"slot":0.7,"winding":1.0,"gorge":1.8,"grand":2.5},
		"stacks":1.5,"traffic":-1}
	# The start: over the origin, 45 m up (endless_flight START_ALT), north.
	spawn = {"at":Vector2.ZERO,"alt":45.0,"heading":0.0}
