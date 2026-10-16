extends SceneTree
## The stun in the stun yard (studies/stun_yard.gd), headless, through the
## real play loop: the study not scripted, its own `_process` frames, the
## stick and the buttons pressed as input actions (the pad layer's), the
## camera's yaw held along his facing:
##   - off the drop ladder's 0.75x column, a landing; off its 1.25x, laid
##     down (stunned "fall"), then up;
##   - off its 1.6x, the twirl pressed just before the touch: the roll, never
##     down;
##   - stood on the wind blaster's plate, he is blasted off, stunned with no
##     sail till his poise is back, and ends down on the floor below or
##     sailing;
##   - the chain: the kicker knocks him onto the waiting Sky Ray: down on
##     its back he is carried; with the tech on (T), the twirl pressed just
##     before the touch latches him onto a rail; a stunned body lying on the
##     seesaw dropper's far half is thrown by its block, still stunned.
##   godot --headless --path . --script tests/test_stun_yard.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
var failures := 0
var study: Node3D
var m: PilotMotor

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _hold(action: StringName, on: bool) -> void:
	if on: Input.action_press(action)
	else: Input.action_release(action)

func _let_go() -> void:
	for a: StringName in [&"move_forward",&"move_back",&"move_left",&"move_right",&"walk_jump",&"walk_twirl",&"walk_crouch"]:
		Input.action_release(a)

func _frame() -> void:
	study.set("_yaw",m.facing if m.move != "tumble" else study.get("_yaw"))
	await process_frame

