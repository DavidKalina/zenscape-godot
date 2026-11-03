extends Node3D
## Now and then, flying low over a lake, a big fish comes up beside the plane and
## keeps pace with it just under the surface, its back and fin cutting the water,
## for several seconds; it may breach once, then it dives away and is gone. Rarer
## than the leaps: one every GAP s or so of time low over a lake.
##
## What shows: the sea (shaders/endless_sea.gdshader) draws what's under it from
## the screen, faded by the water it's seen through, so the fish is a real body
## under the sheet: a dark shape at a metre down, gone by about four. It swims
## shallow enough that its dorsal cuts the surface now and then. The water over
## it is its own (EndlessSea `swimmers`): a low hump pushed ahead of its head,
## the chop stilled over its back, a little less sky where its body is, and fine
## spray and two short ripples off the fin while it's out.
##
## It is placed by the plane, not by the water: a slot beside it and a little
## ahead (fore, side), where the chase camera, 12 m behind and 3.6 m over the
## plane, has it in view. At 57 m/s that's a cheat, and it's meant to look like a
## powerful animal doing it: a slow, deep beat, its slot drifting, a surge now and
## then.
##
## The body is the leaping fish's (assets/models/fish/hero_fish.glb, bent by
## shaders/wake_fish.gdshader), larger and darker; the splashes and rings when it
## breaches are WakeFish's own (`_splash`, `_mark`).
##
## Nothing here touches the plane.
##
## --swimmer=0 none. --swim-gap=S the mean gap (s), --swim-size=X its length
## times X.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Field = preload("res://scripts/endless/land_field.gd")

## The mean gap (s of time low over a lake) and how far either way it goes; the
## first comes at this share of one.
const GAP := 60.0
const GAP_SPREAD := 0.4
const FIRST := Vector2(0.3,0.7)
## Only this low over the water (m), and this fast (m/s).
const LOW := 14.0
const FAST := 20.0
## Not placed: tried again in this long (s).
const AGAIN := 0.5
## Its length (m), and the companion's share of it; how often there are two.
const LONG := Vector2(4.2,5.4)
const SECOND := Vector2(0.6,0.8)
const PAIR_SHARE := 0.3
const BUILD := Vector2(1.12,1.18)
## The phases (s): up from the deep beside the camera, pacing, diving away.
const RISE := 1.8
const PACE := Vector2(5.0,8.0)
const DIVE := 1.6
## Its slot: fore of the plane's centre (m, the camera's 12 m behind), out to one
## side (m), down from the surface to its middle (m), so about 14-18 m from the
## eye. Deeper than about 1 m it's lost at that range; shallower than 0.6 its
## back lies on top. Off Boost the camera's narrower: the slot is further on by
## up to CRUISE_ON m. It comes up from behind, wide and deep, and dives back and
## away.
const FORE := Vector2(-2.0,4.0)
const CRUISE_ON := 5.0
const BOOST_SPEED := Vector2(42.0,54.0)
const SIDE := Vector2(5.0,6.5)
const DEPTH := 0.78
const START := Vector3(-16.0,11.0,4.0)
const GONE := Vector3(-30.0,13.0,5.5)
## How far its slot wanders (m) and how fast (rad/s).
const WANDER := Vector3(2.5,0.8,0.12)
const WANDER_RATE := Vector3(0.55,0.4,0.9)
## A surge: once in a while it pulls ahead this far (m) for about this long (s).
const SURGE := 4.0
const SURGE_LONG := 1.6
## The breach: this often, this high (m, its middle over the water), this long in
## the air on real gravity.
const BREACH_SHARE := 0.5
const BREACH_PEAK := Vector2(1.6,2.6)
const GRAVITY := 9.8
## The tail (Hz, and its swing) and how far its body turns with its slot (rad
## per m/s sideways or down).
const BEAT_HZ := Vector2(1.6,2.2)
const BEAT := 0.42
const YAW := 0.05
const PITCH := 0.09
## The dorsal's tip over the spine, a share of its length (art/blender/fish/
## fish_build.py: the back at 0.36 of the nose plus the fin's 0.085).
const FIN_TOP := 0.167
## Under the water the sky doesn't reach it: the body's fill, bounce and mirror
## (shaders/wake_fish.gdshader) this much of the leaping fish's, back to all of it
## as it comes out.
const UNDER_LIGHT := 0.35
## Its body takes the water's colour this far over the still sea's level (m).
const WET_BACK := 0.4
## The kind: a dark back, a dull silver flank, a pale belly.
const KIND := {"back":Color(0.04,0.06,0.07),"flank":Color(0.36,0.4,0.4),"belly":Color(0.78,0.78,0.74),"spot":Color(0.03,0.04,0.05),"band":Color(0.3,0.32,0.34),"fin":Color(0.08,0.1,0.11),"spots":0.5,"bands":0.0}

