extends Node3D
## A rune serpent in the sky round the aqueduct isle (studies/
## aqueduct_isle_sky.gd; docs/scenic/rune-serpent.md): the grass snake
## (scripts/life_snakes.gd) grown to some ninety metres and carved from the
## ruins' eroded basalt, flying. It slithers a long authored way through the
## sky isles: round the aqueduct isle at a respectful distance, out west and
## down the length of the Sundered gorge between its two halves, back round
## the isle, down into the cloud sea under the bell spires and breaching
## out of it again, and home (docs/scenic/motif-sky.md). Runes glow in bands round its flanks where
## the grass snake has its dark bars, a rune collar behind its head, a line
## of runes running back along its spine with its speed, its eyes alight;
## two whiskers of soft light stream from the corners of its mouth and a
## fin of light from its tail's tip, drawing its slither in the air.
##
## Built and moved in code, as the grass snake is. The body is a faceted
## tube skinned to a chain of bones, and every ring follows the exact path
## the head has taken, so the serpentine comes from the head's way weaving
## and the body never slides sideways. The path is kept as points STEP
## apart. The head's way is the route (ROUTE, a closed cubic B-spline, so it
## turns smoothly and never overshoots its control points) with a lateral
## weave WEAVE radians either side, one wave every WAVE metres, like a sea
## snake swimming, a slow heave up and down, the rings rolling into the
## route's turns. The waves stand still in the sky and the body flows
## through them. The head keeps only HEAD_KEEP of the weave: the rest passes
## under it, taken up by the neck's S, so the head glides.
##
## Every head and neck quantity (its pace, the weave, a veer off its way,
## where it looks, the lean and lift of its head, its jaw, its roll) is a
## goal that eases in and follows a critically damped spring, so nothing is
## keyed pose to pose. Breath, a slow drift of the head and tongue flicks
## never stop.
##
## The plane (or the pilot on foot) within NOTICE metres: it turns its head
## to look, the head held steady while the neck's S takes the turn. Flying
## alongside, it veers toward you a little and paces you a few seconds,
## then peels away. Never hostile. Its body is solid to the plane: capsules
## along it on layer 1, moved each physics frame, as the airships' bodies.
##
## Flags (the study's, after --):
##   --serpent-at=<mark or metres>   start it there on its way (MARKS)
##   --serpent-cam[=side|left|pace|below|head|far|hill]   a camera on it
##   --meet-serpent                  into the plane, flying alongside it
##   --serpent-speed=<x>             its pace times x (judging the motion)
##
## Another scene may fly it its own way (studies/serpent_ride.gd, the
## greybox for riding on its back): before `setup` it sets `route`,
## `route_marks` and `start_mark`, its `girth`, and `solid` off; while it is
## ridden, `bank_share` eases its roll and `look_back` has it glance back
## over its shoulder at whoever is behind it. `ring_frame`, `ring_corners`,
## `head_frame` and `head_corners` give its rings and head as posed, to
## stand on. A line of them flying one way nose to tail (the ride's convoy)
## sets each its own `rng_seed` and `clock` before `setup`, so they breathe
## and flick out of step, and holds every one behind the first to a pace
## (`pace_hold`), so each keeps its place in the line. Left alone, all of
## these are as above.

