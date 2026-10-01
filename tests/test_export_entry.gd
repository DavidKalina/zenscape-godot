extends SceneTree
## The source-tree twin of the packaged self-check (tools/verify_desktop_export.py):
## the project's main scene opens the product shell and passes
## scripts/desktop_build_check.gd. Pass --native-kernels as the packaged run does.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var entry = ProjectSettings.get_setting("application/run/main_scene", "")
	if entry != "res://studies/cozy_worlds.tscn":
		push_error("FAIL: package opens an old study instead of the product shell: " + str(entry))
		quit(1)
		return
	var scene = load(entry).instantiate()
	# Never touch the player's saved places.
	var folder = OS.get_temp_dir().path_join("zenscape-export-places-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	scene.places_path = folder.path_join("places.json")
	root.size = Vector2i(1440,960)
	root.add_child(scene)
	# Quits with the check's verdict.
	preload("res://scripts/desktop_build_check.gd").run(scene)
