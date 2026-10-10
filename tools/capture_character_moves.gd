extends SceneTree
## Stills of the pilot's moves in the character study (studies/
## character_study.tscn): crouched, mid long jump, sliding down the shaft's
## wall, kicking off it, the pump; a plain jump rising and falling, the
## twirl, surfing the slide ramp, the side flip's tuck, and the climb half
## way. Needs a renderer (opens a window).
##   godot --path . --script tools/capture_character_moves.gd -- --no-title [OUT_DIR]
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var study: Node3D
var out := "/tmp/character_moves"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args(): if not a.begins_with("--"): out = a
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func tick(want: Vector2, jump: bool, crouch := false, twirl := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.script_twirl = twirl
	study.tick(DT)

func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out,name])
	print("CAPTURE ",name)

func run() -> void:
	study = load("res://studies/character_study.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	var m: PilotMotor = study.motor
	# Crouched after a run: the slide to a stop.
	study.place(Vector3(-20.0,0.0,27.0),Vector2(1.0,0.0))
	for i in range(40): tick(Vector2(1.0,0.0),false)
	for i in range(40): tick(Vector2(1.0,0.0),false,true)
	await shot("crouch")
	# The long jump over the 3.0 m gap, at its top.
	study.place(Vector3(-29.5,1.2,6.0),Vector2(1.0,0.0))
	for i in range(200):
		tick(Vector2(1.0,0.0),m.feet.x > -25.3,m.grounded and m.feet.x > -25.9)
		if m.move == "long" and m.velocity.y < 0.3: break
	await shot("long_jump")
	# The pump.
	study.place(Vector3(0.0,0.0,2.0),Vector2(0.0,-1.0))
	var landed := false
	for i in range(200):
		tick(Vector2(0.0,-0.5),not landed or m.grounded)
		if m.grounded and i > 5: landed = true
		if m.move == "pump" and m.velocity.y < 3.0: break
	await shot("pump")
	# The shaft: onto the wall, sliding.
	study.place(Vector3(-9.6,0.0,-10.0),Vector2(-1.0,0.0))
	for i in range(120):
		tick(Vector2(-1.0,0.0),m.grounded and m.feet.x < -10.0 or (m.velocity.y > 0.0 and m.move != "wall"))
		if m.move == "wall" and m.velocity.y < -1.0: break
	await shot("wall_slide")
	tick(Vector2(-1.0,0.0),true)
	for i in range(8): tick(Vector2(1.0,0.0),true)
	await shot("wall_kick")
	# A plain jump, going up and coming down.
	study.place(Vector3(0.0,0.0,2.0),Vector2(0.0,-1.0))
	for i in range(10): tick(Vector2.ZERO,false)
	for i in range(8): tick(Vector2(0.0,-0.3),true)
	await shot("jump_rise")
	for i in range(14): tick(Vector2(0.0,-0.3),true)
	await shot("jump_fall")
	for i in range(30): tick(Vector2.ZERO,false)
	# The twirl at a jump's top.
	for i in range(14): tick(Vector2.ZERO,true)
	tick(Vector2.ZERO,true,false,true)
	for i in range(6): tick(Vector2.ZERO,true)
	await shot("twirl")
	for i in range(60): tick(Vector2.ZERO,false)
	# Surfing the slide ramp.
	study.go_to(10)
	for i in range(90):
		tick(Vector2(0.0,-1.0),false,m.feet.z < 26.0)
		if m.move == "slide" and m.feet.z < 20.0: break
	await shot("slide")
	# The side flip, tucked.
	study.place(Vector3(54.5,0.0,-23.0),Vector2(0.0,1.0))
	var flipped := 0
	for i in range(120):
		var back := i >= 18
		tick(Vector2(0.0,-1.0) if back else Vector2(0.0,1.0),back and m.skidding and flipped == 0)
		if m.move == "flip": flipped += 1
		if flipped >= 16: break
	await shot("side_flip")
	# Climbing up a catch wall, half way.
	study.place(Vector3(6.0,0.0,-27.4),Vector2(0.0,-1.0))
	for i in range(60):
		tick(Vector2(0.0,-0.3),i < 20)
		if m.hold == "hang": break
	for i in range(10): tick(Vector2.ZERO,false)
	tick(Vector2.ZERO,true)
	for i in range(11): tick(Vector2.ZERO,false)
	await shot("climb")
	quit()
