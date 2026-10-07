extends SceneTree
## The forest hold motif (scripts/cluster_motifs.gd "forest", scripts/
## woodland.gd, scripts/forest_hold.gd): over SEEDS seeds its hold is a
## real wood (many trees, layered: emergent giants over a canopy over an
## understory, lower trees at the edge, ferns and fallen wood under them),
## with a glade holding the hut, the platform up the hold tree, wooded
## islets on rope bridges, a trail from every bridge clear of trunks to the
## hut, lantern strings and bough lanterns that all leave headroom, and
## lanterns on the bridges; stood up, its night lights come as a few
## batches and a handful of real lights per member, however many lanterns.
const Solver = preload("res://scripts/cluster_solver.gd")
const Dresser = preload("res://scripts/cluster_dresser.gd")
const ForestHold = preload("res://scripts/forest_hold.gd")
const Woodland = preload("res://scripts/woodland.gd")
const SEEDS := 8
var failures := 0

func _initialize() -> void:
	var stats := {"trees":0,"giants":0,"under":0,"canopy":0,"ferns":0,"logs":0,"strings":0,"hangs":0,"bridges":0,"wood_trees":0}
	var bad: Array = []
	var slowest := 0
	for s in range(SEEDS):
		var seed_value := 300+s*7717
		var began := Time.get_ticks_msec()
		var plan := Solver.solve("forest",seed_value)
		slowest = maxi(slowest,Time.get_ticks_msec()-began)
		var problems := Solver.validate(plan)
		if not problems.is_empty(): bad.append("seed %d: %s" % [seed_value,problems[0]])
		var hold: Dictionary = plan.members[0]
		var shape: RefCounted = hold.shape
		var glades: Array = shape.get_meta("glades",[])
		for o: Dictionary in shape.objects:
			var h := float(o.scale)*float(Woodland.HEIGHT.get(o.asset,0.0))
			if o.asset in ForestHold.TREES:
				stats.trees += 1
				if h >= Woodland.GIANT.x-0.1: stats.giants += 1
				elif h <= Woodland.UNDER.y+0.1: stats.under += 1
				else: stats.canopy += 1
			elif o.asset == "fern": stats.ferns += 1
			elif o.asset in ["log","stump","snag"]: stats.logs += 1
		var cabin: Dictionary = ForestHold._find(hold,"cabin")
		var house: Dictionary = ForestHold._find(hold,"treehouse")
		var canopy: Dictionary = ForestHold._find(hold,"canopy")
		var trail: Dictionary = ForestHold._find(hold,"trail")
		if glades.is_empty() or cabin.is_empty() or (cabin.at as Vector2).distance_to(Vector2(glades[0].x,glades[0].y)) > float(glades[0].z)+1.5:
			bad.append("seed %d: the hut stands outside the hold's glade" % seed_value)
		if house.is_empty(): bad.append("seed %d: no treehouse" % seed_value)
		if canopy.is_empty() or canopy.strings.size()+canopy.hangs.size() < 6: bad.append("seed %d: few canopy lanterns" % seed_value)
		else:
			stats.strings += canopy.strings.size()
			stats.hangs += canopy.hangs.size()
		# The trail runs clear of trunks.
		if trail.is_empty(): bad.append("seed %d: no trail on the hold" % seed_value)
		else:
			for o: Dictionary in shape.objects:
				if not o.asset in ForestHold.TREES: continue
				for line: PackedVector2Array in trail.lines:
					for k in range(line.size()-1):
						if ForestHold._segment_distance(Vector2(o.x,o.z),line[k],line[k+1]) < ForestHold.TRAIL_HALF and not house.is_empty() and Vector2(o.x,o.z).distance_to(house.at) > 0.05:
							bad.append("seed %d: a trunk on the trail (%s at %s)" % [seed_value,o.asset,str(Vector2(o.x,o.z))])
		for m: Dictionary in plan.members:
			if m.role == "grove":
				for o: Dictionary in m.shape.objects:
					if o.asset in ForestHold.TREES: stats.wood_trees += 1
		var roped := 0
		for br: Dictionary in plan.bridges:
			if br.from == "hold": roped += 1
		stats.bridges += roped
		if roped < 1: bad.append("seed %d: no bridge off the hold" % seed_value)
	check(bad.is_empty(),"%d seeds lay a whole forest hold%s" % [SEEDS,"" if bad.is_empty() else " (%d wrong, e.g. %s)" % [bad.size(),bad[0]]])
	var n := float(SEEDS)
	print("  a hold: %.0f trees (%.1f giants, %.0f canopy, %.0f understory and edge), %.0f ferns, %.0f logs and stumps; %.0f lantern strings, %.0f bough lanterns; a grove %.0f trees; slowest plan %d ms" % [
		stats.trees/n,stats.giants/n,stats.canopy/n,stats.under/n,stats.ferns/n,stats.logs/n,stats.strings/n,stats.hangs/n,stats.wood_trees/n/2.5,slowest])
	check(stats.trees/n >= 110.0,"The hold is a wood, not a few trees (%.0f a hold)" % (stats.trees/n))
	check(stats.giants/n >= 2.0 and stats.under/n >= 15.0 and stats.canopy/n >= 40.0,"Its canopy is layered: giants, canopy, understory")
	check(stats.ferns/n >= 25.0 and stats.logs/n >= 4.0,"Its floor has ferns and fallen wood")
	# Stood up: lanterns batched, few real lights.
	var plan := Solver.solve("forest",300)
	var root_node := Node3D.new()
	root.add_child(root_node)
	var lanterns := 0
	var most_lights := 0
	var bridge_lanterns := 0
	for m: Dictionary in plan.members:
		var made := Dresser.prepare(m,plan)
		var node := Node3D.new()
		root_node.add_child(node)
		var live := Dresser.furnish(node,m,plan,made)
		most_lights = maxi(most_lights,(live.lights as Array).size())
		var batch := node.get_node_or_null("Lanterns") as MultiMeshInstance3D
		if batch != null: lanterns += batch.multimesh.instance_count
	for br: Dictionary in plan.bridges:
		var only := {"night":plan.night,"bridges":[br]}
		var made := ForestHold.prepare({"name":br.from,"features":[],"shape":plan.members[0].shape,"seed":1},only)
		if not made.is_empty(): bridge_lanterns += (made.lanterns as Array).size()
	check(lanterns >= 20,"Its lanterns stand up in batches (%d lanterns)" % lanterns)
	check(bridge_lanterns >= ForestHold.BRIDGE_AT.size(),"Lanterns hang on its rope bridges (%d)" % bridge_lanterns)
	check(most_lights <= 10,"A handful of real lights a member at most (%d)" % most_lights)
	Dresser.set_night(1.0)
	root_node.free()
	Dresser.release()
	print("PASS: forest hold" if failures == 0 else "FAIL: forest hold")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)
