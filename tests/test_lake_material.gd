extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/lake-wind.json"))["mesh-30"]
	var geometry = load("res://assets/zen_reference/geometry.scn").instantiate()
	root.add_child(geometry)
	var lake: ShaderMaterial = geometry.get_node("mesh-30").mesh.surface_get_material(0)
	var look: Vector2 = lake.get_shader_parameter("lake_look")
	var volume: Vector4 = lake.get_shader_parameter("lake_volume")
	check(look.distance_to(Vector2(source.look[0], source.look[1])) < 0.00001, "Imported opacity and roughness match live source")
	check(volume.distance_to(Vector4(source.volume[0], source.volume[1], source.volume[2], source.volume[3])) < 0.00001, "Imported volume matches live GL uniforms")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8, 8)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(8, 8)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/reference_lake_material.gdshaderinc"
uniform float depth = 0.0;
uniform float ice = 0.0;
uniform float facing = 1.0;
uniform vec3 detail = vec3(0.0);
void fragment() { COLOR = vec4(zs_lake_opacity(depth, ice), zs_lake_roughness(ice, detail), zs_lake_reflection(facing), 1); }
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("lake_look", look)
	material.set_shader_parameter("lake_volume", volume)
	rect.material = material
	viewport.add_child(rect)
	var shore := await pixel(viewport)
	check(absf(shore.r - look.x * volume.w) < 0.005, "Shallow water retains the source transmission floor")
	check(absf(shore.g - look.y) < 0.005, "Open water keeps its authored roughness")
	check(absf(shore.b - volume.z * 0.02) < 0.005, "Normal incidence has source Fresnel F0")
	material.set_shader_parameter("depth", volume.x)
	var absorption := await pixel(viewport)
	check(absf(absorption.r - look.x * lerpf(volume.w, 1.0, 1.0 - exp(-1.0))) < 0.005, "One absorption distance applies Beer attenuation")
	material.set_shader_parameter("facing", 0.0)
	material.set_shader_parameter("ice", 1.0)
	material.set_shader_parameter("detail", Vector3(1, 1, 0))
	var clear_ice := await pixel(viewport)
	check(clear_ice.r > 0.995 and absf(clear_ice.g - 0.22) < 0.005, "Clear ice closes transparency and becomes glossy")
	check(absf(clear_ice.b - volume.z) < 0.005, "Grazing reflection reaches the source sky gain")
	material.set_shader_parameter("detail", Vector3.ONE)
	var snow := await pixel(viewport)
	check(absf(snow.g - 0.94) < 0.005, "Snow roughens the ice surface")
	geometry.queue_free()
	viewport.queue_free()
	await process_frame
	print("PASS: source lake material import, absorption, Fresnel, open water and ice roughness" if failures == 0 else "FAIL: lake material")
	quit(1 if failures else 0)
func pixel(viewport: SubViewport) -> Color:
	for i in range(3):
		RenderingServer.force_draw(false)
		await process_frame
	return viewport.get_texture().get_image().get_pixel(4, 4)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
