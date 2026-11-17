extends Node3D
## The ruined viaduct on the north-west plain (seed 1, the wilderness): two
## tiers of arches striding about 1.1 km from the ridge's east end at O
## south-south-east across the flat to the hills, from its own pieces
## (art/blender/temple_kit/viaduct_build.py) and the aqueduct's rubble.
##
## The line: O, then U (DIR_DEG from +x, toward +z); a point is O + U*s +
## V*v, V across (U turned a quarter). Lower piers stand every BAY from S0;
## lower span j runs from pier j to pier j+1. The upper tier has two spans
## over each lower one: upper pier m every BAY2 (the even ones over the lower
## piers, the odd ones over the lower crowns), upper span m from upper pier m
## to m+1, over lower span m/2. The lower deck (the tiers' join) is level at
## Y1, the top deck at Y2: the lower piers hang from Y1 into the ground, so
## they grow as the land falls. Where the land rises past a piece at either
## end it is left out, so the viaduct runs into the rises.
##
## The openings, wide enough to weave arch by arch at cruise (in one span,
## turn, back through the next): a lower span is 45.2 m clear and from the
## ground to 3.8 m under Y1 (about 41 m on the plain), its piers 8 m through;
## an upper span 23.6 m clear from Y1 to 4 m under Y2 (20 m). The ruin:
## FALLEN_TOP upper spans have lost their arch (a stub left on one pier);
## FALLEN lower spans have lost both tiers (a stub on one side, the upper
## pier over the crown gone), and STUMPS' piers are down to a stump between
## two fallen spans, so the gap is two bays wide. Rubble under each fallen
## span. END_TOP: the upper spans from it toward the far rise are gone, their
## upper piers stumps.
##
## Drawn and solid as the citadel is (citadel_site.gd): chunks of CHUNK piers,
## each in its own frame on the line, MultiMeshes per piece and LOD gathered on
## a worker and made on the main thread, a chunk at a time; a StaticBody3D on
## LandArches' layer and a `loose` record per chunk. Trees keep off
## (`tree_keepouts`). `--viaduct=0`: none.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const O := Vector2(-3520.0,-3880.0)
const DIR_DEG := 60.0
## viaduct_build.py's numbers.
const BAY := 57.2
const BAY2 := BAY*0.5
const W1 := 12.0
const T1 := 8.0
const W2 := 5.0
const TIER2 := 24.0
const CROWN1 := 3.8
const CROWN2 := 4.0
## The decks (world y).
const Y1 := 30.0
const Y2 := Y1+TIER2
## The first pier's s (pier 1 at s 12, the map's end), and the last pier's index the line may reach.
const S0 := 12.0-BAY
const MAX_PIERS := 22
## The ruin: FALLEN_TOP by upper span, FALLEN by lower span, STUMPS by lower pier.
## Lower spans 5 to 12 stand whole, eight to weave in a row.
const FALLEN_TOP: Array[int] = [12,20,21,33]
const FALLEN: Array[int] = [4,13,14]
const STUMPS: Array[int] = [14]
## Upper spans from this one to the end have lost their arch; the upper piers past it are stumps.
const END_TOP := 37
const CHUNK := 3
## Streaming and LOD (m): a chunk comes in at REACH, a few pixels in the haze,
## so the line never appears whole in view; a piece swaps near -> mid at
## MID_NEAREST and mid -> far at FAR_NEAREST from its set's nearest (plus the
## set's radius from its middle), the far only where a bay is a few pixels;
## a piece with no mid (the rubble) keeps its near to NOMID_NEAREST.
const REACH := 8000.0
const FREE := 8400.0
const MID_NEAREST := 50.0
const FAR_NEAREST := 1000.0
const NOMID_NEAREST := 250.0
const CLEAR_ACROSS := 18.0

var game: Node3D
## Each: {name, xf (world), pieces [[id, xf in its frame]], state, task, made, node, record}.
var chunks: Array = []

static func wanted() -> bool:
	return not ("--viaduct=0" in LaunchArgs.user_args())

static func _u() -> Vector2:
	return Vector2.from_angle(deg_to_rad(DIR_DEG))

static func _v() -> Vector2:
	var u := _u()
	return Vector2(-u.y,u.x)

## The world XZ of (s along, v across).
static func at_sv(s: float, v := 0.0) -> Vector2:
	return O+_u()*s+_v()*v

## The line's frame: +x along U, +z along V, at y 0.
static func frame() -> Transform3D:
	var u := _u()
	return Transform3D(Basis(Vector3.UP,atan2(-u.y,u.x)),Vector3(O.x,0.0,O.y))

static func _g(field: Object, s: float, v := 0.0) -> float:
	var p := at_sv(s,v)
	return float(field.call("height",p.x,p.y))

## The lowest ground over s0..s1 across the piece's width.
static func _low(field: Object, s0: float, s1: float, half: float) -> float:
	var lo := INF
	var n := maxi(2,ceili((s1-s0)/4.0))
	for i in range(n+1):
		var s := lerpf(s0,s1,float(i)/n)
		for v: float in [-half,0.0,half]: lo = minf(lo,_g(field,s,v))
	return lo

