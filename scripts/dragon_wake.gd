extends RefCounted
## The roost dragon's wake (docs/design/dragon-wake/round1.md): the sleeping
## dragon (scripts/dragon_roost.gd on scripts/sky_dragon.gd, on his
## mountain, scripts/kit_isle/motif_dragon_roost.gd) wakes on a schedule,
## flies one big circuit round the region and settles back into his coil.
## Spectacle only: he never grips, blows, grabs or knocks anything (the
## roost dragon has no gale, treasure or targets), and never troubles the
## aqueduct isle (his pass over it is high, HOME_OVER over its turf).
##
## The beats:
##   - asleep: the roost's own breath (it hands its frames to the pose).
##   - stirring (STIR s): the eyes open, the neck and head lift off their
##     shelf, he looks round, a roar (its call in the kit audio), a beat.
##   - taking off (RISE s): the dust and the carrion birds burst off the
##     mountain (scripts/roost_air.gd `dust`, `scatter`) as he unfurls: each
##     bone eased from the coil to the flight pose, head first and the tail
##     last (`_lag_rise`), the body lifting off the ledge on heavy beats.
##   - flying: the sky dragon's own flight (`wake_fly`) along CIRCUIT: north
##     out of the roost, between the hollow keel and the bell spires, a
##     sweeping pass over the aqueduct isle, out between the colonnade spine
##     and the Sundered gorge, round the broken ring's side, back east between
##     the gorge and the drowned nave, between the keel and the spires again,
##     and in to the roost from the north-east. The roost reads empty
##     meanwhile: the same body is the one flying.
##   - landing (SETTLE s): a slowing curve in over the ledge from out and
##     above, wings cupped and back-beating, legs reaching (the grab's flare),
##     each bone eased back to the coil, the body first and the head last
##     (`_lag_land`), dust as he sets down; the eyes shut.
##
## The schedule: once a world day at WAKE_HOUR, never before FIRST_AFTER real
## seconds of play; a held day (no live clock) never wakes him on its own.
## Flags: --dragon-wake (wakes him FLAG_AFTER s after load),
## --dragon-wake-at=<s> (that many seconds after load), --no-dragon-wake (the
## schedule off).
const Roost = preload("res://scripts/kit_isle/motif_dragon_roost.gd")
const SkyDragon = preload("res://scripts/sky_dragon.gd")

## The schedule: the world hour he wakes at (late afternoon: he is out in
## the low gold light and back on his mountain as the sun sets), the real
## seconds of play before the first wake may come, and --dragon-wake's wait.
const WAKE_HOUR := 15.5
const FIRST_AFTER := 240.0
const FLAG_AFTER := 4.0
## The beats' lengths (s).
const STIR := 9.0
const RISE := 8.0
const SETTLE := 11.0
## Longest he stays out (s): past it he comes home from where he is.
const OUT_MOST := 240.0
## Stirring: when the eyes open, the head's lift (each bone's, rad: up off
## its shelf, out from the rock), when the roar comes, the look round (rad).
const EYES_AT := 1.0
const LIFT := {"neck.1":0.05,"neck.2":0.12,"neck.3":0.22,"head":0.12}
const LIFT_IN := Vector2(1.2,4.0)
const ROAR_AT := 5.2
const LOOK := 0.3
## Taking off: each bone's blend lasts this share of RISE after its lag;
## the climb's speed (m/s) from and to, its angle (rad) from and to.
const RISE_WINDOW := 0.55
const RISE_SPEED := Vector2(4.0,26.0)
const RISE_CLIMB := Vector2(1.0,0.3)
## Landing: the bones blend from SETTLE_FROM of it, each over this share.
const SETTLE_FROM := 0.3
const SETTLE_WINDOW := 0.4
## The circuit's ends: the takeoff's first point and the landing's last
## approach, out from the ledge along `away` (m) and up (m over the ledge).
const DEPART := Vector2(170.0,40.0)
const APPROACH := Vector2(150.0,30.0)
## Over the aqueduct isle: his height over its turf (m; its summit is some
## 14 m over the turf, its arches less).
const HOME_OVER := 62.0
## The circuit (world x, z, y): [kind, x, z, y]. "at" a point; "home" the
## aqueduct isle's middle, its y HOME_OVER over the turf. Laid between the
## motif isles' circles (scripts/kit_isle/motif_sky.gd PLACES and REACH),
## each gap threaded across its line: keel/spires westward, colonnade/gorge
## westward, gorge/nave eastward, keel/spires eastward again.
const CIRCUIT := [
	[600.0,230.0,120.0],
	[392.0,207.0,78.0],
	[230.0,110.0,92.0],
	"home",
	[-120.0,-205.0,105.0],
	[-250.0,-110.0,88.0],
	[-470.0,20.0,100.0],
	[-450.0,215.0,88.0],
	[-265.0,215.0,80.0],
	[-60.0,215.0,86.0],
	[392.0,207.0,82.0],
	[620.0,240.0,130.0],
]

