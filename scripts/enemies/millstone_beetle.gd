extends "res://scripts/enemies/enemy.gd"
## The Millstone Beetle (docs/design/roguelike/ideas-enemies.md 2, docs/
## design/roguelike/beetle-round1.md): the deck's patroller. A heavy scarab
## rolling a millstone up and down a lane of an isle's flat (a terrace, a
## causeway, a landing), the way it always did, because it has no other job.
## It never turns early; it sees only down its lane, ahead of its wheel.
##
## States (`state`):
##   "patrol"  rolls the wheel toward the lane's end ahead at `patrol_speed`,
##             the stone grinding; at the end (or a lip, or a wall) it stops.
##   "turn"    rests `end_rest` s, then hauls the wheel round, slow and
##             heavy (`turn_time` for the half turn), and goes back.
##   "notice"  he is ahead on its lane (within `notice` m past its wheel and
##             `notice_side` m to either side of it, on ground it can roll
##             to): it stops dead, the head comes up, the feelers lift, a hiss.
##   "tell"    it plants: the legs splay, the body sinks, and the wheel is
##             racked back in its grip `clicks` times (a click each, dust at
##             the feet), the last a heavy clack and a `hold`: then it goes.
##   "charge"  winds up over `wind_up` to `charge_speed`, dead straight down
##             its lane (it can't steer a millstone). Short of the commit it
##             still looks: he stepped out of its line, a lip it can't stop
##             before, he ran out of range: it brakes in time (a safe stop).
##   commit    `commit` s from reaching him it stops looking. Hit, he is
##             knocked hard on down the lane (`shove_out`, laid down `down`
##             s, a heart): the lanes run to the void. Dodged (a jump over
##             the wheel, a late step aside), it brakes on blind: from full
##             pace it needs `kill_band` m, and if a lip comes first the
##             wheel tears out of its grip and goes over
##             (scripts/enemies/millstone_wheel.gd: it falls, or jams in a
##             gap narrower than itself and is a bridge). Faster than
##             `over_share` of its top it goes over after it.
##   "brake"   legs dug in, sitting back, dust spraying, the stone grinding.
##   "dig"     stopped; winded (stunned `stun_hit`) if it hit him, else it
##             looks down its lane again (a short tell) or patrols on.
##   "teeter"  its wheel gone over, scrabbling at the lip `teeter` s.
##   "bereft"  without its wheel: harmless, it wanders its lane slowly.
##   "stun"    (the base's) a stone to stand on.
## Its body is two stones (the wheel, the shell): he stands on the shell, a
## jump that comes down on it while it charges is bucked off behind it.
## Running or sliding into it at the base's `push_speed` barely moves it
## (`push_carry`); bereft it is light and goes over a lip.
## Sizes all come from the pilot's numbers (enemy_field.gd `numbers()`):
## the wheel as tall as his plain jump (`wheel` scales it), so a timed
## jump clears it.
const Look = preload("res://scripts/enemies/millstone_look.gd")
const Voice = preload("res://scripts/enemies/beetle_voice.gd")
const Wheel = preload("res://scripts/enemies/millstone_wheel.gd")

## The wheel's diameter and thickness, the shell's length, width, height.
var d := 1.0
var t := 0.4
var lb := 1.2
var wb := 1.0
var hb := 0.7
var has_wheel := true
## The lane: its two ends (world), and which it is going to.
var lane_a := Vector3.INF
var lane_b := Vector3.INF
var _to_b := true
## The wheel's and the shell's middles along its length (local z).
var _zw := 0.0
var _zb := 0.0
var _beetle: Node3D
var _wheel: Node3D
var _head: Node3D
var _feelers: Array[Node3D] = []
## The walking legs' hips (and each one's phase), the front pair's.
var _legs: Array[Node3D] = []
var _phase: Array[float] = []
var _fore: Array[Node3D] = []
var _wheel_col: CollisionShape3D
var _shell_col: CollisionShape3D
var _trail: CPUParticles3D
var _spray: CPUParticles3D
var _kick: CPUParticles3D
var _rumble: AudioStreamPlayer3D

