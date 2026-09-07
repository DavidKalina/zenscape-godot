extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	if "--control" in OS.get_cmdline_user_args():
		scene._celestial.night_fill = 0.0
		scene._celestial.update_rig()
