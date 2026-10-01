extends Node
## Moods: the nine authored looks (scripts/scene_look_presets.gd) as one quick
## choice, with opt-in controls on top. A mood gives every control its starting
## value; a control the player sets is pinned and survives later moods until
## Back to mood (`clear_pins`). Every change cross-fades over FADE_SECONDS.
##
## The tables below are the whole vocabulary (moods, controls, options,
## swatches); scripts/mood_panel.gd only draws them, so a restyle replaces the
## panel and keeps this. See docs/scenic/mood.md.
const Presets = preload("res://scripts/scene_look_presets.gd")
const Look = preload("res://scripts/scene_look.gd")
const Living = preload("res://scripts/living_weather.gd")

signal changed

const FADE_SECONDS := 1.2
## The season each mood was painted for: its gold, cold and palette belong to it.
const MOOD_SEASONS := {"alpine_morning":"summer","golden_meadow":"summer","copper_autumn":"autumn","rosewater_dusk":"spring",
	"enchanted_forest":"summer","halloween_hollow":"autumn","first_snow":"winter","nordic_night":"winter","after_the_rain":"spring",
	"rose_dusk":"spring","meadow_morning":"spring","desert_afternoon":"summer","autumn_evening":"autumn","winter_hush":"winter",
	"misty_hollow":"autumn","ocean_light":"summer","moonlit_stillness":"winter","storm_gathering":"autumn"}
## Moods defined by their hour: they hold it even where the day turns. Every
## other mood, on a world whose day turns (the creation plain), sets its hour
## as the time now and lets the day carry on from there.
const HOUR_MOODS := ["nordic_night","rosewater_dusk","halloween_hollow","rose_dusk","moonlit_stillness"]
## Customise, in drawer order. `colors` is one control per COLORS key.
const CONTROLS := [
	{"id":"season","title":"Season"},
	{"id":"time","title":"Time of day"},
	{"id":"weather","title":"Weather"},
	{"id":"rock_type","title":"Rock"},
	{"id":"colors","title":"Colours"},
]
const SEASONS := [{"id":"spring","title":"Spring"},{"id":"summer","title":"Summer"},{"id":"autumn","title":"Autumn"},{"id":"winter","title":"Winter"}]
## A held hour, or the day turning on its own (`phase` < 0).
const TIMES := [
	{"id":"dawn","title":"Dawn","phase":0.275},
	{"id":"morning","title":"Morning","phase":0.345},
	{"id":"midday","title":"Midday","phase":0.47},
	{"id":"golden","title":"Golden hour","phase":0.645},
	{"id":"dusk","title":"Dusk","phase":0.705},
	{"id":"night","title":"Night","phase":0.035},
	{"id":"turning","title":"Turning day","phase":-1.0},
]
const WEATHERS := [{"id":"clear","title":"Clear"},{"id":"fair","title":"Fair"},{"id":"overcast","title":"Overcast"},{"id":"mist","title":"Mist"},
	{"id":"rain","title":"Rain"},{"id":"storm","title":"Storm"},{"id":"snow","title":"Snow"},{"id":"autumn","title":"Leaf fall"}]
