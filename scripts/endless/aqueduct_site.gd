extends Node3D
## The broken aqueduct across the north downs (seed 1, the wilderness): the
## temple kit's aqueduct pieces (art/blender/temple_kit/aqueduct_build.py)
## laid along LINE, one pier every BAY, an arch between each two. The channel
## falls FALL m a metre from DECK0, so the arcade stands tall over the dips
## and sinks to a low wall where the land rises.
##
## The line is cut into chunks of CHUNK piers. Each chunk is one Node3D of
## MultiMeshes (one per piece and LOD, as temple_site.gd), one StaticBody3D of
## its boxes on LandArches' layer (the near-miss rays and the plane's contact)
## and one LandArches `loose` record (the flight's solid). Chunks stand
## within REACH m of the eye, built on a worker one at a time and never while
## a temple-kit way ruin builds (way_towers.gd, which steps this); gone past
## FREE. Trees keep off (`tree_keepouts`). `--aqueduct=0`: none.
##
## To move or extend it: LINE (its corners, smoothed), DECK0 and FALL; the
## breaks are by pier / span number (span k runs from pier k to pier k+1).

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The line's corners, world XZ, start to end: off the big hill's north-west
## flank, over the knoll's west shoulder, down across the two hollows, then
## east along the downs' north side to the pits. Smoothed (Chaikin) so the
## turns run over several spans.
const LINE: Array[Vector2] = [Vector2(-905,-3590),Vector2(-998,-3790),Vector2(-1060,-3960),
	Vector2(-1140,-4120),Vector2(-1150,-4300),Vector2(-1020,-4440),Vector2(-760,-4500),
	Vector2(-480,-4500),Vector2(-170,-4450)]
const SMOOTH := 4
## The deck (the channel walls' top) at the start, m, and its fall per metre.
const DECK0 := 9.0
const FALL := 0.004
## The kit's numbers (aqueduct_build.py).
const BAY := 18.5
const HALF_THICK := 2.5
## Spans gone, a stub left on one pier (+1 on the start's pier, -1 on the end's,
## 0 none) and rubble under.
const MISSING := {21:1,47:-1,58:1,59:-1,66:1}
## The collapsed stretch: these spans down, their piers stumps but LEANS.
const COLLAPSE := Vector2i(38,42)
## Piers leaning (rad, across the line, + to its right).
const LEANS := {41:0.1,59:-0.07}
## Piers per chunk.
const CHUNK := 8
const REACH := 3000.0
const FREE := 3400.0
## The trees' keep-out round each chunk: half across the line (TreePlan adds
## its ARCH_CLEAR, 18 m), and past the line's ends.
const CLEAR_ACROSS := 16.0
const CLEAR_END := 30.0
const MID_NEAREST := 50.0
const FAR_NEAREST := 280.0
## A leaning piece's boxes are cut this tall before they're turned, so their
## bounds stay near the stone.
const LEAN_SLICE := 5.0

var game: Node3D
## Each: {xf (the chunk's frame, world), pieces ([id, local xf]), keep, state, task, made, node, record}.
var chunks: Array = []

static func wanted() -> bool:
	return not ("--aqueduct=0" in LaunchArgs.user_args())

## The line smoothed, then the piers' XZ every BAY along it.
static func piers_xz() -> PackedVector2Array:
	var pts: Array[Vector2] = LINE.duplicate()
	for _i in SMOOTH:
		var out: Array[Vector2] = [pts[0]]
		for k in range(pts.size()-1):
			out.append(pts[k].lerp(pts[k+1],0.25))
			out.append(pts[k].lerp(pts[k+1],0.75))
		out.append(pts[-1])
		pts = out
	var res := PackedVector2Array()
	var seg := 0
	var acc := 0.0
	var s := 0.0
	while true:
		while seg < pts.size()-1 and acc+pts[seg].distance_to(pts[seg+1]) < s:
			acc += pts[seg].distance_to(pts[seg+1])
			seg += 1
		if seg >= pts.size()-1: break
		var L := pts[seg].distance_to(pts[seg+1])
		res.append(pts[seg].lerp(pts[seg+1],(s-acc)/L))
		s += BAY
	return res

