extends SceneTree
## The Broken Ring (studies/broken_ring_isle.tscn), headless: the isle builds
## within its triangle budget; its eight small isles stand round the central
## one, 60-75 m across, 20+ m from the lowest to the highest, each with its
## own ruin note; the central isle carries a stone circle (two stones
## missing) round a turret; the spiral on foot is connected from the lowest
## isle to the highest, every hop driven as a player would (a rope bridge
## walked, floating stones hopped, a jump over a 2.7 m gap), the central
## isle's bridge walked, the break in the ring not crossable on foot; the
## foot tokens up the spiral and the plane's line.
##   godot --headless --path . --script tests/test_broken_ring_isle.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Ring = preload("res://studies/broken_ring_isle_art.gd")
const DT := 1.0/60.0
## The most triangles the isle may draw (about the other motifs').
const BUDGET := 400000
## The jump the pilot clears (m, rim to rim).
const JUMP_GAP := 3.2
var failures := 0
var study: Node3D
var m: PilotMotor
var debug := OS.has_environment("BR_DEBUG")

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(500.0).timeout.connect(func() -> void: push_error("broken ring test timed out"); quit(2))
	study = load("res://studies/broken_ring_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	var tris: int = study.triangles(study.art)
	check(tris > 0 and tris < BUDGET,"The isle draws %d triangles (budget %d)" % [tris,BUDGET])
	_layout()
	_pieces()
	_gaps()
	_start_stands()
	_spiral()
	_centre()
	_platforms_true()
	_tokens()
	print("PASS: broken ring" if failures == 0 else "FAIL: broken ring (%d)" % failures)
	quit(1 if failures else 0)

# --- Driving ---------------------------------------------------------------------------

func tick(want: Vector2, jump := false, crouch := false, twirl := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.script_twirl = twirl
	study.tick(DT)

func settle(at: Vector3, face: Vector2) -> void:
	study.place(at,face)
	for i in range(20): tick(Vector2.ZERO)

func flat(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)

func ahead(way: Vector2, reach := 0.7) -> float:
	return study.ground.ground(flat(m.feet)+way*reach)

func feet() -> String:
	return "feet %s" % m.feet

## Walked through `points` (world x, z) with the stick only: {ok, fell, reached}.
func walk_only(points: Array, frames := 6000) -> Dictionary:
	var i := 0
	var air := 0
	var fell := 0
	for f in range(frames):
		var to: Vector2 = points[i]
		var off: Vector2 = to-flat(m.feet)
		if off.length() < (0.5 if i == points.size()-1 else 1.0):
			i += 1
			if i >= points.size(): break
			continue
		tick(off.normalized())
		air = 0 if m.grounded else air+1
		if air == 15: fell += 1
		if m.on_ledge(): fell += 1
		if m.feet.y < Ring.W-20.0: break
	return {"ok":i >= points.size() and m.grounded,"fell":fell,"reached":i}

## A jump from where he stands (or `from`) to `to` (a top's middle): run at
## it, jump at the edge (or the rise), hold it rising; true landed on it.
func leap(to: Vector3, tech := "jump", from := Vector3.INF, speed := 1.0) -> bool:
	var target := Vector2(to.x,to.z)
	if from != Vector3.INF: settle(from,(target-Vector2(from.x,from.z)).normalized())
	var jumped := false
	for i in range(600):
		var off := target-flat(m.feet)
		var way := off.normalized() if off.length() > 0.05 else Vector2.ZERO
		var edge: bool = m.grounded and ahead(way,0.35) < m.feet.y-0.45
		var wall: bool = m.grounded and ahead(way,0.6) > m.feet.y+0.45
		var close: bool = m.grounded and off.length() < 1.9 and (absf(to.y-m.feet.y) > 0.2 or ahead(way,0.6) < m.feet.y-0.25)
		var jump := not jumped and (edge or wall or close)
		jump = jump or (jumped and not m.grounded and m.velocity.y > 0.0) or (m.on_ledge() and i%20 < 3)
		jumped = jumped or jump
		tick(way*(0.0 if off.length() < 0.2 and m.grounded else speed),jump)
		if m.feet.y < Ring.W-20.0:
			if debug: print("  leap to %s fell at %s" % [to,m.feet])
			return false
		if debug and i%6 == 0 and i < 120: print("    %s g %s j %s v %s" % [m.feet,m.grounded,jumped,m.velocity])
		if jumped and m.grounded and not m.on_ledge() and absf(m.feet.y-to.y) < 0.15 and off.length() < 1.2: return true
	if debug: print("  leap to %s failed: %s grounded %s ledge %s move %s v %s" % [to,m.feet,m.grounded,m.on_ledge(),m.move,m.velocity])
	return false

# --- The layout ----------------------------------------------------------------------

func _layout() -> void:
	var sats: Array = Ring.sats()
	check(sats.size() == 8 and study.isles.size() == 8,"Eight satellite isles stand round the central one (%d built)" % study.isles.size())
	var lo := INF
	var hi := -INF
	var x0 := INF
	var x1 := -INF
	var z0 := INF
	var z1 := -INF
	var radii_ok := true
	for s: Dictionary in sats:
		lo = minf(lo,float(s.top))
		hi = maxf(hi,float(s.top))
		var c: Vector2 = s.c
		x0 = minf(x0,c.x-float(s.r))
		x1 = maxf(x1,c.x+float(s.r))
		z0 = minf(z0,c.y-float(s.r))
		z1 = maxf(z1,c.y+float(s.r))
		radii_ok = radii_ok and float(s.r) >= 6.0 and float(s.r) <= 9.0
	var span := maxf(x1-x0,z1-z0)
	check(radii_ok,"Each satellite is a small isle, 6-9 m in radius")
	check(span >= 60.0 and span <= 75.0,"The ring spans %.0f m (60-75)" % span)
	check(hi-lo >= 20.0 and hi-lo <= 25.0,"The ring climbs %.1f m from the lowest isle to the highest (20-25)" % (hi-lo))
	var tops := sats.map(func(s: Dictionary) -> float: return float(s.top))
	var sorted := tops.duplicate()
	sorted.sort()
	check(tops == sorted,"The isles climb in order round the spiral (%s)" % str(tops))
	# The break: no two ends of the spiral near enough to cross.
	var first: Dictionary = sats[0]
	var last: Dictionary = sats[7]
	var gap := (first.c as Vector2).distance_to(last.c)-float(first.r)-float(last.r)
	check(gap > 6.0,"The ring is broken: %.1f m of sky between the last isle and the first" % gap)

func _pieces() -> void:
	var notes := {}
	for n: Array in Ring.notes(): notes[n[0]] = true
	check(notes.size() >= 7,"The satellites carry different ruin notes (%s)" % ", ".join(notes.keys()))
	var ring: Dictionary = study.circle.get_meta("ring")
	check((ring.missing as Array).size() == 2 and (study.circle.get_meta("ring").gone as Array).size() > 0,"The central stone circle has stones missing (%s)" % str(ring.missing))
	check(study.turret != null and study.turret.is_inside_tree(),"A broken turret stands in the circle")

## The rim-to-rim sky between two isles, read off the turf by rays along
## their line.
func rim_gap(i: int, j: int) -> float:
	var a: Dictionary = Ring.sat(i)
	var b: Dictionary = Ring.sat(j)
	var ca: Vector2 = a.c
	var cb: Vector2 = b.c
	var dir := (cb-ca).normalized()
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var step := 0.1
	var total := ca.distance_to(cb)
	var edge_a := 0.0
	while edge_a < total and _turf_at(space,ca+dir*edge_a,float(a.top)): edge_a += step
	var edge_b := total
	while edge_b > 0.0 and _turf_at(space,ca+dir*edge_b,float(b.top)): edge_b -= step
	return edge_b-edge_a

func _turf_at(space: PhysicsDirectSpaceState3D, p: Vector2, y: float) -> bool:
	var q := PhysicsRayQueryParameters3D.new()
	q.from = Vector3(p.x,y+3.0,p.y)
	q.to = Vector3(p.x,y-3.0,p.y)
	q.collision_mask = study.TURF_LAYER
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and absf((hit.position as Vector3).y-y) < 1.0

func _gaps() -> void:
	for hop: Array in Ring.HOPS:
		var g := rim_gap(int(hop[0]),int(hop[1]))
		match str(hop[2]):
			"jump": check(g > 1.0 and g < JUMP_GAP,"Hop %d-%d: a jump-only gap of %.1f m (under %.1f)" % [hop[0],hop[1],g,JUMP_GAP])
			_: check(g > 4.0,"Hop %d-%d (%s): %.1f m of sky, past a jump" % [hop[0],hop[1],hop[2],g])

# --- The spiral on foot ----------------------------------------------------------------

func _start_stands() -> void:
	study.respawn()
	for i in range(40): tick(Vector2.ZERO)
	var s0 := Ring.sat(0)
	check(m.grounded and absf(m.feet.y-(float(s0.top)+Ring.SWELL*0.3)) < 0.8 and flat(m.feet).distance_to(s0.c) < float(s0.r),"Start: he stands on the lowest isle (%s)" % feet())

## From the lowest isle up the whole ring: each hop driven, every landing on
## the next isle, then walked on to the next hop's start.
func _spiral() -> void:
	var ok := true
	var at := 0
	for hop: Array in Ring.HOPS:
		var from: int = hop[0]
		var to: int = hop[1]
		var ends := Ring.hop_ends(from,to)
		var a: Vector2 = ends[0]
		var b: Vector2 = ends[1]
		var sb := Ring.sat(to)
		var dir := (b-a).normalized()
		# On to the hop's start across the isle, walked; then the hop itself.
		var sa := Ring.sat(from)
		var launch: Vector2 = (sa.c as Vector2)+dir*float(sa.r)*0.8
		var how := str(hop[2])
		var start_at: Vector2 = a-dir*0.6 if how == "bridge" else launch
		var walked := walk_only([start_at])
		check(walked.ok and walked.fell == 0,"Spiral: across isle %d to the start of its hop (%s)" % [from,feet()])
		var landed := false
		match how:
			"bridge":
				walked = walk_only([a+dir*0.3,b+dir*1.2],3000)
				landed = walked.ok and walked.fell == 0 and flat(m.feet).distance_to(Ring.sat(to).c) < float(sb.r)
			"stones":
				landed = true
				var stones: Array = Ring.platforms().filter(func(p: Dictionary) -> bool: return p.chain == "stones_%d_%d" % [from,to])
				for p: Dictionary in stones:
					landed = landed and leap(p.at)
					if debug: print("  stone %s %s -> %s" % [p.name,p.at,landed])
				var far := (sb.c as Vector2)-dir*float(sb.r)*0.6
				landed = landed and leap(Vector3(far.x,Ring.sat_ground(sb,far.x,far.y),far.y))
			"jump":
				var far := (sb.c as Vector2)-dir*float(sb.r)*0.55
				landed = leap(Vector3(far.x,Ring.sat_ground(sb,far.x,far.y),far.y))
		var on_it := flat(m.feet).distance_to(sb.c) < float(sb.r) and absf(m.feet.y-float(sb.top)) < 1.0
		check(landed and on_it,"Spiral: isle %d to %d by %s, onto its turf at %.1f m (%s)" % [from,to,how,float(sb.top),feet()])
		ok = ok and landed and on_it
		if not ok: break
		at = to
	var top_isle := Ring.sat(7)
	var walked_up := walk_only([top_isle.c])
	check(ok and walked_up.ok,"Spiral: on to the middle of the highest isle (%s)" % feet())
	check(ok and at == 7 and m.feet.y > float(Ring.sat(0).top)+19.0,"Spiral: the whole ring climbed on foot to the highest isle, %.1f m over the lowest" % (m.feet.y-float(Ring.sat(0).top)))

## The central isle: its bridge walked from the fourth isle onto the
## circle's floor; the break not crossable (the lowest isle's edge is nowhere
## near a jump of the last's).
func _centre() -> void:
	var br: Dictionary = {}
	for b: Dictionary in Ring.bridges():
		if b.name == "bridge_centre": br = b
	var a: Vector3 = br.a
	var e: Vector3 = br.b
	var dir := Vector2(e.x-a.x,e.z-a.z).normalized()
	var span := Vector2(e.x-a.x,e.z-a.z).length()
	settle(a-Vector3(dir.x,0.0,dir.y)*0.9,dir)
	var walked := walk_only([Vector2(e.x,e.z)+dir*1.2])
	var there: bool = walked.ok and walked.fell == 0 and absf(m.feet.y-e.y) < 0.2
	walked = walk_only([Vector2(a.x,a.z)-dir*1.2])
	var back: bool = walked.ok and walked.fell == 0 and absf(m.feet.y-a.y) < 0.2
	check(there and back and span > 6.0,"Centre: the %.1f m rope bridge walked onto the central isle and back (%s)" % [span,feet()])
	walked = walk_only([Vector2(e.x,e.z)+dir*1.2,Ring.C+dir*3.0])
	check(walked.ok and absf(flat(m.feet).distance_to(Ring.C)) < 6.0,"Centre: on into the stone circle (%s)" % feet())
	# A mid-span jump on a bridge's deck lands back on it.
	var b0: Dictionary = Ring.bridges()[0]
	var ba: Vector3 = b0.a
	var bb: Vector3 = b0.b
	var bdir := Vector2(bb.x-ba.x,bb.z-ba.z).normalized()
	settle(ba-Vector3(bdir.x,0.0,bdir.y)*0.9,bdir)
	walk_only([Vector2(ba.x,ba.z).lerp(Vector2(bb.x,bb.z),0.5)])
	var landed := false
	for i in range(120):
		tick(Vector2.ZERO,i < 14)
		if i > 20 and m.grounded:
			landed = true
			break
	check(landed and m.grounded,"Bridge: a jump on the first bridge's sagging middle lands back on its deck (%s)" % feet())

func _platforms_true() -> void:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	var off := 0
	for p: Dictionary in Ring.platforms():
		var a: Vector3 = p.at
		ray.from = a+Vector3.UP*2.0
		ray.to = a+Vector3.DOWN*2.0
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or absf((hit.position as Vector3).y-a.y) > 0.03: off += 1
	check(off == 0,"Stones: every stone's walked top is where it is drawn (%d of %d off)" % [off,Ring.platforms().size()])

func _tokens() -> void:
	var life: Node = study.get("life")
	if life == null or life.tokens == null:
		check(false,"Tokens: the isle's life and its tokens are there")
		return
	var all: Array = life.tokens.tokens.map(func(t: Dictionary) -> String: return t.name)
	var taken: Array = life.tokens.taken
	check(all.size() >= 4,"Tokens: %d on-foot tokens up the spiral (%s)" % [all.size(),", ".join(all)])
	check(taken.size() >= 5 and taken.has("summit"),"Tokens: the climb took %d of them (%s; not taken: %s)" % [taken.size(),", ".join(taken),", ".join(all.filter(func(n: String) -> bool: return not taken.has(n)))])
	var lines: Array = Ring.plane_tokens()
	var ids := lines.map(func(l: Array) -> String: return l[0])
	check(lines.size() >= 8 and ids.size() == ids.duplicate().size(),"Plane: a slalom of %d token lines through and under the ring" % lines.size())
	var under := lines.filter(func(l: Array) -> bool: return str(l[0]).begins_with("br:under_")).size()
	check(under >= 2,"Plane: tokens under %d of the rope bridges" % under)
