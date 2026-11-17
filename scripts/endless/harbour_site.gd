extends Node3D
## The ruined harbour in the cove on the inland sea's west shore (seed 1, the
## wilderness), about (870, -2030), from the harbour's pieces
## (art/blender/temple_kit/harbour_build.py) and the kit's columns.
##
## - The colossus astride the mouth at COLOSSUS, facing out to sea (east): a
##   foot on each pedestal, 100 m apart, 74 m clear between the pedestals at the
##   water, the crotch ~58 m up. Broken off at the chest, ~105 m high.
## - The north mole runs from the shore straight out to the north pedestal; the
##   breakwater curves from the south headland round to the south one (BREAK).
## - Five ship sheds side by side on the north shore (SHEDS_X: the first's
##   middle), sloping down into the water from their land end, open at both
##   ends: 24.75 m clear, ~22 m under the crown. Sheds BROKEN have their
##   vaults fallen in over the middle.
## - The quay along the west shore (QUAY_X, from QUAY_Z0 north), with steps.
## - The colossus' head lying in the shallows by the north shore, its arm by
##   the south shore; four columns standing in the water where the shore sank.
##
## Every piece's origin is at the sea's level (LandField.SEA_Y). Drawn as the
## citadel is (citadel_site.gd): chunks of MultiMeshes per piece and LOD
## gathered on a worker and made on the main thread, one chunk a frame, each
## with a StaticBody3D of the pieces' boxes on LandArches' layer and a `loose`
## solid record in the chunk's own frame. Trees keep off (`tree_keepouts`).
## `--harbour=0`: none.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Field = preload("res://scripts/endless/land_field.gd")

const B := TempleKit.BAY
const SEA := Field.SEA_Y
## The colossus' middle (between its feet), the feet north and south of it.
const COLOSSUS := Vector2(1015.0,-2035.0)
const FOOT_X := 50.0
const PED_HALF := 13.0
## harbour_build.py's numbers.
const MOLE_L := 19.0
const SHED_P := 27.75
const SHED_L := 55.5
## The breakwater's line, from the south pedestal round to the headland.
const BREAK: Array[Vector2] = [Vector2(1015.0,-1972.0),Vector2(1013.0,-1925.0),Vector2(998.0,-1872.0),
	Vector2(970.0,-1818.0),Vector2(938.0,-1777.0),Vector2(905.0,-1745.0)]
## Its pieces (from the pedestal) that are broken.
const BREAK_BROKEN := [4,9]
## The north mole: from the north pedestal north to the shore.
const MOLE_N := 12
const MOLE_BROKEN := [6]
## The sheds: the first's middle (x), the sea end's line (z); which are fallen in.
const SHEDS_X := 773.9
const SHEDS_Z := -2198.0
const SHEDS := 5
const BROKEN := [1,4]
## The quay's face (x) and its south end (z); its bays north; the bays with steps.
const QUAY_X := 697.0
const QUAY_Z0 := -1918.0
const QUAY_BAYS := 11
const QUAY_STEPS := [2,8]
## The columns in the water: the first's foot (XZ), the line they stand on.
const COLS_AT := Vector2(752.0,-1888.0)
const COLS_DIR := Vector2(0.707,0.707)
const HEAD_AT := Vector2(962.0,-2250.0)
const HEAD_YAW := 0.55
const ARM_AT := Vector2(828.0,-1800.0)
const ARM_YAW := 0.12
## The trees' keep-out.
const KEEP_C := Vector2(865.0,-2030.0)
const KEEP_HALF := Vector2(225.0,300.0)
const REACH := 3000.0
const FREE := 3400.0
const MID_NEAREST := 60.0
const FAR_NEAREST := 300.0

var game: Node3D
## Each: {name, xf, pieces ([id, local xf]), state, task, made, node, record}.
var chunks: Array = []

static func wanted() -> bool:
	return not ("--harbour=0" in LaunchArgs.user_args())

## TreePlan's keep-outs near a world rectangle, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	if KEEP_C.x < x0-600.0 or KEEP_C.x > x1+600.0 or KEEP_C.y < z0-600.0 or KEEP_C.y > z1+600.0: return []
	return [[KEEP_C,1.0,0.0,KEEP_HALF.x,KEEP_HALF.y]]

