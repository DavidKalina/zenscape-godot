extends Node3D
## The cannon (docs/design/roguelike/cannon-round1.md): a greybox barrel on a
## base. It takes one keg (`load_keg`), and with the pilot inside (the
## field, scripts/cannon/cannon_field.gd, boards him) he aims it with the
## stick and fires: the pilot is the cannonball, launched along the barrel
## at a speed from the keg's size. One keg is one shot; an empty cannon only
## clicks. Every number is in `knobs`, sized from the pilot (`unit` is the
## walker's half second of walking, 1.2 m at the knobs).
##
## The cannon's own frame: origin on the ground at the base's middle, the
## rest aim along -z (turn the node to turn the rest heading). `aim_yaw` is
## the aim turned off that heading (radians, PilotMotor.forward's
## convention, within `yaw_limit`); `pitch` is up from level within
## `pitch_min`..`pitch_max`.
const WorldScale = preload("res://scripts/world_scale.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

const BASE := Color(0.5,0.5,0.52)
const BARREL := Color(0.3,0.3,0.34)
const FLASH := Color(0.96,0.55,0.16)

signal sounded(kind: StringName, at: Vector3)

var knobs: Dictionary = {}
## The keg inside ("" none, else its kind).
var loaded := ""
var aim_yaw := 0.0
var pitch := 0.0
var shots := 0
var heard: Array = []
var _barrel: Node3D
var _paint: StandardMaterial3D
var _flash := 0.0
var _dots: Array[MeshInstance3D] = []

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
		# Launch speed per keg kind, in runs (the pilot's top pace): range
		# goes with the square, so a big shot goes about twice a small one.
		"speed_small":p.run*3.8,
		"speed_big":p.run*5.4,
		"yaw_limit":deg_to_rad(70.0),
		"pitch_min":deg_to_rad(15.0),
		"pitch_max":deg_to_rad(75.0),
		"pitch_rest":deg_to_rad(40.0),
		"yaw_rate":1.2,                # rad/s on a full stick
		"pitch_rate":0.9,
		"enter_reach":unit*2.4,        # from the base's middle: load and climb in
		"preview_dots":9,
		"preview_time":0.75,           # s of the flight shown (the first part)
		"flash_time":0.25,
	}

func _init() -> void:
	knobs = defaults()
	pitch = float(knobs.pitch_rest)

func configure(over: Dictionary) -> Node3D:
	knobs.merge(over,true)
	pitch = float(knobs.pitch_rest)
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

func speed_of(kind: String) -> float:
	return float(knobs["speed_"+kind])

## The launch velocity the loaded keg gives (zero when empty).
func launch_velocity() -> Vector3:
	if loaded == "": return Vector3.ZERO
	return direction()*speed_of(loaded)

func set_aim(new_yaw: float, new_pitch: float) -> void:
	aim_yaw = clampf(new_yaw,-float(knobs.yaw_limit),float(knobs.yaw_limit))
	pitch = clampf(new_pitch,float(knobs.pitch_min),float(knobs.pitch_max))
	_pose()

## A keg of `kind` put in (false if one is in).
func load_keg(kind: String) -> bool:
	if loaded != "": return false
	loaded = kind
	_sound(&"fuse",pivot())
	return true

## Fired: the shot's launch velocity (and the keg spent), or zero with a dry
## click when empty.
func fire() -> Vector3:
	if loaded == "":
		_sound(&"click",pivot())
		return Vector3.ZERO
	var v := launch_velocity()
	loaded = ""
	shots += 1
	_flash = float(knobs.flash_time)
	_sound(&"boom",mouth())
	return v

func reset() -> void:
	loaded = ""
	shots = 0
	aim_yaw = 0.0
	pitch = float(knobs.pitch_rest)
	_flash = 0.0
	heard.clear()
	_pose()
	show_preview([])

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

## How far (m, across) a shot of `speed` at `pitch_angle` flies from a mouth
## `above` m over the landing, over a flat floor.
static func reach(speed: float, pitch_angle: float, above: float) -> float:
	var v := Vector3(cos(pitch_angle),sin(pitch_angle),0.0)*speed
	var pts := flight(Vector3(0.0,above,0.0),v,pilot(),1.0/240.0,30.0,0.0)
	return pts[pts.size()-1].x

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
	for i in int(knobs.preview_dots):
		var d := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = float(knobs.unit)*0.06
		s.height = s.radius*2.0
		d.mesh = s
		d.material_override = _mat(FLASH)
		d.top_level = true
		d.visible = false
		add_child(d)
		_dots.append(d)
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

## The dotted arc of the first part of the loaded keg's flight from the
## mouth (none when empty).
func preview(p: PilotMotor) -> void:
	if loaded == "":
		show_preview([])
		return
	var n := int(knobs.preview_dots)
	var dt := float(knobs.preview_time)/float(n)
	var pts := flight(mouth(),launch_velocity(),p,dt,float(knobs.preview_time))
	show_preview(pts.slice(1))

func show_preview(pts: Array) -> void:
	for i in _dots.size():
		_dots[i].visible = i < pts.size()
		if i < pts.size(): _dots[i].global_position = pts[i]
