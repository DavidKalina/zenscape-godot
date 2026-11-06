extends Node3D
## The trains on a rail path, held as one (docs/design/endless-flight/
## spec-railroad.md, lane `train`). The module: give it any rail path (the
## contract: `length`, `pose(s, track)`, `kind`) and, for each train, its track
## and timetable (`add`, rail_timetable.gd); give it a clock (`clock`, a Callable
## returning seconds; without one it counts its own frames' seconds). Each
## frame every train is where its timetable puts it at the clock's time (a pure
## function: no train holds a place of its own), and built only near the plane:
## - far (past LOOK_FAR m): nothing but its timetable; it costs one read of it
##   and three poses a frame;
## - in sight (LOOK_NEAR in, LOOK_FAR out): its look, posed each frame (the
##   cars' meshes made once and shared by every train);
## - near (SOLID_NEAR in, SOLID_FAR out): its solid too (RailTrain `set_solid`).
## `list` holds the trains built; `runs` all of them.
##
## The flight's readers talk to this, not to a train: each frame's `before` and
## `after` go to every train built, and a question about a point (FlightContact
## `relative`, `face`, `way_off`, `scrape`; NearMiss `motion_at`) is answered by
## the train whose car is nearest. The chase camera's (the study's `_sight` and
## `chase.tight`) ask every train: `sight` (exact, segment against the cars'
## boxes) and `tight` (in a car's hollow).
##
## The test (--train-test, `setup`): two trains on the test loop, each stopping
## at TEST_STOP (track 0's nose there, track 1's a train's length short of it, so
## both stand along one platform), DWELL s, their laps held to one period so they
## meet in the same two places every lap. Track 0's nose passes TEST_HEAD at
## time 0, full speed, the plane behind it in the gap between the tracks
## (RailTrain `test_start`); track 1's meets the plane TEST_MEET s in (the plane
## at cruise).
##
## The line (`on_line`, seed 1's railroad, RailLine; the timetables
## `line_tables`): train 0 on track 0 (+s) and train 1 on track 1 (-s) stop at
## the four stops (LINE_STOPS, a train's middle on the middle of the
## station's platforms, RailStops `platform`) and wait
## each one's dwell, their laps held to one period, so they pass each other in
## the same two places every lap: their noses meet mid west tunnel (LINE_TUNNEL,
## head on in the dark) and, by the dwells (long at the mine and cattle towns,
## short at the start and the farm: `line_split`), mid bay bridge (LINE_BRIDGE),
## at any --train-speed=. The lap's start is set so the bridge meeting falls
## LINE_MEET s into the clock: a fresh start takes off (the clock held in the
## menu) with train 1 pulling out of the start station and both trains coming
## onto the bridge a kilometre off on its left, in sight of the meadow.
##
## The clock on the line is the study's `rail_clock` (endless_flight.gd): the
## world's seconds since it was built, the frames' deltas the flight ticks
## (`flown`) less the menu's (`rail_held`), plus --rail-clock=S (the clock's
## time at the start). Steady: the day cycle's skips (T), speeds (] and [) and
## holds don't touch it, so the same seed and clock time put a train in the
## same place on every machine.
##
## Knobs: --trains=0|1|2 (TRAINS: how many run; one is track 0's), and
## RailTrain's --train-speed=, --rail-clock=S; the quick starts
## --rail-start=beside|tunnel|bridge (`line_start`).

const RailTrain = preload("res://scripts/endless/rail_train.gd")
const Timetable = preload("res://scripts/endless/rail_timetable.gd")
const RailStops = preload("res://scripts/endless/rail_stops.gd")

