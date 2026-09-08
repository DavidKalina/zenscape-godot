extends SceneTree
## Current product scene, fixed native viewport, two complete breathing cycles.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,900)
	var capture := SubViewport.new()
	capture.size = Vector2i(1280,900)
	capture.own_world_3d = true
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.library_path = "/private/tmp/zs-breath-film"
	scene.recent_file = "/private/tmp/zs-breath-film/recent.cfg"
	capture.add_child(scene)
	await process_frame
	scene.new_diorama()
	scene._paused = true
	await scene._chunk_editor.form_landscape("valley","woodland",false)
	preload("res://scripts/scene_look_presets.gd").apply(scene,"golden_meadow")
	scene._celestial.set_phase(0.5)
	scene._celestial.update_rig()
	assert(scene.invite_bigfoot(Vector3(3,0,3)))
	scene.set_building(false)
	scene._paused = true
	scene.set_process(false)
	scene.creature.visible = true
	scene.frame_creature(5.6,-0.5)
	var original := CreatureActor.new()
	scene.add_child(original)
	original.setup("res://assets/models/zenscape-bigfoot-woodland.glb")
	original.set_process(false)
	original.global_transform = scene.creature.global_transform
	var coat := ShaderMaterial.new()
	coat.shader = preload("res://shaders/reference_surface.gdshader")
	for mesh in original.actor.find_children("*","MeshInstance3D",true,false):
		if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat
	for effect in [true,false]:
		var actor: CreatureActor = scene.creature if effect else original
		scene.creature.visible = effect
		original.visible = not effect
		actor.reset_at(original.global_position)
		for i in range(12): actor.advance(1.0/60.0)
		actor.player.seek(0.0,true)
		actor.player.advance(0.0)
		var directory := "/private/tmp/zs-breath-"+("effect" if effect else "control")
		DirAccess.make_dir_recursive_absolute(directory)
		for frame in range(312):
			actor.advance(1.0/30.0)
			RenderingServer.global_shader_parameter_set("zs_motion_time",float(frame)/30.0)
			await process_frame
			RenderingServer.force_draw(false)
			capture.get_texture().get_image().save_jpg(directory+"/%04d.jpg" % frame,0.95)
		print("BREATH FILM complete effect=",effect)
	scene.free()
	quit()
