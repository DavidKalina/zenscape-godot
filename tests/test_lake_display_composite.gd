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
render_mode unshaded;
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_tonemap.gdshaderinc"
uniform vec3 lit = vec3(0.1, 0.2, 0.3);
uniform vec3 sky = vec3(0.15, 0.3, 0.5);
uniform vec4 path = vec4(1.0, 0.9, 0.7, 0.0);
uniform float reflection = 0.0;
uniform int mode = 0;
void fragment() {
 vec3 color = lit;
 if (mode == 1) color = zs_lake_display_composite(lit, sky, reflection, path);
 if (mode == 2) color = mix(mix(lit, scene_linear_for_display(sky), reflection), scene_linear_for_display(path.rgb), path.a);
 if (mode == 3) color = zs_lake_ice_composite(lit, sky, reflection, vec3(0.3,0.45,0.6), 0.4, path);
 ALBEDO = color;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	plane.material_override = material
	for lit in [Vector3(0.03, 0.06, 0.12), Vector3(0.2, 0.3, 0.4), Vector3(2.0, 1.0, 0.3)]:
		material.set_shader_parameter("lit", lit)
		material.set_shader_parameter("mode", 0)
		var baseline := await pixel()
		for weight in [0.02, 0.3, 0.68]:
			var sky := Vector3(0.15, 0.3, 0.5)
			var target := Vector3(1.0, 0.9, 0.7)
			material.set_shader_parameter("sky", sky)
			material.set_shader_parameter("reflection", 0.12)
			material.set_shader_parameter("path", Vector4(target.x, target.y, target.z, weight))
			material.set_shader_parameter("mode", 1)
			var actual := await pixel()
			var expected := baseline.lerp(sky, 0.12).lerp(target, weight)
			check(actual.distance_to(expected) < 0.015, "Native final pixel matches display mix: " + str(actual) + " expected " + str(expected))
			material.set_shader_parameter("mode", 3)
			var icy := await pixel()
			var icy_expected := baseline.lerp(sky,0.12).lerp(Vector3(0.3,0.45,0.6),0.4).lerp(target,weight)
			check(icy.distance_to(icy_expected) < 0.015,"Ice reflection follows water reflection and precedes glints")
			if weight == 0.3:
				material.set_shader_parameter("mode", 2)
				var wrong := await pixel()
				check(wrong.distance_to(expected) > 0.025, "Probe rejects the earlier HDR blend")
	world.queue_free()
	await process_frame
	print("PASS: native ACES display composite across dark, midtone and bright water with HDR control rejection" if failures == 0 else "FAIL: lake display composite")
	quit(1 if failures else 0)
func pixel() -> Vector3:
	for i in range(4):
		RenderingServer.force_draw(false)
		await process_frame
	var image := root.get_texture().get_image()
	var c := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
	return Vector3(c.r,c.g,c.b)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
