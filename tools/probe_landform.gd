extends SceneTree
## A landform's islands, headless: for a few widths and seeds, how long one
## takes to shape and draw (its arrays, as the islets' worker makes them),
## its faces, its records by asset, its heights, and how much of its
## ground is steeper than the palette's rock slope (and how much of that at
## the coast). --no-glen, --no-tors and --no-erode leave those out of the
## hills, to see what each does.
##   godot --headless --path . --script tools/probe_landform.gd -- [--landform=hills] [--seeds=3]
const SkyIslet = preload("res://scripts/sky_islet.gd")
const LANDFORMS := {"hills":preload("res://scripts/landform_hills.gd")}

func _initialize() -> void:
	var landform := "hills"
	var seeds := 3
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--landform="): landform = a.trim_prefix("--landform=")
		elif a.begins_with("--seeds="): seeds = int(a.trim_prefix("--seeds="))
	var script: GDScript = LANDFORMS[landform]
	var across_range: Vector2 = script.ACROSS
	for across in [across_range.x,lerpf(across_range.x,across_range.y,0.5),across_range.y]:
		for s in range(seeds):
			var seed_value := 4100+s*7919
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var spec: Dictionary = script.recipe(rng,across)
			if "--no-glen" in OS.get_cmdline_user_args(): spec.downs.glen = 0.0
			if "--no-tors" in OS.get_cmdline_user_args(): spec.downs.tors = Vector2i(0,0)
			if "--no-erode" in OS.get_cmdline_user_args(): spec.erode = {"max_cut":0.0}
			var t := Time.get_ticks_usec()
			var shape: RefCounted = SkyIslet.author(seed_value,spec)
			var shaped := Time.get_ticks_usec()-t
			var top: Array = shape.top_arrays(SkyIslet.plain_palette())
			var sides: Array = shape.side_arrays()
			var total := Time.get_ticks_usec()-t
			var low := INF
			var high := -INF
			for i in range(shape.points.size()):
				if shape.shore_distance[i] < 0.0: continue
				low = minf(low,shape.heights[i])
				high = maxf(high,shape.heights[i])
			var steep := 0
			var sloped := 0
			var coast_steep := 0
			for f in shape.land:
				var slope: float = shape._slope(f)
				if slope > 0.93:
					steep += 1
					var e: float = (shape.shore_distance[shape.ids[f*3]]+shape.shore_distance[shape.ids[f*3+1]]+shape.shore_distance[shape.ids[f*3+2]])/3.0
					if e < 3.0: coast_steep += 1
				elif slope > 0.5: sloped += 1
			var assets := {}
			for o: Dictionary in shape.objects: assets[o.asset] = int(assets.get(o.asset,0))+1
			print("%s %.0f m seed %d: step %.2f shape %.0f ms, with arrays %.0f ms; top %d faces, sides %d; heights %.1f to %.1f m; rock-steep %.0f%% (%d of %d at the coast), over 0.5 %.0f%%; %d records %s" % [landform,across,seed_value,shape.step,
				shaped/1000.0,total/1000.0,(top[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3,(sides[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3,low,high,100.0*steep/shape.land.size(),coast_steep,steep,100.0*sloped/shape.land.size(),shape.objects.size(),str(assets)])
	quit()
