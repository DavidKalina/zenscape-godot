extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.library_path = "/private/tmp/camp-consequences-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	scene.set_process(false)
	var data: NativeTerrainData = scene._chunk_editor.data
	var id := data.place("campsite",Vector2(0,-5))
	var second := data.place("campsite",Vector2(7,-5))
	check(data.update_object(second,{"camper":"backpacker"}),"Second camp accepts a different resident")
	check(not data.update_object(id,{"food":-1}),"Food cannot go negative")
	check(not data.update_object(id,{"photos":1.5}),"Photo count must be an integer")
	check(not data.update_object(id,{"camper":"unknown"}),"Unknown camper models are rejected")
	scene._chunk_editor.refresh()
	scene._refresh_habitat()
	scene.invite_bigfoot(Vector3(0,0,5))
	scene.set_building(false)
	scene._celestial.set_phase(0.48)
	var manager = scene.camps
	manager._sync()
	check(manager.camps.size()==2,"Two tents own two independent campers")
	var entry: Dictionary = manager.camps[id]
	check(manager.camps[second].actor.variant == "backpacker","Backpacker model is used")
	check(entry.actor.parts.any(func(p: Dictionary) -> bool: return p.limb == "arm"),"Authored arm meshes participate in posing")
	entry.actor.position = Vector3.ZERO
	entry.actor.rotation.y = 0
	entry.state = "search"
	entry.last_seen = scene.creature.position
	entry.search = 9.0
	entry.wait = 20.0
	entry.outings = 1
	for i in range(150): manager._advance_camper(entry,1.0/60,true)
	check(manager.photographs==1,"Sustained clear sight produces one photograph")
	check(int(data.object_by_id(id).get("photos",0))==1,"Photograph is persisted on the correct campsite")
	# A clear initial glimpse is insufficient if the subject disappears before shutter time.
	entry.route.clear()
	entry.state = "photo"
	entry.wait = 0.05
	entry.actor.position = Vector3.ZERO
	entry.actor.rotation.y = 0
	entry.last_seen = scene.creature.position
	var tree := data.place("tree",Vector2(0,2.5),0,2)
	scene._chunk_editor.refresh()
	scene._refresh_habitat()
	manager.sight.refresh(scene)
	for i in range(6): manager._advance_camper(entry,1.0/60,true)
	check(manager.photographs==1,"Tree occlusion at shutter time prevents a photograph")
	data.remove_object(tree)
	scene._chunk_editor.refresh()
	scene._refresh_habitat()
	manager._sync()
	entry = manager.camps[id]
	entry.actor.position = Vector3(5,0,5)
	entry.state = "rest"
	entry.wait = 100
	scene.routine.cancel()
	scene.creature.reset_at(entry.home)
	manager._take_bigfoot(PackedVector3Array([entry.home]),"visiting camp",id)
	for i in range(200): manager._bigfoot(1.0/60,false)
	check(manager.stolen_food==1 and data.object_by_id(id).food==2,"Completed unattended inspection removes exactly one snack")
	check(not data.object_by_id(second).has("food"),"Other camp inventory is unaffected")
	manager._sync()
	entry = manager.camps[id]
	manager._take_bigfoot(PackedVector3Array([entry.home]),"visiting camp",id)
	scene._resident_play.carrying = true
	manager._bigfoot(1.0/60,false)
	check(manager.bigfoot_activity.is_empty(),"Player ownership cancels the camp encounter")
	check(data.object_by_id(id).food==2,"Interrupted encounter does not steal food")
	scene._resident_play.carrying = false
	# Moving a tent cancels an inspection before inventory is touched.
	manager._take_bigfoot(PackedVector3Array([entry.home]),"visiting camp",id)
	data.update_object(id,{"x":-4.0})
	scene._chunk_editor.refresh()
	scene._refresh_habitat()
	manager._sync()
	check(manager.bigfoot_activity.is_empty() and data.object_by_id(id).food==2,"Moving tent cancels visit without stealing")
	check(scene.save_current() and scene.open_path(scene._chunk_editor.save_path),"Save and reopen the consequences")
	check(data.object_by_id(id).get("food",0)==2 and data.object_by_id(id).get("photos",0)==1,"Food and photographs survive reopening")
	print("CAMPSITE CONSEQUENCES: failures=",failures)
	scene.free()
	quit(1 if failures else 0)
