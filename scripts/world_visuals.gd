extends Node3D
## Shared, saved atmosphere and geology for editor worlds and title covers.
const LIMITS := {"fog_density":[0.0,1.8],"fog_height":[1.5,14.0],"peak_density":[0.0,0.7],"peak_altitude":[2.0,24.0],"rock_style":[0,2],"rock_detail":[0.0,1.0]}
var fog_density := 0.0
var fog_height := 6.0
var peak_density := 0.0
var peak_altitude := 8.0
var rock_style := 0
var rock_detail := 0.65
var _fog: FogVolume
var _peaks: FogVolume
var _signature := PackedByteArray()
var _settings_ref: Dictionary
var _geology: ImageTexture
var _genome := {}
var _water_shader: Shader
var _water_managed := false
func document() -> Dictionary:
	var result := {}
	for key in LIMITS: result[key] = get(key)
	return result
static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != LIMITS.size(): return false
	for key in LIMITS:
		if not GardenData._number(value.get(key),LIMITS[key][0],LIMITS[key][1]): return false
	return GardenData._integer(value.rock_style)
func restore(value: Dictionary = {}) -> void:
	var defaults := {"fog_density":0.0,"fog_height":6.0,"peak_density":0.0,"peak_altitude":8.0,"rock_style":0,"rock_detail":0.65}
	for key in LIMITS: set(key,value.get(key,defaults[key]))
func _volume(shader: Shader, extent: Vector3) -> FogVolume:
	var volume := FogVolume.new()
	volume.size = extent
	volume.material = ShaderMaterial.new()
	volume.material.shader = shader
	add_child(volume)
	return volume
func sync(scene: Node3D) -> void:
	if _fog == null:
		_fog = _volume(preload("res://shaders/living_fog.gdshader"),Vector3(36,24,36))
		_fog.position.y = 10.0
		_peaks = _volume(preload("res://shaders/peak_clouds.gdshader"),Vector3(36,7,36))
	_fog.visible = fog_density>0.0
	_peaks.visible = peak_density>0.0
	_peaks.position.y = peak_altitude
	if _fog.visible or _peaks.visible:
		scene._environment.volumetric_fog_enabled = true
		scene._environment.volumetric_fog_length = maxf(125.0,scene.distance+40.0)
	var color: Color = scene._celestial.look.colors.fog.srgb_to_linear().lerp(Color(0.85,0.89,0.94).srgb_to_linear(),0.65)
	var fog_values := {"ground_map":scene._precipitation.ground_texture,"stream_map":scene._precipitation.stream_texture,"bank_density":fog_density,"bank_height":fog_height,"activity":clampf(scene._atmosphere._air_strength/3.5,0,1),"bank_clock":scene._motion_time,"bank_color":Vector3(color.r,color.g,color.b)}
	for key in fog_values: _fog.material.set_shader_parameter(key,fog_values[key])
	_peaks.material.set_shader_parameter("cloud_time",scene._motion_time)
	_peaks.material.set_shader_parameter("cloud_density",peak_density)
	var data: NativeTerrainData = scene._chunk_editor.data
	# Terrain data replaces its settings dictionary rather than editing it, so
	# the same instance means the same settings and skips re-serializing.
	var settings_changed := not is_same(data._recipe_settings,_settings_ref)
	var signature: PackedByteArray = var_to_bytes(data._recipe_settings) if settings_changed else _signature
	_settings_ref = data._recipe_settings
	if signature != _signature:
		_signature = signature
		_genome = data._recipe.inland.genome if data._recipe != null and data._recipe_settings.get("kind") == "inland" else {}
		_geology = null
		if not _genome.is_empty() and _genome.composition in preload("res://scripts/desert_landscape.gd").KINDS:
			var image: Image = data._recipe_geology if data._recipe_geology_signature == signature else null
			# Canonical recipe preparation publishes this CPU image with its
			# height tables. Retain the old loop for hand-constructed providers.
			if image == null:
				image = Image.create(128,128,false,Image.FORMAT_RGBA8)
				for z in range(128):
					for x in range(128):
						var field: Vector3 = preload("res://scripts/desert_landscape.gd").field(_genome,Vector2(-14.0+(x+0.5)*28.0/128.0,-14.0+(z+0.5)*28.0/128.0))
						image.set_pixel(x,z,Color(field.y,field.z,0,1))
			_geology = ImageTexture.create_from_image(image)
	var material: ShaderMaterial = scene._chunk_editor.terrain.get_active_material(0)
	if material != null and material.shader.resource_path == "res://shaders/reference_surface.gdshader":
		material.set_shader_parameter("rock_treatment",rock_style)
		material.set_shader_parameter("rock_detail_strength",rock_detail)
		material.set_shader_parameter("inland_rock_amount",0.0 if _genome.is_empty() or _genome.composition == "dunes" else 1.0)
		material.set_shader_parameter("desert_enabled",_geology != null)
		material.set_shader_parameter("desert_has_map",_geology != null)
		material.set_shader_parameter("desert_geology",_geology)
		material.set_shader_parameter("desert_band_height",0.85*float(_genome.get("relief",1.0)))
	var water: ShaderMaterial = scene._chunk_editor.content._water_material
	if _genome.get("composition") == "salt-basin":
		if not _water_managed: _water_shader = water.shader
		_water_managed = true
		water.shader = preload("res://shaders/inland_water.gdshader")
		water.set_shader_parameter("salt_pool",true)
	elif _water_managed:
		water.shader = _water_shader
		_water_managed = false
