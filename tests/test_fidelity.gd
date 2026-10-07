extends SceneTree
## suite: gpu

var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Fidelity checks need a graphics renderer for MultiMesh transforms.")
		quit(1)
		return
	_check_scene.call_deferred()

func _check_scene() -> void:
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var reference := scene.get_node("Reference")
	_check(reference.has_meta("source_settings"), "Runtime camera and light settings are embedded")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	for pair: Array in [["zs_sky_down", "uDown"], ["zs_sky_up", "uUp"], ["zs_sky_glow", "uGlow"], ["zs_sun_direction", "uSunDir"]]:
		var values: Array = source.sky[pair[1]]
		var expected := Vector3(values[0], values[1], values[2])
		_check(scene._celestial.state[pair[0]].distance_to(expected) < 0.00001, "Daylight state matches captured source: " + pair[1])
	_check(absf(scene._lights[0].light_energy * PI - source.lights[0].intensity) < 0.00001, "Sun intensity matches the source at the reference hour")
	_check(scene._precipitation.cloud_layer.is_equal_approx(Vector2(20, 12)), "Cloud slab retains the source mountain override")
	var cloud_reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/fidelity/source-clouds.json"))
	scene._precipitation.cloud_override = 0.7
	scene._process(0.0)
	for pair: Array in [["zs_cloud_sun", "uSunColor"], ["zs_cloud_sky", "uSkyColor"], ["zs_cloud_direction", "uSunDir"]]:
		var values: Array = cloud_reference.uniforms[pair[1]]
		_check(scene._celestial.state[pair[0]].distance_to(Vector3(values[0], values[1], values[2])) < 0.00001, "Cloud light matches captured source: " + pair[1])
	scene._precipitation.cloud_override = -1.0
	scene._process(0.0)
	var water_count := 0
	for i in range(source.meshes.size()):
		var entry: Dictionary = source.meshes[i]
		if not entry.attrs.has("aDepth"):
			continue
		water_count += 1
		var node: MeshInstance3D = reference.get_child(i)
		var arrays := node.mesh.surface_get_arrays(0)
		var depths: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		_check(depths.size() == arrays[Mesh.ARRAY_VERTEX].size() and not depths.is_empty(), "Every water vertex retains depth data")
		var material := node.mesh.surface_get_material(0) as ShaderMaterial
		_check(material.shader.resource_path.ends_with("reference_water.gdshader"), "Every depth-bearing water mesh uses the water shader")
		_check(material.shader.resource_path.get_file() == ("lake_reference_water.gdshader" if entry.material.water else "reference_water.gdshader"), "Lake excludes received shadows while stream retains them")
		var depth_error := 0.0
		for j in range(depths.size()):
			var swapped: int = (j / 3) * 3 + [0, 2, 1][j % 3]
			var source_index: int = entry.index[swapped] if entry.index != null else swapped
			depth_error = maxf(depth_error, absf(depths[j].x - entry.attrs.aDepth.array[source_index]))
		_check(depth_error < 0.00001, "Water depths survive triangle winding conversion")
		if not entry.material.water:
			_check(material.get_shader_parameter("flowing"), "Stream uses downstream motion")
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			_check(uvs[uvs.size() - 1].x > uvs[0].x + 1.0, "Stream coordinates accumulate course distance")
	_check(water_count == 2, "Lake and stream are both checked")
	scene._process(0.25)
	var before: float = scene._motion_time
	var air_before: Vector2 = scene._atmosphere._travel
	var cloud_before: Vector3 = scene._atmosphere._cloud_drift
	var bird_pose: Transform3D = scene._birds.get_instance_transform(0)
	scene._paused = true
	scene._process(0.5)
	_check(scene._atmosphere._cloud_drift.is_equal_approx(cloud_before), "Pause freezes cloud advection")
	_check(scene._motion_time == before, "Pause freezes the shared motion clock")
	_check(scene._atmosphere._travel.is_equal_approx(air_before), "Pause freezes air travel")
	_check(scene.get_node("WaterfallSpray").particle_count == 37, "Waterfall mist uses the original particle population")
	_check(scene._birds.get_instance_transform(0).is_equal_approx(bird_pose), "Pause freezes bird transforms")
	scene._paused = false
	scene._process(0.25)
	_check(scene._motion_time > before, "Resume advances motion without resetting")
	scene._set_wind(1.2)
	_check(is_equal_approx(scene._atmosphere.strength, 1.2), "Wind control sets the air's target strength")
	scene._atmosphere.send_gust(Vector3.ZERO)
	var gust_before: Vector4 = scene._atmosphere.puffs.parcels[0]
	var travel_before: float = scene._atmosphere._gust_distance
	scene._process(0.25)
	_check(scene._atmosphere.puffs.parcels[0].is_equal_approx(gust_before), "A young gust retains its birth and strength")
	_check(scene._atmosphere._gust_distance > travel_before, "Air travel carries the parcel downwind")
	scene._atmosphere.set_fog(0.0)
	scene._atmosphere.set_haze(0.0)
	_check(not scene._environment.volumetric_fog_enabled, "Fog and haze controls can clear the atmosphere")
	scene._atmosphere.set_fog(0.5)
	if scene._display_fog != null:
		scene._display_fog.update_view()
		_check(scene._display_fog.material.get_shader_parameter("density") == 0.5, "Fog control reaches the display compositor")
	else:
		_check(scene._environment.volumetric_fog_enabled, "Fog control restores native volumetric fog")
	scene._celestial.set_phase(0.02)
	_check(scene._celestial.state["zs_night"] > 0.99 and scene._celestial.daylight < 0.01, "Night gates aurora and darkens the shared lighting")
	scene._celestial.set_phase(0.5)
	_check(scene._celestial.state["zs_night"] < 0.01 and scene._celestial.daylight > 0.99, "Noon restores daylight and hides the night sky")
	scene._celestial.set_phase(0.35)
	scene._celestial.next_hour()
	_check(is_equal_approx(scene._celestial._target, 0.5), "Advance sun selects the nearest forward quarter")
	scene._celestial.next_hour()
	_check(is_equal_approx(scene._celestial._target, 0.75), "Repeated advance progresses to dusk")
	scene._celestial.next_hour()
	_check(is_equal_approx(scene._celestial._target, 0.0), "Advance sun wraps through midnight")
	scene._update_camera()
	var base_camera: Transform3D = scene.camera.transform
	scene._tremor.add(0.7)
	scene._process(0.1)
	_check(not scene.camera.transform.is_equal_approx(base_camera), "Tremor moves the rendered camera")
	scene._process(2.0)
	_check(scene.camera.transform.is_equal_approx(base_camera), "Tremor settles without camera drift")
	scene._precipitation.set_weather(2, true)
	scene._process(0.0)
	_check(scene._precipitation._instances[0].visible_instance_count == 6000, "Storm enables the rain field")
	_check(scene._precipitation._instances[1].visible_instance_count == 0, "Warm rain has no snowfall")
	_check(scene._celestial.cloud > 0.99 and scene._celestial.storm > 0.8, "Weather drives the celestial light rig")
	scene._precipitation.set_weather(3)
	var weather_before: Vector4 = scene._precipitation.state
	scene._paused = true
	scene._process(1.0)
	_check(scene._precipitation.state.is_equal_approx(weather_before), "Pause holds the weather transition")
	scene._paused = false
	scene._process(5.0)
	_check(scene._precipitation._instances[1].visible_instance_count > 2100 and scene._precipitation._instances[1].visible_instance_count < 2400, "Source snow preset settles toward moderate snowfall")
	_check(scene._precipitation._instances[0].visible_instance_count < 20, "Snow transition retires rain")
	scene._precipitation.set_weather(0, true)
	scene._process(0.0)
	_check(scene._precipitation._instances[0].visible_instance_count == 0 and scene._precipitation._instances[1].visible_instance_count == 0, "Clear weather retires precipitation")
	scene._precipitation.surface_weather.air_wet = 0.8
	scene._celestial.set_phase(0.35)
	scene._celestial.rainbow_strength = 0.0
	scene._process(0.0)
	_check(scene._celestial.weather_bow > 0.8 and scene._celestial.state["zs_bow"] > 0.8, "Clearing weather creates a rainbow from lingering drops")
	scene._precipitation.surface_weather.air_wet = 0.0
	scene._process(0.0)
	_check(scene._celestial.weather_bow == 0.0, "Dry air retires the weather rainbow")
	scene._set_quality(1)
	_check(not scene._environment.ssao_enabled and not scene._environment.glow_enabled, "Balanced disables optional post-processing")
	scene._set_quality(0)
	_check(scene._environment.ssao_enabled and scene._environment.glow_enabled, "Beauty restores optional post-processing")
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_MIDDLE
	button.pressed = true
	scene._unhandled_input(button)
	var target: Vector3 = scene.target
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(20, 10)
	scene._input(motion)
	_check(scene.target.is_equal_approx(target), "Pan pools until the frame eases it")
	scene._process(1.0 / 60.0)
	_check(not scene.target.is_equal_approx(target), "Middle drag pans the scene")
	# Per-frame damping must be exercised with actual frame steps, not one
	# synthetic one-second frame (which represents a stall).
	for frame in range(60): scene._process(1.0 / 60.0)
	_check(scene._pan_delta.length() < 1.0, "Pan settles to under 5 % after sixty 60 Hz frames")
	button.pressed = false
	scene._input(button)
	_check(not scene._panning, "Releasing over UI ends pan")
	scene.queue_free()
	await process_frame
	print("PASS: fidelity water, celestial, wind, tremor, and navigation checks" if failures == 0 else "FAIL: %d fidelity checks" % failures)
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
