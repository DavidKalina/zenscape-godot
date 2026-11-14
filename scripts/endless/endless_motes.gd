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
##           EDDY_SKIM m of the grass. Over a flower drift (EndlessPatch
##           `bloom`) PETAL_WASH of the wash's bits are its petals instead.
##   drift   loose blades (the kick's bit) and petals lifted off the meadow by
##           the wind itself, in puffs: a puff picks a spot among slow gust
##           patches rolling downwind (`_gusty`; the stronger, the likelier),
##           led ahead along the eye's travel and a little upwind of it, and
##           lets go DRIFT_PUFF bits over a second or so. Each rides
##           DRIFT_RIDE m over the grass on the air (carried at DRIFT_CARRY of
##           its speed), tumbling, for a few seconds, then lets go and falls
##           fluttering as a kicked bit does. Over a drift a puff's bits are
##           mostly the drift's petals, in its own colour (EndlessPatch.KINDS'
##           wash). Puffs come more often the stronger the air (by the look's
##           drift: its speed against DRIFT_AIR), the faster the eye flies,
##           and none from DRIFT_HIGH.y m over the ground.
##
## Flags: --no-motes (none), --no-pollen, --no-grass-kick, --pollen=X (the
## specks' count, a share of POLLEN), --grass-kick=X (the kick's rate),
## --no-wind-blades / --wind-blades=X (the drift's blades, their rate),
## --no-petals / --petals=X (petals: the drift's and the wash's, their share),
## --wind-fluff=X (the drift's seed fluff, its share of DRIFT_FLUFF; 0 none).
##
## Native: the specks' drift and the bits' flight each frame run in C++
## (ZenScapeMotes, native/terrain_kernels/flight_fx.h) when the library is
## built, the same numbers as the loops here; the spawning stays here (its
## random draws and land probes) and hands each new speck or bit over.
## --native-react=0 (or --gdscript-kernels) runs the loops here.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Patch = preload("res://scripts/endless/endless_patch.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const Gusts = preload("res://scripts/shared/gust_fronts.gd")
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
## A bird's chaff (`puff`): its fling out and up (m/s) and its size over a blade's.
const PUFF_OUT := Vector2(0.6,2.4)
const PUFF_UP := Vector2(2.5,6.0)
const PUFF_SIZE := 0.5
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

## --- The drift (the wind's own blades and petals) ---
## Its bits at most (one MultiMesh, the kick's blade and shader).
const DRIFT := 360
## Puffs a second at DRIFT_AIR m/s of air (the look's drift; --wind=1 runs
## about 6) over grass, standing still; their rise with the air's speed
## (k^DRIFT_POW, k = air/DRIFT_AIR up to 2), and the eye's travel adding one
## more share every DRIFT_PACE m/s (so a fast plane meets as many).
const DRIFT_PUFFS := 2.4
const DRIFT_AIR := 6.0
const DRIFT_POW := 1.3
const DRIFT_PACE := 5.0
## Puffs alive at once, the bits one lets go (a range, scaled by its gust),
## over how long (s), and how wide its patch (m: across, and along the wind).
const DRIFT_PUFF_MAX := 24
const DRIFT_PUFF := Vector2i(10,22)
const DRIFT_PUFF_TIME := Vector2(0.5,1.4)
const DRIFT_PUFF_SIZE := Vector2(2.2,4.0)
## A puff's patch stretched along the wind (a share of its size): a stream.
const DRIFT_STREAM := 2.6
## Where a puff is: within DRIFT_REACH m of a point led DRIFT_LEAD s ahead
## along the eye's travel (at most DRIFT_LEAD_MAX m), and DRIFT_UPWIND s of
## the air's travel upwind, so its stream drifts into view. DRIFT_TRIES spots
## tried, the gustiest kept; the gusts' patches (`_gusty`) and how much a
## flower drift adds to a spot's draw.
const DRIFT_REACH := 24.0
const DRIFT_LEAD := 1.6
## The corridor's near end (m ahead of the eye).
const DRIFT_NEAR := 6.0
## Flying fast, the near end is the eye's travel over this many s (so a bit
## born there is on screen a while before it passes), and the corridor's
## half-width (m: the chase view at 20 m sees about 28 m to each side).
const DRIFT_NEAR_LEAD := 0.35
const DRIFT_SIDE := 19.0
const DRIFT_LEAD_MAX := 70.0
const DRIFT_UPWIND := 0.8
const DRIFT_TRIES := 3
const DRIFT_BLOOM_DRAW := 1.0
## How high the eye may be over the ground (m) before puffs thin, and none.
const DRIFT_HIGH := Vector2(20.0,60.0)
## Bits born a frame at most, across the puffs.
const DRIFT_SPAWNS := 24
## A riding blade: its size (m, the kick's are 0.33..0.72 long), how high it
## rides over the ground (m), how long it rides (s) before it lets go, the
## share of the air's speed it is carried at, its rise off the grass (m/s), and
## the ride's spring (1/s^2) and damping (1/s), a bob as a share of the height,
## the tumble the air keeps up while riding and its flutter.
const DRIFT_LEN := Vector2(0.4,0.8)
const DRIFT_WIDTH := Vector2(0.15,0.22)
const DRIFT_RIDE := Vector2(1.8,3.8)
## Over that, a share of the eye's own height over the ground (flying low,
## about the plane's height and up to the eye's: against the sky), at most
## DRIFT_RIDE_MAX m.
const DRIFT_OVER := Vector2(0.6,1.7)
const DRIFT_RIDE_MAX := 12.0
## The eye's speed (m/s) from which a bit is met already up (fully from the
## second), and how long it rides on after the eye has passed it (s).
const DRIFT_FAST := Vector2(8.0,25.0)
const DRIFT_AFTER := Vector2(0.25,0.8)
## The share of its fall cut short then (it falls behind the eye, unseen).
const DRIFT_UNSEEN := 0.75
const DRIFT_RIDE_TIME := Vector2(1.4,3.8)
const DRIFT_CARRY := Vector2(0.75,1.25)
const DRIFT_RISE := Vector2(2.5,4.5)
const DRIFT_LIFT := 3.0
const DRIFT_DAMP := 1.8
const DRIFT_BOB := 0.3
const DRIFT_TUMBLE := 1.2
const DRIFT_FLUTTER := 0.45
## The eye's speed (m/s) at which a bit's ride and life are halved.
const DRIFT_PASSED := 30.0
## The share of the riding blades that show a pale face (straw, sunlit, the
## silvery underside), so they read over the standing grass.
const DRIFT_PALE := 0.92
## Their faces (linear): straw, cream, a dry brown leaf and tan (darker than
## the sunlit grass, so they read on it), a pale sunlit tip; touched by the
## ground's tint (DRIFT_TINT of it) so dry land drifts straw.
const DRIFT_PALES := [Color(0.82,0.74,0.40),Color(0.92,0.89,0.70),Color(0.42,0.30,0.14),Color(0.66,0.50,0.26),Color(0.90,0.90,0.62)]
const DRIFT_TINT := 0.3
## The share of a puff's blades that are seed fluff instead: small, round,
## near white, light (they ride long and fall slowly), its size (m).
const DRIFT_FLUFF := 0.3
const FLUFF_SIZE := Vector2(0.14,0.22)
const FLUFF_COLOUR := Color(0.95,0.94,0.86)
## Petals: their size (m), the share of the kick's fall they fall at (light,
## flat: they flutter down), the share of a puff over a drift that are petals
## (times its weight there), and the wash's share over a drift.
const PETAL_LEN := Vector2(0.15,0.22)
const PETAL_WIDTH := Vector2(0.13,0.19)
const PETAL_FALL := 0.3
const PETAL_SHARE := 0.95
const PETAL_WASH := 0.55
## A petal's colour alpha: the shader's sign to round and cup the strip.
const PETAL_MARK := 0.5

