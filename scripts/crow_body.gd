extends Node3D
## One crow's body, for the kit isles' birds (scripts/kit_isle/kit_birds.gd,
## species "crow"). Built in code like the guacharo (scripts/enemies/
## guacharo_look.gd): merged ellipsoids for the body and the head, a heavy
## beak whose lower mandible opens (the caw), dark eyes, scaly legs that
## keep the feet on the stone, and real feathers (each a quad drawn by
## shaders/crow.gdshader: charcoal, a faint oily sheen, worn brown tips,
## ragged split edges): a folded wing each side for sitting, and for flight
## a wing of an arm and a hand of fingered primaries on a shoulder and a
## wrist; a tail that fans; shaggy throat hackles.
##
## Local frame: the feet at the origin, -Z forward, +Y up; built at a
## carrion crow's size (about 45 cm bill to tail, 90 cm across the wings)
## and drawn at SIZE of that.
##
## `apply(p)` sets a pose (any key missing keeps its REST value);
## `animate(bird, delta, yaw)` reads a kit bird's state (it changes none of
## it) and plays the crow's moves: heavy flaps and glides, the launch, the
## flare and the touchdown squash, the hop with one flap, the head's snaps
## and tilts, the caw, the tail flick, the peck.
const SHADER = preload("res://shaders/crow.gdshader")

const SIZE := 0.8
const SPECIES := {"crow":{"title":"Crow"}}
## The hip (the body's pivot) over the feet.
const HIP := Vector3(0.0,0.085,0.012)
const SHOULDER := Vector3(0.036,0.13,-0.045)
const NECK := Vector3(0.0,0.14,-0.09)
const TAIL_AT := Vector3(0.0,0.1,0.085)

## Pose keys: pitch (nose up), bank (rolled, + the right wing up), lift
## (m), crouch (0..1, the body down on its legs), stretch (>1 tall, <1
## squashed), head_yaw, head_tilt (cocked), head_nod (beak down), neck
## (0..1 thrust forward), jaw (0..1 open), tail_up, tail_fan (0..1),
## open (0 folded wings, 1 the flight wing), elev, sweep, wrist, droop,
## spread (the primaries' fan 0..1), legs (0 stood, 1 tucked, -1 reaching),
## flick (the folded wings out a touch).
const REST := {"pitch":0.3,"bank":0.0,"lift":0.0,"crouch":0.0,"stretch":1.0,
	"head_yaw":0.0,"head_tilt":0.0,"head_nod":0.0,"neck":0.0,"jaw":0.0,
	"tail_up":0.0,"tail_fan":0.1,"open":0.0,"elev":0.1,"sweep":0.0,"wrist":0.12,"droop":-0.1,"spread":1.0,
	"legs":0.0,"flick":0.0}
## The flight wing as it folds in (open 0).
const TUCK := {"elev":0.35,"sweep":1.0,"wrist":1.1,"droop":0.1,"spread":0.0}
const WING_KEYS := ["elev","sweep","wrist","droop","spread"]
## Flaps a second: cruising, the launch, the flare.
const FLAP_RATE := 4.2
const LAUNCH_RATE := 5.6
const FLARE_RATE := 6.5

static var _feather_mat: ShaderMaterial
static var _body_mat: ShaderMaterial
static var _meshes := {}

var species := "crow"
var pose: Dictionary = REST.duplicate()
var tail_flick := 0.0

var _root: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _tail: MeshInstance3D
var _folded: Array[MeshInstance3D] = []
var _shoulders: Array[Node3D] = []
var _wrists: Array[Node3D] = []
var _hands: Array[MeshInstance3D] = []
var _arms: Array[MeshInstance3D] = []
var _shins: Array[MeshInstance3D] = []
var _feet: Array[Node3D] = []

# The animation's own state (never the bird's).
var _rng := RandomNumberGenerator.new()
var _was := ""
var _clock := 0.0
var _launch := -1.0
var _touch := -1.0
var _touch_hard := 1.0
var _phase := 0.0
var _amp := 0.0
var _glide := 0.0
var _beats_left := 4
var _look := 0.0
var _look_v := 0.0
var _look_goal := 0.0
var _tilt := 0.0
var _tilt_goal := 0.0
var _caw := -1.0
var _caw_next := 6.0
var _caws := 2
var _bank := 0.0
var _yaw := 0.0
var _flick := 0.0

