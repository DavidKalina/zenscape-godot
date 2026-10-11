extends SceneTree
## The pocket sail study (studies/pocket_sail_study.tscn), headless: the
## island, its tiers and its climbs stand, and the pilot stands on the top;
## walked onto the nudge pad, thrown off without the sail, he comes down
## on the shelf, 12 m lower; thrown by the hurl, the sail opened at the top
## of the throw and steered back, then folded over the top, he comes back
## onto it; thrown by the hurl without it, he falls past the shelf; the
## shelf's stair climbs back to the top, and the switchbacks from the
## islets to the shelf and from the floor to the islets; a gust front pushes the sail
## sideways and the rising air holds it up; a sentinel's blow (K) throws
## him out from the middle; fallen past everything, he is set back at a
## station, never lost.
##   godot --headless --path . --script tests/test_pocket_sail_study.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PocketSail = preload("res://scripts/pocket_sail.gd")
const Study = preload("res://studies/pocket_sail_study.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## Steps until `done` (given the motor) or `most` frames, the stick at
## `want`, the jump held at `jump`.
func until(want: Vector2, jump: bool, most: int, done: Callable) -> int:
	study.script_want = want
	study.script_jump = jump
	for i in range(most):
		study.tick(DT)
		if done.call(study.motor): return i
	return most

## A tap of Space.
func press() -> void:
	study.script_jump = true
	study.tick(DT)
	study.script_jump = false
	study.tick(DT)

## Walked along `legs`, each [the stick, "x" or "z", the line to cross]:
## the stick held until the feet are past the line.
func walk(legs: Array) -> void:
	for leg: Array in legs:
		var want: Vector2 = leg[0]
		var on: float = want.x if leg[1] == "x" else want.y
		until(want,false,60*12,func(mm: PilotMotor) -> bool:
			var at: float = mm.feet.x if leg[1] == "x" else mm.feet.z
			return (at-float(leg[2]))*on > 0.0)

## Calm: no gust under way, none to come.
func calm() -> void:
	for front: Dictionary in study.fronts:
		if front.node != null: front.node.queue_free()
	study.fronts.clear()
	study._next_gust = INF

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("pocket sail study test timed out"); quit(2))
	study = load("res://studies/pocket_sail_study.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	var m: PilotMotor = study.motor
	calm()
	check(study.stations.size() == 6 and study.get_child_count() > 60,"The island, its tiers and climbs stand (%d nodes)" % study.get_child_count())
	until(Vector2.ZERO,false,30,func(_m: PilotMotor) -> bool: return false)
	check(m.grounded and absf(m.feet.y-Study.TOP) < 0.05,"He stands on the top, %.1f m up" % m.feet.y)
	# The nudge, no sail: down on the shelf.
	study.place(Vector3(8.0,Study.TOP,14.0),Vector2(1.0,0.0))
	until(Vector2(1.0,0.0),false,120,func(_m: PilotMotor) -> bool: return not study.last_throw.is_empty())
	check(study.last_throw.get("what","") == "nudge","Walked onto the nudge pad, he is thrown")
	until(Vector2.ZERO,false,600,func(mm: PilotMotor) -> bool: return mm.grounded)
	check(m.grounded and m.feet.y > 37.9 and m.feet.y < Study.TOP-1.0 and m.feet.x > 21.9,"No sail: he comes down on the shelf (or its stair), 10 to 12 m lower (%.1f m up, x %.1f)" % [m.feet.y,m.feet.x])
	# The hurl, the sail out at the top and steered back, folded over the top.
	study.last_throw = {}
	study.place(Vector3(8.0,Study.TOP,-7.0),Vector2(1.0,0.0))
	until(Vector2(1.0,0.0),false,120,func(_m: PilotMotor) -> bool: return not study.last_throw.is_empty())
	until(Vector2.ZERO,false,120,func(mm: PilotMotor) -> bool: return mm.velocity.y <= 0.0)
	var peak: float = m.feet.y
	press()
	check(m.move == "sail","At the top of the throw (%.1f m up), Space: the sail" % peak)
	var folded := false
	var frames := 0
	study.script_want = Vector2(-1.0,0.0)
	while not m.grounded and frames < 60*20:
		if not folded and m.move == "sail" and m.feet.x < 6.0:
			press()
			folded = true
			study.script_want = Vector2.ZERO
		else: study.tick(DT)
		frames += 1
	check(folded and m.grounded and absf(m.feet.y-Study.TOP) < 0.2,"Steered back and folded over it, he lands on the top again (%.1f m up, x %.1f)" % [m.feet.y,m.feet.x])
	# The hurl, no sail: past the shelf, down at least to the islets.
	study.last_throw = {}
	study.place(Vector3(8.0,Study.TOP,-7.0),Vector2(1.0,0.0))
	until(Vector2(1.0,0.0),false,120,func(_m: PilotMotor) -> bool: return not study.last_throw.is_empty())
	until(Vector2.ZERO,false,60*10,func(mm: PilotMotor) -> bool: return mm.grounded)
	check(m.feet.y < 30.0,"The hurl without the sail: well past the shelf (%.1f m up)" % m.feet.y)
	# The shelf's stair: a jump a block, back to the top.
	study.place(Vector3(23.5,38.0,18.5),Vector2(0.0,-1.0))
	var climbed := false
	for k in range(14):
		until(Vector2(0.0,-1.0),true,20,func(_m: PilotMotor) -> bool: return false)
		until(Vector2(0.0,-1.0),false,40,func(mm: PilotMotor) -> bool: return mm.grounded)
		if m.feet.y >= Study.TOP-0.05:
			climbed = true
			break
	until(Vector2(-1.0,0.0),false,90,func(_m: PilotMotor) -> bool: return false)
	check(climbed and m.grounded and absf(m.feet.y-Study.TOP) < 0.05 and m.feet.x < 18.0,"The shelf's stair climbs back onto the top (%.1f m up, x %.1f)" % [m.feet.y,m.feet.x])
	# The switchbacks: islets up to the shelf, the floor up to the islets.
	study.place(Vector3(39.0,24.0,12.0),Vector2(0.0,-1.0))
	walk([[Vector2(0.0,-1.0),"z",-12.0],[Vector2(1.0,0.0),"x",43.0],[Vector2(0.0,1.0),"z",11.5],[Vector2(-1.0,0.0),"x",33.0]])
	check(m.grounded and absf(m.feet.y-38.0) < 0.05 and m.feet.x < 36.0,"The islets' switchback climbs to the shelf (%.1f m up, x %.1f)" % [m.feet.y,m.feet.x])
	study.place(Vector3(52.0,0.0,44.0),Vector2(0.0,-1.0))
	walk([[Vector2(0.0,-1.0),"z",15.0],[Vector2(1.0,0.0),"x",56.0],[Vector2(0.0,1.0),"z",36.0],[Vector2(-1.0,0.0),"x",52.0],
		[Vector2(0.0,-1.0),"z",15.0],[Vector2(1.0,0.0),"x",56.0],[Vector2(0.0,1.0),"z",36.0],[Vector2(-1.0,0.0),"x",48.0],[Vector2(0.0,-1.0),"z",18.0]])
	check(m.grounded and absf(m.feet.y-24.0) < 0.05 and m.feet.x < 48.0,"The floor's switchback climbs to the main islet (%.1f m up, x %.1f z %.1f)" % [m.feet.y,m.feet.x,m.feet.z])
	# A gust front across the sail.
	study.place(Vector3(-40.0,40.0,40.0),Vector2(0.0,-1.0))
	until(Vector2(0.0,-1.0),false,20,func(_m: PilotMotor) -> bool: return false)
	press()
	until(Vector2(0.0,-1.0),false,90,func(_m: PilotMotor) -> bool: return false)
	var still_x: float = m.velocity.x
	study.send_gust()
	study.fronts[-1].born = study.air_clock-(Study.GUST_FROM-40.0)/Study.GUST_SPEED
	var pushed := 0.0
	for i in range(150):
		study.tick(DT)
		pushed = maxf(pushed,m.velocity.x-still_x)
	print("MEASURE: a gust front's push on the sail: %.2f m/s across" % pushed)
	check(m.move == "sail" and pushed > Study.GUST_PUSH*0.5,"A gust front pushes the sail across (%.2f m/s)" % pushed)
	calm()
	# The rising air holds it up.
	study.place(Vector3(Study.THERMAL_AT.x,45.0,Study.THERMAL_AT.y),Vector2(0.0,-1.0))
	until(Vector2.ZERO,false,15,func(_m: PilotMotor) -> bool: return false)
	press()
	var low := INF
	for i in range(180):
		study.script_want = Vector2(1.0,0.0).rotated(i*0.05)
		study.tick(DT)
		if i > 90: low = minf(low,-m.velocity.y)
	check(m.move == "sail" and low < PocketSail.SINK*0.3,"In the rising air the sail barely sinks, or lifts (%.2f m/s down at most)" % low)
	# A sentinel's blow.
	study.place(Vector3(0.0,Study.TOP,-14.0),Vector2(0.0,1.0))
	until(Vector2.ZERO,false,10,func(_m: PilotMotor) -> bool: return false)
	study.blow(3)
	check(not m.grounded and m.velocity.z < -8.0 and m.velocity.y > 15.0,"K: a sentinel's blow throws him out from the middle (%.1f m/s out)" % -m.velocity.z)
	# Lost past everything: set back at a station.
	study.place(Vector3(200.0,10.0,200.0),Vector2(0.0,-1.0))
	until(Vector2.ZERO,false,60*6,func(mm: PilotMotor) -> bool: return mm.grounded and mm.feet.y > -1.0)
	check(m.grounded and m.feet.y > -1.0,"Fallen past everything, he is set back on his feet (%.1f m up)" % m.feet.y)
	print("PASS: pocket sail study" if failures == 0 else "FAIL: pocket sail study")
	quit(1 if failures else 0)
