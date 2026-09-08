extends RefCounted
## Reproducible authored chunk for the gust playground. Uses the normal editor
## data/renderer so ponds, falling strands, spray and vegetation are real tools.
static func populate(editor: Node) -> Vector3:
	var data = editor.data
	data.begin_stroke()
	data.reset_flat()
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		var ridge: float = 5.0 * (1.0 - smoothstep(-5.0, 1.0, p.x)) * (1.0 - smoothstep(1.5, 5.5, absf(p.y))) * smoothstep(-12.0, -8.0, p.x)
		var basin: float = 1.1 * (1.0 - smoothstep(0.0, 3.0, p.distance_to(Vector2(3, 0))))
		data.heights[i] = ridge - basin
	data.paint_grass(Vector2.ZERO, 18.0, 0.85)
	# Keep the landing and foreground clearing readable, with patches around it.
	data.paint_blades(Vector2(0, 2.7), 2.3, 0.9)
	data.paint_blades(Vector2(4.5, 2.5), 1.8, 0.8)
	data.paint_blades(Vector2(3, -3), 1.8, 0.75)
	data.paint_meadow(Vector2(5, 3), 1.8, 0.8)
	data.place("tree", Vector2(-2.5, 3.2), 0.85, 0.45)
	data.place("tree", Vector2(5.8, 0.8), 1.05, 0.75)
	data.place("tree", Vector2(4.8, -3.2), 0.75, 0.65)
	data.place("tree", Vector2(-3.0, -3.5), 0.7, 0.6)
	data.place("rock", Vector2(3.8, 2.8), 0.7, 0.4)
	data.place("rock", Vector2(-0.7, -1.8), 0.55, 0.8)
	var pond_ok: bool = data.add_pond(Vector2(3, 0), -0.2)
	var fall_ok: bool = data.add_waterfall(Vector2(-4, 0), Vector2(3, 0), 1.0)
	assert(pond_ok and fall_ok, "Wind demonstration must contain its pond and waterfall")
	data.end_stroke()
	editor.refresh()
	var clearing := Vector2(1.0, 3.6)
	return editor.terrain.to_global(Vector3(clearing.x, data.ground_height(clearing), clearing.y))
