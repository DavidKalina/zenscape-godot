extends Node3D
## A cutaway chamber using Fidelity's rock palette and existing water effects.
## Seed changes dressing, never the dry bed or puddle footprint.
const LAYER := 4
var bed := Marker3D.new()
var drips := preload("res://scripts/waterfall_drips.gd").new()
var dressing := Node3D.new()
var palette := preload("res://scripts/native_terrain_palette.gd").new()
var seed_value := 37

func _ready() -> void:
	add_child(bed)
	bed.position = Vector3(-2.2,0.15,-0.6)
	add_child(dressing)
	add_child(drips)
	_build_floor()
	_build_walls()
	_build_puddle()
	_build_bed()
	redress(seed_value)
	for spec in [[Vector3(-3,5,4),Color("e8c695"),2.0],[Vector3(3,3,-2),Color("78a9b6"),1.4]]:
		var light := OmniLight3D.new()
		light.position = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		light.omni_range = 14.0
		light.light_cull_mask = LAYER
		add_child(light)
	_layers(self)

func _layers(root: Node) -> void:
	if root is VisualInstance3D: root.layers = LAYER
	for child in root.get_children(): _layers(child)

func _mesh(surface: SurfaceTool, parent: Node = self) -> MeshInstance3D:
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.95
	node.material_override = material
	parent.add_child(node)
	node.layers = LAYER
	return node

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	for point in [a,b,c]: st.add_vertex(point)

func floor_height(x: float, z: float) -> float:
	var basin := Vector2(x-2.7,z-0.8).length()
	if basin<1.8: return -0.42*(1.0-smoothstep(0.8,1.8,basin))
	if Vector2(x+2.2,z+0.6).length()<1.7: return 0.1
	return (palette.noise.fbm(x*0.8,z*0.8)-0.5)*0.16

func _build_floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-6,6):
		for z in range(-4,4):
			var corners: Array[Vector3] = []
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var point: Vector2 = Vector2(x,z)+offset
				corners.append(Vector3(point.x,floor_height(point.x,point.y),point.y))
			var color := palette.rock_at(Vector2(x,z))*Color(0.75,0.72,0.68)
			_triangle(st,corners[0],corners[2],corners[1],color)
			_triangle(st,corners[0],corners[3],corners[2],color.lightened(0.025))
	# A thick exposed geological edge makes the room read as a diorama slice.
	for x in range(-6,6):
		var a := Vector3(x,floor_height(x,4),4)
		var b := Vector3(x+1,floor_height(x+1,4),4)
		_triangle(st,a,b,Vector3(x,-0.9,4),Color("514738"))
		_triangle(st,b,Vector3(x+1,-0.9,4),Vector3(x,-0.9,4),Color("514738"))
	_mesh(st)

func _build_walls() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(18):
		var a := PI+PI*float(i)/18.0
		var b := PI+PI*float(i+1)/18.0
		var low_a := Vector3(cos(a)*6,0,sin(a)*4)
		var low_b := Vector3(cos(b)*6,0,sin(b)*4)
		var mid_a := low_a*0.98+Vector3.UP*(2.1+sin(i*2.1)*0.2)
		var mid_b := low_b*0.98+Vector3.UP*(2.1+sin((i+1)*2.1)*0.2)
		var top_a := low_a*0.82+Vector3.UP*(4.5+sin(i*1.7)*0.25)
		var top_b := low_b*0.82+Vector3.UP*(4.5+sin((i+1)*1.7)*0.25)
		var color := palette.rock_at(Vector2(i,9))*Color(0.65,0.68,0.7)
		for points in [[low_a,low_b,mid_a],[low_b,mid_b,mid_a],[mid_a,mid_b,top_a],[mid_b,top_b,top_a]]:
			_triangle(st,points[0],points[1],points[2],color.lightened(0.015*(i%3)))
		# A short roof lip leaves the front cut away for inspection.
		_triangle(st,top_a,top_b,top_a+Vector3(0,-0.18,0.85),color.darkened(0.15))
		_triangle(st,top_b,top_b+Vector3(0,-0.18,0.85),top_a+Vector3(0,-0.18,0.85),color)
	var roof_color := palette.rock_at(Vector2(9,9))*Color(0.65,0.68,0.7)
	var roof_back := Vector3(2.2,4.3,-2.8)
	var roof_left := Vector3(2.3,4.2,1.15)
	var roof_right := Vector3(3.65,4.2,0.9)
	_triangle(st,roof_back,roof_left,roof_right,roof_color)
	_triangle(st,roof_back,roof_right,Vector3(4.0,4.4,-2.0),roof_color.lightened(0.035))
	_mesh(st)

func _build_puddle() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(2.7,-0.13,0.8)
	for i in range(28):
		var a := TAU*i/28.0
		var b := TAU*(i+1)/28.0
		var radius_a := 1.25+0.08*sin(a*3.0)+0.04*cos(a*5.0)
		var radius_b := 1.25+0.08*sin(b*3.0)+0.04*cos(b*5.0)
		_triangle(st,center,center+Vector3(cos(b),0,sin(b))*radius_b,center+Vector3(cos(a),0,sin(a))*radius_a,Color.WHITE)
	var node := _mesh(st)
	node.name = "CavePuddle"
	var water := ShaderMaterial.new()
	water.shader = preload("res://shaders/garden_water.gdshader")
	node.material_override = water
	drips.add_emitter(Vector3(2.7,3.5,0.8),center+Vector3.UP*0.025)
	drips.add_emitter(Vector3(3.2,3.7,0.5),Vector3(3.2,-0.105,0.5))

func _build_bed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in range(40):
		var leaf := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radial_segments = 5
		shape.rings = 2
		shape.radius = 0.4
		shape.height = 0.8
		leaf.mesh = shape
		leaf.position = bed.position+Vector3(rng.randf_range(-1.2,1.2),-0.01,rng.randf_range(-0.75,0.75))
		leaf.scale = Vector3(1,0.12,0.5)
		leaf.rotation.y = rng.randf_range(0,TAU)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("776944").lightened(rng.randf_range(-0.12,0.12))
		leaf.material_override = mat
		add_child(leaf)

func _spike(point: Vector3, length: float, radius: float, hanging: bool) -> void:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 5
	mesh.rings = 1
	mesh.top_radius = radius if hanging else 0.025
	mesh.bottom_radius = 0.025 if hanging else radius
	mesh.height = length
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = point+Vector3.UP*length*(-0.5 if hanging else 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("837b69")
	mat.roughness = 0.9
	node.material_override = mat
	dressing.add_child(node)
	node.layers = LAYER

func redress(value: int) -> void:
	seed_value = value
	for child in dressing.get_children():
		dressing.remove_child(child)
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	for i in range(24):
		var angle := rng.randf_range(PI+0.12,TAU-0.12)
		var point := Vector3(cos(angle)*4.9,4.2,sin(angle)*3.3+0.25)
		_spike(point,rng.randf_range(0.45,1.6),rng.randf_range(0.16,0.35),true)
	for i in range(10):
		var angle := rng.randf_range(PI+0.1,TAU-0.1)
		_spike(Vector3(cos(angle)*5.2,0,sin(angle)*3.4),rng.randf_range(0.3,0.9),0.25,false)
	# Fixed drip sources belong to the fixed puddle, not randomized decoration.
	_spike(Vector3(2.7,4.2,0.8),0.7,0.25,true)
	_spike(Vector3(3.2,4.2,0.5),0.5,0.18,true)
