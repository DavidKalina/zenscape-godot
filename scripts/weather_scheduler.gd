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
## Off until someone asks for drift: a garden's sky stays where it was put.
var enabled := false
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

## How much gold and how much cold the season alone adds to the ground, on top
## of whatever the current preset asks for. Each is a plateau on the 0..1 year
## aligned to its calendar quarter: it rises over the first days of the season,
## holds, and falls away over the last. The cold reaches zero before the year
## wraps, so day 0 of a fresh garden is the neutral scene it has always been and
## the new year arrives without a step.
## [rise start, rise end, fall start, fall end, strength]; see docs/world-clock/README.md.
const SEASON_AUTUMN := [0.50, 0.56, 0.72, 0.80, 0.9]  ## Gold through the autumn quarter, gone by early winter.
const SEASON_COLD := [0.72, 0.80, 0.94, 1.00, 0.9]    ## Cold from the first winter days, thawing in the last.

static func season_autumn(season: float) -> float:
	return _season_plateau(season, SEASON_AUTUMN)

static func season_cold(season: float) -> float:
	return _season_plateau(season, SEASON_COLD)

## A symmetric bump, [centre, half width, strength]; the weather mix's quarter
## weights still use it.
static func _season_bump(season: float, shape: Array) -> float:
	if not is_finite(season): return 0.0
	var gap := absf(fposmod(season, 1.0) - float(shape[0]))
	return float(shape[2]) * (1.0 - smoothstep(0.0, float(shape[1]), minf(gap, 1.0 - gap)))

static func _season_plateau(season: float, shape: Array) -> float:
	if not is_finite(season): return 0.0
	var year := fposmod(season, 1.0)
	var rise := smoothstep(float(shape[0]), float(shape[1]), year)
	var fall := 1.0 - smoothstep(float(shape[2]), float(shape[3]), year)
	return float(shape[4]) * minf(rise, fall)

## Advance world time. Returns the preset names that became current since the
## last call, oldest first. Calling twice with the same hour returns [] the
## second time. Hours that move backwards are ignored.
func advance(world_hour_abs: float) -> Array[String]:
	var fired: Array[String] = []
	if not enabled:
		# Keep the schedule ahead of the clock so enabling later drifts from
		# now instead of replaying every change missed while off.
		_last_hour = maxf(_last_hour, world_hour_abs)
		if next_change_hour < _last_hour:
			next_change_hour = _last_hour + _roll_dwell(current)
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

## True when the current preset was reached directly from snow.
func _came_from_snow() -> bool:
	return not history.is_empty() and str(history.back().get("from", "")) == "snow"

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

## Quarter bumps used to give each season its own weather: zero at every season
## boundary, one at the middle of its own quarter. Because they vanish at the
## boundaries, season 0 reproduces the neutral table exactly (every factor here
## is 1.0 at season 0 except the gated cold/season presets, which are 0), and
## the year wraps without a step.
const QUARTER_SPRING := [0.125, 0.125, 1.0]
const QUARTER_SUMMER := [0.375, 0.125, 1.0]
const QUARTER_AUTUMN := [0.625, 0.125, 1.0]
const QUARTER_WINTER := [0.875, 0.125, 1.0]

## The mix each quarter wears, on top of the neutral table:
##
## | quarter | what the sky does |
## | spring 0.00–0.25 | showers and dawn mist: rain ×1.8, mist ×1.9 at peak |
## | summer 0.25–0.50 | bright, with afternoon thunder: clear/fair ×1.55, storm ×2.2 |
## | autumn 0.50–0.75 | gold and grey: the autumn preset unlocks, rain ×1.5, overcast climbs, clear/fair fade |
## | winter 0.75–1.00 | snow ×3 and overcast ×2.5; rain halves and storms nearly stop |
func _season_factor(name: String, from: String) -> float:
	var spring := _season_bump(season, QUARTER_SPRING)
	var summer := _season_bump(season, QUARTER_SUMMER)
	var autumn := _season_bump(season, QUARTER_AUTUMN)
	var winter := _season_bump(season, QUARTER_WINTER)
	if name in COLD_PRESETS:
		# Snow belongs to winter: nothing before the last days of autumn.
		var cold := clampf((season - 0.7) / 0.15, 0.0, 1.0)
		# Snow never follows itself, so "still wintry" means the sky we are
		# leaving came straight off snow: a marginal season can flurry back.
		if _came_from_snow():
			cold = maxf(cold, 0.5)
		return cold * 3.0
	if name in SEASON_PRESETS:
		# The gold sky arrives with autumn and thins once deep winter is in.
		var turning := clampf((season - 0.45) / 0.15, 0.0, 1.0)
		return 2.2 * turning * (1.0 - 0.75 * clampf((season - 0.8) / 0.15, 0.0, 1.0))
	if name == "overcast":
		return 1.0 + 1.5 * clampf((season - 0.6) / 0.4, 0.0, 1.0)
	if name == "clear" or name == "fair":
		# Summer is the bright quarter; the second half of the year damps them,
		# so clear/fair peak in midsummer and bottom out in winter.
		return 1.0 + 0.55 * summer - 0.45 * clampf((season - 0.5) / 0.25, 0.0, 1.0)
	if name == "rain":
		# Spring showers, a wet autumn, and a winter that snows instead.
		return 1.0 + 0.8 * spring + 0.2 * summer + 0.9 * autumn - 0.5 * winter
	if name == "storm":
		# Summer rains rarely, so its thunder has to be worth a lot when it does.
		return 1.0 + 3.0 * summer - 0.7 * winter
	if name == "mist":
		return 1.0 + 0.9 * spring + 0.4 * autumn
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
