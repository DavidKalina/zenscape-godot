extends Node3D
## The cannons and kegs of a scene, stepped round the pilot's motor (a
## character study's `foot_pieces` slot, as scripts/traps/trap_field.gd):
##  - Touch a keg and it is picked up: it hovers along behind him like a
##    carried plane part (scripts/carried_follow.gd), up to `max_kegs`. The
##    tech is not muffled.
##  - `use` (E, pad X) by a cannon climbs in; inside, the stick aims (left
##    and right turn the barrel, up and down pitch it), Left/Right arrow
##    (pad d-pad) set the power, Space (pad A) fires YOU: free, always. F
##    (pad Y) fires a keg from the hover instead, a ranging shot.
##  - A fired keg flies the arc you would fly at the same aim and power (the
##    same launch velocity under the motor's gravity, no sail, no steering),
##    lands, and leaves a marker that stays until reset: a glowing ring and
##    column where it came down, or, if it fell into the void, a grey puff
##    where it crossed the cannon's height and a "lost" sound. With no keg,
##    F only clicks.
##  - Fired, you leave by `PilotMotor.toss`: no tumble, the sail ready, a
##    little steering in the air.
## The field is the motor's `rider` while he is inside.
## Hook: `attach(study)`; `add_cannon`, `add_keg`; `reset()`.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const CarriedFollow = preload("res://scripts/carried_follow.gd")
const Keg = preload("res://scripts/cannon/keg.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")

signal sounded(kind: StringName, at: Vector3)

const RING := Color(0.96,0.55,0.16)
const PUFF := Color(0.6,0.6,0.64)

var knobs := {
	"max_kegs":3,
	"pick_reach":1.3,      # m (x unit/1.2) from his feet to a keg's middle
	"carry_share":0.55,    # a carried keg's size share
	"jump_from":6.0,       # a keg further than this from its hover goal snaps
	"marker_height":3.0,   # the column over a landing (m, x unit/1.2)
}

var study: Node3D
var motor: PilotMotor
var cannons: Array = []
var kegs: Array = []
var carried: Array = []
var aboard: Node3D = null
## Where fired kegs came down: {kind: "landed"|"lost", at: Vector3, node}.
var markers: Array = []
var heard: Array = []
## Scripted input (tests): one-shot presses of `use` and the keg button,
## and a power step (-1, +1).
var script_use := false
var script_keg := false
var script_power := 0
var _clock := 0.0
var _held := {}
var _flying: Array = []
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

func add_keg(at: Vector3) -> Node3D:
	var k: Node3D = Keg.new()
	k.setup(_unit)
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
	_use()
	_step_kegs(delta)

func after(delta: float, _events: Dictionary) -> void:
	if aboard == null: _pick_up_near()
	_follow(delta)

func pose(_figure: Node3D) -> void:
	pass

# --- On foot -------------------------------------------------------------------------

func _pick_up_near() -> void:
	var reach := float(knobs.pick_reach)*_unit/1.2
	for k: Node3D in kegs:
		if k.state == "laid" and carried.size() < int(knobs.max_kegs) \
				and k.global_position.distance_to(motor.feet+Vector3.UP*k.height*0.5) <= reach:
			pick_up(k)

func _near(c: Node3D) -> bool:
	var d := motor.feet-c.global_position
	return Vector2(d.x,d.z).length() <= float(c.knobs.enter_reach) and absf(d.y) < 2.0

func _follow(delta: float, snap := false) -> void:
	if carried.is_empty() or study.get("figure") == null: return
	var way := PilotMotor.forward(motor.facing)
	var scale := float(study.get("wanderer_scale"))
	for k in carried.size():
		var keg: Node3D = carried[k]
		var goal := CarriedFollow.goal(study.figure.global_position,way,scale,k,carried.size(),_clock)
		CarriedFollow.ease_to(keg,goal,delta,snap,float(knobs.jump_from),CarriedFollow.EASE)

# --- In the cannon -------------------------------------------------------------------

## A press (the edge) of a button, or the script's one-shot.
func _edge(key: String, held: bool, script: bool) -> bool:
	if study.scripted: return script
	var was: bool = _held.get(key,false)
	_held[key] = held
	return held and not was

func _use() -> void:
	var pressed := _edge("use",Input.is_physical_key_pressed(KEY_E) or Input.is_joy_button_pressed(0,JOY_BUTTON_X),script_use)
	script_use = false
	if aboard != null:
		if pressed: leave()
		var step := script_power
		script_power = 0
		if not study.scripted:
			if _edge("up",Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_joy_button_pressed(0,JOY_BUTTON_DPAD_RIGHT),false): step = 1
			if _edge("down",Input.is_physical_key_pressed(KEY_LEFT) or Input.is_joy_button_pressed(0,JOY_BUTTON_DPAD_LEFT),false): step = -1
		if step != 0 and aboard != null: aboard.set_power(aboard.power+step)
		if _edge("keg",Input.is_physical_key_pressed(KEY_F) or Input.is_joy_button_pressed(0,JOY_BUTTON_Y),script_keg): fire_keg()
		script_keg = false
		return
	if motor.rider != null or not pressed: return
	for c: Node3D in cannons:
		if _near(c):
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
	if pressed: fire()
	return {}

