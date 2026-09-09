extends Node3D
## Additional layered broadleaf asset. All vertices share one tree-local wind field.
var leaf_material: ShaderMaterial

func _ready() -> void:
	name = "LayeredPondTree"
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Broad, unequal tiers; lateral gaps reveal branches and break the silhouette.
	var clusters := [
		[Vector3(-0.15,4.9,-0.15),Vector3(1.25,0.85,1.0),0.2],
		[Vector3(-1.2,4.25,0.15),Vector3(1.35,0.72,1.05),0.8],
		[Vector3(1.12,4.35,-0.35),Vector3(1.35,0.78,1.0),2.1],
		[Vector3(0.2,4.12,1.1),Vector3(1.08,0.64,0.80),3.0],
		[Vector3(-0.65,4.12,-1.05),Vector3(1.05,0.8,1.0),1.2],
		[Vector3(-1.95,3.68,0.72),Vector3(0.78,0.48,0.66),2.7],
		[Vector3(1.92,3.88,0.48),Vector3(0.8,0.5,0.68),0.5],
		[Vector3(0.9,4.8,-0.95),Vector3(0.85,0.65,0.78),3.7],
	]
	for index in range(clusters.size()):
		var entry: Array = clusters[index]
		_cluster(leaves, entry[0], entry[1], entry[2], index)
	var crown := MeshInstance3D.new()
	crown.name = "Crown"
	crown.mesh = leaves.commit()
	leaf_material = ShaderMaterial.new()
	leaf_material.shader = preload("res://shaders/layered_canopy_surface.gdshader")
	leaf_material.set_shader_parameter("palette_role",2)
	leaf_material.set_shader_parameter("roughness_value",0.9)
	leaf_material.set_shader_parameter("foliage_transmission",0.3)
	leaf_material.set_shader_parameter("sway_enabled",true)
	leaf_material.set_shader_parameter("sway_shape",Vector4(0.5,6.0,0.20,0.07))
	leaf_material.set_shader_parameter("sway_frequency",Vector4(0.8,1.7,0.6,0.22))
	crown.material_override = leaf_material
	crown.extra_cull_margin = 0.3
	add_child(crown)
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	_branch(wood,Vector3(0,0,0),Vector3(0.12,1.65,0.05),0.23,0.17)
	_branch(wood,Vector3(0.12,1.65,0.05),Vector3(-0.1,3.3,0),0.17,0.09)
	_branch(wood,Vector3(-0.1,3.3,0),Vector3(-0.2,4.8,-0.1),0.09,0.025)
	for tip in [Vector3(-1.7,3.9,0.65),Vector3(1.6,4.1,0.35),Vector3(0.6,3.7,1.4),Vector3(-0.6,4.2,-1.2)]:
		_branch(wood,Vector3(0,2.65,0),tip,0.095,0.02)
	# A small root flare seats the trunk in the sloping bank.
	for tip in [Vector3(-0.55,-0.08,0.2),Vector3(0.5,-0.05,0.15),Vector3(0,-0.06,-0.5)]:
		_branch(wood,Vector3(0,0.3,0),tip,0.13,0.035)
	var trunk := MeshInstance3D.new()
	trunk.name = "Branchwork"
	trunk.mesh = wood.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/layered_tree_wood.gdshader")
	material.set_shader_parameter("palette_role",4)
	material.set_shader_parameter("tactile",1.0)
	trunk.material_override = material
	add_child(trunk)

