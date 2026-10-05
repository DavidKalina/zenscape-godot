extends RefCounted
## Where the little plane (scripts/sky_plane.gd) comes down on an island and
## where it takes off from: a survey of the land as a grid, the longest,
## flattest clear run on it, and how the plane stands parked on its two
## wheels and its tail skid.
##
## Plain maths on callables in the plate's own frame (metres in XZ), so the
## tests can hand it any island; the wanderer (scripts/wanderer_eye.gd)
## hands it the plate's real heights, water, trees, rocks and buildings.
##
## The survey (`survey`) lays a CELL m grid over the land. Each cell is
## clear, by the shore, blocked or off the land. Off the land and within
## SHORE of it is "by the shore", so a strip keeps its wheels off the rim;
## water, a bridge's deck, ground steeper across than SIDE_SLOPE, and
## anything standing taller than the wings sit low (a tree, a rock, a
## cabin, a lamp, every footprint widened by HALF_SPAN) are blocked.
##
## A landing strip (`pick`) is a straight run of clear cells, tried at
## every ANGLES-th of a half turn across the land every LINE_GAP m. Along
## it the ground may climb or fall no more than GRADE a metre. A run is
## scored by its length up to IDEAL (longer adds little after), less its
## bumps, and a little more into the wind and the way the plane is already
## heading. The plane touches down TOUCH_IN m into it and stops by END_IN
## m short of its far end. No run at least SHORT_RUN long: it falls back to
## the clearest cell nearest the land's middle, a short hop of HOP m, and
## failing even that, the middle itself. It never refuses.
##
## A takeoff run (`takeoff`) starts where the plane stands: whichever way
## runs clear furthest, or off the shore (the plane simply flies off the
## edge), into the wind and straight ahead if it can.

const CELL := 0.5
## The plane's half wingspan, with a little room (m): every blocker's
## footprint is widened by it, so the wings pass clear.
const HALF_SPAN := 0.85
## Cells off the land within SHORE m of it keep a strip off the rim.
const SHORE := 0.9
## Round water and ground too steep, a little room for the wheels (m).
const WET_ROOM := 0.5
## Ground steeper than SIDE_SLOPE (m per m, any way) blocks; along a run
## it may change by GRADE a metre.
const SIDE_SLOPE := 0.45
const GRADE := 0.22
## Orientations tried over a half turn (both ways along each are scored),
## and the gap between parallel lines (m).
const ANGLES := 12
const LINE_GAP := 1.0
## The strip: a run's length that counts in full, the shortest that is a
## strip, the shortest a short hop needs, and how far in from its ends the
## plane touches and stops (m).
const IDEAL := 18.0
const MIN_RUN := 6.0
const SHORT_RUN := 3.0
const TOUCH_IN := 1.0
const END_IN := 0.8
const HOP := 2.5
## Scoring: metres of run a metre of bump costs, and the metres of run
## landing straight into the wind or straight on from the plane's way is
## worth.
const BUMP := 8.0
const WIND := 3.0
const ON_WAY := 2.0
## A takeoff run needs LIFT_RUN m to lift off; runs off the shore count as
## that long.
const LIFT_RUN := 9.0

## Cell states.
const CLEAR := 0
const NEAR_SHORE := 1
const BLOCKED := 2
const OFF := 3

## The plane parked: nose-up on its wheels and tail skid. The wheels touch
## WHEEL m ahead of the middle and WHEEL_GAUGE m either side, the skid
## TAIL m behind; the pitch it rests at on level ground (radians).
const WHEEL := 0.28
const WHEEL_GAUGE := 0.2
const TAIL := 0.66
const REST_PITCH := 0.299
## The wheels' bottom under the figure's origin and ahead of it, and the
## figure's origin under the flight's position (scripts/plane_figure.gd).
const WHEEL_DROP := 0.41
const FIGURE_DROP := 0.2

