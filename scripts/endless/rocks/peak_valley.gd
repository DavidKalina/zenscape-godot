extends "res://scripts/endless/rocks/rock_kind.gd"
## The ice gorge's seracs (a rock kind, scripts/endless/rocks/rock_plan.gd):
## broken towers of ice (peak_serac.gd) heaped in the gorge's bowls, none in its
## narrows, and ranks of them across the mouth's spill (PeakSplit SPILL_*), the
## icefall that comes out of the gorge onto the valley.
##
## A lane stays open down the gorge's line and out over the spill (`kept`): it
## widens with the floor, since a plane drifts further in a bowl. Heaps stand
## between its edge and the walls' feet, so the line runs between them. Two
## towers either lean on each other (one mass to the flight) or stand an opening
## apart (WorldScale.opening(TOY_GAP)).
##
## --peak-ice=0 stands none, so it is the ice's whole A/B. --valley=0 too.

const WorldScale = preload("res://scripts/world_scale.gd")
const PeakIce = preload("res://scripts/endless/peak_ice.gd")
const Split = preload("res://scripts/endless/peak_split.gd")
const Serac = preload("res://scripts/endless/rocks/peak_serac.gd")

## The box (the massif's a, v) that holds them.
const BOX := Rect2(340.0,-760.0,1880.0,1090.0)
## How far (share of the way from the mouth to the saddle) the heaps go: the ice
## tapers out over the last of it.
const UP_TO := 0.87
## The floor's half-width (m) over which a stretch becomes a bowl.
const BOWL := Vector2(50.0,70.0)
## A heap every this far (m) along each side, and the chance one stands.
const HEAP_STEP := 22.0
const HEAP_CHANCE := 0.92
## The lane's half-width over the floor's: DRIFT m per m of the floor past
## DRIFT_FROM, plus LANE_PAD (m).
const DRIFT := 0.6
const DRIFT_FROM := 14.0
const LANE_PAD := 6.0
## The heaps may stand this far past the floor's edge, up the wall's foot (m).
const WALL_FOOT := 6.0
## A tower's foot may not span more than this much of the ground's fall per m of
## its reach, or it is on the wall.
const FOOT_FALL := 0.8
## The gap kept between towers that do not lean on each other (toy width).
const TOY_GAP := 6.0
## The cluster noise's scale (m).
const CLUSTER := 90.0
## The mouth's ranks: their first and last a, how many, their spacing across
## (m), the lane there (half-width, m), how far the last rank's middle bows down
## the flow.
const RANKS_A := Vector2(2052.0,2150.0)
const RANKS := 7
const RANK_STEP := 15.0
const MOUTH_LANE := 36.0
const RANK_BOW := 26.0
## The lane's way out past the mouth (a, v), the tongue's middle.
const OUT := [[2075.0,160.0],[2170.0,142.0],[2300.0,128.0]]
## --rock-start=valley: this far along the line, this high.
const START_ALT := 30.0

static var _cache := {}
static var _lock := Mutex.new()

## The cells (RockPlan.CELL) the box covers: {Vector2i: true}.
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
	if not PeakIce.wanted or not field.has_method("peak"): return []
	var peak: RefCounted = field.peak()
	if peak == null or not cells(peak).has(Vector2i(cx,cz)): return []
	var cell: float = preload("res://scripts/endless/rocks/rock_plan.gd").CELL
	var mine: Array = []
	for b: Array in pieces(field,peak):
		var q: Vector2 = b[0]
		if floori(q.x/cell) == cx and floori(q.y/cell) == cz: mine.append(b)
	if mine.is_empty(): return []
	return [_group(field,peak,mine,cx,cz)]

## The lane's half-width over a floor of half-width `half`.
static func lane_half(half: float) -> float:
	return LANE_PAD+DRIFT*maxf(half-DRIFT_FROM,0.0)

## The lane's points, the way out first: [Vector3(a, v, half kept)...], up the
## gorge to UP_TO.
static func kept() -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in range(OUT.size()-1,-1,-1):
		var p: Array = OUT[k]
		out.append(Vector3(float(p[0]),float(p[1]),MOUTH_LANE))
	var pts: PackedVector3Array = Split.line(Split.ICE)
	var hs: PackedFloat32Array = Split.halves(Split.ICE)
	for i in int(Split.saddle(Split.ICE)*UP_TO)+1:
		out.append(Vector3(pts[i].x,pts[i].y,maxf(lane_half(hs[i]),MOUTH_LANE) if i < 6 else lane_half(hs[i])))
	return out

