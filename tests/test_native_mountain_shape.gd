extends SceneTree
var failures := 0
func _initialize() -> void:
	var shape := NativeMountainShape.new(7)
	check(absf(shape.height(Vector2(0.5,0))-shape.height(Vector2(0,0.5))) > 0.1,"Ridge is not radially symmetric")
	check(shape.height(Vector2(1.01,0)) == 0.0,"Stamp has a bounded footprint")
	check(shape.height(Vector2(0.2,0.2)) == NativeMountainShape.new(7).height(Vector2(0.2,0.2)),"Variation is deterministic")
	check(shape.height(Vector2(0.2,0.2)) != NativeMountainShape.new(19).height(Vector2(0.2,0.2)),"Variation changes mountain shape")
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	data.reset_flat()
	data.heights.fill(-0.5)
	data.begin_stroke()
	data.mountain(Vector2.ZERO,8.0,24.0)
	data.end_stroke()
	check(data.ground_height(Vector2(12,12)) == -0.5,"Mountain preserves hollows outside footprint")
	check(Array(data.heights).max() <= 24.0,"Peak respects editing height limit")
	check(data.undo() and data.heights.count(-0.5) == data.heights.size(),"Whole ridge stamp undoes")
	source.free()
	print("Mountain shape: ",failures," failures")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
