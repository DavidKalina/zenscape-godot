extends "res://scripts/breaks/break_pieces.gd"
## Any kit piece broken by its kind (spec: docs/design/kit-breaks/
## spec-kit-breaks.md): a breakable for the hub's `others` (scripts/
## breaks/breakables.gd) holding the pieces of a place, each cut by its
## break kind (scripts/breaks/break_kinds.gd) on the first hit strong
## enough to break it. Until then nothing about a piece changes: `adopt`
## only notes where it stands.
##
## A hit (`hit`, or the Olmec's bulk through `met`) on a piece: it is built
## again in its kind's parts (what stands, the falling parts), the whole
## swapped for what stands, the parts let go as bodies (the base's fall,
## cap, rubble and `changed`), out from where it was hit.
const Kinds = preload("res://scripts/breaks/break_kinds.gd")
## A big body's bulk about its feet, times its height `hh` (the Olmec's:
## scripts/enemies/headless_body.gd BULK_W, BULK_L, at archive/before-the-cut).
const BULK_W := 1.0
const BULK_L := 0.5
## A stack going over: its turn at first (rad/s), more for his push (m/s).
const TOPPLE_W := 0.55
const TOPPLE_PUSH := 0.12
## A breaker this near a piece (m, past his bulk) has its cut made ahead,
## one build a frame, so the hit only swaps it in.
const WAKE := 9.0
## A pre-cut serves a hit this near (m, the piece's frame) the point it guessed.
const PRE_TOL := 1.5

## A piece broken (a kit cache's cue: scripts/kit_isle/kit_caches.gd):
## its node, whole and in the tree still, and where it was hit (world).
signal broke(node: Node3D, at: Vector3)
## A `hit` in reach of a piece too tough for it: its node, the piece's
## point nearest the hit (world), the hit's strength and source.
signal withstood(node: Node3D, at: Vector3, strength: float, source: StringName)

## The pieces: [{node, kind, tough, box (its frame), xf, seed, rebuild, alive}].
var targets: Array = []
## Pieces broken, and the cut of the last (ms).
var broken := 0
## Pre-cuts: made ahead, used by a hit, thrown away (guessed wrong), and
## the longest frame's build for one (ms).
var pre_made := 0
var pre_used := 0
var pre_missed := 0
var pre_step_ms := 0.0

## Ready mode (`prepare_all`, opt-in): every piece's cut made ahead on a
## worker, from the start, at its middle (READY_UP of its height), so a
## hit only swaps it in: no cut is made on the main thread, nor guessed
## as he nears. A hit on a piece whose cut isn't made yet waits for it
## (his bulk leans on it; a landing's hit lands when it's made).
var ready_all := false
## At most this many cuts building on workers at once (the rest queued,
## the nearest the breaker first; a hit waiting on one begins it at once).
## One: two GDScript builds side by side each ran 6-10x slower (a span's
## whole build 2.4-2.8 s on each of three workers, 0.4 s alone).
const READY_AT_ONCE := 1
const READY_UP := 0.5
## Where the breaker was last and where he is going (his bulk's `met`:
## his place and the last he saw you): the queue's nearest to either first.
var _near: Array[Vector3] = []
## Hits waiting on their cut: target index -> [at, dir].
var _deferred := {}

## Ready mode on (see `ready_all`): every target's cut queued for its
## worker now, and every target added later (what stands of a broken one).
func prepare_all() -> void:
	ready_all = true
	for i in range(targets.size()): _ready_job(i,Vector3.INF)

