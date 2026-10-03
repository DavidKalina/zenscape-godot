extends "res://scripts/clay_tools/clay_tool.gd"
## The Island, "Isle": land put in a lake (the user, 2026-10-03: people will
## want little islands with trees on them, and pulling one up with the
## Modeller meant guessing how far under the water the surface was). Both
## modes build to the water, not to the press: whatever the lake's depth, the
## land comes up to FREEBOARD over its surface and stops there. Neither ever
## lowers ground, so drawing or spreading over an island already there
## extends it. Two modes, picked on its fan or with Q and E:
##
## - **Draw** (the first mode): draw round the island's shore and let go. The
##   outline closes and the land inside rises out of the lake, its middle
##   first and its shore last (RISE_WAVE), over RISE_SECONDS: a beach rising
##   FREEBOARD over BEACH metres in from the drawn line, which is the new
##   waterline, a low crown (CROWN, at most CROWN_SHARE of its depth in)
##   over the middle, and outside the line the lakebed shelving down at
##   SHELF_SLOPE until it meets the old bed. One undo step, closed once it
##   has risen; an undo, a new press, a change of tool or Esc mid-rise lands
##   the rest of it at once. An outline enclosing under ISLE_LEAST square
##   metres leaves the land alone. **Shift:** no crown, a flat low isle.
## - **Spread:** scrub to push land out from an island or a shore: the
##   ground under the brush rises toward a flat top FREEBOARD over the water,
##   SPREAD_CORE metres across, shelving down at SHELF_SLOPE out to
##   SPREAD_OUT past it, by how far the pointer travels (SPREAD_PER_METRE)
##   and, held still, slower (SPREAD_PER_SECOND), as the Hills rise. It cannot
##   overshoot the water. **Shift:** a narrower brush (FINE).
##
## The water to build to is the lake's near the press (`water_level`): the
## surface of the live water standing there, or in a dry hollow the level it
## would fill to (its sill), or with neither, the drawn shore's lowest ground
## (a Draw) or the press's ground (a Spread levels to it).
##
## The lake keeps its level: the water the new land displaces is taken away,
## not lifted onto the island (the user, the same day). The live water keeps
## each cell's depth when the ground under it moves, so a raised bed would
## carry the lake up with it and spill it over the rim. As the rise begins
## the water over the isle's ground is trimmed to the level, and when it ends
## (a Draw) or a Spread is let go the lake's whole basin is laid level at it
## (`_keep_level`). Not every frame: setting the depth stills all the plate's
## water at once.

const FREEBOARD := 0.35
const BEACH := 1.6
const CROWN := 1.4
const CROWN_SHARE := 0.3
const CROWN_LUMP := 0.25
const SHELF_SLOPE := 0.75
const SHELF_OUT := 8.0
const ISLE_LEAST := 3.0
const RISE_PACE := 14.0
const RISE_SECONDS := Vector2(0.8,2.4)
const RISE_WAVE := 0.6
const SPREAD_CORE := 2.2
const SPREAD_OUT := 5.0
const SPREAD_PER_METRE := 0.5
const SPREAD_PER_SECOND := 0.6
const FINE := 0.55
## Live water this deep stands as a lake; the lake's level is the middle
## surface of its deep cells (DEEP) within FIND metres, or of any wet ones.
const WET := 0.05
const DEEP := 0.2
const FIND := 8.0
## A dry hollow is built to only when its sill stands DRY_HOLLOW over the
## ground there.
const DRY_HOLLOW := 0.3
const ISLE_MODES := [{"id":"draw","kind":"drag"},{"id":"spread","kind":"paint"}]
const Wire = preload("res://scripts/clay_tools/wire.gd")
const DrawnLine = preload("res://scripts/clay_tools/drawn_line.gd")

## The stand-in: a faceted wooden scoop heaped with sand, in the icon's tint
## (scripts/hud_icons.gd "island").
const TINT := Color("b4a874")
const WOOD := Color("b98a58")
const TILT := -14.0

