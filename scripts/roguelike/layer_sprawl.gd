extends RefCounted
## The sprawl shape of a generated layer (docs/design/roguelike/
## layer-round4-sprawl.md; `--shape=sprawl` on studies/run_layer.tscn):
## round 3's neighbourhoods, gulfs and rides (scripts/roguelike/
## layer_plan.gd) laid with a lean to one side, the EXIT SIDE, and past the
## last neighbourhood a chain of crossings heading out and up that way, the
## gate at its end; beyond it, higher, the next region (the next seed's
## layer) drawn far off as a hazed silhouette (scripts/roguelike/
## next_region_lod.gd), so from the start you see where you're going.
##
##   - The lean: each seed rolls a heading; LayerPlan scores each isle and
##     gulf placing by how far it stands that way (`_lean`, the knob
##     `lean`), so the neighbourhoods march off to one side. The exit side
##     (`plan.heading`) is the way from the base's middle to the last
##     neighbourhood's.
##   - The exit chain (`plan.chain`, edges of branch "exit"): from a free
##     rim of the last neighbourhood facing the exit side, 4-5 crossings of
##     what the layer already has, each to a floating slab where the way
##     turns a little (a zig-zag on toward the exit side): a run of stones,
##     a rope bridge, the Loose Voussoirs, and a cannon on a broad deck
##     whose shot lands on a catch slab further on; the last slab, the
##     threshold, holds the gate. Every piece is sized from the pilot as
##     round 2's edges are (LayerPlan `_lay_stones`, the footbridge's span
##     and grade, the trap's slabs, the layer cannon's `_aim`) and kept
##     clear of every isle, edge, ride and cannon.
##   - The next region (`plan.next`): the next seed's plan (made here and
##     kept, so going through the gate takes it as it was seen), turned so
##     its own exit side runs on the same way, its base DIST past the gate
##     and `next_rise` higher, raised till the line from the spawn's eye to
##     its landmark (its highest isle's top) is clear of this layer's
##     isles. The spawn is laid looking that way (`_spawn_view`), before
##     the next region is (windowed, after this layer stands).
##   - Taller than round 3 (4B-2): each gulf rises RISE_ROLL, each
##     neighbourhood has an isle more and a tier reached by a climb.
##   - The dragon's roost (`plan.roost`, round 5: docs/design/roguelike/
##     layer-round5-roost.md): the roost motif (scripts/kit_isle/
##     motif_dragon_roost.gd, as it is) stood off to one side of the layer,
##     high over every isle and ROOST_GAP clear of everything, in sight from
##     the spawn and from most neighbourhoods, never in the way of the exit
##     side's view of the next region (`_roost`). No way onto it yet.
## The same seed and knobs give the same plan.
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const KitMotif = preload("res://scripts/kit_isle/kit_motif.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")
const Summit = preload("res://scripts/roguelike/summit.gd")  # [summit]
const NextRegionLod = preload("res://scripts/roguelike/next_region_lod.gd")
const LayerPieces = preload("res://scripts/roguelike/layer_pieces.gd")
const Roost = preload("res://scripts/kit_isle/motif_dragon_roost.gd")
const LayerHazards = preload("res://scripts/roguelike/layer_hazards.gd")
const LayerEnemies = preload("res://scripts/roguelike/layer_enemies.gd")
const MerchantNook = preload("res://scripts/roguelike/merchant_nook.gd")  # [merchant]

## The lean's weight: points per 100 m stood toward the rolled heading
## (LayerPlan `_lean`; a step's random share is 0-2, a gulf's the same).
const LEAN := 1.5
## Taller and fuller than round 3 (LayerPlan's knobs): each gulf rises
## RISE_ROLL m (rolled per gulf; `--knob=rise=` pins it), each
## neighbourhood has HOOD_MORE isles more, and in each one step climbs (a
## `climb` edge: stones stepping up, landings, a bridge up) onto an isle
## standing TIER m over the neighbourhood's lowest.
const RISE_ROLL := Vector2(25.0,60.0)
const HOOD_MORE := 1
const TIER := 8.0
## A motif that is not a family may come this many times a layer (in
## different neighbourhoods, mostly): three of them fill out fuller ones.
const REPEATS := 2
## The exit side is the way to the last neighbourhood's middle unless that
## stands nearer the base than this (m, flat): then the rolled heading.
const SIDE_LEAST := 40.0
## The chain: how many crossings; the stones in a run; how far each slab
## turns the way off the exit side, either way in turn (degrees), and the
## most a way turns off the last; the first way's turn off its rim.
const LINKS := Vector2i(4,5)
const STONES := Vector2i(3,5)
const ZIG := Vector2(10.0,24.0)
const TURN := 40.0
## Its rim: facing within this of the exit side (degrees), this much
## run-up (m); the best few rims tried, each this many rolls.
const RIM_FACING := 80.0
const RIM_RUN_UP := 2.5
## A point for each RIM_OUT m a rim stands further out on the exit side.
const RIM_OUT := 25.0
## The gate at least this far past the last neighbourhood's middle on the
## exit side (m).
const GATE_PAST := 20.0
const CHAIN_RIMS := 4
const CHAIN_TRIES := 8
## The slabs' sides as shares of LayerPlan `landing_size` (his running
## half second): a waystone, the cannon's deck and catch, the threshold.
const WAY := 1.5
const DECK := 2.5
const THRESHOLD := 2.5
## The gate this share of the threshold's side past its middle.
const GATE_ON := 0.3
## The cannon's link: its shot from the deck's middle to the catch's, a
## share of the layer cannon's flat reach (its top notch at 45 degrees),
## rising this many of his chained jumps (JUMPS[1]).
const SHOT := Vector2(0.5,0.7)
const SHOT_RISE := Vector2(2.0,5.0)
const SHOT_INLAND := 2.5
## Clear of a ride's tube past its reach, of a gulf's rims (its piers and
## steps), of a cannon or keg laid before (m).
const RIDE_CLEAR := 6.0
const PIER_CLEAR := 16.0
const CANNON_CLEAR := 4.0
## The next region: its base's middle this far past the gate's slab (m,
## flat, past the region's nearest reach back toward it), its base's turf
## this much over the gate, raised RISE_STEP at a time till its landmark
## is in sight from the spawn (at most RISE_MOST over); kept APART (flat,
## bounds to bounds) from every isle of this layer; seeds tried past one
## that can't be laid (as studies/run_layer.gd SKIP_MOST).
const DIST := 180.0
## Its base's turf over the gate: a gulf's rise (RISE_ROLL, rolled from the
## seed) and RISE_OVER more; where the spawn looks before it is laid, this
## far past the gate (m).
const RISE_OVER := 20.0
const NEXT_ON := 260.0
const RISE_STEP := 20.0
const RISE_MOST := 300.0
const APART := 120.0
const SKIP_MOST := 8
## The eye over the spawn the sight line leaves from (m), and the line's
## samples (m).
const EYE := 1.6
const SIGHT_STEP := 2.0
const SIGHT_MARGIN := 0.3
## The sight line's mark this far under the landmark's highest cell (on it,
## not grazing its tip) (m).
const MARK_UNDER := 3.0
## Where the spawn may move to see it: the base's clear spots this roomy
## (m), this near the spawn round 3 lays (m, the closest first).
const SPOT_ROOM := 1.5
const SPOT_NEAR := 70.0