const Variety = preload("res://scripts/seeded_variety.gd")
const StoneLampLights = preload("res://scripts/stone_lamp_lights.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const SHADER := preload("res://shaders/rune_serpent.gdshader")
const GLOW_SHADER := preload("res://shaders/rune_serpent_glow.gdshader")
const RIBBON_SHADER := preload("res://shaders/rune_serpent_ribbon.gdshader")

## The body (m). About 90 m from snout to tail tip and 4 m through at its
## widest: longer than a near isle is wide (25 to 35 m), a good share of the
## aqueduct isle (110 m), still slender. Its girth along it is the grass
## snake's (`_profile`).
const LENGTH := 90.0
const RADIUS := 2.0
## The head's length, the rune collar's behind it, and how far back from
## the snout the neck's S starts.
const HEAD := 6.4
const COLLAR := 1.4
const NECK := 17.0
## The head: its girth over the neck's, and its sections back to front,
## each [width, height (shares of that girth), place along it (share of
## HEAD)]: the head's back, the jowls (its widest), the brow and eyes, the
## snout, the blunt nose. The eyes' length and width (shares of its girth).
const HEAD_GIRTH := 1.15
const HEAD_SECTIONS := [[0.92,0.78,0.0],[1.24,0.72,0.28],[1.08,0.62,0.56],[0.7,0.46,0.82],[0.36,0.28,0.97]]
const EYE_SIZE := Vector2(0.34,0.24)
## Rings along the body, and points on the neck's curve.
const STATIONS := 48
const NECK_SAMPLES := 12
## A ring's height over its width; the back's crest narrower and higher and
## the belly broader (shares of the ring's radius).
const SQUASH := 0.84
const CREST := Vector2(0.84,1.07)
const BELLY := 1.12
## How far a ring's corners stand in or out of true (share of its radius),
## so its facets read as hewn stone, not a turned tube.
const HEWN := 0.05
## The path: points STEP apart (m), TRAIL of them (the body and some to
## spare); the head's way is laid in steps of at most SUB m.
const STEP := 0.5
const TRAIL := 240
const SUB := 0.12
## The way round (world): a closed cubic B-spline through these control
## points, each [point, weave share, pace share, veer share]. North of the
## isle (0) south past its east side (2-4), round its south some 45 m off
## its rim (5-7), out west to the Sundered gorge (8-9) and down the length
## of its gap from the south mouth to the north, over the lower crossing
## and the broken bridge between the two halves' rims (10-14, the weave
## held in: docs/scenic/motif-sky.md), back east round the isle's north
## (15-19), east (20-21), down into the cloud sea under the bell spires
## (22-25) and along under its tops, breaching out north (26-30), round
## north-west (31-34) and home west along the north and down past the
## lodestone's shard some 100 m off its west side (35-40), clear of it and
## of the ring the hall chain raises past it (studies/
## aqueduct_isle_chain.gd). Weave and veer are held in near rock and the
## pace eased through the gaps.
const ROUTE := [
	[Vector3(172.0,44.0,-200.0),1.0,1.0,0.6],
	[Vector3(172.0,40.0,-135.0),1.0,1.0,0.4],
	[Vector3(168.0,34.0,-72.0),0.6,0.95,0.0],
	[Vector3(167.0,32.0,-35.0),0.5,0.92,0.0],
	[Vector3(165.0,31.0,8.0),0.6,0.95,0.0],
	[Vector3(150.0,33.0,62.0),0.9,1.0,0.0],
	[Vector3(95.0,36.0,92.0),1.0,1.0,0.0],
	[Vector3(30.0,32.0,84.0),1.0,1.0,0.0],
	[Vector3(-110.0,40.0,170.0),1.0,1.0,0.6],
	[Vector3(-240.0,46.0,200.0),0.8,1.0,0.0],
	[Vector3(-298.0,50.0,150.0),0.4,0.95,0.0],
	[Vector3(-299.0,50.0,110.0),0.3,0.9,0.0],
	[Vector3(-299.0,50.0,70.0),0.3,0.9,0.0],
	[Vector3(-299.0,50.0,30.0),0.3,0.9,0.0],
	[Vector3(-297.0,48.0,-15.0),0.5,0.95,0.0],
	[Vector3(-200.0,44.0,-45.0),0.9,1.0,0.4],
	[Vector3(-80.0,42.0,-50.0),0.8,1.0,0.0],
	[Vector3(5.0,38.0,-95.0),1.0,1.0,0.0],
	[Vector3(65.0,32.0,-110.0),0.9,1.0,0.0],
	[Vector3(130.0,30.0,-112.0),0.9,1.0,0.0],
	[Vector3(205.0,32.0,-112.0),1.0,1.0,0.3],
	[Vector3(265.0,26.0,-72.0),0.8,1.0,0.0],
	[Vector3(330.0,8.0,-20.0),1.0,1.0,0.6],
	[Vector3(400.0,-40.0,25.0),1.0,1.0,1.0],
	[Vector3(465.0,-95.0,35.0),1.1,1.0,1.0],
	[Vector3(515.0,-135.0,5.0),1.25,0.9,0.0],
	[Vector3(535.0,-140.0,-70.0),1.25,0.9,0.0],
	[Vector3(525.0,-110.0,-160.0),1.1,1.0,0.0],
	[Vector3(520.0,-55.0,-250.0),1.0,1.0,1.0],
	[Vector3(528.0,-5.0,-345.0),1.0,1.0,1.0],
	[Vector3(540.0,22.0,-440.0),0.8,1.0,0.5],
	[Vector3(500.0,30.0,-610.0),1.0,1.0,1.0],
	[Vector3(404.6,29.2,-772.6),0.8,1.0,0.5],
	[Vector3(360.0,34.0,-815.0),0.8,1.0,0.0],
	[Vector3(280.0,40.0,-830.0),1.0,1.0,1.0],
	[Vector3(190.0,46.0,-790.0),1.0,1.0,1.0],
	[Vector3(115.0,50.0,-700.0),1.0,1.0,1.0],
	[Vector3(80.0,50.0,-590.0),1.0,1.0,1.0],
	[Vector3(80.0,49.0,-470.0),1.0,1.0,1.0],
	[Vector3(100.0,48.0,-350.0),1.0,1.0,0.6],
	[Vector3(140.0,47.0,-262.0),1.0,1.0,0.4],
]
## Places on the way, by control point (--serpent-at=<name>).
const MARKS := {"north":0,"gap":2,"curl":6,"gorge":12,"west":15,"east":20,"dive":23,"sea":25,"breach":28,"home":37}
## Where it starts (a mark).
const START := "north"
## The route is kept as points ROUTE_STEP m apart.
const ROUTE_STEP := 1.0

## Metres per second: its cruise, a slow surge of SURGE either way every
## SURGE_PERIOD s, faster diving and slower climbing by DIVE_GAIN per unit
## of the way's slope, always within PACE_RANGE. The plane cruises at 14
## m/s (scripts/sky_plane.gd), so it can catch it and fly alongside.
const CRUISE := 12.0
const SURGE := 0.14
const SURGE_PERIOD := 38.0
const DIVE_GAIN := 0.35
const PACE_RANGE := Vector2(8.5,17.0)
## The head weaves WEAVE radians either side of its way, one wave every
## WAVE m, and the body follows: the serpentine, long and slow at this
## size. It heaves HEAVE radians up and down, a wave every HEAVE_WAVE m.
const WEAVE := 0.42
const WAVE := 46.0
const HEAVE := 0.1
const HEAVE_WAVE := 84.0
## The share of the weave its head keeps (the neck takes the rest).
const HEAD_KEEP := 0.3
## Rolling into the route's turns: radians per m/s² of turn, and most.
const BANK := 0.2
const BANK_MAX := 0.5

## Watching. The plane (the pilot on foot) within NOTICE m of its head: it
## turns its head to look, up to LOOK_MAX radians (turn, tilt) off its way
## (and ahead again once you are behind it, past LOOK_BEHIND, rather than
## whipping round), its head leaning LEAN m toward you and lifting
## LOOK_LIFT m; for at most WATCH_MOST s, then not again for
## NOTICE_COOLDOWN s. A plane within PACE_NEAR m flying its way (the
## headings' cosine over PACE_ALIGN) it paces for PACE_TIME s, matching its
## speed and veering toward it up to VEER m where there is room (the
## route's veer share), keeping PACE_GAP m off; then it peels away, PEEL
## times its pace and veering off, for PEEL_TIME s.
const NOTICE := 120.0
const WATCH_MOST := 14.0
## Glancing back over its shoulder (`look_back`): the most seconds a glance
## lasts, and the share of LOOK_MAX it turns.
const GLANCE := 5.0
const GLANCE_TURN := 0.85
const NOTICE_COOLDOWN := 16.0
const LOOK_MAX := Vector2(1.25,0.55)
const LOOK_BEHIND := 2.4
const LEAN := 2.6
const LOOK_LIFT := 1.8
const PACE_NEAR := 80.0
const PACE_ALIGN := 0.5
const PACE_TIME := Vector2(6.0,9.0)
const PACE_GAP := 22.0
const VEER := 9.0
const PEEL := 1.3
const PEEL_TIME := 6.0
## Its jaw (radians): cracked open when it first notices you, for JAW_TIME s.
const JAW_NOTICE := 0.2
const JAW_TIME := 1.8
## The tongue: out FLICK s, every FLICK_EVERY s (sooner while it watches).
const FLICK := 0.6
const FLICK_EVERY := Vector2(3.5,7.0)
const FLICK_WATCH := Vector2(1.4,2.8)

## The springs: its pace (m/s), the weave's share, the veer (m), the
## look's turn and tilt (radians), the head's lean and lift (m), the jaw
## (radians) and the roll (radians). Each goal first eases over SPRING_EASE
## s, then the value follows it at SPRING_HZ with SPRING_DAMP damping (1 is
## critical). Slow, for its size: nothing on it snaps.
enum {S_SPEED,S_WEAVE,S_VEER,S_YAW,S_PITCH,S_LEAN,S_LIFT,S_JAW,S_BANK,S_COUNT}
const SPRING_HZ := [0.12,0.1,0.07,0.3,0.3,0.2,0.2,0.6,0.22]
const SPRING_DAMP := [1.0,1.0,1.0,0.9,0.95,1.0,1.0,1.0,1.0]
const SPRING_EASE := [0.6,0.8,0.8,0.25,0.25,0.4,0.4,0.1,0.4]

## The stone: the ruins' eroded basalt (scripts/ruin_stone_style.gd LOOKS
## "eroded": stone, cool), lit with a stronger hemisphere fill and sky rim
## than the ruins' (FILL, RIM: the sky folk's rule, so a creature reads
## over the land, its shaded side slate and not black), a paler belly, a dark crescent
## behind the collar, a pale lip. Faces toward the sky lighter, under
## darker (FACE_TONE by face, the back first round to the belly), each
## segment a shade apart (SEGMENT_TONE), a few faces worn lighter.
const FILL := 1.6
const RIM := 0.4
const STONE := Color("5a5d63")
const COOL := Color("52575f")
const UNDER := Color("706b64")
const CRESCENT := Color("2c2e33")
const LIP := Color("66625c")
const MOUTH := Color("3b2a22")
const FACE_TONE := [1.13,1.06,0.98,0.9,1.0,0.9,0.98,1.06]
const SEGMENT_TONE := 0.08
const WORN := 0.06
## Rune bands every BAND_EVERY rings from the shoulders, a few left plain
## (BAND_SKIP of them), on the flanks and sides (not the back, whose spine
## runs, nor the belly).
const BAND_EVERY := 3
const BAND_SKIP := 0.15
## The runes' light (shaders/rune_serpent.gdshader): their colour (the stone
## plane's and the lodestone's warm gold) and strength by day and by night
## (less at night: against the dark it reads brighter, and more blows out
## to white), the eyes' colour and strength by day and by night, and the
## eyes' haze (radius m, strength by day and night). The spine's runes run back RUNE_RUN m a
## second per m/s of its pace.
const GLOW := Color(1.0,0.72,0.38)
const DAY_GLOW := 1.5
const NIGHT_GLOW := 1.25
const EYE_DAY := 3.5
const EYE_NIGHT := 5.0
const EYE_GLOW := Color(1.0,0.72,0.36)
const HAZE := 1.4
const HAZE_STRENGTH := Vector2(0.12,0.7)
const RUNE_RUN := 0.45
## A spine rune's length (m).
const SPINE_CELL := 1.5

## The soft lights trailing it (shaders/rune_serpent_ribbon.gdshader): two
## whiskers from the corners of its mouth, WHISKER m long and
## WHISKER_WIDTH m wide (root, tip), and a fin of light FIN m long and at
## most FIN_WIDTH m wide off its tail's tip. Each streams through where its
## root has been (laid every RIBBON_STEP m), so it draws the slither's line
## in the air behind it; it flutters FLUTTER m at its tip, FLUTTER_RATE
## times a second, the whiskers sagging WHISKER_SAG m at the tip; at
## RIBBON_STRENGTH by day (brighter after dark).
const WHISKER := 15.0
const WHISKER_WIDTH := Vector2(0.7,0.14)
const WHISKER_SAG := 1.2
const FIN := 12.0
const FIN_WIDTH := 1.6
const RIBBON_STEP := 0.6
## Past RIBBON_FAR m from the eye the ribbons, thinner than a pixel, are
## not drawn.
const RIBBON_FAR := 600.0
const FLUTTER := 0.45
const FLUTTER_RATE := 0.7
const RIBBON_STRENGTH := 0.85

## Its body against the plane: capsules over CAPSULE_RINGS rings each, on
## SOLID_LAYER (the isle's bump layer), CAPSULE_SHARE of the rings' girth.
const SOLID_LAYER := 1
const CAPSULE_RINGS := 4
const CAPSULE_SHARE := 0.95

## The longest step it takes in one frame (s).
const MAX_STEP := 0.1
## The camera on it (--serpent-cam): how far out, up and back for each
## view (m), and how quickly it follows (per second).
const CAM_FOLLOW := 2.5
## Where --meet-serpent sets the plane: back from its head, out to its
## right, up (m).
const MEET := Vector3(40.0,16.0,5.0)
## The hill's eye stands this high over its summit's turf, over the stone
## circle's lintels.
const HILL_EYE := 9.0
const BREATH_KEYS := [[0.0,0.0],[0.38,1.0],[0.86,0.0],[1.0,0.0]]

var scene: Node3D
## Set before `setup` to fly it another way: its route (as ROUTE), the marks
## on it (as MARKS) and the one it starts at; its girth (RADIUS times this
## through, the head too); whether its body is solid to the plane.
var route: Array = ROUTE
var route_marks: Dictionary = MARKS
var start_mark := START
var girth := 1.0
var solid := true
## The share of its roll into turns it takes (1 all of it; a rider on its
## back may ease it), and whether a watcher behind it is glanced at over
## its shoulder (GLANCE) rather than looked away from.
var bank_share := 1.0
var look_back := false
## The share of its look it takes (live): its head's turn, tilt, lean and
## lift toward a watcher, times this. A route easing it by a boarding ledge
## (scripts/kit_isle/serpent_route.gd) keeps its head on its way there.
var look_share := 1.0
## Its own draws (the tongue's flicks, how long it paces) and where its
## clock starts (s: its breath, its surge and its head's drift), set before
## `setup`; a line of them each its own, so they don't move in step.
var rng_seed := 7741
var clock := 0.0
## Held to this pace (m/s) while 0 or more, its own pace's goal set aside
## (live): a serpent in a line keeps the pace of the one at its head.
var pace_hold := -1.0
## Its pace now (m/s), how far round its way it is (m), how far its head
## has travelled in all (m), and the way's length (m).
var s := 0.0
var travelled := 0.0
var route_length := 0.0
## What it is doing: "roam", "watch", "pace" or "peel"; and what it watches.
var mode := "roam"
var watching := Vector3.INF
## Times it has noticed you and paced you, for probes.
var notices := 0
var paces := 0
## Microseconds the last and the worst advance took, for probes.
var last_usec := 0
var worst_usec := 0

# The route, every ROUTE_STEP m: point, way, turn (1/m, + to the right),
# and its weave, pace and veer shares.
var _rp := PackedVector3Array()
var _rt := PackedVector3Array()
var _rk := PackedFloat32Array()
var _rw := PackedFloat32Array()
var _rpace := PackedFloat32Array()
var _rv := PackedFloat32Array()
var _marks := {}
var _wave := WAVE
var _heave_wave := HEAVE_WAVE

# The path: points at trail arcs i*STEP in a ring buffer of TRAIL: the
# path (P, with the weave), its base (B, the route and the veer) and roll.
var _tp := PackedVector3Array()
var _tb := PackedVector3Array()
var _tr := PackedFloat32Array()
var _laid := -1
var _live_p := Vector3.ZERO
var _live_b := Vector3.ZERO
var _live_r := 0.0

# The rings: their arcs behind the snout, radii, weights; this frame's
# places, rolls and scales.
var _arc := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _breath_w := PackedFloat32Array()
var _tail_w := PackedFloat32Array()
var _neck_count := 0
var _pos := PackedVector3Array()
var _rolls := PackedFloat32Array()
var _curve := PackedVector3Array()
var _curve_arc := PackedFloat32Array()

# The springs: values, velocities, eased goals and goals.
var _sx := PackedFloat32Array()
var _sv := PackedFloat32Array()
var _sf := PackedFloat32Array()
var _sg := PackedFloat32Array()
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _mode_at := 0.0
var _mode_for := 0.0
var _notice_ready := 0.0
var _jaw_until := -10.0
var _flick := -10.0
var _next_flick := 2.0
var _veer_side := 1.0
var _glance_side := 1.0
var _head_fwd := Vector3.FORWARD
var _head_pos := Vector3.ZERO
var _head_dir := Vector3.FORWARD
var _snout := Vector3.ZERO
var _scroll := 0.0
var _speed_scale := 1.0

var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _material: ShaderMaterial
var _haze: ShaderMaterial
var _solid: AnimatableBody3D
var _capsules: Array[CollisionShape3D] = []
var _ribbons: MeshInstance3D
var _ribbon_mesh: ImmediateMesh
var _ribbon_material: ShaderMaterial
## The whiskers' roots (the head's frame), where each root has been
## (newest first), and the head's frame now.
var _whisker_roots: Array[Vector3] = []
var _whisker_trails: Array[PackedVector3Array] = []
var _head_xf := Transform3D.IDENTITY
var _capsule_rings: Array[Vector2i] = []
## The camera on it (--serpent-cam), its eye and look as followed; the
## plane alongside it once (--meet-serpent).
var cam_mode := ""
var _cam_eye := Vector3.INF
var _cam_look := Vector3.ZERO
var _cam_hill := Vector3.INF
var _meet := false

func _init() -> void:
	name = "RuneSerpent"

## Stands it on its way in `study`'s sky, its body laid behind its head.
func setup(study: Node3D) -> void:
	scene = study
	_rng.seed = rng_seed
	_time = clock
	var start: Variant = start_mark
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--serpent-at="): start = arg.get_slice("=",1)
		elif arg == "--serpent-cam": cam_mode = "side"
		elif arg.begins_with("--serpent-cam="): cam_mode = arg.get_slice("=",1)
		elif arg == "--meet-serpent": _meet = true
		elif arg.begins_with("--serpent-speed="): _speed_scale = clampf(float(arg.get_slice("=",1)),0.1,4.0)
	for spring in [_sx,_sv,_sf,_sg]: spring.resize(S_COUNT)
	_tp.resize(TRAIL)
	_tb.resize(TRAIL)
	_tr.resize(TRAIL)
	_build_route()
	_stations()
	_build_body()
	_build_ribbons()
	if solid: _build_solid()
	var at := float(_marks.get(start,-1.0)) if _marks.has(start) else (float(start) if str(start).is_valid_float() else float(_marks.get(start_mark,0.0)))
	place(at)

## Its head at `at` m round its way, its body laid out behind along the way
## it would have come, the springs at rest on their goals.
func place(at: float) -> void:
	s = fposmod(at-(LENGTH+STEP*8.0),route_length)
	travelled = 0.0
	_laid = -1
	mode = "roam"
	_goals()
	for i in range(S_COUNT):
		_sx[i] = _sg[i]
		_sf[i] = _sg[i]
		_sv[i] = 0.0
	var first := _path(s)
	_live_p = first[0]
	_live_b = first[1]
	_live_r = _sx[S_BANK]
	_lay(0)
	var behind := LENGTH+STEP*8.0
	while behind > 0.01:
		var step := maxf(minf(1.0/30.0,behind/maxf(_sx[S_SPEED],1.0)),0.001)
		_goals()
		_springs(step)
		var went := _travel(_sx[S_SPEED]*step)
		if went <= 0.0: break
		behind -= went
	_head_fwd = _route_way(s)
	_pose(0.0)
	for t in _whisker_trails: t.clear()
	_ribbons_step()

# --- The way -------------------------------------------------------------------------

## The route sampled every ROUTE_STEP m along its B-spline: points, ways,
## turns and shares; the marks' places on it.
func _build_route() -> void:
	var n := route.size()
	var dense := PackedVector3Array()
	var shares := PackedVector3Array()
	var per := 48
	var mark_at := {}
	for i in range(n):
		for m: String in route_marks:
			if int(route_marks[m]) == i: mark_at[m] = dense.size()
		for j in range(per):
			var t := float(j)/per
			var w := _basis(t)
			var p := Vector3.ZERO
			var sh := Vector3.ZERO
			for c in range(4):
				var cp: Array = route[(i-1+c+n)%n]
				p += (cp[0] as Vector3)*w[c]
				sh += Vector3(float(cp[1]),float(cp[2]),float(cp[3]))*w[c]
			dense.append(p)
			shares.append(sh)
	var lengths := PackedFloat32Array()
	lengths.resize(dense.size()+1)
	lengths[0] = 0.0
	for i in range(dense.size()):
		lengths[i+1] = lengths[i]+dense[i].distance_to(dense[(i+1)%dense.size()])
	route_length = lengths[dense.size()]
	var count := int(floor(route_length/ROUTE_STEP))
	route_length = count*ROUTE_STEP
	_rp.resize(count)
	_rw.resize(count)
	_rpace.resize(count)
	_rv.resize(count)
	var k := 0
	for i in range(count):
		var want := i*ROUTE_STEP*lengths[dense.size()]/route_length
		while k < dense.size()-1 and lengths[k+1] < want: k += 1
		var f := clampf((want-lengths[k])/maxf(lengths[k+1]-lengths[k],1e-6),0.0,1.0)
		_rp[i] = dense[k].lerp(dense[(k+1)%dense.size()],f)
		var sh: Vector3 = shares[k].lerp(shares[(k+1)%dense.size()],f)
		_rw[i] = sh.x
		_rpace[i] = sh.y
		_rv[i] = sh.z
	_rt.resize(count)
	_rk.resize(count)
	for i in range(count):
		_rt[i] = (_rp[(i+1)%count]-_rp[(i-1+count)%count]).normalized()
	for i in range(count):
		var bend := (_rt[(i+2)%count]-_rt[(i-2+count)%count])/(4.0*ROUTE_STEP)
		var right := _rt[i].cross(Vector3.UP).normalized()
		_rk[i] = bend.dot(right)
	# The turn read over some metres either way, so the roll comes on smoothly.
	var smooth := PackedFloat32Array(_rk)
	for i in range(count):
		var total := 0.0
		for d in range(-6,7): total += smooth[(i+d+count)%count]
		_rk[i] = total/13.0
	for m: String in mark_at:
		_marks[m] = lengths[int(mark_at[m])]*route_length/lengths[dense.size()]
	# Whole waves round the way, so the weave meets itself where it closes.
	_wave = route_length/maxf(roundf(route_length/WAVE),1.0)
	_heave_wave = route_length/maxf(roundf(route_length/HEAVE_WAVE),1.0)

## The uniform cubic B-spline's weights at `t` of a segment.
static func _basis(t: float) -> Array:
	var t2 := t*t
	var t3 := t2*t
	return [(1.0-t)*(1.0-t)*(1.0-t)/6.0,(3.0*t3-6.0*t2+4.0)/6.0,(-3.0*t3+3.0*t2+3.0*t+1.0)/6.0,t3/6.0]

## The route's sample index and share toward the next at `at` m.
func _ri(at: float) -> Vector2:
	var f := fposmod(at,route_length)/ROUTE_STEP
	var i := floori(f)
	return Vector2(i%_rp.size(),f-i)

func route_point(at: float) -> Vector3:
	var r := _ri(at)
	var i := int(r.x)
	return _rp[i].lerp(_rp[(i+1)%_rp.size()],r.y)

func _route_way(at: float) -> Vector3:
	var r := _ri(at)
	var i := int(r.x)
	return _rt[i].lerp(_rt[(i+1)%_rt.size()],r.y).normalized()

## The route's shares at `at`: weave, pace, veer.
func route_shares(at: float) -> Vector3:
	var r := _ri(at)
	var i := int(r.x)
	var j := (i+1)%_rp.size()
	return Vector3(lerpf(_rw[i],_rw[j],r.y),lerpf(_rpace[i],_rpace[j],r.y),lerpf(_rv[i],_rv[j],r.y))

func _route_turn(at: float) -> float:
	var r := _ri(at)
	var i := int(r.x)
	return lerpf(_rk[i],_rk[(i+1)%_rk.size()],r.y)

## The weave's reach either side (m) at full share, and the heave's.
func weave_reach() -> float:
	return _wave*tan(WEAVE)/TAU

func heave_reach() -> float:
	return _heave_wave*tan(HEAVE)/TAU

## How far from the route its body can ever reach at `at` (m): its girth,
## the weave at its most, the veer the route allows and the heave. Clear of
## rock by this, it is clear whatever it does.
func reach_at(at: float) -> float:
	var sh := route_shares(at)
	return RADIUS*girth*1.08+weave_reach()*sh.x*1.05+VEER*sh.z+heave_reach()

## The head's way at route arc `at`: [path point (with the weave), base
## point (the route and the veer)], in the route's frame rolled by the
## bank spring: the weave across, the heave up.
func _path(at: float) -> Array:
	var r := _ri(at)
	var i := int(r.x)
	var p := _rp[i].lerp(_rp[(i+1)%_rp.size()],r.y)
	var t := _rt[i].lerp(_rt[(i+1)%_rt.size()],r.y).normalized()
	var sh := route_shares(at)
	var right := t.cross(Vector3.UP).normalized()
	var up := right.cross(t).normalized()
	var b := _sx[S_BANK]
	var side := right*cos(b)-up*sin(b)
	var lift := up*cos(b)+right*sin(b)
	var base := p+side*_sx[S_VEER]*sh.z
	var weave := weave_reach()*sh.x*_sx[S_WEAVE]*sin(TAU*at/_wave)
	var heave := heave_reach()*sin(TAU*at/_heave_wave+1.3)
	return [base+side*weave+lift*heave,base]

## Travels `go` m of true distance along the head's way, laying path points
## every STEP m; returns how far it went.
func _travel(go: float) -> float:
	var left := go
	var stretch := 1.05
	var guard := 0
	while left > 1e-5 and guard < 400:
		guard += 1
		var ds := minf(SUB,left)/stretch
		var next := s+ds
		var pair := _path(next)
		var p: Vector3 = pair[0]
		var d := p.distance_to(_live_p)
		if d < 1e-6:
			s = next
			continue
		stretch = clampf(d/ds,1.0,2.0)
		var from := travelled
		var from_p := _live_p
		var from_b := _live_b
		var from_r := _live_r
		travelled += d
		_live_p = p
		_live_b = pair[1]
		_live_r = _sx[S_BANK]
		s = fposmod(next,route_length)
		left -= d
		# The path points passed on the way, each where the head was then.
		while float(_laid+1)*STEP <= travelled:
			var k := _laid+1
			var f := (k*STEP-from)/maxf(travelled-from,1e-6)
			var slot := k%TRAIL
			_tp[slot] = from_p.lerp(_live_p,f)
			_tb[slot] = from_b.lerp(_live_b,f)
			_tr[slot] = lerpf(from_r,_live_r,f)
			_laid = k
	return go-left

func _lay(k: int) -> void:
	var slot := k%TRAIL
	_tp[slot] = _live_p
	_tb[slot] = _live_b
	_tr[slot] = _live_r
	_laid = k
	travelled = k*STEP

## The path at trail arc `a` (m since it set out): [path, base, roll]; past
## the last laid point, toward the head's live place.
func trail_at(a: float) -> Array:
	var low := maxi(_laid-TRAIL+1,0)
	var last := float(_laid)*STEP
	if a >= last:
		var f := clampf((a-last)/maxf(travelled-last,1e-6),0.0,1.0)
		var slot := _laid%TRAIL
		return [_tp[slot].lerp(_live_p,f),_tb[slot].lerp(_live_b,f),lerpf(_tr[slot],_live_r,f)]
	var x := maxf(a/STEP,float(low))
	var i := floori(x)
	var fi := x-i
	var a0 := i%TRAIL
	var b0 := mini(i+1,_laid)%TRAIL
	# A Catmull-Rom through the points either side, so a ring passing
	# along the path turns smoothly at each point instead of at a corner.
	var p0 := _tp[maxi(i-1,low)%TRAIL]
	var p3 := _tp[(i+2)%TRAIL] if i+2 <= _laid else _live_p
	var q0 := _tb[maxi(i-1,low)%TRAIL]
	var q3 := _tb[(i+2)%TRAIL] if i+2 <= _laid else _live_b
	return [_catmull(p0,_tp[a0],_tp[b0],p3,fi),_catmull(q0,_tb[a0],_tb[b0],q3,fi),lerpf(_tr[a0],_tr[b0],fi)]

static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	return 0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t)

