@tool
class_name TerrainView
extends MeshInstance3D
## A deliberately small mesh rebuilt from editable data. Tile only when profiling
## shows that local updates are needed; the player sees one continuous landscape.

var data := LandscapeData.new()
var ground_material: ShaderMaterial
var _skirt: MeshInstance3D

func _ready() -> void:
	ground_material = ShaderMaterial.new()
	ground_material.shader = preload("res://shaders/reference_surface.gdshader")
	ground_material.set_shader_parameter("wet_ground", true)
	ground_material.set_shader_parameter("roughness_value", 0.95)
	material_override = ground_material
	_skirt = MeshInstance3D.new()
	_skirt.name = "EarthSides"
	var side_material := ShaderMaterial.new()
	side_material.shader = preload("res://shaders/reference_surface.gdshader")
	side_material.set_shader_parameter("wet_ground", true)
	_skirt.material_override = side_material
	add_child(_skirt)
	rebuild()

func rebuild() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(LandscapeData.CELLS):
		for x in range(LandscapeData.CELLS):
			var a := _point(x, z)
			var b := _point(x + 1, z)
			var c := _point(x, z + 1)
			var d := _point(x + 1, z + 1)
			_triangle(surface, a, b, c)
			_triangle(surface, b, d, c)
	mesh = surface.commit()
	_rebuild_skirt()

func show_brush(point: Vector2, radius: float, shown: bool) -> void:
	ground_material.set_shader_parameter("brush_center", point)
	ground_material.set_shader_parameter("brush_radius", radius)
	ground_material.set_shader_parameter("brush_visible", shown)

func ray_hit(origin: Vector3, direction: Vector3) -> Variant:
	# Intersect the actual edited heightfield without rebuilding physics shapes.
	# A short march followed by bisection keeps picking aligned with the triangles.
	var box := AABB(Vector3(-12.0, LandscapeData.MIN_HEIGHT - 0.1, -12.0), Vector3(24.0, 9.0, 24.0))
	var entry: Variant = box.intersects_ray(origin, direction)
	if entry == null:
		return null
	var start: Vector3 = entry
	var previous := start
	for i in range(400):
		var p := start + direction * (i * 0.10)
		var xz := Vector2(p.x, p.z)
		if not data.contains(xz):
			if i > 0:
				return null
			continue
		if p.y <= data.height_at(xz):
			var low := previous
			var high := p
			for iteration in range(10):
				var middle := (low + high) * 0.5
				if middle.y > data.height_at(Vector2(middle.x, middle.z)):
					low = middle
				else:
					high = middle
			return (low + high) * 0.5
		previous = p
	return null

func _point(x: int, z: int) -> Vector3:
	var p := LandscapeData.grid_position(x, z)
	return Vector3(p.x, data.heights[z * LandscapeData.SIDE + x], p.y)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var center := (a + b + c) / 3.0
	var patches := sin(center.x * 0.38 + sin(center.z * 0.45)) * cos(center.z * 0.3) * 0.5 + 0.5
	var green := Color("b49d78").lerp(Color("c8b18b"), patches * 0.7)
	if data is GardenData:
		var grid := (Vector2(center.x, center.z) + Vector2.ONE * LandscapeData.WIDTH * 0.5) / LandscapeData.STEP
		var index := clampi(int(grid.y), 0, LandscapeData.CELLS-1) * LandscapeData.CELLS + clampi(int(grid.x), 0, LandscapeData.CELLS-1)
		green = green.lerp(Color("8ea975"), data.meadow[index])
	var rock := smoothstep(2.5, 6.0, center.y) * 0.8 + (1.0 - normal.y) * 0.45
	var color := green.lerp(Color("bcb29b"), clampf(rock, 0.0, 0.9))
	color = color.lightened(sin(center.x * 17.1 + center.z * 29.8) * 0.025)
	surface.set_normal(normal)
	# Shader vertex colors are linear; palette literals above are sRGB.
	surface.set_color(color.srgb_to_linear())
	for vertex in [a, b, c]:
		surface.add_vertex(vertex)

func _rebuild_skirt() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(LandscapeData.CELLS):
		_side(surface, _point(i + 1, 0), _point(i, 0))
		_side(surface, _point(i, LandscapeData.CELLS), _point(i + 1, LandscapeData.CELLS))
		_side(surface, _point(0, i), _point(0, i + 1))
		_side(surface, _point(LandscapeData.CELLS, i + 1), _point(LandscapeData.CELLS, i))
	_skirt.mesh = surface.commit()

func _side(surface: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var bottom_a := Vector3(a.x, -1.6, a.z)
	var bottom_b := Vector3(b.x, -1.6, b.z)
	var normal := (bottom_a - a).cross(b - a).normalized()
	surface.set_normal(normal)
	for p in [a, b, bottom_a, b, bottom_b, bottom_a]:
		var top: bool = p.y > -1.59
		surface.set_color((Color("ad9875") if top else Color("766457")).srgb_to_linear())
		surface.add_vertex(p)
