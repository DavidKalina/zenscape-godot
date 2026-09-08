extends SceneTree
## Run with --main-pack <exported.pck>; validates the shipped entry, not the source tree.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var entry = ProjectSettings.get_setting("application/run/main_scene", "")
	if entry != "res://studies/diorama.tscn":
		push_error("FAIL: package opens the old study instead of the diorama menu: " + str(entry))
		quit(1)
		return
	var scene = load(entry).instantiate()
	var folder = OS.get_temp_dir().path_join("zenscape-export-menu-" + str(Time.get_ticks_usec()))
	scene.library_path = folder
	scene.recent_file = folder.path_join("recent.cfg")
	root.size = Vector2i(1440,960)
	root.add_child(scene)
	await process_frame
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
	scene.free()
	for name in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	print("PASS: packaged main menu and New diorama editor")
	quit(0)
