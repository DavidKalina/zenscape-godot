extends "res://studies/character_study.gd"
## The cannon yard: a start isle with
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
##
## The catch stations: cannons that
## catch a body arriving in the mouth and fire it on.
##   2  the ledge: step off the tower's edge into the mouth below.
##   3  the kicker: stand on the orange plate; it knocks you, stunned, into
##      the mouth.
##   4  the head: an inhaler head on its isle; let it swallow you; it blasts
##      you out over its rim, down into a cannon on the terrace below.
const CannonField = preload("res://scripts/cannon/cannon_field.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")

## The catch yard: the catching cannon's base, the tower to its side, the
## kicker's plate, and the head's isle with its cannon on the terrace under.
const CATCH_AT := Vector3(-45.0,0.0,0.0)
const TOWER_TOP := 9.0
const KICK_AT := Vector3(-51.0,0.0,-2.0)
const HEAD_AT := Vector3(-100.0,0.0,0.0)
## The head faces +z; its blast's cannon stands on a terrace this far down,
## its mouth where the blast comes down through it (measured: HEAD_CANNON).
const HEAD_TERRACE := -6.0
const HEAD_CANNON := Vector3(-97.98,-6.0,15.9)
const HEAD_GUEST := Vector3(-100.0,0.0,6.5)

## The kicker for the catch: knocks him (itself the source) on an arc that
## peaks `over` m above its aim and comes down through it.
class CatchKicker extends "res://studies/stun_kicker.gd":
	func defaults() -> Dictionary:
		var d: Dictionary = super()
		d["over"] = 2.5
		return d
	func _kick() -> void:
		_fuse = 0.0
		_cool = float(knob("rearm"))
		kicks += 1
		var to: Vector3 = aim.global_position
		var g := motor.gravity
		var top := to.y+float(knob("over"))
		var up := sqrt(2.0*g*maxf(top-motor.feet.y,0.1))
		var t := up/g+sqrt(2.0*(top-to.y)/(g*motor.fall))
		var flat := Vector2(to.x-motor.feet.x,to.z-motor.feet.z)/t
		motor.knock(Vector3(flat.x,up,flat.y),self)
		tell_sound(&"kick",motor.feet)

## Steps the cannons, the traps and the enemies from the study's one slot.
class Both extends Node:
	var parts: Array = []
	var lead: Node
	func before(delta: float) -> void:
		for p: Node in parts: p.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		for p: Node in parts: p.after(delta,events)
	func pose(figure: Node3D) -> void:
		for p: Node in parts: p.pose(figure)
	func frame(camera: Camera3D, delta: float) -> void:
		lead.frame(camera,delta)

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
var traps: Node3D
var enemies: Node
var kicker: Node3D
var catcher: Node3D
var head_cannon: Node3D
var head: Node3D
var catch_landing := Vector3.ZERO
var head_landing := Vector3.ZERO
var _both: Node

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
	_catch_stations()

## Where a cannon at `base` turned `heading` lands its rest shot on `floor_y`.
static func _rest_landing(base: Vector3, heading: float, floor_y: float) -> Vector3:
	var k := Cannon.defaults()
	var f := PilotMotor.forward(heading)
	var p := float(k.pitch_rest)
	var dir := Vector3(f.x*cos(p),sin(p),f.y*cos(p))
	var from: Vector3 = base+Vector3.UP*float(k.base_height)+dir*float(k.barrel_length)
	return Cannon.landing(from,dir*float(k.speed_max)*float(k.power_notches[int(k.power_rest)]),floor_y)