## The level built to this press, and whether it is live water's (only then
## is the lake trimmed back to it).
var level := 0.0
var on_water := false
## The drawn isle: the shore being drawn; once let go, the closed outline
## (with its arc lengths), each point it raises as Vector3(index, how soon it
## rises 0..1, the height it rises to), the plate rect it lies in, the
## seconds risen and to rise, and whether it rises. `lift` follows the
## highest point up and `head` the hand round the shore, for the tremor and
## the sound.
var _line_drawn := DrawnLine.new()
var _shore := PackedVector2Array()
var _shore_arc := PackedFloat32Array()
var _isle: Array[Vector3] = []
var _box := Rect2()
var _clock := 0.0
var _seconds := 0.0
var _rising := false
var _low := false
var head := 0.0
## The Spread: the pointer's last dab point.
var _last: Variant = null
var _noise := FastNoiseLite.new()

func id() -> String: return "island"
func modes() -> Array: return ISLE_MODES
func paints() -> bool: return mode == "spread"
func hover_gesture() -> String: return "press" if paints() else "pinch"
func gesture(_verb: String) -> String: return "press" if paints() else "pinch"
func prop_tilt() -> float: return TILT
func dirt_share(_verb: String) -> float: return 0.0
func stroke_radius() -> float: return SPREAD_CORE*clay.size_scale
func mark_size() -> Vector2: return Vector2.ONE*SPREAD_CORE

func reset() -> void:
	lift = 0.0
	_last = null
	_line_drawn.clear()

# --- The water --------------------------------------------------------------------------

## The live water (scripts/water_flow.gd), or null while there is none.
func _flow() -> RefCounted:
	var flow: Variant = clay.editor.get("flow")
	return flow if flow != null and bool(flow.ready) else null

## The level the lake round `at` stands at, looked for `reach` metres round
## it, into `level` and `on_water`. False when there is neither water nor a
## dry hollow there.
func water_level(at: Vector2, reach: float) -> bool:
	on_water = false
	var flow := _flow()
	if flow == null: return false
	var depth: PackedFloat32Array = flow.depths()
	var ground: PackedFloat32Array = flow.grounds()
	var deep := PackedFloat32Array()
	var wet := PackedFloat32Array()
	for c in _cells_round(flow,at,reach):
		if depth[c] >= DEEP: deep.append(ground[c]+depth[c])
		elif depth[c] >= WET: wet.append(ground[c]+depth[c])
	var surfaces := deep if not deep.is_empty() else wet
	if not surfaces.is_empty():
		surfaces.sort()
		level = surfaces[surfaces.size()/2]
		on_water = true
		return true
	var found: Dictionary = flow.hollow(at,ground)
	var here: Variant = clay.editor.data.sample(at,clay.base)
	if found.is_empty() or here == null or float(found.sill) < float(here)+DRY_HOLLOW: return false
	level = float(found.sill)
	return true

## The water grid's cells within `reach` of `at`.
static func _cells_round(flow: RefCounted, at: Vector2, reach: float) -> PackedInt32Array:
	var cells := PackedInt32Array()
	var cell: float = flow.cell
	var origin: Vector2 = flow.origin
	var width: int = flow.width
	var height: int = flow.height
	var low := Vector2i(((at-Vector2.ONE*reach-origin)/cell).floor()).clamp(Vector2i.ZERO,Vector2i(width-1,height-1))
	var high := Vector2i(((at+Vector2.ONE*reach-origin)/cell).floor()).clamp(Vector2i.ZERO,Vector2i(width-1,height-1))
	for j in range(low.y,high.y+1):
		for i in range(low.x,high.x+1):
			if (origin+Vector2(i+0.5,j+0.5)*cell).distance_to(at) <= reach: cells.append(j*width+i)
	return cells

