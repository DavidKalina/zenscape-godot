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
## The sun's height, the y of its direction (-1..1), as of the last update_rig.
var sun_height := 0.5
var cloud := 0.06
var storm := 0.0
## The endless flight's weather (scripts/endless/weather.gd): how far the sky's
## dome is greyed to an overcast (0..1), and that grey's brightness against the
## clear sky's (1 as bright).
var weather_grey := 0.0
var weather_dim := 1.0
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
## --aurora: a floor the world's mood can't reset, for looking at it.
var forced_aurora := 1.2 if "--aurora" in preload("res://scripts/launch_args.gd").user_args() else 0.0
var rainbow_strength := 0.0
var weather_bow := 0.0
## A rainbow that life calls after rain over a rich place (scripts/life_moments.gd).
var moment_bow := 0.0
## A moonbow that life calls after night rain under a near-full moon.
var moon_bow := 0.0
## 1 on a double rainbow: brings the fainter second bow up (life_moments.gd).
var moment_bow_double := 0.0
## The endless flight's sky lights (scripts/endless/weather_sky_lights.gd): the
## weather's double bow (0..1) and its aurora nights' strength.
var weather_bow_double := 0.0
var sky_aurora := 0.0
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
## How deep the sun may sink (sun height under the horizon), or 0 for no floor
## (a full night, the isles' and studies' own). Endless flight's day cycle
## (scripts/endless/day_cycle.gd) sets it, so night is only a blue hour: the
## sun goes down as ever, then eases toward this depth instead of falling to
## the bottom of its ring, and runs along under the horizon at it, keeping
## its ring's bearing, to where it rises (as the sun does on a midsummer
## night in the far north). The ring's own height is unchanged above the
## horizon, so a day's light is as it was.
var night_floor := 0.0
## The blue hour (with a night floor): as the sun sinks from BLUE_E.x to .y
## (the floor's depth), after the afterglow's rose, the sky turns a deep
## clear blue (BLUE_UP overhead, BLUE_DOWN low) instead of going on to the
## night's navy and black, the night (stars, the night dome, the moon's
## key) comes only BLUE_NIGHT of the way in, the night look's rod-lit grade
## only BLUE_DARK of its way, and the clouds take a dim twilight blue
## (BLUE_CLOUD) rather than the moon's white, and the Belt of Venus (the
## pink band away from the sun) goes as the blue comes. `blue_hour` is how
## far in.
const BLUE_E := Vector2(-0.04, -0.085)
const BLUE_UP := Vector3(0.02, 0.055, 0.17)
const BLUE_DOWN := Vector3(0.018, 0.035, 0.08)
const BLUE_NIGHT := 0.72
const BLUE_DARK := 0.5
const BLUE_CLOUD := Vector3(0.2, 0.24, 0.4)
const BLUE_MOON := 0.5
var blue_hour := 0.0
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
## Night light round 1 (docs/design/night-light/round1.md): the land read as a
## black cutout under clear moonlit skies while the clouds round it took the
## moon well. The moon's key on surfaces is MOON_KEY times what it was, the
## night fill's energy NIGHT_FILL_ENERGY (was 0.4) a unit of fill, and the
## rim's night floor NIGHT_RIM (new moon, full; was 0.12, 0.3), so stone and
## turf read cool and moonlit and night stays night (the grade's rod-lit
## shift and the sky are untouched). --moon-key=K, --night-fill=F try others.
const MOON_KEY := 2.0
const NIGHT_FILL_ENERGY := 1.1
const NIGHT_RIM := Vector2(0.16, 0.42)
## Round 2 (docs/design/night-light/round2.md): up close the moonlit turf
## read pale and sandy, partly autumn's warm cast left on the moon, the
## fill and the haze; at night only this share of it stays.
const NIGHT_AUTUMN := 0.15
var moon_key := _arg_float("--moon-key=", MOON_KEY)
var night_fill_energy := _arg_float("--night-fill=", NIGHT_FILL_ENERGY)
## The moon's light on the clouds (zs_cloud_sun at night) under a new and a
## full moon (was 0.12, 0.85): a full moon lit the drifting puffs, the
## towers and the cloud sea near daytime white; now they stay moonlit and
## cool, bright on the moon's side, in shade on the other. --night-cloud=X
## scales the full moon's.
const NIGHT_CLOUD_LIGHT := Vector2(0.1, 0.42)
var night_cloud := _arg_float("--night-cloud=", 1.0)
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
## Golden hour. The source lets the earth's shadow (`zs_alpen` x and y, the
## shade line that climbs the land) start rising at 6 degrees of sun, so on a
## diorama the whole plate fell into shade from mid-afternoon and the low warm
## sun never reached it. The line keeps the source's shape but runs this much
## lower in sun height: the land holds its sun to within a degree or two of
## the horizon, then the shadow climbs the peaks through sunset.
const ALPEN_LAG := 0.05
## Sun height over which the sky and the ground's bounce go from the night's
## to the day's, wider and lower than `daylight`, so a low sun still has a
## lit sky over it and dusk keeps colour after the sun has gone.
const SKY_DAY_E := Vector2(-0.13, 0.16)
## The sun as a light stands this much higher than its disc near the horizon
## (fading out by KEY_LIFT_E.y of sun height): a sun two degrees up lights
## flat land as if it stood eight, so golden hour's warm light reaches the
## plate and its shadows still run long. The disc, the sky and the shade line
## keep the true height.
const KEY_LIFT := 0.1
const KEY_LIFT_E := Vector2(0.05, 0.35)
## Dusk's afterglow, the sky and shaded land going rose and violet in the
## half hour after sunset, between these sun heights (in, then out again).
const AFTERGLOW_E := Vector4(0.02, -0.03, -0.17, -0.07)
const AFTERGLOW_SKY := Vector3(0.11, 0.07, 0.15)
const AFTERGLOW_DOWN := Vector3(0.055, 0.04, 0.07)
const AFTERGLOW_AMBIENT := Vector3(0.62, 0.5, 0.78)
## Dusk's fill. After sunset the sun's key goes out and the night fill has not
## come in, so between them the land fell darker than at night while the sky
## over it was still bright: in a close view the ground went near black under
## a rose sky. The glowing sky lights the land instead: this much more fill
## energy (the night fill's measure) between DUSK_FILL_E's sun heights (in
## from x to y, out from z to w, gone by the night look so night is as it
## was), tinted toward AFTERGLOW_AMBIENT. Overcast keeps DUSK_FILL_CLOUD of it,
## grey: a dim sky still lights the land.
const DUSK_FILL := 0.42
const DUSK_FILL_E := Vector4(0.04, -0.02, -0.2, -0.1)
const DUSK_FILL_CLOUD := 0.6
## Golden hour's contrast: the sky's fill eases off by this share while the sun
## is low and up, so the warm key leads and shade goes cool and deep.
const GOLDEN_FILL_DIP := 0.18
## The day's key against its fill (the de-Roblox light pass, 2026-10-06): the
## sun this much stronger and the sky's hemisphere fill this much weaker than
## the look's own energies, so forms read sunlit, with a lit side and a shade
## side, instead of evenly lit under an overcast-feeling sky. The night's fill
## and dusk's are left as they were. --key-gain=K / --fill-gain=F try others.
## The clear day's sky (before the look's ratios and the weather): under the
## horizon, the zenith, and the band round the horizon. A deeper blue
## overhead over a pale, clean horizon, so a clear noon reads clear; it was
## slate over a warm grey band ((0.055, 0.07, 0.1), (0.1, 0.14, 0.24),
## (0.3, 0.18, 0.14)), which read overcast under any cover.
const DAY_SKY := [Vector3(0.055, 0.07, 0.1), Vector3(0.075, 0.15, 0.31), Vector3(0.3, 0.18, 0.14)]
static var key_gain := _arg_float("--key-gain=", 1.4)
static var fill_gain := _arg_float("--fill-gain=", 0.65)

