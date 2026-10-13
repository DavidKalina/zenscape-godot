extends RefCounted
## One generated layer of the climb (docs/design/roguelike/layer-round2.md),
## as plain data from a seed: which isles stand where, the edges joining
## them rim to rim, what is on them. The aqueduct isle is the base (where
## the pilot starts); 3 or 4 motif isles are drawn from POOL by weight
## (the families rolled through their own seed and knobs), stood one off
## another along a guaranteed route that climbs to the exit, a gate on the
## highest isle; one more hangs off it as the greed branch, a rune set on
## its perch. studies/run_layer.gd builds it.
##
## An isle is placed only by moving it (no turn): an edge leaves a rim of a
## placed isle (KitMotif `socket` "rim": its facing out over the drop) and
## comes in at a rim of the next facing back, the next isle stood where
## that rim lands. Every isle's occupancy (scripts/roguelike/
## layer_pieces.gd: per 2 m cell its lowest and highest solid; a rolled
## broken ring its footprint's box) is kept CLEAR of every other's, and
## every edge's corridor (the pilot's body along it, the stones under him)
## of every isle and edge; an isle may stand over another (a missed jump
## lands lower), never in it.
##
## The edges (`edge`), each sized from the pilot's own numbers (KitMotif
## `pilot`, as the traps' `pilot()`; AGENTS.md, Sizes), so the route is
## solvable by construction: stones (each stride a share of his running
## small jump's reach at that stride's rise, `reach`), a rope bridge
## (scripts/footbridge.gd: a span of his hops, a gentle grade), the Loose
## Voussoirs trap (scripts/traps/trap_voussoirs.gd: its slabs from lip to
## lip, level), and on the greed branch harder stones (nearer his reach,
## smaller) and, where a shot lands it, the cannon (scripts/cannon/
## cannon.gd, `landing_for`) with kegs to range it.
##
## The same seed gives the same plan: `make(seed)`.
const KitMotif = preload("res://scripts/kit_isle/kit_motif.gd")
const LayerPieces = preload("res://scripts/roguelike/layer_pieces.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")
const Voussoirs = preload("res://scripts/traps/trap_voussoirs.gd")

## The pool: [id, script, weight]. The colonnade spine and the Sundered
## gorge weighted up (the user's strongest), the stair to the clouds a
## climb, the broken ring and the bell spires fillers.
const POOL := [
	["colonnade_spine",preload("res://scripts/kit_isle/motif_colonnade_spine.gd"),3.0],
	["sundered_gorge",preload("res://scripts/kit_isle/motif_sundered_gorge.gd"),3.0],
	["stair_clouds",preload("res://scripts/kit_isle/motif_stair_clouds.gd"),1.5],
	["broken_ring",preload("res://scripts/kit_isle/motif_broken_ring.gd"),1.0],
	["bell_spires",preload("res://scripts/kit_isle/motif_bell_spires.gd"),1.0],
]
const BASE := "aqueduct_isle"
## The aqueduct isle's middle (world), what the layer keeps round.
const MIDDLE := Vector3(85.0,30.0,-20.0)
## Whole draws tried for a seed before the last is kept with its problems.
const ATTEMPTS := 60
## Edges tried for each step.
const TRIES := 240
## Clear between two isles where one stands over the other (m), and round
## an edge's corridor.
const CLEAR := 4.0
## An edge's corridor: under its path this deep (the stones and their
## clods), over it this high (the pilot), this wide either side (m).
const UNDER := 2.6
const OVER := 2.6
const SIDE := 1.0
## Near its own rims an isle doesn't count against the edge (m, flat).
const OWN_NEAR := 6.0
## The most an edge's way turns off a rim's facing (degrees).
const TURN_MOST := 30.0
## The layer keeps within this of MIDDLE (m, flat).
const BAND := 240.0
## The void: this far under the lowest solid of any isle.
const VOID_UNDER := 25.0
## How much a placing that stands over another isle (a soft fall) is
## preferred: points per share of it over.
const OVER_WEIGHT := 12.0
## The pilot starts this far back along the first rim's run-up (at most).
const SPAWN_BACK := 6.0
## The cannon stands this far behind its rim; its shot lands this far in
## from the greed isle's rim; how close is a landing (m).
const CANNON_BACK := 2.5
const SHOT_IN := 2.5
const SHOT_NEAR := 0.75
## The ram wants an arena this roomy, this far from any rim used (m).
const RAM_ROOM := 4.5
const RAM_CLEAR := 8.0
## The runes round the perch.
const RUNES := 5

# --- The pilot's reach ----------------------------------------------------------------

static var _pilot: PilotMotor
static func pilot() -> PilotMotor:
	if _pilot == null: _pilot = KitMotif.pilot()
	return _pilot

## How far (m, flat) his running small jump carries him before it comes
## down to `rise` over where it left (rising at his gravity, falling
## `fall` times as hard): the furthest a gap rising `rise` may be.
static func reach(rise: float) -> float:
	var p := pilot()
	var j := float(p.jumps[0])
	if rise >= j: return 0.0
	return p.run*(sqrt(2.0*j/p.gravity)+sqrt(2.0*(j-rise)/(p.gravity*p.fall)))

## The same for the pump (his second jump in a chain, JUMPS[1]): what he
## jumps if he leaps again within the chain's window of landing, as a
## runner across stones does.
static func pump_reach(rise: float) -> float:
	var p := pilot()
	var j := float(p.jumps[1])
	if rise >= j: return 0.0
	return p.run*(sqrt(2.0*j/p.gravity)+sqrt(2.0*(j-rise)/(p.gravity*p.fall)))

