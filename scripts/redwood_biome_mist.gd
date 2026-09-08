extends FogVolume
## Renderer adapter for the saved redwood biome. Terrain and cover are rebuilt
## from editor data; the existing mist/rays controls still set their intensity.
var revision := -1
var redwoods := 0
var active := false
var saved := {}
var cover: ImageTexture
var cover_image: Image
var fog_material := ShaderMaterial.new()

func _init() -> void:
	name = "RedwoodBiomeMist"
	size = Vector3(32,40,32)
	position.y = 17.0
	fog_material.shader = preload("res://shaders/redwood_biome_mist.gdshader")
	material = fog_material
	visible = false

func _cover(data: NativeTerrainData) -> void:
	var trees: Array[Dictionary] = []
	for item in data.objects:
		if item.asset == "redwood" and data._recipe_settings.get("biome","")=="redwood": trees.append(item)
	redwoods = trees.size()
	cover_image = Image.create(64,64,false,Image.FORMAT_RF)
	for y in range(64):
		for x in range(64):
			var point := Vector2((x+0.5)*0.5-16,(y+0.5)*0.5-16)
			var value := 0.0
			for tree in trees:
				var radius: float = clampf(tree.scale*3.5,1.5,6.0)
				var distance := point.distance_to(Vector2(tree.x,tree.z))/radius
				value = maxf(value,1.0-smoothstep(0.1,1.0,distance))
			cover_image.set_pixel(x,y,Color(value,0,0,1))
	cover = ImageTexture.create_from_image(cover_image)
	fog_material.set_shader_parameter("tree_cover",cover)

func sync(scene: Node3D) -> void:
	var data: NativeTerrainData = scene._chunk_editor.data
	if revision != scene._chunk_editor.content.revision:
		revision = scene._chunk_editor.content.revision
		_cover(data)
		fog_material.set_shader_parameter("ground_map",scene._precipitation.ground_texture)
		fog_material.set_shader_parameter("stream_map",scene._precipitation.stream_texture)
	var wanted: bool = data._recipe_settings.get("biome","")=="redwood" and redwoods>0 and scene._growth.terrain>=0.995 and scene._growth.foliage>=0.995 and scene._atmosphere.fog_amount>0.001 and RenderingServer.get_current_rendering_method()=="forward_plus"
	var env: Environment = scene._environment
	if wanted and not active:
		saved = {"length":env.volumetric_fog_length,"anisotropy":env.volumetric_fog_anisotropy,"ambient":env.volumetric_fog_ambient_inject,"display":scene._display_fog.visible,"valley":scene._atmosphere.get_node("ValleyFog").visible,"rays":[]}
		for light in scene._lights: saved.rays.append(light.light_volumetric_fog_energy)
	if not wanted and active:
		env.volumetric_fog_enabled = false
		env.volumetric_fog_length = saved.length
		env.volumetric_fog_anisotropy = saved.anisotropy
		env.volumetric_fog_ambient_inject = saved.ambient
		scene._display_fog.visible = saved.display
		scene._atmosphere.get_node("ValleyFog").visible = saved.valley
		for i in range(scene._lights.size()): scene._lights[i].light_volumetric_fog_energy = saved.rays[i]
	active = wanted
	visible = active
	if not active: return
	fog_material.set_shader_parameter("mist_time",scene._motion_time)
	fog_material.set_shader_parameter("amount",clampf(scene._atmosphere.fog_amount/0.45,0.0,2.0))
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_length = 65.0
	env.volumetric_fog_anisotropy = 0.65
	env.volumetric_fog_ambient_inject = 0.2
	scene._display_fog.visible = false
	scene._atmosphere.get_node("ValleyFog").visible = false
	for light in scene._lights:
		light.light_volumetric_fog_energy = 2.2*scene._atmosphere.ray_strength if light.shadow_enabled else 0.0
