extends "res://scripts/enemies/enemy.gd"
## The Plinth Ram (docs/design/roguelike/ideas-enemies.md, 7), greybox: a
## stone bull. You are the red flag: it chases you, and a dodge made at the
## last moment near a rim sends it over. That is the only way it dies.
##
## One bull, in states (`state`):
##   "idle"    wanders the turf at `wander_speed`, turning back from every
##             edge, resting `rest` s between goes.
##   "notice"  he is within `notice` m, inside its `sight` (half-angle) and
##             on ground it can run to (no gap between): it stops, its head
##             comes up, it huffs, and turns to face him at `turn` rad/s;
##             after `notice_beat` s, on his line (`line_angle`), it tells.
##   "tell"    `tell` s (a second go: `retell`): `scrapes` scrapes of a
##             front hoof (dust, a paw sound each), the head going down and
##             the body heating to `tell_colour`; still aiming till the last
##             `lock` s.
##   "charge"  winds up from a stand to `charge_speed` over `wind_up` s and
##             HOMES, a bull hooking after the cape: it turns toward where
##             he will be (his pace led on by the time to reach him, at most
##             `lead` s) at `chase_turn` rad/s from a stand, down to
##             `chase_top` at its top speed, so a dodge made early is
##             followed and run down. Its body banks and its head looks into
##             the turn (`lean`).
##   "commit"  `commit` s from reaching him (his own pace counted, so a
##             pilot running away is reached later) the head snaps down onto
##             his lead (at most `lock_on`), it snorts, dust kicks up, it
##             goes deep red: the cue. It still hooks after him, at `hook` of
##             its chase turn (a lazy dodge is caught), till its last `blind`
##             s, head down, its line set. So a late dodge works: a jump over
##             its horns, a run or a power slide out of its line, a drop into
##             a rim hang.
##   "skid"    it lost him (he is more than `lose_angle` off its heading:
##             passed, or over it) and skids on along its line, braking,
##             its front swinging round to him (`skid_turn`), dust spraying.
##             Its stopping distance from full speed is `kill_band` m; if a
##             rim lies inside the distance it needs at the pace it lost him
##             at, it cannot stop: it slides to the lip and teeters.
##             Otherwise it stops ("dig"), comes round and tells again.
##   "teeter"  front feet over the lip, scrabbling for `teeter` s, then it
##             tips over and falls (gone below the study's `lost`).
##   "dig"     dug in for `dig` s, coming round to face him; then winded
##             (stunned `stun_hit` s) if it hit him, else, he still in
##             sight, back to "notice" (no beat) and a short tell
##             (`retell`) and again; else idle. Noticing him nearer than
##             `room` m past its nose, it first backs off, facing him, to
##             give itself a run (not over a lip).
##   "stun"    (the base's) a stone to stand on, sliding to rest.
## Edge rules: idle, it turns back from every edge; a skid it did not lose
## him in (it hit him, or gave up: he went past `give_up` m, it ran
## `charge_dist`, or he dropped out of reach before it committed) stops dead
## at a lip (`lip_brake`); committed, it never looks at the ground: a lip at
## its nose is a teeter. So a miss in the open costs it nothing, and an
## early drop into a hang is waited out at the lip above him.
## Hit rules: only the horns hurt: the front `horns` share of its length,
## while charging or committed, and only a pilot whose feet are under `hop`
## of its height there (a jump clears it). A pilot hanging from a rim is
## never touched: it passes over his hands. Hit, he is shoved `shove_out` m
## (PilotMotor.knock), never damaged. Its body is always a stone: he can't
## walk through it, he stands on it still, and moving or turning into him it
## shoves him out (the base's `push_out`). Charging, skidding or teetering it
## `bucks()`: a jump that comes down on its back is thrown off behind it
## (the base's `buck`), not carried over a rim. A pilot sliding into it at
## `push_speed` knocks it away (the base's push).
## Into a wall it is stunned `stun_wall` s; landing from a fall, `stun_miss`.
## Sizes and speeds all come from the pilot's numbers (enemy_field.gd
## `numbers()`): its back a bit under his plain jump.

const COMMIT_COLOUR := Color(0.88,0.12,0.06)
const NOTICE_COLOUR := Color(0.74,0.6,0.46)

