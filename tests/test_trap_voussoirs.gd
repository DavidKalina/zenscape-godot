extends SceneTree
## Loose Voussoirs (scripts/traps/trap_voussoirs.gd) in the trap yard
## (studies/trap_yard.tscn), headless, the pilot driven by scripted input:
##   - a slab stood on falls after its delay (its tell sounding first) and
##     one not stood on stays;
##   - the first slab only tests (puffs, never falls);
##   - run, he crosses the whole row and stands on the far deck; walked, a
##     slab goes from under him and he falls to the floor below.
##   godot --headless --path . --script tests/test_trap_voussoirs.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Trap =preload("res://scripts/traps/trap.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor
var trap: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("trap voussoirs test timed out"); quit(2))
	study = load("res://studies/trap_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	trap = study.traps.named("voussoirs")
	check(trap != null and trap.slabs.size() == 8 and trap.danger() == 2,"The yard has Loose Voussoirs: 8 slabs, cost 2")
	var p := Trap.pilot()
	check(is_equal_approx(trap.knob("length"),p.walk*0.5) and is_equal_approx(trap.knob("width"),p.run*0.5) and float(trap.knob("delay")) < float(trap.knob("length"))/p.walk,"Sized from the pilot: a slab is his half second walking long, the delay under his walk across it")
	await _frames(2)
	_stand_and_wait()
	_walk_and_run()
	print("trap voussoirs: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _frames(n: int) -> void:
	for i in range(n): await physics_frame

func _tick(n: int) -> void:
	for i in range(n): study.tick(DT)

func _input(want: Vector2) -> void:
	study.script_want = want

## Set on slab `i`'s middle, standing.
func _set_on(i: int) -> void:
	study.place(trap.to_global(trap.slabs[i].top),Vector2(0.0,-1.0))
	_input(Vector2.ZERO)
	_tick(2)

func _stand_and_wait() -> void:
	var delay: float = trap.knob("delay")
	_set_on(3)
	check(m.grounded and trap.slabs[3].state == 1,"Stood on a slab it is touched and sounds (state %d, heard %d)" % [trap.slabs[3].state,trap.heard.size()])
	_tick(int(delay*60.0*0.6))
	check(trap.slabs[3].state == 1,"...and holds until its delay is up")
	_tick(int(delay*60.0*0.6))
	check(trap.slabs[3].state >= 2 and trap.slabs[3].body.collision_layer == 0,"...then falls away (a beat of %.2f s)" % delay)
	_tick(60)
	check(m.feet.y < -0.5,"...and he falls with it (y %.2f)" % m.feet.y)
	check(trap.slabs[5].state == 0 and trap.slabs[5].body.collision_layer == 1,"A slab not stood on stays")
	# The first slab only tests.
	_set_on(0)
	_tick(int(delay*60.0*3.0))
	check(trap.slabs[0].state == 4 and m.grounded and m.feet.y > -0.1,"The first slab only tests: it puffs and he stays on it")

func _walk_and_run() -> void:
	var p := Trap.pilot()
	# Run the whole row.
	study.place(Vector3(trap.global_position.x,0.0,trap.global_position.z+3.0),Vector2(0.0,-1.0))
	_tick(2)
	var low := 0.0
	var end_z: float = trap.exit().origin.z-0.5
	for i in range(240):
		_input(Vector2(0.0,-1.0))
		_tick(1)
		low = minf(low,m.feet.y)
		if m.feet.z < end_z: break
	check(m.feet.z < end_z and low > -0.3 and m.grounded,"Run, he crosses the row and stands on the far deck (z %.1f, lowest y %.2f)" % [m.feet.z,low])
	# Walk it: the slab he is on goes from under him before he is off it,
	# and he is left falling or hanging by a lip, never across.
	study.place(Vector3(trap.global_position.x,0.0,trap.global_position.z+1.0),Vector2(0.0,-1.0))
	_tick(2)
	low = 0.0
	for i in range(300):
		_input(Vector2(0.0,-p.walk/p.run))
		_tick(1)
		low = minf(low,m.feet.y)
	check(trap.fallen_count >= 1 and m.feet.z > end_z and (m.feet.y < -0.3 or m.hold != ""),"Walked, a slab goes from under him: he falls or hangs by a lip, not across (z %.1f, y %.2f, %s)" % [m.feet.z,m.feet.y,m.hold])
