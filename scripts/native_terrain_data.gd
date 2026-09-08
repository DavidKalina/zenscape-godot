class_name NativeTerrainData
extends RefCounted
## Edit the imported chunk's own welded vertices, retaining every material/UV
## channel and the original irregular topology. No replacement heightfield.
const MIN_HEIGHT := -1.5
const MAX_HEIGHT := 24.0
const ASSETS := ["leaf_bed","tree","rock","flower","arch","bigfoot_tree","waterfall","broadleaf","shrub","reeds","bank_grass","button_flower","spike_flower","umbel_flower","daisy_flower","grass_tuft","log","stump","snag","mushroom","boulder_1","boulder_2","boulder_3","boulder_4"]
const MEADOW_CELLS := 56
const MEADOW_STEP := 0.5
var meadow := PackedFloat32Array()
var grass := PackedFloat32Array()
var blades := PackedFloat32Array()
var tint := PackedFloat32Array()
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
var _locate_cache := {}
var _locate_face := PackedInt32Array()
var _locate_u := PackedFloat64Array()
var _locate_v := PackedFloat64Array()
var _water_grid_h := PackedFloat64Array()
var _recipe_height_cache := {}
var _recipe_height_count := 0
var _face_margin := 0.0
var _mesh_arrays: Array = []
var _mesh_result: ArrayMesh
var _mesh_heights := PackedFloat32Array()
var _mesh_grass := PackedFloat32Array()
var _mesh_meadow := PackedFloat32Array()
var _mesh_tint := PackedFloat32Array()
var _mesh_blank := false
var _mesh_sculpted := false
var _mesh_signature := PackedByteArray()
var _shore_field := {}
var _shore_ready := false
var _shore_mask := PackedByteArray()
var _shore_changed := false
var _probe := {}
var _probing := false
var _face_x := PackedFloat64Array()
var _face_z := PackedFloat64Array()
var _face_rock := PackedColorArray()
var _face_snow := PackedColorArray()
var _face_shimmer := PackedFloat64Array()
var _face_rim := PackedByteArray()
var _strands_cache: Array[Dictionary] = []
var _strands_probe := {}
var _strands_seen := {}
var _strands_ready := false
var _face_center := PackedVector2Array()
var _face_probe := PackedInt32Array()
var _ground_tint := Color("b49d78").srgb_to_linear()
## Bumped whenever the object records change. Serialising 3,000 records to
## compare them costs more than the refresh it is meant to shorten, so every
## method here that touches `objects` reports the change instead.
var objects_revision := 0
## A waterfall queries the same pond at each cross-section. Reuse its exact
## flood within one terrain state instead of rebuilding topology every time.
const POND_CACHE_LIMIT := 16
var _pond_surfaces := {}
var _pond_cache_heights := PackedFloat32Array()
var _pond_cache_state := PackedByteArray()
var pond_cache_hits := 0
var pond_cache_misses := 0

