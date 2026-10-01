extends "res://tools/landscapes/harness.gd"
## Hill fort: a Paddle swell for the hill, its top sliced level with the Wire
## (hold, then drag down), a closed ring gorge cut round its foot with the Wire
## (one drag round a closed path), and water poured in as a moat.
## Tests: does the slice leave a flat fort top, does a closed Wire path make a
## ring that holds water all the way round.

const HILL := Vector2(0.0,0.0)
## Take 1: RING_R 5.0, full-depth gorge (hit the -1.5 m floor: a chasm).
## Take 2: further out, Shift for the shallower gorge, so the hill keeps its
## flanks and the moat reads as a ditch.
const RING_R := 6.3
const FINE := true
const TOP := 2.6

func title() -> String: return "hill_fort"

func ring(radius: float, count := 24, start := 0.0) -> Array:
	var path := []
	for i in range(count+1):
		path.append(HILL+Vector2.from_angle(start+TAU*i/count)*radius)
	return path

func transect(label: String, bearing: float) -> void:
	var parts: PackedStringArray = []
	for r in range(0,10):
		if r == 9: parts.append("|")
		parts.append("%.2f" % height(HILL+Vector2.from_angle(bearing)*r))
	log_line("transect %s r=0..9: %s" % [label," ".join(parts)])

func ring_heights(label: String) -> void:
	var parts: PackedStringArray = []
	for i in range(8):
		parts.append("%.2f" % height(HILL+Vector2.from_angle(TAU*i/8)*RING_R))
	log_line("ring %s (8 bearings): %s" % [label," ".join(parts)])

func build() -> void:
	await take_tool("paddle")
	await size(2)
	await hold_to(HILL,4.2)
	transect("hill",0.0)
	await take_tool("wire")
	await size(2)
	await hold_to(HILL,TOP)
	transect("sliced",0.0)
	transect("sliced side",PI*0.5)
	await overview()
	await still("sliced")
	await drag(ring(RING_R),3.0,FINE)
	await frames(200)
	await settle()
	ring_heights("after cut")
	transect("ditched",0.0)
	transect("ditched side",PI*0.5)
	measure_verbs()
	await overview()
	await still("ringed")
	await pour(HILL+Vector2.from_angle(1.2)*RING_R,3.0)
	await pour(HILL+Vector2.from_angle(1.2+0.9)*RING_R,3.0)
	await pour(HILL+Vector2.from_angle(1.2-0.9)*RING_R,3.0)
	await put_down()
	await let_world_run(25.0)
	for i in range(8):
		measure_water("moat b%d" % i,HILL+Vector2.from_angle(TAU*i/8)*RING_R,1.2)
	measure_water("fort top",HILL,2.5)
	measure_water("whole plate",Vector2.ZERO,30.0)
	measure_life("plate")
	await overview()
	await still("moat")
	await view(HILL,17.0,scene.yaw+0.5,1.1)
	await still("moat-low")
