extends RefCounted
## Mountain preset and celestial curves ported from presets.js/daynight.js.
## Lighting, sky and reflected sky read the same state.

var look := preload("res://scripts/scene_look.gd").new()

var fog_display := Vector3.ZERO
var surface_fog_color := Vector3.ZERO
var aerial_sun_color := Vector3.ZERO
## World time. When a WorldClock is attached it owns `phase` and `cycling`
## outright: both become aliases of the clock, so presets, the store, the look
## editor and the day/night checkbox all keep writing the same names and reach
## the clock instead. Without a clock (studies that never build one) the old
## self-integrating behaviour is used unchanged.
var clock: WorldClock = null
var _phase := 0.35
var phase: float:
	set(value):
		if clock != null: clock.set_phase(value)
		else: _phase = fposmod(value, 1.0)
	get:
		return clock.phase if clock != null else _phase
var daylight := 1.0
var cloud := 0.06
var storm := 0.0
var shroud := 0.0
var _cycling := true
var cycling: bool:
	set(value):
		_cycling = value
		if clock != null: clock.running = value
	get:
		return clock.running if clock != null else _cycling
## The look's own aurora (sliders, moods, presets): a floor under the natural
## one, which comes on its own on clear winter nights (`_aurora`).
var aurora_strength := 0.0
var rainbow_strength := 0.0
var weather_bow := 0.0
## A rainbow that life calls after rain over a rich place (scripts/life_moments.gd).
var moment_bow := 0.0
## A moonbow that life calls after night rain under a near-full moon.
var moon_bow := 0.0
## 1 on a double rainbow: brings the fainter second bow up (life_moments.gd).
var moment_bow_double := 0.0
var alpen_enabled := true
var inversion_enabled := true
var wind := 0.4
var autumn := 0.0
var cold := 0.0
var night_fill := 1.0
## How far night leaves daylight's colours behind (the grade's cool, washed
## rod-lit look, `night_grade`): 1 is the full night look, 0 keeps the day's
## colours in the dark. Moods can set it like night_fill.
var night_look := 1.0
## The grade's night term for scripts/look_pass.gd: x how much of the land's
## colour gives way to a cool rod-lit grey, yzw that grey's hue at unit
## luminance. Zero by day; it rises after the afterglow and falls before dawn.
var night_grade := Vector4.ZERO
var state: Dictionary = {}
var _rainbow_growth := 0.0
var _target := -1.0
var _sun: DirectionalLight3D
var _rim: DirectionalLight3D
var _tilt := 0.0
var _yaw := atan2(20.0, 12.0)
## The room's turn (radians about the vertical, anticlockwise seen from above)
## under which the diorama spins (docs/scenic/hand-turn.md, "A fixed room"):
## scripts/world_turn.gd sets it to follow the camera's yaw, so the sun and
## moon ring, both lights, the stars, the aurora and the horizon keep their
## bearing to the camera while the land turns. Zero leaves everything where
## the source put it (`--classic-orbit`, the studies, the captures).
var room_yaw := 0.0
## A shimmer of the key light (0..1) that scripts/spin_time.gd raises as a
## spinning world nears the speed that winds time, and lowers as it runs on.
var shimmer := 0.0
## The rim light's orientation as set up, before the room's turn.
var _rim_basis := Basis.IDENTITY
var _rim_turned := 0.0