## How far (m, flat) before the same jump has risen `rise` (a gap rising
## `rise` shorter than this he meets the far side's face, not its top).
static func clears(rise: float) -> float:
	var p := pilot()
	var j := float(p.jumps[0])
	if rise <= 0.0: return 0.0
	var v := sqrt(2.0*p.gravity*j)
	return p.run*(v-sqrt(maxf(v*v-2.0*p.gravity*rise,0.0)))/p.gravity

## A stepping stone's length along the way and its width: a share of his
## walk's second (the ring's stones, 1.5-1.7 m at his size); the greed
## branch's smaller.
static func stone_length(hard := false) -> float:
	return pilot().walk*(0.45 if hard else 0.7)

## A route stride's gap as a share of his small jump's reach at its rise;
## the greed branch's; how far past the pump's reach a stone's far end
## stands (a share of it).
const GAP_SHARE := Vector2(0.72,0.84)
const GAP_HARD := Vector2(0.86,0.93)
const PUMP_ROOM := 1.08

## A rope bridge's span (m): from SPAN_HOPS of his running hops; its grade
## at most a share of the footbridge's.
const SPAN_HOPS := Vector2(2.6,5.4)
const GRADE := 0.5

# --- Making it ------------------------------------------------------------------------

## The plan for `seed_value`: {seed, isles, edges, route, exit, spawn, prize,
## cannon, ram, void_y, problems}. Isles: {key, id, script, seed, knobs,
## role ("base", "route", "greed"), offset, sockets (world), occ}. Edges:
## {kind, branch, from, to ([isle index, rim name]), a, b (the lips),
## dir, stones, trap, path}.
static func make(seed_value: int) -> Dictionary:
	var plan := {}
	for attempt in range(ATTEMPTS):
		plan = _make(seed_value,attempt)
		if (plan.problems as Array).is_empty(): break
	return plan

## Prints each step's cost (the bake and the test's).
static var trace := false

static func _make(seed_value: int, attempt: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,attempt,"layer"])
	var plan := {"seed":seed_value,"attempt":attempt,"isles":[],"edges":[],"route":[],"exit":{},"spawn":{},"prize":{},"cannon":{},"ram":{},
		"void_y":0.0,"problems":[]}
	# The picks: 3 or 4 of the pool by weight, none twice.
	var count := rng.randi_range(3,4)
	var picks: Array = []
	var pool: Array = POOL.duplicate()
	while picks.size() < count and not pool.is_empty():
		var total := 0.0
		for p: Array in pool: total += float(p[2])
		var roll := rng.randf()*total
		for i in range(pool.size()):
			roll -= float(pool[i][2])
			if roll <= 0.0 or i == pool.size()-1:
				picks.append(pool[i])
				pool.remove_at(i)
				break
	var base := _base_isle()
	base.sockets = base.own.duplicate()
	plan.isles.append(base)
	var motifs: Array = []
	for p: Array in picks: motifs.append(_motif_isle(p,rng))
	# The greed isle: drawn, the smaller the likelier; the route climbs
	# through the rest, the one with the most climb in it last (the exit is
	# on the highest).
	# A hero (the colonnade) is a landmark of the route, never the branch.
	var can: Array = motifs.filter(func(m: Dictionary) -> bool: return m.motif.role() != "hero")
	var total_inv := 0.0
	for m: Dictionary in can: total_inv += 1.0/_area(m)
	var draw := rng.randf()*total_inv
	var greed: Dictionary = can[can.size()-1]
	for m: Dictionary in can:
		draw -= 1.0/_area(m)
		if draw <= 0.0:
			greed = m
			break
	motifs.erase(greed)
	motifs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _climb(a) < _climb(b))
	# Past the first draw, the route in any order.
	if attempt > 0: _shuffle(motifs,rng)
	# The route.
	var used := {}
	var from := 0
	var traps_left := 1
	for k in range(motifs.size()):
		var m: Dictionary = motifs[k]
		m.role = "route"
		var last := k == motifs.size()-1
		var kinds := ["trap"] if traps_left > 0 and (rng.randf() < 0.5 or last) else ["stones","bridge","stones"]
		# The last stands over every other (the exit is on the highest).
		var least := -INF
		if last:
			for isle: Dictionary in plan.isles: least = maxf(least,_top_walked(isle)+1.0)
		var got := _step(plan,from,m,kinds,"route",used,rng,least)
		if got.is_empty() and kinds[0] == "trap":
			got = _step(plan,from,m,["stones","bridge"],"route",used,rng,least)
		elif not got.is_empty() and kinds[0] == "trap": traps_left -= 1
		if got.is_empty():
			plan.problems.append("no way onto %s" % m.id)
			return plan
		from = plan.isles.size()-1
	if traps_left > 0: plan.problems.append("no trap edge on the route")
	for i in range(plan.isles.size()): plan.route.append(i)
	# The exit: the highest rim left on the last isle, its gate.
	var top: Dictionary = plan.isles[from]
	var exit := {}
	for s: Dictionary in top.sockets:
		if s.kind != "rim" or used.has(_key(from,s.name)): continue
		if exit.is_empty() or (s.at as Vector3).y > (exit.at as Vector3).y: exit = s
	if exit.is_empty():
		plan.problems.append("no exit rim on %s" % top.id)
		return plan
	used[_key(from,exit.name)] = true
	plan.exit = {"isle":from,"rim":exit.name,"at":exit.at,"face":exit.face}
	# The greed branch: off a route isle past the base (the base if none),
	# onto the greed isle; the rune set on its roomiest perch.
	greed.role = "greed"
	var starts: Array = range(1,plan.isles.size()) if plan.isles.size() > 1 else [0]
	_shuffle(starts,rng)
	var branched := {}
	var ceiling := _top_walked(plan.isles[from])-1.0
	for s: int in starts+[0]:
		branched = _step(plan,s,greed,["hard"],"greed",used,rng,-INF,ceiling)
		if not branched.is_empty(): break
	if branched.is_empty():
		plan.problems.append("no greed branch onto %s" % greed.id)
		return plan
	var g: int = plan.isles.size()-1
	var perch := {}
	for s: Dictionary in plan.isles[g].sockets:
		if s.kind == "perch" and (perch.is_empty() or float(s.room) > float(perch.room)): perch = s
	if perch.is_empty(): perch = {"at":(branched.to_rim.at as Vector3)-(branched.to_rim.face as Vector3)*3.0,"room":2.0}
	var ring := clampf(float(perch.room)*0.6,1.0,2.2)
	var runes: Array = []
	for i in range(RUNES):
		var a := TAU*i/RUNES
		runes.append((perch.at as Vector3)+Vector3(cos(a)*ring,1.0,sin(a)*ring))
	plan.prize = {"isle":g,"at":perch.at,"room":perch.room,"runes":runes}
	# The highest: the exit's isle stands over the rest.
	var exit_y := _top_walked(plan.isles[from])
	for i in range(plan.isles.size()):
		if i == from: continue
		if _top_walked(plan.isles[i]) > exit_y:
			plan.problems.append("%s stands higher than the exit" % plan.isles[i].id)
			return plan
	_cannon(plan,branched,rng)
	_ram(plan,used)
	# The spawn: back along the first edge's rim's run-up on the base.
	var first: Dictionary = plan.edges[0]
	var rim: Dictionary = first.from_rim
	var back := minf(float(rim.run_up)*0.7,SPAWN_BACK)
	plan.spawn = {"at":(rim.at as Vector3)-(rim.face as Vector3)*back+Vector3.UP*0.2,"face":rim.face}
	var low := INF
	for isle: Dictionary in plan.isles: low = minf(low,_span(isle).x)
	plan.void_y = low-VOID_UNDER
	return plan

