extends Node3D
## The ruined bath house east of the agora (seed 1, the wilderness), between
## the square and the stream: a domed rotunda with its crown broken open, a
## barrel-vaulted hall off its east arch, a dry sunken pool under the dome.
## Its own pieces are art/blender/temple_kit/baths_build.py's; the rest is
## the kit's.
##
## - The rotunda at C: 66 m across inside, its floor a paved platform over
##   the ground (2.5-4.5 m; floor_y), the dome springing 38 m over the floor
##   and 71 m to where its crown was. The hole in the crown is about 31 m
##   across (37 m with its notch to the north-east), its rim about 67 m over
##   the floor.
## - Four arches at floor level, each 20 m wide and 24 m to its crown: east
##   into the hall, north, south toward the stream, and south-west (38 degrees
##   south of west) onto the agora's square, between its east colonnade's
##   stump and standing pair. The wall is down to the south-east.
## - The pool under the dome: 37 m across at its rim, three 3 m steps down to
##   a floor 19 m across, 1.6 m under the paving. Its solid is a ramp over the
##   steps (baths_build.py), so a pass that sinks into it scrapes out.
## - The hall east of it: three 16 m bays, 22 m wide inside, 26 m to the
##   vault's crown, a window 11.5 m wide and 11.75 m high in each wall of each
##   bay. The middle bay's vault has lost its crown; the east bay stands open:
##   its vault and south wall are down.
##
## The curved pieces' solids are axis-aligned boxes cut on a grid, so every
## baths piece is laid unturned (only the rubble turns). Drawn and streamed as
## the agora (agora_site.gd): MultiMeshes per piece and LOD made on the main
## thread, a StaticBody3D of the boxes on LandArches' layer, a `loose` solid
## record. Trees keep off (`tree_keepouts`), grass too (`grass_off`).
## `--baths=0`: none.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const TempleBreaks = preload("res://scripts/endless/temple_breaks.gd")

## The rotunda's centre (world XZ).
const C := Vector2(-149.0,-4792.0)
## The rotunda's outside radius, the pool's rim and depth, the hall's bays
## (their middles east of C), its half width outside and its length from C.
const R_OUT := 37.0
const POOL_R := 18.5
const POOL_D := 1.6
const BAYS: Array[float] = [42.0,58.0,74.0]
const HALL_HALF := 14.0
const HALL_END := 82.0
## The south-west arch's way out (world XZ, a unit vector).
const SW := Vector2(-0.788,0.616)
## What the plane breaks in a surge roll (temple_breaks.gd): stretches of the
## rotunda's wall, 14 m wide and 20 m high, split foot to top with a hole high
## in them (breaks_build.py's SECTIONS: "w" 9 degrees north of west, between
## two of the agora's east columns, on a line through the middle and out the
## east arch into the hall; "ne" opposite the south-west arch). Each is
## "baths/wall_<key>"; a ragged breach 8-10 m wide and 17 m high is left. The
## rotunda is drawn without them (`baths_rotunda_cut`).
const CRACKED: Array[String] = ["w","ne"]
## The trees' keep-out (TreePlan adds its ARCH_CLEAR, 18 m).
const KEEP_C := Vector2(-126.5,-4792.0)
const KEEP_HALF := Vector2(68.0,47.0)
const REACH := 3000.0
const FREE := 3400.0
const FAR_NEAREST := 280.0

var game: Node3D
## The one chunk: {xf, pieces ([id, local xf]), state, task, made, node, record}.
var chunks: Array = []
## The cracked pieces (temple_breaks.gd).
var breaks: Node3D

static func wanted() -> bool:
	return not ("--baths=0" in LaunchArgs.user_args())

## TreePlan's keep-outs near a world rectangle, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	if KEEP_C.x < x0-500.0 or KEEP_C.x > x1+500.0 or KEEP_C.y < z0-500.0 or KEEP_C.y > z1+500.0: return []
	return [[KEEP_C,1.0,0.0,KEEP_HALF.x,KEEP_HALF.y]]

static func _h(field: Object, x: float, z: float) -> float:
	return float(field.call("height",x,z))

static func _at(p: Vector2, y: float, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw),Vector3(p.x,y,p.y))

## The floor's height (world y): the ground 1.3 m or more under the pool's
## floor (its slabs and the dark under them, so no turf shows through a lost
## slab), the paving over the footprint's highest ground.
static func floor_y(field: Object) -> float:
	var pool := -INF
	var all := -INF
	for i in range(-8,9):
		for j in range(-8,9):
			var o := Vector2(i,j)*5.0
			var h := _h(field,C.x+o.x,C.y+o.y)
			if o.length() <= POOL_R+2.0: pool = maxf(pool,h)
			if o.length() <= R_OUT+2.0: all = maxf(all,h)
	return maxf(pool+1.3+POOL_D,all+1.6)

## Whether a world XZ point lies on the baths' floors or steps.
static func covers(x: float, z: float) -> bool:
	var dx := x-C.x
	var dz := z-C.y
	if dx*dx+dz*dz < (R_OUT+1.0)*(R_OUT+1.0): return true
	if dx > 0.0 and dx < HALL_END+0.5 and absf(dz) < HALL_HALF+0.5: return true
	# The steps outside the north and south arches, and the south-west one.
	if absf(dx) < 15.0 and absf(dz) < R_OUT+9.0: return true
	var along := dx*SW.x+dz*SW.y
	return along > 0.0 and along < R_OUT+5.0 and absf(dx*SW.y-dz*SW.x) < 12.5