func setup(mesh: ArrayMesh) -> void:
	_clear_pond_cache()
	blades.resize(MEADOW_CELLS*MEADOW_CELLS)
	blades.fill(0.0)
	grass.resize(MEADOW_CELLS*MEADOW_CELLS)
	grass.fill(0.0)
	meadow.resize(MEADOW_CELLS*MEADOW_CELLS)
	meadow.fill(0.0)
	tint = NativeTerrainTint.make(MEADOW_CELLS*MEADOW_CELLS)
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
	# Every palette lookup a face makes is a function of its fixed XZ centroid, so
	# the noise is evaluated once here instead of on every rebuild.
	for i in range(0, vertices.size(), 3):
		var x: float = (float(vertices[i].x)+float(vertices[i+1].x)+float(vertices[i+2].x))/3.0
		var z: float = (float(vertices[i].z)+float(vertices[i+1].z)+float(vertices[i+2].z))/3.0
		_face_grass.append(_palette.grass_at_coordinates(x,z))
		var center := (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
		_face_center.append(Vector2(center.x,center.z))
		_face_x.append(x)
		_face_z.append(z)
		_face_rock.append(_palette.rock_at_coordinates(x,z))
		_face_snow.append(_palette.shimmer_coordinates(_palette.snow,x,z))
		_face_shimmer.append((_palette.noise.hash_at(x*7.3,z*7.3)-0.5)*0.07)
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
		_face_margin = maxf(_face_margin,(high-low).length())
		_face_rim.append(1 if maxf(absf(low.x),maxf(absf(low.y),maxf(absf(high.x),absf(high.y)))) > 13.9999 else 0)
		for z in range(floori(low.y/2), floori(high.y/2)+1):
			for x in range(floori(low.x/2), floori(high.x/2)+1):
				var key := Vector2i(x,z)
				if not _buckets.has(key):
					_buckets[key] = []
				_buckets[key].append(i)
	# A face's colour reads the sculpt gradient 0.25 from its centroid, which
	# resolves inside a neighbouring triangle, and the meadow cell under that
	# centroid. Growing an edited region by this margin therefore reaches every
	# face whose shading could have moved.
	_face_margin += 0.25+MEADOW_STEP

func height_at(x: float, z: float) -> Variant:
	return sample(Vector2(x,z), heights)

## The triangulation never changes after setup, so the barycentric solution for a
## given XZ point is fixed. Editing only moves vertices vertically. Memoising the
## resolved face and its (u,v) keeps the exact same arithmetic — the same face is
## still chosen in bucket order and the same doubles are multiplied — while
## removing the per-query triangle walk that dominated every refresh.
func sample(point: Vector2, values: PackedFloat32Array) -> Variant:
	var slot: int = _locate_cache.get(point,-1)
	if slot < 0:
		if _locate_cache.size() >= 262144:
			_locate_cache.clear()
			_locate_face.clear()
			_locate_u.clear()
			_locate_v.clear()
			_face_probe.clear()
		slot = _locate_face.size()
		_locate_cache[point] = slot
		_locate(point)
	var i: int = _locate_face[slot]
	if i < 0:
		return null
	if _probing:
		_probe[vertex_ids[i]] = true
		_probe[vertex_ids[i+1]] = true
		_probe[vertex_ids[i+2]] = true
	var u: float = _locate_u[slot]
	var v: float = _locate_v[slot]
	return u*values[vertex_ids[i]]+v*values[vertex_ids[i+1]]+(1.0-u-v)*values[vertex_ids[i+2]]

func _locate(point: Vector2) -> void:
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
			_locate_face.append(i)
			_locate_u.append(u)
			_locate_v.append(v)
			return
	_locate_face.append(-1)
	_locate_u.append(0.0)
	_locate_v.append(0.0)

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

func meadow_cell(point: Vector2) -> int:
	var grid := (point+Vector2(14,14))/MEADOW_STEP
	return clampi(int(grid.y),0,MEADOW_CELLS-1)*MEADOW_CELLS+clampi(int(grid.x),0,MEADOW_CELLS-1)

func ground_coverage(point: Vector2) -> float:
	var cell := meadow_cell(point)
	return maxf(grass[cell],meadow[cell]) if blank else grass[cell]

func tint_weight(point: Vector2) -> float:
	return NativeTerrainTint.weight_at(tint,meadow_cell(point))

func tint_color(point: Vector2) -> Color:
	return NativeTerrainTint.color_at(tint,meadow_cell(point))

func grass_color_at(point: Vector2) -> Color:
	return _palette.grass_at(point)

## A brush dab moves a handful of vertices, so the previous build is kept and
## only the faces that could have changed are recomputed. `dirty_region()`
## reports where the data actually differs from that cached build, and the
## caller may force a full rebuild by clearing the cache first.
func build_mesh(force := false) -> ArrayMesh:
	# The null-budget path never yields; retain the synchronous mesh API for
	# physics, loading, and offline callers.
	return call("build_mesh_budgeted",force,null)

func build_mesh_budgeted(force := false, frame_tree: SceneTree = null) -> ArrayMesh:
	var budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree)
	if force:
		_mesh_result = null
		_shore_ready = false
	if heights == original_heights and not blank and grass.count(0.0) == grass.size() and NativeTerrainTint.empty(tint):
		return source_mesh
	var signature := var_to_bytes([_recipe_settings,ponds,streams,landscape_waterfall])
	var sculpted := _recipe != null and heights != _recipe_heights
	if sculpted:
		_ensure_face_probes()
	var reusable: bool = _mesh_result != null and _mesh_blank == blank and _mesh_sculpted == sculpted and _mesh_signature == signature
	var region: Variant = _mesh_region() if reusable else null
	if region is bool:
		return _mesh_result
	var water_field := _shoreline_field(region) if blank else {}
	if blank and _shore_changed:
		region = null
	var arrays: Array = _mesh_arrays if region != null else _arrays.duplicate(true)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	# The lerp below reads the chunk's untouched authored colour, never the one
	# an earlier incremental build already wrote into the working copy.
	var source_colors: PackedColorArray = _arrays[Mesh.ARRAY_COLOR]
	var paints_uv2 := uv2.size() == vertices.size()
	var biome: Dictionary = preload("res://scripts/native_formation_shape.gd").BIOMES.get(_recipe_settings.get("biome",""),{})
	var snowline: float = biome.get("snowline",_palette.snowline)
	var rock_slope: float = biome.get("rock_slope",_palette.rock_slope)
	var faces: PackedInt32Array = _faces_in(region) if region != null else _all_faces()
	for i in faces:
		if frame_tree != null and i%96 == 0: await budget.checkpoint()
		for j in range(3):
			vertices[i+j].y = heights[vertex_ids[i+j]]
			if paints_uv2:
				uv2[i+j].y = vertices[i+j].y # The existing growth shader reads target height here.
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		var center := (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
		var point := Vector2(center.x,center.z)
		var face := i/3
		var face_x: float = _face_x[face]
		var face_z: float = _face_z[face]
		var cell := meadow_cell(point)
		var coverage: float = maxf(grass[cell],meadow[cell]) if blank else grass[cell]
		var face_color := _ground_tint.lerp(_face_grass[face],coverage)
		var snowed := false
		if blank:
			var slope := sqrt(maxf(0.0,1.0-normal.y*normal.y))/maxf(normal.y,0.001)
			if _recipe != null:
				var gradient: Vector2 = _recipe_gradients[face]
				if sculpted:
					var probe := face*4
					gradient += Vector2((_probe_delta(_face_probe[probe])-_probe_delta(_face_probe[probe+1]))/0.5,(_probe_delta(_face_probe[probe+2])-_probe_delta(_face_probe[probe+3]))/0.5)
				slope = gradient.length()
			# The sealed cut is not a geological cliff. Source colorAt samples
			# the continuous ground before its border is lowered to the rim.
			var cut_rim := _face_rim[face] == 1
			if center.y > snowline-1.8 or (slope > rock_slope and (not cut_rim or _recipe != null)):
				face_color = _face_rock[face]
			if center.y > snowline and slope < 2.4:
				face_color = _face_snow[face]
				snowed = true
			if not water_field.is_empty():
				var shore:=preload("res://scripts/native_recipe_water.gd").sample_grid(water_field.shore,face_x,face_z)
				var running: bool=preload("res://scripts/native_recipe_water.gd").kind_at(water_field,face_x,face_z)==2
				if running and shore<1.7 and center.y<snowline-1.8:
					face_color=_face_grass[face]
				if shore < 0.75 and slope<2.2:
					var bank: Color = _palette.gravel if running else _palette.sand
					if shore < -0.05:
						bank *= 0.78-0.16*minf(1.0,preload("res://scripts/native_recipe_water.gd").sample_grid(water_field.depth,face_x,face_z))
					var shimmer: float = _face_shimmer[face]
					face_color = Color(bank.r+shimmer,bank.g+shimmer,bank.b+shimmer)
		if not blank:
			face_color = source_colors[i].lerp(_face_grass[face],coverage)
		# Snow settles over whatever was painted, so alpine caps keep covering it.
		var painted: float = 0.0 if snowed else NativeTerrainTint.weight_at(tint,cell)
		if painted > 0.0:
			face_color = NativeTerrainTint.blend(face_color,tint,cell,_face_shimmer[face])
		for j in range(3):
			normals[i+j] = normal
			if blank or coverage > 0.0 or painted > 0.0:
				colors[i+j] = face_color
			else:
				# Uncovered faces keep the authored colour a full rebuild would
				# have restored by duplicating the source arrays.
				colors[i+j] = source_colors[i+j]
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var result := ArrayMesh.new()
	var flags := source_mesh.surface_get_format(0) & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
	result.surface_set_material(0, source_mesh.surface_get_material(0))
	_mesh_arrays = arrays
	_mesh_heights = heights.duplicate()
	_mesh_grass = grass.duplicate()
	_mesh_meadow = meadow.duplicate()
	_mesh_tint = tint.duplicate()
	_mesh_blank = blank
	_mesh_sculpted = sculpted
	_mesh_signature = signature
	_mesh_result = result
	return result

## The XZ rectangle holding every vertex whose height differs from `snapshot`,
## grown so it also covers everything those vertices can shade or be sampled
## through. `false` when nothing moved, `null` when the snapshot does not match.
func moved_region(snapshot: PackedFloat32Array) -> Variant:
	if heights == snapshot:
		return false
	if heights.size() != snapshot.size():
		return null
	var region := Rect2()
	var started := false
	for i in range(points.size()):
		if heights[i] == snapshot[i]:
			continue
		region = region.expand(points[i]) if started else Rect2(points[i],Vector2.ZERO)
		started = true
	if not started:
		return null
	return region.grow(_face_margin)

## Whether an edited region can change the water field. Heights only reach the
## flood through cells that are already wet, border a wet cell, or seed a pond;
## everywhere else the recipe height is read and discarded.
## Throw away everything the incremental refresh remembers, so the next build
## starts from the records alone.
func discard_cache() -> void:
	_clear_pond_cache()
	_mesh_result = null
	_shore_ready = false
	_strands_ready = false

func water_reaches(region: Rect2) -> bool:
	if not _shore_ready:
		return true
	var first := (region.position+Vector2(14,14))/NativeRecipeWater.CELL
	var last := (region.end+Vector2(14,14))/NativeRecipeWater.CELL
	for j in range(maxi(0,ceili(first.y)),mini(NativeRecipeWater.W-1,floori(last.y))+1):
		for i in range(maxi(0,ceili(first.x)),mini(NativeRecipeWater.W-1,floori(last.x))+1):
			if _shore_mask[j*NativeRecipeWater.W+i] == 1:
				return true
	return false

## Record which terrain vertices a calculation reads through `sample`. A result
## derived only from those heights stays valid while they stay put, however far
## the calculation wandered, because identical inputs retrace identical paths.
func begin_probe() -> void:
	_probing = true
	_probe = {}

func end_probe() -> Dictionary:
	_probing = false
	var ids := PackedInt32Array()
	var values := PackedFloat32Array()
	for id: int in _probe:
		ids.append(id)
		values.append(heights[id])
	_probe = {}
	return {"ids":ids,"values":values,"sculpted":heights != _recipe_heights}

func probe_stale(record: Dictionary) -> bool:
	if record.is_empty() or record.sculpted != (heights != _recipe_heights):
		return true
	var ids: PackedInt32Array = record.ids
	var values: PackedFloat32Array = record.values
	for k in range(ids.size()):
		if heights[ids[k]] != values[k]:
			return true
	return false

func _all_faces() -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in range(0,vertex_ids.size(),3):
		result.append(i)
	return result

## Every face whose bounding box shares a terrain bucket with the region.
func _faces_in(region: Rect2) -> PackedInt32Array:
	var seen := {}
	var result := PackedInt32Array()
	for z in range(floori(region.position.y/2), floori(region.end.y/2)+1):
		for x in range(floori(region.position.x/2), floori(region.end.x/2)+1):
			for i: int in _buckets.get(Vector2i(x,z),[]):
				if seen.has(i):
					continue
				seen[i] = true
				result.append(i)
	return result

## Where the terrain differs from the cached build. `false` means nothing
## changed, `null` means the difference cannot be localised.
func _mesh_region() -> Variant:
	var moved := heights != _mesh_heights
	var painted := grass != _mesh_grass or meadow != _mesh_meadow or tint != _mesh_tint
	if not moved and not painted:
		return false
	if moved and heights.size() != _mesh_heights.size():
		return null
	if painted and (grass.size() != _mesh_grass.size() or meadow.size() != _mesh_meadow.size() or tint.size() != _mesh_tint.size()):
		return null
	var region := Rect2()
	var started := false
	if moved:
		var vertical: Variant = moved_region(_mesh_heights)
		if not vertical is Rect2:
			return null
		region = vertical
		started = true
	if painted:
		for k in range(grass.size()):
			var recolored := false
			for c in range(NativeTerrainTint.STRIDE):
				recolored = recolored or tint[k*NativeTerrainTint.STRIDE+c] != _mesh_tint[k*NativeTerrainTint.STRIDE+c]
			if grass[k] == _mesh_grass[k] and meadow[k] == _mesh_meadow[k] and not recolored:
				continue
			var corner := meadow_position(k%MEADOW_CELLS,k/MEADOW_CELLS)
			region = region.expand(corner) if started else Rect2(corner,Vector2.ZERO)
			started = true
			region = region.expand(corner+Vector2.ONE*MEADOW_STEP)
	if not started:
		return null
	return region.grow(_face_margin)

## Reuse the shoreline field unless the edit could reach the water. Heights only
## matter to the flood where a cell is already wet, borders a wet cell, or seeds
## a pond, so an edit clear of those cells leaves the field untouched.
func _shoreline_field(region: Variant) -> Dictionary:
	_shore_changed = false
	if _shore_ready and region != null and not water_reaches(region):
		return _shore_field
	var field := preload("res://scripts/native_recipe_water.gd").shoreline(self)
	var changed := not _shore_ready or field.is_empty() != _shore_field.is_empty()
	if not changed and not field.is_empty():
		changed = field.shore != _shore_field.shore or field.depth != _shore_field.depth or field.kind != _shore_field.kind
	_shore_field = field
	_shore_mask = _shoreline_mask(field)
	_shore_ready = true
	_shore_changed = changed
	return field

## Wet cells, their neighbours - which can flood or drain next - and every
## pond's seed window, where the lowest of nine cells starts the flood.
func _shoreline_mask(field: Dictionary) -> PackedByteArray:
	var side: int = NativeRecipeWater.W
	var mask := PackedByteArray()
	mask.resize(side*side)
	if not field.is_empty():
		var shore: PackedFloat32Array = field.shore
		for k in range(shore.size()):
			if shore[k] >= 0.0:
				continue
			for j in range(maxi(0,k/side-1),mini(side-1,k/side+1)+1):
				for i in range(maxi(0,k%side-1),mini(side-1,k%side+1)+1):
					mask[j*side+i] = 1
	for pond in ponds:
		var seed_x := int(floor((float(pond.x)+14.0)/NativeRecipeWater.CELL+0.5))
		var seed_z := int(floor((float(pond.z)+14.0)/NativeRecipeWater.CELL+0.5))
		for j in range(maxi(0,seed_z-1),mini(side-1,seed_z+1)+1):
			for i in range(maxi(0,seed_x-1),mini(side-1,seed_x+1)+1):
				mask[j*side+i] = 1
	return mask

## Recipes are pure functions of their settings, so restoring the same recipe -
## which is what every sculpt undo/redo does - can keep the sampled height and
## gradient tables instead of re-evaluating the source noise ~19,000 times.
func _set_recipe(settings: Dictionary, frame_tree: SceneTree = null) -> void:
	if var_to_bytes(_recipe_settings) == var_to_bytes(settings) and (_recipe == null) == settings.is_empty():
		return
	# Prepare locally: live ground queries keep seeing the complete old recipe
	# until both sample tables are ready to publish together.
	var recipe = null if settings.is_empty() else preload("res://scripts/native_terrain_recipe.gd").new(settings)
	var sampled_heights := PackedFloat32Array()
	var sampled_gradients: Array[Vector2] = []
	var sampled_water := PackedFloat64Array()
	var budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree)
	if recipe != null:
		for i in range(points.size()):
			var point := points[i]
			sampled_heights.append(0.6 if maxf(absf(point.x),absf(point.y)) > 13.9999 else recipe.height(point.x,point.y))
			if frame_tree != null and i%16 == 0: await budget.checkpoint()
		for i in range(_face_x.size()):
			var x: float = _face_x[i]
			var z: float = _face_z[i]
			sampled_gradients.append(Vector2((recipe.height(x+0.25,z)-recipe.height(x-0.25,z))/0.5,(recipe.height(x,z+0.25)-recipe.height(x,z-0.25))/0.5))
			if frame_tree != null and i%8 == 0: await budget.checkpoint()
		# Pond shading would otherwise lazily sample this entire grid during the
		# mesh rebuild. Prepare its exact double-precision values in slices too.
		if frame_tree != null and not ponds.is_empty():
			for z in range(NativeRecipeWater.W):
				for x in range(NativeRecipeWater.W):
					sampled_water.append(recipe.height(-14.0+x*NativeRecipeWater.CELL,-14.0+z*NativeRecipeWater.CELL))
					if x%8 == 0: await budget.checkpoint()
	_recipe_settings = settings.duplicate(true)
	_recipe = recipe
	_recipe_heights = sampled_heights
	_recipe_gradients = sampled_gradients
	_water_grid_h = sampled_water
	_recipe_height_cache.clear()
	_recipe_height_count = 0
	_strands_ready = false

