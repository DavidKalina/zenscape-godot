extends "res://scripts/creation_brush.gd"
## The water brush (docs/scenic/water-brush.md). Dragging pours water, and it
## settles as it pours, with gentle physics:
## - each dab's water runs down the land to the low ground it drains to;
## - a basin fills from its lowest point with the water poured into it, on top
##   of any pond already there, up to its spill level;
## - water past the spill level overflows the lowest saddle and runs on down
##   as a stream to the next basin, or off the edge of the diorama; basins
##   that overflow into each other become one lake;
## - water poured well above where it pools runs down to it as a stream.
## Shift or a right drag drains instead: ponds and streams under the brush go.
##
## `plan` is pure data on a detached height copy, so the editor runs it on a
## worker and the release frame only records the dabs. The result carries a
## delay per pond and stream, so a stream reaches its pond before the pond
## fills, and an overflow leaves only once its pond is nearly full.
## It is a creation brush (scripts/creation_brush.gd) that settles: dabs only
## record, and the editor plans them again every few tenths of a second while
## the button is down, showing the latest plan, and once more at release
## (NativeChunkEditor `_pour_live`).

## The planning grid: 0.5 m cells over the 28 m plate.
const GRID := 0.5
const SIDE := 57
const ORIGIN := -14.0
## Cubic metres poured per second at strength 1 with a brush of REFERENCE_RADIUS.
const RATE := 2.4
const REFERENCE_RADIUS := 3.0
## A pond sits this far under its spill level, so the terrain keeps a bank.
const SPILL_MARGIN := 0.04
## Water shallower than this soaks in rather than making a pond.
const MIN_DEPTH := 0.06
## Water poured this far above its pond, and this far from its shore, runs
## down to it as a stream.
const STREAM_DROP := 0.3
const STREAM_REACH := 1.5
const MAX_STREAMS := 6
const MAX_PONDS := 6
## Lost water (off the edge, or too thin for a pond) scoops a soft hollow to
## pool in: at least SCOOP_MIN m³, radius and depth within these metres, kept
## SCOOP_RIM metres inside the plate's rim, at most MAX_SCOOPS per stroke.
const SCOOP_MIN := 0.5
const SCOOP_RADIUS := Vector2(1.8,4.5)
const SCOOP_DEPTH := Vector2(0.15,0.9)
const SCOOP_RIM := 1.5
const MAX_SCOOPS := 2
## Stream cross-section (native_stream_geometry.gd): the water surface sits
## STREAM_LIFT over its bed; width grows with the water that runs down it.
const STREAM_DEPTH := 0.12
const STREAM_SURFACE := 0.08
const STREAM_LIFT := 0.06
const STREAM_WIDTH := Vector2(0.32,0.85)
## The animation, on the emergence clock: stream fronts run at FLOW_SPEED m/s,
## a pond rises over FILL_SECONDS (shaders/reference_water_body.gdshaderinc
## reads it as `pond_fill_seconds`), and an overflow leaves at OVERFLOW_AT of
## its pond's fill.
const FLOW_SPEED := 2.4
const FILL_SECONDS := 3.2
const OVERFLOW_AT := 0.8
const START_DELAY := 0.1
## Nearby dabs merge into one, so a long stroke stays a short list.
const MERGE := 0.35
## A new stream carves a shallow bed: a (1 - t²)² trough BED_DEPTH deep at its
## centre and BED_HALF_WIDTH (at least) to either side, and its water drops
## BED_SINK of what was carved under it, so it runs in the bed, not on the
## grass. Ground at or above a nearby pond's level is never cut below it, so a
## bed cannot open a pond's bank.
const BED_DEPTH := 0.14
const BED_HALF_WIDTH := 0.9
const BED_SINK := 0.75
const BED_GUARD := 0.03
## Water poured into a pond already brimming at the plate's rim raises a soft
## lip there instead of pouring off the edge: rim ground within LIP_WIDTH of
## the edge, beside the pond, rises so the pond can rise up to LIP_RISE per
## pour (LIP_PASSES settles, as the rising pond reaches more of the rim). A
## lip that raises no pond is dropped. What the lip can't hold scoops a hollow
## as other lost water does.
const LIP_WIDTH := 2.2
const LIP_RISE := 0.5
const LIP_FREEBOARD := 0.1
const LIP_PASSES := 3

const Guidance = preload("res://scripts/quiet_guidance.gd")

## x, z and volume (m³) of each dab; negative volume drains.
var dabs := PackedVector3Array()
var last_plan_usec := 0

func _init() -> void:
	brush_id = "water"
	settles = true
	radius = 3.0
	radius_range = Vector2(1.0,8.0)

## The plan runs on its own grid, not the per-vertex buckets.
func prepare(_data: NativeTerrainData, _world_seed: int) -> void:
	pass

func begin() -> void:
	super.begin()
	dabs = PackedVector3Array()

## One dab. `amount` is seconds of brushing times strength; `drain` removes
## water. Only records: the editor's next plan of the pour takes it up.
func dab(_data: NativeTerrainData, center: Vector2, radius: float, amount: float, drain: bool) -> void:
	if radius <= 0.0 or amount <= 0.0: return
	_grow_bounds(center,radius)
	var volume := amount*RATE*pow(radius/REFERENCE_RADIUS,2.0)
	if drain: volume = -maxf(radius,0.5)
	if not dabs.is_empty():
		var last := dabs[-1]
		if Vector2(last.x,last.y).distance_to(center) < radius*MERGE and (last.z < 0.0) == drain:
			dabs[-1] = Vector3(last.x,last.y,minf(last.z,volume) if drain else last.z+volume)
			return
	dabs.append(Vector3(center.x,center.y,volume))

# --- Planning (pure data, runs on a worker) -----------------------------------

