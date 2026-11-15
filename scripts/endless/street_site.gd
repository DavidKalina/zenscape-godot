extends Node3D
## The colonnaded street (seed 1, the wilderness): from beside the aqueduct's
## last stretch north-east to the agora's west entrance at J, two rows of the
## temple kit's columns at the street's order (S of the temple's) on their
## stylobates, the way paved between. The street's own pieces are
## art/blender/temple_kit/street_build.py's (kerb, paving, the arch and the
## beam across the way, a low stump).
##
## Built as aqueduct_site.gd: the stations (a column each side) every SEG
## along LINE, cut into chunks of CHUNK stations; each chunk one Node3D of
## MultiMeshes per piece and LOD, one StaticBody3D of its boxes on LandArches'
## layer and one LandArches `loose` record, built on a worker within REACH
## (taking turns with the temple-kit ruins), gone past FREE. Trees keep off
## (`tree_keepouts`). `--street=0`: none.
##
## The contract with the agora: the line's last stretch runs along z = J.y
## in +x and ends at J; the way's clear width between the rows' plinths is
## 2*HALF_CLEAR (16 m); nothing of the street lies past x = J.x - 2.
##
## To change the street: LINE (smoothed; the last two points set the end's
## straight), RIGHT / LEFT (one letter a station, start to end), ARCHES,
## BEAMS, ROW_LINTELS, FALLEN, BROKEN_PAVING.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The agora's west entrance (world XZ): the street arrives here going +x.
const J := Vector2(-370.0,-4760.0)
## The line's corners, start to end (smoothed, Chaikin): off the aqueduct's
## north side, north over the flat west of a hollow, bending east past the
## hollow's north rim, then easing south-east onto z = J.y (another hollow
## lies south-west of J, under the line's straight).
const LINE: Array[Vector2] = [Vector2(-668,-4600),Vector2(-660,-4690),Vector2(-605,-4730),
	Vector2(-525,-4730),Vector2(-445,-4760),Vector2(-370,-4760)]
const SMOOTH := 4
## The street's order against the temple's: the kit's column, lintel, broken
## column, drums and the stump are laid at this scale.
const S := 0.72
## Station to station along the line (a scaled bay), the rows' half spacing
## (column centres), the way's clear half width.
const SEG := 18.5*S
const ROW := 9.8
const HALF_CLEAR := 8.0
## The last station stands this far short of J: the column mesh's bounds (3.1 m\n## out from its centre at S) end short of J.x - 2.
const END_SHORT := 6.2
## The stylobate's top and the paving's over the ground (street_build.py).
const KERB_H := 0.55
const PAVE_H := 0.25
## Each side, a letter a station from the start (missing ones are columns):
## C a column, L one leaning, B snapped a third up, T a low stump, - gone
## (its stylobate stays), _ gone with its stylobate, A an arch's pier.
## Side -1 (RIGHT) is the right travelling toward J (south on the last stretch), 1 (LEFT) the left.
const RIGHT := "ACCCCC-T-C-CCCCATCCLBCC-CCCCC"
const LEFT := "ACCCCCCB-B-C-BCA_____-CCCCTCC"
## Stations with an arch across the way (both sides "A").
const ARCHES := [0,15]
## Stations with a beam across the way, column to column.
const BEAMS := [3,11,25]
## Lintels along a row: [side (-1 right, 1 left), from station, to station].
const ROW_LINTELS := [[-1,1,5],[1,2,6],[-1,11,14],[1,22,24],[-1,24,26]]
## A snapped lintel past a run's end: [side, station it hangs from, +1/-1 toward].
const LINTEL_STUBS := [[-1,5,1],[1,6,1],[1,22,-1],[-1,17,-1],[-1,24,-1]]
## A column fallen across the way from its stump: [side, station].
const FALLEN := [[1,13],[-1,20]]
## Drums lying outside a row where a column went: [side, station].
const DRUMS_OUT := [[-1,6],[1,12],[-1,8],[1,21]]
## The paving: these stations' bays (station k to k+1) broken; GONE ones none.
const BROKEN_PAVING := [6,7,8,12,13,16,17,18,19,20]
const GONE_PAVING := [18]
## Leaning columns: along the line (rad, + back toward the start) and out from the way.
const LEAN_ALONG := 0.13
const LEAN_OUT := 0.05
## The gate's tall pair: the temple's own column (unscaled), out from the
## centre line at the start.
const GATE_OUT := 15.0
## Stations per chunk.
const CHUNK := 7
const REACH := 2600.0
const FREE := 3000.0
## The trees' keep-out round each chunk (TreePlan adds ARCH_CLEAR, 18 m).
const CLEAR_ACROSS := 14.0
const CLEAR_END := 20.0
const MID_NEAREST := 50.0
const FAR_NEAREST := 260.0
const LEAN_SLICE := 4.0

