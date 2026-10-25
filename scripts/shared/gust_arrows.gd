extends Node3D
## Gust arrows: a
## crossing's hazard: shots from off
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
## The look's boost over the dragon's shimmer (DragonAirBlast `glow`) and
## its tint: bright enough to see coming against the pale floor.
const GLOW := 1.6
const TINT := Color(0.92,0.97,1.0)
## The tell's ball at full gather on the perch (shares of the ball): big
## enough to catch the eye from the piers.
const GATHER := 1.8
## The hard hit in the air: out and up in walker heights at the burst's
## heart (DragonAirBlast EDGE of it at the shock's rim), down this long (s).
## A notch under the first round's 9 / 1.2 / 0.8:
## a scare he can sail out of, still well off his line.
const AIR_OUT := 7.0
const AIR_UP := 1.0
const STUN_DOWN := 0.6
## The shove on his feet (m/s), out from the burst and up.
const PUSH := 3.2
const PUSH_UP := 2.4
## Launchers take turns: one winds up only when no other is winding up,
## has a ball in flight, or fired within TURN_GAP s (no shove into a second
## shot's throw).
const TURN_GAP := 1.0
## A horn fires where it points: it starts its wind-up only once its barrel is
## within
## START_CONE of him (rad), finishes it only within AIM_CONE (the wind-up
## held at its end meanwhile), and the ball leaves along the barrel.
const START_CONE := 0.6
const AIM_CONE := 0.1

## Slammed on its top (scripts/slam.gd), a perch is disabled this long (s): no
## tell,
## no shots, its horn tipped over; then it comes back. A slam counts on the
## top when its touch is within SLAM_UP walker heights of the top's height
## and inside its round (the top's half size plus SLAM_EDGE m).
const DISABLE_TIME := 8.0
const SLAM_UP := 0.6
const SLAM_EDGE := 0.3

## Off: no tells, no new shots.
var on := true
var look := true
## What landed, for the yard's word and the tests: {kind ("thrown" or
## "pushed"), at (the pilot's feet), launcher (its index), t (s), how
## ("standing", "in the air", "under the sail", "mid-pump")}.
var hits: Array = []
## Slams that disabled a perch: {launcher (index), t (s)}.
var silenced: Array = []
var _clock := 0.0
## Seconds he has been on the ground (0 in the air).
var _footed := 0.0
var launchers: Array[Launcher] = []

## One launch point: a perch's horn (its Head turns, its Mouth is where the
## ball leaves: studies/crossings/horn_stand_in.gd, or the stone wind horn),
## its blast, its zone, and its top (the stone he can stand on and slam).
## The launcher sits at the top's middle.
class Launcher extends Node3D:
	const SlamScript = preload("res://scripts/slam.gd")
	var air_blast: DragonAirBlast
	var zone: Callable
	var horn: Node3D
	## The top's half size (m); 0: no top to slam.
	var top_half := 0.0
	## The horn's own standable top over the perch's top (m; 0 none): a
	## slam on it counts too.
	var cap_rise := 0.0
	## Fires only at a pilot in the air, off his feet and not tumbling (the
	## low perches: at a falling or sailing pilot, never one on the route).
	var airborne := false
	## Seconds it stays disabled still, and how many slams disabled it.
	var down_left := 0.0
	var slams := 0
	## Slammed since the host's last frame.
	var fresh := false
	func _ready() -> void:
		add_to_group(SlamScript.GROUP)
	func mouth_at() -> Vector3:
		var m: Node3D = horn.find_child("Mouth",true,false) if horn != null else null
		return m.global_position if m != null else global_position
	func is_down() -> bool:
		return down_left > 0.0
	## A slam's touch (scripts/slam.gd `blast`): on this top, it's down.
	func slam(at: Vector3, _radius: float, _strength: float) -> void:
		if top_half <= 0.0: return
		var q := to_local(at)
		var up := SLAM_UP*WorldScale.wanderer
		if (absf(q.y) > up and (cap_rise <= 0.0 or q.y < -up or q.y > cap_rise+up)) or Vector2(q.x,q.z).length() > top_half+SLAM_EDGE: return
		down_left = DISABLE_TIME
		slams += 1
		fresh = true
		air_blast.phase = "idle"
		print("gust arrows: %s slammed, down for %.0f s" % [name,DISABLE_TIME])
		if horn != null: horn.disabled(DISABLE_TIME)

func _init() -> void:
	name = "GustArrows"

## A launch point on a perch's top, its middle at `top` (the host's frame:
## this node's parent), `top_half` m round (0: none to slam), `horn` set on
## it (made a child of the launcher), firing while `zone`(feet in the host's
## frame) is true. `opts`: "airborne" (bool), "lead" (share of his flat
## travel led), "cooldown" (s), "range" (m).
func add_launcher(top: Vector3, zone: Callable, horn: Node3D = null, top_half := 0.0, opts := {}) -> Launcher:
	var l := Launcher.new()
	l.name = "Launcher%d" % launchers.size()
	l.position = top
	l.zone = zone
	l.top_half = top_half
	l.airborne = bool(opts.get("airborne",false))
	var b := DragonAirBlast.new()
	b.look = look
	b.publish = false
	b.windup = WINDUP
	b.cooldown = float(opts.get("cooldown",COOLDOWN))
	b.speed = SPEED
	b.homing = HOMING
	b.fire_range = float(opts.get("range",RANGE))
	b.flight = FLY
	b.knock_out = AIR_OUT
	b.knock_up = AIR_UP
	b.fuse = FUSE
	b.lead_flat = true
	b.lead_share = float(opts.get("lead",LEAD))
	b.glow = GLOW
	b.tint = TINT
	b.gather = GATHER
	b.span = TRAIL/0.12
	l.air_blast = b
	l.add_child(b)
	if horn != null:
		l.horn = horn
		l.add_child(horn)
		b.fired.connect(func(_from: Vector3, _aim: Vector3) -> void: horn.fired())
	add_child(l)
	launchers.append(l)
	return l

