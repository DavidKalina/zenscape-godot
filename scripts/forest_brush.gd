extends "res://scripts/creation_brush.gd"
## The forest brush: drag to wish for forest, Shift-drag (or a right drag outside the creation shell) to keep
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
## A firm clearing pass is cleared outright at release, so one deliberate
## Shift pass over a young forest clears it. A cell is firmly cleared when the
## stroke pushed its wish down by at least FIRM_PASS (the sum of its dabs
## there, before clamping), or by at least FIRM_MIN and left it at FIRM_EMPTY
## or less: the pass took the wish away. At strength 1 a steady pass pushes
## about 1 at its centre, which undoes one planting pass. A light pass (low
## strength, a quick flick, the brush's soft shoulder over a denser wish)
## only thins the wish and leaves what emerged.
const FIRM_PASS := 0.7
const FIRM_MIN := 0.3
const FIRM_EMPTY := 0.1
## A landed seed of the seed handful (scripts/seed_handful.gd, `sow`): the
## wish it raises at its point, how far round it (m, with a dab's falloff),
## and how far past the handful's mark (m) that wish fades to nothing, so the
## forest a handful asks for stays inside its mark.
const SEED_WISH := 0.55
const SEED_REACH := 1.5
const SEED_EDGE := 0.3

var _floor := Color()
var _clearing := false
var _planting := false
## Cover cell -> wish this clearing stroke pushed down there.
var _cleared := {}

func _init() -> void:
	brush_id = "forest"
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
		if lower: _cleared[cell] = _cleared.get(cell,0.0)+amount*RATE*weight
		if data.provenance[cell] == NativeTerrainData.SOURCE_HAND: continue
		_tint_toward(tint,cell,_floor,FLOOR_WEIGHT*maxf(wish[cell],0.0),absf(wish[cell]-before)*FLOOR_WEIGHT+0.0001)
	intent.forest = wish
	intent.revision += 1
	data.tint = tint

## One seed of a handful landed at `point`: raise the forest wish round it
## and darken the floor there, as a dab does. `mark` is the handful's mark
## (centre x, z and radius): the wish fades out from its edge to SEED_EDGE
## past it. Between `begin` and `finish`, inside the handful's undo step.
func sow(data: NativeTerrainData, point: Vector2, mark: Vector3) -> void:
	if editor == null: return
	_grow_bounds(point,SEED_REACH)
	_planting = true
	var intent: RefCounted = editor.emergence.intent
	var wish: PackedFloat32Array = intent.forest
	var tint := data.tint
	var centre := Vector2(mark.x,mark.y)
	var step := data.MEADOW_STEP*0.5
	for found: Vector2 in _cells_near(data,point,SEED_REACH):
		var cell := int(found.x)
		var t := found.y/SEED_REACH
		var side := data.MEADOW_CELLS
		var at := data.meadow_position(cell%side,cell/side)+Vector2.ONE*step
		var weight := pow(1.0-t*t,1.5)*(1.0-smoothstep(mark.z-SEED_EDGE,mark.z+SEED_EDGE,at.distance_to(centre)))
		if weight <= 0.0: continue
		var before := wish[cell]
		wish[cell] = move_toward(before,1.0,SEED_WISH*weight)
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
	_settle_clearing()
	_clear_objects(data,_in_clearing.bind(data),func(_asset: String) -> bool: return false)
	_cleared.clear()
	return bounds if _planting else Rect2()

## A firm pass holds its ground clear: its cells drop to CLEAR_BELOW at least,
## inside the stroke's undo step, so their emerged plants go now and the
## biome's own chance there is thinned as any clearing's is.
func _settle_clearing() -> void:
	var intent: RefCounted = editor.emergence.intent
	var wish: PackedFloat32Array = intent.forest
	var changed := false
	for cell: int in _cleared:
		var push: float = _cleared[cell]
		if wish[cell] > CLEAR_BELOW and (push >= FIRM_PASS or (push >= FIRM_MIN and wish[cell] <= FIRM_EMPTY)):
			wish[cell] = CLEAR_BELOW
			changed = true
	if not changed: return
	intent.forest = wish
	intent.revision += 1

func _in_clearing(p: Vector2, data: NativeTerrainData) -> bool:
	var cell := data.meadow_cell(p)
	return _cleared.has(cell) and editor.emergence.intent.forest[cell] <= CLEAR_BELOW