## The grid over `area` (plate XZ): `height` is Callable(Vector2) -> Variant,
## the ground's height or null off the land; `wet` is Callable(Vector2) ->
## bool, water or a deck there; `blockers` are Vector3(x, z, radius) of what
## stands taller than the wings. Returns {origin, w, d, state, h}.
static func survey(area: Rect2, height: Callable, wet: Callable, blockers: PackedVector3Array) -> Dictionary:
	area = area.grow(SHORE+CELL)
	var w := maxi(1,int(ceil(area.size.x/CELL)))
	var d := maxi(1,int(ceil(area.size.y/CELL)))
	var state := PackedByteArray()
	state.resize(w*d)
	var h := PackedFloat32Array()
	h.resize(w*d)
	for j in range(d):
		for i in range(w):
			var p := area.position+Vector2(i+0.5,j+0.5)*CELL
			var at: Variant = height.call(p)
			var k := j*w+i
			if at == null:
				state[k] = OFF
				h[k] = NAN
				continue
			h[k] = float(at)
			state[k] = BLOCKED if bool(wet.call(p)) else CLEAR
	# Too steep across: any neighbour more than SIDE_SLOPE a metre off.
	var steep := PackedByteArray()
	steep.resize(w*d)
	for j in range(d):
		for i in range(w):
			var k := j*w+i
			if state[k] != CLEAR: continue
			for o: Vector2i in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
				var a := i+o.x
				var b := j+o.y
				if a < 0 or b < 0 or a >= w or b >= d: continue
				var n := h[b*w+a]
				if not is_nan(n) and absf(n-h[k]) > SIDE_SLOPE*CELL: steep[k] = 1
	for k in range(w*d):
		if steep[k] == 1: state[k] = BLOCKED
	var map := {"origin":area.position,"w":w,"d":d,"state":state,"h":h}
	# Round the rim: clear cells near land's end are by the shore; round
	# water, blocked.
	var edges := []
	for j in range(d):
		for i in range(w):
			var k := j*w+i
			if state[k] == CLEAR: continue
			for o: Vector2i in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
				var a := i+o.x
				var b := j+o.y
				if a >= 0 and b >= 0 and a < w and b < d and state[b*w+a] == CLEAR:
					edges.append(Vector3i(i,j,state[k]))
					break
	for e: Vector3i in edges:
		var mark := NEAR_SHORE if e.z == OFF else BLOCKED
		_stamp(map,Vector2(e.x+0.5,e.y+0.5)*CELL+area.position,SHORE if e.z == OFF else WET_ROOM,mark)
	for b in blockers: _stamp(map,Vector2(b.x,b.y),b.z+HALF_SPAN,BLOCKED)
	return map

## Marks the clear cells within `radius` of `at` as `mark`.
static func _stamp(map: Dictionary, at: Vector2, radius: float, mark: int) -> void:
	var w: int = map.w
	var d: int = map.d
	var state: PackedByteArray = map.state
	var origin: Vector2 = map.origin
	var lo := ((at-Vector2.ONE*radius-origin)/CELL).floor()
	var hi := ((at+Vector2.ONE*radius-origin)/CELL).ceil()
	for j in range(maxi(0,int(lo.y)),mini(d,int(hi.y)+1)):
		for i in range(maxi(0,int(lo.x)),mini(w,int(hi.x)+1)):
			var k := j*w+i
			if state[k] != CLEAR and not (mark == BLOCKED and state[k] == NEAR_SHORE): continue
			var c := origin+Vector2(i+0.5,j+0.5)*CELL
			if c.distance_squared_to(at) <= radius*radius: state[k] = mark
	map.state = state

## The cell state at a plate point, OFF outside the grid.
static func state_at(map: Dictionary, p: Vector2) -> int:
	var c := ((p-(map.origin as Vector2))/CELL).floor()
	if c.x < 0 or c.y < 0 or c.x >= int(map.w) or c.y >= int(map.d): return OFF
	return (map.state as PackedByteArray)[int(c.y)*int(map.w)+int(c.x)]

## The ground's height at a plate point from the grid, or NAN off the land.
static func height_at(map: Dictionary, p: Vector2) -> float:
	var c := ((p-(map.origin as Vector2))/CELL).floor()
	if c.x < 0 or c.y < 0 or c.x >= int(map.w) or c.y >= int(map.d): return NAN
	return (map.h as PackedFloat32Array)[int(c.y)*int(map.w)+int(c.x)]

## The landing strip: `wind` the way the wind blows (plate XZ, any length,
## ZERO for none), `from` where the plane is and `way` the way it is
## heading (plate XZ). Returns {touch, end, dir: Vector2, length (touch to
## end), bump, score, fallback: bool, hop: bool} in plate XZ.
static func pick(map: Dictionary, wind := Vector2.ZERO, from := Vector2.INF, way := Vector2.ZERO) -> Dictionary:
	return candidates(map,wind,from,way,1)[0]

