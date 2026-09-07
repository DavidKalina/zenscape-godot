extends SceneTree
## Run: godot --headless --path . --script tests/test_landscape.gd

var failures := 0

func _initialize() -> void:
	var data := LandscapeData.new()
	var original := data.heights.duplicate()
	var center := Vector2.ZERO
	var original_center := data.height_at(center)
	data.begin_stroke()
	for i in range(10):
		data.brush(center, 2.0, 2.0, 0.1, "raise", 0.0)
	data.end_stroke()
	_check(data.height_at(center) > original_center + 1.0, "Raise changes the center")
	_check(data.heights[0] == original[0], "The brush does not change distant terrain")
	var raised := data.heights.duplicate()
	_check(data.undo() and data.heights == original, "A whole stroke undoes exactly")
	_check(not data.undo(), "Dabs do not create separate undo entries")
	_check(data.redo() and data.heights == raised, "Redo restores the exact stroke")
	data.undo()
	data.begin_stroke()
	data.brush(center, 2.0, 1.0, 0.2, "lower", 0.0)
	data.end_stroke()
	_check(not data.redo(), "A new stroke clears the redo branch")
	_check(data.height_at(center) < original_center, "Lower moves ground downward")
	data.begin_stroke()
	data.brush(center, 2.0, 100.0, 10.0, "raise", 0.0)
	data.end_stroke()
	_check(data.height_at(center) <= LandscapeData.MAX_HEIGHT, "Sculpting respects the ceiling")
	data.brush(center, 2.0, 100.0, 10.0, "lower", 0.0)
	_check(data.height_at(center) >= LandscapeData.MIN_HEIGHT, "Sculpting respects the floor")
	data.brush(center, 2.0, 100.0, 10.0, "flatten", 1.2)
	_check(is_equal_approx(data.height_at(center), 1.2), "Flatten uses the stroke's sampled height")
	data.brush(center, 0.75, 3.0, 1.0, "raise", 0.0)
	var peak := data.height_at(center)
	data.brush(center, 2.0, 3.0, 1.0, "smooth", 0.0)
	_check(data.height_at(center) < peak, "Smooth softens a local peak")
	var document: Variant = JSON.parse_string(JSON.stringify(data.to_document()))
	var restored := LandscapeData.new()
	_check(restored.load_document(document) and restored.heights == data.heights, "JSON round trip preserves every height")
	var before_bad_load := restored.heights.duplicate()
	document["heights"][0] = "invalid"
	_check(not restored.load_document(document), "Malformed saves are rejected")
	_check(restored.heights == before_bad_load, "A rejected save leaves terrain intact")
	_check(not restored.load_document({}), "Incomplete saves are rejected")
	# Check exact mesh interpolation inside both halves of one grid square.
	var flat := LandscapeData.new()
	flat.heights.fill(0.0)
	flat.heights[1] = 2.0
	flat.heights[LandscapeData.SIDE] = 4.0
	flat.heights[LandscapeData.SIDE + 1] = 6.0
	_check(is_equal_approx(flat.height_at(Vector2(-11.875, -11.875)), 1.5), "Height sampling matches the first triangle")
	_check(is_equal_approx(flat.height_at(Vector2(-11.625, -11.625)), 4.5), "Height sampling matches the second triangle")
	if failures == 0:
		print("PASS: 17 landscape behavior checks")
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
