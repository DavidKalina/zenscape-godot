extends RefCounted
## The motif editor's snappy rebuild (spec-editor-traps item 9). An edit
## stands again in a frame: the land coarse (KitLand's fast grid, a few ms),
## every piece and run whose build is unchanged kept as it stood (only
## re-posed), and one whose ground changed shown as it was until its new
## build lands. The full-detail land (crisp cliffs, lips, collision) and the
## changed pieces and runs are built on a worker (rendered; headless, here
## and now: the dummy renderer's RIDs are not safe on a worker, godot#124183)
## and swapped in when done. Play asks `finish_now` (full detail, at once).
## The editor's view only: the saved file and what the yard and generator
## build are unchanged.
##
## A piece's build depends on its recipe (id, seed, weathering, breakable);
## a "fit" aqueduct piece's and a run's also on the ground under it, so
## their key carries that ground, sampled on a metre grid. Its pose is
## applied apart (a plain piece moved by the land is only moved).

const MotifAuthored = preload("res://scripts/kit_isle/motif_authored.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const SAMPLE := 1.0

var study: Node3D
var threaded := DisplayServer.get_name() != "headless"
## The running worker job ({} none): task, gen, out, items, keys, land.
var job: Dictionary = {}
## Bumped by each rebuild; a job of an older gen is dropped when it lands.
var gen := 0
## Whether the stand showing is full detail (land and every piece).
var detailed := true
## Whether the land standing is the coarse one.
var coarse_land := false
## What the stand needs once it is settled ({} none): a full land and the
## items [kind, k] to build.
var _owed: Dictionary = {}
var _began := 0
## Timings (ms): the last quick stand, the last swap (edit to full detail).
var quick_ms := 0
var detail_ms := 0
var reused := 0
## The longest swap step yet (us).
var swap_us := 0
## The swap's steps left ([Callable, its node]) and the new land coming in.
var _queue: Array = []
var _hill_in: Node3D = null
## A frame's share of the swap (us).
const BUDGET_US := 6000
var built := 0

func _init(s: Node3D) -> void:
	study = s

# --- Keys ---------------------------------------------------------------------------------

static func _base(d: Dictionary, p: Dictionary) -> String:
	return var_to_str([str(p.id),int(p.seed),snappedf(float(p.get("weathered",0.0)),0.001),bool(p.get("fit",false)),
		bool(p.get("breakable",true)) and bool(d.get("breakable",true))])

static func _fits(p: Dictionary) -> bool:
	return bool(p.get("fit",false)) and str(p.id) in RuinKit.AQUEDUCT_PIECES

## Piece k's key: its recipe, and (fit) its pose and the ground under it.
static func piece_key(m: RefCounted, k: int) -> String:
	var p: Dictionary = m.data.pieces[k]
	var key := _base(m.data,p)
	if not _fits(p): return key
	var pose: Array = m.pose_of(k)
	var at: Vector3 = pose[0]
	var box: AABB = MotifAuthored.box_of(str(p.id),int(p.seed),float(p.get("weathered",0.0)))
	var b := Basis(Vector3.UP,deg_to_rad(float(pose[1])))
	var g: Callable = m.ground_fn()
	var ys: Array = [snappedf(at.x,0.001),snappedf(at.y,0.001),snappedf(at.z,0.001),snappedf(float(pose[1]),0.01)]
	var nx := maxi(int(ceil(box.size.x/SAMPLE)),1)
	var nz := maxi(int(ceil(box.size.z/SAMPLE)),1)
	for i in range(nx+1):
		for j in range(nz+1):
			var w := at+b*(box.position+Vector3(box.size.x*i/nx,0.0,box.size.z*j/nz))
			ys.append(snappedf(float(g.call(w.x,w.z)),0.01))
	return key+"|"+str(hash(var_to_str(ys)))

static func run_base(m: RefCounted, k: int) -> String:
	var r: Dictionary = m.data.runs[k]
	return "run|"+var_to_str(r)+"|"+str(bool(m.data.get("breakable",true)))

## Run k's key: its recipe and the ground along it (and 3 m either side).
static func run_key(m: RefCounted, k: int) -> String:
	var r: Dictionary = m.data.runs[k]
	var from := Vector2(float(r.from[0]),float(r.from[1]))
	var to := Vector2(float(r.to[0]),float(r.to[1]))
	var along := (to-from).normalized() if to != from else Vector2.RIGHT
	var side := Vector2(-along.y,along.x)
	var g: Callable = m.ground_fn()
	var ys: Array = []
	var n := maxi(int(ceil(from.distance_to(to)/SAMPLE)),1)
	for i in range(-2,n+3):
		var q := from+along*SAMPLE*i
		for s: float in [-3.0,0.0,3.0]:
			var w := q+side*s
			ys.append(snappedf(float(g.call(w.x,w.y)),0.01))
	return run_base(m,k)+"|"+str(hash(var_to_str(ys)))

# --- The stand ----------------------------------------------------------------------------

## The nodes standing in `holder` taken out of it: base -> [[key, node]].
static func harvest(holder: Node3D) -> Dictionary:
	var out := {}
	if holder == null: return out
	for c: Node in holder.get_children():
		holder.remove_child(c)
		if not c.has_meta("rb_base"):
			c.free()
			continue
		var base := str(c.get_meta("rb_base"))
		if not out.has(base): out[base] = []
		(out[base] as Array).append([str(c.get_meta("rb_key")),c])
	return out

static func free_cache(cache: Dictionary) -> void:
	for base: String in cache:
		for e: Array in cache[base]:
			if is_instance_valid(e[1]): (e[1] as Node).free()
	cache.clear()

## The node in `cache` built as `key` (exact), else one of its base (a
## stale stand-in, the second value false), else null.
static func _take(cache: Dictionary, base: String, key: String) -> Array:
	var list: Array = cache.get(base,[])
	for i in range(list.size()):
		if str(list[i][0]) == key:
			var e: Array = list[i]
			list.remove_at(i)
			return [e[1],true]
	if not list.is_empty():
		var e: Array = list.pop_back()
		return [e[1],false]
	return [null,false]

static func _tag(node: Node3D, base: String, key: String) -> void:
	node.set_meta("rb_base",base)
	node.set_meta("rb_key",key)

## Every piece and run of `m` into `holder`: kept from `cache` where its
## key matches, a stale stand-in where only its base does (`late` then
## gets [kind, k, key]), built here when `build_missing` (else `late`).
func fill(m: RefCounted, holder: Node3D, cache: Dictionary, build_missing: bool) -> Array:
	var late: Array = []
	for k in range((m.data.get("pieces",[]) as Array).size()):
		var p: Dictionary = m.data.pieces[k]
		var base := _base(m.data,p)
		var key := piece_key(m,k)
		var got := _take(cache,base,key)
		var node: Node3D = got[0]
		if node != null and (bool(got[1]) or not build_missing):
			var pose: Array = m.pose_of(k)
			var at: Array = p.at
			at[0] = snappedf((pose[0] as Vector3).x,0.001)
			at[1] = snappedf((pose[0] as Vector3).y,0.001)
			at[2] = snappedf((pose[0] as Vector3).z,0.001)
			if p.has("on"): p.turn = snappedf(float(pose[1]),0.001)
			node.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(pose[1]))),pose[0])
			node.name = "P%d" % k
			if not bool(got[1]):
				late.append(["P",k,key])
				_tag(node,base,"")
			else: reused += 1
			holder.add_child(node)
			continue
		if node != null: node.free()
		if not build_missing:
			late.append(["P",k,key])
			continue
		node = m.make_piece(k)
		if node == null: continue
		_tag(node,base,key)
		holder.add_child(node)
		built += 1
	for k in range((m.data.get("runs",[]) as Array).size()):
		var base := run_base(m,k)
		var key := run_key(m,k)
		var got := _take(cache,base,key)
		var node: Node3D = got[0]
		if node != null and (bool(got[1]) or not build_missing):
			node.name = "Run%d" % k
			if not bool(got[1]):
				late.append(["Run",k,key])
				_tag(node,base,"")
			else: reused += 1
			holder.add_child(node)
			continue
		if node != null: node.free()
		if not build_missing:
			late.append(["Run",k,key])
			continue
		node = m.make_run(k)
		if node == null: continue
		_tag(node,base,key)
		holder.add_child(node)
		built += 1
	return late

