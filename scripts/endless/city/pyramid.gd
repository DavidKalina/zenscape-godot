extends RefCounted
## The city's pyramid, its landmark (giant_city.gd has the contract): six sloped,
## corniced terraces, a stair of 7.5 m treads up the face and down the back, and a
## Greek colonnade on top, open to the sky down its middle aisle.
##
## Two lines through, both ending in the dive down the back stair:
## - Wide: up the stair between its balustrades, level across the forecourt, along
##   the colonnade's middle aisle, off the back.
## - Tight: a corbelled door at the stair's foot, a passage into the mass, then a
##   leaning well: pull up hard in the dark and go up it at the plane's steepest
##   climb, out between the columns and through the open roof. Miss the pull and
##   the passage ends in stone. The colonnade's side aisles are a tight way too.

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

## The door and passage: a floor over the land's rise under the piece, toy widths
## at the floor and the head, stepping in over DOOR_COURSES.
const FLOOR := 10.0
const DOOR_TALL := 22.0
const TOY_DOOR := 10.0
const TOY_DOOR_HEAD := 4.0
const DOOR_COURSES := 4
## The well: half widths, where its middle comes through the deck, and its lean,
## the plane's steepest climb on Boost.
const WELL_X := 12.0
const WELL_Z := 30.0
const WELL_DECK := -47.0
const WELL_LEAN := 1.2

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

## The door's half width at `y`, 0 outside it.
static func door(y: float) -> float:
	if y < FLOOR or y >= FLOOR+DOOR_TALL: return 0.0
	var course := floorf((y-FLOOR)/DOOR_TALL*DOOR_COURSES)
	return lerpf(WorldScale.opening(TOY_DOOR),WorldScale.opening(TOY_DOOR_HEAD),course/(DOOR_COURSES-1.0))*0.5

## The well's middle in z at `y`.
static func well(y: float) -> float:
	return WELL_DECK+(y-deck())/tan(WELL_LEAN)

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

static func _door_cuts() -> Array[float]:
	var out: Array[float] = []
	for i in DOOR_COURSES+1: out.append(FLOOR+DOOR_TALL*i/DOOR_COURSES)
	return out

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
		var cuts: Array[float] = [y,head]
		for c: float in _door_cuts():
			if c > y and c < head: cuts.append(c)
		cuts.sort()
		for i in cuts.size()-1:
			var a := (cuts[i]-y)
			var b := (cuts[i+1]-y)
			out.append({"y0":cuts[i],"y1":cuts[i+1],"x":Vector2(x-a*lean.x,x-b*lean.x),"z":Vector2(z-a*lean.y,z-b*lean.y)})
		var ox := x-(RISE-CORNICE_TALL)*lean.x+CORNICE_OUT
		var oz := z-(RISE-CORNICE_TALL)*lean.y+CORNICE_OUT
		out.append({"y0":head,"y1":y+RISE,"x":Vector2(ox,ox),"z":Vector2(oz,oz)})
	out.append({"y0":top(),"y1":deck(),"x":Vector2(STYLO_X,STYLO_X),"z":Vector2(STYLO_Z,STYLO_Z)})
	return out

static func _hex(s: Shapes, x0: Vector2, x1: Vector2, z0: Vector2, z1: Vector2, y0: float, y1: float) -> void:
	s.slope(Rect2(x0.x,z0.x,x1.x-x0.x,z1.x-z0.x),Rect2(x0.y,z0.y,x1.y-x0.y,z1.y-z0.y),y0,y1)

## One band less the well and, where it reaches, the passage: its front (either
## side of the door), the two walls of the well, its back. Every edge leans from
## its place at y0 to its place at y1.
static func _band(s: Shapes, b: Dictionary) -> void:
	var y0: float = b.y0
	var y1: float = b.y1
	var hx: Vector2 = b.x
	var hz: Vector2 = b.z
	if y1 <= FLOOR:
		_hex(s,-hx,hx,-hz,hz,y0,y1)
		return
	var lo := Vector2(well(y0)-WELL_Z,well(y1)-WELL_Z)
	var hi := Vector2(well(y0)+WELL_Z,well(y1)+WELL_Z)
	var d := door((y0+y1)*0.5)
	if d > 0.0:
		_hex(s,-hx,Vector2(-d,-d),-hz,lo,y0,y1)
		_hex(s,Vector2(d,d),hx,-hz,lo,y0,y1)
	else:
		_hex(s,-hx,hx,-hz,lo,y0,y1)
	var w := Vector2(WELL_X,WELL_X)
	_hex(s,-hx,-w,lo,hi,y0,y1)
	_hex(s,w,hx,lo,hi,y0,y1)
	_hex(s,-hx,hx,hi,hz,y0,y1)

## A stair: `side` -1 up the front, 1 down the back. The front's is cut by the door.
static func _stair(s: Shapes, side: float) -> void:
	for i in treads():
		var y0 := i*TREAD if i > 0 else -DEEP
		var y1 := (i+1)*TREAD
		var nose := STAIR_FOOT-i*tread_deep()
		var near_z := -nose if side < 0.0 else nose-STAIR_BACK
		var far_z := near_z+STAIR_BACK
		var cuts: Array[float] = [y0,y1]
		if side < 0.0:
			for c: float in _door_cuts():
				if c > y0 and c < y1: cuts.append(c)
			cuts.sort()
		for j in cuts.size()-1:
			var d := door((cuts[j]+cuts[j+1])*0.5) if side < 0.0 else 0.0
			if d > 0.0:
				s.box(Vector3(-STAIR_X,cuts[j],near_z),Vector3(-d,cuts[j+1],far_z))
				s.box(Vector3(d,cuts[j],near_z),Vector3(STAIR_X,cuts[j+1],far_z))
			else:
				s.box(Vector3(-STAIR_X,cuts[j],near_z),Vector3(STAIR_X,cuts[j+1],far_z))
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
	for b: Dictionary in _bands(): _band(s,b)
	_stair(s,-1.0)
	_stair(s,1.0)
	_roof(s)
	s.layer = Shapes.FAR
	_far(s)
	s.layer = Shapes.BOTH
	_base(s)
	var row := _row()
	for i in ROWS:
		s.stamp(row,Vector3(0.0,0.0,(i-(ROWS-1)*0.5)*ROW_STEP))
