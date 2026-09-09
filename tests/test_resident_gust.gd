extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.library_path = "/private/tmp/zenscape-gust-test"
	scene.recent_file = scene.library_path+"/recent.cfg"
	root.add_child(scene)
	scene.new_diorama()
	scene.invite_bigfoot(Vector3.ZERO)
	scene._focus_bigfoot()
	await process_frame
	scene._gust_button.pressed.emit()
	var press := InputEventMouseButton.new()
	press.pressed = true
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = scene.camera.unproject_position(Vector3(2,0,2))
	root.push_input(press,true)
	var wind = scene._resident_wind
	check(wind._pending.is_empty() and wind.field._gusts.is_empty(),"Press begins aiming without sending wind")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = press.position
	root.push_input(release,true)
	check(wind._pending.is_empty(),"A click without dragging emits no gust")
	root.push_input(press,true)
	var move := InputEventMouseMotion.new()
	move.position = scene.camera.unproject_position(Vector3(-1,0,2))
	root.push_input(move,true)
	check(wind.visuals.aim.mesh != null and wind._pending.is_empty(),"Dragging shows an aim arrow without firing")
	if "--capture-gust" in OS.get_cmdline_user_args():
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("/private/tmp/resident-gust-aim.png")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	root.push_input(escape,true)
	check(wind.visuals.aim.mesh == null and wind._pending.is_empty() and scene._resident_play.gust,"Escape cancels aiming and keeps the tool ready")
	root.push_input(press,true)
	root.push_input(move,true)
	release.position = Vector2(-10,-10)
	root.push_input(release,true)
	check(wind._pending.is_empty() and scene._resident_play.aim_start == null,"Release outside the world cancels the gust")
	root.push_input(press,true)
	root.push_input(move,true)
	release.position = move.position
	root.push_input(release,true)
	check(wind._pending.size() == 1,"Release sends exactly one gust")
	if not wind._pending.is_empty():
		check(wind._pending[0].direction.dot(Vector3.LEFT)>0.99,"Gust follows the drag direction, independent of ambient wind")
	check(wind.visuals.aim.mesh == null,"Release clears the aim arrow")
	var reacted := false
	for i in range(60):
		await physics_frame
		if scene.creature.state == CreatureActor.State.WIND:
			reacted = true
			break
	check(reacted,"Toolbar gust knocks Bigfoot into physical wind response")
	if scene.get("_resident_wind") != null:
		check(not wind.visuals.trails.is_empty(),"The emitted gust has visible ribbons")
		await create_timer(0.2).timeout
		check(scene.creature.wind_body.linear_velocity.length()>0.1,"Gust physically moves Bigfoot")
		if "--capture-gust" in OS.get_cmdline_user_args():
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("/private/tmp/resident-gust.png")
		scene._paused = true
		await process_frame
		await physics_frame
		var pose: Transform3D = scene.creature.wind_body.global_transform
		var age: float = wind.field._gusts[0].age
		await create_timer(0.15).timeout
		check(scene.creature.wind_body.global_transform.is_equal_approx(pose) and wind.field._gusts[0].age == age,"Pause freezes gust and tumbling actor together")
		scene._paused = false
		var recovered := false
		for i in range(600):
			await physics_frame
			if scene.creature.can_roam():
				recovered = true
				break
		check(recovered,"Bigfoot recovers onto safe ground after the gust")
		check(scene.creature.global_transform.is_finite(),"Recovery leaves a finite pose")
	else:
		check(false,"Product scene has visible physical gusts")
	scene.free()
	print("RESIDENT GUST failures=",failures)
	quit(failures)
