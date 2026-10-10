extends Node3D
## The Sundered hall rising out of the cloud sea in a few big chunks, one
## after another, each whole (docs/design/hall-rise.md; the plan, its
## chunks and timing: scripts/hall_rise_plan.gd). Stand it at the hall's
## entry (the moments set piece's own metres: the entry at 0, flying north),
## tell it where the cloud top is (`sea_y`, in its own frame), `setup`, then
## `play` and `advance` it every physics frame.
##
## Made on a worker (`setup` starts it): the chunks one at a time, in the
## order they rise, each handed over as soon as it is made. Playing never
## waits for the whole build: a chunk due to rise before it is made holds
## the schedule (the chunks already rising go on) until it is; `stall` says
## how long it held. With `upfront` and `cost` (s) the build is made slow on
## purpose, to see how a real build (the kit's, seconds long) sits under it.
##
## A chunk rises straight up from under the cloud top, steady, eases to a
## stop just over its place and sinks into it (RisePlan.height_at). While it
## moves it collides with nothing; once still it goes on the ruins' layer
## (scripts/ruin_bump.gd LAYER), where the plane bumps off it, unless the
## plane is touching one of its solids then (`plane_box`), in which case it
## waits till the plane is clear: the plane is never shut inside stone.
##
## The cloud is greybox: the sea swells where a chunk is about to break
## through (`swells`, for the sea's shader), a ring of cloud bursts round it
## as it punches through, and cloud streams off its sides and wall tops as
## it clears the top.

