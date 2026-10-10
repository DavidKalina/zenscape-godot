extends RefCounted
## The Sundered hall erupting out of the cloud sea in pieces (docs/design/
## hall-eruption.md): plain data, safe on a worker, the same every time.
##
## The hall is the moments set piece the sky world stands (`moments_hall`,
## scripts/sky_moments_plan.gd layout 0: sundered_flow's greybox stone, two
## halves A and B with the gap between). Its solids are taken exactly as
## SkyMoments stands them (`Plan.local_solids`, the station's own metres,
## the entry at 0 flying north), and each one goes to exactly one piece, so
## the settled hall is the same hall: the line, the moments and the tokens
## still fit. Each bay is laid again here (FlightCourse `_bay`, the same
## order) only to say which bay, which bay line and what each solid is.
##
## The pieces, in the order they rise (CATEGORIES), base first and big to
## small:
##   base    each half's floor, with a faceted rock keel hung under it
##           (`keels`, an addition: under the floor, clear of the line)
##   piers   every column on its own, gate to apse
##   walls   runs of WALL_RUN bays a side, arches and breaches with them
##   spans   per bay line: the roof beam, the tie, the slit screen (the
##           arches across the nave)
##   roofs   per roofed bay, its strips and architraves, left and right
##   stones  a few floating stones round the hall (`stones`, an addition,
##           clear of the line and every moment)
## Each piece: {id, category, half, bay, solids (indices into
## `local_solids`, the hall's own; keels and stones carry their own in
## `extra`), pivot (its middle, station metres), lo, hi (its box), across
## (unit, the way out of the hall at it), side, out (m it comes in from),
## lift (m over its place it slides in at), supports (ids that must stand
## first), start (s), rise, slot, settle, over (m)}.
##
## Timing (`schedule`): CHURN_LEAD of cloud churn, then a piece every
## TIMING[category].gap seconds, CATEGORY_PAUSE between categories, and no
## piece arriving before what it stands on (its supports) has arrived. All
## of it scales with `speed` and `gaps`.

const Course = preload("res://scripts/flight_course.gd")
const Plan = preload("res://scripts/sky_moments_plan.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")

## The moments layout this is (sky_moments_plan.gd: 0 is moments_hall).
const LAYOUT := 0
const CATEGORIES := ["base","piers","walls","spans","roofs","stones"]
## Per category: gap (s from one piece's start to the next), rise (s, out
## of the sea to its slot height), slot (s, in over the hall and down into
## place; 0 straight up), settle (s of overshoot ringing out), over (m it
## overshoots by), dip (m it sinks past its place landing from a slot),
## tilt (degrees it comes up tipped by), lift (m over its place it comes in
## at), margin (m clear of the hall's side it rises beside).
const TIMING := {
	"base":  {"gap":0.7, "rise":3.0,"slot":0.0,"settle":1.4,"over":1.8,"dip":0.0, "tilt":3.0, "lift":0.0,"margin":0.0},
	"piers": {"gap":0.06,"rise":1.9,"slot":0.7,"settle":0.8,"over":0.6,"dip":0.25,"tilt":9.0, "lift":1.5,"margin":2.5},
	"spans": {"gap":0.1, "rise":2.0,"slot":0.9,"settle":0.8,"over":0.5,"dip":0.2, "tilt":7.0, "lift":4.0,"margin":2.5},
	"walls": {"gap":0.15,"rise":2.1,"slot":0.8,"settle":0.9,"over":0.6,"dip":0.25,"tilt":6.0, "lift":1.5,"margin":2.0},
	"roofs": {"gap":0.09,"rise":1.9,"slot":0.9,"settle":0.8,"over":0.5,"dip":0.2, "tilt":10.0,"lift":4.0,"margin":2.5},
	"stones":{"gap":0.12,"rise":2.2,"slot":0.0,"settle":1.2,"over":1.2,"dip":0.0, "tilt":25.0,"lift":0.0,"margin":0.0},
}
## Cloud churn before the first piece breaks through (s).
const CHURN_LEAD := 1.0
## The pause between one category's last start and the next's first (s).
const CATEGORY_PAUSE := 0.25
## A piece arrives this long (s) after what it stands on at the soonest.
const ARRIVE_AFTER := 0.15
## Bays per wall run.
const WALL_RUN := 3
## The hall's half width (m, to the walls' outer faces).
const HALF_W := Hall.WALL_Z+Hall.WALL_THICK*0.5
## A piece inside the rows (|across| under this) comes in over the wall
## tops (its foot this high over the floor) and down into place.
const INSIDE := Hall.ROW_Z-1.0
const OVER_WALLS := Hall.ROOF_TOP+2.0
## The keels: depth under the floor (m, at a half's middle and its ends),
## how far the bottom draws in (share of the top), the jitter (m).
const KEEL_DEEP := Vector2(16.0,6.0)
const KEEL_TAPER := 0.42
const KEEL_JITTER := 1.6
## The floating stones: how many, their size (m), seed, and how far they
## keep from the line and every moment (m, past their own half diagonal).
const STONES := 9
const STONE_SIZE := Vector2(1.6,4.2)
const STONE_SEED := 7
const STONE_KEEP := 7.0

