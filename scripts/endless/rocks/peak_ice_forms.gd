extends "res://scripts/endless/rocks/rock_kind.gd"
## Standing ice on the Peak's glacier (a rock kind, scripts/endless/rocks/
## rock_plan.gd; spec docs/design/endless-flight/spec-icefield.md, lane forms):
## things to thread low and fast from the toe to the mouth, hand-sited on the
## glacier's line (PeakIce TONGUE, the massif's a, v), each stood on the field's
## height as it is at build time (whatever the carve leaves under it).
##
##   ranks    seracs across the flow (RANKS), towers leaning on each other with
##            lanes between them: one on the line RANK_LANE wide, the others
##            SIDE_LANE (toy widths, WorldScale.opening)
##   fins     tall thin blades along the flow (FINS), either side of the line
##            in turn, FIN_LANE apart: a slalom down the line or a weave round
##   arches   a bridge of ice between two towers over the line (ARCHES),
##            ARCH_LANE wide and ARCH_UNDER m clear under it; the towers and
##            each slab of the bridge are pillars of their own, so the flight's
##            solid is columns and a roof, never a filled opening
##   blocks   tumbled blocks along the lateral moraines' feet
##
## Nothing in the toe's first stretch (a over TOE_KEEP: the landing). A lane
## stays open along the line (`kept`, LANE half-width): a piece meeting it is
## left out, and so is one whose foot spans more fall than FOOT_FALL (a slot's
## lip). The towers are peak_serac.gd's; the rest are its shards and blocks.
##
## Handles for the finds: `sites(peak)` gives each rank's and arch's spot
## ({name: {at: Vector3(a, v, y over the sea) or world, ...}}, see there).
##
## --ice-forms=0 (rock_plan's own flag for the kind) stands none; --peak-ice=0
## neither.

const WorldScale = preload("res://scripts/world_scale.gd")
const PeakIce = preload("res://scripts/endless/peak_ice.gd")
const Serac = preload("res://scripts/endless/rocks/peak_serac.gd")

## The box (the massif's a, v) that holds them.
const BOX := Rect2(2150.0,-420.0,720.0,920.0)
## No piece further down the glacier than this (a): the toe's landing.
const TOE_KEEP := 2850.0
## The ranks: the a of each one's middle on the line, how far its middle bows
## down the flow (m).
const RANKS := [2790.0,2505.0,2240.0]
const RANK_BOW := 12.0
## The ranks' lanes (toy widths): on the line, and the others, about SIDE_EVERY
## m apart across.
const RANK_LANE := 8.0
const SIDE_LANE := 5.0
const SIDE_EVERY := Vector2(38.0,58.0)
## The ranks stop this far inside the ice's edge (m).
const RANK_EDGE := 14.0
## The fin runs: from a, to a; a fin every FIN_STEP m, FIN_LANE (toy) between
## the two sides.
const FINS := [Vector2(2745.0,2595.0),Vector2(2455.0,2315.0)]
const FIN_STEP := Vector2(28.0,36.0)
const FIN_LANE := 7.0
## A fin's half sizes (m): across, along, and its height over its ground.
const FIN_THICK := Vector2(1.6,2.4)
const FIN_LONG := Vector2(9.0,14.0)
const FIN_TALL := Vector2(15.0,26.0)
## Shards the lower blade breaks into along the flow.
const FIN_SPLIT := Vector2i(2,3)
## The arches: the a of each on the line, the opening (toy) and the room under
## the bridge over the highest ground across it (m).
const ARCHES := [2560.0,2290.0]
const ARCH_LANE := 8.0
const ARCH_UNDER := 18.0
## A leg's reach from its middle (m) and the bridge's thickness (m) and depth
## along the flow (m).
const LEG_REACH := 6.5
const BRIDGE_THICK := Vector2(7.0,9.0)
const BRIDGE_DEEP := Vector2(10.0,13.0)
const SLABS := 5
## The tumbled blocks: from a, to a, a heap every BLOCK_STEP m each side, in a
## band this far inside the floor's edge (m), where the moraine's bank rises.
const BLOCKS := Vector2(2840.0,2195.0)
const BLOCK_STEP := Vector2(26.0,44.0)
const BLOCK_BAND := Vector2(12.0,38.0)
## The lane kept open along the line (half-width, m).
const LANE := 7.0
## A piece's foot may not span more than this much of the ground's fall per m
## of its reach.
const FOOT_FALL := 0.8
## --rock-start=ice-forms: from this far along (a), this high over the ice.
const START_A := 2900.0
const START_ALT := 22.0

