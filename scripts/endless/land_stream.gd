extends Node3D
## The endless land, streamed in chunks round an eye (the plane's camera):
## a quadtree over the field (scripts/endless/land_field.gd), each chunk
## CELLS x CELLS quads whatever its size, so a chunk at level L is
## BASE*2^L m across. Near the eye a chunk splits into four while it is
## nearer than SPLIT times its size, so detail is full under the plane
## (1 m quads) and coarser ring by ring out to ROOT_REACH root chunks
## round it (the far horizon; the fog hides its edge).
##
## No cracks: every chunk hangs a skirt down from its four edges, deep
## enough to cover the step to a coarser neighbour, coloured as its edge.
## No holes while streaming: a chunk still building is covered by what was
## drawn there before (its parent, or its four children) until it stands.
##
## Off the main thread: each chunk's heights, normals and colours are made
## by a WorkerThreadPool task with its own field; the main thread only
## turns the finished arrays into a mesh, up to COMMIT_BUDGET ms a frame.
## Level-0 chunks within COLLIDE m of the eye get a HeightMapShape3D on
## LAYER, for the plane's wheels and whatever walks later.
##
## `stats` counts chunks asked for, built and committed, and the slowest
## commit, for a driver (scratch/) to log.

const Field = preload("res://scripts/endless/land_field.gd")

## Quads along a chunk's side, the finest chunk's size (m, so 1 m quads),
## the coarsest level and how many root chunks reach out each way.
const CELLS := 64
const BASE := 64.0
const TOP_LEVEL := 7
const ROOT_REACH := 1
## A chunk splits while the eye is nearer than SPLIT times its size.
const SPLIT := 1.3
## The tree is looked at again once the eye has moved REPLAN m.
const REPLAN := 6.0
## Tasks in flight at once (0: the cores less two, at least one, so the
## main and render threads keep a core).
const MAX_TASKS := 0
## Milliseconds a frame for meshes and colliders; at least one a frame.
const COMMIT_BUDGET := 2.5
## Level-0 chunks nearer the eye than this (m, to the chunk) collide.
const COLLIDE := 70.0
const LAYER := 1
## The skirt's depth: SKIRT quads of the chunk's own, plus SKIRT_MIN m.
const SKIRT := 6.0
const SKIRT_MIN := 4.0
## The river's flow (m/s) at the ends of CUSTOM0.zw's range.
const RIVER_FLOW_MAX := 4.0

var seed := 0
var field: RefCounted
var eye := Vector3.ZERO
var stats := {"asked":0,"built":0,"committed":0,"freed":0,"slowest_commit_ms":0.0,"slowest_build_ms":0.0,"build_ms":0.0}
## The chunks' material: round one's vertex colours, or the look's ground
## (scripts/endless/endless_look.gd) passed to `setup`.
var material: Material

var _chunks := {}          # key -> {node, heights, level, ix, iz}
var _pending := {}         # key -> true (a task is making it)
var _queue: Array = []     # keys wanted, not yet asked
var _done: Array = []      # finished task results
var _done_lock := Mutex.new()
var _tasks := {}           # task id -> key
var _wanted := {}          # the leaves wanted now
var _shown := {}           # keys drawn now
var _planned_at := Vector3.INF
var _indices := PackedInt32Array()
var _bodies := {}          # key -> StaticBody3D
var _quit := false

func setup(land_seed: int, ground: Material = null) -> void:
	seed = land_seed
	field = Field.new(seed)
	material = ground
	if material == null:
		var plain := StandardMaterial3D.new()
		plain.vertex_color_use_as_albedo = true
		plain.vertex_color_is_srgb = true
		plain.roughness = 1.0
		plain.metallic_specular = 0.08
		plain.cull_mode = BaseMaterial3D.CULL_DISABLED
		material = plain
	_indices = _grid_indices()

func _exit_tree() -> void:
	_quit = true
	for id: int in _tasks.keys(): WorkerThreadPool.wait_for_task_completion(id)
	_tasks.clear()

## Whether every leaf wanted round the eye now stands.
func settled() -> bool:
	if _planned_at == Vector3.INF: return false
	for key: Vector3i in _wanted.keys():
		if not _chunks.has(key): return false
	return true