var pollen_on := true
var kick_on := true
var pollen_count := POLLEN
var kick_scale := 1.0
var drift_on := true
var drift_scale := 1.0
var petals_on := true
var petal_scale := 1.0
var fluff_share := DRIFT_FLUFF
## For the numbers: specks shown, bits flying, the drift's bits and puffs.
var stats := {"pollen": 0, "kick": 0, "drift": 0, "puffs": 0, "far": 0}
var far_on := true
var far_scale := 1.0

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
var _drifts: Array[Dictionary] = []
var _drift_mm: MultiMesh
var _drift_buf := PackedFloat32Array()
var _puffs: Array[Dictionary] = []
var _puff_owed := 0.0
var _air_travel := 0.0
## The C++ loops (ZenScapeMotes), or null for the GDScript ones.
var native: Object = null

const NATIVE_CLASS := &"ZenScapeMotes"
const NATIVE_VERSION := 2
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
		elif a == "--no-wind-blades": drift_on = false
		elif a == "--no-far-drift": far_on = false
		elif a.begins_with("--far-drift="): far_scale = maxf(float(a.get_slice("=",1)),0.0)
		elif a.begins_with("--wind-blades="): drift_scale = maxf(float(a.get_slice("=",1)),0.0)
		elif a == "--no-petals": petals_on = false
		elif a.begins_with("--petals="): petal_scale = maxf(float(a.get_slice("=",1)),0.0)
		elif a.begins_with("--wind-fluff="): fluff_share = clampf(DRIFT_FLUFF*float(a.get_slice("=",1)),0.0,1.0)
	if pollen_count == 0: pollen_on = false
	if kick_scale <= 0.0: kick_on = false
	if drift_scale <= 0.0: drift_on = false
	if petal_scale <= 0.0: petals_on = false
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
	_drift_mm = _batch("WindDrift",_kick_mm.mesh,DRIFT,true,m)
	_drift_buf.resize(DRIFT*20)
	if far_scale <= 0.0: far_on = false
	if far_on: _far_setup()
	if native_wanted():
		native = ClassDB.instantiate(NATIVE_CLASS)
		native.configure({"pollen_count": pollen_count, "pollen_reach": POLLEN_REACH, "pollen_wander": POLLEN_WANDER,
			"pollen_drift": POLLEN_DRIFT, "pollen_opacity": POLLEN_OPACITY, "pollen_high": POLLEN_HIGH, "pollen_colour": POLLEN_COLOUR,
			"kick": KICK, "kick_drag": KICK_DRAG, "kick_fall": KICK_FALL, "kick_flat_drag": KICK_FLAT_DRAG, "kick_glide": KICK_GLIDE,
			"kick_spin_drag": KICK_SPIN_DRAG, "kick_level": KICK_LEVEL, "kick_stir": KICK_STIR,
			"drift": DRIFT, "drift_lift": DRIFT_LIFT, "drift_damp": DRIFT_DAMP, "drift_bob": DRIFT_BOB,
			"drift_tumble": DRIFT_TUMBLE, "drift_flutter": DRIFT_FLUTTER})

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
## the air's (EndlessLook wind_direction, drift: by the wind at the eye, so the
## specks hang in a still hollow and stream on a windy ridge); `wash` GrassReact
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
	_air_travel = travel
	var under := NAN
	if pollen_on or drift_on or petals_on: under = float(grass.call(eye.x,eye.z))
	if pollen_on: _pollen(delta,eye,under,grass)
	FrameLog.mark(&"m_pollen")
	if kick_on: _kick(delta,wash,ribbons)
	FrameLog.mark(&"m_kick")
	if drift_on or petals_on: _drift(delta,eye,under,grass)
	FrameLog.mark(&"m_drift")
	if far_on and (drift_on or petals_on): _far(delta,eye,grass)
	FrameLog.mark(&"m_far")

