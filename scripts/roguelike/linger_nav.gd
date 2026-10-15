extends RefCounted
## Where the linger serpent's head can go on the isles (docs/design/roguelike/
## linger-serpent-round2.md): a grid of CELL m cells over the layer's isles,
## each the height of the first solid straight down there (the real
## colliders: terrain, kit, pillars, walls). Its body is some 10 m through,
## so it goes over low stone (a wall, a step, a terrace's lip) and round
## tall stone (a pillar, an arch, a thin high wall): a cell standing more
## than STEP_MAX over TALL_SIDES or more of its eight neighbours (a pillar's
## top, a thin wall's, an arch's span; not a slope's or a terrace's edge,
## which have lower ground on one side only) is solid. Cells by tall stone
## cost more (WALL_COST), so it keeps off pillars where there is room.
##
## Only the isles' own ground is its ground (the plan's occupancy): a
## bridge, a stepping stone or a viaduct is not, so between isles it goes
## down into the void and climbs the next.
##
## The isles stand over time (streamed in round him, or behind the loading
## screen), so the bake never quite stops: every frame BUDGET rays go to
## the isles nearest `near` (him) that have not settled (two whole passes
## with nothing new), and the cells they change are fitted again.
##
## Paths are Godot's AStarGrid2D over the cells (C++), asked only when the
## straight way is not clear (`clear_line`).
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")

const CELL := 3.0
const STEP_MAX := 5.0
const TALL_SIDES := 5
const WALL_COST := 2.5
## Rays a frame; isles further than BAKE_NEAR m from him wait.
const BUDGET := 220
const BAKE_NEAR := 220.0
const NONE := Vector2i(2147483647,2147483647)
const AROUND := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]

var space: PhysicsDirectSpaceState3D
var isles: Array = []
var exclude: Array[RID] = []
## Cell -> ground height (world y); missing = void or not yet stood.
var _h := {}
var _isle := {}
var _tall := {}
## By isle: its jobs [cell, ray top, ray bottom], where its pass is, its
## rect (world x, z), its passes with nothing new, whether it changed this
## pass, how many cells it has; its rim cells (a set).
var _jobs := {}
var _cursor := {}
var _rect := {}
var _quiet := {}
var _changed := {}
var _count := {}
var _rims := {}
var _dirty := {}
var _rays := 0
var _grid := AStarGrid2D.new()
var _ray := PhysicsRayQueryParameters3D.new()

func _init(physics: PhysicsDirectSpaceState3D, plan_isles: Array, skip: Array[RID]) -> void:
	space = physics
	isles = plan_isles
	exclude = skip
	_ray.collision_mask = 1
	_ray.exclude = exclude
	var all := Rect2i()
	var first := true
	for i in range(isles.size()):
		var isle: Dictionary = isles[i]
		if not isle.has("occ"): continue
		var r: Rect2 = LayerPlan._rect(isle)
		var span: Vector2 = LayerPlan._span(isle)
		var c0 := cell_of(Vector3(r.position.x,0.0,r.position.y))
		var c1 := cell_of(Vector3(r.end.x,0.0,r.end.y))
		var cr := Rect2i(c0,c1-c0+Vector2i.ONE)
		all = cr if first else all.merge(cr)
		first = false
		var jobs: Array = []
		for x in range(c0.x,c1.x+1):
			for z in range(c0.y,c1.y+1):
				var c := Vector2i(x,z)
				var w := centre(c)
				if LayerPlan.occ_at(isle,w.x,w.z).x == INF: continue
				jobs.append([c,span.y+3.0,span.x-3.0])
		_jobs[i] = jobs
		_cursor[i] = 0
		_rect[i] = r
		_quiet[i] = 0
		_changed[i] = false
		_count[i] = 0
		_rims[i] = {}
	_grid.region = all.grow(2)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_grid.update()
	_grid.fill_solid_region(_grid.region,true)

## Any ground yet.
func ready() -> bool:
	return _h.size() > 0