## Fires him from the cannon he is in, at its aim and power: free.
func fire() -> bool:
	var c: Node3D = aboard
	if c == null: return false
	var v: Vector3 = c.fire()
	aboard = null
	motor.rider = null
	motor.grounded = false
	motor.feet = c.mouth()
	study.figure.visible = true
	motor.toss(v)
	return true

## Fires a keg from the hover instead, a ranging shot; a click with none.
func fire_keg() -> bool:
	var c: Node3D = aboard
	if c == null: return false
	if carried.is_empty():
		c.click()
		return false
	var k: Node3D = carried.pop_front()
	var v: Vector3 = c.fire()
	k.launch(c.mouth()+Vector3.UP*0.02,v)
	k.set_meta("cross",Vector3.INF)
	k.set_meta("y0",c.global_position.y)
	_flying.append(k)
	return true

## The kegs in flight, the motor's own arc (gravity up, falling harder, to
## its terminal), no steering; ended at the ground or the void.
func _step_kegs(delta: float) -> void:
	for k: Node3D in _flying.duplicate():
		var from := k.global_position
		var at := from
		var v: Vector3 = k.velocity
		var left := delta
		for i in 4:
			if left <= 0.0: break
			var g := motor.gravity if v.y > 0.0 else motor.gravity*motor.fall
			var t := left
			if v.y > 0.0: t = minf(t,v.y/g)
			at += Vector3(v.x*t,v.y*t-0.5*g*t*t,v.z*t)
			v.y = maxf(v.y-g*t,-motor.terminal)
			left -= t
		if v.y <= 0.0 and from.y > float(k.get_meta("y0")) and at.y <= float(k.get_meta("y0")) and k.get_meta("cross") == Vector3.INF:
			k.set_meta("cross",from.lerp(at,(from.y-float(k.get_meta("y0")))/maxf(from.y-at.y,1e-6)))
		k.velocity = v
		k.global_position = at
		var under: float = study.ground.height_from(Vector2(at.x,at.z),from.y)
		if v.y <= 0.0 and under != -INF and at.y <= under:
			_mark("landed",Vector3(at.x,under,at.z))
			_end(k)
		elif at.y < float(study.lost):
			var cross: Vector3 = k.get_meta("cross")
			_mark("lost",cross if cross != Vector3.INF else at)
			_end(k)

func _end(k: Node3D) -> void:
	_flying.erase(k)
	k.spend()

## The marker where a keg came down (or was lost), kept till reset.
func _mark(kind: String, at: Vector3) -> void:
	var m := Node3D.new()
	m.name = "Mark_"+kind
	add_child(m)
	m.global_position = at
	var scale := _unit/1.2
	if kind == "landed":
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.5*scale
		torus.outer_radius = 0.65*scale
		ring.mesh = torus
		ring.position.y = 0.05
		ring.material_override = _glow(RING)
		m.add_child(ring)
		var col := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06*scale
		cyl.bottom_radius = 0.1*scale
		cyl.height = float(knobs.marker_height)*scale
		col.mesh = cyl
		col.position.y = cyl.height*0.5
		col.material_override = _glow(RING)
		m.add_child(col)
		_sound(&"thud",at)
	else:
		for i in 3:
			var puff := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = (0.35-i*0.07)*scale
			s.height = s.radius*2.0
			puff.mesh = s
			puff.position.y = i*0.45*scale
			puff.material_override = _glow(PUFF)
			m.add_child(puff)
		_sound(&"lost",at)
	markers.append({"kind":kind,"at":at,"node":m})

static func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func reset() -> void:
	aboard = null
	carried.clear()
	_flying.clear()
	heard.clear()
	for m: Dictionary in markers: (m.node as Node).queue_free()
	markers.clear()
	if motor != null: motor.rider = null
	if study != null and study.get("figure") != null: study.figure.visible = true
	for k: Node3D in kegs: k.lay()
	for c: Node3D in cannons: c.reset()

## A line for the HUD and hint.
func status() -> String:
	var parts := PackedStringArray()
	parts.append("kegs in hand: %d" % carried.size())
	if aboard != null:
		parts.append("in the cannon: power %d/%d · yaw %.0f° pitch %.0f° · Space fires you · F fires a keg · arrows power · E out" % [aboard.power+1,aboard.knobs.power_notches.size(),rad_to_deg(aboard.aim_yaw),rad_to_deg(aboard.pitch)])
	else:
		for c: Node3D in cannons:
			if _near(c): parts.append("cannon: E climbs in")
	return " · ".join(parts)
