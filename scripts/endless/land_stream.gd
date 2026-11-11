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
const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const RockShape = preload("res://scripts/endless/rock_shape.gd")
const ChunkNative = preload("res://scripts/endless/chunk_native.gd")

## Quads along a chunk's side, the finest chunk's size (m, so 1 m quads),
## the coarsest level and how many root chunks reach out each way.
const CELLS := 64
const BASE := 64.0
const TOP_LEVEL := 7
const ROOT_REACH := 1
## The draw distance: --view=K (VIEW_RANGE) draws the haze's end
## (EndlessLook FOG_END), the camera's far plane, the far trees (LandTrees
## FAR), the clouds' march (EndlessClouds REACH) and the land's roots K
## times as far. A discrete GPU off the Mac (high_end) draws HIGH_VIEW as
## far by default: about 0.5 to 1 ms on an RTX 4070 Super at 1440p
## (docs/design/endless-flight/aa-view-handoff.md).
const VIEW_RANGE := Vector2(0.5,2.5)
const HIGH_VIEW := 2.0
static func view() -> float:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--view="): return clampf(float(a.get_slice("=",1)),VIEW_RANGE.x,VIEW_RANGE.y)
	return HIGH_VIEW if high_end() else 1.0

## A discrete GPU, not a Mac's: the draw distance and SMAA (EndlessLook
## _frame_trades) go up by default; --high-end=0 leaves them as before.
static func high_end() -> bool:
	if "--high-end=0" in preload("res://scripts/launch_args.gd").user_args(): return false
	return OS.get_name() != "macOS" and RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
## A chunk splits while the eye is nearer than SPLIT times its size.
const SPLIT := 1.3
## The tree is looked at again once the eye has moved REPLAN m.
const REPLAN := 6.0
## Tasks in flight at once (0: the cores less two, at least one, so the
## main and render threads keep a core).
const MAX_TASKS := 0
## `--land-tasks=N` for a run (stutter hunt: many chunk builds at once crowd
## the main thread's GDScript).
static var _max_tasks := -1
static func max_tasks() -> int:
	if _max_tasks < 0:
		_max_tasks = MAX_TASKS
		for a: String in preload("res://scripts/launch_args.gd").user_args():
			if a.begins_with("--land-tasks="): _max_tasks = maxi(int(a.get_slice("=",1)),0)
	return _max_tasks
## Milliseconds a frame for meshes and colliders; at least one a frame.
const COMMIT_BUDGET := 2.5
## The tree is planned round a point led ahead of the eye along the
## flight (`lead_with`): LEAD_TIME s of its level velocity, at most
## LEAD_MOST m, so the detail ahead is asked for before the plane gets
## there (endless flight's boost covers a level-0 chunk in under 1.5 s).
## The eye's own ground stays full detail (a level-0 leaf reaches 83 m round
## the planned point and more); the colliders stay round the eye.
## --land-lead=S sets LEAD_TIME (0 off).
const LEAD_TIME := 0.9
const LEAD_MOST := 48.0
## Level-0 chunks nearer the eye than this (m, to the chunk) collide.
const COLLIDE := 70.0
## How many level-0 chunks may be in flight as high priority tasks (`_ask`).
const NEAR_TASKS := 4
const LAYER := 1
## The skirt's depth: SKIRT quads of the chunk's own, plus SKIRT_MIN m.
const SKIRT := 6.0
const SKIRT_MIN := 4.0
## The river's flow (m/s) at the ends of CUSTOM0.zw's range.
const RIVER_FLOW_MAX := 4.0
## Unless --river-live=0 (docs/design/endless-flight/river-live-handoff.md), each
## chunk also carries the river's channel frame in CUSTOM2 (RGBA float):
## xy the channel's direction down the flow (across the signed distance's
## gradient, turned to the flow), z its curvature signed so that the side
## of positive distance is the bend's outside where it is positive (the
## divergence of the distance's unit gradient, 1/m), w the water's width
## change per metre down the flow; only with the look's ground (`setup`'s
## material). Off, the chunks are as before.
static func river_live_wanted() -> bool:
	return not "--river-live=0" in preload("res://scripts/launch_args.gd").user_args()

