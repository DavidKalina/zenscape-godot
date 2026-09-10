extends Node3D
## Full-footprint lower story: thick rock walls with permanent viewing openings.
## Seed changes dressing, never the dry bed or puddle footprint.
const LAYER := 4
const HALF_WIDTH := 14.2
const CEILING := 8.3
const BED_POINT := Vector3(-6.0,0.15,8.0)
const POOL_POINT := Vector3(5.0,-0.13,7.5)
var bed := Marker3D.new()
var drips := preload("res://scripts/waterfall_drips.gd").new()
var dressing := Node3D.new()
var palette := preload("res://scripts/native_terrain_palette.gd").new()
var seed_value := 37

func _ready() -> void:
	add_child(bed)
	bed.position = BED_POINT
	add_child(dressing)
	add_child(drips)
	_build_floor()
	_build_walls()
	_build_puddle()
	_build_bed()
	redress(seed_value)
	for spec in [[Vector3(-6,5,8),Color("e8c695"),2.5],[Vector3(5,4,7),Color("78a9b6"),1.8],[Vector3(0,5,-6),Color("d6c5a6"),1.6]]:
		var light := OmniLight3D.new()
		light.position = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		light.omni_range = 14.0
		light.light_cull_mask = LAYER | 1
		light.shadow_enabled = true
		add_child(light)
	# Gentle exterior bounce keeps the rock reveals readable below the canopy.
	for point in [Vector3(0,4,23),Vector3(-23,4,0),Vector3(23,4,0),Vector3(0,4,-23)]:
		var fill := OmniLight3D.new()
		fill.position = point
		fill.omni_range = 35
		fill.light_energy = 3.0
		fill.light_color = Color("b9bdc7")
		fill.light_cull_mask = LAYER
		add_child(fill)
	_layers(self)

func _layers(root: Node) -> void:
	if root is GeometryInstance3D: root.layers = LAYER
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
	st.set_smooth_group(-1)
	# Godot front faces use clockwise winding; keep each rock facet flat.
	for point in [a,c,b]: st.add_vertex(point)

func floor_height(x: float, z: float) -> float:
	var basin := Vector2(x-POOL_POINT.x,z-POOL_POINT.z).length()
	if basin<1.8: return -0.42*(1.0-smoothstep(0.8,1.8,basin))
	if Vector2(x-BED_POINT.x,z-BED_POINT.z).length()<1.7: return 0.1
	return (palette.noise.fbm(x*0.8,z*0.8)-0.5)*0.16

func _build_floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-14,14):
		for z in range(-14,14):
			var corners: Array[Vector3] = []
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var point: Vector2 = Vector2(x,z)+offset
				if absf(point.x)<14 and absf(point.y)<14:
					var jitter := Vector2(palette.noise.hash_at(point.x,point.y),palette.noise.hash_at(point.y+43,point.x-17))-Vector2.ONE*0.5
					point += jitter*0.65
				corners.append(Vector3(point.x,floor_height(point.x,point.y),point.y))
			var color := palette.rock_at(Vector2(x,z))*Color(0.75,0.72,0.68)
			_triangle(st,corners[0],corners[2],corners[1],color)
			_triangle(st,corners[0],corners[3],corners[2],color.lightened(0.012))
	_mesh(st).name = "LowerStoryFloor"
	# Solid geological base, with a tapered bottom and faceted strata.
	var base := SurfaceTool.new()
	base.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in range(4):
		var turn := Basis(Vector3.UP,side*PI/2.0)
		for x in range(-14,14,2):
			var a := turn*Vector3(x,0,14)
			var b := turn*Vector3(x+2,0,14)
			var c := turn*Vector3(x*0.96,-1.6,13.44)
			var d := turn*Vector3((x+2)*0.96,-1.6,13.44)
			var color := palette.rock_at(Vector2(x,side))*Color(0.6,0.53,0.45)
			_triangle(base,a,c,b,color)
			_triangle(base,b,c,d,color.darkened(0.08))
	_triangle(base,Vector3(-13.44,-1.6,-13.44),Vector3(13.44,-1.6,13.44),Vector3(13.44,-1.6,-13.44),Color("292820"))
	_triangle(base,Vector3(-13.44,-1.6,-13.44),Vector3(-13.44,-1.6,13.44),Vector3(13.44,-1.6,13.44),Color("292820"))
	_mesh(base).name = "LowerStoryBase"

