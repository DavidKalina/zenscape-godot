extends RefCounted
const Plate = preload("res://scripts/plate.gd")
const Geology = preload("res://scripts/native_geology_samples.gd")
## Worker-owned recipe and tables. No live terrain, nodes, meshes or textures.
static func build(settings: Dictionary, points: PackedVector2Array, face_x: PackedFloat64Array, face_z: PackedFloat64Array, prepare_water: bool, water_begin := 0, water_end := NativeRecipeWater.W, geology_begin := 0, geology_end := Geology.SIZE) -> Dictionary:
	var recipe = null if settings.is_empty() else preload("res://scripts/native_terrain_recipe.gd").new(settings)
	var heights := PackedFloat32Array()
	var gradients: Array[Vector2] = []
	var water := PackedFloat64Array()
	var geology: Image
	var geology_usec := 0
	if recipe != null:
		for point in points:
			heights.append(0.6 if maxf(absf(point.x),absf(point.y)) > Plate.RIM else recipe.height(point.x,point.y))
		for i in range(face_x.size()):
			var x: float = face_x[i]
			var z: float = face_z[i]
			gradients.append(Vector2((recipe.height(x+0.25,z)-recipe.height(x-0.25,z))/0.5,(recipe.height(x,z+0.25)-recipe.height(x,z-0.25))/0.5))
		if prepare_water:
			for z in range(water_begin,water_end):
				for x in range(NativeRecipeWater.W):
					water.append(recipe.height(-Plate.HALF+x*NativeRecipeWater.CELL,-Plate.HALF+z*NativeRecipeWater.CELL))
		if recipe.inland != null and recipe.inland.genome.composition in preload("res://scripts/desert_landscape.gd").KINDS:
			var began := Time.get_ticks_usec()
			geology = preload("res://scripts/native_geology_samples.gd").build(recipe.inland.genome,geology_begin,geology_end)
			geology_usec = Time.get_ticks_usec()-began
	return {"recipe":recipe,"heights":heights,"gradients":gradients,"water":water,"geology":geology,"geology_begin":geology_begin,"geology_usec":geology_usec,"geology_worker":WorkerThreadPool.get_caller_task_id()>=0 or WorkerThreadPool.get_caller_group_id()>=0}

## Contiguous partitions preserve the sequential output ordering and arithmetic.
## Each partition constructs a private recipe (including noise/cache state).
static func build_parallel(settings: Dictionary, points: PackedVector2Array, face_x: PackedFloat64Array, face_z: PackedFloat64Array, prepare_water: bool, tree: SceneTree, workers: int) -> Dictionary:
	var count := clampi(workers,1,mini(8,maxi(1,OS.get_processor_count()-2)))
	var actions: Array[Callable] = []
	for i in range(count):
		actions.append(build.bind(settings.duplicate(true),points.slice(points.size()*i/count,points.size()*(i+1)/count),face_x.slice(face_x.size()*i/count,face_x.size()*(i+1)/count),face_z.slice(face_z.size()*i/count,face_z.size()*(i+1)/count),prepare_water,NativeRecipeWater.W*i/count,NativeRecipeWater.W*(i+1)/count,Geology.SIZE*i/count,Geology.SIZE*(i+1)/count))
	var job = preload("res://scripts/background_work.gd").new()
	var pieces: Array = await job.run_group(actions,tree,count)
	var result: Dictionary = pieces[0]
	var geology: Image
	if result.geology != null:
		geology = Image.create(Geology.SIZE,Geology.SIZE,false,Image.FORMAT_RGBA8)
		for piece: Dictionary in pieces:
			geology.blit_rect(piece.geology,Rect2i(0,0,Geology.SIZE,piece.geology.get_height()),Vector2i(0,piece.geology_begin))
	for i in range(1,pieces.size()):
		result.heights.append_array(pieces[i].heights)
		result.gradients.append_array(pieces[i].gradients)
		result.water.append_array(pieces[i].water)
		result.geology_usec += pieces[i].geology_usec
		result.geology_worker = result.geology_worker and pieces[i].geology_worker
	result.geology = geology
	return result
