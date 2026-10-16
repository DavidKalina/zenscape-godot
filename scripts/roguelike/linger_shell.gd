extends RefCounted
## The drawn world, for the linger serpent's body (docs/design/roguelike/
## linger-serpent-round3.md): what you see clip is the drawn stone, not the
## collision (an isle's hanging sides and keel, a column's shaft under a
## crossing, a pier, a hillside are drawn and not collided; collision is
## the walkable tops). So the serpent keeps its own physics space, apart
## from the game's (nothing else sees it): every drawn mesh of the layer
## near him big enough to matter, as a static trimesh, built a few a frame
## as the layer streams in round him, moved when its mesh moves, dropped
## when its mesh goes.
##
## The rings and the head's way ask it (`state`) as they would the game's
## space.

## Meshes further than NEAR m from him wait; smaller than SMALL m across
## are left out (a lamp, a tuft, a pebble), and lights, haze, fire, water,
## grass and the like by name.
const NEAR := 360.0
const SMALL := 2.2
const SKIP := ["Halo","Haze","Glow","Fire","Flame","Fog","Cloud","Smoke","Water","Sky","Ribbon","Grass","Shadow","Light","Spark","Dust","Mote","Ember","Torch","Rope","Vine","Root","Leaf","Fern","Moss","Banner","Cloth","Flag","Rune","Fly","Bird","Moth"]
## Rescan the tree every SCAN s; build for at most BUDGET_US µs a frame.
const SCAN := 2.0
const BUDGET_US := 1500
## Meshes of more triangles than this are left out. Under these nodes (by
## name) things move: left out.
const MOST_TRIS := 200000
## Meshes of more triangles than this (a toppled colossus's stand-in, 89k)
## stand in as their box: what the body lies over, at a fraction of the
## memory and the time (never a ground: a hillside's box would fill its
## hollows).
const HULL_TRIS := 60000
const MOVING := ["EnemyField","Enemies","Pickups","Loot","Merchant","Flyer","Pilot","Figure","Plane"]

var space: RID
var root: Node
var skip_under: Array[Node] = []
## Instance id -> [node, its (first) body, its shape or pieces [body, shape],
## the transform it was built at, its faces].
var _bodies := {}
var _queue: Array[int] = []
## Big meshes built a piece a frame: [instance id, its faces, next face].
var _chunks: Array = []
## Meshes that may stand in (instance ids), the scene listed once, and the
## ones added to the tree since.
var _cands := {}
var _listed := false
var _added: Array[int] = []
var _later: Array[int] = []
## Meshes seen moving, never built again.
var _moving := {}
var _scan_t := 0.0
## Counts, for drivers.
var built := 0
var triangles := 0
var build_usec := 0
var worst_add_usec := 0
var worst_add := ""
var scan_usec := 0

func _init(scene_root: Node, skips: Array[Node]) -> void:
	root = scene_root
	skip_under = skips
	space = PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space,true)

func state() -> PhysicsDirectSpaceState3D:
	return PhysicsServer3D.space_get_direct_state(space)

func free_all() -> void:
	for id: int in _bodies: _free_rec(_bodies[id])
	_bodies.clear()
	if space.is_valid(): PhysicsServer3D.free_rid(space)
	space = RID()

