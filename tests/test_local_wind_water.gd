extends SceneTree
## GPU contract of the actual helpers used by both water materials and spray.
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var wind = preload("res://scripts/local_wind_field.gd").new()
	root.add_child(wind)
	wind.clear()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(96, 96)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_water_gust.gdshaderinc"
uniform int mode = 0;
uniform float depth = 1.0;
void fragment() {
 vec3 p = vec3((UV.x-0.5)*16.0, 0.0, (UV.y-0.5)*16.0);
 vec3 value = vec3(zs_water_gust_height(p, depth));
 if (mode == 1) value = zs_water_gust_normal(vec3(0,1,0), p, depth) - vec3(0,1,0);
 if (mode == 2) value = zs_spray_gust_offset(p, 0.7);
 if (mode == 3) value = zs_fall_gust_offset(p, 0.5, 1.0);
 if (mode == 4) value = zs_fall_gust_offset(p, 1.0, 1.0);
 COLOR = vec4(vec3(0.5) + value * 0.2, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	viewport.add_child(rect)
	RenderingServer.global_shader_parameter_set("zs_ice", 0.0)
	RenderingServer.global_shader_parameter_set("zs_flow_time", 0.4)
	var baseline := await rendered(viewport)
	wind.emit_gust(Vector3.ZERO, Vector3.RIGHT, 20.0, 5.0, 2.0)
	wind.advance(0.4)
	var waves := await rendered(viewport)
	check(waves.get_data() != baseline.get_data(), "Gust excites water heights")
	check(waves.get_pixel(1, 1) == baseline.get_pixel(1, 1), "Outside gust remains identical")
	material.set_shader_parameter("depth", 0.0)
	check((await rendered(viewport)).get_data() == baseline.get_data(), "Shoreline pinned")
	material.set_shader_parameter("depth", 1.0)
	material.set_shader_parameter("mode", 1)
	check((await rendered(viewport)).get_data() != baseline.get_data(), "Gust creates fine surface ripples")
	for mode in [2, 3]:
		material.set_shader_parameter("mode", mode)
		var positive := (await rendered(viewport)).get_pixel(48, 48)
		check(positive.r > 0.505 and absf(positive.b - 0.5) < 0.005, "Spray/fall drift follows +X")
		wind.clear()
		wind.emit_gust(Vector3.ZERO, Vector3.LEFT, 20.0, 5.0, 2.0)
		wind.advance(0.4)
		var negative := (await rendered(viewport)).get_pixel(48, 48)
		check(negative.r < 0.495, "Spray/fall drift reverses with gust")
		wind.clear()
		wind.emit_gust(Vector3.ZERO, Vector3.RIGHT, 20.0, 5.0, 2.0)
		wind.advance(0.4)
	material.set_shader_parameter("mode", 4)
	check((await rendered(viewport)).get_data() == baseline.get_data(), "Waterfall impact remains anchored")
	RenderingServer.global_shader_parameter_set("zs_ice", 1.0)
	for mode in [0, 1, 2, 3]:
		material.set_shader_parameter("mode", mode)
		check((await rendered(viewport)).get_data() == baseline.get_data(), "Ice rejects gust response mode %d" % mode)
	RenderingServer.global_shader_parameter_set("zs_ice", 0.0)
	wind.advance(2.0)
	for mode in [0, 1, 2, 3]:
		material.set_shader_parameter("mode", mode)
		check((await rendered(viewport)).get_data() == baseline.get_data(), "Expired gust restores exact baseline mode %d" % mode)
	# Atmospheric parcels must reach the same helpers even without a local field.
	RenderingServer.global_shader_parameter_set("zs_wind_direction", Vector2.RIGHT)
	RenderingServer.global_shader_parameter_set("zs_puff_0", Vector4(-5,0,0,0.6))
	RenderingServer.global_shader_parameter_set("zs_gust_distance", 5.0)
	material.set_shader_parameter("mode", 2)
	var parcel := (await rendered(viewport)).get_pixel(48,48)
	check(parcel.r > 0.55 and absf(parcel.b-0.5)<0.005, "Atmospheric parcel carries spray downwind without local gusts")
	RenderingServer.global_shader_parameter_set("zs_gust_distance", 60.0)
	check((await rendered(viewport)).get_data() == baseline.get_data(), "Passed atmospheric parcel restores calm water")
	RenderingServer.global_shader_parameter_set("zs_puff_0", Vector4.ZERO)
	viewport.queue_free()
	wind.queue_free()
	await process_frame
	print("PASS local wind water GPU contracts" if failures == 0 else "FAIL local wind water")
	quit(1 if failures else 0)
func rendered(viewport: SubViewport) -> Image:
	for i in range(3):
		RenderingServer.force_draw(false)
		await process_frame
	return viewport.get_texture().get_image()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
