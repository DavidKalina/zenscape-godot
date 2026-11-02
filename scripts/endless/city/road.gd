extends RefCounted
## The giants' city's road (giant_city.gd has the contract; the spec's "road kit"):
## a paved colonnade way that bends over the land, its height taken from the land.
## It runs 3.66 km from the gate's far side, round the lake's east shore, across the
## head of a bay to the pyramid's stair. BENDS is its centre line. Its first 720 m
## stand, and PLAN is their bays, in acts as the pillared hall's are, so a run keeps
## changing: `OPEN` columns and a beam under the sky, `ROOFED` low cover on ribs
## with a nave, two aisles and bays out of the side at every step, and `BROKEN`
## where age has been at it. Past that age wins: ROW_L and ROW_R say what's left at
## each station, WRECK what fell, PAVE how much street is left, and the wreck is
## baked into a block per two bays, so 3 km of it costs few instances.
##
## A LANDED piece: `build` gets the land (`land(x, z)` in the piece's frame) and
## its heights are the world's, so it isn't seated on the land's mean. The road's
## frame is (s along the centre line, u to the left of the way it flies); nothing
## in it is stamped twice at the same yaw by design, but blocks are shared by size,
## so a bend costs instances, not meshes.
##
## Two lines through, in LINES (s, u, h over the paving): `wide` down the middle,
## `tight` weaving the left row and the aisle's columns. Out through any side bay,
## and over the top where there's no roof, is open as well.