func _trail_p(a: float) -> Vector3:
	return trail_at(a)[0]

# --- Advancing -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if scene == null or delta <= 0.0: return
	# A long frame (a hitch, a world being built) slows it a moment rather
	# than throwing it tens of metres on in one step.
	advance(minf(delta,MAX_STEP))
	if _meet and scene.get("walk_ready") and not scene.flying:
		_meet = false
		meet()
	_camera_step(delta)

## One step of its life: what it sees, its goals and springs, along its
## way, its body posed, its light.
func advance(delta: float) -> void:
	var began := Time.get_ticks_usec()
	_time += delta
	_see()
	_goals()
	_springs(delta)
	if pace_hold >= 0.0:
		_sx[S_SPEED] = pace_hold
		_sv[S_SPEED] = 0.0
		_sf[S_SPEED] = pace_hold
	var went := _travel(_sx[S_SPEED]*delta)
	_scroll += went*RUNE_RUN
	_pose(delta)
	_ribbons_step()
	_light(delta)
	last_usec = Time.get_ticks_usec()-began
	worst_usec = maxi(worst_usec,last_usec)

func _physics_process(_delta: float) -> void:
	_place_solid()

## The plane (or the pilot on foot): who it might watch, or INF.
func watcher() -> Vector3:
	if scene == null: return Vector3.INF
	if scene.get("flying") and scene.get("plane") != null: return scene.plane.position
	var figure: Variant = scene.get("figure")
	if figure is Node3D and (figure as Node3D).is_inside_tree() and (figure as Node3D).visible: return (figure as Node3D).global_position+Vector3.UP*1.4
	return Vector3.INF

