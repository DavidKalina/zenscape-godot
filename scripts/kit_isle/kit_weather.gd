extends Node
## The kit isles' time and weather (docs/design/consolidation-audit.md,
## round 4): the old game's world clock, sky seasons, weather drift and
## lightning on a kit isle's sky (studies/kit_isle.gd's look rig), through
## the shared pieces the old game uses, none of it in kit_isle.gd.
##
##   the day     a WorldClock (scripts/world_clock.gd) attached to the
##               celestial rig, turning: a day in DAY_SECONDS[0] (the old
##               game's 480 s) unless the settings or --day-length= say
##               otherwise, so the sun sets, the night styles come out
##               (scripts/look_pass.gd), the moon waxes and on a clear
##               winter night the aurora may burn. The isle's life already
##               reads the daylight (scripts/kit_isle/kit_life.gd,
##               kit_birds.gd).
##   the year    the clock's calendar (YEAR_DAYS world days a year) worn by
##               the ground and published to the plants and the sky layer
##               through the shared calendar (scripts/sky_calendar.gd): the
##               cloud sea's and the cloud volume's season grade
##               (`zs_sky_season`), the plants' bloom, leaf fall and straw
##               (`zs_season`), the ground's gold and cold. A session opens
##               in the season of the real date (`date_season`; 1 March opens
##               spring) and the year turns on from there.
##   the weather the old scheduler's seasonal table (scripts/
##               weather_scheduler.gd: afternoon thunder in summer, dawn mist
##               after rain, snow only in winter), drawn for the clock's hour
##               on hours of its own (WEATHER_HOUR real seconds each, so the
##               weather drifts while the day holds), each new sky eased in
##               as the old game's living weather eases its own (scripts/
##               living_weather.gd `ease_toward`: about half a minute,
##               keeping the start look's air), the season owning the gold.
##   lightning   the old storm's (studies/lightning.gd), struck where the
##               kit's sky has cloud (`strike`): a flash inside the nearest
##               standing tower, a flash in the cloud sea round the eye, or
##               a bolt from a drifting cloud down into the sea, never on an
##               isle. The cloud volume lights round each flash (the scene's
##               `_lightning`, look_pass.gd), VOLUME_GAIN times the plate's;
##               the thunder (studies/thunder_audio.gd) follows at
##               SOUND_SPEED.
##
## The look presets (L, --look=) are overrides on top of it: a preset holds
## the sky (`show_look`: its hour, its weather and its season, the drift
## off), and LIVE ("Live sky", first in L's order and where a played start
## opens) gives it back: the start look's colours over the turning day,
## from the hour it was held at. A capture holds its look unless
## --live-sky. --still-sky starts held, as the kit was before.
##
## Flags (scripts/launch_args.gd `user_args`), for watching it fast:
##   --day-length=<s>   real seconds a day (0 holds the hour)
##   --hour=<h>         the hour a live start opens at (else the start look's)
##   --season=<s>       spring, summer, autumn, winter or 0..1 (else the date's)
##   --year-days=<n>    world days a year (YEAR_DAYS)
##   --weather=<name>   the sky a live start opens in (clear, fair, overcast,
##                      mist, rain, storm, snow, autumn)
##   --weather-hour=<s> real seconds a weather hour (WEATHER_HOUR)
##   --weather-seed=<n> the drift's draws (else random)
##   --still-weather    the weather holds; --still-sky everything holds
##   --live-sky         live even in a capture
## Developer keys (scripts/kit_isle/dev_keys.gd): F9 the next quarter day,
## F10 the next weather (Shift+F10 drift on or off), F11 the next season,
## F12 a strike now.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const SkyCalendar = preload("res://scripts/sky_calendar.gd")
const Living = preload("res://scripts/living_weather.gd")
const Lightning = preload("res://studies/lightning.gd")
const Thunder = preload("res://studies/thunder_audio.gd")
const SkyTower = preload("res://scripts/sky_tower.gd")

