extends SceneTree
## Headless probe of the sky islets (scripts/sky_islet.gd, sky_islets.gd):
## what a sample of cells grows (kinds, sizes, species, flowers) and what it
## costs: the shape, the arrays and the flora a worker makes per islet, and
## the frames while they stream in round a gliding eye.
##   godot --headless --path . --script tools/probe_islets.gd
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")

func _initialize() -> void:
	var began := Time.get_ticks_usec()
	var catalog: Dictionary = SkyIslets.catalog().data
	print("catalog (offline garden view): %.0f ms" % ((Time.get_ticks_usec()-began)/1000.0))
	var kinds := {}
	var species := {}
	var flowers := {}
	var with_flowers := 0
	var times := {"shape":[],"top":[],"sides":[],"water":[],"flora":[]}
	var tris := []
	var batches := []
	var sizes := []
	var count := 0
	for x in range(-12,12):
		for z in range(-6,6):
			var cell := Vector2i(x,z)
			if SkyIslets.raw(cell) == null: continue
			count += 1
			var t := Time.get_ticks_usec()
			var islet: RefCounted = SkyIslet.make(SkyIslets.seed_of(cell))
			times.shape.append(Time.get_ticks_usec()-t)
			t = Time.get_ticks_usec()
			var top: Array = islet.top_arrays(SkyIslet.plain_palette(),SkyIslets.OFF_MAP)
			times.top.append(Time.get_ticks_usec()-t)
			t = Time.get_ticks_usec()
			var sides: Array = islet.side_arrays()
			times.sides.append(Time.get_ticks_usec()-t)
			t = Time.get_ticks_usec()
			islet.water_arrays()
			times.water.append(Time.get_ticks_usec()-t)
			t = Time.get_ticks_usec()
			var flora: Dictionary = islet.flora(catalog)
			times.flora.append(Time.get_ticks_usec()-t)
			tris.append(((top[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()+(sides[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())/3)
			batches.append(flora.size())
			var box: Rect2 = islet.extent()
			sizes.append(maxf(box.size.x,box.size.y))
			kinds[islet.kind] = int(kinds.get(islet.kind,0))+1
			for s in islet.species: species[s] = int(species.get(s,0))+1
			for f in islet.flowers: flowers[f] = int(flowers.get(f,0))+1
			if not islet.flowers.is_empty(): with_flowers += 1
	print("islets: %d" % count)
	print("kinds: %s" % str(kinds))
	print("tree species (islets with): %s" % str(species))
	print("flowers (islets with): %s; islets with flowers %d of %d" % [str(flowers),with_flowers,count])
	sizes.sort()
	print("across (m): min %.1f median %.1f max %.1f" % [sizes[0],sizes[sizes.size()/2],sizes[-1]])
	for key in times:
		var list: Array = times[key]
		list.sort()
		var total := 0
		for v in list: total += v
		print("%-6s mean %.1f ms, median %.1f, max %.1f" % [key,total/1000.0/list.size(),list[list.size()/2]/1000.0,list[-1]/1000.0])
	tris.sort()
	batches.sort()
	print("triangles (top+sides) median %d max %d; flora batches median %d max %d" % [tris[tris.size()/2],tris[-1],batches[batches.size()/2],batches[-1]])
	_stream()
	quit()

## Frames while islets stream in round an eye gliding along, all built.
func _stream() -> void:
	var cells := SkyCells.new([Vector3.ZERO,Vector3(380.0,-20.0,-160.0)])
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var eye := Vector3(150.0,0.0,150.0)
	var worst := 0
	var total := 0
	var frames := 0
	var stood := []
	var began := Time.get_ticks_msec()
	# Take-off: everything in view comes up while the eye glides 25 m/s.
	while Time.get_ticks_msec()-began < 20000:
		var t := Time.get_ticks_usec()
		var before: int = islets.islet_count()
		islets.advance(1.0/60.0,eye)
		var spent := Time.get_ticks_usec()-t
		if islets.islet_count() > before: stood.append(spent)
		if spent > 4000:
			var kinds := []
			for key in islets.built: kinds.append(islets.built[key].shape.kind)
			print("slow frame %.2f ms: survey %s, stood %s (%s)" % [spent/1000.0,str(islets._since == 0.0),str(islets.islet_count() > before),str(kinds)])
		worst = maxi(worst,spent)
		total += spent
		frames += 1
		eye += Vector3(25.0/60.0,0.0,0.0)
		if islets._making.is_empty() and islets._wanted.is_empty() and frames > 60: break
		OS.delay_usec(16000)
	print("streaming: %d islets up in %.1f s; advance() mean %.2f ms, worst %.2f ms over %d frames" % [islets.islet_count(),(Time.get_ticks_msec()-began)/1000.0,total/1000.0/frames,worst/1000.0,frames])
	print("first stand-ups (ms): %s" % str(stood.slice(0,6).map(func(v: int) -> String: return "%.2f" % (v/1000.0))))
	stood.sort()
	print("frames standing an islet up: %d, median %.2f ms, worst %.2f ms" % [stood.size(),stood[stood.size()/2]/1000.0,stood[-1]/1000.0])
	var made := []
	for key in islets.built: made.append(int(islets.built[key].usec))
	made.sort()
	print("worker time per islet: median %.1f ms, worst %.1f ms" % [made[made.size()/2]/1000.0,made[-1]/1000.0])
	var nodes := 0
	var instances := 0
	for key in islets.built:
		for child in (islets.built[key].node as Node3D).get_children():
			nodes += 1
			if child is MultiMeshInstance3D: instances += (child as MultiMeshInstance3D).multimesh.instance_count
	print("built: %d drawn nodes, %d plant instances over %d islets" % [nodes,instances,islets.islet_count()])
	islets.free()
