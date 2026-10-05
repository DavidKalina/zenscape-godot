class_name GardenSurfaceMap
extends RefCounted
## Rasterize editable terrain and connected pond triangles into the same surface
## texture channels used by the port's atmosphere and precipitation.
const Plate := preload("res://scripts/plate.gd")
const SIZE := Plate.MAP_SIZE
const SPAN := Plate.MAP_SPAN
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

## `clip` restricts the work to a pixel rectangle. Both overlays decide each
## pixel from that pixel's own ground value alone, so painting a sub-rectangle
## over a map whose other pixels are already correct gives the same image as
## painting all of it.
static func paint_water(image: Image, water: PackedVector3Array, clip := Rect2i(0,0,SIZE,SIZE)) -> void:
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
		var span := Rect2i(Vector2i(clampi(floori(first.x),0,SIZE-1),clampi(floori(first.y),0,SIZE-1)),Vector2i.ZERO)
		span = span.expand(Vector2i(clampi(ceili(last.x),0,SIZE-1)+1,clampi(ceili(last.y),0,SIZE-1)+1)).intersection(clip)
		for z in range(span.position.y, span.end.y):
			for x in range(span.position.x, span.end.x):
				if Geometry2D.is_point_in_polygon(_point(x,z), polygon):
					var value := image.get_pixel(x,z)
					var level := water[i].y
					if level > value.r:
						image.set_pixel(x,z,Color(level,value.g,value.g,level))

## Share the reference triangle sampler so rain/fog read the rendered stream's
## height and growth coordinates, including its fitted banks and tapered ends.
static func paint_streams(ground_image: Image,stream_image: Image,nodes: Array[MeshInstance3D],clip := Rect2i(0,0,SIZE,SIZE)) -> void:
	if nodes.is_empty(): return
	paint_stream_samples(ground_image,stream_image,stream_samples(nodes),clip)

## Import render resources on the main thread once. The returned triangle
## samplers can then be copied into data-only worker inputs.
static func stream_samples(nodes: Array[MeshInstance3D]) -> Dictionary:
	var surfaces: Array[RefCounted]=[]
	# Outside a stream's own bounds every sampler misses, so the scan is kept to
	# the pixels the rendered streams actually cover.
	var span := Rect2i()
	for node in nodes:
		var sampler:=preload("res://scripts/reference_ground.gd").new()
		sampler.setup(node)
		surfaces.append(sampler)
		var box := node.transform * node.mesh.get_aabb()
		var low := (Vector2(box.position.x,box.position.z)+Vector2.ONE*SPAN*0.5)*SIZE/SPAN
		var high := (Vector2(box.end.x,box.end.z)+Vector2.ONE*SPAN*0.5)*SIZE/SPAN
		var reach := Rect2i(Vector2i(floori(low.x),floori(low.y)),Vector2i.ZERO).expand(Vector2i(ceili(high.x)+1,ceili(high.y)+1))
		span = reach if span.size == Vector2i.ZERO else span.merge(reach)
	return {"surfaces":surfaces,"span":span}

static func paint_stream_samples(ground_image: Image,stream_image: Image,samples: Dictionary,clip: Rect2i) -> void:
	var surfaces: Array[RefCounted] = samples.surfaces
	var span: Rect2i = samples.span.intersection(clip)
	for z in range(span.position.y,span.end.y):
		for x in range(span.position.x,span.end.x):
			var point:=_point(x,z)
			var value:=ground_image.get_pixel(x,z)
			for sampler in surfaces:
				var height: Variant=sampler.height_at(point.x,point.y)
				if height==null or height<=value.a: continue
				var info: Vector4=sampler.stream_at(point.x,point.y)
				value=Color(maxf(value.g,height),value.g,height,height)
				ground_image.set_pixel(x,z,value)
				stream_image.set_pixel(x,z,Color(info.x,info.y,info.z,info.w))