var _dir := Vector2.ZERO
var _travelled := 0.0
var _committed := false
var _hit := false
var _safe := false
var _doomed := false
var _again := false
var _clicked := 0
var _tell_len := 1.0
var _turn_to := 0.0
var _spin := 0.0
var _rack := 0.0
var _gait := 0.0
var _pace_at_lip := 0.0
## Its look's eased values: the body's sink (0 up, 1 planted), lean, the
## wheel pulled back in the grip (m).
var _sink := 0.0
var _pull := 0.0
var _squash := Vector3.ONE

func _init() -> void:
	cost = 2
	tags = PackedStringArray(["knockable","pushes","loud","deck"])
	tell_sound = &"beetle_click"

func default_knobs(n: Dictionary) -> Dictionary:
	return {
		"wheel":1.0,
		"patrol_speed":n.walk*0.75,"turn_time":1.15,"end_rest":0.6,
		"notice":n.run*2.1,"notice_side":n.unit*1.2,"notice_beat":0.3,
		"tell":1.05,"retell":0.6,"clicks":3,"hold":0.2,
		"charge_speed":n.run*1.45,"wind_up":0.5,"charge_dist":n.run*3.4,
		"commit":0.55,"kill_band":n.unit*2.4,"lip":n.unit*0.1,"lip_brake":n.run*4.0,
		"line_out":n.unit*0.3,"over_share":0.72,"teeter":0.8,
		"hop":0.4,"shove_out":n.run*2.6,"shove_up":n.unit*0.55,"down":0.7,
		"stun_wall":2.2,"stun_hit":0.9,"stun_miss":1.4,"dig":0.45,
		"bereft_speed":n.walk*0.45,"push_carry":0.3,"lane_half":n.run*2.0,
		"lane_a":Vector3.INF,"lane_b":Vector3.INF,
	}

func _size(n: Dictionary) -> void:
	# The wheel as tall as his plain jump, `wheel` times.
	d = n.jump*float(knobs.wheel)
	t = d*0.42
	lb = d*1.25
	wb = d*1.05
	hb = d*0.7
	length = d+lb-d*0.12
	width = wb
	height = d
	_zw = -length*0.5+d*0.5
	_zb = length*0.5-lb*0.5

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	lane_a = knobs.lane_a
	lane_b = knobs.lane_b
	if lane_a == Vector3.INF or lane_b == Vector3.INF:
		var f := PilotMotor.forward(facing)
		var half := float(knobs.lane_half)
		lane_a = at-Vector3(f.x,0.0,f.y)*half
		lane_b = at+Vector3(f.x,0.0,f.y)*half
	# Going the way it faces.
	var to_b := Vector2(lane_b.x-position.x,lane_b.z-position.z)
	_to_b = to_b.dot(PilotMotor.forward(facing)) >= 0.0
	_turn_to = facing
	state = "patrol"

func _ready() -> void:
	_rumble = AudioStreamPlayer3D.new()
	_rumble.stream = Voice.rumble()
	_rumble.unit_size = 9.0
	_rumble.volume_db = -30.0
	_rumble.position = Vector3(0.0,d*0.5,_zw)
	add_child(_rumble)
	_rumble.play()

func harm_cause() -> String:
	return "beetle"

# --- The look ----------------------------------------------------------------------

func _build() -> void:
	super._build()
	# The base's one box made two: the wheel and the shell.
	_wheel_col = body.get_child(0)
	var wb_box := BoxShape3D.new()
	wb_box.size = Vector3(t+0.1,d,d)
	_wheel_col.shape = wb_box
	_wheel_col.position = Vector3(0.0,d*0.5,_zw)
	_shell_col = CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(wb*0.9,hb*0.95,lb*0.95)
	_shell_col.shape = sb
	_shell_col.position = Vector3(0.0,hb*0.95*0.5,_zb)
	body.add_child(_shell_col)

