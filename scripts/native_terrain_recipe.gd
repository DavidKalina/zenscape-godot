class_name NativeTerrainRecipe
extends RefCounted
## Continuous authoring recipe. The mesh still owns sculpted heights.
const Formation = preload("res://scripts/native_formation_shape.gd")
var formation: RefCounted
var inland: RefCounted
var settings: Dictionary
var source := preload("res://scripts/reference_source_ground.gd").new()
func _init(value: Dictionary) -> void:
	settings = value.duplicate(true)
	if settings.kind == "inland":
		inland = preload("res://scripts/inland_world.gd").new(settings)
	source.setup()
	if settings.kind in ["range","formation"]:
		source.noise_seed += settings.variation
	if settings.kind == "formation":
		formation = Formation.new(settings.family,source,settings.variation)
		if settings.has("water"): formation.connect_water(settings.water == "connected")
func height(x: float,z: float) -> float:
	if inland != null: return inland.height(x,z)
	var h := 0.6
	if settings.kind == "foundation":
		h += (source.foundation_at(x,z)-0.6)*settings.relief+settings.elevation
	else:
		var angle: float = -settings.heading
		var sx: float = (x*cos(angle)-z*sin(angle))/settings.width
		var sz: float = (x*sin(angle)+z*cos(angle))/settings.width
		h += ((formation.height(sx,sz) if formation != null else source.height_at(sx,sz))-0.6)*settings.height
	return clampf(h,-1.5,24.0)
static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if value.get("kind") == "inland":
		var genome = preload("res://scripts/inland_genome.gd")
		if value.size() != 9 or value.get("version") not in [3,4,5,6,7]: return false
		if value.get("composition") == "chasm" and value.get("version") not in [5,6,7]: return false
		if value.get("composition") not in genome.COMPOSITIONS or value.get("archetype") not in genome.ARCHETYPES or value.get("landform") not in genome.LANDFORMS or value.get("biome") not in genome.HABITATS: return false
		return GardenData._integer(value.get("seed")) and GardenData._number(value.seed,0,999999) and GardenData._number(value.get("relief"),0.5,1.8) and GardenData._number(value.get("breadth"),0.6,1.5)
	var limits: Dictionary
	match value.get("kind"):
		"foundation": limits={"elevation":[-1.0,8.0],"relief":[0.0,3.0]}
		"formation":
			if value.get("family") not in Formation.FAMILIES or not Formation.BIOMES.has(value.get("biome")): return false
			limits={"height":[0.1,1.8],"width":[0.3,1.5],"heading":[-PI,PI],"variation":[0,999]}
		"range": limits={"height":[0.1,1.8],"width":[0.3,1.5],"heading":[-PI,PI],"variation":[0,999]}
		_: return false
	if value.has("water") and (value.kind != "formation" or value.water not in ["connected","quiet"]): return false
	if value.size() != limits.size()+(3 if value.kind == "formation" else 1)+(1 if value.has("water") else 0): return false
	for key in limits:
		if not GardenData._number(value.get(key),limits[key][0],limits[key][1]): return false
	return not value.has("variation") or GardenData._integer(value.variation)

static func encode(value: Dictionary) -> Dictionary:
	var record := value.duplicate(true)
	for key in record:
		if key not in ["kind","variation","family","biome","water","version","seed","composition","archetype","landform"]:
			record[key] = PackedFloat64Array([float(record[key])]).to_byte_array().hex_encode()
	return record

static func decode(record: Variant) -> Variant:
	if not record is Dictionary: return null
	var result: Dictionary = record.duplicate(true)
	for key in result:
		if key in ["kind","variation","family","biome","water","version","seed","composition","archetype","landform"]: continue
		var value: Variant = result[key]
		if not value is String or value.length() != 16: return null
		for character in value:
			if character not in "0123456789abcdef": return null
		result[key] = value.hex_decode().decode_double(0)
	if not valid(result): return null
	for key in ["variation","version","seed"]:
		if result.has(key): result[key] = int(result[key])
	return result
