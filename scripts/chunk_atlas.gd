extends RefCounted
## The chunk atlas: Genesis chunks laid on a square grid and stitched into one
## world (docs/chunk-atlas/DESIGN.md). Pure data: slots, the frontier, edge
## strips and the border pin. The live chunk is the one editable
## NativeTerrainData at the origin; every other slot is a saved document.
##
## Slot (u, v) sits at world x = u*SIZE, z = -v*SIZE, so +v is north (-z), as
## in the Electron source (grid.js centerOf). Edge sides are named by the
## chunk-local border they lie on: n is z = -HALF, s is z = +HALF, e is
## x = +HALF, w is x = -HALF.

const SIZE := 28.0
const HALF := 14.0
## Border samples per edge: the reference terrain's 44 cells, 45 vertices.
const SAMPLES := 45
## Strip heights are frozen at this quantum (strips.js), so both sides of a
## seam hold the very same number.
const QUANTUM := 1e-4
## Width of the correction band as a fraction of SIZE (about 5 m).
const BAND_FRAC := 0.18
const PATH := "user://cozy-worlds/atlas.json"
const VERSION := 1
## Direction to the neighbour across each side, and the side it shows back.
const SIDES := {"n":Vector2i(0,1),"e":Vector2i(1,0),"s":Vector2i(0,-1),"w":Vector2i(-1,0)}
const FACING := {"n":"s","s":"n","e":"w","w":"e"}

## Vector2i -> {"document": Dictionary}. The live slot's entry is its last
## stored copy; the editor holds the current one.
var slots := {}
var live := Vector2i.ZERO
## One seed for every plain, sampled in world metres, so neighbouring plains
## already roll into each other before the pin.
var seed_value := 0

static func offset(slot: Vector2i, origin: Vector2i) -> Vector3:
	return Vector3((slot.x-origin.x)*SIZE,0.0,-(slot.y-origin.y)*SIZE)

## A slot's centre in world metres, for sampling world-space noise.
static func world_origin(slot: Vector2i) -> Vector2:
	return Vector2(slot.x*SIZE,-slot.y*SIZE)

func has(slot: Vector2i) -> bool:
	return slots.has(slot)

func store(slot: Vector2i, document: Dictionary) -> void:
	slots[slot] = {"document":document}

## Free squares orthogonally next to a chunk, the live one included.
## Diagonal-only squares are not offered (slots.js).
func frontier() -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var taken: Array = slots.keys()
	if live not in taken: taken.append(live)
	for slot: Vector2i in taken:
		for side in SIDES:
			var next: Vector2i = slot+SIDES[side]
			if not occupied(next) and next not in found: found.append(next)
	return found

## Sides of `slot` that face a stored chunk: their skirt walls open and their
## border is pinned.
func shared_sides(slot: Vector2i) -> Dictionary:
	var shared := {}
	for side in SIDES:
		if occupied(slot+SIDES[side]): shared[side] = true
	return shared

func occupied(slot: Vector2i) -> bool:
	return slot == live or slots.has(slot)

## Point ids of each border, ordered by the coordinate along it (x for n/s, z
## for e/w). Sample i of a side and sample i of the neighbour's facing side are
## the same world point.
static func edge_ids(points: PackedVector2Array) -> Dictionary:
	var edges := {}
	for side in SIDES:
		var ids := PackedInt32Array()
		ids.resize(SAMPLES)
		ids.fill(-1)
		edges[side] = ids
	var step := SIZE/(SAMPLES-1)
	for id in range(points.size()):
		var p := points[id]
		if absf(p.y+HALF) < 1e-3: edges.n[roundi((p.x+HALF)/step)] = id
		if absf(p.y-HALF) < 1e-3: edges.s[roundi((p.x+HALF)/step)] = id
		if absf(p.x-HALF) < 1e-3: edges.e[roundi((p.y+HALF)/step)] = id
		if absf(p.x+HALF) < 1e-3: edges.w[roundi((p.y+HALF)/step)] = id
	return edges

static func quantize(value: float) -> float:
	return roundf(value/QUANTUM)*QUANTUM

## A side's frozen strip from a height array.
static func strip(heights: PackedFloat32Array, ids: PackedInt32Array) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(ids.size())
	for i in range(ids.size()): values[i] = quantize(heights[ids[i]])
	return values

## Snap every border height to the strip quantum, so a stored chunk's edges
## are exactly the strips its neighbours will be pinned to.
static func quantize_edges(data: NativeTerrainData) -> void:
	var heights := data.heights
	var edges := edge_ids(data.points)
	for side in edges:
		for id in edges[side]: heights[id] = quantize(heights[id])
	data.heights = heights

## Strips `slot` must honour: each stored neighbour's facing border.
func strips_for(slot: Vector2i, points: PackedVector2Array) -> Dictionary:
	var edges := edge_ids(points)
	var strips := {}
	for side in SIDES:
		var next: Vector2i = slot+SIDES[side]
		# The live chunk's stored copy is stale; its borders are in the editor.
		if next == live or not slots.has(next): continue
		var heights: Variant = slots[next].document.get("heights")
		if not heights is Array or heights.size() != points.size(): continue
		strips[side] = strip(PackedFloat32Array(heights),edges[FACING[side]])
	return strips

