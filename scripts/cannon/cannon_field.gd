extends Node3D
## The cannons and kegs of a scene, stepped round the pilot's motor (a
## character study's `foot_pieces` slot, as scripts/traps/trap_field.gd):
##  - Touch a keg and it is picked up: it hovers along behind him like a
##    carried plane part (scripts/carried_follow.gd), up to `max_kegs`. The
##    tech is not muffled.
##  - Jump (A, Space) near a cannon mans it, and a keg in hand slides into
##    the barrel. Inside, the stick aims, the d-pad (`cannon_power_up/down`)
##    sets the power, A fires what is loaded: a keg if one is in the barrel
##    (a ranging shot, the barrel then empty), else YOU, free. X
##    (`cannon_load`) loads the next keg from the hover; B (`cannon_leave`)
##    steps away. The actions are in scripts/pad.gd's table; edges are read
##    from the InputMap (pad and keys alike), the raw device is never polled.
##  - A fired keg flies the arc you would fly at the same aim and power (the
##    same launch velocity under the motor's gravity, no sail, no steering),
##    lands, and leaves a marker that stays until reset: a glowing ring and
##    column where it came down, or, if it fell into the void, a grey puff
##    where it crossed the cannon's height and a "lost" sound.
##  - Fired, you leave by `PilotMotor.toss`: no tumble, the sail ready, a
##    little steering in the air.
## The field is the motor's `rider` while he is inside.
## Hook: `attach(study)`; `add_cannon`, `add_keg`; `reset()`.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const CarriedFollow = preload("res://scripts/carried_follow.gd")
const Keg = preload("res://scripts/cannon/keg.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")
const PadPrompt = preload("res://scripts/pad_prompt.gd")

signal sounded(kind: StringName, at: Vector3)

const RING := Color(0.96,0.55,0.16)
const PUFF := Color(0.6,0.6,0.64)