## Bodies the balls fly through (DragonAirBlast `see_through`).
func set_see_through(rids: Array[RID]) -> void:
	for l: Launcher in launchers: l.air_blast.see_through = rids

func set_on(value: bool) -> void:
	on = value
	for l: Launcher in launchers: l.air_blast.on = value

## A frame, after the pilot's motor has stepped: each launcher's tell, its
## shots, and their hit on the pilot (`motor`'s knock or toss). Returns the
## hit's kind ("thrown", "pushed"), "silenced" (a perch slammed down this
## frame) or "".
func step(delta: float, motor: Object, space: PhysicsDirectSpaceState3D) -> String:
	_clock += delta
	var host := get_parent() as Node3D
	var feet: Vector3 = motor.feet
	var local := host.to_local(feet) if host != null else feet
	var aim := feet+Vector3.UP*(0.55+AIM_UP)*DragonAirBlast.walker_tall()
	var out := ""
	_footed = _footed+delta if motor.grounded else 0.0
	var standing: bool = motor.grounded and _footed > float(motor.chain_window)
	# Off his feet for the airborne (low) perches: falling or under the sail,
	# not tumbling, not riding an updraft (the swirl is shelter: the glide
	# to it is what they guard).
	var aloft: bool = not motor.grounded and motor.move != "tumble" and not motor.on_ledge() and not (motor.move == "sail" and motor.sail.riding)
	# Who may wind up: on, not down, in its zone. Of those cooled down and
	# in range, the one that has waited longest goes first (no perch hogs
	# the turns).
	var wants: Array[bool] = []
	var next := -1
	for i in range(launchers.size()):
		var l := launchers[i]
		var b := l.air_blast
		if l.fresh:
			l.fresh = false
			out = "silenced"
			silenced.append({"launcher":i,"t":_clock})
		elif l.down_left > 0.0:
			l.down_left = maxf(l.down_left-delta,0.0)
			if l.down_left <= 0.0: print("gust arrows: %s back up" % l.name)
		var w: bool = on and not l.is_down() and bool(l.zone.call(local)) and (aloft or not l.airborne)
		wants.append(w)
		if w and b.phase != "windup" and b.cooldown_left <= 0.0 and l.mouth_at().distance_to(aim) <= b.fire_range:
			if next < 0 or b.since_shot > launchers[next].air_blast.since_shot: next = i
	for i in range(launchers.size()):
		var l := launchers[i]
		var b := l.air_blast
		b.on = on and not l.is_down()
		# The horn turns onto him (onto his lead, for a leading perch), and
		# fires only facing him.
		var target := aim
		if b.lead_share > 0.0: target = DragonAirBlast.lead(l.mouth_at(),aim,Vector3(b.aim_vel.x,0.0,b.aim_vel.z),b.speed,b.lead_share)
		var facing := l.horn != null and l.horn.has_method("aim_error")
		if l.horn != null and wants[i]: l.horn.aim_at(target,delta)
		var off: float = l.horn.aim_error(target) if facing else 0.0
		b.hold = facing and off > AIM_CONE
		b.face = l.horn.facing() if facing else Vector3.ZERO
		var seen := wants[i] and (b.phase == "windup" or (off < START_CONE and not _others_busy(i) and (next < 0 or next == i)))
		b.advance(delta,space,seen,l.mouth_at(),aim)
		if l.horn != null: l.horn.tell(maxf(b.windup_share(),0.0))
		var v: Vector3 = b.pilot_knock(feet,motor)
		if v == Vector3.ZERO: continue
		var how := "standing"
		if standing:
			var flat := Vector2(v.x,v.z).normalized()
			motor.toss(Vector3(flat.x*PUSH,PUSH_UP,flat.y*PUSH))
			out = "pushed"
		else:
			how = "under the sail" if motor.move == "sail" else ("mid-pump" if motor.grounded else "in the air")
			motor.knock(v,b,STUN_DOWN)
			motor.harm("wind",1,b)
			out = "thrown"
		hits.append({"kind":out,"at":feet,"launcher":i,"t":_clock,"how":how})
		print("gust arrows: %s (launcher %d, %s)" % [out,i,how])
	return out

## Whether a launcher other than `me` is winding up, has a ball in
## flight, or fired within TURN_GAP.
func _others_busy(me: int) -> bool:
	for i in range(launchers.size()):
		if i == me: continue
		var o := launchers[i].air_blast
		if o.phase == "windup" or not o.balls.is_empty() or o.since_shot < TURN_GAP: return true
	return false

## The launchers, each read by the isle's sound as a dragon's air blast
## (scripts/kit_isle/kit_audio_beasts.gd `_air_blast`: its `air_blast` and
## `mouth_at()`).
func voices() -> Array:
	var all := []
	for l: Launcher in launchers: all.append(l)
	return all
