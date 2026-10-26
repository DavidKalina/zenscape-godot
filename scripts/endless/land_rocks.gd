extends Node3D
## The endless land's free-standing rock shapes (docs/design/endless-flight/
## rock-shapes-handoff.md): every kind in scripts/endless/rocks/rock_plan.gd
## KINDS (sea stacks, hoodoos), streamed round the eye as the arches are
## (scripts/endless/land_arches.gd): each world cell's groups are planned (a
## pure function of the seed) and built by a WorkerThreadPool task
## (scripts/endless/rocks/rock_build.gd) when the cell comes within REACH
## m, committed on the main thread within COMMIT_BUDGET ms a frame, and
## freed past REACH+CELL.
##
## The flight's solid, for every kind at once: each pillar keeps its rings'
## centres and radii (rock_build.gd `solid`), found through a world grid of
## GRID m. `stretches(p)` gives the solid's y stretches over a point (each
## pillar grown by the plane's wingtip), `ground(p, h)` answers SkyGlide's
## `ground` with them (LandHalls `over`: a pillar raises the land, a cap's
## overhang is an underside), `inside(p)` is for the camera, its sight line
## and the rolling wheels, and `top_near(p, r)` is the highest top within r
## (the rival's look ahead). The colliders (layer 1) are what the near
## misses' wing rays and the wheels meet.
##
## Each group is named `endless/rock/<kind>/<cx>_<cz>/<i>` and placed
## through scripts/layout_overrides.gd: a move in the layout file wins (its
## yaw and place; the solid follows it), a group it lists as deleted is not
## built.

const Field = preload("res://scripts/endless/land_field.gd")
const Plan = preload("res://scripts/endless/rocks/rock_plan.gd")
const Build = preload("res://scripts/endless/rocks/rock_build.gd")
const LandHalls = preload("res://scripts/endless/land_halls.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const REACH := 2600.0
const NEAR := 900.0
const REPLAN := 40.0
const TASKS := 2
const COMMIT_BUDGET := 1.5
const LAYER := 1
## The solid's lookup grid (m).
const GRID := 32.0

var seed := 1
## Each kind's density and the forced ones (RockPlan `flags`).
var densities := {}
var on := false
var material: Material
## The ground material with no turf (a spec's `bare`: the hoodoos' caps are
## stone, not lawn): rock_up past 1, so every face is the land's rock.
var bare: Material
## Levels of detail (off: --no-rock-lod, to compare).
var lod: bool = not "--no-rock-lod" in LaunchArgs.user_args()
var stats := {"cells":0,"groups":0,"pillars":0,"tris":0,"slowest_build_ms":0.0,"slowest_commit_ms":0.0}

var _cells := {}        # Vector2i -> Array of records (committed)
var _pending := {}      # Vector2i -> task id
var _done: Array = []
var _lock := Mutex.new()
var _queue: Array = []
var _planned_at := Vector3.INF
var _quit := false
var _eye := Vector3.ZERO
var _grid := {}         # Vector2i -> Array of [record, pillar index]
var _pad := Build.wingtip()

func setup(land_seed: int, ground: Material = null) -> void:
	seed = land_seed
	densities = Plan.flags()
	on = Plan.any(densities)
	material = ground
	if material == null:
		var plain := StandardMaterial3D.new()
		plain.vertex_color_use_as_albedo = true
		plain.vertex_color_is_srgb = true
		plain.roughness = 1.0
		material = plain
	bare = material
	if material is ShaderMaterial:
		bare = (material as ShaderMaterial).duplicate()
		(bare as ShaderMaterial).set_shader_parameter("rock_up",1.2)
		(bare as ShaderMaterial).set_shader_parameter("thin_up",1.3)

## Where --rock-start=<kind> puts the plane: {at, heading (deg), alt, spec},
## by the nearest group of that kind to `at`, or {}.
static func start_pose(field: RefCounted, at: Vector2) -> Dictionary:
	var kind := Plan.start_wanted()
	if kind == "": return {}
	if not Plan.KINDS.has(kind):
		push_warning("--rock-start: one of %s" % str(Plan.KINDS.keys()))
		return {}
	var spec := Plan.nearest(field,at,kind,Plan.flags())
	if spec.is_empty():
		push_warning("--rock-start=%s: none near the start" % kind)
		return {}
	var a: Dictionary = spec.approach
	return {"at":a.at,"heading":float(a.heading),"alt":float(a.alt),"spec":spec}

func _exit_tree() -> void:
	_quit = true
	for id: int in _pending.values(): WorkerThreadPool.wait_for_task_completion(id)

## Builds the cells within NEAR of `at` now, on this thread.
func prime(at: Vector3) -> void:
	if not on: return
	_eye = at
	var field := Field.new(seed)
	for key: Vector2i in _wanted(at,NEAR):
		if _cells.has(key): continue
		_done.append(_build_cell(key,field))
	_planned_at = Vector3.INF
	while not _done.is_empty(): _commit_one(_done.pop_back())

func step(at: Vector3) -> void:
	if not on: return
	_eye = at
	if _planned_at == Vector3.INF or Vector2(at.x-_planned_at.x,at.z-_planned_at.z).length() > REPLAN:
		_planned_at = at
		_plan(at)
	for key: Vector2i in _pending.keys():
		var id: int = _pending[key]
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_pending.erase(key)
	while _pending.size() < TASKS and not _queue.is_empty():
		var key: Vector2i = _queue.pop_front()
		if _cells.has(key) or _pending.has(key): continue
		_pending[key] = WorkerThreadPool.add_task(_task.bind(key))
	var began := Time.get_ticks_usec()
	while true:
		_lock.lock()
		var next: Variant = _done.pop_front() if not _done.is_empty() else null
		_lock.unlock()
		if next == null: break
		_commit_one(next)
		if (Time.get_ticks_usec()-began)/1000.0 > COMMIT_BUDGET: break

func _wanted(at: Vector3, reach: float) -> Array:
	var out: Array = []
	var c := Plan.cell_of(at.x,at.z)
	var r := int(ceil(reach/Plan.CELL))+1
	for dz in range(-r,r+1):
		for dx in range(-r,r+1):
			var key := c+Vector2i(dx,dz)
			if _cell_distance(key,at) <= reach: out.append(key)
	out.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return _cell_distance(p,at) < _cell_distance(q,at))
	return out

