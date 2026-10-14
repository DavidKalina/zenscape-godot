extends Node
## The wind-horn's runtime (scripts/ruin_kit_horn.gd builds the stone and
## adds this as its "Rig"): the head turns, draws its breath, kicks, and can
## be knocked out for a while. Light: a handful of dust motes and leaves
## and a few puffs, plain meshes, nothing glowing.
##   aim_at(point, delta)   turn the head and pitch the barrel toward a
##                          world point: heavy, but it keeps up
##   aim_error(point)       radians between the barrel's facing and a point
##   tell(share)            the wind-up, 0..1 (below 0: no tell)
##   fired()                the kick and the puff at the shot
##   disabled(seconds)      slumped and mouth tipped down, then it grinds up
##   is_disabled()
##   watch(motor, knobs)    it blows (below); without it, dressing only
##   reset_blow()           back to watching, the breath let go
## The head's yaw is about +Y from +Z (the way the Mouth points); the
## barrel's pitch about its trunnion's x, positive down. `yaw_arc` (rad
## either side of the piece's front, PI all round) limits the turn: a horn
## set into a wall can't turn behind itself.
##
## The blow (docs/design/roguelike/wind-horn-blows.md). Given the pilot's
## motor with `watch`, the horn is a ward: it sweeps its arc, and when it
## notices him (the wake rule: on the ground moving faster than
## `notice_pace` within `view` of where it looks, a splash (wading on, or
## swimming), or a body in the air, anywhere in its arc; always within
## `reach`, inside its pitch (under its lip it can't point), in sight) it
## turns on him and draws its breath for `delay` s (the tell: the chest
## swells, dust and leaves drawn into the mouth, the bell shudders, a
## rising inhale), then, settled on him (`on_him`), blows for `blast_time`
## (the chest empties, the head kicks, fast puffs): the first frame his chest is
## within `cone` of its facing and in reach, the wind blaster's own knock
## (scripts/traps/gust.gd: `blast_out` m along the barrel's flat facing,
## `blast_up` m up), once per blow, the horn piece as the source. Then it
## rests `rearm` s. A breath on him that never lines up blows anyway
## `turn_max` past the tell. Knobs from the pilot at the wanderer's size
## (Gust.defaults; `reach`, `notice_pace` from the run and walk).
## That is `shot` "gust". The default, `shot` "ball": the tell runs
## `ball_tell` (the gust arrows' 0.8 s, the ball gathering in the mouth)
## and always ends in a shot: the gust arrows' ball (DragonAirBlast) out of
## the mouth at where he will be (his flat pace led, no homing: a juke
## beats it), or, if he broke its line mid-tell, where he was heading; it
## leaves up to `off_barrel` off the barrel where the head can't point;
## stone pops it; its burst throws him out from the burst as hard as the
## gust (blast_out / blast_up at its heart), the horn the source. A watching
## horn pitches down to PITCH_DOWN_WARD; `slam` on its top knocks it out.
## `may_draw` (a Callable -> bool), if set, is asked before it draws
## breath: a shared bellows. `step` runs by itself each frame (`auto`);
## a host may turn that off and call `step(delta)` itself.
const Gust = preload("res://scripts/traps/gust.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const AirBlast = preload("res://scripts/dragon_air_blast.gd")

signal woke(why: String)
signal blew(hit: bool)

## The head's turn: it closes TURN_GAIN of its error a second, never faster
## than TURN_RATE (rad/s): heavy, grinding, settling onto him, but quick
## enough to keep a running or gliding pilot in its mouth at its range.
## The barrel's pitch the same (PITCH_GAIN, PITCH_RATE), up to PITCH_UP
## over level and PITCH_DOWN under it (rad): steep up at a pilot over it;
## down only as far as the bell clears its own pedestal, so under its lip
## is out of its reach.
const TURN_RATE := 2.4
const TURN_GAIN := 10.0
const PITCH_RATE := 1.8
const PITCH_GAIN := 10.0
const PITCH_UP := 1.22
const PITCH_DOWN := 0.3
## Disabled: the mouth tips down this far (rad), the head sags sideways
## (roll, rad) and drops (m); the last share of the time it grinds back up.
const DROOP_PITCH := 0.6
const DROOP_ROLL := 0.14
const DROOP_DROP := 0.12
const RISE_SHARE := 0.35
## The recoil kick: its speed (m/s) back along the head's axis, the pitch it
## throws up per metre of recoil (rad), and the spring that takes it out.
const KICK_SPEED := 4.5
const KICK_PITCH := 0.3
const KICK_STIFF := 70.0
const KICK_DAMP := 9.0
## The bell's shudder at the full tell (m).
const SHUDDER := 0.02
const MOTES := 16
const PUFFS := 14
const DUST := Color(0.86,0.82,0.70)
const LEAF := Color(0.36,0.5,0.24)
## How far from the mouth the drawn-in motes start (m).
const DRAW_FROM := Vector2(2.0,5.0)
## The bellows drawing: the chest swells this share wide (and SWELL_UP of
## it tall) at the full tell, eased in; at the blow it empties, squashed
## EMPTY under its rest, and springs back (EMPTY_STIFF, EMPTY_DAMP).
const SWELL := 0.12
const SWELL_UP := 0.35
const EMPTY := 0.08
const EMPTY_STIFF := 60.0
const EMPTY_DAMP := 7.0
## The gust's look: puffs out along the barrel this fast (m/s).
const GUST_PUFFS := 6
const GUST_SPEED := Vector2(9.0,16.0)
## His chest over his feet, as a share of the walker's head height.
const CHEST_SHARE := 0.8
## What blocks its sight (the air blast's solids and turf).
const SIGHT_MASK := AirBlast.MASK

## A watching horn's deepest pitch (rad under level): the bell's lip at
## 3 m out then just clears the ground at the pedestal's own foot (the
## pedestal's top never meets the barrel: its underside stays over it to
## past 1 rad). Dressing horns keep PITCH_DOWN.
const PITCH_DOWN_WARD := 0.55
## The ball (shot "ball"): the gust arrows' ball (studies/crossings/
## gust_arrows.gd, scripts/dragon_air_blast.gd), here leading him rather
## than homing, so a juke beats it.
const GustArrows = preload("res://studies/crossings/gust_arrows.gd")
## Slammed on its pedestal top or cap (scripts/slam.gd GROUP): down this long.
const SlamScript = preload("res://scripts/slam.gd")

## The turn's limit either side of the piece's front (rad); PI: all round.
var yaw_arc := PI
## The barrel's deepest pitch (rad): PITCH_DOWN, PITCH_DOWN_WARD once watching.
var pitch_down := PITCH_DOWN
## The ball's blast (shot "ball"), made by `watch`.
var blast: Node3D = null
## Tells drawn, shots fired (a tell always ends in one, or in a knock-out).
var tells := 0
var shots := 0
var knocked_out_tells := 0
var _last_seen := Vector3.INF
var _last_vel := Vector3.ZERO
var _since_seen := 0.0
## The blow's knobs (see the header); `watch` merges its own.
var knobs := {}
## The pilot's motor it watches, or null: dressing only.
var motor: RefCounted = null
## Its own frames: `step` from _process. Off: the host calls step(delta).
var auto := true
## Leave to draw breath (a Callable -> bool), or none: always.
var may_draw := Callable()
## "watch", "tell", "blow", "rest"; how long in it; what woke it.
var state := "watch"
var state_t := 0.0
var why := ""
var blows := 0
var hits := 0
## The last knock it gave (m/s), zero if none.
var last_knock := Vector3.ZERO
var _hit := false
var _sweep := 0.0
var _sweep_dir := 1.0
var _excl: Array[RID] = []
var _chest_mesh: Node3D
var _empty := 0.0
var _empty_v := 0.0
var _breath: AudioStreamPlayer3D
var _whoosh: AudioStreamPlayer3D

var yaw := 0.0
var pitch := 0.0
var _head: Node3D
var _barrel: Node3D
var _mouth: Node3D
var _base := Vector3.ZERO
var _pivot := Vector3.ZERO
var _recoil := 0.0
var _recoil_v := 0.0
var _left := 0.0
var _total := 1.0
var _share := -1.0
var _telling := 0.0
var _dust_t := 0.0
var _clock := 0.0
var _motes: Array = []
var _puffs: Array = []
var _rng := RandomNumberGenerator.new()
var _sound: AudioStreamPlayer3D
var _mouth_r := 0.8

func _ready() -> void:
	_head = get_parent().get_node("Head")
	_barrel = _head.get_node("Barrel")
	_mouth = _barrel.get_node("Mouth")
	_base = _head.position
	_pivot = _barrel.position
	_mouth_r = float(get_parent().get_meta("mouth_radius",0.8))
	_rng.seed = 11
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.05
	dust_mesh.height = 0.1
	dust_mesh.radial_segments = 6
	dust_mesh.rings = 3
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = Vector3(0.16,0.02,0.1)
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 0.5
	puff_mesh.height = 1.0
	puff_mesh.radial_segments = 8
	puff_mesh.rings = 4
	for i in range(MOTES):
		var leaf := i%3 == 0
		var m := _blob(leaf_mesh if leaf else dust_mesh,LEAF if leaf else DUST,_barrel)
		_motes.append({"node":m,"phase":_rng.randf(),"from":_far(),"spin":_rng.randf_range(-6.0,6.0)})
	for i in range(PUFFS):
		_puffs.append({"node":_blob(puff_mesh,DUST,self,true),"age":1.0,"life":1.0,"pos":Vector3.ZERO,"vel":Vector3.ZERO,"s0":0.2,"s1":0.5,"a":0.4})
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = _crack()
	_sound.unit_size = 14.0
	add_child(_sound)
	_chest_mesh = _head.get_node_or_null("Mesh") as Node3D
	_breath = AudioStreamPlayer3D.new()
	_breath.stream = _hiss(0.5,true)
	_breath.unit_size = 14.0
	add_child(_breath)
	_whoosh = AudioStreamPlayer3D.new()
	_whoosh.stream = _hiss(0.45,false)
	_whoosh.unit_size = 18.0
	add_child(_whoosh)

## Turn the head and pitch the barrel toward `point` (world) (TURN_GAIN,
## TURN_RATE; PITCH_GAIN, PITCH_RATE): the barrel's axis through the point.
## Nothing while disabled.
func aim_at(point: Vector3, delta: float) -> void:
	if _left > 0.0 or _head == null: return
	var parent := _head.get_parent() as Node3D
	var local: Vector3 = parent.to_local(point)-_base
	var flat := Vector2(local.x,local.z)
	var before := yaw
	if flat.length() > 0.1:
		var turn := TURN_RATE*delta
		var aim := atan2(local.x,local.z)
		var err := angle_difference(yaw,aim)
		if yaw_arc < PI:
			# Kept in its arc: the way round inside it, never behind.
			err = clampf(aim,-yaw_arc,yaw_arc)-yaw
		yaw += clampf(err*minf(TURN_GAIN*delta,1.0),-turn,turn)
		if yaw_arc < PI: yaw = clampf(yaw,-yaw_arc,yaw_arc)
		# From the trunnion (out along the yaw, up AXIS): the axis's pitch.
		var want := clampf(-atan2(local.y-_pivot.y,flat.length()-_pivot.z),-PITCH_UP,pitch_down)
		var tip := PITCH_RATE*delta
		pitch += clampf((want-pitch)*minf(PITCH_GAIN*delta,1.0),-tip,tip)
	# Grinding: stone dust off the turntable's edge while it turns.
	_dust_t -= delta
	if absf(yaw-before) > 0.5*delta and _dust_t <= 0.0:
		_dust_t = 0.3
		var at := parent.to_global(_base+Vector3(sin(yaw),0.1,cos(yaw))*-1.1)
		_puff(at,Vector3(_rng.randf_range(-0.3,0.3),0.5,_rng.randf_range(-0.3,0.3)),0.12,0.4,0.7,0.3)
	_apply()

## The wind-up's share, 0..1 (DragonAirBlast.windup_share(); -1 when not
## winding up). Dust and leaves drawn into the mouth, the bell shuddering.
## Nothing while disabled.
func tell(share: float) -> void:
	if _left > 0.0 or share < 0.0:
		_share = -1.0
		return
	_share = share
	_telling = 0.15

## The shot has left: the head kicks back and the mouth puffs.
func fired() -> void:
	if _left > 0.0: return
	_recoil_v = KICK_SPEED
	# The bellows empty: the swell let go past its rest, then back.
	_empty = 1.0
	_empty_v = 0.0
	_share = -1.0
	var way := _mouth.global_transform.basis.z
	for i in range(7):
		var d := (way+Vector3(_rng.randf_range(-0.5,0.5),_rng.randf_range(-0.4,0.5),_rng.randf_range(-0.5,0.5))).normalized()
		_puff(_mouth.global_position+way*0.2,d*_rng.randf_range(2.5,5.0),_mouth_r*0.4,_mouth_r*1.3,_rng.randf_range(0.5,0.9),0.45)

## Knocked out for `seconds`: the head slumps, the mouth tips down; over the
## last RISE_SHARE of it the head grinds back up. aim_at and tell do
## nothing meanwhile.
func disabled(seconds: float) -> void:
	_total = maxf(seconds,0.1)
	_left = _total
	_share = -1.0
	for i in range(9):
		var a := TAU*i/9.0+_rng.randf()
		var out := Vector3(cos(a),0.0,sin(a))
		_puff(_head.global_position+out*1.0+Vector3(0.0,1.2,0.0),out*_rng.randf_range(1.0,2.5)+Vector3(0.0,1.2,0.0),0.25,1.0,_rng.randf_range(0.6,1.1),0.55)
	if _sound.is_inside_tree():
		_sound.global_position = _head.global_position+Vector3(0.0,1.2,0.0)
		_sound.play()

func is_disabled() -> bool:
	return _left > 0.0

## The angle (rad) between the barrel's facing and the way from its mouth
## to `point` (world): under a few degrees, a shot leaves at him.
func aim_error(point: Vector3) -> float:
	if _mouth == null: return PI
	var to := point-_mouth.global_position
	if to.length() < 0.01: return 0.0
	return _mouth.global_transform.basis.z.angle_to(to)

## The way the barrel faces (world, unit).
func facing() -> Vector3:
	return _mouth.global_transform.basis.z.normalized() if _mouth != null else Vector3.FORWARD

# --- The blow ---------------------------------------------------------------

## The blow's knobs at the wanderer's size: the gust's (Gust.defaults:
## blast_out run x 3, blast_up run x 0.25, delay 0.5, blast_time 0.3, rearm
## 2.0) and the watch's: `reach` (m, about twice its throw), `cone` (rad,
## the beam's half-angle a blow hits), `settle` (rad: the head's turn this
## close to his bearing before it blows), `notice_pace` (m/s, walk / 3: slower
## is a creep it doesn't see), `view` (rad either side of where it looks
## that it sees a mover), `sweep` (rad/s, its idle turn) over `sweep_share`
## of its arc, `turn_max` (s past the tell it blows anyway).
static func blow_defaults() -> Dictionary:
	var p := Gust.PilotMotor.new()
	p.set_size(Gust.WorldScale.wanderer)
	var out := Gust.defaults(p)
	out.merge({"reach":float(out.blast_out)*2.2,"cone":0.25,"settle":0.08,"notice_pace":p.walk/3.0,"view":0.6,
		"sweep":0.45,"sweep_share":0.85,"turn_max":1.5,
		# The ball: the gust arrows' wind-up length as its tell, speed, fuse,
		# the share of his flat pace led (1: all of it; no homing), and how
		# far off the barrel (rad) it may leave where the head can't point.
		"shot":"ball","ball_tell":GustArrows.WINDUP,"ball_speed":GustArrows.SPEED,"fuse":GustArrows.FUSE,
		"lead":1.0,"off_barrel":0.35})
	return out

## Watch `who` (a PilotMotor, or null to stop: dressing only) and blow at
## him; `over` overrides knobs by name (see blow_defaults).
func watch(who: RefCounted, over := {}) -> void:
	motor = who
	knobs = blow_defaults()
	knobs.merge(over,true)
	_excl.clear()
	_collect(get_parent(),_excl)
	pitch_down = PITCH_DOWN_WARD if who != null else PITCH_DOWN
	if who != null and not is_in_group(SlamScript.GROUP): add_to_group(SlamScript.GROUP)
	if who != null and ball() and blast == null:
		# The gust arrows' ball, as add_launcher sets it, but led, not homing,
		# and thrown as hard as the gust at the burst's heart.
		var b := AirBlast.new()
		b.publish = false
		b.speed = knob("ball_speed")
		b.homing = 0.0
		b.fire_range = knob("reach")*3.0
		b.flight = GustArrows.FLY
		b.fuse = knob("fuse")
		b.lead_flat = true
		b.lead_share = knob("lead")
		b.glow = GustArrows.GLOW
		b.tint = GustArrows.TINT
		b.gather = GustArrows.GATHER
		b.span = GustArrows.TRAIL/0.12
		b.knock_out = knob("blast_out")/AirBlast.walker_tall()
		b.knock_up = knob("blast_up")/AirBlast.walker_tall()
		b.see_through = _excl
		add_child(b)
		blast = b
	reset_blow()

func knob(key: String) -> float:
	return float(knobs.get(key,0.0))

## Back to watching, the breath let go.
func reset_blow() -> void:
	state = "watch"
	state_t = 0.0
	why = ""
	_hit = false
	_sweep = clampf(yaw,-yaw_arc,yaw_arc) if yaw_arc < PI else wrapf(yaw,-PI,PI)
	tell(-1.0)

## His chest (world).
func chest() -> Vector3:
	var m: Variant = motor
	return m.feet+Vector3.UP*PhysicsGround.HEAD*float(m.size)*CHEST_SHARE

## The horn's bearing (rad, in its piece's frame, from its front) to `point`.
func bearing(point: Vector3) -> float:
	var local: Vector3 = (get_parent() as Node3D).to_local(point)
	return atan2(local.x,local.z)

## It could blow at `point` (world): in reach, in its arc, inside its
## pitch (under its lip it can't), nothing solid between.
func can_reach(point: Vector3) -> bool:
	if _mouth == null or not _mouth.is_inside_tree(): return false
	var from := _mouth.global_position
	if from.distance_to(point) > knob("reach"): return false
	if yaw_arc < PI and absf(bearing(point)) > yaw_arc+knob("cone"): return false
	var flat := Vector2(point.x-from.x,point.z-from.z).length()
	var down := atan2(from.y-point.y,maxf(flat,0.01))
	# Its pitch, plus what leaves off it: the gust's beam, or the ball sent
	# off_barrel off the barrel. Nearer under its lip than that: safe.
	var slack := knob("off_barrel") if ball() else knob("cone")*0.8
	if down > pitch_down+slack or -down > PITCH_UP+slack: return false
	var q := PhysicsRayQueryParameters3D.create(from,point,SIGHT_MASK)
	q.exclude = _excl
	return _mouth.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## What wakes it now: "air" (a body in the air), "splash" (wading on, or
## swimming), "seen" (moving faster than notice_pace within view of where
## it looks), or "". A body already tumbling is not news.
func noise() -> String:
	var m: Variant = motor
	if m.move == "tumble" or not Gust.can_take(m): return ""
	if not m.grounded and not m.on_ledge() and not m.swimming: return "air"
	var pace := Vector2(m.velocity.x,m.velocity.z).length()
	if m.swimming or float(m.wade) > 0.03 and pace > 0.2: return "splash"
	if pace > knob("notice_pace") and absf(angle_difference(yaw,bearing(chest()))) < knob("view"): return "seen"
	return ""

## One frame of the ward (from _process while `auto`).
func step(delta: float) -> void:
	if motor == null: return
	_brain(delta)
	if blast != null: _step_ball(delta)

func ball() -> bool:
	return String(knobs.get("shot","ball")) == "ball"

## The tell's length: the ball's (`ball_tell`) or the gust's (`delay`).
func tell_time() -> float:
	return knob("ball_tell") if ball() else knob("delay")

func _brain(delta: float) -> void:
	if is_disabled():
		if state == "tell": knocked_out_tells += 1
		if state != "watch": reset_blow()
		return
	var at := chest()
	if state == "tell" and ball():
		# Committed: the breath always ends in the ball, at him if it can
		# see him (led), else where it last saw him; once the tell has run
		# and the barrel is near enough to send it (off_barrel), or turn_max
		# past the tell anyway (sent as near his way as the barrel allows).
		var seen := can_reach(at)
		if seen:
			_last_seen = at
			_since_seen = 0.0
			if blast != null:
				var bv: Vector3 = (blast as Variant).aim_vel
				_last_vel = Vector3(bv.x,0.0,bv.z)
		else: _since_seen += delta
		aim_at(at if seen else _last_seen,delta)
		state_t += delta
		tell(minf(state_t/maxf(tell_time(),0.01),1.0))
		if state_t >= tell_time():
			var to := _ball_target(seen)
			var from := _mouth.global_position
			if facing().angle_to(to-from) <= knob("off_barrel") or state_t > tell_time()+knob("turn_max"):
				_fire_ball(from,to)
				_go("rest")
		return
	match state:
		"watch":
			_sweep_step(delta)
			var heard := noise()
			if heard != "" and can_reach(at) and (not may_draw.is_valid() or bool(may_draw.call())):
				why = heard
				_go("tell")
				tells += 1
				_last_seen = at
				_last_vel = Vector3.ZERO
				_since_seen = 0.0
				if _breath.is_inside_tree():
					_breath.global_position = _mouth.global_position
					_breath.play()
				woke.emit(heard)
		"tell":
			# The breath drawn while it turns on him; it blows once the tell
			# has run and it is on him, or turn_max past it anyway.
			aim_at(at,delta)
			state_t += delta
			tell(minf(state_t/maxf(knob("delay"),0.01),1.0))
			if state_t >= knob("delay") and (on_him(at) or state_t > knob("delay")+knob("turn_max")):
				fired()
				_gust_look()
				blows += 1
				shots += 1
				_hit = false
				_go("blow")
		"blow":
			# The blow: the first frame he is in its beam, the knock, once.
			aim_at(at,delta)
			state_t += delta
			if not _hit and Gust.can_take(motor) and aim_error(at) < knob("cone") and can_reach(at):
				_hit = true
				hits += 1
				last_knock = Gust.knock(motor,facing(),knob("blast_out"),knob("blast_up"),get_parent())
			if state_t >= knob("blast_time"):
				blew.emit(_hit)
				_go("rest")
		"rest":
			state_t += delta
			if state_t >= knob("rearm"):
				reset_blow()

## His aim point for the ball (world): over his middle by the gust arrows'
## AIM_UP (its fuse reaches down to him).
func ball_aim() -> Vector3:
	var m: Variant = motor
	return m.feet+Vector3.UP*(0.55+GustArrows.AIM_UP)*AirBlast.walker_tall()

## Where the ball goes: seen, where he will be (his flat pace led `lead`
## of the way, AirBlast.lead: no homing, so a juke beats it); unseen, where
## he was heading when it lost him (last seen, carried on at his last pace
## for the time since, then led the same way).
func _ball_target(seen: bool) -> Vector3:
	var from := _mouth.global_position
	var b: Variant = blast
	if not seen:
		var on := _last_seen+Vector3.UP*(ball_aim()-chest()).y+_last_vel*_since_seen
		return AirBlast.lead(from,on,_last_vel,float(b.speed),knob("lead"))
	var v: Vector3 = b.aim_vel
	return AirBlast.lead(from,ball_aim(),Vector3(v.x,0.0,v.z),float(b.speed),knob("lead"))

## The ball leaves the mouth for `to`: along the line to it, or, when the
## barrel can't point there (its turn, its pitch), off_barrel off the
## barrel toward it.
func _fire_ball(from: Vector3, to: Vector3) -> void:
	var way := (to-from).normalized()
	var face := facing()
	var off := face.angle_to(way)
	if off > knob("off_barrel"):
		var axis := face.cross(way)
		way = face.rotated(axis.normalized(),knob("off_barrel")) if axis.length() > 0.0001 else face
	var b: Variant = blast
	b.fire(from,from+way*maxf(from.distance_to(to),1.0))
	b.phase = "idle"
	b.windup_t = 0.0
	fired()
	blows += 1
	shots += 1
	if _whoosh.is_inside_tree():
		_whoosh.global_position = from
		_whoosh.play()

## The ball's frame: its gather in the mouth through the tell (the blast's
## own wind-up, held: the horn fires it), the flight, the burst and its
## knock on him, the horn the source; while knocked out no new gather, but
## a ball in flight flies on.
func _step_ball(delta: float) -> void:
	var b: Variant = blast
	b.windup = tell_time()
	b.cooldown = 0.0
	b.hold = true
	b.on = not is_disabled()
	var space := _mouth.get_world_3d().direct_space_state
	b.advance(delta,space,state == "tell" and not is_disabled(),_mouth.global_position,ball_aim())
	var m: Variant = motor
	var v: Vector3 = b.pilot_knock(m.feet,m)
	if v == Vector3.ZERO or not Gust.can_take(m): return
	m.knock(v,get_parent())
	hits += 1
	last_knock = v
	blew.emit(true)

## Slammed on its pedestal's top or its cap (scripts/slam.gd): down
## GustArrows.DISABLE_TIME s, as a crossing perch's horn.
func slam(at: Vector3, _radius: float, _strength: float) -> void:
	var piece := get_parent() as Node3D
	var q := piece.to_local(at)
	var up := GustArrows.SLAM_UP*Gust.WorldScale.wanderer
	var tops := [float(piece.get_meta("ped_height",0.0)),float(piece.get_meta("top",0.0))]
	var on_top := false
	for h: float in tops:
		if absf(q.y-h) <= up: on_top = true
	if not on_top or Vector2(q.x,q.z).length() > load("res://scripts/ruin_kit_horn.gd").PED_R+GustArrows.SLAM_EDGE: return
	disabled(GustArrows.DISABLE_TIME)

## Settled on `point`: the barrel within cone x 0.6 of it and the head's
## turn within `settle` of its bearing (so the gust goes along the line
## to him, not along a swing still closing on him).
func on_him(point: Vector3) -> bool:
	var want := bearing(point)
	if yaw_arc < PI: want = clampf(want,-yaw_arc,yaw_arc)
	return aim_error(point) < knob("cone")*0.6 and absf(angle_difference(yaw,want)) < knob("settle")

func _go(s: String) -> void:
	state = s
	state_t = 0.0

## The idle sweep across its arc, looking level.
func _sweep_step(delta: float) -> void:
	var arc := yaw_arc if yaw_arc < PI else PI
	var span := arc*knob("sweep_share")
	_sweep += _sweep_dir*knob("sweep")*delta
	if absf(_sweep) > span:
		_sweep = clampf(_sweep,-span,span)
		_sweep_dir = -_sweep_dir
	var piece := get_parent() as Node3D
	var far := knob("reach")*0.6
	aim_at(piece.to_global(_base+Vector3(sin(_sweep)*far,_pivot.y,cos(_sweep)*far)),delta)

## The gust leaving: fast puffs out along the barrel, and its rush.
func _gust_look() -> void:
	var way := facing()
	for i in range(GUST_PUFFS):
		var d := (way+Vector3(_rng.randf_range(-0.15,0.15),_rng.randf_range(-0.1,0.15),_rng.randf_range(-0.15,0.15))).normalized()
		_puff(_mouth.global_position+way*0.3,d*_rng.randf_range(GUST_SPEED.x,GUST_SPEED.y),_mouth_r*0.5,_mouth_r*1.8,_rng.randf_range(0.6,1.0),0.4)
	if _whoosh.is_inside_tree():
		_whoosh.global_position = _mouth.global_position
		_whoosh.play()

func _collect(n: Node, into: Array[RID]) -> void:
	if n is CollisionObject3D: into.append((n as CollisionObject3D).get_rid())
	for c in n.get_children(): _collect(c,into)

func _process(delta: float) -> void:
	if _head == null: return
	_clock += delta
	var was := _left
	_left = maxf(0.0,_left-delta)
	if was > 0.0 and _left <= 0.0:
		# Back on its feet: a last puff of dust off the turntable.
		for i in range(4):
			_puff(_head.global_position+Vector3(_rng.randf_range(-1.0,1.0),0.2,_rng.randf_range(-1.0,1.0)),Vector3(0.0,0.8,0.0),0.15,0.6,0.8,0.35)
	_telling = maxf(0.0,_telling-delta)
	if _telling <= 0.0: _share = -1.0
	# The kick: a spring back to rest.
	_recoil_v += (-KICK_STIFF*_recoil-KICK_DAMP*_recoil_v)*delta
	_recoil += _recoil_v*delta
	_empty_v += (-EMPTY_STIFF*_empty-EMPTY_DAMP*_empty_v)*delta
	_empty += _empty_v*delta
	if auto and motor != null: step(delta)
	_apply()
	_step_motes(delta)
	_step_puffs(delta)

## The slump (0..1): in quickly, held, then eased out over the last share.
func _slump() -> float:
	if _left <= 0.0: return 0.0
	var e := 1.0-_left/_total
	return smoothstep(0.0,0.12,e)*(1.0-smoothstep(1.0-RISE_SHARE,1.0,e))

func _apply() -> void:
	var s := _slump()
	var shake := SHUDDER*maxf(_share,0.0)*maxf(_share,0.0)
	# While it grinds back up the rise judders.
	if _left > 0.0 and _left < _total*RISE_SHARE: shake += 0.012*s
	var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,DROOP_PITCH*s)*Basis(Vector3.BACK,DROOP_ROLL*s)
	_head.basis = basis
	var judder := Vector3(sin(_clock*61.0),sin(_clock*47.0+1.0),0.0)*shake
	_head.position = _base+Vector3(0.0,-DROOP_DROP*s,0.0)+basis*judder
	# The barrel: its aim, eased level in the slump, and the kick back along
	# its own axis.
	var tilt := Basis(Vector3.RIGHT,pitch*(1.0-s)-_recoil*KICK_PITCH)
	_barrel.basis = tilt
	_barrel.position = _pivot-tilt.z*_recoil
	# The bellows: swelling through the tell (eased in), emptied at the blow.
	if _chest_mesh != null:
		var swell := SWELL*smoothstep(0.0,1.0,maxf(_share,0.0))-EMPTY*_empty
		_chest_mesh.scale = Vector3(1.0+swell,1.0+swell*SWELL_UP,1.0+swell)

