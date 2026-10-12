extends "res://studies/character_study.gd"
## The cannon yard (docs/design/roguelike/cannon-round1.md): a start isle with
## a cannon and three powder kegs (two small, one big), a near isle at a
## small shot's range with a second cannon and no keg, and a far isle at a
## big shot's range. Open drops between. The isles are placed from the
## shots' flight at the cannons' rest aim (Cannon.reach), so they follow the
## knobs. This extends the character study (motor, figure, camera, F1
## numbers, F2 feel); a CannonField (scripts/cannon/cannon_field.gd) fills
## its `foot_pieces` slot.
##   touch a keg  picked up, hovers behind you (no penalty)
##   near a cannon with kegs  one is loaded (the big one; crouch for a small)
##   E (pad X)  climb in / out · stick aims · Space (pad A) fires
## `--cannon=small|big|both` starts by the cannon with those kegs already
## hovering. R resets (kegs back, cannons empty).
##   godot --path . res://studies/cannon_yard.tscn -- --no-title --cannon=big
const CannonField = preload("res://scripts/cannon/cannon_field.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")

const START_ISLE := Rect2(-8.0,-7.0,16.0,20.0)
const NEAR_WIDE := 10.0
const FAR_WIDE := 14.0
const FAR_DEPTH := 14.0
const DROP := 24.0
const CANNON_AT := Vector3(0.0,0.0,-3.0)

var cannon_field: Node3D
var carry_at_start := ""
var near_centre := Vector3.ZERO
var far_centre := Vector3.ZERO
var cannon_b_at := Vector3.ZERO

func _ready() -> void:
	pack = "cannon_yard"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--cannon="): carry_at_start = arg.get_slice("=",1)
	super._ready()

## Where a shot of `kind` from a cannon at `at` (rest aim) comes down, on z.
static func landing_z(at: Vector3, kind: String) -> float:
	var k := Cannon.defaults()
	var pitch_rest: float = k.pitch_rest
	var mouth_off := float(k.barrel_length)*cos(pitch_rest)
	var above := float(k.base_height)+float(k.barrel_length)*sin(pitch_rest)
	return at.z-mouth_off-Cannon.reach(float(k["speed_"+kind]),pitch_rest,above)

func _load_pack() -> void:
	var small_z := landing_z(CANNON_AT,"small")
	var big_z := landing_z(CANNON_AT,"big")
	near_centre = Vector3(0.0,0.0,small_z)
	# The second cannon stands at the near isle's back edge, so the small
	# shot that landed here is not on top of it; its own small shot and the
	# first cannon's big one both come down on the far isle.
	cannon_b_at = Vector3(0.0,0.0,small_z+NEAR_WIDE*0.5-1.5)
	far_centre = Vector3(0.0,0.0,(big_z+landing_z(cannon_b_at,"small"))*0.5)
	var at_cannon := carry_at_start != ""
	start = Vector3(0.0,0.0,CANNON_AT.z+4.0) if at_cannon else Vector3(0.0,0.0,10.0)
	start_face = Vector2(0.0,-1.0)
	lost = -DROP
	_last_stood = start
	var near := Rect2(-NEAR_WIDE*0.5,small_z-NEAR_WIDE*0.5,NEAR_WIDE,NEAR_WIDE)
	var far := Rect2(-FAR_WIDE*0.5,far_centre.z-FAR_DEPTH*0.5,FAR_WIDE,FAR_DEPTH)
	stations = [{"key":1,"name":"Cannon yard","spawn":start,"face":start_face,"sign":Vector3(-6.0,3.0,11.0),"parts":[
		["box",START_ISLE,-2.0,0.0,"floor"],
		["box",near,-2.0,0.0,"floor"],
		["box",far,-2.0,0.0,"pad"],
		["label",Vector3(0.0,1.5,far_centre.z),"far isle: a big shot"],
		["label",Vector3(0.0,1.5,small_z+NEAR_WIDE*0.5-1.0),"near isle: a small shot"],
	]}]

func _build_room() -> void:
	super._build_room()
	cannon_field = CannonField.new()
	add_child(cannon_field)
	cannon_field.attach(self)
	cannon_field.add_cannon(CANNON_AT)
	cannon_field.add_cannon(cannon_b_at)
	cannon_field.add_keg(Vector3(-4.0,0.0,6.0),"small")
	cannon_field.add_keg(Vector3(4.0,0.0,6.0),"small")
	cannon_field.add_keg(Vector3(0.0,0.0,2.0),"big")
	_start_with_kegs()

func _start_with_kegs() -> void:
	var take := {"small":["small"],"big":["big"],"both":["small","big"]}.get(carry_at_start,[]) as Array
	for kind: String in take:
		for k: Node3D in cannon_field.kegs:
			if k.kind == kind and k.state == "laid":
				cannon_field.pick_up(k)
				break

## Set down: the kegs back, the cannons empty (and any start kegs in hand).
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if cannon_field != null:
		cannon_field.reset()
		_start_with_kegs()

func _hint_text() -> String:
	return "Cannon yard: touch a keg to carry it · walk up to a cannon to load (crouch: small first) · E climb in/out · stick aims · Space fires · R reset · F1 numbers · F2 feel"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or cannon_field == null: return
	_hud.text = "%s\n\n%s" % [_hud.text,cannon_field.status()]
