extends Node3D
## The ruined citadel on the cape north of the town (seed 1, the wilderness):
## a walled enclosure draped over the low rise at about (-592, -5552), built
## from the citadel's pieces (art/blender/temple_kit/citadel_build.py) and a
## few of the kit's. The road of tombs (tombs_site.gd, which extends this
## script for its chunks) arrives at its main gate.
##
## - The curtain wall: an irregular seven-sided ring through V, a round bastion
##   on each corner and a run of BAY-long pieces between (RUNS: one letter a
##   piece). The wall is 21 m thick; the walk on its top, 26.4 m up between
##   the parapets, is 16.2 m clear. The east and north-east runs each stand on
##   one level, so the walk runs on from bastion to bastion; the others step
##   with the ground, piece by piece.
## - The gatehouse in the south run: the passage 18 m wide, 22 m at the crown,
##   44 m through. Its line runs on through the keep's two doors
##   (16 m by 19 m), the cistern's nave under its two ribs and out over the
##   north run's breach.
## - Towers: a square one in the east run (the walk's doors through it), one in
##   the north-east run broken open on the slant, a tall one in the north-west
##   run, and in the west run one split top to bottom and a stub whose
##   walled-up outer door is cracked.
## - Breaches (rubble banks) in the north and south-west runs; a postern in
##   the north-east run and a walled-up, cracked one beside the main gate.
## - Inside: the keep's lower storeys on the rise, the dry cistern north of
##   it, a roofless hall (the kit's columns, lintels and walls) whose nave
##   runs in from the walled-up postern.
##
## Drawn as the agora is (agora_site.gd): chunks (a run with its bastion, the
## axis' buildings, the hall) of MultiMeshes per piece and LOD gathered on a
## worker and made on the main thread, a StaticBody3D of the pieces' boxes on
## LandArches' layer and a `loose` solid record per chunk, each in its chunk's
## own frame (along its run, so the boxes stay tight), streamed within REACH.
## Trees keep off (`tree_keepouts`). `--citadel=0`: no citadel and no road.
##
## To change it: V, RUNS (and LEVEL, the runs that stand level), the towers'
## stacks, AXIS_KEEP / AXIS_CISTERN (m along the gate's line), HALL_IN.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const TempleBreaks = preload("res://scripts/endless/temple_breaks.gd")

const B := TempleKit.BAY
## The ring's corners, anticlockwise seen from above with north up (the
## outside is on a run's local +z): SE, E, NE, N, W, SW, S.
const V: Array[Vector2] = [Vector2(-470,-5430),Vector2(-455,-5560),Vector2(-510,-5690),Vector2(-640,-5710),
	Vector2(-730,-5610),Vector2(-715,-5480),Vector2(-610,-5395)]
## Run i goes from V[i] to V[i+1]. A letter a piece, from the run's start:
## W a whole bay, V one under the gallery, E a standing stretch's end going
## down (e: coming up), L a low stretch (l: turned), P the postern, B the
## walled-up postern, T a square tower (2 bays; its stack in `towers`), S the
## split tower (2 bays), G the gatehouse (3 bays), | a gap left to rubble
## (a run without one is stretched to fit, a few per cent).
## `towers`: each T's stack over its base ("storey", "crown", "ruin"); a
## leading "!" cracks the wall in its outer door (a breakable), which is
## plain stone in the others. `bastion`: the one on the run's first corner.
const RUNS := [
	{"mods":"WTVV","towers":[["storey","crown"]],"bastion":&"citadel_bastion"},
	{"mods":"WWTPW","towers":[["storey","ruin"]],"bastion":&"citadel_bastion_tall"},
	{"mods":"WWE|","bastion":&"citadel_bastion"},
	{"mods":"WTWE|","towers":[["storey","storey","ruin"]],"bastion":&"citadel_bastion_tall"},
	{"mods":"SE|T","towers":[["!","ruin"]],"bastion":&"citadel_bastion_tall"},
	{"mods":"E|eWW","bastion":&"citadel_bastion"},
	{"mods":"WWGB","bastion":&"citadel_bastion_tall"},
]
## The runs that stand on one foot each, the walk level along them (the
## others step piece by piece with the ground). A bastion joins the level run
## that ends on it, else the one that starts on it.
const LEVEL := [0,1]
## A piece's origin stands this far over the lowest ground under it (its
## courses go on down past that: citadel_build.py LIFT, FOOT).
const LIFT := 2.5
## A run's wall ends this far from its corners (inside the bastions' drums).
const END := 16.5
## The pieces' numbers (citadel_build.py).
const WT := 21.0
const WALK := 26.4
const STOREY := 22.0
const TOWER := 37.0
const GATE_D := 44.0
const KEEP := 55.5
const KEEP_FOOT := 8.8
const CISTERN := Vector2(74.0,37.0)
const CISTERN_FOOT := 6.6
## Along the gate's line from the gatehouse's middle: the keep's and the cistern's middles (m).
const AXIS_KEEP := 135.0
const AXIS_CISTERN := 235.0
## The hall: its middle this far in from the walled-up postern, on the
## postern's line (its nave is the way on from the postern); its two rows' half spacing.
const HALL_IN := 62.0
const HALL_HALF := 11.0
## The trees' keep-out (TreePlan adds its ARCH_CLEAR, 18 m).
const KEEP_C := Vector2(-592.0,-5552.0)
const KEEP_HALF := Vector2(160.0,180.0)
const REACH := 3000.0
const FREE := 3400.0
const MID_NEAREST := 60.0
const FAR_NEAREST := 300.0