func _step_motes(delta: float) -> void:
	for m: Dictionary in _motes:
		var node := m.node as MeshInstance3D
		if _share < 0.0:
			node.visible = false
			continue
		# Each mote runs in twice over the wind-up, from round the mouth in
		# front of it to the mouth, faster as it nears.
		var t := fposmod(_share*2.0+float(m.phase),1.0)
		var pull := pow(t,2.2)
		node.position = _mouth.position+(m.from as Vector3)*(1.0-pull)
		node.rotation += Vector3(float(m.spin),float(m.spin)*0.6,0.0)*delta
		node.scale = Vector3.ONE*(1.0-0.5*pull)
		node.transparency = 1.0-0.7*smoothstep(0.0,0.15,t)*(1.0-smoothstep(0.85,1.0,t))
		node.visible = true

func _far() -> Vector3:
	var d := Vector3(_rng.randf_range(-1.0,1.0),_rng.randf_range(-0.7,1.0),_rng.randf_range(0.0,1.0)).normalized()
	return d*_rng.randf_range(DRAW_FROM.x,DRAW_FROM.y)*0.8

func _puff(at: Vector3, vel: Vector3, s0: float, s1: float, life: float, alpha: float) -> void:
	var pick: Dictionary = _puffs[0]
	for p: Dictionary in _puffs:
		if float(p.age) >= float(p.life):
			pick = p
			break
		if float(p.age)/float(p.life) > float(pick.age)/float(pick.life): pick = p
	pick.pos = at
	pick.vel = vel
	pick.age = 0.0
	pick.life = life
	pick.s0 = s0
	pick.s1 = s1
	pick.a = alpha

