extends Node3D
## The cannons and kegs of a scene, stepped round the pilot's motor (a
## character study's `foot_pieces` slot, as scripts/traps/trap_field.gd).
##  - Touch a keg and it is picked up: it hovers along behind him like a
##    carried plane part (scripts/carried_follow.gd), up to `max_kegs`. The
##    tech is not muffled.
##  - Two separate modes at a cannon:
##    OPERATING, from outside: he stands at the breech, behind the base, and
##    works it like artillery. The stick aims the barrel, the d-pad sets the
##    power, A fires a keg (taken from his hover into the barrel, seen
##    sliding in, then fired; with none, a dry click). The camera stands
##    behind the cannon looking down the barrel, follows a keg in flight and
##    holds on where it came down. Firing never launches him from here.
##    INSIDE, launching himself: Y climbs into the barrel. The aim and power
##    stay as he tested them (the stick does nothing in here); A fires him,
##    B climbs back out to operating.
##    On foot at a cannon: A starts operating (it does not jump), Y climbs
##    straight in. B while operating steps away.
##  - Each button does one thing per press: the edges are read here from the
##    InputMap (scripts/pad.gd's actions, the pad and the keys alike) before
##    the motor steps, and the motor's own jump press is ignored while he is
##    at a cannon (the field is its `rider`), so the A that starts operating
##    neither jumps nor fires.
##  - A fired keg flies the arc he would fly at the same aim and power (the
##    same launch velocity under the motor's gravity, no sail, no steering),
##    lands, and leaves a marker that stays until reset: a glowing ring and
##    column where it came down, or, if it fell into the void, a grey puff
##    where it crossed the cannon's height and a "lost" sound.
##  - Fired, he leaves by `PilotMotor.toss`: no tumble, the sail ready, a
##    little steering in the air.
##  - THE CATCH: a body arriving in
##    a cannon's mouth, not by climbing in (falling off a ledge, thrown,
##    knocked, tumbling stunned, blown out of an inhaler head), is caught:
##    within `catch_pull` of the mouth and heading in, his drift off the line
##    to it is turned toward it, his speed kept (a funnel); within `catch_radius` (swept), moving
##    into it against the aim, he is swallowed (the gulp: squash, wobble,
##    "gulp"), held `catch_hold` s, wound up `catch_windup` s (drawn back,
##    swelling, shaking, glowing, "charge"), then fired along the aim at the
##    power set (boom, kick). Poised, he leaves by `toss` as from climbing
##    in; stunned, by `knock(v, cannon)`: the cannon names itself as the
##    source, so a fresh stun only if `stunnable`, else thrown on still
##    stunned (the restun gap and the chain cap hold). Only the pilot is
##    caught: enemies and kegs fly past (see the doc).
## Hook: `attach(study)`; `add_cannon`, `add_keg`; `reset()`; the study calls
## `frame(camera, delta)` after its own camera.
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
	# The operating camera, in units (cannon `unit`, 1.2 m): behind the
	# pivot, over it, how far down the barrel it looks; its ease (s); how long
	# it holds on a keg's landing (s); how far it rises per metre of range.
	"view_back":4.5,
	"view_up":2.4,
	"view_ahead":6.0,
	"view_ease":0.3,
	"view_hold":1.6,
	"view_rise":0.12,
}

var study: Node3D
var motor: PilotMotor
var cannons: Array = []
var kegs: Array = []
var carried: Array = []
## The cannon he is at, and how: "" (on foot), "operating" (outside, at the
## breech) or "inside" (in the barrel).
var cannon: Node3D = null
var mode := ""
## Where fired kegs came down: {kind: "landed"|"lost", at: Vector3, node}.
var markers: Array = []
var heard: Array = []
## A keg on its way from the hover into the barrel, fired when it is in:
## {keg, into, t}, or empty.
var loading := {}
var _prompt: Label
var _clock := 0.0
var _held := {}
var _launch := false
var _flying: Array = []
var _unit := 1.2
# The camera: its weight over the study's, the eye and look eased, the keg
# it follows, and the landing it holds on.
var _view_w := 0.0
var _eye := Vector3.INF
var _look := Vector3.INF
var _watch: Node3D = null
var _hold_at := Vector3.INF
var _hold_t := 0.0
var _last_cannon: Node3D = null
## The catch: seconds since he was caught, whether he came in stunned, the
## shot due after the motor's step, his feet before it (the sweep), and the
## catches and shots so far ({cannon, stunned, at, t} each, for checks).
var _catch_t := 0.0
var _caught_stunned := false
var _fire_caught := false
var _feet_was := Vector3.INF
var catches: Array = []
var spits: Array = []

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
	for c: Node3D in cannons: c.step_catch(delta)
	_use()
	_load(delta)
	_hold_caught(delta)
	_funnel(delta)
	_feet_was = motor.feet
	_step_kegs(delta)
	_show_prompt()

