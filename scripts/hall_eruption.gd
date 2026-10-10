extends Node3D
## The Sundered hall erupting out of the cloud sea in pieces, one by one
## (docs/design/hall-eruption.md; the plan, its pieces and timing:
## scripts/hall_eruption_plan.gd). Stand it at the hall's entry (the
## moments set piece's own metres: the entry at 0, flying north), tell it
## where the cloud top is (`sea_y`, in its own frame), `setup`, then `play`
## and `advance` it every physics frame.
##
## Made on a worker (`setup` starts it): the pieces one at a time, in the
## order they rise, each handed over as soon as it is made. Playing never
## waits for the whole build: the cloud churns from the start, and a piece
## due to rise before it is made holds the schedule (the pieces already in
## the air fly on) until it is; `stall` says how long it held. With
## `upfront` and `cost` (s) the build is made slow on purpose, to see how a
## real build (the kit's, seconds long) sits under the eruption.
##
## A piece rises from under the cloud top: straight up (the base, the
## floating stones) or up beside the hall and in over it (the rest, its
## `out` and `lift`), overshooting its place and ringing out (`pose`).
## While it moves it collides with nothing; once still it is put on the
## ruins' layer (scripts/ruin_bump.gd LAYER), where the plane bumps off it,
## unless the plane is in its box then (`plane_box`), in which case it
## waits till the plane is out: the plane is never shut inside stone.
##
## The cloud and the dust are greybox: soft balls of cloud (a churn over
## the hall's footprint from the start, a burst round each piece where it
## breaks through, wisps trailing it out of the sea) and small grey stones
## falling off a rising piece.