# --- Pollen ---------------------------------------------------------------------------

func _pollen(delta: float, eye: Vector3, under: float, grass: Callable) -> void:
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
		# Over a flower drift some of what the wash throws is its petals.
		var bloom := Patch.bloom(at.x,at.y) if _kick_owed >= 1.0 and petals_on else Vector2.ZERO
		var petals := clampf(_petal_weight(bloom.x)*PETAL_WASH*petal_scale,0.0,0.9)
		while _kick_owed >= 1.0:
			_kick_owed -= 1.0
			var r := sqrt(_rng.randf())*reach*0.7
			var out := Vector2.from_angle(_rng.randf()*TAU)
			var p := at+out*r
			var fling := out*_rng.randf_range(KICK_OUT.x,KICK_OUT.y)*k+back*KICK_BACK*k*_rng.randf_range(0.4,1.2)
			var carry := _eye_vel*KICK_CARRY*_rng.randf_range(0.6,1.2)
			var vel := Vector3(fling.x+carry.x,_rng.randf_range(KICK_UP.x,KICK_UP.y)*sqrt(k),fling.y+carry.z)
			if petals > 0.0 and _rng.randf() < petals:
				var bit := _petal(p,float(_ground.call(p.x,p.y)),vel*0.7,int(bloom.y))
				if native != null: native.kick_add(_bit_record(bit))
				else:
					if _bits.size() >= KICK: _bits.pop_front()
					_bits.append(bit)
			else: _throw(p,vel,tint)
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
	_kick_buf = _fly(_bits,_kick_buf,delta)
	_kick_mm.buffer = _kick_buf
	_kick_mm.visible_instance_count = _flown
	stats.kick = _flown

## Bits drawn by the last `_fly`.
var _flown := 0

## Every bit in `bits` a frame on (the spent ones dropped), drawn into `buf`
## (returned; `_flown` of them). A kicked bit is thrown and falls; a drift's
## bit first rides (`ride` s) `lift` m over its ground (the ground it rose
## from, sloped along `sx`, `sz` from `ox`, `oz`), carried at `carry` of the
## air, tumbling; then falls as a kicked one does, at `fall` of its fall.
func _fly(bits: Array[Dictionary], buf: PackedFloat32Array, delta: float) -> PackedFloat32Array:
	var n := 0
	var i := 0
	var air := Vector3(_air.x,0.0,_air.y)
	while i < bits.size():
		var b: Dictionary = bits[i]
		var age := float(b.age)+delta
		if age > float(b.life):
			bits.remove_at(i)
			continue
		b.age = age
		var turn: Basis = b.basis
		var face := turn.y
		var flat := absf(face.y)
		var v: Vector3 = b.vel
		var w: Vector3 = b.spin
		var landed := bool(b.landed)
		var riding := age < float(b.ride)
		var was: Vector3 = b.pos
		var ground := float(b.ground)+float(b.sx)*(was.x-float(b.ox))+float(b.sz)*(was.z-float(b.oz))
		if not landed:
			v += (air*float(b.carry)-v)*clampf(KICK_DRAG*delta,0.0,1.0)
			if riding:
				# Held up by the air, springing toward its height and bobbing.
				var want := ground+float(b.lift)*(1.0+DRIFT_BOB*sin(_time*1.3+float(b.phase)*TAU))
				v.y = v.y+((want-was.y)*DRIFT_LIFT-v.y*DRIFT_DAMP)*delta
			else:
				v.y -= KICK_FALL*float(b.fall)*delta
				if v.y < 0.0:
					# Falling: flat it catches the air, and slides toward its low side.
					v.y *= maxf(1.0-KICK_FLAT_DRAG*flat*delta,0.0)
					var low := Vector3(face.x,0.0,face.z)*signf(face.y)
					v += low*KICK_GLIDE*(-v.y)*delta*4.0
			w *= maxf(1.0-KICK_SPIN_DRAG*delta,0.0)
			# The air rocks it toward lying flat (either face up), stirred;
			# riding, the air keeps it tumbling.
			var settle := smoothstep(float(b.settle),float(b.settle)+0.6,age)
			var up := Vector3.UP*(1.0 if face.y >= 0.0 else -1.0)
			w += face.cross(up)*KICK_LEVEL*settle*delta
			var ph := float(b.phase)*TAU
			var tumble := DRIFT_TUMBLE if riding else 0.0
			w += Vector3(sin(_time*2.3+ph),0.4*sin(_time*1.7+ph*1.9),cos(_time*2.9+ph*2.7))*KICK_STIR*(settle+tumble)*delta
		var p: Vector3 = b.pos+v*delta
		var floor_y := ground+float(b.rest)
		if not landed and not riding and p.y < floor_y:
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
		var flutter := 0.0 if landed else clampf(through/6.0,0.0,1.0)*0.85+clampf(rate/4.0,0.0,1.0)*0.15+(DRIFT_FLUTTER if riding else 0.0)
		var c: Color = b.colour
		var o := n*20
		buf[o] = turn.x.x
		buf[o+1] = turn.y.x
		buf[o+2] = turn.z.x
		buf[o+3] = p.x
		buf[o+4] = turn.x.y
		buf[o+5] = turn.y.y
		buf[o+6] = turn.z.y
		buf[o+7] = p.y
		buf[o+8] = turn.x.z
		buf[o+9] = turn.y.z
		buf[o+10] = turn.z.z
		buf[o+11] = p.z
		buf[o+12] = c.r
		buf[o+13] = c.g
		buf[o+14] = c.b
		buf[o+15] = c.a
		buf[o+16] = float(b.width)*size
		buf[o+17] = float(b.length)*size
		buf[o+18] = float(b.phase)
		buf[o+19] = flutter
		n += 1
		i += 1
	_flown = n
	return buf