func _build_walls() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two broad irregular windows per side. Their reveals are real rock depth,
	# so the openings remain legible while orbiting, without visibility tricks.
	for side in range(4):
		var turn := Basis(Vector3.UP,side*PI/2.0)
		for bay in range(2):
			var left := -HALF_WIDTH+bay*HALF_WIDTH
			var right := left+HALF_WIDTH
			var middle := (left+right)*0.5
			var outer := [Vector2(left,0),Vector2(left,4),Vector2(left,CEILING+0.9),Vector2(middle,CEILING+0.9),Vector2(right,CEILING+0.9),Vector2(right,4),Vector2(right,0),Vector2(middle,0)]
			var inner := [Vector2(left+2.0,0.9),Vector2(left+1.35,3.8),Vector2(left+2.2,6.9),Vector2(middle,7.5),Vector2(right-2.0,6.7),Vector2(right-1.5,3.5),Vector2(right-2.3,0.85),Vector2(middle,0.65)]
			for i in range(8):
				var j := (i+1)%8
				var a: Vector3 = turn*Vector3(outer[i].x,outer[i].y,HALF_WIDTH)
				var b: Vector3 = turn*Vector3(outer[j].x,outer[j].y,HALF_WIDTH)
				var c: Vector3 = turn*Vector3(inner[i].x,inner[i].y,HALF_WIDTH)
				var d: Vector3 = turn*Vector3(inner[j].x,inner[j].y,HALF_WIDTH)
				var inward := turn*Vector3(0,0,-1.45)
				var color := palette.rock_at(Vector2(i+side*4,bay))*Color(0.82,0.75,0.65)
				_triangle(st,a,c,b,color)
				_triangle(st,b,c,d,color.lightened(0.016))
				_triangle(st,a+inward,b+inward,c+inward,color.darkened(0.12))
				_triangle(st,b+inward,d+inward,c+inward,color.darkened(0.08))
				_triangle(st,c,c+inward,d,color.darkened(0.18))
				_triangle(st,d,c+inward,d+inward,color.darkened(0.15))
	_mesh(st).name = "WindowedRockWalls"
	# The upstairs chunk is the ceiling; this underside overlaps its skirt.
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-14,14,2):
		for z in range(-14,14,2):
			var a := Vector3(x,CEILING,z)
			var b := Vector3(x+2,CEILING,z)
			var c := Vector3(x,CEILING,z+2)
			var d := Vector3(x+2,CEILING,z+2)
			var color := palette.rock_at(Vector2(x,z))*Color(0.6,0.58,0.53)
			_triangle(roof,a,b,c,color)
			_triangle(roof,b,d,c,color)
	_mesh(roof).name = "UpperStoryUnderside"

func _build_puddle() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := POOL_POINT
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
	drips.add_emitter(Vector3(center.x,CEILING-1.4,center.z),center+Vector3.UP*0.025)
	drips.add_emitter(Vector3(center.x+0.5,CEILING-1.1,center.z-0.3),center+Vector3(0.5,0.025,-0.3))

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
	for i in range(42):
		var point := Vector3(rng.randf_range(-12.0,12.0),CEILING,rng.randf_range(-12.0,12.0))
		_spike(point,rng.randf_range(0.45,1.8),rng.randf_range(0.16,0.45),true)
	for i in range(16):
		var point := Vector3(rng.randf_range(-11.5,11.5),0,rng.randf_range(-11.5,3.0))
		if Vector2(point.x-BED_POINT.x,point.z-BED_POINT.z).length()<2: continue
		_spike(point,rng.randf_range(0.3,1.3),rng.randf_range(0.2,0.4),false)
	_spike(Vector3(POOL_POINT.x,CEILING,POOL_POINT.z),1.4,0.3,true)
	_spike(Vector3(POOL_POINT.x+0.5,CEILING,POOL_POINT.z-0.3),1.1,0.22,true)