func build(kind: String) -> void:
	species = kind if SPECIES.has(kind) else "crow"
	scale = Vector3.ONE*SIZE
	var m := meshes()
	_root = Node3D.new()
	_root.name = "Body"
	add_child(_root)
	_part(_root,m.body,body_material())
	_neck = Node3D.new()
	_neck.position = NECK-HIP
	_root.add_child(_neck)
	_head = Node3D.new()
	_head.position = Vector3(0.0,0.03,-0.02)
	_neck.add_child(_head)
	_part(_head,m.head,body_material())
	_part(_head,m.hackles,feather_material())
	_jaw = Node3D.new()
	_jaw.position = Vector3(0.0,-0.012,-0.036)
	_head.add_child(_jaw)
	_part(_jaw,m.jaw,body_material())
	_tail = _part(_root,m.tail,feather_material())
	_tail.position = TAIL_AT-HIP
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var folded := _part(_root,m.folded[i],feather_material())
		_folded.append(folded)
		var mirror := Node3D.new()
		mirror.scale = Vector3(side,1.0,1.0)
		_root.add_child(mirror)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(SHOULDER.x,SHOULDER.y-HIP.y,SHOULDER.z-HIP.z)
		mirror.add_child(shoulder)
		_arms.append(_part(shoulder,m.arm,feather_material()))
		var wrist := Node3D.new()
		wrist.position = Vector3(0.125,0.0,0.0)
		shoulder.add_child(wrist)
		_hands.append(_part(wrist,m.hand,feather_material()))
		_shoulders.append(shoulder)
		_wrists.append(wrist)
		var shin := _part(self,m.shin,body_material())
		_shins.append(shin)
		var foot := Node3D.new()
		add_child(foot)
		_part(foot,m.toes,body_material())
		_feet.append(foot)
	_rng.seed = hash(get_instance_id())
	_caw_next = _rng.randf_range(3.0,16.0)
	apply(REST)

