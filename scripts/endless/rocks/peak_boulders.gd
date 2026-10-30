extends "res://scripts/endless/rocks/rock_kind.gd"
## The Peak's boulders (a rock kind, scripts/endless/rocks/rock_plan.gd):
## fallen granite blocks on the summit cirque (PeakMassif `cirque_at`):
## heaped along its rim, scattered over its floor, and a talus under the
## head on the headwall.
##
## The whole cirque's blocks are placed at once from the land's seed (a
## jittered lattice in the massif's frame, kept or not by the zone it falls
## in and a cluster noise), then each cell (`cells`) takes the blocks that
## stand in it as one group. Kept off the landing strip and the lane it runs
## out through (PeakMassif STRIP, the rim's gap), the tarn and its shore
## (the bowl's lobed outline, `tn`), and the couloir's lift tube. Two blocks
## either lean on each other (a heap, one rock to the flight) or stand at
## least an opening apart (WorldScale.opening(TOY_GAP)), so no slot narrower
## than the plane stands between them.
##
## A block: buried foot, a squared body bulging a little, rounding in to a
## domed top; bare stone, the snow paint takes its tops.

const WorldScale = preload("res://scripts/world_scale.gd")
const PeakMassif = preload("res://scripts/endless/peak_massif.gd")
const PeakRoutes = preload("res://scripts/endless/peak_routes.gd")

## The lattice's step (m) and the box it covers in the massif's (a, v).
const STEP := 11.0
const BOX := Rect2(-280.0,-280.0,600.0,560.0)
## Each zone: [chance a lattice point holds a block, least and most radius
## (m), height over radius least and most].
## The rim (|s - 1| under RIM_BAND, off the head's side): heaped, the biggest.
const RIM_BAND := 0.2
const RIM := [0.5,2.2,6.0,0.7,1.15]
## The floor (s FLOOR_S.x..FLOOR_S.y): scattered, small.
const FLOOR_S := Vector2(0.4,0.82)
const FLOOR := [0.1,1.0,2.6,0.6,1.0]
## The headwall (the head's side past the strip, to HEADWALL_A): talus.
const HEADWALL_A := 250.0
const HEADWALL_V := 170.0
const TALUS := [0.28,1.4,4.2,0.6,1.1]
## Keep-offs: past the strip's half-width and ease (PeakMassif STRIP) by
## STRIP_PAD m either side of its line, all along it (its runout through the
## rim's gap); the tarn's bowl's outline times TARN_KEEP; the lift's tube
## plus an opening.
const STRIP_PAD := 14.0
const TARN_KEEP := 1.3
## The gap kept between two blocks that do not lean on each other (toy
## width, WorldScale.opening), and how far a block reaches past its radius
## (squared corners, lumps).
const TOY_GAP := 4.0
const WIDEST := 1.3
## The cluster noise's scale (m): blocks fall in heaps, not evenly.
const CLUSTER := 38.0
## The weathering (rock_build.gd): granite blocks, jointed, a few beds.
const LUMPS := 0.11
const GRAIN := 0.04
const LEDGES := 0.02
const FLUTES := 0.05
## --rock-start=boulders: this far out along the strip's line past its end,
## this high, flying in along it.
const START_BACK := 520.0
const START_ALT := 40.0

static var _cache := {}
static var _lock := Mutex.new()

## The cells (RockPlan.CELL) the cirque's box covers: {Vector2i: true}.
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
	for b: Array in blocks(field,peak):
		var q: Vector2 = b[0]
		if floori(q.x/cell) == cx and floori(q.y/cell) == cz: mine.append(b)
	if mine.is_empty(): return []
	return [_group(field,peak,mine,cx,cz)]

## Every block on the cirque: [[XZ, radius, height over its ground, zone]...]
## (zone 0 rim, 1 floor, 2 talus), the same for every cell (cached by seed).
static func blocks(field: RefCounted, peak: RefCounted) -> Array:
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

static func _place(field: RefCounted, peak: RefCounted) -> Array:
	var out: Array = []
	if peak.cirque_at(peak.centre.x,peak.centre.y).x == INF: return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),"peak boulders"])
	var noise := FastNoiseLite.new()
	noise.seed = int(hash([int(field.seed),"peak boulder heaps"]))
	noise.frequency = 1.0/CLUSTER
	var lift: Array = PeakRoutes.couloir(peak,Callable(field,"height")).points
	var strip_keep := PeakMassif.STRIP.z+PeakMassif.STRIP.w+STRIP_PAD
	var head_from := PeakMassif.STRIP.x+PeakMassif.STRIP.z+PeakMassif.STRIP.w+STRIP_PAD
	var gap := WorldScale.opening(TOY_GAP)
	var nx := int(BOX.size.x/STEP)
	var nz := int(BOX.size.y/STEP)
	for i in range(nx):
		for j in range(nz):
			var a := BOX.position.x+(i+rng.randf_range(0.1,0.9))*STEP
			var v := BOX.position.y+(j+rng.randf_range(0.1,0.9))*STEP
			var roll := rng.randf()
			var size := rng.randf()
			var tall := rng.randf()
			if absf(a-PeakMassif.STRIP.x) < strip_keep: continue
			var w: Vector2 = peak.world(a,v)
			var cq: Vector4 = peak.cirque_at(w.x,w.y)
			var s := cq.x
			if cq.y < TARN_KEEP: continue
			var rho := Vector2(a,v).length()
			var hd := smoothstep(0.25,0.75,a/maxf(rho,1.0))
			var zone := -1
			var z: Array = []
			if hd < 0.5 and absf(s-1.0) < RIM_BAND:
				zone = 0
				z = RIM
			elif hd > 0.5 and a > head_from and a < HEADWALL_A and absf(v) < HEADWALL_V:
				zone = 2
				z = TALUS
			elif s > FLOOR_S.x and s < FLOOR_S.y:
				zone = 1
				z = FLOOR
			if zone < 0: continue
			# Heaps: the chance swells and fades with the cluster noise; on the
			# rim most at its line.
			var heap := clampf(noise.get_noise_2d(a,v)*1.2+0.5,0.0,1.0)
			var chance := float(z[0])*lerpf(0.15,1.9,heap)
			if zone == 0: chance *= 1.0-absf(s-1.0)/RIM_BAND*0.6
			if roll > chance: continue
			var r := lerpf(float(z[1]),float(z[2]),size*size)*lerpf(0.8,1.15,heap)
			var up := r*lerpf(float(z[3]),float(z[4]),tall)
			var wr := r*WIDEST
			# Off the strip's flat (its ease included), whatever the lattice.
			if absf(a-PeakMassif.STRIP.x) < strip_keep+wr: continue
			if not _off_lift(w,wr,lift): continue
			# Lean on a neighbour or stand an opening off it.
			var ok := true
			for o: Array in out:
				var d := (o[0] as Vector2).distance_to(w)
				var ow := float(o[1])*WIDEST
				var g := d-wr-ow
				if g >= gap: continue
				if g > 0.0 or d < 0.7*maxf(r,float(o[1])):
					ok = false
					break
			if not ok: continue
			out.append([w,r,up,zone])
	return out