## Every piece of the hall, planned and timed. opts: keels (bool, true),
## stones (bool, true), path ("arc" or "straight"), speed (time scale, 1),
## gaps (scales the gaps, 1).
static func make(opts := {}) -> Dictionary:
	var solids := Plan.local_solids(LAYOUT)
	var info := classify()
	var pieces := _group(solids,info,opts)
	schedule(pieces,opts)
	return {"solids":solids,"pieces":pieces,"length":length(pieces)}

## What every solid of the hall is: [{bay, half, kind ("floor", "column",
## "span", "wall", "roof"), line (0 or 1: which bay line), across (m, + the
## right), side (-1, 1)}], in `Plan.local_solids` order.
static func classify() -> Array:
	var s: Dictionary = Plan.stations()[LAYOUT]
	var out := []
	var bay := 0
	var half := 0
	for part: Array in s.parts:
		if str(part[0]) != "bay": continue
		var at: Vector3 = part[1]
		var yaw := float(part[2])
		var plan: Dictionary = part[3]
		var turn := Basis(Vector3.UP,yaw+PI*0.5)
		for q: Dictionary in Course._bay(at,yaw,plan):
			var local: Vector3 = turn.inverse()*((q.middle as Vector3)-at)
			var kind := "span"
			if q.kind == "cyl": kind = "column"
			elif local.y < 0.0: kind = "floor"
			elif absf(absf(local.z)-Hall.WALL_Z) < 0.01 and is_equal_approx((q.size as Vector3).z,Hall.WALL_THICK): kind = "wall"
			elif is_equal_approx((q.size as Vector3).x,Hall.BAY): kind = "roof"
			out.append({"bay":bay,"half":half,"kind":kind,"line":0 if local.x < Hall.BAY*0.5 else 1,"across":local.z,"side":-1 if local.z < 0.0 else 1,
				"turn":turn,"at":at})
		if bool(plan.get("last",false)): half += 1
		bay += 1
	return out

static func _group(solids: Array, info: Array, opts: Dictionary) -> Array:
	var keyed := {}
	var order := []
	var add := func(key: String, category: String, index: int, i: Dictionary) -> void:
		if not keyed.has(key):
			keyed[key] = {"id":key,"category":category,"half":i.half,"bay":i.bay,"solids":[],"extra":[],"side":i.side,"bays":[]}
			order.append(key)
		keyed[key].solids.append(index)
		keyed[key].bays.append(i.bay)
	for k in range(info.size()):
		var i: Dictionary = info[k]
		match str(i.kind):
			"floor": add.call("base_%d" % i.half,"base",k,i)
			"column": add.call("pier_%02d_%d_%+.1f" % [i.bay,i.line,i.across],"piers",k,i)
			"span": add.call("span_%02d_%d" % [i.bay,i.line],"spans",k,i)
			"wall":
				var first := _first_bay(info,i.half)
				add.call("wall_%d_%d_%+d" % [i.half,(int(i.bay)-first)/WALL_RUN,i.side],"walls",k,i)
			"roof": add.call("roof_%02d_%+d" % [i.bay,i.side],"roofs",k,i)
	var pieces := []
	for key: String in order: pieces.append(keyed[key])
	if opts.get("keels",true):
		for p: Dictionary in pieces:
			if p.category == "base": p.extra = keels(solids,info,int(p.half))
	if opts.get("stones",true):
		var at := 0
		for stone: Dictionary in stones(solids):
			pieces.append({"id":"stone_%d" % at,"category":"stones","half":-1,"bay":-1,"solids":[],"extra":[stone],"side":1,"bays":[]})
			at += 1
	# In order: by category, then along the hall (half, bay, then the
	# line, then across), walls alternating sides run by run.
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca := CATEGORIES.find(a.category)
		var cb := CATEGORIES.find(b.category)
		if ca != cb: return ca < cb
		if a.half != b.half: return a.half < b.half
		return str(a.id) < str(b.id))
	var path: String = opts.get("path","arc")
	for p: Dictionary in pieces: _shape(p,solids,path)
	return pieces