var knobs := {
	"max_kegs":3,
	"pick_reach":1.3,      # m (x unit/1.2) from his feet to a keg's middle
	"carry_share":0.55,    # a carried keg's size share
	"jump_from":6.0,       # a keg further than this from its hover goal snaps
	"marker_height":3.0,   # the column over a landing (m, x unit/1.2)
	"load_time":0.35,      # s for a keg to slide from the hover into the barrel
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
var _just_boarded := false
var _sliding: Array = []
var _prompt: Label
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
	_slide(delta)
	_step_kegs(delta)
	_show_prompt()

func after(delta: float, _events: Dictionary) -> void:
	if aboard == null: _pick_up_near()
	_follow(delta)

func pose(_figure: Node3D) -> void:
	pass

# --- On foot -------------------------------------------------------------------------

func _pick_up_near() -> void:
	var reach := float(knobs.pick_reach)*_unit/1.2
	for k: Node3D in kegs:
		if k.state != "laid" or carried.size() >= int(knobs.max_kegs): continue
		# Across the ground within reach, and about his height (feet to head).
		var d := k.global_position-motor.feet
		if Vector2(d.x,d.z).length() <= reach and d.y > -0.5 and d.y < _unit*1.6: pick_up(k)

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

## Whether the named input action went down since this was last asked (the
## game's InputMap actions, scripts/pad.gd: the pad and the keys alike).
func _edge(action: StringName) -> bool:
	var down := Input.is_action_pressed(action)
	var was: bool = _held.get(action,false)
	_held[action] = down
	return down and not was

func _use() -> void:
	var a := _edge(&"walk_jump")
	var load_key := _edge(&"cannon_load")
	var leave_key := _edge(&"cannon_leave")
	var up := _edge(&"cannon_power_up")
	var down := _edge(&"cannon_power_down")
	if aboard != null:
		if leave_key: leave()
		elif load_key: load_next()
		elif up: aboard.set_power(aboard.power+1)
		elif down: aboard.set_power(aboard.power-1)
		return
	if motor.rider != null or not a: return
	for c: Node3D in cannons:
		if _near(c):
			board(c)
			return

## Manned: still, the figure hidden, the camera along the barrel; a keg in
## hand goes into an empty barrel.
func board(c: Node3D) -> void:
	aboard = c
	_just_boarded = true
	motor.rider = self
	motor.velocity = Vector3.ZERO
	motor.feet = c.pivot()
	study.figure.visible = false
	study._yaw = c.yaw()
	_sound(&"climb",c.pivot())
	load_next()

## The next keg from the hover into the manned cannon's barrel, sliding in.
## False with none in hand or the barrel full.
func load_next() -> bool:
	var c: Node3D = aboard
	if c == null or c.loaded != null or carried.is_empty(): return false
	var k: Node3D = carried.pop_front()
	k.state = "loaded"
	c.loaded = k
	_sliding.append({"keg":k,"into":c,"t":0.0})
	_sound(&"load",c.pivot())
	return true

## Steps away onto the ground at the cannon's back (a keg loaded stays in).
func leave() -> void:
	var c: Node3D = aboard
	aboard = null
	motor.rider = null
	var back: Vector3 = -c.direction()
	var out: Vector3 = c.global_position+Vector3(back.x,0.0,back.z).normalized()*float(c.knobs.enter_reach)*0.7
	motor.reset(Vector3(out.x,c.global_position.y,out.z),motor.facing)
	study.figure.visible = true

## The motor's rider contract: his step while inside. `pressed` is the
## jump's (A's) press: it fires what is in the barrel.
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
	var fresh := _just_boarded
	_just_boarded = false
	if pressed and not fresh: fire()
	return {}

## A: fires what is in the barrel: a keg (a ranging shot) if one is loaded,
## else him, free.
func fire() -> bool:
	var c: Node3D = aboard
	if c == null: return false
	if c.loaded != null: return fire_keg()
	return fire_self()

func fire_self() -> bool:
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

## The loaded keg out of the barrel along his aim; he stays in.
func fire_keg() -> bool:
	var c: Node3D = aboard
	if c == null or c.loaded == null: return false
	var k: Node3D = c.loaded
	c.loaded = null
	_sliding = _sliding.filter(func(s: Dictionary) -> bool: return s.keg != k)
	var v: Vector3 = c.fire()
	k.launch(c.mouth()+Vector3.UP*0.02,v)
	k.set_meta("cross",Vector3.INF)
	k.set_meta("y0",c.global_position.y)
	_flying.append(k)
	return true

## Kegs sliding from the hover into a barrel.
func _slide(delta: float) -> void:
	for s: Dictionary in _sliding.duplicate():
		var k: Node3D = s.keg
		s.t = float(s.t)+delta
		var f := clampf(float(s.t)/float(knobs.load_time),0.0,1.0)
		k.global_position = k.global_position.lerp((s.into as Node3D).pivot(),f)
		k.scale = Vector3.ONE*lerpf(1.0,0.4,f)
		if f >= 1.0:
			k.visible = false
			k.scale = Vector3.ONE
			_sliding.erase(s)

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
	_sliding.clear()
	heard.clear()
	for m: Dictionary in markers: (m.node as Node).queue_free()
	markers.clear()
	if motor != null: motor.rider = null
	if study != null and study.get("figure") != null: study.figure.visible = true
	for k: Node3D in kegs: k.lay()
	for c: Node3D in cannons: c.reset()

## The prompt line at a cannon: [keys form, pad form] ("" when none).
func prompt_lines() -> Array:
	if aboard != null:
		var held := carried.size()
		var power := "power %d/%d" % [aboard.power+1,aboard.knobs.power_notches.size()]
		if aboard.loaded != null:
			return ["Space fire keg · X load keg (%d) · E leave · , . %s" % [held,power],"{A} fire keg  ·  {X} load keg (%d)  ·  {B} leave  ·  {DPAD} %s" % [held,power]]
		return ["Space launch yourself · X load keg (%d) · E leave · , . %s" % [held,power],"{A} launch yourself  ·  {X} load keg (%d)  ·  {B} leave  ·  {DPAD} %s" % [held,power]]
	for c: Node3D in cannons:
		if _near(c): return ["Space man the cannon (%d kegs in hand)" % carried.size(),"{A} man the cannon (%d kegs in hand)" % carried.size()]
	return ["",""]

func _show_prompt() -> void:
	if _prompt == null:
		var layer := CanvasLayer.new()
		layer.layer = 6
		add_child(layer)
		_prompt = PadPrompt.new()
		_prompt.add_theme_font_size_override("font_size",16)
		_prompt.add_theme_color_override("font_color",Color("fbf6ea"))
		_prompt.add_theme_color_override("font_shadow_color",Color(0,0,0,0.55))
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_prompt.offset_top = -110.0
		_prompt.offset_bottom = -80.0
		_prompt.offset_left = -480.0
		_prompt.offset_right = 480.0
		layer.add_child(_prompt)
	var lines := prompt_lines()
	_prompt.alternates = {lines[0]:lines[1]}
	_prompt.text = lines[0]
	_prompt.visible = lines[0] != ""

## The prompt as on screen (for tests).
func shown_prompt() -> String:
	return _prompt.shown_text() if _prompt != null else ""
