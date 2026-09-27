extends RefCounted
## The creation brush: dragging raises soft, natural land; Shift or a right
## drag lowers it. Each dab has a broad smooth falloff with a quicker core, and
## a ridged, domain-warped noise field seeded per world shapes how much each
## vertex rises, so repeated strokes grow crests and spurs instead of blobs.
## Rising slows toward a ceiling; lowering slows toward a shallow floor.
##
## When a stroke ends, `weather` runs the native stream-power erosion
## (scripts/terrain_erosion.gd) over the stroke's bounds only; every grid cell
## outside is locked through the `fixed` mask, so fresh land gets gullies and
## aprons while the rest of the world stays exactly as it was.
const Erosion = preload("res://scripts/terrain_erosion.gd")
## The creation brush list (scripts/genesis_canvas.gd) reads these.
const brush_id := "land"
const title := "Land"
const HINT := "Drag to raise land  ·  Shift or right drag lowers  ·  [ ] brush size  ·  drag the sky to orbit"
## Bucket size for the per-vertex lookup, in metres.
const CELL := 2.0
## Peak rise in metres per second at the stroke centre, at strength 1.
const RATE := 2.4
## Lowering never digs below this floor (NativeTerrainData.MIN_HEIGHT is -1.5).
const FLOOR := -1.2
## Stroke erosion: gentler than a generated world's families, since the same
## place may be weathered after every stroke. No detail term: it would add the
## same ridged pattern again on each pass.
const WEATHER := {"detail":0.0,"frequency":0.16,"warp":1.3,"slope_ref":1.2,"iterations":20,"k":0.012,
	"channel_area":2.5,"jitter":0.6,"max_cut":0.7,"deposit":0.5,"deposit_slope":0.35,"deposit_cap":0.05,
	"edge_inner":11.6,"edge_outer":13.4}
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
	for cz in range(low.y,high.y+1):
		for cx in range(low.x,high.x+1):
			var cell: Variant = _cells.get(Vector2i(cx,cz))
			if cell == null: continue
			for i: int in cell:
				var t := data.points[i].distance_to(center)*inverse
				if t >= 1.0: continue
				var broad := 1.0-t*t
				# Broad smooth shoulders, plus a quicker core under the pointer.
				var weight := broad*broad*0.62+exp(-t*t*9.0)*0.38
				var n: float = _ridge[i]
				var h: float = heights[i]
				if lower:
					# Hollows follow the noise troughs, easing out near the floor.
					var room := clampf((h-FLOOR)/1.6,0.0,1.0)
					h -= amount*RATE*weight*(0.55+(1.0-n)*0.8)*room
					heights[i] = maxf(h,minf(FLOOR,heights[i]))
				else:
					# Crests follow the ridges; rising slows toward the ceiling and
					# never lifts land that already stands above it.
					var headroom := clampf((ceiling-h)/band,0.0,1.0)
					h += amount*RATE*weight*(0.4+n*1.2)*headroom
					heights[i] = minf(h,maxf(ceiling,heights[i]))
	data.heights = heights

## Weather the finished stroke: erode its bounds, lock everything else.
## Returns true when heights moved.
func weather(data: NativeTerrainData) -> bool:
	if not has_bounds: return false
	var started := Time.get_ticks_usec()
	var region := bounds.grow(Erosion.CELL*2.0).intersection(Rect2(-14,-14,28,28))
	has_bounds = false
	if region.size.x <= 0.0 or region.size.y <= 0.0: return false
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
	if not any: return false
	var settings := WEATHER.duplicate()
	settings.merge({"size":size,"cell":Erosion.CELL,"origin":Erosion.ORIGIN,"seed":(seed_value+7919)&0xffffffff})
	var delta := Erosion.erode(base,fixed,settings)
	if delta.size() != size*size: return false
	var moved := false
	var heights := data.heights
	var reach := region.grow(Erosion.CELL)
	for cz in range(floori(reach.position.y/CELL),floori(reach.end.y/CELL)+1):
		for cx in range(floori(reach.position.x/CELL),floori(reach.end.x/CELL)+1):
			var cell: Variant = _cells.get(Vector2i(cx,cz))
			if cell == null: continue
			for i: int in cell:
				var p: Vector2 = data.points[i]
				if not reach.has_point(p): continue
				var change := Erosion.sample(delta,p.x,p.y)
				if absf(change) < 0.0005: continue
				heights[i] = clampf(heights[i]+change,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
				moved = true
	data.heights = heights
	last_weather_usec = Time.get_ticks_usec()-started
	return moved
