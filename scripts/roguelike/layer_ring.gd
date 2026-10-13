extends RefCounted
## The ring shape of a generated layer (docs/design/roguelike/
## layer-round7-ring.md; `--shape=ring` on studies/run_layer.tscn, and every
## other region of a run begun on the sprawl): the aqueduct scene's layout
## (scripts/kit_isle/motif_sky.gd PLACES), generated. The aqueduct isle at
## the middle, where he arrives; COUNT motif isles from the pool (families
## rolled) standing in a ring round it, RADIUS out, wide open sky between
## them and every isle in sight across the middle; the ring rising gently
## from its low isle round both ways to the gate isle on the far side.
##
##   - The ring serpent (`_ring_serpent`): one rune serpent on a loop of its
##     own, as the aqueduct scene's (scripts/kit_isle/serpent_route.gd ROUTE):
##     from a pier on the aqueduct isle out to the gate isle's neighbour, on
##     round the ring past a pier on every ring isle but the gate isle, and
##     home; by each pier straight and level, its slither held in (LayerPlan's
##     gulf loop's grammar, many piers).
##   - The gate isle is reached across a gulf from a neighbour (or the base)
##     on its own honest ride, the ferry first (LayerPlan `_ferry_loop`), as
##     is any ring isle the serpent's loop couldn't pass (`_links`).
##   - Cannons where a shot carries a gulf between two ring isles or from the
##     base out (`_cannons`, LayerPlan `_gulf_cannon`): the fast, risky way.
##   - A greed branch (hard stones, the rune set, its cannon) off a ring isle
##     and the Plinth Ram, as round 3's (LayerPlan `_step`, `_cannon`, `_ram`).
##   - The gate on the gate isle's rim facing out (`plan.heading`, the exit
##     side), and beyond it the next region (the sprawl's machinery:
##     LayerSprawl `_spawn_view`, `attach_next`, `_place_next`), and the
##     dragon's roost apart past the ring (LayerSprawl `_roost`).
##   - Each ring isle's room for the dragon's grip, as a flag for later
##     (`isle.grip`, `_grip`: docs/design/dragon-grip/round1.md's room rule
##     read off its occupancy).
## The same seed and knobs give the same plan.
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LayerSprawl = preload("res://scripts/roguelike/layer_sprawl.gd")
const SerpentRoute = preload("res://scripts/kit_isle/serpent_route.gd")
const SkyDragon = preload("res://scripts/sky_dragon.gd")

## How many isles stand in the ring (the knob `ring` pins it).
const COUNT := Vector2i(4,6)
## Each ring isle's middle this far out from the aqueduct isle's (m, flat),
## give or take RADIUS_JITTER; its bearing off an even spacing by up to
## BEARING_JITTER (degrees). The aqueduct scene's isles stand 345-480 m out.
const RADIUS := Vector2(275.0,325.0)
const RADIUS_JITTER := 22.0
const BEARING_JITTER := 9.0
## Open sky: solid to solid (m, flat) between two ring isles, and between a
## ring isle and the aqueduct isle.
const RING_GAP := 110.0
const BASE_GAP := 120.0
## The rise round the ring: the low isle's foot this much over the aqueduct
## isle's turf, the gate isle's this much, the others between by how far
## round they stand (m); the gate isle GATE_OVER more.
const LOW_RISE := Vector2(3.0,9.0)
const GATE_RISE := Vector2(22.0,36.0)
const GATE_OVER := 4.0
## A motif that is not a family may come this many times a layer.
const REPEATS := 2
## Placings tried for each ring isle (each pushed out a little more), and
## motifs drawn in place of one that won't stand.
const PLACE_TRIES := 12
const SUBS := 2
## Whole draws tried before the last is kept with its problems.
const ATTEMPTS := 30
## The ring serpent: loops tried (each moving a pier that met an isle to
## its rim's next best, or dropping it), the most piers on the ring, the
## lanes' lead out off each pier (along its rim's edge, out over the drop;
## in RUN*OUT, the 45-degree corners' reach), scaled by BULGES in turn.
const SERPENT_TRIES := 12
const SERPENT_BUDGET := 36
const BULGES := [1.0,1.35,0.75]
const BASE_LEAD := Vector2(0.5,3.2)
const RING_LEAD := Vector2(1.3,1.9)
## A gulf link's rim pairs tried for each ride; a link's rims want this
## run-up.
const LINK_FITS := 16
## How far a link's rims may turn off its line when none does within
## LayerPlan GULF_TURN (degrees; the rides come round at 45 degrees).
const LINK_TURN := 65.0
## Cannon-only gulfs: at most this many, rim lip to rim lip at most
## CANNON_GAP (m, flat).
const CANNONS_MOST := 2
const CANNON_GAP := 240.0
## A ride's tube kept this far (m) past another's, where it can be.
const TUBE_APART := 4.0
## The greed branch's stones kept this far (m) past a ride's tube.
const STONES_CLEAR := 4.0
## The gate: its rim this much run-up.
const GATE_RUN_UP := 2.5

# --- Making it ------------------------------------------------------------------------

## The ring plan for `seed_value`: LayerPlan's keys (`make`'s), `shape`
## ("ring"), `ring` ({order (isle indices round it), gate, radius, serpent
## (its edge), turn}), `heading` (the exit side), the spawn turned toward
## where the next region stands, `roost`, and on the main thread the next
## region (`next`; laid later on a worker windowed, as the sprawl's).
static func make(seed_value: int, knobs := {}) -> Dictionary:
	var plan := core(seed_value,knobs)
	if not (plan.problems as Array).is_empty(): return plan
	if OS.get_thread_caller_id() == OS.get_main_thread_id(): LayerSprawl.attach_next(plan)
	return plan

## Plans made, kept by seed and knobs (as LayerSprawl's: made once as the
## next region, taken again through the gate).
static var _kept := {}
static var _order: Array = []
static var _lock: Mutex = null
static func _mutex() -> Mutex:
	if _lock == null: _lock = Mutex.new()
	return _lock
const KEEP := 4

