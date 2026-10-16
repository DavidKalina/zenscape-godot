extends "res://scripts/traps/trap.gd"
## The hung stair's runtime (scripts/ruin_kit_keel.gd builds the stone and
## adds this as its "Rig"): it turns the flight about its hinge. Built to
## the trap contract (scripts/traps/trap.gd: knobs, the tell, `reset`),
## and it steps itself each frame (`auto`), so a piece placed anywhere (the
## motif editor, an authored place, a study) runs live with no host: it
## hears the slam by its group (scripts/slam.gd GROUP) and finds the
## pilot's motor on the scene (`motor`, or `watch(motor)` from a host).
##
## States: "hung" (the soffit up: a slide), "turned" (the treads up: a
## walked flight), and between them "tell" (it grinds and sheds grit for
## `tell` s, shuddering) and "turn" (`turn` s, eased as trap_flip's flip).
## Triggers: a slam of at least `slam` strength whose ring reaches the
## boss turns it hung -> turned; a slam while turned starts its `hold`
## over. Turned, after `hold` s it tells and turns back (never, `latch`).
## `start` "hung" or "turned"; `reset` puts it back there.
##
## Riding (trap_flip's rule): the flight's body is moving ground, so the
## motor carries him on it as it turns (his feet or his hands on a lip);
## stood on it once it has turned past `knock_angle` (deg) since the turn
## began, he is thrown off along the swing with the flight's own pace at
## his feet, up a little and out `knock` m/s: a `toss` while that pace is
## under `knock_pace`, a `knock` (this piece the source) past it. Hanging
## from it he is carried round and keeps his hold.
const Slam = preload("res://scripts/slam.gd")

const S_HUNG := 0
const S_TELL := 1
const S_TURN := 2
const S_TURNED := 3
const STATE_NAMES := ["hung","tell","turn","turned"]

## The piece (its root), its pivot and the flight's body.
var piece: Node3D
var pivot: Node3D
var body: StaticBody3D
var axis_from := Vector3.ZERO
var axis_dir := Vector3.RIGHT
var hung_angle := 0.0
var boss := Vector3.ZERO
## Steps itself in `_process` (off: a host calls `step(delta)`).
var auto := true

var state := S_HUNG
## Where it is turned to (rad about the axis, 0 right way up) and the turn
## in hand: from, to, its clock; the state's clock.
var angle := 0.0
var _from := 0.0
var _to := 0.0
var _t := 0.0
## Where it goes once the tell ends (S_TURNED or S_HUNG).
var _going := S_TURNED
var _thrown := false
var _seek := 0
## Turns made and pilots thrown (counts).
var turns := 0
var knocks := 0
var grit: CPUParticles3D

func _init() -> void:
	super()
	trap_name = "keel_hung_stair"
	cost = 2
	under = "void"
	verbs = PackedStringArray(["slam","run","slide"])

func defaults() -> Dictionary:
	var p := pilot()
	return {"start":"hung","hold":12.0,"latch":false,"tell":0.5,"turn":1.2,
		"knock_angle":70.0,"knock":p.walk*0.8,"knock_pace":p.run*1.2,"slam":Slam.decent(),
		"trigger":["slam"]}

## The piece it turns: reads the pivot, axis and boss from it.
func bind(root: Node3D) -> void:
	piece = root
	pivot = root.get_node("Pivot")
	body = root.get_node("Pivot/Flight/Body")
	var ax: Array = root.get_meta("axis")
	axis_from = ax[0]
	axis_dir = ((ax[1] as Vector3)-(ax[0] as Vector3)).normalized()
	hung_angle = float(root.get_meta("hung_angle"))
	boss = root.get_meta("boss")
	_start()

## The flight's turn about its hinge at `a`.
func _pose(a: float) -> void:
	if pivot == null: return
	pivot.transform = Transform3D(Basis(axis_dir,a),axis_from)

func _start() -> void:
	state = S_TURNED if str(knob("start")) == "turned" else S_HUNG
	angle = 0.0 if state == S_TURNED else hung_angle
	_t = 0.0
	_pose(angle)

## Set before it is in the tree (as `configure`), then posed.
func configure(over: Dictionary) -> Node3D:
	super(over)
	if pivot != null: _start()
	return self

func _ready() -> void:
	add_to_group(Slam.GROUP)
	grit = _grit()
	add_child(grit)

## A host's pilot (else the scene's `motor` is looked up).
func watch(m: PilotMotor) -> void:
	motor = m

func state_name() -> String:
	return STATE_NAMES[state]

func _process(delta: float) -> void:
	if auto: step(delta)