func _set_mode(next: String) -> void:
	mode = next
	_mode_at = _time
	match next:
		"watch":
			notices += 1
			_jaw_until = _time+JAW_TIME
			_next_flick = minf(_next_flick,_time+0.8)
			if watching != Vector3.INF:
				var right := _head_fwd.cross(Vector3.UP).normalized()
				_glance_side = -1.0 if (watching-_head_pos).dot(right) > 0.0 else 1.0
		"pace":
			paces += 1
			_mode_for = _rng.randf_range(PACE_TIME.x,PACE_TIME.y)
		"roam":
			_notice_ready = _time+NOTICE_COOLDOWN

## What it sees: you within NOTICE m, and whether you fly its way alongside.
func _see() -> void:
	var w := watcher()
	watching = w
	var d := w.distance_to(_head_pos) if w != Vector3.INF else INF
	var flying := bool(scene.get("flying")) if scene != null else false
	var age := _time-_mode_at
	match mode:
		"roam":
			if d < NOTICE and _time >= _notice_ready: _set_mode("watch")
		"watch":
			if d > NOTICE*1.25 or age > (GLANCE if look_back and _behind(w) else WATCH_MOST): _set_mode("roam")
			elif flying and d < PACE_NEAR and _aligned(): _set_mode("pace")
		"pace":
			if age > _mode_for or d > NOTICE: _set_mode("peel")
		"peel":
			if age > PEEL_TIME: _set_mode("roam")

## Whether `w` is behind its head, past where it would look round to it.
func _behind(w: Vector3) -> bool:
	if w == Vector3.INF: return false
	var to := w-_head_pos
	var rel := wrapf(atan2(to.x,to.z)-atan2(_head_fwd.x,_head_fwd.z),-PI,PI)
	return absf(rel) > LOOK_BEHIND-0.5

## The plane flies its way (headings within PACE_ALIGN).
func _aligned() -> bool:
	var plane: Variant = scene.get("plane")
	if plane == null: return false
	var v: Vector3 = plane.velocity
	if v.length() < 1.0: return false
	return v.normalized().dot(_route_way(s)) > PACE_ALIGN

## The goals for every spring, from where it is on its way and what it does.
func _goals() -> void:
	var way := _route_way(s)
	var sh := route_shares(s)
	var pace := CRUISE*(1.0+SURGE*sin(TAU*_time/SURGE_PERIOD))*sh.y*(1.0-DIVE_GAIN*way.y)
	var drift := _drift(_time,11.0)
	var yaw := 0.1*drift.x
	var pitch := 0.06*drift.y
	var lean := 0.0
	var lift := 0.0
	var veer := 0.0
	var weave := 1.0
	var w := watching
	if mode in ["watch","pace"] and w != Vector3.INF:
		var to := (w-_head_pos).normalized()
		var base := _head_fwd
		# Behind it (past LOOK_BEHIND), it looks ahead again rather than
		# whipping its head from one side to the other.
		var rel := wrapf(atan2(to.x,to.z)-atan2(base.x,base.z),-PI,PI)
		yaw = clampf(rel,-LOOK_MAX.x,LOOK_MAX.x)*(1.0-smoothstep(LOOK_BEHIND-0.5,LOOK_BEHIND,absf(rel)))
		# Glancing back: over the shoulder it began on, held there, so a
		# watcher straight behind doesn't flip it from side to side.
		if look_back and absf(rel) > LOOK_BEHIND-0.5: yaw = _glance_side*LOOK_MAX.x*GLANCE_TURN
		pitch = clampf(asin(clampf(to.y,-1.0,1.0))-asin(clampf(base.y,-1.0,1.0)),-LOOK_MAX.y,LOOK_MAX.y)
		lean = LEAN
		lift = LOOK_LIFT
		yaw *= look_share
		pitch *= look_share
		lean *= look_share
		lift *= look_share
	if mode == "pace" and w != Vector3.INF:
		var plane: Variant = scene.get("plane")
		if plane != null: pace = (plane.velocity as Vector3).dot(way)
		var right := way.cross(Vector3.UP).normalized()
		var across := (w-_head_pos).dot(right)
		_veer_side = signf(across) if absf(across) > 1.0 else _veer_side
		veer = clampf(across-signf(across)*PACE_GAP,-VEER,VEER) if absf(across) > PACE_GAP else 0.0
		weave = 0.8
	elif mode == "peel":
		pace *= PEEL
		veer = -_veer_side*VEER*0.6
	_sg[S_SPEED] = clampf(pace,PACE_RANGE.x,PACE_RANGE.y)*_speed_scale
	_sg[S_WEAVE] = weave
	_sg[S_VEER] = veer
	_sg[S_YAW] = yaw
	_sg[S_PITCH] = pitch
	_sg[S_LEAN] = lean
	_sg[S_LIFT] = lift
	_sg[S_JAW] = JAW_NOTICE if _time < _jaw_until else 0.0
	var v := _sx[S_SPEED] if _sx[S_SPEED] > 0.0 else CRUISE
	_sg[S_BANK] = clampf(BANK*v*v*_route_turn(s),-BANK_MAX,BANK_MAX)*bank_share