func _init() -> void:
	cost = 3
	tags = PackedStringArray(["knockable","pushes","loud"])
	tell_sound = &"ram_paw"

func default_knobs(n: Dictionary) -> Dictionary:
	return {
		"wander_speed":n.walk*0.5,"rest":0.8,"edge_look":n.unit*0.8,
		"notice":n.run*2.4,"sight":1.2,"line_angle":0.14,"turn":2.6,"notice_beat":0.35,
		"tell":0.75,"retell":0.4,"lock":0.2,"scrapes":3,
		"charge_speed":n.run*1.9,"wind_up":0.3,"chase_turn":3.4,"chase_top":2.4,"hook":0.5,"blind":0.45,"lean":0.04,"commit":0.7,"lock_on":0.6,"lead":1.2,"lose_angle":1.3,
		"give_up":n.run*3.6,"charge_dist":n.unit*13.0,
		"kill_band":n.unit*1.7,"lip":n.unit*0.15,"lip_brake":n.run*5.0,"teeter":0.45,
		"skid_turn":4.5,"dig":0.3,"room":n.unit*1.5,
		"horns":0.35,"hop":0.25,
		"shove_out":n.run*1.9,"shove_up":n.unit*0.45,
		"stun_miss":1.2,"stun_hit":0.6,"stun_wall":2.5,
	}

## Its back a bit under his plain jump; longer than it is wide.
func _size(n: Dictionary) -> void:
	height = n.jump*0.9
	width = height
	length = height*2.2

# --- The greybox body --------------------------------------------------------------

var _head: Node3D
## Front left, front right, back left, back right.
var _legs: Array[Node3D] = []
## Dust: a trail off its feet at a run, the spray of a skid, one-shot kicks.
var _trail: CPUParticles3D
var _spray: CPUParticles3D
var _kick: CPUParticles3D
var _gait := 0.0

func _art(root: Node3D) -> void:
	var leg_h := height*0.32
	# The torso, heavier at the shoulders.
	_part(Vector3(width,height*0.62,length*0.78),Vector3(0.0,leg_h+height*0.31,length*0.08),true)
	_part(Vector3(width*1.08,height*0.22,length*0.3),Vector3(0.0,height*0.92,-length*0.18),true)
	# The head on a pivot at the shoulders' front: it lifts, drops and locks.
	_head = Node3D.new()
	_head.position = Vector3(0.0,height*0.72,-length*0.31)
	root.add_child(_head)
	_part(Vector3(width*0.7,height*0.5,length*0.26),Vector3(0.0,-height*0.05,-length*0.13),true,Color.WHITE,_head)
	# The horns: curled lintel corners, out and forward.
	for side: float in [-1.0,1.0]:
		_part(Vector3(width*0.22,height*0.14,length*0.2),Vector3(side*width*0.42,height*0.17,-length*0.2),false,Color(0.86,0.83,0.74),_head)
	# The facing mark: a bright muzzle.
	_part(Vector3(width*0.42,height*0.2,length*0.06),Vector3(0.0,-height*0.18,-length*0.27),false,mark_colour,_head)
	# Legs hung from the hips and shoulders.
	for at: Vector2 in [Vector2(-1.0,-1.0),Vector2(1.0,-1.0),Vector2(-1.0,1.0),Vector2(1.0,1.0)]:
		var hip := Node3D.new()
		hip.position = Vector3(at.x*width*0.3,leg_h,at.y*length*0.3)
		root.add_child(hip)
		_part(Vector3(width*0.2,leg_h,width*0.2),Vector3(0.0,-leg_h*0.5,0.0),false,Color(0.5,0.47,0.42),hip)
		_legs.append(hip)
	_trail = _puffs(16,0.45,0.1,Vector2(0.3,0.9))
	_spray = _puffs(40,0.7,0.16,Vector2(1.2,3.2))
	_kick = _puffs(18,0.55,0.13,Vector2(0.8,2.2))
	_kick.one_shot = true
	_kick.explosiveness = 0.9
	for p: CPUParticles3D in [_trail,_spray,_kick]: root.add_child(p)

