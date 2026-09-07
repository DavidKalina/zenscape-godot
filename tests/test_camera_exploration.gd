extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	for size in [Vector2i(1440,900),Vector2i(900,1200)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		scene._reset_camera()
		var skirt: MeshInstance3D = scene.get_node("Reference/skirt")
		var vertices: PackedVector3Array = skirt.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var screen: Vector2 = scene.camera.unproject_position(skirt.to_global(vertex))
			check(Rect2(Vector2(size)*0.025,Vector2(size)*0.95).has_point(screen),"Frame includes the whole exposed base")
	scene.distance = 6.5
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.factor = 1.0
	scene._unhandled_input(wheel)
	check(scene.distance < 6.5,"Zooming in after Bigfoot moves closer")
	scene.distance = 0.5
	scene._unhandled_input(wheel)
	check(scene.distance == 0.5,"Close zoom respects the near limit")
	scene.distance = 10
	wheel.factor = 0.25
	scene._unhandled_input(wheel)
	check(scene.distance > 9.2 and scene.distance < 10,"Trackpad fractional zoom remains gentle")
	scene._reset_camera(true)
	check(scene.target.distance_to(scene._vector(scene._source.camera.target)) < 0.0001,"Reference comparison keeps original framing")
	scene.queue_free()
	await process_frame
	print("PASS: landscape framing, close zoom, fractional scroll and reference view" if failures == 0 else "FAIL: camera exploration")
	quit(1 if failures else 0)
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