## The land round `at` built before the first frame (a load, on every
## worker, the main thread waiting): returns the seconds it took.
func prime(at: Vector3) -> float:
	var began := Time.get_ticks_msec()
	step(at)
	while not settled():
		OS.delay_msec(4)
		step(at)
	return (Time.get_ticks_msec()-began)/1000.0

## Whether the ground under a world XZ point is drawn at full detail with
## its collider (the plane's wheels can stand there).
func solid_at(x: float, z: float) -> bool:
	return _bodies.has(Vector3i(0,floori(x/BASE),floori(z/BASE)))

## One frame: the tree replanned if the eye has moved, tasks asked, finished
## chunks turned into meshes within the budget, what is drawn swapped.
func step(at: Vector3) -> void:
	eye = at
	var t0 := Time.get_ticks_usec()
	if _planned_at == Vector3.INF or Vector2(at.x-_planned_at.x,at.z-_planned_at.z).length() > REPLAN or absf(at.y-_planned_at.y) > REPLAN:
		_plan()
	var t1 := Time.get_ticks_usec()
	_ask()
	var t2 := Time.get_ticks_usec()
	if _commit(): _show()
	var t3 := Time.get_ticks_usec()
	_collide()
	var t4 := Time.get_ticks_usec()
	_slowest("plan",t1-t0)
	_slowest("ask",t2-t1)
	_slowest("commit",t3-t2)
	_slowest("collide",t4-t3)
	_slowest("step",t4-t0)

func _slowest(what: String, usec: int) -> void:
	var key := "slowest_%s_ms" % what
	stats[key] = maxf(float(stats.get(key,0.0)),usec/1000.0)

# --- The tree -------------------------------------------------------------------------

static func size_of(level: int) -> float:
	return BASE*pow(2.0,level)

func _plan() -> void:
	_planned_at = eye
	_wanted.clear()
	var root := size_of(TOP_LEVEL)
	var cx := floori(eye.x/root)
	var cz := floori(eye.z/root)
	for dz in range(-ROOT_REACH,ROOT_REACH+1):
		for dx in range(-ROOT_REACH,ROOT_REACH+1):
			_split(TOP_LEVEL,cx+dx,cz+dz)
	_queue.clear()
	for key: Vector3i in _wanted.keys():
		if not _chunks.has(key) and not _pending.has(key): _queue.append(key)
	# Nearest first; at the start the coarse ones first, so the view fills.
	var first := _chunks.is_empty()
	_queue.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if first and a.x != b.x: return a.x > b.x
		return _distance(a) < _distance(b))
	_show()

func _split(level: int, ix: int, iz: int) -> void:
	var key := Vector3i(level,ix,iz)
	if level > 0 and _distance(key) < SPLIT*size_of(level):
		for c in 4: _split(level-1,ix*2+(c&1),iz*2+(c>>1))
	else:
		_wanted[key] = true

## The eye's distance to a chunk: across to its square, and up from the
## sea's height plus a little.
func _distance(key: Vector3i) -> float:
	var s := size_of(key.x)
	var x0 := key.y*s
	var z0 := key.z*s
	var dx := maxf(maxf(x0-eye.x,eye.x-(x0+s)),0.0)
	var dz := maxf(maxf(z0-eye.z,eye.z-(z0+s)),0.0)
	var dy := maxf(eye.y-(Field.SEA_Y+20.0),0.0)
	return sqrt(dx*dx+dy*dy+dz*dz)

func _ask() -> void:
	var most := MAX_TASKS if MAX_TASKS > 0 else maxi(OS.get_processor_count()-2,1)
	while _tasks.size() < most and not _queue.is_empty():
		var key: Vector3i = _queue.pop_front()
		if _chunks.has(key) or _pending.has(key) or not _wanted.has(key): continue
		_pending[key] = true
		stats.asked += 1
		var id := WorkerThreadPool.add_task(_build.bind(key,seed))
		_tasks[id] = key
	# Tasks done: their ids let go.
	for id: int in _tasks.keys():
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_tasks.erase(id)

