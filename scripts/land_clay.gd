extends Node
## Land as clay (docs/scenic/modeless.md, "Land as clay"). Under `--modeless`
## a left press on the land is the hand working clay, and the shape and timing
## of the press decide the verb. There are no springs here: the land follows
## the hand and stays where it is let go.
##
## - **Tap** (let go within HOLD_SECONDS, moved under MOVE_PIXELS): a poke. A
##   small dimple rings out at the spot and the land comes back exactly; a
##   resident nearby looks round. Nothing is kept, no undo step. (Props, trees
##   and residents under the pointer never reach here: hand_reach keeps their
##   own grab.)
## - **Drag** (moved MOVE_PIXELS before HOLD_SECONDS): the thumb. How fast the
##   pointer travels decides it, blended: a slow stroke digs a soft groove along
##   the path, a fast back-and-forth rub smooths the land under it. **Shift**
##   when the drag is decided makes it the palm, which levels the land to the
##   height under the press.
## - **Hold still** for HOLD_SECONDS: the hand closes into a pinch, and then
##   dragging up raises and down sinks the pinched spot, directly: the summit
##   follows the pointer. **Shift** when the pinch closes makes it a smaller,
##   gentler one.
##
## Each stroke or pinch is one undo step (opened when the verb is decided,
## closed at release). The land shows through the editor's light refresh, one
## at a time, as the brushes and the land spring do; only the points near the
## hand are written. Nothing weathers after: clay stays as it was left.
##
## Input: hand_reach's `land_pressed`, `land_dragged` and `land_released` call
## `press`, `pull` and `release` (connected in studies/fidelity.gd).

## Emitted when a press ends: `verb` is "poke", "groove" (a thumb stroke, its
## `rub` share 0..1 in `last_rub`), "palm", "pinch" or "fine_pinch"; `kept` is
## whether the land changed and an undo step was added.
signal worked(verb: String, kept: bool)

## Seconds of holding still that close the pinch, and the screen pixels of
## travel that make the press a drag instead. A release before either is a tap.
const HOLD_SECONDS := 0.3
const MOVE_PIXELS := 6.0
## The thumb's speed blend, pointer pixels per second over the last
## SPEED_WINDOW seconds of travel (path length, so a rub's turns do not read
## as slow): at GROOVE_SPEED and under it only digs, at RUB_SPEED and over it
## only smooths, and between it does some of each.
const GROOVE_SPEED := 500.0
const RUB_SPEED := 1200.0
const SPEED_WINDOW := 0.25
## Dabs along the path, metres apart, and at most this many a frame.
const DAB_SPACING := 0.3
const MAX_DABS := 64
## The groove: half-width and depth in metres below the ground on the stroke's
## line. Its bed is level across (the ground at the line, less the depth),
## full depth inside GROOVE_FLOOR of the half-width (the land's points are
## about 0.6 m apart, so the nearest row always reaches the bed) and eases to
## the untouched ground at the half-width on a smoothstep, so the floor and
## the banks are rounded. A lip of GROOVE_LIP metres rises just
## outside (to LIP_OUT half-widths), the clay the thumb pushed aside. Each dab
## moves the ground GROOVE_STEP of the way to that shape, and a stroke never
## digs below it however long it lingers: a groove is even and unbroken.
const GROOVE_HALF_WIDTH := 1.2
const GROOVE_DEPTH := 0.3
const GROOVE_FLOOR := 0.35
const GROOVE_LIP := 0.05
const LIP_OUT := 1.6
const GROOVE_STEP := 0.5
## The rub: radius in metres, and the share each dab moves a point toward the
## mean of its neighbours at the centre (easing to nothing at the rim from
## RUB_CORE of the radius).
const RUB_RADIUS := 1.6
const RUB_STEP := 0.45
const RUB_CORE := 0.5
## The palm: radius in metres, and the share each dab moves a point toward
## the level under the press (full inside PALM_CORE of the radius).
const PALM_RADIUS := 2.0
const PALM_STEP := 0.5
const PALM_CORE := 0.55
## The pinch. The pinched spot rises by the pointer's travel up the screen at
## the scale of a metre standing there (so the summit keeps to the pointer),
## `(1-t²)²` falloff over a radius that widens with the height: R0 plus GROW
## per metre, at most MAX_RADIUS. The lift is between -SINK and RAISE metres,
## and sinking never takes ground below FLOOR (the land brush's floor).
## A Shift pinch is FINE_SCALE of the travel over a smaller spread.
const PINCH := {"r0":2.2,"grow":0.45,"max_radius":5.6,"raise":8.0,"sink":4.0,"scale":1.0}
const FINE_PINCH := {"r0":1.2,"grow":0.3,"max_radius":2.6,"raise":2.0,"sink":1.0,"scale":0.4}
const FLOOR := -1.2
## A metre standing at the pinch is never taken as fewer than this share of a
## metre across the ground on screen, so a camera looking straight down still
## pinches.
const MIN_UPRIGHT := 0.3
## The poke: a dimple POKE_DEPTH metres deep over POKE_RADIUS, ringing out
## over POKE_SECONDS; a resident within NOTICE metres looks round at it.
const POKE_DEPTH := 0.1
const POKE_RADIUS := 1.2
const POKE_SECONDS := 0.5
const POKE_RATE := 26.0
const POKE_DAMP := 7.0
const NOTICE := 8.0
## The plate's last metres, where shaping fades to nothing (as the land
## spring and the mountain forms).
const EDGE := Vector2(11.4,13.6)
## Metres per bucket of the point lookup.
const CELL := 1.5

