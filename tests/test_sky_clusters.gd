extends SceneTree
## The sky's clusters (scripts/sky_clusters.gd): rare, one to a cell at
## most, clear of the islands, the seeded islets kept off them; planned on a
## worker and stood member by member as fixed, grouped records in the
## islets' own (solids to the glide, never let go by the islets' streaming);
## the showcase stands whole at its spot; at night their lights come on and
## the lighthouse's beams sweep; past FORGET a cluster goes.
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyClusters = preload("res://scripts/sky_clusters.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _run() -> void:
	var cells := SkyCells.new([Vector3.ZERO,Vector3(380.0,-20.0,-160.0)])
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var field: Node3D = SkyClusters.new()
	field.islets = islets
	field.with_showcase = true
	field.with_random = true
	root.add_child(field)
	field.reset(cells)
	var random := (field.spots as Array).filter(func(s: Dictionary) -> bool: return s.key != "showcase")
	print("  %d random clusters in the world" % random.size())
	check(random.size() >= 4 and random.size() <= 40,"Clusters are rare: %d over the world" % random.size())
	var near_island := false
	var closest := INF
	for i in range(random.size()):
		var s: Dictionary = random[i]
		if not cells.spots_near(s.at,SkyClusters.ISLAND_CLEAR).is_empty(): near_island = true
		for j in range(i+1,random.size()): closest = minf(closest,Vector2(s.at.x-random[j].at.x,s.at.z-random[j].at.z).length())
	check(not near_island,"None stands by an island's spot")
	check(closest > SkyClusters.SPACING*0.35,"Open sky between them (closest two %.0f m apart)" % closest)
	var motifs := {}
	for s: Dictionary in random: motifs[s.motif] = true
	check(motifs.size() >= 2,"More than one motif turns up (%s)" % str(motifs.keys()))
	# Every motif forced near the home (--motifs-near-home): one each, in
	# reach of the home, apart, clear of the islands and of the showcase.
	var names: Array = SkyClusters.Motifs.names()
	var near: Array = field.near_spots(names,SkyClusters.NEAR_SEED,[{"at":SkyClusters.SHOWCASE_AT}])
	var near_ok := near.size() == names.size()
	var farthest := 0.0
	for i in range(near.size()):
		var at: Vector3 = near[i].at
		farthest = maxf(farthest,Vector2(at.x,at.z).length())
		if not cells.spots_near(at,SkyClusters.NEAR_ISLAND).is_empty(): near_ok = false
		if Vector2(at.x-SkyClusters.SHOWCASE_AT.x,at.z-SkyClusters.SHOWCASE_AT.z).length() < SkyClusters.NEAR_GAP: near_ok = false
		for j in range(i+1,near.size()):
			if Vector2(at.x-near[j].at.x,at.z-near[j].at.z).length() < SkyClusters.NEAR_GAP: near_ok = false
	check(near_ok and farthest < 700.0,"Every motif stands near the home, apart and clear (%d, farthest %.0f m)" % [near.size(),farthest])
	var forced: Node3D = SkyClusters.new()
	forced.islets = islets
	forced.with_near = ["mountain","lake"]
	forced.with_random = true
	root.add_child(forced)
	forced.reset(cells)
	var keys: Array = (forced.spots as Array).map(func(s: Dictionary) -> String: return s.key)
	var forced_at: Array = (forced.spots as Array).filter(func(s: Dictionary) -> bool: return str(s.key).begins_with("near:"))
	var crowded := (forced.spots as Array).any(func(s: Dictionary) -> bool: return not str(s.key).begins_with("near:") and forced_at.any(func(f: Dictionary) -> bool: return Vector2(s.at.x-f.at.x,s.at.z-f.at.z).length() < SkyClusters.SPACING*0.5))
	check("near:mountain" in keys and "near:lake" in keys and keys.size() > 2 and not crowded,"--motif stands its motifs near the home, the random ones as ever")
	forced.queue_free()
	# The showcase, stood.
	field.plan_now("showcase")
	var stood: Dictionary = field.members_of("showcase")
	check(stood.size() == 9,"The showcase stands whole (%d members)" % stood.size())
	var fixed := true
	var group := ""
	for b: Dictionary in stood.values():
		if not b.get("fixed",false): fixed = false
		if group == "": group = b.group
		elif b.group != group: fixed = false
	check(fixed,"Its members are fixed, one group")
	var lead: Dictionary = stood.get("lead",{})
	check(not lead.is_empty() and islets.body(islets.place(lead)+Vector3.UP*30.0) is Vector2,"The glide reads its members as solids")
	# Seeded islets keep off it.
	for i in range(60):
		islets.advance(1.0/60.0,SkyClusters.SHOWCASE_AT)
		islets.flush()
	var crowding := false
	for key: String in islets.built:
		if key.begins_with("cluster:"): continue
		var home: Vector3 = islets.built[key].home
		if Vector2(home.x-SkyClusters.SHOWCASE_AT.x,home.z-SkyClusters.SHOWCASE_AT.z).length() < SkyClusters.KEEP: crowding = true
	check(not crowding,"No seeded islet stands in its room")
	# Streamed: the eye by a random cluster plans it, nearest first.
	var target: Dictionary = random[0]
	for i in range(240):
		field.advance(1.0/60.0,target.at+cells.origin)
		if not field.members_of(target.key).is_empty() and (field.clusters[target.key].waiting as Array).is_empty() and int(field.clusters[target.key].task) < 0: break
		await process_frame
	check(not field.members_of(target.key).is_empty(),"Flown near, a cluster plans and stands (%s, %d members)" % [target.motif,field.members_of(target.key).size()])
	# Night.
	field.daylight_override = 0.0
	for i in range(200):
		field.advance(1.0/30.0,target.at+cells.origin)
		await process_frame
	check(field.night > 0.9,"At night they are lit (%.2f)" % field.night)
	var lit := 0
	for key in field.clusters:
		for entry: Array in field.clusters[key].live.lights:
			if (entry[0] as OmniLight3D).visible: lit += 1
	check(lit > 0,"Their lights are on (%d)" % lit)
	# Far off, they go; the islets' streaming never takes them.
	for i in range(30):
		field.advance(CHECK_STEP,Vector3(5000.0,0.0,5000.0)+cells.origin)
	check(field.members_of(target.key).is_empty(),"Past FORGET a cluster goes")
	check(not islets.built.keys().any(func(k: String) -> bool: return k.begins_with("cluster:"+str(target.key)+":")),"And its records with it")
	field.queue_free()
	islets.queue_free()
	await process_frame
	print("PASS: sky clusters" if failures == 0 else "FAIL: sky clusters")
	quit(1 if failures else 0)

const CHECK_STEP := 0.6
