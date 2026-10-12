extends "res://scripts/enemies/enemy.gd"
## The Plinth Ram (docs/design/roguelike/ideas-enemies.md, 7), greybox: a
## stone ram that charges the pilot, and is proud.
##
## "idle": wanders the turf (turning back from any edge, since it only falls
## when sent), and when the pilot is within `notice` m and inside its `sight`
## (half-angle), turns toward him; on his line (inside `line_angle`) it
## "tell"s. "tell" (`tell` s, 0.8): three scrapes of the front, the body
## going `tell_colour`, still aiming until the last `lock` s, then fixed.
## "charge": straight along the locked line, no steering, winding up from
## a standstill to `charge_speed` (over the pilot's run) over `wind_up` s,
## and only as far as where he stood when it locked plus `overrun` m (at most
## `charge_dist`). Then it "skid"s, as the pilot does thrown back at a run:
## it keeps sliding along the line, braking at `brake` m/s^2, while it swings
## round toward him at `skid_turn` rad/s (dust off its feet, a scrape sound).
## A sliding ram faster than `hurt_speed` still hurts. Stopped, it "dig"s in
## for `dig` s (still swinging till it faces him) and, if he is still in
## notice, tells again for `retell` s and goes again; no long stun after a
## miss, so a juke has to be late and sharp, and he can slide it off in the
## skid or the dig. After a hit it is stunned `stun_hit` s instead. It never
## runs itself off an edge: near a lip it brakes harder (`lip_brake`) and
## stops dead at the lip; only a push sends it over. Hitting him shoves him
## `shove_out` m along its way (PilotMotor.knock); into a wall it is stunned
## `stun_wall` s. A pilot that slides into it from the side (`push_speed`
## along the line to it) knocks it away instead. Stunned, it is a stone to
## stand on.
## Sizes and speeds all come from the pilot's numbers (enemy_field.gd
## `numbers()`): its back is a bit under his plain jump high.

func _init() -> void:
	cost = 3
	tags = PackedStringArray(["knockable","pushes","loud"])
	tell_sound = &"ram_paw"

func default_knobs(n: Dictionary) -> Dictionary:
	return {
		"wander_speed":n.walk*0.5,"turn":2.6,"sight":1.2,"notice":n.run*2.4,"line_angle":0.14,
		"tell":0.6,"lock":0.2,"charge_speed":n.run*1.6,"wind_up":0.5,"charge_dist":n.unit*13.0,
		"overrun":n.run*1.1,"brake":n.run*2.2,"lip_brake":n.run*5.0,"lip":n.unit*0.15,
		"skid_turn":4.5,"hurt_speed":n.run*0.9,"dig":0.25,"retell":0.35,
		"shove_out":n.run*1.9,"shove_up":n.unit*0.45,
		"stun_miss":1.2,"stun_hit":0.6,"stun_wall":2.5,"edge_look":n.unit*0.8,
	}

## Its back a bit under his plain jump; longer than it is wide.
func _size(n: Dictionary) -> void:
	height = n.jump*0.9
	width = height
	length = height*2.2

func _art(_root: Node3D) -> void:
	_part(Vector3(width,height,length),Vector3(0.0,height*0.5,0.0),true)
	_part(Vector3(width*0.8,height*0.7,length*0.3),Vector3(0.0,height*0.9,-length*0.55),true)
	# The horns: lintel corners.
	for side: float in [-1.0,1.0]:
		_part(Vector3(width*0.15,height*0.15,length*0.25),Vector3(side*width*0.5,height*1.3,-length*0.55),false,Color(0.8,0.78,0.7))
	# The facing indicator: a bright muzzle.
	_part(Vector3(width*0.4,height*0.25,length*0.12),Vector3(0.0,height*0.75,-length*0.75),false,mark_colour)
	_dust = _puffs()
	_root.add_child(_dust)

