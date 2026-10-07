extends RefCounted
## The waterfall terraces' layout (scripts/cluster_motifs.gd "falls"), for
## the cluster solver (scripts/cluster_solver.gd): islets stepping down, each
## pond pouring off its lip into the next one's pool, the last fall dropping
## on into the cloud sea; and what stands on them, as features the dresser
## (scripts/cluster_falls_dress.gd) stands up. Plain data, safe on a worker.
##
## The fall relation ({type: "fall", to, drop, gap}): a member laid under
## the lip of the member it names, so that member's fall lands in its pool.
##   1. The upper member's pond gives the lip (its channel's end on the rim),
##      the water's level and the way out (SkyIslet `water`).
##   2. The lower member's pool: a pond of POOL radius set in from its rim
##      on the side facing the lip (POOL_IN of its radius, so its banks stand
##      whole), its water SINK under the islets' usual level (a basin the
##      fall drops into); its own channel leaving TURN off the fall's way, so
##      the run of terraces winds on round one way.
##   3. Where it stands: its pool's middle on the line out from the lip, its
##      rim `gap` m out from the lip, its water `drop` m under the lip's; the
##      fall lands LAND_IN of the pool's radius short of the pool's middle.
##      Tried along a few swings of the pool round the member's middle until
##      it keeps clear of every member laid before, and its own fall (on to
##      the sea, unless a later member takes it) pours clear of them.
##   4. The upper member's recipe gets `fall_to` ({to, lip, out, drop, speed,
##      pool}, its frame): SkyIslets `_fall_rings` throws its curtain at
##      `speed` so it lands at `pool`, and lays no thread on to the sea; the
##      lower member gets a "plunge" feature (the splash, the mist ring, the
##      light that catches the fall at night).
##
## Features (ClusterSolver `_feature` hands these here):
##   paddies: a row of PADDIES stepped ponds (rice terraces) on the land, each
##     ground levelled PADDY_STEP under the last, a shallow sheet of water on
##     it, low bunds round it, rows of young shoots in some; lantern posts
##     along their downhill edge;
##   moss: soft faceted moss cushions and ferns round a pond's banks, its
##     channel and its pool's inflow;
##   wheel: a small undershot mill wheel turning in a member's channel (one
##     to a cluster), on two posts;
##   brook: a little timber footbridge over a member's channel, so a walker
##     crosses the brook;
##   edge_lanterns: lantern posts along a terrace's edge, flanking where its
##     fall comes in and where its own leaves.

const SkyIslet = preload("res://scripts/sky_islet.gd")
const Footbridge = preload("res://scripts/footbridge.gd")

## A fall: its drop (m, lip to the pool's water), the rim to rim gap (m)
## across the line it falls along, and how far under the pool's water the
## curtain runs on (m, out of sight) so it never ends in the air.
const DROP := Vector2(3.6,5.4)
const GAP := Vector2(1.7,2.5)
const SUNK := 0.35
## The pool: its radius (m), its middle this many radii (plus POOL_PAD m) in
## from the shore, its water this far under the islets' usual level.
const POOL := Vector2(1.7,2.2)
const POOL_IN := 1.25
const POOL_PAD := 0.25
const SINK := 0.22
## Where the fall lands: this share of the pool's radius short of its middle.
const LAND_IN := 0.5
## The water's speed off the lip at most (m/s): a member pushed further out
## to keep clear takes a deeper drop rather than a harder throw, by up to
## DROP_STRETCH m past the relation's own; the pushes tried (m).
const MAX_SPEED := 4.8
const DROP_STRETCH := 1.5
const PUSH := [0.0,0.4,0.8,1.3,1.9,2.6]
## The ways a pool is tried round its member's middle (rad off facing the
## lip straight), and how far each terrace's own lip turns off the fall's way
## (rad, one way for the whole cluster).
const SWINGS := [0.0,0.3,-0.3,0.6,-0.6,0.9,-0.9,1.2,-1.2]
const TURN := Vector2(0.35,0.9)
## The anchor's first lip: the ways round it tried, and how far out past
## the rim (m) the sky must be open.
const OPEN_WAYS := 24
const OPEN_LOOK := 8.0
## The arc must pass this far over any land it crosses (m) but the pool's.
const ARC_CLEAR := 0.25
## A fall to the sea must pour clear of every lower member's rim by this (m)
## over the first FALL_LOOK m out from its lip.
const SEA_CLEAR := 1.0
const FALL_LOOK := 5.0
const G := 9.81
## Rim samples (as ClusterSolver RIM_SAMPLES).
const RIM_SAMPLES := 32
## Paddies: how many (the feature's count overrides), a paddy's half
## extents across the row and along it (m), the gap between two, the step
## down from one to the next (m), the water's depth, the bund's width and
## height over the water, the shoots' spacing (m) and the share planted.
const PADDIES := Vector2i(3,4)
const PADDY_ACROSS := Vector2(1.9,2.5)
const PADDY_ALONG := Vector2(1.1,1.4)
const PADDY_GAP := 0.32
const PADDY_STEP := 0.34
const PADDY_DEPTH := 0.07
const BUND := Vector2(0.24,0.1)
const SHOOTS := 0.42
const PLANTED := 0.55
## Moss: cushions round a pond (count range), their radius and height (m);
## ferns among them.
const MOSS := Vector2i(10,16)
const MOSS_SIZE := Vector2(0.22,0.55)
const MOSS_HIGH := Vector2(0.08,0.2)
const FERNS := Vector2i(4,8)
## The wheel: its radius and width (m), along the channel at this share
## from the pond to the lip, its axle this far over the water.
const WHEEL := Vector2(0.8,0.42)
const WHEEL_AT := 0.62
const WHEEL_LIFT := 0.42
## The brook's footbridge: its ends this far past the channel's half width.
const BROOK_BANK := 0.6

