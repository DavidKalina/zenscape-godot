extends RefCounted
## Quiet guidance (docs/scenic/guidance.md). A regional beauty score the player
## never sees, and the small nudges it steers, so the world seems to have taste
## without arranging anything.
##
## The score reads one dirty rect at a time on a 1 m grid: relief, water and
## its shore, forest edges, openness against clutter, cover variety and the
## framing from the overview camera. Each term lies in 0..1.
##
## The nudges are the same terms asked locally, and each is small:
## - water: a pond's level may drop a few centimetres when that trims a thin
##   fringe (water_brush.gd `_settle`), and a scooped hollow may sit up to
##   1.5 m from the lowest point, clear of thin land between ponds, as a soft
##   oval along the contour (`_scoop_sites`, `_scoop`);
## - edges: where a forest wish's edge reads as a ruled line, trees read the
##   wish a little way off, so the edge wanders into bays and bulges; a lone
##   tree in an ordinary spot usually does not take (emergence.gd);
## - variant choice: a plant's size leans between two hash draws, larger on a
##   feature spot (knoll, shore, a third of the overview), smaller in front of
##   water; trees thin in front of water outside a forest's core;
## - spacing: undergrowth already crowded by its neighbours usually yields.
##
## Every nudge is a pure function of the ground, the salt and position hashes,
## so the same strokes give the same world. Only emerged plants and new water
## are nudged; hand, pinned and generated work never is. `--no-guidance` turns
## all of it off for A/B.
const Variety = preload("res://scripts/seeded_variety.gd")
const Beauty = preload("res://scripts/world_beauty.gd")

## False with --no-guidance: water plans, emergence and the probe read it.
static var enabled := "--no-guidance" not in OS.get_cmdline_user_args()
## The water nudges alone, for probes that hold the ground fixed.
static var water_enabled := true

## The guide grid: 1 m cells over the 28 m plate, as the biome blend's.
const CELLS := 28
## Weights of the score's terms.
const WEIGHTS := {"relief":0.15,"water":0.2,"edges":0.2,"openness":0.15,"variety":0.1,"framing":0.2}
## Metres a region's fields reach past its rect, so edges and sightlines just
## outside it still count.
const REACH := 4.0

## Forest edges. Coherence of the edge's direction over STRAIGHT_WINDOW cells
## where it starts and finishes reading as a straight line; how far (metres)
## the wish is read off at a fully straight edge, and the size of its bays
## (FRAY_FREQUENCY, 1/m).
const STRAIGHT := Vector2(0.72,0.93)
const STRAIGHT_WINDOW := 4
const WARP := 3.0
## The score reads the canopy's outline through a kernel this wide (metres).
const OUTLINE_REACH := 3.0
## ... and judges its straightness over this many cells either side: trees
## stand 1-2 m apart, so a line only shows over a longer run than a wish's.
const OUTLINE_WINDOW := 6
const FRAY_FREQUENCY := 0.18
## Lone trees: a tree with no other tree planned or standing within
## LONE_RADIUS, off a feature spot (FEATURE_KEEP), takes with 1 - LONE_DROP.
const LONE_RADIUS := 3.0
const LONE_DROP := 0.7
const FEATURE_KEEP := 0.5
## Sightlines: ground within SIGHT_REACH metres in front of water (toward the
## overview camera) keeps trees at 1 - SIGHT_THIN outside a forest's core.
const SIGHT_REACH := 4.0
const SIGHT_THIN := 0.55
## Spacing: undergrowth with CLUTTER_MAX plants already within CLUTTER_RADIUS
## yields with CLUTTER_DROP.
const CLUTTER_RADIUS := 1.2
const CLUTTER_MAX := 3
const CLUTTER_DROP := 0.6
## Water level: a new pond may sit up to LEVEL_TRIM lower, in LEVEL_STEPS,
## when that trims its thin fringe; LEVEL_COST weighs the water given up.
const LEVEL_TRIM := 0.05
const LEVEL_STEPS := 5
const LEVEL_COST := 0.6
## How hard thin water (one-cell tongues, one-cell strips of land) marks a
## shore down, against the water's size.
const THIN_WEIGHT := 5.0
const LEVEL_MARGIN := 0.04
## Hollows: sites within SITE_SLACK metres of the lowest, up to SITE_REACH
## grid cells away; land thinner than SLIVER_GAP between a hollow and other
## water reads as a sliver. An oval hollow is SCOOP_STRETCH long for wide.
const SITE_SLACK := 0.12
const SITE_REACH := 3
const SLIVER_GAP := 2.0
const SCOOP_STRETCH := Vector2(1.1,1.35)

