extends SceneTree
## The cannon (scripts/cannon/, studies/cannon_yard.tscn), headless, driven
## through the game's own input actions as the pad layer emits them
## (scripts/pad.gd: A is walk_jump, Y cannon_climb, B cannon_leave, the d-pad
## cannon_power_up/down, the left stick move_*; Input.action_press), not
## internal calls:
##   - walking onto kegs picks them up and they hover after him; the jump is
##     NOT muffled;
##   - A at the cannon starts operating it from outside (no jump); the stick
##     aims, the d-pad sets the power; A fires a keg (used, a marker, he stays
##     outside on the ground); a second keg after a power change lands
##     elsewhere; the camera follows the keg;
##   - Y climbs in, B climbs back out without firing, Y again and A launches
##     him: he lands on the last marker at the same aim and power;
##   - with no kegs A only clicks, and Y then A still launches him;
##   - the targets are reachable at their aims; a keg into the void leaves a
##     "lost" mark; R clears the markers.
##   godot --headless --path . --script tests/test_cannon.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Pad = preload("res://scripts/pad.gd")
const PadPrompt = preload("res://scripts/pad_prompt.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor
var field: Node3D
## The highest his feet went while the cannon was being worked from outside.
var top := -INF

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _tick(n: int) -> void:
	for i in range(n):
		study.tick(DT)
		top = maxf(top,m.feet.y)

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
	_jump_not_muffled()
	_ranging_then_launch()
	_no_kegs()
	_targets()
	_void()
	print("cannon: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## A button pressed and let go, a tick each.
func _press(action: StringName) -> void:
	Input.action_press(action)
	_tick(1)
	Input.action_release(action)
	_tick(1)

## The stick held `n` ticks.
func _hold(action: StringName, n: int) -> void:
	Input.action_press(action)
	_tick(n)
	Input.action_release(action)
	_tick(1)

func _put(at: Vector3, face := Vector2(0.0,-1.0)) -> void:
	study.place(at,face)
	_tick(3)

## Moved without the reset `place` does (it also resets the yard).
func _move(at: Vector3, face: Vector2) -> void:
	m.reset(at,PilotMotor.facing_of(face))
	study._yaw = m.facing
	_tick(3)

func _jump_peak(at: Vector3, keg: Node3D = null) -> float:
	_put(at)
	if keg != null: field.pick_up(keg)
	var peak := m.feet.y
	Input.action_press(&"walk_jump")
	for i in 90:
		study.tick(DT)
		peak = maxf(peak,m.feet.y)
		if i == 25: Input.action_release(&"walk_jump")
	Input.action_release(&"walk_jump")
	return peak-at.y

func _jump_not_muffled() -> void:
	var bare := _jump_peak(Vector3(7.0,0.0,0.0))
	var loaded_peak := _jump_peak(Vector3(2.0,0.0,6.0),field.kegs[1])
	check(field.carried.size() >= 1 and absf(loaded_peak-bare) < 0.03,"Carrying does not muffle the jump (%.3f m bare, %.3f m with a keg)" % [bare,loaded_peak])

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _fly_kegs_out(camera_check := false) -> float:
	var best := -1.0
	var i := 0
	while (not field._flying.is_empty() or not field.loading.is_empty()) and i < 900:
		_tick(1)
		i += 1
		if camera_check and not field._flying.is_empty() and i % 10 == 0:
			var k: Node3D = field._flying[0]
			var cam: Camera3D = study.camera
			var to := (k.global_position-cam.global_position).normalized()
			var facing := -cam.global_transform.basis.z
			best = maxf(best,facing.dot(to))
	return best

func _land() -> Vector3:
	var i := 0
	while i < 900:
		study.tick(DT)
		i += 1
		if m.grounded or m.feet.y < study.lost+1.0: break
	return m.feet

## Outside: standing on the ground beyond the base, not in the barrel.
func _outside(c: Node3D) -> bool:
	return field.mode == "operating" and m.grounded and absf(m.feet.y-c.global_position.y) < 0.05 \
		and _flat(m.feet,c.global_position) > float(c.knobs.base_width)*0.5 and study.figure.visible

func _ranging_then_launch() -> void:
	var a: Node3D = field.cannons[0]
	var rects: Dictionary = study.target_rects()
	# Walked onto the kegs with the stick: along z = 6 through two, then down
	# the middle through the third to the cannon.
	_put(Vector3(-6.0,0.0,6.0),Vector2(1.0,0.0))
	Input.action_press(&"move_forward")
	var i := 0
	while m.feet.x < 5.0 and i < 400:
		_tick(1)
		i += 1
	Input.action_release(&"move_forward")
	_tick(20)
	check(field.carried.size() == 2 and field.kegs[0].state == "carried","Walking onto kegs picks them up (%d)" % field.carried.size())
	var gap: float = field.kegs[0].global_position.distance_to(study.figure.global_position)
	check(gap < 1.8 and field.kegs[0].global_position.distance_to(field.kegs[0].home) > 0.5,"...and they hover along with him (%.2f m off)" % gap)
	_move(Vector3(0.0,0.0,4.5),Vector2(0.0,-1.0))
	Input.action_press(&"move_forward")
	i = 0
	while m.feet.z > -0.2 and i < 400:
		_tick(1)
		i += 1
	Input.action_release(&"move_forward")
	_tick(40)
	check(field.carried.size() == 3,"Three kegs in hand, walked up to the cannon")
	check(field.shown_prompt().contains("operate the cannon") and field.shown_prompt().contains("climb in") and field.shown_prompt().contains("3 kegs") and field.shown_prompt().contains("power 3/5"),"At the cannon the prompt says A operates, Y climbs in, the kegs and the power: %s" % field.shown_prompt())
	# A starts operating: no jump, he stands outside at the breech. Held, it
	# does nothing more.
	top = m.feet.y
	Input.action_press(&"walk_jump")
	_tick(30)
	Input.action_release(&"walk_jump")
	_tick(2)
	check(field.mode == "operating" and field.cannon == a and _outside(a),"A at the cannon starts operating it from outside, at the breech")
	check(top < 0.05 and a.shots == 0 and field.loading.is_empty() and field.carried.size() == 3,"...that A neither jumps nor fires, held or not (top %.3f m)" % top)
	check(field.shown_prompt().contains("fire a keg (3 left)") and field.shown_prompt().contains("step away") and field.shown_prompt().contains("climb in") and field.shown_prompt().contains("power 3/5"),"The prompt names each button: %s" % field.shown_prompt())
	Pad.set_pad(true)
	_tick(1)
	var pad_line := PadPrompt.plain(field.shown_prompt())
	Pad.set_pad(false)
	check(pad_line.contains("A fire a keg (3 left)") and pad_line.contains("Y climb in") and pad_line.contains("B step away") and pad_line.contains("DPAD power 3/5"),"On a pad the prompt draws the pad's buttons: %s" % pad_line)
	var cam: Camera3D = study.camera
	var back: Vector3 = cam.global_position-a.pivot()
	check(back.dot(a.direction()) < 0.0 and back.y > 0.0,"The camera stands behind and over the cannon")
	# Aim with the stick, power with the d-pad.
	var yaw0: float = a.aim_yaw
	var pitch0: float = a.pitch
	_hold(&"move_right",4)
	_hold(&"move_forward",4)
	check(a.aim_yaw < yaw0-0.03 and a.pitch > pitch0+0.03,"The stick aims the barrel (yaw %.1f deg, pitch %.1f deg)" % [rad_to_deg(a.aim_yaw),rad_to_deg(a.pitch)])
	check(_outside(a),"...and he keeps to the breech as it turns")
	_press(&"cannon_power_down")
	_press(&"cannon_power_down")
	check(a.power == 0 and field.shown_prompt().contains("power 1/5"),"The d-pad sets the power: %s" % field.shown_prompt())
	# The first keg.
	_press(&"walk_jump")
	check(field.loading.size() > 0 and field.carried.size() == 2 and a.shots == 0,"A takes a keg from the hover into the barrel (loading, not yet fired)")
	check(field.shown_prompt().contains("loading"),"...the prompt says so: %s" % field.shown_prompt())
	var seen := _fly_kegs_out(true)
	check(a.shots == 1 and field.markers.size() == 1 and field.carried.size() == 2,"...then fires it: one keg used, a marker placed (%s)" % (field.markers[0].kind if field.markers.size() > 0 else "none"))
	check(_outside(a) and top < 0.05,"...and he is still outside, on the ground (top %.3f m)" % top)
	check(seen > 0.95,"The camera follows the keg in flight (best %.3f)" % seen)
	# The second keg, a notch up: its marker is further.
	_press(&"cannon_power_up")
	check(a.power == 1,"The d-pad up a notch")
	_press(&"walk_jump")
	_fly_kegs_out()
	check(a.shots == 2 and field.markers.size() == 2 and field.carried.size() == 1,"A second keg fired")
	var mark1: Vector3 = field.markers[0].at
	var mark: Vector3 = field.markers[1].at
	check(field.markers[1].kind == "landed" and _flat(mark,a.global_position) > _flat(mark1,a.global_position)+1.0,"...more power, the marker moves further (%.1f m, then %.1f m)" % [_flat(mark1,a.global_position),_flat(mark,a.global_position)])
	check(_outside(a) and top < 0.05,"...he never left the ground")
	var aim := [a.aim_yaw,a.pitch,a.power]
	# Y in, B out without firing, Y in again.
	_press(&"cannon_climb")
	check(field.mode == "inside" and not study.figure.visible,"Y climbs into the barrel")
	check(field.shown_prompt().contains("launch yourself") and field.shown_prompt().contains("climb out") and field.shown_prompt().contains("power 2/5") and field.shown_prompt().contains("1 keg"),"...the prompt: %s" % field.shown_prompt())
	_hold(&"move_left",20)
	check(a.aim_yaw == aim[0] and a.pitch == aim[1],"Inside, the stick leaves the aim as tested")
	_press(&"cannon_leave")
	check(_outside(a) and a.shots == 2,"B climbs back out without firing")
	_press(&"cannon_climb")
	check(field.mode == "inside","Y climbs in again")
	_press(&"walk_jump")
	check(field.mode == "" and a.shots == 3 and not m.grounded,"A launches him")
	_tick(10)
	check(m.move != "sail","...and that A does not also open the sail")
	check([a.aim_yaw,a.pitch,a.power] == aim,"...at the aim and power of the last keg")
	var at := _land()
	var off := _flat(at,mark)
	check(off < 0.8 and absf(at.y-mark.y) < 0.1,"He lands on the last keg's marker (%.2f m off; mark %.1f, %.1f; him %.1f, %.1f)" % [off,mark.x,mark.z,at.x,at.z])
	check(m.move != "tumble" and rects.near.has_point(Vector2(at.x,at.z)),"...a launch, not a tumble, onto the near isle")

func _no_kegs() -> void:
	_put(Vector3(0.0,0.0,-0.5))
	var a: Node3D = field.cannons[0]
	_press(&"walk_jump")
	check(field.mode == "operating" and field.carried.is_empty(),"With no kegs, A still starts operating")
	check(field.shown_prompt().contains("fire a keg (none left)"),"...the prompt says none are left: %s" % field.shown_prompt())
	_press(&"walk_jump")
	_tick(30)
	check(a.shots == 0 and field.mode == "operating" and field.heard.any(func(h: Array) -> bool: return h[0] == &"click"),"A with no kegs only clicks")
	_press(&"cannon_climb")
	var from: float = m.feet.y
	_press(&"walk_jump")
	check(a.shots == 1 and field.mode == "" and m.velocity.length() > 5.0,"...Y then A still launches him (%.1f m/s)" % m.velocity.length())
	var high := from
	for i in 60:
		study.tick(DT)
		high = maxf(high,m.feet.y)
	check(high > from+2.0,"...up and away (%.1f m over the barrel)" % (high-from))

func _in(r: Rect2, p: Vector3) -> bool:
	return r.has_point(Vector2(p.x,p.z))

## The yard's targets at their aims (the aim set directly: a geometry check).
func _targets() -> void:
	var rects: Dictionary = study.target_rects()
	for pair: Array in [[0,"target_1"],[1,"target_2"]]:
		var c: Node3D = field.cannons[pair[0]]
		var aim: Dictionary = study.AIMS[pair[1]]
		_put(c.global_position+Vector3(2.5,0.0,0.0))
		_press(&"cannon_climb")
		c.set_aim(deg_to_rad(float(aim.yaw)),deg_to_rad(float(aim.pitch)))
		c.set_power(int(aim.notch))
		_press(&"walk_jump")
		var at := _land()
		check(_in(rects[pair[1]],at) and absf(at.y) < 0.1,"Y then A at %s's aim lands on it (%.1f, %.1f)" % [pair[1],at.x,at.z])

func _void() -> void:
	_put(Vector3(0.0,0.0,-0.5))
	var a: Node3D = field.cannons[0]
	field.pick_up(field.kegs[1])
	_press(&"walk_jump")
	a.set_aim(deg_to_rad(60.0),deg_to_rad(30.0))
	a.set_power(4)
	_press(&"walk_jump")
	_fly_kegs_out()
	var lost: Dictionary = field.markers[field.markers.size()-1]
	check(lost.kind == "lost" and absf(lost.at.y-a.global_position.y) < 0.3 and field.heard.any(func(h: Array) -> bool: return h[0] == &"lost"),"A keg into the void leaves a puff at the isle-top height and a lost sound (y %.2f)" % lost.at.y)
	_press(&"cannon_leave")
	check(field.mode == "" and m.grounded,"B steps away")
	field.reset()
	check(field.markers.is_empty() and field.kegs.all(func(x: Node3D) -> bool: return x.state == "laid"),"R clears the markers and brings the kegs back")
