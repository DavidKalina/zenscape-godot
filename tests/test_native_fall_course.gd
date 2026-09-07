extends SceneTree
func _initialize() -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/fall-course-source.json"))
	var course=preload("res://scripts/native_fall_course.gd")
	var ok:=true
	for item in fixture.cases:
		var height_at: Callable
		match item.kind:
			"slope": height_at=func(x: float,z: float): return 0.1+sqrt(x*x+z*z)*0.6
			"apron": height_at=func(x: float,z: float): return 0.1+sqrt(x*x+z*z)*0.07+sin(x*1.7)*cos(z*0.9)*0.02
			"wall": height_at=func(x: float,_z: float): return maxf(0.1,4.0*tanh((x-1.0)*3.0))
			_: height_at=func(x: float,z: float): return 2.0+0.1*((x+8.0)*(x+8.0)+(z-8.0)*(z-8.0))
		var result: Dictionary=course.trace(height_at,item.pool,item.x,item.z,item.target,item.pool.waterY)
		var error:=0.0
		if result.pts.size()==item.expected.pts.size():
			for i in range(result.pts.size()):
				for key in ["x","z","h"]: error=maxf(error,absf(result.pts[i][key]-item.expected.pts[i][key]))
		else: error=INF
		for ring in item.rings:
			var sampled: Array=course.resample(result.pts,int(ring.count))
			for i in range(sampled.size()):
				for key in ["x","z","h"]: error=maxf(error,absf(sampled[i][key]-ring.points[i][key]))
		var passed: bool=error<0.00000001 and result.arrived==item.expected.arrived
		print("Fall course ",item.kind," stations ",result.pts.size()," arrived ",result.arrived," max source error ",error)
		ok=ok and passed
	quit(0 if ok else 1)
