extends RefCounted
## What the land offers life, read from the live world (docs/scenic/life.md).
##
## A 56×56 grid at 0.5 m, aligned with the terrain's cover cells, holding the
## ground height, any still water (pond surfaces) or flowing water (stream
## beds) over it, and the trees and shrubs standing near it. From those it
## derives the places each creature looks for: deep water for fish, shallow
## still edges for frogspawn, dry banks for frogs and wading birds, forest
## edges for deer and damp undergrowth for fireflies.
##
## A survey never runs in one go. `step(budget)` does as many rows as fit in
## the budget and returns true once the whole grid is read, so a changed world
## is re-read across a handful of frames instead of in one hitch. Nothing here
## looks at the world every frame; LandLife starts a survey only when the
## editor reports that the land, water or plants changed.

const SIDE := 56
const STEP := 0.5
const HALF := 14.0
## Coarse 1 m grid for tree density sums.
const COARSE := 28
const TREES := ["tree","layered_tree","broadleaf","redwood","joshua","cactus"]
const SHRUBS := ["shrub","fern","reeds","bank_grass","grass_tuft","daisy_flower","button_flower","spike_flower","umbel_flower","mushroom"]
## Water depth a fish needs, and the depth band frogspawn and waders like.
const DEEP := 0.22
const SHALLOW_MIN := 0.02
const SHALLOW_MAX := 0.2
const WADE_MAX := 0.32
## A still-water body smaller than this (m²) is a puddle, not a pond.
const MIN_BODY_AREA := 1.5
## Forest edge: trees within FOREST_REACH metres (coarse cells), none on the spot.
const FOREST_REACH := 3
const FOREST_MIN := 3
## Damp undergrowth is within this many metres of water.
const DAMP_REACH := 3.0

var data: NativeTerrainData
var done := false
var height := PackedFloat32Array()
## Water surface over each cell, or -INF when dry.
var level := PackedFloat32Array()
## 1 where the water is a stream (flowing), 0 for still water or dry ground.
var flow := PackedByteArray()
## Still-water body id per cell, -1 elsewhere.
var body := PackedInt32Array()
## [{id, area, center, level, deep, shallow, shore, wade}] cell index lists.
var bodies: Array[Dictionary] = []
var slope := PackedFloat32Array()
## Metres to the nearest water, capped at DAMP_REACH+0.5.
var water_distance := PackedFloat32Array()
## Trees and shrubs per 1 m cell; tree positions for forest directions.
var tree_grid := PackedInt32Array()
var shrub_grid := PackedInt32Array()
var tree_count := 0
var shrub_count := 0
var stream_cells := 0
## Dry cells beside any water (still or flowing), for birds and frogs.
var shore := PackedInt32Array()
## [{cell, p, into}] open ground at a forest's edge; `into` points into the trees.
var forest_edges: Array[Dictionary] = []
var damp := PackedInt32Array()
## Microseconds the survey took in total, and the most it spent in one step.
var spent_usec := 0
var worst_step_usec := 0

## Pond triangles rasterised per step.
const TRIANGLES := 64
var _stage := 0
var _cursor := 0
var _surface := PackedVector3Array()
var _triangle := 0
var _objects: Array = []
var _streams: Array = []

## `water` is the pond surface the view drew (GardenView.pond_vertices):
## triangles in plate metres at the water's height. Reading it rather than
## flooding each pond again costs nothing and matches what the player sees.
func _init(terrain: NativeTerrainData, water: PackedVector3Array) -> void:
	data = terrain
	_surface = water
	var count := SIDE*SIDE
	height.resize(count)
	level.resize(count)
	level.fill(-INF)
	flow.resize(count)
	body.resize(count)
	body.fill(-1)
	slope.resize(count)
	water_distance.resize(count)
	tree_grid.resize(COARSE*COARSE)
	shrub_grid.resize(COARSE*COARSE)
	# Snapshot the records so an edit mid-survey cannot tear the read.
	_objects = data.objects.duplicate()
	_streams = data.streams.duplicate()

