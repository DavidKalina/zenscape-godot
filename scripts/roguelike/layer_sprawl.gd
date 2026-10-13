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
##     and RISE higher, raised till the line from the spawn's eye to its
##     landmark (its highest isle's top) is clear of this layer's isles.
##     The spawn faces it.
## The same seed and knobs give the same plan.
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const KitMotif = preload("res://scripts/kit_isle/kit_motif.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")
const NextRegionLod = preload("res://scripts/roguelike/next_region_lod.gd")
const LayerPieces = preload("res://scripts/roguelike/layer_pieces.gd")

## The lean's weight: points per 100 m stood toward the rolled heading
## (LayerPlan `_lean`; a step's random share is 0-2, a gulf's the same).
const LEAN := 1.5
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
const SHOT_RISE := Vector2(0.7,2.5)
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
const RISE := 90.0
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
static func make(seed_value: int, knobs := {}) -> Dictionary:
	var plan := core(seed_value,knobs)
	if not (plan.problems as Array).is_empty(): return plan
	var nxt := {}
	for k in range(1,SKIP_MOST+1):
		nxt = core(seed_value+k,knobs)
		if (nxt.problems as Array).is_empty(): break
	if (nxt.problems as Array).is_empty():
		plan.next = _place_next(plan,nxt)
		plan.spawn.at = (plan.next.spawn as Vector3)+Vector3.UP*0.2
		var to: Vector3 = (plan.next.landmark as Vector3)-(plan.spawn.at as Vector3)
		plan.spawn.face = Vector3(to.x,0.0,to.z).normalized()
	else: plan.problems.append("no next region laid past seed %d" % seed_value)
	return plan

## Plans made, kept by seed and knobs (each plan is made once as the next
## region and taken again as the layer when its gate is reached); a few
## only. studies/run_layer.gd lays one plan at a time (on a worker
## windowed, on the main thread headless), so no lock: a static Mutex
## aborted the engine's exit.
static var _kept := {}
static var _order: Array = []
const KEEP := 4

## The layer for `seed_value` without its next region: round 3's laid with
## the lean, then the exit chain; a draw that won't take a chain is drawn
## again (as LayerPlan `make` does).
static func core(seed_value: int, knobs := {}) -> Dictionary:
	var key := "%d %s" % [seed_value,str(knobs)]
	var had: Dictionary = _kept.get(key,{})
	if not had.is_empty(): return had
	var lean := rolled_heading(seed_value)
	var k := knobs.duplicate()
	k.lean = lean*LEAN
	k.shape = "sprawl"
	var plan := {}
	for attempt in range(LayerPlan.ATTEMPTS):
		plan = LayerPlan._make(seed_value,attempt,k)
		if not (plan.problems as Array).is_empty(): continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value,attempt,"sprawl"])
		if _chain(plan,lean,rng): break
		plan.problems.append("no exit chain")
	_kept[key] = plan
	_order.append(key)
	while _order.size() > KEEP: _kept.erase(_order.pop_front())
	return plan

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
			if s.kind != "rim" or used.has(LayerPlan._key(i,s.name)) or float(s.run_up) < RIM_RUN_UP: continue
			var f := Vector2((s.face as Vector3).x,(s.face as Vector3).z).normalized()
			if f.dot(heading) < cos(deg_to_rad(RIM_FACING)): continue
			if not (plan.ram as Dictionary).is_empty() and int(plan.ram.isle) == i and (plan.ram.at as Vector3).distance_to(s.at) < LayerPlan.RAM_CLEAR: continue
			rims.append([f.dot(heading)*2.0+(s.at as Vector3).y*0.05+rng.randf(),i,s])
	rims.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for r: Array in rims.slice(0,CHAIN_RIMS):
		for t in range(CHAIN_TRIES):
			var links := _lay(plan,int(r[1]),r[2],heading,rng)
			if links.is_empty(): continue
			# Each slab the chain turns on is built with the crossing that
			# leaves it (the edge's stones), not the one that comes to it:
			# an edge's stones are what he crosses on to its far rim.
			for k in range(links.size()-1,0,-1):
				var before: Array = links[k-1].stones
				var slab: Dictionary = before.pop_back()
				(links[k].stones as Array).push_front(slab)
			plan.chain = []
			for e: Dictionary in links:
				plan.chain.append((plan.edges as Array).size())
				plan.edges.append(e)
			var gate: Dictionary = links[links.size()-1].gate
			plan.exit = {"isle":-1,"rim":"gate","at":gate.at,"face":gate.face,"from":[int(r[1]),str(r[2].name)]}
			return true
	return false

