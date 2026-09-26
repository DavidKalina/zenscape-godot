## Rendered stills (and optional orbit frames) of regrown seeds, UI hidden.
## Godot --path . --rendering-method forward_plus -s res://tools/capture_seed_stills.gd -- --out=/tmp/x --seeds=1,2 [--orbit=6]
extends SceneTree
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var out := "/private/tmp/zs-stills"
	var seeds: Array[int] = []
	var orbit := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--seeds="):
			for s in arg.trim_prefix("--seeds=").split(","): seeds.append(int(s))
		if arg.begins_with("--orbit="): orbit = float(arg.trim_prefix("--orbit="))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(60.0+seeds.size()*(25.0+orbit*3.0)).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = out+"/places.json"
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	await create_timer(1).timeout
	for world_seed in seeds:
		scene.places.regrow(world_seed)
		while scene.places.busy: await process_frame
		scene._ui.visible = false
		# Let fog, clouds and the grow-in settle before the still.
		await create_timer(2.5).timeout
		RenderingServer.force_draw(false)
		await process_frame
		var label: String = "%s %s %s" % [world_seed,scene.places.generated_world.terrain.composition,scene.places.generated_world.mood.weather]
		root.get_texture().get_image().save_png("%s/%d.png" % [out,world_seed])
		print("STILL ",label)
		if orbit>0.0:
			var frames := out+"/orbit-%d" % world_seed
			DirAccess.make_dir_recursive_absolute(frames)
			var start: float = scene.yaw
			var count := int(orbit*30.0)
			for i in range(count):
				scene.yaw = start+0.6*sin(TAU*float(i)/count*0.5)
				scene._update_camera()
				await process_frame
				root.get_texture().get_image().save_png("%s/%04d.png" % [frames,i])
		scene._ui.visible = true
	quit(0)
