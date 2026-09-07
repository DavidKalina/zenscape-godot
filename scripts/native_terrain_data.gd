class_name NativeTerrainData
extends RefCounted
## Edit the imported chunk's own welded vertices, retaining every material/UV
## channel and the original irregular topology. No replacement heightfield.
const MIN_HEIGHT := -1.5
const MAX_HEIGHT := 24.0
const ASSETS := ["tree","rock","flower","arch","bigfoot_tree","waterfall"]
const MEADOW_CELLS := 56
const MEADOW_STEP := 0.5
var meadow := PackedFloat32Array()
var grass := PackedFloat32Array()
var blades := PackedFloat32Array()
var objects: Array[Dictionary] = []
var ponds: Array[Dictionary] = []
var next_id := 1
var blank := false
var source_mesh: ArrayMesh
var heights := PackedFloat32Array()
var original_heights := PackedFloat32Array()
var points := PackedVector2Array()
var _cover_noise := PackedFloat32Array()
var vertex_ids := PackedInt32Array()
var _arrays: Array
var _buckets := {}
var _neighbors: Array[PackedInt32Array] = []
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _before := {}

func setup(mesh: ArrayMesh) -> void:
	blades.resize(MEADOW_CELLS*MEADOW_CELLS)
	blades.fill(0.0)
	grass.resize(MEADOW_CELLS*MEADOW_CELLS)
	grass.fill(0.0)
	meadow.resize(MEADOW_CELLS*MEADOW_CELLS)
	meadow.fill(0.0)
	source_mesh = mesh
	_arrays = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = _arrays[Mesh.ARRAY_VERTEX]
	var ids := {}
	for vertex in vertices:
		var point := Vector2(vertex.x, vertex.z)
		if not ids.has(point):
			ids[point] = points.size()
			points.append(point)
			heights.append(vertex.y)
			_neighbors.append(PackedInt32Array())
		vertex_ids.append(ids[point])
	original_heights = heights.duplicate()
	var cover_noise := NativeMountainShape.new(7)
	for point in points:
		_cover_noise.append(cover_noise.fbm(point*0.4))
	for i in range(0, vertex_ids.size(), 3):
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for j in range(3):
			var id := vertex_ids[i+j]
			low = low.min(points[id])
			high = high.max(points[id])
			for k in range(3):
				var neighbor := vertex_ids[i+k]
				if neighbor != id and neighbor not in _neighbors[id]:
					_neighbors[id].append(neighbor)
		for z in range(floori(low.y/2), floori(high.y/2)+1):
			for x in range(floori(low.x/2), floori(high.x/2)+1):
				var key := Vector2i(x,z)
				if not _buckets.has(key):
					_buckets[key] = []
				_buckets[key].append(i)

func height_at(x: float, z: float) -> Variant:
	return sample(Vector2(x,z), heights)

