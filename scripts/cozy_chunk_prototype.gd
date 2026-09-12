extends Node3D
## Throwaway habitat for the cozy-flow study. All edits live in session memory.
const HALF := 5.2
const STEP := 0.4
const CELLS := 26
var snowy := false
var landscape_seed := 12
var layout := 0
var hills: Array[Vector3] = []
var objects: Array[Dictionary] = []
var surface := MeshInstance3D.new()
var scenery := Node3D.new()
var rng := RandomNumberGenerator.new()

func setup(winter: bool, value: int, style := 0) -> void:
	snowy = winter
	add_child(surface)
	add_child(scenery)
	generate(value, style)

func generate(value: int, style: int) -> void:
	landscape_seed = value
	layout = style
	rng.seed = value
	hills.clear()
	objects.clear()
	if style == 1:
		hills.append(Vector3(-2.5, 1.0, -2.4))
		hills.append(Vector3(2.7, 0.7, -1.8))
	if style != 2:
		for i in range(9):
			var point := Vector2(rng.randf_range(-4.4, 4.4), rng.randf_range(-4.2, -1.3))
			if objects.any(func(item: Dictionary) -> bool: return item.point.distance_to(point) < 1.3): continue
			objects.append({"kind":"tree", "point":point, "size":rng.randf_range(0.8, 1.2)})
		objects.append({"kind":"pond", "point":Vector2(2.8, 1.0), "size":1.0})
		objects.append({"kind":"flowers", "point":Vector2(-2.5, 1.8), "size":1.0})
		objects.append({"kind":"log", "point":Vector2(-1.3, -0.8), "size":1.0})
	rebuild()

func snapshot() -> Dictionary:
	return {"seed":landscape_seed, "layout":layout, "hills":hills.duplicate(), "objects":objects.duplicate(true)}

func restore(data: Dictionary) -> void:
	landscape_seed = data.seed
	layout = data.layout
	hills.assign(data.hills)
	objects.assign(data.objects.duplicate(true))
	rebuild()

func contains(point: Vector3, margin := 0.0) -> bool:
	var local := to_local(point)
	return absf(local.x) <= HALF-margin and absf(local.z) <= HALF-margin

func height_at(point: Vector2) -> float:
	var phase := float(landscape_seed % 100) * 0.3
	var h := 0.08 * sin(point.x * 0.65 + phase) * cos(point.y * 0.6)
	if layout == 2: h = 0.0
	for hill in hills:
		h += hill.y * exp(-point.distance_squared_to(Vector2(hill.x, hill.z)) / 3.6)
	return h

func ground(point: Vector3) -> Vector3:
	var local := to_local(point)
	return to_global(Vector3(local.x, height_at(Vector2(local.x, local.z)), local.z))

