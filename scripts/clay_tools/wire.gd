extends "res://scripts/clay_tools/clay_tool.gd"
## The Wire, "Slice" (docs/design/tools/PLAN.md): a taut wire between two
## wooden toggles, drawn through the land as a potter's wire goes through clay.
## It cuts; it never raises.
##
## - **Drag (press, drag, release):** a gorge along the path the pointer drew,
##   bends and all. The path is the pointer's ground points kept PATH_SPACING
##   apart and smoothed a little (`drawn`), so the hand's jitter does not
##   wiggle the gorge but a deliberate curve stays. While the drag lasts the
##   land is untouched: the ground marks' faint line (scripts/ground_marks.gd)
##   follows the drawn path to the pointer. Let go, the wire is drawn through
##   the clay along it from the press to the release: the cut is carved behind
##   a head running CUT_SPEED metres a second (the whole taking CUT_SECONDS,
##   eased by CUT_EASE so it has a pull to it), and the prop rides the head
##   down in the cut, then goes back to the pointer. The land it leaves is the
##   one `cut_gorge` writes at once along the same path; an undo, a new press,
##   a change of tool or Esc mid-cut lands the rest of it at once (`finish`).
## - **Hold, then drag up or down:** a slice. Everything within SLICE_RADIUS of
##   the press that stands above a level plane is cut down to it: a hilltop
##   sliced off flat. The plane starts at the ground under the press and
##   follows the pointer's height, as the pinch's summit does, so dragging
##   down takes more of the hill.
## - **Tap:** nothing yet.
## - **Shift** at the moment the verb is decided: a shallower gorge (SHALLOW of
##   the depth), and a slice whose plane follows the pointer at SHALLOW of the
##   pace, so it takes a thinner cut for the same pull.
##
## Each is one undo step (the gorge's closes once its cut has run). The pips
## (clay.size_scale) scale the reach: the gorge's width and the slice's
## radius. Depth and wall steepness hold.
##
## ### The gorge
##
## Across, a flat bed BED_HALF metres either side of the path, then a wall
## rising to the untouched ground over WALL_RUN metres: under the land's point
## spacing (0.45 to 0.75 m), so each wall is one facet row, as steep as the
## points allow. Across is distance to the path, so the ends are round and a
## bend is a round-cornered channel. Along, working in arc length along the
## path, the bed is GORGE_DEPTH under the ground where it starts, and it never
## climbs: from its high end it falls at least BED_FALL metres per metre,
## cutting deeper where the ground rises under the path, so water (the
## shallow-water sim) runs the length of it. Across a dip the far side is cut
## down to the dip's level, as a river's canyon cuts through the ridge beyond
## it. Where the path crosses itself the deeper cut wins. The land's
## MIN_HEIGHT stops it; a drag is a stroke, as the thumb's groove is, so it is
## not held to the clay's sink FLOOR.
##
## As the head passes, the dug ground shows the stratum it reached (the
## clay's dirt, scripts/strata.gd); once the cut has run, the walls take the
## strata on their steeps, a shade darker (clay.paint_faces, by slope alone on
## cut ground), so the bed reads as its band and the walls as banded faces,
## and trees on ground the cut moved that cannot hold it slide off. The faces
## wait for the end because it reads the
## slope round each cell, which the head's own round end would get wrong,
## and a tree sliding mid-cut would stop the clay's light refresh.
const BED_HALF := 1.1
const WALL_RUN := 0.35
const GORGE_DEPTH := 2.6
const BED_FALL := 0.02
## Metres between the stations the bed's fall is worked out on.
const STATION := 0.25
## Shift: the shallower share (of the gorge's depth, of the slice's pace).
const SHALLOW := 0.4
## The drawn path: a pointer point is kept once it is PATH_SPACING metres from
## the last one kept, and the kept points are smoothed SMOOTH_PASSES times
## (each interior point halfway to its neighbours' middle), the ends held.
const PATH_SPACING := 0.5
const SMOOTH_PASSES := 2
## The cut drawn through: the head's pace in metres a second, the whole cut's
## least and most seconds, and how much of a smoothstep's ease-in-out is
## mixed into its even pace (0 even, 1 a full smoothstep).
const CUT_SPEED := 8.0
const CUT_SECONDS := Vector2(0.5,2.5)
const CUT_EASE := 0.5
## The slice: radius in metres at the middle pip; the plane rises and falls
## with the pointer's travel at SLICE_SCALE metres per metre standing at the
## press, between SLICE_SINK below and SLICE_RAISE above the pressed ground.
## Inside the radius the cut is a hard, level plane: a wire does not feather.
## A hill wider than the radius is left a step at its rim, which the rock
## paint takes as a cliff.
const SLICE_RADIUS := 7.0
const SLICE_SCALE := 1.0
const SLICE_SINK := 6.0
const SLICE_RAISE := 8.0
## The stand-in prop, metres at the hand's own size: two hexagonal toggles in
## the icon's tint (scripts/hud_icons.gd "wire"), darker end caps, and a thin
## lighter wire between them hanging down from the one in the grip.
const TINT := Color("b8683f")
const CAP := Color("8a4a2c")
const WIRE := Color("e6c3a4")
const TOGGLE := Vector3(0.34,0.075,0.075)
const WIRE_LENGTH := 1.05
const WIRE_THICK := 0.012

