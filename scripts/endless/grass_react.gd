extends Node
## The endless grass reacting (docs/design/endless-flight/grass-react-handoff.md):
## the propeller's wash, the walker and the wind's gusts push the grass, and
## it springs back. Everything that pushes drops STAMPS: a point, a reach, a
## strength, the air's way there, a front speed and a hold. Every frame the
## live stamps are drawn, summed, into one world-space map round the eye
## (MAP_PX texels over MAP_M m, half float, a SubViewport with one
## MultiMeshInstance2D; shaders/grass_react_stamp.gdshader works out each
## stamp's push from its age: a quick push as its front arrives, held, then
## a springy overshoot back past rest and settling). The near tufts
## (reference_surface `grass_blades`), the far ring (shaders/
## endless_tuft_far.gdshader) and the painted ground (shaders/
## endless_ground.gdshader) read it through shaders/grass_react.gdshaderinc
## (zs_react_map, zs_react_rect): the tufts bend and lie over, and from up
## high the stirred patches show a paler sheen.
##
##   wash   while the plane is within WASH_UP spans of the ground with its
##          engine running, a puff every WASH_EVERY s where the prop's wash
##          comes down behind it: it fans out from there (WASH_FRONT m/s),
##          swirling with the prop (WASH_SWIRL) and blown back along the
##          plane's way (WASH_BACK). Stronger low and with the throttle open
##          (`thrust`); rolling on the wheels too.
##   walker `walker(at, velocity, sliding)` each frame while someone is on
##          foot: a stamp a stride, parting the grass round him and
##          dragging it a little after him (WALK_*).
##   gusts  the endless look's own breeze (scripts/endless/endless_look.gd:
##          its wind's way and its air's travel, zs_gust_distance): every
##          GUST_EVERY s or so a gust comes down on the land ahead of the
##          eye. It goes into the breeze as a gust parcel (zs_puff_N,
##          shaders/reference_wind.gdshaderinc), so the near tufts' own sway
##          leans with it as it rolls downwind with the air, and here as a
##          landing that fans the grass out (GUST_REACH, GUST_FRONT), then a
##          band of lean riding downwind with the parcel (GUST_ROLL).
##
##   wake   the burrower's gust through a wood (`gust_strip`, `gust_disc`,
##          from scripts/burrower/tree_shudder.gd): not a push on this map but
##          a second one, the trees' alone (zs_gust_map, WAKE_*, shaders/
##          wake_gust_stamp.gdshader), so it can go further and last longer than
##          anything here without touching how the wash or the wind's bands
##          move a tree. It draws only while a stamp lives.
##
## Flags: --no-grass-react (none of it), --no-prop-wash, --no-grass-gusts,
## --no-grass-part (the walker's), --prop-wash=X (its strength, 1),
## --grass-gusts=X (their strength, 1), --gust-every=S (GUST_EVERY),
## --grass-bend=X (how far every push bends the grass, 1), --eddy-press=X
## (how far the eddies' bands press it down, EDDY_PRESS).

const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const STAMP_SHADER = preload("res://shaders/grass_react_stamp.gdshader")
const WAKE_SHADER = preload("res://shaders/wake_gust_stamp.gdshader")

## The map: texels a side and metres a side, centred on the eye (snapped
## to SNAP texels so it doesn't swim).
const MAP_PX := 512
const MAP_M := 384.0
const SNAP := 4
## The most stamps alive at once.
const MOST := 220

## The wash, in plane spans (WorldScale TOY_SPAN x the plane's size): how
## high it reaches the grass, its puff's reach there (wider the higher it
## comes down), how far behind the plane it comes down per m of height.
const WASH_UP := 7.0
const WASH_REACH := Vector2(2.4, 4.5)
const WASH_LAG := 0.55
const WASH_EVERY := 1.0/18.0
const WASH_FRONT := 11.0
const WASH_HOLD := 0.12
const WASH_SWIRL := 0.6
const WASH_BACK := 0.9
## A puff's strength at full thrust right over the grass; the steady sum of
## puffs WASH_EVERY apart is about this (each is scaled by SUM_SPAN).
const WASH_STRENGTH := 2.8
## About the seconds of push one stamp gives (its hold, rise and swing
## summed), so a stream of them sums to their strength.
const SUM_SPAN := 0.24
## The jitter in each puff's strength (the wash is turbulent).
const WASH_TURB := 0.45