const EPlan = preload("res://scripts/hall_eruption_plan.gd")
const SkyMoments = preload("res://scripts/sky_moments.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const GRID := preload("res://shaders/hall_eruption_grid.gdshader")
const PUFF := preload("res://shaders/hall_eruption_puff.gdshader")

## The in-world hall's greybox tints (scripts/sky_moments.gd TINTS), and the
## additions'.
const TINTS := {"box":Color(0.55,0.57,0.6),"cyl":Color(0.6,0.58,0.55),"keel":Color(0.42,0.4,0.39),"stone":Color(0.5,0.49,0.47)}
## A piece starts with its top this far (m) under the cloud top.
const UNDER := 6.0
## The rise eases out with this power (higher: a harder burst off the sea).
const RISE_POW := 2.6
## The overshoot rings out as a spring: its period (s) and damping.
const RING := 0.6
const DAMP := 0.42
## Cloud: the most puffs at once; the churn over the footprint (puffs a
## second at its height, how long it runs on past the last breakthrough);
## each breakthrough's burst (puffs per metre round the piece, fewest,
## most); wisps trailing a piece (a second, while its foot is within WISP_UP
## m of the cloud top).
const PUFFS := 1200
const CHURN_RATE := 34.0
const CHURN_TAIL := 1.5
const BURST_PER_M := 0.55
const BURST := Vector2i(6,46)
const WISP_RATE := 26.0
const WISP_UP := 30.0
## Dust: the most at once, stones a second per square metre of a rising
## piece's foot (capped), gravity.
const DUST := 700
const DUST_RATE := 0.6
const DUST_CAP := 40.0
const GRAVITY := 9.8
## A settled piece waits for the plane to be this far (m) out of its box.
const PLANE_CLEAR := 0.6

signal finished

## The cloud top, in this node's frame.
var sea_y := -125.0
var opts := {}
## The plan (EPlan.make): solids, pieces, length.
var plan := {}
var pieces: Array = []
## Each piece's node once made (null till then), and what it is doing:
## "waiting" (not risen), "moving", "pending" (still, the plane in its box),
## "set" (still and solid).
var nodes: Array = []
var state: PackedStringArray = []
var began_at: PackedFloat32Array = []
var broke: PackedByteArray = []
var playing := false
## Seconds since play (pieces in the air fly on this) and the schedule's
## clock (held while a due piece is not made yet), and how long it held.
var clock := 0.0
var sched := 0.0
var stall := 0.0
var done_at := -1.0
## The plane's box in this frame (Callable() -> AABB; a zero-size AABB for
## no plane).
var plane_box := Callable()
## The build: its task, the pieces made and not yet taken, how many taken,
## when it began and how long it took (usec; -1 running).
var _task := -1
var _mutex := Mutex.new()
var _made: Array = []
var built := 0
var _build_began := 0
var build_usec := -1
var _first_usec := -1
## The heaviest hand-over of one piece on the main thread (usec: its mesh
## made, put under this node).
var take_usec := 0
var _materials := {}
var _footprint := Rect2()
## The puffs and dust: positions, velocities, sizes, ages and lives.
var _puffs: MultiMeshInstance3D
var _dust: MultiMeshInstance3D
var _pp := PackedVector3Array()
var _pv := PackedVector3Array()
var _ps := PackedFloat32Array()
var _pg := PackedFloat32Array()
var _pa := PackedFloat32Array()
var _pl := PackedFloat32Array()
var _dp := PackedVector3Array()
var _dv := PackedVector3Array()
var _ds := PackedFloat32Array()
var _da := PackedFloat32Array()
var _dl := PackedFloat32Array()
var _last := PackedVector3Array()
var _rng := RandomNumberGenerator.new()
var _churn_owed := 0.0

## The eruption's options from the launch flags: --erupt-speed=<x> (all of
## it quicker), --erupt-gaps=<x> (the gaps between pieces), --erupt-path=
## arc|straight, --no-keels, --no-stones, --build-upfront=<s> and
## --build-cost=<s> (a slow build on purpose: before the first piece, and
## spread over the pieces).
static func options(args: PackedStringArray) -> Dictionary:
	var out := {"speed":1.0,"gaps":1.0,"path":"arc","keels":true,"stones":true,"upfront":0.0,"cost":0.0}
	for a: String in args:
		if a.begins_with("--erupt-speed="): out.speed = maxf(0.05,float(a.get_slice("=",1)))
		elif a.begins_with("--erupt-gaps="): out.gaps = maxf(0.0,float(a.get_slice("=",1)))
		elif a.begins_with("--erupt-path=") and a.get_slice("=",1) in ["arc","straight"]: out.path = a.get_slice("=",1)
		elif a == "--no-keels": out.keels = false
		elif a == "--no-stones": out.stones = false
		elif a.begins_with("--build-upfront="): out.upfront = maxf(0.0,float(a.get_slice("=",1)))
		elif a.begins_with("--build-cost="): out.cost = maxf(0.0,float(a.get_slice("=",1)))
	return out

func _init() -> void:
	name = "HallEruption"
	_rng.seed = 99

func _exit_tree() -> void:
	_wait()

func _wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

## Plans the pieces and starts making them on a worker. Puts nothing up.
func setup(given := {}) -> void:
	_wait()
	for n in nodes:
		if n != null: (n as Node).queue_free()
	opts = given
	plan = EPlan.make(given)
	pieces = plan.pieces
	nodes = []
	nodes.resize(pieces.size())
	state = PackedStringArray()
	state.resize(pieces.size())
	state.fill("waiting")
	began_at = PackedFloat32Array()
	began_at.resize(pieces.size())
	broke = PackedByteArray()
	broke.resize(pieces.size())
	_last = PackedVector3Array()
	_last.resize(pieces.size())
	var lo := Vector2(INF,INF)
	var hi := -lo
	for p: Dictionary in pieces:
		lo = lo.min(Vector2(p.lo.x,p.lo.z))
		hi = hi.max(Vector2(p.hi.x,p.hi.z))
	_footprint = Rect2(lo,hi-lo)
	for kind: String in TINTS: _material(kind)
	_make_clouds()
	built = 0
	_made = []
	build_usec = -1
	_first_usec = -1
	_build_began = Time.get_ticks_usec()
	_task = WorkerThreadPool.add_task(_build_all.bind(float(given.get("upfront",0.0)),float(given.get("cost",0.0))),true,"Hall eruption pieces")

## From the start: every piece back under the cloud, the clocks at 0.
func play() -> void:
	clock = 0.0
	sched = 0.0
	stall = 0.0
	done_at = -1.0
	_churn_owed = 0.0
	playing = true
	for i in range(pieces.size()):
		state[i] = "waiting"
		broke[i] = 0
		if nodes[i] != null: _hide(i)
	_clear_clouds()

## Every piece in its place and solid at once (no plane in the way).
func finish_now() -> void:
	flush()
	for i in range(pieces.size()):
		_place(i,Transform3D(Basis.IDENTITY,pieces[i].pivot))
		(nodes[i] as Node3D).visible = true
		_solid(i,true)
		state[i] = "set"
	playing = false
	done_at = clock
	_clear_clouds()

## Waits for the build and takes every piece made.
func flush() -> void:
	_wait()
	_take()

## True once every piece is made and taken.
func all_built() -> bool:
	return built == pieces.size() and not pieces.is_empty()

## One frame: the pieces made since taken, then the schedule, every piece
## in the air, the settled ones made solid when the plane is clear, and the
## cloud and dust.
func advance(delta: float) -> void:
	_take()
	if playing:
		clock += delta
		var due := _next_due()
		var next := sched+delta
		while due >= 0 and float(pieces[due].start) <= next:
			if nodes[due] == null:
				stall += next-maxf(sched,float(pieces[due].start))
				next = float(pieces[due].start)
				break
			_begin(due,clock-(next-float(pieces[due].start)))
			due = _next_due()
		sched = next
		for i in range(pieces.size()):
			if state[i] == "moving": _move(i,delta)
		if done_at < 0.0 and _all_set():
			done_at = clock
			playing = false
			finished.emit()
	for i in range(pieces.size()):
		if state[i] == "pending" and not _plane_in(i):
			_solid(i,true)
			state[i] = "set"
	if playing or done_at < 0.0: _churn(delta)
	_step_clouds(delta)

## The index of the next piece to rise (-1 none).
func _next_due() -> int:
	for i in range(pieces.size()):
		if state[i] == "waiting": return i
	return -1

func _all_set() -> bool:
	for s in state:
		if s != "set": return false
	return true

func _all_still() -> bool:
	for s in state:
		if s == "waiting" or s == "moving": return false
	return true

## Seconds since `i` began rising (it began at clock `at`).
func _begin(i: int, at: float) -> void:
	state[i] = "moving"
	began_at[i] = at
	(nodes[i] as Node3D).visible = true
	_move(i,1.0/60.0)

func _move(i: int, dt: float) -> void:
	var p: Dictionary = pieces[i]
	var t := clock-float(began_at[i])
	var was := _last[i]
	var pose := pose_at(p,t,sea_y)
	_place(i,pose)
	# Breaking through the cloud top: a burst round its foot.
	var top: float = pose.origin.y+(float(p.hi.y)-float(p.pivot.y))
	if broke[i] == 0 and top > sea_y:
		broke[i] = 1
		_burst(p,pose)
	var foot: float = pose.origin.y-(float(p.pivot.y)-float(p.lo.y))
	if broke[i] == 1 and foot < sea_y+WISP_UP and t < float(p.rise): _wisps(p,pose,dt)
	if t < float(p.rise)*0.9 and foot > sea_y-2.0: _shed(p,pose,(pose.origin-was)/maxf(dt,0.001),dt)
	if t >= float(p.rise)+float(p.slot)+float(p.settle):
		_place(i,Transform3D(Basis.IDENTITY,p.pivot))
		state[i] = "pending"
		if not _plane_in(i):
			_solid(i,true)
			state[i] = "set"

## Where piece `p`'s pivot stands `t` s after it began rising, the cloud
## top at `sea` (this frame): under the cloud (its top UNDER under), up
## (beside the hall by `out`, at `lift` over its place, plus its overshoot),
## in and down into place (sinking `dip` past it), ringing out; tipped by
## up to `tilt` degrees on the way up. Exactly its place from the end on.
static func pose_at(p: Dictionary, t: float, sea: float) -> Transform3D:
	var home: Vector3 = p.pivot
	var rise := float(p.rise)
	var slot := float(p.slot)
	var settle := float(p.settle)
	var over := float(p.over)
	var lift := float(p.lift)
	var side: Vector3 = (p.across as Vector3)*float(p.out)
	var start_y := sea-UNDER-(float(p.hi.y)-home.y)
	var tip := 0.0
	var at := home
	if t < rise:
		var u := clampf(t/rise,0.0,1.0)
		var e := 1.0-pow(1.0-u,RISE_POW)
		at = home+side
		at.y = lerpf(start_y,home.y+lift+over,e)
		tip = 1.0-e
	elif t < rise+slot:
		var s := (t-rise)/slot
		at = home+side*(1.0-smoothstep(0.0,0.7,s))
		at.y = home.y+lerpf(lift+over,-float(p.dip),smoothstep(0.35,1.0,s))
	elif t < rise+slot+settle:
		var x0 := -float(p.dip) if slot > 0.0 else over
		at.y = home.y+ring(x0,t-rise-slot)
	else:
		return Transform3D(Basis.IDENTITY,home)
	if tip <= 0.0: return Transform3D(Basis.IDENTITY,at)
	var a := float(hash(str(p.id)) % 6283)/1000.0
	var axis := Vector3(cos(a),0.0,sin(a))
	var basis := Basis(axis,deg_to_rad(float(p.tilt))*tip)*Basis(Vector3.UP,deg_to_rad(float(p.tilt))*0.6*tip*(1.0 if (hash(str(p.id)) & 2) == 0 else -1.0))
	return Transform3D(basis,at)

## A damped spring let go at `x0` (m), still: where it is `t` s on.
static func ring(x0: float, t: float) -> float:
	var w := TAU/RING
	var wd := w*sqrt(1.0-DAMP*DAMP)
	return exp(-DAMP*w*t)*(x0*cos(wd*t)+(DAMP*w*x0/wd)*sin(wd*t))

func _place(i: int, pose: Transform3D) -> void:
	var node: Node3D = nodes[i]
	if node == null: return
	node.transform = pose
	_last[i] = pose.origin
	var mesh := node.get_node_or_null(^"Mesh") as GeometryInstance3D
	if mesh != null and is_inside_tree():
		mesh.set_instance_shader_parameter(&"offset",global_transform.basis*(pose.origin-(pieces[i].pivot as Vector3)))

func _hide(i: int) -> void:
	var node: Node3D = nodes[i]
	node.visible = false
	_solid(i,false)
	var p: Dictionary = pieces[i]
	_place(i,pose_at(p,0.0,sea_y))

func _solid(i: int, on: bool) -> void:
	var node: Node3D = nodes[i]
	if node == null: return
	var body := node.get_node(^"Body") as StaticBody3D
	body.collision_layer = RuinBump.LAYER if on else 0

## Whether the plane is in (or within PLANE_CLEAR of) piece `i`'s box.
func _plane_in(i: int) -> bool:
	if not plane_box.is_valid(): return false
	var box: AABB = plane_box.call()
	if box.size == Vector3.ZERO: return false
	var p: Dictionary = pieces[i]
	var mine := AABB(p.lo,(p.hi as Vector3)-(p.lo as Vector3)).grow(PLANE_CLEAR)
	return mine.intersects(box)

# --- Making the pieces (worker) ------------------------------------------------------

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
	for p: Dictionary in pieces: weight += _weight(p)
	for i in range(pieces.size()):
		var began := Time.get_ticks_usec()
		var node := make_piece(pieces[i],plan.solids,_materials)
		if cost > 0.0:
			var owed := int(cost*1e6*_weight(pieces[i])/weight)-(Time.get_ticks_usec()-began)
			if owed > 0: OS.delay_usec(owed)
		_mutex.lock()
		_made.append([i,node])
		_mutex.unlock()

static func _weight(p: Dictionary) -> float:
	return float(p.solids.size())+4.0*float(p.extra.size())

## Takes the pieces made so far: under this node, hidden, under the cloud.
func _take() -> void:
	_mutex.lock()
	var got := _made
	_made = []
	_mutex.unlock()
	for item: Array in got:
		var i: int = item[0]
		var node: Node3D = item[1]
		nodes[i] = node
		var began := Time.get_ticks_usec()
		finish_mesh(node,_materials)
		add_child(node)
		take_usec = maxi(take_usec,Time.get_ticks_usec()-began)
		built += 1
		if _first_usec < 0: _first_usec = Time.get_ticks_usec()-_build_began
		if state[i] == "set":
			_place(i,Transform3D(Basis.IDENTITY,pieces[i].pivot))
			_solid(i,true)
		else: _hide(i)
	if built == pieces.size() and build_usec < 0 and not pieces.is_empty():
		build_usec = Time.get_ticks_usec()-_build_began

## Seconds from setup to the first piece made, and to the last (-1 not yet).
func first_ready() -> float:
	return _first_usec/1e6 if _first_usec >= 0 else -1.0

func build_seconds() -> float:
	return build_usec/1e6 if build_usec >= 0 else -1.0

## One piece, safe on a worker: a Node3D at its pivot holding its mesh's
## surfaces (the hall's boxes and cylinders as SkyMoments draws them, the
## keels and stones in their own tints; `finish_mesh` makes the mesh) and
## its body (a shape a solid, the hall's own;
## no layer till it is still).
static func make_piece(p: Dictionary, solids: Array, mats: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = str(p.id)
	root.position = p.pivot
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 0
	body.collision_mask = 0
	root.add_child(body)
	var pivot: Vector3 = p.pivot
	var surfaces := {}
	var all := []
	for k: int in p.solids: all.append(solids[k])
	all.append_array(p.extra)
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

## Makes a piece's mesh from the surfaces its worker left (main thread).
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

## A keel's faces (EPlan.keels: a top ring, a bottom ring and a shoulder
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

# --- Cloud and dust ------------------------------------------------------------------

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
	_puffs = _multi("Puffs",ball,PUFFS)
	var bit := BoxMesh.new()
	bit.size = Vector3.ONE
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.42,0.41,0.4)
	grey.roughness = 0.95
	bit.surface_set_material(0,grey)
	_dust = _multi("Dust",bit,DUST)

func _multi(label: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.name = label
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Never culled by its own box: the puffs go wherever the pieces are.
	inst.custom_aabb = AABB(Vector3(-2000,-1000,-2000),Vector3(4000,2000,4000))
	add_child(inst)
	return inst

func _clear_clouds() -> void:
	_pp.clear(); _pv.clear(); _ps.clear(); _pg.clear(); _pa.clear(); _pl.clear()
	_dp.clear(); _dv.clear(); _ds.clear(); _da.clear(); _dl.clear()

## How many puffs and dust stones are up now.
func puff_count() -> int:
	return _pp.size()

func dust_count() -> int:
	return _dp.size()

func _puff(at: Vector3, vel: Vector3, size: float, grow: float, life: float) -> void:
	if _pp.size() >= PUFFS: return
	_pp.append(at); _pv.append(vel); _ps.append(size); _pg.append(grow); _pa.append(0.0); _pl.append(life)

## The cloud boiling over the hall's footprint from the start till the
## last piece is through.
func _churn(delta: float) -> void:
	var last_break := true
	for b in broke:
		if b == 0:
			last_break = false
			break
	var strength := 1.0
	if last_break and playing:
		strength = 0.35
	elif not playing: return
	strength *= clampf(clock/0.6,0.15,1.0)
	_churn_owed += CHURN_RATE*strength*delta
	while _churn_owed >= 1.0:
		_churn_owed -= 1.0
		var r := _footprint.grow(10.0)
		var at := Vector3(_rng.randf_range(r.position.x,r.end.x),sea_y+_rng.randf_range(-1.0,2.5),_rng.randf_range(r.position.y,r.end.y))
		_puff(at,Vector3(_rng.randf_range(-1.0,1.0),_rng.randf_range(1.5,5.0),_rng.randf_range(-1.0,1.0)),_rng.randf_range(6.0,15.0),_rng.randf_range(0.6,1.4),_rng.randf_range(2.2,3.8))

## A burst round a piece's foot where it breaks the cloud top.
func _burst(p: Dictionary, pose: Transform3D) -> void:
	var half := Vector2((float(p.hi.x)-float(p.lo.x))*0.5,(float(p.hi.z)-float(p.lo.z))*0.5)
	var middle := Vector3(pose.origin.x,sea_y,pose.origin.z)
	var n := clampi(int(4.0*(half.x+half.y)*BURST_PER_M),BURST.x,BURST.y)
	var big := clampf((half.x+half.y)/10.0,0.5,2.2)
	for k in range(n):
		var a := TAU*float(k)/float(n)+_rng.randf_range(-0.2,0.2)
		var edge := Vector3(cos(a)*half.x,0.0,sin(a)*half.y)*1.05
		var out := Vector3(cos(a),0.0,sin(a))
		_puff(middle+edge+Vector3.UP*_rng.randf_range(0.0,2.0),out*_rng.randf_range(4.0,11.0)*big+Vector3.UP*_rng.randf_range(4.0,13.0),
			_rng.randf_range(3.0,7.0)*big,_rng.randf_range(1.2,2.4),_rng.randf_range(1.8,3.4))

## Wisps trailing a piece's foot out of the sea.
func _wisps(p: Dictionary, pose: Transform3D, dt: float) -> void:
	var half := Vector2((float(p.hi.x)-float(p.lo.x))*0.5,(float(p.hi.z)-float(p.lo.z))*0.5)
	var count := WISP_RATE*clampf((half.x+half.y)/8.0,0.4,2.5)*dt
	var foot: float = pose.origin.y-(float(p.pivot.y)-float(p.lo.y))
	while count > 0.0:
		if count < 1.0 and _rng.randf() > count: break
		count -= 1.0
		var at := Vector3(pose.origin.x+_rng.randf_range(-half.x,half.x),foot+_rng.randf_range(-1.0,1.0),pose.origin.z+_rng.randf_range(-half.y,half.y))
		_puff(at,Vector3(_rng.randf_range(-1.5,1.5),_rng.randf_range(2.0,8.0),_rng.randf_range(-1.5,1.5)),_rng.randf_range(2.0,4.5),_rng.randf_range(0.8,1.6),_rng.randf_range(1.0,1.8))

## Small stones falling off a rising piece's foot.
func _shed(p: Dictionary, pose: Transform3D, vel: Vector3, dt: float) -> void:
	var half := Vector2((float(p.hi.x)-float(p.lo.x))*0.5,(float(p.hi.z)-float(p.lo.z))*0.5)
	var count := minf(DUST_CAP,DUST_RATE*4.0*half.x*half.y)*dt
	var foot: float = pose.origin.y-(float(p.pivot.y)-float(p.lo.y))
	while count > 0.0:
		if count < 1.0 and _rng.randf() > count: break
		count -= 1.0
		if _dp.size() >= DUST: return
		_dp.append(Vector3(pose.origin.x+_rng.randf_range(-half.x,half.x),foot+_rng.randf_range(0.0,1.0),pose.origin.z+_rng.randf_range(-half.y,half.y)))
		_dv.append(vel*0.25+Vector3(_rng.randf_range(-2.0,2.0),_rng.randf_range(-1.0,2.0),_rng.randf_range(-2.0,2.0)))
		_ds.append(_rng.randf_range(0.12,0.5))
		_da.append(0.0)
		_dl.append(_rng.randf_range(1.6,3.0))

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
		_pv[k] *= exp(-1.6*delta)
		k += 1
	var mm := _puffs.multimesh
	mm.visible_instance_count = _pp.size()
	for i in range(_pp.size()):
		var u := _pa[i]/_pl[i]
		var size := _ps[i]*(1.0+_pg[i]*sqrt(u))
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(size,size*0.72,size)),_pp[i]))
		mm.set_instance_color(i,Color(1,1,1,smoothstep(0.0,0.12,u)*(1.0-smoothstep(0.45,1.0,u))*0.85))
	k = 0
	while k < _dp.size():
		_da[k] += delta
		if _da[k] >= _dl[k] or _dp[k].y < sea_y-4.0:
			var last := _dp.size()-1
			_dp[k] = _dp[last]; _dv[k] = _dv[last]; _ds[k] = _ds[last]; _da[k] = _da[last]; _dl[k] = _dl[last]
			_dp.resize(last); _dv.resize(last); _ds.resize(last); _da.resize(last); _dl.resize(last)
			continue
		_dv[k] += Vector3.DOWN*GRAVITY*delta
		_dp[k] += _dv[k]*delta
		k += 1
	mm = _dust.multimesh
	mm.visible_instance_count = _dp.size()
	for i in range(_dp.size()):
		var s := _ds[i]*(1.0-smoothstep(0.7,1.0,_da[i]/_dl[i]))
		mm.set_instance_transform(i,Transform3D(Basis(Vector3(1,1,0).normalized(),_da[i]*3.0).scaled(Vector3.ONE*maxf(s,0.001)),_dp[i]))

## What the HUD shows: {clock, risen (pieces up out of the cloud), set
## (still and solid), total, category (the last to begin), stall, built,
## first (s to the first piece made), build (s to the last, -1 running),
## waiting (a due piece not made yet), length (planned, s)}.
func progress() -> Dictionary:
	var risen := 0
	var set_count := 0
	var category := ""
	for i in range(pieces.size()):
		if state[i] != "waiting":
			risen += 1
			category = pieces[i].category
		if state[i] == "set": set_count += 1
	var due := _next_due()
	return {"clock":clock,"risen":risen,"set":set_count,"total":pieces.size(),"category":category,"stall":stall,"built":built,
		"first":first_ready(),"build":build_seconds(),"waiting":playing and due >= 0 and nodes[due] == null and float(pieces[due].start) <= sched+0.001,
		"length":float(plan.get("length",0.0)),"done":done_at}
