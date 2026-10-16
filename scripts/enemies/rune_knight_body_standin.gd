extends Node3D
## The rune knight's stand-in body (docs/design/rune-knight/
## spec-rune-knight.md, "The contract"): primitives in the kit's stone,
## behind the body API the mind (scripts/enemies/rune_knight.gd) drives him
## through, so a Blender body can drop in later with the mind unchanged.
##
## - **The API:** `play(clip)`, signal `beat_reached(clip, beat)`,
##   `socket(name) -> Node3D`, `set_effect(name, on)`, and `shape()` (his
##   room, eye, reach, stride and pace, from his height). Clips and beats
##   are CLIPS; sockets SOCKETS; effects `rune_glow` and `wind_gather`.
## - **The mind moves him, the body moves its limbs:** the mind sets his
##   parent's transform (the root on the deck, his yaw) and plays `walk` or
##   `turn` while it moves it; the body keeps each foot where it was set and
##   steps the trailing one to where the root will be (planted steps), the
##   hips sinking SETTLE at each plant and coming slowly back (heavy), and
##   swaying over the standing foot. Legs reach their feet by two-bone IK.
##   Each footfall sends `plant`. In `idle` a foot left out of place steps
##   home and he stands.
## - **The other clips** (`notice`, `gather`, `throw`, `catch`, `return`,
##   `stagger`) run their CLIPS length and send their beats at their times;
##   their key poses come with the tasks that play them (until then he
##   stands in `idle`'s pose through them).
## - **His look:** a blocky helm with a visor slit and a crest, a broad
##   chest over a narrow belly, pauldrons, big gauntlets, legs on hip and
##   knee pivots; rune lines on the chest and gauntlets, dim, lit by
##   `rune_glow`.
const RuinKit = preload("res://scripts/ruin_kit.gd")

signal beat_reached(clip: String, beat: String)

## Clips: length (s), loop, beats {name: time (s)}. `walk`'s and `turn`'s
## `plant` come from the footfalls themselves (their length is a step's).
const CLIPS := {
	"idle": {"length": 2.0, "loop": true, "beats": {}},
	"walk": {"length": 0.95, "loop": true, "beats": {"plant": -1.0}},
	"turn": {"length": 0.8, "loop": true, "beats": {"plant": -1.0}},
	"notice": {"length": 0.6, "loop": false, "beats": {}},
	"gather": {"length": 1.0, "loop": false, "beats": {"grab": 0.25, "full": 1.0}},
	"throw": {"length": 0.7, "loop": false, "beats": {"release": 0.35}},
	"catch": {"length": 0.6, "loop": false, "beats": {"contact": 0.1, "hold": 0.6}},
	"return": {"length": 0.5, "loop": false, "beats": {"release": 0.22}},
	"stagger": {"length": 1.8, "loop": false, "beats": {"plant": 0.9, "recover": 1.8}},
}
const SOCKETS := ["hand_r","hand_l","hands_mid","chest_rune","eye"]
## The walk, as shares of his height: the swing's share of a step (the rest
## is the plant's settle), the feet's spacing along his line, the swing
## foot's lift, the plant's sink, the hips' sway over the standing foot; a
## foot further than HOME_SLOP (m) from its spot steps in idle.
const SWING_SHARE := 0.62
const STRIDE := 0.3
const LIFT := 0.09
const SETTLE := 0.035
const SWAY := 0.035
const HOME_SLOP := 0.08
## His room's radius and his reach (the catch's range), shares of tall.
const ROOM := 0.24
const REACH := 0.75
## The rune lines' colour and light, dim and lit; how fast the light eases.
const RUNE := Color(0.45,0.85,1.0)
const RUNE_DIM := 0.25
const RUNE_LIT := 4.0
const RUNE_EASE := 6.0
## His stone's tones (the kit's, a touch lighter so he reads off the deck).
const STONE := Color("6a645d")
const STONE_DARK := Color("3d3934")

