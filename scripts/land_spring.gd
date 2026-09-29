extends Node
## The land spring (docs/scenic/modeless-spring.md, docs/scenic/hand-world.md
## "Verbs on the diorama"). The land is a spring: press it, pull toward the
## bottom of the screen and let go, and a mountain springs up; pull the other
## way and let go, and it springs down into a basin for a lake. How far you
## pull decides how much.
##
## - **Tension.** While the button is held the land itself answers: a small
##   pucker at the spot for a mountain, a dimple for a basin, growing with the
##   pull and trembling harder as it nears the cap. Only the points near the
##   press are written, on the editor's light refresh, so it costs a frame
##   about what a brush dab does. The hand pinches the spot (a press for the
##   basin) through `reach_gesture` and `reach_point` (scripts/god_hand.gd).
## - **Release.** A mountain's final form is built once, from the existing
##   mountain machinery (scripts/mountain_forms.gd) at a spread and height set
##   by the pull. A basin's is a bowl dug below the ground round the spot. A
##   scale `x` on that shape then runs a real spring, `x'' = -w²(x-1) -
##   2·z·w·x'`, kicked at release, so the land overshoots, rings down and
##   settles. The mountain lands as any mountain does (`_land_mountain`: its
##   weathering and rock on a worker, emergence told), and the whole thing,
##   tension included, is one undo step.
## - **Small pulls.** Under DEAD nothing shows; under MIN_PULL the land relaxes
##   back with a small wobble and nothing is kept. So a click, or a pull that
##   returns to the start, changes nothing.
##
## The input comes from the modeless press (scripts/hand_reach.gd): its
## `land_pressed`, `land_dragged` and `land_released` call `press`, `pull` and
## `release` (connected in studies/fidelity.gd).

const Mountains = preload("res://scripts/mountain_forms.gd")

## Emitted when a spring is kept: `kind` is "mountain" or "basin", `size` the
## pull it was let go at, 0..1.
signal sprung(kind: String, size: float)

## A pull this fraction of the viewport's height (top to bottom) is the cap.
const PULL_SCREEN := 0.32
## Pulls (fraction of the cap) under DEAD show nothing; under MIN_PULL let go
## keeps nothing.
const DEAD := 0.03
const MIN_PULL := 0.12
## How quickly (1/s) the shown tension follows the pull.
const TENSION_FOLLOW := 20.0
## The tension's pucker: peak height in metres and radius in metres, from a
## small pull to the cap.
const BULGE_HEIGHT := Vector2(0.10,0.85)
const BULGE_RADIUS := Vector2(1.1,2.8)
## A basin's dimple while held is this share of the bowl the pull would dig.
const DIMPLE := 0.4
## The tremble: share of the tension's height it trembles by at the cap, and
## its rate in radians per second.
const TREMBLE := 0.12
const TREMBLE_RATE := 34.0
## The mountain's spread in metres, from a small pull to the cap (the form's
## own limits are 3 and 9.5), and the form used. Its height follows the spread.
const MOUNTAIN_SPREAD := Vector2(3.4,7.2)
const MOUNTAIN_FORM := "alpine"
## The basin's radius and depth in metres below its rim level, small pull to
## cap. The floor never goes below FLOOR.
const BASIN_RADIUS := Vector2(2.2,5.0)
const BASIN_DEPTH := Vector2(0.4,1.1)
const FLOOR := -1.2
## The bowl keeps its full depth inside this share of the radius and eases to
## nothing at the rim; its rim level is the mean ground over the outer ring
## (RIM_RING to 1 of the radius).
const BOWL_FLAT := 0.3
const BOWL_EDGE := 0.75
const RIM_RING := 0.85
## The plate's last metres, where the shape fades to nothing (as the mountain
## forms' EDGE).
const EDGE := Vector2(11.4,13.6)
## The spring: angular frequency (rad/s) and damping ratio for each kind
## (under 1 rings; 0.4 overshoots about a quarter), and
## the speed (per second, on the shape's scale) the release kicks it with.
const OMEGA := 12.5
const ZETA := {"mountain":0.4,"basin":0.4}
const KICK := 4.0
## Integration substep, seconds, so a long frame cannot blow the spring up.
const SUBSTEP := 1.0/240.0
## The spring is at rest when it is this close to its target (on the shape's
## scale) and slower than REST_SPEED, or after MAX_SPRING seconds.
const REST := 0.004
const REST_SPEED := 0.03
const MAX_SPRING := 3.5
## Metres of ground round the press that tension and basins may touch.
const REACH := 5.2

enum State { IDLE, PULLING, SPRINGING }

