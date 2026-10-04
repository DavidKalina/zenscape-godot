class_name WorldClock
extends RefCounted
## The world's single source of truth for time. Pure data, deterministic: the
## same captured state plus the same sequence of deltas always produces the same
## day, hour and phase. No RNG, no wall-clock reads, no nodes.
##
## `hour` is honest clock time and always advances at a constant rate, so a world
## day of `day_length` real seconds is `day_length` real seconds long whatever
## the sun is doing. The sunrise/sunset "linger" therefore lives here, in the
## hour -> phase mapping (`phase_for_hour`), instead of in the celestial rig: the
## sun slows through golden hour and the afterglow (`linger`) and hurries at
## midday, but the clock's hands do not. The linger is a function of sun height,
## so it is symmetric about phases 0.25 and 0.75, and the day's half weighs what
## the night's does (NOON_HASTE), so the quarter days are fixed points of the
## mapping (hour 0/6/12/18 <-> phase 0.0/0.25/0.5/0.75): the sun still rises at
## 6:00 and sets at 18:00, and an authored phase shows the same sun as ever.

const MAX_DELTA := 1.0             ## A stalled frame must not skip a day.
const DEFAULT_DAY_LENGTH := 480.0  ## Real seconds per world day at speed 1.0.
const HOURS_PER_DAY := 24.0
const SECONDS_PER_DAY := 86400.0
const MAX_DAY := 1000000
const YEAR_DAYS := 28              ## Default year: four seven-day seasons.
const MIN_YEAR_DAYS := 1           ## A one-day year is silly but legal; zero is not.
const MAX_YEAR_DAYS := 100000
const SEASON_NAMES := ["spring", "summer", "autumn", "winter"]
const SKIP_RESPONSE := 1.6         ## Easing rate of skip_to, from celestial.next_hour.
const SKIP_SNAP := 0.024           ## Hours; the old 0.001-of-a-turn snap.
## The sun heights the sun lingers through: the slow band comes in over x..y
## below the horizon (the afterglow's end) and goes out over z..w above it
## (golden hour's start). Inside it the sun turns at (1 - depth) rate.
const LINGER_E := Vector4(-0.22, -0.12, 0.28, 0.42)
## The depth with the sun up (golden hour) and down (the afterglow), blended
## over +-LINGER_SIDE_E of the horizon. At 480 s a day, golden hour (sun
## 0.03..0.28 high) lasts ~62 real seconds, was 30; the afterglow (sun 0 to
## -0.10) ~33, was 16. Sunrise mirrors it.
const LINGER_DEPTH_UP := 0.72
const LINGER_DEPTH_DOWN := 0.8
const LINGER_SIDE_E := 0.05
## The high sun hurries by this share more (from NOON_HASTE_E.x to .y of sun
## height) to pay for golden hour, which lies all on the day's side. Sized so
## the day's half takes exactly the night's twelve hours: the sun still rises
## at 6:00 and sets at 18:00. Full day (sun above 0.28) is ~100 s, was 169;
## night (below -0.2) ~133 s, was 185.
const NOON_HASTE := 0.667
const NOON_HASTE_E := Vector2(0.3, 0.6)
const WARP_STEPS := 4096           ## Fine enough that the pace never steps (<3% a sample).

var day := 0          ## Whole days elapsed, starts 0.
var hour := 0.0       ## 0.0 ..< 24.0, fractional.
var phase := 0.0      ## 0..1, the celestial rig's phase for this hour.
var daylight := 1.0   ## 0..1, mirrors what celestial publishes as zs_daylight.
var speed := 1.0      ## Multiplier; 0 is allowed and simply stops the hands.
var running := true   ## false freezes time (this is celestial's old `cycling`). On by default: the pond, the weather and the bed all live on world time.
var day_length := DEFAULT_DAY_LENGTH
var elapsed := 0.0    ## Total world seconds, day * 86400 + hour * 3600.
var target_hour := -1.0  ## Smooth skip destination; < 0 when idle.
## Pins the season for scrubbing and tests. Any value >= 0 wins over the
## calendar; -1 (the default) hands the year back to `day`.
var season_override := -1.0
## How many world days a year lasts. A knob, not a constant, so a garden can run
## a long calendar or a test can walk a year in a handful of days; it rides along
## in `capture()`. Everything that draws a year — the season scalar, the editor's
## Day scrubber — reads this, never YEAR_DAYS.
var year_days := YEAR_DAYS:
	set(value):
		year_days = clampi(value, MIN_YEAR_DAYS, MAX_YEAR_DAYS)

## Where the world stands in its year, 0..1. 0 opens the calendar, 0.25/0.5/0.75
## are the season boundaries. Read-only: move `day` or set `season_override`.
var season: float:
	get: return clampf(season_override, 0.0, 1.0) if season_override >= 0.0 else calendar_season()