var seed := 0
var field: RefCounted
var eye := Vector3.ZERO
## The lead off the eye the tree is planned round (`lead_with`), and its
## seconds of flight.
var lead := Vector3.ZERO
var lead_time := LEAD_TIME
var stats := {"asked":0,"built":0,"committed":0,"freed":0,"slowest_commit_ms":0.0,"slowest_build_ms":0.0,"build_ms":0.0}
## The chunks' material: round one's vertex colours, or the look's ground
## (scripts/endless/endless_look.gd) passed to `setup`.
var material: Material

## ROOT_REACH, or more under --view (view()).
var root_reach := ROOT_REACH
## Whether chunks carry the channel frame (river_live_wanted()).
var river_live := false
## --crest-cut=0: the Peak's chunks keep the grid's one diagonal (_crest_cut).
var crest_cut := not "--crest-cut=0" in preload("res://scripts/launch_args.gd").user_args()
var _chunks := {}          # key -> {node, heights, faces, tops}
var _pending := {}         # key -> true (a task is making it)
var _queue: Array = []     # keys wanted, not yet asked
var _done: Array = []      # finished task results
var _done_lock := Mutex.new()
var _tasks := {}           # task id -> key
var _high := {}            # task ids asked as high priority
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
	root_reach = maxi(ROOT_REACH,ceili(ROOT_REACH*view()))
	river_live = river_live_wanted() and ground != null
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--land-lead="): lead_time = maxf(0.0,float(a.get_slice("=",1)))
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

## The lead from the flight's velocity (m/s): LEAD_TIME s of its level
## part, at most LEAD_MOST m. Before `step`.
func lead_with(velocity: Vector3) -> void:
	lead = Vector3(velocity.x,0.0,velocity.z)*lead_time
	if lead.length() > LEAD_MOST: lead = lead.normalized()*LEAD_MOST

## The point the tree is planned round: the eye, led ahead.
func centre() -> Vector3:
	return eye+lead

## One frame: the tree replanned if the eye has moved, tasks asked, finished
## chunks turned into meshes within the budget, what is drawn swapped.
func step(at: Vector3) -> void:
	eye = at
	var t0 := Time.get_ticks_usec()
	var c := centre()
	if _planned_at == Vector3.INF or Vector2(c.x-_planned_at.x,c.z-_planned_at.z).length() > REPLAN or absf(c.y-_planned_at.y) > REPLAN:
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
	_planned_at = centre()
	_wanted.clear()
	var root := size_of(TOP_LEVEL)
	var cx := floori(_planned_at.x/root)
	var cz := floori(_planned_at.z/root)
	for dz in range(-root_reach,root_reach+1):
		for dx in range(-root_reach,root_reach+1):
			_split(TOP_LEVEL,cx+dx,cz+dz)
	_queue.clear()
	for key: Vector3i in _wanted.keys():
		if not _chunks.has(key) and not _pending.has(key): _queue.append(key)
	# Nearest first; at the start the coarse ones first, so the view fills.
	var first := _chunks.is_empty()
	_queue.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if first and a.x != b.x: return a.x > b.x
		return _distance(a) < _distance(b))
	if StreamLog.on:
		for key: Vector3i in _queue: StreamLog.want(&"land",key,_distance_flat(key))
		StreamLog.keep(&"land",_wanted,_pending)
	_show()

func _split(level: int, ix: int, iz: int) -> void:
	var key := Vector3i(level,ix,iz)
	if level > 0 and _distance(key) < SPLIT*size_of(level):
		for c in 4: _split(level-1,ix*2+(c&1),iz*2+(c>>1))
	else:
		_wanted[key] = true

## The planned point's distance to a chunk (the eye's, led ahead): across
## to its square, and up from its ground (`_top`), never from below the
## sea's height plus a little, so high land (a plateau, a wall) gets full
## detail and colliders when the eye is near it.
func _distance(key: Vector3i) -> float:
	var at := _planned_at if _planned_at != Vector3.INF else centre()
	var s := size_of(key.x)
	var x0 := key.y*s
	var z0 := key.z*s
	var dx := maxf(maxf(x0-at.x,at.x-(x0+s)),0.0)
	var dz := maxf(maxf(z0-at.z,at.z-(z0+s)),0.0)
	var dy := maxf(at.y-maxf(Field.SEA_Y+20.0,_top(key)),0.0)
	return sqrt(dx*dx+dy*dy+dz*dz)