## Moon phases: a lunar month of LUNAR_DAYS world days. Age 0 is full and 0.5
## new; the moon falls a turn behind the sun each month, so it rises later
## every night. A fresh world opens LUNAR_START into the month (waxing
## gibbous). Without a clock the moon stays full, where it always stood.
const LUNAR_DAYS := 8.0
const LUNAR_START := 0.85
## Moonlight at new and full moon, as a share of the old fixed moon. A full
## moon is a readable key over the fill, so its shadows and lit faces show.
const MOON_LIGHT := Vector2(0.1, 2.0)
## The night fill leans on the moon: this at new, this at full.
const MOON_FILL := Vector2(0.7, 1.0)
## Moonlight's colour at new and full moon: a thin dim blue under a sliver,
## brighter silver-blue under a full moon (the source's b9cae8 sits between).
const MOON_TINT := ["8a9ac4", "c4d3f4"]
## The night fill's colour per unit of fill: a deep blue leaning teal, so
## shaded land goes cool against the moonlit faces.
const NIGHT_FILL := Vector3(0.11, 0.18, 0.32)
## The night look (`night_grade`): the share of colour lost to rod vision under
## a new and a full moon, and the hue left, new and full. Under a new moon it
## is deeper and darker; a full moon keeps a little more colour, silver-blue.
const NIGHT_GRADE := Vector2(0.8, 0.62)
const NIGHT_HUE_NEW := Vector3(0.64, 0.92, 1.5)
const NIGHT_HUE_FULL := Vector3(0.8, 0.98, 1.3)
## Sun heights (sun.y) over which the night look comes in: after the
## afterglow and the belt, so golden hour and dusk keep their colour.
const NIGHT_LOOK_E := Vector2(-0.2, -0.03)
## Aurora: each night rolls once, with this chance by the season it falls in
## (winter, late autumn from AURORA_LATE_AUTUMN, and the rest of the year).
const AURORA_CHANCE := Vector3(0.5, 0.2, 0.025)
const AURORA_LATE_AUTUMN := 0.62
## A chosen night's strength, its onset in hours after noon, and how long it
## burns (hours); it never runs past AURORA_DAWN hours after noon.
const AURORA_STRENGTH := Vector2(0.35, 1.15)
const AURORA_ONSET := Vector2(7.0, 11.0)
const AURORA_HOURS := Vector2(4.0, 9.0)
const AURORA_DAWN := 17.5
## Real seconds to fade from nothing to the strongest aurora.
const AURORA_FADE := 150.0
## Cloud cover over which it fades out; only a clear sky shows it.
const AURORA_CLOUD := Vector2(0.12, 0.3)
const AURORA_SEED := 7121
## Lunar age now (0 full, 0.5 new) and the lit share of the disc.
var moon_age := 0.0
var moon_lit := 1.0
var _aurora := 0.0
var _aurora_night := -1
var _aurora_plan := Vector3.ZERO

func setup(lights: Array[DirectionalLight3D]) -> void:
	look.publish()
	_sun = lights[0]
	_rim = lights[1]
	_rim_basis = _rim.global_basis
	var elevation := asin(14.0 / Vector3(20, 14, 12).length())
	_tilt = PI / 2.0 - clampf(elevation + 0.32, 0.7, 1.08)
	update_rig()

## Hand time over to the world clock, seeding it with the hour this rig is
## already showing so nothing jumps at startup.
func attach_clock(value: WorldClock) -> void:
	clock = value
	clock.set_phase(_phase)
	clock.running = _cycling
	_target = -1.0
	update_rig()

func set_phase(value: float) -> void:
	phase = fposmod(value, 1.0)
	_target = -1.0
	if clock != null: clock.target_hour = -1.0
	update_rig()

func next_hour() -> void:
	if clock != null:
		var from: float = clock.target_hour if clock.target_hour >= 0.0 else clock.hour
		var closest := INF
		var choice := -1.0
		for quarter in [6.0, 12.0, 18.0, 0.0]:
			var step := fposmod(quarter - from, 24.0)
			if step > 0.72 and step < closest:
				closest = step
				choice = quarter
		if choice >= 0.0: clock.skip_to(choice)
		return
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
	if clock != null:
		# The clock already advanced this frame; phase is read from it, linger
		# and all. Nothing here integrates time.
		pass
	elif _target >= 0.0:
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
	_aurora = move_toward(_aurora, _aurora_target(), delta * AURORA_STRENGTH.y / AURORA_FADE)
	_rainbow_growth = move_toward(_rainbow_growth, 1.0 if maxf(maxf(rainbow_strength, weather_bow), moment_bow) > 0.04 else 0.0, delta / 6.0)
	update_rig()

