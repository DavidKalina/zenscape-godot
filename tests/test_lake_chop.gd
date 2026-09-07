extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(256, 256)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_lake_chop.gdshaderinc"
uniform float fetch = 0.0;
void fragment() {
    vec3 p = vec3(UV.x * 32.0 - 16.0, 0, UV.y * 32.0 - 16.0);
    vec3 state;
    float height = zs_lake_chop(p, p, 0.8, vec4(fetch), vec4(fetch), state);
    vec3 foam = vec3(0); float alpha = 0.0;
    zs_lake_foam(foam, alpha, p, 0.8, state);
    COLOR = vec4(0.5 + height, foam.r, state.x, 1);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	viewport.add_child(rect)
	RenderingServer.global_shader_parameter_set("zs_wind_strength", 2.5)
	RenderingServer.global_shader_parameter_set("zs_ice", 0.0)
	RenderingServer.global_shader_parameter_set("zs_flow_time", 1.0)
	var shore: Image = await rendered(viewport)
	check(activity(shore) == 0, "Zero fetch produces no chop or foam")
	material.set_shader_parameter("fetch", 9.0)
	var open: Image = await rendered(viewport)
	check(activity(open) > 1000, "Full fetch produces wind-driven chop")
	var caps := 0
	for y in range(256):
		for x in range(256):
			if open.get_pixel(x, y).g > 0.005: caps += 1
	check(caps > 10, "Hard air produces localized crest foam")
	RenderingServer.global_shader_parameter_set("zs_flow_time", 1.4)
	var moved: Image = await rendered(viewport)
	check(moved.get_data() != open.get_data(), "Waves and crest foam move with the water clock")
	RenderingServer.global_shader_parameter_set("zs_ice", 1.0)
	var frozen: Image = await rendered(viewport)
	check(activity(frozen) == 0, "Frozen water rejects wind chop and whitecaps")
	RenderingServer.global_shader_parameter_set("zs_ice", 0.0)
	RenderingServer.global_shader_parameter_set("zs_wind_strength", 0.0)
	var calm: Image = await rendered(viewport)
	check(activity(calm) == 0, "Calm air creates no wind chop or whitecaps")
	viewport.queue_free()
	await process_frame
	print("PASS: fetch-limited chop, crest foam, motion, calm and freeze gates" if failures == 0 else "FAIL: lake chop")
	quit(1 if failures else 0)
func activity(frame: Image) -> int:
	var count := 0
	for y in range(256):
		for x in range(256):
			var c := frame.get_pixel(x, y)
			if absf(c.r - 0.5) > 0.005 or c.g > 0.005: count += 1
	return count
func rendered(viewport: SubViewport) -> Image:
	for i in range(3):
		RenderingServer.force_draw(false)
		await process_frame
	return viewport.get_texture().get_image()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
