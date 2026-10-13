extends RefCounted
## The dragon's sight (docs/design/dragon-vision/round1.md): what he sees of
## the pilot, and how sure he is of it. He is deaf while flying (his wings
## drown everything), so sight is all he has.
##
##   - a cone from his head (`look`: where the head bone actually points,
##     the snout's way), RANGE m deep, HALF_ANGLE off the snout;
##   - rays from his eye to a few points on the pilot (`pilot_points`: feet,
##     chest and head on foot; the plane's middle and both wingtips), against
##     isle ground and cover (MASK), so a half-hidden pilot is half seen;
##   - the share seen falls off past NEAR to FAR_SEEN at RANGE, and off
##     the cone's middle to EDGE_SEEN at its rim; in the air (the plane, the
##     sail, a jump, a fall) he is plain (AIR), on the turf less so (GROUND);
##   - awareness 0..1: while seen (visibility over NOTICE) it fills at FILL
##     a second times the visibility; unseen, after GRACE s, it drains at
##     DRAIN a second. Three states with hysteresis: unaware, suspicious
##     (over SUSPECT_UP, back under SUSPECT_DOWN), spotted (over SPOT_UP,
##     back under SPOT_DOWN). `state_changed` fires on each change.
##
## Pure but for the rays: `look_at_pilot` needs a physics space; `step`
## takes a visibility and needs nothing. scripts/sky_dragon.gd owns one
## (`sight`) and runs it each frame he flies (his own flight or his wake's
## circuit) when the host gives him a target (`sight_target`).

signal state_changed(now: String, was: String)

const WorldScale = preload("res://scripts/world_scale.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")

## The cone (m, rad).
const RANGE := 450.0
const HALF_ANGLE := 1.1
## Distance: fully seen within NEAR m, FAR_SEEN of it at RANGE.
const NEAR := 150.0
const FAR_SEEN := 0.2
## Off the snout: EDGE_SEEN at the cone's rim (eased in, so most of the cone
## sees nearly fully).
const EDGE_SEEN := 0.5
## How plain he is: standing on turf, and in the air.
const GROUND := 0.55
const AIR := 1.0
## Awareness: least visibility that counts, fill a second at visibility 1,
## the grace once unseen (s), the drain a second after it.
const NOTICE := 0.03
const FILL := 0.55
const GRACE := 2.0
const DRAIN := 0.12
## The states' thresholds, going up and coming back down.
const SUSPECT_UP := 0.3
const SUSPECT_DOWN := 0.12
const SPOT_UP := 0.85
const SPOT_DOWN := 0.5
## What a ray stops on: solid stone (layer 1) and the isles' turf (1 << 11,
## studies/kit_isle.gd TURF_LAYER). The parked plane's column (1 << 13) and
## the pilot are not on them.
const MASK := 1 | (1 << 11)
## The pilot's points on foot, as shares of his head's height over his feet
## (scripts/pilot_physics_ground.gd HEAD, times the wanderer's size).
const BODY := [0.12,0.55,0.95]

## This frame's look: his eye, the snout's way, each point and whether its
## ray got through (and was in the cone and in range).
var eye := Vector3.ZERO
var look := Vector3.FORWARD
var points := PackedVector3Array()
var seen: Array[bool] = []
var in_cone := false
var distance := INF
var seen_share := 0.0
var visibility := 0.0
var airborne := false
## How sure he is (0..1), the state, the time since last seen (s).
var awareness := 0.0
var state := "unaware"
var unseen_for := INF
## RIDs a ray passes through (his own colliders).
var exclude: Array[RID] = []

## The pilot's points to look for: on foot his feet, chest and head; in the
## plane its middle and both wingtips (WorldScale.span).
static func pilot_points(feet: Vector3, in_plane: bool, plane_at := Vector3.ZERO, plane_forward := Vector3.FORWARD) -> PackedVector3Array:
	var out := PackedVector3Array()
	if in_plane:
		var right := plane_forward.cross(Vector3.UP)
		right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
		out.append(plane_at)
		out.append(plane_at+right*WorldScale.span*0.5)
		out.append(plane_at-right*WorldScale.span*0.5)
		return out
	var tall := PhysicsGround.HEAD*WorldScale.wanderer
	for share: float in BODY: out.append(feet+Vector3.UP*tall*share)
	return out

