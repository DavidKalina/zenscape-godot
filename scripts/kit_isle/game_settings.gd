extends RefCounted
## The game's settings (docs/design/consolidation-audit.md, round 2): what
## the old game's Settings dialog offered (studies/diorama.gd), kept where
## it kept them and applied through the same pieces, so a choice made in
## either game holds in both. The look: visual quality (scripts/look_pass.gd
## `apply_tier`), render resolution (scripts/render_resolution.gd), the
## clouds, the night sky and the planet (look_pass `set_cloud_style`,
## `set_night_style`, `set_sky_planet`), all in user://look.cfg. The sound:
## the Master volume, the Sound bus (scripts/genesis_audio.gd's Genesis bus:
## steps, tokens, life's one-shots) and Mute, in user://sound.cfg. The pad's
## vibration (scripts/pad.gd), in user://pad.cfg. The sky's time and
## weather (docs/design/consolidation-audit.md, round 4; scripts/kit_isle/
## kit_weather.gd): how long a day lasts or that it holds, and whether the
## weather drifts and the season (Live or held at one), new to the kit (the old game had a Day/night checkbox in
## its look editor only), kept in user://look.cfg under [time].
##
## Every setting is a choice among named options, held as an index
## (`index_of`, `choose`), so the settings sheet (scripts/kit_isle/
## settings_menu.gd) steps them the same way with the keys, the mouse and the
## pad. A volume is ten steps of 10%. `choose` saves at once and applies
## live where it can: the tier, the resolution, the sound and the vibration
## always; the clouds, the night and the planet on the isle's look pass,
## which a headless run doesn't build (kit_isle.gd `_looks`), so there they
## are only saved, for the next rendered start. Visual quality had no saved
## value in the old game (each world kept its own); it's kept here under
## [quality] tier, Balanced (the kit's tier) until the player chooses.
##
## The paths are vars so tests write elsewhere.

const LookPass = preload("res://scripts/look_pass.gd")
const RenderResolution = preload("res://scripts/render_resolution.gd")
const Audio = preload("res://scripts/genesis_audio.gd")
const Pad = preload("res://scripts/pad.gd")
const KitWeather = preload("res://scripts/kit_isle/kit_weather.gd")

const TIERS := ["Beauty","Balanced","Ultra"]
const DEFAULT_TIER := 1
const OFF_ON := ["Off","On"]
const STEPS := 10
## Each setting: its key, its title, its options' names (null: a volume in
## STEPS steps), and the group it sits under on the sheet.
const ENTRIES := [
	{"key":"quality","title":"Visual quality","options":TIERS,"group":"Look"},
	{"key":"resolution","title":"Render resolution","options":RenderResolution.CAP_NAMES,"group":"Look"},
	{"key":"clouds","title":"Clouds","options":LookPass.CLOUD_STYLE_NAMES,"group":"Look"},
	{"key":"night","title":"Night sky","options":LookPass.NIGHT_STYLE_NAMES,"group":"Look"},
	{"key":"planet","title":"Planet in the night sky","options":OFF_ON,"group":"Look"},
	{"key":"day","title":"Day and night","options":KitWeather.DAY_NAMES,"group":"Look"},
	{"key":"weather","title":"Weather","options":KitWeather.DRIFT_NAMES,"group":"Look"},
	{"key":"season","title":"Season","options":KitWeather.SEASON_CHOICES,"group":"Look"},
	{"key":"master","title":"Volume","options":null,"group":"Sound"},
	{"key":"sound","title":"Steps, tokens and life","options":null,"group":"Sound"},
	{"key":"muted","title":"Mute all sound","options":OFF_ON,"group":"Sound"},
	{"key":"vibration","title":"Controller vibration","options":OFF_ON,"group":"Controls"},
]

static var look_path := LookPass.SETTINGS_PATH
static var sound_path := Audio.SETTINGS_PATH
static var pad_path := Pad.SETTINGS_PATH

static func entry(key: String) -> Dictionary:
	for e: Dictionary in ENTRIES:
		if e.key == key: return e
	return {}

## The names a setting steps through.
static func options(key: String) -> Array:
	var given: Variant = entry(key).get("options")
	if given != null: return given
	var out := []
	for i in range(STEPS+1): out.append("%d%%" % (i*100/STEPS))
	return out