enum State { IDLE, PENDING, THUMB, PINCH }

var scene: Node3D
var editor: NativeChunkEditor
var state := State.IDLE
## "thumb" or "palm" for a drag, "pinch" or "fine_pinch" for a hold.
var verb := ""
## Seconds since the press, and the most pixels the pointer has been from it.
var held := 0.0
var travel := 0.0
## The thumb's speed (pixels per second over the window) and its rub share.
var speed := 0.0
var rub := 0.0
var last_rub := 0.0
## The pinch's lift in metres, as shown.
var lift := 0.0
## Counters for the probe: light refreshes, dabs, times the pinch closed.
var refreshes := 0
var dabs := 0
var pinch_closes := 0
var poking := false

var _press := Vector2.ZERO
var _pointer := Vector2.ZERO
var _center := Vector2.ZERO
var _base := PackedFloat32Array()
var _first_id := 0
var _region := Rect2()
var _queued := PackedVector2Array()
var _last_plate: Variant = null
var _moved := 0.0
var _window: Array[Vector2] = []
var _dug := PackedByteArray()
var _level := 0.0
var _near := PackedInt32Array()
var _near_d := PackedFloat32Array()
var _metre_pixels := 1.0
var _shown_lift := INF
var _hand_set := ""
var _poke_t := 0.0
var _poke_idx := PackedInt32Array()
var _poke_shape := PackedFloat32Array()
var _poke_written := PackedFloat32Array()
var _cells := {}
var _cells_for: NativeTerrainData
var _cells_points := -1

static func enabled() -> bool:
	return "--modeless" in OS.get_cmdline_user_args()

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = owner_scene._chunk_editor
	editor.clay = self
	name = "LandClay"

# --- The seam the modeless input drives -------------------------------------------

## A press on the land at `screen_pos`. False when it is not on the land or
## the editor cannot take it.
func press(screen_pos: Vector2) -> bool:
	finish_now()
	if editor == null or editor.forming or not editor.active: return false
	var hit: Variant = editor.pick(screen_pos)
	if hit == null: return false
	_press = screen_pos
	_pointer = screen_pos
	_center = Vector2(hit.x,hit.z)
	_last_plate = _center
	_queued = PackedVector2Array()
	_window.clear()
	_moved = 0.0
	held = 0.0
	travel = 0.0
	speed = 0.0
	rub = 0.0
	lift = 0.0
	verb = ""
	refreshes = 0
	dabs = 0
	state = State.PENDING
	return true

## The pointer moved to `screen_pos`.
func pull(screen_pos: Vector2, _relative := Vector2.ZERO) -> void:
	if state == State.IDLE: return
	_moved += screen_pos.distance_to(_pointer)
	_pointer = screen_pos
	travel = maxf(travel,screen_pos.distance_to(_press))
	if state == State.PENDING and travel >= MOVE_PIXELS: _begin_drag()
	if state == State.THUMB:
		var hit: Variant = editor.pick(screen_pos)
		if hit != null: _queued.append(Vector2(hit.x,hit.z))

## The button came up: a tap pokes, a stroke or a pinch is kept as it stands.
func release(screen_pos: Vector2 = Vector2.INF) -> void:
	if state == State.IDLE: return
	if screen_pos != Vector2.INF: pull(screen_pos)
	match state:
		State.PENDING:
			state = State.IDLE
			_poke()
		State.THUMB:
			_thumb_step(0.0)
			_end_stroke()
		State.PINCH:
			_pinch_step()
			_end_stroke()