static var _cache := {}
static var _lock := Mutex.new()

# --- The line ---------------------------------------------------------------

## The glacier's line (v) at `a`: PeakIce TONGUE's middle.
static func line_v(a: float) -> float:
	var t: Array = PeakIce.TONGUE
	if a <= float(t[0][0]): return float(t[0][1])
	for i in range(t.size()-1):
		var a1 := float(t[i+1][0])
		if a <= a1:
			var a0 := float(t[i][0])
			return lerpf(float(t[i][1]),float(t[i+1][1]),(a-a0)/(a1-a0))
	return float(t[t.size()-1][1])

## The ice's half-width at `a` (TONGUE's).
static func ice_half(a: float) -> float:
	var t: Array = PeakIce.TONGUE
	for i in range(t.size()-1):
		var a1 := float(t[i+1][0])
		if a <= a1:
			var a0 := float(t[i][0])
			return lerpf(float(t[i][2]),float(t[i+1][2]),clampf((a-a0)/(a1-a0),0.0,1.0))
	return float(t[t.size()-1][2])

## The line's way down the flow at `a`, in (a, v), unit.
static func line_way(a: float) -> Vector2:
	return Vector2(10.0,line_v(a+5.0)-line_v(a-5.0)).normalized()

## A spot `s` m across the line (positive toward +v) and `d` m down the flow
## from the line's point at `a`, in (a, v).
static func off_line(a: float, s: float, d := 0.0) -> Vector2:
	var t := line_way(a)
	return Vector2(a,line_v(a))+Vector2(-t.y,t.x)*s+t*d

## The lane's points, the toe first: [Vector3(a, v, half)...].
static func kept() -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := TOE_KEEP+60.0
	while a > BOX.position.x-40.0:
		out.append(Vector3(a,line_v(a),LANE))
		a -= 20.0
	return out

## The line in world XZ, every `step` m, the toe first (for drivers and the
## start).
static func line(peak: RefCounted, step := 20.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var a := TOE_KEEP+150.0
	while a > BOX.position.x:
		out.append(peak.world(a,line_v(a)))
		a -= step
	return out

## The finds' handles: {"rank/<i>": {...}, "arch/<i>": {...}}, each with `a`, `v`
## (the massif's frame, on the line), `world` (XZ), `y` (the ice under it, over
## the sea), `lane` (m wide); an arch's `under` (the bridge's underside, over the
## sea). The same spots the pieces stand round.
static func sites(field: RefCounted, peak: RefCounted) -> Dictionary:
	var out := {}
	for i in RANKS.size():
		var a: float = float(RANKS[i])+RANK_BOW
		var w: Vector2 = peak.world(a,line_v(a))
		out["rank/%d" % i] = {"a":a,"v":line_v(a),"world":w,"y":float(field.height(w.x,w.y)),"lane":WorldScale.opening(RANK_LANE)}
	for i in ARCHES.size():
		var a: float = ARCHES[i]
		var w: Vector2 = peak.world(a,line_v(a))
		var under := _under(field,peak,a)
		out["arch/%d" % i] = {"a":a,"v":line_v(a),"world":w,"y":float(field.height(w.x,w.y)),"lane":WorldScale.opening(ARCH_LANE),"under":under}
	return out

# --- The plan ---------------------------------------------------------------

## The cells (RockPlan.CELL) the box covers: {Vector2i: true}.
static func cells(peak: RefCounted) -> Dictionary:
	var out := {}
	if peak == null: return out
	var cell: float = preload("res://scripts/endless/rocks/rock_plan.gd").CELL
	var lo := Vector2(INF,INF)
	var hi := -lo
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
	if peak == null or peak.shaped() or not cells(peak).has(Vector2i(cx,cz)): return []
	var cell: float = preload("res://scripts/endless/rocks/rock_plan.gd").CELL
	var mine: Array = []
	for u: Dictionary in units(field,peak):
		var h: Vector2 = u.home
		if floori(h.x/cell) == cx and floori(h.y/cell) == cz: mine.append(u)
	if mine.is_empty(): return []
	return [_group(field,peak,mine,cx,cz)]

## Every unit (a tower, a fin, an arch, a heap of blocks): {home (world XZ, the
## cell it is built in), form, parts: [part...]}, the same for every cell
## (cached by seed). A part is {t (serac, fin, leg, slab, heap), q (world XZ),
## flow (world XZ unit), ...its sizes}.
static func units(field: RefCounted, peak: RefCounted) -> Array:
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
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),"peak ice forms"])
	var lane := kept()
	# (The roomy pieces first, so a heap never takes a lane's wall.)
	for i in ARCHES.size(): _arch(out,field,peak,float(ARCHES[i]),i,rng)
	for i in RANKS.size(): _rank(out,field,peak,lane,float(RANKS[i]),i,rng)
	for i in FINS.size(): _fins(out,field,peak,lane,FINS[i],i,rng)
	_blocks(out,field,peak,lane,rng)
	return out