## The grass kept off the floors and steps (endless_grass.gd grow_cell, as
## agora_site.gd's): the cell's nodes on them read as a river's water.
static func grass_off(got: Dictionary, land_seed: int, x0: float, z0: float, n: int, pad: int) -> void:
	if land_seed != 1 or not wanted() or not got.has("river"): return
	var gx0 := x0-pad
	var gz0 := z0-pad
	if gx0+n-1 < C.x-R_OUT-9.0 or gx0 > C.x+HALL_END+1.0 or gz0+n-1 < C.y-R_OUT-9.0 or gz0 > C.y+R_OUT+9.0: return
	var rs: PackedFloat32Array = got.river
	var i0 := maxi(ceili(C.x-R_OUT-9.0-gx0),0)
	var i1 := mini(floori(C.x+HALL_END+1.0-gx0),n-1)
	var j0 := maxi(ceili(C.y-R_OUT-9.0-gz0),0)
	var j1 := mini(floori(C.y+R_OUT+9.0-gz0),n-1)
	for jj in range(j0,j1+1):
		for ii in range(i0,i1+1):
			if covers(gx0+ii,gz0+jj):
				var k := jj*n+ii
				rs[k] = minf(rs[k],-1.0)
	got.river = rs

func setup(g: Node3D) -> void:
	game = g
	breaks = TempleBreaks.new()
	add_child(breaks)
	breaks.setup(g)
	var all := layout(game.field)
	var xf := _at(C,floor_y(game.field))
	var pieces: Array = []
	for e: Array in all:
		if e.size() > 2: breaks.add(e[2],e[0],e[1],e[3])
		else: pieces.append([e[0],xf.affine_inverse()*(e[1] as Transform3D)])
	chunks.append({"xf":xf,"lo":0,"pieces":pieces,"state":"away","task":-1})
	_load_meshes()

## Every piece, world: [id, xf]; a cracked one [id, xf, its name, what is left ([id, xf])].
static func layout(field: Object) -> Array:
	var out: Array = []
	var fl := floor_y(field)
	# The rotunda: its drum (less the cracked stretches), dome and floor on one origin, unturned.
	for id: StringName in [&"baths_rotunda_cut",&"baths_dome",&"baths_floor"]: out.append([id,_at(C,fl)])
	for key: String in ["w","ne"]:
		var whole := StringName("baths_wall_%s_cracked" % key)
		if key in CRACKED: out.append([whole,_at(C,fl),"baths/wall_"+key,[[StringName("baths_wall_%s_holed" % key),_at(C,fl)]]])
		else: out.append([whole,_at(C,fl)])
	# The hall's bays, west to east.
	var kinds: Array[StringName] = [&"baths_hall",&"baths_hall_broken",&"baths_hall_end"]
	for i in range(BAYS.size()): out.append([kinds[i],_at(C+Vector2(BAYS[i],0.0),fl)])
	# What fell from the crown: a heap on the paving under the notch (north-east),
	# joined blocks on the pool's steps and by the heap. Off the arches' lines.
	out.append([&"baths_rubble",_at(C+Vector2(13.8,-19.7),fl-0.1,0.6)])
	out.append([&"baths_fragment",_at(C+Vector2(9.9,-9.9),fl-POOL_D/3.0-0.2,PI*0.5)])
	out.append([&"baths_fragment",_at(C+Vector2(24.5,-12.5),fl-0.15)])
	# The wall down to the south-east: its heap in the gap, more outside it.
	out.append([&"baths_rubble",_at(C+Vector2(21.5,19.4),fl-0.3,2.2)])
	var gap := C+Vector2(31.2,28.1)
	out.append([&"aqueduct_rubble",_at(gap,_h(field,gap.x,gap.y)-0.3,0.7)])
	# The hall: the vault's fall along the middle bay's walls, the south wall's in the east bay.
	out.append([&"baths_fragment",_at(C+Vector2(BAYS[1]-1.0,8.4),fl-0.15)])
	out.append([&"baths_fragment",_at(C+Vector2(BAYS[1]+3.0,-8.6),fl-0.2,PI)])
	out.append([&"baths_rubble",_at(C+Vector2(BAYS[2]+1.0,12.0),fl-0.6,1.3)])
	# Round the foot: rubble, a stump and drums from what stood by it.
	for e: Array in [[&"aqueduct_rubble",Vector2(-30.0,-33.0),1.4,-0.5],[&"column_broken",Vector2(-35.0,-35.0),0.3,-0.15],
			[&"agora_drum",Vector2(-36.0,-24.0),0.9,0.05],[&"agora_drum",Vector2(-12.0,44.0),2.4,0.05],
			[&"agora_drum",Vector2(34.0,-29.0),0.2,0.05]]:
		var p: Vector2 = C+(e[1] as Vector2)
		out.append([e[0],_at(p,_h(field,p.x,p.y)+float(e[3]),float(e[2]))])
	return out

## One frame: streamed round the eye. `busy`: a temple-kit build is running
## elsewhere (one at a time). Returns whether the chunk is building.
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
					ch.task = WorkerThreadPool.add_task(_make.bind(ch),false,"Baths")
					building = true
			"up":
				if d > FREE: _free(ch)
	return building

## On a worker: the chunk's boxes and its sets (one per piece: its frames, box
## and LOD ranges). No resource is made here (see agora_site.gd).
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
		sets.append({"id":id,"xfs":xfs,"box":set_box,"ranges":[Vector2(0.0,far_at),Vector2(far_at,far_at),Vector2(far_at,0.0)]})
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
			for level in [TempleKit.NEAR,TempleKit.FAR]:
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
	root.name = "Baths%d" % int(ch.lo)
	for s: Dictionary in made.sets:
		var id: StringName = s.id
		var xfs: Array = s.xfs
		for level in [TempleKit.NEAR,TempleKit.FAR]:
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
	ch.record = {"name":"baths/%d" % int(ch.lo),"kind":"way","node":root,"pos":xf.origin,"cos":1.0,"sin":0.0,
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