## One frame: the tell, the turn (carrying and throwing), the hold.
func step(delta: float) -> void:
	if pivot == null or delta <= 0.0: return
	_find_motor()
	_t += delta
	var shudder := 0.0
	var loud := 0.0
	match state:
		S_TELL:
			loud = clampf(_t/maxf(float(knob("tell")),0.01),0.0,1.0)
			shudder = sin(_t*70.0)*0.012*loud
			if _t >= float(knob("tell")): _begin_turn()
		S_TURN:
			var u := clampf(_t/maxf(float(knob("turn")),0.02),0.0,1.0)
			angle = lerpf(_from,_to,_ease(u))
			loud = 1.0-u
			_ride(u)
			if u >= 1.0:
				angle = _to
				state = _going
				_t = 0.0
				turns += 1
				tell_sound(&"thud",_world(boss))
		S_TURNED:
			if not bool(knob("latch")) and _t >= float(knob("hold")): _tell(S_HUNG)
	_pose(angle+shudder)
	grit.emitting = state == S_TELL or state == S_TURN
	tell_sight(loud)

## Trap_flip's ease (smoothstep).
static func _ease(u: float) -> float:
	return u*u*(3.0-2.0*u)

func _tell(going: int) -> void:
	state = S_TELL
	_going = going
	_t = 0.0
	tell_sound(&"grind",_world(boss))

func _begin_turn() -> void:
	state = S_TURN
	_t = 0.0
	_thrown = false
	_from = angle
	_to = 0.0 if _going == S_TURNED else hung_angle

## Turns it now (as a slam on the boss does): hung, it tells and turns;
## turned, its hold starts over.
func trigger() -> void:
	if state == S_HUNG: _tell(S_TURNED)
	elif state == S_TURNED: _t = 0.0
	elif state == S_TELL and _going == S_HUNG:
		state = S_TURNED
		_t = 0.0

## The slam (scripts/slam.gd `blast`): its ring reaching the boss, hard
## enough.
func slam(at: Vector3, radius: float, strength: float) -> void:
	if not "slam" in (knob("trigger") as Array): return
	if strength < float(knob("slam")): return
	if Slam.share(at,radius,_world(boss)) <= 0.0: return
	trigger()

func _world(p: Vector3) -> Vector3:
	return piece.global_transform*p if piece != null and piece.is_inside_tree() else p

## The pilot on the flight as it turns: carried by the motor (moving
## ground); past `knock_angle`, thrown along the swing (trap_flip's rule).
func _ride(u: float) -> void:
	if _thrown or motor == null or not _on_it(): return
	var turned := absf(angle-_from)
	if turned < deg_to_rad(float(knob("knock_angle"))): return
	_thrown = true
	var omega := (_to-_from)*6.0*u*(1.0-u)/maxf(float(knob("turn")),0.02)
	var g := piece.global_transform
	var w_axis := (g.basis*axis_dir).normalized()
	var w_from := g*axis_from
	var tangent := (w_axis*omega).cross(motor.feet-w_from)
	var flat := Vector3(tangent.x,0.0,tangent.z)
	var out := flat.normalized()*float(knob("knock")) if flat.length() > 0.05 else Vector3.ZERO
	var up := sqrt(2.0*motor.gravity*float(motor.jumps[0])*0.5)
	var push := tangent+out+Vector3.UP*up
	if tangent.length() > float(knob("knock_pace")): motor.knock(push,piece)
	else: motor.toss(push)
	knocks += 1

## He stands on the flight (not hanging from it).
func _on_it() -> bool:
	if not motor.grounded or motor.hold != "": return false
	var under: Node3D = motor.platform
	return under != null and is_instance_valid(under) and (under == body or body.is_ancestor_of(under))

func _find_motor() -> void:
	if motor != null: return
	_seek -= 1
	if _seek > 0: return
	_seek = 30
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene != null and "motor" in scene:
		var m: Variant = scene.get("motor")
		if m is PilotMotor: motor = m

func reset() -> void:
	super()
	turns = 0
	knocks = 0
	_start()

## Grit off the flight's hinge while it tells and turns: small stone
## motes falling.
func _grit() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Grit"
	p.amount = 40
	p.lifetime = 1.4
	p.emitting = false
	p.local_coords = false
	var mote := BoxMesh.new()
	mote.size = Vector3.ONE*0.05
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("6b6158")
	m.roughness = 1.0
	mote.material = m
	p.mesh = mote
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var length := 1.0
	if piece != null:
		var ax: Array = piece.get_meta("axis")
		length = ((ax[1] as Vector3)-(ax[0] as Vector3)).length()
		var mid := ((ax[0] as Vector3)+(ax[1] as Vector3))*0.5
		p.position = mid
		p.basis = Basis(Vector3.UP,atan2(-axis_dir.z,axis_dir.x))
	p.emission_box_extents = Vector3(length*0.45,0.1,0.3)
	p.direction = Vector3.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0.0,-9.0,0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	return p