const TRAINS := 2
## Built within LOOK_NEAR m of the plane, freed past LOOK_FAR; solid within
## SOLID_NEAR, not past SOLID_FAR (m from the train's nearest point). At 9 m tall a
## car is 2 px at 4 km; solid 600 m out is 7 s off flying head on at Boost.
const LOOK_NEAR := 4000.0
const LOOK_FAR := 4400.0
const SOLID_NEAR := 600.0
const SOLID_FAR := 800.0
## The test: the stop (m along the test path, on its far straight), the wait, how
## long after the start track 1's train's nose meets the plane (s), and the speed
## the plane is taken to fly at (cruise, m/s).
const TEST_STOP := 3550.0
const DWELL := 20.0
const TEST_MEET := 8.0
const CRUISE := 36.75
## The line's stops in the order track 0 meets them: [piece, the sign of its
## share of the split], both trains'. With one period for both and the first
## meeting mid west tunnel, the second falls where the dwells after the tunnel
## (mine, cattle) outweigh the ones before it (start, farm): each waits
## DWELL_MID s, less the split at the start and farm, plus it at the mine and
## cattle towns. `line_split` finds the split that puts it mid bay bridge at
## the trains' speed (30.3 s at 32 m/s, the waits about 30/30/90/90; each
## second of it moves the meeting about 64 m along).
const DWELL_MID := 60.0
const LINE_STOPS := [["rail/start-station",-1.0],["rail/farm-town",-1.0],["rail/mine-town",1.0],["rail/cattle-town",1.0]]
## Where the noses meet (s): mid west tunnel and mid bay bridge.
const LINE_TUNNEL := 10020.0
const LINE_BRIDGE := 17316.0
## The clock time (s) the noses meet on the bay bridge. The start faces the
## Peak and no stretch of the line is in view ahead of it in the first minute
## (the land hides it all within 50 degrees of the nose, flown straight at 45
## or 100 m), so the first minute's trains are the bridge's: on the plane's
## left, 0.8-1.1 km off, train 0 coming over from the cattle plain, train 1
## out of the start station (its tail still along the platform at the
## takeoff); both on the bridge from about 10 s to 77 s, the pass itself
## (noses meet to tails clear, the 24 cars) 35-52 s.
const LINE_MEET := 35.0
## The quick starts on the line (--rail-start=beside|tunnel|bridge,
## `line_start`): the plane RailTrain START_BACK m behind train 0's van, in
## the gap between the tracks, START_UP m over the rails (over the low zone,
## FlightWeight `low_spans`, so hands off it holds its height; at the test's
## 4 m it settles onto the deck in 2.5 s), flying its way at cruise, the clock
## set to match: each puts the van in one place, so the plane starts there
## at any --train-speed= and any train length:
## - beside: the van at START_BESIDE, where the farm plain's 2 km run to the
##   farm town starts, at full speed, train 1 far off on the cattle side: creep
##   up the train at cruise (about a minute to the engine, as it brakes into
##   the farm town), Boost to it;
## - tunnel: the van START_MOUTH m short of the west tunnel's mouth, at the
##   farm mouth's trestle, the plane 6 s short of the bore: train 0 goes in
##   ahead on the right and train 1 comes at the plane head on in the dark
##   (the noses meet mid tunnel 7 s in, train 1's meets the plane 15 s in, at
##   32 m/s with the 24 cars);
## - bridge: the van START_DECK m onto the bay bridge's west end: between both
##   trains on the deck (the noses meet 7 s in, train 1's meets the plane 15
##   s in).
const START_BESIDE := 3800.0
const START_MOUTH := 194.0
const START_DECK := 26.0
const START_UP := 6.5

var game: Node3D
var path: RefCounted
## The clock (seconds), or an empty Callable: then `time` counts the frames'.
var clock := Callable()
var time := 0.0
## Each train: {track, timetable, label, train (the RailTrain built, or null)}.
var runs: Array[Dictionary] = []
## The trains built, track 0's first.
var list: Array[Node3D] = []
## Trains made and freed (counted, for the drivers).
var built := 0
var freed := 0

static func count_flag(otherwise := TRAINS) -> int:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--trains="): return clampi(a.trim_prefix("--trains=").to_int(),0,2)
	return otherwise

