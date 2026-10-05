extends Node3D
const Plate = preload("res://scripts/plate.gd")
## One moving air field drives vegetation, water, fog and waterfall mist.

var native_volume := true
var cloud := 0.06
var rain := 0.0
var _cloud_drift := Vector3.ZERO
var _summit := Vector3.ZERO
var _ground_min := INF
var strength := 0.4
var direction_angle := 19.290046
var shroud := 0.0
var loosen := 0.0
var fog_amount := 0.45
var summit_mist := 1.0
var ray_strength := 1.0
var inversion_amount := 0.0
var _fog_target := 0.45
## How fast wind, fog and haze ease toward a new weather profile, per second.
## Living weather (scripts/living_weather.gd) slows it for gentle drift.
var weather_response := 0.55
var haze_amount := 0.15
## Ground mist by daylight. The mist that pools in hollows (and the fog bank)
## belongs to dawn, dusk and cold mornings: from DAY_MIST_SUN.x to .y of sun
## height it thins to DAY_MIST_FLOOR of itself, so water in basins reads by
## day. A cold season (celestial `cold`) holds it to DAY_MIST_COLD_SUN, later
## into the morning. Misty weather keeps it all day: fog from DAY_MIST_WEATHER.x
## up to .y (mist weather, the fog bank) lifts the gate. fog_amount itself is
## untouched; only what the air draws is thinned (`ground_mist`).
const DAY_MIST_SUN := Vector2(0.14, 0.4)
const DAY_MIST_COLD_SUN := Vector2(0.3, 0.6)
const DAY_MIST_FLOOR := 0.2
const DAY_MIST_WEATHER := Vector2(0.4, 0.55)
## The evening's window: a setting sun leaves golden hour clear, and the mist
## gathers in the hollows only as the sun goes down through dusk, whole by
## the time the afterglow fades. Through the afterglow itself it stays a low
## veil (about a third at its height), so a close view is not a grey bank
## over a lit land; it thickens with the night look. Cold does not hold it,
## as it does mornings.
const EVENING_MIST_SUN := Vector2(-0.22, -0.04)
## Sun height, whether it is going down (afternoon to midnight), and season
## cold, set by the scene each frame from Celestial.
var sun_height := 0.0
var sun_setting := false
var cold := 0.0
## 0..1, the share of ground mist the hour leaves (1 at dawn and by night).
var day_mist := 1.0
var _haze_target := 0.15
var _air_strength := 0.4
var _air_angle := deg_to_rad(19.290046)
## Short-lived extra air the painting hand stirs up (scripts/stroke_feedback.gd).
## Added on top of the eased dial for what the scenery shows, never saved.
var swell := 0.0
## The ambient breeze plants lean in (docs/scenic/breeze.md), published as
## `zs_breeze`. The air's strength is lifted to a gentle floor, so a world is
## never quite still, and breathes in slow swells and lulls (BREEZE_SWELLS:
## period s, share) tens of seconds long and never in step, instead of the
## whole land pulsing together with gust_at's quick terms. Strong air passes
## through nearly unchanged, so storms still read stronger.
const BREEZE_FLOOR := 0.35
## Tuning (`--breeze=`): scales the whole ambient breeze plants lean in.
var breeze_gain := 1.6
const BREEZE_SWELLS := [Vector3(53.0,0.2,0.6),Vector3(23.0,0.13,2.1),Vector3(9.7,0.07,4.0)]
var _travel := Vector2.ZERO
var _gust_distance := 0.0
var _wind_time := 0.0
var puffs := preload("res://studies/wind_puffs.gd").new()
## The breeze's events: gust fronts rolling across the plate
## (studies/gust_fronts.gd), with a quiet before each.
var fronts := preload("res://studies/gust_fronts.gd").new()

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--breeze="): breeze_gain = float(arg.get_slice("=", 1))
		if arg.begins_with("--fronts="): fronts.gain = float(arg.get_slice("=", 1))
var _fog_material: ShaderMaterial
var _environment: Environment
var wind_trails: Node3D

## The air drawn: painterly breeze ribbons riding the flow and the gust
## fronts (scripts/breeze_ribbons.gd); `--old-trails` brings back the earlier
## stamped trails (scripts/weather_wind_trails.gd) to compare.
func setup_wind_trails(probe: Callable, old := OS.get_cmdline_user_args().has("--old-trails")) -> void:
	if wind_trails != null: return
	wind_trails = (preload("res://scripts/weather_wind_trails.gd") if old else preload("res://scripts/breeze_ribbons.gd")).new()
	add_child(wind_trails)
	wind_trails.setup(probe)
	if wind_trails.has_method("set_bounds"): wind_trails.set_bounds(fronts.center, fronts.radius)

func setup(geometry: Node3D, environment: Environment) -> void:
	setup_ground(geometry.get_node("terrain"), environment)

func setup_ground(terrain: MeshInstance3D, environment: Environment, use_reference_bounds := true) -> void:
	_environment = environment
	update_ground_bounds(terrain, use_reference_bounds)
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		_add_fog()