## Each face reads the sculpt delta at four fixed offsets from its centroid, so
## the triangle those offsets land in is resolved once and then evaluated with
## the same expression `_sculpt_delta` uses.
func _ensure_face_probes() -> void:
	if _face_probe.size() == _face_center.size()*4:
		return
	_face_probe.clear()
	for face in range(_face_center.size()):
		for offset: Vector2 in [Vector2(0.25,0),Vector2(-0.25,0),Vector2(0,0.25),Vector2(0,-0.25)]:
			var point := (_face_center[face]+offset).clamp(Vector2(-14,-14),Vector2(14,14))
			var slot: int = _locate_cache.get(point,-1)
			if slot < 0:
				slot = _locate_face.size()
				_locate_cache[point] = slot
				_locate(point)
			_face_probe.append(slot)

func _probe_delta(slot: int) -> float:
	var i: int = _locate_face[slot]
	if i < 0:
		return 0.0 # `_sculpt_delta` subtracts two nulls here, which is also zero.
	var u: float = _locate_u[slot]
	var v: float = _locate_v[slot]
	var a := vertex_ids[i]
	var b := vertex_ids[i+1]
	var c := vertex_ids[i+2]
	return (u*heights[a]+v*heights[b]+(1.0-u-v)*heights[c])-(u*_recipe_heights[a]+v*_recipe_heights[b]+(1.0-u-v)*_recipe_heights[c])

