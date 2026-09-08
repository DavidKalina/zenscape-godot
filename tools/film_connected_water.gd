extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var control := "--control" in OS.get_cmdline_user_args()
	var directory := "/private/tmp/zenscape-water-"+("control" if control else "flow")
	DirAccess.make_dir_recursive_absolute(directory)
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	scene._auto_orbit = false
	scene._ui.hide()
	await scene._chunk_editor.form_landscape("terraced_pools","",false)
	preload("res://scripts/scene_look_presets.gd").apply(scene,"alpine_morning")
	scene.target = Vector3(0,3.1,0)
	scene.distance = 30.0
	scene.yaw = 0.23
	scene.polar = 0.85
	scene._update_camera()
	scene.set_process(false)
	for i in range(8): await process_frame
	for frame in range(96):
		RenderingServer.global_shader_parameter_set("zs_flow_time",0.0 if control else frame/24.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory+"/frame-%04d.png" % frame)
	print("WATER FILM ","control" if control else "flow"," frames=96 cascades=",scene._chunk_editor.content._landscape_falls.size())
	scene.free()
	quit()