## The crossings' kinds in order: stones, a bridge, the voussoirs and the
## cannon, a fifth (stones or a bridge) now and then; never the cannon
## first (it stands on a deck the chain lays).
static func _kinds(rng: RandomNumberGenerator) -> Array:
	var kinds: Array = ["stones","bridge","trap","cannon"]
	if rng.randi_range(LINKS.x,LINKS.y) > 4: kinds.append("stones" if rng.randf() < 0.5 else "bridge")
	LayerPlan._shuffle(kinds,rng)
	if kinds[0] == "cannon":
		kinds[0] = kinds[1]
		kinds[1] = "cannon"
	return kinds

## One try at the chain off rim `rim` of isle `from`: its edges (the last's
## `gate`: {at, face}), or [] where a piece won't stand clear.
static func _lay(plan: Dictionary, from: int, rim: Dictionary, heading: Vector2, rng: RandomNumberGenerator) -> Array:
	var kinds := _kinds(rng)
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
		var out := {"stones":[],"bridges":[],"trap":{},"parts":[],"path":[],"cannon":{}}
		var q := p
		match kind:
			"stones":
				q = LayerPlan._lay_stones(out,p,d,rng.randi_range(STONES.x,STONES.y),false,rng,chain)
			"bridge":
				var span := clampf(KitMotif.hop_reach()*rng.randf_range(LayerPlan.SPAN_HOPS.x,LayerPlan.SPAN_HOPS.y),Footbridge.TIMBER_SPAN,Footbridge.MAX_SPAN)
				var rise := span*Footbridge.MAX_GRADE*LayerPlan.GRADE*rng.randf_range(0.3,1.0)
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
	var dist := DIST
	var out := {}
	# Pushed on till its bounds keep APART from this layer's isles.
	for k in range(12):
		var origin := gate+h3*(dist-back)
		var bounds := Rect2(Vector2(origin.x,origin.z),Vector2.ZERO)
		for w: Vector3 in corners: bounds = bounds.expand(Vector2(origin.x+w.x,origin.z+w.z))
		var near := true
		for isle: Dictionary in plan.isles:
			var r: Rect2 = LayerPlan._rect(isle)
			var dx := maxf(maxf(r.position.x-bounds.end.x,bounds.position.x-r.end.x),0.0)
			var dz := maxf(maxf(r.position.y-bounds.end.y,bounds.position.y-r.end.y),0.0)
			if Vector2(dx,dz).length() < APART: near = false
		if near: break
		dist += 40.0
	# Raised till its landmark is in sight from the spawn, or from a spot
	# of the base near it (the spawn moved there).
	var eyes: Array = [plan.spawn.at]
	var spots: Array = LayerPieces.sockets(LayerPlan.BASE).filter(func(s: Dictionary) -> bool: return s.kind == "perch" and float(s.room) >= SPOT_ROOM \
		and (s.at as Vector3).distance_to(plan.spawn.at) < SPOT_NEAR)
	spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.at as Vector3).distance_to(plan.spawn.at) < (b.at as Vector3).distance_to(plan.spawn.at))
	for spot: Dictionary in spots: eyes.append(spot.at)
	var rise := RISE
	while true:
		var origin := gate+h3*(dist-back)
		origin.y = gate.y+rise
		var xform := Transform3D(basis,origin-basis*pivot)
		var top: Vector3 = xform*mark_at+Vector3.DOWN*MARK_UNDER
		var ok := false
		for at: Vector3 in eyes:
			eye = at+Vector3.UP*EYE
			ok = sight_clear(plan,eye,top)
			if ok: break
		if not ok: eye = (plan.spawn.at as Vector3)+Vector3.UP*EYE
		out = {"seed":int(nxt.seed),"xform":xform,"isles":isles,"landmark":top,"landmark_id":str(nxt.isles[mark].id),"sight":[eye,top],"sight_ok":ok,
			"dist":dist,"rise":rise,"heading":heading,"spawn":eye-Vector3.UP*EYE}
		if ok or rise >= RISE_MOST: break
		rise += RISE_STEP
	# How far its nearest reach stands from the spawn.
	var xf: Transform3D = out.xform
	var least := INF
	for w: Vector3 in corners:
		var at := xf*(pivot+w)
		least = minf(least,Vector2(at.x-eye.x,at.z-eye.z).length())
	out.near = least
	out.far = eye.distance_to(out.landmark)
	return out

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
## (its occupancy, sampled every SIGHT_STEP m).
static func sight_clear(plan: Dictionary, a: Vector3, b: Vector3) -> bool:
	var n := maxi(int(ceil(a.distance_to(b)/SIGHT_STEP)),1)
	for isle: Dictionary in plan.isles:
		var r: Rect2 = LayerPlan._rect(isle)
		var span := LayerPlan._span(isle)
		for i in range(1,n):
			var p := a.lerp(b,float(i)/n)
			if p.y > span.y+1.0 or not r.has_point(Vector2(p.x,p.z)): continue
			var o := LayerPlan.occ_at(isle,p.x,p.z)
			if o.x < INF and p.y > o.x-SIGHT_MARGIN and p.y < o.y+SIGHT_MARGIN: return false
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
	if plan.has("next"):
		var lod := NextRegionLod.build(plan.next)
		stage.add_child(lod)
	# The kept plans go with the study (held past it, their motifs outlive
	# the engine's servers and abort its exit).
	var study: Node = stage.get("study")
	if study != null and not study.tree_exiting.is_connected(forget): study.tree_exiting.connect(forget)

