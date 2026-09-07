extends RefCounted
## Native pond loop: breathe, leap into checked water, paddle, return to own bank.
var frogs: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var _node: MultiMeshInstance3D
var _rings: MultiMeshInstance3D
var _ground: RefCounted
var _water: Array[RefCounted] = []
var _next_ring := 0
var time := 0.0

func setup(geometry: Node3D) -> void:
	_node = geometry.get_node("mesh-40")
	_rings = geometry.get_node("mesh-39")
	_ground = preload("res://scripts/reference_ground.gd").new()
	_ground.setup(geometry.get_node("terrain"))
	for node in geometry.get_children():
		if node.has_meta("water_bed"):
			var sample = preload("res://scripts/reference_ground.gd").new()
			sample.setup(node)
			_water.append(sample)
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/frogs.json"))
	for i in range(data.size()):
		var f: Dictionary = data[i]
		var home := Vector3(f.spot.x, f.spot.y, f.spot.z)
		var ground_height: Variant = _ground.height_at(home.x,home.z)
		if ground_height != null:
			home.y = ground_height + 0.02
		var landing := home
		for reach in [1.1, 0.8, 0.55, 0.35]:
			var candidate := Vector3(home.x-f.spot.nx*reach, f.body.level, home.z-f.spot.nz*reach)
			if is_water(candidate):
				landing = candidate
				break
		frogs.append({"home":home,"landing":landing,"position":home,"from":home,"to":home,"mode":"sit","age":0.0,"wait":4.0+i*3.1,"duration":0.6,"scale":f.scale,"phase":f.phase,"yaw":atan2(-f.spot.nx,-f.spot.nz),"natural":f.natural})
	var mesh := _rings.multimesh.mesh
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.instance_count = 12
	instances.mesh = mesh
	_rings.multimesh = instances
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_contact_ring.gdshader")
	_rings.material_override = material
	_node.extra_cull_margin = 2.0
	_rings.extra_cull_margin = 2.0
	for i in range(12):
		rings.append({"position":Vector3.ZERO,"age":100.0,"size":1.0})
	publish()

func is_water(point: Vector3) -> bool:
	var bed: Variant = _ground.height_at(point.x, point.z)
	if bed != null and bed > point.y - 0.03:
		return false
	for water in _water:
		var height: Variant = water.height_at(point.x, point.z)
		if height != null and absf(height-point.y) < 0.05:
			return true
	return false

func startle() -> void:
	for i in range(frogs.size()):
		if frogs[i].mode == "sit":
			frogs[i].wait = i*0.12

func hop(f: Dictionary, destination: Vector3, mode: String) -> void:
	f.from = f.position
	f.to = destination
	f.mode = mode
	f.age = 0.0
	f.duration = 0.32 + Vector2(destination.x-f.position.x,destination.z-f.position.z).length()*0.28
	f.yaw = atan2(destination.x-f.position.x,destination.z-f.position.z)

func ripple(point: Vector3, size: float) -> void:
	rings[_next_ring] = {"position":point,"age":0.0,"size":size}
	_next_ring = (_next_ring+1)%rings.size()

func advance(delta: float, paused: bool) -> void:
	if paused or not _node.visible:
		return
	var dt := minf(delta,0.05)
	time += dt
	for f in frogs:
		f.age += dt
		if f.mode == "sit":
			f.wait -= dt
			if f.wait <= 0.0 and f.landing != f.home:
				hop(f,f.landing,"in")
		elif f.mode in ["in","out"]:
			var u := minf(1.0,f.age/f.duration)
			f.position = f.from.lerp(f.to,u)
			f.position.y += 4.0*(0.28+f.from.distance_to(f.to)*0.22)*u*(1.0-u)
			if u >= 1.0:
				if f.mode == "in":
					ripple(f.landing,0.7+0.4*f.scale)
					f.mode = "swim"
					f.age = 0.0
				else:
					f.mode = "sit"
					f.wait = 9.0+3.0*sin(f.phase+time)
		elif f.mode == "swim":
			# A small checked paddle stays within this frog's entry pool.
			var candidate: Vector3 = f.landing + Vector3(sin(f.age*1.8)*0.12,0,(1.0-cos(f.age*1.8))*0.1)
			if is_water(candidate):
				f.position = candidate
			f.position.y = f.landing.y-0.08*sin(minf(1.0,f.age/0.4)*PI*0.5)
			if f.age >= 3.5:
				hop(f,f.home,"out")
	for ring in rings:
		ring.age += dt
	publish()

func publish() -> void:
	for i in range(frogs.size()):
		var f := frogs[i]
		var scale: Vector3 = Vector3.ONE*f.scale
		var pitch := 0.0
		if f.mode in ["in","out"]:
			scale *= Vector3(1,0.85,1.35)
			pitch = -(0.5-minf(1.0,f.age/f.duration))*1.2
		elif f.mode == "swim":
			var kick := maxf(0.0,sin(f.age*5.0))
			scale *= Vector3(1.0-0.06*kick,1.0-0.12*kick,1.0+0.3*kick)
		else:
			scale.y *= 1.0+0.05*sin(time*7.0+f.phase)
		if not f.natural:
			scale = Vector3.ONE*0.0001
		_node.multimesh.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(pitch,f.yaw,0),EULER_ORDER_XYZ).scaled(scale),f.position))
	for i in range(rings.size()):
		var ring := rings[i]
		var u := clampf(ring.age/(1.3+ring.size*0.9),0.0,1.0)
		var radius: float = (0.08+sqrt(u)*0.95)*ring.size if u < 1.0 else 0.0001
		_rings.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*radius),ring.position+Vector3(0,0.05,0)))
		_rings.multimesh.set_instance_custom_data(i,Color((1.0-u)*(1.0-u)*0.75,0,0,0))