var game: Node3D
var chunks: Array = []

static func wanted() -> bool:
	return not ("--street=0" in LaunchArgs.user_args())

## The line smoothed, as a dense polyline.
static func _smoothed() -> Array[Vector2]:
	var pts: Array[Vector2] = LINE.duplicate()
	for _i in SMOOTH:
		var out: Array[Vector2] = [pts[0]]
		for k in range(pts.size()-1):
			out.append(pts[k].lerp(pts[k+1],0.25))
			out.append(pts[k].lerp(pts[k+1],0.75))
		out.append(pts[-1])
		pts = out
	return pts

## The stations: [centre XZ, direction XZ], start to end, counted back from
## END_SHORT short of the line's end so the last stands at J.
static func stations() -> Array:
	var pts := _smoothed()
	var cum: Array[float] = [0.0]
	for k in range(pts.size()-1): cum.append(cum[-1]+pts[k].distance_to(pts[k+1]))
	var total: float = cum[-1]
	var ss: Array[float] = []
	var s := total-END_SHORT
	while s >= 0.0:
		ss.push_front(s)
		s -= SEG
	var out: Array = []
	for t: float in ss:
		var seg := 0
		while seg < pts.size()-2 and cum[seg+1] < t: seg += 1
		var a: Vector2 = pts[seg]
		var b: Vector2 = pts[seg+1]
		out.append([a.lerp(b,(t-cum[seg])/maxf(cum[seg+1]-cum[seg],0.001)),(b-a).normalized()])
	return out

## A frame at XZ `p` with local +x along `d`, at `y`, scaled `sc`.
static func _frame(p: Vector2, d: Vector2, y: float, sc := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,atan2(-d.y,d.x)).scaled_local(Vector3.ONE*sc),Vector3(p.x,y,p.y))

static func _h(field: Object, p: Vector2) -> float:
	return float(field.call("height",p.x,p.y))

## The lowest ground in a square of half side `r` round `p`.
static func _ground_min(field: Object, p: Vector2, r: float) -> float:
	var lo := INF
	for i in [-1.0,0.0,1.0]:
		for j in [-1.0,0.0,1.0]:
			lo = minf(lo,_h(field,p+Vector2(i,j)*r))
	return lo

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
		if c.x > x0-400.0 and c.x < x1+400.0 and c.y > z0-400.0 and c.y < z1+400.0: out.append(e)
	return out

static var _keep: Array = []
static var _keep_lock := Mutex.new()

static func _keepouts() -> Array:
	var out: Array = []
	var st := stations()
	var n := st.size()
	var k := 0
	while k < n-1:
		var k1 := mini(k+CHUNK,n-1)
		var a: Vector2 = st[k][0]
		var b: Vector2 = st[k1][0]
		var d := (b-a).normalized()
		var half := a.distance_to(b)*0.5+(CLEAR_END if k == 0 else 0.0)+(0.0 if k1 == n-1 else SEG*0.5)
		var c := (a+b)*0.5-(d*CLEAR_END*0.5 if k == 0 else Vector2.ZERO)
		var yaw := atan2(d.x,d.y)
		out.append([c,cos(yaw),sin(yaw),CLEAR_ACROSS,half])
		k = k1
	return out

