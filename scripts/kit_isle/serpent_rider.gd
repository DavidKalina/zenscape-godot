extends Node3D
## Riding the rune serpent in the game (docs/design/serpent-route.md): the
## serpent ride's greybox (studies/serpent_ride.gd, docs/design/
## serpent-ride-handoff.md) brought onto the serpent's route between the
## isles (scripts/kit_isle/serpent_route.gd), round the game's own pilot
## (studies/kit_isle.gd: the character study's motor, camera and bridge).
##
## Its body is ground as in the greybox (studies/serpent_back.gd: a convex
## hull between every two rings and the head's sections, re-pointed each
## frame), but only while he is near it (LIVE_NEAR) or on it: the rest of
## the time its hulls are out of the world and its own capsules stand in for
## it to the plane, as before. Each frame, before his step (this runs ahead
## of the scene, after the serpent has moved: process priorities -101, -100,
## then the scene's 0):
##   1. what he is on after his last step: its back (held as a place on its
##      body), still ground, or the air;
##   2. its hulls laid where it is now;
##   3. carried: on its back, by the body's move at his place (PilotMotor
##      `carry`), the camera with him, its turn taken up over CAM_TURN; in
##      the air, by the frame he left it in (its velocity there).
## Then the scene's own frame steps him as ever.
##
## Off its back in the air, while he is still over it (within AIR_OVER m
## past its back's edge and AIR_HOLD m over its crest), he goes on with the
## place on its back under him, as on it: a hop or a twirl comes down where
## it went on its back however it slithers, turns or dives under him. (A
## frame held straight let its slither and its turns in the dip slide its
## back out from under a hop and a twirl, two or three metres in a second:
## he came down past its flank, fell, and the stranding rule took him back
## to the plane, round 1 of docs/design/serpent-teleports-sail.) Past its
## edge he keeps the last of that frame while he is within AIR_HOLD m
## under where he left (a jump off its side carries its pace), and loses
## it over AIR_FADE s once he drops past that or opens the sail.
## Falling off is the game's own fall (studies/kit_isle.gd `_check_step_off`
## and on: Space opens the pocket sail; down on something he walks on, else
## stranded a moment and back beside the parked plane). There is no fade
## back onto its back here. While he rides it and falls from it the scene's
## `lost` floor (a respawn) is set aside, since its dip runs under it; the
## stranding rule is the net.
const SerpentBack = preload("res://studies/serpent_back.gd")
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

## The share of its roll it keeps while ridden, and for how long after he
## leaves (s): the greybox's (studies/serpent_ride.gd RIDE_ROLL).
const RIDE_ROLL := 0.4
const RIDDEN_AFTER := 3.0
## The camera takes up the body's turn over this many seconds.
const CAM_TURN := 0.6
## Its hulls stand in the world while any ring (or its head) is within this
## of his feet (m), or he is on it.
const LIVE_NEAR := 40.0
## The frame he left it in: held while he is within AIR_HOLD m under where
## he left; past that, or under the sail, it fades over AIR_FADE s.
const AIR_HOLD := 6.0
const AIR_FADE := 1.5
## Over its back in the air: within this far (m) past its back's edge.
const AIR_OVER := 0.6

var scene: Node3D
var serpent: Node3D
var back: SerpentBack
## Driven by hand (a test calls `step` itself, after advancing the serpent).
var manual := false
## What he is on: "serpent", "still" (any other ground, or a ledge), "air".
var riding_on := "still"
## His place on its body (arc, across, up) while on it, the last where he
## stood on it, and whether he left the air from its back.
var anchor := Vector3.ZERO
var last_on := Vector3.ZERO
var from_back := false
## Times he has got on it (landed on it from anything else).
var boardings := 0
## His feet's carry on it this frame and the frame he left in (m/s).
var carry_v := Vector3.ZERO
var air_v := Vector3.ZERO
## Its hulls in the world now.
var live := false
## The hulls' cost the last frame (µs).
var hulls_usec := 0
var _air_ref := 0.0
## In the air over its back: the place on it under him (arc, across, its
## crest's up), as it was posed when he last stepped; else x < 0.
var _air_over := Vector3(-1.0,0.0,0.0)
var _turn_owed := 0.0
var _since_ridden := 99.0
var _lost_was := NAN

func _init() -> void:
	name = "SerpentRider"
	process_priority = -100