func _cell_distance(key: Vector2i, at: Vector3) -> float:
	return Vector2((key.x+0.5)*Plan.CELL-at.x,(key.y+0.5)*Plan.CELL-at.z).length()

func _plan(at: Vector3) -> void:
	_queue.clear()
	for key: Vector2i in _wanted(at,REACH):
		if not _cells.has(key) and not _pending.has(key): _queue.append(key)
	for key: Vector2i in _cells.keys():
		if _cell_distance(key,at) > REACH+Plan.CELL: _free_cell(key)

func _task(key: Vector2i) -> void:
	if _quit: return
	var result := _build_cell(key,Field.new(seed))
	_lock.lock()
	_done.append(result)
	_lock.unlock()

## A cell's groups built: {key, groups: [built...], ms}.
func _build_cell(key: Vector2i, field: RefCounted) -> Dictionary:
	var began := Time.get_ticks_usec()
	var built: Array = []
	for spec: Dictionary in Plan.plan(field,key.x,key.y,densities):
		var b := Build.build(spec)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(b.faces)
		b["shape"] = shape
		built.append(b)
	return {"key":key,"groups":built,"ms":(Time.get_ticks_usec()-began)/1000.0}

func _commit_one(done: Dictionary) -> void:
	var key: Vector2i = done.key
	var t0 := Time.get_ticks_usec()
	stats.slowest_build_ms = maxf(stats.slowest_build_ms,float(done.ms))
	if _cells.has(key) or _cell_distance(key,_eye) > REACH+Plan.CELL*2.0: return
	var records: Array = []
	for b: Dictionary in done.groups:
		var spec: Dictionary = b.spec
		var name := String(spec.name)
		if LayoutOverrides.deleted(name): continue
		var coded := Transform3D(Basis.IDENTITY,spec.pos)
		var xf := LayoutOverrides.xform(name,coded)
		var yaw := atan2(-xf.basis.x.z,xf.basis.x.x)
		xf = Transform3D(Basis(Vector3.UP,yaw),xf.origin)
		var node := Node3D.new()
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,b.arrays,[],b.lods if lod else {})
		mesh.surface_set_material(0,bare if bool(spec.get("bare",false)) else material)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		node.add_child(mi)
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = LAYER
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = b.shape
		body.add_child(cs)
		node.add_child(body)
		node.name = name.replace("/","_")
		node.transform = xf
		add_child(node)
		LayoutOverrides.track(name,node,"piece",coded)
		var rec := {"name":name,"kind":String(spec.kind),"node":node,"xf":xf,"inv":xf.affine_inverse(),"pos":xf.origin,"spec":spec,
			"solid":b.solid,"tris":b.tris,"grid":[]}
		_index(rec)
		records.append(rec)
		stats.groups += 1
		stats.pillars += (b.solid as Array).size()
		stats.tris += int(b.tris[0])
	_cells[key] = records
	stats.cells = _cells.size()
	stats.slowest_commit_ms = maxf(stats.slowest_commit_ms,(Time.get_ticks_usec()-t0)/1000.0)