const Shapes = preload("res://scripts/endless/city/city_shapes.gd")
const Colonnade = preload("res://scripts/endless/city/colonnade.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const DEEP := 60.0

## REACH is a ring about the row's spot, not the road's length: the road runs on
## out of it. The stomper keeps off the whole road by where his line is laid
## (stomper_route.gd).
const REACH := 350.0
const LANDED := true
## Where the centre line starts, against the gate's back wall, in this piece's
## frame: the gate's z 36, heading out of its door.
const FROM := Vector2(97.8,-449.2)
const FROM_YAW := -1.4
## The centre line: Vector2(length, radians to the left).
const BENDS: Array[Vector2] = [Vector2(50.0,0.0),Vector2(300.0,2.22),Vector2(150.0,-1.14),Vector2(170.0,1.32),Vector2(60.0,0.0),
	# The swing to the shore, the reveal: the pyramid across the water.
	Vector2(420.0,-2.34),Vector2(160.0,0.0),
	# North up the shore, winding.
	Vector2(220.0,0.35),Vector2(260.0,-0.75),Vector2(280.0,0.5),Vector2(260.0,-0.45),Vector2(180.0,0.45),Vector2(396.0,-0.662),
	# Out over the bay's head, then hard round onto the stair's line.
	Vector2(548.0,-1.23),Vector2(152.0,1.832),Vector2(60.0,0.0)]
## How long a bend takes to come on and go off (m).
const EASE := 60.0
const STEP := 4.0
## The cross-section: half the street to the row's centres, the stylobate past it,
## the aisle columns' u.
const HALF := 40.0
const PITCH := 60.0
const INNER_SHARE := 0.45
const CURB := 8.0
const KERB := 1.6
## The paving is cut this long, so the land's rise is taken in low steps.
const SLAB := 30.0
const OVER_LAND := 0.8
## How far the land may stand over the paving before the road is lifted over it.
const LET_LAND := 1.5
## The columns. Open ones bear a beam at a figure's height (colonnade.gd, whose
## figures stand at the joints between acts); low ones the roof's ribs.
const TALL := Colonnade.STAND_TALL+Colonnade.CAP_TALL
const LOW := 28.0
const SHAFT := Vector2(4.6,3.8)
const FOOT := 6.0
const CAP := Vector2(2.2,5.8)
const STUMP := 11.0
## Beam: architrave, frieze, cornice (height, half depth).
const ARCHITRAVE := Vector2(2.0,3.8)
const FRIEZE := Vector2(2.5,3.4)
const CORNICE := Vector2(1.5,5.0)
const BEAM_TALL := ARCHITRAVE.x+FRIEZE.x+CORNICE.x
## The roof: how much of a bay's length a slab covers, its height, the step on it.
const ROOF_SHARE := 0.72
const ROOF_TALL := 4.0
const ROOF_STEP := 2.5
const ROOF_OVER := 5.0
## The broken bays. A slab fallen flat on two heaps: `SLOT` of air under it, on
## the left of the road. A wall of rubble across the road with a notch (toy width).
const SLOT := 10.0
const SLAB_THICK := 4.5
const TOY_NOTCH := 7.0
const RUBBLE_TALL := 21.0

const OPEN := 0
const ROOFED := 1
const BROKEN := 2
## A bay each: `k`, and on a broken one what happened to it. `roof` L or R: only
## that half has its slab; "" none. `gone`: the sides (1 left, -1 right) that lost
## their row at this bay's end. `drop`: the fallen slab. `rubble`: the wall, its
## notch at that u. `lean`: a column leaning from that side.
const PLAN: Array[Dictionary] = [
	{"k":OPEN},
	{"k":OPEN},
	{"k":ROOFED,"roof":"LR"},
	{"k":ROOFED,"roof":"LR"},
	{"k":ROOFED,"roof":"R"},
	{"k":BROKEN,"drop":true},
	{"k":OPEN},
	{"k":ROOFED,"roof":"LR"},
	{"k":ROOFED,"roof":"L"},
	{"k":BROKEN,"rubble":12.0},
	{"k":BROKEN,"gone":[1],"lean":1},
	{"k":OPEN},
]
## The bays in all, with PLAN's first; past PLAN the road is the wreck's.
const BAYS := 61
## What's left at each station from PLAN's end, one letter each, L and R of the road:
## T a column with its beam on to the next, t a column, m a broken shaft, s a stump,
## f a column fallen into the road, o one fallen out of it, l one leaning in,
## d drums, . nothing.
const ROW_L := "-TTTtmTTTt" + "sdTTTt.mft" + "s.d.TTTt.s" + ".os..m.d.t" + "s.s.s.t.ft"
const ROW_R := "-TtfTTTts." + "TTt.sTTTTt" + "..sfd.mt.f" + "s.d.t..s.." + ".s.m.s.dlt"
## How much street each bay keeps from PLAN's end: F whole, G a whole slab and a
## gap, P patches, half sunk where the land rises, N none.
const PAVE := "FFFFFGFFG" + "GFFGPGFGF" + "PGPPFGPPG" + "PNPNPPNPP" + "GPGPGGPPPPPPP"
## What fell, by bay: `drop` a slab on heaps, that high, `wall` rubble with its notch at that u,
## `portal` a beam still across the road at the bay's start, `roof` a slab still
## up, `slalom` aisle columns standing in the road, `heap` a mound at that u, `low`
## a beam across two stumps.
const WRECK := {
	14:{"drop":SLOT},
	18:{"portal":true},
	21:{"wall":-14.0},
	24:{"slalom":true},
	27:{"roof":"L"},
	31:{"heap":10.0},
	33:{"drop":14.0},
	36:{"portal":true},
	41:{"slalom":true},
	44:{"wall":16.0},
	46:{"heap":-16.0},
	49:{"heap":18.0},
	52:{"low":true},
	55:{"portal":true},
	57:{"low":true},
	59:{"heap":-24.0},
}
## The lake: a road crossing it stands this far over it, the lake at -40.
const WET := -38.5
## How low in the lake a fallen stone's foot is set, so it still shows.
const BED := -42.0
## A column broken off, a fallen one's size, a heap's.
const SNAPPED := 25.0
const FALLEN := Vector3(4.2,8.0,34.0)
## How far down a drum or a fallen column goes, in the ground.
const DRUM_FOOT := 20.0
const HEAP_TALL := 15.0
## How far round a heap the ground is read for where it rests.
const HEAP_REST := 12.0
const SNAP_TOP := 3.0
## Aisle columns left standing in the road, how tall, their u; `low`: how far out its stumps
## stand, of the half street.
const AISLE_LEFT := 17.0
const SLALOM := 9.0
const LOW_SHARE := 0.65
const LOW_UP := 15.0
## The lines, by stick: each point Vector3(s, u, h over the paving).
const LINES := {
	"wide":[Vector3(-60.0,0.0,20.0),Vector3(90.0,0.0,20.0),Vector3(130.0,0.0,17.0),Vector3(285.0,0.0,17.0),Vector3(322.0,0.0,25.0),Vector3(375.0,0.0,25.0),Vector3(425.0,0.0,18.0),Vector3(530.0,0.0,18.0),Vector3(578.0,0.0,29.0),Vector3(640.0,0.0,24.0),Vector3(780.0,0.0,22.0),Vector3(1220.0,0.0,24.0),Vector3(1265.0,0.0,33.0),Vector3(1330.0,0.0,33.0),Vector3(1400.0,0.0,28.0),Vector3(1560.0,0.0,28.0),Vector3(1640.0,0.0,20.0),Vector3(1700.0,0.0,20.0),Vector3(1860.0,0.0,24.0),Vector3(2130.0,0.0,24.0),Vector3(2160.0,0.0,20.0),Vector3(2200.0,0.0,24.0),Vector3(2440.0,0.0,28.0),Vector3(2570.0,0.0,28.0),Vector3(2630.0,0.0,33.0),Vector3(2690.0,0.0,33.0),Vector3(2760.0,0.0,24.0),Vector3(3100.0,0.0,24.0),Vector3(3150.0,0.0,30.0),Vector3(3300.0,0.0,20.0),Vector3(3450.0,0.0,30.0),Vector3(3520.0,0.0,34.0),Vector3(3580.0,0.0,48.0),Vector3(3640.0,0.0,56.0),Vector3(3690.0,0.0,80.0),Vector3(3793.0,0.0,150.0),Vector3(3850.0,0.0,150.0)],
	"tight":[Vector3(5.0,86.0,10.0),Vector3(60.0,62.0,10.0),Vector3(85.0,42.0,10.0),Vector3(106.0,28.0,11.0),Vector3(175.0,29.0,11.0),Vector3(215.0,8.0,11.0),Vector3(245.0,5.0,11.0),Vector3(285.0,16.0,11.0),Vector3(310.0,9.0,5.0),Vector3(355.0,9.0,5.0),Vector3(400.0,26.0,10.0),Vector3(450.0,29.0,11.0),Vector3(478.0,29.0,11.0),Vector3(520.0,12.0,11.0),Vector3(582.0,12.0,11.0),Vector3(660.0,0.0,14.0),Vector3(740.0,0.0,14.0),Vector3(800.0,0.0,5.0),Vector3(905.0,0.0,5.0),Vector3(980.0,0.0,12.0),Vector3(1050.0,28.0,14.0),Vector3(1110.0,28.0,14.0),Vector3(1190.0,-14.0,11.0),Vector3(1330.0,-14.0,11.0),Vector3(1410.0,0.0,10.0),Vector3(1440.0,6.0,10.0),Vector3(1470.0,-6.0,10.0),Vector3(1500.0,6.0,10.0),Vector3(1530.0,-6.0,10.0),Vector3(1580.0,8.0,14.0),Vector3(1650.0,20.0,18.0),Vector3(1750.0,10.0,14.0),Vector3(1860.0,-20.0,14.0),Vector3(1900.0,-20.0,12.0),Vector3(1945.0,0.0,3.0),Vector3(2045.0,0.0,3.0),Vector3(2090.0,14.0,12.0),Vector3(2150.0,24.0,14.0),Vector3(2220.0,24.0,14.0),Vector3(2284.0,68.0,14.0),Vector3(2350.0,16.0,14.0),Vector3(2392.0,20.0,12.0),Vector3(2440.0,0.0,10.0),Vector3(2460.0,6.0,10.0),Vector3(2490.0,-6.0,10.0),Vector3(2520.0,6.0,10.0),Vector3(2545.0,-6.0,13.0),Vector3(2570.0,4.0,14.0),Vector3(2615.0,16.0,12.0),Vector3(2690.0,16.0,11.0),Vector3(2790.0,14.0,10.0),Vector3(2890.0,-14.0,12.0),Vector3(3030.0,-14.0,12.0),Vector3(3060.0,0.0,10.0),Vector3(3110.0,0.0,5.0),Vector3(3180.0,0.0,5.0),Vector3(3300.0,0.0,10.0),Vector3(3420.0,0.0,6.0),Vector3(3480.0,0.0,6.0),Vector3(3520.0,0.0,20.0),Vector3(3580.0,0.0,44.0),Vector3(3640.0,0.0,56.0),Vector3(3690.0,0.0,80.0),Vector3(3793.0,0.0,150.0),Vector3(3850.0,0.0,150.0)],
}

static var _pts := PackedVector3Array()
static var _high := PackedFloat64Array()
## The land, while `build` runs (`_rest`).
static var _land: Callable

static func half() -> float: return HALF
static func pitch() -> float: return PITCH
static func length() -> float: return BAYS*pitch()

## The centre line every STEP m: Vector3(x, yaw, z).
static func _trace() -> PackedVector3Array:
	if not _pts.is_empty(): return _pts
	var curve := PackedFloat64Array()
	for b: Vector2 in BENDS:
		for i in int(b.x/STEP): curve.append(b.y/b.x)
	var w := int(EASE/STEP)
	var p := Vector2(FROM)
	var yaw := FROM_YAW
	var n := curve.size()
	for i in n:
		_pts.append(Vector3(p.x,yaw,p.y))
		var total := 0.0
		for j in range(i-w,i+w+1): total += curve[clampi(j,0,n-1)]
		yaw += total/(2.0*w+1.0)*STEP
		p += Vector2(sin(yaw),cos(yaw))*STEP
	return _pts

## The centre line at `s`, as _trace; straight on past either end.
static func at(s: float) -> Vector3:
	var pts := _trace()
	var last := pts.size()-1
	var q := s/STEP
	if q <= 0.0: return pts[0]+Vector3(sin(pts[0].y),0.0,cos(pts[0].y))*s
	if q >= last:
		var e := pts[last]
		return e+Vector3(sin(e.y),0.0,cos(e.y))*(s-last*STEP)
	var i := int(q)
	return pts[i].lerp(pts[i+1],q-i)

## The place (x, z) `u` to the left of the line at `s`.
static func spot(s: float, u: float) -> Vector2:
	var c := at(s)
	return Vector2(c.x+cos(c.y)*u,c.z-sin(c.y)*u)

## The paving's height at `s` (built only).
static func level(s: float) -> float:
	return _high[clampi(int(s/SLAB),0,_high.size()-1)]

## The land's highest under the road's width, per slab, eased, and never far
## under the land it crosses.
static func _heights(land: Callable) -> void:
	_high = PackedFloat64Array()
	var n := int(ceilf(length()/SLAB))+1
	var raw := PackedFloat64Array()
	var w := half()+CURB
	for k in n:
		var top := -INF
		for ds: float in [0.0,SLAB*0.5,SLAB]:
			for f: float in [-1.0,-0.6,-0.2,0.2,0.6,1.0]:
				var q := spot(k*SLAB+ds,w*f)
				top = maxf(top,float(land.call(q.x,q.y)))
		raw.append(maxf(top,WET))
	var soft := raw.duplicate()
	for pass_i in 3:
		var was := soft.duplicate()
		for k in n: soft[k] = (was[maxi(k-1,0)]+was[k]*2.0+was[mini(k+1,n-1)])*0.25
	for k in n: _high.append(maxf(soft[k],raw[k]-LET_LAND)+OVER_LAND)

## Whether whole street is left at (`si`, `u`), PAVE's or PLAN's.
static func _paved(si: float, u: float) -> bool:
	if absf(u) > half()+CURB: return false
	var n := int(floorf(si/pitch()))-PLAN.size()
	if n < 0: return true
	if n >= PAVE.length(): return false
	return PAVE[n] == "F" or (PAVE[n] == "G" and fposmod(si,pitch()) < pitch()*0.5)

## Where a thing that fell comes to rest at (`si`, `u`), `r` m round: the paving where
## there's street, else the lowest ground under it, or its foot just in the lake. So
## nothing that fell hangs in the air, wherever the road's own height stands over the land.
static func _rest(si: float, u: float, r: float) -> float:
	if _paved(si,u): return level(si)
	var q := spot(si,u)
	var low := INF
	for d: Vector2 in [Vector2.ZERO,Vector2(r,0.0),Vector2(-r,0.0),Vector2(0.0,r),Vector2(0.0,-r)]:
		low = minf(low,float(_land.call(q.x+d.x,q.y+d.y)))
	return maxf(low,BED)

static func _sized(cache: Dictionary, key: Variant, make: Callable) -> Shapes:
	if not cache.has(key): cache[key] = make.call()
	return cache[key]

static func build(s: Shapes, land: Callable) -> void:
	_pts = PackedVector3Array()
	_land = land
	_heights(land)
	var cache := {}
	var bays := PLAN.size()
	var p := pitch()
	var w := half()
	# The paving.
	var k := 0
	while k*SLAB < bays*p:
		var mid := (k+0.5)*SLAB
		var long := SLAB*(1.0+(w+CURB)*_bent(mid))+3.0
		long = ceilf(long/2.0)*2.0
		var slab := _sized(cache,"slab%d" % int(long),_paving.bind(long,w))
		var c := at(mid)
		s.stamp(slab,Vector3(c.x,level(mid),c.z),c.y)
		k += 1
	# What stands at each station, by side: -1 nothing, else its height.
	var row := {1.0:[],-1.0:[]}
	for side: float in [1.0,-1.0]:
		for i in bays+1:
			var before: Dictionary = PLAN[maxi(i-1,0)]
			var after: Dictionary = PLAN[mini(i,bays-1)]
			var tall := TALL if int(before.k) != ROOFED or int(after.k) != ROOFED else LOW
			if (before.get("gone",[]) as Array).has(int(side)): tall = STUMP
			(row[side] as Array).append(tall)
	# The columns, and figures at the joints between acts.
	var shaft_tall := _sized(cache,"tall",_column.bind(TALL))
	var shaft_low := _sized(cache,"low",_column.bind(LOW))
	var stump := _sized(cache,"stump",_stump)
	var figure := _sized(cache,"figure",func() -> Shapes: return Colonnade._standing())
	for i in bays+1:
		var si := i*p
		var joint := i > 0 and i < bays and int(PLAN[i-1].k) != int(PLAN[i].k) and (int(PLAN[i-1].k) == OPEN or int(PLAN[i].k) == OPEN)
		for side: float in [1.0,-1.0]:
			var tall := float((row[side] as Array)[i])
			var q := spot(si,side*w)
			var at_y := Vector3(q.x,level(si),q.y)
			if tall == STUMP: s.stamp(stump,at_y,float(i))
			elif tall == TALL and joint: s.stamp(figure,at_y,at(si).y+PI*0.5*side)
			else: s.stamp(shaft_tall if tall == TALL else shaft_low,at_y)
		# The aisle's columns, under cover only.
		if i > 0 and i < bays and int(PLAN[i-1].k) == ROOFED and int(PLAN[i].k) == ROOFED:
			for side: float in [1.0,-1.0]:
				var q := spot(si,side*w*INNER_SHARE)
				s.stamp(shaft_low,Vector3(q.x,level(si),q.y))
	# Beams along each row, ribs across the roofed stations.
	for i in bays:
		var bay: Dictionary = PLAN[i]
		var y := LOW if int(bay.k) == ROOFED else TALL
		for side: float in [1.0,-1.0]:
			var r: Array = row[side]
			if float(r[i]) == STUMP or float(r[i+1]) == STUMP: continue
			_span(s,cache,i*p,(i+1)*p,side*w,y)
		if int(bay.k) == ROOFED:
			_rib(s,cache,i*p,w)
			_rib(s,cache,(i+1)*p,w)
			_roof(s,cache,i,str(bay.roof),w)
		if bay.has("drop"): _dropped(s,cache,i,w)
		if bay.has("rubble"): _wall(s,cache,i,float(bay.rubble),w)
		if bay.has("lean"): _leaning(s,cache,i,int(bay.lean),w)
	_pave_ruin(s,cache,land)
	_ruin(s,cache)
	_land = Callable()

## What's left of the street past PLAN, as PAVE says. A sunk patch sits on the land.
static func _pave_ruin(s: Shapes, cache: Dictionary, land: Callable) -> void:
	var p := pitch()
	for n in PAVE.length():
		var i := PLAN.size()+n
		var kind := PAVE[n]
		if kind == "N": continue
		for k in 2:
			var mid := (i+0.25+k*0.5)*p
			var c := at(mid)
			if kind == "F" or (kind == "G" and k == 0):
				var long := ceilf((SLAB*(1.0+(half()+CURB)*_bent(mid))+3.0)/2.0)*2.0
				var slab := _sized(cache,"slab%d" % int(long),_paving.bind(long,half()))
				s.stamp(slab,Vector3(c.x,level(mid),c.z),c.y)
			elif kind == "P" or k == 0:
				var u := (_h(i,k)-0.5)*half()*1.2
				var q := spot(mid,u)
				var size := 20+2*(int(_h(i,k+4)*3.0)*5)
				var patch := _sized(cache,"patch%d" % size,_patch.bind(float(size)))
				var y := maxf(float(land.call(q.x,q.y))+0.5,WET)
				s.stamp(patch,Vector3(q.x,y,q.y),c.y+(_h(i,k+8)-0.5)*0.5)

## The hash behind the wreck's small choices, 0 to 1: the same on every machine.
static func _h(i: int, k: int) -> float:
	return float(((i*73856093)^(k*19349663)^(i*k*83492791))&1023)/1023.0

## The wreck, a block per two bays: a mesh and a body each, however much is in it.
static func _ruin(s: Shapes, cache: Dictionary) -> void:
	var p := pitch()
	var row := [ROW_L,ROW_R]
	for i in range(PLAN.size(),BAYS,2):
		var a := spot(i*p,0.0)
		var e := spot((i+2)*p,0.0)
		var run := a.distance_to(e)
		var c := Vector3((a.x+e.x)*0.5,atan2(e.x-a.x,e.y-a.y),(a.y+e.y)*0.5)
		var y := level((i+1)*p)
		var b := Shapes.new()
		for st in range(i,BAYS+1 if i+2 >= BAYS else i+2):
			for sd in 2:
				var what: String = (row[sd] as String)[st-PLAN.size()]
				if _held(st): what = "t"
				_remains(s,b,cache,c,y,st,1.0 if sd == 0 else -1.0,what)
			if WRECK.has(st): _wreck(s,b,cache,c,y,st,WRECK[st])
		# The far stand-in: the street as one strip.
		b.layer = Shapes.FAR
		b.box(Vector3(-half(),-3.0,-run*0.5),Vector3(half(),0.4,run*0.5))
		s.stamp(b,Vector3(c.x,y,c.z),c.y)

## Whether what's over the road at station `st` keeps its columns up.
static func _held(st: int) -> bool:
	if WRECK.has(st) and (WRECK[st] as Dictionary).has("portal"): return true
	if WRECK.has(st) and (WRECK[st] as Dictionary).has("roof"): return true
	return WRECK.has(st-1) and (WRECK[st-1] as Dictionary).has("roof")

## (x, y, z) at place `q` and height `y` in the block standing at `c`, `y0` high.
static func _in(c: Vector3, y0: float, q: Vector2, y: float) -> Vector3:
	var dx := q.x-c.x
	var dz := q.y-c.z
	return Vector3(dx*cos(c.y)-dz*sin(c.y),y-y0,dx*sin(c.y)+dz*cos(c.y))

## What's left of a row's column at station `st`, as ROW_L and ROW_R spell it.
static func _remains(s: Shapes, b: Shapes, cache: Dictionary, c: Vector3, y0: float, st: int, side: float, what: String) -> void:
	var si := st*pitch()
	var w := half()
	# What still carries a beam keeps the street's height; the rest stands on its ground.
	var foot := level(si) if what == "T" or _held(st) else _rest(si,side*w,FOOT)
	var o := _in(c,y0,spot(si,side*w),foot)
	var road := at(si).y
	match what:
		"T","t":
			_shaft(b,o,TALL,true)
			if what == "T": _span(s,cache,si,si+pitch(),side*w,TALL)
		"m": _shaft(b,o,SNAPPED,false)
		"s": _shaft(b,o,STUMP,false)
		"f","o":
			_shaft(b,o,STUMP,false)
			var u := side*(w-FALLEN.z*0.6 if what == "f" else w+FALLEN.z*0.6)
			var si2 := si+(_h(st,1)-0.5)*16.0
			var q := spot(si2,u)
			var lying := _sized(cache,"fallen_col",_fallen)
			s.stamp(lying,Vector3(q.x,_rest(si2,u,FALLEN.z*0.5),q.y),road+PI*0.5+(_h(st,2)-0.5)*0.9)
		"l":
			_shaft(b,o,STUMP,false)
			_leaning(s,cache,st,int(side),w)
		"d":
			for k in 3:
				var si2 := si+(_h(st,k+3)-0.5)*30.0
				var u := side*(w-(_h(st,k+6)-0.3)*24.0)
				_drum_in(b,_in(c,y0,spot(si2,u),_rest(si2,u,SHAFT.x)))

## The stones `WRECK` names for bay `i`.
static func _wreck(s: Shapes, b: Shapes, cache: Dictionary, c: Vector3, y0: float, i: int, d: Dictionary) -> void:
	var p := pitch()
	var w := half()
	if d.has("drop"): _dropped(s,cache,i,w,float(d.drop))
	if d.has("wall"): _wall(s,cache,i,float(d.wall),w)
	if d.has("portal"): _rib(s,cache,i*p,w,TALL)
	if d.has("roof"):
		_rib(s,cache,i*p,w,TALL)
		_rib(s,cache,(i+1)*p,w,TALL)
		_roof(s,cache,i,str(d.roof),w,TALL)
	if d.has("slalom"):
		for k in 4:
			var si := (i+k*0.5)*p
			_shaft(b,_in(c,y0,spot(si,-SLALOM if k%2 == 0 else SLALOM),level(si)),AISLE_LEFT,false)
	if d.has("heap"):
		var q := spot((i+0.5)*p,float(d.heap))
		var heap := _sized(cache,"mound",_rubble.bind(20.0,HEAP_TALL,30.0))
		s.stamp(heap,Vector3(q.x,_rest((i+0.5)*p,float(d.heap),HEAP_REST),q.y),at((i+0.5)*p).y+0.4)
	if d.has("low"):
		var si := (i+0.5)*p
		for side: float in [-1.0,1.0]:
			_shaft(b,_in(c,y0,spot(si,side*w*LOW_SHARE),level(si)),LOW_UP,false)
		_rib(s,cache,si,w*LOW_SHARE,LOW_UP)

## A column into block `b`, its foot at `o`: capped, or snapped off. Near only; the
## far mesh has a post.
static func _shaft(b: Shapes, o: Vector3, tall: float, capped: bool) -> void:
	b.layer = Shapes.NEAR
	b.cyl(o+Vector3(0.0,-DEEP,0.0),SHAFT.x,SHAFT.y,tall+DEEP-(CAP.x if capped else 0.0),10)
	b.box(o+Vector3(-FOOT,-DEEP,-FOOT),o+Vector3(FOOT,3.0+KERB,FOOT))
	if capped: b.box(o+Vector3(-CAP.y,tall-CAP.x,-CAP.y),o+Vector3(CAP.y,tall,CAP.y))
	else: b.cyl(o+Vector3(0.8,tall,0.5),SHAFT.y-1.0,SHAFT.y-1.6,SNAP_TOP,6)
	b.layer = Shapes.FAR
	b.box(o+Vector3(-3.5,-4.0,-3.5),o+Vector3(3.5,tall,3.5))

static func _drum_in(b: Shapes, o: Vector3) -> void:
	b.layer = Shapes.NEAR
	b.cyl(o+Vector3(0.0,-DRUM_FOOT,0.0),SHAFT.x,SHAFT.x-0.4,DRUM_FOOT+6.0,8)

## How bent the line is at `s`, the worst near it: 1/R.
static func _bent(s: float) -> float:
	var a := at(s-SLAB*0.5)
	var b := at(s+SLAB*0.5)
	return absf(wrapf(b.y-a.y,-PI,PI))/SLAB

## A run of beam from `s0` to `s1` at `u`, its foot `y` over the paving.
static func _span(s: Shapes, cache: Dictionary, s0: float, s1: float, u: float, y: float) -> void:
	var a := spot(s0,u)
	var b := spot(s1,u)
	var d := b-a
	var long := ceilf((d.length()+CAP.y*2.0)/2.0)*2.0
	var beam := _sized(cache,"beam%d" % int(long),_beam.bind(long))
	var mid := (a+b)*0.5
	s.stamp(beam,Vector3(mid.x,minf(level(s0),level(s1))+y,mid.y),atan2(d.x,d.y))

static func _rib(s: Shapes, cache: Dictionary, si: float, w: float, y := LOW) -> void:
	var long := ceilf((w*2.0+CAP.y*2.0)/2.0)*2.0
	var beam := _sized(cache,"beam%d" % int(long),_beam.bind(long))
	var c := at(si)
	s.stamp(beam,Vector3(c.x,level(si)+y,c.z),c.y+PI*0.5)

## A bay's slab, on the ribs. `sides` L, R or LR.
static func _roof(s: Shapes, cache: Dictionary, i: int, sides: String, w: float, over := LOW) -> void:
	var p := pitch()
	var mid := (i+0.5)*p
	var y := minf(level(i*p),level((i+1)*p))+over+BEAM_TALL
	var c := at(mid)
	var deep := p*ROOF_SHARE
	var full := sides.length() == 2
	var wide := (w+ROOF_OVER)*(2.0 if full else 1.0)
	var slab := _sized(cache,"roof%d" % int(wide),_slab.bind(wide,deep))
	if full: s.stamp(slab,Vector3(c.x,y,c.z),c.y)
	else:
		var q := spot(mid,(w+ROOF_OVER)*0.5*(1.0 if sides == "L" else -1.0))
		s.stamp(slab,Vector3(q.x,y,q.y),c.y)

## A roof slab fallen flat on two heaps, the air under it the low way through.
static func _dropped(s: Shapes, cache: Dictionary, i: int, w: float, slot := SLOT) -> void:
	var mid := (i+0.6)*pitch()
	var c := at(mid)
	var y := maxf(level(mid-pitch()*0.3),level(mid+pitch()*0.3))
	var slab := _sized(cache,"fallen",_slab.bind(w*1.7,pitch()*0.55,false))
	s.stamp(slab,Vector3(c.x,y+slot,c.z),c.y)
	var heap := _sized(cache,"heap%d" % int(slot),_rubble.bind(10.0,slot+1.0,pitch()*0.4))
	for u: float in [-w*0.75,w*0.75]:
		var q := spot(mid,u)
		s.stamp(heap,Vector3(q.x,y,q.y),c.y)

## A wall of rubble across the road, a notch through it at `u`.
static func _wall(s: Shapes, cache: Dictionary, i: int, u: float, w: float) -> void:
	var mid := (i+0.6)*pitch()
	var c := at(mid)
	var y := level(mid)
	var gap := WorldScale.opening(TOY_NOTCH)*0.5
	for run: Vector2 in [Vector2(-w,u-gap),Vector2(u+gap,w)]:
		var long := run.y-run.x
		var heap := _sized(cache,"wall%d" % int(long),_rubble.bind(long*0.5,RUBBLE_TALL,9.0))
		var q := spot(mid,(run.x+run.y)*0.5)
		s.stamp(heap,Vector3(q.x,y,q.y),c.y)

## A column gone over and resting on its neighbour's beam, drums at its foot.
static func _leaning(s: Shapes, cache: Dictionary, i: int, side: int, w: float) -> void:
	var p := pitch()
	var si := (i+0.5)*p
	var c := at(si)
	var q := spot(si,side*w)
	var lean := _sized(cache,"lean",_leaner)
	s.stamp(lean,Vector3(q.x,_rest(si,side*w,SHAFT.x),q.y),c.y+(PI*0.5 if side > 0 else -PI*0.5))
	var drum := _sized(cache,"drum",_drum)
	for f: Vector2 in [Vector2(-0.3,0.45),Vector2(0.15,0.15),Vector2(0.38,0.7)]:
		var d := spot(si+f.x*p,side*w*f.y)
		s.stamp(drum,Vector3(d.x,_rest(si+f.x*p,side*w*f.y,SHAFT.x),d.y),f.x*5.0)

# --- The blocks ------------------------------------------------------------------

## A length of street, its stylobates either side.
static func _paving(long: float, w: float) -> Shapes:
	var b := Shapes.new()
	var hw := w+CURB
	var hl := long*0.5
	b.box(Vector3(-hw,-DEEP,-hl),Vector3(hw,0.0,hl))
	b.layer = Shapes.NEAR
	for side: float in [-1.0,1.0]:
		var x0 := minf(side*(w-CURB),side*hw)
		var x1 := maxf(side*(w-CURB),side*hw)
		b.box(Vector3(x0,0.0,-hl),Vector3(x1,KERB,hl))
	return b

## A patch of the street left in the grass, near only: the far mesh has a strip.
static func _patch(size: float) -> Shapes:
	var b := Shapes.new()
	b.layer = Shapes.NEAR
	b.box(Vector3(-size*0.7,-DEEP*0.5,-size*0.5),Vector3(size*0.7,0.6,size*0.5))
	return b

## A column lying along its z, a tapered section so it isn't a plank.
static func _fallen() -> Shapes:
	var b := Shapes.new()
	var r := FALLEN.x
	var z := FALLEN.z*0.5
	b.layer = Shapes.NEAR
	b.slope(Rect2(-r,-z,r*2.0,z*2.0),Rect2(-r*0.6,-z,r*1.2,z*2.0),-1.0,FALLEN.y)
	b.box(Vector3(-r,-DRUM_FOOT,-z),Vector3(r,-1.0,z))
	return b

static func _column(tall: float) -> Shapes:
	var b := Shapes.new()
	b.cyl(Vector3(0.0,-DEEP,0.0),SHAFT.x,SHAFT.y,tall+DEEP-CAP.x,12)
	b.layer = Shapes.NEAR
	b.box(Vector3(-FOOT,-DEEP,-FOOT),Vector3(FOOT,3.0+KERB,FOOT))
	b.box(Vector3(-CAP.y,tall-CAP.x,-CAP.y),Vector3(CAP.y,tall,CAP.y))
	return b

static func _stump() -> Shapes:
	var b := Shapes.new()
	b.cyl(Vector3(0.0,-DEEP,0.0),SHAFT.x,SHAFT.x-0.3,STUMP+DEEP,12)
	b.layer = Shapes.NEAR
	b.box(Vector3(-FOOT,-DEEP,-FOOT),Vector3(FOOT,3.0+KERB,FOOT))
	return b

static func _beam(long: float) -> Shapes:
	var b := Shapes.new()
	var y := 0.0
	b.layer = Shapes.NEAR
	for band: Vector2 in [ARCHITRAVE,FRIEZE,CORNICE]:
		b.box(Vector3(-band.y,y,-long*0.5),Vector3(band.y,y+band.x,long*0.5))
		y += band.x
	b.layer = Shapes.FAR
	b.box(Vector3(-CORNICE.y,0.0,-long*0.5),Vector3(CORNICE.y,y,long*0.5))
	return b

## `wide` across the road, `deep` along it, its foot at the origin, a step on top.
static func _slab(wide: float, deep: float, stepped := true) -> Shapes:
	var b := Shapes.new()
	b.box(Vector3(-wide*0.5,0.0,-deep*0.5),Vector3(wide*0.5,ROOF_TALL,deep*0.5))
	if not stepped: return b
	b.layer = Shapes.NEAR
	b.box(Vector3(-wide*0.5+ROOF_OVER,ROOF_TALL,-deep*0.5+2.5),Vector3(wide*0.5-ROOF_OVER,ROOF_TALL+ROOF_STEP,deep*0.5-2.5))
	return b

## Stones stepping up to `tall`, `half` wide each way across, `deep` thick.
static func _rubble(hw: float, tall: float, deep: float) -> Shapes:
	var b := Shapes.new()
	b.box(Vector3(-hw,-DEEP,-deep*0.5),Vector3(hw,tall*0.45,deep*0.5))
	b.layer = Shapes.NEAR
	b.box(Vector3(-hw*0.82,tall*0.45,-deep*0.42),Vector3(hw*0.95,tall*0.75,deep*0.46))
	b.box(Vector3(-hw*0.6,tall*0.75,-deep*0.32),Vector3(hw*0.7,tall,deep*0.3))
	b.layer = Shapes.FAR
	b.box(Vector3(-hw*0.8,tall*0.45,-deep*0.4),Vector3(hw*0.8,tall*0.85,deep*0.4))
	return b

## A shaft leaning over +z, level cut top and foot, resting on nothing much.
static func _leaner() -> Shapes:
	var b := Shapes.new()
	var r := SHAFT.x-0.6
	b.slope(Rect2(-r,-r,r*2.0,r*2.0),Rect2(-r,-r+24.0,r*2.0,r*2.0),-2.0,30.0)
	b.box(Vector3(-r,-DRUM_FOOT,-r),Vector3(r,-2.0,r))
	return b

static func _drum() -> Shapes:
	var b := Shapes.new()
	b.cyl(Vector3(0.0,-DRUM_FOOT,0.0),SHAFT.x,SHAFT.x-0.4,DRUM_FOOT+6.0,8)
	return b
