extends SceneTree
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0
func _initialize() -> void:
	var shape := NativeMountainShape.new(7)
	check(absf(shape.height(Vector2(0.5,0))-shape.height(Vector2(0,0.5))) > 0.1,"Ridge is not radially symmetric")
	check(shape.height(Vector2(1.01,0)) == 0.0,"Stamp has a bounded footprint")
	check(shape.height(Vector2(0.2,0.2)) == NativeMountainShape.new(7).height(Vector2(0.2,0.2)),"Variation is deterministic")
	check(shape.height(Vector2(0.2,0.2)) != NativeMountainShape.new(19).height(Vector2(0.2,0.2)),"Variation changes mountain shape")
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	data.reset_flat()
	data.heights.fill(-0.5)
	data.begin_stroke()
	## The ridge overshoots its peak; stamp at the limit (64 m since 500a574b) so the clamp bites.
	data.mountain(Vector2.ZERO,8.0,NativeTerrainData.MAX_HEIGHT)
	data.end_stroke()
	check(data.ground_height(Vector2(12,12)) == -0.5,"Mountain preserves hollows outside footprint")
	check(Array(data.heights).max() <= NativeTerrainData.MAX_HEIGHT,"Peak respects editing height limit")
	check(data.undo() and data.heights.count(-0.5) == data.heights.size(),"Whole ridge stamp undoes")
	print("Mountain shape: ",failures," failures")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
