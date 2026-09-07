extends SceneTree

var failures := 0

func _initialize() -> void:
	var garden := GardenData.new()
	check(garden.heights.count(0.0) == garden.heights.size(), "A new garden starts flat")
	garden.begin_stroke()
	garden.brush(Vector2(-4, 0), 3, 2, 1, "raise", 0)
	garden.brush(Vector2(4, 0), 3, 1, 0.5, "lower", 0)
	garden.paint_meadow(Vector2(-4, 0), 3, 1)
	garden.place("tree", Vector2(-4, 0), 0.7, 1.2)
	garden.place("rock", Vector2(1, 1))
	garden.place("flower", Vector2(2, 1))
	check(garden.add_pond(Vector2(4, 0), -0.1), "A hollow can hold a pond")
	garden.weather = "Rain"
	garden.end_stroke()
	var saved := garden.to_document()
	check(garden.undo() and garden.objects.is_empty() and garden.ponds.is_empty() and garden.weather == "Clear", "Undo restores the complete world")
	check(garden.redo() and garden.to_document() == saved, "Redo restores every garden layer")
	var copy := GardenData.new()
	check(copy.load_document(JSON.parse_string(JSON.stringify(saved, "", true, true))), "A serialized garden loads")
	check(copy.to_document() == saved, "Every saved value survives JSON round trip")
	if copy.objects.is_empty():
		quit(1)
		return
	var before := copy.object_position(copy.objects[0])
	copy.begin_stroke()
	copy.brush(Vector2(-4, 0), 2, 1, 0.5, "raise", 0)
	copy.end_stroke()
	check(copy.object_position(copy.objects[0]).y > before.y, "Placed objects follow edited ground")
	copy.undo()
	check(copy.object_position(copy.objects[0]) == before, "Undo restores rooted placement")
	var invalid := saved.duplicate(true)
	invalid.objects[0].scale = "bad"
	check(not copy.load_document(invalid) and copy.to_document() == saved, "Invalid assets do not partially replace the world")
	invalid = saved.duplicate(true)
	invalid.objects[1].id = invalid.objects[0].id
	check(not copy.load_document(invalid), "Duplicate object identities are rejected")
	invalid = saved.duplicate(true)
	invalid.meadow[0] = INF
	check(not copy.load_document(invalid), "Nonfinite paint is rejected")
	check(copy.load_document(LandscapeData.new().to_document()) and copy.objects.is_empty(), "Original terrain saves migrate")
	var limits := GardenData.new()
	for i in range(GardenData.MAX_OBJECTS):
		limits.place("flower", Vector2.ZERO)
	check(limits.place("flower", Vector2.ZERO) == -1, "Object creation respects the load limit")
	check(copy.load_document(JSON.parse_string(JSON.stringify(limits.to_document(), "", true, true))), "A garden at the object limit reopens")
	limits.objects.clear()
	limits.brush(Vector2.ZERO, 5.0, 1.0, 0.5, "lower", 0)
	for i in range(GardenData.MAX_PONDS):
		limits.add_pond(Vector2(float(i) * 0.001, 0), -0.1)
	check(not limits.add_pond(Vector2(0.3, 0), -0.1), "Pond creation respects the load limit")
	check(limits.add_pond(Vector2.ZERO, -0.2) and limits.ponds.size() == GardenData.MAX_PONDS, "Refilling the same seed replaces it")
	check(copy.load_document(JSON.parse_string(JSON.stringify(limits.to_document(), "", true, true))), "A garden at the pond limit reopens")
	print("Garden checks: ", failures, " failures")
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