## How far (a, v) lies outside the lane (m; under 0 inside it).
static func off_lane(a: float, v: float, lane: PackedVector3Array) -> float:
	var best := INF
	var q := Vector2(a,v)
	for i in lane.size()-1:
		var p0 := lane[i]
		var p1 := lane[i+1]
		var d := Vector2(p1.x-p0.x,p1.y-p0.y)
		var u := clampf((q-Vector2(p0.x,p0.y)).dot(d)/maxf(d.length_squared(),0.01),0.0,1.0)
		best = minf(best,q.distance_to(Vector2(p0.x,p0.y)+d*u)-lerpf(p0.z,p1.z,u))
	return best

## The line in world XZ, every `step` m or so, the mouth upward.
static func line(peak: RefCounted, step := 20.0) -> PackedVector2Array:
	var pts: PackedVector3Array = Split.line(Split.ICE)
	var out := PackedVector2Array()
	for i in range(0,Split.saddle(Split.ICE),maxi(int(step/Split.STRIDE),1)): out.append(peak.world(pts[i].x,pts[i].y))
	return out

## Every tower: [[XZ, radius, height over its ground, flow (XZ), long]...]
## (`long` how far it reaches across the flow over its radius), the same for
## every cell (cached by seed).
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

## How far a tower reaches past its centre (m), the widest way.
static func widest(b: Array) -> float:
	return float(b[1])*Serac.WIDEST*float(b[4])

static func _place(field: RefCounted, peak: RefCounted) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),"peak seracs"])
	var noise := FastNoiseLite.new()
	noise.seed = int(hash([int(field.seed),"peak serac groups"]))
	noise.frequency = 1.0/CLUSTER
	var lane := kept()
	_ranks(out,field,peak,lane,rng)
	_bowls(out,field,peak,lane,rng,noise)
	return out

