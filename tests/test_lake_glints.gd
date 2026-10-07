extends SceneTree
## suite: gpu
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
#include "res://shaders/reference_lake_glint.gdshaderinc"
uniform float facing = 1.0;
uniform float clear = 1.0;
uniform float ice = 0.0;
uniform bool night = false;
void fragment() {
 vec3 ray = vec3(sqrt(1.0 - facing * facing), facing, 0);
 vec4 path = zs_lake_glint(ray, vec3(0, night ? -1.0 : 1.0, 0), vec3(0,1,0), clear, ice, 1.0);
 COLOR = vec4(path.a, path.r, path.g, 1);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	viewport.add_child(rect)
	material.set_shader_parameter("facing", 1.0)
	var noon := await rendered(viewport)
	check(absf(noon.get_pixel(128,128).r - 0.68) < 0.005, "Aligned sun uses source narrow plus broad weight")
	material.set_shader_parameter("clear", 0.5)
	check(absf((await rendered(viewport)).get_pixel(128,128).r - 0.17) < 0.005, "Cloud cover attenuates glints quadratically")
	material.set_shader_parameter("clear", 0.0)
	check((await rendered(viewport)).get_pixel(128,128).r == 0.0, "Overcast hides celestial paths")
	material.set_shader_parameter("clear", 1.0)
	material.set_shader_parameter("night", true)
	var moon := (await rendered(viewport)).get_pixel(128,128)
	check(absf(moon.r - 0.68 * 0.32) < 0.005, "Moon path has source reduced intensity")
	check(absf(moon.g - 0.38) < 0.005 and absf(moon.b - 0.57) < 0.005, "Moon reflection uses cool source color")
	material.set_shader_parameter("facing", 0.9)
	var broad := (await rendered(viewport)).get_pixel(128,128)
	check(broad.r > 0.0 and broad.r < moon.r, "Broad path survives beyond narrow glint")
	material.set_shader_parameter("ice", 0.99)
	check((await rendered(viewport)).get_pixel(128,128).r == 0.0, "Frozen surface suppresses open-water paths")
	viewport.queue_free()
	await process_frame
	print("PASS: lake sun/moon path intensity, color, cloud response, broad lobe and freeze cutoff" if failures == 0 else "FAIL: lake glints")
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