## The grass kept off the sheds' floors and the quay's deck (endless_grass.gd
## grow_cell, as agora_site.gd's paving): every node under them reads as a
## river's water (`river` -1), so no tuft comes up through the stone. Seed 1 only.
static func grass_off(got: Dictionary, land_seed: int, x0: float, z0: float, n: int, pad: int) -> void:
	if land_seed != 1 or not wanted() or not got.has("river"): return
	var gx0 := x0-pad
	var gz0 := z0-pad
	# [x0, x1, z0, z1]: the sheds (their walls too) and the quay behind its face.
	var rects := [[SHEDS_X-SHED_P*0.5-1.0,SHEDS_X+SHED_P*(SHEDS-0.5)+4.0,SHEDS_Z-SHED_L-1.0,SHEDS_Z+1.0],
		[QUAY_X-13.0,QUAY_X+1.0,QUAY_Z0-B*QUAY_BAYS-1.0,QUAY_Z0+1.0]]
	var rs: PackedFloat32Array = got.river
	var hit := false
	for r: Array in rects:
		var i0 := maxi(ceili(float(r[0])-gx0),0)
		var i1 := mini(floori(float(r[1])-gx0),n-1)
		var j0 := maxi(ceili(float(r[2])-gz0),0)
		var j1 := mini(floori(float(r[3])-gz0),n-1)
		for jj in range(j0,j1+1):
			for ii in range(i0,i1+1):
				var k := jj*n+ii
				rs[k] = minf(rs[k],-1.0)
				hit = true
	if hit: got.river = rs

static func _h(field: Object, p: Vector2) -> float:
	return float(field.call("height",p.x,p.y))

## A frame at XZ `p` with local +x along `d`, at `y`.
static func _frame(p: Vector2, d: Vector2, y: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,atan2(-d.y,d.x)),Vector3(p.x,y,p.y))

## The colossus' frame: its local +x north (to the north foot), facing east.
static func colossus_frame() -> Transform3D:
	return _frame(COLOSSUS,Vector2(0.0,-1.0),SEA)

## The XZ of each foot: [north, south].
static func feet() -> Array:
	return [COLOSSUS+Vector2(0.0,-FOOT_X),COLOSSUS+Vector2(0.0,FOOT_X)]

## A point `s` m along a polyline, and the way it runs there.
static func _along(line: Array[Vector2], s: float) -> Array:
	for i in range(line.size()-1):
		var a := line[i]
		var b := line[i+1]
		var l := a.distance_to(b)
		if s <= l or i == line.size()-2: return [a+(b-a).normalized()*minf(s,l),(b-a).normalized()]
		s -= l
	return [line[-1],Vector2.UP]

static func _length(line: Array[Vector2]) -> float:
	var l := 0.0
	for i in range(line.size()-1): l += line[i].distance_to(line[i+1])
	return l

func setup(g: Node3D) -> void:
	game = g
	_lay(game.field)
	for ch: Dictionary in chunks:
		var inv := (ch.xf as Transform3D).affine_inverse()
		var pieces: Array = ch.pieces
		for k in range(pieces.size()): pieces[k] = [pieces[k][0],inv*(pieces[k][1] as Transform3D)]
	_load_meshes()

func _chunk(label: String, xf: Transform3D) -> int:
	chunks.append({"name":label,"xf":xf,"pieces":[],"state":"away","task":-1})
	return chunks.size()-1

func _put(c: int, id: StringName, xf: Transform3D) -> void:
	(chunks[c].pieces as Array).append([id,xf])

