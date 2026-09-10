extends Node3D
## Render saved cave sites from the approved Blender asset. The terrain bore
## removes intersecting hillside; the rock shell supplies the visible opening.
const Tunnels = preload("res://scripts/native_tunnels.gd")
const MODEL = preload("res://assets/models/zenscape-cave.glb")
var _masked: Array[Dictionary] = []
var _signature := PackedByteArray()
const LOCAL_BOUNDS := AABB(Vector3(-5.8,-0.8,-9.2),Vector3(11.6,7.3,9.4))
static func pose(item: Dictionary) -> Transform3D:
	return Tunnels.pose(item)*Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*float(item.get("cave_scale",1.0))),Vector3.ZERO)
static func bounds(item: Dictionary) -> AABB:
	return pose(item)*LOCAL_BOUNDS
func rebuild(data: NativeTerrainData) -> void:
	# Editor refreshes may rewrite the same private MultiMesh. Restore only
	# transforms that are still our zero mask, never newer authored transforms.
	for record in _masked:
		if not is_instance_valid(record.node) or record.node.multimesh != record.masked: continue
		for saved in record.transforms:
			if str(record.node.name)+":"+str(saved.index) in data.source_replacements: continue
			if record.masked.get_instance_transform(saved.index) == Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO):
				record.masked.set_instance_transform(saved.index,saved.pose)
	_masked.clear()
	_mask_foliage(data)
	var signature := var_to_bytes(data.tunnels)
	if signature == _signature: return
	_signature = signature
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for item: Dictionary in data.tunnels:
		if not item.get("cave",false) or item.sealed: continue
		var model := MODEL.instantiate()
		add_child(model)
		model.transform = pose(item)
		# Separate the authored floor from the terrain subtraction floor.
		model.position.y += 0.025
		_add_darkness(model)
		for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			if part.name.begins_with("Moss") or part.name=="CaveDarkness": continue
			var body := StaticBody3D.new()
			var collision := CollisionShape3D.new()
			var shape := part.mesh.create_trimesh_shape()
			shape.backface_collision = true
			collision.shape = shape
			body.add_child(collision)
			part.add_child(body)


func _mask_foliage(data: NativeTerrainData) -> void:
	if not data.tunnels.any(func(item: Dictionary) -> bool: return item.get("cave",false) and not item.sealed): return
	var reference := get_parent().get_node("Reference")
	for node in reference.get_children():
		if not node is MultiMeshInstance3D: continue
		var source: MultiMesh = node.multimesh
		var masked: MultiMesh
		var transforms: Array[Dictionary] = []
		for i in range(source.instance_count):
			var transform: Transform3D = node.global_transform*source.get_instance_transform(i)
			if transform.basis.determinant()==0.0: continue
			var center: Vector3 = transform*source.mesh.get_aabb().get_center()
			for item: Dictionary in data.tunnels:
				if not item.get("cave",false) or item.sealed: continue
				var local := pose(item).affine_inverse()*center
				if absf(local.x)>2.2 or local.z>2.4 or local.z< -6.5 or local.y>4.8: continue
				if masked == null: masked = source.duplicate()
				transforms.append({"index":i,"pose":source.get_instance_transform(i)})
				masked.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
				break
		if masked != null:
			node.multimesh = masked
			_masked.append({"node":node,"masked":masked,"transforms":transforms})

func _add_darkness(model: Node3D) -> void:
	var outline: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/zenscape-cave-entrance.json"))
	var vertices := PackedVector3Array()
	var center := Vector3.ZERO
	for p: Array in outline:
		var vertex := Vector3(p[0],p[1],p[2]-0.035)
		vertices.append(vertex)
		center += vertex
	center /= vertices.size()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(vertices.size()):
		surface.add_vertex(center)
		surface.add_vertex(vertices[i])
		surface.add_vertex(vertices[(i+1)%vertices.size()])
	var portal := MeshInstance3D.new()
	portal.name = "CaveDarkness"
	portal.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/cave_darkness.gdshader")
	portal.material_override = material
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(portal)