func setup(g: Node3D) -> void:
	game = g
	var field: Object = game.field
	var st := stations()
	var n := st.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	# Every piece: [station, id, xf, lean]; each goes to its station's chunk.
	var all: Array = []
	var side_of := {-1:RIGHT,1:LEFT}
	var dirs: Array[Vector2] = []
	for k in range(n):
		var d: Vector2 = st[k][1]
		if k > 0: d = (d+(st[k][0]-st[k-1][0]).normalized()).normalized()
		dirs.append(d)
	# The column foot each side: on its footprint's lowest ground, the stylobate's top.
	var foot := {}
	for k in range(n):
		for sd: int in [-1,1]:
			var p := _side(st,dirs,k,sd)
			foot[Vector2i(k,sd)] = _ground_min(field,p,2.0)+KERB_H
	for k in range(n):
		var c: Vector2 = st[k][0]
		var d: Vector2 = dirs[k]
		for sd: int in [-1,1]:
			var letter := _letter(side_of[sd],k)
			var p := _side(st,dirs,k,sd)
			var y: float = foot[Vector2i(k,sd)]
			var out := d.orthogonal()*float(sd)
			match letter:
				"C":
					all.append([k,&"column",_frame(p,d if rng.randf() < 0.5 else -d,y-0.05,S),false])
				"L":
					var xf := _frame(p,d,y-0.1,S)
					var pivot := Vector3(p.x,y,p.y)
					var axis := Vector3(out.x,0.0,out.y)
					var along := Vector3(d.x,0.0,d.y)
					var turn := Basis(axis,LEAN_ALONG)*Basis(along,LEAN_OUT)
					xf = Transform3D(turn,pivot)*Transform3D(Basis(),-pivot)*xf
					all.append([k,&"column",xf,true])
				"B":
					var fall := [sd,k] in FALLEN
					var to := -out if fall else d.rotated(rng.randf_range(-PI,PI))
					all.append([k,&"column_broken",_frame(p,to,y-0.05,S),false])
				"T":
					all.append([k,&"street_stump",_frame(p,d.rotated(rng.randf_range(-PI,PI)),y-0.05,S),false])
		if k in ARCHES:
			var yl := minf(foot[Vector2i(k,-1)],foot[Vector2i(k,1)])
			all.append([k,&"street_arch",_frame(c,d.orthogonal(),yl),false])
		if k in BEAMS:
			var yb := minf(foot[Vector2i(k,-1)],foot[Vector2i(k,1)])
			all.append([k,&"street_lintel_cross",_frame(c,d.orthogonal(),yb),false])
	# The gate's tall pair, outside the arch's piers, on the ground.
	for sd: int in [-1,1]:
		var p: Vector2 = st[0][0]+dirs[0].orthogonal()*float(sd)*GATE_OUT
		all.append([0,&"column",_frame(p,dirs[0],_ground_min(field,p,2.5)-0.1),false])
	# The bays: stylobates, paving, lintels along the rows.
	for k in range(n-1):
		var a: Vector2 = st[k][0]
		var b: Vector2 = st[k+1][0]
		var m := (a+b)*0.5
		var d := (b-a).normalized()
		for sd: int in [-1,1]:
			var la := _letter(side_of[sd],k)
			var lb := _letter(side_of[sd],k+1)
			var gone := la == "_" and lb == "_" or ((la == "_" or lb == "_") and rng.randf() < 0.5)
			if gone: continue
			var pa := _side(st,dirs,k,sd)
			var pb := _side(st,dirs,k+1,sd)
			var ya: float = foot[Vector2i(k,sd)]-KERB_H
			var yb: float = foot[Vector2i(k+1,sd)]-KERB_H
			all.append([k,&"street_kerb",_tilted((pa+pb)*0.5,(pb-pa).normalized(),ya,yb,0.0,0.0),false])
		if not (k in GONE_PAVING):
			var id: StringName = &"street_paving_broken" if k in BROKEN_PAVING else &"street_paving"
			var q := d.orthogonal()*(HALF_CLEAR-1.0)
			# Fitted to the ground: pitched along, rolled across, sunk a little.
			var g0 := _h(field,m-d*SEG*0.45)
			var g1 := _h(field,m+d*SEG*0.45)
			var gl := _h(field,m+q)
			var gr := _h(field,m-q)
			var dir := d if rng.randf() < 0.5 else -d
			var flip := 1.0 if dir == d else -1.0
			all.append([k,id,_tilted(m,dir,g0 if flip > 0 else g1,g1 if flip > 0 else g0,(gl-gr)*flip,HALF_CLEAR-1.0),false])
	for e: Array in ROW_LINTELS:
		var sd: int = e[0]
		for k in range(int(e[1]),int(e[2])):
			all.append([k,&"lintel",_between(st,dirs,foot,k,sd,1.0),false])
	for e: Array in LINTEL_STUBS:
		var sd: int = e[0]
		var k: int = e[1]
		var tw: int = e[2]
		var k0 := mini(k,k+tw)
		var xf := _between(st,dirs,foot,k0,sd,float(tw))
		all.append([k,&"lintel_broken",xf,false])
	# Fallen columns: the drums across the way from their stump, on the paving.
	for e: Array in FALLEN:
		var sd: int = e[0]
		var k: int = e[1]
		var p := _side(st,dirs,k,sd)
		var to := -dirs[k].orthogonal()*float(sd)
		# Half sunk: the drums' tops stand under 2.4 m over the way.
		var y := _h(field,st[k][0])+PAVE_H-0.8
		all.append([k,&"column_drums",_frame(p,to.rotated(0.12*float(sd)),y,S),false])
	for e: Array in DRUMS_OUT:
		var sd: int = e[0]
		var k: int = e[1]
		var p := _side(st,dirs,k,sd)
		var to := dirs[k].orthogonal()*float(sd)
		var r := to.rotated(rng.randf_range(-0.6,0.6))
		all.append([k,&"column_drums",_frame(p-to*4.0,r,_ground_min(field,p+r*10.0,6.0)-0.05,S),false])
	# Stone where the left side went: rubble heaps, small.
	for k in range(n):
		if _letter(LEFT,k) == "_" and k % 2 == 0:
			var p := _side(st,dirs,k,1)+dirs[k].orthogonal()*rng.randf_range(0.0,3.0)
			all.append([k,&"aqueduct_rubble",_frame(p,dirs[k].rotated(rng.randf_range(-1.0,1.0)),_ground_min(field,p,3.0)-0.2,0.4),false])
	# Chunks.
	var k := 0
	while k < n:
		var k1 := mini(k+CHUNK,n)-1
		var a: Vector2 = st[k][0]
		var b: Vector2 = st[k1][0] if k1 > k else a+dirs[k]
		chunks.append({"xf":_frame((a+b)*0.5,(b-a).normalized(),_h(field,(a+b)*0.5)),"lo":k,"hi":k1,"pieces":[],"state":"away","task":-1})
		k = k1+1
	for e: Array in all:
		for ch: Dictionary in chunks:
			if int(e[0]) >= int(ch.lo) and int(e[0]) <= int(ch.hi):
				(ch.pieces as Array).append([e[1],(ch.xf as Transform3D).affine_inverse()*(e[2] as Transform3D),e[3]])
				break

