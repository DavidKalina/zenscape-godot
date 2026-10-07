extends SceneTree
## suite: gpu
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/lake-wind.json"))["mesh-30"].algae
	var geometry = load("res://assets/zen_reference/geometry.scn").instantiate()
	var lake: ShaderMaterial = geometry.get_node("mesh-30").mesh.surface_get_material(0)
	for key in ["amount", "richness", "seed"]:
		check(absf(lake.get_shader_parameter("lake_algae_" + key) - source[key]) < 0.00001, "Imported algae " + key)
	var anchors: PackedVector3Array = lake.get_shader_parameter("lake_algae_anchors")
	check(anchors.size() == 12, "Twelve source debris anchors imported")
	for i in range(anchors.size()):
		check(anchors[i].distance_to(Vector3(source.anchors[i][0], source.anchors[i][1], source.anchors[i][2])) < 0.00001, "Debris anchor matches source")
	geometry.free()
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
#include "res://shaders/reference_lake_algae.gdshaderinc"
uniform float depth = 0.4;
uniform float cut = 0.0;
void fragment() {
 vec2 p = (UV - 0.5) * 80.0;
 vec3 body = vec3(0.5); float alpha = 0.5;
 zs_lake_algae(body, alpha, vec3(p.x, 0, p.y), p, depth, cut);
 COLOR = vec4(body.r, alpha, 0, 1);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	for key in ["amount", "richness", "seed"]:
		material.set_shader_parameter("lake_algae_" + key, source[key])
	material.set_shader_parameter("lake_algae_anchors", anchors)
	rect.material = material
	viewport.add_child(rect)
	RenderingServer.global_shader_parameter_set("zs_water_growth", 1.0)
	RenderingServer.global_shader_parameter_set("zs_ice", 0.0)
	RenderingServer.global_shader_parameter_set("zs_flow_time", 0.0)
	RenderingServer.global_shader_parameter_set("zs_wind_strength", 0.5)
	material.set_shader_parameter("lake_algae_amount", 0.0)
	var empty := await rendered(viewport)
	material.set_shader_parameter("lake_algae_amount", source.amount)
	var film := await rendered(viewport)
	check(film.get_data() != empty.get_data(), "Source richness produces localized film")
	check((await rendered(viewport)).get_data() == film.get_data(), "Paused film remains stationary")
	RenderingServer.global_shader_parameter_set("zs_flow_time", 30.0)
	check((await rendered(viewport)).get_data() != film.get_data(), "Film drifts with water clock")
	RenderingServer.global_shader_parameter_set("zs_flow_time", 0.0)
	RenderingServer.global_shader_parameter_set("zs_wind_strength", 3.5)
	var windy := await rendered(viewport)
	check(coverage(windy) < coverage(film) * 0.5, "Strong wind thins film")
	RenderingServer.global_shader_parameter_set("zs_ice", 0.85)
	check((await rendered(viewport)).get_data() == empty.get_data(), "Frozen lake rejects film")
	RenderingServer.global_shader_parameter_set("zs_ice", 0.0)
	RenderingServer.global_shader_parameter_set("zs_water_growth", 0.97)
	check((await rendered(viewport)).get_data() == empty.get_data(), "Unfinished lake reveal rejects film")
	RenderingServer.global_shader_parameter_set("zs_water_growth", 1.0)
	material.set_shader_parameter("depth", 0.04)
	check((await rendered(viewport)).get_data() == empty.get_data(), "Dry shoreline rejects film")
	material.set_shader_parameter("depth", 0.4)
	material.set_shader_parameter("cut", 1.0)
	check((await rendered(viewport)).get_data() == empty.get_data(), "Cut walls reject surface film")
	viewport.queue_free()
	await process_frame
	print("PASS: algae source import, film, drift, pause, wind thinning, freeze, growth, shore and cut gates" if failures == 0 else "FAIL: lake algae")
	quit(1 if failures else 0)
func coverage(img: Image) -> float:
	var total := 0.0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			total += maxf(img.get_pixel(x, y).g - 128.0 / 255.0, 0.0)
	return total
func rendered(viewport: SubViewport) -> Image:
	for i in range(3):
		RenderingServer.force_draw(false)
		await process_frame
	return viewport.get_texture().get_image()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
