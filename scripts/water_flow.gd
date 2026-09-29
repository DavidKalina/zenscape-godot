extends RefCounted
## Live water on the plate (docs/scenic/water-flow.md): a shallow-water
## simulation on a regular grid, stepped at a fixed rate apart from the frame.
## Water runs downhill, fills grooves as channels, pools in hollows and spills
## over rims, and follows the land whenever it changes: the ground under every
## cell is read again from the terrain's heights at the start of each step, so
## a sculpt, an undo or a new world moves the water with nothing to hook.
##
## The numbers run in C++ (`ZenScapeWaterFlow`, native/terrain_kernels/
## water_flow.h) when the library is built; scripts/water_flow_reference.gd is
## the GDScript mirror, run on a coarser grid (`FALLBACK_CELL`).
##
## Sources: a water ball dropped on high or steep ground becomes a spring that
## keeps pouring (`springs`, saved and undoable); anywhere else it lets all its
## water go once, over BURST_SECONDS (`bursts`, neither saved nor undone).
## The depth itself is saved with the place but is not part of undo: undoing a
## sculpt puts the land back and the water follows it.

## Grid cell, metres. The native grid is 112×112 over the 28 m plate.
const CELL := 0.25
const FALLBACK_CELL := 0.5
## Fixed step, seconds, and the most steps one frame may run (a slow frame
## slows the water rather than piling work up).
const DT := 1.0/60.0
const FALLBACK_DT := 1.0/30.0
const MAX_TICKS := 4
## Physics (see the doc's tunables table).
const PARAMS := {
	"gravity":9.81,
	# 1/s: still water stops sloshing in a few seconds.
	"friction":0.6,
	# m/s: bed friction that grows as water thins (λ = friction + drag/depth),
	# so a thin sheet on a steep face runs at about 1.5 m/s, a deep channel faster.
	"drag":0.06,
	# m/s lost from every wet cell (0.4 mm/s): a 6 m³ pond lasts about 15 min.
	"evaporation":0.0004,
	# m/s lost from thin water, fading to nothing at soak_depth: fronts soak in.
	"soak":0.004,
	"soak_depth":0.03,
	"max_speed":4.0,
}
## A ball is a spring when it lands SPRING_RISE m above the plate's low ground
## (its LOW_SHARE quantile), or on ground steeper than SPRING_SLOPE.
const SPRING_RISE := 1.2
const SPRING_SLOPE := 0.45
const LOW_SHARE := 0.2
## A spring pours SPRING_SHARE of its ball's volume each second, within
## SPRING_MIN..SPRING_MAX m³/s, over SPRING_RADIUS m, after letting the ball's
## own water go as a burst.
const SPRING_SHARE := 0.012
const SPRING_MIN := 0.03
const SPRING_MAX := 0.25
const SPRING_RADIUS := 0.35
const MAX_SPRINGS := 8
## A burst lets its volume go over BURST_SECONDS across BURST_RADIUS m.
const BURST_SECONDS := 1.2
const BURST_RADIUS := 0.8
## Standing water deeper than POOL_DEPTH and slower than POOL_SPEED, over at
## least POOL_CELLS cells, is a pool (fish and shore life; `pools()`).
const POOL_DEPTH := 0.15
const POOL_SPEED := 0.12
const POOL_CELLS := 12

var data: NativeTerrainData
var kernel: RefCounted
var native := false
var cell := CELL
var dt := DT
var width := 0
var height := 0
var origin := Vector2.ZERO
## [{"x", "z", "rate", "radius"}], saved and undoable.
var springs: Array[Dictionary] = []
## [{"x", "z", "rate", "radius", "left"}], transient.
var bursts: Array[Dictionary] = []
var ready := false
var paused := false
## Bumped every step, so a view can tell new water from old.
var revision := 0
var _clock := 0.0
var _topology := PackedInt32Array()
## Microseconds of the last step and the worst seen, for probes.
var last_step_usec := 0
var worst_step_usec := 0

