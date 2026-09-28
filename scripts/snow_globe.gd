extends Node
## Shaking the diorama like a snow globe (docs/scenic/hand-snow-globe.md).
##
## Grab the rim and shake: the diorama jiggles in the hand, and it snows in
## winter and rains otherwise, as much as the shake was hard and long. Let go
## and the jiggle rings down while the fall thins away by itself; nothing is
## switched on or off.
##
## The mouse drives and the hand interprets: there is no gesture to perform.
## A shake is an ordinary drag that keeps turning back on itself quickly. The
## drag is projected on its own main axis, and every turn that ends a quick
## stroke (MIN_STROKE travel within MAX_STROKE seconds, at MIN_SPEED or more)
## is counted; STROKES of them within WINDOW make it a shake. A slow drag
## along the rim never turns, or turns too slowly, so it never counts.
##
## How hard it shakes (`vigour`, the drag's smoothed speed) stirs the fall up
## (`airborne`), which settles out on its own over SNOW_SETTLE or
## RAIN_SETTLE seconds: a gentle shake lifts a few flakes, a firm one a
## flurry, a long firm one a storm. The fall is the precipitation's second
## channel (studies/precipitation.gd `state.y`, added to the sky's own rain),
## so the world's cold decides whether it falls as snow or rain, and the
## ground whitens or wets under it as it would under any other weather.
##
## The jiggle moves the camera, not the diorama: the tremor
## (scripts/reference_tremor.gd `jiggle`) moves the view the other way, so the
## whole world moves together on screen, with the hand on its rim, while the
## terrain, water, creatures and physics never move. The diorama follows the
## drag's quick part (a steady drag barely moves it) on an underdamped spring,
## so it lags a touch like something heavy and rings down after.
##
## The hand (scripts/god_hand.gd, may be absent with --no-hand) grips the
## rim's lip with the Shake clips while it is held, shakes faster the harder
## the drag shakes, and lets go on release.
##
## The API is independent of how the rim is grabbed: `grab(screen_pos)`,
## `feed(screen_delta, delta) -> bool` and `release()`. Until
## scripts/hand_reach.gd lands, a minimal rim grab of its own drives it (see
## "Temporary rim grab" below).

## Emitted once a grab has turned into a shake.
signal shake_started

## A stroke must travel this far along the shake's axis (screen heights) ...
const MIN_STROKE := 0.012
## ... in at most this many seconds ...
const MAX_STROKE := 0.45
## ... at this average speed or more (screen heights per second) to count.
const MIN_SPEED := 0.12
## Travel back against a stroke (screen heights) that turns it: less is jitter.
const TURN_SLOP := 0.005
## Counted turns within WINDOW seconds that make a shake.
const STROKES := 2
const WINDOW := 1.1
## Seconds the shake's main axis is averaged over.
const AXIS_TIME := 0.25
## Seconds a shake keeps stirring after its last counted turn.
const LIVELY := 0.5
## Seconds the drag's speed is smoothed over.
const VIGOUR_TIME := 0.12
## Drag speeds (screen heights per second) of a gentle and a firm shake; the
## shake's strength runs 0..1 between them.
const GENTLE := 0.08
const FIRM := 1.8
## The strength is raised to this power, so a gentle shake does little.
const STIR_CURVE := 1.5
## Share of the loose fall lifted per second by a full-strength shake.
const STIR := 0.8
## Seconds (time constant) the airborne fall takes to settle out: snow
## drifts down slowly, rain is gone sooner. Mixed by the world's cold.
const SNOW_SETTLE := 9.0
const RAIN_SETTLE := 4.0
## How quickly (1/s) the fall builds toward what is airborne.
const GATHER := 4.0
## Precipitation amount (0..1, as the weather profiles') of a fully stirred globe.
const FLURRY := 0.85
## Below this amount the fall is over.
const DONE := 0.003
## Seconds the drag is high-passed over for the jiggle: a steady drag leaves
## about its speed times this.
const PULL_TIME := 0.12
## Share of that quick drag the diorama follows, held and at a full-strength
## shake (by the square root of the strength, so a gentle shake stirs it a little).
const PULL_GAIN := Vector2(0.15,0.45)
## The jiggle's spring: frequency (Hz) and damping ratio.
const JIGGLE_HZ := 3.5
const JIGGLE_DAMPING := 0.25
## Most the diorama moves on screen (screen heights).
const MAX_JIGGLE := 0.06
## Radians the diorama rolls per screen height it moves sideways.
const ROCK := 0.35
## How fast the hand's ShakeHold plays, holding still and at a firm shake.
const PACE := Vector2(0.35,1.6)
## The plate's half size and the earth block's lip beyond it (m, plate space),
## and how far in from the edge the plate's top counts as rim.
const EDGE := 14.0
const LIP := 0.2
const RIM_BAND := 1.5
## A grip keeps this far (m) from a corner.
const CORNER := 1.2