## Rock faces are live: the terrain shader's treatment and detail, and a base
## colour (a pinned rock colour wins over it). No regeneration.
const ROCK_TYPES := [
	{"id":"granite","title":"Granite","style":0,"detail":0.55,"color":"9b958b"},
	{"id":"slate","title":"Slate","style":1,"detail":0.9,"color":"5e6570"},
	{"id":"sandstone","title":"Sandstone","style":1,"detail":0.75,"color":"b88c63"},
	{"id":"basalt","title":"Basalt","style":2,"detail":0.6,"color":"4d4b4f"},
]
## Look colour keys the drawer offers, with a few curated swatches each.
const COLORS := [
	{"id":"grass","title":"Grass","swatches":["5d9e53","79a848","6c9d7b","a69557","80917b","9a86b8"]},
	{"id":"foliage","title":"Leaves","swatches":["47764a","758549","4d856a","cc852f","9b804b","8b6aa6"]},
	{"id":"rock","title":"Rock","swatches":["8d8577","959789","5e6570","b88c63","706784","4d4b4f"]},
	{"id":"earth","title":"Earth","swatches":["6a503e","876449","ad7852","594559","57695f","79818b"]},
	{"id":"water","title":"Water","swatches":["397d79","438f97","35a6b4","6e97ac","9a91b1","628775"]},
	{"id":"sky","title":"Sky","swatches":["78aacb","709ebd","7c9daf","8676a1","49385d","536884"]},
	{"id":"fog","title":"Mist","swatches":["ffffff","e8e2d4","d6e4ec","ac83bc","eac0b5","bcd9c4"]},
]
## The prevailing wind's strengths, weakest first (design "ZenScape HUD 5
## Air", docs/design/hud-5/lowpoly.js WINDS and WIND_DROOP): the one table the
## almanac's Wind pocket (its windsock) and the Customise page's Wind row both
## read, so a chip and the sock always agree. `strength` is the atmosphere's
## `strength` a chip sets (the weather keeps it within 0.12 to 1.4; the sky's
## held sweep reaches 0.15 to 1.3, scripts/sky_wind.gd STRENGTH); `droop` is
## degrees the windsock hangs below level. A strength in between reads as the
## nearest (`wind_strength_id`).
##
## Wind is not in CONTROLS, so the old drawers (mood_panel, lantern_mood) do
## not grow a row they cannot draw; it pins like any control all the same,
## "<strength id>@<degrees>" (`wind_pin`), where degrees is the atmosphere's
## `direction_angle`, the way it blows on the ground (world x, z).
const WIND_STRENGTHS := [
	{"id":"calm","title":"Calm","strength":0.15,"droop":40.0},
	{"id":"light","title":"Light","strength":0.4,"droop":22.0},
	{"id":"brisk","title":"Brisk","strength":0.8,"droop":10.0},
	{"id":"gale","title":"Gale","strength":1.3,"droop":0.0},
]
## A pinned Time of day that holds any hour (`held_hour`): this prefix, then the phase.
const HELD_HOUR := "at:"
## Winter frost laid on the ground when a pinned winter replaces a mood's own season.
const WINTER_SNOW := 0.45
## Continuous state the cross-fade blends, by owner.
const FLOATS := {
	"_celestial":["night_fill","aurora_strength","rainbow_strength","_rainbow_growth"],
	"_atmosphere":["strength","_air_strength","fog_amount","_fog_target","haze_amount","_haze_target","summit_mist","ray_strength","shroud","loosen"],
	"surface_weather":["autumn","target_autumn","cold","target_cold","ice","snow_cover","ground_wet","air_wet"],
	"_world_visuals":["fog_density","fog_height","peak_density","peak_altitude","rock_detail","weather_fog","weather_peaks"],
}

var scene: Node3D
## A PRESETS id, or "" for the world's own look (`origin`).
var mood := ""
## Control id -> value: SEASONS/TIMES/WEATHERS/ROCK_TYPES ids, or "rrggbb" for COLORS keys.
var pins := {}
## The world as it was before the first mood or pin: what "" returns to.
var origin := {}
## Pinning the weather held the living drift; unpinning lets it go again.
var held_drift := false
var _from := {}
var _to := {}
var _t := 0.0
## Microseconds of the last rebuild and the slowest fade frame, for probes.
var last_build_usec := 0
var max_fade_usec := 0

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene

# --- Vocabulary ---------------------------------------------------------------

static func mood_ids() -> Array:
	return Presets.PRESETS.keys()

static func mood_title(id: String) -> String:
	return str(Presets.PRESETS[id].title) if Presets.PRESETS.has(id) else "This world"

static func mood_description(id: String) -> String:
	return str(Presets.PRESETS[id].description) if Presets.PRESETS.has(id) else "The look this world was made with."

## The options a choice control offers: [{id, title}].
static func options(control: String) -> Array:
	match control:
		"season": return SEASONS
		"time": return TIMES
		"weather": return WEATHERS
		"rock_type": return ROCK_TYPES
	return []

static func option(control: String, id: String) -> Dictionary:
	if control == "time" and id.begins_with(HELD_HOUR):
		var phase := id.substr(HELD_HOUR.length())
		if not phase.is_valid_float() or float(phase) < 0.0 or float(phase) >= 1.0: return {}
		return {"id":id,"title":"Held hour","phase":float(phase)}
	for entry: Dictionary in options(control):
		if entry.id == id: return entry
	return {}

## A Time of day pin for any hour, not one of TIMES: the sun dragged to it
## (scripts/hand_reach.gd). "at:0.5230" holds that phase.
static func held_hour(phase: float) -> String:
	return HELD_HOUR+("%.4f" % clampf(fposmod(phase,1.0),0.0,0.9999))

