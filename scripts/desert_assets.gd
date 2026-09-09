extends RefCounted
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