func _springs(step: float) -> void:
	if step <= 0.0: return
	var count := ceili(step/0.02)
	var h := step/count
	for i in range(S_COUNT):
		var w := TAU*float(SPRING_HZ[i])
		var z := float(SPRING_DAMP[i])
		_sf[i] += (_sg[i]-_sf[i])*(1.0-exp(-step/float(SPRING_EASE[i])))
		var x := _sx[i]
		var v := _sv[i]
		for _n in range(count):
			v += ((_sf[i]-x)*w*w-v*2.0*z*w)*h
			x += v*h
		_sx[i] = x
		_sv[i] = v

# --- The body ------------------------------------------------------------------------

## Ring arcs behind the snout: the collar close behind the head, then
## evenly to the tail.
func _stations() -> void:
	for a in [_arc,_radius,_breath_w,_tail_w,_rolls]: a.resize(STATIONS)
	_pos.resize(STATIONS)
	_curve.resize(NECK_SAMPLES+1)
	_curve_arc.resize(NECK_SAMPLES+1)
	_arc[0] = HEAD+COLLAR
	_arc[1] = _arc[0]+0.9
	for k in range(2,STATIONS): _arc[k] = lerpf(_arc[1],LENGTH,float(k-1)/(STATIONS-2))
	_neck_count = 0
	for k in range(STATIONS):
		var u := _body_u(_arc[k])
		_radius[k] = RADIUS*girth*_profile(u)
		_breath_w[k] = sin(PI*clampf((u-0.08)/0.55,0.0,1.0))
		_tail_w[k] = pow(smoothstep(0.86,1.0,u),2.0)
		if _arc[k] < NECK: _neck_count = k+1

func _body_u(a: float) -> float:
	return clampf((a-(HEAD+COLLAR))/(LENGTH-(HEAD+COLLAR)),0.0,1.0)

## Radius share along the body, 0 at the neck and 1 at the tail's tip: the
## grass snake's (scripts/life_snakes.gd `_profile`), its tail drawn out a
## little finer.
static func _profile(u: float) -> float:
	if u < 0.1: return lerpf(0.74,0.95,u/0.1)
	if u < 0.22: return lerpf(0.95,1.0,(u-0.1)/0.12)
	if u < 0.55: return 1.0
	if u < 0.72: return lerpf(1.0,0.76,(u-0.55)/0.17)
	return maxf(0.76*pow(maxf(1.0-(u-0.72)/0.28,0.0),1.25),0.035)

## Every ring on the path behind the head, the neck's on its S up to the
## head; the head steady on the kept share of the weave, turned to what it
## watches; the bones posed; the breath.
func _pose(_delta: float) -> void:
	var head := travelled
	var breath := _beats(fposmod(_time/5.2,1.0),BREATH_KEYS)
	for k in range(STATIONS):
		var t := trail_at(head-_arc[k])
		_pos[k] = t[0]
		_rolls[k] = t[2]
	# The tail's tip drifts a little off the path.
	var drift := _drift(_time,7.0)
	for k in range(STATIONS-6,STATIONS):
		if _tail_w[k] <= 0.0: continue
		var along := (_pos[k-1]-_pos[mini(k+1,STATIONS-1)]).normalized()
		var side := along.cross(Vector3.UP).normalized()
		_pos[k] += (side*drift.x*0.5+Vector3.UP*drift.z*0.3)*_tail_w[k]
	# The head: on the kept share of the weave, a head's length back of the
	# snout's path point, pointing along that kept line; it turns to look.
	var back := trail_at(head-HEAD)
	var front := trail_at(head)
	var kept_back: Vector3 = (back[1] as Vector3).lerp(back[0],HEAD_KEEP)
	var kept_front: Vector3 = (front[1] as Vector3).lerp(front[0],HEAD_KEEP)
	var way := (kept_front-kept_back).normalized()
	if _delta > 0.0: _head_fwd = _head_fwd.slerp(way,1.0-exp(-4.0*_delta)).normalized()
	else: _head_fwd = way
	var hd := _head_fwd.rotated(Vector3.UP,_sx[S_YAW])
	var pitch_axis := hd.cross(Vector3.UP).normalized()
	hd = hd.rotated(pitch_axis,_sx[S_PITCH]).normalized()
	var held := kept_back
	# Toward its look, smoothly saturating (no kink as the look comes round).
	var lean_dir := hd-_head_fwd*hd.dot(_head_fwd)
	held += lean_dir/sqrt(lean_dir.length_squared()+0.0625)*_sx[S_LEAN]
	held += Vector3.UP*_sx[S_LIFT]
	# The neck: an S from the body's line at NECK to the head, keeping its
	# length (handles corrected against it), its rings at their share of it.
	var o: Vector3 = trail_at(head-NECK)[0]
	var o_back: Vector3 = trail_at(head-NECK-1.0)[0]
	var t0 := (o-o_back).normalized()
	var length := NECK-HEAD
	var span := o.distance_to(held)
	var handle := 1.0
	for attempt in range(3):
		var total := 0.0
		var last := o
		for n in range(NECK_SAMPLES+1):
			var point := _hermite(o,t0*span*handle,held,hd*span*handle,float(n)/NECK_SAMPLES)
			total += point.distance_to(last)
			_curve[n] = point
			_curve_arc[n] = total
			last = point
		if attempt < 2: handle = clampf(handle*pow(length/maxf(total,1e-4),1.6),0.5,3.0)
	var total := _curve_arc[NECK_SAMPLES]
	var head_roll := _sx[S_BANK]
	for k in range(_neck_count):
		var want := (NECK-_arc[k])/(NECK-HEAD)*total
		var n := 1
		while n < NECK_SAMPLES and _curve_arc[n] < want: n += 1
		var u := clampf((want-_curve_arc[n-1])/maxf(_curve_arc[n]-_curve_arc[n-1],1e-6),0.0,1.0)
		_pos[k] = _curve[n-1].lerp(_curve[n],u)
		_rolls[k] = lerpf(_rolls[k],head_roll,clampf(1.0-(_arc[k]-HEAD)/(NECK-HEAD),0.0,1.0))
	_head_pos = held
	_head_dir = hd
	_snout = held+hd*HEAD
	if _skeleton == null: return
	# The rings' bones: along the body, rolled into the turns, breathing.
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for k in range(STATIONS):
		var ahead := _pos[k-1] if k > 0 else held
		var behind := _pos[k+1] if k < STATIONS-1 else _pos[k]
		var t := (ahead-behind).normalized()
		var up0 := (Vector3.UP-t*t.y).normalized()
		var right0 := t.cross(up0)
		var up := up0*cos(_rolls[k])+right0*sin(_rolls[k])
		var sc := 1.0+0.025*breath*_breath_w[k]
		_skeleton.set_bone_pose(k,Transform3D(Basis(up.cross(t)*sc,up*sc,t*sc),_pos[k]))
		lo = lo.min(_pos[k])
		hi = hi.max(_pos[k])
	# The head, rolled with the body, its jaw, its tongue.
	var head_up0 := (Vector3.UP-hd*hd.y).normalized()
	var head_right := hd.cross(head_up0)
	var head_up := head_up0*cos(head_roll)+head_right*sin(head_roll)
	var head_side := head_up.cross(hd)
	_head_xf = Transform3D(Basis(head_side,head_up,hd),held)
	_skeleton.set_bone_pose(STATIONS,_head_xf)
	var jaw := _sx[S_JAW]
	_skeleton.set_bone_pose(STATIONS+2,Transform3D(Basis(head_side,head_up.rotated(head_side,jaw),hd.rotated(head_side,jaw)),held))
	var out := 0.0
	var flutter := 0.0
	var age := _time-_flick
	if age >= 0.0 and age < FLICK:
		out = smoothstep(0.0,0.1,age)*(1.0-smoothstep(FLICK-0.12,FLICK,age))
		flutter = sin(TAU*7.0*age)*0.35*out
	if _time >= _next_flick:
		_flick = _time
		var every := FLICK_WATCH if mode in ["watch","pace"] else FLICK_EVERY
		_next_flick = _time+_rng.randf_range(every.x,every.y)
	var tongue := hd.rotated(head_side,0.12+flutter)
	var tongue_up := head_up.rotated(head_side,0.12+flutter)
	var ts := maxf(out,0.001)
	_skeleton.set_bone_pose(STATIONS+1,Transform3D(Basis(head_side*ts,tongue_up*ts,tongue*ts),held+hd*(HEAD*0.97)-head_up*RADIUS*girth*0.22))
	lo = lo.min(_snout).min(held)
	hi = hi.max(_snout).max(held)
	var pad := Vector3.ONE*(RADIUS*girth*2.0+HAZE*2.0+4.0)
	_body.custom_aabb = AABB(lo-pad,hi-lo+pad*2.0)