## The walker: a stamp each WALK_STEP of his height moved (or WALK_EVERY s
## standing), its reach in his heights (WorldScale wanderer_tall; sliding
## wider), the drag after him, the hold.
const WALK_STEP := 0.25
const WALK_EVERY := 0.15
const WALK_REACH := 1.0
const SLIDE_REACH := 1.4
const WALK_STRENGTH := 1.5
const WALK_DRAG := 0.35
const WALK_HOLD := 0.45

## Gusts: about every GUST_EVERY s (+-GUST_JITTER), GUST_AHEAD m ahead of the
## eye (along the ground) and up to GUST_SIDE m aside, on turf.
const GUST_EVERY := 7.0
const GUST_JITTER := 3.0
const GUST_AHEAD := Vector2(35.0, 150.0)
const GUST_SIDE := 70.0
const GUST_REACH := Vector2(18.0, 34.0)
const GUST_FRONT := 6.5
const GUST_HOLD := 0.15
const GUST_STRENGTH := 1.2
## The landing's lean downwind (a share of its outward push).
const GUST_DOWNWIND := 0.5
## The band rolling on with the parcel: a stamp each GUST_ROLL.x s for
## GUST_ROLL.y s, GUST_ROLL.z m reach, GUST_ROLL.w strength.
const GUST_ROLL := Vector4(0.35, 7.0, 12.0, 0.5)
## The parcel published into the breeze (its strength), and the puff slots
## the endless land leaves free (zs_puff_0..5: all of them).
const PARCEL := 0.9
const SLOTS := 6

## The wake's map: texels a side (same ground as the push map) and its ring of
## stamps, the most alive. WAKE_LIFE: the longest a stamp lives, past its
## reach's arrival (wake_gust_stamp.gdshader RISE, HOLD, GONE; WAKE_FRONT FRONT).
const WAKE_PX := 256
const WAKE_RING := 220
const WAKE_FRONT := 30.0
const WAKE_LIFE := 0.7+0.5+6.0

var enabled := true
var wash_on := true
var gusts_on := true
var part_on := true
var wash_scale := 1.0
var gust_scale := 1.0
var bend := 1.0
var gust_every := GUST_EVERY
## How far an eddy's swept band presses the grass down, as a share of the
## wash's and the walker's press (EDDY_PRESS; --eddy-press=X).
const EDDY_PRESS := 0.25
var eddy_press := EDDY_PRESS
var time := 0.0
## For the numbers: stamps alive, the wash's strength now, gusts so far.
var stats := {"stamps": 0, "wash": 0.0, "gusts": 0}
## Where the wash comes down now (for the motes, scripts/endless/
## endless_motes.gd): at (xz), reach (m), k (its strength 0..1), back (the
## way it blows, xz); empty while it doesn't reach the grass.
var wash_spot := {}

var _viewport: SubViewport
var _multimesh: MultiMesh
var _stamps: Array[Dictionary] = []
var _buffer := PackedFloat32Array()
var _min := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _wash_at := 0.0
var _walk_from := Vector2.INF
var _walk_at := 0.0
var rings_on := true
var _gust_next := 3.0
var _gusts: Array[Dictionary] = []
var _parcels: Array = []
var _wake_view: SubViewport
var _wake_mesh: MultiMesh
var _wake_mat: ShaderMaterial
var _wake_i := 0
var _wake_until := -INF

static func wanted() -> bool:
	return not "--no-grass-react" in LaunchArgs.user_args()

