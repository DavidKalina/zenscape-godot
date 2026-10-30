extends "res://scripts/endless/rocks/rock_kind.gd"
## The Peak's approach valley (a rock kind, scripts/endless/rocks/rock_plan.gd):
## house-sized granite blocks over the boulder field (PeakMassif BOULDERS)
## and ice seracs on the icefall's steps (PeakMassif ICEFALL).
##
## One line runs up the valley's floor through both (`line`): a slalom
## weaving across the boulder field's middle (FIELD_WEAVE), then a thread
## weaving through the seracs (ICE_WEAVE), ending at the icefall's head where
## the stair begins. Nothing stands within LANE (an opening) of it, and a
## pole stands on the inside of each of its bends. Off it, the blocks and
## seracs fill the floor from a jittered lattice (in the massif's frame),
## kept by a cluster noise so they fall in groups; two of them either lean on
## each other (one rock to the flight) or stand at least an opening apart
## (WorldScale.opening(TOY_GAP)). Kept off the stair (whose path runs from
## the icefall's head, PeakStair.APPROACH_FROM, toward the couloir: smaller
## a) and the couloir's lift tube.
##
## A boulder: as the cirque's (peak_boulders.gd `_block`). A serac: a
## squared slab, long across the flow, tapering a little, leaning
## downstream, with a flat top; the most and tallest along the steps' lips.
## Both bare; the ground's paint gives them the floor's colour (scree on the
## boulder field, ice on the icefall).

const WorldScale = preload("res://scripts/world_scale.gd")
const PeakMassif = preload("res://scripts/endless/peak_massif.gd")
const PeakRoutes = preload("res://scripts/endless/peak_routes.gd")
const Boulders = preload("res://scripts/endless/rocks/peak_boulders.gd")

## The box (the massif's a, v) the valley's pieces stand in.
const BOX := Rect2(880.0,-440.0,1180.0,880.0)
## The line: its half-width kept clear (toy width, WorldScale.opening, so the
## clear lane is opening(TOY_LANE) wide), and its weaves: across the boulder
## field, [amplitude (m) off the valley's middle, half waves over the
## field]; across the icefall the same.
const TOY_LANE := 10.0
const FIELD_WEAVE := Vector2(45.0,3.0)
const ICE_WEAVE := Vector2(32.0,2.0)
## The line runs on past the field onto the glacier this far (m), and stops
## at the icefall's head (a), short of the stair's first flight.
const LINE_OUT := 200.0
const LINE_END := 870.0
## Each zone: [lattice step (m), chance a point holds a piece, least and most
## radius (m), height over radius least and most, kept this far inside the
## floor's edge (m)].
const FIELD := [24.0,0.38,4.0,9.0,1.0,1.7,18.0]
const SERACS := [19.0,0.5,4.5,8.5,1.3,2.6,16.0]
## The seracs' stretch along a: from past the stair's foot to the icefall's
## foot. STAIR_KEEP: m kept between a serac and the stair's first flight
## (along a: the stair runs from APPROACH_FROM toward smaller a).
const SERACS_A := Vector2(880.0,1245.0)
const STAIR_KEEP := 20.0
## Along a step's lip (the riser's top) the chance and height swell: within
## LIP m upstream of it, by LIP_MORE.
const LIP := 26.0
const LIP_MORE := Vector2(1.8,1.35)
## The boulder field's stretch (a), short of the icefall's foot.
const FIELD_A := Vector2(1275.0,2030.0)
## The gap kept between pieces that do not lean on each other (toy width).
const TOY_GAP := 6.0
## How far a piece reaches past its radius (corners, lumps, a serac's
## length across the flow).
const WIDEST := 1.3
const SERAC_LONG := 1.5
## No piece stands taller than this over its ground (m).
const TALLEST := 28.0
## Within LINE_NEAR m past the lane the chance swells by LINE_MORE, so the
## line runs between pieces.
const LINE_NEAR := 30.0
const LINE_MORE := 1.8
## The cluster noise's scale (m).
const CLUSTER := 70.0
## The poles on the line's bends: radius and height over radius.
const POLE := Vector2(8.5,1.9)
const SERAC_POLE := Vector2(7.0,2.8)
## --rock-start=valley: this far down the line from its start, this high.
const START_ALT := 30.0

static var _cache := {}
static var _lock := Mutex.new()