## The best `count` strips, best first, no two alike (as `pick`). A short
## hop when no run makes a strip; never empty.
static func candidates(map: Dictionary, wind := Vector2.ZERO, from := Vector2.INF, way := Vector2.ZERO, count := 6) -> Array:
	var origin: Vector2 = map.origin
	var size := Vector2(int(map.w),int(map.d))*CELL
	var middle := origin+size*0.5
	var radius := size.length()*0.5
	var into := -wind.normalized() if wind.length() > 0.01 else Vector2.ZERO
	var all := []
	for a in range(ANGLES):
		var dir := Vector2.from_angle(PI*a/ANGLES)
		var across := Vector2(-dir.y,dir.x)
		var c := -radius
		while c <= radius:
			for run in _runs(map,middle+across*c,dir,radius):
				for sense in [1.0,-1.0]:
					var strip := _strip(map,run,dir*sense,sense < 0.0)
					if strip.is_empty(): continue
					strip.score = _score(strip,into,from,way)
					all.append(strip)
			c += LINE_GAP
	all.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.score) > float(y.score))
	var out := []
	for strip: Dictionary in all:
		if float(strip.length) < SHORT_RUN-TOUCH_IN-END_IN: continue
		var alike := false
		for kept: Dictionary in out:
			if (kept.touch as Vector2).distance_to(strip.touch) < 3.0 and (kept.dir as Vector2).dot(strip.dir) > 0.95: alike = true
		if alike: continue
		strip.hop = float(strip.length) < MIN_RUN-TOUCH_IN-END_IN
		out.append(strip)
		if out.size() >= count: break
	# No run long enough even for a short hop: the clearest spot.
	if out.is_empty(): out.append(_hop(map,into,way))
	return out

## The clear runs along a line through `through` the way `dir`, within
## `radius` of it, as [start point, end point]. A climb steeper than GRADE
## between two cells breaks a run there.
static func _runs(map: Dictionary, through: Vector2, dir: Vector2, radius: float) -> Array:
	var out := []
	var w: int = map.w
	var d: int = map.d
	var state: PackedByteArray = map.state
	var heights: PackedFloat32Array = map.h
	var origin: Vector2 = map.origin
	var start := INF
	var last := NAN
	var t := -radius
	while t <= radius+CELL:
		var ok := false
		var h := NAN
		if t <= radius:
			var c := ((through+dir*t-origin)/CELL).floor()
			if c.x >= 0 and c.y >= 0 and c.x < w and c.y < d:
				var k := int(c.y)*w+int(c.x)
				ok = state[k] == CLEAR
				h = heights[k]
		if ok and start != INF and absf(h-last) > GRADE*CELL:
			out.append([through+dir*start,through+dir*(t-CELL)])
			start = t
		elif ok and start == INF:
			start = t
		elif not ok and start != INF:
			out.append([through+dir*start,through+dir*(t-CELL)])
			start = INF
		last = h
		t += CELL
	return out

## A strip from a run's two ends, flown `dir` (from the end that is behind).
static func _strip(map: Dictionary, run: Array, dir: Vector2, backwards: bool) -> Dictionary:
	var a: Vector2 = run[1] if backwards else run[0]
	var b: Vector2 = run[0] if backwards else run[1]
	var whole := a.distance_to(b)
	if whole < SHORT_RUN-0.01: return {}
	var touch := a+dir*TOUCH_IN
	var end := b-dir*END_IN
	# The bumps: the furthest the ground strays from a straight line.
	var ha := height_at(map,touch)
	var hb := height_at(map,end)
	var bump := 0.0
	var n := maxi(2,int(whole/CELL))
	for i in range(n+1):
		var u := float(i)/n
		var h := height_at(map,a.lerp(b,u))
		if not is_nan(h): bump = maxf(bump,absf(h-lerpf(ha,hb,clampf((u*whole-TOUCH_IN)/maxf(whole-TOUCH_IN-END_IN,0.01),0.0,1.0))))
	return {"touch":touch,"end":end,"dir":dir,"length":touch.distance_to(end),"bump":bump,"fallback":false,"hop":false,"score":0.0}

static func _score(strip: Dictionary, into: Vector2, from: Vector2, way: Vector2) -> float:
	var length: float = strip.length
	var score := minf(length,IDEAL)+0.1*maxf(length-IDEAL,0.0)-BUMP*float(strip.bump)
	var dir: Vector2 = strip.dir
	if into != Vector2.ZERO: score += WIND*dir.dot(into)
	if way.length() > 0.01: score += ON_WAY*dir.dot(way.normalized())
	if from != Vector2.INF:
		# Coming at it from in front of its threshold is easier than past it.
		var to := (strip.touch as Vector2)-from
		if to.length() > 0.01: score += ON_WAY*0.5*dir.dot(to.normalized())
	return score

