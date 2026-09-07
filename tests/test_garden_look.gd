extends SceneTree
## Checks the shared renderer against live edited geometry, with a real GPU.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node3D = load("res://scenes/sandbox.tscn").instantiate()
	scene.save_path = "/tmp/zenscape-look-unused-%d.json" % OS.get_process_id()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var data: GardenData = scene.garden.data
	var look: GardenLook = scene.look
	check(look.lighting.environment.tonemap_mode == Environment.TONE_MAPPER_ACES, "Garden uses source tone mapping")
	check(look.lighting.lights.size() == 2, "Garden uses the source key and rim lights")
	check(scene.terrain.ground_material.shader.resource_path.ends_with("reference_surface.gdshader"), "Editable ground uses source material shading")
	check(look.display_fog.material.get_shader_parameter("orthographic") == true, "Air uses orthographic rays")
	check(look.display_fog.blend.get_shader_parameter("surface_orthographic") == true, "Surface haze uses orthographic depth")
	var before := look.surface_map.ground.get_image().get_pixel(64,64)
	check(before.g == 0.0, "Atmosphere starts on flat terrain")
	data.brush(Vector2.ZERO, 3, 2, 1, "raise", 0)
	data.brush(Vector2(4,2), 3, 2, 1, "lower", 0)
	data.add_pond(Vector2(4,2), -0.1)
	scene._refresh()
	var image := look.surface_map.ground.get_image()
	check(absf(image.get_pixel(64,64).g - data.height_at(Vector2(0.125,0.125))) < 0.00001, "Atmosphere ground map follows sculpted terrain")
	var water := image.get_pixel(80,72)
	check(absf(water.a + 0.1) < 0.00001 and water.g < water.a and water.r == water.a, "Atmosphere sees the pond above its bed")
	check(image.get_pixel(0,0).g < -100, "Atmosphere excludes the area beyond the plot")
	check(look.air._summit.y > 1.9, "Atmosphere summit follows the edited hill")
	data.brush(Vector2(4,2), 4, 2, 1, "raise", 0)
	scene._refresh()
	check(look.surface_map.ground.get_image().get_pixel(80,72).a < -100, "Filling a basin with earth removes stale water occlusion")
	var flat := GardenData.new()
	var low := PackedVector3Array([Vector3(-1,0.4,-1), Vector3(1,0.4,-1), Vector3(-1,0.4,1)])
	var high := PackedVector3Array([Vector3(-1,0.7,-1), Vector3(1,0.7,-1), Vector3(-1,0.7,1)])
	var map := GardenSurfaceMap.new()
	map.update(flat, low + high)
	var first := map.ground.get_image().get_data()
	map.update(flat, high + low)
	check(map.ground.get_image().get_data() == first, "Overlapping water maps are independent of insertion order")
	check(absf(map.ground.get_image().get_pixel(63,63).a - 0.7) < 0.00001, "Atmosphere uses the highest overlapping pond")
	scene._dirty = false
	scene.queue_free()
	await process_frame
	print("Garden look checks: ", failures, " failures")
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
