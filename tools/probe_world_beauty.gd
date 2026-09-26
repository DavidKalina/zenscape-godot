extends SceneTree
## Headless probe: time and score generator candidates across seeds.
## godot --headless --path . -s res://tools/probe_world_beauty.gd -- [count]
const Beauty = preload("res://scripts/world_beauty.gd")
const World = preload("res://scripts/inland_world.gd")
const Generator = preload("res://scripts/cozy_world_generator.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size()>0 else 40
	var build_ms := 0.0
	var score_ms := 0.0
	var sample_ms := 0.0
	var totals := {}
	for i in range(count):
		var t0 := Time.get_ticks_usec()
		var world := Generator.sample(i)
		sample_ms += (Time.get_ticks_usec()-t0)/1000.0
		var t := Time.get_ticks_usec()
		var field = World.new(world.terrain).sampler
		var t2 := Time.get_ticks_usec()
		var s := Beauty.score(field)
		var t3 := Time.get_ticks_usec()
		build_ms += (t2-t)/1000.0
		score_ms += (t3-t2)/1000.0
		if not totals.has(world.terrain.composition): totals[world.terrain.composition] = []
		totals[world.terrain.composition].append(s.total)
		var harmony := Beauty.palette(_colors(world.mood.colors),world.mood.phase<0.1)
		print("harmony %.2f " % harmony,"seed %3d %-17s %-16s rel %.2f  total %.2f  drama %.2f focal %.2f water %.2f comp %.2f relief %.2f  %s" % [i,world.terrain.composition,world.terrain.landform,world.terrain.relief,s.total,s.drama,s.focal,s.water,s.composition,s.relief,world.mood.weather])
	var all := 0.0
	for family in totals:
		var list: Array = totals[family]
		var sum := 0.0
		for v in list: sum += v
		all += sum
		print("%-17s n=%2d mean %.2f min %.2f" % [family,list.size(),sum/list.size(),list.min()])
	print("overall mean %.3f, sample %.0f ms per world" % [all/count,sample_ms/count])
	print("mean build %.1f ms, score %.1f ms per candidate" % [build_ms/count,score_ms/count])
	quit()

func _colors(encoded: Dictionary) -> Dictionary:
	var colors := {}
	for key in encoded: colors[key] = Color(encoded[key])
	return colors
