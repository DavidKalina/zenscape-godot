extends SceneTree
## Probe: the collectible lines a whole sky lays (scripts/sky_collectibles.gd,
## scripts/collectible_lines.gd), counted by category without standing the
## sky: every cluster planned and laid, every island pair's swoop, and the
## islets' odds counted from their hashes (their under lines nearly always
## lay; their foot lines are tried on a sample). Prints the census and what
## laying costs.
##   godot --headless --path . -s res://tools/probe_collectibles.gd [-- --sky-seed=N --islet-sample=40]
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyClusters = preload("res://scripts/sky_clusters.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyCollectibles = preload("res://scripts/sky_collectibles.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const Solver = preload("res://scripts/cluster_solver.gd")
const Lines = preload("res://scripts/collectible_lines.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sample := 40
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--islet-sample="): sample = int(a.trim_prefix("--islet-sample="))
	SkyWorld.read_flags()
	if SkyWorld.seed_flag() >= 0: SkyWorld.seed = SkyWorld.seed_flag()
	var began := Time.get_ticks_msec()
	var cells := SkyCells.new(SkyWorld.SLOTS)
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var field: Node3D = SkyClusters.new()
	field.islets = islets
	field.with_near = []
	root.add_child(field)
	field.reset(cells)
	var tokens: Node3D = SkyCollectibles.new()
	tokens.islets = islets
	tokens.clusters = field
	root.add_child(tokens)
	tokens.reset(cells)
	print("PROBE seed %d, layout %d ms" % [SkyWorld.seed,Time.get_ticks_msec()-began])
	var census := {"bridge":0,"under":0,"air":0,"foot":0}
	var lines := {"bridge":0,"under":0,"air":0,"foot":0}
	var kinds := {}
	var t := Time.get_ticks_usec()
	tokens._lay_trails()
	var trail_us := Time.get_ticks_usec()-t
	for l: Dictionary in tokens.sources.trails.lines: _count(l,census,lines,kinds)
	print("PROBE trails: %d lines in %d ms" % [(tokens.sources.trails.lines as Array).size(),trail_us/1000])
	# Every cluster, planned and laid as its worker would.
	var cluster_us := 0
	for s: Dictionary in field.spots:
		var plan := Solver.solve(s.motif,int(s.seed))
		var c := {"plan":plan,"stood":{},"spot":s}
		for m: Dictionary in plan.members:
			c.stood[m.name] = {"node":tokens}
			m.shape.flora(SkyIslets.catalog().data)
		t = Time.get_ticks_usec()
		var job: Dictionary = tokens._cluster_job("cluster:"+str(s.key),c)
		var laid: Array = job.work.call()
		var us := Time.get_ticks_usec()-t
		cluster_us += us
		var names: Array = laid.map(func(l: Dictionary) -> String: return "%s/%s(%d)" % [l.category,l.kind,(l.points as PackedVector3Array).size()])
		print("PROBE cluster %s %s: %s in %d ms" % [s.key,s.motif,", ".join(names),us/1000])
		for l: Dictionary in laid: _count(l,census,lines,kinds)
	# The islets: every spot in the world, their hashes; a sample laid.
	var spots: Array = []
	var reach := ceili(SkyWorld.SCATTER/SkyIslets.CELL)+1
	for x in range(-reach,reach+1):
		for z in range(-reach,reach+1):
			var at: Variant = islets.spot(Vector2i(x,z))
			if at != null: spots.append([Vector2i(x,z),at])
	var under_n := 0
	var foot_n := 0
	for e: Array in spots:
		var key: String = "islet:"+islets._key(e[0])
		if Lines.lays(SkyWorld.seed,key,"under_islet"): under_n += 1
		if Lines.lays(SkyWorld.seed,key,"foot_islet"): foot_n += 1
	var tried := 0
	var foot_tried := 0
	var foot_laid := 0
	var foot_tokens := 0
	var under_tokens := 0
	var under_laid := 0
	var islet_us := 0
	for e: Array in spots:
		if tried >= sample: break
		var key: String = "islet:"+islets._key(e[0])
		var under := Lines.lays(SkyWorld.seed,key,"under_islet")
		var foot := Lines.lays(SkyWorld.seed,key,"foot_islet")
		if not under and not foot: continue
		tried += 1
		var shape: RefCounted = SkyIslet.make(SkyIslets.seed_of(e[0]))
		shape.flora(SkyIslets.catalog().data)
		t = Time.get_ticks_usec()
		if under:
			var l := Lines.under_line(key+":under",func(p: Vector2) -> float: return Lines.islet_under(shape,p),Vector2.ZERO,float(shape.reach),Lines.LOWEST-(e[1] as Vector3).y,SkyWorld.seed)
			if not l.is_empty():
				under_laid += 1
				under_tokens += (l.points as PackedVector3Array).size()
		if foot and not shape.crowns.is_empty():
			foot_tried += 1
			var l := Lines.foot_line(key+":foot",[Lines.solid(shape,Vector3.ZERO)],0,SkyWorld.seed)
			if not l.is_empty():
				foot_laid += 1
				foot_tokens += (l.points as PackedVector3Array).size()
		islet_us += Time.get_ticks_usec()-t
	print("PROBE islets: %d in the world; hashes ask %d under lines and %d foot lines; of %d laid here: %d under (%d tokens), foot %d of %d with trees (%d tokens), %d ms laying" % [spots.size(),under_n,foot_n,tried,under_laid,under_tokens,foot_laid,foot_tried,foot_tokens,islet_us/1000])
	print("PROBE clusters + trails: %s tokens, %s lines, kinds %s; clusters laid in %d ms" % [str(census),str(lines),str(kinds),cluster_us/1000])
	print("PROBE done")
	quit(0)

func _count(l: Dictionary, census: Dictionary, lines: Dictionary, kinds: Dictionary) -> void:
	census[l.category] += (l.points as PackedVector3Array).size()
	lines[l.category] += 1
	kinds[l.kind] = int(kinds.get(l.kind,0))+1