var scene: Node3D
var editor: Node
## The rim is held, and the grab has been judged a shake.
var grabbed := false
var decided := false
## Where the hand holds the rim (plate space, on the lip) and the way in
## across it (horizontal, plate space).
var rim_point := Vector3.ZERO
var rim_inward := Vector3.FORWARD
## The drag's smoothed speed (screen heights per second) and the shake's
## strength from it (0..1, 0 unless it is shaking).
var vigour := 0.0
var strength := 0.0
## The loose fall in the air (0..1) and the fall shown (0..1 of FLURRY).
var airborne := 0.0
var fall := 0.0
## The jiggle: offset (screen heights, x right, y down) and its rate.
var jiggle := Vector2.ZERO
var jiggle_speed := Vector2.ZERO
## While true, a grab shows the hand gripping at once; at merge, when the
## rim grab turns the season dial, set it false so the hand only shakes once
## a shake is decided.
var claim_grip := true
var _pull := Vector2.ZERO
var _gain := 0.0
var _travel := 0.0
var _lively := 0.0
var _clock := 0.0
## The shake's axis as a running second moment (xx, xy, yy) and its unit
## direction, the position along it, the stroke's start, extreme, sign and
## age, and the times of counted turns.
var _moment := Vector3.ZERO
var _axis := Vector2.RIGHT
var _along := 0.0
var _stroke_start := 0.0
var _extreme := 0.0
var _sign := 0
var _stroke_age := 0.0
var _turns: Array[float] = []
var _written := false
var _fed := false
var _hand_set := false
var _last_feed := 0
var _seam_grab := false

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	name = "SnowGlobe"
	# Before the scene applies the tremor to the camera and eases the weather.
	process_priority = -10

func _process(delta: float) -> void:
	_seam_check()
	advance(minf(delta,0.05))

## Take hold of the rim at `screen_pos`. The grip goes to the lip nearest
## what is under the pointer.
func grab(screen_pos: Vector2) -> void:
	var rim: Variant = rim_at(screen_pos)
	if rim == null: rim = _nearest_rim(screen_pos)
	rim_point = rim[0]
	rim_inward = rim[1]
	grabbed = true
	decided = false
	_turns.clear()
	_sign = 0
	_along = 0.0
	_stroke_start = 0.0
	_extreme = 0.0
	_stroke_age = 0.0
	_moment = Vector3.ZERO
	_travel = 0.0
	_lively = 0.0

## A piece of the drag while the rim is held: `screen_delta` in pixels over
## `delta` seconds. Returns true once the grab has been judged a shake.
func feed(screen_delta: Vector2, delta: float) -> bool:
	if not grabbed: return false
	var d := screen_delta/_screen_height()
	var dt := clampf(delta,0.0,0.25)
	_fed = true
	_clock += dt
	_stroke_age += dt
	_travel += d.length()
	_pull += d
	# The shake's main axis, sign-free, from the drag's recent second moment.
	var keep := exp(-dt/AXIS_TIME) if dt > 0.0 else 1.0
	_moment = _moment*keep+Vector3(d.x*d.x,d.x*d.y,d.y*d.y)
	if _moment.x+_moment.z > 1e-9:
		var axis := Vector2.from_angle(0.5*atan2(2.0*_moment.y,_moment.x-_moment.z))
		_axis = axis if axis.dot(_axis) >= 0.0 else -axis
	_along += d.dot(_axis)
	if _sign == 0:
		if absf(_along-_stroke_start) >= TURN_SLOP:
			_sign = 1 if _along > _stroke_start else -1
			_extreme = _along
	elif (_along-_extreme)*_sign > 0.0:
		_extreme = _along
	elif (_extreme-_along)*_sign >= TURN_SLOP:
		_turn()
	# A stroke that runs on is a drag, not a shake: start counting again.
	if _stroke_age > MAX_STROKE: _turns.clear()
	while not _turns.is_empty() and _clock-_turns[0] > WINDOW: _turns.pop_front()
	if not decided and _turns.size() >= STROKES:
		decided = true
		shake_started.emit()
	return decided

## Let go of the rim. The fall and the jiggle carry on and settle by themselves.
func release() -> void:
	grabbed = false
	decided = false
	_lively = 0.0
	_turns.clear()

