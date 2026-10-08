extends SceneTree
## What a lower-world island costs (scripts/sky_archipelago.gd): for each
## placeholder landform at a few widths, on the plate's grid step and on the
## archipelago's coarser one, the time to shape and dress it (as a worker
## does: SkyIslet `author` and SkyIslets `dress`), its grid's points, its
## top's and sides' triangles, and its plants' instances.
##   godot --headless --path . --script tools/probe_lower_islands.gd [-- --widths=25,55,90]
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyArchipelago = preload("res://scripts/sky_archipelago.gd")
const Landforms = preload("res://scripts/landforms.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var widths := [25.0,55.0,90.0]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--widths="): widths = Array(a.trim_prefix("--widths=").split(",")).map(func(w: String) -> float: return float(w))
	var islets := SkyIslets.new()
	root.add_child(islets)
	var palette: Dictionary = islets.prepare_authored()
	Landforms.prepare()
	print("PROBE landform width step points top_tris side_tris instances shape_ms dress_ms")
	for landform: String in Landforms.names():
		for width: float in widths:
			for coarse in [false,true]:
				var rng := RandomNumberGenerator.new()
				rng.seed = 1234
				var spec := Landforms.recipe(landform,rng,width)
				SkyArchipelago.dress_spec(spec,width,SkyIslet.RIM_HEIGHT-2.0,1234)
				if not coarse: spec.step = SkyIslet.STEP
				var began := Time.get_ticks_usec()
				var shape: RefCounted = SkyIslet.author(1234,spec)
				var shaped := Time.get_ticks_usec()
				var out: Dictionary = SkyIslets.dress(shape,palette,0.0)
				var dressed := Time.get_ticks_usec()
				var instances := 0
				for key in out.plants: instances += int(out.plants[key].count)
				print("PROBE %-8s %5.0f %5.2f %6d %7d %7d %6d %8.1f %8.1f" % [landform,width,shape.step,shape.points.size(),
					(out.top[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3,(out.sides[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3,
					instances,(shaped-began)/1000.0,(dressed-shaped)/1000.0])
	islets.queue_free()
	await process_frame
	quit(0)
