extends SceneTree
## The plane on the aqueduct isle (studies/aqueduct_isle.gd), headless:
## `board` (the --fly start) puts the pilot in the game's plane already
## flying ahead and above him, with the knife-edge drift (scripts/
## sky_plane.gd); it is bumped off the stone and flies on or sits on its
## wheels (never inside it, never a crash); nosed down at the turf it
## touches and sticks, never into it (the hand landing, scripts/
## manual_landing.gd; a dive too steep bounces instead, round 3, and
## tests/test_kit_isle_landing.gd has that and the rest); out in
## the air he stands on open turf near the plane, which goes back to its
## parked home; slow and braking it settles and stops but never gets out by
## itself; R in the plane puts him on foot at the start. The pad's right
## stick turns the camera on foot and in the plane, and R3 resets it.
##   godot --headless --path . --script tests/test_aqueduct_isle_plane.gd
const Art = preload("res://studies/aqueduct_isle_art.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("aqueduct isle plane test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.flora_ready: await process_frame
	await physics_frame
	check(str(study._switch_hint.text).contains("Walk to your plane"),"On foot the hint says to walk to the plane: '%s'" % study._switch_hint.text)
	_foot_look()
	_board()
	_plane_look()
	_drift()
	_bump()
	_skim()
	_back_on_foot()
	_touch_down()
	_reset()
	print("PASS: aqueduct isle plane" if failures == 0 else "FAIL: aqueduct isle plane (%d)" % failures)
	quit(1 if failures > 0 else 0)

func _fly(seconds: float, input: Dictionary) -> Dictionary:
	var out := {"in_stone":0,"lowest":INF,"skimmed":false}
	for i in range(int(seconds/DT)):
		if not study.flying: break
		study.fly_step(DT,input)
		if not study.flying: break
		if study._in_stone(): out.in_stone += 1
		var top: Variant = study.plane_ground(study.plane.position)
		if top != null: out.lowest = minf(out.lowest,float(study.plane.position.y)-float(top))
		if study.plane.skimming: out.skimmed = true
	return out

## Pushed or pressed, as the pad would.
func _r3() -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_RIGHT_STICK
	press.pressed = true
	study._unhandled_input(press)

## On foot the right stick orbits the walker's camera; R3 puts it back
## behind him at the default pitch.
func _foot_look() -> void:
	var yaw: float = study._yaw
	var polar: float = study._polar
	study.scripted = false
	Input.action_press(&"look_right",1.0)
	Input.action_press(&"look_up",0.6)
	for i in range(30): study.tick(DT)
	Input.action_release(&"look_right")
	Input.action_release(&"look_up")
	study.scripted = true
	check(absf(angle_difference(yaw,float(study._yaw))) > 0.5 and absf(float(study._polar)-polar) > 0.1,"On foot the right stick orbits the camera (yaw %.2f, pitch %.2f rad)" % [angle_difference(yaw,float(study._yaw)),float(study._polar)-polar])
	_r3()
	study.tick(0.0)
	check(absf(angle_difference(float(study._yaw),float(study.motor.facing))) < 0.01 and is_equal_approx(float(study._polar),study.CAM_POLAR),"R3 puts the camera back behind the pilot at the default pitch")

## In the plane the right stick swings the chase camera round it; let go,
## it holds a moment and swings back; R3 puts it back behind at once.
func _plane_look() -> void:
	var plane: RefCounted = study.plane
	plane.position = Vector3(110.0,Art.TOP+40.0,-80.0)
	_fly(1.0,{})
	var behind: Vector3 = (study.chase.eye-plane.position).normalized()
	Input.action_press(&"look_right",1.0)
	for i in range(40): study.fly_step(DT,study._fly_input(DT))
	Input.action_release(&"look_right")
	var free: Vector2 = study.chase.get(&"free")
	var swung: Vector3 = (study.chase.eye-plane.position).normalized()
	check(absf(free.x) > 1.0 and rad_to_deg(behind.angle_to(swung)) > 20.0,"In the plane the right stick swings the chase camera round it (%.2f rad, eye %.0f deg round)" % [free.x,rad_to_deg(behind.angle_to(swung))])
	for i in range(30): study.fly_step(DT,study._fly_input(DT))
	check(absf(float(study.chase.get(&"free").x)) > 0.9,"Let go, the look holds a moment (%.2f rad)" % study.chase.get(&"free").x)
	for i in range(int((study.LOOK_LINGER+2.0)/DT)): study.fly_step(DT,study._fly_input(DT))
	check(absf(float(study.chase.get(&"free").x)) < 0.05,"Then it swings back behind the plane (%.2f rad)" % study.chase.get(&"free").x)
	Input.action_press(&"look_right",1.0)
	for i in range(40): study.fly_step(DT,study._fly_input(DT))
	Input.action_release(&"look_right")
	_r3()
	check(study.chase.get(&"free") == Vector2.ZERO,"R3 puts the chase camera back behind the plane")
	check(str(study._switch_hint.text).contains("R3"),"The hint names the camera reset")

func _board() -> void:
	var feet: Vector3 = study.motor.feet
	study.board()
	check(study.flying,"Boarded (the --fly start)")
	var plane: RefCounted = study.plane
	var off: Vector3 = plane.position-feet
	check(off.y >= study.BOARD_UP-0.01 and Vector2(off.x,off.z).length() > 3.0,"It starts flying ahead of and above the pilot (%.1f m out, %.1f m up)" % [Vector2(off.x,off.z).length(),off.y])
	check(float(plane.speed) >= SkyPlane.CRUISE_SPEED*0.8,"At cruise, no runway (%.1f m/s)" % plane.speed)
	check(not study._in_stone(),"Not in stone")
	check(not study.figure.visible and study.plane_figure.is_inside_tree(),"The walker is hidden, the plane drawn")
	check(str(study._switch_hint.text).contains("knife edge") and str(study._switch_hint.text).contains("F (pad Y) flaps"),"The hint shows the knife edge and the flaps")
	check(is_equal_approx(float(plane.drift_strength),1.0),"The plane has the knife-edge drift (strength %.1f)" % plane.drift_strength)

func _drift() -> void:
	var plane: RefCounted = study.plane
	plane.position = Vector3(110.0,Art.TOP+40.0,-80.0)
	_fly(1.5,{"turn":1.0,"lean":1.0})
	check(float(plane.drift) > 0.6 and absf(float(plane.slip)) > 0.1,"On the knife edge a turn drifts (drift %.2f, slip %.1f deg)" % [plane.drift,rad_to_deg(plane.slip)])
	var speed := float(plane.speed)
	_fly(0.1,{})
	check(float(plane.speed) > speed+0.5,"Letting go gives the boost (%.1f to %.1f m/s)" % [speed,plane.speed])
	check(study.air != null and study.air._player.playing and float(study.air._hum_goal) > 0.0,"Flying, the plane sounds: wind and the propeller's hum")

## Flown straight at stone found round the start: bumped off and flying on.
func _bump() -> void:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var from: Vector3 = study.start+Vector3.UP*2.5
	var target := {}
	for i in range(24):
		var a := TAU*i/24.0
		var ray := PhysicsRayQueryParameters3D.create(from,from+Vector3(cos(a),0.0,sin(a))*30.0,1)
		ray.exclude = study._turf_rids
		var hit := space.intersect_ray(ray)
		if not hit.is_empty() and (hit.normal as Vector3).y < 0.4 and from.distance_to(hit.position) > 9.0:
			target = {"at":hit.position,"way":Vector3(cos(a),0.0,sin(a))}
			break
	check(not target.is_empty(),"Stone stands near the start to fly at")
	if target.is_empty(): return
	var plane: RefCounted = study.plane
	var way: Vector3 = target.way
	plane.launch((target.at as Vector3)-way*8.0,atan2(-way.x,-way.z),SkyPlane.CRUISE_SPEED,false)
	study.bumps = 0
	var out := _fly(2.0,{})
	print("  bumped %d times off stone at %s" % [study.bumps,target.at])
	check(study.bumps > 0,"Flown at stone, it bumps (%d)" % study.bumps)
	check(out.in_stone == 0,"Never left inside stone (%d frames)" % out.in_stone)
	check(study.flying and (float(plane.speed) >= SkyPlane.SLOW or study.hand_landing.on_ground()),"And flies on, or sits on its wheels (%.1f m/s, %s), never a crash" % [plane.speed,study.hand_landing.NAMES[study.hand_landing.phase]])

## A stretch of open, nearly flat turf RUN m long on the near island:
## {at (its top), way}.
const RUN := 24.0
func _open_run() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	for gx in range(16):
		for gz in range(12):
			var top: Vector3 = study._turf_top(space,60.0+gx*5.0,-20.0+gz*4.0)
			if top == Vector3.INF: continue
			for d in range(8):
				var way := Vector3(cos(TAU*d/8.0),0.0,sin(TAU*d/8.0))
				var ok := true
				for s in range(1,7):
					var p := top+way*RUN*s/6.0
					var there: Vector3 = study._turf_top(space,p.x,p.z)
					if there == Vector3.INF or absf(there.y-top.y) > 0.8: ok = false
				var ray := PhysicsRayQueryParameters3D.create(top+Vector3.UP*1.5,top+Vector3.UP*1.5+way*RUN,1)
				ray.exclude = study._turf_rids
				if ok and space.intersect_ray(ray).is_empty() and study._room_for_pilot(space,top): return {"at":top,"way":way}
	return {}

## Nosed down over the turf, low (not a dive steep enough to bounce): it
## touches and sticks, never sinks in.
func _skim() -> void:
	var run := _open_run()
	check(not run.is_empty(),"Open turf to touch found")
	if run.is_empty(): return
	var way: Vector3 = run.way
	study.fly_from((run.at as Vector3)+Vector3.UP*2.0,atan2(-way.x,-way.z))
	var out := _fly(1.2,{"pitch":-0.6})
	check(not (study.hand_landing.stats.touches as Array).is_empty() and study.hand_landing.on_ground(),"Nosed down at the turf, it touches and sticks (%s)" % study.hand_landing.last_touch)
	check(out.lowest > 0.25,"Never into the turf (lowest %.2f m over it)" % out.lowest)

func _back_on_foot() -> void:
	var plane: RefCounted = study.plane
	plane.position = study.start+Vector3(0.0,12.0,0.0)
	var near: Vector3 = plane.position
	study.leave_plane()
	check(not study.flying and study.figure.visible and study.parked and bool(study.plane_figure.parked),"Out in the air: back on foot, the plane parked at its home")
	check(not study.air._player.playing,"And its sound stops")
	var feet: Vector3 = study.motor.feet
	check(Vector2(feet.x-near.x,feet.z-near.z).length() < 6.0,"He stands near where the plane was (%.1f m off)" % Vector2(feet.x-near.x,feet.z-near.z).length())
	var top: Variant = study.plane_ground(feet+Vector3.UP*0.5)
	check(top != null and absf(float(top)-feet.y) < 0.3,"On the turf")
	for i in range(30): study.tick(DT)
	check(study.motor.grounded and study.motor.feet.distance_to(feet) < 1.0,"And stands there walking (grounded, %.2f m moved)" % study.motor.feet.distance_to(feet))
	check(str(study._switch_hint.text).contains("Walk to your plane"),"The hint is the on-foot one again")

## Low over the turf, braking: it settles and stops on its wheels, and
## never gets out by itself.
func _touch_down() -> void:
	study.board()
	var plane: RefCounted = study.plane
	var run := _open_run()
	if run.is_empty(): return
	var way: Vector3 = run.way
	plane.launch((run.at as Vector3)+Vector3.UP*1.5,atan2(-way.x,-way.z),SkyPlane.BRAKE_SPEED,false)
	study.hand_landing.begin(plane)
	var flew := 0.0
	while study.flying and flew < 6.0 and study.hand_landing.phase != study.hand_landing.STOPPED:
		study.fly_step(DT,{"brake":1.0,"pitch":-0.3})
		flew += DT
	check(study.flying and study.hand_landing.phase == study.hand_landing.STOPPED,"Slow and braking over the turf it settles and stops (after %.1f s, %s)" % [flew,study.hand_landing.last_touch])
	for i in range(30): study.fly_step(DT,{"brake":1.0})
	check(study.flying,"And never gets out by itself")

func _reset() -> void:
	study.board()
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	study._unhandled_input(key)
	check(not study.flying and study.motor.feet.distance_to(study.start) < 0.5,"R in the plane: on foot at the start")