func update_rig() -> void:
	var theta := (phase - 0.25) * TAU
	var sun := _ring_direction(theta, _tilt)
	moon_age = lunar_age()
	moon_lit = 0.5 + 0.5 * cos(moon_age * TAU)
	var moon := moon_direction(phase)
	var e := sun.y
	var day := smoothstep(-0.06, 0.28, e)
	daylight = day
	var night := 1.0 - smoothstep(-0.16, 0.02, e)
	var warmth := exp(-e * e / (2.0 * 0.13 * 0.13))
	var sun_energy := 3.4 * smoothstep(-0.03, 0.10, e) * (0.45 + 0.55 * smoothstep(0.08, 0.45, e))
	var moon_up := smoothstep(0.02, 0.30, moon.y)
	var moon_energy := 3.4 * 0.11 * moon_up * night * lerpf(MOON_LIGHT.x, MOON_LIGHT.y, moon_lit)
	# How much moon there is to see by (phase and height), and how deep into
	# the night the look has gone.
	var moon_glow := moon_lit * moon_up
	var dark := 1.0 - smoothstep(NIGHT_LOOK_E.x, NIGHT_LOOK_E.y, e)
	var moon_tint := _rgb(MOON_TINT[0]).lerp(_rgb(MOON_TINT[1]), moon_lit)
	var tint := look.rgb("sun").lerp(Vector3(1, 0.97, 0.9), smoothstep(0.35, 0.9, e) * 0.5)
	tint = _rgb("ff6222").lerp(_rgb("ffb45c"), smoothstep(-0.02, 0.1, e)).lerp(tint, smoothstep(0.1, 0.4, e))
	var key_direction := sun
	var energy := sun_energy
	if moon_energy > sun_energy:
		key_direction = moon
		energy = moon_energy
		tint = moon_tint
	var overcast := lerpf(1.0, 0.44, cloud) * lerpf(1.0, 0.8, storm) * lerpf(1.0, 0.86, shroud) * lerpf(1.0, 0.92, cold)
	_sun.position = key_direction * Vector3(20, 14, 12).length()
	_sun.look_at(Vector3.ZERO)
	_sun.light_energy = energy * overcast / PI * look.settings.sun_energy
	if shimmer > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		_sun.light_energy *= 1.0 + shimmer * 0.16 * (0.5 * sin(t * 37.0) + 0.5 * sin(t * 23.0 + 1.3))
	_sun.light_color = _color(tint.lerp(Vector3(0.78, 0.84, 0.95), cloud * 0.7).lerp(Vector3(1.0, 0.70, 0.38), autumn * 0.35).lerp(Vector3(0.82, 0.88, 1.0), cold * 0.4)).linear_to_srgb()
	var ambient := smoothstep(-0.12, 0.10, e)
	var hemi_sky := _rgb("26324e").lerp(_rgb("8fb3d9"), ambient).lerp(_rgb("7d92bd"), warmth * 0.5)
	hemi_sky *= look.ratio("ambient")
	hemi_sky = hemi_sky.lerp(Vector3(0.5, 0.55, 0.62), cloud * 0.6).lerp(Vector3(0.66, 0.58, 0.46), autumn * 0.3).lerp(Vector3(0.62, 0.70, 0.85), cold * 0.35)
	var hemi_ground := _rgb("0d1016").lerp(_rgb("4a5240"), day)
	hemi_ground *= look.ratio("bounce")
	if _rim_turned != room_yaw:
		_rim.global_basis = Basis(Vector3.UP, room_yaw) * _rim_basis
		_rim_turned = room_yaw
	# The rim's night floor follows the moon: a new moon leaves silhouettes.
	_rim.light_energy = 1.1 * (lerpf(0.3, lerpf(0.12, 0.3, moon_glow), dark) + 0.7 * day) * lerpf(1.0, 0.5, cloud) / PI
	_publish("zs_key_direction", _sun.global_basis.z.normalized())
	var key_color := _sun.light_color.srgb_to_linear()
	_publish("zs_key_irradiance", Vector3(key_color.r, key_color.g, key_color.b) * _sun.light_energy * PI)
	_publish("zs_rim_direction", _rim.global_basis.z.normalized())
	_rim.light_color = _color(look.rgb("rim")).linear_to_srgb()
	var rim_color := _rim.light_color.srgb_to_linear()
	_publish("zs_rim_irradiance", Vector3(rim_color.r, rim_color.g, rim_color.b) * _rim.light_energy * PI)
	_publish("zs_cloud_direction", key_direction)
	var cloud_sun := tint.lerp(Vector3(0.78, 0.84, 0.95), cloud * 0.7).lerp(Vector3(1.0, 0.70, 0.38), autumn * 0.35).lerp(Vector3(0.82, 0.88, 1.0), cold * 0.4) * (0.9 + 0.5 * overcast)
	# The source lights air and cloud with the key's colour at full strength
	# even when nothing is up. At night that left the mist lit like day (and
	# orange under a new moon): lean it on the moon instead.
	cloud_sun = cloud_sun.lerp(moon_tint.lerp(Vector3(0.78, 0.84, 0.95), cloud * 0.7) * lerpf(0.12, 0.85, moon_glow) * (0.9 + 0.5 * overcast), dark)
	_publish("zs_cloud_sun", cloud_sun)
	_publish("zs_cloud_sky", hemi_sky * 0.55)
	# Native night adaptation: a cool surface fill keeps the miniature readable.
	# Keep sky/cloud/fog colors independent so stars retain their dark backdrop.
	var fill := night * night_fill * lerpf(1.0, 0.4, storm) * lerpf(MOON_FILL.x, MOON_FILL.y, moon_glow)
	_publish("zs_hemi_sky", hemi_sky + NIGHT_FILL * fill)
	_publish("zs_hemi_ground", hemi_ground + Vector3(0.08, 0.1, 0.13) * fill)
	_publish("zs_hemi_energy", (0.55 * (0.22 + 0.78 * ambient) * lerpf(1.0, 1.25, cloud) * lerpf(1.0, 0.55, storm) + 0.4 * fill) * look.settings.ambient_energy)
	var down := Vector3(0.006, 0.009, 0.016).lerp(Vector3(0.055, 0.07, 0.1), day)
	var up := Vector3(0.01, 0.016, 0.038).lerp(Vector3(0.1, 0.14, 0.24), day).lerp(Vector3(0.1, 0.07, 0.16), warmth * 0.55)
	var glow := Vector3(0.016, 0.024, 0.045).lerp(Vector3(0.3, 0.18, 0.14), day).lerp(Vector3(0.85, 0.3, 0.09), warmth * 0.8)
	down *= look.ratio("horizon")
	up *= look.ratio("sky")
	glow *= look.ratio("glow")
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
	fog_color *= look.ratio("fog")
	fog_display = source_display_fog(fog_color, 1.15 * look.settings.exposure)
	var display_color := Color(fog_color.x, fog_color.y, fog_color.z).linear_to_srgb()
	surface_fog_color = Vector3(display_color.r, display_color.g, display_color.b)
	var aerial_warmth := 0.6 * smoothstep(-0.02, 0.18, key_direction.y) * (1.0 - 0.85 * cloud) * (1.0 - storm)
	aerial_sun_color = fog_color.lerp(fog_color * Vector3(1.22, 1.06, 0.84), aerial_warmth)
	var inv_color := source_display_fog(fog_color.lerp(state.zs_cloud_sun, 0.35 * sun_on * sun_k), 1.15 * look.settings.exposure)
	_publish("zs_inversion_color", inv_color.lerp(Vector3.ONE, 0.38 * sun_on * sun_k))
	_publish("zs_night", night)
	# The night look: the grade's rod-lit shift, and moonlight for the sky cloud.
	var hue := NIGHT_HUE_NEW.lerp(NIGHT_HUE_FULL, moon_glow)
	var mood := look.ratio("ambient")
	hue *= Vector3.ONE.lerp(mood / maxf(mood.dot(Vector3(0.2126, 0.7152, 0.0722)), 0.0001), 0.5)
	var look_dark := dark * clampf(night_look, 0.0, 1.5)
	night_grade = Vector4(minf(look_dark * lerpf(NIGHT_GRADE.x, NIGHT_GRADE.y, moon_glow), 0.95), hue.x, hue.y, hue.z)
	var moonlight := moon_tint * moon_glow * night * lerpf(1.0, 0.35, cloud)
	_publish("zs_moon_light", Vector4(moonlight.x, moonlight.y, moonlight.z, look_dark))
	_publish("zs_daylight", day)
	_publish("zs_celestial_clear", 1.0 - minf(1.0, cloud * 1.3))
	_publish("zs_dusk_direction", warmth * 0.9)
	_publish("zs_belt", smoothstep(0.06, -0.01, e) * smoothstep(-0.14, -0.06, e) * (1.0 - minf(1.0, cloud * 1.3)))
	# The aurora's heading is a bearing, so the room's turn simply adds to it.
	_publish("zs_aurora", Vector4(maxf(aurora_strength, _aurora), 1.0, 0.15, -1.2 + room_yaw))
	_publish("zs_room_yaw", room_yaw)
	_publish("zs_bow", maxf(maxf(rainbow_strength, weather_bow), moment_bow) * smoothstep(-0.03, 0.1, e))
	_publish("zs_bow_grow", _rainbow_growth)
	_publish("zs_bow_shape", Vector2.ONE)
	_publish("zs_moonbow", moon_bow * night * smoothstep(-0.02, 0.08, moon.y))
	_publish("zs_bow_double", moment_bow_double)