var tall := 1.9
var clip := "idle"
var clip_time := 0.0
var effects := {"rune_glow": false, "wind_gather": false}
var glow := 0.0
## The feet (world, on the ground), 0 left, 1 right.
var feet: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
## The step under way: the foot swinging (-1 none), where from, its clock
## and length.
var _swing := -1
var _swing_from := Vector3.ZERO
var _swing_t := 0.0
var _swing_len := 1.0
var _last_foot := 1
var _settle_t := 9.0
var _root_last := Vector3.ZERO
var _root_v := Vector3.ZERO
var _sent: Dictionary = {}

var _hips: Node3D
var _waist: Node3D
var _head: Node3D
var _thigh: Array[Node3D] = []
var _shin: Array[Node3D] = []
var _foot: Array[Node3D] = []
var _arm: Array[Node3D] = []
var _forearm: Array[Node3D] = []
var _sockets: Dictionary = {}
var _rune_mat: StandardMaterial3D
var _stone_mat: Material
var _hip_y := 0.0
var _thigh_len := 0.0
var _shin_len := 0.0
var _ankle := 0.0
var _hip_x := 0.0

func _init() -> void:
	name = "Body"

## Built `height` m tall; call once it is in the tree under his root.
func setup(height: float) -> void:
	tall = height
	_build()
	_root_last = global_position
	for i in range(2): feet[i] = _home(i,0.0)
	_pose(0.0,0.0)

## His shape (m, s): room radius and height, eye height, reach, the feet's
## stride and a walking step's time, and the walking pace they make.
func shape() -> Dictionary:
	var step: float = CLIPS.walk.length
	var stride := STRIDE*tall
	return {"radius":ROOM*tall,"height":tall,"eye":_sockets.eye.position.y if _sockets.has("eye") else 0.9*tall,
		"reach":REACH*tall,"stride":stride,"step_time":step,"pace":stride/step}

# --- The API ------------------------------------------------------------------------

func play(name_: String) -> void:
	if not CLIPS.has(name_):
		push_warning("rune knight body: no clip %s" % name_)
		return
	if name_ == clip and CLIPS[name_].loop: return
	clip = name_
	clip_time = 0.0
	_sent = {}

func socket(name_: String) -> Node3D:
	return _sockets.get(name_)

func set_effect(name_: String, on: bool) -> void:
	effects[name_] = on

# --- The frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if delta <= 0.0: return
	var now := global_position
	_root_v = _root_v.lerp((now-_root_last)/delta,clampf(delta*8.0,0.0,1.0))
	_root_last = now
	clip_time += delta
	var c: Dictionary = CLIPS[clip]
	for beat: String in c.beats:
		var at: float = c.beats[beat]
		if at >= 0.0 and clip_time >= at and not _sent.has(beat):
			_sent[beat] = true
			beat_reached.emit(clip,beat)
	if not c.loop and clip_time >= float(c.length) and not _sent.has("_end"):
		_sent["_end"] = true
	glow = move_toward(glow,1.0 if effects.rune_glow else 0.0,delta*RUNE_EASE*0.5)
	_step(delta)

