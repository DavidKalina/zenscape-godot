extends SceneTree
## The hat hold in the game itself, rendered: the aqueduct isle (studies/
## aqueduct_isle.tscn) run as the player runs it, its own frame loop and
## input (not scripted), the keys pressed through Input as a player would.
## Set over the isle with room under him, Space opens the pocket sail; the
## chase camera's frames are kept as the hat comes off his head (opening),
## held, turning left and right, and as it folds back on; then a side view
## of the hold. Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1440x900 -s res://tools/capture_sail_hold.gd \
##     -- --no-title --out=captures/look-round4/hold
##   --up=<m> (22) how high over where he starts the sail is opened
##   --only=chase|side   one set
const DT := 1.0/60.0
var study: Node3D
var out := "captures/look-round4/hold"
var up := 22.0
var only := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		elif arg.begins_with("--up="): up = float(arg.trim_prefix("--up="))
		elif arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	run.call_deferred()

func still(label: String) -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var path := "%s/%s.png" % [out,label]
	root.get_texture().get_image().save_png(path)
	print("SAIL HOLD still %s (move %s, sail out %.2f)" % [path,study.motor.move,study.sail_wing.out])

func frames(n: int) -> void:
	for i in range(n): await process_frame

func tap(action: StringName) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)

func run() -> void:
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	while not study.get("flora_ready"): await process_frame
	Engine.max_fps = 60
	await frames(30)
	for hud in ["_hud","_layer"]:
		var node = study.get(hud)
		if node is CanvasItem: node.visible = false
	var start: Vector3 = study.motor.feet
	var face: Vector2 = study.start_face
	study.place(start+Vector3.UP*up,face)
	await frames(8)
	print("SAIL HOLD placed at %s, move '%s'" % [study.motor.feet,study.motor.move])
	# The opening and the fold are slowed (Engine.time_scale) so their
	# few tenths of a second show over several stills.
	Engine.time_scale = 0.15
	Input.action_press(&"walk_jump")
	await process_frame
	Input.action_release(&"walk_jump")
	if only != "side":
		# The opening: the hat off his head into his hands.
		for k in range(5):
			await still("chase-1-opening-%d" % k)
		Engine.time_scale = 1.0
		await frames(40)
		await still("chase-2-holding")
		Input.action_press(&"move_left")
		await frames(45)
		await still("chase-3-turning-left")
		Input.action_release(&"move_left")
		Input.action_press(&"move_right")
		await frames(70)
		await still("chase-4-turning-right")
		Input.action_release(&"move_right")
		await frames(40)
	Engine.time_scale = 1.0
	if only != "chase":
		# Side on to him, the camera's own: from his right, level with the hat.
		var at: Vector3 = study.figure.global_position
		var right: Vector3 = study.figure.global_transform.basis.x
		var cam: Camera3D = study.camera
		for k in range(3):
			study.set_process(false)
			at = study.figure.global_position
			cam.look_at_from_position(at+right*3.2+Vector3.UP*1.0,at+Vector3.UP*0.85)
			await still("side-%d" % k)
			study.set_process(true)
			await frames(20)
		study.set_process(true)
	# The fold: back on his head.
	Engine.time_scale = 0.15
	Input.action_press(&"walk_jump")
	await process_frame
	Input.action_release(&"walk_jump")
	for k in range(5):
		await still("chase-5-folding-%d" % k)
	Engine.time_scale = 1.0
	print("SAIL HOLD done")
	quit(0)