## One swimmer: its slot now and where it's going.
class Swimmer:
	var node: MeshInstance3D
	var mat: ShaderMaterial
	var long := 4.8
	var shape := Vector2.ONE
	var fore := 0.0
	var side := 0.0
	var depth := 0.0
	## Where its slot goes; the companion's offset from the first.
	var to := Vector3.ZERO
	var offset := Vector3.ZERO
	var phase := 0.0
	var beat_hz := 2.0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var yaw := 0.0
	var pitch := 0.0
	var out := false

var wake: Node3D
var _rng := RandomNumberGenerator.new()
var _gap_mean := GAP
var _size := 1.0
var _left := 0.0
var _swim: Array[Swimmer] = []
var _pool: Array[Swimmer] = []
## The moment: running, its clock, its phases' lengths, which side, the breach
## (when, how fast up, and its clock in the air; -1 none).
var _on := false
var _t := 0.0
var _pace := 6.0
var _sign := 1.0
var _breach_at := -1.0
var _breach_v := 0.0
var _air := -1.0
var _surge_at := -1.0
var _spine := PackedVector3Array()
## What the sea is sent for each (`_water`).
var _at: Array[Vector4] = [Vector4.ZERO,Vector4.ZERO]
var _body: Array[Vector4] = [Vector4.ZERO,Vector4.ZERO]
var _warm := 0.5
## For the numbers and probes: time low over a lake (s), moments, breaches, and
## the last one's start (of that time); ms this frame and its mean.
var water_s := 0.0
var count := 0
var breaches := 0
var last_at := -1.0
var ms := 0.0
var ms_avg := 0.0

## --swimmer=0 none.
static func wanted() -> bool:
	return not ("--swimmer=0" in LaunchArgs.user_args())

static func _knob(name: String, otherwise: float) -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--"+name+"="): return a.get_slice("=",1).to_float()
	return otherwise

## `the_wake`: the leaping fish (scripts/endless/wake_fish.gd), whose line, lakes,
## mesh and splashes this uses.
func setup(the_wake: Node3D, mesh: Mesh, shader: Shader, skin: Texture2D) -> void:
	wake = the_wake
	_rng.randomize()
	_gap_mean = maxf(_knob("swim-gap",GAP),0.5)
	_size = maxf(_knob("swim-size",1.0),0.05)
	_left = _gap_mean*_rng.randf_range(FIRST.x,FIRST.y)
	_spine.resize(9)
	for i in 9: _spine[i] = Vector3(0.0,0.42-i/8.0,0.0)
	for i in 2:
		var s := Swimmer.new()
		s.mat = ShaderMaterial.new()
		s.mat.shader = shader
		s.mat.set_shader_parameter("skin",skin)
		s.mat.set_shader_parameter("spine",_spine)
		s.mat.set_shader_parameter("back_tint",KIND.back)
		s.mat.set_shader_parameter("flank_tint",KIND.flank)
		s.mat.set_shader_parameter("belly_tint",KIND.belly)
		s.mat.set_shader_parameter("spot_tint",KIND.spot)
		s.mat.set_shader_parameter("band_tint",KIND.band)
		s.mat.set_shader_parameter("fin_tint",KIND.fin)
		s.mat.set_shader_parameter("spot_share",KIND.spots)
		s.mat.set_shader_parameter("band_share",KIND.bands)
		s.mat.set_shader_parameter("under",1.0)
		# Over the still sea's level by a swell's trough: the swell lays its back
		# bare now and then, and dry it reads as a fish lying on the water.
		s.mat.set_shader_parameter("surface_y",Field.SEA_Y+WET_BACK)
		s.node = MeshInstance3D.new()
		s.node.name = "Swimmer%d" % i
		s.node.mesh = mesh
		s.node.material_override = s.mat
		s.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Folded, and moved by hand: never culled by a stale box.
		s.node.custom_aabb = AABB(Vector3(-4.0,-4.0,-4.0),Vector3(8.0,8.0,8.0))
		s.node.scale = Vector3.ONE*0.001
		s.node.top_level = true
		add_child(s.node)
		_pool.append(s)

