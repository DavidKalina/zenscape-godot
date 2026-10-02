extends SceneTree
## The world session (scripts/world_session.gd) against a light stand-in for
## the cozy scene: its regrowth saves and loads a one-line place, so this runs
## headless in a moment. The full scene's own load and form paths are
## scripts/cozy_regrowth.gd `open_place` and `open_land`; captures are skipped
## headless. Covers migration, launch picks, create/open/switch files, copies,
## keeping while busy and the autosave debounce.
const Session = preload("res://scripts/world_session.gd")
const Library = preload("res://scripts/world_library.gd")
var failures := 0

class StubPlaces extends Node:
	var scene: Node3D
	var initialized := true
	var busy := false
	var holding := false
	var writes := 0
	func save_places() -> bool:
		if busy or holding: return false
		var file := FileAccess.open(scene.places_path,FileAccess.WRITE)
		file.store_string(JSON.stringify({"land":scene.land}))
		file.close()
		writes += 1
		return true
	func open_place(path: String) -> bool:
		await get_tree().process_frame
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary: return false
		scene.land = parsed.land
		return true
	func open_land(land: String, seed_value: int) -> bool:
		await get_tree().process_frame
		scene.land = "%s:%d" % [land,seed_value]
		return true

class StubScene extends Node3D:
	signal title_picked(choice: String)
	var places_path := ""
	var places: Node
	var titled := false
	var land := ""
	func _places_idle() -> bool: return places != null and places.initialized and not places.busy and not places.holding
	func save_current() -> bool: return places.save_places()

func _initialize() -> void: run.call_deferred()

func saved_land(path: String) -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return str(parsed.land) if parsed is Dictionary else ""

func make_scene(root_dir: String) -> Array:
	var scene := StubScene.new()
	scene.places_path = root_dir.path_join("places.json")
	var places := StubPlaces.new()
	places.scene = scene
	scene.places = places
	scene.add_child(places)
	var session := Session.new()
	scene.add_child(session)
	root.add_child(scene)
	session.set_process(false)
	return [scene,places,session]