## A way in the massif's frame as a world XZ direction.
static func _world_way(peak: RefCounted, way: Vector2) -> Vector2:
	return (peak.world(way.x,way.y)-peak.world(0.0,0.0)).normalized()

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

## The ground's low and high round world XZ `w` within `r` m (eight points and
## the middle).
static func _span(field: RefCounted, w: Vector2, r: float, flow := Vector2.ZERO, long := 1.0) -> Vector2:
	var across := Vector2(-flow.y,flow.x)
	var low := INF
	var high := -INF
	for k in 9:
		var ang := TAU*k/8.0
		var d := Vector2.ZERO
		if k > 0: d = Vector2.from_angle(ang)*r if flow == Vector2.ZERO else flow*cos(ang)*r+across*sin(ang)*r*long
		var g := float(field.height(w.x+d.x,w.y+d.y))
		low = minf(low,g)
		high = maxf(high,g)
	return Vector2(low,high)

## Whether a footprint `r` m round (along the flow; `long` times it across)
## stands on ground even enough.
static func _even(field: RefCounted, w: Vector2, r: float, flow: Vector2, long := 1.0) -> bool:
	var g := _span(field,w,r,flow,long)
	return g.y-g.x <= FOOT_FALL*r*2.0

## Whether `w` (world XZ) reaching `reach` m keeps clear of every part in `out`
## by `gap` m (their reaches).
static func _clear(out: Array, w: Vector2, reach: float, gap: float, mine := "") -> bool:
	for u: Dictionary in out:
		if mine != "" and String(u.name) == mine: continue
		for p: Dictionary in u.parts:
			if (p.q as Vector2).distance_to(w)-reach-float(p.reach) < gap: return false
	return true

## The bridge's underside (over the sea) for an arch at `a`: ARCH_UNDER over
## the highest ground across its opening.
static func _under(field: RefCounted, peak: RefCounted, a: float) -> float:
	var half := WorldScale.opening(ARCH_LANE)*0.5+LEG_REACH
	var high := -INF
	for k in 9:
		for d: float in [-BRIDGE_DEEP.y*0.5,0.0,BRIDGE_DEEP.y*0.5]:
			var w: Vector2 = peak.world(off_line(a,lerpf(-half,half,k/8.0),d).x,off_line(a,lerpf(-half,half,k/8.0),d).y)
			high = maxf(high,float(field.height(w.x,w.y)))
	return high+ARCH_UNDER

