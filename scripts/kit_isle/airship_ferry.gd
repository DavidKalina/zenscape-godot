extends Node3D
## The sky folk's ferry (docs/design/airship-ferry/round1.md, round2.md):
## one of the aqueduct isle's airships (studies/aqueduct_isle_sky.gd, the
## ship scripts/sky_airship.gd builds, scripts/airship_build.gd) flown on a
## fixed loop that shuttles round five isles, comes to rest beside a turf
## edge at each and carries the pilot on foot between them. It is the way
## to the bell spires on foot, where the plane's cowl is jammed under the
## belfry's bell, and the plane's tail fin lies on its foredeck
## (scripts/plane_arc/part_spots.gd).
##
## The ship is SCALE times the sky folk's own, so its foredeck (about 4 m
## by 2.5) takes him; its solid (the hull's half shell up to the flat
## deck, the cabin, the envelope's capsules: the others' shapes, scaled) a
## body of its own, moved with it each frame and at once in the physics
## space, so his ground reads the deck where it is now.
##
## The loop (ROUTE, a closed Catmull-Rom through the points, about 1950 m,
## some seven and a half minutes a lap). Each stop was found by rays on the
## stood isles: the deck level with the turf (the gorge's a step under),
## the hull's side 0.3 to 0.6 m off the edge by the foredeck, its
## neighbours along the edge so it rests square to it (a stop's departure
## veers out from the edge: going straight on, the hull met the rim's
## jags); the whole lap keeps hull, cabin and envelope off every
## isle and its kit, and passes some 25 m under the tarn's airship's loop
## (studies/aqueduct_isle_sky.gd ROUTES, raised for it).
##   home   it comes in from the east along the aqueduct isle's south edge,
##          past the parked plane, and rests heading west by the start, the
##          isle to starboard.
##   gorge  west along the isle's south side and on west to the Sundered
##          gorge, resting heading south by its east half's east edge (the
##          isle to starboard), the deck a step (0.3 m) under the turf: the
##          rim there is bevelled, and level with it a walk aboard went down
##          the bevel into the gap; the gate tower and the rope bridge are
##          across the half, west.
##   nave   south down the gap to the drowned nave, resting heading south
##          by its west edge (the isle to port).
##   tarn   round the nave's south tip, east under the cloister tarn and up
##          its east side, resting heading north by its east edge just south
##          of the falls (the isle to port).
##   bell   north-east to the bell spires, round their north and down their
##          west lobe, resting heading south (the isle to port): off, the
##          low stair's foot is some twenty-five metres east, the belfry up
##          it and the hero's stair (PartSpots `cowl`).
##   back   it turns west short of the floating stone south of the lobe
##          and goes home, coming down to the south edge from the east.
## Between the stops it eases up to CRUISE and down again at EASE (a
## long, slow glide in and out), and rests HOLD s at each. Its place is a
## function of its clock alone (`pose_at`), so a start can put it anywhere
## on its lap.
##
## Carried, each frame before his step (this runs ahead of the scene, as
## the serpent rider does: process priority -100, the scene's 0):
##   1. what he is on after his last step: the deck (a ray under his feet
##      meets its body; or a ledge he hangs from on its edge), other
##      ground, or the air;
##   2. the ship and its body moved on along the loop;
##   3. carried: on the deck, by its move (PilotMotor `carry`: feet, pace
##      and facing turned with it), the camera with him, its turn taken up
##      over CAM_TURN; in the air off it, by the frame he left in (its pace
##      at his feet), held while he is within AIR_HOLD m under where he left
##      and fading over AIR_FADE s past that or under the sail. So a jump on
##      the deck lands where it went, and a jump off it at a stop is a jump
##      off still ground.
##
## Flags (the game's, after --):
##   --no-ferry                 the ferry left out (--no-airships leaves
##                              every ship out; --serpent --serpent-old-route
##                              it too)
##   --ferry-aboard[=<stop>]    start on its foredeck: at home (the
##                              default) a few seconds before it leaves;
##                              at another stop, ARRIVE_LEAD s before it
##                              comes to rest there
##   --ferry-at=<stop>          start on foot at the stop's edge, the
##                              ferry coming in (WAIT_LEAD s off)
## A stop is home, gorge, nave, tarn or bell, or its isle's motif id
## (STOP_ISLES: sundered_gorge, drowned_nave, cloister_tarn, bell_spires);
## its isle is stood up at once.
const AirshipBuild = preload("res://scripts/airship_build.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The ferry's size over the sky folk's ship (AirshipBuild's metres).
const SCALE := 1.8
## The loop (world): [point (the ship's origin, its deck DECK over it), the
## stop resting there, or "", and for a stop its isle's side (+1 starboard,
## -1 port)]. A stop's neighbours lie along its edge, so it rests square to
## it.
const ROUTE := [
	[Vector3(92.0,29.93,18.5),"home",1.0],
	[Vector3(82.0,30.8,20.6),""],
	[Vector3(73.0,37.0,25.0),""],
	[Vector3(62.0,43.0,34.0),""],
	[Vector3(40.0,46.0,46.0),""],
	[Vector3(-20.0,46.0,54.0),""],
	[Vector3(-100.0,45.0,58.0),""],
	[Vector3(-170.0,43.0,56.0),""],
	[Vector3(-215.0,40.5,56.0),""],
	[Vector3(-240.0,39.0,58.0),""],
	[Vector3(-250.0,38.0,73.0),""],
	[Vector3(-250.65,37.26,84.0),"gorge",1.0],
	[Vector3(-250.2,37.9,94.0),""],
	[Vector3(-249.5,38.5,108.0),""],
	[Vector3(-256.0,38.0,160.0),""],
	[Vector3(-282.0,36.0,230.0),""],
	[Vector3(-294.0,33.0,290.0),""],
	[Vector3(-294.5,31.4,331.0),""],
	[Vector3(-294.5,31.04,341.0),"nave",-1.0],
	[Vector3(-294.6,31.4,351.0),""],
	[Vector3(-295.5,32.0,372.0),""],
	[Vector3(-276.0,33.0,402.0),""],
	[Vector3(-235.0,34.0,420.0),""],
	[Vector3(-150.0,35.0,420.0),""],
	[Vector3(-50.0,35.0,414.0),""],
	[Vector3(20.0,34.0,414.0),""],
	[Vector3(70.0,33.5,414.0),""],
	[Vector3(93.0,32.5,406.0),""],
	[Vector3(96.0,31.6,385.0),""],
	[Vector3(96.55,31.24,375.03),"tarn",-1.0],
	[Vector3(97.9,31.7,365.1),""],
	[Vector3(100.5,32.5,353.0),""],
	[Vector3(108.0,34.0,338.0),""],
	[Vector3(125.0,37.0,322.0),""],
	[Vector3(175.0,41.0,260.0),""],
	[Vector3(250.0,46.0,150.0),""],
	[Vector3(275.0,46.0,60.0),""],
	[Vector3(310.0,45.0,16.0),""],
	[Vector3(360.0,44.0,14.0),""],
	[Vector3(380.0,43.0,26.0),""],
	[Vector3(385.6,42.4,41.0),""],
	[Vector3(385.8,41.73,52.5),"bell",-1.0],
	[Vector3(384.0,42.8,62.0),""],
	[Vector3(376.0,44.5,68.0),""],
	[Vector3(362.0,47.0,70.0),""],
	[Vector3(300.0,50.0,80.0),""],
	[Vector3(220.0,48.0,64.0),""],
	[Vector3(165.0,41.0,40.0),""],
	[Vector3(124.0,32.6,21.6),""],
	[Vector3(109.0,30.8,19.8),""],
]
## The deck's top over the ship's origin (m): the hull's flat top.
const DECK := 0.02*SCALE
## Where he stands aboard (ship frame, m): the foredeck's middle.
const FOREDECK := Vector3(0.0,DECK,-1.25*SCALE)
## Pace between stops (m/s), its easing in and out (m/s²), the rest at
## each stop (s).
const CRUISE := 7.0
const EASE := 0.3
const HOLD := 14.0
## Its bank per radian a second of turn, and the most (gentler than the
## other ships': he stands on it).
const BANK := 0.5
const BANK_MOST := 0.05
## The table the loop is read from: a sample every this many m (about).
const SAMPLE := 0.25
## The loop is first sampled this many times between two of its points.
const FINE := 400
## The camera takes up the ship's turn over this many seconds.
const CAM_TURN := 0.6
## The frame he left it in, held while he is within AIR_HOLD m under where
## he left; past that, or under the sail, it fades over AIR_FADE s.
const AIR_HOLD := 6.0
const AIR_FADE := 1.5
## --ferry-aboard=<stop> (not home) starts this long (s) before it comes
## to rest there; --ferry-aboard (home) this long before it leaves;
## --ferry-at this long before it comes to rest.
const ARRIVE_LEAD := 25.0
const LEAVE_LEAD := 4.0
const WAIT_LEAD := 20.0
## Where the clock starts by default: coming in to home, this long before
## it rests there (s), so it is seen gliding in by the start.
const START_LEAD := 12.0
## Each stop's motif isle (stood up at once by a start there), its id also
## a name for the stop in the flags.
const STOP_ISLES := {"gorge":"sundered_gorge","nave":"drowned_nave","tarn":"cloister_tarn","bell":"bell_spires"}
## The solid's layer (the sky's SOLID_LAYER: the plane bumps it, his ground
## reads it).
const LAYER := 1

var scene: Node3D
## The ship (SkyAirship: its `_ship` the drawn ship) and its own body.
var ship: Node3D
var body: StaticBody3D
## Driven by hand (a test calls `step` itself).
var manual := false
## Its clock (s, round the lap) and the lap's length (s).
var clock := 0.0
var lap := 0.0
## The pose now (unscaled: the body's) and its heading, bank, pace.
var pose := Transform3D.IDENTITY
var heading := 0.0
var pace := 0.0
## What he is on: "deck", "still", "air"; whether he went up into the air
## off the deck; times he has got aboard (onto it from anything else).
var riding_on := "still"
var from_deck := false
var boardings := 0
## His feet's carry this frame and the frame he left in (m/s).
var carry_v := Vector3.ZERO
var air_v := Vector3.ZERO
## The start asked for (--ferry-aboard, --ferry-at), or "".
var start_aboard := ""
var start_at := ""
var _air_ref := 0.0
var _turn_owed := 0.0
## The loop's table: positions every SAMPLE m, and their arcs.
var _points := PackedVector3Array()
var _arcs := PackedFloat32Array()
## The fine samples' arcs (FINE a point of ROUTE), for the stops.
var _fine_arcs := PackedFloat32Array()
var _length := 0.0
## Each stop: {name, arc (m round the loop), at (s into the lap its rest
## begins)}; each leg after one: its length (m) and how long it takes (s).
var stops: Array[Dictionary] = []
## The loop: ROUTE unless another sets it before `setup` (a generated
## layer's gulf, scripts/roguelike/layer_rides.gd): [point, stop or "",
## and for a stop optionally its isle's side, +1 starboard, -1 port].
var route: Array = ROUTE
## The envelope's capsules (the sky's `envelope_solid`); empty: asked of
## the ship's parent, the sky.
var envelope_parts: Array = []

func _init() -> void:
	name = "Ferry"
	process_priority = -100

## Whether the ferry flies: the sky's ships do, and not --no-ferry. The
## serpent's old long way (--serpent with --serpent-old-route) runs down
## under the bell spires through its loop, so there it is left out.
static func wanted() -> bool:
	var args := LaunchArgs.user_args()
	return not args.has("--no-ferry") and not (args.has("--serpent") and args.has("--serpent-old-route"))

## Made round `airship` (a SkyAirship whose ship is made) for `study`.
func setup(study: Node3D, airship: Node3D) -> void:
	scene = study
	ship = airship
	ship._ship.scale = Vector3.ONE*SCALE
	_build_body()
	_lay_table()
	_lay_stops()
	for arg: String in LaunchArgs.user_args():
		if arg == "--ferry-aboard": start_aboard = "home"
		elif arg.begins_with("--ferry-aboard="): start_aboard = arg.get_slice("=",1)
		elif arg.begins_with("--ferry-at="): start_at = arg.get_slice("=",1)
	var first := stop("home")
	if first.is_empty(): first = stops[0]
	clock = fposmod(float(first.at)-START_LEAD,lap)
	_place(clock)
	if (start_aboard != "" or start_at != "") and scene.has_signal("isle_ready"):
		scene.isle_ready.connect(_flag_start,CONNECT_ONE_SHOT)

## Its solid: the gondola's hull and cabin and the envelope's capsules (the
## sky's own shapes for its ships), scaled.
func _build_body() -> void:
	body = StaticBody3D.new()
	body.name = "FerrySolid"
	body.collision_layer = LAYER
	# Passing through the sky, not the island's ground (the rune knight's
	# knocks, scripts/enemies/rune_knight.gd `knock_reach`, look past it).
	body.set_meta(&"aloft",true)
	body.collision_mask = 0
	for part: Vector3 in (envelope_parts if not envelope_parts.is_empty() else ship.get_parent().envelope_solid()):
		var envelope := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = part.z*SCALE
		capsule.height = (part.y-part.x+2.0*part.z)*SCALE
		envelope.shape = capsule
		envelope.transform = Transform3D(Basis(Vector3.RIGHT,PI*0.5),(AirshipBuild.ENVELOPE_AT+Vector3(0.0,0.0,(part.x+part.y)*0.5))*SCALE)
		body.add_child(envelope)
	for points: PackedVector3Array in AirshipBuild.gondola_hulls():
		var hull := ConvexPolygonShape3D.new()
		var scaled := PackedVector3Array()
		for p: Vector3 in points: scaled.append(p*SCALE)
		hull.points = scaled
		# Sharp: a rounded edge would lower the deck's rim under his feet.
		hull.margin = 0.0
		var shape := CollisionShape3D.new()
		shape.shape = hull
		body.add_child(shape)
	ship.add_child(body)

# --- The loop -----------------------------------------------------------------------

## The loop's points (world), as the sky's ships' loops are given (the
## sky's `_loop` through them is this loop).
static func loop_points() -> Array:
	return ROUTE.map(func(r: Array) -> Vector3: return r[0])

## This ferry's loop's points.
func loop() -> Array:
	return route.map(func(r: Array) -> Vector3: return r[0])

## A point on the loop's Catmull-Rom at `u` (0 to 1 round it).
func _spline(u: float) -> Vector3:
	return spline_of(route,u)

static func spline_of(points: Array, u: float) -> Vector3:
	var n := points.size()
	var f := fposmod(u,1.0)*n
	var i := int(f)
	var t := f-i
	var p0: Vector3 = points[(i-1+n)%n][0]
	var p1: Vector3 = points[i%n][0]
	var p2: Vector3 = points[(i+1)%n][0]
	var p3: Vector3 = points[(i+2)%n][0]
	return 0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t)