## The deck's height at pier k.
static func deck_at(k: int) -> float:
	return DECK0-FALL*BAY*k

## A frame at XZ `p` looking along `d` (local +x along the line), at `y`.
static func _frame(p: Vector2, d: Vector2, y: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,atan2(-d.y,d.x)),Vector3(p.x,y,p.y))

## TreePlan's keep-outs near a world rectangle, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	var out: Array = []
	if not wanted(): return out
	_keep_lock.lock()
	if _keep.is_empty(): _keep = _keepouts()
	var all: Array = _keep
	_keep_lock.unlock()
	for e: Array in all:
		var c: Vector2 = e[0]
		if c.x > x0-500.0 and c.x < x1+500.0 and c.y > z0-500.0 and c.y < z1+500.0: out.append(e)
	return out

## The tree plans run on workers, many cells a second: the keep-outs once.
static var _keep: Array = []
static var _keep_lock := Mutex.new()

static func _keepouts() -> Array:
	var out: Array = []
	var ps := piers_xz()
	var k := 0
	while k < ps.size()-1:
		var k1 := mini(k+CHUNK,ps.size()-1)
		var a: Vector2 = ps[k]
		var b: Vector2 = ps[k1]
		var c := (a+b)*0.5
		var d := (b-a).normalized()
		var half := a.distance_to(b)*0.5+BAY*0.5+(CLEAR_END if k == 0 or k1 == ps.size()-1 else 0.0)
		# Local z along the line (TreePlan's frame: z = (sin, cos)).
		var yaw := atan2(d.x,d.y)
		out.append([c,cos(yaw),sin(yaw),CLEAR_ACROSS,half])
		k = k1
	return out

func setup(g: Node3D) -> void:
	game = g
	var field: Object = game.field
	var ps := piers_xz()
	var n := ps.size()
	var dirs: Array[Vector2] = []
	for k in range(n-1): dirs.append((ps[k+1]-ps[k]).normalized())
	# Every piece, world: [id, xf, lean (a turned piece's boxes sliced)].
	var all: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1931
	for k in range(n):
		var d: Vector2 = (dirs[mini(k,n-2)]+dirs[maxi(k-1,0)]).normalized()
		var p: Vector2 = ps[k]
		var in_collapse := k > COLLAPSE.x and k <= COLLAPSE.y
		if in_collapse and not LEANS.has(k):
			# A stump: on its footprint's lowest ground, sunk a little more.
			var gy := _ground_min(field,p,d,2.0,2.5)-rng.randf_range(0.5,9.0)
			var turn := rng.randf_range(-0.12,0.12)
			all.append([&"aqueduct_pier_broken",_frame(p,d.rotated(turn),gy),false])
			continue
		var xf := _frame(p,d if rng.randf() < 0.5 else -d,deck_at(k))
		if LEANS.has(k):
			# Turned about the line, round its foot on the ground.
			var foot := Vector3(p.x,float(field.call("height",p.x,p.y)),p.y)
			var axis := Vector3(d.x,0.0,d.y)
			var lean := Transform3D(Basis(axis,float(LEANS[k])),Vector3.ZERO)
			xf = Transform3D(Basis(),foot)*lean*Transform3D(Basis(),-foot)*xf
			all.append([&"aqueduct_pier",xf,true])
			continue
		all.append([&"aqueduct_pier",xf,false])
	for k in range(n-1):
		var a: Vector2 = ps[k]
		var b: Vector2 = ps[k+1]
		var m := (a+b)*0.5
		var d: Vector2 = dirs[k]
		var deck := (deck_at(k)+deck_at(k+1))*0.5
		var gone := MISSING.has(k) or (k >= COLLAPSE.x and k <= COLLAPSE.y)
		if not gone:
			var id: StringName = &"aqueduct_arch" if rng.randf() < 0.55 else &"aqueduct_arch_b"
			all.append([id,_frame(m,d if rng.randf() < 0.5 else -d,deck),false])
			continue
		# A stub on the standing pier at the gap's edge.
		var stub := 0
		if MISSING.has(k): stub = int(MISSING[k])
		elif k == COLLAPSE.x: stub = 1
		elif k == COLLAPSE.y and not LEANS.has(k+1): stub = -1
		if stub != 0: all.append([&"aqueduct_arch_broken",_frame(m,d if stub > 0 else -d,deck),false])
		all.append([&"aqueduct_rubble",_on_ground(field,m+d.orthogonal()*rng.randf_range(-2.0,2.0),d.rotated(rng.randf_range(-0.5,0.5)),6.0),false])
	# The broken ends: a stub reaching out past the first and last piers, rubble beyond.
	var d0: Vector2 = dirs[0]
	var d1: Vector2 = dirs[-1]
	all.append([&"aqueduct_arch_broken",_frame(ps[0]-d0*BAY*0.5,-d0,deck_at(0)),false])
	all.append([&"aqueduct_rubble",_on_ground(field,ps[0]-d0*BAY*0.7,d0.rotated(0.4),6.0),false])
	all.append([&"aqueduct_arch_broken",_frame(ps[n-1]+d1*BAY*0.5,d1,deck_at(n-1)),false])
	all.append([&"aqueduct_rubble",_on_ground(field,ps[n-1]+d1*BAY*0.7,d1.rotated(-0.3),6.0),false])
	# Chunks: each piece to the chunk of its nearest pier.
	var k := 0
	while k < n:
		var k1 := mini(k+CHUNK,n)-1
		var a: Vector2 = ps[k]
		var b: Vector2 = ps[k1] if k1 > k else ps[k]+dirs[mini(k,n-2)]
		var c := (a+b)*0.5
		chunks.append({"xf":_frame(c,(b-a).normalized(),0.0),"lo":k,"hi":k1,"pieces":[],"state":"away","task":-1})
		k = k1+1
	for e: Array in all:
		var xf: Transform3D = e[1]
		var at := Vector2(xf.origin.x,xf.origin.z)
		var best := 0
		var bd := INF
		for i in range(n):
			var dd := at.distance_squared_to(ps[i])
			if dd < bd:
				bd = dd
				best = i
		for ch: Dictionary in chunks:
			if best >= int(ch.lo) and best <= int(ch.hi):
				(ch.pieces as Array).append([e[0],(ch.xf as Transform3D).affine_inverse()*xf,e[2]])
				break