## The layer for `seed_value` without its next region.
static func core(seed_value: int, knobs := {}) -> Dictionary:
	var key := "%d %s" % [seed_value,str(knobs)]
	var lock := _mutex()
	lock.lock()
	var had: Dictionary = _kept.get(key,{})
	lock.unlock()
	if not had.is_empty(): return had
	var k := knobs.duplicate()
	k.shape = "ring"
	k.repeats = REPEATS
	var plan := {}
	for attempt in range(ATTEMPTS):
		var began := Time.get_ticks_usec()
		plan = _make(seed_value,attempt,k)
		if not (plan.problems as Array).is_empty():
			if LayerPlan.trace: print("layer ring: seed %d attempt %d: %s" % [seed_value,attempt,str(plan.problems)])
			continue
		LayerSprawl._spawn_view(plan)
		if LayerSprawl._roost(plan):
			plan.ring.ms = (Time.get_ticks_usec()-began)/1000.0
			break
		plan.problems.append("no roost")
	plan.user_knobs = knobs.duplicate()
	lock.lock()
	_kept[key] = plan
	_order.append(key)
	while _order.size() > KEEP: _kept.erase(_order.pop_front())
	lock.unlock()
	return plan

static func _make(seed_value: int, attempt: int, knobs: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,attempt,"ring"])
	var k_all := LayerPlan.KNOBS.duplicate()
	k_all.merge(knobs,true)
	var plan := {"seed":seed_value,"attempt":attempt,"knobs":k_all,"shape":"ring","isles":[],"edges":[],"hoods":[],"gulfs":[],"route":[],"exit":{},
		"spawn":{},"prize":{},"cannon":{},"ram":{},"void_y":0.0,"tubes":[],"problems":[]}
	var n := int(k_all.get("ring",0))
	n = clampi(n,3,7) if n > 0 else rng.randi_range(COUNT.x,COUNT.y)
	# The motifs: n round the ring and one for the greed branch (the
	# smaller the likelier, never a hero).
	var motifs: Array = []
	for p: Array in LayerPlan._draw(n+1,rng,REPEATS): motifs.append(LayerPlan._motif_isle(p,rng))
	if motifs.size() < n+1:
		plan.problems.append("too few motifs drawn")
		return plan
	var can: Array = motifs.filter(func(m: Dictionary) -> bool: return m.motif.role() != "hero")
	if can.is_empty(): can = motifs.duplicate()
	var total_inv := 0.0
	for m: Dictionary in can: total_inv += 1.0/LayerPlan._area(m)
	var draw := rng.randf()*total_inv
	var greed: Dictionary = can[can.size()-1]
	for m: Dictionary in can:
		draw -= 1.0/LayerPlan._area(m)
		if draw <= 0.0:
			greed = m
			break
	motifs.erase(greed)
	if attempt > 0: LayerPlan._shuffle(motifs,rng)
	var base := LayerPlan._base_isle()
	base.sockets = base.own.duplicate()
	base.hood = 0
	plan.isles.append(base)
	# The ring: k = 0 the low isle, the gate isle across from it.
	var mid := Vector2(LayerPlan.MIDDLE.x,LayerPlan.MIDDLE.z)
	var start := rng.randf()*TAU
	var turn := 1.0 if rng.randf() < 0.5 else -1.0
	var radius := rng.randf_range(RADIUS.x,RADIUS.y)
	var gate_k := n/2
	var low := rng.randf_range(LOW_RISE.x,LOW_RISE.y)
	var high := rng.randf_range(GATE_RISE.x,GATE_RISE.y)
	var order: Array = []
	for kk in range(n):
		var share := float(mini(kk,n-kk))/float(mini(gate_k,n-gate_k))
		var foot := LayerPlan.MIDDLE.y+lerpf(low,high,share)+rng.randf_range(-1.5,1.5)+(GATE_OVER if kk == gate_k else 0.0)
		var m: Dictionary = motifs[kk]
		var placed := {}
		for sub in range(SUBS+1):
			if sub > 0: m = _another(plan,motifs,greed,rng)
			if m.is_empty(): break
			placed = _place(plan,m,mid,start+turn*kk*TAU/n,radius,foot,rng)
			if not placed.is_empty(): break
		if placed.is_empty():
			plan.problems.append("no place in the ring for %s" % str(motifs[kk].id))
			return plan
		motifs[kk] = m
		placed.role = "route"
		placed.ring = kk
		placed.sockets = []
		for s: Dictionary in placed.own: placed.sockets.append(LayerPlan._world(s,placed.offset))
		plan.isles.append(placed)
		order.append(plan.isles.size()-1)
	var gate_i: int = order[gate_k]
	# The neighbourhoods: the base's, the gate isle's (the first the start
	# looks toward), then the rest round the ring.
	plan.hoods.append([0])
	plan.hoods.append([gate_i])
	for i: int in order:
		if i != gate_i: plan.hoods.append([i])
	for h in range((plan.hoods as Array).size()): plan.isles[plan.hoods[h][0]].hood = h
	var used := {}
	# The exit side: out from the middle through the gate isle; the gate on
	# its rim facing out that way (high, and furthest out).
	var gate_mid := LayerPlan._rect(plan.isles[gate_i]).get_center()
	var heading := (gate_mid-mid).normalized()
	plan.heading = heading
	var exit := {}
	var exit_score := -INF
	for s: Dictionary in plan.isles[gate_i].sockets:
		if s.kind != "rim" or float(s.run_up) < GATE_RUN_UP: continue
		var f := Vector2((s.face as Vector3).x,(s.face as Vector3).z).normalized()
		var score := f.dot(heading)*2.0+(s.at as Vector3).y*0.05+Vector2((s.at as Vector3).x,(s.at as Vector3).z).dot(heading)/25.0
		if score > exit_score:
			exit_score = score
			exit = s
	if exit.is_empty():
		plan.problems.append("no gate rim on %s" % str(plan.isles[gate_i].id))
		return plan
	used[LayerPlan._key(gate_i,str(exit.name))] = true
	plan.exit = {"isle":gate_i,"rim":exit.name,"at":exit.at,"face":exit.face}
	plan.ring = {"order":order,"gate":gate_i,"radius":radius,"turn":turn,"serpent":-1,"rise":[low,high+GATE_OVER]}
	# The ring serpent, then the links it leaves, then the cannons.
	if not _ring_serpent(plan,order,gate_k,used,rng):
		plan.problems.append("no ring serpent")
		return plan
	if not _links(plan,order,used,rng): return plan
	_serpent_to_gate(plan,gate_i)
	for i in range(1,plan.isles.size()): plan.route.append(i)
	plan.route.push_front(0)
	_greed(plan,greed,gate_i,used,rng)
	_cannons(plan,order,used,rng)
	LayerPlan._ram(plan,used)
	# The spawn: back along the run-up of the serpent's pier's rim on the
	# base (`_spawn_view` may move it to see the next region).
	var serpent: Dictionary = plan.edges[int(plan.ring.serpent)]
	var rim: Dictionary = serpent.from_rim
	var back := minf(float(rim.run_up)*0.7,LayerPlan.SPAWN_BACK)
	plan.spawn = {"at":(rim.at as Vector3)-(rim.face as Vector3)*back+Vector3.UP*0.2,"face":rim.face}
	var lowest := INF
	for isle: Dictionary in plan.isles: lowest = minf(lowest,LayerPlan._span(isle).x)
	plan.void_y = lowest-LayerPlan.VOID_UNDER
	for i: int in order: plan.isles[i].grip = _grip(plan.isles[i])
	return plan

