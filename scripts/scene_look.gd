class_name SceneLook
extends RefCounted
## Authored base colors. Weather and the hour modulate these without changing them.
signal changed
const SURFACES := ["grass", "foliage", "rock", "earth", "water"]
const DEFAULT_COLORS := {
	"grass":"5d9e53", "foliage":"47764a", "rock":"8d8577", "earth":"6a503e", "water":"397d79",
	"sun":"ffcf8f", "ambient":"8fb3d9", "bounce":"4a5240", "rim":"7fa8c9", "fog":"ffffff",
}
const LIMITS := {"strength":[0.0,1.0], "sun_energy":[0.0,2.0], "ambient_energy":[0.0,2.0], "exposure":[0.5,1.8]}
# Upper sky, horizon, glow, sunlight, grass, rock, water, foliage, earth.
const FAMILIES := {
	"Meadow":["6ca8b8","476d68","c4d8b0","fff2cf","63a85b","959789","529b95","508458","756249"],
	"Summer":["558ebf","465c7c","f6d5a4","ffe0a3","79a848","a7957b","458e92","668545","876449"],
	"Desert":["8c7d97","805f4b","e5ae78","ffcd91","a69b57","ad8969","699f99","8b8750","ad7852"],
	"Heat":["397fb6","5f8fa9","7d9cab","fff0c2","a69b57","ad8969","4b939a","86884c","aa7e56"],
	"Autumn":["696484","554657","dea37d","ffd0a0","a69557","928275","777f88","ae7841","806044"],
	"Winter":["697caa","444d67","b3bfd4","dcecff","6e8990","939eae","6892aa","56777d","79818b"],
	"Dusk":["49345f","53364b","dc927d","ffb690","8a876c","917b88","7a798f","6d6875","826073"],
	"Moonlit":["252a44","2b3448","747d98","b8c9f2","53777a","757888","4e728d","45646c","596171"],
	"Hollow":["294c5d","293841","7caaa3","c6dedc","659d82","738b8c","477f7f","426f61","57695f"],
	"Storm":["3c4659","343f4b","899292","d3dbe1","798369","777c82","587678","526850","63656a"],
	"Dawn":["697aab","665b81","efbcb0","ffe6c0","759d71","9c919b","77999e","5f8069","83706a"],
	"Ocean":["559bbc","39798f","b3d7d4","fff2d0","7ba779","96a6a3","35a6b4","4d897c","ab9677"],
}
# Palette, hour, weather, fog, haze, wind. Moods are explicit editor actions.
const MOODS := {
	"Alpine daylight":["Mountain",0.48,"fair",0.16,0.18,0.9],
	"Meadow morning":["Meadow",0.36,"fair",0.2,0.15,0.65],
	"Desert afternoon":["Desert",0.59,"clear",0.02,0.3,0.55],
	"Autumn evening":["Autumn",0.64,"autumn",0.22,0.25,0.9],
	"Winter hush":["Winter",0.43,"snow",0.3,0.35,0.5],
	"Misty hollow":["Hollow",0.31,"mist",0.85,0.45,0.2],
	"Ocean light":["Ocean",0.46,"fair",0.1,0.18,1.0],
	"Rose dusk":["Dusk",0.71,"clear",0.16,0.2,0.35],
	"Moonlit stillness":["Moonlit",0.02,"clear",0.18,0.08,0.2],
	"Storm gathering":["Storm",0.46,"storm",0.42,0.58,2.5],
}
var palette := "Mountain"
var colors := defaults()
var settings := {"strength":1.0,"sun_energy":1.0,"ambient_energy":1.0,"exposure":1.0}
var _linear := {}
var _ratios := {}

func _init() -> void:
	_cache_colors()

static func defaults() -> Dictionary:
	var result := {}
	for key in DEFAULT_COLORS: result[key] = Color(DEFAULT_COLORS[key])
	# The original dome stores linear values rather than sRGB hex colors.
	result["sky"] = Color(0.1,0.14,0.24).linear_to_srgb()
	result["horizon"] = Color(0.055,0.07,0.1).linear_to_srgb()
	result["glow"] = Color(0.3,0.18,0.14).linear_to_srgb()
	return result

static func palette_names() -> Array:
	return ["Mountain"] + FAMILIES.keys()

static func preset_colors(name: String) -> Dictionary:
	var result := defaults()
	if FAMILIES.has(name):
		var keys := ["sky","horizon","glow","sun","grass","rock","water","foliage","earth"]
		for i in range(keys.size()): result[keys[i]] = Color(FAMILIES[name][i])
		result.ambient = result.sky.lerp(Color("d1dcea"),0.45)
		result.bounce = result.earth.darkened(0.25)
		result.rim = result.sky.lerp(Color("b5c9e3"),0.3)
	return result

func choose(name: String) -> void:
	if name not in palette_names(): return
	palette = name
	colors = preset_colors(name)
	settings.strength = 1.0
	publish()

func set_color(key: String, color: Color) -> void:
	if not colors.has(key): return
	colors[key] = Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1))
	palette = "Custom"
	publish()

func set_value(key: String, value: float) -> void:
	if not LIMITS.has(key) or not is_finite(value): return
	settings[key] = clampf(value,LIMITS[key][0],LIMITS[key][1])
	publish()

