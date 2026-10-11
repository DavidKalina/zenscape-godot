extends SceneTree
## The source-tree twin of the packaged self-check (tools/verify_desktop_export.py):
## the project's main scene is the front door (studies/zenscape.tscn: the
## title over the aqueduct isle) and passes scripts/desktop_build_check.gd
## through its title, as the packaged run does. Pass --native-kernels as the
## packaged run does.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var entry = ProjectSettings.get_setting("application/run/main_scene", "")
	if entry != "res://studies/zenscape.tscn":
		push_error("FAIL: package opens an old study instead of the front door: " + str(entry))
		quit(1)
		return
	var scene = load(entry).instantiate()
	# Not the current scene here, so the title is asked for, as the packaged
	# run (the main scene) has it.
	scene.set_meta("title", true)
	root.size = Vector2i(1440,960)
	root.add_child(scene)
	# Quits with the check's verdict.
	preload("res://scripts/desktop_build_check.gd").run(scene)