static func _letter(row: String, k: int) -> String:
	return row[k] if k < row.length() else "C"

## A station's column centre on side `sd` (-1 right, 1 left of travel).
static func _side(st: Array, dirs: Array[Vector2], k: int, sd: int) -> Vector2:
	var c: Vector2 = st[k][0]
	return c+dirs[k].orthogonal()*float(sd)*ROW

## A lintel's frame (kit lintel, origin at its middle on the columns' feet)
## between stations k and k+1 on side sd.
static func _between(st: Array, dirs: Array[Vector2], foot: Dictionary, k: int, sd: int, tw: float) -> Transform3D:
	var pa := _side(st,dirs,k,sd)
	var pb := _side(st,dirs,k+1,sd)
	var y := minf(foot[Vector2i(k,sd)],foot[Vector2i(k+1,sd)])-0.05
	var d := (pb-pa).normalized()
	# lintel_broken hangs from its -x end: turned so that end is on the standing column.
	return _frame((pa+pb)*0.5,d*(1.0 if tw > 0.0 else -1.0),y,S)

## A frame at `p` along `d`, its ends at heights ya (back) and yb (front),
## rolled so its sides differ by `across` over 2*`half` (pieces on the ground).
static func _tilted(p: Vector2, d: Vector2, ya: float, yb: float, across: float, half: float) -> Transform3D:
	var pitch := atan2(yb-ya,SEG)
	var roll := atan2(across,2.0*half) if half > 0.0 else 0.0
	var b := Basis(Vector3.UP,atan2(-d.y,d.x))*Basis(Vector3.BACK,pitch)*Basis(Vector3.RIGHT,roll)
	return Transform3D(b,Vector3(p.x,(ya+yb)*0.5,p.y))

## One frame: the chunks streamed round the eye. Returns whether one builds.
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
					ch.task = WorkerThreadPool.add_task(_make.bind(ch),false,"Street")
					building = true
			"up":
				if d > FREE: _free(ch)
	return building

## On a worker: the chunk's MultiMeshes off the tree, and its boxes.
func _make(ch: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Street%d" % int(ch.lo)
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
	ch.record = {"name":"street/%d" % int(ch.lo),"kind":"way","node":root,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
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
