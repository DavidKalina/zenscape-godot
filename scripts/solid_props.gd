extends RefCounted
## The plate's solid props for the pilot on foot (scripts/wanderer_eye.gd,
## scripts/pilot_motor.gd): trees, rocks, logs, stumps, boulders, cacti and
## cabins as things with a height, read from their own drawn meshes, so the
## new moveset has something to stand on and kick off.
##
## Each drawn part of a prop is a column cut into bands by height (as the
## walker's `_profile`): round (the widest any vertex stands from the part's
## upright axis, band by band) or, for the long and square ones (BOXES: a
## log, a cabin), a box turned with the part (each band's extent along the
## part's own x and z). At a height, a part is as wide as its bands there.
##
## Three answers, in the plate's frame (x, z across, y up):
##  - `push`: a step of the feet pushed back out of every part that stands
##    in its way at the body's height (from STEP over the feet to HEAD), so
##    on the ground the figure slides round a trunk as before. A part that
##    can be stood on (`stand`: a rock, log, stump, boulder or cabin) stops
##    the body only while its top is more than a step (PilotMotor STEP_UP)
##    over the feet: lower, it is ground to step or land on. Foliage (a
##    crown, a spruce's skirt, a joshua's thatch, `soft`) stops the body on
##    the ground, keeping the eye out of it as before, but not in the air:
##    jumped into, the body goes in among the leaves to the trunk. Landed
##    inside a crown, the feet are eased back out of it (SOFT_EASE).
##  - `top`: the highest top that can be stood on over a point, or -INF:
##    read off the part's mesh from above (`_tops`: a grid of its highest
##    surface, so a boulder is domed, a log is only as wide as the log, and
##    a cabin's roof is pitched).
##  - `wall`: the way off the nearest part within reach that stands at least
##    PilotMotor WALL_TALL over the feet (measured to the whole prop's
##    highest point), at the body's height, for the wall slide and the wall
##    kick. Foliage is never a wall: a tree's wall is its trunk where the
##    crown is high (a broadleaf, a birch), and where foliage reaches the
##    ground the trunk inside it, once jumped into.

const PilotMotor = preload("res://scripts/pilot_motor.gd")

## Props that can be stood on, and those whose parts are boxes, not round.
const STANDS := ["rock","log","stump","boulder_1","boulder_2","boulder_3","boulder_4","cabin"]
const BOXES := ["log","cabin"]
## Words in a part's name that mark it foliage.
const SOFT_PARTS := ["canop","thatch","blades","deadwood"]
## Bands a part is cut into, and cells across its top's grid.
const BANDS := 24
const TOP_CELLS := 32
## Metres of the spatial grid's cells.
const CELL := 2.0
## Metres a step the feet are eased out of foliage they landed in.
const SOFT_EASE := 0.05
## Push-out passes a step takes.
const PASSES := 3

## The figure's radius, and the body's span over the feet that is stopped.
var radius := 0.28
var step := 0.2
var head := 1.3

## The parts: {"at": Vector2 (the axis, plate x, z), "base": the lowest
## band's foot (plate y), "band": a band's height (m), "top": the highest
## point (plate y), "round": radii by band (m) or "rects": Rect2 by band
## (part-local x, z), "to_local": plate to part-local (boxes and tops),
## "from_local", "scale" (x, z), "stand", "soft", "wall", "tops": the top
## grid (Dictionary, see `_tops`) for those stood on.}
var parts: Array[Dictionary] = []
var _grid := {}
## Each prop's highest point (plate y) by its key, every part counted: a
## broadleaf's trunk part ends in its crown, but the tree stands as tall as
## the crown's top.
var _tall := {}

static var _profiles := {}
static var _box_profiles := {}
static var _top_grids := {}

func _init(figure_radius := 0.28, step_over := 0.2, body := 1.3) -> void:
	radius = figure_radius
	step = step_over
	head = body

func clear() -> void:
	parts.clear()
	_grid.clear()
	_tall.clear()

func is_empty() -> bool:
	return parts.is_empty()

