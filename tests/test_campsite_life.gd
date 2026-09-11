extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	var scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/campsite-test-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.size = Vector2i(1440,900)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	check(scene._build_palette._entries.has("campsite"),"Campsite appears in searchable editor")
	var preview: Node3D = scene._build_palette.build_model("campsite")
	check(preview != null,"Campsite has a placement preview")
	if preview != null: preview.free()
	var data: NativeTerrainData = editor.data
	editor.reactions_enabled = false
	scene._build_palette._choose("campsite")
	check(editor.place_at(scene.camera.unproject_position(Vector3(0,0,-5))),"Campsite places through the editor tool")
	var id: int = data.objects[0].id
	data.begin_stroke()
	data.place("fallen_branch",Vector2(4,3))
	data.place("fallen_branch",Vector2(-5,3))
	data.end_stroke()
	editor.refresh()
	scene._refresh_habitat()
	scene.set_building(false)
	scene._process(1.0/60)
	check(scene.camps.camps.size()==1,"One camper appears without requiring Bigfoot")
	check(not scene.navigation.is_safe(Vector3(0,0,-5)),"Tent blocks navigation")
	for frame in range(3000):
		scene._process(1.0/60)
		if frame%100 == 0: await process_frame
		if data.object_by_id(id).get("carrying",false): break
	check(data.object_by_id(id).get("carrying",false),"Gathered branch enters carried inventory")
	check(scene.save_current() and scene.open_path(editor.save_path),"Save and reopen during a gathering trip")
	scene.set_building(false)
	scene._refresh_habitat()
	check(data.object_by_id(id).get("carrying",false),"Carried wood survives reopening")
	for frame in range(5000):
		scene._process(1.0/60)
		if frame%100 == 0: await process_frame
		if int(data.object_by_id(id).get("wood",0))>0: break
	check(int(data.object_by_id(id).get("wood",0))==1,"Camper gathers and returns with wood")
	check(not data.object_by_id(id).get("carrying",true),"Delivery empties carried inventory")
	print("CAMP EVENTS: ",scene.camps.events)
	check(scene.save_current(),"Save campsite")
	var saved := editor.save_path
	check(scene.open_path(saved),"Reopen campsite")
	scene.set_building(false)
	scene._refresh_habitat()
	scene._process(1.0/60)
	check(scene.camps.camps.size()==1 and int(data.object_by_id(id).get("wood",0))==1,"Reopen restores one camper and wood count")
	data.begin_stroke()
	check(data.update_object(id,{"x":5.0,"z":-5.0}),"Move camp record")
	data.end_stroke()
	editor.refresh()
	scene._refresh_habitat()
	scene._process(1.0/60)
	check(scene.camps.camps[id].actor.position.distance_to(Vector3(5,0,-2.75))<0.2,"Moving the tent relocates camper home")
	data.begin_stroke()
	data.remove_object(id)
	data.end_stroke()
	editor.refresh()
	scene._refresh_habitat()
	scene._process(1.0/60)
	check(scene.camps.camps.is_empty(),"Removing tent removes attached camper")
	data.undo()
	editor.refresh()
	scene._refresh_habitat()
	scene._process(1.0/60)
	check(scene.camps.camps.size()==1,"Undo restores exactly one camper")
	var position: Vector3 = scene.camps.camps[id].actor.position
	scene.set_building(true)
	for i in range(120): scene._process(1.0/60)
	check(scene.camps.camps[id].actor.position == position,"Building pauses the camper")
	scene.set_building(false)
	var tree := data.place("tree",Vector2.ZERO,0,2)
	editor.refresh()
	scene._refresh_habitat()
	scene.camps.sight.refresh(scene)
	check(scene.camps.sight.blocked(Vector3(-4,1.5,0),Vector3(4,1.5,0)),"Authored trunk blocks sight")
	data.remove_object(tree)
	editor.refresh()
	scene.camps.sight.refresh(scene)
	check(not scene.camps.sight.blocked(Vector3(-4,1.5,0),Vector3(4,1.5,0)),"Removing trunk opens that sightline")
	print("CAMPSITE LIFE: failures=",failures)
	scene.free()
	quit(1 if failures else 0)
