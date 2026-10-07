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
uniform vec4 flash;
varying vec3 world_position;
varying float inversion_transmit;
void fragment() {
 world_position = vec3(0);
 inversion_transmit = 1.0;
 ALBEDO = vec3(0.13, 0.25, 0.3);
 ROUGHNESS = rough;
 SPECULAR = 0.7;
 if (lake_display_lighting) {
  EMISSION = zs_lake_flash(ALBEDO, NORMAL, VIEW, vec3(0), rough, flash);
  SPECULAR = 0.0;
 }
}
#define ZS_COMPLETE_LAKE_LIGHTING
#include "res://shaders/reference_direct_light.gdshaderinc"
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	plane.material_override = material
	var light := OmniLight3D.new()
	world.add_child(light)
	light.light_color = Color("d8e8ff")
	light.omni_range = 160.0
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	RenderingServer.global_shader_parameter_set("zs_alpen", Vector3.ZERO)
	material.set_shader_parameter("rough", 0.86)
	for distance in [8.0, 30.0, 80.0, 160.0]:
		for flash in [0.0, 0.3, 1.0]:
			light.position = Vector3(0,0,distance)
			light.light_energy = 900.0 * flash / PI
			material.set_shader_parameter("flash", Vector4(0,0,distance,flash))
			material.set_shader_parameter("lake_display_lighting", false)
			var native := await pixel()
			material.set_shader_parameter("lake_display_lighting", true)
			var complete := await pixel()
			check(native.distance_to(complete) < 0.015, "Source flash matches point light at distance " + str(distance) + " intensity " + str(flash) + ": " + str(native) + " vs " + str(complete))
	world.queue_free()
	await process_frame
	print("PASS: source lake flash agrees with native point-light output across distance, pulse amplitude and cutoff" if failures == 0 else "FAIL: lake flash")
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