## Another pool pick in place of one that won't stand (a family any
## number of times, the rest REPEATS a layer).
static func _another(plan: Dictionary, motifs: Array, greed: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var taken := {}
	for m: Dictionary in motifs+[greed]+plan.isles: taken[m.id] = int(taken.get(m.id,0))+1
	var pool: Array = []
	var total := 0.0
	for p: Array in LayerPlan.POOL:
		var probe: RefCounted = (p[1] as Script).new()
		if not probe.family() and int(taken.get(str(p[0]),0)) >= REPEATS: continue
		pool.append(p)
		total += float(p[2])
	if pool.is_empty(): return {}
	var roll := rng.randf()*total
	for p: Array in pool:
		roll -= float(p[2])
		if roll <= 0.0: return LayerPlan._motif_isle(p,rng)
	return LayerPlan._motif_isle(pool[pool.size()-1],rng)

## Its foot: its lowest rim with a run-up (own frame, y): what stands at the
## ring's height there.
static func _foot(m: Dictionary) -> float:
	var y := INF
	for s: Dictionary in m.own:
		if s.kind == "rim" and float(s.run_up) >= LayerPlan.GULF_RUN_UP: y = minf(y,(s.at as Vector3).y)
	if y == INF:
		for s: Dictionary in m.own: if s.kind == "rim": y = minf(y,(s.at as Vector3).y)
	return y if y < INF else LayerPlan.MIDDLE.y

## `m` stood in the ring at `bearing`, its middle about `radius` out and its
## foot at `foot`: open sky kept to every isle stood before; {} if no placing
## of PLACE_TRIES does.
static func _place(plan: Dictionary, m: Dictionary, mid: Vector2, bearing: float, radius: float, foot: float, rng: RandomNumberGenerator) -> Dictionary:
	var own := LayerPlan._rect(m).get_center()
	for t in range(PLACE_TRIES):
		var b := bearing+deg_to_rad(rng.randf_range(-BEARING_JITTER,BEARING_JITTER))
		var r := radius+rng.randf_range(-RADIUS_JITTER,RADIUS_JITTER)+t*8.0
		var c := mid+Vector2.from_angle(b)*r
		var placed: Dictionary = m.duplicate()
		placed.offset = Vector3(c.x-own.x,foot-_foot(m),c.y-own.y)
		placed.hood = plan.isles.size()
		if LayerPlan._rect(placed).get_center().distance_to(mid) > LayerPlan.BAND-60.0: continue
		var ok := true
		for other: Dictionary in plan.isles:
			var gap := BASE_GAP if other.role == "base" else RING_GAP
			if LayerPlan.clash(other,placed) or _near(other,placed,gap):
				ok = false
				break
		if ok: return placed
	return {}

## Whether any solid of `a` stands within `d` (m, flat) of `b`'s.
static func _near(a: Dictionary, b: Dictionary, d: float) -> bool:
	var ra := LayerPlan._rect(a)
	var rb := LayerPlan._rect(b)
	var dx := maxf(maxf(ra.position.x-rb.end.x,rb.position.x-ra.end.x),0.0)
	var dz := maxf(maxf(ra.position.y-rb.end.y,rb.position.y-ra.end.y),0.0)
	if Vector2(dx,dz).length() >= d: return false
	return LayerPlan._near_cells(a,b,d)

# --- The ring serpent -----------------------------------------------------------------

## The serpent round the ring: a pier on the base facing the gate's way,
## out to the ring isle past the gate (round the ring's turn), on round past
## a pier on every ring isle but the gate isle, home to the base. Each
## pier's rim the best that faces in or out of the ring (so the serpent
## passes it going round); a pier whose loop meets an isle moved to its
## rim's next best, or dropped from the loop (that isle is linked later).
## The edge appended (kind "gulf", ride "serpent", `stops` its isles), its
## tube kept; false if no loop of three piers or more clears.
static func _ring_serpent(plan: Dictionary, order: Array, gate_k: int, used: Dictionary, rng: RandomNumberGenerator) -> bool:
	var n := order.size()
	var mid := Vector2(LayerPlan.MIDDLE.x,LayerPlan.MIDDLE.z)
	var gate_i: int = order[gate_k]
	# Each ring isle's pier rims (but the gate isle's), the best first.
	var ring_rims := {}
	for i: int in order:
		if i == gate_i: continue
		var c := LayerPlan._rect(plan.isles[i]).get_center()
		var inward := (mid-c).normalized()
		var rims: Array = []
		for s: Dictionary in plan.isles[i].sockets:
			if s.kind != "rim" or float(s.run_up) < LayerPlan.GULF_RUN_UP or used.has(LayerPlan._key(i,str(s.name))): continue
			var h := _pier_held(plan.isles[i],s)
			if h == 0: continue
			var f := Vector2((s.face as Vector3).x,(s.face as Vector3).z).normalized()
			var at := Vector2((s.at as Vector3).x,(s.at as Vector3).z)
			# Facing in or out of the ring (in the better), on the isle's
			# edge (not deep in it), low (near its foot).
			var score := absf(f.dot(inward))+(1.0 if f.dot(inward) > 0.0 else 0.0)+(at-c).length()/60.0-((s.at as Vector3).y-(plan.isles[i].offset as Vector3).y-_foot(plan.isles[i]))*0.03+rng.randf()*0.3
			var r: Dictionary = s.duplicate()
			r.held = h
			rims.append([score+0.5*h,r])
		rims.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		if not rims.is_empty(): ring_rims[i] = rims.map(func(x: Array) -> Dictionary: return x[1])
	# The base's pier rims (its coast is ragged: few take a pier), in a
	# rolled order; each tried in turn.
	var base_rims: Array = []
	for s: Dictionary in plan.isles[0].sockets:
		if s.kind != "rim" or float(s.run_up) < LayerPlan.GULF_RUN_UP: continue
		var h := _pier_held(plan.isles[0],s)
		if h == 0: continue
		var r: Dictionary = s.duplicate()
		r.held = h
		base_rims.append(r)
	LayerPlan._shuffle(base_rims,rng)
	var bearings: Array = []
	for i: int in order: bearings.append((LayerPlan._rect(plan.isles[i]).get_center()-mid).angle())
	var loop := {}
	var tries := 0
	for base_rim: Dictionary in base_rims:
		# The loop's mouth: the gap round the ring nearest the way the base's
		# pier faces; out through it to the isle past it, round the ring
		# (past the gate isle without a pier), home through it.
		var face := Vector2((base_rim.face as Vector3).x,(base_rim.face as Vector3).z).angle()
		var mouth := 0
		var near := INF
		for k in range(n):
			var gap := float(bearings[k])+wrapf(float(bearings[(k+1)%n])-float(bearings[k]),-PI,PI)*0.5
			var off := absf(wrapf(gap-face,-PI,PI))
			if off < near:
				near = off
				mouth = k
		var stops: Array = [[0,[base_rim],0]]
		for j in range(1,n+1):
			var i: int = order[(mouth+j)%n]
			if ring_rims.has(i): stops.append([i,ring_rims[i],0])
		for t in range(SERPENT_TRIES):
			if stops.size() < 3 or tries >= SERPENT_BUDGET: break
			tries += 1
			var bulge: float = BULGES[t%BULGES.size()]
			var picks: Array = []
			for s: Array in stops: picks.append([s[0],s[1][s[2]]])
			var got := _ring_loop(plan,picks,bulge)
			if got.has("points"):
				loop = got
				break
			# It met an isle: if one with a pier, that pier moves to its rim's
			# next (or is dropped); the base's, the next base rim; another
			# (the gate isle, a lane's way), the lanes' lead changes.
			var hit: Vector3 = got.hit
			var hit_isle: int = got.isle
			var best := -1
			for k in range(stops.size()):
				if int(stops[k][0]) == hit_isle: best = k
			if LayerPlan.trace: print("  ring serpent try %d: met isle %d at %s (%s)" % [t,hit_isle,hit.round(),"pier %d" % best if best >= 0 else "no pier"])
			if best == 0: break
			if best < 0: continue
			stops[best][2] = int(stops[best][2])+1
			if int(stops[best][2]) >= (stops[best][1] as Array).size(): stops.remove_at(best)
		if not loop.is_empty() or tries >= SERPENT_BUDGET: break
	if loop.is_empty(): return false
	var first: Dictionary = loop.rims[0]
	var second: Dictionary = loop.rims[1]
	var lip_a: Vector3 = (first.at as Vector3)+(first.face as Vector3)*float(first.lip)
	var lip_b: Vector3 = (second.at as Vector3)+(second.face as Vector3)*float(second.lip)
	var isles: Array = []
	for k in range((loop.rims as Array).size()):
		var i: int = loop.isles[k]
		isles.append(i)
		used[LayerPlan._key(i,str(loop.rims[k].name))] = true
	var edge := {"kind":"gulf","branch":"route","from":[0,str(first.name)],"to":[int(loop.isles[1]),str(second.name)],"a":lip_a,"b":lip_b,
		"dir":Vector3(lip_b.x-lip_a.x,0.0,lip_b.z-lip_a.z).normalized(),"stones":[],"bridges":[],"parts":["ring serpent %.0f m" % float(loop.length),"%d piers" % isles.size()],
		"trap":{},"path":[],"from_rim":first,"to_rim":second,"width":lip_a.distance_to(lip_b),"rise":lip_b.y-lip_a.y,"ride":"serpent","serpent":loop,
		"stops":isles,"ring":true,"cannon":{},"sight":[(first.at as Vector3)+Vector3.UP*LayerPlan.EYE,(second.at as Vector3)+Vector3.UP*LayerPlan.EYE]}
	plan.ring.serpent = (plan.edges as Array).size()
	plan.gulfs.append((plan.edges as Array).size())
	plan.edges.append(edge)
	plan.tubes.append_array(loop.tube)
	return true

## Whether the serpent's straight run past a pier off `rim` (world) keeps
## clear of `isle` (its own): the held run and its 45-degree corners, at
## its reach, its rim's own air left out within LayerPlan EXEMPT_LEDGE (the
## loop's own test, near the pier only, cheap: the rims of a ragged coast
## are mostly ruled out here).
static func _pier_held(isle: Dictionary, rim: Dictionary) -> int:
	for h: int in [HELD,1]:
		if _pier_ok(isle,rim,h): return h
	return 0

static func _pier_ok(isle: Dictionary, rim: Dictionary, held: int) -> bool:
	var shape := LayerPlan._serpent_shape()
	var out: float = shape.flank+shape.weave*LayerPlan.LEDGE_WEAVE+SerpentRoute.LEDGE_GAP+LayerPlan.LEDGE_JUT
	var f: Vector3 = rim.face
	var f2 := Vector3(f.x,0.0,f.z).normalized()
	var lip: Vector3 = (rim.at as Vector3)+f*float(rim.lip)
	var p := Vector3(lip.x,(rim.at as Vector3).y+LayerPlan.LEDGE_RISE-shape.crest+SerpentRoute.LEDGE_DROP,lip.z)+f2*out
	var e := Vector3(f2.z,0.0,-f2.x)
	var side := e*RUN*(held-1)
	var line: Array = [p-side+(-e+f2)*RUN*OUT,p-e*RUN*(held+0.2),p+e*RUN*(held+0.2),p+side+(e+f2)*RUN*OUT]
	var samples: Array = []
	for k in range(line.size()-1):
		for s: Array in LayerPlan._line(line[k],line[k+1],0.0,2.0): samples.append([s[0],PIER_REACH])
	return _tube_hit(samples,[isle],[[0,p,LayerPlan.EXEMPT_LEDGE]]) == Vector3.INF
## The serpent's reach by a pier (its girth and slither held in, m).
const PIER_REACH := 6.3

## The serpent's edge read as coming to the isle the gate's link leaves
## (its pier there), so the way on (scripts/roguelike/way_lights.gd
## `main_line`, the start's facing) runs base, serpent, link, gate.
static func _serpent_to_gate(plan: Dictionary, gate_i: int) -> void:
	var e: Dictionary = plan.edges[int(plan.ring.serpent)]
	for gi: int in plan.gulfs:
		var link: Dictionary = plan.edges[gi]
		if link.get("ring",false) or int(link.to[0]) != gate_i: continue
		var k: int = (e.serpent.isles as Array).find(int(link.from[0]))
		if k <= 0: continue
		var rim: Dictionary = e.serpent.rims[k]
		e.to = [int(link.from[0]),str(rim.name)]
		e.to_rim = rim
		e.b = (rim.at as Vector3)+(rim.face as Vector3)*float(rim.lip)
		return

## The serpent's loop through `picks` ([isle, rim (world)], the base's
## first, then round the ring): {points, marks, start, spots, tube, length,
## rims, isles}, or {hit (where its tube met an isle), ends (each pier's
## pass point)}.
const RUN := 8.0
const OUT := 2.0
## Its pace's share coming in to a pier (held 0.75 by it); the held run's
## control points each side of the pier's (RUN apart: its middle, where a
## rider sits, passes the pier with its head still held).
const NEAR_PACE := 0.78
const HELD := 2
## (Where a coast won't take it, one each side, as LayerPlan's gulf loops.)
static func _ring_loop(plan: Dictionary, picks: Array, bulge: float) -> Dictionary:
	var shape := LayerPlan._serpent_shape()
	var out: float = shape.flank+shape.weave*LayerPlan.LEDGE_WEAVE+SerpentRoute.LEDGE_GAP+LayerPlan.LEDGE_JUT
	var middle := LayerPlan.MIDDLE
	var ends: Array = []
	var faces: Array = []
	for pk: Array in picks:
		var rim: Dictionary = pk[1]
		var f: Vector3 = rim.face
		var f2 := Vector3(f.x,0.0,f.z).normalized()
		var lip: Vector3 = (rim.at as Vector3)+f*float(rim.lip)
		ends.append(Vector3(lip.x,(rim.at as Vector3).y+LayerPlan.LEDGE_RISE-shape.crest+SerpentRoute.LEDGE_DROP,lip.z)+f2*out)
		faces.append(f2)
	var n := ends.size()
	# Each pier's way along its rim's edge, on round the loop.
	var ways: Array = []
	for i in range(n):
		var f: Vector3 = faces[i]
		var e := Vector3(f.z,0.0,-f.x)
		var ahead: Vector3 = (ends[(i+1)%n] as Vector3)-(ends[(i-1+n)%n] as Vector3)
		if e.dot(ahead) < 0.0: e = -e
		ways.append(e)
	var pts: Array = []
	var marks := {}
	var held := func(p: Vector3) -> Array: return [p,LayerPlan.LEDGE_WEAVE,0.75,0.0]
	var free := func(p: Vector3, w: float, pace := 1.0) -> Array: return [p,w,pace,0.0]
	for i in range(n):
		var p: Vector3 = ends[i]
		var f: Vector3 = faces[i]
		var e: Vector3 = ways[i]
		# Slowing to the pier's pace before it, its lanes long.
		var h := int(picks[i][1].get("held",1))
		var side := e*RUN*(h-1)
		pts.append(free.call(p-side+(-e+f)*RUN*OUT,0.4,NEAR_PACE))
		for k in range(-h,h+1): pts.append(held.call(p+e*RUN*k))
		marks["s%d" % i] = pts.size()-1-h
		pts.append(free.call(p+side+(e+f)*RUN*OUT,0.4,NEAR_PACE))
		# Out into open sky off the rim before turning for the next pier
		# (the base's further out and less aside: its neighbours on the ring
		# stand well off its rim's facing), and in the same way to the next.
		var q: Vector3 = ends[(i+1)%n]
		var fq: Vector3 = faces[(i+1)%n]
		var eq: Vector3 = ways[(i+1)%n]
		var lead: Vector2 = (BASE_LEAD if i == 0 else RING_LEAD)*bulge
		var lead_q: Vector2 = (BASE_LEAD if i == n-1 else RING_LEAD)*bulge
		var po := p+side+(e*lead.x+f*lead.y)*RUN*OUT
		var qo := q-eq*RUN*(int(picks[(i+1)%n][1].get("held",1))-1)+(-eq*lead_q.x+fq*lead_q.y)*RUN*OUT
		pts.append(free.call(po,0.7))
		var d := Vector2(qo.x-po.x,qo.z-po.z).length()
		var t0 := clampf(LayerPlan.SERPENT_LANE_STEP*0.5/maxf(d,1.0),0.08,0.3)
		var lane: Array = []
		if i == 0 or i == n-1:
			# Out from the base and home to it: straight.
			lane = LayerPlan._lane(po,qo,Vector3.ZERO,t0)
		else:
			# Round the ring: along the arc between the two piers.
			var ap := Vector2(po.x-middle.x,po.z-middle.z)
			var aq := Vector2(qo.x-middle.x,qo.z-middle.z)
			var span := wrapf(aq.angle()-ap.angle(),-PI,PI)
			var count := maxi(int(ceil(absf(span)*(ap.length()+aq.length())*0.5*(1.0-2.0*t0)/LayerPlan.SERPENT_LANE_STEP)),1)
			for s in range(count+1):
				var t := lerpf(t0,1.0-t0,float(s)/count)
				var a := ap.angle()+span*t
				var r := lerpf(ap.length(),aq.length(),t)
				lane.append(Vector3(middle.x+cos(a)*r,lerpf(p.y,q.y,t)+LayerPlan.LANE_LIFT*sin(PI*t),middle.z+sin(a)*r))
		if i == n-1: marks.start = pts.size()+int(lane.size()/2.0)
		for lp: Vector3 in lane: pts.append(free.call(lp,1.0))
		pts.append(free.call(qo,0.7,NEAR_PACE))
	# Its heave by each pier taken out of the way there (twice: the arcs
	# move a little), so each pier's top stands LEDGE_RISE over its rim.
	var tube := LayerPlan._serpent_tube(pts,marks)
	for again in range(2):
		for i in range(n):
			var mark := "s%d" % i
			var y: float = (ends[i] as Vector3).y-float(tube.heave[mark])
			var h := int(picks[i][1].get("held",1))
			for j in range(int(marks[mark])-h,int(marks[mark])+h+1): pts[j][0] = Vector3((pts[j][0] as Vector3).x,y,(pts[j][0] as Vector3).z)
		tube = LayerPlan._serpent_tube(pts,marks)
	var exempt: Array = []
	for i in range(n): exempt.append([int(picks[i][0]),ends[i],LayerPlan.EXEMPT_LEDGE])
	var hit := _tube_hit(tube.samples,plan.isles,exempt)
	if hit != Vector3.INF: return {"hit":hit,"isle":_hit_isle,"ends":ends}
	# Each pier on its isle's side of the way.
	var spots: Array = []
	var rims: Array = []
	var isles: Array = []
	for i in range(n):
		var way: Vector3 = ways[i]
		var f: Vector3 = faces[i]
		var right := Vector2(-way.z,way.x)
		spots.append({"name":"s%d" % i,"isle":int(picks[i][0]),"side":1.0 if Vector2(-f.x,-f.z).dot(right) > 0.0 else -1.0})
		rims.append(picks[i][1])
		isles.append(int(picks[i][0]))
	return {"points":pts,"marks":marks,"start":"start","spots":spots,"tube":tube.samples,"length":tube.length,"rims":rims,"isles":isles}

## Where the samples ([point, radius]) first meet an isle of `isles` (but
## each of `exempt`, [isle, point, radius], near its point), or INF.
static func _tube_hit(samples: Array, isles: Array, exempt: Array) -> Vector3:
	for i in range(isles.size()):
		var isle: Dictionary = isles[i]
		var r := LayerPlan._rect(isle)
		var span := LayerPlan._span(isle)
		for t: Array in samples:
			var p: Vector3 = t[0]
			var rad: float = t[1]
			if p.x < r.position.x-rad or p.x > r.end.x+rad or p.z < r.position.y-rad or p.z > r.end.y+rad: continue
			if p.y+rad < span.x or p.y-rad > span.y: continue
			var skip := false
			for ex: Array in exempt:
				if int(ex[0]) == i and Vector2(p.x-(ex[1] as Vector3).x,p.z-(ex[1] as Vector3).z).length() < float(ex[2]): skip = true
			if skip: continue
			if LayerPlan._column_hit(isle,p,rad):
				_hit_isle = i
				return p
	return Vector3.INF
## The isle `_tube_hit` last met (its index in the list it was given).
static var _hit_isle := -1

## Whether two rides' tubes ([point, radius] each) come within TUBE_APART
## (their samples bucketed flat).
static func _tubes_meet(a: Array, b: Array) -> bool:
	var cell := 24.0
	var grid := {}
	for t: Array in b:
		var p: Vector3 = t[0]
		var key := Vector2i(floori(p.x/cell),floori(p.z/cell))
		if not grid.has(key): grid[key] = []
		grid[key].append(t)
	for t: Array in a:
		var p: Vector3 = t[0]
		var c := Vector2i(floori(p.x/cell),floori(p.z/cell))
		for dx in range(-1,2):
			for dz in range(-1,2):
				for u: Array in grid.get(c+Vector2i(dx,dz),[]):
					if p.distance_to(u[0]) < float(t[1])+float(u[1])+TUBE_APART: return true
	return false

# --- The links: the gate isle and any isle the loop left -----------------------------

## Every ring isle the serpent doesn't pass linked across a gulf from one
## it reaches (a ring neighbour first, else the base), on its own honest ride
## (the first link the ferry if it goes, then the other way about), its
## cannon too where it is narrow enough. False (a problem noted) if one
## can't be.
static func _links(plan: Dictionary, order: Array, used: Dictionary, rng: RandomNumberGenerator) -> bool:
	var reached := {0: true}
	for i: int in plan.edges[int(plan.ring.serpent)].stops: reached[i] = true
	var n := order.size()
	var ride_next := "ferry"
	var progress := true
	while progress:
		progress = false
		for k in range(n):
			var u: int = order[k]
			if reached.has(u): continue
			var froms: Array = []
			for d: int in [-1,1]:
				var a: int = order[(k+d+n)%n]
				if reached.has(a): froms.append(a)
			var rides: Array = [ride_next,"serpent" if ride_next == "ferry" else "ferry"]
			var got := {}
			# A ring neighbour first (clear of the other rides, then not; then
			# its rims turned further off the line), the base last.
			for pass_: Array in [[froms,true,LayerPlan.GULF_TURN],[froms,false,LayerPlan.GULF_TURN],[froms,false,LINK_TURN],[[0],true,LayerPlan.GULF_TURN],[[0],false,LINK_TURN]]:
				for ride: String in rides:
					for a: int in pass_[0]:
						got = _link(plan,a,u,ride,used,rng,bool(pass_[1]),float(pass_[2]))
						if not got.is_empty(): break
					if not got.is_empty(): break
				if not got.is_empty(): break
			if got.is_empty(): continue
			reached[u] = true
			progress = true
			ride_next = "serpent" if got.ride == "ferry" else "ferry"
	for i: int in order:
		if not reached.has(i):
			plan.problems.append("no way onto ring isle %d (%s)" % [i,str(plan.isles[i].id)])
			return false
	return true

## The rim pairs from isle `a` to isle `b` a gulf may take (each facing out
## over the line between their lips, within LayerPlan GULF_TURN), as gulf
## edges (no ride yet), the best first: [edge].
static func _fits(plan: Dictionary, a: int, b: int, used: Dictionary, rng: RandomNumberGenerator, run_up := LayerPlan.GULF_RUN_UP, turn := LayerPlan.GULF_TURN) -> Array:
	var ia: Dictionary = plan.isles[a]
	var ib: Dictionary = plan.isles[b]
	var fits: Array = []
	for ra: Dictionary in ia.sockets:
		if ra.kind != "rim" or used.has(LayerPlan._key(a,str(ra.name))) or float(ra.run_up) < run_up: continue
		for rb: Dictionary in ib.sockets:
			if rb.kind != "rim" or used.has(LayerPlan._key(b,str(rb.name))) or float(rb.run_up) < run_up: continue
			var fa: Vector3 = ra.face
			var fb: Vector3 = rb.face
			if fa.dot(-fb) < cos(deg_to_rad(turn*2.0)): continue
			var lip_a: Vector3 = (ra.at as Vector3)+fa*float(ra.lip)
			var lip_b: Vector3 = (rb.at as Vector3)+fb*float(rb.lip)
			var dir := Vector3(lip_b.x-lip_a.x,0.0,lip_b.z-lip_a.z).normalized()
			if dir.dot(fa) < cos(deg_to_rad(turn)) or dir.dot(-fb) < cos(deg_to_rad(turn)): continue
			var width := Vector2(lip_b.x-lip_a.x,lip_b.z-lip_a.z).length()
			var edge := {"kind":"gulf","branch":"route","from":[a,str(ra.name)],"to":[b,str(rb.name)],"a":lip_a,"b":lip_b,"dir":dir,
				"stones":[],"bridges":[],"parts":["gulf %.0f m" % width],"trap":{},"path":LayerPlan._line(lip_a,lip_b,LayerPlan.GULF_UNDER,2.0),
				"from_rim":ra,"to_rim":rb,"width":width,"rise":lip_b.y-lip_a.y,"ride":"","cannon":{},
				"sight":[(ra.at as Vector3)+Vector3.UP*LayerPlan.EYE,(rb.at as Vector3)+Vector3.UP*LayerPlan.EYE]}
			if not LayerPlan._corridor_clear(edge,plan.isles,a,b): continue
			if LayerPlan._crosses(edge,plan.edges): continue
			# Facing each other square, short, and off a high rim.
			fits.append([dir.dot(fa)+dir.dot(-fb)-width/150.0+0.02*lip_a.y+rng.randf(),edge])
	fits.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) > float(q[0]))
	return fits.map(func(p: Array) -> Dictionary: return p[1])