## Picks the native kernel unless `--gdscript-kernels` asks for the mirror (or
## the library is not built). Build the cell map with `map_cells` (or `setup`).
func _init(terrain: NativeTerrainData, prefer_native := true) -> void:
	data = terrain
	# A library built before the newest method (`cascades`) is stale: use the mirror.
	if prefer_native and preload("res://scripts/native_terrain_kernels.gd").get_kernel() != null and ClassDB.class_exists("ZenScapeWaterFlow") and ClassDB.class_has_method("ZenScapeWaterFlow","cascades"):
		kernel = ClassDB.instantiate("ZenScapeWaterFlow")
		native = true
	else:
		kernel = preload("res://scripts/water_flow_reference.gd").new()
		cell = FALLBACK_CELL
		dt = FALLBACK_DT
	kernel.set_params(PARAMS)
	data.history_captured.connect(func(state: Dictionary) -> void: state["water_springs"] = springs.duplicate(true))
	data.state_restored.connect(_restore)
	data.document_captured.connect(func(document: Dictionary) -> void:
		if ready and (not springs.is_empty() or volume() > 0.01): document["water_flow"] = encode())

## Maps every grid cell to the terrain triangle under its centre, synchronously
## or on a worker when `tree` is given. Call again if the mesh changes.
func setup(tree: SceneTree = null) -> void:
	var low := Vector2(INF,INF)
	var high := -low
	for point: Vector2 in data.points:
		low = low.min(point)
		high = high.max(point)
	origin = low
	width = ceili((high.x-low.x)/cell-0.001)
	height = ceili((high.y-low.y)/cell-0.001)
	var points := data.points
	var ids := data.vertex_ids
	var w := width
	var h := height
	var size := cell
	var start := origin
	var job = preload("res://scripts/background_work.gd").new()
	var mapped: Dictionary = await job.run(func() -> Dictionary: return map_cells(points,ids,size,start,w,h),tree)
	kernel.configure(width,height,cell,origin,mapped.faces,mapped.weights)
	_topology = data.vertex_ids
	ready = true

