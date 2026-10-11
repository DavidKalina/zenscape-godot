extends Node3D
## Breeze ribbons (docs/scenic/breeze-ribbons.md): the air drawn as a few
## long painterly strokes that ride it. Each ribbon is the trace of a mote
## carried on a flowing air field (`flow`): downwind, meandering across,
## rising over ground ahead and settling into hollows, swelling and sinking
## in long undulations, and now and then caught in an eddy that curls it
## through a loop. Its tail is where the mote has been, so the stroke is
## continuous and travels, never a mark stamped in place.
##
## Ribbons ride gust fronts (studies/gust_fronts.gd): a front brings a few in
## along its line, at its own pace, so the stroke and the plants bowing under
## it are the same air. Between fronts a lone ribbon drifts through now and
## then. Same interface as scripts/weather_wind_trails.gd (setup, advance),
## plus `carry_front`.
##
## Ribbons fly over woods, not through them: the trees' shade on the ground
## (scripts/ground_shade.gd, `set_canopy`) lifts the height they ride, so a
## stroke never threads a crown and shows only between its clumps. Each
## ribbon's head is published (zs_ribbon_0..7) and bows the plants it passes
## over in a wake behind it (zs_ribbon_wake, shaders/reference_wind.gdshaderinc),
## so the stroke and what it moves are one gesture.

const SHADER = preload("res://shaders/breeze_ribbon.gdshader")
const CAPACITY := 8
## Simulation step (s): fixed, so a ribbon's path is the same at any rate.
const STEP := 1.0 / 60.0
## Seconds of path a ribbon's tail keeps, and between samples of it.
const TAIL := Vector2(1.6, 2.6)
const SAMPLE := 1.0 / 30.0
## Metres above the ground a ribbon rides, and how high it swells and sinks
## (amplitude m, period s).
const RIDE := Vector2(0.9, 2.4)
const SWELL := Vector2(0.7, 5.5)
## How far ahead (s of travel) it reads the ground, so it rises before a
## rise, and how hard it is pulled to its height (1/s): quicker up than
## down, so it clears a wood and settles slowly beyond it.
const LOOK_AHEAD := [0.0, 0.4, 0.8, 1.2]
const CLIMB := 2.6
const SETTLE := 0.9
## Metres a full canopy (ground shade 0.4 or more) lifts a ribbon's ride.
const CANOPY := 8.0
## Across-wind meander: m/s of drift and the field's scale (1/m) and pace.
const MEANDER := 2.6
const MEANDER_SCALE := 0.07
const MEANDER_PACE := 0.15
## Eddies: chance a second that a ribbon curls, and how long a curl takes
## (s). A curl turns the mote once round, in the upright plane along the
## wind (a loop), flat (a swirl) or between (a helix). Slow and so wide
## (3 to 4 m across at 5 m/s): a sweep of the air, not a twirl round a tree.
const EDDY_RATE := 0.07
const EDDY_TIME := Vector2(2.6, 3.6)
## Sweeps: a ribbon dives to skim the ground, then kicks up off it. Seconds
## to descend (smoothly, never a dive), to skim, and to lift off in a rising
## curl; the metres over the ground it skims at; how much faster it travels
## low (share); how hard its height is held while it hugs the ground (1/s);
## and how far the lift tips its path up (radians, in the upright plane along
## the wind: about 60 degrees, so it climbs several metres).
const SWEEP_DESCEND := Vector2(0.8, 1.2)
const SWEEP_SKIM := Vector2(1.0, 1.8)
const SWEEP_LIFT := Vector2(1.5, 2.5)
const SWEEP_HEIGHT := Vector2(0.2, 0.35)
const SWEEP_FAST := 1.35
const SWEEP_PULL := 2.6
const SWEEP_PITCH := 1.1
## Chance a second that a ribbon between fronts takes a sweep (well under
## EDDY_RATE), the chance a front gives one of its ribbons one, and how long
## after that ribbon joins the plate (s) it begins.
const SWEEP_RATE := 0.02
const SWEEP_CHANCE := 0.7
const SWEEP_DELAY := Vector2(0.8, 1.8)
## What a sweep does to the air (`air_at`), for the leaves and blades that
## answer it: how far (m) it reaches to the sides and back along its track,
## the drag it puts on the air along its way (share of its velocity), the
## updraft at the strongest point of lift (m/s), and the swirl round its head
## (m/s). A head this near the ground (m) is kicking it up.
const KICK_REACH := 1.5
const KICK_TRAIL := 2.0
const KICK_DRAG := 0.8
const KICK_UPDRAFT := 3.5
const KICK_SWIRL := 0.8
const KICK_NEAR := 0.7
## Between fronts, a lone ribbon every this many seconds in default air.
const LONE_GAP := Vector2(5.0, 11.0)
## Ribbons along a front, and how far upwind of the plate's middle (share
## of its radius) they join it.
const PER_FRONT := Vector2i(2, 4)
const JOIN := 0.85
## How hard a ribbon's head bows the plants under it, in zs_blow_at's units.
const WAKE := 0.55
## The stroke: true width (m) at its fullest, and its peak opacity.
const WIDTH := Vector2(0.14, 0.3)
const OPACITY := 1.0