## Per-region fields and gains, planned on the emergence worker.
class Guide extends RefCounted:
	var straight := PackedFloat32Array()
	var sight := PackedFloat32Array()
	var feature := PackedFloat32Array()
	## The region's score before it grew, and how hard each nudge leans:
	## a region already strong in a term is nudged less for it.
	var score := {}
	var gain := {"lone":1.0,"sight":1.0,"clutter":1.0}
	var usec := 0
	var fray_noise: FastNoiseLite

	func at(values: PackedFloat32Array, p: Vector2) -> float:
		return values[clampi(floori(p.y+14.0),0,27)*28+clampi(floori(p.x+14.0),0,27)]

	## Bilinear read, for fields that move things smoothly.
	func smooth(values: PackedFloat32Array, p: Vector2) -> float:
		var g := p+Vector2(13.5,13.5)
		var x0 := clampi(floori(g.x),0,27)
		var z0 := clampi(floori(g.y),0,27)
		var x1 := mini(x0+1,27)
		var z1 := mini(z0+1,27)
		var fx := clampf(g.x-x0,0.0,1.0)
		var fz := clampf(g.y-z0,0.0,1.0)
		return lerpf(lerpf(values[z0*28+x0],values[z0*28+x1],fx),lerpf(values[z1*28+x0],values[z1*28+x1],fx),fz)

	## Where a candidate at `p` reads the forest wish: `p` itself where the
	## edge already curves, up to WARP metres off along slow noise where it
	## reads as a ruled line.
	func warp(p: Vector2) -> Vector2:
		var s := smooth(straight,p)
		if s <= 0.0: return Vector2.ZERO
		return Vector2(fray_noise.get_noise_2d(p.x,p.y),fray_noise.get_noise_2d(p.x+71.3,p.y-23.9))*WARP*s

	## Share of a tree's chance kept in front of water.
	func sight_keep(p: Vector2) -> float:
		return 1.0-SIGHT_THIN*at(sight,p)*float(gain.sight)

	## A size draw leaning between two hash draws: larger on a feature spot,
	## smaller in front of water.
	func size_draw(p: Vector2, first: float, second: float, tree: bool) -> float:
		var lean := at(sight,p)*-0.8
		if tree: lean += at(feature,p)
		lean = clampf(lean,-1.0,1.0)
		if lean >= 0.0: return lerpf(first,maxf(first,second),lean)
		return lerpf(first,minf(first,second),-lean)

## Plants near `rect` as (x, z, tree 1/0, size), for a planner that has no
## object records. Read on the main thread; cheap next to a plan.
static func plants(objects: Array, rect: Rect2, trees: Array) -> PackedVector4Array:
	var found := PackedVector4Array()
	var area := rect.grow(REACH+LONE_RADIUS)
	for item: Dictionary in objects:
		if item.asset == "waterfall": continue
		var x := float(item.x)
		var z := float(item.z)
		if not area.has_point(Vector2(x,z)): continue
		found.append(Vector4(x,z,1.0 if item.asset in trees else 0.0,float(item.get("scale",1.0))))
	return found

## The camera the plate is usually seen from (world_beauty.gd's overview).
static func _eye() -> Vector3:
	return Beauty.TARGET+Vector3(sin(Beauty.POLAR)*sin(Beauty.YAW),cos(Beauty.POLAR),sin(Beauty.POLAR)*cos(Beauty.YAW))*Beauty.DISTANCE

