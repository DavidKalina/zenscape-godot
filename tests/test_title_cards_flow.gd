extends SceneTree
## The title as cards end to end in the full cozy scene, launched as the game
## is, in a scratch folder (scripts/title_cards.gd; the old card and strip are
## tests/test_worlds_flow.gd's). The main menu is dealt over the showcase;
## Your worlds deals world select, whose focused world loads live behind it;
## Esc deals the menu back over the showcase; a world card enters its world;
## Return to title lands on the menu; Continue plays the most recent world;
## A new world opens its panel and Back returns to the menu and showcase; the
## blank card opens it from world select; and a kept world's card shows what
## was placed in it. Headless: nothing is drawn, so faces, captures and fades
## are not checked.
const Library = preload("res://scripts/world_library.gd")
const Desert = preload("res://scripts/desert_landscape.gd")
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

## The cards' main menu over the showcase, the old card unseen.
func on_menu(world: Node3D, showcase: Dictionary) -> bool:
	var cards: Control = world.title_cards
	return world.titled and not world.library_open and cards.visible and cards.view == "menu" and world._menu.modulate.a == 0.0 \
		and not world.world_title.visible and world.world_session.showing_showcase and world._chunk_editor.data._recipe_settings == showcase

## Picks the menu card `label` and waits out its draw.
func pick(world: Node3D, label: String) -> void:
	var cards: Control = world.title_cards
	for i in cards.items.size():
		if cards.items[i].label == label:
			cards.choose(i)
			break
	await create_timer(cards.DRAW+0.1).timeout

func back_to_title(world: Node3D, showcase: Dictionary) -> bool:
	await escape()
	if not world.pause_panel.is_open: return false
	world.pause_panel.title_requested.emit()
	return await until(func() -> bool: return on_menu(world,showcase) and world.get_node_or_null("TitleLoading") == null)

func run() -> void:
	Desert.on = true
	create_timer(900).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	var dir := "/tmp/title-cards-flow-%d" % Time.get_ticks_usec()
	var seeded := Library.new(dir.path_join("worlds"))
	var now := Time.get_unix_time_from_system()
	var fern: Dictionary = seeded.create("Fern bank","plain","fern-owl-0001",now-600.0)
	var ochre: Dictionary = seeded.create("Ochre steps","canyon","flint-wren-0002",now-60.0)
	var world: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	world.set_meta("movie_capture",true)
	world.places_path = dir.path_join("places.json")
	root.add_child(world)
	current_scene = world
	check(await until(func() -> bool: return world.shell_ready,300.0), "The scene opens")
	var session: Node = world.world_session
	var cards: Control = world.title_cards
	var data: NativeTerrainData = world._chunk_editor.data
	var showcase: Dictionary = data._recipe_settings.duplicate(true)
	check(cards != null, "The title is dealt as cards")
	check(on_menu(world,showcase), "The game opens on the cards' menu over the showcase")
	check(cards.items.map(func(item: Dictionary) -> String: return item.label) == ["Continue","Your worlds","A new world","Almanac","Rest"], "The menu's five picks")
	check(cards.items[0].line == "Back to Ochre steps", "Continue names the most recent world")
	# World select: the most recent world loads behind it.
	await pick(world,"Your worlds")
	check(world.library_open and cards.view == "worlds" and cards.world_cards.size() == 3, "Your worlds deals world select: two worlds and the blank card")
	check(await until(func() -> bool: return session.current_id == ochre.id and not session._backdrop_loading and data._recipe_settings.get("family","") == "canyon"), "The focused world loads behind world select")
	check(not FileAccess.file_exists(seeded.save_path(ochre.id)), "Showing a world behind the title writes nothing")
	cards.world_cards[1].hovered.emit(cards.world_cards[1])
	check(await until(func() -> bool: return session.current_id == fern.id and not session._backdrop_loading and world.places.plain), "Hovering a card swaps the live world")
	cards.world_cards[1].unhovered.emit(cards.world_cards[1])
	# Esc deals the menu back over the showcase.
	await escape()
	check(await until(func() -> bool: return on_menu(world,showcase)), "Esc on world select returns to the menu and the showcase")
	# Enter a world from its card.
	await pick(world,"Your worlds")
	check(await until(func() -> bool: return session.current_id == ochre.id and not session._backdrop_loading), "World select reopens on the most recent world")
	cards.choose(1)
	check(await until(func() -> bool: return not world.titled), "A world's card enters it")
	check(world._has_world and session.current_id == fern.id and not cards.visible, "The picked world is in hand, the cards gone")
	check(FileAccess.file_exists(seeded.save_path(fern.id)), "A world entered for the first time is kept")
	var kept: Dictionary = session.library.find(fern.id)
	check(kept.get("card") is Dictionary and kept.card.get("pal") is Dictionary and kept.card.get("els") is Array, "Keeping a world keeps its card: %s" % [kept.get("card")])
	# Return to title; Continue plays the most recent world.
	check(await back_to_title(world,showcase), "Return to title lands on the cards' menu over the showcase")
	check(cards.items[0].line == "Back to Fern bank", "Continue now names the world just played")
	await pick(world,"Continue")
	check(await until(func() -> bool: return not world.titled), "Continue leaves the title")
	check(session.current_id == fern.id, "Continue plays the most recent world")
	# A new world from the menu, and back.
	check(await back_to_title(world,showcase), "Back on the menu")
	await pick(world,"A new world")
	var panel: Control = world.new_world_panel
	check(panel.visible and not cards.visible, "A new world opens its panel")
	panel.pick("hollow")
	check(await until(func() -> bool: return session.previewed.size() == 2 and session.previewed[0] == "hollow" and not session._preview_forming), "Picking a land previews it")
	panel.back_requested.emit()
	check(await until(func() -> bool: return on_menu(world,showcase)), "Back returns to the menu over the showcase")
	# The blank card opens it from world select; Begin makes the world.
	await pick(world,"Your worlds")
	check(await until(func() -> bool: return world.library_open and not session._backdrop_loading), "World select again")
	cards.choose(cards.world_cards.size()-1)
	await create_timer(cards.DRAW+0.1).timeout
	check(panel.visible and not cards.visible, "The blank card opens the New world panel")
	panel.pick("plain")
	panel.begin()
	check(await until(func() -> bool: return not world.titled), "Begin leaves the title")
	check(session.library.worlds().size() == 3, "The new world is in the library")
	world.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	remove_tree(dir)
	print("Title cards flow: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

func remove_tree(path: String) -> void:
	for sub: String in DirAccess.get_directories_at(path): remove_tree(path.path_join(sub))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