static func center(index: int) -> Vector2:
	return Vector2((index%SIDE)+0.5,(index/SIDE)+0.5)*STEP-Vector2(HALF,HALF)

static func cell_at(p: Vector2) -> int:
	var g := ((p+Vector2(HALF,HALF))/STEP).floor()
	if g.x < 0 or g.y < 0 or g.x >= SIDE or g.y >= SIDE: return -1
	return int(g.y)*SIDE+int(g.x)

func depth(index: int) -> float:
	return level[index]-height[index] if index >= 0 and level[index] > -INF and not is_nan(height[index]) else 0.0

## True when `p` is under water in this survey.
func wet_at(p: Vector2) -> bool:
	var index := cell_at(p)
	return index >= 0 and depth(index) > 0.01

## Surface level at `p`, or -INF.
func level_at(p: Vector2) -> float:
	var index := cell_at(p)
	return level[index] if index >= 0 else -INF

## Ground height at `p` from the grid (bilinear-free, cell value).
func ground_at(p: Vector2) -> float:
	var index := cell_at(p)
	return height[index] if index >= 0 else NAN

## Nearest cell of body `id` within `reach` metres of `p` whose water is at
## most `deepest` deep, or -1.
func water_near(p: Vector2, id: int, reach: float, deepest: float) -> int:
	var best := -1
	var best_distance := INF
	var home := cell_at(p)
	if home < 0: return -1
	var span := ceili(reach/STEP)
	for dz in range(-span,span+1):
		for dx in range(-span,span+1):
			var x := home%SIDE+dx
			var z := home/SIDE+dz
			if x < 0 or z < 0 or x >= SIDE or z >= SIDE: continue
			var index := z*SIDE+x
			if body[index] != id or depth(index) > deepest: continue
			var distance := center(index).distance_squared_to(p)
			if distance < best_distance and distance <= reach*reach:
				best = index
				best_distance = distance
	return best

## Read more of the world. True once the survey is complete.
func step(budget_usec: int) -> bool:
	if done: return true
	var began := Time.get_ticks_usec()
	while not done and Time.get_ticks_usec()-began < budget_usec:
		_advance()
	var used := Time.get_ticks_usec()-began
	spent_usec += used
	worst_step_usec = maxi(worst_step_usec,used)
	return done

func _advance() -> void:
	match _stage:
		0:
			_bucket_objects()
			_stage = 1
			_cursor = 0
		1:
			# Heights, one row at a time.
			var row := _cursor
			for x in range(SIDE):
				var h: Variant = data.ground_height(center(row*SIDE+x))
				height[row*SIDE+x] = float(h) if h != null else NAN
			_cursor += 1
			if _cursor >= SIDE:
				_stage = 2
				_cursor = 0
		2:
			# Still water, a slice of the view's pond triangles at a time.
			_triangle = _rasterise(_triangle,TRIANGLES)
			if _triangle*3 >= _surface.size()-2:
				_stage = 3
				_cursor = 0
		3:
			if _cursor < _streams.size(): _mark_stream(_streams[_cursor])
			_cursor += 1
			if _cursor >= _streams.size():
				_stage = 4
				_cursor = 0
		4:
			_slopes_row(_cursor)
			_cursor += 1
			if _cursor >= SIDE:
				_stage = 5
		5:
			_find_bodies()
			_stage = 6
		6:
			_water_distances()
			_stage = 7
			_cursor = 0
		7:
			_places_row(_cursor)
			_cursor += 1
			if _cursor >= SIDE:
				done = true

func _bucket_objects() -> void:
	for item: Dictionary in _objects:
		var asset := str(item.get("asset",""))
		var tree := asset in TREES
		if not tree and asset not in SHRUBS: continue
		var g := Vector2i(clampi(floori(float(item.x)+HALF),0,COARSE-1),clampi(floori(float(item.z)+HALF),0,COARSE-1))
		if tree:
			tree_grid[g.y*COARSE+g.x] += 1
			tree_count += 1
		else:
			shrub_grid[g.y*COARSE+g.x] += 1
			shrub_count += 1

