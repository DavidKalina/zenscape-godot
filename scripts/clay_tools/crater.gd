extends "res://scripts/clay_tools/hand.gd"
## The Crater, "Hollow" (docs/design/tools/PLAN.md "The roll, revised"): two
## modes, picked on its fan or with Q and E, as the Mountain's are (the user,
## 2026-10-03: people will want to make massive lakes). Each mode's press is
## its verb at once (`modes`' kinds).
##
## - **Pull** (the first mode): press on the land and drag down, and a crater
##   opens under the press, its floor following the pointer down. It is the
##   Mountain's pull turned over, built on the Modeller's pinch
##   (scripts/clay_tools/hand.gd) as the Mountain is. Dragging up does
##   nothing past the press's ground. The user, 2026-10-02, asked for it as
##   its own tool, after the Mountain's pull-down crater: one landform, one
##   tool.
## - **Draw:** press and draw round the shore you want, and let go: the
##   outline closes (its end joined back to its start) and the land inside
##   it sinks into a lake bed, level LAKE_DEPTH under the outline's lowest
##   ground, its banks easing up to the shore over LAKE_BANK metres (at most
##   LAKE_BANK_SHARE of the way to its middle). While the drag lasts the land
##   is untouched and the ground marks' faint line follows the drawn shore.
##   Let go, the bed sinks over SINK_SECONDS, the banks going first and the
##   middle following (SINK_WAVE), and the hand runs round the shore as it
##   goes, so the tremor and the sound feel it; one undo step, closed once
##   it has sunk, and an undo, a new press, a change of tool or Esc mid-sink
##   lands the rest of it at once. An outline enclosing under LAKE_LEAST
##   square metres (a click, a scribble) leaves the land alone.
##
## **Shift:** a smaller crater (FINE_CRATER), or a shallower lake (SHALLOW of
## the depth).
##
const CRATER := {"r0":2.4,"grow":0.5,"max_radius":7.0,"raise":0.0,"sink":6.0,"scale":1.4}
const FINE_CRATER := {"r0":1.4,"grow":0.35,"max_radius":3.5,"raise":0.0,"sink":3.0,"scale":0.6}
const CRATER_FLOOR := 0.45
const CRATER_RIM_AT := 0.95
const CRATER_RIM := 0.3
const CRATER_RIM_OUT := 1.25
const LAKE_DEPTH := 3.0
const LAKE_BANK := 3.0
const LAKE_BANK_SHARE := 0.45
const LAKE_LEAST := 6.0
const SHALLOW := 0.4
## The bed sinking: its least and most seconds (by the outline's length at
## SINK_PACE metres a second), and how far behind the banks the middle sinks
## (a share of the whole sink).
const SINK_PACE := 16.0
const SINK_SECONDS := Vector2(1.0,3.0)
const SINK_WAVE := 0.6
const CRATER_MODES := [{"id":"pull","kind":"hold"},{"id":"draw","kind":"drag"}]
const Wire = preload("res://scripts/clay_tools/wire.gd")
const DrawnLine = preload("res://scripts/clay_tools/drawn_line.gd")

## The stand-in: a faceted tamper, a wooden haft down to a broad round stone
## foot in the icon's tint (scripts/hud_icons.gd "crater").
const STONE := Color("a08a68")
const HAFT := Color("b98a58")

## The drawn lake: the shore being drawn; once let go, the closed outline
## (with its arc lengths), each point inside as Vector3(index, metres in from
## the shore, depth it sinks to), the deepest any stands in from the shore,
## the plate rect it lies in, the seconds sunk and to sink, and whether it
## sinks. `lift` follows the bed's middle down and `head` the hand's metres
## round the shore, for the tremor and the sound.
var _line_drawn := DrawnLine.new()
var _shore := PackedVector2Array()
var _shore_arc := PackedFloat32Array()
var _lake_bed: Array[Vector3] = []
var _deepest := 0.0
var _box := Rect2()
var _clock := 0.0
var _seconds := 0.0
var _sinking := false
var _shallow := false
var head := 0.0

func id() -> String: return "crater"
func modes() -> Array: return CRATER_MODES
func hover_gesture() -> String: return "pinch"
func stroke_radius() -> float: return float(CRATER.r0)*clay.size_scale
func mark_size() -> Vector2: return Vector2.ONE*float(CRATER.r0)
func _pinch_spec(fine: bool) -> Dictionary: return FINE_CRATER if fine else CRATER
func _pinch_verb(fine: bool) -> String: return "fine_crater" if fine else "crater"