## Every piece into its chunk, in world frames.
func _lay(field: Object) -> void:
	# ---- The colossus.
	var cx := colossus_frame()
	var col := _chunk("harbour/colossus",cx)
	_put(col,&"harbour_colossus",cx)
	# ---- The north mole: from the pedestal's north face to the shore.
	var nf: Vector2 = feet()[0]
	var n0 := nf+Vector2(0.0,-PED_HALF)
	var north := _chunk("harbour/north_mole",_frame(n0,Vector2(0.0,-1.0),SEA))
	for i in range(MOLE_N):
		var p := n0+Vector2(0.0,-(i+0.5)*(MOLE_L-0.5))
		_put(north,&"harbour_mole_broken" if i in MOLE_BROKEN else &"harbour_mole",_frame(p,Vector2(0.0,-1.0),SEA))
	# ---- The breakwater: along BREAK from the shore out (its parapet to the sea).
	var bl := _length(BREAK)
	var nb := int(ceil(bl/(MOLE_L-0.5)))
	var brk := _chunk("harbour/breakwater",_frame(BREAK[0],Vector2(0.0,-1.0),SEA))
	for i in range(nb):
		var got := _along(BREAK,minf((i+0.5)*(MOLE_L-0.5),bl-MOLE_L*0.5))
		var d: Vector2 = got[1]
		_put(brk,&"harbour_mole_broken" if i in BREAK_BROKEN else &"harbour_mole",_frame(got[0],-d,SEA))
	# ---- The ship sheds: their land end north, side by side along x.
	var sheds := _chunk("harbour/sheds",_frame(Vector2(SHEDS_X+SHED_P*2.0,SHEDS_Z-SHED_L*0.5),Vector2(1.0,0.0),SEA))
	for i in range(SHEDS):
		var o := Vector2(SHEDS_X+SHED_P*i,SHEDS_Z)
		var xf := _frame(o,Vector2(1.0,0.0),SEA)
		_put(sheds,&"harbour_shed_broken" if i in BROKEN else &"harbour_shed",xf)
		if i == SHEDS-1: _put(sheds,&"harbour_shed_end",xf)
	# ---- The quay: bays north from QUAY_Z0, its face east.
	var quay := _chunk("harbour/quay",_frame(Vector2(QUAY_X,QUAY_Z0-B*QUAY_BAYS*0.5),Vector2(0.0,-1.0),SEA))
	for i in range(QUAY_BAYS):
		var p := Vector2(QUAY_X,QUAY_Z0-B*(i+0.5))
		_put(quay,&"harbour_quay_steps" if i in QUAY_STEPS else &"harbour_quay",_frame(p,Vector2(0.0,-1.0),SEA))
	# The columns in the water: two under a lintel, a stump, one alone.
	var ids: Array[StringName] = [&"column",&"column",&"column_broken",&"column"]
	var feet_y: Array[float] = []
	for i in range(ids.size()):
		var p := COLS_AT+COLS_DIR*(B*i)
		var y := _h(field,p)-0.4
		feet_y.append(y)
		_put(quay,ids[i],_frame(p,COLS_DIR,y))
	var lp := COLS_AT+COLS_DIR*(B*0.5)
	_put(quay,&"lintel",_frame(lp,COLS_DIR,maxf(feet_y[0],feet_y[1])))
	# ---- The fallen head and arm, resting on the shallows' bed.
	var frag := _chunk("harbour/fragments",_frame(HEAD_AT,Vector2(1.0,0.0),SEA))
	_put(frag,&"harbour_colossus_head",_frame(HEAD_AT,Vector2.from_angle(HEAD_YAW),_low(field,HEAD_AT,12.0)+0.4))
	var ay := maxf(_low(field,ARM_AT,6.0)+4.2,SEA-1.2)
	_put(frag,&"harbour_colossus_arm",_frame(ARM_AT,Vector2.from_angle(ARM_YAW),ay))

## The lowest ground within `r` of `c`.
static func _low(field: Object, c: Vector2, r: float) -> float:
	var lo := INF
	for i in range(-2,3):
		for j in range(-2,3): lo = minf(lo,_h(field,c+Vector2(i,j)*(r*0.5)))
	return lo

## One frame: the chunks streamed round the eye. `busy`: a temple-kit build
## is running elsewhere (one at a time). Returns whether a chunk is building.
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
					ch.task = WorkerThreadPool.add_task(_make.bind(ch),false,"Harbour")
					building = true
			"up":
				if d > FREE: _free(ch)
	return building

## On a worker: the chunk's boxes and its sets (one per piece: its frames, box
## and LOD ranges). No resource is made here (_commit makes the MultiMeshes).
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
		var mid_at := MID_NEAREST+radius if TempleKit.lod(id,TempleKit.MID) != null else far_at
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
