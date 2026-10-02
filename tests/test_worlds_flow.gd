extends SceneTree
## The worlds handoff end to end in the full cozy scene, launched as the game
## is, in a scratch folder. The title's front page is the old card over the
## showcase world; Your worlds opens the library page, whose selected world
## loads live behind it; Esc goes back to the showcase; Enter plays a world;
## Esc pauses; a copy carries on; Return to title lands on the front page;
## Begin on a quiet plain and Build this world make worlds from the front;
## New world previews a canyon and Begin keeps that preview. Headless:
## nothing is drawn, so captures and fades are not checked.
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

func entry(world: Node3D, text: String) -> Button:
	for button: Button in world._menu.buttons:
		if button.text == text: return button
	return null

## The front page: the old card, seen, over the showcase as it was formed.
func on_front(world: Node3D, showcase: Dictionary) -> bool:
	return world.titled and not world.library_open and world._menu.visible and world._menu.modulate.a == 1.0 and not world.world_title.visible \
		and world.world_session.showing_showcase and world._chunk_editor.data._recipe_settings == showcase

## Pauses with Esc and returns to the title.
func back_to_title(world: Node3D, showcase: Dictionary) -> bool:
	await escape()
	if not world.pause_panel.is_open: return false
	world.pause_panel.title_requested.emit()
	return await until(func() -> bool: return on_front(world,showcase) and world.get_node_or_null("TitleLoading") == null)

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
	var data: NativeTerrainData = world._chunk_editor.data
	var showcase: Dictionary = data._recipe_settings.duplicate(true)
	# The front page.
	check(session.managing and not showcase.is_empty() and on_front(world,showcase), "The game opens on the old card over the showcase")
	check(session.current_id.is_empty() and FileAccess.file_exists(session.showcase_path()), "The showcase is kept aside, no world is played")
	check(not world._continue.disabled and world._continue.visible, "Continue your world is offered")
	check(world._your_worlds.visible and world._your_worlds.get("detail") == "2 kept", "Your worlds counts the worlds: "+str(world._your_worlds.get("detail")))
	check(world._keep_title.visible and entry(world,"Begin on a quiet plain").visible, "Build this world and a quiet plain are offered")
	check(world._menu.buttons.find(world._your_worlds) == 1, "Your worlds comes after Continue")
	# The library page: the most recent world loads behind it.
	world._your_worlds.pressed.emit()
	check(world.library_open and title.visible and title.quit_button.text.to_lower() == "back", "Your worlds opens the library page, with Back")
	check(title.worlds.size() == 2 and title.selected_world().id == ochre.id, "The library lists the worlds, the most recent selected")
	check(await until(func() -> bool: return session.current_id == ochre.id and not session._backdrop_loading and data._recipe_settings.get("family","") == "canyon"), "The selected world loads behind the library")
	check(not session.showing_showcase and world._menu.visible and world._menu.modulate.a == 0.0, "The card gives way to the library")
	check(not FileAccess.file_exists(seeded.save_path(ochre.id)), "Showing a world behind the title writes nothing")
	title.browse(1)
	check(await until(func() -> bool: return session.current_id == fern.id and not session._backdrop_loading and world.places.plain), "Browsing swaps the live world")
	# Esc goes back to the front page and its showcase.
	await escape()
	check(await until(func() -> bool: return on_front(world,showcase)), "Esc on the library returns to the showcase on the front page")
	# Your worlds again, browse, enter.
	world._your_worlds.pressed.emit()
	check(await until(func() -> bool: return session.current_id == ochre.id and not session._backdrop_loading), "The library reopens on the most recent world")
	title.browse(1)
	check(await until(func() -> bool: return session.current_id == fern.id and not session._backdrop_loading and world.places.plain), "Browsing again")
	var forms := [0]
	world._chunk_editor.formation_started.connect(func() -> void: forms[0] += 1)
	title.enter()
	check(await until(func() -> bool: return not world.titled), "Enter leaves the title")
	check(forms[0] == 0 and world._has_world and session.current_id == fern.id, "The entered world is not loaded again")
	check(FileAccess.file_exists(seeded.save_path(fern.id)), "A world entered for the first time is kept")
	check(not title.visible and not world._menu.visible and world._chunk_editor.active, "The world is in hand")
	# Esc pauses; save a copy and carry on in it.
	await escape()
	check(world.pause_panel.is_open and world._menu.visible and world._paused, "Esc opens the pause panel over the paused world")
	check(world.pause_panel.name_label.text == "Fern bank", "Pause names the world")
	check(await until(func() -> bool: return not session.keeping), "Pausing keeps the world")
	check(world.pause_panel.status_text.begins_with("Kept safe"), "Pause says the world is kept: "+world.pause_panel.status_text)
	world.pause_panel.set_copy_open(true)
	world.pause_panel.copy_name.text = "Fern fork"
	world.pause_panel.set_carry_on(true)
	world.pause_panel.save_copy()
	var copy: Dictionary = session.library.find(session.current_id)
	check(session.library.worlds().size() == 3 and copy.name == "Fern fork" and session.current_id != fern.id, "The copy is in the library and played")
	check(world.places_path == session.library.save_path(copy.id) and FileAccess.file_exists(world.places_path), "The copy keeps to its own save")
	check(not world.pause_panel.is_open and not world._menu.visible and not world._paused, "Saving the copy resumes")
	# Return to title lands on the front page, the showcase again.
	check(await back_to_title(world,showcase), "Return to title lands on the front page over the showcase")
	check(not world.pause_panel.is_open and world._your_worlds.get("detail") == "3 kept", "The card counts the copy")
	# Front: Begin on a quiet plain.
	entry(world,"Begin on a quiet plain").pressed.emit()
	check(await until(func() -> bool: return not world.titled), "Begin on a quiet plain plays a new world")
	var plain: Dictionary = session.library.find(session.current_id)
	check(plain.get("land","") == "plain" and world.places.plain and session.library.worlds().size() == 4 and FileAccess.file_exists(session.library.save_path(plain.id)), "The new plain world is kept")
	# Front: Build this world keeps the showcase.
	check(await back_to_title(world,showcase), "Back on the front page")
	world._keep_title.pressed.emit()
	check(await until(func() -> bool: return not world.titled), "Build this world plays the showcase")
	var built: Dictionary = session.library.find(session.current_id)
	var recipe: Dictionary = world.title_recipe
	check(built.get("name","") == ("%s %s" % [str(recipe.biome).capitalize(),str(recipe.family).replace("-"," ")]) and session.library.worlds().size() == 5, "The showcase is a world named for its land: "+str(built.get("name","")))
	check(data._recipe_settings == showcase and FileAccess.file_exists(session.library.save_path(built.id)), "It keeps the showcase's land")
	# Library → New world → Back returns to the library; then a canyon.
	check(await back_to_title(world,showcase), "Back on the front page again")
	world._your_worlds.pressed.emit()
	check(await until(func() -> bool: return world.library_open and not session._backdrop_loading and session.current_id == built.id), "The library opens on the most recent world")
	title.new_world_requested.emit()
	var panel: Control = world.new_world_panel
	check(panel.visible and not title.visible, "New world opens its panel")
	panel.pick("hollow")
	check(await until(func() -> bool: return session.previewed.size() == 2 and session.previewed[0] == "hollow" and not session._preview_forming), "Picking a land previews it")
	panel.back_requested.emit()
	check(await until(func() -> bool: return not session.previewing and title.visible and world.library_open), "Back returns to the library")
	check(session.current_id == built.id and data._recipe_settings == showcase, "The selected world is behind the library again")
	title.new_world_requested.emit()
	panel.pick("canyon")
	check(await until(func() -> bool: return session.previewed == ["canyon",panel.seed_text] and not session._preview_forming), "A canyon previews")
	forms[0] = 0
	panel.begin()
	check(await until(func() -> bool: return not world.titled), "Begin leaves the title")
	var made: Dictionary = session.library.find(session.current_id)
	check(made.get("land","") == "canyon" and made.get("name","") == "Red canyon" and session.library.worlds().size() == 6, "The new world exists with land canyon")
	check(session.reused_preview and forms[0] == 0, "Begin keeps the preview rather than forming it again")
	check(saved_family(session.library.save_path(made.id)) == "canyon", "The new world is kept as a canyon")
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