## A gulf from isle `a` to isle `b` on `ride` (its loop clear of every isle
## and, `strict`, of every ride laid before), appended with its tube, its
## cannon where it is narrow enough; the edge, or {}.
static func _link(plan: Dictionary, a: int, b: int, ride: String, used: Dictionary, rng: RandomNumberGenerator, strict: bool, turn := LayerPlan.GULF_TURN) -> Dictionary:
	for edge: Dictionary in _fits(plan,a,b,used,rng,LayerPlan.GULF_RUN_UP,turn).slice(0,LINK_FITS):
		var loop := LayerPlan._serpent_loop(edge,plan.isles,rng) if ride == "serpent" else LayerPlan._ferry_loop(edge,plan.isles,rng)
		if loop.is_empty(): continue
		if strict and _tubes_meet(loop.tube,plan.tubes): continue
		edge.ride = ride
		edge.parts = ["gulf %.0f m" % float(edge.width),ride]
		edge[ride] = loop
		plan.gulfs.append((plan.edges as Array).size())
		plan.edges.append(edge)
		plan.tubes.append_array(loop.tube)
		used[LayerPlan._key(a,str(edge.from[1]))] = true
		used[LayerPlan._key(b,str(edge.to[1]))] = true
		if float(edge.width) <= LayerPlan.GULF_CANNON_MOST: edge.cannon = LayerPlan._gulf_cannon(plan,edge)
		return edge
	return {}