## The light's colour cast (2026-10-06: "why is the lighting super greenish
## and blue"). The only ambient is the sky's hemisphere (zs_hemi_sky from
## above, zs_hemi_ground from below), lighting land, rock and folk as
## emission, and the looks' palettes push it hard: a saturated blue from
## above (blue twice the red at noon) and a grass-green bounce from below,
## under a teal zenith and a cyan horizon. Tempered where they are made:
## the fill keeps FILL_SATURATION of its colour (still cool, no longer
## blue), the bounce goes BOUNCE_NEUTRAL of the way to a warm grey of its
## brightness, and the sky's green never rises past SKY_GREEN_CAP of the
## way from its red to its blue, so a teal turns blue and a blue stays.
const FILL_SATURATION := 0.55
const BOUNCE_NEUTRAL := 0.7
const BOUNCE_GREY := Vector3(1.0, 0.96, 0.9)
const SKY_GREEN_CAP := 0.5

static func _luma(c: Vector3) -> float:
	return c.dot(Vector3(0.2126, 0.7152, 0.0722))

## Light follow (docs/design/endless-flight/light-pass-handoff.md): the
## reference look's light, the default mood (alpine_morning) at 8.6 h: its
## key's hue and its sky fill's hue (luma 1). zs_sun_lean and zs_shade_lean are
## today's hues over these, so a material's painted warm and cool tones are its
## own at the reference and turn with the light from there.
const REF_SUN_HUE := Vector3(1.432, 0.927, 0.454)
const REF_FILL_HUE := Vector3(0.801, 1.025, 1.336)
## The shade's hue follows the zenith's turn from its day colour by this power
## (golden hour's violet), and cools against a sun warmer than the reference's
## by this power of the sun's hue's inverse (shade reads as the sun's complement).
const SHADOW_SKY := 0.5
const SHADOW_COMPLEMENT := 0.3
## Each lean's channels stay within this.
const LEAN_RANGE := Vector2(0.3, 3.0)
## With light follow on: the fill's golden-hour dip (GOLDEN_FILL_DIP off), and
## the rim's, the key's lift, and how far the sun's hue deepens past the
## reference's (a power of its lean).
const GOLDEN_FILL_DIP_FOLLOW := 0.3
const RIM_GOLDEN_DIP := 0.3
const GOLDEN_KEY_LIFT := 0.3
const GOLDEN_DEEPEN := 0.5
## Light follow's golden hour: in from sun height x to y (wider than the old
## dip's 0.3 to 0.1, so a late afternoon sun already leans golden; the default
## mood's 8.6 h sun stands at 0.48).
const GOLDEN_E := Vector2(0.42, 0.14)
## Light pass round 2 (docs/design/endless-flight/light-pass-2-handoff.md):
## haze toward and away from a low sun. Over golden hour (GOLDEN_E, clear
## sky, light follow on) zs_haze_sun rises to 1: the sky's horizon glow
## gathers toward the sun's bearing and the side away from it cools to the
## zenith's hue (reference_sky_common zsSkyBase), and the land's depth fog
## takes more of the sky behind each pixel and more of the sun's scatter
## (scripts/endless/endless_look.gd `_haze`). --haze-sun=0 turns it off.
static var haze_sun := _arg_float("--haze-sun=", 1.0)
## Backlight: grass tips and spruce silhouettes seen against a low sun glow
## in its colour (shaders/backlight.gdshaderinc). zs_backlight follows
## golden hour (GOLDEN_E, clear sky, light follow) times --backlight=X
## (1; 0 off).
static var backlight := _arg_float("--backlight=", 1.0)
## Clouds lit from below at sunset (shaders/endless_cloud_composite.gdshader
## UNDER_*): zs_cloud_under comes in as the sun falls from CLOUD_UNDER_E.x
## to .y and goes as it sinks from .z to .w under the horizon, under a clear
## sky, with light follow, times --cloud-under=X (1; 0 off).
const CLOUD_UNDER_E := Vector4(0.16, 0.03, 0.0, -0.08)
static var cloud_under := _arg_float("--cloud-under=", 1.0)
## --light-follow=0 is the light as it was before the light pass (the leans 1,
## the fill and rim their old colours and dips); between, part way.
static var light_follow := _arg_float("--light-follow=", 1.0)

