extends RefCounted
const Plate = preload("res://scripts/plate.gd")
## Private CPU images and terrain providers. Only the caller publishes textures.
static func build(data: NativeTerrainData, original: bool, blank: bool, source_ground: Image, source_stream: Image, base: Image, image: Image, streams: Image, water: PackedVector3Array, samples: Dictionary, clip: Rect2i) -> Dictionary:
	var began := Time.get_ticks_usec()
	var size := source_ground.get_width()
	for z in range(clip.position.y,clip.end.y):
		for x in range(clip.position.x,clip.end.x):
			if not original or blank:
				var point := (Vector2(x,z)+Vector2.ONE*0.5)/float(size)*(Plate.MAP_HALF*2.0)-Vector2.ONE*Plate.MAP_HALF
				var height: Variant = data.height_at(point.x,point.y)
				var value := Color(-1000,-1000,-1000,-1000) if blank else source_ground.get_pixel(x,z)
				value.g = float(height) if height != null else -1000.0
				value.r = maxf(value.g,value.a)
				base.set_pixel(x,z,value)
			image.set_pixel(x,z,base.get_pixel(x,z))
			streams.set_pixel(x,z,Color(0,0,0,0) if blank else source_stream.get_pixel(x,z))
	GardenSurfaceMap.paint_water(image,water,clip)
	GardenSurfaceMap.paint_stream_samples(image,streams,samples,clip)
	return {"base":base,"ground":image,"stream":streams,"clip":clip,"usec":Time.get_ticks_usec()-began,"worker":WorkerThreadPool.get_caller_group_id() >= 0}

static func build_parallel(data: NativeTerrainData, original: bool, source_ground: Image, source_stream: Image, base: Image, image: Image, streams: Image, water: PackedVector3Array, samples: Dictionary, clip: Rect2i, tree: SceneTree, workers: int) -> Dictionary:
	var began := Time.get_ticks_usec()
	var count := mini(clip.size.y,clampi(workers,1,mini(8,maxi(1,OS.get_processor_count()-2))))
	var actions: Array[Callable] = []
	for i in range(count):
		var first := clip.position.y+clip.size.y*i/count
		var last := clip.position.y+clip.size.y*(i+1)/count
		var stripe := Rect2i(clip.position.x,first,clip.size.x,last-first)
		var private_samples := {"surfaces":[],"span":samples.span}
		var surfaces: Array[RefCounted] = []
		for sampler in samples.surfaces: surfaces.append(sampler.query_snapshot())
		private_samples.surfaces = surfaces
		actions.append(build.bind(preload("res://scripts/native_terrain_snapshot.gd").for_height(data),original,data.blank,source_ground.duplicate(),source_stream.duplicate(),base.duplicate(),image.duplicate(),streams.duplicate(),water.duplicate(),private_samples,stripe))
	var submit_usec := Time.get_ticks_usec()-began
	var job = preload("res://scripts/background_work.gd").new()
	var parts: Array = await job.run_group(actions,tree,count)
	# Blit disjoint row stripes; no worker output is visible before the join.
	var merged := {"base":base.duplicate(),"ground":image.duplicate(),"stream":streams.duplicate(),"worker":true,"workers":count,"submit_usec":submit_usec,"worker_usec":0}
	for part: Dictionary in parts:
		for key in ["base","ground","stream"]:
			merged[key].blit_rect(part[key],part.clip,part.clip.position)
		merged.worker = merged.worker and part.worker
		merged.worker_usec += int(part.usec)
	return merged