## The pinch's hold, with the grip's kick turned down.
func hold_begin(fine: bool) -> String:
	var verb := super.hold_begin(fine)
	_lift_speed = -_lift_speed
	return verb

## The crater round the press, from `clay.base`, at the lift (never above 0).
func hold_step(heights: PackedFloat32Array, rise: float) -> bool:
	var spec: Dictionary = _pinch_spec(clay.verb == _pinch_verb(true))
	_follow(spec,rise)
	if is_equal_approx(lift,_shown_lift): return false
	_shown_lift = lift
	var radius: float = minf(float(spec.r0)+float(spec.grow)*absf(lift),float(spec.max_radius))*clay.size_scale
	var depth := maxf(-lift,0.0)
	var ground: Variant = clay.editor.data.sample(clay.center,clay.base)
	var thrown := minf(depth,maxf(float(ground)-clay.FLOOR,0.0)) if ground != null else depth
	var base: PackedFloat32Array = clay.base
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	for k in near.size():
		var i := near[k]
		var t: float = near_d[k]/radius
		var bowl := 1.0-smoothstep(CRATER_FLOOR,CRATER_RIM_AT,t)
		var rim := 0.0
		if t > CRATER_FLOOR and t < CRATER_RIM_OUT: rim = pow(sin(PI*(t-CRATER_FLOOR)/(CRATER_RIM_OUT-CRATER_FLOOR)),2.0)
		var h: float = base[i]+(thrown*CRATER_RIM*rim-depth*bowl)*clay.fade(i)
		if h < base[i]: h = maxf(h,minf(base[i],clay.FLOOR))
		heights[i] = clampf(h,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	clay.touch(clay.center,radius*CRATER_RIM_OUT)
	if depth > 0.0: clay.dirty(clay.center,radius*CRATER_RIM_AT)
	return true

## Let go: trees on the rim and walls that cannot hold them slide off.
func hold_end() -> void:
	clay.shake_trees(clay.center,float(CRATER.max_radius)*clay.size_scale*CRATER_RIM_OUT+1.0)

# --- Draw: the lake ---------------------------------------------------------------------

func reset() -> void:
	super.reset()
	_line_drawn.clear()

func drag_begin(fine: bool) -> String:
	_shallow = fine
	_line_drawn.begin(clay.center)
	return "shallow_lake" if fine else "lake"

## Nothing sinks while the shore is drawn: the path's points wait in the
## clay's queue and are read into the drawn line.
func drag_frame(_delta: float) -> bool:
	_line_drawn.take(clay)
	clay.hand_gesture(gesture(clay.verb),clay.ground_at(_line_drawn.end()))
	return false

func gesture(_verb: String) -> String: return "pinch"
func dab(_heights: PackedFloat32Array, _q: Vector2) -> float: return 0.0
## Run off the plate mid-draw: the shore simply stops where the land did.
func drag_off() -> void: pass

## The shore drawn so far (plate points, press first, the pointer last).
## Empty while none is being drawn (the ground marks show the line only then).
func drawn() -> PackedVector2Array:
	return PackedVector2Array() if _sinking else _line_drawn.path(clay)

## Let go: the outline is closed and the bed inside it planned, then sunk by
## `frame` inside the stroke's undo step, which the clay keeps open while it
## sinks.
func drag_end() -> bool:
	var path := drawn()
	_line_drawn.clear()
	if path.size() < 3: return false
	path.append(path[0])
	if absf(_area(path)) < LAKE_LEAST: return false
	_shore = path
	_shore_arc = Wire._arc(_shore)
	_plan_bed()
	if _lake_bed.is_empty(): return false
	lift = 0.0
	head = 0.0
	_clock = 0.0
	_seconds = clampf(_shore_arc[-1]/SINK_PACE,SINK_SECONDS.x,SINK_SECONDS.y)
	_sinking = true
	return false

## The outline the last lake sank inside (plate points, closed), for probes.
func lake_shore() -> PackedVector2Array:
	return _shore

func busy() -> bool: return _sinking or super.busy()
func drag_running() -> bool: return _sinking
## True while a drawn lake's bed sinks.
func growing() -> bool: return _sinking
## Where the hand stands on the shore as the bed sinks (plate).
func head_point() -> Vector2: return Wire._point_at(_shore,fmod(head,_shore_arc[-1])) if not _shore.is_empty() else clay.center

func frame(delta: float) -> void:
	super.frame(delta)
	if not _sinking: return
	_clock += delta
	var t := clampf(_clock/_seconds,0.0,1.0)
	if t >= 1.0:
		finish()
		return
	_sink(t)
	clay.hand_gesture(gesture(clay.verb),clay.ground_at(head_point()))

## The rest of the bed at once (it sank, an undo, a new press, a change of
## tool): all of it written, then its dirt, the strata on its banks, and the
## trees.
func finish() -> void:
	super.finish()
	if not _sinking: return
	_sink(1.0)
	_sinking = false
	var spread := maxf(_box.size.x,_box.size.y)*0.5
	clay.lay_dirt(_box.get_center(),spread)
	clay.paint_faces(_box)
	clay.show_land()
	clay.shake_trees(_box.get_center(),spread+1.0)

## The bed `t` of the way through its sink written to the land: each point
## that share of the way down, the banks (near the shore) ahead of the middle.
func _sink(t: float) -> void:
	var eased := Wire._ease(t)
	head = _shore_arc[-1]*eased
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	var base: PackedFloat32Array = clay.base
	var middle := 0.0
	for entry in _lake_bed:
		var i := int(entry.x)
		var lag := SINK_WAVE*entry.y/maxf(_deepest,0.01)
		var share := smoothstep(0.0,1.0,clampf((eased*(1.0+SINK_WAVE)-lag),0.0,1.0))
		heights[i] = lerpf(base[i],entry.z,share)
		middle = minf(middle,heights[i]-base[i])
	lift = middle
	data.heights = heights
	clay.touch(_box.get_center(),maxf(_box.size.x,_box.size.y)*0.5)
	clay.show_land()

## The bed inside `_shore`: a level floor LAKE_DEPTH (SHALLOW of it with
## Shift) under the shore's lowest ground, its banks rising to the shore over
## LAKE_BANK, eased out at the plate's edge (the clay's `fade`) and never
## below the clay's FLOOR or above the ground already there.
func _plan_bed() -> void:
	_lake_bed = []
	_deepest = 0.0
	var data: NativeTerrainData = clay.editor.data
	var base: PackedFloat32Array = clay.base
	var low := INF
	for p in _shore:
		var ground: Variant = data.sample(p,base)
		if ground != null: low = minf(low,float(ground))
	if low == INF: return
	var floor_h := low-LAKE_DEPTH*(SHALLOW if _shallow else 1.0)
	_box = Rect2(_shore[0],Vector2.ZERO)
	for p in _shore: _box = _box.expand(p)
	clay.gather(_box.get_center(),_box.size.length()*0.5+0.5)
	var points := data.points
	var inside: Array[Vector2] = []
	for i: int in clay.near:
		var p := points[i]
		if not _box.has_point(p) or not Geometry2D.is_point_in_polygon(p,_shore): continue
		var d := INF
		for j in range(_shore.size()-1): d = minf(d,p.distance_to(Geometry2D.get_closest_point_to_segment(p,_shore[j],_shore[j+1])))
		inside.append(Vector2(i,d))
		_deepest = maxf(_deepest,d)
	var bank := minf(LAKE_BANK*clay.size_scale,_deepest*LAKE_BANK_SHARE)
	for entry in inside:
		var i := int(entry.x)
		var goal := lerpf(base[i],floor_h,smoothstep(0.0,maxf(bank,0.01),entry.y)*clay.fade(i))
		goal = maxf(goal,minf(base[i],clay.FLOOR))
		goal = maxf(goal,NativeTerrainData.MIN_HEIGHT)
		if goal < base[i]: _lake_bed.append(Vector3(i,entry.y,goal))
	_box = _box.grow(1.0)

## The signed area of the closed outline `path` (square metres).
static func _area(path: PackedVector2Array) -> float:
	var sum := 0.0
	for j in range(path.size()-1): sum += path[j].cross(path[j+1])
	return sum*0.5

# --- The stand-in prop ------------------------------------------------------------------

## A faceted tamper: a wooden haft down to a broad, flat, round stone foot.
func build_prop() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(_prism(8),HAFT,Vector3(0.0,-0.12,0.0),Vector3(0.035,0.62,0.035)))
	root.add_child(part(_prism(8,0.9),STONE,Vector3(0.0,-0.5,0.0),Vector3(0.16,0.1,0.16)))
	return root