var enabled := true
## How many ribbons it keeps at once (CAPACITY; the dragon's breath,
## scripts/dragon_breath.gd, keeps more). Only the first CAPACITY publish.
var capacity := CAPACITY
## Tuning: every ribbon's opacity, width and brightness (the stroke's
## light, 1 as lit).
var opacity_scale := 1.0
var width_scale := 1.0
## How hard the heads bow plants, as a share of WAKE (`--wake=`).
var wake_gain := 1.5
var glow := 2.0
var ground_height: Callable
## Plate point -> tree shade 0..1 (ground_shade.gd `shade_at`), or none.
var canopy: Callable
var center := Vector2.ZERO
var radius := 14.0
var ribbons: Array[Dictionary] = []
## The heads last published (zs_ribbon_N), for probes and tests.
var heads: Array[Vector4] = []
var _pending: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _carry := 0.0
var _until_lone := 3.0
var _next_id := 1
var _kicks: Array[Dictionary] = []
var _kicks_stale := true
## Share of the sweep rates (`--sweeps=`): 1 as designed, 0 for none.
var sweep_gain := 1.0
var _mesh: ImmediateMesh
var _view: MeshInstance3D
var _material: ShaderMaterial

func setup(probe: Callable) -> void:
	ground_height = probe
	_rng.randomize()
	_mesh = ImmediateMesh.new()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_view = MeshInstance3D.new()
	_view.name = "BreezeRibbons"
	_view.mesh = _mesh
	_view.material_override = _material
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.extra_cull_margin = 64.0
	add_child(_view)
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--ribbon-opacity="): opacity_scale = float(arg.get_slice("=", 1))
		if arg.begins_with("--ribbon-width="): width_scale = float(arg.get_slice("=", 1))
		if arg.begins_with("--ribbon-glow="): glow = float(arg.get_slice("=", 1))
		if arg.begins_with("--wake="): wake_gain = float(arg.get_slice("=", 1))
		if arg.begins_with("--sweeps="): sweep_gain = float(arg.get_slice("=", 1))
		if arg == "--ribbon-debug": _material.set_shader_parameter("debug_view", 1)

func _process(_delta: float) -> void:
	if _material != null: _material.set_shader_parameter("glow", glow)

func set_canopy(probe: Callable) -> void:
	canopy = probe

func set_bounds(middle: Vector2, reach: float) -> void:
	center = middle
	radius = maxf(reach, 4.0)

