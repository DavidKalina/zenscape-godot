extends RefCounted
## A motif isle's land as the sky dragon reads it (docs/design/rim-dragon.md,
## round 7): what SkyIslet's shape answered for the old far isles, built
## from a placed motif isle (scripts/kit_isle/motif_isle.gd) as it stands at
## rest. All in the frame of `home` (its main land's middle at its datum):
##   on_land(p)    p (x, z) on any of its turf outlines (its satellites too);
##   ground_at(p)  its turf's height there over home.y;
##   open_at(p)    turf there with nothing standing on it (ruin, bell,
##                 tree, water) within a metre or so: where the chin can
##                 rest and the pilot can stand;
##   main_at(p)    p on its main land (the largest outline);
##   turf_at(p)    as ground_at, but null off its main turf (round 8);
##   top_at(p)     the top of anything solid there (turf, ruins, bells,
##                 trees, rock, water), spread a cell either way, or null
##                 over open air (round 8: the floor the dragon's breath
##                 rides over and its head is kept above).
## The heights and the open map are sampled once, by rays at its turf and
## at everything solid, on a GRID m grid over its main land's bounds and
## a margin, while the isle stands at rest.
const GRID := 1.5
const TURF_LAYER := 1 << 11
const SOLID_LAYER := 1
const WATER_LAYER := 1 << 12
## Something standing this far over the turf blocks it.
const STANDS := 0.5

var home := Vector3.ZERO
var reach := 30.0
## Its main land's radius from home (m, the furthest outline point).
var radius := 16.0
var _outlines: Array = []
var _main := -1
var _lo := Vector2.ZERO
var _nx := 0
var _nz := 0
var _height := PackedFloat32Array()
var _open := PackedByteArray()
var _top := PackedFloat32Array()
var _top_raw := PackedFloat32Array()
## Metres of grid kept round the main land's bounds (round 8: wide enough
## to take in its near satellites and spires for the breath).
const MARGIN := 14.0
var ok := false
## The turf of its other lands (satellites, spire tops): left out of the
## heights here, and of the dragon's rays at the turf while it holds on
## (`exclude`), so a spire's top over its head never reads as its ground.
var exclude: Array[RID] = []