func setup(land_seed: int) -> void:
	name = "GrassReact"
	_rng.seed = land_seed*7919+13
	for a: String in LaunchArgs.user_args():
		if a == "--no-prop-wash": wash_on = false
		elif a == "--no-grass-gusts": gusts_on = false
		elif a == "--no-grass-part": part_on = false
		elif a.begins_with("--prop-wash="): wash_scale = float(a.get_slice("=",1))
		elif a.begins_with("--grass-gusts="): gust_scale = float(a.get_slice("=",1))
		elif a.begins_with("--gust-every="): gust_every = maxf(float(a.get_slice("=",1)),0.5)
		elif a.begins_with("--grass-bend="): bend = float(a.get_slice("=",1))
		elif a.begins_with("--eddy-press="): eddy_press = float(a.get_slice("=",1))
	if wash_scale <= 0.0: wash_on = false
	if gust_scale <= 0.0: gusts_on = false
	_parcels.resize(SLOTS)
	_viewport = SubViewport.new()
	_viewport.name = "PushMap"
	_viewport.size = Vector2i(MAP_PX,MAP_PX)
	_viewport.use_hdr_2d = true
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_multimesh = MultiMesh.new()
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_multimesh.mesh = quad
	_multimesh.instance_count = MOST
	_multimesh.visible_instance_count = 0
	_buffer.resize(MOST*16)
	var drawn := MultiMeshInstance2D.new()
	drawn.multimesh = _multimesh
	var m := ShaderMaterial.new()
	m.shader = STAMP_SHADER
	m.set_shader_parameter("px_per_m",MAP_PX/MAP_M)
	drawn.material = m
	_viewport.add_child(drawn)
	RenderingServer.global_shader_parameter_set("zs_react_map",_viewport.get_texture())
	_publish_rect()
	_wake_view = SubViewport.new()
	_wake_view.name = "WakeMap"
	_wake_view.size = Vector2i(WAKE_PX,WAKE_PX)
	_wake_view.use_hdr_2d = true
	_wake_view.transparent_bg = true
	_wake_view.disable_3d = true
	_wake_view.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_wake_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_wake_view)
	_wake_mesh = MultiMesh.new()
	_wake_mesh.use_colors = true
	_wake_mesh.use_custom_data = true
	var wake_quad := QuadMesh.new()
	wake_quad.size = Vector2.ONE
	_wake_mesh.mesh = wake_quad
	_wake_mesh.instance_count = WAKE_RING
	# Each draws where its custom data says; the transform only keeps the whole
	# map in the batch's bounds.
	for i in WAKE_RING:
		_wake_mesh.set_instance_transform_2d(i,Transform2D(0.0,Vector2.ONE*WAKE_PX,0.0,Vector2.ONE*WAKE_PX*0.5))
	var wake_drawn := MultiMeshInstance2D.new()
	wake_drawn.multimesh = _wake_mesh
	_wake_mat = ShaderMaterial.new()
	_wake_mat.shader = WAKE_SHADER
	_wake_mat.set_shader_parameter("px_per_m",WAKE_PX/MAP_M)
	wake_drawn.material = _wake_mat
	_wake_view.add_child(wake_drawn)
	RenderingServer.global_shader_parameter_set("zs_gust_map",_wake_view.get_texture())

func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_wake_until = -INF
		_wake_step(Vector2.ZERO)
		_stamps.clear()
		_gusts.clear()
		for i in SLOTS: _free_parcel(i)
	_publish_rect()

## The plane's span in m (the wash's unit).
static func span(plane_size: float) -> float:
	return WorldScale.TOY_SPAN*plane_size