const RisePlan = preload("res://scripts/hall_rise_plan.gd")
const SkyMoments = preload("res://scripts/sky_moments.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const GRID := preload("res://shaders/hall_rise_grid.gdshader")
const PUFF := preload("res://shaders/hall_rise_puff.gdshader")

## The in-world hall's greybox tints (scripts/sky_moments.gd TINTS), and the
## additions'.
const TINTS := {"box":Color(0.55,0.57,0.6),"cyl":Color(0.6,0.58,0.55),"keel":Color(0.42,0.4,0.39),"stone":Color(0.5,0.49,0.47)}
## Cloud: the most puffs at once; the burst as a chunk breaks through (most
## puffs round its rim); the streaming off it (puffs a second while its foot
## is within STREAM_UP m over the cloud top, the share of its speed they
## start with); the cap of cloud on its wall tops as it breaks.
const PUFFS := 600
const BURST := 70
const STREAM_RATE := 40.0
const STREAM_UP := 5.0
const STREAM_CARRY := 0.55
const CAP := 24
## The sea's swell under a chunk about to break through: how high (m), and
## how far under the top (m) its top is when the swell begins.
const SWELL := 3.5
const SWELL_FROM := 14.0
## The most swells the sea's shader takes.
const SWELLS := 6
## A settled chunk waits for the plane to be this far (m) off its solids.
const PLANE_CLEAR := 0.6

signal finished
## Sunk back under the cloud (`sink`): every chunk hidden again.
signal sunk

## The cloud top, in this node's frame.
var sea_y := RisePlan.SEA
var opts := {}
## The plan (RisePlan.make): solids, chunks, length.
var plan := {}
var chunks: Array = []
## Each chunk's node once made (null till then), and what it is doing:
## "waiting" (not risen), "moving", "pending" (still, the plane touching
## it), "set" (still and solid).
var nodes: Array = []
var state: PackedStringArray = []
var began_at: PackedFloat32Array = []
var broke: PackedByteArray = []
var playing := false
## Seconds since play (chunks rising go on this) and the schedule's clock
## (held while a due chunk is not made yet), and how long it held.
var clock := 0.0
var sched := 0.0
var stall := 0.0
var done_at := -1.0
## The plane's box in this frame (Callable() -> AABB; a zero-size AABB for
## no plane).
var plane_box := Callable()
## The build: its task, the chunks made and not yet taken, how many taken,
## when it began and how long it took (usec; -1 running).
var _task := -1
var _mutex := Mutex.new()
var _made: Array = []
var built := 0
var _build_began := 0
var build_usec := -1
var _first_usec := -1
## The heaviest hand-over of one chunk on the main thread (usec: its mesh
## made, put under this node).
var take_usec := 0
## The heaviest one frame's hand-over (usec: every chunk taken that frame),
## all of this rise's hand-overs added up, and `setup` itself (planning
## and starting the worker).
var frame_take_usec := 0
var take_total_usec := 0
var setup_usec := 0
## The most chunks taken in one frame (0: every one made; a chain takes 1,
## so a hall's hand-over is spread over a few frames).
var take_per_frame := 0
## Sinking back into the cloud (`sink`): the rise reversed. `sink_clock` is
## seconds since it began, `gone` once every chunk is under again.
var sinking := false
var sink_clock := 0.0
var gone := false
var _sink_from := PackedFloat32Array()
var _materials := {}
## The puffs: positions, velocities, sizes, growth, ages and lives.
var _puffs: MultiMeshInstance3D
var _pp := PackedVector3Array()
var _pv := PackedVector3Array()
var _ps := PackedFloat32Array()
var _pg := PackedFloat32Array()
var _pa := PackedFloat32Array()
var _pl := PackedFloat32Array()
var _owed := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()

## The rise's options from the launch flags: --rise-speed=<m/s>,
## --chunk-gap=<s>, --rise-settle=<s>, --rise-over=<m>, --rise-ease=<m> (the
## slow-down), --rise-from=apse|gate, --keels, --stones, --build-upfront=<s>
## and --build-cost=<s> (a slow build on purpose: before the first chunk,
## and spread over them).
static func options(args: PackedStringArray) -> Dictionary:
	var out := {"from":"apse","keels":false,"stones":false,"upfront":0.0,"cost":0.0}
	for a: String in args:
		var v := a.get_slice("=",1)
		if a.begins_with("--rise-speed="): out.speed = maxf(0.5,float(v))
		elif a.begins_with("--chunk-gap="): out.gap = maxf(0.0,float(v))
		elif a.begins_with("--rise-settle="): out.settle = maxf(0.0,float(v))
		elif a.begins_with("--rise-over="): out.over = maxf(0.0,float(v))
		elif a.begins_with("--rise-ease="): out.ease_out = maxf(0.0,float(v))
		elif a.begins_with("--rise-from=") and v in ["apse","gate"]: out.from = v
		elif a == "--keels": out.keels = true
		elif a == "--stones": out.stones = true
		elif a.begins_with("--build-upfront="): out.upfront = maxf(0.0,float(v))
		elif a.begins_with("--build-cost="): out.cost = maxf(0.0,float(v))
	return out

func _init() -> void:
	name = "HallRise"
	_rng.seed = 99

func _exit_tree() -> void:
	_wait()

## Freed with chunks made but never taken (a chain's hall dropped before
## its build came in): free them too, they are under no node.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_wait()
		for item: Array in _made:
			if is_instance_valid(item[1]): (item[1] as Node).free()
		_made = []

func _wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

## Plans the chunks and starts making them on a worker. Puts nothing up.
## `given` may also hold a `template` (a RisePlan.make with the same from,
## keels and stones: the chunks are timed again from it, RisePlan.remake,
## not planned again) and `materials` (a dictionary shared between rises,
## so a chain's halls share their materials).
func setup(given := {}) -> void:
	var began := Time.get_ticks_usec()
	_wait()
	for n in nodes:
		if n != null: (n as Node).queue_free()
	opts = given.duplicate()
	opts.sea = sea_y
	if given.has("materials"): _materials = given.materials
	plan = RisePlan.remake(given.template,opts) if given.has("template") else RisePlan.make(opts)
	sinking = false
	gone = false
	chunks = plan.chunks
	var n := chunks.size()
	nodes = []
	nodes.resize(n)
	state = PackedStringArray()
	state.resize(n)
	state.fill("waiting")
	began_at = PackedFloat32Array()
	began_at.resize(n)
	broke = PackedByteArray()
	broke.resize(n)
	_owed = PackedFloat32Array()
	_owed.resize(n)
	for kind: String in TINTS: _material(kind)
	_make_clouds()
	built = 0
	_made = []
	build_usec = -1
	_first_usec = -1
	_build_began = Time.get_ticks_usec()
	_task = WorkerThreadPool.add_task(_build_all.bind(float(given.get("upfront",0.0)),float(given.get("cost",0.0))),true,"Hall rise chunks")
	setup_usec = Time.get_ticks_usec()-began

## From the start: every chunk back under the cloud, the clocks at 0.
func play() -> void:
	clock = 0.0
	sched = 0.0
	stall = 0.0
	done_at = -1.0
	playing = true
	sinking = false
	gone = false
	for i in range(chunks.size()):
		state[i] = "waiting"
		broke[i] = 0
		_owed[i] = 0.0
		if nodes[i] != null: _hide(i)
	_clear_clouds()

## Every chunk in its place and solid at once (no plane in the way).
func finish_now() -> void:
	flush()
	for i in range(chunks.size()):
		_place(i,home(i))
		(nodes[i] as Node3D).visible = true
		_solid(i,true)
		state[i] = "set"
	playing = false
	done_at = clock
	_clear_clouds()

## Waits for the build and takes every chunk made.
func flush() -> void:
	_wait()
	_take()

## True once every chunk is made and taken.
func all_built() -> bool:
	return built == chunks.size() and not chunks.is_empty()

## Chunk `i`'s place (this frame).
func home(i: int) -> Transform3D:
	return Transform3D(Basis.IDENTITY,chunks[i].pivot)

## Where chunk `c` stands `t` s after it began rising.
static func pose_at(c: Dictionary, t: float) -> Transform3D:
	var at: Vector3 = c.pivot
	at.y = RisePlan.height_at(c,t)
	return Transform3D(Basis.IDENTITY,at)

## One frame: the chunks made since taken, then the schedule, every chunk
## rising, the settled ones made solid when the plane is clear, the cloud.
func advance(delta: float) -> void:
	_take()
	if playing:
		clock += delta
		var due := _next_due()
		var next := sched+delta
		while due >= 0 and float(chunks[due].start) <= next:
			if nodes[due] == null:
				stall += next-maxf(sched,float(chunks[due].start))
				next = float(chunks[due].start)
				break
			_begin(due,clock-(next-float(chunks[due].start)))
			due = _next_due()
		sched = next
		for i in range(chunks.size()):
			if state[i] == "moving": _move(i,delta)
		if done_at < 0.0 and _all_set():
			done_at = clock
			playing = false
			finished.emit()
	if sinking: _sink_step(delta)
	for i in range(chunks.size()):
		if state[i] == "pending" and not plane_touches(i):
			_solid(i,true)
			state[i] = "set"
	_step_clouds(delta)

## Back down into the cloud: the rise reversed. Every chunk stops colliding
## at once (nothing sinking is ever solid, so it never shuts the plane in),
## and each goes down the way it came up, on the rise's own timing played
## backwards: the last to rise goes first, the first to rise last, each
## from where it is now. Done (`gone`, `sunk`) once all are under and
## hidden; a chunk never made just stays unmade.
func sink() -> void:
	if sinking or chunks.is_empty(): return
	playing = false
	sinking = true
	sink_clock = 0.0
	var length := float(plan.get("length",0.0))
	_sink_from = PackedFloat32Array()
	_sink_from.resize(chunks.size())
	for i in range(chunks.size()):
		var c: Dictionary = chunks[i]
		_solid(i,false)
		broke[i] = 0
		_owed[i] = 0.0
		if state[i] == "waiting" or nodes[i] == null:
			state[i] = "gone"
			continue
		# Its rise time now (the end of its settle if it is still), and the
		# sink's clock when the reversed rise reaches it.
		var now := minf(clock-float(began_at[i]),RisePlan.settles(c)-float(c.start)) if state[i] == "moving" else RisePlan.settles(c)-float(c.start)
		_sink_from[i] = now
		state[i] = "sinking"
	if _all_gone(): _sunk()

## How long the whole sink takes from the start (s), with every chunk still.
func sink_length() -> float:
	return float(plan.get("length",0.0))-float(chunks[0].start) if not chunks.is_empty() else 0.0

## Chunk `c`'s rise time `s` s into the sink, from rise time `from`: the
## rise played backwards from its end, held at `from` till it gets there.
func sink_time(c: Dictionary, s: float, from: float) -> float:
	return minf(from,float(plan.get("length",0.0))-s-float(c.start))

func _sink_step(delta: float) -> void:
	sink_clock += delta
	for i in range(chunks.size()):
		if state[i] != "sinking": continue
		var c: Dictionary = chunks[i]
		var t := sink_time(c,sink_clock,float(_sink_from[i]))
		if t <= 0.0:
			_hide(i)
			state[i] = "gone"
			continue
		var pose := pose_at(c,t)
		_place(i,pose)
		var lift: float = pose.origin.y-float(c.pivot.y)
		var top: float = float(c.hi.y)+lift
		var foot: float = float(c.lo.y)+lift
		# Cloud closing over it: off its sides as its foot goes under, a ring
		# as its top does.
		if foot < sea_y+STREAM_UP and top > sea_y: _stream(i,c,lift,2.0,delta)
		if broke[i] == 0 and top < sea_y:
			broke[i] = 1
			_burst(c,lift)
	if _all_gone(): _sunk()

func _all_gone() -> bool:
	for s in state:
		if s != "gone": return false
	return true

func _sunk() -> void:
	sinking = false
	gone = true
	sunk.emit()

## The index of the next chunk to rise (-1 none).
func _next_due() -> int:
	for i in range(chunks.size()):
		if state[i] == "waiting": return i
	return -1

func _all_set() -> bool:
	for s in state:
		if s != "set": return false
	return true

func _begin(i: int, at: float) -> void:
	state[i] = "moving"
	began_at[i] = at
	(nodes[i] as Node3D).visible = true
	_move(i,0.0)

func _move(i: int, dt: float) -> void:
	var c: Dictionary = chunks[i]
	var t := clock-float(began_at[i])
	var pose := pose_at(c,t)
	_place(i,pose)
	var lift: float = pose.origin.y-float(c.pivot.y)
	var top: float = float(c.hi.y)+lift
	var foot: float = float(c.lo.y)+lift
	if broke[i] == 0 and top > sea_y:
		broke[i] = 1
		_burst(c,lift)
	if broke[i] == 1 and foot < sea_y+STREAM_UP: _stream(i,c,lift,RisePlan.speed_at(c,t),dt)
	if t >= RisePlan.settles(c)-float(c.start):
		_place(i,home(i))
		state[i] = "pending"
		if not plane_touches(i):
			_solid(i,true)
			state[i] = "set"

func _place(i: int, pose: Transform3D) -> void:
	var node: Node3D = nodes[i]
	if node == null: return
	node.transform = pose
	var mesh := node.get_node_or_null(^"Mesh") as GeometryInstance3D
	if mesh != null and is_inside_tree():
		mesh.set_instance_shader_parameter(&"offset",global_transform.basis*(pose.origin-(chunks[i].pivot as Vector3)))

func _hide(i: int) -> void:
	var node: Node3D = nodes[i]
	node.visible = false
	_solid(i,false)
	_place(i,pose_at(chunks[i],0.0))

func _solid(i: int, on: bool) -> void:
	var node: Node3D = nodes[i]
	if node == null: return
	var body := node.get_node(^"Body") as StaticBody3D
	body.collision_layer = RuinBump.LAYER if on else 0

## Whether the plane touches (is within PLANE_CLEAR of) any of chunk `i`'s
## solids' boxes, in its place.
func plane_touches(i: int) -> bool:
	if not plane_box.is_valid(): return false
	var box: AABB = plane_box.call()
	if box.size == Vector3.ZERO: return false
	for b: AABB in chunks[i].boxes:
		if b.grow(PLANE_CLEAR).intersects(box): return true
	return false

# --- Making the chunks (worker) ------------------------------------------------------

func _material(kind: String) -> Material:
	if not _materials.has(kind):
		var m := ShaderMaterial.new()
		m.shader = GRID
		m.set_shader_parameter("tint",TINTS[kind])
		_materials[kind] = m
	return _materials[kind]

func _build_all(upfront: float, cost: float) -> void:
	if upfront > 0.0: OS.delay_usec(int(upfront*1e6))
	var weight := 0.0
	for c: Dictionary in chunks: weight += _weight(c)
	for i in range(chunks.size()):
		var began := Time.get_ticks_usec()
		var node := make_chunk(chunks[i],plan.solids)
		if cost > 0.0:
			var owed := int(cost*1e6*_weight(chunks[i])/weight)-(Time.get_ticks_usec()-began)
			if owed > 0: OS.delay_usec(owed)
		_mutex.lock()
		_made.append([i,node])
		_mutex.unlock()

static func _weight(c: Dictionary) -> float:
	return float(c.solids.size())+4.0*float(c.extra.size())

## Takes the chunks made so far: under this node, hidden, under the cloud.
func _take() -> void:
	_mutex.lock()
	var got := _made
	_made = []
	if take_per_frame > 0 and got.size() > take_per_frame:
		_made = got.slice(take_per_frame)
		got = got.slice(0,take_per_frame)
	_mutex.unlock()
	var frame := 0
	for item: Array in got:
		var i: int = item[0]
		var node: Node3D = item[1]
		nodes[i] = node
		var began := Time.get_ticks_usec()
		finish_mesh(node,_materials)
		add_child(node)
		var took := Time.get_ticks_usec()-began
		take_usec = maxi(take_usec,took)
		take_total_usec += took
		frame += took
		built += 1
		if _first_usec < 0: _first_usec = Time.get_ticks_usec()-_build_began
		if state[i] == "set":
			_place(i,home(i))
			_solid(i,true)
		else: _hide(i)
	frame_take_usec = maxi(frame_take_usec,frame)
	if built == chunks.size() and build_usec < 0 and not chunks.is_empty():
		build_usec = Time.get_ticks_usec()-_build_began

## Seconds from setup to the first chunk made, and to the last (-1 not yet).
func first_ready() -> float:
	return _first_usec/1e6 if _first_usec >= 0 else -1.0

func build_seconds() -> float:
	return build_usec/1e6 if build_usec >= 0 else -1.0

## One chunk, safe on a worker: a Node3D at its pivot holding its mesh's
## surfaces (the hall's boxes and cylinders as SkyMoments draws them, keels
## and stones in their own tints; `finish_mesh` makes the mesh) and its body
## (a shape a solid, the hall's own; no layer till it is still).
static func make_chunk(c: Dictionary, solids: Array) -> Node3D:
	var root := Node3D.new()
	root.name = str(c.id)
	root.position = c.pivot
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 0
	body.collision_mask = 0
	root.add_child(body)
	var pivot: Vector3 = c.pivot
	var surfaces := {}
	var all := []
	for k: int in c.solids: all.append(solids[k])
	all.append_array(c.extra)
	for q: Dictionary in all:
		var kind := "keel" if q.get("keel",false) else ("stone" if q.get("stone",false) else str(q.kind))
		if not surfaces.has(kind): surfaces[kind] = [PackedVector3Array(),PackedVector3Array()]
		var v: PackedVector3Array = surfaces[kind][0]
		var n: PackedVector3Array = surfaces[kind][1]
		var shape := CollisionShape3D.new()
		if q.kind == "box":
			var box := BoxShape3D.new()
			box.size = q.size
			shape.shape = box
			shape.transform = Transform3D(q.basis,(q.middle as Vector3)-pivot)
			SkyMoments._box(v,n,(q.middle as Vector3)-pivot,q.basis,(q.size as Vector3)*0.5)
		elif q.kind == "cyl":
			var cyl := CylinderShape3D.new()
			cyl.radius = q.radius
			cyl.height = q.height
			shape.shape = cyl
			shape.position = (q.middle as Vector3)-pivot
			SkyMoments._cylinder(v,n,(q.middle as Vector3)-pivot,float(q.radius),float(q.height))
		else:
			var pts := PackedVector3Array()
			for point: Vector3 in q.points: pts.append(point-pivot)
			var hull := ConvexPolygonShape3D.new()
			hull.points = pts
			shape.shape = hull
			_keel_faces(v,n,pts)
		surfaces[kind][0] = v
		surfaces[kind][1] = n
		body.add_child(shape)
	# The mesh itself is made on the main thread (`finish_mesh`): the
	# renderer's mesh store is not for workers.
	var drawn := MeshInstance3D.new()
	drawn.name = "Mesh"
	drawn.set_meta(&"surfaces",surfaces)
	root.add_child(drawn)
	return root

## Makes a chunk's mesh from the surfaces its worker left (main thread).
static func finish_mesh(node: Node3D, mats: Dictionary) -> void:
	var drawn := node.get_node(^"Mesh") as MeshInstance3D
	if not drawn.has_meta(&"surfaces"): return
	var surfaces: Dictionary = drawn.get_meta(&"surfaces")
	drawn.remove_meta(&"surfaces")
	var mesh := ArrayMesh.new()
	for kind: String in surfaces:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surfaces[kind][0]
		arrays[Mesh.ARRAY_NORMAL] = surfaces[kind][1]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,mats.get(kind,mats.box))
	drawn.mesh = mesh