## The lake round `area` kept at `level`, the ground read from `heights`
## inside `area` (where the land has moved or will) and the water's own
## elsewhere. Every cell inside `area` keeps no more than the level over its
## ground, so the water the new land displaces goes rather than spilling.
## `settle` (the stroke is done) lays the whole lake level too: every cell
## of its basin (the water's `hollow` from the deepest water in `area`)
## stands at the level, at most the basin's sill, filled as well as
## trimmed. Trimming alone would cut the crests of the waves the rising land
## set going and leave their troughs, and the lake would end low. Nothing
## when the level was not live water's.
func _keep_level(area: Rect2, heights: PackedFloat32Array, settle: bool) -> void:
	var flow := _flow()
	if flow == null or not on_water: return
	var depth: PackedFloat32Array = flow.depths()
	var ground: PackedFloat32Array = flow.grounds()
	var data: NativeTerrainData = clay.editor.data
	var cell: float = flow.cell
	var origin: Vector2 = flow.origin
	var width: int = flow.width
	var height: int = flow.height
	var low := Vector2i(((area.position-origin)/cell).floor()).clamp(Vector2i.ZERO,Vector2i(width-1,height-1))
	var high := Vector2i(((area.end-origin)/cell).floor()).clamp(Vector2i.ZERO,Vector2i(width-1,height-1))
	var deepest := -1
	for j in range(low.y,high.y+1):
		for i in range(low.x,high.x+1):
			var c := j*width+i
			var now: Variant = data.sample(origin+Vector2(i+0.5,j+0.5)*cell,heights)
			if now != null: ground[c] = float(now)
			if deepest < 0 or depth[c] > depth[deepest]: deepest = c
			depth[c] = minf(depth[c],maxf(level-ground[c],0.0))
	if settle and deepest >= 0:
		var found: Dictionary = flow.hollow(origin+Vector2(deepest%width+0.5,deepest/width+0.5)*cell,ground)
		if not found.is_empty():
			var top := minf(level,float(found.sill))
			for c: int in found.cells: depth[c] = maxf(top-ground[c],0.0)
	flow.kernel.set_depth(depth)

# --- Draw: the isle -----------------------------------------------------------------------

func drag_begin(fine: bool) -> String:
	_low = fine
	_line_drawn.begin(clay.center)
	return "low_island" if fine else "island"

## Nothing rises while the shore is drawn: the path's points wait in the
## clay's queue and are read into the drawn line.
func drag_frame(_delta: float) -> bool:
	_line_drawn.take(clay)
	clay.hand_gesture(gesture(clay.verb),clay.ground_at(_line_drawn.end()))
	return false

func dab(_heights: PackedFloat32Array, _q: Vector2) -> float: return 0.0
func drag_off() -> void: pass

## The shore drawn so far (plate points, press first, the pointer last).
## Empty while none is being drawn (the ground marks show the line only then).
func drawn() -> PackedVector2Array:
	return PackedVector2Array() if _rising else _line_drawn.path(clay)

## Let go: the outline is closed and the isle planned, the lake let down
## where it will stand, and the land raised by `frame` inside the stroke's
## undo step, which the clay keeps open while it rises.
func drag_end() -> bool:
	var path := drawn()
	_line_drawn.clear()
	if path.size() < 3: return false
	path.append(path[0])
	if absf(_area(path)) < ISLE_LEAST: return false
	_shore = path
	_shore_arc = Wire._arc(_shore)
	_plan_isle()
	if _isle.is_empty(): return false
	_keep_level(_box,_risen(),false)
	lift = 0.0
	head = 0.0
	_clock = 0.0
	_seconds = clampf(_shore_arc[-1]/RISE_PACE,RISE_SECONDS.x,RISE_SECONDS.y)
	_rising = true
	return false

## The outline the last isle rose inside (plate points, closed), for probes.
func isle_shore() -> PackedVector2Array:
	return _shore

