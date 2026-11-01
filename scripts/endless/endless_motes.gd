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
##   kick    clipped grass blades (shaders/grass_bit.gdshader: long thin
##           slivers in the grass's own greens, lit by the scene) thrown up
##           where the prop's wash comes down (GrassReact `wash_spot`), up
##           to KICK_RATE a second at full wash, flung out from its middle
##           and back along the plane's way. Each turns lazily end over end
##           or about its length, slowed by the air, then rocks toward lying
##           flat as it falls, fluttering and sliding side to side; and a
##           few off any eddy (EndlessEddies' ribbons) skimming within
##           EDDY_SKIM m of the grass.
##
## Flags: --no-motes (none), --no-pollen, --no-grass-kick, --pollen=X (the
## specks' count, a share of POLLEN), --grass-kick=X (the kick's rate).
##
## Native: the specks' drift and the bits' flight each frame run in C++
## (ZenScapeMotes, native/terrain_kernels/flight_fx.h) when the library is
## built, the same numbers as the loops here; the spawning stays here (its
## random draws and land probes) and hands each new speck or bit over.
## --native-react=0 (or --gdscript-kernels) runs the loops here.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Patch = preload("res://scripts/endless/endless_patch.gd")
const Field = preload("res://scripts/endless/land_field.gd")
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

## Specks born a frame at most (each asks the land up to five times); one
## whose turn doesn't come stays spent. Boost through the disc needs about 5
## a frame at 120 fps; beside water every speck would otherwise retry each frame.
const POLLEN_SPAWNS := 12

const KICK := 240
const KICK_RATE := 150.0
## A clipped blade's length and width (m: the endless grass stands about
## four times the isles', its blades a few centimetres wide), its fling out
## and up (m/s, at full wash), the share blown back along the plane's way,
## its drag (1/s), its fall (m/s^2) and its life (s).
const KICK_LEN := Vector2(0.5,1.1)
const KICK_WIDTH := Vector2(0.12,0.2)
const KICK_OUT := Vector2(2.5,6.5)
const KICK_UP := Vector2(4.5,9.0)
const KICK_BACK := 3.0
## The share of the eye's travel the bits are carried on with at first (the
## plane's wake drags them along), so they stream back past the chase view
## rather than being left at once behind it.
const KICK_CARRY := 0.8
const KICK_DRAG := 0.9
const KICK_FALL := 4.8
const KICK_LIFE := Vector2(2.6,4.4)
## How a blade falls: lying flat it catches the air (KICK_FLAT_DRAG more drag
## on its fall, 1/s, times how flat it lies), so it falls slowly flat and
## faster edge on, and slides toward its low side (KICK_GLIDE of its fall).
const KICK_FLAT_DRAG := 2.8
const KICK_GLIDE := 0.7
## How it turns: thrown with KICK_SPIN rad/s end over end or about its
## length, slowed by the air (KICK_SPIN_DRAG, 1/s), then, from KICK_SETTLE s
## on, the air rocks it toward lying flat (KICK_LEVEL, a spring: it swings
## about flat, a slow flutter, rather than spinning), stirred by KICK_STIR.
const KICK_SPIN := Vector2(2.5,6.0)
const KICK_SPIN_DRAG := 1.3
const KICK_SETTLE := Vector2(0.25,1.1)
const KICK_LEVEL := 16.0
const KICK_STIR := 3.5
## Where a bit starts (m over the ground: the tall grass's upper blades) and
## the height under which it is back in the grass and goes.
const KICK_FROM := Vector2(0.9,1.6)
const KICK_SINK := 0.6
## A skimming eddy's bits a second, and how low it skims (m over the ground).
const EDDY_RATE := 10.0
const EDDY_SKIM := 1.2
## The bits' colours: the grass's own root and tip (linear; the near tufts'
## defaults, endless_grass.gd `_fine`) under the ground's grass tint where
## they were thrown (EndlessPatch.tint), a bit from the upper blade
## (KICK_TIP of the way to the tip), and KICK_DRY of them gone a little dry.
const KICK_ROOT := Color(0.0395,0.133,0.0423)
const KICK_TIP := Vector2(0.65,1.25)
const KICK_GREEN := Color(0.366,0.604,0.122)
const KICK_STRAW := Color(0.50,0.46,0.20)
const KICK_DRY := 0.25
## Most bits show a pale face against the standing grass, so they read from
## the chase view (KICK_PALE of them): sunlit tips, the silvery underside and
## dry straw (linear; the old chips' tones), touched by the ground's tint.
const KICK_PALE := 0.75
const KICK_PALES := [Color(0.58,0.72,0.25),Color(0.72,0.79,0.53),Color(0.75,0.72,0.37),Color(0.64,0.58,0.27)]

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
## The C++ loops (ZenScapeMotes), or null for the GDScript ones.
var native: Object = null

