extends SceneTree
## The lake landform (scripts/landform_lake.gd), measured: for each size a
## few seeds' build time (the shape, its top, sides and water arrays) and
## their triangle counts. Headless:
##   godot --headless --path . --script tools/bench_landform_lake.gd
const SkyIslet = preload("res://scripts/sky_islet.gd")
const Landform = preload("res://scripts/landform_lake.gd")
const SIZES := [30.0,45.0,60.0,75.0,90.0]
const SEEDS := 3

func _initialize() -> void:
	for across: float in SIZES:
		var times := Vector4.ZERO
		var tris := Vector3i.ZERO
		var share := 0.0
		var objects := 0
		for s in range(SEEDS):
			var rng := RandomNumberGenerator.new()
			rng.seed = 900+s*31
			var spec := Landform.recipe(rng,across)
			var t0 := Time.get_ticks_usec()
			var islet: RefCounted = SkyIslet.author(4100+s*77,spec)
			var t1 := Time.get_ticks_usec()
			var top: Array = islet.top_arrays(SkyIslet.plain_palette())
			var t2 := Time.get_ticks_usec()
			var sides: Array = islet.side_arrays()
			var t3 := Time.get_ticks_usec()
			var water: Array = islet.water_arrays()
			var t4 := Time.get_ticks_usec()
			times += Vector4(t1-t0,t2-t1,t3-t2,t4-t3)/1000.0
			tris += Vector3i(_tris(top),_tris(sides),_tris(water))
			share += float(islet.lake.get("area",0.0))/islet.land_area()
			objects += islet.objects.size()
			if "--detail" in OS.get_cmdline_user_args():
				var counts := {}
				for item: Dictionary in islet.objects: counts[item.asset] = int(counts.get(item.asset,0))+1
				print("  %s tea %.2f: %s" % [spec.flavour,float(islet.lake.get("tea",0.0)),counts])
		times /= SEEDS
		print("LAKE %2d m: shape %4.0f ms, top %3.0f, sides %3.0f, water %3.0f | tris top %6d sides %5d water %6d | objects %4d | lake share %.2f" % [
			across,times.x,times.y,times.z,times.w,tris.x/SEEDS,tris.y/SEEDS,tris.z/SEEDS,objects/SEEDS,share/SEEDS])
	quit()

static func _tris(arrays: Array) -> int:
	if arrays.is_empty(): return 0
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