func update_ground_bounds(terrain: MeshInstance3D, use_reference_bounds := false) -> void:
	_ground_min = INF
	_summit = Vector3(0, -INF, 0)
	var low := Vector2(INF, INF)
	var high := -low
	var placed := terrain.global_transform if terrain.is_inside_tree() else terrain.transform
	for vertex: Vector3 in terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point := terrain.transform * vertex
		_ground_min = minf(_ground_min, point.y)
		if point.y > _summit.y:
			_summit = point
		var seen := placed * vertex
		low = low.min(Vector2(seen.x, seen.z))
		high = high.max(Vector2(seen.x, seen.z))
	# Gust fronts roll across the plate as the world sees it.
	fronts.set_bounds((low + high) * 0.5, (high - low).length() * 0.5)
	if wind_trails != null and wind_trails.has_method("set_bounds"): wind_trails.set_bounds(fronts.center, fronts.radius)
	if use_reference_bounds:
		var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/environment.json"))
		var summit: Array = reference.uSummit
		_summit = Vector3(summit[0], summit[1], summit[2])
		_ground_min = reference.uGroundRange[0]
	var fog := get_node_or_null("ValleyFog") as FogVolume
	if fog != null:
		fog.size = Vector3(Plate.SIZE, _summit.y - _ground_min + 10.0, Plate.SIZE)
		fog.position = Vector3(0.0, _ground_min - 0.5 + fog.size.y * 0.5, 0.0)
		_fog_material.set_shader_parameter("floor_height", _ground_min)
	_publish_wind()

func advance(delta: float, paused: bool) -> void:
	# The hour moves while paused too (scrubbing), so the mist follows it.
	day_mist = _day_mist()
	if paused:
		_publish_fog()
		_publish_wind()
		return
	# Integrating travel avoids the noise pattern jumping when the dial changes.
	var response := 1.0 - exp(-delta * weather_response)
	_air_strength = lerpf(_air_strength, strength, response)
	fog_amount = lerpf(fog_amount, _fog_target, response)
	haze_amount = lerpf(haze_amount, _haze_target, response)
	_publish_fog()
	_air_angle = lerp_angle(_air_angle, deg_to_rad(direction_angle), response)
	var direction := Vector2(cos(_air_angle), sin(_air_angle))
	var velocity := direction * (1.6 + 1.9 * _air_strength)
	_travel += velocity * delta
	_gust_distance += (1.6 + 1.9 * _air_strength) * delta
	_wind_time += delta
	var cloud_speed := (0.0016 + _air_strength * 0.0022) * delta * 60.0
	_cloud_drift -= Vector3(direction.x, 0, direction.y) * cloud_speed
	_cloud_drift.y += delta * 0.004
	if wind_trails != null: wind_trails.advance(delta,_air_strength*gust_at(_wind_time),_air_angle)
	puffs.retire(_gust_distance)
	var sent: int = fronts.sent
	fronts.advance(delta, direction, _air_strength, breeze_air(_air_strength + swell))
	if fronts.sent > sent and wind_trails != null and wind_trails.has_method("carry_front"):
		for front: Dictionary in fronts.fronts:
			if not front.is_empty() and float(front.age) <= delta + 0.001: wind_trails.carry_front(front)
	_publish_wind()

## `strength` is the puff's weight (wind_puffs.gd); 0.45 is a full gust.
func send_gust(center: Vector3, strength := 0.45) -> void:
	var direction := Vector2(cos(_air_angle), sin(_air_angle))
	puffs.puff(Vector2(center.x, center.z), direction, _gust_distance, _air_strength, strength)
	_publish_wind()

## What the hour leaves of the ground mist: thin by day and through golden
## hour, whole at dawn, after dusk, by night, on cold mornings and in misty
## weather.
func _day_mist() -> float:
	var window := EVENING_MIST_SUN if sun_setting else DAY_MIST_SUN.lerp(DAY_MIST_COLD_SUN, clampf(cold, 0.0, 1.0))
	var day := smoothstep(window.x, window.y, sun_height)
	day *= 1.0 - smoothstep(DAY_MIST_WEATHER.x, DAY_MIST_WEATHER.y, fog_amount)
	return lerpf(1.0, DAY_MIST_FLOOR, day)

## The ground mist the air draws: fog_amount thinned by the hour.
func ground_mist() -> float:
	return fog_amount * day_mist

func set_fog(value: float) -> void:
	fog_amount = value
	_fog_target = value
	_publish_fog()

