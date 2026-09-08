extends SceneTree
## Matched native diorama reels; fixed camera, seed, geometry and 24 Hz clock.
func _initialize() -> void: run.call_deferred()
func old_script(file: String) -> GDScript:
	var script := GDScript.new()
	var text := FileAccess.get_file_as_string("res://docs/bigfoot-deliberation/control/"+file+".txt")
	if text.begins_with("class_name"): text = text.substr(text.find("\n")+1)
	script.source_code = text
	assert(script.reload()==OK)
	return script
func run() -> void:
	root.size = Vector2i(1280,900)
	var capture := SubViewport.new()
	capture.size = Vector2i(1280,900)
	capture.own_world_3d = true
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.library_path = "/private/tmp/zs-deliberation-film"
	scene.recent_file = "/private/tmp/zs-deliberation-film/recent.cfg"
	capture.add_child(scene)
	await process_frame
	scene.new_diorama()
	scene.set_building(false)
	scene._paused = true
	scene.set_process(false)
	preload("res://scripts/scene_look_presets.gd").apply(scene,"golden_meadow")
	scene._celestial.set_phase(0.5)
	scene._celestial.update_rig()
	scene.target = Vector3(0,0.8,0)
	scene.distance = 30.0
	scene.yaw = -0.45
	scene.polar = 0.95
	scene._update_camera()
	# Landmarks make direction changes legible, with open ground for free roaming.
	for p in [Vector2(-10,-9),Vector2(10,-8),Vector2(-11,8),Vector2(10,10)]:
		scene._chunk_editor.data.place("tree",p,0.0,1.0)
	scene._chunk_editor.refresh()
	for effect in [true,false]:
		var actor: CreatureActor = scene.creature
		actor.reset_at(Vector3(-3,0,-5))
		actor.rotation = Vector3.ZERO
		actor.visible = true
		actor._gaze_weight = 0.0
		actor._gaze_yaw = 0.0
		actor._gaze_pitch = 0.0
		var nav = CreatureNavigation.new() if effect else old_script("creature_navigation.gd").new()
		nav.rebuild(scene._chunk_editor.data,func(_p: Vector3) -> bool: return true,0.35,0.3)
		var brain = CreatureBrain.new() if effect else old_script("creature_brain.gd").new()
		scene.add_child(brain)
		brain.setup(actor,nav,func() -> Array: return [])
		brain.rest_min = scene.brain.rest_min if effect else 0.5
		brain.rest_max = scene.brain.rest_max if effect else 1.2
		var dir := "/private/tmp/zs-deliberation-"+("effect" if effect else "control")
		DirAccess.make_dir_recursive_absolute(dir)
		for frame in range(24*30):
			brain.advance(1.0/24.0)
			actor.advance(1.0/24.0)
			RenderingServer.global_shader_parameter_set("zs_motion_time",float(frame)/24.0)
			await process_frame
			RenderingServer.force_draw(false)
			capture.get_texture().get_image().save_jpg(dir+"/%04d.jpg" % frame,0.92)
		brain.free()
		print("DELIBERATION REEL COMPLETE ",effect)
	scene.free()
	quit()
