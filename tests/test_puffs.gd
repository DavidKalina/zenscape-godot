extends SceneTree
var failures := 0
func _initialize() -> void:
	var puffs = load("res://studies/wind_puffs.gd").new()
	var samples = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/puff-checks.json"))
	var positions := [Vector2(-4,0), Vector2(0,0), Vector2(8,3), Vector2(20,-2)]
	var travel := 0.0
	for sample in samples:
		if sample.op.has("puff"):
			var p = sample.op.puff
			puffs.puff(Vector2(p[0],p[1]), Vector2.RIGHT, travel, 0.4, p[2])
		else:
			travel += (1.6 + 1.9 * 0.4) * sample.op.advance
			puffs.retire(travel)
		for i in range(6):
			var p = sample.parcels[i]
			check(puffs.parcels[i].distance_to(Vector4(p[0],p[1],p[2],p[3])) < 0.00002, "Source parcel slot matches through merge, replacement and retirement")
		for i in range(positions.size()):
			check(absf(puffs.sample_at(positions[i], Vector2.RIGHT, travel) - sample.field[i]) < 0.00002, "Source traveling parcel field")
	var atmosphere = load("res://studies/atmosphere.gd").new()
	atmosphere.send_gust(Vector3.ZERO)
	var before: PackedVector4Array = atmosphere.puffs.parcels.duplicate()
	atmosphere.advance(3.0, true)
	check(before == atmosphere.puffs.parcels and atmosphere._gust_distance == 0.0, "Pause holds parcel age")
	atmosphere.free()
	print("PASS: source puff lifecycle, merge, six-slot replacement, field and pause" if failures == 0 else "FAIL: puffs")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