## The test's trains on `rail_path` (rail_test_path.gd), on their own clock.
func setup(g: Node3D, rail_path: RefCounted) -> void:
	start(g,rail_path)
	var n := count_flag()
	var top := RailTrain.speed_flag()
	var t0: RefCounted = Timetable.new(rail_path,0,[TEST_STOP],DWELL,top)
	var t1: RefCounted = Timetable.new(rail_path,1,[TEST_STOP-RailTrain.length_of()],DWELL,top)
	var lap := maxf(float(t0.natural()),float(t1.natural()))
	t0.period = lap
	t1.period = lap
	t0.aim(RailTrain.TEST_HEAD,0.0)
	t1.aim(RailTrain.test_start_s()+CRUISE*TEST_MEET,TEST_MEET)
	if n >= 1: add(0,t0,"rail/train0")
	if n >= 2: add(1,t1,"rail/train1")
	refresh()

## --rail-clock=S: the trains' clock at the start (s), else `otherwise`.
static func clock_flag(otherwise := 0.0) -> float:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--rail-clock="): return a.trim_prefix("--rail-clock=").to_float()
	return otherwise

## --rail-start=beside|tunnel|bridge (`line_start`), or "".
static func start_flag() -> String:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--rail-start="): return a.trim_prefix("--rail-start=")
	return ""

## The quick start `which` (beside, tunnel, bridge: START_BESIDE above) on
## `line` with the trains at `top` m/s: {at (Vector2, x z), heading (rad, the
## study's: forward is (-sin, -cos)), y (world), clock (s), s}; {} if unknown.
static func line_start(line: RefCounted, which: String, top := RailTrain.SPEED) -> Dictionary:
	var tables := line_tables(line,top)
	if tables.size() < 2 or (tables[0] as RefCounted).still(): return {}
	var t0: RefCounted = tables[0]
	var long := RailTrain.length_of()
	var van := 0.0
	match which:
		"beside": van = START_BESIDE
		"tunnel": van = float(line.piece("rail/west-tunnel").get("s0",LINE_TUNNEL))-START_MOUTH
		"bridge": van = float(line.piece("rail/bay-bridge").get("s0",LINE_BRIDGE))+START_DECK
		_:
			push_warning("--rail-start=%s: beside, tunnel or bridge" % which)
			return {}
	var clock := float(t0.time_at(van+long))
	var s: float = t0.s_of(float(t0.at(clock).d)-long-RailTrain.START_BACK)
	var x: Transform3D = line.pose(s,0)
	var at := x.origin-x.basis.x*0.5*float(line.track_gap())+Vector3.UP*START_UP
	var f := -x.basis.z
	return {"at":Vector2(at.x,at.z),"heading":atan2(-f.x,-f.z),"y":at.y,"clock":clock,"s":s}

## The line's trains on `line` (RailLine) by `on_clock` (seconds): train 0,
## and with --trains=2 (the default) train 1.
func on_line(g: Node3D, line: RefCounted, on_clock: Callable) -> void:
	start(g,line,on_clock)
	var n := count_flag()
	var tables := line_tables(line,RailTrain.speed_flag())
	if tables.is_empty(): return
	if n >= 1: add(0,tables[0],"rail/train0")
	if n >= 2: add(1,tables[1],"rail/train1")
	refresh()

