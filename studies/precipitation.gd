extends Node3D
## Source weather.js precipitation cycles, adapted to native instanced geometry.
## A shared height texture clips wind-carried particles to terrain and water.

const Plate = preload("res://scripts/plate.gd")
## The ground and stream maps' reach (the shaders' ground_half).
const HALF := Plate.MAP_HALF
const MAP_SIZE := Plate.MAP_SIZE
const SKY_CLEARANCE := 32.0
const COUNT := [6000, 3500, 1600]
signal weather_selected(profile: Dictionary, instant: bool)
const PRESET_NAMES := ["clear", "rain", "storm", "snow", "fair", "overcast", "mist", "autumn"]
var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/weather-profiles.json"))
var preset_index := 0
var cloud_layer := Vector2(20, 12)
var ground_texture: Texture2D
var stream_texture: Texture2D
var cloud_override := -1.0
var cold_override := -1.0
var wind := 0.4
## How fast rain, cloud and storm ease toward a new preset, per second. Living
## weather (scripts/living_weather.gd) slows it so a drifting sky changes over
## half a minute instead of a few seconds.
var response := 0.55
## Living weather: rain and storm wait for the cloud to build, and stop as it
## thins, so a clear sky never rains before it has clouded over.
var gather := false
var leaves: MultiMeshInstance3D
var surface_weather := preload("res://studies/surface_weather.gd").new()
var state := Vector4(0, 0, 0.06, 0)
var target := Vector4(0, 0, 0.06, 0)
var _materials: Array[ShaderMaterial] = []
var _instances: Array[MultiMesh] = []
var _surfaces: Array[RefCounted] = []
var _water_beds: Array[float] = []
var _random := 7

func _rnd() -> float:
	_random = (_random * 1664525 + 1013904223) & 0xffffffff
	return float(_random >> 8) / 16777216.0

func _height(x: float, z: float) -> float:
	var height := -1000.0
	for surface in _surfaces:
		var sample: Variant = surface.height_at(x, z)
		if sample != null:
			height = maxf(height, sample)
	return height

func setup(geometry: Node3D, terrain: RefCounted) -> void:
	Plate.publish_shader_globals()
	leaves = preload("res://studies/falling_leaves.gd").new()
	add_child(leaves)
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/environment.json"))
	cloud_layer = Vector2(reference.uCloudY, reference.uCloudH)
	_surfaces.append(terrain)
	_water_beds.append(-1000.0)
	for node in geometry.get_children():
		if node is MeshInstance3D:
			var material := node.mesh.surface_get_material(0) as ShaderMaterial
			if material != null and material.shader.resource_path.ends_with("reference_water.gdshader"):
				var surface := preload("res://scripts/reference_ground.gd").new()
				surface.setup(node)
				_surfaces.append(surface)
				_water_beds.append(float(node.get_meta("water_bed", -1000.0)))
	var height_image := Image.create(Plate.MAP_TEXELS, Plate.MAP_TEXELS, false, Image.FORMAT_RGBAF)
	var stream_image := Image.create(Plate.MAP_TEXELS, Plate.MAP_TEXELS, false, Image.FORMAT_RGBAF)
	var highest := 0.0
	for z in range(Plate.MAP_TEXELS):
		for x in range(Plate.MAP_TEXELS):
			var px := (x + 0.5) / float(Plate.MAP_TEXELS) * HALF * 2.0 - HALF
			var pz := (z + 0.5) / float(Plate.MAP_TEXELS) * HALF * 2.0 - HALF
			var ground: Variant = terrain.height_at(px, pz)
			var ground_y: float = ground if ground != null else -1000.0
			var water_y := -1000.0
			var bed := -1000.0
			var stream_info := Vector4.ZERO
			for i in range(1, _surfaces.size()):
				var sample: Variant = _surfaces[i].height_at(px, pz)
				if sample != null and sample > water_y:
					water_y = sample
					stream_info = _surfaces[i].stream_at(px, pz)
					bed = _water_beds[i] if _water_beds[i] > -100.0 else water_y
			var value := maxf(ground_y, water_y)
			highest = maxf(highest, value)
			height_image.set_pixel(x, z, Color(value, ground_y, bed, water_y))
			stream_image.set_pixel(x, z, Color(stream_info.x, stream_info.y, stream_info.z, stream_info.w))
	var height_texture := ImageTexture.create_from_image(height_image)
	ground_texture = height_texture
	stream_texture = ImageTexture.create_from_image(stream_image)
	var rain_homes: Array[Vector3] = []
	var rain_drops: Array[Color] = []
	for kind in range(3):
		var mesh: Mesh
		if kind == 0:
			var lines := ArrayMesh.new()
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.UP])
			lines.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
			mesh = lines
		else:
			mesh = QuadMesh.new()
			mesh.size = Vector2.ONE
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/reference_precipitation.gdshader")
		material.set_shader_parameter("kind", kind)
		material.set_shader_parameter("top", highest + SKY_CLEARANCE)
		material.set_shader_parameter("ground_map", height_texture)
		material.set_shader_parameter("stream_map", stream_texture)
		material.set_shader_parameter("ground_half", HALF)
		_materials.append(material)
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_custom_data = true
		instances.mesh = mesh
		instances.instance_count = COUNT[kind]
		for i in range(COUNT[kind]):
			var home: Vector3
			var drop: Color
			if kind == 2:
				home = rain_homes[i]
				drop = rain_drops[i]
			else:
				home = Vector3((_rnd() - 0.5) * HALF * 2.0, 0, (_rnd() - 0.5) * HALF * 2.0)
				var ground := _height(home.x, home.z)
				var speed := (16.0 + _rnd() * 12.0) if kind == 0 else (1.3 + _rnd() * 1.2)
				drop = Color(ground, speed, _rnd(), _rnd())
				if kind == 0:
					rain_homes.append(home)
					rain_drops.append(drop)
			instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, home))
			instances.set_instance_custom_data(i, drop)
		instances.visible_instance_count = 0
		_instances.append(instances)
		var node := MultiMeshInstance3D.new()
		node.name = ["Rain", "Snow", "RainCrowns"][kind]
		node.multimesh = instances
		node.material_override = material
		node.custom_aabb = AABB(Vector3(-HALF * 2, -2, -HALF * 2), Vector3(HALF * 4, highest + SKY_CLEARANCE + 3.0, HALF * 4))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)

