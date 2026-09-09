extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(300).timeout.connect(func(): push_error("World integration timed out"); quit(2))
	var scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/zenscape-world-integration-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	scene.title_seed = 37
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	var editor = scene._chunk_editor
	for family in ["massif","valley","salt-basin"]:
		var settings := {"kind":"inland","version":3,"seed":7,"composition":family,"archetype":"range","landform":"tall-massif" if family == "massif" else "glacial-valley" if family == "valley" else "original","biome":"arid" if family == "salt-basin" else "woodland","relief":1.25,"breadth":1.0}
		await editor.form_inland(settings)
		scene._world_visuals.fog_density = 0.7
		scene._world_visuals.peak_density = 0.3
		scene._world_visuals.rock_style = 2
		editor.data.begin_stroke()
		editor.data.heights[100] += 0.2
		editor.data.end_stroke()
		var tree_id: int = editor.data.place("layered_tree",Vector2(8,8),0,0.7)
		check(tree_id>0,"Additional tree can be placed")
		await editor.refresh(self)
		var heights: PackedFloat32Array = editor.data.heights.duplicate()
		check(editor.save_garden(),"Save "+family)
		scene._world_visuals.restore()
		editor.data.reset_flat()
		check(editor.open_garden(),"Reload "+family)
		check(editor.data.heights == heights,"Sculpted heights survive "+family)
		check(editor.data._recipe_settings == settings,"Genome survives "+family)
		check(scene._world_visuals.fog_density == 0.7 and scene._world_visuals.peak_density == 0.3 and scene._world_visuals.rock_style == 2,"Atmosphere and rock settings survive")
		check(not editor.data.object_by_id(tree_id).is_empty(),"Additional tree survives")
		var travel: Vector2 = scene._atmosphere._travel
		await create_timer(0.3).timeout
		check(scene._atmosphere._travel != travel,"Shared wind advances")
		check(scene._environment.volumetric_fog_length >= scene.distance+40.0,"Fog covers camera reach")
		print("WORLD ROUND TRIP ",family)
	# Old saves have no new settings and must clear the previous world's effects.
	var legacy: Dictionary = NativeGardenStore.capture(scene)
	legacy.erase("world_visuals")
	check(NativeGardenStore.valid(scene,legacy),"Older scene state remains valid")
	NativeGardenStore.restore(scene,legacy)
	check(scene._world_visuals.fog_density == 0 and scene._world_visuals.peak_density == 0,"Older saves reset new atmosphere")
	scene.free()
	for name in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	print("WORLD INTEGRATION failures=",failures)
	quit(failures)