func _init(starting_phase := 0.35) -> void:
	set_phase(starting_phase)

# ------------------------------------------------------------------- advancing

func advance(delta: float, paused: bool) -> void:
	if paused or not is_finite(delta) or delta <= 0.0:
		_sync()
		return
	var step := minf(delta, MAX_DELTA)
	if target_hour >= 0.0:
		var gap := fposmod(target_hour - hour, HOURS_PER_DAY)
		if gap <= SKIP_SNAP:
			_add_hours(gap)
			hour = target_hour
			target_hour = -1.0
		else:
			_add_hours(gap * (1.0 - exp(-step * SKIP_RESPONSE)))
	elif running and speed > 0.0 and day_length > 0.0:
		_add_hours(step * speed * HOURS_PER_DAY / day_length)
	_sync()

func set_time(new_day: int, new_hour: float) -> void:
	day = clampi(new_day, 0, MAX_DAY)
	hour = fposmod(new_hour, HOURS_PER_DAY) if is_finite(new_hour) else 0.0
	target_hour = -1.0
	_sync()

## Ease toward this hour the way pressing N always has: fast at first, settling
## onto the target. Always travels forward, so `elapsed` stays monotonic.
func skip_to(new_hour: float) -> void:
	if not is_finite(new_hour): return
	target_hour = fposmod(new_hour, HOURS_PER_DAY)

## Jump to the hour that renders as this celestial phase, keeping the day.
func set_phase(value: float) -> void:
	set_time(day, hour_for_phase(value))

## The season the calendar alone says it is, ignoring any override.
func calendar_season() -> float:
	var length := float(clampi(year_days, MIN_YEAR_DAYS, MAX_YEAR_DAYS))
	return fposmod(float(day) + hour / HOURS_PER_DAY, length) / length

## Which quarter of the year it is, as a watcher would name it.
func season_name() -> String:
	return name_for_season(season)

static func name_for_season(value: float) -> String:
	if not is_finite(value): return SEASON_NAMES[0]
	return str(SEASON_NAMES[clampi(int(fposmod(value, 1.0) * 4.0), 0, 3)])

## A rate multiplier for the time of year: [spring, summer, autumn, winter].
##
## Each number is the multiplier at the *opening* of its season. The value holds
## flat through the first half of that season and then eases into the next over
## the second half, so the year has four recognisable plateaus joined by smooth
## shoulders and — the point of the arrangement — season 0.0 is exactly
## `shape[0]`. Winter has climbed all the way back before the year wraps, the
## same convention the ground's gold and cold bumps follow, so day 0 of a fresh
## garden behaves exactly as it did before there was a calendar and no consumer
## sees a step at new year.
##
## Pure and static: the fish restock rate calls it, and dead wood can call it
## with its own four numbers. A malformed shape reads as 1.0, so a caller that
## loses its constants keeps the neutral rate.
static func season_factor(value: float, shape: Array) -> float:
	if shape.size() != 4 or not is_finite(value): return 1.0
	var year := fposmod(value, 1.0)
	var quarter := clampi(int(year * 4.0), 0, 3)
	var within := year * 4.0 - float(quarter)          ## 0..1 inside this season.
	var from: Variant = shape[quarter]
	var to: Variant = shape[(quarter + 1) % 4]
	if not (from is float or from is int) or not (to is float or to is int): return 1.0
	if not is_finite(float(from)) or not is_finite(float(to)): return 1.0
	return lerpf(float(from), float(to), smoothstep(0.5, 1.0, within))

func label() -> String:
	return "Day %d · %02d:%02d" % [day, int(hour) % 24, int(hour * 60.0) % 60]

# ----------------------------------------------------------------- persistence

func capture() -> Dictionary:
	return {
		"day": day,
		"hour": hour,
		"speed": speed,
		"running": running,
		"day_length": day_length,
		"target": target_hour,
		"season_override": season_override,
		"year_days": year_days,
	}

func restore(value: Dictionary) -> void:
	if value == null: return
	speed = _number(value.get("speed"), 1.0, 0.0, 10000.0)
	day_length = maxf(0.0, _number(value.get("day_length"), DEFAULT_DAY_LENGTH, 0.0, 1e9))
	running = bool(value.get("running", true))
	season_override = _number(value.get("season_override"), -1.0, -1.0, 1.0)
	year_days = int(_number(value.get("year_days"), float(YEAR_DAYS), float(MIN_YEAR_DAYS), float(MAX_YEAR_DAYS)))
	var wanted: float = _number(value.get("target"), -1.0, -1.0, HOURS_PER_DAY)
	set_time(int(_number(value.get("day"), 0.0, 0.0, float(MAX_DAY))), _number(value.get("hour"), 0.0, 0.0, HOURS_PER_DAY))
	if wanted >= 0.0: target_hour = fposmod(wanted, HOURS_PER_DAY)

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not _finite(value.get("day"), 0.0, float(MAX_DAY)): return false
	if not _finite(value.get("hour"), 0.0, HOURS_PER_DAY): return false
	if not _finite(value.get("speed"), 0.0, 10000.0): return false
	if not _finite(value.get("day_length"), 0.0, 1e9): return false
	if not _finite(value.get("target"), -1.0, HOURS_PER_DAY): return false
	# Written by later saves only: a document without one simply follows the calendar.
	if not _finite(value.get("season_override", -1.0), -1.0, 1.0): return false
	if not _finite(value.get("year_days", YEAR_DAYS), float(MIN_YEAR_DAYS), float(MAX_YEAR_DAYS)): return false
	return value.get("running") is bool

