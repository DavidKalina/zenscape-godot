extends "res://scripts/clay_tools/clay_tool.gd"
## The Wire, "Slice" (docs/design/tools/PLAN.md): a taut wire between two
## wooden toggles, drawn through the land as a potter's wire goes through clay.
## It cuts; it never raises.
##
## - **Drag (press, drag, release):** a gorge along the straight line from the
##   press to the release, whatever way the pointer wandered between. It is
##   cut at release: while the drag lasts only the faint line the ground marks
##   draw (scripts/ground_marks.gd, the wire's line from the press point to the
##   pointer) shows where it will go, and the land is untouched. A wire is
##   pulled taut between two points and then drawn through; the line is the
##   preview, the release is the cut. Cut live, the gorge would have to follow
##   the pointer's path (a groove, the Hand's thumb) or be torn up and recut
##   each frame as the far end moved.
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
## Each is one undo step. The pips (clay.size_scale) scale the reach: the
## gorge's width and the slice's radius. Depth and wall steepness hold.
##
## ### The gorge
##
## Across, a flat bed BED_HALF metres either side of the line, then a wall
## rising to the untouched ground over WALL_RUN metres: under the land's point
## spacing (0.45 to 0.75 m), so each wall is one facet row, as steep as the
## points allow. The ends are round (distance to the segment). Along, the bed
## is GORGE_DEPTH under the ground where it starts, and it never climbs: from
## its high end it falls at least BED_FALL metres per metre, cutting deeper
## where the ground rises across the line, so water (the shallow-water sim)
## runs the length of it. Across a dip the far side is cut down to the dip's
## level, as a river's canyon cuts through the ridge beyond it. The land's
## MIN_HEIGHT stops it; a drag is a stroke, as the thumb's groove is, so it
## is not held to the clay's sink FLOOR.
##
## Let go, the dug ground turns to bare earth (the clay's dirt), and then the
## walls take the range's granite on their steeps (clay.paint_faces, rock by
## slope alone on cut ground): the bed stays earth, the walls read as rock.
## Trees on ground the cut moved that cannot hold it slide off.
const BED_HALF := 1.1
const WALL_RUN := 0.35
const GORGE_DEPTH := 2.6
const BED_FALL := 0.02
## Metres between the stations the bed's fall is worked out on.
const STATION := 0.25
## Shift: the shallower share (of the gorge's depth, of the slice's pace).
const SHALLOW := 0.4
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

func id() -> String: return "wire"
func stroke_radius() -> float: return (BED_HALF+WALL_RUN)*clay.size_scale

func reset() -> void:
	lift = 0.0
	_shallow = false

# --- Drag: the gorge -----------------------------------------------------------------

func drag_begin(fine: bool) -> String:
	_shallow = fine
	return "shallow_gorge" if fine else "gorge"

## Nothing is laid while the wire is drawn taut: the path's points wait in the
## clay's queue, and the last is the far end. The hand follows the pointer.
func drag_frame(_delta: float) -> bool:
	clay.hand_gesture(gesture(clay.verb),clay.ground_at(clay.path_end()))
	return false

## Let go: the cut, from the press to the last point on the path, written
## straight to the land inside the stroke's undo step; then the dirt, the
## rock over it, and the trees.
func drag_end() -> bool:
	var from: Vector2 = clay.center
	var to: Vector2 = clay.path_end()
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	var reach := cut_gorge(heights,from,to)
	data.heights = heights
	var box := Rect2(from,Vector2.ZERO).expand(to).grow(reach)
	var spread := maxf(box.size.x,box.size.y)*0.5
	clay.touch(box.get_center(),spread)
	# The clay lays the dirt after a frame's dabs; the cut has no dabs, so it
	# is laid here, before the rock, which must go over it.
	clay.lay_dirt(box.get_center(),spread)
	clay.paint_faces(box)
	clay.show_land()
	clay.shake_trees(clay.center,0.0,clay.touched())
	return false

## The gorge from `from` to `to` (plate points), written into `heights` from
## the clay's base. Returns its reach either side of the line in metres.
func cut_gorge(heights: PackedFloat32Array, from: Vector2, to: Vector2) -> float:
	var base: PackedFloat32Array = clay.base
	var data: NativeTerrainData = clay.editor.data
	var width: float = clay.size_scale
	var bed_half := BED_HALF*width
	var top := bed_half+WALL_RUN
	var depth := GORGE_DEPTH*(SHALLOW if _shallow else 1.0)
	var length := from.distance_to(to)
	var along := (to-from)/length if length > 0.01 else Vector2.ZERO
	var bed := _bed(from,to,depth)
	var points := data.points
	for i in range(points.size()):
		var p := points[i]
		var s := clampf((p-from).dot(along),0.0,length) if length > 0.01 else 0.0
		var d := p.distance_to(from+along*s)
		if d >= top: continue
		var fade: float = clay.fade(i)
		if fade <= 0.0: continue
		var k := s/length*(bed.size()-1) if length > 0.01 else 0.0
		var floor_h := lerpf(bed[floori(k)],bed[mini(floori(k)+1,bed.size()-1)],k-floorf(k))
		var goal := floor_h if d <= bed_half else lerpf(floor_h,base[i],(d-bed_half)/WALL_RUN)
		goal = minf(goal,base[i])
		heights[i] = maxf(lerpf(base[i],goal,fade),NativeTerrainData.MIN_HEIGHT)
	return top

## The bed's height at stations STATION apart from `from` to `to`: `depth`
## under the ground, falling at least BED_FALL per metre from the higher end,
## never climbing, and never under MIN_HEIGHT.
func _bed(from: Vector2, to: Vector2, depth: float) -> PackedFloat32Array:
	var base: PackedFloat32Array = clay.base
	var data: NativeTerrainData = clay.editor.data
	var count := maxi(ceili(from.distance_to(to)/STATION),1)+1
	var step := from.distance_to(to)/(count-1)
	var bed := PackedFloat32Array()
	bed.resize(count)
	var last := 0.0
	var found := false
	for k in count:
		var ground: Variant = data.sample(from.lerp(to,float(k)/(count-1)),base)
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