const NATIVE_CLASS := &"ZenScapeMotes"
const NATIVE_VERSION := 1
static func native_wanted() -> bool:
	var args := LaunchArgs.user_args()
	if "--native-react=0" in args or "--gdscript-kernels" in args: return false
	Field.native_available()
	if not ClassDB.class_exists(NATIVE_CLASS): return false
	var probe: Object = ClassDB.instantiate(NATIVE_CLASS)
	return probe.has_method("version") and int(probe.version()) == NATIVE_VERSION

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
	_pollen_mm = _batch("Pollen",quad,pollen_count,true)
	_pollen_buf.resize(pollen_count*20)
	var m := ShaderMaterial.new()
	m.shader = BIT
	_kick_mm = _batch("GrassKick",_blade_strip(),KICK,true,m)
	_kick_buf.resize(KICK*20)
	if native_wanted():
		native = ClassDB.instantiate(NATIVE_CLASS)
		native.configure({"pollen_count": pollen_count, "pollen_reach": POLLEN_REACH, "pollen_wander": POLLEN_WANDER,
			"pollen_drift": POLLEN_DRIFT, "pollen_opacity": POLLEN_OPACITY, "pollen_high": POLLEN_HIGH, "pollen_colour": POLLEN_COLOUR,
			"kick": KICK, "kick_drag": KICK_DRAG, "kick_fall": KICK_FALL, "kick_flat_drag": KICK_FLAT_DRAG, "kick_glide": KICK_GLIDE,
			"kick_spin_drag": KICK_SPIN_DRAG, "kick_level": KICK_LEVEL, "kick_stir": KICK_STIR})

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
	_air = wind.normalized()*speed
	if pollen_on: _pollen(delta,eye,grass)
	if kick_on: _kick(delta,wash,ribbons)

# --- Pollen ---------------------------------------------------------------------------

func _pollen(delta: float, eye: Vector3, grass: Callable) -> void:
	var under := float(grass.call(eye.x,eye.z))
	var low := not is_nan(under) and eye.y-under < POLLEN_UP
	_show = move_toward(_show,1.0 if low else 0.0,delta*0.8)
	if _show <= 0.0:
		if not _specks.is_empty(): _specks.clear()
		if native != null: native.pollen_clear()
		_pollen_mm.visible_instance_count = 0
		stats.pollen = 0
		return
	var lead := Vector2(_eye_vel.x,_eye_vel.z)*POLLEN_LEAD
	if lead.length() > POLLEN_REACH*0.8: lead = lead.normalized()*POLLEN_REACH*0.8
	var centre := Vector2(eye.x,eye.z)+lead
	if native != null:
		_pollen_native(delta,centre,grass)
		return
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

