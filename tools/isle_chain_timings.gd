extends SceneTree
## The aqueduct isle's ring and hall chain timed (docs/design/
## isle-hall-chain.md), headless: for cruise and boost, the plane flies
## straight at the ring from 600 m out, threads it, then the chain's
## autopilot flies on through three halls. For the ring and each hall it
## prints when it was set rising (s after the start of the run), how long
## it took from then until its gate was still, how long until the plane
## got there, and the margin (positive: still before the plane arrived).
##   godot --headless --path . -s tools/isle_chain_timings.gd [-- <isle flags>]
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")
const DT := 1.0/60.0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for boost in [0.0,1.0]:
		await _measure(boost)
	quit(0)

func _ahead(h: float) -> Vector3:
	return Vector3(-sin(h),0.0,-cos(h))

func _measure(boost: float) -> void:
	var s: Node3D = load("res://studies/aqueduct_isle.tscn").instantiate()
	s.scripted = true
	s._carry = true
	root.add_child(s)
	current_scene = s
	while not s.flora_ready: await process_frame
	await physics_frame
	s.board()
	var c: Node3D = s.isle_chain
	s.fly_from(c.ring_at-_ahead(c.ring_heading)*600.0,c.ring_heading)
	var t := 0.0
	var ring := {"woke":-1.0,"still":-1.0,"there":-1.0,"woke_m":0.0}
	var halls := {}
	var at := -1
	var speeds := PackedFloat32Array()
	while t < 120.0 and not _done(halls,3):
		var input := {"boost":boost}
		if c.state in ["passed","started"] and not c.chain.halls.is_empty():
			if at < 0: at = c.chain.route_base
			var got: Array = c.chain.steer(s.plane,at)
			at = got[1]
			input = got[0]
			input.boost = boost
		s.fly_step(DT,input)
		t += DT
		speeds.append(float(s.plane.speed))
		if ring.woke < 0.0 and c.state != "hidden":
			ring.woke = t
			ring.woke_m = s.plane.position.distance_to(c.ring_at)
		if ring.still < 0.0 and c.state in ["standing","passed","started"]: ring.still = t
		if ring.there < 0.0 and c.state in ["passed","started"]: ring.there = t
		for h: Dictionary in c.chain.halls:
			var i := int(h.index)
			if not halls.has(i): halls[i] = {"set":t,"still":-1.0,"there":-1.0}
			var rec: Dictionary = halls[i]
			var rise: Node3D = h.rise
			var g: int = rise.chunks.size()-1
			if float(rec.still) < 0.0 and rise.state[g] in ["pending","set"]: rec.still = t
			var local: Vector3 = ChainPlan.local(rise.to_local(s.plane.position),ChainPlan.hand_of(h.pose))
			if float(rec.there) < 0.0 and local.distance_to(ChainPlan.line()[0]) < 8.0: rec.there = t
	var mean := 0.0
	for v in speeds: mean += v
	mean /= maxf(speeds.size(),1)
	print("== %s (mean %.1f m/s)" % ["boost" if boost > 0.0 else "cruise",mean])
	print("ring: woke %.0f m out; up and still %.1f s after waking, plane there %.1f s after; margin %+.1f s" % [ring.woke_m,ring.still-ring.woke,ring.there-ring.woke,ring.there-ring.still])
	for i in range(mini(halls.size(),3)):
		var rec: Dictionary = halls[i]
		var from: float = ring.there if i == 0 else float(rec.set)
		var what := "hall %d (from threading)" % i if i == 0 else "hall %d (from its trigger)" % i
		print("%s: gate still %.1f s, plane at gate %.1f s; margin %+.1f s" % [what,float(rec.still)-from,float(rec.there)-from,float(rec.there)-float(rec.still)])
	s.queue_free()
	await process_frame

func _done(halls: Dictionary, n: int) -> bool:
	for i in range(n):
		if not halls.has(i) or float(halls[i].there) < 0.0 or float(halls[i].still) < 0.0: return false
	return true