## A colour's hue at luma 1.
static func _hue(c: Vector3) -> Vector3:
	return c / maxf(_luma(c), 1e-5)

static func _vpow(c: Vector3, k: float) -> Vector3:
	return Vector3(pow(maxf(c.x, 1e-5), k), pow(maxf(c.y, 1e-5), k), pow(maxf(c.z, 1e-5), k))

## A ratio of hues as a lean: luma 1, each channel in LEAN_RANGE.
static func _lean(r: Vector3) -> Vector3:
	return _hue(r).clamp(Vector3.ONE * LEAN_RANGE.x, Vector3.ONE * LEAN_RANGE.y)

## `c` leaned by `lean`, keeping its luma.
static func _hue_keep(c: Vector3, lean: Vector3) -> Vector3:
	return _hue(c * lean) * _luma(c)

static func _temper_fill(c: Vector3) -> Vector3:
	return Vector3.ONE * _luma(c) + (c - Vector3.ONE * _luma(c)) * FILL_SATURATION

static func _temper_bounce(c: Vector3) -> Vector3:
	var grey := BOUNCE_GREY * _luma(c) / _luma(BOUNCE_GREY)
	return c.lerp(grey, BOUNCE_NEUTRAL)

static func _temper_sky(c: Vector3) -> Vector3:
	return Vector3(c.x, minf(c.y, lerpf(c.x, c.z, SKY_GREEN_CAP) if c.z > c.x else c.y), c.z)

