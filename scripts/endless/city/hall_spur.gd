extends RefCounted
## The giants' city's spur (giant_city.gd has the contract): what's left of a side
## way from the road to the pillared hall's door, on the hall's own axis, so the door
## shows straight down it from the fork. Narrower than the road and far more gone:
## two columns where it leaves the road, stumps and stray paving, and a last pair
## framing the door. Nothing crosses it; it's a sight line more than a street.
##
## A LANDED piece: its heights are the world's. The frame: its row in PLACED has the
## hall's turn, so +z runs from the fork to the door.

const Shapes = preload("res://scripts/endless/city/city_shapes.gd")
const Road = preload("res://scripts/endless/city/road.gd")

const REACH := 40.0
const SPINE := 260.0
const LANDED := true
## Half the way, to the rows' centres, and its stations: the first z, the step.
const HALF := 24.0
const FROM_Z := -255.0
const STEP := 50.0
## What's left at each station, L (-x) and R (+x), in the road's letters (road.gd
## ROW_L): t a column, m a broken shaft, s a stump, d drums, . nothing.
const ROW_L := "tm.s.d.s.mt"
const ROW_R := "ts.d.s..smt"
## Paving left, by station: the patch's size, 0 none.
const PAVE: Array[int] = [24,0,20,0,0,24,0,20,28,0,30]
## Columns lying by the way: z, x, yaw.
const LYING: Array[Vector3] = [Vector3(-70.0,31.0,0.5),Vector3(150.0,-34.0,-0.35)]

static func build(s: Shapes, land: Callable) -> void:
	var cache := {}
	for i in ROW_L.length():
		var z := FROM_Z+i*STEP
		_stone(s,land,-HALF,z,ROW_L[i],i)
		_stone(s,land,HALF,z,ROW_R[i],i+40)
		if PAVE[i] > 0:
			var size := float(PAVE[i])
			var x := (Road._h(i,5)-0.5)*HALF
			s.stamp(Road._sized(cache,PAVE[i],Road._patch.bind(size)),Vector3(x,float(land.call(x,z+STEP*0.5))+0.5,z+STEP*0.5),(Road._h(i,6)-0.5)*0.5)
	for f: Vector3 in LYING:
		s.stamp(Road._sized(cache,"fallen",Road._fallen),Vector3(f.y,_rest(land,f.y,f.x,Road.FALLEN.z*0.5),f.x),PI*0.5+f.z)

## The lowest ground within `r` of (x, z), what a fallen thing rests on.
static func _rest(land: Callable, x: float, z: float, r: float) -> float:
	var y := float(land.call(x,z))
	for k in 4:
		var a := k*PI*0.5
		y = minf(y,float(land.call(x+cos(a)*r,z+sin(a)*r)))
	return y

## What a station has left on one side, as ROW_L spells it.
static func _stone(s: Shapes, land: Callable, x: float, z: float, what: String, i: int) -> void:
	var o := Vector3(x,_rest(land,x,z,Road.FOOT),z)
	match what:
		"t": Road._shaft(s,o,Road.TALL,true)
		"m": Road._shaft(s,o,Road.SNAPPED,false)
		"s": Road._shaft(s,o,Road.STUMP,false)
		"d":
			for k in 3:
				var q := Vector2(x+(Road._h(i,k+3)-0.5)*20.0,z+(Road._h(i,k+6)-0.5)*30.0)
				Road._drum_in(s,Vector3(q.x,_rest(land,q.x,q.y,Road.SHAFT.x),q.y))
	s.layer = Shapes.BOTH
