extends "res://scripts/endless/rocks/rock_kind.gd"
## Sea stacks (a rock kind, scripts/endless/rocks/rock_plan.gd): weathered
## pillars standing in the surf off the coast, strongest off headlands.
##
## A try stands in shallow sea (DEPTH under the sea) with land within
## SHORE_MOST m on some sides but not most (a bay is skipped; a headland's
## tip, land on few sides, takes one more readily: HEADLAND). The coast's
## way is read off which ways the land lies. Then one of two forms:
##   line   COUNT stacks strung along the coast, each set off the shore by
##          an inner gap (TOY_INNER, the channel between them and the
##          cliff: the risky line), every THREAD_EVERY-th gap between them a
##          tight thread (TOY_TIGHT), the rest wide passages (TOY_WIDE), now
##          and then a break (TOY_BREAK): crossings far enough apart to link
##          at speed (the plane turns about 30-40 m round at cruise, so
##          weaving every 40 m gap is no line), the open sea outside the
##          safe line.
##   giant  one big stack (GIANT_*), its channel to the shore TOY_GIANT_INNER,
##          often with a satellite or two at TOY_SAT off it: a thread
##          between them, or round it all.
## Every gap is sized with WorldScale.opening from a toy width, between the
## rocks' surfaces at their widest (radius x SHAPE_MOST x (1 + NOISE)).
##
## A stack: a talus under the water, a wave-cut notch at the waterline, a
## body narrowing a little up its height in tiers (beds that step in and
## out), a lean, a squared section, and a flat top (the ground material
## grows turf on it).

const WorldScale = preload("res://scripts/world_scale.gd")
const Field = preload("res://scripts/endless/land_field.gd")

## Tries a cell at density 1, and the chance a fitting spot takes a group
## (HEADLAND x that at a headland's tip).
const TRIES := 3
const TAKE := 0.4
const HEADLAND := 1.5
## The try's depth under the sea (m), the land's reach round it (m) and
## the ways read.
const DEPTH := Vector2(1.5,30.0)
const SHORE_MOST := 220.0
const WAYS := 16
const SHORE_READ := [30.0,60.0,100.0,150.0,220.0]
## The share of tries that make a giant.
const GIANT := 0.32
## A line: its stacks, their radius and height over the sea (m), their
## gaps (toy widths: WorldScale.opening).
const COUNT := Vector2i(4,8)
const RADIUS := Vector2(5.0,11.0)
const TALL := Vector2(22.0,58.0)
const TOY_TIGHT := Vector2(7.0,10.0)
const TOY_WIDE := Vector2(14.0,24.0)
const TOY_BREAK := Vector2(28.0,40.0)
const BREAK := 0.15
const THREAD_EVERY := 3
const TOY_INNER := Vector2(9.0,16.0)
## A giant and its satellites.
const GIANT_RADIUS := Vector2(13.0,22.0)
const GIANT_TALL := Vector2(55.0,100.0)
const TOY_GIANT_INNER := Vector2(12.0,30.0)
const SAT_RADIUS := Vector2(3.0,6.5)
const SAT_TALL := Vector2(12.0,30.0)
const TOY_SAT := Vector2(7.0,11.0)
const SATS := 0.65
## The widest a stack's section stands past its radius (its tiers) and the
## weathering's most push: a gap is kept between radius x SHAPE_MOST x
## (1 + NOISE) either side.
const SHAPE_MOST := 1.06
const NOISE := 0.3
## The weathering (rock_build.gd).
const LUMPS := 0.11
const GRAIN := 0.04
const LEDGES := 0.035
const FLUTES := 0.1
## Where --rock-start puts the plane: this far back along the line (m),
## this high over the sea.
const START_BACK := 420.0
const START_ALT := 12.0

