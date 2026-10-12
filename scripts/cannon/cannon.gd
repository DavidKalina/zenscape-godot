extends Node3D
## The cannon (docs/design/roguelike/cannon-round1.md): a greybox barrel on a
## base. Worked from outside (the field, scripts/cannon/cannon_field.gd): aim
## it (yaw and pitch with the stick, power in notches) and fire powder kegs
## as ranging shots; each flies exactly the arc you would (same launch
## velocity), and the mark where it lands is where you will, at that aim and
## power. Then climb in and fire YOURSELF: free, always usable. There is no
## arc preview; reading the keg's flight is the skill.
## Every number is in `knobs`, sized from the pilot (`unit` is the walker's
## half second of walking, 1.2 m at the knobs).
##
## The cannon's own frame: origin on the ground at the base's middle, the
## rest aim along -z (turn the node to turn the rest heading). `aim_yaw` is
## the aim turned off that heading (radians, PilotMotor.forward's
## convention, within `yaw_limit`); `pitch` is up from level within
## `pitch_min`..`pitch_max`; `power` indexes `power_notches`.
const WorldScale = preload("res://scripts/world_scale.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

const BASE := Color(0.5,0.5,0.52)
const BARREL := Color(0.3,0.3,0.34)
const FLASH := Color(0.96,0.55,0.16)

signal sounded(kind: StringName, at: Vector3)

var knobs: Dictionary = {}
var power := 0
## The keg in the barrel (a Keg node), or null.
var loaded: Node3D = null
var aim_yaw := 0.0
var pitch := 0.0
var shots := 0
var heard: Array = []
var _barrel: Node3D
var _paint: StandardMaterial3D
var _flash := 0.0

static func pilot() -> PilotMotor:
	var p := PilotMotor.new()
	p.set_size(WorldScale.wanderer)
	return p

## The knobs, from the pilot's numbers.
static func defaults() -> Dictionary:
	var p := pilot()
	var unit: float = p.walk*0.5
	return {
		"unit":unit,
		"base_height":unit*0.75,       # the base the barrel sits on (m)
		"base_width":unit*1.6,
		"barrel_radius":unit*0.45,
		"barrel_length":unit*2.2,
		# Launch speed at full power, in runs (the pilot's top pace), and the
		# notches (shares of it); range goes with the square of the speed.
		"speed_max":p.run*5.4,
		"power_notches":[0.5,0.62,0.75,0.87,1.0],
		"power_rest":2,
		"yaw_limit":deg_to_rad(70.0),
		"pitch_min":deg_to_rad(15.0),
		"pitch_max":deg_to_rad(75.0),
		"pitch_rest":deg_to_rad(40.0),
		"yaw_rate":1.2,                # rad/s on a full stick
		"pitch_rate":0.9,
		"enter_reach":unit*2.4,        # from the base's middle: operate or climb in
		"stand_back":unit*1.35,        # from the base's middle: where he stands to operate it
		"flash_time":0.25,
	}

func _init() -> void:
	knobs = defaults()
	pitch = float(knobs.pitch_rest)
	power = int(knobs.power_rest)

func configure(over: Dictionary) -> Node3D:
	knobs.merge(over,true)
	pitch = float(knobs.pitch_rest)
	power = int(knobs.power_rest)
	return self

## The aim's yaw in the world.
func yaw() -> float:
	return rotation.y+aim_yaw

func direction() -> Vector3:
	var f := PilotMotor.forward(yaw())
	return Vector3(f.x*cos(pitch),sin(pitch),f.y*cos(pitch))

## The barrel's pivot and mouth in the world.
func pivot() -> Vector3:
	return global_position+Vector3.UP*float(knobs.base_height)

func mouth() -> Vector3:
	return pivot()+direction()*float(knobs.barrel_length)

## The launch speed at the power set.
func speed() -> float:
	return float(knobs.speed_max)*float(knobs.power_notches[power])

## The launch velocity at this aim and power: the pilot's, and a keg's.
func launch_velocity() -> Vector3:
	return direction()*speed()

func set_aim(new_yaw: float, new_pitch: float) -> void:
	aim_yaw = clampf(new_yaw,-float(knobs.yaw_limit),float(knobs.yaw_limit))
	pitch = clampf(new_pitch,float(knobs.pitch_min),float(knobs.pitch_max))
	_pose()

func set_power(index: int) -> void:
	power = clampi(index,0,knobs.power_notches.size()-1)

## Fired (the pilot or a keg): the launch velocity, with the boom.
func fire() -> Vector3:
	shots += 1
	_flash = float(knobs.flash_time)
	_sound(&"boom",mouth())
	return launch_velocity()

func click() -> void:
	_sound(&"click",pivot())

func reset() -> void:
	loaded = null
	shots = 0
	aim_yaw = 0.0
	pitch = float(knobs.pitch_rest)
	power = int(knobs.power_rest)
	_flash = 0.0
	heard.clear()
	_pose()

func _sound(kind: StringName, at: Vector3) -> void:
	heard.append([kind,at])
	sounded.emit(kind,at)

## The flight from `from` at `v` (m/s) under the pilot's gravity (rising
## `gravity`, falling `fall` times as hard, to `terminal`), points `dt`
## apart until `t_max` s or it falls to `floor_y`. The last point is the
## touch when it came down.
static func flight(from: Vector3, v: Vector3, p: PilotMotor, dt: float, t_max: float, floor_y := -INF) -> Array[Vector3]:
	var pts: Array[Vector3] = [from]
	var at := from
	var vel := v
	var t := 0.0
	while t < t_max:
		var g := p.gravity if vel.y > 0.0 else p.gravity*p.fall
		var nv := Vector3(vel.x,maxf(vel.y-g*dt,-p.terminal),vel.z)
		var nat := at+(vel+nv)*0.5*dt
		t += dt
		if nat.y <= floor_y and vel.y <= 0.0:
			var k := (at.y-floor_y)/maxf(at.y-nat.y,1e-6)
			pts.append(at.lerp(nat,clampf(k,0.0,1.0)))
			return pts
		at = nat
		vel = nv
		pts.append(at)
	return pts

## Where a shot from `from` at `v` comes down on flat ground at `floor_y`.
static func landing(from: Vector3, v: Vector3, floor_y: float) -> Vector3:
	var pts := flight(from,v,pilot(),1.0/240.0,30.0,floor_y)
	return pts[pts.size()-1]

## Where a default cannon standing at `base` (rest heading -z) would land a
## shot at `shot_yaw`, `shot_pitch`, power notch `notch`, on flat ground at
## `floor_y`. For placing a yard's targets.
static func landing_for(base: Vector3, shot_yaw: float, shot_pitch: float, notch: int, floor_y: float) -> Vector3:
	var k := defaults()
	var f := PilotMotor.forward(shot_yaw)
	var dir := Vector3(f.x*cos(shot_pitch),sin(shot_pitch),f.y*cos(shot_pitch))
	var from: Vector3 = base+Vector3.UP*float(k.base_height)+dir*float(k.barrel_length)
	return landing(from,dir*float(k.speed_max)*float(k.power_notches[notch]),floor_y)

func _ready() -> void:
	var w := float(knobs.base_width)
	var h := float(knobs.base_height)
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w,h,w)
	base.mesh = box
	base.material_override = _mat(BASE)
	base.position.y = h*0.5
	add_child(base)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	shape.shape = bs
	body.add_child(shape)
	body.position.y = h*0.5
	add_child(body)
	_barrel = Node3D.new()
	_barrel.position.y = h
	add_child(_barrel)
	var tube := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = float(knobs.barrel_radius)
	cyl.bottom_radius = float(knobs.barrel_radius)*1.15
	cyl.height = float(knobs.barrel_length)
	cyl.radial_segments = 16
	tube.mesh = cyl
	_paint = _mat(BARREL)
	tube.material_override = _paint
	# The cylinder stands along y: laid along -z, its middle half out.
	tube.rotation.x = -PI*0.5
	tube.position.z = -float(knobs.barrel_length)*0.5
	_barrel.add_child(tube)
	_pose()

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func _pose() -> void:
	if _barrel == null: return
	_barrel.rotation = Vector3(pitch,aim_yaw,0.0)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0,_flash-delta)
		if _paint != null: _paint.albedo_color = BARREL.lerp(FLASH,_flash/float(knobs.flash_time))