## Soft grey puffs off its feet.
func _puffs(amount: int, life: float, size: float, speed: Vector2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.top_level = true
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	var ball := SphereMesh.new()
	ball.radius = size
	ball.height = size*2.0
	ball.radial_segments = 6
	ball.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.74,0.7,0.62,0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material = mat
	p.mesh = ball
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(width*0.5,0.05,length*0.3)
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0.0,-2.0,0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	return p

## A one-shot kick of dust at `at` (its feet if not given).
func _dust_kick(at := Vector3.INF) -> void:
	_kick.global_position = (global_position if at == Vector3.INF else at)+Vector3.UP*0.05
	_kick.restart()

# --- State -----------------------------------------------------------------------

var _dir := Vector2.ZERO
var _travelled := 0.0
var _walking := false
var _wander_t := 0.0
var _turn_to := 0.0
var _rng := RandomNumberGenerator.new()
var _tell_len := 0.0
var _scraped := 0
## This charge hit him (then it is winded after its skid).
var _hit := false
## This skid stops at a lip (it hit him, or gave up on him).
var _safe := false
## This skid can't stop short of a rim: it will teeter and fall.
var _doomed := false
var _tipped := false
## This go is a second one (a short tell).
var _again := false
## Its turn this frame (rad/s, + to its left), for the lean.
var _yaw_rate := 0.0

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	_turn_to = facing
	_rng.seed = hash(at)
	# Ready from the start: no rest owed.
	state_t = float(knobs.rest)

## Decel of a skid: from `charge_speed` it stops in `kill_band` m.
func brake() -> float:
	var top := float(knobs.charge_speed)
	return top*top/(2.0*maxf(float(knobs.kill_band),0.1))

## On the death card: the ram.
func harm_cause() -> String:
	return "ram"

func harmful() -> bool:
	return grounded and (state == "charge" or state == "commit")

func think(delta: float) -> void:
	state_t += delta
	match state:
		"idle": _idle(delta)
		"notice": _notice(delta)
		"tell": _tell(delta)
		"charge": _charge(delta)
		"commit": _commit(delta)
		"skid": _skid(delta)
		"teeter": _teeter(delta)
		"dig": _dig(delta)
	_pose(delta)
	var pace := Vector2(vel.x,vel.z).length()
	_trail.global_position = global_position+Vector3.UP*0.05
	_trail.emitting = grounded and (state == "charge" or state == "commit") and pace > float(knobs.charge_speed)*0.4
	_spray.global_position = global_position+Vector3.UP*0.05
	_spray.emitting = grounded and state == "skid" and pace > 1.0

## Charging, skidding or teetering it carries no one: a pilot come down on
## its back is bucked off behind it (the base's `buck`), not ridden over a rim.
func bucks() -> bool:
	return not grounded or state in ["charge","commit","skid","teeter"]

## Its turn toward him at `pace` (rad/s): `chase_turn` from a stand down to
## `chase_top` at its top speed; after the lock, `hook` of that.
func _chase_rate(pace: float, locked: bool) -> float:
	var k := clampf(pace/float(knobs.charge_speed),0.0,1.0)
	var rate := lerpf(float(knobs.chase_turn),float(knobs.chase_top),k)
	return rate*(float(knobs.hook) if locked else 1.0)

# --- Him -------------------------------------------------------------------------

## Where the pilot is from its middle: [flat way (x, z), distance, height over its feet].
func _pilot() -> Array:
	var f: Vector3 = field.motor.feet
	var flat := Vector2(f.x-position.x,f.z-position.z)
	return [flat,flat.length(),f.y-position.y]

## Seconds till its horns reach him at `pace`, his own pace along the line counted.
func _reach_time(pace: float) -> float:
	var p := _pilot()
	var flat: Vector2 = p[0]
	var dist: float = p[1]
	var gap := dist-length*0.5-float(knobs.radius)
	if gap <= 0.0: return 0.0
	var his := Vector2(field.motor.velocity.x,field.motor.velocity.z)
	var closing := pace-his.dot(flat/maxf(dist,0.01))
	return gap/maxf(closing,0.5)

## Where he will be (from its middle, x, z) when its horns get there at
## `pace` (at least half its top): his pace led on (off at more than a
## stroll and not sliding, reckoned at his run at least), at most `lead` s.
func _lead(pace: float, ttc: float) -> Vector2:
	var flat: Vector2 = _pilot()[0]
	var his := Vector2(field.motor.velocity.x,field.motor.velocity.z)
	# Off at a pace, he is reckoned to run on at his run at least.
	if his.length() > float(knobs.wander_speed) and field.motor.move != "slide": his = his.normalized()*maxf(his.length(),field.motor.run)
	var most := float(knobs.lead)
	var t := minf(ttc,most)
	var aim := flat
	for i in range(3):
		aim = flat+his*t
		t = clampf((aim.length()-length*0.5-float(knobs.radius))/maxf(pace,float(knobs.charge_speed)*0.5),0.0,most)
	return aim if aim.length() > 0.01 else flat

## He is near enough, at a height, in front, and on ground it can run to.
func _sees(cone: float) -> bool:
	var p := _pilot()
	var flat: Vector2 = p[0]
	var dist: float = p[1]
	var up: float = p[2]
	if dist > float(knobs.notice) or up <= -1.0 or up >= 2.0: return false
	if field.motor.on_ledge(): return false
	if absf(angle_difference(facing,PilotMotor.facing_of(flat))) > cone: return false
	return _reachable(flat,dist)

## No gap in the ground between it and him (it won't charge across one).
func _reachable(flat: Vector2, dist: float) -> bool:
	var way := flat/maxf(dist,0.01)
	var d := length*0.5
	while d < dist-0.3:
		if field.floor_under(position+Vector3(way.x,0.0,way.y)*d,2.5,1.0,body.get_rid()) == -INF: return false
		d += 0.8
	return true

# --- Idle and notice -------------------------------------------------------------

func _idle(delta: float) -> void:
	if state_t >= float(knobs.rest) and _sees(float(knobs.sight)):
		_go("notice")
		_again = false
		field.sound(&"ram_huff",global_position)
		tint(NOTICE_COLOUR)
		return
	_wander(delta)

func _notice(delta: float) -> void:
	if not _sees(PI):
		slow(delta,float(knobs.skid_decel))
		_go("idle")
		state_t = float(knobs.rest)
		rest()
		return
	var off := _aim_at_him(delta,float(knobs.turn))
	# Too close for a run at him: it backs off, facing him (not over a lip).
	var back := -PilotMotor.forward(facing)
	if float(_pilot()[1]) < length*0.5+float(knobs.room) and not edge_ahead(back,length*0.5+float(knobs.edge_look)):
		var v := back*float(knobs.wander_speed)*2.0
		vel.x = v.x
		vel.z = v.y
		return
	slow(delta,float(knobs.skid_decel))
	if float(_pilot()[1]) < length*0.5+float(knobs.radius)+0.4: return
	if state_t >= float(knobs.notice_beat) and off <= float(knobs.line_angle): _start_tell(float(knobs.retell if _again else knobs.tell))

func _go(to: String) -> void:
	state = to
	state_t = 0.0

## Turns toward him at `rate` rad/s; how far off he still is.
func _aim_at_him(delta: float, rate: float) -> float:
	var flat: Vector2 = _pilot()[0]
	if flat.length() < 0.01: return 0.0
	return _turn_toward(PilotMotor.facing_of(flat),rate*delta)

func _turn_toward(want: float, most: float) -> float:
	var off := angle_difference(facing,want)
	facing = wrapf(facing+clampf(off,-most,most),-PI,PI)
	rotation.y = facing
	return absf(angle_difference(facing,want))

func _wander(delta: float) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_walking = not _walking
		_wander_t = _rng.randf_range(1.0,2.5)
		if _walking: _turn_to = facing+_rng.randf_range(-1.2,1.2)
	if not _walking:
		slow(delta,float(knobs.skid_decel))
		return
	var look := length*0.5+float(knobs.edge_look)
	if edge_ahead(PilotMotor.forward(facing),look) and absf(angle_difference(facing,_turn_to)) < 0.3:
		_turn_to = facing+PI*_rng.randf_range(0.6,1.0)*(1.0 if _rng.randf() < 0.5 else -1.0)
	_turn_toward(_turn_to,float(knobs.turn)*delta)
	if absf(angle_difference(facing,_turn_to)) < 0.3 and not edge_ahead(PilotMotor.forward(facing),look):
		var v := PilotMotor.forward(facing)*float(knobs.wander_speed)
		vel.x = v.x
		vel.z = v.y
	else: slow(delta,float(knobs.skid_decel))

# --- The tell --------------------------------------------------------------------

func _start_tell(seconds: float) -> void:
	_go("tell")
	_tell_len = seconds
	_scraped = 1
	_hit = false
	_safe = false
	_doomed = false
	tell()
	_dust_kick(_hoof())

## Where the scraping hoof is.
func _hoof() -> Vector3:
	return to_global(Vector3(width*0.3,0.0,-length*0.3))

func _tell(delta: float) -> void:
	slow(delta,float(knobs.skid_decel))
	var t := _tell_len
	var k := clampf(state_t/t,0.0,1.0)
	tint(NOTICE_COLOUR.lerp(tell_colour,k))
	var scrapes := maxi(int(knobs.scrapes),1)
	if _scraped < scrapes and state_t >= t*float(_scraped)/float(scrapes):
		_scraped += 1
		field.sound(&"ram_paw",global_position)
		_dust_kick(_hoof())
	if state_t < t-minf(float(knobs.lock),t*0.5): _aim_at_him(delta,float(knobs.turn)*1.5)
	if state_t >= t:
		_dir = PilotMotor.forward(facing)
		_travelled = 0.0
		_go("charge")
		field.sound(&"ram_charge",global_position)

# --- The charge ------------------------------------------------------------------

## Up to its top over `wind_up`, along `_dir`.
func _run_on(delta: float) -> float:
	var top := float(knobs.charge_speed)
	var pace := move_toward(Vector2(vel.x,vel.z).length(),top,top/maxf(float(knobs.wind_up),0.01)*delta)
	vel.x = _dir.x*pace
	vel.z = _dir.y*pace
	_travelled += pace*delta
	return pace

## He is more than `lose_angle` off its heading (passed), or over its
## horns (his feet over `hop` of its height, his middle behind its nose).
func _lost_him() -> bool:
	var p := _pilot()
	var flat: Vector2 = p[0]
	var up: float = p[2]
	if up >= height*float(knobs.hop) and flat.dot(PilotMotor.forward(facing)) < length*0.5: return true
	if flat.length() < 0.4: return false
	return absf(angle_difference(facing,PilotMotor.facing_of(flat))) > float(knobs.lose_angle)

func _charge(delta: float) -> void:
	if not grounded: return
	var pace := Vector2(vel.x,vel.z).length()
	var p := _pilot()
	var dist: float = p[1]
	var up: float = p[2]
	# Out of range, run far enough, or dropped out of reach early: it gives up
	# and stops at a lip.
	if dist > float(knobs.give_up) or _travelled >= float(knobs.charge_dist) or field.motor.on_ledge() or up < -1.0:
		_start_skid(true)
		return
	if _lost_him():
		_start_skid(false)
		return
	var ttc := _reach_time(pace)
	if ttc <= float(knobs.commit):
		# The head locks on where he will be (a snap of at most `lock_on`).
		_turn_toward(PilotMotor.facing_of(_lead(pace,ttc)),float(knobs.lock_on))
		_dir = PilotMotor.forward(facing)
		# The snap is the head's, not a turn to bank into.
		_last_facing = facing
		_start_commit()
		_commit(delta)
		return
	# Homing on where he will be, turning less the faster it goes.
	_turn_toward(PilotMotor.facing_of(_lead(pace,ttc)),_chase_rate(pace,false)*delta)
	_dir = PilotMotor.forward(facing)
	# Short of the commit it still sees the ground: a lip ahead is a safe stop.
	if edge_ahead(_dir,length*0.5+float(knobs.lip)+pace*delta*2.0):
		_start_skid(true)
		return
	_run_on(delta)

func _start_commit() -> void:
	_go("commit")
	field.sound(&"ram_snort",global_position)
	tint(COMMIT_COLOUR)
	_dust_kick()

## Locked on: still hooking after him (on where he will be), but at only
## `hook` of its chase turn, so a dodge from here outruns the turn.
func _commit(delta: float) -> void:
	if not grounded: return
	var pace := Vector2(vel.x,vel.z).length()
	if _lost_him():
		_start_skid(false)
		return
	if _travelled >= float(knobs.charge_dist):
		_start_skid(true)
		return
	# Head down for the last `blind` s: it runs on blind, its line set.
	var ttc := _reach_time(pace)
	if ttc > float(knobs.blind):
		_turn_toward(PilotMotor.facing_of(_lead(pace,ttc)),_chase_rate(pace,true)*delta)
	_dir = PilotMotor.forward(facing)
	if edge_ahead(_dir,length*0.5+float(knobs.lip)+pace*delta):
		_start_teeter()
		return
	_run_on(delta)

# --- The skid, the teeter, the dig -----------------------------------------------

func _start_skid(safe: bool) -> void:
	_go("skid")
	_safe = safe or _hit
	var pace := Vector2(vel.x,vel.z).length()
	_doomed = not _safe and _edge_within(pace*pace/(2.0*brake()))
	field.sound(&"ram_scrape",global_position)
	_dust_kick()
	if _hit: rest()
	else: tint(tell_colour)

## Sliding on along its line, braking, the front swinging round toward him.
func _skid(delta: float) -> void:
	if not grounded: return
	var pace := Vector2(vel.x,vel.z).length()
	_aim_at_him(delta,float(knobs.skid_turn))
	var decel := brake()
	if _doomed:
		if _edge_within(0.0):
			_start_teeter()
			return
	elif _edge_within(0.0):
		vel.x = 0.0
		vel.z = 0.0
	elif _edge_within(pace*pace/(2.0*decel)): decel = float(knobs.lip_brake)
	if slow(delta,decel):
		vel.x = 0.0
		vel.z = 0.0
		_go("dig")
		_dust_kick()

## An edge ahead along its way within `dist` m past its front and the lip.
func _edge_within(dist: float) -> bool:
	var way := Vector2(vel.x,vel.z)
	way = way.normalized() if way.length() > 0.1 else _dir
	return edge_ahead(way,length*0.5+float(knobs.lip)+dist)

func _start_teeter() -> void:
	var way := Vector2(vel.x,vel.z)
	if way.length() > 0.1: _dir = way.normalized()
	vel.x = 0.0
	vel.z = 0.0
	_tipped = false
	_go("teeter")
	field.sound(&"ram_scrabble",global_position)
	_dust_kick(to_global(Vector3(0.0,0.0,-length*0.5)))
	tint(tell_colour)

## Front feet over the lip, scrabbling; then over it goes.
func _teeter(delta: float) -> void:
	if not grounded: return
	if state_t < float(knobs.teeter):
		if fmod(state_t,0.15) < delta: _dust_kick(to_global(Vector3(0.0,0.0,-length*0.5)))
		return
	if not _tipped:
		_tipped = true
		field.sound(&"ram_bellow",global_position)
	vel.x = _dir.x*float(knobs.wander_speed)*2.5
	vel.z = _dir.y*float(knobs.wander_speed)*2.5

func _dig(delta: float) -> void:
	slow(delta,float(knobs.skid_decel))
	var off := _aim_at_him(delta,float(knobs.skid_turn))
	if state_t < float(knobs.dig) or (off > float(knobs.line_angle)*2.0 and state_t < 1.5): return
	if _hit: stun(float(knobs.stun_hit))
	elif _sees(PI):
		# Again: straight to its line (backing off for room first).
		_go("notice")
		_again = true
		state_t = float(knobs.notice_beat)
	else:
		_go("idle")
		rest()

# --- Its pose --------------------------------------------------------------------

var _last_facing := INF

func _pose(delta: float) -> void:
	var pace := Vector2(vel.x,vel.z).length()
	if _last_facing == INF: _last_facing = facing
	_yaw_rate = lerpf(_yaw_rate,angle_difference(_last_facing,facing)/maxf(delta,0.001),1.0-exp(-14.0*delta))
	_last_facing = facing
	# Into the turn: the body banks (its top toward the inside) and the head
	# looks round, the more the faster it goes.
	var bank := 0.0
	var look := 0.0
	if state == "charge" or state == "commit":
		bank = clampf(_yaw_rate*pace*float(knobs.lean),-0.35,0.35)
		look = clampf(_yaw_rate*0.35,-0.5,0.5)
	var head := 0.0
	var lean := 0.0
	var head_rate := 10.0
	var swing := clampf(pace/float(knobs.charge_speed),0.0,1.0)*0.9+(0.35 if pace > 0.2 and state == "idle" else 0.0)
	_gait += delta*(4.0+pace*2.2)
	var legs := [sin(_gait),sin(_gait+PI),sin(_gait+PI),sin(_gait)]
	match state:
		"idle": head = 0.05*sin(state_t*1.3)
		"notice":
			head = 0.32
			lean = 0.04
		"tell":
			var k := clampf(state_t/maxf(_tell_len,0.01),0.0,1.0)
			head = lerpf(0.15,-0.5,k)
			lean = -0.06*k
			# The scrape: the front right hoof drawn back, again and again.
			var scrapes := float(maxi(int(knobs.scrapes),1))
			legs = [0.0,-0.9*maxf(0.0,sin(PI*scrapes*state_t/maxf(_tell_len,0.01))),0.0,0.0]
			swing = 1.0
		"charge":
			head = -0.32
			lean = -0.08
		"commit":
			head = -0.7
			lean = -0.14
			head_rate = 40.0
		"skid":
			head = 0.3
			lean = 0.2
			legs = [0.7,0.7,-0.3,-0.3]
			swing = 1.0
		"teeter":
			lean = -0.4+0.1*sin(state_t*38.0)
			head = -0.5
			legs = [sin(state_t*40.0),sin(state_t*40.0+PI),-0.4,-0.4]
			swing = 1.0
		"dig":
			head = -0.2
			lean = -0.04
	_head.rotation.x = lerpf(_head.rotation.x,head,1.0-exp(-head_rate*delta))
	_head.rotation.y = lerpf(_head.rotation.y,look,1.0-exp(-12.0*delta))
	if grounded:
		skin.rotation.x = lerpf(skin.rotation.x,lean,1.0-exp(-12.0*delta))
		skin.rotation.z = lerpf(skin.rotation.z,bank,1.0-exp(-12.0*delta))
	for i in range(4): _legs[i].rotation.x = lerpf(_legs[i].rotation.x,float(legs[i])*swing,1.0-exp(-20.0*delta))

## Falling: its nose goes down, over the rim.
func _air_pose(delta: float) -> void:
	skin.rotation.x = maxf(skin.rotation.x-2.4*delta,-1.4)

# --- Contact ---------------------------------------------------------------------

## A pilot hanging from a rim is never touched. Charging, only the horns
## hurt, and only a pilot with his feet under `hop` of its height there;
## the base's push (him sliding into it) when it is not charging.
func touch(m: PilotMotor, v_pre: Vector3) -> void:
	if gone or _cool > 0.0 or m.on_ledge(): return
	if state == "teeter": return
	if harmful():
		if m.seized() or (m.recovering() and not m.stunnable(self)): return
		var local := Basis(Vector3.UP,facing).inverse()*(m.feet-position)
		var r := float(knobs.radius)
		var nose := -length*0.5
		if absf(local.x) > width*0.5+r: return
		if local.z < nose-r or local.z > nose+length*float(knobs.horns): return
		if m.feet.y-position.y >= height*float(knobs.hop): return
		hits_pilot(m)
		return
	super.touch(m,v_pre)

func hits_pilot(m: PilotMotor) -> void:
	var way := Vector2(vel.x,vel.z)
	if way.length() < 0.1: way = _dir
	shove_pilot(m,way.normalized(),float(knobs.shove_out),float(knobs.shove_up))
	# Proud: it slides on a little, then is winded.
	_hit = true
	if state == "charge" or state == "commit": _start_skid(true)

func bumped() -> void:
	if state in ["charge","commit","skid"]:
		_dust_kick()
		field.sound(&"ram_thud",global_position)
		stun(float(knobs.stun_wall))

func landed() -> void:
	stun(float(knobs.stun_miss))

func pushed(speed: float) -> void:
	skin.rotation.x = 0.0
	super.pushed(speed)

func stun(seconds: float) -> void:
	if _trail != null:
		_trail.emitting = false
		_spray.emitting = false
	if _head != null:
		_head.rotation.x = 0.1
		_head.rotation.y = 0.0
	skin.rotation.z = 0.0
	_yaw_rate = 0.0
	super.stun(seconds)