# --- Making it ------------------------------------------------------------------------

## The sprawl plan for `seed_value`: LayerPlan's (`make`'s keys), the exit
## side (`heading`, flat), the exit chain (`chain`, edge indices; the gate
## at its end in `exit`) and the next region (`next`: NextRegionLod's
## input, see `_place_next`), the spawn turned to face it.
##
## Laid on a worker (windowed play, studies/run_layer.gd), the next region
## is left for later (`attach_next`): `dress` lays it on a worker once this
## layer stands, so the first layer is up after one plan, not two.
static func make(seed_value: int, knobs := {}) -> Dictionary:
	var plan := core(seed_value,knobs)
	if not (plan.problems as Array).is_empty(): return plan
	if OS.get_thread_caller_id() == OS.get_main_thread_id(): attach_next(plan)
	return plan

## The next region laid into `plan` (`plan.next`), or a problem noted.
static func attach_next(plan: Dictionary) -> void:
	if Summit.final_plan(plan): return  # [summit] nothing lies past the summit
	var nxt := next_plan(plan)
	if (nxt.problems as Array).is_empty(): plan.next = _place_next(plan,nxt)
	else: plan.problems.append("no next region laid past seed %d" % int(plan.seed))

## The plan the gate leads to (as studies/run_layer.gd takes it: on past a
## seed that can't be laid), in the shape it will have (a run alternates
## them: scripts/roguelike/layer_shapes.gd `after`; a ring plan's too).
static func next_plan(plan: Dictionary) -> Dictionary:
	# The region one on (its world may be the other: the climb out of the dark).
	var knobs: Dictionary = LayerPlan.LayerWorlds.next_knobs(plan.get("user_knobs",{}))
	var shapes: GDScript = load("res://scripts/roguelike/layer_shapes.gd")
	var shape: String = shapes.after(plan)
	var nxt := {}
	for k in range(1,SKIP_MOST+1):
		nxt = shapes.core(shape,int(plan.seed)+k,knobs)
		if (nxt.problems as Array).is_empty(): break
	return nxt

## Plans made, kept by seed and knobs (each plan is made once as the next
## region and taken again as the layer when its gate is reached); a few
## only. A worker may lay the next region while another lays a layer
## asked for, hence the lock (made on first use, dropped by `forget`).
static var _kept := {}
static var _order: Array = []
static var _lock: Mutex = null
static func _mutex() -> Mutex:
	if _lock == null: _lock = Mutex.new()
	return _lock
const KEEP := 4

## The layer for `seed_value` without its next region: round 3's laid with
## the lean, then the exit chain; a draw that won't take a chain is drawn
## again (as LayerPlan `make` does).
static func core(seed_value: int, knobs := {}) -> Dictionary:
	var key := "%d %s" % [seed_value,str(knobs)]
	var lock := _mutex()
	lock.lock()
	var had: Dictionary = _kept.get(key,{})
	lock.unlock()
	if not had.is_empty(): return had
	var lean := rolled_heading(seed_value)
	var k := knobs.duplicate()
	k.lean = lean*LEAN
	k.shape = "sprawl"
	k.rise_roll = RISE_ROLL
	k.hood_more = HOOD_MORE
	# Underground the court is a whole hill of pillars: no isle more a
	# neighbourhood, or three courts won't sit in one.
	if LayerPlan.LayerWorlds.world_of(k) == "under": k.hood_more = 0
	k.tier = TIER
	# The city's places climb in themselves (in at the foot, out at the top):
	# no tier step forced between them.
	if LayerPlan.LayerWorlds.city(k): k.tier = 0.0
	k.repeats = REPEATS
	var plan := {}
	for attempt in range(LayerPlan.ATTEMPTS):
		plan = LayerPlan._make(seed_value,attempt,k)
		if not (plan.problems as Array).is_empty(): continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value,attempt,"sprawl"])
		if _chain(plan,lean,rng):
			# [merchant] The stall's nook: a side spur off a place on the way
			# (merchant_nook.gd), before the hazards and heads keep clear of it.
			var nook_rng := RandomNumberGenerator.new()
			nook_rng.seed = hash([seed_value,attempt,"nook"])
			MerchantNook.lay(plan,nook_rng)
			# The hazards (the viaduct may move the gate) before the view.
			if not LayerHazards.lay(plan,attempt):
				plan.problems.append("no viaduct")
				continue
			# The heads, off the hazards' perches.
			LayerEnemies.lay(plan,attempt)
			_spawn_view(plan)
			var roost_began := Time.get_ticks_usec()
			# The dragon is the sky's: no roost underground.
			if LayerPlan.LayerWorlds.world_of(k) == "under":
				plan.roost = {}
				break
			if _roost(plan):
				plan.roost.ms = (Time.get_ticks_usec()-roost_began)/1000.0
				break
			plan.problems.append("no roost")
			continue
		plan.problems.append("no exit chain")
	plan.user_knobs = knobs.duplicate()
	lock.lock()
	_kept[key] = plan
	_order.append(key)
	while _order.size() > KEEP: _kept.erase(_order.pop_front())
	lock.unlock()
	return plan

## The spawn moved where its eye sees past the gate to where the next
## region will stand (its base's middle, NEXT_UP over it): round 3's spawn,
## else the nearest of the base's clear spots that does; faced that way.
const NEXT_UP := 40.0
## The swings tried off the exit side (degrees), the straight way first.
const YAWS := [0.0,12.0,-12.0,24.0,-24.0,36.0,-36.0]
static func _spawn_view(plan: Dictionary) -> void:
	var h3 := Vector3(plan.heading.x,0.0,plan.heading.y)
	var gate: Vector3 = plan.exit.at
	var target: Vector3 = gate+h3*(DIST+NEXT_ON)+Vector3.UP*(next_rise(int(plan.seed))+NEXT_UP)
	var eyes: Array = [plan.spawn.at]
	var spots: Array = LayerPlan.base_spots(plan,"perch").filter(func(s: Dictionary) -> bool: return float(s.room) >= SPOT_ROOM \
		and (s.at as Vector3).distance_to(plan.spawn.at) < SPOT_NEAR)
	spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.at as Vector3).distance_to(plan.spawn.at) < (b.at as Vector3).distance_to(plan.spawn.at))
	for spot: Dictionary in spots: eyes.append((spot.at as Vector3)+Vector3.UP*0.2)
	plan.next_yaw = 0.0
	var found := false
	for yaw: float in YAWS:
		var aim := gate+Basis(Vector3.UP,deg_to_rad(yaw))*h3*(DIST+NEXT_ON)+Vector3.UP*(next_rise(int(plan.seed))+NEXT_UP)
		for at: Vector3 in eyes:
			if sight_clear(plan,at+Vector3.UP*EYE,aim):
				plan.spawn.at = at
				plan.next_yaw = yaw
				target = aim
				found = true
				break
		if found: break
	plan.next_aim = target
	var to: Vector3 = target-(plan.spawn.at as Vector3)
	plan.spawn.face = Vector3(to.x,0.0,to.z).normalized()

## How far over the gate the next region's base stands (m), rolled from
## the seed: a gulf's rise and RISE_OVER more.
static func next_rise(seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"next rise"])
	return rng.randf_range(RISE_ROLL.x,RISE_ROLL.y)+RISE_OVER

