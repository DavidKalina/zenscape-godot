extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	if not "--control" in OS.get_cmdline_user_args():
		scene._atmosphere.summit_mist = 0.35
		scene._atmosphere._publish_wind()