class Heap:
	var h := PackedFloat32Array()
	var k := PackedInt32Array()
	func push(height: float, key: int) -> void:
		h.append(height)
		k.append(key)
		var i := h.size()-1
		while i > 0:
			var parent := (i-1)/2
			if h[parent] <= h[i]: break
			_swap(i,parent)
			i = parent
	func pop() -> int:
		var top := k[0]
		var last := h.size()-1
		_swap(0,last)
		h.resize(last)
		k.resize(last)
		var i := 0
		while true:
			var left := i*2+1
			var right := left+1
			var low := i
			if left < last and h[left] < h[low]: low = left
			if right < last and h[right] < h[low]: low = right
			if low == i: break
			_swap(i,low)
			i = low
		return top
	func empty() -> bool:
		return h.is_empty()
	func _swap(a: int, b: int) -> void:
		var th := h[a]
		h[a] = h[b]
		h[b] = th
		var tk := k[a]
		k[a] = k[b]
		k[b] = tk

static func cell_of(point: Vector2) -> int:
	var i := clampi(roundi((point.x-ORIGIN)/GRID),0,SIDE-1)
	var j := clampi(roundi((point.y-ORIGIN)/GRID),0,SIDE-1)
	return j*SIDE+i

static func position_of(k: int) -> Vector2:
	return Vector2(ORIGIN+(k%SIDE)*GRID,ORIGIN+(k/SIDE)*GRID)

static func _border(k: int) -> bool:
	var i := k%SIDE
	var j := k/SIDE
	return i == 0 or j == 0 or i == SIDE-1 or j == SIDE-1

## Settle a stroke's dabs on `data`, a detached height copy the plan may
## reshape. `ponds` and `streams` are the world's water before the stroke.
## `validate` floods each new pond on the terrain mesh, as the renderer will,
## and lowers it until it holds.
##
## Water that would be lost - run off the plate's edge, or spread too thin to
## make a pond - scoops a soft hollow where it last came to rest (the lowest
## point on its way down, clear of the edge) sized to hold it, and the water
## settles again. So a pour on open ground always leaves a pond, and water
## poured on a hilltop runs down and pools at its foot.
##
## Returns the world's ponds and streams after the stroke, the new records
## with their delays and rises, the heights when a hollow was scooped, and the
## plate rect that changed.
static func plan(data: NativeTerrainData, ponds: Array, streams: Array, dabs_in: PackedVector3Array, validate: bool) -> Dictionary:
	var began := Time.get_ticks_usec()
	var grid := _grid(data)
	var result := _settle(data,grid,ponds,streams,dabs_in,validate)
	# A pond brimming at the rim raises a lip there and settles again. As it
	# rises it may reach the rim further along, so the lip grows a few times,
	# never past LIP_RISE over where the pond first brimmed.
	var lips := 0
	var cap := -INF
	for rim: Dictionary in result.rims: cap = maxf(cap,float(rim.level)+LIP_RISE)
	var unlipped := {"result":result,"heights":data.heights.duplicate(),"h":grid.h.duplicate()}
	for lip_pass in range(LIP_PASSES):
		if result.rims.is_empty(): break
		# Ponds keep their water, not their level: the lip lets them rise.
		if not grid.has("before"): grid["before"] = grid.h.duplicate()
		var heights := data.heights
		var rect := Rect2()
		var raised := false
		for rim: Dictionary in result.rims:
			var touched := _lip(data,heights,grid,rim,cap)
			if touched.has_area():
				rect = _grow(rect,raised,touched)
				raised = true
		if not raised: break
		lips += 1
		data.heights = heights
		var before_rect: Rect2 = result.rect
		var before_changed: bool = result.changed
		result = _settle(data,grid,ponds,streams,dabs_in,validate)
		rect = _grow(before_rect,before_changed,rect)
		result.rect = result.rect.merge(rect) if result.changed else rect
		result.changed = true
		result["heights"] = data.heights
	# A lip that raised no pond is only a bank; leave the rim as it was.
	if lips > 0 and result.added.is_empty():
		lips = 0
		result = unlipped.result
		data.heights = unlipped.heights
		grid.h = unlipped.h
		grid.erase("before")
	var sites := _scoop_sites(grid,result.lost,result.ponds)
	if not sites.is_empty():
		# Ponds keep their water, not their level: the hollow may deepen them.
		if not grid.has("before"): grid["before"] = grid.h.duplicate()
		var heights := data.heights
		for site: Dictionary in sites:
			var rect := _scoop(data,heights,grid,site)
			result.rect = _grow(result.rect,result.changed,rect)
			result.changed = true
		data.heights = heights
		var rect: Rect2 = result.rect
		result = _settle(data,grid,ponds,streams,dabs_in,validate)
		result.rect = result.rect.merge(rect) if result.changed else rect
		result.changed = true
		result["heights"] = data.heights
	var carved := _carve_beds(data,grid,result,validate)
	if carved.has_area():
		result.rect = result.rect.merge(carved) if result.changed else carved
		result.changed = true
		result["heights"] = data.heights
	result.erase("lost")
	result.erase("rims")
	result["scoops"] = sites.size()
	# What quiet guidance changed, for probes: levels trimmed (m) and hollows
	# moved (m) or shaped into ovals.
	result["guided"] = {"trims":result.get("trims",[]),"moved":sites.map(func(site: Dictionary) -> float: return snappedf(float(site.get("moved",0.0)),0.01)),"ovals":sites.filter(func(site: Dictionary) -> bool: return float(site.get("stretch",1.0)) > 1.0).size()}
	result.erase("trims")
	result["lips"] = lips
	result["beds"] = carved.has_area()
	result["usec"] = Time.get_ticks_usec()-began
	return result

