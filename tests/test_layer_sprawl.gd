extends "res://tests/test_run_layer.gd"
## suite: slow
## The sprawl shape (scripts/roguelike/layer_sprawl.gd, scripts/roguelike/
## next_region_lod.gd; docs/design/roguelike/layer-round4-sprawl.md;
## studies/run_layer.tscn --shape=sprawl), headless:
##   - the plan is the same for the same seed (laid again from nothing);
##   - an exit side: the last neighbourhood stands that way, a chain of 4-5
##     crossings (stones, a bridge, the voussoirs, a cannon) leaves one of
##     its rims on toward it and climbs, the gate on its last slab, past
##     every isle of the layer that way;
##   - every crossing within the pilot's reach (round 2's rules);
##   - the next region stands past the gate, higher, apart from this layer;
##     the spawn faces it and from the spawn's eye a physics ray reaches
##     its landmark through the built layer; its silhouette is cheap
##     (COST) and not lost in its haze;
##   - built and driven through the study's own `tick` (test_run_layer.gd's
##     moves): every route and chain edge crossed on foot, the chain's
##     cannon landing him on its catch, the greed cannon, every gulf ridden
##     over on its serpent or ferry;
##   - through the gate the next layer is the region seen (its seed, its
##     isles where they were drawn), and it has a next region of its own.
##   godot --headless --path . --script tests/test_layer_sprawl.gd
## SPRAWL_SEEDS=15,2 picks the driven seeds (RL_TRACE=<seed> as before).
const LayerSprawl = preload("res://scripts/roguelike/layer_sprawl.gd")
const NextRegionLod = preload("res://scripts/roguelike/next_region_lod.gd")

## Driven through the play loop (15: a serpent gulf, 2: a ferry gulf);
## planned and checked only.
var DRIVE := [15,2] if OS.get_environment("SPRAWL_SEEDS") == "" else Array(OS.get_environment("SPRAWL_SEEDS").split(",")).map(func(s: String) -> int: return int(s))
const PLANNED := [1,3,4]
## The silhouette's budget: triangles, surfaces (draw calls), build (ms,
## headless on the main thread), and the most its landmark may be hazed
## from the spawn.
const COST := {"triangles":40000,"surfaces":1,"ms":80.0,"haze":0.6}
## The next region: at least this much over the gate (m), this far past it
## along the exit side (m).
const OVER_GATE := 50.0
const PAST_GATE := 100.0

func run() -> void:
	create_timer(1200.0).timeout.connect(func() -> void: push_error("layer sprawl test timed out"); quit(2))
	_sprawl_plans()
	study = load("res://studies/run_layer.tscn").instantiate()
	study.scripted = true
	study.layer_seed = DRIVE[0]
	study.layer_shape = "sprawl"
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	m = study.motor
	for k in range(DRIVE.size()):
		if k > 0: study.start_layer(DRIVE[k])
		var began := Time.get_ticks_msec()
		study.sky.flush()
		await physics_frame
		await physics_frame
		await process_frame
		print("layer sprawl test: seed %d stood in %d ms (flushed)" % [DRIVE[k],Time.get_ticks_msec()-began])
		await _sprawl_layer(DRIVE[k])
	_sprawl_gate()
	print("PASS: layer sprawl" if failures == 0 else "FAIL: layer sprawl (%d)" % failures)
	quit(1 if failures > 0 else 0)

# --- The plans ------------------------------------------------------------------

func _sprawl_plans() -> void:
	# The same plan from nothing twice.
	var s: int = DRIVE[0]
	var began := Time.get_ticks_msec()
	var a := LayerSprawl.make(s)
	print("layer sprawl test: seed %d planned (with its next region) in %d ms" % [s,Time.get_ticks_msec()-began])
	var a_text := _text(a)
	LayerSprawl._kept.clear()
	LayerSprawl._order.clear()
	var b := LayerSprawl.make(s)
	check(a_text == _text(b),"seed %d: the same sprawl plan twice, laid from nothing (its chain, gate and next region)" % s)
	print(LayerSprawl.overview(b))
	for t: int in DRIVE+PLANNED:
		var t0 := Time.get_ticks_msec()
		var plan := LayerSprawl.make(t)
		print("layer sprawl test: seed %d planned in %d ms\n%s\n%s" % [t,Time.get_ticks_msec()-t0,LayerPlan.describe(plan),LayerSprawl.card(plan)])
		_sprawl_plan(t,plan)

