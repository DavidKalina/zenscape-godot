extends SceneTree
## The character study (studies/character_study.tscn), headless: the greybox
## room stands, and the pilot, his motor answered from its colliders
## (scripts/pilot_physics_ground.gd), stands on the floor, runs into a wall
## and stops at it (and slides along it), walks under the low bridge and,
## up its ramp, on top of it, bumps his head jumping under it, wades into
## the pool and swims where it is deep, and walked slowly off the pit's edge
## lowers himself to hang from it; long-jumped at the gap station he
## crosses 3.5 m and not 4; kicked up the wall-jump shaft he reaches its
## lip and climbs out. The motor's feel, turned live, starts as its
## constants.
##   godot --headless --path . --script tests/test_character_study.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## `frames` steps of the pilot, the stick at `want` and the jump `jump`;
## `each` sees the motor after every one.
func drive(want: Vector2, jump: bool, frames: int, each := Callable()) -> void:
	study.script_want = want
	study.script_jump = jump
	for i in range(frames):
		study.tick(DT)
		if each.is_valid(): each.call(study.motor)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("character study test timed out"); quit(2))
	var began := Time.get_ticks_msec()
	study = load("res://studies/character_study.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	print("     walking %.2f s after the scene was added" % ((Time.get_ticks_msec()-began)/1000.0))
	var m: PilotMotor = study.motor
	# The feel starts as the constants.
	check(m.run == PilotMotor.RUN and m.gravity == PilotMotor.GRAVITY and m.jumps == PilotMotor.JUMPS and m.coyote == PilotMotor.COYOTE,"The motor's feel starts as its constants")
	check(study.get_child_count() > 100,"The room is built (%d nodes)" % study.get_child_count())
	# Standing.
	drive(Vector2.ZERO,false,30)
	check(m.grounded and absf(m.feet.y) < 0.01,"He stands on the floor (feet %.3f)" % m.feet.y)
	# A jump from a stand reaches the first jump's height, and is measured.
	drive(Vector2.ZERO,true,40)
	drive(Vector2.ZERO,false,40)
	var jumped: Dictionary = study.last_jump
	check(not jumped.is_empty() and absf(float(jumped.peak)-float(PilotMotor.JUMPS[0])) < 0.01 and m.grounded,"A held jump from a stand peaks at %.3f m (JUMPS[0]) and lands" % float(jumped.get("peak",0.0)))
	# The room's wall.
	study.place(Vector3(0.0,0.0,29.5),Vector2(0.0,1.0))
	drive(Vector2(0.0,1.0),false,120)
	check(m.feet.z < 32.0-0.2 and m.feet.z > 31.0 and absf(m.feet.y) < 0.01,"Run into the room's wall, he stops at it (z %.2f)" % m.feet.z)
	# The step ladder's 2.4 m block, square on and at a slant.
	study.place(Vector3(29.0,0.0,23.0),Vector2(0.0,1.0))
	drive(Vector2(0.0,1.0),false,120)
	check(m.feet.z < 25.5-0.2 and m.feet.z > 24.8 and absf(m.feet.y) < 0.01,"Into a 2.4 m block, he stops at its face (z %.2f)" % m.feet.z)
	study.place(Vector3(0.0,0.0,30.5),Vector2(0.0,1.0))
	drive(Vector2(-1.0,1.0).normalized(),false,60)
	check(m.feet.z < 32.0-0.2 and m.feet.x < -1.5,"Run at the wall at a slant, he slides along it (x %.2f, z %.2f)" % [m.feet.x,m.feet.z])
	# A step he can walk up, and one he can't.
	study.place(Vector3(11.0,0.0,24.0),Vector2(0.0,1.0))
	drive(Vector2(0.0,1.0),false,45)
	check(absf(m.feet.y-0.45) < 0.01,"He walks up the 0.45 m block (feet %.2f)" % m.feet.y)
	study.place(Vector3(14.0,0.0,23.5),Vector2(0.0,1.0))
	drive(Vector2(0.0,1.0),false,90)
	check(absf(m.feet.y) < 0.01 and m.feet.z < 25.5,"The 0.6 m block stops him (feet %.2f, z %.2f)" % [m.feet.y,m.feet.z])
	# Under the low bridge, and on it.
	study.place(Vector3(0.0,0.0,5.0),Vector2(0.0,1.0))
	var highest := [0.0]
	drive(Vector2(0.0,1.0),false,100,func(mm: PilotMotor) -> void: highest[0] = maxf(highest[0],mm.feet.y))
	check(m.feet.z > 11.0 and highest[0] < 0.01,"He walks under the low bridge (z %.2f, highest %.2f)" % [m.feet.z,highest[0]])
	study.place(Vector3(0.0,0.0,9.0),Vector2(0.0,1.0))
	highest[0] = 0.0
	drive(Vector2.ZERO,true,30,func(mm: PilotMotor) -> void: highest[0] = maxf(highest[0],mm.feet.y))
	drive(Vector2.ZERO,false,60)
	check(highest[0] < 1.4-1.0 and m.grounded and absf(m.feet.y) < 0.01,"Jumping under it, he bumps his head (rose %.2f m) and comes down under it" % highest[0])
	study.place(Vector3(-12.5,0.0,9.0),Vector2(1.0,0.0))
	drive(Vector2(1.0,0.0),false,150)
	check(m.grounded and absf(m.feet.y-1.7) < 0.02 and m.feet.x > -6.0,"Up its ramp, he stands on top of it (%.2f, %.2f)" % [m.feet.x,m.feet.y])
	study.place(Vector3(0.0,1.7,9.0),Vector2(0.0,1.0))
	drive(Vector2.ZERO,false,30)
	check(m.grounded and absf(m.feet.y-1.7) < 0.01,"Set on the deck, he stands on it (feet %.2f)" % m.feet.y)
	# The pool: in down the beach, wading, then swimming.
	study.place(Vector3(15.0,0.0,5.0),Vector2(1.0,0.0))
	var waded := [false,false]
	drive(Vector2(1.0,0.0),false,360,func(mm: PilotMotor) -> void:
		if mm.grounded and mm.wade > PilotMotor.WADE_FROM: waded[0] = true
		if mm.swimming: waded[1] = true)
	check(waded[0],"He wades in down the beach")
	check(waded[1] and m.swimming and absf(m.surface-(-0.3)) < 0.01,"Deeper, he swims (surface %.2f)" % m.surface)
	# The pit: walked slowly off its edge, he lowers himself to hang.
	study.place(Vector3(-10.8,0.0,-23.5),Vector2(0.0,1.0))
	var hung := [false]
	drive(Vector2(0.0,0.4),false,240,func(mm: PilotMotor) -> void: if mm.hold == "hang": hung[0] = true)
	check(hung[0],"Walked slowly off the pit's edge, he hangs from it (%s)" % m.hold)
	# A jump at the 1.7 m catch wall: caught.
	study.place(Vector3(6.0,0.0,-27.4),Vector2(0.0,-1.0))
	var caught := [false]
	drive(Vector2(0.0,-0.3),true,40,func(mm: PilotMotor) -> void: if mm.on_ledge(): caught[0] = true)
	check(caught[0],"A jump at the 1.7 m wall catches its lip (%s)" % m.hold)
	# The long jump across the gaps: from 0.2 m short of the deck's edge.
	for gap: Array in [[3.5,9.0,true],[4.0,12.0,false]]:
		study.place(Vector3(-29.5,1.2,gap[1]),Vector2(1.0,0.0))
		var went := [false,false]
		study.script_want = Vector2(1.0,0.0)
		for i in range(240):
			study.script_crouch = m.grounded and m.feet.x > -25.8
			study.script_jump = m.feet.x > -25.2
			study.tick(DT)
			if m.move == "long": went[0] = true
			if went[0] and (m.grounded or m.on_ledge()):
				went[1] = m.grounded and m.feet.y > 1.19 and m.feet.x > -25.0+float(gap[0])
				break
		study.script_crouch = false
		check(went[0] and went[1] == gap[2],"Long-jumped at the %.1f m gap, he %s (%s)" % [gap[0],"lands across" if gap[2] else "falls short",study.last_jump])
	# Up the wall-jump shaft: into a wall, kicked off it to the other, and up.
	study.go_to(9)
	study.place(Vector3(-9.6,0.0,-10.0),Vector2(-1.0,0.0))
	var way := Vector2(-1.0,0.0)
	var on_wall := 0
	var was := ""
	var kicks := []
	var out_top := false
	for i in range(1200):
		on_wall = on_wall+1 if m.move == "wall" else 0
		study.script_want = way
		study.script_jump = (m.move != "wall" and m.velocity.y > 0.0) or on_wall >= 5 or (m.grounded and m.feet.x < -10.2) or (m.on_ledge() and i%20 < 3)
		study.tick(DT)
		if m.move == "kick" and was != "kick":
			kicks.append(snappedf(m.feet.y,0.01))
			way = -way
		was = m.move
		if m.grounded and m.feet.y > 5.9:
			out_top = true
			break
	study.script_jump = false
	check(out_top and kicks.size() >= 3,"Kicked between the shaft's walls he reaches its 6 m lip and climbs out (kicks at %s m)" % [kicks])
	print("character study: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