## The streaming and LOD distances, functions so a site that extends this one
## (dome_site.gd) sets its own: built within reach(), freed past free_at(); a
## piece swaps near -> mid at mid_nearest() and mid -> far at far_nearest() (m
## from its set's nearest, so plus the set's radius from its middle); a piece
## with no mid goes near -> far at nomid_nearest() (INF: at the far swap).
func reach() -> float: return REACH
func free_at() -> float: return FREE
func mid_nearest() -> float: return MID_NEAREST
func far_nearest() -> float: return FAR_NEAREST
func nomid_nearest() -> float: return INF

var game: Node3D
## Each: {name, xf, pieces ([id, local xf]), state, task, made, node, record}.
var chunks: Array = []
## The cracked pieces (temple_breaks.gd).
var breaks: Node3D

static func wanted() -> bool:
	return not ("--citadel=0" in LaunchArgs.user_args())

## TreePlan's keep-outs near a world rectangle, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	if KEEP_C.x < x0-600.0 or KEEP_C.x > x1+600.0 or KEEP_C.y < z0-600.0 or KEEP_C.y > z1+600.0: return []
	return [[KEEP_C,1.0,0.0,KEEP_HALF.x,KEEP_HALF.y]]

static func _h(field: Object, p: Vector2) -> float:
	return float(field.call("height",p.x,p.y))

## A frame at XZ `p` with local +x along `d`, at `y`; `stretch` along its x.
static func _frame(p: Vector2, d: Vector2, y: float, stretch := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,atan2(-d.y,d.x))*Basis.from_scale(Vector3(stretch,1.0,1.0)),Vector3(p.x,y,p.y))

## The lowest ground over a rectangle about `c`: `along` d by `across`, sampled every ~6 m.
static func _low(field: Object, c: Vector2, d: Vector2, along: float, across: float) -> float:
	var lo := INF
	var n := d.orthogonal()
	var na := maxi(1,int(ceil(along/6.0)))
	var nc := maxi(1,int(ceil(across/6.0)))
	for i in range(-na,na+1):
		for j in range(-nc,nc+1):
			lo = minf(lo,_h(field,c+d*(along*i/na)+n*(across*j/nc)))
	return lo

## Run i's start, direction and length.
static func run_line(i: int) -> Array:
	var a := V[i]
	var b := V[(i+1)%V.size()]
	return [a,(b-a).normalized(),a.distance_to(b)]

## How many bays a piece's letter takes.
static func _bays(letter: String) -> float:
	match letter:
		"T","S": return 2.0
		"G": return 3.0
	return 1.0

## Run i's pieces along it: [letter, middle (m from the run's start), length (m), stretch].
static func run_plan(i: int) -> Array:
	var mods: String = RUNS[i].mods
	var total: float = run_line(i)[2]-2.0*END
	var fixed := 0.0
	for k in range(mods.length()):
		if mods[k] != "|": fixed += _bays(mods[k])*B
	var has_gap := mods.contains("|")
	var f := 1.0 if has_gap else total/fixed
	var out: Array = []
	var s := END
	for k in range(mods.length()):
		var len := (total-fixed) if mods[k] == "|" else _bays(mods[k])*B*f
		out.append([mods[k],s+len*0.5,len,f])
		s += len
	return out