## The skid's dust: soft grey puffs kicked up off its feet.
func _puffs() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.top_level = true
	p.amount = 14
	p.lifetime = 0.5
	p.emitting = false
	p.local_coords = false
	var ball := SphereMesh.new()
	ball.radius = 0.12
	ball.height = 0.24
	ball.radial_segments = 6
	ball.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.72,0.68,0.6,0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material = mat
	p.mesh = ball
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0.0,-1.5,0.0)
	return p

var _dir := Vector2.ZERO
var _travelled := 0.0
var _reach := 0.0
var _walking := false
var _wander_t := 0.0
var _turn_to := 0.0
var _rng := RandomNumberGenerator.new()
var _dust: CPUParticles3D
var _tell_len := 0.0
## Whether this charge hit him (then it is winded after its skid).
var _hit := false

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	_turn_to = facing
	_rng.seed = hash(at)
	# Ready from the start: no rest owed.
	state_t = float(knobs.rest)

func harmful() -> bool:
	return state == "charge" or (state == "skid" and Vector2(vel.x,vel.z).length() >= float(knobs.hurt_speed))

func think(delta: float) -> void:
	state_t += delta
	match state:
		"idle": _idle(delta)
		"tell": _tell(delta)
		"charge": _charge(delta)
		"skid": _skid(delta)
		"dig": _dig(delta)

## Where the pilot is from its middle: [flat way (x, z), distance, height over its feet].
func _pilot() -> Array:
	var f: Vector3 = field.motor.feet
	var flat := Vector2(f.x-position.x,f.z-position.z)
	return [flat,flat.length(),f.y-position.y]

## Whether he is near enough, and at a height, to be gone for.
func _in_notice() -> bool:
	var p := _pilot()
	var dist: float = p[1]
	var up: float = p[2]
	return dist <= float(knobs.notice) and dist > length*0.5+float(knobs.radius)+0.4 and up > -1.0 and up < 2.0

func _idle(delta: float) -> void:
	var p := _pilot()
	var flat: Vector2 = p[0]
	var dist: float = p[1]
	var want := PilotMotor.facing_of(flat) if dist > 0.01 else facing
	var off := absf(angle_difference(facing,want))
	var resting: bool = state_t < float(knobs.rest)
	if _in_notice() and not resting and off <= float(knobs.sight):
		slow(delta,float(knobs.skid_decel))
		_aim(want,delta,1.0)
		if off <= float(knobs.line_angle): _start_tell(float(knobs.tell))
		return
	_wander(delta)

func _aim(want: float, delta: float, rate: float) -> void:
	var max_turn := float(knobs.turn)*rate*delta
	facing = wrapf(facing+clampf(angle_difference(facing,want),-max_turn,max_turn),-PI,PI)
	rotation.y = facing

## Swings its front round toward him at `skid_turn`, whatever way it slides.
func _swing(delta: float) -> float:
	var flat: Vector2 = _pilot()[0]
	if flat.length() < 0.01: return 0.0
	var want := PilotMotor.facing_of(flat)
	var max_turn := float(knobs.skid_turn)*delta
	facing = wrapf(facing+clampf(angle_difference(facing,want),-max_turn,max_turn),-PI,PI)
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
	var way := PilotMotor.forward(facing)
	if edge_ahead(way,length*0.5+float(knobs.edge_look)) and absf(angle_difference(facing,_turn_to)) < 0.3:
		_turn_to = facing+PI*_rng.randf_range(0.6,1.0)*(1.0 if _rng.randf() < 0.5 else -1.0)
	_aim(_turn_to,delta,1.0)
	if absf(angle_difference(facing,_turn_to)) < 0.3 and not edge_ahead(way,length*0.5+float(knobs.edge_look)):
		var v := PilotMotor.forward(facing)*float(knobs.wander_speed)
		vel.x = v.x
		vel.z = v.y
	else: slow(delta,float(knobs.skid_decel))

## The tell, `seconds` long (the first is `tell`, a second go `retell`).
func _start_tell(seconds: float) -> void:
	state = "tell"
	state_t = 0.0
	_tell_len = seconds
	_hit = false
	tell()