## The WIND_STRENGTHS entry nearest `strength`.
static func wind_strength(strength: float) -> Dictionary:
	var best: Dictionary = WIND_STRENGTHS[0]
	for entry: Dictionary in WIND_STRENGTHS:
		if absf(float(entry.strength)-strength) < absf(float(best.strength)-strength): best = entry
	return best

static func wind_strength_id(strength: float) -> String:
	return str(wind_strength(strength).id)

## A Wind pin: a WIND_STRENGTHS id and the direction it blows (degrees, the
## atmosphere's `direction_angle`), rounded to a whole degree.
static func wind_pin(strength_id: String, degrees: float) -> String:
	return "%s@%d" % [strength_id,roundi(fposmod(degrees,360.0))%360]

## A Wind pin read back: {id, strength, degrees}, or {} when malformed.
static func wind_parts(pin_value: String) -> Dictionary:
	var parts := pin_value.split("@")
	if parts.size() != 2 or not parts[1].is_valid_int(): return {}
	var degrees := int(parts[1])
	if degrees < 0 or degrees >= 360: return {}
	for entry: Dictionary in WIND_STRENGTHS:
		if entry.id == parts[0]: return {"id":entry.id,"strength":float(entry.strength),"degrees":float(degrees)}
	return {}

static func color_keys() -> Array:
	return COLORS.map(func(entry: Dictionary) -> String: return entry.id)

static func swatches(key: String) -> Array:
	for entry: Dictionary in COLORS:
		if entry.id == key: return entry.swatches
	return []

## A mood's chip: upper sky, horizon glow and grass. "" reads the world's origin.
func chip_colors(id: String) -> Array[Color]:
	var document: Dictionary = Presets.look_document(id) if Presets.PRESETS.has(id) else origin.get("look",{})
	var result: Array[Color] = []
	for key in ["sky","glow","grass"]:
		var c: Array = document.get("colors",{}).get(key,[0.5,0.5,0.5])
		result.append(Color(c[0],c[1],c[2]))
	return result

# --- State the panel reads -----------------------------------------------------

func pinned(control: String) -> bool:
	return pins.has(control)

## What a control shows now: its pin, or the mood's (or world's) own value.
## Choices answer an option id ("" when none matches), colours "rrggbb".
func value(control: String) -> String:
	if pins.has(control): return str(pins[control])
	if control in color_keys(): return scene._celestial.look.colors[control].to_html(false)
	match control:
		"wind": return wind_pin(wind_strength_id(float(scene._atmosphere.strength)),float(scene._atmosphere.direction_angle))
		"season": return WorldClock.name_for_season(scene.world_clock.season)
		"weather": return str(scene._precipitation.PRESET_NAMES[scene._precipitation.preset_index])
		"time":
			if scene.world_clock.running: return "turning"
			for entry: Dictionary in TIMES:
				if entry.phase >= 0.0 and absf(angle_difference(entry.phase*TAU,scene._celestial.phase*TAU)) < 0.01*TAU: return entry.id
	return ""

## True while a regrowth or carry owns the world.
func busy() -> bool:
	var places: Node = scene.get("places")
	return places != null and (places.busy or places.holding)

# --- Changes -------------------------------------------------------------------

func choose(id: String, fade := true) -> void:
	if id != "" and not Presets.PRESETS.has(id): return
	if id == "" and origin.is_empty(): return
	if busy(): return
	_remember_origin()
	mood = id
	_rebuild(fade)

func pin(control: String, pin_value: String, fade := true) -> void:
	if busy() or not _valid_pin(control,pin_value): return
	_remember_origin()
	pins[control] = pin_value
	# A colour dragged in the picker lands directly; nothing else depends on it.
	if not fade and control in color_keys() and _to.is_empty():
		scene._celestial.look.set_color(control,Color(pin_value))
		changed.emit()
		return
	# So does the wind's dial: the air eases round to it at its own pace.
	if not fade and control == "wind" and _to.is_empty():
		_apply_wind()
		scene._sync_saved_controls()
		changed.emit()
		return
	_rebuild(fade)

func unpin(control: String) -> void:
	if busy() or not pins.has(control): return
	pins.erase(control)
	_rebuild(true)