## The loop sampled finely, then laid out every SAMPLE m along it.
func _lay_table() -> void:
	var fine := route.size()*FINE
	var at := PackedVector3Array()
	var arcs := PackedFloat32Array()
	var run := 0.0
	var was := _spline(0.0)
	for k in range(fine+1):
		var p := _spline(float(k)/fine)
		run += p.distance_to(was)
		at.append(p)
		arcs.append(run)
		was = p
	_length = run
	_points.clear()
	_arcs.clear()
	var j := 0
	var s := 0.0
	while s < _length:
		while j < arcs.size()-2 and arcs[j+1] < s: j += 1
		var t := (s-arcs[j])/maxf(arcs[j+1]-arcs[j],1e-6)
		_points.append(at[j].lerp(at[j+1],t))
		_arcs.append(s)
		s += SAMPLE
	_fine_arcs = arcs

## Each stop's arc round the loop, and the lap's timeline: rest HOLD s, then
## the leg to the next stop eased in and out.
func _lay_stops() -> void:
	stops.clear()
	for i in range(route.size()):
		if str(route[i][1]) == "": continue
		var side := 1.0 if str(route[i][1]) == "home" else -1.0
		if (route[i] as Array).size() > 2: side = float(route[i][2])
		stops.append({"name":str(route[i][1]),"arc":_fine_arcs[i*FINE],"side":side})
	var t := 0.0
	for k in range(stops.size()):
		var a: float = stops[k].arc
		var b: float = stops[(k+1)%stops.size()].arc
		var leg := fposmod(b-a,_length) if stops.size() > 1 else _length
		stops[k].at = t
		stops[k].leg = leg
		stops[k].travel = _travel_time(leg)
		t += HOLD+float(stops[k].travel)
	lap = t

