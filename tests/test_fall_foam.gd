extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var geometry = load("res://assets/zen_reference/geometry.scn").instantiate()
	root.add_child(geometry)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/fall-foam.json"))
	var foam = load("res://studies/fall_foam.gd").new()
	foam.setup(geometry,data)
	var worst := 0.0
	for frame: Dictionary in data.frames:
		foam.advance(frame.time,false,frame.ice,smoothstep(0.0,0.5,frame.growth),true)
		for i in range(foam.nodes.size()):
			var node: Node3D = foam.nodes[i]
			var m: Array = frame.transforms[i].matrix
			var expected := Transform3D(Basis(Vector3(m[0],m[1],m[2]),Vector3(m[4],m[5],m[6]),Vector3(m[8],m[9],m[10])),Vector3(m[12],m[13],m[14]))
			worst = maxf(worst,node.position.distance_to(expected.origin))
			for axis in range(3):
				worst = maxf(worst,node.basis[axis].distance_to(expected.basis[axis]))
			check(node.visible == frame.transforms[i].visible,"Source foam growth visibility")
	check(worst < 0.00001,"Foam transforms match original updates: " + str(worst))
	var before: Array[Transform3D] = []
	for node: Node3D in foam.nodes:
		before.append(node.transform)
	foam.advance(100.0,true,0.0,smoothstep(0.0,0.5,0.35),true)
	for i in range(foam.nodes.size()):
		check(foam.nodes[i].transform == before[i],"Pause freezes foam transforms")
	foam.advance(101.0,false,1.0,1.0,false)
	for node: Node3D in foam.nodes:
		check(not node.visible,"Foam waits for terrain")
	foam.advance(102.0,false,1.0,1.0,true)
	for i in range(foam.nodes.size()):
		check(absf(foam.nodes[i].position.y-data.blobs[i].baseY)<0.000001,"Fully frozen foam settles to its base")
	geometry.queue_free()
	await process_frame
	print("PASS: source foam transforms, growth, freeze and pause; max error ",worst) if failures == 0 else print("FAIL: foam")
	quit(1 if failures else 0)
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