func busy() -> bool: return _rising
func drag_running() -> bool: return _rising
## True while a drawn isle rises.
func growing() -> bool: return _rising
## Where the hand stands on the shore as the isle rises (plate).
func head_point() -> Vector2: return Wire._point_at(_shore,fmod(head,_shore_arc[-1])) if not _shore.is_empty() else clay.center

func frame(delta: float) -> void:
	if not _rising: return
	_clock += delta
	var t := clampf(_clock/_seconds,0.0,1.0)
	if t >= 1.0:
		finish()
		return
	_rise(t)
	clay.hand_gesture(gesture(clay.verb),clay.ground_at(head_point()))

## The rest of the isle at once (it rose, an undo, a new press, a change of
## tool): all of it written, the lake trimmed to its level, the faces on its
## banks and the trees.
func finish() -> void:
	if not _rising: return
	_rise(1.0)
	_rising = false
	_keep_level(_box,clay.editor.data.heights,true)
	clay.paint_faces(_box)
	clay.show_land()
	clay.shake_trees(_box.get_center(),maxf(_box.size.x,_box.size.y)*0.5+1.0)

## The isle `t` of the way through its rise written to the land: each point
## that share of the way up, the middle ahead of the shore.
func _rise(t: float) -> void:
	var eased := Wire._ease(t)
	head = _shore_arc[-1]*eased
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	var base: PackedFloat32Array = clay.base
	var most := 0.0
	for entry in _isle:
		var i := int(entry.x)
		var share := smoothstep(0.0,1.0,clampf(eased*(1.0+RISE_WAVE)-RISE_WAVE*entry.y,0.0,1.0))
		heights[i] = lerpf(base[i],entry.z,share)
		most = maxf(most,heights[i]-base[i])
	lift = most
	data.heights = heights
	clay.touch(_box.get_center(),maxf(_box.size.x,_box.size.y)*0.5)
	clay.show_land()

## The land as it will stand once the isle has risen.
func _risen() -> PackedFloat32Array:
	var heights: PackedFloat32Array = clay.base.duplicate()
	for entry in _isle: heights[int(entry.x)] = entry.z
	return heights

## The isle inside `_shore`, built to the water (`water_level`) or, with
## none, to the shore's lowest ground: FREEBOARD over it at BEACH metres in
## from the shore, a crown over the middle, and the bed shelving down at
## SHELF_SLOPE outside it, eased out at the plate's edge (the clay's
## `fade`), only where it stands over the ground already there.
func _plan_isle() -> void:
	_isle = []
	var data: NativeTerrainData = clay.editor.data
	var base: PackedFloat32Array = clay.base
	_box = Rect2(_shore[0],Vector2.ZERO)
	for p in _shore: _box = _box.expand(p)
	if not water_level(_box.get_center(),_box.size.length()*0.5+1.0):
		var low := INF
		for p in _shore:
			var ground: Variant = data.sample(p,base)
			if ground != null: low = minf(low,float(ground))
		if low == INF: return
		level = low
	var reach := _box.grow(SHELF_OUT)
	clay.gather(reach.get_center(),reach.size.length()*0.5)
	var points := data.points
	var placed: Array[Vector2] = []
	var deepest := 0.0
	for i: int in clay.near:
		var p := points[i]
		if not reach.has_point(p): continue
		var d := INF
		for j in range(_shore.size()-1): d = minf(d,p.distance_to(Geometry2D.get_closest_point_to_segment(p,_shore[j],_shore[j+1])))
		if d > SHELF_OUT: continue
		if Geometry2D.is_point_in_polygon(p,_shore): deepest = maxf(deepest,d)
		else: d = -d
		placed.append(Vector2(i,d))
	_noise.seed = int(clay.editor.land_seed)
	_noise.frequency = 0.18
	var crown := 0.0 if _low else minf(CROWN*clay.size_scale,deepest*CROWN_SHARE)
	for entry in placed:
		var i := int(entry.x)
		var d := entry.y
		var goal: float
		if d >= 0.0:
			var middle := smoothstep(0.0,1.0,(d-BEACH)/maxf(deepest-BEACH,0.01))
			var p := points[i]
			goal = level+FREEBOARD*smoothstep(0.0,BEACH,d)+crown*middle*(1.0+CROWN_LUMP*_noise.get_noise_2d(p.x,p.y))
		else:
			goal = level+d*SHELF_SLOPE
		goal = minf(base[i]+maxf(goal-base[i],0.0)*clay.fade(i),NativeTerrainData.MAX_HEIGHT)
		if goal <= base[i]+0.01: continue
		# The middle rises first: how soon by how far in from the shelf's foot.
		var soon := clampf((d+SHELF_OUT)/(maxf(deepest,0.01)+SHELF_OUT),0.0,1.0)
		_isle.append(Vector3(i,1.0-soon,goal))
		_box = _box.expand(points[i])
	_box = _box.grow(1.0)

