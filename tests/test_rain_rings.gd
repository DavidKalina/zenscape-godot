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
#include "res://shaders/reference_rain_rings.gdshaderinc"
uniform float clock = 1.0;
uniform float wet = 0.0;
uniform float ice = 0.0;
void fragment() {
    vec3 n = zs_rain_ring_normal(vec3(0, 1, 0), vec3(UV.x * 3.0, 0, UV.y * 3.0), clock, wet, ice);
    COLOR = vec4(n * 0.5 + 0.5, 1);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	viewport.add_child(rect)
	var dry: Image = await rendered(viewport)
	material.set_shader_parameter("wet", 1.0)
	var rain: Image = await rendered(viewport)
	var changed := 0
	for y in range(256):
		for x in range(256):
			if rain.get_pixel(x, y).r != dry.get_pixel(x, y).r:
				changed += 1
	check(changed > 10000, "Rain produces a distributed ring normal field")
	var held: Image = await rendered(viewport)
	check(held.get_data() == rain.get_data(), "Held clock preserves the ring field exactly")
	material.set_shader_parameter("clock", 1.4)
	var moved: Image = await rendered(viewport)
	check(moved.get_data() != rain.get_data(), "Rain rings propagate with the water clock")
	material.set_shader_parameter("ice", 0.5)
	var frozen: Image = await rendered(viewport)
	check(frozen.get_data() == dry.get_data(), "Source half-freeze threshold rejects raindrop tilt")
	material.set_shader_parameter("ice", 0.49)
	material.set_shader_parameter("wet", 0.01)
	var threshold: Image = await rendered(viewport)
	check(threshold.get_data() == dry.get_data(), "Source liquid-rain threshold leaves dry water untouched")
	viewport.queue_free()
	await process_frame
	print("PASS: rain-ring normal field, held clock, propagation, rain threshold and freeze cutoff" if failures == 0 else "FAIL: rain rings")
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