## Bring ribbons in along a gust front: they join its line where it enters
## the plate and ride at its pace.
func carry_front(front: Dictionary) -> void:
	if front.is_empty(): return
	var way: Vector2 = front.way
	var side := Vector2(-way.y, way.x)
	var origin: Vector2 = front.origin
	var join := center - way * radius * JOIN
	var delay := maxf((join - origin).dot(way), 0.0) / float(front.speed)
	var count := _rng.randi_range(PER_FRONT.x, PER_FRONT.y)
	var swept := _rng.randi_range(0, count - 1) if _rng.randf() < SWEEP_CHANCE * sweep_gain else -1
	var half := minf(float(front.half), radius) * 0.8
	var line := (join - origin).dot(side)
	for i in range(count):
		var across := line + lerpf(-half, half, (float(i) + _rng.randf_range(0.2, 0.8)) / float(count))
		var at := origin + way * (join - origin).dot(way) + side * across
		_pending.append({"at": at, "when": _clock + delay + _rng.randf_range(-0.4, 0.6), "speed": float(front.speed), "power": float(front.power),
			"sweep": _rng.randf_range(SWEEP_DELAY.x, SWEEP_DELAY.y) if i == swept else -1.0})

func advance(delta: float, strength: float, angle: float) -> void:
	if delta <= 0.0 or not is_finite(delta) or not ground_height.is_valid(): return
	var way := Vector2(cos(angle), sin(angle))
	_carry += minf(delta, 0.25)
	while _carry >= STEP:
		_carry -= STEP
		_step(way, clampf(strength, 0.0, 3.0))
	_draw()
	publish()

func _step(way: Vector2, power: float) -> void:
	_clock += STEP
	for i in range(_pending.size() - 1, -1, -1):
		var p: Dictionary = _pending[i]
		if _clock >= float(p.when):
			_pending.remove_at(i)
			_birth(p.at, way, float(p.speed), 0.75 + 0.35 * float(p.power), float(p.get("sweep", -1.0)))
	_until_lone -= STEP
	if _until_lone <= 0.0:
		_until_lone = _rng.randf_range(LONE_GAP.x, LONE_GAP.y) / clampf(0.7 + 0.75 * power, 0.7, 2.0)
		var side := Vector2(-way.y, way.x)
		_birth(center - way * radius * JOIN + side * _rng.randf_range(-0.6, 0.6) * radius, way, 3.6 + 2.2 * power, 0.6)
	for i in range(ribbons.size() - 1, -1, -1):
		var r: Dictionary = ribbons[i]
		_move(r, way)
		if float(r.fade) <= 0.0:
			ribbons.remove_at(i)

## `sweep_after` is the seconds from its birth a ribbon waits before it takes
## a sweep (negative: it is not given one).
func _birth(at: Vector2, way: Vector2, speed: float, weight: float, sweep_after := -1.0) -> void:
	if ribbons.size() >= capacity: return
	var ground: Variant = ground_height.call(at)
	var ride := _rng.randf_range(RIDE.x, RIDE.y)
	var y := (float(ground) if ground != null else 0.0) + ride
	var pos := Vector3(at.x, y, at.y)
	ribbons.append({
		"pos": pos,
		"vel": Vector3(way.x, 0.0, way.y) * speed,
		"speed": speed,
		"ride": ride,
		"ground": float(ground) if ground != null else 0.0,
		"seed": _rng.randf() * 100.0,
		"age": 0.0,
		"tail": _rng.randf_range(TAIL.x, TAIL.y),
		"width": _rng.randf_range(WIDTH.x, WIDTH.y),
		"weight": weight,
		"fade": 1.0,
		"dying": false,
		"since": 0.0,
		"path": PackedVector3Array([pos]),
		"eddy": {},
		"sweep": {},
		"sweep_wait": sweep_after if sweep_gain > 0.0 else -1.0,
		"sweep_tries": 6,
		"id": _next_id,
	})
	_next_id += 1

