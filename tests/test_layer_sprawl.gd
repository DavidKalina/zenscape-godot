extends "res://tests/test_run_layer.gd"
## suite: slow
## The sprawl shape (scripts/roguelike/layer_sprawl.gd, scripts/roguelike/
## next_region_lod.gd;
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
##   - taller (4B-2): each gulf rises at least RISE_ROLL's least (or a share
##     of its width), each neighbourhood stands higher than the last, holds
##     3+ isles and a climb onto an isle TIER over its lowest;
##   - laid on a worker the plan leaves its next region for later, and laid
##     then it is the one laid at once;
##   - built and driven through the study's own `tick` (test_run_layer.gd's
##     moves; the layers in the sky, --world=sky): every route and chain
##     edge crossed on foot (the Broken Viaduct's flown), the chain's
##     cannon landing him on its catch, the greed cannon, every gulf ridden
##     over on its serpent or ferry;
##   - through the gate the next layer is the region seen (its seed, its
##     isles where they were drawn), and it has a next region of its own;
##     into the void the climb ends on its card;
##   - the dragon's roost (round 5) stands in every sprawl layer: its turf over
##     every isle's highest solid, ROOST_GAP clear of every isle, edge and
##     ride, off the exit side; built, a physics ray from the start's eye
##     meets its tower first, and its dragon lies on its ledge.
##   godot --headless --path . --script tests/test_layer_sprawl.gd
## SPRAWL_SEEDS=15,2 picks the driven seeds (RL_TRACE=<seed> as before).
const LayerSprawl = preload("res://scripts/roguelike/layer_sprawl.gd")
const NextRegionLod = preload("res://scripts/roguelike/next_region_lod.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## Driven through the play loop (6: a ferry gulf rising 30 m; 3: a serpent
## gulf rising 35 m with a cannon up it); planned and checked only.
var DRIVE := [6,3] if OS.get_environment("SPRAWL_SEEDS") == "" else Array(OS.get_environment("SPRAWL_SEEDS").split(",")).map(func(s: String) -> int: return int(s))
const PLANNED := [15,2,1,12]
## The silhouette's budget: triangles, surfaces (draw calls), build (ms,
## headless on the main thread), and the most its landmark may be hazed
## from the spawn.
const COST := {"triangles":40000,"surfaces":1,"ms":80.0,"haze":0.6}
## The next region: at least this much over the gate (m), this far past it
## along the exit side (m).
const OVER_GATE := 50.0
const PAST_GATE := 100.0
## The spawn faces where the next region was to stand (laid before it), its
## landmark within this of straight ahead (degrees).
const FACING := 30.0
## A neighbourhood's isles stand higher than the last's (m, the mean of
## their highest walked points). The planner holds each gulf's rise
## (RISE_ROLL, checked on its own), not the means: a neighbourhood's tier
## climb can lift its mean near the next one's (seed 1: 7 m), so only
## "higher" is held here.
const HOOD_CLIMB := 0.0

func run() -> void:
	create_timer(1200.0).timeout.connect(func() -> void: push_error("layer sprawl test timed out"); quit(2))
	_sprawl_plans()
	# The driven layers in the sky (a run's first regions are city layers
	# underground now, with no sky kit and no roost: layer_worlds.gd).
	LaunchArgs.set_override(["--no-title","--world=sky"])
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
	LaunchArgs.set_override(null)
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
	_later(s)
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
	# The chain, and past its threshold the Broken Viaduct when the hazards
	# roll it (scripts/roguelike/layer_hazards.gd): its far rim then holds
	# the gate.
	var chain: Array = plan.chain
	var kinds: Array = chain.map(func(i: int) -> String: return str(plan.edges[i].kind))
	var viaduct: bool = kinds.back() == "viaduct"
	var links: Array = chain.slice(0,chain.size()-1) if viaduct else chain
	check(links.size() >= LayerSprawl.LINKS.x and links.size() <= LayerSprawl.LINKS.y and kinds.has("stones") and kinds.has("bridge") and kinds.has("trap") and kinds.has("cannon") and kinds.count("viaduct") == (1 if viaduct else 0),
		"seed %d: an exit chain of %d crossings (%s)" % [s,links.size(),", ".join(PackedStringArray(kinds))])
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
	var last_edge: Dictionary = plan.edges[links[links.size()-1]]
	var thresholds: Array = (last_edge.stones as Array).filter(func(st: Dictionary) -> bool: return str(st.name).ends_with("threshold"))
	check(not thresholds.is_empty(),"seed %d: the chain ends on its threshold slab" % s)
	if thresholds.is_empty(): return
	var threshold: Dictionary = thresholds[0]
	if viaduct:
		var v: Dictionary = plan.edges[chain[chain.size()-1]]
		var from_slab := Vector2((v.a as Vector3).x-(threshold.at as Vector3).x,(v.a as Vector3).z-(threshold.at as Vector3).z).length() <= float((threshold.size as Vector3).x)*0.5+0.01
		check(from_slab and (v.b as Vector3).is_equal_approx(gate),"seed %d: the Broken Viaduct goes on from the threshold slab, the gate on its far rim" % s)
	else:
		var on_slab := Vector2(gate.x-(threshold.at as Vector3).x,gate.z-(threshold.at as Vector3).z).length() < float((threshold.size as Vector3).x)*0.5-1.0 and absf(gate.y-(threshold.at as Vector3).y) < 0.01
		check(on_slab,"seed %d: the gate on the chain's last slab" % s)
	# Past every isle of the other neighbourhoods (the planner wants it past
	# the last one's middle too, LayerSprawl GATE_PAST, but keeps the
	# furthest gate it can lay: a bent layout's last isles may reach on).
	var past := true
	var behind := 0
	for isle: Dictionary in plan.isles:
		var c := LayerPlan._rect(isle).get_center()
		if Vector2(gate.x,gate.z).dot(h) <= c.dot(h):
			behind += 1
			if int(isle.hood) != hoods.size()-1: past = false
	check(past,"seed %d: the gate stands past the other neighbourhoods on the exit side (%d isle middles of the last further out, %s its middle)" % [s,behind,
		"past" if Vector2(gate.x,gate.z).dot(h) > last_mid.dot(h) else "short of"])
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
	_tall(s,plan)
	# The next region.
	var nx: Dictionary = plan.next
	var mark: Vector3 = nx.landmark
	check(mark.y > gate.y+OVER_GATE and along.call(mark)-along.call(gate) > PAST_GATE,"seed %d: the next region (layer %d) stands past the gate (%.0f m on) and higher (its landmark %.0f m over it)" % [s,int(nx.seed),along.call(mark)-along.call(gate),mark.y-gate.y])
	check(bool(nx.sight_ok),"seed %d: from the spawn's eye its landmark (%s) is in sight over this layer's isles (planned)" % [s,str(nx.landmark_id)])
	var face: Vector3 = plan.spawn.face
	var to := Vector2(mark.x-(plan.spawn.at as Vector3).x,mark.z-(plan.spawn.at as Vector3).z).normalized()
	check(Vector2(face.x,face.z).dot(to) > cos(deg_to_rad(FACING)),"seed %d: the spawn faces it (within %.0f deg)" % [s,FACING])
	var lod := NextRegionLod.build(nx)
	var st: Dictionary = lod.get_meta("stats")
	var haze := NextRegionLod.haze((nx.sight[0] as Vector3).distance_to(mark),1.0,true)
	check(int(st.triangles) > 1000 and int(st.triangles) <= int(COST.triangles) and int(st.surfaces) <= int(COST.surfaces) and float(st.ms) <= float(COST.ms),
		"seed %d: its silhouette costs %d triangles in %d surface, built in %.1f ms (budget %d, %d, %.0f ms)" % [s,int(st.triangles),int(st.surfaces),float(st.ms),int(COST.triangles),int(COST.surfaces),float(COST.ms)])
	check(haze <= float(COST.haze),"seed %d: its landmark %.0f m off is %.0f%% hazed from the spawn (at most %.0f%%)" % [s,(nx.sight[0] as Vector3).distance_to(mark),haze*100.0,float(COST.haze)*100.0])
	var aabb: AABB = (lod.transform*lod.mesh.get_aabb()) if lod.mesh.get_surface_count() > 0 else AABB()
	lod.free()
	# The landmark the highest of its isles (its roost, if drawn, stands
	# apart and higher, as this layer's does).
	var bare := nx.duplicate()
	bare.erase("roost")
	var lod_bare := NextRegionLod.build(bare)
	var aabb_bare: AABB = lod_bare.transform*lod_bare.mesh.get_aabb()
	check(absf(aabb_bare.end.y-(mark.y+LayerSprawl.MARK_UNDER)) < 0.5,"seed %d: its landmark is the highest point of the region's isles (%.0f, %.0f)%s" % [s,aabb_bare.end.y,mark.y+LayerSprawl.MARK_UNDER,
		"; its roost drawn too, %.0f m high" % aabb.end.y if nx.has("roost") else ""])
	lod_bare.free()
	_roost_plan(s,plan)

## Round 5: the roost apart and over the layer, off the exit side.
func _roost_plan(s: int, plan: Dictionary) -> void:
	var roost: Dictionary = plan.get("roost",{})
	check(not roost.is_empty(),"seed %d: the layer has its dragon's roost" % s)
	if roost.is_empty(): return
	var at: Vector3 = roost.at
	var flat := Vector2(at.x,at.z)
	var reach: float = roost.reach
	# Above every cluster: its turf over every isle's highest solid.
	var high := -INF
	for isle: Dictionary in plan.isles: high = maxf(high,LayerPlan._span(isle).y)
	check(at.y >= high+LayerSprawl.ROOST_OVER-0.01 and LayerPlan._span(roost).y > high+100.0,"seed %d: the roost's turf stands %.0f m over the layer's highest solid, its peak %.0f m" % [s,at.y-high,LayerPlan._span(roost).y-high])
	# Its reach holds every cell of it.
	var o: Dictionary = roost.occ
	var off: Vector3 = roost.offset
	var holds := true
	for k in range((o.lo as PackedFloat32Array).size()):
		if (o.lo as PackedFloat32Array)[k] == INF: continue
		var cell := (o.origin as Vector2)+Vector2(k%int(o.cols)+0.5,k/int(o.cols)+0.5)*float(o.cell)+Vector2(off.x,off.z)
		holds = holds and cell.distance_to(flat) < reach
	# Apart from everything: isles' bounds, every edge, ride and cannon.
	var least := INF
	var what := ""
	for i in range((plan.isles as Array).size()):
		var r: Rect2 = LayerPlan._rect(plan.isles[i])
		var d := Vector2(maxf(maxf(r.position.x-flat.x,flat.x-r.end.x),0.0),maxf(maxf(r.position.y-flat.y,flat.y-r.end.y),0.0)).length()-reach
		if d < least:
			least = d
			what = "isle %d" % i
	for e: Dictionary in plan.edges:
		for sp: Array in e.path:
			var d := Vector2((sp[0] as Vector3).x-flat.x,(sp[0] as Vector3).z-flat.y).length()-reach
			if d < least:
				least = d
				what = "%s %s" % [e.branch,e.kind]
	for t: Array in plan.tubes:
		var d := Vector2((t[0] as Vector3).x-flat.x,(t[0] as Vector3).z-flat.y).length()-float(t[1])-reach
		if d < least:
			least = d
			what = "a ride's tube"
	check(holds and least >= LayerSprawl.ROOST_GAP,"seed %d: the roost stands %.0f m clear of everything (nearest: %s; at least %.0f)" % [s,least,what,LayerSprawl.ROOST_GAP])
	# Off the exit side: from the gate, well off the heading.
	var gate: Vector3 = plan.exit.at
	var off_exit := rad_to_deg(acos(clampf(Vector2(at.x-gate.x,at.z-gate.z).normalized().dot(plan.heading),-1.0,1.0)))
	var spawn: Vector3 = plan.spawn.at
	check(off_exit >= LayerSprawl.ROOST_OFF_EXIT,"seed %d: the roost stands %.0f deg off the exit side from the gate (%s of the spawn, %.0f deg off its facing, seen from %d of %d neighbourhoods)" % [s,off_exit,
		LayerSprawl.compass(Vector2(at.x-spawn.x,at.z-spawn.z).normalized()),float(roost.view),int(roost.seen[0]),int(roost.seen[1])])
	check(LayerSprawl.sight_clear(plan,spawn+Vector3.UP*LayerSprawl.EYE,roost.mark,false),"seed %d: from the spawn's eye the roost's tower is in sight (planned)" % s)

## 4B-2: the gulfs rise, each neighbourhood higher than the last, 3+ isles
## in each and a climb onto an upper tier.
func _tall(s: int, plan: Dictionary) -> void:
	for gi: int in plan.gulfs:
		var e: Dictionary = plan.edges[gi]
		var least := minf(LayerSprawl.RISE_ROLL.x,float(e.width)*LayerPlan.GULF_GRADE)
		check(float(e.rise) >= least-0.01 and float(e.rise) <= LayerSprawl.RISE_ROLL.y+0.01,"seed %d: gulf %d->%d rises %.0f m over %.0f m" % [s,int(e.from[0]),int(e.to[0]),float(e.rise),float(e.width)])
	var hoods: Array = plan.hoods
	var tops: Array = []
	for h: Array in hoods:
		var sum := 0.0
		for i: int in h: sum += LayerPlan._top_walked(plan.isles[i])
		tops.append(sum/h.size())
	for h in range(1,hoods.size()):
		check(float(tops[h]) > float(tops[h-1])+HOOD_CLIMB,"seed %d: neighbourhood %d stands %.0f m over the last (its isles' highest walked, mean)" % [s,h,float(tops[h])-float(tops[h-1])])
	for h in range(hoods.size()):
		var isles: Array = hoods[h]
		var route: int = isles.filter(func(i: int) -> bool: return plan.isles[i].role != "greed").size()
		var climb := {}
		for e: Dictionary in plan.edges:
			if e.kind == "climb" and int(plan.isles[int(e.to[0])].hood) == h: climb = e
		var low := INF
		for i: int in isles: low = minf(low,LayerPlan._top_walked(plan.isles[i]))
		var up := -INF if climb.is_empty() else LayerPlan._top_walked(plan.isles[int(climb.to[0])])-low
		check(route >= 3 and not climb.is_empty() and up >= LayerSprawl.TIER-0.01,"seed %d: neighbourhood %d holds %d isles on the route and a climb (%s) onto one %.0f m over its lowest" % [s,h,route,
			"" if climb.is_empty() else ", ".join(PackedStringArray(climb.parts)),up])

## Laid on a worker, the next region waits (`dress` lays it once the layer
## stands); laid then, it is the same as laid at once.
func _later(s: int) -> void:
	var at_once := LayerSprawl.make(s)
	var seen := str(at_once.next.xform)
	LayerSprawl.forget()
	var out := {}
	var task := WorkerThreadPool.add_task(func() -> void: out.plan = LayerSprawl.make(s),true)
	WorkerThreadPool.wait_for_task_completion(task)
	var later: Dictionary = out.plan
	check((later.problems as Array).is_empty() and not later.has("next"),"seed %d: laid on a worker, its next region waits" % s)
	var placed := LayerSprawl._place_next(later,LayerSprawl.next_plan(later))
	check(str(placed.xform) == seen,"seed %d: laid later, its next region is the one laid at once (layer %d)" % [s,int(placed.seed)])

# --- A built layer --------------------------------------------------------------

func _sprawl_layer(s: int) -> void:
	var plan: Dictionary = study.layer
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var stood: int = plan.isles.size()-1+(1 if plan.has("roost") else 0)
	check(study.sky.motifs.all_stood() and study.sky.motifs.isles.size() == stood,"seed %d: its %d motif isles stand (the roost too)" % [s,stood])
	_roost_built(s,plan,space)
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
	# Driven across: the route, the greed branch and the chain on foot (not
	# the Broken Viaduct: its gust arrows and updrafts carry him over).
	var trap_n := 0
	for e: Dictionary in plan.edges:
		if e.kind in ["gulf","cannon","viaduct"]: continue
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

## Round 5: the roost built where it was laid, a ray from the start's eye
## meeting its tower first, his dragon asleep on its ledge.
func _roost_built(s: int, plan: Dictionary, space: PhysicsDirectSpaceState3D) -> void:
	var isle: Node3D = study._motif_isle(LayerSprawl.ROOST)
	check(isle != null and isle.stands(),"seed %d: the roost stands" % s)
	if isle == null: return
	print("layer sprawl test: seed %d: the roost's art built in %d ms; its dragon and air laid in %d ms" % [s,int(isle.motif.built_ms),int(study.roost_ms)])
	var eye: Vector3 = (study.start as Vector3)+Vector3.UP*LayerSprawl.EYE
	var mark: Vector3 = plan.roost.mark
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,mark,0xFFFFFFFF))
	var on := not hit.is_empty() and isle.is_ancestor_of(hit.collider as Node)
	check(on,"seed %d: from the start a ray meets the roost's tower %.0f m off%s" % [s,eye.distance_to(mark),
		" (missed)" if hit.is_empty() else ("" if on else " (%s at %s first)" % [(hit.collider as Node).get_path(),(hit.position as Vector3).round()])])
	# Shown once his mountain stands (the study's frame).
	study._roost_frame(1.0/60.0)
	var dragon: Node3D = study.roost_dragon
	var ledge := Vector3.INF
	var l2 := LayerSprawl.Roost.own(LayerSprawl.Roost.LEDGE_C)
	ledge = Vector3(l2.x,LayerSprawl.Roost.TOP+LayerSprawl.Roost.LEDGE_H*LayerSprawl.Roost.SPAN,l2.y)+(plan.roost.offset as Vector3)
	var away := dragon.global_position.distance_to(ledge) if dragon != null else INF
	check(dragon != null and dragon.visible and away < 60.0,"seed %d: his dragon lies on the roost's ledge (%.0f m from its middle)" % [s,away])

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
## next region of its own; the void ends the climb (scripts/roguelike/
## run_loop.gd: the dark, then the card, a new climb laid behind it).
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
	check(study.layer.has("roost") and study.roost_dragon != null,"And a dragon's roost of its own")
	var spawn: Vector3 = study.layer.spawn.at
	check(Vector2(m.feet.x-spawn.x,m.feet.z-spawn.z).length() < 1.0 and absf(m.feet.y-spawn.y) < 2.0,"He starts the new layer at its spawn (%s, the spawn %s)" % [_feet(),spawn.snapped(Vector3.ONE*0.01)])
	study.place(Vector3(m.feet.x,float(study.layer.void_y)+1.0,m.feet.z),Vector2(1.0,0.0))
	var loop: Node = study.run_loop
	for i in range(600):
		tick(Vector2.ZERO)
		if loop == null or loop.state == "card": break
	check(loop != null and loop.state == "card" and str(study.last_end).to_lower().contains("into the void"),"Into the void, the climb ends on its card (%s: %s)" % [loop.state if loop != null else "no run loop",study.last_end])