func after(delta: float, _events: Dictionary) -> void:
	if _launch:
		_launch = false
		launch_self()
	elif _fire_caught:
		_fire_caught = false
		spit()
	elif mode == "caught" and motor.rider != self:
		# Something else took him out of the barrel (a knock): let go.
		_let_go()
	elif mode == "":
		_catch_in()
		if mode == "": _pick_up_near()
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

## The cannon he could use from where he stands on foot, or null.
func near_cannon() -> Node3D:
	if mode != "" or motor.rider != null or not motor.grounded: return null
	for c: Node3D in cannons:
		if _near(c): return c
	return null

func _follow(delta: float, snap := false) -> void:
	if carried.is_empty() or study.get("figure") == null: return
	var way := PilotMotor.forward(motor.facing)
	var scale := float(study.get("wanderer_scale"))
	for k in carried.size():
		var keg: Node3D = carried[k]
		var goal := CarriedFollow.goal(study.figure.global_position,way,scale,k,carried.size(),_clock)
		CarriedFollow.ease_to(keg,goal,delta,snap,float(knobs.jump_from),CarriedFollow.EASE)

# --- The buttons ---------------------------------------------------------------------

## Whether the named input action went down since this was last asked (the
## game's InputMap actions, scripts/pad.gd: the pad and the keys alike).
func _edge(action: StringName) -> bool:
	var down := Input.is_action_pressed(action)
	var was: bool = _held.get(action,false)
	_held[action] = down
	return down and not was

## One frame's presses, each doing one thing in the mode he is in.
func _use() -> void:
	var a := _edge(&"walk_jump")
	var climb := _edge(&"cannon_climb")
	var back := _edge(&"cannon_leave")
	var up := _edge(&"cannon_power_up")
	var down := _edge(&"cannon_power_down")
	match mode:
		"caught":
			# Held: the beat is the cannon's; no button cuts it short.
			pass
		"inside":
			# Fired after the motor's step (`after`), so that step still
			# takes the press as the rider's and he leaves with A held: the
			# same press cannot open the sail as well.
			if a: _launch = true
			elif back: climb_out()
		"operating":
			if up: cannon.set_power(cannon.power+1)
			elif down: cannon.set_power(cannon.power-1)
			if not loading.is_empty(): return
			if a: fire_keg_press()
			elif climb: climb_in()
			elif back: step_away()
		_:
			var c := near_cannon()
			if c == null: return
			if a: operate(c)
			elif climb:
				operate(c)
				climb_in()

# --- Operating, from outside ---------------------------------------------------------

## Where he stands to work `c`: on the ground behind the base, at the breech.
func stand(c: Node3D) -> Vector3:
	var f := PilotMotor.forward(c.yaw())
	return c.global_position-Vector3(f.x,0.0,f.y)*float(c.knobs.stand_back)

## At the breech, working the cannon from outside; the stick aims it.
func operate(c: Node3D) -> void:
	cannon = c
	_last_cannon = c
	mode = "operating"
	motor.mount(self,stand(c),true,c.yaw())
	study.figure.visible = true
	study._yaw = c.yaw()

## A while operating: the next keg from the hover slides into the barrel and
## is fired when it is in; with none in hand, a dry click.
func fire_keg_press() -> bool:
	var c: Node3D = cannon
	if c == null or mode != "operating" or not loading.is_empty(): return false
	if carried.is_empty():
		c.click()
		return false
	var k: Node3D = carried.pop_front()
	k.state = "loaded"
	c.loaded = k
	loading = {"keg":k,"into":c,"t":0.0}
	_sound(&"load",c.pivot())
	return true

