extends RefCounted
## Brings a terrain document saved on the 28 m plate onto the plate as it is
## now (scripts/plate.gd). Until version 12 every world was saved against the
## authored mesh (assets/zen_reference/geometry.scn `terrain`, 45×45 points
## over ±LEGACY_HALF), its `template` that mesh's; it is kept only to read
## those worlds. The land comes over unchanged in the middle of the bigger
## plate:
##   heights are read off the old mesh at each new point (a point past the old
##   square reads the old edge); a landscape made from a recipe keeps the
##   recipe's own heights at the new points and carries over only what was
##   sculpted into it;
##   the outline is the old one, face by face under each new face's middle,
##   or the old square where there was none (the plate's grid lines on
##   ±LEGACY_HALF keep that square's edge straight);
##   cover (meadow, grass, blades, tint, provenance) and the forest wish are
##   COVER_STEP cells, so the old ones sit OFFSET cells in from the new corner;
##   live water's depths are re-laid on the new grid the same way;
##   objects, fences, ponds, streams and tunnels are in metres from the
##   middle and stay where they are.
## The scene's own saved state is moved over by `migrate_state`.

const Plate = preload("res://scripts/plate.gd")
## The version a migrated document is written as; NativeTerrainData saves it.
const VERSION := 12
## Cover cells a side on the 28 m plate, and how far in from the new plate's
## corner its first cell sits.
const LEGACY_COVER := roundi(Plate.LEGACY_HALF*2.0/Plate.COVER_STEP)
const OFFSET := roundi((Plate.HALF-Plate.LEGACY_HALF)/Plate.COVER_STEP)

static var _lock := Mutex.new()
static var _legacy: NativeTerrainData
static var _legacy_id := ""

## Whether `document` was saved on the 28 m plate.
static func needs(document: Variant) -> bool:
	if not document is Dictionary: return false
	var version: Variant = document.get("version")
	if not GardenData._integer(version) or int(version) < 3 or int(version) > 11: return false
	return document.get("template") == legacy_template()

## The 28 m plate's template id, as its documents carry it.
static func legacy_template() -> String:
	_lock.lock()
	_ensure_legacy()
	var id := _legacy_id
	_lock.unlock()
	return id

## The 28 m plate's terrain, set up with no outline. Callers hold `_lock`.
static func _ensure_legacy() -> void:
	if _legacy != null: return
	var scene: Node = load("res://assets/zen_reference/geometry.scn").instantiate()
	var mesh: ArrayMesh = (scene.get_node("terrain") as MeshInstance3D).mesh
	scene.free()
	_legacy = NativeTerrainData.new()
	_legacy.setup(mesh,[],false)
	_legacy_id = _legacy._template_id()

## `document` (saved on the 28 m plate, `needs`) as a version-12 document for
## `target`'s plate, or null when it cannot be read. What the old loader
## filled in for older versions is filled in here; everything else is left
## for `target.load_document` to check as it checks any document.
static func migrate(document: Dictionary, target: NativeTerrainData) -> Variant:
	if not needs(document): return null
	var version := int(document.version)
	var made := document.duplicate(true)
	made.version = VERSION
	made.template = target._template_id()
	if version < 6: made.terrain_recipe = {}
	if version < 8: made.landscape_waterfall = false
	if version < 7: made.streams = []
	var recipe: Variant = preload("res://scripts/native_terrain_recipe.gd").decode(made.get("terrain_recipe",{}))
	if not preload("res://scripts/native_terrain_recipe.gd").valid(recipe): return null
	# Cover.
	var cells := LEGACY_COVER*LEGACY_COVER
	for field: String in ["meadow","grass","blades"]:
		var values: Variant = document.get(field)
		if (field == "grass" and version == 3) or (field == "blades" and version < 5):
			values = []
			values.resize(cells)
			values.fill(0.0)
		if field == "blades" and version == 4: values = document.get("grass")
		if not values is Array or values.size() != cells: return null
		for value: Variant in values:
			if not GardenData._number(value,0.0,1.0): return null
		made[field] = Array(regrid(PackedFloat32Array(values),1))
	if version >= 9:
		var painted: Variant = NativeTerrainTint.decode(document.get("tint"),cells)
		if painted == null: return null
		made.tint = Array(regrid(painted,NativeTerrainTint.STRIDE))
	else: made.tint = Array(NativeTerrainTint.make(Plate.COVER_CELLS*Plate.COVER_CELLS))
	if document.has("provenance"):
		var hex: Variant = document.provenance
		if not hex is String or hex.length() != cells*2 or not hex.is_valid_hex_number(): return null
		made.provenance = regrid_bytes(hex.hex_decode(),1).hex_encode()
	if document.has("intent_forest"):
		var wish: Variant = preload("res://scripts/land_intent.gd").decode(document.intent_forest,cells)
		if wish == null: return null
		made.intent_forest = preload("res://scripts/land_intent.gd").encode(regrid(wish,1))
	if document.has("water_flow"):
		var flow: Variant = _water(document.water_flow)
		if flow == null: return null
		made.water_flow = flow
	_lock.lock()
	_ensure_legacy()
	var result: Variant = _land(document,made,recipe,target)
	_lock.unlock()
	return result