func _publish_wind() -> void:
	var humidity := minf(1.0, cloud * 0.9 + fog_amount * 0.45 + rain * 0.5)
	var relief := smoothstep(4.5, 8.5, _summit.y - _ground_min)
	var orographic := relief * smoothstep(0.12, 0.65, humidity) * smoothstep(0.25, 1.0, _air_strength) * (1.0 - shroud) * summit_mist
	RenderingServer.global_shader_parameter_set("zs_summit", Vector4(_summit.x, _summit.y, _summit.z, orographic))
	RenderingServer.global_shader_parameter_set("zs_condensation", _summit.y + 1.5 - 6.0 * smoothstep(0.3, 1.0, humidity))
	RenderingServer.global_shader_parameter_set("zs_cloud_drift", _cloud_drift)
	RenderingServer.global_shader_parameter_set("zs_wind_strength", (_air_strength + swell) * gust_at(_wind_time))
	RenderingServer.global_shader_parameter_set("zs_wind_direction", Vector2(cos(_air_angle), sin(_air_angle)))
	RenderingServer.global_shader_parameter_set("zs_wind_offset", _travel)
	RenderingServer.global_shader_parameter_set("zs_gust_distance", _gust_distance)
	RenderingServer.global_shader_parameter_set("zs_gust_speed", 1.6 + 1.9 * _air_strength)
	RenderingServer.global_shader_parameter_set("zs_breeze", breeze())
	puffs.publish()
	fronts.publish()

## What `zs_breeze` is now: the eased air (and the hand's swell) lifted to
## the floor, breathing on the wind clock, which holds while paused, and
## going quiet before a gust front (GustFronts `lull`).
func breeze() -> float:
	return breeze_air(_air_strength + swell) * breeze_swell(_wind_time) * fronts.lull() * breeze_gain

## The air's strength lifted to BREEZE_FLOOR: about 0.38 for a calm world,
## 0.53 for the default 0.4, 1.35 for a gale's 1.3.
static func breeze_air(air: float) -> float:
	var a := maxf(air, 0.0)
	return sqrt(a * a + BREEZE_FLOOR * BREEZE_FLOOR)

## The breeze's slow breathing at `t` s on the wind clock: 1 on average,
## from 0.6 in the deepest lull to 1.4 at the fullest swell.
static func breeze_swell(t: float) -> float:
	var value := 1.0
	for swell_term: Vector3 in BREEZE_SWELLS:
		value += swell_term.y * sin(TAU * t / swell_term.x + swell_term.z)
	return value

func _add_fog() -> void:
	_environment.volumetric_fog_enabled = native_volume
	_environment.volumetric_fog_density = 0.0
	_environment.volumetric_fog_length = 65.0
	_environment.volumetric_fog_albedo = Color(0.74, 0.80, 0.87)
	_environment.volumetric_fog_anisotropy = 0.45
	_environment.volumetric_fog_ambient_inject = 0.35
	_environment.volumetric_fog_sky_affect = 1.0
	_fog_material = ShaderMaterial.new()
	_fog_material.shader = preload("res://shaders/reference_fog.gdshader")
	var fog := FogVolume.new()
	fog.name = "ValleyFog"
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog.size = Vector3(Plate.SIZE, _summit.y - _ground_min + 10.0, Plate.SIZE)
	fog.position = Vector3(0.0, _ground_min - 0.5 + fog.size.y * 0.5, 0.0)
	fog.material = _fog_material
	add_child(fog)
	set_fog(fog_amount)

func set_ground_texture(texture: Texture2D, stream: Texture2D) -> void:
	if _fog_material != null:
		_fog_material.set_shader_parameter("ground_map", texture)
		_fog_material.set_shader_parameter("stream_map", stream)
		_fog_material.set_shader_parameter("floor_height", _ground_min)

func set_rays(value: float) -> void:
	ray_strength = value
	if _fog_material != null:
		_fog_material.set_shader_parameter("rays", value)

# Source weather.js gustAt: the strength dial breathes independently of spatial patches.
static func gust_at(t: float) -> float:
	return 0.68 + 0.22 * sin(t * 0.31) + 0.14 * sin(t * 0.73 + 1.7) + 0.09 * sin(t * 1.9 + 0.4) + 0.07 * sin(t * 3.7 + 2.2)

func set_inversion(value: float) -> void:
	inversion_amount = value
	if _fog_material != null:
		_environment.volumetric_fog_enabled = native_volume and (fog_amount > 0.001 or haze_amount > 0.001 or value > 0.001)

func set_haze(value: float) -> void:
	haze_amount = value
	_haze_target = value
	_publish_fog()

func set_weather_profile(profile: Dictionary, instant := false) -> void:
	strength = profile.wind
	_fog_target = profile.mist
	_haze_target = profile.haze
	if instant:
		_air_strength = strength
		fog_amount = _fog_target
		haze_amount = _haze_target
		_publish_fog()

func _publish_fog() -> void:
	RenderingServer.global_shader_parameter_set("zs_haze", haze_amount)
	if _fog_material != null:
		_fog_material.set_shader_parameter("density", ground_mist())
		_fog_material.set_shader_parameter("haze", haze_amount)
		_environment.volumetric_fog_enabled = native_volume and (fog_amount > 0.001 or haze_amount > 0.001 or inversion_amount > 0.001)