# --- On a worker ----------------------------------------------------------------------

## A chunk's arrays, made from its own field: the (CELLS+1)^2 grid, then
## its skirt's four edges, with normals from a one-sample border.
func _build(key: Vector3i, land_seed: int) -> void:
	if _quit: return
	var began := Time.get_ticks_usec()
	var f: RefCounted = Field.new(land_seed)
	var s := size_of(key.x)
	var step := s/CELLS
	f.detail = step
	var x0 := key.y*s
	var z0 := key.z*s
	var n := CELLS+1
	var w := n+2
	var hs := PackedFloat32Array()
	var ms := PackedFloat32Array()
	var cv := PackedByteArray()
	# The river (land_field last_river_*): signed distance from its line,
	# water half-width, level and flow, per grid point.
	var rv := PackedFloat32Array()
	hs.resize(w*w)
	ms.resize(w*w)
	cv.resize(w*w*2)
	rv.resize(w*w*5)
	for j in w:
		for i in w:
			var got: Vector2 = f.sample(x0+(i-1)*step,z0+(j-1)*step)
			hs[j*w+i] = got.x
			ms[j*w+i] = got.y
			cv[(j*w+i)*2] = int(clampf(f.last_cavity,0.0,1.0)*255.0)
			cv[(j*w+i)*2+1] = int(clampf(f.last_ridge,0.0,1.0)*255.0)
			var q := (j*w+i)*5
			rv[q] = clampf(f.last_river_r,-1000.0,1000.0)
			rv[q+1] = f.last_river_w
			rv[q+2] = f.last_river_y if f.last_river_y > -INF else Field.SEA_Y-100.0
			rv[q+3] = f.last_river_flow.x
			rv[q+4] = f.last_river_flow.y
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var carved := PackedByteArray()
	var river := PackedFloat32Array()
	var heights := PackedFloat32Array()
	verts.resize(n*n+4*n)
	normals.resize(n*n+4*n)
	colours.resize(n*n+4*n)
	carved.resize((n*n+4*n)*4)
	river.resize((n*n+4*n)*3)
	heights.resize(n*n)
	for j in n:
		for i in n:
			var k := (j+1)*w+i+1
			var y := hs[k]
			var nx := hs[k-1]-hs[k+1]
			var nz := hs[k-w]-hs[k+w]
			var normal := Vector3(nx,2.0*step,nz).normalized()
			var v := j*n+i
			verts[v] = Vector3(i*step,y,j*step)
			normals[v] = normal
			# Its alpha the meadow, for the look's ground shader.
			var c: Color = f.colour(x0+i*step,z0+j*step,y,normal.y,ms[k])
			c.a = ms[k]
			colours[v] = c
			# The carve's groove and crest, for the rock (CUSTOM0.xy).
			carved[v*4] = cv[k*2]
			carved[v*4+1] = cv[k*2+1]
			# The flow for the water's ripples (CUSTOM0.zw, RIVER_FLOW_MAX m/s
			# at the ends), and the river (CUSTOM1, floats): its signed
			# distance, half-width (the skirt's negative, so the shader never
			# lifts it to the water) and level.
			carved[v*4+2] = int(clampf(rv[k*5+3]/RIVER_FLOW_MAX*0.5+0.5,0.0,1.0)*255.0)
			carved[v*4+3] = int(clampf(rv[k*5+4]/RIVER_FLOW_MAX*0.5+0.5,0.0,1.0)*255.0)
			river[v*3] = rv[k*5]
			river[v*3+1] = rv[k*5+1]
			river[v*3+2] = rv[k*5+2]
			heights[v] = y
	# The skirt: each edge's vertices again, dropped.
	var drop := step*SKIRT+SKIRT_MIN
	var edges := _edges()
	for e in 4:
		for t in n:
			var from: int = edges[e][t]
			var v := n*n+e*n+t
			verts[v] = verts[from]-Vector3(0.0,drop,0.0)
			normals[v] = normals[from]
			colours[v] = colours[from]
			carved[v*4] = carved[from*4]
			carved[v*4+1] = carved[from*4+1]
			carved[v*4+2] = carved[from*4+2]
			carved[v*4+3] = carved[from*4+3]
			river[v*3] = river[from*3]
			river[v*3+1] = -river[from*3+1]
			river[v*3+2] = river[from*3+2]
	var ms_took := (Time.get_ticks_usec()-began)/1000.0
	_done_lock.lock()
	_done.append({"key":key,"verts":verts,"normals":normals,"colours":colours,"carved":carved,"river":river,"heights":heights,"ms":ms_took})
	_done_lock.unlock()