## A chunk's ground for `_distance`: the highest of its heights once it has
## been built; else read off a built ancestor's heights at that ancestor's
## spacing (`_tops_of`, TOPS_DEPTH levels down) or raised to the highest of
## the built chunks under it; else that of its nearest known ancestor (an
## upper bound, so never less detail than the eye's height asks); else none
## (-INF: the sea's). Kept after the chunks are freed; past TOPS_MOST keys
## it starts again from the chunks standing.
const TOPS_DEPTH := 2
const TOPS_MOST := 32768
var _tops := {}            # key -> highest ground (m)
var _tops_own := {}        # keys whose top came from their own build
func _top(key: Vector3i) -> float:
	var k := key
	while k.x <= TOP_LEVEL:
		var got: Variant = _tops.get(k)
		if got != null: return got
		k = Vector3i(k.x+1,k.y>>1,k.z>>1)
	return -INF

func _keep_tops(key: Vector3i, tops: Dictionary) -> void:
	if _tops.size() > TOPS_MOST:
		_tops.clear()
		_tops_own.clear()
		for k: Vector3i in _chunks.keys(): _add_tops(k,_chunks[k].tops)
	_add_tops(key,tops)

func _add_tops(key: Vector3i, tops: Dictionary) -> void:
	if not tops.has(key): return
	for k: Vector3i in tops.keys():
		if k == key or not _tops_own.has(k): _tops[k] = tops[k]
	_tops_own[key] = true
	var top: float = tops[key]
	var a := Vector3i(key.x+1,key.y>>1,key.z>>1)
	while a.x <= TOP_LEVEL:
		if not _tops_own.has(a) and float(_tops.get(a,-INF)) < top: _tops[a] = top
		a = Vector3i(a.x+1,a.y>>1,a.z>>1)

## On the worker: the highest height of a chunk and of its descendants down
## to TOPS_DEPTH levels (each block's samples, edges included), as
## {key: top}.
static func _tops_of(key: Vector3i, heights: PackedFloat32Array) -> Dictionary:
	var out := {}
	var n := CELLS+1
	if heights.size() < n*n: return out
	var depth := mini(TOPS_DEPTH,key.x)
	var parts := 1 << depth
	var cell := CELLS >> depth
	# The finest blocks first, from the samples.
	var fine := PackedFloat32Array()
	fine.resize(parts*parts)
	for bj in parts:
		for bi in parts:
			var top := -INF
			for j in range(bj*cell,bj*cell+cell+1):
				for i in range(bi*cell,bi*cell+cell+1): top = maxf(top,heights[j*n+i])
			fine[bj*parts+bi] = top
	# Then up, a level at a time, each block the highest of its four.
	var level := key.x-depth
	var size := parts
	var tops := fine
	while true:
		for bj in size:
			for bi in size:
				out[Vector3i(level,key.y*size+bi,key.z*size+bj)] = tops[bj*size+bi]
		if size == 1: break
		var up := PackedFloat32Array()
		var half := size >> 1
		up.resize(half*half)
		for bj in half:
			for bi in half:
				up[bj*half+bi] = maxf(maxf(tops[2*bj*size+2*bi],tops[2*bj*size+2*bi+1]),maxf(tops[(2*bj+1)*size+2*bi],tops[(2*bj+1)*size+2*bi+1]))
		tops = up
		size = half
		level += 1
	return out