## The seed's lean (flat, unit): where its neighbourhoods are drawn toward.
static func rolled_heading(seed_value: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"lean"])
	return Vector2.from_angle(rng.randf()*TAU)

# --- The exit chain -------------------------------------------------------------------

## The exit side and its chain laid into `plan`: true, or false if no rim
## of the last neighbourhood takes one.
static func _chain(plan: Dictionary, lean: Vector2, rng: RandomNumberGenerator) -> bool:
	var last: Array = plan.hoods[(plan.hoods as Array).size()-1]
	var mid := Vector2.ZERO
	for i: int in last: mid += LayerPlan._rect(plan.isles[i]).get_center()
	mid /= last.size()
	var side := mid-Vector2(LayerPlan.MIDDLE.x,LayerPlan.MIDDLE.z)
	var heading := side.normalized() if side.length() >= SIDE_LEAST else lean
	plan.heading = heading
	var used := {}
	for e: Dictionary in plan.edges:
		used[LayerPlan._key(int(e.from[0]),str(e.from[1]))] = true
		used[LayerPlan._key(int(e.to[0]),str(e.to[1]))] = true
	var rims: Array = []
	for i: int in last:
		var isle: Dictionary = plan.isles[i]
		if isle.role == "greed": continue
		for s: Dictionary in isle.sockets:
			if s.kind != "rim" or used.has(LayerPlan._key(i,s.name)) or float(s.run_up) < RIM_RUN_UP or not LayerPlan.can_out(s,plan.knobs): continue
			var f := Vector2((s.face as Vector3).x,(s.face as Vector3).z).normalized()
			if f.dot(heading) < cos(deg_to_rad(RIM_FACING)): continue
			if not (plan.ram as Dictionary).is_empty() and int(plan.ram.isle) == i and (plan.ram.at as Vector3).distance_to(s.at) < LayerPlan.RAM_CLEAR: continue
			# Facing the exit side, high, and furthest out that way.
			var out_on := Vector2((s.at as Vector3).x,(s.at as Vector3).z).dot(heading)/RIM_OUT
			rims.append([f.dot(heading)*2.0+(s.at as Vector3).y*0.05+out_on+rng.randf()+LayerPlan.way_score(s,{},plan.knobs),i,s])
	rims.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	# The first chain each rim takes; the one whose gate stands furthest out
	# kept, at once if it is GATE_PAST the last neighbourhood's middle.
	var best: Array = []
	var best_on := -INF
	var best_rim: Array = []
	for r: Array in rims.slice(0,CHAIN_RIMS):
		for t in range(CHAIN_TRIES):
			var links := _lay(plan,int(r[1]),r[2],heading,rng)
			if links.is_empty(): continue
			var g: Vector3 = links[links.size()-1].gate.at
			var on := Vector2(g.x,g.z).dot(heading)
			if on > best_on:
				best_on = on
				best = links
				best_rim = r
			break
		if best_on >= mid.dot(heading)+GATE_PAST: break
	if best.is_empty(): return false
	# A clear exit side: the gate past the last neighbourhood's middle and
	# every isle of the others; else this draw is laid again.
	var out_most := mid.dot(heading)+GATE_PAST
	for i in range((plan.isles as Array).size()):
		if int(plan.isles[i].get("hood",0)) != (plan.hoods as Array).size()-1: out_most = maxf(out_most,LayerPlan._rect(plan.isles[i]).get_center().dot(heading))
	if best_on < out_most: return false
	var links := best
	# Each slab the chain turns on is built with the crossing that leaves it
	# (the edge's stones), not the one that comes to it: an edge's stones
	# are what he crosses on to its far rim. Listed last: the first stone
	# is the one he jumps for off the slab's edge.
	for k in range(links.size()-1,0,-1):
		var before: Array = links[k-1].stones
		var slab: Dictionary = before.pop_back()
		(links[k].stones as Array).push_back(slab)
	plan.chain = []
	for e: Dictionary in links:
		plan.chain.append((plan.edges as Array).size())
		plan.edges.append(e)
	var gate: Dictionary = links[links.size()-1].gate
	plan.exit = {"isle":-1,"rim":"gate","at":gate.at,"face":gate.face,"from":[int(best_rim[1]),str(best_rim[2].name)]}
	return true

## The crossings' kinds in order: stones, a bridge, the voussoirs and the
## cannon, a fifth (stones or a bridge) now and then; never the cannon
## first (it stands on a deck the chain lays).
static func _kinds(rng: RandomNumberGenerator, city := false) -> Array:
	# The city (underground): a second run of column tops in place of the
	# Loose Voussoirs (layer-round14-city-layers.md).
	var kinds: Array = ["stones","bridge","stones" if city else "trap","cannon"]
	if rng.randi_range(LINKS.x,LINKS.y) > 4: kinds.append("stones" if rng.randf() < 0.5 else "bridge")
	LayerPlan._shuffle(kinds,rng)
	if kinds[0] == "cannon":
		kinds[0] = kinds[1]
		kinds[1] = "cannon"
	return kinds

