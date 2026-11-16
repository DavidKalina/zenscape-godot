extends Node3D
## The ruined round temple on the ridge east of the aqueduct's end (seed 1,
## the wilderness): a ring of the temple kit's columns on a round stepped
## base (art/blender/temple_kit/tholos_build.py) whose retaining drum goes
## down into the ridge's flanks.
##
## - The ring: N columns RING m from the centre, BAY apart, so 14.5 m clear
##   between shafts and 30.5 m under the lintels. Columns at 300, 0, 60 and
##   120 degrees (from +x toward +z) stand under three bays of the ring's
##   entablature; the one at 180 (west) is a stump; the one at 240 is gone,
##   its drums down the west flank. The gaps at 90 and 270 lie on the crest's
##   line; every gap faces another across the open middle.
## - Along the crest: a pair under a lintel to the north, a column and a
##   stump to the south, a lone column beyond the pair.
##
## Drawn as the agora is (agora_site.gd): MultiMeshes per piece and LOD made
## on the main thread, a StaticBody3D of the pieces' boxes on LandArches'
## layer and a `loose` solid record, streamed within REACH (far: a landmark).
## Trees keep off (`tree_keepouts`), grass off the base (`grass_off`).
## `--tholos=0`: none.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const TempleBreaks = preload("res://scripts/endless/temple_breaks.gd")

const B := TempleKit.BAY
## The ring's centre.
const C := Vector2(10.0,-4476.0)
const N := 6
## tholos_build.py's numbers: the columns' circle, the stylobate's edge, the
## second step's foot, the drum's top radius and how far down it goes.
const RING := 18.5
const STYLO := 21.9
const LEDGE := 25.1
const DRUM := 26.3
const DEPTH := 46.0
## The ring's columns by their index (k * 360/N degrees): standing, a stump, or none.
const STANDING: Array[int] = [5,0,1,2]
const STUMPS: Array[int] = [3]
## The bays that keep their entablature (bay k: column k to k+1) and its piece.
const BAYS := {5:&"tholos_lintel_l",0:&"tholos_lintel",1:&"tholos_lintel_r"}
## The crest's columns: the pair under its lintel (its middle, the columns
## B apart along x), then lone ones [piece, at].
const PAIR := Vector2(10.0,-4546.0)
const LONE := [[&"column",Vector2(-5.75,-4428.0)],[&"column_broken",Vector2(12.75,-4428.0)],[&"column",Vector2(21.0,-4570.0)]]
## What the plane breaks in a surge roll (temple_breaks.gd): the crest pair's
## lintel, in three with its middle dropped ("tholos/lintel": its two ends are
## left on the abaci, the way over the pair open), and LONE's columns by
## index, slipped apart ("tholos/column_<i>": a stump is left).
const CRACKED_LINTEL := true
const CRACKED_COLUMNS: Array[int] = [2]
## The trees' keep-out (TreePlan adds its ARCH_CLEAR, 18 m).
const KEEP_C := Vector2(8.0,-4498.0)
const KEEP_HALF := Vector2(46.0,88.0)
const REACH := 4500.0
const FREE := 5000.0
const MID_NEAREST := 80.0
const FAR_NEAREST := 420.0
## Round pieces: their boxes are laid unturned (a turned box's bounds grow).
const ROUND: Array[StringName] = [&"column",&"column_broken"]

var game: Node3D
## Each: {xf, pieces ([id, local xf]), state, task, made, node, record}.
var chunks: Array = []
## The cracked pieces (temple_breaks.gd).
var breaks: Node3D

static func wanted() -> bool:
	return not ("--tholos=0" in LaunchArgs.user_args())

## TreePlan's keep-outs near a world rectangle, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	if KEEP_C.x < x0-500.0 or KEEP_C.x > x1+500.0 or KEEP_C.y < z0-500.0 or KEEP_C.y > z1+500.0: return []
	return [[KEEP_C,1.0,0.0,KEEP_HALF.x,KEEP_HALF.y]]

static func _h(field: Object, x: float, z: float) -> float:
	return float(field.call("height",x,z))

## A frame at world XZ `p`, height `y`, turned `yaw` about y.
static func _at(p: Vector2, y: float, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw),Vector3(p.x,y,p.y))