func _part(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	parent.add_child(part)
	return part

## No-ops the songbirds' perch ride asks for (crows sit on stone).
func spread_wings(_out: bool) -> void:
	pass

static func title(kind: String) -> String:
	return str(SPECIES.get(kind,SPECIES.crow).title)

static func feather_material() -> ShaderMaterial:
	if _feather_mat == null:
		_feather_mat = ShaderMaterial.new()
		_feather_mat.shader = SHADER
	return _feather_mat

static func body_material() -> ShaderMaterial:
	if _body_mat == null:
		_body_mat = ShaderMaterial.new()
		_body_mat.shader = SHADER
		_body_mat.set_shader_parameter("is_body",1.0)
	return _body_mat

# --- Posing ----------------------------------------------------------------------------

## Sets the pose: `p`'s keys over REST's.
func apply(p: Dictionary) -> void:
	for k: String in REST:
		pose[k] = float(p.get(k,REST[k]))
	var st: float = pose.stretch
	var crouch: float = pose.crouch
	_root.position = HIP+Vector3(0.0,float(pose.lift)-crouch*0.032,crouch*0.006)
	_root.basis = Basis.from_euler(Vector3(float(pose.pitch),0.0,float(pose.bank)))*Basis.from_scale(Vector3(1.0/sqrt(st),st,1.0/sqrt(st)))
	var neck: float = pose.neck
	_neck.position = NECK-HIP+Vector3(0.0,-neck*0.014,-neck*0.022)
	_head.basis = Basis(Vector3.UP,float(pose.head_yaw))*Basis(Vector3.RIGHT,-float(pose.head_nod))*Basis(Vector3.BACK,float(pose.head_tilt))
	_jaw.rotation = Vector3(-float(pose.jaw)*0.5,0.0,0.0)
	_tail.rotation = Vector3(-float(pose.tail_up),0.0,0.0)
	_tail.set_instance_shader_parameter("spread",float(pose.tail_fan))
	var open: float = pose.open
	var wing := {}
	for k: String in WING_KEYS: wing[k] = lerpf(float(TUCK[k]),float(pose[k]),smoothstep(0.0,1.0,open))
	var flying := open > 0.3
	var flick: float = pose.flick
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		_folded[i].visible = not flying
		_folded[i].basis = Basis(Vector3.BACK,side*flick*0.22)*Basis(Vector3.UP,-side*flick*0.08)
		_folded[i].position = Vector3(side*flick*0.006,flick*0.004,0.0)
		_shoulders[i].get_parent().visible = flying
		_shoulders[i].basis = Basis(Vector3.UP,-float(wing.sweep))*Basis(Vector3.BACK,float(wing.elev))
		_wrists[i].basis = Basis(Vector3.UP,-float(wing.wrist))*Basis(Vector3.BACK,float(wing.droop))
		_hands[i].set_instance_shader_parameter("spread",float(wing.spread))
		_arms[i].set_instance_shader_parameter("spread",1.0)
	_place_legs()

## The legs: each foot on the stone (stood), tucked back under the tail, or
## reaching forward (landing); the shin from the foot up into the belly.
func _place_legs() -> void:
	var legs: float = pose.legs
	var body := _root.transform
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var hip := body*Vector3(side*0.016,-0.012,0.004)
		var stood := Vector3(side*0.02,0.0,0.004)
		var foot := stood
		if legs >= 0.0: foot = stood.lerp(body*Vector3(side*0.012,-0.03,0.06),legs)
		else: foot = stood.lerp(body*Vector3(side*0.022,-0.07,-0.03),-legs)
		var up := hip-foot
		var length := maxf(up.length(),0.004)
		var y := up/length
		var x := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.BACK
		var z := x.cross(y).normalized()
		x = y.cross(z).normalized()
		_shins[i].transform = Transform3D(Basis(x,y*length,z),foot)
		_feet[i].transform = Transform3D(Basis(Vector3.RIGHT,-1.3*legs if legs > 0.0 else -0.3*legs),foot)

## Blends poses `a` and `b` at `t`.
static func mix_pose(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k: String in REST:
		out[k] = lerpf(float(a.get(k,REST[k])),float(b.get(k,REST[k])),t)
	return out

# --- Animating ---------------------------------------------------------------------------

const AIR := ["flying","landing","wheeling","leaving"]

## Plays the crow from a kit bird (scripts/kit_isle/kit_birds.gd), placed
## at its spot facing `yaw`. Reads the bird; writes nothing back.
func animate(bird: Dictionary, delta: float, yaw: float) -> void:
	_clock += delta
	var state := str(bird.state)
	var airborne := state in AIR
	var was_air := _was in AIR
	if _was != "" and airborne and not was_air:
		_launch = 0.0
		_phase = 0.9
		_amp = 1.0
		_caw = -1.0
	if _was != "" and not airborne and was_air:
		_touch = 0.0
		_touch_hard = 1.0
	if _was == "hopping" and state == "perched":
		_touch = 0.0
		_touch_hard = 0.6
	if _was == "" and airborne: _amp = 1.0
	_was = state
	if _launch >= 0.0:
		_launch += delta
		if _launch > 1.2: _launch = -1.0
	if _touch >= 0.0:
		_touch += delta
		if _touch > 0.8: _touch = -1.0
	var turn := wrapf(yaw-_yaw,-PI,PI)/maxf(delta,0.001)
	_yaw = yaw
	global_basis = Basis(Vector3.UP,yaw)*Basis.from_scale(Vector3.ONE*SIZE)
	_flick = maxf(_flick,tail_flick)
	tail_flick = 0.0
	var want: Dictionary
	if airborne: want = _flight(bird,delta,turn)
	else: want = _sitting(bird,state,delta)
	# The flick of the tail (asked for by the bird): up and fanned, the
	# wings out a touch, a bob.
	if _flick > 0.0:
		var f := sin(minf(_flick,1.0)*PI)
		want.tail_up = float(want.get("tail_up",0.0))+0.45*f
		want.tail_fan = float(want.get("tail_fan",0.1))+0.6*f
		want.flick = float(want.get("flick",0.0))+0.6*f
		want.crouch = float(want.get("crouch",0.0))+0.2*f
		_flick = maxf(_flick-delta*4.0,0.0)
	var t := 1.0-exp(-delta*22.0)
	var wing_t := 1.0-exp(-delta*60.0) if airborne else t
	var next := {}
	for k: String in REST:
		var goal := float(want.get(k,REST[k]))
		next[k] = lerpf(float(pose[k]),goal,wing_t if k in WING_KEYS or k in ["lift","bank"] else t)
	next.head_yaw = _look
	next.head_tilt = lerpf(float(pose.head_tilt),float(want.get("head_tilt",0.0)),1.0-exp(-delta*16.0))
	apply(next)

## In the air: heavy flaps (the down-stroke the stronger, the hand flexed
## back on the up), glides between bouts of them once cruising, banked into
## turns; the launch thrown up and nose-high; the flare to land.
func _flight(bird: Dictionary, delta: float, turn: float) -> Dictionary:
	var v: Vector3 = bird.v
	var flat := Vector2(v.x,v.z).length()
	var state := str(bird.state)
	var landing := state == "landing"
	var launching := _launch >= 0.0 and _launch < 0.75
	var rate := FLAP_RATE
	var flap := true
	if landing: rate = FLARE_RATE
	elif launching: rate = lerpf(LAUNCH_RATE,FLAP_RATE,_launch/0.75)
	elif v.y < 0.6 and flat > 2.6:
		# Cruising: some beats, then a glide.
		if _glide > 0.0:
			_glide -= delta
			flap = false
		elif _beats_left <= 0:
			_glide = _rng.randf_range(0.45,1.3)
			_beats_left = _rng.randi_range(3,6)
	var before := _phase
	if flap or _amp > 0.05: _phase = fmod(_phase+delta*rate,1.0)
	if _phase < before and flap: _beats_left -= 1
	# A glide waits for the wing to come level (mid down-stroke).
	var level := absf(_phase-0.3) < 0.08
	_amp = move_toward(_amp,1.0 if flap else (0.0 if level or _amp < 0.6 else _amp),delta*(7.0 if flap else 5.0))
	var p := {"open":1.0,"legs":1.0,"tail_fan":0.35,"tail_up":0.05,"head_nod":-0.12,"jaw":0.0,"crouch":0.0,"stretch":1.0}
	p.pitch = clampf(atan2(v.y,maxf(flat,0.5))*0.55,-0.5,0.55)
	_bank = lerpf(_bank,clampf(turn*0.14,-0.55,0.55),1.0-exp(-delta*6.0))
	p.bank = _bank
	var stroke := _stroke(_phase)
	var glide := {"elev":0.07,"sweep":0.02,"wrist":0.12,"droop":-0.14,"spread":1.0}
	var amp := _amp
	if launching: amp *= lerpf(1.3,1.0,_launch/0.75)
	for k: String in WING_KEYS:
		p[k] = lerpf(float(glide[k]),float(stroke[k]),clampf(amp,0.0,1.0))
	if amp > 1.0:
		p.elev = float(p.elev)*amp
	# The body rides against the stroke.
	p.lift = -0.007*amp*sin(_phase*TAU)
	p.tail_fan = lerpf(0.6,0.3,amp)
	if launching:
		var k := 1.0-_launch/0.75
		p.pitch = float(p.pitch)+0.4*k
		p.legs = smoothstep(0.05,0.3,_launch)
		p.stretch = 1.0+0.12*k
		p.tail_fan = 0.7
		p.tail_up = -0.2*k
	if landing:
		# The flare: nose up, short quick beats with the wings forward,
		# the tail fanned and down, the feet out.
		p.pitch = 0.75
		p.elev = 0.4+0.45*sin(_phase*TAU)
		p.sweep = -0.3
		p.wrist = 0.05+0.2*maxf(-sin(_phase*TAU),0.0)
		p.droop = -0.1
		p.spread = 1.0
		p.tail_fan = 1.0
		p.tail_up = -0.45
		p.legs = -1.0
		p.head_nod = -0.35
		p.bank = 0.0
	_look_spring(0.0,delta)
	return p

## One flap at `phase` (0..1): the down-stroke over 0..0.55, the up-stroke
## after, with the hand flexed back and the fan half closed.
static func _stroke(phase: float) -> Dictionary:
	if phase < 0.55:
		var s := smoothstep(0.0,1.0,phase/0.55)
		var mid := sin(s*PI)
		return {"elev":lerpf(0.95,-0.62,s),"sweep":-0.12*mid,"wrist":0.08,"droop":-0.3*mid,"spread":1.0}
	var s := smoothstep(0.0,1.0,(phase-0.55)/0.45)
	var mid := sin(s*PI)
	return {"elev":lerpf(-0.62,0.95,s),"sweep":0.3*mid,"wrist":0.12+0.95*mid,"droop":0.35*mid,"spread":1.0-0.55*mid}

## On the stone or the turf: sat a little nose-up, the head snapping between
## glances (cocked now and then), breathing, a caw now and then; the hop
## (crouch, a leap with one flap, the feet reaching); the peck; the
## touchdown's squash with the wings lifted and folded in.
func _sitting(bird: Dictionary, state: String, delta: float) -> Dictionary:
	var p := {"open":0.0,"legs":0.0,"pitch":0.3,"tail_fan":0.08,"tail_up":0.0}
	p.stretch = 1.0+0.012*sin(_clock*TAU*0.7)
	var goal := float(bird.get("look_goal",0.0))
	if not is_equal_approx(goal,_look_goal):
		_look_goal = goal
		_tilt_goal = (_rng.randf_range(0.25,0.5)*(1.0 if _rng.randf() < 0.5 else -1.0)) if _rng.randf() < 0.45 else 0.0
	_look_spring(goal*0.9,delta)
	p.head_tilt = _tilt_goal
	if state == "hopping":
		var t := clampf(float((bird.hop as Dictionary).get("t",0.0)),0.0,1.0)
		var air := sin(t*PI)
		p.crouch = 0.7*(1.0-smoothstep(0.0,0.18,t))+0.5*smoothstep(0.8,1.0,t)
		p.stretch = 1.0+0.16*air
		p.open = smoothstep(0.04,0.18,t)*(1.0-smoothstep(0.7,0.95,t))
		p.elev = lerpf(0.9,-0.45,smoothstep(0.12,0.6,t))
		p.sweep = -0.05
		p.wrist = 0.3
		p.spread = 0.75
		p.legs = 0.45*air if t < 0.6 else lerpf(0.3,-0.7,smoothstep(0.6,0.9,t))
		p.pitch = 0.15+0.25*smoothstep(0.6,1.0,t)
		p.tail_fan = 0.6*air
		p.tail_up = -0.2*air
		p.head_tilt = 0.0
	elif state == "ground":
		p.pitch = 0.1
		var hop: Dictionary = bird.hop
		if not hop.is_empty():
			var t := clampf(float(hop.get("t",0.0)),0.0,1.0)
			var air := sin(t*PI)
			p.crouch = 0.45*(1.0-air)
			p.stretch = 1.0+0.08*air
			p.legs = 0.25*air
			p.flick = 0.3*air
			p.tail_up = 0.15*air
		else:
			# The peck: the head jabbed down, the body tipping after it.
			var jab := maxf(0.0,sin(float(bird.get("peck",0.0))*9.0))
			jab = pow(jab,0.6)
			p.head_nod = 1.0*jab
			p.neck = 0.9*jab
			p.pitch = 0.1-0.4*jab
			p.tail_up = 0.25*jab
			p.crouch = 0.15*jab
	else:
		_caw_step(p,delta)
	# The touchdown: a squash that springs back, the wings lifted and folding.
	if _touch >= 0.0:
		var t := _touch
		var spring := exp(-t*8.0)*cos(t*15.0)
		p.stretch = float(p.stretch)-0.2*_touch_hard*spring
		p.crouch = float(p.get("crouch",0.0))+0.8*_touch_hard*maxf(spring,0.0)
		p.tail_up = float(p.tail_up)+0.35*_touch_hard*maxf(spring,0.0)
		p.tail_fan = maxf(float(p.tail_fan),0.8*_touch_hard*(1.0-smoothstep(0.1,0.45,t)))
		if _touch_hard > 0.8:
			p.open = 1.0-smoothstep(0.08,0.32,t)
			p.elev = 0.75
			p.sweep = 0.4
			p.wrist = 0.6
			p.spread = 0.4
			p.legs = 0.0
			p.pitch = 0.3+0.35*exp(-t*10.0)
		if t > 0.32 and t-delta <= 0.32: _flick = 0.8
	return p

## A caw now and then while sat: the head thrown up, then thrust forward
## and down with the beak open, the tail lifting and fanned, the body
## bobbing, two or three times.
func _caw_step(p: Dictionary, delta: float) -> void:
	if _caw < 0.0:
		if _touch >= 0.0: return
		_caw_next -= delta
		if _caw_next <= 0.0:
			_caw = 0.0
			_caws = _rng.randi_range(2,3)
			_caw_next = _rng.randf_range(9.0,22.0)
		return
	_caw += delta
	var one := 0.42
	var lead := 0.14
	if _caw < lead:
		var a := smoothstep(0.0,1.0,_caw/lead)
		p.head_nod = -0.3*a
		p.stretch = float(p.stretch)+0.06*a
		p.pitch = 0.35
		return
	var u := (_caw-lead)/one
	if u >= float(_caws):
		_caw = -1.0
		return
	var c := fmod(u,1.0)
	# Each caw: thrust (0..0.25), held (..0.55), back (..1).
	var k := smoothstep(0.0,0.22,c)*(1.0-smoothstep(0.55,0.95,c))
	p.head_nod = lerpf(-0.15,0.5,k)
	p.neck = 0.9*k
	p.jaw = smoothstep(0.08,0.2,c)*(1.0-smoothstep(0.45,0.6,c))
	p.pitch = 0.3-0.3*k
	p.tail_up = 0.4*k
	p.tail_fan = 0.08+0.45*k
	p.flick = 0.55*k
	p.crouch = 0.3*k
	p.head_tilt = 0.0

## The head's yaw: a quick snap that overshoots a touch and settles.
func _look_spring(goal: float, delta: float) -> void:
	var steps := maxi(1,ceili(delta/0.008))
	var h := delta/steps
	for _i in range(steps):
		_look_v += ((goal-_look)*700.0-_look_v*30.0)*h
		_look += _look_v*h

# --- Building it -----------------------------------------------------------------------

## The shared meshes: body, head, jaw, hackles, tail, folded [left, right],
## arm, hand, shin, toes.
static func meshes() -> Dictionary:
	if not _meshes.is_empty(): return _meshes
	var plume := Color(0,0,0,1)
	var eye := Color(1,0,0,1)
	var horn := Color(0,1,0,1)
	var scale_c := Color(0,0,1,1)
	# The body about the hip: one faceted hull, rump to neck, keeled under
	# the breast and ridged along the back, flat planes catching the light.
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(body,[[0.13,0.104,0.004,0.004,0.004],[0.11,0.106,0.018,0.012,0.012],[0.07,0.11,0.036,0.024,0.03],[0.02,0.116,0.048,0.032,0.048],
		[-0.03,0.122,0.048,0.033,0.054],[-0.07,0.132,0.042,0.03,0.048],[-0.1,0.146,0.033,0.028,0.034],[-0.128,0.162,0.026,0.024,0.028]],-HIP,plume)
	# The head: a flat crown, the forehead sloping straight into the beak,
	# the eyes, the upper mandible.
	var head := SurfaceTool.new()
	head.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(head,[[0.04,0.0,0.004,0.004,0.004],[0.03,0.0,0.016,0.014,0.016],[0.012,0.002,0.029,0.028,0.03],[-0.012,0.002,0.03,0.028,0.028],
		[-0.03,-0.003,0.021,0.017,0.02],[-0.04,-0.004,0.014,0.013,0.01]],Vector3.ZERO,plume)
	for side: float in [-1.0,1.0]:
		_ellipsoid(head,Vector3(side*0.0235,0.007,-0.02),Vector3(0.01,0.01,0.01),eye,6,4)
	_mandible(head,Vector3(0.0,-0.012,-0.036),0.062,0.026,0.024,1.0,horn)
	var jaw := SurfaceTool.new()
	jaw.begin(Mesh.PRIMITIVE_TRIANGLES)
	_mandible(jaw,Vector3.ZERO,0.056,0.022,0.012,-1.0,horn)
	# The legs: a shin (a unit post up +Y, set from foot to hip) and toes.
	var shin := SurfaceTool.new()
	shin.begin(Mesh.PRIMITIVE_TRIANGLES)
	_post(shin,0.0045,0.0035,scale_c)
	var toes := SurfaceTool.new()
	toes.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(3):
		var a := (float(k)-1.0)*0.38
		_toe(toes,Vector3(sin(a),0.0,-cos(a)),0.034,scale_c)
	_toe(toes,Vector3(0.0,0.0,1.0),0.022,scale_c)
	var out := {"body":_finish(body),"head":_finish(head),"jaw":_finish(jaw),"shin":_finish(shin),"toes":_finish(toes),
		"hackles":_hackles_mesh(),"tail":_tail_mesh(),"arm":_arm_mesh(),"hand":_hand_mesh(),"folded":[_folded_mesh(-1.0),_folded_mesh(1.0)]}
	_meshes = out
	return out

static func _finish(st: SurfaceTool) -> ArrayMesh:
	return st.commit()

## An ellipsoid at `at` with full sizes `size`, smooth, flagged `flag`
## (COLOR: plumage, eye, horn, scale).
static func _ellipsoid(st: SurfaceTool, at: Vector3, size: Vector3, flag: Color, seg := 14, rings := 9) -> void:
	var r := size*0.5
	var grid: Array = []
	for j in range(rings+1):
		var lat := PI*float(j)/rings
		var row: Array = []
		for i in range(seg+1):
			var lon := TAU*float(i)/seg
			var u := Vector3(sin(lat)*cos(lon),cos(lat),sin(lat)*sin(lon))
			row.append([at+u*r,(u/r).normalized()])
		grid.append(row)
	for j in range(rings):
		for i in range(seg):
			var a: Array = grid[j][i]
			var b: Array = grid[j][i+1]
			var c: Array = grid[j+1][i+1]
			var d: Array = grid[j+1][i]
			for v: Array in [a,c,b,a,d,c]:
				st.set_color(flag)
				st.set_normal(v[1])
				st.add_vertex(v[0])

## A faceted hull through `stations` ([z, y, half width, height over,
## depth under]), each a seven-sided section (ridge, shoulders, widest,
## flanks, keel), moved by `off`, flat-shaded, both ends capped.
static func _loft(st: SurfaceTool, stations: Array, off: Vector3, flag: Color) -> void:
	var rings: Array = []
	var mids: Array = []
	for sta: Array in stations:
		var z: float = sta[0]
		var y: float = sta[1]
		var w: float = sta[2]
		var up: float = sta[3]
		var dn: float = sta[4]
		var c := Vector3(0.0,y,z)+off
		rings.append([c+Vector3(0.0,up,0.0),c+Vector3(w*0.78,up*0.55,0.0),c+Vector3(w,-dn*0.12,0.0),c+Vector3(w*0.58,-dn*0.72,0.0),
			c+Vector3(0.0,-dn,0.0),c+Vector3(-w*0.58,-dn*0.72,0.0),c+Vector3(-w,-dn*0.12,0.0),c+Vector3(-w*0.78,up*0.55,0.0)])
		mids.append(c)
	var n := 8
	for j in range(rings.size()-1):
		var mid: Vector3 = ((mids[j] as Vector3)+(mids[j+1] as Vector3))*0.5
		for i in range(n):
			var a: Vector3 = rings[j][i]
			var b: Vector3 = rings[j][(i+1)%n]
			var c: Vector3 = rings[j+1][(i+1)%n]
			var d: Vector3 = rings[j+1][i]
			_tri(st,a,b,c,mid,flag)
			_tri(st,a,c,d,mid,flag)
	for e: int in [0,rings.size()-1]:
		var centre: Vector3 = mids[e]
		var inward: Vector3 = (mids[1] as Vector3)-(mids[0] as Vector3) if e == 0 else (mids[e-1] as Vector3)-(mids[e] as Vector3)
		for i in range(n):
			_tri(st,rings[e][i],rings[e][(i+1)%n],centre,centre+inward,flag)

## A mandible from `base` (its back) along -Z: deep and broad at the base,
## the culmen arched and hooked down at the tip (`up` 1 the upper, -1 the
## lower, flat on top along the gape).
static func _mandible(st: SurfaceTool, base: Vector3, length: float, width: float, depth: float, up: float, flag: Color) -> void:
	var rings: Array = []
	var n := 6
	for j in range(n+1):
		var t := float(j)/n
		var w := width*0.5*pow(1.0-t,0.75)
		var d := depth*(1.0-pow(t,1.3))
		var hook := -0.006*pow(t,3.0) if up > 0.0 else 0.003*pow(t,2.0)
		var c := base+Vector3(0.0,hook,-length*t)
		var ring: Array = []
		if j == n:
			for _i in range(6): ring.append(c)
		else:
			ring.append(c+Vector3(-w,0.0,0.0))
			ring.append(c+Vector3(-w*0.72,up*d*0.62,0.0))
			ring.append(c+Vector3(0.0,up*d,0.0))
			ring.append(c+Vector3(w*0.72,up*d*0.62,0.0))
			ring.append(c+Vector3(w,0.0,0.0))
			ring.append(c+Vector3(0.0,-up*d*0.08,0.0))
		rings.append(ring)
	for j in range(n):
		for i in range(6):
			var a: Vector3 = rings[j][i]
			var b: Vector3 = rings[j][(i+1)%6]
			var c: Vector3 = rings[j+1][(i+1)%6]
			var d: Vector3 = rings[j+1][i]
			var mid := base+Vector3(0.0,up*depth*0.3,-length*(float(j)+0.5)/n)
			_tri(st,a,b,c,mid,flag)
			_tri(st,a,c,d,mid,flag)

## A tapered post up +Y from 0 to 1, eight-sided.
static func _post(st: SurfaceTool, r0: float, r1: float, flag: Color) -> void:
	for i in range(8):
		var a0 := TAU*float(i)/8.0
		var a1 := TAU*float(i+1)/8.0
		var p := [Vector3(cos(a0)*r0,0.0,sin(a0)*r0),Vector3(cos(a1)*r0,0.0,sin(a1)*r0),Vector3(cos(a1)*r1,1.0,sin(a1)*r1),Vector3(cos(a0)*r1,1.0,sin(a0)*r1)]
		_tri(st,p[0],p[1],p[2],Vector3(0,0.5,0),flag)
		_tri(st,p[0],p[2],p[3],Vector3(0,0.5,0),flag)

## A toe from the foot along `dir`, a four-sided taper with a claw's curl.
static func _toe(st: SurfaceTool, dir: Vector3, length: float, flag: Color) -> void:
	var side := Vector3(-dir.z,0.0,dir.x)*0.0032
	var top := Vector3(0.0,0.004,0.0)
	var tip := dir*length+Vector3(0.0,-0.002,0.0)
	var a := side
	var b := top
	var c := -side
	var d := Vector3(0.0,0.0005,0.0)
	var mid := dir*length*0.3+Vector3(0.0,0.0015,0.0)
	for e: Array in [[a,b],[b,c],[c,d],[d,a]]:
		_tri(st,e[0],e[1],tip,mid,flag)

## One flat triangle facing away from `centre`.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3, flag: Color) -> void:
	var n := (b-a).cross(c-a)
	if n.length_squared() < 1e-14: return
	n = n.normalized()
	if n.dot((a+b+c)/3.0-centre) < 0.0:
		n = -n
		var s := b
		b = c
		c = s
	# Godot's front faces wind clockwise.
	st.set_color(flag)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_color(flag)
	st.set_normal(n)
	st.add_vertex(c)
	st.set_color(flag)
	st.set_normal(n)
	st.add_vertex(b)

# --- Feathers ----------------------------------------------------------------------------

## One feather into `a`: from `base` along `along` (unit) `length` m, `width`
## across `side`, its face `normal`, cambered (bowed against the normal),
## its fan pivot at its base (`fan` the turn folded), its tint (r the vane
## notched as a finger, g worn, b sheen).
static func _feather(a: Dictionary, base: Vector3, along: Vector3, side: Vector3, normal: Vector3, length: float, width: float,
		camber: float, fan: float, seed: float, tint: Color) -> void:
	var segs := 3
	var first: int = (a.v as Array).size()
	for i in range(segs+1):
		var t := float(i)/segs
		var mid := base+along*length*t-normal*camber*length*t*t
		for j in range(2):
			var u := float(j)
			(a.v as Array).append(mid+side*width*(u-0.5))
			(a.n as Array).append(normal)
			(a.uv as Array).append(Vector2(u,t))
			(a.c as Array).append(tint)
			(a.cu as Array).append_array([base.x,base.z,fan,seed])
	for i in range(segs):
		var k := first+i*2
		(a.i as Array).append_array([k,k+2,k+1,k+1,k+2,k+3])

static func _arrays() -> Dictionary:
	return {"v":[],"n":[],"uv":[],"c":[],"cu":[],"i":[]}

static func _commit(a: Dictionary) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(a.v)
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(a.n)
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(a.uv)
	arr[Mesh.ARRAY_COLOR] = PackedColorArray(a.c)
	arr[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array(a.cu)
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array(a.i)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh

## The arm (shoulder frame: +X out along it, +Z back): secondaries and
## tertials along it, two rows of coverts over their bases.
static func _arm_mesh() -> ArrayMesh:
	var a := _arrays()
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in range(11):
		var x := 0.004+float(i)*0.0118
		var dir := Vector3(0.03+float(i)*0.012,0.0,1.0).normalized()
		var length := (0.13 if i < 3 else 0.125)+rng.randf_range(-0.006,0.006)
		_feather(a,Vector3(x,-0.001*float(i%2),0.0),dir,Vector3(1,0,0),Vector3.UP,length,0.034,0.12,0.0,rng.randf(),Color(0.0,0.7,0.35,1.0))
	for row in range(2):
		for i in range(11):
			var x := float(i)*0.0118
			_feather(a,Vector3(x,0.003+row*0.003,-0.004-row*0.006),Vector3(0.08,0.0,1.0).normalized(),Vector3(1,0,0),Vector3.UP,
				0.05-row*0.018,0.024,0.2,0.0,rng.randf(),Color(0.0,0.25,1.0,1.0))
	return _commit(a)

## The hand (wrist frame): ten primaries fanned from back (inner) to out,
## the outer five notched into fingers, and their coverts. Folded
## (`spread` 0) each turns back about its base to lie along the arm.
static func _hand_mesh() -> ArrayMesh:
	var a := _arrays()
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var folded := 1.5
	for i in range(10):
		var t := float(i)/9.0
		var ang := lerpf(1.25,0.1,t)
		var dir := Vector3(cos(ang),0.0,sin(ang))
		var side := Vector3(-dir.z,0.0,dir.x)
		var length := lerpf(0.15,0.215,pow(t,0.7))+rng.randf_range(-0.006,0.006)
		if i == 9: length -= 0.05
		elif i == 8: length -= 0.012
		var base := Vector3(0.002+t*0.07,-0.0008*float(i),0.004-t*0.01)
		_feather(a,base,dir,side,Vector3.UP,length,lerpf(0.036,0.026,t),0.1,folded-ang,rng.randf(),Color(1.0 if i >= 5 else 0.0,0.9,0.3,1.0))
	for i in range(8):
		var t := float(i)/7.0
		var ang := lerpf(1.1,0.3,t)
		var dir := Vector3(cos(ang),0.0,sin(ang))
		var side := Vector3(-dir.z,0.0,dir.x)
		_feather(a,Vector3(t*0.06,0.004,-0.002),dir,side,Vector3.UP,0.058,0.024,0.2,folded-ang,rng.randf(),Color(0.0,0.3,1.0,1.0))
	return _commit(a)

## The tail: twelve feathers, the middle ones a touch the longest (rounded),
## fanned; folded they close to a narrow wedge.
static func _tail_mesh() -> ArrayMesh:
	var a := _arrays()
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in range(12):
		var t := float(i)/11.0-0.5
		var ang := PI*0.5+t*0.8
		var dir := Vector3(cos(ang),0.0,sin(ang))
		var side := Vector3(-dir.z,0.0,dir.x)
		var length := 0.165-absf(t)*0.04+rng.randf_range(-0.005,0.005)
		_feather(a,Vector3(t*0.026,-absf(t)*0.006,0.0),dir,side,Vector3.UP,length,0.034,0.05,(PI*0.5-ang)*0.88,rng.randf(),Color(0.0,0.9,0.5,1.0))
	return _commit(a)

## The throat's hackles: shaggy lance feathers under the chin.
static func _hackles_mesh() -> ArrayMesh:
	var a := _arrays()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(9):
		var x := (float(i%3)-1.0)*0.012
		var row := float(i/3)
		var base := Vector3(x,-0.018-row*0.006,-0.02+row*0.012)
		var along := Vector3(x*2.0,-0.55,1.0).normalized()
		var side := Vector3(1,0,0)
		var normal := side.cross(along).normalized()
		if normal.y > 0.0: normal = -normal
		_feather(a,base,along,side,-normal,0.03,0.014,-0.3,0.0,rng.randf(),Color(0.0,0.6,0.8,1.0))
	return _commit(a)

## A folded wing on side `s` (body frame about the hip): laid along the
## body's flank, the primaries' tips reaching most of the way down the tail,
## the secondaries and tertials over them, the coverts over their bases.
static func _folded_mesh(s: float) -> ArrayMesh:
	var a := _arrays()
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 if s > 0.0 else 93
	var o := Vector3(s*0.036,0.132,-0.05)-HIP
	var along := Vector3(0.0,0.1,1.0).normalized()
	var down := Vector3(s*0.24,-1.0,0.0)
	down = (down-along*down.dot(along)).normalized()
	var normal := along.cross(down).normalized()
	if normal.x*s < 0.0: normal = -normal
	var lay := 0.0018
	# Primaries, innermost layer, their tips crossing over the rump.
	for i in range(7):
		var dir := (along+down*(0.04-0.01*i)).normalized()
		dir = (dir-normal*0.06).normalized()
		_feather(a,o+along*(0.035+i*0.006)+down*(0.026+i*0.0035),dir,down,normal,0.2-i*0.011+rng.randf_range(-0.004,0.004),0.03,0.07,0.0,rng.randf(),
			Color(1.0 if i < 3 else 0.0,1.0,0.25,1.0))
	# Secondaries, over them.
	for i in range(8):
		var dir := (along+down*0.12).normalized()
		_feather(a,o+along*(0.012+i*0.0095)+down*(0.004+i*0.0035)+normal*lay,dir,down,normal,0.122+rng.randf_range(-0.005,0.005),0.034,0.08,0.0,rng.randf(),
			Color(0.0,0.75,0.45,1.0))
	# Tertials, broad, up on the back.
	for i in range(3):
		var dir := (along-down*0.04).normalized()
		_feather(a,o+along*(0.07+i*0.012)+down*(-0.006+i*0.005)+normal*lay*2.0,dir,down,normal,0.105,0.04,0.06,0.0,rng.randf(),
			Color(0.0,0.6,0.6,1.0))
	# Greater and median coverts at the front.
	for i in range(8):
		var dir := (along+down*0.3).normalized()
		_feather(a,o+along*(-0.006+i*0.0105)+down*0.012+normal*lay*3.0,dir,down,normal,0.05,0.026,0.15,0.0,rng.randf(),
			Color(0.0,0.2,0.6,1.0))
	for i in range(7):
		var dir := (along+down*0.35).normalized()
		_feather(a,o+along*(-0.01+i*0.011)+down*(-0.004)+normal*lay*4.0,dir,down,normal,0.03,0.022,0.2,0.0,rng.randf(),
			Color(0.0,0.1,0.6,1.0))
	return _commit(a)
