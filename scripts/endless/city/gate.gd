extends RefCounted
## The city's gate (giant_city.gd has the contract): a battered wall about 90 m
## tall to the cornice, the stomper's knee, with a door corbelled in to a flat
## lintel and an entablature over it. The first piece of the line out of the hall.
##
## Two lines through: the door, wide and high, and a slit low in the wall each
## side of it, corbelled to a narrow head, running the wall's depth. Over the top
## and round the ends are open as well.

const Shapes = preload("res://scripts/endless/city/city_shapes.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const DEEP := 60.0

const REACH := 170.0
## The door: this tall, this wide at the floor and at the head, stepping in over
## COURSES.
const DOOR_TALL := 66.0
const DOOR_FLOOR := 52.0
const DOOR_HEAD := 16.0
const COURSES := 6
## The slits: the tight line. Toy width at the floor (WorldScale `opening`), the
## narrowest head they step to, how tall, on how many courses, how far off the
## middle.
const TOY_SLIT := 6.0
const TOY_SLIT_HEAD := 3.0
const SLIT_TALL := 32.0
const SLIT_COURSES := 4
const SLIT_X := 86.0
## The wall: half its width and depth at the foot and at the top of the mass.
const WALL_TOP := 78.0
const WIDE_FOOT := 132.0
const WIDE_TOP := 116.0
const DEEP_FOOT := 30.0
const DEEP_TOP := 20.0
## The entablature on it: architrave, frieze, cornice, their heights and overhangs.
const ARCHITRAVE := Vector2(4.0,1.5)
const FRIEZE := Vector2(6.0,0.0)
const CORNICE := Vector2(3.5,4.0)
## Columns against the piers, both faces: either side of each slit.
const COLUMN_XS: Array[float] = [54.0,114.0]
const COLUMN_TALL := 56.0
const COLUMN_FOOT := 5.4
const COLUMN_TOP := 4.5

static func build(s: Shapes) -> void:
	var cuts: Array[float] = [-DEEP,WALL_TOP]
	for i in COURSES: cuts.append(DOOR_TALL*i/COURSES)
	cuts.append(DOOR_TALL)
	for i in SLIT_COURSES+1: cuts.append(SLIT_TALL*i/SLIT_COURSES)
	cuts.sort()
	s.layer = Shapes.NEAR
	for i in cuts.size()-1:
		if cuts[i+1] > cuts[i]: _band(s,cuts[i],cuts[i+1])
	s.layer = Shapes.FAR
	_far(s)
	s.layer = Shapes.BOTH
	_entablature(s)
	var column := Shapes.new()
	column.cyl(Vector3(0.0,-DEEP,0.0),COLUMN_FOOT*1.2,COLUMN_TOP,COLUMN_TALL+DEEP,12)
	column.box(Vector3(-COLUMN_TOP-1.5,COLUMN_TALL,-COLUMN_TOP-1.5),Vector3(COLUMN_TOP+1.5,COLUMN_TALL+3.0,COLUMN_TOP+1.5))
	var off := DEEP_FOOT+COLUMN_FOOT-1.0
	for x: float in COLUMN_XS:
		for side: float in [-1.0,1.0]:
			s.stamp(column,Vector3(x*side,0.0,off))
			s.stamp(column,Vector3(x*side,0.0,-off),PI)

## The wall's half width and half depth at `y`.
static func _wide(y: float) -> float:
	return lerpf(WIDE_FOOT,WIDE_TOP,clampf(y/WALL_TOP,0.0,1.0))

static func _depth(y: float) -> float:
	return lerpf(DEEP_FOOT,DEEP_TOP,clampf(y/WALL_TOP,0.0,1.0))

## The openings at `y`, low to high: Vector2(from, to) across x.
static func _openings(y: float) -> Array[Vector2]:
	var list: Array[Vector2] = []
	if y < DOOR_TALL:
		var course := floorf(clampf(y,0.0,DOOR_TALL-1.0)/DOOR_TALL*COURSES)
		var half := lerpf(DOOR_FLOOR,DOOR_HEAD,course/(COURSES-1.0))*0.5
		list.append(Vector2(-half,half))
	if y < SLIT_TALL:
		var course := floorf(clampf(y,0.0,SLIT_TALL-1.0)/SLIT_TALL*SLIT_COURSES)
		var half := lerpf(WorldScale.opening(TOY_SLIT),WorldScale.opening(TOY_SLIT_HEAD),course/(SLIT_COURSES-1.0))*0.5
		list.push_front(Vector2(-SLIT_X-half,-SLIT_X+half))
		list.push_back(Vector2(SLIT_X-half,SLIT_X+half))
	return list

## The wall between heights `y0` and `y1`, less its openings: a stack of these
## is the corbelling. The outermost run keeps the wall's batter; so do all the
## faces front and back.
static func _band(s: Shapes, y0: float, y1: float) -> void:
	var w0 := _wide(y0)
	var w1 := _wide(y1)
	var d0 := _depth(y0)
	var d1 := _depth(y1)
	var from := -1.0
	var openings := _openings((y0+y1)*0.5)
	for i in openings.size()+1:
		var gap_to: float = openings[i].x if i < openings.size() else 1.0
		var outer_low := i == 0
		var outer_high := i == openings.size()
		var x0 := from*w0 if outer_low else from
		var x1 := from*w1 if outer_low else from
		var x2 := w0 if outer_high else gap_to
		var x3 := w1 if outer_high else gap_to
		s.slope(Rect2(x0,-d0,x2-x0,d0*2.0),Rect2(x1,-d1,x3-x1,d1*2.0),y0,y1)
		if i < openings.size(): from = openings[i].y

static func _entablature(s: Shapes) -> void:
	var y := WALL_TOP
	for band: Vector2 in [ARCHITRAVE,FRIEZE,CORNICE]:
		var w := WIDE_TOP+band.y
		var d := DEEP_TOP+band.y
		s.box(Vector3(-w,y,-d),Vector3(w,y+band.x,d))
		y += band.x

## The stand-in: two battered masses and the head over the door, no slits.
static func _far(s: Shapes) -> void:
	var head := DOOR_HEAD*0.5
	var foot := DOOR_FLOOR*0.5
	for side: float in [-1.0,1.0]:
		var low := Rect2(foot,-DEEP_FOOT,WIDE_FOOT-foot,DEEP_FOOT*2.0)
		var high := Rect2(head,-_depth(DOOR_TALL),_wide(DOOR_TALL)-head,_depth(DOOR_TALL)*2.0)
		if side < 0.0:
			low.position.x = -WIDE_FOOT
			high.position.x = -_wide(DOOR_TALL)
		s.slope(low,high,-DEEP,DOOR_TALL)
	s.slope(Rect2(-_wide(DOOR_TALL),-_depth(DOOR_TALL),_wide(DOOR_TALL)*2.0,_depth(DOOR_TALL)*2.0),Rect2(-WIDE_TOP,-DEEP_TOP,WIDE_TOP*2.0,DEEP_TOP*2.0),DOOR_TALL,WALL_TOP)
