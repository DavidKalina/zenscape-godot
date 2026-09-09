extends "res://scripts/play_loose_body.gd"
## Promotes an authored prop without changing its silhouette or placement.
var object_id := -1
var record_in_body := Transform3D.IDENTITY

func configure(parts: Array, record_pose: Transform3D, type: String) -> void:
	kind = type
	var orientation := record_pose.basis.orthonormalized()
	var frame := Transform3D(orientation,record_pose.origin)
	var box := AABB()
	var first := true
	var vertices := PackedVector3Array()
	for part in parts:
		var local: Transform3D = frame.affine_inverse()*part.transform
		var bounds: AABB = local*part.mesh.get_aabb()
		box = bounds if first else box.merge(bounds)
		first = false
		for vertex in part.mesh.get_faces(): vertices.append(local*vertex)
	frame.origin = frame*box.get_center()
	global_transform = frame
	record_in_body = frame.affine_inverse()*record_pose
	for i in range(parts.size()):
		var part: Dictionary = parts[i]
		var instance := visual if i == 0 else MeshInstance3D.new()
		instance.mesh = part.mesh
		instance.material_override = part.material
		add_child(instance)
		instance.global_transform = part.transform
	var shape := ConvexPolygonShape3D.new()
	for i in range(vertices.size()): vertices[i] -= box.get_center()
	shape.points = vertices
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	radius = maxf(0.08,minf(box.size.y,box.size.z)*0.5) if kind == "log" else maxf(0.08,box.size.length()*0.29)
	reach = maxf(radius,box.size.x*0.5) if kind == "log" else radius
	mass = clampf(box.size.x*box.size.y*box.size.z*(2.5 if kind == "log" else 18.0),0.4,120.0)
	continuous_cd = true
	collision_layer = 1
	collision_mask = 3
	linear_damp = 0.12
	angular_damp = 0.15
	var physics := PhysicsMaterial.new()
	physics.friction = 0.65
	physics.bounce = 0.12
	physics_material_override = physics
	home = global_transform
	parked = true
	freeze = true
