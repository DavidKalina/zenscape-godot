extends SceneTree
var scene: Node
var frame := 0
var start := Vector2.ZERO
var finish := Vector2.ZERO
var states: Array[int] = []
var peak := 0.0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	scene = load("res://studies/god_mode_playground.tscn").instantiate()
	root.add_child(scene)
	for i in range(10): await process_frame
	scene.brain.enabled = false
	scene._attention_time = 30.0
	process_frame.connect(_frame)
func _frame() -> void:
	frame += 1
	if frame == 60:
		start = scene.camera.unproject_position(scene.spring_tree.center(3.5))
		finish = scene.camera.unproject_position(scene.spring_tree.center(3.5)+Vector3(-4.7,0,0))
		scene.begin_tree_drag(start)
	if frame > 60 and frame <= 150: scene.move_tree_drag(start.lerp(finish,float(frame-60)/90.0))
	if frame == 180:
		print("FILM RELEASE ",scene._tree_drag," tension=",scene.spring_tree.tension," pos=",scene.creature.global_position)
		scene.release_tree_drag()
	peak = maxf(peak,scene.creature.global_position.distance_to(scene._home))
	if scene.creature.state not in states: states.append(scene.creature.state)
	if frame in [45,150,195,230,330,540]: _capture.call_deferred(frame)
	if frame == 600:
		print("GOD MODE FILM ",JSON.stringify({"peak_displacement":peak,"states":states,"tree_height":scene.spring_tree.get_child(0).mesh.get_aabb().end.y}))
		process_frame.disconnect(_frame)
		scene.queue_free()
		await process_frame
		quit()
func _capture(at: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/god-mode-playground/frame-%03d.png" % at)