## The cells (RockPlan.CELL) the valley's box covers: {Vector2i: true}.
static func cells(peak: RefCounted) -> Dictionary:
	var out := {}
	if peak == null: return out
	var cell: float = preload("res://scripts/endless/rocks/rock_plan.gd").CELL
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	for c: Vector2 in [BOX.position,BOX.position+Vector2(BOX.size.x,0.0),BOX.position+Vector2(0.0,BOX.size.y),BOX.end]:
		var w: Vector2 = peak.world(c.x,c.y)
		lo = lo.min(w)
		hi = hi.max(w)
	for z in range(floori(lo.y/cell),floori(hi.y/cell)+1):
		for x in range(floori(lo.x/cell),floori(hi.x/cell)+1): out[Vector2i(x,z)] = true
	return out

static func plan_cell(field: RefCounted, cx: int, cz: int, _density: float, _rng: RandomNumberGenerator) -> Array:
	if not field.has_method("peak"): return []
	var peak: RefCounted = field.peak()
	if peak == null or not cells(peak).has(Vector2i(cx,cz)): return []
	var cell: float = preload("res://scripts/endless/rocks/rock_plan.gd").CELL
	var mine: Array = []
	for b: Array in pieces(field,peak):
		var q: Vector2 = b[0]
		if floori(q.x/cell) == cx and floori(q.y/cell) == cz: mine.append(b)
	if mine.is_empty(): return []
	return [_group(field,peak,mine,cx,cz)]

## The line's v at `a` (the massif's frame).
static func lane_v(a: float) -> float:
	var v := PeakMassif._valley_mid(a)
	if a >= PeakMassif.BOULDERS.x:
		var t := clampf((a-PeakMassif.BOULDERS.x)/(PeakMassif.BOULDERS.y-PeakMassif.BOULDERS.x),0.0,1.0)
		return v+FIELD_WEAVE.x*sin(PI*FIELD_WEAVE.y*t)
	var t := clampf((a-PeakMassif.ICEFALL.x)/(PeakMassif.ICEFALL.y-PeakMassif.ICEFALL.x),0.0,1.0)
	return v-ICE_WEAVE.x*sin(PI*ICE_WEAVE.y*t)

## The line's points (a, v), every `step` m along a, from the glacier down to
## the icefall's head (the way it is flown).
static func line_av(step := 10.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var a := PeakMassif.BOULDERS.y+LINE_OUT
	while a > LINE_END:
		out.append(Vector2(a,lane_v(a)))
		a -= step
	out.append(Vector2(LINE_END,lane_v(LINE_END)))
	return out

## The line in world XZ.
static func line(peak: RefCounted, step := 10.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in line_av(step): out.append(peak.world(p.x,p.y))
	return out

## The clear lane's half-width (m).
static func lane_half() -> float:
	return WorldScale.opening(TOY_LANE)*0.5

## How far (a, v) lies from the line (m, the massif's frame is metric).
static func off_line(a: float, v: float) -> float:
	var best := INF
	var s := -60.0
	while s <= 60.0:
		var b := a+s
		best = minf(best,Vector2(s,v-lane_v(b)).length())
		s += 3.0
	return best

## Every piece: [[XZ, radius, height over its ground, zone, long]...] (zone
## 0 boulder, 1 serac; `long` how far a serac reaches across the flow over
## its radius), the same for every cell (cached by seed).
static func pieces(field: RefCounted, peak: RefCounted) -> Array:
	var key := [int(field.seed),peak.centre,peak.facing]
	_lock.lock()
	var got: Variant = _cache.get(key)
	_lock.unlock()
	if got != null: return got
	var out := _place(field,peak)
	_lock.lock()
	_cache[key] = out
	_lock.unlock()
	return out

## How far a piece reaches past its centre (m), the widest way.
static func widest(b: Array) -> float:
	return float(b[1])*WIDEST*float(b[4])

static func _place(field: RefCounted, peak: RefCounted) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),"peak valley"])
	var noise := FastNoiseLite.new()
	noise.seed = int(hash([int(field.seed),"peak valley groups"]))
	noise.frequency = 1.0/CLUSTER
	var lift: Array = PeakRoutes.couloir(peak,Callable(field,"height")).points
	var keep := lane_half()
	# The poles first, on the inside of each bend (toward the valley's middle).
	for k in int(FIELD_WEAVE.y):
		var t := (k+0.5)/FIELD_WEAVE.y
		var a := lerpf(PeakMassif.BOULDERS.x,PeakMassif.BOULDERS.y,t)
		_try(out,peak,lift,a,lane_v(a),POLE.x,POLE.x*POLE.y,0,1.0,keep,true)
	for k in int(ICE_WEAVE.y):
		var t := (k+0.5)/ICE_WEAVE.y
		var a := lerpf(PeakMassif.ICEFALL.x,PeakMassif.ICEFALL.y,t)
		_try(out,peak,lift,a,lane_v(a),SERAC_POLE.x,SERAC_POLE.y*SERAC_POLE.x,1,SERAC_LONG,keep,true)
	for zone in 2:
		var z: Array = FIELD if zone == 0 else SERACS
		var span: Vector2 = FIELD_A if zone == 0 else SERACS_A
		var step := float(z[0])
		var na := int((span.y-span.x)/step)
		var nv := int(BOX.size.y/step)
		for i in range(na):
			for j in range(nv):
				var a := span.x+(i+rng.randf_range(0.1,0.9))*step
				var v := BOX.position.y+(j+rng.randf_range(0.1,0.9))*step
				var roll := rng.randf()
				var size := rng.randf()
				var tall := rng.randf()
				var long := rng.randf_range(1.15,SERAC_LONG) if zone == 1 else 1.0
				var half := _floor_half(a)
				if absf(v-PeakMassif._valley_mid(a)) > half-float(z[6]): continue
				var heap := clampf(noise.get_noise_2d(a,v)*1.2+0.5,0.0,1.0)
				var chance := float(z[1])*lerpf(0.2,1.7,heap)
				# Lining the line: more of them just off its lane.
				chance *= lerpf(LINE_MORE,1.0,smoothstep(0.0,LINE_NEAR,off_line(a,v)-keep-float(z[3])*WIDEST))
				var up_k := 1.0
				if zone == 1:
					var lip := _lip(a)
					chance *= lerpf(1.0,LIP_MORE.x,lip)
					up_k = lerpf(1.0,LIP_MORE.y,lip)
				if roll > chance: continue
				var r := lerpf(float(z[2]),float(z[3]),size*size)
				var up := minf(r*lerpf(float(z[4]),float(z[5]),tall)*up_k,TALLEST)
				_try(out,peak,lift,a,v,r,up,zone,long,keep,false)
	return out