var scene: Node3D
var editor: NativeChunkEditor
var state := State.IDLE
## "mountain" (pulled down) or "basin" (pulled up) while a pull is on.
var kind := ""
## The signed pull, -1..1 of the cap, down positive: what the fingers did
## (`pulled`) and what the land shows (`shown`, following it).
var pulled := 0.0
var shown := 0.0
## The spring's shape scale, its speed and its target (1 kept, 0 relaxed).
var spring_x := 0.0
var spring_v := 0.0
var spring_target := 1.0
var spring_seconds := 0.0
## The most the shape's scale has reached, for the probe.
var spring_peak := 0.0
var center := Vector2.ZERO
## Frames since press, seconds and light refreshes shown, for the probe.
var elapsed := 0.0
var refreshes := 0
## Whether the temporary input seam is on, and whether it started this pull.

var _press := Vector2.ZERO
var _base := PackedFloat32Array()
var _near := PackedInt32Array()
var _near_d := PackedFloat32Array()
var _first_id := 0
var _size := 0.0
var _keep_kind := ""
var _shape_idx := PackedInt32Array()
var _shape_lift := PackedFloat32Array()
var _bulge := PackedFloat32Array()
var _region := Rect2()
var _landing := false

## The flag every part of the modeless scheme sits behind.
static func enabled() -> bool:
	return "--modeless" in OS.get_cmdline_user_args()

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = owner_scene._chunk_editor
	editor.spring = self
	name = "LandSpring"

# --- The seam the modeless input drives -------------------------------------------

## A press on the land at `screen_pos`. False when it is not on the land or
## the editor cannot take it.
func press(screen_pos: Vector2) -> bool:
	if editor == null or editor.forming or not editor.active: return false
	land_now()
	var hit: Variant = editor.pick(screen_pos)
	if hit == null: return false
	# Anything still landing lands first, as a brush press would.
	editor._land_mountain()
	var data := editor.data
	center = Vector2(hit.x,hit.z)
	_press = screen_pos
	# Opening the step first joins any weathering still landing, so the base
	# is the ground as it now stands.
	data.begin_stroke()
	_base = data.heights.duplicate()
	_first_id = data.next_id
	_gather(data)
	state = State.PULLING
	kind = ""
	pulled = 0.0
	shown = 0.0
	elapsed = 0.0
	refreshes = 0
	spring_peak = 0.0
	_keep_kind = ""
	_region = Rect2(center-Vector2.ONE*REACH,Vector2.ONE*REACH*2.0)
	editor._emit_stroke(0,Vector3(hit.x,hit.y,hit.z),BULGE_RADIUS.y,0.0)
	_hand("pinch")
	return true

## The pointer moved to `screen_pos` (`relative` since the last event).
func pull(screen_pos: Vector2, _relative := Vector2.ZERO) -> void:
	if state != State.PULLING: return
	var span := maxf(scene.get_viewport().get_visible_rect().size.y*PULL_SCREEN,1.0)
	pulled = clampf((screen_pos.y-_press.y)/span,-1.0,1.0)

## The button came up at `screen_pos`: spring, or relax if the pull was tiny.
func release(screen_pos: Vector2 = Vector2.INF) -> void:
	if state != State.PULLING: return
	if screen_pos != Vector2.INF: pull(screen_pos)
	_size = absf(pulled)
	_hand("")
	if _size < MIN_PULL:
		spring_target = 0.0
		spring_x = 1.0
		spring_v = 0.0
		_keep_kind = ""
		_relax_start()
		return
	_keep_kind = "mountain" if pulled > 0.0 else "basin"
	_build_shape(_keep_kind,_size)
	spring_target = 1.0
	spring_x = 0.0
	spring_v = KICK
	spring_seconds = 0.0
	state = State.SPRINGING
	spring_peak = 0.0
	if _keep_kind == "mountain": editor._mountain_feel(0)

## Land whatever is springing at once (undo, a new press, a world change).
## A pull still held is cancelled.
func land_now() -> void:
	match state:
		State.PULLING:
			_hand("")
			_relax_start()
			_finish_relax()
		State.SPRINGING:
			spring_x = spring_target
			spring_v = 0.0
			_apply(spring_x)
			_end_spring()

# --- Frame loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	match state:
		State.PULLING:
			_tension(delta)
		State.SPRINGING: _spring(delta)

