extends RefCounted
## A wanderer's footprints, kept to be walked again (the footprint-replay
## buffer of the strange-city enemies: h2 the
## Second Walker walks it 8 s behind; h5 the Tithe-Taker at a leash in
## metres, h7 the Mirror Twin at no delay through a reflection).
##
## One trail follows one wanderer's motor (scripts/pilot_motor.gd), never
## "the player": whoever owns the trail picks which (co-op: the one who
## woke it). Each `record(delta)` keeps a sample of that motor as it stands
## after its step: the trail's clock `t` (s since the trail began), the
## path walked so far `s` (m, flat and up), the feet, where the figure is
## drawn (`draw`: the hang's origin on a ledge), the velocity and the
## facing, and the motor's state the figure (scripts/pilot_figure.gd)
## reads: grounded, skidding, move, hold, hold_t, shimmy, lip, swimming,
## lip_out, wade, wall_out, carving, knocks.
##
## Read back by time (`at_time`) or by path walked (`at_length`), each
## interpolated between the two samples round it (positions lerped, the
## facing by the short way, the states the earlier sample's), with the
## sample index it came from (`i`), so a reader can visit every footprint
## it passes (`since(i0, i1)`). `pose(puppet, sample)` sets a stand-in
## motor (a PilotMotor.new() that is never stepped) to the sample, so a
## PilotFigure drives off it and plays the wanderer's own clips.
##
## Samples older than `keep` s behind the newest are let go (a reader that
## lags further reads the oldest kept). Plain dictionaries in an Array,
## trimmed in chunks: a minute at 60 Hz is 3600 small dictionaries.
const PilotMotor = preload("res://scripts/pilot_motor.gd")

## Seconds kept behind the newest sample.
const KEEP := 30.0
## Samples dropped at once when trimming (an Array's front is costly to
## pop one at a time).
const TRIM_CHUNK := 120
## A held lip's footing is looked for this far in from its edge (m).
const LIP_IN := 0.15

## The motor followed (anything with a PilotMotor's fields).
var who: Object = null
var keep := KEEP
var samples: Array[Dictionary] = []
## The trail's clock (s since it began) and the path walked (m).
var clock := 0.0
var length := 0.0
## Samples let go so far (a reader's index minus this is its place in
## `samples`; `index` and `since` take absolute indices).
var dropped := 0

func _init(motor: Object = null, keep_s := KEEP) -> void:
	who = motor
	keep = keep_s

## Everything back to empty; following `motor` if given.
func clear(motor: Object = null) -> void:
	if motor != null: who = motor
	samples.clear()
	clock = 0.0
	length = 0.0
	dropped = 0

func is_empty() -> bool:
	return samples.is_empty()

## The followed motor sampled now, `delta` s after the last sample (the
## first sample is at t 0). Returns the sample.
func record(delta: float) -> Dictionary:
	if who == null: return {}
	if not samples.is_empty(): clock += delta
	var s := capture(who)
	return add(s)

## A sample (from `capture`, or made by hand) kept at the trail's clock.
func add(s: Dictionary) -> Dictionary:
	if not samples.is_empty():
		var last: Dictionary = samples[samples.size()-1]
		length += (s.feet as Vector3).distance_to(last.feet as Vector3)
	s["t"] = clock
	s["s"] = length
	samples.append(s)
	_trim()
	return s

## What the trail keeps of `m` (a PilotMotor) this frame.
static func capture(m: Object) -> Dictionary:
	var feet: Vector3 = m.feet
	var on_ledge: bool = String(m.hold) != ""
	return {
		"feet":feet,
		"draw":(m.origin() as Vector3) if on_ledge and m.has_method("origin") else feet,
		"vel":m.velocity,"facing":float(m.facing),
		"grounded":bool(m.grounded),"skidding":bool(m.skidding),"move":String(m.move),
		"hold":String(m.hold),"hold_t":float(m.hold_t),"shimmy":float(m.shimmy),"lip":m.lip,"lip_out":m.lip_out,
		"swimming":bool(m.swimming),"wade":float(m.wade),"wall_out":m.wall_out,
		"carving":float(m.carving),"knocks":int(m.knocks),
	}

func _trim() -> void:
	if samples.size() < TRIM_CHUNK*2: return
	var cut := clock-keep
	if float(samples[TRIM_CHUNK].t) >= cut: return
	samples = samples.slice(TRIM_CHUNK)
	dropped += TRIM_CHUNK