func _step_puffs(delta: float) -> void:
	for p: Dictionary in _puffs:
		var node := p.node as MeshInstance3D
		if float(p.age) >= float(p.life):
			node.visible = false
			continue
		p.age = float(p.age)+delta
		var u := clampf(float(p.age)/float(p.life),0.0,1.0)
		p.vel = (p.vel as Vector3)*(1.0-2.0*delta)
		p.pos = (p.pos as Vector3)+(p.vel as Vector3)*delta
		node.global_position = p.pos
		node.scale = Vector3.ONE*lerpf(float(p.s0),float(p.s1),sqrt(u))
		node.transparency = 1.0-float(p.a)*(1.0-u)
		node.visible = true

func _blob(mesh: Mesh, tint: Color, parent: Node, free := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	if free: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	node.visible = false
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = free
	parent.add_child(node)
	return node

## Air through stone, `seconds` long: `rising`, the long inhale (soft,
## swelling and brightening to a catch at the end); else the gust's rush
## (a hard onset, a low roar dying away).
func _hiss(seconds: float, rising: bool) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate*seconds)
	var data := PackedByteArray()
	data.resize(n*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9 if rising else 13
	var low := 0.0
	for i in range(n):
		var u := float(i)/n
		var bright := lerpf(0.04,0.3,u) if rising else lerpf(0.5,0.08,u)
		low += (rng.randf_range(-1.0,1.0)-low)*bright
		var env := pow(u,1.6)*(1.0-smoothstep(0.92,1.0,u)) if rising else (1.0-exp(-u*60.0))*exp(-u*4.0)
		var v := low*env*(1.6 if rising else 2.4)
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

## A dull crack and a grind: a burst of noise over a low thump.
func _crack() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate*0.7)
	var data := PackedByteArray()
	data.resize(n*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var low := 0.0
	for i in range(n):
		var t := float(i)/rate
		low += (rng.randf_range(-1.0,1.0)-low)*0.12
		var v := low*2.2*exp(-t*5.0)+sin(TAU*58.0*t)*0.6*exp(-t*9.0)+rng.randf_range(-1.0,1.0)*0.4*exp(-t*40.0)
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