## Follow the pull and show its tension on the land.
func _tension(delta: float) -> void:
	elapsed += delta
	var goal := pulled if absf(pulled) >= DEAD else 0.0
	shown = lerpf(shown,goal,1.0-exp(-TENSION_FOLLOW*delta))
	var next := "" if absf(shown) < 0.004 else ("mountain" if shown > 0.0 else "basin")
	if next != kind:
		kind = next
		_hand("" if kind.is_empty() else ("pinch" if kind == "mountain" else "press"))
	var amount := absf(shown)
	if not kind.is_empty(): _hand_pace(1.0+1.5*amount)
	var data := editor.data
	var heights := data.heights
	var tremble := 1.0+TREMBLE*amount*amount*sin(elapsed*TREMBLE_RATE)
	if kind == "mountain":
		var height := lerpf(BULGE_HEIGHT.x,BULGE_HEIGHT.y,amount)*tremble
		var reach := lerpf(BULGE_RADIUS.x,BULGE_RADIUS.y,amount)
		for k in _near.size():
			var t := _near_d[k]/reach
			var i := _near[k]
			heights[i] = _base[i]+(pow(1.0-t,2.0)*height if t < 1.0 else 0.0)*_fade(i,data)
	elif kind == "basin":
		_build_shape("basin",amount)
		var s := DIMPLE*tremble
		for k in _near.size(): heights[_near[k]] = _base[_near[k]]
		for k in _shape_idx.size():
			var i := _shape_idx[k]
			heights[i] = maxf(_base[i]+_shape_lift[k]*s,NativeTerrainData.MIN_HEIGHT)
	else:
		for i in _near: heights[i] = _base[i]
	data.heights = heights
	_show(amount)
	if elapsed > 0.0: editor._emit_stroke(1,_at(),BULGE_RADIUS.y,amount*delta)

## Run the spring one frame and show the land at its scale.
func _spring(delta: float) -> void:
	spring_seconds += delta
	var zeta: float = ZETA.get(_keep_kind,0.5)
	var remaining := delta
	while remaining > 0.0:
		var step := minf(remaining,SUBSTEP)
		remaining -= step
		spring_v += (-OMEGA*OMEGA*(spring_x-spring_target)-2.0*zeta*OMEGA*spring_v)*step
		spring_x += spring_v*step
	spring_peak = maxf(spring_peak,spring_x)
	_apply(spring_x)
	if _keep_kind.is_empty(): _show(0.0)
	else: _show(1.0)
	var at_rest := absf(spring_x-spring_target) < REST and absf(spring_v) < REST_SPEED
	if at_rest or spring_seconds > MAX_SPRING:
		spring_x = spring_target
		spring_v = 0.0
		_apply(spring_x)
		_end_spring()