## Whether `p` lies in the cone from `from` along `way` (unit) and in range.
static func in_view(from: Vector3, way: Vector3, p: Vector3) -> bool:
	var to := p-from
	var d := to.length()
	if d > RANGE: return false
	if d < 0.01: return true
	return way.angle_to(to/d) <= HALF_ANGLE

## The share seen at `d` m: 1 within NEAR, down to FAR_SEEN at RANGE, 0 past.
static func by_distance(d: float) -> float:
	if d > RANGE: return 0.0
	return lerpf(1.0,FAR_SEEN,clampf((d-NEAR)/(RANGE-NEAR),0.0,1.0))

## The share seen `angle` rad off the snout: 1 at the middle, EDGE_SEEN at
## the rim, 0 out of the cone.
static func by_angle(angle: float) -> float:
	if angle > HALF_ANGLE: return 0.0
	var u := angle/HALF_ANGLE
	return lerpf(1.0,EDGE_SEEN,u*u)

## Looks for the pilot at `pilot` (his points) from `from` along `way`:
## the visibility (0..1) this frame, the rays cast against `space`.
func look_at_pilot(space: PhysicsDirectSpaceState3D, from: Vector3, way: Vector3, pilot: PackedVector3Array, in_air: bool) -> float:
	eye = from
	look = way.normalized() if way.length() > 0.001 else Vector3.FORWARD
	points = pilot
	airborne = in_air
	seen.clear()
	visibility = 0.0
	seen_share = 0.0
	in_cone = false
	distance = INF
	if pilot.is_empty(): return 0.0
	var middle := Vector3.ZERO
	for p in pilot: middle += p
	middle /= float(pilot.size())
	distance = from.distance_to(middle)
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = MASK
	ray.exclude = exclude
	var got := 0
	for p in pilot:
		var ok := in_view(from,look,p)
		if ok:
			in_cone = true
			if space != null:
				ray.from = from
				ray.to = p
				ok = space.intersect_ray(ray).is_empty()
		seen.append(ok)
		if ok: got += 1
	seen_share = float(got)/float(pilot.size())
	if got == 0: return 0.0
	var angle := look.angle_to((middle-from).normalized()) if distance > 0.01 else 0.0
	visibility = seen_share*by_distance(distance)*by_angle(minf(angle,HALF_ANGLE))*(AIR if in_air else GROUND)
	return visibility

## Awareness and state for a frame at `vis` (0..1).
func step(delta: float, vis: float) -> void:
	if vis > NOTICE:
		unseen_for = 0.0
		awareness = minf(1.0,awareness+FILL*vis*delta)
	else:
		unseen_for += delta
		if unseen_for > GRACE: awareness = maxf(0.0,awareness-DRAIN*delta)
	var now := next_state(state,awareness)
	if now != state:
		var was := state
		state = now
		state_changed.emit(now,was)

## Both: looks, then steps.
func update(delta: float, space: PhysicsDirectSpaceState3D, from: Vector3, way: Vector3, pilot: PackedVector3Array, in_air: bool) -> void:
	step(delta,look_at_pilot(space,from,way,pilot,in_air))

## Nothing to look at (asleep, no pilot): the awareness drains as unseen.
func blind(delta: float) -> void:
	points = PackedVector3Array()
	seen.clear()
	visibility = 0.0
	seen_share = 0.0
	in_cone = false
	step(delta,0.0)

## The state for `a` coming from `was` (the thresholds' hysteresis).
static func next_state(was: String, a: float) -> String:
	match was:
		"spotted":
			if a < SUSPECT_DOWN: return "unaware"
			if a < SPOT_DOWN: return "suspicious"
			return "spotted"
		"suspicious":
			if a >= SPOT_UP: return "spotted"
			if a < SUSPECT_DOWN: return "unaware"
			return "suspicious"
		_:
			if a >= SPOT_UP: return "spotted"
			if a >= SUSPECT_UP: return "suspicious"
			return "unaware"

## How alert he looks (0 unaware, 0.5 suspicious, 1 spotted): his eyes'
## glow and the overlay read it.
func alert() -> float:
	match state:
		"spotted": return 1.0
		"suspicious": return 0.5
	return 0.0

## The middle of the pilot's points this frame (INF without any).
func target() -> Vector3:
	if points.is_empty(): return Vector3.INF
	var m := Vector3.ZERO
	for p in points: m += p
	return m/float(points.size())
