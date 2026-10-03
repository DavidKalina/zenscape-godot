extends RefCounted
## Tea lakes: the land decides what colour a lake's water is (the user,
## 2026-10-03). Standing water steeps in what grows and falls round it, as
## a peat or forest lake does: reeds and bank grass at its edge, conifer
## needles, leaf litter, rotting logs and stumps. A crater sunk in bare
## ground stays clear and goes deep blue with depth; the same hollow ringed
## with reeds and pines turns to a dark tarn, umber only over the shelves and
## near-black slate-blue beyond (shaders/reference_water_body.gdshaderinc
## `tea_map`; after Electron's tannin, its ADR 0016, but dark blue, not brown).
##
## Each pool (WaterFlow.pools) has a target from the things within
## SHORE_REACH m of its outline (its rect grown by that much), each kind
## weighing STEEP[kind], over 1 + sqrt(area)/AREA_SPAN, so a big lake needs a
## fuller shore to steep as dark as a pond does. The pool's tea moves to its
## target over STEEP_SECONDS (steeping) or CLEAR_SECONDS (clearing): plant
## reeds round a lake and watch it turn. Nothing is saved: a load or a new
## world takes each lake's target at once (`steep` with `snap`).

const SHORE_REACH := 3.0
const AREA_SPAN := 6.0
const STEEP := {
	"reeds":0.12,"bank_grass":0.06,
	"redwood":0.08,"juniper":0.08,"layered_tree":0.08,
	"leaf_bed":0.1,"log":0.1,"stump":0.08,"snag":0.08,"fern":0.05,"mushroom":0.04,
	"willow":0.05,
}
const STEEP_SECONDS := 40.0
const CLEAR_SECONDS := 90.0
## A pool read again whose outline (its rect) overlaps one read before is the
## same lake, the one it overlaps most. Its "x", "z" are its deepest cell,
## which on a flat-floored crater wanders metres between reads: matched by
## that, a lake started steeping again from clear at every read.
## The tea grid's cells round a pool's rect painted with its tea, so the
## shoreline the linear filter blends to is the lake's own, not clear water.
const PAINT_MARGIN := 2

## [{"x", "z", "tea"}] from the last read.
var lakes: Array[Dictionary] = []
## One byte a cell over the live water's grid (0..255 tea).
var grid := PackedByteArray()

## The target tea of a pool from `objects` (NativeTerrainData.objects).
static func target(pool: Dictionary, objects: Array) -> float:
	var rect: Rect2 = (pool.rect as Rect2).grow(SHORE_REACH)
	var total := 0.0
	for item: Dictionary in objects:
		var weight: float = STEEP.get(str(item.get("asset","")),0.0)
		if weight <= 0.0: continue
		if rect.has_point(Vector2(float(item.x),float(item.z))): total += weight
	return clampf(total/(1.0+sqrt(maxf(float(pool.area),0.0))/AREA_SPAN),0.0,1.0)

## Steeps each pool `seconds` toward its target and paints the grid of
## `flow` (WaterFlow: width, height, cell, origin). With `snap`, each takes
## its target at once. Returns true when the grid changed.
func steep(pools: Array, objects: Array, flow: RefCounted, seconds: float, snap := false) -> bool:
	var next: Array[Dictionary] = []
	for pool: Dictionary in pools:
		var aim := target(pool,objects)
		var tea := aim
		if not snap:
			var before := _overlapping(pool.rect)
			var was: float = before.tea if not before.is_empty() else 0.0
			var span := STEEP_SECONDS if aim > was else CLEAR_SECONDS
			tea = lerpf(was,aim,1.0-exp(-seconds/span))
		next.append({"x":float(pool.x),"z":float(pool.z),"tea":tea,"rect":pool.rect})
	lakes = next
	var w: int = flow.width
	var h: int = flow.height
	var painted := PackedByteArray()
	painted.resize(w*h)
	var cell: float = flow.cell
	var origin: Vector2 = flow.origin
	for lake: Dictionary in lakes:
		var value := int(round(clampf(float(lake.tea),0.0,1.0)*255.0))
		if value <= 0: continue
		var rect: Rect2 = lake.rect
		var i0 := maxi(floori((rect.position.x-origin.x)/cell)-PAINT_MARGIN,0)
		var i1 := mini(floori((rect.end.x-origin.x)/cell)+PAINT_MARGIN,w-1)
		var j0 := maxi(floori((rect.position.y-origin.y)/cell)-PAINT_MARGIN,0)
		var j1 := mini(floori((rect.end.y-origin.y)/cell)+PAINT_MARGIN,h-1)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var c := j*w+i
				painted[c] = maxi(painted[c],value)
	if painted == grid: return false
	grid = painted
	return true

## The tea of the lake whose outline holds `point`, 0 outside them all.
func tea_at(point: Vector2) -> float:
	for lake: Dictionary in lakes:
		if (lake.rect as Rect2).has_point(point): return float(lake.tea)
	return 0.0

func _overlapping(rect: Rect2) -> Dictionary:
	var best := {}
	var most := 0.0
	for lake: Dictionary in lakes:
		var shared := (lake.rect as Rect2).intersection(rect).get_area()
		if shared > most:
			most = shared
			best = lake
	return best
