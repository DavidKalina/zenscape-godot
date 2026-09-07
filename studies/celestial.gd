extends RefCounted
## Mountain preset and celestial curves ported from presets.js/daynight.js.
## Lighting, sky and reflected sky read the same state.

var fog_display := Vector3.ZERO
var surface_fog_color := Vector3.ZERO
var aerial_sun_color := Vector3.ZERO
var phase := 0.35
var daylight := 1.0
var cloud := 0.06
var storm := 0.0
var shroud := 0.0
var cycling := false
var aurora_strength := 0.65
var rainbow_strength := 0.0
var weather_bow := 0.0
var alpen_enabled := true
var inversion_enabled := true
var wind := 0.4
var autumn := 0.0
var cold := 0.0
var night_fill := 1.0
var state: Dictionary = {}
var _rainbow_growth := 0.0
var _target := -1.0
var _sun: DirectionalLight3D
var _rim: DirectionalLight3D
var _tilt := 0.0
var _yaw := atan2(20.0, 12.0)

func setup(lights: Array[DirectionalLight3D]) -> void:
	_sun = lights[0]
	_rim = lights[1]
	var elevation := asin(14.0 / Vector3(20, 14, 12).length())
	_tilt = PI / 2.0 - clampf(elevation + 0.32, 0.7, 1.08)
	update_rig()

func set_phase(value: float) -> void:
	phase = fposmod(value, 1.0)
	_target = -1.0
	update_rig()

func next_hour() -> void:
	var current := _target if _target >= 0.0 else phase
	var nearest := INF
	for quarter in [0.25, 0.5, 0.75, 0.0]:
		var gap := fposmod(quarter - current, 1.0)
		if gap > 0.03 and gap < nearest:
			nearest = gap
			_target = quarter

func advance(delta: float, paused: bool) -> void:
	if paused:
		# Freeze the clock, not explicit cloud/aurora/material edits.
		update_rig()
		return
	if _target >= 0.0:
		var gap := fposmod(_target - phase, 1.0)
		if gap < 0.001:
			phase = _target
			_target = -1.0
		else:
			phase = fposmod(phase + gap * (1.0 - exp(-delta * 1.6)), 1.0)
	elif cycling:
		var elevation := sin((phase - 0.25) * TAU) * cos(_tilt)
		var linger := 1.0 - 0.5 * exp(-elevation * elevation / (2.0 * 0.09 * 0.09))
		phase = fposmod(phase + delta / 480.0 * linger, 1.0)
	_rainbow_growth = move_toward(_rainbow_growth, 1.0 if maxf(rainbow_strength, weather_bow) > 0.04 else 0.0, delta / 6.0)
	update_rig()

