extends RefCounted
## The plane's pace presets (scripts/sky_plane.gd `pace_scale`, `use_pace`): how fast endless
## flight's plane goes. `speed` times its cruise, Boost, the cap a dive
## reaches and the surge (1.3 times Boost's); the slow end stays as it is:
## Brake's 13.2 m/s, the floor, the flaps, the landing and touchdown speeds,
## the takeoff, and the landing's 16 m/s grade. So a hand landing comes in as
## ever, at any pace.
##
## The held turn keeps its rate (2.08 rad/s): the radius grows with the
## speed, the roll and its timing in the hand stay the same.
##
## What reads the pace besides the plane:
## - the near misses (scripts/endless/near_miss.gd): the closing rate's
##   reference and the pull-out's least closing are times `speed`, so a dive
##   at the same angle grades the same at any pace;
## - the low zone (SkyPlane `_low_zone`): the hands-off settling nose is over
##   `speed`, so it sinks as many m/s at any pace;
## - the chase camera (scripts/glide_camera.gd `cruise`) and the sound
##   (scripts/endless/flight_sound.gd) read the speed against today's cruise
##   (the plane's cruise over its `pace_scale`), so faster looks and sounds faster.
##
## `--pace=<today|brisk|fast>` picks one at launch (a number, e.g.
## `--pace=1.75`, flies at that multiple); endless flight starts on DEFAULT
## and cycles them with P or the pad's d-pad right.

const NAMES: Array[String] = ["today","brisk","fast"]
const DEFAULT := "brisk"

const PRESETS := {
	"today":{"speed":1.0},
	"brisk":{"speed":1.25},
	"fast":{"speed":1.5},
}

## The preset's speed multiple by name (an unknown name: a number in it, else
## today's 1).
static func speed(preset: String) -> float:
	if PRESETS.has(preset): return float(PRESETS[preset].speed)
	if preset.is_valid_float(): return clampf(float(preset),0.5,3.0)
	return 1.0

## The preset after `preset`, round the list (a number goes to the first).
static func next(preset: String) -> String:
	var i := NAMES.find(preset)
	return NAMES[(i+1)%NAMES.size()]

## `--pace=<name or number>` from the launch flags, else `otherwise`.
static func flag(otherwise := DEFAULT) -> String:
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--pace="):
			var name := arg.substr(7)
			if name in NAMES or name.is_valid_float(): return name
			push_warning("--pace=%s: not one of %s or a number" % [name,NAMES])
	return otherwise
