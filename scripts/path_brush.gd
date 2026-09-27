extends "res://scripts/creation_brush.gd"
## The path brush: drag to wear a path; Shift or a right drag lets it grow
## back. The tread wears to packed earth with a little green left at its
## shoulders, and settles a few centimetres into the ground, smoothing across
## so it follows the land gently instead of every bump. Its margins turn
## stony: some edge faces take a gravel colour while painting, and when the
## stroke ends a scatter of small stones is laid along both edges.
##
## Tread and margin cells are marked hand, so nothing emerges on the path. At
## release the path clears emerged plants from its tread, and generated
## undergrowth too; hand-placed and pinned records, and generated trees and
## rocks, stay where they are. Nothing is handed to emergence.
## Seconds of brushing at strength 1 for the centre of the tread to wear.
const RATE := 2.2
## The tread: cover left at its centre, the worn earth's weight, and how far
## out (in brush radii) the earth and the stony margin reach.
const WORN_COVER := 0.12
const EARTH_WEIGHT := 0.8
const TREAD := 0.7
const MARGIN := 1.15
## Share of margin cells that turn to gravel, and their weight.
const STONY_SHARE := 0.45
const STONY_WEIGHT := 0.6
## Settling: metres per second of sinking at the centre, the deepest it goes
## below where the stroke found the ground, and how fast (per second) it
## eases each vertex toward the mean of its neighbours.
const SINK_RATE := 0.3
const MAX_SINK := 0.07
const SMOOTH := 4.0
## Stones: spacing of candidates along each edge (m), the chance one lands,
## their size range (NativeTerrainData "rock" scale), and a cap per stroke.
const STONE_SPACING := 0.32
const STONE_CHANCE := 0.34
const STONE_SIZE := Vector2(0.1,0.22)
const STONE_CAP := 80
## Generated records a path may clear from its tread.
const UNDERGROWTH := ["grass_tuft","fern","shrub","mushroom","bank_grass","reeds","button_flower","spike_flower","umbel_flower","daisy_flower","flower","leaf_bed"]

var _earth := Color()
var _gravel := Color()
var _start := PackedFloat32Array()
var _trail := PackedVector2Array()
var _trail_radius := 0.0
var _lower := false

func _init() -> void:
	brush_id = "path"
	radius = 1.1
	radius_range = Vector2(0.5,3.0)

func _prepared(data: NativeTerrainData) -> void:
	var palette: NativeTerrainPalette = data._palette
	_earth = palette.sand.lerp(palette.gravel,0.45)*0.78
	_earth.a = 1.0
	_gravel = palette.gravel.lerp(palette.rock[1],0.35)

func begin() -> void:
	super.begin()
	_start = PackedFloat32Array()
	_trail = PackedVector2Array()
	_trail_radius = 0.0
	_lower = false

func dab(data: NativeTerrainData, center: Vector2, reach: float, amount: float, lower: bool) -> void:
	if reach <= 0.0 or amount <= 0.0: return
	if _start.is_empty(): _start = data.heights.duplicate()
	_grow_bounds(center,reach*MARGIN)
	_lower = _lower or lower
	if not lower and (_trail.is_empty() or _trail[_trail.size()-1].distance_to(center) > reach*0.25):
		_trail.append(center)
		_trail_radius = maxf(_trail_radius,reach)
	var tint := data.tint
	var grass := data.grass
	var provenance := data.provenance
	for found: Vector2 in _cells_near(data,center,reach*MARGIN):
		var cell := int(found.x)
		var t := found.y/reach
		var step := amount*RATE*(1.0-smoothstep(TREAD,MARGIN,t))
		if step <= 0.0: continue
		provenance[cell] = NativeTerrainData.SOURCE_HAND
		if lower:
			_tint_toward(tint,cell,Color(),0.0,step)
			grass[cell] = move_toward(grass[cell],1.0,step)
			continue
		if t > TREAD*0.85 and Variety.unit([seed_value,17,cell]) < STONY_SHARE:
			_tint_toward(tint,cell,_gravel,STONY_WEIGHT,step*STONY_WEIGHT)
		else:
			_tint_toward(tint,cell,_earth,EARTH_WEIGHT*(1.0-smoothstep(TREAD*0.6,MARGIN,t)*0.5),step*EARTH_WEIGHT)
		grass[cell] = move_toward(grass[cell],lerpf(WORN_COVER,1.0,smoothstep(TREAD*0.5,MARGIN,t)),step)
	data.tint = tint
	data.grass = grass
	data.provenance = provenance
	if not lower: _settle(data,center,reach,amount)

