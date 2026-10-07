extends SceneTree
## The ravine (scripts/ravine_cut.gd, "ravine" in scripts/cluster_motifs.gd):
## one island torn in two. Over a few seeds: the two halves are cut from the
## same whole (one seed, one rock look) and stand where the whole puts them,
## the far one a little higher; their tear edges match tooth for tooth, the
## gap between them narrow at one end and wide enough at the other for the
## plane; the inner walls hang deep (the whole's rock); a rope bridge spans
## the gap; the near half's spring pours off the tear's lip into it; a
## broken-off chunk hangs in the gap below the rims; the lookout runs out
## over the gap; at night lanterns stand on both lips and the cabin is lit.
## Plans pass the validator, and a seed lays the same plan.
const Solver = preload("res://scripts/cluster_solver.gd")
const RavineCut = preload("res://scripts/ravine_cut.gd")
const Dresser = preload("res://scripts/cluster_dresser.gd")
const SEEDS := [11,2024,77731,904211]
var failures := 0

func _initialize() -> void:
	var a := Solver.solve("ravine",11)
	var b := Solver.solve("ravine",11)
	check(_signature(a) == _signature(b),"A seed lays the same ravine")
	for seed_value: int in SEEDS: _check_plan(Solver.solve("ravine",seed_value),seed_value)
	_check_dressing(a)
	print("PASS: ravine motif" if failures == 0 else "FAIL: ravine motif")
	quit(1 if failures else 0)

