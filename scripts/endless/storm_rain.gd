extends Node3D
## The storm's rain (docs/design/endless-flight/spec-storm-front.md, the rain
## lane), built only when there is a storm (study.storm not null):
## - the streaks round the eye (shaders/storm_rain.gdshader): COUNT drops in
##   a BOX round the camera, world-fixed and falling, each a streak along its
##   motion past the eye, shown as densely as the storm rains where it falls;
## - the curtains (shaders/storm_curtain.gdshader): grey veils hanging from
##   the cloud base under the core, cards on the storm's own frame, so they
##   ride the front; seen from afar, faded near the eye;
## - the rain's air (shaders/storm_rain_air.gdshader): a sheet over the
##   screen that greys whatever is seen through the rain under the deck, so
##   the distance under it joins the cloud base and the near land softens;
## - the lens wetted under rain (the study's `wet`, WaterContact `douse`:
##   ScreenWet drops), more at speed;
## - the rain bed in the sound (FlightSound `rain_to`).
## Rain on the water is in the sea and ground shaders
## (shaders/storm_rain_water.gdshaderinc). Nothing here touches the plane.
##
## Cost: one draw of COUNT thin quads (all their work in the vertex shader;
## the drops outside the rain are folded away) and one draw of the curtain
## cards (a few noise reads a pixel, cut where there's no rain or near the
## eye), and one full-screen pass for the rain's air (TAPS cheap taps a
## pixel, cut where a ray meets no rain).

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Field = preload("res://scripts/endless/land_field.gd")

const COUNT := 18000
const BOX := Vector3(64.0,44.0,64.0)
## The curtain cards: rows across the core (d behind the leading edge, m),
## spaced CARD_STEP along the line, CARD_WIDTH wide (least, most).
const CARD_ROWS := [-200.0,-700.0,-1250.0,-1800.0,-2350.0,-2900.0]
const CARD_STEP := 620.0
const CARD_WIDTH := Vector2(650.0,1300.0)
## The lens: ScreenWet amount a second at full rain (times LENS_SPEED at
## cruise, less slow), and none while the eye is under cover (unchecked).
const LENS := 0.8
const LENS_SPEED := Vector2(0.35,1.0)
## Enveloped (StormFront `immersed`, `env_here`): in the storm's cloud the
## lens mists over (ScreenWet amount a second, whole in cloud) and the air's
## sound closes in (FlightSound `cloud_muffle`: whole in cloud, ENV_MUFFLE
## of it deep under the envelope).
const CLOUD_LENS := 0.5
const CLOUD_MUFFLE := 0.55
const ENV_MUFFLE := 0.35
## The rain's air sheet: drawn after the clouds' (-6), before the rain.
const AIR_PRIORITY := -5

var storm: RefCounted
var streaks: MeshInstance3D
var curtains: MeshInstance3D
var rain_air: MeshInstance3D
var _streak_mat: ShaderMaterial
var _curtain_mat: ShaderMaterial
var _air_mat: ShaderMaterial
var _clouds_seen: Node
var _clock := 0.0
var _last_eye := Vector3.INF
## The rain at the eye as of the last step (0..1), for probes.
var here := 0.0
var off := false

func _init() -> void:
	name = "StormRain"

func setup(storm_front: RefCounted) -> void:
	storm = storm_front
	off = "--storm-rain=0" in LaunchArgs.user_args()
	if off: return
	_streak_mat = ShaderMaterial.new()
	_streak_mat.shader = preload("res://shaders/storm_rain.gdshader")
	_streak_mat.set_shader_parameter("box",BOX)
	streaks = _instance("Streaks",_streak_mesh(),_streak_mat)
	_curtain_mat = ShaderMaterial.new()
	_curtain_mat.shader = preload("res://shaders/storm_curtain.gdshader")
	_curtain_mat.set_shader_parameter("sea_y",Field.SEA_Y)
	curtains = _instance("Curtains",_curtain_mesh(),_curtain_mat)
	_air_mat = ShaderMaterial.new()
	_air_mat.shader = preload("res://shaders/storm_rain_air.gdshader")
	_air_mat.set_shader_parameter("sea_y",Field.SEA_Y)
	# Just after the clouds' sheet (EndlessClouds RENDER_PRIORITY -6), so
	# the deck's base seen through the rain greys with it, and before the
	# curtains and streaks, which are the rain itself.
	_air_mat.render_priority = AIR_PRIORITY
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0,2.0)
	rain_air = _instance("Air",quad,_air_mat)
	rain_air.ignore_occlusion_culling = true
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--rain-opacity="): _streak_mat.set_shader_parameter("opacity",a.get_slice("=",1).to_float())
		elif a.begins_with("--curtain-opacity="): _curtain_mat.set_shader_parameter("opacity",a.get_slice("=",1).to_float())
		elif a.begins_with("--curtain-base="): _curtain_mat.set_shader_parameter("base",a.get_slice("=",1).to_float())
		elif a.begins_with("--rain-air="): _air_mat.set_shader_parameter("opacity",a.get_slice("=",1).to_float())
		elif a.begins_with("--rain-air-sigma="): _air_mat.set_shader_parameter("sigma",a.get_slice("=",1).to_float())