var dragon: Node3D
var roost: RefCounted
## The air round the roost (scripts/roost_air.gd), for its dust and birds.
var air: Node3D
## The world clock's hours so far (day*24 + hour), or below 0 held.
var hours: Callable
## The aqueduct isle's middle (x, z) and turf height.
var home := Vector3(85.0,30.0,-20.0)

## asleep, stirring, rising, flying, settling.
var phase := "asleep"
var _t := 0.0
var _since := 0.0
var _wake_at := -1.0
var _scheduled := true
var _hours_was := -1.0
## The coil's frame (the dragon's, asleep), and the way out off the ledge.
var coil_xf := Transform3D.IDENTITY
var ledge := Vector3.ZERO
var away := Vector3.FORWARD
## His head's lift now (0..1) and its look round (rad).
var _lift := 0.0
var _look := 0.0
var _roared := false
var _dusted := false
## Landing's curve: from, its two pulls, to.
var _p := [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
## How many times he has woken; seconds out on the last.
var wakes := 0
var outing := 0.0

func setup(owner: Node3D, roost_air: Node3D, args: PackedStringArray, clock_hours: Callable, home_at: Vector3) -> void:
	dragon = owner
	roost = dragon.get("roost")
	air = roost_air
	hours = clock_hours
	home = home_at
	coil_xf = dragon.global_transform
	var t2 := Roost.own(Roost.TOWER_C)
	var l2 := Roost.own(Roost.LEDGE_C)
	ledge = Vector3(l2.x,Roost.TOP+Roost.LEDGE_H*Roost.SPAN,l2.y)+Roost.AT
	away = Vector3(l2.x-t2.x,0.0,l2.y-t2.y).normalized()
	for arg in args:
		if arg == "--dragon-wake": _wake_at = FLAG_AFTER
		elif arg.begins_with("--dragon-wake-at="): _wake_at = maxf(float(arg.get_slice("=",1)),0.0)
		elif arg == "--no-dragon-wake": _scheduled = false
	if _wake_at >= 0.0: print("dragon wake: he wakes %.1f s after load" % _wake_at)

## Whether he is awake (stirring, out or landing).
func out() -> bool:
	return phase != "asleep"

func advance(delta: float) -> void:
	_since += delta
	match phase:
		"asleep":
			roost.advance(delta)
			if _due(): _begin_stir()
		"stirring": _stir(delta)
		"rising": _rise(delta)
		"flying": _flying(delta)
		"settling": _settle(delta)

## Whether he wakes now: the flag's time, else WAKE_HOUR crossed on a live
## clock once FIRST_AFTER s have passed.
func _due() -> bool:
	if _wake_at >= 0.0 and _since >= _wake_at:
		_wake_at = -1.0
		return true
	var now: float = float(hours.call()) if hours.is_valid() else -1.0
	var was := _hours_was
	_hours_was = now
	if not _scheduled or now < 0.0 or was < 0.0 or _since < FIRST_AFTER: return false
	return floor((was-WAKE_HOUR)/24.0) < floor((now-WAKE_HOUR)/24.0)

# --- Stirring ---------------------------------------------------------------------------

func _begin_stir() -> void:
	phase = "stirring"
	_t = 0.0
	_lift = 0.0
	_roared = false
	wakes += 1
	outing = 0.0
	dragon.set("state","waking")
	# His flight's dice (its bouts of beats, bumps, roars) the same each wake
	# of a run's count, so a wake can be seen again.
	(dragon.get("_rng") as RandomNumberGenerator).seed = 7+wakes
	dragon.set("flap_w",0.0)
	dragon.set("speed",0.0)
	print("dragon wake: he stirs (%.0f s in)" % _since)

## The coil breathing on, the eyes open, the head up off its shelf and
## looking round, a roar, a beat.
func _stir(delta: float) -> void:
	_t += delta
	roost.advance(delta)
	if _t >= EYES_AT and _t-delta < EYES_AT: dragon.call("open_eyes",true)
	_lift = smoothstep(LIFT_IN.x,LIFT_IN.y,_t)
	_look = LOOK*sin(clampf((_t-LIFT_IN.y)/(STIR-LIFT_IN.y),0.0,1.0)*TAU)*smoothstep(LIFT_IN.y,LIFT_IN.y+1.0,_t)
	if not _roared and _t >= ROAR_AT:
		_roared = true
		dragon.set("_roar_t",0.0)
	# The jaw on the flight's springs (its roar); the rest is the coil's.
	if _roared: dragon.call("_mouth",delta)
	_lift_head(_lift,_look)
	outing += delta
	if _t >= STIR: _begin_rise()

## The neck and head lifted off their shelf by `k` of LIFT (each about its
## own across, so up and out from the rock), the head turned `look`.
func _lift_head(k: float, look: float) -> void:
	var sk: Skeleton3D = dragon.get("skeleton")
	var bones: Dictionary = dragon.get("_bone")
	var rest: Dictionary = dragon.get("_rest_global")
	for b: String in LIFT:
		if not bones.has(b): continue
		var g: Basis = rest[b]
		var q := sk.get_bone_pose_rotation(bones[b])
		q = q*Quaternion((g.inverse()*Vector3.RIGHT).normalized(),float(LIFT[b])*k)
		if b == "neck.3" or b == "head": q = q*Quaternion((g.inverse()*Vector3.UP).normalized(),look*0.5)
		sk.set_bone_pose_rotation(bones[b],q)

# --- Taking off -------------------------------------------------------------------------

func _begin_rise() -> void:
	phase = "rising"
	_turns.clear()
	_t = 0.0
	_dusted = false
	dragon.set("state","taking off")
	dragon.set("pos",coil_xf.origin+Vector3.UP*2.0)
	dragon.set("yaw",atan2(-away.x,-away.z))
	dragon.set("gamma",RISE_CLIMB.x)
	dragon.set("speed",RISE_SPEED.x)
	dragon.set("roll",0.0)
	dragon.set("yaw_rate",0.0)
	dragon.set("flap_w",0.0)
	dragon.set("phase",0.55)
	dragon.set("mode","climb")
	dragon.set("_bout",true)
	dragon.set("_flare",0.0)
	dragon.set("_rope_ready",false)
	dragon.set("_body_q_on",false)
	_haze_off()
	print("dragon wake: he takes off")

## Each bone's start into the takeoff (share of RISE): the head first, the
## neck after it from its head end, the chest and wings, the hips and legs,
## the tail last, root to tip.
static func _lag_rise(b: String) -> float:
	if b == "head" or b.begins_with("jaw"): return 0.0
	if b.begins_with("neck."): return 0.02+0.04*float(3-int(b.get_slice(".",1)))
	if b.begins_with("wing_arm"): return 0.2
	if b.begins_with("wing_fore"): return 0.23
	if b.begins_with("wing_hand"): return 0.26
	if b.begins_with("wing_f"): return 0.28
	if b.begins_with("hind"): return 0.3
	if b == "hips": return 0.28
	if b.begins_with("tail."): return 0.3+0.012*float(int(b.get_slice(".",1)))
	return 0.18

## Up off the ledge: the coil (its head still lifted) eased bone by bone
## into the flight's pose, the body from the coil's frame into the climb's;
## the climb flown here: from slow and steep to cruising, out over the
## ledge, turning toward the circuit's first point.
func _rise(delta: float) -> void:
	_t += delta
	outing += delta
	var u := clampf(_t/RISE,0.0,1.0)
	if not _dusted and u > 0.04:
		_dusted = true
		if air != null:
			air.call("dust",ledge,1.0)
			air.call("scatter")
	roost.advance(delta)
	_haze_off()
	_lift_head(1.0,0.0)
	var coil := _take()
	var s := smoothstep(0.0,1.0,u)
	var first := _point(0)
	var to_first := atan2(-(first.x-coil_xf.origin.x),-(first.z-coil_xf.origin.z))
	var yaw := lerp_angle(atan2(-away.x,-away.z),to_first,smoothstep(0.35,1.0,u))
	var climb := lerpf(RISE_CLIMB.x,RISE_CLIMB.y,s)
	var speed := lerpf(RISE_SPEED.x,RISE_SPEED.y,s)
	dragon.set("yaw",yaw)
	dragon.set("gamma",climb)
	dragon.set("speed",speed)
	dragon.set("flap_w",smoothstep(0.1,0.35,u))
	dragon.set("phase",fposmod(float(dragon.get("phase"))+delta*SkyDragon.BEAT_CLIMB*1.2,1.0))
	var fwd := Vector3(-sin(yaw)*cos(climb),sin(climb),-cos(yaw)*cos(climb))
	dragon.set("pos",(dragon.get("pos") as Vector3)+fwd*speed*delta)
	dragon.call("wake_pose",delta)
	var flight := _take()
	var flight_xf: Transform3D = dragon.global_transform
	var weights := {}
	for b: String in (dragon.get("_bone") as Dictionary):
		weights[b] = smoothstep(0.0,1.0,(u-_lag_rise(b))/RISE_WINDOW)
	_mix(coil,flight,weights)
	dragon.global_transform = _blend_xf(coil_xf,flight_xf,smoothstep(0.1,0.7,u))
	if u >= 1.0: _begin_flying()

# --- The circuit -------------------------------------------------------------------------

## The circuit's point `i` (world): CIRCUIT's, the home pass's over the
## aqueduct isle.
func _point(i: int) -> Vector3:
	if i == 0: return ledge+away*DEPART.x+Vector3.UP*DEPART.y
	var c: Variant = CIRCUIT[i-1]
	if c is String: return Vector3(home.x,home.y+HOME_OVER,home.z)
	return Vector3(float(c[0]),float(c[2]),float(c[1]))

## The whole circuit: out from the ledge, CIRCUIT, the landing's approach,
## and the roost itself after it (never reached in flight: the landing
## takes over once the approach is passed).
func circuit() -> Array:
	var pts: Array = []
	for i in range(CIRCUIT.size()+1): pts.append(_point(i))
	pts.append(ledge+away*APPROACH.x+Vector3.UP*APPROACH.y)
	pts.append(coil_xf.origin+Vector3.UP*20.0)
	return pts

func _begin_flying() -> void:
	phase = "flying"
	dragon.set("state","roaming")
	var route := circuit()
	var kinds: Array = []
	for i in range(route.size()): kinds.append("circuit")
	dragon.set("route",route)
	dragon.set("_leg_kinds",kinds)
	dragon.set("_bout",true)
	print("dragon wake: he flies his circuit (%d points)" % route.size())

func _flying(delta: float) -> void:
	outing += delta
	dragon.call("wake_fly",delta)
	var left: Array = dragon.get("route")
	if left.size() <= 1 or outing > OUT_MOST: _begin_settle()

# --- Landing -----------------------------------------------------------------------------

func _begin_settle() -> void:
	phase = "settling"
	_turns.clear()
	_t = 0.0
	_dusted = false
	dragon.set("state","landing")
	var from: Vector3 = dragon.get("pos")
	var yaw := float(dragon.get("yaw"))
	var gamma := float(dragon.get("gamma"))
	var fwd := Vector3(-sin(yaw)*cos(gamma),sin(gamma),-cos(yaw)*cos(gamma))
	var to := coil_xf.origin
	var span := from.distance_to(to)
	_p = [from,from+fwd*span*0.35,to+away*span*0.3+Vector3.UP*span*0.3,to]
	print("dragon wake: he comes in to land from %.0f m out (%.0f s out)" % [span,outing])

static func _bezier(p: Array, s: float) -> Vector3:
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var c: Vector3 = p[2]
	var d: Vector3 = p[3]
	var r := 1.0-s
	return a*r*r*r+b*3.0*r*r*s+c*3.0*r*s*s+d*s*s*s

## Each bone's start back into the coil (share of SETTLE after SETTLE_FROM):
## the hips, legs and chest down first, the wings folding, the tail laid
## round from its root, the neck wound round the tower, the head last.
static func _lag_land(b: String) -> float:
	if b == "hips" or b.begins_with("hind") or b == "chest" or b == "root": return 0.0
	if b.begins_with("wing_"): return 0.05
	if b.begins_with("tail."): return 0.06+0.02*float(int(b.get_slice(".",1)))
	if b == "spine.2": return 0.1
	if b.begins_with("neck."): return 0.16+0.03*float(int(b.get_slice(".",1)))
	if b == "head" or b.begins_with("jaw"): return 0.3
	return 0.05

## In along the curve, slowing, flared; each bone eased back into the coil,
## the body into the coil's frame; dust as he sets down.
func _settle(delta: float) -> void:
	_t += delta
	outing += delta
	var u := clampf(_t/SETTLE,0.0,1.0)
	var s := 1.0-(1.0-u)*(1.0-u)
	var at := _bezier(_p,s)
	var was: Vector3 = dragon.get("pos")
	var step := at-was
	var flat := Vector2(step.x,step.z)
	# Facing along the curve while it still carries him on (not over the
	# last of it, nearly straight down onto the ledge).
	if flat.length() > 1.0*delta: dragon.set("yaw",atan2(-step.x,-step.z))
	var flare := smoothstep(0.2,0.55,u)*(1.0-smoothstep(0.85,1.0,u))
	dragon.set("pos",at)
	dragon.set("speed",step.length()/maxf(delta,0.001))
	# Out of the flight eased, not set: its bank and turn level out, its
	# pitch comes nose up into the flare, its wings come to heavy beats
	# (from a glide or a dive's tuck), the mode following its pitch as in
	# flight (sky_dragon.gd `_fly`), so nothing snaps.
	var gamma := move_toward(float(dragon.get("gamma")),0.25*flare,0.4*delta)
	dragon.set("gamma",gamma)
	dragon.set("roll",lerpf(float(dragon.get("roll")),0.0,1.0-exp(-delta*1.5)))
	dragon.set("yaw_rate",lerpf(float(dragon.get("yaw_rate")),0.0,1.0-exp(-delta*1.5)))
	dragon.set("_flare",flare)
	var beat := 1.0-smoothstep(0.75,0.95,u)
	dragon.set("flap_w",move_toward(float(dragon.get("flap_w")),beat,delta*1.4))
	dragon.set("mode","climb" if gamma > 0.22 else ("dive" if gamma < -0.2 else "cruise"))
	dragon.set("phase",fposmod(float(dragon.get("phase"))+delta*SkyDragon.BEAT_CLIMB*1.3,1.0))
	if not _dusted and u > 0.62:
		_dusted = true
		if air != null: air.call("dust",ledge,0.8)
	roost.advance(delta)
	_haze_off()
	# The head comes down onto its shelf last.
	_lift_head(1.0-smoothstep(0.8,1.0,u),0.0)
	var coil := _take()
	dragon.call("wake_pose",delta)
	var flight := _take()
	var flight_xf: Transform3D = dragon.global_transform
	var weights := {}
	for b: String in (dragon.get("_bone") as Dictionary):
		weights[b] = 1.0-smoothstep(0.0,1.0,(u-SETTLE_FROM-_lag_land(b))/SETTLE_WINDOW)
	_mix(coil,flight,weights)
	dragon.global_transform = _blend_xf(coil_xf,flight_xf,1.0-smoothstep(SETTLE_FROM,0.85,u))
	if u >= 1.0: _sleep()

## Back asleep in his coil, the eyes shut, the watch camera given back.
func _sleep() -> void:
	phase = "asleep"
	dragon.set("state","roosting")
	dragon.set("flap_w",0.0)
	dragon.set("speed",0.0)
	dragon.set("_flare",0.0)
	dragon.set("_roar_t",-1.0)
	dragon.set("_rope_ready",false)
	dragon.set("_body_q_on",false)
	dragon.set("route",[])
	dragon.set("_leg_kinds",[])
	dragon.call("open_eyes",false)
	dragon.global_transform = coil_xf
	roost.advance(0.0001)
	if str(dragon.get("watch")) != "":
		dragon.set("watch","")
		var cam: Camera3D = dragon.get("camera")
		var fov := float(dragon.get("_fov"))
		if cam != null and fov > 0.0: cam.fov = fov
	print("dragon wake: he is back asleep on his roost (%.0f s out)" % outing)

# --- Poses -------------------------------------------------------------------------------

## The roost's nostril haze off while he is up (it puffs only asleep).
func _haze_off() -> void:
	var haze: CPUParticles3D = roost.get("_haze")
	if haze != null: haze.emitting = false

## Every bone's turn and scale now: [rotations, scales] by bone index.
func _take() -> Array:
	var sk: Skeleton3D = dragon.get("skeleton")
	var rots: Array[Quaternion] = []
	var scales: Array[Vector3] = []
	for i in range(sk.get_bone_count()):
		rots.append(sk.get_bone_pose_rotation(i))
		scales.append(sk.get_bone_pose_scale(i))
	return [rots,scales]

## Each bone between the coil's pose and the flight's by its weight (0 the
## coil, 1 the flight): turned from the coil's by that share of its turn to
## the flight's, scales (the chest's swell, the folded fingers' shortening)
## lerped. The turn between them is kept continuous from frame to frame
## (`_turns`): a beating wing's goes past half a turn now and then, and a
## plain slerp would flip the other way round there.
var _turns := {}

func _mix(coil: Array, flight: Array, weights: Dictionary) -> void:
	var sk: Skeleton3D = dragon.get("skeleton")
	var bones: Dictionary = dragon.get("_bone")
	for b: String in bones:
		var i: int = bones[b]
		var w := float(weights.get(b,0.0))
		var qa: Quaternion = coil[0][i]
		var qb: Quaternion = flight[0][i]
		var r := _turn_between(i,qa,qb)
		var q := qa
		if r.length() > 0.000001: q = (qa*Quaternion(r.normalized(),r.length()*w)).normalized()
		sk.set_bone_pose_rotation(i,q)
		sk.set_bone_pose_scale(i,(coil[1][i] as Vector3).lerp(flight[1][i] as Vector3,w))

## The turn from `qa` to `qb` as axis times angle, the way round nearest
## last frame's for bone `i`.
func _turn_between(i: int, qa: Quaternion, qb: Quaternion) -> Vector3:
	var d := (qa.inverse()*qb).normalized()
	if d.w < 0.0: d = -d
	var angle := 2.0*acos(clampf(d.w,-1.0,1.0))
	var axis := Vector3(d.x,d.y,d.z)
	if axis.length() < 0.000001:
		_turns[i] = Vector3.ZERO
		return Vector3.ZERO
	axis = axis.normalized()
	var near := axis*angle
	var far := axis*(angle-TAU)
	var r := near
	if _turns.has(i) and (_turns[i] as Vector3).distance_to(far) < (_turns[i] as Vector3).distance_to(near): r = far
	_turns[i] = r
	return r

static func _blend_xf(a: Transform3D, b: Transform3D, w: float) -> Transform3D:
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(),w)
	return Transform3D(Basis(q),a.origin.lerp(b.origin,w))