## Place a piece at (a, v) unless it meets the line, the stair, the lift or a
## neighbour (leaning on one is allowed). `pole`: on a bend, pushed off the
## line toward the valley's middle until clear.
static func _try(out: Array, peak: RefCounted, lift: Array, a: float, v: float, r: float, up: float, zone: int, long: float, keep: float, pole: bool) -> bool:
	var wr := r*WIDEST*long
	if pole:
		var toward := signf(PeakMassif._valley_mid(a)-v)
		if toward == 0.0: toward = 1.0
		var n := 0
		while off_line(a,v) < keep+wr+1.0 and n < 40:
			v += toward*2.0
			n += 1
	elif off_line(a,v) < keep+wr: return false
	if zone == 1 and a-wr < _stair_from()+STAIR_KEEP: return false
	var w: Vector2 = peak.world(a,v)
	if not Boulders._off_lift(w,wr,lift): return false
	var gap := WorldScale.opening(TOY_GAP)
	for o: Array in out:
		var d := (o[0] as Vector2).distance_to(w)
		var ow := widest(o)
		var g := d-wr-ow
		if g >= gap: continue
		if pole or g > 0.0 or d < 0.7*maxf(r,float(o[1])): return false
	out.append([w,r,up,zone,long])
	return true

## Where the stair's approach begins (along a).
static func _stair_from() -> float:
	return preload("res://scripts/endless/peak_stair.gd").APPROACH_FROM

## The floor's half-width at `a` (PeakMassif `_valley`).
static func _floor_half(a: float) -> float:
	if a < PeakMassif.BOULDERS.x: return PeakMassif.FLOOR_HALF.x
	var t := (a-PeakMassif.BOULDERS.x)/(PeakMassif.BOULDERS.y-PeakMassif.BOULDERS.x)
	return lerpf(PeakMassif.FLOOR_HALF.x,PeakMassif.FLOOR_HALF.y,smoothstep(0.0,0.3,t))

