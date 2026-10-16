extends "res://scripts/enemies/enemy.gd"
## The Millstone Beetle's wheel, let go: when a charging beetle can't stop
## before a lip, its wheel
## tears out of its grip and rolls on alone. Spawned by scripts/enemies/
## millstone_beetle.gd (`field.add`), stepped by the EnemyField like any
## enemy. Scripted, not a rigid body, so it reads and plays the same every
## time:
##   "roll"     on the ground at `speed` along its facing, slowed by
##              `roll_drag` and sped or slowed by the slope; it crushes him
##              while faster than `harm_speed` (a hard knock along its way,
##              a heart). Into a wall it bounces back a little. Slow under
##              `topple_speed`, it wobbles and falls flat.
##   at a lip   it looks across: ground again within `jam` of its diameter
##              (a gap it can't drop through) and it JAMS: it drops into
##              the gap, grinding down until its top sits `flush` over the
##              lip (the lips crumble round it), a stone plug he can walk
##              over: "every danger is a tool". Else it goes over.
##   "fall"     tumbling under gravity; onto ground it lands (a thud, a
##              bounce if hard) and rolls on, under the field's `lost` it
##              is gone (a far crash when it lands out of sight).
##   "flat"     fallen on its face: a round step 1 thickness high.
##   "jammed"   a plug in the gap.
## Flat or jammed it is a still stone to stand on (the base's prop).
const Look = preload("res://scripts/enemies/millstone_look.gd")
const Voice = preload("res://scripts/enemies/beetle_voice.gd")

var d := 1.0
var t := 0.4
## Its pace along its facing (m/s, signed: a bounce runs it back).
var speed := 0.0
## How far it has turned (rad), and its wobble as it falls flat.
var spin := 0.0
var _tip := 0.0
var _tip_v := 0.0
var _tip_side := 1.0
var _wheel: Node3D
var _collider: CollisionShape3D
var _fallen_from := 0.0
var _dust: CPUParticles3D

func _init() -> void:
	cost = 0
	tags = PackedStringArray(["stone","bridge"])
	state = "roll"

func default_knobs(n: Dictionary) -> Dictionary:
	return {
		"d":n.jump,"t":n.jump*0.42,"speed":3.0,"spin":0.0,
		"roll_drag":0.9,"topple_speed":0.55,"harm_speed":2.2,
		"jam":0.95,"flush":n.step_up*0.85,
		"shove_out":n.run*2.2,"shove_up":n.unit*0.5,"down":0.6,"hop":0.55,
		"bounce":0.3,
	}

func _size(_n: Dictionary) -> void:
	d = float(knobs.d)
	t = float(knobs.t)
	width = t
	height = d
	length = d

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	speed = float(knobs.speed)
	spin = float(knobs.spin)
	_collider = body.get_child(0)
	if bool(knobs.get("falling",false)):
		grounded = false
		state = "fall"
		vel = Vector3(PilotMotor.forward(facing).x*speed,float(knobs.get("vy",0.0)),PilotMotor.forward(facing).y*speed)
		_fallen_from = position.y

func _art(root: Node3D) -> void:
	_wheel = Look.wheel(d,t)
	_wheel.position = Vector3(0.0,d*0.5,0.0)
	_wheel.rotation.x = -spin
	root.add_child(_wheel)
	_dust = CPUParticles3D.new()
	_dust.top_level = true
	_dust.amount = 26
	_dust.lifetime = 0.8
	_dust.one_shot = true
	_dust.explosiveness = 0.9
	_dust.emitting = false
	var ball := SphereMesh.new()
	ball.radius = 0.14
	ball.height = 0.28
	ball.radial_segments = 6
	ball.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.72,0.64,0.5,0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material = mat
	_dust.mesh = ball
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(d*0.5,0.05,d*0.5)
	_dust.direction = Vector3.UP
	_dust.spread = 70.0
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 3.0
	_dust.gravity = Vector3(0.0,-3.0,0.0)
	root.add_child(_dust)

func tint(_colour: Color) -> void:
	pass

func _puff() -> void:
	if _dust == null: return
	_dust.global_position = global_position+Vector3.UP*0.05
	_dust.restart()