## Where the air carries a mote at `r.pos`: downwind at its speed, meandering
## across, climbing to ride over the ground ahead, swelling and sinking, and
## through an eddy's loop when one has it.
func flow(r: Dictionary, way: Vector2) -> Vector3:
	var pos: Vector3 = r.pos
	var speed := float(r.speed)
	var seed := float(r.seed)
	var t := float(r.age)
	var side := Vector2(-way.y, way.x)
	var p2 := Vector2(pos.x, pos.z)
	var wander := (_noise(p2 * MEANDER_SCALE + Vector2(seed, _clock * MEANDER_PACE)) - 0.5) * 2.0
	var level := Vector2(way.x, way.y) * speed + side * wander * MEANDER
	var sweep: Dictionary = r.sweep
	# Low in a sweep it runs faster, and so reads the ground further ahead.
	var low := _sweep_low(sweep)
	var quick := lerpf(1.0, SWEEP_FAST, low)
	level *= quick
	var heading := Vector2((r.vel as Vector3).x, (r.vel as Vector3).z)
	heading = heading.normalized() if heading.length_squared() > 0.01 else way
	var ground := -INF
	for s: float in LOOK_AHEAD:
		var at := p2 + heading * speed * quick * s
		var h: Variant = ground_height.call(at)
		if h != null: ground = maxf(ground, float(h) + _canopy_lift(at))
	if ground == -INF: ground = float(r.ground)
	r.ground = ground
	var swell := SWELL.x * sin(TAU * t / SWELL.y + seed)
	var target := ground + float(r.ride) + swell
	if not sweep.is_empty(): target = lerpf(target, ground + float(sweep.height), low)
	var eddy: Dictionary = r.eddy
	# In an eddy the air lets go of its height for the loop.
	var k := clampf(float(eddy.t) / float(eddy.span), 0.0, 1.0) if not eddy.is_empty() else 0.0
	var climb := (target - pos.y) * (CLIMB if target > pos.y else SETTLE) * (1.0 - sin(PI * k))
	var bob := SWELL.x * TAU / SWELL.y * cos(TAU * t / SWELL.y + seed)
	var lift := 0.0
	if not sweep.is_empty():
		# Low, it holds its height closely both ways and stops its swell; in
		# the lift it lets go of height for the curl.
		lift = _sweep_lift(sweep)
		climb = (target - pos.y) * lerpf(CLIMB if target > pos.y else SETTLE, SWEEP_PULL, low) * (1.0 - sin(PI * lift))
		bob *= 1.0 - low
	var v := Vector3(level.x, climb + bob, level.y)
	if not eddy.is_empty():
		var turn := TAU * smoothstep(0.0, 1.0, k) * float(eddy.spin)
		var axis: Vector3 = eddy.axis
		v = v.rotated(axis, turn) * lerpf(1.0, 0.75, sin(PI * k))
	if lift > 0.0:
		# The lift tips the path up, in the upright plane along its way: it
		# climbs steeply, then flattens as it eases back to its ride.
		var along := Vector3(level.x, 0.0, level.y).normalized()
		v = v.rotated(along.cross(Vector3.UP).normalized(), SWEEP_PITCH * sin(PI * lift))
	return v

func _move(r: Dictionary, way: Vector2) -> void:
	r.age = float(r.age) + STEP
	r.since = float(r.since) + STEP
	var eddy: Dictionary = r.eddy
	_sweeping(r)
	if eddy.is_empty() and (r.sweep as Dictionary).is_empty():
		if not bool(r.dying) and float(r.age) > 1.0 and _rng.randf() < EDDY_RATE * STEP:
			# Upright loops always rise first (never dive into the ground);
			# flat swirls turn either way.
			var flat := _rng.randf()
			var along := Vector3(way.x, 0.0, way.y)
			var upright := along.cross(Vector3.UP).normalized()
			r.eddy = {"t": 0.0, "span": _rng.randf_range(EDDY_TIME.x, EDDY_TIME.y), "spin": 1.0 if flat < 0.5 or _rng.randf() < 0.5 else -1.0,
				"axis": upright.slerp(Vector3.UP, flat * flat).normalized()}
		# A sweep never starts mid-eddy, nor an eddy mid-sweep.
		if (r.eddy as Dictionary).is_empty() and (r.sweep as Dictionary).is_empty() and float(r.age) > 1.0 \
				and _rng.randf() < SWEEP_RATE * sweep_gain * STEP:
			start_sweep(r)
	elif not eddy.is_empty():
		eddy.t = float(eddy.t) + STEP
		if float(eddy.t) >= float(eddy.span): r.eddy = {}
	var v := flow(r, way)
	r.vel = (r.vel as Vector3).lerp(v, 1.0 - exp(-STEP * 6.0))
	r.pos = (r.pos as Vector3) + (r.vel as Vector3) * STEP
	var path: PackedVector3Array = r.path
	if float(r.since) >= SAMPLE:
		r.since = 0.0
		path.append(r.pos)
		var keep := int(ceil(float(r.tail) / SAMPLE)) + 1
		if path.size() > keep: path = path.slice(path.size() - keep)
	else:
		path[path.size() - 1] = r.pos
	r.path = path
	_keep_above_ground(r)
	_kicks_stale = true
	var p2 := Vector2((r.pos as Vector3).x, (r.pos as Vector3).z)
	if not bool(r.dying) and (p2 - center).length() > radius * 1.05:
		r.dying = true
	if bool(r.dying): r.fade = float(r.fade) - STEP / 0.9