## One frame, after WakeFish read the plane's line.
func step(delta: float) -> void:
	var began := Time.get_ticks_usec()
	if _warm > 0.0:
		_warm -= delta
		if _warm <= 0.0:
			for s: Swimmer in _pool: s.node.visible = false
	if _on: _run(delta)
	else: _wait(delta)
	ms = (Time.get_ticks_usec()-began)/1000.0
	ms_avg = lerpf(ms_avg,ms,0.05)

func _wait(delta: float) -> void:
	if not wake._low or wake._high > LOW: return
	water_s += delta
	_left -= delta
	if _left > 0.0 or wake._speed < FAST: return
	if not _start():
		_left = AGAIN
		return
	_left = _gap_mean*_rng.randf_range(1.0-GAP_SPREAD,1.0+GAP_SPREAD)

## Begins one, on the side with water all along its stay: false if neither has.
func _start() -> bool:
	var pace := _rng.randf_range(PACE.x,PACE.y)
	var sign := 1.0 if _rng.randf() < 0.5 else -1.0
	var side := _rng.randf_range(SIDE.x,SIDE.y)
	for i in 2:
		if _clear(sign*side,RISE+pace+DIVE):
			_begin(pace,sign,side)
			return true
		sign = -sign
	return false

## Lake under a slot `side` m out along the plane's line for `long` s.
func _clear(side: float, long: float) -> bool:
	var t := 0.0
	while t <= long:
		var p: Vector3 = wake._line(t)+wake._right*side
		if not wake._lake(p.x,p.z): return false
		t += 0.5
	return true

func _begin(pace: float, sign: float, side: float) -> void:
	_on = true
	_t = 0.0
	_pace = pace
	_sign = sign
	_air = -1.0
	_breach_at = RISE+_rng.randf_range(0.3,0.65)*pace if _rng.randf() < BREACH_SHARE else -1.0
	_surge_at = RISE+_rng.randf_range(0.15,0.8)*pace
	count += 1
	last_at = water_s
	_swim.clear()
	var long := _rng.randf_range(LONG.x,LONG.y)*_size
	var first := _pool[0]
	_ready_one(first,long,Vector3(_rng.randf_range(FORE.x,FORE.y),side,DEPTH),Vector3.ZERO)
	if _rng.randf() < PAIR_SHARE:
		var off := Vector3(_rng.randf_range(-6.0,-3.0),_rng.randf_range(1.8,3.0),_rng.randf_range(0.15,0.35))
		_ready_one(_pool[1],long*_rng.randf_range(SECOND.x,SECOND.y),first.to,off)

func _ready_one(s: Swimmer, long: float, to: Vector3, offset: Vector3) -> void:
	s.long = long
	s.shape = BUILD*_rng.randf_range(0.96,1.04)
	s.to = to
	s.offset = offset
	s.fore = START.x+offset.x
	s.side = START.y+offset.y
	s.depth = START.z+offset.z
	s.phase = _rng.randf()*TAU
	s.beat_hz = _rng.randf_range(BEAT_HZ.x,BEAT_HZ.y)*sqrt(4.8/maxf(long,1.0))
	s.out = false
	s.yaw = 0.0
	s.pitch = 0.0
	s.pos = _world(s.fore,s.side,s.depth)
	s.node.visible = true
	_swim.append(s)

## A slot's place in the world now.
func _world(fore: float, side: float, depth: float) -> Vector3:
	fore += CRUISE_ON*(1.0-smoothstep(BOOST_SPEED.x,BOOST_SPEED.y,float(wake._speed)))
	var p: Vector3 = wake._at+wake._ahead*fore+wake._right*side*_sign
	p.y = Field.SEA_Y-depth
	return p