## One try at the chain off rim `rim` of isle `from`: its edges (the last's
## `gate`: {at, face}), or [] where a piece won't stand clear.
static func _lay(plan: Dictionary, from: int, rim: Dictionary, heading: Vector2, rng: RandomNumberGenerator) -> Array:
	var kinds := _kinds(rng,LayerPlan.LayerWorlds.city(plan.knobs))
	var land := LayerPlan.landing_size()
	var h3 := Vector3(heading.x,0.0,heading.y)
	var face: Vector3 = rim.face
	var p: Vector3 = (rim.at as Vector3)+face*float(rim.lip)
	# The first way: off the rim's facing toward the exit side, at most
	# LayerPlan's turn off a rim.
	var d := _toward(face,h3,LayerPlan.TURN_MOST)
	var from_rim: Dictionary = rim
	var from_at := [from,str(rim.name)]
	var slab := {}
	var links: Array = []
	var others: Array = (plan.edges as Array).duplicate()
	var zig := 1.0 if rng.randf() < 0.5 else -1.0
	for k in range(kinds.size()):
		var kind: String = kinds[k]
		var last := k == kinds.size()-1
		var size := land*(THRESHOLD if last else (DECK if kinds[k+1] == "cannon" else WAY))
		# A cannon's catch as broad as its deck.
		if kind == "cannon": size = maxf(size,land*DECK)
		if k > 0:
			# On the slab: turned toward the exit side, a little either way in
			# turn, and off its edge that way.
			var want := h3.rotated(Vector3.UP,deg_to_rad(zig*rng.randf_range(ZIG.x,ZIG.y)))
			zig = -zig
			d = _toward(d,want,TURN)
			p = _edge_of(slab,d)
			from_rim = {"kind":"rim","name":"way%d" % k,"at":p,"face":d,"run_up":float(slab.side)*0.5,"lip":0.0,"room":0.0}
			from_at = [-1,"way%d" % k]
		var chain := "exit_%d_%d_%d" % [k,roundi(p.x),roundi(p.z)]
		var out := {"stones":[],"bridges":[],"trap":{},"parts":[],"path":[],"cannon":{},"mean":LayerPlan.mean(plan.knobs)}
		var q := p
		match kind:
			"stones":
				q = LayerPlan._lay_stones(out,p,d,rng.randi_range(STONES.x,STONES.y),false,rng,chain,LayerPlan.CLIMB_LIFT)
			"bridge":
				var span := clampf(KitMotif.hop_reach()*rng.randf_range(LayerPlan.SPAN_HOPS.x,LayerPlan.SPAN_HOPS.y),Footbridge.TIMBER_SPAN,Footbridge.MAX_SPAN)
				var rise := span*Footbridge.MAX_GRADE*LayerPlan.GRADE*rng.randf_range(0.7,1.0)
				q = p+d*span+Vector3.UP*rise
				out.bridges.append([p,q])
				out.parts.append("bridge %.1f m" % span)
				out.path.append_array(LayerPlan._line(p,q,Footbridge.bow(span)+0.6))
			"trap":
				var length := LayerPlan.slab_length()
				var count := rng.randi_range(6,9)
				var over := length*0.25
				q = p+d*(count*length-2.0*over)
				out.trap = {"frame":Transform3D(Basis.looking_at(d,Vector3.UP),p-d*over),"count":count,"under":"void"}
				out.parts.append("voussoirs x%d" % count)
				out.path.append_array(LayerPlan._line(p,q,1.0))
			"cannon":
				var c := _cannon(plan,slab,d,size,rng)
				if c.is_empty(): return []
				out.cannon = c
				out.parts.append("cannon %.0f m" % Vector2((c.target as Vector3).x-(c.at as Vector3).x,(c.target as Vector3).z-(c.at as Vector3).z).length())
				q = (c.target as Vector3)-d*size*0.5
				out.path.append_array(LayerPlan._line(c.at,q,LayerPlan.UNDER,1.0))
		# The slab it comes to (the catch's middle is the shot's mark).
		var next := _slab(out,q,d,size,chain,last)
		var to_rim := {"kind":"rim","name":"way%d" % (k+1),"at":q,"face":-d,"run_up":size*0.5,"lip":0.0,"room":0.0}
		var edge := {"kind":kind,"branch":"exit","from":from_at,"to":[-1,"way%d" % (k+1)],"a":p,"b":q,"dir":d,
			"stones":out.stones,"bridges":out.bridges,"parts":out.parts,"trap":out.trap,"path":out.path,"cannon":out.cannon,
			"from_rim":from_rim,"to_rim":to_rim}
		if not _clear(plan,edge,others,from if k == 0 else -1,heading,links): return []
		if not (edge.trap as Dictionary).is_empty(): edge.trap.under = LayerPlan._under(edge,plan.isles)
		# The gate toward the threshold's far side (a run onto the slab
		# stops short of it).
		if last: edge.gate = {"at":(next.at as Vector3)+d*float(next.side)*GATE_ON,"face":d}
		links.append(edge)
		slab = next
	return links

## `from` turned toward `want` (flat), at most `most` degrees.
static func _toward(from: Vector3, want: Vector3, most: float) -> Vector3:
	var a := Vector3(from.x,0.0,from.z).normalized()
	var b := Vector3(want.x,0.0,want.z).normalized()
	var angle := a.signed_angle_to(b,Vector3.UP)
	return a.rotated(Vector3.UP,clampf(angle,-deg_to_rad(most),deg_to_rad(most)))

## A square slab whose near edge's middle is `near`, laid along `d`, `side`
## m across, into `out` (its stones and path): {at (its top's middle),
## dir, side}.
static func _slab(out: Dictionary, near: Vector3, d: Vector3, side: float, chain: String, last: bool) -> Dictionary:
	var top := near+d*side*0.5
	out.stones.append({"name":"%s_%s" % [chain,"threshold" if last else "slab"],"at":top,"size":Vector3(side,1.0,side),"yaw":atan2(-d.z,d.x),
		"kind":"block","chain":chain,"landing":true})
	out.parts.append("threshold" if last else "slab %.1f m" % side)
	out.path.append_array(LayerPlan._line(near,near+d*side,LayerPlan.UNDER))
	return {"at":top,"dir":d,"side":side}

## Where a way along `d` leaves the slab: its edge (the square's, laid
## along its own dir).
static func _edge_of(slab: Dictionary, d: Vector3) -> Vector3:
	var own: Vector3 = slab.dir
	var half: float = float(slab.side)*0.5
	var c := absf(own.dot(d))
	var s := absf(own.cross(Vector3.UP).normalized().dot(d))
	return (slab.at as Vector3)+d*half/maxf(maxf(c,s),0.5)

## The cannon on the deck `deck`, its shot along `d` landing on a catch
## SHOT of its reach on and SHOT_RISE up, its arc clear (LayerPlan `_aim`):
## the aim, or {}.
static func _cannon(plan: Dictionary, deck: Dictionary, d: Vector3, catch_side: float, rng: RandomNumberGenerator) -> Dictionary:
	if deck.is_empty(): return {}
	var base: Vector3 = deck.at
	var speed := float(LayerPlan.cannon_knobs().speed_max)
	var notches: Array = LayerPlan.cannon_knobs().power_notches
	var top := LayerPlan._shot(Vector3.ZERO,0.0,deg_to_rad(45.0),notches.size()-1,0.0)
	var flat_reach := Vector2(top.x,top.z).length()
	var jump := float(LayerPlan.pilot().jumps[1])
	for i in range(4):
		var dist := flat_reach*rng.randf_range(SHOT.x,SHOT.y)
		var rise := jump*rng.randf_range(SHOT_RISE.x,SHOT_RISE.y)
		var target := base+d*dist+Vector3.UP*rise
		if dist-float(deck.side)*0.5-catch_side*0.5 < LayerPlan.landing_size(): continue
		# LayerPlan `_aim` reads its base `back` behind a rim and its mark
		# `inland` in from another: rims made for it.
		var back := LayerPlan.CANNON_BACK
		var fake := {"from":[-1,"deck"],"to":[-1,"catch"],"from_rim":{"at":base+d*back,"face":d},"to_rim":{"at":target+d*SHOT_INLAND,"face":d}}
		var c := LayerPlan._aim(plan,fake,back,SHOT_INLAND,speed)
		if c.is_empty(): continue
		# Its kegs on the deck beside it, out of the shot.
		var across := d.cross(Vector3.UP).normalized()
		var off := float(deck.side)*0.28
		c.kegs = [base+across*off+Vector3.UP*0.05,base-across*off+Vector3.UP*0.05,base-d*off+across*off*0.6+Vector3.UP*0.05]
		return c
	return {}