## The feet: a step under way goes on; else in `walk`/`turn` the trailing
## foot steps, in anything else a foot off its spot steps home.
func _step(delta: float) -> void:
	var moving := clip == "walk" or clip == "turn"
	if _swing < 0:
		var pick := -1
		if moving:
			pick = 1-_last_foot
		else:
			var worst := HOME_SLOP
			for i in range(2):
				var off := feet[i].distance_to(_home(i,0.0))
				if off > worst:
					worst = off
					pick = i
		if pick >= 0:
			_swing = pick
			_swing_from = feet[pick]
			_swing_t = 0.0
			_swing_len = float(CLIPS[clip].length) if moving else float(CLIPS.walk.length)
	var lift := 0.0
	var s := 0.0
	if _swing >= 0:
		_swing_t += delta
		var swing_time := _swing_len*SWING_SHARE
		s = clampf(_swing_t/swing_time,0.0,1.0)
		var e := s*s*(3.0-2.0*s)
		var lead := maxf(swing_time-_swing_t,0.0)+_swing_len*(1.0-SWING_SHARE*0.5)
		var to := _home(_swing,lead if moving else 0.0)
		var far := _swing_from.distance_to(to)
		feet[_swing] = _swing_from.lerp(to,e)+Vector3.UP*sin(s*PI)*LIFT*tall*clampf(far/(STRIDE*tall),0.3,1.0)
		lift = sin(s*PI)*0.012
		if s >= 1.0:
			feet[_swing] = to
			_last_foot = _swing
			_settle_t = 0.0
			_swing = -1
			if moving: beat_reached.emit(clip,"plant")
	_settle_t += delta
	# The plant's sink: down quick, back up slow.
	var p := _settle_t/(float(CLIPS.walk.length)*(1.0-SWING_SHARE))
	var sink := sin(minf(p*1.6,1.0)*PI*0.5)*(1.0-smoothstep(0.55,1.0,p)) if p < 1.0 else 0.0
	_pose(lift-sink*SETTLE*tall,s)

## Foot `i`'s spot under the root now, or `ahead` s on at the root's pace.
func _home(i: int, ahead: float) -> Vector3:
	var g := global_transform
	var side := g.basis.x.normalized()*_hip_x*(1.0 if i == 1 else -1.0)
	var flat := Vector3(_root_v.x,0.0,_root_v.z)
	return g.origin+side+flat*ahead

# --- The pose -----------------------------------------------------------------------

## The body `lift` m up, the legs reaching the feet; `swing` (0..1) the
## step's swing for the sway and the arms.
func _pose(lift: float, swing: float) -> void:
	var sway := 0.0
	if _swing >= 0:
		var stand := 1-_swing
		sway = (1.0 if stand == 1 else -1.0)*sin(swing*PI)*SWAY*tall
	_hips.position = Vector3(sway,_hip_y+lift,0.0)
	_hips.rotation.z = -sway*0.6
	_waist.rotation.z = sway*0.9
	for i in range(2): _reach(i)
	var arm := 0.0
	if _swing >= 0 and clip == "walk":
		arm = sin(swing*PI)*0.22*(1.0 if _swing == 0 else -1.0)
	_arm[0].rotation.x = arm
	_arm[1].rotation.x = -arm
	_forearm[0].rotation.x = 0.25+maxf(arm,0.0)*0.5
	_forearm[1].rotation.x = 0.25+maxf(-arm,0.0)*0.5
	_head.rotation.x = -lift*2.5
	_rune_mat.emission_energy_multiplier = lerpf(RUNE_DIM,RUNE_LIT,glow)

## Leg `i` (0 left) reaching its foot: two-bone IK in his walking plane.
func _reach(i: int) -> void:
	var hip := _hips.position+Vector3(_hip_x*(1.0 if i == 1 else -1.0),0.0,0.0)
	var foot := global_transform.affine_inverse()*feet[i]+Vector3.UP*_ankle
	var d := foot-hip
	var fwd := -d.z
	var down := -d.y
	var a := _thigh_len
	var b := _shin_len
	var reach := clampf(sqrt(fwd*fwd+down*down),0.05,a+b-0.002)
	var base := atan2(fwd,down)
	var alpha := acos(clampf((a*a+reach*reach-b*b)/(2.0*a*reach),-1.0,1.0))
	var gamma := acos(clampf((a*a+b*b-reach*reach)/(2.0*a*b),-1.0,1.0))
	_thigh[i].position = hip-_hips.position
	_thigh[i].rotation = Vector3(base+alpha,0.0,0.0)
	_shin[i].rotation = Vector3(-(PI-gamma),0.0,0.0)
	_foot[i].rotation = Vector3(-(base+alpha)+(PI-gamma),0.0,0.0)