func pin_for(slot: Vector2i, points: PackedVector2Array) -> Pin:
	return Pin.new(points,strips_for(slot,points))

## Largest height difference between `heights` on `slot`'s borders and its
## stored neighbours' strips.
func seam_delta(slot: Vector2i, heights: PackedFloat32Array, points: PackedVector2Array) -> float:
	var edges := edge_ids(points)
	var worst := 0.0
	var strips := strips_for(slot,points)
	for side in strips:
		for i in range(SAMPLES): worst = maxf(worst,absf(heights[edges[side][i]]-strips[side][i]))
	return worst

## Pulls a chunk's border onto its neighbours' strips. Border offsets blend
## inward over the band as a Coons patch, so corners where two strips meet are
## not counted twice (strips.js makeCorrection). Border vertices are then set
## to the strip exactly. Applying a pin twice changes nothing.
class Pin extends RefCounted:
	var strips := {}
	var _edges := {}
	## Per band vertex: id, then per side its weight and position along the side.
	var _band_ids := PackedInt32Array()
	var _band_weights := {}
	var _band_t := {}

	func _init(points: PackedVector2Array, pinned: Dictionary) -> void:
		strips = pinned
		_edges = preload("res://scripts/chunk_atlas.gd").edge_ids(points)
		if strips.is_empty(): return
		var band: float = preload("res://scripts/chunk_atlas.gd").BAND_FRAC*preload("res://scripts/chunk_atlas.gd").SIZE
		var half: float = preload("res://scripts/chunk_atlas.gd").HALF
		for side in strips:
			_band_weights[side] = PackedFloat32Array()
			_band_t[side] = PackedFloat32Array()
		for id in range(points.size()):
			var p := points[id]
			var near := false
			var weights := {}
			for side in strips:
				var distance: float = {"n":p.y+half,"s":half-p.y,"e":half-p.x,"w":p.x+half}[side]
				weights[side] = 1.0-smoothstep(0.0,band,distance)
				near = near or weights[side] > 0.0
			if not near: continue
			_band_ids.append(id)
			for side in strips:
				_band_weights[side].append(weights[side])
				var along: float = p.x if side in ["n","s"] else p.y
				_band_t[side].append((along+half)/(2.0*half)*(strips[side].size()-1))

	func active() -> bool:
		return not strips.is_empty()

	## Returns the largest border offset it had to close.
	func apply(data: NativeTerrainData) -> float:
		if strips.is_empty(): return 0.0
		var heights := data.heights
		var offsets := {}
		var worst := 0.0
		for side in strips:
			var values := PackedFloat32Array()
			values.resize(strips[side].size())
			for i in range(values.size()):
				values[i] = strips[side][i]-heights[_edges[side][i]]
				worst = maxf(worst,absf(values[i]))
			offsets[side] = values
		if worst == 0.0: return 0.0
		# Corner offsets, where two pinned sides meet.
		var pairs := []
		for pair in [["n","e"],["e","s"],["s","w"],["w","n"]]:
			if strips.has(pair[0]) and strips.has(pair[1]): pairs.append(pair)
		var corner := {}
		for pair in pairs:
			# n/s run along x, e/w along z; the shared corner is at their ends.
			var along_first: int = 0 if (pair[0] in ["n","s"] and pair[1] == "w") or (pair[0] in ["e","w"] and pair[1] == "n") else offsets[pair[0]].size()-1
			corner[pair[0]+pair[1]] = offsets[pair[0]][along_first]
		for k in range(_band_ids.size()):
			var id := _band_ids[k]
			var correction := 0.0
			for side in strips:
				var weight: float = _band_weights[side][k]
				if weight <= 0.0: continue
				var t: float = _band_t[side][k]
				var i := mini(floori(t),offsets[side].size()-2)
				correction += weight*lerpf(offsets[side][i],offsets[side][i+1],t-i)
			for pair in pairs:
				correction -= _band_weights[pair[0]][k]*_band_weights[pair[1]][k]*corner[pair[0]+pair[1]]
			heights[id] += correction
		# The border is law: set it exactly. Where two strips meet at a corner
		# the side named first in `strips` wins.
		for side in strips:
			for i in range(strips[side].size()): heights[_edges[side][i]] = strips[side][i]
		data.heights = heights
		return worst

func to_json() -> Dictionary:
	var saved := []
	for slot: Vector2i in slots:
		saved.append({"u":slot.x,"v":slot.y,"document":slots[slot].document})
	return {"version":VERSION,"seed":seed_value,"live":[live.x,live.y],"slots":saved}

func from_json(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != VERSION or not value.get("slots") is Array: return false
	var live_value: Variant = value.get("live")
	if not live_value is Array or live_value.size() != 2: return false
	var loaded := {}
	for item: Variant in value.slots:
		if not item is Dictionary or not item.get("document") is Dictionary: return false
		loaded[Vector2i(int(item.get("u",0)),int(item.get("v",0)))] = {"document":item.document}
	slots = loaded
	live = Vector2i(int(live_value[0]),int(live_value[1]))
	seed_value = int(value.get("seed",0))
	return true

func save(path := PATH) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temporary := path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(to_json()))
	file.flush()
	var result := file.get_error()
	file.close()
	return result == OK and DirAccess.rename_absolute(temporary,path) == OK

func load(path := PATH) -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return false
	return from_json(JSON.parse_string(file.get_as_text()))
