extends Node3D
## Endless flight's motes, cosmetic only: two small CPU-run swarms drawn
## as one MultiMesh each.
##
##   pollen  POLLEN specks (shaders/pollen_speck.gdshader, lit soft dots
##           drawn out along their way) drift on the breeze round the eye
##           while it is within POLLEN_UP m of grassy land: POLLEN_HIGH m
##           over the ground, wandering on slow sines, fading in and out
##           over a life of POLLEN_LIFE s. The swarm's disc (POLLEN_REACH
##           m) is led ahead along the eye's travel, and a speck that falls
##           out of it comes back on its far side, so a passing plane flies
##           through them rather than past an empty patch.
##   kick    bits of grass blade (WindGrassChaff's blade mesh) thrown up
##           where the prop's wash comes down (GrassReact `wash_spot`), up
##           to KICK_RATE a second at full wash, flung out from its middle
##           and back along the plane's way, tumbling, slowed by the air and
##           falling back; and a few off any eddy (EndlessEddies' ribbons)
##           skimming within EDDY_SKIM m of the grass.
##
## Flags: --no-motes (none), --no-pollen, --no-grass-kick, --pollen=X (the
## specks' count, a share of POLLEN), --grass-kick=X (the kick's rate).

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Chaff = preload("res://scripts/wind_grass_chaff.gd")
const SPECK = preload("res://shaders/pollen_speck.gdshader")
const BIT = preload("res://shaders/grass_bit.gdshader")

const POLLEN := 260
const POLLEN_UP := 30.0
const POLLEN_REACH := 22.0
const POLLEN_HIGH := Vector2(0.4,5.0)
const POLLEN_LIFE := Vector2(5.0,11.0)
## A speck's size (m) and opacity, its colour (linear: a warm cream).
const POLLEN_SIZE := Vector2(0.09,0.16)
const POLLEN_OPACITY := 0.75
const POLLEN_COLOUR := Color(1.0,0.9,0.62)
## The lead ahead of the eye: its travel over this many seconds.
const POLLEN_LEAD := 0.6
## The specks' own wander (m/s) over the breeze's drift (a share of it).
const POLLEN_WANDER := 0.45
const POLLEN_DRIFT := 0.55

## The storm's gust front (lane gust): the most it adds to the specks' drift
## (m/s) at its peak; `storm_air` is set each frame from the gust at the eye.
const STORM_AIR := 16.0
var storm_air := 0.0
## The storm's hush (0..1), set each frame from the storm at the eye
## (StormFront `here`): under the core the rain washes the pollen out
## (the swarm fades to none) and the specks' and bits' own little light
## goes, so nothing glows like a firefly under the dark deck.
var storm_hush := 0.0
var _hush_shown := -1.0
var _speck_mat: ShaderMaterial
var _bit_mat: ShaderMaterial

const KICK := 180
const KICK_RATE := 120.0
## A bit's length (m: the endless grass is about four times the isles'),
## its fling out and up (m/s, at full wash), the share blown back along the
## plane's way, its drag (1/s) and fall (m/s^2), and its life (s).
const KICK_SIZE := Vector2(0.45,0.9)
## How much wider than WindGrassChaff's blade (0.07 a metre of length) the
## bits are: the endless grass's blades are broad.
const KICK_WIDE := 3.0
const KICK_OUT := Vector2(2.5,6.5)
const KICK_UP := Vector2(3.5,8.0)
const KICK_BACK := 3.0
## The share of the eye's travel the bits are carried on with at first (the
## plane's wake drags them along), so they stream back past the chase view
## rather than being left at once behind it.
const KICK_CARRY := 0.8
const KICK_DRAG := 0.9
const KICK_FALL := 5.0
const KICK_LIFE := Vector2(1.4,2.8)
## Where a bit starts (m over the ground: the tall grass's upper blades) and
## the height under which it is back in the grass and goes.
const KICK_FROM := Vector2(0.7,1.3)
const KICK_SINK := 0.6
## A skimming eddy's bits a second, and how low it skims (m over the ground).
const EDDY_RATE := 14.0
const EDDY_SKIM := 1.2
## The bits' colours (sRGB): sunlit tips, pale undersides and dry straw,
## lighter than the standing grass so they read against it.
const KICK_COLOURS := ["c8dc8a","b5cf76","e0dca4","d2c98e"]

var pollen_on := true
var kick_on := true
var pollen_count := POLLEN
var kick_scale := 1.0
## For the numbers: specks shown, bits flying.
var stats := {"pollen": 0, "kick": 0}

