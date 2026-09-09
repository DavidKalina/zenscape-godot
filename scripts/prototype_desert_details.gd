extends Node3D
## Disposable source-inspired saguaros, cliff-foot debris, and narrow monument spire.
const Desert = preload("res://scripts/prototype_desert_landscape.gd")
func build(g: Dictionary,recipe: RefCounted,terrain_material: ShaderMaterial) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(g.plant_seed)+1941
	var cactus_material := ShaderMaterial.new()
	cactus_material.shader = preload("res://shaders/reference_surface.gdshader")
	cactus_material.set_shader_parameter("base_color",Color("5e7d4a"))
	cactus_material.set_shader_parameter("flat_faces",true)
	var cactus_meshes: Array = []
	for arms in range(3): cactus_meshes.append(_cactus(arms))
	var spots: Array[Vector2] = []
	for i in range(1200):
		var p := Vector2(rng.randf_range(-11,11),rng.randf_range(-10.5,10.5))
		var f := Desert.field(g,p)
		if f.y>0.1 or f.z>0.2 or f.x>3.5: continue
		var slope := Vector2(recipe.height(p.x+0.2,p.y)-recipe.height(p.x-0.2,p.y),recipe.height(p.x,p.y+0.2)-recipe.height(p.x,p.y-0.2)).length()/0.4
		if slope>0.5: continue
		var crowded := false
		for other in spots:
			if p.distance_squared_to(other)<2.5: crowded = true; break
		if crowded: continue
		var cactus := MeshInstance3D.new()
		cactus.mesh = cactus_meshes[spots.size()%3]
		cactus.material_override = cactus_material
		cactus.position = Vector3(p.x,recipe.height(p.x,p.y)-0.05,p.y)
		cactus.rotation.y = rng.randf()*TAU
		cactus.scale = Vector3.ONE*rng.randf_range(0.65,1.1)
		add_child(cactus)
		spots.append(p)
		if spots.size()>=26: break
	var rubble_material := terrain_material.duplicate() as ShaderMaterial
	rubble_material.set_shader_parameter("terrain_growth",false)
	rubble_material.set_shader_parameter("desert_has_map",false)
	rubble_material.set_shader_parameter("inland_rock_amount",0.0)
	rubble_material.set_shader_parameter("desert_sand_a",Color("a5502f"))
	rubble_material.set_shader_parameter("desert_sand_b",Color("c9875a"))
	var rubble := SphereMesh.new()
	rubble.radial_segments = 5
	rubble.rings = 2
	rubble.radius = 0.5
	rubble.height = 0.8
	var count := 0
	for i in range(700):
		var p := Vector2(rng.randf_range(-11.5,11.5),rng.randf_range(-11.5,11.5))
		var f := Desert.field(g,p)
		if f.y>0.5 or f.z>0.15: continue
		var near_cliff := false
		for d in [Vector2(0.8,0),Vector2(-0.8,0),Vector2(0,0.8),Vector2(0,-0.8)]:
			var neighbor := Desert.field(g,p+d)
			if neighbor.y>0.5 and neighbor.x>f.x+0.3: near_cliff = true
		if not near_cliff: continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = rubble
		mesh.material_override = rubble_material
		mesh.position = Vector3(p.x,recipe.height(p.x,p.y)+0.05,p.y)
		mesh.rotation = Vector3(rng.randf(),rng.randf()*TAU,rng.randf())
		mesh.scale = Vector3(rng.randf_range(0.3,0.8),rng.randf_range(0.25,0.6),rng.randf_range(0.3,0.8))
		add_child(mesh)
		count += 1
		if count>=90: break
	if g.composition in ["monuments","salt-basin"]:
		# This source finger is narrower than the native terrain lattice spacing.
		# Resolve its silhouette with a separate rock mesh, anchored in the shared apron.
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var center := Vector2(16.2/3.0,-5.1/3.0)*float(g.breadth)
		for ring in range(8):
			for segment in range(12):
				var corners: Array[Vector3] = []
				for pair in [Vector2(ring,segment),Vector2(ring,segment+1),Vector2(ring+1,segment+1),Vector2(ring+1,segment)]:
					var r: float = 1.5*(1.0-pair.x/8.0)
					var angle: float = pair.y/12.0*TAU
					var h := 0.8+(3.2+17.0*pow(maxf(0,1.0-r/1.5),0.28))*0.65*float(g.relief)
					corners.append(Vector3(center.x+cos(angle)*r*1.15/3.0*g.breadth,h,center.y+sin(angle)*r*1.25/3.0*g.breadth))
				for index in [0,2,1,0,3,2]: tool.add_vertex(corners[index])
		tool.generate_normals()
		var spire := MeshInstance3D.new()
		spire.mesh = tool.commit()
		var stone := terrain_material.duplicate() as ShaderMaterial
		stone.set_shader_parameter("terrain_growth",false)
		stone.set_shader_parameter("desert_has_map",false)
		stone.set_shader_parameter("inland_rock_amount",1.0)
		spire.material_override = stone
		add_child(spire)
func _cactus(arms: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cylinder(tool,0.12,0.17,1.7,Transform3D(Basis.IDENTITY,Vector3(0,0.85,0)))
	for i in range(arms):
		var side := -1.0 if i==0 else 1.0
		var y := 0.85 if i==0 else 1.15
		_cylinder(tool,0.08,0.08,0.3,Transform3D(Basis(Vector3.FORWARD,PI/2),Vector3(side*0.24,y,0)))
		_cylinder(tool,0.08,0.09,0.55,Transform3D(Basis.IDENTITY,Vector3(side*0.36,y+0.28,0)))
	return tool.commit()
func _cylinder(tool: SurfaceTool,top: float,bottom: float,h: float,pose: Transform3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = h
	mesh.radial_segments = 7
	mesh.rings = 1
	tool.append_from(mesh,0,pose)