## A drawn part of prop `asset` (its mesh named `part`), placed by `placed`
## (mesh to plate); `key` names the prop the part belongs to.
func add_mesh(asset: String, part: String, mesh: Mesh, placed: Transform3D, key: Variant = null) -> void:
	var box := mesh.get_aabb()
	if box.size.y <= 0.0001: return
	var lift: float = placed.basis.y.y
	var scale := placed.basis.get_scale()
	var p := {"at":Vector2(placed.origin.x,placed.origin.z),
		"base":placed.origin.y+lift*box.position.y,"band":lift*box.size.y/BANDS,
		"top":placed.origin.y+lift*box.end.y,
		"stand":asset in STANDS,"soft":false,"wall":true,"key":key,
		"to_local":placed.affine_inverse(),"from_local":placed,"scale":Vector2(scale.x,scale.z)}
	for word: String in SOFT_PARTS:
		if word in part or part == "canopy": p.soft = true
	if p.soft: p.wall = false
	var reach := 0.0
	if asset in BOXES:
		var rects := _box_profile(mesh)
		p.rects = rects
		for r: Variant in rects:
			if r == null: continue
			var b := r as Rect2
			for c: Vector2 in [b.position,b.end,Vector2(b.position.x,b.end.y),Vector2(b.end.x,b.position.y)]:
				reach = maxf(reach,(c*p.scale).length())
	else:
		var radii := PackedFloat32Array()
		var wide := maxf(scale.x,scale.z)
		for r: float in _profile(mesh): radii.append(r*wide)
		p.round = radii
		for r: float in radii: reach = maxf(reach,r)
	if reach <= 0.0: return
	if p.stand: p.tops = _tops(mesh)
	p.reach = reach
	if key != null: _tall[key] = maxf(float(_tall.get(key,-INF)),float(p.top))
	_insert(p)

## A plain upright cylinder: the parked plane, a wall to nothing and never
## stood on.
func add_column(at: Vector2, base: float, height: float, wide: float) -> void:
	var radii := PackedFloat32Array()
	radii.resize(BANDS)
	radii.fill(wide)
	_insert({"at":at,"base":base,"band":height/BANDS,"top":base+height,"round":radii,
		"stand":false,"soft":false,"wall":false,"reach":wide})

func _insert(p: Dictionary) -> void:
	var index := parts.size()
	parts.append(p)
	var r: float = p.reach+radius
	var at: Vector2 = p.at
	for x in range(floori((at.x-r)/CELL),floori((at.x+r)/CELL)+1):
		for z in range(floori((at.y-r)/CELL),floori((at.y+r)/CELL)+1):
			var cell := Vector2i(x,z)
			if not _grid.has(cell): _grid[cell] = PackedInt32Array()
			_grid[cell].append(index)

## The parts whose reach may touch plate point `p`.
func _near(p: Vector2) -> PackedInt32Array:
	return _grid.get(Vector2i(floori(p.x/CELL),floori(p.y/CELL)),PackedInt32Array())

# --- Shapes by height ---------------------------------------------------------------

## A round part's widest between plate heights `low` and `high`, or 0.
static func _round_span(p: Dictionary, low: float, high: float) -> float:
	var radii: PackedFloat32Array = p.round
	var band: float = p.band
	var base: float = p.base
	var a := clampi(floori((low-base)/band),0,BANDS)
	var b := clampi(ceili((high-base)/band),0,BANDS)
	var wide := 0.0
	for i in range(a,b): wide = maxf(wide,radii[i])
	return wide

## A box part's extent (part-local x, z) between plate heights `low` and
## `high`, or an empty Rect2.
static func _box_span(p: Dictionary, low: float, high: float) -> Rect2:
	var rects: Array = p.rects
	var band: float = p.band
	var base: float = p.base
	var a := clampi(floori((low-base)/band),0,BANDS)
	var b := clampi(ceili((high-base)/band),0,BANDS)
	var out := Rect2()
	var any := false
	for i in range(a,b):
		if rects[i] == null: continue
		var r: Rect2 = rects[i]
		out = r if not any else out.merge(r)
		any = true
	return out if any else Rect2()

## Whether part `p` stops a body with its feet at height `y`, stepping to
## plate point `to`: foliage only on the ground; a part that can be stood on
## only while its top stands over a step above the feet. On the ground that
## is its highest top, so a boulder is no slope to walk up; in the air its
## top where the body comes down (at `to` and a figure's radius in from it),
## so falling onto a boulder's shoulder lands on it there.
func _stops(p: Dictionary, y: float, grounded: bool, to: Vector2) -> bool:
	if p.soft and not grounded: return false
	if p.stand:
		if float(p.top) <= y+PilotMotor.STEP_UP: return false
		if not grounded:
			var at: Vector2 = p.at
			var inward := (at-to).limit_length(radius)
			if maxf(_top_of(p,to),_top_of(p,to+inward)) <= y+PilotMotor.STEP_UP: return false
	return float(p.top) > y+step and float(p.base) < y+head