static func _first_bay(info: Array, half: int) -> int:
	for i: Dictionary in info:
		if i.half == half: return int(i.bay)
	return 0

## A piece's box, middle and way in.
static func _shape(p: Dictionary, solids: Array, path: String) -> void:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for k: int in p.solids:
		var q: Dictionary = solids[k]
		var e := Plan.extent(q)
		lo = lo.min((q.middle as Vector3)-e)
		hi = hi.max((q.middle as Vector3)+e)
	for q: Dictionary in p.extra:
		var e := Plan.extent(q) if q.kind != "hull" else Vector3.ZERO
		if q.kind == "hull":
			for v: Vector3 in q.points:
				lo = lo.min(v)
				hi = hi.max(v)
		else:
			lo = lo.min((q.middle as Vector3)-e)
			hi = hi.max((q.middle as Vector3)+e)
	p.lo = lo
	p.hi = hi
	p.pivot = (lo+hi)*0.5
	var t: Dictionary = TIMING[p.category]
	for key: String in t: p[key] = t[key]
	p.across = Vector3.ZERO
	p.out = 0.0
	if path == "arc" and float(t.slot) > 0.0:
		# Out of the hall across its bay, from the side it is on (a piece
		# across the middle from alternating sides); far enough that its
		# inner edge clears the hall's side by `margin`.
		# Across the bay in the piece's middle.
		var bays: Array = p.bays
		var middle_bay := int(bays[bays.size()/2])
		var across: Vector3 = Basis(Vector3.UP,float(_bay_part(middle_bay)[2])+PI*0.5)*Vector3.BACK
		across = Vector3(across.x,0.0,across.z).normalized()
		var bay_at := _bay_at(middle_bay)
		var c: float = ((p.pivot as Vector3)-bay_at).dot(across)
		var e := 0.0
		for k: int in p.solids:
			var q: Dictionary = solids[k]
			var x := Plan.extent(q)
			e = maxf(e,absf(((q.middle as Vector3)-(p.pivot as Vector3)).dot(across))+absf(x.x*across.x)+absf(x.z*across.z))
		var side := float(signf(c)) if absf(c) > 1.0 else (1.0 if (hash(p.id) & 1) == 0 else -1.0)
		p.side = int(side)
		p.across = across*side
		p.out = maxf(0.0,HALF_W+float(t.margin)-(side*c-e))
		var lift := float(t.lift)
		if absf(c) < INSIDE: lift = maxf(lift,OVER_WALLS-(lo.y-_floor_of(p)))
		p.lift = lift
	else:
		p.slot = 0.0
		p.lift = 0.0
		p.dip = 0.0

static func _bay_at(bay: int) -> Vector3:
	var s: Dictionary = Plan.stations()[LAYOUT]
	var k := 0
	for part: Array in s.parts:
		if str(part[0]) != "bay": continue
		if k == bay: return part[1]
		k += 1
	return Vector3.ZERO

## The floor's top (station metres) under a piece's bay.
static func _floor_of(p: Dictionary) -> float:
	return _bay_at(int(p.bay)).y if int(p.bay) >= 0 else 0.0

## Each piece's start (s from the eruption's start). Rising one after
## another: CHURN_LEAD, then each category in turn; a piece never lands
## before its supports.
static func schedule(pieces: Array, opts := {}) -> void:
	var speed := maxf(0.05,float(opts.get("speed",1.0)))
	var gaps := maxf(0.0,float(opts.get("gaps",1.0)))
	var by_id := {}
	for p: Dictionary in pieces:
		p.rise = float(p.rise)/speed
		p.slot = float(p.slot)/speed
		p.settle = float(p.settle)/speed
		by_id[p.id] = p
	for p: Dictionary in pieces: p.supports = supports(p,pieces)
	var t := CHURN_LEAD/speed
	var last := ""
	for p: Dictionary in pieces:
		if last != "" and last != p.category: t += CATEGORY_PAUSE*gaps/speed
		var start := t
		for id: String in p.supports:
			var s: Dictionary = by_id[id]
			start = maxf(start,arrives(s)+ARRIVE_AFTER/speed-float(p.rise)-float(p.slot))
		p.start = start
		t = start+float(TIMING[p.category].gap)*gaps/speed
		last = p.category