## The lowest ground under a footprint (half sizes along and across `d`).
static func _ground_min(field: Object, p: Vector2, d: Vector2, along: float, across: float) -> float:
	var lo := INF
	var q := d.orthogonal()
	for i in [-1.0,0.0,1.0]:
		for j in [-1.0,0.0,1.0]:
			var w: Vector2 = p+d*along*i+q*across*j
			lo = minf(lo,float(field.call("height",w.x,w.y)))
	return lo

## A heap's frame on the ground: at the middle's height, sunk by the fall
## across its reach so the low side doesn't show its underside.
static func _on_ground(field: Object, p: Vector2, d: Vector2, reach: float) -> Transform3D:
	var mid := float(field.call("height",p.x,p.y))
	var lo := _ground_min(field,p,d,reach,reach*0.7)
	return _frame(p,d,mid-minf(mid-lo,2.0)*0.6)

## One frame: the chunks streamed round the eye. `busy`: a temple-kit ruin is
## building (one kit build at a time). Returns whether a chunk is building.
func step(eye: Vector3, busy: bool, here: bool) -> bool:
	var building := false
	for ch: Dictionary in chunks:
		if str(ch.state) == "building":
			if WorkerThreadPool.is_task_completed(int(ch.task)): _commit(ch)
			else: building = true
	for ch: Dictionary in chunks:
		var o: Vector3 = (ch.xf as Transform3D).origin
		var d := Vector2(o.x-eye.x,o.z-eye.z).length() if here else INF
		match str(ch.state):
			"away":
				if d < REACH and not busy and not building:
					ch.state = "building"
					ch.task = WorkerThreadPool.add_task(_make.bind(ch),false,"Aqueduct")
					building = true
			"up":
				if d > FREE: _free(ch)
	return building

