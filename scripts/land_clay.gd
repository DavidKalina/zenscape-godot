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
##   pointer travels decides it, blended: a slow stroke digs a channel along
##   the path, a fast back-and-forth rub smooths the land under it. **Shift**
##   when the drag is decided makes it the palm, which levels the land to a
##   little under the height under the press, a pan a pond can fill. Where
##   either takes the ground down, bare earth shows through the grass (the
##   tint layer) and stays.
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
## Dabs along the path, metres apart, and at most this many a frame (a
## thumb's first SPEED_WINDOW of dabs are laid together once its speed is read).
const DAB_SPACING := 0.3
const MAX_DABS := 64
## The groove: half-width and depth in metres below the ground on the stroke's
## line. Its bed is level across (the ground at the line, less the depth),
## full depth inside GROOVE_FLOOR of the half-width (the land's points are
## 0.45 to 0.75 m apart, so a row or two always reaches the bed) and eases to
## the untouched ground at the half-width on a smoothstep, so the floor and
## the banks are rounded. A lip of GROOVE_LIP metres rises just
## outside (to LIP_OUT half-widths), the clay the thumb pushed aside. Each dab
## moves the ground GROOVE_STEP of the way to that shape, and a stroke never
## digs below it however long it lingers: a groove is even and unbroken.
## The bed never climbs along the stroke, so a downhill stroke is a channel
## that keeps falling across the ground's bumps; it cuts at most GROOVE_CUT
## metres deeper than GROOVE_DEPTH to do so, and past that it rises with a
## hump (an uphill stroke: level, then rising, so it drains back to its start).
const GROOVE_HALF_WIDTH := 1.25
const GROOVE_DEPTH := 1.0
const GROOVE_FLOOR := 0.55
const GROOVE_LIP := 0.1
const LIP_OUT := 1.6
const GROOVE_STEP := 0.5
const GROOVE_CUT := 0.5
## The rub: radius in metres, and the share each dab moves a point toward the
## mean of its neighbours at the centre (easing to nothing at the rim from
## RUB_CORE of the radius).
const RUB_RADIUS := 1.6
const RUB_STEP := 0.45
const RUB_CORE := 0.5
## The palm: radius in metres, and the share each dab moves a point toward
## the level under the press (full inside PALM_CORE of the radius). The level
## is pressed PALM_SINK metres below the ground under the press, easing to
## none at the rim, so the palm leaves a level-floored pan a pond can fill;
## each stroke presses from the ground as it stands, so pressing again deepens it.
const PALM_RADIUS := 2.0
const PALM_STEP := 0.5
const PALM_CORE := 0.55
const PALM_SINK := 0.4
## Dirt: where the thumb or the palm takes the ground down, the painted grass
## has caved in and bare earth shows. The tint layer's weight rises from
## nothing at DIRT_FROM metres dug to full at DIRT_FULL, and its colour darkens
## from DIRT toward DIRT_DEEP by GROOVE_DEPTH. A cell a stroke leaves at least
## DIRT_BARE bare loses its grass and blades and is marked hand-made, so cover
## does not creep back and nothing takes root in it. Dirt only ever deepens.
const DIRT_FROM := 0.04
const DIRT_FULL := 0.45
const DIRT_BARE := 0.5
const DIRT := Color("946c47")
const DIRT_DEEP := Color("73513a")
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
## A thumb's groove that runs into that fade heading out of the plate (its
## travel within BREACH_ANGLE degrees of straight out across the nearest
## side) breaches the rim: it digs at full depth to the lip and notches the
## rim, a spillway the live water runs off (docs/scenic/modeless.md, "The
## thumb at the rim"). A stroke let go, or run off the plate, while breaching
## is carried on to BREACH_PAST metres beyond the rim (PLATE_HALF), so the rim's
## own points take the groove's bed. Only the groove itself is dug so: its
## banks' raised lip, the pinch, the palm, the rub and a thumb running along
## the edge still fade, so the plate's outline stays clean round the notch.
const BREACH_ANGLE := 50.0
const BREACH_PAST := 0.4
const PLATE_HALF := 14.0
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
## Rim notches the thumb has cut this session, and the last one: {"normal"
## (out of the plate), "at" (plate point on the rim), "bed" (m)}, for probes.
var notches := 0
var last_notch := {}

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
var _bed := INF
var _stroking := 0.0
var _tint_base := PackedFloat32Array()
var _dirt_depth := {}
var _dirt_rect := Rect2()
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
## The outward normal of the side the thumb's last dab breached (zero when
## it did not), the stroke's heading (over its last HEADING_RUN metres, so a
## slow stroke's pick jitter does not turn it), and whether it has been
## carried to the lip.
const HEADING_RUN := 0.6
var _breach := Vector2.ZERO
var _heading := Vector2.ZERO
var _heading_from := Vector2.ZERO
var _carried := false

