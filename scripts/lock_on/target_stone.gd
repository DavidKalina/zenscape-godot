extends Node3D
## The lock-on target (docs/design/lock-on/spec-lock-on.md): a squat
## weathered standing stone on the turf, a RuinKit sarsen sized from the
## wanderer (scripts/world_scale.gd through DragonAirBlast `walker_tall`),
## colliding as built. It answers a hit (`hit`): it rocks back on its foot
## away from the blow and settles (a damped spring), a puff of grit and dust
## bursts where it was struck and a skirt of dust at its foot, and a knock.
## In the group "lock_targets"; `aim_point` is where a shot aims.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const DragonGale = preload("res://scripts/dragon_gale.gd")

const GROUP := &"lock_targets"
## Its size in walker heights (1.12 m at --wanderer-scale=1): a little over
## his height, about half as broad, a third as deep.
const TALL := 1.35
const BROAD := 0.62
const DEEP := 0.42
## The rock on a hit: the kick (rad/s per unit strength), the spring
## (rad/s², per rad) and its damping (1/s); the most it tips (rad).
const KICK := 3.0
const SPRING := 140.0
const DAMP := 5.5
const MOST_TIP := 0.32
## The dust: puffs at the blow and round the foot, their life (s).
const BLOW_PUFFS := 10
const FOOT_PUFFS := 8
const PUFF_LIFE := Vector2(0.55,1.1)
const DUST := Color(0.5,0.42,0.31)
const KNOCKS := ["res://assets/audio/foley/hammer-rock-1.wav","res://assets/audio/foley/hammer-rock-2.wav","res://assets/audio/foley/hammer-rock-3.wav"]

## Hits taken, for checks.
var hits := 0
var _tip := 0.0
var _tip_v := 0.0
var _axis := Vector3.RIGHT
var _rocker: Node3D
var _puffs: MultiMeshInstance3D
var _free: Array = []
var _rng := RandomNumberGenerator.new()
var _knock: AudioStreamPlayer3D

static func tall() -> float:
	return TALL*DragonAirBlast.walker_tall()

## Builds one standing at `at` (the turf under its middle), turned `yaw`.
static func make(at: Vector3, yaw: float, seed_value := 41) -> Node3D:
	var stone: Node3D = load("res://scripts/lock_on/target_stone.gd").new()
	stone.name = "TargetStone"
	stone.position = at
	stone.rotation.y = yaw
	stone._build(seed_value)
	return stone

func _build(seed_value: int) -> void:
	_rng.seed = seed_value
	add_to_group(GROUP)
	var w := DragonAirBlast.walker_tall()
	var b := RuinKit.Build.new(seed_value,0.55,"Sarsen")
	b.ground = 0.0
	RuinKit._sarsen(b,Transform3D.IDENTITY,Vector3(BROAD,TALL,DEEP)*w,0.12)
	# The rocker: the stone tips about its foot, collision and all.
	_rocker = Node3D.new()
	_rocker.name = "Rocker"
	add_child(_rocker)
	_rocker.add_child(b.finish())
	_puffs = MultiMeshInstance3D.new()
	_puffs.name = "Dust"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = DragonGale._puff_mesh()
	mm.instance_count = BLOW_PUFFS+FOOT_PUFFS
	mm.visible_instance_count = 0
	_puffs.multimesh = mm
	_puffs.top_level = true
	_puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puffs.extra_cull_margin = 50.0
	add_child(_puffs)
	_knock = AudioStreamPlayer3D.new()
	_knock.name = "Knock"
	_knock.unit_size = 6.0
	_knock.position = Vector3.UP*tall()*0.6
	add_child(_knock)

## Where a shot aims: the stone's middle, a little over half up.
func aim_point() -> Vector3:
	return global_position+Vector3.UP*tall()*0.55

