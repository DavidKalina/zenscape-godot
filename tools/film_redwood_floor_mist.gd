extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440,900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var study = load("res://studies/redwood_forest.tscn").instantiate()
	viewport.add_child(study)
	study.caption.hide()
	study.paused = true
	for effect in [true,false]:
		study.mist_material.set_shader_parameter("floor_pockets",1.0 if effect else 0.0)
		var dir := "/private/tmp/zs-floor-mist-"+("effect" if effect else "control")
		DirAccess.make_dir_recursive_absolute(dir)
		for frame in range(-24,192):
			var time := maxf(frame,0)/24.0
			study.clock = time
			study.yaw = sin(time*0.20)*0.025
			study._update_camera()
			await process_frame
			RenderingServer.force_draw(false)
			if frame>=0: viewport.get_texture().get_image().save_png(dir+"/%04d.png" % frame)
			if frame == 72 and effect: viewport.get_texture().get_image().save_png("res://docs/redwood-forest/floor-mist.png")
		print("FLOOR MIST FILM mist=",effect," frames=192 trees=",study.tree_count)
	study.free()
	quit()