## End whatever is in hand at once (undo, a new press, a world change): a
## stroke or pinch closes as it stands, a poke's dimple is taken back.
func finish_now() -> void:
	if poking: _end_poke()
	match state:
		State.PENDING: state = State.IDLE
		State.THUMB, State.PINCH: _end_stroke()

# --- Frame loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	if poking: _poke_step(delta)
	match state:
		State.PENDING:
			held += delta
			_track_speed(delta)
			if held >= HOLD_SECONDS and travel < MOVE_PIXELS: _begin_pinch()
		State.THUMB: _thumb_step(delta)
		State.PINCH: _pinch_step()

## The thumb's speed: path pixels over the last SPEED_WINDOW seconds.
func _track_speed(delta: float) -> void:
	_window.append(Vector2(delta,_moved))
	_moved = 0.0
	var seconds := 0.0
	var pixels := 0.0
	for k in range(_window.size()-1,-1,-1):
		if seconds >= SPEED_WINDOW:
			_window = _window.slice(k+1)
			break
		seconds += _window[k].x
		pixels += _window[k].y
	speed = pixels/maxf(seconds,1.0/120.0)

# --- Verbs -------------------------------------------------------------------------

func _begin_drag() -> void:
	verb = "palm" if _shift() else "thumb"
	_open_stroke()
	_dug = PackedByteArray()
	_dug.resize(_base.size())
	var ground: Variant = editor.data.sample(_center,_base)
	_level = float(ground) if ground != null else 0.0
	state = State.THUMB
	_hand("press",_ground_at(_center))

func _begin_pinch() -> void:
	var fine := _shift()
	verb = "fine_pinch" if fine else "pinch"
	var spec: Dictionary = FINE_PINCH if fine else PINCH
	_open_stroke()
	_gather(_center,float(spec.max_radius))
	var at := _ground_at(_center)
	var camera: Camera3D = scene.camera
	var terrain: Node3D = editor.terrain
	var foot := camera.unproject_position(terrain.to_global(at))
	var up := camera.unproject_position(terrain.to_global(at+Vector3.UP)).distance_to(foot)
	var across := camera.unproject_position(terrain.to_global(at+Vector3.RIGHT)).distance_to(foot)
	_metre_pixels = maxf(maxf(up,across*MIN_UPRIGHT),1.0)
	_shown_lift = INF
	state = State.PINCH
	pinch_closes += 1
	_hand("pinch",at,true)

## Open the verb's one undo step on the ground as it now stands.
func _open_stroke() -> void:
	var data := editor.data
	# Anything still landing lands first, as a brush press would.
	editor._land_mountain()
	data.begin_stroke()
	_base = data.heights.duplicate()
	_first_id = data.next_id
	_region = Rect2(_center,Vector2.ZERO).grow(1.0)
	editor._emit_stroke(0,_ground_at(_center),GROOVE_HALF_WIDTH,0.0)

## Close the verb's undo step and settle the land, as a brush's release does.
func _end_stroke() -> void:
	var data := editor.data
	data.mark_objects_hand(_first_id)
	var kept := data.end_stroke()
	editor._stroke_rect = _region.grow(1.0)
	editor._settle_pending = true
	editor._settle_stroke()
	if kept: editor._stroke_ended("land")
	editor._stroke_rect = Rect2()
	editor._emit_stroke(2,_ground_at(_center),GROOVE_HALF_WIDTH,0.0)
	var done := verb
	if verb == "thumb": done = "groove"
	last_rub = rub
	state = State.IDLE
	verb = ""
	_hand("")
	worked.emit(done,kept)

## Dabs along the pointer's path since the last frame.
func _thumb_step(delta: float) -> void:
	if delta > 0.0: _track_speed(delta)
	rub = smoothstep(GROOVE_SPEED,RUB_SPEED,speed) if verb == "thumb" else 0.0
	if _queued.is_empty(): return
	var data := editor.data
	var heights := data.heights
	for p in _queued:
		var from: Vector2 = _last_plate if _last_plate != null else p
		var count := clampi(ceili(from.distance_to(p)/DAB_SPACING),1,MAX_DABS)
		for k in range(1,count+1):
			var q := from.lerp(p,float(k)/count)
			if verb == "palm": _palm(heights,q)
			else:
				if rub < 0.99: _groove(heights,q,1.0-rub)
				if rub > 0.01: _rub(heights,q,rub)
			dabs += 1
		_last_plate = p
	_queued = PackedVector2Array()
	data.heights = heights
	_show()
	var at := _ground_at(_last_plate)
	editor._emit_stroke(1,at,GROOVE_HALF_WIDTH,delta)
	_hand("press",at)
	var hand: Node = scene.get("god_hand") as Node
	if hand != null and _hand_set == "press": hand.reach_pace = 1.0+1.5*rub