## What a piece stands on: its half's base (piers, walls, spans), its bay
## line's piers and its bay's walls (spans), its bay's spans and walls
## (roofs).
static func supports(p: Dictionary, pieces: Array) -> Array:
	var out := []
	for q: Dictionary in pieces:
		if q.id == p.id: continue
		match str(p.category):
			"piers","walls":
				if q.category == "base" and q.half == p.half: out.append(q.id)
			"spans":
				if q.category == "base" and q.half == p.half: out.append(q.id)
				if q.category == "piers" and q.bay == p.bay: out.append(q.id)
				if q.category == "walls" and q.half == p.half and _in_run(q,int(p.bay)): out.append(q.id)
			"roofs":
				if q.category == "spans" and q.bay == p.bay: out.append(q.id)
				if q.category == "walls" and q.half == p.half and _in_run(q,int(p.bay)): out.append(q.id)
	return out

static func _in_run(wall: Dictionary, bay: int) -> bool:
	# A wall run's bay is its first (its solids come in bay order).
	return bay >= int(wall.bay) and bay < int(wall.bay)+WALL_RUN

## When a piece is in its place (s): started, risen, slid in.
static func arrives(p: Dictionary) -> float:
	return float(p.start)+float(p.rise)+float(p.slot)

## When it has stopped ringing (s).
static func settles(p: Dictionary) -> float:
	return arrives(p)+float(p.settle)

## The whole eruption's length (s): the last piece settled.
static func length(pieces: Array) -> float:
	var out := 0.0
	for p: Dictionary in pieces: out = maxf(out,settles(p))
	return out

# --- Additions round the hall ---------------------------------------------------------

## The rock keel under half `half`'s floor: a faceted frustum under each
## bay's floor, deepest at the half's middle, drawn in at the bottom, the
## end bays drawn in at their outer ends so the gap stays open sky. Each a
## {"kind":"hull","points"}.
static func keels(solids: Array, info: Array, half: int) -> Array:
	var bays := []
	for k in range(info.size()):
		var i: Dictionary = info[k]
		if i.half == half and i.kind == "floor": bays.append([k,i])
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242+half
	for n in range(bays.size()):
		var k: int = bays[n][0]
		var q: Dictionary = solids[k]
		var b: Basis = q.basis
		var h: Vector3 = (q.size as Vector3)*0.5
		var top := (q.middle as Vector3).y-h.y
		var u := (float(n)+0.5)/float(bays.size())
		var deep := lerpf(KEEL_DEEP.y,KEEL_DEEP.x,sin(u*PI))+rng.randf_range(-KEEL_JITTER,KEEL_JITTER)
		var mid: Vector3 = q.middle
		# The bay's own frame: x along the nave, z across.
		var ax := b.x
		var az := b.z
		var long := h.x+0.3
		var wide := h.z-0.4
		var pull_back := 0.0
		var pull_front := 0.0
		if n == 0: pull_back = 1.0
		if n == bays.size()-1: pull_front = 1.0
		var pts := PackedVector3Array()
		for sx: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				var lx := long-(pull_back if sx < 0.0 else pull_front)*0.8
				pts.append(Vector3(mid.x,top-0.02,mid.z)+ax*sx*lx+az*sz*wide)
		var drift := ax*rng.randf_range(-1.5,1.5)+az*rng.randf_range(-2.0,2.0)
		var taper := KEEL_TAPER+rng.randf_range(-0.08,0.08)
		for sx: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				var lx := long*taper*(0.55 if (sx < 0.0 and pull_back > 0.0) or (sx > 0.0 and pull_front > 0.0) else 1.0)
				var d := deep*(0.85+0.15*rng.randf())
				pts.append(Vector3(mid.x,top-d,mid.z)+ax*sx*lx+az*sz*wide*taper+drift)
		# A shoulder ring half way down, pushed out a little: facets.
		for sx: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				var lx := long*(0.8+rng.randf()*0.1)-(pull_back if sx < 0.0 else pull_front)*2.0
				pts.append(Vector3(mid.x,top-deep*0.38,mid.z)+ax*sx*lx+az*sz*wide*(0.8+rng.randf()*0.12)+drift*0.4)
		out.append({"kind":"hull","points":pts,"keel":true})
	return out