func _go(key: int) -> void:
	_let_go()
	study.go_to(key)
	await process_frame
	await process_frame

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("stun yard test timed out"); quit(2))
	study = load("res://studies/stun_yard.tscn").instantiate()
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	var h: float = m.fall_stun_height()
	# The ladder: 0.75x, a landing.
	var low := await _step_off(2,false)
	check(not low.downed and low.landed,"Off the 0.75x column (%.1f m), a landing" % (h*0.75))
	var mid := await _step_off(5,false)
	check(mid.downed and mid.why == "fall" and mid.up,"Off the 1.25x column (%.1f m), laid down, then up (%.2f s)" % [h*1.25,mid.down_t])
	var rolled := await _step_off(6,true)
	check(rolled.rolled and not rolled.downed,"Off the 1.6x, twirl just before the touch: the roll, never down")
	# The blaster.
	await _blaster()
	# The chain.
	await _chain()
	_let_go()
	print("stun yard: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## Off ladder column `key`, walked off; with `roll`, the twirl pressed as the
## touch comes close. {landed, downed, why, up, down_t, rolled}.
func _step_off(key: int, roll: bool) -> Dictionary:
	await _go(key)
	var out := {"landed":false,"downed":false,"why":"","up":false,"down_t":0.0,"rolled":false}
	var pressed := false
	var t := 0.0
	_hold(&"move_forward",true)
	while t < 6.0:
		if not m.grounded: _hold(&"move_forward",false)
		if roll and not pressed and not m.grounded and m.velocity.y < -2.0:
			var under: float = m.feet.y-m.ground_y
			if under < -m.velocity.y*m.tech_window*0.5:
				pressed = true
				_hold(&"walk_twirl",true)
		elif pressed: _hold(&"walk_twirl",false)
		var was_air := not m.grounded
		await _frame()
		t += study.get_process_delta_time()
		if was_air and m.grounded: out.landed = true
		if m.move == "roll": out.rolled = true
		if m.downed():
			out.downed = true
			out.why = m.stunned
			out.down_t += study.get_process_delta_time()
		elif out.downed and m.grounded and m.move != "tumble":
			out.up = true
			break
		if out.landed and not out.downed and m.grounded and m.move != "roll" and t > 1.0: break
	_let_go()
	return out

func _blaster() -> void:
	await _go(10)
	var trap: Node3D = study.blaster
	# Onto its plate and stood there.
	var plate: Vector3 = trap.to_global(Vector3(0.0,0.0,-float(trap.knob("plate_at"))))
	study.place(plate,Vector2(0.0,-1.0))
	await process_frame
	var knocked := false
	var sail_early := false
	var poised := false
	var down_low := false
	var t := 0.0
	while t < 6.0:
		# Jump held and let go, over and over: the sail as soon as he can.
		_hold(&"walk_jump",int(t*20.0) % 2 == 0 and knocked)
		await _frame()
		t += study.get_process_delta_time()
		if m.move == "tumble" and not m.grounded: knocked = true
		if knocked and m.move == "sail" and not poised: sail_early = true
		if knocked and m.move != "tumble" and not m.grounded: poised = true
		if m.downed() and m.feet.y < -1.0: down_low = true
		if knocked and (down_low or m.move == "sail") and t > 1.0: break
	_let_go()
	check(knocked and not sail_early,"Blasted off the plate, stunned: no sail till his poise is back")
	check(poised or down_low,"Then poise back mid-air (%s) or down on the floor below (%s)" % [poised,down_low])

func _chain() -> void:
	var ray: Node3D = study.ray
	# Untouched: kicked onto the ray waiting, he lies on its back, carried.
	var res := await _kick(false)
	check(res.kicked,"The kicker knocks him toward the Sky Ray")
	check(res.down_on_ray,"Down on the ray's back he is carried (a body)")
	# With the tech, a press just before the touch latches him onto a rail.
	study.toggle_tech()
	check(m.tech,"T turns the tech on")
	res = await _kick(true)
	check(res.latched and ray.latches >= 1,"Tech on, pressed just before the touch: latched onto a rail (%d)" % ray.latches)
	study.toggle_tech()
	# The seesaw: a stunned body on its far half, the block falls, thrown.
	var saw: Node3D = study.seesaw
	_let_go()
	# Just past the pivot, so the tilt slides him slowly (it slides a body
	# down it as it slides a standing one).
	var far: Vector3 = saw.to_global(Vector3(0.0,0.3,saw.pivot_z()-saw.length()*0.5*0.3))
	study.place(far,Vector2(0.0,1.0))
	m.tumble_down = 30.0
	m.knock(Vector3(0.0,0.5,0.0))
	var thrown := false
	var t := 0.0
	while t < 12.0 and not thrown:
		await _frame()
		t += study.get_process_delta_time()
		if m.move == "tumble" and m.velocity.y > 4.0: thrown = true
	m.tumble_down = PilotMotor.TUMBLE_DOWN
	check(thrown,"A stunned body on the seesaw's far half is thrown by its block, still stunned (%.1f s)" % t)

## Onto the kicker once the ray waits at its stop; with `tech`, the twirl
## pressed just before the touch on its back.
func _kick(tech: bool) -> Dictionary:
	var ray: Node3D = study.ray
	await _go(11)
	var out := {"kicked":false,"down_on_ray":false,"latched":false}
	# Wait for the ray to come in and stop.
	var t := 0.0
	var was: Vector3 = ray.body.global_position
	while t < 8.0:
		await _frame()
		t += study.get_process_delta_time()
		var now: Vector3 = ray.body.global_position
		if t > 1.0 and now.distance_to(was) < 0.001: break
		was = now
	_hold(&"move_forward",true)
	var pressed := false
	t = 0.0
	while t < 5.0:
		if m.move == "tumble" or study.kicker.on_plate(m.feet): _hold(&"move_forward",false)
		if tech and not pressed and m.move == "tumble" and not m.grounded and m.velocity.y < 0.0:
			var top: float = ray.body.global_position.y
			if m.feet.y-top < -m.velocity.y*m.tech_window*0.5:
				pressed = true
				_hold(&"walk_twirl",true)
		elif pressed: _hold(&"walk_twirl",false)
		await _frame()
		t += study.get_process_delta_time()
		if m.move == "tumble": out.kicked = true
		if m.downed() and ray.on_back(m.feet) and ray._was_riding: out.down_on_ray = true
		if ray.holds_rail(): out.latched = true
		if out.latched or (out.down_on_ray and not tech): break
	_let_go()
	return out