## Ground heights on the planning grid. Void and the plate's rim drain.
static func _grid(data: NativeTerrainData) -> Dictionary:
	var h := PackedFloat32Array()
	h.resize(SIDE*SIDE)
	var drain_cell := PackedByteArray()
	drain_cell.resize(SIDE*SIDE)
	for k in range(SIDE*SIDE):
		var value: Variant = data.ground_height(position_of(k))
		if value == null:
			drain_cell[k] = 1
			h[k] = -1000.0
		else:
			h[k] = float(value)
		if _border(k): drain_cell[k] = 1
	return {"h":h,"drain":drain_cell}

static func _settle(data: NativeTerrainData, grid: Dictionary, ponds: Array, streams: Array, dabs_in: PackedVector3Array, validate: bool) -> Dictionary:
	var area := GRID*GRID
	var h: PackedFloat32Array = grid.h
	var drain_cell: PackedByteArray = grid.drain
	# Existing ponds on the grid: each floods from its seed below its level.
	var owner := PackedInt32Array()
	owner.resize(SIDE*SIDE)
	owner.fill(-1)
	var bottoms := PackedInt32Array()
	var pond_water := PackedFloat32Array()
	var before: PackedFloat32Array = grid.get("before",h)
	for index in range(ponds.size()):
		var pond: Dictionary = ponds[index]
		var seed := cell_of(Vector2(pond.x,pond.z))
		var lowest := seed
		var water := 0.0
		for cell: int in _flood_below(before,seed,float(pond.level),owner,index):
			if h[cell] < h[lowest]: lowest = cell
			water += (float(pond.level)-before[cell])*area
		bottoms.append(lowest)
		pond_water.append(water)
	# Where every cell's water ends up: steepest descent to a local low, or -1
	# where it runs off the edge.
	var sink := PackedInt32Array()
	sink.resize(SIDE*SIDE)
	sink.fill(-2)
	for k in range(SIDE*SIDE):
		if drain_cell[k]: sink[k] = -1
	for k in range(SIDE*SIDE): _descend(h,drain_cell,sink,k)
	# Drain dabs first: a pond or stream under one goes.
	var removed := {}
	var kept_streams: Array = streams.duplicate(true)
	var poured := {}
	var sources := {}
	var lost: Array = []
	var rims: Array = []
	var changed := Rect2()
	var any_change := false
	for d in dabs_in:
		var point := Vector2(d.x,d.y)
		if d.z < 0.0:
			var reach := -d.z
			for k in range(SIDE*SIDE):
				if owner[k] >= 0 and not removed.has(owner[k]) and position_of(k).distance_to(point) < reach:
					removed[owner[k]] = true
			for s in range(kept_streams.size()-1,-1,-1):
				for p: Dictionary in kept_streams[s].pts:
					if Vector2(p.x,p.z).distance_to(point) < reach:
						changed = _grow(changed,any_change,_stream_rect(kept_streams[s]))
						any_change = true
						kept_streams.remove_at(s)
						break
			continue
		var start := cell_of(point)
		var target: int = sink[start]
		if target < 0:
			lost.append({"volume":d.z,"start":start})
			continue
		poured[target] = float(poured.get(target,0.0))+d.z
		# The highest dab over each sink is where its stream starts.
		if not sources.has(target) or h[start] > h[sources[target]]: sources[target] = start
	var kept_ponds: Array = []
	var bottom_of := {}
	for index in range(ponds.size()):
		if removed.has(index):
			var pond: Dictionary = ponds[index]
			changed = _grow(changed,any_change,Rect2(Vector2(pond.x,pond.z)-Vector2.ONE*3.0,Vector2.ONE*6.0))
			any_change = true
			continue
		kept_ponds.append(ponds[index])
		if grid.has("before"):
			# Reshaped ground: the pond's water pours in again from its bottom.
			var bottom: int = sink[bottoms[index]]
			if bottom >= 0: poured[bottom] = float(poured.get(bottom,0.0))+pond_water[index]
		else:
			bottom_of[bottoms[index]] = ponds[index]
	# Fill basins, upstream first; overflow feeds the basin below it.
	var group := {}
	for s: int in poured: group[s] = s
	var inflow := {}
	var results := {}
	var pending: Array = poured.keys()
	pending.sort_custom(func(a: int, b: int) -> bool: return h[a] > h[b])
	var rounds := 0
	while not pending.is_empty() and rounds < 48:
		rounds += 1
		var root: int = _find(group,pending.pop_front())
		var members: Array = []
		for s: int in group:
			if _find(group,s) == root: members.append(s)
		var volume := 0.0
		var start_level := -INF
		for s: int in members:
			volume += float(poured.get(s,0.0))
			for from: int in inflow.get(s,{}):
				if not members.has(from) and _find(group,from) != root: volume += float(inflow[s][from])
			if bottom_of.has(s): start_level = maxf(start_level,float(bottom_of[s].level))
		var result := _fill(h,drain_cell,sink,members,volume,start_level,area)
		result["volume"] = volume
		results[root] = result
		var spill: int = result.spill
		if spill < 0 or result.edge or result.remaining <= 0.0: continue
		var below: int = sink[spill]
		if below < 0: continue
		var downstream: int = _find(group,below) if group.has(below) else below
		if downstream == root: continue
		# Two basins spilling into each other are one lake above the saddle.
		var back: Dictionary = results.get(downstream,{})
		var loops := false
		if not back.is_empty() and back.spill >= 0 and not back.edge:
			var return_sink: int = sink[back.spill]
			loops = return_sink >= 0 and _find(group,return_sink) == root
		if loops:
			group[downstream] = root
			results.erase(downstream)
			pending.push_front(root)
			continue
		if not group.has(below):
			group[below] = below
		if not inflow.has(below): inflow[below] = {}
		inflow[below][root] = result.remaining
		if not pending.has(downstream): pending.append(downstream)
	# Records: a pond per filled basin, streams for runs and overflows.
	var added: Array = []
	var new_streams: Array = []
	var roots: Array = results.keys()
	roots.sort_custom(func(a: int, b: int) -> bool: return h[a] > h[b])
	var ponds_out: Array = kept_ponds.duplicate(true)
	var surfaces := {}
	var trims: Array = []
	for root: int in roots:
		var result: Dictionary = results[root]
		var region: PackedInt32Array = result.region
		if region.is_empty(): continue
		var deepest: int = region[0]
		for k in region:
			if h[k] < h[deepest]: deepest = k
		result["deepest"] = deepest
		# Water leaving the plate is lost to it.
		var off_edge: bool = result.spill >= 0 and result.remaining > 0.0 and (result.edge or sink[result.spill] < 0)
		# A pond already there, brimming at the rim itself, raises a lip there
		# (`_lip`) so more water raises it. New water lost off the edge still
		# scoops a hollow.
		var holds_pond := false
		for k in region:
			if owner[k] >= 0 and not removed.has(owner[k]):
				holds_pond = true
				break
		if off_edge and result.edge and holds_pond and _rim_distance(result.spill) <= 1.5:
			rims.append({"region":region,"level":float(result.level),"volume":float(result.remaining),"spill":int(result.spill)})
		if off_edge: lost.append({"volume":result.remaining,"start":deepest})
		var held: float = float(result.volume)-(float(result.remaining) if result.spill >= 0 else 0.0)
		var level: float = result.level-(SPILL_MARGIN if result.spill >= 0 else 0.0)
		var previous := -INF
		for k in region:
			if owner[k] >= 0 and not removed.has(owner[k]): previous = maxf(previous,float(ponds[owner[k]].level))
		if level <= previous+0.005: continue
		if level-h[deepest] < MIN_DEPTH or added.size() >= MAX_PONDS:
			lost.append({"volume":held,"start":deepest})
			continue
		# Quiet guidance: a few centimetres lower when that trims a thin
		# fringe of water; what it gives up soaks in.
		if Guidance.enabled and Guidance.water_enabled:
			var trimmed := Guidance.pond_level(h,deepest,level,maxf(previous+0.006,h[deepest]+MIN_DEPTH),SIDE)
			if trimmed < level: trims.append(snappedf(level-trimmed,0.001))
			level = trimmed
		var seed := position_of(deepest)
		var record := {"x":seed.x,"z":seed.y,"level":level}
		if validate:
			var surface := PackedVector3Array()
			for attempt in range(5):
				surface = NativeGardenWater.surface(data,record)
				if not surface.is_empty(): break
				record.level = float(record.level)-0.03
			if surface.is_empty() or float(record.level)-h[deepest] < MIN_DEPTH:
				lost.append({"volume":held,"start":deepest})
				continue
			if float(record.level) <= previous+0.005: continue
			surfaces[root] = surface
		# The new lake replaces every pond it now covers.
		for i in range(ponds_out.size()-1,-1,-1):
			if region.has(cell_of(Vector2(ponds_out[i].x,ponds_out[i].z))): ponds_out.remove_at(i)
		ponds_out.append(record)
		var drop: float = float(record.level)-(previous if previous > -INF else h[deepest])
		var bounds_rect := Rect2(position_of(region[0]),Vector2.ZERO)
		for k in region: bounds_rect = bounds_rect.expand(position_of(k))
		# `cells` are the flooded planning cells; emergence withdraws the
		# plants they drown (emergence.gd `drown`).
		added.append({"record":record,"root":root,"drop":drop,"rect":bounds_rect,"cells":region})
		changed = _grow(changed,any_change,bounds_rect.grow(1.0))
		any_change = true
	# Streams from high dabs down to their pond, then overflows in order.
	var pond_of := {}
	for entry: Dictionary in added: pond_of[entry.root] = entry
	for target: int in sources:
		var root: int = _find(group,target) if group.has(target) else target
		var entry: Dictionary = pond_of.get(root,{})
		var start: int = sources[target]
		var level: float = float(entry.record.level) if not entry.is_empty() else maxf(h[target],float(results.get(root,{}).get("level",h[target])))
		if h[start]-level < STREAM_DROP: continue
		var path := _path_down(h,start,results.get(root,{}).get("region",PackedInt32Array()))
		if path.size() < 2 or position_of(path[0]).distance_to(position_of(path[-1])) < STREAM_REACH: continue
		var volume: float = float(poured.get(target,0.0))
		new_streams.append({"path":path,"volume":volume,"into":root,"from":-1,"level":level})
	for root: int in roots:
		var result: Dictionary = results[root]
		# A lake brimming at the rim just spills over it; no stream to draw.
		if result.spill < 0 or result.remaining <= 0.0 or result.edge: continue
		var below: int = sink[result.spill]
		var into: int = (_find(group,below) if group.has(below) else below) if below >= 0 else -1
		var into_region: PackedInt32Array = results.get(into,{}).get("region",PackedInt32Array())
		var path := _path_down(h,result.spill,into_region)
		if path.size() < 2 or _path_length(path) < STREAM_REACH*0.5: continue
		var entry: Dictionary = pond_of.get(into,{})
		var end_level: float = float(entry.record.level) if not entry.is_empty() else maxf(h[path[-1]],float(results.get(into,{}).get("level",h[path[-1]])))
		var from_entry: Dictionary = pond_of.get(root,{})
		var from_level: float = float(from_entry.record.level) if not from_entry.is_empty() else float(result.level)-SPILL_MARGIN
		new_streams.append({"path":path,"volume":float(result.remaining),"into":into,"from":root,"level":end_level,"from_level":from_level})
	new_streams.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.volume > b.volume)
	new_streams.resize(mini(new_streams.size(),MAX_STREAMS))
	# Timing: a pond fills once its streams arrive; overflows leave near full.
	var stream_records: Array = []
	var ready := {}
	for entry: Dictionary in added: ready[entry.root] = START_DELAY
	for pass_index in range(3):
		for stream: Dictionary in new_streams:
			var leave := START_DELAY if stream.from < 0 else float(ready.get(stream.from,START_DELAY))+FILL_SECONDS*OVERFLOW_AT
			stream["delay"] = leave
			stream["seconds"] = maxf(0.6,_path_length(stream.path)/FLOW_SPEED)
			if stream.into >= 0 and pond_of.has(stream.into):
				ready[stream.into] = maxf(float(ready[stream.into]),leave+stream.seconds*0.85)
	for stream: Dictionary in new_streams:
		var water: PackedVector3Array = surfaces.get(stream.into,PackedVector3Array())
		var record := _stream_record(data,stream,water)
		if record.is_empty(): continue
		stream_records.append({"record":record,"delay":stream.delay,"seconds":stream.seconds,"from_level":float(stream.get("from_level",-INF))})
		changed = _grow(changed,any_change,_stream_rect(record).grow(1.0))
		any_change = true
	var streams_out: Array = kept_streams
	for entry: Dictionary in stream_records:
		if streams_out.size() >= 128: break
		streams_out.append(entry.record)
	for entry: Dictionary in added:
		entry["delay"] = float(ready.get(entry.root,START_DELAY))
		entry.erase("root")
	return {"ponds":ponds_out,"streams":streams_out,"added":added,"added_streams":stream_records,
		"rect":changed if any_change else Rect2(),"changed":any_change,"lost":lost,"rims":rims,"trims":trims}

