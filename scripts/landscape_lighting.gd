class_name LandscapeLighting
extends Node3D
## The same sky, tone mapping, ambient occlusion and lights in both landscapes.
var environment: Environment
var lights: Array[DirectionalLight3D] = []

func setup(source: Dictionary) -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_sky.gdshader")
	RenderingServer.global_shader_parameter_set("zs_exposure", float(source.exposure) / 1.08)
	sky.sky_material = material
	environment.sky = sky
	# Hemisphere bounce comes from the imported material's source lighting.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = float(source.exposure) / 1.08
	environment.tonemap_white = 16.0
	environment.ssao_enabled = true
	environment.ssao_radius = 0.65
	environment.ssao_intensity = 0.7
	environment.ssao_light_affect = 0.12
	environment.glow_enabled = true
	environment.glow_intensity = 0.12
	environment.glow_hdr_threshold = 1.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	for entry: Dictionary in source.lights:
		if entry.type != "DirectionalLight":
			continue
		var light := DirectionalLight3D.new()
		lights.append(light)
		add_child(light)
		light.position = Vector3(entry.position[0], entry.position[1], entry.position[2])
		light.look_at(Vector3(entry.target[0], entry.target[1], entry.target[2]))
		light.light_color = Color(entry.color[0], entry.color[1], entry.color[2]).linear_to_srgb()
		# Godot's light energy convention includes PI; the source irradiance does not.
		light.light_energy = float(entry.intensity) / PI
		light.shadow_enabled = entry.castShadow
		# Source: one 4096 map fitted to the whole island (~35 texels/m), tight
		# 3x3 PCF and a slightly negative bias. One orthogonal map over the
		# diorama keeps far foliage self-shadowed and trunk bases grounded.
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		light.directional_shadow_max_distance = 130.0
		light.directional_shadow_fade_start = 1.0
		light.shadow_bias = 0.08
		light.shadow_normal_bias = 0.8
		# A tight but adequately sampled edge: 0.2 exposed shadow-map steps;
		# 0.5 with medium PCF smooths the silhouette without a broad penumbra.
		light.shadow_blur = 0.5
		# Three.js has no environment map: direct GGX only, no split-sum glaze.
		light.light_specular = 1.0
		# Source PCFSoftShadowMap filters edges without a distance-growing penumbra.
		light.light_angular_distance = 0.6 if "--legacy-soft-shadows" in OS.get_cmdline_user_args() else 0.0