## One frame. `eye` the drawing camera; `plane` the plane's state:
## position, forward (Vector3), over (m over the ground under it, NAN over
## the sea), ground (the ground's height under it), thrust (0..1, the engine
## and the throttle), size (the plane's ground scale); `air` the look's
## breeze: way (Vector2), travel (zs_gust_distance), facing (the view's xz).
## `land` is a Callable(x, z) -> height, or NAN where no grass grows.
func step(delta: float, eye: Vector3, plane: Dictionary, air: Dictionary, land: Callable) -> void:
	if not enabled: return
	time += delta
	var c := Vector2(eye.x,eye.z)
	var texel := MAP_M/MAP_PX
	var snap := texel*SNAP
	var centre := Vector2(snappedf(c.x,snap),snappedf(c.y,snap))
	_min = centre-Vector2.ONE*MAP_M*0.5
	if wash_on and not plane.is_empty(): _wash(plane)
	else:
		stats.wash = 0.0
		wash_spot = {}
	if gusts_on and rings_on and not air.is_empty(): _gust_step(delta,eye,air,land)
	_draw()
	_publish_rect()
	_wake_step(c if gust_eye == Vector2.INF else gust_eye)

func _publish_rect() -> void:
	var on := enabled and bend > 0.0
	RenderingServer.global_shader_parameter_set("zs_react_rect",Vector4(_min.x,_min.y,MAP_M,bend if on else 0.0))

# --- The wash -------------------------------------------------------------------------

## The wash's strength (0..1) at `over` m over the ground with `thrust`.
static func wash_strength(over: float, thrust: float, plane_span: float) -> float:
	if is_nan(over): return 0.0
	var up := WASH_UP*plane_span
	var low := 1.0-smoothstep(0.0,up,maxf(over,0.0))
	return low*low*clampf(thrust,0.0,1.0)

func _wash(plane: Dictionary) -> void:
	var size: float = plane.get("size",1.0)
	var s := span(size)
	var over: float = plane.get("over",NAN)
	var k := wash_strength(over,float(plane.get("thrust",1.0)),s)*wash_scale
	stats.wash = k
	if k < 0.02:
		wash_spot = {}
		return
	if time-_wash_at < WASH_EVERY: return
	var spent := minf(time-_wash_at,WASH_EVERY*3.0)
	_wash_at = time
	var p: Vector3 = plane.position
	var f: Vector3 = plane.forward
	var flat := Vector2(f.x,f.z)
	flat = flat.normalized() if flat.length() > 0.05 else Vector2(0,-1)
	var up := WASH_UP*s
	var lift := clampf(over/up,0.0,1.0)
	var hit := Vector2(p.x,p.z)-flat*(maxf(over,0.0)*WASH_LAG+s*0.25)
	var reach := s*lerpf(WASH_REACH.x,WASH_REACH.y,lift)
	wash_spot = {"at": hit, "reach": reach, "k": k, "back": -flat}
	var strength := WASH_STRENGTH*k*spent/SUM_SPAN*(1.0+_rng.randf_range(-WASH_TURB,WASH_TURB))
	_add({"at": hit, "way": -flat*WASH_BACK, "strength": strength, "swirl": WASH_SWIRL,
		"reach": reach, "front": WASH_FRONT, "hold": WASH_HOLD})

# --- The walker -----------------------------------------------------------------------

## Someone on foot at `at` moving at `velocity` (m/s), sliding wider. Call
## each frame he is on the ground.
func walker(at: Vector3, velocity: Vector3, sliding := false) -> void:
	if not enabled or not part_on: return
	var size := WorldScale.wanderer_tall
	var here := Vector2(at.x,at.z)
	var moved := INF if _walk_from == Vector2.INF else here.distance_to(_walk_from)
	if moved < WALK_STEP*size and time-_walk_at < WALK_EVERY: return
	var flat := Vector2(velocity.x,velocity.z)
	var speed := flat.length()
	var way := flat/speed if speed > 0.2 else Vector2.ZERO
	var still := clampf(speed/1.5,0.25,1.0)
	_walk_from = here
	_walk_at = time
	var reach := (SLIDE_REACH if sliding else WALK_REACH)*size*(1.0+0.15*clampf(speed/6.0,0.0,1.0))
	# A stride's stamps overlap about reach*2/step of them (fewer standing).
	var overlap := maxf(2.0*reach/(WALK_STEP*size),1.0) if speed > 0.5 else (WALK_HOLD+SUM_SPAN)/WALK_EVERY
	_add({"at": here, "way": way*WALK_DRAG, "strength": WALK_STRENGTH*still*2.2/overlap, "swirl": 0.0,
		"reach": reach, "front": 0.0, "hold": WALK_HOLD})