static func _key(isle: int, rim: String) -> String:
	return "%d/%s" % [isle,rim]

# --- The isles ----------------------------------------------------------------------

## The aqueduct isle as an isle record (stood at the origin).
static func _base_isle() -> Dictionary:
	return {"key":BASE,"id":BASE,"script":null,"seed":-1,"knobs":{},"role":"base","offset":Vector3.ZERO,
		"own":LayerPieces.sockets(BASE).filter(func(s: Dictionary) -> bool: return s.kind == "rim"),"occ":LayerPieces.occupancy(BASE),"sockets":[]}

## A pool pick as an isle record, a family configured from `rng` (its own
## seed and knobs), its sockets read in its own frame (`own`).
static func _motif_isle(pick: Array, rng: RandomNumberGenerator) -> Dictionary:
	var script: Script = pick[1]
	var m: RefCounted = script.new()
	var isle_seed := -1
	if m.family():
		isle_seed = rng.randi_range(1,9999)
		m.configure(isle_seed)
	var own: Array = []
	for s: Dictionary in m.sockets():
		var c := s.duplicate()
		if not c.has("lip"): c.lip = float(s.room) if s.kind == "rim" else 0.0
		own.append(c)
	# The colonnade's tail rim only with both its bridges holding (else its
	# fragments may be out of reach on foot).
	if m.id() == "colonnade_spine" and str(m.knobs.get("bridges","intact")) != "intact":
		own = own.filter(func(s: Dictionary) -> bool: return s.name != "tail")
	var occ := LayerPieces.occupancy(m.id())
	# A rolled ring moves its isles: its occupancy from its plan.
	if m.id() == "broken_ring": occ = _ring_occ(m)
	elif occ.is_empty(): occ = _box_occ(m.footprint(),m.height_span())
	return {"key":"%s_%d" % [m.id(),isle_seed],"id":m.id(),"script":script,"seed":isle_seed,"knobs":m.knobs.duplicate(),"role":"",
		"offset":Vector3.ZERO,"own":own,"occ":occ,"sockets":[],"motif":m}

static func _box_occ(rect: Rect2, span: Vector2) -> Dictionary:
	var cell := 2.0
	var cols := int(ceil(rect.size.x/cell))+2
	var rows := int(ceil(rect.size.y/cell))+2
	var lo := PackedFloat32Array()
	var hi := PackedFloat32Array()
	lo.resize(cols*rows)
	hi.resize(cols*rows)
	lo.fill(span.x)
	hi.fill(span.y)
	return {"origin":rect.position-Vector2.ONE*cell,"cell":cell,"cols":cols,"rows":rows,"lo":lo,"hi":hi}

## A broken ring's occupancy from its plan (studies/broken_ring_isle_art.gd):
## its central isle and each satellite a disc from its keel (the art's
## depths) to RING_OVER over its top (the circle, the turret, the notes),
## each floating stone a small block.
const RING_OVER := 10.0
static func _ring_occ(m: RefCounted) -> Dictionary:
	var Ring: GDScript = m.Ring
	var p: Dictionary = m.plan()
	var occ := _box_occ(m.footprint().grow(2.0),Vector2(INF,-INF))
	var discs: Array = [[Ring.C,float(Ring.CENTRE_R)*1.08,float(Ring.centre_top(p))-24.0,float(Ring.centre_top(p))+RING_OVER]]
	for sat: Dictionary in Ring.sats(p):
		discs.append([sat.c,float(sat.r)*1.08,float(sat.top)-7.0-float(sat.r),float(sat.top)+RING_OVER*0.7])
	for st: Dictionary in Ring.platforms(p):
		var at: Vector3 = st.at
		discs.append([Vector2(at.x,at.z),1.4,at.y-2.6,at.y+0.2])
	var lo: PackedFloat32Array = occ.lo
	var hi: PackedFloat32Array = occ.hi
	var cell: float = occ.cell
	var origin: Vector2 = occ.origin
	for k in range(lo.size()):
		var q := origin+Vector2(k%int(occ.cols)+0.5,k/int(occ.cols)+0.5)*cell
		for d: Array in discs:
			if q.distance_to(d[0]) > float(d[1])+cell*0.75: continue
			lo[k] = minf(lo[k],float(d[2]))
			hi[k] = maxf(hi[k],float(d[3]))
	occ.lo = lo
	occ.hi = hi
	return occ