## The time an eased leg of `leg` m takes (s): up to CRUISE at EASE, on,
## and down again (never reaching CRUISE if it's short).
static func _travel_time(leg: float) -> float:
	var ramp := CRUISE*CRUISE/EASE
	if leg >= ramp: return 2.0*CRUISE/EASE+(leg-ramp)/CRUISE
	return 2.0*sqrt(leg/EASE)

## How far along an eased leg of `leg` m it is `t` s in (m), and its pace.
static func _eased(leg: float, t: float) -> Vector2:
	var total := _travel_time(leg)
	t = clampf(t,0.0,total)
	var top := minf(CRUISE,sqrt(leg*EASE))
	var up := top/EASE
	if t < up: return Vector2(0.5*EASE*t*t,EASE*t)
	if t > total-up:
		var left := total-t
		return Vector2(leg-0.5*EASE*left*left,EASE*left)
	return Vector2(0.5*EASE*up*up+top*(t-up),top)

## The stop named `n`, or {}.
func stop(n: String) -> Dictionary:
	for s: Dictionary in stops:
		if str(s.name) == n: return s
	return {}

## Where it is round the loop at clock `t`: [arc (m), pace (m/s), the stop
## it rests at or ""].
func state_at(t: float) -> Array:
	t = fposmod(t,lap)
	for s: Dictionary in stops:
		var into := t-float(s.at)
		if into < 0.0 or into >= HOLD+float(s.travel): continue
		if into < HOLD: return [float(s.arc),0.0,str(s.name)]
		var e := _eased(float(s.leg),into-HOLD)
		return [fposmod(float(s.arc)+e.x,_length),e.y,""]
	return [float(stops[0].arc),0.0,str(stops[0].name)]

