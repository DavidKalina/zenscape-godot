class_name NativeTerrainRecipe
extends RefCounted
## Continuous authoring recipe. The mesh still owns sculpted heights.
var settings: Dictionary
var source := preload("res://scripts/reference_source_ground.gd").new()
func _init(value: Dictionary) -> void:
	settings = value.duplicate(true)
	source.setup()
	if settings.kind == "range":
		source.noise_seed += settings.variation
func height(x: float,z: float) -> float:
	var h := 0.6
	if settings.kind == "foundation":
		h += (source.foundation_at(x,z)-0.6)*settings.relief+settings.elevation
	else:
		var angle: float = -settings.heading
		var sx: float = (x*cos(angle)-z*sin(angle))/settings.width
		var sz: float = (x*sin(angle)+z*cos(angle))/settings.width
		h += (source.height_at(sx,sz)-0.6)*settings.height
	return clampf(h,-1.5,24.0)
static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	var limits: Dictionary
	match value.get("kind"):
		"foundation": limits={"elevation":[-1.0,8.0],"relief":[0.0,3.0]}
		"range": limits={"height":[0.1,1.8],"width":[0.3,1.5],"heading":[-PI,PI],"variation":[0,999]}
		_: return false
	if value.size() != limits.size()+1: return false
	for key in limits:
		if not GardenData._number(value.get(key),limits[key][0],limits[key][1]): return false
	return not value.has("variation") or GardenData._integer(value.variation)

static func encode(value: Dictionary) -> Dictionary:
	var record := value.duplicate(true)
	for key in record:
		if key not in ["kind","variation"]:
			record[key] = PackedFloat64Array([float(record[key])]).to_byte_array().hex_encode()
	return record

static func decode(record: Variant) -> Variant:
	if not record is Dictionary: return null
	var result: Dictionary = record.duplicate(true)
	for key in result:
		if key in ["kind","variation"]: continue
		var value: Variant = result[key]
		if not value is String or value.length() != 16: return null
		for character in value:
			if character not in "0123456789abcdef": return null
		result[key] = value.hex_decode().decode_double(0)
	if not valid(result): return null
	if result.has("variation"): result.variation = int(result.variation)
	return result