## The ground's grass tint at `at` (EndlessPatch.tint: its patches and
## region over the plain grass), as the near tufts take it.
func _grass_tint(at: Vector2) -> Color:
	var g := float(_ground.call(at.x,at.y))
	if is_nan(g): return Color.WHITE
	var t := Patch.tint(at.x,at.y,0.5,g-Field.SEA_Y,1.0)
	return Color(clampf(t.r,0.5,1.8),clampf(t.g,0.5,1.8),clampf(t.b,0.5,1.8))

## A bird leaving the grass at `at`: a few small bits of chaff up after it.
func puff(at: Vector2, n: int) -> void:
	if not kick_on: return
	var tint := _grass_tint(at)
	for i in n:
		var out := Vector2.from_angle(_rng.randf()*TAU)
		var fling := out*_rng.randf_range(PUFF_OUT.x,PUFF_OUT.y)
		_throw(at+out*_rng.randf_range(0.0,0.5),Vector3(fling.x,_rng.randf_range(PUFF_UP.x,PUFF_UP.y),fling.y),tint,PUFF_SIZE)

## A clipped blade thrown from `at` (xz, on the ground there) at `vel`, in
## the grass's colour there (`tint`), `small` of the size.
func _throw(at: Vector2, vel: Vector3, tint: Color, small := 1.0) -> void:
	if native == null and _bits.size() >= KICK: _bits.pop_front()
	var bit := _blade(at,float(_ground.call(at.x,at.y)),vel,tint,small)
	if native != null: native.kick_add(_bit_record(bit))
	else: _bits.append(bit)

## A clipped blade's bit standing in the grass at `at` (ground `g`), off at
## `vel`: as `_throw`'s, not riding (`_fly`).
func _blade(at: Vector2, g: float, vel: Vector3, tint: Color, small: float) -> Dictionary:
	var turn := _stood(vel)
	# Its spin: end over end about the level line across its way, or rolling
	# about its own length, either a little off.
	var spin := _rng.randf_range(KICK_SPIN.x,KICK_SPIN.y)*(1.0 if _rng.randf() < 0.5 else -1.0)
	var axis := _spin_axis(vel,turn.z)
	var colour := KICK_ROOT.lerp(KICK_GREEN,_rng.randf_range(KICK_TIP.x,KICK_TIP.y))
	if _rng.randf() < KICK_DRY: colour = colour.lerp(KICK_STRAW,_rng.randf_range(0.25,0.5))
	colour = Color(colour.r*tint.r,colour.g*tint.g,colour.b*tint.b)*_rng.randf_range(0.85,1.12)
	if _rng.randf() < KICK_PALE:
		var pale: Color = KICK_PALES[_rng.randi() % KICK_PALES.size()]
		# Mostly the ground's own tint (dry ground: straw, not cream), a little paler than the green tips.
		colour = pale.lerp(Color(pale.r*tint.r,pale.g*tint.g,pale.b*tint.b),0.65)*_rng.randf_range(0.8,0.95)
	colour.a = 1.0
	return {"pos": Vector3(at.x,g+_rng.randf_range(KICK_FROM.x,KICK_FROM.y),at.y), "vel": vel, "ground": g,
		"age": 0.0, "life": _rng.randf_range(KICK_LIFE.x,KICK_LIFE.y),
		"length": _rng.randf_range(KICK_LEN.x,KICK_LEN.y)*0.65*small, "width": _rng.randf_range(KICK_WIDTH.x,KICK_WIDTH.y)*0.8*small,
		"basis": turn, "spin": axis*spin, "phase": _rng.randf(), "landed": false,
		"settle": _rng.randf_range(KICK_SETTLE.x,KICK_SETTLE.y), "rest": _rng.randf_range(KICK_SINK,KICK_FROM.y),
		"colour": colour, "ride": 0.0, "lift": 0.0, "carry": 1.0, "fall": 1.0, "sx": 0.0, "sz": 0.0, "ox": at.x, "oz": at.y}

## How much of a drift's weight (EndlessPatch `bloom` x) gives petals: none
## from its thin edge (under PETAL_EDGE), where few flowers stand.
const PETAL_EDGE := Vector2(0.4,0.75)
static func _petal_weight(w: float) -> float:
	return smoothstep(PETAL_EDGE.x,PETAL_EDGE.y,w)