## The sun let go at an hour (scripts/hand_reach.gd): pin Time of day to it
## as a held hour. The hour is already on screen, so nothing is rebuilt: only
## the pin and the held clock, which a later rebuild applies the same way. A
## running fade lands on the new hour too.
func pin_hour(phase: float) -> void:
	if busy(): return
	_remember_origin()
	var id := held_hour(phase)
	pins["time"] = id
	var held: float = option("time",id).phase
	scene._celestial.cycling = false
	scene._celestial.set_phase(held)
	if not _to.is_empty():
		_to.phase = held
		_to.running = false
		_from.phase = held
	scene._sync_saved_controls()
	changed.emit()

## Back to mood: every control follows the mood again.
func clear_pins() -> void:
	if busy() or pins.is_empty(): return
	pins.clear()
	_rebuild(true)

## A new world: its own look, nothing pinned.
func reset() -> void:
	mood = ""
	pins.clear()
	origin.clear()
	_to.clear()
	if held_drift and scene.get("weather_scheduler") != null: _let_drift()
	held_drift = false
	changed.emit()

func _remember_origin() -> void:
	if origin.is_empty(): origin = snapshot()

# --- Building the target -------------------------------------------------------

func _rebuild(fade: bool) -> void:
	var started := Time.get_ticks_usec()
	var from := snapshot() if fade else {}
	var surface: RefCounted = scene._precipitation.surface_weather
	var base_season := str(MOOD_SEASONS.get(mood,"summer"))
	if mood.is_empty():
		_restore_snapshot(origin)
		base_season = WorldClock.name_for_season(float(origin.season))
	else:
		_apply_preset(mood)
		# The preset holds its hour; a turning day keeps turning from it.
		if turns_day(mood): scene._celestial.cycling = true
		var visuals: Node3D = scene._world_visuals
		visuals.rock_style = int(origin.rock_style)
		visuals.rock_detail = float(origin.floats.get("_world_visuals:rock_detail",visuals.rock_detail))
	_apply_weather()
	var season := str(pins.get("season",base_season))
	var quarter := maxi(SEASONS.map(func(s: Dictionary) -> String: return s.id).find(season),0)
	var clock: WorldClock = scene.world_clock
	clock.season_override = float(origin.season_override) if mood.is_empty() and not pins.has("season") else Living.SEASONS[quarter]
	var strip := season != base_season
	if strip:
		# A season other than the mood's own: the season, not the mood, owns the gold and cold.
		var profile: Dictionary = scene._precipitation.profiles[scene._precipitation.PRESET_NAMES[scene._precipitation.preset_index]]
		scene._precipitation.cold_override = -1.0
		surface.target_autumn = 0.0 if scene.get("living_weather") != null else float(profile.autumn)
		surface.target_cold = float(profile.cold)
	scene._season_shown = clock.season
	scene._apply_season(0.0)
	if strip:
		surface.autumn = surface.target_autumn
		surface.cold = surface.target_cold
		surface.snow_cover = WINTER_SNOW if quarter == 3 else 0.0
		surface.ice = smoothstep(0.35,0.7,surface.cold)
	var time: Dictionary = option("time",str(pins.get("time","")))
	if not time.is_empty():
		if time.phase < 0.0: scene._celestial.cycling = true
		else:
			scene._celestial.cycling = false
			scene._celestial.set_phase(time.phase)
	var rock: Dictionary = option("rock_type",str(pins.get("rock_type","")))
	var look: SceneLook = scene._celestial.look
	if not rock.is_empty():
		scene._world_visuals.rock_style = int(rock.style)
		scene._world_visuals.rock_detail = float(rock.detail)
		if not pins.has("rock"): look.colors.rock = Color(rock.color)
	for key in color_keys():
		if pins.has(key): look.colors[key] = Color(pins[key])
	if not rock.is_empty() or color_keys().any(func(key: String) -> bool: return pins.has(key)): look.palette = "Custom"
	look.publish()
	if pins.has("weather"):
		if scene.weather_scheduler.enabled: held_drift = true
		scene.weather_scheduler.enabled = false
	elif held_drift:
		_let_drift()
		held_drift = false
	scene._sync_saved_controls()
	if fade:
		_to = snapshot()
		_from = from
		_t = 0.0
		max_fade_usec = 0
		_blend(_from,_to,0.0)
	else:
		_to.clear()
	last_build_usec = Time.get_ticks_usec()-started
	changed.emit()