## Horizontal direction from the ground toward the overview camera.
static func toward_camera() -> Vector2:
	return Vector2(sin(Beauty.YAW),cos(Beauty.YAW))

## 0..1 nearness to a rule-of-thirds point of the overview, per 1 m cell.
static func thirds() -> PackedFloat32Array:
	var eye := _eye()
	var view := Basis.looking_at(Beauty.TARGET-eye,Vector3.UP)
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for corner in [Vector2(-14,-14),Vector2(14,-14),Vector2(14,14),Vector2(-14,14)]:
		var s := Beauty._project(eye,view,Vector3(corner.x,0.0,corner.y))
		low = low.min(s)
		high = high.max(s)
	var values := PackedFloat32Array()
	values.resize(CELLS*CELLS)
	for z in range(CELLS):
		for x in range(CELLS):
			var s := (Beauty._project(eye,view,Vector3(x-13.5,0.0,z-13.5))-low)/(high-low)
			var near := INF
			for t in [Vector2(1,1),Vector2(2,1),Vector2(1,2),Vector2(2,2)]:
				near = minf(near,s.distance_to(t/3.0))
			values[z*CELLS+x] = 1.0-smoothstep(0.05,0.13,near)
	return values

static func _cell_center(x: int, z: int) -> Vector2:
	return Vector2(x-13.5,z-13.5)

static func _cells(rect: Rect2) -> Rect2i:
	var low := Vector2i(clampi(floori(rect.position.x+14.0),0,CELLS-1),clampi(floori(rect.position.y+14.0),0,CELLS-1))
	var high := Vector2i(clampi(ceili(rect.end.x+14.0),0,CELLS),clampi(ceili(rect.end.y+14.0),0,CELLS))
	return Rect2i(low,(high-low).max(Vector2i.ZERO))

## Plan a region's guide on the planner: fields over the rect and its reach,
## the region's score, and gains from it. `emergence` is the planner (its
## blend, forest wish and salt); `known` its plants near the rect.
static func plan(emergence: RefCounted, rect: Rect2, known: PackedVector4Array) -> Guide:
	var began := Time.get_ticks_usec()
	var guide := Guide.new()
	var blend: RefCounted = emergence._blend
	var area := _cells(rect.grow(REACH))
	guide.straight = straightness(_wish_grid(emergence.data,emergence.intent.forest),0.08,0.75,area)
	guide.sight = sightlines(blend,area)
	guide.feature = features(blend,area)
	guide.fray_noise = FastNoiseLite.new()
	guide.fray_noise.seed = Variety.mix([emergence.salt,53])
	guide.fray_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	guide.fray_noise.frequency = FRAY_FREQUENCY
	# One octave: slow bays, no fine wobble (the edge's own scatter has that).
	guide.fray_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	guide.score = score(emergence.data,blend,known,rect,guide.feature)
	# A region already open, well edged or well framed is nudged less there.
	guide.gain = {"lone":clampf(1.4-float(guide.score.edges),0.6,1.0),"sight":clampf(1.4-float(guide.score.framing),0.6,1.0),"clutter":clampf(1.4-float(guide.score.openness),0.6,1.0)}
	guide.usec = Time.get_ticks_usec()-began
	return guide

## The forest wish averaged onto the 1 m grid (it lives on 0.5 m cells).
static func _wish_grid(data: NativeTerrainData, wish: PackedFloat32Array) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(CELLS*CELLS)
	var side: int = data.MEADOW_CELLS
	if wish.size() != side*side: return values
	for z in range(CELLS):
		for x in range(CELLS):
			values[z*CELLS+x] = (wish[z*2*side+x*2]+wish[z*2*side+x*2+1]+wish[(z*2+1)*side+x*2]+wish[(z*2+1)*side+x*2+1])*0.25
	return values

