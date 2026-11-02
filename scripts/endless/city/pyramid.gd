extends RefCounted
## The city's pyramid, its landmark (giant_city.gd has the contract): six sloped,
## corniced terraces, a stair of 7.5 m treads up the face and down the back, and a
## Greek colonnade on top, open to the sky down its middle aisle.
##
## Over it: up the stair between its balustrades, level across the forecourt, along
## the colonnade's middle aisle or a side aisle, off the back.
##
## It's hollow (`rooms`, plan in tall halls and long galleries), and every way in it
## comes out somewhere else:
## - Wide, about 18 s: the great corbelled door in the stair's foot, the hall, left or
##   right at the cross, down a side gallery that steps up halfway, round the back hall,
##   into the shaft heading back the way you came, climbing to the opening high in its
##   far wall, round the upper galleries and out through the back stair.
## - Tight: the needle, slits past the stair, into the shaft, out of it and out of the
##   back hall all on one line, sky at the end of it. Or from the shaft, an arch in its
##   wall and the window in line with it, out of the side. The gallery ends and the low
##   windows let you out early.
## - Up: anywhere in the shaft, a turn or two up its walls and out of the vault through
##   the open aisle between the columns.

const Shapes = preload("res://scripts/endless/city/city_shapes.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const REACH := 290.0
const DEEP := 40.0

## What it stands on where its hill falls away: a floor at the origin, so the row's
## `lift` sets it just over the hilltop, half sizes past the stair's foot, and
## courses down from it, each {rise, step out}, the last taken on to -BASE_DEEP.
const FLOOR_X := 192.0
const FLOOR_Z := 212.0
const BASE_COURSES: Array[Vector2] = [Vector2(10.0,7.0),Vector2(10.0,7.0)]
const BASE_DEEP := 130.0
## How much of the terraces' lean the last, long course keeps: steep, so the hill
## reads under it.
const LAST_BATTER := 0.25

## The terraces: how many, each one's rise, the half sizes at the foot and on top.
## Of each course's step in, BATTER_SHARE is slope and the rest ledge.
const COURSES := 6
const RISE := 15.0
const FOOT_X := 186.0
const FOOT_Z := 190.0
const TOP_X := 66.0
const TOP_Z := 100.0
const BATTER_SHARE := 0.75
const CORNICE_TALL := 1.5
const CORNICE_OUT := 1.2

## The stair: two treads to a terrace, from its foot, proud of the terraces, to the
## top of the mass. Its slope is the plane's climb up it.
const TREAD := 7.5
const STAIR_FOOT := 205.0
const STAIR_X := 28.0
const BALUSTRADE := 4.0
const BALUSTRADE_TALL := 4.5
## How far a tread's block runs back into the mass: past the terrace face, short of
## the well.
const STAIR_BACK := 20.0

## How far under the origin the far mesh's ramp starts.
const FAR_FOOT := 2.0

## The rooms (`rooms`): the floor, over the land's rise under them (15.5, and 18.4 at
## the back), how far a corbel's course steps in and rises.
const FLOOR := 16.5
const STEP_IN := 3.0
const STEP_UP := 2.8
## Toy widths: the great door's and a gallery's are sized to be seen, not threaded.
const TOY_SLIT := 5.0
const TOY_WINDOW := 4.0
const DOOR_X := 22.0
const DOOR_HEAD := 48.0
## The lower ring: the galleries' x, the cross's z, the back hall's z, the ring's head
## at the front and, past the step, at the back, and where the floor steps up.
const LOW_X := Vector2(72.0,106.0)
const CROSS_Z := Vector2(-132.0,-98.0)
const BACK_Z := Vector2(88.0,122.0)
const LOW_HEAD := 48.0
const STEP_FLOOR := 20.0
const STEP_HEAD := 52.0
const STEP_AT := -4.0
## The shaft: half sizes, where its vault starts, how many courses, the neck that opens
## on the aisle between the columns.
const SHAFT_X := 44.0
const SHAFT_Z := 54.0
const VAULT_AT := 74.0
const VAULT_COURSES := 4
const NECK_X := 14.0
const NECK_Z := 50.0
## The upper ring, over the lower: its floor and head, x, the near and far z.
const UP_FLOOR := 58.0
const UP_HEAD := 84.0
const UP_X := Vector2(52.0,76.0)
const UP_Z := Vector2(62.0,98.0)
const OPENING_X := 34.0
const EXIT_X := 24.0
## The shaft's side walls have arches, in line with the upper windows: z, width.
const ARCHES: Array[float] = [-40.0,0.0,40.0]
const ARCH_WIDE := 12.0
## The needle's x and its floor and head (in the shaft's height, all the way through);
## a window's z in the galleries.
const SLIT_X := 38.0
const NEEDLE := Vector2(20.0,40.0)
const WINDOWS_LOW: Array[float] = [-90.0,-30.0,40.0,100.0]
const WINDOWS_UP: Array[float] = ARCHES
const WINDOW_Z := 60.0
## Bays open on the +x face: x, z0, z1, floor. The wide arch from the high one.
const SUN_BAYS: Array[Vector4] = [Vector4(105.0,-72.0,-30.0,20.0),Vector4(105.0,28.0,70.0,28.0),Vector4(75.0,18.0,60.0,60.0)]
const SUN_BAY_TALL := 20.0
const SUN_ARCH := Vector2(-12.0,26.0)
const OUT := 320.0

## The stylobate the colonnade stands on; the forecourt each end of the temple is
## where the plane levels off the stair.
const STYLOBATE := 3.0
const STYLO_X := 60.0
const STYLO_Z := 94.0
## The colonnade: column radii, height with its capital, the middle aisle's clear
## width, the side aisles' toy width, how many columns across (even) and in a row,
## their spacing along z.
const COLUMN_FOOT := 3.2
const COLUMN_TOP := 2.6
const COLUMN_TALL := 28.0
const CAPITAL := 2.0
const MIDDLE_AISLE := 28.0
const TOY_AISLE := 5.5
const ACROSS := 6
const ROWS := 8
const ROW_STEP := 16.0
## What the columns carry: entablature, cornice, the end attics stepping in.
const BEAM := 6.0
const ROOF_CORNICE := 2.0
const ROOF_OUT := 2.0
## The band of roof over each end of the open aisle.
const END_BEAM := 6.0
const ATTICS: Array[Vector2] = [Vector2(0.72,3.0),Vector2(0.42,3.0)]

## The pieces `_cut` is still carrying up, Vector4 -> {y0, y}.
static var _open := {}

static func top() -> float:
	return COURSES*RISE

static func deck() -> float:
	return top()+STYLOBATE

static func treads() -> int:
	return roundi(top()/TREAD)

static func tread_deep() -> float:
	return (STAIR_FOOT-TOP_Z)/treads()

## The stair's nose, |z|, at height `y`.
static func stair_at(y: float) -> float:
	return STAIR_FOOT-y/TREAD*tread_deep()

## The columns' x, low to high.
static func column_xs() -> Array[float]:
	var out: Array[float] = []
	var at := MIDDLE_AISLE*0.5+COLUMN_FOOT
	var step := COLUMN_FOOT*2.0+WorldScale.opening(TOY_AISLE)
	for i in ACROSS/2:
		out.push_front(-at)
		out.push_back(at)
		at += step
	return out

## A room: `r` (x, z) from y0 to y1, its head stepping in along `along_x`'s axis over
## `courses`, as a corbel does.
static func _vault(out: Array[Dictionary], r: Rect2, y0: float, y1: float, across_x: bool, courses := 3) -> void:
	var spring := y1-courses*STEP_UP
	out.append({"r":r,"y0":y0,"y1":spring})
	for i in courses:
		var inset := (i+1.0)*STEP_IN
		var q := r.grow_individual(-inset,0.0,-inset,0.0) if across_x else r.grow_individual(0.0,-inset,0.0,-inset)
		out.append({"r":q,"y0":spring+i*STEP_UP,"y1":spring+(i+1)*STEP_UP})

static func _span(x0: float, x1: float, z0: float, z1: float) -> Rect2:
	return Rect2(minf(x0,x1),minf(z0,z1),absf(x1-x0),absf(z1-z0))

## What's hollow, as {r: Rect2 (x, z), y0, y1}.
static func rooms() -> Array[Dictionary]:
	var o: Array[Dictionary] = []
	var slit := WorldScale.opening(TOY_SLIT)*0.5
	var win := WorldScale.opening(TOY_WINDOW)*0.5
	# The great door and its hall, the cross.
	_vault(o,_span(-DOOR_X,DOOR_X,-OUT,CROSS_Z.y),FLOOR,DOOR_HEAD,true,4)
	_vault(o,_span(-LOW_X.y,LOW_X.y,CROSS_Z.x,CROSS_Z.y),FLOOR,LOW_HEAD,false)
	# The back hall, and the big way from it into the shaft.
	_vault(o,_span(-LOW_X.y,LOW_X.y,BACK_Z.x,BACK_Z.y),STEP_FLOOR,STEP_HEAD,false)
	_vault(o,_span(-OPENING_X,OPENING_X,SHAFT_Z-4.0,BACK_Z.x+4.0),STEP_FLOOR,STEP_HEAD,true)
	# The shaft and its vault, up through the neck.
	o.append({"r":_span(-SHAFT_X,SHAFT_X,-SHAFT_Z,SHAFT_Z),"y0":FLOOR,"y1":VAULT_AT})
	var up := (top()-VAULT_AT)/VAULT_COURSES
	for i in VAULT_COURSES:
		var f := (i+1.0)/VAULT_COURSES
		var hx := lerpf(SHAFT_X,NECK_X,f)
		var hz := lerpf(SHAFT_Z,NECK_Z,f)
		o.append({"r":_span(-hx,hx,-hz,hz),"y0":VAULT_AT+i*up,"y1":VAULT_AT+(i+1)*up})
	o.append({"r":_span(-NECK_X,NECK_X,-NECK_Z,NECK_Z),"y0":top(),"y1":deck()+1.0})
	# The high way out of the shaft, the upper ring, the door through the back stair.
	_vault(o,_span(-OPENING_X,OPENING_X,-UP_Z.x-4.0,-SHAFT_Z+4.0),UP_FLOOR,UP_HEAD,true)
	_vault(o,_span(-UP_X.y,UP_X.y,-UP_Z.y,-UP_Z.x),UP_FLOOR,UP_HEAD,false)
	_vault(o,_span(-UP_X.y,UP_X.y,UP_Z.x,UP_Z.y),UP_FLOOR,UP_HEAD,false)
	_vault(o,_span(-EXIT_X,EXIT_X,UP_Z.x,OUT),UP_FLOOR,UP_HEAD,true,4)
	# The needle: slits past the stair, into the shaft, out of it, out of the back hall,
	# all on one line, so there's sky down it.
	var ax := -SLIT_X
	for r: Rect2 in [_span(ax-slit,ax+slit,-OUT,CROSS_Z.x+1.0),_span(ax-slit,ax+slit,CROSS_Z.y-1.0,-SHAFT_Z+1.0),_span(ax-slit,ax+slit,SHAFT_Z-1.0,BACK_Z.x+1.0),_span(ax-slit,ax+slit,BACK_Z.y-1.0,OUT)]:
		_vault(o,r,NEEDLE.x,NEEDLE.y,true,1)
	for side: float in [-1.0,1.0]:
		var mid := (LOW_X.x+LOW_X.y)*0.5*side
		_vault(o,_span(side*LOW_X.x,side*LOW_X.y,CROSS_Z.x,STEP_AT),FLOOR,LOW_HEAD,true)
		_vault(o,_span(side*LOW_X.x,side*LOW_X.y,STEP_AT,BACK_Z.y),STEP_FLOOR,STEP_HEAD,true)
		_vault(o,_span(side*UP_X.x,side*UP_X.y,-UP_Z.y,UP_Z.y),UP_FLOOR,UP_HEAD,true)
		for z: float in ARCHES:
			o.append({"r":_span(side*SHAFT_X,side*UP_X.x,z-ARCH_WIDE*0.5,z+ARCH_WIDE*0.5),"y0":UP_FLOOR+2.0,"y1":UP_HEAD-8.0})
		# Light, and slits out: a gallery's end, its windows.
		_vault(o,_span(mid-slit,mid+slit,-OUT,CROSS_Z.x+1.0),FLOOR+4.0,40.0,true,1)
		for z: float in WINDOWS_LOW:
			var f0 := FLOOR if z < STEP_AT else STEP_FLOOR
			o.append({"r":_span(side*LOW_X.y-side,side*OUT,z-win,z+win),"y0":f0+10.0,"y1":f0+28.0})
		for z: float in WINDOWS_UP:
			o.append({"r":_span(side*UP_X.y-side,side*OUT,z-win,z+win),"y0":UP_FLOOR+6.0,"y1":UP_HEAD-6.0})
		o.append({"r":_span(side*WINDOW_Z-win,side*WINDOW_Z+win,-OUT,CROSS_Z.x+1.0),"y0":FLOOR+6.0,"y1":FLOOR+24.0})
		o.append({"r":_span(side*WINDOW_Z-win,side*WINDOW_Z+win,BACK_Z.y-1.0,OUT),"y0":STEP_FLOOR+10.0,"y1":STEP_FLOOR+28.0})
	# Big bays on the +x face to light the galleries, one high, by a wide arch into
	# the shaft. The great door takes the low sun down the hall.
	for b: Vector4 in SUN_BAYS:
		o.append({"r":_span(b.x,OUT,b.y,b.z),"y0":b.w,"y1":b.w+SUN_BAY_TALL})
	o.append({"r":_span(SHAFT_X,UP_X.x,SUN_ARCH.x,SUN_ARCH.y),"y0":UP_FLOOR+2.0,"y1":UP_HEAD-8.0})
	return o

static func _in_room(list: Array[Dictionary], x: float, z: float, y: float) -> bool:
	for v: Dictionary in list:
		if y > float(v.y0) and y < float(v.y1) and (v.r as Rect2).has_point(Vector2(x,z)): return true
	return false

## The cover of solid cells on a grid, `rows` first: each [i0, i1, j0, j1], cells
## i0 to i1 less one along the row and j0 to j1 less one across rows, equal runs of
## neighbouring rows joined.
static func _tiles(full: Array, cols: int, rows: int, flip: bool) -> Array:
	var out: Array = []
	var open := {}
	for j in rows:
		var now := {}
		var i := 0
		while i < cols:
			if not (full[i+j*cols] if not flip else full[j+i*rows]):
				i += 1
				continue
			var e := i
			while e < cols and (full[e+j*cols] if not flip else full[j+e*rows]): e += 1
			var key := Vector2i(i,e)
			if open.has(key):
				now[key] = open[key]
				open.erase(key)
			else: now[key] = j
			i = e
		for k: Vector2i in open: out.append([k.x,k.y,int(open[k]),j])
		open = now
	for k: Vector2i in open: out.append([k.x,k.y,int(open[k]),rows])
	return out

## The rect `a` at y0 running to `b` at y1, less the rooms: every side leans from its
## place at y0 to its place at y1, and a room's side cuts it upright. Level by level,
## and a piece that goes on unchanged into the next level stays one shape.
static func _cut(s: Shapes, list: Array[Dictionary], a: Rect2, b: Rect2, y0: float, y1: float) -> void:
	var ys: Array[float] = [y0,y1]
	for v: Dictionary in list:
		for y: float in [float(v.y0),float(v.y1)]:
			if y > y0+0.01 and y < y1-0.01 and not ys.has(y): ys.append(y)
	ys.sort()
	for n in ys.size()-1:
		var t0 := (ys[n]-y0)/(y1-y0)
		var t1 := (ys[n+1]-y0)/(y1-y0)
		var ra := Rect2(a.position.lerp(b.position,t0),a.size.lerp(b.size,t0))
		var rb := Rect2(a.position.lerp(b.position,t1),a.size.lerp(b.size,t1))
		for k: Vector4 in _level(list,ra.intersection(rb),ra.merge(rb),ys[n],ys[n+1]):
			if _open.has(k) and absf(float(_open[k].y)-ys[n]) < 0.01:
				_open[k].y = ys[n+1]
				continue
			if _open.has(k): _close(s,k,a,b,y0,y1)
			_open[k] = {"y0":ys[n],"y":ys[n+1]}
	# Pieces on the outline lean with this band, so they end with it.
	for k: Vector4 in _open.keys():
		if is_inf(k.x) or is_inf(k.y) or is_inf(k.z) or is_inf(k.w): _close(s,k,a,b,y0,y1)

## One open piece into `s`: its sides, ±INF the outline's, at its y0 and top.
static func _close(s: Shapes, k: Vector4, a: Rect2, b: Rect2, y0: float, y1: float) -> void:
	var low := float(_open[k].y0)
	var high := float(_open[k].y)
	_open.erase(k)
	var q0 := (low-y0)/(y1-y0)
	var q1 := (high-y0)/(y1-y0)
	s.slope(_piece(k,Rect2(a.position.lerp(b.position,q0),a.size.lerp(b.size,q0))),_piece(k,Rect2(a.position.lerp(b.position,q1),a.size.lerp(b.size,q1))),low,high)

static func _piece(k: Vector4, on: Rect2) -> Rect2:
	var x0 := on.position.x if is_inf(k.x) else k.x
	var x1 := on.end.x if is_inf(k.y) else k.y
	var z0 := on.position.y if is_inf(k.z) else k.z
	var z1 := on.end.y if is_inf(k.w) else k.w
	return Rect2(x0,z0,x1-x0,z1-z0)

## The solid pieces of the level y0 to y1, `inner` the rect's least, `outer` its most:
## each Vector4(x0, x1, z0, z1), -INF or INF where it runs out to the outline.
static func _level(list: Array[Dictionary], inner: Rect2, outer: Rect2, y0: float, y1: float) -> Array[Vector4]:
	var mid := (y0+y1)*0.5
	var xs: Array[float] = []
	var zs: Array[float] = []
	var here: Array[Dictionary] = []
	for v: Dictionary in list:
		if float(v.y0) >= y1 or float(v.y1) <= y0: continue
		var r: Rect2 = v.r
		if not r.intersects(outer): continue
		here.append(v)
		for x: float in [r.position.x,r.end.x]:
			if x > inner.position.x+0.01 and x < inner.end.x-0.01 and not xs.has(x): xs.append(x)
		for z: float in [r.position.y,r.end.y]:
			if z > inner.position.y+0.01 and z < inner.end.y-0.01 and not zs.has(z): zs.append(z)
	xs.sort()
	zs.sort()
	var cols := xs.size()+1
	var rows := zs.size()+1
	var full := []
	full.resize(cols*rows)
	for j in rows:
		var zc := (_line(zs,j,inner.position.y,inner.end.y)+_line(zs,j+1,inner.position.y,inner.end.y))*0.5
		for i in cols:
			var xc := (_line(xs,i,inner.position.x,inner.end.x)+_line(xs,i+1,inner.position.x,inner.end.x))*0.5
			full[i+j*cols] = not _in_room(here,xc,zc,mid)
	var by_row: Array = _tiles(full,cols,rows,false)
	var by_col: Array = _tiles(full,rows,cols,true)
	var out: Array[Vector4] = []
	var rowwise := by_row.size() <= by_col.size()
	for t: Array in (by_row if rowwise else by_col):
		var cx: Array = [t[0],t[1]] if rowwise else [t[2],t[3]]
		var cz: Array = [t[2],t[3]] if rowwise else [t[0],t[1]]
		out.append(Vector4(_line(xs,cx[0],-INF,INF),_line(xs,cx[1],-INF,INF),_line(zs,cz[0],-INF,INF),_line(zs,cz[1],-INF,INF)))
	return out

## Line `i` of the grid over `cuts`: `lo` first, `hi` last.
static func _line(cuts: Array[float], i: int, lo: float, hi: float) -> float:
	if i == 0: return lo
	if i == cuts.size()+1: return hi
	return cuts[i-1]

## The mass in level bands, low to high: {y0, y1, x (half at y0, at y1), z}.
static func _bands() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var run := Vector2(FOOT_X-TOP_X,FOOT_Z-TOP_Z)/COURSES
	var lean := run*BATTER_SHARE/(RISE-CORNICE_TALL)
	out.append({"y0":-DEEP,"y1":0.0,"x":Vector2(FOOT_X,FOOT_X),"z":Vector2(FOOT_Z,FOOT_Z)})
	for k in COURSES:
		var x := FOOT_X-k*run.x
		var z := FOOT_Z-k*run.y
		var y := k*RISE
		var head := y+RISE-CORNICE_TALL
		var b := head-y
		out.append({"y0":y,"y1":head,"x":Vector2(x,x-b*lean.x),"z":Vector2(z,z-b*lean.y)})
		var ox := x-(RISE-CORNICE_TALL)*lean.x+CORNICE_OUT
		var oz := z-(RISE-CORNICE_TALL)*lean.y+CORNICE_OUT
		out.append({"y0":head,"y1":y+RISE,"x":Vector2(ox,ox),"z":Vector2(oz,oz)})
	out.append({"y0":top(),"y1":deck(),"x":Vector2(STYLO_X,STYLO_X),"z":Vector2(STYLO_Z,STYLO_Z)})
	return out

## A stair: `side` -1 up the front, 1 down the back, cut by what passes through it.
static func _stair(s: Shapes, list: Array[Dictionary], side: float) -> void:
	for i in treads():
		var y0 := i*TREAD if i > 0 else -DEEP
		var y1 := (i+1)*TREAD
		var nose := STAIR_FOOT-i*tread_deep()
		var near_z := -nose if side < 0.0 else nose-STAIR_BACK
		var far_z := near_z+STAIR_BACK
		var r := Rect2(-STAIR_X,near_z,STAIR_X*2.0,STAIR_BACK)
		_cut(s,list,r,r,y0,y1)
		var top_y := y1+BALUSTRADE_TALL
		s.box(Vector3(-STAIR_X-BALUSTRADE,y0,near_z),Vector3(-STAIR_X,top_y,far_z))
		s.box(Vector3(STAIR_X,y0,near_z),Vector3(STAIR_X+BALUSTRADE,top_y,far_z))

## One row of the colonnade across x, stamped along z: one shared mesh.
static func _row() -> Shapes:
	var row := Shapes.new()
	row.layer = Shapes.NEAR
	var y := deck()
	var cap := COLUMN_FOOT+0.6
	for x: float in column_xs():
		row.cyl(Vector3(x,y,0.0),COLUMN_FOOT,COLUMN_TOP,COLUMN_TALL-CAPITAL,10)
		row.box(Vector3(x-cap,y+COLUMN_TALL-CAPITAL,-cap),Vector3(x+cap,y+COLUMN_TALL,cap))
	return row

## The roof's half widths: over the outer columns, out to the end rows.
static func roof_x() -> float:
	var xs := column_xs()
	return xs[xs.size()-1]+COLUMN_FOOT

static func roof_z() -> float:
	return (ROWS-1)*ROW_STEP*0.5+COLUMN_FOOT

## The roof's underside and its top.
static func roof_y() -> float:
	return deck()+COLUMN_TALL

static func crown() -> float:
	var y := roof_y()+BEAM+ROOF_CORNICE
	for a: Vector2 in ATTICS: y += a.y
	return y

## A level slab, its z both ways from `side`*a to `side`*b.
static func _end(s: Shapes, side: float, half: float, a: float, b: float, y0: float, y1: float) -> void:
	s.box(Vector3(-half,y0,minf(side*a,side*b)),Vector3(half,y1,maxf(side*a,side*b)))

## The entablature on the columns: a slab each side of the open middle, a band
## over each end, a cornice round it all, and an attic stepping in over each end.
static func _roof(s: Shapes) -> void:
	var y := roof_y()
	var x := roof_x()
	var z := roof_z()
	var open := MIDDLE_AISLE*0.5
	var ends := z-END_BEAM
	for side: float in [-1.0,1.0]:
		s.box(Vector3(minf(side*open,side*x),y,-z),Vector3(maxf(side*open,side*x),y+BEAM,z))
		_end(s,side,open,ends,z,y,y+BEAM)
	y += BEAM
	var ox := x+ROOF_OUT
	var oz := z+ROOF_OUT
	for side: float in [-1.0,1.0]:
		s.box(Vector3(minf(side*open,side*ox),y,-oz),Vector3(maxf(side*open,side*ox),y+ROOF_CORNICE,oz))
		_end(s,side,open,ends,oz,y,y+ROOF_CORNICE)
	y += ROOF_CORNICE
	for step: Vector2 in ATTICS:
		for side: float in [-1.0,1.0]: _end(s,side,x*step.x,ends,z,y,y+step.y)
		y += step.y

## The base under the floor: sloped courses with a ledge between, as the terraces.
static func _base(s: Shapes) -> void:
	var at := Vector2(FLOOR_X,FLOOR_Z)
	var y := 0.0
	for i in BASE_COURSES.size():
		var c := BASE_COURSES[i]
		var out := c.y*BATTER_SHARE
		var low := y-c.x
		if i == BASE_COURSES.size()-1:
			out *= (y+BASE_DEEP)/c.x*LAST_BATTER
			low = -BASE_DEEP
		var foot := at+Vector2.ONE*out
		s.slope(Rect2(-foot,foot*2.0),Rect2(-at,at*2.0),low,y)
		at += Vector2.ONE*c.y
		y -= c.x

## The stand-in: the terraces whole, each stair one ramp, the colonnade's column
## lines as thin walls, so the aisles still read from the front.
static func _far(s: Shapes) -> void:
	var run := Vector2(FOOT_X-TOP_X,FOOT_Z-TOP_Z)/COURSES
	for k in COURSES:
		var x := FOOT_X-k*run.x
		var z := FOOT_Z-k*run.y
		var low := -DEEP if k == 0 else k*RISE
		var inset := run*BATTER_SHARE
		s.slope(Rect2(-x,-z,x*2.0,z*2.0),Rect2(-x+inset.x,-z+inset.y,(x-inset.x)*2.0,(z-inset.y)*2.0),low,(k+1)*RISE)
	var wide := STAIR_X+BALUSTRADE
	var foot := stair_at(-FAR_FOOT)
	for side: float in [-1.0,1.0]:
		var a := minf(side*foot,side*(TOP_Z-STAIR_BACK))
		var b := maxf(side*foot,side*(TOP_Z-STAIR_BACK))
		var c := minf(side*TOP_Z,side*(TOP_Z-STAIR_BACK))
		var d := maxf(side*TOP_Z,side*(TOP_Z-STAIR_BACK))
		s.slope(Rect2(-wide,a,wide*2.0,b-a),Rect2(-wide,c,wide*2.0,d-c),-FAR_FOOT,top())
	var y := deck()
	var z := roof_z()
	s.box(Vector3(-STYLO_X,top(),-STYLO_Z),Vector3(STYLO_X,y,STYLO_Z))
	for x: float in column_xs():
		s.box(Vector3(x-COLUMN_FOOT,y,-z),Vector3(x+COLUMN_FOOT,y+COLUMN_TALL,z))
	y = roof_y()
	var rx := roof_x()
	var open := MIDDLE_AISLE*0.5
	for side: float in [-1.0,1.0]:
		s.box(Vector3(minf(side*open,side*rx),y,-z),Vector3(maxf(side*open,side*rx),y+BEAM+ROOF_CORNICE,z))
		_end(s,side,rx,z-END_BEAM,z,y,crown())

static func build(s: Shapes) -> void:
	s.layer = Shapes.NEAR
	var list := rooms()
	_open.clear()
	for b: Dictionary in _bands():
		var hx: Vector2 = b.x
		var hz: Vector2 = b.z
		_cut(s,list,Rect2(-hx.x,-hz.x,hx.x*2.0,hz.x*2.0),Rect2(-hx.y,-hz.y,hx.y*2.0,hz.y*2.0),b.y0,b.y1)
	_stair(s,list,-1.0)
	_stair(s,list,1.0)
	for k: Vector4 in _open.keys(): _close(s,k,Rect2(),Rect2(),0.0,1.0)
	_roof(s)
	s.layer = Shapes.FAR
	_far(s)
	s.layer = Shapes.BOTH
	_base(s)
	var row := _row()
	for i in ROWS:
		s.stamp(row,Vector3(0.0,0.0,(i-(ROWS-1)*0.5)*ROW_STEP))