func _ask() -> void:
	var most := max_tasks() if max_tasks() > 0 else maxi(OS.get_processor_count()-2,1)
	# The colliders' chunks (level 0) go as high priority tasks, at most
	# NEAR_TASKS at once, and wait in the queue for a slot: low priority
	# tasks share a few of the pool's threads (threading/worker_pool/
	# low_priority_thread_ratio) with the grass, rocks and trees, and a level-0
	# chunk asked there waited seconds near the Peak; more high ones at once
	# keep the engine's own tasks waiting (frames stall).
	var held: Array = []
	while _tasks.size() < most and not _queue.is_empty():
		var key: Vector3i = _queue.pop_front()
		if _chunks.has(key) or _pending.has(key) or not _wanted.has(key): continue
		var high := key.x == 0
		if high and _high.size() >= NEAR_TASKS:
			held.append(key)
			continue
		_pending[key] = true
		stats.asked += 1
		var id := WorkerThreadPool.add_task(_build.bind(key,seed),high)
		_tasks[id] = key
		if high: _high[id] = true
		if StreamLog.on: StreamLog.ask(&"land",key)
	if not held.is_empty(): _queue = held+_queue
	# Tasks done: their ids let go.
	for id: int in _tasks.keys():
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_tasks.erase(id)
			_high.erase(id)

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
	# The whole chunk in one call (LandField.build_chunk: native when built,
	# else the same loops in GDScript).
	var made: Dictionary = f.build_chunk(x0,z0,step,CELLS,step*SKIRT+SKIRT_MIN,RIVER_FLOW_MAX)
	if river_live: made.frame = _river_frame(f,made,x0,z0,step)
	if RockShape.wanted:
		# The rock's shape (RockShape, CUSTOM3), where the chunk has rock.
		var shape := RockShape.grid(f,made,x0,z0,step,CELLS)
		if not shape.is_empty(): made.shape = shape
	_wall_normals(made)
	_portal_holes(f,made,key,x0,z0,step)
	# A placed curtain's cave mouths: its faces' triangles over them dropped
	# (LandField.curtain_cut).
	if f.has_method("curtain_cut"): f.curtain_cut(made,x0,z0,step,CELLS,made.indices if made.has("indices") else _indices,key.x == 0)
	_crest_cut(f,made,key,x0,z0,s)
	made.tops =_tops_of(key,made.get("heights",PackedFloat32Array()))
	made.key = key
	made.ms = (Time.get_ticks_usec()-began)/1000.0
	made.ended = Time.get_ticks_usec()
	_done_lock.lock()
	_done.append(made)
	_done_lock.unlock()

## The walls' drawn normals. A sheer drop between two grid samples stands as
## a near-vertical strip, and a wall running across the grid is a staircase
## of them: each vertex's normal (central differences) faces +x, +z or the
## diagonal by which neighbour sits over the drop, so the wall shaded column
## by column with saw edges. Where the slope's tangent passes WALL_FROM, each
## vertex keeps its own steepness (its normal's y) and turns its bearing
## toward the gradient averaged over a 5x5 binomial window (WALL_FROM to
## WALL_FULL blends it in); an edge vertex averages along its edge only and a
## corner keeps its own, so neighbouring chunks agree. Drawn normals only:
## made.normals has already given the colours and RockShape their input, and
## nothing past here reads it but the mesh. --wall-normals=0 off.
const WALL_FROM := 1.5
const WALL_FULL := 4.0
static var wall_normals := "--wall-normals=0" not in preload("res://scripts/launch_args.gd").user_args()
static var _wall_warned := false

static func _wall_normals(made: Dictionary) -> void:
	if not wall_normals: return
	var pk: Object = ChunkNative.pass_kernel()
	if pk != null and pk.has_method("wall_normals"):
		pk.wall_normals(made,CELLS,WALL_FROM,WALL_FULL)
		return
	if pk != null and not _wall_warned:
		_wall_warned = true
		push_warning("native terrain kernels predate wall_normals: walls' normals in GDScript (rebuild the kernels, tools/build_native_kernels.py)")
	_wall_normals_gd(made,CELLS,WALL_FROM,WALL_FULL)

## `_wall_normals` in GDScript: the reference (chunk_pass_bind.h wall_normals).
static func _wall_normals_gd(made: Dictionary, cells: int, from: float, full: float) -> void:
	var nm: PackedVector3Array = made.normals
	var n := cells+1
	var gx := PackedFloat64Array()
	var gz := PackedFloat64Array()
	var mag := PackedFloat64Array()
	gx.resize(n*n)
	gz.resize(n*n)
	mag.resize(n*n)
	var any := false
	for v in n*n:
		var q: Vector3 = nm[v]
		var a := float(q.x)/float(q.y)
		var b := float(q.z)/float(q.y)
		gx[v] = a
		gz[v] = b
		mag[v] = sqrt(a*a+b*b)
		if mag[v] > from: any = true
	if not any: return
	var wt := [1.0,4.0,6.0,4.0,1.0]
	var out := nm.duplicate()
	for j in n:
		for i in n:
			var v := j*n+i
			var s := mag[v]
			if s <= from: continue
			var on_i := i == 0 or i == cells
			var on_j := j == 0 or j == cells
			if on_i and on_j: continue
			var sx := 0.0
			var sz := 0.0
			for dj in range(-2,3):
				var jj := j+dj
				if jj < 0 or jj > cells: continue
				if on_j and dj != 0: continue
				for di in range(-2,3):
					var ii := i+di
					if ii < 0 or ii > cells: continue
					if on_i and di != 0: continue
					var w: float = wt[dj+2]*wt[di+2]
					sx += w*gx[jj*n+ii]
					sz += w*gz[jj*n+ii]
			var gl := sqrt(sx*sx+sz*sz)
			if gl < 1e-9: continue
			var t := clampf((s-from)/(full-from),0.0,1.0)
			t = t*t*(3.0-2.0*t)
			var ux := gx[v]/s
			var uz := gz[v]/s
			var dx := ux+(sx/gl-ux)*t
			var dz := uz+(sz/gl-uz)*t
			var dl := sqrt(dx*dx+dz*dz)
			if dl < 1e-6: continue
			var ax := dx/dl*s
			var az := dz/dl*s
			var l := sqrt(ax*ax+1.0+az*az)
			out[v] = Vector3(ax/l,1.0/l,az/l)
	# The skirt: its edge's normals.
	for e in 4:
		for t in n:
			var from_v: int = t if e == 0 else (t*n+cells if e == 1 else (cells*n+t if e == 2 else t*n))
			out[n*n+e*n+t] = out[from_v]
	made.normals = out

