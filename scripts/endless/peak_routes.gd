## The Peak's ways up (docs/design/endless-flight/spec-peak.md), from the
## placed massif (scripts/endless/peak_massif.gd) and the land's height.
##
## The couloir: a lift up the slot from its mouth to its notch on the crest
## (the rim), and on over the rim toward the plateau, ending short of its
## flat so it never holds a landing off. It is one way (AirLift `add`
## one_way): a plane flying up the slot rides it, one flying back down the
## slot has still air.
##
## The main scene asks `couloir(peak, ground)` once the massif is placed and
## hands the lift to AirLift.add.
extends RefCounted

const PeakMassif = preload("res://scripts/endless/peak_massif.gd")

## The lift's path name (AirLift).
const LIFT := "peak/couloir"
## The lift: LIFT_OVER m over the slot's floor, LIFT_R m round, LIFT_RISE m/s
## at its core (the slot's floor climbs up to about 1.9 m per m in its
## middle; at 26 a plane flown up it by the stick on medium or heavy rides
## it to the rim, at 30 the same stick overshoots the rim). Past the rim it
## runs on toward the plateau's centre, its end LIFT_END m over the
## plateau's flat and no nearer its centre than LIFT_SHORT (the flat's
## radius plus most of the tube's).
const LIFT_OVER := 40.0
const LIFT_R := 60.0
const LIFT_RISE := 26.0
const LIFT_END := 40.0
const LIFT_SHORT := 230.0

## The couloir's lift: {name, points, radius, strength, one_way}. `ground`:
## the land's height (world y) at (x, z).
static func couloir(peak: RefCounted, ground: Callable) -> Dictionary:
	var c: Dictionary = peak.couloir()
	var line: Array = c.line
	var rim: Vector3 = line[line.size()-1]
	var pts := PackedVector3Array()
	for q: Vector3 in line: pts.append(q+Vector3.UP*LIFT_OVER)
	var flat: Vector2 = peak.centre
	var r2 := Vector2(rim.x,rim.z)
	var top := PeakMassif.PLATEAU_Y+PeakMassif.SEA_Y+LIFT_END
	if r2.distance_to(flat) > LIFT_SHORT:
		var end2 := flat+(r2-flat).normalized()*LIFT_SHORT
		var mid2 := r2.lerp(end2,0.5)
		var mid_y := maxf(float(ground.call(mid2.x,mid2.y))+LIFT_OVER,lerpf(rim.y+LIFT_OVER,top,0.5))
		pts.append(Vector3(mid2.x,mid_y,mid2.y))
		pts.append(Vector3(end2.x,maxf(top,float(ground.call(end2.x,end2.y))+LIFT_OVER),end2.y))
	return {"name":LIFT,"points":pts,"radius":LIFT_R,"strength":LIFT_RISE,"one_way":true}
