extends SceneTree
## Stills of the pilot's moves in the character study (studies/
## character_study.tscn): crouched, mid long jump, sliding down the shaft's
## wall, kicking off it, and the pump. Needs a renderer (opens a window).
##   godot --path . --script tools/capture_character_moves.gd -- --no-title [OUT_DIR]
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var study: Node3D
var out := "/tmp/character_moves"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args(): if not a.begins_with("--"): out = a
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func tick(want: Vector2, jump: bool, crouch := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
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
	quit()