func update_rig() -> void:
	var theta := (phase - 0.25) * TAU
	var sun := _ring_direction(theta, _tilt)
	var moon := _ring_direction(theta + PI, _tilt * 0.75)
	var e := sun.y
	var day := smoothstep(-0.06, 0.28, e)
	daylight = day
	var night := 1.0 - smoothstep(-0.16, 0.02, e)
	var warmth := exp(-e * e / (2.0 * 0.13 * 0.13))
	var sun_energy := 3.4 * smoothstep(-0.03, 0.10, e) * (0.45 + 0.55 * smoothstep(0.08, 0.45, e))
	var moon_energy := 3.4 * 0.11 * smoothstep(0.02, 0.30, moon.y) * night
	var tint := _rgb("ffcf8f").lerp(Vector3(1, 0.97, 0.9), smoothstep(0.35, 0.9, e) * 0.5)
	tint = _rgb("ff6222").lerp(_rgb("ffb45c"), smoothstep(-0.02, 0.1, e)).lerp(tint, smoothstep(0.1, 0.4, e))
	var key_direction := sun
	var energy := sun_energy
	if moon_energy > sun_energy:
		key_direction = moon
		energy = moon_energy
		tint = _rgb("b9cae8")
	var overcast := lerpf(1.0, 0.44, cloud) * lerpf(1.0, 0.8, storm) * lerpf(1.0, 0.86, shroud) * lerpf(1.0, 0.92, cold)
	_sun.position = key_direction * Vector3(20, 14, 12).length()
	_sun.look_at(Vector3.ZERO)
	_sun.light_energy = energy * overcast / PI
	_sun.light_color = _color(tint.lerp(Vector3(0.78, 0.84, 0.95), cloud * 0.7).lerp(Vector3(1.0, 0.70, 0.38), autumn * 0.35).lerp(Vector3(0.82, 0.88, 1.0), cold * 0.4)).linear_to_srgb()
	var ambient := smoothstep(-0.12, 0.10, e)
	var hemi_sky := _rgb("26324e").lerp(_rgb("8fb3d9"), ambient).lerp(_rgb("7d92bd"), warmth * 0.5)
	hemi_sky = hemi_sky.lerp(Vector3(0.5, 0.55, 0.62), cloud * 0.6).lerp(Vector3(0.66, 0.58, 0.46), autumn * 0.3).lerp(Vector3(0.62, 0.70, 0.85), cold * 0.35)
	var hemi_ground := _rgb("0d1016").lerp(_rgb("4a5240"), day)
	_rim.light_energy = 1.1 * (0.3 + 0.7 * day) * lerpf(1.0, 0.5, cloud) / PI
	_publish("zs_key_direction", _sun.global_basis.z.normalized())
	var key_color := _sun.light_color.srgb_to_linear()
	_publish("zs_key_irradiance", Vector3(key_color.r, key_color.g, key_color.b) * _sun.light_energy * PI)
	_publish("zs_rim_direction", _rim.global_basis.z.normalized())
	var rim_color := _rim.light_color.srgb_to_linear()
	_publish("zs_rim_irradiance", Vector3(rim_color.r, rim_color.g, rim_color.b) * _rim.light_energy * PI)
	_publish("zs_cloud_direction", key_direction)
	_publish("zs_cloud_sun", tint.lerp(Vector3(0.78, 0.84, 0.95), cloud * 0.7).lerp(Vector3(1.0, 0.70, 0.38), autumn * 0.35).lerp(Vector3(0.82, 0.88, 1.0), cold * 0.4) * (0.9 + 0.5 * overcast))
	_publish("zs_cloud_sky", hemi_sky * 0.55)
	# Native night adaptation: a cool surface fill keeps the miniature readable.
	# Keep sky/cloud/fog colors independent so stars retain their dark backdrop.
	var fill := night * night_fill * lerpf(1.0, 0.4, storm)
	_publish("zs_hemi_sky", hemi_sky + Vector3(0.22, 0.28, 0.4) * fill)
	_publish("zs_hemi_ground", hemi_ground + Vector3(0.08, 0.1, 0.13) * fill)
	_publish("zs_hemi_energy", 0.55 * (0.22 + 0.78 * ambient) * lerpf(1.0, 1.25, cloud) * lerpf(1.0, 0.55, storm) + 0.4 * fill)
	var down := Vector3(0.006, 0.009, 0.016).lerp(Vector3(0.055, 0.07, 0.1), day)
	var up := Vector3(0.01, 0.016, 0.038).lerp(Vector3(0.1, 0.14, 0.24), day).lerp(Vector3(0.1, 0.07, 0.16), warmth * 0.55)
	var glow := Vector3(0.016, 0.024, 0.045).lerp(Vector3(0.3, 0.18, 0.14), day).lerp(Vector3(0.85, 0.3, 0.09), warmth * 0.8)
	var sky_dim := clampf(up.dot(Vector3(0.2126, 0.7152, 0.0722)) / 0.14, 0.08, 1.0)
	var cover := minf(1.0, cloud * 1.15)
	# Weather tint targets from weather.js; applied after the hour, as in the source.
	down = down.lerp(Vector3(0.052, 0.058, 0.066) * sky_dim, cover).lerp(Vector3(0.022, 0.024, 0.028) * sky_dim, storm)
	up = up.lerp(Vector3(0.085, 0.096, 0.112) * sky_dim, cover).lerp(Vector3(0.034, 0.038, 0.046) * sky_dim, storm)
	glow = glow.lerp(Vector3(0.085, 0.085, 0.090) * sky_dim, cover).lerp(Vector3(0.040, 0.042, 0.048) * sky_dim, storm)
	_publish("zs_sky_down", down)
	_publish("zs_sky_up", up)
	_publish("zs_sky_glow", glow)
	_publish("zs_sun_direction", sun)
	_publish("zs_moon_direction", moon)
	_publish("zs_moon_shadow_direction", (moon - sun * 0.028).normalized())
	var clear := 1.0 - minf(1.0, cloud * 1.4)
	var alpen := smoothstep(0.13, 0.07, e) * smoothstep(-0.14, -0.07, e) * clear
	var afterglow := smoothstep(0.03, -0.02, e) * smoothstep(-0.13, -0.05, e) * clear
	_publish("zs_alpen", Vector3(alpen if alpen_enabled else 0.0, smoothstep(0.10, -0.04, e), afterglow if alpen_enabled else 0.0))
	var alpen_dir := Vector3(sun.x, 0.0, sun.z).normalized()
	alpen_dir.y = 0.22
	_publish("zs_alpen_direction", alpen_dir.normalized())
	var rising := smoothstep(-0.15, 0.15, cos(theta))
	var still := 1.0 - smoothstep(0.9, 1.9, wind)
	var inversion := clear * rising * still * smoothstep(-0.22, -0.09, e) * (1.0 - smoothstep(0.05, 0.24, e))
	var inv_line := 0.21 - 0.16 * smoothstep(0.0, 0.24, e)
	_publish("zs_inversion", Vector2(inversion if inversion_enabled else 0.0, inv_line))
	var low := 0.15
	var high := 12.6268235
	var band := maxf(0.8, 0.08 * (high - low))
	var lid := lerpf(low, high, inv_line)
	var shade_line := lerpf(low - band, high + band, smoothstep(0.10, -0.04, e))
	var sun_on := lerpf(1.0, smoothstep(shade_line - band * 0.5, shade_line + band * 0.5, lid), alpen)
	var sun_k := minf(1.0, energy / 2.0)
	var fog_color := (hemi_sky * 0.55 * 1.7).lerp(Vector3(0.30, 0.33, 0.38), storm * 0.6).lerp(Vector3(0.72, 0.66, 0.54), autumn * 0.35).lerp(Vector3(0.62, 0.68, 0.78), cold * 0.45)
	fog_display = source_display_fog(fog_color, 1.15)
	var display_color := Color(fog_color.x, fog_color.y, fog_color.z).linear_to_srgb()
	surface_fog_color = Vector3(display_color.r, display_color.g, display_color.b)
	var aerial_warmth := 0.6 * smoothstep(-0.02, 0.18, key_direction.y) * (1.0 - 0.85 * cloud) * (1.0 - storm)
	aerial_sun_color = fog_color.lerp(fog_color * Vector3(1.22, 1.06, 0.84), aerial_warmth)
	var inv_color := source_display_fog(fog_color.lerp(state.zs_cloud_sun, 0.35 * sun_on * sun_k), 1.15)
	_publish("zs_inversion_color", inv_color.lerp(Vector3.ONE, 0.38 * sun_on * sun_k))
	_publish("zs_night", night)
	_publish("zs_daylight", day)
	_publish("zs_celestial_clear", 1.0 - minf(1.0, cloud * 1.3))
	_publish("zs_dusk_direction", warmth * 0.9)
	_publish("zs_belt", smoothstep(0.06, -0.01, e) * smoothstep(-0.14, -0.06, e) * (1.0 - minf(1.0, cloud * 1.3)))
	_publish("zs_aurora", Vector4(aurora_strength, 1.0, 0.15, -1.2))
	_publish("zs_bow", maxf(rainbow_strength, weather_bow) * smoothstep(-0.03, 0.1, e))
	_publish("zs_bow_grow", _rainbow_growth)
	_publish("zs_bow_shape", Vector2.ONE)

