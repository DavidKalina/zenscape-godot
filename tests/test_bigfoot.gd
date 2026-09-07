extends SceneTree
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var rig := preload("res://scripts/reference_bigfoot.gd").new()
	root.add_child(rig)
	rig.setup()
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bigfoot/poses.json"))
	var worst := 0.0
	var failures := 0
	for fixture: Dictionary in fixtures:
		rig.pose(fixture.kind, fixture.time, Vector3(2, 3, 8), {}, {-1: -0.08, 1: 0.05})
		for key: String in fixture.transforms:
			var m: Array = fixture.transforms[key]
			var expected := Transform3D(Basis(Vector3(m[0],m[1],m[2]), Vector3(m[4],m[5],m[6]), Vector3(m[8],m[9],m[10])), Vector3(m[12],m[13],m[14]))
			var actual: Transform3D = rig.joints[int(key)].transform
			var error := maxf(actual.origin.distance_to(expected.origin), maxf(actual.basis.x.distance_to(expected.basis.x), maxf(actual.basis.y.distance_to(expected.basis.y), actual.basis.z.distance_to(expected.basis.z))))
			worst = maxf(worst, error)
			if error > 0.0001:
				failures += 1
				print("FAIL ", fixture.kind, " ", fixture.time, " joint ", key, " error ", error)
	print("Bigfoot: ", fixtures.size() * rig.joints.size(), " source joint transforms; worst error ", worst, "; failures ", failures)
	quit(1 if failures else 0)