## Where lost water comes to rest: down its steepest path from where it last
## stood, the lowest point far enough from the rim to hold a hollow. Nearby
## losses share one hollow; the largest few are kept. With quiet guidance a
## hollow may sit a little way off, clear of thin land between it and the
## `ponds`, and takes an oval along the contour (`_guide_sites`).
static func _scoop_sites(grid: Dictionary, lost: Array, ponds: Array = []) -> Array:
	var h: PackedFloat32Array = grid.h
	var sites: Array = []
	for chunk: Dictionary in lost:
		var volume: float = chunk.volume
		if volume <= 0.0: continue
		var reach := _scoop_radius(volume)+SCOOP_RIM
		var best := -1
		var at: int = chunk.start
		for step in range(SIDE*3):
			if _rim_distance(at) >= reach and (best < 0 or h[at] < h[best]): best = at
			var next := _lowest_neighbor(h,at)
			if next == at: break
			at = next
		if best < 0:
			# Too near the rim all the way down: step in toward the middle.
			var p := position_of(chunk.start)
			var limit := 14.0-reach
			if limit <= 0.0: continue
			best = cell_of(p.clamp(Vector2(-limit,-limit),Vector2(limit,limit)))
		var merged := false
		for site: Dictionary in sites:
			if position_of(site.cell).distance_to(position_of(best)) < 3.0:
				site.volume = float(site.volume)+volume
				if h[best] < h[site.cell]: site.cell = best
				merged = true
				break
		if not merged: sites.append({"cell":best,"volume":volume})
	sites = sites.filter(func(site: Dictionary) -> bool: return float(site.volume) >= SCOOP_MIN)
	sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.volume > b.volume)
	sites.resize(mini(sites.size(),MAX_SCOOPS))
	if Guidance.enabled and Guidance.water_enabled and not sites.is_empty(): _guide_sites(grid,sites,ponds)
	return sites

