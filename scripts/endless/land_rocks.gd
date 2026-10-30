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
const RockShape = preload("res://scripts/endless/rock_shape.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const REACH := 2600.0
## The Peak's cells (its spires, RockPlan ON_PEAK) stream within PEAK_REACH:
## the towers on its crest show from the start meadow, 4.5 km off.
const PEAK_REACH := 8000.0
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
## The cells that hold the Peak's spires ({Vector2i: true}), and whether
## they are the only cells wanted (no other kind on).
var peak_cells := {}
var _peak_only := false
## The Peak's hero towers (scripts/endless/rocks/peak_towers.gd), or null:
## their solid answers through these same calls.
var extra: Node3D
var material: Material
## The ground material with no turf (a spec's `bare`: the hoodoos' caps are
## stone, not lawn): rock_up past 1, so every face is the land's rock.
var bare: Material
## Levels of detail (off: --no-rock-lod, to compare).
var lod: bool = not "--no-rock-lod" in LaunchArgs.user_args()
var stats := {"cells":0,"groups":0,"pillars":0,"tris":0,"slowest_build_ms":0.0,"slowest_commit_ms":0.0,"slowest_body_ms":0.0}

var _cells := {}        # Vector2i -> Array of records (committed)
var _pending := {}      # Vector2i -> task id
var _done: Array = []
var _lock := Mutex.new()
var _queue: Array = []
var _planned_at := Vector3.INF
var _quit := false
var _eye := Vector3.ZERO
var _grid := {}         # Vector2i -> Array of [record, pillar index]
var _bodies: Array = []  # [node, shape] waiting for their collider
var _pad := Build.wingtip()

## `peak`: the land's massif (LandField `peak`), or null: the Peak's kinds
## are off without one.
func setup(land_seed: int, ground: Material = null, peak: RefCounted = null) -> void:
	seed = land_seed
	densities = Plan.flags()
	var peaked := false
	for k: String in Plan.ON_PEAK:
		if peak == null: densities[k] = 0.0
		elif float(densities.get(k,0.0)) > 0.0: peaked = true
	if peaked:
		for k: String in Plan.ON_PEAK:
			if float(densities.get(k,0.0)) > 0.0: peak_cells.merge((Plan.KINDS[k] as Script).call("cells",peak))
	on = Plan.any(densities)
	_peak_only = peaked
	for k: String in Plan.KINDS:
		if not k in Plan.ON_PEAK and float(densities.get(k,0.0)) > 0.0: _peak_only = false
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
	var densities := Plan.flags()
	if float(densities.get(kind,0.0)) <= 0.0: densities[kind] = 1.0
	var spec := Plan.nearest(field,at,kind,densities)
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
	var t0 := Time.get_ticks_usec()
	while not _done.is_empty(): _commit_one(_done.pop_back())
	_add_bodies(Time.get_ticks_usec())
	while not _bodies.is_empty(): _add_bodies(Time.get_ticks_usec())
	# The start's own commits are its load, not a frame's.
	stats.prime_ms = float(stats.get("prime_ms",0.0))+(Time.get_ticks_usec()-t0)/1000.0
	stats.slowest_commit_ms = 0.0
	stats.slowest_body_ms = 0.0

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
	if _add_bodies(began): return
	while true:
		_lock.lock()
		var next: Variant = _done.pop_front() if not _done.is_empty() else null
		_lock.unlock()
		if next == null: break
		_commit_one(next)
		if (Time.get_ticks_usec()-began)/1000.0 > COMMIT_BUDGET: break

## The colliders waiting, a pillar's trimesh at a time within half the
## frame's budget (at least one a frame); true when that left no time for
## a commit.
func _add_bodies(began: int) -> bool:
	while not _bodies.is_empty():
		var e: Array = _bodies[0]
		var body: StaticBody3D = e[0]
		var shapes: Array = e[1]
		var i := int(e[2])
		if not is_instance_valid(body) or body.is_queued_for_deletion() or i >= shapes.size():
			_bodies.pop_front()
			continue
		var t0 := Time.get_ticks_usec()
		var cs := CollisionShape3D.new()
		cs.shape = shapes[i]
		body.add_child(cs)
		e[2] = i+1
		stats.slowest_body_ms = maxf(stats.slowest_body_ms,(Time.get_ticks_usec()-t0)/1000.0)
		if (Time.get_ticks_usec()-began)/1000.0 > COMMIT_BUDGET*0.5: return true
	return false

## The cells within `reach` of `at` (the Peak's within PEAK_REACH when
## `reach` is REACH), the Peak's first, then nearest first.
func _wanted(at: Vector3, reach: float) -> Array:
	var out: Array = []
	if not _peak_only:
		var c := Plan.cell_of(at.x,at.z)
		var r := int(ceil(reach/Plan.CELL))+1
		for dz in range(-r,r+1):
			for dx in range(-r,r+1):
				var key := c+Vector2i(dx,dz)
				if _cell_distance(key,at) <= reach: out.append(key)
	var far := PEAK_REACH if reach >= REACH else reach
	for key: Vector2i in peak_cells:
		if not key in out and _cell_distance(key,at) <= far: out.append(key)
	# The Peak's few cells first (its towers show from far off), then by
	# distance.
	out.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		var pp := peak_cells.has(p)
		if pp != peak_cells.has(q): return pp
		return _cell_distance(p,at) < _cell_distance(q,at))
	return out

