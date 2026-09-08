extends RefCounted
## A small pile of folded leaves, shared by the garden renderer and editor.
static func mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 87321
	for i in range(60):
		var angle := rng.randf()*TAU
		var radius := sqrt(rng.randf())
		var center := Vector3(cos(angle)*radius*0.85,0.04+(1.0-radius)*0.12,sin(angle)*radius*0.95+0.15)
		var facing := Basis(Vector3.UP,rng.randf()*TAU)
		var length := rng.randf_range(0.18,0.34)
		var width := length*0.48
		var points := [Vector3(0,0,-length),Vector3(-width,0,0),Vector3(0,0,length),Vector3(width,0,0),Vector3(0,0.035,0)]
		var color := Color("9a864f").lerp(Color("596842"),rng.randf()).srgb_to_linear()
		for face in [[0,4,1],[1,4,2],[2,4,3],[3,4,0]]:
			for index in face:
				surface.set_color(color)
				surface.add_vertex(center+facing*points[index])
	surface.generate_normals()
	return surface.commit()