## For each cell centre of a `w`×`h` grid, the triangle under it: three vertex
## ids and barycentric (u, v) as NativeTerrainData.sample weighs them, or -1.
## Each triangle is rasterised over the cells its bounds cover.
static func map_cells(points: PackedVector2Array, ids: PackedInt32Array, size: float, start: Vector2, w: int, h: int) -> Dictionary:
	var faces := PackedInt32Array()
	faces.resize(w*h*3)
	faces.fill(-1)
	var weights := PackedFloat32Array()
	weights.resize(w*h*2)
	for f in range(0,ids.size(),3):
		var a := points[ids[f]]
		var b := points[ids[f+1]]
		var c := points[ids[f+2]]
		var denominator := (b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
		if absf(denominator) < 0.000001: continue
		var lo := a.min(b).min(c)
		var hi := a.max(b).max(c)
		for j in range(maxi(0,floori((lo.y-start.y)/size-0.5)),mini(h-1,ceili((hi.y-start.y)/size-0.5))+1):
			var z := start.y+(j+0.5)*size
			for i in range(maxi(0,floori((lo.x-start.x)/size-0.5)),mini(w-1,ceili((hi.x-start.x)/size-0.5))+1):
				var at := j*w+i
				if faces[at*3] >= 0: continue
				var x := start.x+(i+0.5)*size
				var u := ((b.y-c.y)*(x-c.x)+(c.x-b.x)*(z-c.y))/denominator
				var v := ((c.y-a.y)*(x-c.x)+(a.x-c.x)*(z-c.y))/denominator
				if u >= -0.00001 and v >= -0.00001 and u+v <= 1.00001:
					faces[at*3] = ids[f]
					faces[at*3+1] = ids[f+1]
					faces[at*3+2] = ids[f+2]
					weights[at*2] = u
					weights[at*2+1] = v
	return {"faces":faces,"weights":weights}

## Runs the fixed steps `delta` seconds owe. True when any ran.
func advance(delta: float) -> bool:
	if not ready or paused: return false
	_clock += minf(delta,0.1)
	var ticks := mini(floori(_clock/dt),MAX_TICKS)
	if ticks <= 0: return false
	_clock = maxf(_clock-ticks*dt,0.0) if ticks < MAX_TICKS else 0.0
	run(ticks)
	return true

## Runs `ticks` fixed steps now.
func run(ticks: int) -> void:
	if not ready: return
	var sources := PackedFloat32Array()
	for spring: Dictionary in springs: sources.append_array([spring.x,spring.z,spring.radius,spring.rate])
	var seconds := ticks*dt
	var finished := false
	for burst: Dictionary in bursts:
		# The last step of a burst pours only what is left.
		var rate: float = minf(burst.rate,float(burst.left)/seconds)
		sources.append_array([burst.x,burst.z,burst.radius,rate])
		burst.left = float(burst.left)-rate*seconds
		finished = finished or burst.left <= 0.0001
	if finished: bursts = bursts.filter(func(burst: Dictionary) -> bool: return burst.left > 0.0001)
	last_step_usec = kernel.step(data.heights,sources,ticks,dt)
	worst_step_usec = maxi(worst_step_usec,last_step_usec)
	revision += 1

## What a ball of `volume` m³ landing at `point` becomes: "spring" or "burst".
func source_kind(point: Vector2) -> String:
	var ground: Variant = data.ground_height(point)
	if ground == null: return ""
	var slope := 0.0
	for direction: Vector2 in [Vector2(0.75,0),Vector2(0,0.75)]:
		var ahead: Variant = data.ground_height(point+direction)
		var behind: Variant = data.ground_height(point-direction)
		if ahead != null and behind != null: slope = maxf(slope,absf(float(ahead)-float(behind))/1.5)
	return "spring" if float(ground)-low_ground() >= SPRING_RISE or slope >= SPRING_SLOPE else "burst"

## The plate's low ground: the LOW_SHARE quantile of its heights.
func low_ground() -> float:
	var sorted := data.heights.duplicate()
	sorted.sort()
	return sorted[clampi(int(sorted.size()*LOW_SHARE),0,sorted.size()-1)] if not sorted.is_empty() else 0.0

## A water ball lands: its water goes as a burst, and on high or steep ground
## a spring stays and keeps pouring. The spring is its own undo step. Returns
## the kind.
func drop(point: Vector2, volume: float) -> String:
	var kind := source_kind(point)
	if kind.is_empty() or not ready: return ""
	bursts.append({"x":point.x,"z":point.y,"rate":volume/BURST_SECONDS,"radius":BURST_RADIUS,"left":volume})
	if kind == "spring":
		data.begin_stroke()
		if springs.size() >= MAX_SPRINGS: springs.pop_front()
		springs.append({"x":point.x,"z":point.y,"rate":clampf(volume*SPRING_SHARE,SPRING_MIN,SPRING_MAX),"radius":SPRING_RADIUS})
		data.end_stroke()
	return kind

## Takes the water within `radius` of `point` and any spring there, as one
## undo step for the springs. Returns the m³ taken.
func drain(point: Vector2, radius: float) -> float:
	var kept := springs.filter(func(spring: Dictionary) -> bool: return Vector2(spring.x,spring.z).distance_to(point) > radius)
	if kept.size() != springs.size():
		data.begin_stroke()
		springs.assign(kept)
		data.end_stroke()
	bursts = bursts.filter(func(burst: Dictionary) -> bool: return Vector2(burst.x,burst.z).distance_to(point) > radius)
	return kernel.drain(point,radius) if ready else 0.0

## Water standing on the plate, m³.
func volume() -> float:
	return float(kernel.stats().volume) if ready else 0.0

func stats() -> Dictionary:
	var found: Dictionary = kernel.stats() if ready else {}
	found.merge({"cell":cell,"width":width,"height":height,"springs":springs.size(),"bursts":bursts.size(),"last_step_usec":last_step_usec,"worst_step_usec":worst_step_usec},true)
	return found

## Depth over each cell (row-major, `width` per row) and ground under it.
func depths() -> PackedFloat32Array:
	return kernel.get_depth() if ready else PackedFloat32Array()

func grounds() -> PackedFloat32Array:
	return kernel.get_ground() if ready else PackedFloat32Array()

## Water depth at a plate point (the cell under it), 0 off the grid.
func depth_at(point: Vector2) -> float:
	var at := cell_at(point)
	return kernel.get_depth()[at] if at >= 0 else 0.0

func cell_at(point: Vector2) -> int:
	var i := floori((point.x-origin.x)/cell)
	var j := floori((point.y-origin.y)/cell)
	return j*width+i if i >= 0 and j >= 0 and i < width and j < height else -1

## Where water stands WET_DEPTH or deeper, for emergence: {"mask" (1 per
## wet cell), "origin", "cell", "width", "height"}. A new dictionary each
## call, so a planner on a worker can keep the one it was given.
const WET_DEPTH := 0.05
func wet_mask() -> Dictionary:
	if not ready: return {}
	return {"mask":kernel.wet_cells(WET_DEPTH),"origin":origin,"cell":cell,"width":width,"height":height}

## True when `mask` (from `wet_mask`) has water at `point`.
static func wet_in(mask: Dictionary, point: Vector2) -> bool:
	if mask.is_empty(): return false
	var i := floori((point.x-float(mask.origin.x))/float(mask.cell))
	var j := floori((point.y-float(mask.origin.y))/float(mask.cell))
	if i < 0 or j < 0 or i >= int(mask.width) or j >= int(mask.height): return false
	return (mask.mask as PackedByteArray)[j*int(mask.width)+i] != 0

func surface(params: Dictionary) -> Dictionary:
	return kernel.surface(params)

## Standing water: [{"x", "z", "cells", "area", "level", "depth", "rect"}].
func pools() -> Array:
	return kernel.pools(POOL_DEPTH,POOL_SPEED,POOL_CELLS) if ready else []

## Steep drops of moving water: flat x0, y0, z0, x1, y1, z1, flux per fall.
func falls(min_flux: float, min_drop: float, min_slope: float, reach: float) -> PackedFloat32Array:
	return kernel.falls(min_flux,min_drop,min_slope,reach) if ready else PackedFloat32Array()

## Waterfalls traced from the flow (ZenScapeWaterFlow::cascades): lip, plunge,
## flux and a course down the face, for scripts/flow_falls.gd.
func cascades(params: Dictionary) -> Array:
	return kernel.cascades(params) if ready else []

## The saved form: springs, and the depth grid deflated as float32, base64.
func encode() -> Dictionary:
	var values: PackedFloat32Array = kernel.get_depth()
	return {"cell":cell,"width":width,"height":height,"springs":springs.duplicate(true),
		"depth":Marshalls.raw_to_base64(values.to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE))}