static func _area(isle: Dictionary) -> float:
	var o: Dictionary = isle.occ
	return float(o.cols)*float(o.rows)

## How far its rims climb (m): its highest rim over its lowest.
static func _climb(isle: Dictionary) -> float:
	var lo := INF
	var hi := -INF
	for s: Dictionary in isle.own:
		if s.kind != "rim": continue
		lo = minf(lo,(s.at as Vector3).y)
		hi = maxf(hi,(s.at as Vector3).y)
	return hi-lo if hi > lo else 0.0

## Its highest walked point (world): its rims and spots.
static func _top_walked(isle: Dictionary) -> float:
	var h := -INF
	for s: Dictionary in isle.own: h = maxf(h,(s.at as Vector3).y)
	return h+(isle.offset as Vector3).y

## Its lowest and highest solid (world y).
static func _span(isle: Dictionary) -> Vector2:
	var o: Dictionary = isle.occ
	if not o.has("_span"):
		var span := Vector2(INF,-INF)
		for v: float in o.lo: if v < INF: span.x = minf(span.x,v)
		for v: float in o.hi: if v > -INF: span.y = maxf(span.y,v)
		o._span = span
	return (o._span as Vector2)+Vector2.ONE*(isle.offset as Vector3).y

## Its rect (world x, z).
static func _rect(isle: Dictionary) -> Rect2:
	var o: Dictionary = isle.occ
	var off: Vector3 = isle.offset
	return Rect2((o.origin as Vector2)+Vector2(off.x,off.z),Vector2(float(o.cols),float(o.rows))*float(o.cell))

## Its lowest and highest solid at (x, z) (world), Vector2(INF, -INF) for
## none.
static func occ_at(isle: Dictionary, x: float, z: float) -> Vector2:
	return _grid_at(isle.occ,isle.offset,x,z)

static func _grid_at(o: Dictionary, off: Vector3, x: float, z: float) -> Vector2:
	var origin: Vector2 = o.origin
	var c := int(floor((x-off.x-origin.x)/float(o.cell)))
	var r := int(floor((z-off.z-origin.y)/float(o.cell)))
	if c < 0 or r < 0 or c >= int(o.cols) or r >= int(o.rows): return Vector2(INF,-INF)
	var k := r*int(o.cols)+c
	var lo: float = (o.lo as PackedFloat32Array)[k]
	if lo == INF: return Vector2(INF,-INF)
	return Vector2(lo+off.y,(o.hi as PackedFloat32Array)[k]+off.y)

## Its occupancy COARSE cells to a side merged (each the lowest and highest
## of its cells), made once: what `clash` looks at first.
const COARSE := 4
static func _coarse(o: Dictionary) -> Dictionary:
	if o.has("_coarse"): return o._coarse
	var cols := int(ceil(float(o.cols)/COARSE))
	var rows := int(ceil(float(o.rows)/COARSE))
	var lo := PackedFloat32Array()
	var hi := PackedFloat32Array()
	lo.resize(cols*rows)
	hi.resize(cols*rows)
	lo.fill(INF)
	hi.fill(-INF)
	var flo: PackedFloat32Array = o.lo
	var fhi: PackedFloat32Array = o.hi
	for k in range(flo.size()):
		if flo[k] == INF: continue
		var ck := (k/int(o.cols))/COARSE*cols+(k%int(o.cols))/COARSE
		lo[ck] = minf(lo[ck],flo[k])
		hi[ck] = maxf(hi[ck],fhi[k])
	o._coarse = {"origin":o.origin,"cell":float(o.cell)*COARSE,"cols":cols,"rows":rows,"lo":lo,"hi":hi}
	return o._coarse

## Whether two isles stand in each other (CLEAR kept over and under): their
## coarse cells first, the fine ones only where those meet.
static func clash(a: Dictionary, b: Dictionary) -> bool:
	var ra := _rect(a)
	var rb := _rect(b)
	if not ra.intersects(rb): return false
	var sa := _span(a)
	var sb := _span(b)
	if sa.y+CLEAR < sb.x or sb.y+CLEAR < sa.x: return false
	var both := ra.intersection(rb)
	var cb := _coarse(b.occ)
	var ca := _coarse(a.occ)
	var off_a: Vector3 = a.offset
	var off_b: Vector3 = b.offset
	var big: float = cb.cell
	var ob: Vector2 = (cb.origin as Vector2)+Vector2(off_b.x,off_b.z)
	var c0 := maxi(int(floor((both.position.x-ob.x)/big)),0)
	var c1 := mini(int(floor((both.end.x-ob.x)/big)),int(cb.cols)-1)
	var r0 := maxi(int(floor((both.position.y-ob.y)/big)),0)
	var r1 := mini(int(floor((both.end.y-ob.y)/big)),int(cb.rows)-1)
	var cell: float = b.occ.cell
	for r in range(r0,r1+1):
		for c in range(c0,c1+1):
			var hb := _grid_at(cb,off_b,ob.x-off_b.x+off_b.x+(c+0.5)*big,ob.y+(r+0.5)*big)
			if hb.x == INF: continue
			# The other's coarse cells under this one's corners and middle.
			var ha := Vector2(INF,-INF)
			for o: Vector2 in [Vector2(0.01,0.01),Vector2(0.99,0.01),Vector2(0.01,0.99),Vector2(0.99,0.99),Vector2(0.5,0.5)]:
				var h := _grid_at(ca,off_a,ob.x+(c+o.x)*big,ob.y+(r+o.y)*big)
				ha = Vector2(minf(ha.x,h.x),maxf(ha.y,h.y))
			if ha.x == INF or ha.x >= hb.y+CLEAR or hb.x >= ha.y+CLEAR: continue
			# Fine, within this coarse cell.
			var x := ob.x+c*big+cell*0.5
			while x < ob.x+(c+1)*big:
				var z := ob.y+r*big+cell*0.5
				while z < ob.y+(r+1)*big:
					var fb := occ_at(b,x,z)
					if fb.x < INF:
						var fa := occ_at(a,x,z)
						if fa.x < INF and fa.x < fb.y+CLEAR and fb.x < fa.y+CLEAR: return true
					z += cell
				x += cell
	return false

