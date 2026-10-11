extends SceneTree
## The lodestone on the aqueduct isle (studies/aqueduct_isle.gd, docs/design/
## isle-lodestone.md), headless: it rests humming on its floating stone and
## hums harder as the pilot nears; only standing on that stone can he pick
## it up; picked up, it floats into the air over his mitts and the camera
## pushes in; kept, it rides at his side; boarding the stone plane (scripts/
## stone_plane_figure.gd) seats it in the chamber, the needle shows and the
## seams wake (dark until then); the wing-seam compass lights the left wing
## for a target to the left, the right for the right, the top fin for one
## above (and the compass itself: on course, behind); arriving flashes;
## out of the plane he carries it again.
##   godot --headless --path . --script tests/test_isle_lodestone.gd
const Art = preload("res://studies/aqueduct_isle_art.gd")
const StoneFigure = preload("res://scripts/stone_plane_figure.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(150.0).timeout.connect(func() -> void: push_error("isle lodestone test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	study.stone_plane = true
	# The shard-only arrival (--no-chain); the ring and the chain are
	# tests/test_isle_hall_chain.gd's.
	study.chain_on = false
	root.add_child(study)
	current_scene = study
	while not study.flora_ready: await process_frame
	await physics_frame
	_compass()
	await _rests()
	_pickup()
	_carried()
	_seated()
	_points()
	_arrives()
	_leaves()
	print("PASS: isle lodestone" if failures == 0 else "FAIL: isle lodestone (%d)" % failures)
	quit(1 if failures > 0 else 0)

## The compass rule itself, as stone_render.py has it.
func _compass() -> void:
	var ahead := StoneFigure.compass(Vector3(0.0,0.0,-1.0))
	check(is_equal_approx(float(ahead.L),0.3) and is_equal_approx(float(ahead.R),0.3) and is_equal_approx(float(ahead.RING),1.0),"Dead ahead: both wings 0.3, the prow full (L %.2f R %.2f ring %.2f)" % [ahead.L,ahead.R,ahead.RING])
	var left := StoneFigure.compass(Vector3(-1.0,0.0,-1.732))
	check(is_equal_approx(float(left.L),1.0) and float(left.R) < 0.06,"30 degrees left: the left wing full, the right near dark (L %.2f R %.2f)" % [left.L,left.R])
	var behind := StoneFigure.compass(Vector3(0.2,0.0,1.0))
	check(float(behind.BK) > 0.99 and float(behind.R) == 1.0 and float(behind.L) == 0.0,"Behind to the right: the tail lit, the right wing full (BK %.2f)" % behind.BK)
	var up := StoneFigure.compass(Vector3(0.0,1.0,-1.0))
	check(float(up.UP) == 1.0 and float(up.DN) == 0.0,"45 degrees up: the top fin full")

func _ticks(seconds: float) -> void:
	for i in range(int(seconds/DT)): study.tick(DT)

## It rests over its floating stone, humming harder near; it can be picked
## up only from that stone.
func _rests() -> void:
	var stone: Node3D = study.lodestone
	var p: Dictionary = Art.platform(study.LODE_PLATFORM)
	check(stone != null and study.lode_state == "resting","The lodestone rests on the isle")
	check(stone.position.distance_to(p.at+Vector3.UP*study.LODE_HOVER) < 0.1,"Over the floating stone %s" % study.LODE_PLATFORM)
	_ticks(0.5)
	var far_hum: float = stone.hum_goal
	check(not study.can_pick(),"From the start it can't be picked up")
	study.place(Vector3(p.at.x,p.at.y-1.3,p.at.z+2.6),Vector2(0.0,-1.0))
	_ticks(0.3)
	check(not study.can_pick(),"Nor from the ground under its stone (feet %.2f)" % study.motor.feet.y)
	study.place(p.at+Vector3(0.6,0.05,0.0),Vector2(-1.0,0.0))
	_ticks(0.6)
	check(study.motor.grounded and absf(study.motor.feet.y-p.at.y) < 0.2,"Stood on the floating stone (feet %.2f, top %.2f)" % [study.motor.feet.y,p.at.y])
	check(float(stone.hum_goal) > 0.9 and far_hum < 0.05,"It hums harder near (%.2f far, %.2f near)" % [far_hum,stone.hum_goal])
	check(study.can_pick(),"On its stone it can be picked up")
	check(str(study._switch_hint.text).contains("E (pad A): pick up"),"The hint names the key")
	await process_frame

## E: held up over the mitts, the camera pushed in close.
func _pickup() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	study._unhandled_input(key)
	check(study.lode_state == "inspecting","E picks it up")
	_ticks(3.2)
	var stone: Node3D = study.lodestone
	var head: Vector3 = study.motor.feet
	check(stone.position.y > head.y+1.0 and Vector2(stone.position.x-head.x,stone.position.z-head.z).length() < 0.8,"Held up over him (%.2f m over his feet)" % (stone.position.y-head.y))
	check(study.camera.global_position.distance_to(stone.global_position) < 1.3,"The camera pushed in to it (%.2f m)" % study.camera.global_position.distance_to(stone.global_position))
	check(is_equal_approx(stone.scale.x,1.0),"At hand size")
	var turn: float = stone._yaw
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(80.0,0.0)
	study._unhandled_input(drag)
	check(absf(float(stone._yaw)-turn) > 0.5,"A drag turns it")
	study._unhandled_input(key)

## Kept: at his side, small, following as he walks.
func _carried() -> void:
	check(study.lode_state == "carried","E again keeps it")
	_ticks(1.0)
	var stone: Node3D = study.lodestone
	var side: float = stone.position.distance_to(study.figure.global_position+Vector3.UP*study.CARRY_AT.y)
	check(side < 0.6 and stone.scale.x < 0.6,"It rides at his side (%.2f m, scale %.2f)" % [side,stone.scale.x])
	check(str(study._switch_hint.text).contains("by your plane to board"),"The hint says to board")

## Boarded: the stone flies into the chamber, the needle shows, the pulse
## runs and the seams wake.
func _seated() -> void:
	study.board()
	var figure: Node3D = study.plane_figure
	check(figure is StoneFigure,"The isle flies the stone plane")
	check(study.lode_state == "seated" and figure.stone == study.lodestone,"Boarding seats the stone")
	check(not figure.seated and figure.wake == 0.0 and not figure._needle.visible,"Until it settles: seams dark, no needle")
	var level := 0.0
	for i in range(int(0.6/DT)): study.fly_step(DT,{})
	var mid: float = figure.wake
	for i in range(int(1.8/DT)): study.fly_step(DT,{})
	check(figure.seated and figure._needle.visible,"Settled in the chamber, the needle over it")
	check(study.lodestone.get_parent() == figure._chamber,"In the hull's chamber")
	check(mid < 1.0 and figure.wake == 1.0,"The seams woke behind the pulse (%.2f mid-way, %.2f)" % [mid,figure.wake])
	check(float(figure._glow.GAP.get_shader_parameter("energy")) > 1.0,"The gaps glow")

## The target left, right, then above: the wing (or fin) toward it lit.
func _points() -> void:
	var figure: Node3D = study.plane_figure
	for case: Array in [["left",Vector3(-1.0,0.0,-0.4),"L","R"],["right",Vector3(1.0,0.0,-0.4),"R","L"],["up",Vector3(0.0,1.2,-1.0),"UP","DN"]]:
		var away: Vector3 = case[1]
		for i in range(int(1.2/DT)):
			study.lode_target = figure.global_transform*(away.normalized()*200.0)
			study.fly_step(DT,{})
		var lit: String = case[2]
		var dark: String = case[3]
		var levels: Dictionary = figure.levels
		var bright: float = figure._glow[lit].get_shader_parameter("energy")
		var dim: float = figure._glow[dark].get_shader_parameter("energy")
		check(float(levels[lit]) > 0.85 and float(levels[dark]) < 0.15 and bright > dim*5.0,"Target %s: %s lit %.2f, %s %.2f (energy %.1f vs %.1f)" % [case[0],lit,levels[lit],dark,levels[dark],bright,dim])
		if case[0] == "up": check(absf(float(levels.L)-float(levels.R)) < 0.05,"Straight up ahead, both wings even (L %.2f R %.2f)" % [levels.L,levels.R])
	var aim: Vector3 = -figure._needle.global_basis.z
	var want: Vector3 = (study.lode_target-figure._needle.global_position).normalized()
	check(aim.dot(want) > 0.97,"The needle points at it (%.1f deg off)" % rad_to_deg(acos(clampf(aim.dot(want),-1.0,1.0))))
	check(figure.triangles() < 8000,"The stone plane costs %d triangles" % figure.triangles())

## Close by: a flash and the pop.
func _arrives() -> void:
	study.lode_target = study.plane.position+study.plane.forward()*12.0
	study.fly_step(DT,{})
	check(study.arrived and study._flash_left > 0.0,"Arriving flashes")

## Out: he carries it again; back in, it seats again.
func _leaves() -> void:
	study.leave_plane()
	check(study.lode_state == "carried" and study.lodestone.get_parent() == study and study.lodestone.visible,"Out of the plane he carries it")
	_ticks(0.5)
	study.board()
	check(study.lode_state == "seated" and study.plane_figure.stone == study.lodestone,"Back in, it seats again")
	study.leave_plane()
