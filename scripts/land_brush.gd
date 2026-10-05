extends RefCounted
## The creation brush: dragging raises soft, natural land; Shift-drag (or a right drag outside the creation shell)
## lowers it. Each dab has a broad smooth falloff with a quicker core, and
## a ridged, domain-warped noise field seeded per world shapes how much each
## vertex rises, so repeated strokes grow crests and spurs instead of blobs.
## Rising slows toward a dome over the dab's rim (so held dabs round off into
## hills, not spikes) and toward a ceiling; lowering slows toward a shallow floor.
##
## When a stroke ends, `weather` runs the native stream-power erosion
## (scripts/terrain_erosion.gd) over the stroke's bounds only; every grid cell
## outside is locked through the `fixed` mask, so fresh land gets gullies and
## aprons while the rest of the world stays exactly as it was.
const Erosion = preload("res://scripts/terrain_erosion.gd")
const Plate = preload("res://scripts/plate.gd")
## Bucket size for the per-vertex lookup, in metres.
const CELL := 2.0
## Peak rise in metres per second at the stroke centre, at strength 1.
const RATE := 2.4
## Lowering never digs below this floor, a little over
## NativeTerrainData.MIN_HEIGHT.
const FLOOR := NativeTerrainData.MIN_HEIGHT+0.3
## Rounded hills: one dab never lifts land above a dome over the ground at its
## rim, `DOME` metres high per metre of radius, shaped (1-t²)² and scaled by
## the ridge field (`DOME_RIDGE`). Its steepest flank is about 1.54·DOME·ridge,
## under the plain's rock slope (0.93), so held dabs round off into green
## hills instead of stacking a bare spike; the rim keeps rising slowly, so
## repeated strokes still grow a mountain. RIM is the ring (in radii) that
## sets the dome's base, and EASE the share of the dome's height over which
## rising slows as it nears the dome.
const DOME := 0.4
const DOME_RIDGE := Vector2(0.8,1.25)
const RIM := 0.8
const EASE := 0.35
## Share of the rise in the quicker core under the pointer (the rest is the
## broad shoulders). A strong core stacks into a spike on a held dab.
const CORE := 0.18
## Stroke erosion: gentler than a generated world's families, since the same
## place may be weathered after every stroke. No detail term: it would add the
## same ridged pattern again on each pass.
const WEATHER := {"detail":0.0,"frequency":0.16,"warp":1.3,"slope_ref":1.2,"iterations":20,"k":0.012,
	"channel_area":2.5,"jitter":0.6,"max_cut":0.7,"deposit":0.5,"deposit_slope":0.35,"deposit_cap":0.05,
	"edge_inner":Plate.HALF-2.4,"edge_outer":Plate.HALF-0.6}
## The creation brush interface (scripts/creation_brush.gd); land keeps its
## size and strength on the editor (land_radius, land_strength).
var brush_id := "land"
var settles := false
var seed_value := -1
var _ridge := PackedFloat32Array()
var _cells := {}
var _points := 0
## World-space XZ bounds of the stroke in progress; empty size when none.
var bounds := Rect2()
var has_bounds := false
var last_weather_usec := 0

## Rebuild the per-vertex ridge field and buckets when the seed or mesh changes.
func prepare(data: NativeTerrainData, world_seed: int) -> void:
	if world_seed == seed_value and _points == data.points.size(): return
	seed_value = world_seed
	_points = data.points.size()
	var ridge := FastNoiseLite.new()
	ridge.seed = world_seed
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridge.frequency = 0.085
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 3
	ridge.fractal_lacunarity = 2.1
	ridge.fractal_gain = 0.45
	var warp := FastNoiseLite.new()
	warp.seed = world_seed+911
	warp.frequency = 0.05
	_ridge.resize(_points)
	_cells.clear()
	for i in range(_points):
		var p: Vector2 = data.points[i]
		var q := p+Vector2(warp.get_noise_2d(p.x,p.y),warp.get_noise_2d(p.x+37.1,p.y-11.7))*3.2
		_ridge[i] = clampf(ridge.get_noise_2d(q.x,q.y)*0.5+0.5,0.0,1.0)
		var key := Vector2i(floori(p.x/CELL),floori(p.y/CELL))
		if not _cells.has(key): _cells[key] = PackedInt32Array()
		_cells[key].append(i)

## Land keeps its size and strength on the editor (land_radius, land_strength).
func activate(_owner: Node) -> void:
	pass

func deactivate(_owner: Node) -> void:
	pass

func begin() -> void:
	has_bounds = false
	bounds = Rect2()