## A petal's bit off a drift of kind `kind` (EndlessPatch.KINDS) at `at`
## (ground `g`), off at `vel`: small, its flower's colour, falling light.
func _petal(at: Vector2, g: float, vel: Vector3, kind: int) -> Dictionary:
	var turn := _stood(vel)
	var spin := _rng.randf_range(KICK_SPIN.x,KICK_SPIN.y)*(1.0 if _rng.randf() < 0.5 else -1.0)
	var axis := _spin_axis(vel,turn.z)
	var wash: Vector3 = Patch.KINDS[clampi(kind,0,Patch.KINDS.size()-1)][2]
	var bright := _rng.randf_range(0.85,1.15)
	var colour := Color(wash.x*bright,wash.y*bright,wash.z*bright,PETAL_MARK)
	return {"pos": Vector3(at.x,g+_rng.randf_range(0.5,1.2),at.y), "vel": vel, "ground": g,
		"age": 0.0, "life": _rng.randf_range(KICK_LIFE.x,KICK_LIFE.y)*1.6,
		"length": _rng.randf_range(PETAL_LEN.x,PETAL_LEN.y), "width": _rng.randf_range(PETAL_WIDTH.x,PETAL_WIDTH.y),
		"basis": turn, "spin": axis*spin, "phase": _rng.randf(), "landed": false,
		"settle": _rng.randf_range(KICK_SETTLE.x,KICK_SETTLE.y), "rest": _rng.randf_range(0.3,0.9),
		"colour": colour, "ride": 0.0, "lift": 0.0, "carry": 1.0, "fall": PETAL_FALL, "sx": 0.0, "sz": 0.0, "ox": at.x, "oz": at.y}

## A tuft of seed fluff off the meadow at `at` (ground `g`), off at `vel`: a
## petal's round shape (PETAL_MARK), near white, falling lighter still.
func _fluff(at: Vector2, g: float, vel: Vector3) -> Dictionary:
	var bit := _petal(at,g,vel,0)
	var bright := _rng.randf_range(0.88,1.05)
	bit.colour = Color(FLUFF_COLOUR.r*bright,FLUFF_COLOUR.g*bright,FLUFF_COLOUR.b*bright,PETAL_MARK)
	var s := _rng.randf_range(FLUFF_SIZE.x,FLUFF_SIZE.y)
	bit.length = s
	bit.width = s*0.9
	bit.fall = PETAL_FALL*0.7
	return bit

## A bit's start, standing in the grass: its length near upright, leaning
## the way it goes off (`vel`), turned any way about it.
func _stood(vel: Vector3) -> Basis:
	var way := Vector3(vel.x,0.0,vel.z)
	way = way.normalized() if way.length() > 0.1 else Vector3.FORWARD
	var lean := _rng.randf_range(0.15,0.9)
	var along := (Vector3.UP*cos(lean)+way*sin(lean)).normalized()
	var across := along.cross(way)
	if across.length() < 0.01: across = Vector3.RIGHT
	across = across.normalized().rotated(along,_rng.randf()*TAU)
	return Basis(across,along.cross(across),along).orthonormalized()

func _spin_axis(vel: Vector3, along: Vector3) -> Vector3:
	var way := Vector3(vel.x,0.0,vel.z)
	way = way.normalized() if way.length() > 0.1 else Vector3.FORWARD
	var axis := way.cross(Vector3.UP).normalized()
	if _rng.randf() < 0.35: axis = along
	return (axis+Vector3(_rng.randf_range(-0.3,0.3),_rng.randf_range(-0.3,0.3),_rng.randf_range(-0.3,0.3))).normalized()

## A bit as ZenScapeMotes takes it (flight_fx.h BIT_REC): pos, vel, ground,
## age, life, length, width, the basis's rows, spin, phase, settle, rest,
## colour (thrown, so not landed); then its ride, lift, carry, fall, and its
## ground's slope (sx, sz) from (ox, oz).
static func _bit_record(b: Dictionary) -> PackedFloat64Array:
	var p: Vector3 = b.pos
	var v: Vector3 = b.vel
	var t: Basis = b.basis
	var w: Vector3 = b.spin
	var c: Color = b.colour
	return PackedFloat64Array([p.x,p.y,p.z,v.x,v.y,v.z,float(b.ground),float(b.age),float(b.life),float(b.length),float(b.width),
		t.x.x,t.y.x,t.z.x,t.x.y,t.y.y,t.z.y,t.x.z,t.y.z,t.z.z,w.x,w.y,w.z,float(b.phase),float(b.settle),float(b.rest),
		c.r,c.g,c.b,c.a,float(b.ride),float(b.lift),float(b.carry),float(b.fall),float(b.sx),float(b.sz),float(b.ox),float(b.oz)])

# --- The drift ------------------------------------------------------------------------

## 0..1: how gusty the air is at `at` now: slow patches about 30 m along the
## wind and 18 m across rolling downwind with the air's travel (as the
## shaders' zs_gust_band_at, on the CPU's noise), roughened finer.
func _gusty(at: Vector2, way: Vector2) -> float:
	var q := at-way*_air_travel
	var along := q.dot(way)
	var side := q.dot(Vector2(-way.y,way.x))
	var band := smoothstep(0.38,0.78,Gusts.noise(Vector2(along*0.035+17.3,side*0.055+4.1)))
	var fine := Gusts.noise(Vector2(along*0.11-3.7,side*0.21+9.2))
	return band*(0.45+0.55*fine)