## Begin a sweep on ribbon `r`: it descends to skim the ground, then lifts
## off in a curl. Only in the open: not while dying, in an eddy or already
## sweeping, nor with trees' shade on the ground it would cross. Returns
## whether it began.
func start_sweep(r: Dictionary) -> bool:
	if sweep_gain <= 0.0 or bool(r.dying) or not (r.eddy as Dictionary).is_empty() or not (r.sweep as Dictionary).is_empty(): return false
	var pos: Vector3 = r.pos
	var span := SWEEP_DESCEND.y + SWEEP_SKIM.y
	var heading := Vector2((r.vel as Vector3).x, (r.vel as Vector3).z)
	if heading.length_squared() < 0.01: return false
	heading = heading.normalized()
	# Open ground wherever it runs low (down and skim; the lift clears trees
	# on its own), on the plate: past its rim there is nothing to hit.
	for s in range(7):
		var at := Vector2(pos.x, pos.z) + heading * float(r.speed) * SWEEP_FAST * span * float(s) / 6.0
		if ground_height.call(at) != null and _canopy_lift(at) > 0.0: return false
	r.sweep = {"t": 0.0, "descend": _rng.randf_range(SWEEP_DESCEND.x, SWEEP_DESCEND.y), "skim": _rng.randf_range(SWEEP_SKIM.x, SWEEP_SKIM.y),
		"lift": _rng.randf_range(SWEEP_LIFT.x, SWEEP_LIFT.y), "height": _rng.randf_range(SWEEP_HEIGHT.x, SWEEP_HEIGHT.y)}
	_kicks_stale = true
	return true

## Run a ribbon's sweep clock, and start the one it was given when its wait is
## up (trying again a few times if an eddy or shade is in the way).
func _sweeping(r: Dictionary) -> void:
	var sweep: Dictionary = r.sweep
	if not sweep.is_empty():
		sweep.t = float(sweep.t) + STEP
		if float(sweep.t) >= float(sweep.descend) + float(sweep.skim) + float(sweep.lift): r.sweep = {}
		return
	var wait := float(r.sweep_wait)
	if wait < 0.0: return
	wait -= STEP
	if wait > 0.0:
		r.sweep_wait = wait
	elif start_sweep(r):
		r.sweep_wait = -1.0
	else:
		r.sweep_tries = int(r.sweep_tries) - 1
		r.sweep_wait = 0.5 if int(r.sweep_tries) > 0 else -1.0

## How close to the ground a sweep holds the ribbon, 0 to 1: eased in over
## the descent, full through the skim, and let go over the lift's first part.
func _sweep_low(sweep: Dictionary) -> float:
	if sweep.is_empty(): return 0.0
	var t := float(sweep.t)
	var down := smoothstep(0.0, 1.0, t / float(sweep.descend))
	return down * (1.0 - smoothstep(0.0, 0.25, _sweep_lift(sweep)))

## How far through the lift a sweep is, 0 to 1 (0 before it begins).
func _sweep_lift(sweep: Dictionary) -> float:
	var t := float(sweep.t) - float(sweep.descend) - float(sweep.skim)
	return clampf(t / float(sweep.lift), 0.0, 1.0)