## The line's two timetables, [track 0's, track 1's], at `top` m/s: the
## stops (each train's middle on the middle of the station's platforms,
## RailStops `platform`: track 0's nose half a train past it, track 1's half
## a train short), DWELL_MID -/+ `split` s at each
## (LINE_STOPS' signs; NAN: `line_split`'s), one period for both, the noses
## meeting at LINE_TUNNEL and the second meeting (`line_meet`) at clock `meet`
## (mod the period). Empty if the line lacks a stop.
static func line_tables(line: RefCounted, top := RailTrain.SPEED, meet := LINE_MEET, split := NAN) -> Array:
	if is_nan(split): split = line_split(line,top)
	var half := RailTrain.length_of()*0.5
	var by_track := [[],[]]
	var waits: Array = []
	for st: Array in LINE_STOPS:
		var p: Dictionary = line.piece(str(st[0]))
		if p.is_empty():
			push_warning("rail trains: no stop %s on the line" % str(st[0]))
			return []
		var pl: Vector2 = RailStops.platform(line,float(p.s0))
		var mid := (pl.x+pl.y)*0.5
		by_track[0].append(mid+half)
		by_track[1].append(mid-half)
		waits.append(maxf(DWELL_MID+float(st[1])*split,0.0))
	var t0: RefCounted = Timetable.new(line,0,by_track[0],waits,top)
	var t1: RefCounted = Timetable.new(line,1,by_track[1],waits,top)
	var lap := maxf(float(t0.natural()),float(t1.natural()))
	t0.period = lap
	t1.period = lap
	if t0.still() or t1.still(): return [t0,t1]
	t0.aim(LINE_TUNNEL,0.0)
	t1.aim(LINE_TUNNEL,0.0)
	# Both moved on together till the second meeting is at `meet`.
	var m: Dictionary = line_meet(t0,t1,float(line.length()))
	var shift := meet-float(m.get("time",0.0))
	t0.phase += shift
	t1.phase += shift
	return [t0,t1]

## The split (s, in [0, DWELL_MID]) that puts the second meeting at
## LINE_BRIDGE at `top` m/s, by halving: the meeting comes down s as the split
## grows.
static func line_split(line: RefCounted, top := RailTrain.SPEED) -> float:
	var n := float(line.length())
	var lo := 0.0
	var hi := DWELL_MID
	for i in range(10):
		var mid := (lo+hi)*0.5
		var tables := line_tables(line,top,0.0,mid)
		if tables.size() < 2 or (tables[0] as RefCounted).still(): return mid
		var m := line_meet(tables[0],tables[1],n)
		if m.is_empty(): return mid
		if wrapf(float(m.s)-LINE_BRIDGE,-n*0.5,n*0.5) > 0.0: lo = mid
		else: hi = mid
	return (lo+hi)*0.5

## Where and when the noses of `t0` (track 0) and `t1` (track 1) on a path of
## `n` m meet other than at LINE_TUNNEL: {s, time} (time in [0, period)), by
## stepping one period a second at a time, then halving to 1/256 s.
static func line_meet(t0: RefCounted, t1: RefCounted, n: float) -> Dictionary:
	var P := float(t0.period)
	var tunnel_t := float(t0.time_at(LINE_TUNNEL))
	var gap := func(t: float) -> float: return fposmod(float(t1.at(t).s)-float(t0.at(t).s),n)
	var was := float(gap.call(0.0))
	var t := 1.0
	while t <= P+1.0:
		var g := float(gap.call(t))
		# Track 1's nose comes down s, track 0's up: the gap shrinks to 0 and
		# wraps to n at a meeting.
		if g > was+n*0.5:
			var a := t-1.0
			var b := t
			for i in range(8):
				var c := (a+b)*0.5
				if float(gap.call(c)) > n*0.5: b = c
				else: a = c
			var when := fposmod(b,P)
			var dt := absf(when-tunnel_t)
			if minf(dt,P-dt) > 5.0: return {"s":float(t0.at(b).s),"time":when}
		was = g
		t += 1.0
	return {}

## The holder on `rail_path`, with no trains yet.
func start(g: Node3D, rail_path: RefCounted, on_clock := Callable()) -> void:
	game = g
	path = rail_path
	clock = on_clock
	name = "RailTrains"
	if clock.is_valid(): time = float(clock.call())

## A train on `track` by `table` (on this path and track), its handle `label`.
func add(track: int, table: RefCounted, label: String) -> void:
	runs.append({"track":track,"timetable":table,"label":label,"train":null})

