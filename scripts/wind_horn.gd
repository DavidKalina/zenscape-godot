extends Node
## The wind-horn's runtime (scripts/ruin_kit_horn.gd builds the stone and
## adds this as its "Rig"): the head turns, draws its breath, kicks, and can
## be knocked out for a while. Light: a handful of dust motes and leaves
## and a few puffs, plain meshes, nothing glowing.
##   aim_at(point, delta)   turn the head and pitch the barrel toward a
##                          world point: heavy, but it keeps up
##   aim_error(point)       radians between the barrel's facing and a point
##   tell(share)            the wind-up, 0..1 (below 0: no tell)
##   fired()                the kick and the puff at the shot
##   disabled(seconds)      slumped and mouth tipped down, then it grinds up
##   is_disabled()
## The head's yaw is about +Y from +Z (the way the Mouth points); the
## barrel's pitch about its trunnion's x, positive down.

## The head's turn: it closes TURN_GAIN of its error a second, never faster
## than TURN_RATE (rad/s): heavy, grinding, settling onto him, but quick
## enough to keep a running or gliding pilot in its mouth at its range.
## The barrel's pitch the same (PITCH_GAIN, PITCH_RATE), up to PITCH_UP
## over level and PITCH_DOWN under it (rad): steep up at a pilot over it;
## down only as far as the bell clears its own pedestal, so under its lip
## is out of its reach.
const TURN_RATE := 2.4
const TURN_GAIN := 10.0
const PITCH_RATE := 1.8
const PITCH_GAIN := 10.0
const PITCH_UP := 1.22
const PITCH_DOWN := 0.3
## Disabled: the mouth tips down this far (rad), the head sags sideways
## (roll, rad) and drops (m); the last share of the time it grinds back up.
const DROOP_PITCH := 0.6
const DROOP_ROLL := 0.14
const DROOP_DROP := 0.12
const RISE_SHARE := 0.35
## The recoil kick: its speed (m/s) back along the head's axis, the pitch it
## throws up per metre of recoil (rad), and the spring that takes it out.
const KICK_SPEED := 4.5
const KICK_PITCH := 0.3
const KICK_STIFF := 70.0
const KICK_DAMP := 9.0
## The bell's shudder at the full tell (m).
const SHUDDER := 0.02
const MOTES := 16
const PUFFS := 14
const DUST := Color(0.86,0.82,0.70)
const LEAF := Color(0.36,0.5,0.24)
## How far from the mouth the drawn-in motes start (m).
const DRAW_FROM := Vector2(2.0,5.0)

var yaw := 0.0
var pitch := 0.0
var _head: Node3D
var _barrel: Node3D
var _mouth: Node3D
var _base := Vector3.ZERO
var _pivot := Vector3.ZERO
var _recoil := 0.0
var _recoil_v := 0.0
var _left := 0.0
var _total := 1.0
var _share := -1.0
var _telling := 0.0
var _dust_t := 0.0
var _clock := 0.0
var _motes: Array = []
var _puffs: Array = []
var _rng := RandomNumberGenerator.new()
var _sound: AudioStreamPlayer3D
var _mouth_r := 0.8

func _ready() -> void:
	_head = get_parent().get_node("Head")
	_barrel = _head.get_node("Barrel")
	_mouth = _barrel.get_node("Mouth")
	_base = _head.position
	_pivot = _barrel.position
	_mouth_r = float(get_parent().get_meta("mouth_radius",0.8))
	_rng.seed = 11
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.05
	dust_mesh.height = 0.1
	dust_mesh.radial_segments = 6
	dust_mesh.rings = 3
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = Vector3(0.16,0.02,0.1)
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 0.5
	puff_mesh.height = 1.0
	puff_mesh.radial_segments = 8
	puff_mesh.rings = 4
	for i in range(MOTES):
		var leaf := i%3 == 0
		var m := _blob(leaf_mesh if leaf else dust_mesh,LEAF if leaf else DUST,_barrel)
		_motes.append({"node":m,"phase":_rng.randf(),"from":_far(),"spin":_rng.randf_range(-6.0,6.0)})
	for i in range(PUFFS):
		_puffs.append({"node":_blob(puff_mesh,DUST,self,true),"age":1.0,"life":1.0,"pos":Vector3.ZERO,"vel":Vector3.ZERO,"s0":0.2,"s1":0.5,"a":0.4})
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = _crack()
	_sound.unit_size = 14.0
	add_child(_sound)

