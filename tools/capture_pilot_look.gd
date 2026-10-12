extends SceneTree
## Stills of the pilot's look (art/blender/pilot/pilot_build.py, his paint
## scripts/pilot_paint.gd, shaders/pilot_paint.gdshader) on the test island
## (studies/test_island.tscn): standing at the chase camera, running through
## the wheat, then close up in front, at three-quarters either side, the
## face in front and from the side, and from behind, standing.
## Rendered only when asked for (needs a window):
##   Godot --windowed --fixed-fps 60 --path . -s res://tools/capture_pilot_look.gd -- --no-title [--out=DIR]
## Writes DIR/<moment>.png (default /tmp/pilot_look) and quits.

const RUN_SHOTS := {"run_a":45,"run_b":70,"run_c":95}

var out := "/tmp/pilot_look"
var scene: Node3D

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(300.0).timeout.connect(func() -> void: push_error("pilot look capture timed out"); quit(2))
	scene = load("res://studies/test_island.tscn").instantiate()
	scene.places_path = OS.get_temp_dir().path_join("pilot-look-capture-%d" % Time.get_ticks_usec()).path_join("places.json")
	root.size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not scene.walk_ready: await process_frame
	for i in range(90): await process_frame
	await _save("stand")
	Input.action_press(&"move_forward")
	for i in range(100):
		await process_frame
		if RUN_SHOTS.values().has(i): await _save(RUN_SHOTS.find_key(i))
	Input.action_release(&"move_forward")
	for i in range(150): await process_frame
	await _save("stopped")
	# Close up, with a camera of our own.
	var eye: Node = scene.wanderer
	var figure: Node3D = eye.figure
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	var at := figure.global_position
	var ahead := -figure.global_basis.z.normalized()
	var side := figure.global_basis.x.normalized()
	for shot: Array in [["close_front",ahead*1.9+Vector3.UP*0.75,0.62],["close_three",(ahead+side*0.8).normalized()*2.0+Vector3.UP*0.85,0.6],
			["close_three_other",(ahead-side*0.8).normalized()*2.0+Vector3.UP*0.85,0.6],
			["face",ahead*0.9+Vector3.UP*0.85,0.82],["face_side",(ahead*0.5+side).normalized()*0.9+Vector3.UP*0.85,0.82],["close_back",(-ahead+side*0.5).normalized()*2.0+Vector3.UP*1.0,0.6]]:
		cam.global_position = at+shot[1]
		cam.look_at(at+Vector3.UP*shot[2])
		cam.make_current()
		for i in range(3): await process_frame
		await _save(shot[0])
	# The faces (scripts/pilot_figure.gd `express`), close in front.
	var body: Node = eye.body
	cam.global_position = at+ahead*1.1+Vector3.UP*0.95
	cam.look_at(at+Vector3.UP*0.88)
	for mood: String in ["happy","surprise","squint"]:
		body.express(mood,3.0)
		for i in range(20): await process_frame
		await _save("face_"+mood)
	body.express("",0.0)
	# The cap float: a jump, then Jump again in the air opens the pocket
	# sail; the hat flies overhead, spinning. Seen from the side, following.
	cam.global_position = at+side*3.2+Vector3.UP*1.4
	cam.look_at(at+Vector3.UP*1.0)
	Input.action_press(&"walk_jump")
	for i in range(8): await process_frame
	Input.action_release(&"walk_jump")
	for i in range(14): await process_frame
	Input.action_press(&"walk_jump")
	for i in range(4): await process_frame
	Input.action_release(&"walk_jump")
	for i in range(30):
		await process_frame
		var p := figure.global_position
		cam.global_position = p+side*3.2+Vector3.UP*1.4
		cam.look_at(p+Vector3.UP*1.1)
		if i == 8 or i == 28: await _save("cap_float_%d" % i)
	print("PILOT LOOK captured ",out)
	quit(0)

func _save(moment: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(moment+".png"))