static func enabled() -> bool:
	return preload("res://scripts/modeless_input.gd").enabled()

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
		var hit: Variant = _pick_base(screen_pos)
		if hit != null: _queued.append(Vector2(hit.x,hit.z))
		# Run off the plate while breaching: the groove goes on to the lip.
		elif not _carried: _carry_to_lip()

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
			if not _carried and _carry_to_lip(): _thumb_step(0.0)
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
	_bed = INF
	_stroking = 0.0
	_tint_base = editor.data.tint.duplicate()
	_dirt_depth = {}
	_breach = Vector2.ZERO
	_heading = Vector2.ZERO
	_heading_from = _center
	_carried = false
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
	_bare()
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
	_stroking += delta
	rub = smoothstep(GROOVE_SPEED,RUB_SPEED,speed) if verb == "thumb" else 0.0
	# A thumb's first SPEED_WINDOW is held until its speed is known, so a rub
	# does not start by digging (a release lays it down as it stands).
	if _queued.is_empty() or (verb == "thumb" and delta > 0.0 and _stroking < SPEED_WINDOW): return
	var data := editor.data
	var heights := data.heights
	_dirt_rect = Rect2()
	for p in _queued:
		var from: Vector2 = _last_plate if _last_plate != null else p
		var count := clampi(ceili(from.distance_to(p)/DAB_SPACING),1,MAX_DABS)
		if _heading_from.distance_to(p) >= HEADING_RUN:
			_heading = (p-_heading_from).normalized()
			_heading_from = p
		for k in range(1,count+1):
			var q := from.lerp(p,float(k)/count)
			if verb == "palm":
				_palm(heights,q)
				_dirty(q,PALM_RADIUS)
			else:
				if rub < 0.99:
					_breach = _breaching(q)
					_groove(heights,q,1.0-rub,_breach)
					_dirty(q,GROOVE_HALF_WIDTH)
				if rub > 0.01: _rub(heights,q,rub)
			dabs += 1
		_last_plate = p
	_queued = PackedVector2Array()
	data.heights = heights
	_dirt()
	_show()
	var at := _ground_at(_last_plate)
	editor._emit_stroke(1,at,GROOVE_HALF_WIDTH,delta)
	_hand("press",at)
	var hand: Node = scene.get("god_hand") as Node
	if hand != null and _hand_set == "press": hand.reach_pace = 1.0+1.5*rub

## The groove's dab at `q` with weight `g`: toward a level bed GROOVE_DEPTH
## under the stroke's line, never below it, and never above the bed behind it
## (by at most GROOVE_CUT). `breach` (the outward normal of the side it is
## breaching, or zero) digs its bed without the edge fade.
func _groove(heights: PackedFloat32Array, q: Vector2, g: float, breach := Vector2.ZERO) -> void:
	# Past the rim (a breach carried to the lip) the bed follows the ground
	# at the rim.
	var ground: Variant = editor.data.sample(q.clamp(-Vector2.ONE*(PLATE_HALF-0.02),Vector2.ONE*(PLATE_HALF-0.02)),_base)
	if ground == null: return
	var bed := float(ground)-GROOVE_DEPTH
	bed = maxf(minf(bed,_bed),bed-GROOVE_CUT)
	_bed = bed
	var reach := GROOVE_HALF_WIDTH*LIP_OUT
	_gather(q,reach)
	_touch(q,reach)
	var notched := false
	for k in _near.size():
		var i := _near[k]
		var t := _near_d[k]/GROOVE_HALF_WIDTH
		var fade := _fade(i)
		if t < 1.0:
			_dug[i] = 1
			if breach != Vector2.ZERO:
				fade = 1.0
				notched = notched or editor.data.points[i].dot(breach) >= PLATE_HALF-0.001
			var goal := minf(_base[i],lerpf(bed,_base[i],smoothstep(GROOVE_FLOOR,1.0,t)))
			var h := heights[i]
			if goal < h: heights[i] = maxf(lerpf(h,goal,GROOVE_STEP*g*fade),NativeTerrainData.MIN_HEIGHT)
		elif _dug[i] == 0:
			var rim := GROOVE_LIP*sin(PI*(t-1.0)/(LIP_OUT-1.0))
			var goal := _base[i]+rim
			var h := heights[i]
			if goal > h: heights[i] = lerpf(h,goal,GROOVE_STEP*g*fade)
	if notched:
		if last_notch.is_empty() or last_notch.normal != breach or (last_notch.at as Vector2).distance_to(q) > GROOVE_HALF_WIDTH*2.0: notches += 1
		var along := Vector2(breach.y,-breach.x)
		last_notch = {"normal":breach,"at":breach*PLATE_HALF+along*q.dot(along),"bed":bed}

