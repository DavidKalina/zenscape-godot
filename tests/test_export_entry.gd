extends SceneTree
## Run with --main-pack <exported.pck>; validates the shipped entry, not the source tree.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if "--native-kernels" in OS.get_cmdline_user_args():
		var kernel = preload("res://scripts/native_terrain_kernels.gd").get_kernel()
		if kernel == null or not kernel.has_method("shade"):
			push_error("FAIL: packaged native terrain kernel is unavailable")
			quit(1)
			return
		print("PASS: packaged native terrain kernel loaded")
	var entry = ProjectSettings.get_setting("application/run/main_scene", "")
	if entry != "res://studies/diorama.tscn":
		push_error("FAIL: package opens the old study instead of the product shell: " + str(entry))
		quit(1)
		return
	var scene = load(entry).instantiate()
	var folder = OS.get_temp_dir().path_join("zenscape-export-menu-" + str(Time.get_ticks_usec()))
	scene.library_path = folder
	scene.recent_file = folder.path_join("recent.cfg")
	root.size = Vector2i(1440,960)
	root.add_child(scene)
	# Startup loads Fidelity before exposing the shell.
	# A single frame (or the scene's ready signal) does not mean it is usable.
	var deadline := Time.get_ticks_msec() + 120_000
	while not scene.title_loaded:
		if Time.get_ticks_msec() >= deadline:
			push_error("FAIL: title loading did not finish within 120 seconds")
			quit(1)
			return
		await process_frame
	if not scene._has_world or not scene.resident_enabled or scene._chunk_editor.data.blank:
		push_error("FAIL: startup did not enter inhabited Fidelity")
		quit(1)
		return
	scene.show_menu()
	print("Menu visible: ", scene._menu.visible if scene._menu != null else "MISSING")
	if scene._menu == null or not scene._menu.visible:
		push_error("FAIL: main menu is missing")
		quit(1)
		return
	scene.new_diorama()
	print("Build editor active: ", scene._chunk_editor.active)
	var rail = scene._build_palette.get("_tool_rail")
	print("New tool tray visible: ", rail != null and rail.visible)
	if rail == null or not rail.visible:
		push_error("FAIL: new editor tool tray is missing")
		quit(1)
		return
	if not scene._chunk_editor.active:
		push_error("FAIL: New diorama did not open editor")
		quit(1)
		return
	# Exercise shutdown with a recording still playing, independent of the
	# random bird schedule or how fast this runner loads the title.
	var ambience = scene._ambient_audio
	ambience.muted = false
	ambience.update_world(0.05,false,scene)
	ambience.nature.call_bird("owl",scene.camera.global_position,0.3)
	await physics_frame
	await process_frame
	var audio_streams: Array[WeakRef] = []
	var recording_playing := false
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for player in scene.find_children("*",kind,true,false):
			if player.stream != null: audio_streams.append(weakref(player.stream))
			if player.stream is AudioStreamMP3 and player.playing: recording_playing = true
	if not recording_playing:
		push_error("FAIL: shutdown check needs an active wildlife recording")
		quit(1)
		return
	scene.free()
	# Removing players asks the audio mixer to stop them; releasing their
	# streams happens on a later mix. Quitting immediately reports them as leaks.
	# Observe release rather than sleeping for an assumed mixer buffer length.
	var shutdown_deadline := Time.get_ticks_msec()+2000
	while audio_streams.any(func(stream: WeakRef) -> bool: return stream.get_ref() != null):
		if Time.get_ticks_msec() >= shutdown_deadline:
			push_error("FAIL: audio streams are still retained after scene shutdown")
			quit(1)
			return
		await process_frame
	for name in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	print("PASS: packaged main menu and New diorama editor")
	quit(0)