## A sweep never takes the head below the ground, however the ground ahead
## falls or rises under the lag of its climb.
func _keep_above_ground(r: Dictionary) -> void:
	if (r.sweep as Dictionary).is_empty(): return
	var pos: Vector3 = r.pos
	var h: Variant = ground_height.call(Vector2(pos.x, pos.z))
	if h != null and pos.y < float(h) + 0.1:
		pos.y = float(h) + 0.1
		r.pos = pos
		if (r.vel as Vector3).y < 0.0: r.vel = Vector3((r.vel as Vector3).x, 0.0, (r.vel as Vector3).z)

## Every ribbon whose sweep has its head near the ground or lifting off it:
## the ground point under it (`at`), its velocity, how far into the lift-off
## it is (`lift`, 0 skimming to 1 at its strongest), how hard it kicks
## (`strength`, 0 to 1, eased so nothing pops) and a stable `id`. For the
## grass blades and leaves that answer it. Empty when disabled.
func kicks() -> Array[Dictionary]:
	if _kicks_stale:
		_kicks_stale = false
		_kicks.clear()
		if enabled:
			for r in ribbons:
				var sweep: Dictionary = r.sweep
				if sweep.is_empty(): continue
				var pos: Vector3 = r.pos
				var ground: Variant = ground_height.call(Vector2(pos.x, pos.z))
				if ground == null: continue
				var above := pos.y - float(ground)
				var k := _sweep_lift(sweep)
				var strength := 1.0
				if k > 0.0:
					# Lifting off: strongest as it leaves, then it lets go.
					strength = (1.0 - smoothstep(0.6, 1.0, k)) * (1.0 - smoothstep(2.0, 5.0, above))
				elif above > KICK_NEAR: continue
				elif float(sweep.t) < float(sweep.descend):
					strength = 1.0 - smoothstep(0.2, KICK_NEAR, above)
				strength *= clampf(float(r.fade), 0.0, 1.0)
				if strength <= 0.0: continue
				_kicks.append({"at": Vector3(pos.x, float(ground), pos.z), "vel": r.vel, "lift": sin(PI * k), "strength": strength, "id": int(r.id)})
	return _kicks

## Extra air (m/s) at `p` from sweeping ribbons only: along a sweep's track
## and near the ground it drags the air with it, in the lift it throws it up,
## and round the head it swirls gently. Zero when nothing sweeps or `p` is
## beyond reach. Cheap: leaves ask it every physics step.
func air_at(p: Vector3) -> Vector3:
	var list := kicks()
	if list.is_empty(): return Vector3.ZERO
	var air := Vector3.ZERO
	for kick in list:
		var at: Vector3 = kick.at
		var vel: Vector3 = kick.vel
		var d := Vector2(p.x - at.x, p.z - at.z)
		if absf(d.x) > KICK_REACH + KICK_TRAIL or absf(d.y) > KICK_REACH + KICK_TRAIL: continue
		var h := maxf(p.y - at.y, 0.0)
		var low := 1.0 - smoothstep(0.4, 2.0, h)
		if low <= 0.0: continue
		var v2 := Vector2(vel.x, vel.z)
		var run := v2.length()
		if run < 0.01: continue
		var unit := v2 / run
		# Distance to the track: the head and the trail behind it.
		var back := clampf(d.dot(-unit), 0.0, KICK_TRAIL)
		var gap := (d + unit * back).length()
		if gap >= KICK_REACH: continue
		var reach := (1.0 - smoothstep(0.3, KICK_REACH, gap)) * low * float(kick.strength)
		var push := v2 * KICK_DRAG * reach
		var up := KICK_UPDRAFT * float(kick.lift) * reach
		# Swirl round the head: tangent to the circle about it, close in.
		var head := d.length()
		if head > 0.01 and head < 0.9:
			var swirl := Vector2(-d.y, d.x) / head * KICK_SWIRL * (1.0 - smoothstep(0.2, 0.9, head)) * low * float(kick.strength)
			push += swirl
		air += Vector3(push.x, up, push.y)
	return air

