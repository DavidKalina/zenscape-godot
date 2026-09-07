extends SceneTree
## Scene integration check. Pass -- --capture=/absolute/path.png for a rendered
## preview (run without --headless when capturing).

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/sandbox.tscn").instantiate() as Node3D
	scene.save_path = "/tmp/zenscape-scene-test-unused.json"
	root.add_child(scene)
	await process_frame
	var terrain: TerrainView = scene.get_node("Terrain")
	var camera: Camera3D = scene.get_node("OrbitCamera/Camera3D")
	_check(terrain.mesh.get_surface_count() == 1, "Terrain renders as one mesh surface")
	var hit: Variant = terrain.ray_hit(Vector3(0, 12, 0), Vector3.DOWN)
	_check(hit != null and absf(hit.y - terrain.data.height_at(Vector2.ZERO)) < 0.002, "Picking matches the rendered surface")
	_check(terrain.ray_hit(Vector3(30, 12, 30), Vector3.DOWN) == null, "Picking outside the plot misses")
	var arrays := terrain.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	_check(normals[0].y > 0.0, "Ground normals face upward")
	var before := terrain.data.heights.duplicate()
	# Exercise the same UI selection and input handler used by real brush presses.
	scene._select_tool("raise")
	scene._hit = null # The pointer was on the toolbar in the previous frame.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = camera.unproject_position(hit)
	scene._unhandled_input(press)
	press.pressed = false
	scene._unhandled_input(press)
	_check(terrain.data.heights != before, "A fast click picks terrain without a cached hover hit")
	scene._undo()
	_check(terrain.data.heights == before, "The Undo action restores that click")
	scene._redo()
	_check(terrain.data.heights != before, "The Redo action restores that click")
	# Build a visible hill to inspect the brush footprint and faceted shading.
	terrain.data.begin_stroke()
	terrain.data.brush(Vector2(1.0, -1.0), 4.5, 3.0, 1.1, "raise", 0.0)
	terrain.data.end_stroke()
	var started := Time.get_ticks_usec()
	terrain.rebuild()
	print("Mesh rebuild: %.2f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	var target := Vector3(1.0, terrain.data.height_at(Vector2(1, -1)), -1.0)
	var screen := camera.unproject_position(target)
	var picked: Variant = terrain.ray_hit(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	_check(picked != null and picked.distance_to(target) < 0.01, "Camera ray picking follows sculpted ground")
	# Check both orbit and zoom through the camera's normal input handler.
	var orbit: Node3D = scene.get_node("OrbitCamera")
	var old_size := camera.size
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	orbit._unhandled_input(wheel)
	_check(camera.size < old_size, "The scroll wheel zooms the camera")
	camera.size = old_size
	scene.set_process(false)
	scene._dirty = false # This test must not persist its temporary landscape.
	terrain.show_brush(Vector2(1.0, -1.0), 2.2, true)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			for i in range(5):
				await process_frame
			await RenderingServer.frame_post_draw
			var destination := argument.trim_prefix("--capture=")
			_check(root.get_texture().get_image().save_png(destination) == OK, "Preview image saves")
			print("Preview: ", destination)
	if failures == 0:
		print("PASS: scene integration checks")
	scene.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