## How straight an edge reads around each cell, 0..1: the axial coherence of
## the field's gradient over the edge cells (values in lo..hi) within
## STRAIGHT_WINDOW. A ruled stroke's edges read 1; a round patch reads 0.
static func straightness(values: PackedFloat32Array, lo: float, hi: float, area: Rect2i, w := STRAIGHT_WINDOW) -> PackedFloat32Array:
	var axes := PackedVector2Array()
	axes.resize(CELLS*CELLS)
	var edge := PackedByteArray()
	edge.resize(CELLS*CELLS)
	var any := false
	# Edge cells are read a window past the area, so two regions agree where
	# they overlap.
	var source := area.grow(w).intersection(Rect2i(0,0,CELLS,CELLS))
	for z in range(source.position.y,source.end.y):
		for x in range(source.position.x,source.end.x):
			var v := values[z*CELLS+x]
			if v <= lo or v >= hi: continue
			var g := Vector2(values[z*CELLS+mini(x+1,CELLS-1)]-values[z*CELLS+maxi(x-1,0)],values[mini(z+1,CELLS-1)*CELLS+x]-values[maxi(z-1,0)*CELLS+x])
			if g.length() < 0.02: continue
			# Double the angle, so the two sides of a band agree.
			axes[z*CELLS+x] = Vector2.from_angle(g.angle()*2.0)
			edge[z*CELLS+x] = 1
			any = true
	var straight := PackedFloat32Array()
	straight.resize(CELLS*CELLS)
	if not any: return straight
	# Summed-area tables of the axes and the edge count: a square window of
	# STRAIGHT_WINDOW cells either side costs four reads per cell.
	var span := CELLS+1
	var sum_x := PackedFloat32Array()
	var sum_y := PackedFloat32Array()
	var sum_n := PackedInt32Array()
	sum_x.resize(span*span)
	sum_y.resize(span*span)
	sum_n.resize(span*span)
	for z in range(CELLS):
		for x in range(CELLS):
			var a := axes[z*CELLS+x]
			var o := (z+1)*span+x+1
			sum_x[o] = a.x+sum_x[o-1]+sum_x[o-span]-sum_x[o-span-1]
			sum_y[o] = a.y+sum_y[o-1]+sum_y[o-span]-sum_y[o-span-1]
			sum_n[o] = edge[z*CELLS+x]+sum_n[o-1]+sum_n[o-span]-sum_n[o-span-1]
	for z in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var x0 := maxi(x-w,0)
			var z0 := maxi(z-w,0)
			var x1 := mini(x+w+1,CELLS)
			var z1 := mini(z+w+1,CELLS)
			var count := sum_n[z1*span+x1]-sum_n[z0*span+x1]-sum_n[z1*span+x0]+sum_n[z0*span+x0]
			if count < 4: continue
			var sx := sum_x[z1*span+x1]-sum_x[z0*span+x1]-sum_x[z1*span+x0]+sum_x[z0*span+x0]
			var sy := sum_y[z1*span+x1]-sum_y[z0*span+x1]-sum_y[z1*span+x0]+sum_y[z0*span+x0]
			straight[z*CELLS+x] = smoothstep(STRAIGHT.x,STRAIGHT.y,Vector2(sx,sy).length()/count)
	return straight

## 0..1 per cell: how directly the cell stands in front of water as seen from
## the overview (water within SIGHT_REACH metres beyond it, away from the
## camera). Water itself reads 0.
static func sightlines(blend: RefCounted, area: Rect2i) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(CELLS*CELLS)
	if not blend.has_water: return values
	var wet: PackedByteArray = blend._wet
	var away := -toward_camera()
	for z in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			if wet[z*CELLS+x] == 1: continue
			var p := _cell_center(x,z)
			var d := 0.5
			while d <= SIGHT_REACH:
				var q := p+away*d
				var qx := floori(q.x+14.0)
				var qz := floori(q.y+14.0)
				if qx < 0 or qz < 0 or qx >= CELLS or qz >= CELLS: break
				if wet[qz*CELLS+qx] == 1:
					values[z*CELLS+x] = 1.0-smoothstep(1.0,SIGHT_REACH,d)
					break
				d += 0.5
	return values

