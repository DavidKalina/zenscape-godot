extends Node3D
## The weather's rain and wet (docs/design/endless-flight/spec-weather.md,
## lane rain), all by the rain field (Weather.rain_at, rain_here, wet; on the
## GPU zs_rain_at in shaders/weather.gdshaderinc). Built only with weather
## (studies/endless_flight.gd `weather` not null). Lifted from the old storm's
## storm_rain.gd, keyed to the field, which has no edge:
## - the streaks round the eye (shaders/weather_rain.gdshader): COUNT drops in
##   a box round the camera, world-fixed and falling, as many shown as it
##   rains at the eye, so a drizzle is a few and a cell's heart many;
## - the rain seen through the air (shaders/weather_rain_air.gdshader): from
##   kilometres off a cell is a soft grey shaft under the cloud, lit land
##   beyond it; no cards, no edge;
## - the lens wetted under rain (the study's WaterContact screen, ScreenWet
##   `wet`), a few small drops, more at speed;
## - the rain bed in the sound (FlightSound `rain_to`).
## Rain on the water and the wet land are in the sea and ground shaders
## (shaders/weather_rain_water.gdshaderinc; zs_weather.w). Nothing here
## touches the plane.
##
## Cost: nothing drawn while no rain falls anywhere (both hidden). In rain,
## one draw of COUNT thin quads (all their work in the vertex shader; the
## drops not shown folded away) and one full-screen pass of a few reads of
## the field a pixel.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Field = preload("res://scripts/endless/land_field.gd")

const COUNT := 18000
const BOX := Vector3(64.0,40.0,64.0)
## The lens: ScreenWet amount a second at a rain of 1 (times LENS_SPEED at
## cruise, less slow). Small: a few drops bead and run, not a doused screen.
const LENS := 0.12
const LENS_SPEED := Vector2(0.3,1.0)
## The rain's air sheet: drawn after the clouds' (-6), before the rain.
const AIR_PRIORITY := -5
## The share of the drops shown at a rain of 1 (weather_rain.gdshader `most`).
const STREAK_MOST := 0.8

var weather: Weather
var streaks: MeshInstance3D
var rain_air: MeshInstance3D
var _streak_mat: ShaderMaterial
var _air_mat: ShaderMaterial
var _clouds_seen: Object
var _clock := 0.0
var _last_eye := Vector3.INF
## The rain at the eye as of the last step (0..1), and the share of the
## streaks shown (for probes).
var here := 0.0
var shown := 0.0

func _init() -> void:
	name = "WeatherRain"

func setup(w: Weather) -> void:
	weather = w
	_streak_mat = ShaderMaterial.new()
	_streak_mat.shader = preload("res://shaders/weather_rain.gdshader")
	_streak_mat.set_shader_parameter("box",BOX)
	_streak_mat.set_shader_parameter("most",STREAK_MOST)
	streaks = _instance("Streaks",_streak_mesh(),_streak_mat)
	_air_mat = ShaderMaterial.new()
	_air_mat.shader = preload("res://shaders/weather_rain_air.gdshader")
	_air_mat.set_shader_parameter("sea_y",Field.SEA_Y)
	_air_mat.render_priority = AIR_PRIORITY
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0,2.0)
	rain_air = _instance("Air",quad,_air_mat)
	rain_air.ignore_occlusion_culling = true
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--rain-opacity="): _streak_mat.set_shader_parameter("opacity",a.get_slice("=",1).to_float())
		elif a.begins_with("--rain-air="): _air_mat.set_shader_parameter("opacity",a.get_slice("=",1).to_float())
		elif a.begins_with("--rain-slant="): _streak_mat.set_shader_parameter("slant",a.get_slice("=",1).to_float())
		elif a.begins_with("--rain-sigma="): _air_mat.set_shader_parameter("sigma",a.get_slice("=",1).to_float())
	streaks.visible = false
	rain_air.visible = false

func _instance(id: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = id
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Placed in the shader: never culled by its box.
	mi.custom_aabb = AABB(Vector3(-1e6,-1e4,-1e6),Vector3(2e6,2e4,2e6))
	add_child(mi)
	return mi

## COUNT quads: UV the corner (x across, y tail to head), UV2.x the drop.
static func _streak_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(COUNT*4)
	uv.resize(COUNT*4)
	uv2.resize(COUNT*4)
	idx.resize(COUNT*6)
	var corners := [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	for i in range(COUNT):
		for k in range(4):
			uv[i*4+k] = corners[k]
			uv2[i*4+k] = Vector2(float(i),0.0)
		var b := i*4
		idx[i*6] = b
		idx[i*6+1] = b+1
		idx[i*6+2] = b+2
		idx[i*6+3] = b
		idx[i*6+4] = b+2
		idx[i*6+5] = b+3
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

## One frame, after the weather's and the look's steps: `game` the endless
## flight study.
func step(delta: float, game: Node3D) -> void:
	if weather == null or delta <= 0.0: return
	var cam: Camera3D = game.get_viewport().get_camera_3d()
	if cam == null: return
	var eye := cam.global_position
	var vel := Vector3.ZERO
	if _last_eye != Vector3.INF: vel = (eye-_last_eye)/delta
	if vel.length() > 250.0: vel = Vector3.ZERO
	_last_eye = eye
	_clock += delta
	here = weather.rain_here()
	shown = here*STREAK_MOST
	var raining := weather.rain_level() > 0.0
	streaks.visible = here > 0.0
	rain_air.visible = raining
	# The rain's air rides the land (its rise is over the ground, as the
	# clouds' bases are), so the ground under the eye each frame.
	if raining:
		var field = game.get("field")
		if field != null: _air_mat.set_shader_parameter("ground_y",maxf(float(field.height(eye.x,eye.z)),Field.SEA_Y))
	if streaks.visible:
		_streak_mat.set_shader_parameter("eye_velocity",vel)
		_streak_mat.set_shader_parameter("clock",fmod(_clock,4096.0))
	var look = game.get("look")
	if raining: _see_clouds(look.clouds if look != null else null)
	var plane = game.get("plane")
	var air := 0.0
	if plane != null: air = (plane.velocity as Vector3).length()/maxf(float(plane.cruise()),1.0)
	# The lens: a few drops land as the rain is heavy, more flying into it.
	var water = game.get("water")
	if here > 0.0 and water != null and water.screen != null:
		water.screen.wet(here*LENS*lerpf(LENS_SPEED.x,LENS_SPEED.y,clampf(air,0.0,1.0))*delta)
	var sound = game.get("sound")
	if sound != null and sound.has_method("rain_to"): sound.rain_to(here,clampf(air,0.0,1.5))

## The rain's air seen through the clouds' march (its resolved shape: cover,
## distance), so rain behind a cloud never lays over it.
func _see_clouds(clouds: Node) -> void:
	var on: bool = clouds != null and bool(clouds.enabled) and bool(clouds.sheet.visible) and clouds.get("effect") != null
	if on and _clouds_seen != clouds:
		var shape = clouds.effect.get("resolved_b")
		if shape == null: on = false
		else:
			_clouds_seen = clouds
			_air_mat.set_shader_parameter("cloud_shape",shape)
	_air_mat.set_shader_parameter("clouds_on",1.0 if on and _clouds_seen == clouds else 0.0)
