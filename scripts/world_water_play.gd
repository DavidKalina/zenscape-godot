extends "res://scripts/play_water_mischief.gd"
## Sample the rendered water meshes, including rivers and imported waterways.
var surfaces: Array[RefCounted] = []
var triangles: Array[Dictionary] = []

func refresh() -> void:
	surfaces.clear()
	triangles.clear()
	var nodes: Array = [scene._chunk_editor.content._water]
	nodes.append_array(scene._chunk_editor.content._stream_nodes)
	if not scene._chunk_editor.data.blank:
		for node in scene.owner_scene.get_node("Reference").get_children():
			if node is MeshInstance3D and node.visible:
				var material := node.get_active_material(0) as ShaderMaterial
				if material != null and material.shader.resource_path.ends_with("reference_water.gdshader"): nodes.append(node)
	for node in nodes:
		if node.mesh == null: continue
		var probe := preload("res://scripts/reference_ground.gd").new()
		probe.setup(node)
		surfaces.append(probe)
		triangles.append({"mesh":node.mesh.generate_triangle_mesh(),"transform":node.global_transform})

func surface_at(point: Vector3) -> Variant:
	var highest: Variant = null
	for surface in surfaces:
		var level: Variant = surface.height_at(point.x,point.z)
		if level != null and (highest == null or level>highest): highest = level
	return Vector3(point.x,highest,point.z) if highest != null else null

func pick(mouse: Vector2) -> Variant:
	if scene._over_controls(mouse): return null
	var origin: Vector3 = scene.camera.project_ray_origin(mouse)
	var direction: Vector3 = scene.camera.project_ray_normal(mouse)
	var ground: Variant = scene._ground_at(mouse)
	var nearest: float = origin.distance_to(ground)+0.05 if ground != null else INF
	var result: Variant = null
	for surface in triangles:
		if surface.mesh == null: continue
		var inverse: Transform3D = surface.transform.affine_inverse()
		var hit: Dictionary = surface.mesh.intersect_ray(inverse*origin,(inverse.basis*direction).normalized())
		if hit.is_empty(): continue
		var point: Vector3 = surface.transform*hit.position
		if origin.distance_to(point)<nearest:
			nearest = origin.distance_to(point)
			result = point
	return result