## The groove's dab at `q` with weight `g`: toward a level bed GROOVE_DEPTH
## under the stroke's line, never below it.
func _groove(heights: PackedFloat32Array, q: Vector2, g: float) -> void:
	var ground: Variant = editor.data.sample(q,_base)
	if ground == null: return
	var bed := float(ground)-GROOVE_DEPTH
	var reach := GROOVE_HALF_WIDTH*LIP_OUT
	_gather(q,reach)
	_touch(q,reach)
	for k in _near.size():
		var i := _near[k]
		var t := _near_d[k]/GROOVE_HALF_WIDTH
		var fade := _fade(i)
		if t < 1.0:
			_dug[i] = 1
			var goal := minf(_base[i],lerpf(bed,_base[i],smoothstep(GROOVE_FLOOR,1.0,t)))
			var h := heights[i]
			if goal < h: heights[i] = maxf(lerpf(h,goal,GROOVE_STEP*g*fade),NativeTerrainData.MIN_HEIGHT)
		elif _dug[i] == 0:
			var rim := GROOVE_LIP*sin(PI*(t-1.0)/(LIP_OUT-1.0))
			var goal := _base[i]+rim
			var h := heights[i]
			if goal > h: heights[i] = lerpf(h,goal,GROOVE_STEP*g*fade)

## The rub's dab at `q` with weight `w`: each point toward its neighbours' mean.
func _rub(heights: PackedFloat32Array, q: Vector2, w: float) -> void:
	var neighbors: Array[PackedInt32Array] = editor.data._neighbors
	_gather(q,RUB_RADIUS)
	_touch(q,RUB_RADIUS)
	for k in _near.size():
		var i := _near[k]
		var around: PackedInt32Array = neighbors[i]
		if around.is_empty(): continue
		var total := 0.0
		for j in around: total += heights[j]
		var f := 1.0-smoothstep(RUB_CORE,1.0,_near_d[k]/RUB_RADIUS)
		heights[i] = lerpf(heights[i],total/around.size(),RUB_STEP*w*f*_fade(i))

## The palm's dab at `q`: toward the level under the press.
func _palm(heights: PackedFloat32Array, q: Vector2) -> void:
	_gather(q,PALM_RADIUS)
	_touch(q,PALM_RADIUS)
	for k in _near.size():
		var i := _near[k]
		var f := 1.0-smoothstep(PALM_CORE,1.0,_near_d[k]/PALM_RADIUS)
		heights[i] = lerpf(heights[i],_level,PALM_STEP*f*_fade(i))