func _run(delta: float) -> void:
	_t += delta
	var end := RISE+_pace+DIVE
	# Gone early: the plane climbed away, or its slot ran out of lake.
	var dive_from := RISE+_pace
	if _t < dive_from and _air < 0.0:
		var first := _swim[0]
		var here := first.pos
		if wake._high > LOW*1.6 or not wake._lake(here.x,here.z):
			_pace = maxf(_t-RISE,0.0)
			dive_from = _t
			end = _t+DIVE
	if _t >= end:
		_finish()
		return
	if _breach_at > 0.0 and _air < 0.0 and _t >= _breach_at and _t < dive_from-1.0:
		_air = 0.0
		var peak := _rng.randf_range(BREACH_PEAK.x,BREACH_PEAK.y)
		_breach_v = sqrt(2.0*GRAVITY*(peak+DEPTH))
		_breach_at = -1.0
		breaches += 1
	var lead := _swim[0]
	for s: Swimmer in _swim:
		var want := _slot(s,lead,dive_from)
		var was := s.pos
		var k := 1.0-exp(-delta/0.35)
		s.fore = lerpf(s.fore,want.x,k if _t > RISE else 1.0)
		s.side = lerpf(s.side,want.y,k if _t > RISE else 1.0)
		s.depth = lerpf(s.depth,want.z,k if _t > RISE else 1.0)
		if s == lead and _air >= 0.0: s.depth = _breach(delta)
		s.pos = _world(s.fore,s.side,s.depth)
		s.vel = (s.pos-was)/maxf(delta,1e-4)
		_pose(s,delta)
	_water()

## Where its slot should be at this moment of the moment.
func _slot(s: Swimmer, lead: Swimmer, dive_from: float) -> Vector3:
	var t := _t
	var base := s.to+s.offset
	if s != lead: base = Vector3(lead.fore,lead.side,maxf(lead.depth,lead.to.z))+s.offset
	var w := Vector3(WANDER.x*sin(t*WANDER_RATE.x+s.phase),WANDER.y*sin(t*WANDER_RATE.y+s.phase*1.7),WANDER.z*sin(t*WANDER_RATE.z+s.phase*0.6))
	var surge := SURGE*exp(-pow((t-_surge_at)/(SURGE_LONG*0.5),2.0))
	var paced := base+(w+Vector3(surge,0.0,0.0) if s == lead else Vector3.ZERO)
	if t < RISE:
		var u := smoothstep(0.0,1.0,t/RISE)
		var from := START+s.offset
		# Up late: it comes along wide and deep, then rises as it closes in.
		var up := smoothstep(0.25,1.0,t/RISE)
		return Vector3(lerpf(from.x,paced.x,u),lerpf(from.y,paced.y,u),lerpf(from.z,paced.z,up))
	if t > dive_from:
		var u := smoothstep(0.0,1.0,(t-dive_from)/DIVE)
		var to := GONE+s.offset
		return Vector3(lerpf(paced.x,to.x,u*u),lerpf(paced.y,to.y,u),lerpf(paced.z,to.z,sqrt(u)))
	return paced

## The breach on real gravity: its middle's depth (under the surface, + down).
func _breach(delta: float) -> float:
	var was_air := _air
	_air += delta
	var up := _breach_v*_air-0.5*GRAVITY*_air*_air
	var depth := DEPTH-up
	var lead := _swim[0]
	var way: Vector3 = wake._ahead*wake._speed
	var vy := _breach_v-GRAVITY*_air
	if not lead.out and depth < 0.0 and was_air >= 0.0:
		lead.out = true
		wake._splash(Vector3(lead.pos.x,Field.SEA_Y,lead.pos.z),way*0.2+Vector3.UP*vy,lead.long/0.6*0.8,false)
	if lead.out and vy < 0.0 and depth > 0.0:
		lead.out = false
		var at := Vector3(lead.pos.x,Field.SEA_Y,lead.pos.z)
		wake._splash(at,way*0.2+Vector3.UP*vy,lead.long/0.6,true)
		wake._splash(at,way*0.1+Vector3.UP*vy*0.5,lead.long/0.6*0.7,true,0.16)
		wake._mark(at,wake._clock,lead.long/0.6)
	if up < 0.0 and vy < 0.0:
		_air = -1.0
		return DEPTH
	return depth

