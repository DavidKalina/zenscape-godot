## Lift: rising air in tubes along paths, and still air everywhere else.
##
## Each path is a polyline (world points) with a radius (m) and a strength
## (m/s of rising air). Inside a tube the air rises at the strength; across
## the tube's outer EDGE share of the radius it fades to nothing; the ends
## are rounded. Outside every tube `air_at` returns {}: the plane's air is
## then exactly what no air callable gives.
##
## The plane's step (scripts/sky_plane.gd) reads the rise from the "rise"
## key as its own term, not as wind, so the calm near the land
## (scripts/manual_landing.gd `calmed`, which damps rising wind under
## CALM_HIGH m over the ground for touchdowns) leaves it alone: a slot
## climbed a few metres off its rock keeps its lift. The plane scales it by
## its own airspeed (none at its slowest, all of it SOFT_SPAN m/s faster)
## and fades it over the top of its thin band, so lift adds to a flown climb
## and does not carry a stalled plane or lift it past its ceiling.
##
## The main scene (studies/endless_flight.gd `air_lift`) owns one and passes
## `air_at` as the plane's air; `--lift=0` turns it off (no air callable, as
## before). Places add their paths by a stable name:
##   air_lift.add("peak/couloir", points, radius, strength)
extends RefCounted

## The share of a tube's radius over which its rise fades out.
const EDGE := 0.35

## name -> {points: PackedVector3Array, radius, strength, box: AABB}
var paths := {}
## Every tube's box together (a point outside it is still air at one test).
var _box := AABB()
var _any := false

## Whether lift is on: `--lift=0` (or off/false) turns it off.
static func flag(args: Variant = null) -> bool:
	var list: PackedStringArray = args if args != null else preload("res://scripts/launch_args.gd").user_args()
	for a in list:
		if a.begins_with("--lift="): return not (a.get_slice("=",1) in ["0","off","false","no"])
	return true

## Add (or replace) the path `name`: `points` world, at least one (one
## point is a ball), `radius` m, `strength` m/s of rise at its core.
func add(name: String, points: PackedVector3Array, radius: float, strength: float) -> void:
	if points.is_empty() or radius <= 0.0: return
	var box := AABB(points[0],Vector3.ZERO)
	for p in points: box = box.expand(p)
	box = box.grow(radius)
	paths[name] = {"points": points, "radius": radius, "strength": strength, "box": box}
	_rebox()

func remove(name: String) -> void:
	paths.erase(name)
	_rebox()

func clear() -> void:
	paths.clear()
	_rebox()

func _rebox() -> void:
	_any = not paths.is_empty()
	var first := true
	for k in paths:
		var b: AABB = paths[k].box
		_box = b if first else _box.merge(b)
		first = false

## The air at `p` for the plane's step: {"rise": m/s, "thermal": 0 to 1,
## the share of the strongest tube's core} inside a tube, {} outside.
func air_at(p: Vector3) -> Dictionary:
	if not _any or not _box.has_point(p): return {}
	var rise := 0.0
	var share := 0.0
	for k in paths:
		var path: Dictionary = paths[k]
		var box: AABB = path.box
		if not box.has_point(p): continue
		var radius := float(path.radius)
		var d := distance_to(path.points,p)
		if d >= radius: continue
		var s := 1.0-smoothstep(radius*(1.0-EDGE),radius,d)
		var r := float(path.strength)*s
		if r > rise:
			rise = r
			share = s
	if rise <= 0.0: return {}
	return {"rise": rise, "thermal": share}

## The distance from `p` to the polyline `points` (its nearest segment).
static func distance_to(points: PackedVector3Array, p: Vector3) -> float:
	if points.size() == 1: return p.distance_to(points[0])
	var best := INF
	for i in points.size()-1:
		var a := points[i]
		var ab := points[i+1]-a
		var len2 := ab.length_squared()
		var t := clampf((p-a).dot(ab)/len2,0.0,1.0) if len2 > 0.0 else 0.0
		best = minf(best,p.distance_to(a+ab*t))
	return best