## The runes' run and the light by the hour: brighter after dark.
func _light(_delta: float) -> void:
	var night := StoneLampLights.night_for(_daylight())
	_material.set_shader_parameter("scroll",_scroll)
	_material.set_shader_parameter("energy",lerpf(DAY_GLOW,NIGHT_GLOW,night))
	_material.set_shader_parameter("eye_energy",lerpf(EYE_DAY,EYE_NIGHT,night))
	_haze.set_shader_parameter("strength",lerpf(HAZE_STRENGTH.x,HAZE_STRENGTH.y,night))
	_ribbon_material.set_shader_parameter("night",night)

func _daylight() -> float:
	var celestial: Variant = scene.get("_celestial") if scene != null else null
	if celestial != null and celestial.get("state") is Dictionary and celestial.state.has("zs_daylight"):
		return float(celestial.state.zs_daylight)
	return 1.0

static func _hermite(p0: Vector3, m0: Vector3, p1: Vector3, m1: Vector3, t: float) -> Vector3:
	var t2 := t*t
	var t3 := t2*t
	return p0*(2.0*t3-3.0*t2+1.0)+m0*(t3-2.0*t2+t)+p1*(-2.0*t3+3.0*t2)+m1*(t3-t2)

static func _smooth(x: float) -> float:
	x = clampf(x,0.0,1.0)
	return x*x*(3.0-2.0*x)

## Value at `t` through [time, value] keys, each segment eased.
static func _beats(t: float, keys: Array) -> float:
	var first: Array = keys[0]
	if t <= float(first[0]): return float(first[1])
	for i in range(keys.size()-1):
		var b: Array = keys[i+1]
		if t <= float(b[0]):
			var a: Array = keys[i]
			return lerpf(float(a[1]),float(b[1]),_smooth((t-float(a[0]))/maxf(1e-6,float(b[0])-float(a[0]))))
	return float(keys.back()[1])

## Three slow, seamless wander channels, roughly -1..1.
static func _drift(t: float, period: float) -> Vector3:
	var out := Vector3.ZERO
	for c in range(3):
		out[c] = 0.62*sin(TAU*t/period+1.7*c+2.3)+0.28*sin(TAU*2.0*t/period+1.7*c+4.6)+0.14*sin(TAU*3.0*t/period+1.7*c+6.9)
	return out

# --- The trailing lights -------------------------------------------------------------

func _build_ribbons() -> void:
	_ribbon_mesh = ImmediateMesh.new()
	_ribbon_material = ShaderMaterial.new()
	_ribbon_material.shader = RIBBON_SHADER
	_ribbon_material.set_shader_parameter("colour",GLOW)
	_ribbon_material.set_shader_parameter("strength",RIBBON_STRENGTH)
	_ribbons = MeshInstance3D.new()
	_ribbons.name = "Ribbons"
	_ribbons.mesh = _ribbon_mesh
	_ribbons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ribbons)
	for i in range(2): _whisker_trails.append(PackedVector3Array())

## The whiskers' roots laid down as the head goes, and the three ribbons
## drawn again, facing the eye: the whiskers through where their roots have
## been, the fin along the path behind the tail's tip.
func _ribbons_step() -> void:
	if _ribbons == null or _whisker_roots.size() < 2: return
	var most := int(ceil(WHISKER/RIBBON_STEP))+2
	var lines: Array = []
	for i in range(2):
		var root := _head_xf*_whisker_roots[i]
		var trail := _whisker_trails[i]
		if trail.is_empty() or trail[0].distance_to(root) >= RIBBON_STEP:
			trail.insert(0,root)
			if trail.size() > most: trail.resize(most)
		var points := PackedVector3Array([root])
		var length := 0.0
		for p in trail:
			length += p.distance_to(points[points.size()-1])
			if length > WHISKER: break
			if p.distance_to(points[points.size()-1]) > 0.05: points.append(p)
		lines.append([points,WHISKER,WHISKER_WIDTH,0.0,1.0])
	var fin := PackedVector3Array()
	var d := -2.0
	while d <= FIN:
		fin.append(trail_at(travelled-LENGTH-d)[0])
		d += 0.75
	lines.append([fin,FIN+2.0,Vector2(FIN_WIDTH,0.0),1.0,0.9])
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := camera.global_position if camera != null else _head_pos+Vector3.UP*100.0
	_ribbon_mesh.clear_surfaces()
	if eye.distance_to(_head_pos) > RIBBON_FAR+LENGTH: return
	_ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,_ribbon_material)
	var count := 0
	for line: Array in lines: count += _strip(line[0],float(line[1]),line[2],float(line[3]),float(line[4]),eye)
	if count == 0:
		# An empty surface is an error: one unseen triangle.
		for k in range(3):
			_ribbon_mesh.surface_set_color(Color(1,1,1,0))
			_ribbon_mesh.surface_add_vertex(_head_pos)
	_ribbon_mesh.surface_end()

## One ribbon through `points` (root first), `length` m at full: its width
## from `width.x` at the root to `width.y` at the tip (a fin swells first,
## `fin` 1), fluttering and (a whisker) sagging toward its tip. Returns the
## triangles laid.
func _strip(points: PackedVector3Array, length: float, width: Vector2, fin: float, alpha: float, eye: Vector3) -> int:
	var n := points.size()
	if n < 2: return 0
	var placed := PackedVector3Array()
	var shares := PackedFloat32Array()
	placed.resize(n)
	shares.resize(n)
	var along := 0.0
	for i in range(n):
		if i > 0: along += points[i].distance_to(points[i-1])
		var t := clampf(along/length,0.0,1.0)
		var way := (points[mini(i+1,n-1)]-points[maxi(i-1,0)]).normalized()
		var side := way.cross(Vector3.UP).normalized()
		var wave := sin(TAU*FLUTTER_RATE*_time-t*7.0+fin*1.7)
		var p := points[i]+side*wave*FLUTTER*pow(t,1.5)*(1.0+fin)
		p += Vector3.UP*(cos(TAU*FLUTTER_RATE*0.7*_time-t*5.0)*FLUTTER*0.5*t-WHISKER_SAG*t*t*(1.0-fin))
		placed[i] = p
		shares[i] = t
	# Each point's two edges, across the ribbon as the eye sees it.
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	left.resize(n)
	right.resize(n)
	for i in range(n):
		var p := placed[i]
		var t := shares[i]
		var way := placed[mini(i+1,n-1)]-placed[maxi(i-1,0)]
		var across := way.cross(eye-p)
		across = across.normalized() if across.length_squared() > 1e-8 else Vector3.UP
		var w := lerpf(width.x,width.y,t) if fin < 0.5 else width.x*smoothstep(0.0,0.22,t)*(1.0-0.75*t)
		left[i] = p-across*w*0.5
		right[i] = p+across*w*0.5
	var colour := Color(1,1,1,alpha)
	for i in range(n-1):
		var a := shares[i]
		var b := shares[i+1]
		_ribbon_vertex(left[i],a,0.0,colour)
		_ribbon_vertex(left[i+1],b,0.0,colour)
		_ribbon_vertex(right[i+1],b,1.0,colour)
		_ribbon_vertex(left[i],a,0.0,colour)
		_ribbon_vertex(right[i+1],b,1.0,colour)
		_ribbon_vertex(right[i],a,1.0,colour)
	return (n-1)*2

func _ribbon_vertex(p: Vector3, along: float, across: float, colour: Color) -> void:
	_ribbon_mesh.surface_set_color(colour)
	_ribbon_mesh.surface_set_uv(Vector2(along,across))
	_ribbon_mesh.surface_add_vertex(p)

# --- Solid to the plane --------------------------------------------------------------

## Capsules along it on the bump's layer, one over every CAPSULE_RINGS rings
## and one for the head, each as thick as its rings.
func _build_solid() -> void:
	_solid = AnimatableBody3D.new()
	_solid.name = "Solid"
	_solid.collision_layer = SOLID_LAYER
	_solid.collision_mask = 0
	_solid.sync_to_physics = false
	add_child(_solid)
	var k := 0
	while k < STATIONS-1:
		var to := mini(k+CAPSULE_RINGS,STATIONS-1)
		var r := 0.0
		for i in range(k,to+1): r = maxf(r,_radius[i])
		_add_capsule(r*CAPSULE_SHARE,_arc[to]-_arc[k])
		_capsule_rings.append(Vector2i(k,to))
		k = to
	_add_capsule(RADIUS*girth*0.85,HEAD)
	_capsule_rings.append(Vector2i(-1,-1))

func _add_capsule(radius: float, length: float) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = maxf(radius,0.2)
	shape.height = length+shape.radius*2.0
	var c := CollisionShape3D.new()
	c.shape = shape
	_solid.add_child(c)
	_capsules.append(c)

## Each capsule laid along its rings now (the head's from its back to its snout).
func _place_solid() -> void:
	if _solid == null: return
	for i in range(_capsules.size()):
		var pair := _capsule_rings[i]
		var a := _head_pos if pair.x < 0 else _pos[pair.x]
		var b := _snout if pair.x < 0 else _pos[pair.y]
		var axis := b-a
		if axis.length() < 1e-3: continue
		var y := axis.normalized()
		var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
		_capsules[i].transform = Transform3D(Basis(x,y,x.cross(y)),(a+b)*0.5)

## Its capsules solid to the plane or not (a rider's hulls standing in
## for them: scripts/kit_isle/serpent_rider.gd).
func set_solid(on: bool) -> void:
	if _solid != null: _solid.collision_layer = SOLID_LAYER if on else 0

## The body's physics RID (tests keep it out of their own queries).
func solid_rid() -> RID:
	return _solid.get_rid() if _solid != null else RID()

# --- Probes --------------------------------------------------------------------------

