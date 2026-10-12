extends SceneTree
## The giants (scripts/traps/trap_tumble.gd, trap_ray.gd) in the trap yard,
## headless, the pilot driven by scripted input:
##   - the Tumbling Block (through the real play loop: input actions, the
##     study's own frames) is a giant over open void; standing still he is
##     slid off into the void within one rhythm; its lurch throws a rider
##     near the leading edge; a station-keeper who never jumps the lurch is
##     thrown at the first face change (it can't be walked); a skilled
##     rider (uphill, hops, jumps each lurch) rides several and takes the
##     prize; the pocket carries him through a lurch to a step he hops up
##     from;
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
	# The ray first: the tumble's part runs the yard unscripted (every trap
	# stepped by real frames), the ray's on scripted ticks from a fresh yard.
	await _ray()
	await _tumble()
	print("trap giants: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## The Tumbling Block is played through the real play loop: the study not
## scripted, its own `_process` frames (at the project's frame rate), the
## stick and the jump pressed as input actions, the camera held looking
## along the route (-z) as a player would hold it.
var _jump_left := 0

func _play(way: float, jump: bool) -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"move_back")
	if way < 0.0: Input.action_press(&"move_forward")
	elif way > 0.0: Input.action_press(&"move_back")
	# A fresh press, held a few frames.
	if jump and _jump_left <= -2: _jump_left = 10
	if _jump_left > 0: Input.action_press(&"walk_jump")
	else: Input.action_release(&"walk_jump")
	_jump_left -= 1
	study.set("_yaw",0.0)

func _let_go() -> void:
	for action: StringName in [&"move_forward",&"move_back",&"walk_jump"]: Input.action_release(action)
	_jump_left = 0

