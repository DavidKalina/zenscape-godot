extends RefCounted
## Gust fronts (docs/scenic/gust-fronts.md): the ambient air's events. Every
## so often a front of stronger air rolls across the plate along the wind. At
## any point it arrives fast, holds a moment and lets go slowly, and plants
## hit, overshoot and settle as it passes. Just before it comes the breeze
## goes quiet (`lull`). Its line is ragged and its strength patchy across it,
## so it reads as a gust cell crossing the land, not a wall.
##
## Published as zs_front_N_a (origin x, z, way x, z) and zs_front_N_b (age s,
## speed m/s, peak lean, half width m); `zs_front_at` in
## shaders/reference_wind.gdshaderinc reads them. `lean_at` is its CPU
## mirror: keep the two in step. The atmosphere (studies/atmosphere.gd) owns
## one, ages it on its wind clock and folds `lull` into zs_breeze.

const Disturbance = preload("res://scripts/disturbance.gd")

const SLOTS := 2
## Seconds between fronts at the default air; stronger air sends them sooner
## (`gap_for`).
const GAP := Vector2(12.0, 30.0)
## Metres a second a front runs, plus SPEED_AIR per unit of air.
const SPEED := Vector2(5.0, 7.5)
const SPEED_AIR := 3.0
## A front's peak lean, in zs_blow_at's units (1 lays a small plant over by
## about 45 degrees): power * (PEAK_BASE + PEAK_AIR * breeze air).
const PEAK_BASE := 0.3
const PEAK_AIR := 0.3
const POWER := Vector2(0.55, 1.0)
## Half width as a share of the plate's radius: some fronts cross a side of
## the plate, some all of it.
const WIDTH := Vector2(0.7, 1.6)
## The push at a point `tau` s after the front reached it: rises from
## ATTACK.x to ATTACK.y, holds HOLD s, then lets go over RELEASE s (e-folding).
## At the hit plants overshoot by OVERSHOOT, ringing at RING rad/s and dying
## at RING_DAMP per s.
const ATTACK := Vector2(-0.35, 0.25)
const HOLD := 0.5
const RELEASE := 2.2
const OVERSHOOT := 0.4
const RING := 6.0
const RING_DAMP := 2.4
## Metres the front's line wanders along the wind across its width.
const RAGGED := 8.0
## The quiet before: the breeze eases to LULL of itself over the LULL_LEAD s
## before a front reaches the plate's middle, and is back RECOVER s after.
const LULL := 0.75
const LULL_LEAD := 4.0
const RECOVER := 3.0
## How hard creatures feel a front, per unit of its power: fish dart and
## gulls lift for most, songbirds flush only for the strongest
## (life_notice.gd FISH_GUST, BIRD_GUST; songbirds.gd GUST_SHARE).
const NOTICE := 0.25
## Metres upwind of the plate's edge a front is born, so it rolls in.
const LEAD_IN := 6.0

var rng := RandomNumberGenerator.new()
## Tuning (`--fronts=` on the atmosphere): scales every front's lean.
var gain := 2.0
var center := Vector2.ZERO
var radius := 20.0
## Each slot: {} when free, else origin, way, age, speed, peak, half, power.
var fronts: Array[Dictionary] = []
var _wait := 0.0
## Fronts sent so far, for probes.
var sent := 0

func _init() -> void:
	rng.randomize()
	for i in range(SLOTS): fronts.append({})
	_wait = rng.randf_range(4.0, 10.0)

func set_bounds(middle: Vector2, reach: float) -> void:
	center = middle
	radius = maxf(reach, 4.0)

## Seconds to the next front at `air` (the eased dial): about GAP in default
## air, half that in a gale, a little longer when calm.
static func gap_for(air: float, pick: float) -> float:
	return lerpf(GAP.x, GAP.y, pick) / clampf(0.75 + 0.6 * air, 0.8, 2.2)

## Age the fronts `delta` s, retire spent ones and send the next when due.
## `way` is the wind's unit direction, `air` the eased dial, `breeze_air` the
## breeze's strength before its swells (Atmosphere.breeze_air).
func advance(delta: float, way: Vector2, air: float, breeze_air: float) -> void:
	for i in range(SLOTS):
		var f := fronts[i]
		if f.is_empty(): continue
		f.age = float(f.age) + delta
		if float(f.age) > _life(f): fronts[i] = {}
	_wait -= delta
	if _wait <= 0.0:
		# Born when it was due, not at the frame's end: the same at any rate.
		var late := -_wait
		_wait = gap_for(air, rng.randf()) - late
		var f := send(way, air, breeze_air)
		if not f.is_empty(): f.age = late