func _check_plan(plan: Dictionary, seed_value: int) -> void:
	var tag := "seed %d: " % seed_value
	var problems := Solver.validate(plan)
	check(problems.is_empty(),tag+"passes the validator%s" % ("" if problems.is_empty() else " (%s)" % problems[0]))
	check(plan.has("cleft"),tag+"lays the cleft")
	if not plan.has("cleft"): return
	var by := {}
	for m: Dictionary in plan.members: by[m.name] = m
	var near: Dictionary = by[plan.cleft.near]
	var far: Dictionary = by[plan.cleft.far]
	var tear: Dictionary = near.shape.recipe.tear
	var far_tear: Dictionary = far.shape.recipe.tear
	check(near.seed == far.seed and tear.knots == far_tear.knots and is_equal_approx(float(tear.angle),float(far_tear.angle))
		and near.shape.recipe.rock == far.shape.recipe.rock,tag+"both halves cut from one whole")
	var lift: float = far.offset.y-near.offset.y
	check(lift >= 0.7 and lift <= 2.0,tag+"the far half stands a little higher (%.2f m)" % lift)
	# The tear edges, walked along the tear: each half's edge found across
	# it; the gap they leave follows the tear's width, tooth for tooth.
	var origin: Vector3 = plan.cleft.origin
	var way := RavineCut.across(tear)
	var worst := 0.0
	var narrow := INF
	var wide := 0.0
	var samples := 0
	for k in range(41):
		var s := RavineCut.share_s(tear,lerpf(-0.7,0.7,k/40.0))
		var mid := RavineCut.middle_at(tear,s)
		var e_near := _edge(near,origin,mid,-way)
		var e_far := _edge(far,origin,mid,way)
		# Past where the tear meets the coast a ray finds the coast, not the wall.
		var half_gap := RavineCut.width(tear,s)*0.5+2.5
		if e_near > half_gap or e_far > half_gap: continue
		samples += 1
		var gap := e_near+e_far
		worst = maxf(worst,absf(gap-RavineCut.width(tear,s)))
		narrow = minf(narrow,gap)
		wide = maxf(wide,gap)
	check(samples >= 25,tag+"both halves run along the tear (%d of 41 samples)" % samples)
	check(worst < 1.6,tag+"the halves' tear edges match (gap off the tear's width by %.2f m at most)" % worst)
	check(narrow < 6.0 and wide > 11.0,tag+"the gap narrow at one end, wide at the other (%.1f to %.1f m)" % [narrow,wide])
	# The inner walls hang deep: the whole's rock under the tear.
	for half: Dictionary in [near,far]:
		var shape: RefCounted = half.shape
		var deepest := 0.0
		var tear_edges := 0
		for e in range(shape.cleft.edges.size()):
			if shape.cleft.edges[e] == 0: continue
			tear_edges += 1
			deepest = maxf(deepest,shape.keel[shape.shore_edges[e*3]])
		check(tear_edges > 40 and deepest > 8.0,tag+"%s's inner wall: %d tear edges, hanging %.1f m under its foot" % [half.name,tear_edges,deepest])
	var sides: Array = near.shape.side_arrays()
	check((sides[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0,tag+"the near half's sides build with its inner wall")
	# The bridge across the gap.
	var bridged := false
	for br: Dictionary in plan.bridges:
		if br.from == near.name and br.to == far.name: bridged = true
	check(bridged,tag+"a rope bridge spans the gap")
	# The fall: the near half's spring leaves over the tear's lip, toward the far half.
	var water: Dictionary = near.shape.water()
	var into_gap := false
	if not water.is_empty():
		var lip: Vector2 = water.lip
		into_gap = (water.out as Vector2).dot(way) > 0.4 and RavineCut.margin(tear,lip+near.shape.cleft.middle,-1.0) < 0.8
	check(into_gap,tag+"the near half's stream falls into the gap")
	# The chunk hangs in the gap, under the rims.
	var chunk: Dictionary = by.get("chunk",{})
	var hangs := false
	if not chunk.is_empty():
		var at: Vector3 = chunk.offset-origin
		var p := Vector2(at.x,at.z)
		hangs = RavineCut.margin(tear,p,-1.0) < 0.0 and RavineCut.margin(tear,p,1.0) < 0.0 and chunk.offset.y < near.offset.y-5.0
	check(hangs,tag+"a broken-off chunk hangs in the gap below the rims")
	# The lookout runs out over the gap from the far half.
	var lookout := false
	for f: Dictionary in far.features:
		if f.get("lookout",false):
			var end: Vector3 = f.b
			lookout = not far.shape.on_land(Vector2(end.x,end.z))
	check(lookout,tag+"the lookout runs out over the gap")
	# Night: lanterns on both lips, the cabin on the near half.
	var posts := {}
	var cabin := false
	for half: Dictionary in [near,far]:
		for f: Dictionary in half.features:
			if f.type == "post": posts[half.name] = int(posts.get(half.name,0))+1
			if f.type == "cabin": cabin = true
	check(int(posts.get(near.name,0)) >= 2 and int(posts.get(far.name,0)) >= 2 and cabin,tag+"lanterns on both lips (%d, %d) and a cabin" % [posts.get(near.name,0),posts.get(far.name,0)])

## How far (m) from the gap's middle line at `mid` (the whole's frame)
## along `way` the member's land begins; INF if not within 12 m.
func _edge(member: Dictionary, origin: Vector3, mid: Vector2, way: Vector2) -> float:
	var off := Vector2(member.offset.x-origin.x,member.offset.z-origin.z)
	for k in range(120):
		var d := k*0.1
		if member.shape.on_land(mid+way*d-off): return d
	return INF

## The lights stand: the lookout's mesh and lantern, the lip lanterns, the
## lit cabin.
func _check_dressing(plan: Dictionary) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var lights := 0
	var lookout := false
	for m: Dictionary in plan.members:
		var made := Dresser.prepare(m,plan)
		var node := Node3D.new()
		holder.add_child(node)
		var live := Dresser.furnish(node,m,plan,made)
		lights += (live.lights as Array).size()
		for i in range(m.features.size()):
			if m.features[i].get("lookout",false): lookout = made.features.get(i) is ArrayMesh
	check(lookout,"The lookout's mesh is made")
	check(lights >= 8,"The ravine's night lights stand (%d)" % lights)
	holder.queue_free()
	Dresser.release()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _signature(plan: Dictionary) -> String:
	var parts := []
	for m: Dictionary in plan.members: parts.append("%s %s %d %d" % [m.name,str((m.offset as Vector3).snapped(Vector3.ONE*0.01)),m.features.size(),(m.shape.objects as Array).size()])
	return "|".join(parts)