## 0..1 per cell: a spot a tree would stand out well from: a knoll, a shore a
## little back from the water, or a third of the overview's frame.
static func features(blend: RefCounted, area: Rect2i) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(CELLS*CELLS)
	var heights: PackedFloat32Array = blend._heights
	var distance: PackedFloat32Array = blend._water_distance
	var third := thirds()
	for z in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var h := heights[z*CELLS+x]
			var ring := 0.0
			var count := 0
			for offset in [Vector2i(3,0),Vector2i(-3,0),Vector2i(0,3),Vector2i(0,-3),Vector2i(2,2),Vector2i(-2,2),Vector2i(2,-2),Vector2i(-2,-2)]:
				var n: Vector2i = Vector2i(x,z)+offset
				if n.x < 0 or n.y < 0 or n.x >= CELLS or n.y >= CELLS: continue
				ring += heights[n.y*CELLS+n.x]
				count += 1
			var knoll := smoothstep(0.25,1.0,h-ring/maxi(count,1))
			var shore := 0.0
			if blend.has_water:
				var d := distance[z*CELLS+x]
				shore = smoothstep(0.8,1.8,d)*(1.0-smoothstep(3.0,4.5,d))
			values[z*CELLS+x] = maxf(knoll,maxf(shore*0.85,third[z*CELLS+x]*0.7))
	return values