## Target `i`'s cut queued (threaded), hit at `at` (world; at its middle's
## height with `mid`), or at its middle for INF; none if it has one.
func _ready_job(i: int, at: Vector3, mid := false) -> void:
	var t: Dictionary = targets[i]
	if not t.alive or not (t.pre as Dictionary).is_empty() or not is_instance_valid(t.node): return
	t.threaded = true
	var box: AABB = t.box
	var local := Vector3(box.get_center().x,box.position.y+box.size.y*READY_UP,box.get_center().z)
	if at != Vector3.INF:
		local = (t.node as Node3D).global_transform.affine_inverse()*at
		if mid: local.y = box.position.y+box.size.y*READY_UP
	t.pre = Kinds.job(str(t.kind),{"node":t.node,"box":t.box,"at":local,"dir":Vector3.FORWARD,"seed":t.seed,"rebuild":t.rebuild,"keep":t.keep,"threaded":true})
	if not (t.pre as Dictionary).is_empty(): pre_made += 1

func _process(delta: float) -> void:
	super._process(delta)
	if ready_all: _ready_step()

## Ready mode, each frame: workers' asks served, finished cuts noted, the
## queue's nearest begun while under READY_AT_ONCE, and the hits that
## waited on a cut now made, landed.
func _ready_step() -> void:
	Kinds.serve()
	var running := 0
	var queued: Array = []
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		var j: Dictionary = t.pre
		if not t.alive or j.is_empty() or Kinds.done(j): continue
		if int(j.ctl.task) >= 0:
			if not Kinds.step(j): running += 1
		else: queued.append(i)
	if running < READY_AT_ONCE and not queued.is_empty():
		if not _near.is_empty():
			queued.sort_custom(func(a: int, b: int) -> bool: return _ready_d(a) < _ready_d(b))
		for k in range(mini(READY_AT_ONCE-running,queued.size())): Kinds.step(targets[queued[k]].pre)
	if _deferred.is_empty(): return
	var any := false
	for i: int in _deferred.keys():
		var t: Dictionary = targets[i]
		if not t.alive:
			_deferred.erase(i)
			continue
		if not Kinds.done(t.pre): continue
		var w: Array = _deferred[i]
		_deferred.erase(i)
		if _break(i,w[0],w[1],Vector3.ZERO,null): any = true
	if any: _pause()

## Target `i`'s distance from the nearest of `_near` (m).
func _ready_d(i: int) -> float:
	var best := INF
	for p: Vector3 in _near: best = minf(best,_nearest(targets[i],p).distance_to(p))
	return best

## Every piece at or under `root` with a kind (Kinds `kind_of`) noted as a
## target. Returns how many were added. A piece with meta "breakable" false
## (the motif editor's toggle, per piece or per motif) is left out, and so
## is everything under it.
func adopt(root: Node) -> int:
	var n := 0
	var all: Array[Node] = [root]
	all.append_array(root.find_children("*","Node3D",true,false))
	for node: Node in all:
		if not node is Node3D: continue
		if not node.has_meta("kit_piece") and not node.has_meta("break_kind"): continue
		if _held(node,root): continue
		var kind := Kinds.kind_of(node)
		if kind == "" or not Kinds.has(kind): continue
		if add(node as Node3D,kind) >= 0: n += 1
	return n

## Whether `node`, or anything over it up to `root`, is marked unbreakable.
static func _held(node: Node, root: Node) -> bool:
	var at := node
	while at != null:
		if at.has_meta("breakable") and not bool(at.get_meta("breakable")): return true
		if at == root: return false
		at = at.get_parent()
	return false

## `node` a target of `kind`; `rebuild` builds it again (honouring RuinKit
## Build.keep_only): by default its "kit_piece" recipe. Its index, or -1.
func add(node: Node3D, kind: String, rebuild := Callable(), seed_value := -1) -> int:
	var box := _box_of(node)
	if box.size == Vector3.ZERO: return -1
	var recipe: Array = node.get_meta("kit_piece",[]) as Array
	# A RuinKit recipe's pre-cut builds on a worker (bar the aqueduct's,
	# whose water makes its own meshes mid-build).
	var threaded := false
	if not rebuild.is_valid() and recipe.size() == 3:
		rebuild = func() -> Node3D: return RuinKit.piece(str(recipe[0]),int(recipe[1]),float(recipe[2]))
		threaded = not str(recipe[0]) in RuinKit.AQUEDUCT_PIECES
	if seed_value < 0: seed_value = int(recipe[1]) if recipe.size() == 3 else hash(node.name)
	targets.append({"node":node,"kind":kind,"tough":Kinds.toughness(node,kind),"box":box,"seed":seed_value,
		"rebuild":rebuild,"alive":true,"pre":{},"keep":Callable(),"threaded":threaded})
	_refresh_rids()
	return targets.size()-1