## Send a front now along `way`. Returns its record, or {} if both slots run.
func send(way: Vector2, air: float, breeze_air: float, power := -1.0) -> Dictionary:
	var slot := fronts.find({})
	if slot < 0: return {}
	var dir := way.normalized() if way.length_squared() > 0.000001 else Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x)
	var p := power if power >= 0.0 else rng.randf_range(POWER.x, POWER.y)
	var half := radius * rng.randf_range(WIDTH.x, WIDTH.y)
	var off := rng.randf_range(-0.5, 0.5) * radius
	var f := {
		"origin": center - dir * (radius + LEAD_IN) + side * off,
		"way": dir,
		"age": 0.0,
		"speed": rng.randf_range(SPEED.x, SPEED.y) + SPEED_AIR * air,
		"peak": p * (PEAK_BASE + PEAK_AIR * breeze_air) * gain,
		"half": half,
		"power": p,
	}
	fronts[slot] = f
	sent += 1
	_disturb(f)
	return f

## Seconds a front lives: across the plate and its ragged line, then let go.
func _life(f: Dictionary) -> float:
	return (2.0 * radius + LEAD_IN + RAGGED) / float(f.speed) + HOLD + 4.0 * RELEASE

## 0..1+: the push a front gives a point `tau` s after it reached it.
static func push(tau: float) -> float:
	var rise := smoothstep(ATTACK.x, ATTACK.y, tau)
	if rise <= 0.0: return 0.0
	var after := maxf(tau, 0.0)
	var hold := exp(-maxf(tau - HOLD, 0.0) / RELEASE)
	var ring := OVERSHOOT * exp(-RING_DAMP * after) * sin(RING * after)
	return rise * (hold + ring)

## The shaders' value noise (zs_noise), for the CPU mirror.
static func noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	return lerpf(lerpf(_hash(i), _hash(i + Vector2(1, 0)), f.x), lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), f.x), f.y)

static func _hash(p: Vector2) -> float:
	var v := sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453
	return v - floorf(v)

## One front's lean at plate point `p` (along its way), `lag` s behind the
## air there. Mirrors zs_front_one in shaders/reference_wind.gdshaderinc.
static func front_lean(f: Dictionary, p: Vector2, lag := 0.0) -> float:
	if f.is_empty(): return 0.0
	var dir: Vector2 = f.way
	var rel: Vector2 = p - (f.origin as Vector2)
	var across := rel.dot(Vector2(-dir.y, dir.x))
	var half := float(f.half)
	var lateral := 1.0 - smoothstep(0.55 * half, half, absf(across))
	if lateral <= 0.0: return 0.0
	var seed := _seed(f.origin)
	var ragged := (noise(Vector2(across * 0.06, seed)) - 0.5) * RAGGED
	var tau := float(f.age) - lag - (rel.dot(dir) + ragged) / float(f.speed)
	var cell := 0.35 + 0.65 * smoothstep(0.2, 0.75, noise(Vector2(across * 0.12 + 5.3, seed * 1.7)))
	return float(f.peak) * lateral * cell * push(tau)

## Every front's lean at `p`, along the wind `way` (fronts at an angle to it
## give their share along it).
func lean_at(p: Vector2, way: Vector2, lag := 0.0) -> float:
	var total := 0.0
	for f in fronts:
		if f.is_empty(): continue
		total += front_lean(f, p, lag) * (f.way as Vector2).dot(way)
	return total

## A small seed from the origin, as the shader takes it (fract of a hash).
static func _seed(origin: Vector2) -> float:
	var v := origin.dot(Vector2(0.137, 0.291)) * 7.31
	return (v - floorf(v)) * 40.0

## 0..1: how much of the breeze is left in the quiet before a front.
func lull() -> float:
	var left := 1.0
	for f in fronts:
		if f.is_empty(): continue
		var dir: Vector2 = f.way
		var at := float(f.age) - (center - (f.origin as Vector2)).dot(dir) / float(f.speed)
		var quiet := smoothstep(-LULL_LEAD, -1.0, at) * (1.0 - smoothstep(-0.5, RECOVER, at))
		left = minf(left, 1.0 - (1.0 - LULL) * quiet)
	return left

func publish() -> void:
	for i in range(SLOTS):
		var f := fronts[i]
		var a := Vector4.ZERO
		var b := Vector4.ZERO
		if not f.is_empty():
			var o: Vector2 = f.origin
			var w: Vector2 = f.way
			a = Vector4(o.x, o.y, w.x, w.y)
			b = Vector4(float(f.age), float(f.speed), float(f.peak), float(f.half))
		RenderingServer.global_shader_parameter_set("zs_front_%d_a" % i, a)
		RenderingServer.global_shader_parameter_set("zs_front_%d_b" % i, b)

## Creatures hear a front as a gust running the plate at its own steady pace
## (scripts/disturbance.gd; `steady` tells readers the head does not ease).
func _disturb(f: Dictionary) -> void:
	var o: Vector2 = f.origin
	var w: Vector2 = f.way
	var span := 2.0 * radius + LEAD_IN
	Disturbance.raise(Vector3(o.x, 0.0, o.y), span, float(f.power) * NOTICE, "gust", {
		"shape": "lane", "way": Vector3(w.x, 0.0, w.y), "from": 0.0, "span": span,
		"run": span / float(f.speed), "wind_up": 0.0, "across": float(f.half), "steady": true})