func setup(study: Node3D, on: Node3D) -> void:
	scene = study
	serpent = on
	back = SerpentBack.new(serpent,self)
	back.set_live(false)

func _process(delta: float) -> void:
	if manual or scene == null: return
	step(delta)

## Whether he walks now (the scene steps him this frame).
func on_foot() -> bool:
	if not bool(scene.get("walk_ready")) or bool(scene.get("flying")): return false
	return manual or not bool(scene.get("scripted"))

## A frame, before his own step (the serpent already moved on).
func step(delta: float) -> void:
	if serpent == null or delta <= 0.0: return
	if not on_foot():
		if live: _set_live(false)
		riding_on = "still"
		from_back = false
		_hand_back_lost()
		serpent.bank_share = 1.0
		return
	var dt := minf(delta,RuneSerpent.MAX_STEP)
	_contact(delta)
	_choose_live()
	serpent.bank_share = RIDE_ROLL if _since_ridden < RIDDEN_AFTER else 1.0
	if live:
		var began := Time.get_ticks_usec()
		back.update()
		hulls_usec = Time.get_ticks_usec()-began
	_carry(dt)
	var take := _turn_owed*(1.0-exp(-delta/CAM_TURN))
	scene._yaw += take
	_turn_owed -= take
	if riding_on == "serpent" or (riding_on == "air" and from_back): _set_aside_lost()
	else: _hand_back_lost()

## As after a set-down (he and it placed anew): nothing carried over.
func reset() -> void:
	riding_on = "still"
	from_back = false
	air_v = Vector3.ZERO
	carry_v = Vector3.ZERO
	_air_over = Vector3(-1.0,0.0,0.0)
	_turn_owed = 0.0
	if live: back.reset()

# --- Its hulls ----------------------------------------------------------------------

## Live while he is on it, or near any ring or its head.
func _choose_live() -> void:
	var want := riding_on == "serpent"
	if not want:
		var at: Vector3 = scene.motor.feet
		var near := LIVE_NEAR*LIVE_NEAR
		want = (serpent.head() as Vector3).distance_squared_to(at) < near
		var rings: PackedVector3Array = serpent.rings()
		var i := 0
		while not want and i < rings.size():
			want = rings[i].distance_squared_to(at) < near
			i += 3
	if want != live: _set_live(want)

func _set_live(on: bool) -> void:
	live = on
	if on: back.reset()
	back.set_live(on)
	# Its capsules stand in for the hulls to the plane while they are out.
	serpent.set_solid(not on)

# --- Carried ------------------------------------------------------------------------

## Carried over `step`: on it, by the body's move where he is; in the air,
## by the frame he left in (slid round what stands in the way, as his own
## steps are), held, then fading.
func _carry(step: float) -> void:
	var motor: PilotMotor = scene.motor
	var was := motor.feet
	if riding_on == "serpent" and live:
		var turn := back.turn(anchor.x)
		motor.carry(back.moved(anchor),turn)
		carry_v = (motor.feet-was)/step
		_carry_camera(was,motor.feet-was,turn)
	elif riding_on == "air" and from_back and _air_over.x >= 0.0 and motor.move != "sail":
		# Over its back: on with the place under him (its move, and its
		# turn for his way and pace), as if he still stood there.
		var moved := back.place(_air_over)-back.place(_air_over,true)
		var turn := back.turn(_air_over.x)
		motor.carry(Transform3D(Basis.IDENTITY,moved),turn)
		air_v = moved/step
		_air_ref += moved.y
		_carry_camera(was,moved,turn)
	elif riding_on == "air" and air_v != Vector3.ZERO:
		if _air_ref-motor.feet.y > AIR_HOLD or motor.move == "sail":
			air_v *= exp(-step/AIR_FADE)
			if air_v.length() < 0.05: air_v = Vector3.ZERO
		var go := air_v*step
		var slid: Vector3 = scene.ground.slide(was,Vector2(go.x,go.z))
		var moved := Vector3(slid.x-was.x,go.y,slid.z-was.z)
		motor.carry(Transform3D(Basis.IDENTITY,moved),0.0)
		_air_ref += go.y
		_carry_camera(was,moved,0.0)

