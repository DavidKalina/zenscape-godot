extends SceneTree
## Open the existing game playground with the actor framed for iteration.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var scene = load("res://studies/god_mode_playground.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in range(90): await physics_frame
	var tuner = get_first_node_in_group("tree_motion_tuner")
	tuner._close_up()
	tuner._watch_idle()
	root.title = "ZenScape · Bigfoot personality · worktree"
	if "--capture" in OS.get_cmdline_user_args():
		for i in range(90): await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/bigfoot-personality-game.png")
