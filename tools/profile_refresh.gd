extends SceneTree
## Time each stage of an editor brush refresh on a populated world.
func _initialize() -> void: run.call_deferred()
func t(label: String, f: Callable) -> void:
	var s := Time.get_ticks_usec()
	f.call()
	print("%-34s %8.1f ms" % [label, (Time.get_ticks_usec()-s)/1000.0])
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor = scene._chunk_editor
	editor.content.set_process(false)
	var path := "res://docs/garden/fall-world-proof.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--file="): path = a.trim_prefix("--file=")
	editor.save_path = path
	print("open ok: ", editor.open_garden(), "  objects: ", editor.data.objects.size(), "  tris: ", editor.data.vertex_ids.size()/3)
	var data = editor.data
	var cam: Camera3D = scene.camera
	var mouse := Vector2(720, 450)
	t("pick (ray vs all triangles)", func(): editor.pick(mouse))
	t("begin_stroke snapshot", func(): data.begin_stroke())
	t("brush dab", func(): data.brush(Vector2(0,0), 2.2, 0.05, "raise", 0.0))
	t("build_mesh", func(): editor.terrain.mesh = data.build_mesh())
	t("content.rebuild (objects+water)", func(): editor.content.rebuild())
	t("landmarks.rebuild", func(): editor.landmarks.rebuild(data))
	t("falls.rebuild", func(): editor.falls.rebuild(data))
	t("surface map pixel loop", func():
		var image: Image = editor._original_ground_map.duplicate()
		for z in range(image.get_height()):
			for x in range(image.get_width()):
				var p := (Vector2(x,z)+Vector2.ONE*0.5)/image.get_width()*32.0-Vector2.ONE*16.0
				var h = data.height_at(p.x,p.y)
				var v := Color(-1000,-1000,-1000,-1000)
				v.g = float(h) if h != null else -1000.0
				image.set_pixel(x,z,v))
	t("paint_water", func(): GardenSurfaceMap.paint_water(editor._original_ground_map.duplicate(), editor.content.pond_vertices))
	t("paint_streams", func(): GardenSurfaceMap.paint_streams(editor._original_ground_map.duplicate(), editor._original_stream_map.duplicate(), editor.content._stream_nodes))
	t("bigfoot ground.setup", func(): scene._bigfoot.ground.setup(editor.terrain))
	t("atmosphere.update_ground_bounds", func(): scene._atmosphere.update_ground_bounds(editor.terrain, false))
	t("skirt rebuild", func(): editor._rebuild_skirt())
	t("FULL editor.refresh()", func(): editor.refresh())
	t("end_stroke", func(): data.end_stroke())
	t("undo", func(): editor.undo())
	quit()