## The keg sliding from the hover into the barrel, then out of it.
func _load(delta: float) -> void:
	if loading.is_empty(): return
	var k: Node3D = loading.keg
	var c: Node3D = loading.into
	loading.t = float(loading.t)+delta
	var f := clampf(float(loading.t)/float(knobs.load_time),0.0,1.0)
	k.global_position = k.global_position.lerp(c.pivot(),f)
	if f < 1.0: return
	loading = {}
	fire_keg(c)

## The loaded keg out of `c`'s barrel along the aim; he stays where he is.
func fire_keg(c: Node3D) -> bool:
	if c == null or c.loaded == null: return false
	var k: Node3D = c.loaded
	c.loaded = null
	var v: Vector3 = c.fire()
	k.launch(c.mouth()+Vector3.UP*0.02,v)
	k.set_meta("cross",Vector3.INF)
	k.set_meta("y0",c.global_position.y)
	_flying.append(k)
	_watch = k
	_hold_t = 0.0
	return true

## B while operating: he steps away, on foot where he stood.
func step_away() -> void:
	var c: Node3D = cannon
	cannon = null
	mode = ""
	motor.reset(stand(c),c.yaw())
	study.figure.visible = true

# --- Inside, launching himself -------------------------------------------------------

## Y: into the barrel; the aim and power stay as tested.
func climb_in() -> void:
	var c: Node3D = cannon
	if c == null: return
	mode = "inside"
	motor.feet = c.pivot()
	study.figure.visible = false
	_sound(&"climb",c.pivot())

## B inside: back out to the breech, operating; nothing fired.
func climb_out() -> void:
	if cannon == null: return
	mode = "operating"
	motor.feet = stand(cannon)
	study.figure.visible = true
	_sound(&"climb",cannon.pivot())

## A inside: he is fired along the aim at the power, as a keg would be.
func launch_self() -> bool:
	var c: Node3D = cannon
	if c == null or mode != "inside": return false
	var v: Vector3 = c.fire()
	cannon = null
	mode = ""
	study.figure.visible = true
	motor.dismount(c.mouth(),v)
	return true

## The motor's rider contract: his step while at a cannon. The jump's press
## is ignored (A is read in `_use`); operating, the stick aims.
func ride(m: PilotMotor, delta: float, want: Vector2, _pressed: bool) -> Dictionary:
	var c: Node3D = cannon
	if c == null: return {}
	if mode == "caught":
		# In the barrel; the chase camera swings round to look down the shot.
		m.velocity = Vector3.ZERO
		m.feet = c.pivot()
		study._yaw = lerp_angle(study._yaw,c.yaw(),1.0-exp(-delta*6.0))
		return {}
	if mode == "operating" and loading.is_empty():
		var camera_forward := PilotMotor.forward(c.yaw())
		var right := Vector2(-camera_forward.y,camera_forward.x)
		c.set_aim(c.aim_yaw-want.dot(right)*float(c.knobs.yaw_rate)*delta,c.pitch+want.dot(camera_forward)*float(c.knobs.pitch_rate)*delta)
	study._yaw = c.yaw()
	m.velocity = Vector3.ZERO
	m.facing = c.yaw()
	if mode == "operating":
		m.feet = stand(c)
		m.grounded = true
	else:
		m.feet = c.pivot()
	return {}

# --- The catch -----------------------------------------------------------------------

## The point of him the mouth takes: his middle, a little under his chest.
func _middle(feet: Vector3) -> Vector3:
	return feet+Vector3.UP*float(study.ground.head_top)*0.4

## Whether he can be caught now: in the air, his own or tumbling, not held,
## hanging, swimming or riding anything.
func _catchable() -> bool:
	return mode == "" and motor.rider == null and not motor.grounded and motor.hold == "" and not motor.swimming and not motor.seized()