## Plate point `q` at height `y` in a box part's own frame.
static func _local(p: Dictionary, q: Vector2, y: float) -> Vector3:
	return (p.to_local as Transform3D)*Vector3(q.x,y,q.y)

# --- The walk -----------------------------------------------------------------------

## A step from `feet` by `way` (x, z) pushed back out of what stands in the
## way; `grounded` as the motor is. Walked square into a round part the step
## is leaned round it on the side it is already on, so it never stops dead.
func push(feet: Vector3, way: Vector2, grounded: bool) -> Vector2:
	var from := Vector2(feet.x,feet.z)
	var to := from+way
	var y := feet.y
	for i in _near(to):
		var p := parts[i]
		if not p.has("round") or not _stops(p,y,grounded,to): continue
		var wide := _round_span(p,y+step,y+head)
		if wide <= 0.0: continue
		var r := wide+radius
		var centre: Vector2 = p.at
		if to.distance_to(centre) >= r or (p.soft and from.distance_to(centre) < r): continue
		var normal := (from-centre).normalized() if from.distance_to(centre) > 0.0001 else -way.normalized()
		if way.normalized().dot(-normal) > 0.97:
			var side := signf(normal.cross(way)) if absf(normal.cross(way)) > 1e-6 else 1.0
			to += Vector2(-normal.y,normal.x)*side*way.length()*0.6
	for _round in range(PASSES):
		var moved := false
		for i in _near(to):
			var p := parts[i]
			if not _stops(p,y,grounded,to): continue
			var out := _out_of(p,from,to,y)
			if out != to:
				to = out
				moved = true
		if not moved: break
	return to

## `to` out of part `p` at feet height `y` (unchanged if clear). Foliage the
## feet were already in eases them out.
func _out_of(p: Dictionary, from: Vector2, to: Vector2, y: float) -> Vector2:
	if p.has("round"):
		var wide := _round_span(p,y+step,y+head)
		if wide <= 0.0: return to
		var r := wide+radius
		var centre: Vector2 = p.at
		var away := to-centre
		var gap := away.length()
		if gap >= r: return to
		var dir := away/gap if gap > 0.0001 else Vector2.RIGHT
		if p.soft and from.distance_to(centre) < r: return to+dir*minf(r-gap,SOFT_EASE)
		return centre+dir*r
	var rect := _box_span(p,y+step,y+head)
	if rect.size == Vector2.ZERO: return to
	var s: Vector2 = p.scale
	var grown := rect.grow_individual(radius/s.x,radius/s.y,radius/s.x,radius/s.y)
	var l3 := _local(p,to,y)
	var l := Vector2(l3.x,l3.z)
	if not grown.has_point(l): return to
	# Out through the nearest side, in metres.
	var sides := [(l.x-grown.position.x)*s.x,(grown.end.x-l.x)*s.x,(l.y-grown.position.y)*s.y,(grown.end.y-l.y)*s.y]
	var best := 0
	for k in range(1,4):
		if sides[k] < sides[best]: best = k
	match best:
		0: l.x = grown.position.x
		1: l.x = grown.end.x
		2: l.y = grown.position.y
		3: l.y = grown.end.y
	var back: Vector3 = (p.from_local as Transform3D)*Vector3(l.x,l3.y,l.y)
	return Vector2(back.x,back.z)

## Whether a body with its feet at `feet` stands in any part.
func inside(feet: Vector3, grounded := true) -> bool:
	var at := Vector2(feet.x,feet.z)
	for i in _near(at):
		var p := parts[i]
		if _stops(p,feet.y,grounded,at) and _out_of(p,Vector2.INF,at,feet.y) != at: return true
	return false

# --- Tops ---------------------------------------------------------------------------

## The highest top to stand on over plate point `q` (plate y), or -INF.
func top(q: Vector2) -> float:
	var best := -INF
	for i in _near(q):
		var p := parts[i]
		if p.stand: best = maxf(best,_top_of(p,q))
	return best

