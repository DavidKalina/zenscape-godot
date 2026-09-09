extends SubViewport
## Render palette canvas materials once before interaction. Hidden controls do
## not trigger their first canvas draw; this tiny offscreen target does.
func _init() -> void:
	size = Vector2i(8,8)
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_ONCE

func prepare(source: Node) -> void:
	var materials := {}
	_collect(source,materials)
	for material in materials:
		var rect := ColorRect.new()
		rect.size = Vector2(8,8)
		rect.material = material
		add_child(rect)

func _collect(node: Node, materials: Dictionary) -> void:
	if node is CanvasItem and node.material is ShaderMaterial:
		materials[node.material] = true
	for child in node.get_children(): _collect(child,materials)
