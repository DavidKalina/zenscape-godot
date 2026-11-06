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
## The line (`on_line`, seed 1's railroad, RailLine): train 0 on track 0 (+s)
## stops at the four stops (LINE_STOPS, its middle on the station's s) and
## waits each one's dwell. At clock 0 it is rolling into the start station, to
## pull out at LINE_PULL s, so it is seen from the start in the first minute.
##
## The clock on the line is the study's `rail_clock` (endless_flight.gd): the
## world's seconds since it was built, the frames' deltas the flight ticks
## (`flown`), plus --rail-clock=S (the clock's time at the start). Steady: the
## day cycle's skips (T), speeds (] and [) and holds don't touch it, so the
## same seed and clock time put a train in the same place on every machine.
##
## Knobs: --trains=0|1|2 (TRAINS: how many run; one is track 0's), and
## RailTrain's --train-speed=, --rail-clock=S.

const RailTrain = preload("res://scripts/endless/rail_train.gd")
const Timetable = preload("res://scripts/endless/rail_timetable.gd")

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
## The line's stops in the order track 0 meets them: [piece, dwell (s)]. The
## dwells are the train lane's (start and farm short, mine and cattle long):
## with one period for both trains and the first meeting mid west tunnel they
## put the second on the bay bridge.
const LINE_STOPS := [["rail/start-station",30.0],["rail/farm-town",30.0],["rail/mine-town",90.0],["rail/cattle-town",90.0]]
## Train 0 pulls out of the start station at this clock time (s); with the
## station's 30 s dwell it is braking in at clock 0. The station is 1.4 km
## behind the plane's start (which faces the Peak): a pilot who turns and flies
## to it gets there as it pulls out.
const LINE_PULL := 40.0

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

## --rail-clock=S: the trains' clock at the start (s), else 0.
static func clock_flag() -> float:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--rail-clock="): return a.trim_prefix("--rail-clock=").to_float()
	return 0.0

## The line's trains on `line` (RailLine) by `on_clock` (seconds).
func on_line(g: Node3D, line: RefCounted, on_clock: Callable) -> void:
	start(g,line,on_clock)
	var n := mini(count_flag(),1)
	var top := RailTrain.speed_flag()
	var half := RailTrain.length_of()*0.5
	var stops: Array = []
	var waits: Array = []
	for st: Array in LINE_STOPS:
		var p: Dictionary = line.piece(str(st[0]))
		if p.is_empty():
			push_warning("rail trains: no stop %s on the line" % str(st[0]))
			continue
		# Its nose half a train past the station's s, its way (+s).
		stops.append(float(p.s0)+half)
		waits.append(float(st[1]))
	if stops.is_empty(): return
	var t0: RefCounted = Timetable.new(line,0,stops,waits,top)
	# Its wait at the start station ends at LINE_PULL.
	t0.aim(float(stops[0]),LINE_PULL-float(t0.wait(0)))
	if n >= 1: add(0,t0,"rail/train0")
	refresh()

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
