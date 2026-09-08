extends SceneTree
## A short deterministic reel through the same carrying/landing actor used live.
var scene: Node3D
var frame := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,900)
	scene = load("res://studies/bigfoot_playground.tscn").instantiate()
	root.add_child(scene)
	root.content_scale_factor = 1.0
	scene.set_process(false)
	scene._play_ui.visible = false
	scene._paused = true
	scene.creature.set_process(false)
	scene.target = Vector3(0,1.9,0)
	scene.distance = 8.0
	scene.polar = 1.25
	scene._update_camera()
	scene._process(0.0)
	process_frame.connect(_frame)
func _frame() -> void:
	frame += 1
	var creature: CreatureActor = scene.creature
	if frame == 30: creature.pick_up()
	if frame >= 30 and frame < 210:
		var t := float(frame-30)/60.0
		creature.move_held(Vector3(sin(t*1.5)*0.22,minf(t*3.0,1.0),0),1.0/60.0)
	if frame == 210: creature.release_at(Vector3.ZERO)
	creature.advance(1.0/60.0)
	if frame == 115:
		_capture.call_deferred()
	if frame >= 300: quit()
func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/bigfoot-playground/head-grab.png")