## Quiet guidance for hollows: among ground within SITE_SLACK of the chosen
## low and SITE_REACH cells of it, the site that leaves no sliver of land
## between the new pond and the others (Guidance.site); then an oval along
## the contour, kept inside the rim.
static func _guide_sites(grid: Dictionary, sites: Array, ponds: Array) -> void:
	var h: PackedFloat32Array = grid.h
	var drain_cell: PackedByteArray = grid.drain
	var owner := PackedInt32Array()
	owner.resize(SIDE*SIDE)
	owner.fill(-1)
	var water := PackedVector2Array()
	for index in range(ponds.size()):
		for k in _flood_below(h,cell_of(Vector2(ponds[index].x,ponds[index].z)),float(ponds[index].level),owner,index):
			water.append(position_of(k))
	for site: Dictionary in sites:
		var radius := _scoop_radius(float(site.volume))
		var origin: int = site.cell
		var cells := PackedInt32Array([origin])
		var points := PackedVector2Array([position_of(origin)])
		var heights := PackedFloat32Array([h[origin]])
		var i := origin%SIDE
		var j := origin/SIDE
		for reach in range(1,Guidance.SITE_REACH+1):
			for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
				var ni: int = i+offset.x*reach
				var nj: int = j+offset.y*reach
				if ni < 0 or nj < 0 or ni >= SIDE or nj >= SIDE: continue
				var k: int = nj*SIDE+ni
				if drain_cell[k] or h[k] > h[origin]+Guidance.SITE_SLACK or _rim_distance(k) < radius+SCOOP_RIM: continue
				cells.append(k)
				points.append(position_of(k))
				heights.append(h[k])
		# Only water near enough to leave a sliver matters.
		var near := PackedVector2Array()
		var span := radius+Guidance.SLIVER_GAP+Guidance.SITE_REACH*GRID+GRID
		for w in water:
			if absf(w.x-points[0].x) < span and absf(w.y-points[0].y) < span: near.append(w)
		var chosen: int = cells[Guidance.site(points,heights,near,radius,origin)]
		site.cell = chosen
		site["moved"] = position_of(chosen).distance_to(position_of(origin))
		var ci := chosen%SIDE
		var cj := chosen/SIDE
		var gradient := Vector2(h[cj*SIDE+mini(ci+2,SIDE-1)]-h[cj*SIDE+maxi(ci-2,0)],h[mini(cj+2,SIDE-1)*SIDE+ci]-h[maxi(cj-2,0)*SIDE+ci])/(4.0*GRID)
		site.merge(Guidance.oval(chosen,gradient,_rim_distance(chosen)-SCOOP_RIM),true)