## Drops the kept plans.
static func forget() -> void:
	_kept.clear()
	_order.clear()

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
	return line

# --- Reading it -----------------------------------------------------------------------

## A map of the plan from above, and from the side along the exit side,
## in text: isles by index (0 the base), the edges' stones and slabs `.`,
## a gulf's line `~`, the gate `G`, the spawn `S`, the next region `#`
## with its landmark `@`, the sight line `'` (above only).
static func overview(plan: Dictionary, wide := 110, tall := 44) -> String:
	var dots: Array = []  # [world point, char, priority]
	for i in range((plan.isles as Array).size()):
		var isle: Dictionary = plan.isles[i]
		var c := LayerPlan._coarse(isle.occ)
		var off: Vector3 = isle.offset
		var lo: PackedFloat32Array = c.lo
		var hi: PackedFloat32Array = c.hi
		for k in range(lo.size()):
			if lo[k] == INF: continue
			var x := (c.origin as Vector2).x+off.x+(k%int(c.cols)+0.5)*float(c.cell)
			var z := (c.origin as Vector2).y+off.z+(k/int(c.cols)+0.5)*float(c.cell)
			dots.append([Vector3(x,hi[k]+off.y,z),str(i%10),1,lo[k]+off.y])
	for e: Dictionary in plan.edges:
		if e.kind == "gulf":
			for s: Array in e.path: dots.append([s[0],"~",2,(s[0] as Vector3).y])
		else:
			for s: Array in e.path: dots.append([s[0],"." if e.branch != "exit" else ":",2,(s[0] as Vector3).y])
	if plan.has("next"):
		var xf: Transform3D = plan.next.xform
		for isle: Dictionary in plan.next.isles:
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