# --- The job ------------------------------------------------------------------------------

## A rebuild began (its stand quick or whole): what is owed for full
## detail. `land`: the land stood is coarse.
func owe(land: bool, late: Array) -> void:
	gen += 1
	_abort()
	coarse_land = land
	if not land and late.is_empty():
		_owed = {}
		detailed = true
		return
	_owed = {"land":land,"late":late}
	detailed = false

func began_at(t: int) -> void:
	_began = t

## Nothing owed (the dressed stand replaced the bare one).
func reset() -> void:
	gen += 1
	_abort()
	_owed = {}
	coarse_land = false
	detailed = true

## A piece built apart (placed) tagged so the next rebuild keeps it.
func tag_piece(m: RefCounted, k: int, node: Node3D) -> void:
	_tag(node,_base(m.data,m.data.pieces[k]),piece_key(m,k))

## Each frame: a landed job swapped in; an owed build started once the
## hand stops (`settled`).
func step(settled: bool) -> void:
	if not _queue.is_empty():
		_drain(BUDGET_US)
		return
	if not collect(): return
	if _owed.is_empty() or not settled: return
	_start()

## A landed job taken in (swapped, or dropped if a newer rebuild came);
## false while it still runs. Also called while playing (play drops it).
func collect() -> bool:
	if job.is_empty(): return true
	if not WorkerThreadPool.is_task_completed(int(job.task)): return false
	WorkerThreadPool.wait_for_task_completion(int(job.task))
	var done := job
	job = {}
	if int(done.gen) == gen: _swap(done)
	else: _drop(done)
	return true