# --- The fall relation ---------------------------------------------------------------

## Lays `m` under `parent`'s lip (see the top). True when it stands.
static func lay(m: Dictionary, parent: Dictionary, rel: Dictionary, placed: Array, plan: Dictionary, rng: RandomNumberGenerator, clear: Callable) -> bool:
	# The first fall leaves the anchor where its rim stands out into open
	# sky: its pond shaped again to pour that way.
	if parent.role_data.get("anchor",false) and not plan.has("falls") and not plan.get("lead_lip",false):
		plan.lead_lip = true
		_open_lead(parent,placed)
	var water: Dictionary = parent.shape.water()
	if water.is_empty(): return false
	var out: Vector2 = (water.out as Vector2).normalized()
	var lip := Vector3(water.lip.x,float(water.level),water.lip.y)
	var lip_home: Vector3 = (parent.offset as Vector3)+lip
	if not plan.has("fall_turn"): plan.fall_turn = 1.0 if rng.randf() < 0.5 else -1.0
	var drops: Vector2 = rel.get("drop",DROP)
	var gaps: Vector2 = rel.get("gap",GAP)
	var r := rng.randf_range(POOL.x,POOL.y)
	var level := SkyIslet.WATER-SINK
	for k in range(SWINGS.size()):
		var way := Vector2.from_angle((-out).angle()+float(SWINGS[k]))
		var pool := r
		var t := _pool_reach(m.shape,way,pool)
		if t < 0.0:
			pool = POOL.x*0.8
			t = _pool_reach(m.shape,way,pool)
		if t < 0.0: continue
		var middle := way*t
		# The member's rim from the pool's middle back toward the lip.
		var back := 0.0
		while back < 40.0 and m.shape.on_land(middle-out*(back+0.1)): back += 0.1
		var gap := rng.randf_range(gaps.x,gaps.y)
		var drop := rng.randf_range(drops.x,drops.y)
		# Pushed out further until it keeps clear, the drop deepening so the
		# water is never thrown faster than MAX_SPEED.
		var at := Vector3.INF
		var reach := 0.0
		for extra: float in PUSH:
			reach = gap+extra+back-LAND_IN*pool
			var deep := maxf(drop,0.5*G*pow(reach/MAX_SPEED,2.0))
			if deep > drops.y+DROP_STRETCH: break
			var pool_home := Vector2(lip_home.x,lip_home.z)+out*(gap+extra+back)
			var try_at := Vector3(pool_home.x-middle.x,lip_home.y-deep-level,pool_home.y-middle.y)
			if clear.call(m,try_at,placed):
				at = try_at
				drop = deep
				break
		if at == Vector3.INF: continue
		# Its own lip leaves TURN off the fall's way, where its rim stands
		# out most; shaped with its pool.
		var onward := _onward(m.shape,out,float(plan.fall_turn),rng)
		var spec: Dictionary = (m.shape.recipe as Dictionary).duplicate(true)
		spec.pond = {"at":middle,"radius":pool,"lip":m.shape.rim_point(onward.angle()),"level":level}
		var shape: RefCounted = SkyIslet.author(int(m.seed),spec)
		var speed := reach/sqrt(2.0*drop/G)
		var landing := Vector3(lip.x+out.x*reach,lip.y-drop,lip.z+out.y*reach)
		if not _arc_clear(lip_home,out,drop,reach,shape,at,placed,parent): continue
		if not _sea_clear(shape,at,placed): continue
		m.shape = shape
		m.rim = rim_of(shape)
		m.offset = at
		m.y = at.y
		parent.shape.recipe.fall_to = {"to":m.name,"lip":lip,"out":Vector3(out.x,0.0,out.y),"drop":drop,"speed":speed,"pool":landing}
		var local := Vector2(landing.x,landing.z)+Vector2(parent.offset.x-at.x,parent.offset.z-at.z)
		m.features.append({"type":"plunge","at":local,"y":level,"way":out,"drop":drop})
		if not plan.has("falls"): plan.falls = []
		plan.falls.append({"from":parent.name,"to":m.name,"drop":drop,"reach":reach,"speed":speed})
		return true
	return false