# ------------------------------------------------------------- phase mapping

## Sun elevation of the celestial ring at this phase, matching celestial.gd.
static func elevation_for_phase(value: float) -> float:
	return sin((value - 0.25) * TAU) * cos(_tilt())

static func daylight_for_phase(value: float) -> float:
	return smoothstep(-0.06, 0.28, elevation_for_phase(value))

## The relative rate the sun ring turns at this phase: slow through golden
## hour and the afterglow, quick at midday. Smooth in sun height (smoothsteps
## all through), so the sun never visibly changes pace.
static func linger(value: float) -> float:
	var e := elevation_for_phase(value)
	var depth := lerpf(LINGER_DEPTH_DOWN, LINGER_DEPTH_UP, smoothstep(-LINGER_SIDE_E, LINGER_SIDE_E, e))
	var band := smoothstep(LINGER_E.x, LINGER_E.y, e) * smoothstep(LINGER_E.w, LINGER_E.z, e)
	return (1.0 - depth * band) * (1.0 + NOON_HASTE * smoothstep(NOON_HASTE_E.x, NOON_HASTE_E.y, e))

static func phase_for_hour(value: float) -> float:
	var table := _warp_table()
	var u := fposmod(value, HOURS_PER_DAY) / HOURS_PER_DAY
	var low := 0
	var high := WARP_STEPS
	while high - low > 1:
		var middle := (low + high) / 2
		if table[middle] <= u: low = middle
		else: high = middle
	var span: float = table[high] - table[low]
	var fraction: float = 0.0 if span <= 0.0 else clampf((u - table[low]) / span, 0.0, 1.0)
	return clampf((float(low) + fraction) / float(WARP_STEPS), 0.0, 1.0)

static func hour_for_phase(value: float) -> float:
	var table := _warp_table()
	var x := fposmod(value, 1.0) * float(WARP_STEPS)
	var index := clampi(int(floor(x)), 0, WARP_STEPS - 1)
	var fraction := x - float(index)
	return lerpf(table[index], table[index + 1], fraction) * HOURS_PER_DAY

# ---------------------------------------------------------------- internals

func _add_hours(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0: return
	hour += amount
	while hour >= HOURS_PER_DAY:
		hour -= HOURS_PER_DAY
		day = mini(day + 1, MAX_DAY)

func _sync() -> void:
	hour = fposmod(hour, HOURS_PER_DAY) if is_finite(hour) else 0.0
	phase = phase_for_hour(hour)
	daylight = daylight_for_phase(phase)
	elapsed = float(day) * SECONDS_PER_DAY + hour * 3600.0

static func _number(value: Variant, fallback: float, low: float, high: float) -> float:
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value), low, high)

static func _finite(value: Variant, low: float, high: float) -> bool:
	if not (value is float or value is int): return false
	var number := float(value)
	return is_finite(number) and number >= low and number <= high

## The celestial ring's tilt, derived exactly as celestial.setup does.
static func _tilt() -> float:
	var elevation := asin(14.0 / Vector3(20, 14, 12).length())
	return PI / 2.0 - clampf(elevation + 0.32, 0.7, 1.08)

## Cumulative, normalized clock-time for each phase sample: the integral of
## 1/linger. Inverting it turns an even hour into a lingering phase. Built once
## per run from constants only, so every run and every clock shares it.
static var _warp: PackedFloat64Array = PackedFloat64Array()

static func _warp_table() -> PackedFloat64Array:
	if _warp.size() == WARP_STEPS + 1: return _warp
	var table := PackedFloat64Array()
	table.resize(WARP_STEPS + 1)
	var previous := 1.0 / linger(0.0)
	var total := 0.0
	table[0] = 0.0
	for i in range(1, WARP_STEPS + 1):
		var current := 1.0 / linger(float(i) / float(WARP_STEPS))
		total += (previous + current) * 0.5 / float(WARP_STEPS)
		table[i] = total
		previous = current
	for i in range(WARP_STEPS + 1): table[i] = table[i] / total
	table[WARP_STEPS] = 1.0
	_warp = table
	return _warp