## True when `id` leaves the day turning: the world's own day turned before
## any mood (the creation plain) and the mood is not one of HOUR_MOODS. A
## pinned Time of day still wins, since it is applied after the mood.
func turns_day(id: String) -> bool:
	return id != "" and id not in HOUR_MOODS and bool(origin.get("running",false))

## The pinned wind set on the atmosphere as its targets: the air eases to
## them (studies/atmosphere.gd), and a cross-fade blends them.
func _apply_wind() -> void:
	var wind := wind_parts(str(pins.get("wind","")))
	if wind.is_empty(): return
	scene._atmosphere.strength = wind.strength
	scene._atmosphere.direction_angle = wind.degrees

func _let_drift() -> void:
	var living: RefCounted = scene.get("living_weather")
	scene.weather_scheduler.enabled = living == null or living.drift

## SceneLookPresets.apply without its full scene step: the fade and the next
## frame publish everything it would.
func _apply_preset(id: String) -> void:
	var p := Presets.recipe(id)
	var precipitation: Node3D = scene._precipitation
	scene._celestial.look.restore(Presets.look_document(id))
	precipitation.set_weather(precipitation.PRESET_NAMES.find(p.weather),true)
	var values := Presets.controls(id)
	for group in values:
		var object: Object = precipitation.surface_weather if group == "surface_weather" else scene.get(group)
		for key in values[group]: object.set(key,values[group][key])
	var atmosphere: Node3D = scene._atmosphere
	atmosphere._air_strength = p.wind
	atmosphere._air_angle = deg_to_rad(atmosphere.direction_angle)
	atmosphere.set_fog(p.mist)
	atmosphere.set_haze(p.haze)
	atmosphere.set_rays(atmosphere.ray_strength)
	scene._celestial.set_phase(p.phase)

## A pinned weather keeps the mood's own air, moved by the difference between
## the two skies the way living weather drifts (scripts/living_weather.gd).
## Either way the drift restarts from the sky that results.
func _apply_weather() -> void:
	var precipitation: Node3D = scene._precipitation
	var atmosphere: Node3D = scene._atmosphere
	var surface: RefCounted = precipitation.surface_weather
	var base: String = precipitation.PRESET_NAMES[precipitation.preset_index]
	var air := {"wind":atmosphere.strength,"cloud":precipitation.cloud_override if precipitation.cloud_override >= 0.0 else precipitation.state.z,
		"mist":atmosphere._fog_target,"haze":atmosphere._haze_target}
	var name := str(pins.get("weather",base))
	var wind := wind_parts(str(pins.get("wind","")))
	if name != base:
		var gold := [surface.autumn,surface.target_autumn]
		var cold := maxf(surface.target_cold,precipitation.cold_override)
		var profiles: Dictionary = precipitation.profiles
		var from: Dictionary = profiles[base]
		var to: Dictionary = profiles[name]
		precipitation.set_weather(precipitation.PRESET_NAMES.find(name),true)
		air.cloud = clampf(float(to.cloud)+float(air.cloud)-float(from.cloud),0.0,1.0)
		precipitation.state.z = air.cloud
		precipitation.target.z = air.cloud
		air.wind = clampf(float(air.wind)+(float(to.wind)-float(from.wind))*0.5,0.12,1.4)
		air.mist = clampf(float(air.mist)+float(Living.MIST.get(name,0.16))-float(Living.MIST.get(base,0.16)),0.02,0.8)
		air.haze = clampf(float(air.haze)+(float(to.haze)-float(from.haze))*0.5,0.05,0.6)
		atmosphere.strength = air.wind
		atmosphere._air_strength = air.wind
		atmosphere.set_fog(air.mist)
		atmosphere.set_haze(air.haze)
		surface.autumn = gold[0]
		surface.target_autumn = gold[1]
		surface.target_cold = maxf(surface.target_cold,cold)
		surface.cold = surface.target_cold
	# A pinned wind wins over the mood's and the weather's, and the drift
	# starts from it.
	if not wind.is_empty():
		air.wind = wind.strength
		_apply_wind()
	var living: RefCounted = scene.get("living_weather")
	if living != null and (mood != "" or name != base or not wind.is_empty()):
		var fog: float = scene._world_visuals.weather_fog
		var peaks: float = scene._world_visuals.weather_peaks
		var clock_pin: float = scene.world_clock.season_override
		living.establish({"seed":0,"mood":{"weather":name,"wind":air.wind,"clouds":air.cloud,"mist":air.mist,"haze":air.haze}})
		# establish() resets these for a fresh world; a mood keeps the world's own.
		scene._world_visuals.weather_fog = fog
		scene._world_visuals.weather_peaks = peaks
		scene.world_clock.season_override = clock_pin