## An arch at `a` on the line: two legs either side of the opening and a bridge
## of three slabs across their tops. Moved up or down the flow (a few tries) if
## a leg would stand on a slot's lip.
static func _arch(out: Array, field: RefCounted, peak: RefCounted, a0: float, i: int, rng: RandomNumberGenerator) -> void:
	var lane := WorldScale.opening(ARCH_LANE)
	var off := lane*0.5+LEG_REACH
	for tryk in 5:
		var a: float = a0+float([0.0,12.0,-12.0,24.0,-24.0][tryk])
		var t := line_way(a)
		var flow := _world_way(peak,t)
		var legs: Array = []
		var ok := true
		for sg: float in [-1.0,1.0]:
			var p := off_line(a,sg*off)
			var w: Vector2 = peak.world(p.x,p.y)
			if not _even(field,w,LEG_REACH,flow): ok = false
			legs.append(w)
		if not ok: continue
		var under := _under(field,peak,a)
		var thick := rng.randf_range(BRIDGE_THICK.x,BRIDGE_THICK.y)
		var deep := rng.randf_range(BRIDGE_DEEP.x,BRIDGE_DEEP.y)
		var parts: Array = []
		for k in 2:
			parts.append({"t":"leg","q":legs[k],"flow":flow,"reach":LEG_REACH,"top":under+thick+rng.randf_range(4.0,11.0),"seed":rng.randi()})
		# The bridge: SLABS slabs leg to leg, thicker at the ends (wedged between
		# the towers) and sagging over the middle, each knocked askew.
		var span: float = (legs[0] as Vector2).distance_to(legs[1])
		for k in SLABS:
			var u := (k+0.5)/SLABS
			var s := lerpf(-off,off,u)
			var p := off_line(a,s,rng.randf_range(-1.5,1.5))
			var end := absf(u-0.5)*2.0
			parts.append({"t":"slab","q":peak.world(p.x,p.y),"flow":flow,"reach":span/(SLABS*2.0)+2.5,
				"half":Vector3(span/(SLABS*2.0)+1.4,thick*0.5*lerpf(0.8,1.5,end*end),deep*0.5*rng.randf_range(0.8,1.1)),"under":under,"seed":rng.randi()})
		var home: Vector2 = peak.world(a,line_v(a))
		out.append({"home":home,"form":"arch","name":"arch/%d" % i,"parts":parts})
		return

## A rank across the flow at `a0` on the line: towers leaning on each other
## between the lanes, bowed down the flow in the middle.
static func _rank(out: Array, field: RefCounted, peak: RefCounted, lane: PackedVector3Array, a0: float, i: int, rng: RandomNumberGenerator) -> void:
	var wide := ice_half(a0)-RANK_EDGE
	var mid_lane := WorldScale.opening(RANK_LANE)
	var side_lane := WorldScale.opening(SIDE_LANE)
	# The lanes across (centres, widths), the line's in the middle.
	var lanes: Array = [[0.0,mid_lane]]
	for sg: float in [-1.0,1.0]:
		var s := mid_lane*0.5
		while true:
			s += rng.randf_range(SIDE_EVERY.x,SIDE_EVERY.y)
			if s+side_lane > wide-10.0: break
			lanes.append([sg*(s+side_lane*0.5),side_lane])
			s += side_lane
	lanes.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var edges: Array = [[-wide,-wide]]
	for l: Array in lanes: edges.append([float(l[0])-float(l[1])*0.5,float(l[0])+float(l[1])*0.5])
	edges.append([wide,wide])
	var t := line_way(a0)
	var flow := _world_way(peak,t)
	for k in edges.size()-1:
		var s0 := float(edges[k][1])
		var s1 := float(edges[k+1][0])
		_wall(out,field,peak,lane,a0,s0,s1,wide,flow,i,rng)

## Towers from `s0` to `s1` across the line at `a0`, leaning on each other, the
## first and last flush with the lanes' edges.
static func _wall(out: Array, field: RefCounted, peak: RefCounted, lane: PackedVector3Array, a0: float, s0: float, s1: float, wide: float, flow: Vector2, i: int, rng: RandomNumberGenerator) -> void:
	var len := s1-s0
	if len < 6.0: return
	var long := rng.randf_range(1.05,1.3)
	# Taller toward the line and toward the lanes' edges.
	var w := minf(rng.randf_range(7.0,12.0),len*0.5)
	var n := 1 if len <= 2.0*w else ceili((len-2.0*w)/(1.1*w))+1
	var step := 0.0 if n == 1 else (len-2.0*w)/(n-1)
	for k in n:
		var s := s0+w+step*k if n > 1 else (s0+s1)*0.5
		var wk := w if (k == 0 or k == n-1) else w*rng.randf_range(0.85,1.0)
		var r := wk/(Serac.WIDEST*long)
		var near := 1.0-clampf(absf(s)/wide,0.0,1.0)
		var up := lerpf(rng.randf_range(9.0,16.0),rng.randf_range(16.0,28.0),near)
		var u := s/maxf(wide,1.0)
		var p := off_line(a0,s,RANK_BOW*(1.0-u*u)+rng.randf_range(-3.0,3.0))
		var q: Vector2 = peak.world(p.x,p.y)
		if off_lane(p.x,p.y,lane) < wk: continue
		if not _even(field,q,r*Serac.WIDEST,flow,long): continue
		if not _clear(out,q,r*Serac.WIDEST,0.0,"rank/%d" % i): continue
		out.append({"home":q,"form":"rank","name":"rank/%d" % i,"parts":[{"t":"serac","q":q,"flow":flow,"reach":wk,"r":r,"up":up,"long":long,"seed":rng.randi()}]})