func _reach_of(key: Vector2i) -> float:
	return PEAK_REACH if peak_cells.has(key) else REACH

func _cell_distance(key: Vector2i, at: Vector3) -> float:
	return Vector2((key.x+0.5)*Plan.CELL-at.x,(key.y+0.5)*Plan.CELL-at.z).length()

func _plan(at: Vector3) -> void:
	_queue.clear()
	for key: Vector2i in _wanted(at,REACH):
		if not _cells.has(key) and not _pending.has(key): _queue.append(key)
	for key: Vector2i in _cells.keys():
		if _cell_distance(key,at) > _reach_of(key)+Plan.CELL: _free_cell(key)

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
		var shapes: Array = []
		for f: PackedVector3Array in b.faces:
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(f)
			shapes.append(shape)
		b["shapes"] = shapes
		built.append(b)
	return {"key":key,"groups":built,"ms":(Time.get_ticks_usec()-began)/1000.0}

func _commit_one(done: Dictionary) -> void:
	var key: Vector2i = done.key
	var t0 := Time.get_ticks_usec()
	stats.slowest_build_ms = maxf(stats.slowest_build_ms,float(done.ms))
	if _cells.has(key) or _cell_distance(key,_eye) > _reach_of(key)+Plan.CELL*2.0: return
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
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,b.arrays,[],b.lods if lod else {},RockShape.format(b.arrays))
		mesh.surface_set_material(0,bare if bool(spec.get("bare",false)) else material)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		node.add_child(mi)
		node.name = name.replace("/","_")
		node.transform = xf
		add_child(node)
		LayoutOverrides.track(name,node,"piece",coded)
		var rec := {"name":name,"kind":String(spec.kind),"node":node,"xf":xf,"inv":xf.affine_inverse(),"pos":xf.origin,"spec":spec,
			"solid":b.solid,"tris":b.tris,"grid":[]}
		_index(rec)
		records.append(rec)
		# Its collider a frame or more later (`_add_bodies`), so a big
		# group's trimesh and mesh don't land in one frame.
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = LAYER
		body.collision_mask = 0
		node.add_child(body)
		_bodies.append([body,b.shapes,0])
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

## How far inside pillar `s`'s ring `k`, grown by `pad`, local XZ `q` is
## (m; under 0 outside): the ring's reach that way less q's distance.
static func _in_ring(s: Dictionary, k: int, q: Vector2, pad: float) -> float:
	var c: PackedVector2Array = s.c
	var r: PackedFloat32Array = s.r
	var off := q-c[k]
	var sec := clampi(int(floor((off.angle()+PI)/TAU*Build.SECTORS)),0,Build.SECTORS-1)
	return r[k*Build.SECTORS+sec]+pad-off.length()