## True while a decided shake is still being shaken.
func shaking() -> bool:
	return decided and _lively > 0.0

## "snow" or "rain": what the world's cold makes of the fall.
func kind() -> String:
	return "snow" if _snow_phase() >= 0.5 else "rain"

## The precipitation amount the shake adds (0..FLURRY).
func amount() -> float:
	return fall*FLURRY

## One step: stir and settle the fall, ring the jiggle, and drive the weather,
## the camera and the hand.
func advance(delta: float) -> void:
	if delta <= 0.0: return
	# Time passes for the strokes between feeds too: a held pause runs a
	# stroke out as surely as a slow drag.
	if not _fed and grabbed:
		_clock += delta
		_stroke_age += delta
		if _stroke_age > MAX_STROKE: _turns.clear()
	_fed = false
	var speed := _travel/delta
	_travel = 0.0
	vigour += (speed-vigour)*(1.0-exp(-delta/VIGOUR_TIME))
	_lively = maxf(_lively-delta,0.0)
	var lively := grabbed and decided and _lively > 0.0
	strength = clampf((vigour-GENTLE)/(FIRM-GENTLE),0.0,1.0) if lively else 0.0
	# The fall: a shake lifts it, the air lets it settle out.
	var settle := lerpf(RAIN_SETTLE,SNOW_SETTLE,_snow_phase())
	airborne += (STIR*pow(strength,STIR_CURVE)*(1.0-airborne)-airborne/settle)*delta
	airborne = clampf(airborne,0.0,1.0)
	fall = lerpf(fall,airborne,1.0-exp(-GATHER*delta)) if airborne > fall else airborne
	if maxf(fall,airborne)*FLURRY < DONE and not lively:
		fall = 0.0
		airborne = 0.0
	# The jiggle follows the drag's quick part on a heavy spring.
	_pull *= exp(-delta/PULL_TIME)
	_gain = move_toward(_gain,sqrt(strength),delta*4.0)
	var goal := Vector2.ZERO
	if grabbed: goal = (_pull*lerpf(PULL_GAIN.x,PULL_GAIN.y,_gain)).limit_length(MAX_JIGGLE)
	var omega := TAU*JIGGLE_HZ
	var steps := int(ceil(delta/0.004))
	var h := delta/steps
	for i in range(steps):
		jiggle_speed += (omega*omega*(goal-jiggle)-2.0*JIGGLE_DAMPING*omega*jiggle_speed)*h
		jiggle += jiggle_speed*h
	if not grabbed and jiggle.length() < 0.00005 and jiggle_speed.length() < 0.0005:
		jiggle = Vector2.ZERO
		jiggle_speed = Vector2.ZERO
	_publish()

func _turn() -> void:
	var length := absf(_extreme-_stroke_start)
	if length >= MIN_STROKE and _stroke_age <= MAX_STROKE and length/maxf(_stroke_age,0.001) >= MIN_SPEED:
		_turns.append(_clock)
		_lively = LIVELY
	else:
		_turns.clear()
	_stroke_start = _extreme
	_sign = -_sign
	_extreme = _along
	_stroke_age = 0.0

func _publish() -> void:
	var tremor: RefCounted = scene.get("_tremor")
	if tremor != null:
		var metres := 2.0*float(scene.distance)*tan(deg_to_rad(scene.camera.fov)*0.5) if scene.camera != null else 1.0
		tremor.jiggle = Vector3(jiggle.x*metres,-jiggle.y*metres,jiggle.x*ROCK)
	var precipitation: Node = scene.get("_precipitation")
	if precipitation != null and (fall > 0.0 or _written):
		precipitation.state.y = fall*FLURRY
		_written = fall > 0.0
	var hand: Node3D = scene.get("god_hand")
	if hand == null: return
	if grabbed and (decided or claim_grip):
		hand.reach_gesture = "shake"
		hand.reach_point = rim_point
		hand.reach_facing = rim_inward
		hand.reach_pace = lerpf(PACE.x,PACE.y,strength)
		_hand_set = true
	elif _hand_set:
		_hand_set = false
		if hand.reach_gesture == "shake":
			hand.reach_gesture = ""
			hand.reach_point = null
			hand.reach_facing = null
			hand.reach_pace = 1.0

func _snow_phase() -> float:
	var precipitation: Node = scene.get("_precipitation")
	return float(precipitation.surface_weather.snow_phase) if precipitation != null else 0.0

func _screen_height() -> float:
	return maxf(scene.get_viewport().get_visible_rect().size.y,1.0) if scene.is_inside_tree() else 1080.0