static func _scoop_radius(volume: float) -> float:
	return clampf(1.4+sqrt(volume)*0.9,SCOOP_RADIUS.x,SCOOP_RADIUS.y)

static func _rim_distance(k: int) -> float:
	var p := position_of(k)
	return 14.0-maxf(absf(p.x),absf(p.y))

## Lower a soft bowl, (1 - t²)² in profile, whose volume holds the site's
## water; update the grid under it. Returns the rect it touched.
static func _scoop(data: NativeTerrainData, heights: PackedFloat32Array, grid: Dictionary, site: Dictionary) -> Rect2:
	var volume: float = site.volume
	var radius := _scoop_radius(volume)
	# An oval (quiet guidance): long by √stretch, wide by 1/√stretch, the long
	# radius kept within the site's `room` from the rim.
	var stretch := sqrt(float(site.get("stretch",1.0)))
	var along := Vector2.from_angle(float(site.get("angle",0.0)))
	var long_radius := minf(radius*stretch,maxf(float(site.get("room",INF)),radius))
	var short_radius := radius/stretch
	# The bowl holds pi a b d / 3; a little over, so the pond has a bank.
	var depth := clampf(3.0*volume/(PI*long_radius*short_radius)+0.05,SCOOP_DEPTH.x,SCOOP_DEPTH.y)
	var center := position_of(site.cell)
	for i in range(data.points.size()):
		var offset := data.points[i]-center
		if absf(offset.x) >= long_radius or absf(offset.y) >= long_radius: continue
		var t := offset.length()/radius if stretch == 1.0 else Vector2(offset.dot(along)/long_radius,offset.dot(along.orthogonal())/short_radius).length()
		if t >= 1.0: continue
		var w := (1.0-t*t)*(1.0-t*t)
		heights[i] = maxf(NativeTerrainData.MIN_HEIGHT,heights[i]-depth*w)
	data.heights = heights
	var h: PackedFloat32Array = grid.h
	var drain_cell: PackedByteArray = grid.drain
	var rect := Rect2(center-Vector2.ONE*(long_radius+GRID),Vector2.ONE*(long_radius+GRID)*2.0)
	for k in range(SIDE*SIDE):
		if drain_cell[k] and h[k] <= -1000.0: continue
		if not rect.has_point(position_of(k)): continue
		var value: Variant = data.ground_height(position_of(k))
		if value != null: h[k] = float(value)
	return rect.grow(1.0)

## Raise a soft lip along the rim beside a pond that brims there, high enough
## to hold the water it lost (at most LIP_RISE more). Only raises ground.
## Returns the rect it touched, or an empty rect.
static func _lip(data: NativeTerrainData, heights: PackedFloat32Array, grid: Dictionary, rim: Dictionary, cap: float) -> Rect2:
	var region: PackedInt32Array = rim.region
	var frontage := PackedVector2Array()
	frontage.append(position_of(int(rim.spill)))
	for k in region:
		if _rim_distance(k) <= 1.5: frontage.append(position_of(k))
	var area := float(region.size())*GRID*GRID
	var top: float = minf(float(rim.level)+float(rim.volume)/maxf(area,1.0),cap)+SPILL_MARGIN+LIP_FREEBOARD
	var bounds := Rect2(frontage[0],Vector2.ZERO)
	for p in frontage: bounds = bounds.expand(p)
	bounds = bounds.grow(LIP_WIDTH+2.0)
	var touched := Rect2()
	var any := false
	for i in range(data.points.size()):
		var p := data.points[i]
		if not bounds.has_point(p): continue
		var edge := 14.0-maxf(absf(p.x),absf(p.y))
		if edge >= LIP_WIDTH: continue
		var near := INF
		for f in frontage: near = minf(near,f.distance_to(p))
		if near >= 3.5: continue
		var w := (1.0-smoothstep(0.0,LIP_WIDTH,edge))*(1.0-smoothstep(1.5,3.5,near))
		var raised := minf(NativeTerrainData.MAX_HEIGHT,lerpf(heights[i],maxf(heights[i],top),w))
		if raised <= heights[i]+0.001: continue
		heights[i] = raised
		touched = _grow(touched,any,Rect2(p,Vector2.ZERO))
		any = true
	if not any: return Rect2()
	data.heights = heights
	_regrid(data,grid,touched.grow(1.0))
	return touched.grow(1.5)

## Re-sample the planning grid under `rect` after the heights changed.
static func _regrid(data: NativeTerrainData, grid: Dictionary, rect: Rect2) -> void:
	var h: PackedFloat32Array = grid.h
	var drain_cell: PackedByteArray = grid.drain
	for k in range(SIDE*SIDE):
		if drain_cell[k] and h[k] <= -1000.0: continue
		if not rect.has_point(position_of(k)): continue
		var value: Variant = data.ground_height(position_of(k))
		if value != null: h[k] = float(value)