var _shallow := false
var _shown_level := INF
var _level_at := 0.0
## False cuts the gorge whole at release, with no drawing through (for probes).
var animate := true
## The drawn path: the points kept, how many of the clay's queued points have
## been read, and the pointer's last ground point.
var _kept := PackedVector2Array()
var _taken := 0
var _end := Vector2.ZERO
## The cut running: its path, the plan (`_plan`), the next cut to lay, the
## seconds run and to run, and whether it runs.
var _path := PackedVector2Array()
var _cuts: Array = []
var _next := 0
var _length := 0.0
var _box := Rect2()
var _clock := 0.0
var _seconds := 0.0
var _running := false

## The fan's modes (clay_tool `modes`): the gorge and the slice.
const MODES := [{"id":"gorge","kind":"drag"},{"id":"slice","kind":"hold"}]
func modes() -> Array: return MODES
func id() -> String: return "wire"
func stroke_radius() -> float: return (BED_HALF+WALL_RUN)*clay.size_scale

func reset() -> void:
	lift = 0.0
	_shallow = false
	_kept = PackedVector2Array()
	_taken = 0

# --- Drag: the gorge -----------------------------------------------------------------

func drag_begin(fine: bool) -> String:
	_shallow = fine
	_kept = PackedVector2Array([clay.center])
	_taken = 0
	_end = clay.center
	return "shallow_gorge" if fine else "gorge"

## Nothing is laid while the wire is drawn: the path's points wait in the
## clay's queue and are read into the drawn path. The hand follows the pointer.
func drag_frame(_delta: float) -> bool:
	_take()
	clay.hand_gesture(gesture(clay.verb),clay.ground_at(_end))
	return false

## The pointer's new ground points into the path: kept PATH_SPACING apart.
func _take() -> void:
	if _kept.is_empty(): return
	var queued: PackedVector2Array = clay.queued()
	for k in range(_taken,queued.size()):
		_end = queued[k]
		if _end.distance_to(_kept[-1]) >= PATH_SPACING: _kept.append(_end)
	_taken = queued.size()

## The path drawn so far (plate points, press first, the pointer last): the
## kept points and the pointer's own, smoothed so the hand's jitter goes and
## its bends stay. Empty before a gorge is drawn.
func drawn() -> PackedVector2Array:
	if _kept.is_empty(): return PackedVector2Array()
	_take()
	var path := _kept.duplicate()
	# The pointer's point ends it: it stands in for a kept point too near it.
	if path.size() > 1 and _end.distance_to(path[-1]) < PATH_SPACING*0.5: path[-1] = _end
	elif _end.distance_to(path[-1]) > 0.01: path.append(_end)
	for n in SMOOTH_PASSES:
		var was := path.duplicate()
		for k in range(1,path.size()-1): path[k] = was[k]*0.5+(was[k-1]+was[k+1])*0.25
	return path

## Let go: the cut is planned along the drawn path and drawn through the
## land by `frame`, inside the stroke's undo step, which the clay keeps open
## while it runs. Without `animate` it lands whole now.
func drag_end() -> bool:
	_path = drawn()
	var plan := _plan(_path)
	_cuts = plan.cuts
	_length = plan.length
	_box = plan.box
	_next = 0
	_clock = 0.0
	_seconds = clampf(_length/CUT_SPEED,CUT_SECONDS.x,CUT_SECONDS.y)
	_running = true
	if _length > 0.0: clay.sound(&"wire_start",_path[0])
	if not animate: finish()
	return false

## The path the last cut ran along (plate points), for probes.
func cut_path() -> PackedVector2Array:
	return _path

## How far along its path the running cut's head is, 0..1 (1 when none runs).
func cut_share() -> float:
	if not _running: return 1.0
	return _ease(clampf(_clock/_seconds,0.0,1.0))

func busy() -> bool: return _running
func drag_running() -> bool: return _running

## The head runs on: the cuts it has passed are laid, the land shown, and the
## prop rides it down in the cut. Once it reaches the end the cut is finished.
func frame(delta: float) -> void:
	if not _running: return
	_clock += delta
	var t := clampf(_clock/_seconds,0.0,1.0)
	if t >= 1.0:
		finish()
		return
	var head := _length*_ease(t)
	_lay(head)
	clay.hand_gesture(gesture(clay.verb),clay.ground_at(_point_at(_path,head)))