## Mark cells under pond triangles [first, first+count); returns the next.
## A triangle's water stands at its vertices' height.
func _rasterise(first: int, count: int) -> int:
	var surface := _surface
	var last := mini(first+count,surface.size()/3)
	for n in range(first,last):
		var t := n*3
		var a := Vector2(surface[t].x,surface[t].z)
		var b := Vector2(surface[t+1].x,surface[t+1].z)
		var c := Vector2(surface[t+2].x,surface[t+2].z)
		var water := (surface[t].y+surface[t+1].y+surface[t+2].y)/3.0
		var lo := ((a.min(b).min(c)+Vector2(HALF,HALF))/STEP-Vector2(0.5,0.5)).floor()
		var hi := ((a.max(b).max(c)+Vector2(HALF,HALF))/STEP-Vector2(0.5,0.5)).ceil()
		for z in range(clampi(int(lo.y),0,SIDE),clampi(int(hi.y)+1,0,SIDE)):
			for x in range(clampi(int(lo.x),0,SIDE),clampi(int(hi.x)+1,0,SIDE)):
				var index := z*SIDE+x
				if level[index] >= water: continue
				if Geometry2D.point_is_inside_triangle(center(index),a,b,c): level[index] = water
	return last

func _mark_stream(route: Dictionary) -> void:
	var reach := float(route.get("width",0.6))*0.5+0.1
	for point in route.get("pts",[]):
		var p := Vector2(float(point.x),float(point.z))
		var lo := ((p-Vector2.ONE*reach+Vector2(HALF,HALF))/STEP).floor()
		var hi := ((p+Vector2.ONE*reach+Vector2(HALF,HALF))/STEP).ceil()
		for z in range(clampi(int(lo.y),0,SIDE),clampi(int(hi.y),0,SIDE)):
			for x in range(clampi(int(lo.x),0,SIDE),clampi(int(hi.x),0,SIDE)):
				var index := z*SIDE+x
				if level[index] > -INF or is_nan(height[index]): continue
				if center(index).distance_squared_to(p) > reach*reach: continue
				level[index] = height[index]+0.06
				flow[index] = 1
				stream_cells += 1

func _slopes_row(z: int) -> void:
	for x in range(SIDE):
		var index := z*SIDE+x
		var l := height[z*SIDE+maxi(x-1,0)]
		var r := height[z*SIDE+mini(x+1,SIDE-1)]
		var d := height[maxi(z-1,0)*SIDE+x]
		var u := height[mini(z+1,SIDE-1)*SIDE+x]
		if is_nan(l) or is_nan(r) or is_nan(d) or is_nan(u) or is_nan(height[index]):
			slope[index] = INF
			continue
		slope[index] = Vector2(r-l,u-d).length()/(STEP*2.0)

