extends SceneTree
## The world session in the full cozy scene, in a scratch folder: a launch
## with an empty library forms a new plain world and keeps it; every land
## forms; switching writes and reads each world's own save. Slow headless
## (the scene and four landscapes form on the dummy renderer).
const Library = preload("res://scripts/world_library.gd")
## The canyon is held back with the desert (scripts/desert_landscape.gd);
## these flows exercise it, so the desert is on. tools/probe_desert_gate.gd
## checks the default game without it.
const Desert = preload("res://scripts/desert_landscape.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	Desert.on = true
	create_timer(600).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	var dir := OS.get_temp_dir().path_join("world-session-scene-%d" % Time.get_ticks_usec())
	var world: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	world.set_meta("movie_capture",true)
	world.set_meta("manage_worlds",true)
	world.places_path = dir.path_join("places.json")
	var started := Time.get_ticks_msec()
	root.add_child(world)
	while not world.places_ready: await process_frame
	print("scene ready ms=",Time.get_ticks_msec()-started)
	var session: Node = world.world_session
	var first: String = session.current_id
	check(not first.is_empty() and session.library.worlds().size() == 1, "An empty library launches into a new world")
	check(world.places_path == session.library.save_path(first) and FileAccess.file_exists(world.places_path), "The new world is kept in its own file")
	check(world.places.plain, "The launch world is a quiet plain")
	var ids := {"plain":first}
	for land: String in ["canyon","isle","hollow"]:
		started = Time.get_ticks_msec()
		var made: Dictionary = await session.create_world("",land,"basalt-heron-2081")
		print(land," formed ms=",Time.get_ticks_msec()-started," objects=",world._chunk_editor.data.objects.size())
		ids[land] = made.id
		check(session.current_id == made.id and FileAccess.file_exists(session.library.save_path(made.id)), "A new %s world is kept" % land)
		check(made.name == Library.land_name(land), "It takes the land's name")
		check(world._chunk_editor.data._undo.is_empty(), "A new %s world's undo does not reach the last world" % land)
	var canyon_heights: PackedFloat32Array = PackedFloat32Array()
	await session.open_world(ids.canyon)
	canyon_heights = world._chunk_editor.data.heights.duplicate()
	check(world._chunk_editor.data._recipe_settings.get("family","") == "canyon", "Reopening the canyon reads its save")
	await session.open_world(ids.plain)
	check(world.places.plain and world._chunk_editor.data.heights != canyon_heights, "Switching back reads the plain's save")
	# A finished stroke keeps the world a moment later.
	session.autosave_delay = 0.2
	var kept: float = session.last_kept_at
	await create_timer(1.1).timeout
	world._chunk_editor.stroke_finished.emit(Vector3.ZERO,1.0,"land")
	await create_timer(0.8).timeout
	check(session.last_kept_at > kept, "A finished stroke is kept after the delay")
	# A preview forms a land without a world, and ends back on the world.
	var count: int = session.library.worlds().size()
	await session.preview_land("canyon","flint-wren-0042")
	check(session.previewing and world._chunk_editor.data._recipe_settings.get("family","") == "canyon" and session.library.worlds().size() == count, "A preview forms the land without a world")
	await session.end_preview()
	check(not session.previewing and world.places.plain, "Ending the preview reopens the world")
	var copy: Dictionary = session.save_copy("",true)
	check(session.current_id == copy.id and world.places_path == session.library.save_path(copy.id), "Carry on in the copy")
	world.queue_free()
	await process_frame
	await process_frame
	remove_tree(dir)
	print("World session scene: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

func remove_tree(path: String) -> void:
	for sub: String in DirAccess.get_directories_at(path): remove_tree(path.path_join(sub))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
