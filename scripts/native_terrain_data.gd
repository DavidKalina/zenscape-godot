class_name NativeTerrainData
extends RefCounted
## Edit the imported chunk's own welded vertices, retaining every material/UV
## channel and the original irregular topology. No replacement heightfield.
const MIN_HEIGHT := -1.5
const MAX_HEIGHT := 24.0
const ASSETS := ["tree","rock","flower","arch","bigfoot_tree","waterfall","broadleaf","shrub","reeds","bank_grass","button_flower","spike_flower","umbel_flower","daisy_flower","grass_tuft","log","stump","snag","mushroom","boulder_1","boulder_2","boulder_3","boulder_4"]
const MEADOW_CELLS := 56
const MEADOW_STEP := 0.5
var meadow := PackedFloat32Array()
var grass := PackedFloat32Array()
var blades := PackedFloat32Array()
var objects: Array[Dictionary] = []
var ponds: Array[Dictionary] = []
var streams: Array[Dictionary] = []
var landscape_waterfall := false
var next_id := 1
var blank := false
var source_mesh: ArrayMesh
var heights := PackedFloat32Array()
var original_heights := PackedFloat32Array()
var points := PackedVector2Array()
var _face_grass := PackedColorArray()
var _palette := preload("res://scripts/native_terrain_palette.gd").new()
var vertex_ids := PackedInt32Array()
var _arrays: Array
var _buckets := {}
var _neighbors: Array[PackedInt32Array] = []
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _before := {}
var _recipe_settings := {}
var _recipe: RefCounted
var _recipe_heights := PackedFloat32Array()
var _recipe_gradients: Array[Vector2] = []

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
	for i in range(0, vertices.size(), 3):
		var x: float = (float(vertices[i].x)+float(vertices[i+1].x)+float(vertices[i+2].x))/3.0
		var z: float = (float(vertices[i].z)+float(vertices[i+1].z)+float(vertices[i+2].z))/3.0
		_face_grass.append(_palette.grass_at_coordinates(x,z))
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

func ground_coverage(point: Vector2) -> float:
	var grid := (point+Vector2(14,14))/MEADOW_STEP
	var cell := clampi(int(grid.y),0,MEADOW_CELLS-1)*MEADOW_CELLS+clampi(int(grid.x),0,MEADOW_CELLS-1)
	return maxf(grass[cell],meadow[cell]) if blank else grass[cell]