## Something parked at `at` (the main menu's plane, studies/endless_flight.gd):
## the grass parted round it out to `reach` m, `strength` times a standing
## walker's push, kept so while it is called each frame (a stamp every
## PART_EVERY s, overlapping as his do standing). `slot` (0 or 1) keeps two
## such things apart.
func part(at: Vector2, reach: float, strength := 1.0, slot := 0) -> void:
	if not enabled: return
	if time-_part_at[slot] < PART_EVERY: return
	_part_at[slot] = time
	_add({"at": at, "way": Vector2.ZERO, "strength": WALK_STRENGTH*strength*2.2*PART_EVERY/(WALK_HOLD+SUM_SPAN), "swirl": 0.0,
		"reach": reach, "front": 0.0, "hold": WALK_HOLD})

const PART_EVERY := 0.2
var _part_at := [-INF,-INF]

## A blast out over the land from `at`: laid over as its front passes (`front`
## m/s), out to `reach` m (the stomper's footfall, scripts/endless/stomper_fall.gd).
## `press` the share of the press it adds: lean and press sum in the bend, so
## much of both takes a blade down through the ground and the grass goes.
func shock(at: Vector2, reach: float, front: float, strength: float, hold: float, press: float) -> void:
	if not enabled: return
	_add({"at": at, "way": Vector2.ZERO, "strength": strength, "swirl": 0.0,
		"reach": reach, "front": front, "hold": hold, "press": press})

# --- Gusts ----------------------------------------------------------------------------

func _gust_step(delta: float, eye: Vector3, air: Dictionary, land: Callable) -> void:
	var way: Vector2 = air.get("way",Vector2(1,0))
	var travel: float = air.get("travel",0.0)
	_gust_next -= delta
	if _gust_next <= 0.0:
		_gust_next = gust_every+_rng.randf_range(-GUST_JITTER,GUST_JITTER)*gust_every/GUST_EVERY
		var facing: Vector2 = air.get("facing",Vector2(0,-1))
		facing = facing.normalized() if facing.length() > 0.05 else Vector2(0,-1)
		var tries := 6
		while tries > 0:
			tries -= 1
			var at := Vector2(eye.x,eye.z)+facing*_rng.randf_range(GUST_AHEAD.x,GUST_AHEAD.y)+Vector2(-facing.y,facing.x)*_rng.randf_range(-GUST_SIDE,GUST_SIDE)
			if land.is_valid() and is_nan(float(land.call(at.x,at.y))): continue
			land_gust(at,way,travel)
			break
	# Each gust rides downwind on the air's travel, as its parcel does.
	for i in range(_gusts.size()-1,-1,-1):
		var g: Dictionary = _gusts[i]
		var age := time-float(g.born)
		if age > GUST_ROLL.y:
			if int(g.slot) >= 0: _free_parcel(int(g.slot))
			_gusts.remove_at(i)
			continue
		var now: Vector2 = g.at+way*(travel-float(g.travel))
		if age > 0.6 and time-float(g.rolled) >= GUST_ROLL.x:
			g.rolled = time
			var fade := 1.0-smoothstep(GUST_ROLL.y*0.5,GUST_ROLL.y,age)
			_add({"at": now, "way": way*1.1, "strength": GUST_ROLL.w*gust_scale*fade*float(g.strength), "swirl": 0.0,
				"reach": GUST_ROLL.z, "front": 0.0, "hold": GUST_ROLL.x*1.5})

