extends Node3D
## The ruined agora north of the aqueduct's east end (seed 1, the wilderness):
## a paved square on the flat downs, built from the temple kit's pieces and
## the agora's own (art/blender/temple_kit/agora_build.py).
##
## - The stoa along the north side: a podium (the kit's podium bays), NCOL
##   columns under lintels, the back wall DEPTH m behind them, the roof bays
##   between. Bays 4 and 5 lost their roof when column 5 fell into the
##   square (its drums lie out over the paving); bay 2's roof has a hole
##   with its fall under it; the wall's bay 4 is down. The inside: ~20 m clear across and 30.5 m
##   from the floor to the architrave.
## - The west gate on the street's join (JOIN): travel +x, 20 m by 26 m clear.
## - Open colonnades: the west run south of the gate, the south side with
##   runs missing and fallen, the east side's short run that stops. The
##   south-east corner is down in rubble.
## - In the square: an altar, a statue's plinth, a lone column pair under its
##   lintel, drums; the paving heaved, broken and gone in places.
##
## Drawn as the aqueduct is (aqueduct_site.gd): chunks of MultiMeshes per
## piece and LOD built on a worker, a StaticBody3D of the pieces' boxes on
## LandArches' layer and a `loose` solid record per chunk, streamed within
## REACH. Trees keep off (`tree_keepouts`). `--agora=0`: none.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const TempleBreaks = preload("res://scripts/endless/temple_breaks.gd")

const B := TempleKit.BAY
const S := TempleKit.PODIUM_H
## The street's join: the west gate's opening is centred on it, travel +x.
## Nothing here lies west of JOIN.x.
const JOIN := Vector2(-370.0,-4760.0)
## The gate's middle (its 6 m depth and cornice stay east of JOIN.x).
const GATE := Vector2(-366.0,-4760.0)
## The stoa: its front columns' line (z), its first column (x), the columns'
## count and the back wall's axis behind the front line (m, toward -z).
const STOA_Z := -4794.0
const STOA_X0 := -357.0
const NCOL := 9
const DEPTH := 24.0
## The colonnades: the west line (x), the south line (z), the east line (x).
const WEST_X := -366.5
const SOUTH_Z := -4711.5
const EAST_X := -218.5
## The paving: tile centres from (x0, z0), BAY apart, PAVE_N across x by z.
const PAVE0 := Vector2(-357.25,-4778.5)
const PAVE_N := Vector2i(9,5)
## The trees' keep-out (TreePlan adds its ARCH_CLEAR, 18 m).
const KEEP_C := Vector2(-288.0,-4764.0)
const KEEP_HALF := Vector2(92.0,62.0)
## What the plane breaks in a surge roll (temple_breaks.gd): the stoa's back
## wall in this bay, cracked foot to top ("agora/wall": a breach is left, to
## fly out through from under the roof), the lone pair's lintel
## ("agora/lintel": a stub on one column, the rest fallen) and the altar
## ("agora/altar": its lowest course is left).
const CRACKED_WALL := 3
## Chunks split along x at these.
const CUTS: Array[float] = [-320.0,-262.0]
const REACH := 3000.0
const FREE := 3400.0
const MID_NEAREST := 50.0
const FAR_NEAREST := 280.0

var game: Node3D
## Each: {xf, pieces ([id, local xf]), state, task, made, node, record}.
var chunks: Array = []
## The cracked pieces (temple_breaks.gd).
var breaks: Node3D

static func wanted() -> bool:
	return not ("--agora=0" in LaunchArgs.user_args())

## TreePlan's keep-outs near a world rectangle, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	if KEEP_C.x < x0-500.0 or KEEP_C.x > x1+500.0 or KEEP_C.y < z0-500.0 or KEEP_C.y > z1+500.0: return []
	return [[KEEP_C,1.0,0.0,KEEP_HALF.x,KEEP_HALF.y]]

static func _h(field: Object, x: float, z: float) -> float:
	return float(field.call("height",x,z))

## The lowest ground over points.
static func _low(field: Object, pts: Array) -> float:
	var lo := INF
	for p: Vector2 in pts: lo = minf(lo,_h(field,p.x,p.y))
	return lo

## A frame at world XZ `p`, height `y`, turned `yaw` about y.
static func _at(p: Vector2, y: float, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw),Vector3(p.x,y,p.y))