func is_safe(point: Vector3, radius := 0.48) -> bool:
	if not contains(point, radius): return false
	var local := to_local(point)
	var xz := Vector2(local.x, local.z)
	var center_height := height_at(xz)
	for offset in [Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
		if absf(height_at(xz+offset)-center_height) > 0.22: return false
	for item in objects:
		var clearance: float = {"tree":0.5, "pond":1.35, "log":0.9}.get(item.kind, 0.0)
		if clearance > 0.0 and xz.distance_to(item.point) < clearance * item.size + radius: return false
	return true

func can_place(kind: String, point: Vector3) -> bool:
	var radius: float = {"tree":0.65, "pond":1.6, "log":1.1, "flowers":0.6, "hill":1.4}.get(kind, 0.7)
	if not contains(point, radius): return false
	var local := to_local(point)
	var xz := Vector2(local.x, local.z)
	for item in objects:
		var other: float = {"tree":0.6, "pond":1.4, "log":0.9, "flowers":0.4}.get(item.kind, 0.5)
		if xz.distance_to(item.point) < radius + other: return false
	return true

func place(kind: String, point: Vector3) -> void:
	var local := to_local(point)
	if kind == "hill": hills.append(Vector3(local.x, 0.55, local.z))
	else: objects.append({"kind":kind, "point":Vector2(local.x, local.z), "size":1.0})
	rebuild()

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.86
	return result

func part(mesh: Mesh, at: Vector3, size: Vector3, color: Color, parent: Node3D = scenery) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = at
	node.scale = size
	return node

func orb(at: Vector3, size: Vector3, color: Color, parent: Node3D = scenery) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 6
	return part(sphere, at, size, color, parent)

func rebuild() -> void:
	for child in scenery.get_children():
		scenery.remove_child(child)
		child.queue_free()
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(CELLS):
		for x in range(CELLS):
			var a := Vector2(-HALF+x*STEP, -HALF+z*STEP)
			var b := a+Vector2(STEP, 0)
			var c := a+Vector2(0, STEP)
			var d := a+Vector2(STEP, STEP)
			for v: Vector2 in [a,b,c,b,d,c]:
				var h := height_at(v)
				var grass := Color("9ab777").lerp(Color("b9c991"), clampf(h, 0, 1))
				mesh.set_color((Color("e0e9e4") if snowy else grass).srgb_to_linear())
				mesh.add_vertex(Vector3(v.x, h, v.y))
	# Exposed earth sides make each patch read as a little held world.
	for edge in range(4):
		for i in range(CELLS):
			var a := Vector2(-HALF+i*STEP, -HALF)
			var b := a+Vector2(STEP, 0)
			a = a.rotated(edge*PI/2)
			b = b.rotated(edge*PI/2)
			var top_a := Vector3(a.x, height_at(a), a.y)
			var top_b := Vector3(b.x, height_at(b), b.y)
			var low_a := Vector3(a.x, -1.25, a.y)
			var low_b := Vector3(b.x, -1.25, b.y)
			for v: Vector3 in [top_a,low_a,top_b,top_b,low_a,low_b]:
				mesh.set_color((Color("847461") if v.y > -1 else Color("665b51")).srgb_to_linear())
				mesh.add_vertex(v)
	mesh.generate_normals()
	surface.mesh = mesh.commit()
	var ground_material := material(Color.WHITE)
	ground_material.vertex_color_use_as_albedo = true
	ground_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = ground_material
	rng.seed = landscape_seed
	for item in objects:
		var root := Node3D.new()
		scenery.add_child(root)
		root.position = Vector3(item.point.x, height_at(item.point), item.point.y)
		root.scale = Vector3.ONE * item.size
		match item.kind:
			"tree":
				var trunk := CylinderMesh.new()
				trunk.top_radius = 0.11
				trunk.bottom_radius = 0.19
				trunk.height = 1.8
				part(trunk, Vector3(0,0.9,0), Vector3.ONE, Color("79614c"), root)
				if snowy:
					for j in range(3):
						var cone := CylinderMesh.new()
						cone.top_radius = 0.05
						cone.bottom_radius = 1.05-j*0.22
						cone.height = 1.45
						part(cone, Vector3(0,1.5+j*0.62,0), Vector3.ONE, Color("507b70"), root)
						var cap := cone.duplicate() as CylinderMesh
						cap.bottom_radius *= 0.86
						part(cap, Vector3(0,1.65+j*0.62,0), Vector3.ONE, Color("e8efeb"), root)
				else:
					orb(Vector3(0,2.2,0), Vector3(2.4,1.5,2.0), Color("688e58"), root)
					orb(Vector3(-0.5,2.5,0.1), Vector3(1.5,1.1,1.6), Color("83a36a"), root)
			"pond":
				orb(Vector3(0,0.03,0), Vector3(2.8,0.08,2.25), Color("96c5ce") if snowy else Color("649ea2"), root)
				for j in range(9):
					var angle := float(j)/9*TAU
					orb(Vector3(cos(angle)*1.4,0.06,sin(angle)*1.12), Vector3(0.48,0.25,0.36), Color("c2c4ae"), root)
			"flowers":
				for j in range(13):
					var at := Vector3(rng.randf_range(-0.5,0.5),0.15,rng.randf_range(-0.5,0.5))
					orb(at, Vector3(0.14,0.15,0.14), [Color("eac17b"),Color("e6a292"),Color("f1e9c9")][j%3], root)
			"log":
				var log_mesh := CylinderMesh.new()
				log_mesh.top_radius = 0.26
				log_mesh.bottom_radius = 0.3
				log_mesh.height = 1.5
				var log_node := part(log_mesh, Vector3(0,0.28,0), Vector3.ONE, Color("8c6950"), root)
				log_node.rotation.z = PI/2