## A run of fins from `run.x` to `run.y` (a): either side of the line in turn,
## FIN_LANE between the sides' inner faces.
static func _fins(out: Array, field: RefCounted, peak: RefCounted, lane: PackedVector3Array, run: Vector2, i: int, rng: RandomNumberGenerator) -> void:
	var a := run.x
	var sg := 1.0 if rng.randf() < 0.5 else -1.0
	var gap := WorldScale.opening(FIN_LANE)
	while a > run.y:
		var thick := rng.randf_range(FIN_THICK.x,FIN_THICK.y)
		var long := rng.randf_range(FIN_LONG.x,FIN_LONG.y)
		var yaw := rng.randf_range(-0.14,0.14)
		# Its reach across: the blade turned off the flow.
		var across := thick+long*absf(sin(yaw))+0.8
		var s := sg*(gap*0.5+across)
		var p := off_line(a,s)
		var q: Vector2 = peak.world(p.x,p.y)
		var t := line_way(a)
		var flow := _world_way(peak,t)
		var reach := sqrt(across*across+long*long)
		if off_lane(p.x,p.y,lane) >= across-0.5 and _even(field,q,long,flow,across/long) and _clear(out,q,reach,1.0):
			out.append({"home":q,"form":"fin","name":"fin/%d" % i,"parts":[{"t":"fin","q":q,"flow":flow,"reach":reach,
				"thick":thick,"long":long,"across":across,"yaw":yaw,"tall":rng.randf_range(FIN_TALL.x,FIN_TALL.y),"side":sg,"seed":rng.randi()}]})
		sg = -sg
		a -= rng.randf_range(FIN_STEP.x,FIN_STEP.y)

