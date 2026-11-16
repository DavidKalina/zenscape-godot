extends Node3D
## The great bridge (seed 1, the wilderness): one stone arch, 116 m clear,
## leaping the gorge south-west of the agora, a gate tower on each bank, the
## deck broken through over the east haunch. Its pieces
## (art/blender/temple_kit/bridge_build.py) are built where they stand in the
## bridge's frame; this lays them, draws and solidifies them.
##
## The frame: origin at the arch's middle, y the world's height; +x along the
## span to the east bank (world (cos 20, sin 20) in x, z), +z across, down the
## gorge. The ring springs at YS, 116 m clear (R 58) and 58 m high, its crown
## 94 m up, 110 m over the gorge's floor; the deck's paving is at YD.
##
## What is flown: under the arch along the gorge; across the bridge through
## the breach in its deck (21 m wide at the deck, open above, between the
## standing deck at u ~41 and the abutment's face at u 63); along the deck
## through both gates (15 m clear, 23.5 m high).
##
## Drawn as the sanctuary is (sanctuary_site.gd): MultiMeshes per piece and LOD
## made on the main thread once a worker has sorted the pieces; one
## StaticBody3D and one LandArches `loose` record in the bridge's frame. Trees
## keep off (`tree_keepouts`), grass keeps off what is built over (`grass_off`).
## `--bridge=0`: none.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const O := Vector2(1225.74,1287.18)
const YAW_DEG := -20.0
## bridge_build.py's numbers.
const YS := 36.0
const R := 58.0
const YD := 104.0
const TOWER_U := 84.0
## The trees' and grass's keep-out: half along (u) and across (v).
const KEEP_HALF := Vector2(96.0,16.0)
const REACH := 3200.0
const FREE := 3600.0
const MID_NEAREST := 50.0
const FAR_NEAREST := 280.0

var game: Node3D
## {root, draws ([id, xf]), state, task, made, nodes, records}.
var site := {}

static func wanted() -> bool:
	return not ("--bridge=0" in LaunchArgs.user_args())

## The span's direction (world XZ) and across it.
static func _u() -> Vector2:
	return Vector2.from_angle(deg_to_rad(-YAW_DEG))

static func _v() -> Vector2:
	var u := _u()
	return Vector2(-u.y,u.x)

## The world XZ of (u, v).
static func at_uv(u: float, v: float) -> Vector2:
	return O+_u()*u+_v()*v

static func frame() -> Transform3D:
	return Transform3D(Basis(Vector3.UP,deg_to_rad(YAW_DEG)),Vector3(O.x,0.0,O.y))

## TreePlan's keep-outs near a world rectangle: [centre XZ, cos, sin, half along, half across].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	if O.x < x0-500.0 or O.x > x1+500.0 or O.y < z0-500.0 or O.y > z1+500.0: return []
	var a := deg_to_rad(YAW_DEG)
	return [[O,cos(a),sin(a),KEEP_HALF.x,KEEP_HALF.y]]

static func _ground(field: Object, u: float, v: float) -> float:
	var p := at_uv(u,v)
	return float(field.call("height",p.x,p.y))

## Every piece in the bridge's frame: [id, xf].
static func layout(field: Object) -> Array:
	var out: Array = []
	out.append([&"bridge_crown",Transform3D()])
	out.append([&"bridge_haunch",Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO)])
	out.append([&"bridge_haunch_broken",Transform3D()])
	out.append([&"bridge_abut_e",Transform3D()])
	out.append([&"bridge_abut_w",Transform3D()])
	out.append([&"bridge_tower",Transform3D(Basis(),Vector3(-TOWER_U,YD,0.0))])
	out.append([&"bridge_tower_broken",Transform3D(Basis(),Vector3(TOWER_U,YD,0.0))])
	# What fell from the breach: heaps on the east bank's slope under it and
	# on the gorge's floor, clear of the arch's way through.
	for e: Array in [[58.0,-14.0,0.4],[66.0,13.0,2.1],[47.0,22.0,1.2],[36.0,-24.0,2.7]]:
		var u := float(e[0])
		var v := float(e[1])
		out.append([&"aqueduct_rubble",Transform3D(Basis(Vector3.UP,float(e[2])),Vector3(u,_ground(field,u,v)-0.4,v))])
	out.append([&"baths_rubble",Transform3D(Basis(Vector3.UP,0.9),Vector3(55.0,_ground(field,55.0,-26.0)-0.4,-26.0))])
	return out

## The grass kept off the abutments' and towers' footprint (endless_grass.gd
## grow_cell, as the sanctuary's: a node there reads as a river's water). Seed 1 only.
static func grass_off(got: Dictionary, land_seed: int, x0: float, z0: float, n: int, pad: int) -> void:
	if land_seed != 1 or not wanted() or not got.has("river"): return
	var gx0 := x0-pad
	var gz0 := z0-pad
	var reach := KEEP_HALF.x+20.0
	if gx0+n-1 < O.x-reach or gx0 > O.x+reach or gz0+n-1 < O.y-reach or gz0 > O.y+reach: return
	var u := _u()
	var w := _v()
	var rs: PackedFloat32Array = got.river
	var i0 := maxi(ceili(O.x-reach-gx0),0)
	var i1 := mini(floori(O.x+reach-gx0),n-1)
	var j0 := maxi(ceili(O.y-reach-gz0),0)
	var j1 := mini(floori(O.y+reach-gz0),n-1)
	for jj in range(j0,j1+1):
		for ii in range(i0,i1+1):
			var d := Vector2(gx0+ii,gz0+jj)-O
			var su := absf(d.dot(u))
			var sv := absf(d.dot(w))
			if su > 54.0 and su < 92.0 and sv < 14.0:
				var k := jj*n+ii
				rs[k] = minf(rs[k],-1.0)
	got.river = rs