## On a worker: the chunk's MultiMeshes off the tree, and its boxes.
func _make(ch: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Aqueduct%d" % int(ch.lo)
	var by_id := {}
	var boxes: Array = []
	var reach := 0.0
	for e: Array in ch.pieces:
		var id: StringName = e[0]
		var xf: Transform3D = e[1]
		if not by_id.has(id): by_id[id] = []
		(by_id[id] as Array).append(xf)
		for box: AABB in TempleKit.boxes(id):
			for part: AABB in (_sliced(box) if e[2] else [box]):
				var b: AABB = xf*part
				boxes.append(b)
				for corner in [Vector2(b.position.x,b.position.z),Vector2(b.end.x,b.end.z),
						Vector2(b.position.x,b.end.z),Vector2(b.end.x,b.position.z)]:
					reach = maxf(reach,(corner as Vector2).length())
	for id: StringName in by_id:
		var xfs: Array = by_id[id]
		var meshes: Array = [TempleKit.lod(id,TempleKit.NEAR),TempleKit.lod(id,TempleKit.MID),
				TempleKit.lod(id,TempleKit.FAR)]
		var piece_box := AABB()
		var first := true
		for m: Mesh in meshes:
			if m == null: continue
			piece_box = m.get_aabb() if first else piece_box.merge(m.get_aabb())
			first = false
		var set_box: AABB = xfs[0]*piece_box
		for xf: Transform3D in xfs: set_box = set_box.merge(xf*piece_box)
		var centre := set_box.get_center()
		var radius := 0.0
		for xf: Transform3D in xfs:
			var b: AABB = xf*piece_box
			for k in 8: radius = maxf(radius,b.get_endpoint(k).distance_to(centre))
		var far_at := FAR_NEAREST+radius
		var mid_at := MID_NEAREST+radius if meshes[1] != null else far_at
		var ranges := [Vector2(0.0,mid_at),Vector2(mid_at,far_at),Vector2(far_at,0.0)]
		for level in 3:
			var m: Mesh = meshes[level]
			if m == null: continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = m
			mm.instance_count = xfs.size()
			for i in range(xfs.size()): mm.set_instance_transform(i,xfs[i])
			mm.custom_aabb = set_box
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.name = String(id)+(["","_mid","_far"][level] as String)
			mmi.visibility_range_begin = ranges[level].x
			mmi.visibility_range_end = ranges[level].y
			root.add_child(mmi)
	ch.made = {"node":root,"boxes":boxes,"reach":reach}

## A box cut into LEAN_SLICE-tall pieces.
static func _sliced(box: AABB) -> Array:
	var out: Array = []
	var y := box.position.y
	while y < box.end.y-0.01:
		var top := minf(y+LEAN_SLICE,box.end.y)
		out.append(AABB(Vector3(box.position.x,y,box.position.z),Vector3(box.size.x,top-y,box.size.z)))
		y = top
	return out

## On the main thread: the chunk in the tree, its body and its solid.
func _commit(ch: Dictionary) -> void:
	WorkerThreadPool.wait_for_task_completion(int(ch.task))
	ch.task = -1
	var made: Dictionary = ch.made
	ch.erase("made")
	var root: Node3D = made.node
	var xf: Transform3D = ch.xf
	root.transform = xf
	add_child(root)
	ch.node = root
	var boxes: Array = made.boxes
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = game.arches.LAYER
	body.collision_mask = 0
	for box: AABB in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	root.add_child(body)
	var yaw := xf.basis.get_euler().y
	ch.record = {"name":"aqueduct/%d" % int(ch.lo),"kind":"way","node":root,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
		"solid":BoxSolid.build(boxes),"reach":float(made.reach)+BoxSolid.grow_most()+10.0,"spec":{},"no_break":true}
	game.arches.loose.append(ch.record)
	GroundNative.bump_loose()
	ch.state = "up"

func _free(ch: Dictionary) -> void:
	game.arches.loose.erase(ch.record)
	GroundNative.bump_loose()
	ch.erase("record")
	if ch.has("node") and is_instance_valid(ch.node): (ch.node as Node).queue_free()
	ch.erase("node")
	ch.state = "away"

func _exit_tree() -> void:
	for ch: Dictionary in chunks:
		if int(ch.task) >= 0: WorkerThreadPool.wait_for_task_completion(int(ch.task))
		ch.task = -1
		if ch.has("made"): ((ch.made as Dictionary).node as Node).free()