## A frame's share of the bake, nearest `near` first; the cells it changed
## fitted again.
func bake_step(near: Vector3, budget := BUDGET) -> void:
	var order: Array = []
	for i: int in _jobs:
		if int(_quiet[i]) >= 2 or (_jobs[i] as Array).is_empty(): continue
		var d := _rect_dist(_rect[i],near)
		if d > BAKE_NEAR: continue
		order.append([d,i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var left := budget
	for o: Array in order:
		if left <= 0: break
		var i := int(o[1])
		var jobs: Array = _jobs[i]
		while left > 0:
			var k := int(_cursor[i])
			left -= 1
			_rays += 1
			_bake(jobs[k],i)
			k += 1
			if k >= jobs.size():
				_quiet[i] = 0 if bool(_changed[i]) or int(_count[i]) == 0 else int(_quiet[i])+1
				_changed[i] = false
				_cursor[i] = 0
				break
			_cursor[i] = k
	if not _dirty.is_empty(): _fit()

static func _rect_dist(r: Rect2, p: Vector3) -> float:
	var dx := maxf(maxf(r.position.x-p.x,p.x-r.end.x),0.0)
	var dz := maxf(maxf(r.position.y-p.z,p.z-r.end.y),0.0)
	return sqrt(dx*dx+dz*dz)

func _bake(job: Array, i: int) -> void:
	var c: Vector2i = job[0]
	var w := centre(c)
	_ray.from = Vector3(w.x,float(job[1]),w.z)
	_ray.to = Vector3(w.x,float(job[2]),w.z)
	var hit := space.intersect_ray(_ray)
	if hit.is_empty(): return
	var y := (hit.position as Vector3).y
	if _h.has(c) and absf(float(_h[c])-y) < 0.25: return
	if _h.has(c) and int(_isle[c]) != i and float(_h[c]) > y: return
	if not _h.has(c): _count[i] = int(_count[i])+1
	_h[c] = y
	_isle[c] = i
	_changed[i] = true
	_dirty[c] = true

## The changed cells and their neighbours: tall or not, solid or not,
## beside a wall, at a rim.
func _fit() -> void:
	var touch := {}
	for c: Vector2i in _dirty:
		touch[c] = true
		for d: Vector2i in AROUND: touch[c+d] = true
	_dirty.clear()
	for c: Vector2i in touch:
		if not _h.has(c): continue
		var h := float(_h[c])
		var lower := 0
		for d: Vector2i in AROUND:
			var n: Vector2i = c+d
			if _h.has(n) and h-float(_h[n]) > STEP_MAX: lower += 1
		if lower >= TALL_SIDES: _tall[c] = true
		else: _tall.erase(c)
	for c: Vector2i in touch:
		if not _h.has(c) or not _grid.is_in_boundsv(c): continue
		var i := int(_isle[c])
		var walk := not _tall.has(c)
		_grid.set_point_solid(c,not walk)
		var by_wall := false
		var rim := false
		for d: Vector2i in AROUND:
			if _tall.has(c+d): by_wall = true
			if not _h.has(c+d): rim = true
		_grid.set_point_weight_scale(c,1.0+(WALL_COST if by_wall else 0.0))
		var rims: Dictionary = _rims[i]
		if walk and rim: rims[c] = true
		else: rims.erase(c)

# --- Cells -------------------------------------------------------------------

func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x/CELL),floori(p.z/CELL))

func centre(c: Vector2i) -> Vector3:
	return Vector3((float(c.x)+0.5)*CELL,0.0,(float(c.y)+0.5)*CELL)

func walkable(c: Vector2i) -> bool:
	return _h.has(c) and not _tall.has(c)

func isle_of(c: Vector2i) -> int:
	return int(_isle.get(c,-1)) if walkable(c) else -1

## The ground under `p` (world y), smoothed over the cells round it (tall
## stone and void left out); NAN off its ground.
func height(p: Vector3) -> float:
	var fx := p.x/CELL-0.5
	var fz := p.z/CELL-0.5
	var x0 := floori(fx)
	var z0 := floori(fz)
	var tx := fx-float(x0)
	var tz := fz-float(z0)
	var sum := 0.0
	var wsum := 0.0
	for dx in range(2):
		for dz in range(2):
			var c := Vector2i(x0+dx,z0+dz)
			if not walkable(c): continue
			var w := (tx if dx == 1 else 1.0-tx)*(tz if dz == 1 else 1.0-tz)+1e-4
			sum += float(_h[c])*w
			wsum += w
	return sum/wsum if wsum > 0.0 else NAN

