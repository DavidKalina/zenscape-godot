extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/camp-encounter-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.size = Vector2i(1440,900)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	root.content_scale_factor = 1
	scene.new_diorama()
	scene.set_process(false)
	var data: NativeTerrainData = scene._chunk_editor.data
	data.grass.fill(0.8)
	var id := data.place("campsite",Vector2(0,-5))
	for p in [Vector2(6,4),Vector2(-6,5),Vector2(3,7)]: data.place("fallen_branch",p)
	for p in [Vector2(-7,0),Vector2(-4,1),Vector2(4,1),Vector2(7,0),Vector2(-9,-8),Vector2(9,-8)]:
		data.place("tree",p,0,1.8)
		data.place("rock",p+Vector2(0,0.8),0,1.2)
	scene._chunk_editor.refresh()
	scene._refresh_habitat()
	scene.invite_bigfoot(Vector3(-5,0,4))
	scene.set_building(false)
	scene._celestial.set_phase(0.03)
	scene.target = Vector3(0,0.8,0)
	scene.distance = 26
	scene.yaw = 0.05
	scene.polar = 1.08
	scene._update_camera()
	var captures := {}
	for frame in range(9000):
		scene._process(1.0/60)
		if frame%120 == 0: await process_frame
		var manager = scene.camps
		for kind in ["visiting camp","hiding"]:
			if manager.bigfoot_activity == kind and not captures.has(kind) and manager.bigfoot_waypoint>1:
				captures[kind] = true
				for i in range(3): await process_frame
				RenderingServer.force_draw(false)
				if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("res://docs/campsite-life/"+kind.replace(" ","-")+".png")
	check(scene.camps.completed_visits>0,"Bigfoot chooses an unattended camp during an outing")
	check(scene.camps.stolen_food>0 and int(data.object_by_id(id).get("food",3))<3,"Unattended visit leaves missing food")
	check(captures.has("hiding"),"A camper sighting can send Bigfoot to cover")
	check(scene.camps.events.any(func(e: String) -> bool: return "investigates a glimpse" in e),"Camper interrupts an outing to investigate a glimpse")
	check(scene.camps.events.any(func(e: String) -> bool: return "adds wood" in e),"Camper can finish an outing despite encounters")
	var entry: Dictionary = scene.camps.camps[id]
	check(entry.outings>1,"Camper returns to a repeated quiet routine")
	print("ENCOUNTER EVENTS: ",scene.camps.events)
	var file := FileAccess.open("res://docs/campsite-life/events.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"events":scene.camps.events,"visits":scene.camps.visits,"completed_visits":scene.camps.completed_visits,"outings":entry.outings,"wood":data.object_by_id(id).get("wood",0),"failures":failures},"\t"))
	file.close()
	print("CAMPSITE ENCOUNTERS: failures=",failures)
	scene.free()
	quit(1 if failures else 0)