# --- The greed branch, the cannons ----------------------------------------------------

## Round 3's greed branch (hard stones, the rune set on its isle's perch,
## its cannon) off a ring isle but the gate's, its stones clear of every
## ride; none if no isle takes it.
static func _greed(plan: Dictionary, greed: Dictionary, gate_i: int, used: Dictionary, rng: RandomNumberGenerator) -> void:
	greed.role = "greed"
	var starts: Array = (plan.ring.order as Array).filter(func(i: int) -> bool: return i != gate_i)
	LayerPlan._shuffle(starts,rng)
	var ceiling := LayerPlan._top_walked(plan.isles[gate_i])-1.0
	for s: int in starts:
		greed.hood = int(plan.isles[s].hood)
		var isles_had := (plan.isles as Array).size()
		var edges_had := (plan.edges as Array).size()
		var branched := LayerPlan._step(plan,s,greed,["hard"],"greed",used,rng,-INF,ceiling,int(greed.hood))
		if branched.is_empty(): continue
		if _path_in_tubes(branched.path,plan.tubes):
			# Its stones in a ride's way: undone.
			used.erase(LayerPlan._key(s,str(branched.from[1])))
			used.erase(LayerPlan._key(int(branched.to[0]),str(branched.to[1])))
			plan.isles.resize(isles_had)
			plan.edges.resize(edges_had)
			continue
		var g: int = plan.isles.size()-1
		plan.hoods[int(greed.hood)].append(g)
		var perch := {}
		for sk: Dictionary in plan.isles[g].sockets:
			if sk.kind == "perch" and (perch.is_empty() or float(sk.room) > float(perch.room)): perch = sk
		if perch.is_empty(): perch = {"at":(branched.to_rim.at as Vector3)-(branched.to_rim.face as Vector3)*3.0,"room":2.0}
		var ring := clampf(float(perch.room)*0.6,1.0,2.2)
		var runes: Array = []
		for i in range(LayerPlan.RUNES):
			var ang := TAU*i/LayerPlan.RUNES
			runes.append((perch.at as Vector3)+Vector3(cos(ang)*ring,1.0,sin(ang)*ring))
		plan.prize = {"isle":g,"at":perch.at,"room":perch.room,"runes":runes}
		LayerPlan._cannon(plan,branched,rng)
		return

