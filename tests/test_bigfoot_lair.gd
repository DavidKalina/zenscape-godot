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
	scene.cave_hover = false
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
	var walls: Array = scene.lair.get_node("RockWalls").get_children()
	var room_bounds: AABB = scene.lair.global_transform*walls[0].mesh.get_aabb()
	for wall in walls:
		room_bounds = room_bounds.merge(scene.lair.global_transform*wall.mesh.get_aabb())
		room_bounds = room_bounds.merge(scene.lair.global_transform*wall.get_node("Earth").mesh.get_aabb())
	var surface_bounds: AABB = scene.get_node("Reference/skirt").global_transform*scene.get_node("Reference/skirt").mesh.get_aabb()
	check(scene.get_node("Reference").find_child("mesh-3",true,false).layers==0,"Old suspended underside is replaced rather than hanging inside the room")
	check(room_bounds.size.x>=28 and room_bounds.size.z>=28 and room_bounds.size.y>8,"Lower story spans the full chunk footprint with substantial height")
	check(room_bounds.end.y>=surface_bounds.position.y and room_bounds.position.y<surface_bounds.position.y,"Lower story meets the original chunk without a vertical gap")
	var skirt_mesh: Mesh = scene.get_node("Reference/skirt").mesh
	var earth_material: ShaderMaterial = walls[0].get_node("Earth").material_override
	check(earth_material.shader==skirt_mesh.surface_get_material(0).shader and earth_material.get_shader_parameter("flat_faces")==true and scene.lair.strata[0].is_equal_approx(scene.lair.strata_from(skirt_mesh)[0]),"Cave walls continue the chunk's own earth material and strata")
	scene._focus_lair()
	check(scene.camera.cull_mask==shared_mask and scene.get_node("Reference").visible,"Window inspection preserves the surface and the shared camera mask")
	for frame in range(80): scene._process(1.0/60.0)
	var opened: Array = scene.lair.wall_reveal.filter(func(value: float) -> bool: return value>0.0)
	check(opened.size()==1 and opened[0]==1.0,"Lair inspection dissolves exactly the facing wall")
	scene._focus_cave()
	check(scene.camera.cull_mask==shared_mask,"Cave focus never hides the lower story")
	scene._focus_bigfoot()
	check(scene.camera.cull_mask==shared_mask,"Find Bigfoot preserves both stories")
	scene._reset_camera()
	check(scene.camera.cull_mask==shared_mask,"Reset returns to the combined diorama")
	scene.cave_hover = true
	scene._focus_stack()
	var home := Vector3(scene.yaw,scene.polar,scene.distance)
	var side: int = scene.lair.side_facing(scene.camera.global_position)
	var aim_at: Vector3 = scene.lair.to_global(scene.lair.wall_normal(side)*scene.lair.HALF_WIDTH+Vector3.UP*4.0)
	scene.cave_pointer = scene.camera.unproject_position(aim_at)
	for frame in range(260): scene._process(1.0/60.0)
	check(scene._inspect_side==side and scene.distance<home.z-5.0 and scene.lair.wall_reveal[side]==1.0,"Hovering a wall glides the camera in, then opens that wall")
	scene.cave_pointer = Vector2(4,4)
	for frame in range(200): scene._process(1.0/60.0)
	check(Vector3(scene.yaw,scene.polar,scene.distance).distance_to(home)<0.001 and scene.lair.wall_reveal.max()==0.0,"Moving off the cave glides back to the previous view and closes it")
	scene.cave_pointer = scene.camera.unproject_position(aim_at)
	for frame in range(60): scene._process(1.0/60.0)
	scene.distance += 3.0
	var taken: float = scene.distance
	scene.cave_pointer = Vector2(4,4)
	for frame in range(120): scene._process(1.0/60.0)
	check(scene._inspect_home.is_empty() and is_equal_approx(scene.distance,taken),"Zooming during an inspection keeps the viewer's camera")
	scene.cave_hover = false
	scene.cave_pointer = null
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