## L's entry that gives the sky back to the clock and the drift, and its
## name as it shows.
const LIVE := "live"
const LIVE_TITLE := "Live sky"
const LIVE_LINE := "The day turns and the weather drifts."

## The settings' day lengths (real seconds a world day; 0 holds the hour)
## and their names (scripts/kit_isle/game_settings.gd "day"). The first is
## the old game's day (WorldClock.DEFAULT_DAY_LENGTH).
const DAY_SECONDS := [WorldClock.DEFAULT_DAY_LENGTH,1440.0,0.0]
const DAY_NAMES := ["A day in 8 minutes","A day in 24 minutes","Held"]
## The settings' weather ("weather"): drifting or still.
const DRIFT_NAMES := ["Drifting","Still"]
## World days a year: the old game's four seven-day seasons. At the first
## day length a season is about an hour of play.
const YEAR_DAYS := WorldClock.YEAR_DAYS
## Day of the year (0 the first of January) the year's spring opens on:
## the first of March, so the date's season is the meteorological one.
const SPRING_DAY := 59
const MONTH_DAYS := [31,28,31,30,31,30,31,31,30,31,30,31]

## Real seconds a weather hour (living weather's HOUR_SECONDS): the
## scheduler's dwell, in its hours, is three to four minutes of a bright
## sky and a minute or two of rain.
const WEATHER_HOUR := Living.HOUR_SECONDS
## A storm holds a little longer than the table's 1-3 hours, so its cloud
## has built (precipitation `gather`) and its thunder had its say before
## it passes.
const DWELL := {"storm":[3.0,6.0]}

## Where the storm strikes: the share that flash inside a standing tower
## (within TOWER_REACH m of the eye), the share that fall as a bolt from a
## drifting cloud within PUFF_REACH (none closer than its x: the eye is in
## it), and the rest flash in the cloud sea SEA_RING m off (x to y),
## SEA_DEPTH m into its heaps. Nothing within ISLE_CLEAR of an isle.
const TOWER_SHARE := 0.35
const TOWER_REACH := 2500.0
const BOLT_SHARE := 0.45
const PUFF_REACH := Vector2(60.0,700.0)
const SEA_RING := Vector2(160.0,700.0)
const SEA_DEPTH := 10.0
const ISLE_CLEAR := 60.0
## The cloud sea's heaps' tops (world y): where the bolts end, and the
## level the sea's flashes sit under.
const SEA_TOP := SkyTower.SEA
## A tower's flash stands this share of its column's height up from the
## sea, and this share of its radius toward the eye (the near side lights).
const TOWER_HEIGHT := Vector2(0.2,0.55)
const TOWER_NEAR := 0.6
## The cloud volume shows a flash this many times the plate's (its glow
## falls off over tens of metres; a tower is two hundred across).
const VOLUME_GAIN := 6.0
## The thunder's pace (m/s): slower than sound, so a strike half a
## kilometre off is heard a few seconds after it is seen.
const SOUND_SPEED := 160.0

var scene: Node3D
var clock: WorldClock
var scheduler: WeatherScheduler
var calendar := SkyCalendar.new()
var lightning: Node3D
var thunder: Node
## The clock turns and the weather drifts (false while a look preset, a
## capture or --still-sky holds the sky).
var live := false
## Whether the weather drifts while live (settings, --still-weather).
var drift := true
## Real seconds a world day while live (0 holds the hour).
var day_length: float = DAY_SECONDS[0]
## The scheduler's own hours, and real seconds each.
var weather_hours := 0.0
var weather_hour := WEATHER_HOUR
## The look a start opens in: LIVE, or the preset a flag or a capture holds.
var start_look := LIVE
## Main-thread microseconds the last `step` took.
var spent := 0
## Flags that set a thing pin it against the settings.
var _day_flag := false
var _drift_flag := false
var _start_hour := -1.0
var _start_season := -1.0
var _start_weather := ""
var _opened := false
## The precipitation's, the air's and the ground's own easing, put back when
## a preset holds the sky.
var _paces := {}
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "Weather"