## `_pollen`'s loop in C++ (ZenScapeMotes): the same specks, spawned here.
func _pollen_native(delta: float, centre: Vector2, grass: Callable) -> void:
	var left := POLLEN_SPAWNS
	while native.pollen_count() < pollen_count and left > 0:
		left -= 1
		var s := {}
		_spawn_speck(s,centre,grass,true)
		native.pollen_put(native.pollen_count(),_speck_record(s))
	var away := Vector2(_eye_vel.x,_eye_vel.z)-_air*POLLEN_DRIFT
	for i: int in native.pollen_age(delta,centre):
		if left <= 0: break
		left -= 1
		var s := {}
		_spawn_speck(s,centre,grass,false,away)
		native.pollen_put(i,_speck_record(s))
	_pollen_buf = native.pollen_move(delta,_time,_air,_show)
	_pollen_mm.buffer = _pollen_buf
	var n: int = native.pollen_count()
	_pollen_mm.visible_instance_count = n
	stats.pollen = n

static func _speck_record(s: Dictionary) -> PackedFloat64Array:
	var p: Vector3 = s.pos
	return PackedFloat64Array([p.x,p.y,p.z,float(s.age),float(s.life),float(s.ground),float(s.size),float(s.phase),float(s.drift)])

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

## The blade's strip: KICK_ROWS rows along it (UV.y 0 at the cut end, 1 at
## the tip), three across (UV.x 0, 0.5, 1: the edges and the midrib). Its
## shape is the shader's (shaders/grass_bit.gdshader), from the instance's
## width and length; the vertices here are a 1 m stand-in.
const KICK_ROWS := 6
static func _blade_strip() -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in KICK_ROWS+1:
		var v := float(r)/KICK_ROWS
		for c in 3:
			var u := c*0.5
			surface.set_uv(Vector2(u,v))
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3((u-0.5)*0.05,0.0,v-0.5))
	for r in KICK_ROWS:
		for c in 2:
			var a := r*3+c
			var b := a+3
			for i: int in [a,b,a+1,a+1,b,b+1]: surface.add_index(i)
	return surface.commit()

