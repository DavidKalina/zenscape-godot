extends SceneTree
## The giants (scripts/traps/trap_tumble.gd, trap_ray.gd) in the trap yard,
## headless, the pilot driven by scripted input:
##   - the Tumbling Block is several pilot-heights a side; a pilot standing
##     still on its top is carried round and slid off as it tips; one who
##     keeps walking uphill against the roll (a station-keeper) stays on
##     longer, over N seconds;
##   - the Sky Ray carries a pilot along its path (his world position follows
##     it, no teleport), and standing still in a hard bank he slides toward
##     the low edge.
##   godot --headless --path . --script tests/test_trap_giants.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Trap = preload("res://scripts/traps/trap.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _tick(n: int) -> void:
	for i in range(n):
		study.tick(DT)
		await physics_frame

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("trap giants test timed out"); quit(2))
	study = load("res://studies/trap_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	await physics_frame
	await physics_frame
	await _tumble()
	await _ray()
	print("trap giants: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## Seconds (up to `limit`) he stays on the block; `keep` the station-keeper.
func _stay_on(trap: Node3D, keep: bool, limit: float) -> float:
	trap.reset()
	study.place(trap.top_point(),Vector2(0.0,-1.0))
	study.script_want = Vector2.ZERO
	await _tick(2)
	var t := 0.0
	var p := Trap.pilot()
	var z0: float = trap.to_global(trap.centre()).z
	var prev_z := m.feet.z
	while t < limit:
		var want := Vector2.ZERO
		if keep:
			# Hold the middle: walk -z (uphill) when behind it, back when ahead.
			var off := m.feet.z-z0
			want = Vector2(0.0,clampf(-off*2.0,-1.0,1.0))
		study.script_want = want
		# Hop what blocks him (a step, a wall): pressing on and not getting on.
		study.script_jump = keep and m.feet.z-z0 > 0.3 and m.feet.z > prev_z-0.004 and m.grounded
		prev_z = m.feet.z
		await _tick(1)
		t += DT
		if OS.get_environment("TRACE") != "" and int(t*60.0)%5 == 0 and t > 6.0 and t < 7.4 and keep:
			print("  t %.2f roll %.2f feet %s grounded %s move %s hold %s" % [t,trap.roll,(trap.to_local(m.feet)-trap.centre()).snapped(Vector3.ONE*0.01),m.grounded,m.move,m.hold])
			print("     want %s vel %s wallish %s" % [study.script_want,m.velocity.snapped(Vector3.ONE*0.01),str(m.slope)])
		if not trap.on_block(m.feet) or m.feet.y < trap.top_point().y-3.0 and not m.on_ledge(): break
	study.script_jump = false
	return t

func _tumble() -> void:
	var trap: Node3D = study.traps.named("tumble")
	var p := Trap.pilot()
	check(trap != null and trap.danger() == 5,"The yard has the Tumbling Block, cost 4 over the void")
	var size: float = trap.knob("size")
	check(size >= 4.0*1.12,"It is many pilot-heights a side (%.1f m)" % size)
	var still := await _stay_on(trap,false,20.0)
	check(still < 15.0,"Standing still on its top he is slid off as it tips (%.1f s)" % still)
	var keeping := await _stay_on(trap,true,40.0)
	check(keeping > still*1.5 and keeping >= 39.9,"Walking against the roll he stays on, the whole run, longer (%.1f s vs %.1f s)" % [keeping,still])
	print("     tumble: still %.1f s, keeping %.1f s of 40, rolled %.2f rad" % [still,keeping,trap.roll])
	# Carried, not teleported: no frame of a keeper moves more than the surface could.
	var worst := 0.0
	trap.reset()
	study.place(trap.top_point(),Vector2(0.0,-1.0))
	study.script_want = Vector2.ZERO
	await _tick(2)
	var last := m.feet
	for i in range(120):
		await _tick(1)
		worst = maxf(worst,m.feet.distance_to(last))
		last = m.feet
	check(worst < p.run*DT*3.0+float(trap.knob("size"))*float(trap.knob("spin"))*DT*2.0,"...carried by the surface, never jumped (worst step %.3f m)" % worst)
	trap.reset()

func _ray() -> void:
	var trap: Node3D = study.traps.named("ray")
	check(trap != null and trap.danger() == 5,"The yard has the Sky Ray, cost 4 over the void")
	# Carried along the path.
	trap.reset()
	study.place(trap.body.global_position+Vector3(0.0,0.2,0.0),Vector2(0.0,-1.0))
	study.script_want = Vector2.ZERO
	await _tick(2)
	var start: Vector3 = m.feet
	var start_body: Vector3 = trap.body.global_position
	await _tick(180)
	var local: Vector3 = trap.body.global_transform.affine_inverse()*m.feet
	var moved := m.feet.distance_to(start)
	check(trap.on_back(m.feet) or absf(local.x) < float(trap.knob("width")),"He rides it: still on its back after 3 s (local %s)" % str(local.snapped(Vector3.ONE*0.01)))
	check(moved > float(trap.knob("speed"))*3.0*0.8 and trap.body.global_position.distance_to(start_body) > 5.0,"...his world position follows it (moved %.1f m, it moved %.1f)" % [moved,trap.body.global_position.distance_to(start_body)])
	check(m.feet.distance_to(trap.body.global_position) < float(trap.knob("long")),"...within its length of it (%.1f m)" % m.feet.distance_to(trap.body.global_position))
	# A hard bank: stood still he slides to the low edge.
	trap.reset()
	trap.s = trap.straight()+float(trap.knob("radius"))*PI*0.5
	trap.bank = -float(trap.knob("max_bank"))
	trap.knobs["bank_lag"] = 100.0
	trap._pose()
	await physics_frame
	await physics_frame
	m.reset(trap.body.global_position+Vector3(0.0,0.25,0.0),0.0)
	study.script_want = Vector2.ZERO
	await _tick(3)
	var x0: float = (trap.body.global_transform.affine_inverse()*m.feet).x
	await _tick(60)
	var x1: float = (trap.body.global_transform.affine_inverse()*m.feet).x
	# A right turn banks right wing down: the low edge is local +x.
	check(x1 > x0+0.5,"In a hard bank, standing still, he slides toward the low edge (local x %.2f to %.2f)" % [x0,x1])
	print("     ray: bank %.2f pitch %.2f" % [trap.bank,trap.pitch])
	trap.reset()
