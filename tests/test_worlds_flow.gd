extends SceneTree
## The worlds handoff end to end in the full cozy scene, launched as the game
## is (on the title), in a scratch folder: the title lists the worlds over the
## most recent one, live; browsing swaps the live world; Enter plays it; Esc
## pauses; a copy carries on; Return to title shows the copy selected and
## live; New world previews a canyon and Begin keeps that preview as the new
## world. Headless: nothing is drawn, so captures and fades are not checked.
const Library = preload("res://scripts/world_library.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: "+message)

func until(condition: Callable, seconds := 60.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	return true

func escape() -> void:
	for down in [true,false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = down
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await process_frame

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	var dir := "/private/tmp/worlds-flow-%d" % Time.get_ticks_usec()
	var seeded := Library.new(dir.path_join("worlds"))
	var now := Time.get_unix_time_from_system()
	var fern: Dictionary = seeded.create("Fern bank","plain","fern-owl-0001",now-600.0)
	var ochre: Dictionary = seeded.create("Ochre steps","canyon","flint-wren-0002",now-60.0)
	var world: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	world.set_meta("movie_capture",true)
	world.places_path = dir.path_join("places.json")
	root.add_child(world)
	# As the game launches: the scene is the current one, so the title opens.
	current_scene = world
	check(await until(func() -> bool: return world.shell_ready,300.0), "The scene opens")
	var session: Node = world.world_session
	var title: Control = world.world_title
	check(session.managing and world.titled and title.visible, "The game opens on the worlds title")
	check(title.worlds.size() == 2 and title.selected_world().id == ochre.id, "The title lists the worlds, the most recent selected")
	check(session.current_id == ochre.id and world._chunk_editor.data._recipe_settings.get("family","") == "canyon", "The selected world is live behind the title")
	check(world._menu.visible and world._menu.modulate.a == 0.0 and not world._menu.is_ancestor_of(world.get_viewport().gui_get_focus_owner() if world.get_viewport().gui_get_focus_owner() != null else world), "The old menu holds the state, unseen and unfocused")
	check(not FileAccess.file_exists(seeded.save_path(ochre.id)), "Showing a world behind the title writes nothing")
	# Browse to the plain: its land replaces the canyon behind the title.
	title.browse(1)
	check(title.selected_world().id == fern.id, "Browsing selects the next world")
	check(await until(func() -> bool: return session.current_id == fern.id and not session._backdrop_loading and world.places.plain), "The backdrop swaps to the selected world")
	check(world.titled and not world._has_world, "Browsing stays on the title")
	# Enter it: the world already behind the title is played as it stands.
	var forms := [0]
	world._chunk_editor.formation_started.connect(func() -> void: forms[0] += 1)
	title.enter()
	check(await until(func() -> bool: return not world.titled), "Enter leaves the title")
	check(forms[0] == 0 and world._has_world and session.current_id == fern.id, "The entered world is not loaded again")
	check(FileAccess.file_exists(seeded.save_path(fern.id)), "A world entered for the first time is kept")
	check(not title.visible and not world._menu.visible and world._chunk_editor.active, "The world is in hand")
	# Esc pauses.
	await escape()
	check(world.pause_panel.is_open and world._menu.visible and world._paused, "Esc opens the pause panel over the paused world")
	check(world.pause_panel.name_label.text == "Fern bank", "Pause names the world")
	check(await until(func() -> bool: return not session.keeping), "Pausing keeps the world")
	check(world.pause_panel.status_text.begins_with("Kept safe"), "Pause says the world is kept: "+world.pause_panel.status_text)
	# Save a copy and carry on in it.
	world.pause_panel.set_copy_open(true)
	world.pause_panel.copy_name.text = "Fern fork"
	world.pause_panel.set_carry_on(true)
	world.pause_panel.save_copy()
	var copy: Dictionary = session.library.find(session.current_id)
	check(session.library.worlds().size() == 3 and copy.name == "Fern fork" and session.current_id != fern.id, "The copy is in the library and played")
	check(world.places_path == session.library.save_path(copy.id) and FileAccess.file_exists(world.places_path), "The copy keeps to its own save")
	check(not world.pause_panel.is_open and not world._menu.visible and not world._paused, "Saving the copy resumes")
	# Pause again and return to the title, the copy selected and live.
	await escape()
	check(world.pause_panel.is_open, "Esc pauses again")
	world.pause_panel.title_requested.emit()
	check(await until(func() -> bool: return world.titled and title.visible), "Return to title shows the worlds title")
	check(title.worlds.size() == 3 and title.selected_world().id == copy.id and session.current_id == copy.id, "The title selects the copy, live behind it")
	check(not world.pause_panel.is_open and world._menu.visible, "The pause panel gives way to the title")
	# New world: preview a canyon and begin it.
	title.new_world_requested.emit()
	var panel: Control = world.new_world_panel
	check(panel.visible and not title.visible, "New world opens its panel")
	panel.pick("canyon")
	check(await until(func() -> bool: return session.previewed == ["canyon",panel.seed_text] and not session._preview_forming), "Picking a land previews it")
	check(world._chunk_editor.data._recipe_settings.get("family","") == "canyon" and session.library.worlds().size() == 3, "The preview is the land, not a world")
	forms[0] = 0
	panel.begin()
	check(await until(func() -> bool: return not world.titled), "Begin leaves the title")
	var made: Dictionary = session.library.find(session.current_id)
	check(made.get("land","") == "canyon" and made.get("name","") == "Red canyon" and session.library.worlds().size() == 4, "The new world exists with land canyon")
	check(session.reused_preview and forms[0] == 0, "Begin keeps the preview rather than forming it again")
	check(FileAccess.file_exists(session.library.save_path(made.id)) and saved_family(session.library.save_path(made.id)) == "canyon", "The new world is kept as a canyon")
	check(not panel.visible and world._has_world and not world._menu.visible, "The new world is in hand")
	# Back from New world returns to the selected world.
	world.open_worlds_title(made.id)
	title.new_world_requested.emit()
	panel.pick("hollow")
	check(await until(func() -> bool: return session.previewed.size() == 2 and session.previewed[0] == "hollow" and not session._preview_forming), "A second preview forms")
	panel.back_requested.emit()
	check(await until(func() -> bool: return not session.previewing and title.visible), "Back ends the preview")
	check(session.current_id == made.id and world._chunk_editor.data._recipe_settings.get("family","") == "canyon", "Back shows the selected world again")
	world.queue_free()
	await process_frame
	await process_frame
	remove_tree(dir)
	print("Worlds flow: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

func saved_family(path: String) -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return ""
	return str(parsed.slots[int(parsed.active)].document.get("terrain_recipe",{}).get("family",""))

func remove_tree(path: String) -> void:
	for sub: String in DirAccess.get_directories_at(path): remove_tree(path.path_join(sub))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