## Its stone's bounds in its own frame (every mesh under it).
func _box_of(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := node.global_transform.affine_inverse() if node.is_inside_tree() else Transform3D.IDENTITY
	for m: Node in node.find_children("*","MeshInstance3D",true,false):
		var mi := m as MeshInstance3D
		if mi.mesh == null: continue
		var xf := inv*mi.global_transform if node.is_inside_tree() else _local_of(node,mi)
		var b := xf*mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

func _local_of(node: Node3D, under: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var up: Node = under
	while up != node and up is Node3D:
		xf = (up as Node3D).transform*xf
		up = up.get_parent()
	return xf

## The bodies of what stands and breaks to him (his rays look through them,
## he walks into them): pieces he is strong enough for that aren't ground.
func _standing_bodies() -> Array[RID]:
	var out: Array[RID] = []
	var olmec := float(hub.strength_of(&"olmec")) if hub != null else 1.0
	for t: Dictionary in targets:
		if not t.alive or float(t.tough) > olmec or str(t.kind) in ["slab","stair"]: continue
		if not is_instance_valid(t.node): continue
		var node: Node3D = t.node
		for b: Node in node.find_children("*","CollisionObject3D",true,false): out.append((b as CollisionObject3D).get_rid())
	return out

## The world point of target `t` nearest `at`.
func _nearest(t: Dictionary, at: Vector3) -> Vector3:
	var xf: Transform3D = (t.node as Node3D).global_transform
	var box: AABB = t.box
	var lp := xf.affine_inverse()*at
	return xf*Vector3(clampf(lp.x,box.position.x,box.end.x),clampf(lp.y,box.position.y,box.end.y),clampf(lp.z,box.position.z,box.end.z))

# --- The hub's calls --------------------------------------------------------------------------

func hit(at: Vector3, radius: float, strength: float, source: StringName) -> int:
	var n := 0
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		if not t.alive or not is_instance_valid(t.node): continue
		var q := _nearest(t,at)
		if q.distance_to(at) > radius: continue
		if strength < float(t.tough):
			withstood.emit(t.node,q,strength,source)
			continue
		var out := Vector3(q.x-at.x,0.0,q.z-at.z)
		var centre: Vector3 = (t.node as Node3D).global_transform*(t.box as AABB).get_center()
		if out.length() < 0.05: out = Vector3(centre.x-at.x,0.0,centre.z-at.z)
		if _break(i,q,out.normalized() if out.length() > 0.05 else Vector3.FORWARD,Vector3.ZERO,null): n += 1
	if n > 0: _pause()
	return n

## His bulk this frame: a piece he's strong enough for that it touches
## breaks where it meets him, over the way he goes.
func met(body: Node3D) -> void:
	Kinds.serve()
	var olmec := float(hub.strength_of(&"olmec")) if hub != null else 1.0
	var hh: float = body.hh
	var hw := hh*BULK_W
	var hl := hh*BULK_L
	var low: float = body.position.y+0.3
	var high: float = body.position.y+float(body._bulk_top())
	var inv := Basis(Vector3.UP,float(body.facing)).inverse()
	var fwd: Vector3 = body._forward3()
	_near = [body.position]
	var aim: Variant = body.get("seen_at")
	if aim is Vector3 and (aim as Vector3).is_finite(): _near.append(aim)
	if not ready_all: _wake(body,olmec,(low+high)*0.5,fwd,hw,hl)
	var any := false
	var mid := Vector3(body.position.x,(low+high)*0.5,body.position.z)
	var touched := {}
	var read := false
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		if not t.alive or not is_instance_valid(t.node) or olmec < float(t.tough): continue
		var q := _nearest(t,mid)
		if q.y < low or q.y > high: continue
		var rel := inv*(q-body.position)
		if absf(rel.x) > hw or absf(rel.z) > hl: continue
		# What stands of a broken piece (or one whose box met him with no
		# stone there) is much air in its box: it meets him only where a
		# block of it is in his bulk, and breaks there, low enough that
		# the block goes.
		if _by_block(t):
			if not read:
				touched = _touched(body,low,high,hw,hl)
				read = true
			var at: Variant = _block_in(t,touched,mid)
			if at == null: continue
			q = at
			# Its cut made a build a frame first (he leans on it a beat),
			# not all in this one.
			prepare(i,q)
			if not Kinds.done(t.pre):
				_step_pre(i)
				continue
		elif bool(t.threaded):
			# Its cut still building on its worker (or none guessed): he
			# leans on it till it's made, not a fresh cut in this frame.
			prepare(i,q)
			if not Kinds.done(t.pre):
				_step_pre(i)
				continue
		if _break(i,q,fwd,body.vel,body): any = true
	if any: _pause()

## Whether target `t` meets him by its blocks, not its box: what stands of
## a broken piece, or one whose box met him with no stone there.
func _by_block(t: Dictionary) -> bool:
	return (t.keep as Callable).is_valid() or int(t.get("duds",0)) > 0

## The blocks his bulk is in: {Body RID: [shape index]}.
func _touched(body: Node3D, low: float, high: float, hw: float, hl: float) -> Dictionary:
	var box := BoxShape3D.new()
	box.size = Vector3(hw*2.0,high-low,hl*2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis(Vector3.UP,float(body.facing)),Vector3(body.position.x,(low+high)*0.5,body.position.z))
	q.exclude = rubble_rids()
	var out := {}
	for h: Dictionary in get_world_3d().direct_space_state.intersect_shape(q,64):
		var rid: RID = h.rid
		if not out.has(rid): out[rid] = []
		(out[rid] as Array).append(int(h.shape))
	return out

## Of target `t`'s blocks in `touched`, the middle (world) of the one
## nearest `mid`, or null.
func _block_in(t: Dictionary, touched: Dictionary, mid: Vector3) -> Variant:
	var best: Variant = null
	var best_d := INF
	for b: Node in (t.node as Node).find_children("*","CollisionObject3D",true,false):
		var co := b as CollisionObject3D
		if not touched.has(co.get_rid()): continue
		for idx: int in touched[co.get_rid()]:
			var owner_id := co.shape_find_owner(idx)
			var holder := co.shape_owner_get_owner(owner_id) as CollisionShape3D
			if holder == null or not holder.shape is ConvexPolygonShape3D: continue
			var pts := (holder.shape as ConvexPolygonShape3D).points
			if pts.is_empty(): continue
			var c := Vector3.ZERO
			var lo := INF
			for p: Vector3 in pts:
				c += p
				lo = minf(lo,(holder.global_transform*p).y)
			var w := holder.global_transform*(c/pts.size())
			var d := w.distance_to(mid)
			if d < best_d:
				best_d = d
				best = _under(t,w,lo)
	return best

## `w` (a block's middle, world) lowered to the hit height whose stump line
## (its kind's share of it, less the line's wobble) is under `lo`, the
## block's foot: the block falls.
func _under(t: Dictionary, w: Vector3, lo: float) -> Vector3:
	var shape: Dictionary = Kinds.SHAPES.get(str(t.kind),{})
	var share := float(shape.get("stump",-1.0))
	if share <= 0.0: return w
	var xf := (t.node as Node3D).global_transform
	var local := xf.affine_inverse()*w
	var floor_y: float = (t.box as AABB).position.y
	var foot := (xf.affine_inverse()*Vector3(w.x,lo,w.z)).y
	local.y = floor_y+maxf(foot-0.65-floor_y,0.0)/share
	return xf*local

func wave(_body: Node3D, _w: Dictionary) -> void:
	pass

func veer(_body: Node3D, heading: float) -> float:
	return heading

func ahead(_body: Node3D) -> bool:
	return false

func smash(_body: Node3D) -> void:
	pass

# --- Pre-cuts ---------------------------------------------------------------------------------

## The pieces within WAKE that his way meets get their cut guessed where
## his bulk will meet them (his middle's height, along the way he faces),
## and one build of the nearest unfinished one is made this frame.
func _wake(body: Node3D, olmec: float, mid_y: float, fwd: Vector3, hw: float, hl: float) -> void:
	var best := -1
	var best_d := INF
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		if not t.alive or not is_instance_valid(t.node) or olmec < float(t.tough): continue
		# Cut where a block of it meets him (met), not guessed from its box.
		if _by_block(t): continue
		var from := Vector3(body.position.x,mid_y,body.position.z)
		var q := _nearest(t,from)
		var d := Vector2(q.x-from.x,q.z-from.z).length()
		if d > WAKE+hl: continue
		# Where along his way he comes nearest it.
		var guess := q
		var near := d
		var s := 0.5
		while s <= WAKE+hl:
			var p := from+fwd*s
			var qs := _nearest(t,p)
			var ds := Vector2(qs.x-p.x,qs.z-p.z).length()
			if ds < near:
				near = ds
				guess = qs
			s += 0.5
		# He goes by it: no guess.
		if near > hw+0.5: continue
		# A guess still on his way stands (a way along a face moves the
		# nearest point a lot for a small step).
		if not (t.pre as Dictionary).is_empty():
			var was: Vector3 = (t.node as Node3D).global_transform*(t.pre.t.at as Vector3)
			var rel := Vector2(was.x-from.x,was.z-from.z)
			var f2 := Vector2(fwd.x,fwd.z).normalized()
			if rel.dot(f2) > -hl and absf(rel.cross(f2)) <= hw+0.5: guess = was
		prepare(i,guess)
		if not Kinds.done(t.pre) and d < best_d:
			best_d = d
			best = i
	if best >= 0: _step_pre(best)

## Target `i`'s cut begun for a hit at `at` (world), unless one near it is
## already made or under way. Any breaker may call it ahead of a hit.
func prepare(i: int, at: Vector3) -> void:
	var t: Dictionary = targets[i]
	# Ready mode: a cut once queued serves every hit (none remade).
	if ready_all:
		_ready_job(i,at)
		return
	var local := (t.node as Node3D).global_transform.affine_inverse()*at
	if not (t.pre as Dictionary).is_empty():
		if Kinds.serves(t.pre,local,PRE_TOL): return
		Kinds.drop(t.pre)
		pre_missed += 1
	t.pre = Kinds.job(str(t.kind),{"node":t.node,"box":t.box,"at":local,"dir":Vector3.FORWARD,"seed":t.seed,"rebuild":t.rebuild,"keep":t.keep,"threaded":t.threaded})
	if not (t.pre as Dictionary).is_empty(): pre_made += 1

## One build of target `i`'s pre-cut.
func _step_pre(i: int) -> void:
	var began := Time.get_ticks_usec()
	var served := Kinds.serve_ms
	Kinds.step(targets[i].pre)
	# Less what the step's serve took (counted in Kinds.serve_ms).
	var ms := (Time.get_ticks_usec()-began)/1000.0-(Kinds.serve_ms-served)
	pre_step_ms = maxf(pre_step_ms,ms)
	build_ms += ms

func _exit_tree() -> void:
	for t: Dictionary in targets:
		if t.alive: Kinds.drop(t.pre)
	Kinds.settle_all()

# --- A break --------------------------------------------------------------------------------

## Target `i` cut by its kind where `at` (world) met it, its parts going
## over along `dir` (flat), with `push` (his way) on them; `his` a body its
## parts pass through, or null.
func _break(i: int, at: Vector3, dir: Vector3, push: Vector3, his: Variant) -> bool:
	var t: Dictionary = targets[i]
	# Ready mode: never a cut here; a hit before its cut is made waits.
	if ready_all:
		if (t.pre as Dictionary).is_empty(): _ready_job(i,at)
		if not Kinds.done(t.pre):
			if not (t.pre as Dictionary).is_empty():
				Kinds.step(t.pre)
				_deferred[i] = [at,dir]
			return false
	t.alive = false
	var node: Node3D = t.node
	var xf := node.global_transform
	var inv := xf.affine_inverse()
	var cut_t := {"node":node,"box":t.box,"at":inv*at,"dir":inv.basis*dir,"seed":t.seed,"rebuild":t.rebuild,"keep":t.keep}
	var began := Time.get_ticks_usec()
	var pre: Dictionary = t.pre
	var cut := {}
	if Kinds.serves(pre,cut_t.at as Vector3,PRE_TOL) or (ready_all and not pre.is_empty()):
		Kinds.finish(pre)
		cut = Kinds.result(pre)
		pre_used += 1
	else:
		if not pre.is_empty():
			Kinds.drop(pre)
			pre_missed += 1
		cut = Kinds.cut(str(t.kind),cut_t)
	t.pre = {}
	cut_ms = (Time.get_ticks_usec()-began)/1000.0
	build_ms += cut_ms
	# Nothing falls (what stands of a piece hit where it is already gone):
	# no break. One that keeps coming to nothing stops being a target.
	if cut.is_empty() or (cut.get("parts",[]) as Array).is_empty():
		var st: Variant = cut.get("stands")
		if st is Node3D and is_instance_valid(st) and not (st as Node3D).is_inside_tree(): (st as Node3D).free()
		t.alive = true
		if his == null: return false
		t.duds = int(t.get("duds",0))+1
		if int(t.duds) >= 3:
			t.tough = INF
			_refresh_rids()
		return false
	broken += 1
	broke.emit(node,at)
	var parent := node.get_parent()
	var stands: Node3D = cut.get("stands")
	if stands != null:
		parent.add_child(stands)
		stands.global_transform = xf
		_dress(stands)
	parent.remove_child(node)
	node.queue_free()
	var group := _new_group(at)
	group.stump = stands
	# What stands breaks again: a target of its own, built only of what is
	# left (kept out of the rubble's merged mesh, so its break takes it).
	if stands != null and (cut.get("keep",Callable()) as Callable).is_valid():
		var again := add(stands,str(t.kind),t.rebuild,int(t.seed))
		if again >= 0:
			targets[again].keep = cut.keep
			targets[again].threaded = t.threaded
			targets[again].tough = t.tough
			group.stump = null
			if ready_all:
				_ready_job(again,at,true)
				Kinds.step(targets[again].pre)
	var foot := xf*Vector3((t.box as AABB).get_center().x,(t.box as AABB).position.y,(t.box as AABB).get_center().z)
	var fall: Array = cut.get("parts",[])
	if bool(cut.get("topple",false)):
		_topple(fall,xf,t.box as AABB,at,dir,push,his,group)
		fall = []
	for part: Dictionary in fall:
		var pat: Vector3 = xf*(part.at as Vector3)
		var out := Vector3(pat.x-at.x,0.0,pat.z-at.z)
		var away := (out.normalized()*0.5+dir*0.5).normalized() if out.length() > 0.05 else dir
		var axis := Vector3.UP.cross(away).normalized()
		var high := clampf((pat.y-foot.y)/maxf((t.box as AABB).size.y,0.5),0.0,1.0)
		var ang := axis*_rng.randf_range(0.5,1.0)*(0.6+high)+Vector3.UP*_rng.randf_range(-0.3,0.3)
		var lin := away*_rng.randf_range(0.6,1.4)*(0.5+high)+push*0.3
		var rb := _body_of([{"mesh":part.mesh,"shape":part.shape,"local":Transform3D.IDENTITY,"kg":float(part.kg)}],Transform3D(xf.basis,pat))
		rb.angular_damp = 0.9
		if his is PhysicsBody3D: rb.add_collision_exception_with(his)
		for other: Variant in group.pieces:
			if is_instance_valid(other): rb.add_collision_exception_with(other as RigidBody3D)
		# The top goes a beat after the bottom: it falls on what fell.
		_go_piece(rb,group,str(part.kind),lin,ang,0.08*high,away,high)
	if group.pieces.is_empty(): _settled(group)
	_hit_dust(at)
	Dust.rocks(self,at+Vector3.UP*0.5,dir,10,0.24)
	_sound(&"ruin_crack",at)
	_sound(&"ruin_fall",foot)
	_shake(QUAKE_PIER*1.2)
	_refresh_rids()
	return true

## Parts "<along>_<up>" (the piece's frame, `xf` its place) going over as
## stacks: each along's parts one body about its foot (the colonnade's
## column: slow at first, gravity doing the rest), a beat apart, bursting
## into its parts where it lands.
func _topple(parts: Array, xf: Transform3D, box: AABB, at: Vector3, dir: Vector3, push: Vector3, his: Variant, group: Dictionary) -> void:
	var stacks := {}
	for part: Dictionary in parts:
		var along := str(part.get("id","0_0")).get_slice("_",0)
		if not stacks.has(along): stacks[along] = []
		(stacks[along] as Array).append(part)
	var flat := Vector3(push.x,0.0,push.z)
	var axis := Vector3.UP.cross(dir).normalized()
	var keys := stacks.keys()
	keys.sort()
	for k: int in range(keys.size()):
		var stack: Array = stacks[keys[k]]
		var lo := INF
		var hi := -INF
		var mid := Vector3.ZERO
		var kg := 0.0
		for part: Dictionary in stack:
			var c: Vector3 = part.at
			var half := float((part.size as Vector3).y)*0.5
			lo = minf(lo,c.y-half)
			hi = maxf(hi,c.y+half)
			mid += c*float(part.kg)
			kg += float(part.kg)
		mid /= maxf(kg,1.0)
		var subs: Array = []
		for part: Dictionary in stack:
			subs.append({"mesh":part.mesh,"shape":part.shape,"local":Transform3D(Basis.IDENTITY,(part.at as Vector3)-mid),
				"kg":float(part.kg),"kind":str(part.kind)})
		var rb := _body_of(subs,Transform3D(xf.basis,xf*mid))
		if his is PhysicsBody3D: rb.add_collision_exception_with(his)
		for other: Variant in group.pieces:
			if is_instance_valid(other): rb.add_collision_exception_with(other as RigidBody3D)
		var lever := maxf(mid.y-lo,0.3)
		var high := clampf((mid.y-box.position.y)/maxf(box.size.y,0.5),0.0,1.0)
		var w := TOPPLE_W+TOPPLE_PUSH*flat.length()+_rng.randf_range(-0.1,0.15)
		var ang := axis*w+Vector3.UP*_rng.randf_range(-0.25,0.25)
		var lin := dir*w*lever+flat*0.15
		var whole := subs.size() > 1
		_go_piece(rb,group,"column" if whole else str(stack[0].kind),lin,ang,0.07*k,dir,high)
		var entry: Dictionary = live[-1] if not live.is_empty() and live[-1].rb == rb else {}
		if not entry.is_empty(): entry["soft_air"] = true
		if whole and not entry.is_empty(): entry["burst"] = subs

## What stands of a broken piece, in the tree. A cut rebuilds it from the kit,
## so a look put on the standing piece is put on again here (SmashBreaks).
func _dress(_node: Node3D) -> void:
	pass

## The cloud at the hit.
func _hit_dust(at: Vector3) -> void:
	Dust.plume(self,at,3.2)
