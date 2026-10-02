extends SceneTree
## Meadow lands in the full cozy scene (scripts/world_lands.gd), in a scratch
## folder: each meadow forms as a new world through the world session, as
## New world begins it, is named for its land and kept, and reopens from its
## save as it was. Slow headless (the scene and five meadows form on the
## dummy renderer).
const Library = preload("res://scripts/world_library.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	create_timer(600).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	var dir := "/private/tmp/meadow-lands-scene-%d" % Time.get_ticks_usec()
	var world: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	world.set_meta("movie_capture",true)
	world.set_meta("manage_worlds",true)
	world.places_path = dir.path_join("places.json")
	root.add_child(world)
	while not world.places_ready: await process_frame
	var session: Node = world.world_session
	var made := {}
	for type_id: String in MeadowTypes.ORDER:
		var land := MeadowTypes.land_id(type_id)
		var started := Time.get_ticks_msec()
		var entry: Dictionary = await session.create_world("",land,"meadow-lark-2081")
		var data: NativeTerrainData = world._chunk_editor.data
		print("%s formed ms=%d records=%d" % [land,Time.get_ticks_msec()-started,data.objects.size()])
		made[type_id] = [entry.id,data.objects.duplicate(true)]
		# What a stroke's refresh costs on this meadow (the view rebuilds the plate).
		var refresh_started := Time.get_ticks_usec()
		data.objects_revision += 1
		await world._chunk_editor.refresh(self)
		print("%s refresh ms=%.0f" % [land,(Time.get_ticks_usec()-refresh_started)/1000.0])
		check(entry.land == land and entry.name == Library.land_name(land),"A %s world takes its land and name" % land)
		check(data._recipe_settings.get("meadow") == type_id,"The %s world is a %s meadow" % [land,type_id])
		check(data.objects.size() >= 400,"The %s world is dressed (%d records)" % [land,data.objects.size()])
		check(FileAccess.file_exists(session.library.save_path(entry.id)),"The %s world is kept" % land)
		check(str(world.places._label(world)).begins_with(str(MeadowTypes.TYPES[type_id].title)),"The badge names the meadow: %s" % world.places._label(world))
	# Back to the first: its save reads as it was dressed.
	await session.open_world(made.wildflower[0])
	var reopened: NativeTerrainData = world._chunk_editor.data
	check(reopened._recipe_settings.get("meadow") == "wildflower" and reopened.objects.size() == made.wildflower[1].size(),"The wildflower meadow reopens from its save")
	world.queue_free()
	await process_frame
	await process_frame
	remove_tree(dir)
	print("Meadow lands scene: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

func remove_tree(path: String) -> void:
	for sub: String in DirAccess.get_directories_at(path): remove_tree(path.path_join(sub))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