## A keel's faces (RisePlan.keels: a top ring, a bottom ring and a shoulder
## ring, four corners each, flat shaded), wound to face out.
static func _keel_faces(v: PackedVector3Array, n: PackedVector3Array, pts: PackedVector3Array) -> void:
	var middle := Vector3.ZERO
	for point in pts: middle += point
	middle /= float(pts.size())
	# Rings: 0 the top, 2 the shoulder, 1 the bottom.
	_flat(v,n,_corner(pts,0,0),_corner(pts,0,1),_corner(pts,0,2),middle)
	_flat(v,n,_corner(pts,0,0),_corner(pts,0,2),_corner(pts,0,3),middle)
	_flat(v,n,_corner(pts,1,0),_corner(pts,1,1),_corner(pts,1,2),middle)
	_flat(v,n,_corner(pts,1,0),_corner(pts,1,2),_corner(pts,1,3),middle)
	for k in range(4):
		for pair: Array in [[0,2],[2,1]]:
			var a := _corner(pts,pair[0],k)
			var b := _corner(pts,pair[0],k+1)
			var c := _corner(pts,pair[1],k+1)
			var d := _corner(pts,pair[1],k)
			_flat(v,n,a,b,c,middle)
			_flat(v,n,a,c,d,middle)

## Corner `k` round ring `r` (each ring's corners come (-,-) (-,+) (+,-)
## (+,+); round it they go 0 1 3 2).
static func _corner(pts: PackedVector3Array, r: int, k: int) -> Vector3:
	return pts[r*4+[0,1,3,2][k%4]]