## Whether `v` goes into `c`'s mouth: against its aim, fast enough, and
## within `catch_cone` of the barrel's axis.
static func _going_in(c: Node3D, v: Vector3) -> bool:
	var into: float = -v.dot(c.direction())
	return into > float(c.knobs.catch_in) and into > v.length()*cos(float(c.knobs.catch_cone))

## The funnel: heading into a mouth within `catch_pull`, his velocity is
## turned toward it at `catch_pull_rate` (his speed kept).
func _funnel(delta: float) -> void:
	if not _catchable(): return
	var p := _middle(motor.feet)
	for c: Node3D in cannons:
		if not c.catching(): continue
		var to: Vector3 = c.mouth()-p
		var d := to.length()
		if d > float(c.knobs.catch_pull) or d < 0.01: continue
		var v := motor.velocity
		var along := to/d
		if v.dot(along) <= 0.0 or not _going_in(c,v): continue
		# In front of the mouth, not behind the breech.
		if (p-c.mouth()).dot(c.direction()) < -float(c.knobs.catch_radius): continue
		# Turned toward the mouth, his speed kept.
		var k := 1.0-exp(-float(c.knobs.catch_pull_rate)*delta)
		motor.velocity = v.lerp(along*v.length(),k).normalized()*v.length()
		return