## The moon's direction at a phase: half a day round from the sun on a flatter
## ring, less the turn it has fallen behind this far into the month.
func moon_direction(at_phase: float) -> Vector3:
	return _ring_direction((at_phase - 0.25) * TAU + PI - moon_age * TAU, _tilt * 0.75)

func lunar_age() -> float:
	if clock == null: return 0.0
	return fposmod((clock.day + clock.hour / WorldClock.HOURS_PER_DAY) / LUNAR_DAYS + LUNAR_START, 1.0)

## Where tonight's aurora is headed: a roll per night (noon to noon) by the
## season, a window of hours inside it, and a clear sky. Studies without a
## clock keep only the look's aurora.
func _aurora_target() -> float:
	if clock == null: return 0.0
	var night := clock.day + (1 if clock.hour >= 12.0 else 0)
	if night != _aurora_night:
		_aurora_night = night
		var rng := RandomNumberGenerator.new()
		rng.seed = night * 7919 + AURORA_SEED
		var season := clock.season
		var chance := AURORA_CHANCE.x if season >= 0.75 else (AURORA_CHANCE.y if season >= AURORA_LATE_AUTUMN else AURORA_CHANCE.z)
		var onset := rng.randf_range(AURORA_ONSET.x, AURORA_ONSET.y)
		var strength := rng.randf_range(AURORA_STRENGTH.x, AURORA_STRENGTH.y)
		var hours := rng.randf_range(AURORA_HOURS.x, AURORA_HOURS.y)
		_aurora_plan = Vector3(onset, minf(onset + hours, AURORA_DAWN), strength if rng.randf() < chance else 0.0)
	var after_noon := fposmod(clock.hour - 12.0, WorldClock.HOURS_PER_DAY)
	if after_noon < _aurora_plan.x or after_noon > _aurora_plan.y: return 0.0
	return _aurora_plan.z * smoothstep(AURORA_CLOUD.y, AURORA_CLOUD.x, cloud)