## The anchor's pond shaped again (its outline, and so its rim, the same)
## to pour off the rim where it stands out most into open sky: a lobe, not
## a bay, its way out clear of the members laid round it.
static func _open_lead(lead: Dictionary, placed: Array) -> void:
	var shape: RefCounted = lead.shape
	var water: Dictionary = shape.water()
	var r: float = float(water.radius) if not water.is_empty() else POOL.y
	var best := -INF
	var best_way := Vector2.RIGHT
	for k in range(OPEN_WAYS):
		var a := TAU*k/OPEN_WAYS
		var way := Vector2.from_angle(a)
		var score := _stands_out(shape,a)*2.0
		var ahead: Vector2 = Vector2(lead.offset.x,lead.offset.z)+shape.rim_point(a)+way*OPEN_LOOK
		var room := OPEN_LOOK
		for q: Dictionary in placed:
			if q == lead: continue
			var local: Vector2 = ahead-Vector2(q.offset.x,q.offset.z)
			for p: Vector2 in q.rim: room = minf(room,local.distance_to(p))
		score += room
		if score > best:
			best = score
			best_way = way
	# The pond in from that rim, deep enough in for its banks.
	var rim: Vector2 = shape.rim_point(best_way.angle())
	var at := rim
	var need := r*1.3+1.2
	while at.length() > 0.5 and shape.inland(at) < need: at -= best_way*0.2
	var spec: Dictionary = (shape.recipe as Dictionary).duplicate(true)
	spec.pond = {"at":at,"radius":r,"lip":rim}
	lead.shape = SkyIslet.author(int(lead.seed),spec)

## How far the rim at angle `a` stands out past the rim either side of it
## (m): a lobe's tip high, a bay's back low.
static func _stands_out(shape: RefCounted, a: float) -> float:
	return shape.rim_radius(a)-0.5*(shape.rim_radius(a-0.4)+shape.rim_radius(a+0.4))

## The way a terrace's own lip leaves: TURN off the fall in (`out`), one
## way (`turn`), where its rim stands out most.
static func _onward(shape: RefCounted, out: Vector2, turn: float, rng: RandomNumberGenerator) -> Vector2:
	var best := -INF
	var best_way := out.rotated(turn*TURN.x)
	for k in range(5):
		var way := out.rotated(turn*lerpf(TURN.x,TURN.y,k/4.0))
		var score := _stands_out(shape,way.angle())+rng.randf()*0.3
		if score > best:
			best = score
			best_way = way
	return best_way

## How far from `shape`'s middle along `way` a pool of radius `r` can stand,
## as near the rim as its banks allow; -1 if nowhere.
static func _pool_reach(shape: RefCounted, way: Vector2, r: float) -> float:
	var need := POOL_IN*r+POOL_PAD
	var best := -1.0
	var t := 0.0
	while t < float(shape.reach):
		var p := way*t
		if not shape.on_land(p): break
		if shape.inland(p) >= need: best = t
		t += 0.2
	return best