## Attaches a clock to `study`'s celestial rig, makes the drift, the
## lightning (the scene's `_lightning`) and the thunder, and reads the flags.
## `study.look_id` is a look a flag asked for, or its START_LOOK.
func setup(study: Node3D) -> void:
	scene = study
	clock = WorldClock.new()
	clock.year_days = YEAR_DAYS
	scene._celestial.attach_clock(clock)
	var args := LaunchArgs.user_args()
	var seed_value := randi()
	var asked := ""
	var capture := false
	for arg: String in args:
		if arg.begins_with("--day-length="):
			day_length = maxf(float(arg.get_slice("=",1)),0.0)
			_day_flag = true
		elif arg.begins_with("--hour="): _start_hour = fposmod(float(arg.get_slice("=",1)),24.0)
		elif arg.begins_with("--season="): _start_season = season_named(arg.get_slice("=",1))
		elif arg.begins_with("--year-days="): clock.year_days = int(arg.get_slice("=",1))
		elif arg.begins_with("--weather="): _start_weather = arg.get_slice("=",1)
		elif arg.begins_with("--weather-hour="): weather_hour = maxf(float(arg.get_slice("=",1)),0.01)
		elif arg.begins_with("--weather-seed="): seed_value = int(arg.get_slice("=",1))
		elif arg == "--still-weather":
			drift = false
			_drift_flag = true
		elif arg.begins_with("--look=") and arg.get_slice("=",1).split(",").size() != 3: asked = arg.get_slice("=",1)
		elif arg.begins_with("--preset="): asked = arg.get_slice("=",1)
		elif arg.begins_with("--capture="): capture = true
	if _start_weather != "" and WeatherScheduler.preset_index(_start_weather) < 0:
		push_warning("kit weather: no weather '%s' (%s)" % [_start_weather,", ".join(WeatherScheduler.PRESET_NAMES)])
		_start_weather = ""
	if _start_season < 0.0: _start_season = date_season(Time.get_date_dict_from_system())
	scheduler = WeatherScheduler.new(seed_value)
	scheduler.dwell = DWELL.duplicate(true)
	_rng.seed = seed_value
	var precipitation: Node3D = scene._precipitation
	_paces = {"response":precipitation.response,"gather":precipitation.gather,
		"air":scene._atmosphere.weather_response,"pace":precipitation.surface_weather.pace,
		"frost":precipitation.surface_weather.frost_limit}
	# A look a flag asked for, a capture or --still-sky holds the sky.
	var held := asked != "" or ("--still-sky" in args) or (capture and not "--live-sky" in args)
	start_look = str(scene.look_id) if held else LIVE
	lightning = Lightning.new()
	lightning.name = "Lightning"
	add_child(lightning)
	lightning.setup(NoGround.new())
	lightning.aim = strike
	lightning.sound_speed = SOUND_SPEED
	lightning.volume_gain = VOLUME_GAIN
	lightning.downburst_enabled = false
	scene._lightning = lightning
	thunder = Thunder.new()
	thunder.name = "Thunder"
	add_child(thunder)
	lightning.thunder.connect(thunder.play_thunder)

## No plate under the storm (its own strikes are aimed).
class NoGround extends RefCounted:
	func height_at(_x: float, _z: float) -> Variant: return null

# --- The look presets over it --------------------------------------------------------

## Shows look `id`: a preset held (its hour, weather and season; the drift
## off), or LIVE, the start look's colours with the clock turning and the
## weather drifting from where the sky was held (a fresh start: from the
## start look's hour, or --hour, in the season of the date, or --season).
## Returns false for an unknown id.
func show_look(id: String) -> bool:
	if id != LIVE and not SceneLookPresets.PRESETS.has(id): return false
	var preset: String = scene.START_LOOK if id == LIVE else id
	var day := clock.day
	var hour := clock.hour
	_hold(preset)
	SceneLookPresets.apply(scene,preset)
	if id == LIVE: _go_live(day,hour)
	return true