## Each train built, freed, made solid or not for where the plane is now.
func refresh() -> void:
	var plane = game.get("plane")
	if plane == null: return
	var p: Vector3 = plane.position
	var changed := false
	for run: Dictionary in runs:
		var tr: Node3D = run.train
		var off := _off(run,p)
		if tr == null and off < LOOK_NEAR:
			tr = RailTrain.new()
			add_child(tr)
			tr.setup(game,path,int(run.track),run.timetable,time,str(run.label))
			tr.name = "Train%d" % int(run.track)
			run.train = tr
			built += 1
			changed = true
		elif tr != null and off > LOOK_FAR:
			tr.set_solid(false)
			remove_child(tr)
			tr.queue_free()
			run.train = null
			freed += 1
			changed = true
			continue
		if tr == null: continue
		if not tr.solid and off < SOLID_NEAR: tr.set_solid(true)
		elif tr.solid and off > SOLID_FAR: tr.set_solid(false)
	if changed:
		list.clear()
		for run: Dictionary in runs:
			if run.train != null: list.append(run.train)

## How far world `p` is from the train of `run` (m, at most: a share of its
## length under the true distance): from its nose, middle and tail on its track,
## less a quarter of its length (the most a point of it is off the nearest).
func _off(run: Dictionary, p: Vector3) -> float:
	var tr: Node3D = run.train
	if tr != null:
		var best := INF
		for car: Dictionary in tr.cars: best = minf(best,(car.xf as Transform3D).origin.distance_to(p)-float(car.long)*0.5)
		return best
	var table: RefCounted = run.timetable
	var d := float((table.at(time) as Dictionary).d)
	var long := RailTrain.length_of()
	var best := INF
	for k: float in [0.0,0.5,1.0]:
		var o: Vector3 = (path.pose(table.s_of(d-long*k),int(run.track)) as Transform3D).origin
		best = minf(best,o.distance_to(p))
	return best-long*0.25

func before(delta: float) -> void:
	time = float(clock.call()) if clock.is_valid() else time+delta
	refresh()
	for tr: Node3D in list: tr.before(delta,time)

func after(delta: float) -> void:
	for tr: Node3D in list: tr.after(delta)

## The train whose car is nearest world `at`, within `reach` m, or null.
func near_train(at: Vector3, reach: float) -> Node3D:
	var best := INF
	var got: Node3D = null
	for tr: Node3D in list:
		var near: Dictionary = tr.nearest(at,reach)
		if not near.is_empty() and float(near.d) < best:
			best = float(near.d)
			got = tr
	return got

func motion_at(at: Vector3, reach: float) -> Variant:
	var tr := near_train(at,reach)
	return null if tr == null else tr.motion_at(at,reach)

func relative(at: Vector3, v: Vector3) -> Vector3:
	var tr := near_train(at,RailTrain.TOUCH)
	return v if tr == null else tr.relative(at,v)

func scrape(plane: RefCounted, n: Vector3, at: Vector3, keep: float, kick: float) -> bool:
	var tr := near_train(at,RailTrain.TOUCH)
	return tr != null and tr.scrape(plane,n,at,keep,kick)

func face(p: Vector3, reach: float) -> Vector3:
	var tr := near_train(p,reach)
	return Vector3.ZERO if tr == null else tr.face(p,reach)

## The chase camera's: the share of the way clear of every train's cars (exact),
## and whether the plane is in a car's hollow (the camera `tight`).
func sight(from: Vector3, to: Vector3, pad := 0.0) -> float:
	var got := 1.0
	for tr: Node3D in list: got = minf(got,tr.sight(from,to,pad))
	return got

func tight(p: Vector3) -> bool:
	for tr: Node3D in list:
		if tr.tight(p): return true
	return false

func way_off(p: Vector3, what := "") -> Vector3:
	for tr: Node3D in list:
		var off: Vector3 = tr.way_off(p,what)
		if off != Vector3.ZERO: return off
	return Vector3.ZERO
