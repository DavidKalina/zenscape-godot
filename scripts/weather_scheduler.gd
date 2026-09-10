class_name WeatherScheduler
extends RefCounted
## Pure-data weather drift. Decides which precipitation preset the sky should
## wear as world time passes, and when the next change is due.
##
## The scheduler owns no nodes and reads no globals: feed it an absolute world
## hour (day * 24 + hour) and it hands back the presets that fired. See
## docs/weather-scheduler/README.md for the transition table and the wiring.

## Mirror of studies/precipitation.gd PRESET_NAMES. tests/test_weather_scheduler.gd
## asserts the two lists stay identical.
const PRESET_NAMES := ["clear", "rain", "storm", "snow", "fair", "overcast", "mist", "autumn"]

## Base transition weights at season 0. A preset never transitions to itself.
const TABLE := {
	"clear": {"fair": 0.55, "overcast": 0.30, "mist": 0.15},
	"fair": {"clear": 0.40, "overcast": 0.40, "rain": 0.20, "autumn": 0.30},
	"overcast": {"rain": 0.40, "fair": 0.30, "clear": 0.15, "mist": 0.15, "snow": 0.35, "autumn": 0.35},
	"rain": {"overcast": 0.45, "storm": 0.25, "fair": 0.20, "mist": 0.10, "snow": 0.20},
	"storm": {"rain": 0.50, "overcast": 0.40, "fair": 0.10},
	"mist": {"clear": 0.40, "fair": 0.30, "overcast": 0.30, "snow": 0.15},
	"snow": {"overcast": 0.50, "clear": 0.20, "fair": 0.15, "mist": 0.15},
	"autumn": {"overcast": 0.40, "fair": 0.25, "rain": 0.25, "clear": 0.10},
}

## Dwell time per preset, in world hours: [minimum, maximum].
const DWELL := {
	"clear": [5.0, 12.0],
	"fair": [6.0, 18.0],
	"overcast": [4.0, 10.0],
	"rain": [2.0, 6.0],
	"storm": [1.0, 3.0],
	"mist": [1.0, 3.0],
	"snow": [3.0, 8.0],
	"autumn": [6.0, 14.0],
}

## Presets that only exist when the season is cold or already wintry.
const COLD_PRESETS := ["snow"]
## Presets the season alone can summon; never rolled at season 0.
const SEASON_PRESETS := ["autumn"]
## Most transitions a single advance() call may fire before it gives up and
## re-anchors the schedule to the requested hour.
const MAX_CATCH_UP := 24
## History entries kept.
const HISTORY_LIMIT := 32

var seed: int = 0
var enabled := true
var current := "clear"
var next_change_hour := 0.0
var season := 0.0
var history: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _last_hour := 0.0

func _init(p_seed := 0, p_current := "clear", p_start_hour := 0.0) -> void:
	seed = p_seed
	_rng.seed = p_seed
	current = p_current if TABLE.has(p_current) else "clear"
	_last_hour = p_start_hour
	next_change_hour = p_start_hour + _roll_dwell(current)

## Index into studies/precipitation.gd PRESET_NAMES; -1 when unknown.
static func preset_index(name: String) -> int:
	return PRESET_NAMES.find(name)

## Advance world time. Returns the preset names that became current since the
## last call, oldest first. Calling twice with the same hour returns [] the
## second time. Hours that move backwards are ignored.
func advance(world_hour_abs: float) -> Array[String]:
	var fired: Array[String] = []
	if not enabled:
		_last_hour = maxf(_last_hour, world_hour_abs)
		return fired
	var now := maxf(world_hour_abs, _last_hour)
	_last_hour = now
	while now >= next_change_hour:
		if fired.size() >= MAX_CATCH_UP:
			# Too far behind (a huge fast-forward). Re-anchor rather than spin.
			next_change_hour = now + _roll_dwell(current)
			break
		var at := next_change_hour
		var chosen := _pick(current, fposmod(at, 24.0))
		history.append({"hour": at, "from": current, "to": chosen})
		while history.size() > HISTORY_LIMIT:
			history.remove_at(0)
		current = chosen
		fired.append(chosen)
		next_change_hour = at + _roll_dwell(chosen)
	return fired