## The sky held for `preset`: the clock still (the preset sets it so as it
## applies), the drift off, the easing back to the rig's own, and the year
## pinned to the season the preset was drawn for (living weather's
## `season_for`: snow is winter, gold leaves autumn, the rest spring or
## summer by its name).
func _hold(preset: String) -> void:
	live = false
	scheduler.enabled = false
	var precipitation: Node3D = scene._precipitation
	precipitation.response = _paces.response
	precipitation.gather = _paces.gather
	scene._atmosphere.weather_response = _paces.air
	precipitation.surface_weather.pace = _paces.pace
	precipitation.surface_weather.frost_limit = _paces.frost
	clock.season_override = preset_season(preset)
	calendar.glide = false
	calendar.shown = -1.0

## The sky given back: the clock turning at `day_length` from `day`,
## `hour` (a fresh start: the start's), the year the calendar's, the drift
## from the start look's weather and air, eased as living weather eases.
func _go_live(day: int, hour: float) -> void:
	live = true
	var precipitation: Node3D = scene._precipitation
	var atmosphere: Node3D = scene._atmosphere
	var surface: RefCounted = precipitation.surface_weather
	var recipe: Dictionary = SceneLookPresets.recipe(scene.START_LOOK)
	var weather: String = recipe.weather
	if not _opened:
		_opened = true
		hour = _start_hour if _start_hour >= 0.0 else clock.hour
		day = maxi(roundi(_start_season*clock.year_days-hour/WorldClock.HOURS_PER_DAY),0)
		if _start_weather != "": weather = _start_weather
	clock.season_override = -1.0
	clock.set_time(day,hour)
	clock.day_length = day_length
	scene._celestial.cycling = day_length > 0.0
	# The start look pins the visible cloud and the cold; the drift owns
	# them now, from what is on screen.
	if precipitation.cloud_override >= 0.0:
		precipitation.state.z = precipitation.cloud_override
		precipitation.target.z = precipitation.cloud_override
	precipitation.cloud_override = -1.0
	precipitation.cold_override = -1.0
	var profile: Dictionary = precipitation.profiles[recipe.weather]
	scheduler.origin = recipe.weather
	scheduler.origin_mood = {"wind":float(recipe.wind),"cloud":clampf(float(recipe.clouds)-float(profile.cloud),-0.3,0.3),
		"mist":float(recipe.mist),"haze":float(recipe.haze)}
	if weather != recipe.weather:
		Living.ease_toward(weather,precipitation,atmosphere,scheduler)
		precipitation.state = precipitation.target
	scheduler.set_current(weather,weather_hours)
	scheduler.enabled = drift
	precipitation.response = Living.RESPONSE
	precipitation.gather = true
	atmosphere.weather_response = Living.RESPONSE
	surface.pace = Living.SURFACE_PACE
	surface.frost_limit = Living.FROST_LIMIT
	# The season owns the gold; the ground wears the year at once.
	surface.target_autumn = 0.0
	calendar.glide = true
	calendar.shown = -1.0
	calendar.claim(surface)
	calendar.apply(clock,0.0,precipitation,scheduler,true)
	surface.autumn = surface.target_autumn
	surface.cold = surface.target_cold

## The season a look preset was drawn for, 0..1.
static func preset_season(id: String) -> float:
	var p: Dictionary = SceneLookPresets.recipe(id)
	return Living.season_for({"mood":{"weather":p.weather,"cold":p.get("cold",0.0),"autumn":p.get("autumn",0.0)},"seed":hash(id)})