## Turn the head and pitch the barrel toward `point` (world) (TURN_GAIN,
## TURN_RATE; PITCH_GAIN, PITCH_RATE): the barrel's axis through the point.
## Nothing while disabled.
func aim_at(point: Vector3, delta: float) -> void:
	if _left > 0.0 or _head == null: return
	var parent := _head.get_parent() as Node3D
	var local: Vector3 = parent.to_local(point)-_base
	var flat := Vector2(local.x,local.z)
	var before := yaw
	if flat.length() > 0.1:
		var turn := TURN_RATE*delta
		yaw += clampf(angle_difference(yaw,atan2(local.x,local.z))*minf(TURN_GAIN*delta,1.0),-turn,turn)
		# From the trunnion (out along the yaw, up AXIS): the axis's pitch.
		var want := clampf(-atan2(local.y-_pivot.y,flat.length()-_pivot.z),-PITCH_UP,PITCH_DOWN)
		var tip := PITCH_RATE*delta
		pitch += clampf((want-pitch)*minf(PITCH_GAIN*delta,1.0),-tip,tip)
	# Grinding: stone dust off the turntable's edge while it turns.
	_dust_t -= delta
	if absf(yaw-before) > 0.5*delta and _dust_t <= 0.0:
		_dust_t = 0.3
		var at := parent.to_global(_base+Vector3(sin(yaw),0.1,cos(yaw))*-1.1)
		_puff(at,Vector3(_rng.randf_range(-0.3,0.3),0.5,_rng.randf_range(-0.3,0.3)),0.12,0.4,0.7,0.3)
	_apply()

## The wind-up's share, 0..1 (DragonAirBlast.windup_share(); -1 when not
## winding up). Dust and leaves drawn into the mouth, the bell shuddering.
## Nothing while disabled.
func tell(share: float) -> void:
	if _left > 0.0 or share < 0.0:
		_share = -1.0
		return
	_share = share
	_telling = 0.15

## The shot has left: the head kicks back and the mouth puffs.
func fired() -> void:
	if _left > 0.0: return
	_recoil_v = KICK_SPEED
	_share = -1.0
	var way := _mouth.global_transform.basis.z
	for i in range(7):
		var d := (way+Vector3(_rng.randf_range(-0.5,0.5),_rng.randf_range(-0.4,0.5),_rng.randf_range(-0.5,0.5))).normalized()
		_puff(_mouth.global_position+way*0.2,d*_rng.randf_range(2.5,5.0),_mouth_r*0.4,_mouth_r*1.3,_rng.randf_range(0.5,0.9),0.45)

## Knocked out for `seconds`: the head slumps, the mouth tips down; over the
## last RISE_SHARE of it the head grinds back up. aim_at and tell do
## nothing meanwhile.
func disabled(seconds: float) -> void:
	_total = maxf(seconds,0.1)
	_left = _total
	_share = -1.0
	for i in range(9):
		var a := TAU*i/9.0+_rng.randf()
		var out := Vector3(cos(a),0.0,sin(a))
		_puff(_head.global_position+out*1.0+Vector3(0.0,1.2,0.0),out*_rng.randf_range(1.0,2.5)+Vector3(0.0,1.2,0.0),0.25,1.0,_rng.randf_range(0.6,1.1),0.55)
	if _sound.is_inside_tree():
		_sound.global_position = _head.global_position+Vector3(0.0,1.2,0.0)
		_sound.play()

func is_disabled() -> bool:
	return _left > 0.0

## The angle (rad) between the barrel's facing and the way from its mouth
## to `point` (world): under a few degrees, a shot leaves at him.
func aim_error(point: Vector3) -> float:
	if _mouth == null: return PI
	var to := point-_mouth.global_position
	if to.length() < 0.01: return 0.0
	return _mouth.global_transform.basis.z.angle_to(to)

## The way the barrel faces (world, unit).
func facing() -> Vector3:
	return _mouth.global_transform.basis.z.normalized() if _mouth != null else Vector3.FORWARD

func _process(delta: float) -> void:
	if _head == null: return
	_clock += delta
	var was := _left
	_left = maxf(0.0,_left-delta)
	if was > 0.0 and _left <= 0.0:
		# Back on its feet: a last puff of dust off the turntable.
		for i in range(4):
			_puff(_head.global_position+Vector3(_rng.randf_range(-1.0,1.0),0.2,_rng.randf_range(-1.0,1.0)),Vector3(0.0,0.8,0.0),0.15,0.6,0.8,0.35)
	_telling = maxf(0.0,_telling-delta)
	if _telling <= 0.0: _share = -1.0
	# The kick: a spring back to rest.
	_recoil_v += (-KICK_STIFF*_recoil-KICK_DAMP*_recoil_v)*delta
	_recoil += _recoil_v*delta
	_apply()
	_step_motes(delta)
	_step_puffs(delta)

