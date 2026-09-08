extends SceneTree
var failures := 0
const Wind = preload("res://scripts/local_wind_field.gd")
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var wind = Wind.new()
	root.add_child(wind)
	check(wind.emit_gust(Vector3.ZERO, Vector3.ZERO, 10, 5, 2) == -1, "Reject undefined direction")
	check(wind.emit_gust(Vector3.ZERO, Vector3.RIGHT, NAN, 5, 2) == -1, "Reject nonfinite gust")
	check(wind.emit_gust(Vector3.ZERO, Vector3.RIGHT, 10, -1, 2) == -1, "Reject invalid radius")
	check(wind.emit_gust(Vector3.ZERO, Vector3.RIGHT, 10, 5, 0) == -1, "Reject invalid lifetime")
	wind.emit_gust(Vector3.ZERO, Vector3.RIGHT * 3, 20, 8, 2)
	check(wind.sample_local(Vector3.ZERO) == Vector3.ZERO, "Attack starts smoothly at zero")
	wind.advance(0.4)
	check(wind.sample_local(Vector3.ZERO).is_equal_approx(Vector3.RIGHT * 20), "Peak velocity normalizes input direction")
	check(wind.sample_local(Vector3(4,0,0)).is_equal_approx(Vector3.RIGHT * 10), "Half radius has half strength")
	check(wind.sample_local(Vector3(0,4,0)).is_equal_approx(Vector3.RIGHT * 10), "Falloff is three dimensional")
	check(wind.sample_local(Vector3(8,0,0)) == Vector3.ZERO, "No force outside radius")
	wind.ambient_velocity = Vector3(1, 0, 2)
	check(wind.sample(Vector3.ZERO).is_equal_approx(Vector3(21,0,2)), "Ambient and gust combine")
	wind.emit_gust(Vector3.ZERO, Vector3.LEFT, 20, 8, 2)
	wind.advance(0.3)
	check(wind.sample_local(Vector3.ZERO).length() < 0.001, "Opposing overlapping gusts cancel")
	# Read back the GPU field at distinct 3D points; this catches uniform packing,
	# shader direction/falloff mistakes and CPU/render clock disagreement.
	wind.clear()
	wind.emit_gust(Vector3(1,2,3), Vector3(2,1,-3), 20, 8, 2)
	wind.advance(0.4)
	if DisplayServer.get_name() != "headless":
		var viewport := SubViewport.new()
		viewport.size = Vector2i(4,4)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var rect := ColorRect.new()
		rect.size = Vector2(4,4)
		var shader := Shader.new()
		shader.code = 'shader_type canvas_item;\n#include "res://shaders/reference_wind.gdshaderinc"\nuniform vec3 sample_position;\nvoid fragment() { COLOR = vec4(zs_local_wind(sample_position) / 64.0 + vec3(0.5), 1.0); }'
		var material := ShaderMaterial.new()
		material.shader = shader
		rect.material = material
		viewport.add_child(rect)
		for position: Vector3 in [Vector3(1,2,3), Vector3(5,2,3), Vector3(1,6,3), Vector3(10,2,3)]:
			material.set_shader_parameter("sample_position", position)
			await process_frame
			await RenderingServer.frame_post_draw
			var pixel: Color = viewport.get_texture().get_image().get_pixel(2,2)
			var actual := (Vector3(pixel.r,pixel.g,pixel.b) - Vector3.ONE * 0.5) * 64.0
			check(actual.distance_to(wind.sample_local(position)) < 0.45, "GPU/CPU velocity agrees at %s: %s vs %s" % [position,actual,wind.sample_local(position)])
		viewport.queue_free()
	wind.advance(2)
	check(wind.sample_local(Vector3(1,2,3)) == Vector3.ZERO, "Expired gust retires completely")
	wind.clear()
	for i in range(9):
		wind.emit_gust(Vector3(i * 20,0,0), Vector3.RIGHT, 10, 1, 2)
	wind.advance(0.4)
	check(wind.sample_local(Vector3.ZERO) == Vector3.ZERO and wind.sample_local(Vector3(160,0,0)).length() > 9, "Capacity evicts oldest, retains newest")
	wind.clear()
	check(wind.sample_local(Vector3(160,0,0)) == Vector3.ZERO, "Clear immediately clears field")
	wind.queue_free()
	await process_frame
	print("PASS: local wind validation, falloff, overlap, lifetime and CPU/GPU parity" if failures == 0 else "FAIL: local wind")
	quit(1 if failures else 0)