## The season of `date` (Time's date dictionary), 0..1: 0 opens spring on
## the first of March.
static func date_season(date: Dictionary) -> float:
	var month := clampi(int(date.get("month",6)),1,12)
	var day_of_year := int(date.get("day",1))-1
	for m in range(month-1): day_of_year += int(MONTH_DAYS[m])
	return fposmod(float(day_of_year-SPRING_DAY)/365.0,1.0)

## A season by name (spring, summer, autumn, winter: living weather's
## landing in each) or as a number 0..1; the date's for anything else.
static func season_named(text: String) -> float:
	var i := WorldClock.SEASON_NAMES.find(text.to_lower())
	if i >= 0: return float(Living.SEASONS[i])
	if text.is_valid_float(): return fposmod(float(text),1.0)
	return date_season(Time.get_date_dict_from_system())

# --- The settings ---------------------------------------------------------------------

## The day length chosen in the settings (DAY_SECONDS' index); a
## --day-length= flag keeps its own.
func choose_day(index: int) -> void:
	if _day_flag: return
	day_length = float(DAY_SECONDS[clampi(index,0,DAY_SECONDS.size()-1)])
	if not live: return
	clock.day_length = day_length
	scene._celestial.cycling = day_length > 0.0

## Whether the weather drifts, chosen in the settings; --still-weather
## keeps it still.
func choose_drift(on: bool) -> void:
	if _drift_flag: return
	drift = on
	if live: scheduler.enabled = on

# --- Each frame -----------------------------------------------------------------------

## One frame, first in the look's (kit_isle.gd `_advance_look`, as the old
## game's scene steps its clock first): the clock, the drift, the year, then
## the storm's lightning on the sky as it stood last frame.
func step(delta: float) -> void:
	if delta <= 0.0 or scene == null: return
	var began := Time.get_ticks_usec()
	var precipitation: Node3D = scene._precipitation
	clock.advance(delta,false)
	weather_hours += delta/weather_hour
	scheduler.hour_of_day = clock.hour
	var picked: String = precipitation.PRESET_NAMES[precipitation.preset_index]
	if picked != scheduler.current: scheduler.set_current(picked,weather_hours)
	# Always advance: disabled, the scheduler slides its schedule forward.
	for name: String in scheduler.advance(weather_hours): _ease(name)
	calendar.apply(clock,delta,precipitation,scheduler,live)
	var atmosphere: Node3D = scene._atmosphere
	var camera: Camera3D = scene.camera
	lightning.advance(delta,false,precipitation.state.w,atmosphere._air_strength,Vector2(cos(atmosphere._air_angle),sin(atmosphere._air_angle)),camera.global_position if camera != null else Vector3.ZERO)
	thunder.update_state(false)
	spent = Time.get_ticks_usec()-began

## Ease toward the sky `name`, as living weather does, the season keeping
## the gold.
func _ease(name: String) -> void:
	var precipitation: Node3D = scene._precipitation
	Living.ease_toward(name,precipitation,scene._atmosphere,scheduler)
	precipitation.surface_weather.target_autumn = 0.0
	calendar.claim(precipitation.surface_weather)

# --- The storm ------------------------------------------------------------------------

## A strike round `eye` where the kit's sky has cloud (see the head): in
## the nearest standing tower, a bolt from a drifting cloud, or in the
## cloud sea. The lightning's own timing calls it in a storm; F12 calls it.
func strike(eye: Vector3) -> void:
	var host: Node = scene.cloud_host() if scene.has_method("cloud_host") else null
	var roll := _rng.randf()
	if host != null and roll < TOWER_SHARE:
		var at: Variant = _in_tower(host,eye)
		if at != null:
			lightning.flash_in(at,eye)
			return
	if host != null and roll < TOWER_SHARE+BOLT_SHARE:
		var puff: Variant = host.cloud_near(eye,PUFF_REACH.y)
		if puff is Vector3 and (puff as Vector3).distance_to(eye) >= PUFF_REACH.x and _clear((puff as Vector3)) and (puff as Vector3).y > SEA_TOP+20.0:
			lightning.strike_through((puff as Vector3)-Vector3(0.0,8.0,0.0),SEA_TOP,eye)
			return
	lightning.flash_in(_in_sea(eye),eye)