## The setting's kept choice, as an index into `options`.
static func index_of(key: String) -> int:
	match key:
		"quality":
			var file := ConfigFile.new()
			if file.load(look_path) != OK: return DEFAULT_TIER
			return clampi(int(file.get_value("quality","tier",DEFAULT_TIER)),0,TIERS.size()-1)
		"resolution": return maxi(RenderResolution.CAPS.find(RenderResolution.load_cap(look_path)),0)
		"clouds": return maxi(LookPass.CLOUD_STYLES.find(LookPass.load_cloud_style(look_path)),0)
		"night": return maxi(LookPass.NIGHT_STYLES.find(LookPass.load_night_style(look_path)),0)
		"planet": return 1 if LookPass.load_sky_planet(look_path) else 0
		"day","weather","season":
			var file := ConfigFile.new()
			if file.load(look_path) != OK: return 0
			return clampi(int(file.get_value("time",key,0)),0,options(key).size()-1)
		"master","sound": return roundi(float(sound()[key])*STEPS)
		"muted": return 1 if bool(sound().muted) else 0
		"vibration": return 1 if vibration() else 0
	return 0

## The kept sound settings (genesis_audio's keys and defaults).
static func sound() -> Dictionary:
	var settings: Dictionary = Audio.DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if file.load(sound_path) == OK:
		settings.master = clampf(float(file.get_value("sound","master",settings.master)),0.0,1.0)
		settings.muted = bool(file.get_value("sound","muted",settings.muted))
		settings.sound = clampf(float(file.get_value("sound","sound",settings.sound)),0.0,1.0)
	return settings

static func vibration() -> bool:
	var file := ConfigFile.new()
	return file.load(pad_path) != OK or bool(file.get_value("pad","vibration",true))

## Keeps option `index` of setting `key` and applies it: to `isle`'s look
## pass when it has one, else to the window.
static func choose(key: String, index: int, isle: Node = null) -> void:
	index = clampi(index,0,options(key).size()-1)
	var look: Node = isle.get("_look") if isle != null else null
	match key:
		"quality":
			_keep(look_path,"quality","tier",index)
			if look != null: look.apply_tier(index)
		"resolution":
			var cap: int = RenderResolution.CAPS[index]
			RenderResolution.save_cap(cap,look_path)
			var viewport: Viewport = isle.get_viewport() if isle != null and isle.is_inside_tree() else (Engine.get_main_loop() as SceneTree).root
			RenderResolution.apply(viewport,cap)
		"clouds":
			LookPass.save_cloud_style(LookPass.CLOUD_STYLES[index],look_path)
			if look != null: look.set_cloud_style(LookPass.CLOUD_STYLES[index],false)
		"night":
			LookPass.save_night_style(LookPass.NIGHT_STYLES[index],look_path)
			if look != null: look.set_night_style(LookPass.NIGHT_STYLES[index],false)
		"planet":
			_keep(look_path,"sky","planet",index == 1)
			if look != null: look.set_sky_planet(index == 1,false)
		"day","weather","season":
			_keep(look_path,"time",key,index)
			_apply_time(isle)
		"master","sound","muted":
			var settings := sound()
			settings[key] = (index == 1) if key == "muted" else float(index)/STEPS
			var file := ConfigFile.new()
			for name: String in settings: file.set_value("sound",name,settings[name])
			file.save(sound_path)
			Audio.apply_settings(settings)
		"vibration":
			_keep(pad_path,"pad","vibration",index == 1)
			Pad._vibration = index == 1

## What the isle doesn't read for itself at its start: the sound, the
## visual quality and the time and weather (the look pass reads its clouds,
## night and planet, and render_resolution its cap, from user://look.cfg as
## they're made).
static func apply_start(isle: Node) -> void:
	Audio.apply_settings(sound())
	Pad._vibration = vibration()
	var look: Node = isle.get("_look") if isle != null else null
	if look != null: look.apply_tier(index_of("quality"))
	_apply_time(isle)

## The kept day length, drift and season on `isle`'s time and weather, if it has
## them (a flag that set either keeps its own).
static func _apply_time(isle: Node) -> void:
	var weather: Variant = isle.get("weather") if isle != null else null
	if not (weather is Node and (weather as Node).has_method("choose_day")): return
	weather.choose_day(index_of("day"))
	weather.choose_drift(index_of("weather") == 0)
	weather.choose_season(index_of("season"))

static func _keep(path: String, section: String, name: String, value: Variant) -> void:
	var file := ConfigFile.new()
	file.load(path)
	file.set_value(section,name,value)
	file.save(path)
