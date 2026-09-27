extends RefCounted
## What the creation brushes asked of the ground, for emergence to answer
## (docs/scenic/brushes.md). One value per cover cell, aligned with the masks:
## `forest` runs from -1 (keep this ground clear) through 0 (no wish: the
## biome decides) to 1 (the heart of a forest).
##
## Intent is part of the stroke's undo step: it rides the terrain history
## through `history_captured` and `state_restored`, as the fire field does, so
## one undo removes a forest stroke's wish together with its painted floor.
##
## It is saved with the place: `to_document` adds an optional `intent_forest`
## field (deflated float32 cells, base64) whenever any cell carries a wish, and
## `load_document` hands it back through `state_restored`. Saves without the
## field load with no wish anywhere, as before.
var data: NativeTerrainData
var forest := PackedFloat32Array()
## Bumped on every change, so planners can tell a stale read.
var revision := 0

func _init(terrain: NativeTerrainData) -> void:
	data = terrain
	forest = _blank()
	data.history_captured.connect(func(state: Dictionary) -> void: state["intent_forest"] = forest.duplicate())
	data.state_restored.connect(_restore)
	data.document_captured.connect(func(document: Dictionary) -> void:
		if forest.count(0.0) != forest.size(): document["intent_forest"] = encode(forest))

## The saved form of a wish layer.
static func encode(values: PackedFloat32Array) -> Dictionary:
	return {"cells":values.size(),"deflate":Marshalls.raw_to_base64(values.to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE))}

## A saved wish layer of `count` cells, or null when it is malformed.
static func decode(value: Variant, count: int) -> Variant:
	if not value is Dictionary or not GardenData._integer(value.get("cells")) or int(value.cells) != count or not value.get("deflate") is String:
		return null
	var packed := Marshalls.base64_to_raw(value.deflate)
	if packed.is_empty():
		return null
	var raw := packed.decompress(count*4,FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != count*4:
		return null
	var values := raw.to_float32_array()
	for v in values:
		if not is_finite(v) or v < -1.0 or v > 1.0:
			return null
	return values

func _blank() -> PackedFloat32Array:
	var made := PackedFloat32Array()
	made.resize(data.MEADOW_CELLS*data.MEADOW_CELLS)
	made.fill(0.0)
	return made

func _restore(state: Dictionary) -> void:
	var saved: Variant = state.get("intent_forest")
	forest = saved.duplicate() if saved is PackedFloat32Array and saved.size() == data.MEADOW_CELLS*data.MEADOW_CELLS else _blank()
	revision += 1

## Forest wish at a plate point, from the cell under it.
func forest_at(p: Vector2) -> float:
	return forest[data.meadow_cell(p)]

## True when any cell in `rect` carries a forest wish either way.
func any_forest(rect: Rect2) -> bool:
	var side := data.MEADOW_CELLS
	var step := data.MEADOW_STEP
	for z in range(clampi(floori((rect.position.y+14.0)/step),0,side-1),clampi(floori((rect.end.y+14.0)/step),0,side-1)+1):
		for x in range(clampi(floori((rect.position.x+14.0)/step),0,side-1),clampi(floori((rect.end.x+14.0)/step),0,side-1)+1):
			if forest[z*side+x] != 0.0: return true
	return false