static func pier_s(k: int) -> float:
	return S0+k*BAY

static func top_pier_s(m: int) -> float:
	return S0+m*BAY2

## The piers the line runs between: [first, last], the first and last whose
## top deck stands clear of the land, and one more each end into the rise.
static func extent(field: Object) -> Vector2i:
	var first := -1
	var last := -1
	for k in range(MAX_PIERS+1):
		if _g(field,pier_s(k)) < Y2-2.0:
			if first < 0: first = k
			last = k
	return Vector2i(maxi(first-1,0),mini(last+1,MAX_PIERS))

## A piece's frame along the line: at (s, y, v), turned `yaw` about y.
static func _at(s: float, y: float, v := 0.0, yaw := 0.0, size := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),Vector3(s,y,v))

## Every piece in the line's frame: [id, xf, lower pier index for its chunk].
static func layout(field: Object) -> Array:
	var out: Array = []
	var ex := extent(field)
	# The lower piers.
	for k in range(ex.x,ex.y+1):
		var s := pier_s(k)
		if k in STUMPS:
			out.append([&"viaduct_pier_stump",_at(s,_g(field,s)-1.5,0.0,0.4),k])
			continue
		if _low(field,s-W1*0.5,s+W1*0.5,T1*0.5) < Y1+0.5: out.append([&"viaduct_pier",_at(s,Y1),k])
	# The upper piers: none on a stump or over a fallen span's crown.
	for m in range(2*ex.x,2*ex.y+1):
		var s := top_pier_s(m)
		var k := m/2
		if m%2 == 0 and k in STUMPS: continue
		if m%2 == 1 and k in FALLEN: continue
		if _low(field,s-3.0,s+3.0,3.0) >= Y2-1.0: continue
		if m > END_TOP and m < 2*ex.y: out.append([&"viaduct_top_stump",_at(s,Y1,0.0,PI*float(m%2)),k])
		else: out.append([&"viaduct_top_pier",_at(s,Y2),k])
	# The lower spans, and what fell from them.
	for j in range(ex.x,ex.y):
		var s := pier_s(j)+BAY*0.5
		var h := (j*7919)%5
		var low := _low(field,s-BAY*0.4,s+BAY*0.4,T1*0.5)
		var flip := PI if h%2 == 1 else 0.0
		# The stub's side: the left pier's (yaw 0) or the right's (PI), never a stump's.
		var stub := 0.0 if h%2 == 0 else PI
		if j in STUMPS: stub = PI
		if (j+1) in STUMPS: stub = 0.0
		if j in FALLEN:
			if not (j in STUMPS and (j+1) in STUMPS):
				out.append([&"viaduct_arch_broken",_at(s,Y1,0.0,stub),j])
				# The upper span over the stub's pier keeps its own stub.
				var m := 2*j if stub == 0.0 else 2*j+1
				var ms := top_pier_s(m)+BAY2*0.5
				if m < END_TOP: out.append([&"viaduct_top_arch_broken",_at(ms,Y2,0.0,stub),j])
			# Low heaps either side of the line, so a weave through the gap at grass height stays clear.
			for e: Array in [[-15.0,7.0,1.5],[-3.0,-8.0,1.4],[9.0,7.5,1.5],[18.0,-7.0,1.2]]:
				var rs := s+float(e[0])
				var rv := float(e[1])
				out.append([&"aqueduct_rubble",_at(rs,_g(field,rs,rv)-0.9,rv,float(j)*1.7+float(e[0]),float(e[2])),j])
		elif low < Y1-CROWN1-1.0:
			out.append([&"viaduct_arch_b" if h < 2 else &"viaduct_arch",_at(s,Y1,0.0,flip),j])
	# The upper spans over the standing lower ones.
	for m in range(2*ex.x,2*ex.y):
		var j := m/2
		if j in FALLEN: continue
		var s := top_pier_s(m)+BAY2*0.5
		var h := (m*7919)%5
		var low := _low(field,s-BAY2*0.4,s+BAY2*0.4,3.0)
		if low >= Y2-CROWN2-1.0: continue
		var stub := 0.0 if h%2 == 0 else PI
		if m in FALLEN_TOP or m >= END_TOP:
			if m == END_TOP: stub = 0.0
			if m <= END_TOP: out.append([&"viaduct_top_arch_broken",_at(s,Y2,0.0,stub),j])
			if m < END_TOP+2:
				var side := 1.0 if h%2 == 0 else -1.0
				var rs := s+3.0
				var rv := side*13.0
				out.append([&"aqueduct_rubble",_at(rs,_g(field,rs,rv)-0.3,rv,float(m)*2.3,1.2),j])
		else:
			out.append([&"viaduct_top_arch_b" if h >= 3 else &"viaduct_top_arch",_at(s,Y2,0.0,PI if h%2 == 1 else 0.0),j])
	return out