## True when the fall from `lip_home` out along `out`, dropping `drop` over
## `reach` m, passes ARC_CLEAR over all land under it but the pool's water
## (the lower member, `shape` at `at`, and every member laid).
static func _arc_clear(lip_home: Vector3, out: Vector2, drop: float, reach: float, shape: RefCounted, at: Vector3, placed: Array, parent: Dictionary) -> bool:
	var water: Dictionary = shape.water()
	for k in range(4,21):
		var x := reach*k/20.0
		var y := lip_home.y-drop*(x/reach)*(x/reach)
		var p := Vector2(lip_home.x,lip_home.z)+out*x
		var local := p-Vector2(at.x,at.z)
		if shape.on_land(local) and local.distance_to(water.middle) > float(water.radius)*0.95:
			if y < at.y+shape.ground_at(local)+ARC_CLEAR: return false
		for q: Dictionary in placed:
			if q == parent and k < 8: continue
			var ql: Vector2 = p-Vector2(q.offset.x,q.offset.z)
			if q.shape.on_land(ql) and y < q.offset.y+q.shape.ground_at(ql)+ARC_CLEAR: return false
	return true

## True when `shape` standing at `at` pours its own fall (on to the sea)
## clear of every member laid lower than its lip.
static func _sea_clear(shape: RefCounted, at: Vector3, placed: Array) -> bool:
	var water: Dictionary = shape.water()
	if water.is_empty(): return true
	var lip_home: Vector3 = at+Vector3(water.lip.x,float(water.level),water.lip.y)
	for q: Dictionary in placed:
		if not _pours_clear(lip_home,water.out,q.offset,q.rim): return false
	return true

static func _pours_clear(lip_home: Vector3, out: Vector2, q_at: Vector3, q_rim: PackedVector2Array) -> bool:
	if q_at.y > lip_home.y: return true
	for k in range(6):
		var p := Vector2(lip_home.x,lip_home.z)+out*(0.5+FALL_LOOK*k/5.0)-Vector2(q_at.x,q_at.z)
		if Geometry2D.is_point_in_polygon(p,q_rim): return false
		for i in range(q_rim.size()):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,q_rim[i],q_rim[(i+1)%q_rim.size()])) < SEA_CLEAR: return false
	return true

static func rim_of(shape: RefCounted) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(RIM_SAMPLES): out.append(shape.rim_point(TAU*k/RIM_SAMPLES))
	return out

# --- Features --------------------------------------------------------------------------

## Lays feature `f` (paddies, moss, wheel, brook, edge_lanterns) on `m`.
## False when it found no room.
static func feature(m: Dictionary, f: Dictionary, rng: RandomNumberGenerator, plan: Dictionary) -> bool:
	match str(f.type):
		"paddies": return _paddies(m,f,rng)
		"moss": return _moss(m,rng)
		"wheel":
			if plan.get("has_wheel",false): return true
			var ok := _wheel(m)
			if ok: plan.has_wheel = true
			return ok
		"brook": return _brook(m,plan)
		"edge_lanterns": return _edge_lanterns(m)
	return false

