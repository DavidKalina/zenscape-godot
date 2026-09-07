extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var leaves = scene._precipitation.leaves
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/leaves.json"))
	check(leaves.multimesh.instance_count == 520, "Original leaf population")
	check(leaves.multimesh.visible_instance_count == 0, "No leaf fall before autumn")
	for i in range(520):
		var p = leaves.multimesh.get_instance_transform(i).origin
		var a = leaves.multimesh.get_instance_custom_data(i)
		var expected := Vector3(source.positions[i * 3], source.positions[i * 3 + 1], source.positions[i * 3 + 2])
		check(p.distance_to(expected) < 0.00001, "Original canopy particle location")
		for j in range(4):
			check(absf(a[j] - source.attributes[i * 4 + j]) < 0.00001, "Original leaf cycle attribute")
	scene._precipitation.set_weather(7, true)
	scene._process(0.0)
	check(leaves.multimesh.visible_instance_count == 520, "Autumn enables source leaves")
	scene._process(0.5)
	var time: float = scene._motion_time
	var air: float = scene._atmosphere._gust_distance
	scene._paused = true
	scene._process(1.0)
	check(scene._motion_time == time and scene._atmosphere._gust_distance == air, "Pause holds falling time and release field")
	leaves.enabled = false
	scene._process(0.0)
	check(leaves.multimesh.visible_instance_count == 0, "Control removes leaves without changing autumn")
	check(scene._precipitation.surface_weather.autumn == 1.0, "Control retains season")
	leaves.enabled = true
	scene._precipitation.set_weather(0, true)
	scene._process(0.0)
	check(leaves.multimesh.visible_instance_count == 0, "Clear weather removes leaf fall")
	# Isolate actual leaf rendering against black. A signed projection scale
	# used to clamp every native quad to one pixel despite correct CPU state.
	for child in scene.get_children():
		if child is Node3D and child != scene.camera and child != scene._precipitation:
			child.visible = false
	scene._ui.visible = false
	if scene._display_fog != null:
		scene._display_fog.visible = false
	scene._environment.background_mode = Environment.BG_COLOR
	scene._environment.background_color = Color.BLACK
	scene._environment.volumetric_fog_enabled = false
	scene.target = Vector3(11.64, 2, -3.3)
	scene.distance = 4.0
	scene.polar = 1.2
	scene.yaw = 1.57
	scene._update_camera()
	scene._precipitation.surface_weather.autumn = 1.0
	scene._precipitation.surface_weather.publish()
	leaves.update_season(1.0)
	for i in range(3):
		RenderingServer.force_draw(false)
		await process_frame
	var image := root.get_texture().get_image()
	var colored := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if maxf(c.r, maxf(c.g, c.b)) > 0.1:
				colored += 1
	print("Rendered leaf pixels: ", colored)
	check(colored > 500, "Leaves retain source projected size on the native renderer")
	scene.queue_free()
	await process_frame
	print("PASS: source leaf data, seasonal gating, pause and control" if failures == 0 else "FAIL: leaves")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