func _drift(delta: float, eye: Vector3, under: float, grass: Callable) -> void:
	var speed := _air.length()
	var way := _air/speed if speed > 1.0e-3 else Vector2.RIGHT
	var near := 0.0 if is_nan(under) else 1.0-smoothstep(DRIFT_HIGH.x,DRIFT_HIGH.y,eye.y-under)
	var k := clampf(speed/DRIFT_AIR,0.0,2.0)
	var flat_vel := Vector2(_eye_vel.x,_eye_vel.z)
	var rate := DRIFT_PUFFS*pow(k,DRIFT_POW)*near*(1.0+flat_vel.length()/DRIFT_PACE)*maxf(drift_scale if drift_on else 0.0,petal_scale if petals_on else 0.0)
	_puff_owed = minf(_puff_owed+rate*delta,1.5)
	# A new puff (one a frame at most: it asks the land three times).
	if _puff_owed >= 1.0 and _puffs.size() < DRIFT_PUFF_MAX:
		_puff_owed -= 1.0
		# Flying, the puffs line the way ahead (a corridor from DRIFT_NEAR m
		# out to the eye's travel over DRIFT_LEAD s, DRIFT_REACH*0.6 m to
		# each side), so the eye flies through them; slow, a disc round it.
		var lead_m := minf(flat_vel.length()*DRIFT_LEAD,DRIFT_LEAD_MAX)
		var near_m := maxf(DRIFT_NEAR,flat_vel.length()*DRIFT_NEAR_LEAD)
		var ahead_way := flat_vel.normalized() if flat_vel.length() > 1.0 else way
		var corridor := lead_m > DRIFT_REACH
		var centre := Vector2(eye.x,eye.z)+(Vector2.ZERO if corridor else ahead_way*lead_m)-_air*DRIFT_UPWIND
		var across := Vector2(-ahead_way.y,ahead_way.x)
		var best := Vector2.ZERO
		var best_score := -1.0
		var best_bloom := Vector2.ZERO
		for _try in DRIFT_TRIES:
			var at := centre+Vector2.from_angle(_rng.randf()*TAU)*sqrt(_rng.randf())*DRIFT_REACH
			if corridor: at = centre+ahead_way*_rng.randf_range(near_m,maxf(lead_m,near_m+10.0))+across*_rng.randf_range(-1.0,1.0)*DRIFT_SIDE
			var score := _gusty(at,way)
			var bloom := Patch.bloom(at.x,at.y) if petals_on else Vector2.ZERO
			score += bloom.x*DRIFT_BLOOM_DRAW
			if score > best_score:
				best_score = score
				best = at
				best_bloom = bloom
		# A calm spot mostly stays still: the gaps between the puffs.
		if _rng.randf() < best_score:
			var g := float(grass.call(best.x,best.y))
			if not is_nan(g):
				var ahead := best+way*12.0
				var g2 := float(_ground.call(ahead.x,ahead.y))
				var slope := Vector2.ZERO if is_nan(g2) else way*clampf((g2-g)/12.0,-0.6,0.6)
				var strength := clampf(best_score,0.3,1.0)
				var count := roundi(lerpf(DRIFT_PUFF.x,DRIFT_PUFF.y,strength*_rng.randf_range(0.6,1.0)))
				var petals := clampf(_petal_weight(best_bloom.x)*PETAL_SHARE*petal_scale,0.0,1.0) if petals_on else 0.0
				var blades := count if drift_on else 0
				if not drift_on: count = roundi(count*petals)
				_puffs.append({"at": best, "ground": g, "slope": slope, "left": count, "petals": petals,
					"blades": blades, "kind": int(best_bloom.y), "every": _rng.randf_range(DRIFT_PUFF_TIME.x,DRIFT_PUFF_TIME.y)/maxf(count,1),
					"owed": 1.0, "tint": _grass_tint(best), "size": _rng.randf_range(DRIFT_PUFF_SIZE.x,DRIFT_PUFF_SIZE.y),
					"carry": _rng.randf_range(DRIFT_CARRY.x,DRIFT_CARRY.y), "over": eye.y-under})
	# The puffs let go their bits.
	var left := DRIFT_SPAWNS
	var j := 0
	while j < _puffs.size():
		var pf: Dictionary = _puffs[j]
		pf.owed = float(pf.owed)+delta/float(pf.every)
		while float(pf.owed) >= 1.0 and int(pf.left) > 0 and left > 0:
			pf.owed = float(pf.owed)-1.0
			pf.left = int(pf.left)-1
			left -= 1
			_drift_bit(pf,way)
		if int(pf.left) <= 0: _puffs.remove_at(j)
		else: j += 1
	stats.puffs = _puffs.size()
	if native != null:
		_drift_buf = native.drift_step(delta,_time,_air)
		_drift_mm.buffer = _drift_buf
		var n: int = native.drift_count()
		_drift_mm.visible_instance_count = n
		stats.drift = n
		return
	_drift_buf = _fly(_drifts,_drift_buf,delta)
	_drift_mm.buffer = _drift_buf
	_drift_mm.visible_instance_count = _flown
	stats.drift = _flown