## The rice terraces: a row of paddies along an axis, found on the land as
## one rectangle, the highest end first, each stepped PADDY_STEP down.
static func _paddies(m: Dictionary, f: Dictionary, rng: RandomNumberGenerator) -> bool:
	var shape: RefCounted = m.shape
	var counts: Vector2i = f.get("count",PADDIES)
	var n := rng.randi_range(counts.x,counts.y)
	var across := rng.randf_range(PADDY_ACROSS.x,PADDY_ACROSS.y)
	var along := rng.randf_range(PADDY_ALONG.x,PADDY_ALONG.y)
	var pitch := along*2.0+PADDY_GAP
	var length := pitch*n-PADDY_GAP
	var axes: Array = [Vector2.RIGHT,Vector2.DOWN]
	var first := rng.randi() % 2
	for k in range(2):
		var axis: Vector2 = axes[(first+k) % 2]
		var whole := Vector2(length*0.5,across) if axis.x != 0.0 else Vector2(across,length*0.5)
		var spot: Variant = shape.find_spot(0.0,0.9,1.8,[],{"middle":0.3},whole,1.4)
		if spot == null: continue
		var at: Vector2 = spot
		# Highest end first.
		var a: Vector2 = at-axis*(length*0.5-along)
		var b: Vector2 = at+axis*(length*0.5-along)
		var way := axis if shape.ground_at(a) >= shape.ground_at(b) else -axis
		var start: Vector2 = a if way == axis else b
		var half := Vector2(along,across) if axis.x != 0.0 else Vector2(across,along)
		var top: float = shape.ground_at(start)
		var pads: Array = []
		for i in range(n):
			var c: Vector2 = start+way*pitch*i
			var y: float = top-PADDY_STEP*i
			shape.claim(c,0.0,y-shape.ground_at(c),half)
			pads.append({"rect":Rect2(c-half,half*2.0),"y":y,"planted":false})
		# Young shoots in rows in some, the rest open water.
		for i in range(n):
			var pad: Dictionary = pads[i]
			if rng.randf() > PLANTED and i != 1: continue
			pad.planted = true
			var rect: Rect2 = pad.rect
			var z := rect.position.y+BUND.x+0.2
			while z < rect.end.y-BUND.x-0.1:
				var x := rect.position.x+BUND.x+0.2
				while x < rect.end.x-BUND.x-0.1:
					shape.add_record("grass_tuft",Vector2(x+rng.randf_range(-0.04,0.04),z+rng.randf_range(-0.04,0.04)),rng.randf()*TAU,rng.randf_range(0.5,0.62))
					x += SHOOTS
				z += SHOOTS
		m.features.append({"type":"paddies","pads":pads,"way":way})
		# Lanterns down the row's side, at its foot and its head.
		var side := Vector2(-way.y,way.x)*(across+0.55)
		var spots: Array = [start-way*(along+0.5)+side,start+way*(pitch*(n-1)+along+0.5)-side]
		if n >= 4: spots.append(start+way*pitch*1.5+side)
		for p: Vector2 in spots:
			if shape.on_land(p) and not shape.wet(p) and shape.inland(p) > 0.5:
				m.features.append({"type":"post","at":p,"angle":_facing(-side.normalized())})
		return true
	return false

## Post angle whose arm (its -Z) points along `d`.
static func _facing(d: Vector2) -> float:
	return atan2(-d.x,-d.y)

## Moss cushions and ferns round the pond's bank, along its channel and by
## the plunge.
static func _moss(m: Dictionary, rng: RandomNumberGenerator) -> bool:
	var shape: RefCounted = m.shape
	var water: Dictionary = shape.water()
	if water.is_empty(): return false
	var middle: Vector2 = water.middle
	var r: float = water.radius
	var cushions: Array = []
	var want := rng.randi_range(MOSS.x,MOSS.y)
	for attempt in range(want*4):
		if cushions.size() >= want: break
		var p: Vector2
		var roll := rng.randf()
		if roll < 0.6: p = middle+Vector2.from_angle(rng.randf()*TAU)*r*rng.randf_range(1.05,1.75)
		else:
			var t := rng.randf()
			var q: Vector2 = middle.lerp(water.lip,t)
			var way: Vector2 = ((water.lip as Vector2)-middle).normalized()
			p = q+Vector2(-way.y,way.x)*(SkyIslet.CHANNEL+rng.randf_range(0.1,0.6))*(1.0 if rng.randf() < 0.5 else -1.0)
		if not shape.on_land(p) or shape.wet(p) or shape.inland(p) < 0.15 or _near_claim(shape,p): continue
		var size := rng.randf_range(MOSS_SIZE.x,MOSS_SIZE.y)
		cushions.append(Vector4(p.x,p.y,size,rng.randf_range(MOSS_HIGH.x,MOSS_HIGH.y)*(0.6+size)))
	var ferns := rng.randi_range(FERNS.x,FERNS.y)
	for k in range(ferns*3):
		if ferns <= 0: break
		var p := middle+Vector2.from_angle(rng.randf()*TAU)*r*rng.randf_range(1.3,2.0)
		if not shape.on_land(p) or shape.wet(p) or shape.inland(p) < 0.4 or _near_claim(shape,p): continue
		shape.add_record("fern",p,rng.randf()*TAU,rng.randf_range(0.6,0.9))
		ferns -= 1
	if cushions.is_empty(): return false
	m.features.append({"type":"moss","cushions":cushions})
	return true

static func _near_claim(shape: RefCounted, p: Vector2) -> bool:
	for c: Vector4 in shape.claims:
		var reach := Vector2(c.z,c.w).length() if c.w > 0.0 else c.z
		if p.distance_to(Vector2(c.x,c.y)) < reach+0.6: return true
	for deck: Dictionary in shape.decks:
		for end: Vector3 in [deck.a,deck.b]:
			if p.distance_to(Vector2(end.x,end.z)) < 1.0: return true
	return false

