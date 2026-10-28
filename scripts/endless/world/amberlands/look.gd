extends RefCounted
## The amberlands' paint, flora and dressing layers
## (scripts/endless/world/profiles/amberlands.gd). No trees: tall grass gone
## to straw over the whole land, under the amber hour (a low, soft gold sun
## through a warm haze that greys the distance: EndlessLook mood "amber_hour"). Ruins all
## through it: aqueduct runs and ruined gates in the valleys, rim to rim
## across the canyons, slot halls through the massifs' crests, tunnels
## under them.

static func flora() -> Dictionary:
	return {"forest":0.0,"forest_meadows":0.0,"tree_weights":PackedFloat32Array(),"grass":1.15,"grass_tall":1.9,"flowers":false}

static func paint() -> Dictionary:
	return {"mood":"amber_hour","hour":16.7,
		# Hold the clock at the low sun when this world plays alone (T, --day
		# and --hour= still move it; a world of regions keeps its own clock).
		"still":true,
		# The grass: muted straw with an olive undertone from afar, so it reads
		# as grass and not sand; darker and greener at the root.
		"ground":{"carpet_tone_top":Vector3(1.04,0.89,0.86),"carpet_tone_low":Vector3(1.02,0.87,0.86),
			"carpet_under_tone":Vector3(1.0,0.88,0.84),
			# Most of the paint's own green gives way to straw at its own light,
			# the rest left as an olive undertone.
			"carpet_hue":Vector3(0.72,0.62,0.30),"rock_moss":0.6,
			# The rock weathered grey-beige: its hue mostly a grey one, its
			# warmth the sun's, not its own.
			"rock_hue":Vector3(0.88,0.80,0.68),"rock_tint":Vector3(0.76,0.75,0.72),"rock_rich":0.7,"rock_follow":0.65},
		"far":{"root_colour":Vector3(0.13,0.16,0.12),"tip_colour":Vector3(0.34,0.44,0.30)},
		# The undersides the wind bows into view: pale dry straw.
		"silver_colour":Vector3(0.66,0.62,0.48),
		# The water: a muted grey-green, never the alpine turquoise.
		"sea":{"tint_shallow":Color(0.46,0.60,0.50),"tint_mid":Color(0.17,0.32,0.29),"tint_deep":Color(0.08,0.17,0.19),"tint_abyss":Color(0.04,0.10,0.12)},
		# The near tufts gone dry to straw (the season's ripening), with none of
		# autumn's turn (it reads orange) and their green a little less red.
		"globals":{"zs_autumn":0.0,"zs_season":Vector4(0.0,0.0,0.8,0.5),"zs_palette_grass":Vector3(0.95,1.0,0.86)}}

static func layers() -> Dictionary:
	return {"trees":false,"grass":true,"birds":true,"fish":true,
		# Ruins: more tries per cell, the ruin kinds taken more often than the
		# natural rock arches, kept near the massifs and plateaus, and an
		# aqueduct across a canyon or between two shelves spans from rim to rim.
		"arches":1.8,"rock_arches":0.35,"ruin_arches":1.6,"ruin_near":700.0,"aqueduct_span":0.8,
		"halls":1.3,"tunnels":1.0,
		# No split mountains, sea stacks or hoodoos: wilderness's.
		"splits":0.0,"stacks":0.0,"hoodoos":0.0,"traffic":-1}