## Heaps of tumbled blocks along both moraines' feet.
static func _blocks(out: Array, field: RefCounted, peak: RefCounted, lane: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	var t0 := preload("res://scripts/endless/peak_massif.gd")
	for sg: float in [-1.0,1.0]:
		var a := BLOCKS.x-rng.randf_range(0.0,BLOCK_STEP.x)
		while a > BLOCKS.y:
			var mid: float = t0._valley_mid(a)
			var g: float = clampf((a-t0.GLACIER.x)/(t0.GLACIER.y-t0.GLACIER.x),0.0,1.0)
			var half: float = lerpf(t0.FLOOR_HALF.z,t0.FLOOR_HALF.w,g)
			var v := mid+sg*(half-rng.randf_range(BLOCK_BAND.x,BLOCK_BAND.y))
			var q: Vector2 = peak.world(a,v)
			var size := rng.randf_range(2.0,4.5)
			var reach := size*2.4
			var here := a
			a -= rng.randf_range(BLOCK_STEP.x,BLOCK_STEP.y)
			if off_lane(here,v,lane) < reach+20.0: continue
			if not _clear(out,q,reach,2.0): continue
			out.append({"home":q,"form":"blocks","name":"blocks","parts":[{"t":"heap","q":q,"flow":Vector2.UP,"reach":reach,"size":size,"seed":rng.randi()}]})

# --- The shapes -------------------------------------------------------------

## Cell (cx, cz)'s units as one group, anchored at their middle.
static func _group(field: RefCounted, peak: RefCounted, mine: Array, _cx: int, _cz: int) -> Dictionary:
	var mid := Vector2.ZERO
	var n := 0
	for u: Dictionary in mine:
		for p: Dictionary in u.parts:
			mid += p.q
			n += 1
	mid /= float(n)
	var pos := Vector3(mid.x,float(field.height(mid.x,mid.y)),mid.y)
	var pillars: Array = []
	var reach := 0.0
	for u: Dictionary in mine:
		for p: Dictionary in u.parts:
			var rng := RandomNumberGenerator.new()
			rng.seed = int(p.seed)
			var q: Vector2 = p.q
			match String(p.t):
				"serac": pillars.append(Serac.pillar(field,pos,q,float(p.r),float(p.up),float(p.long),p.flow,rng))
				"fin": pillars.append(_fin(field,pos,p,rng))
				"leg": pillars.append(_leg(field,pos,p,rng))
				"slab": pillars.append(_slab(field,pos,p,rng))
				"heap": pillars.append(_heap(field,pos,p,rng))
			reach = maxf(reach,q.distance_to(mid)+float(p.reach)*1.3)
	var s0 := peak.world(START_A,line_v(START_A)) as Vector2
	var s1 := peak.world(START_A-40.0,line_v(START_A-40.0)) as Vector2
	var to := s1-s0
	return {"pos":pos,"reach":reach,"pillars":pillars,"foot":[],"by_arches":false,"bare":true,"on_peak":true,
		"approach":{"at":s0,"heading":rad_to_deg(atan2(to.x,-to.y)),"alt":START_ALT},"form":"ice forms","mesher":Serac,"ice":true}

## Blocks built in a frame of x across the flow, z down it, turned into the
## group's (world axes) at `flow`.
static func _turn(blocks: Array, flow: Vector2) -> void:
	var f3 := Vector3(flow.x,0.0,flow.y)
	var s3 := Vector3(-flow.y,0.0,flow.x)
	for b: Dictionary in blocks:
		var polys: Array = b.polys
		for i in polys.size():
			var f: PackedVector3Array = polys[i]
			for j in f.size():
				var p := f[j]
				f[j] = s3*p.x+Vector3.UP*p.y+f3*p.z
			polys[i] = f

## Blocks squeezed (x, z about the axis) to reach at most `rx` across and `rz`
## along.
static func _fit(blocks: Array, rx: float, rz: float) -> void:
	var mx := 0.0
	var mz := 0.0
	for b: Dictionary in blocks:
		for f: PackedVector3Array in b.polys:
			for p: Vector3 in f:
				mx = maxf(mx,absf(p.x))
				mz = maxf(mz,absf(p.z))
	var kx := minf(1.0,rx/maxf(mx,0.01))
	var kz := minf(1.0,rz/maxf(mz,0.01))
	for b: Dictionary in blocks:
		var polys: Array = b.polys
		for i in polys.size():
			var f: PackedVector3Array = polys[i]
			for j in f.size(): f[j] = Vector3(f[j].x*kx,f[j].y,f[j].z*kz)
			polys[i] = f

## The pillar dictionary peak_serac.gd builds from.
static func _pillar(pos: Vector3, q: Vector2, ground: float, blocks: Array, r: float, foot: float, tall: float) -> Dictionary:
	return {"at":Vector3(q.x-pos.x,ground-pos.y,q.y-pos.z),"blocks":blocks,"r":r,"foot":foot,"tall":tall}

## A fin: a tall blade along the flow, broken across its top, a lesser shard
## leant on its outer face, a block or two at its foot.
static func _fin(field: RefCounted, pos: Vector3, p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var q: Vector2 = p.q
	var flow: Vector2 = p.flow
	var long := float(p.long)
	var thick := float(p.thick)
	var g := _span(field,q,long,flow,thick/long)
	var ground := float(field.height(q.x,q.y))
	var foot := g.x-ground-2.0
	var tall := maxf(g.y-ground,0.0)+float(p.tall)
	var tone := rng.randf_range(0.35,0.7)
	var blocks: Array = []
	# The blade: two shards, the upper knocked askew on the lower and shorter
	# along, so its top is ragged, not a slab's.
	var turn := Basis(Vector3.UP,float(p.yaw))*Basis(Vector3.BACK,rng.randf_range(-0.06,0.06))
	var cut := foot+(tall-foot)*rng.randf_range(0.5,0.66)
	var ly := (cut-foot)*0.56
	# The lower blade split along the flow into FIN_SPLIT shards of their own
	# heights and leans, so its side is a broken ridge, not one slab's face.
	# Each its own height (one at the cut's), so the skyline is serrated.
	var n := rng.randi_range(FIN_SPLIT.x,FIN_SPLIT.y)
	var hi := rng.randi_range(0,n-1)
	var top_z := 0.0
	var top_y := 0.0
	var zs: Array[float] = []
	for k in n:
		var zk := lerpf(-0.55,0.55,(k+0.5)/n)*long+rng.randf_range(-0.08,0.08)*long
		var lk := long*rng.randf_range(0.42,0.6)*(3.0/n)
		var yk := (cut-foot)*0.5*(1.0 if k == hi else rng.randf_range(0.4,0.8))
		var tk := Basis(Vector3.UP,float(p.yaw)+rng.randf_range(-0.1,0.1))*Basis(Vector3.BACK,rng.randf_range(-0.08,0.08))*Basis(Vector3.RIGHT,rng.randf_range(-0.07,0.07))
		blocks.append(Serac._shard(rng,Vector3(thick*rng.randf_range(0.8,1.05),yk,lk),Vector3(0.0,foot+yk,zk),tk,clampf(tone+rng.randf_range(-0.1,0.1),0.0,1.0),2))
		zs.append(zk)
		if yk > top_y:
			top_y = yk
			top_z = zk
	var uy := (tall-cut)*0.64
	var askew := Basis(Vector3.UP,rng.randf_range(-0.12,0.12))*turn*Basis(Vector3.BACK,rng.randf_range(-0.1,0.1))
	blocks.append(Serac._shard(rng,Vector3(thick*rng.randf_range(0.75,0.95),uy,long*rng.randf_range(0.35,0.55)),
		Vector3(0.0,tall-uy,top_z),askew,clampf(tone+rng.randf_range(-0.12,0.12),0.0,1.0),2))
	# A lesser spire on another shard, half as far over the cut: two points.
	var z2: float = zs[(zs.find(top_z)+1)%zs.size()]
	var u2 := uy*rng.randf_range(0.45,0.6)
	var lean2 := Basis(Vector3.UP,rng.randf_range(-0.15,0.15))*turn*Basis(Vector3.BACK,rng.randf_range(-0.14,0.14))*Basis(Vector3.RIGHT,signf(z2-top_z)*rng.randf_range(0.04,0.12))
	blocks.append(Serac._shard(rng,Vector3(thick*rng.randf_range(0.7,0.9),u2,long*rng.randf_range(0.25,0.4)),
		Vector3(0.0,cut+u2*0.6,z2),lean2,clampf(tone+rng.randf_range(-0.12,0.12),0.0,1.0),2))
	var hy := (tall-foot)*0.5
	# The lesser shard on the side away from the line.
	var out_s := float(p.side)
	var sy := hy*rng.randf_range(0.45,0.7)
	var lean := Basis(Vector3.UP,float(p.yaw)+rng.randf_range(-0.2,0.2))*Basis(Vector3.BACK,-out_s*rng.randf_range(0.05,0.16))
	blocks.append(Serac._shard(rng,Vector3(thick*rng.randf_range(0.9,1.3),sy,long*rng.randf_range(0.45,0.7)),
		Vector3(out_s*thick*1.1,foot+sy,rng.randf_range(-0.3,0.3)*long),lean,clampf(tone+rng.randf_range(-0.12,0.12),0.0,1.0),1))
	for k in rng.randi_range(1,2):
		var sz := thick*rng.randf_range(0.6,1.0)
		var half := Vector3(sz,sz*rng.randf_range(0.6,1.0),sz*rng.randf_range(0.8,1.4))
		var at := Vector3(out_s*(thick+sz*0.6),half.y*0.3,rng.randf_range(-0.8,0.8)*long)
		blocks.append(Serac._block(rng,half,at,Serac._tilt(rng,0.3,0.9),3,clampf(tone+rng.randf_range(-0.2,0.2),0.0,1.0),1))
	# Its inner face (toward the line) kept at its reach: the lane holds.
	_fit_side(blocks,float(p.across),long*1.1,out_s)
	_turn(blocks,flow)
	return _pillar(pos,q,ground,blocks,thick*2.0,foot,tall)

## Blocks squeezed so nothing reaches past `inner` m toward the line (the side
## opposite `out_s`) nor past `rz` along.
static func _fit_side(blocks: Array, inner: float, rz: float, out_s: float) -> void:
	var mi := 0.0
	var mz := 0.0
	for b: Dictionary in blocks:
		for f: PackedVector3Array in b.polys:
			for p: Vector3 in f:
				mi = maxf(mi,-p.x*out_s)
				mz = maxf(mz,absf(p.z))
	var ki := minf(1.0,inner/maxf(mi,0.01))
	var kz := minf(1.0,rz/maxf(mz,0.01))
	for b: Dictionary in blocks:
		var polys: Array = b.polys
		for i in polys.size():
			var f: PackedVector3Array = polys[i]
			for j in f.size():
				var x := f[j].x
				if -x*out_s > 0.0: x *= ki
				f[j] = Vector3(x,f[j].y,f[j].z*kz)
			polys[i] = f

## An arch's leg: a serac tower up to the
## bridge's top and a little over, within LEG_REACH of its middle.
static func _leg(field: RefCounted, pos: Vector3, p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var q: Vector2 = p.q
	var r := float(p.reach)
	var g := _span(field,q,r)
	var ground := float(field.height(q.x,q.y))
	var foot := g.x-ground-2.0
	var tall := float(p.top)-ground
	# A serac tower (peak_serac.gd's: shards, a hood, slabs, tumbled blocks),
	# squeezed into its reach.
	var blocks: Array = Serac._tower(rng,r*0.9,r*0.8,tall,foot)
	_fit(blocks,r,r)
	_turn(blocks,p.flow)
	return _pillar(pos,q,ground,blocks,r,foot,tall)

## A slab of the bridge: a chopped block across the opening, its underside at
## `under` (over the sea) or higher.
static func _slab(field: RefCounted, pos: Vector3, p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var q: Vector2 = p.q
	var ground := float(field.height(q.x,q.y))
	var half: Vector3 = p.half
	var tilt := Basis(Vector3.BACK,rng.randf_range(-0.12,0.12))*Basis(Vector3.RIGHT,rng.randf_range(-0.1,0.1))*Basis(Vector3.UP,rng.randf_range(-0.22,0.22))
	var tone := rng.randf_range(0.4,0.7)
	var b := Serac._shard(rng,half,Vector3.ZERO,tilt,tone,2)
	# Lifted so its lowest corner is the underside.
	var lo := INF
	for f: PackedVector3Array in b.polys:
		for v: Vector3 in f: lo = minf(lo,v.y)
	var lift := float(p.under)-ground-lo
	var polys: Array = b.polys
	for i in polys.size():
		var f: PackedVector3Array = polys[i]
		for j in f.size(): f[j] += Vector3(0.0,lift,0.0)
		polys[i] = f
	var blocks := [b]
	_turn(blocks,p.flow)
	var top := float(p.under)-ground+half.y*2.0
	# (Its belly half open, so with the overhang's shade it reads blue; its
	# back open.)
	return _pillar(pos,q,ground,blocks,half.z,float(p.under)-ground-top*0.25,top)

## A heap of tumbled blocks, half sunk, tilted hard.
static func _heap(field: RefCounted, pos: Vector3, p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var q: Vector2 = p.q
	var ground := float(field.height(q.x,q.y))
	var size := float(p.size)
	var tone := rng.randf_range(0.3,0.65)
	var blocks: Array = []
	var ang := rng.randf()*TAU
	for k in rng.randi_range(2,5):
		var sz := size*(1.0 if k == 0 else rng.randf_range(0.35,0.7))
		var half := Vector3(sz*rng.randf_range(0.8,1.4),sz*rng.randf_range(0.55,1.0),sz*rng.randf_range(0.8,1.3))
		var d := 0.0 if k == 0 else size*rng.randf_range(0.9,1.5)
		ang += rng.randf_range(1.2,2.4)
		var at := Vector3(cos(ang)*d,0.0,sin(ang)*d)
		at.y = float(field.height(q.x+at.x,q.y+at.z))-ground+half.y*0.25
		blocks.append(Serac._block(rng,half,at,Serac._tilt(rng,0.3,1.0),3,clampf(tone+rng.randf_range(-0.15,0.15),0.0,1.0),2 if k == 0 else 1))
	return _pillar(pos,q,ground,blocks,size,-size,size*2.0)