## The mill wheel across the channel, WHEEL_AT of the way from the pond to
## the lip, its posts on the banks.
static func _wheel(m: Dictionary) -> bool:
	var shape: RefCounted = m.shape
	var water: Dictionary = shape.water()
	if water.is_empty(): return false
	var middle: Vector2 = water.middle
	var lip: Vector2 = water.lip
	var way := (lip-middle).normalized()
	var length := middle.distance_to(lip)
	var across := Vector2(-way.y,way.x)
	for t: float in [WHEEL_AT,WHEEL_AT-0.12,WHEEL_AT+0.1,0.45]:
		var at := middle+way*length*t
		if at.distance_to(middle) < float(water.radius)+WHEEL.x+0.3 or at.distance_to(lip) < WHEEL.x+0.8: continue
		var posts: Array = [at+across*(SkyIslet.CHANNEL+0.3),at-across*(SkyIslet.CHANNEL+0.3)]
		var ok := true
		for p: Vector2 in posts:
			if not shape.on_land(p) or shape.wet(p) or shape.inland(p) < 0.3: ok = false
		if not ok: continue
		var blocks: Array = shape.recipe.get("blocks",[]).duplicate()
		for p: Vector2 in posts: blocks.append(Vector3(p.x,p.y,0.25))
		shape.recipe.blocks = blocks
		_clear_objects(shape,at,WHEEL.x+0.8)
		m.features.append({"type":"wheel","at":at,"y":float(water.level)+WHEEL_LIFT,"way":way,
			"posts":[Vector3(posts[0].x,shape.ground_at(posts[0]),posts[0].y),Vector3(posts[1].x,shape.ground_at(posts[1]),posts[1].y)]})
		return true
	return false

## A footbridge over the channel, between the pond and the lip (clear of a
## wheel), as a bridge of the plan from the member to itself.
static func _brook(m: Dictionary, plan: Dictionary) -> bool:
	var shape: RefCounted = m.shape
	var water: Dictionary = shape.water()
	if water.is_empty(): return false
	var middle: Vector2 = water.middle
	var lip: Vector2 = water.lip
	var way := (lip-middle).normalized()
	var length := middle.distance_to(lip)
	var across := Vector2(-way.y,way.x)
	var wheel := {}
	for f: Dictionary in m.features:
		if f.type == "wheel": wheel = f
	for t: float in [0.35,0.45,0.28,0.55,0.7]:
		var at := middle+way*length*t
		if at.distance_to(middle) < float(water.radius)*1.5 or at.distance_to(lip) < 1.4: continue
		if not wheel.is_empty() and at.distance_to(wheel.at) < WHEEL.x+1.6: continue
		var a2 := at-across*(SkyIslet.CHANNEL+BROOK_BANK)
		var b2 := at+across*(SkyIslet.CHANNEL+BROOK_BANK)
		var ok := true
		for p: Vector2 in [a2,b2,a2-across*0.5,b2+across*0.5]:
			if not shape.on_land(p) or shape.wet(p) or shape.inland(p) < 0.4: ok = false
		if not ok: continue
		var a := Vector3(a2.x,shape.ground_at(a2)+0.05,a2.y)
		var b := Vector3(b2.x,shape.ground_at(b2)+0.05,b2.y)
		var span := a2.distance_to(b2)
		if absf(a.y-b.y) > span*Footbridge.MAX_GRADE*0.8: continue
		shape.decks.append({"a":a,"b":b,"width":Footbridge.WIDTH,"bow":Footbridge.bow(span)})
		_clear_objects(shape,a2,0.8)
		_clear_objects(shape,b2,0.8)
		plan.bridges.append({"from":m.name,"to":m.name,"a":a,"b":b,"span":span})
		return true
	return false

static func _clear_objects(shape: RefCounted, at: Vector2, reach: float) -> void:
	shape.objects = shape.objects.filter(func(o: Dictionary) -> bool: return Vector2(o.x,o.z).distance_to(at) > reach)