## The grid's vertex index along each edge, in order: -z, +x, +z, -x.
static func _edges() -> Array:
	var n := CELLS+1
	var out := [[],[],[],[]]
	for t in n:
		out[0].append(t)
		out[1].append(t*n+CELLS)
		out[2].append(CELLS*n+t)
		out[3].append(t*n)
	return out

## The triangles every chunk shares: the grid's, then the skirt's.
static func _grid_indices() -> PackedInt32Array:
	var n := CELLS+1
	var out := PackedInt32Array()
	for j in CELLS:
		for i in CELLS:
			var a := j*n+i
			out.append_array([a,a+1,a+n,a+1,a+n+1,a+n])
	var edges := _edges()
	for e in 4:
		for t in CELLS:
			var a: int = edges[e][t]
			var b: int = edges[e][t+1]
			var sa := n*n+e*n+t
			out.append_array([a,b,sa,b,sa+1,sa])
	return out

# --- On the main thread ---------------------------------------------------------------

## Finished chunks into meshes within the budget; true if any stood.
func _commit() -> bool:
	_done_lock.lock()
	var ready := _done
	_done = []
	_done_lock.unlock()
	if ready.is_empty(): return false
	var began := Time.get_ticks_usec()
	var made := 0
	while not ready.is_empty():
		if made > 0 and (Time.get_ticks_usec()-began)/1000.0 > COMMIT_BUDGET: break
		var r: Dictionary = ready.pop_front()
		var key: Vector3i = r.key
		_pending.erase(key)
		stats.built += 1
		stats.build_ms += float(r.ms)
		stats.slowest_build_ms = maxf(stats.slowest_build_ms,float(r.ms))
		var t0 := Time.get_ticks_usec()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = r.verts
		arrays[Mesh.ARRAY_NORMAL] = r.normals
		arrays[Mesh.ARRAY_COLOR] = r.colours
		arrays[Mesh.ARRAY_CUSTOM0] = r.carved
		arrays[Mesh.ARRAY_CUSTOM1] = r.river
		arrays[Mesh.ARRAY_INDEX] = _indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},(Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
		mesh.surface_set_material(0,material)
		var node := MeshInstance3D.new()
		node.name = "Land_%d_%d_%d" % [key.x,key.y,key.z]
		node.mesh = mesh
		node.visible = false
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if key.x <= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s := size_of(key.x)
		node.position = Vector3(key.y*s,0.0,key.z*s)
		add_child(node)
		_chunks[key] = {"node":node,"heights":r.heights if key.x == 0 else PackedFloat32Array()}
		stats.committed += 1
		stats.slowest_commit_ms = maxf(stats.slowest_commit_ms,(Time.get_ticks_usec()-t0)/1000.0)
		made += 1
	if not ready.is_empty():
		_done_lock.lock()
		ready.append_array(_done)
		_done = ready
		_done_lock.unlock()
	return made > 0

## What is drawn: each wanted leaf if it stands, else what stands over or
## under it; chunks drawn nowhere and wanted nowhere freed.
func _show() -> void:
	var show := {}
	var root := size_of(TOP_LEVEL)
	var cx := floori(_planned_at.x/root)
	var cz := floori(_planned_at.z/root)
	for dz in range(-ROOT_REACH,ROOT_REACH+1):
		for dx in range(-ROOT_REACH,ROOT_REACH+1):
			var root_key := Vector3i(TOP_LEVEL,cx+dx,cz+dz)
			var got: Variant = _cover(root_key)
			# A root not yet covered whole (new at the far edge) draws what
			# of it stands.
			if got == null: got = _partial(root_key)
			for key: Vector3i in got: show[key] = true
	for key: Vector3i in _shown.keys():
		if not show.has(key) and _chunks.has(key): (_chunks[key].node as Node3D).visible = false
	for key: Vector3i in show.keys(): (_chunks[key].node as Node3D).visible = true
	_shown = show
	for key: Vector3i in _chunks.keys():
		if show.has(key) or _wanted.has(key): continue
		(_chunks[key].node as Node).queue_free()
		_chunks.erase(key)
		stats.freed += 1
		if _bodies.has(key):
			(_bodies[key] as Node).queue_free()
			_bodies.erase(key)

## The chunks that draw `key`'s square, or null if nothing standing can.
func _cover(key: Vector3i) -> Variant:
	if _wanted.has(key):
		if _chunks.has(key): return [key]
		return _under(key,2)
	if key.x == 0: return [key] if _chunks.has(key) else null
	var parts := []
	for c in 4:
		var got: Variant = _cover(Vector3i(key.x-1,key.y*2+(c&1),key.z*2+(c>>1)))
		if got == null:
			parts = []
			break
		parts.append_array(got)
	if not parts.is_empty(): return parts
	if _chunks.has(key): return [key]
	return null

## Whatever stands that draws part of `key`'s square, finest first.
func _partial(key: Vector3i) -> Array:
	var got: Variant = _cover(key)
	if got != null: return got
	# A wanted leaf (still building, nothing under it) stops the search.
	if key.x == 0 or _wanted.has(key): return []
	var parts := []
	for c in 4: parts.append_array(_partial(Vector3i(key.x-1,key.y*2+(c&1),key.z*2+(c>>1))))
	return parts

## Standing chunks under `key` that cover it whole, `depth` levels down.
func _under(key: Vector3i, depth: int) -> Variant:
	if key.x == 0 or depth == 0: return null
	var parts := []
	for c in 4:
		var child := Vector3i(key.x-1,key.y*2+(c&1),key.z*2+(c>>1))
		if _chunks.has(child): parts.append(child)
		else:
			var got: Variant = _under(child,depth-1)
			if got == null: return null
			parts.append_array(got)
	return parts

## Level-0 chunks near the eye collide; farther ones let go of it.
func _collide() -> void:
	for key: Vector3i in _bodies.keys():
		if _distance_flat(key) > COLLIDE*1.5 or not _chunks.has(key):
			(_bodies[key] as Node).queue_free()
			_bodies.erase(key)
	var x0 := floori((eye.x-COLLIDE)/BASE)
	var x1 := floori((eye.x+COLLIDE)/BASE)
	var z0 := floori((eye.z-COLLIDE)/BASE)
	var z1 := floori((eye.z+COLLIDE)/BASE)
	for iz in range(z0,z1+1):
		for ix in range(x0,x1+1):
			var key := Vector3i(0,ix,iz)
			if _bodies.has(key) or not _chunks.has(key) or _distance_flat(key) > COLLIDE: continue
			var shape := HeightMapShape3D.new()
			shape.map_width = CELLS+1
			shape.map_depth = CELLS+1
			shape.map_data = _chunks[key].heights
			var body := StaticBody3D.new()
			body.name = "Ground_%d_%d" % [ix,iz]
			body.collision_layer = LAYER
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			body.position = Vector3(ix*BASE+BASE*0.5,0.0,iz*BASE+BASE*0.5)
			add_child(body)
			_bodies[key] = body

func _distance_flat(key: Vector3i) -> float:
	var s := size_of(key.x)
	var dx := maxf(maxf(key.y*s-eye.x,eye.x-(key.y*s+s)),0.0)
	var dz := maxf(maxf(key.z*s-eye.z,eye.z-(key.z*s+s)),0.0)
	return sqrt(dx*dx+dz*dz)

## Chunks standing, drawn, wanted and in flight.
func counts() -> Dictionary:
	return {"standing":_chunks.size(),"drawn":_shown.size(),"wanted":_wanted.size(),"in_flight":_tasks.size(),"queued":_queue.size(),"colliders":_bodies.size()}
