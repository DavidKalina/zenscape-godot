extends RefCounted
## What the creation brushes share (scripts/genesis_canvas.gd `BRUSHES`).
## A brush writes intent into the same data craft mode edits (heights, cover
## masks, painted ground colour, a few object records) and the world picks
## the details. The editor drives every brush the same way land_brush.gd is
## driven:
##   activate(editor) / deactivate(editor)  when it comes into or leaves the hand
##   prepare(data, world_seed)              before a stroke, cheap when unchanged
##   begin()                                on press
##   dab(data, center, radius, amount, lower)  along the pointer path, 30 Hz
##   finish(data) -> Rect2                  on release, inside the stroke's undo
##                                          step; the rect is handed to emergence
## Dabs must stay light: they touch only the cells and vertices under the
## brush and never mint or remove object records, so a held stroke takes the
## editor's light refresh (docs/performance/stroke-pipeline.md). Records wait
## for `finish`, whose changes the settle refresh publishes.
const Variety = preload("res://scripts/seeded_variety.gd")
## Bucket size for the per-vertex lookup, in metres (as land_brush.gd).
const CELL := 2.0

## The brush's id in scripts/genesis_canvas.gd `BRUSHES`, which also holds
## its palette title and how-to hint.
var brush_id := ""
## True for a brush whose dabs only record and whose stroke settles by plan
## (water): the editor hands the stroke to NativeChunkEditor `_pour_live`,
## which opens the undo step when a plan first shows, instead of `finish`.
var settles := false
## World-space brush radius and strength, adjusted with [ ] and Shift [ ].
var radius := 3.0
var strength := 1.0
var radius_range := Vector2(0.5,9.0)
var strength_range := Vector2(0.25,3.0)
var seed_value := -1
## World-space XZ bounds of the stroke in progress.
var bounds := Rect2()
var has_bounds := false
## The editor holding this brush, set while it is in hand.
var editor: Node
var _cells := {}
var _points := 0

func activate(owner: Node) -> void:
	editor = owner

func deactivate(_owner: Node) -> void:
	pass

## Rebuild the per-vertex buckets when the seed or mesh changes.
func prepare(data: NativeTerrainData, world_seed: int) -> void:
	if world_seed == seed_value and _points == data.points.size(): return
	seed_value = world_seed
	_points = data.points.size()
	_cells.clear()
	for i in range(_points):
		var p: Vector2 = data.points[i]
		var key := Vector2i(floori(p.x/CELL),floori(p.y/CELL))
		if not _cells.has(key): _cells[key] = PackedInt32Array()
		_cells[key].append(i)
	_prepared(data)

## Per-brush setup after `prepare` rebuilt the buckets.
func _prepared(_data: NativeTerrainData) -> void:
	pass

func begin() -> void:
	has_bounds = false
	bounds = Rect2()

func dab(_data: NativeTerrainData, _center: Vector2, _radius: float, _amount: float, _lower: bool) -> void:
	pass

func finish(_data: NativeTerrainData) -> Rect2:
	has_bounds = false
	return Rect2()

func _grow_bounds(center: Vector2, reach: float) -> void:
	var area := Rect2(center-Vector2.ONE*reach,Vector2.ONE*reach*2.0)
	bounds = bounds.merge(area) if has_bounds else area
	has_bounds = true

## Cover-cell indices whose centres lie within `reach` of `center`, with the
## distance of each, so a dab never walks the whole cover grid.
func _cells_near(data: NativeTerrainData, center: Vector2, reach: float) -> Array:
	var found := []
	var side := data.MEADOW_CELLS
	var step := data.MEADOW_STEP
	# Inline, not a const: the brushes extending this one may name Plate.
	var half: float = preload("res://scripts/plate.gd").HALF
	var low := Vector2i(clampi(floori((center.x-reach+half)/step),0,side-1),clampi(floori((center.y-reach+half)/step),0,side-1))
	var high := Vector2i(clampi(floori((center.x+reach+half)/step),0,side-1),clampi(floori((center.y+reach+half)/step),0,side-1))
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var distance := (data.meadow_position(x,z)+Vector2.ONE*step*0.5).distance_to(center)
			if distance < reach: found.append(Vector2(z*side+x,distance))
	return found

## Vertex indices under the brush, from the buckets.
func _vertices_near(data: NativeTerrainData, center: Vector2, reach: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	for cz in range(floori((center.y-reach)/CELL),floori((center.y+reach)/CELL)+1):
		for cx in range(floori((center.x-reach)/CELL),floori((center.x+reach)/CELL)+1):
			var cell: Variant = _cells.get(Vector2i(cx,cz))
			if cell == null: continue
			for i: int in cell:
				if data.points[i].distance_to(center) < reach: found.append(i)
	return found

## Lay painted ground colour into one tint cell: the weight eases toward
## `weight` by `step`, and the colour toward `color` by the same share, so
## repeated dabs settle on the target instead of saturating. A zero `weight`
## only fades the cell, keeping whatever colour it had.
static func _tint_toward(tint: PackedFloat32Array, cell: int, color: Color, weight: float, step: float) -> void:
	var k := cell*NativeTerrainTint.STRIDE
	var before := tint[k+3]
	var after := move_toward(before,weight,step)
	if weight > 0.0:
		var share := 1.0 if before <= 0.0 else clampf(step/maxf(after,0.05),0.0,1.0)
		tint[k] = lerpf(tint[k],color.r,share)
		tint[k+1] = lerpf(tint[k+1],color.g,share)
		tint[k+2] = lerpf(tint[k+2],color.b,share)
	tint[k+3] = after
	if after <= 0.0:
		tint[k] = 0.0
		tint[k+1] = 0.0
		tint[k+2] = 0.0

## Remove records a brush may clear: emerged ones always; generated ones only
## when `generated` accepts the asset. Hand and pinned records always stay.
static func _clear_objects(data: NativeTerrainData, inside: Callable, generated: Callable) -> bool:
	var removed := false
	for index in range(data.objects.size()-1,-1,-1):
		var item: Dictionary = data.objects[index]
		var source := NativeTerrainData.object_source(item)
		if source == "hand" or item.asset in ["waterfall","explosive","bigfoot_tree"]: continue
		if source == "generated" and not generated.call(str(item.asset)): continue
		if not inside.call(Vector2(item.x,item.z)): continue
		data.objects.remove_at(index)
		removed = true
	if removed: data.objects_revision += 1
	return removed
