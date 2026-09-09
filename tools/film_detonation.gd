extends SceneTree
## Frame-by-frame film of one summit detonation through the real remote, so the
## flash, crater, and debris timing can be inspected as images. Frames land in
## /private/tmp/detonation-film/frame-NNN.png with the request time in ms.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/detonation-film-library"
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	var editor: NativeChunkEditor = scene._chunk_editor
	await editor.form_landscape("horn","alpine",false,37)
	var top := 0
	for i in range(editor.data.heights.size()):
		if editor.data.heights[i]>editor.data.heights[top]: top = i
	var charge := editor.data.place("explosive",editor.data.points[top])
	editor.data.update_object(charge,{"blast_radius":3.5})
	editor.refresh()
	scene.target = Vector3(-1,5.5,-1)
	scene.distance = 18
	scene.polar = 1.05
	scene.yaw = 0.65
	scene._auto_orbit = false
	scene._update_camera()
	scene.set_building(false)
	for name in ["_ui","_toolbar","_menu"]:
		var panel: Variant = scene.get(name)
		if panel is CanvasItem: panel.visible = false
	for layer in root.find_children("*","CanvasLayer",true,false):
		if layer.get_parent() != scene and layer.get_parent() != editor.explosives: layer.visible = false
	DirAccess.make_dir_recursive_absolute("/private/tmp/detonation-film")
	for i in range(30): await process_frame
	editor.explosives.target_id = charge
	var start := Time.get_ticks_usec()
	editor.explosives.request_detonation()
	# Keep frames in memory; PNG encoding on the spot would stretch the timeline.
	var frames: Array[Image] = []
	var stamps: Array[int] = []
	for i in range(60):
		await process_frame
		frames.append(root.get_texture().get_image())
		stamps.append(int((Time.get_ticks_usec()-start)/1000.0))
	for i in range(frames.size()):
		frames[i].save_png("/private/tmp/detonation-film/frame-%02d-%04dms.png" % [i,stamps[i]])
	# A second blast in the same process separates first-use costs (shader
	# pipelines, first mesh uploads) from the work the detonation always does.
	editor.undo()
	for i in range(60): await process_frame
	editor.explosives.target_id = editor.data.objects.back().id
	frames.clear()
	stamps.clear()
	start = Time.get_ticks_usec()
	editor.explosives.request_detonation()
	for i in range(60):
		await process_frame
		frames.append(root.get_texture().get_image())
		stamps.append(int((Time.get_ticks_usec()-start)/1000.0))
	DirAccess.make_dir_recursive_absolute("/private/tmp/detonation-film/second")
	for i in range(frames.size()):
		frames[i].save_png("/private/tmp/detonation-film/second/frame-%02d-%04dms.png" % [i,stamps[i]])
	print("FILM done")
	scene.queue_free()
	await process_frame
	quit()
