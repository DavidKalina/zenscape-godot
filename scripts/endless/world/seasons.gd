extends RefCounted
## Seasons: a paint laid over a green world's own (wilderness's), picked
## at launch with --season=<id>. No flag (or --season=summer): nothing
## changes, the world's paint as it is. A season is one entry in SEASONS:
##   flora   keys over the world's flora (flowers...)
##   paint   keys over the world's paint, a level deep: mood and hour (the
##           look's preset, SceneLookPresets, and the opening hour; the sun's
##           compass stays the world's, paint.ring_hour), sea (endless_sea
##           uniforms; the rivers and ponds copy its tints), ground
##           (endless_ground uniforms), far (the far tuft ring's),
##           silver_colour (the grass's bowed undersides), globals (shader
##           globals set after the season reset: zs_autumn turns the tufts and
##           broadleaf crowns, conifers excepted by their own leaf_season).
## The ground paint and the far ring read no season globals, so their
## tones are set here by hand to meet the near tufts' turn.

const LaunchArgs = preload("res://scripts/launch_args.gd")

const SEASONS := {
	"fall":{
		# Past the bloom: the drifts' flowers off.
		"flora":{"flowers":false},
		"paint":{
			# The light: a crisp day under a warm sun, a pale sky going to a warm
			# haze (SceneLookPresets fall_day), opening mid-afternoon with the sun
			# low and the shadows long (the day cycle runs on from there).
			"mood":"fall_day","hour":15.6,
			# The water: cool steel blue-green, darker, the sandy bed seen less
			# far down (the rivers and ponds copy these: EndlessLook._river_water).
			"sea":{"tint_shallow":Color(0.26,0.40,0.41),"tint_mid":Color(0.10,0.26,0.33),"tint_deep":Color(0.05,0.16,0.23),
				"tint_abyss":Color(0.03,0.09,0.15),"sss_color":Vector3(0.22,0.42,0.40),"absorb":Vector3(0.40,0.14,0.11),"bed_fade":2.5,"water_light":2.3},
			# The painted turf past the tufts: the meadow's green given way to
			# a russet-gold at its own light (carpet_hue), warmer from above.
			"ground":{"carpet_hue":Vector3(1.30,0.62,0.24),
				"carpet_tone_top":Vector3(1.0,0.84,0.68),"carpet_tone_low":Vector3(0.98,0.84,0.70),
				"carpet_under_tone":Vector3(1.0,0.84,0.66)},
			# The far tuft ring: rust at the root, ochre tips.
			"far":{"root_colour":Vector3(0.16,0.09,0.04),"tip_colour":Vector3(0.52,0.36,0.14)},
			# The bowed undersides: pale straw, not summer's sage.
			"silver_colour":Vector3(0.78,0.64,0.44),
			"globals":{"zs_autumn":1.0,"zs_season":Vector4(0.0,0.0,0.0,0.7)}}},
}

## The season --season= names ("" for none, or an unknown one, which warns).
static func wanted() -> String:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--season="):
			var s := a.get_slice("=",1)
			if s == "" or s == "summer": return ""
			if SEASONS.has(s): return s
			push_error("no season '%s'; the seasons: summer, %s." % [s,", ".join(PackedStringArray(SEASONS.keys()))])
	return ""

## Lays the wanted season over a world's flora and paint (in place).
static func apply(flora: Dictionary, paint: Dictionary) -> void:
	var s := wanted()
	if s == "": return
	var entry: Dictionary = SEASONS[s]
	flora.merge(entry.get("flora",{}),true)
	var over: Dictionary = entry.get("paint",{})
	# The sun's ring keeps the world's turn (EndlessLook.turn_ring_to stands it
	# by the opening hour): a season's own hour moves the clock, not the compass.
	if over.has("hour") and paint.has("hour") and not paint.has("ring_hour"): paint["ring_hour"] = paint["hour"]
	for k: String in over:
		if over[k] is Dictionary and paint.get(k) is Dictionary:
			(paint[k] as Dictionary).merge(over[k],true)
		else:
			paint[k] = over[k]