## One of a puff's bits: a blade, or over a drift its petal, from within the
## puff's patch (stretched along the wind), rising to ride the air.
func _drift_bit(pf: Dictionary, way: Vector2) -> void:
	var at: Vector2 = pf.at
	var size := float(pf.size)
	var side := Vector2(-way.y,way.x)
	var p := at+way*_rng.randf_range(-1.0,1.0)*size*DRIFT_STREAM+side*_rng.randf_range(-1.0,1.0)*size*0.6
	var slope: Vector2 = pf.slope
	var g := float(pf.ground)+slope.dot(p-at)
	var carry := float(pf.carry)*_rng.randf_range(0.85,1.15)
	var vel := Vector3(_air.x*carry*0.5,_rng.randf_range(DRIFT_RISE.x,DRIFT_RISE.y),_air.y*carry*0.5)
	var petal := _rng.randf() < float(pf.petals) or int(pf.blades) <= 0
	var bit: Dictionary
	if petal: bit = _petal(p,g,vel,int(pf.kind))
	elif _rng.randf() < fluff_share: bit = _fluff(p,g,vel)
	else:
		bit = _blade(p,g,vel,pf.tint,1.0)
		if _rng.randf() < DRIFT_PALE:
			var pale: Color = DRIFT_PALES[_rng.randi() % DRIFT_PALES.size()]
			var tint: Color = pf.tint
			bit.colour = pale.lerp(Color(pale.r*tint.r,pale.g*tint.g,pale.b*tint.b),DRIFT_TINT)*_rng.randf_range(0.9,1.08)
			bit.colour.a = 1.0
		bit.length = _rng.randf_range(DRIFT_LEN.x,DRIFT_LEN.y)
		bit.width = _rng.randf_range(DRIFT_WIDTH.x,DRIFT_WIDTH.y)
	# How high it rides: about the eye's own height over the ground (a share
	# DRIFT_OVER of it), so flying low the streams cross the view at the
	# plane's height and against the sky, not down in the grass; never under
	# DRIFT_RIDE (the title's eye sits in the grass).
	var over := float(pf.get("over",0.0))
	var lift := maxf(_rng.randf_range(DRIFT_RIDE.x,DRIFT_RIDE.y),over*_rng.randf_range(DRIFT_OVER.x,DRIFT_OVER.y))
	lift = minf(lift,DRIFT_RIDE_MAX)
	# A fast eye meets them already up (the air carries them, it doesn't see
	# them rise), and they ride until it has passed them, then fall behind it,
	# so the pool holds the ones ahead.
	var flat_vel := Vector2(_eye_vel.x,_eye_vel.z)
	var fast := clampf((flat_vel.length()-DRIFT_FAST.x)/(DRIFT_FAST.y-DRIFT_FAST.x),0.0,1.0)
	var up := fast*_rng.randf_range(0.55,1.0)
	var p3: Vector3 = bit.pos
	p3.y = lerpf(p3.y,g+lift,up)
	bit.pos = p3
	vel.y *= 1.0-up
	bit.vel = vel
	var pace := 1.0/(1.0+flat_vel.length()/DRIFT_PASSED)
	var ride := _rng.randf_range(DRIFT_RIDE_TIME.x,DRIFT_RIDE_TIME.y)*(1.3 if petal else 1.0)
	if fast > 0.0:
		var fwd := flat_vel.normalized()
		var closing := flat_vel.length()-_air.dot(fwd)*carry
		if closing > 4.0:
			var ahead := (p-Vector2(_last_eye.x,_last_eye.z)).dot(fwd)
			var passed := maxf(ahead,0.0)/closing+_rng.randf_range(DRIFT_AFTER.x,DRIFT_AFTER.y)
			ride = lerpf(ride,minf(ride,maxf(passed,0.5)),fast)
	bit.ride = ride
	bit.lift = lift
	bit.carry = carry
	bit.settle = ride+float(bit.settle)*0.5
	bit.life = ride+_rng.randf_range(2.5,4.0)*(1.6 if petal else 1.0)*pace*(1.0-DRIFT_UNSEEN*fast)
	bit.sx = slope.x
	bit.sz = slope.y
	bit.ox = at.x
	bit.oz = at.y
	bit.ground = float(pf.ground)
	if native != null:
		native.drift_add(_bit_record(bit))
		return
	if _drifts.size() >= DRIFT: _drifts.pop_front()
	_drifts.append(bit)

# --- The far drift (the wind seen from height and far off) ------------------------

## Streamers of flecks (shaders/wind_fleck.gdshader: one camera-facing fleck
## each, never under a couple of pixels) carried downwind over the meadows
## FAR_RING m out, in a sector led along the view, so from height the land
## below shows the wind; they give way to the near drift's real blades within
## about 45..85 m of the eye (the shader). A streamer is placed by the puffs'
## logic (gust patches, more in stronger air, petals over a flower drift in its
## colour) and its flecks are written once, at birth: each flies on the GPU
## from where and when it was let go, so a frame here costs one uniform and,
## now and then, one streamer's writes. FAR_STREAMERS slots of FAR_FLECKS.
const FLECK = preload("res://shaders/wind_fleck.gdshader")
const FAR_STREAMERS := 56
const FAR_FLECKS := 48
## Streamers a second at DRIFT_AIR m/s of air (times k^DRIFT_POW, before the
## gust's chance), how far out (m: near, far), the sector's half-angle (rad)
## about the view, and how long one lives (s; its flecks let go over
## FAR_STAGGER s).
const FAR_RATE := 5.0
const FAR_RING := Vector2(70.0,520.0)
const FAR_SECTOR := 1.0
const FAR_LIFE := Vector2(6.0,12.0)
const FAR_STAGGER := 2.0
## A streamer's length along the wind and half-width across (m), how high its
## flecks ride over the ground (m), and a fleck's own size (m: the shader keeps
## it at least a couple of pixels across).
const FAR_LEN := Vector2(20.0,48.0)
const FAR_WIDE := Vector2(3.0,8.0)
const FAR_UP := Vector2(3.0,16.0)
const FAR_SIZE := Vector2(0.28,0.42)
## Far off the pale straw is lost on the sunlit meadow: the far flecks are
## cream, a dry brown and tan (linear), and more of them seed fluff.
const FAR_PALES := [Color(0.92,0.9,0.78),Color(0.30,0.21,0.10),Color(0.36,0.25,0.12),Color(0.58,0.42,0.22)]
const FAR_FLUFF := 0.25

var _far_mm: MultiMesh
var _far_mat: ShaderMaterial
var _far_free := PackedFloat64Array()
var _far_next := 0
var _far_owed := 0.0
var _far_alive := 0

func _far_setup() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_far_mat = ShaderMaterial.new()
	_far_mat.shader = FLECK
	var n := FAR_STREAMERS*FAR_FLECKS
	_far_mm = _batch("WindFar",quad,n,true,_far_mat)
	# Every fleck spent until its streamer is born (born long ago, no life).
	var buf := PackedFloat32Array()
	buf.resize(n*20)
	for i in n:
		var o := i*20
		buf[o] = 1.0
		buf[o+5] = 1.0
		buf[o+10] = 1.0
		buf[o+16] = -1.0e6
	_far_mm.buffer = buf
	_far_mm.visible_instance_count = n
	_far_free.resize(FAR_STREAMERS)
	_far_free.fill(-1.0)

