extends RefCounted
## The giants' city's colonnade (giant_city.gd has the contract): the kit's
## slalom. Rows of figure-columns stand across the line, each figure bearing an
## entablature on its head and raised hands. The rows' spacing is uneven and each
## row's openings sit somewhere else, so the line banks one way then the other.
##
## Two lines through, both in ROWS: `wide` by the biggest gap of each row, `tight`
## by the narrow bay of each. Height is the third move. The kneelers' beam is low:
## the wide line hops it and the tight line ducks it. Where a beam has fallen the
## wide line stays high over the heap, and the last row's has gone, so it leaves
## with the sky open; the last tight bay is a window between a heap and the beam
## still standing. Over the top is open as well.

const Shapes = preload("res://scripts/endless/city/city_shapes.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const DEEP := 60.0

const REACH := 350.0
const STAND := 0
const KNEEL := 1
## The rows, in flying order: `z`, `kind`, the figures' `xs` but for the tight bay's
## two (`tight` sets those), each line's Vector2(x, y), `down` (an x in each span
## whose beam has fallen) and `heap` (x -> how tall a heap stands in that span).
const ROWS: Array[Dictionary] = [
	{"z":-270.0,"kind":STAND,"xs":[-170.0,-128.0,-56.0,-14.0,30.0,72.0,172.0],
		"wide":Vector2(-92.0,28.0),"tight":Vector2(120.0,20.0),"down":[10.0],"heap":{}},
	{"z":-170.0,"kind":STAND,"xs":[-160.0,-118.0,-76.0,-4.0,110.0,152.0],
		"wide":Vector2(-40.0,28.0),"tight":Vector2(50.0,18.0),"down":[88.0],"heap":{}},
	{"z":-40.0,"kind":KNEEL,"xs":[-140.0,-96.0,-52.0,-8.0,36.0,76.0,170.0],
		"wide":Vector2(-88.0,41.0),"tight":Vector2(125.0,13.0),"down":[-30.0],"heap":{}},
	{"z":45.0,"kind":STAND,"xs":[-160.0,-120.0,-78.0,-6.0,104.0,150.0],
		"wide":Vector2(-42.0,38.0),"tight":Vector2(46.0,18.0),"down":[-42.0],"heap":{-42.0:16.0}},
	{"z":165.0,"kind":STAND,"xs":[-173.0,-131.0,-59.0,-16.0,28.0,70.0,172.0],
		"wide":Vector2(-95.0,28.0),"tight":Vector2(120.0,18.0),"down":[-38.0],"heap":{}},
	{"z":270.0,"kind":STAND,"xs":[-160.0,-120.0,-78.0,-6.0,104.0,148.0],
		"wide":Vector2(-42.0,30.0),"tight":Vector2(44.0,33.0),"down":[-42.0,126.0],"heap":{44.0:24.0}},
]
## The tight bay's clear width at the shoulders: toy width (WorldScale `opening`).
const TOY_BAY := 7.0
## A standing figure: half widths, half depth, and the heights of its courses.
const FOOT := 10.0
const HIP := 7.5
const WAIST := 5.5
const CHEST := 8.0
const SHOULDER := 9.5
const DEPTH := 5.0
const LEG_TO := 17.0
const HIP_TO := 20.0
const CHEST_TO := 31.0
const SHOULDER_TO := 34.0
const STAND_TALL := 38.5
## A kneeler, lower and slighter.
const KNEEL_SHOULDER := 8.5
const KNEEL_TALL := 20.0
## What each carries: the cap on its head, then the entablature's architrave,
## frieze and cornice (height, half depth).
const CAP_TALL := 2.5
const ARCHITRAVE := Vector2(2.5,5.5)
const FRIEZE := Vector2(3.5,5.0)
const CORNICE := Vector2(2.0,7.0)

static func build(s: Shapes) -> void:
	var stand := _standing()
	var kneel := _kneeling()
	var heaps := {}
	for r: Dictionary in ROWS:
		var xs := figures(r)
		var z := float(r.z)
		var kneels := int(r.kind) == KNEEL
		var under := (KNEEL_TALL if kneels else STAND_TALL)+CAP_TALL
		var half := KNEEL_SHOULDER if kneels else SHOULDER
		for x: float in xs:
			s.stamp(kneel if kneels else stand,Vector3(x,0.0,z))
			s.layer = Shapes.FAR
			s.slope(Rect2(x-half-1.0,z-DEPTH-1.0,(half+1.0)*2.0,(DEPTH+1.0)*2.0),Rect2(x-half,z-DEPTH,half*2.0,DEPTH*2.0),-DEEP,under)
		var run := 0
		for i in xs.size()-1:
			if _fallen(r,xs[i],xs[i+1]):
				_beam(s,xs[run],xs[i],z,under)
				run = i+1
		_beam(s,xs[run],xs[xs.size()-1],z,under)
		for at: float in (r.heap as Dictionary):
			var tall := float(r.heap[at])
			if not heaps.has(tall): heaps[tall] = _heap(tall)
			s.stamp(heaps[tall],Vector3(at,0.0,z),0.3 if at > 0.0 else -0.25)
			s.layer = Shapes.FAR
			s.box(Vector3(at-9.0,-DEEP,z-7.0),Vector3(at+9.0,tall*0.7,z+7.0))
	s.layer = Shapes.BOTH

## A row's figures, left to right, the tight bay's two with them.
static func figures(r: Dictionary) -> Array[float]:
	var half := SHOULDER if int(r.kind) == STAND else KNEEL_SHOULDER
	var x := float((r.tight as Vector2).x)
	var post := WorldScale.opening(TOY_BAY)*0.5+half
	var xs: Array[float] = [x-post,x+post]
	for q: float in r.xs: xs.append(q)
	xs.sort()
	return xs

## Whether the span from `from` to `to` lost its beam.
static func _fallen(r: Dictionary, from: float, to: float) -> bool:
	for x: float in r.down:
		if x > from and x < to: return true
	return false

## A run of entablature, figure `from` to figure `to`, its foot at `y`: near as
## its three bands, far as one.
static func _beam(s: Shapes, from: float, to: float, z: float, y: float) -> void:
	if to <= from: return
	var y0 := y
	s.layer = Shapes.NEAR
	for band: Vector2 in [ARCHITRAVE,FRIEZE,CORNICE]:
		s.box(Vector3(from-SHOULDER,y0,z-band.y),Vector3(to+SHOULDER,y0+band.x,z+band.y))
		y0 += band.x
	s.layer = Shapes.FAR
	s.box(Vector3(from-SHOULDER,y,z-CORNICE.y),Vector3(to+SHOULDER,y0,z+CORNICE.y))

static func _near() -> Shapes:
	var b := Shapes.new()
	b.layer = Shapes.NEAR
	return b

static func _rect(half: float, depth: float) -> Rect2:
	return Rect2(-half,-depth,half*2.0,depth*2.0)

## Upright, legs a stride apart, raised hands either side of the head.
static func _standing() -> Shapes:
	var f := _near()
	f.box(Vector3(-FOOT,-DEEP,-DEPTH-2.0),Vector3(FOOT,3.0,DEPTH+2.0))
	for side: float in [-1.0,1.0]:
		var inner := 0.7
		var low := Rect2(minf(inner*side,(FOOT-1.0)*side),-DEPTH-0.5,FOOT-1.0-inner,(DEPTH+0.5)*2.0)
		var high := Rect2(minf(inner*side,HIP*side),-DEPTH,HIP-inner,DEPTH*2.0)
		f.slope(low,high,3.0,LEG_TO)
	f.box(Vector3(-HIP-0.5,LEG_TO,-DEPTH-0.5),Vector3(HIP+0.5,HIP_TO,DEPTH+0.5))
	f.slope(_rect(WAIST,DEPTH-1.0),_rect(CHEST,DEPTH-0.5),HIP_TO,CHEST_TO)
	f.box(Vector3(-SHOULDER,CHEST_TO,-DEPTH+0.5),Vector3(SHOULDER,SHOULDER_TO,DEPTH-0.5))
	_crown(f,SHOULDER_TO,STAND_TALL,SHOULDER)
	return f

## Knee on a block, the other leg folded under him: broad low, slight above.
static func _kneeling() -> Shapes:
	var f := _near()
	f.box(Vector3(-KNEEL_SHOULDER-1.0,-DEEP,-DEPTH-3.0),Vector3(KNEEL_SHOULDER+1.0,3.0,DEPTH+3.0))
	f.slope(_rect(KNEEL_SHOULDER,DEPTH+1.5),_rect(HIP-1.5,DEPTH),3.0,7.0)
	f.slope(_rect(WAIST-0.5,DEPTH-1.0),_rect(KNEEL_SHOULDER-1.0,DEPTH-0.5),7.0,14.0)
	f.box(Vector3(-KNEEL_SHOULDER,14.0,-DEPTH+0.5),Vector3(KNEEL_SHOULDER,16.0,DEPTH-0.5))
	_crown(f,16.0,KNEEL_TALL,KNEEL_SHOULDER)
	return f

## Head, the raised forearms by it, and the cap on them, from `y0`, the hands
## reaching `y1`.
static func _crown(f: Shapes, y0: float, y1: float, half: float) -> void:
	f.box(Vector3(-2.6,y0,-3.0),Vector3(2.6,y1,3.0))
	for side: float in [-1.0,1.0]:
		var x := minf((half-3.0)*side,(half-0.5)*side)
		f.box(Vector3(x,y0,-2.2),Vector3(x+2.5,y1,2.2))
	f.box(Vector3(-half-0.5,y1,-DEPTH-0.5),Vector3(half+0.5,y1+CAP_TALL,DEPTH+0.5))

## A heap of fallen entablature, its stones stepping to `tall`.
static func _heap(tall: float) -> Shapes:
	var h := _near()
	h.box(Vector3(-11.0,-DEEP,-7.0),Vector3(9.0,tall*0.45,7.0))
	h.box(Vector3(-6.0,tall*0.45,-5.5),Vector3(10.0,tall*0.75,6.0))
	h.box(Vector3(-8.0,tall*0.75,-4.0),Vector3(4.0,tall,4.0))
	return h