func _art(root: Node3D) -> void:
	_wheel = Look.wheel(d,t)
	_wheel.position = Vector3(0.0,d*0.5,_zw)
	root.add_child(_wheel)
	_beetle = Node3D.new()
	_beetle.name = "Beetle"
	_beetle.position = Vector3(0.0,0.0,_zb)
	root.add_child(_beetle)
	var dome := Look.part(_beetle,Look.dome(Vector3(wb,hb*0.72,wb)),Vector3(0.0,hb*0.3,lb*0.1),hb*0.3,0.0,1.0)
	dome.scale = Vector3(1.0,1.0,lb*0.82/wb)
	var belly := Look.part(_beetle,Look.blob(Vector3(wb*0.88,hb*0.42,wb*0.88)),Vector3(0.0,hb*0.32,lb*0.08),hb*0.32,0.1,2.0)
	belly.scale = Vector3(1.0,1.0,lb*0.78/(wb*0.88))
	var neck := Look.part(_beetle,Look.dome(Vector3(wb*0.84,hb*0.5,wb*0.84)),Vector3(0.0,hb*0.27,-lb*0.33),hb*0.27,0.0,3.0)
	neck.scale = Vector3(1.0,1.0,0.6)
	# The head, low and broad, nosed into the wheel's back.
	_head = Node3D.new()
	_head.position = Vector3(0.0,hb*0.3,-lb*0.47)
	_beetle.add_child(_head)
	var skull := Look.part(_head,Look.blob(Vector3(wb*0.44,hb*0.3,wb*0.44)),Vector3(0.0,0.0,-wb*0.08),hb*0.3,0.0,4.0)
	skull.scale = Vector3(1.0,1.0,0.8)
	var shovel := Look.part(_head,Look.blob(Vector3(wb*0.5,hb*0.07,wb*0.3)),Vector3(0.0,-hb*0.07,-wb*0.24),hb*0.23,0.15,5.0)
	shovel.scale = Vector3(1.0,1.0,1.0)
	for side: float in [-1.0,1.0]:
		var e := MeshInstance3D.new()
		var bead := SphereMesh.new()
		bead.radius = wb*0.045
		bead.height = wb*0.09
		bead.radial_segments = 8
		bead.rings = 4
		e.mesh = bead
		e.material_override = Look.eye()
		e.position = Vector3(side*wb*0.18,hb*0.04,-wb*0.17)
		_head.add_child(e)
		# The feelers: short stalks, a soft club at each tip.
		var f := Node3D.new()
		f.position = Vector3(side*wb*0.13,hb*0.05,-wb*0.24)
		_head.add_child(f)
		var tip := Vector3(side*wb*0.1,hb*0.16,-wb*0.12)
		Look.limb(f,Vector3.ZERO,tip,wb*0.014,hb*0.4,6.0)
		Look.part(f,Look.blob(Vector3(wb*0.07,wb*0.09,wb*0.07)),tip,hb*0.5,0.0,7.0)
		_feelers.append(f)
	# The walking legs: middle and hind pairs (tripod phases).
	for leg: Array in [[-1.0,-0.06,PI],[1.0,-0.06,0.0],[-1.0,0.24,0.0],[1.0,0.24,PI]]:
		_legs.append(_walking_leg(float(leg[0]),lb*float(leg[1]),float(leg[1]) > 0.0))
		_phase.append(float(leg[2]))
	# The front pair grips the axle's ends.
	for side: float in [-1.0,1.0]:
		_fore.append(_fore_leg(side))
	_trail = _puffs(18,0.6,0.1,Vector2(0.4,1.1))
	_spray = _puffs(44,0.8,0.15,Vector2(1.2,3.0))
	_kick = _puffs(20,0.6,0.12,Vector2(0.8,2.0))
	_kick.one_shot = true
	_kick.explosiveness = 0.9
	for p: CPUParticles3D in [_trail,_spray,_kick]: root.add_child(p)

## A leg on its hip at `side`, `z` along the shell: a thigh out and up, the
## shin down to the ground at a spread.
func _walking_leg(side: float, z: float, hind: bool) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(side*wb*0.34,hb*0.3,z)
	_beetle.add_child(hip)
	var back := hb*0.22 if hind else 0.0
	# A beetle's leg: a stout thigh out level, a broad shin down and out.
	var knee_at := Vector3(side*hb*0.42,hb*0.1,back*0.5)
	Look.limb(hip,Vector3.ZERO,knee_at,hb*0.1,hb*0.3,8.0)
	var knee := Node3D.new()
	knee.name = "Knee"
	knee.position = knee_at
	hip.add_child(knee)
	var foot := Vector3(side*hb*0.26,-hb*0.3-hb*0.1,back)
	var shin := Look.limb(knee,Vector3.ZERO,foot,hb*0.075,hb*0.12,9.0)
	shin.scale = Vector3(1.0,1.0,0.6)
	return hip