func setup(g: Node3D) -> void:
	game = g
	site = {"root":frame(),"draws":layout(game.field),"state":"away","task":-1}
	_load_meshes()

## One frame: the bridge streamed round the eye. `busy`: a temple-kit build is
## running elsewhere (one at a time). Returns whether it is building.
func step(eye: Vector3, busy: bool, here: bool) -> bool:
	var building := false
	if str(site.state) == "building":
		if WorkerThreadPool.is_task_completed(int(site.task)): _commit()
		else: building = true
	var d := Vector2(O.x-eye.x,O.y-eye.z).length() if here else INF
	match str(site.state):
		"away":
			if d < REACH and not busy and not building:
				site.state = "building"
				site.task = WorkerThreadPool.add_task(_make,false,"Bridge")
				building = true
		"up":
			if d > FREE: _free()
	return building

## On a worker: the drawing's sets (one per piece: its frames, box and LOD
## ranges) and the boxes and solid. No resource is made here.
func _make() -> void:
	var by := {}
	var boxes: Array = []
	for e: Array in site.draws:
		var id: StringName = e[0]
		var xf: Transform3D = e[1]
		if not by.has(id): by[id] = []
		(by[id] as Array).append(xf)
		for box: AABB in TempleKit.boxes(id): boxes.append(xf*box)
	var sets: Array = []
	for id: StringName in by:
		var xfs: Array = by[id]
		var piece_box: AABB = _piece_box[id]
		var set_box: AABB = (xfs[0] as Transform3D)*piece_box
		for xf: Transform3D in xfs: set_box = set_box.merge(xf*piece_box)
		var centre := set_box.get_center()
		var radius := 0.0
		for xf: Transform3D in xfs:
			var b: AABB = xf*piece_box
			for k in 8: radius = maxf(radius,b.get_endpoint(k).distance_to(centre))
		var far_at := FAR_NEAREST+radius
		var mid_at := MID_NEAREST+radius if TempleKit.lod(id,TempleKit.MID) != null else far_at
		sets.append({"id":id,"xfs":xfs,"box":set_box,"ranges":[Vector2(0.0,mid_at),Vector2(mid_at,far_at),Vector2(far_at,0.0)]})
	var reach := 0.0
	for b: AABB in boxes:
		for corner in [Vector2(b.position.x,b.position.z),Vector2(b.end.x,b.end.z),
				Vector2(b.position.x,b.end.z),Vector2(b.end.x,b.position.z)]:
			reach = maxf(reach,(corner as Vector2).length())
	site.made = {"sets":sets,"boxes":boxes,"reach":reach,"solid":BoxSolid.build(boxes)}

## Each piece's box over its LODs, its meshes loaded on the main thread (setup).
var _piece_box := {}

func _load_meshes() -> void:
	for e: Array in site.draws:
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

## On the main thread: the MultiMeshes, in the tree, the body and its solid.
func _commit() -> void:
	WorkerThreadPool.wait_for_task_completion(int(site.task))
	site.task = -1
	var made: Dictionary = site.made
	site.erase("made")
	var xf: Transform3D = site.root
	var root := Node3D.new()
	root.name = "BridgeDraw"
	for s: Dictionary in made.sets:
		var id: StringName = s.id
		var xfs: Array = s.xfs
		for level in 3:
			var m: Mesh = TempleKit.lod(id,level)
			if m == null: continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = m
			mm.instance_count = xfs.size()
			for i in range(xfs.size()): mm.set_instance_transform(i,xfs[i])
			mm.custom_aabb = s.box
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.name = "%s%s" % [id,["","_mid","_far"][level]]
			mmi.visibility_range_begin = (s.ranges[level] as Vector2).x
			mmi.visibility_range_end = (s.ranges[level] as Vector2).y
			root.add_child(mmi)
	root.transform = xf
	add_child(root)
	var nodes: Array = [root]
	var records: Array = []
	var list: Array = made.boxes
	if not list.is_empty():
		var body := StaticBody3D.new()
		body.name = "BridgeBody"
		body.collision_layer = game.arches.LAYER
		body.collision_mask = 0
		for box: AABB in list:
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = box.size
			cs.shape = shape
			cs.position = box.get_center()
			body.add_child(cs)
		body.transform = xf
		add_child(body)
		nodes.append(body)
		var yaw := xf.basis.get_euler().y
		var record := {"name":"bridge","kind":"way","node":body,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
			"solid":made.solid,"reach":float(made.reach)+BoxSolid.grow_most()+10.0,"spec":{},"no_break":true}
		records.append(record)
		game.arches.loose.append(record)
		GroundNative.bump_loose()
	site.nodes = nodes
	site.records = records
	site.state = "up"

func _free() -> void:
	for record: Dictionary in site.get("records",[]): game.arches.loose.erase(record)
	GroundNative.bump_loose()
	site.erase("records")
	for node: Node in site.get("nodes",[]):
		if is_instance_valid(node): node.queue_free()
	site.erase("nodes")
	site.state = "away"

func _exit_tree() -> void:
	if site.is_empty(): return
	if int(site.task) >= 0: WorkerThreadPool.wait_for_task_completion(int(site.task))
	site.task = -1
	site.erase("made")