## Carve a shallow bed under each new stream and let its water down into it.
## Ground beside a pond, at or above its level, stays above that level, so no
## bed breaches a bank or drains a pond down a new channel. Returns the rect
## carved, or an empty rect.
static func _carve_beds(data: NativeTerrainData, grid: Dictionary, result: Dictionary, validate: bool) -> Rect2:
	var entries: Array = result.added_streams
	if entries.is_empty(): return Rect2()
	# Guard level per grid cell: the highest pond whose water is within ~1 m.
	var h: PackedFloat32Array = grid.h
	var guard := PackedFloat32Array()
	guard.resize(SIDE*SIDE)
	guard.fill(-INF)
	var owner := PackedInt32Array()
	owner.resize(SIDE*SIDE)
	owner.fill(-1)
	var ponds: Array = result.ponds
	for index in range(ponds.size()):
		var level := float(ponds[index].level)
		for k in _flood_below(h,cell_of(Vector2(ponds[index].x,ponds[index].z)),level,owner,index):
			var i := k%SIDE
			var j := k/SIDE
			for dj in range(-2,3):
				for di in range(-2,3):
					var ni := i+di
					var nj := j+dj
					if ni < 0 or nj < 0 or ni >= SIDE or nj >= SIDE: continue
					guard[nj*SIDE+ni] = maxf(guard[nj*SIDE+ni],level)
	var heights := data.heights
	var cut := PackedFloat32Array()
	cut.resize(heights.size())
	var rect := Rect2()
	var any := false
	for entry: Dictionary in entries:
		var record: Dictionary = entry.record
		var pts: Array = record.pts
		var half := maxf(BED_HALF_WIDTH,float(record.width)*1.1)
		var bounds := _stream_rect(record).grow(half)
		for i in range(data.points.size()):
			var p := data.points[i]
			if not bounds.has_point(p): continue
			var near := INF
			for s in range(1,pts.size()):
				var a := Vector2(pts[s-1].x,pts[s-1].z)
				var b := Vector2(pts[s].x,pts[s].z)
				near = minf(near,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b)))
			if near >= half: continue
			var t := near/half
			var depth := BED_DEPTH*(1.0-t*t)*(1.0-t*t)
			var floor_level: float = guard[cell_of(p)]
			if heights[i] >= floor_level:
				depth = minf(depth,maxf(0.0,heights[i]-(floor_level+BED_GUARD)))
			cut[i] = maxf(cut[i],depth)
	var before := heights.duplicate()
	for i in range(heights.size()):
		if cut[i] <= 0.001: continue
		heights[i] = maxf(NativeTerrainData.MIN_HEIGHT,heights[i]-cut[i])
		rect = _grow(rect,any,Rect2(data.points[i],Vector2.ZERO))
		any = true
	if not any: return Rect2()
	# Each stream's surface follows the ground down into its new bed.
	var ground_before := {}
	for entry: Dictionary in entries:
		for p: Dictionary in entry.record.pts:
			ground_before[Vector2(p.x,p.z)] = data.ground_height(Vector2(p.x,p.z))
	data.heights = heights
	# A pond whose surface the bed would break keeps the uncarved ground.
	if validate:
		for added: Dictionary in result.added:
			if NativeGardenWater.surface(data,added.record).is_empty():
				data.heights = before
				return Rect2()
	for entry: Dictionary in entries:
		var record: Dictionary = entry.record
		var lowered: Dictionary = record.duplicate(true)
		var ceiling := INF
		for p: Dictionary in lowered.pts:
			var was: Variant = ground_before[Vector2(p.x,p.z)]
			var now: Variant = data.ground_height(Vector2(p.x,p.z))
			var sink := BED_SINK*(float(was)-float(now)) if was != null and now != null else 0.0
			ceiling = minf(ceiling,float(p.h)-sink)
			p.h = clampf(ceiling,-1.5,66.0)
		if not preload("res://scripts/native_stream_record.gd").valid(lowered): continue
		var index: int = result.streams.find(record)
		if index >= 0: result.streams[index] = lowered
		entry.record = lowered
	_regrid(data,grid,rect.grow(1.0))
	return rect.grow(1.0)

static func _grow(rect: Rect2, started: bool, add: Rect2) -> Rect2:
	return rect.merge(add) if started else add

static func _find(group: Dictionary, s: int) -> int:
	var root := s
	var guard := 0
	while group.has(root) and group[root] != root and guard < 64:
		root = group[root]
		guard += 1
	return root

## Cells connected to `seed` (4-neighbour) under `level`, tagged with `tag`.
static func _flood_below(h: PackedFloat32Array, seed: int, level: float, owner: PackedInt32Array, tag: int) -> PackedInt32Array:
	var found := PackedInt32Array()
	if h[seed] >= level: return found
	var stack: Array[int] = [seed]
	owner[seed] = tag
	while not stack.is_empty():
		var k: int = stack.pop_back()
		found.append(k)
		for next in _neighbors4(k):
			if owner[next] == tag or h[next] >= level: continue
			owner[next] = tag
			stack.append(next)
	return found