## Lantern posts along a terrace's edge: either side of where its fall
## comes in (lit, the fall catches the light) and by its own lip.
static func _edge_lanterns(m: Dictionary) -> bool:
	var shape: RefCounted = m.shape
	var water: Dictionary = shape.water()
	if water.is_empty(): return false
	var middle: Vector2 = water.middle
	var spots: Array = []
	for f: Dictionary in m.features:
		if f.type != "plunge": continue
		var inflow: Vector2 = -(f.way as Vector2)
		var side := Vector2(-inflow.y,inflow.x)
		for s: float in [-1.0,1.0]:
			for reach: float in [1.35,1.6,1.9]:
				var p: Vector2 = middle+(inflow*0.55+side*s).normalized()*float(water.radius)*reach
				if _post_ok(shape,p):
					spots.append([p,middle-p])
					break
	var lip: Vector2 = water.lip
	var way := (lip-middle).normalized()
	for s: float in [1.0,-1.0]:
		var p := lip-way*1.1+Vector2(-way.y,way.x)*s*(SkyIslet.CHANNEL+0.6)
		if _post_ok(shape,p):
			spots.append([p,lip-p])
			break
	for entry: Array in spots: m.features.append({"type":"post","at":entry[0],"angle":_facing((entry[1] as Vector2).normalized())})
	return not spots.is_empty()

static func _post_ok(shape: RefCounted, p: Vector2) -> bool:
	return shape.on_land(p) and not shape.wet(p) and shape.inland(p) > 0.45 and not _near_claim(shape,p) and shape.deck_y(p) == -INF

# --- Validation --------------------------------------------------------------------------

## What is wrong with a plan's falls and terraces, as sentences: a fall that
## misses its pool or lands off its level, one whose arc cuts through land,
## a fall to the sea that pours onto a lower member, paddies off the land or
## in the pond, a wheel or brook bridge off its banks. Empty for a plan with
## none of them.
static func validate(plan: Dictionary) -> Array:
	var problems: Array = []
	if not plan.has("falls"): return problems
	var by_name := {}
	for m: Dictionary in plan.members: by_name[m.name] = m
	for m: Dictionary in plan.members:
		var shape: RefCounted = m.shape
		var water: Dictionary = shape.water()
		if shape.recipe.has("fall_to"):
			var to: Dictionary = shape.recipe.fall_to
			var low: Dictionary = by_name.get(to.to,{})
			if low.is_empty():
				problems.append("fall from %s to a member not laid" % m.name)
				continue
			var landing: Vector3 = (m.offset as Vector3)+(to.pool as Vector3)-(low.offset as Vector3)
			var pool: Dictionary = low.shape.water()
			if pool.is_empty() or Vector2(landing.x,landing.z).distance_to(pool.middle) > float(pool.radius)*0.7:
				problems.append("fall misses its pool: %s to %s" % [m.name,low.name])
			elif absf(landing.y-float(pool.level)) > 0.05:
				problems.append("fall lands off the water: %s to %s (%.2f m)" % [m.name,low.name,landing.y-float(pool.level)])
			var placed: Array = (plan.members as Array).filter(func(q: Dictionary) -> bool: return q != low)
			var lip_home: Vector3 = (m.offset as Vector3)+(to.lip as Vector3)
			var out := Vector2(to.out.x,to.out.z)
			var reach := Vector2(to.pool.x-to.lip.x,to.pool.z-to.lip.z).length()
			if not _arc_clear(lip_home,out,float(to.drop),reach,low.shape,low.offset,placed,m):
				problems.append("fall cuts through land: %s to %s" % [m.name,low.name])
		elif not water.is_empty():
			var lip_home: Vector3 = (m.offset as Vector3)+Vector3(water.lip.x,float(water.level),water.lip.y)
			for q: Dictionary in plan.members:
				if q == m: continue
				if not _pours_clear(lip_home,water.out,q.offset,rim_of(q.shape)):
					problems.append("fall pours onto a member: %s onto %s" % [m.name,q.name])
		for f: Dictionary in m.features:
			match str(f.type):
				"paddies":
					for pad: Dictionary in f.pads:
						var rect: Rect2 = pad.rect
						for c: Vector2 in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y),rect.get_center()]:
							if not shape.on_land(c) or shape.wet(c): problems.append("paddy off the land or in water on %s" % m.name)
						if absf(shape.ground_at(rect.get_center())-float(pad.y)) > 0.05: problems.append("paddy not level on %s" % m.name)
				"wheel":
					for p: Vector3 in f.posts:
						if not shape.on_land(Vector2(p.x,p.z)) or shape.wet(Vector2(p.x,p.z)): problems.append("wheel post off its bank on %s" % m.name)
				"plunge":
					if water.is_empty() or (f.at as Vector2).distance_to(water.middle) > float(water.radius)*0.7: problems.append("plunge out of the pool on %s" % m.name)
	return problems
