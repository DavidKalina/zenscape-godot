extends RefCounted
## The on-foot pieces placed on the aqueduct isle (studies/aqueduct_isle.gd;
## docs/design/foot-interactables.md), a short route worth recording, a
## loop:
##   1. the grand stair down from the henge terrace: a balustrade down each
##      cheek (slide it, flung off its foot east across the meadow);
##   2. beside the aqueduct, out over the near island's north meadow and
##      the gap (30 m at plane 2, ratio 1.0): three ropes hung from stone
##      beams laid out over the aqueduct's east parapet, a cloth tag off
##      each beam's end, the first over the meadow (run into it or jump to
##      it), the second and third over the gap (laid out from the isle as
##      drawn, so they follow its scale), each a plain release on from the
##      last (rope, rope, rope), and from the third a release lands him on
##      the far island;
##   3. back across the gap east of it on a drifting slab, a ferry out and
##      back;
##   4. off the near island's east rim, three bobbing slabs climbing out to
##      the east islet (the lodestone's floating stone just north of them);
##   5. over the first slab, the air rings (scripts/interactables/
##      air_ring.gd): slam the slab, its spring throws him up through the
##      first, and each ring's boost and one refilled updraft take him up to the next,
##      stepping back west over the rim to a turfed perch high over the
##      meadow;
##   6. from the east islet, the ring route out to the bell spires
##      (scripts/interactables/ring_route.gd).
## The stair to the clouds' own pieces (scripts/interactables/
## stair_clouds_foot_route.gd) stand on it in the sky.
##
## `--foot-at=rail|ropes|ferry|slabs|ring_route|ring_slide|ring_far` (on the aqueduct isle and the game,
## studies/zenscape.tscn) starts on foot at that piece; `--foot-at=stair`
## on the stair to the clouds (in the sky: scripts/interactables/
## stair_clouds_foot_route.gd SPOTS). `--no-foot-pieces` leaves them all out.
const FootPieces = preload("res://scripts/interactables/foot_pieces.gd")
const Balustrade = preload("res://scripts/interactables/balustrade.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const StairClouds = preload("res://scripts/interactables/stair_clouds_foot_route.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const RingRoute = preload("res://scripts/interactables/ring_route.gd")

const TOP := Art.TOP
## The ropes, laid out from the isle as drawn (Art: the aqueduct's deck,
## the near and far islands' rims), so they follow its scale: the anchor's
## x under the beam's outer end (the beam from the deck out over the east
## face, clear of the buttress at x 104.3), lying on the east parapet, the
## anchor ROPE_UNDER under the beam, the rope down to its knot SwingRope.KNOT
## over the turf, at a standing walker's hands (9.3 m at deck 10). The
## first hangs over the near island's meadow ROPE_IN in from its rim, run
## into or jumped to; the third ROPE_SHORT short of the far rim; the second
## halfway: rope, rope, rope across (the user, 2026-10-11). Measured
## (tools/measure_rope_reach.gd), a 9.3 m rope's well-timed plain release
## reaches 26.5 m (5.6 m: 19.0), so at plane 2, ratio 1.0 (a 30.2 m gap)
## each 17.6 m on is well inside one. From the third a release lands well
## up the far island.
const ROPE_X := 106.3
const ROPE_IN := 7.7
const ROPE_SHORT := 2.8
const ROPE_UNDER := 0.25
const BEAM := Vector3(6.4,0.5,0.6)
static var BEAM_Y: float = TOP+Art.DECK+Art.PARAPET.y+BEAM.y*0.5
static var ROPE_TOP: float = BEAM_Y-BEAM.y*0.5-ROPE_UNDER
static var ROPE_LENGTH: float = ROPE_TOP-TOP-SwingRope.KNOT
static var ROPE_ZS: Array = _rope_zs()
## The ferry: along z across the gap at FERRY_X, from FERRY_OUT out past the
## near rim to FERRY_SHORT short of the far rim, there and back at
## FERRY_PACE (m/s on average: main's 13.8 m in 5.5 s).
const FERRY_X := 110.0
const FERRY_OUT := 2.0
const FERRY_SHORT := 1.6
const FERRY_PACE := 13.8/5.5
static var FERRY: Array = [Vector3(FERRY_X,TOP+0.3,near_rim(FERRY_X)-FERRY_OUT),Vector3(FERRY_X,TOP+0.3,far_rim(FERRY_X)+FERRY_SHORT)]
static var FERRY_PERIOD: float = 2.0*absf((FERRY[1] as Vector3).z-(FERRY[0] as Vector3).z)/FERRY_PACE
## The bobbing slabs off the east rim to the east islet.
const BOBS := [Vector3(129.6,TOP+0.3,3.4),Vector3(132.6,TOP+0.8,2.0),Vector3(135.0,TOP+1.4,-1.4)]
## The air rings over the first slab (docs/design/air-ring/air-ring-handoff.md),
## sized from the motor as measured on it (scratch drivers, size 1, the
## slab's rest top): no spring, a jump, three updrafts and a twirl reach
## 7.1 m; the slab's launch alone 8.0 m (with one updraft 11.8, two 14.1).
## The first ring's middle RING_FIRST over the slab: his chest (feet + 0.9)
## crosses it at the launch's top and never off a jump. From a ring (popped
## AirRing.POP up, the charge refilled and its chain fresh) the pop alone
## puts his chest 6.0 m over it, short of the next, and the pop and one
## updraft 9.7 m, 2.2 past it (measured, scratch/ring_route/measure.gd):
## each ring RING_STEP over the last and RING_OUT out along RING_WAY, one
## Q a step. The perch PERCH_UP over the last ring's middle, PERCH_OUT on,
## its top turfed: the last ring's pop alone lands him on it.
const RING_FIRST := 9.1
## The first slab, under the rings, throws a pump higher than the others
## (BobSlab.SPRING_PUMPS 6): at 6 its launch tops out 7.5 to 8.1 m, too
## near the 7.1 m a jump and three updrafts reach for a ring between them.
const RING_SLAB_PUMPS := 7.0
const RING_STEP := 7.5
const RING_OUT := 3.0
const RING_COUNT := 3
const RING_WAY := Vector2(-0.954,-0.3)
const PERCH_UP := 4.5
const PERCH_OUT := 3.6
const PERCH := Vector3(3.8,1.3,3.6)
static var RINGS: Array = _rings()
static var PERCH_AT: Vector3 = (RINGS[-1] as Vector3)+Vector3(RING_WAY.x,0.0,RING_WAY.y)*PERCH_OUT+Vector3.UP*PERCH_UP

static func _rings() -> Array:
	var out: Array = []
	var base: Vector3 = BOBS[0]
	for i in range(RING_COUNT):
		out.append(base+Vector3(RING_WAY.x,0.0,RING_WAY.y)*RING_OUT*i+Vector3.UP*(RING_FIRST+RING_STEP*i))
	return out

## Where --foot-at= starts him: [feet, the way faced (x, z)]. Ropes: 10 m
## short of the first; ferry: 1.1 m in on the far island behind its end.
static var SPOTS: Dictionary = {
	"rail":[Vector3(77.8,TOP+4.48,-1.0),Vector2(1.0,0.0)],
	"ropes":[Vector3(ROPE_X,TOP,float(ROPE_ZS[0])+10.0),Vector2(0.0,-1.0)],
	"ferry":[Vector3(FERRY_X,TOP,far_rim(FERRY_X)-1.1),Vector2(0.0,1.0)],
	"slabs":[Vector3(124.0,TOP,4.0),Vector2(1.0,-0.2)],
}

## The near island's north rim at `x` (world z), and the far island's south
## rim (Art.NEAR, Art.FAR as moved with the aqueduct's run).
static func near_rim(x: float) -> float:
	return _crossing(Art.NEAR,x,true)

static func far_rim(x: float) -> float:
	return _crossing(Art.FAR,x,false)

static func _crossing(outline: Array, x: float, north: bool) -> float:
	var best := INF if north else -INF
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		if a.x == b.x or (a.x-x)*(b.x-x) > 0.0: continue
		var z := lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))
		best = minf(best,z) if north else maxf(best,z)
	return best