static func _path_in_tubes(path: Array, tubes: Array) -> bool:
	for s: Array in path:
		var p: Vector3 = s[0]
		for t: Array in tubes:
			if p.distance_to(t[0]) < float(t[1])+STONES_CLEAR+float(s[1]): return true
	return false

## Cannon-only gulfs (ride "cannon": no ride, only the shot): from the base
## out to a ring isle, or from one ring isle to the next, where a shot
## carries it (LayerPlan `_gulf_cannon`); CANNONS_MOST at most, the
## narrowest first.
static func _cannons(plan: Dictionary, order: Array, used: Dictionary, rng: RandomNumberGenerator) -> void:
	var n := order.size()
	var pairs: Array = []
	for k in range(n):
		pairs.append([order[k],order[(k+1)%n]])
		pairs.append([order[(k+1)%n],order[k]])
		pairs.append([0,order[k]])
	var cands: Array = []
	for pr: Array in pairs:
		var fits := _fits(plan,int(pr[0]),int(pr[1]),used,rng,LayerPlan.CANNON_BACK+1.0)
		if fits.is_empty() or float(fits[0].width) > CANNON_GAP: continue
		cands.append(fits[0])
	cands.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.width) < float(q.width))
	var laid := 0
	for edge: Dictionary in cands:
		if laid >= CANNONS_MOST: break
		var a: int = edge.from[0]
		var b: int = edge.to[0]
		if used.has(LayerPlan._key(a,str(edge.from[1]))) or used.has(LayerPlan._key(b,str(edge.to[1]))): continue
		# A pier-less gulf: it stands just aside of its rim's line.
		edge.ride = "serpent"
		var c := LayerPlan._gulf_cannon(plan,edge)
		edge.ride = "cannon"
		if c.is_empty(): continue
		edge.cannon = c
		edge.parts = ["gulf %.0f m" % float(edge.width),"cannon"]
		plan.gulfs.append((plan.edges as Array).size())
		plan.edges.append(edge)
		used[LayerPlan._key(a,str(edge.from[1]))] = true
		used[LayerPlan._key(b,str(edge.to[1]))] = true
		laid += 1

