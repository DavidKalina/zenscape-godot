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
	scene._focus_stack()
	scene._process(0)
	var shared_mask: int = scene.camera.cull_mask
	check(resident.visible and shared_mask&5==5,"Both stories and the sleeping resident share the main view")
	var room_bounds: AABB = scene.lair.global_transform*scene.lair.get_node("WindowedRockWalls").mesh.get_aabb()
	var surface_bounds: AABB = scene.get_node("Reference/skirt").global_transform*scene.get_node("Reference/skirt").mesh.get_aabb()
	check(scene.get_node("Reference").find_child("mesh-3",true,false).layers==0,"Old suspended underside is replaced rather than hanging inside the room")
	check(room_bounds.size.x>=28 and room_bounds.size.z>=28 and room_bounds.size.y>8,"Lower story spans the full chunk footprint with substantial height")
	check(room_bounds.end.y>=surface_bounds.position.y and room_bounds.position.y<surface_bounds.position.y,"Lower story meets the original chunk without a vertical gap")
	scene._focus_lair()
	check(scene.camera.cull_mask==shared_mask and scene.get_node("Reference").visible,"Window inspection preserves the surface and the shared camera mask")
	scene._focus_cave()
	check(scene.camera.cull_mask==shared_mask,"Cave focus never hides the lower story")
	scene._focus_bigfoot()
	check(scene.camera.cull_mask==shared_mask,"Find Bigfoot preserves both stories")
	scene._reset_camera()
	check(scene.camera.cull_mask==shared_mask,"Reset returns to the combined diorama")
	scene._growth.terrain = 0.5
	scene._process(0)
	check(not resident.visible,"The stacked view respects terrain growth visibility")
	scene._growth.terrain = 1.0
	scene._process(0)
	var lights_isolated := true
	for light in scene.lair.find_children("*","Light3D",true,false):
		if light.light_cull_mask&1 and not light.shadow_enabled: lights_isolated = false
	check(lights_isolated,"Room lights illuminate the underground resident without leaking upstairs")
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
	scene._focus_stack()
	scene._process(0)
	check(resident.visible and scene.camera.cull_mask==shared_mask,"The sleeping resident stays visible when viewing the whole stack")
	for frame in range(7200):
		scene._process(1.0/60.0)
		if scene.routine.cave.phase.is_empty(): break
	check(scene.routine.cave.phase.is_empty() and scene.navigation.is_safe(resident.position),"Rest completes and resident returns to safe surface ground")
	check(resident.visible and resident==scene.creature,"Surface return restores the same visible resident and surface lighting")
	scene.routine.cancel()
	resident.reset_at(scene.routine.cave.entrance)
	check(scene.routine.cave.request(),"A second visit can begin")
	for frame in range(1800):
		scene._process(1.0/60.0)
		if scene.routine.cave.concealed: break
	scene.routine.cave.cancel()
	scene._process(0)
	check(not scene.routine.cave.concealed and scene.navigation.is_safe(resident.position),"Cancelling an occupied room restores the resident safely")
	# Flush batched visibility/light changes before removing their geometry.
	await process_frame
	RenderingServer.force_draw(false)
	scene.queue_free()
	await process_frame
	print("BIGFOOT LAIR: failures=",failures)
	quit(1 if failures else 0)
