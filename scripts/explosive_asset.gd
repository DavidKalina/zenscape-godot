extends RefCounted
## A compact red charge. Leaves replace its visible shell when camouflaged.
static func mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(3):
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.075
		cylinder.bottom_radius = 0.075
		cylinder.height = 0.42
		cylinder.radial_segments = 8
		var pose := Transform3D(Basis(Vector3.RIGHT,PI*0.5),Vector3((i-1)*0.14,0.1,0))
		for vertex in cylinder.get_faces():
			surface.set_color(Color("c55138").srgb_to_linear())
			surface.add_vertex(pose*vertex)
	var band := BoxMesh.new()
	band.size = Vector3(0.46,0.18,0.08)
	for vertex in band.get_faces():
		surface.set_color(Color("403d36").srgb_to_linear())
		surface.add_vertex(vertex+Vector3(0,0.1,0))
	surface.generate_normals()
	return surface.commit()