## A record's pillars into the grid.
func _index(rec: Dictionary) -> void:
	var xf: Transform3D = rec.xf
	var solid: Array = rec.solid
	for i in range(solid.size()):
		var s: Dictionary = solid[i]
		var mid: Vector2 = s.mid
		var w := xf*Vector3(mid.x,0.0,mid.y)
		var r := float(s.reach)+_pad
		var a := Vector2i(floori((w.x-r)/GRID),floori((w.z-r)/GRID))
		var b := Vector2i(floori((w.x+r)/GRID),floori((w.z+r)/GRID))
		for gz in range(a.y,b.y+1):
			for gx in range(a.x,b.x+1):
				var g := Vector2i(gx,gz)
				if not _grid.has(g): _grid[g] = []
				(_grid[g] as Array).append([rec,i])
				(rec.grid as Array).append(g)

func _free_cell(key: Vector2i) -> void:
	for r: Dictionary in _cells[key]:
		LayoutOverrides.entries.erase(r.name)
		for g: Vector2i in r.grid:
			var list: Variant = _grid.get(g)
			if list == null: continue
			var kept: Array = []
			for e: Array in list:
				if e[0] != r: kept.append(e)
			if kept.is_empty(): _grid.erase(g)
			else: _grid[g] = kept
		(r.node as Node).queue_free()
		stats.groups -= 1
		stats.pillars -= (r.solid as Array).size()
		stats.tris -= int(r.tris[0])
	_cells.erase(key)
	stats.cells = _cells.size()

## Every group standing now: [{name, kind, pos, spec, solid, ...}].
func standing() -> Array:
	var out: Array = []
	for key in _cells: out.append_array(_cells[key])
	return out

## The pillars standing near world XZ `p`: [[record, index]...] (each once).
func _near(p: Vector3) -> Array:
	if _grid.is_empty(): return []
	var list: Variant = _grid.get(Vector2i(floori(p.x/GRID),floori(p.z/GRID)))
	return [] if list == null else list

# --- The flight's solid -----------------------------------------------------

## Whether pillar `s`'s band `i` (between rings i and i+1; the last ring
## for its cap) holds local XZ `q`, grown by `pad`.
static func _band(s: Dictionary, i: int, q: Vector2, pad: float) -> bool:
	var c: PackedVector2Array = s.c
	var r: PackedFloat32Array = s.r
	var last := int(s.rings)-1
	for k: int in [mini(i,last),mini(i+1,last)]:
		var off := q-c[k]
		var d := off.length()
		var sec := clampi(int(floor((off.angle()+PI)/TAU*Build.SECTORS)),0,Build.SECTORS-1)
		if d <= r[k*Build.SECTORS+sec]+pad: return true
	return false

