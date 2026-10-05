extends "res://scripts/clay_tools/clay_tool.gd"
## The Ravine, "Carve" (docs/design/tools/PLAN.md; it keeps the id `wire`
## from when it was the Wire, so probes and the roll read as before): a taut
## wire between two wooden toggles, drawn through the land as a potter's wire
## goes through clay. It cuts; it never raises. Its one gesture is drawing a
## line (the user, 2026-10-02: drawing the line and watching it form the
## terrain was the fun; mountains are pulled, not drawn), so a press is a
## drag at once (`press_kind`) and it has no fan.
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
## - **A closed loop** (the path ends within LOOP_GAP of where it began, and
##   runs at least LOOP_MIN round) is a shore: a level basin sinks inside it
##   for a lake (`_plan_basin`), settling from its edge in.
## - **Shift** at the moment the drag is decided: a shallower gorge or basin
##   (SHALLOW of the depth).
##
## Each is one undo step, closed once its cut has run. The pips
## (clay.size_scale) scale the gorge's width and the basin's bank. Depth and
## wall steepness hold.
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
## Shift: the shallower share of the gorge's and the basin's depth.
const SHALLOW := 0.4
## The drawn path: a pointer point is kept once it is PATH_SPACING metres from
## the last one kept, and the kept points are smoothed SMOOTH_PASSES times
## (each interior point halfway to its neighbours' middle), the ends held.
const PATH_SPACING := 0.5
const SMOOTH_PASSES := 2
## Edge to edge: unlike the other tools the wire cuts at full depth to the
## plate's rim (no clay `fade`), and a drawn end within RIM_REACH metres of
## the rim, heading out (its last run's direction at least RIM_HEADING
## along the rim's outward normal), runs on out through the rim, to RIM_PAST
## beyond it, so a gorge drawn to the edge opens the plate's side. On an
## island with an outline (scripts/island_outline.gd) the shore is its rim:
## an end near the shore heading out runs on past it the same way, and the
## gorge opens the island's shore wall there.
const RIM_REACH := 2.5
const RIM_HEADING := 0.3
const RIM_PAST := 0.6
## A ravine run out through the rim keeps a sill: over its last RIM_SILL_RUN
## metres before the rim the bed climbs to RIM_SILL_DEPTH of the gorge's depth
## under the ground (none: the mouth's bed rises to the ground line, which the
## flow's cells read as a few cm under it), so the ravine fills to the brim. Water holds a hollow to its rim's
## lowest point (WaterFlow `hollow`), and a bed that fell to the open side held
## none: the can's gush found a few m3 and brimmed (tools/probe_ravine_fill.gd).
## With the sill the ravine fills to the notch, and what is poured past it
## spills off the plate's side as an edge fall.
const RIM_SILL_RUN := 3.0
const RIM_SILL_DEPTH := 0.0
## The cut drawn through: the head's pace in metres a second, the whole cut's
## least and most seconds, and how much of a smoothstep's ease-in-out is
## mixed into its even pace (0 even, 1 a full smoothstep).
const CUT_SPEED := 8.0
const CUT_SECONDS := Vector2(0.5,2.5)
const CUT_EASE := 0.5
## A loop: the drawn path's ends within LOOP_GAP m (at the middle pip) and
## its run at least LOOP_MIN m. Inside it the head runs on FILL_PACE m of
## arc for each metre in from the outline, so the inside settles edge first.
const LOOP_GAP := 2.0
const LOOP_MIN := 8.0
const FILL_PACE := 1.0
## The basin: BASIN_DEPTH under the outline's lowest ground, level, its banks
## rising to the outline over BASIN_BANK m (at most BASIN_BANK_SHARE of the
## way to its middle).
const BASIN_DEPTH := 2.4
const BASIN_BANK := 2.5
const BASIN_BANK_SHARE := 0.45
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
## No fan: the line is all it draws. A press is a drag from the start.
func press_kind() -> String: return "drag"
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
	if _closes(path):
		path[-1] = path[0]
		return path
	return _to_rim(path,clay.editor.data if clay != null else null)

