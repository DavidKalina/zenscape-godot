extends SceneTree
## Seesaw Slab (scripts/traps/trap_seesaw.gd) in the trap yard, headless:
##   - stood on the near end, the slab tips toward him (far end rises) and
##     he is carried with it;
##   - empty, it returns level;
##   - a hard landing on the high end flings what stands on the low end:
##     a RigidBody3D load, and the pilot himself.
##   godot --headless --path . --script tests/test_trap_seesaw.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Trap = preload("res://scripts/traps/trap.gd")
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

func _tick(n: int) -> void:
	for i in range(n):
		study.tick(DT)
		await physics_frame

func _put(z: float, up := 0.0) -> void:
	var at: Vector3 = trap.to_global(Vector3(0.0,up,z))
	study.place(at,Vector2(0.0,-1.0))
	study.script_want = Vector2.ZERO

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("trap seesaw test timed out"); quit(2))
	study = load("res://studies/trap_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	trap = study.traps.named("seesaw")
	check(trap != null and trap.danger() == 3,"The yard has a Seesaw Slab, cost 3")
	var max_tilt: float = trap.knob("max_tilt")
	await physics_frame
	await physics_frame
	# Near end: the far end rises.
	_put(-0.8)
	await _tick(90)
	check(m.grounded and trap.on_slab(m.feet),"Stood on the near end he is on the slab")
	check(trap.tilt > max_tilt*0.4 and trap.high_end() == 1,"...it tips toward him: far end up (tilt %.2f of %.2f)" % [trap.tilt,max_tilt])
	check(absf(m.feet.y-trap.to_global(Vector3(0.0,trap._surface_y(trap.to_local(m.feet).z),0.0)).y) < 0.2,"...and he is carried with it (y %.2f)" % m.feet.y)
	# Empty: level.
	_put(8.0)
	await _tick(300)
	check(absf(trap.tilt) < 0.01,"Empty, it returns level (tilt %.3f)" % trap.tilt)
	# Hard landing on the high end flings the low end.
	var stone := RigidBody3D.new()
	stone.gravity_scale = 0.0
	var cs := CollisionShape3D.new()
	cs.shape = SphereShape3D.new()
	stone.add_child(cs)
	study.add_child(stone)
	trap.loads.append(stone)
	_put(-length_far(),3.0)
	_level_at(max_tilt)
	stone.global_position = trap.to_global(Vector3(0.0,1.5,-0.7))
	stone.linear_velocity = Vector3.ZERO
	await physics_frame
	var launches: int = trap.launches
	await _tick(80)
	check(trap.launches == launches+1,"A hard landing on the high end is a launch (%d)" % trap.launches)
	check(stone.linear_velocity.y > 1.0,"...it flings the load on the low end (vy %.1f)" % stone.linear_velocity.y)
	# The pilot himself on the low end, a blow on the high end.
	_put(-0.8)
	_level_at(max_tilt)
	m.feet = trap.to_global(Vector3(0.0,trap._surface_y(-0.8),-0.8))
	await physics_frame
	await _tick(1)
	_level_at(max_tilt)
	trap.impact(2.5,float(trap.knob("hard"))*1.5)
	await _tick(2)
	check(not m.grounded and m.velocity.y > 1.0,"...and the pilot on the low end (vy %.1f)" % m.velocity.y)
	print("trap seesaw: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## z of a spot on the far end.
func length_far() -> float:
	return trap.length()-0.8

func _level_at(t: float) -> void:
	trap.tilt = t
	trap.spin = 0.0
	trap._pose()