func setup(g: Node3D) -> void:
	game = g
	breaks = TempleBreaks.new()
	add_child(breaks)
	breaks.setup(g)
	var all: Array = []
	for e: Array in layout(game.field):
		if e.size() > 2: breaks.add(e[2],e[0],e[1],e[3])
		else: all.append(e)
	var xs: Array[float] = [-INF]
	xs.append_array(CUTS)
	xs.append(INF)
	for i in range(xs.size()-1):
		var lo: float = xs[i]
		var hi: float = xs[i+1]
		var mine: Array = []
		var c := Vector2.ZERO
		for e: Array in all:
			var o: Vector3 = (e[1] as Transform3D).origin
			if o.x >= lo and o.x < hi:
				mine.append(e)
				c += Vector2(o.x,o.z)
		if mine.is_empty(): continue
		c /= mine.size()
		var xf := _at(c,-16.0)
		var pieces: Array = []
		for e: Array in mine: pieces.append([e[0],xf.affine_inverse()*(e[1] as Transform3D)])
		chunks.append({"xf":xf,"lo":i,"pieces":pieces,"state":"away","task":-1})
	_load_meshes()

## Every piece, world: [id, xf]; a cracked one [id, xf, its name, what is left ([id, xf])].
static func layout(field: Object) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	# ---- The stoa. Its podium's foot under the footprint's highest ground.
	var x_end := STOA_X0+(NCOL-1)*B
	var foot := -INF
	for k in range(NCOL):
		for dz in [6.0,0.0,-12.0,-DEPTH]:
			foot = maxf(foot,_h(field,STOA_X0+k*B,STOA_Z+dz))
	foot -= 0.6
	var top := foot+S
	# The podium: steps along the front, the ends' sides, floor bays behind.
	out.append([&"podium_corner",_at(Vector2(STOA_X0,STOA_Z),foot,PI*1.5)])
	out.append([&"podium_corner",_at(Vector2(x_end,STOA_Z),foot)])
	for k in range(1,NCOL-1): out.append([&"podium",_at(Vector2(STOA_X0+k*B,STOA_Z),foot)])
	out.append([&"podium",_at(Vector2(STOA_X0,STOA_Z-B),foot,PI*1.5)])
	out.append([&"podium",_at(Vector2(x_end,STOA_Z-B),foot,PI*0.5)])
	for k in range(NCOL):
		for dz in [-9.0,-18.0,-21.0]:
			out.append([&"podium_floor",_at(Vector2(STOA_X0+k*B,STOA_Z+dz),foot-0.02)])
	# Columns: the sixth (k 5) down into the square, its stump left.
	const FALLEN := 5
	const HOLE := 2
	for k in range(NCOL):
		var p := Vector2(STOA_X0+k*B,STOA_Z)
		if k == FALLEN:
			out.append([&"column_broken",_at(p,top,PI*0.5)])
			var g := _h(field,p.x,p.y+18.0)+0.1
			out.append([&"column_drums",_at(p,g,-PI*0.5+0.12)])
		else:
			out.append([&"column",_at(p,top,rng.randf_range(0,TAU))])
	# Lintels and roof bays (bay k from column k to k+1).
	for k in range(NCOL-1):
		var m := Vector2(STOA_X0+(k+0.5)*B,STOA_Z)
		if k == FALLEN-1: out.append([&"lintel_broken",_at(m,top)])
		elif k == FALLEN: out.append([&"lintel_broken",_at(m,top,PI)])
		else: out.append([&"lintel",_at(m,top)])
		if k == FALLEN-1 or k == FALLEN:
			var rub: StringName = &"agora_roof_rubble" if k == FALLEN-1 else &"aqueduct_rubble"
			var r_at := m+Vector2(0.0,-12.0 if k == FALLEN-1 else -11.0)
			out.append([rub,_at(m if k == FALLEN-1 else r_at,top-0.1,0.0 if k == FALLEN-1 else 0.3)])
		elif k == HOLE:
			out.append([&"agora_stoa_roof_broken",_at(m,top)])
			# What came down through it, turned about the bay's middle so it lies inside.
			out.append([&"agora_roof_rubble",_at(m+Vector2(0.0,-DEPTH),top-0.1,PI)])
		else: out.append([&"agora_stoa_roof",_at(m,top)])
		# The back wall; its bay under the gap down.
		var w := Vector2(m.x,STOA_Z-DEPTH)
		if k == CRACKED_WALL: out.append([&"agora_stoa_wall_cracked",_at(w,top),"agora/wall",[[&"agora_stoa_wall_holed",_at(w,top)]]])
		else: out.append([&"wall_broken" if k == FALLEN-1 else &"agora_stoa_wall",_at(w,top)])
	# ---- The gate.
	var gate_g := _low(field,[GATE,GATE+Vector2(0,13.5),GATE+Vector2(0,-13.5)])
	out.append([&"agora_gate",_at(GATE,gate_g-0.2)])
	# ---- The colonnades. A run under lintels stands on its lowest ground.
	var runs := [
		# West, south of the gate: two columns under a lintel (the SW corner).
		{"pts":[Vector2(WEST_X,-4730.0),Vector2(WEST_X,SOUTH_Z)],"lintels":[0],"turn":PI*0.5},
		# South: corner, two more under a lintel and the broken one.
		{"pts":[Vector2(WEST_X,SOUTH_Z),Vector2(WEST_X+B,SOUTH_Z),Vector2(WEST_X+2*B,SOUTH_Z)],"lintels":[0],"broken":[1],"turn":0.0},
		{"pts":[Vector2(WEST_X+4*B,SOUTH_Z),Vector2(WEST_X+5*B,SOUTH_Z)],"lintels":[0],"turn":0.0},
		# East: a short run that stops.
		{"pts":[Vector2(EAST_X,-4767.0),Vector2(EAST_X,-4748.5)],"lintels":[0],"turn":PI*0.5},
	]
	var corner_done := false
	for run: Dictionary in runs:
		var pts: Array = run.pts
		var base := _low(field,pts)+0.05
		for i in range(pts.size()):
			var p: Vector2 = pts[i]
			if p.is_equal_approx(Vector2(WEST_X,SOUTH_Z)):
				if corner_done: continue
				corner_done = true
			out.append([&"column",_at(p,base,rng.randf_range(0,TAU))])
		var turn: float = run.turn
		for i: int in run.lintels:
			var m: Vector2 = ((pts[i] as Vector2)+(pts[i+1] as Vector2))*0.5
			out.append([&"lintel",_at(m,base,turn)])
		for i: int in run.get("broken",[]):
			var m: Vector2 = ((pts[i] as Vector2)+(pts[i+1] as Vector2))*0.5
			out.append([&"lintel_broken",_at(m,base,turn+PI)])
	# Stumps and the fallen.
	for p: Vector2 in [Vector2(WEST_X+3*B,SOUTH_Z),Vector2(WEST_X+7*B,SOUTH_Z),Vector2(EAST_X,-4730.0)]:
		out.append([&"column_broken",_at(p,_h(field,p.x,p.y)-0.15,rng.randf_range(0,TAU))])
	var p6 := Vector2(WEST_X+6*B,SOUTH_Z)
	out.append([&"column_broken",_at(p6,_h(field,p6.x,p6.y)-0.1,PI*0.5)])
	out.append([&"column_drums",_at(p6,_h(field,p6.x,p6.y+16.0)-0.05,-PI*0.5-0.2)])
	# The south-east corner: down in heaps, its drums thrown in across the paving.
	var se := Vector2(EAST_X,SOUTH_Z)
	out.append([&"aqueduct_rubble",_at(se+Vector2(-2.0,1.0),_h(field,se.x,se.y)-0.4,0.7)])
	out.append([&"aqueduct_rubble",_at(se+Vector2(1.0,-15.0),_h(field,se.x,se.y-15.0)-0.4,2.1)])
	out.append([&"column_drums",_at(se,_h(field,se.x-12.0,se.y-12.0)-0.05,PI*0.75)])
	# ---- In the square.
	for e: Array in [[&"agora_altar",Vector2(-302.0,-4747.0),0.14],[&"agora_plinth",Vector2(-331.0,-4737.0),0.32],
			[&"agora_drum",Vector2(-318.0,-4771.0),1.0],[&"agora_drum",Vector2(-241.0,-4727.0),2.3],
			[&"agora_drum",Vector2(-279.0,-4731.0),0.45],[&"agora_drum",Vector2(-346.0,-4721.0),1.9]]:
		var p: Vector2 = e[1]
		var xf := _at(p,_h(field,p.x,p.y)+0.05,float(e[2]))
		if e[0] == &"agora_altar": out.append([&"agora_altar_cracked",xf,"agora/altar",[[&"agora_altar_smashed",xf]]])
		else: out.append([e[0],xf])
	# The lone pair under its lintel, a little off the square's lines.
	var pc := Vector2(-252.0,-4745.0)
	var yaw := 0.38
	var dir := Vector2(cos(yaw),-sin(yaw))
	var pa := pc-dir*B*0.5
	var pb := pc+dir*B*0.5
	var pair_base := _low(field,[pa,pb])+0.05
	out.append([&"column",_at(pa,pair_base,0.4)])
	out.append([&"column",_at(pb,pair_base,2.1)])
	out.append([&"agora_lintel_cracked",_at(pc,pair_base,yaw),"agora/lintel",[[&"lintel_broken",_at(pc,pair_base,yaw)]]])
	# ---- The paving: tiles on the ground's own tilt, turned at random, broken
	# toward the fallen corner and under the fallen column, gone in places.
	for i in range(PAVE_N.x):
		for j in range(PAVE_N.y):
			var c := PAVE0+Vector2(i*B,j*B)
			if _dropped(i,j): continue
			var broken := (i >= 6 and j >= 3) or (i == 8) or (i == 5 and j == 0) or (i == 1 and j == 3) or (i == 3 and j == 1)
			var q := rng.randi_range(0,3)
			# The edge: mostly broken, its lost side (the broken tile's +x -z) turned outward.
			var outward := Vector2(-1.0 if i == 0 else (1.0 if i >= PAVE_N.x-2 else 0.0),1.0 if j == PAVE_N.y-1 else 0.0)
			var gate_tile := i == 0 and j == 1
			if outward != Vector2.ZERO and not gate_tile and (broken or rng.randf() < 0.75):
				broken = true
				q = _facing(outward)
			out.append([&"agora_paving_broken" if broken else &"agora_paving",_tile(field,c,q)])
	return out