func _cache_colors() -> void:
	var bases := defaults()
	for key in colors:
		var base: Color = bases[key].srgb_to_linear()
		var color: Color = base.lerp(colors[key].srgb_to_linear(),settings.strength)
		_linear[key] = Vector3(color.r,color.g,color.b)
		_ratios[key] = _linear[key]/Vector3(base.r,base.g,base.b)

func rgb(key: String) -> Vector3:
	return _linear[key]

func ratio(key: String) -> Vector3:
	return _ratios[key]

func publish() -> void:
	_cache_colors()
	for key in SURFACES: RenderingServer.global_shader_parameter_set("zs_palette_"+key,ratio(key))
	changed.emit()

func document() -> Dictionary:
	var encoded := {}
	for key in colors:
		var c: Color = colors[key]
		encoded[key] = [c.r,c.g,c.b]
	return {"version":1,"palette":palette,"colors":encoded,"settings":settings.duplicate()}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1: return false
	if value.get("palette") not in palette_names()+["Custom"]: return false
	if not value.get("colors") is Dictionary or value.colors.size() != defaults().size(): return false
	for key in defaults():
		var c: Variant = value.colors.get(key)
		if not c is Array or c.size() != 3: return false
		for channel in c:
			if not GardenData._number(channel,0,1): return false
	if not value.get("settings") is Dictionary or value.settings.size() != LIMITS.size(): return false
	for key in LIMITS:
		if not GardenData._number(value.settings.get(key),LIMITS[key][0],LIMITS[key][1]): return false
	return true

func restore(value: Dictionary) -> void:
	if not valid(value): return
	palette = value.palette
	for key in colors:
		var c: Array = value.colors[key]
		colors[key] = Color(c[0],c[1],c[2])
	settings = value.settings.duplicate()
	publish()

## Only scenery opts into material palettes; creatures and flower heads keep their identity.
static func source_roles(geometry: Node3D) -> void:
	var roles := {"terrain":1,"skirt":4,"landmark-arch":3,"mesh-4":3,"mesh-5":3,"mesh-6":3,"mesh-7":3,
		"mesh-8":4,"mesh-9":2,"mesh-10":5,"mesh-11":4,"broadleaf-canopies":2,"mesh-13":2,"mesh-14":2,"mesh-15":5,
		"flower-stems":5,"logs":4,"stumps":4,"snags":4}
	for name in roles:
		var node := geometry.get_node_or_null(NodePath(name))
		if node == null: continue
		var mesh: Mesh = node.multimesh.mesh if node is MultiMeshInstance3D else node.mesh
		var material := mesh.surface_get_material(0) as ShaderMaterial
		if material != null and material.shader.resource_path.ends_with("reference_surface.gdshader"):
			material.set_shader_parameter("palette_role",roles[name])
			material.set_shader_parameter("leaf_season",leaf_season(SOURCE_SEASON_KEYS.get(name,"")))

## Source nodes named by the part key whose seasons they share.
const SOURCE_SEASON_KEYS := {"mesh-8":"trunk","mesh-9":"canopy","mesh-10":"grass","broadleaf-canopies":"broadleaf:broadleaf-canopies","mesh-13":"shrub:mesh-13","flower-stems":"stem"}

## How a part follows the seasons: the `leaf_season` uniform on
## reference_surface and layered_canopy_surface, read against the `zs_season`
## global (shaders/reference_season.gdshaderinc).
## x: turns gold in autumn and fresh in spring; 0 keeps evergreens green.
## y: share of the crown that falls in winter.
## z: share of these plants that blossom in spring.
## w: how far the plant dies back in winter.
## Material parameters only, so new tree and prop variants that reuse these
## keys follow along.
static func leaf_season(key: String) -> Vector4:
	if key in ["canopy","trunk"] or key.begins_with("tree:spruce-") or key.begins_with("redwood:") or key.begins_with("joshua:") or key.begins_with("cactus:"):
		return Vector4.ZERO
	if key in ["broadleaf:broadleaf-canopies","layered_tree:layered-canopies"]: return Vector4(1.0,1.0,0.45,0.0)
	if key.begins_with("shrub:"): return Vector4(1.0,0.55,0.3,0.0)
	if key.begins_with("fern:"): return Vector4(1.0,0.0,0.0,0.6)
	if key in ["petal","stem"] or "flower" in key: return Vector4(1.0,0.0,0.0,1.0)
	if key == "grass" or key.begins_with("grass_tuft:") or key.begins_with("bank_grass:"): return Vector4(1.0,0.0,0.0,0.35)
	return Vector4(1.0,0.0,0.0,0.0)

static func part_role(key: String) -> int:
	if key.begins_with("fern:"): return 5
	if key.begins_with("joshua:"): return preload("res://scripts/hero_trees.gd").JOSHUA[key.get_slice(":",1)][1]
	if key in ["redwood:redwood-trunk","layered_tree:layered-trunk"] or (key.begins_with("layered_tree:") and key.ends_with("-trunk")): return 4
	if key in ["grass","stem"] or "flower-stems" in key or "grass" in key: return 5
	if key == "rock" or key.begins_with("boulder_"): return 3
	if key == "trunk" or (key.begins_with("tree:") and key.ends_with("-trunk")) or key == "leaf_bed" or key.begins_with("log:") or key.begins_with("snag:") or key.begins_with("stump:") or key == "broadleaf:mesh-11": return 4
	if key == "canopy" or "canopies" in key or key.begins_with("shrub:") or key.begins_with("reeds:"): return 2
	return 0