## Whether a chain edge stands clear: its corridor of every isle (the rim's
## own near its lip), of every edge but the chain's last, of the rides'
## tubes, the gulfs' piers and the cannons; and on toward the exit side.
static func _clear(plan: Dictionary, edge: Dictionary, others: Array, from: int, heading: Vector2, links: Array) -> bool:
	var a: Vector3 = edge.a
	var b: Vector3 = edge.b
	var on := Vector2(b.x-a.x,b.z-a.z).dot(heading)
	if on < 1.0: return false
	if not LayerPlan._corridor_clear(edge,plan.isles,from,-1): return false
	var before: Array = others+links.slice(0,maxi(links.size()-1,0))
	if LayerPlan._crosses(edge,before): return false
	# The chain's own slab under each new piece: never over (or in) a piece
	# laid before but the last link's.
	var tubes: Array = plan.tubes
	var box := Rect2(Vector2(a.x,a.z),Vector2.ZERO)
	for s: Array in edge.path: box = box.expand(Vector2((s[0] as Vector3).x,(s[0] as Vector3).z))
	box = box.grow(RIDE_CLEAR+12.0)
	for t: Array in tubes:
		var tp: Vector3 = t[0]
		if not box.has_point(Vector2(tp.x,tp.z)): continue
		for s: Array in edge.path:
			if (s[0] as Vector3).distance_to(tp) < float(t[1])+RIDE_CLEAR: return false
	# The gulfs' rims (their piers and steps) and the cannons and kegs.
	var keep: Array = []
	for gi: int in plan.gulfs:
		var g: Dictionary = plan.edges[gi]
		keep.append([g.from_rim.at,PIER_CLEAR])
		keep.append([g.to_rim.at,PIER_CLEAR])
		if not (g.get("cannon",{}) as Dictionary).is_empty():
			keep.append([g.cannon.at,CANNON_CLEAR])
			for kat: Vector3 in g.cannon.kegs: keep.append([kat,CANNON_CLEAR])
	if not (plan.cannon as Dictionary).is_empty():
		keep.append([plan.cannon.at,CANNON_CLEAR])
		for kat: Vector3 in plan.cannon.kegs: keep.append([kat,CANNON_CLEAR])
	for kp: Array in keep:
		for s: Array in edge.path:
			var p: Vector3 = s[0]
			if Vector2(p.x-(kp[0] as Vector3).x,p.z-(kp[0] as Vector3).z).length() < float(kp[1]) and absf(p.y-(kp[0] as Vector3).y) < 8.0: return false
	return true

# --- The next region ------------------------------------------------------------------

## The next region placed past the gate: {seed, xform (its plan's world to
## this layer's), isles ([{id, occ, offset, landmark}]), landmark (its top,
## this layer's world), sight ([eye, landmark]), sight_ok, dist, rise,
## near (m from the spawn to its nearest bounds)}.
static func _place_next(plan: Dictionary, nxt: Dictionary) -> Dictionary:
	var heading: Vector2 = plan.heading
	var own: Vector2 = nxt.get("heading",heading)
	var h3 := Vector3(heading.x,0.0,heading.y)
	var basis := Basis(Vector3.UP,Vector3(own.x,0.0,own.y).signed_angle_to(h3,Vector3.UP))
	var pivot := LayerPlan.MIDDLE
	# Its isles, the landmark the highest top.
	var isles: Array = []
	var mark := -1
	var mark_top := -INF
	for i in range((nxt.isles as Array).size()):
		var isle: Dictionary = nxt.isles[i]
		isles.append({"id":isle.id,"occ":isle.occ,"offset":isle.offset,"landmark":false})
		var top := LayerPlan._span(isle).y
		if top > mark_top:
			mark_top = top
			mark = i
	isles[mark].landmark = true
	var mark_at := _top_of(nxt.isles[mark])
	# How far it reaches back toward the gate (along the heading, from its
	# base's middle), and its bounds.
	var back := 0.0
	var corners: Array = []
	for isle: Dictionary in nxt.isles:
		var r: Rect2 = LayerPlan._rect(isle)
		for c: Vector2 in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]:
			var w := basis*(Vector3(c.x,pivot.y,c.y)-pivot)
			corners.append(w)
			back = minf(back,w.dot(h3))
	var gate: Vector3 = plan.exit.at
	var eye: Vector3 = (plan.spawn.at as Vector3)+Vector3.UP*EYE
	var out := {}
	# Raised till its landmark is in sight from the spawn (laid looking
	# that way, `_spawn_view`), swung a little off the exit side if this
	# layer's own climb stands in the way (the way the spawn looks first).
	var yaws: Array = [float(plan.get("next_yaw",0.0))]
	for y: float in YAWS: if not yaws.has(y): yaws.append(y)
	var rise := next_rise(int(plan.seed))
	var first := {}
	while out.is_empty():
		for yaw: float in yaws:
			var turn := Basis(Vector3.UP,deg_to_rad(yaw))
			var way := turn*h3
			var b := turn*basis
			var reach := 0.0
			var swung: Array = []
			for w: Vector3 in corners:
				var t := turn*w
				swung.append(t)
				reach = minf(reach,t.dot(way))
			var dist := _apart_dist(plan,gate,way,reach,swung)
			var origin := gate+way*(dist-reach)
			origin.y = gate.y+rise
			var xform := Transform3D(b,origin-b*pivot)
			var top: Vector3 = xform*mark_at+Vector3.DOWN*MARK_UNDER
			var ok := sight_clear(plan,eye,top)
			var placing := {"seed":int(nxt.seed),"xform":xform,"isles":isles,"landmark":top,"landmark_id":str(nxt.isles[mark].id),"sight":[eye,top],"sight_ok":ok,
				"dist":dist,"rise":rise,"yaw":yaw,"heading":heading}
			if first.is_empty(): first = placing
			if ok:
				out = placing
				break
		if out.is_empty():
			if rise >= RISE_MOST: out = first
			rise += RISE_STEP
	# How far its nearest reach stands from the spawn.
	var xf: Transform3D = out.xform
	var least := INF
	for w: Vector3 in corners:
		var at := xf*(pivot+w)
		least = minf(least,Vector2(at.x-eye.x,at.z-eye.z).length())
	out.near = least
	out.far = eye.distance_to(out.landmark)
	# Its own roost in the silhouette too, where it keeps clear.
	var far_roost: Dictionary = nxt.get("roost",{})
	if not far_roost.is_empty():
		var entry := {"id":ROOST,"occ":far_roost.occ,"offset":far_roost.offset,"landmark":false}
		if _far_roost_ok(plan,out,entry): out.roost = entry
	return out

## How far past the gate (along `way`) its nearest reach must stand to
## keep APART (flat, bounds to bounds) from every isle of this layer.
static func _apart_dist(plan: Dictionary, gate: Vector3, way: Vector3, reach: float, corners: Array) -> float:
	var dist := DIST
	for k in range(12):
		var origin := gate+way*(dist-reach)
		var bounds := Rect2(Vector2(origin.x,origin.z),Vector2.ZERO)
		for w: Vector3 in corners: bounds = bounds.expand(Vector2(origin.x+w.x,origin.z+w.z))
		var near := true
		var solids: Array = plan.isles
		if not (plan.get("roost",{}) as Dictionary).is_empty(): solids = solids+[plan.roost]
		for isle: Dictionary in solids:
			var r: Rect2 = LayerPlan._rect(isle)
			var dx := maxf(maxf(r.position.x-bounds.end.x,bounds.position.x-r.end.x),0.0)
			var dz := maxf(maxf(r.position.y-bounds.end.y,bounds.position.y-r.end.y),0.0)
			if Vector2(dx,dz).length() < APART: near = false
		if near: break
		dist += 40.0
	return dist

## An isle's highest solid cell's middle (its plan's world).
static func _top_of(isle: Dictionary) -> Vector3:
	var o: Dictionary = isle.occ
	var hi: PackedFloat32Array = o.hi
	var best := 0
	for k in range(hi.size()):
		if hi[k] > hi[best]: best = k
	var off: Vector3 = isle.offset
	var origin: Vector2 = o.origin
	return Vector3(origin.x+(best%int(o.cols)+0.5)*float(o.cell)+off.x,hi[best]+off.y,origin.y+(best/int(o.cols)+0.5)*float(o.cell)+off.z)