## Whether `path` closes on itself: a loop, an outline (LOOP_GAP, LOOP_MIN).
func _closes(path: PackedVector2Array) -> bool:
	if path.size() < 4: return false
	var size: float = clay.size_scale if clay != null else 1.0
	return path[0].distance_to(path[-1]) <= LOOP_GAP*maxf(size,1.0) and _arc(path)[-1] >= LOOP_MIN

## `path` with each end near the rim (`data`'s shore, if it has an outline)
## and heading out run on through it.
static func _to_rim(path: PackedVector2Array, data: NativeTerrainData = null) -> PackedVector2Array:
	if path.size() < 2: return path
	var out := path.duplicate()
	var tail: Variant = _past_rim(path[-1],path[-2],data)
	if tail != null: out.append(tail)
	var head: Variant = _past_rim(path[0],path[1],data)
	if head != null: out.insert(0,head)
	return out

## Where the run from `from` through `end` leaves the plate RIM_PAST beyond
## its rim, or null when `end` is not near the rim or not heading out.
static func _past_rim(end: Vector2, from: Vector2, data: NativeTerrainData = null) -> Variant:
	if data != null and not data.outline.is_empty(): return _past_shore(end,from,data)
	var half: float = preload("res://scripts/land_clay.gd").PLATE_HALF
	if half-maxf(absf(end.x),absf(end.y)) > RIM_REACH or end.distance_to(from) < 0.01: return null
	var heading := (end-from).normalized()
	var outward := Vector2(signf(end.x),0.0) if absf(end.x) >= absf(end.y) else Vector2(0.0,signf(end.y))
	if heading.dot(outward) < RIM_HEADING: return null
	var reach := half+RIM_PAST
	var run := INF
	if absf(heading.x) > 0.001: run = minf(run,(signf(heading.x)*reach-end.x)/heading.x)
	if absf(heading.y) > 0.001: run = minf(run,(signf(heading.y)*reach-end.y)/heading.y)
	return end+heading*maxf(run,0.0)

## `_past_rim` on an island with an outline: the shore (its outward way
## from the distance to it) stands for the rim.
static func _past_shore(end: Vector2, from: Vector2, data: NativeTerrainData) -> Variant:
	var way: Vector3 = preload("res://scripts/land_clay.gd").edge_way(data,end)
	if way == Vector3.ZERO or way.z > RIM_REACH or end.distance_to(from) < 0.01: return null
	var heading := (end-from).normalized()
	if heading.dot(Vector2(way.x,way.y)) < RIM_HEADING: return null
	var run := 0.0
	while run < RIM_REACH+2.0 and data.ground_height(end+heading*run) != null: run += 0.1
	return end+heading*(run+RIM_PAST)

## Whether plate point `p` lies beyond the land's edge: past the plate's rim,
## or off the island's outline.
static func _past_edge(p: Vector2, data: NativeTerrainData) -> bool:
	if data.outline.is_empty():
		var half: float = preload("res://scripts/land_clay.gd").PLATE_HALF
		return maxf(absf(p.x),absf(p.y)) > half
	return data.ground_height(p) == null

## Let go: the cut is planned along the drawn path and drawn through the
## land by `frame`, inside the stroke's undo step, which the clay keeps open
## while it runs. Without `animate` it lands whole now.
func drag_end() -> bool:
	_path = drawn()
	var plan := _plan_basin(_path) if _path.size() > 3 and _path[0] == _path[-1] else _plan(_path)
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

## The running cut's whole length along its path, metres (scripts/clay_tremor.gd
## reads its head's travel as `cut_share` of it).
func cut_length() -> float:
	return _length

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
			var s := arc[j]+t
			var k := s/length*(bed.size()-1) if length > 0.001 else 0.0
			var floor_h := lerpf(bed[floori(k)],bed[mini(floori(k)+1,bed.size()-1)],k-floorf(k))
			var goal := floor_h if d <= bed_half else lerpf(floor_h,base[i],(d-bed_half)/WALL_RUN)
			goal = minf(goal,base[i])
			var h := maxf(goal,NativeTerrainData.MIN_HEIGHT)
			if h < base[i]: cuts.append(Vector3(s,i,h))
	# Vector3s sort by x first: by arc length.
	cuts.sort()
	return {"cuts":cuts,"length":length,"box":box.grow(top)}

