extends SceneTree
## Exercise the product entry and ordinary object editing, then capture the
## actual notice, crossing and successful-rest frames with the native renderer.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/cozy_worlds.tscn").instantiate()
	var folder := "/private/tmp/crossing-render-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	scene.places_path = folder+"/places.json"
	root.add_child(scene)
	while not scene.places_ready: await process_frame
	var original: Dictionary = JSON.parse_string(JSON.stringify(scene._chunk_editor.data.to_document(),"",true,true))
	await profile_discovery(scene,"populated world")
	scene.open_crossing_glade()
	var backup_ok := false
	for filename in DirAccess.get_files_at(folder):
		if filename.begins_with("Before-crossing-") and filename.ends_with(".json"):
			var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(filename)))
			backup.erase("scene_state")
			backup_ok = backup==original
	print("Previous cozy world backup matches: ",backup_ok)
	await profile_discovery(scene,"crossing glade")
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	var log_id := -1
	for record in editor.data.objects:
		if record.asset == "log": log_id = int(record.id)
	var wish = scene.routine.crossing_wish
	var stones := "--stones" in OS.get_cmdline_user_args()
	var output := "/private/tmp/crossing-render-stones" if stones else "/private/tmp/crossing-render"
	DirAccess.make_dir_recursive_absolute(output)
	var captured := {}
	var placed := false
	for frame in range(7200):
		scene._process(1.0/60.0)
		var name := ""
		if wish.destination != null and not placed:
			if not captured.has("notice"): name = "notice"
			elif wish._noticing<=0:
				if stones:
					editor.data.begin_stroke()
					editor.data.brush(Vector2.ZERO,0.6,30.0,"flatten",0.0)
					editor.data.end_stroke()
					editor.refresh()
				else:
					editor.select_object(log_id)
					editor.begin_selection_edit()
					editor.update_selected({"x":0.0,"z":0.0})
					editor.end_selection_edit()
				scene._refresh_habitat()
				scene.set_building(false)
				placed = true
		if placed and scene.creature.balancing and absf(scene.creature.position.x)<0.35 and scene.creature.state==CreatureActor.State.WALKING: name = "crossing"
		if stones and scene.creature.state==CreatureActor.State.HOPPING and scene.creature._age>0.3: name = "crossing"
		if scene.routine.habits.outing_visits>0: name = "favorite"
		if not name.is_empty() and not captured.has(name):
			await process_frame
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(output+"/"+name+".png")
			captured[name] = true
			print("Captured ",name," actor=",scene.creature.position," outing=",scene.routine.habits.outing)
		if captured.size()==3: break
		if wish._planning or frame%30==0: await process_frame
	print("CROSSING RENDER: ",captured.keys()," scene=",folder," actor=",scene.creature.position," destination=",wish.destination," active=",scene.routine.active," cancel=",scene.routine.last_cancel," query_slices=",wish.last_query_slices)
	var saved: bool = scene.save_current()
	var favorite: Variant = scene.routine.habits.outing
	scene.routine.crossing_wish.reset()
	scene.brain.enabled = false
	scene.brain.reset_behavior()
	scene.routine.cancel("capture completed")
	for frame in range(3): await process_frame
	scene.free()
	var reopened = load("res://studies/cozy_worlds.tscn").instantiate()
	reopened.places_path = folder+"/places.json"
	root.add_child(reopened)
	while not reopened.places_ready: await process_frame
	var memory_ok: bool = reopened.routine.habits.outing == favorite and reopened.routine.habits.outing_visits>0
	print("Main cozy restart preserves favorite: ",saved and memory_ok)
	reopened.routine.crossing_wish.reset()
	reopened.free()
	quit(0 if captured.size()==3 and backup_ok and saved and memory_ok else 1)

func profile_discovery(scene: Node, label: String) -> void:
	var wish = scene.routine.crossing_wish
	var processing: bool = scene.is_processing()
	scene.set_process(false)
	var began := Time.get_ticks_usec()
	wish._prepare(true)
	while wish._planning: await process_frame
	print("CROSSING PROFILE ",label," peak_slice_ms=",wish.last_query_peak_usec/1000.0," slices=",wish.last_query_slices," total_wall_ms=",(Time.get_ticks_usec()-began)/1000.0)
	wish.reset()
	wish._next = scene.routine._clock+3.0
	scene.set_process(processing)