func run() -> void:
	create_timer(30).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	var dir := "user://test-world-session-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(dir.path_join("places.json"),FileAccess.WRITE).store_string(JSON.stringify({"land":"legacy"}))
	# Other launches keep the single save.
	var parts := make_scene(dir)
	var scene: StubScene = parts[0]
	var places: StubPlaces = parts[1]
	var session: Node = parts[2]
	session.setup(scene,false)
	check(session.library.worlds().is_empty() and scene.places_path == dir.path_join("places.json"), "An unmanaged session adopts nothing and keeps the path")
	check(session.begin("plain") == "plain" and session.current_id.is_empty(), "An unmanaged launch keeps its choice")
	session.edited()
	session.tick(10.0)
	check(places.writes == 0 and not session.keep_now(), "Nothing autosaves without a world")
	scene.queue_free()
	await process_frame
	# Migration: the older save becomes "Your world", once.
	parts = make_scene(dir)
	scene = parts[0]
	places = parts[1]
	session = parts[2]
	session.setup(scene,true)
	var worlds: Array = session.library.worlds()
	check(worlds.size() == 1 and worlds[0].name == "Your world", "The older save is adopted as Your world")
	var yours: String = worlds[0].id
	check(session.current_id == yours and scene.places_path == session.library.save_path(yours), "The adopted world is the one to continue")
	check(saved_land(scene.places_path) == "legacy", "The adopted world holds the older save")
	check(session.begin("resume") == "resume", "Continue resumes a world with a save")
	scene.land = "legacy"
	session.opened()
	check(session.library.find(yours).last_played_at > 1000.0, "Opening touches the world")
	var again := Session.new()
	again.scene = scene
	scene.add_child(again)
	again.set_process(false)
	again.setup(scene,true)
	check(again.library.worlds().size() == 1, "Adoption happens once")
	again.queue_free()
	scene.places_path = session.library.save_path(yours)
	# Create and switch: each world writes and reads its own file.
	var kept_states: Array = []
	session.keeping_changed.connect(func(value: bool) -> void: kept_states.append(value))
	scene.land = "legacy, sculpted"
	var dunes: Dictionary = await session.create_world("Dunes","canyon","basalt-heron-2081")
	check(dunes.name == "Dunes" and dunes.land == "canyon", "Create names the world and its land")
	check(session.current_id == dunes.id and scene.places_path == session.library.save_path(dunes.id), "Create opens the new world")
	check(saved_land(session.library.save_path(yours)) == "legacy, sculpted", "Switching keeps the world left behind")
	var formed := "canyon:%d" % Library.seed_value("basalt-heron-2081")
	check(scene.land == formed and saved_land(session.library.save_path(dunes.id)) == formed, "A new world forms from its land and seed and is kept")
	check(kept_states.size() >= 2 and kept_states[0] == true and kept_states.back() == false, "Keeping is announced, then settled")
	check(session.last_kept_at > 1000.0, "The keep time is recorded")
	scene.land = "dunes, watered"
	await session.open_world(yours)
	check(session.current_id == yours and scene.land == "legacy, sculpted", "Opening a world reads its own save")
	check(saved_land(session.library.save_path(dunes.id)) == "dunes, watered", "Opening another world keeps the one left")
	check(session.library.worlds()[0].id == yours, "The opened world is the most recent")
	# Save a copy: stay here, then carry on in a copy.
	scene.land = "legacy, planted"
	var stay: Dictionary = session.save_copy("For later",false)
	check(stay.name == "For later" and session.current_id == yours, "Stay here keeps playing the original")
	check(saved_land(session.library.save_path(stay.id)) == "legacy, planted", "The copy holds the world as it was kept")
	var carry: Dictionary = session.save_copy("",true)
	check(carry.name == "Your world (copy)", "A blank copy name is {name} (copy)")
	check(session.current_id == carry.id and scene.places_path == session.library.save_path(carry.id), "Carry on switches to the copy")
	scene.land = "copy, changed"
	check(session.keep_now(), "The copy keeps itself")
	check(saved_land(session.library.save_path(carry.id)) == "copy, changed" and saved_land(session.library.save_path(yours)) == "legacy, planted", "Carrying on writes the copy, not the original")
	# Never while busy: try again shortly.
	places.busy = true
	scene.land = "busy edit"
	var writes := places.writes
	check(not session.keep_now() and places.writes == writes, "A busy world is not kept")
	session.tick(Session.RETRY*0.5)
	check(places.writes == writes, "Still busy, still waiting")
	places.busy = false
	session.tick(Session.RETRY)
	check(places.writes == writes+1 and saved_land(scene.places_path) == "busy edit", "The keep is retried once idle")
	# The debounce: kept a delay after the last edit, not the first.
	session.autosave_delay = 1.0
	writes = places.writes
	session.edited()
	session.tick(0.6)
	session.edited()
	session.tick(0.6)
	check(places.writes == writes, "Edits within the delay hold the keep off")
	session.tick(0.5)
	check(places.writes == writes+1, "Kept a delay after the last edit")
	session.tick(5.0)
	check(places.writes == writes+1, "Nothing more to keep")
	writes = places.writes
	for i in range(int(Session.AUTOSAVE_LONGEST/0.5)+2):
		session.edited()
		session.tick(0.5)
	check(places.writes == writes+1, "A steady stream of edits is still kept within the longest wait")
	# A preview is never kept; ending it brings the world back.
	scene.land = "before preview"
	session.keep_now()
	await session.preview_land("isle","quartz-owl-0001")
	check(session.previewing and scene.land == "isle:%d" % Library.seed_value("quartz-owl-0001"), "Preview forms the land")
	session.edited()
	check(not session.keep_now() and saved_land(scene.places_path) == "before preview", "A preview is not kept over the world")
	await session.end_preview()
	check(not session.previewing and scene.land == "before preview", "Ending the preview reopens the world")
	# On the title, opening a world is the pick that leaves it.
	scene.titled = true
	var picks: Array = []
	scene.title_picked.connect(func(choice: String) -> void:
		picks.append(choice)
		scene.titled = false
		session.enter(choice))
	await session.open_world(dunes.id)
	check(picks == ["open"] and session.current_id == dunes.id and scene.land == "dunes, watered", "A title pick opens the world")
	scene.queue_free()
	await process_frame
	# A fresh launch: the title's new plain is a new world.
	parts = make_scene(dir)
	scene = parts[0]
	session = parts[2]
	session.setup(scene,true)
	check(session.current_id == dunes.id, "Launch points at the most recent world")
	var count: int = session.library.worlds().size()
	check(session.begin("plain") == "plain" and session.library.worlds().size() == count+1 and session.launch_seed >= 0, "Begin on a plain creates a world with a seed")
	check(scene.places_path == session.library.save_path(session.current_id) and not FileAccess.file_exists(scene.places_path), "The new world's save waits for its forming")
	scene.queue_free()
	await process_frame
	for path: String in DirAccess.get_files_at(dir.path_join("worlds")): DirAccess.remove_absolute(dir.path_join("worlds").path_join(path))
	DirAccess.remove_absolute(dir.path_join("worlds"))
	DirAccess.remove_absolute(dir.path_join("places.json"))
	DirAccess.remove_absolute(dir)
	print("World session: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: "+message)