## Built from `isle` (a placed motif isle standing at rest): its outlines
## (world x, z), its turf bodies; `space` the world's physics.
func build(isle: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var outlines: Array = isle.get("_outlines")
	var turf: Array = isle.get("_turf")
	if outlines == null or outlines.is_empty(): return
	var best_area := -1.0
	for i in range(outlines.size()):
		var o: PackedVector2Array = outlines[i]
		var area := 0.0
		for j in range(o.size()):
			var a := o[j]
			var b := o[(j+1)%o.size()]
			area += a.x*b.y-b.x*a.y
		if absf(area) > best_area:
			best_area = absf(area)
			_main = i
	var main: PackedVector2Array = outlines[_main]
	var mid := Vector2.ZERO
	var lo := Vector2(INF,INF)
	var hi := -lo
	for p in main:
		mid += p
		lo = lo.min(p)
		hi = hi.max(p)
	mid /= float(main.size())
	# The middle of its bounds if the outline's points crowd one side.
	if not Geometry2D.is_point_in_polygon(mid,main): mid = (lo+hi)*0.5
	home = Vector3(mid.x,float(isle.call("isle_top")),mid.y)
	for o: PackedVector2Array in outlines:
		var moved := PackedVector2Array()
		for p in o: moved.append(p-mid)
		_outlines.append(moved)
	radius = 0.0
	for p in main: radius = maxf(radius,p.distance_to(mid))
	reach = radius+4.0
	# The grid: heights and open turf over the main land and a margin.
	_lo = lo-mid-Vector2.ONE*MARGIN
	var size := hi-lo+Vector2.ONE*2.0*MARGIN
	_nx = int(ceil(size.x/GRID))+1
	_nz = int(ceil(size.y/GRID))+1
	_height.resize(_nx*_nz)
	_open.resize(_nx*_nz)
	var raw := PackedFloat32Array()
	raw.resize(_nx*_nz)
	var turf_rids := {}
	for body: Node in turf:
		if body is CollisionObject3D: turf_rids[(body as CollisionObject3D).get_rid()] = true
	# Its main land's own turf (its lands and outlines are registered in
	# the same order: scripts/kit_isle/motif_isle.gd `_register`).
	var main_rids := {}
	var motif: Variant = isle.get("motif")
	if motif != null and (motif.lands as Array).size() == outlines.size():
		var land: Array = motif.lands[_main]
		var node: Node3D = land[0]
		for body: Node in (KitLand.turf_bodies(node) if bool(land[2]) else [node.get_node("Body")]):
			if body is CollisionObject3D: main_rids[(body as CollisionObject3D).get_rid()] = true
	if not main_rids.is_empty():
		for rid: RID in turf_rids:
			if not main_rids.has(rid): exclude.append(rid)
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collide_with_areas = false
	var hits := 0
	for iz in range(_nz):
		for ix in range(_nx):
			var flat := _lo+Vector2(ix,iz)*GRID
			var k := iz*_nx+ix
			_height[k] = NAN
			_open[k] = 0
			raw[k] = NAN
			# The top of anything solid there, over land or not (round 8).
			var high := Vector3(home.x+flat.x,home.y+140.0,home.z+flat.y)
			ray.from = high
			ray.to = high+Vector3.DOWN*240.0
			ray.collision_mask = SOLID_LAYER|TURF_LAYER|WATER_LAYER
			ray.exclude = []
			var over := space.intersect_ray(ray)
			if not over.is_empty(): raw[k] = (over.position as Vector3).y-home.y
			if not on_land(flat): continue
			var w := Vector3(home.x+flat.x,home.y+60.0,home.z+flat.y)
			ray.from = w
			ray.to = w+Vector3.DOWN*160.0
			ray.collision_mask = TURF_LAYER
			ray.exclude = exclude
			var hit := space.intersect_ray(ray)
			if hit.is_empty(): continue
			hits += 1
			var g: float = (hit.position as Vector3).y
			_height[k] = g-home.y
			ray.collision_mask = SOLID_LAYER|TURF_LAYER|WATER_LAYER
			ray.exclude = []
			var top := space.intersect_ray(ray)
			var free := top.is_empty() or turf_rids.has(top.rid) or (top.position as Vector3).y < g+STANDS
			_open[k] = 1 if free else 0
	# The tops spread a cell either way, so a thin wall or a column reads
	# from either side and the breath lifts before it, not into it.
	_top.resize(_nx*_nz)
	for iz in range(_nz):
		for ix in range(_nx):
			var best := NAN
			for dz in range(-1,2):
				for dx in range(-1,2):
					var x := ix+dx
					var z := iz+dz
					if x < 0 or z < 0 or x >= _nx or z >= _nz: continue
					var h := raw[z*_nx+x]
					if not is_nan(h) and (is_nan(best) or h > best): best = h
			_top[iz*_nx+ix] = best
	_top_raw = raw
	ok = hits > 0

func _cell(p: Vector2) -> Vector2:
	return (p-_lo)/GRID

func on_land(p: Vector2) -> bool:
	for o: PackedVector2Array in _outlines:
		if Geometry2D.is_point_in_polygon(p,o): return true
	return false

func main_at(p: Vector2) -> bool:
	return _main >= 0 and Geometry2D.is_point_in_polygon(p,_outlines[_main])

## Its turf's height over home.y at p (bilinear over the grid's known
## cells; off the grid or unknown, the nearest known, else 0).
func ground_at(p: Vector2) -> float:
	if _nx == 0: return 0.0
	var c := _cell(p)
	var x0 := clampi(int(floor(c.x)),0,_nx-1)
	var z0 := clampi(int(floor(c.y)),0,_nz-1)
	var x1 := mini(x0+1,_nx-1)
	var z1 := mini(z0+1,_nz-1)
	var fx := clampf(c.x-x0,0.0,1.0)
	var fz := clampf(c.y-z0,0.0,1.0)
	var sum := 0.0
	var wsum := 0.0
	for e: Array in [[x0,z0,(1.0-fx)*(1.0-fz)],[x1,z0,fx*(1.0-fz)],[x0,z1,(1.0-fx)*fz],[x1,z1,fx*fz]]:
		var h := _height[int(e[1])*_nx+int(e[0])]
		if is_nan(h): continue
		sum += h*float(e[2])
		wsum += float(e[2])
	if wsum > 0.001: return sum/wsum
	# The nearest known cell, a few rings out.
	for r in range(1,5):
		for dz in range(-r,r+1):
			for dx in range(-r,r+1):
				var x := clampi(x0+dx,0,_nx-1)
				var z := clampi(z0+dz,0,_nz-1)
				var h := _height[z*_nx+x]
				if not is_nan(h): return h
	return 0.0

## Open turf at p: its cell and the cells round it within `room` m.
func open_at(p: Vector2, room := 1.5) -> bool:
	if _nx == 0 or not on_land(p): return false
	var c := _cell(p)
	var n := int(ceil(room/GRID))
	for dz in range(-n,n+1):
		for dx in range(-n,n+1):
			var x := int(round(c.x))+dx
			var z := int(round(c.y))+dz
			if x < 0 or z < 0 or x >= _nx or z >= _nz: return false
			if Vector2(dx,dz).length()*GRID > room+0.01: continue
			if _open[z*_nx+x] == 0: return false
	return true

## Bilinear over `grid`'s known cells at p, or null if none of the four is
## known (off the grid too).
func _known_at(grid: PackedFloat32Array, p: Vector2) -> Variant:
	if _nx == 0 or grid.size() != _nx*_nz: return null
	var c := _cell(p)
	if c.x < -0.5 or c.y < -0.5 or c.x > float(_nx)-0.5 or c.y > float(_nz)-0.5: return null
	var x0 := clampi(int(floor(c.x)),0,_nx-1)
	var z0 := clampi(int(floor(c.y)),0,_nz-1)
	var x1 := mini(x0+1,_nx-1)
	var z1 := mini(z0+1,_nz-1)
	var fx := clampf(c.x-x0,0.0,1.0)
	var fz := clampf(c.y-z0,0.0,1.0)
	var sum := 0.0
	var wsum := 0.0
	var w00 := (1.0-fx)*(1.0-fz)
	var w10 := fx*(1.0-fz)
	var w01 := (1.0-fx)*fz
	var w11 := fx*fz
	var h := grid[z0*_nx+x0]
	if not is_nan(h):
		sum += h*w00
		wsum += w00
	h = grid[z0*_nx+x1]
	if not is_nan(h):
		sum += h*w10
		wsum += w10
	h = grid[z1*_nx+x0]
	if not is_nan(h):
		sum += h*w01
		wsum += w01
	h = grid[z1*_nx+x1]
	if not is_nan(h):
		sum += h*w11
		wsum += w11
	if wsum <= 0.0001: return null
	return sum/wsum

## Its main turf's height over home.y at p, or null off it (round 8).
func turf_at(p: Vector2) -> Variant:
	return _known_at(_height,p)

## The top of anything solid at p over home.y, spread a cell either way, or
## null over open air (round 8).
func top_at(p: Vector2) -> Variant:
	return _known_at(_top,p)

## As top_at, but not spread: the solid top in the cells about p only (the
## dragon's head, which must not be lifted by a column a metre off).
func solid_at(p: Vector2) -> Variant:
	return _known_at(_top_raw,p)
