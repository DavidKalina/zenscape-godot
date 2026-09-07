extends SceneTree
func _initialize() -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/fall-course-source.json"))
	var ok:=true
	for item in fixture.cases:
		var height_at: Callable
		match item.kind:
			"slope": height_at=func(x: float,z: float): return 0.1+sqrt(x*x+z*z)*0.6
			"apron": height_at=func(x: float,z: float): return 0.1+sqrt(x*x+z*z)*0.07+sin(x*1.7)*cos(z*0.9)*0.02
			"wall": height_at=func(x: float,_z: float): return maxf(0.1,4.0*tanh((x-1.0)*3.0))
			_: height_at=func(x: float,z: float): return 2.0+0.1*((x+8.0)*(x+8.0)+(z-8.0)*(z-8.0))
		var actual: Dictionary=preload("res://scripts/native_fall_strand.gd").build(height_at,item.pool,item.x,item.z,item.target,0.5,0.3,[0.0,0.0,1.0],0.8)
		if item.strand==null:
			ok=ok and actual.is_empty()
			print("Strand ",item.kind," rejected: ",actual.is_empty())
			continue
		var error:=0.0
		for key in item.strand:
			if not actual.has(key) or actual[key].size()!=item.strand[key].size():
				error=INF
				continue
			for i in range(actual[key].size()):
				if actual[key][i] is Array:
					for axis in range(3): error=maxf(error,absf(actual[key][i][axis]-item.strand[key][i][axis]))
				else: error=maxf(error,absf(actual[key][i]-item.strand[key][i]))
		print("Strand ",item.kind," rings ",actual.get("centers",[]).size()," source state max error ",error)
		ok=ok and error<0.00000001
	var ground=preload("res://scripts/reference_source_ground.gd").new()
	ground.setup()
	var expected: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/water-growth.json")).strands
	var actual: Array=preload("res://scripts/native_fall_strand.gd").landscape(ground.height_at,ground.pool,ground.g)
	var error:=0.0
	if actual.size()!=expected.size(): error=INF
	else:
		for n in range(actual.size()):
			for key in ["centers","axA","axB","halfW","thick","steep","aer","tau","impact"]:
				if actual[n][key].size()!=expected[n][key].size():
					error=INF
					continue
				for i in range(actual[n][key].size()):
					if actual[n][key][i] is Array:
						for axis in range(3): error=maxf(error,absf(actual[n][key][i][axis]-expected[n][key][i][axis]))
					else: error=maxf(error,absf(actual[n][key][i]-expected[n][key][i]))
	print("Fidelity strands ",actual.size(),"; complete geometric state max error ",error)
	ok=ok and error<0.00001
	quit(0 if ok else 1)
