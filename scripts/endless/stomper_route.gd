extends RefCounted
## The stomper's walk (stomper.gd): a closed loop laid by hand on the plain over the
## lake from the road, read off the height map with the land fully streamed, then
## smoothed to a line the body can turn along. About 3.8 km, 1.6 km by 0.7, a long
## bean round a low hill, so it reads as a walk out and back, not round a pole. It
## keeps 1.7 km or more off the road and 1.9 km off the pyramid, and stands 40
## degrees or more aside of the sight line from the shore road to the pyramid. The
## same on every machine: it reads no land.
##   walked(place)          the loop; `place(at)`: LINE's (along, across) as world x, z
##   at(s) / way(s)         the point and the unit direction `s` m along it
##   nearest(p)             the `s` closest to `p`

## The corners, in the city's frame (along, across; giant_city.gd PLACED). North
## about, east end at the fin over the lake, between the two ruins at the west end.
const LINE: Array[Vector2] = [Vector2(2220.0,-960.0),Vector2(2520.0,-1010.0),Vector2(2610.0,-1300.0),Vector2(2600.0,-1760.0),Vector2(2440.0,-2020.0),
	Vector2(2340.0,-2240.0),Vector2(2360.0,-2480.0),Vector2(2390.0,-2620.0),Vector2(2250.0,-2650.0),Vector2(2100.0,-2630.0),
	Vector2(2110.0,-2420.0),Vector2(2150.0,-2220.0),Vector2(2130.0,-1960.0),Vector2(1960.0,-1600.0),Vector2(1880.0,-1200.0),
	Vector2(1990.0,-1000.0)]
## The line: its points' spacing (m), smoothing passes.
const SPACING := 40.0
const PASSES := 24

var points := PackedVector2Array()
var length := 0.0

static func walked(place: Callable) -> RefCounted:
	var route: RefCounted = (load("res://scripts/endless/stomper_route.gd") as GDScript).new()
	var raw := PackedVector2Array()
	for corner: Vector2 in LINE: raw.append(place.call(corner))
	route._line(raw)
	return route

func at(s: float) -> Vector2:
	var i := fposmod(s,length)/SPACING
	var a := int(i)%points.size()
	return points[a].lerp(points[(a+1)%points.size()],i-floorf(i))

func way(s: float) -> Vector2:
	return (at(s+60.0)-at(s-60.0)).normalized()

func nearest(p: Vector2) -> float:
	var best := INF
	var out := 0.0
	for i in range(points.size()):
		var d := points[i].distance_squared_to(p)
		if d < best:
			best = d
			out = float(i)*SPACING
	return out

## The corners as an even closed line, smoothed so the body turns, not jogs.
func _line(raw: PackedVector2Array) -> void:
	points = _even(raw)
	for pass_i in range(PASSES):
		var next := PackedVector2Array()
		next.resize(points.size())
		var n := points.size()
		for i in range(n):
			next[i] = (points[(i+n-1)%n]+points[i]*2.0+points[(i+1)%n])*0.25
		points = next
		if pass_i%10 == 9: points = _even(points)
	points = _even(points)
	length = float(points.size())*SPACING

## A closed line at SPACING.
func _even(raw: PackedVector2Array) -> PackedVector2Array:
	var total := 0.0
	var n := raw.size()
	for i in range(n): total += raw[i].distance_to(raw[(i+1)%n])
	var count := maxi(int(round(total/SPACING)),3)
	var step := total/float(count)
	var out := PackedVector2Array()
	var i := 0
	var into := 0.0
	var run := raw[0].distance_to(raw[1%n])
	for k in range(count):
		var want := float(k)*step
		while want-into > run and i < n-1:
			into += run
			i += 1
			run = raw[i].distance_to(raw[(i+1)%n])
		out.append(raw[i].lerp(raw[(i+1)%n],clampf((want-into)/maxf(run,0.001),0.0,1.0)))
	return out