# --- Snapshots and the fade ------------------------------------------------------

func _object(group: String) -> Object:
	return scene._precipitation.surface_weather if group == "surface_weather" else scene.get(group)

## Everything a mood touches, JSON-safe: the look document, the blended
## floats, and the discrete choices a fade sets once.
func snapshot() -> Dictionary:
	var precipitation: Node3D = scene._precipitation
	var atmosphere: Node3D = scene._atmosphere
	var floats := {}
	for group: String in FLOATS:
		var object := _object(group)
		for key: String in FLOATS[group]: floats[group+":"+key] = float(object.get(key))
	var state: Vector4 = precipitation.state
	var target: Vector4 = precipitation.target
	var scheduler: WeatherScheduler = scene.weather_scheduler
	return {"look":scene._celestial.look.document(),"floats":floats,"phase":scene._celestial.phase,"season":scene.world_clock.season,
		"state":[state.x,state.y,state.z,state.w],"target":[target.x,target.y,target.z,target.w],
		"direction_angle":atmosphere.direction_angle,"air_angle":atmosphere._air_angle,
		"cloud_override":precipitation.cloud_override,"cold_override":precipitation.cold_override,
		"weather":precipitation.PRESET_NAMES[precipitation.preset_index],"rock_style":scene._world_visuals.rock_style,
		"running":scene.world_clock.running,"season_override":scene.world_clock.season_override,
		"origin_weather":scheduler.origin,"origin_mood":scheduler.origin_mood.duplicate()}

func _restore_snapshot(value: Dictionary) -> void:
	var precipitation: Node3D = scene._precipitation
	precipitation.preset_index = maxi(precipitation.PRESET_NAMES.find(value.weather),0)
	precipitation.cloud_override = float(value.cloud_override)
	precipitation.cold_override = float(value.cold_override)
	scene._world_visuals.rock_style = int(value.rock_style)
	scene.world_clock.running = bool(value.running)
	scene.world_clock.season_override = float(value.season_override)
	var scheduler: WeatherScheduler = scene.weather_scheduler
	scheduler.origin = str(value.origin_weather)
	scheduler.origin_mood = value.origin_mood.duplicate()
	scheduler.set_current(str(value.weather),scheduler.now_hour())
	_blend(value,value,1.0)

func _blend(a: Dictionary, b: Dictionary, w: float) -> void:
	var look: SceneLook = scene._celestial.look
	for key in look.colors:
		var ca: Array = a.look.colors[key]
		var cb: Array = b.look.colors[key]
		look.colors[key] = Color(ca[0],ca[1],ca[2]).lerp(Color(cb[0],cb[1],cb[2]),w)
	for key in look.settings: look.settings[key] = lerpf(float(a.look.settings[key]),float(b.look.settings[key]),w)
	look.palette = b.look.palette if w >= 1.0 else "Custom"
	for path: String in b.floats:
		_object(path.get_slice(":",0)).set(path.get_slice(":",1),lerpf(float(a.floats.get(path,b.floats[path])),float(b.floats[path]),w))
	var precipitation: Node3D = scene._precipitation
	var sa: Array = a.state
	var sb: Array = b.state
	var ta: Array = a.target
	var tb: Array = b.target
	precipitation.state = Vector4(sa[0],sa[1],sa[2],sa[3]).lerp(Vector4(sb[0],sb[1],sb[2],sb[3]),w)
	precipitation.target = Vector4(ta[0],ta[1],ta[2],ta[3]).lerp(Vector4(tb[0],tb[1],tb[2],tb[3]),w)
	# Overrides blend through what they stand for, then land on the raw value.
	if w >= 1.0:
		precipitation.cloud_override = float(b.cloud_override)
		precipitation.cold_override = float(b.cold_override)
	else:
		precipitation.cloud_override = lerpf(_cloud(a),_cloud(b),w)
		precipitation.cold_override = lerpf(_cold(a),_cold(b),w)
	var atmosphere: Node3D = scene._atmosphere
	atmosphere.direction_angle = rad_to_deg(lerp_angle(deg_to_rad(float(a.direction_angle)),deg_to_rad(float(b.direction_angle)),w))
	atmosphere._air_angle = lerp_angle(float(a.air_angle),float(b.air_angle),w)
	atmosphere.set_rays(atmosphere.ray_strength)
	var clock: WorldClock = scene.world_clock
	var season := fposmod(lerp_angle(float(a.season)*TAU,float(b.season)*TAU,w)/TAU,1.0)
	clock.season_override = float(b.season_override) if w >= 1.0 else season
	scene._season_shown = clock.season if w >= 1.0 else season
	var phase := fposmod(lerp_angle(float(a.phase)*TAU,float(b.phase)*TAU,w)/TAU,1.0)
	# A turning day keeps its own time once the fade lands.
	if not (w >= 1.0 and clock.running): scene._celestial.set_phase(phase)
	look.publish()
	precipitation.surface_weather.publish()