static func _arg_float(prefix: String, fallback: float) -> float:
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with(prefix): return float(arg.trim_prefix(prefix))
	return fallback
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
	var sun := floored(_ring_direction(theta, _tilt))
	moon_age = lunar_age()
	moon_lit = 0.5 + 0.5 * cos(moon_age * TAU)
	var moon := moon_direction(phase)
	var e := sun.y
	sun_height = e
	var day := smoothstep(-0.06, 0.28, e)
	daylight = day
	var blue := smoothstep(BLUE_E.x, BLUE_E.y, e) if night_floor > 0.0 else 0.0
	blue_hour = blue
	# (The land's night fill keeps the whole night's: the blue hour's sky
	# lights it as the night's would.)
	var night_full := 1.0 - smoothstep(-0.16, 0.02, e)
	var night := night_full * (1.0 - BLUE_NIGHT * blue)
	var warmth := exp(-e * e / (2.0 * 0.13 * 0.13))
	# A low sun stays a strong key down to the horizon (golden hour's long
	# light) and goes out over the last degree or two.
	var sun_energy := 3.4 * smoothstep(-0.035, 0.05, e) * (0.68 + 0.32 * smoothstep(0.08, 0.45, e))
	var sky_day := smoothstep(SKY_DAY_E.x, SKY_DAY_E.y, e)
	var moon_up := smoothstep(0.02, 0.30, moon.y)
	var moon_energy := 3.4 * 0.11 * moon_up * night * lerpf(MOON_LIGHT.x, MOON_LIGHT.y, moon_lit) * moon_key * (1.0 - BLUE_MOON * blue)
	# How much moon there is to see by (phase and height), and how deep into
	# the night the look has gone.
	var moon_glow := moon_lit * moon_up
	var dark := (1.0 - smoothstep(NIGHT_LOOK_E.x, NIGHT_LOOK_E.y, e)) * (1.0 - BLUE_DARK * blue)
	# Autumn's warm cast on the light, the fill and the haze is the sun's:
	# under the moon only NIGHT_AUTUMN of it is left (night light round 2).
	var autumn_lit := autumn * lerpf(1.0, NIGHT_AUTUMN, dark)
	var moon_tint := _rgb(MOON_TINT[0]).lerp(_rgb(MOON_TINT[1]), moon_lit)
	var tint := look.rgb("sun").lerp(Vector3(1, 0.97, 0.9), smoothstep(0.35, 0.9, e) * 0.5)
	tint = _rgb("ff6222").lerp(_rgb("ffb45c"), smoothstep(-0.02, 0.1, e)).lerp(tint, smoothstep(0.1, 0.4, e))
	# Golden hour (a low sun, up, under a clear sky): with light follow on, the
	# sun's hue deepens past the reference's (GOLDEN_DEEPEN) and the key grows
	# (GOLDEN_KEY_LIFT) as the fill and rim ease off, so the low sun leads.
	var clear_sun := smoothstep(-0.03, 0.05, e) * (1.0 - minf(1.0, cloud * 1.3))
	var golden := smoothstep(0.3, 0.1, e) * clear_sun
	var golden_f := smoothstep(GOLDEN_E.x, GOLDEN_E.y, e) * clear_sun
	var follow := clampf(light_follow, 0.0, 1.0)
	var deepen := _vpow(_lean(_hue(tint) / REF_SUN_HUE), GOLDEN_DEEPEN * golden_f * follow)
	tint = _hue_keep(tint, deepen)
	var sun_tint := tint
	var key_direction := _lifted(sun)
	var energy := sun_energy
	if moon_energy > sun_energy:
		key_direction = moon
		energy = moon_energy
		tint = moon_tint
	var overcast := lerpf(1.0, 0.44, cloud) * lerpf(1.0, 0.8, storm) * lerpf(1.0, 0.86, shroud) * lerpf(1.0, 0.92, cold)
	_sun.position = key_direction * Vector3(20, 14, 12).length()
	_sun.look_at(Vector3.ZERO)
	_sun.light_energy = energy * overcast / PI * look.settings.sun_energy * lerpf(1.0, key_gain, day) * (1.0 + GOLDEN_KEY_LIFT * golden_f * follow * (0.0 if moon_energy > sun_energy else 1.0))
	if shimmer > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		_sun.light_energy *= 1.0 + shimmer * 0.16 * (0.5 * sin(t * 37.0) + 0.5 * sin(t * 23.0 + 1.3))
	_sun.light_color = _color(tint.lerp(Vector3(0.78, 0.84, 0.95), cloud * 0.7).lerp(Vector3(1.0, 0.70, 0.38), autumn_lit * 0.35).lerp(Vector3(0.82, 0.88, 1.0), cold * 0.4)).linear_to_srgb()
	var ambient := smoothstep(-0.12, 0.10, e)
	var hemi_sky := _rgb("26324e").lerp(_rgb("8fb3d9"), ambient).lerp(_rgb("7d92bd"), warmth * 0.5)
	var dusk_glow := smoothstep(AFTERGLOW_E.x, AFTERGLOW_E.y, e) * smoothstep(AFTERGLOW_E.z, AFTERGLOW_E.w, e) * (1.0 - minf(1.0, cloud * 1.3))
	hemi_sky = hemi_sky.lerp(AFTERGLOW_AMBIENT * maxf(hemi_sky.dot(Vector3(0.2126, 0.7152, 0.0722)), 0.0) / AFTERGLOW_AMBIENT.dot(Vector3(0.2126, 0.7152, 0.0722)), dusk_glow * 0.6)
	hemi_sky *= look.ratio("ambient")
	hemi_sky = hemi_sky.lerp(Vector3(0.5, 0.55, 0.62), cloud * 0.6).lerp(Vector3(0.66, 0.58, 0.46), autumn_lit * 0.3).lerp(Vector3(0.62, 0.70, 0.85), cold * 0.35)
	hemi_sky = _temper_fill(hemi_sky)
	var hemi_ground := _rgb("0d1016").lerp(_rgb("4a5240"), sky_day)
	hemi_ground *= look.ratio("bounce")
	hemi_ground = _temper_bounce(hemi_ground)
	if _rim_turned != room_yaw:
		_rim.global_basis = Basis(Vector3.UP, room_yaw) * _rim_basis
		_rim_turned = room_yaw
	# The rim's night floor follows the moon: a new moon leaves silhouettes.
	_rim.light_energy = 1.1 * (lerpf(0.3, lerpf(NIGHT_RIM.x, NIGHT_RIM.y, moon_glow), dark) + 0.7 * sky_day) * lerpf(1.0, 0.5, cloud) / PI
	_publish("zs_key_direction", _sun.global_basis.z.normalized())
	var key_color := _sun.light_color.srgb_to_linear()
	_publish("zs_key_irradiance", Vector3(key_color.r, key_color.g, key_color.b) * _sun.light_energy * PI)
	_publish("zs_rim_direction", _rim.global_basis.z.normalized())
	_publish("zs_cloud_direction", key_direction)
	# (The sun's tint, not the key's: just after sunset the moon outshines
	# the set sun and the key takes the moon's tint, which lit the clouds
	# moon-white at full strength the moment the sun went down.)
	var cloud_sun := sun_tint.lerp(Vector3(0.78, 0.84, 0.95), cloud * 0.7).lerp(Vector3(1.0, 0.70, 0.38), autumn_lit * 0.35).lerp(Vector3(0.82, 0.88, 1.0), cold * 0.4) * (0.9 + 0.5 * overcast)
	# The source lights air and cloud with the key's colour at full strength
	# even when nothing is up. At night that left the mist lit like day (and
	# orange under a new moon): lean it on the moon instead.
	cloud_sun = cloud_sun.lerp(moon_tint.lerp(Vector3(0.78, 0.84, 0.95), cloud * 0.7) * lerpf(NIGHT_CLOUD_LIGHT.x, NIGHT_CLOUD_LIGHT.y * night_cloud, moon_glow) * (0.9 + 0.5 * overcast), maxf(dark, smoothstep(0.0, -0.07, e)))
	cloud_sun = cloud_sun.lerp(BLUE_CLOUD * lerpf(1.0, 0.7, cloud), blue)
	_publish("zs_cloud_sun", cloud_sun)
	_publish("zs_cloud_sky", hemi_sky * 0.55)
	# Native night adaptation: a cool surface fill keeps the miniature readable.
	# Keep sky/cloud/fog colors independent so stars retain their dark backdrop.
	var fill := night_full * night_fill * lerpf(1.0, 0.4, storm) * lerpf(MOON_FILL.x, MOON_FILL.y, moon_glow)
	# Dusk's fill (DUSK_FILL): the afterglow sky lighting the land, rose-lavender
	# under a clear sky, grey under cloud.
	var dusk_fill := smoothstep(DUSK_FILL_E.x, DUSK_FILL_E.y, e) * smoothstep(DUSK_FILL_E.z, DUSK_FILL_E.w, e) * lerpf(1.0, DUSK_FILL_CLOUD, minf(1.0, cloud * 1.3)) * lerpf(1.0, 0.4, storm)
	var surface_sky := hemi_sky.lerp(AFTERGLOW_AMBIENT * maxf(hemi_sky.dot(Vector3(0.2126, 0.7152, 0.0722)), 0.0) / AFTERGLOW_AMBIENT.dot(Vector3(0.2126, 0.7152, 0.0722)), dusk_fill * (1.0 - minf(1.0, cloud * 1.3)) * 0.5)
	var dip := lerpf(GOLDEN_FILL_DIP * golden, GOLDEN_FILL_DIP_FOLLOW * golden_f, follow)
	_publish("zs_hemi_energy", (0.55 * (0.22 + 0.78 * ambient) * (1.0 - dip) * lerpf(1.0, 1.25, cloud) * lerpf(1.0, 0.55, storm) * lerpf(1.0, fill_gain, day) + night_fill_energy * fill + DUSK_FILL * dusk_fill) * look.settings.ambient_energy)
	var down := Vector3(0.006, 0.009, 0.016).lerp(DAY_SKY[0], sky_day)
	var up := Vector3(0.01, 0.016, 0.038).lerp(DAY_SKY[1], sky_day).lerp(Vector3(0.1, 0.07, 0.16), warmth * 0.55)
	var glow := Vector3(0.016, 0.024, 0.045).lerp(DAY_SKY[2], sky_day).lerp(Vector3(0.85, 0.3, 0.09), warmth * 0.8)
	up = up.lerp(AFTERGLOW_SKY, dusk_glow * 0.7).lerp(BLUE_UP, blue)
	down = down.lerp(AFTERGLOW_DOWN, dusk_glow * 0.7).lerp(BLUE_DOWN, blue)
	down *= look.ratio("horizon")
	up *= look.ratio("sky")
	glow *= look.ratio("glow")
	var sky_dim := clampf(up.dot(Vector3(0.2126, 0.7152, 0.0722)) / 0.14, 0.08, 1.0)
	# Under the endless flight's weather (weather_grey > 0) the dome is greyed
	# below instead of darkened by these targets (drawn for the isles' sky).
	var cover := minf(1.0, cloud * 1.15) * (1.0 - weather_grey)
	var dome_storm := storm * (1.0 - weather_grey)
	# Weather tint targets from weather.js; applied after the hour, as in the source.
	down = down.lerp(Vector3(0.052, 0.058, 0.066) * sky_dim, cover).lerp(Vector3(0.022, 0.024, 0.028) * sky_dim, dome_storm)
	up = up.lerp(Vector3(0.085, 0.096, 0.112) * sky_dim, cover).lerp(Vector3(0.034, 0.038, 0.046) * sky_dim, dome_storm)
	glow = glow.lerp(Vector3(0.085, 0.085, 0.090) * sky_dim, cover).lerp(Vector3(0.040, 0.042, 0.048) * sky_dim, dome_storm)
	# The zenith's turn (the shade's hue below) is the clear sky's: a grey
	# dome would turn the shade, and the paint leaning on it, red.
	var hue_up := up
	if weather_grey > 0.0:
		# An overcast dome: even top to bottom, a cool grey as bright as the
		# clear sky's own (by its hour), times weather_dim.
		var flat := (_luma(up) * 0.5 + _luma(down) * 0.3 + _luma(glow) * 0.4) * weather_dim
		var grey := Vector3(0.94, 0.97, 1.03) * flat
		up = up.lerp(grey, weather_grey)
		down = down.lerp(grey * 0.92, weather_grey)
		glow = glow.lerp(grey * 0.15, weather_grey)
	_publish("zs_sky_down", _temper_sky(down))
	_publish("zs_sky_up", _temper_sky(up))
	_publish("zs_sky_glow", glow)
	# Light follow: the shade's hue (the sky fill's, turned as the zenith turns
	# from its day colour and cooled against a sun warmer than the reference),
	# and how far the sun's and the shade's hues have moved from the reference
	# look's (the leans the materials' painted light tones follow).
	var sun_up := smoothstep(-0.03, 0.05, e) * (0.0 if moon_energy > sun_energy else 1.0)
	var sun_hue := _hue(Vector3(key_color.r, key_color.g, key_color.b))
	var fill_hue := _hue(surface_sky)
	var zenith_turn := _hue(hue_up) / _hue(_temper_sky(DAY_SKY[1] * look.ratio("sky")))
	var complement := (REF_SUN_HUE / sun_hue).clamp(Vector3.ONE * 0.2, Vector3.ONE * 5.0)
	var shadow_hue := _hue(fill_hue * _vpow(zenith_turn, SHADOW_SKY * sun_up) * _vpow(complement, SHADOW_COMPLEMENT * sun_up))
	shadow_hue = fill_hue.lerp(shadow_hue, follow)
	_publish("zs_sun_hue", sun_hue)
	_publish("zs_shadow_tint", shadow_hue)
	# (The paint follows the hour's sun, not golden hour's deepening of it.)
	var sun_lean := Vector3.ONE.lerp(_lean(sun_hue / deepen / REF_SUN_HUE), sun_up * follow)
	var shade_lean := Vector3.ONE.lerp(_lean(shadow_hue / REF_FILL_HUE), (1.0 - dark) * follow)
	_publish("zs_sun_lean", sun_lean)
	_publish("zs_shade_lean", shade_lean)
	_publish("zs_light_follow", follow)
	_publish("zs_haze_sun", golden_f * follow * clampf(haze_sun, 0.0, 1.0))
	_publish("zs_backlight", golden_f * follow * maxf(backlight, 0.0) * (0.0 if moon_energy > sun_energy else 1.0))
	_publish("zs_cloud_under", smoothstep(CLOUD_UNDER_E.x, CLOUD_UNDER_E.y, e) * smoothstep(CLOUD_UNDER_E.w, CLOUD_UNDER_E.z, e) * (1.0 - minf(1.0, cloud * 1.3)) * follow * maxf(cloud_under, 0.0))
	# The sky fill is the shade's hue at the fill's strength; the rim (a
	# second fill from the side) leans as the shade does, and both ease off at
	# golden hour so the low sun leads.
	_publish("zs_hemi_sky", shadow_hue * _luma(surface_sky) + NIGHT_FILL * fill)
	_publish("zs_hemi_ground", hemi_ground + Vector3(0.08, 0.1, 0.13) * fill)
	_rim.light_energy *= 1.0 - RIM_GOLDEN_DIP * golden_f * follow
	_rim.light_color = _color(_hue_keep(look.rgb("rim"), shade_lean)).linear_to_srgb()
	var rim_color := _rim.light_color.srgb_to_linear()
	_publish("zs_rim_irradiance", Vector3(rim_color.r, rim_color.g, rim_color.b) * _rim.light_energy * PI)
	_publish("zs_sun_direction", sun)
	_publish("zs_moon_direction", moon)
	_publish("zs_moon_shadow_direction", (moon - sun * 0.028).normalized())
	var clear := 1.0 - minf(1.0, cloud * 1.4)
	var shade_e := e + ALPEN_LAG
	var alpen := smoothstep(0.13, 0.07, shade_e) * smoothstep(-0.14, -0.07, shade_e) * clear
	var afterglow := smoothstep(0.03, -0.02, e) * smoothstep(-0.13, -0.05, e) * clear
	_publish("zs_alpen", Vector3(alpen if alpen_enabled else 0.0, smoothstep(0.10, -0.04, shade_e), afterglow if alpen_enabled else 0.0))
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
	# The dawn inversion's lid keeps the source's light (its shade line and sun
	# strength at the true sun height): it is a dawn sight, not golden hour's.
	var source_alpen := smoothstep(0.13, 0.07, e) * smoothstep(-0.14, -0.07, e) * clear
	var shade_line := lerpf(low - band, high + band, smoothstep(0.10, -0.04, e))
	var sun_on := lerpf(1.0, smoothstep(shade_line - band * 0.5, shade_line + band * 0.5, lid), source_alpen)
	var source_energy := 3.4 * smoothstep(-0.03, 0.10, e) * (0.45 + 0.55 * smoothstep(0.08, 0.45, e))
	var sun_k := minf(1.0, (energy if moon_energy > sun_energy else source_energy) / 2.0)
	var fog_color := (hemi_sky * 0.55 * 1.7).lerp(Vector3(0.30, 0.33, 0.38), storm * 0.6).lerp(Vector3(0.72, 0.66, 0.54), autumn_lit * 0.35).lerp(Vector3(0.62, 0.68, 0.78), cold * 0.45)
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
	_publish("zs_belt", smoothstep(0.06, -0.01, e) * smoothstep(-0.14, -0.06, e) * (1.0 - minf(1.0, cloud * 1.3)) * (1.0 - 0.8 * blue))
	# The aurora's heading is a bearing, so the room's turn simply adds to it.
	_publish("zs_aurora", Vector4(maxf(maxf(maxf(aurora_strength, forced_aurora), _aurora), sky_aurora), 1.0, 0.15, -1.2 + room_yaw))
	_publish("zs_room_yaw", room_yaw)
	_publish("zs_bow", maxf(maxf(rainbow_strength, weather_bow), moment_bow) * smoothstep(-0.03, 0.1, e))
	_publish("zs_bow_grow", _rainbow_growth)
	_publish("zs_bow_shape", Vector2.ONE)
	_publish("zs_moonbow", moon_bow * night * smoothstep(-0.02, 0.08, moon.y))
	_publish("zs_bow_double", maxf(moment_bow_double, weather_bow_double))

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

