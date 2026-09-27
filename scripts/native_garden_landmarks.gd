class_name NativeGardenLandmarks
extends Node3D
signal instances_published()
## Place the demo's source landmarks with a ground-centered pivot.
const KINDS := ["arch", "bigfoot_tree"]
var _arch_mesh: Mesh
var _arch_material: Material
var _arch_offset := Vector3.ZERO

func _ready() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var arch: MeshInstance3D = source.get_node("landmark-arch")
	_arch_mesh = arch.mesh
	_arch_material = arch.get_active_material(0).duplicate()
	_arch_material.set_shader_parameter("palette_role",3)
	# The source arch is already fully formed. Its growth target coordinates
	# belong to the original chunk, so placement uses its actual mesh positions.
	_arch_material.set_shader_parameter("terrain_growth",false)
	var bounds := _arch_mesh.get_aabb()
	_arch_offset = -Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	source.free()

## Move the placed landmarks onto the current ground without re-instancing
## them; a held brush uses this between full rebuilds.
func lift(data: NativeTerrainData) -> void:
	for item: Dictionary in data.objects:
		if item.asset not in KINDS:
			continue
		var landmark := get_node_or_null(NodePath("%s_%d" % [item.asset,item.id])) as Node3D
		if landmark != null:
			landmark.position = data.object_position(item)

func rebuild(data: NativeTerrainData) -> void:
	for child in get_children():
		child.free()
	for item: Dictionary in data.objects:
		if item.asset not in KINDS:
			continue
		var landmark := Node3D.new()
		landmark.name = "%s_%d" % [item.asset,item.id]
		add_child(landmark)
		landmark.position = data.object_position(item)
		landmark.rotation.y = item.angle
		landmark.scale = Vector3.ONE*item.scale
		if item.asset == "arch":
			var mesh := MeshInstance3D.new()
			mesh.mesh = _arch_mesh
			mesh.material_override = _arch_material
			mesh.position = _arch_offset
			landmark.add_child(mesh)
		else:
			var tree: Node3D = preload("res://assets/bigfoot/old_tree.glb").instantiate()
			landmark.add_child(tree)
			tree.scale *= preload("res://studies/bigfoot_encounter.gd").PEEK_SCALE
			for mesh: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):
				var original := mesh.mesh.surface_get_material(0) as StandardMaterial3D
				var material := ShaderMaterial.new()
				material.shader = preload("res://shaders/reference_surface.gdshader")
				material.set_shader_parameter("base_color",original.albedo_color)
				material.set_shader_parameter("palette_role",4)
				mesh.material_override = material
	instances_published.emit()
