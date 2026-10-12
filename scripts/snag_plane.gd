extends Node3D
## The snag (studies/snag_study.gd, docs/design/snag/round1.md): a sky-folk
## pilot flying a fixed, learnable low loop with a part slung on a rope
## under the plane, for the wanderer on foot to snatch.
##
## The plane is the wanderer's own figure (scripts/plane_figure.gd) in a
## sky-traffic livery (scripts/sky_traffic.gd LIVERIES), drawn SCALE times
## its toy size so the load and its rope read from the ground. It flies one
## closed curve, the same every lap (`hook_at`): an ellipse RADII round, its
## height CRUISE over the dip but for a low pass `dip` m over the ledge
## (`over`) at the ellipse's near side, and a shallower sag FAR_DROP m down
## at the far side. Every lap takes `lap` s, so a pass can be watched and
## timed. Heading and pitch follow the curve; the wings bank with the turn
## (BANK by the heading's rate, as the traffic does).
##
## The rope is a verlet chain of LINKS links from the plane's belly (HOOK)
## to the load, `rope` m long, under GRAVITY, losing DRAG of its pace a
## second, the load heavier than a link (LOAD_WEIGHT): so it lags the plane,
## swings out on the banked ends and whips as the nose comes up out of the
## dip. The load is the rune token (scripts/glyph_pickup.gd `make("rune")`).
##
## `snatch` takes the load off the rope: the rope's end flies free, the
## plane lurches (a roll toward the side the load hung and a nose-down jolt,
## ringing out over JOLT_TIME s) and its pilot looks back over his shoulder;
## RESPAWN s on, a new load is on the rope's end.
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const SkyTraffic = preload("res://scripts/sky_traffic.gd")
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")

## A lap (s), the rope (m), the belly's height over the ledge at the dip (m).
const LAP := 26.0
const ROPE := 7.0
const DIP := 8.8
## The loop: its radii (x along the dip's pass, z across), the belly's
## height over the dip's elsewhere (m), the dip's width (rad of the lap),
## the far side's sag (m) and width (rad).
const RADII := Vector2(60.0,36.0)
const CRUISE := 14.0
const DIP_WIDTH := 0.45
const FAR_DROP := 8.0
const FAR_WIDTH := 0.6
## Bank per rad/s of turn, and the most.
const BANK := 2.0
const BANK_MAX := 0.95
## The figure drawn this many times its toy size; the hook under its belly
## (figure frame, before the scale).
const SCALE := 2.5
const HOOK := Vector3(0.0,-0.15,0.02)
## The rope: links, gravity (m/s²), pace lost a second, the load's weight
## against a link's, constraint passes, the sim's step (s).
const LINKS := 10
const GRAVITY := 12.0
const DRAG := 0.2
const LOAD_WEIGHT := 4.0
const PASSES := 12
const STEP := 1.0/120.0
## The load's size (m), seconds till a new one hangs after a snatch.
const LOAD_SIZE := 0.9
## The token hangs this share of its size under the rope's end.
const HANG := 0.6
const RESPAWN := 4.0
## The lurch: roll (rad), pitch (rad, down), sag (m), how long it rings (s)
## and at what rate (Hz).
const JOLT_ROLL := 0.55
const JOLT_PITCH := -0.3
const JOLT_SAG := 1.2
const JOLT_TIME := 1.6
const JOLT_HZ := 1.4

var lap := LAP
var rope := ROPE
var dip := DIP
## The ledge's top at the dip: the plane passes over it heading +x.
var over := Vector3(0.0,10.0,36.0)
## Seconds into the loop (0: over the ledge).
var clock := 0.0
var flight := SkyTraffic.Flight.new()
var figure: Node3D
## The rope's points, hook first, the load's end last.
var points := PackedVector3Array()
var _old := PackedVector3Array()
## Whether the load hangs on the rope.
var attached := true
var load_token: Node3D
var _segments: Array[MeshInstance3D] = []
var _jolt := -1.0
var _jolt_side := 1.0
var _respawn := 0.0
var snatches := 0

## Set up: the loop's lap, rope and dip, the ledge it dips over, and where
## in the lap it starts.
func setup(lap_s: float, rope_m: float, dip_m: float, ledge: Vector3, start_at := 0.0) -> void:
	lap = maxf(lap_s,5.0)
	rope = maxf(rope_m,1.0)
	dip = dip_m
	over = ledge
	clock = start_at

func _ready() -> void:
	name = "SnagPlane"
	figure = PlaneFigure.new(SkyTraffic.LIVERIES[1])
	add_child(figure)
	var mesh := SwingRope._rope_mesh()
	for i in range(LINKS):
		var segment := MeshInstance3D.new()
		segment.mesh = mesh
		segment.scale = Vector3.ONE
		add_child(segment)
		_segments.append(segment)
	_fly(0.0)
	figure.reset(flight)
	_fly(0.0)
	(figure.get("_scarf") as Node3D).visible = false
	_hang()
	_new_load()
	_place()

## The belly's point at `theta` (rad round the lap, 0 over the ledge).
func hook_at(theta: float) -> Vector3:
	return path_point(theta,over,dip)

static func path_point(theta: float, ledge: Vector3, dip_m: float) -> Vector3:
	var centre := ledge-Vector3(0.0,0.0,RADII.y)
	var near := exp(-pow(wrapf(theta,-PI,PI),2.0)/(2.0*DIP_WIDTH*DIP_WIDTH))
	var far := exp(-pow(wrapf(theta-PI,-PI,PI),2.0)/(2.0*FAR_WIDTH*FAR_WIDTH))
	var y := ledge.y+dip_m+CRUISE*(1.0-near)-FAR_DROP*far
	return Vector3(centre.x+RADII.x*sin(theta),y,centre.z+RADII.y*cos(theta))

