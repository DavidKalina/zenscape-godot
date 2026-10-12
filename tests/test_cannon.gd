extends SceneTree
## The cannon (scripts/cannon/, studies/cannon_yard.tscn), headless, the
## pilot driven by scripted input:
##   - touching a keg picks it up and it hovers after him; the jump is NOT
##     muffled; loading takes one keg from the hover (the big one first);
##   - a small keg's shot lands the pilot on the near isle, a big keg's on
##     the far isle (aim at the cannon's rest);
##   - an unloaded cannon doesn't fire (a dry click) and one keg is one shot.
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
	_loading()
	_shots()
	_dry_and_single()
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
	var many := 0
	for k: Node3D in field.kegs: if field.pick_up(k): many += 1
	field.knobs.max_kegs = 3
	check(field.carried.size() <= 3,"He can hold several kegs, up to the knob (%d)" % field.carried.size())

func _loading() -> void:
	var cannon: Node3D = field.cannons[0]
	study.place(cannon.global_position+Vector3(4.0,0.0,0.0),Vector2(0.0,-1.0))
	for k: Node3D in field.kegs: field.pick_up(k)
	check(field.carried.size() == 3,"Three kegs carried")
	study.script_want = Vector2(-1.0,0.0)
	_tick(60)
	study.script_want = Vector2.ZERO
	check(cannon.loaded == "big" and field.carried.size() == 2,"Walking up loads the big keg from the hover (%s, %d left)" % [cannon.loaded,field.carried.size()])

## Fires cannon `c` with a keg of `kind` and flies to the first touch;
## returns the feet where he came down.
func _fly(c: Node3D, kind: String) -> Vector3:
	study.place(c.global_position+Vector3(4.0,0.0,0.0),Vector2(0.0,-1.0))
	for k: Node3D in field.kegs:
		if k.kind == kind and field.pick_up(k): break
	study.script_want = Vector2(-1.0,0.0)
	for i in 120:
		study.tick(DT)
		if c.loaded != "": break
	study.script_want = Vector2.ZERO
	_tick(2)
	field.script_use = true
	_tick(2)
	var boarded: bool = field.aboard == c
	if not boarded: print("  (not aboard)")
	study.script_jump = true
	_tick(1)
	study.script_jump = false
	var launched: bool = field.aboard == null and not m.grounded
	if not launched: print("  (not launched)")
	var i := 0
	while i < 900:
		study.tick(DT)
		i += 1
		if m.grounded or m.feet.y < study.lost+1.0: break
	return m.feet

func _in(r: Rect2, p: Vector3) -> bool:
	return r.has_point(Vector2(p.x,p.z))

func _shots() -> void:
	var a: Node3D = field.cannons[0]
	var near := Rect2(-study.NEAR_WIDE*0.5,study.near_centre.z-study.NEAR_WIDE*0.5,study.NEAR_WIDE,study.NEAR_WIDE)
	var far := Rect2(-study.FAR_WIDE*0.5,study.far_centre.z-study.FAR_DEPTH*0.5,study.FAR_WIDE,study.FAR_DEPTH)
	var at := _fly(a,"small")
	check(_in(near,at) and absf(at.y) < 0.1 and a.shots == 1,"A small keg's shot lands on the near isle (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
	check(m.move != "tumble","...a launch, not a tumble (move '%s')" % m.move)
	at = _fly(a,"big")
	check(_in(far,at) and absf(at.y) < 0.1,"A big keg's shot reaches the far isle (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
	var b: Node3D = field.cannons[1]
	at = _fly(b,"small")
	check(_in(far,at) and absf(at.y) < 0.1,"The near isle's cannon with a small keg also reaches the far isle (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])

func _dry_and_single() -> void:
	field.reset()
	var a: Node3D = field.cannons[0]
	study.place(a.global_position+Vector3(2.5,0.0,0.0),Vector2(0.0,-1.0))
	_tick(2)
	field.script_use = true
	_tick(2)
	check(field.aboard == a and a.loaded == "","Climbs into an empty cannon")
	var was := m.feet
	study.script_jump = true
	_tick(1)
	study.script_jump = false
	_tick(30)
	check(field.aboard == a and a.shots == 0 and m.feet.distance_to(was) < 0.1 and a.heard.any(func(h: Array) -> bool: return h[0] == &"click"),"An unloaded cannon doesn't fire: it clicks")
	field.reset()
	for k: Node3D in field.kegs:
		if k.kind == "small": field.pick_up(k); break
	field.load_from_hover(a)
	check(a.loaded == "small","Loaded from the hover")
	field.board(a)
	study.script_jump = true
	_tick(1)
	study.script_jump = false
	_tick(5)
	check(a.shots == 1 and a.loaded == "","Fired")
	field.board(a)
	var peak := m.feet
	study.script_jump = true
	_tick(1)
	study.script_jump = false
	_tick(30)
	check(a.shots == 1 and field.aboard == a,"One keg is one shot: a second press only clicks")