## The signed area of the closed outline `path` (square metres).
static func _area(path: PackedVector2Array) -> float:
	var sum := 0.0
	for j in range(path.size()-1): sum += path[j].cross(path[j+1])
	return sum*0.5

# --- Spread --------------------------------------------------------------------------------

func _size() -> float: return clay.size_scale*(FINE if clay.verb == "fine_spread" else 1.0)

## The press finds the water it builds to: the lake's near it, or a dry
## hollow's sill, or the press's own ground.
func paint_begin(fine: bool) -> String:
	if not water_level(clay.center,FIND):
		var here: Variant = clay.editor.data.sample(clay.center,clay.base)
		level = (float(here) if here != null else 0.0)-FREEBOARD
	return "fine_spread" if fine else "spread"

## `work` seconds and the travel since the last dab at `q`: the ground round
## it rises toward the flat top and its shelf, never over them.
func paint_dab(heights: PackedFloat32Array, q: Vector2, work: float) -> float:
	var travelled: float = q.distance_to(_last) if _last != null else 0.0
	_last = q
	var share := clampf(SPREAD_PER_METRE*travelled+SPREAD_PER_SECOND*work,0.0,1.0)
	if share <= 0.0: return 0.0
	var size := _size()
	var core := SPREAD_CORE*size
	var reach := core+SPREAD_OUT
	var top := level+FREEBOARD
	clay.gather(q,reach)
	clay.touch(q,reach)
	for k in clay.near.size():
		var i: int = clay.near[k]
		var r: float = clay.near_d[k]
		var goal := minf(top-SHELF_SLOPE*maxf(r-core,0.0),NativeTerrainData.MAX_HEIGHT)
		if goal <= heights[i]: continue
		heights[i] = lerpf(heights[i],goal,share*clay.fade(i))
		lift = maxf(lift,heights[i]-clay.base[i])
	return 0.0

## Let go: the lake trimmed to its level, the faces on the new banks, and
## trees that cannot hold them slide down.
func paint_end(_tapped: bool) -> void:
	var area: Rect2 = clay.touched()
	if not area.has_area(): return
	_keep_level(area,clay.editor.data.heights,true)
	clay.paint_faces(area)
	clay.shake_trees(Vector2.ZERO,0.0,area)

# --- The stand-in prop ------------------------------------------------------------------

## A faceted scoop: a wooden handle down to a shallow bowl heaped with sand.
func build_prop() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(_prism(8),WOOD,Vector3(0.0,-0.1,0.0),Vector3(0.035,0.6,0.035)))
	root.add_child(part(_prism(8,0.6),WOOD.darkened(0.15),Vector3(0.0,-0.46,0.0),Vector3(0.15,0.08,0.15)))
	root.add_child(part(_prism(7,1.6),TINT,Vector3(0.0,-0.4,0.0),Vector3(0.09,0.06,0.09)))
	return root

## An upright n-sided prism, unit radius and height, tapering to `foot` of
## its radius at the bottom.
static func _prism(sides: int, foot := 1.0) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = foot
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh
