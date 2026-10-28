class_name SceneLookPresets
extends RefCounted
## Complete authored looks. Applying one clears the previous season and light overrides.
const Look = preload("res://scripts/scene_look.gd")
const PRESETS := {
	"alpine_morning": {"title":"Alpine morning","description":"Clear blue air. Sunlit stone.","palette":"Mountain","phase":0.40,"weather":"fair","clouds":0.18,"mist":0.12,"haze":0.12,"wind":0.65,
		"strength":0.75,"exposure":1.03,"colors":{"sky":"709ebd","horizon":"64899d","glow":"c5d9dc","water":"438f97"}},
	"golden_meadow": {"title":"Golden meadow","description":"Honey light and soft green hills.","palette":"Summer","phase":0.36,"weather":"clear","clouds":0.12,"mist":0.18,"haze":0.16,"wind":0.4,
		"strength":0.65,"sun_energy":1.24,"ambient_energy":1.3,"exposure":1.07,"colors":{"sky":"7c9daf","horizon":"9b9082","glow":"f2c294","sun":"ffc480","grass":"92a85c","foliage":"758549","water":"6c9c97"}},
	"copper_autumn": {"title":"Copper autumn","description":"Copper leaves. Clear, gentle light.","palette":"Autumn","phase":0.40,"weather":"autumn","clouds":0.22,"mist":0.17,"haze":0.19,"wind":0.55,
		"strength":0.65,"ambient_energy":1.2,"autumn":0.65,"colors":{"sky":"8795ae","horizon":"8e8590","glow":"e4b995","foliage":"9b804b","water":"78959a"}},
	"rosewater_dusk": {"title":"Rosewater dusk","description":"Blush skies and lavender shadows.","palette":"Dusk","phase":0.69,"weather":"clear","clouds":0.10,"mist":0.2,"haze":0.16,"wind":0.25,
		"strength":0.62,"ambient_energy":1.85,"exposure":1.16,"colors":{"sky":"8676a1","horizon":"a287a4","glow":"eac0b5","grass":"80917b","foliage":"647d76","water":"9a91b1"}},
	"enchanted_forest": {"title":"Enchanted forest","description":"Emerald greens in drifting mist.","palette":"Hollow","phase":0.335,"weather":"mist","clouds":0.3,"mist":0.56,"haze":0.22,"wind":0.28,
		"strength":0.62,"sun_energy":0.9,"exposure":1.06,"colors":{"sky":"6d9aa5","horizon":"557b7d","glow":"bbd3bc","grass":"6c9d7b","foliage":"4d856a","water":"529595"}},
	"halloween_hollow": {"title":"Halloween hollow","description":"Amber leaves in haunted violet mist.","palette":"Autumn","phase":0.055,"weather":"mist","clouds":0.22,"mist":0.60,"haze":0.22,"wind":0.48,
		"strength":0.85,"autumn":0.55,"ambient_energy":1.8,"exposure":1.18,"night_fill":1.35,"night_look":0.7,"colors":{"sky":"49385d","horizon":"625067","glow":"a7795c","grass":"917351","foliage":"cc852f","rock":"706784","earth":"594559","water":"628775","ambient":"b7a0c2","bounce":"786047","rim":"dab27d","fog":"ac83bc"}},
	"first_snow": {"title":"First snow","description":"Pearl light and a soft white coat.","palette":"Winter","phase":0.43,"weather":"snow","clouds":0.59,"mist":0.22,"haze":0.24,"wind":0.4,
		"strength":0.65,"cold":0.92,"snow":0.68,"ice":0.58,"exposure":1.04,"colors":{"sky":"879cb9","horizon":"849aa8","glow":"d8dce7","foliage":"6c8686"}},
	"nordic_night": {"title":"Nordic night","description":"Silver peaks beneath the aurora.","palette":"Moonlit","phase":0.035,"weather":"clear","clouds":0.03,"mist":0.14,"haze":0.07,"wind":0.2,
		"strength":0.55,"ambient_energy":1.5,"exposure":1.18,"night_fill":1.4,"aurora":0.95,"colors":{"sky":"536884","horizon":"526d80","glow":"8d9eae","foliage":"627d7c","water":"6e97ac"}},
	"after_the_rain": {"title":"After the rain","description":"Fresh greens and clearing skies.","palette":"Meadow","phase":0.355,"weather":"fair","clouds":0.29,"mist":0.35,"haze":0.15,"wind":0.5,
		"strength":0.62,"wet":0.55,"humidity":0.75,"rainbow":0.6,"colors":{"sky":"739fb5","horizon":"76949c","glow":"e0d7b7","grass":"70a268","foliage":"528468","water":"619f9f"}},
	# The editor's whole moods (SceneLook.MOODS), once only behind the World
	# menu's Colors & sky: each family's own colours at full strength, as
	# `apply_scene_mood` set them. Alpine daylight is Alpine morning's.
	"rose_dusk": {"title":"Rose dusk","description":"Deep rose light over violet hills.","palette":"Dusk","phase":0.71,"weather":"clear","clouds":0.12,"mist":0.16,"haze":0.2,"wind":0.35,
		"strength":1.0,"colors":{}},
	"meadow_morning": {"title":"Meadow morning","description":"Cool green light, the dew still on.","palette":"Meadow","phase":0.36,"weather":"fair","clouds":0.22,"mist":0.2,"haze":0.15,"wind":0.65,
		"strength":1.0,"colors":{}},
	"desert_afternoon": {"title":"Desert afternoon","description":"Dry gold air and long warm stone.","palette":"Desert","phase":0.59,"weather":"clear","clouds":0.06,"mist":0.02,"haze":0.3,"wind":0.55,
		"strength":1.0,"colors":{}},
	"autumn_evening": {"title":"Autumn evening","description":"Low amber sun through turning leaves.","palette":"Autumn","phase":0.64,"weather":"autumn","clouds":0.22,"mist":0.22,"haze":0.25,"wind":0.9,
		"strength":1.0,"autumn":0.6,"colors":{}},
	"winter_hush": {"title":"Winter hush","description":"Blue cold and falling snow.","palette":"Winter","phase":0.43,"weather":"snow","clouds":0.6,"mist":0.3,"haze":0.35,"wind":0.5,
		"strength":1.0,"cold":0.85,"snow":0.55,"ice":0.4,"colors":{}},
	"misty_hollow": {"title":"Misty hollow","description":"Teal mist pooled in the low ground.","palette":"Hollow","phase":0.31,"weather":"mist","clouds":0.35,"mist":0.85,"haze":0.45,"wind":0.2,
		"strength":1.0,"colors":{}},
	"ocean_light": {"title":"Ocean light","description":"Bright sea air and turquoise water.","palette":"Ocean","phase":0.46,"weather":"fair","clouds":0.2,"mist":0.1,"haze":0.18,"wind":1.0,
		"strength":1.0,"colors":{}},
	"moonlit_stillness": {"title":"Moonlit stillness","description":"Blue night, the aurora overhead.","palette":"Moonlit","phase":0.02,"weather":"clear","clouds":0.05,"mist":0.18,"haze":0.08,"wind":0.2,
		"strength":1.0,"aurora":0.65,"colors":{}},
	# The amberlands' (scripts/endless/world/amberlands/look.gd): a low, soft
	# gold sun through a warm haze that greys the distance, a grey-blue upper
	# sky, muted shade.
	"amber_hour": {"title":"Amber hour","description":"Soft late gold through a warm haze.","palette":"Amber","phase":0.696,"weather":"clear","clouds":0.08,"mist":0.12,"haze":0.32,"wind":0.45,
		"strength":1.0,"ambient_energy":1.0,"exposure":1.04,"colors":{"ambient":"a8acb4","bounce":"6e665a","rim":"e8d4b0","fog":"e6e2dc"}},
	"storm_gathering": {"title":"Storm gathering","description":"Slate skies and a rising wind.","palette":"Storm","phase":0.46,"weather":"storm","clouds":0.8,"mist":0.42,"haze":0.58,"wind":2.5,
		"strength":1.0,"wet":0.5,"humidity":0.8,"colors":{}},
}
# World presets can specialize a look without changing the standalone Looks gallery.
static var _looks := {}

