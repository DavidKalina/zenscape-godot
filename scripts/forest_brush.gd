extends "res://scripts/creation_brush.gd"
## The forest brush: drag to wish for forest, Shift or a right drag to keep
## ground clear. It plants no trees itself. Each dab raises the forest wish in
## the land intent layer (scripts/land_intent.gd) with a soft falloff, and
## darkens the floor a little under it so the stroke reads at once. When the
## stroke ends its bounds go to emergence, which grows the forest over the
## succession clock: a dense core, a ragged scattered edge with shrubs at the
## margin, thinning on steep rock, nothing on water or snow
## (scripts/emergence.gd, docs/scenic/brushes.md).
##
## Clearing lowers the wish toward -1 and, at release, withdraws emerged
## plants from the cleared ground. Hand and pinned work is never touched, and
## the floor tint skips cells laid down by hand (a painted meadow or path).
## Forest wish per second at the brush centre, at strength 1.
const RATE := 2.2
## The painted forest floor at full wish: weight of the tint, and how far the
## palette's darkest grass is shifted (hue, saturation, lightness).
const FLOOR_WEIGHT := 0.42
const FLOOR_SHIFT := Vector3(0.015,-0.04,-0.07)
## Emerged plants go when a clearing stroke leaves their cell below this wish.
const CLEAR_BELOW := -0.25

var _floor := Color()
var _clearing := false
var _planting := false
var _cleared := {}

func _init() -> void:
	brush_id = "forest"
	title = "Forest"
	hint = "Drag to grow forest · Shift or right drag clears · [ ] brush size"
	radius = 3.6
	radius_range = Vector2(1.5,9.0)

func _prepared(data: NativeTerrainData) -> void:
	_floor = NativeTerrainPalette.shift_hsl(data._palette.grass[2],FLOOR_SHIFT.x,FLOOR_SHIFT.y,FLOOR_SHIFT.z)

func begin() -> void:
	super.begin()
	_clearing = false
	_planting = false
	_cleared.clear()

func dab(data: NativeTerrainData, center: Vector2, reach: float, amount: float, lower: bool) -> void:
	if reach <= 0.0 or amount <= 0.0 or editor == null: return
	_grow_bounds(center,reach)
	_clearing = _clearing or lower
	_planting = _planting or not lower
	var intent: RefCounted = editor.emergence.intent
	var wish: PackedFloat32Array = intent.forest
	var tint := data.tint
	var goal := -1.0 if lower else 1.0
	for found: Vector2 in _cells_near(data,center,reach):
		var cell := int(found.x)
		var t := found.y/reach
		# Soft shoulders, so a single pass leaves a gradient the edge can fray along.
		var weight := pow(1.0-t*t,1.5)
		var before := wish[cell]
		wish[cell] = move_toward(before,goal,amount*RATE*weight)
		if lower: _cleared[cell] = true
		if data.provenance[cell] == NativeTerrainData.SOURCE_HAND: continue
		_tint_toward(tint,cell,_floor,FLOOR_WEIGHT*maxf(wish[cell],0.0),absf(wish[cell]-before)*FLOOR_WEIGHT+0.0001)
	intent.forest = wish
	intent.revision += 1
	data.tint = tint

## Planting hands the stroke's ground to emergence; clearing withdraws what
## emerged there and keeps the ground to itself.
func finish(data: NativeTerrainData) -> Rect2:
	if not has_bounds: return Rect2()
	has_bounds = false
	if not _clearing: return bounds
	_clear_objects(data,_in_clearing.bind(data),func(_asset: String) -> bool: return false)
	_cleared.clear()
	return bounds if _planting else Rect2()

func _in_clearing(p: Vector2, data: NativeTerrainData) -> bool:
	var cell := data.meadow_cell(p)
	return _cleared.has(cell) and editor.emergence.intent.forest[cell] <= CLEAR_BELOW