## The loop's point at arc `s` (m).
func point(s: float) -> Vector3:
	s = fposmod(s,_length)
	var i := clampi(int(s/SAMPLE),0,_points.size()-1)
	var j := (i+1)%_points.size()
	var t := clampf((s-_arcs[i])/SAMPLE,0.0,1.0)
	return _points[i].lerp(_points[j],t)

## Its heading at arc `s` (radians, as the other ships': the bow toward
## -Z turned about up), from the loop's way there.
func heading_at(s: float) -> float:
	var way := point(s+1.5)-point(s-1.5)
	return atan2(-way.x,-way.z)

## Its pose at clock `t` (unscaled: the body's): along the loop, turned to
## its way, banked into its turn by its pace.
func pose_at(t: float) -> Transform3D:
	var st := state_at(t)
	var s: float = st[0]
	var v: float = st[1]
	var h := heading_at(s)
	var turn := angle_difference(heading_at(s-2.0),heading_at(s+2.0))/4.0*v
	var bank := clampf(-turn*BANK,-BANK_MOST,BANK_MOST)
	return Transform3D(Basis(Vector3.UP,h)*Basis(Vector3.BACK,bank),point(s))

## The ship and its body to clock `t`; the body moved in the physics space
## at once, so a ray this frame reads it where it is.
func _place(t: float) -> void:
	var st := state_at(t)
	pace = float(st[1])
	pose = pose_at(t)
	heading = heading_at(float(st[0]))
	ship._ship.transform = Transform3D(pose.basis*Basis.from_scale(Vector3.ONE*SCALE),pose.origin)
	body.global_transform = pose
	PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,pose)