## Connected still water, 4-neighbour, with its deep, shallow-edge, wading and
## shore cells.
func _find_bodies() -> void:
	for start in range(SIDE*SIDE):
		if body[start] >= 0 or flow[start] == 1 or depth(start) <= 0.01: continue
		var id := bodies.size()
		var record := {"id":id,"cells":PackedInt32Array(),"deep":PackedInt32Array(),"shallow":PackedInt32Array(),"wade":PackedInt32Array(),"shore":PackedInt32Array(),"level":level[start],"center":Vector2.ZERO,"area":0.0}
		var queue := PackedInt32Array([start])
		body[start] = id
		var head := 0
		var sum := Vector2.ZERO
		var shores := {}
		while head < queue.size():
			var index := queue[head]
			head += 1
			record.cells.append(index)
			sum += center(index)
			var x := index%SIDE
			var z := index/SIDE
			var edge := false
			for offset: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var nx := x+offset.x
				var nz := z+offset.y
				if nx < 0 or nz < 0 or nx >= SIDE or nz >= SIDE:
					edge = true
					continue
				var next := nz*SIDE+nx
				if depth(next) > 0.01 and flow[next] == 0:
					if body[next] < 0:
						body[next] = id
						queue.append(next)
				elif not is_nan(height[next]):
					edge = true
					if slope[next] < 0.9: shores[next] = true
			var d := depth(index)
			if d >= DEEP and not edge: record.deep.append(index)
			if edge and d >= SHALLOW_MIN and d <= SHALLOW_MAX: record.shallow.append(index)
			if d >= 0.05 and d <= WADE_MAX: record.wade.append(index)
		record.area = record.cells.size()*STEP*STEP
		record.center = sum/maxf(record.cells.size(),1.0)
		record.shore = PackedInt32Array(shores.keys())
		if record.area < MIN_BODY_AREA:
			# A puddle: not a pond, but still wet ground for the damp search.
			record.deep.clear()
			record.shallow.clear()
			record.wade.clear()
		bodies.append(record)

## Breadth-first metres to water, capped just past DAMP_REACH.
func _water_distances() -> void:
	water_distance.fill(DAMP_REACH+0.5)
	var queue := PackedInt32Array()
	for index in range(SIDE*SIDE):
		if depth(index) > 0.01:
			water_distance[index] = 0.0
			queue.append(index)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var reach := water_distance[index]+STEP
		if reach > DAMP_REACH: continue
		var x := index%SIDE
		var z := index/SIDE
		for offset: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var nx := x+offset.x
			var nz := z+offset.y
			if nx < 0 or nz < 0 or nx >= SIDE or nz >= SIDE: continue
			var next := nz*SIDE+nx
			if water_distance[next] > reach:
				water_distance[next] = reach
				queue.append(next)

## Shore, forest edge and damp undergrowth for one row of dry ground.
func _places_row(z: int) -> void:
	for x in range(SIDE):
		var index := z*SIDE+x
		if is_nan(height[index]) or depth(index) > 0.01 or slope[index] > 0.9: continue
		var p := center(index)
		if water_distance[index] <= STEP+0.01 and slope[index] < 0.6: shore.append(index)
		var cover := data.grass[index] if index < data.grass.size() else 0.0
		var g := Vector2i(clampi(int(p.x+HALF),0,COARSE-1),clampi(int(p.y+HALF),0,COARSE-1))
		var near := 0
		var shrubs := 0
		var close := 0
		var into := Vector2.ZERO
		var on_spot := tree_grid[g.y*COARSE+g.x]
		for dz in range(-FOREST_REACH,FOREST_REACH+1):
			for dx in range(-FOREST_REACH,FOREST_REACH+1):
				var cx := g.x+dx
				var cz := g.y+dz
				if cx < 0 or cz < 0 or cx >= COARSE or cz >= COARSE: continue
				var trees := tree_grid[cz*COARSE+cx]
				if absi(dx) <= 1 and absi(dz) <= 1:
					shrubs += shrub_grid[cz*COARSE+cx]
					close += tree_grid[cz*COARSE+cx]
				if trees == 0: continue
				near += trees
				into += Vector2(dx,dz)*trees
		if water_distance[index] <= DAMP_REACH and (cover >= 0.35 or shrubs > 0 or near > 0):
			damp.append(index)
		if on_spot == 0 and close > 0 and near >= FOREST_MIN and slope[index] < 0.4 and cover >= 0.2 and into.length() > 0.5:
			forest_edges.append({"cell":index,"p":p,"into":into.normalized(),"trees":near})

## Richness of the whole place, 0 and up: water, shores, trees and shrubs.
func richness() -> float:
	var water := 0.0
	for record in bodies: water += record.area
	return minf(water/12.0,1.5)+minf(stream_cells/30.0,0.6)+minf(tree_count/12.0,1.5)+minf(shrub_count/30.0,0.8)