## The solid stretches over world XZ `p` (world y, low to high), from every
## pillar there, grown by the plane's wingtip.
func stretches(p: Vector3) -> Array:
	var out: Array = []
	for e: Array in _near(p):
		var rec: Dictionary = e[0]
		var s: Dictionary = (rec.solid as Array)[int(e[1])]
		var l: Vector3 = (rec.inv as Transform3D)*p
		var q := Vector2(l.x,l.z)
		if q.distance_to(s.mid) > float(s.reach)+_pad: continue
		var oy := (rec.xf as Transform3D).origin.y
		var y0 := float(s.y0)
		var dy := float(s.dy)
		var bands := int(s.rings)
		var from := -INF
		for i in range(bands):
			var lo := y0+i*dy
			var hi := float(s.top) if i == bands-1 else lo+dy
			if _band(s,i,q,_pad):
				if from == -INF: from = lo
				if i == bands-1: out.append(Vector2(from+oy,hi+oy))
			elif from != -INF:
				out.append(Vector2(from+oy,lo+oy))
				from = -INF
	if out.size() > 1: out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out

## SkyGlide's `ground` at `p` over the land `h` (LandHalls `over`): a
## pillar raises it, an overhang over the plane is Vector2(top, underside).
func ground(p: Vector3, h: Variant) -> Variant:
	if not h is float: return h
	var list := stretches(p)
	if list.is_empty(): return h
	return LandHalls.over(p,h,list)

## True inside a pillar's solid (grown by the wingtip): the camera keeps
## out, the wheels stop.
func inside(p: Vector3) -> bool:
	for e: Array in _near(p):
		var rec: Dictionary = e[0]
		var s: Dictionary = (rec.solid as Array)[int(e[1])]
		var l: Vector3 = (rec.inv as Transform3D)*p
		if l.y < float(s.y0) or l.y > float(s.top): continue
		var q := Vector2(l.x,l.z)
		if q.distance_to(s.mid) > float(s.reach)+_pad: continue
		var i := mini(int(floor((l.y-float(s.y0))/float(s.dy))),int(s.rings)-1)
		if _band(s,i,q,_pad): return true
	return false

## The highest top (world y) of any pillar within `r` m of world XZ `p`
## (its reach grown by the wingtip), or -INF.
func top_near(p: Vector3, r: float) -> float:
	var best := -INF
	if _grid.is_empty(): return best
	var a := Vector2i(floori((p.x-r)/GRID),floori((p.z-r)/GRID))
	var b := Vector2i(floori((p.x+r)/GRID),floori((p.z+r)/GRID))
	for gz in range(a.y,b.y+1):
		for gx in range(a.x,b.x+1):
			var list: Variant = _grid.get(Vector2i(gx,gz))
			if list == null: continue
			for e: Array in list:
				var rec: Dictionary = e[0]
				var s: Dictionary = (rec.solid as Array)[int(e[1])]
				var top := float(s.top)+(rec.xf as Transform3D).origin.y
				if top <= best: continue
				var mid: Vector2 = s.mid
				var w := (rec.xf as Transform3D)*Vector3(mid.x,0.0,mid.y)
				if Vector2(w.x-p.x,w.z-p.z).length() <= float(s.reach)+_pad+r: best = top
	return best

## The F1 numbers' line.
func note() -> String:
	var kinds: Array = []
	for k: String in Plan.KINDS:
		if float(densities.get(k,0.0)) > 0.0: kinds.append("%s %.1f" % [k,float(densities[k])])
	return "rocks (%s): %d groups, %d pillars in %d cells, %dk tris at full detail  ·  slowest build %.0f ms on a worker, slowest commit %.2f ms" % [
		", ".join(kinds),int(stats.groups),int(stats.pillars),int(stats.cells),int(stats.tris)/1000,float(stats.slowest_build_ms),float(stats.slowest_commit_ms)]