func _sculpt_delta(point: Vector2) -> float:
	point = point.clamp(Vector2(-14,-14),Vector2(14,14))
	return float(sample(point,heights))-float(sample(point,_recipe_heights))

func form_range(height_scale := 1.0, width_scale := 1.0, heading := 0.0, variation := 0, frame_tree: SceneTree = null) -> void:
	await _set_recipe({"kind":"range","height":height_scale,"width":width_scale,"heading":heading,"variation":variation},frame_tree)
	heights = _recipe_heights.duplicate()

func form_foundation(elevation := 0.0, relief := 1.0, frame_tree: SceneTree = null) -> void:
	await _set_recipe({"kind":"foundation","elevation":elevation,"relief":relief},frame_tree)
	landscape_waterfall=false
	heights = _recipe_heights.duplicate()

func reset_flat() -> void:
	_set_recipe({})
	blank = true
	heights.fill(0.0)
	blades.fill(0.0)
	grass.fill(0.0)
	meadow.fill(0.0)
	tint.fill(0.0)
	objects.clear()
	objects_revision += 1
	ponds.clear()
	streams.clear()
	landscape_waterfall=false
	next_id = 1

func _snapshot() -> Dictionary:
	return {"landscape_waterfall":landscape_waterfall,"terrain_recipe":_recipe_settings.duplicate(true), "heights": heights.duplicate(), "blank": blank, "meadow":meadow.duplicate(), "grass":grass.duplicate(), "blades":blades.duplicate(), "tint":tint.duplicate(), "objects":objects.duplicate(true), "ponds":ponds.duplicate(true), "streams":streams.duplicate(true), "next_id":next_id}

