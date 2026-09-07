extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	if "--control" in OS.get_cmdline_user_args():
		for f in scene._frog_motion.frogs:
			f.wait = 1000.0
	else:
		scene._frog_motion.startle()