func _instance(id: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = id
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Placed in the shader (world_vertex_coords): never culled by its box.
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
	return _mesh(verts,uv,uv2,PackedColorArray(),idx)

## The curtain cards: UV the corner (y foot 0 to top 1), UV2 (along, d),
## COLOR (width / 2000, seed, top's jitter).
func _curtain_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var half: float = float(storm.length)*0.5
	var corners := [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	for row: float in CARD_ROWS:
		var along := -half+CARD_STEP*0.5+rng.randf()*CARD_STEP*0.5
		while along < half:
			var where := Vector2(along+rng.randf_range(-0.3,0.3)*CARD_STEP,row+rng.randf_range(-180.0,180.0))
			var c := Color(rng.randf_range(CARD_WIDTH.x,CARD_WIDTH.y)/2000.0,rng.randf(),rng.randf())
			var b := verts.size()
			for k in range(4):
				verts.append(Vector3.ZERO)
				uv.append(corners[k])
				uv2.append(where)
				col.append(c)
			idx.append_array([b,b+1,b+2,b,b+2,b+3])
			along += CARD_STEP*rng.randf_range(0.75,1.25)
	return _mesh(verts,uv,uv2,col,idx)

static func _mesh(verts: PackedVector3Array, uv: PackedVector2Array, uv2: PackedVector2Array, col: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	if not col.is_empty(): arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

## One frame, after the storm's step: `game` the endless flight study.
func step(delta: float, game: Node3D) -> void:
	if storm == null or delta <= 0.0: return
	var cam: Camera3D = game.camera
	if cam == null: return
	var eye := cam.global_position
	var vel := Vector3.ZERO
	if _last_eye != Vector3.INF: vel = (eye-_last_eye)/delta
	if vel.length() > 250.0: vel = Vector3.ZERO
	_last_eye = eye
	_clock += delta
	var q := Vector2(eye.x,eye.z)
	here = storm.rain_at(q)
	_enveloped(delta,game)
	if off:
		_sound(game,0.0)
		return
	# The streaks drawn only near rain (the box's reach either way across).
	var reach := BOX.x*0.75
	var h: Vector2 = storm.heading()
	var near := maxf(here,maxf(storm.rain_at(q+h*reach),storm.rain_at(q-h*reach)))
	streaks.visible = near > 0.0
	if streaks.visible:
		_streak_mat.set_shader_parameter("eye_velocity",vel)
		_streak_mat.set_shader_parameter("clock",fmod(_clock,4096.0))
	_curtain_mat.set_shader_parameter("clock",fmod(_clock,4096.0))
	_air_mat.set_shader_parameter("clock",fmod(_clock,4096.0))
	var look = game.get("look")
	if look != null and look.environment != null: _curtain_mat.set_shader_parameter("fog_end",look.environment.fog_depth_end)
	_see_clouds(look.clouds if look != null else null)
	# The lens: drops land as the rain is heavy, more flying into it.
	var air := 0.0
	if game.plane != null: air = (game.plane.velocity as Vector3).length()/maxf(float(game.plane.cruise()),1.0)
	if here > 0.0 and game.has_method("wet"):
		game.wet(here*LENS*lerpf(LENS_SPEED.x,LENS_SPEED.y,clampf(air,0.0,1.0))*delta)
	_sound(game,clampf(air,0.0,1.5))

## In the storm's cloud: the lens and the sound.
func _enveloped(delta: float, game: Node3D) -> void:
	var inside: float = storm.immersed
	if inside > 0.01 and game.has_method("wet"): game.wet(inside*CLOUD_LENS*delta)
	var sound = game.get("sound")
	if sound != null and "cloud_muffle" in sound:
		sound.cloud_muffle = CLOUD_MUFFLE*maxf(inside,float(storm.env_here)*ENV_MUFFLE)

## The rain's air and curtains seen through the clouds' march (its resolved
## shape: cover, distance), so rain behind a cloud never lays over it.
func _see_clouds(clouds: Node) -> void:
	var on: bool = clouds != null and bool(clouds.enabled) and bool(clouds.sheet.visible)
	if on and _clouds_seen != clouds:
		_clouds_seen = clouds
		_air_mat.set_shader_parameter("cloud_shape",clouds.effect.resolved_b)
		_curtain_mat.set_shader_parameter("cloud_shape",clouds.effect.resolved_b)
	_air_mat.set_shader_parameter("clouds_on",1.0 if on else 0.0)
	_curtain_mat.set_shader_parameter("clouds_on",1.0 if on else 0.0)

func _sound(game: Node3D, air: float) -> void:
	var sound = game.get("sound")
	if sound != null and sound.has_method("rain_to"): sound.rain_to(here,air)
