class_name NativeObjectPose
extends RefCounted
## Exact float32 basis and float64 vertical offset for authored asset placement.
static func make(basis: Basis, offset: float) -> Dictionary:
	return {"basis":PackedFloat32Array([basis.x.x,basis.x.y,basis.x.z,basis.y.x,basis.y.y,basis.y.z,basis.z.x,basis.z.y,basis.z.z]).to_byte_array().hex_encode(),"offset":PackedFloat64Array([offset]).to_byte_array().hex_encode()}
static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=2: return false
	for key in ["basis","offset"]:
		var item: Variant=value.get(key)
		if not item is String or item.length()!=(72 if key=="basis" else 16): return false
		for character in item:
			if character not in "0123456789abcdef": return false
	var numbers: PackedFloat32Array=value.basis.hex_decode().to_float32_array()
	for number in numbers:
		if not is_finite(number) or absf(number)>25.0: return false
	var transform := decode_basis(value)
	return absf(transform.determinant())>0.000001 and GardenData._number(decode_offset(value),-5.0,10.0)
static func decode_basis(value: Dictionary) -> Basis:
	var a: PackedFloat32Array=value.basis.hex_decode().to_float32_array()
	return Basis(Vector3(a[0],a[1],a[2]),Vector3(a[3],a[4],a[5]),Vector3(a[6],a[7],a[8]))
static func decode_offset(value: Dictionary) -> float:
	return value.offset.hex_decode().decode_double(0)

static func encode_tint(color: Color) -> String:
	return PackedFloat32Array([color.r,color.g,color.b]).to_byte_array().hex_encode()
static func valid_tint(value: Variant) -> bool:
	if not value is String or value.length()!=24: return false
	for character in value:
		if character not in "0123456789abcdef": return false
	for number in value.hex_decode().to_float32_array():
		if not is_finite(number) or number<0.0 or number>1.0: return false
	return true
static func decode_tint(value: String) -> Color:
	var a: PackedFloat32Array=value.hex_decode().to_float32_array()
	return Color(a[0],a[1],a[2])