## The channel frame for CUSTOM2 (see river_live_wanted), from the chunk's
## river distance and width (CUSTOM1) and a two-sample ring round it read
## from the field, so the differences are central everywhere and match the
## neighbouring chunks'. Zeros where no river is near.
static func _river_frame(f: RefCounted, made: Dictionary, x0: float, z0: float, step: float) -> PackedFloat32Array:
	var pk: Object = ChunkNative.pass_kernel()
	if pk == null: return _river_frame_gd(f,made,x0,z0,step)
	var n := CELLS+1
	if not pk.river_near(made.river,n*n):
		var frame := PackedFloat32Array()
		frame.resize((n*n+4*n)*4)
		return frame
	var rr := PackedFloat32Array()
	var ww := PackedFloat32Array()
	var plain := ChunkNative.plain_in(f,x0-2.0*step,z0-2.0*step,x0+(n+1)*step,z0+(n+1)*step)
	if not plain.is_empty():
		var got: Array = pk.river_ring(plain[0],plain[1],plain[2],plain[3],x0,z0,step,CELLS)
		rr = got[0]
		ww = got[1]
	else:
		# The ring through LandField (its layers), in river_ring's order.
		var m := n+4
		for j in m:
			for i in m:
				if i >= 2 and i < n+2 and j >= 2 and j < n+2: continue
				f.sample(x0+(i-2)*step,z0+(j-2)*step)
				rr.append(clampf(float(f.last_river_r),-1000.0,1000.0))
				ww.append(float(f.last_river_w))
	return pk.river_frame(made,rr,ww,step,CELLS)

## `_river_frame` in GDScript: the reference.
static func _river_frame_gd(f: RefCounted, made: Dictionary, x0: float, z0: float, step: float) -> PackedFloat32Array:
	var n := CELLS+1
	var frame := PackedFloat32Array()
	frame.resize((n*n+4*n)*4)
	var river: PackedFloat32Array = made.river
	var carved: PackedByteArray = made.carved
	var near := false
	for v in n*n:
		if river[v*3+1] > 0.05 and absf(river[v*3]) < river[v*3+1]+40.0:
			near = true
			break
	if not near: return frame
	var m := n+4
	var rs := PackedFloat32Array()
	var ws := PackedFloat32Array()
	rs.resize(m*m)
	ws.resize(m*m)
	for j in m:
		for i in m:
			var k := j*m+i
			if i >= 2 and i < n+2 and j >= 2 and j < n+2:
				var v := (j-2)*n+i-2
				rs[k] = river[v*3]
				ws[k] = river[v*3+1]
			else:
				f.sample(x0+(i-2)*step,z0+(j-2)*step)
				rs[k] = clampf(float(f.last_river_r),-1000.0,1000.0)
				ws[k] = float(f.last_river_w)
	# The distance's unit gradient over the grid and a one-sample ring.
	var nx := PackedFloat32Array()
	var nz := PackedFloat32Array()
	nx.resize(m*m)
	nz.resize(m*m)
	for j in range(1,m-1):
		for i in range(1,m-1):
			var k := j*m+i
			var g := Vector2(rs[k+1]-rs[k-1],rs[k+m]-rs[k-m])
			if g.length_squared() > 1e-12:
				g = g.normalized()
				nx[k] = g.x
				nz[k] = g.y
	var h2 := 1.0/(2.0*step)
	for j in n:
		for i in n:
			var v := j*n+i
			if river[v*3+1] <= 0.05 or absf(river[v*3]) > river[v*3+1]+40.0: continue
			var k := (j+2)*m+i+2
			var t := Vector2(-nz[k],nx[k])
			var flow := Vector2(carved[v*4+2]/255.0*2.0-1.0,carved[v*4+3]/255.0*2.0-1.0)
			if t.dot(flow) < 0.0: t = -t
			var bend := ((nx[k+1]-nx[k-1])+(nz[k+m]-nz[k-m]))*h2
			var widen := Vector2(ws[k+1]-ws[k-1],ws[k+m]-ws[k-m])*h2
			frame[v*4] = t.x
			frame[v*4+1] = t.y
			frame[v*4+2] = clampf(bend,-0.2,0.2)
			frame[v*4+3] = clampf(widen.dot(t),-1.0,1.0)
	# The skirt: its edge's frame.
	var edges := _edges()
	for e in 4:
		for t in n:
			var from: int = edges[e][t]
			var v := n*n+e*n+t
			for c in 4: frame[v*4+c] = frame[from*4+c]
	return frame

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

