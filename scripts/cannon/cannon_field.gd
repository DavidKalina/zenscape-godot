extends Node3D
## The cannons and kegs of a scene, stepped round the pilot's motor (a
## character study's `foot_pieces` slot, as scripts/traps/trap_field.gd):
##  - Touch a keg and it is picked up: it hovers along behind him like a
##    carried plane part (scripts/carried_follow.gd), up to `max_kegs`. The
##    tech is not muffled.
##  - Walk up to an empty cannon with kegs and one goes in from the hover:
##    the big one, or the small one while crouching.
##  - `use` (E, pad X) by a cannon climbs in; inside, the stick aims (left
##    and right turn the barrel, up and down pitch it), the jump button
##    fires, `use` climbs out. A dotted arc shows the first part of the
##    flight. The shot is the motor's `toss`: no tumble, the sail ready, a
##    little steering in the air.
## The field is the motor's `rider` while he is inside.
## Hook: `attach(study)`; `add_cannon`, `add_keg`; `reset()`.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const CarriedFollow = preload("res://scripts/carried_follow.gd")
const Keg = preload("res://scripts/cannon/keg.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")

signal sounded(kind: StringName, at: Vector3)

var knobs := {
	"max_kegs":3,
	"pick_reach":1.3,      # m (x unit/1.2) from his feet to a keg's middle
	"carry_share":0.55,    # a carried keg's size share
	"jump_from":6.0,       # a keg further than this from its hover goal snaps
}

var study: Node3D
var motor: PilotMotor
var cannons: Array = []
var kegs: Array = []
var carried: Array = []
var aboard: Node3D = null
var heard: Array = []
## Scripted input (tests): `script_use` is a one-shot press of `use`.
var script_use := false
var _clock := 0.0
var _use_was := false
var _unit := 1.2

func _init() -> void:
	name = "CannonField"

func attach(scene: Node3D) -> void:
	study = scene
	motor = scene.motor
	scene.foot_pieces = self
	_unit = float(Cannon.defaults().unit)

func add_cannon(at: Vector3, heading := 0.0, over := {}) -> Node3D:
	var c: Node3D = Cannon.new()
	c.configure(over)
	c.position = at
	c.rotation.y = heading
	c.sounded.connect(_sound)
	add_child(c)
	cannons.append(c)
	return c

func add_keg(at: Vector3, kind: String) -> Node3D:
	var k: Node3D = Keg.new()
	k.setup(kind,_unit)
	k.home = at
	k.position = at
	add_child(k)
	kegs.append(k)
	return k

func _sound(kind: StringName, at: Vector3) -> void:
	heard.append([kind,at])
	sounded.emit(kind,at)

## Picked up now (a dev start, or a test).
func pick_up(k: Node3D) -> bool:
	if k.state != "laid" or carried.size() >= int(knobs.max_kegs): return false
	carried.append(k)
	k.set_carried(true,float(knobs.carry_share))
	_sound(&"pickup",k.global_position)
	return true

func before(delta: float) -> void:
	_clock += delta
	_use(delta)

func after(delta: float, _events: Dictionary) -> void:
	if aboard == null:
		_pick_up_near()
		_load_near()
	_follow(delta)

func pose(_figure: Node3D) -> void:
	pass

# --- On foot -------------------------------------------------------------------------

func _feet() -> Vector3:
	return motor.feet

func _pick_up_near() -> void:
	var reach := float(knobs.pick_reach)*_unit/1.2
	for k: Node3D in kegs:
		if k.state == "laid" and carried.size() < int(knobs.max_kegs) \
				and k.global_position.distance_to(_feet()+Vector3.UP*k.height*0.5) <= reach:
			pick_up(k)

## Which carried keg goes in: the big one, or a small one while crouching.
func choose_keg() -> Node3D:
	var want := "small" if motor.crouch else "big"
	for k: Node3D in carried:
		if k.kind == want: return k
	return carried[0] if not carried.is_empty() else null

func _near(c: Node3D) -> bool:
	var d := _feet()-c.global_position
	return Vector2(d.x,d.z).length() <= float(c.knobs.enter_reach) and absf(d.y) < 2.0

func _load_near() -> void:
	if carried.is_empty(): return
	for c: Node3D in cannons:
		if c.loaded == "" and _near(c): load_from_hover(c)