var _rng := RandomNumberGenerator.new()
var _ground: Callable
var _specks: Array[Dictionary] = []
var _bits: Array[Dictionary] = []
var _pollen_mm: MultiMesh
var _kick_mm: MultiMesh
var _pollen_buf := PackedFloat32Array()
var _kick_buf := PackedFloat32Array()
var _last_eye := Vector3.INF
var _eye_vel := Vector3.ZERO
var _travel := NAN
var _air := Vector2.ZERO
var _kick_owed := 0.0
var _eddy_owed := {}
var _time := 0.0
var _show := 0.0

static func wanted() -> bool:
	return not "--no-motes" in LaunchArgs.user_args()

func setup(land_seed: int, ground: Callable) -> void:
	name = "EndlessMotes"
	_rng.seed = land_seed*6271+5
	_ground = ground
	for a: String in LaunchArgs.user_args():
		if a == "--no-pollen": pollen_on = false
		elif a == "--no-grass-kick": kick_on = false
		elif a.begins_with("--pollen="): pollen_count = clampi(roundi(POLLEN*float(a.get_slice("=",1))),0,POLLEN*4)
		elif a.begins_with("--grass-kick="): kick_scale = maxf(float(a.get_slice("=",1)),0.0)
	if pollen_count == 0: pollen_on = false
	if kick_scale <= 0.0: kick_on = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var speck := ShaderMaterial.new()
	speck.shader = SPECK
	quad.material = speck
	_speck_mat = speck
	_pollen_mm = _batch("Pollen",quad,pollen_count,true)
	_pollen_buf.resize(pollen_count*20)
	var blade: Mesh = Chaff._chaff_mesh()
	var m := ShaderMaterial.new()
	m.shader = BIT
	_bit_mat = m
	_kick_mm = _batch("GrassKick",blade,KICK,false,m)
	_kick_buf.resize(KICK*16)

func _batch(label: String, mesh: Mesh, count: int, custom: bool, look: Material = null) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = label
	mmi.multimesh = mm
	mmi.material_override = look
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# They follow the eye: never culled by the batch's own box.
	mmi.custom_aabb = AABB(Vector3.ONE*-1.0e5,Vector3.ONE*2.0e5)
	add_child(mmi)
	return mm

## One frame. `eye` the drawing camera; `wind` the breeze's way and `travel`
## the air's (EndlessLook wind_direction, _gust); `wash` GrassReact
## wash_spot; `ribbons` the eddies' live ribbons (or []); `grass` Callable(x,
## z) -> height where grass grows, else NAN.
func step(delta: float, eye: Vector3, wind: Vector2, travel: float, wash: Dictionary, ribbons: Array, grass: Callable) -> void:
	if delta <= 0.0: return
	_time += delta
	if _last_eye != Vector3.INF:
		var v := (eye-_last_eye)/delta
		# A jump (a reset, the start) is not travel.
		if v.length() > 200.0: v = Vector3.ZERO
		_eye_vel = _eye_vel.lerp(v,clampf(delta*4.0,0.0,1.0))
	_last_eye = eye
	var speed := 0.0
	if not is_nan(_travel): speed = clampf((travel-_travel)/delta,0.0,20.0)
	_travel = travel
	_air = wind.normalized()*(speed+storm_air)
	if absf(storm_hush-_hush_shown) > 0.01:
		_hush_shown = storm_hush
		_speck_mat.set_shader_parameter("self_light",1.0-storm_hush)
		_bit_mat.set_shader_parameter("self_light",1.0-storm_hush)
	if pollen_on: _pollen(delta,eye,grass)
	if kick_on: _kick(delta,wash,ribbons)

# --- Pollen ---------------------------------------------------------------------------

