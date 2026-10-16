extends "res://scripts/traps/trap.gd"
## The stun yard's kicker (studies/stun_yard.gd): a greybox plate that, stood
## on for `fuse` s (it warms
## to orange), knocks the pilot (PilotMotor.knock, itself the source) onto
## whatever `aim` is (the Sky Ray's body, live), peaking `up` m over the
## plate, landing on the aim's middle. A test fixture for the chain (a knock
## onto the ray, a seesaw below), not a trap for runs. Re-arms `rearm` s on.
const PLATE := Color(0.3,0.3,0.34)

## What it throws him at (its global position is the landing's middle).
var aim: Node3D
var kicks := 0
var _fuse := 0.0
var _cool := 0.0
var _mat: StandardMaterial3D

func _init() -> void:
	super()
	trap_name = "kicker"
	cost = 1

func defaults() -> Dictionary:
	var p := pilot()
	return {"fuse":0.5,"up":float(p.jumps[0])*1.5,"size":p.run*0.35,"rearm":2.0,"past":1.0}

func build() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	var s := float(knob("size"))
	box.size = Vector3(s,0.04,s)
	mesh.mesh = box
	mesh.position.y = 0.02
	_mat = paint(PLATE)
	mesh.material_override = _mat
	add_child(mesh)

## Is `feet` (world) on the plate?
func on_plate(feet: Vector3) -> bool:
	var l := to_local(feet)
	var h := float(knob("size"))*0.5
	return absf(l.x) <= h and absf(l.z) <= h and absf(l.y) < 0.3

func after(delta: float, _events: Dictionary) -> void:
	if motor == null: return
	_cool = maxf(0.0,_cool-delta)
	if _cool <= 0.0 and motor.grounded and motor.move != "tumble" and on_plate(motor.feet):
		_fuse += delta
		if _fuse >= float(knob("fuse")): _kick()
	else: _fuse = 0.0
	tell_sight(clampf(_fuse/float(knob("fuse")),0.0,1.0) if _cool <= 0.0 else 0.0)

func _kick() -> void:
	_fuse = 0.0
	_cool = float(knob("rearm"))
	kicks += 1
	var to := aim.global_position if aim != null else global_position+global_transform.basis*Vector3(4.0,0.0,0.0)
	var flat := Vector2(to.x-motor.feet.x,to.z-motor.feet.z)
	var out := flat.length()+float(knob("past"))
	motor.knock(motor.knock_velocity(flat.normalized(),out,float(knob("up")),motor.feet.y-to.y),self)
	tell_sound(&"kick",motor.feet)

func tell_sight(amount: float) -> void:
	if _mat != null: _mat.albedo_color = PLATE.lerp(TELL,amount)

func reset() -> void:
	super()
	_fuse = 0.0
	_cool = 0.0
	kicks = 0
	tell_sight(0.0)
