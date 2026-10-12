extends "res://studies/character_study.gd"
## The cannon yard (docs/design/roguelike/cannon-round1.md): a start isle with
## a cannon and three powder kegs, and targets whose distance you cannot
## judge by eye. The kegs are ranging shots, fired from outside the cannon:
## fire a keg, see where it lands (a marker stays), adjust, fire another;
## then climb in and launch yourself at the aim and power you tested. Three
## kegs, so spend them where the judgement is hard.
##  - TARGET_1: a narrow isle off to the left of the first cannon's line.
##  - NEAR: a wide isle straight ahead with the second cannon on its back
##    edge, and no kegs; its target is TARGET_2, narrow, far to the right.
## Targets are placed from the shot (Cannon.landing_for) at the aim and
## power named in AIMS, so each is reachable; the knobs move them with it.
## This extends the character study (motor, figure, camera, F1 numbers, F2
## feel); a CannonField (scripts/cannon/cannon_field.gd) fills its
## `foot_pieces` slot.
##   touch a keg  picked up, hovers behind you
##   at a cannon: A (Space) operate it from outside · Y (F) climb in
##   operating: stick aims · d-pad (, .) power · A fires a keg (loads it
##     from your hover first; none, a click) · Y climb in · B (E) step away
##   inside: A launch yourself · B climb out
## `--cannon=in` starts by the first cannon with a keg in hand.
##   godot --path . res://studies/cannon_yard.tscn -- --no-title
const CannonField = preload("res://scripts/cannon/cannon_field.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")

const START_ISLE := Rect2(-8.0,-7.0,16.0,20.0)
const DROP := 24.0
const CANNON_AT := Vector3(0.0,0.0,-3.0)
const NEAR_WIDE := 10.0
const TARGET_WIDE := 5.0
## The aims the targets are placed from: {yaw (deg), pitch (deg), notch}.
const AIMS := {
	"target_1":{"yaw":20.0,"pitch":40.0,"notch":3},
	"near":{"yaw":0.0,"pitch":40.0,"notch":1},
	"target_2":{"yaw":-30.0,"pitch":40.0,"notch":4},
}

var cannon_field: Node3D
var carry_at_start := false
var near_centre := Vector3.ZERO
var cannon_b_at := Vector3.ZERO
var target_1 := Vector3.ZERO
var target_2 := Vector3.ZERO

func _ready() -> void:
	pack = "cannon_yard"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--cannon="): carry_at_start = true
	super._ready()

static func _land(base: Vector3, aim: Dictionary) -> Vector3:
	return Cannon.landing_for(base,deg_to_rad(float(aim.yaw)),deg_to_rad(float(aim.pitch)),int(aim.notch),0.0)

func _load_pack() -> void:
	var n := _land(CANNON_AT,AIMS.near)
	near_centre = Vector3(n.x,0.0,n.z)
	cannon_b_at = near_centre+Vector3(0.0,0.0,NEAR_WIDE*0.5-1.5)
	target_1 = _land(CANNON_AT,AIMS.target_1)
	target_2 = _land(cannon_b_at,AIMS.target_2)
	start = Vector3(0.0,0.0,CANNON_AT.z+4.0) if carry_at_start else Vector3(0.0,0.0,10.0)
	start_face = Vector2(0.0,-1.0)
	lost = -DROP
	_last_stood = start
	stations = [{"key":1,"name":"Cannon yard","spawn":start,"face":start_face,"sign":Vector3(-6.0,3.0,11.0),"parts":[
		["box",START_ISLE,-2.0,0.0,"floor"],
		["box",_isle(near_centre,NEAR_WIDE),-2.0,0.0,"floor"],
		["box",_isle(target_1,TARGET_WIDE),-2.0,0.0,"pad"],
		["box",_isle(target_2,TARGET_WIDE),-2.0,0.0,"pad"],
	]}]

static func _isle(centre: Vector3, wide: float) -> Rect2:
	return Rect2(centre.x-wide*0.5,centre.z-wide*0.5,wide,wide)

func target_rects() -> Dictionary:
	return {"near":_isle(near_centre,NEAR_WIDE),"target_1":_isle(target_1,TARGET_WIDE),"target_2":_isle(target_2,TARGET_WIDE)}

func _build_room() -> void:
	super._build_room()
	cannon_field = CannonField.new()
	add_child(cannon_field)
	cannon_field.attach(self)
	cannon_field.add_cannon(CANNON_AT)
	cannon_field.add_cannon(cannon_b_at)
	cannon_field.add_keg(Vector3(-4.0,0.0,6.0))
	cannon_field.add_keg(Vector3(4.0,0.0,6.0))
	cannon_field.add_keg(Vector3(0.0,0.0,2.0))
	_start_with_keg()

func _start_with_keg() -> void:
	if carry_at_start: cannon_field.pick_up(cannon_field.kegs[0])

## Set down: the kegs back, the markers gone.
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if cannon_field != null:
		cannon_field.reset()
		_start_with_keg()

func _hint_text() -> String:
	return "Cannon yard: touch a keg to carry it · at a cannon A operates it from outside: stick aims, d-pad power, A fires a keg to see where it lands · Y climbs in, then A launches you · B steps away / climbs out · R reset · F1 numbers · F2 feel"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or cannon_field == null: return
	_hud.text = "%s\n\n%s" % [_hud.text,"kegs in hand: %d" % cannon_field.carried.size()]