## Part `p`'s top over plate point `q` (plate y), or -INF.
static func _top_of(p: Dictionary, q: Vector2) -> float:
	var at: Vector2 = p.at
	if q.distance_squared_to(at) > float(p.reach)*float(p.reach): return -INF
	var grid: Dictionary = p.tops
	var l: Vector3 = (p.to_local as Transform3D)*Vector3(q.x,float(p.top),q.y)
	var cx := floori((l.x-float(grid.x))/float(grid.cell))
	var cz := floori((l.z-float(grid.z))/float(grid.cell))
	if cx < 0 or cz < 0 or cx >= int(grid.nx) or cz >= int(grid.nz): return -INF
	var h: float = (grid.heights as PackedFloat32Array)[cz*int(grid.nx)+cx]
	if not is_finite(h): return -INF
	return ((p.from_local as Transform3D)*Vector3(l.x,h,l.z)).y

# --- Walls --------------------------------------------------------------------------

## The way off the nearest wall `reach` along `way` from `feet` (x, z), or
## Vector2.ZERO: a part, not foliage, standing at least WALL_TALL over the
## feet, as wide as it is at the body's height (the figure's radius added,
## as the walk keeps the feet off it).
func wall(feet: Vector3, way: Vector2, reach: float) -> Vector2:
	var from := Vector2(feet.x,feet.z)
	var to := from+way*reach
	var y := feet.y
	var best := Vector2.ZERO
	var nearest := INF
	var seen := {}
	for q: Vector2 in [from,to]:
		for i in _near(q):
			if seen.has(i): continue
			seen[i] = true
			var p := parts[i]
			if not p.wall or _height(p) < y+PilotMotor.WALL_TALL or float(p.base) > y+head: continue
			if p.has("round"):
				var wide := _round_span(p,y+step,y+head)
				if wide <= 0.0: continue
				var centre: Vector2 = p.at
				var gap := _segment_gap(centre,from,to)-wide-radius
				if gap > 0.001: continue
				var d := from.distance_to(centre)
				if d < nearest:
					nearest = d
					best = (from-centre)/d if d > 0.0001 else -way
			else:
				var rect := _box_span(p,y+step,y+head)
				if rect.size == Vector2.ZERO: continue
				var s: Vector2 = p.scale
				var grown := rect.grow_individual(radius/s.x+0.01,radius/s.y+0.01,radius/s.x+0.01,radius/s.y+0.01)
				var lt3 := _local(p,to,y)
				if not grown.has_point(Vector2(lt3.x,lt3.z)): continue
				var lf3 := _local(p,from,y)
				var lf := Vector2(lf3.x,lf3.z)
				# The side the feet are off: the axis they stand out furthest on.
				var dx := maxf(grown.position.x-lf.x,lf.x-grown.end.x)*s.x
				var dz := maxf(grown.position.y-lf.y,lf.y-grown.end.y)*s.y
				var n := Vector3(signf(lf.x-grown.get_center().x),0.0,0.0) if dx >= dz else Vector3(0.0,0.0,signf(lf.y-grown.get_center().y))
				var world: Vector3 = (p.from_local as Transform3D).basis*n
				var flat := Vector2(world.x,world.z).normalized()
				var d := maxf(maxf(dx,dz),0.0)
				if d < nearest:
					nearest = d
					best = flat
	return best

## A part's prop's highest point (plate y).
func _height(p: Dictionary) -> float:
	return float(_tall.get(p.key,p.top)) if p.get("key") != null else float(p.top)