## A gust coming down at `at` (world xz), the breeze's way `way` and its
## travel now: a landing fanning out, a parcel in the breeze, a band after.
func land_gust(at: Vector2, way: Vector2, travel: float, strength := 1.0) -> void:
	stats.gusts = int(stats.gusts)+1
	var k := strength*_rng.randf_range(0.8,1.15)
	var slot := _take_parcel(at,travel,PARCEL*k*gust_scale)
	_gusts.append({"at": at, "travel": travel, "born": time, "rolled": time, "slot": slot, "strength": k})
	_add({"at": at, "way": way*GUST_DOWNWIND, "strength": GUST_STRENGTH*k*gust_scale, "swirl": 0.08,
		"reach": _rng.randf_range(GUST_REACH.x,GUST_REACH.y), "front": GUST_FRONT, "hold": GUST_HOLD})

func _take_parcel(at: Vector2, travel: float, strength: float) -> int:
	var slot := -1
	for i in SLOTS:
		if _parcels[i] == null:
			slot = i
			break
	if slot < 0: return -1
	_parcels[slot] = true
	# Born at its landing on the breeze's travel now: it rises over its
	# first 1.5 m of travel (reference_wind `life`) as the landing fans out.
	RenderingServer.global_shader_parameter_set("zs_puff_%d" % slot,Vector4(at.x,at.y,travel,strength))
	return slot

func _free_parcel(slot: int) -> void:
	_parcels[slot] = null
	RenderingServer.global_shader_parameter_set("zs_puff_%d" % slot,Vector4.ZERO)

## The gusts alive now (for a driver): their centre now and age.
func gusts(travel: float, way: Vector2) -> Array:
	var out := []
	for g: Dictionary in _gusts:
		out.append({"at": g.at+way*(travel-float(g.travel)), "age": time-float(g.born)})
	return out

## One stamp of a swept band: the endless eddies (scripts/endless/
## endless_eddies.gd) drop these along a breeze ribbon's head, so the grass
## bows along its path and springs back behind it. `way` the head's unit way.
func eddy(at: Vector2, way: Vector2, strength: float, reach: float) -> void:
	if not enabled or not gusts_on: return
	# Stamps a spacing apart overlap about 2*reach/spacing deep; a push
	# along the path with a little spread to the sides, pressing the grass
	# down only by eddy_press of the push (at 1 the band lay flat and
	# showed the tufts' roots).
	_add({"at": at, "way": way*0.9, "strength": strength*gust_scale*0.55, "swirl": 0.0,
		"reach": reach, "front": 0.0, "hold": 0.25, "press": eddy_press})

# --- The wake (the burrower's gust) ------------------------------------------------

## What the gust's map centres on: the burrower's head (he alone writes it, and
## he can be far from the eye), or the eye (INF).
var gust_eye := Vector2.INF
## The lean's gain, in `zs_gust_rect.w` (a sighting, far from the eye: more).
var gust_gain := 1.0

## A stretch of the gust along his way: centred on `at`, `half` m each way
## along `way` (unit), out to `reach` m each side, `strength` 0..1.
func gust_strip(at: Vector2, way: Vector2, half: float, reach: float, strength: float) -> void:
	_wake_add(Color(at.x,at.y,way.x,way.y),Color(half,reach,time,strength),reach)

## The gust straight out from `at`, to `reach` m (a push-up through the crowns).
func gust_disc(at: Vector2, reach: float, strength: float) -> void:
	_wake_add(Color(at.x,at.y,0.0,0.0),Color(0.0,reach,time,strength),reach)

func _wake_add(where: Color, shape: Color, reach: float) -> void:
	if not enabled or _wake_mesh == null: return
	_wake_mesh.set_instance_color(_wake_i,where)
	_wake_mesh.set_instance_custom_data(_wake_i,shape)
	_wake_i = (_wake_i+1)%WAKE_RING
	_wake_until = maxf(_wake_until,time+reach/WAKE_FRONT+WAKE_LIFE)

