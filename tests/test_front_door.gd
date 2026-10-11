extends SceneTree
## The game's front door (studies/zenscape.tscn, scripts/kit_isle/front_door.gd,
## docs/design/consolidation-audit.md round 1), headless, opened as the game
## opens it (the project's main scene, changed to):
##   - the project's main scene is the front door, and the way back from a
##     picked scene (scripts/scene_return.gd) goes to it;
##   - the veil is up while the isle builds, and gone once it's up;
##   - the original title over the isle: the card's Begin in reach, Scenes
##     and Quit quiet along its foot, the isle's own HUD hidden, the pilot
##     held, the camera orbiting the isle from above;
##   - nothing reaches the isle under the card (R, a click);
##   - Scenes opens the picker over the faded card, its Builder (old game)
##     row there (the cozy worlds scene, on its own title); Esc goes back;
##   - pad A on Begin: the card fades, the HUD is back, the pilot on foot by
##     the parked plane (Space boards it), the camera eased down behind him;
##   - `--no-title`: straight in, by the plane, no title.
##   godot --headless --path . --script tests/test_front_door.gd
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Catalog = preload("res://scripts/scene_catalog.gd")
const FRONT_DOOR := "res://studies/zenscape.tscn"
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func frames(n: int) -> void:
	for i in range(n): await process_frame

func until(condition: Callable, seconds := 60.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	return true

func tap_pad(index: JoyButton) -> void:
	for down: bool in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = index
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(3)

func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)

func run() -> void:
	create_timer(400).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	check(ProjectSettings.get_setting("application/run/main_scene") == FRONT_DOOR,"The project opens on the front door")
	var back: Node = preload("res://scripts/scene_return.gd").new()
	check(back.title_scene == FRONT_DOOR,"The way back from a picked scene goes to it")
	back.free()
	# Opened as the game: the main scene, current, on the command line's flags.
	LaunchArgs.set_override(PackedStringArray())
	change_scene_to_file(FRONT_DOOR)
	check(await until(func() -> bool: return current_scene != null and current_scene.scene_file_path == FRONT_DOOR,10.0),"The front door opens")
	var game: Node3D = current_scene
	var door: Node = game.front_door
	check(door.title_wanted and door.veil != null and door.veil.is_inside_tree(),"The veil is up while the isle builds")
	check(await until(func() -> bool: return game.isle_up,180.0),"The isle comes up (%.1f s from launch)" % (Time.get_ticks_msec()/1000.0))
	await frames(2)
	check(door.titled and door.veil == null,"The title is up and the veil gone")
	var title: Control = door.title
	check(title != null and title.is_visible_in_tree(),"The title shows")
	check(door.begin_button.has_focus() and not door.begin_button.get("quiet"),"Begin in reach on the card")
	check(door.scenes_button != null and door.scenes_button.get("quiet") and door.quit_button.get("quiet"),"Scenes and Quit quiet along its foot")
	check(title.buttons.size() == 3,"Nothing else on the card")
	var shown := 0
	for child in game.get_children():
		if child is CanvasLayer and child.visible: shown += 1
	check(shown == 0,"The isle's own HUD is hidden under it")
	check(game.scripted and not game.flying and game.parked,"The pilot is held, the plane parked")
	var eye: Vector3 = game.camera.global_position
	await frames(30)
	var moved: Vector3 = game.camera.global_position
	check(eye.distance_to(moved) > 0.01 and moved.y > game.isle_top()+20.0,"The camera orbits the isle from above")
	var feet: Vector3 = game.motor.feet
	await key(KEY_R)
	check(game.motor.feet.distance_to(feet) < 0.01 and door.titled,"R under the card does nothing")
	# Scenes.
	door.scenes_button.pressed.emit()
	await frames(3)
	var picker: Control = door.picker
	check(picker != null and picker.visible and title.modulate.a == 0.0,"Scenes opens the picker over the faded card")
	var builder := Catalog.find("builder")
	check(not builder.is_empty() and builder.scene == "res://studies/cozy_worlds.tscn" and builder.get("own_title") == true,"The old game waits there on its own title")
	var rows: Array = picker.rows.filter(func(row: Button) -> bool: return picker.entry_of[row].id == "builder")
	check(rows.size() == 1,"Its Builder (old game) row")
	await key(KEY_ESCAPE)
	check(not picker.visible and door.titled and door.scenes_button.has_focus(),"Esc goes back to the card, Scenes in reach")
	check(await until(func() -> bool: return title.modulate.a >= 1.0,3.0),"The card comes back")
	# Begin.
	door.begin_button.grab_focus()
	await tap_pad(JOY_BUTTON_A)
	check(not door.titled and not game.scripted,"Pad A on Begin gives the pilot back")
	check(await until(func() -> bool: return not door.layer.visible,3.0),"The card fades away")
	shown = 0
	for child in game.get_children():
		if child is CanvasLayer and child.visible: shown += 1
	check(shown > 0,"The isle's HUD is back")
	check(game.by_plane() and not game.flying,"On foot by the parked plane")
	await until(func() -> bool: return door._ease_left <= 0.0,5.0)
	await frames(2)
	var behind: float = game.camera.global_position.distance_to(game.figure.global_position)
	check(behind < 15.0,"The camera eased down behind him (%.1f m)" % behind)
	game.board_parked()
	check(game.flying,"The plane boards from there")
	# Straight in.
	LaunchArgs.set_override(PackedStringArray(["--no-title"]))
	var first := game.get_instance_id()
	change_scene_to_file(FRONT_DOOR)
	check(await until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != first and current_scene.scene_file_path == FRONT_DOOR,10.0),"--no-title opens it again")
	game = current_scene
	check(await until(func() -> bool: return game.isle_up,180.0),"The isle comes up")
	await frames(2)
	check(not game.front_door.titled and game.front_door.title == null and not game.scripted,"--no-title: no title, the pilot free")
	check(game.by_plane(),"...on foot by the parked plane")
	LaunchArgs.set_override(null)
	print("front door: %d failures" % failures)
	quit(1 if failures else 0)