## The outward normal of the side a groove dab at `q` breaches: the nearest
## side's, when `q` is in the edge fade and the stroke heads out across that
## side within BREACH_ANGLE degrees; else zero.
func _breaching(q: Vector2) -> Vector2:
	if maxf(absf(q.x),absf(q.y)) < EDGE.x or _heading == Vector2.ZERO: return Vector2.ZERO
	var normal := Vector2(signf(q.x),0.0) if absf(q.x) >= absf(q.y) else Vector2(0.0,signf(q.y))
	return normal if _heading.dot(normal) >= cos(deg_to_rad(BREACH_ANGLE)) else Vector2.ZERO

## Carries a breaching groove on along its heading to BREACH_PAST beyond the
## rim, queued as the pointer's next point. False when it is not breaching or
## is already there.
func _carry_to_lip() -> bool:
	if verb != "thumb" or _breach == Vector2.ZERO or _last_plate == null: return false
	var from: Vector2 = _queued[-1] if not _queued.is_empty() else _last_plate
	var out := _heading.dot(_breach)
	var left := PLATE_HALF+BREACH_PAST-from.dot(_breach)
	if out <= 0.0 or left <= 0.05: return false
	_carried = true
	_queued.append(from+_heading*(left/out))
	return true

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

## The palm's dab at `q`: toward the level under the press, pressed PALM_SINK
## down in the middle.
func _palm(heights: PackedFloat32Array, q: Vector2) -> void:
	_gather(q,PALM_RADIUS)
	_touch(q,PALM_RADIUS)
	for k in _near.size():
		var i := _near[k]
		var f := 1.0-smoothstep(PALM_CORE,1.0,_near_d[k]/PALM_RADIUS)
		var goal := _level-PALM_SINK*f
		heights[i] = maxf(lerpf(heights[i],goal,PALM_STEP*f*_fade(i)),NativeTerrainData.MIN_HEIGHT)

## The ground a dab at `q` may have dug, `reach` round it, for this frame's dirt.
func _dirty(q: Vector2, reach: float) -> void:
	var area := Rect2(q-Vector2.ONE*reach,Vector2.ONE*reach*2.0)
	_dirt_rect = _dirt_rect.merge(area) if _dirt_rect.has_area() else area

## Bare earth into the tint cells under this frame's dabs, by how far each
## cell's middle now stands below the ground at the stroke's start. Written
## from the stroke's starting tint, so it lands the same whatever the pace.
func _dirt() -> void:
	if not _dirt_rect.has_area(): return
	var data := editor.data
	var side := NativeTerrainData.MEADOW_CELLS
	var step := NativeTerrainData.MEADOW_STEP
	var low := Vector2i(((_dirt_rect.position+Vector2(14,14))/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var high := Vector2i(((_dirt_rect.end+Vector2(14,14))/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var light := DIRT.srgb_to_linear()
	var deep := DIRT_DEEP.srgb_to_linear()
	var heights := data.heights
	var tint := data.tint
	var changed := false
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var p := data.meadow_position(x,z)+Vector2.ONE*step*0.5
			var was: Variant = data.sample(p,_base)
			var now: Variant = data.sample(p,heights)
			if was == null or now == null: continue
			var cell := z*side+x
			var dug := float(was)-float(now)
			if dug <= float(_dirt_depth.get(cell,DIRT_FROM)): continue
			_dirt_depth[cell] = dug
			var color := light.lerp(deep,smoothstep(DIRT_FULL,GROOVE_DEPTH,dug))
			NativeTerrainTint.coat(tint,_tint_base,cell,color,smoothstep(DIRT_FROM,DIRT_FULL,dug))
			changed = true
	_dirt_rect = Rect2()
	if changed: data.tint = tint

## Where a stroke left the ground bare, the grass is gone for good: no cover,
## no blades, and hand-made, so emergence neither regrows nor plants it.
func _bare() -> void:
	var data := editor.data
	for cell: int in _dirt_depth:
		if NativeTerrainTint.weight_at(data.tint,cell) < DIRT_BARE: continue
		data.grass[cell] = 0.0
		data.blades[cell] = 0.0
		data.meadow[cell] = 0.0
		data.provenance[cell] = NativeTerrainData.SOURCE_HAND
	_dirt_depth = {}

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

## The pointer on the ground as it stood when the stroke began: picked on the
## live ground, a groove deepening ahead of the pointer would draw the line
## onto its far wall, away from the camera, and widen it on that side.
func _pick_base(screen_pos: Vector2) -> Variant:
	var data := editor.data
	var now := data.heights
	data.heights = _base
	var hit: Variant = editor.pick(screen_pos)
	data.heights = now
	return hit

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