## The regional beauty score over `rect`: each term 0..1 and their weighted
## `total`, plus counts for probes. `known` holds the plants (plants()),
## `feature` a features() field or empty to build one.
static func score(data: NativeTerrainData, blend: RefCounted, known: PackedVector4Array, rect: Rect2, feature := PackedFloat32Array()) -> Dictionary:
	var area := _cells(rect)
	if feature.is_empty(): feature = features(blend,area)
	var heights: PackedFloat32Array = blend._heights
	var wet: PackedByteArray = blend._wet
	var land: PackedByteArray = blend._land
	# Plants by metre cell.
	var near := {}
	for plant in known: near.get_or_add(Vector2i(floori(plant.x),floori(plant.y)),[]).append(plant)
	var cells: Array[Vector2i] = []
	var sum := 0.0
	var sum2 := 0.0
	var lowest := INF
	var highest := -INF
	var wet_cells := 0
	var open := 0
	var dry := 0
	var classes := [0,0,0,0,0]
	# Plants splatted onto the grid: canopy shade, and trees or undergrowth
	# close to each cell's centre.
	var canopy := PackedFloat32Array()
	canopy.resize(CELLS*CELLS)
	var tree_near := PackedByteArray()
	tree_near.resize(CELLS*CELLS)
	var shrub_near := PackedByteArray()
	shrub_near.resize(CELLS*CELLS)
	# The canopy's outline at the scale the overview reads it: a broad kernel,
	# so a forest's edge is a smooth ramp and a ruled one reads as a line.
	var outline := PackedFloat32Array()
	outline.resize(CELLS*CELLS)
	for plant in known:
		var tree := plant.z > 0.5
		var reach := OUTLINE_REACH if tree else 0.8
		for z in range(maxi(floori(plant.y+14.0-reach),0),mini(floori(plant.y+14.0+reach)+1,CELLS)):
			for x in range(maxi(floori(plant.x+14.0-reach),0),mini(floori(plant.x+14.0+reach)+1,CELLS)):
				var d := _cell_center(x,z).distance_to(Vector2(plant.x,plant.y))
				if tree:
					canopy[z*CELLS+x] += maxf(0.0,1.0-d/2.2)
					outline[z*CELLS+x] += maxf(0.0,1.0-d/OUTLINE_REACH)*0.5
					if d < 1.5: tree_near[z*CELLS+x] = 1
				elif d < 0.8: shrub_near[z*CELLS+x] = 1
	var grass_ok := data.grass.size() == data.MEADOW_CELLS*data.MEADOW_CELLS
	for z in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var i := z*CELLS+x
			if land[i] == 0: continue
			var p := _cell_center(x,z)
			cells.append(Vector2i(x,z))
			var h := heights[i]
			sum += h
			sum2 += h*h
			lowest = minf(lowest,h)
			highest = maxf(highest,h)
			if wet[i] == 1:
				wet_cells += 1
				classes[0] += 1
				continue
			dry += 1
			canopy[i] = minf(canopy[i],1.0)
			if tree_near[i] == 0: open += 1
			var green := data.grass[data.meadow_cell(p)] if grass_ok else float(blend.cover(p))
			classes[1 if canopy[i] > 0.5 else 2 if shrub_near[i] == 1 else 3 if green > 0.4 else 4] += 1
	var n := cells.size()
	if n == 0:
		return {"total":0.0,"relief":0.0,"water":0.0,"edges":0.0,"openness":0.0,"variety":0.0,"framing":0.0,"cells":0}
	var mean := sum/n
	var spread := sqrt(maxf(sum2/n-mean*mean,0.0))
	var relief := 0.7*smoothstep(0.05,0.9,spread)+0.3*smoothstep(0.1,2.0,highest-lowest)
	# Water: presence, then the shore's shape on the pond raster.
	var share := float(wet_cells)/n
	var presence := 0.35 if wet_cells == 0 else smoothstep(0.0,0.08,share)*(1.0-0.6*smoothstep(0.4,0.8,share))
	var shape := shore_shape(blend,rect)
	var water := presence if wet_cells == 0 else 0.5*presence+0.5*float(shape.quality)
	# Edges: how straight the canopy's outline reads, and trees left alone.
	for i in range(outline.size()): outline[i] = minf(outline[i],1.0)
	var straight := straightness(outline,0.2,0.8,area,OUTLINE_WINDOW)
	var edge_sum := 0.0
	var edge_count := 0
	for c in cells:
		var v := outline[c.y*CELLS+c.x]
		if v > 0.2 and v < 0.8:
			edge_sum += straight[c.y*CELLS+c.x]
			edge_count += 1
	var trees := 0
	var lone := 0
	var shrubs := 0
	var cluttered := 0
	var sizes: Array = []
	for plant in known:
		var p := Vector2(plant.x,plant.y)
		if not rect.has_point(p): continue
		if plant.z > 0.5:
			trees += 1
			sizes.append(plant.w)
			var alone := true
			for other in _around(near,p,LONE_RADIUS):
				if other.z > 0.5 and other != plant and p.distance_to(Vector2(other.x,other.y)) < LONE_RADIUS:
					alone = false
					break
			if alone and _at(feature,p) < FEATURE_KEEP: lone += 1
		else:
			shrubs += 1
			var crowd := -1
			for other in _around(near,p,CLUTTER_RADIUS):
				if p.distance_to(Vector2(other.x,other.y)) < CLUTTER_RADIUS: crowd += 1
			if crowd > CLUTTER_MAX: cluttered += 1
	var edges := 0.7 if edge_count == 0 else 1.0-edge_sum/edge_count
	if trees > 0: edges = clampf(edges-0.6*float(lone)/trees,0.0,1.0)
	# Openness: open ground in a pleasing share, and no noisy clumps.
	var open_share := float(open)/maxi(dry,1)
	var openness := smoothstep(0.2,0.45,open_share)*(1.0-0.5*smoothstep(0.85,1.0,open_share))
	if shrubs > 0: openness *= 1.0-0.8*float(cluttered)/shrubs
	# Variety: the spread of water, canopy, undergrowth, grass and bare ground.
	var entropy := 0.0
	for count in classes:
		if count == 0: continue
		var f := float(count)/n
		entropy -= f*log(f)
	var variety := entropy/log(5.0)
	# Framing: water seen past what stands in front of it, and the biggest
	# trees on the spots they stand out from.
	var toward := toward_camera()
	var seen := 0
	for c in cells:
		if wet[c.y*CELLS+c.x] == 0: continue
		var p := _cell_center(c.x,c.y)
		var blocked := false
		var d := 0.5
		while d <= 3.5 and not blocked:
			var q := p+toward*d
			for plant in _around(near,q,0.9):
				if plant.z > 0.5 and q.distance_to(Vector2(plant.x,plant.y)) < 0.9:
					blocked = true
					break
			d += 0.5
		if not blocked: seen += 1
	var seen_share := 0.5 if wet_cells == 0 else float(seen)/wet_cells
	var placed := 0.5
	if sizes.size() >= 2:
		sizes.sort()
		var cut: float = sizes[sizes.size()/2]
		var big := 0
		var on := 0
		var featured := 0
		for c in cells:
			if feature[c.y*CELLS+c.x] >= FEATURE_KEEP: featured += 1
		for plant in known:
			if plant.z < 0.5 or plant.w < cut or not rect.has_point(Vector2(plant.x,plant.y)): continue
			big += 1
			if _at(feature,Vector2(plant.x,plant.y)) >= FEATURE_KEEP: on += 1
		placed = clampf(0.5+float(on)/maxi(big,1)-float(featured)/n,0.0,1.0)
	var framing := 0.6*seen_share+0.4*placed
	var terms := {"relief":relief,"water":water,"edges":edges,"openness":openness,"variety":variety,"framing":framing}
	var total := 0.0
	for key: String in WEIGHTS: total += float(WEIGHTS[key])*float(terms[key])
	terms["total"] = total
	terms["cells"] = n
	terms["trees"] = trees
	terms["lone"] = lone
	terms["shrubs"] = shrubs
	terms["cluttered"] = cluttered
	terms["open_share"] = open_share
	terms["water_share"] = share
	terms["water_seen"] = seen_share
	terms["thin_shore"] = shape.thin
	terms["edge_straight"] = edge_sum/edge_count if edge_count > 0 else 0.0
	return terms