func _pollen(delta: float, eye: Vector3, grass: Callable) -> void:
	var under := float(grass.call(eye.x,eye.z))
	var low := not is_nan(under) and eye.y-under < POLLEN_UP
	_show = move_toward(_show,(1.0-storm_hush) if low else 0.0,delta*0.8)
	if _show <= 0.0:
		if not _specks.is_empty(): _specks.clear()
		_pollen_mm.visible_instance_count = 0
		stats.pollen = 0
		return
	var lead := Vector2(_eye_vel.x,_eye_vel.z)*POLLEN_LEAD
	if lead.length() > POLLEN_REACH*0.8: lead = lead.normalized()*POLLEN_REACH*0.8
	var centre := Vector2(eye.x,eye.z)+lead
	while _specks.size() < pollen_count:
		var s := {}
		_spawn_speck(s,centre,grass,true)
		_specks.append(s)
	var away := Vector2(_eye_vel.x,_eye_vel.z)-_air*POLLEN_DRIFT
	var n := 0
	for s: Dictionary in _specks:
		var p: Vector3 = s.pos
		var age := float(s.age)+delta
		s.age = age
		var flat := Vector2(p.x,p.z)
		if age > float(s.life) or flat.distance_to(centre) > POLLEN_REACH:
			_spawn_speck(s,centre,grass,false,away)
			p = s.pos
		var ph := float(s.phase)
		var wander := Vector3(sin(_time*0.7+ph),0.35*sin(_time*1.1+ph*1.7),cos(_time*0.6+ph*2.3))*POLLEN_WANDER
		var v := Vector3(_air.x*POLLEN_DRIFT,0.0,_air.y*POLLEN_DRIFT)*float(s.drift)+wander
		p += v*delta
		# Held within its band over the ground it was born over.
		p.y = clampf(p.y,float(s.ground)+POLLEN_HIGH.x*0.5,float(s.ground)+POLLEN_HIGH.y*1.2)
		s.pos = p
		var u := age/float(s.life)
		var a := smoothstep(0.0,0.15,u)*(1.0-smoothstep(0.75,1.0,u))*POLLEN_OPACITY*_show
		var size := float(s.size)
		var o := n*20
		_pollen_buf[o] = size
		_pollen_buf[o+1] = 0.0
		_pollen_buf[o+2] = 0.0
		_pollen_buf[o+3] = p.x
		_pollen_buf[o+4] = 0.0
		_pollen_buf[o+5] = size
		_pollen_buf[o+6] = 0.0
		_pollen_buf[o+7] = p.y
		_pollen_buf[o+8] = 0.0
		_pollen_buf[o+9] = 0.0
		_pollen_buf[o+10] = size
		_pollen_buf[o+11] = p.z
		_pollen_buf[o+12] = POLLEN_COLOUR.r
		_pollen_buf[o+13] = POLLEN_COLOUR.g
		_pollen_buf[o+14] = POLLEN_COLOUR.b
		_pollen_buf[o+15] = a
		_pollen_buf[o+16] = v.x
		_pollen_buf[o+17] = v.y
		_pollen_buf[o+18] = v.z
		_pollen_buf[o+19] = 0.0
		n += 1
	_pollen_mm.buffer = _pollen_buf
	_pollen_mm.visible_instance_count = n
	stats.pollen = n

## A speck anew: anywhere in the disc at the start, else on the side it is
## coming from (`away`: the eye's travel over the specks'), part way into its
## life so the swarm never pulses.
func _spawn_speck(s: Dictionary, centre: Vector2, grass: Callable, anywhere: bool, away := Vector2.ZERO) -> void:
	var at := Vector2.ZERO
	for _try in 4:
		if anywhere or away.length() < 0.5:
			at = centre+Vector2.from_angle(_rng.randf()*TAU)*sqrt(_rng.randf())*POLLEN_REACH
		else:
			var ahead := away.normalized()
			var side := Vector2(-ahead.y,ahead.x)
			at = centre+ahead*POLLEN_REACH*_rng.randf_range(0.35,0.95)+side*_rng.randf_range(-0.8,0.8)*POLLEN_REACH*0.75
		var h := float(grass.call(at.x,at.y))
		if not is_nan(h):
			s.ground = h
			break
		s.ground = NAN
	if is_nan(float(s.get("ground",NAN))):
		# No grass there: born spent, tried again next frame.
		s.ground = float(_ground.call(at.x,at.y))
		s.life = 0.01
		s.age = 1.0
		s.pos = Vector3(at.x,float(s.ground)-50.0,at.y)
	else:
		s.life = _rng.randf_range(POLLEN_LIFE.x,POLLEN_LIFE.y)
		s.age = s.life*_rng.randf_range(0.0,0.5) if anywhere else 0.0
		s.pos = Vector3(at.x,float(s.ground)+lerpf(POLLEN_HIGH.x,POLLEN_HIGH.y,pow(_rng.randf(),1.6)),at.y)
	s.size = _rng.randf_range(POLLEN_SIZE.x,POLLEN_SIZE.y)
	s.phase = _rng.randf()*TAU
	s.drift = _rng.randf_range(0.7,1.2)

# --- The kick -------------------------------------------------------------------------