# --- The dragon's grip ----------------------------------------------------------------

## Room for the dragon's grip (docs/design/dragon-grip/round1.md, scripts/
## sky_dragon.gd `_has_room`/`_best_turn`), read off the isle's occupancy,
## not its built shape: a rim ROOM*k out from its middle (k its size over
## TUNED_SIZE) whose chin band (3-16 m in from the lip, 3 m either side,
## each times k) is ROOM_OPEN open (solid there within a few metres of the
## rim's height) with at most ROOM_TALL samples standing 2 m+ over the rim
## (4-13 m in, 6 m either side, times k). {room, rim, out, open, tall}: the
## best way found. For later rounds (no dragon flies here yet).
static func _grip(isle: Dictionary) -> Dictionary:
	var k := SkyDragon.SIZE/SkyDragon.TUNED_SIZE
	var c := Vector2.ZERO
	var cells := LayerPlan._cells(isle)
	for p: Vector2 in cells: c += p
	c /= maxf(cells.size(),1.0)
	var best := {"room":false,"rim":"","out":0.0,"open":0.0,"tall":0}
	var best_score := -INF
	for s: Dictionary in isle.sockets:
		if s.kind != "rim": continue
		var at: Vector3 = s.at
		var rim := Vector2(at.x,at.z)
		var r := rim.distance_to(c)
		if r < 1.0: continue
		var out := (rim-c)/r
		var right := Vector2(-out.y,out.x)
		var open := 0
		var count := 0
		for d: float in [3.0,5.0,7.0,9.0,11.0,13.0,16.0]:
			for side: float in [-3.0,0.0,3.0]:
				var p := rim-out*d*k+right*side*k
				var o := LayerPlan.occ_at(isle,p.x,p.y)
				count += 1
				if o.x < INF and o.y <= at.y+2.0 and o.y >= at.y-3.0: open += 1
		var tall := 0
		for d: float in [4.0,7.0,10.0,13.0]:
			for side: float in [-6.0,-3.0,0.0,3.0,6.0]:
				var p := rim-out*d*k+right*side*k
				var o := LayerPlan.occ_at(isle,p.x,p.y)
				if o.x < INF and o.y-at.y > 2.0: tall += 1
		var roomy := r >= SkyDragon.ROOM*k and float(open) >= SkyDragon.ROOM_OPEN*count and tall <= SkyDragon.ROOM_TALL
		var score := (10.0 if roomy else 0.0)+float(open)/count-0.05*tall
		if score > best_score:
			best_score = score
			best = {"room":roomy,"rim":str(s.name),"out":r,"open":float(open)/count,"tall":tall}
	return best

