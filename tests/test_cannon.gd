extends SceneTree
## The cannon (scripts/cannon/, studies/cannon_yard.tscn), headless, driven
## through the game's own input actions (scripts/pad.gd: what the pad's A, X,
## B and d-pad press; Input.action_press), not internal calls:
##   - walking onto a keg picks it up and it hovers after him; the jump is
##     NOT muffled;
##   - A at the cannon mans it and a keg in hand loads; A fires the keg (a
##     marker, the barrel empty); A again launches him, and he lands on the
##     keg's marker; X loads the next keg; B steps away;
##   - with no kegs, A launches him; the targets are reachable at their aims;
##   - a keg into the void leaves a "lost" mark; R clears the markers.
##   godot --headless --path . --script tests/test_cannon.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor
var field: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _tick(n: int) -> void:
	for i in range(n): study.tick(DT)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("cannon test timed out"); quit(2))
	study = load("res://studies/cannon_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	study.scripted = false
	m = study.motor
	field = study.cannon_field
	await physics_frame
	_pickup_and_jump()
	_flow()
	_empty_and_targets()
	_void()
	print("cannon: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## A button pressed and let go, a tick each.
func _press(action: StringName) -> void:
	Input.action_press(action)
	_tick(1)
	Input.action_release(action)
	_tick(1)

func _put(at: Vector3) -> void:
	study.place(at,Vector2(0.0,-1.0))
	_tick(3)

func _jump_peak(at: Vector3, keg: Node3D = null) -> float:
	_put(at)
	if keg != null: field.pick_up(keg)
	var top := m.feet.y
	Input.action_press(&"walk_jump")
	for i in 90:
		study.tick(DT)
		top = maxf(top,m.feet.y)
		if i == 25: Input.action_release(&"walk_jump")
	Input.action_release(&"walk_jump")
	return top-at.y

func _pickup_and_jump() -> void:
	var bare := _jump_peak(Vector3(7.0,0.0,0.0))
	var keg: Node3D = field.kegs[0]
	# Walked onto it with the stick, his real feet: picked up.
	_put(keg.home+Vector3(-2.0,0.0,0.0))
	Input.action_press(&"move_right")
	_tick(70)
	Input.action_release(&"move_right")
	check(field.carried.has(keg) and keg.state == "carried","Walking onto a keg picks it up")
	_tick(40)
	var gap: float = keg.global_position.distance_to(study.figure.global_position)
	check(gap < 1.8 and keg.global_position.distance_to(keg.home) > 0.5,"...and it hovers along with him (%.2f m off)" % gap)
	var loaded_peak := _jump_peak(Vector3(2.0,0.0,6.0),field.kegs[1])
	check(field.carried.size() >= 1 and absf(loaded_peak-bare) < 0.03,"Carrying does not muffle the jump (%.3f m bare, %.3f m with a keg)" % [bare,loaded_peak])
	for k: Node3D in field.kegs: field.pick_up(k)
	check(field.carried.size() <= int(field.knobs.max_kegs),"He can hold several kegs, up to the knob (%d)" % field.carried.size())

func _in(r: Rect2, p: Vector3) -> bool:
	return r.has_point(Vector2(p.x,p.z))

func _land() -> Vector3:
	var i := 0
	while i < 900:
		study.tick(DT)
		i += 1
		if m.grounded or m.feet.y < study.lost+1.0: break
	return m.feet

func _fly_keg_out() -> void:
	var i := 0
	while not field._flying.is_empty() and i < 900:
		_tick(1)
		i += 1

func _flow() -> void:
	var a: Node3D = field.cannons[0]
	var rects: Dictionary = study.target_rects()
	_put(a.global_position+Vector3(2.5,0.0,0.0))
	for k: Node3D in field.kegs: field.pick_up(k)
	check(field.carried.size() == 3,"Three kegs in hand")
	_press(&"walk_jump")
	check(field.aboard == a and a.loaded != null and field.carried.size() == 2,"A at the cannon mans it and loads a keg (2 left in hand)")
	check(field.shown_prompt().contains("fire keg") and field.shown_prompt().contains("load keg (2)"),"The prompt says so: %s" % field.shown_prompt())
	_tick(30)
	check(a.loaded != null and not a.loaded.visible,"...the keg slid into the barrel")
	a.set_aim(deg_to_rad(8.0),deg_to_rad(45.0))
	a.set_power(1)
	var shots: int = a.shots
	_press(&"walk_jump")
	_fly_keg_out()
	check(a.shots == shots+1 and a.loaded == null and field.markers.size() == 1 and field.markers[0].kind == "landed","A fires the keg: a marker, the barrel empty")
	check(field.aboard == a and field.shown_prompt().contains("launch yourself"),"...he stays in; the prompt now says launch yourself: %s" % field.shown_prompt())
	var mark: Vector3 = field.markers[0].at
	# X loads another and A flies it too; B steps away without firing.
	_press(&"cannon_load")
	check(a.loaded != null and field.carried.size() == 1,"X loads the next keg from the hover")
	_press(&"cannon_power_up")
	check(a.power == 2,"The d-pad sets the power")
	_press(&"cannon_power_down")
	_press(&"cannon_leave")
	check(field.aboard == null and a.loaded != null and m.grounded,"B steps away without firing (the keg stays loaded)")
	_press(&"walk_jump")
	check(field.aboard == a and a.loaded != null,"Manned again, the keg still in the barrel")
	a.set_aim(deg_to_rad(8.0),deg_to_rad(45.0))
	a.set_power(1)
	_press(&"walk_jump")
	_fly_keg_out()
	mark = field.markers[field.markers.size()-1].at
	_press(&"walk_jump")
	var at := _land()
	var off := Vector2(at.x-mark.x,at.z-mark.z).length()
	check(a.loaded == null and off < 0.8 and absf(at.y-mark.y) < 0.1,"With the barrel empty A launches him, and he lands on the keg's marker (%.2f m off; mark %.1f, %.1f; him %.1f, %.1f)" % [off,mark.x,mark.z,at.x,at.z])
	check(m.move != "tumble" and rects.near.has_point(Vector2(at.x,at.z)),"...a launch, not a tumble, onto the near isle")

func _empty_and_targets() -> void:
	field.reset()
	var a: Node3D = field.cannons[0]
	var rects: Dictionary = study.target_rects()
	var aim: Dictionary = study.AIMS.target_1
	_put(a.global_position+Vector3(2.5,0.0,0.0))
	_press(&"walk_jump")
	check(field.aboard == a and a.loaded == null and field.carried.is_empty(),"With no kegs, A mans the cannon with the barrel empty")
	a.set_aim(deg_to_rad(float(aim.yaw)),deg_to_rad(float(aim.pitch)))
	a.set_power(int(aim.notch))
	_press(&"cannon_load")
	check(a.loaded == null,"X with no kegs loads nothing")
	_press(&"walk_jump")
	var at := _land()
	check(_in(rects.target_1,at) and absf(at.y) < 0.1,"A launches him with no kegs; the narrow target is reachable at its aim (%.1f, %.1f)" % [at.x,at.z])
	var b: Node3D = field.cannons[1]
	aim = study.AIMS.target_2
	_put(b.global_position+Vector3(2.5,0.0,0.0))
	_press(&"walk_jump")
	b.set_aim(deg_to_rad(float(aim.yaw)),deg_to_rad(float(aim.pitch)))
	b.set_power(int(aim.notch))
	_press(&"walk_jump")
	at = _land()
	check(_in(rects.target_2,at) and absf(at.y) < 0.1,"...and the second cannon's target (%.1f, %.1f)" % [at.x,at.z])

func _void() -> void:
	field.reset()
	var a: Node3D = field.cannons[0]
	_put(a.global_position+Vector3(2.5,0.0,0.0))
	field.pick_up(field.kegs[1])
	_press(&"walk_jump")
	a.set_aim(deg_to_rad(60.0),deg_to_rad(30.0))
	a.set_power(4)
	_press(&"walk_jump")
	_fly_keg_out()
	var lost: Dictionary = field.markers[field.markers.size()-1]
	check(lost.kind == "lost" and absf(lost.at.y-a.global_position.y) < 0.3 and field.heard.any(func(h: Array) -> bool: return h[0] == &"lost"),"A keg into the void leaves a puff at the isle-top height and a lost sound (y %.2f)" % lost.at.y)
	field.reset()
	check(field.markers.is_empty() and field.kegs.all(func(x: Node3D) -> bool: return x.state == "laid"),"R clears the markers and brings the kegs back")