func _ring_direction(theta: float, tilt: float) -> Vector3:
	var x := cos(theta)
	var y := sin(theta) * cos(tilt)
	var z := sin(theta) * sin(tilt)
	return Vector3(x * cos(_yaw) + z * sin(_yaw), y, -x * sin(_yaw) + z * cos(_yaw))

func _rgb(hex: String) -> Vector3:
	var color := Color(hex).srgb_to_linear()
	return Vector3(color.r, color.g, color.b)

func _color(value: Vector3) -> Color:
	return Color(value.x, value.y, value.z)

func _publish(key: StringName, value: Variant) -> void:
	state[key] = value
	RenderingServer.global_shader_parameter_set(key, value)

# weather.js displayFog: source ACES and sRGB, before native volume adaptation.
static func source_display_fog(color: Vector3, exposure: float) -> Vector3:
	var c := color * (exposure / 0.6)
	var v := Vector3(Vector3(0.59719, 0.35458, 0.04823).dot(c), Vector3(0.076, 0.90834, 0.01566).dot(c), Vector3(0.02840, 0.13383, 0.83777).dot(c))
	for i in range(3):
		v[i] = (v[i] * (v[i] + 0.0245786) - 0.000090537) / (v[i] * (0.983729 * v[i] + 0.432951) + 0.238081)
	var mapped := Vector3(Vector3(1.60475, -0.53108, -0.07367).dot(v), Vector3(-0.10208, 1.10813, -0.00605).dot(v), Vector3(-0.00327, -0.07276, 1.07602).dot(v)).clamp(Vector3.ZERO, Vector3.ONE)
	var srgb := Color(mapped.x, mapped.y, mapped.z).linear_to_srgb()
	return Vector3(srgb.r, srgb.g, srgb.b)
