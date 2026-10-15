extends SceneTree
## The stun in the stun yard (studies/stun_yard.gd), headless, through the
## real play loop: the study not scripted, its own `_process` frames, the
## stick and the buttons pressed as input actions (the pad layer's), the
## camera's yaw held along his facing:
##   - off the drop ladder's 0.75x column, a landing; off its 1.25x, laid
##     down (stunned "fall"), then up;
##   - off its 1.6x, the twirl pressed just before the touch: the roll, never
##     down;
##   - stood on the blast post's deck, the dragon's air blast knocks him
##     off, stunned the whole throw (no sail), then laid down dizzy on the
##     floor below; T turns the tech on and off.
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
	# The blast post.
	await _blast_post()
	study.toggle_tech()
	check(m.tech,"T turns the tech on")
	study.toggle_tech()
	check(not m.tech,"T turns it off again")
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

func _blast_post() -> void:
	await _go(9)
	var knocked := false
	var sail_early := false
	var down_low := false
	var t := 0.0
	while t < 12.0:
		# Jump held and let go, over and over once knocked: the sail as
		# soon as he could have it (never, a hard hit).
		_hold(&"walk_jump",int(t*20.0) % 2 == 0 and knocked)
		await _frame()
		t += study.get_process_delta_time()
		if m.move == "tumble" and not m.grounded: knocked = true
		if knocked and m.move == "sail": sail_early = true
		if m.downed() and m.feet.y < -1.0: down_low = true
		if down_low: break
	_let_go()
	check(knocked and study.post.knocks >= 1,"The blast post's air blast knocks him off its deck (%d, %.1f s)" % [study.post.knocks,t])
	check(not sail_early,"A hard hit: stunned the whole throw, no sail")
	check(down_low,"Then laid down on the floor below")