## The slump (0..1): in quickly, held, then eased out over the last share.
func _slump() -> float:
	if _left <= 0.0: return 0.0
	var e := 1.0-_left/_total
	return smoothstep(0.0,0.12,e)*(1.0-smoothstep(1.0-RISE_SHARE,1.0,e))

func _apply() -> void:
	var s := _slump()
	var shake := SHUDDER*maxf(_share,0.0)*maxf(_share,0.0)
	# While it grinds back up the rise judders.
	if _left > 0.0 and _left < _total*RISE_SHARE: shake += 0.012*s
	var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,DROOP_PITCH*s)*Basis(Vector3.BACK,DROOP_ROLL*s)
	_head.basis = basis
	var judder := Vector3(sin(_clock*61.0),sin(_clock*47.0+1.0),0.0)*shake
	_head.position = _base+Vector3(0.0,-DROOP_DROP*s,0.0)+basis*judder
	# The barrel: its aim, eased level in the slump, and the kick back along
	# its own axis.
	var tilt := Basis(Vector3.RIGHT,pitch*(1.0-s)-_recoil*KICK_PITCH)
	_barrel.basis = tilt
	_barrel.position = _pivot-tilt.z*_recoil

func _step_motes(delta: float) -> void:
	for m: Dictionary in _motes:
		var node := m.node as MeshInstance3D
		if _share < 0.0:
			node.visible = false
			continue
		# Each mote runs in twice over the wind-up, from round the mouth in
		# front of it to the mouth, faster as it nears.
		var t := fposmod(_share*2.0+float(m.phase),1.0)
		var pull := pow(t,2.2)
		node.position = _mouth.position+(m.from as Vector3)*(1.0-pull)
		node.rotation += Vector3(float(m.spin),float(m.spin)*0.6,0.0)*delta
		node.scale = Vector3.ONE*(1.0-0.5*pull)
		node.transparency = 1.0-0.7*smoothstep(0.0,0.15,t)*(1.0-smoothstep(0.85,1.0,t))
		node.visible = true

func _far() -> Vector3:
	var d := Vector3(_rng.randf_range(-1.0,1.0),_rng.randf_range(-0.7,1.0),_rng.randf_range(0.0,1.0)).normalized()
	return d*_rng.randf_range(DRAW_FROM.x,DRAW_FROM.y)*0.8

func _puff(at: Vector3, vel: Vector3, s0: float, s1: float, life: float, alpha: float) -> void:
	var pick: Dictionary = _puffs[0]
	for p: Dictionary in _puffs:
		if float(p.age) >= float(p.life):
			pick = p
			break
		if float(p.age)/float(p.life) > float(pick.age)/float(pick.life): pick = p
	pick.pos = at
	pick.vel = vel
	pick.age = 0.0
	pick.life = life
	pick.s0 = s0
	pick.s1 = s1
	pick.a = alpha

func _step_puffs(delta: float) -> void:
	for p: Dictionary in _puffs:
		var node := p.node as MeshInstance3D
		if float(p.age) >= float(p.life):
			node.visible = false
			continue
		p.age = float(p.age)+delta
		var u := clampf(float(p.age)/float(p.life),0.0,1.0)
		p.vel = (p.vel as Vector3)*(1.0-2.0*delta)
		p.pos = (p.pos as Vector3)+(p.vel as Vector3)*delta
		node.global_position = p.pos
		node.scale = Vector3.ONE*lerpf(float(p.s0),float(p.s1),sqrt(u))
		node.transparency = 1.0-float(p.a)*(1.0-u)
		node.visible = true

func _blob(mesh: Mesh, tint: Color, parent: Node, free := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	if free: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	node.visible = false
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = free
	parent.add_child(node)
	return node

## A dull crack and a grind: a burst of noise over a low thump.
func _crack() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate*0.7)
	var data := PackedByteArray()
	data.resize(n*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var low := 0.0
	for i in range(n):
		var t := float(i)/rate
		low += (rng.randf_range(-1.0,1.0)-low)*0.12
		var v := low*2.2*exp(-t*5.0)+sin(TAU*58.0*t)*0.6*exp(-t*9.0)+rng.randf_range(-1.0,1.0)*0.4*exp(-t*40.0)
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
