extends Node3D
## Gust arrows (docs/design/roguelike/crossing-viaduct-arrows.md): a
## crossing's hazard after Dark Souls 3's giant archers, shots from off
## the path that knock you off your line. No archer yet: a launch point
## (a small stone perch) and the dragon's air blast fired from it
## (scripts/dragon_air_blast.gd: its wind-up shimmer and inhale at the
## perch as the tell, the ball, its lead, bursting on him or on a floor,
## popping on stone met side on, the shock hidden by stone between), here
## a slower, gently homing ball led on his flat pace only (aimed at his
## height now: a pump's rise and fall aren't led), and a lighter knock.
##
## Each launcher fires while the pilot is in its zone (a Callable of his
## feet in the crossing's frame) and within RANGE m. A hit:
##   - in the air or mid-pump (a jump, a pump, a landing he may pump off:
##     on the ground under the motor's `chain_window`): a hard hit, thrown AIR_OUT walker
##     heights out from the burst (PilotMotor `knock_velocity`), stunned
##     the throw and laid down STUN_DOWN s: off the piers to the floor;
##   - standing (on the ground longer than that): a shove (PilotMotor `toss`), PUSH m/s out and PUSH_UP
##     up, his control kept: a stagger he can save by steering back.
## The host steps it each frame (`step`) after the pilot's motor; `on`
## false stops the tells and shots (flights in the air fly on and burst).
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

# --- The knobs (a tier turns them up) -----------------------------------------------

## The ball's speed (m/s), the tell (s, the wind-up at the perch) and the
## gap from a shot to the next tell (s).
const SPEED := 30.0
const WINDUP := 0.8
const COOLDOWN := 2.0
## The most it turns toward him a second (radians): it bends after a
## sidestep, but a late one (or a twirl) still beats it.
const HOMING := 0.8
## The share of his flat travel led at the shot (the pier field rises
## ahead of him: a full lead aims into the next pier's face).
const LEAD := 0.0
## Aimed (and homed) this far over his middle (walker heights): a ball
## skimming the next pier's edge on its way to him pops; aimed a little
## high it clears it and still bursts on him (its fuse reaches down).
const AIM_UP := 0.5
## How near (m) the perch winds up at him, and how far a ball flies.
const RANGE := 55.0
const FLY := 90.0
## The fuse: a ball passing this near his middle bursts on him (walker
## heights; the dragon's is wider), so a sidestep or cover beats it.
const FUSE := 0.3
## The streak trail behind a ball (m); the blast draws it a share of its
## `span` (DragonAirBlast `_draw`: 0.12 of it).
const TRAIL := 4.0
## The hard hit in the air: out and up in walker heights at the burst's
## heart (DragonAirBlast EDGE of it at the shock's rim), down this long (s).
const AIR_OUT := 9.0
const AIR_UP := 1.2
const STUN_DOWN := 0.8
## The shove on his feet (m/s), out from the burst and up.
const PUSH := 3.2
const PUSH_UP := 2.4

## Off: no tells, no new shots.
var on := true
var look := true
## What landed, for the yard's word and the tests: {kind ("thrown" or
## "pushed"), at (the pilot's feet), launcher (its index), t (s)}.
var hits: Array = []
var _clock := 0.0
## Seconds he has been on the ground (0 in the air).
var _footed := 0.0
var launchers: Array[Launcher] = []

## One launch point: its blast, where its ball leaves (`mouth`, world),
## and its zone.
class Launcher extends Node3D:
	var air_blast: DragonAirBlast
	var zone: Callable
	func mouth_at() -> Vector3:
		return global_position

func _init() -> void:
	name = "GustArrows"

## A launch point at `at` (the host's frame: this node's parent), firing
## while `zone`(feet in the host's frame) is true.
func add_launcher(at: Vector3, zone: Callable) -> Launcher:
	var l := Launcher.new()
	l.name = "Launcher%d" % launchers.size()
	l.position = at
	l.zone = zone
	var b := DragonAirBlast.new()
	b.look = look
	b.publish = false
	b.windup = WINDUP
	b.cooldown = COOLDOWN
	b.speed = SPEED
	b.homing = HOMING
	b.fire_range = RANGE
	b.flight = FLY
	b.knock_out = AIR_OUT
	b.knock_up = AIR_UP
	b.fuse = FUSE
	b.lead_flat = true
	b.lead_share = LEAD
	b.span = TRAIL/0.12
	l.air_blast = b
	l.add_child(b)
	add_child(l)
	launchers.append(l)
	return l

func set_on(value: bool) -> void:
	on = value
	for l: Launcher in launchers: l.air_blast.on = value

## A frame, after the pilot's motor has stepped: each launcher's tell, its
## shots, and their hit on the pilot (`motor`'s knock or toss). Returns the
## hit's kind ("thrown", "pushed") or "".
func step(delta: float, motor: Object, space: PhysicsDirectSpaceState3D) -> String:
	_clock += delta
	var host := get_parent() as Node3D
	var feet: Vector3 = motor.feet
	var local := host.to_local(feet) if host != null else feet
	var aim := feet+Vector3.UP*(0.55+AIM_UP)*DragonAirBlast.walker_tall()
	var out := ""
	_footed = _footed+delta if motor.grounded else 0.0
	var standing: bool = motor.grounded and _footed > float(motor.chain_window)
	for i in range(launchers.size()):
		var l := launchers[i]
		var b := l.air_blast
		b.on = on
		var seen := bool(l.zone.call(local))
		b.advance(delta,space,seen,l.mouth_at(),aim)
		var v: Vector3 = b.pilot_knock(feet,motor)
		if v == Vector3.ZERO: continue
		if standing:
			var flat := Vector2(v.x,v.z).normalized()
			motor.toss(Vector3(flat.x*PUSH,PUSH_UP,flat.y*PUSH))
			out = "pushed"
		else:
			motor.knock(v,b,STUN_DOWN)
			out = "thrown"
		hits.append({"kind":out,"at":feet,"launcher":i,"t":_clock})
		print("gust arrows: %s (launcher %d, %s)" % [out,i,"standing" if standing else ("mid-pump, on the touch" if motor.grounded else "in the air")])
	return out

## The launchers, each read by the isle's sound as a dragon's air blast
## (scripts/kit_isle/kit_audio_beasts.gd `_air_blast`: its `air_blast` and
## `mouth_at()`).
func voices() -> Array:
	var all := []
	for l: Launcher in launchers: all.append(l)
	return all