func _tell(delta: float) -> void:
	slow(delta,float(knobs.skid_decel))
	var t := _tell_len
	# Three scrapes: the front dips and lifts.
	skin.rotation.x = -0.2*maxf(0.0,sin(TAU*1.5*state_t/t))
	if state_t < t-minf(float(knobs.lock),t*0.5):
		var p := _pilot()
		var flat: Vector2 = p[0]
		if flat.length() > 0.01: _aim(PilotMotor.facing_of(flat),delta,1.5)
	if state_t >= t:
		skin.rotation.x = 0.0
		_dir = PilotMotor.forward(facing)
		_travelled = 0.0
		_reach = minf(float(_pilot()[1])+float(knobs.overrun),float(knobs.charge_dist))
		state = "charge"
		state_t = 0.0

func _charge(delta: float) -> void:
	if not grounded: return
	var pace := Vector2(vel.x,vel.z).length()
	var top := float(knobs.charge_speed)
	pace = move_toward(pace,top,top/maxf(float(knobs.wind_up),0.01)*delta)
	vel.x = _dir.x*pace
	vel.z = _dir.y*pace
	_travelled += pace*delta
	# Into its skid so that it stops at the end of its reach; near a lip, in
	# time for the harder brake to stop it there.
	var stopping := pace*pace/(2.0*float(knobs.brake))
	if _travelled+stopping >= _reach or _edge_within(pace*pace/(2.0*float(knobs.lip_brake))+pace*delta*2.0):
		_start_skid()

func _start_skid() -> void:
	state = "skid"
	state_t = 0.0
	field.sound(&"ram_scrape",global_position)

## Sliding on along its line, braking, the front swinging round toward him;
## at a lip it brakes harder and stops dead on it.
func _skid(delta: float) -> void:
	if not grounded: return
	var pace := Vector2(vel.x,vel.z).length()
	_dust.global_position = global_position+Vector3.UP*0.05
	_dust.emitting = pace > 1.0
	_swing(delta)
	var decel := float(knobs.brake)
	if _edge_within(0.0):
		vel.x = 0.0
		vel.z = 0.0
	elif _edge_within(pace*pace/(2.0*decel)):
		decel = float(knobs.lip_brake)
	if slow(delta,decel):
		vel.x = 0.0
		vel.z = 0.0
		_dust.emitting = false
		state = "dig"
		state_t = 0.0

## Dug in: still coming round to face him; then winded after a hit, or
## (he still near) a short second tell and on again.
func _dig(delta: float) -> void:
	slow(delta,float(knobs.skid_decel))
	var off := _swing(delta)
	if state_t < float(knobs.dig) or (off > float(knobs.line_angle)*2.0 and state_t < 1.5): return
	if _hit: stun(float(knobs.stun_hit))
	elif _in_notice(): _start_tell(float(knobs.retell))
	else:
		state = "idle"
		state_t = 0.0

## An edge ahead along its way within `dist` m past its front and the lip.
func _edge_within(dist: float) -> bool:
	var way := Vector2(vel.x,vel.z)
	way = way.normalized() if way.length() > 0.1 else _dir
	return edge_ahead(way,length*0.5+float(knobs.lip)+dist)

func hits_pilot(m: PilotMotor) -> void:
	var way := Vector2(vel.x,vel.z)
	if way.length() < 0.1: way = _dir
	shove_pilot(m,way.normalized(),float(knobs.shove_out),float(knobs.shove_up))
	# Proud: it slides on a little, then is winded.
	_hit = true
	if state != "skid": _start_skid()

func bumped() -> void:
	if state == "charge" or state == "skid":
		stun(float(knobs.stun_wall))

func landed() -> void:
	if state == "charge" or state == "skid": stun(float(knobs.stun_miss))

func pushed(speed: float) -> void:
	skin.rotation.x = 0.0
	super.pushed(speed)

func stun(seconds: float) -> void:
	if _dust != null: _dust.emitting = false
	super.stun(seconds)