## A few floating stones round the hall, beside its walls and down in the
## gap, each a turned box, every one STONE_KEEP clear of the line (and its
## way in) and of every moment, and clear of the hall's stone.
static func stones(solids: Array) -> Array:
	var keep := keep_points()
	var rng := RandomNumberGenerator.new()
	rng.seed = STONE_SEED
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for q: Dictionary in solids:
		var e := Plan.extent(q)
		lo = lo.min((q.middle as Vector3)-e)
		hi = hi.max((q.middle as Vector3)+e)
	var out := []
	var tries := 0
	while out.size() < STONES and tries < 4000:
		tries += 1
		var bay := rng.randi_range(0,14)
		var at := _bay_at(bay)
		var yaw := float(_bay_part(bay)[2])
		var turn := Basis(Vector3.UP,yaw+PI*0.5)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var c := Vector3(rng.randf_range(0.0,Hall.BAY),rng.randf_range(-14.0,7.0),side*(HALF_W+rng.randf_range(5.0,16.0)))
		if out.size() >= STONES-2:
			# Two down in the gap, well under the line.
			at = (_bay_at(8)+_bay_at(9))*0.5
			turn = Basis.IDENTITY
			c = Vector3(rng.randf_range(-12.0,12.0),rng.randf_range(-26.0,-17.0),rng.randf_range(-8.0,8.0))
		var middle: Vector3 = at+turn*c
		var size := Vector3(rng.randf_range(STONE_SIZE.x,STONE_SIZE.y),rng.randf_range(STONE_SIZE.x,STONE_SIZE.y)*0.7,rng.randf_range(STONE_SIZE.x,STONE_SIZE.y))
		var r := size.length()*0.5
		var ok := true
		for p: Vector3 in keep:
			if p.distance_to(middle) < r+STONE_KEEP:
				ok = false
				break
		for q: Dictionary in out:
			if (q.middle as Vector3).distance_to(middle) < r+(q.size as Vector3).length()*0.5+3.0: ok = false
		var inside := middle.x > lo.x-r and middle.x < hi.x+r and middle.z > lo.z-r and middle.z < hi.z+r and middle.y > lo.y-r and middle.y < hi.y+r
		if inside:
			for q: Dictionary in solids:
				if Course.distance(q,middle) < r+1.0: ok = false
		if not ok: continue
		var basis := Basis(Vector3.UP,rng.randf()*TAU)*Basis(Vector3.RIGHT,rng.randf_range(-0.5,0.5))*Basis(Vector3.BACK,rng.randf_range(-0.5,0.5))
		out.append({"kind":"box","middle":middle,"size":size,"basis":basis.orthonormalized(),"stone":true})
	return out

static func _bay_part(bay: int) -> Array:
	var s: Dictionary = Plan.stations()[LAYOUT]
	var k := 0
	for part: Array in s.parts:
		if str(part[0]) != "bay": continue
		if k == bay: return part
		k += 1
	return []

## The points the additions keep clear of (station metres): the line every
## metre, its way in (the starter, the leads) and its way out, and every
## moment.
static func keep_points() -> Array[Vector3]:
	var line := Plan.line(LAYOUT)
	var way: Array[Vector3] = [Vector3(0.0,0.0,float(Plan.LEADS[-1])+20.0),Vector3(0.0,0.0,0.0)]
	way.append_array(line)
	var last: Vector3 = line[-1]
	var before: Vector3 = line[-2]
	way.append(last+(last-before).normalized()*40.0)
	var out: Array[Vector3] = []
	for i in range(way.size()-1):
		var a: Vector3 = way[i]
		var b: Vector3 = way[i+1]
		var n := maxi(1,int(ceil(a.distance_to(b))))
		for k in range(n): out.append(a.lerp(b,float(k)/float(n)))
	out.append(way[-1])
	for m: Dictionary in Plan.moments(LAYOUT): out.append(m.at)
	return out