## Metres the trees lift the air at `p`: a full canopy CANOPY, none in the open.
func _canopy_lift(p: Vector2) -> float:
	if not canopy.is_valid(): return 0.0
	return CANOPY * smoothstep(0.05, 0.4, float(canopy.call(p)))

## Publish each ribbon's head for the plants it passes over: x, z and its
## way scaled by how strongly it bows them (0 for a free slot), and its
## height above the ground in a fifth float per slot (zs_ribbon_lift).
func publish() -> void:
	var lift := Vector4.ZERO
	var lift_b := Vector4.ZERO
	heads.clear()
	for i in range(CAPACITY):
		var head := Vector4.ZERO
		if i < ribbons.size():
			var r: Dictionary = ribbons[i]
			var pos: Vector3 = r.pos
			var v := Vector2((r.vel as Vector3).x, (r.vel as Vector3).z)
			var strength := WAKE * wake_gain * float(r.weight) * smoothstep(0.0, 0.7, float(r.age)) * clampf(float(r.fade), 0.0, 1.0)
			if enabled and v.length_squared() > 0.01:
				var unit := v.normalized()
				head = Vector4(pos.x, pos.z, unit.x * strength, unit.y * strength)
				var above := pos.y - float(r.ground)
				if i < 4: lift[i] = above
				else: lift_b[i - 4] = above
		heads.append(head)
		RenderingServer.global_shader_parameter_set("zs_ribbon_%d" % i, head)
	RenderingServer.global_shader_parameter_set("zs_ribbon_lift_a", lift)
	RenderingServer.global_shader_parameter_set("zs_ribbon_lift_b", lift_b)

## Rebuild the strokes: each ribbon's path as a strip of centre points; the
## shader turns it to face the camera and paints it.
func _draw() -> void:
	_mesh.clear_surfaces()
	_view.visible = enabled
	if not enabled: return
	var any := false
	for r in ribbons:
		if (r.path as PackedVector3Array).size() >= 3:
			any = true
			break
	if not any: return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in ribbons:
		var path: PackedVector3Array = r.path
		var n := path.size()
		if n < 3: continue
		var born := smoothstep(0.0, 0.7, float(r.age))
		var alpha := OPACITY * opacity_scale * float(r.weight) * born * clampf(float(r.fade), 0.0, 1.0)
		var metres := 0.0
		var along: PackedFloat32Array = [0.0]
		for i in range(1, n):
			metres += path[i].distance_to(path[i - 1])
			along.append(metres)
		var total := maxf(metres, 0.001)
		var prev_l := Vector3.ZERO
		for i in range(n):
			var tangent := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)])
			if tangent.length_squared() < 1e-8: tangent = r.vel
			tangent = tangent.normalized()
			# 0 at the tail, 1 at the head; metres from the head.
			var u := along[i] / total
			var size := Vector2(float(r.width) * width_scale, alpha)
			if i > 0:
				var a := [path[i - 1], path[i]]
				var ua := [along[i - 1] / total, u]
				var ta: Array = [prev_l, tangent]
				for corner in [[0, 0.0], [1, 0.0], [1, 1.0], [0, 0.0], [1, 1.0], [0, 1.0]]:
					var j: int = corner[0]
					_mesh.surface_set_normal(ta[j])
					_mesh.surface_set_uv(Vector2(total - along[i - 1 + j], corner[1]))
					# Width and opacity ride UV2: vertex colour is taken as
					# sRGB and would be darkened on its way to the shader.
					_mesh.surface_set_uv2(size)
					_mesh.surface_set_color(Color(0.0, 0.0, float(r.seed) * 0.01, ua[j]))
					_mesh.surface_add_vertex(a[j])
			prev_l = tangent
	_mesh.surface_end()

## The shaders' value noise (zs_noise).
func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	return lerpf(lerpf(_hash(i), _hash(i + Vector2(1, 0)), f.x), lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), f.x), f.y)

static func _hash(p: Vector2) -> float:
	var v := sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453
	return v - floorf(v)
