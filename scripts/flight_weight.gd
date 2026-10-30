extends RefCounted
## The plane's weight presets (scripts/sky_plane.gd `use_weight`, the chase
## camera's lag in scripts/glide_camera.gd `use_weight`). `off` is the
## arcade flight as it was: the path with the nose, the bank eased in, the
## turn with the bank. The others give it mass, more each step:
##
## - roll: the bank answers a spring (`roll_hz`, radians a second, critically
##   damped), so the roll's rate builds and settles instead of snapping; the
##   turn's rate follows the bank over `turn_lag` s, a beat after the lean.
## - path: the way it travels bends after the nose, its heading over
##   `yaw_lag` s (a slip in a hard turn) and its climb over `pitch_lag` s (it
##   sinks through the bottom of a pull-out before it climbs), both at
##   cruise and longer slower (by cruise over speed, within LAG_SCALE).
##   The stick builds the pitch's rate over `pitch_build` s.
## - speed: pulling and turning bleed `bleed` m/s² a g past one (the path's
##   own bend, speed times its turn rate over G). Slow, under SOFT_SPAN m/s
##   over the floor with the flaps up, the stick keeps only `soft_keep` of
##   its rate and it mushes down `mush` m/s at the floor. A bank sinks it
##   `sag` m/s at a right angle (by 1 - cos of the bank).
## - camera: its idea of the flight's way and its roll follow `cam_lag`
##   times slower, the way is `cam_path` the path's (the rest the nose's), and
##   the field of view eases over `fov_ease` s.
## - low: under `low_spans` wingspans of clearance over whatever is under it
##   (the land, a tree, a ruin, the water) and fast (over LOW_SLOW m/s, full
##   by LOW_FAST of cruise), the nose stops easing level and eases to
##   `settle_pitch` instead, and the plane settles `settle` m/s toward the
##   land, both by how deep into the zone it is (0 at its top, 1 at
##   LOW_FULL spans, the square root of the share of the way down): hands off, it scrapes in a couple of seconds, and a
##   low line takes small steady corrections. A buffet of `buffet` m/s
##   shakes it up and down there, by the depth and the speed. Slow (a hand
##   landing's approach, a braked pass) none of this acts.
## - ceiling: in thin air (SkyPlane `use_thin`) the share of the thin band
##   it climbs through: its top is `ceiling` of the way from where the air
##   thins to the flight's top.
## - reach: the share of that band (up to its top) a flown climb gets
##   through: past it the flown climb fades to nothing over TOP_FALL of the
##   band, and only rising air (lift) carries it on to the top. With the
##   Peak's tarn at 1145 m over the sea: light flies up to it with room,
##   medium only just (its flown climb stops near 1175), heavy not (near
##   1100; it gets there by the couloir's lift).
##
## `--weight=<off|light|medium|heavy>` picks one at launch; endless flight
## starts on DEFAULT and cycles them with V or the pad's d-pad up.

const NAMES: Array[String] = ["off","light","medium","heavy"]
const DEFAULT := "medium"

const PRESETS := {
	"off":{"roll_hz":0.0,"turn_lag":0.0,"yaw_lag":0.0,"pitch_lag":0.0,"pitch_build":0.0,
		"bleed":0.0,"soft_keep":1.0,"mush":0.0,"sag":0.0,"cam_lag":1.0,"cam_path":0.5,"fov_ease":0.3,
		"low_spans":0.0,"settle":0.0,"settle_pitch":0.0,"buffet":0.0,"ceiling":1.0,"reach":1.0},
	"light":{"roll_hz":13.0,"turn_lag":0.04,"yaw_lag":0.05,"pitch_lag":0.18,"pitch_build":0.06,
		"bleed":0.3,"soft_keep":0.75,"mush":0.8,"sag":0.6,"cam_lag":1.25,"cam_path":0.56,"fov_ease":0.4,
		"low_spans":1.6,"settle":1.0,"settle_pitch":-0.06,"buffet":0.35,"ceiling":1.0,"reach":1.0},
	"medium":{"roll_hz":11.0,"turn_lag":0.06,"yaw_lag":0.08,"pitch_lag":0.3,"pitch_build":0.09,
		"bleed":0.6,"soft_keep":0.6,"mush":1.4,"sag":1.0,"cam_lag":1.5,"cam_path":0.62,"fov_ease":0.55,
		"low_spans":1.8,"settle":1.4,"settle_pitch":-0.09,"buffet":0.5,"ceiling":0.94,"reach":0.862},
	"heavy":{"roll_hz":7.0,"turn_lag":0.12,"yaw_lag":0.13,"pitch_lag":0.48,"pitch_build":0.15,
		"bleed":1.0,"soft_keep":0.45,"mush":2.2,"sag":1.8,"cam_lag":2.0,"cam_path":0.7,"fov_ease":0.8,
		"low_spans":2.0,"settle":1.8,"settle_pitch":-0.11,"buffet":0.65,"ceiling":0.85,"reach":0.879},
}

## The path's lag at a speed: times cruise over speed, within these.
const LAG_SCALE := Vector2(0.7,1.6)
## The soft band: this many m/s over the floor (SkyPlane SLOW) and under.
const SOFT_SPAN := 6.0
## The low zone is full this many wingspans over the land, acts only over
## LOW_SLOW m/s (a hand landing's approach and Brake's 13.2 stay under it)
## and is full from LOW_FAST of cruise.
const LOW_FULL := 0.25
const LOW_SLOW := 16.0
const LOW_FAST := 0.85
const G := 9.8

## The preset's knobs by name (an unknown name: off).
static func knobs(preset: String) -> Dictionary:
	return PRESETS.get(preset,PRESETS["off"])

## The preset after `preset`, round the list.
static func next(preset: String) -> String:
	return NAMES[(NAMES.find(preset)+1)%NAMES.size()]

## `--weight=<name>` from the launch flags, else `otherwise`.
static func flag(otherwise := "off") -> String:
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--weight="):
			var name := arg.substr(9)
			if name in NAMES: return name
			push_warning("--weight=%s: not one of %s" % [name,NAMES])
	return otherwise