func set_weather(index: int, instant := false) -> void:
	cloud_override = -1.0
	cold_override = -1.0
	preset_index = clampi(index, 0, PRESET_NAMES.size() - 1)
	var profile: Dictionary = profiles[PRESET_NAMES[preset_index]]
	surface_weather.target_cold = profile.cold
	surface_weather.target_autumn = profile.autumn
	if instant:
		surface_weather.cold = surface_weather.target_cold
		surface_weather.autumn = surface_weather.target_autumn
	target = Vector4(profile.rain, 0.0, profile.cloud, profile.storm)
	if instant:
		state = target
	weather_selected.emit(profile, instant)

func advance(delta: float, paused: bool, celestial: RefCounted) -> void:
	if not paused:
		var aim := target
		if gather:
			var covered := smoothstep(0.35, 0.7, state.z)
			aim.x *= covered
			aim.w *= covered
		state = state.lerp(aim, 1.0 - exp(-delta * response))
	surface_weather.target_cold = cold_override if cold_override >= 0.0 else surface_weather.target_cold
	var cloud_now := cloud_override if cloud_override >= 0.0 else state.z
	surface_weather.advance(delta, paused, minf(1.0, state.x + state.y), cloud_now, wind)
	celestial.cold = surface_weather.cold
	celestial.autumn = surface_weather.autumn
	leaves.update_season(surface_weather.autumn)
	celestial.weather_bow = smoothstep(0.04, 0.22, celestial.state.get("zs_sun_direction", Vector3.UP).y) * smoothstep(0.92, 0.5, cloud_now) * (1.0 - 0.7 * state.w) * smoothstep(0.03, 0.45, surface_weather.air_wet) * (1.0 - surface_weather.snow_phase) * (1.0 - celestial.shroud)
	celestial.cloud = cloud_override if cloud_override >= 0.0 else state.z
	RenderingServer.global_shader_parameter_set("zs_cloud", Vector4(celestial.cloud, state.w, cloud_layer.x, cloud_layer.y))
	celestial.storm = state.w
	for kind in range(3):
		var amount := minf(1.0, state.x + state.y)
		var intensity: float = minf(1.0, amount * 1.2) * surface_weather.snow_phase if kind == 1 else amount * (1.0 - surface_weather.snow_phase)
		_materials[kind].set_shader_parameter("intensity", intensity)
		_instances[kind].visible_instance_count = int(COUNT[kind] * intensity)

func set_ceiling(height: float) -> void:
	for material in _materials:
		material.set_shader_parameter("top", height)
	# Shader motion extends beyond the instance meshes, including after edits.
	for particle_name in ["Rain", "Snow", "RainCrowns"]:
		var particles := get_node(NodePath(particle_name)) as MultiMeshInstance3D
		var bounds := particles.custom_aabb
		bounds.size.y = height + 1.0 - bounds.position.y
		particles.custom_aabb = bounds