## Where the load hangs at rest at `theta` (straight under the hook).
static func rest_load(theta: float, ledge: Vector3, dip_m: float, rope_m: float) -> Vector3:
	return path_point(theta,ledge,dip_m)+Vector3.DOWN*rope_m

func theta() -> float:
	return TAU*fposmod(clock,lap)/lap

## Seconds till the next pass over the ledge.
func till_pass() -> float:
	return lap-fposmod(clock,lap)

func hook() -> Vector3:
	return figure.transform*HOOK

## The load's point (its token's middle, hung by its top tip).
func load_point() -> Vector3:
	return points[LINKS]+Vector3.DOWN*LOAD_SIZE*HANG

## How far the rope hangs off plumb (rad).
func swing() -> float:
	return (points[LINKS]-points[0]).angle_to(Vector3.DOWN)

func _process(delta: float) -> void:
	advance(delta)

## One frame: the plane along the loop, the rope stepped, all drawn.
func advance(delta: float) -> void:
	if delta <= 0.0: return
	clock += delta
	var left := delta
	_fly(delta)
	while left > 1e-6:
		var dt := minf(STEP,left)
		_step_rope(dt)
		left -= dt
	if not attached:
		_respawn -= delta
		if _respawn <= 0.0:
			attached = true
			_new_load()
	_place()

func _fly(delta: float) -> void:
	var th := theta()
	var ahead := TAU*0.05/lap
	var at := hook_at(th)
	var v := (hook_at(th+ahead)-at)/0.05
	var v2 := (hook_at(th+ahead*2.0)-hook_at(th+ahead))/0.05
	var heading := atan2(-v.x,-v.z)
	var turn := angle_difference(heading,atan2(-v2.x,-v2.z))/0.05
	flight.heading = heading
	flight.pitch = atan2(v.y,Vector2(v.x,v.z).length())
	flight.bank = clampf(-turn*BANK,-BANK_MAX,BANK_MAX)
	flight.speed = v.length()
	flight.velocity = v
	flight.position = at+Vector3.UP*(0.2-HOOK.y)*SCALE
	if _jolt >= 0.0:
		_jolt += delta
		var ring := sin(TAU*JOLT_HZ*_jolt)*exp(-3.0*_jolt/JOLT_TIME)
		var kick := exp(-3.0*_jolt/JOLT_TIME)
		flight.bank += JOLT_ROLL*_jolt_side*ring
		flight.pitch += JOLT_PITCH*ring
		flight.position.y -= JOLT_SAG*kick*minf(_jolt*8.0,1.0)
		if _jolt > JOLT_TIME*2.0: _jolt = -1.0
	figure.update(delta,flight,0.0,Callable(),false)
	figure.transform = PlaneFigure.pose(flight.position,flight.heading,flight.pitch,flight.bank).scaled_local(Vector3.ONE*SCALE)
	figure.transform.origin = flight.position+Vector3.DOWN*0.2*SCALE

## The rope straight down from the hook.
func _hang() -> void:
	points.resize(LINKS+1)
	_old.resize(LINKS+1)
	var top := hook()
	for i in range(LINKS+1):
		points[i] = top+Vector3.DOWN*rope*float(i)/LINKS
		_old[i] = points[i]

func _step_rope(dt: float) -> void:
	var keep := 1.0-DRAG*dt
	for i in range(1,LINKS+1):
		var p := points[i]
		var v := (p-_old[i])*keep
		_old[i] = p
		points[i] = p+v+Vector3.DOWN*GRAVITY*dt*dt
	var link := rope/LINKS
	for _pass in range(PASSES):
		points[0] = hook()
		for i in range(LINKS):
			var a := points[i]
			var b := points[i+1]
			var d := b-a
			var length := d.length()
			if length < 1e-5: continue
			var wa := 0.0 if i == 0 else 1.0
			var wb := 1.0/LOAD_WEIGHT if i+1 == LINKS and attached else 1.0
			var fix := d*(length-link)/length/(wa+wb)
			points[i] = a+fix*wa
			points[i+1] = b-fix*wb
	points[0] = hook()

## Takes the load off the rope (the wanderer's grab): the token, for the
## caller to carry; the plane lurches and its pilot looks back.
func snatch() -> Node3D:
	if not attached or load_token == null: return null
	attached = false
	snatches += 1
	_respawn = RESPAWN
	_jolt = 0.0
	var right := figure.transform.basis.x.normalized()
	_jolt_side = signf((points[LINKS]-hook()).dot(right))
	if _jolt_side == 0.0: _jolt_side = 1.0
	var rig: Node = figure.get("_rig")
	if rig != null:
		rig.set("_idle","look_back")
		rig.set("_idle_left",2.2)
		rig.set("_idle_look",Vector2(1.9*_jolt_side,0.15))
	# The torn end springs up a little as the weight comes off.
	_old[LINKS] = points[LINKS]+Vector3.DOWN*0.15
	var token := load_token
	load_token = null
	return token

func _new_load() -> void:
	load_token = GlyphPickup.make("rune",LOAD_SIZE)
	add_child(load_token)
	load_token.scale = Vector3.ONE*0.05
	create_tween().tween_property(load_token,"scale",Vector3.ONE,0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The rope's links and the load drawn where the sim has them.
func _place() -> void:
	for i in range(LINKS):
		_segments[i].transform = Transform3D(SwingRope._segment_basis(points[i],points[i+1]).scaled_local(Vector3(1.6,1.0,1.6)),points[i])
	if load_token != null:
		load_token.position = load_point()