## The key light's direction for a sun at `sun`: raised near the horizon by
## KEY_LIFT, keeping its bearing.
func _lifted(sun: Vector3) -> Vector3:
	var flat := Vector2(sun.x, sun.z).length()
	if flat < 0.0001: return sun
	var height := sun.y + KEY_LIFT * (1.0 - smoothstep(KEY_LIFT_E.x, KEY_LIFT_E.y, sun.y))
	return Vector3(sun.x / flat * sqrt(maxf(0.0, 1.0 - height * height)), height, sun.z / flat * sqrt(maxf(0.0, 1.0 - height * height))).normalized()

## The sun's direction `sun` under the night floor: its height eased (a
## tanh, so the descent's pace carries on unbroken through the horizon) to
## no deeper than `night_floor`, its bearing kept. Unchanged above the
## horizon or with no floor.
func floored(sun: Vector3) -> Vector3:
	if night_floor <= 0.0 or sun.y >= 0.0: return sun
	var y := -night_floor * tanh(-sun.y / night_floor)
	var flat := Vector2(sun.x, sun.z).normalized() * sqrt(1.0 - y * y)
	return Vector3(flat.x, y, flat.y)

## The sun's direction at a phase, with the room's yaw left out.
func ring_at(at_phase: float) -> Vector3:
	var was := room_yaw
	room_yaw = 0.0
	var d := _ring_direction((at_phase - 0.25) * TAU, _tilt)
	room_yaw = was
	return d

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