## The rim under `screen_pos`, as [lip point, way in] in plate space, or
## null: the earth block's walls and lip, and the plate's top within RIM_BAND
## of its edge.
func rim_at(screen_pos: Vector2) -> Variant:
	var ray: Array = _ray(screen_pos)
	if ray.is_empty(): return null
	var hit: Variant = editor.data.ray_hit(ray[0],ray[1])
	if hit != null:
		var top: Vector3 = hit
		return _lip(top) if maxf(absf(top.x),absf(top.z)) >= EDGE-RIM_BAND else null
	var block: AABB = _block()
	var entry: Variant = block.intersects_ray(ray[0],ray[1])
	if entry == null: return null
	var at: Vector3 = entry
	return _lip(at) if maxf(absf(at.x),absf(at.z)) >= EDGE-0.01 else null

## The lip nearest the pointer, for a grab the caller has already judged to
## be on the rim.
func _nearest_rim(screen_pos: Vector2) -> Array:
	var ray: Array = _ray(screen_pos)
	if ray.is_empty(): return _lip(Vector3(0.0,0.0,EDGE))
	var hit: Variant = editor.data.ray_hit(ray[0],ray[1])
	if hit == null:
		var dir: Vector3 = ray[1]
		var t := -Vector3(ray[0]).y/dir.y if absf(dir.y) > 0.0001 else 0.0
		hit = Vector3(ray[0])+dir*maxf(t,0.0)
	return _lip(hit)

## The lip point on the side of the plate nearest `at`, and the way in.
func _lip(at: Vector3) -> Array:
	var out := Vector3(signf(at.x),0.0,0.0) if absf(at.x) >= absf(at.z) else Vector3(0.0,0.0,signf(at.z))
	if out == Vector3.ZERO: out = Vector3.BACK
	var along := Vector3(out.z,0.0,-out.x).abs()
	var slide := clampf(at.dot(along),-EDGE+CORNER,EDGE-CORNER)
	var edge := along*slide+out*(EDGE-0.02)
	var height: Variant = editor.data.ground_height(Vector2(edge.x,edge.z))
	var point := along*slide+out*(EDGE+LIP)
	point.y = float(height) if height != null else at.y
	return [point,-out]

## The pointer's ray in plate space: [origin, direction], or [] off the world.
func _ray(screen_pos: Vector2) -> Array:
	var camera: Camera3D = scene.camera
	if camera == null or editor == null or editor.terrain == null: return []
	var terrain: Node3D = editor.terrain
	var origin := terrain.to_local(camera.project_ray_origin(screen_pos))
	var direction := (terrain.global_basis.inverse()*camera.project_ray_normal(screen_pos)).normalized()
	return [origin,direction]

## The earth block the plate sits on, in plate space.
func _block() -> AABB:
	var skirt: Variant = editor.get("_skirt")
	var terrain: Node3D = editor.terrain
	if skirt is MeshInstance3D and skirt.mesh != null:
		return terrain.global_transform.affine_inverse()*skirt.global_transform*skirt.get_aabb()
	return AABB(Vector3(-EDGE-LIP,-4.0,-EDGE-LIP),Vector3(2.0*(EDGE+LIP),4.0,2.0*(EDGE+LIP)))

# ---------------------------------------------------------------- Temporary rim grab
# TEMPORARY until scripts/hand_reach.gd lands: it owns the rim grab and will
# call grab() on rim_grabbed, feed() on rim_dragged and release() on
# rim_released. At merge, delete from here to the end of the file (and the
# input it takes) and connect those signals instead.

## Whether a left press at `screen_pos` takes hold of the rim.
func _is_rim(screen_pos: Vector2) -> bool:
	if editor == null or not editor.pointer_in_world(screen_pos): return false
	return rim_at(screen_pos) != null

## A press on the rim is the hand's, not the camera's or the brush's.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not grabbed:
		if _is_rim(event.position):
			grab(event.position)
			_seam_grab = true
			_last_feed = Time.get_ticks_usec()
			get_viewport().set_input_as_handled()

## While held, the drag is read before the controls, so it carries on across
## a panel, as the camera's orbit does.
func _input(event: InputEvent) -> void:
	if not grabbed: return
	if event is InputEventMouseMotion:
		var now := Time.get_ticks_usec()
		feed(event.relative,(now-_last_feed)/1000000.0)
		_last_feed = now
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_seam_grab = false
		release()

## A release lost outside the window still lets go.
func _seam_check() -> void:
	if _seam_grab and grabbed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_seam_grab = false
		release()