func _kick(delta: float, wash: Dictionary, ribbons: Array) -> void:
	if not wash.is_empty():
		var k := float(wash.k)
		_kick_owed += KICK_RATE*kick_scale*k*delta
		var at: Vector2 = wash.at
		var reach := float(wash.reach)
		var back: Vector2 = wash.back
		while _kick_owed >= 1.0:
			_kick_owed -= 1.0
			var r := sqrt(_rng.randf())*reach*0.7
			var out := Vector2.from_angle(_rng.randf()*TAU)
			var p := at+out*r
			var fling := out*_rng.randf_range(KICK_OUT.x,KICK_OUT.y)*k+back*KICK_BACK*k*_rng.randf_range(0.4,1.2)
			var carry := _eye_vel*KICK_CARRY*_rng.randf_range(0.6,1.2)
			_throw(p,Vector3(fling.x+carry.x,_rng.randf_range(KICK_UP.x,KICK_UP.y)*sqrt(k),fling.y+carry.z))
	else:
		_kick_owed = 0.0
	var alive := {}
	for rb: Dictionary in ribbons:
		var id := int(rb.id)
		alive[id] = true
		var pos: Vector3 = rb.pos
		var above := pos.y-float(rb.ground)
		var w := clampf(float(rb.fade),0.0,1.0)*float(rb.weight)*(1.0-smoothstep(EDDY_SKIM*0.5,EDDY_SKIM,above))
		if w <= 0.05: continue
		var owed := float(_eddy_owed.get(id,0.0))+EDDY_RATE*kick_scale*w*delta
		var rv: Vector3 = rb.vel
		while owed >= 1.0:
			owed -= 1.0
			var p := Vector2(pos.x,pos.z)+Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(0.0,1.5)
			_throw(p,Vector3(rv.x*0.7,_rng.randf_range(1.5,3.5),rv.z*0.7)+Vector3(_rng.randf_range(-1,1),0,_rng.randf_range(-1,1)))
		_eddy_owed[id] = owed
	for id: int in _eddy_owed.keys():
		if not alive.has(id): _eddy_owed.erase(id)
	var n := 0
	var i := 0
	while i < _bits.size():
		var b: Dictionary = _bits[i]
		var age := float(b.age)+delta
		if age > float(b.life):
			_bits.remove_at(i)
			continue
		b.age = age
		var v: Vector3 = b.vel
		var air := Vector3(_air.x,0.0,_air.y)
		v += (air-v)*clampf(KICK_DRAG*delta,0.0,1.0)
		v.y -= KICK_FALL*delta
		var p: Vector3 = b.pos+v*delta
		var floor_y := float(b.ground)+KICK_SINK
		var spin := float(b.spin)
		if p.y < floor_y:
			# Back down in the grass: it settles there and goes.
			p.y = floor_y
			v = Vector3.ZERO
			spin = 0.0
			b.life = minf(float(b.life),age+0.3)
		b.vel = v
		b.pos = p
		var turn: Basis = Basis(b.axis as Vector3,spin*delta)*(b.basis as Basis)
		b.basis = turn
		b.spin = spin
		var u := age/float(b.life)
		var size := float(b.size)*(1.0-smoothstep(0.8,1.0,u))*smoothstep(0.0,0.06,age)
		var bs := turn*Basis.from_scale(Vector3(KICK_WIDE,1.0,1.0)*size)
		var c: Color = b.colour
		var o := n*16
		_kick_buf[o] = bs.x.x
		_kick_buf[o+1] = bs.y.x
		_kick_buf[o+2] = bs.z.x
		_kick_buf[o+3] = p.x
		_kick_buf[o+4] = bs.x.y
		_kick_buf[o+5] = bs.y.y
		_kick_buf[o+6] = bs.z.y
		_kick_buf[o+7] = p.y
		_kick_buf[o+8] = bs.x.z
		_kick_buf[o+9] = bs.y.z
		_kick_buf[o+10] = bs.z.z
		_kick_buf[o+11] = p.z
		_kick_buf[o+12] = c.r
		_kick_buf[o+13] = c.g
		_kick_buf[o+14] = c.b
		_kick_buf[o+15] = 1.0
		n += 1
		i += 1
	_kick_mm.buffer = _kick_buf
	_kick_mm.visible_instance_count = n
	stats.kick = n

## A bit of blade thrown from `at` (xz, on the ground there) at `vel`.
func _throw(at: Vector2, vel: Vector3) -> void:
	if _bits.size() >= KICK: _bits.pop_front()
	var g := float(_ground.call(at.x,at.y))
	var axis := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1))
	if axis.length() < 0.1: axis = Vector3.RIGHT
	_bits.append({"pos": Vector3(at.x,g+_rng.randf_range(KICK_FROM.x,KICK_FROM.y),at.y), "vel": vel, "ground": g,
		"age": 0.0, "life": _rng.randf_range(KICK_LIFE.x,KICK_LIFE.y), "size": _rng.randf_range(KICK_SIZE.x,KICK_SIZE.y),
		"basis": Basis.from_euler(Vector3(_rng.randf()*TAU,_rng.randf()*TAU,_rng.randf()*TAU)),
		"axis": axis.normalized(), "spin": _rng.randf_range(6.0,16.0)*(1.0 if _rng.randf() < 0.5 else -1.0),
		"colour": Color(KICK_COLOURS[_rng.randi()%KICK_COLOURS.size()]).srgb_to_linear()})
