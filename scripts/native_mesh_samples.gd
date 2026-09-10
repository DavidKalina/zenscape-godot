extends RefCounted
## Mesh arithmetic on detached data. Mesh resources publish only on the caller.

static func snapshot(source: NativeTerrainData) -> NativeTerrainData:
	var data := preload("res://scripts/native_terrain_snapshot.gd").for_height(source)
	# Packed buffers retain their element precision. No render resource, live
	# recipe, noise generator or mutable lookup dictionary crosses this seam.
	for key in ["grass","meadow","tint","_face_grass","_face_rock","_face_snow","_face_rim","_face_shimmer","_face_x","_face_z","_face_center","_face_probe","_locate_face","_locate_u","_locate_v","_recipe_heights","_water_grid_h","_shore_mask"]:
		data.set(key,source.get(key).duplicate())
	data._arrays = source._arrays.duplicate(true)
	data._recipe_gradients.assign(source._recipe_gradients.duplicate())
	data._recipe_settings = source._recipe_settings.duplicate(true)
	data.ponds.assign(source.ponds.duplicate(true))
	data.streams.assign(source.streams.duplicate(true))
	data.blank = source.blank
	data._ground_tint = source._ground_tint
	data._shore_ready = source._shore_ready
	data._shore_field = source._shore_field.duplicate(true)
	for key in ["sand","gravel","snowline","rock_slope"]:
		data._palette.set(key,source._palette.get(key))
	return data

## Flood/distance passes are ordered; preserve their single-worker arithmetic.
## Once this task joins, shading treats the prepared provider as immutable.
static func prepare(data: NativeTerrainData, region: Variant, sculpted: bool) -> Dictionary:
	var began := Time.get_ticks_usec()
	data._recipe = null if data._recipe_settings.is_empty() else NativeTerrainRecipe.new(data._recipe_settings)
	if sculpted: data._ensure_face_probes()
	var water := data._shoreline_field(region) if data.blank else {}
	return {"data":data,"water":water,"usec":Time.get_ticks_usec()-began,"worker":WorkerThreadPool.get_caller_task_id() >= 0}

static func build_parallel(data: NativeTerrainData, arrays: Array, faces: PackedInt32Array, water: Dictionary, sculpted: bool, has_recipe: bool, tree: SceneTree, workers: int, native_enabled := true) -> Dictionary:
	var began := Time.get_ticks_usec()
	var count := clampi(workers if workers > 0 else 2,1,mini(8,maxi(1,OS.get_processor_count()-2)))
	var total := data.vertex_ids.size()/3
	var actions: Array[Callable] = []
	var kernel := preload("res://scripts/native_terrain_kernels.gd").get_kernel() if native_enabled else null
	# The measured native pass is below the cooperative publication budget.
	# Avoid a worker round trip and extra frame for this now-small operation.
	# Explicit counts still exercise exactly the requested partition strategy.
	if kernel != null and workers == 0 and total <= 8192:
		var part := shade(data,arrays,faces,water,sculpted,has_recipe,0,total*3,kernel)
		var merged := arrays.duplicate()
		merged[Mesh.ARRAY_VERTEX] = part.vertices
		merged[Mesh.ARRAY_NORMAL] = part.normals
		merged[Mesh.ARRAY_TEX_UV2] = part.uv2
		merged[Mesh.ARRAY_COLOR] = part.colors
		return {"arrays":merged,"workers":0,"usec":part.usec,"worker":false,"snapshot_usec":0,"merge_usec":Time.get_ticks_usec()-began-part.usec}
	for i in range(count):
		var private := snapshot(data)
		actions.append(shade.bind(private,arrays.duplicate(true),faces.duplicate(),water.duplicate(true),sculpted,has_recipe,total*i/count*3,total*(i+1)/count*3,kernel))
	var snapshot_usec := Time.get_ticks_usec()-began
	var job = preload("res://scripts/background_work.gd").new()
	var parts: Array = await job.run_group(actions,tree,count)
	began = Time.get_ticks_usec()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var colors := PackedColorArray()
	var usec := 0
	var worker := true
	for part: Dictionary in parts:
		vertices.append_array(part.vertices)
		normals.append_array(part.normals)
		uv2.append_array(part.uv2)
		colors.append_array(part.colors)
		usec += int(part.usec)
		worker = worker and part.worker
	var merged := arrays.duplicate()
	merged[Mesh.ARRAY_VERTEX] = vertices
	merged[Mesh.ARRAY_NORMAL] = normals
	merged[Mesh.ARRAY_TEX_UV2] = uv2
	merged[Mesh.ARRAY_COLOR] = colors
	return {"arrays":merged,"workers":count,"usec":usec,"worker":worker,"snapshot_usec":snapshot_usec,"merge_usec":Time.get_ticks_usec()-began}

static func shade(data: NativeTerrainData, arrays: Array, faces: PackedInt32Array, water_field: Dictionary, sculpted: bool, has_recipe: bool, first: int, last: int, kernel: RefCounted = null) -> Dictionary:
	var began := Time.get_ticks_usec()
	if kernel != null:
		var result := preload("res://scripts/native_terrain_kernels.gd").shade(kernel,data,arrays,faces,water_field,sculpted,has_recipe,first,last)
		result.usec = Time.get_ticks_usec()-began
		result.worker = WorkerThreadPool.get_caller_group_id() >= 0
		return result
	var heights = data.heights
	var vertex_ids = data.vertex_ids
	var grass = data.grass
	var meadow = data.meadow
	var tint = data.tint
	var blank = data.blank
	var _recipe_gradients = data._recipe_gradients
	var _face_probe = data._face_probe
	var _arrays = data._arrays
	var _face_x = data._face_x
	var _face_z = data._face_z
	var _face_grass = data._face_grass
	var _face_rock = data._face_rock
	var _face_snow = data._face_snow
	var _face_rim = data._face_rim
	var _face_shimmer = data._face_shimmer
	var _ground_tint = data._ground_tint
	var _recipe_settings = data._recipe_settings
	var _palette = data._palette
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
	for i in faces:
		if i < first or i >= last: continue
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
		var cell := data.meadow_cell(point)
		var coverage: float = maxf(grass[cell],meadow[cell]) if blank else grass[cell]
		var face_color := _ground_tint.lerp(_face_grass[face],coverage)
		var snowed := false
		if blank:
			var slope := sqrt(maxf(0.0,1.0-normal.y*normal.y))/maxf(normal.y,0.001)
			if has_recipe:
				var gradient: Vector2 = _recipe_gradients[face]
				if sculpted:
					var probe := face*4
					gradient += Vector2((data._probe_delta(_face_probe[probe])-data._probe_delta(_face_probe[probe+1]))/0.5,(data._probe_delta(_face_probe[probe+2])-data._probe_delta(_face_probe[probe+3]))/0.5)
				slope = gradient.length()
			# The sealed cut is not a geological cliff. Source colorAt samples
			# the continuous ground before its border is lowered to the rim.
			var cut_rim: bool = _face_rim[face] == 1
			if center.y > snowline-1.8 or (slope > rock_slope and (not cut_rim or has_recipe)):
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
	return {"vertices":vertices.slice(first,last),"normals":normals.slice(first,last),"uv2":uv2.slice(first,last),"colors":colors.slice(first,last),"usec":Time.get_ticks_usec()-began,"worker":WorkerThreadPool.get_caller_group_id() >= 0}