## A carried keg into `c`: false when none is carried or it is full.
func load_from_hover(c: Node3D) -> bool:
	var k := choose_keg()
	if k == null or c.loaded != "": return false
	carried.erase(k)
	k.spend()
	return c.load_keg(k.kind)

func _follow(delta: float, snap := false) -> void:
	if carried.is_empty() or study.get("figure") == null: return
	var way := PilotMotor.forward(motor.facing)
	var scale := float(study.get("wanderer_scale"))
	for k in carried.size():
		var keg: Node3D = carried[k]
		var goal := CarriedFollow.goal(study.figure.global_position,way,scale,k,carried.size(),_clock)
		CarriedFollow.ease_to(keg,goal,delta,snap,float(knobs.jump_from),CarriedFollow.EASE)

# --- In the cannon -------------------------------------------------------------------

func _pressed_use() -> bool:
	var now := script_use
	script_use = false
	if not study.scripted:
		var held := Input.is_physical_key_pressed(KEY_E) or Input.is_joy_button_pressed(0,JOY_BUTTON_X)
		now = held and not _use_was
		_use_was = held
	return now

func _use(delta: float) -> void:
	var pressed := _pressed_use()
	if aboard != null:
		if pressed: leave()
		return
	if motor.rider != null or not pressed: return
	for c: Node3D in cannons:
		if _near(c):
			if c.loaded == "" and not carried.is_empty(): load_from_hover(c)
			board(c)
			return

## Climbed in: still, the figure hidden, the camera along the barrel.
func board(c: Node3D) -> void:
	aboard = c
	motor.rider = self
	motor.velocity = Vector3.ZERO
	motor.feet = c.pivot()
	study.figure.visible = false
	study._yaw = c.yaw()
	_sound(&"climb",c.pivot())

## Climbed out onto the ground at the cannon's back.
func leave() -> void:
	var c: Node3D = aboard
	aboard = null
	motor.rider = null
	c.show_preview([])
	var back: Vector3 = -c.direction()
	var out: Vector3 = c.global_position+Vector3(back.x,0.0,back.z).normalized()*float(c.knobs.enter_reach)*0.7
	motor.reset(Vector3(out.x,c.global_position.y,out.z),motor.facing)
	study.figure.visible = true

## The motor's rider contract: his step while inside.
func ride(m: PilotMotor, delta: float, want: Vector2, pressed: bool) -> Dictionary:
	var c: Node3D = aboard
	var camera_forward := PilotMotor.forward(float(study._yaw))
	var right := Vector2(-camera_forward.y,camera_forward.x)
	var dx := want.dot(right)
	var dy := want.dot(camera_forward)
	c.set_aim(c.aim_yaw-dx*float(c.knobs.yaw_rate)*delta,c.pitch+dy*float(c.knobs.pitch_rate)*delta)
	study._yaw = c.yaw()
	m.feet = c.pivot()
	m.velocity = Vector3.ZERO
	m.facing = c.yaw()
	c.preview(m)
	if pressed: fire()
	return {}

## Fires the cannon he is in: launched along the barrel, or a dry click.
func fire() -> bool:
	var c: Node3D = aboard
	if c == null: return false
	var v: Vector3 = c.fire()
	if v == Vector3.ZERO: return false
	aboard = null
	c.show_preview([])
	motor.rider = null
	motor.grounded = false
	motor.feet = c.mouth()
	study.figure.visible = true
	motor.toss(v)
	return true

func reset() -> void:
	aboard = null
	carried.clear()
	heard.clear()
	if motor != null: motor.rider = null
	if study != null and study.get("figure") != null: study.figure.visible = true
	for k: Node3D in kegs: k.lay()
	for c: Node3D in cannons: c.reset()

## A line for the HUD and hint.
func status() -> String:
	var parts := PackedStringArray()
	var held := PackedStringArray()
	for k: Node3D in carried: held.append(k.kind)
	parts.append("kegs: %s" % (", ".join(held) if not held.is_empty() else "none"))
	if aboard != null:
		parts.append("in the cannon (%s): stick aims · Space fires · E climbs out" % (aboard.loaded if aboard.loaded != "" else "empty"))
	else:
		for c: Node3D in cannons:
			if _near(c): parts.append("cannon (%s): E climbs in" % (c.loaded if c.loaded != "" else "empty"))
	return " · ".join(parts)
