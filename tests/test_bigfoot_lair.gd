extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/bigfoot_lair.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.replaying = false
	scene._growth.publish()
	scene._precipitation.set_weather(0,true)
	var resident = scene.creature
	check(scene.routine.cave.request("hibernate"),"Resident can begin a lair visit")
	for frame in range(2400):
		scene._process(1.0/60.0)
		if scene.routine.cave.concealed: break
	check(scene.routine.cave.concealed and resident.global_position.distance_to(scene.lair.bed.global_position)<0.01,"The same resident occupies the underground bed")
	check(resident.action_clip=="Sleep" and resident.state==CreatureActor.State.ACTION,"Underground rest plays the sleep animation")
	scene._toggle_lair()
	scene._process(0)
	check(resident.visible and scene.camera.cull_mask==4,"Inspection reveals the occupied room")
	scene._focus_cave()
	check(not scene.inspecting and scene.camera.cull_mask==1,"Cave focus returns to the visible surface")
	scene._focus_bigfoot()
	check(scene.inspecting and scene.camera.cull_mask==4,"Find Bigfoot reveals his underground room")
	scene._reset_camera()
	check(not scene.inspecting and scene.camera.cull_mask==1,"Camera reset exits inspection coherently")
	scene._toggle_lair()
	scene._growth.terrain = 0.5
	scene._process(0)
	check(not resident.visible,"Inspection respects terrain growth visibility")
	scene._growth.terrain = 1.0
	scene._process(0)
	var saved: Dictionary = scene.capture_diorama_state()
	check(saved.position[1]>0,"Saving underground retains a surface exit position")
	var room_clock: float = scene.lair.drips.clock
	var rest_clock: float = scene.routine.cave._away
	scene._paused = true
	scene._process(1)
	check(scene.lair.drips.clock==room_clock and scene.routine.cave._away==rest_clock,"Pause freezes both dripping and rest")
	scene._paused = false
	scene.lair.redress(42)
	check(resident.global_position.distance_to(scene.lair.bed.global_position)<0.01,"Changing rock dressing preserves the occupied bed")
	for frame in range(180): scene._process(1.0/60.0)
	for child in scene.find_children("*","CanvasLayer",true,false): child.hide()
	scene._ui.hide()
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/private/tmp/bigfoot-lair.png")
	scene._toggle_lair()
	scene._process(0)
	check(not resident.visible and scene.camera.cull_mask==1,"Surface view conceals the underground resident")
	for frame in range(7200):
		scene._process(1.0/60.0)
		if scene.routine.cave.phase.is_empty(): break
	check(scene.routine.cave.phase.is_empty() and scene.navigation.is_safe(resident.position),"Rest completes and resident returns to safe surface ground")
	check(resident.visible and resident==scene.creature,"Surface return restores the same visible resident")
	scene.routine.cancel()
	resident.reset_at(scene.routine.cave.entrance)
	check(scene.routine.cave.request(),"A second visit can begin")
	for frame in range(1800):
		scene._process(1.0/60.0)
		if scene.routine.cave.concealed: break
	scene.routine.cave.cancel()
	scene._process(0)
	check(not scene.routine.cave.concealed and scene.navigation.is_safe(resident.position),"Cancelling an occupied room restores the resident safely")
	scene.free()
	print("BIGFOOT LAIR: failures=",failures)
	quit(1 if failures else 0)