## The body: along its way, turned by its slot's drift, the tail beating slow.
func _pose(s: Swimmer, delta: float) -> void:
	var ahead: Vector3 = wake._ahead
	var right: Vector3 = wake._right*_sign
	var rel: Vector3 = s.vel-ahead*float(wake._speed)
	var want_yaw := clampf(rel.dot(right)*YAW,-0.5,0.5)
	var want_pitch := clampf(s.vel.y*PITCH,-0.9,0.9)
	if _air >= 0.0 and s == _swim[0]: want_pitch = clampf(atan2(s.vel.y,9.0),-1.1,1.1)
	var k := 1.0-exp(-delta/0.2)
	s.yaw = lerpf(s.yaw,want_yaw,k)
	s.pitch = lerpf(s.pitch,want_pitch,k)
	var flat := ahead.rotated(Vector3.UP,-s.yaw*_sign)
	var fore := (flat*cos(s.pitch)+Vector3.UP*sin(s.pitch)).normalized()
	var over := Vector3.UP.cross(fore).normalized()
	var b := Basis(over,fore.cross(over),fore)
	s.node.global_transform = Transform3D(b*Basis.from_scale(Vector3(s.long*s.shape.x,s.long*s.shape.y,s.long)),s.pos)
	var wave := TAU*s.beat_hz*_t+s.phase
	var bend := -s.yaw*1.5
	var head := 0.7*(bend*(0.25-0.42)+BEAT*pow(0.25,1.6)*sin(wave-0.25*5.0))
	var x := 0.0
	var z := 0.42
	for i in 9:
		var f := i/8.0
		var theta := bend*(f-0.42)+BEAT*pow(f,1.6)*sin(wave-f*5.0)-head
		if i > 0:
			x += sin(theta)/8.0
			z -= cos(theta)/8.0
		_spine[i] = Vector3(x,z,theta)
	var mid := _spine[3]
	for i in 9: _spine[i] -= Vector3(mid.x,mid.y-(0.42-3.0/8.0),0.0)
	s.mat.set_shader_parameter("spine",_spine)
	s.mat.set_shader_parameter("flare",-0.4)
	var lit := lerpf(1.0,UNDER_LIGHT,smoothstep(-0.2,0.6,s.depth))
	# The flank's shine is the sky's and the sun's off it in the air: under, the
	# surface takes them, or it shows as a white fish lying on the water.
	var shine := 1.0-smoothstep(-0.3,0.4,s.depth)
	s.mat.set_shader_parameter("fill",2.2*lit)
	s.mat.set_shader_parameter("bounce",3.0*lit)
	s.mat.set_shader_parameter("mirror",0.9*shine)
	s.mat.set_shader_parameter("flash",3.0*shine)

## The water over them: a hump pushed ahead of each, the chop stilled over its
## back, its body darker, and spray where its fin cuts (EndlessSea `swimmers`).
func _water() -> void:
	if wake.sea == null: return
	_swim_mark(0)
	_swim_mark(1)
	wake.sea.swimmers(_at[0],_body[0],_at[1],_body[1],_swim.size())

## The sea's numbers for swimmer `i`: where it is and which way, its length, its
## middle's depth, how far its fin stands out, and how strong (none in the air).
func _swim_mark(i: int) -> void:
	if i >= _swim.size():
		_body[i] = Vector4.ZERO
		return
	var s := _swim[i]
	var fore := s.node.global_transform.basis.z
	var way := Vector2(fore.x,fore.z)
	way = way/way.length() if way.length_squared() > 1e-6 else Vector2(wake._ahead.x,wake._ahead.z)
	_at[i] = Vector4(s.pos.x,s.pos.z,way.x,way.y)
	var fin := FIN_TOP*s.long*s.shape.y-s.depth
	_body[i] = Vector4(s.long,s.depth,fin,0.0 if s.out else 1.0)

func _finish() -> void:
	_on = false
	for s: Swimmer in _swim: s.node.visible = false
	_swim.clear()
	if wake.sea != null: wake.sea.swimmers(Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,0)

## The numbers' line (--numbers).
func note() -> String:
	return "\nswimmer: low over a lake %.0f s, next in %.0f s, %d (%d breached)%s  %.2f ms (%.2f)" % [water_s,_left,count,breaches," swimming" if _on else "",ms,ms_avg]
