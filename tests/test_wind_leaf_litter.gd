extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var air = load("res://studies/atmosphere.gd").new()
	var litter = load("res://scripts/wind_leaf_litter.gd").new()
	root.add_child(air)
	root.add_child(litter)
	air.strength = 0.0
	air._air_strength = 0.0
	litter.seed_from([Vector2.ZERO],func(_p): return 0.0)
	var start: Array = litter.leaves.duplicate(true)
	for i in range(120): litter.advance(1.0/60.0,false,air)
	for i in range(start.size()): check(litter.leaves[i].position == start[i].position,"Calm air keeps grounded leaves still")
	air.send_gust(Vector3.ZERO)
	var lifted := false
	for i in range(180):
		air.advance(1.0/60.0,false)
		litter.advance(1.0/60.0,false,air)
		for leaf in litter.leaves: lifted = lifted or leaf.airborne
	check(lifted,"The shared traveling gust lifts leaves")
	check(litter.leaves[0].position.x > start[0].position.x,"Gust carries leaves downwind")
	var paused: Array = litter.leaves.duplicate(true)
	litter.advance(10.0,true,air)
	check(litter.leaves == paused,"Pause freezes the whole leaf state")
	air.puffs.parcels.fill(Vector4.ZERO)
	for i in range(360): litter.advance(1.0/60.0,false,air)
	for leaf in litter.leaves:
		check(not leaf.airborne and is_equal_approx(leaf.position.y,0.035),"Leaves settle back on the ground after gust")
	litter.seed_from([Vector2.ZERO],func(p): return p.x*0.25)
	for leaf in litter.leaves: check(leaf.normal.dot(Vector3(-0.25,1,0).normalized())>0.99,"Resting leaves conform to ground slope")
	litter.seed_from([Vector2.ZERO],func(_p): return null)
	check(litter.leaves.is_empty(),"Missing terrain or water creates no litter")
	var anchors: Array = []
	for i in range(1000): anchors.append(Vector2.ZERO)
	litter.seed_from(anchors,func(_p): return 0.0)
	check(litter.leaves.size()<=litter.CAPACITY,"Population is bounded")
	# A lifting breeze-ribbon sweep (a stub with a steady updraft over the leaf)
	# throws a resting leaf up, and it rises but tops out low.
	var stub := GDScript.new()
	stub.source_code = "extends Node3D\nfunc air_at(p: Vector3) -> Vector3:\n\treturn Vector3(2.0, 3.5, 0.0) if Vector2(p.x, p.z).length() < 6.0 else Vector3.ZERO\n"
	stub.reload()
	var trails: Node3D = stub.new()
	air.add_child(trails)
	air.strength = 0.0
	air._air_strength = 0.0
	air.puffs.parcels.fill(Vector4.ZERO)
	litter.seed_from([Vector2.ZERO],func(_p): return 0.0)
	var peak := 0.0
	for i in range(60): litter.advance(1.0/60.0,false,air)
	for leaf in litter.leaves: check(is_equal_approx(leaf.position.y,0.035) and not leaf.airborne,"No sweep wired in: leaves rest")
	air.wind_trails = trails
	for i in range(180):
		litter.advance(1.0/60.0,false,air)
		for leaf in litter.leaves: peak = maxf(peak,leaf.position.y)
	check(peak > 0.6,"A lifting sweep throws a leaf up: %.2f m" % peak)
	check(peak < 3.2,"A leaf tops out low in a sweep's updraft: %.2f m" % peak)
	air.wind_trails = null
	trails.free()
	litter.free()
	air.free()
	print("WIND LEAF LITTER: ",failures," failures")
	quit(1 if failures else 0)