static func _at(values: PackedFloat32Array, p: Vector2) -> float:
	return values[clampi(floori(p.y+14.0),0,CELLS-1)*CELLS+clampi(floori(p.x+14.0),0,CELLS-1)]

static func _around(near: Dictionary, p: Vector2, radius: float) -> Array:
	var found := []
	var reach := ceili(radius)
	var base := Vector2i(floori(p.x),floori(p.y))
	for dz in range(-reach,reach+1):
		for dx in range(-reach,reach+1):
			found.append_array(near.get(base+Vector2i(dx,dz),[]))
	return found

## The ponds' shore on the blend's 0.25 m pond raster, read at 0.5 m: thin
## water (a one-cell tongue) and thin land (a one-cell strip between waters)
## against the water's size. `quality` 1 is a clean shore.
static func shore_shape(blend: RefCounted, rect: Rect2) -> Dictionary:
	var raster: PackedByteArray = blend._sampler.get("_water") if blend._sampler != null and blend._sampler.get("_water") != null else PackedByteArray()
	if raster.is_empty(): return {"quality":1.0,"thin":0,"water":0}
	const SIDE := 112
	var low := Vector2i(clampi(floori((rect.position.x+14.0)*4.0),0,SIDE-1),clampi(floori((rect.position.y+14.0)*4.0),0,SIDE-1))
	var high := Vector2i(clampi(ceili((rect.end.x+14.0)*4.0),0,SIDE),clampi(ceili((rect.end.y+14.0)*4.0),0,SIDE))
	var water := 0
	var thin := 0
	for z in range(low.y,high.y,2):
		for x in range(low.x,high.x,2):
			var here: bool = raster[z*SIDE+x] == 1
			var left := x >= 2 and raster[z*SIDE+x-2] == 1
			var right := x < SIDE-2 and raster[z*SIDE+x+2] == 1
			var up := z >= 2 and raster[(z-2)*SIDE+x] == 1
			var down := z < SIDE-2 and raster[(z+2)*SIDE+x] == 1
			if here:
				water += 1
				if (not left and not right) or (not up and not down): thin += 1
			elif (left and right) or (up and down): thin += 1
	if water == 0: return {"quality":1.0,"thin":0,"water":0}
	return {"quality":1.0-clampf(THIN_WEIGHT*thin/water,0.0,1.0),"thin":thin,"water":water}

# --- Water nudges (pure data, on the water plan's worker) ---------------------