func _cloud(value: Dictionary) -> float:
	return float(value.cloud_override) if float(value.cloud_override) >= 0.0 else float(value.state[2])

func _cold(value: Dictionary) -> float:
	return float(value.cold_override) if float(value.cold_override) >= 0.0 else float(value.floats["surface_weather:target_cold"])

func fading() -> bool:
	return not _to.is_empty()

## Land a running fade now, so a save never stores a sky halfway between moods.
func finish_fade() -> void:
	if _to.is_empty(): return
	_blend(_from,_to,1.0)
	_to.clear()

func _process(delta: float) -> void:
	if _to.is_empty(): return
	var started := Time.get_ticks_usec()
	_t = minf(_t+maxf(delta,0.0)/FADE_SECONDS,1.0)
	_blend(_from,_to,smoothstep(0.0,1.0,_t))
	if _t >= 1.0: _to.clear()
	max_fade_usec = maxi(max_fade_usec,Time.get_ticks_usec()-started)

# --- Save ------------------------------------------------------------------------

func document() -> Dictionary:
	return {"version":1,"mood":mood,"pins":pins.duplicate(),"origin":origin.duplicate(true),"held_drift":held_drift}

## Saves from before moods have no entry and open on their own look.
func restore_document(value: Dictionary) -> void:
	_to.clear()
	if not valid(value):
		mood = ""
		pins.clear()
		origin.clear()
		held_drift = false
	else:
		mood = str(value.mood)
		pins = value.pins.duplicate()
		origin = value.origin.duplicate(true)
		held_drift = bool(value.get("held_drift",false))
	changed.emit()

static func _valid_pin(control: String, pin_value: Variant) -> bool:
	if not pin_value is String: return false
	if control in color_keys(): return pin_value.is_valid_html_color() and not pin_value.begins_with("#")
	if control == "wind": return not wind_parts(pin_value).is_empty()
	return not option(control,pin_value).is_empty()

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1: return false
	if not value.get("mood") is String or (value.mood != "" and not Presets.PRESETS.has(value.mood)): return false
	if not value.get("pins") is Dictionary or not value.get("origin") is Dictionary: return false
	if value.has("held_drift") and not value.held_drift is bool: return false
	for key in value.pins:
		if not key is String or not _valid_pin(key,value.pins[key]): return false
	if value.origin.is_empty(): return value.mood == "" and value.pins.is_empty()
	return valid_snapshot(value.origin)

static func valid_snapshot(value: Dictionary) -> bool:
	if not Look.valid(value.get("look")) or not value.get("floats") is Dictionary: return false
	for group: String in FLOATS:
		for key: String in FLOATS[group]:
			if not GardenData._number(value.floats.get(group+":"+key),-1e6,1e6): return false
	for key in ["phase","season","direction_angle","air_angle","cloud_override","cold_override","season_override"]:
		if not GardenData._number(value.get(key),-1e6,1e6): return false
	for key in ["state","target"]:
		if not value.get(key) is Array or value[key].size() != 4: return false
		for number in value[key]:
			if not GardenData._number(number,-1e6,1e6): return false
	if not value.get("weather") in WEATHERS.map(func(w: Dictionary) -> String: return w.id): return false
	if not GardenData._integer(value.get("rock_style")) or int(value.rock_style) > 2: return false
	return value.get("running") is bool and value.get("origin_weather") is String and value.get("origin_mood") is Dictionary