## This frame's ring places, head first, and their radii.
func rings() -> PackedVector3Array:
	return _pos

func radii() -> PackedFloat32Array:
	return _radius

func stations() -> PackedFloat32Array:
	return _arc

## Ring `k`'s place and turn as posed this frame (its bone: across, up and
## along toward the head, scaled by its breath), and its octagon's corners
## in that frame (the faces between two rings' corners are its skin).
func ring_frame(k: int) -> Transform3D:
	return _skeleton.get_bone_pose(k)

func ring_corners(k: int) -> Array[Vector3]:
	return _octagon(_radius[k],1.0,SQUASH,0.0,k,HEWN if k >= 2 and k < STATIONS-3 else 0.0)

## The head's place and turn as posed this frame (its bone: across, up and
## along toward the snout), and its section `i`'s corners (HEAD_SECTIONS,
## back to front; the brows raised over the eyes) in that frame, laid flat
## at its back: section i stands HEAD times its share along from there.
func head_frame() -> Transform3D:
	return _head_xf

func head_corners(i: int) -> Array[Vector3]:
	var hr := RADIUS*girth*_profile(0.0)*HEAD_GIRTH
	var spec: Array = HEAD_SECTIONS[i]
	var section := _octagon(hr,float(spec[0]),float(spec[1])*SQUASH,0.0,-1,0.0,false)
	if i == 2:
		for j: int in [0,1]: section[j] += Vector3(signf(section[j].x)*0.06*hr,0.14*hr,0.0)
	return section

## The head's back, its way, its snout; its pace now (m/s).
func head() -> Vector3:
	return _head_pos

func head_dir() -> Vector3:
	return _head_dir

func snout() -> Vector3:
	return _snout

func speed() -> float:
	return _sx[S_SPEED]

func spring(i: int) -> float:
	return _sx[i]

func marks() -> Dictionary:
	return _marks

# --- Watching it ---------------------------------------------------------------------

## Into the plane, flying alongside it: off its right side by its middle
## (MEET: back, out, up from its head) on its way at its pace, so the chase
## camera has its head ahead and its body beside.
func meet() -> void:
	if scene == null or not scene.has_method("board"): return
	scene.board()
	var plane: Variant = scene.get("plane")
	if plane == null: return
	var way := _route_way(s)
	var right := way.cross(Vector3.UP).normalized()
	plane.position = _head_pos-way*MEET.x+right*MEET.y+Vector3.UP*MEET.z
	plane.heading = atan2(-way.x,-way.z)
	plane.pitch = 0.0
	plane.speed = _sx[S_SPEED]
	plane.velocity = plane.forward()*float(plane.speed)
	var chase: Variant = scene.get("chase")
	if chase != null: chase.reset(plane,plane.position-plane.forward()*8.0+Vector3.UP*2.5,scene.camera.fov)

## The camera on it (--serpent-cam, not while flying): beside it (side,
## left), where a plane pacing it would be (pace), under it against the sky
## (below), ahead looking back at its face (head), well off and above
## (far), or from the isle's hill (hill); following smoothly.
func _camera_step(delta: float) -> void:
	if cam_mode == "" or scene == null or scene.get("flying") or scene.camera == null: return
	var mid := _pos[STATIONS/3]
	var way := _route_way(s-LENGTH*0.3)
	var right := way.cross(Vector3.UP).normalized()
	var head_way := _route_way(s)
	var head_right := head_way.cross(Vector3.UP).normalized()
	var eye := Vector3.ZERO
	var look := Vector3.ZERO
	match cam_mode:
		"left":
			eye = mid-right*60.0+Vector3.UP*14.0
			look = mid.lerp(_head_pos,0.4)
		"pace":
			# Off the outside of its turn, a little behind its head.
			var out := -signf(_route_turn(s)) if absf(_route_turn(s)) > 0.002 else -1.0
			eye = _head_pos-head_way*10.0+head_right*out*26.0+Vector3.UP*3.0
			look = _head_pos+head_way*4.0
		"below":
			eye = mid-Vector3.UP*40.0+right*18.0
			look = mid+Vector3.UP*4.0
		"head":
			eye = _head_pos+head_way*26.0+head_right*12.0+Vector3.UP*5.0
			look = _head_pos.lerp(mid,0.25)
		"far":
			# A wide shot from well off its side and above: the whole of it
			# and the way it takes (dives, breaches).
			eye = mid+right*150.0+Vector3.UP*45.0
			look = mid
		"hill":
			if _cam_hill == Vector3.INF: _cam_hill = _hill_eye()
			eye = _cam_hill
			look = mid.lerp(_head_pos,0.3)
		_:
			eye = mid+right*60.0+Vector3.UP*14.0
			look = mid.lerp(_head_pos,0.4)
	if _cam_eye == Vector3.INF:
		_cam_eye = eye
		_cam_look = look
	var k := 1.0-exp(-CAM_FOLLOW*delta)
	_cam_eye = _cam_eye.lerp(eye,k)
	_cam_look = _cam_look.lerp(look,k)
	scene.camera.global_position = _cam_eye
	if _cam_eye.distance_to(_cam_look) > 0.1: scene.camera.look_at(_cam_look,Vector3.UP)

## An eye on the isle's hill, over the stone circle on its summit.
func _hill_eye() -> Vector3:
	var at := Vector3(58.0,200.0,2.0)
	var ray := PhysicsRayQueryParameters3D.create(at,Vector3(at.x,-50.0,at.z),1|(1 << 11))
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return ((hit.position as Vector3) if not hit.is_empty() else Vector3(58.0,46.0,2.0))+Vector3.UP*HILL_EYE

# --- The mesh ------------------------------------------------------------------------

## The skeleton (a bone a ring, then the head, tongue and jaw) and the body
## skinned to it: the stone with its runes, and the eyes' haze.
func _build_body() -> void:
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Serpent"
	add_child(_skeleton)
	var skin := Skin.new()
	for k in range(STATIONS+3):
		_skeleton.add_bone("ring%d" % k if k < STATIONS else ["head","tongue","jaw"][k-STATIONS])
		skin.add_bind(k,Transform3D.IDENTITY)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("glow",GLOW)
	_material.set_shader_parameter("eye_glow",EYE_GLOW)
	_material.set_shader_parameter("fill",FILL)
	_material.set_shader_parameter("rim",RIM)
	_material.set_shader_parameter("spine_reach",LENGTH*0.86)
	_material.set_shader_parameter("spine_cell",SPINE_CELL)
	_haze = ShaderMaterial.new()
	_haze.shader = GLOW_SHADER
	_haze.set_shader_parameter("colour",EYE_GLOW)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = _build_mesh()
	_body.skin = skin
	_body.skeleton = NodePath("..")
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_skeleton.add_child(_body)

