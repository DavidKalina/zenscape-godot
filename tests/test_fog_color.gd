extends SceneTree
## suite: gpu

# GPU regression: neutral, low-density fog must not become yellow/green.
# --control bypasses the correction to reproduce the renderer's truncation.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(320, 240)
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0
	environment.volumetric_fog_length = 20.0
	environment.volumetric_fog_ambient_inject = 0.0
	var environment_node := WorldEnvironment.new()
	environment_node.environment = environment
	world.add_child(environment_node)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 0, 10)
	camera.current = true
	var volume := FogVolume.new()
	volume.size = Vector3(8, 8, 8)
	var shader := Shader.new()
	var correction := not OS.get_cmdline_user_args().has("--control")
	shader.code = '''shader_type fog;
#include "res://shaders/reference_fog_emission.gdshaderinc"
void fog() {
	float d = 0.015 * (1.0 - smoothstep(-0.1, 0.0, SDF));
	DENSITY = d;
	ALBEDO = vec3(0.0);
	vec3 p = floor(WORLD_POSITION * 19.0);
	float h = fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	EMISSION = %s;
}''' % ("zs_fog_emission(vec3(0.2), d, h)" if correction else "vec3(0.2)")
	var material := ShaderMaterial.new()
	material.shader = shader
	volume.material = material
	world.add_child(volume)
	for i in range(60):
		RenderingServer.force_draw(false)
		await process_frame
	var image := root.get_texture().get_image()
	var sum := Vector3.ZERO
	for y in range(60, 180):
		for x in range(80, 240):
			var c := image.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
	sum /= 19200.0
	var error := (maxf(sum.x, maxf(sum.y, sum.z)) - minf(sum.x, minf(sum.y, sum.z))) / maxf(sum.y, 0.00001)
	var ok := error < 0.05 and sum.y > 0.01
	print("Fog neutral RGB=", sum, " relative color error=", error, " correction=", correction)
	print("PASS: thin fog preserves neutral color" if ok else "FAIL: thin fog color bias")
	world.queue_free()
	await process_frame
	quit(0 if ok else 1)