static func recipe(id: String, overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = PRESETS[id].duplicate(true)
	for key in overrides:
		if key == "colors": result.colors.merge(overrides.colors,true)
		else: result[key] = overrides[key]
	return result

static func look_document(id: String, overrides: Dictionary = {}) -> Dictionary:
	if overrides.is_empty() and _looks.has(id): return _looks[id].duplicate(true)
	var p := recipe(id,overrides)
	var look := Look.new()
	look.palette = "Custom"
	look.colors = Look.preset_colors(p.palette)
	for key in p.colors: look.colors[key] = Color(p.colors[key])
	for key in look.settings: look.settings[key] = p.get(key,1.0)
	var document := look.document()
	if overrides.is_empty(): _looks[id] = document.duplicate(true)
	return document

static func controls(id: String, overrides: Dictionary = {}) -> Dictionary:
	var p := recipe(id,overrides)
	return {
		"_celestial":{"phase":p.phase,"cycling":false,"night_fill":p.get("night_fill",1.0),"night_look":p.get("night_look",1.0),"aurora_strength":p.get("aurora",0.0),"rainbow_strength":p.get("rainbow",0.0),"_rainbow_growth":1.0 if p.get("rainbow",0.0)>0 else 0.0,"_target":-1.0},
		"_atmosphere":{"strength":p.wind,"direction_angle":p.get("wind_direction",25.0),"_fog_target":p.mist,"_haze_target":p.haze,"summit_mist":p.get("summit_mist",0.65),"shroud":0.0,"loosen":0.5,"ray_strength":p.get("rays",0.65)},
		"_precipitation":{"cloud_override":p.clouds,"cold_override":p.get("cold",0.0)},
		"surface_weather":{"autumn":p.get("autumn",0.0),"target_autumn":p.get("autumn",0.0),"cold":p.get("cold",0.0),"target_cold":p.get("cold",0.0),"ice":p.get("ice",0.0),"snow_cover":p.get("snow",0.0),"ground_wet":p.get("wet",0.0),"air_wet":p.get("humidity",0.0)}
	}

static func apply(scene: Node3D, id: String, overrides: Dictionary = {}) -> void:
	if not PRESETS.has(id): return
	var p := recipe(id,overrides)
	scene._celestial.look.restore(look_document(id,overrides))
	scene._precipitation.set_weather(scene._precipitation.PRESET_NAMES.find(p.weather),true)
	var values := controls(id,overrides)
	for group in values:
		var object: Object = scene._precipitation.surface_weather if group == "surface_weather" else scene.get(group)
		for key in values[group]: object.set(key,values[group][key])
	scene._atmosphere._air_strength = p.wind
	scene._atmosphere._air_angle = deg_to_rad(scene._atmosphere.direction_angle)
	scene._atmosphere.set_fog(p.mist)
	scene._atmosphere.set_haze(p.haze)
	scene._atmosphere.set_rays(scene._atmosphere.ray_strength)
	scene._celestial.set_phase(p.phase)
	scene._process(0.0)
	scene._sync_saved_controls()

## Compare authored choices, not wetness/snow that naturally evolves after selection.
static func matches(scene: Node3D, id: String) -> bool:
	if scene._celestial.look.document() != look_document(id): return false
	var values := controls(id)
	for group in ["_celestial","_atmosphere","_precipitation"]:
		var object: Object = scene.get(group)
		for key in values[group]:
			if key in ["_rainbow_growth","_target"]: continue
			var expected: Variant = values[group][key]
			if expected is bool:
				if object.get(key) != expected: return false
			elif not is_equal_approx(float(object.get(key)),float(expected)): return false
	return scene._precipitation.PRESET_NAMES[scene._precipitation.preset_index] == PRESETS[id].weather and is_equal_approx(scene._precipitation.surface_weather.target_autumn,values.surface_weather.target_autumn)
