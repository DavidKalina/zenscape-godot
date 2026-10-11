extends SceneTree
## The aqueduct isle's ring and what it sets rising timed (docs/design/
## isle-hall-line.md, isle-hall-chain.md), headless: for cruise and boost,
## the plane flies straight at the ring from 600 m out, threads it, then
## the autopilot flies on through PIECES pieces of the Sundered line (or
## halls, with --chain-style=halls). For the ring and each piece it prints
## when it was set rising (s after the start of the run), how long it took
## from then until it was still (a hall: its gate), how long until the
## plane got there (a piece: its entry), and the margin (positive: still
## before the plane arrived); for a piece also how the line came into it
## (gap, jog, bend) and its main-thread cost (all of it, its heaviest
## frame, its hand-over with its island, its heaviest body) and the
## worker's build. It flies in real time (a physics frame a step), as the
## real pieces are built on a worker as in play, and gives the heaviest
## frame's process and physics time once the line is up.
##   godot --headless --path . -s tools/isle_chain_timings.gd [-- <isle flags>]
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")
const DT := 1.0/60.0
const PIECES := 6

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
	var line: bool = c.style == "line"
	var want := PIECES if line else 3
	s.fly_from(c.ring_at-_ahead(c.ring_heading)*600.0,c.ring_heading)
	var t := 0.0
	var ring := {"woke":-1.0,"still":-1.0,"there":-1.0,"woke_m":0.0}
	var halls := {}
	var at := -1
	var speeds := PackedFloat32Array()
	var bumps0: int = s.bumps
	var worst_frame := 0.0
	while t < 150.0 and not _done(halls,want):
		var input := {"boost":boost}
		if c.state in ["passed","started"] and not c.chain.halls.is_empty():
			if at < 0: at = c.chain.route_base
			var got: Array = c.chain.steer(s.plane,at)
			at = got[1]
			input = got[0]
			input.boost = boost
		s.fly_step(DT,input)
		t += DT
		await physics_frame
		if c.state in ["passed","started"]: worst_frame = maxf(worst_frame,(Performance.get_monitor(Performance.TIME_PROCESS)+Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.0)
		speeds.append(float(s.plane.speed))
		if ring.woke < 0.0 and c.state != "hidden":
			ring.woke = t
			ring.woke_m = s.plane.position.distance_to(c.ring_at)
		if ring.still < 0.0 and c.state in ["standing","passed","started"]: ring.still = t
		if ring.there < 0.0 and c.state in ["passed","started"]: ring.there = t
		for h: Dictionary in c.chain.halls:
			var i := int(h.index)
			if not halls.has(i): halls[i] = {"set":t,"still":-1.0,"there":-1.0,"kind":str(h.pose.get("kind","")),"gap":float(h.pose.get("gap",0.0))}
			var rec: Dictionary = halls[i]
			var rise: Node3D = h.rise
			var g: int = rise.chunks.size()-1
			if float(rec.still) < 0.0 and rise.state[g] in ["pending","set"]: rec.still = t
			if float(rec.there) >= 0.0: continue
			if line:
				if bool(h.reached): rec.there = t
			else:
				var local: Vector3 = ChainPlan.local(rise.to_local(s.plane.position),ChainPlan.hand_of(h.pose))
				if local.distance_to(ChainPlan.line()[0]) < 8.0: rec.there = t
	var mean := 0.0
	for v in speeds: mean += v
	mean /= maxf(speeds.size(),1)
	print("== %s (mean %.1f m/s), %s, %d bumps" % ["boost" if boost > 0.0 else "cruise",mean,c.style,s.bumps-bumps0])
	print("ring: woke %.0f m out; up and still %.1f s after waking, plane there %.1f s after; margin %+.1f s" % [ring.woke_m,ring.still-ring.woke,ring.there-ring.woke,ring.there-ring.still])
	for i in range(mini(halls.size(),want)):
		var rec: Dictionary = halls[i]
		var from: float = ring.there if i == 0 else float(rec.set)
		var what := ("piece %d" if line else "hall %d") % i
		what += " (from threading)" if i == 0 else " (from its trigger)"
		if line and i > 0: what += " after a %s of %.0f m" % [rec.kind,float(rec.gap)]
		var cost := ""
		if line:
			for sp: Dictionary in c.chain.spawns:
				if int(sp.index) == i:
					cost = ", main thread %.2f ms (heaviest frame %.2f ms: hand-over %.2f, a body %.2f), build %.0f ms, %d hulls, %d triangles" % [int(sp.total)/1000.0,int(sp.frame)/1000.0,
						(int(sp.setup)+int(sp.take))/1000.0,int(sp.get("bodies",0))/1000.0,int(sp.get("build",0))/1000.0,int(sp.get("hulls",0)),int(sp.get("triangles",0))]
		print("%s: still %.1f s, plane there %.1f s; margin %+.1f s%s" % [what,float(rec.still)-from,float(rec.there)-from,float(rec.there)-float(rec.still),cost])
	print("heaviest frame once the line is up (process + physics, headless): %.2f ms" % worst_frame)
	s.queue_free()
	await process_frame

func _done(halls: Dictionary, n: int) -> bool:
	for i in range(n):
		if not halls.has(i) or float(halls[i].there) < 0.0 or float(halls[i].still) < 0.0: return false
	return true