## A frame: rescan now and then, then build from the queue (nearest
## `near` first) within the budget.
func step(delta: float, near: Vector3) -> void:
	if root == null or not is_instance_valid(root): return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN
		var s0 := Time.get_ticks_usec()
		_scan(near)
		scan_usec = maxi(scan_usec,Time.get_ticks_usec()-s0)
	var began := Time.get_ticks_usec()
	# The meshes added since, judged a few a frame (one not dressed yet, no
	# mesh, asked again later).
	var judged := 0
	while not _added.is_empty() and judged < JUDGE_A_FRAME:
		var id: int = _added.pop_back()
		judged += 1
		if _consider(id) == 1: _later.append(id)
	if _added.is_empty() and not _later.is_empty() and _scan_t >= SCAN-delta:
		_added = _later
		_later = []
	while (not _chunks.is_empty() or not _queue.is_empty()) and Time.get_ticks_usec()-began < BUDGET_US:
		var t0 := Time.get_ticks_usec()
		var what := ""
		if not _chunks.is_empty():
			what = _chunk_step()
		else:
			var mi := instance_from_id(_queue.pop_back()) as MeshInstance3D
			if mi == null or not is_instance_valid(mi) or not mi.is_inside_tree(): continue
			_add(mi)
			what = str(mi.get_path()).right(70)
		var took := Time.get_ticks_usec()-t0
		if took > worst_add_usec:
			worst_add_usec = took
			worst_add = what
	build_usec = Time.get_ticks_usec()-began

func _scan(near: Vector3) -> void:
	# Gone or moved.
	for id: int in _bodies.keys():
		var rec: Array = _bodies[id]
		var node: Node3D = instance_from_id(id) as Node3D
		if node == null or not is_instance_valid(node) or not node.is_inside_tree() or not node.is_visible_in_tree():
			_free_rec(rec)
			_bodies.erase(id)
			continue
		# Moved: dropped, for good (a thing that moves is not the world).
		if not node.global_transform.is_equal_approx(rec[3]):
			_free_rec(rec)
			_bodies.erase(id)
			_moving[id] = true
	# The meshes: all of them once, then the ones added since (the layer
	# streams in round him), each judged once (`_skipped`), the rest asked
	# only how near they are.
	if not _listed:
		_listed = true
		for n: Node in root.find_children("*","MeshInstance3D",true,false): _added.append(n.get_instance_id())
		if root.is_inside_tree(): root.get_tree().node_added.connect(_on_added)
	var found: Array = []
	for id: int in _cands.keys():
		var mi := instance_from_id(id) as MeshInstance3D
		if mi == null or not is_instance_valid(mi) or not mi.is_inside_tree():
			_cands.erase(id)
			continue
		if _bodies.has(id) or _moving.has(id) or mi.mesh == null or not mi.is_visible_in_tree(): continue
		var box := mi.global_transform*mi.get_aabb()
		var d := _box_dist(box,near)
		if d > NEAR: continue
		found.append([d,mi])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	_queue.clear()
	for f: Array in found: _queue.append((f[1] as Node).get_instance_id())

func _on_added(n: Node) -> void:
	if n is MeshInstance3D: _added.append(n.get_instance_id())

## Judged: 0 a candidate or never one, 1 ask again (not dressed yet).
func _consider(id: int) -> int:
	var mi := instance_from_id(id) as MeshInstance3D
	if mi == null or not is_instance_valid(mi) or not mi.is_inside_tree(): return 0
	if not root.is_ancestor_of(mi) or _cands.has(id) or mi.skin != null: return 0
	if mi.mesh == null: return 1
	if _skipped(mi): return 0
	var box := mi.global_transform*mi.get_aabb()
	if box.get_longest_axis_size() < SMALL: return 0
	_cands[id] = true
	return 0

func _skipped(mi: MeshInstance3D) -> bool:
	var nm := String(mi.name)
	for s: String in SKIP:
		if nm.contains(s): return true
	var p := mi.get_parent()
	if p != null:
		var pn := String(p.name)
		for s: String in SKIP:
			if pn.contains(s): return true
	var path := str(mi.get_path())
	for s: String in MOVING:
		if path.contains(s): return true
	if _tris(mi.mesh) > MOST_TRIS: return true
	for under: Node in skip_under:
		if is_instance_valid(under) and (under == mi or under.is_ancestor_of(mi)): return true
	return false