## The stamps never change once written: only the clock and the map's corner.
func _wake_step(eye: Vector2) -> void:
	if _wake_view == null: return
	var live := time < _wake_until
	var mode := SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	if _wake_view.render_target_update_mode != mode:
		_wake_view.render_target_update_mode = mode
		if not live: RenderingServer.global_shader_parameter_set("zs_gust_rect",Vector4.ZERO)
	if not live: return
	var snap := MAP_M/WAKE_PX*2.0
	var low := Vector2(snappedf(eye.x,snap),snappedf(eye.y,snap))-Vector2.ONE*MAP_M*0.5
	_wake_mat.set_shader_parameter("map_min",low)
	_wake_mat.set_shader_parameter("now",time)
	RenderingServer.global_shader_parameter_set("zs_gust_rect",Vector4(low.x,low.y,MAP_M,gust_gain))

# --- The map --------------------------------------------------------------------------

## A stamp's life: until its front has crossed its reach, held, and swung out.
static func life(stamp: Dictionary) -> float:
	var front: float = stamp.front
	var arrive: float = float(stamp.reach)/front if front > 0.0 else 0.0
	var wide := smoothstep(4.0,30.0,float(stamp.reach))
	return arrive+float(stamp.hold)+2.4/lerpf(1.0,0.6,wide)

func _add(stamp: Dictionary) -> void:
	stamp.born = time
	stamp.dies = time+life(stamp)
	if _stamps.size() >= MOST: _stamps.pop_front()
	_stamps.append(stamp)

func _draw() -> void:
	var i := 0
	while i < _stamps.size():
		if time >= float(_stamps[i].dies): _stamps.remove_at(i)
		else: i += 1
	var per_m := MAP_PX/MAP_M
	var n := 0
	for s: Dictionary in _stamps:
		var at: Vector2 = s.at
		var reach: float = s.reach
		var px := (at-_min)*per_m
		var side := reach*2.0*per_m
		if px.x+side < 0.0 or px.y+side < 0.0 or px.x-side > MAP_PX or px.y-side > MAP_PX: continue
		var way: Vector2 = s.way
		# A 2D instance: its transform's two rows (x, y, 0, origin), colour, custom.
		var o := n*16
		_buffer[o] = side
		_buffer[o+3] = px.x
		_buffer[o+5] = side
		_buffer[o+7] = px.y
		_buffer[o+8] = way.x
		_buffer[o+9] = way.y
		_buffer[o+10] = float(s.strength)
		_buffer[o+11] = float(s.swirl)
		_buffer[o+12] = float(s.get("press",1.0))
		_buffer[o+13] = time-float(s.born)
		_buffer[o+14] = float(s.front)
		_buffer[o+15] = float(s.hold)
		n += 1
	_multimesh.buffer = _buffer
	_multimesh.visible_instance_count = n
	stats.stamps = n

## The push (x, z) and press the map holds at a world point, worked out on
## the CPU as the stamp shader does (for drivers and checks).
func push_at(p: Vector2) -> Vector3:
	var sum := Vector3.ZERO
	for s: Dictionary in _stamps:
		var reach: float = s.reach
		var o: Vector2 = p-Vector2(s.at)
		var r := o.length()
		var u := r/maxf(reach,0.01)
		if u >= 1.0: continue
		var wide := smoothstep(4.0,30.0,reach)
		var front: float = s.front
		var t := time-float(s.born)-(r/front if front > 0.0 else 0.0)
		var after := maxf(t-float(s.hold),0.0)
		var swing := smoothstep(-(0.1+0.35*wide),0.0,t)*exp(-2.4*lerpf(1.0,0.6,wide)*after)*cos(5.2*lerpf(1.0,0.55,wide)*after)
		var fall := 1.0-smoothstep(0.45,1.0,u)
		var out := o/sqrt(r*r+0.04*reach*reach)
		var turn := Vector2(-out.y,out.x)*float(s.swirl)
		var push: Vector2 = (out+turn+Vector2(s.way))*(float(s.strength)*swing*fall)
		var core := 1.0-smoothstep(0.0,0.5,u)
		var press := float(s.strength)*float(s.get("press",1.0))*core*(swing if swing > 0.0 else swing*0.5)
		sum += Vector3(push.x,push.y,press)
	return sum