## Whether the straight line from `a` to `b` misses every isle of the plan
## (its occupancy, sampled every SIGHT_STEP m), and its roost (if laid, and
## `roost`).
static func sight_clear(plan: Dictionary, a: Vector3, b: Vector3, roost := true) -> bool:
	var n := maxi(int(ceil(a.distance_to(b)/SIGHT_STEP)),1)
	var solids: Array = plan.isles
	if roost and not (plan.get("roost",{}) as Dictionary).is_empty(): solids = solids+[plan.roost]
	for isle: Dictionary in solids:
		var r: Rect2 = LayerPlan._rect(isle)
		var span := LayerPlan._span(isle)
		for i in range(1,n):
			var p := a.lerp(b,float(i)/n)
			if p.y > span.y+1.0 or not r.has_point(Vector2(p.x,p.z)): continue
			var o := LayerPlan.occ_at(isle,p.x,p.z)
			if o.x < INF and p.y > o.x-SIGHT_MARGIN and p.y < o.y+SIGHT_MARGIN: return false
	return true

# --- The dragon's roost ---------------------------------------------------------------

## The roost (scripts/kit_isle/motif_dragon_roost.gd as it is, its dragon
## curled on its ledge: scripts/dragon_roost.gd) stood apart from the layer
## (`_roost`): its footprint ROOST_GAP clear (flat) of every isle's bounds,
## every edge's path (the chain and the gulfs' lines too), the rides' tubes
## and the cannons and their marks; its turf ROOST_OVER over the highest
## solid of every isle (so the whole mountain stands over the layer's
## skyline, its peak some 118 m more); its middle within ROOST_RING of the
## layer's MIDDLE (the clouds thin over it: studies/run_layer_sky.gd
## `keep_roost`; the cumulus towers stand 340 m+ off at that ring).
##
## Its side: bearings round the layer's middle, each taken out to the
## first spot clear by the gap. A spot stands off the exit side (from the
## gate at least ROOST_OFF_EXIT off the heading, so the chain and the gate
## look past it at the next region) and off the spawn's line to where the
## next region will be (ROOST_OFF_NEXT), and its tower is in sight from the
## spawn's eye. Of those, the best: seen from the most neighbourhoods (from
## any of its isles' highest rim or spot), within ROOST_VIEW of the spawn's
## facing (in the first frame with the next region), its front (Roost V,
## the side it was laid out to be seen from: the dragon's neck, the hoard)
## toward the spawn, and nearer. Moved, never turned (the dragon's pose
## reads the mountain's own ground in its own frame).
const ROOST := "dragon_roost"
const ROOST_GAP := 150.0
const ROOST_OVER := 15.0
const ROOST_RING := 680.0
const ROOST_BEARINGS := 36
const ROOST_STEP := 15.0
const ROOST_OFF_EXIT := 55.0
const ROOST_OFF_NEXT := 25.0
const ROOST_VIEW := 35.0
## What "in sight" aims at: the summit tower's axis this far under its
## shoulder (m, inside the rock, so a ray that gets there hits the tower).
const ROOST_MARK_UNDER := 12.0

## The roost's occupancy (the bake's, its own frame), its keel added: the
## bake reads only the turf and crags (its keel has no collision), so each
## cell's lowest is taken down the hanging keel's cone (Roost DEPTH under
## its turf at the middle, to the turf at its outline). Its reach: the
## farthest occupied cell from its middle (m). Made once.
static var _roost_occ := {}
static func roost_occ() -> Dictionary:
	var lock := _mutex()
	lock.lock()
	if _roost_occ.is_empty():
		var o: Dictionary = LayerPieces.occupancy(ROOST)
		var lo: PackedFloat32Array = (o.lo as PackedFloat32Array).duplicate()
		var hi: PackedFloat32Array = (o.hi as PackedFloat32Array).duplicate()
		var mid := Roost.own(Roost.ISLE_C)
		var r_out := Roost.ISLE_R*Roost.SPAN
		var reach := 0.0
		var cols := int(o.cols)
		var cell := float(o.cell)
		for k in range(lo.size()):
			if lo[k] == INF: continue
			var at := (o.origin as Vector2)+Vector2(k%cols+0.5,k/cols+0.5)*cell
			var r := at.distance_to(mid)
			reach = maxf(reach,r+cell*0.71)
			lo[k] = minf(lo[k],Roost.TOP-Roost.DEPTH*Roost.SPAN*pow(clampf(1.0-r/r_out,0.0,1.0),0.7))
		_roost_occ = {"origin":o.origin,"cell":o.cell,"cols":o.cols,"rows":o.rows,"lo":lo,"hi":hi,"reach":reach,"mid":mid}
	lock.unlock()
	return _roost_occ