## Where the ring's angle `deg` (from +x toward +z) meets the circle `r`.
static func _polar(deg: float, r: float) -> Vector2:
	var a := deg_to_rad(deg)
	return C+Vector2(cos(a),sin(a))*r

## The lowest ground under a column's plinth at `p`.
static func _foot(field: Object, p: Vector2) -> float:
	var lo := _h(field,p.x,p.y)
	for d: Vector2 in [Vector2(-2.5,-2.5),Vector2(2.5,-2.5),Vector2(-2.5,2.5),Vector2(2.5,2.5)]:
		lo = minf(lo,_h(field,p.x+d.x,p.y+d.y))
	return lo

## A frame lying on the ground's slope at `p`, sunk `sink` m into it, turned `yaw`.
static func _on_slope(field: Object, p: Vector2, yaw: float, sink: float) -> Transform3D:
	const E := 1.5
	var n := Vector3(_h(field,p.x-E,p.y)-_h(field,p.x+E,p.y),2.0*E,_h(field,p.x,p.y-E)-_h(field,p.x,p.y+E)).normalized()
	var tilt := Basis()
	var ax := Vector3.UP.cross(n)
	if ax.length() > 1e-5: tilt = Basis(ax.normalized(),Vector3.UP.angle_to(n))
	return Transform3D(tilt*Basis(Vector3.UP,yaw),Vector3(p.x,_h(field,p.x,p.y),p.y)-n*sink)

## The stylobate's height: over the highest ground under it.
static func top(field: Object) -> float:
	var hi := -INF
	for i in range(-11,12):
		for j in range(-11,12):
			var d := Vector2(i,j)*2.0
			if d.length() > STYLO: continue
			hi = maxf(hi,_h(field,C.x+d.x,C.y+d.y))
	return hi+0.6

func setup(g: Node3D) -> void:
	game = g
	breaks = TempleBreaks.new()
	add_child(breaks)
	breaks.setup(g)
	var all := layout(game.field)
	var xf := _at(C,0.0)
	var pieces: Array = []
	for e: Array in all:
		if e.size() > 2: breaks.add(e[2],e[0],e[1],e[3])
		else: pieces.append([e[0],xf.affine_inverse()*(e[1] as Transform3D)])
	chunks.append({"xf":xf,"lo":0,"pieces":pieces,"state":"away","task":-1})
	_load_meshes()

## Every piece, world: [id, xf]; a cracked one [id, xf, its name, what is left ([id, xf])].
static func layout(field: Object) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 3109
	var y := top(field)
	var step := 360.0/N
	out.append([&"tholos_base",_at(C,y)])
	# ---- The ring.
	for k: int in STANDING: out.append([&"column",_at(_polar(k*step,RING),y,-deg_to_rad(k*step))])
	for k: int in STUMPS: out.append([&"column_broken",_at(_polar(k*step,RING),y,-deg_to_rad(k*step)+PI*0.5)])
	for k: int in BAYS: out.append([BAYS[k],_at(C,y,-deg_to_rad((k+0.5)*step))])
	# The lost column's foot drum, toppled where it stood.
	out.append([&"agora_drum",_at(_polar(4*step-3.0,RING+0.6),y+0.3,0.9)])
	# ---- Down the west flank: the lost column's drums lodged in the slope,
	# the entablature's blocks in heaps at the drum's foot.
	for i in range(9):
		var p := _polar(rng.randf_range(188.0,262.0),DRUM+4.0+24.0*float(i)/8.0+rng.randf_range(-2.0,2.0))
		out.append([&"agora_drum",_on_slope(field,p,rng.randf_range(0.0,TAU),rng.randf_range(0.3,1.0))])
	for e: Array in [[198.0,6.0,0.4],[247.0,7.0,2.6]]:
		out.append([&"aqueduct_rubble",_on_slope(field,_polar(float(e[0]),DRUM+float(e[1])),float(e[2]),0.2)])
	# ---- Along the crest. The pair stands on its lower foot, under a lintel.
	var pa := PAIR-Vector2(B*0.5,0.0)
	var pb := PAIR+Vector2(B*0.5,0.0)
	var base := minf(_foot(field,pa),_foot(field,pb))-0.2
	out.append([&"column",_at(pa,base,0.0)])
	out.append([&"column",_at(pb,base,PI*0.5)])
	if CRACKED_LINTEL: out.append([&"lintel_cracked_wide",_at(PAIR,base),"tholos/lintel",[[&"lintel_snapped",_at(PAIR,base)]]])
	else: out.append([&"lintel",_at(PAIR,base)])
	for i in range(LONE.size()):
		var p: Vector2 = LONE[i][1]
		var at := _at(p,_foot(field,p)-0.2,rng.randf_range(0.0,TAU))
		if i in CRACKED_COLUMNS and LONE[i][0] == &"column":
			out.append([&"column_cracked_wide",at,"tholos/column_%d" % i,[[&"street_stump",at]]])
		else: out.append([LONE[i][0],at])
	return out

