extends RefCounted
## Plain bounded course records. Hex doubles preserve authored routes through JSON.
static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=6: return false
	for key in ["width","depth","surface"]:
		if not GardenData._number(value.get(key),0.01,10.0): return false
	for key in ["capHead","capTail"]:
		if not value.get(key) is bool: return false
	var points: Variant=value.get("pts")
	if not points is Array or points.size()<2 or points.size()>1024: return false
	for i in range(points.size()):
		var p: Variant=points[i]
		if not p is Dictionary or p.size()!=3: return false
		for key in ["x","z","h"]:
			if not GardenData._number(p.get(key),-14.0 if key!="h" else -1.5,14.0 if key!="h" else 66.0): return false
		if i>0 and (p.h>points[i-1].h+0.00001 or preload("res://scripts/native_stream_geometry.gd").distance(p,points[i-1])<0.00001): return false
	return true
static func encode(value: Dictionary) -> Dictionary:
	var result:=value.duplicate(true)
	for key in ["width","depth","surface"]: result[key]=_encode(result[key])
	for p in result.pts:
		for key in ["x","z","h"]: p[key]=_encode(p[key])
	return result
static func decode(value: Variant) -> Variant:
	if not value is Dictionary: return null
	var result: Dictionary=value.duplicate(true)
	for key in ["width","depth","surface"]:
		result[key]=_decode(result.get(key))
	if not result.get("pts") is Array or result.pts.size()>1024: return null
	for p in result.pts:
		if not p is Dictionary: return null
		for key in ["x","z","h"]: p[key]=_decode(p.get(key))
	return result if valid(result) else null
static func _encode(value: float) -> String:
	return PackedFloat64Array([value]).to_byte_array().hex_encode()
static func _decode(value: Variant) -> Variant:
	if not value is String or value.length()!=16: return null
	for c in value:
		if c not in "0123456789abcdef": return null
	return value.hex_decode().decode_double(0)