## The heaps in the bowls: each side of the line, heap by heap, the biggest
## where the band between the lane and the wall has room.
static func _bowls(out: Array, field: RefCounted, peak: RefCounted, lane: PackedVector3Array, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var pts: PackedVector3Array = Split.line(Split.ICE)
	var hs: PackedFloat32Array = Split.halves(Split.ICE)
	var last := int(Split.saddle(Split.ICE)*UP_TO)
	for sg: float in [-1.0,1.0]:
		var s := rng.randf_range(0.0,HEAP_STEP)
		while s < last*Split.STRIDE:
			var at := s/Split.STRIDE
			s += HEAP_STEP*rng.randf_range(0.75,1.25)
			var i := int(at)
			var half := lerpf(hs[i],hs[i+1],at-i)
			var p := pts[i].lerp(pts[i+1],at-i)
			var roll := rng.randf()
			var heap := clampf(noise.get_noise_2d(p.x,p.y)*1.3+0.6,0.0,1.0)
			if roll > HEAP_CHANCE*smoothstep(BOWL.x,BOWL.y,half)*lerpf(0.5,1.0,heap): continue
			var way := Vector2(pts[i].x-pts[i+1].x,pts[i].y-pts[i+1].y).normalized()
			var across := Vector2(-way.y,way.x)*sg
			var keep := lane_half(half)
			var band := half+WALL_FOOT-keep
			# As big as the band holds: a giant's court takes all of it.
			var big := clampf(heap*0.6+rng.randf()*0.5,0.0,1.0)*smoothstep(14.0,44.0,band)
			var members: Array = Serac.cluster(rng,big)
			var reach := 0.0
			for m: Array in members: reach = maxf(reach,(m[0] as Vector2).length()+float(m[1])*Serac.WIDEST*float(m[3]))
			var off := keep+minf(reach,band*0.5)+rng.randf()*maxf(band-reach*2.0,0.0)
			var mid := Vector2(p.x,p.y)+across*off
			var flow := _world_way(peak,way)
			for k in members.size():
				var m: Array = members[k]
				var o: Vector2 = m[0]
				var q := mid+way*o.x+across*o.y
				# (A heap's own towers stand as close as they like: nothing flies between.)
				var stood := _try(out,field,peak,lane,q.x,q.y,float(m[1]),float(m[2]),float(m[3]),flow,WorldScale.opening(TOY_GAP) if k == 0 else 0.0)
				if not stood and k == 0: break

## The mouth's icefall: ranks across the spill, bowed down the flow, tall at its
## head and small at its foot, with the lane through them.
static func _ranks(out: Array, field: RefCounted, peak: RefCounted, lane: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	for k in RANKS:
		var t := float(k)/(RANKS-1)
		var a0 := lerpf(RANKS_A.x,RANKS_A.y,t)
		var wide := lerpf(Split.SPILL_HALF.x,Split.SPILL_HALF.y,t*t)
		var v := -wide+rng.randf_range(0.0,RANK_STEP)
		while v < wide:
			var u := v/wide
			var a := a0+lerpf(8.0,RANK_BOW,t)*(1.0-u*u)+rng.randf_range(-7.0,7.0)
			var at := Split.SPILL_V+v
			v += RANK_STEP*rng.randf_range(0.8,1.25)
			var r := lerpf(rng.randf_range(5.5,9.0),rng.randf_range(3.0,5.0),t)
			var up := r*lerpf(rng.randf_range(2.0,3.2),rng.randf_range(1.2,2.2),t)
			# Down the spill and a little out from its middle.
			var flow := _world_way(peak,Vector2(1.0,u*0.5).normalized())
			_try(out,field,peak,lane,a,at,r,up,rng.randf_range(1.05,1.4),flow,0.0)

## A way in the massif's frame (along a, along v) as a world XZ direction.
static func _world_way(peak: RefCounted, way: Vector2) -> Vector2:
	return (peak.world(way.x,way.y)-peak.world(0.0,0.0)).normalized()

## Stand a tower at (a, v) unless it meets the lane, a wall's foot or a
## neighbour: it leans on it, or stands `gap` m off.
static func _try(out: Array, field: RefCounted, peak: RefCounted, lane: PackedVector3Array, a: float, v: float, r: float, up: float, long: float, flow: Vector2, gap: float) -> bool:
	var wr := r*Serac.WIDEST*long
	if off_lane(a,v,lane) < wr: return false
	var w: Vector2 = peak.world(a,v)
	var low := INF
	var high := -INF
	for k in 8:
		var d := Vector2.from_angle(TAU*k/8.0)*wr
		var g := float(field.height(w.x+d.x,w.y+d.y))
		low = minf(low,g)
		high = maxf(high,g)
	if high-low > FOOT_FALL*wr*2.0: return false
	for o: Array in out:
		var d := (o[0] as Vector2).distance_to(w)
		var g := d-wr-widest(o)
		if g >= gap: continue
		if g > 0.0 or d < 0.7*maxf(r,float(o[1])): return false
	out.append([w,r,up,flow,long])
	return true

## Cell (cx, cz)'s towers as one group, anchored at their middle.
static func _group(field: RefCounted, peak: RefCounted, mine: Array, cx: int, cz: int) -> Dictionary:
	var mid := Vector2.ZERO
	for b: Array in mine: mid += b[0]
	mid /= float(mine.size())
	var pos := Vector3(mid.x,float(field.height(mid.x,mid.y)),mid.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),cx,cz,"peak serac shape"])
	var pillars: Array = []
	var reach := 0.0
	for b: Array in mine:
		var q: Vector2 = b[0]
		pillars.append(Serac.pillar(field,pos,q,float(b[1]),float(b[2]),float(b[4]),b[3],rng))
		reach = maxf(reach,q.distance_to(mid)+widest(b)*1.3)
	var pts := line(peak,40.0)
	var start: Vector2 = pts[0]
	var to: Vector2 = pts[2]-start
	return {"pos":pos,"reach":reach,"pillars":pillars,"foot":[],"by_arches":false,"bare":true,"on_peak":true,
		"approach":{"at":start,"heading":rad_to_deg(atan2(to.x,-to.y)),"alt":START_ALT},"form":"seracs","mesher":Serac,"ice":true}