## The roost laid into `plan` (`plan.roost`: {id, occ, offset, at (its
## middle, on its turf), reach, mark (see ROOST_MARK_UNDER), gap (m, the
## least found), seen ([neighbourhoods it is in sight from, of how many]),
## view (deg off the spawn's facing)}), or false where no side takes it.
static func _roost(plan: Dictionary) -> bool:
	var occ := roost_occ()
	var reach: float = occ.reach
	var own_mid: Vector2 = occ.mid
	# What it keeps clear of: the isles' bounds, and points (each with its
	# own reach) along every edge, tube and cannon shot.
	var rects: Array = []
	var middle := Vector2.ZERO
	var high := -INF
	for isle: Dictionary in plan.isles:
		var r: Rect2 = LayerPlan._rect(isle)
		rects.append(r)
		middle += r.get_center()
		high = maxf(high,LayerPlan._span(isle).y)
	middle /= maxf((plan.isles as Array).size(),1.0)
	var pts := {}
	var add := func(p: Vector3, rad: float) -> void:
		var key := Vector2i(floori(p.x/6.0),floori(p.z/6.0))
		pts[key] = maxf(float(pts.get(key,0.0)),rad)
	for e: Dictionary in plan.edges:
		for sp: Array in e.path: add.call(sp[0],0.0)
		var c: Dictionary = e.get("cannon",{})
		if not c.is_empty():
			add.call(c.at,0.0)
			add.call(c.target,0.0)
	for t: Array in plan.tubes: add.call(t[0],float(t[1]))
	if not (plan.cannon as Dictionary).is_empty():
		add.call(plan.cannon.at,0.0)
		add.call(plan.cannon.target,0.0)
	# Each as (x, its reach plus half a bucket's diagonal, z).
	var flat_pts: Array = []
	for key: Vector2i in pts: flat_pts.append(Vector3((key.x+0.5)*6.0,float(pts[key])+4.3,(key.y+0.5)*6.0))
	var gap_at := func(p: Vector2) -> float:
		var least := INF
		for r: Rect2 in rects:
			var dx := maxf(maxf(r.position.x-p.x,p.x-r.end.x),0.0)
			var dz := maxf(maxf(r.position.y-p.y,p.y-r.end.y),0.0)
			least = minf(least,Vector2(dx,dz).length())
		for q: Vector3 in flat_pts: least = minf(least,Vector2(q.x-p.x,q.z-p.y).length()-q.y)
		return least-reach
	var turf := high+ROOST_OVER
	var tower := Roost.own(Roost.TOWER_C)
	var mark_own := Vector3(tower.x,Roost.TOP+Roost.SHOULDER_H*Roost.SPAN-ROOST_MARK_UNDER,tower.y)
	var eye: Vector3 = (plan.spawn.at as Vector3)+Vector3.UP*EYE
	var face: Vector3 = plan.spawn.face
	var gate: Vector3 = plan.exit.at
	var heading: Vector2 = plan.heading
	var to_next := Vector2((plan.next_aim as Vector3).x-eye.x,(plan.next_aim as Vector3).z-eye.z).normalized()
	# Each neighbourhood's eyes: each of its isles' highest rim or spot.
	var hood_eyes: Array = []
	for h: Array in plan.hoods:
		var eyes: Array = []
		for i: int in h:
			var top := Vector3(0.0,-INF,0.0)
			for sk: Dictionary in plan.isles[i].sockets:
				if (sk.at as Vector3).y > top.y: top = sk.at
			if top.y > -INF: eyes.append(top+Vector3.UP*EYE)
		hood_eyes.append(eyes)
	var ring_mid := Vector2(LayerPlan.MIDDLE.x,LayerPlan.MIDDLE.z)
	var front := Roost.V.normalized()
	var best := {}
	var best_score := -INF
	for b in range(ROOST_BEARINGS):
		var u := Vector2.from_angle(TAU*float(b)/ROOST_BEARINGS)
		var t := 0.0
		var p := middle
		var gap := -INF
		while true:
			p = middle+u*t
			if p.distance_to(ring_mid) > ROOST_RING: break
			gap = gap_at.call(p)
			if gap >= ROOST_GAP: break
			t += maxf(ROOST_STEP,(ROOST_GAP-gap)*0.5)
		if gap < ROOST_GAP or p.distance_to(ring_mid) > ROOST_RING: continue
		var off := Vector3(p.x-own_mid.x,turf-Roost.TOP,p.y-own_mid.y)
		var mark := mark_own+off
		# Off the exit side, off the line to the next region.
		var from_gate := Vector2(p.x-gate.x,p.y-gate.z).normalized()
		if rad_to_deg(acos(clampf(from_gate.dot(heading),-1.0,1.0))) < ROOST_OFF_EXIT: continue
		var to_mark := Vector2(mark.x-eye.x,mark.z-eye.z).normalized()
		if rad_to_deg(acos(clampf(to_mark.dot(to_next),-1.0,1.0))) < ROOST_OFF_NEXT: continue
		if not sight_clear(plan,eye,mark,false): continue
		var view := rad_to_deg(acos(clampf(to_mark.dot(Vector2(face.x,face.z).normalized()),-1.0,1.0)))
		var score := 2.0*(1.0 if view <= ROOST_VIEW else maxf(1.0-(view-ROOST_VIEW)/40.0,0.0))
		score += 0.75*front.dot(-to_mark)
		score -= t/300.0
		# Only a spot that could still win is looked at from the others.
		if score+3.0 <= best_score: continue
		var seen := 0
		for eyes: Array in hood_eyes:
			for he: Vector3 in eyes:
				if sight_clear(plan,he,mark,false):
					seen += 1
					break
		score += 3.0*float(seen)/maxf(hood_eyes.size(),1.0)
		if score > best_score:
			best_score = score
			best = {"id":ROOST,"occ":occ,"offset":off,"at":Vector3(p.x,turf,p.y),"reach":reach,"mark":mark,"gap":gap,"seen":[seen,hood_eyes.size()],"view":view}
	if best.is_empty(): return false
	plan.roost = best
	return true

## The next region's own roost for its silhouette (`entry`: an isle of
## NextRegionLod's, in the next plan's frame, under `out.xform`), if it
## stands APART from this layer's isles and roost and off the spawn's sight
## line to the landmark.
static func _far_roost_ok(plan: Dictionary, out: Dictionary, entry: Dictionary) -> bool:
	var xf: Transform3D = out.xform
	var r: Rect2 = LayerPlan._rect(entry)
	var bounds := Rect2()
	var first := true
	for c: Vector2 in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]:
		var w := xf*Vector3(c.x,0.0,c.y)
		if first: bounds = Rect2(Vector2(w.x,w.z),Vector2.ZERO)
		else: bounds = bounds.expand(Vector2(w.x,w.z))
		first = false
	var solids: Array = plan.isles
	if not (plan.get("roost",{}) as Dictionary).is_empty(): solids = solids+[plan.roost]
	for isle: Dictionary in solids:
		var o: Rect2 = LayerPlan._rect(isle)
		var dx := maxf(maxf(o.position.x-bounds.end.x,bounds.position.x-o.end.x),0.0)
		var dz := maxf(maxf(o.position.y-bounds.end.y,bounds.position.y-o.end.y),0.0)
		if Vector2(dx,dz).length() < APART: return false
	var a: Vector3 = out.sight[0]
	var b: Vector3 = out.sight[1]
	var inv := xf.affine_inverse()
	var n := maxi(int(ceil(a.distance_to(b)/SIGHT_STEP)),1)
	for i in range(1,n):
		var q := inv*a.lerp(b,float(i)/n)
		var o := LayerPlan.occ_at(entry,q.x,q.z)
		if o.x < INF and q.y > o.x-SIGHT_MARGIN and q.y < o.y+SIGHT_MARGIN: return false
	return true

# --- On the stage ---------------------------------------------------------------------

## What the sprawl adds to a built layer (`stage`, scripts/roguelike/
## layer_stage.gd, which already built the chain's stones, bridges, trap
## and gate from the plan's edges): the chain's cannons and kegs, and the
## next region's silhouette.
static func dress(stage: Node3D, plan: Dictionary) -> void:
	for i: int in plan.get("chain",[]):
		var e: Dictionary = plan.edges[i]
		if (e.cannon as Dictionary).is_empty(): continue
		var c: Dictionary = e.cannon
		var node: Node3D = stage.cannons.add_cannon(c.at,float(c.heading),{"speed_max":float(c.speed)})
		node.name = "ExitCannon%d" % i
		for at: Vector3 in c.kegs: stage.cannons.add_keg(at)
	stage.hazards = LayerHazards.dress(stage,plan)
	if plan.has("next"):
		var lod := NextRegionLod.build(plan.next)
		stage.add_child(lod)
	else:
		# Laid on a worker once this layer stands (scripts/roguelike/
		# next_region_loader.gd).
		_mutex()
		var loader: Node = load("res://scripts/roguelike/next_region_loader.gd").new()
		loader.setup(stage,plan)
		stage.add_child(loader)
	# The kept plans go with the study (held past it, their motifs outlive
	# the engine's servers and abort its exit).
	var study: Node = stage.get("study")
	if study != null and not study.tree_exiting.is_connected(forget): study.tree_exiting.connect(forget)

## Drops the kept plans.
static func forget() -> void:
	_kept.clear()
	_order.clear()
	_lock = null

## The exit side as a compass word (north is -z).
static func compass(heading: Vector2) -> String:
	var names := ["east","south-east","south","south-west","west","north-west","north","north-east"]
	return names[posmod(roundi(heading.angle()/(PI/4.0)),8)]