## A front leg reaching from the shell's front to the axle's end.
func _fore_leg(side: float) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(side*wb*0.28,hb*0.3,-lb*0.3)
	_beetle.add_child(hip)
	var grip := Vector3(side*(t*0.5+d*Look.AXLE_OUT*0.6),d*0.5,_zw-_zb)-hip.position
	var knee_at := grip*0.5+Vector3(side*hb*0.22,hb*0.2,0.0)
	Look.limb(hip,Vector3.ZERO,knee_at,hb*0.09,hb*0.35,10.0)
	var knee := Node3D.new()
	knee.name = "Knee"
	knee.position = knee_at
	hip.add_child(knee)
	Look.limb(knee,Vector3.ZERO,grip-knee_at,hb*0.065,hb*0.45,11.0)
	return hip

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
	mat.albedo_color = Color(0.7,0.62,0.48,0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material = mat
	p.mesh = ball
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(wb*0.5,0.05,lb*0.4)
	p.direction = Vector3.UP
	p.spread = 65.0
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0.0,-2.0,0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	return p

func _dust_kick(at := Vector3.INF) -> void:
	_kick.global_position = (global_position if at == Vector3.INF else at)+Vector3.UP*0.05
	_kick.restart()

## No colour tells: it tells with its body, its wheel and its sounds.
func tint(_colour: Color) -> void:
	pass

func _say(key: StringName) -> void:
	field.sound(key,global_position)

# --- Him -------------------------------------------------------------------------

## The pilot from its middle: [along its facing, to the side (abs), up, flat distance].
func _him() -> Array:
	var f: Vector3 = field.motor.feet
	var rel := Vector2(f.x-position.x,f.z-position.z)
	var fwd := PilotMotor.forward(facing)
	return [rel.dot(fwd),absf(rel.x*fwd.y-rel.y*fwd.x),f.y-position.y,rel.length()]

## He is ahead on its lane, in reach, on ground it can roll to.
func _sees() -> bool:
	if not has_wheel or field.motor.on_ledge(): return false
	var h := _him()
	var along: float = h[0]
	if along < length*0.5 or along > float(knobs.notice): return false
	if float(h[1]) > width*0.5+float(knobs.notice_side): return false
	if float(h[2]) <= -1.0 or float(h[2]) >= 1.8: return false
	var fwd := PilotMotor.forward(facing)
	var dd := length*0.5
	while dd < along-0.3:
		if field.floor_under(position+Vector3(fwd.x,0.0,fwd.y)*dd,1.5,1.0,body.get_rid()) == -INF: return false
		dd += 0.8
	return true

## Seconds till its wheel reaches him at `pace`, his own pace counted.
func _reach_time(pace: float) -> float:
	var h := _him()
	var gap: float = float(h[0])-length*0.5-float(knobs.radius)
	if gap <= 0.0: return 0.0
	var his := Vector2(field.motor.velocity.x,field.motor.velocity.z)
	return gap/maxf(pace-his.dot(_dir),0.5)

## He is past its wheel's face (alongside or behind), or over the wheel.
func _lost_him() -> bool:
	var h := _him()
	var along: float = h[0]
	if float(h[2]) >= d*float(knobs.hop) and along < length*0.5+0.3: return true
	return along < length*0.5-d*0.4

## Out of its line: wider than its wheel's danger and its margin.
func _out_of_line() -> bool:
	return float(_him()[1]) > _danger_half()+float(knobs.line_out)

## Half the width that hurts: the wheel, the axle's ends and the feet gripping them.
func _danger_half() -> float:
	return t*0.5+d*Look.AXLE_OUT+float(knobs.radius)

# --- The states ----------------------------------------------------------------

func think(delta: float) -> void:
	state_t += delta
	match state:
		"patrol": _patrol(delta)
		"turn": _turn(delta)
		"notice": _notice(delta)
		"tell": _tell(delta)
		"charge": _charge(delta)
		"brake": _brake(delta)
		"dig": _dig(delta)
		"teeter": _teeter(delta)
		"plunge": _plunge()
		"bereft": _patrol(delta)
	_pose(delta)

func _go(to: String) -> void:
	state = to
	state_t = 0.0

func _end() -> Vector3:
	return lane_b if _to_b else lane_a

func _patrol(delta: float) -> void:
	if state == "patrol" and _sees():
		_go("notice")
		_say(&"beetle_hiss")
		_dust_kick()
		return
	var end := _end()
	var to := Vector2(end.x-position.x,end.z-position.z)
	var top := float(knobs.patrol_speed) if has_wheel else float(knobs.bereft_speed)
	var look := length*0.5+0.35
	var fwd := PilotMotor.forward(facing)
	if to.length() < 0.3 or edge_ahead(fwd,look) or (to.dot(fwd) < 0.0 and to.length() < 2.0):
		_turn_round()
		return
	var off := _turn_toward(PilotMotor.facing_of(to),0.9*delta)
	if off > 0.6:
		slow(delta,6.0)
		return
	var pace := move_toward(Vector2(vel.x,vel.z).length(),top,3.0*delta)
	fwd = PilotMotor.forward(facing)
	vel.x = fwd.x*pace
	vel.z = fwd.y*pace

func _turn_round() -> void:
	_to_b = not _to_b
	var end := _end()
	_turn_to = PilotMotor.facing_of(Vector2(end.x-position.x,end.z-position.z))
	vel.x = 0.0
	vel.z = 0.0
	_go("turn")

func _turn(delta: float) -> void:
	slow(delta,8.0)
	if state_t < float(knobs.end_rest): return
	var rate := PI/float(knobs.turn_time)*(1.4 if not has_wheel else 1.0)
	var off := _turn_toward(_turn_to,rate*delta)
	if off < 0.02: _go("bereft" if not has_wheel else "patrol")

func _turn_toward(want: float, most: float) -> float:
	var off := angle_difference(facing,want)
	facing = wrapf(facing+clampf(off,-most,most),-PI,PI)
	rotation.y = facing
	return absf(angle_difference(facing,want))

func _notice(delta: float) -> void:
	slow(delta,14.0)
	if not _sees():
		if state_t > 0.6: _go("patrol")
		return
	if state_t >= float(knobs.notice_beat): _start_tell(float(knobs.retell if _again else knobs.tell))

func _start_tell(seconds: float) -> void:
	_go("tell")
	_tell_len = seconds
	_clicked = 0
	_hit = false
	_safe = false
	_doomed = false
	_committed = false
	told_count += 1
	told.emit(self)

func _tell(delta: float) -> void:
	slow(delta,14.0)
	var clicks := maxi(int(knobs.clicks)-(1 if _again else 0),1)
	var span := maxf(_tell_len-float(knobs.hold),0.1)
	var due := int(floor(state_t/span*clicks))+1
	if _clicked < clicks and _clicked < due:
		_clicked += 1
		_say(&"beetle_clack" if _clicked == clicks else &"beetle_click")
		_rack += 0.22
		_dust_kick(to_global(Vector3(0.0,0.0,_zb)))
	# He slipped away early: it settles and goes on.
	if state_t < span*0.6 and not _sees() and state_t > 0.2:
		_go("patrol")
		return
	if state_t >= _tell_len:
		_dir = PilotMotor.forward(facing)
		_travelled = 0.0
		_go("charge")
		_say(&"beetle_charge")
		_dust_kick(to_global(Vector3(0.0,0.0,_zb+lb*0.3)))

## Up to its top over `wind_up`, along `_dir`.
func _run_on(delta: float) -> float:
	var top := float(knobs.charge_speed)
	var pace := move_toward(Vector2(vel.x,vel.z).length(),top,top/maxf(float(knobs.wind_up),0.01)*delta)
	vel.x = _dir.x*pace
	vel.z = _dir.y*pace
	_travelled += pace*delta
	return pace

func _stopping(pace: float) -> float:
	return pace*pace/(2.0*_brake_decel())

func _brake_decel() -> float:
	var top := float(knobs.charge_speed)
	return top*top/(2.0*maxf(float(knobs.kill_band),0.1))

func _charge(delta: float) -> void:
	if not grounded: return
	var pace := Vector2(vel.x,vel.z).length()
	var h := _him()
	if not _committed:
		# Still looking: out of its line, out of range, or a lip it can't stop
		# before: a safe stop.
		if _out_of_line() or float(h[0]) < length*0.5 or float(h[3]) > float(knobs.notice)*1.6 or _travelled >= float(knobs.charge_dist) or field.motor.on_ledge():
			_start_brake(true)
			return
		if edge_ahead(_dir,length*0.5+float(knobs.lip)+_stopping(pace)+pace*delta*2.0):
			_start_brake(true)
			return
		if _reach_time(pace) <= float(knobs.commit):
			_committed = true
			_say(&"beetle_clack")
	else:
		if _lost_him():
			_start_brake(false)
			return
		if _travelled >= float(knobs.charge_dist)*1.3:
			_start_brake(false)
			return
	if edge_ahead(_dir,length*0.5+float(knobs.lip)+pace*delta):
		_over_the_lip(pace)
		return
	_run_on(delta)

func _start_brake(safe: bool) -> void:
	_go("brake")
	_safe = safe or _hit
	var pace := Vector2(vel.x,vel.z).length()
	_doomed = not _safe and edge_ahead(_dir,length*0.5+float(knobs.lip)+_stopping(pace))
	_say(&"beetle_grind")
	_dust_kick(to_global(Vector3(0.0,0.0,_zb)))

func _brake(delta: float) -> void:
	if not grounded: return
	var pace := Vector2(vel.x,vel.z).length()
	var decel := _brake_decel()
	var at_lip := edge_ahead(_dir,length*0.5+float(knobs.lip)+pace*delta)
	if at_lip and pace > 0.3:
		if _doomed or not _safe:
			_over_the_lip(pace)
			return
		vel.x = 0.0
		vel.z = 0.0
	elif _safe and edge_ahead(_dir,length*0.5+float(knobs.lip)+_stopping(pace)): decel = float(knobs.lip_brake)
	_travelled += pace*delta
	if slow(delta,decel):
		vel.x = 0.0
		vel.z = 0.0
		_go("dig")
		_dust_kick(to_global(Vector3(0.0,0.0,_zw)))

func _dig(delta: float) -> void:
	slow(delta,14.0)
	if state_t < float(knobs.dig): return
	if _hit:
		_hit = false
		stun(float(knobs.stun_hit))
	elif _sees():
		_again = true
		_go("notice")
		state_t = float(knobs.notice_beat)
	else:
		_again = false
		_go("patrol")

## Its nose at the lip at `pace`: the wheel tears out of its grip and goes
## on over; the beetle after it if it was going fast.
func _over_the_lip(pace: float) -> void:
	_pace_at_lip = pace
	# Ground again just past the lip (a gap its wheel will jam in): it only teeters.
	var narrow := false
	var probe := length*0.5+float(knobs.lip)+0.1
	while probe < length*0.5+d*1.1 and not narrow:
		narrow = not edge_ahead(_dir,probe)
		probe += 0.1
	_release(maxf(pace,2.0))
	if pace > float(knobs.charge_speed)*float(knobs.over_share) and not narrow:
		_go("plunge")
		_say(&"beetle_scrabble")
		var v := _dir*maxf(pace*0.7,2.0)
		vel.x = v.x
		vel.z = v.y
		return
	vel.x = 0.0
	vel.z = 0.0
	_go("teeter")
	_say(&"beetle_scrabble")

## The wheel let go at `pace`: a loose wheel (scripts/enemies/
## millstone_wheel.gd) in its place, the beetle's body its shell alone.
func _release(pace: float) -> void:
	if not has_wheel: return
	has_wheel = false
	var f := PilotMotor.forward(facing)
	var at := global_position+Vector3(f.x,0.0,f.y)*(-_zw)
	field.add(Wheel,at,f,{"d":d,"t":t,"speed":pace,"spin":_spin})
	_wheel.queue_free()
	_wheel = null
	body.remove_child(_wheel_col)
	_wheel_col.queue_free()
	# Its middle the shell's now.
	position += Vector3(f.x,0.0,f.y)*(-_zb)
	_beetle.position.z = 0.0
	_shell_col.position.z = 0.0
	length = lb
	height = hb
	width = wb
	_zw = 0.0
	_zb = 0.0
	knobs.push_carry = 0.85
	if _rumble != null:
		_rumble.stop()
	# The front legs let go: they walk now.
	for i in range(_fore.size()):
		var side := -1.0 if i == 0 else 1.0
		_fore[i].queue_free()
		_legs.append(_walking_leg(side,-lb*0.3,false))
		_phase.append(0.0 if side < 0.0 else PI)
	_fore.clear()
	body.force_update_transform()

## Going over after its wheel; stopped by something at the lip (its own
## wheel jammed there), it only teeters.
func _plunge() -> void:
	if not grounded: return
	if (state_t > 0.12 and Vector2(moved.x,moved.z).length() < 0.001) or state_t > 0.7:
		_go("teeter")
		return
	var v := _dir*maxf(_pace_at_lip*0.7,2.0)
	vel.x = v.x
	vel.z = v.y

func _teeter(delta: float) -> void:
	slow(delta,14.0)
	if fmod(state_t,0.18) < delta: _dust_kick(to_global(Vector3(0.0,0.0,-length*0.5)))
	if state_t < float(knobs.teeter): return
	# It backs off the lip and goes on without it.
	_go("bereft")

# --- Its pose --------------------------------------------------------------------

func _pose(delta: float) -> void:
	var pace := Vector2(vel.x,vel.z).length()
	var fwd := PilotMotor.forward(facing)
	var along := Vector2(moved.x,moved.z).dot(fwd)
	if has_wheel and _wheel != null:
		_spin += along/(d*0.5)
	# Eased targets by state.
	var sink := 0.0
	var pull := 0.0
	var lean := 0.0
	var head := 0.0
	var feel := 0.0
	var sq := Vector3.ONE
	var gait_rate := pace/maxf(lb*0.55,0.1)*TAU
	var stride := 0.38
	var lift := 0.35
	match state:
		"patrol", "bereft":
			head = 0.04*sin(state_t*1.7)
			feel = 0.1*sin(state_t*2.3)
		"turn":
			gait_rate = 7.0 if state_t > float(knobs.end_rest) else 0.0
			stride = 0.25
			head = -0.05
		"notice":
			head = 0.3
			feel = 0.55
			sq = Vector3(0.98,1.05,0.98)
		"tell":
			var k := clampf(state_t/maxf(_tell_len-float(knobs.hold),0.1),0.0,1.0)
			sink = k
			pull = d*0.09*k
			head = lerpf(0.2,-0.25,k)
			feel = 0.4-0.5*k
			sq = Vector3(1.0+0.08*k,1.0-0.14*k,1.0-0.04*k)
			lean = -0.03*k
			gait_rate = 0.0
		"charge":
			var k := clampf(pace/float(knobs.charge_speed),0.0,1.0)
			lean = -0.07*k
			head = -0.3
			feel = -0.4
			# Off the mark: stretched long; settled at its top.
			var off_mark := clampf(1.0-state_t/0.25,0.0,1.0)
			sq = Vector3(1.0-0.05*off_mark,1.0-0.04*off_mark,1.0+0.14*off_mark+0.04*k)
			stride = 0.5
			lift = 0.5
		"brake":
			lean = 0.16
			head = 0.15
			sq = Vector3(1.06,0.9,0.96)
			gait_rate = 0.0
		"dig":
			lean = 0.05*(1.0-state_t/maxf(float(knobs.dig),0.1))
			sq = Vector3(1.03,0.95,1.0)
		"teeter":
			lean = -0.22+0.07*sin(state_t*34.0)
			head = -0.4
			feel = 0.6*sin(state_t*20.0)
			gait_rate = 30.0
			stride = 0.6
		"stun":
			lean = 0.06*sin(state_t*9.0)*exp(-state_t*1.5)
			head = -0.2
			feel = 0.3*sin(state_t*14.0)
			gait_rate = 0.0
	var e := 1.0-exp(-14.0*delta)
	_sink = lerpf(_sink,sink,e)
	_pull = lerpf(_pull,pull,1.0-exp(-(30.0 if state == "charge" else 10.0)*delta))
	_squash = _squash.lerp(sq,1.0-exp(-(22.0 if state == "charge" else 12.0)*delta))
	# The rack's clicks pull the wheel back a notch at a time; let go at the launch.
	if state != "tell": _rack = move_toward(_rack,0.0,6.0*delta)
	if _wheel != null:
		_wheel.rotation.x = -_spin+_rack
		_wheel.position.z = _zw+_pull
	_beetle.scale = _squash
	_beetle.position.y = -hb*0.08*_sink
	if grounded and state != "plunge":
		skin.rotation.x = lerpf(skin.rotation.x,lean,1.0-exp(-10.0*delta))
	_head.rotation.x = lerpf(_head.rotation.x,head,1.0-exp(-12.0*delta))
	for i in range(_feelers.size()):
		_feelers[i].rotation.x = lerpf(_feelers[i].rotation.x,feel+0.08*sin(state_t*5.0+i),1.0-exp(-10.0*delta))
	# The legs: a tripod gait; planted, splayed out.
	_gait += gait_rate*delta
	for i in range(_legs.size()):
		var side := -1.0 if i%2 == 0 else 1.0
		var ph := _gait+_phase[i]
		var moving := gait_rate > 0.01
		var swing := side*stride*sin(ph) if moving else 0.0
		var up := side*lift*maxf(0.0,cos(ph)) if moving else 0.0
		# Splayed under the weight (the tell, the brake): the hips roll down.
		var splay := -side*0.28*maxf(_sink,0.6 if state == "brake" else 0.0)
		_legs[i].rotation.y = lerpf(_legs[i].rotation.y,swing,1.0-exp(-25.0*delta))
		_legs[i].rotation.z = lerpf(_legs[i].rotation.z,up+splay,1.0-exp(-25.0*delta))
	for i in range(_fore.size()):
		# Pumping the axle as it runs.
		var push := 0.08*sin(_gait*1.0+float(i)*PI) if state == "charge" else 0.0
		_fore[i].rotation.x = push
	# The dust and the grind.
	var top := float(knobs.charge_speed)
	_trail.global_position = global_position+Vector3.UP*0.05
	_trail.emitting = grounded and state == "charge" and pace > top*0.4
	_spray.global_position = to_global(Vector3(0.0,0.05,_zw))
	_spray.emitting = grounded and state == "brake" and pace > 0.8
	if _rumble != null and has_wheel:
		var k := clampf(pace/top,0.0,1.0)
		_rumble.volume_db = linear_to_db(maxf(0.06+0.94*k,0.001))-4.0
		_rumble.pitch_scale = 0.7+0.6*k

## Falling: its nose down, over the rim.
func _air_pose(delta: float) -> void:
	skin.rotation.x = maxf(skin.rotation.x-2.0*delta,-1.3)

# --- Contact ---------------------------------------------------------------------

func harmful() -> bool:
	return has_wheel and grounded and (state == "charge" or (state == "brake" and Vector2(vel.x,vel.z).length() > 2.0))

func bucks() -> bool:
	return not grounded or state in ["charge","brake","teeter","plunge"]

## The wheel's face hurts (his feet under `hop` of it): a hard knock on down
## the lane. Otherwise the base's push.
func touch(m: PilotMotor, v_pre: Vector3) -> void:
	if gone or _cool > 0.0 or m.on_ledge(): return
	if harmful():
		if m.seized() or (m.recovering() and not m.stunnable(self)): return
		var local := Basis(Vector3.UP,facing).inverse()*(m.feet-position)
		var r := float(knobs.radius)
		var nose := -length*0.5
		if absf(local.x) > _danger_half(): return
		if local.z < nose-r or local.z > nose+d+r*0.5: return
		if m.feet.y-position.y >= d*float(knobs.hop): return
		hits_pilot(m)
		return
	if state == "teeter" or state == "plunge": return
	super.touch(m,v_pre)

func hits_pilot(m: PilotMotor) -> void:
	var way := _dir if _dir.length() > 0.1 else PilotMotor.forward(facing)
	m.knock(m.knock_velocity(way,float(knobs.shove_out),float(knobs.shove_up)),self,float(knobs.down))
	m.harm(harm_cause(),1,self)
	_cool = 0.6
	hit_pilot.emit(self)
	_say(&"beetle_thud")
	_hit = true
	_start_brake(true)

func pushed(speed: float) -> void:
	skin.rotation.x = 0.0
	super.pushed(speed)

func bumped() -> void:
	if state in ["charge","brake"]:
		_dust_kick(to_global(Vector3(0.0,0.0,-length*0.5)))
		_say(&"beetle_thud")
		_rack = 0.0
		stun(float(knobs.stun_wall))
	elif state == "patrol" or state == "bereft":
		_turn_round()

func landed() -> void:
	stun(float(knobs.stun_miss))

func stun(seconds: float) -> void:
	if _trail != null:
		_trail.emitting = false
		_spray.emitting = false
	super.stun(seconds)

## Stunned it comes back to its lane's patrol (or its wandering, bereft).
func step(delta: float) -> void:
	var was := state
	super.step(delta)
	if was == "stun" and state == "idle":
		state = "patrol" if has_wheel else "bereft"
	if state == "stun": _pose(delta)