## How far `c` is from the segment `a`-`b`.
static func _segment_gap(c: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b-a
	var t := 0.0 if ab.length_squared() < 1e-10 else clampf((c-a).dot(ab)/ab.length_squared(),0.0,1.0)
	return c.distance_to(a+ab*t)

# --- Read from the meshes, once each ------------------------------------------------

## A mesh's widest from its upright axis by band (BANDS, the mesh's own
## units).
static func _profile(mesh: Mesh) -> PackedFloat32Array:
	if _profiles.has(mesh): return _profiles[mesh]
	var box := mesh.get_aabb()
	var band := maxf(box.size.y,0.0001)/BANDS
	var radii := PackedFloat32Array()
	radii.resize(BANDS)
	for s in range(mesh.get_surface_count()):
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var i := clampi(int((v.y-box.position.y)/band),0,BANDS-1)
			radii[i] = maxf(radii[i],Vector2(v.x,v.z).length())
	_profiles[mesh] = radii
	return radii

## A mesh's extent (x, z) by band, null where a band has no vertex.
static func _box_profile(mesh: Mesh) -> Array:
	if _box_profiles.has(mesh): return _box_profiles[mesh]
	var box := mesh.get_aabb()
	var band := maxf(box.size.y,0.0001)/BANDS
	var rects := []
	var any := []
	rects.resize(BANDS)
	any.resize(BANDS)
	any.fill(false)
	for s in range(mesh.get_surface_count()):
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var i := clampi(int((v.y-box.position.y)/band),0,BANDS-1)
			var at := Vector2(v.x,v.z)
			rects[i] = Rect2(at,Vector2.ZERO) if not any[i] else (rects[i] as Rect2).expand(at)
			any[i] = true
	# A band between two with vertices (a roof's slope, a wall's run) spans
	# both: the faces cross it.
	for i in range(BANDS):
		if any[i]: continue
		var below := -1
		var above := -1
		for k in range(i-1,-1,-1):
			if any[k]:
				below = k
				break
		for k in range(i+1,BANDS):
			if any[k]:
				above = k
				break
		if below >= 0 and above >= 0: rects[i] = (rects[below] as Rect2).merge(rects[above])
	_box_profiles[mesh] = rects
	return rects

## A mesh's highest surface seen from above, on a grid of TOP_CELLS across
## its widest: {"x", "z" (the grid's corner), "cell" (m), "nx", "nz",
## "heights" (mesh y by cell, -INF where nothing is)}, every upward-facing
## triangle laid on it.
static func _tops(mesh: Mesh) -> Dictionary:
	if _top_grids.has(mesh): return _top_grids[mesh]
	var box := mesh.get_aabb()
	var cell := maxf(maxf(box.size.x,box.size.z),0.001)/TOP_CELLS
	var nx := maxi(1,ceili(box.size.x/cell))
	var nz := maxi(1,ceili(box.size.z/cell))
	var heights := PackedFloat32Array()
	heights.resize(nx*nz)
	heights.fill(-INF)
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var count: int = (indices as PackedInt32Array).size() if indices != null else vertices.size()
		for t in range(0,count-2,3):
			var a := vertices[indices[t] if indices != null else t]
			var b := vertices[indices[t+1] if indices != null else t+1]
			var c := vertices[indices[t+2] if indices != null else t+2]
			var area := (b.x-a.x)*(c.z-a.z)-(c.x-a.x)*(b.z-a.z)
			if absf(area) < 1e-8: continue
			var x0 := clampi(floori((minf(a.x,minf(b.x,c.x))-box.position.x)/cell),0,nx-1)
			var x1 := clampi(floori((maxf(a.x,maxf(b.x,c.x))-box.position.x)/cell),0,nx-1)
			var z0 := clampi(floori((minf(a.z,minf(b.z,c.z))-box.position.z)/cell),0,nz-1)
			var z1 := clampi(floori((maxf(a.z,maxf(b.z,c.z))-box.position.z)/cell),0,nz-1)
			for x in range(x0,x1+1):
				for z in range(z0,z1+1):
					var px := box.position.x+(x+0.5)*cell
					var pz := box.position.z+(z+0.5)*cell
					var u := ((b.x-px)*(c.z-pz)-(c.x-px)*(b.z-pz))/area
					var v := ((c.x-px)*(a.z-pz)-(a.x-px)*(c.z-pz))/area
					var w := 1.0-u-v
					if u < -1e-4 or v < -1e-4 or w < -1e-4: continue
					var h := a.y*u+b.y*v+c.y*w
					var k := z*nx+x
					if h > heights[k]: heights[k] = h
	# Cells the faces' centres missed (a steep flank's thin slivers) take the
	# highest of their neighbours, where they are ringed by top.
	var filled := heights.duplicate()
	for z in range(nz):
		for x in range(nx):
			if is_finite(heights[z*nx+x]): continue
			var near := -INF
			var count := 0
			for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var n := Vector2i(x,z)+d
				if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz or not is_finite(heights[n.y*nx+n.x]): continue
				near = maxf(near,heights[n.y*nx+n.x])
				count += 1
			if count >= 2: filled[z*nx+x] = near
	heights = filled
	var grid := {"x":box.position.x,"z":box.position.z,"cell":cell,"nx":nx,"nz":nz,"heights":heights}
	_top_grids[mesh] = grid
	return grid
