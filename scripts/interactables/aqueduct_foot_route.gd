extends RefCounted
## The on-foot pieces placed on the aqueduct isle (studies/aqueduct_isle.gd;
## docs/design/foot-interactables.md), a short route worth recording, a
## loop:
##   1. the grand stair down from the henge terrace: a balustrade down each
##      cheek (slide it, flung off its foot east across the meadow);
##   2. beside the aqueduct, out over the near island's north meadow and
##      the 16 m gap: three ropes hung from stone beams laid out over the
##      aqueduct's east parapet, a cloth tag off each beam's end, the first
##      over the meadow (run into it or jump to it), the second and third
##      over the gap, each a plain release on from the last (rope, rope,
##      rope), and from the third a release lands him on the far island;
##   3. back across the gap east of it on a drifting slab, a ferry out and
##      back;
##   4. off the near island's east rim, three bobbing slabs climbing out to
##      the east islet (the lodestone's floating stone just north of them).
## The stair to the clouds' own pieces (scripts/interactables/
## stair_clouds_foot_route.gd) stand on it in the sky.
##
## `--foot-at=rail|ropes|ferry|slabs` (on the aqueduct isle and the game,
## studies/zenscape.tscn) starts on foot at that piece; `--foot-at=stair`
## on the stair to the clouds (in the sky: scripts/interactables/
## stair_clouds_foot_route.gd SPOTS). `--no-foot-pieces` leaves them all out.
const FootPieces = preload("res://scripts/interactables/foot_pieces.gd")
const Balustrade = preload("res://scripts/interactables/balustrade.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const StairClouds = preload("res://scripts/interactables/stair_clouds_foot_route.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")

const TOP := Art.TOP
## The ropes: the anchor's x under the beam's outer end (the beam from the
## deck out over the east face, clear of the buttress at x 104.3), their z
## along the aqueduct, the anchor's height and the rope's length (its knot
## SwingRope.KNOT over the turf, at a standing walker's hands). Measured
## (tools/measure_rope_reach.gd, round 3), a 5.6 m rope's well-timed plain
## release reaches 19.0 m held by the knot, a twirl 24.4 (22.8 held 0.7 m
## up, as a running jump takes it), the sail 44.9. So the first hangs over
## the near island's meadow, 7.7 m in from the rim, run into or jumped to;
## the second over the gap 10.5 m on and the third 10.5 m past it, 2.8 m
## short of the far rim: each well inside a plain release (the user asked
## for rope, rope, rope across, 2026-10-11). From the third a release
## lands well up the far island.
const ROPE_X := 106.3
const ROPE_ZS := [-16.6,-27.1,-37.6]
const ROPE_LENGTH := SwingRope.LENGTH
const ROPE_TOP := TOP+SwingRope.KNOT+ROPE_LENGTH
## The ferry: along z across the gap at x, there and back in PERIOD s.
const FERRY := [Vector3(110.0,TOP+0.3,-27.0),Vector3(110.0,TOP+0.3,-40.8)]
const FERRY_PERIOD := 11.0
## The bobbing slabs off the east rim to the east islet.
const BOBS := [Vector3(129.6,TOP+0.3,3.4),Vector3(132.6,TOP+0.8,2.0),Vector3(135.0,TOP+1.4,-1.4)]
## Where --foot-at= starts him: [feet, the way faced (x, z)].
const SPOTS := {
	"rail":[Vector3(77.8,TOP+4.48,-1.0),Vector2(1.0,0.0)],
	"ropes":[Vector3(ROPE_X,TOP,-6.6),Vector2(0.0,-1.0)],
	"ferry":[Vector3(110.0,TOP,-43.5),Vector2(0.0,1.0)],
	"slabs":[Vector3(124.0,TOP,4.0),Vector2(1.0,-0.2)],
}

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
		beams.append({"name":"beam","at":Vector3(ROPE_X-2.75,ROPE_TOP+0.5,z),"size":Vector3(6.4,0.5,0.6),"yaw":0.0,"kind":"lintel"})
		var r: Node3D = host.rope(Vector3(ROPE_X,ROPE_TOP,z),ROPE_LENGTH)
		r.add_tag(Vector3(ROPE_X+0.25,ROPE_TOP,z),0.0,321+i)
	var beam_stones := Art.floating_stones(320,beams)
	beam_stones.name = "RopeBeams"
	host.add_child(beam_stones)
	# 3: the ferry back across.
	host.drift_slab(PackedVector3Array(FERRY),FERRY_PERIOD,false,0.0,Vector3(2.4,0.6,2.4),0.0,330)
	# 4: the bobbing slabs out to the east islet.
	for i in range(BOBS.size()): host.bob_slab(BOBS[i],Vector3(2.3,0.7,2.2),0.4+0.5*i,340+i)
	# The stair to the clouds, where the sky stands it.
	StairClouds.build(study,StairClouds.SKY_OFFSET)
	start_at(study,SPOTS.merged(StairClouds.spots(StairClouds.SKY_OFFSET)))
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