## Write the land at shape scale `x`. For a mountain the pucker fades as the
## mountain takes over (over x 0..1, gone after), so the land is continuous
## through the release.
func _apply(x: float) -> void:
	var data := editor.data
	var heights := data.heights
	if _keep_kind.is_empty():
		# Relaxing: what the pull showed, scaled back down to nothing.
		for k in _shape_idx.size(): heights[_shape_idx[k]] = _base[_shape_idx[k]]+_relax_shape[k]*x
	elif _keep_kind == "mountain":
		var lift: PackedFloat32Array = editor.mountain._lift
		var carry := clampf(1.0-x,0.0,1.0)
		for i in _near: heights[i] = _base[i]
		for i: int in editor.mountain._touched: heights[i] = _base[i]+lift[i]*x
		for k in _near.size():
			var j := _near[k]
			heights[j] += _bulge[k]*carry
		for i: int in editor.mountain._touched: heights[i] = clampf(heights[i],NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	else:
		for i in _near: heights[i] = _base[i]
		for k in _shape_idx.size():
			var i := _shape_idx[k]
			heights[i] = clampf(_base[i]+_shape_lift[k]*x,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	data.heights = heights

# --- Shapes ----------------------------------------------------------------------

var _relax_shape := PackedFloat32Array()

## Every point within REACH of the press, with its distance.
func _gather(data: NativeTerrainData) -> void:
	_near = PackedInt32Array()
	_near_d = PackedFloat32Array()
	for i in range(data.points.size()):
		var d: float = data.points[i].distance_to(center)
		if d >= REACH: continue
		_near.append(i)
		_near_d.append(d)

func _fade(i: int, data: NativeTerrainData) -> float:
	var p: Vector2 = data.points[i]
	var edge := maxf(absf(p.x),absf(p.y))
	return clampf((EDGE.y-edge)/(EDGE.y-EDGE.x),0.0,1.0)

## Build the final shape for `what` at pull `amount` (0..1): a basin's lift
## (negative), or the mountain's, from the mountain machinery. Nothing is
## written to the land.
func _build_shape(what: String, amount: float) -> void:
	var data := editor.data
	if what == "basin":
		var radius := lerpf(BASIN_RADIUS.x,BASIN_RADIUS.y,amount)
		var depth := lerpf(BASIN_DEPTH.x,BASIN_DEPTH.y,amount)
		var ring := 0.0
		var count := 0
		for k in _near.size():
			var t := _near_d[k]/radius
			if t >= RIM_RING and t < 1.0:
				ring += _base[_near[k]]
				count += 1
		var rim := ring/count if count > 0 else float(data.sample(center,_base) if data.sample(center,_base) != null else 0.0)
		_shape_idx = PackedInt32Array()
		_shape_lift = PackedFloat32Array()
		for k in _near.size():
			var t := _near_d[k]/radius
			if t >= 1.0: continue
			var i := _near[k]
			var bowl := 1.0-smoothstep(BOWL_FLAT,1.0,t)
			var goal := maxf(rim-depth*bowl,FLOOR)
			var cut := smoothstep(1.0,BOWL_EDGE,t)
			var lift := (minf(_base[i],goal)-_base[i])*cut*_fade(i,data)
			_shape_idx.append(i)
			_shape_lift.append(lift)
		_region = Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2.0)
		return
	# The mountain: the form's own lift, at a spread the pull sets. The heights
	# it reads are the ground from before the pull.
	var mountain: RefCounted = editor.mountain
	var shown_heights := data.heights
	data.heights = _base.duplicate()
	mountain.prepare(data,editor.land_seed)
	var right: Vector3 = editor.terrain.global_basis.inverse()*editor.scene.camera.global_basis.x
	mountain.begin(data,MOUNTAIN_FORM,center,0.01,editor.land_strength,Vector2(right.x,right.z))
	var spread := lerpf(MOUNTAIN_SPREAD.x,MOUNTAIN_SPREAD.y,amount)
	mountain.aim(data,center+Vector2(spread-mountain.spread,0.0))
	data.heights = shown_heights
	# The pucker that was showing carries into the spring and fades out.
	_bulge = PackedFloat32Array()
	_bulge.resize(_near.size())
	for k in _near.size(): _bulge[k] = shown_heights[_near[k]]-_base[_near[k]]
	_region = mountain.bounds

## Relaxing back: remember what the land shows as the shape that scales down.
func _relax_start() -> void:
	var data := editor.data
	_shape_idx = PackedInt32Array()
	_relax_shape = PackedFloat32Array()
	for k in _near.size():
		var i := _near[k]
		var lift := data.heights[i]-_base[i]
		if absf(lift) < 0.0005: continue
		_shape_idx.append(i)
		_relax_shape.append(lift)
	_keep_kind = ""
	if state == State.PULLING and shown == 0.0 and _shape_idx.is_empty():
		_finish_relax()
		return
	if state == State.PULLING:
		state = State.SPRINGING
		spring_seconds = 0.0
		spring_x = 1.0
		spring_v = 0.0
		spring_target = 0.0

# --- Landing ---------------------------------------------------------------------

func _end_spring() -> void:
	if _landing: return
	_landing = true
	var data := editor.data
	if _keep_kind.is_empty():
		_finish_relax()
	elif _keep_kind == "mountain":
		# Lands like any mountain: undo step closed, weathering on a worker.
		editor._stroke_first_id = _first_id
		editor._land_mountain()
		editor._stroke_rect = Rect2()
		state = State.IDLE
		sprung.emit("mountain",_size)
	else:
		data.mark_objects_hand(_first_id)
		var changed := data.end_stroke()
		editor._stroke_rect = _region.grow(1.0)
		editor._settle_pending = true
		editor._settle_stroke()
		if changed: editor._stroke_ended("land")
		editor._stroke_rect = Rect2()
		editor._emit_stroke(2,_at(),BASIN_RADIUS.y,0.0)
		state = State.IDLE
		sprung.emit("basin",_size)
	_hand("")
	_landing = false

## Nothing kept: the exact ground from before the press, no undo step.
func _finish_relax() -> void:
	var data := editor.data
	data.heights = _base.duplicate()
	data.end_stroke()
	editor._settle_pending = true
	editor._settle_stroke()
	editor._emit_stroke(2,_at(),BULGE_RADIUS.y,0.0)
	state = State.IDLE
	kind = ""
	pulled = 0.0
	shown = 0.0

## Send the tension to the screen: one light refresh at a time, so a slow one
## is never stacked on.
func _show(_amount: float) -> void:
	if editor.refresh_pending > 0: return
	if editor._light_refresh_ready(true):
		refreshes += 1
		editor._refresh_light()

func _at() -> Vector3:
	var h: Variant = editor.data.ground_height(center)
	return Vector3(center.x,float(h) if h != null else 0.0,center.y)

# --- The hand --------------------------------------------------------------------

func _hand(gesture: String) -> void:
	var hand: Node = scene.get("god_hand") as Node
	if hand == null: return
	hand.reach_gesture = gesture
	hand.reach_point = _at() if not gesture.is_empty() else null
	if gesture.is_empty(): hand.reach_pace = 1.0

func _hand_pace(pace: float) -> void:
	var hand: Node = scene.get("god_hand") as Node
	if hand == null or hand.reach_gesture.is_empty(): return
	hand.reach_pace = pace
	hand.reach_point = _at()