## A body's direction on its ring, turned by the room.
func _ring_direction(theta: float, tilt: float) -> Vector3:
	var x := cos(theta)
	var y := sin(theta) * cos(tilt)
	var z := sin(theta) * sin(tilt)
	var yaw := _yaw + room_yaw
	return Vector3(x * cos(yaw) + z * sin(yaw), y, -x * sin(yaw) + z * cos(yaw))

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

## CPU-owned trajectory shared with the sky shader and resident attention.
var meteor := {}
var _meteor_window := -1
var _meteor_start := Vector3.ZERO
var _meteor_tangent := Vector3.ZERO
var _meteor_fires := false
func sample_sky_motion(time: float) -> void:
	var window := floori(time/5.0)
	if window != _meteor_window:
		_meteor_window = window
		var rng := RandomNumberGenerator.new()
		rng.seed = window*7919+19237
		_meteor_fires = rng.randf()>0.45
		_meteor_start = Vector3(rng.randf()-0.5,rng.randf_range(-0.35,0.5),rng.randf()-0.5).normalized()
		_meteor_tangent = _meteor_start.cross(Vector3(rng.randf()-0.5,rng.randf()-0.5,rng.randf()-0.5)).normalized()
	var progress := (time-window*5.0)/0.9
	meteor = {}
	var head := Vector3.ZERO
	var tail := Vector3.ZERO
	var envelope := 0.0
	if _meteor_fires and progress<1.0:
		# The streak crosses the room's sky, so it turns with the room.
		head = (_meteor_start+_meteor_tangent*progress*0.45).normalized().rotated(Vector3.UP,room_yaw)
		tail = (_meteor_start+_meteor_tangent*maxf(progress-0.22,0.0)*0.45).normalized().rotated(Vector3.UP,room_yaw)
		envelope = smoothstep(0.0,0.1,progress)*(1.0-smoothstep(0.7,1.0,progress))
		if float(state.get("zs_night",0.0))*float(state.get("zs_celestial_clear",0.0))*envelope>0.08:
			meteor = {"window":window,"head":head,"tail":tail}
	RenderingServer.global_shader_parameter_set("zs_meteor_head",Vector4(head.x,head.y,head.z,envelope))
	RenderingServer.global_shader_parameter_set("zs_meteor_tail",tail)

func rainbow_direction() -> Vector3:
	var axis: Vector3 = -state.get("zs_sun_direction",Vector3.UP)
	var reference := Vector3.FORWARD if absf(axis.y)>0.999 else Vector3.UP
	var up := (reference-axis*reference.dot(axis)).normalized()
	# Follow the visible portion of the growing ring, then settle at its crown.
	var phi := minf(0.0,(_rainbow_growth-0.08)*TAU-PI)
	var rim := up*cos(phi)+axis.cross(up)*sin(phi)
	return (axis*cos(deg_to_rad(41.45))+rim*sin(deg_to_rad(41.45))).normalized()
