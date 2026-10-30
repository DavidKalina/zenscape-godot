## The Peak's way up for every weight (docs/design/endless-flight/spec-crown.md),
## from the placed massif (scripts/endless/peak_massif.gd): a chosen, telegraphed
## lift up the rock gorge, on along the saddle's ramp toward the plateau, ending
## short of its flat so it never holds a landing off. It is one way (AirLift
## `add` one_way): a plane flying up the gorge rides it, one flying back down has
## still air.
##
## The main scene asks `lift(peak, ground)` once the massif is placed and hands
## it to AirLift.add.
extends RefCounted

const PeakMassif = preload("res://scripts/endless/peak_massif.gd")
const Split = preload("res://scripts/endless/peak_split.gd")

## The lift's path name (AirLift).
const LIFT := "peak/rock_gorge"
## The lift: LIFT_OVER m over the gorge's floor, LIFT_R m round, LIFT_RISE m/s
## at its core. It starts LIFT_FROM m up the gorge. It ends LIFT_END m over the
## plateau's flat and no nearer its centre than LIFT_SHORT (the flat's radius
## plus most of the tube's).
const LIFT_OVER := 40.0
const LIFT_R := 60.0
const LIFT_RISE := 12.0
const LIFT_FROM := 120.0
const LIFT_END := 40.0
const LIFT_SHORT := 230.0
## One point of the tube every this many of the line's samples.
const EVERY := 3

## The rock gorge's lift: {name, points, radius, strength, one_way}. `ground`:
## the land's height (world y) at (x, z).
static func lift(peak: RefCounted, ground: Callable) -> Dictionary:
	var g: Dictionary = peak.gorge(Split.ROCK)
	var line: Array = g.line
	var saddle: int = g.saddle
	var pts := PackedVector3Array()
	var k := int(LIFT_FROM/Split.STRIDE)
	while k < saddle:
		pts.append((line[k] as Vector3)+Vector3.UP*LIFT_OVER)
		k += EVERY
	var s0: Vector3 = line[saddle]
	pts.append(s0+Vector3.UP*LIFT_OVER)
	var flat: Vector2 = peak.centre
	var r2 := Vector2(s0.x,s0.z)
	var top := PeakMassif.PLATEAU_Y+PeakMassif.SEA_Y+LIFT_END
	if r2.distance_to(flat) > LIFT_SHORT:
		var end2 := flat+(r2-flat).normalized()*LIFT_SHORT
		pts.append(Vector3(end2.x,maxf(top,float(ground.call(end2.x,end2.y))+LIFT_OVER),end2.y))
	return {"name":LIFT,"points":pts,"radius":LIFT_R,"strength":LIFT_RISE,"one_way":true}