## No strip: a short hop onto the clearest cell nearest the land's middle,
## facing into the wind or on the plane's way; failing every cell, the
## middle of whatever land there is.
static func _hop(map: Dictionary, into: Vector2, way: Vector2) -> Dictionary:
	var w: int = map.w
	var d: int = map.d
	var state: PackedByteArray = map.state
	var origin: Vector2 = map.origin
	var sum := Vector2.ZERO
	var count := 0
	for j in range(d):
		for i in range(w):
			if state[j*w+i] != OFF:
				sum += origin+Vector2(i+0.5,j+0.5)*CELL
				count += 1
	var middle := sum/count if count > 0 else origin+Vector2(w,d)*CELL*0.5
	var best := Vector2.INF
	for k in range(w*d):
		if state[k] != CLEAR: continue
		var p := origin+Vector2(k%w+0.5,k/w+0.5)*CELL
		if best == Vector2.INF or p.distance_squared_to(middle) < best.distance_squared_to(middle): best = p
	var dir := into if into != Vector2.ZERO else (way.normalized() if way.length() > 0.01 else Vector2(0.0,-1.0))
	var at := best if best != Vector2.INF else middle
	var hop := minf(HOP,maxf(0.5,clear_ahead(map,at,dir,HOP)))
	return {"touch":at-dir*hop*0.5,"end":at+dir*hop*0.5,"dir":dir,"length":hop,"bump":0.0,"fallback":true,"hop":true,"score":-INF}

## How far from `at` the way `dir` stays clear, up to `most` m.
static func clear_ahead(map: Dictionary, at: Vector2, dir: Vector2, most: float) -> float:
	var t := CELL
	while t <= most:
		if state_at(map,at+dir*t) != CLEAR: return t-CELL
		t += CELL
	return most

## A takeoff run from where the plane stands, `heading` the way it faces
## (plate XZ): {dir, length, edge: bool (it runs off the shore)}. Clear or
## by-the-shore cells are runway; a blocked cell stops it; land's end lets
## it fly off. The plane's own spot is never in its way.
static func takeoff(map: Dictionary, at: Vector2, heading: Vector2, wind := Vector2.ZERO) -> Dictionary:
	var into := -wind.normalized() if wind.length() > 0.01 else Vector2.ZERO
	var best := {}
	for k in range(24):
		var dir := Vector2.from_angle(TAU*k/24.0)
		var t := CELL
		var edge := false
		var most := 60.0
		while t < most:
			var s := state_at(map,at+dir*t)
			if s == OFF:
				edge = true
				break
			if s == BLOCKED and t > HALF_SPAN: break
			t += CELL
		var length := t-CELL
		var score := minf(LIFT_RUN if edge else length,LIFT_RUN)*2.0+(1.5 if edge else 0.0)+WIND*0.5*dir.dot(into)+ON_WAY*dir.dot(heading.normalized())
		if best.is_empty() or score > float(best.score): best = {"dir":dir,"length":length,"edge":edge,"score":score}
	return best

## How the plane stands parked at `at` (plate XZ) facing `heading` (the
## scene's yaw): Vector4(the flight position's height, pitch, roll, the
## ground under the wheels), so its wheels and tail skid sit on the ground
## `height` (Callable(Vector2) -> float) gives.
static func rest(height: Callable, at: Vector2, heading: float) -> Vector4:
	var forward := Vector2(-sin(heading),-cos(heading))
	var right := Vector2(cos(heading),-sin(heading))
	var left_h := float(height.call(at+forward*WHEEL-right*WHEEL_GAUGE))
	var right_h := float(height.call(at+forward*WHEEL+right*WHEEL_GAUGE))
	var tail_h := float(height.call(at-forward*TAIL))
	var wheels := (left_h+right_h)*0.5
	var pitch := REST_PITCH+atan2(wheels-tail_h,WHEEL+TAIL)
	var roll := clampf(atan2(left_h-right_h,WHEEL_GAUGE*2.0),-0.35,0.35)
	return Vector4(wheels+contact(pitch),pitch,roll,wheels)

## How far over the ground under its wheels the flight's position stands
## when they touch, at `pitch`.
static func contact(pitch: float) -> float:
	return FIGURE_DROP+WHEEL_DROP*cos(pitch)-WHEEL*sin(pitch)