## A mountain tunnel's mouths (tunnel_sites.gd, portals): a chunk under a
## portal's footprint gets its own triangles, without those wholly on it
## (the plug of rock the heightmap leaves in the mouth; the portal's block
## hides the hole's edge), and a level-0 chunk keeps them as its collider's
## faces (chunk-local), since a HeightMapShape3D has no holes.
static func _portal_holes(f: RefCounted, made: Dictionary, key: Vector3i, x0: float, z0: float, step: float) -> void:
	if not f.has_method("tunnels_in"): return
	var ts: Array = f.tunnels_in(x0,z0,x0+step*CELLS,z0+step*CELLS)
	var mask := PackedByteArray()
	if not ts.is_empty():
		_lift_skirts(made,ts,x0,z0)
		mask = Tunnels.portal_mask(ts,x0,z0,step,CELLS)
	# The ice tunnel's mouths, its gully and its window (PeakTunnel `hole_mask`).
	var ice: Variant = f.get("ice_tunnel")
	if ice != null:
		var got: PackedByteArray = ice.hole_mask(made.verts,x0,z0,step,CELLS)
		if mask.is_empty(): mask = got
		elif not got.is_empty():
			for i in mask.size(): mask[i] = mask[i] | got[i]
	if mask.is_empty(): return
	var pk: Object = ChunkNative.pass_kernel()
	if pk != null:
		pk.portal_tris(made,mask,CELLS,key.x == 0)
		return
	var n := CELLS+1
	var out := PackedInt32Array()
	var verts: PackedVector3Array = made.verts
	var faces := PackedVector3Array()
	for j in CELLS:
		for i in CELLS:
			var a := j*n+i
			for tri: Array in [[a,a+1,a+n],[a+1,a+n+1,a+n]]:
				if mask[tri[0]] != 0 and mask[tri[1]] != 0 and mask[tri[2]] != 0: continue
				out.append_array(PackedInt32Array(tri))
				if key.x == 0: faces.append_array([verts[tri[0]],verts[tri[1]],verts[tri[2]]])
	# The skirts too: a chunk's edge across a mouth hung a curtain in it.
	var grid := _grid_indices()
	var skirts := grid.slice(CELLS*CELLS*6)
	var k := 0
	while k < skirts.size():
		if not (_on_mask(mask,skirts[k]) and _on_mask(mask,skirts[k+1]) and _on_mask(mask,skirts[k+2])):
			out.append_array(skirts.slice(k,k+3))
		k += 3
	made.indices = out
	if key.x == 0: made.faces = faces

## The skirts over a sunk cave drawn up out of its bore (Tunnels `skirt_floor`).
static func _lift_skirts(made: Dictionary, ts: Array, x0: float, z0: float) -> void:
	var any := false
	for t: RefCounted in ts: any = any or t.sunk
	if not any: return
	var n := CELLS+1
	var verts: PackedVector3Array = made.verts
	for v in range(n*n,verts.size()):
		var p := verts[v]
		var e := (v-n*n)/n
		var t := (v-n*n)%n
		var from: int = [t,t*n+CELLS,CELLS*n+t,t*n][e]
		# A chunk's vertices are its own: the sites stand in the world.
		var low := Tunnels.skirt_floor(ts,x0+p.x,z0+p.z)
		if low > p.y: verts[v] = Vector3(p.x,minf(low,verts[from].y),p.z)
	made.verts = verts