static func _off_lift(q: Vector2, w: float, lift: Array) -> bool:
	var keep := PeakRoutes.LIFT_R+w+WorldScale.opening(6.0)
	for i in range(lift.size()-1):
		var a: Vector3 = lift[i]
		var b: Vector3 = lift[i+1]
		if Geometry2D.get_closest_point_to_segment(q,Vector2(a.x,a.z),Vector2(b.x,b.z)).distance_to(q) < keep: return false
	return true

## Cell (cx, cz)'s blocks as one group, anchored at their middle.
static func _group(field: RefCounted, peak: RefCounted, mine: Array, cx: int, cz: int) -> Dictionary:
	var mid := Vector2.ZERO
	for b: Array in mine: mid += b[0]
	mid /= float(mine.size())
	var pos := Vector3(mid.x,float(field.height(mid.x,mid.y)),mid.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),cx,cz,"peak boulder shape"])
	var pillars: Array = []
	var reach := 0.0
	for b: Array in mine:
		var q: Vector2 = b[0]
		pillars.append(_block(field,pos,q,float(b[1]),float(b[2]),rng))
		reach = maxf(reach,q.distance_to(mid)+float(b[1])*WIDEST*1.3)
	var t: Dictionary = peak.tarn()
	var s0: Vector3 = t.strip[0]
	var s1: Vector3 = t.strip[1]
	var along := Vector2(s0.x-s1.x,s0.z-s1.z).normalized()
	var start := Vector2(s0.x,s0.z)+along*START_BACK
	var to := Vector2(s1.x,s1.z)-start
	return {"pos":pos,"reach":reach,"pillars":pillars,"foot":[],"by_arches":false,"bare":true,"on_peak":true,
		"approach":{"at":start,"heading":rad_to_deg(atan2(to.x,-to.y)),"alt":START_ALT},"form":"boulders"}

## One block at world XZ `q`, radius `r`, standing `up` m over its ground.
static func _block(field: RefCounted, pos: Vector3, q: Vector2, r: float, up: float, rng: RandomNumberGenerator) -> Dictionary:
	var low := INF
	var high := -INF
	for k in range(9):
		var d := Vector2.ZERO if k == 0 else Vector2.from_angle(TAU*k/8.0)*r
		var g := float(field.height(q.x+d.x,q.y+d.y))
		low = minf(low,g)
		high = maxf(high,g)
	var ground := float(field.height(q.x,q.y))
	# Its height over the ground's high side under it, so a block on a slope
	# still stands out of it.
	var tall := maxf(high-ground,0.0)+up
	var aspect := rng.randf_range(1.0,1.5)
	var ax := sqrt(aspect)
	var profile: Array = []
	var ring := func(y: float, k: float) -> void:
		if not profile.is_empty() and y < float(profile.back()[0])+0.3: return
		profile.append([y,r*k*ax,r*k/ax,0.0,0.0])
	var bulge := rng.randf_range(1.0,1.12)
	ring.call(low-ground-1.5,0.85)
	ring.call(maxf(high-ground,0.0)-up*0.3,0.95)
	ring.call(tall-up*0.55,bulge)
	ring.call(tall-up*0.2,bulge*0.86)
	ring.call(tall,bulge*0.55)
	# A tilt, as a fallen block sits.
	var lean := Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.0,0.25)*r
	for c: Array in profile:
		var u := clampf(float(c[0])/maxf(tall,0.1),0.0,1.0)
		c[3] = lean.x*u
		c[4] = lean.y*u
	return {"at":Vector3(q.x-pos.x,ground-pos.y,q.y-pos.z),"profile":profile,"yaw":rng.randf()*TAU,"dome":r*rng.randf_range(0.15,0.4),
		"square":rng.randf_range(0.55,0.8),"lump":clampf(r*0.7,1.0,4.0),"lumps":LUMPS,"grain":GRAIN,"ledges":LEDGES,"flutes":FLUTES,
		"bed":rng.randf_range(1.5,3.0),"ring_every":clampf(tall/6.0,0.5,1.5),"segments":12 if r < 3.0 else 16,"seed":rng.randi()}