static func plan_cell(field: RefCounted, cx: int, cz: int, density: float, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var cell: float = preload("res://scripts/endless/rocks/rock_plan.gd").CELL
	var tries := int(round(TRIES*density))
	for t in range(tries):
		var x := (cx+0.0)*cell+rng.randf_range(60.0,cell-60.0)
		var z := (cz+0.0)*cell+rng.randf_range(60.0,cell-60.0)
		var roll := rng.randf()
		var sub := RandomNumberGenerator.new()
		sub.seed = rng.randi()
		if not out.is_empty(): continue
		var h: float = field.height(x,z)
		if h > Field.SEA_Y-DEPTH.x or h < Field.SEA_Y-DEPTH.y: continue
		var coast := _coast(field,x,z)
		if coast.is_empty(): continue
		var take := TAKE*(HEADLAND if int(coast.ways) <= WAYS/3 else 1.0)
		if roll > take: continue
		var spec := _giant(field,x,z,coast,sub) if sub.randf() < GIANT else _line(field,x,z,coast,sub)
		if spec.is_empty(): continue
		out.append(spec)
	return out

## Which way the land lies from a point in the sea: {to_land (unit XZ),
## along (unit XZ, the coast's way), ways (how many of WAYS meet land)},
## or {} with none in reach or land most ways round (a bay).
static func _coast(field: RefCounted, x: float, z: float) -> Dictionary:
	var toward := Vector2.ZERO
	var ways := 0
	for k in range(WAYS):
		var d := Vector2.from_angle(TAU*k/WAYS)
		for r: float in SHORE_READ:
			if float(field.height(x+d.x*r,z+d.y*r)) > Field.SEA_Y:
				toward += d/r
				ways += 1
				break
	if ways == 0 or ways > WAYS*5/8: return {}
	var n := toward.normalized()
	return {"to_land":n,"along":Vector2(-n.y,n.x),"ways":ways}

## How far from `p` toward `n` the shore stands at the flying height
## (FLY_OVER m over the sea), or INF within SHORE_MOST: a beach's gentle
## rise is no wall, a cliff is.
const FLY_OVER := 6.0
static func _shore(field: RefCounted, p: Vector2, n: Vector2) -> float:
	var d := 0.0
	while d < SHORE_MOST+60.0:
		if float(field.height(p.x+n.x*d,p.y+n.y*d)) > Field.SEA_Y+FLY_OVER: return d
		d += 4.0
	return INF

## Whether the sea is open `r` m round `p` (no land up out of it).
static func _open(field: RefCounted, p: Vector2, r: float) -> bool:
	if float(field.height(p.x,p.y)) > Field.SEA_Y-1.0: return false
	for k in range(10):
		var d := Vector2.from_angle(TAU*k/10.0)*r
		if float(field.height(p.x+d.x,p.y+d.y)) > Field.SEA_Y-0.3: return false
	return true

static func _widest(r: float) -> float:
	return r*SHAPE_MOST*(1.0+NOISE)

## A stack set off the shore: at `b`, moved along `n` (to the land) so its
## surface stands `inner` m off the shore, or {} where it would not stand
## in open sea.
static func _set_off(field: RefCounted, b: Vector2, n: Vector2, r: float, inner: float) -> Variant:
	var d := _shore(field,b,n)
	var p := b
	if d != INF: p = b+n*clampf(d-(_widest(r)+inner),-80.0,140.0)
	for back: float in [0.0,15.0,35.0]:
		var q := p-n*back
		if _open(field,q,_widest(r)+WorldScale.opening(6.0)): return q
	return null

## A line of stacks along the coast through (x, z).
static func _line(field: RefCounted, x: float, z: float, coast: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: Vector2 = coast.to_land
	var along: Vector2 = coast.along
	if rng.randf() < 0.5: along = -along
	var count := rng.randi_range(COUNT.x,COUNT.y)
	var radii: Array = []
	var gaps: Array = []
	var thread_at := rng.randi_range(0,THREAD_EVERY-1)
	var length := 0.0
	for k in range(count):
		radii.append(rng.randf_range(RADIUS.x,RADIUS.y))
		var g := 0.0
		if rng.randf() < BREAK: g = WorldScale.opening(rng.randf_range(TOY_BREAK.x,TOY_BREAK.y))
		elif k%THREAD_EVERY == thread_at: g = WorldScale.opening(rng.randf_range(TOY_TIGHT.x,TOY_TIGHT.y))
		else: g = WorldScale.opening(rng.randf_range(TOY_WIDE.x,TOY_WIDE.y))
		gaps.append(g)
		length += _widest(radii[k])*2.0+(g if k < count-1 else 0.0)
	var s := -length*0.5
	var placed: Array = []   # [XZ, r]
	var centre := Vector2(x,z)
	for k in range(count):
		var r: float = radii[k]
		s += _widest(r)
		var inner := WorldScale.opening(rng.randf_range(TOY_INNER.x,TOY_INNER.y))
		var got: Variant = _set_off(field,centre+along*s,n,r,inner)
		s += _widest(r)+float(gaps[k])
		if got == null: continue
		var q: Vector2 = got
		var ok := true
		for o: Array in placed:
			if (o[0] as Vector2).distance_to(q) < _widest(r)+_widest(float(o[1]))+WorldScale.opening(TOY_TIGHT.x): ok = false
		if ok: placed.append([q,r,rng.randf_range(TALL.x,TALL.y)])
	if placed.size() < 3: return {}
	var spec := _group(field,centre,placed,rng)
	# The approach: back along the line from its first stack, out past it
	# on the sea's side (the safe line), flying along it.
	var a: Vector2 = placed[0][0]
	var b: Vector2 = placed[placed.size()-1][0]
	var way := (b-a).normalized()
	var start := a-way*START_BACK-n*(_widest(float(placed[0][1]))+WorldScale.opening(TOY_WIDE.x))
	spec["approach"] = {"at":_seaward(field,start,n),"heading":_heading(way),"alt":START_ALT}
	spec["form"] = "line"
	return spec

## A giant stack, and perhaps a satellite or two.
static func _giant(field: RefCounted, x: float, z: float, coast: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: Vector2 = coast.to_land
	var along: Vector2 = coast.along
	var r := rng.randf_range(GIANT_RADIUS.x,GIANT_RADIUS.y)
	var inner := WorldScale.opening(rng.randf_range(TOY_GIANT_INNER.x,TOY_GIANT_INNER.y))
	var got: Variant = _set_off(field,Vector2(x,z),n,r,inner)
	if got == null: return {}
	var g: Vector2 = got
	var placed: Array = [[g,r,rng.randf_range(GIANT_TALL.x,GIANT_TALL.y)]]
	if rng.randf() < SATS:
		for k in range(rng.randi_range(1,2)):
			var sr := rng.randf_range(SAT_RADIUS.x,SAT_RADIUS.y)
			# Out to sea or along the coast, never toward the shore.
			var way := (-n).rotated(rng.randf_range(-1.6,1.6))
			var q := g+way*(_widest(r)+WorldScale.opening(rng.randf_range(TOY_SAT.x,TOY_SAT.y))+_widest(sr))
			if not _open(field,q,_widest(sr)+WorldScale.opening(6.0)): continue
			var ok := true
			for o: Array in placed:
				if (o[0] as Vector2).distance_to(q) < _widest(sr)+_widest(float(o[1]))+WorldScale.opening(TOY_SAT.x): ok = false
			if ok: placed.append([q,sr,rng.randf_range(SAT_TALL.x,SAT_TALL.y)])
	var spec := _group(field,g,placed,rng)
	# The approach: along the coast toward the channel inside the giant.
	var channel := g+n*(_widest(r)+inner*0.5)
	if rng.randf() < 0.5: along = -along
	spec["approach"] = {"at":_seaward(field,channel-along*START_BACK,n),"heading":_heading(along),"alt":START_ALT}
	spec["form"] = "giant"
	return spec

## `at` moved out to sea (away from `n`, the way to the land) until it is
## over open water, so a start there flies in low over the sea.
static func _seaward(field: RefCounted, at: Vector2, n: Vector2) -> Vector2:
	var p := at
	for k in range(30):
		if _open(field,p,20.0): return p
		p -= n*15.0
	return at

## Degrees clockwise from -z for a way in XZ (endless_flight's --heading).
static func _heading(way: Vector2) -> float:
	return rad_to_deg(atan2(way.x,-way.y))

## The group's spec, anchored at sea level over `centre`: placed is
## [[XZ, radius, height over the sea]...].
static func _group(field: RefCounted, centre: Vector2, placed: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pos := Vector3(centre.x,Field.SEA_Y,centre.y)
	var pillars: Array = []
	var reach := 0.0
	for o: Array in placed:
		var q: Vector2 = o[0]
		var r := float(o[1])
		pillars.append(_stack(field,pos,q,r,float(o[2]),rng))
		reach = maxf(reach,q.distance_to(centre)+_widest(r)*1.3)
	return {"pos":pos,"reach":reach,"pillars":pillars,"foot":[],"by_arches":false}

## One stack at world XZ `q` of radius `r`, `tall` m over the sea.
static func _stack(field: RefCounted, pos: Vector3, q: Vector2, r: float, tall: float, rng: RandomNumberGenerator) -> Dictionary:
	# Its foot on the seabed: the lowest ground under it.
	var bed := INF
	for k in range(9):
		var d := Vector2.ZERO if k == 0 else Vector2.from_angle(TAU*k/8.0)*r*1.3
		bed = minf(bed,float(field.height(q.x+d.x,q.y+d.y)))
	var base := bed-pos.y
	var sea := Field.SEA_Y-bed
	var aspect := rng.randf_range(1.0,1.7)
	var ax := sqrt(aspect)
	var top := sea+tall
	var taper := rng.randf_range(0.04,0.2)
	var r_top := r*(1.0-taper)
	var profile: Array = []
	var ring := func(y: float, k: float) -> void:
		profile.append([y,r*k*ax,r*k/ax,0.0,0.0])
	ring.call(-3.0,1.35)
	if sea > 6.0: ring.call(sea-4.0,1.25)
	ring.call(maxf(sea-0.5,0.0),1.05)
	# The wave-cut notch.
	ring.call(sea+1.5,0.9)
	ring.call(sea+3.5,0.97)
	# Tiers: beds stepping out and in up the body.
	var y := sea+5.0
	var tier := 1.0
	while y < top-3.0:
		var u := (y-sea)/tall
		ring.call(y,(1.0-taper*u)*tier)
		var step := rng.randf_range(4.0,11.0)
		var next := minf(y+step,top-3.0)
		ring.call(next-0.6,(1.0-taper*(next-sea)/tall)*tier)
		tier = rng.randf_range(0.94,SHAPE_MOST)
		y = next
	ring.call(top-1.2,(r_top/r)*tier)
	ring.call(top,(r_top/r)*tier*0.86)
	# A lean, most at the top.
	var lean := Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.0,0.07)*tall
	for c: Array in profile:
		var u := clampf((float(c[0])-sea)/tall,0.0,1.0)
		c[3] = lean.x*u*u
		c[4] = lean.y*u*u
	var giant := r > GIANT_RADIUS.x*0.9
	return {"at":Vector3(q.x-pos.x,base,q.y-pos.z),"profile":profile,"yaw":rng.randf()*TAU,"dome":rng.randf_range(0.3,1.2),
		"square":rng.randf_range(0.55,0.75),"lump":clampf(r*0.9,4.0,14.0),"lumps":LUMPS,"grain":GRAIN,"ledges":LEDGES,"flutes":FLUTES,
		"bed":rng.randf_range(5.0,9.0),"ring_every":2.0 if giant else 1.6,"segments":28 if giant else 20,"seed":rng.randi()}