## A plan's words and numbers, for comparing.
func _text(plan: Dictionary) -> String:
	if not (plan.problems as Array).is_empty(): return str(plan.problems)
	return "%s\n%s\n%s %s %s" % [LayerPlan.describe(plan),LayerSprawl.card(plan),str(plan.next.xform),str(plan.spawn),str(plan.exit.at)]

func _sprawl_plan(s: int, plan: Dictionary) -> void:
	check((plan.problems as Array).is_empty(),"seed %d: laid (%s)" % [s,str(plan.problems)])
	if not (plan.problems as Array).is_empty(): return
	var h: Vector2 = plan.heading
	var along := func(p: Vector3) -> float: return Vector2(p.x,p.z).dot(h)
	# The exit side: the last neighbourhood that way off the base.
	var hoods: Array = plan.hoods
	var last_mid := Vector2.ZERO
	for i: int in hoods[hoods.size()-1]: last_mid += LayerPlan._rect(plan.isles[i]).get_center()
	last_mid /= (hoods[hoods.size()-1] as Array).size()
	check((last_mid-Vector2(LayerPlan.MIDDLE.x,LayerPlan.MIDDLE.z)).dot(h) > 0.0,"seed %d: the last neighbourhood stands on the exit side (%s)" % [s,LayerSprawl.compass(h)])
	# The chain.
	var chain: Array = plan.chain
	var kinds: Array = chain.map(func(i: int) -> String: return str(plan.edges[i].kind))
	check(chain.size() >= LayerSprawl.LINKS.x and chain.size() <= LayerSprawl.LINKS.y and kinds.has("stones") and kinds.has("bridge") and kinds.has("trap") and kinds.has("cannon"),
		"seed %d: an exit chain of %d crossings (%s)" % [s,chain.size(),", ".join(PackedStringArray(kinds))])
	var first: Dictionary = plan.edges[chain[0]]
	check(int(first.from[0]) in hoods[hoods.size()-1] and plan.isles[int(first.from[0])].role != "greed","seed %d: it leaves a rim of the last neighbourhood (%d.%s)" % [s,int(first.from[0]),str(first.from[1])])
	var on := true
	var up := 0.0
	for i: int in chain:
		var e: Dictionary = plan.edges[i]
		on = on and along.call(e.b) > along.call(e.a)
		up += (e.b as Vector3).y-(e.a as Vector3).y
	check(on and up > 0.0,"seed %d: each crossing goes on toward the exit side, climbing %.1f m in all" % [s,up])
	var gate: Vector3 = plan.exit.at
	var last_edge: Dictionary = plan.edges[chain[chain.size()-1]]
	var threshold: Dictionary = (last_edge.stones as Array).filter(func(st: Dictionary) -> bool: return str(st.name).ends_with("threshold"))[0]
	var on_slab := Vector2(gate.x-(threshold.at as Vector3).x,gate.z-(threshold.at as Vector3).z).length() < float((threshold.size as Vector3).x)*0.5-1.0 and absf(gate.y-(threshold.at as Vector3).y) < 0.01
	check(on_slab,"seed %d: the gate on the chain's last slab" % s)
	var past := true
	for isle: Dictionary in plan.isles:
		var c := LayerPlan._rect(isle).get_center()
		past = past and Vector2(gate.x,gate.z).dot(h) > c.dot(h)
	check(past,"seed %d: the gate stands past every isle's middle on the exit side" % s)
	for i: int in chain:
		var e: Dictionary = plan.edges[i]
		if e.kind != "cannon": continue
		var c: Dictionary = e.cannon
		var off := INF
		for j: int in chain:
			for st: Dictionary in plan.edges[j].stones:
				if st.get("landing",false): off = minf(off,(c.target as Vector3).distance_to(st.at))
		check(off < 0.01 and Vector2((c.landing as Vector3).x-(c.target as Vector3).x,(c.landing as Vector3).z-(c.target as Vector3).z).length() < LayerPlan.SHOT_NEAR,
			"seed %d: the chain's cannon is aimed at its catch's middle (%.0f m, notch %d, pitch %.0f deg)" % [s,Vector2((c.target as Vector3).x-(c.at as Vector3).x,(c.target as Vector3).z-(c.at as Vector3).z).length(),int(c.notch)+1,rad_to_deg(float(c.pitch))])
	_reach(s,plan)
	# The next region.
	var nx: Dictionary = plan.next
	var mark: Vector3 = nx.landmark
	check(mark.y > gate.y+OVER_GATE and along.call(mark)-along.call(gate) > PAST_GATE,"seed %d: the next region (layer %d) stands past the gate (%.0f m on) and higher (its landmark %.0f m over it)" % [s,int(nx.seed),along.call(mark)-along.call(gate),mark.y-gate.y])
	check(bool(nx.sight_ok),"seed %d: from the spawn's eye its landmark (%s) is in sight over this layer's isles (planned)" % [s,str(nx.landmark_id)])
	var face: Vector3 = plan.spawn.face
	var to := Vector2(mark.x-(plan.spawn.at as Vector3).x,mark.z-(plan.spawn.at as Vector3).z).normalized()
	check(Vector2(face.x,face.z).dot(to) > 0.99,"seed %d: the spawn faces it" % s)
	var lod := NextRegionLod.build(nx)
	var st: Dictionary = lod.get_meta("stats")
	var haze := NextRegionLod.haze((nx.sight[0] as Vector3).distance_to(mark),1.0,true)
	check(int(st.triangles) > 1000 and int(st.triangles) <= int(COST.triangles) and int(st.surfaces) <= int(COST.surfaces) and float(st.ms) <= float(COST.ms),
		"seed %d: its silhouette costs %d triangles in %d surface, built in %.1f ms (budget %d, %d, %.0f ms)" % [s,int(st.triangles),int(st.surfaces),float(st.ms),int(COST.triangles),int(COST.surfaces),float(COST.ms)])
	check(haze <= float(COST.haze),"seed %d: its landmark %.0f m off is %.0f%% hazed from the spawn (at most %.0f%%)" % [s,(nx.sight[0] as Vector3).distance_to(mark),haze*100.0,float(COST.haze)*100.0])
	var aabb: AABB = (lod.transform*lod.mesh.get_aabb()) if lod.mesh.get_surface_count() > 0 else AABB()
	check(absf(aabb.end.y-(mark.y+LayerSprawl.MARK_UNDER)) < 0.5,"seed %d: its landmark is the region's highest point (%.0f, %.0f)" % [s,aabb.end.y,mark.y+LayerSprawl.MARK_UNDER])
	lod.free()