static func _neighbors4(k: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var i := k%SIDE
	var j := k/SIDE
	if i > 0: result.append(k-1)
	if i < SIDE-1: result.append(k+1)
	if j > 0: result.append(k-SIDE)
	if j < SIDE-1: result.append(k+SIDE)
	return result

static func _lowest_neighbor(h: PackedFloat32Array, k: int) -> int:
	var i := k%SIDE
	var j := k/SIDE
	var best := k
	var best_drop := 0.0
	for dj in [-1,0,1]:
		for di in [-1,0,1]:
			if di == 0 and dj == 0: continue
			var ni: int = i+di
			var nj: int = j+dj
			if ni < 0 or nj < 0 or ni >= SIDE or nj >= SIDE: continue
			var n: int = nj*SIDE+ni
			# Diagonals compare by slope, so water does not favour them.
			var drop: float = (h[k]-h[n])/(1.41421356 if di != 0 and dj != 0 else 1.0)
			if drop > best_drop:
				best_drop = drop
				best = n
	return best

## Memoised steepest descent: the local low a cell drains to, or -1 for the edge.
static func _descend(h: PackedFloat32Array, drain_cell: PackedByteArray, sink: PackedInt32Array, k: int) -> int:
	var path := PackedInt32Array()
	var at := k
	var result := -1
	while true:
		if sink[at] != -2:
			result = sink[at]
			break
		if drain_cell[at]:
			result = -1
			break
		path.append(at)
		var next := _lowest_neighbor(h,at)
		if next == at:
			result = at
			break
		at = next
	for cell in path: sink[cell] = result
	return result

## Priority flood from the basins in `members`: raise the water until the
## poured volume is spent, or until it finds a lower cell draining elsewhere
## (the spill), or reaches the edge. Water below `start_level` is already there.
static func _fill(h: PackedFloat32Array, drain_cell: PackedByteArray, sink: PackedInt32Array, members: Array, volume: float, start_level: float, area: float) -> Dictionary:
	var heap := Heap.new()
	var seen := {}
	var level := INF
	for s: int in members:
		heap.push(h[s],s)
		seen[s] = true
		level = minf(level,h[s])
	var remaining := volume
	var region := PackedInt32Array()
	var inside := {}
	for s: int in members: inside[s] = true
	while not heap.empty():
		var height: float = heap.h[0]
		var k := heap.pop()
		if height > level:
			var from := maxf(level,start_level)
			var to := maxf(height,start_level)
			var cost := float(region.size())*area*(to-from)
			if region.size() > 0 and cost >= remaining:
				level = from+remaining/(float(region.size())*area)
				return {"level":level,"region":region,"spill":-1,"edge":false,"remaining":0.0}
			remaining -= cost
			level = height
		elif height < level and region.size() > 0 and not inside.has(sink[k]):
			return {"level":level,"region":region,"spill":k,"edge":sink[k] < 0,"remaining":remaining}
		elif height < level:
			remaining -= area*maxf(0.0,level-maxf(height,start_level))
		region.append(k)
		if drain_cell[k]:
			return {"level":level,"region":region,"spill":k,"edge":true,"remaining":remaining}
		for next in _neighbors4(k):
			if seen.has(next): continue
			seen[next] = true
			heap.push(h[next],next)
	return {"level":level,"region":region,"spill":-1,"edge":false,"remaining":remaining}

## Steepest descent from `start` until it reaches `region`, the edge or a low.
static func _path_down(h: PackedFloat32Array, start: int, region: PackedInt32Array) -> PackedInt32Array:
	var path := PackedInt32Array([start])
	var at := start
	for step in range(SIDE*3):
		if region.has(at) and path.size() > 1: break
		var next := _lowest_neighbor(h,at)
		if next == at: break
		path.append(next)
		at = next
		if _border(at): break
	return path

static func _path_length(path: PackedInt32Array) -> float:
	var total := 0.0
	for i in range(1,path.size()): total += position_of(path[i]).distance_to(position_of(path[i-1]))
	return total

static func _stream_rect(record: Dictionary) -> Rect2:
	var rect := Rect2(Vector2(record.pts[0].x,record.pts[0].z),Vector2.ZERO)
	for p: Dictionary in record.pts: rect = rect.expand(Vector2(p.x,p.z))
	return rect

## A stream record along a planned path: NativeWaterCourse.trace where it
## finds its way (it keeps momentum and curves), else the grid path smoothed.
static func _stream_record(data: NativeTerrainData, stream: Dictionary, water: PackedVector3Array) -> Dictionary:
	var path: PackedInt32Array = stream.path
	var first := position_of(path[0])
	var last := position_of(path[-1])
	var start_ground: Variant = data.ground_height(first)
	var end_ground: Variant = data.ground_height(last)
	if start_ground == null or end_ground == null: return {}
	var end_level: float = minf(float(stream.level),float(end_ground)+STREAM_LIFT) if water.is_empty() else float(stream.level)
	var stations := PackedVector3Array()
	var rings := clampi(int(_path_length(path)/0.4),6,64)
	var traced := NativeWaterCourse.trace(data,Vector3(first.x,float(start_ground)+0.08,first.y),Vector3(last.x,end_level,last.y),rings,water)
	if traced.size() >= 2:
		stations = traced
	else:
		var smoothed := PackedVector2Array()
		for i in range(path.size()):
			var a := position_of(path[maxi(0,i-1)])
			var b := position_of(path[i])
			var c := position_of(path[mini(path.size()-1,i+1)])
			smoothed.append(b if i == 0 or i == path.size()-1 else (a+b*2.0+c)*0.25)
		for p in smoothed:
			var ground: Variant = data.ground_height(p)
			if ground == null: return {}
			stations.append(Vector3(p.x,float(ground)+STREAM_LIFT,p.y))
		stations[-1].y = minf(stations[-1].y,end_level)
	var width := lerpf(STREAM_WIDTH.x,STREAM_WIDTH.y,clampf(sqrt(maxf(float(stream.volume),0.0))/4.0,0.0,1.0))
	var points: Array = []
	var ceiling := INF
	for station in stations:
		var x := clampf(station.x,-14.0,14.0)
		var z := clampf(station.z,-14.0,14.0)
		# The surface never climbs: `h` is non-increasing along a course.
		ceiling = minf(ceiling,station.y+STREAM_DEPTH-STREAM_SURFACE)
		var h := clampf(ceiling,-1.5,66.0)
		if not points.is_empty() and Vector2(points[-1].x,points[-1].z).distance_to(Vector2(x,z)) < 0.05: continue
		points.append({"x":x,"z":z,"h":h})
	if points.size() < 2 or points.size() > 1024: return {}
	var record := {"pts":points,"width":width,"depth":STREAM_DEPTH,"surface":STREAM_SURFACE,"capHead":true,"capTail":true}
	return record if preload("res://scripts/native_stream_record.gd").valid(record) else {}