func _restore(state: Dictionary) -> void:
	_set_recipe(state.get("terrain_recipe",{}))
	landscape_waterfall=state.get("landscape_waterfall",false)
	heights = state.heights.duplicate()
	blank = state.blank
	meadow = state.meadow.duplicate()
	grass = state.grass.duplicate()
	blades = state.blades.duplicate()
	tint = state.get("tint",NativeTerrainTint.make(MEADOW_CELLS*MEADOW_CELLS)).duplicate()
	# Undoing a sculpt stroke restores the very same object records. Spotting that
	# once here is far cheaper than making the view rebuild all of them.
	if objects.size() != state.objects.size() or var_to_bytes(objects) != var_to_bytes(state.objects):
		objects_revision += 1
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

## Paint linear-RGB colour over rock and grass alike. `amount` is the coat this
## dab lays down; repeated dabs deepen it toward a full-weight tint.
func paint_tint(center: Vector2, radius: float, color: Color, amount: float) -> void:
	NativeTerrainTint.paint(tint,MEADOW_CELLS,MEADOW_STEP,center,radius,color,amount)

func erase_tint(center: Vector2, radius: float, amount: float) -> void:
	NativeTerrainTint.erase(tint,MEADOW_CELLS,MEADOW_STEP,center,radius,amount)

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
	objects_revision += 1
	return id