# --- A built layer --------------------------------------------------------------

func _sprawl_layer(s: int) -> void:
	var plan: Dictionary = study.layer
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	check(study.sky.motifs.all_stood() and study.sky.motifs.isles.size() == plan.isles.size()-1,"seed %d: its %d motif isles stand" % [s,plan.isles.size()-1])
	# The silhouette stands in the layer.
	var lod: MeshInstance3D = study.stage.find_child("NextRegion",true,false)
	check(lod != null and lod.is_inside_tree() and lod.mesh.get_surface_count() == 1,"seed %d: the next region's silhouette stands in the layer" % s)
	# In sight from where he starts: a ray through the built layer.
	var eye: Vector3 = (study.start as Vector3)+Vector3.UP*LayerSprawl.EYE
	var mark: Vector3 = plan.next.landmark
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,mark,0xFFFFFFFF))
	check(hit.is_empty(),"seed %d: from the start (%s) a ray reaches the next region's landmark %.0f m off%s" % [s,eye.snapped(Vector3.ONE*0.1),eye.distance_to(mark),
		"" if hit.is_empty() else " (%s at %s)" % [(hit.collider as Node).get_path(),(hit.position as Vector3).round()]])
	var own := _own()
	# The rims round 3 uses, and the chain's first.
	for e: Dictionary in plan.edges:
		var rims: Array = [e.from_rim,e.to_rim] if e.branch != "exit" else ([e.from_rim] if int(e.from[0]) >= 0 else [])
		for rim: Dictionary in rims:
			var why := Probe.rim_ok(space,rim,own)
			check(why == "","seed %d: rim %s stands on its ground over the drop %s" % [s,rim.name,why])
	for e: Dictionary in plan.edges:
		if e.kind in ["gulf","cannon"]: continue
		var hit_at := _corridor(space,e)
		check(hit_at == "","seed %d %s %s: its corridor is clear %s" % [s,e.branch,e.kind,hit_at])
	# Driven across: the route, the greed branch and the chain on foot.
	var trap_n := 0
	for e: Dictionary in plan.edges:
		if e.kind in ["gulf","cannon"]: continue
		var ok := _cross(e)
		check(ok,"seed %d %s %s (%s): crossed on foot, %s" % [s,e.branch,e.kind,", ".join(PackedStringArray(e.parts)),_feet()])
		if not (e.trap as Dictionary).is_empty():
			var trap: Node3D = study.stage.traps.traps[trap_n]
			check(int(trap.fallen_count) > 0,"seed %d %s: the voussoirs fell behind him (%d)" % [s,e.branch,int(trap.fallen_count)])
			trap_n += 1
	for i: int in plan.chain:
		var e: Dictionary = plan.edges[i]
		if e.kind == "cannon": _chain_cannon(s,i,e)
	_cannon(s,plan)
	await _gulfs(s,plan)