## The camera's follow point carried with him (moved, and turned about
## him), the turn owed to its yaw, taken up over CAM_TURN.
func _carry_camera(about: Vector3, moved: Vector3, turn: float) -> void:
	var cam_at: Vector2 = scene._cam_at
	var pivot := Vector3(cam_at.x,float(scene._cam_y),cam_at.y)
	pivot = about+moved+(pivot-about).rotated(Vector3.UP,turn)
	scene._cam_at = Vector2(pivot.x,pivot.z)
	scene._cam_y = pivot.y
	var cam_pace: Vector2 = scene._cam_pace
	var pace := Vector3(cam_pace.x,0.0,cam_pace.y).rotated(Vector3.UP,turn)
	scene._cam_pace = Vector2(pace.x,pace.z)
	_turn_owed += turn

# --- What he is on -------------------------------------------------------------------

## What he is on after his last step: its back (held as a place on it),
## other ground, or the air (leaving its back, the frame he leaves in is
## its carry).
func _contact(delta: float) -> void:
	var motor: PilotMotor = scene.motor
	var was := riding_on
	var on_back := false
	if motor.on_ledge():
		on_back = _on_back(motor.lip-Vector3(motor.lip_out.x,0.0,motor.lip_out.y)*0.1)
		riding_on = "serpent" if on_back else "still"
	elif motor.grounded:
		on_back = _on_back(motor.feet)
		riding_on = "serpent" if on_back else "still"
	else: riding_on = "air"
	match riding_on:
		"serpent":
			anchor = back.locate(motor.lip if motor.on_ledge() else motor.feet,anchor.x if was == "serpent" else -1.0)
			if motor.grounded: last_on = anchor
			if was != "serpent" and not from_back: boardings += 1
			_since_ridden = 0.0
			air_v = Vector3.ZERO
			_air_over = Vector3(-1.0,0.0,0.0)
			from_back = false
		"air":
			if was != "air":
				from_back = was == "serpent"
				air_v = carry_v if from_back else Vector3.ZERO
				_air_ref = motor.feet.y
			_air_over = _over_back(motor.feet) if from_back else Vector3(-1.0,0.0,0.0)
			_since_ridden += delta
		_:
			air_v = Vector3.ZERO
			carry_v = Vector3.ZERO
			_air_over = Vector3(-1.0,0.0,0.0)
			from_back = false
			_since_ridden += delta

## The place on its back right under `p` (arc, across, its crest's up),
## while `p` is over it: within AIR_OVER m past its back's edge and at most
## AIR_HOLD m over its crest (nor under it); else x < 0. Read on the body as
## posed when he last stepped.
func _over_back(p: Vector3) -> Vector3:
	var none := Vector3(-1.0,0.0,0.0)
	if not live: return none
	var c := back.locate(p,anchor.x)
	if c.x < back.first_arc() or c.x > back.last_arc(): return none
	if absf(c.y) > back.half_width(c.x)+AIR_OVER: return none
	var crest := back.top(c.x)
	if c.z < crest.z-0.3 or c.z > crest.z+AIR_HOLD: return none
	return Vector3(c.x,c.y,crest.z)

## Whether he is on its back, or in the air over it having left it (a hop,
## a twirl): carried with it, nothing under him has gone.
func carries() -> bool:
	return riding_on == "serpent" or (riding_on == "air" and from_back and _air_over.x >= 0.0)

## Whether its back is right under `p`.
func _on_back(p: Vector3) -> bool:
	if not live: return false
	var ground = scene.ground
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.3,p-Vector3.UP*0.35,ground.mask)
	var hit: Dictionary = ground.space.intersect_ray(ray)
	return not hit.is_empty() and hit.rid == back.rid()

# --- The fall floor -------------------------------------------------------------------

## The scene's `lost` (a respawn under it) set aside while he rides it or
## falls from it: its dip runs under it. The stranding rule is the net.
func _set_aside_lost() -> void:
	if not is_nan(_lost_was): return
	_lost_was = float(scene.lost)
	scene.lost = -INF

func _hand_back_lost() -> void:
	if is_nan(_lost_was): return
	scene.lost = _lost_was
	_lost_was = NAN

func _exit_tree() -> void:
	_hand_back_lost()

## His velocity over the ground (m/s): his own and the frame he is in.
func ground_velocity() -> Vector3:
	var frame := carry_v if riding_on == "serpent" else (air_v if riding_on == "air" else Vector3.ZERO)
	return frame+(scene.motor.velocity as Vector3)
