class_name GardenLook
extends Node3D
## Editable scenery shares the port's actual lighting rig and material state.
var lighting: LandscapeLighting
var celestial := preload("res://studies/celestial.gd").new()
var air := preload("res://studies/atmosphere.gd").new()
var display_fog := preload("res://studies/display_fog.gd").new()
var surface_map := GardenSurfaceMap.new()
var terrain: TerrainView
var camera: Camera3D
var _time := 0.0
var _wind := 0.4

func setup(view: Camera3D, ground: TerrainView) -> void:
	camera = view
	terrain = ground
	lighting = LandscapeLighting.new()
	add_child(lighting)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	lighting.setup(source)
	celestial.setup(lighting.lights)
	celestial.aurora_strength = 0.0
	celestial.inversion_enabled = false
	RenderingServer.global_shader_parameter_set("zs_growth", Vector2.ONE)
	RenderingServer.global_shader_parameter_set("zs_water_growth", 1.0)
	RenderingServer.global_shader_parameter_set("zs_surface_post", false)
	air.native_volume = false
	add_child(air)
	air.setup_ground(terrain, lighting.environment, false)
	surface_map.update(terrain.data, PackedVector3Array())
	air.set_ground_texture(surface_map.ground, surface_map.stream)
	add_child(display_fog)
	display_fog.setup(air, camera, surface_map.ground, surface_map.stream)
	set_weather("Clear")

func set_weather(weather: String) -> void:
	var snow := weather == "Snow"
	var rain := weather == "Rain"
	celestial.cloud = 0.78 if rain else (0.58 if snow else (0.35 if weather == "Mist" else 0.06))
	celestial.cold = 1.0 if snow else 0.0
	_wind = 1.2 if rain else 0.4
	celestial.wind = _wind
	celestial.update_rig()
	RenderingServer.global_shader_parameter_set("zs_snow", 0.8 if snow else 0.0)
	RenderingServer.global_shader_parameter_set("zs_ice", 1.0 if snow else 0.0)
	RenderingServer.global_shader_parameter_set("zs_ground_wet", 1.0 if rain else 0.0)
	RenderingServer.global_shader_parameter_set("zs_foliage_wet", 1.0 if rain else 0.0)
	RenderingServer.global_shader_parameter_set("zs_cloud", Vector4(celestial.cloud, 0.0, 20.0, 12.0))
	air.cloud = celestial.cloud
	air.rain = 1.0 if rain else 0.0
	air.set_weather_profile({"wind": _wind, "mist": 0.35 if weather == "Mist" else 0.04, "haze": 0.16 if weather == "Mist" else 0.06}, true)
	display_fog.blend.set_shader_parameter("surface_fog_color", celestial.surface_fog_color)
	display_fog.blend.set_shader_parameter("aerial_sun_color", celestial.aerial_sun_color)
	display_fog.material.set_shader_parameter("fog_display", celestial.fog_display)

func update_ground(data: GardenData, water: PackedVector3Array) -> void:
	surface_map.update(data, water)
	air.update_ground_bounds(terrain)
	display_fog.material.set_shader_parameter("floor_height", air._ground_min)

func _process(delta: float) -> void:
	_time += delta
	RenderingServer.global_shader_parameter_set("zs_motion_time", _time)
	RenderingServer.global_shader_parameter_set("zs_flow_time", _time)
	RenderingServer.global_shader_parameter_set("zs_camera_position", camera.global_position)

	air.advance(delta, false)
	display_fog.update_view()