## The stop it rests at now, or "".
func resting() -> String:
	return str(state_at(clock)[2])

## Where it is (its origin, world).
func at() -> Vector3:
	return pose.origin

## The foredeck's middle on the deck now (world).
func deck_point() -> Vector3:
	return pose*FOREDECK

# --- Each frame ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if manual or scene == null: return
	step(delta)

## Whether he walks now (the scene steps him this frame).
func on_foot() -> bool:
	if not bool(scene.get("walk_ready")) or bool(scene.get("flying")): return false
	return manual or not bool(scene.get("scripted"))

## A frame, before his own step: what he stood on, the ship on along its
## loop, he carried.
func step(delta: float) -> void:
	if delta <= 0.0: return
	var walking := on_foot()
	if walking: _contact()
	else: _reset_carry()
	var was := pose
	var was_heading := heading
	clock = fposmod(clock+delta,lap)
	_place(clock)
	if not walking: return
	var moved := pose*was.affine_inverse()
	_carry(moved,angle_difference(was_heading,heading),delta)
	var take := _turn_owed*(1.0-exp(-delta/CAM_TURN))
	scene._yaw += take
	_turn_owed -= take

## As after a set-down: nothing carried over.
func _reset_carry() -> void:
	riding_on = "still"
	from_deck = false
	air_v = Vector3.ZERO
	carry_v = Vector3.ZERO
	_turn_owed = 0.0

