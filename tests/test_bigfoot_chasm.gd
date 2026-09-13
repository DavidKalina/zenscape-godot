extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func settle(scene: Node) -> void:
	for i in range(220):
		scene._process(1.0/60.0)
		if i%30==0: await process_frame
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/private/tmp/chasm-"+label+".png")
func run() -> void:
	root.size = Vector2i(1440,960)
	create_timer(120).timeout.connect(func() -> void: quit(2))
	var scene = load("res://studies/cozy_worlds.tscn").instantiate()
	var folder := "/private/tmp/chasm-play-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	scene.places_path = folder+"/places.json"
	root.add_child(scene)
	while not scene.places_ready: await process_frame
	scene._world_menu.get_popup().id_pressed.emit(111)
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	var data: NativeTerrainData = editor.data
	check(data._recipe_settings.get("composition")=="chasm","Main World menu opens a chasm")
	check(not editor._skirt.visible,"Continuous source skirt is hidden")
	check(editor.terrain.mesh.get_surface_count()==2,"Chasm renders its own bank walls")
	scene.environment_life.cancel()
	scene.environment_life.arrival_pending = false
	scene.environment_life.autonomous = false
	scene.routine.living.enabled = false
	scene.routine._next_action = INF
	scene.brain.rest_min = 10000
	scene.brain.rest_max = 10000
	scene.brain.reset_behavior()
	scene._paused = false
	var wish = scene.routine.crossing_wish
	for i in range(1100):
		scene._process(1.0/60.0)
		if wish.destination != null: break
		if wish._planning: await process_frame
	check(wish.destination != null,"Bigfoot notices a destination across the actual void")
	check(scene.navigation.path(Vector3(-3,0,0),Vector3(3,0,0)).is_empty(),"He cannot walk across an empty gap")
	var log_id := -1
	for item in data.objects:
		if item.asset=="log": log_id = int(item.id)
	editor.select_object(log_id)
	# Exercise the editor's pointer drag, not only the terrain-data API.
	editor._selection_drag = true
	editor._selection_press = Vector2(-100,-100)
	editor._selection_offset = Vector2.ZERO
	editor._selection_plane_y = 0.0
	editor.move_selection_pointer(scene.camera.unproject_position(Vector3.ZERO))
	editor.finish_stroke()
	var moved := data.object_by_id(log_id)
	check(absf(moved.x)<0.02 and absf(moved.z)<0.02,"Pointer drag places a log over the void")
	scene._refresh_habitat()
	scene.set_building(false)
	check(not scene.habitat.walkways.at(Vector2.ZERO).is_empty(),"The supplied log supports both banks")
	check(not scene.navigation.path(Vector3(-3,0,0),Vector3(3,0,0)).is_empty(),"The placed bridge connects the banks")
	var crossed := false
	for i in range(4200):
		scene._process(1.0/60.0)
		if scene.creature.state==CreatureActor.State.WALKING and absf(scene.creature.position.x)<0.3:
			crossed = true
			break
		if wish._planning: await process_frame
	check(crossed and scene.creature.balancing,"Bigfoot walks and balances over the chasm")
	await capture("crossing")
	# Bridge removal must produce a visible fall, never an immediate teleport.
	var before: Vector3 = scene.creature.position
	editor.select_object(log_id)
	editor.delete_selected()
	scene._refresh_habitat()
	check(scene.creature.state==CreatureActor.State.FALLING,"Removing the bridge beneath him starts a fall")
	check(scene.creature.position.distance_to(before)<0.01,"Fall begins at his actual feet")
	for i in range(30): scene._process(1.0/60.0)
	check(scene.creature.position.y<before.y-0.5,"Gravity visibly carries him below the bank")
	await capture("fall")
	var falling: Vector3 = scene.creature.position
	scene._paused = true
	for i in range(60): scene._process(1.0/60.0)
	check(scene.creature.position==falling,"Pause freezes the fall")
	scene._paused = false
	await settle(scene)
	check(scene.creature.state!=CreatureActor.State.FALLING and scene.navigation.is_safe(scene.creature.position),"He recovers on a safe bank")
	check(scene.routine.habits.outing_visits==0,"An interrupted crossing earns no visit")
	# The diorama carry controller supports a deliberate release into the gap.
	scene.creature.pick_up()
	scene.creature.position = Vector3(0,1,0)
	check(not scene.try_void_fall(),"Held Bigfoot does not fall before release")
	scene._resident_play.release(scene.camera.unproject_position(Vector3.ZERO))
	check(scene.creature.state==CreatureActor.State.FALLING,"Resident release into the gap starts falling")
	await settle(scene)
	# Main cozy carry is a screen portrait; its release must also resolve voids.
	scene.places.holding = true
	scene.places.origin_feet = Vector3(-3,0,0)
	scene.places.old_paused = false
	scene.places.drop_at(scene.camera.unproject_position(Vector3.ZERO))
	check(scene.creature.state==CreatureActor.State.FALLING,"Main cozy portrait drop falls into the gap")
	await settle(scene)
	check(scene.navigation.is_safe(scene.creature.position),"Cozy carry recovers safely too")
	# A log above his head is not support, nor a valid recovery bank.
	var overhead := data.place("log",Vector2.ZERO,0,4.0,NativeObjectPose.make(Basis.from_scale(Vector3.ONE*4.0),-0.35))
	editor.refresh()
	scene._refresh_habitat()
	scene.creature.pick_up()
	scene.creature.position = Vector3(0,-1,0)
	scene._resident_play.release(scene.camera.unproject_position(Vector3.ZERO))
	check(scene.creature.state==CreatureActor.State.FALLING,"Releasing below an overhead bridge still falls")
	await settle(scene)
	check(data.ground_height(Vector2(scene.creature.position.x,scene.creature.position.z))!=null,"Recovery chooses a bank rather than the overhead log")
	editor.select_object(overhead)
	editor.delete_selected()
	scene._refresh_habitat()
	# A physical shove uses the collision solver before the void takes over.
	scene.creature.reset_at(Vector3(-2,0,0))
	check(scene.creature.receive_impulse(Vector3(200,25,0)),"A shove starts physical motion")
	var pushed_fall := false
	for i in range(240):
		await physics_frame
		scene._process(1.0/60.0)
		if scene.creature.state==CreatureActor.State.FALLING:
			pushed_fall = true
			break
	check(pushed_fall,"A physical shove over the edge becomes a real fall")
	await settle(scene)
	check(scene.navigation.is_safe(scene.creature.position),"Pushed Bigfoot recovers safely")
	await capture("glade")
	check(scene.save_current(),"Chasm saves through the main place store")
	scene.free()
	var reopened = load("res://studies/cozy_worlds.tscn").instantiate()
	reopened.library_path = folder
	reopened.recent_file = folder+"/recent.cfg"
	reopened.places_path = folder+"/places.json"
	root.add_child(reopened)
	while not reopened.places_ready: await process_frame
	check(reopened._chunk_editor.data.ground_height(Vector2.ZERO)==null,"Main saved world still contains a void after restart")
	check(reopened.navigation.is_safe(reopened.creature.position),"Restart restores Bigfoot on safe ground")
	reopened.free()
	print("BIGFOOT CHASM failures=",failures)
	quit(1 if failures else 0)