func sample(point: Vector2, values: PackedFloat32Array) -> Variant:
	for i: int in _buckets.get(Vector2i(floori(point.x/2), floori(point.y/2)), []):
		var a := points[vertex_ids[i]]
		var b := points[vertex_ids[i+1]]
		var c := points[vertex_ids[i+2]]
		var denominator := (b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
		if absf(denominator) < 0.000001:
			continue
		var u := ((b.y-c.y)*(point.x-c.x)+(c.x-b.x)*(point.y-c.y))/denominator
		var v := ((c.y-a.y)*(point.x-c.x)+(a.x-c.x)*(point.y-c.y))/denominator
		if u >= -0.00001 and v >= -0.00001 and u+v <= 1.00001:
			return u*values[vertex_ids[i]]+v*values[vertex_ids[i+1]]+(1.0-u-v)*values[vertex_ids[i+2]]
	return null

func delta_at(point: Vector2) -> float:
	var current: Variant = sample(point, heights)
	var original: Variant = sample(point, original_heights)
	return float(current)-float(original) if current != null and original != null else 0.0

func ray_hit(origin: Vector3, direction: Vector3) -> Variant:
	var nearest: Variant = null
	var distance := INF
	for i in range(0, vertex_ids.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, _vertex(vertex_ids[i]), _vertex(vertex_ids[i+1]), _vertex(vertex_ids[i+2]))
		if hit != null and origin.distance_squared_to(hit) < distance:
			nearest = hit
			distance = origin.distance_squared_to(hit)
	return nearest

func _vertex(id: int) -> Vector3:
	return Vector3(points[id].x, heights[id], points[id].y)

func begin_stroke() -> void:
	if _before.is_empty():
		_before = _snapshot()

func end_stroke() -> bool:
	if _before.is_empty():
		return false
	var changed := _snapshot() != _before
	if changed:
		_undo.append(_before)
		if _undo.size() > 50:
			_undo.pop_front()
		_redo.clear()
	_before = {}
	return changed

func brush(center: Vector2, radius: float, amount: float, mode: String, level: float) -> void:
	if radius <= 0.0 or amount <= 0.0:
		return
	var before := heights.duplicate()
	for i in range(points.size()):
		var distance := points[i].distance_to(center)
		if distance >= radius:
			continue
		var weight := 1.0-smoothstep(0.0,radius,distance)
		match mode:
			"raise": heights[i] += amount*weight
			"lower": heights[i] -= amount*weight
			"flatten": heights[i] = move_toward(heights[i],level,amount*weight)
			"smooth":
				var total := 0.0
				for neighbor in _neighbors[i]:
					total += before[neighbor]
				if not _neighbors[i].is_empty():
					heights[i] = lerpf(heights[i],total/_neighbors[i].size(),1.0-exp(-amount*weight*5.0))
		heights[i] = clampf(heights[i],MIN_HEIGHT,MAX_HEIGHT)

func undo() -> bool:
	end_stroke()
	if _undo.is_empty():
		return false
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	return true

func redo() -> bool:
	end_stroke()
	if _redo.is_empty():
		return false
	_undo.append(_snapshot())
	_restore(_redo.pop_back())
	return true

func build_mesh() -> ArrayMesh:
	if heights == original_heights and not blank and grass.count(0.0) == grass.size():
		return source_mesh
	var arrays := _arrays.duplicate(true)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in range(vertices.size()):
		vertices[i].y = heights[vertex_ids[i]]
		var grid := (points[vertex_ids[i]]+Vector2(14,14))/MEADOW_STEP
		var cell := clampi(int(grid.y),0,MEADOW_CELLS-1)*MEADOW_CELLS+clampi(int(grid.x),0,MEADOW_CELLS-1)
		var patch := _cover_noise[vertex_ids[i]]
		var grass_color := Color("7fb069" if patch > 0.55 else "4a8548" if patch < 0.42 else "5d9e53").srgb_to_linear()
		if blank:
			var soil := Color("b49d78").srgb_to_linear()
			colors[i] = soil.lerp(grass_color,maxf(grass[cell],meadow[cell])) * (0.965+0.07*uv2[i].x)
		elif grass[cell] > 0.0:
			colors[i] = colors[i].lerp(grass_color,grass[cell])
		if uv2.size() == vertices.size():
			uv2[i].y = vertices[i].y # The existing growth shader reads target height here.
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3):
			normals[i+j] = normal
			if blank:
				# Original terrain.js uses flat color bands: slope selects rock,
				# then snow covers high faces that are not sheer cliff walls.
				var center := (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
				var slope := sqrt(maxf(0.0,1.0-normal.y*normal.y))/maxf(normal.y,0.001)
				var variation := 0.94+0.12*uv2[i].x
				if center.y > 3.7 or slope > 1.1:
					colors[i+j] = Color("8d8577" if uv2[i].x > 0.5 else "6f6a5f").srgb_to_linear()*variation
				if center.y > 5.5 and slope < 2.4:
					colors[i+j] = Color("f4f7fa").srgb_to_linear()*variation
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var result := ArrayMesh.new()
	var flags := source_mesh.surface_get_format(0) & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
	result.surface_set_material(0, source_mesh.surface_get_material(0))
	return result

func reset_flat() -> void:
	blank = true
	heights.fill(0.0)
	blades.fill(0.0)
	grass.fill(0.0)
	meadow.fill(0.0)
	objects.clear()
	ponds.clear()
	next_id = 1

func _snapshot() -> Dictionary:
	return {"heights": heights.duplicate(), "blank": blank, "meadow":meadow.duplicate(), "grass":grass.duplicate(), "blades":blades.duplicate(), "objects":objects.duplicate(true), "ponds":ponds.duplicate(true), "next_id":next_id}

func _restore(state: Dictionary) -> void:
	heights = state.heights.duplicate()
	blank = state.blank
	meadow = state.meadow.duplicate()
	grass = state.grass.duplicate()
	blades = state.blades.duplicate()
	objects.assign(state.objects.duplicate(true))
	ponds.assign(state.ponds.duplicate(true))
	next_id = state.next_id

func meadow_side() -> int:
	return MEADOW_CELLS

func meadow_step() -> float:
	return MEADOW_STEP

func meadow_position(x: int, z: int) -> Vector2:
	return Vector2(x,z)*MEADOW_STEP-Vector2(14,14)

func ground_height(point: Vector2) -> Variant:
	return height_at(point.x,point.y)

func grass_density(index: int) -> float:
	return maxf(blades[index],meadow[index])

func paint_grass(center: Vector2, radius: float, density: float) -> void:
	_paint_cover(grass,center,radius,density)

func paint_blades(center: Vector2, radius: float, density: float) -> void:
	_paint_cover(blades,center,radius,density)

func _paint_cover(layer: PackedFloat32Array, center: Vector2, radius: float, density: float) -> void:
	if radius <= 0.0:
		return
	for z in range(MEADOW_CELLS):
		for x in range(MEADOW_CELLS):
			var distance := (meadow_position(x,z)+Vector2.ONE*MEADOW_STEP*0.5).distance_to(center)
			if distance < radius:
				var index := z*MEADOW_CELLS+x
				layer[index] = lerpf(layer[index],clampf(density,0.0,1.0),1.0-smoothstep(0.0,radius,distance))

func mountain(center: Vector2, radius: float, peak: float, variation := 7, angle := 0.0) -> void:
	if radius <= 0.0:
		return
	var shape := NativeMountainShape.new(variation)
	for i in range(points.size()):
		var local := (points[i]-center).rotated(-angle)/radius
		if local.length() >= 1.0:
			continue
		var height := clampf(peak*shape.height(local),0.0,MAX_HEIGHT)
		heights[i] = maxf(heights[i],height)

func paint_meadow(center: Vector2, radius: float, amount: float) -> void:
	for z in range(MEADOW_CELLS):
		for x in range(MEADOW_CELLS):
			var point := meadow_position(x,z)+Vector2.ONE*MEADOW_STEP*0.5
			var distance := point.distance_to(center)
			if distance < radius:
				var index := z*MEADOW_CELLS+x
				meadow[index] = clampf(meadow[index]+amount*(1.0-smoothstep(0.0,radius,distance)),0.0,1.0)

func place(kind: String, point: Vector2, angle := 0.0, size := 1.0) -> int:
	if kind == "waterfall" or kind not in ASSETS or ground_height(point) == null or objects.size() >= GardenData.MAX_OBJECTS or next_id >= 2147483647:
		return -1
	if not GardenData._number(angle,-TAU*100,TAU*100) or not GardenData._number(size,0.1,5.0):
		return -1
	var id := next_id
	next_id += 1
	objects.append({"id":id,"asset":kind,"x":point.x,"z":point.y,"angle":angle,"scale":size})
	return id

func add_waterfall(start: Vector2, finish: Vector2, width: float) -> bool:
	if ground_height(start) == null or ground_height(finish) == null or start.distance_to(finish) < 0.5:
		return false
	if not GardenData._number(width,0.1,5.0) or objects.size() >= GardenData.MAX_OBJECTS or next_id >= 2147483647:
		return false
	var item := {"id":next_id,"asset":"waterfall","x":start.x,"z":start.y,"end_x":finish.x,"end_z":finish.y,"angle":0.0,"scale":width}
	var ends := NativeGardenFalls.endpoints(self,item)
	if ends[0].y <= ends[1].y+0.5 or not NativeGardenFalls.clear_path(self,item):
		return false
	objects.append(item)
	next_id += 1
	return true

func object_position(item: Dictionary) -> Vector3:
	return Vector3(item.x,height_at(item.x,item.z),item.z)

func erase_objects(point: Vector2, radius: float) -> void:
	objects = objects.filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(point) > radius)

