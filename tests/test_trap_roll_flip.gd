extends SceneTree
## Rolling Logs and Flip Platforms (scripts/traps/trap_logs.gd, trap_flip.gd)
## in the trap yard (studies/trap_yard.tscn), headless, scripted input:
##   - sized from the pilot (radius, gap a share of a hop's reach; slab a half
##     second of walk);
##   - standing on a log he is carried by its spin (moved over time, not
##     teleported) and ends off it; a run across the logs makes it;
##   - standing on a flip slab he is off it after its flip; one hopping in
##     rhythm (waiting for a flat next slab) crosses the row.
##   godot --headless --path . --script tests/test_trap_roll_flip.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Trap = preload("res://scripts/traps/trap.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor
var logs: Node3D
var flip: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("trap roll flip test timed out"); quit(2))
	study = load("res://studies/trap_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	logs = study.traps.named("logs")
	flip = study.traps.named("flip")
	var p := Trap.pilot()
	check(logs != null and logs.logs.size() == 6 and logs.danger() == 2,"The yard has Rolling Logs: 6 logs, cost 2")
	check(flip != null and flip.slabs.size() == 7 and flip.danger() == 3,"The yard has Flip Platforms: 7 slabs, cost 3")
	check(is_equal_approx(logs.knob("radius"),p.walk*0.3) and float(logs.knob("gap")) < p.run*2.0*sqrt(2.0*p.jumps[0]/p.gravity) and float(logs.knob("spin")) < p.walk,"Logs sized from the pilot: radius of his walk, gap under a hop's reach, spin under his walk")
	check(is_equal_approx(flip.knob("length"),p.walk*0.5) and float(flip.knob("gap")) < float(logs.knob("gap"))+0.01,"Slabs sized from the pilot: a half second of walk long")
	await _frames(2)
	_logs_stand()
	_logs_run()
	_flip_stand()
	_flip_hop()
	print("trap roll flip: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _frames(n: int) -> void:
	for i in range(n): await physics_frame

func _tick(n: int) -> void:
	for i in range(n): study.tick(DT)

func _input(want: Vector2, jump := false) -> void:
	study.script_want = want
	study.script_jump = jump

func _set_on(trap: Node3D, at: Vector3) -> void:
	study.place(trap.to_global(at),Vector2(0.0,-1.0))
	_input(Vector2.ZERO)
	_tick(2)

func _logs_stand() -> void:
	logs.reset()
	_set_on(logs,logs.logs[2].top)
	var z0 := m.feet.z
	check(m.grounded and logs.log_at(m.feet) == 2,"Set on log 2 he stands on it")
	_tick(15)
	var d := m.feet.z-z0
	var want: float = logs.pace()*0.25
	check(m.grounded and logs.log_at(m.feet) == 2 and absf(d-want) < want*0.35 and d > 0.1,"Standing, the spin carries him back, not teleports him (%.2f m in 0.25 s, surface %.2f)" % [d,want])
	_tick(120)
	check(logs.log_at(m.feet) != 2 and (m.feet.y < -0.3 or m.hold != "" or logs.log_at(m.feet) >= 0),"Standing still he ends off the log (y %.2f, %s)" % [m.feet.y,m.hold])
	check(not (m.grounded and logs.log_at(m.feet) == 2),"...and is not on it")
	# Along-axis logs carry sideways.
	logs.reset()
	# The spin gains pace with time on them.
	logs.clock = 10.0
	check(logs.pace() > float(logs.knob("spin"))*1.5,"The spin speeds up with time on the logs (%.2f m/s)" % logs.pace())
	logs.reset()

func _logs_run() -> void:
	logs.reset()
	study.place(Vector3(logs.global_position.x,0.0,logs.global_position.z+logs.run_up()),Vector2(0.0,-1.0))
	_input(Vector2.ZERO)
	_tick(2)
	var end_z: float = logs.exit().origin.z-0.5
	var low := 0.0
	for i in range(420):
		var jump: bool = m.grounded and logs.log_at(m.feet) >= 0 and m.feet.z < logs.to_global(logs.logs[maxi(logs.log_at(m.feet),0)].top).z-0.1
		_input(Vector2(0.0,-1.0),jump)
		_tick(1)
		low = minf(low,m.feet.y)
		if m.feet.z < end_z and m.grounded: break
	check(m.feet.z < end_z and low > -0.3 and m.grounded,"Running across the logs he makes the far deck (z %.1f, lowest y %.2f)" % [m.feet.z,low])
	_input(Vector2.ZERO)

func _flip_stand() -> void:
	flip.reset()
	_set_on(flip,Vector3(0.0,0.0,flip.slabs[3].z))
	check(m.grounded and flip.slab_at(m.feet) == 3,"Set on flip slab 3 he stands on it")
	var tells: int = flip.heard.size()
	# Until its tell, then its flip.
	var guard := 0
	while int(flip.slabs[3].phase) == 0 and guard < 900:
		_tick(1)
		guard += 1
	check(int(flip.slabs[3].phase) == 1 and flip.heard.size() > tells,"The slab tells first, sounding (phase %d, heard %d)" % [flip.slabs[3].phase,flip.heard.size()])
	check(m.grounded and flip.slab_at(m.feet) == 3,"...with him still on it")
	_tick(int((float(flip.knob("tell"))+float(flip.knob("flip")))*60.0)+30)
	check(flip.slab_at(m.feet) != 3 and flip.knocks >= 1,"After its flip he is off it (knocked %d, y %.2f, on %d)" % [flip.knocks,m.feet.y,flip.slab_at(m.feet)])
	check(flip.slabs[3].flips == 1 and flip.upside_down(flip.slabs[3]),"...the slab lies upside down (its other face up)")
	check(flip.slabs[3].bottom_mat.albedo_color != flip.slabs[3].top_mat.albedo_color,"...in a different colour")

func _flip_hop() -> void:
	flip.reset()
	var p := Trap.pilot()
	var walk := Vector2(0.0,-0.75)
	study.place(Vector3(flip.global_position.x,0.0,flip.global_position.z+1.5),Vector2(0.0,-1.0))
	_input(Vector2.ZERO)
	_tick(2)
	var end_z: float = flip.exit().origin.z-0.5
	var low := 0.0
	var made := false
	var half: float = float(flip.knob("length"))*0.5
	var hops := 0
	var was_air := false
	for i in range(60*30):
		var on: int = flip.slab_at(m.feet) if m.grounded else -1
		var want := Vector2.ZERO
		var jump := false
		if m.grounded:
			# The surface's far edge (z): the deck's, or the slab's; is the next flat enough?
			var edge := flip.global_position.z
			var next := 0
			if on >= 0:
				edge = flip.to_global(Vector3(0.0,0.0,float(flip.slabs[on].z))).z-half
				next = on+1
			var go: bool = next >= flip.slabs.size() or flip.flat_for(next) > (1.2 if m.feet.z > edge+0.8 else 0.6)
			if m.feet.z > edge+0.35 and (go or m.feet.z > edge+0.8): want = walk
			elif go:
				want = walk
				jump = true
		else:
			want = walk
		if m.hold != "": jump = (i % 4 == 0)
		_input(want,jump)
		_tick(1)
		low = minf(low,m.feet.y)
		if was_air and m.grounded: hops += 1
		was_air = not m.grounded
		if m.feet.z < end_z and m.grounded:
			made = true
			break
	check(made and low > -0.3,"Hopping in rhythm (a hop to each flat slab) he crosses the row (z %.1f, lowest y %.2f, %d hops, %d knocks)" % [m.feet.z,low,hops,flip.knocks])
	_input(Vector2.ZERO)
