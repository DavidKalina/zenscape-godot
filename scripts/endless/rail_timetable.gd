extends RefCounted
## A train's timetable on a rail path (docs/design/endless-flight/spec-railroad.md,
## lane `train`): where its nose is at any clock time. A pure function of the
## time (`at`), so a train holds no place of its own and stands in the same spot
## on every machine (co-op later); a clock that jumps moves it with no harm.
##
## The train runs one track of `path` (the rail path contract: `length`,
## `pose(s, track)`), measured in metres along that track's own centre (its
## odometer, `d`): on a curve the outer track is longer than the middle line's s,
## the inner one shorter (RailLine: 4% on its tightest), so a train holds
## `speed` m/s on every curve and its cars keep their gaps. Track 0 runs +s,
## track 1 -s; d grows the way the train runs, from 0 at s = 0.
##
## The day: it halts with its nose at each stop (an s), waits its dwell (s), pulls
## out at ACCEL m/s^2, runs at `speed` and brakes at BRAKE m/s^2 into the next
## stop, round the lap, and again every `period` s. With no stops it runs at
## `speed` the whole way round. Speed under STILL: it stands where `aim` put it.
##
## Two trains meet in the same two places every lap only if their laps take as
## long (one runs the outer track, longer by pi x the tracks' gap): give both
## the same `period` (at least each's `natural()`); the time over a train's
## natural lap is shared over its dwells. Then `aim(s, time)` puts the nose at s
## at that clock time (moving `phase`): set the period first, aim after.
##
## Reads: `at(time)` {d, s, v (m/s along its track), stop (the index of the stop
## it waits at, else -1)}; `s_of(d)`, `d_of(s)`; `time_at(s)` (the clock time,
## within one period, its nose passes s); `lap()` (its track's lap, m).

const SPEED := 32.0
const DWELL := 20.0
## Pulling out and braking (m/s^2): to full speed in a minute, stopped in 45 s.
const ACCEL := 0.5
const BRAKE := 0.7
const STILL := 0.5
## The odometer's samples along the path (m).
const STEP := 2.0

var path: RefCounted
var track := 0
var speed := SPEED
## The stops in running order: each one's d, s and dwell (s), and its dwell
## with the period's share.
var stop_d := PackedFloat64Array()
var stop_s := PackedFloat64Array()
var dwells := PackedFloat64Array()
var _wait := PackedFloat64Array()
## Each leg (stop i to the next): [length, top speed, accel time, cruise time, brake time].
var _legs: Array[PackedFloat64Array] = []
var _natural := 0.0
## One lap's seconds (`period`), and the clock time the lap starts at: the
## arrival at the first stop, or with no stops the nose at d = 0.
var period := 0.0:
	set(value):
		period = maxf(value,_natural)
		_share()
var phase := 0.0
## The odometer: d at each STEP of s along +s (track 0's way), `_lap` the whole.
var _cum := PackedFloat64Array()
var _h := STEP
var _lap := 0.0
## With speed under STILL: where it stands.
var _still_d := 0.0

## `stops`: the s each stop's nose halts at (any order); `wait`: the seconds at
## each, one for all or an Array in the order of `stops`; `top`: its speed (m/s).
func _init(rail_path: RefCounted, on_track: int, stops: Array = [], wait: Variant = DWELL, top := SPEED) -> void:
	path = rail_path
	track = on_track
	speed = top
	_measure()
	var ds: Array = []
	for i in range(stops.size()):
		var w := float((wait as Array)[i]) if wait is Array else float(wait)
		ds.append([d_of(float(stops[i])),fposmod(float(stops[i]),float(path.length())),maxf(w,0.0)])
	ds.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for e: Array in ds:
		# Two stops in one place are one.
		if not stop_d.is_empty() and float(e[0])-stop_d[stop_d.size()-1] < 1.0: continue
		stop_d.append(float(e[0]))
		stop_s.append(float(e[1]))
		dwells.append(float(e[2]))
	_plan()

## The track's lap (m along its own centre).
func lap() -> float:
	return _lap

## The lap's seconds with no time added to the dwells.
func natural() -> float:
	return _natural

func still() -> bool:
	return speed < STILL

## Stop `i`'s wait (s, in running order): its dwell with the period's share.
func wait(i: int) -> float:
	return _wait[i]

## Where the train is at clock `time`: {d, s, v, stop}.
func at(time: float) -> Dictionary:
	if still(): return {"d":_still_d,"s":s_of(_still_d),"v":0.0,"stop":-1}
	var u := fposmod(time-phase,period)
	if stop_d.is_empty():
		var d0 := fposmod(u*speed,_lap)
		return {"d":d0,"s":s_of(d0),"v":speed,"stop":-1}
	for i in range(stop_d.size()):
		if u < _wait[i]: return {"d":stop_d[i],"s":stop_s[i],"v":0.0,"stop":i}
		u -= _wait[i]
		var g := _legs[i]
		var T := g[2]+g[3]+g[4]
		if u < T or i == stop_d.size()-1:
			var xv := _run(g,minf(u,T))
			var d := fposmod(stop_d[i]+xv.x,_lap)
			return {"d":d,"s":s_of(d),"v":xv.y,"stop":-1}
		u -= T
	return {}

