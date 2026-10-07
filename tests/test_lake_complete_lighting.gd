extends SceneTree
## suite: gpu
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(128, 128)
	root.content_scale_size = Vector2i(128, 128)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position.z = 2
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment.tonemap_white = 16.0
	env.environment.tonemap_exposure = 1.0
	world.add_child(env)
	RenderingServer.global_shader_parameter_set("zs_exposure", 1.0)
	var plane := MeshInstance3D.new()
	plane.mesh = QuadMesh.new()
	world.add_child(plane)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_alpenglow.gdshaderinc"
#include "res://shaders/reference_lake_lighting.gdshaderinc"
uniform bool lake_display_lighting = false;
uniform bool flowing = false;
uniform float metalness_value = 0.0;
uniform float rough = 0.5;
uniform vec3 direction;
uniform vec3 irradiance;
varying vec3 world_position;
varying float inversion_transmit;
void fragment() {
 world_position = vec3(0);
 inversion_transmit = 1.0;
 ALBEDO = vec3(0.13, 0.25, 0.3);
 ROUGHNESS = rough;
 SPECULAR = 0.7;
 if (lake_display_lighting) {
  EMISSION = zs_lake_direct(ALBEDO, NORMAL, VIEW, direction, irradiance, rough);
  SPECULAR = 0.0;
 }
}
#define ZS_COMPLETE_LAKE_LIGHTING
#include "res://shaders/reference_direct_light.gdshaderinc"
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	plane.material_override = material
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation = Vector3(0.3, 0.4, 0)
	light.light_color = Color(0.8,0.7,0.6)
	light.light_energy = 1.3 / PI
	light.shadow_enabled = false
	var color := light.light_color.srgb_to_linear()
	material.set_shader_parameter("direction", light.global_basis.z.normalized())
	material.set_shader_parameter("irradiance", Vector3(color.r,color.g,color.b) * light.light_energy * PI)
	RenderingServer.global_shader_parameter_set("zs_alpen", Vector3.ZERO)
	for rough in [0.22, 0.5, 0.86]:
		material.set_shader_parameter("rough", rough)
		material.set_shader_parameter("lake_display_lighting", false)
		var native := await pixel()
		material.set_shader_parameter("lake_display_lighting", true)
		var complete := await pixel()
		check(native.distance_to(complete) < 0.015, "Complete lake directional light matches native Lambert/GGX at roughness " + str(rough) + ": " + str(native) + " vs " + str(complete))
	world.queue_free()
	await process_frame
	print("PASS: complete lake directional light agrees with native Lambert/GGX across open-water and ice roughness" if failures == 0 else "FAIL: lake complete lighting")
	quit(1 if failures else 0)
func pixel() -> Vector3:
	for i in range(4):
		RenderingServer.force_draw(false)
		await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		check(false, "The rendered frame reads back")
		return Vector3.ZERO
	var c := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
	return Vector3(c.r,c.g,c.b)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