func _cluster(tool: SurfaceTool, center: Vector3, shape: Vector3, angle: float, seed: int) -> void:
	var phi := (1.0+sqrt(5.0))/2.0
	var base: Array[Vector3] = [Vector3(-1,phi,0),Vector3(1,phi,0),Vector3(-1,-phi,0),Vector3(1,-phi,0),Vector3(0,-1,phi),Vector3(0,1,phi),Vector3(0,-1,-phi),Vector3(0,1,-phi),Vector3(phi,0,-1),Vector3(phi,0,1),Vector3(-phi,0,-1),Vector3(-phi,0,1)]
	var faces := [0,11,5,0,5,1,0,1,7,0,7,10,0,10,11,1,5,9,5,11,4,11,10,2,10,7,6,7,1,8,3,9,4,3,4,2,3,2,6,3,6,8,3,8,9,4,9,5,2,4,11,6,2,10,8,6,7,9,8,1]
	var points := PackedVector3Array()
	var indices := PackedInt32Array()
	for face in range(0,faces.size(),3):
		var a := base[faces[face]].normalized()
		var b := base[faces[face+1]].normalized()
		var c := base[faces[face+2]].normalized()
		var ab := (a+b).normalized()
		var bc := (b+c).normalized()
		var ca := (c+a).normalized()
		for v in [a,ab,ca,b,bc,ab,c,ca,bc,ab,bc,ca]:
			indices.append(points.size())
			points.append(v)
	var rotation := Basis(Vector3.UP,angle)
	for triangle in range(0,indices.size(),3):
		var vertices: Array[Vector3] = []
		for corner in range(3):
			var v := points[indices[triangle+corner]]
			var wobble := 1.0 + 0.10*sin(v.x*5.0+v.z*3.0+seed*1.7)*cos(v.y*4.0+seed)
			vertices.append(center + rotation*(v*shape*wobble))
		var normal := (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
		var midpoint := (vertices[0]+vertices[1]+vertices[2])/3.0
		if normal.dot(midpoint-center)<0: normal = -normal
		else: vertices.reverse() # Godot front faces use clockwise winding.
		var tint := Color("568445").srgb_to_linear()
		var top := smoothstep(3.2,5.7,midpoint.y)
		tint = tint.lerp(Color("76964e").srgb_to_linear(),top*0.55)
		tint.a = 0.18
		tint *= 0.94 + 0.10*sin(float(seed)*2.3+float(triangle)*0.47)
		for vertex in vertices:
			# Retain facets, but soften the hard terminator across each leaf mass.
			var radial := rotation * (((rotation.inverse()*(vertex-center))/shape)/shape).normalized()
			tool.set_normal(normal.lerp(radial,0.4).normalized())
			tool.set_color(tint)
			tool.add_vertex(vertex)

	# A few opaque folded leaves interrupt the outline without alpha shimmer.
	for spray in range(5):
		var bearing := angle + float(spray)*TAU/5.0 + seed*0.37
		var outward := Vector3(cos(bearing),0.10+0.14*sin(seed+spray),sin(bearing)).normalized()
		var origin := center + outward*shape*0.92
		for finger in range(3):
			var direction := Basis(Vector3.UP,float(finger-1)*0.65)*outward
			_leaf(tool,origin,direction,0.27+0.06*sin(seed+finger))

func _leaf(tool: SurfaceTool, origin: Vector3, direction: Vector3, length: float) -> void:
	var side := direction.cross(Vector3.UP).normalized()*length*0.34
	var middle := origin+direction*length*0.52
	var ridge := middle+Vector3.UP*length*0.16
	var outline := [origin,middle+side,origin+direction*length,middle-side]
	for i in range(4):
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i+1)%4]
		var normal := (b-a).cross(ridge-a).normalized()
		var triangle := [a,b,ridge]
		if normal.y < 0: normal = -normal
		else: triangle.reverse()
		for vertex in triangle:
			tool.set_normal(normal)
			tool.set_color(Color("709449").srgb_to_linear())
			tool.add_vertex(vertex)

func _branch(tool: SurfaceTool, base: Vector3, tip: Vector3, radius: float, end_radius: float) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = radius
	cylinder.top_radius = end_radius
	cylinder.height = base.distance_to(tip)
	cylinder.radial_segments = 7
	cylinder.rings = 1
	var arrays := cylinder.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rotation := Basis(Quaternion(Vector3.UP,(tip-base).normalized()))
	for index in indices:
		tool.set_normal(rotation*normals[index])
		tool.set_color(Color("746049").srgb_to_linear())
		tool.add_vertex((base+tip)*0.5 + rotation*vertices[index])