## The quarter turns that point a broken tile's lost corner (local +x -z) along `o`.
static func _facing(o: Vector2) -> int:
	var best := 0
	var bd := -INF
	for q in 4:
		var d := Basis(Vector3.UP,q*PI*0.5)*Vector3(1.0,0.0,-1.0)
		var dd := Vector2(d.x,d.z).dot(o)
		if dd > bd:
			bd = dd
			best = q
	return best

## The paving tiles left out (ground and grass where a tile was).
static func _dropped(i: int, j: int) -> bool:
	return (i == 8 and j < 2) or (i == 8 and j == 4) or (i == 7 and j == 4) or (i == 0 and j == 4) or (i == 4 and j == 2)

## The grass kept off the paving (endless_grass.gd grow_cell, over its cell's
## LandField.grid): every node on a laid tile reads as a river's water (`river`
## -1, as hall_sites.gd's slot), so no tuft or flower grows through the slabs.
## The edge tiles keep their outer 4 m, where the broken ones lose their slabs.
## Seed 1 only (the wilderness, as the way towers).
static func grass_off(got: Dictionary, land_seed: int, x0: float, z0: float, n: int, pad: int) -> void:
	if land_seed != 1 or not wanted() or not got.has("river"): return
	var gx0 := x0-pad
	var gz0 := z0-pad
	var gx1 := gx0+n-1
	var gz1 := gz0+n-1
	var h := B*0.5
	if gx1 < PAVE0.x-h or gx0 > PAVE0.x+(PAVE_N.x-1)*B+h or gz1 < PAVE0.y-h or gz0 > PAVE0.y+(PAVE_N.y-1)*B+h: return
	var rs: PackedFloat32Array = got.river
	for i in range(PAVE_N.x):
		for j in range(PAVE_N.y):
			if _dropped(i,j): continue
			var c := PAVE0+Vector2(i*B,j*B)
			var lo := c-Vector2(h,h)
			var hi := c+Vector2(h,h)
			if i == 0: lo.x += 4.0
			if i >= PAVE_N.x-2: hi.x -= 4.0
			if j == PAVE_N.y-1: hi.y -= 4.0
			var i0 := maxi(ceili(lo.x-gx0),0)
			var i1 := mini(floori(hi.x-gx0),n-1)
			var j0 := maxi(ceili(lo.y-gz0),0)
			var j1 := mini(floori(hi.y-gz0),n-1)
			for jj in range(j0,j1+1):
				for ii in range(i0,i1+1):
					var k := jj*n+ii
					rs[k] = minf(rs[k],-1.0)
	got.river = rs