const SLIVER_CHECK := 3000
## A mesh's faces are built this many a piece, a piece a step.
const CHUNK_TRIS := 2000
## Meshes newly in the tree judged a frame.
const JUDGE_A_FRAME := 120
static func _solid_faces(f: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(0,f.size()-2,3):
		if (f[i+1]-f[i]).cross(f[i+2]-f[i]).length_squared() > 1e-8:
			out.append(f[i])
			out.append(f[i+1])
			out.append(f[i+2])
	return out

static func _tris(m: Mesh) -> int:
	var am := m as ArrayMesh
	if am == null: return 0
	var n := 0
	for i in range(am.get_surface_count()):
		if am.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES: continue
		var idx := am.surface_get_array_index_len(i)
		n += (idx if idx > 0 else am.surface_get_array_len(i))/3
	return n

static func _box_dist(box: AABB, p: Vector3) -> float:
	var q := p.clamp(box.position,box.end)
	return q.distance_to(p)

## Its triangles laid in the world (a scaled body is not every engine's),
## one static body.
func _add(mi: MeshInstance3D) -> void:
	var xf := mi.global_transform
	var tris := _tris(mi.mesh)
	if tris > HULL_TRIS:
		# Its box, turned and placed as it is (no scale in a body).
		var aabb := mi.get_aabb()
		var bx := BoxShape3D.new()
		var sc := xf.basis.get_scale()
		bx.size = (aabb.size*sc).max(Vector3.ONE*0.2)
		var body0 := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body0,PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_add_shape(body0,bx.get_rid())
		PhysicsServer3D.body_set_space(body0,space)
		PhysicsServer3D.body_set_state(body0,PhysicsServer3D.BODY_STATE_TRANSFORM,Transform3D(xf.basis.orthonormalized(),xf*aabb.get_center()))
		_bodies[mi.get_instance_id()] = [mi,body0,bx,xf,12]
		built += 1
		triangles += 12
		return
	var faces: PackedVector3Array = xf*mi.mesh.get_faces()
	# A small mesh may be all slivers (a line, a flat card edge on): the
	# engine refuses a shape of none.
	if faces.size() <= SLIVER_CHECK*3: faces = _solid_faces(faces)
	if faces.size() < 3:
		_bodies[mi.get_instance_id()] = [mi,RID(),null,xf,0]
		return
	tris = faces.size()/3
	# Its record, its bodies (one a piece), built a piece a frame.
	_bodies[mi.get_instance_id()] = [mi,RID(),[],xf,tris]
	_chunks.append([mi.get_instance_id(),faces,0])
	built += 1
	triangles += tris

## The next piece (CHUNK_TRIS faces) of the first big mesh waiting.
func _chunk_step() -> String:
	var job: Array = _chunks[0]
	var id: int = job[0]
	if not _bodies.has(id):
		_chunks.pop_front()
		return ""
	var faces: PackedVector3Array = job[1]
	var from: int = job[2]
	var to := mini(from+CHUNK_TRIS*3,faces.size())
	var trimesh := ConcavePolygonShape3D.new()
	trimesh.backface_collision = true
	trimesh.set_faces(faces.slice(from,to))
	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body,PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(body,trimesh.get_rid())
	PhysicsServer3D.body_set_space(body,space)
	var rec: Array = _bodies[id]
	if not (rec[1] as RID).is_valid(): rec[1] = body
	(rec[2] as Array).append([body,trimesh])
	job[2] = to
	if to >= faces.size(): _chunks.pop_front()
	return "piece of %d" % id

## A record's bodies freed.
static func _free_rec(rec: Array) -> void:
	if rec[2] is Array:
		for piece: Array in rec[2]: PhysicsServer3D.free_rid(piece[0])
	elif (rec[1] as RID).is_valid(): PhysicsServer3D.free_rid(rec[1])

## The mesh a body of this space was built from (drivers).
func mesh_of(body: RID) -> Node:
	for id: int in _bodies:
		var rec: Array = _bodies[id]
		if rec[1] == body: return instance_from_id(id) as Node
		if rec[2] is Array:
			for piece: Array in rec[2]:
				if piece[0] == body: return instance_from_id(id) as Node
	return null

func count() -> int:
	return _bodies.size()
