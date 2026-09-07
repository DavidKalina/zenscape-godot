extends SceneTree
## End-to-end garden loop through the sandbox's tool handlers, plus disk reopen.
var failures := 0
var save_file := "/tmp/zenscape-garden-integration-%d.json" % OS.get_process_id()
var capture_directory := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_directory = arg.trim_prefix("--capture-dir=")
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/sandbox.tscn")
	var scene: Node3D = packed.instantiate()
	scene.save_path = save_file
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._start_flat()
	check(scene.garden.data.heights.count(0.0) == LandscapeData.SIDE * LandscapeData.SIDE, "Start flat clears the ground")
	stroke(scene, "raise", Vector2(-3, -3), 4.5, 1.5)
	stroke(scene, "lower", Vector2(4, 2), 3.5, 0.45)
	stroke(scene, "meadow", Vector2(-3, -2), 5.0, 2.0)
	stroke(scene, "meadow", Vector2(0, 4), 3.0, 1.5)
	check(scene.garden.data.height_at(Vector2(-3, -3)) > 2.5, "Sculpted hill rises")
	check(scene.garden.data.height_at(Vector2(4, 2)) < -0.4, "Sculpted hollow descends")
	for entry: Array in [["tree", Vector2(-3, -3)], ["rock", Vector2(0, 1)], ["flower", Vector2(1, 3)]]:
		scene._select_tool(entry[0])
		click(scene, entry[1])
	check(scene.garden.data.objects.size() == 3, "Tree, stone and individual flower are placed")
	check(scene.garden.get_node("Canopy").multimesh.instance_count == 1, "Tree uses the actual canopy renderer")
	check(scene.garden.get_node("Grass").multimesh.instance_count > 500, "Meadow painting renders hundreds of blades")
	var rooted: Vector3 = scene.garden.get_node("Canopy").multimesh.get_instance_transform(0).origin
	stroke(scene, "raise", Vector2(-3, -3), 2.0, 0.2)
	check(scene.garden.get_node("Canopy").multimesh.get_instance_transform(0).origin.y > rooted.y, "Rendered tree follows a terrain edit")
	scene._undo()
	check(scene.garden.get_node("Canopy").multimesh.get_instance_transform(0).origin == rooted, "Undo restores the rendered anchor")
	scene._select_tool("pond")
	scene.pond_level = -0.1
	click(scene, Vector2(4, 2))
	click(scene, Vector2(4.1, 2))
	check(scene.garden.data.ponds.size() == 1, "Refilling a connected pond does not stack water")
	check(not scene.garden.pond_vertices.is_empty(), "Pond surface fills the hollow")
	for vertex: Vector3 in scene.garden.pond_vertices:
		check(absf(vertex.y + 0.1) < 0.00001, "Water has a consistent level")
	# Another separated basin must not fill just because it is lower.
	stroke(scene, "lower", Vector2(-7, 5), 2.0, 0.4)
	for vertex: Vector3 in scene.garden.pond_vertices:
		check(vertex.x > 0, "Pond does not jump into a disconnected hollow")
	scene.terrain.show_brush(Vector2.ZERO, 1, false)
	await capture("garden-clear", scene)
	for weather in ["Mist", "Snow", "Rain"]:
		var index := GardenData.WEATHER.find(weather)
		scene._weather_selector.item_selected.emit(index)
		await process_frame
		check(scene.garden.data.weather == weather, "Weather control changes the saved setting")
		check(scene._weather_effect.visible == (weather != "Mist"), "Precipitation follows selected weather")
		await capture("garden-" + weather.to_lower(), scene)
	# Save an intentional close view as well as the garden contents.
	scene.camera.size = 30
	scene.orbit.position = Vector3(-2.0, 0.7, 2.0)
	var expected: Dictionary = scene.garden.data.to_document()
	var expected_view: Array = scene._camera_state()
	var expected_water: PackedVector3Array = scene.garden.pond_vertices.duplicate()
	check(scene._save(), "Save writes the garden to disk")
	scene.queue_free()
	await process_frame
	var reopened: Node3D = packed.instantiate()
	reopened.save_path = save_file
	root.add_child(reopened)
	await process_frame
	reopened.set_process(false)
	check(reopened.garden.data.to_document() == expected, "Fresh scene reopens every world value exactly")
	check(reopened._camera_state() == expected_view, "Reopening restores camera framing")
	check(reopened.garden.pond_vertices == expected_water, "Reopening reconstructs the identical shoreline")
	check(reopened.garden.get_node("Canopy").multimesh.get_instance_transform(0).origin == rooted, "Reopening reconstructs tree placement")
	await capture("garden-reopened", reopened)
	reopened._dirty = false
	reopened.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_file)
	print("Garden integration: ", failures, " failures")
	quit(1 if failures else 0)

func stroke(scene: Node3D, tool: String, point: Vector2, radius: float, seconds: float) -> void:
	scene._select_tool(tool)
	scene.radius = radius
	scene.garden.data.begin_stroke()
	scene._painting = true
	scene._dab(point, seconds)
	scene._refresh()
	scene._finish_stroke()

func click(scene: Node3D, point: Vector2) -> void:
	scene._hit = null
	var world := Vector3(point.x, scene.garden.data.height_at(point), point.y)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = scene.camera.unproject_position(world)
	event.pressed = true
	scene._unhandled_input(event)
	event.pressed = false
	scene._unhandled_input(event)

func capture(label: String, scene: Node3D) -> void:
	if capture_directory.is_empty():
		return
	scene.terrain.show_brush(Vector2.ZERO, 1, false)
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_directory.path_join(label + ".png")) == OK, "Capture saves")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
