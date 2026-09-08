extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	var study = load("res://studies/redwood_forest.tscn").instantiate()
	root.add_child(study)
	study.caption.hide()
	study.paused = true
	for effect in [true,false]:
		study.environment.volumetric_fog_enabled = effect
		var dir := "/private/tmp/zs-redwood-"+("effect" if effect else "control")
		DirAccess.make_dir_recursive_absolute(dir)
		for frame in range(-24,192):
			var time := maxf(frame,0)/24.0
			study.clock = time
			study.yaw = sin(time*0.20)*0.025
			study._update_camera()
			await process_frame
			RenderingServer.force_draw(false)
			if frame>=0: root.get_texture().get_image().save_png(dir+"/%04d.png" % frame)
			if frame == 72 and effect: root.get_texture().get_image().save_png("res://docs/redwood-forest/hero.png")
		print("REDWOOD FILM mist=",effect," frames=192 trees=",study.tree_count)
	study.free()
	quit()
