extends FogVolume
## Native landscape mist, with a forest-floor treatment for redwood biomes.
## Terrain and cover are rebuilt
## from editor data; the existing mist/rays controls still set their intensity.
var revision := -1
var objects_revision := -1
var redwoods := 0
var active := false
var enabled := true
var redwood := false
var woodland_material := ShaderMaterial.new()
var saved := {}
var cover: ImageTexture
var cover_image: Image
var _cover_signature := PackedByteArray()
var fog_material := ShaderMaterial.new()
## The mist's drift with the wind (`_blow`): metres travelled downwind in the
## stretched frame, and the scene clock it was last moved at.
var air_travel := 0.0
var _blown_at := -1.0
## Metres a second the mist drifts in still air, and more per unit of wind
## (the atmosphere's strength, gusts and all): a breeze of 0.4 moves it about
## 0.35 m/s, a strong wind of 2 nearly 2 m/s.
const Plate := preload("res://scripts/plate.gd")
const DRIFT_CALM := 0.1
const DRIFT_CARRY := 0.85
## How far a wind draws the mist out along itself: at strength s the noise is
## stretched 1 + STRETCH × s times along the wind.
const STRETCH := 0.7

func _init() -> void:
	name = "RedwoodBiomeMist"
	size = Vector3(32,40,32)
	position.y = 17.0
	fog_material.shader = preload("res://shaders/redwood_biome_mist.gdshader")
	woodland_material.shader = preload("res://shaders/beauty_mist.gdshader")
	material = fog_material
	visible = false

func _cover(data: NativeTerrainData) -> void:
	var trees: Array[Dictionary] = []
	for item in data.objects:
		if item.asset == "redwood" and data._recipe_settings.get("biome","")=="redwood": trees.append(item)
	redwoods = trees.size()
	var footprints: Array = []
	for tree in trees: footprints.append([tree.x,tree.z,tree.scale])
	var signature := var_to_bytes(footprints)
	if cover != null and signature == _cover_signature: return
	_cover_signature = signature
	cover_image = Image.create(Plate.SHADE_SIZE,Plate.SHADE_SIZE,false,Image.FORMAT_RF)
	cover_image.fill(Color(0,0,0,1))
	# A tree contributes nothing beyond its radius. Rasterize its footprint
	# instead of testing every tree against every pixel on each edit.
	for tree in trees:
		var radius: float = clampf(tree.scale*3.5,1.5,6.0)
		var low := Vector2i(clampi(floori((tree.x-radius+Plate.MAP_HALF)/Plate.SHADE_TEXEL),0,Plate.SHADE_SIZE),clampi(floori((tree.z-radius+Plate.MAP_HALF)/Plate.SHADE_TEXEL),0,Plate.SHADE_SIZE))
		var high := Vector2i(clampi(ceili((tree.x+radius+Plate.MAP_HALF)/Plate.SHADE_TEXEL),0,Plate.SHADE_SIZE),clampi(ceili((tree.z+radius+Plate.MAP_HALF)/Plate.SHADE_TEXEL),0,Plate.SHADE_SIZE))
		for y in range(low.y,high.y):
			for x in range(low.x,high.x):
				var point := Vector2((x+0.5)*Plate.SHADE_TEXEL-Plate.MAP_HALF,(y+0.5)*Plate.SHADE_TEXEL-Plate.MAP_HALF)
				var distance := point.distance_to(Vector2(tree.x,tree.z))/radius
				var value := maxf(cover_image.get_pixel(x,y).r,1.0-smoothstep(0.1,1.0,distance))
				cover_image.set_pixel(x,y,Color(value,0,0,1))
	cover = ImageTexture.create_from_image(cover_image)
	fog_material.set_shader_parameter("tree_cover",cover)

func sync(scene: Node3D) -> void:
	var data: NativeTerrainData = scene._chunk_editor.data
	if revision != scene._chunk_editor.content.revision or objects_revision != data.objects_revision:
		revision = scene._chunk_editor.content.revision
		objects_revision = data.objects_revision
		_cover(data)
		fog_material.set_shader_parameter("ground_map",scene._precipitation.ground_texture)
		fog_material.set_shader_parameter("stream_map",scene._precipitation.stream_texture)
	redwood = data._recipe_settings.get("biome", "") == "redwood" and redwoods > 0
	var wanted: bool = enabled and (data._recipe != null or not data.objects.is_empty() or not data.ponds.is_empty()) and scene._growth.terrain>=0.995 and scene._growth.foliage>=0.995 and scene._atmosphere.fog_amount>0.001 and RenderingServer.get_current_rendering_method()=="forward_plus"
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
	material = fog_material if redwood else woodland_material
	_blow(scene)
	woodland_material.set_shader_parameter("ground_map", scene._precipitation.ground_texture)
	woodland_material.set_shader_parameter("stream_map", scene._precipitation.stream_texture)
	woodland_material.set_shader_parameter("density", 0.145 * clampf(scene._atmosphere.fog_amount / 0.18, 0.0, 2.0))
	fog_material.set_shader_parameter("mist_time",scene._motion_time)
	fog_material.set_shader_parameter("amount",clampf(scene._atmosphere.fog_amount/0.45,0.0,2.0))
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_length = 65.0
	env.volumetric_fog_anisotropy = 0.65 if redwood else 0.55
	env.volumetric_fog_ambient_inject = 0.2 if redwood else 0.25
	scene._display_fog.visible = false
	scene._atmosphere.get_node("ValleyFog").visible = false
	for light in scene._lights:
		light.light_volumetric_fog_energy = 2.2*scene._atmosphere.ray_strength if light.shadow_enabled else 0.0

## Moves the mist on with the wind, by the scene's clock (so a paused world
## holds it), and hands both mists the wind as it is now.
func _blow(scene: Node3D) -> void:
	var air: Node = scene._atmosphere
	var now: float = scene._motion_time
	var dt := clampf(now-_blown_at,0.0,0.1) if _blown_at >= 0.0 else 0.0
	_blown_at = now
	var steady := maxf(float(air._air_strength)+float(air.swell),0.0)
	var blowing := steady*float(air.gust_at(float(air._wind_time)))
	var stretch := 1.0/(1.0+STRETCH*steady)
	air_travel += (DRIFT_CALM+DRIFT_CARRY*blowing)*stretch*dt
	for target: ShaderMaterial in [woodland_material,fog_material]:
		target.set_shader_parameter("air_travel",air_travel)
		target.set_shader_parameter("air_stretch",stretch)
		target.set_shader_parameter("air_strength",steady)
