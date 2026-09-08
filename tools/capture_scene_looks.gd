extends SceneTree
var scene: Node3D
var output := "res://docs/scene-look"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	create_timer(100).timeout.connect(func() -> void: push_error("Look capture timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	scene._auto_orbit = false
	scene._ui.hide()
	scene._precipitation.set_weather(0,true)
	scene._celestial.set_phase(0.48)
	scene._atmosphere.set_fog(0.15)
	scene._atmosphere.set_haze(0.12)
	scene._process(0)
	for title in ["Mountain","Meadow","Desert","Ocean","Winter"]:
		scene._celestial.look.choose(title)
		await capture(title.to_lower())
	for title in ["Misty hollow","Rose dusk","Moonlit stillness"]:
		scene.apply_scene_mood(title)
		await capture(title.to_lower().replace(" ","-"))
	scene.apply_scene_mood("Meadow morning")
	scene._chunk_editor.set_active(true)
	scene.edit_scene_look()
	scene._look_editor.tabs.current_tab = 1
	await capture("editor-landscape")
	scene._look_editor.tabs.current_tab = 2
	await capture("editor-light")
	scene._look_editor.tabs.current_tab = 3
	await capture("editor-atmosphere")
	root.size = Vector2i(960,640)
	await capture("editor-small")
	scene.free()
	print("LOOK CAPTURES COMPLETE")
	quit()
func capture(title: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(output+"/"+title+".png")
	print("Captured ",title)