## The oldest and newest times kept.
func oldest_t() -> float:
	return float(samples[0].t) if not samples.is_empty() else 0.0

func newest_t() -> float:
	return clock

func newest() -> Dictionary:
	return samples[samples.size()-1] if not samples.is_empty() else {}

## The absolute index of the last sample at or before time `t` (clamped
## to the kept ones).
func index_at(t: float) -> int:
	return dropped+_find(t,"t")

## The sample at absolute index `i` (clamped), or {} if none kept.
func index(i: int) -> Dictionary:
	if samples.is_empty(): return {}
	return samples[clampi(i-dropped,0,samples.size()-1)]

## The samples with absolute indices in (i0, i1], oldest first.
func since(i0: int, i1: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(maxi(i0+1,dropped),mini(i1,dropped+samples.size()-1)+1): out.append(samples[i-dropped])
	return out

## The trail at time `t` (s on the trail's clock), interpolated.
func at_time(t: float) -> Dictionary:
	return _at(t,"t")

## The trail where `s` m of it had been walked, interpolated (a leash in
## metres: `at_length(length-leash)`).
func at_length(s: float) -> Dictionary:
	return _at(s,"s")

func _find(x: float, key: String) -> int:
	var lo := 0
	var hi := samples.size()-1
	if hi < 0: return 0
	if x <= float(samples[0][key]): return 0
	if x >= float(samples[hi][key]): return hi
	while hi-lo > 1:
		var mid := (lo+hi) >> 1
		if float(samples[mid][key]) <= x: lo = mid
		else: hi = mid
	return lo

func _at(x: float, key: String) -> Dictionary:
	if samples.is_empty(): return {}
	var k := _find(x,key)
	var a: Dictionary = samples[k]
	var out := a.duplicate()
	out["i"] = dropped+k
	if k+1 >= samples.size(): return out
	var b: Dictionary = samples[k+1]
	var span := float(b[key])-float(a[key])
	var u := clampf((x-float(a[key]))/span,0.0,1.0) if span > 1e-6 else 0.0
	for p: String in ["feet","draw","vel"]: out[p] = (a[p] as Vector3).lerp(b[p] as Vector3,u)
	out["facing"] = lerp_angle(float(a.facing),float(b.facing),u)
	out["t"] = lerpf(float(a.t),float(b.t),u)
	out["s"] = lerpf(float(a.s),float(b.s),u)
	# A hang's or a climb's place in its clip moves on smoothly too.
	if String(a.hold) == String(b.hold): out["hold_t"] = lerpf(float(a.hold_t),float(b.hold_t),u)
	return out

## `puppet` (a PilotMotor never stepped) set to `s`, for a PilotFigure to
## draw: its feet, pace, facing and state.
static func pose(puppet: Object, s: Dictionary) -> void:
	puppet.feet = s.feet
	puppet.velocity = s.vel
	puppet.facing = float(s.facing)
	puppet.grounded = bool(s.grounded)
	puppet.skidding = bool(s.skidding)
	puppet.move = String(s.move)
	puppet.hold = String(s.hold)
	puppet.hold_t = float(s.hold_t)
	puppet.shimmy = float(s.shimmy)
	puppet.lip = s.lip
	puppet.swimming = bool(s.swimming)
	puppet.wade = float(s.wade)
	puppet.wall_out = s.wall_out
	puppet.carving = float(s.carving)

## Whether a footprint stood on something: on the ground, not swimming,
## not riding a ledge (a hold's footing is its lip: see `footing`).
static func stood(s: Dictionary) -> bool:
	return bool(s.grounded) and not bool(s.swimming) and String(s.hold) == "" and String(s.move) != "tumble"

## Where a footprint's footing was, to look for it again: the feet stood
## on the ground, the lip held on a ledge; Vector3.INF for none (in the
## air, swimming, tumbling).
static func footing(s: Dictionary) -> Vector3:
	if stood(s): return s.feet
	var hold := String(s.hold)
	if hold == "hang" or hold == "catch":
		var out: Vector2 = s.get("lip_out",Vector2.ZERO)
		return (s.lip as Vector3)-Vector3(out.x,0.0,out.y)*LIP_IN
	return Vector3.INF