## The clock time (in [0, period)) the nose passes s (on a stop: arrives at it).
func time_at(s: float) -> float:
	var d := d_of(s)
	if still(): return 0.0
	if stop_d.is_empty(): return fposmod(phase+d/speed,period)
	var u := 0.0
	for i in range(stop_d.size()):
		var g := _legs[i]
		var x := fposmod(d-stop_d[i],_lap)
		if x < g[0]: return fposmod(phase+u+(0.0 if x < 0.01 else _wait[i]+_when(g,x)),period)
		u += _wait[i]+g[2]+g[3]+g[4]
	return fposmod(phase,period)

## The nose at s at clock `time`, the lap's other times unchanged.
func aim(s: float, time: float) -> void:
	_still_d = d_of(s)
	if still(): return
	phase = 0.0
	phase = time-time_at(s)

## The s at odometer d (wrapping).
func s_of(d: float) -> float:
	var n := float(path.length())
	d = fposmod(d,_lap)
	if track != 0: d = _lap-d
	var i := clampi(_cum.bsearch(d,true)-1,0,_cum.size()-2)
	var a := _cum[i]
	var b := _cum[i+1]
	var s := (i+(d-a)/maxf(b-a,0.000001))*_h
	return fposmod(s,n)

## The odometer at s (wrapping).
func d_of(s: float) -> float:
	var n := float(path.length())
	var f := fposmod(s,n)/_h
	var i := mini(int(f),_cum.size()-2)
	var d := lerpf(_cum[i],_cum[i+1],f-i)
	return fposmod(d if track == 0 else _lap-d,_lap)

## Leg `g`'s run `u` s after pulling out: Vector2(m from its start, m/s).
static func _run(g: PackedFloat64Array, u: float) -> Vector2:
	var v := g[1]
	var ta := g[2]
	var tc := g[3]
	var tb := g[4]
	if u < ta:
		var a := v/maxf(ta,0.000001)
		return Vector2(0.5*a*u*u,a*u)
	var da := 0.5*v*ta
	if u < ta+tc: return Vector2(da+v*(u-ta),v)
	var r := maxf(ta+tc+tb-u,0.0)
	var b := v/maxf(tb,0.000001)
	return Vector2(g[0]-0.5*b*r*r,b*r)

## Leg `g`'s seconds after pulling out to reach `x` m along it.
static func _when(g: PackedFloat64Array, x: float) -> float:
	var v := g[1]
	var ta := g[2]
	var tc := g[3]
	var tb := g[4]
	var da := 0.5*v*ta
	if x < da: return sqrt(2.0*x/(v/maxf(ta,0.000001)))
	if x < g[0]-0.5*v*tb: return ta+(x-da)/v
	var b := v/maxf(tb,0.000001)
	return ta+tc+tb-sqrt(maxf(2.0*(g[0]-x)/b,0.0))

func _plan() -> void:
	_legs.clear()
	var n := stop_d.size()
	if still():
		_natural = 1.0
	elif n == 0:
		_natural = _lap/speed
	else:
		_natural = 0.0
		for i in range(n):
			var length := fposmod(stop_d[(i+1)%n]-stop_d[i],_lap)
			if n == 1: length = _lap
			var top := speed
			if top*top*(0.5/ACCEL+0.5/BRAKE) > length: top = sqrt(2.0*length*ACCEL*BRAKE/(ACCEL+BRAKE))
			var ta := top/ACCEL
			var tb := top/BRAKE
			var tc := maxf(length-top*top*(0.5/ACCEL+0.5/BRAKE),0.0)/top
			_legs.append(PackedFloat64Array([length,top,ta,tc,tb]))
			_natural += dwells[i]+ta+tc+tb
	period = _natural

## The period's time over the natural lap shared over the dwells.
func _share() -> void:
	var n := stop_d.size()
	_wait.resize(n)
	var extra := (period-_natural)/maxf(n,1)
	for i in range(n): _wait[i] = dwells[i]+extra

## The odometer table, once a path and track (cached: a lap of RailLine is 3700
## samples a track).
static var _tables := {}

func _measure() -> void:
	var n := float(path.length())
	var key := "%d/%d" % [path.get_instance_id(),track]
	if _tables.has(key):
		var got: Array = _tables[key]
		_cum = got[0]
		_h = float(got[1])
		_lap = _cum[_cum.size()-1]
		return
	var k := int(ceil(n/STEP))
	_h = n/k
	_cum.resize(k+1)
	_cum[0] = 0.0
	var was: Vector3 = (path.pose(0.0,track) as Transform3D).origin
	for i in range(1,k+1):
		var o: Vector3 = (path.pose(i*_h,track) as Transform3D).origin
		_cum[i] = _cum[i-1]+o.distance_to(was)
		was = o
	_lap = _cum[k]
	_tables[key] = [_cum,_h]
