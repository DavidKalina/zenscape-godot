extends RefCounted
## The amberlands' paint, flora and dressing layers
## (scripts/endless/world/profiles/amberlands.gd). No trees: tall grass gone
## to amber and straw over the whole land, under the amber hour (a low gold
## sun, warm dust in the air: EndlessLook mood "amber_hour"). Ruins all
## through it: aqueduct runs and ruined gates in the valleys, rim to rim
## across the canyons, slot halls through the massifs' crests, tunnels
## under them.

static func flora() -> Dictionary:
	return {"forest":0.0,"forest_meadows":0.0,"tree_weights":PackedFloat32Array(),"grass":1.15,"grass_tall":1.9,"flowers":false}

static func paint() -> Dictionary:
	return {"mood":"amber_hour","hour":16.2,
		# Hold the clock at the low sun when this world plays alone (T, --day
		# and --hour= still move it; a world of regions keeps its own clock).
		"still":true,
		# The grass: amber from afar, straw-gold near, dark honey at the root.
		"ground":{"carpet_tone_top":Vector3(3.6,1.08,0.38),"carpet_tone_low":Vector3(3.3,0.98,0.35),
			"carpet_under_tone":Vector3(2.9,0.80,0.27),"rock_moss":0.35,
			# The rock sun-bleached sandstone, its red pulled back.
			"rock_tint":Vector3(0.98,1.04,0.96)},
		"far":{"root_colour":Vector3(0.24,0.12,0.035),"tip_colour":Vector3(0.74,0.46,0.12)},
		# The undersides the wind bows into view: pale straw.
		"silver_colour":Vector3(0.88,0.74,0.48),
		# The water: a warm jade, never the alpine turquoise.
		"sea":{"tint_shallow":Color(0.48,0.74,0.62),"tint_mid":Color(0.16,0.46,0.48)},
		# The grass dry and gone gold (the season's ripening and autumn's
		# gold, with no tree to turn), the ruins' stone warmed.
		"globals":{"zs_autumn":0.8,"zs_season":Vector4(0.0,0.0,0.6,0.5)}}

static func layers() -> Dictionary:
	return {"trees":false,"grass":true,"birds":true,"fish":true,
		# Ruins: more tries per cell, the ruin kinds taken more often than the
		# natural rock arches, kept near the massifs and plateaus, and an
		# aqueduct across a canyon or between two shelves spans from rim to rim.
		"arches":1.8,"rock_arches":0.35,"ruin_arches":1.6,"ruin_near":700.0,"aqueduct_span":0.8,
		"halls":1.3,"tunnels":1.0,
		# No split mountains, sea stacks or hoodoos: wilderness's.
		"splits":0.0,"stacks":0.0,"hoodoos":0.0,"traffic":-1}