func _say(key: String) -> void:
	field.sound(StringName(key),global_position)

func harm_cause() -> String:
	return "beetle"

## Rolling fast it crushes; flat or jammed it is a stone.
func harmful() -> bool:
	return state == "roll" and absf(speed) > float(knobs.harm_speed)

func bucks() -> bool:
	return state == "roll" or state == "fall" or state == "topple"

# --- A frame ---------------------------------------------------------------------

func step(delta: float) -> void:
	if gone: return
	_cool = maxf(0.0,_cool-delta)
	var was := position
	state_t += delta
	match state:
		"roll": _roll(delta)
		"fall": _fall(delta)
		"topple": _topple(delta)
	moved = position-was
	if not gone: body.force_update_transform()

func _roll(delta: float) -> void:
	var rid := body.get_rid()
	var fwd := PilotMotor.forward(facing)
	var way := fwd*signf(speed) if speed != 0.0 else fwd
	# The slope: its ground a little ahead and behind.
	var ga: float = field.floor_under(position+Vector3(fwd.x,0.0,fwd.y)*0.4,float(knobs.step_up),float(knobs.step_up),rid)
	var gb: float = field.floor_under(position-Vector3(fwd.x,0.0,fwd.y)*0.4,float(knobs.step_up),float(knobs.step_up),rid)
	if ga != -INF and gb != -INF:
		# Down the slope it speeds (a rolling disc: two thirds of g sin).
		speed += -float(knobs.gravity)/1.5*(ga-gb)/0.8*delta*0.6
	speed = move_toward(speed,0.0,float(knobs.roll_drag)*delta)
	var step := speed*delta
	if field.blocked(position+Vector3.UP*d*0.5,Vector3(way.x,0.0,way.y)*(d*0.5+absf(step)+0.05),rid):
		_say("wheel_thud")
		_puff()
		speed = -speed*float(knobs.bounce)
		step = 0.0
	position += Vector3(fwd.x,0.0,fwd.y)*step
	spin += step/(d*0.5)
	_wheel.rotation.x = -spin
	var g0: float = field.floor_under(position,float(knobs.step_up),float(knobs.step_up),rid)
	if g0 == -INF:
		# Over a lip: a gap it can't drop through, or the drop.
		if _try_jam(Vector2(way.x,way.y)): return
		grounded = false
		state = "fall"
		state_t = 0.0
		_fallen_from = position.y
		vel = Vector3(way.x,0.0,way.y)*absf(speed)
		return
	position.y = g0
	if absf(speed) < float(knobs.topple_speed):
		state = "topple"
		state_t = 0.0
		_tip_side = 1.0 if hash(position) % 2 == 0 else -1.0
		_tip_v = 0.0

## Ground again across the gap within `jam` of its diameter: it drops in
## and jams, its top `flush` over the lip; true if it did.
func _try_jam(way: Vector2) -> bool:
	var rid := body.get_rid()
	var lip_y := position.y
	# The near lip: just behind its middle.
	var back := 0.0
	while back < d*0.6 and field.floor_under(position-Vector3(way.x,0.0,way.y)*back,0.3,0.6,rid) == -INF: back += 0.05
	if back >= d*0.6: return false
	var across := 0.05
	var most := d*float(knobs.jam)
	while across < most:
		var g: float = field.floor_under(position+Vector3(way.x,0.0,way.y)*across,0.6,0.8,rid)
		if g != -INF and absf(g-lip_y) < 0.6: break
		across += 0.05
	if across >= most: return false
	var gap := across+back
	position += Vector3(way.x,0.0,way.y)*(across-back)*0.5
	# Its top over the lip by `flush` (ground down into the gap).
	position.y = lip_y+float(knobs.flush)-d
	state = "jammed"
	state_t = 0.0
	speed = 0.0
	_jam_box(gap)
	_say("wheel_jam")
	_puff()
	return true

## Jammed: its body a plug the width of the gap and a little more, his
## walk over its top.
func _jam_box(gap: float) -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(t+0.3,d,maxf(gap+0.3,d*0.6))
	_collider.shape = box
	_collider.position.y = d*0.5
	width = t+0.3
	length = maxf(gap+0.3,d*0.6)