## The pinch follows the pointer: its lift is the pointer's travel up the
## screen in metres standing at the spot.
func _pinch_step() -> void:
	var spec: Dictionary = FINE_PINCH if verb == "fine_pinch" else PINCH
	lift = clampf((_press.y-_pointer.y)/_metre_pixels*float(spec.scale),-float(spec.sink),float(spec.raise))
	if is_equal_approx(lift,_shown_lift): return
	_shown_lift = lift
	var radius := minf(float(spec.r0)+float(spec.grow)*absf(lift),float(spec.max_radius))
	var data := editor.data
	var heights := data.heights
	for k in _near.size():
		var i := _near[k]
		var t := _near_d[k]/radius
		var shape := pow(1.0-t*t,2.0) if t < 1.0 else 0.0
		var h := _base[i]+lift*shape*_fade(i)
		if lift < 0.0: h = maxf(h,minf(_base[i],FLOOR))
		heights[i] = clampf(h,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	data.heights = heights
	_touch(_center,radius)
	_show()
	_hand("pinch",_ground_at(_center))

# --- The poke ----------------------------------------------------------------------

## A tap on bare land: a small dimple that rings out, and a resident near it
## looks round. The ground comes back exactly and no undo step is added.
func _poke() -> void:
	verb = ""
	var data := editor.data
	_gather(_center,POKE_RADIUS)
	_poke_idx = _near.duplicate()
	_poke_shape = PackedFloat32Array()
	_poke_written = PackedFloat32Array()
	_base = data.heights.duplicate()
	for k in _near.size():
		var t := _near_d[k]/POKE_RADIUS
		_poke_shape.append(pow(1.0-t*t,2.0)*_fade(_near[k]))
	_poke_written.resize(_poke_idx.size())
	_poke_t = 0.0
	poking = true
	_hand("press",_ground_at(_center))
	var creature: Node3D = scene.get("creature") as Node3D
	if creature != null and creature.visible and creature.has_method("notice"):
		var at: Vector3 = editor.terrain.to_global(_ground_at(_center))
		if creature.global_position.distance_to(at) < NOTICE: creature.notice(at)
	_poke_step(0.0)

func _poke_step(delta: float) -> void:
	_poke_t += delta
	if _poke_t >= POKE_SECONDS:
		_end_poke()
		return
	var amount := -POKE_DEPTH*exp(-POKE_DAMP*_poke_t)*cos(POKE_RATE*_poke_t)
	var data := editor.data
	var heights := data.heights
	for k in _poke_idx.size():
		var i := _poke_idx[k]
		heights[i] = _base[i]+amount*_poke_shape[k]
		_poke_written[k] = heights[i]
	data.heights = heights
	_show()

## The dimple is taken back: the exact ground from before, where nothing else
## has moved it since.
func _end_poke() -> void:
	poking = false
	var data := editor.data
	var heights := data.heights
	for k in _poke_idx.size():
		var i := _poke_idx[k]
		if i < heights.size() and heights[i] == _poke_written[k]: heights[i] = _base[i]
	data.heights = heights
	editor._settle_pending = true
	editor._settle_stroke()
	if _hand_set == "press": _hand("")
	worked.emit("poke",false)

# --- Helpers -----------------------------------------------------------------------

func _shift() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)

## Every point within `radius` of `center` into _near (and distances _near_d).
func _gather(center: Vector2, radius: float) -> void:
	var data := editor.data
	if _cells_for != data or _cells_points != data.points.size():
		_cells.clear()
		_cells_for = data
		_cells_points = data.points.size()
		for i in range(data.points.size()):
			var key := Vector2i(floori(data.points[i].x/CELL),floori(data.points[i].y/CELL))
			if not _cells.has(key): _cells[key] = PackedInt32Array()
			_cells[key].append(i)
	_near = PackedInt32Array()
	_near_d = PackedFloat32Array()
	var low := Vector2i(floori((center.x-radius)/CELL),floori((center.y-radius)/CELL))
	var high := Vector2i(floori((center.x+radius)/CELL),floori((center.y+radius)/CELL))
	var points := data.points
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			var cell: Variant = _cells.get(Vector2i(x,y))
			if cell == null: continue
			for i: int in cell:
				var d := points[i].distance_to(center)
				if d < radius:
					_near.append(i)
					_near_d.append(d)

func _fade(i: int) -> float:
	var p: Vector2 = editor.data.points[i]
	var edge := maxf(absf(p.x),absf(p.y))
	return clampf((EDGE.y-edge)/(EDGE.y-EDGE.x),0.0,1.0)

func _touch(q: Vector2, reach: float) -> void:
	_region = _region.merge(Rect2(q-Vector2.ONE*reach,Vector2.ONE*reach*2.0))

func _ground_at(p: Vector2) -> Vector3:
	var h: Variant = editor.data.ground_height(p)
	return Vector3(p.x,float(h) if h != null else 0.0,p.y)

## Send the land to the screen: one light refresh at a time, so a slow one is
## never stacked on; a full one if the light one cannot run.
func _show() -> void:
	if editor.refresh_pending > 0: return
	refreshes += 1
	if editor._light_refresh_ready(true): editor._refresh_light()
	else: editor.refresh(get_tree())

## Drive the God Hand. `again` plays the gesture's In afresh even if it is
## already showing (the hover's ready pinch closes into the real one).
func _hand(gesture: String, point: Variant = null, again := false) -> void:
	var hand: Node = scene.get("god_hand") as Node
	if hand == null: return
	_hand_set = gesture
	hand.reach_gesture = gesture
	hand.reach_point = point if not gesture.is_empty() else null
	if gesture.is_empty(): hand.reach_pace = 1.0
	if again and hand.get("gesture") == gesture and hand.player != null:
		var clip: String = hand.GESTURES[gesture]+"In"
		if hand.player.has_animation(clip): hand.player.play(clip,hand.BLEND)