## A saved form checked for shape, or null. The depth is kept only if it was
## saved on the grid this build runs; the springs always are.
static func decode(value: Variant) -> Variant:
	if not value is Dictionary or not value.get("springs") is Array or value.springs.size() > MAX_SPRINGS: return null
	var found := {"springs":[]}
	for spring: Variant in value.springs:
		if not spring is Dictionary: return null
		for key in ["x","z"]:
			if not GardenData._number(spring.get(key),-14.0,14.0): return null
		if not GardenData._number(spring.get("rate"),0.0,1.0) or not GardenData._number(spring.get("radius"),0.05,3.0): return null
		found.springs.append({"x":float(spring.x),"z":float(spring.z),"rate":float(spring.rate),"radius":float(spring.radius)})
	if GardenData._number(value.get("cell"),0.05,2.0) and GardenData._integer(value.get("width")) and GardenData._integer(value.get("height")) and value.get("depth") is String:
		var count := int(value.width)*int(value.height)
		if count > 0 and count <= 1048576:
			var raw := Marshalls.base64_to_raw(value.depth).decompress(count*4,FileAccess.COMPRESSION_DEFLATE)
			if raw.size() == count*4:
				var depths := raw.to_float32_array()
				var sane := true
				for d in depths:
					if not is_finite(d) or d < 0.0 or d > 80.0:
						sane = false
						break
				if sane: found.merge({"cell":float(value.cell),"width":int(value.width),"height":int(value.height),"depth":depths})
	return found

## Undo and redo bring back the springs; a load brings back the water too; a
## new world (no record at all) starts dry.
func _restore(state: Dictionary) -> void:
	bursts.clear()
	if state.has("water_springs"):
		springs.assign(state.water_springs.duplicate(true))
		return
	var saved: Variant = state.get("water_flow")
	springs.clear()
	if not ready: return
	if data.vertex_ids != _topology: await setup()
	if saved is Dictionary:
		springs.assign(saved.springs)
		if saved.has("depth") and is_equal_approx(float(saved.cell),cell) and int(saved.width) == width and int(saved.height) == height:
			kernel.set_depth(saved.depth)
			return
	var dry := PackedFloat32Array()
	dry.resize(width*height)
	kernel.set_depth(dry)