func pond_surface(pond: Dictionary) -> PackedVector3Array:
	return NativeGardenWater.surface(self,pond)

func pond_fetch(point: Vector2, level: float) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	for i in range(8):
		var direction := Vector2.from_angle(float(i)*PI/4.0)
		var distance := 0.0
		for step in range(1,57):
			var height: Variant = ground_height(point+direction*float(step)*0.5)
			if height == null or height >= level:
				break
			distance = float(step)*0.5
		distances.append(distance)
	return distances

func add_pond(point: Vector2, level: float) -> bool:
	var height: Variant = ground_height(point)
	if height == null or not is_finite(level) or level <= height or level > MAX_HEIGHT:
		return false
	var candidate := {"x":point.x,"z":point.y,"level":level}
	var surface := pond_surface(candidate)
	if surface.is_empty():
		return false
	for i in range(ponds.size()-1,-1,-1):
		if GardenWater.covers(surface,Vector2(ponds[i].x,ponds[i].z)) or GardenWater.covers(pond_surface(ponds[i]),point):
			ponds.remove_at(i)
	if ponds.size() >= GardenData.MAX_PONDS:
		return false
	ponds.append(candidate)
	return true

func to_document() -> Dictionary:
	return {"version":5,"template":_template_id(),"heights":Array(heights),"blank":blank,"meadow":Array(meadow),"grass":Array(grass),"blades":Array(blades),"objects":objects.duplicate(true),"ponds":ponds.duplicate(true),"next_id":next_id}

