extends SceneTree
## The lake motif (scripts/cluster_motifs.gd "lake"): its lead islet is
## mostly a lake (scripts/islet_lake.gd) with a level of its own, shallow
## shelves round a deep bowl, dry land all round it but the spill, whose
## channel leaves over the rim where the fall pours, wet read from the
## ground itself and the water's sheet at the level; a spring's pond keeps
## the old level. Laid by the solver (scripts/cluster_lake.gd): over SEEDS
## seeds every plan passes the validator with a jetty out to deep water, a
## boat afloat by it, lilies and lanterns on the water; the walker keeps
## off the water but on the jetty, and the glide skims the water's top.
## Stood (scripts/lake_dress.gd): the lake's pond, its fall, the boat, the
## lilies, the floating lanterns, their halos and the reflections.
const SkyIslet = preload("res://scripts/sky_islet.gd")
const IsletLake = preload("res://scripts/islet_lake.gd")
const Solver = preload("res://scripts/cluster_solver.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyClusters = preload("res://scripts/sky_clusters.gd")
const SEEDS := 16
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _run() -> void:
	# The islet itself.
	var levels := {}
	var shares := []
	var shelf_and_deep := true
	var dry_round := true
	var agrees := true
	var sheet_level := true
	for s in range(6):
		var islet: RefCounted = SkyIslet.author(7100+s*313,{"kind":"meadow","radius":16.0,"lake":{"toward":Vector2.from_angle(s*1.1)},"dome":0.15})
		var level: float = islet.water_level
		levels[snappedf(level,0.01)] = true
		shares.append(float(islet.lake.area)/islet.land_area())
		var shallow := 0
		var deep := 0
		var wet_far := false
		for i in range(islet.points.size()):
			if islet.shore_distance[i] < 0.0: continue
			var p: Vector2 = islet.points[i]
			var under := level-float(islet.heights[i])
			if under > 0.1 and under < 0.35: shallow += 1
			if under > 2.0: deep += 1
			if under > 0.0 and islet.shore_distance[i] < 1.0 and islet._channel_distance(p) > SkyIslet.CHANNEL*1.5: wet_far = true
			if islet.wet(p) != (islet.on_land(p) and float(islet.ground_at(p)) < level-0.005) and islet.deck_y(p) == -INF: agrees = false
		if shallow < 10 or deep < 10: shelf_and_deep = false
		if wet_far: dry_round = false
		var arrays: Array = islet.water_arrays(Color.WHITE)
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			if not is_equal_approx(v.y,level): sheet_level = false
		var w: Dictionary = islet.water()
		check(islet.lake.spilled and islet.wet(islet.lip-(islet.lip_out as Vector2)*0.4) and is_equal_approx(float(w.level),level) and w.has("half"),
			"Lake %d spills off its rim at its own level (%.2f m), a broad fall" % [s,level])
	check(levels.size() > 1,"Each lake has a level of its own (%s)" % str(levels.keys()))
	shares.sort()
	check(float(shares[0]) > 0.35,"A lake is most of its islet (least %.0f%%)" % (float(shares[0])*100.0))
	check(shelf_and_deep,"Shallow shelves round a deep bowl")
	check(dry_round,"Dry land all round the water but the spill")
	check(agrees,"Wet is the ground under the level")
	check(sheet_level,"The water's sheet lies at the level")
	var spring: RefCounted = SkyIslet.make(5,"spring")
	check(is_equal_approx(float(spring.water().level),SkyIslet.WATER) and spring.lake.is_empty(),"A spring's pond keeps the old level")
	# Laid by the solver.
	var bad := []
	var whole := 0
	var walker := true
	var glide := true
	for s in range(SEEDS):
		var plan := Solver.solve("lake",900+s*7717)
		var problems := Solver.validate(plan)
		if not problems.is_empty(): bad.append("seed %d: %s" % [900+s*7717,problems[0]])
		var lead: Dictionary = plan.members[0]
		var shape: RefCounted = lead.shape
		var have := {}
		for f: Dictionary in lead.features:
			have[f.type+("_jetty" if f.get("jetty",false) else "")] = f
		if have.has("dock_jetty") and have.has("boat") and have.has("floats") and not (have.floats.lanterns as Array).is_empty(): whole += 1
		if have.has("dock_jetty"):
			var j: Dictionary = have.dock_jetty
			var mid := Vector2((j.a.x+j.b.x)*0.5,(j.a.z+j.b.z)*0.5)
			var beside := mid+Vector2(-(j.b.z-j.a.z),j.b.x-j.a.x).normalized()*2.0
			if SkyIslets.blocked(shape,mid) or (shape.wet(beside) and not SkyIslets.blocked(shape,beside)): walker = false
		var water_at: Vector2 = shape.lake.deep
		if shape.wet(water_at) and absf(float(shape.solid_top(water_at))-float(shape.water_level)) > 0.01: glide = false
	check(bad.is_empty(),"%d lake plans pass the validator%s" % [SEEDS,"" if bad.is_empty() else " (%d fail, e.g. %s)" % [bad.size(),bad[0]]])
	check(whole == SEEDS,"Every lake has its jetty, boat and floating lanterns (%d of %d)" % [whole,SEEDS])
	check(walker,"On foot: the jetty is ground, the water beside it isn't")
	check(glide,"The glide skims the water's top")
	# Stood.
	var cells := SkyCells.new([Vector3.ZERO])
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var field: Node3D = SkyClusters.new()
	field.islets = islets
	field.with_showcase = false
	field.with_random = true
	root.add_child(field)
	field.reset(cells)
	var spot: Dictionary = field.spots[0]
	spot.motif = "lake"
	spot.seed = 4242
	field.plan_now(spot.key)
	var stood: Dictionary = field.members_of(spot.key)
	var node: Node3D = (stood.get("lake",{}) as Dictionary).get("node")
	check(node != null,"The lake cluster stands (%s)" % str(stood.keys()))
	if node != null:
		for part in ["Pond","Fall","Dock","Boat","Lilies","FloatingLantern","LakeHalos","Glints","LakeLife"]:
			check(node.find_child(part,false,false) != null,"Its lead has its %s" % part)
	field.daylight_override = 0.0
	for i in range(120):
		field.advance(1.0/30.0,spot.at+cells.origin)
		await process_frame
	var glints: Node = node.find_child("Glints",false,false) if node != null else null
	check(glints != null and float(((glints as GeometryInstance3D).material_override as ShaderMaterial).get_shader_parameter("glow")) > 0.8,"At night the lake's reflections glow")
	print("PASS: cluster lake" if failures == 0 else "FAIL: cluster lake")
	field.queue_free()
	islets.queue_free()
	await process_frame
	quit(1 if failures else 0)