func _build_mesh() -> ArrayMesh:
	var mesh := MeshParts.new()
	# The rings, each its own true-ish octagon: crest, belly, hewn corners.
	var rings: Array = []
	for k in range(STATIONS): rings.append(ring_corners(k))
	var bands := {}
	for k in range(3,STATIONS-5):
		if k%BAND_EVERY == 0 and Variety.unit([k,41]) >= BAND_SKIP: bands[k] = true
	for k in range(STATIONS-1):
		var seg := _arc[k+1]-_arc[k]
		var tone := 1.0+(Variety.unit([k,17])-0.5)*SEGMENT_TONE
		var stone := STONE.lerp(COOL,Variety.unit([k,23]))
		for j in range(8):
			var n := (j+1)%8
			var colour := stone*float(FACE_TONE[j])*tone
			if j == 4: colour = UNDER*tone
			if k == 0 and j != 4: colour = CRESCENT
			if Variety.unit([k,j,59]) < 0.08: colour = colour*(1.0+WORN)
			var what := 0
			var width: float = (rings[k][j] as Vector3).distance_to(rings[k][n])
			if k > 0 and j == 0: what = 1
			elif bands.has(k) and j != 4 and j != 0: what = 2
			var count := maxf(1.0,roundf(seg/(width*0.95)))
			var aspect := SPINE_CELL/maxf(width,0.05) if what == 1 else (seg/count)/maxf(width,0.05)
			mesh.paint(colour,what,aspect,float(k*8+j),count)
			mesh.quad(rings[k][j],k,rings[k][n],k,rings[k+1][j],k+1,rings[k+1][n],k+1,-_arc[k],-_arc[k+1],_arc[k],_arc[k+1])
	# The head on its bone: wider than the neck at its jowls, flat on top,
	# brows over the eyes, a blunt snout; the jaw (the lower faces) on its
	# own bone, hinged at the head's back, whose back edge stays with the
	# head so the corner of the mouth stretches.
	var hr := RADIUS*girth*_profile(0.0)*HEAD_GIRTH
	var secs: Array = []
	for i in range(HEAD_SECTIONS.size()):
		var section := head_corners(i)
		for j in range(8): section[j].z = HEAD*float(HEAD_SECTIONS[i][2])
		secs.append(section)
	var tip := Vector3(0.0,-0.06*hr,HEAD)
	var h := STATIONS
	var jaw := STATIONS+2
	var upper := [6,7,0,1,2]
	var s0: Array = secs[0]
	for j in range(8):
		var n := (j+1)%8
		# The collar: from the head's back to the first ring, a ring of runes.
		var collar := UNDER if j == 4 else CRESCENT
		var collar_w: float = ((s0[j] as Vector3).distance_to(s0[n])+(rings[0][j] as Vector3).distance_to(rings[0][n]))*0.5
		mesh.paint(collar,0 if j == 4 else 3,(_arc[0]-HEAD)/maxf(collar_w,0.05),float(900+j),1.0)
		mesh.quad(s0[j],h,s0[n],h,rings[0][j],0,rings[0][n],0,0.0,-(_arc[0]-HEAD),HEAD,_arc[0])
		var bone := h if j in upper else jaw
		var top := STONE*float(FACE_TONE[j])*1.04 if j in upper else (UNDER if j == 4 else LIP)
		for i in range(1,secs.size()):
			var front: Array = secs[i]
			var back: Array = secs[i-1]
			var back_bone := h if i == 1 else bone
			# A sigil on the brow, between the eyes.
			mesh.paint(top,7 if j == 0 and i == 2 else 0,0.9,77.0,1.0)
			mesh.quad(front[j],bone,front[n],bone,back[j],back_bone,back[n],back_bone,0.0,0.0,HEAD*(1.0-float(HEAD_SECTIONS[i][2])),HEAD*(1.0-float(HEAD_SECTIONS[i-1][2])))
		# The blunt nose closed in a fan to its tip (wound as the sections'
		# quads are, so it shows from outside).
		mesh.paint(top,0,1.0,0.0,1.0)
		mesh.tri(tip,bone,secs[-1][j],bone,secs[-1][n],bone,0.0,0.0,0.0,false,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector3(0.0,HEAD*0.03,HEAD*0.03))
	# Inside the mouth, along the lip line (corners 3 and 6): a palate on the
	# head and a floor on the jaw, warm with its light.
	mesh.paint(MOUTH,5,1.0,0.0,1.0)
	for bone: int in [h,jaw]:
		for i in range(1,secs.size()):
			var back_bone := h if i == 1 else bone
			mesh.quad(secs[i][3],bone,secs[i][6],bone,secs[i-1][3],back_bone,secs[i-1][6],back_bone,0.0,0.0,0.0,0.0,true,true)
		mesh.tri(secs[-1][3],bone,tip,bone,secs[-1][6],bone,0.0,0.0,0.0,true)
		mesh.tri(secs[-1][6],bone,tip,bone,secs[-1][3],bone,0.0,0.0,0.0,true)
	# The whiskers' roots: the corners of the mouth at the snout.
	for j: int in [3,6]:
		var corner: Vector3 = secs[3][j]
		_whisker_roots.append(corner+Vector3(signf(corner.x)*0.15,0.0,0.0))
	# Eyes alight on the upper flanks under the brows, between the jowls
	# and the brow.
	var eyes: Array[Vector3] = []
	for j: int in [1,7]:
		var n := (j+1)%8
		var behind: Vector3 = ((secs[1][j] as Vector3)+secs[1][n])*0.5
		var ahead: Vector3 = ((secs[2][j] as Vector3)+secs[2][n])*0.5
		var center := behind.lerp(ahead,0.62)
		var along := (ahead-behind).normalized()
		var across: Vector3 = ((secs[2][n] as Vector3)-secs[2][j]).normalized()
		var out := along.cross(across).normalized()
		if out.dot(Vector3(center.x,center.y,0.0)) < 0.0: out = -out
		center += out*0.05
		eyes.append(center+out*0.25)
		var length := along*EYE_SIZE.x*hr
		var width := across*EYE_SIZE.y*hr
		# A socket the shader lights as an almond of light with a slit pupil.
		mesh.paint(Color(0.1,0.1,0.1),4,1.0,0.0,1.0)
		mesh.quad(center+length-width,h,center+length+width,h,center-length-width,h,center-length+width,h,0.0,0.0,HEAD*0.4,HEAD*0.4,false,true)
	# A forked tongue of light, flat both ways.
	var t := STATIONS+1
	var w := 0.08
	mesh.paint(Color(0.2,0.2,0.2),6,1.0,0.0,1.0)
	for plane in [Vector3(1,0,0),Vector3(0,1,0)]:
		mesh.quad(plane*w+Vector3(0,0,1.1),t,-plane*w+Vector3(0,0,1.1),t,plane*w,t,-plane*w,t,0.0,0.0,0.0,0.0,true,true)
		for fork in [-1.0,1.0]:
			mesh.tri(plane*w*0.7+Vector3(0,0,1.05),t,Vector3(fork*0.26,0,1.8),t,-plane*w*0.7+Vector3(0,0,1.05),t,0.0,0.0,0.0,true)
			mesh.tri(-plane*w*0.7+Vector3(0,0,1.05),t,Vector3(fork*0.26,0,1.8),t,plane*w*0.7+Vector3(0,0,1.05),t,0.0,0.0,0.0,true)
	var built := mesh.commit(_material)
	# The eyes' haze: a quad each, its corners at the eye, spread facing you.
	var haze := HazeParts.new()
	for e in eyes: haze.light(e,h,HAZE,1.0)
	haze.commit(built,_haze)
	return built

## An octagon ring (8 corners, corner j at 67.5 + 45 j degrees, so face 0
## is the back, 4 the belly): `w` wide and `hgt` high shares of `r`, the
## back's corners drawn in and up to a crest, the belly's out; ring `k`'s
## corners hewn `hewn` of `r` in or out of true.
static func _octagon(r: float, w: float, hgt: float, z: float, k: int, hewn: float, crest := true) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for j in range(8):
		var a := deg_to_rad(67.5+45.0*j)
		var x := cos(a)*r*w
		var y := sin(a)*r*hgt
		if crest and (j == 0 or j == 1):
			x *= CREST.x
			y *= CREST.y
		elif j == 4 or j == 5:
			x *= BELLY
		var true_off := 1.0+(Variety.unit([k,j,5])-0.5)*2.0*hewn if hewn > 0.0 else 1.0
		points.append(Vector3(x*true_off,y*true_off,z))
	return points

## The stone's faces, each a flat facet (its normal from where its corners
## lie with the rings laid out straight), skinned a bone a corner; what it
## is painted (`paint`) carried by its colour, UV, UV2 and CUSTOM0 (shaders/
## rune_serpent.gdshader).
class MeshParts:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var custom := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var _colour := Color.WHITE
	var _what := 0.0
	var _aspect := 1.0
	var _seed := 0.0
	var _count := 1.0

	## What the next faces are: their colour (sRGB), what (the shader's
	## code), a glyph cell's length over its height, a seed, glyphs along.
	func paint(colour: Color, what: int, aspect: float, seed_value: float, count: float) -> void:
		var linear := colour.srgb_to_linear()
		_colour = Color(linear.r,linear.g,linear.b,1.0)
		_what = float(what)
		_aspect = aspect
		_seed = seed_value
		_count = count

	## A triangle; `za`..`zc` where its corners lie along the straight body
	## (for the facet's normal), `arc_*` m back from the snout. UVs are the
	## face's square (along, across), given by `quad`.
	func tri(a: Vector3, ba: int, b: Vector3, bb: int, c: Vector3, bc: int, za: float, zb: float, zc: float, keep_normal := false, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, arcs := Vector3.ZERO) -> void:
		var ra := a+Vector3(0,0,za)
		var rb := b+Vector3(0,0,zb)
		var rc := c+Vector3(0,0,zc)
		var normal := (rb-ra).cross(rc-ra)
		if normal.length_squared() < 1e-12: normal = Vector3.UP
		normal = normal.normalized()
		var mid := (ra+rb+rc)/3.0
		if not keep_normal and normal.dot(Vector3(mid.x,mid.y,0.0)) < 0.0: normal = -normal
		# Godot's front faces wind clockwise as seen: laid a, c, b, so the
		# side the normal points to is the side that shows.
		var corners := [[a,ba,ua,arcs.x],[c,bc,uc,arcs.z],[b,bb,ub,arcs.y]]
		for corner: Array in corners:
			vertices.append(corner[0])
			normals.append(normal)
			colors.append(_colour)
			uvs.append(corner[2])
			uv2s.append(Vector2(_seed,_count))
			custom.append_array([_what,_aspect,float(corner[3]),0.0])
			bones.append_array([int(corner[1]),0,0,0])
			weights.append_array([1.0,0.0,0.0,0.0])

	## Front edge a-b, back edge c-d; za/zb the front and back edges' places
	## along the straight body (normals), arc_f/arc_b their metres back from
	## the snout.
	## `both` draws it from behind too (its other side's normal by its
	## winding when `keep_normal`, else outward as the front's).
	func quad(a: Vector3, ba: int, b: Vector3, bb: int, c: Vector3, bc: int, d: Vector3, bd: int, za: float, zc: float, arc_f: float, arc_b: float, keep_normal := false, both := false) -> void:
		tri(a,ba,c,bc,d,bd,za,zc,zc,keep_normal,Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector3(arc_f,arc_b,arc_b))
		tri(a,ba,d,bd,b,bb,za,zc,za,keep_normal,Vector2(0,0),Vector2(1,1),Vector2(0,1),Vector3(arc_f,arc_b,arc_f))
		if both:
			tri(b,bb,d,bd,c,bc,za,zc,zc,keep_normal,Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector3(arc_f,arc_b,arc_b))
			tri(b,bb,c,bc,a,ba,za,zc,za,keep_normal,Vector2(0,1),Vector2(1,0),Vector2(0,0),Vector3(arc_f,arc_b,arc_f))

	func commit(material: Material) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.surface_set_material(0,material)
		return mesh

## The soft lights' quads (shaders/rune_serpent_glow.gdshader): every
## corner at the light's middle on its bone, UV the corner, UV2 its radius
## and how far toward the eye it is drawn.
class HazeParts:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()

	func light(at: Vector3, bone: int, radius: float, toward: float) -> void:
		for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
			vertices.append(at)
			uvs.append(corner)
			uv2s.append(Vector2(radius,toward))
			bones.append_array([bone,0,0,0])
			weights.append_array([1.0,0.0,0.0,0.0])

	func commit(mesh: ArrayMesh, material: Material) -> void:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var up := PackedVector3Array()
		up.resize(vertices.size())
		up.fill(Vector3.UP)
		arrays[Mesh.ARRAY_NORMAL] = up
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,material)
