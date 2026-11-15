extends RefCounted
## Seasons: a paint laid over a green world's own (wilderness's), picked
## at launch with --season=<id>. No flag (or --season=summer): nothing
## changes, the world's paint as it is. A season is one entry in SEASONS:
##   flora   keys over the world's flora (flowers...)
##   paint   keys over the world's paint, a level deep: ground (endless_ground
##           uniforms), far (the far tuft ring's), silver_colour (the grass's
##           bowed undersides), globals (shader globals set after the season
##           reset: zs_autumn turns the tufts and broadleaf crowns, conifers
##           excepted by their own leaf_season).
## The ground paint and the far ring read no season globals, so their
## tones are set here by hand to meet the near tufts' turn.

const LaunchArgs = preload("res://scripts/launch_args.gd")

const SEASONS := {
	"fall":{
		# A thin late bloom: the drifts' flowers off under the turned woods.
		"flora":{"flowers":false},
		"paint":{
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
	for k: String in over:
		if over[k] is Dictionary and paint.get(k) is Dictionary:
			(paint[k] as Dictionary).merge(over[k],true)
		else:
			paint[k] = over[k]