## The walkable cell nearest `p` within `reach` m (of isle `isle`, or any),
## or NONE.
func nearest(p: Vector3, reach := 12.0, isle := -1) -> Vector2i:
	var c := cell_of(p)
	if walkable(c) and (isle < 0 or isle_of(c) == isle): return c
	var best := NONE
	var bd := INF
	var r := ceili(reach/CELL)
	for dx in range(-r,r+1):
		for dz in range(-r,r+1):
			var n := c+Vector2i(dx,dz)
			if not walkable(n) or (isle >= 0 and isle_of(n) != isle): continue
			var d := Vector2(dx,dz).length_squared()
			if d < bd:
				bd = d
				best = n
	return best

func ground_point(c: Vector2i) -> Vector3:
	var w := centre(c)
	return Vector3(w.x,float(_h.get(c,0.0)),w.z)

## The isle's rim cell best for coming up from `from` toward `toward` (or
## going down from it); {at, out, cell}, or {}.
func rim(isle: int, from: Vector3, toward: Vector3, toward_share := 0.6) -> Dictionary:
	var rims: Dictionary = _rims.get(isle,{})
	var best := NONE
	var score := INF
	for c: Vector2i in rims:
		var w := centre(c)
		var s := Vector2(w.x-from.x,w.z-from.z).length()+Vector2(w.x-toward.x,w.z-toward.z).length()*toward_share
		if s < score:
			score = s
			best = c
	if best == NONE: return {}
	return {"at":ground_point(best),"out":out_of(best),"cell":best}

## The isle's rim cell to come up over from `from`: about `want` m from
## `him` (so it has the isle to cross to him), not far round from `from`.
func rim_off(isle: int, from: Vector3, him: Vector3, want: float) -> Dictionary:
	var rims: Dictionary = _rims.get(isle,{})
	var best := NONE
	var score := INF
	for c: Vector2i in rims:
		var w := centre(c)
		var dh := Vector2(w.x-him.x,w.z-him.z).length()
		var s := Vector2(w.x-from.x,w.z-from.z).length()*0.35+absf(dh-want)*1.5
		if s < score:
			score = s
			best = c
	if best == NONE: return {}
	return {"at":ground_point(best),"out":out_of(best),"cell":best}

func out_of(c: Vector2i) -> Vector3:
	var o := Vector3.ZERO
	for dx in range(-2,3):
		for dz in range(-2,3):
			if dx == 0 and dz == 0: continue
			if not _h.has(c+Vector2i(dx,dz)): o += Vector3(dx,0.0,dz).normalized()
	return o.normalized() if o.length() > 0.01 else Vector3.FORWARD

func clear_line(a: Vector3, b: Vector3) -> bool:
	var d := Vector2(b.x-a.x,b.z-a.z)
	var n := maxi(1,ceili(d.length()/(CELL*0.5)))
	var last := NAN
	for i in range(n+1):
		var p := a.lerp(b,float(i)/n)
		var c := cell_of(p)
		if not walkable(c): return false
		var h := float(_h[c])
		if not is_nan(last) and absf(h-last) > STEP_MAX: return false
		last = h
	return true

func path(a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var ca := nearest(a,6.0)
	var cb := nearest(b,9.0,isle_of(ca) if ca != NONE else -1)
	if ca == NONE or cb == NONE: return out
	var ids := _grid.get_id_path(ca,cb,true)
	for c: Vector2i in ids: out.append(ground_point(c))
	return out

func stats() -> Dictionary:
	var by := {}
	for c: Vector2i in _h:
		var i := int(_isle[c])
		if not by.has(i): by[i] = [0,0,0]
		by[i][0] += 1
		if _tall.has(c): by[i][1] += 1
	for i: int in _rims: if by.has(i): by[i][2] = (_rims[i] as Dictionary).size()
	return {"rays":_rays,"ground":_h.size(),"tall":_tall.size(),"by_isle":by,"quiet":_quiet}

func size() -> int:
	return _h.size()-_tall.size()
