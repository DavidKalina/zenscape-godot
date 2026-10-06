extends SceneTree
## Stills of the pad's prompts and focus (docs/gamepad.md): building with
## the pad's cursor and a seed in hand, walking, flying the plane, coming in
## to land, and the pause panel with the focus ring. Saves
## <out>/<view>.png (default /tmp/zenscape-gamepad-stills).
## Rendered (needs a window):
##   Godot --windowed --path . --resolution 1440x900 -s res://tools/still_pad_prompts.gd -- --no-title [--out=dir]
const Pad = preload("res://scripts/pad.gd")
var scene: Node3D
var out := "/tmp/zenscape-gamepad-stills"

func _initialize() -> void: run.call_deferred()

func seconds(s: float) -> void:
	await create_timer(s).timeout

func button(index: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(index: JoyButton) -> void:
	button(index,true)
	for i in range(3): await process_frame
	button(index,false)
	for i in range(3): await process_frame

func shot(view: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out.path_join(view+".png"))
	print("still: ",out.path_join(view+".png"))

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("pad stills timed out"); quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("manage_worlds",true)
	scene.places_path = "/private/tmp/zs-pad-stills-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,900))
	root.size = Vector2i(1440,900)
	scene.world_clock.running = false
	await seconds(2.0)
	var pad: Node = scene.pad
	var editor: Node = scene._chunk_editor
	# Building: the cursor on the land, a seed from the case on the D-pad.
	var middle: Vector3 = editor.terrain.to_global(Vector3(2.0,float(editor.data.ground_height(Vector2(2.0,1.0))),1.0))
	await tap(JOY_BUTTON_DPAD_RIGHT)
	pad._move_to(scene.camera.unproject_position(middle))
	await seconds(1.0)
	await shot("build")
	# Walking.
	await tap(JOY_BUTTON_B)
	await tap(JOY_BUTTON_BACK)
	await seconds(1.5)
	await shot("walk")
	# Flying, and coming in to land.
	button(JOY_BUTTON_A,true)
	await seconds(0.6)
	button(JOY_BUTTON_A,false)
	await seconds(2.5)
	await shot("plane")
	await tap(JOY_BUTTON_Y)
	await seconds(1.0)
	await shot("landing")
	await tap(JOY_BUTTON_B)
	await seconds(1.5)
	# The pause panel, a row down, the ring round it.
	await tap(JOY_BUTTON_START)
	await seconds(0.5)
	await tap(JOY_BUTTON_DPAD_DOWN)
	await seconds(0.6)
	await shot("pause")
	quit(0)