## What he is on after his last step (the body still where he stepped).
func _contact() -> void:
	var motor: PilotMotor = scene.motor
	var was := riding_on
	if motor.swimming: riding_on = "still"
	elif motor.on_ledge(): riding_on = "deck" if _on_deck(motor.lip-Vector3(motor.lip_out.x,0.0,motor.lip_out.y)*0.1) else "still"
	elif motor.grounded: riding_on = "deck" if _on_deck(motor.feet) else "still"
	else: riding_on = "air"
	match riding_on:
		"deck":
			if was != "deck" and not from_deck: boardings += 1
			air_v = Vector3.ZERO
			from_deck = false
		"air":
			if was != "air":
				from_deck = was == "deck"
				air_v = carry_v if from_deck else Vector3.ZERO
				_air_ref = motor.feet.y
		_:
			air_v = Vector3.ZERO
			carry_v = Vector3.ZERO
			from_deck = false

## Whether its body is right under `p`.
func _on_deck(p: Vector3) -> bool:
	var ground = scene.ground
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.3,p-Vector3.UP*0.35,ground.mask)
	var hit: Dictionary = ground.space.intersect_ray(ray)
	return not hit.is_empty() and hit.rid == body.get_rid()

## Carried by `moved` (the ship's move this frame, turned `turn` about up)
## on the deck; in the air, by the frame he left in.
func _carry(moved: Transform3D, turn: float, step_s: float) -> void:
	var motor: PilotMotor = scene.motor
	var was := motor.feet
	if riding_on == "deck":
		motor.carry(moved,turn)
		carry_v = (motor.feet-was)/step_s
		_carry_camera(was,motor.feet-was,turn)
	elif riding_on == "air" and air_v != Vector3.ZERO:
		if _air_ref-motor.feet.y > AIR_HOLD or motor.move == "sail":
			air_v *= exp(-step_s/AIR_FADE)
			if air_v.length() < 0.05: air_v = Vector3.ZERO
		var go := air_v*step_s
		var slid: Vector3 = scene.ground.slide(was,Vector2(go.x,go.z))
		var shift := Vector3(slid.x-was.x,go.y,slid.z-was.z)
		motor.carry(Transform3D(Basis.IDENTITY,shift),0.0)
		_air_ref += go.y
		_carry_camera(was,shift,0.0)

## The camera's follow point carried with him (moved, and turned about
## him), the turn owed to its yaw (taken up over CAM_TURN).
func _carry_camera(about: Vector3, moved: Vector3, turn: float) -> void:
	var cam_at: Vector2 = scene._cam_at
	var pivot := Vector3(cam_at.x,float(scene._cam_y),cam_at.y)
	pivot = about+moved+(pivot-about).rotated(Vector3.UP,turn)
	scene._cam_at = Vector2(pivot.x,pivot.z)
	scene._cam_y = pivot.y
	var cam_pace: Vector2 = scene._cam_pace
	var v := Vector3(cam_pace.x,0.0,cam_pace.y).rotated(Vector3.UP,turn)
	scene._cam_pace = Vector2(v.x,v.z)
	_turn_owed += turn

