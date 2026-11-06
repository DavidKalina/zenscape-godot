extends Node3D
## The ground escort's stand-in body (docs/design/endless-flight/
## spec-wild-kit-elk.md, The contract): an elk of faceted primitives in the
## elk's size and silhouette, its sockets in place, and `play(clip)` driving
## procedural key poses timed to the contract's beats. The mind
## (scripts/endless/kinds/ground_escort.gd) calls only the API below, so the
## real body (scripts/endless/world/wilderness/elk_body.gd) drops in for it.
##
## The frame: origin on the ground under the middle of the body, -Z its
## heading. Sizes are multiples of the plane's span (scripts/world_scale.gd):
## body length about 0.9 span nose to rump, withers 0.55, eye 0.62, a bull's
## antlers 0.45 over the head. The legs reach their feet by two-bone IK, so a
## gait's stance feet stand still on the ground when the mind moves the body
## at the clip's ground speed (ground per cycle over length, times rate).
##
## The clip advances in this node's own _process; the mind stops a sleeping
## body by disabling its processing (process_mode), as it would stop the real
## body's AnimationPlayer. `play` of the clip already playing keeps its phase
## and sets the rate (AnimationPlayer's way); a finished one-shot starts over.

signal beat_reached(name: String)

const LifeModels = preload("res://scripts/life_models.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The contract's clips: length (s), loop, ground per cycle (body lengths),
## and beats [name, time].
const CLIPS := {
	"graze": {"length":3.0,"loop":true,"ground":0.0,"beats":[["graze.lift",2.2]]},
	"alert": {"length":0.6,"loop":false,"ground":0.0,"beats":[["alert.up",0.25]]},
	"bolt_start": {"length":0.5,"loop":false,"ground":1.2,"beats":[["bolt_start.crouch",0.15],["bolt_start.launch",0.3]]},
	"trot": {"length":0.8,"loop":true,"ground":2.0,"beats":[["trot.plant",0.0],["trot.plant",0.4]]},
	"gallop": {"length":0.55,"loop":true,"ground":4.0,"beats":[["gallop.plant",0.05],["gallop.air",0.35]]},
	"sprint": {"length":0.5,"loop":true,"ground":7.0,"beats":[["sprint.plant",0.05],["sprint.push",0.2],["sprint.air",0.25]]},
	"leap": {"length":0.9,"loop":false,"ground":12.6,"beats":[["leap.takeoff",0.2],["leap.land",0.7]]},
	"stop_look": {"length":1.2,"loop":false,"ground":0.5,"beats":[["stop_look.halt",0.35],["stop_look.hold",0.6]]},
}

## How a one-shot that travels spreads its ground over its time: [time (s),
## fraction covered], as the real elk's clips do (assets/models/elk/
## elk_clips.json, `ground_curve`); the mind moves the root by the same.
const GROUND_CURVE := {
	"bolt_start": [[0.0,0.0],[0.125,0.0],[0.1667,0.0064],[0.2083,0.0371],[0.25,0.1042],[0.2917,0.215],
		[0.3333,0.355],[0.375,0.5043],[0.4167,0.6586],[0.4583,0.824],[0.5,1.0]],
}

## The legs, in IK order: fore left, fore right, hind left, hind right.
const LEGS := ["fl","fr","hl","hr"]
## Body length in spans (nose to rump).
const BODY_LENGTH := 0.9

## The span every size multiplies (m).
var S: float = WorldScale.span
## One body length (m).
var BL: float = BODY_LENGTH*WorldScale.span

## The torso's pivot over the root, in spans: its middle.
const TORSO_AT := Vector3(0.0,0.42,0.0)
## Where the neck leaves the torso (torso frame, spans), and its far end.
const NECK_AT := Vector3(0.0,0.06,-0.22)
const NECK_END := Vector3(0.0,0.15,-0.21)
## Each leg's top joint (torso frame, spans), its two segments and side.
const LEG_AT := {
	"fl": Vector3(-0.07,-0.02,-0.19),"fr": Vector3(0.07,-0.02,-0.19),
	"hl": Vector3(-0.075,0.0,0.21),"hr": Vector3(0.075,0.0,0.21)}
const UPPER := {"fl":0.21,"fr":0.21,"hl":0.22,"hr":0.22}
const LOWER := {"fl":0.215,"fr":0.215,"hl":0.23,"hr":0.23}

## Coat, by variant (sRGB).
const COATS := {
	"bull": {"body":"#bf9a68","mane":"#4a2f1e","legs":"#3f2d1f","rump":"#e8d7b0","nose":"#241a14","antler":"#dccbab","tip":"#f3ead6"},
	"cow": {"body":"#a98657","mane":"#6b4a32","legs":"#4a3524","rump":"#e2cfa6","nose":"#2a1f18","antler":"#dccbab","tip":"#f3ead6"},
}

var torso: Node3D
var neck: Node3D
var head: Node3D
var ears: Array[Node3D] = []
var tail: Node3D
var antlers: Node3D
var _hips := {}
var _knees := {}
var _sockets := {}
var _meshes: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D

var variant := "cow"
var clip := "graze"
var rate := 1.0
var time := 0.0
var _done := false
var _from := {}
var _blend := 0.0
var _blend_left := 0.0
var _pose := {}
var _look_at := Vector3.ZERO
var _look_weight := 0.0
var _effects := {"dust":false}
var _puffs: Array[MeshInstance3D] = []
var _puff_age: Array[float] = []
var _puff_size: Array[float] = []
var _puff_next := 0

const PUFFS := 8
const PUFF_LIFE := 0.7

func _init() -> void:
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.95
	_build()
	_pose = _clip_pose("graze",0.0)
	_apply(_pose)

# --- The API -------------------------------------------------------------

## Plays `clip` at `rate`, blending from the pose shown over `blend` s.
func play(name: String, play_rate := 1.0, blend := 0.15) -> void:
	if not CLIPS.has(name):
		push_warning("escort stand-in: no clip '%s'" % name)
		return
	rate = play_rate
	if name == clip and not _done: return
	_from = _pose.duplicate(true)
	_blend = maxf(blend,0.0)
	_blend_left = _blend
	clip = name
	time = 0.0
	_done = false
	_fire_beats(-1.0,0.0)

func clip_length(name: String) -> float:
	return float(CLIPS[name].length) if CLIPS.has(name) else 0.0

func socket(name: String) -> Node3D:
	return _sockets.get(name)

func set_variant(name: String) -> void:
	if not COATS.has(name): return
	variant = name
	for mi in _meshes:
		mi.get_parent().remove_child(mi)
		mi.free()
	_meshes.clear()
	_paint()
	antlers.visible = name == "bull"

func set_effect(name: String, on: bool) -> void:
	_effects[name] = on

## Turns the head toward `target` (world) by `weight` (0 to 1), over the clip.
func look_at_world(target: Vector3, weight: float) -> void:
	_look_at = target
	_look_weight = clampf(weight,0.0,1.0)

# --- Time ----------------------------------------------------------------

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec() if FrameLog.on else 0
	_tick(delta)
	if FrameLog.on: FrameLog.add(&"herd_bodies",float(Time.get_ticks_usec()-t0)/1000.0)

## One step of `delta` s: the clip, its beats, the blend, the pose.
func _tick(delta: float) -> void:
	var c: Dictionary = CLIPS[clip]
	var length := float(c.length)
	var was := time
	if not _done:
		time += delta*rate
		if c.loop:
			if time >= length:
				_fire_beats(was,length)
				time = fmod(time,length)
				_fire_beats(-1.0,time)
			else:
				_fire_beats(was,time)
		else:
			if time >= length:
				time = length
				_done = true
			_fire_beats(was,time)
	var pose := _clip_pose(clip,time)
	if _blend_left > 0.0:
		_blend_left = maxf(_blend_left-delta,0.0)
		var k := 1.0-_blend_left/maxf(_blend,1e-4)
		pose = _mix(_from,pose,k*k*(3.0-2.0*k))
	_pose = pose
	_apply(pose)
	_puffs_step(delta)

## Each beat of the clip in (from, to].
func _fire_beats(from: float, to: float) -> void:
	for b: Array in CLIPS[clip].beats:
		var at := float(b[1])
		if at > from and at <= to:
			_on_beat(str(b[0]))
			beat_reached.emit(str(b[0]))

func _on_beat(name: String) -> void:
	if not _effects.dust: return
	if name == "gallop.plant": _puff(socket("foot_fr").global_position)
	elif name == "sprint.plant":
		# The fores strike: a bigger puff, grass and dust thrown up.
		_puff(socket("foot_fl").global_position,1.5)
		_puff(socket("foot_fr").global_position,1.2)
	elif name == "leap.land":
		# Down from high: the biggest puffs.
		_puff(socket("foot_fl").global_position,1.8)
		_puff(socket("foot_fr").global_position,1.5)

# --- The clips' poses ------------------------------------------------------
# A pose: torso y, z (spans, off its rest), pitch (deg, front up), neck and
# head (deg down off rest), neck_yaw and head_yaw (deg, left), ear (deg,
# turned out-back), tail (deg up), feet [fl, fr, hl, hr] in the root's frame
# (spans).

func _rest_feet() -> Array:
	var out := []
	for leg: String in LEGS:
		var at: Vector3 = LEG_AT[leg]
		out.append(Vector3(at.x,0.0,at.z+(-0.01 if leg[0] == "f" else 0.0)))
	return out

func _clip_pose(name: String, t: float) -> Dictionary:
	match name:
		"graze": return _graze(t)
		"alert": return _alert(t)
		"bolt_start": return _bolt_start(t)
		"trot": return _trot(t)
		"gallop": return _gallop(t)
		"sprint": return _sprint(t)
		"leap": return _leap(t)
		"stop_look": return _stop_look(t)
	return _base()

func _base() -> Dictionary:
	return {"y":0.0,"z":0.0,"pitch":0.0,"neck":0.0,"head":0.0,"neck_yaw":0.0,"head_yaw":0.0,
		"ear":0.0,"tail":0.0,"feet":_rest_feet()}

## Head down in the grass, nibbling; at graze.lift (2.2) the head comes up a
## little and the ears turn, then down again.
func _graze(t: float) -> Dictionary:
	var p := _base()
	p.pitch = -4.0
	p.y = -0.012
	p.neck = _key(t,[[0.0,112.0],[1.0,114.0],[2.0,112.0],[2.2,84.0,"out"],[2.65,82.0],[3.0,112.0]])
	p.head = _key(t,[[0.0,-52.0],[0.35,-44.0],[0.7,-52.0],[1.05,-44.0],[1.4,-52.0],[2.0,-52.0],[2.2,-34.0,"out"],[2.65,-34.0],[3.0,-52.0]])
	p.ear = _key(t,[[0.0,0.0],[2.0,0.0],[2.2,45.0,"out"],[2.5,45.0],[2.7,-15.0],[3.0,0.0]])
	p.tail = _key(t,[[0.0,0.0],[1.3,0.0],[1.4,25.0,"out"],[1.6,0.0],[3.0,0.0]])
	var feet: Array = p.feet
	feet[0] = feet[0]+Vector3(0.0,0.0,-0.05)
	return p

## The snap: head fully up by alert.up (0.25), a touch past and back, held.
func _alert(t: float) -> Dictionary:
	var p := _base()
	p.neck = _key(t,[[0.0,70.0],[0.25,-20.0,"back"],[0.6,-16.0]])
	p.head = _key(t,[[0.0,-30.0],[0.25,-4.0,"out"],[0.6,-6.0]])
	p.ear = _key(t,[[0.0,30.0],[0.2,-25.0,"out"],[0.6,-25.0]])
	p.pitch = _key(t,[[0.0,-3.0],[0.25,4.0,"out"],[0.6,2.5]])
	p.y = _key(t,[[0.0,-0.01],[0.25,0.006,"out"],[0.6,0.004]])
	p.z = _key(t,[[0.0,0.0],[0.25,0.02,"out"],[0.6,0.015]])
	p.tail = _key(t,[[0.0,0.0],[0.2,35.0,"out"],[0.6,30.0]])
	return p

## Crouch (0.15): haunches down, weight back, head low; launch (0.3): the
## hinds drive, the front lifts and the fores tuck, then reach for the first
## gallop stride. The root covers 0.8 BL, gathering speed.
func _bolt_start(t: float) -> Dictionary:
	var p := _base()
	p.y = _key(t,[[0.0,0.0],[0.15,-0.06,"io"],[0.3,0.03,"out"],[0.5,0.0]])
	p.z = _key(t,[[0.0,0.0],[0.15,0.04,"io"],[0.3,-0.02,"out"],[0.5,0.0]])
	p.pitch = _key(t,[[0.0,0.0],[0.15,5.0,"io"],[0.3,14.0,"out"],[0.5,2.0]])
	p.neck = _key(t,[[0.0,-10.0],[0.15,15.0,"io"],[0.3,25.0],[0.5,30.0]])
	p.head = _key(t,[[0.0,-5.0],[0.15,5.0],[0.5,10.0]])
	p.ear = _key(t,[[0.0,-20.0],[0.3,40.0,"out"],[0.5,50.0]])
	p.tail = _key(t,[[0.0,30.0],[0.3,50.0],[0.5,40.0]])
	# The root's travel since the clip began (spans), on its ground curve:
	# still through the crouch, then gathering speed.
	var go := func(at: float) -> float: return CLIPS.bolt_start.ground*BODY_LENGTH*_curve("bolt_start",at)
	var feet: Array = p.feet
	for i in range(4):
		var leg: String = LEGS[i]
		var rest: Vector3 = feet[i]
		var off := 0.22 if leg[0] == "f" else 0.35
		if t < off:
			# Planted: slides back under the body as it goes.
			feet[i] = rest+Vector3(0.0,0.0,go.call(t))
		else:
			var s := clampf((t-off)/(0.5-off),0.0,1.0)
			var from := rest+Vector3(0.0,0.0,go.call(off))
			var to := rest+Vector3(0.0,0.0,-0.12 if leg[0] == "f" else -0.06)
			feet[i] = from.lerp(to,_smooth(s))+Vector3(0.0,(0.16 if leg[0] == "f" else 0.1)*sin(PI*s),0.0)
	# The fores tucked hard on the launch.
	if t > 0.22: _tuck(p,0,0.6*_bump(t,0.22,0.5))
	if t > 0.22: _tuck(p,1,0.6*_bump(t,0.24,0.5))
	return p

## A diagonal trot: fl+hr plant at 0.0, fr+hl at 0.4 (trot.plant).
func _trot(t: float) -> Dictionary:
	var p := _base()
	var u := t/0.8
	p.y = -0.01+0.012*cos(TAU*2.0*u)
	p.pitch = 1.5*sin(TAU*2.0*u)
	p.neck = 8.0+3.0*sin(TAU*2.0*u+0.6)
	p.head = 2.0
	p.ear = 10.0
	p.tail = 20.0
	var stride: float = CLIPS.trot.ground*BODY_LENGTH
	var plants := [0.0,0.5,0.5,0.0]
	for i in range(4):
		p.feet[i] = _gait_foot(i,u,plants[i],0.2,stride,0.1 if i < 2 else 0.08)
	return p

## A rotary gallop led by the right fore: hl 0.70, hr 0.78, fl 0.88, fr 0.09
## of the cycle (gallop.plant 0.05 s), all feet off from 0.2 to 0.7 with the
## legs gathered under at gallop.air (0.35 s); the fores reach before they
## plant, the back rocks.
func _gallop(t: float) -> Dictionary:
	var p := _base()
	var u := t/0.55
	# Front up as the fores push off, level in the air, down as the hinds land.
	p.pitch = 7.0*sin(TAU*(u-0.05))
	p.y = -0.02+0.035*sin(PI*clampf((u-0.2)/0.5,0.0,1.0))
	p.z = 0.0
	p.neck = 22.0-12.0*sin(TAU*(u-0.05))
	p.head = 6.0
	p.ear = 55.0
	p.tail = 45.0
	var stride: float = CLIPS.gallop.ground*BODY_LENGTH
	var plants := [0.88,0.09,0.70,0.78]
	for i in range(4):
		p.feet[i] = _gait_foot(i,u,plants[i],0.11,stride,0.17 if i < 2 else 0.13)
	return p

## The sprint beside the plane: long bounds, 7 BL a 0.5 s cycle. The fores
## strike (sprint.plant 0.05 s: fl, then fr), the front drops onto them and
## the hinds swing through under the belly (the gather); the hinds plant
## well forward and drive (sprint.push 0.2 s), the front thrown up; all feet
## off by sprint.air (0.25 s): the long stretched hang, fores reaching far
## ahead, hinds trailing, the front coming down into the next strike.
func _sprint(t: float) -> Dictionary:
	var p := _base()
	var u := t/0.5
	p.y = _key(u,[[0.0,0.01],[0.16,-0.05,"out"],[0.3,-0.045],[0.4,-0.03],[0.72,0.07,"out"],[1.0,0.01,"in"]])
	p.pitch = _key(u,[[0.0,-5.0],[0.16,-7.0],[0.28,0.0],[0.42,9.0,"out"],[0.6,5.0],[0.8,0.0],[1.0,-5.0]])
	p.neck = _key(u,[[0.0,34.0],[0.18,44.0,"out"],[0.42,26.0],[0.75,32.0],[1.0,34.0]])
	p.head = _key(u,[[0.0,10.0],[0.2,4.0],[0.5,12.0],[1.0,10.0]])
	p.ear = 60.0
	p.tail = _key(u,[[0.0,48.0],[0.2,40.0],[0.45,62.0,"out"],[1.0,48.0]])
	var stride: float = CLIPS.sprint.ground*BODY_LENGTH
	var stance := 0.075
	var reach := stride*stance
	var plants := [0.10,0.13,0.30,0.33]
	for i in range(4):
		var at: Vector3 = LEG_AT[LEGS[i]]
		var r := fposmod(u-float(plants[i]),1.0)
		var z := 0.0
		var y := 0.0
		if r < stance:
			z = -reach*0.5+reach*r/stance
		elif i < 2:
			# Flicked up behind, folded under the chest in the gather, then
			# reaching far ahead through the hang and down to strike.
			z = _key(r,[[stance,reach*0.5],[0.12,0.24],[0.22,0.02],[0.45,-0.30],[0.7,-0.42],[0.9,-0.36],[1.0,-reach*0.5]])
			y = _key(r,[[stance,0.0],[0.12,0.10],[0.22,0.24],[0.45,0.20],[0.7,0.12],[0.9,0.05],[1.0,0.0]])
		else:
			# Driving off, trailing stretched through the hang, then swung
			# through under the belly to land well forward.
			z = _key(r,[[stance,reach*0.5],[0.2,0.36],[0.45,0.42],[0.7,0.15],[0.85,-0.18],[0.95,-0.25],[1.0,-reach*0.5]])
			y = _key(r,[[stance,0.0],[0.2,0.06],[0.45,0.12],[0.7,0.20],[0.85,0.16],[0.95,0.06],[1.0,0.0]])
		p.feet[i] = Vector3(at.x,y,at.z+z)
	return p

## The leap, a flourish mid-sprint: 12.6 BL at the sprint's pace (the root
## goes straight on at 12.6 spans/s), from the sprint's late hang (its time 0)
## and back into it, so the sprint starts again where the leap ends. The fores
## strike and the front drops onto them; the hinds swing through and plant
## under a deep gather, then drive (leap.takeoff 0.2), the front thrown up;
## high over the top (0.45), the fores folded tight and the hinds trailing,
## then folding through; nose down, the fores reach and strike (leap.land
## 0.7), the give, the hinds come through and push, into the hang. Each
## stance is the sprint's (0.0375 s), its foot still on the ground; in the
## air the feet are keyed off the hips, so the legs fold with the body.
func _leap(t: float) -> Dictionary:
	var s0 := _sprint(0.0)
	var p := _base()
	p.y = _key(t,[[0.0,s0.y],[0.08,-0.05],[0.17,-0.1],[0.21,-0.03,"out"],[0.45,0.5,"out"],[0.68,0.05,"in"],
		[0.72,-0.02],[0.77,-0.09,"out"],[0.84,0.0],[0.9,s0.y]])
	p.pitch = _key(t,[[0.0,s0.pitch],[0.08,-9.0],[0.16,-3.0],[0.22,18.0,"out"],[0.45,2.0],[0.67,-14.0,"in"],
		[0.74,-9.0],[0.82,6.0],[0.9,s0.pitch]])
	p.neck = _key(t,[[0.0,s0.neck],[0.1,46.0,"out"],[0.22,16.0],[0.45,12.0],[0.66,30.0],[0.76,44.0,"out"],[0.9,s0.neck]])
	p.head = _key(t,[[0.0,s0.head],[0.2,0.0],[0.45,-6.0],[0.7,12.0],[0.9,s0.head]])
	p.ear = _key(t,[[0.0,s0.ear],[0.3,75.0],[0.7,55.0],[0.9,s0.ear]])
	p.tail = _key(t,[[0.0,s0.tail],[0.2,40.0],[0.45,72.0,"out"],[0.76,42.0],[0.9,s0.tail]])
	# The sprint's stance and the ground a planted foot slides back by in it.
	var stance := 0.0375
	var reach: float = CLIPS.leap.ground*BODY_LENGTH/0.9*stance
	# Off the ground from the sprint's own plants (0.05, 0.065, 0.15, 0.165),
	# and down again on the landing.
	var lift := [0.0875,0.1025,0.1875,0.2025]
	var land := [0.7,0.715,0.78,0.795]
	var early: Array = _sprint(t).feet if t <= 0.21 else []
	var tx := _torso_xform(p)
	var feet: Array = p.feet
	for i in range(4):
		var at: Vector3 = LEG_AT[LEGS[i]]
		var fore := i < 2
		var shift := 0.015*float(i%2)
		var t1: float = lift[i]
		var t2: float = land[i]
		var down := Vector3(at.x,0.0,at.z-reach*0.5)
		var up := Vector3(at.x,0.0,at.z+reach*0.5)
		if t <= t1:
			feet[i] = early[i]
		elif t < t2:
			# In the air: off the hip (torso frame), blended in from the
			# lift-off and out to the strike.
			var off: Vector3
			var u := t-shift
			if fore:
				off = Vector3(0.0,_key(u,[[0.09,-0.36],[0.3,-0.17],[0.45,-0.16],[0.6,-0.3],[0.7,-0.36]]),
					_key(u,[[0.09,0.15],[0.3,0.02],[0.45,0.0],[0.6,-0.2],[0.7,-0.22]]))
			else:
				off = Vector3(0.0,_key(u,[[0.19,-0.36],[0.3,-0.3],[0.48,-0.2],[0.65,-0.26],[0.78,-0.34]]),
					_key(u,[[0.19,0.2],[0.3,0.3],[0.48,0.1],[0.65,-0.1],[0.78,-0.2]]))
			var air := tx*(at+off)
			var s := (t-t1)/(t2-t1)
			var low := up.lerp(down,s)+Vector3(0.0,0.15*sin(PI*s),0.0)
			var w := _smooth((t-t1)/0.08)*_smooth((t2-t)/0.08)
			feet[i] = low.lerp(air,w)
		elif t <= t2+stance:
			feet[i] = down+Vector3(0.0,0.0,reach*(t-t2)/stance)
		else:
			# Up again and through to the hang's pose.
			var s := clampf((t-t2-stance)/(0.9-t2-stance),0.0,1.0)
			feet[i] = up.lerp(s0.feet[i],_smooth(s))+Vector3(0.0,(0.2 if fore else 0.08)*sin(PI*s),0.0)
	return p

## The halt's slide (0.35): fores braced ahead, haunches under, the front
## thrown up; then the head turns back over the shoulder, held from 0.6.
func _stop_look(t: float) -> Dictionary:
	var p := _base()
	p.y = _key(t,[[0.0,0.0],[0.35,-0.04,"out"],[0.6,-0.01],[1.2,-0.01]])
	p.z = _key(t,[[0.0,0.0],[0.35,0.03,"out"],[0.6,0.01],[1.2,0.01]])
	p.pitch = _key(t,[[0.0,4.0],[0.35,9.0,"out"],[0.55,0.0],[1.2,0.0]])
	p.neck = _key(t,[[0.0,20.0],[0.35,5.0],[0.6,-14.0,"back"],[1.2,-12.0]])
	p.neck_yaw = _key(t,[[0.0,0.0],[0.35,0.0],[0.6,72.0,"back"],[1.2,70.0]])
	p.head_yaw = _key(t,[[0.0,0.0],[0.4,0.0],[0.6,48.0,"out"],[1.2,46.0]])
	p.head = _key(t,[[0.0,6.0],[0.6,-6.0],[1.2,-6.0]])
	p.ear = _key(t,[[0.0,50.0],[0.35,30.0],[0.6,-25.0,"out"],[1.2,-25.0]])
	p.tail = _key(t,[[0.0,40.0],[0.6,30.0],[1.2,25.0]])
	# The root slides 0.5 BL to a stop by the halt; the feet brace.
	var feet: Array = p.feet
	feet[0] = feet[0]+Vector3(0.0,0.0,_key(t,[[0.0,-0.05],[0.35,-0.1,"out"],[0.6,-0.06],[1.2,-0.06]]))
	feet[1] = feet[1]+Vector3(0.0,0.0,_key(t,[[0.0,-0.08],[0.35,-0.12,"out"],[0.6,-0.05],[1.2,-0.05]]))
	feet[2] = feet[2]+Vector3(0.0,0.0,_key(t,[[0.0,-0.02],[0.35,-0.07,"out"],[0.6,-0.03],[1.2,-0.03]]))
	feet[3] = feet[3]+Vector3(0.0,0.0,_key(t,[[0.0,0.0],[0.35,-0.05,"out"],[0.6,-0.02],[1.2,-0.02]]))
	return p

## Leg `i`'s foot in a cycle at `u` (0 to 1): planted at `plant`, in stance
## for `stance` of the cycle, sliding back under the body by the root's
## travel (`stride` spans a cycle), then swung forward with `lift`.
func _gait_foot(i: int, u: float, plant: float, stance: float, stride: float, lift: float) -> Vector3:
	var at: Vector3 = LEG_AT[LEGS[i]]
	var reach := stride*stance
	var front := at.z-reach*0.5-0.02
	var r := fposmod(u-plant,1.0)
	if r < stance:
		return Vector3(at.x,0.0,front+reach*r/stance)
	var s := (r-stance)/(1.0-stance)
	var y := lift*pow(sin(PI*s),0.8)
	return Vector3(at.x,y,front+reach-reach*_smooth(s))

## Draws foot `i` up toward its hip by `k` (0 to 1): a folded leg.
func _tuck(p: Dictionary, i: int, k: float) -> void:
	var leg: String = LEGS[i]
	var hip := _torso_xform(p)*(LEG_AT[leg] as Vector3)
	var folded := hip+Vector3(0.0,-0.2,-0.03 if leg[0] == "f" else 0.04)
	p.feet[i] = (p.feet[i] as Vector3).lerp(folded,clampf(k,0.0,1.0))

## The fraction of clip `name`'s ground covered by time `t` (its curve,
## straight between points).
static func _curve(name: String, t: float) -> float:
	var c: Array = GROUND_CURVE[name]
	if t <= float(c[0][0]): return float(c[0][1])
	for k in range(1,c.size()):
		if t <= float(c[k][0]):
			var a: Array = c[k-1]
			var b: Array = c[k]
			return lerpf(float(a[1]),float(b[1]),(t-float(a[0]))/maxf(float(b[0])-float(a[0]),1e-5))
	return float(c[-1][1])

func _bump(t: float, a: float, b: float) -> float:
	return sin(PI*clampf((t-a)/(b-a),0.0,1.0))

func _smooth(k: float) -> float:
	k = clampf(k,0.0,1.0)
	return k*k*(3.0-2.0*k)

## Keyed value at `t`: [[time, value, ease]...], held before the first key
## and after the last; each key's ease shapes the way into it: "io" (default,
## smooth), "out" (fast, settling: a snap), "in" (slow, then fast), "back"
## (a snap past the key and back), "lin".
func _key(t: float, keys: Array) -> float:
	if t <= float(keys[0][0]): return float(keys[0][1])
	for k in range(1,keys.size()):
		var b: Array = keys[k]
		if t <= float(b[0]):
			var a: Array = keys[k-1]
			var s := (t-float(a[0]))/maxf(float(b[0])-float(a[0]),1e-4)
			var ease: String = b[2] if b.size() > 2 else "io"
			match ease:
				"out": s = 1.0-pow(1.0-s,3.0)
				"in": s = s*s*s
				"lin": pass
				"back":
					var c := 2.2
					s -= 1.0
					s = 1.0+s*s*((c+1.0)*s+c)
				_: s = s*s*(3.0-2.0*s)
			return lerpf(float(a[1]),float(b[1]),s)
	return float(keys[-1][1])

func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	if a.is_empty(): return b
	var out := {}
	for key: String in b:
		if key == "feet":
			var fa: Array = a.feet
			var fb: Array = b.feet
			var f := []
			for i in range(4): f.append((fa[i] as Vector3).lerp(fb[i],k))
			out.feet = f
		else:
			out[key] = lerpf(float(a.get(key,0.0)),float(b[key]),k)
	return out

# --- The pose on the rig -------------------------------------------------

## The torso's place over the root in pose `p`, in spans.
func _torso_xform(p: Dictionary) -> Transform3D:
	var b := Basis(Vector3.RIGHT,deg_to_rad(float(p.pitch)))
	return Transform3D(b,TORSO_AT+Vector3(0.0,float(p.y),float(p.z)))

func _apply(p: Dictionary) -> void:
	var tx := _torso_xform(p)
	torso.position = tx.origin*S
	torso.basis = tx.basis
	var ny := deg_to_rad(float(p.neck_yaw))
	var hy := deg_to_rad(float(p.head_yaw))
	var np := -deg_to_rad(float(p.neck))
	var hp := -deg_to_rad(float(p.head))
	if _look_weight > 0.0:
		var want := _look_angles()
		ny = lerpf(ny,want.x*0.6,_look_weight)
		hy = lerpf(hy,want.x*0.4,_look_weight)
		hp = lerpf(hp,want.y,_look_weight)
	neck.rotation = Vector3(np,ny,0.0)
	head.rotation = Vector3(hp,hy,0.0)
	var ear := deg_to_rad(float(p.ear))
	ears[0].rotation = Vector3(0.0,ear,0.3)
	ears[1].rotation = Vector3(0.0,-ear,-0.3)
	tail.rotation.x = deg_to_rad(float(p.tail))
	var inv := tx.affine_inverse()
	for i in range(4):
		_solve(LEGS[i],inv*(p.feet[i] as Vector3))

## The look's yaw (left +) and pitch (up -, as the rotation) from the neck's
## base to `_look_at`, clamped to what a neck turns.
func _look_angles() -> Vector2:
	if not is_inside_tree(): return Vector2.ZERO
	var base := torso.global_transform*(NECK_AT*S)
	var local := global_transform.basis.inverse()*(_look_at-base)
	var yaw := atan2(-local.x,-local.z)
	var flat := Vector2(local.x,local.z).length()
	var pitch := atan2(local.y,maxf(flat,0.01))
	return Vector2(clampf(yaw,-2.0,2.0),clampf(pitch*0.8,-0.5,0.6))

## Two-bone IK in the leg's own plane: the hip and knee turned so the foot
## meets `foot` (torso frame, spans); fores bend their knee forward, hinds
## their hock back.
func _solve(leg: String, foot: Vector3) -> void:
	var d := foot-(LEG_AT[leg] as Vector3)
	var l1: float = UPPER[leg]
	var l2: float = LOWER[leg]
	var dist := clampf(Vector2(d.z,d.y).length(),absf(l1-l2)+0.01,(l1+l2)*0.999)
	var a := atan2(-d.z,-d.y)
	var alpha := acos(clampf((l1*l1+dist*dist-l2*l2)/(2.0*l1*dist),-1.0,1.0))
	var bend := PI-acos(clampf((l1*l1+l2*l2-dist*dist)/(2.0*l1*l2),-1.0,1.0))
	if leg[0] == "f":
		_hips[leg].rotation.x = a+alpha
		_knees[leg].rotation.x = -bend
	else:
		_hips[leg].rotation.x = a-alpha
		_knees[leg].rotation.x = bend

# --- Dust ----------------------------------------------------------------

## A puff of grass and dust at `at` (world), `size` times the gallop's.
func _puff(at: Vector3, size := 1.0) -> void:
	if _puffs.is_empty():
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(0.72,0.66,0.5,0.6)
		# A low faceted ball: a puff from any side, no square edges.
		var ball := SphereMesh.new()
		ball.radius = 0.2*S
		ball.height = 0.3*S
		ball.radial_segments = 7
		ball.rings = 3
		for k in range(PUFFS):
			var mi := MeshInstance3D.new()
			mi.mesh = ball
			mi.material_override = mat.duplicate()
			mi.top_level = true
			mi.visible = false
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_puffs.append(mi)
			_puff_age.append(PUFF_LIFE)
			_puff_size.append(1.0)
	var mi := _puffs[_puff_next]
	_puff_age[_puff_next] = 0.0
	_puff_size[_puff_next] = size
	_puff_next = (_puff_next+1)%PUFFS
	mi.global_position = at+Vector3(0.0,0.15*S,0.0)
	mi.visible = true

func _puffs_step(delta: float) -> void:
	for k in range(_puffs.size()):
		if _puff_age[k] >= PUFF_LIFE: continue
		_puff_age[k] += delta
		var mi := _puffs[k]
		var u := _puff_age[k]/PUFF_LIFE
		mi.scale = Vector3.ONE*(0.6+1.6*u)*_puff_size[k]
		mi.global_position.y += delta*0.6
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.6*(1.0-u)
		if u >= 1.0: mi.visible = false

# --- The rig -------------------------------------------------------------

func _build() -> void:
	torso = Node3D.new()
	torso.name = "Torso"
	add_child(torso)
	neck = Node3D.new()
	neck.name = "Neck"
	neck.position = NECK_AT*S
	torso.add_child(neck)
	head = Node3D.new()
	head.name = "Head"
	head.position = NECK_END*S
	neck.add_child(head)
	antlers = Node3D.new()
	antlers.name = "Antlers"
	antlers.visible = false
	head.add_child(antlers)
	for side in [-1.0,1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(side*0.035,0.035,0.01)*S
		head.add_child(ear)
		ears.append(ear)
	tail = Node3D.new()
	tail.position = Vector3(0.0,0.05,0.29)*S
	torso.add_child(tail)
	for leg: String in LEGS:
		var hip := Node3D.new()
		hip.name = "Hip_"+leg
		hip.position = (LEG_AT[leg] as Vector3)*S
		torso.add_child(hip)
		var knee := Node3D.new()
		knee.name = "Knee_"+leg
		knee.position = Vector3(0.0,-float(UPPER[leg]),0.0)*S
		hip.add_child(knee)
		var foot := Node3D.new()
		foot.name = "Foot_"+leg
		foot.position = Vector3(0.0,-float(LOWER[leg]),0.0)*S
		knee.add_child(foot)
		_hips[leg] = hip
		_knees[leg] = knee
		_sockets["foot_"+leg] = foot
	_sockets["head"] = head
	var chest := Node3D.new()
	chest.name = "Chest"
	chest.position = Vector3(0.0,-0.02,-0.27)*S
	torso.add_child(chest)
	_sockets["chest"] = chest
	var rump := Node3D.new()
	rump.name = "Rump"
	rump.position = Vector3(0.0,0.03,0.3)*S
	torso.add_child(rump)
	_sockets["rump"] = rump
	_paint()

## The meshes, in the variant's coat.
func _paint() -> void:
	var c: Dictionary = COATS[variant]
	var body := LifeModels.hex(c.body)
	var mane := LifeModels.hex(c.mane)
	var legs := LifeModels.hex(c.legs)
	var rump := LifeModels.hex(c.rump)
	var nose := LifeModels.hex(c.nose)
	var bull := variant == "bull"
	var s := S
	# The torso: a loft rump to chest, the pale rump patch, the dark belly.
	var b := LifeModels.Build.new()
	var rings := [
		[Vector3(0.0,0.03,0.27)*s,0.085*s,0.075*s,0.10*s],
		[Vector3(0.0,0.02,0.18)*s,0.11*s,0.09*s,0.13*s],
		[Vector3(0.0,0.0,0.02)*s,0.12*s,0.095*s,0.14*s],
		[Vector3(0.0,0.03,-0.14)*s,0.115*s,0.10*s,0.14*s],
		[Vector3(0.0,0.02,-0.25)*s,(0.095 if bull else 0.088)*s,0.09*s,0.12*s],
	]
	var paint := func(u: float, a: float) -> Color:
		if u < 0.2 and sin(a) > -0.6: return rump
		if u > 0.78: return mane
		if sin(a) < -0.55: return body.lerp(mane,0.55)
		return body
	b.loft(rings,8,paint,Vector3(0.0,0.04,0.31)*s,Vector3(0.0,0.0,-0.30)*s)
	_outward(b,0,Vector3(0.0,0.03,0.27)*s,Vector3(0.0,0.02,-0.25)*s)
	_mesh(b,torso)
	# The tail, a pale tuft.
	b = LifeModels.Build.new()
	_spindle(b,Vector3.ZERO,Vector3(0.0,-0.06,0.04)*s,0.022*s,rump,5,0.3)
	_mesh(b,tail)
	# The neck: thick and dark, the bull's mane shaggy underneath.
	b = LifeModels.Build.new()
	var drop := 0.11 if bull else 0.085
	b.loft([[Vector3(0.0,-0.01,0.02)*s,0.085*s,0.08*s,drop*s],[Vector3(0.0,0.08,-0.11)*s,0.06*s,0.06*s,(drop-0.01)*s],
		[NECK_END*s,0.045*s,0.045*s,0.05*s]],7,func(_u: float,_a: float) -> Color: return mane)
	_outward(b,0,Vector3(0.0,-0.01,0.02)*s,NECK_END*s)
	_mesh(b,neck)
	# The head: a long face to a dark muzzle, ears, eyes.
	b = LifeModels.Build.new()
	b.loft([[Vector3(0.0,0.01,0.01)*s,0.045*s,0.045*s,0.05*s],[Vector3(0.0,-0.03,-0.09)*s,0.035*s,0.035*s,0.04*s],
		[Vector3(0.0,-0.055,-0.16)*s,0.028*s,0.025*s,0.03*s]],6,
		func(u: float,_a: float) -> Color: return nose if u > 0.8 else body.lerp(mane,0.5),
		Vector3(0.0,0.02,0.04)*s,Vector3(0.0,-0.065,-0.18)*s)
	_outward(b,0,Vector3(0.0,0.01,0.01)*s,Vector3(0.0,-0.055,-0.16)*s)
	for side in [-1.0,1.0]:
		var at := b.vertices.size()
		b.icosahedron(Vector3(side*0.04,0.0,-0.035)*s,0.011*s,nose)
		_outward(b,at,Vector3(side*0.04,0.0,-0.035)*s,Vector3(side*0.04,0.0,-0.035)*s)
	_mesh(b,head)
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		b = LifeModels.Build.new()
		_spindle(b,Vector3.ZERO,Vector3(side*0.075,0.045,0.02)*s,0.02*s,body.lerp(mane,0.3),4,0.4,0.005*s)
		_mesh(b,ears[k])
	# The legs: a muscled upper, a thin lower, a dark hoof.
	for leg: String in LEGS:
		var fore := leg[0] == "f"
		b = LifeModels.Build.new()
		_spindle(b,Vector3(0.0,0.04,0.0)*s,Vector3(0.0,-float(UPPER[leg])-0.01,0.0)*s,(0.045 if fore else 0.062)*s,
			legs.lerp(body,0.35) if not fore else legs.lerp(mane,0.3),6,0.3)
		_mesh(b,_hips[leg])
		b = LifeModels.Build.new()
		_spindle(b,Vector3(0.0,0.01,0.0)*s,Vector3(0.0,-float(LOWER[leg])+0.02,0.0)*s,0.022*s,legs,5,0.25)
		_spindle(b,Vector3(0.0,-float(LOWER[leg])+0.035,0.0)*s,Vector3(0.0,-float(LOWER[leg]),-0.012)*s,0.024*s,nose,4,0.5)
		_mesh(b,_knees[leg])
	# The bull's antlers: two beams swept up and back, tines forward.
	b = LifeModels.Build.new()
	var bone := LifeModels.hex(c.antler)
	var tip := LifeModels.hex(c.tip)
	var tall := 0.48
	for side in [-1.0,1.0]:
		var beam := [Vector3(side*0.03,0.04,0.0),Vector3(side*0.11,0.14,0.05),Vector3(side*0.17,0.27,0.07),
			Vector3(side*0.19,0.38,0.03),Vector3(side*0.16,tall+0.02,-0.03)]
		for k in range(beam.size()-1):
			_spindle(b,beam[k]*s,beam[k+1]*s,(0.022-0.003*k)*s,bone if k < 3 else tip,5,0.5)
		# Brow, bez and two crown tines, forward and up.
		var tines := [[0,Vector3(side*0.06,0.12,-0.12)],[1,Vector3(side*0.12,0.22,-0.08)],[2,Vector3(side*0.18,0.36,-0.06)],[3,Vector3(side*0.25,0.47,0.02)]]
		for tn: Array in tines:
			var from: Vector3 = (beam[tn[0]] as Vector3).lerp(beam[int(tn[0])+1],0.5)
			_spindle(b,from*s,(tn[1] as Vector3)*s,0.012*s,tip,4,0.35)
	_mesh(b,antlers)

## A Build spindle, faced out.
func _spindle(b: LifeModels.Build, a: Vector3, z: Vector3, radius: float, color: Color, sides := 5, bulge := 0.45, height := -1.0) -> void:
	var at := b.vertices.size()
	b.spindle(a,z,radius,color,sides,bulge,height)
	_outward(b,at,a,z)

## The faces from vertex `from` on turned to face out from the segment
## `a`..`z` (a point when the two are one): Godot's front faces wind
## clockwise seen from outside; their normals out. (LifeModels' own parts
## are drawn double-sided; these are culled.)
func _outward(b: LifeModels.Build, from: int, a: Vector3, z: Vector3) -> void:
	var v := b.vertices
	var n := b.normals
	var c := b.colors
	var axis := z-a
	for i in range(from,v.size(),3):
		var p0 := v[i]
		var p1 := v[i+1]
		var p2 := v[i+2]
		var mid := (p0+p1+p2)/3.0
		var k := clampf((mid-a).dot(axis)/maxf(axis.length_squared(),1e-12),0.0,1.0)
		var out := mid-(a+axis*k)
		var geo := (p1-p0).cross(p2-p0)
		if geo.dot(out) > 0.0:
			v[i+1] = p2
			v[i+2] = p1
			var cc := c[i+1]
			c[i+1] = c[i+2]
			c[i+2] = cc
			geo = -geo
		var nn := -geo.normalized()
		n[i] = nn
		n[i+1] = nn
		n[i+2] = nn
	b.vertices = v
	b.normals = n
	b.colors = c

func _mesh(b: LifeModels.Build, parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(_mat)
	parent.add_child(mi)
	_meshes.append(mi)
