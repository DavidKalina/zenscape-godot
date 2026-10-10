extends SceneTree
## The scene picker from the real title (docs/design/scene-picker.md), in the
## full cozy scene launched as the game is, in a scratch folder, headless,
## through injected joypad events:
##   - the front page has a quiet "Scenes" on its foot, before Settings;
##   - A on it opens the picker over the faded card, the pad's focus on its
##     first row and the stitched ring round it;
##   - B goes back to the card with "Scenes" in reach;
##   - A on an entry (the ruin kit gallery) changes scene to it, on its flags.
##   godot --headless --path . --script tests/test_scene_picker_title.gd
## Waits about a minute headless for the title's world.
## suite: slow
const Pad = preload("res://scripts/pad.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
var failures := 0
var world: Node3D

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func until(condition: Callable, seconds := 60.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	return true

func frames(n: int) -> void:
	for i in range(n): await process_frame

func tap(index: JoyButton) -> void:
	for down: bool in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = index
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(3)

func focus() -> Control:
	return world.get_viewport().gui_get_focus_owner()

func run() -> void:
	create_timer(600).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	var dir := "/private/tmp/scene-picker-title-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	world = load("res://studies/cozy_worlds.tscn").instantiate()
	world.set_meta("movie_capture",true)
	world.places_path = dir.path_join("places.json")
	root.add_child(world)
	current_scene = world
	check(await until(func() -> bool: return world.shell_ready,300.0),"The scene opens on the title")
	var pad: Node = world.pad
	check(pad.context() == "front","The front page")
	var scenes: Button = world._scenes
	var buttons: Array = world._menu.buttons
	var settings_at := -1
	for i in buttons.size():
		if buttons[i].text == "Settings": settings_at = i
	check(scenes != null and scenes.visible and not scenes.disabled and scenes.get("quiet") == true,"A quiet Scenes on the card's foot")
	check(buttons.find(scenes) == settings_at-1,"Scenes comes just before Settings")
	await until(func() -> bool: return world._menu.modulate.a >= 1.0 and scenes.modulate.a >= 1.0,10.0)
	# The pad in hand, Scenes in reach, A.
	await tap(JOY_BUTTON_DPAD_DOWN)
	scenes.grab_focus()
	await tap(JOY_BUTTON_A)
	var picker: Control = world.scene_picker
	check(picker != null and picker.visible,"A on Scenes opens the picker")
	check(world._menu.modulate.a == 0.0 and pad.context() == "front","The card fades under it; the pad still on the screens")
	check(focus() == picker.rows[0],"Its first row in reach")
	check(await until(func() -> bool: return pad.ring.target() == focus() and pad.ring._alpha > 0.9,8.0),"The stitched ring is round it")
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(focus() == picker.rows[1],"The D-pad walks it")
	await tap(JOY_BUTTON_B)
	check(not picker.visible and focus() == scenes,"B goes back to the card, Scenes in reach")
	check(await until(func() -> bool: return world._menu.modulate.a >= 1.0,3.0),"The card comes back")
	check(world.titled and not world.library_open,"Still on the title")
	# An entry.
	await tap(JOY_BUTTON_A)
	picker.present("ruin_kit")
	await frames(2)
	check(picker.entry_of[focus()].id == "ruin_kit","The ruin kit gallery in reach")
	await tap(JOY_BUTTON_A)
	var opened := await until(func() -> bool: return current_scene != null and current_scene.scene_file_path == "res://studies/ruin_kit_gallery.tscn",30.0)
	check(opened,"A on it changes scene to the ruin kit gallery")
	check(LaunchArgs.user_args()[0] == "--no-title" and LaunchArgs.overridden(),"On the entry's flags")
	check(root.get_node_or_null("SceneReturn") != null and root.get_node("SceneReturn").active,"With the way back")
	await frames(30)
	check(current_scene != null and is_instance_valid(current_scene),"The gallery runs")
	print("scene picker title: %d failures" % failures)
	quit(1 if failures else 0)
