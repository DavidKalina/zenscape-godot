extends SceneTree
## Walking under the aqueduct on the aqueduct isle (studies/aqueduct_isle.gd,
## its art studies/aqueduct_isle_art.gd), headless: across the run through
## each open arch standing on turf, at five points along each, both ways,
## and along the run under each such arch from pier to pier, he keeps to
## the turf (the channel's water overhead is not water over him: it once
## floated him up through the deck onto its top; scripts/
## pilot_physics_ground.gd `depth`). Up on the deck he still wades the
## channel along its length, on its floor.
##   godot --headless --path . --script tests/test_aqueduct_under.gd
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const DT := 1.0/60.0
## The most he may rise over the turf he set out on walking under (m): a
## tuft or a stone, not the deck.
const RISE_MOST := 1.6
var failures := 0
var study: Node3D
var m: RefCounted

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("aqueduct under test timed out"); quit(2))
	LaunchArgs.set_override(["--no-life","--no-flora","--no-serpent"])
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	for i in range(3): await physics_frame
	m = study.motor
	_across()
	_along()
	_channel()
	LaunchArgs.set_override(null)
	print("PASS: aqueduct under" if failures == 0 else "FAIL: aqueduct under (%d)" % failures)
	quit(1 if failures > 0 else 0)

## The turf's top at world (x, z) under the deck, or NAN.
func _turf(x: float, z: float) -> float:
	var y: float = study.ground.height_from(Vector2(x,z),Art.TOP+1.0)
	return y if is_finite(y) and absf(y-Art.TOP) < 2.0 else NAN

## Walked from `from` (on the turf) along `way` for `seconds`: the most he
## rose over where he set out, and whether he swam.
func _walk(from: Vector3, way: Vector2, seconds: float) -> Vector2:
	study.place(from,way)
	study._last_stood = from
	study.script_want = Vector2.ZERO
	for i in range(5): study.tick(DT)
	var rose := 0.0
	var swam := 0.0
	for i in range(int(seconds/DT)):
		study.script_want = way
		study.tick(DT)
		if m.grounded or m.swimming: rose = maxf(rose,m.feet.y-from.y)
		if m.swimming: swam = 1.0
	study.script_want = Vector2.ZERO
	return Vector2(rose,swam)

## Across the run (world x) through each open arch over turf, at five
## points along it, both ways.
func _across() -> void:
	var walks := 0
	var worst := 0.0
	var swam := false
	for cx: float in Art.ARCHES:
		for f: float in [-0.8,-0.4,0.0,0.4,0.8]:
			var z: float = -(cx+f*Art.HALF)
			for dir: float in [1.0,-1.0]:
				var x0: float = Art.MID_X-4.5*dir
				var y := _turf(x0,z)
				var y_under := _turf(Art.MID_X,z)
				if is_nan(y) or is_nan(y_under): continue
				var got := _walk(Vector3(x0,y,z),Vector2(dir,0.0),2.0)
				walks += 1
				worst = maxf(worst,got.x)
				if got.y > 0.0: swam = true
				if got.x > RISE_MOST or got.y > 0.0: print("  under arch at %.1f (%+.1f), going %+.0f: rose %.2f m, swam %s" % [cx,f,dir,got.x,str(got.y > 0.0)])
	print("MEASURE across under the arches: %d walks, rose at most %.2f m, swam %s" % [walks,worst,str(swam)])
	check(walks >= 16,"Walked across through the open arches over turf (%d ways)" % walks)
	check(worst < RISE_MOST and not swam,"Through every arch he keeps to the turf (rose at most %.2f m), never afloat" % worst)

## Along the run under each open arch over turf, from by one pier to by
## the next, just off the middle line.
func _along() -> void:
	var walks := 0
	var worst := 0.0
	var swam := false
	for cx: float in Art.ARCHES:
		for off: float in [-0.6,0.6]:
			var x: float = Art.MID_X+off
			var a0: float = cx-Art.HALF+0.6
			var y := _turf(x,-a0)
			if is_nan(y) or is_nan(_turf(x,-(cx+Art.HALF-0.6))): continue
			var got := _walk(Vector3(x,y,-a0),Vector2(0.0,-1.0),1.4)
			walks += 1
			worst = maxf(worst,got.x)
			if got.y > 0.0: swam = true
	print("MEASURE along under the arches: %d walks, rose at most %.2f m, swam %s" % [walks,worst,str(swam)])
	check(walks >= 2,"Walked along the run under the open arches over turf (%d ways)" % walks)
	check(worst < RISE_MOST and not swam,"Along under the spans he keeps to the turf (rose at most %.2f m), never afloat" % worst)

## Up on the deck: along the channel from the head toward the snap, on its
## floor, wading.
func _channel() -> void:
	var deck: float = Art.TOP+Art.DECK
	var from := Vector3(Art.MID_X,deck,-(Art.HEAD+3.0))
	study.place(from,Vector2(0.0,-1.0))
	study._last_stood = from
	var waded := 0
	var low := INF
	var high := -INF
	for i in range(int(3.0/DT)):
		study.script_want = Vector2(0.0,-1.0)
		study.tick(DT)
		if m.wade > 0.0: waded += 1
		low = minf(low,m.feet.y)
		high = maxf(high,m.feet.y)
	study.script_want = Vector2.ZERO
	var went: float = -m.feet.z-(Art.HEAD+3.0)
	print("MEASURE along the channel: %.1f m, feet %.2f to %.2f (the deck %.2f), wading %d frames, swimming %s" % [went,low,high,deck,waded,str(m.swimming)])
	check(went > 8.0 and low > deck-0.3 and high < deck+0.6 and waded > 60 and not m.swimming,"Up on the deck he walks the channel's length on its floor, wading its water")
