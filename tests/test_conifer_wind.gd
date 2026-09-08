extends SceneTree
## GPU checks of the deformation shared by editable pine trunks and crowns.
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
#include "res://shaders/conifer_wind.gdshaderinc"
uniform float height = 4.3;
uniform bool rotated = false;
void fragment() {
 mat4 model = mat4(1.0);
 if (rotated) model = mat4(vec4(0,0,-1.4,0),vec4(0,1,0,0),vec4(1.4,0,0,0),vec4(0,0,0,1));
 vec3 offset = mat3(model) * zs_conifer_offset(vec3(0,height,0), model);
 COLOR = vec4(vec3(0.5) + offset, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	viewport.add_child(rect)
	RenderingServer.global_shader_parameter_set("zs_wind_direction", Vector2.RIGHT)
	RenderingServer.global_shader_parameter_set("zs_wind_strength", 1.3)
	RenderingServer.global_shader_parameter_set("zs_motion_time", 1.0)
	RenderingServer.global_shader_parameter_set("zs_gust_speed", 4.0)
	RenderingServer.global_shader_parameter_set("zs_gust_distance", 10.0)
	RenderingServer.global_shader_parameter_set("zs_puff_0", Vector4(-5,0,0,0.6))
	var crown := (await rendered(viewport)).get_pixel(48,48)
	check(crown.r > 0.58, "Crown bends downwind")
	material.set_shader_parameter("rotated", true)
	var turned := (await rendered(viewport)).get_pixel(48,48)
	check(crown.is_equal_approx(turned), "Rotated and scaled pine preserves world direction")
	material.set_shader_parameter("height", 0.0)
	var base := (await rendered(viewport)).get_pixel(48,48)
	check(absf(base.r-0.5)<0.005 and absf(base.g-0.5)<0.005, "Roots remain pinned")
	material.set_shader_parameter("height", 1.0)
	var trunk := (await rendered(viewport)).get_pixel(48,48)
	check(absf(trunk.r-0.5)<0.02, "Lower trunk remains nearly still")
	material.set_shader_parameter("height", 4.3)
	check((await rendered(viewport)).get_pixel(48,48) == turned, "Frozen wind clocks preserve crown pose")
	RenderingServer.global_shader_parameter_set("zs_wind_strength", 0.0)
	var calm := (await rendered(viewport)).get_pixel(48,48)
	check(absf(calm.r-0.5)<0.005, "Calm wind leaves crown at rest")
	viewport.queue_free()
	wind.queue_free()
	await process_frame
	print("PASS conifer roots, crown, world direction, calm and frozen clocks" if failures == 0 else "FAIL conifer wind")
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