## A new pond's level: `level`, or up to LEVEL_TRIM lower when that trims a
## thin fringe of water enough to be worth the water given up. Never below
## `floor_level`. `h` is the water plan's grid, `side` its width.
static func pond_level(h: PackedFloat32Array, seed: int, level: float, floor_level: float, side: int) -> float:
	var full := _pond_shape(h,seed,level,side)
	if full.thin == 0 or full.volume <= 0.0: return level
	var best := level
	var best_score: float = full.quality
	for step in range(1,LEVEL_STEPS+1):
		var trial := level-LEVEL_TRIM*step/LEVEL_STEPS
		if trial <= floor_level: break
		var shape := _pond_shape(h,seed,trial,side)
		var value: float = float(shape.quality)-LEVEL_COST*(1.0-float(shape.volume)/float(full.volume))
		if value > best_score+LEVEL_MARGIN:
			best_score = value
			best = trial
	return best

## Flood `h` below `level` from `seed` (4-neighbour): cell count, the thin
## cells (water with no water either side along a row or column), quality
## as shore_shape's, and the volume held (in grid-cell metres).
static func _pond_shape(h: PackedFloat32Array, seed: int, level: float, side: int) -> Dictionary:
	var inside := {}
	if h[seed] >= level: return {"cells":0,"thin":0,"quality":1.0,"volume":0.0}
	var stack: Array[int] = [seed]
	inside[seed] = true
	var volume := 0.0
	while not stack.is_empty() and inside.size() < 3000:
		var k: int = stack.pop_back()
		volume += level-h[k]
		var i := k%side
		var j := k/side
		for next in [k-1 if i > 0 else -1,k+1 if i < side-1 else -1,k-side if j > 0 else -1,k+side if j < side-1 else -1]:
			if next < 0 or inside.has(next) or h[next] >= level: continue
			inside[next] = true
			stack.append(next)
	var thin := 0
	for k: int in inside:
		var i := k%side
		var horizontal := (i > 0 and inside.has(k-1)) or (i < side-1 and inside.has(k+1))
		var vertical := inside.has(k-side) or inside.has(k+side)
		if not horizontal or not vertical: thin += 1
	return {"cells":inside.size(),"thin":thin,"quality":1.0-clampf(THIN_WEIGHT*thin/maxf(inside.size(),1.0),0.0,1.0),"volume":volume}

## Where a hollow reads best among `candidates` (plate points, where the
## water came to rest first, with their ground `heights`): off thin land
## between it and other water (`water`, points ponds cover), near a third of
## the overview, close to where the water came to rest, low. `radius` is the
## hollow's. Returns an index into `candidates`.
static func site(candidates: PackedVector2Array, heights: PackedFloat32Array, water: PackedVector2Array, radius: float, tag: int) -> int:
	var third := thirds()
	var origin := candidates[0]
	var best := 0
	var best_score := -INF
	for n in range(candidates.size()):
		var p := candidates[n]
		var gap := INF
		for w in water: gap = minf(gap,p.distance_to(w))
		gap -= radius
		var sliver := 0.0 if gap <= 0.0 or gap == INF else 1.0-smoothstep(0.0,SLIVER_GAP,gap)
		var value := -sliver+0.15*_at(third,p)-0.1*p.distance_to(origin)-2.0*(heights[n]-heights[0])+Variety.unit([tag,n,61])*0.01
		if value > best_score:
			best_score = value
			best = n
	return best

## An oval for a hollow at `p`: long along the contour where the ground
## slopes (a pond lying along a hillside, not cupped into it), else at a
## hashed angle. `gradient` is the ground's slope there; `room` caps the long
## radius (the bowl deepens to hold its water). Returns {"stretch", "angle",
## "room"}.
static func oval(cell: int, gradient: Vector2, room: float) -> Dictionary:
	var stretch := lerpf(SCOOP_STRETCH.x,SCOOP_STRETCH.y,Variety.unit([cell,67]))
	var angle := Variety.unit([cell,71])*PI
	if gradient.length() > 0.03: angle = gradient.orthogonal().angle()
	return {"stretch":stretch,"angle":angle,"room":room}
