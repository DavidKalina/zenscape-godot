extends SceneTree
## Loose grass chaff (scripts/wind_grass_chaff.gd): sparse, still in calm
## air, lifted and carried by a gust sooner than the heavier leaves, and
## settled again after; anchors only on grass.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	print(("ok   " if ok else "FAIL ") + message)
func run() -> void:
	var Chaff = load("res://scripts/wind_grass_chaff.gd")
	var air = load("res://studies/atmosphere.gd").new()
	var chaff = Chaff.new()
	var leaves = load("res://scripts/wind_leaf_litter.gd").new()
	root.add_child(air)
	root.add_child(chaff)
	root.add_child(leaves)
	air.strength = 0.0
	air._air_strength = 0.0
	var anchors: Array = Chaff.anchors_on(func(p: Vector2) -> float: return 1.0 if p.x > -4.0 else 0.0)
	check(anchors.size() == Chaff.CHAFF, "A meadow gives the full, sparse count: %d" % anchors.size())
	check(anchors.all(func(p: Vector2) -> bool: return p.x > -4.0), "Anchors only on grass")
	check(Chaff.anchors_on(func(_p: Vector2) -> float: return 0.0).is_empty(), "No grass, no chaff")
	check(Chaff.anchors_on(func(p: Vector2) -> float: return 1.0 if p.x > -4.0 else 0.0) == anchors, "The same ground gives the same anchors")
	var flat := func(_p: Vector2) -> float: return 0.0
	chaff.seed_from(anchors, flat)
	check(chaff.leaves.size() == Chaff.CHAFF and chaff.multimesh.visible_instance_count == Chaff.CHAFF, "Every anchor rests one blade")
	var start: Array = chaff.leaves.duplicate(true)
	for i in range(120): chaff.advance(1.0/60.0, false, air)
	var still := true
	for i in range(start.size()): still = still and chaff.leaves[i].position == start[i].position
	check(still, "Calm air keeps resting chaff still")
	# One shared gust: the chaff travels further than leaves under it.
	chaff.seed_from([Vector2.ZERO], flat)
	leaves.seed_from([Vector2.ZERO], flat)
	var chaff_from: Vector3 = chaff.leaves[0].position
	var leaf_from: Array = leaves.leaves.map(func(l: Dictionary) -> Vector3: return l.position)
	air.send_gust(Vector3.ZERO)
	var lifted := false
	for i in range(180):
		air.advance(1.0/60.0, false)
		chaff.advance(1.0/60.0, false, air)
		leaves.advance(1.0/60.0, false, air)
		lifted = lifted or chaff.leaves[0].airborne
	check(lifted, "A gust lifts the chaff")
	var leaf_travel := 0.0
	for i in range(leaves.leaves.size()): leaf_travel = maxf(leaf_travel, (leaves.leaves[i].position - leaf_from[i]).x)
	var chaff_travel: float = (chaff.leaves[0].position - chaff_from).x
	check(chaff_travel > 0.0, "The gust carries it downwind: %.2f m" % chaff_travel)
	check(chaff_travel > leaf_travel, "Lighter than a leaf, it goes further: %.2f m against %.2f m" % [chaff_travel, leaf_travel])
	air.puffs.parcels.fill(Vector4.ZERO)
	for i in range(360): chaff.advance(1.0/60.0, false, air)
	check(not chaff.leaves[0].airborne and is_equal_approx(chaff.leaves[0].position.y, 0.035), "It settles back on the ground")
	var paused: Array = chaff.leaves.duplicate(true)
	chaff.advance(10.0, true, air)
	check(chaff.leaves == paused, "Pause freezes it")
	print("leaf travel %.2f m, chaff travel %.2f m" % [leaf_travel, chaff_travel])
	chaff.free()
	leaves.free()
	air.free()
	print("WIND GRASS CHAFF: ", failures, " failures")
	quit(1 if failures else 0)
