extends RefCounted
## The amberlands' land recipe (scripts/endless/world/profiles/amberlands.gd):
## an old, worn land. Broad terraced shelves and shallow valleys over most of
## it, broken by a few bulky mountain massifs and by tiered plateau chunks
## (mesas) standing out of the lowland; the valleys cut through the plateaus
## as canyons, where the aqueducts can span from rim to rim. Rivers, coast and
## sea as wilderness's. Every key here is an existing recipe key
## (LandField.recipe_defaults, V3_KEYS): no native change.
## (docs/design/endless-flight/amberlands-round1-handoff.md)

const Field = preload("res://scripts/endless/land_field.gd")

static func recipe() -> Dictionary:
	var land := Field.recipe_defaults()
	land.merge({"mountains":1.0,"peaks":1.0,"valleys":1.0,"carve":1.0,"carve_blocks":1.0,"carve_ledges":1.0,"carve_gullies":1.0,
		"rivers":1.0,"river_width":1.0,"river_drop":1.0,"river_cut":1.0,"river_fill":1.0,"river_mouth":1.0,"river_flare":1.0,"ponds":0.6},true)
	land.merge({
		# A broad interior: the continents lifted, so less of it is sea.
		"continent_lift":28.0,
		# Broad, low swells: longer hills than wilderness's, no taller.
		"hill_scale":620.0,
		"hill_tall":16.0,
		# Massifs: wide and bulky ranges (a broad massif under a softened
		# gable), in clusters with broad lowland between.
		"range_scale":3000.0,
		"range_width":0.26,
		"range_band":Vector2(-0.5,-0.15),
		"warp_move":320.0,
		"peak_tall":Vector2(90.0,190.0),
		"ridge_scale":1100.0,
		"ridge_crisp":0.35,
		"notch":0.35,
		"notch_scale":4200.0,
		"notch_width":Vector2(0.04,0.09),
		# Worn terraces over most of the hills: broad treads, short risers.
		"terrace":1.0,
		"terrace_step":7.0,
		"terrace_flat":0.74,
		"terrace_scale":1800.0,
		"terrace_band":Vector2(-0.45,-0.05),
		# Plateau chunks: tiered mesas, taller than overgrown's, in broad
		# fields of them.
		"mesa":1.0,
		"mesa_tall":70.0,
		"mesa_scale":1300.0,
		"mesa_level":0.10,
		"mesa_edge":0.03,
		"mesa_steps":3.0,
		"mesa_gap":0.07,
		"mesa_keep":0.1,
		"mesa_mask_scale":3200.0,
		"mesa_band":Vector2(-0.4,-0.05),
		# Shallow valleys: wide floors, gentle long sides.
		"valley_swing":Vector2(0.9,2.0),
		"valley_side":Vector2(420.0,160.0),
		# Meadows a little more often than wilderness's (the flats).
		"meadow_band":Vector2(-0.1,0.18),
		# No snow on the massifs.
		"snow":400.0,
	},true)
	return land