## Heights and outline, read off the old mesh. Holds `_lock`.
static func _land(document: Dictionary, made: Dictionary, recipe: Dictionary, target: NativeTerrainData) -> Variant:
	var old := _legacy
	var values: Variant = document.get("heights")
	if not values is Array or values.size() != old.heights.size(): return null
	for value: Variant in values:
		if not GardenData._number(value,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT): return null
	var saved := PackedFloat32Array(values)
	var edge := Vector2.ONE*Plate.LEGACY_HALF
	var heights := PackedFloat32Array()
	heights.resize(target.points.size())
	if recipe.is_empty():
		for i in range(target.points.size()):
			heights[i] = float(old.sample(target.points[i].clamp(-edge,edge),saved))
	else:
		# The recipe's own heights at the new points, and what was sculpted into
		# it (the saved heights less the recipe's at the old points) carried
		# over: an untouched landscape reads exactly as it always did. The old
		# plate's rim stood at 0.6 whatever the recipe said, and the new points
		# on and past it read the old heights there as they were.
		var samples := preload("res://scripts/native_recipe_samples.gd")
		var was: PackedFloat32Array = samples.build(recipe,old.points,PackedFloat64Array(),PackedFloat64Array(),false).heights
		var now: PackedFloat32Array = samples.build(recipe,target.points,PackedFloat64Array(),PackedFloat64Array(),false).heights
		var sculpt := saved.duplicate()
		for i in range(sculpt.size()):
			if not _inside_legacy(old.points[i]): was[i] = 0.6
			sculpt[i] -= was[i]
		for i in range(target.points.size()):
			var p := target.points[i]
			if _inside_legacy(p): heights[i] = clampf(now[i]+float(old.sample(p,sculpt)),NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
			else: heights[i] = float(old.sample(p.clamp(-edge,edge),saved))
	made.heights = Array(heights)
	# The outline: the old one under each new face's middle; none was the
	# whole old square.
	var mask := PackedByteArray()
	mask.resize(target.vertex_ids.size()/3)
	mask.fill(1)
	var land: Variant = null
	if document.has("outline"):
		land = old._decode_outline(document.outline)
		if land == null: return null
	for f in range(mask.size()):
		var middle: Vector2 = target._face_center[f]
		if absf(middle.x) >= Plate.LEGACY_HALF or absf(middle.y) >= Plate.LEGACY_HALF: continue
		if land == null:
			mask[f] = 0
			continue
		if old.sample(middle,old.heights) == null: continue
		mask[f] = land[old._locate_face[old._locate_cache[middle]]/3]
	if mask.count(0) == 0: return null
	made.outline = Marshalls.raw_to_base64(mask.compress(FileAccess.COMPRESSION_DEFLATE))
	return made

## Whether `p` lies inside the old plate's rim.
static func _inside_legacy(p: Vector2) -> bool:
	return maxf(absf(p.x),absf(p.y)) < Plate.LEGACY_HALF-0.0001

## A layer of LEGACY_COVER² cells, `stride` values a cell, laid in the
## middle of the plate's COVER_CELLS² (zero round it).
static func regrid(values: PackedFloat32Array, stride: int) -> PackedFloat32Array:
	var side := Plate.COVER_CELLS
	var result := PackedFloat32Array()
	result.resize(side*side*stride)
	for z in range(LEGACY_COVER):
		for x in range(LEGACY_COVER):
			var from := (z*LEGACY_COVER+x)*stride
			var to := ((z+OFFSET)*side+x+OFFSET)*stride
			for k in range(stride): result[to+k] = values[from+k]
	return result

static func regrid_bytes(values: PackedByteArray, stride: int) -> PackedByteArray:
	var side := Plate.COVER_CELLS
	var result := PackedByteArray()
	result.resize(side*side*stride)
	for z in range(LEGACY_COVER):
		for x in range(LEGACY_COVER):
			var from := (z*LEGACY_COVER+x)*stride
			var to := ((z+OFFSET)*side+x+OFFSET)*stride
			for k in range(stride): result[to+k] = values[from+k]
	return result

## Live water (scripts/water_flow.gd `encode`): the springs stay where they
## are; the depths, saved on a grid from the old plate's corner that records
## its own cell and size, are laid on the grid the new plate's corner starts.
## A record the water would not read anyway (scripts/water_flow.gd `decode`)
## is left as it is.
static func _water(value: Variant) -> Variant:
	if not value is Dictionary: return null
	var made: Dictionary = value.duplicate(true)
	if not (GardenData._number(value.get("cell"),0.05,2.0) and GardenData._integer(value.get("width")) and GardenData._integer(value.get("height")) and value.get("depth") is String): return made
	var cell := float(value.cell)
	var width := int(value.width)
	var height := int(value.height)
	var count := width*height
	if count <= 0 or count > 1048576: return made
	var raw := Marshalls.base64_to_raw(value.depth).decompress(count*4,FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != count*4: return made
	var depths := raw.to_float32_array()
	var shift := roundi((Plate.HALF-Plate.LEGACY_HALF)/cell)
	var wide := ceili(Plate.SIZE/cell-0.001)
	var laid := PackedFloat32Array()
	laid.resize(wide*wide)
	for j in range(mini(height,wide-shift)):
		for i in range(mini(width,wide-shift)):
			laid[(j+shift)*wide+i+shift] = depths[j*width+i]
	made.width = wide
	made.height = wide
	made.depth = Marshalls.raw_to_base64(laid.to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE))
	return made