## One real frame; its seconds. TRACE=1 prints each.
func _frame() -> float:
	await process_frame
	if OS.get_environment("TRACE") != "":
		var trap: Node3D = study.traps.named("tumble")
		print("  %s %.2f roll %.2f feet %s grounded %s move %s hold %s riding %s pocket %s slide %.2f off %s vel %s stick %s" % [trap.phase,trap.phase_t,trap.roll,(trap.to_local(m.feet)-trap.centre()).snapped(Vector3.ONE*0.01),m.grounded,m.move,m.hold,trap.riding(),trap.in_pocket(m.feet),trap.slide,trap.put_off,m.velocity.snapped(Vector3.ONE*0.01),Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")])
	return study.get_process_delta_time()

## Gone into the void: under the block's middle and not holding it.
func _in_void(trap: Node3D) -> bool:
	return m.feet.y < trap.to_global(trap.centre()).y-0.5 and not trap.riding()

## The block set with the rhythm at `phase`, `phase_t` in, the face at
## roll `base` on top, and him set down at `at` (in the block's own frame;
## the top's middle if INF). The yard's `place` rebuilds the traps, so the
## block is set after it.
func _set_on(trap: Node3D, at := Vector3.INF, phase := "rest", phase_t := 0.0, base := 0.0) -> void:
	_let_go()
	study.place(trap.top_point(),Vector2(0.0,-1.0))
	trap.set("_base",base)
	trap.roll = base
	trap.phase = phase
	trap.phase_t = phase_t
	trap._pose()
	if at != Vector3.INF: m.reset(trap.to_global(trap._transform()*at)+Vector3.UP*0.05,0.0)
	study.set("_yaw",0.0)
	await physics_frame

## A rider for `limit` s: `skill` 0 stands still, 1 keeps station walking
## uphill and hops what blocks him but never jumps the lurch (the face
## change "walked"), 2 also jumps at the end of the shudder (the skilled
## rider) and climbs from a hang. Returns {"t": seconds till the void (or
## limit), "lurches", "worst": the largest frame step past what the stone
## and a fall could make}.
func _ride(trap: Node3D, skill: int, limit: float) -> Dictionary:
	var p := Trap.pilot()
	var size: float = trap.knob("size")
	var rise := sqrt(2.0*float(p.jumps[0])/p.gravity)
	var t := 0.0
	var prev := m.feet
	var worst := 0.0
	var stuck := 0.0
	var last_on := INF
	while t < limit:
		var c: Vector3 = trap.to_global(trap.centre())
		var off := m.feet.z-c.z
		# Up to the middle at rest (the prize is there on face 2), the uphill
		# side as it tips; everything carries him back, so only uphill.
		var target := -size*0.15 if trap.phase == "tip" else 0.0
		var way := 0.0
		var jump := false
		if skill > 0:
			if off > target+0.2: way = -1.0
			# Pressing on and not getting on over the stone: hop it (a bar, a
			# wall, a step).
			var on_stone: float = trap.face_local(trap.top_face(),m.feet).z
			stuck = stuck+1.0/60.0 if way != 0.0 and m.grounded and on_stone > last_on-p.walk*0.3/60.0 else 0.0
			last_on = on_stone
			if stuck > 0.15: jump = true
			if m.hold == "hang": way = signf(-m.lip_out.y)
		if skill > 1 and trap.phase == "tip" and trap.until_lurch() <= rise*0.3 and m.grounded: jump = true
		_play(way,jump)
		var dt := await _frame()
		t += dt
		if not m.recovering():
			worst = maxf(worst,m.feet.distance_to(prev)-(PilotMotor.TERMINAL+absf(trap.lurch_rate())*size)*dt)
		prev = m.feet
		if _in_void(trap): break
	_let_go()
	return {"t":t,"lurches":trap.lurches,"worst":worst}

func _tumble() -> void:
	var trap: Node3D = study.traps.named("tumble")
	var p := Trap.pilot()
	check(trap != null and trap.danger() == 5,"The yard has the Tumbling Block, cost 4 over the void")
	var size: float = trap.knob("size")
	var height: float = preload("res://scripts/pilot_physics_ground.gd").HEAD*preload("res://scripts/world_scale.gd").wanderer
	check(size >= height*6.0,"It reads as a giant: %.1f m a side, %.1f of his heights" % [size,size/height])
	check(trap.open_below(),"...over open void: no floor a layer down in its lane")
	study.scripted = false
	var cycle: float = float(trap.knob("rest"))+float(trap.knob("tip_time"))+float(trap.knob("lurch"))
	var half := size*0.5
	# Standing still at the top's middle, from the start of a rest.
	await _set_on(trap)
	var still := await _ride(trap,0,cycle+6.0)
	check(_in_void(trap) and still.t < cycle+1.5,"Standing still he is slid off and into the void in %.1f s (a rhythm is %.1f s; %s)" % [still.t,cycle,trap.put_off])
	# The lurch throws a rider near the leading edge: on the tipped face a
	# body length in from it as the shudder starts, keeping his place
	# uphill (no jump).
	var shudder: float = float(trap.knob("tip_time"))-float(trap.knob("tell"))
	await _set_on(trap,Vector3(0.0,half,half-height*1.5),"tip",shudder)
	var held := 0.0
	while trap.phase != "rest" and held < 3.0:
		_play(-1.0,false)
		held += await _frame()
	_let_go()
	var thrown_how: String = trap.put_off
	held = 0.0
	while not _in_void(trap) and held < 3.0: held += await _frame()
	check(thrown_how == "thrown" and _in_void(trap),"The lurch throws a rider near the leading edge into the void (%s, %.1f s after)" % [thrown_how,held])
	# Walked, not jumped: a station-keeper who never jumps the lurch.
	await _set_on(trap)
	var walked := await _ride(trap,1,cycle*3.0)
	check(_in_void(trap) and walked.lurches <= 1 and trap.put_off in ["thrown","jolted"],"The face change can't be walked: keeping station without jumping the lurch he is thrown at lurch %d (%.1f s, %s)" % [walked.lurches,walked.t,trap.put_off])
	check(float(trap.knob("bevel")) == 0.0,"...the edges are knife edges at default knobs (bevel %.2f)" % float(trap.knob("bevel")))
	# The skilled rider: station uphill, hops the bar and walls, jumps at
	# the end of each shudder, climbs from a hang.
	await _set_on(trap)
	var rides := 4
	var skilled := await _ride(trap,2,cycle*float(rides)+cycle*0.5)
	check(not _in_void(trap) and skilled.lurches >= rides and trap.on_block(m.feet),"A skilled rider (uphill, hop, jump the lurch) rides %d lurches (%.1f s, %d lurched, thrown %d)" % [rides,skilled.t,skilled.lurches,trap.thrown])
	check(trap.prize_taken,"...and picks up the prize on face 2 as it comes up")
	var ramped: float = trap.pace
	check(ramped > 1.0,"...the pace ramps up as he rides (x%.2f)" % ramped)
	check(skilled.worst < 0.05,"...carried by the stone, never jumped (worst excess step %.3f m)" % skilled.worst)
	var heard: Array = trap.heard.map(func(h: Array) -> String: return String(h[0]))
	check("grind" in heard and "lurch" in heard and "slam" in heard,"...told: a grind in the shudder before each lurch, the lurch, the slam as it stops")
	# The pocket: in it as face 3 tips, he rides the lurch there and is set
	# on the step under the new top's leading lip; a hop and he is up.
	var pl: float = trap.knob("plate")
	var pocket: float = trap.knob("pocket")
	await _set_on(trap,Basis(Vector3.RIGHT,PI*1.5)*Vector3(0.0,half-pl,-half+pocket*0.5),"tip",shudder,PI*0.5)
	held = 0.0
	while trap.phase != "rest" and held < 3.0:
		_play(0.0,false)
		held += await _frame()
	check(trap.riding() and trap.put_off == "" and trap.in_pocket(m.feet),"In the pocket he rides the lurch, not thrown, onto the step it becomes (%s)" % trap.put_off)
	var up := false
	held = 0.0
	while held < 3.0 and not _in_void(trap):
		if m.grounded and trap.face_at(m.feet) == trap.top_face() and not trap.in_pocket(m.feet):
			up = true
			break
		_play(-1.0,m.grounded and absf(m.velocity.z) < p.walk*0.2)
		held += await _frame()
	_let_go()
	check(up,"...and from the step he hops up onto the new top (%.1f s)" % held)
	print("     tumble: still %.1f s; walked %d lurch(es); skilled %d lurches in %.1f s, pace x%.2f" % [still.t,walked.lurches,skilled.lurches,skilled.t,ramped])
	study.scripted = true
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