## The chain's cannon at its found aim fires him onto its catch slab.
func _chain_cannon(s: int, i: int, e: Dictionary) -> void:
	var field: Node = study.stage.cannons
	var c: Node3D = field.find_child("ExitCannon%d" % i,false,false)
	check(c != null,"seed %d: the chain's cannon stands on its deck" % s)
	if c == null: return
	if study.stage != null: study.stage.reset()
	var aim: Dictionary = e.cannon
	study.place(_ground(field.stand(c)),Vector2(0.0,-1.0))
	for k in range(10): tick(Vector2.ZERO)
	field.operate(c)
	c.set_aim(0.0,float(aim.pitch))
	c.set_power(int(aim.notch))
	field.climb_in()
	field.launch_self()
	var landed := false
	for f in range(600):
		tick(Vector2.ZERO)
		if m.grounded and f > 10:
			landed = true
			break
	var target: Vector3 = aim.target
	var miss := Vector2(m.feet.x-target.x,m.feet.z-target.z).length()
	check(landed and miss < 2.5 and absf(m.feet.y-target.y) < 1.0,"seed %d: the chain's cannon lands him on its catch (%.1f m off its mark, %s)" % [s,miss,_feet()])

## Through the gate: the next layer is the region that was seen, with a
## next region of its own; the void as before.
func _sprawl_gate() -> void:
	var seen: Dictionary = study.layer.next
	var exit: Dictionary = study.layer.exit
	var was: int = study.layer_seed
	study.place(exit.at,Vector2(1.0,0.0))
	tick(Vector2.ZERO)
	check(study.layer_seed == int(seen.seed) and study.last_end.begins_with("Through the gate"),"At the gate, the next layer is the region seen (seed %d -> %d, seen %d)" % [was,study.layer_seed,int(seen.seed)])
	var same := (study.layer.isles as Array).size() == (seen.isles as Array).size()
	if same:
		for k in range(seen.isles.size()):
			same = same and str(study.layer.isles[k].id) == str(seen.isles[k].id) and (study.layer.isles[k].offset as Vector3).is_equal_approx(seen.isles[k].offset)
	check(same,"Its isles are the ones drawn far off, where they were drawn")
	check(study.layer.has("next") and study.stage.find_child("NextRegion",true,false) != null,"It has a next region of its own (layer %d)" % int(study.layer.get("next",{}).get("seed",-1)))
	var spawn: Vector3 = study.layer.spawn.at
	check(Vector2(m.feet.x-spawn.x,m.feet.z-spawn.z).length() < 1.0 and absf(m.feet.y-spawn.y) < 2.0,"He starts the new layer at its spawn (%s, the spawn %s)" % [_feet(),spawn.snapped(Vector3.ONE*0.01)])
	was = study.layer_seed
	study.place(Vector3(m.feet.x,float(study.layer.void_y)+1.0,m.feet.z),Vector2(1.0,0.0))
	for i in range(30): tick(Vector2.ZERO)
	check(study.layer_seed == was+1 and study.last_end.begins_with("Into the void"),"Into the void, the next layer (seed %d -> %d)" % [was,study.layer_seed])