## The rest of the cut at once (the head reached the end, an undo, a new
## press, a change of tool): every cut laid, then the dirt over the whole of
## it, the rock over that, and the trees.
func finish() -> void:
	if not _running: return
	_lay(INF)
	_running = false
	var spread := maxf(_box.size.x,_box.size.y)*0.5
	clay.touch(_box.get_center(),spread)
	clay.lay_dirt(_box.get_center(),spread)
	clay.sound(&"crumble",_box.get_center(),_length/20.0)
	clay.paint_faces(_box)
	clay.show_land()
	clay.shake_trees(clay.center,0.0,clay.touched())

## Lay every planned cut the head has passed (arc length up to `head`),
## write the land, lay the dirt under them and show it. Only the points cut
## this frame are written; the rest of the land is as it was.
func _lay(head: float) -> void:
	if _next >= _cuts.size(): return
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	var points := data.points
	var area := Rect2()
	var first := true
	while _next < _cuts.size() and (_cuts[_next] as Vector3).x <= head:
		var cut: Vector3 = _cuts[_next]
		var i := int(cut.y)
		heights[i] = minf(heights[i],cut.z)
		area = Rect2(points[i],Vector2.ZERO) if first else area.expand(points[i])
		first = false
		_next += 1
	if first: return
	data.heights = heights
	var spread := maxf(area.size.x,area.size.y)*0.5+NativeTerrainData.MEADOW_STEP
	clay.touch(area.get_center(),spread)
	clay.lay_dirt(area.get_center(),spread)
	clay.show_land()

## The head's share of the path at `t` of the cut's seconds: even, with
## CUT_EASE of a smoothstep mixed in.
static func _ease(t: float) -> float:
	return lerpf(t,smoothstep(0.0,1.0,t),CUT_EASE)

## The gorge along `path` (plate points) written into `heights` at once, from
## the clay's base: the land a drawn-through cut along it leaves. Returns the
## plate rect it may have taken down.
func cut_gorge(heights: PackedFloat32Array, path: PackedVector2Array) -> Rect2:
	var plan := _plan(path)
	for cut: Vector3 in plan.cuts:
		var i := int(cut.y)
		heights[i] = minf(heights[i],cut.z)
	return plan.box

## Every cut the gorge along `path` makes, from the clay's base: {"cuts":
## Vector3(arc length where the wire passes, point index, height) sorted by
## arc length, "length": the path's in metres, "box": the plate rect they
## lie in}. A point near more than one stretch of the path (a bend, a
## crossing) has a cut from each; the lowest stands.
func _plan(path: PackedVector2Array) -> Dictionary:
	var base: PackedFloat32Array = clay.base
	var data: NativeTerrainData = clay.editor.data
	var bed_half: float = BED_HALF*clay.size_scale
	var top := bed_half+WALL_RUN
	var depth := GORGE_DEPTH*(SHALLOW if _shallow else 1.0)
	if path.size() == 1: path = PackedVector2Array([path[0],path[0]])
	var arc := _arc(path)
	var length := arc[-1]
	var bed := _bed(path,arc,depth)
	var points := data.points
	var cuts: Array = []
	var box := Rect2(path[0],Vector2.ZERO)
	for j in range(path.size()-1):
		var a := path[j]
		var b := path[j+1]
		var run := a.distance_to(b)
		var along := (b-a)/run if run > 0.001 else Vector2.ZERO
		box = box.expand(b)
		clay.gather((a+b)*0.5,run*0.5+top)
		for i: int in clay.near:
			var p := points[i]
			var t := clampf((p-a).dot(along),0.0,run)
			var d := p.distance_to(a+along*t)
			if d >= top: continue
			var fade: float = clay.fade(i)
			if fade <= 0.0: continue
			var s := arc[j]+t
			var k := s/length*(bed.size()-1) if length > 0.001 else 0.0
			var floor_h := lerpf(bed[floori(k)],bed[mini(floori(k)+1,bed.size()-1)],k-floorf(k))
			var goal := floor_h if d <= bed_half else lerpf(floor_h,base[i],(d-bed_half)/WALL_RUN)
			goal = minf(goal,base[i])
			var h := maxf(lerpf(base[i],goal,fade),NativeTerrainData.MIN_HEIGHT)
			if h < base[i]: cuts.append(Vector3(s,i,h))
	# Vector3s sort by x first: by arc length.
	cuts.sort()
	return {"cuts":cuts,"length":length,"box":box.grow(top)}

## Arc length at each point of `path`.
static func _arc(path: PackedVector2Array) -> PackedFloat32Array:
	var arc := PackedFloat32Array([0.0])
	for j in range(1,path.size()): arc.append(arc[-1]+path[j-1].distance_to(path[j]))
	return arc