## 1 just upstream of an icefall step's lip (the riser's top, PeakMassif
## `_valley`: each step's riser starts at its lip and falls toward larger a),
## easing to 0 LIP m upstream and over the riser.
static func _lip(a: float) -> float:
	var span := (PeakMassif.ICEFALL.y-PeakMassif.ICEFALL.x)/PeakMassif.ICEFALL_STEPS
	var best := 0.0
	for k in PeakMassif.ICEFALL_STEPS:
		var lip := PeakMassif.ICEFALL.x+k*span
		var d := a-lip
		best = maxf(best,1.0-smoothstep(0.0,LIP,absf(d)) if d < 0.0 else 1.0-smoothstep(0.0,span*PeakMassif.ICEFALL_RISER*0.6,d))
	return best

## Cell (cx, cz)'s pieces as one group, anchored at their middle.
static func _group(field: RefCounted, peak: RefCounted, mine: Array, cx: int, cz: int) -> Dictionary:
	var mid := Vector2.ZERO
	for b: Array in mine: mid += b[0]
	mid /= float(mine.size())
	var pos := Vector3(mid.x,float(field.height(mid.x,mid.y)),mid.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),cx,cz,"peak valley shape"])
	var pillars: Array = []
	var reach := 0.0
	for b: Array in mine:
		var q: Vector2 = b[0]
		if int(b[3]) == 0: pillars.append(Boulders._block(field,pos,q,float(b[1]),float(b[2]),rng))
		else: pillars.append(_serac(field,peak,pos,q,float(b[1]),float(b[2]),float(b[4]),rng))
		reach = maxf(reach,q.distance_to(mid)+widest(b)*1.3)
	var pts := line(peak,50.0)
	var start: Vector2 = pts[0]
	var to: Vector2 = pts[2]-start
	return {"pos":pos,"reach":reach,"pillars":pillars,"foot":[],"by_arches":false,"bare":true,"on_peak":true,
		"approach":{"at":start,"heading":rad_to_deg(atan2(to.x,-to.y)),"alt":START_ALT},"form":"valley"}

## One serac at world XZ `q`: radius `r` along the flow, `long` times it
## across, standing `up` m over the high side of its ground.
static func _serac(field: RefCounted, peak: RefCounted, pos: Vector3, q: Vector2, r: float, up: float, long: float, rng: RandomNumberGenerator) -> Dictionary:
	var low := INF
	var high := -INF
	var side: Vector2 = peak.side
	var fwd: Vector2 = peak.facing
	for k in range(9):
		var ang := TAU*k/8.0
		var d := Vector2.ZERO if k == 0 else fwd*cos(ang)*r+side*sin(ang)*r*long
		var g := float(field.height(q.x+d.x,q.y+d.y))
		low = minf(low,g)
		high = maxf(high,g)
	var ground := float(field.height(q.x,q.y))
	var over := maxf(high-ground,0.0)
	var tall := over+up
	var rf := r*rng.randf_range(0.9,1.1)
	var rs := r*long
	var profile: Array = []
	var ring := func(y: float, k: float) -> void:
		if not profile.is_empty() and y < float(profile.back()[0])+0.3: return
		profile.append([y,rs*k,rf*k,0.0,0.0])
	ring.call(low-ground-1.5,1.0)
	ring.call(over,1.0)
	ring.call(over+up*0.45,rng.randf_range(0.94,1.02))
	ring.call(tall-up*0.08,rng.randf_range(0.82,0.92))
	ring.call(tall,rng.randf_range(0.7,0.8))
	# Leaning downstream (toward the meadow, +a), as seracs topple.
	var lean := fwd*rng.randf_range(0.05,0.3)*r+side*rng.randf_range(-0.1,0.1)*r
	for c: Array in profile:
		var u := clampf((float(c[0])-over)/maxf(up,0.1),0.0,1.0)
		c[3] = lean.x*u*u
		c[4] = lean.y*u*u
	# Long across the flow: the ring's x along the side, turned a little.
	var yaw := atan2(side.y,side.x)+rng.randf_range(-0.25,0.25)
	return {"at":Vector3(q.x-pos.x,ground-pos.y,q.y-pos.z),"profile":profile,"yaw":yaw,"dome":rng.randf_range(0.2,0.9),
		"square":rng.randf_range(0.3,0.5),"lump":clampf(r*0.8,1.5,5.0),"lumps":0.06,"grain":0.02,"ledges":0.03,"flutes":0.08,
		"bed":rng.randf_range(2.5,4.5),"ring_every":clampf(tall/8.0,0.8,1.6),"segments":16,"seed":rng.randi(),
		"tint":Color(0.9,1.0,1.12)}