## How much of `b` stands over another isle (a share of its coarse cells):
## a missed jump off it lands lower.
static func over_share(plan: Dictionary, b: Dictionary) -> float:
	var cb := _coarse(b.occ)
	var off_b: Vector3 = b.offset
	var ob: Vector2 = (cb.origin as Vector2)+Vector2(off_b.x,off_b.z)
	var n := 0
	var over := 0
	for r in range(int(cb.rows)):
		for c in range(int(cb.cols)):
			var x := ob.x+(c+0.5)*float(cb.cell)
			var z := ob.y+(r+0.5)*float(cb.cell)
			var hb := _grid_at(cb,off_b,x,z)
			if hb.x == INF: continue
			n += 1
			for a: Dictionary in plan.isles:
				if a == b: continue
				var ha := occ_at(a,x,z)
				if ha.x < INF and ha.y < hb.x:
					over += 1
					break
	return float(over)/maxf(n,1)

# --- The edges ----------------------------------------------------------------------

## The next isle `m` stood off isle `from` by an edge of one of `kinds`
## (tried TRIES times, the best kept; its highest walked point between `least`
## and `most`): the edge appended to the plan, `m`
## placed and appended; the edge, or {} if none fits.
static func _step(plan: Dictionary, from: int, m: Dictionary, kinds: Array, branch: String, used: Dictionary, rng: RandomNumberGenerator,
		least := -INF, most := INF) -> Dictionary:
	var a: Dictionary = plan.isles[from]
	var outs: Array = a.own.filter(func(s: Dictionary) -> bool: return s.kind == "rim" and not used.has(_key(from,s.name)))
	var ins: Array = m.own.filter(func(s: Dictionary) -> bool: return s.kind == "rim")
	# A family's way through: in at its entry, out at its exit (the ring).
	if ins.any(func(s: Dictionary) -> bool: return s.name == "entry"): ins = ins.filter(func(s: Dictionary) -> bool: return s.name == "entry")
	if from > 0 and outs.any(func(s: Dictionary) -> bool: return s.name == "exit"): outs = outs.filter(func(s: Dictionary) -> bool: return s.name == "exit")
	if outs.is_empty() or ins.is_empty(): return {}
	var off_a: Vector3 = a.offset
	var began := Time.get_ticks_msec()
	var why := {}
	var best := {}
	var best_score := -INF
	# Every out rim and in rim that face each other, each kind, in a shuffled
	# order: TRIES of them tried.
	var combos: Array = []
	for ra: Dictionary in outs:
		for rb: Dictionary in ins:
			if (ra.face as Vector3).dot(-(rb.face as Vector3)) < cos(deg_to_rad(TURN_MOST*2.0)): continue
			for kind: String in kinds: combos.append([ra,rb,kind])
	for i in range(combos.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap: Variant = combos[i]
		combos[i] = combos[j]
		combos[j] = swap
	for t in range(TRIES):
		if combos.is_empty(): break
		var combo: Array = combos[t%combos.size()]
		var ra: Dictionary = combo[0]
		var rb: Dictionary = combo[1]
		var kind: String = combo[2]
		var fa: Vector3 = ra.face
		var fb: Vector3 = rb.face
		var dir := (fa-fb).normalized()
		if dir.dot(fa) < cos(deg_to_rad(TURN_MOST)) or dir.dot(-fb) < cos(deg_to_rad(TURN_MOST)): continue
		if kind in ["stones","hard"] and float(ra.run_up) < 1.5: continue
		if kind == "hard" and float(ra.run_up) < CANNON_BACK+1.0: continue
		var lip_a: Vector3 = (ra.at as Vector3)+off_a+fa*float(ra.lip)
		var shape := _shape(kind,lip_a,dir,rng)
		if shape.is_empty(): continue
		var lip_b: Vector3 = shape.b
		var at_b: Vector3 = lip_b-fb*float(rb.lip)
		var off_b: Vector3 = at_b-(rb.at as Vector3)
		var placed := m.duplicate()
		placed.offset = off_b
		var top_b := _top_walked(placed)
		if top_b < least or top_b > most:
			why.height = why.get("height",0)+1
			continue
		# Kept within the band round the base.
		var mid := _rect(placed).get_center()
		if mid.distance_to(Vector2(MIDDLE.x,MIDDLE.z)) > BAND:
			why.band = why.get("band",0)+1
			continue
		var bad := false
		for other: Dictionary in plan.isles:
			if clash(other,placed):
				bad = true
				break
		if bad:
			why.clash = why.get("clash",0)+1
			continue
		var edge := {"kind":kind,"branch":branch,"from":[from,ra.name],"to":[plan.isles.size(),rb.name],"a":lip_a,"b":lip_b,"dir":dir,
			"stones":shape.stones,"bridges":shape.bridges,"parts":shape.parts,"trap":shape.trap,"path":shape.path,"from_rim":_world(ra,off_a),"to_rim":_world(rb,off_b)}
		var isles: Array = plan.isles+[placed]
		if not _corridor_clear(edge,isles,from,isles.size()-1):
			why.corridor = why.get("corridor",0)+1
			continue
		if _crosses(edge,plan.edges):
			why.crosses = why.get("crosses",0)+1
			continue
		if _covers_edges(placed,plan.edges):
			why.covers = why.get("covers",0)+1
			continue
		# The best: climbing, over another isle (a soft fall), near the base.
		var score := rng.randf()*2.0
		score += 0.15*(lip_b.y-lip_a.y)
		score += OVER_WEIGHT*over_share(plan,placed)
		score -= 0.01*mid.distance_to(Vector2(MIDDLE.x,MIDDLE.z))
		if score > best_score:
			best_score = score
			best = {"edge":edge,"isle":placed}
	if trace: print("layer plan: step %d -> %s %s, %d ms %s" % [from,m.id,kinds,Time.get_ticks_msec()-began,why])
	if best.is_empty(): return {}
	var placed_isle: Dictionary = best.isle
	placed_isle.sockets = []
	for s: Dictionary in placed_isle.own: placed_isle.sockets.append(_world(s,placed_isle.offset))
	plan.isles.append(placed_isle)
	var e: Dictionary = best.edge
	if not (e.trap as Dictionary).is_empty(): e.trap.under = _under(e,plan.isles)
	plan.edges.append(e)
	used[_key(from,e.from[1])] = true
	used[_key(e.to[0],e.to[1])] = true
	return e

static func _world(s: Dictionary, off: Vector3) -> Dictionary:
	var w := s.duplicate()
	w.at = (s.at as Vector3)+off
	return w

## An edge of `kind` leaving lip `a` along `dir`: {b (its far lip), path
## (samples [point, under, over]), stones (floating stones' platforms),
## bridges ([a, b] deck ends), trap ({frame, count, under}), parts (what it
## is made of, in order)}, sized from the pilot. Rims stand tens of metres
## apart, so most edges are made of parts: a run of stones up to a landing
## (a floating slab), then a rope bridge or the trap from it; or a long run
## of stones.
static func _shape(kind: String, a: Vector3, dir: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var out := {"stones":[],"bridges":[],"trap":{},"parts":[],"path":[]}
	var chain := "%s_%d_%d" % [kind,roundi(a.x),roundi(a.z)]
	var p := a
	match kind:
		"stones":
			p = _lay_stones(out,p,dir,rng.randi_range(4,9),false,rng,chain)
		"hard":
			p = _lay_stones(out,p,dir,rng.randi_range(3,6),true,rng,chain)
		"bridge":
			if rng.randf() < 0.6:
				p = _lay_stones(out,p,dir,rng.randi_range(2,5),false,rng,chain)
				p = _landing(out,p,dir,chain)
			var hop := KitMotif.hop_reach()
			var span := clampf(hop*rng.randf_range(SPAN_HOPS.x,SPAN_HOPS.y),Footbridge.TIMBER_SPAN,Footbridge.MAX_SPAN)
			var rise := span*Footbridge.MAX_GRADE*GRADE*rng.randf_range(0.0,1.0)
			var b := p+dir*span+Vector3.UP*rise
			out.bridges.append([p,b])
			out.parts.append("bridge %.1f m" % span)
			out.path.append_array(_line(p,b,Footbridge.bow(span)+0.6))
			p = b
		"trap":
			if rng.randf() < 0.7:
				p = _lay_stones(out,p,dir,rng.randi_range(2,5),false,rng,chain)
				p = _landing(out,p,dir,chain)
			var slab := slab_length()
			var count := rng.randi_range(6,9)
			var over := slab*0.25
			var length := count*slab-2.0*over
			var b := p+dir*length
			out.trap = {"frame":Transform3D(Basis.looking_at(dir,Vector3.UP),p-dir*over),"count":count,"under":"void"}
			out.parts.append("voussoirs x%d" % count)
			out.path.append_array(_line(p,b,1.0))
			p = b
	out.b = p
	return out

static var _slab := 0.0
## The Loose Voussoirs' slab length (its own default, from the pilot's walk).
static func slab_length() -> float:
	if _slab == 0.0:
		var v: Node3D = Voussoirs.new()
		_slab = float(v.defaults().length)
		v.free()
	return _slab

## `n` stones on from `p` (the lip or a landing's far edge) along `dir`,
## each stride a gap a share of his reach at its rise, into `out`; answers
## where the next part's near edge stands (one more stride on).
static func _lay_stones(out: Dictionary, p: Vector3, dir: Vector3, n: int, hard: bool, rng: RandomNumberGenerator, chain: String) -> Vector3:
	var j := float(pilot().jumps[0])
	var h := j*(rng.randf_range(0.0,0.4) if hard else rng.randf_range(0.15,0.5))
	# Each gap a share of his small jump's reach at its rise (the greed
	# branch's nearer it); each stone long enough that the pump (a jump
	# straight off a landing, as a runner chains them) still comes down on
	# the next, not past it.
	var gap := reach(h)*(rng.randf_range(GAP_HARD.x,GAP_HARD.y) if hard else rng.randf_range(GAP_SHARE.x,GAP_SHARE.y))
	gap = maxf(gap,clears(h)+0.3)
	var length := maxf(stone_length(hard),pump_reach(h)*PUMP_ROOM-gap)
	var yaw := atan2(-dir.z,dir.x)
	var first: int = (out.stones as Array).size()
	for k in range(n):
		var top := p+dir*(gap*(k+1)+length*(k+0.5))+Vector3.UP*h*(k+1)
		out.stones.append({"name":"%s_%d" % [chain,first+k+1],"at":top,"size":Vector3(length,0.7 if k%2 == 0 else 0.9,length*(0.95 if hard else 1.0)),
			"yaw":yaw+(0.12 if k%2 else -0.08),"kind":"block","chain":chain,"gap":gap,"rise":h})
	var next := p+dir*(gap*(n+1)+length*n)+Vector3.UP*h*(n+1)
	out.parts.append("%d stones (gap %.2f, rise %.2f)" % [n,gap,h])
	out.path.append_array(_line(p,next,UNDER))
	return next

## A landing: a broad floating slab whose near edge is at `p`; answers its
## far edge (on its top).
static func _landing(out: Dictionary, p: Vector3, dir: Vector3, chain: String) -> Vector3:
	var size := landing_size()
	var top := p+dir*size*0.5
	out.stones.append({"name":"%s_landing" % chain,"at":top,"size":Vector3(size,1.0,size),"yaw":atan2(-dir.z,dir.x),"kind":"block","chain":chain,"landing":true})
	out.parts.append("landing")
	var far := p+dir*size
	out.path.append_array(_line(p,far,UNDER))
	return far

## A landing's side (m): a running half second of his, room for a bridge's
## anchors.
static func landing_size() -> float:
	return pilot().run*0.6

## Samples along a straight edge from `a` to `b` every half metre:
## [point, how deep under it, how high over it].
static func _line(a: Vector3, b: Vector3, under: float) -> Array:
	var out: Array = []
	var n := maxi(int(ceil(a.distance_to(b)/0.5)),1)
	for i in range(n+1):
		out.append([a.lerp(b,float(i)/n),under,OVER])
	return out

## Whether the edge's corridor is clear of every isle (its own two only
## past OWN_NEAR of its lips).
static func _corridor_clear(edge: Dictionary, isles: Array, from: int, to: int) -> bool:
	var a: Vector3 = edge.a
	var b: Vector3 = edge.b
	var dir: Vector3 = edge.dir
	var side := dir.cross(Vector3.UP).normalized()
	for s: Array in edge.path:
		var p: Vector3 = s[0]
		var lo := p.y-float(s[1])
		var hi := p.y+float(s[2])
		var near_a := Vector2(p.x-a.x,p.z-a.z).length() < OWN_NEAR
		var near_b := Vector2(p.x-b.x,p.z-b.z).length() < OWN_NEAR
		for i in range(isles.size()):
			if (i == from and near_a) or (i == to and near_b): continue
			for off: float in [-SIDE,0.0,SIDE]:
				var q := p+side*off
				var o := occ_at(isles[i],q.x,q.z)
				if o.x < INF and o.x < hi+CLEAR*0.5 and lo-CLEAR*0.5 < o.y: return false
	return true

## Whether the edge comes within CLEAR of another edge's corridor.
static func _crosses(edge: Dictionary, edges: Array) -> bool:
	for e: Dictionary in edges:
		for s: Array in edge.path:
			var p: Vector3 = s[0]
			for t: Array in e.path:
				var q: Vector3 = t[0]
				if Vector2(p.x-q.x,p.z-q.z).length() < CLEAR and absf(p.y-q.y) < OVER+UNDER+CLEAR: return true
	return false

## Whether the isle stands in an edge laid before.
static func _covers_edges(isle: Dictionary, edges: Array) -> bool:
	for e: Dictionary in edges:
		for s: Array in e.path:
			var p: Vector3 = s[0]
			var o := occ_at(isle,p.x,p.z)
			if o.x < INF and o.x < p.y+float(s[2])+CLEAR*0.5 and p.y-float(s[1])-CLEAR*0.5 < o.y: return true
	return false

## What is under a trap's slabs: "layer" if any isle is under its middle
## half, else "void".
static func _under(edge: Dictionary, isles: Array) -> String:
	var path: Array = edge.path
	for i in range(path.size()/4,path.size()*3/4):
		var p: Vector3 = path[i][0]
		for isle: Dictionary in isles:
			if occ_at(isle,p.x,p.z).y < p.y-2.0: return "layer"
	return "void"

# --- The greed branch's cannon, the ram ---------------------------------------------

## A cannon behind the greed branch's rim whose shot (at some power and
## pitch, aimed at the greed isle) lands SHOT_IN past its rim, its arc
## clear of every isle; kegs beside it to range it. None if no shot lands.
static func _cannon(plan: Dictionary, edge: Dictionary, _rng: RandomNumberGenerator) -> void:
	var rim: Dictionary = edge.from_rim
	# Further back along the run-up, further in past the far rim, till a
	# shot lands clear.
	for back: float in [CANNON_BACK,CANNON_BACK+1.5,CANNON_BACK+3.0,CANNON_BACK+5.0]:
		if back > float(rim.run_up)-0.5 and back > CANNON_BACK: break
		for inland: float in [SHOT_IN,SHOT_IN+2.0,SHOT_IN+4.0]:
			if _cannon_at(plan,edge,back,inland): return

## The layer's cannon: the cannon's own knobs but its launch a little
## faster (CANNON_RUNS of the pilot's run at full power, the cannon's own
## 5.4), so a shot carries a greed gap tens of metres wide.
const CANNON_RUNS := 6.6
static func cannon_knobs() -> Dictionary:
	var k := Cannon.defaults()
	k.speed_max = pilot().run*CANNON_RUNS
	return k

## Where a shot from the layer's cannon at `base` comes down on flat ground
## at `floor_y` (the cannon's `landing_for`, at its knobs).
static func _shot(base: Vector3, yaw: float, pitch: float, notch: int, floor_y: float) -> Vector3:
	var k := cannon_knobs()
	var f := PilotMotor.forward(yaw)
	var dir := Vector3(f.x*cos(pitch),sin(pitch),f.y*cos(pitch))
	var from: Vector3 = base+Vector3.UP*float(k.base_height)+dir*float(k.barrel_length)
	return Cannon.landing(from,dir*float(k.speed_max)*float(k.power_notches[notch]),floor_y)

static func _cannon_at(plan: Dictionary, edge: Dictionary, back: float, inland: float) -> bool:
	var rim: Dictionary = edge.from_rim
	var to: Dictionary = edge.to_rim
	var face: Vector3 = rim.face
	var base: Vector3 = (rim.at as Vector3)-face*back
	var target: Vector3 = (to.at as Vector3)-(to.face as Vector3)*inland
	var flat := Vector2(target.x-base.x,target.z-base.z)
	var yaw := atan2(-flat.x,-flat.y)
	var k := cannon_knobs()
	for notch in range((k.power_notches as Array).size()):
		var lo := float(k.pitch_min)
		var hi := deg_to_rad(45.0)
		# The low arc: further as it pitches up to 45 degrees.
		var far := _shot(base,yaw,hi,notch,target.y)
		var near := _shot(base,yaw,lo,notch,target.y)
		var want := flat.length()
		if Vector2(far.x-base.x,far.z-base.z).length() < want or Vector2(near.x-base.x,near.z-base.z).length() > want: continue
		for i in range(30):
			var mid := (lo+hi)*0.5
			var land := _shot(base,yaw,mid,notch,target.y)
			if Vector2(land.x-base.x,land.z-base.z).length() < want: lo = mid
			else: hi = mid
		var pitch := (lo+hi)*0.5
		var landing := _shot(base,yaw,pitch,notch,target.y)
		if Vector2(landing.x-target.x,landing.z-target.z).length() > SHOT_NEAR: continue
		if not _arc_clear(plan,base,yaw,pitch,notch,target,edge,back,inland): continue
		var side := face.cross(Vector3.UP).normalized()
		var keg_at := (rim.at as Vector3)-face*0.6
		plan.cannon = {"at":base,"heading":yaw,"pitch":pitch,"notch":notch,"target":target,"landing":landing,
			"kegs":[keg_at+side*1.4+Vector3.UP*0.05,keg_at-side*1.4+Vector3.UP*0.05,base+face*1.2+side*1.6+Vector3.UP*0.05]}
		return true
	return false

## The shot's arc clear of every isle (but the two it leaves and lands on
## near its ends).
static func _arc_clear(plan: Dictionary, base: Vector3, yaw: float, pitch: float, notch: int, target: Vector3, edge: Dictionary, back: float, inland: float) -> bool:
	var k := cannon_knobs()
	var f := PilotMotor.forward(yaw)
	var dir := Vector3(f.x*cos(pitch),sin(pitch),f.y*cos(pitch))
	var from: Vector3 = base+Vector3.UP*float(k.base_height)+dir*float(k.barrel_length)
	var pts := Cannon.flight(from,dir*float(k.speed_max)*float(k.power_notches[notch]),pilot(),1.0/60.0,30.0,target.y)
	var a: int = edge.from[0]
	var b: int = edge.to[0]
	for p: Vector3 in pts:
		for i in range(plan.isles.size()):
			if i == a and Vector2(p.x-base.x,p.z-base.z).length() < back+OWN_NEAR: continue
			if i == b and Vector2(p.x-target.x,p.z-target.z).length() < inland+OWN_NEAR: continue
			var o := occ_at(plan.isles[i],p.x,p.z)
			if o.x < INF and o.x < p.y+1.5 and p.y-1.0 < o.y: return false
	return true

## The Plinth Ram on the roomiest arena of a route isle past the base, clear
## of every rim used.
static func _ram(plan: Dictionary, used: Dictionary) -> void:
	var best := {}
	for i in range(1,plan.isles.size()):
		var isle: Dictionary = plan.isles[i]
		if isle.role != "route": continue
		for s: Dictionary in isle.sockets:
			if s.kind != "arena" or float(s.room) < RAM_ROOM: continue
			var clear := true
			for r: Dictionary in isle.sockets:
				if r.kind == "rim" and used.has(_key(i,r.name)) and (r.at as Vector3).distance_to(s.at) < RAM_CLEAR: clear = false
			if clear and (best.is_empty() or float(s.room) > float(best.room)):
				best = s.duplicate()
				best.isle = i
	if not best.is_empty(): plan.ram = {"isle":best.isle,"at":best.at,"face":best.face,"room":best.room}

# --- Reading it -----------------------------------------------------------------------

## One line per isle and edge, for the card and the log.
static func describe(plan: Dictionary) -> String:
	var lines := PackedStringArray()
	for i in range(plan.isles.size()):
		var isle: Dictionary = plan.isles[i]
		var knobs := ""
		if not (isle.knobs as Dictionary).is_empty(): knobs = " seed %d %s" % [int(isle.seed),str(isle.knobs)]
		var over := "" if i == 0 else ", %d%% over another" % roundi(over_share(plan,isle)*100.0)
		lines.append("%d %s (%s)%s at %s%s" % [i,isle.id,isle.role,knobs,str((isle.offset as Vector3).round()),over])
	for e: Dictionary in plan.edges:
		var extra := ": "+", ".join(PackedStringArray(e.parts))
		if not (e.trap as Dictionary).is_empty(): extra += " over the %s" % str(e.trap.under)
		lines.append("%s %s: %d.%s -> %d.%s, %.1f m, rise %.1f m%s" % [e.branch,e.kind,int(e.from[0]),str(e.from[1]),int(e.to[0]),str(e.to[1]),
			Vector2((e.b as Vector3).x-(e.a as Vector3).x,(e.b as Vector3).z-(e.a as Vector3).z).length(),(e.b as Vector3).y-(e.a as Vector3).y,extra])
	if not (plan.cannon as Dictionary).is_empty(): lines.append("cannon: notch %d pitch %.0f deg" % [int(plan.cannon.notch)+1,rad_to_deg(float(plan.cannon.pitch))])
	if not (plan.ram as Dictionary).is_empty(): lines.append("ram on %d" % int(plan.ram.isle))
	if not (plan.problems as Array).is_empty(): lines.append("problems: %s" % str(plan.problems))
	return "\n".join(lines)

static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap: Variant = list[i]
		list[i] = list[j]
		list[j] = swap