## Object edits share the caller's stroke so a drag is one undoable operation.
## Return copies to keep renderer revisions and undo history behind this API.
func object_by_id(id: int) -> Dictionary:
	var index := _object_index(id)
	return objects[index].duplicate(true) if index >= 0 else {}

func _object_index(id: int) -> int:
	for index in range(objects.size()):
		if objects[index].id == id:
			return index
	return -1

## Patch editable properties atomically. Empty/null pose or tint restores the
## asset default. Waterfalls need their dedicated two-endpoint editing tool.
func update_object(id: int, changes: Dictionary) -> bool:
	var index := _object_index(id)
	if index < 0 or objects[index].asset == "waterfall":
		return false
	var candidate := objects[index].duplicate(true)
	for key in changes:
		if key not in ["x","z","angle","scale","pose","tint"]:
			return false
		var value: Variant = changes[key]
		if key == "pose" and (value == null or (value is Dictionary and value.is_empty())):
			candidate.erase(key)
		elif key == "tint" and (value == null or value == ""):
			candidate.erase(key)
		else:
			candidate[key] = value
	if not GardenData._number(candidate.x,-14,14) or not GardenData._number(candidate.z,-14,14):
		return false
	if ground_height(Vector2(candidate.x,candidate.z)) == null:
		return false
	if not GardenData._number(candidate.angle,-TAU*100,TAU*100) or not GardenData._number(candidate.scale,0.1,5.0):
		return false
	if candidate.has("pose") and (candidate.asset in ["arch","bigfoot_tree"] or not NativeObjectPose.valid(candidate.pose)):
		return false
	if candidate.has("tint") and (candidate.asset in ["arch","bigfoot_tree"] or not NativeObjectPose.valid_tint(candidate.tint)):
		return false
	if candidate == objects[index]:
		return false
	# Once customized, a generated piece belongs to the user. Refilling the
	# landscape must only replace untouched generated flora.
	candidate.erase("landscape")
	objects[index] = candidate.duplicate(true)
	objects_revision += 1
	return true

