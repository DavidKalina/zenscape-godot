class_name SceneLookPresets
extends RefCounted
## Complete authored looks. Applying one clears the previous season and light overrides.
const Look = preload("res://scripts/scene_look.gd")
const PRESETS := {
	"alpine_morning": {"title":"Alpine morning","description":"Clear blue air. Sunlit stone.","palette":"Mountain","phase":0.40,"weather":"fair","clouds":0.18,"mist":0.12,"haze":0.12,"wind":0.65,
		"strength":0.75,"exposure":1.03,"colors":{"sky":"709ebd","horizon":"64899d","glow":"c5d9dc","water":"438f97"}},
	"golden_meadow": {"title":"Golden meadow","description":"Honey light and soft green hills.","palette":"Summer","phase":0.36,"weather":"clear","clouds":0.12,"mist":0.18,"haze":0.16,"wind":0.4,
		"strength":0.65,"ambient_energy":1.3,"exposure":1.07,"colors":{"sky":"7c9daf","horizon":"9b9082","glow":"f2c294","grass":"92a85c","foliage":"758549","water":"6c9c97"}},
	"copper_autumn": {"title":"Copper autumn","description":"Copper leaves. Clear, gentle light.","palette":"Autumn","phase":0.40,"weather":"autumn","clouds":0.22,"mist":0.17,"haze":0.19,"wind":0.55,
		"strength":0.65,"ambient_energy":1.2,"autumn":0.65,"colors":{"sky":"8795ae","horizon":"8e8590","glow":"e4b995","foliage":"9b804b","water":"78959a"}},
	"rosewater_dusk": {"title":"Rosewater dusk","description":"Blush skies and lavender shadows.","palette":"Dusk","phase":0.69,"weather":"clear","clouds":0.10,"mist":0.2,"haze":0.16,"wind":0.25,
		"strength":0.62,"ambient_energy":1.85,"exposure":1.16,"colors":{"sky":"8676a1","horizon":"a287a4","glow":"eac0b5","grass":"80917b","foliage":"647d76","water":"9a91b1"}},
	"enchanted_forest": {"title":"Enchanted forest","description":"Emerald greens in drifting mist.","palette":"Hollow","phase":0.335,"weather":"mist","clouds":0.3,"mist":0.56,"haze":0.22,"wind":0.28,
		"strength":0.62,"sun_energy":0.9,"exposure":1.06,"colors":{"sky":"6d9aa5","horizon":"557b7d","glow":"bbd3bc","grass":"6c9d7b","foliage":"4d856a","water":"529595"}},
	"halloween_hollow": {"title":"Halloween hollow","description":"Amber leaves in haunted violet mist.","palette":"Autumn","phase":0.055,"weather":"mist","clouds":0.22,"mist":0.60,"haze":0.22,"wind":0.48,
		"strength":0.85,"autumn":0.55,"ambient_energy":1.8,"exposure":1.18,"night_fill":1.35,"colors":{"sky":"49385d","horizon":"625067","glow":"a7795c","grass":"917351","foliage":"cc852f","rock":"706784","earth":"594559","water":"628775","ambient":"b7a0c2","bounce":"786047","rim":"dab27d","fog":"ac83bc"}},
	"first_snow": {"title":"First snow","description":"Pearl light and a soft white coat.","palette":"Winter","phase":0.43,"weather":"snow","clouds":0.59,"mist":0.22,"haze":0.24,"wind":0.4,
		"strength":0.65,"cold":0.92,"snow":0.68,"ice":0.58,"exposure":1.04,"colors":{"sky":"879cb9","horizon":"849aa8","glow":"d8dce7","foliage":"6c8686"}},
	"nordic_night": {"title":"Nordic night","description":"Silver peaks beneath the aurora.","palette":"Moonlit","phase":0.035,"weather":"clear","clouds":0.03,"mist":0.14,"haze":0.07,"wind":0.2,
		"strength":0.55,"ambient_energy":1.5,"exposure":1.18,"night_fill":1.4,"aurora":0.95,"colors":{"sky":"536884","horizon":"526d80","glow":"8d9eae","foliage":"627d7c","water":"6e97ac"}},
	"after_the_rain": {"title":"After the rain","description":"Fresh greens and clearing skies.","palette":"Meadow","phase":0.355,"weather":"fair","clouds":0.29,"mist":0.35,"haze":0.15,"wind":0.5,
		"strength":0.62,"wet":0.55,"humidity":0.75,"rainbow":0.6,"colors":{"sky":"739fb5","horizon":"76949c","glow":"e0d7b7","grass":"70a268","foliage":"528468","water":"619f9f"}},
}
static var _looks := {}

static func look_document(id: String) -> Dictionary:
	if not _looks.has(id):
		var recipe: Dictionary = PRESETS[id]
		var look := Look.new()
		look.palette = "Custom"
		look.colors = Look.preset_colors(recipe.palette)
		for key in recipe.colors: look.colors[key] = Color(recipe.colors[key])
		for key in look.settings: look.settings[key] = recipe.get(key,1.0)
		_looks[id] = look.document()
	return _looks[id].duplicate(true)

static func controls(id: String) -> Dictionary:
	var p: Dictionary = PRESETS[id]
	return {
		"_celestial":{"phase":p.phase,"cycling":false,"night_fill":p.get("night_fill",1.0),"aurora_strength":p.get("aurora",0.0),"rainbow_strength":p.get("rainbow",0.0),"_rainbow_growth":1.0 if p.get("rainbow",0.0)>0 else 0.0,"_target":-1.0},
		"_atmosphere":{"strength":p.wind,"direction_angle":25.0,"_fog_target":p.mist,"_haze_target":p.haze,"summit_mist":0.65,"shroud":0.0,"loosen":0.5,"ray_strength":0.65},
		"_precipitation":{"cloud_override":p.clouds,"cold_override":p.get("cold",0.0)},
		"surface_weather":{"autumn":p.get("autumn",0.0),"target_autumn":p.get("autumn",0.0),"cold":p.get("cold",0.0),"target_cold":p.get("cold",0.0),"ice":p.get("ice",0.0),"snow_cover":p.get("snow",0.0),"ground_wet":p.get("wet",0.0),"air_wet":p.get("humidity",0.0)}
	}

static func apply(scene: Node3D, id: String) -> void:
	if not PRESETS.has(id): return
	var p: Dictionary = PRESETS[id]
	scene._celestial.look.restore(look_document(id))
	scene._precipitation.set_weather(scene._precipitation.PRESET_NAMES.find(p.weather),true)
	var values := controls(id)
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