## The gatehouse: [its middle (XZ), the way out through it (unit, outward)].
static func gate() -> Array:
	for i in range(RUNS.size()):
		for e: Array in run_plan(i):
			if str(e[0]) != "G": continue
			var line := run_line(i)
			var d: Vector2 = line[1]
			return [(line[0] as Vector2)+d*float(e[1]),Vector2(-d.y,d.x)]
	return [Vector2.ZERO,Vector2.DOWN]

func setup(g: Node3D) -> void:
	game = g
	breaks = TempleBreaks.new()
	add_child(breaks)
	breaks.setup(g)
	_lay(game.field)
	for ch: Dictionary in chunks:
		var inv := (ch.xf as Transform3D).affine_inverse()
		var pieces: Array = ch.pieces
		for k in range(pieces.size()): pieces[k] = [pieces[k][0],inv*(pieces[k][1] as Transform3D)]
	_load_meshes()

## A new chunk in frame `xf`; its number.
func _chunk(label: String, xf: Transform3D) -> int:
	chunks.append({"name":label,"xf":xf,"pieces":[],"state":"away","task":-1})
	return chunks.size()-1

## Piece `id` at world `xf` into chunk `c`.
func _put(c: int, id: StringName, xf: Transform3D) -> void:
	(chunks[c].pieces as Array).append([id,xf])