## TreePlan's keep-outs near a world rectangle, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	var out: Array = []
	var u := _u()
	var yaw := atan2(u.x,u.y)
	var k := 0
	while k < MAX_PIERS:
		var k1 := mini(k+CHUNK,MAX_PIERS)
		var c := at_sv((pier_s(k)+pier_s(k1))*0.5)
		if c.x > x0-500.0 and c.x < x1+500.0 and c.y > z0-500.0 and c.y < z1+500.0:
			out.append([c,cos(yaw),sin(yaw),CLEAR_ACROSS,(k1-k)*BAY*0.5+BAY*0.5])
		k = k1
	return out

func setup(g: Node3D) -> void:
	game = g
	var root := frame()
	var by: Dictionary = {}
	for e: Array in layout(game.field):
		var c := int(e[2])/CHUNK
		if not by.has(c): by[c] = []
		(by[c] as Array).append(e)
	var keys: Array = by.keys()
	keys.sort()
	for c: int in keys:
		var mid := (pier_s(c*CHUNK)+pier_s(c*CHUNK+CHUNK))*0.5
		var shift := Transform3D(Basis(),Vector3(mid,0.0,0.0))
		var pieces: Array = []
		for e: Array in by[c]:
			pieces.append([e[0],shift.affine_inverse()*(e[1] as Transform3D)])
		chunks.append({"name":"viaduct/%d" % c,"xf":root*shift,"pieces":pieces,"state":"away","task":-1})
	_load_meshes()

## One frame: the chunks streamed round the eye. `busy`: a temple-kit build is
## running elsewhere (one at a time). Returns whether a chunk is building.
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
					ch.task = WorkerThreadPool.add_task(_make.bind(ch),false,"Viaduct")
					building = true
			"up":
				if d > FREE: _free(ch)
	return building

## On a worker: the chunk's boxes and its sets (one per piece: frames, box, LOD ranges).
func _make(ch: Dictionary) -> void:
	var by_id := {}
	var boxes: Array = []
	var reach := 0.0
	for e: Array in ch.pieces:
		var id: StringName = e[0]
		var xf: Transform3D = e[1]
		if not by_id.has(id): by_id[id] = []
		(by_id[id] as Array).append(xf)
		for box: AABB in TempleKit.boxes(id):
			var b: AABB = xf*box
			boxes.append(b)
			for corner in [Vector2(b.position.x,b.position.z),Vector2(b.end.x,b.end.z),
					Vector2(b.position.x,b.end.z),Vector2(b.end.x,b.position.z)]:
				reach = maxf(reach,(corner as Vector2).length())
	var sets: Array = []
	for id: StringName in by_id:
		var xfs: Array = by_id[id]
		var piece_box: AABB = _piece_box[id]
		var set_box: AABB = xfs[0]*piece_box
		for xf: Transform3D in xfs: set_box = set_box.merge(xf*piece_box)
		var centre := set_box.get_center()
		var radius := 0.0
		for xf: Transform3D in xfs:
			var b: AABB = xf*piece_box
			for k in 8: radius = maxf(radius,b.get_endpoint(k).distance_to(centre))
		var far_at := FAR_NEAREST+radius
		var has_mid := TempleKit.lod(id,TempleKit.MID) != null
		var mid_at := MID_NEAREST+radius if has_mid else minf(NOMID_NEAREST+radius,far_at)
		if not has_mid: far_at = mid_at
		var ranges := [Vector2(0.0,mid_at),Vector2(mid_at,far_at),Vector2(far_at,0.0)]
		for level in 3:
			var m: Mesh = TempleKit.lod(id,level)
			if m == null: continue
			sets.append([m,xfs,set_box,String(id)+(["","_mid","_far"][level] as String),ranges[level]])
	ch.made = {"sets":sets,"boxes":boxes,"reach":reach,"solid":BoxSolid.build(boxes)}

## Each piece's box over its LODs, its meshes loaded on the main thread (setup).
var _piece_box := {}

func _load_meshes() -> void:
	for ch: Dictionary in chunks:
		for e: Array in ch.pieces:
			var id: StringName = e[0]
			if _piece_box.has(id): continue
			var box := AABB()
			var first := true
			for level in [TempleKit.NEAR,TempleKit.MID,TempleKit.FAR]:
				var m: Mesh = TempleKit.lod(id,level)
				if m == null: continue
				box = m.get_aabb() if first else box.merge(m.get_aabb())
				first = false
			_piece_box[id] = box

## On the main thread: the chunk's MultiMeshes, in the tree, its body and its solid.
func _commit(ch: Dictionary) -> void:
	WorkerThreadPool.wait_for_task_completion(int(ch.task))
	ch.task = -1
	var made: Dictionary = ch.made
	ch.erase("made")
	var root := Node3D.new()
	root.name = str(ch.name).replace("/","_")
	TempleKit.fill(root,made.sets)
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
	ch.record = {"name":str(ch.name),"kind":"way","node":root,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
		"solid":made.solid,"reach":float(made.reach)+BoxSolid.grow_most()+10.0,"spec":{},"no_break":true}
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
		ch.erase("made")