static func _rope_zs() -> Array:
	var first := near_rim(ROPE_X)+ROPE_IN
	var third := far_rim(ROPE_X)+ROPE_SHORT
	return [first,(first+third)*0.5,third]

## The camera's angle from straight up at a --foot-at= start (radians; the
## walker's own is PI/2-0.7, looking down at him).
const SPOT_POLAR := 1.32

## The pieces on `study` (the aqueduct isle), its host made if need be.
static func build(study: Node3D) -> Node3D:
	var args := LaunchArgs.user_args()
	if args.has("--no-foot-pieces"): return null
	var host := host_of(study)
	# 1: the grand stair's balustrades.
	var stair: Transform3D = study.stair.transform
	for side: float in [-1.0,1.0]: host.balustrade(Balustrade.grand_stair_rail(stair,side),310+int(side),0.4,Balustrade.grand_stair_floor(stair,side))
	# 2: the ropes off beams over the parapet.
	var beams: Array = []
	for i in range(ROPE_ZS.size()):
		var z: float = ROPE_ZS[i]
		beams.append({"name":"beam","at":Vector3(ROPE_X-2.75,BEAM_Y,z),"size":BEAM,"yaw":0.0,"kind":"lintel"})
		var r: Node3D = host.rope(Vector3(ROPE_X,ROPE_TOP,z),ROPE_LENGTH)
		r.add_tag(Vector3(ROPE_X+0.25,ROPE_TOP,z),0.0,321+i)
	var beam_stones := Art.floating_stones(320,beams)
	beam_stones.name = "RopeBeams"
	host.add_child(beam_stones)
	# 3: the ferry back across.
	host.drift_slab(PackedVector3Array(FERRY),FERRY_PERIOD,false,0.0,Vector3(2.4,0.6,2.4),0.0,330)
	# 4: the bobbing slabs out to the east islet.
	for i in range(BOBS.size()):
		var slab: Node3D = host.bob_slab(BOBS[i],Vector3(2.3,0.7,2.2),0.4+0.5*i,340+i)
		if i == 0: slab.spring_pumps = RING_SLAB_PUMPS
	# 5: the air rings over the first slab, up to the perch.
	for i in range(RINGS.size()): host.air_ring(RINGS[i],350+i,0.3*i)
	var perch := Art.floating_stones(360,[{"name":"perch","at":PERCH_AT,"size":PERCH,"yaw":0.35,"kind":"block"},
		{"name":"marker","at":PERCH_AT+Vector3(1.1,1.5,-0.9),"size":Vector3(0.55,1.9,0.45),"yaw":0.6,"kind":"sarsen","grounded":true}])
	perch.name = "RingPerch"
	host.add_child(perch)
	# 6: the ring route out east to the bell spires (scripts/interactables/
	# ring_route.gd); --no-ring-route leaves it out.
	if not args.has("--no-ring-route"): RingRoute.build(study,host)
	# The stair to the clouds, where the sky stands it.
	StairClouds.build(study,StairClouds.SKY_OFFSET)
	start_at(study,SPOTS.merged(StairClouds.spots(StairClouds.SKY_OFFSET)).merged(RingRoute.spots()))
	return host

## The scene's pieces host (scripts/interactables/foot_pieces.gd), made and
## hooked into its frame the first time.
static func host_of(study: Node3D) -> Node3D:
	var host: Node3D = study.get("foot_pieces")
	if host != null: return host
	host = FootPieces.new()
	study.add_child(host)
	host.attach(study)
	return host

## With --foot-at=<spot>, he starts there once the isle is up.
static func start_at(study: Node3D, spots: Dictionary) -> void:
	for arg in LaunchArgs.user_args():
		if not arg.begins_with("--foot-at="): continue
		var key := arg.get_slice("=",1)
		if not spots.has(key):
			push_warning("foot route: no spot '%s' (%s)" % [key,", ".join(PackedStringArray(spots.keys()))])
			return
		var spot: Array = spots[key]
		study.isle_ready.connect(func() -> void:
			study.start = spot[0]
			study.start_face = spot[1]
			study.place(spot[0],spot[1])
			# The camera low behind him, looking out along his way rather
			# than down at his feet, so the piece ahead is in view.
			study.set("_polar",SPOT_POLAR)
			study.set("_last_stood",spot[0]),CONNECT_ONE_SHOT)