## One flat triangle facing away from `middle`.
static func _flat(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, middle: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot((a+b+c)/3.0-middle) < 0.0: normal = -normal
	SkyMoments._tri(v,n,[a,b,c],[normal,normal,normal],normal)

# --- Cloud ---------------------------------------------------------------------------

func _make_clouds() -> void:
	if _puffs != null: return
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 14
	ball.rings = 7
	var mat := ShaderMaterial.new()
	mat.shader = PUFF
	ball.surface_set_material(0,mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = ball
	mm.instance_count = PUFFS
	mm.visible_instance_count = 0
	_puffs = MultiMeshInstance3D.new()
	_puffs.name = "Puffs"
	_puffs.multimesh = mm
	_puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Never culled by its own box: the puffs go wherever the chunks are.
	_puffs.custom_aabb = AABB(Vector3(-2000,-1000,-2000),Vector3(4000,2000,4000))
	add_child(_puffs)

func _clear_clouds() -> void:
	_pp.clear(); _pv.clear(); _ps.clear(); _pg.clear(); _pa.clear(); _pl.clear()

## How many puffs are up now.
func puff_count() -> int:
	return _pp.size()

func _puff(at: Vector3, vel: Vector3, size: float, grow: float, life: float) -> void:
	if _pp.size() >= PUFFS: return
	_pp.append(at); _pv.append(vel); _ps.append(size); _pg.append(grow); _pa.append(0.0); _pl.append(life)

## Outward from chunk `c`'s middle at rim point `p` (flat, unit).
static func _out(c: Dictionary, p: Vector3) -> Vector3:
	var d := Vector3(p.x-float(c.pivot.x),0.0,p.z-float(c.pivot.z))
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD

## The ring of cloud as chunk `c` (lifted `lift` off its place) breaks
## through, and the cap of cloud on its wall tops.
func _burst(c: Dictionary, lift: float) -> void:
	var rim: PackedVector3Array = c.rim
	var n := mini(BURST,rim.size())
	for k in range(n):
		var p := rim[_rng.randi_range(0,rim.size()-1)]
		var out := _out(c,p)
		_puff(Vector3(p.x,sea_y+_rng.randf_range(-0.5,1.5),p.z)+out*_rng.randf_range(0.5,2.5),
			out*_rng.randf_range(1.5,4.5)+Vector3.UP*_rng.randf_range(1.5,4.0),_rng.randf_range(5.0,9.0),_rng.randf_range(0.6,1.2),_rng.randf_range(2.6,4.2))
	var v := float(c.speed)
	for k in range(mini(CAP,rim.size())):
		var p := rim[_rng.randi_range(0,rim.size()-1)]
		_puff(Vector3(p.x,float(c.hi.y)+lift+_rng.randf_range(0.0,1.0),p.z),Vector3.UP*v*_rng.randf_range(0.6,0.9)+_out(c,p)*_rng.randf_range(0.5,1.5),
			_rng.randf_range(3.0,5.5),_rng.randf_range(0.5,1.0),_rng.randf_range(1.6,2.6))

## Cloud streaming off chunk `i` as it clears the top: puffs on its sides
## between the cloud top and its own top, carried up a little and left
## behind.
func _stream(i: int, c: Dictionary, lift: float, v: float, dt: float) -> void:
	_owed[i] += STREAM_RATE*dt
	var rim: PackedVector3Array = c.rim
	var top: float = float(c.hi.y)+lift
	while _owed[i] >= 1.0:
		_owed[i] -= 1.0
		var p := rim[_rng.randi_range(0,rim.size()-1)]
		var out := _out(c,p)
		var y := _rng.randf_range(sea_y,minf(top,sea_y+10.0))
		_puff(Vector3(p.x,y,p.z)+out*_rng.randf_range(0.0,1.5),Vector3.UP*v*STREAM_CARRY*_rng.randf_range(0.6,1.0)+out*_rng.randf_range(0.5,2.0),
			_rng.randf_range(2.5,5.0),_rng.randf_range(0.6,1.4),_rng.randf_range(1.4,2.4))

func _step_clouds(delta: float) -> void:
	if _puffs == null: return
	var k := 0
	while k < _pp.size():
		_pa[k] += delta
		if _pa[k] >= _pl[k]:
			var last := _pp.size()-1
			_pp[k] = _pp[last]; _pv[k] = _pv[last]; _ps[k] = _ps[last]; _pg[k] = _pg[last]; _pa[k] = _pa[last]; _pl[k] = _pl[last]
			_pp.resize(last); _pv.resize(last); _ps.resize(last); _pg.resize(last); _pa.resize(last); _pl.resize(last)
			continue
		_pp[k] += _pv[k]*delta
		_pv[k] *= exp(-1.4*delta)
		k += 1
	var mm := _puffs.multimesh
	mm.visible_instance_count = _pp.size()
	for i in range(_pp.size()):
		var u := _pa[i]/_pl[i]
		var size := _ps[i]*(1.0+_pg[i]*sqrt(u))
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(size,size*0.72,size)),_pp[i]))
		mm.set_instance_color(i,Color(1,1,1,smoothstep(0.0,0.15,u)*(1.0-smoothstep(0.4,1.0,u))*0.8))