## Sink the tread a little and smooth across it, never deeper than MAX_SINK
## below the ground the stroke started on.
func _settle(data: NativeTerrainData, center: Vector2, reach: float, amount: float) -> void:
	var heights := data.heights
	var neighbors: Array[PackedInt32Array] = data._neighbors
	for i in _vertices_near(data,center,reach):
		var t := data.points[i].distance_to(center)/reach
		var weight := 1.0-smoothstep(0.2,1.0,t)
		var h: float = heights[i]
		var around: PackedInt32Array = neighbors[i]
		if not around.is_empty():
			var total := 0.0
			for n: int in around: total += heights[n]
			h = lerpf(h,total/around.size(),clampf(amount*SMOOTH*weight,0.0,1.0))
		h -= amount*SINK_RATE*weight
		heights[i] = clampf(maxf(h,_start[i]-MAX_SINK),NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	data.heights = heights

## Clear the tread of what grew there and lay stones along both edges.
func finish(data: NativeTerrainData) -> Rect2:
	has_bounds = false
	if _lower or _trail.is_empty(): return Rect2()
	var tread := _trail_radius*TREAD
	_clear_objects(data,func(p: Vector2) -> bool: return _distance(p) < tread,func(asset: String) -> bool: return asset in UNDERGROWTH)
	_lay_stones(data)
	return Rect2()

## Distance from a point to the stroke's centre line.
func _distance(p: Vector2) -> float:
	if _trail.size() == 1: return p.distance_to(_trail[0])
	var best := INF
	for i in range(_trail.size()-1):
		best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,_trail[i],_trail[i+1])))
	return best

func _lay_stones(data: NativeTerrainData) -> void:
	var laid := 0
	var near := {}
	for item in data.objects:
		near.get_or_add(Vector2i(floori(item.x),floori(item.z)),[]).append(Vector2(item.x,item.z))
	var walked := 0.0
	var points := _trail if _trail.size() > 1 else PackedVector2Array([_trail[0]-Vector2(0.01,0),_trail[0]+Vector2(0.01,0)])
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		var along := a.distance_to(b)
		if along <= 0.0: continue
		var direction := a.direction_to(b)
		var side := Vector2(-direction.y,direction.x)
		var s := fmod(STONE_SPACING-fmod(walked,STONE_SPACING),STONE_SPACING)
		while s < along:
			var key := [seed_value,19,roundi((walked+s)/STONE_SPACING)]
			for edge: float in [-1.0,1.0]:
				var edge_key := key+[int(edge)]
				if Variety.unit(edge_key+[1]) >= STONE_CHANCE or laid >= STONE_CAP: continue
				var out := _trail_radius*lerpf(0.72,1.05,Variety.unit(edge_key+[2]))
				var p := a+direction*(s+(Variety.unit(edge_key+[3])-0.5)*STONE_SPACING)+side*edge*out
				if maxf(absf(p.x),absf(p.y)) > 12.5 or _distance(p) < _trail_radius*0.6: continue
				var h: Variant = data.ground_height(p)
				if h == null or data.is_void(p) or _wet(data,p) or _crowded(near,p): continue
				var size := lerpf(STONE_SIZE.x,STONE_SIZE.y,pow(Variety.unit(edge_key+[4]),1.6))
				if data.place("rock",p,Variety.unit(edge_key+[5])*TAU,size) < 0: return
				near.get_or_add(Vector2i(p.floor()),[]).append(p)
				laid += 1
			s += STONE_SPACING
		walked += along

func _crowded(near: Dictionary, p: Vector2) -> bool:
	var base := Vector2i(p.floor())
	for dz in range(-1,2):
		for dx in range(-1,2):
			for other: Vector2 in near.get(base+Vector2i(dx,dz),[]):
				if p.distance_squared_to(other) < 0.2*0.2: return true
	return false

## Stones stay out of ponds.
func _wet(data: NativeTerrainData, p: Vector2) -> bool:
	var h: float = data.ground_height(p)
	for pond in data.ponds:
		if h < float(pond.level) and Vector2(p.x-float(pond.x),p.y-float(pond.z)).length() < 8.0: return true
	return false