## Player override from the weather dropdown. Reschedules the next drift.
func set_current(name: String, world_hour_abs: float) -> void:
	if not TABLE.has(name):
		return
	_last_hour = maxf(_last_hour, world_hour_abs)
	if name != current:
		history.append({"hour": world_hour_abs, "from": current, "to": name})
		while history.size() > HISTORY_LIMIT:
			history.remove_at(0)
	current = name
	next_change_hour = world_hour_abs + _roll_dwell(name)

func capture() -> Dictionary:
	return {
		"seed": seed,
		"enabled": enabled,
		"current": current,
		"next_change_hour": next_change_hour,
		"season": season,
		"rng_state": str(_rng.state),
		"last_hour": _last_hour,
		"history": history.duplicate(true),
	}

func restore(value: Dictionary) -> void:
	seed = int(value.get("seed", seed))
	_rng.seed = seed
	enabled = bool(value.get("enabled", enabled))
	var name := str(value.get("current", current))
	current = name if TABLE.has(name) else current
	next_change_hour = float(value.get("next_change_hour", next_change_hour))
	season = float(value.get("season", season))
	_last_hour = float(value.get("last_hour", _last_hour))
	if value.has("rng_state"):
		_rng.state = int(str(value["rng_state"]).to_int())
	history.clear()
	for entry in value.get("history", []):
		history.append({
			"hour": float(entry.get("hour", 0.0)),
			"from": str(entry.get("from", "")),
			"to": str(entry.get("to", "")),
		})

func _roll_dwell(name: String) -> float:
	var span: Array = DWELL.get(name, [4.0, 8.0])
	return _rng.randf_range(float(span[0]), float(span[1]))

## Weighted draw over the table row for [param from], shaped by hour of day and
## season. Always returns a valid preset name.
func _pick(from: String, hour_of_day: float) -> String:
	var row: Dictionary = TABLE.get(from, TABLE["clear"])
	var names: Array = []
	var weights: Array = []
	var total := 0.0
	for name in row:
		var weight := float(row[name]) * _season_factor(name, from) * _hour_factor(name, from, hour_of_day)
		if weight <= 0.0:
			continue
		names.append(name)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return "fair" if from != "fair" else "clear"
	var roll := _rng.randf() * total
	for i in range(names.size()):
		roll -= float(weights[i])
		if roll <= 0.0:
			return str(names[i])
	return str(names[names.size() - 1])

## Season 0 reproduces the neutral table exactly: every factor here is 1.0 at
## season 0 except the gated cold/season presets, which are 0.
func _season_factor(name: String, from: String) -> float:
	if name in COLD_PRESETS:
		var cold := clampf((season - 0.6) / 0.25, 0.0, 1.0)
		if from == "snow" or current == "snow":
			cold = maxf(cold, 0.5)
		return cold * 3.0
	if name in SEASON_PRESETS:
		return clampf((season - 0.55) / 0.25, 0.0, 1.0) * 2.0
	if name == "overcast":
		return 1.0 + 1.5 * clampf((season - 0.6) / 0.4, 0.0, 1.0)
	if name == "clear" or name == "fair":
		# High season damps the bright presets, so season < 0.3 is where
		# clear/fair dominate. Exactly 1.0 at season 0.
		return 1.0 - 0.5 * clampf((season - 0.3) / 0.7, 0.0, 1.0)
	return 1.0

## Time-of-day shaping: afternoon storms, dawn mist after rain, evening clearing.
func _hour_factor(name: String, from: String, hour_of_day: float) -> float:
	match name:
		"storm":
			if hour_of_day >= 13.0 and hour_of_day < 19.0:
				return 2.5
			if hour_of_day < 6.0 or hour_of_day >= 22.0:
				return 0.4
		"mist":
			if hour_of_day >= 4.0 and hour_of_day < 8.0:
				return 5.0 if (from == "rain" or from == "storm") else 1.5
			if hour_of_day >= 10.0 and hour_of_day < 16.0:
				return 0.2
		"clear":
			if hour_of_day >= 17.0 and hour_of_day < 22.0:
				return 1.8
		_:
			return 1.0
	return 1.0