func duplicate_object(id: int) -> int:
	var index := _object_index(id)
	if index < 0 or objects.size() >= GardenData.MAX_OBJECTS or next_id >= 2147483647:
		return -1
	var copy := objects[index].duplicate(true)
	copy.id = next_id
	copy.erase("landscape")
	next_id += 1
	objects.append(copy)
	objects_revision += 1
	return copy.id

func remove_object(id: int) -> bool:
	var index := _object_index(id)
	if index < 0:
		return false
	objects.remove_at(index)
	objects_revision += 1
	return true

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
	objects_revision += 1
	next_id += 1
	return true

func object_position(item: Dictionary) -> Vector3:
	return Vector3(item.x,height_at(item.x,item.z)+(preload("res://scripts/native_object_pose.gd").decode_offset(item.pose) if item.has("pose") else 0.0),item.z)

func erase_objects(point: Vector2, radius: float) -> void:
	objects = objects.filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(point) > radius)
	objects_revision += 1

func pond_surface(pond: Dictionary) -> PackedVector3Array:
	# Probe callers need the terrain reads as well as the result. Let the native
	# flood record those dependencies rather than hiding reads behind a hit.
	if _probing:
		return NativeGardenWater.surface(self,pond)
	var state := var_to_bytes([_recipe_settings, _recipe != null, streams, ponds, landscape_waterfall])
	if heights != _pond_cache_heights or state != _pond_cache_state:
		_pond_surfaces.clear()
		_pond_cache_heights = heights.duplicate()
		_pond_cache_state = state
	var key := var_to_bytes(pond).hex_encode()
	if _pond_surfaces.has(key):
		pond_cache_hits += 1
		return (_pond_surfaces[key] as PackedVector3Array).duplicate()
	pond_cache_misses += 1
	var surface := NativeGardenWater.surface(self,pond)
	if _pond_surfaces.size() >= POND_CACHE_LIMIT:
		_pond_surfaces.erase(_pond_surfaces.keys()[0])
	_pond_surfaces[key] = surface.duplicate()
	return surface