## The grass kept off the base (endless_grass.gd grow_cell, over its cell's
## LandField.grid): every node under the stylobate and its steps reads as a
## river's water (`river` -1, as agora_site.gd's paving), so no tuft comes up
## through the stone where the ridge's top lies just under it. Seed 1 only.
static func grass_off(got: Dictionary, land_seed: int, x0: float, z0: float, n: int, pad: int) -> void:
	if land_seed != 1 or not wanted() or not got.has("river"): return
	var gx0 := x0-pad
	var gz0 := z0-pad
	const R := LEDGE+0.5
	if gx0+n-1 < C.x-R or gx0 > C.x+R or gz0+n-1 < C.y-R or gz0 > C.y+R: return
	var rs: PackedFloat32Array = got.river
	var i0 := maxi(ceili(C.x-R-gx0),0)
	var i1 := mini(floori(C.x+R-gx0),n-1)
	var j0 := maxi(ceili(C.y-R-gz0),0)
	var j1 := mini(floori(C.y+R-gz0),n-1)
	for jj in range(j0,j1+1):
		for ii in range(i0,i1+1):
			if Vector2(gx0+ii-C.x,gz0+jj-C.y).length() > R: continue
			var k := jj*n+ii
			rs[k] = minf(rs[k],-1.0)
	got.river = rs

## One frame: streamed round the eye. `busy`: a temple-kit build is running
## elsewhere (one at a time). Returns whether a chunk is building.
func step(eye: Vector3, busy: bool, here: bool) -> bool:
	var building := false
	for ch: Dictionary in chunks:
		if str(ch.state) == "building":
			if WorkerThreadPool.is_task_completed(int(ch.task)): _commit(ch)
			else: building = true
	if here: breaks.step(eye,not busy and not building)
	for ch: Dictionary in chunks:
		var o: Vector3 = (ch.xf as Transform3D).origin
		var d := Vector2(o.x-eye.x,o.z-eye.z).length() if here else INF
		match str(ch.state):
			"away":
				if d < REACH and not busy and not building:
					ch.state = "building"
					ch.task = WorkerThreadPool.add_task(_make.bind(ch),false,"Tholos")
					building = true
			"up":
				if d > FREE: _free(ch)
	return building

## On a worker: the chunk's boxes and its sets (one per piece: its frames, box
## and LOD ranges). No resource is made here (agora_site.gd's reason).
func _make(ch: Dictionary) -> void:
	var by_id := {}
	var boxes: Array = []
	var reach := 0.0
	for e: Array in ch.pieces:
		var id: StringName = e[0]
		var xf: Transform3D = e[1]
		if not by_id.has(id): by_id[id] = []
		(by_id[id] as Array).append(xf)
		var bxf := Transform3D(Basis(),xf.origin) if id in ROUND else xf
		for box: AABB in TempleKit.boxes(id):
			var b: AABB = bxf*box
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
		var mid_at := MID_NEAREST+radius if TempleKit.lod(id,TempleKit.MID) != null else far_at
		sets.append({"id":id,"xfs":xfs,"box":set_box,"ranges":[Vector2(0.0,mid_at),Vector2(mid_at,far_at),Vector2(far_at,0.0)]})
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
	root.name = "Tholos%d" % int(ch.lo)
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
			mmi.name = String(id)+(["","_mid","_far"][level] as String)
			mmi.visibility_range_begin = (s.ranges[level] as Vector2).x
			mmi.visibility_range_end = (s.ranges[level] as Vector2).y
			root.add_child(mmi)
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
	ch.record = {"name":"tholos/%d" % int(ch.lo),"kind":"way","node":root,"pos":xf.origin,"cos":1.0,"sin":0.0,
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