## The basin inside a loop `path`: each point inside sunk toward a level
## floor BASIN_DEPTH under the outline's lowest ground, full past its bank
## (`_inside`); a lake's bed, its shore the outline. Points are cut once the
## outline's run is past, edge first.
func _plan_basin(path: PackedVector2Array) -> Dictionary:
	var base: PackedFloat32Array = clay.base
	var data: NativeTerrainData = clay.editor.data
	var arc := _arc(path)
	var length := arc[-1]
	var low := INF
	for k in range(path.size()):
		var ground: Variant = data.sample(path[k],base)
		if ground != null: low = minf(low,float(ground))
	if low == INF: return {"cuts":[],"length":0.0,"box":Rect2()}
	var floor_h := maxf(low-BASIN_DEPTH*(SHALLOW if _shallow else 1.0),NativeTerrainData.MIN_HEIGHT)
	var inside := _inside(path)
	var deepest: float = inside.deepest
	var bank := minf(BASIN_BANK*clay.size_scale,deepest*BASIN_BANK_SHARE)
	var cuts: Array = []
	for entry: Vector2 in inside.points:
		var i := int(entry.x)
		var goal := lerpf(base[i],floor_h,smoothstep(0.0,maxf(bank,0.01),entry.y))
		if goal < base[i]: cuts.append(Vector3(length+entry.y*FILL_PACE,i,goal))
	cuts.sort()
	return {"cuts":cuts,"length":length+deepest*FILL_PACE,"box":inside.box}

## The land's points inside a loop `path`: {"points": Vector2(point index,
## metres in from the outline), "deepest": the most metres in, "box"}.
func _inside(path: PackedVector2Array) -> Dictionary:
	var data: NativeTerrainData = clay.editor.data
	var points := data.points
	var box := Rect2(path[0],Vector2.ZERO)
	for p in path: box = box.expand(p)
	var found := []
	var deepest := 0.0
	clay.gather(box.get_center(),box.size.length()*0.5+0.5)
	for i: int in clay.near:
		var p := points[i]
		if not box.has_point(p) or not Geometry2D.is_point_in_polygon(p,path): continue
		var d := INF
		for j in range(path.size()-1): d = minf(d,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[j],path[j+1])))
		found.append(Vector2(i,d))
		deepest = maxf(deepest,d)
	return {"points":found,"deepest":deepest,"box":box.grow(1.0)}

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
	var grounds := PackedFloat32Array()
	grounds.resize(count)
	for k in count:
		var ground: Variant = data.sample(_point_at(path,step*k),base)
		if ground != null:
			last = float(ground)
			if not found:
				# Stations before the first on the land take its height.
				for j in k: bed[j] = last-depth
			found = true
		bed[k] = last-depth
		grounds[k] = last
	var forward := bed[0] >= bed[count-1]
	for n in range(1,count):
		var k := n if forward else count-1-n
		var before := k-1 if forward else k+1
		bed[k] = minf(bed[k],bed[before]-BED_FALL*step)
	# The sill at an end run out through the rim: the bed climbs to a notch.
	var open_head := _past_edge(path[0],data)
	var open_tail := _past_edge(path[-1],data)
	for k in count:
		var run := INF
		if open_head: run = step*k
		if open_tail: run = minf(run,length-step*k)
		if run >= RIM_SILL_RUN: continue
		var notch := grounds[k]-depth*RIM_SILL_DEPTH
		bed[k] = maxf(bed[k],lerpf(bed[k],notch,smoothstep(RIM_SILL_RUN,RIM_SILL_RUN*0.5,run)))
	for k in count: bed[k] = maxf(bed[k],NativeTerrainData.MIN_HEIGHT)
	return bed

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