func _fall(delta: float) -> void:
	var rid := body.get_rid()
	vel.y -= float(knobs.gravity)*delta
	var was_y := position.y
	position += vel*delta
	spin += Vector2(vel.x,vel.z).length()*delta/(d*0.5)
	_wheel.rotation.x = -spin
	# Tumbling a little as it goes.
	skin.rotation.z = lerpf(skin.rotation.z,0.35*sin(state_t*3.0),1.0-exp(-3.0*delta))
	if vel.y <= 0.0:
		var g: float = field.floor_under(position,was_y-position.y+0.05,0.05,rid)
		if g != -INF:
			position.y = g
			skin.rotation.z = 0.0
			var drop := _fallen_from-g
			_say("wheel_crash" if drop > 4.0 else "wheel_thud")
			_puff()
			if -vel.y > 6.0 and drop > 1.0:
				# A hard landing bounces once.
				vel.y = -vel.y*0.25
				position.y += 0.02
				_fallen_from = position.y
				return
			grounded = true
			state = "roll"
			state_t = 0.0
			speed = Vector2(vel.x,vel.z).length()*0.6
			var flat := Vector2(vel.x,vel.z)
			if flat.length() > 0.1:
				facing = PilotMotor.facing_of(flat)
				rotation.y = facing
			vel = Vector3.ZERO
	if position.y < field.lost:
		gone = true
		field.gone_count += 1
		fell.emit(self)
		queue_free()

## Wobbling as a coin does, then down flat on a face.
func _topple(delta: float) -> void:
	# A slow lean first (the wobble), then over it goes.
	_tip_v += (0.6+_tip*14.0)*delta
	_tip = minf(_tip+_tip_v*delta,PI*0.5)
	var a := _tip+sin(state_t*16.0)*0.06*(1.0-_tip/(PI*0.5))
	_lie(a)
	if _tip >= PI*0.5:
		state = "flat"
		state_t = 0.0
		_lie(PI*0.5)
		var box := BoxShape3D.new()
		box.size = Vector3(d,t,d)
		_collider.shape = box
		_collider.position.y = t*0.5
		width = d
		height = t
		length = d
		_say("wheel_thud")
		_puff()

## Tipped `a` (rad) onto its `_tip_side` face, its middle eased down from
## its radius to a half thickness over the spot it stood.
func _lie(a: float) -> void:
	var r := d*0.5
	skin.rotation.z = a*_tip_side
	skin.position = Vector3(_tip_side*r*sin(a),lerpf(r,t*0.5,1.0-cos(a))-r*cos(a),0.0)

# --- Contact ---------------------------------------------------------------------

## Rolling fast, it crushes him (his feet under `hop` of it): a hard knock
## on along its way, a heart.
func touch(m: PilotMotor, v_pre: Vector3) -> void:
	if gone or _cool > 0.0 or m.on_ledge(): return
	if not harmful():
		if state == "roll": return
		super.touch(m,v_pre)
		return
	if m.seized() or (m.recovering() and not m.stunnable(self)): return
	var local := Basis(Vector3.UP,facing).inverse()*(m.feet-position)
	var r := float(knobs.radius)
	if absf(local.x) > t*0.5+r or absf(local.z) > d*0.5+r: return
	if m.feet.y-position.y >= d*float(knobs.hop) or m.feet.y < position.y-0.5: return
	hits_pilot(m)

func hits_pilot(m: PilotMotor) -> void:
	var f := PilotMotor.forward(facing)*signf(speed)
	m.knock(m.knock_velocity(f,float(knobs.shove_out),float(knobs.shove_up)),self,float(knobs.down))
	m.harm(harm_cause(),1,self)
	_cool = 0.6
	hit_pilot.emit(self)
	speed *= 0.7

## Too heavy for him to throw.
func pilot_pushes(m: PilotMotor, _way: Vector2, _speed: float) -> void:
	m.velocity.x *= 0.2
	m.velocity.z *= 0.2
	_cool = 0.3
