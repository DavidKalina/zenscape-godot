extends "res://scripts/enemies/headless_body.gd"
## The Olmec as a lock-on target (studies/olmec_field.gd): the headless body
## (scripts/enemies/headless_body.gd) as it is everywhere, plus what the
## lock and the gust shot ask of a target (scripts/lock_on/foot_lock.gd,
## gust_shot.gd): in "lock_targets", `aim_point` his chest, `tall` his top
## (the marker over his head), and `hit(at, way, strength)`:
##   - he rocks back on his feet away from the blow (a damped spring on his
##     skin about his feet, as the target stone rocks), slides back
##     PUSH m x strength along it, the camera quakes, dust bursts where it
##     struck and round his feet;
##   - walking, chasing or looking about, he is stopped for a beat (his
##     heavy "land" squash, `knobs.land` s), then comes on again.
## After HITS hits he crumbles (`crumble`): his figure and his head go, a
## heap of weathered blocks tumbles out where he stood. Only this study
## spawns him; the body elsewhere is untouched.

const RuinKit = preload("res://scripts/ruin_kit.gd")

const GROUP := &"lock_targets"
## His lock reach (m, acquire and release): he towers, so the lock
## takes him from across the field (scripts/lock_on/foot_lock.gd).
const REACH := Vector2(48.0,58.0)
## Hits to bring him down.
const HITS := 6
## The rock: kick (rad/s per unit strength), spring, damping, most tip (rad).
const KICK := 0.9
const SPRING := 38.0
const DAMP := 4.5
const MOST_TIP := 0.22
## The slide back (m at strength 1), eased out over about PUSH_EASE s.
const PUSH := 1.6
const PUSH_EASE := 0.3
## States a hit stops him in (the rest, climbing, leaping, sucking, he
## rides out).
const STOPPABLE := ["listen","roam","home","chase","alert","seek","return","spent","swat"]
## The rubble: blocks, their size (head heights), how long they tumble
## before they settle for good (s).
const RUBBLE := 16
const RUBBLE_SIZE := Vector2(0.35,0.8)
const RUBBLE_SETTLE := 7.0

var hits := 0
var crumbled := false
var _tip := 0.0
var _tip_v := 0.0
var _tip_axis := Vector3.RIGHT
var _push := Vector3.ZERO
var _rubble: Array[RigidBody3D] = []
var _rubble_t := 0.0
var _hit_rng := RandomNumberGenerator.new()

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	add_to_group(GROUP)
	_hit_rng.seed = 77

## His chest: halfway up his torso.
func aim_point() -> Vector3:
	return global_position+Vector3.UP*(legs_h+torso_h*0.55)

func lock_reach() -> Vector2:
	return REACH

## His top: over his head when whole, his stump's cut when not.
func tall() -> float:
	return neck_h+(hh*1.1 if whole else 0.0)

func hit(at: Vector3, way: Vector3, strength := 1.0) -> void:
	if crumbled or gone: return
	hits += 1
	var flat := Vector3(way.x,0.0,way.z)
	if flat.length() < 0.01: flat = global_position-at
	flat.y = 0.0
	flat = flat.normalized() if flat.length() > 0.01 else -_forward3()
	# Rock back away from the blow, about the axis across it (his skin's frame).
	var axis_world := Vector3.UP.cross(flat).normalized()
	var axis_local := (global_transform.basis.inverse()*axis_world).normalized()
	_tip = _tip*signf(_tip_axis.dot(axis_local)) if absf(_tip) > 0.001 else 0.0
	_tip_v = _tip_v*signf(_tip_axis.dot(axis_local))
	_tip_axis = axis_local
	_tip_v += KICK*strength
	_push += flat*PUSH*strength/PUSH_EASE
	stagger(1.0)
	quake = maxf(quake,0.45)
	if grounded and state in STOPPABLE: _go("land")
	_puff(at-Vector3.UP*0.2,hh*0.9)
	_puff(global_position,hh*1.6)
	field.sound(&"body_land",global_position)
	print("olmec target: hit %d/%d at (%.1f, %.1f, %.1f), strength %.2f, now %s" % [hits,HITS,at.x,at.y,at.z,strength,state])
	if hits >= HITS: crumble()