## Full detail now (play): no worker, everything owed built here.
func finish_now() -> void:
	_drain(1 << 40)
	if detailed: return
	var owed := _owed
	if not job.is_empty():
		# The worker's build is left to land and be dropped (never waited
		# on from here: its renderer calls wait on this thread); what it
		# was building is built here.
		gen += 1
		owed = {"land":job.land,"late":job.late}
	_owed = {}
	if owed.is_empty(): owed = {"land":coarse_land,"late":[]}
	var done := {"gen":gen,"out":_build(_job_motif(),owed),"late":owed.late,"land":owed.land}
	_swap(done)
	_drain(1 << 40)

func busy() -> bool:
	return not detailed

func _job_motif() -> RefCounted:
	var m: RefCounted = MotifAuthored.from_data(study.data.duplicate(true))
	m.ground_fn()
	return m

## What a job builds: {"land": Node3D?, "P3": node, "Run0": node}.
static func _build(m: RefCounted, owed: Dictionary) -> Dictionary:
	var out := {}
	if bool(owed.land): out.land = m.build_land(false)
	for it: Array in owed.late:
		var node: Node3D = m.make_piece(int(it[1])) if str(it[0]) == "P" else m.make_run(int(it[1]))
		if node != null: out["%s%d" % [str(it[0]),int(it[1])]] = node
	return out

func _start() -> void:
	var owed := _owed
	_owed = {}
	var m := _job_motif()
	var out := {}
	var done := {"gen":gen,"out":out,"late":owed.late,"land":owed.land}
	if not threaded:
		done.out = _build(m,owed)
		_swap(done)
		return
	done.task = WorkerThreadPool.add_task(func() -> void:
		var o := _build(m,owed)
		for key: String in o: out[key] = o[key],false,"Motif editor detail")
	job = done

func _drop(done: Dictionary) -> void:
	for key: String in done.out:
		var n: Variant = done.out[key]
		if n is Node and is_instance_valid(n): (n as Node).free()
	# What it was for is still owed (a newer rebuild owes its own).

## A finished build stood in place of the coarse land and the stale
## pieces, spread over frames (`_drain`): the new land's parts entered one
## at a time beside the old (its collision shapes are the cost, ~40 ms
## whole), then the old land freed, then each piece, then the ropes.
func _swap(done: Dictionary) -> void:
	var out: Dictionary = done.out
	var bare: Node3D = study.bare
	if bare == null:
		_drop(done)
		return
	_queue.clear()
	if out.has("land"):
		var land: Node3D = out.land
		land.name = "HillIn"
		var parts: Array = land.get_children()
		for c: Node in parts: land.remove_child(c)
		_hill_in = land
		_queue.append([func() -> void: bare.add_child(land),land])
		for c: Node in parts: _queue.append([func() -> void: land.add_child(c),c])
		_queue.append([func() -> void:
			var old := bare.get_node_or_null("Hill")
			if old != null:
				bare.remove_child(old)
				old.free()
			land.name = "Hill"
			bare.move_child(land,0)
			for body: StaticBody3D in KitLand.turf_bodies(land): body.collision_layer |= study.TURF_LAYER
			# Painted from the stand down (its "Hill" reads as land, not stone).
			if not study.dressed and study.grey != null:
				for gi: Node in land.find_children("*","GeometryInstance3D",true,false): study.grey.paint_one(gi as GeometryInstance3D,bare)
			_hill_in = null
			coarse_land = false,null])
	var holder: Node3D = bare.get_node_or_null("Pieces")
	for it: Array in done.late:
		var name := "%s%d" % [str(it[0]),int(it[1])]
		var node: Node3D = out.get(name)
		if node == null or holder == null: continue
		var key := str(it[2])
		var k := int(it[1])
		var kind := str(it[0])
		_queue.append([func() -> void:
			var old := holder.get_node_or_null(name)
			var base := ""
			if old != null:
				base = str(old.get_meta("rb_base",""))
				holder.remove_child(old)
				old.free()
			if base == "": base = _base(study.data,study.data.pieces[k]) if kind == "P" else run_base(study.motif,k)
			_tag(node,base,key)
			node.name = name
			holder.add_child(node)
			study._grey_new(node)
			built += 1,node])
	_queue.append([func() -> void:
		detailed = true
		detail_ms = Time.get_ticks_msec()-_began
		study.full_ms = detail_ms
		study.hang_ropes(),null])

## The swap's steps run for up to `budget_us` (at least one); the longest
## step's cost kept in `swap_us`.
func _drain(budget_us: int) -> void:
	var t0 := Time.get_ticks_usec()
	while not _queue.is_empty():
		var t := Time.get_ticks_usec()
		var it: Array = _queue.pop_front()
		(it[0] as Callable).call()
		swap_us = maxi(swap_us,Time.get_ticks_usec()-t)
		if Time.get_ticks_usec()-t0 > budget_us: break

## A swap under way given up (a newer rebuild): its nodes not yet stood freed.
func _abort() -> void:
	for it: Array in _queue:
		var n: Variant = it[1]
		if n is Node and is_instance_valid(n) and (n as Node).get_parent() == null: (n as Node).free()
	_queue.clear()
	if _hill_in != null and is_instance_valid(_hill_in): _hill_in.free()
	_hill_in = null
