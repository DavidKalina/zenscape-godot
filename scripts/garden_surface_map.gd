class_name GardenSurfaceMap
extends RefCounted
## Rasterize editable terrain and connected pond triangles into the same surface
## texture channels used by the port's atmosphere and precipitation.
const SIZE := 128
const SPAN := 32.0
var ground := ImageTexture.new()
var stream := ImageTexture.new()

func update(data: GardenData, water: PackedVector3Array) -> void:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBAF)
	image.fill(Color(-1000, -1000, -1000, -1000))
	for z in range(SIZE):
		for x in range(SIZE):
			var point := _point(x, z)
			if data.contains(point):
				var height := data.height_at(point)
				image.set_pixel(x, z, Color(height, height, -1000, -1000))
	paint_water(image,water)
	if ground.get_width() == 0:
		ground.set_image(image)
		var empty := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBAF)
		empty.fill(Color(0,0,0,0))
		stream.set_image(empty)
	else:
		ground.update(image)

static func _point(x: int, z: int) -> Vector2:
	return (Vector2(x,z) + Vector2.ONE * 0.5) * SPAN / SIZE - Vector2.ONE * SPAN * 0.5

static func paint_water(image: Image, water: PackedVector3Array) -> void:
	for i in range(0, water.size(), 3):
		var polygon := PackedVector2Array()
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for j in range(3):
			var point := Vector2(water[i+j].x, water[i+j].z)
			polygon.append(point)
			low = low.min(point)
			high = high.max(point)
		var first := (low + Vector2.ONE * SPAN * 0.5) * SIZE / SPAN
		var last := (high + Vector2.ONE * SPAN * 0.5) * SIZE / SPAN
		for z in range(clampi(floori(first.y), 0, SIZE-1), clampi(ceili(last.y), 0, SIZE-1)+1):
			for x in range(clampi(floori(first.x), 0, SIZE-1), clampi(ceili(last.x), 0, SIZE-1)+1):
				if Geometry2D.is_point_in_polygon(_point(x,z), polygon):
					var value := image.get_pixel(x,z)
					var level := water[i].y
					if level > value.r:
						image.set_pixel(x,z,Color(level,value.g,value.g,level))

## Share the reference triangle sampler so rain/fog read the rendered stream's
## height and growth coordinates, including its fitted banks and tapered ends.
static func paint_streams(ground_image: Image,stream_image: Image,nodes: Array[MeshInstance3D]) -> void:
	if nodes.is_empty(): return
	var surfaces: Array[RefCounted]=[]
	for node in nodes:
		var sampler:=preload("res://scripts/reference_ground.gd").new()
		sampler.setup(node)
		surfaces.append(sampler)
	for z in range(SIZE):
		for x in range(SIZE):
			var point:=_point(x,z)
			var value:=ground_image.get_pixel(x,z)
			for sampler in surfaces:
				var height: Variant=sampler.height_at(point.x,point.y)
				if height==null or height<=value.a: continue
				var info: Vector4=sampler.stream_at(point.x,point.y)
				value=Color(maxf(value.g,height),value.g,height,height)
				ground_image.set_pixel(x,z,value)
				stream_image.set_pixel(x,z,Color(info.x,info.y,info.z,info.w))
