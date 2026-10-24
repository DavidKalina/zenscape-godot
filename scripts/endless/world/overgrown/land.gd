extends RefCounted
## Overgrown's land recipe (scripts/endless/world/profiles/overgrown.gd): the
## old builders' land (docs/design/endless-flight/overgrown-land-handoff.md).
## Lower, broader, straighter ranges with gable crests and clean notches (the
## ridges a hall would cut through), terraced hills, mesas standing out of the
## lowland, and wilderness's valleys, rivers, coast and sea between.

const Field = preload("res://scripts/endless/land_field.gd")

static func recipe() -> Dictionary:
	var land := Field.recipe_defaults()
	land.merge({"mountains":1.0,"peaks":1.0,"valleys":1.0,"carve":1.0,"carve_blocks":1.0,"carve_ledges":1.0,"carve_gullies":1.0,
		"rivers":1.0,"river_width":1.0,"river_drop":1.0,"river_cut":1.0,"river_fill":1.0,"river_mouth":1.0,"river_flare":1.0,"ponds":1.0})
	land.merge({
		# Ranges: longer and straighter crest lines, lower, a gable crest.
		"range_scale":3400.0,
		"range_width":0.16,
		"warp_move":140.0,
		"peak_tall":Vector2(70.0,150.0),
		"ridge_scale":1500.0,
		"ridge_crisp":0.7,
		"range_band":Vector2(-0.7,-0.3),
		"notch":0.5,
		"notch_scale":5000.0,
		"notch_width":Vector2(0.04,0.09),
		# Hills as wilderness's, terraced.
		"hill_tall":16.0,
		"terrace":1.0,
		"terrace_step":4.0,
		"terrace_flat":0.65,
		"terrace_scale":1500.0,
		"terrace_band":Vector2(-0.15,0.2),
		# Mesas.
		"mesa":1.0,
		"mesa_tall":50.0,
		"mesa_scale":1400.0,
		"mesa_level":0.05,
		"mesa_edge":0.025,
		"mesa_steps":2.0,
		"mesa_gap":0.06,
		"mesa_keep":0.12,
		"mesa_mask_scale":3800.0,
		"mesa_band":Vector2(-0.1,0.2),
		# No snow on these lower ranges.
		"snow":320.0,
	},true)
	return land