func _kick(delta: float, wash: Dictionary, ribbons: Array) -> void:
	if not wash.is_empty():
		var k := float(wash.k)
		_kick_owed += KICK_RATE*kick_scale*k*delta
		var at: Vector2 = wash.at
		var reach := float(wash.reach)
		var back: Vector2 = wash.back
		var tint := _grass_tint(at) if _kick_owed >= 1.0 else Color.WHITE
		while _kick_owed >= 1.0:
			_kick_owed -= 1.0
			var r := sqrt(_rng.randf())*reach*0.7
			var out := Vector2.from_angle(_rng.randf()*TAU)
			var p := at+out*r
			var fling := out*_rng.randf_range(KICK_OUT.x,KICK_OUT.y)*k+back*KICK_BACK*k*_rng.randf_range(0.4,1.2)
			var carry := _eye_vel*KICK_CARRY*_rng.randf_range(0.6,1.2)
			_throw(p,Vector3(fling.x+carry.x,_rng.randf_range(KICK_UP.x,KICK_UP.y)*sqrt(k),fling.y+carry.z),tint)
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
		var tint := _grass_tint(Vector2(pos.x,pos.z)) if owed >= 1.0 else Color.WHITE
		while owed >= 1.0:
			owed -= 1.0
			var p := Vector2(pos.x,pos.z)+Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(0.0,1.5)
			_throw(p,Vector3(rv.x*0.7,_rng.randf_range(1.5,3.5),rv.z*0.7)+Vector3(_rng.randf_range(-1,1),0,_rng.randf_range(-1,1)),tint)
		_eddy_owed[id] = owed
	for id: int in _eddy_owed.keys():
		if not alive.has(id): _eddy_owed.erase(id)
	if native != null:
		_kick_buf = native.kick_step(delta,_time,_air)
		_kick_mm.buffer = _kick_buf
		var k: int = native.kick_count()
		_kick_mm.visible_instance_count = k
		stats.kick = k
		return
	var n := 0
	var i := 0
	var air := Vector3(_air.x,0.0,_air.y)
	while i < _bits.size():
		var b: Dictionary = _bits[i]
		var age := float(b.age)+delta
		if age > float(b.life):
			_bits.remove_at(i)
			continue
		b.age = age
		var turn: Basis = b.basis
		var face := turn.y
		var flat := absf(face.y)
		var v: Vector3 = b.vel
		var w: Vector3 = b.spin
		var landed := bool(b.landed)
		if not landed:
			v += (air-v)*clampf(KICK_DRAG*delta,0.0,1.0)
			v.y -= KICK_FALL*delta
			if v.y < 0.0:
				# Falling: flat it catches the air, and slides toward its low side.
				v.y *= maxf(1.0-KICK_FLAT_DRAG*flat*delta,0.0)
				var low := Vector3(face.x,0.0,face.z)*signf(face.y)
				v += low*KICK_GLIDE*(-v.y)*delta*4.0
			w *= maxf(1.0-KICK_SPIN_DRAG*delta,0.0)
			# The air rocks it toward lying flat (either face up), stirred.
			var settle := smoothstep(float(b.settle),float(b.settle)+0.6,age)
			var up := Vector3.UP*(1.0 if face.y >= 0.0 else -1.0)
			w += face.cross(up)*KICK_LEVEL*settle*delta
			var ph := float(b.phase)*TAU
			w += Vector3(sin(_time*2.3+ph),0.4*sin(_time*1.7+ph*1.9),cos(_time*2.9+ph*2.7))*KICK_STIR*settle*delta
		var p: Vector3 = b.pos+v*delta
		var floor_y := float(b.ground)+float(b.rest)
		if not landed and p.y < floor_y:
			# Back down on the grass: it lies there a moment and goes.
			p.y = floor_y
			v = Vector3.ZERO
			w = Vector3.ZERO
			landed = true
			b.landed = true
			b.life = minf(float(b.life),age+0.6)
		b.vel = v
		b.pos = p
		var rate := w.length()
		if rate > 1.0e-4:
			turn = (Basis(w/rate,rate*delta)*turn).orthonormalized()
		b.basis = turn
		b.spin = w
		var u := age/float(b.life)
		var size := (1.0-smoothstep(0.82,1.0,u))*smoothstep(0.0,0.06,age)
		# It flutters while the air pulls at it (its speed through the air),
		# and a little while it rocks.
		var through := (v-air).length()
		var flutter := 0.0 if landed else clampf(through/6.0,0.0,1.0)*0.85+clampf(rate/4.0,0.0,1.0)*0.15
		var c: Color = b.colour
		var o := n*20
		_kick_buf[o] = turn.x.x
		_kick_buf[o+1] = turn.y.x
		_kick_buf[o+2] = turn.z.x
		_kick_buf[o+3] = p.x
		_kick_buf[o+4] = turn.x.y
		_kick_buf[o+5] = turn.y.y
		_kick_buf[o+6] = turn.z.y
		_kick_buf[o+7] = p.y
		_kick_buf[o+8] = turn.x.z
		_kick_buf[o+9] = turn.y.z
		_kick_buf[o+10] = turn.z.z
		_kick_buf[o+11] = p.z
		_kick_buf[o+12] = c.r
		_kick_buf[o+13] = c.g
		_kick_buf[o+14] = c.b
		_kick_buf[o+15] = 1.0
		_kick_buf[o+16] = float(b.width)*size
		_kick_buf[o+17] = float(b.length)*size
		_kick_buf[o+18] = float(b.phase)
		_kick_buf[o+19] = flutter
		n += 1
		i += 1
	_kick_mm.buffer = _kick_buf
	_kick_mm.visible_instance_count = n
	stats.kick = n

## The ground's grass tint at `at` (EndlessPatch.tint: its patches and
## region over the plain grass), as the near tufts take it.
func _grass_tint(at: Vector2) -> Color:
	var g := float(_ground.call(at.x,at.y))
	if is_nan(g): return Color.WHITE
	var t := Patch.tint(at.x,at.y,0.5,g-Field.SEA_Y,1.0)
	return Color(clampf(t.r,0.5,1.8),clampf(t.g,0.5,1.8),clampf(t.b,0.5,1.8))

