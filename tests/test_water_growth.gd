extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/water-growth.json"))
	var lake: MeshInstance3D = scene.get_node("Reference/" + data.lakes[0].name)
	scene._growth.set_water(0.2)
	check(not lake.visible, "An empty lake has no floating surface")
	scene._growth.set_water(0.525)
	check(absf(lake.position.y - (data.lakes[0].bed + data.lakes[0].level) * 0.5) < 0.00001, "Lake fills from original bed with source smoothstep")
	var material := lake.mesh.surface_get_material(0) as ShaderMaterial
	check(absf(float(material.get_shader_parameter("level_drop")) - (data.lakes[0].level - lake.position.y)) < 0.00001, "Depth follows the lowered water surface")
	scene._growth.set_water(1.0)
	check(lake.visible and absf(lake.position.y - data.lakes[0].level) < 0.00001, "Full water restores original level")
	scene._growth.set_foliage(0.3)
	scene._growth.replay_water()
	for i in range(240):
		scene._growth.advance(1.0 / 30.0, false, scene._tremor)
	check(scene._growth.water == 1.0 and scene._growth.foliage == 0.3 and not scene._growth.replaying, "Water-only replay preserves foliage")
	scene._growth.set_terrain(0.4)
	scene._growth.replay_water()
	for i in range(360):
		scene._growth.advance(1.0 / 30.0, false, scene._tremor)
	check(scene._growth.terrain == 1.0 and scene._growth.water == 1.0 and scene._growth.foliage == 0.3, "Refill over partial land preserves foliage while restoring support")
	scene._growth.set_foliage(1.0)
	var stream: MeshInstance3D = scene.get_node("Reference/" + data.streams[0].name)
	var stream_arrays := stream.mesh.surface_get_arrays(0)
	var centers: PackedFloat32Array = stream_arrays[Mesh.ARRAY_CUSTOM0]
	var stream_error := 0.0
	for i in range(centers.size() / 4):
		var index: int = (i / 3) * 3 + [0, 2, 1][i % 3]
		for axis in range(3):
			stream_error = maxf(stream_error, absf(centers[i * 4 + axis] - data.streams[0].aCenter.array[index * 3 + axis]))
		stream_error = maxf(stream_error, absf(centers[i * 4 + 3] - data.streams[0].aT.array[index]))
	check(stream_error < 0.00001, "Stream centerline and arrival coordinates survive import")
	var stream_image: Image = scene._precipitation.stream_texture.get_image()
	var late_samples := 0
	for z in range(stream_image.get_height()):
		for x in range(stream_image.get_width()):
			var sample := stream_image.get_pixel(x, z)
			if sample.a > 0.5 and sample.r > 0.5:
				late_samples += 1
				check(sample.g >= 0.0 and sample.g <= 1.0001, "Stream map retains normalized width")
	check(late_samples > 0, "Weather map retains late-arriving stream sections")
	var fall: MeshInstance3D = scene.get_node("Reference/strand")
	var arrays := fall.mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var m := fall.mesh.surface_get_material(0) as ShaderMaterial
	var ct: PackedVector4Array = m.get_shader_parameter("centers_tau")
	var aw: PackedVector4Array = m.get_shader_parameter("axis_a_width")
	var bt: PackedVector4Array = m.get_shader_parameter("axis_b_thick")
	var shape: PackedVector2Array = m.get_shader_parameter("aer_steep")
	var count: int = m.get_shader_parameter("ring_count")
	var seed: float = m.get_shader_parameter("fall_seed")
	var front_tau := 0.47 * ct[count - 1].w
	var fi := 0
	while fi < count - 2 and ct[fi + 1].w <= front_tau:
		fi += 1
	var fraction := clampf((front_tau - ct[fi].w) / (ct[fi + 1].w - ct[fi].w), 0.0, 1.0)
	var nose := xyz(ct[fi]).lerp(xyz(ct[fi + 1]), fraction)
	var max_error := 0.0
	for i in range(uv.size()):
		var r := int(uv[i].x)
		var a := uv[i].y
		var tau := ct[r].w
		var p: Vector3
		if tau > front_tau:
			p = nose + xyz(aw[fi]) * cos(a) * aw[fi].w * 0.3 + xyz(bt[fi]) * sin(a) * bt[fi].w * 0.4
		else:
			var swell := 1.0 + sin(tau * 5.0 - 1.25 * 2.4 + a * 2.0 + seed) * (0.02 + shape[r].y * 0.06) + sin(tau * 9.0 - 1.25 * 3.6 + a * 3.0 + seed) * (0.01 + shape[r].y * 0.04)
			var chop := 1.0 + shape[r].x * (sin(tau * 19.0 - 1.25 * 7.5 + a * 4.0 + seed * 3.0) * 0.11 + sin(tau * 13.0 - 1.25 * 5.1 + a * 7.0 + seed) * 0.08 - 0.11)
			p = xyz(ct[r]) + xyz(aw[r]) * cos(a) * aw[r].w * swell * chop + xyz(bt[r]) * sin(a) * bt[r].w * swell * chop
		var index: int = (i / 3) * 3 + [0, 2, 1][i % 3]
		var expected := Vector3(data.checks[0][index * 3], data.checks[0][index * 3 + 1], data.checks[0][index * 3 + 2])
		max_error = maxf(max_error, p.distance_to(expected))
	check(max_error < 0.00001, "Imported strand parameters reproduce all source vertices at time 1.25/front .47")
	print("Water growth checks: ", failures, " failures; source vertex error ", max_error)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
func xyz(v: Vector4) -> Vector3:
	return Vector3(v.x, v.y, v.z)