func _far(delta: float, eye: Vector3, grass: Callable) -> void:
	_far_mat.set_shader_parameter(&"now",_time)
	var speed := _air.length()
	if speed < 0.2: return
	var way := _air/speed
	var k := clampf(speed/DRIFT_AIR,0.0,2.0)
	var rate := FAR_RATE*pow(k,DRIFT_POW)*far_scale
	_far_owed = minf(_far_owed+rate*delta,1.5)
	if _far_owed < 1.0: return
	_far_owed -= 1.0
	# A free slot (one whose streamer is done), looked for from the last.
	var slot := -1
	_far_alive = 0
	for s in FAR_STREAMERS:
		if _far_free[s] > _time: _far_alive += 1
	stats.far = _far_alive
	for s in FAR_STREAMERS:
		var j := (_far_next+s) % FAR_STREAMERS
		if _far_free[j] <= _time:
			slot = j
			break
	if slot < 0: return
	var cam := get_viewport().get_camera_3d()
	var fwd := Vector2(_eye_vel.x,_eye_vel.z)
	if cam != null:
		var z := -cam.global_basis.z
		if Vector2(z.x,z.z).length() > 0.05: fwd = Vector2(z.x,z.z)
	fwd = fwd.normalized() if fwd.length() > 0.01 else way
	var best := Vector2.ZERO
	var best_score := -1.0
	var best_bloom := Vector2.ZERO
	for _try in 2:
		var r := lerpf(FAR_RING.x,FAR_RING.y,sqrt(_rng.randf()))
		var at := Vector2(eye.x,eye.z)+fwd.rotated(_rng.randf_range(-FAR_SECTOR,FAR_SECTOR))*r
		var score := _gusty(at,way)
		var bloom := Patch.bloom(at.x,at.y) if petals_on else Vector2.ZERO
		score += bloom.x*DRIFT_BLOOM_DRAW
		if score > best_score:
			best_score = score
			best = at
			best_bloom = bloom
	if _rng.randf() >= best_score: return
	var g := float(grass.call(best.x,best.y))
	if is_nan(g): return
	var length := _rng.randf_range(FAR_LEN.x,FAR_LEN.y)
	var ahead := best+way*length*0.5
	var g2 := float(_ground.call(ahead.x,ahead.y))
	var slope := 0.0 if is_nan(g2) else clampf((g2-g)/(length*0.5),-0.6,0.6)
	var tint := _grass_tint(best)
	var strength := clampf(best_score,0.3,1.0)
	var count := roundi(lerpf(FAR_FLECKS*0.45,FAR_FLECKS,strength*_rng.randf_range(0.6,1.0)))
	var petals := clampf(_petal_weight(best_bloom.x)*PETAL_SHARE*petal_scale,0.0,1.0) if petals_on else 0.0
	if not drift_on:
		count = roundi(count*petals)
		petals = 1.0
	var kind := clampi(int(best_bloom.y),0,Patch.KINDS.size()-1)
	var wash: Vector3 = Patch.KINDS[kind][2]
	var wide := _rng.randf_range(FAR_WIDE.x,FAR_WIDE.y)
	var side := Vector2(-way.y,way.x)
	var carry := _rng.randf_range(DRIFT_CARRY.x,DRIFT_CARRY.y)
	var life_max := 0.0
	for j in FAR_FLECKS:
		var idx := slot*FAR_FLECKS+j
		if j >= count:
			_far_mm.set_instance_custom_data(idx,Color(-1.0e6,0.0,0.0,0.0))
			continue
		var along := _rng.randf_range(-0.5,0.5)
		var across := _rng.randf_range(-1.0,1.0)*wide*sqrt(1.0-absf(along)*1.6)
		var p := best+way*along*length+side*across
		var y := g+slope*along*length+lerpf(FAR_UP.x,FAR_UP.y,pow(_rng.randf(),1.4))
		var colour: Color
		var size := _rng.randf_range(FAR_SIZE.x,FAR_SIZE.y)
		if _rng.randf() < petals:
			var b := _rng.randf_range(0.85,1.15)
			colour = Color(wash.x*b,wash.y*b,wash.z*b,PETAL_MARK)
			size *= 0.8
		elif _rng.randf() < fluff_share*FAR_FLUFF/DRIFT_FLUFF:
			var b := _rng.randf_range(0.88,1.05)
			colour = Color(FLUFF_COLOUR.r*b,FLUFF_COLOUR.g*b,FLUFF_COLOUR.b*b,PETAL_MARK)
			size *= 0.8
		else:
			var pale: Color = FAR_PALES[_rng.randi() % FAR_PALES.size()]
			colour = pale.lerp(Color(pale.r*tint.r,pale.g*tint.g,pale.b*tint.b),DRIFT_TINT)*_rng.randf_range(0.9,1.08)
			colour.a = 1.0
		var born := _time+_rng.randf_range(0.0,FAR_STAGGER)
		var life := _rng.randf_range(FAR_LIFE.x,FAR_LIFE.y)
		life_max = maxf(life_max,born+life)
		var c := carry*_rng.randf_range(0.85,1.15)
		_far_mm.set_instance_transform(idx,Transform3D(Basis.from_scale(Vector3.ONE*size),Vector3(p.x,y,p.y)))
		_far_mm.set_instance_color(idx,colour)
		_far_mm.set_instance_custom_data(idx,Color(born,life,_air.x*c,_air.y*c))
	_far_free[slot] = life_max+0.1
	_far_next = (slot+1) % FAR_STREAMERS