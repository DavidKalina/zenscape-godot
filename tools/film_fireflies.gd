extends SceneTree
## Uses the normal scene capture arguments; --control removes only fireflies.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	if "--control" in OS.get_cmdline_user_args():
		scene._fireflies.layers = 0
