extends SceneTree
## The floating mountain (scripts/cluster_mountain.gd, scripts/
## mountain_spire.gd): over SEEDS seeds its plans pass the validator and lay
## a real peak 30 to 60 m over its meadow with a snow line, a hut on its
## ledge, a trail up to it (never steeper than a walk, its bench under it,
## lanterns along it), the hut's star, and a cabin's islet at its feet
## reached by stepping stones; the bare crags carry no trail. Stood in the
## sky's islets (scripts/sky_clusters.gd), the peak is a solid to the glide
## up to its summit and hangs a deeper keel, the walker finds ground all
## the way up the trail, the peak draws its own faces (the islet's top
## leaves them out) and fades in, and at night the hut's star is lit.
const Solver = preload("res://scripts/cluster_solver.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyClusters = preload("res://scripts/sky_clusters.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const Spire = preload("res://scripts/mountain_spire.gd")
const SEEDS := 10
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _run() -> void:
	var bad := []
	var low := INF
	var high := -INF
	var steepest := 0.0
	var fewest_posts := 999
	var missing := []
	for s in range(SEEDS):
		var seed_value := 900+s*15485
		var plan := Solver.solve("mountain",seed_value)
		var problems := Solver.validate(plan)
		if not problems.is_empty(): bad.append("seed %d: %s" % [seed_value,problems[0]])
		var have := {}
		var posts := 0
		for m: Dictionary in plan.members:
			for f: Dictionary in m.features:
				have["%s:%s" % [m.role,f.type]] = true
				if m.role == "peak" and f.type == "post": posts += 1
			if m.role == "crag" and m.shape.spire != null and (m.shape.spire.trail as PackedVector3Array).size() > 0: missing.append("trail on a crag")
			if m.role != "peak": continue
			var spire: RefCounted = m.shape.spire
			if spire == null:
				missing.append("seed %d: no peak" % seed_value)
				continue
			var rise: float = spire.summit.y-float(m.shape.ground_at(spire.centre+spire.hut_out*spire.foot*1.2))
			low = minf(low,rise)
			high = maxf(high,rise)
			# Walked: the ground along the trail every 0.1 m.
			var trail: PackedVector3Array = spire.trail
			for k in range(trail.size()-1):
				var a := Vector2(trail[k].x,trail[k].z)
				var b := Vector2(trail[k+1].x,trail[k+1].z)
				var n := maxi(int(a.distance_to(b)/0.1),1)
				var last: float = m.shape.ground_at(a)
				for i in range(1,n+1):
					var g: float = m.shape.ground_at(a.lerp(b,float(i)/n))
					steepest = maxf(steepest,absf(g-last)/(a.distance_to(b)/n))
					last = g
		fewest_posts = mini(fewest_posts,posts)
		for want: String in ["peak:cabin","peak:star","peak:post","hold:cabin"]:
			if not have.has(want): missing.append("seed %d: %s" % [seed_value,want])
		if (plan.routes as Array).is_empty(): missing.append("seed %d: no stepping stones" % seed_value)
	check(bad.is_empty(),"mountain: %d seeds pass the validator%s" % [SEEDS,"" if bad.is_empty() else " (%d fail, e.g. %s)" % [bad.size(),bad[0]]])
	check(missing.is_empty(),"Every plan has its peak, hut, star, lanterns, cabin and stones%s" % ("" if missing.is_empty() else " (%s)" % str(missing.slice(0,3))))
	check(low >= 30.0*0.95 and high <= 60.0,"The peak stands 30 to 60 m over its meadow (%.1f to %.1f m)" % [low,high])
	check(steepest < 1.2,"The trail is walked without a wall (steepest %.2f over 0.1 m)" % steepest)
	check(fewest_posts >= 3,"Lanterns climb every trail (fewest %d)" % fewest_posts)
	# Stood in the sky.
	var cells := SkyCells.new([Vector3.ZERO,Vector3(380.0,-20.0,-160.0)])
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var field: Node3D = SkyClusters.new()
	field.islets = islets
	field.with_showcase = false
	field.with_random = false
	root.add_child(field)
	field.reset(cells)
	var at := Vector3(900.0,0.0,700.0)
	field.spots.append({"key":"mtn","at":at,"motif":"mountain","seed":4242})
	field.plan_now("mtn")
	var stood: Dictionary = field.members_of("mtn")
	check(stood.has("peak") and stood.has("hold"),"It stands: %s" % str(stood.keys()))
	var peak: Dictionary = stood.get("peak",{})
	if not peak.is_empty():
		var spire: RefCounted = peak.shape.spire
		var place: Vector3 = islets.place(peak)
		var over_summit := place+Vector3(spire.centre.x,spire.summit.y+5.0,spire.centre.y)
		var body: Variant = islets.body(over_summit)
		check(body is Vector2 and absf((body as Vector2).x-(place.y+spire.summit.y)) < 1.5,"The glide meets the summit as a solid (%s, summit %.1f)" % [str(body),place.y+spire.summit.y])
		var plain: RefCounted = SkyIslet.author(int(peak.shape.seed),{"kind":"meadow","radius":peak.shape.radius})
		var deepest := 0.0
		var plain_deepest := 0.0
		for k in peak.shape.keel: deepest = maxf(deepest,k)
		for k in plain.keel: plain_deepest = maxf(plain_deepest,k)
		check(deepest > plain_deepest+spire.height*0.3,"A deeper keel hangs under it (%.1f m against %.1f)" % [deepest,plain_deepest])
		var trail: PackedVector3Array = spire.trail
		var on := 0
		for k in range(0,trail.size(),4):
			var q := place+trail[k]
			if islets.islet_at(q) == peak and SkyIslets.ground(peak.shape,Vector2(trail[k].x,trail[k].z)) != null: on += 1
		check(on == (trail.size()+3)/4,"The walker finds the peak's ground all up the trail (%d of %d)" % [on,(trail.size()+3)/4])
		var node: Node3D = peak.node
		var spire_node := node.get_node_or_null("Spire") as MeshInstance3D
		check(spire_node != null and spire_node.mesh.get_surface_count() == 1,"The peak draws its own faces")
		check(node.get_node_or_null("TrailSteps") != null,"Steps are laid on the trail")
		var top: Array = peak.shape.top_arrays(SkyIslet.plain_palette())
		var count: int = (top[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var drawn := 0
		for f in peak.shape.land:
			if spire.drawn[f] != 0: drawn += 1
		check(drawn > 500 and count == ((peak.shape.land as PackedInt32Array).size()-drawn)*3,"The islet's top leaves the peak's %d faces out" % drawn)
		var snowy := false
		var uv: PackedVector2Array = spire_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		for v in uv:
			if v.x < 0.0: snowy = true
		check(snowy,"It wears a snow cap")
	# Night.
	field.daylight_override = 0.0
	for i in range(120):
		field.advance(1.0/30.0,at+cells.origin)
		await process_frame
	var star_lit := false
	if not peak.is_empty():
		for entry: Array in field.clusters["mtn"].live.lights:
			var light: OmniLight3D = entry[0]
			if light.visible and light.omni_range >= 10.0 and light.get_parent() == peak.node: star_lit = true
	check(star_lit,"At night the hut's window burns like a star")
	field.queue_free()
	islets.queue_free()
	await process_frame
	print("PASS: cluster mountain" if failures == 0 else "FAIL: cluster mountain")
	quit(1 if failures else 0)
