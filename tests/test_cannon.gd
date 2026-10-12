extends SceneTree
## The cannon (scripts/cannon/, studies/cannon_yard.tscn), headless, the
## pilot driven by scripted input:
##   - touching a keg picks it up and it hovers after him; the jump is NOT
##     muffled;
##   - firing yourself needs no keg, lands where the aim and power say
##     (the near isle, a narrow target);
##   - firing a keg uses one, flies the pilot's arc, and its marker is where
##     the pilot then lands at the same aim and power; into the void it
##     leaves a "lost" mark;
##   - no keg: a keg shot only clicks, yourself still fires.
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
	m = study.motor
	field = study.cannon_field
	await physics_frame
	_pickup_and_jump()
	_self_shots()
	_keg_shots()
	_no_keg()
	print("cannon: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _reset(at: Vector3) -> void:
	study.script_jump = false
	study.script_want = Vector2.ZERO
	study.place(at,Vector2(0.0,-1.0))
	_tick(3)

## The height of a standing jump from `at`.
func _jump_peak(at: Vector3, keg: Node3D = null) -> float:
	study.place(at,Vector2(0.0,-1.0))
	if keg != null: field.pick_up(keg)
	_tick(3)
	var top := m.feet.y
	study.script_jump = true
	for i in 90:
		study.tick(DT)
		top = maxf(top,m.feet.y)
		if i == 25: study.script_jump = false
	study.script_jump = false
	return top-at.y

func _pickup_and_jump() -> void:
	var bare := _jump_peak(Vector3(8.0,0.0,0.0) - Vector3(1.0,0.0,0.0))
	var keg: Node3D = field.kegs[0]
	_reset(keg.home+Vector3(0.0,0.0,0.3))
	_tick(2)
	check(field.carried.has(keg) and keg.state == "carried","Touching a keg picks it up")
	study.script_want = Vector2(1.0,0.0)
	_tick(60)
	study.script_want = Vector2.ZERO
	_tick(30)
	var gap: float = keg.global_position.distance_to(study.figure.global_position)
	check(gap < 1.5 and keg.global_position.distance_to(keg.home) > 2.0,"...and it hovers along after him (%.2f m off, %.1f m from where it lay)" % [gap,keg.global_position.distance_to(keg.home)])
	var loaded_peak := _jump_peak(Vector3(2.0,0.0,6.0),keg)
	check(field.carried.size() >= 1 and absf(loaded_peak-bare) < 0.03,"Carrying does not muffle the jump (%.3f m bare, %.3f m with a keg)" % [bare,loaded_peak])
	for k: Node3D in field.kegs: field.pick_up(k)
	field.knobs.max_kegs = 3
	check(field.carried.size() <= 3,"He can hold several kegs, up to the knob (%d)" % field.carried.size())

## Climbs into cannon `c` from the side (a use press), aim and power set.
func _board(c: Node3D, yaw_deg: float, pitch_deg: float, notch: int) -> void:
	study.place(c.global_position+Vector3(2.5,0.0,0.0),Vector2(0.0,-1.0))
	_tick(2)

func _climb(c: Node3D, yaw_deg: float, pitch_deg: float, notch: int) -> void:
	field.script_use = true
	_tick(2)
	c.set_aim(deg_to_rad(yaw_deg),deg_to_rad(pitch_deg))
	c.set_power(notch)

func _press_jump() -> void:
	study.script_jump = true
	_tick(1)
	study.script_jump = false

func _land() -> Vector3:
	var i := 0
	while i < 900:
		study.tick(DT)
		i += 1
		if m.grounded or m.feet.y < study.lost+1.0: break
	return m.feet

func _in(r: Rect2, p: Vector3) -> bool:
	return r.has_point(Vector2(p.x,p.z))

func _self_shots() -> void:
	var a: Node3D = field.cannons[0]
	var rects: Dictionary = study.target_rects()
	_board(a,0,0,0)
	check(field.carried.is_empty(),"No keg in hand")
	_climb(a,0.0,40.0,1)
	check(field.aboard == a,"Climbs in")
	_press_jump()
	var at := _land()
	check(a.shots == 1 and _in(rects.near,at) and absf(at.y) < 0.1,"Firing yourself needs no keg: lands on the near isle (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
	check(m.move != "tumble","...a launch, not a tumble (move '%s')" % m.move)
	var aim: Dictionary = study.AIMS.target_1
	_board(a,0,0,0)
	_climb(a,aim.yaw,aim.pitch,aim.notch)
	_press_jump()
	at = _land()
	check(_in(rects.target_1,at) and absf(at.y) < 0.1,"The narrow target is reachable at its aim and power (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
	var b: Node3D = field.cannons[1]
	aim = study.AIMS.target_2
	_board(b,0,0,0)
	_climb(b,aim.yaw,aim.pitch,aim.notch)
	_press_jump()
	at = _land()
	check(_in(rects.target_2,at) and absf(at.y) < 0.1,"...and the second cannon's (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])

func _fly_keg() -> void:
	field.script_keg = true
	_tick(1)
	var i := 0
	while not field._flying.is_empty() and i < 900:
		_tick(1)
		i += 1

func _keg_shots() -> void:
	var a: Node3D = field.cannons[0]
	_board(a,0,0,0)
	var k: Node3D = field.kegs[0]
	field.pick_up(k)
	_climb(a,8.0,45.0,1)
	var shots: int = a.shots
	_fly_keg()
	check(field.carried.is_empty() and k.state == "spent" and a.shots == shots+1,"Firing a keg uses one")
	check(field.markers.size() == 1 and field.markers[0].kind == "landed","...and leaves a landing marker")
	var mark: Vector3 = field.markers[0].at
	check(field.aboard == a and field.markers[0].node.is_inside_tree(),"...he stays in the cannon, the marker stays")
	_press_jump()
	var at := _land()
	var off := Vector2(at.x-mark.x,at.z-mark.z).length()
	check(off < 0.8 and absf(at.y-mark.y) < 0.1,"Then fired himself at the same aim and power, he lands on the keg's marker (%.2f m off; keg %.1f, %.1f; him %.1f, %.1f)" % [off,mark.x,mark.z,at.x,at.z])
	# Into the void.
	_board(a,0,0,0)
	field.pick_up(field.kegs[1])
	_climb(a,60.0,30.0,4)
	_fly_keg()
	var lost: Dictionary = field.markers[field.markers.size()-1]
	check(lost.kind == "lost" and absf(lost.at.y-a.global_position.y) < 0.3 and field.heard.any(func(h: Array) -> bool: return h[0] == &"lost"),"A keg into the void leaves a puff at the isle-top height and a lost sound (y %.2f)" % lost.at.y)
	field.reset()
	check(field.markers.is_empty() and field.kegs.all(func(x: Node3D) -> bool: return x.state == "laid"),"R clears the markers and brings the kegs back")

func _no_keg() -> void:
	field.reset()
	var a: Node3D = field.cannons[0]
	_board(a,0,0,0)
	_climb(a,0.0,40.0,1)
	var shots: int = a.shots
	field.script_keg = true
	_tick(3)
	check(a.shots == shots and field.markers.is_empty() and field.aboard == a and a.heard.any(func(h: Array) -> bool: return h[0] == &"click"),"With no keg, the keg button only clicks")
	_press_jump()
	var at := _land()
	check(a.shots == shots+1 and absf(at.y) < 0.1,"...and he can still fire himself")