## The catch stations: the ledge (2), the kicker (3), the head (4).
func _catch_stations() -> void:
	catch_landing = _rest_landing(CATCH_AT,0.0,0.0)
	head_landing = _rest_landing(HEAD_CANNON,PI*0.5,HEAD_TERRACE)
	var k := Cannon.defaults()
	var mouth_z: float = CATCH_AT.z-cos(float(k.pitch_rest))*float(k.barrel_length)
	stations.append({"key":2,"name":"catch: the ledge","spawn":Vector3(CATCH_AT.x+4.2,TOWER_TOP,mouth_z),"face":Vector2(-1.0,0.0),
		"sign":Vector3(CATCH_AT.x,4.0,CATCH_AT.z+6.0),"parts":[
		["box",Rect2(CATCH_AT.x-11.0,CATCH_AT.z-6.0,16.0,14.0),-2.0,0.0,"floor"],
		["box",Rect2(CATCH_AT.x+2.4,mouth_z-1.5,2.8,3.0),-2.0,TOWER_TOP,"grey"],
		["box",_isle(catch_landing,8.0),-2.0,0.0,"pad"],
		["label",Vector3(CATCH_AT.x,4.5,CATCH_AT.z+2.0),"the catching cannon: fall in, thrown in, knocked in"],
	]})
	stations.append({"key":3,"name":"catch: the kicker","spawn":KICK_AT+Vector3(-2.0,0.0,0.0),"face":Vector2(1.0,0.0),"parts":[]})
	stations.append({"key":4,"name":"catch: the head","spawn":HEAD_GUEST,"face":Vector2(0.0,-1.0),
		"sign":Vector3(HEAD_AT.x+6.0,3.0,HEAD_AT.z+6.0),"parts":[
		["box",Rect2(HEAD_AT.x-8.0,HEAD_AT.z-8.0,16.0,16.0),-2.0,0.0,"floor"],
		["box",Rect2(HEAD_CANNON.x-10.0,HEAD_CANNON.z-7.0,20.0,14.0),HEAD_TERRACE-2.0,HEAD_TERRACE,"floor"],
		["box",_isle(head_landing,8.0),HEAD_TERRACE-2.0,HEAD_TERRACE,"pad"],
		["label",Vector3(HEAD_AT.x+4.0,1.5,HEAD_AT.z+8.0),"let the head swallow you: it spits you into the cannon below"],
	]})

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
	catcher = cannon_field.add_cannon(CATCH_AT)
	head_cannon = cannon_field.add_cannon(HEAD_CANNON,PI*0.5)
	traps = TrapField.new()
	add_child(traps)
	traps.attach(self)
	kicker = CatchKicker.new()
	kicker.position = KICK_AT
	traps.add(kicker)
	var aim := Node3D.new()
	aim.name = "KickAim"
	add_child(aim)
	aim.position = catcher.mouth()
	kicker.aim = aim
	enemies = EnemyField.new()
	enemies.attach(self)
	head = enemies.spawn(InhalerHead,HEAD_AT,Vector2(0.0,1.0),{"ring":1.0})
	_both = Both.new()
	_both.parts = [cannon_field,traps,enemies]
	_both.lead = cannon_field
	add_child(_both)
	foot_pieces = _both
	_start_with_keg()

func _start_with_keg() -> void:
	if carry_at_start: cannon_field.pick_up(cannon_field.kegs[0])

## Set down: the kegs back, the markers gone.
func place(at: Vector3, face: Vector2) -> void:
	if traps != null: traps.reset()
	if enemies != null:
		enemies.reset()
		head = enemies.enemies[0] if not enemies.enemies.is_empty() else null
	super.place(at,face)
	if cannon_field != null:
		cannon_field.reset()
		_start_with_keg()

func _hint_text() -> String:
	return "Cannon yard: touch a keg to carry it · at a cannon A operates it from outside: stick aims, d-pad power, A fires a keg to see where it lands · Y climbs in, then A launches you · B steps away / climbs out · 2-4 the catching cannons (ledge, kicker, head) · R reset · F1 numbers · F2 feel"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or cannon_field == null: return
	_hud.text = "%s\n\n%s" % [_hud.text,"kegs in hand: %d" % cannon_field.carried.size()]