## Struck at `at` (world) by something travelling `way`, `strength` 1 a
## full gust ball: it rocks away from the blow, dust bursts, a knock.
func hit(at: Vector3, way: Vector3, strength := 1.0) -> void:
	hits += 1
	var flat := Vector3(way.x,0.0,way.z)
	if flat.length() < 0.01: flat = global_position-at
	flat.y = 0.0
	if flat.length() < 0.01: flat = Vector3.FORWARD
	flat = flat.normalized()
	# Tipping away from the blow: about the axis across it, in the stone's frame.
	var axis_world := Vector3.UP.cross(flat).normalized()
	var axis_local := global_transform.basis.inverse()*axis_world
	# A new blow: carry the swing it has into the new axis's sense.
	_tip = _tip*signf(_axis.dot(axis_local)) if absf(_tip) > 0.001 else 0.0
	_tip_v = _tip_v*signf(_axis.dot(axis_local))
	_axis = axis_local.normalized()
	_tip_v += KICK*strength
	var r := DragonAirBlast.walker_tall()
	for i in range(BLOW_PUFFS):
		var d := (-flat*0.6+Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.3,1.0),_rng.randf_range(-1,1))).normalized()
		var size := _rng.randf_range(0.18,0.32)*r
		_puff(at,d*_rng.randf_range(1.5,3.5),size,size*_rng.randf_range(1.8,2.4))
	for i in range(FOOT_PUFFS):
		var a := TAU*float(i)/float(FOOT_PUFFS)+_rng.randf()*0.6
		var out := Vector3(cos(a),0.0,sin(a))
		var size := _rng.randf_range(0.15,0.25)*r
		_puff(global_position+out*BROAD*r*0.5+Vector3.UP*0.08,out*_rng.randf_range(0.8,1.8)+Vector3.UP*0.2,size,size*2.2)
	if _knock.is_inside_tree():
		_knock.stream = load(KNOCKS[_rng.randi()%KNOCKS.size()])
		_knock.pitch_scale = _rng.randf_range(0.8,0.95)
		_knock.volume_db = linear_to_db(clampf(strength,0.2,1.0))
		_knock.play()

func _puff(p: Vector3, v: Vector3, size: float, grow: float) -> void:
	if _free.size() >= BLOW_PUFFS+FOOT_PUFFS: _free.pop_front()
	_free.append({"p":p,"v":v,"size":size,"grow":grow,"age":0.0,"life":_rng.randf_range(PUFF_LIFE.x,PUFF_LIFE.y)})

## The tip's angle now (rad), for checks.
func tip() -> float:
	return _tip

func _process(delta: float) -> void:
	# The rock: a damped spring about the foot, held under MOST_TIP.
	if absf(_tip) > 0.0001 or absf(_tip_v) > 0.0001:
		_tip_v += (-SPRING*_tip-DAMP*_tip_v)*delta
		_tip += _tip_v*delta
		if absf(_tip) > MOST_TIP:
			_tip = signf(_tip)*MOST_TIP
			_tip_v *= -0.3
		_rocker.transform = Transform3D(Basis(_axis,_tip),Vector3.ZERO)
	else:
		_tip = 0.0
		_tip_v = 0.0
	_draw_dust(delta)

func _draw_dust(delta: float) -> void:
	var mm := _puffs.multimesh
	var i := 0
	var kept: Array = []
	for s: Dictionary in _free:
		s.age = float(s.age)+delta
		if float(s.age) >= float(s.life): continue
		s.v = (s.v as Vector3)*(1.0-minf(0.95,3.0*delta))+Vector3.UP*0.4*delta
		s.p = (s.p as Vector3)+(s.v as Vector3)*delta
		var u := float(s.age)/float(s.life)
		var size := lerpf(float(s.size),float(s.grow),1.0-pow(1.0-u,2.0))
		var fade := smoothstep(0.0,0.08,u)*(1.0-smoothstep(0.25,1.0,u))*0.5
		mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*size),s.p))
		mm.set_instance_custom_data(i,Color(fade,0,0,0))
		mm.set_instance_color(i,DUST)
		i += 1
		kept.append(s)
	_free = kept
	mm.visible_instance_count = i