## A clipped blade thrown from `at` (xz, on the ground there) at `vel`, in
## the grass's colour there (`tint`).
func _throw(at: Vector2, vel: Vector3, tint: Color) -> void:
	if native == null and _bits.size() >= KICK: _bits.pop_front()
	var g := float(_ground.call(at.x,at.y))
	# It stood in the grass: its length near upright, leaning the way it is
	# flung, turned any way about it.
	var way := Vector3(vel.x,0.0,vel.z)
	way = way.normalized() if way.length() > 0.1 else Vector3.FORWARD
	var lean := _rng.randf_range(0.15,0.9)
	var along := (Vector3.UP*cos(lean)+way*sin(lean)).normalized()
	var across := along.cross(way)
	if across.length() < 0.01: across = Vector3.RIGHT
	across = across.normalized().rotated(along,_rng.randf()*TAU)
	var turn := Basis(across,along.cross(across),along).orthonormalized()
	# Its spin: end over end about the level line across its way, or rolling
	# about its own length, either a little off.
	var spin := _rng.randf_range(KICK_SPIN.x,KICK_SPIN.y)*(1.0 if _rng.randf() < 0.5 else -1.0)
	var axis := way.cross(Vector3.UP).normalized()
	if _rng.randf() < 0.35: axis = along
	axis = (axis+Vector3(_rng.randf_range(-0.3,0.3),_rng.randf_range(-0.3,0.3),_rng.randf_range(-0.3,0.3))).normalized()
	var colour := KICK_ROOT.lerp(KICK_GREEN,_rng.randf_range(KICK_TIP.x,KICK_TIP.y))
	if _rng.randf() < KICK_DRY: colour = colour.lerp(KICK_STRAW,_rng.randf_range(0.25,0.5))
	colour = Color(colour.r*tint.r,colour.g*tint.g,colour.b*tint.b)*_rng.randf_range(0.85,1.12)
	if _rng.randf() < KICK_PALE:
		var pale: Color = KICK_PALES[_rng.randi() % KICK_PALES.size()]
		# Mostly the ground's own tint (dry ground: straw, not cream), a little paler than the green tips.
		colour = pale.lerp(Color(pale.r*tint.r,pale.g*tint.g,pale.b*tint.b),0.65)*_rng.randf_range(0.8,0.95)
	var bit := {"pos": Vector3(at.x,g+_rng.randf_range(KICK_FROM.x,KICK_FROM.y),at.y), "vel": vel, "ground": g,
		"age": 0.0, "life": _rng.randf_range(KICK_LIFE.x,KICK_LIFE.y),
		"length": _rng.randf_range(KICK_LEN.x,KICK_LEN.y)*0.65, "width": _rng.randf_range(KICK_WIDTH.x,KICK_WIDTH.y)*0.8,
		"basis": turn, "spin": axis*spin, "phase": _rng.randf(), "landed": false,
		"settle": _rng.randf_range(KICK_SETTLE.x,KICK_SETTLE.y), "rest": _rng.randf_range(KICK_SINK,KICK_FROM.y),
		"colour": colour}
	if native != null: native.kick_add(_bit_record(bit))
	else: _bits.append(bit)

## A bit as ZenScapeMotes takes it (flight_fx.h BIT_REC): pos, vel, ground,
## age, life, length, width, the basis's rows, spin, phase, settle, rest,
## colour (thrown, so not landed).
static func _bit_record(b: Dictionary) -> PackedFloat64Array:
	var p: Vector3 = b.pos
	var v: Vector3 = b.vel
	var t: Basis = b.basis
	var w: Vector3 = b.spin
	var c: Color = b.colour
	return PackedFloat64Array([p.x,p.y,p.z,v.x,v.y,v.z,float(b.ground),float(b.age),float(b.life),float(b.length),float(b.width),
		t.x.x,t.y.x,t.z.x,t.x.y,t.y.y,t.z.y,t.x.z,t.y.z,t.z.z,w.x,w.y,w.z,float(b.phase),float(b.settle),float(b.rest),
		c.r,c.g,c.b,c.a])
