extends SceneTree
## Probe: the pierced isle's lid (scripts/pierced_isle.gd `recipe`, a big
## SkyIslet) step by step: its shape, top, sides and planting, timed.
##   godot --headless --path . --script tools/probe_pierced_lid.gd -- [--seed=3]
const PiercedIsle = preload("res://scripts/pierced_isle.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")

func _initialize() -> void:
	var seed_value := 3
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): seed_value = int(a.trim_prefix("--seed="))
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	var plan: RefCounted = PiercedIsle.make(seed_value)
	var t := Time.get_ticks_usec()
	var shape: RefCounted = SkyIslet.author(plan.lid_seed(),plan.recipe)
	print("author %.0f ms, objects %d, points %d, land faces %d" % [(Time.get_ticks_usec()-t)/1000.0,shape.objects.size(),shape.points.size(),shape.land.size()])
	t = Time.get_ticks_usec()
	var cat := SkyIslets.catalog(null)
	print("catalog %.0f ms" % [(Time.get_ticks_usec()-t)/1000.0])
	t = Time.get_ticks_usec()
	var top: Array = shape.top_arrays(SkyIslet.plain_palette())
	print("top %.0f ms, %d faces" % [(Time.get_ticks_usec()-t)/1000.0,(top[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3])
	t = Time.get_ticks_usec()
	var sides: Array = shape.side_arrays()
	print("sides %.0f ms, %d faces" % [(Time.get_ticks_usec()-t)/1000.0,(sides[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3])
	t = Time.get_ticks_usec()
	var flora: Dictionary = shape.flora(cat.data)
	var count := 0
	for k in flora: count += int(flora[k].count)
	print("flora %.0f ms, %d instances in %d batches" % [(Time.get_ticks_usec()-t)/1000.0,count,flora.size()])
	var kinds := {}
	for o: Dictionary in shape.objects: kinds[o.asset] = int(kinds.get(o.asset,0))+1
	print(kinds)
	quit()