## A line for the card: the exit side, its chain, the next region.
static func card(plan: Dictionary) -> String:
	if not plan.has("heading"): return ""
	var kinds := PackedStringArray()
	for i: int in plan.get("chain",[]): kinds.append(str(plan.edges[i].kind).replace("trap","voussoirs"))
	var line := "Exit side: %s (%s, then the gate)" % [compass(plan.heading),", ".join(kinds)]
	if plan.has("next"): line += "  ·  next region (layer %d) %.0f m off, %.0f m up" % [int(plan.next.seed),float(plan.next.far),float(plan.next.rise)]
	var hz := LayerHazards.card(plan)
	if hz != "": line += "\n"+hz
	var en := LayerEnemies.card(plan)
	if en != "": line += "\n"+en
	var roost: Dictionary = plan.get("roost",{})
	if not roost.is_empty():
		var at: Vector3 = roost.at
		var spawn: Vector3 = plan.spawn.at
		var to := Vector2(at.x-spawn.x,at.z-spawn.z)
		line += "
The dragon's roost: %s, %.0f m off, its turf %.0f m up (its peak %.0f m)" % [compass(to.normalized()),to.length(),at.y-spawn.y,at.y+Roost.PEAK_H*Roost.SPAN-spawn.y]
	return line

# --- Reading it -----------------------------------------------------------------------

## A map of the plan from above, and from the side along the exit side,
## in text: isles by index (0 the base), the dragon's roost `R`, the edges'
## stones and slabs `.`, a gulf's line `~`, the gate `G`, the spawn `S`, the
## next region `#` (its roost too) with its landmark `@`, the sight line `'`
## (above only).
static func overview(plan: Dictionary, wide := 110, tall := 44) -> String:
	var dots: Array = []  # [world point, char, priority]
	var mine: Array = (plan.isles as Array).duplicate()
	if not (plan.get("roost",{}) as Dictionary).is_empty(): mine.append(plan.roost)
	for i in range(mine.size()):
		var isle: Dictionary = mine[i]
		var c := LayerPlan._coarse(isle.occ)
		var off: Vector3 = isle.offset
		var lo: PackedFloat32Array = c.lo
		var hi: PackedFloat32Array = c.hi
		for k in range(lo.size()):
			if lo[k] == INF: continue
			var x := (c.origin as Vector2).x+off.x+(k%int(c.cols)+0.5)*float(c.cell)
			var z := (c.origin as Vector2).y+off.z+(k/int(c.cols)+0.5)*float(c.cell)
			dots.append([Vector3(x,hi[k]+off.y,z),"R" if str(isle.id) == ROOST else str(i%10),1,lo[k]+off.y])
	for e: Dictionary in plan.edges:
		if e.kind == "gulf":
			for s: Array in e.path: dots.append([s[0],"~",2,(s[0] as Vector3).y])
		else:
			for s: Array in e.path: dots.append([s[0],"." if e.branch != "exit" else ":",2,(s[0] as Vector3).y])
	if plan.has("next"):
		var xf: Transform3D = plan.next.xform
		var far: Array = (plan.next.isles as Array).duplicate()
		if not (plan.next.get("roost",{}) as Dictionary).is_empty(): far.append(plan.next.roost)
		for isle: Dictionary in far:
			var c := LayerPlan._coarse(isle.occ)
			var off: Vector3 = isle.offset
			var lo: PackedFloat32Array = c.lo
			var hi: PackedFloat32Array = c.hi
			for k in range(lo.size()):
				if lo[k] == INF: continue
				var x := (c.origin as Vector2).x+off.x+(k%int(c.cols)+0.5)*float(c.cell)
				var z := (c.origin as Vector2).y+off.z+(k/int(c.cols)+0.5)*float(c.cell)
				dots.append([xf*Vector3(x,hi[k]+off.y,z),"#",1,(xf*Vector3(x,lo[k]+off.y,z)).y])
		var sa: Vector3 = plan.next.sight[0]
		var sb: Vector3 = plan.next.sight[1]
		for i in range(60): dots.append([sa.lerp(sb,i/60.0),"'",0,sa.lerp(sb,i/60.0).y])
		dots.append([plan.next.landmark,"@",4,(plan.next.landmark as Vector3).y])
	dots.append([plan.exit.at,"G",5,(plan.exit.at as Vector3).y])
	dots.append([plan.spawn.at,"S",5,(plan.spawn.at as Vector3).y])
	# From above: x right, z down (north up).
	var box := AABB(dots[0][0],Vector3.ZERO)
	for d: Array in dots: box = box.expand(d[0])
	# One scale both ways (a character twice as tall as it is wide).
	var scale := maxf(box.size.x/wide,box.size.z/(tall*2.0))
	var flat := Rect2(box.position.x+box.size.x*0.5-scale*wide*0.5,box.position.z+box.size.z*0.5-scale*tall,scale*wide,scale*tall*2.0)
	var top := _raster(dots,wide,tall,func(p: Vector3) -> Vector2: return Vector2(p.x,p.z),flat,false)
	# From the side: along the exit side (right), height up.
	var h: Vector2 = plan.get("heading",Vector2.RIGHT)
	var along := func(p: Vector3) -> Vector2: return Vector2(p.x*h.x+p.z*h.y,-p.y)
	var r := Rect2(along.call(dots[0][0]),Vector2.ZERO)
	for d: Array in dots:
		r = r.expand(along.call(d[0]))
		r = r.expand(along.call(Vector3((d[0] as Vector3).x,float(d[3]),(d[0] as Vector3).z)))
	var side := _raster(dots,wide,int(tall/2.0),along,r,true)
	return "From above (north up, a character %.0f m across and %.0f m down; %.0f x %.0f m):\n%s\nFrom the side along the exit side (%s to the right, up is up; a character %.0f m across and %.0f m up):\n%s" % [
		scale,scale*2.0,box.size.x,box.size.z,top,compass(h),r.size.x/wide,r.size.y/int(tall/2.0),side]

static func _raster(dots: Array, wide: int, tall: int, flat: Callable, r: Rect2, keel: bool) -> String:
	var rows: Array = []
	var pri: Array = []
	for j in range(tall):
		var row: Array = []
		row.resize(wide)
		row.fill(" ")
		rows.append(row)
		var pr: Array = []
		pr.resize(wide)
		pr.fill(-1)
		pri.append(pr)
	var put := func(p: Vector2, ch: String, prio: int) -> void:
		var i := clampi(int((p.x-r.position.x)/maxf(r.size.x,1.0)*(wide-1)),0,wide-1)
		var j := clampi(int((p.y-r.position.y)/maxf(r.size.y,1.0)*(tall-1)),0,tall-1)
		if prio >= int(pri[j][i]):
			rows[j][i] = ch
			pri[j][i] = prio
	for d: Array in dots:
		var p: Vector3 = d[0]
		put.call(flat.call(p),d[1],int(d[2]))
		if keel and int(d[2]) == 1:
			# A column from its top down to its keel.
			var low := Vector3(p.x,float(d[3]),p.z)
			var a: Vector2 = flat.call(p)
			var b: Vector2 = flat.call(low)
			var n := maxi(int(absf(b.y-a.y)/maxf(r.size.y,1.0)*tall),1)
			for s in range(n+1): put.call(a.lerp(b,float(s)/n),d[1],int(d[2]))
	var out := PackedStringArray()
	for row: Array in rows: out.append("|"+"".join(PackedStringArray(row))+"|")
	return "\n".join(out)