func _template_id() -> String:
	return var_to_bytes([points,vertex_ids,original_heights]).hex_encode().sha256_text()

func load_document(document: Variant) -> bool:
	if not document is Dictionary or (document.get("version") != 3 and document.get("version") != 4 and document.get("version") != 5) or document.get("template") != _template_id() or not document.get("blank") is bool:
		return false
	var loaded := {}
	for field: String in ["heights","meadow","grass","blades"]:
		var values: Variant = document.get(field)
		if (field == "grass" and document.version == 3) or (field == "blades" and document.version != 5):
			values = Array(PackedFloat32Array())
			values.resize(meadow.size())
			values.fill(0.0)
		var count := heights.size() if field == "heights" else meadow.size()
		if not values is Array or values.size() != count:
			return false
		for value: Variant in values:
			if not GardenData._number(value,MIN_HEIGHT if field == "heights" else 0.0,MAX_HEIGHT if field == "heights" else 1.0):
				return false
		loaded[field] = PackedFloat32Array(values)
	if document.version == 4:
		loaded.blades = loaded.grass.duplicate() # Preserve saved vegetation; new Grass paints only ground.
	loaded.blank = document.blank
	loaded.objects = []
	loaded.ponds = []
	if not GardenData._integer(document.get("next_id")) or document.next_id < 1:
		return false
	loaded.next_id = int(document.next_id)
	var ids := {}
	for field: String in ["objects","ponds"]:
		var records: Variant = document.get(field)
		if not records is Array or records.size() > (GardenData.MAX_OBJECTS if field == "objects" else GardenData.MAX_PONDS):
			return false
		for item: Variant in records:
			if not item is Dictionary or not GardenData._number(item.get("x"),-14,14) or not GardenData._number(item.get("z"),-14,14):
				return false
			var point := Vector2(item.x,item.z)
			if ground_height(point) == null:
				return false
			var record := {"x":point.x,"z":point.y}
			if field == "objects":
				if item.get("asset") not in ASSETS or not GardenData._integer(item.get("id")) or item.id < 1 or item.id >= loaded.next_id or ids.has(item.id):
					return false
				if not GardenData._number(item.get("angle"),-TAU*100,TAU*100) or not GardenData._number(item.get("scale"),0.1,5.0):
					return false
				if item.asset == "waterfall":
					if not GardenData._number(item.get("end_x"),-14,14) or not GardenData._number(item.get("end_z"),-14,14):
						return false
					var endpoint := Vector2(item.end_x,item.end_z)
					if ground_height(endpoint) == null or endpoint.distance_to(point) < 0.5:
						return false
					record.merge({"end_x":endpoint.x,"end_z":endpoint.y})
				ids[item.id] = true
				record.merge({"id":int(item.id),"asset":item.asset,"angle":float(item.angle),"scale":float(item.scale)})
			else:
				if not GardenData._number(item.get("level"),MIN_HEIGHT,MAX_HEIGHT):
					return false
				record.level = float(item.level)
			loaded[field].append(record)
	_restore(loaded)
	_undo.clear()
	_redo.clear()
	_before = {}
	return true
