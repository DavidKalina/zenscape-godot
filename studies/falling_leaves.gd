extends MultiMeshInstance3D
## Original canopy-bound leaf particles, rendered as native point-sized quads.
var enabled := true

func _ready() -> void:
	name = "FallingLeaves"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/leaves.json"))
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_leaves.gdshader")
	material_override = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = source.positions.size() / 3
	for i in range(multimesh.instance_count):
		var p: Array = source.positions
		var a: Array = source.attributes
		var c: Array = source.colors
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2])))
		multimesh.set_instance_custom_data(i, Color(a[i * 4], a[i * 4 + 1], a[i * 4 + 2], a[i * 4 + 3]))
		multimesh.set_instance_color(i, Color(c[i * 3], c[i * 3 + 1], c[i * 3 + 2]))
	custom_aabb = AABB(Vector3(-48, -4, -48), Vector3(96, 48, 96))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	update_season(0.0)

func update_season(autumn: float) -> void:
	multimesh.visible_instance_count = multimesh.instance_count if enabled and autumn > 0.02 else 0
