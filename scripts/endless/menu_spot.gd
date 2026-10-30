extends RefCounted
## Where the main menu parks the plane (scripts/endless/main_menu.gd): a
## flat grassy stretch near the start, with an open run ahead long enough
## to roll off and climb out. Read off the land field alone (its height,
## meadow and rivers), so the same seed and start always give the same
## spot; what stands on the land (trees, arches, halls, tunnels) is the
## caller's to rule out once it is primed there (`clear`).
##
## The search walks rings out from the start, RING m apart, a candidate
## every RING m round each, out to REACH. A candidate is turf (over the sea
## by DRY, no river or pond within its clearance), a meadow (MEADOW or
## more), level round where it stands (no more than LEVEL m of rise within
## PAD m) and has, along one of HEADINGS headings (nearest the asked one
## first), RUN m of turf no steeper than SLOPE a step and never climbing
## more than CLIMB m over where it starts.

const Field = preload("res://scripts/endless/land_field.gd")

const RING := 14.0
const REACH := 900.0
const DRY := 4.0
const MEADOW := 0.45
const PAD := 7.0
const LEVEL := 0.45
const HEADINGS := 16
const RUN := 110.0
const STEP := 5.0
const SLOPE := 0.09
const CLIMB := 3.0
## Over this far from a river's line it is clear of the water.
const RIVER_ROOM := 12.0
## Past halfway along the run the clear line climbs this many m a metre.
const CLIMB_OUT := 0.12

## The candidates in order, nearest the start first: each {at: Vector2,
## heading: float (radians, as SkyPlane's: 0 toward -z, positive to the
## left)}, at most `most` of them. Empty if none is within REACH. `spread`:
## how many of the HEADINGS a candidate tries, nearest the asked one first
## (3: the asked one and one step either side).
static func find(field: RefCounted, start: Vector2, heading := 0.0, most := 8, spread := HEADINGS) -> Array:
	var out: Array = []
	var r := 0.0
	while r <= REACH and out.size() < most:
		var count := 1 if r == 0.0 else maxi(6,int(TAU*r/RING))
		# Each ring starts a little round from the last, so the rings'
		# candidates don't line up along one spoke.
		var turn := r*0.013
		for i in count:
			var a := turn+TAU*i/count
			var p := start+Vector2(sin(a),cos(a))*r
			var way: float = _spot(field,p,heading,spread)
			if not is_nan(way): out.append({"at":p,"heading":way})
			if out.size() >= most: break
		r += RING
	return out

## The heading the plane can take off along from `p`, or NAN.
static func _spot(field: RefCounted, p: Vector2, heading: float, spread := HEADINGS) -> float:
	var h0 := _turf(field,p)
	if is_nan(h0): return NAN
	var s: Vector2 = field.sample(p.x,p.y)
	if s.y < MEADOW: return NAN
	for k in 6:
		var a := TAU*k/6.0
		var h := _turf(field,p+Vector2(sin(a),cos(a))*PAD)
		if is_nan(h) or absf(h-h0) > LEVEL: return NAN
	# The headings nearest the asked one first, alternating either side.
	for n in mini(spread,HEADINGS):
		var k := int((n+1)*0.5)*(1 if n%2 == 1 else -1)
		var way := heading+TAU*k/HEADINGS
		if _run_clear(field,p,h0,way): return wrapf(way,-PI,PI)
	return NAN

## The turf's height at `p`, or NAN over the sea, a river or a pond.
static func _turf(field: RefCounted, p: Vector2) -> float:
	var h: float = field.height(p.x,p.y)
	if h < Field.SEA_Y+DRY: return NAN
	if float(field.last_river) < RIVER_ROOM: return NAN
	return h

## RUN m on from `p` along `way` is turf, never steeper than SLOPE a step
## nor climbing more than CLIMB.
static func _run_clear(field: RefCounted, p: Vector2, h0: float, way: float) -> bool:
	var dir := Vector2(-sin(way),-cos(way))
	var last := h0
	var d := STEP
	while d <= RUN:
		var h := _turf(field,p+dir*d)
		if is_nan(h): return false
		if absf(h-last) > SLOPE*STEP or h-h0 > CLIMB: return false
		last = h
		d += STEP
	return true

## Whether nothing standing on the land (`blocked`, a point inside a tree,
## an arch, a hall or a tunnel's rock) is in the way at the spot: round
## where it stands within `room` m (for the camera circling it), or along
## the run and the climb out past it (rising CLIMB_OUT m a metre from
## halfway).
static func clear(field: RefCounted, spot: Dictionary, room: float, blocked: Callable) -> bool:
	var at: Vector2 = spot.at
	var dir := Vector2(-sin(float(spot.heading)),-cos(float(spot.heading)))
	for k in 12:
		var a := TAU*k/12.0
		for rr in [room*0.4,room*0.75,room]:
			var q: Vector2 = at+Vector2(sin(a),cos(a))*float(rr)
			if blocked.call(Vector3(q.x,field.height(q.x,q.y)+1.0,q.y)): return false
	var d := 0.0
	while d <= RUN*1.6:
		var q := at+dir*d
		var lift := 1.0+maxf(0.0,d-RUN*0.5)*CLIMB_OUT
		for side in [-1.0,0.0,1.0]:
			var s: Vector2 = q+Vector2(-dir.y,dir.x)*float(side)*room*0.5
			if blocked.call(Vector3(s.x,field.height(s.x,s.y)+lift,s.y)): return false
		d += STEP
	return true