func grass_color_at(point: Vector2) -> Color:
	return _palette.grass_at(point)

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
		if uv2.size() == vertices.size():
			uv2[i].y = vertices[i].y # The existing growth shader reads target height here.
	var water_field := preload("res://scripts/native_recipe_water.gd").shoreline(self) if blank else {}
	var sculpted := _recipe != null and heights != _recipe_heights
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		var center := (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
		var point := Vector2(center.x,center.z)
		var face_x: float = (float(vertices[i].x)+float(vertices[i+1].x)+float(vertices[i+2].x))/3.0
		var face_z: float = (float(vertices[i].z)+float(vertices[i+1].z)+float(vertices[i+2].z))/3.0
		var coverage := ground_coverage(point)
		var face_color := Color("b49d78").srgb_to_linear().lerp(_face_grass[i/3],coverage)
		if blank:
			var slope := sqrt(maxf(0.0,1.0-normal.y*normal.y))/maxf(normal.y,0.001)
			if _recipe != null:
				var gradient: Vector2 = _recipe_gradients[i/3]
				if sculpted:
					gradient += Vector2((_sculpt_delta(point+Vector2(0.25,0))-_sculpt_delta(point-Vector2(0.25,0)))/0.5,(_sculpt_delta(point+Vector2(0,0.25))-_sculpt_delta(point-Vector2(0,0.25)))/0.5)
				slope = gradient.length()
			# The sealed cut is not a geological cliff. Source colorAt samples
			# the continuous ground before its border is lowered to the rim.
			var cut_rim := false
			for j in range(3):
				var p := points[vertex_ids[i+j]]
				cut_rim = cut_rim or maxf(absf(p.x),absf(p.y)) > 13.9999
			if center.y > _palette.snowline-1.8 or (slope > _palette.rock_slope and (not cut_rim or _recipe != null)):
				face_color = _palette.rock_at_coordinates(face_x,face_z)
			if center.y > _palette.snowline and slope < 2.4:
				face_color = _palette.shimmer_coordinates(_palette.snow,face_x,face_z)
			if not water_field.is_empty():
				var shore:=preload("res://scripts/native_recipe_water.gd").sample_grid(water_field.shore,face_x,face_z)
				var running: bool=preload("res://scripts/native_recipe_water.gd").kind_at(water_field,face_x,face_z)==2
				if running and shore<1.7 and center.y<_palette.snowline-1.8:
					face_color=_face_grass[i/3]
				if shore < 0.75 and slope<2.2:
					var bank: Color = _palette.gravel if running else _palette.sand
					if shore < -0.05:
						bank *= 0.78-0.16*minf(1.0,preload("res://scripts/native_recipe_water.gd").sample_grid(water_field.depth,face_x,face_z))
					face_color = _palette.shimmer_coordinates(bank,face_x,face_z)
		if not blank:
			face_color = colors[i].lerp(_face_grass[i/3],coverage)
		for j in range(3):
			normals[i+j] = normal
			if blank:
				colors[i+j] = face_color
			elif coverage > 0.0:
				colors[i+j] = face_color
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var result := ArrayMesh.new()
	var flags := source_mesh.surface_get_format(0) & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
	result.surface_set_material(0, source_mesh.surface_get_material(0))
	return result

func _set_recipe(settings: Dictionary) -> void:
	_recipe_settings = settings.duplicate(true)
	_recipe = null if settings.is_empty() else preload("res://scripts/native_terrain_recipe.gd").new(settings)
	_recipe_heights.clear()
	_recipe_gradients.clear()
	if _recipe == null: return
	for point in points:
		_recipe_heights.append(0.6 if maxf(absf(point.x),absf(point.y)) > 13.9999 else _recipe.height(point.x,point.y))
	var vertices: PackedVector3Array = _arrays[Mesh.ARRAY_VERTEX]
	for i in range(0,vertices.size(),3):
		var x: float = (float(vertices[i].x)+float(vertices[i+1].x)+float(vertices[i+2].x))/3.0
		var z: float = (float(vertices[i].z)+float(vertices[i+1].z)+float(vertices[i+2].z))/3.0
		_recipe_gradients.append(Vector2((_recipe.height(x+0.25,z)-_recipe.height(x-0.25,z))/0.5,(_recipe.height(x,z+0.25)-_recipe.height(x,z-0.25))/0.5))

func _sculpt_delta(point: Vector2) -> float:
	point = point.clamp(Vector2(-14,-14),Vector2(14,14))
	return float(sample(point,heights))-float(sample(point,_recipe_heights))

func form_range(height_scale := 1.0, width_scale := 1.0, heading := 0.0, variation := 0) -> void:
	_set_recipe({"kind":"range","height":height_scale,"width":width_scale,"heading":heading,"variation":variation})
	heights = _recipe_heights.duplicate()

func form_foundation(elevation := 0.0, relief := 1.0) -> void:
	landscape_waterfall=false
	_set_recipe({"kind":"foundation","elevation":elevation,"relief":relief})
	heights = _recipe_heights.duplicate()

func reset_flat() -> void:
	_set_recipe({})
	blank = true
	heights.fill(0.0)
	blades.fill(0.0)
	grass.fill(0.0)
	meadow.fill(0.0)
	objects.clear()
	ponds.clear()
	streams.clear()
	landscape_waterfall=false
	next_id = 1

func _snapshot() -> Dictionary:
	return {"landscape_waterfall":landscape_waterfall,"terrain_recipe":_recipe_settings.duplicate(true), "heights": heights.duplicate(), "blank": blank, "meadow":meadow.duplicate(), "grass":grass.duplicate(), "blades":blades.duplicate(), "objects":objects.duplicate(true), "ponds":ponds.duplicate(true), "streams":streams.duplicate(true), "next_id":next_id}

func _restore(state: Dictionary) -> void:
	_set_recipe(state.get("terrain_recipe",{}))
	landscape_waterfall=state.get("landscape_waterfall",false)
	heights = state.heights.duplicate()
	blank = state.blank
	meadow = state.meadow.duplicate()
	grass = state.grass.duplicate()
	blades = state.blades.duplicate()
	objects.assign(state.objects.duplicate(true))
	ponds.assign(state.ponds.duplicate(true))
	streams.assign(state.get("streams",[]).duplicate(true))
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

func place(kind: String, point: Vector2, angle := 0.0, size := 1.0, pose: Dictionary = {}, tint := "") -> int:
	if kind == "waterfall" or kind not in ASSETS or ground_height(point) == null or objects.size() >= GardenData.MAX_OBJECTS or next_id >= 2147483647:
		return -1
	if not GardenData._number(angle,-TAU*100,TAU*100) or not GardenData._number(size,0.1,5.0):
		return -1
	if not pose.is_empty() and (kind in ["arch","bigfoot_tree","waterfall"] or not preload("res://scripts/native_object_pose.gd").valid(pose)):
		return -1
	if not tint.is_empty() and (kind in ["arch","bigfoot_tree","waterfall"] or not preload("res://scripts/native_object_pose.gd").valid_tint(tint)):
		return -1
	var id := next_id
	next_id += 1
	objects.append({"id":id,"asset":kind,"x":point.x,"z":point.y,"angle":angle,"scale":size})
	if not pose.is_empty(): objects.back()["pose"] = pose.duplicate(true)
	if not tint.is_empty(): objects.back()["tint"] = tint
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
	return Vector3(item.x,height_at(item.x,item.z)+(preload("res://scripts/native_object_pose.gd").decode_offset(item.pose) if item.has("pose") else 0.0),item.z)

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
	return {"version":8,"landscape_waterfall":landscape_waterfall,"terrain_recipe":preload("res://scripts/native_terrain_recipe.gd").encode(_recipe_settings),"template":_template_id(),"heights":Array(heights),"blank":blank,"meadow":Array(meadow),"grass":Array(grass),"blades":Array(blades),"objects":objects.duplicate(true),"ponds":ponds.duplicate(true),"streams":streams.map(func(value): return preload("res://scripts/native_stream_record.gd").encode(value)),"next_id":next_id}

func _template_id() -> String:
	return var_to_bytes([points,vertex_ids,original_heights]).hex_encode().sha256_text()

func load_document(document: Variant) -> bool:
	if not document is Dictionary or (document.get("version") != 3 and document.get("version") != 4 and document.get("version") != 5 and document.get("version") != 6 and document.get("version") != 7 and document.get("version") != 8) or document.get("template") != _template_id() or not document.get("blank") is bool:
		return false
	var recipe: Variant = preload("res://scripts/native_terrain_recipe.gd").decode(document.get("terrain_recipe",{})) if document.version >= 6 else {}
	if not preload("res://scripts/native_terrain_recipe.gd").valid(recipe):
		return false
	var enabled: Variant=document.get("landscape_waterfall") if document.version>=8 else false
	if not enabled is bool or (enabled and recipe.get("kind")!="range"): return false
	var loaded := {"terrain_recipe":recipe,"landscape_waterfall":enabled}
	for field: String in ["heights","meadow","grass","blades"]:
		var values: Variant = document.get(field)
		if (field == "grass" and document.version == 3) or (field == "blades" and document.version < 5):
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
	loaded.streams = []
	if document.version>=7:
		if not document.get("streams") is Array or document.streams.size()>128: return false
		for item in document.streams:
			var stream: Variant=preload("res://scripts/native_stream_record.gd").decode(item)
			if stream==null: return false
			loaded.streams.append(stream)
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
				if item.has("pose"):
					if item.asset in ["arch","bigfoot_tree","waterfall"] or not preload("res://scripts/native_object_pose.gd").valid(item.pose): return false
					record.pose = item.pose.duplicate(true)
				if item.has("tint"):
					if item.asset in ["arch","bigfoot_tree","waterfall"] or not preload("res://scripts/native_object_pose.gd").valid_tint(item.tint): return false
					record.tint = item.tint
				if item.has("landscape"):
					if not item.landscape is bool: return false
					record.landscape = item.landscape
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

func fill_landscape_streams() -> bool:
	if _recipe==null or _recipe_settings.kind!="range": return false
	var courses: Array[Dictionary]=[]
	var angle: float=_recipe_settings.heading
	var width: float=_recipe_settings.width
	var height: float=_recipe_settings.height
	for source in _recipe.source.g.streams:
		var points: Array=[]
		for p in source.pts:
			points.append({"x":(p.x*cos(angle)-p.z*sin(angle))*width,"z":(p.x*sin(angle)+p.z*cos(angle))*width,"h":0.6+(p.h-0.6)*height})
		var course: Dictionary={"pts":points,"width":source.width*width,"depth":source.depth*height,"surface":source.surface*height,"capHead":source.capHead,"capTail":source.capTail}
		if not preload("res://scripts/native_stream_record.gd").valid(course): return false
		courses.append(course)
	streams=courses
	return true

func stream_ground_height(x: float,z: float) -> float:
	var p:=Vector2(x,z).clamp(Vector2(-14,-14),Vector2(14,14))
	if _recipe==null: return float(height_at(p.x,p.y))
	return _recipe.height(x,z)+(_sculpt_delta(p) if heights!=_recipe_heights else 0.0)

func fill_landscape_waterfall() -> bool:
	if _recipe==null or _recipe_settings.kind!="range": return false
	landscape_waterfall=true
	return true

func waterfall_transform() -> Transform3D:
	var settings: Dictionary=_recipe_settings
	return Transform3D(Basis(Vector3.UP,-settings.heading).scaled_local(Vector3(settings.width,settings.height,settings.width)),Vector3(0.0,0.6*(1.0-settings.height),0.0))

func waterfall_ground_height(x: float,z: float) -> float:
	var angle: float=_recipe_settings.heading
	var width: float=_recipe_settings.width
	var px: float=(x*cos(angle)-z*sin(angle))*width
	var pz: float=(x*sin(angle)+z*cos(angle))*width
	return 0.6+(stream_ground_height(px,pz)-0.6)/_recipe_settings.height

func waterfall_strands() -> Array[Dictionary]:
	if not landscape_waterfall or _recipe==null: return []
	return preload("res://scripts/native_fall_strand.gd").landscape(waterfall_ground_height,_recipe.source.pool,_recipe.source.g)

func waterfall_impacts() -> Array[Dictionary]:
	var impacts: Array[Dictionary]=[]
	if not landscape_waterfall: return impacts
	var angle: float=_recipe_settings.heading
	var width: float=_recipe_settings.width
	for strand in waterfall_strands():
		var p: Array=strand.impact
		impacts.append({"x":(p[0]*cos(angle)-p[2]*sin(angle))*width,"z":(p[0]*sin(angle)+p[2]*cos(angle))*width,"radius":(0.7+_recipe.source.g.chute.flow*0.5)*width})
	return impacts

## Regenerate the source's scatter layers and rim boulders as ordinary object
## records (catalog kinds, float32 poses, linear tints) that follow the range
## transform. Records are tagged `landscape` so refilling replaces only them.
func fill_landscape_flora() -> bool:
	if _recipe==null or _recipe_settings.kind!="range": return false
	var angle: float=_recipe_settings.heading
	var width: float=_recipe_settings.width
	var height_scale: float=_recipe_settings.height
	var edited: bool=heights!=_recipe_heights
	var ground:=func(x: float,z: float) -> float:
		var h: float=_recipe.source.height_at(x,z)
		if edited:
			h+=_sculpt_delta(Vector2((x*cos(angle)-z*sin(angle))*width,(x*sin(angle)+z*cos(angle))*width))/height_scale
		return h
	var plot_ponds: Array=[]
	for pond in ponds:
		plot_ponds.append({"x":(pond.x*cos(angle)+pond.z*sin(angle))/width,"z":(-pond.x*sin(angle)+pond.z*cos(angle))/width,"level":0.6+(pond.level-0.6)/height_scale})
	var plot_streams: Array=[]
	for stream in streams:
		var pts: Array=[]
		for p in stream.pts:
			pts.append({"x":(p.x*cos(angle)+p.z*sin(angle))/width,"z":(-p.x*sin(angle)+p.z*cos(angle))/width,"h":0.6+(p.h-0.6)/height_scale})
		plot_streams.append({"pts":pts,"width":stream.width/width,"depth":stream.depth/height_scale,"surface":stream.surface/height_scale})
	var field: Dictionary=preload("res://scripts/native_flora.gd").water_field(ground,plot_ponds,plot_streams)
	var placements: Array=preload("res://scripts/native_flora.gd").build(ground,_recipe.source,field)
	var pivots: Dictionary=preload("res://scripts/native_asset_catalog.gd").pivots()
	var world:=waterfall_transform()
	var kept: Array[Dictionary]=[]
	for item in objects:
		if not item.get("landscape",false): kept.append(item)
	var before:=objects
	var before_id:=next_id
	objects=kept
	for entry in placements:
		var m: PackedFloat64Array=entry.m
		var record: Transform3D
		if entry.pivot:
			var pivot: Transform3D=pivots[entry.asset+":"+preload("res://scripts/native_asset_catalog.gd").PARTS[entry.asset][0]]
			record=Transform3D(world.basis,world*(Vector3(m[12],m[13],m[14])-pivot.origin))
		else:
			record=world*Transform3D(Basis(Vector3(m[0],m[1],m[2]),Vector3(m[4],m[5],m[6]),Vector3(m[8],m[9],m[10])),Vector3(m[12],m[13],m[14]))
		var point:=Vector2(record.origin.x,record.origin.z)
		var height: Variant=height_at(point.x,point.y)
		var tint: String=""
		if entry.color!=null: tint=preload("res://scripts/native_object_pose.gd").encode_tint(Color(entry.color[0],entry.color[1],entry.color[2]))
		if height==null or place(entry.asset,point,0.0,1.0,preload("res://scripts/native_object_pose.gd").make(record.basis,record.origin.y-float(height)),tint)<0:
			objects=before
			next_id=before_id
			return false
		objects.back()["landscape"]=true
	return not placements.is_empty()