## Over the top ring at `q` (`g` inside it, `_in_ring`): its cap's height
## there over the ring, the dome less toward the rim.
static func _dome(s: Dictionary, q: Vector2, g: float) -> float:
	var last := int(s.rings)-1
	var dome := maxf(0.0,float(s.top)-(float(s.y0)+last*float(s.dy)))
	var c: PackedVector2Array = s.c
	return dome*clampf(g/maxf(0.01,g+q.distance_to(c[last])),0.0,1.0)

## The solid stretches over world XZ `p` (world y, low to high), from every
## pillar there, grown by `pad` m round (the wingtip's reach when not
## given; 0 for a point on the plane's own edge). The skin runs straight
## from ring to ring, as it is lofted, so a side's edge is where the
## distance inside crosses 0 between two rings.
func stretches(p: Vector3, pad := -1.0) -> Array:
	var out: Array = []
	if pad < 0.0: pad = _pad
	for e: Array in _near(p):
		var rec: Dictionary = e[0]
		var s: Dictionary = (rec.solid as Array)[int(e[1])]
		var l: Vector3 = (rec.inv as Transform3D)*p
		var q := Vector2(l.x,l.z)
		if q.distance_to(s.mid) > float(s.reach)+pad: continue
		var oy := (rec.xf as Transform3D).origin.y
		var y0 := float(s.y0)
		var dy := float(s.dy)
		var rings := int(s.rings)
		var g0 := _in_ring(s,0,q,pad)
		var from := y0 if g0 > 0.0 else -INF
		for k in range(1,rings):
			var g1 := _in_ring(s,k,q,pad)
			if (g0 > 0.0) != (g1 > 0.0):
				var y := y0+(k-1+g0/(g0-g1))*dy
				if g1 > 0.0: from = y
				else:
					out.append(Vector2(from+oy,y+oy))
					from = -INF
			g0 = g1
		if from != -INF: out.append(Vector2(from+oy,y0+(rings-1)*dy+_dome(s,q,g0)+oy))
	if extra != null: out.append_array(extra.stretches(p,pad))
	if out.size() > 1: out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out

## SkyGlide's `ground` at `p` over the land `h` (LandHalls `over`): a
## pillar raises it, an overhang over the plane is Vector2(top, underside).
## Grown by `pad` (as `stretches`).
func ground(p: Vector3, h: Variant, pad := -1.0) -> Variant:
	if not h is float: return h
	var list := stretches(p,pad)
	if list.is_empty(): return h
	return LandHalls.over(p,h,list)

## True inside a pillar's solid, grown by `pad` (as `stretches`; the camera
## keeps out, the wheels stop).
func inside(p: Vector3, pad := -1.0) -> bool:
	if pad < 0.0: pad = _pad
	for e: Array in _near(p):
		var rec: Dictionary = e[0]
		var s: Dictionary = (rec.solid as Array)[int(e[1])]
		var l: Vector3 = (rec.inv as Transform3D)*p
		if l.y < float(s.y0) or l.y > float(s.top): continue
		var q := Vector2(l.x,l.z)
		if q.distance_to(s.mid) > float(s.reach)+pad: continue
		var last := int(s.rings)-1
		var f := (l.y-float(s.y0))/float(s.dy)
		if f >= float(last):
			var g := _in_ring(s,last,q,pad)
			if g > 0.0 and l.y <= float(s.y0)+last*float(s.dy)+_dome(s,q,g): return true
			continue
		var k := int(floor(f))
		if lerpf(_in_ring(s,k,q,pad),_in_ring(s,k+1,q,pad),f-k) > 0.0: return true
	return extra != null and extra.inside(p,pad)

## The highest top (world y) of any pillar within `r` m of world XZ `p`
## (its reach grown by the wingtip), or -INF.
func top_near(p: Vector3, r: float) -> float:
	var best: float = -INF if extra == null else extra.top_near(p,r)
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
	return "rocks (%s): %d groups, %d pillars in %d cells, %dk tris at full detail  ·  slowest build %.0f ms on a worker, slowest commit %.2f ms (collider %.2f), the start's %.0f ms" % [
		", ".join(kinds),int(stats.groups),int(stats.pillars),int(stats.cells),int(stats.tris)/1000,float(stats.slowest_build_ms),float(stats.slowest_commit_ms),float(stats.slowest_body_ms),float(stats.get("prime_ms",0.0))]