## His velocity over the ground (m/s): his own and the frame he is in.
func ground_velocity() -> Vector3:
	var frame := carry_v if riding_on == "deck" else (air_v if riding_on == "air" else Vector3.ZERO)
	return frame+(scene.motor.velocity as Vector3)

# --- Starts -------------------------------------------------------------------------

## The clock that many seconds before the stop `n`'s rest begins (or into
## it, `lead` negative).
func clock_before(n: String, lead: float) -> float:
	var s := stop(n)
	return fposmod(float(s.get("at",0.0))-lead,lap)

## The ship at clock `t`, nothing carried over.
func set_clock(t: float) -> void:
	clock = fposmod(t,lap)
	_place(clock)
	_reset_carry()

## Him on the foredeck now, facing the bow.
func board_now() -> void:
	var p := deck_point()+Vector3.UP*0.02
	var bow := -pose.basis.z
	scene.place(p,Vector2(bow.x,bow.z).normalized())
	scene.set("_last_stood",p)
	_reset_carry()
	riding_on = "deck"

## Where to wait for it at stop `n` on foot: on the turf by its foredeck
## (the edge's side), facing it.
func wait_spot(n: String) -> Dictionary:
	var s := stop(n)
	var p := point(float(s.arc))
	var h := heading_at(float(s.arc))
	var basis := Basis(Vector3.UP,h)
	# The isle's side: +1 starboard (+X), -1 port (ROUTE's).
	var side := float(s.get("side",1.0 if n == "home" else -1.0))
	var deck := basis*FOREDECK+p
	var out := basis.x*side
	var spot := deck+out*(AirshipBuild.HULL.x*SCALE+1.4)
	return {"stand":Vector3(spot.x,deck.y-DECK+0.05,spot.z),"face":Vector2(-out.x,-out.z).normalized()}

## The stop named `n` or by its isle's motif id (STOP_ISLES), or "".
func stop_named(n: String) -> String:
	if not stop(n).is_empty(): return n
	for k: String in STOP_ISLES:
		if STOP_ISLES[k] == n and not stop(k).is_empty(): return k
	return ""

## The flags' start, once the isle is up.
func _flag_start() -> void:
	start(start_aboard if start_aboard != "" else start_at,start_aboard != "")

## A start at stop `n` (its isle stood up at once if a motif's): `aboard`,
## on its foredeck (at home a few seconds before it leaves, elsewhere
## ARRIVE_LEAD s before it comes to rest); else on foot at the stop's edge,
## the ferry WAIT_LEAD s off. False if there is no such stop.
func start(n: String, aboard: bool) -> bool:
	var named := stop_named(n)
	if named == "":
		push_warning("ferry: no stop '%s' (%s)" % [n,", ".join(PackedStringArray(stops.map(func(s: Dictionary) -> String: return str(s.name))))])
		return false
	if STOP_ISLES.has(named): _stand_up(str(STOP_ISLES[named]))
	if aboard:
		set_clock(clock_before("home",-(HOLD-LEAVE_LEAD)) if named == "home" else clock_before(named,ARRIVE_LEAD))
		board_now()
		return true
	set_clock(clock_before(named,WAIT_LEAD))
	var w := wait_spot(named)
	scene.place(w.stand,w.face)
	scene.set("_last_stood",w.stand)
	return true

## Motif isle `id` stood up now, if the sky has it and it isn't up.
func _stand_up(id: String) -> void:
	var sky: Node = ship.get_parent()
	var motifs: Variant = sky.get("motifs") if sky != null else null
	if motifs == null: return
	for isle: Node3D in motifs.isles:
		if str(isle.motif.id()) == id and not isle.is_up():
			isle.build_now()
			isle.work(-1)
