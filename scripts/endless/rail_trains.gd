extends Node3D
## The trains on a rail path, held as one (docs/design/endless-flight/
## spec-railroad.md, lane `train`): a RailTrain on each track, track 0's running
## +s and track 1's -s, so the two pass each other. The study and the flight's
## readers talk to this, not to a train: each frame's `before` and `after` go to
## every train, and a question about a point (FlightContact `relative`, `face`,
## `way_off`, `scrape`; NearMiss `motion_at`) is answered by the train whose car is nearest.
## The chase camera's (the study's `_sight` and `chase.tight`) ask every train:
## `sight` (exact, segment against the cars' boxes) and `tight` (in a car's hollow).
##
## The test (--train-test): the plane starts behind track 0's train in the middle
## of the gap between the tracks (RailTrain `test_start`), and track 1's train is
## placed to meet it TEST_MEET s later (the plane at cruise, the train at its
## speed): the two trains pass each other by the plane's start, so it is between
## them while they do, and they meet again every half lap, on the far straight.
##
## Knobs: --trains=0|1|2 (TRAINS: how many run; one is track 0's).

const RailTrain = preload("res://scripts/endless/rail_train.gd")

const TRAINS := 2
## The test: how long after the start track 1's train's nose meets the plane (s),
## and the speed the plane is taken to fly at (cruise, m/s).
const TEST_MEET := 8.0
const CRUISE := 36.75

var game: Node3D
## The trains, track 0's first.
var list: Array[Node3D] = []

static func count_flag(otherwise := TRAINS) -> int:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--trains="): return clampi(a.trim_prefix("--trains=").to_int(),0,2)
	return otherwise

## The test's trains on `path` (rail_test_path.gd).
func setup(g: Node3D, path: RefCounted) -> void:
	game = g
	name = "RailTrains"
	var n := count_flag()
	if n >= 1: _add(path,0,RailTrain.TEST_HEAD,"rail/train0")
	if n >= 2:
		var s := RailTrain.test_start_s()+(CRUISE+RailTrain.speed_flag())*TEST_MEET
		_add(path,1,s,"rail/train1")

func _add(path: RefCounted, track: int, nose: float, handle: String) -> void:
	var tr: Node3D = RailTrain.new()
	add_child(tr)
	tr.setup(game,path,track,nose,handle)
	tr.name = "Train%d" % track
	list.append(tr)

func before(delta: float) -> void:
	for tr: Node3D in list: tr.before(delta)

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