## The plate point `s` metres along `path`.
static func _point_at(path: PackedVector2Array, s: float) -> Vector2:
	var at := 0.0
	for j in range(path.size()-1):
		var run := path[j].distance_to(path[j+1])
		if s <= at+run and run > 0.0: return path[j].lerp(path[j+1],(s-at)/run)
		at += run
	return path[-1]

## The bed's height at stations STATION apart along `path` (by arc length
## `arc`): `depth` under the ground, falling at least BED_FALL per metre from
## the higher end, never climbing, and never under MIN_HEIGHT.
func _bed(path: PackedVector2Array, arc: PackedFloat32Array, depth: float) -> PackedFloat32Array:
	var base: PackedFloat32Array = clay.base
	var data: NativeTerrainData = clay.editor.data
	var length := arc[-1]
	var count := maxi(ceili(length/STATION),1)+1
	var step := length/(count-1)
	var bed := PackedFloat32Array()
	bed.resize(count)
	var last := 0.0
	var found := false
	for k in count:
		var ground: Variant = data.sample(_point_at(path,step*k),base)
		if ground != null:
			last = float(ground)
			if not found:
				# Stations before the first on the land take its height.
				for j in k: bed[j] = last-depth
			found = true
		bed[k] = last-depth
	var forward := bed[0] >= bed[count-1]
	for n in range(1,count):
		var k := n if forward else count-1-n
		var before := k-1 if forward else k+1
		bed[k] = minf(bed[k],bed[before]-BED_FALL*step)
	for k in count: bed[k] = maxf(bed[k],NativeTerrainData.MIN_HEIGHT)
	return bed

# --- Hold: the slice -----------------------------------------------------------------

func hold_begin(fine: bool) -> String:
	_shallow = fine
	var ground: Variant = clay.editor.data.sample(clay.center,clay.base)
	_level_at = float(ground) if ground != null else 0.0
	clay.gather(clay.center,SLICE_RADIUS*clay.size_scale)
	_shown_level = INF
	return "shallow_slice" if fine else "slice"

## The plane at the pressed ground plus the pointer's travel; every gathered
## point above it is cut down to it.
func hold_step(heights: PackedFloat32Array, rise: float) -> bool:
	lift = clampf(rise*SLICE_SCALE*(SHALLOW if _shallow else 1.0),-SLICE_SINK,SLICE_RAISE)
	var level := maxf(_level_at+lift,NativeTerrainData.MIN_HEIGHT)
	if is_equal_approx(level,_shown_level): return false
	_shown_level = level
	var base: PackedFloat32Array = clay.base
	var near: PackedInt32Array = clay.near
	var radius: float = SLICE_RADIUS*clay.size_scale
	for i in near:
		heights[i] = base[i] if base[i] <= level else lerpf(base[i],level,clay.fade(i))
	clay.touch(clay.center,radius)
	clay.dirty(clay.center,radius)
	return true

## The level the slice stands at, in metres (for probes).
func slice_level() -> float:
	return _shown_level

func hold_end() -> void:
	var radius: float = SLICE_RADIUS*clay.size_scale
	var reach := radius+1.0
	clay.paint_faces(Rect2(clay.center-Vector2.ONE*reach,Vector2.ONE*reach*2.0))
	clay.shake_trees(clay.center,reach)

# --- The stand-in prop ------------------------------------------------------------------

## Faceted toggles from primitives: one across the grip, a thin wire hanging
## from its middle down -Y, and the other toggle at the wire's foot, both in
## the icon's tint with darker end caps. Untilted: the wire hangs plumb.
## Replaced by the Blender wire's glb later: only this function changes.
func build_prop() -> Node3D:
	var root := Node3D.new()
	var across := Vector3(0.0,0.0,PI*0.5)
	root.add_child(part(_prism(4),WIRE,Vector3(0.0,-WIRE_LENGTH*0.5,0.0),Vector3(WIRE_THICK,WIRE_LENGTH,WIRE_THICK)))
	for y in [0.0,-WIRE_LENGTH]:
		for side in [-1.0,1.0]:
			root.add_child(part(_prism(6),CAP,Vector3(side*TOGGLE.x*0.5,y,0.0),Vector3(TOGGLE.y*1.12,0.045,TOGGLE.z*1.12),across))
	root.add_child(part(_prism(6,0.8),TINT,Vector3.ZERO,Vector3(TOGGLE.y,TOGGLE.x,TOGGLE.z),across))
	root.add_child(part(_prism(6,0.8),TINT,Vector3(0.0,-WIRE_LENGTH,0.0),Vector3(TOGGLE.y,TOGGLE.x,TOGGLE.z),across))
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