## A point inside the nearest standing tower within reach, on its near
## side, or null.
func _in_tower(host: Node, eye: Vector3) -> Variant:
	var towers: Node3D = host.get("towers")
	if towers == null: return null
	for column: Array in towers.screens(eye):
		var round: Vector4 = column[0]
		var span: Vector2 = column[1]
		var middle := Vector2(round.x,round.y)
		var to_eye := Vector2(eye.x,eye.z)-middle
		if to_eye.length() > TOWER_REACH: continue
		var side := middle+to_eye.normalized()*round.z*TOWER_NEAR if to_eye.length() > 1.0 else middle
		return Vector3(side.x,lerpf(span.x,span.y,_rng.randf_range(TOWER_HEIGHT.x,TOWER_HEIGHT.y)),side.y)
	return null

## A point in the cloud sea round `eye`, off every isle.
func _in_sea(eye: Vector3) -> Vector3:
	var at := Vector3.ZERO
	for attempt in range(8):
		var angle := _rng.randf()*TAU
		var reach := _rng.randf_range(SEA_RING.x,SEA_RING.y)
		at = Vector3(eye.x+cos(angle)*reach,SEA_TOP-SEA_DEPTH,eye.z+sin(angle)*reach)
		if _clear(at): break
	return at

## Off the isle (and the kit's far isles, by the cloud host's keeps).
func _clear(at: Vector3) -> bool:
	if scene.has_method("isle_circle"):
		var c: Vector3 = scene.isle_circle()
		if Vector2(at.x-c.x,at.z-c.y).length() < c.z+ISLE_CLEAR: return false
	var host: Node = scene.cloud_host() if scene.has_method("cloud_host") else null
	if host != null:
		for keep: Vector4 in host.get("keep"):
			if Vector2(at.x-keep.x,at.z-keep.y).length() < keep.w: return false
	return true

# --- The developer keys ----------------------------------------------------------------

## F9 the next quarter day, F10 the next weather (Shift: the drift on or
## off), F11 the next season, F12 a strike. Returns what changed, for the
## scene to show, or "" when `event` was none of them.
func key(event: InputEvent) -> String:
	if not event is InputEventKey or not event.pressed or event.echo: return ""
	var shift := (event as InputEventKey).shift_pressed
	match (event as InputEventKey).keycode:
		KEY_F9:
			scene._celestial.next_hour()
			return "On to %02d:00" % int(clock.target_hour if clock.target_hour >= 0.0 else clock.hour)
		KEY_F10:
			if shift:
				drift = not drift
				scheduler.enabled = drift and live
				return "The weather drifts" if scheduler.enabled else "The weather holds"
			var name := scheduler.force_next(weather_hours)
			_ease(name)
			return "Toward %s" % name
		KEY_F11:
			return "Turning toward %s" % next_season()
		KEY_F12:
			strike(scene.camera.global_position)
			return "Lightning"
	return ""

## On to the middle of the next season (living weather's landings), the
## hour kept; the plants walk there (the calendar's glide).
func next_season() -> String:
	var quarter := (clampi(int(fposmod(clock.season,1.0)*4.0),0,3)+1)%4
	var target: float = Living.SEASONS[quarter]
	if clock.season_override >= 0.0:
		clock.season_override = target
	else:
		var day := roundi(target*clock.year_days-clock.hour/WorldClock.HOURS_PER_DAY)
		while day <= clock.day: day += clock.year_days
		clock.set_time(day,clock.hour)
	return WorldClock.SEASON_NAMES[quarter]

## "Day 3 · 14:05 · autumn · rain": for the record.
func label() -> String:
	return "%s · %s · %s" % [clock.label(),clock.season_name(),scheduler.current]