# --- The build ----------------------------------------------------------------------

func _build() -> void:
	var h := tall
	_stone_mat = RuinKit.materials().stone
	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Color(0.12,0.16,0.18)
	_rune_mat.emission_enabled = true
	_rune_mat.emission = RUNE
	_rune_mat.emission_energy_multiplier = RUNE_DIM
	_thigh_len = 0.22*h
	_shin_len = 0.21*h
	_ankle = 0.045*h
	_hip_x = 0.085*h
	_hip_y = _ankle+(_thigh_len+_shin_len)*0.97
	_hips = _pivot(self,"Hips",Vector3(0.0,_hip_y,0.0))
	_box(_hips,"Pelvis",Vector3.ZERO,Vector3(0.3,0.09,0.17)*h,STONE_DARK)
	_box(_hips,"Tasset",Vector3(0.0,-0.06*h,-0.02*h),Vector3(0.32,0.08,0.2)*h,STONE,Vector3(0.12,0,0))
	for i in range(2):
		var sx := 1.0 if i == 1 else -1.0
		var thigh := _pivot(_hips,"Thigh%d" % i,Vector3(_hip_x*sx,0.0,0.0))
		_box(thigh,"ThighMesh",Vector3(0.0,-_thigh_len*0.5,0.0),Vector3(0.12*h,_thigh_len*1.02,0.13*h),STONE)
		var shin := _pivot(thigh,"Shin",Vector3(0.0,-_thigh_len,0.0))
		_box(shin,"Knee",Vector3(0.0,0.0,-0.02*h),Vector3(0.11,0.07,0.09)*h,STONE_DARK)
		_box(shin,"ShinMesh",Vector3(0.0,-_shin_len*0.5,0.0),Vector3(0.115*h,_shin_len,0.125*h),STONE)
		var foot := _pivot(shin,"Foot",Vector3(0.0,-_shin_len,0.0))
		_box(foot,"Sabaton",Vector3(0.0,-_ankle*0.5,-0.035*h),Vector3(0.13*h,_ankle,0.22*h),STONE_DARK)
		_thigh.append(thigh)
		_shin.append(shin)
		_foot.append(foot)
	# Torso: a narrow belly under a broad chest.
	_waist = _pivot(_hips,"Waist",Vector3(0.0,0.03*h,0.0))
	_box(_waist,"Belly",Vector3(0.0,0.07*h,0.0),Vector3(0.24,0.12,0.16)*h,STONE_DARK)
	_box(_waist,"Chest",Vector3(0.0,0.21*h,-0.005*h),Vector3(0.38,0.18,0.22)*h,STONE,Vector3(-0.05,0,0))
	_box(_waist,"Gorget",Vector3(0.0,0.31*h,0.0),Vector3(0.16,0.04,0.14)*h,STONE_DARK)
	var front := -0.117*h
	_rune(_waist,Vector3(0.0,0.2*h,front),Vector3(0.012,0.12,0.01)*h,0.0)
	_rune(_waist,Vector3(-0.035*h,0.255*h,front),Vector3(0.012,0.07,0.01)*h,0.75)
	_rune(_waist,Vector3(0.035*h,0.255*h,front),Vector3(0.012,0.07,0.01)*h,-0.75)
	_rune(_waist,Vector3(0.0,0.14*h,front),Vector3(0.08,0.012,0.01)*h,0.0)
	_sockets.chest_rune = _pivot(_waist,"chest_rune",Vector3(0.0,0.2*h,front))
	_sockets.hands_mid = _pivot(_waist,"hands_mid",Vector3(0.0,0.2*h,-0.35*h))
	# Head.
	_head = _pivot(_waist,"Head",Vector3(0.0,0.33*h,0.0))
	_box(_head,"Helm",Vector3(0.0,0.08*h,0.005*h),Vector3(0.14,0.15,0.16)*h,STONE)
	_box(_head,"Brow",Vector3(0.0,0.115*h,-0.075*h),Vector3(0.15,0.035,0.03)*h,STONE_DARK)
	_box(_head,"Visor",Vector3(0.0,0.085*h,-0.076*h),Vector3(0.11,0.016,0.01)*h,Color(0.05,0.05,0.05))
	_box(_head,"Crest",Vector3(0.0,0.165*h,0.015*h),Vector3(0.022,0.03,0.15)*h,STONE_DARK)
	_sockets.eye = _pivot(_head,"eye",Vector3(0.0,0.085*h,-0.08*h))
	# Arms: pauldron, upper arm, forearm, gauntlet.
	for i in range(2):
		var sx := 1.0 if i == 1 else -1.0
		var shoulder := Vector3(0.23*h*sx,0.27*h,0.0)
		_box(_waist,"Pauldron%d" % i,shoulder+Vector3(0.02*h*sx,0.035*h,0.0),Vector3(0.13,0.06,0.19)*h,STONE_DARK,Vector3(0,0,-0.45*sx))
		_box(_waist,"PauldronLame%d" % i,shoulder+Vector3(0.065*h*sx,-0.015*h,0.0),Vector3(0.1,0.05,0.17)*h,STONE,Vector3(0,0,-0.9*sx))
		var arm := _pivot(_waist,"Arm%d" % i,shoulder)
		arm.rotation_order = EULER_ORDER_ZXY
		_box(arm,"UpperArm",Vector3(0.0,-0.08*h,0.0),Vector3(0.09,0.17,0.1)*h,STONE)
		var fore := _pivot(arm,"Forearm",Vector3(0.0,-0.16*h,0.0))
		_box(fore,"ForearmMesh",Vector3(0.0,-0.065*h,0.0),Vector3(0.095,0.14,0.1)*h,STONE)
		var hand := _pivot(fore,"Gauntlet",Vector3(0.0,-0.15*h,0.0))
		_box(hand,"Fist",Vector3(0.0,-0.035*h,0.0),Vector3(0.13,0.12,0.13)*h,STONE_DARK)
		_box(hand,"Cuff",Vector3(0.0,0.035*h,0.0),Vector3(0.14,0.04,0.14)*h,STONE)
		_rune(hand,Vector3(0.0,-0.03*h,-0.066*h),Vector3(0.012,0.08,0.01)*h,0.0)
		_rune(hand,Vector3(0.016*h,-0.005*h,-0.066*h),Vector3(0.012,0.04,0.01)*h,-0.8)
		_rune(hand,Vector3(-0.016*h,-0.005*h,-0.066*h),Vector3(0.012,0.04,0.01)*h,0.8)
		_sockets["hand_r" if i == 1 else "hand_l"] = _pivot(hand,"hand_r" if i == 1 else "hand_l",Vector3(0.0,-0.035*h,0.0))
		arm.rotation.z = 0.12*sx
		_arm.append(arm)
		_forearm.append(fore)

func _pivot(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = label
	n.position = at
	parent.add_child(n)
	return n

## A stone box of `size` about `at` under `parent`, turned by `rot` (rad),
## coloured by its vertices (the kit's stone shader reads them).
func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, tone: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var colors := PackedColorArray()
	colors.resize(n)
	colors.fill(Color(tone.r,tone.g,tone.b,1.0))
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var m := MeshInstance3D.new()
	m.name = label
	m.mesh = mesh
	m.material_override = _stone_mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m

## A rune line: a thin lit bar of `size` at `at`, turned `roll` in its face.
func _rune(parent: Node3D, at: Vector3, size: Vector3, roll: float) -> void:
	var box := BoxMesh.new()
	box.size = size
	var m := MeshInstance3D.new()
	m.name = "Rune"
	m.mesh = box
	m.material_override = _rune_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at
	m.rotation.z = roll
	parent.add_child(m)