## Every piece of the citadel into its chunks; the cracked ones to `breaks`.
func _lay(field: Object) -> void:
	var n := V.size()
	# A level run's foot: the lowest ground under any of its pieces.
	var level := {}
	for i: int in LEVEL:
		var line := run_line(i)
		var lo := INF
		for e: Array in run_plan(i):
			lo = minf(lo,_low(field,(line[0] as Vector2)+(line[1] as Vector2)*float(e[1]),line[1],float(e[2])*0.5,WT*0.5+2.0))
		level[i] = lo+LIFT
	for i in range(n):
		var line := run_line(i)
		var a: Vector2 = line[0]
		var d: Vector2 = line[1]
		var len: float = line[2]
		var out := Vector2(-d.y,d.x)
		var c := _chunk("citadel/run%d" % i,_frame(a+d*len*0.5,d,_h(field,a+d*len*0.5)))
		# The bastion on the run's first corner, its outer arc toward the corner's outside.
		var prev := (i+n-1)%n
		var d_prev: Vector2 = run_line(prev)[1]
		var o := (d_prev-d).normalized()
		var by: float = level[prev] if level.has(prev) else (level[i] if level.has(i) else _low(field,a,d,21.0,21.0)+LIFT)
		_put(c,RUNS[i].bastion,Transform3D(Basis(Vector3.UP,atan2(o.x,o.y)),Vector3(a.x,by,a.y)))
		var towers: Array = RUNS[i].get("towers",[])
		var tower := 0
		for e: Array in run_plan(i):
			var letter := str(e[0])
			var p := a+d*float(e[1])
			var f: float = e[3]
			var y: float = level[i] if level.has(i) else _low(field,p,d,float(e[2])*0.5,WT*0.5+2.0)+LIFT
			var xf := _frame(p,d,y,f)
			var back := _frame(p,-d,y,f)
			match letter:
				"W": _put(c,&"citadel_wall",xf if (int(float(e[1])/B)%2 == 0) else back)
				"V": _put(c,&"citadel_wall_gallery",xf)
				"E": _put(c,&"citadel_wall_end",xf)
				"e": _put(c,&"citadel_wall_end",back)
				"L": _put(c,&"citadel_wall_low",xf)
				"l": _put(c,&"citadel_wall_low",back)
				"P","B":
					_put(c,&"citadel_postern",xf)
					if letter == "B": _block(p+out*(WT*0.5-0.6),d,y,"citadel/postern")
				"G": _put(c,&"citadel_gate",xf)
				"S": _put(c,&"citadel_tower_split",xf)
				"T":
					var stack: Array = towers[tower]
					tower += 1
					_put(c,&"citadel_tower_base",xf)
					# Its outer door walled up: cracked in a "!" tower.
					var mouth := p+out*(TOWER*0.5-1.2)
					if stack.has("!"): _block(mouth,d,y,"citadel/tower_door")
					else: _put(c,&"citadel_blocking",_frame(mouth,d,y,f))
					var ty := y+WALK
					for part: String in stack:
						if part == "!": continue
						_put(c,StringName("citadel_tower_"+part),_frame(p,d,ty,f))
						ty += STOREY
				"|":
					var gap: float = e[2]
					if gap < 10.0: continue
					var count := maxi(1,roundi(gap/B))
					for k in range(count):
						var q := a+d*(float(e[1])-gap*0.5+(k+0.5)*gap/count)
						var gy := _low(field,q,d,gap/count*0.5,12.0)-0.2
						_put(c,&"citadel_rubble",_frame(q,d if k%2 == 0 else -d,gy,gap/count/B))
	# ---- The gate's line: the keep and the cistern.
	var gt := gate()
	var gc: Vector2 = gt[0]
	var axis: Vector2 = -(gt[1] as Vector2)
	var kc := gc+axis*AXIS_KEEP
	var cc := gc+axis*AXIS_CISTERN
	var ky := _low(field,kc,axis,KEEP*0.5,KEEP*0.5)+KEEP_FOOT-0.3
	var cy := _low(field,cc,axis,CISTERN.x*0.5,CISTERN.y*0.5)+CISTERN_FOOT-0.3
	var ax := _chunk("citadel/axis",_frame((kc+cc)*0.5,axis,ky))
	_put(ax,&"citadel_keep",_frame(kc,axis,ky))
	_put(ax,&"citadel_cistern",_frame(cc,axis,cy))
	# ---- The hall inside the walled-up postern, its nave on the postern's line:
	# a wall with two doors (west) and a colonnade (east), no roof.
	var hall_c := gc
	var hd := axis
	for i in range(n):
		for e: Array in run_plan(i):
			if str(e[0]) != "B": continue
			var line := run_line(i)
			hd = -Vector2(-(line[1] as Vector2).y,(line[1] as Vector2).x)
			hall_c = (line[0] as Vector2)+(line[1] as Vector2)*float(e[1])+hd*HALL_IN
	var hn := Vector2(-hd.y,hd.x)
	var hall := _chunk("citadel/hall",_frame(hall_c,hd,_h(field,hall_c)))
	var cols: Array[Vector2] = []
	for k in range(5): cols.append(hall_c+hn*HALL_HALF+hd*(k-2.0)*B)
	var col_y := INF
	for p: Vector2 in cols: col_y = minf(col_y,_low(field,p,hd,2.5,2.5))
	col_y -= 0.1
	for k in range(5):
		if k == 4:
			# The last column down along its row's line, past the hall's end.
			_put(hall,&"column_broken",_frame(cols[k],-hd,col_y))
			_put(hall,&"column_drums",_frame(cols[k],hd,_low(field,cols[k]+hd*17.0,hd,10.0,3.0)-0.1))
		else: _put(hall,&"column",_frame(cols[k],hd.rotated(PI*0.5*k),col_y))
	for k in range(3):
		var m := (cols[k]+cols[k+1])*0.5
		_put(hall,&"lintel" if k < 2 else &"lintel_broken",_frame(m,hd,col_y))
	var walls := [[-1.5,&"wall_door",1.0],[-0.5,&"wall_broken",1.0],[1.5,&"wall_door",-1.0]]
	for e: Array in walls:
		var p := hall_c-hn*HALL_HALF+hd*float(e[0])*B
		var wy := _low(field,p,hd,B*0.5,1.5)-0.2
		_put(hall,e[1],_frame(p,hd*float(e[2]),wy))
	var heap := hall_c-hn*HALL_HALF+hd*0.5*B
	_put(hall,&"aqueduct_rubble",_frame(heap,hd.rotated(0.4),_low(field,heap,hd,6.0,6.0)-0.4))

## The cracked wall in a doorway's mouth: its face `d`-wards along the wall at `p`, looking out.
func _block(p: Vector2, d: Vector2, y: float, handle: String) -> void:
	var xf := _frame(p,d,y)
	breaks.add(handle,&"citadel_blocking_cracked",xf,[[&"citadel_blocking_left",xf]])

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
				if d < reach() and not busy and not building:
					ch.state = "building"
					ch.task = WorkerThreadPool.add_task(_make.bind(ch),false,"Citadel")
					building = true
			"up":
				if d > free_at(): _free(ch)
	return building

## On a worker: the chunk's boxes and its sets (one per piece: its frames, box
## and LOD ranges). No resource is made here: the MultiMeshes are made on the
## main thread (_commit).
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
		var far_at := far_nearest()+radius
		var has_mid := TempleKit.lod(id,TempleKit.MID) != null
		var mid_at := mid_nearest()+radius if has_mid else minf(nomid_nearest()+radius,far_at)
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