# --- On the stage ---------------------------------------------------------------------

## What the ring adds to a built layer (the stage built its gate, the
## greed branch's stones and cannon, and the rides from `plan.gulfs`): the
## next region's silhouette (or its loader), as the sprawl's.
static func dress(stage: Node3D, plan: Dictionary) -> void:
	LayerSprawl.dress(stage,plan)
	var study: Node = stage.get("study")
	if study != null and not study.tree_exiting.is_connected(forget): study.tree_exiting.connect(forget)

static func forget() -> void:
	_kept.clear()
	_order.clear()
	_lock = null

## A line for the card: the ring, its rides, the gate, the next region, the
## roost.
static func card(plan: Dictionary) -> String:
	if not plan.has("ring"): return ""
	var ring: Dictionary = plan.ring
	var serpent: Dictionary = plan.edges[int(ring.serpent)]
	var gate: Dictionary = plan.isles[int(ring.gate)]
	var rides := PackedStringArray()
	var cannons := 0
	for gi: int in plan.gulfs:
		var e: Dictionary = plan.edges[gi]
		if e.get("ring",false): continue
		if e.ride == "cannon": cannons += 1
		else: rides.append("%s %d->%d" % [e.ride,int(e.from[0]),int(e.to[0])])
		if e.ride != "cannon" and not (e.cannon as Dictionary).is_empty(): cannons += 1
	var room := PackedStringArray()
	for i: int in ring.order:
		if (plan.isles[i].get("grip",{}) as Dictionary).get("room",false): room.append(str(i))
	var line := "Ring of %d, %.0f m out, rising %.0f-%.0f m · gate on %d %s (%s) · serpent loop %.0f m past %d piers · %s · %d cannon%s · grip room: %s" % [
		(ring.order as Array).size(),float(ring.radius),float(ring.rise[0]),float(ring.rise[1]),int(ring.gate),str(gate.id).replace("_"," "),
		LayerSprawl.compass(plan.heading),float(serpent.serpent.length),(serpent.stops as Array).size(),", ".join(rides) if not rides.is_empty() else "no other ride",
		cannons,"" if cannons == 1 else "s",", ".join(room) if not room.is_empty() else "none"]
	var next_shape := "ring" if int((plan.get("user_knobs",{}) as Dictionary).get("alternate",1)) == 0 else "sprawl"
	if plan.has("next"): line += "  ·  next region (layer %d, a %s) %.0f m off, %.0f m up" % [int(plan.next.seed),next_shape,float(plan.next.far),float(plan.next.rise)]
	var roost: Dictionary = plan.get("roost",{})
	if not roost.is_empty():
		var at: Vector3 = roost.at
		var spawn: Vector3 = plan.spawn.at
		var to := Vector2(at.x-spawn.x,at.z-spawn.z)
		line += "\nThe dragon's roost: %s, %.0f m off, its turf %.0f m up" % [LayerSprawl.compass(to.normalized()),to.length(),at.y-spawn.y]
	return line

## The plan for LayerSprawl `overview` with the ring serpent's loop drawn
## (as a gulf's line, `~`).
static func drawn(plan: Dictionary) -> Dictionary:
	var copy := plan.duplicate()
	copy.edges = (plan.edges as Array).duplicate()
	var e: Dictionary = (plan.edges[int(plan.ring.serpent)] as Dictionary).duplicate()
	var path: Array = []
	var tube: Array = e.serpent.tube
	for i in range(0,tube.size(),3): path.append([tube[i][0],0.0,0.0])
	e.path = path
	copy.edges[int(plan.ring.serpent)] = e
	return copy