## The sea's swells now: up to SWELLS of (x, z, radius, height), in this
## node's frame, where a chunk is about to break through or is breaking
## through, or sinking back under it.
func swells() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for i in range(chunks.size()):
		if not (state[i] == "moving" or state[i] == "sinking") or out.size() >= SWELLS: continue
		var c: Dictionary = chunks[i]
		var lift := float(nodes[i].position.y)-float(c.pivot.y)
		var d := float(c.hi.y)+lift-sea_y
		var tall := float(c.hi.y)-float(c.lo.y)
		var amount := SWELL*smoothstep(-SWELL_FROM,0.0,d)*(1.0-smoothstep(tall*0.5,tall+6.0,d))
		if amount <= 0.01: continue
		var r := Vector2(float(c.hi.x)-float(c.lo.x),float(c.hi.z)-float(c.lo.z)).length()*0.5
		out.append(Vector4(float(c.pivot.x),float(c.pivot.z),r,amount))
	return out

## What the HUD shows: {clock, risen (chunks begun), set (still and solid),
## total, chunk (the last to begin), stall, built, first (s to the first
## chunk made), build (s to the last, -1 running), waiting (a due chunk not
## made yet), length (planned, s), done}.
func progress() -> Dictionary:
	var risen := 0
	var set_count := 0
	var title := ""
	for i in range(chunks.size()):
		if state[i] != "waiting":
			risen += 1
			title = chunks[i].title
		if state[i] == "set": set_count += 1
	var due := _next_due()
	return {"clock":clock,"risen":risen,"set":set_count,"total":chunks.size(),"chunk":title,"stall":stall,"built":built,
		"first":first_ready(),"build":build_seconds(),"waiting":playing and due >= 0 and nodes[due] == null and float(chunks[due].start) <= sched+0.001,
		"length":float(plan.get("length",0.0)),"done":done_at}
