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
## - **Drag, with another mode on the fan:** the same drawn path builds instead
##   of cutting (`_plan_range`, `_plan_hill`, `_plan_plants`), raised behind
##   the same running head: **Range**, a line of jagged peaks along the path;
##   **Hill**, a soft rolling ridge; **Trees**, a row of the land's own trees;
##   **Flowers**, a narrow border of wildflowers. The user, 2026-10-02: "Would
##   be cool to trace what you want. Same tool. Draw a ravine, draw a mountain
##   range, draw a hill, hell, maybe draw a line of flowers, trees."
## - **A closed loop** (the path ends within LOOP_GAP of where it began, and
##   runs at least LOOP_MIN round) is an outline: the Gorge sinks a level
##   basin inside it for a lake (`_plan_basin`), the Hill raises one rounded
##   hill filling it (`_plan_mound`), the Range stands a ring of peaks along
##   it. The outline is built first, then the inside settles from its edge in.
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
## Edge to edge: unlike the other tools the wire cuts at full depth to the
## plate's rim (no clay `fade`), and a drawn end within RIM_REACH metres of
## the rim, heading out (its last run's direction at least RIM_HEADING
## along the rim's outward normal), runs on out through the rim, to RIM_PAST
## beyond it, so a gorge drawn to the edge opens the plate's side.
const RIM_REACH := 2.5
const RIM_HEADING := 0.3
const RIM_PAST := 0.6
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
## The range: summits RANGE_HEIGHT m over the ground at the middle pip,
## RANGE_HALF m either side of the path at their feet, every RANGE_SPACING m
## along it (slipped by up to RANGE_SLIP of that), each RANGE_TALL of the
## tallest; between them the crest at RANGE_SADDLE of the summits, serrated;
## an open range tapers RANGE_TAPER lower at its ends. Shift: LOW of it all
## but the spacing.
const RANGE_HEIGHT := 8.5
const RANGE_HALF := 3.4
const RANGE_SPACING := 4.0
const RANGE_SLIP := 0.25
const RANGE_TALL := Vector2(0.72,1.0)
const RANGE_SADDLE := 0.55
const RANGE_TAPER := 0.4
const LOW := 0.45
## The hill: a soft ridge HILL_HEIGHT m over the ground and HILL_HALF m either
## side of the path, its crest rolling by HILL_ROLL. A loop's hill stands
## MOUND_SLOPE m for each metre the outline's middle lies in from it, between
## MOUND_HEIGHT.x and .y m. Shift: LOW of the height.
const HILL_HEIGHT := 2.4
const HILL_HALF := 4.0
const HILL_ROLL := 0.2
const MOUND_SLOPE := 0.5
const MOUND_HEIGHT := Vector2(1.2,8.0)
## The row of trees: one every TREE_STEP m along the path (Shift: HEDGE_STEP,
## closer), each up to TREE_WANDER m off it. The border of flowers: the flower
## brush (scripts/flower_paint.gd) at FLOWER_SIZE of its own, drawn along the
## path in steps FLOWER_STEP m apart, each lingering FLOWER_LINGER s, so one
## draw comes up near a full drift's core.
const TREE_STEP := 3.0
const HEDGE_STEP := 2.0
const TREE_WANDER := 0.3
const FLOWER_SIZE := 0.6
const FLOWER_STEP := 0.25
const FLOWER_LINGER := 0.4
const TreePaint = preload("res://scripts/tree_paint.gd")
const FlowerPaint = preload("res://scripts/flower_paint.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
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
## The running build raises (max) rather than cuts (min); what it plants as
## the head passes ([arc length, plate point], in order), the next to plant,
## and the strokes planting them; the height rock is measured against.
var _raise := false
var _plants: Array = []
var _next_plant := 0
var _trees: RefCounted = null
var _flowers: RefCounted = null
var _rock_height := 0.0

## The fan's modes (clay_tool `modes`): what a drawn path makes (the gorge,
## a range, a hill, a row of trees, a border of flowers) and the slice.
const MODES := [{"id":"gorge","kind":"drag"},{"id":"range","kind":"drag"},{"id":"hill","kind":"drag"},{"id":"trees","kind":"drag"},{"id":"flowers","kind":"drag"},{"id":"slice","kind":"hold"}]
## Each drawing mode's verb, and its Shift verb.
const VERBS := {"gorge":["gorge","shallow_gorge"],"range":["range","low_range"],"hill":["hill","low_hill"],"trees":["trees","hedge"],"flowers":["flowers","fine_flowers"]}
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
	var verbs: Array = VERBS.get(mode,VERBS.gorge)
	return verbs[1] if fine else verbs[0]

## The drawing mode in hand ("gorge" for none or the slice's).
func _drawing() -> String:
	return mode if VERBS.has(mode) else "gorge"

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
	# Only a gorge runs on out through the rim.
	return _to_rim(path) if _drawing() == "gorge" else path

## Whether `path` closes on itself: a loop, an outline (LOOP_GAP, LOOP_MIN).
func _closes(path: PackedVector2Array) -> bool:
	if path.size() < 4 or _drawing() in ["trees","flowers"]: return false
	var size: float = clay.size_scale if clay != null else 1.0
	return path[0].distance_to(path[-1]) <= LOOP_GAP*maxf(size,1.0) and _arc(path)[-1] >= LOOP_MIN

## `path` with each end near the rim and heading out run on through it.
static func _to_rim(path: PackedVector2Array) -> PackedVector2Array:
	if path.size() < 2: return path
	var out := path.duplicate()
	var tail: Variant = _past_rim(path[-1],path[-2])
	if tail != null: out.append(tail)
	var head: Variant = _past_rim(path[0],path[1])
	if head != null: out.insert(0,head)
	return out

## Where the run from `from` through `end` leaves the plate RIM_PAST beyond
## its rim, or null when `end` is not near the rim or not heading out.
static func _past_rim(end: Vector2, from: Vector2) -> Variant:
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

## Let go: the cut is planned along the drawn path and drawn through the
## land by `frame`, inside the stroke's undo step, which the clay keeps open
## while it runs. Without `animate` it lands whole now.
func drag_end() -> bool:
	_path = drawn()
	var plan := _plan_drawn(_path)
	_cuts = plan.cuts
	_length = plan.length
	_box = plan.box
	_raise = plan.get("raise",false)
	_plants = plan.get("plants",[])
	_rock_height = float(plan.get("rock",0.0))
	_next = 0
	_next_plant = 0
	_clock = 0.0
	_seconds = clampf(_length/CUT_SPEED,CUT_SECONDS.x,CUT_SECONDS.y)
	_running = true
	if _length > 0.0: clay.sound(&"wire_start",_path[0])
	if not animate: finish()
	return false

## The plan for the drawing mode in hand along `path`: `_plan`'s, plus
## "raise" (the heights are built up, not cut), "plants" and "rock" (the
## height a range's rock is measured against, 0 for none).
func _plan_drawn(path: PackedVector2Array) -> Dictionary:
	var loop := path.size() > 3 and path[0] == path[-1]
	match _drawing():
		"range": return _plan_range(path,loop)
		"hill": return _plan_mound(path) if loop else _plan_hill(path)
		"trees", "flowers": return _plan_plants(path)
	return _plan_basin(path) if loop else _plan(path)

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
	if not _plants.is_empty() or _drawing() in ["trees","flowers"]:
		# Plants only: no ground moved. The flowers' faint wash, in the step.
		if _flowers != null: _flowers.finish()
		_trees = null
		_flowers = null
		return
	var spread := maxf(_box.size.x,_box.size.y)*0.5
	clay.touch(_box.get_center(),spread)
	clay.lay_dirt(_box.get_center(),spread)
	clay.sound(&"crumble",_box.get_center(),_length/20.0)
	if _rock_height > 0.0: clay.paint_rock(_box.get_center(),spread,_rock_height)
	clay.paint_faces(_box)
	clay.show_land()
	clay.shake_trees(clay.center,0.0,clay.touched())

## Lay every planned cut the head has passed (arc length up to `head`),
## write the land, lay the dirt under them and show it. Only the points cut
## this frame are written; the rest of the land is as it was.
func _lay(head: float) -> void:
	_plant(head)
	if _next >= _cuts.size(): return
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	var points := data.points
	var area := Rect2()
	var first := true
	while _next < _cuts.size() and (_cuts[_next] as Vector3).x <= head:
		var cut: Vector3 = _cuts[_next]
		var i := int(cut.y)
		heights[i] = maxf(heights[i],cut.z) if _raise else minf(heights[i],cut.z)
		area = Rect2(points[i],Vector2.ZERO) if first else area.expand(points[i])
		first = false
		_next += 1
	if first: return
	data.heights = heights
	var spread := maxf(area.size.x,area.size.y)*0.5+NativeTerrainData.MEADOW_STEP
	clay.touch(area.get_center(),spread)
	clay.lay_dirt(area.get_center(),spread)
	clay.show_land()

## Plant what the head has passed (arc length up to `head`), shown at once
## through the view's paint preview, as the flower brush's are.
func _plant(head: float) -> void:
	if _next_plant >= _plants.size(): return
	var made := []
	while _next_plant < _plants.size() and float(_plants[_next_plant][0]) <= head:
		var p: Vector2 = _plants[_next_plant][1]
		if _trees != null:
			var key := [int(_trees.sowing.salt),clay.editor.land_seed,"row",_next_plant]
			if _trees.suits(p) and _trees._clear(p):
				_trees.kind = _land_tree(p,key)
				var item: Variant = _trees._plant(p,key)
				if item != null: made.append(item)
		elif _flowers != null:
			var got: Dictionary = _flowers.press(p) if _next_plant == 0 else _flowers.stroke(p,FLOWER_LINGER)
			made.append_array(got.records)
		_next_plant += 1
	if not made.is_empty(): clay.editor._show_paint({"records":made,"removed":[]})

## The tree the land grows at `p`: emergence's own pick for its habitat, or an
## oak before the habitat is known.
func _land_tree(p: Vector2, key: Array) -> String:
	var life: RefCounted = clay.editor.emergence
	if life._blend == null: return "broadleaf"
	return life._tree_kind(str(life._blend.pick(p)),p,Variety.unit(key+[5]),Variety.unit(key+[25]))

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

## One rounded hill filling a loop `path`: each point inside raised by a
## smoothstep of its way in, MOUND_SLOPE m for each metre the middle lies in,
## so a bigger outline stands a bigger hill.
func _plan_mound(path: PackedVector2Array) -> Dictionary:
	var base: PackedFloat32Array = clay.base
	var length := _arc(path)[-1]
	var inside := _inside(path)
	var deepest: float = maxf(inside.deepest,0.01)
	var tall := clampf(deepest*MOUND_SLOPE,MOUND_HEIGHT.x,MOUND_HEIGHT.y)*(LOW if _shallow else 1.0)
	var cuts: Array = []
	for entry: Vector2 in inside.points:
		var i := int(entry.x)
		var h := minf(base[i]+tall*smoothstep(0.0,1.0,entry.y/deepest)*clay.fade(i),NativeTerrainData.MAX_HEIGHT)
		if h > base[i]: cuts.append(Vector3(length+entry.y*FILL_PACE,i,h))
	cuts.sort()
	return {"cuts":cuts,"length":length+deepest*FILL_PACE,"box":inside.box,"raise":true}

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

## Every point near `path` and its arc length and distance from it, nearest
## stretch first: [Vector3(point index, arc length, distance)], within `reach`.
func _beside(path: PackedVector2Array, arc: PackedFloat32Array, reach: float) -> Array:
	var data: NativeTerrainData = clay.editor.data
	var points := data.points
	var best := {}
	for j in range(path.size()-1):
		var a := path[j]
		var b := path[j+1]
		var run := a.distance_to(b)
		var along := (b-a)/run if run > 0.001 else Vector2.ZERO
		clay.gather((a+b)*0.5,run*0.5+reach)
		for i: int in clay.near:
			var t := clampf((points[i]-a).dot(along),0.0,run)
			var d := points[i].distance_to(a+along*t)
			if d >= reach: continue
			var was: Variant = best.get(i)
			if was == null or d < (was as Vector3).z: best[i] = Vector3(i,arc[j]+t,d)
	return best.values()

## A range along `path` (a ring of peaks round a loop): summits every
## RANGE_SPACING along the crest, the crest between them at RANGE_SADDLE,
## each point raised by the crest at its arc length and a knife-edged
## profile across, at the land's fade.
func _plan_range(path: PackedVector2Array, loop: bool) -> Dictionary:
	var base: PackedFloat32Array = clay.base
	var size: float = clay.size_scale
	if path.size() == 1: path = PackedVector2Array([path[0],path[0]])
	var arc := _arc(path)
	var length := arc[-1]
	var low := LOW if _shallow else 1.0
	var height := RANGE_HEIGHT*size*low
	var half := RANGE_HALF*size*lerpf(1.0,low,0.5)
	var spacing := RANGE_SPACING*size
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([clay.editor.land_seed,"wire range",path[0].snapped(Vector2.ONE*0.01)])
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.9
	var summits := PackedVector2Array()
	var count := maxi(1,roundi(length/spacing))
	for k in count:
		summits.append(Vector2((k+0.5+rng.randf_range(-RANGE_SLIP,RANGE_SLIP))*length/count,rng.randf_range(RANGE_TALL.x,RANGE_TALL.y)))
	var cuts: Array = []
	var box := Rect2(path[0],Vector2.ZERO)
	for p in path: box = box.expand(p)
	for entry: Vector3 in _beside(path,arc,half*1.3):
		var i := int(entry.x)
		var s := entry.y
		var crest := RANGE_SADDLE*(0.82+0.18*noise.get_noise_1d(s))
		var width := half*(0.85+0.15*noise.get_noise_1d(s+40.0))
		for top: Vector2 in summits:
			var u := (s-top.x)/(spacing*0.6)
			if absf(u) < 1.0:
				crest = maxf(crest,top.y*pow(1.0-u*u,2.0))
				width = maxf(width,half*(0.85+0.3*(1.0-absf(u))))
		if not loop and length > 0.01: crest *= 1.0-RANGE_TAPER*(1.0-pow(sin(PI*clampf(s/length,0.0,1.0)),0.7))
		var q := entry.z/width
		if q >= 1.0: continue
		var edge := lerpf(pow(1.0-q*q,2.0),pow(1.0-q,1.45),0.6)*(0.92+0.08*noise.get_noise_2dv(clay.editor.data.points[i]*1.3))
		var h := minf(base[i]+height*crest*edge*clay.fade(i),NativeTerrainData.MAX_HEIGHT)
		if h > base[i]+0.005: cuts.append(Vector3(s,i,h))
	cuts.sort()
	return {"cuts":cuts,"length":length,"box":box.grow(half*1.3),"raise":true,"rock":height}

## A soft ridge along `path`: HILL_HEIGHT over the ground at its crest,
## rolling a little along it, falling away on a cosine to HILL_HALF either side.
func _plan_hill(path: PackedVector2Array) -> Dictionary:
	var base: PackedFloat32Array = clay.base
	var size: float = clay.size_scale
	if path.size() == 1: path = PackedVector2Array([path[0],path[0]])
	var arc := _arc(path)
	var height := HILL_HEIGHT*size*(LOW if _shallow else 1.0)
	var half := HILL_HALF*size
	var noise := FastNoiseLite.new()
	noise.seed = hash([clay.editor.land_seed,"wire hill",path[0].snapped(Vector2.ONE*0.01)])
	noise.frequency = 0.12
	var cuts: Array = []
	var box := Rect2(path[0],Vector2.ZERO)
	for p in path: box = box.expand(p)
	for entry: Vector3 in _beside(path,arc,half):
		var i := int(entry.x)
		var q := entry.z/half
		var crest := 1.0-HILL_ROLL+HILL_ROLL*noise.get_noise_1d(entry.y)
		var h := minf(base[i]+height*crest*(0.5+0.5*cos(PI*q))*clay.fade(i),NativeTerrainData.MAX_HEIGHT)
		if h > base[i]+0.005: cuts.append(Vector3(entry.y,i,h))
	cuts.sort()
	return {"cuts":cuts,"length":arc[-1],"box":box.grow(half),"raise":true}

## What the Trees and Flowers modes plant along `path`: stations TREE_STEP
## (or HEDGE_STEP) apart for a row of trees, wandering a little off the line,
## or FLOWER_STEP apart for the flower brush to be drawn through; and the
## stroke that plants them (scripts/tree_paint.gd, scripts/flower_paint.gd),
## inside the clay's undo step. No ground moves.
func _plan_plants(path: PackedVector2Array) -> Dictionary:
	var editor: Node = clay.editor
	var data: NativeTerrainData = editor.data
	if path.size() == 1: path = PackedVector2Array([path[0],path[0]])
	var arc := _arc(path)
	var length := arc[-1]
	var plants: Array = []
	var box := Rect2(path[0],Vector2.ZERO)
	for p in path: box = box.expand(p)
	var serial := hash([editor.land_seed,"wire plants",path[0].snapped(Vector2.ONE*0.01)])
	_trees = null
	_flowers = null
	if _drawing() == "trees":
		_trees = TreePaint.new(editor.emergence,data,"broadleaf",clay.size_scale,false,serial,editor._paint_wet())
		var step := (HEDGE_STEP if _shallow else TREE_STEP)*lerpf(1.0,clay.size_scale,0.5)
		var count := maxi(1,floori(length/step)+1)
		var start := (length-step*(count-1))*0.5
		for k in count:
			var s := start+step*k
			var key := [serial,k]
			var at := _point_at(path,s)+Vector2.from_angle(Variety.unit(key+[1])*TAU)*TREE_WANDER*Variety.unit(key+[2])
			plants.append([s,at])
	else:
		_flowers = FlowerPaint.new(editor._flower_sowing("wildflower"),FLOWER_SIZE*clay.size_scale*(LOW if _shallow else 1.0),false,serial)
		var count := maxi(1,ceili(length/FLOWER_STEP))
		for k in count+1:
			var s := length*k/count
			plants.append([s,_point_at(path,s)])
	return {"cuts":[],"length":length,"box":box.grow(TreePaint.TREE_RADIUS),"plants":plants}

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
		heights[i] = minf(base[i],level)
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