## A paving tile's frame: on the ground's plane through its corners, sunk a little, turned `q` quarters.
static func _tile(field: Object, c: Vector2, q: int) -> Transform3D:
	var h := B*0.5
	var hx0 := _h(field,c.x-h,c.y)
	var hx1 := _h(field,c.x+h,c.y)
	var hz0 := _h(field,c.x,c.y-h)
	var hz1 := _h(field,c.x,c.y+h)
	var hc := (_h(field,c.x,c.y)+hx0+hx1+hz0+hz1)/5.0
	var n := Vector3(-(hx1-hx0)/B,1.0,-(hz1-hz0)/B).normalized()
	var tilt := Basis()
	var ax := Vector3.UP.cross(n)
	if ax.length() > 1e-5: tilt = Basis(ax.normalized(),Vector3.UP.angle_to(n))
	return Transform3D(tilt*Basis(Vector3.UP,q*PI*0.5),Vector3(c.x,hc-0.08,c.y))

## One frame: the chunks streamed round the eye. `busy`: a temple-kit build
## is running elsewhere (one at a time). Returns whether a chunk is building.
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
					ch.task = WorkerThreadPool.add_task(_make.bind(ch),false,"Agora")
					building = true
			"up":
				if d > FREE: _free(ch)
	return building

## On a worker: the chunk's boxes and its sets (one per piece: its frames, box
## and LOD ranges). No resource is made here: the MultiMeshes are made on the
## main thread (_commit), so a build never makes RIDs on a worker while the
## aqueduct's own build does.
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
	root.name = "Agora%d" % int(ch.lo)
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
	ch.record = {"name":"agora/%d" % int(ch.lo),"kind":"way","node":root,"pos":xf.origin,"cos":1.0,"sin":0.0,
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
