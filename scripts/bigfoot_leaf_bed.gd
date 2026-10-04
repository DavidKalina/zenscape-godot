extends RefCounted
## A small pile of folded leaves, shared by the garden renderer and editor.
## Real leaf shapes (scripts/leaf_litter_mesh.gd), warm and varied, heaped
## higher at the middle and lying in loose layers.
const LeafMesh := preload("res://scripts/leaf_litter_mesh.gd")

static func mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 87321
	for i in range(34):
		var angle := rng.randf()*TAU
		var radius := sqrt(rng.randf())
		var center := Vector3(cos(angle)*radius*0.85,0.03+(1.0-radius)*0.12+rng.randf()*0.02,sin(angle)*radius*0.95+0.15)
		var scale := rng.randf_range(0.22,0.36)
		var basis := Basis(Vector3.UP,rng.randf()*TAU)*Basis(Vector3.RIGHT,rng.randf_range(-0.2,0.2))*Basis(Vector3.FORWARD,rng.randf_range(-0.2,0.2))
		var shape: String = LeafMesh.ORDER[rng.randi_range(0,LeafMesh.ORDER.size()-1)]
		var curl := 1.0+rng.randf_range(0.0,1.5)
		LeafMesh.add_leaf(surface,shape,Transform3D(basis.scaled(Vector3.ONE*scale),center),LeafMesh.leaf_color(rng),0.0,curl)
	surface.generate_normals()
	return surface.commit()