func step(delta: float) -> void:
	if crumbled:
		_settle_rubble(delta)
		return
	super.step(delta)
	if gone: return
	# The slide back, eased out.
	if _push.length() > 0.01:
		var k := 1.0-exp(-delta/PUSH_EASE)
		var d := _push*PUSH_EASE*k
		position += Vector3(d.x,0.0,d.z)
		_push *= 1.0-k
		body.force_update_transform()
	# The rock about his feet.
	if absf(_tip) > 0.0001 or absf(_tip_v) > 0.0001:
		_tip_v += (-SPRING*_tip-DAMP*_tip_v)*delta
		_tip += _tip_v*delta
		if absf(_tip) > MOST_TIP:
			_tip = signf(_tip)*MOST_TIP
			_tip_v *= -0.3
		if grounded: skin.transform = Transform3D(Basis(_tip_axis,_tip),Vector3.ZERO)
	elif _tip != 0.0:
		_tip = 0.0
		_tip_v = 0.0
		if grounded: skin.transform = Transform3D.IDENTITY

## Brought down: the figure and its head gone, a heap of blocks in its place.
func crumble() -> void:
	if crumbled: return
	crumbled = true
	remove_from_group(GROUP)
	skin.visible = false
	body.collision_layer = 0
	body.collision_mask = 0
	if head != null and is_instance_valid(head):
		head.visible = false
		var hb: StaticBody3D = head.get("body")
		if hb != null: hb.collision_layer = 0
		head.set("gone",true)
	quake = 1.0
	_puff(global_position,hh*3.0)
	field.sound(&"body_land",global_position)
	for i in range(RUBBLE):
		# Piled up his height, most at his legs and torso.
		var up := (neck_h+hh)*pow(_hit_rng.randf(),0.8)
		var a := _hit_rng.randf()*TAU
		var r := width*0.35*_hit_rng.randf()
		var at := global_position+Vector3(cos(a)*r,up,sin(a)*r)
		var s := Vector3(_hit_rng.randf_range(RUBBLE_SIZE.x,RUBBLE_SIZE.y),_hit_rng.randf_range(RUBBLE_SIZE.x,RUBBLE_SIZE.y),_hit_rng.randf_range(RUBBLE_SIZE.x,RUBBLE_SIZE.y))*hh
		if i == 0: s = Vector3.ONE*hh*0.95 # the head, the biggest stone
		_rubble.append(_block(at,s,Vector3(cos(a),0.6,sin(a))*_hit_rng.randf_range(2.0,5.0),71+i))
	print("olmec target: crumbled after %d hits" % hits)

func _block(at: Vector3, s: Vector3, v: Vector3, seed_value: int) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.name = "Rubble"
	rb.mass = s.x*s.y*s.z*2.4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = s*0.92
	shape.shape = box
	rb.add_child(shape)
	var b := RuinKit.Build.new(seed_value,0.7,"Rubble")
	b.ground = -s.y*0.5
	RuinKit._sarsen(b,Transform3D(Basis.IDENTITY,Vector3(0.0,-s.y*0.5,0.0)),s,0.2)
	var built: Node3D = b.finish()
	for sb: Node in built.find_children("*","CollisionObject3D",true,false):
		sb.get_parent().remove_child(sb)
		sb.queue_free()
	rb.add_child(built)
	field.add_child(rb)
	rb.global_position = at
	rb.rotation = Vector3(_hit_rng.randf_range(-0.4,0.4),_hit_rng.randf()*TAU,_hit_rng.randf_range(-0.4,0.4))
	rb.linear_velocity = v
	rb.angular_velocity = Vector3(_hit_rng.randf_range(-2,2),_hit_rng.randf_range(-2,2),_hit_rng.randf_range(-2,2))
	return rb

func _settle_rubble(delta: float) -> void:
	_rubble_t += delta
	quake = maxf(0.0,quake-delta*1.2)
	if _rubble_t < RUBBLE_SETTLE: return
	for rb: RigidBody3D in _rubble:
		if is_instance_valid(rb) and not rb.freeze: rb.freeze = true

func _exit_tree() -> void:
	super._exit_tree()
	for rb: RigidBody3D in _rubble:
		if is_instance_valid(rb): rb.queue_free()
	_rubble.clear()
