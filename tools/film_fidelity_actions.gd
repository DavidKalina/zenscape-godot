extends SceneTree
var scene: Node
var frame := 0
var kind := "stone"
var started := false
var start_frame := 0
var contact_error := -1.0
var off_world := false
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--kind="): kind = argument.trim_prefix("--kind=")
	scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._ui.visible = false
	scene._auto_orbit = false
	scene._refresh_habitat()
	scene.routine._next_action = INF
	if not scene.routine.request(kind):
		push_error("No reachable target for "+kind)
		scene.free()
		quit(1)
		return
	process_frame.connect(_frame)
func _frame() -> void:
	frame += 1
	scene._process(1.0/60.0)
	if not started and scene.routine._phase == "perform":
		started = true
		start_frame = frame
		scene.frame_creature(8.0,scene.creature.rotation.y-0.65)
		print("PERFORM ",kind," frame=",frame," feet=",scene.creature.position," target=",scene.routine.target)
	if started:
		var local_frame := frame-start_frame
		if local_frame in [30,60,90,150,180,240,360]: _capture.call_deferred(local_frame)
		if local_frame == 63 and kind in ["stone","fish"] and not scene.routine.target.is_empty():
			var point: Vector3 = scene.routine.target.position
			if kind == "stone": point.y += 0.24*float(scene.routine.target.record.scale)
			contact_error = scene.creature.hand_position().distance_to(point)
			print("CONTACT ",kind," error=",contact_error," palm=",scene.creature.hand_position()," target=",point)
		for projectile in scene.routine._projectiles:
			if absf(projectile.node.position.x)>14 or absf(projectile.node.position.z)>14: off_world = true
		if scene.routine.active.is_empty() and local_frame>420 or local_frame>4500:
			print("ACTION RESULT ",kind," history=",scene.routine.history," off_world=",off_world," contact_error=",contact_error," cancel=",scene.routine.last_cancel)
			quit(0 if kind in scene.routine.history else 1)
	if frame>6000:
		push_error("Action film timed out: "+kind)
		quit(1)
func _capture(at: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/fidelity-life/actions/"+kind+"-%03d.png" % at)