## Whether grid or skirt vertex `v` stands on `mask` (a skirt's, as the edge
## vertex it hangs from: tunnel_sites.gd `apply_chunk`'s order).
static func _on_mask(mask: PackedByteArray, v: int) -> bool:
	var n := CELLS+1
	if v < n*n: return mask[v] != 0
	var e := (v-n*n)/n
	var t := (v-n*n)%n
	var from: int = [t,t*n+CELLS,CELLS*n+t,t*n][e]
	return mask[from] != 0

## Over the Peak the shadow-casting chunks past the first (levels 1, 2) cut
## each quad along its nearer heights, not the grid's one diagonal: a crest
## running against that diagonal stood as a row of teeth, and the sun's shadow
## drew them long over the ice. The same vertices; the draw only (a chunk's
## collider keeps the field). --crest-cut=0 off.
func _crest_cut(f: RefCounted, made: Dictionary, key: Vector3i, x0: float, z0: float, s: float) -> void:
	if key.x < 1 or key.x > 2 or made.has("indices") or not crest_cut: return
	var pk: RefCounted = f.peak()
	if pk == null or not pk.meets(x0,z0,x0+s,z0+s): return
	var v: PackedVector3Array = made.verts
	var n := CELLS+1
	var out := _indices.duplicate()
	var w := 0
	for j in CELLS:
		for i in CELLS:
			var a := j*n+i
			if absf(v[a].y-v[a+n+1].y) < absf(v[a+1].y-v[a+n].y):
				out[w+2] = a+n+1
				out[w+3] = a
				out[w+4] = a+n+1
				out[w+5] = a+n
			w += 6
	made.indices = out

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
		if StreamLog.on: StreamLog.built(&"land",key,float(r.ms),int(r.ended))
		var tops: Dictionary = r.get("tops",{})
		_keep_tops(key,tops)
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
		arrays[Mesh.ARRAY_INDEX] = r.get("indices",_indices)
		var format := (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		if r.has("frame"):
			arrays[Mesh.ARRAY_CUSTOM2] = r.frame
			format |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
		if r.has("shape"):
			arrays[Mesh.ARRAY_CUSTOM3] = r.shape
			format |= Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},format)
		mesh.surface_set_material(0,material)
		var node := MeshInstance3D.new()
		node.name = "Land_%d_%d_%d" % [key.x,key.y,key.z]
		node.mesh = mesh
		node.visible = false
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if key.x <= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s := size_of(key.x)
		node.position = Vector3(key.y*s,0.0,key.z*s)
		add_child(node)
		_chunks[key] = {"node":node,"heights":r.heights if key.x == 0 else PackedFloat32Array(),"faces":r.get("faces",PackedVector3Array()),"tops":tops}
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
	for dz in range(-root_reach,root_reach+1):
		for dx in range(-root_reach,root_reach+1):
			var root_key := Vector3i(TOP_LEVEL,cx+dx,cz+dz)
			var got: Variant = _cover(root_key)
			# A root not yet covered whole (new at the far edge) draws what
			# of it stands.
			if got == null: got = _partial(root_key)
			for key: Vector3i in got: show[key] = true
	for key: Vector3i in _shown.keys():
		if not show.has(key) and _chunks.has(key): (_chunks[key].node as Node3D).visible = false
	for key: Vector3i in show.keys():
		(_chunks[key].node as Node3D).visible = true
		if StreamLog.on and not _shown.has(key): StreamLog.show(&"land",key,key.x,_distance_flat(key))
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
			var faces: PackedVector3Array = _chunks[key].faces
			var shape: Shape3D
			if faces.is_empty():
				var hm := HeightMapShape3D.new()
				hm.map_width = CELLS+1
				hm.map_depth = CELLS+1
				hm.map_data = _chunks[key].heights
				shape = hm
			else:
				# Holed at a tunnel's mouth: the triangles that stand.
				var cp := ConcavePolygonShape3D.new()
				cp.set_faces(faces)
				cp.backface_collision = true
				shape = cp
			var body := StaticBody3D.new()
			body.name = "Ground_%d_%d" % [ix,iz]
			body.collision_layer = LAYER
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			body.position = Vector3(ix*BASE+BASE*0.5,0.0,iz*BASE+BASE*0.5) if faces.is_empty() else Vector3(ix*BASE,0.0,iz*BASE)
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
