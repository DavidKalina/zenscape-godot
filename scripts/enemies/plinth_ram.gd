extends "res://scripts/enemies/enemy.gd"
## The Plinth Ram (docs/design/roguelike/ideas-enemies.md, 7), greybox: a
## stone ram that charges the pilot, and is proud.
##
## "idle": wanders the turf (turning back from any edge, since it only falls
## when sent), and when the pilot is within `notice` m and inside its `sight`
## (half-angle), turns toward him; on his line (inside `line_angle`) it
## "tell"s. "tell" (`tell` s, 0.8): three scrapes of the front, the body
## going `tell_colour`, still aiming until the last `lock` s, then fixed.
## "charge": straight along the locked line, to `charge_speed` (over the
## pilot's run), no steering, for up to `charge_dist` m. Hitting him shoves
## him `shove_out` m along the line (PilotMotor.knock). Missing, it keeps
## going: over an edge it sails off; at the end of its distance it "skid"s
## to rest and is stunned `stun_miss` s; into a wall it is stunned `stun_wall`
## s. A pilot that slides into it from the side (`push_speed` along the line
## to it) knocks it away instead. Stunned, it is a stone to stand on.
## Sizes and speeds all come from the pilot's numbers (enemy_field.gd
## `numbers()`): its back is a bit under his plain jump high.

func _init() -> void:
	cost = 3
	tags = PackedStringArray(["knockable","pushes","loud"])
	tell_sound = &"ram_paw"

func default_knobs(n: Dictionary) -> Dictionary:
	return {
		"wander_speed":n.walk*0.5,"turn":1.8,"sight":1.2,"notice":n.run*2.4,"line_angle":0.14,
		"tell":0.8,"lock":0.3,"charge_speed":n.run*1.6,"charge_accel":n.run*8.0,"charge_dist":n.unit*13.0,
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

var _dir := Vector2.ZERO
var _travelled := 0.0
var _walking := false
var _wander_t := 0.0
var _turn_to := 0.0
var _rng := RandomNumberGenerator.new()

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	_turn_to = facing
	_rng.seed = hash(at)
	# Ready from the start: no rest owed.
	state_t = float(knobs.rest)

func harmful() -> bool:
	return state == "charge"

func think(delta: float) -> void:
	state_t += delta
	match state:
		"idle": _idle(delta)
		"tell": _tell(delta)
		"charge": _charge(delta)
		"skid":
			if grounded and slow(delta,float(knobs.skid_decel)): stun(float(knobs.stun_miss))

## Where the pilot is from its middle: [flat way (x, z), distance, height over its feet].
func _pilot() -> Array:
	var f: Vector3 = field.motor.feet
	var flat := Vector2(f.x-position.x,f.z-position.z)
	return [flat,flat.length(),f.y-position.y]

func _idle(delta: float) -> void:
	var p := _pilot()
	var flat: Vector2 = p[0]
	var dist: float = p[1]
	var up: float = p[2]
	var want := PilotMotor.facing_of(flat) if dist > 0.01 else facing
	var off := absf(angle_difference(facing,want))
	var near: bool = dist <= float(knobs.notice) and dist > length*0.5+float(knobs.radius)+0.4 and up > -1.0 and up < 2.0
	var resting: bool = state_t < float(knobs.rest)
	if near and not resting and off <= float(knobs.sight):
		slow(delta,float(knobs.skid_decel))
		_aim(want,delta,1.0)
		if off <= float(knobs.line_angle): _start_tell()
		return
	_wander(delta)

func _aim(want: float, delta: float, rate: float) -> void:
	var max_turn := float(knobs.turn)*rate*delta
	facing = wrapf(facing+clampf(angle_difference(facing,want),-max_turn,max_turn),-PI,PI)
	rotation.y = facing

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

func _start_tell() -> void:
	state = "tell"
	state_t = 0.0
	tell()

func _tell(delta: float) -> void:
	slow(delta,float(knobs.skid_decel))
	var t := float(knobs.tell)
	# Three scrapes: the front dips and lifts.
	skin.rotation.x = -0.2*maxf(0.0,sin(TAU*1.5*state_t/t))
	if state_t < t-float(knobs.lock):
		var p := _pilot()
		var flat: Vector2 = p[0]
		if flat.length() > 0.01: _aim(PilotMotor.facing_of(flat),delta,1.5)
	if state_t >= t:
		skin.rotation.x = 0.0
		_dir = PilotMotor.forward(facing)
		_travelled = 0.0
		state = "charge"
		state_t = 0.0

func _charge(delta: float) -> void:
	if not grounded: return
	var pace := Vector2(vel.x,vel.z).length()
	pace = move_toward(pace,float(knobs.charge_speed),float(knobs.charge_accel)*delta)
	vel.x = _dir.x*pace
	vel.z = _dir.y*pace
	_travelled += pace*delta
	if _travelled >= float(knobs.charge_dist):
		state = "skid"
		state_t = 0.0

func hits_pilot(m: PilotMotor) -> void:
	var way := Vector2(vel.x,vel.z)
	if way.length() < 0.1: way = _dir
	shove_pilot(m,way.normalized(),float(knobs.shove_out),float(knobs.shove_up))
	# Proud: it goes on a little, then stops.
	state = "skid"
	state_t = 0.0

func bumped() -> void:
	if state == "charge" or state == "skid":
		stun(float(knobs.stun_wall))

func landed() -> void:
	if state == "charge" or state == "skid": stun(float(knobs.stun_miss))

func pushed(speed: float) -> void:
	skin.rotation.x = 0.0
	super.pushed(speed)