func _clear_pond_cache() -> void:
	_pond_surfaces.clear()
	_pond_cache_heights = PackedFloat32Array()
	_pond_cache_state = PackedByteArray()

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
	return {"version":9,"tint":Array(tint),"landscape_waterfall":landscape_waterfall,"terrain_recipe":preload("res://scripts/native_terrain_recipe.gd").encode(_recipe_settings),"template":_template_id(),"heights":Array(heights),"blank":blank,"meadow":Array(meadow),"grass":Array(grass),"blades":Array(blades),"objects":objects.duplicate(true),"ponds":ponds.duplicate(true),"streams":streams.map(func(value): return preload("res://scripts/native_stream_record.gd").encode(value)),"next_id":next_id}

func _template_id() -> String:
	return var_to_bytes([points,vertex_ids,original_heights]).hex_encode().sha256_text()

func load_document(document: Variant) -> bool:
	if not document is Dictionary or (document.get("version") != 3 and document.get("version") != 4 and document.get("version") != 5 and document.get("version") != 6 and document.get("version") != 7 and document.get("version") != 8 and document.get("version") != 9) or document.get("template") != _template_id() or not document.get("blank") is bool:
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
	# Gardens saved before the Paint tool simply have nothing painted.
	var painted: Variant = NativeTerrainTint.make(meadow.size()) if document.version < 9 else NativeTerrainTint.decode(document.get("tint"),meadow.size())
	if painted == null:
		return false
	loaded.tint = painted
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
				if item.has("basin"):
					if not item.basin is Array or item.basin.size()!=2: return false
					for radius in item.basin:
						if not GardenData._number(radius,0.1,14.0): return false
					record.basin = item.basin.duplicate()
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
	return _recipe_height(x,z)+(_sculpt_delta(p) if heights!=_recipe_heights else 0.0)

## Stream banks and the waterfall's trace sample the recipe thousands of times,
## often at coordinates they have already asked for. The doubles are kept as
## dictionary keys so a hit returns the identical value the noise produced.
func _recipe_height(x: float,z: float) -> float:
	var row: Variant = _recipe_height_cache.get(x)
	if row == null:
		row = {}
		_recipe_height_cache[x] = row
	var height: Variant = row.get(z)
	if height == null:
		height = _recipe.height(x,z)
		row[z] = height
		_recipe_height_count += 1
		if _recipe_height_count >= 262144:
			_recipe_height_cache.clear()
			_recipe_height_count = 0
	return height

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

## Tracing the landscape fall is expensive and every rebuild asks for it at least
## twice - once to render it and once per pond for its impact foam. The trace
## reads the terrain only through `sample`, so recording which heights it read
## says exactly when the cached strands stop being the ones it would produce.
func waterfall_strands() -> Array[Dictionary]:
	if not landscape_waterfall or _recipe==null: return []
	if _strands_ready and not probe_stale(_strands_probe):
		if _probing: _probe.merge(_strands_seen)
		return _strands_cache
	var outer := _probe
	var outer_probing := _probing
	_probe = {}
	_probing = true
	_strands_cache = preload("res://scripts/native_fall_strand.gd").landscape(waterfall_ground_height,_recipe.source.pool,_recipe.source.g)
	_strands_seen = _probe
	_strands_probe = end_probe()
	if outer_probing: outer.merge(_strands_seen)
	_probe = outer
	_probing = outer_probing
	_strands_ready = true
	return _strands_cache

func waterfall_probe() -> Dictionary:
	return _strands_probe if _strands_ready else {}

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
	objects_revision += 1
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
			objects_revision += 1
			next_id=before_id
			return false
		objects.back()["landscape"]=true
		objects_revision += 1
	return not placements.is_empty()