## One dab. `amount` is seconds of brushing times strength; `lower` digs.
func dab(data: NativeTerrainData, center: Vector2, radius: float, amount: float, lower: bool, ceiling: float) -> void:
	if radius <= 0.0 or amount <= 0.0 or _ridge.size() != data.points.size(): return
	var reach := Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2.0)
	bounds = bounds.merge(reach) if has_bounds else reach
	has_bounds = true
	var low := Vector2i(floori(reach.position.x/CELL),floori(reach.position.y/CELL))
	var high := Vector2i(floori(reach.end.x/CELL),floori(reach.end.y/CELL))
	var inverse := 1.0/radius
	var band := maxf(ceiling*0.4,1.0)
	# Write through a local copy: one copy-on-write per dab, not one per vertex.
	var heights := data.heights
	var inside := PackedInt32Array()
	var rim_total := 0.0
	var rim_count := 0
	for cz in range(low.y,high.y+1):
		for cx in range(low.x,high.x+1):
			var cell: Variant = _cells.get(Vector2i(cx,cz))
			if cell == null: continue
			for i: int in cell:
				var t := data.points[i].distance_to(center)*inverse
				if t >= 1.0: continue
				inside.append(i)
				if t >= RIM:
					rim_total += heights[i]
					rim_count += 1
	# The dome stands on the ground around the dab (the lowest point under it
	# when the rim is off the mesh).
	var rim := rim_total/rim_count if rim_count > 0 else INF
	if rim_count == 0:
		for i in inside: rim = minf(rim,heights[i])
	var dome := radius*DOME
	for i in inside:
		var t := data.points[i].distance_to(center)*inverse
		var broad := 1.0-t*t
		# Broad smooth shoulders, plus a gentle quicker core under the pointer.
		var weight := broad*broad*(1.0-CORE)+exp(-t*t*9.0)*CORE
		var n: float = _ridge[i]
		var h: float = heights[i]
		if lower:
			# Hollows follow the noise troughs, easing out near the floor.
			var room := clampf((h-FLOOR)/1.6,0.0,1.0)
			h -= amount*RATE*weight*(0.55+(1.0-n)*0.8)*room
			heights[i] = maxf(h,minf(FLOOR,heights[i]))
		else:
			# Crests follow the ridges; rising slows toward the dome over the
			# rim and toward the ceiling, and never lowers land already above.
			var cap := minf(ceiling,rim+dome*broad*broad*lerpf(DOME_RIDGE.x,DOME_RIDGE.y,n))
			var headroom := clampf((ceiling-h)/band,0.0,1.0)*clampf((cap-h)/maxf(dome*EASE,0.05),0.0,1.0)
			h += amount*RATE*weight*(0.4+n*1.2)*headroom
			heights[i] = minf(h,maxf(cap,heights[i]))
	data.heights = heights

## Weather the finished stroke: erode its bounds, lock everything else.
## Returns true when heights moved. Runs on the calling thread; the editor
## runs the same work on a worker through `weather_job`.
func weather(data: NativeTerrainData) -> bool:
	var job := weather_job(data)
	if not job.is_valid(): return false
	var result: Dictionary = job.call()
	last_weather_usec = result.usec
	if not result.moved: return false
	data.heights = result.heights
	return true

## The finished stroke's weathering as a pure-data callable over a detached
## height copy taken now. It returns {"moved","heights","usec"}; the caller
## publishes `heights` only while the terrain still holds the heights it was
## taken from. Empty when the stroke has no bounds. Clears the bounds.
func weather_job(data: NativeTerrainData) -> Callable:
	if not has_bounds: return Callable()
	has_bounds = false
	var region := bounds.grow(Erosion.CELL*2.0).intersection(Plate.RECT)
	if region.size.x <= 0.0 or region.size.y <= 0.0: return Callable()
	# The native kernel loads on the main thread, before a worker needs it.
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	var ground: NativeTerrainData = preload("res://scripts/native_terrain_snapshot.gd").for_height(data)
	var settings := WEATHER.duplicate()
	settings.merge({"size":Erosion.SIZE,"cell":Erosion.CELL,"origin":Erosion.ORIGIN,"seed":(seed_value+7919)&0xffffffff})
	return func() -> Dictionary: return _weathered(ground,region,settings)

## `data` is a detached copy. Vertices are walked in index order rather than
## through the brush's buckets (which a new press may rebuild); each vertex's
## change depends only on its own position, so the result is the same.
static func _weathered(data: NativeTerrainData, region: Rect2, settings: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := {"moved":false,"heights":PackedFloat32Array(),"usec":0}
	var size: int = Erosion.SIZE
	var base := PackedFloat64Array()
	var fixed := PackedByteArray()
	base.resize(size*size)
	fixed.resize(size*size)
	var any := false
	for j in range(size):
		for i in range(size):
			var p := Vector2(Erosion.ORIGIN+i*Erosion.CELL,Erosion.ORIGIN+j*Erosion.CELL)
			var h: Variant = data.sample(p,data.heights)
			var c := j*size+i
			base[c] = float(h) if h != null else 0.0
			var inside := h != null and region.has_point(p) and not data.is_void(p)
			fixed[c] = 0 if inside else 1
			any = any or inside
	if not any: return result
	var delta := Erosion.erode(base,fixed,settings)
	if delta.size() != size*size: return result
	var heights := data.heights
	var reach := region.grow(Erosion.CELL)
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if not reach.has_point(p): continue
		var change := Erosion.sample(delta,p.x,p.y)
		if absf(change) < 0.0005: continue
		heights[i] = clampf(heights[i]+change,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
		result.moved = true
	result.heights = heights
	result.usec = Time.get_ticks_usec()-started
	return result