## After the motor's step: did his middle pass through a mouth this frame?
func _catch_in() -> void:
	if not _catchable() or _feet_was == Vector3.INF: return
	var a := _middle(_feet_was)
	var b := _middle(motor.feet)
	for c: Node3D in cannons:
		if not c.catching() or not _going_in(c,motor.velocity): continue
		var m: Vector3 = c.mouth()
		var ab := b-a
		var t := clampf((m-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
		if (a+ab*t).distance_to(m) <= float(c.knobs.catch_radius):
			catch_body(c)
			return

## Caught by `c`: swallowed, held in the barrel for the beat.
func catch_body(c: Node3D) -> void:
	cannon = c
	_last_cannon = c
	mode = "caught"
	_catch_t = 0.0
	_fire_caught = false
	_caught_stunned = motor.move == "tumble"
	if not _caught_stunned:
		motor.move = ""
		motor.sail.rest()
	catches.append({"cannon":c,"stunned":_caught_stunned,"at":motor.feet,"t":_clock})
	motor.mount(self,c.pivot(),false)
	study.figure.visible = false
	c.swallow()

## The beat: held, then the windup, then the shot (after the motor's step).
func _hold_caught(delta: float) -> void:
	if mode != "caught" or cannon == null: return
	_catch_t += delta
	var hold := float(cannon.knobs.catch_hold)
	var wind := maxf(float(cannon.knobs.catch_windup),1e-3)
	if _catch_t > hold: cannon.set_charge((_catch_t-hold)/wind)
	if _catch_t >= hold+wind: _fire_caught = true

## Fired out along the aim at the power set. Stunned, the cannon knocks him
## as itself (a fresh stun only if it may; else thrown on still stunned);
## poised, a toss, as from climbing in.
func spit() -> bool:
	var c: Node3D = cannon
	if c == null or mode != "caught": return false
	var v: Vector3 = c.fire()
	cannon = null
	mode = ""
	study.figure.visible = true
	var stunned := motor.move == "tumble"
	motor.dismount(c.mouth()-Vector3.UP*float(study.ground.head_top)*0.4,v,c)
	spits.append({"cannon":c,"stunned":stunned,"v":v,"t":_clock})
	return true

## Taken out of the barrel by something else (a knock): let go, no shot.
func _let_go() -> void:
	if cannon != null: cannon.set_charge(0.0)
	cannon = null
	mode = ""
	_fire_caught = false
	study.figure.visible = true

# --- Kegs in flight ------------------------------------------------------------------

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
	if _watch == k:
		_watch = null
		_hold_at = (markers[markers.size()-1].at as Vector3)
		_hold_t = float(knobs.view_hold)

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

# --- The camera ----------------------------------------------------------------------

## After the study's own camera: while he is at a cannon, a view from behind
## and over it looking down the barrel; a keg in flight is followed, its
## landing held on for `view_hold` s, the eye rising with the range so the
## arc and the marker both read. Eased in and out over the study's chase
## camera, so leaving (or being fired) hands back smoothly.
func frame(camera: Camera3D, delta: float) -> void:
	var goal_w := 1.0 if mode == "operating" or mode == "inside" else 0.0
	_view_w = move_toward(_view_w,goal_w,delta/float(knobs.view_ease))
	var c: Node3D = cannon if cannon != null else _last_cannon
	if _view_w <= 0.0 or c == null:
		_eye = Vector3.INF
		return
	var u := _unit
	var f := PilotMotor.forward(c.yaw())
	var flat := Vector3(f.x,0.0,f.y)
	var look: Vector3 = c.mouth()+c.direction()*float(knobs.view_ahead)*u
	if _watch != null and is_instance_valid(_watch) and _watch.state == "flying": look = _watch.global_position
	elif _hold_t > 0.0:
		_hold_t -= delta
		look = _hold_at
	var reach := Vector2(look.x-c.global_position.x,look.z-c.global_position.z).length()
	var eye: Vector3 = c.pivot()-flat*float(knobs.view_back)*u+Vector3.UP*(float(knobs.view_up)*u+reach*float(knobs.view_rise))
	var k := 1.0-exp(-delta/maxf(float(knobs.view_ease)*0.5,1e-3))
	if _eye == Vector3.INF:
		_eye = eye
		_look = look
	else:
		_eye = _eye.lerp(eye,k)
		_look = _look.lerp(look,k)
	var to := _look-_eye
	if to.length() < 0.01: return
	var mine := Transform3D(Basis.looking_at(to.normalized(),Vector3.UP),_eye)
	var w := smoothstep(0.0,1.0,_view_w)
	camera.global_transform = camera.global_transform.interpolate_with(mine,w)

# --- Reset and prompt ----------------------------------------------------------------

func reset() -> void:
	cannon = null
	mode = ""
	loading = {}
	_launch = false
	_fire_caught = false
	_catch_t = 0.0
	_feet_was = Vector3.INF
	catches.clear()
	spits.clear()
	carried.clear()
	_flying.clear()
	heard.clear()
	_watch = null
	_hold_t = 0.0
	_view_w = 0.0
	_eye = Vector3.INF
	for m: Dictionary in markers: (m.node as Node).queue_free()
	markers.clear()
	if motor != null: motor.rider = null
	if study != null and study.get("figure") != null: study.figure.visible = true
	for k: Node3D in kegs: k.lay()
	for c: Node3D in cannons: c.reset()

## The prompt line at a cannon: [keys form, pad form] ("" when none). It
## names what each button does in the mode he is in, the kegs in hand and
## the power notch.
func prompt_lines() -> Array:
	if mode == "caught": return ["",""]
	var c: Node3D = cannon if cannon != null else near_cannon()
	if c == null: return ["",""]
	var held := carried.size()
	var power := "power %d/%d" % [c.power+1,c.knobs.power_notches.size()]
	var kegs_left := "%d kegs" % held if held != 1 else "1 keg"
	match mode:
		"inside":
			return ["Space launch yourself · E climb out · aim and %s as tested · %s" % [power,kegs_left],
				"{walk_jump} launch yourself  ·  {cannon_leave} climb out  ·  aim and %s as tested  ·  %s" % [power,kegs_left]]
		"operating":
			var fire := "loading a keg..."
			var fire_pad := "loading a keg..."
			if loading.is_empty():
				fire = "Space fire a keg (%d left)" % held if held > 0 else "Space fire a keg (none left)"
				fire_pad = "{walk_jump} fire a keg (%d left)" % held if held > 0 else "{walk_jump} fire a keg (none left)"
			return ["WASD aim · , . %s · %s · F climb in · E step away" % [power,fire],
				"{LS} aim  ·  {DPAD} %s  ·  %s  ·  {cannon_climb} climb in  ·  {cannon_leave} step away" % [power,fire_pad]]
	return ["Space operate the cannon · F climb in · %s · %s" % [kegs_left,power],
		"{walk_jump} operate the cannon  ·  {cannon_climb} climb in  ·  %s  ·  %s" % [kegs_left,power]]

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
