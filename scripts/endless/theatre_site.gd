extends Node3D
## The ruined theatre on the east flank of the hill south of the aqueduct's
## start (seed 1, the wilderness): a half bowl of stepped seating laid against
## the slope, an orchestra floor at its foot and a stage wall across the open
## side, from the theatre's own pieces (art/blender/temple_kit/theatre_build.py)
## and the temple kit's.
##
## The bowl's frame: C the orchestra's centre, U the way uphill (the bowl's
## axis), V across (U turned a quarter). A point is C + U*s + V*v; an angle is
## measured from U toward V, the bowl spanning -90..90 degrees in 12 SECTORS.
##
## - The seating: 5 rings of sector pieces from R0 out to 63.6 m, each a solid
##   block of masonry from under the floor up to its rows, so it stands where
##   the hill is under it and where it is not (the wings); pieces missing
##   (GONE) show the land, others have lost seats (broken) or slumped.
## - The rim: a terrace 63.6..75 m at RIM_TOP over the floor, the kit's
##   columns on it COL_R from C at the sectors' middles (18.5 m apart),
##   lintels over the two runs that stand; the two on the axis are gone, a
##   gap 49 m clear where the dive comes in.
## - The stage wall: bays along V at s -31..-26: the middle doorway on the
##   axis (16 m by 22.4 m), a doorway each side (12.5 m by 18.25 m, centred
##   29 m off the axis), solid bays between, the +v end fallen (26 m of stump
##   and blocks). The ground rises toward -v: the wall there stands in it.
## - The side arches: across the passage between the wall and the seats' ends,
##   65.5 m either side of the axis (18 m by 18.6 m).
##
## Drawn as the agora is (agora_site.gd): MultiMeshes per piece and LOD made on
## the main thread once a worker has sorted the pieces, streamed within REACH.
## The solids: one StaticBody3D and one LandArches `loose` record per sector
## and one for the stage, each in its own turned frame so the pieces' boxes
## stay exact. Trees keep off (`tree_keepouts`). `--theatre=0`: none.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const TempleBreaks = preload("res://scripts/endless/temple_breaks.gd")

const C := Vector2(-796.5,-3747.0)
const UP_DEG := 190.0
const SECTORS := 12
const SECTOR_DEG := 15.0
## theatre_build.py's numbers.
const R0 := 18.0
const RINGS: Array[Vector2] = [Vector2(18.0,26.4),Vector2(26.4,34.8),Vector2(34.8,43.2),Vector2(43.2,55.2),Vector2(55.2,63.6)]
const RIM := Vector2(63.6,75.0)
const RIM_TOP := 21.5
## Each ring's first row's top over the floor (a slumped piece turns about it).
const RING_TOP: Array[float] = [1.5,5.1,8.7,11.1,18.3]
## The rim's columns: from C, at the sectors' middles (a BAY's chord apart).
const COL_R := 70.87
## The stage wall's axis and face (s), and the side arches' middles (v).
const WALL_S := -28.5
const FACE_S := -26.0
const ARCH_V := 65.5
## The floor's paving: the agora's tile at half size, in rows along V.
const TILE := 9.25
const FLOOR_S0 := -21.4
const FLOOR_ROWS := 5
const FLOOR_COLS := 12
## Seating pieces gone, [ring, sector]: the land shows there.
const GONE: Array[Vector2i] = [Vector2i(1,6),Vector2i(2,7),Vector2i(3,5),Vector2i(0,9),Vector2i(4,6),Vector2i(1,2),Vector2i(2,3),Vector2i(0,4)]
## Slumped, [ring, sector]: sunk and tipped.
const SLUMPED: Array[Vector2i] = [Vector2i(1,7),Vector2i(2,6),Vector2i(1,5),Vector2i(3,8),Vector2i(2,10),Vector2i(0,1),Vector2i(4,3)]
## What the plane breaks in a surge roll (temple_breaks.gd):
## - the stage wall's bay at this v (between the middle doorway and a side
##   one), split down from its window's notch, the wedge between the cracks
##   pushed out ("theatre/stage": a slot 6.5 m wide is left, top to floor);
## - the rim's lintels by number, in three with the middle dropped
##   ("theatre/lintel_<k>": their ends are left on the abaci);
## - the rim's columns by sector, slipped apart ("theatre/column_<k>": a stump).
const CRACKED_STAGE := 16.0
const CRACKED_LINTELS: Array[int] = [3]
const CRACKED_COLUMNS: Array[int] = [10]
## The trees' keep-out (TreePlan adds its ARCH_CLEAR, 18 m).
const KEEP_C := Vector2(-818.0,-3747.0)
const KEEP_HALF := Vector2(64.0,84.0)
const REACH := 3000.0
const FREE := 3400.0
const MID_NEAREST := 50.0
const FAR_NEAREST := 280.0

var game: Node3D
## {root (the drawing's frame, world), draws ([id, world xf]), groups ([{xf, pieces}]), state, task, made, node, records}.
var site := {}
## The cracked pieces (temple_breaks.gd).
var breaks: Node3D

static func wanted() -> bool:
	return not ("--theatre=0" in LaunchArgs.user_args())

## TreePlan's keep-outs near a world rectangle, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	if KEEP_C.x < x0-500.0 or KEEP_C.x > x1+500.0 or KEEP_C.y < z0-500.0 or KEEP_C.y > z1+500.0: return []
	return [[KEEP_C,1.0,0.0,KEEP_HALF.x,KEEP_HALF.y]]

static func _u() -> Vector2:
	return Vector2.from_angle(deg_to_rad(UP_DEG))

static func _v() -> Vector2:
	var u := _u()
	return Vector2(-u.y,u.x)

## The world XZ of (s, v).
static func at_sv(s: float, v: float) -> Vector2:
	return C+_u()*s+_v()*v

## The way out from C at `deg` from U toward V.
static func dir_at(deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return _u()*cos(a)+_v()*sin(a)

## The turn about y that points a piece's +x along `d`.
static func _yaw(d: Vector2) -> float:
	return atan2(-d.y,d.x)

static func _h(field: Object, x: float, z: float) -> float:
	return float(field.call("height",x,z))

static func _frame(p: Vector2, y: float, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw),Vector3(p.x,y,p.y))

## The floor's height: the ground's mean over the orchestra's middle.
static func floor_y(field: Object) -> float:
	var sum := 0.0
	var n := 0
	for i in range(-2,3):
		for j in range(-2,3):
			var p := at_sv(i*6.0-4.0,j*6.0)
			sum += _h(field,p.x,p.y)
			n += 1
	return sum/n-0.4

## Whether a seating piece is there.
static func _seat_gone(ring: int, sector: int) -> bool:
	return GONE.has(Vector2i(ring,sector))

## Whether a floor tile is laid at row i (along s), column j (along v).
static func _tile_laid(i: int, j: int) -> bool:
	var s := FLOOR_S0+i*TILE
	var v := (j-(FLOOR_COLS-1)*0.5)*TILE
	if s > 2.0 and Vector2(s,v).length() > R0+1.0: return false
	if s <= 2.0 and absf(v) > 58.0: return false
	# Lost: toward the fallen end and here and there.
	var k := (i*7+j*13+i*j*3)%11
	if v > 30.0 and k < 5: return false
	return k != 3

func setup(g: Node3D) -> void:
	game = g
	var field: Object = game.field
	var y0 := floor_y(field)
	var laid := layout(field)
	var groups: Array = []
	for k in range(SECTORS+1): groups.append({"xf":group_frame(k,y0),"pieces":[]})
	breaks = TempleBreaks.new()
	add_child(breaks)
	breaks.setup(g)
	var draws: Array = []
	for e: Array in laid:
		if e.size() > 3:
			breaks.add(e[3],e[0],e[1],e[4])
			continue
		draws.append([e[0],e[1]])
		var gi := int(e[2])
		var gxf: Transform3D = groups[gi].xf
		(groups[gi].pieces as Array).append([e[0],gxf.affine_inverse()*(e[1] as Transform3D)])
	site = {"root":_frame(C,y0),"draws":draws,"groups":groups,"state":"away","task":-1}
	_load_meshes()

## Group k's frame: a sector's (its +x out along the sector's middle), or the stage's (k SECTORS, its +x along V).
static func group_frame(k: int, y0: float) -> Transform3D:
	if k >= SECTORS: return _frame(C,y0,_yaw(_v()))
	return _frame(C,y0,_yaw(dir_at(-90.0+SECTOR_DEG*(k+0.5))))

## Every piece, world: [id, xf, group]; a cracked one [id, xf, group, its name, what is left ([id, xf])].
static func layout(field: Object) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4410
	var y0 := floor_y(field)
	# ---- The seating and the rim.
	for k in range(SECTORS):
		var gxf := group_frame(k,y0)
		for ring in range(RINGS.size()):
			if _seat_gone(ring,k): continue
			var broken := rng.randf() < 0.3
			var xf := gxf
			if SLUMPED.has(Vector2i(ring,k)):
				broken = true
				var pivot := Vector3((RINGS[ring].x+RINGS[ring].y)*0.5,RING_TOP[ring],0.0)
				var tip := Basis(Vector3(0,0,1),rng.randf_range(0.04,0.08))*Basis(Vector3(1,0,0),rng.randf_range(-0.04,0.04))
				xf = gxf*Transform3D(Basis(),pivot+Vector3(0.0,-rng.randf_range(0.5,1.0),0.0))*Transform3D(tip,Vector3.ZERO)*Transform3D(Basis(),-pivot)
			out.append([StringName("theatre_seat_broken_%d" % ring if broken else "theatre_seat_%d" % ring),xf,k])
		out.append([&"theatre_rim",gxf,k])
	# The columns at the sectors' middles: 0 and 11 stumps, 5 and 6 (either
	# side of the axis) gone, the rest standing; lintels 1-4 and 7-9.
	var top := y0+RIM_TOP
	for k in range(SECTORS):
		if k == 5 or k == 6: continue
		var d := dir_at(-90.0+SECTOR_DEG*(k+0.5))
		var p := C+d*COL_R
		var cxf := _frame(p,top,_yaw(d))
		if k in CRACKED_COLUMNS and k != 0 and k != 11:
			out.append([&"column_cracked_wide",cxf,k,"theatre/column_%d" % k,[[&"street_stump",cxf]]])
		else: out.append([&"column_broken" if k == 0 or k == 11 else &"column",cxf,k])
	for e: Array in [[10.55,-1.5,0.3],[11.3,-4.0,1.2],[5.4,-2.5,0.7]]:
		var d := dir_at(-90.0+SECTOR_DEG*float(e[0]))
		out.append([&"agora_drum",_frame(C+d*(COL_R+float(e[1])),top,_yaw(d)+float(e[2])),int(e[0])])
	for k in [1,2,3,7,8]:
		var d := dir_at(-90.0+SECTOR_DEG*(k+1))
		var m := C+d*(COL_R*cos(deg_to_rad(SECTOR_DEG*0.5)))
		var lxf := _frame(m,top,_yaw(d)+PI*0.5)
		if k in CRACKED_LINTELS: out.append([&"lintel_cracked_wide",lxf,k,"theatre/lintel_%d" % k,[[&"lintel_snapped",lxf]]])
		else: out.append([&"lintel",lxf,k])
	# ---- The stage wall: [piece, v, turned].
	var st := SECTORS
	var syaw := _yaw(_v())
	# The fallen bay's tall end and the ends' low ends are at their +x: turned, they face -v.
	for e: Array in [[&"theatre_stage_mid",0.0,false],[&"theatre_stage_wall",16.0,false],[&"theatre_stage_wall",-16.0,true],
			[&"theatre_stage_door",29.0,false],[&"theatre_stage_door",-29.0,true],
			[&"theatre_stage_wall",-42.0,false],[&"theatre_stage_wall",-52.0,true],[&"theatre_stage_end",-62.5,true],
			[&"theatre_stage_fallen",50.0,true],[&"theatre_stage_end",68.5,true]]:
		var p := at_sv(WALL_S,float(e[1]))
		var wxf := _frame(p,y0,syaw+(PI if bool(e[2]) else 0.0))
		if e[0] == &"theatre_stage_wall" and is_equal_approx(float(e[1]),CRACKED_STAGE):
			out.append([&"theatre_stage_wall_cracked",wxf,st,"theatre/stage",[[&"theatre_stage_wall_holed",wxf]]])
		else: out.append([e[0],wxf,st])
	# The -v arch a course up, on the rising ground.
	out.append([&"theatre_side_arch",_frame(at_sv(FACE_S,-ARCH_V),y0+2.4,syaw),st])
	out.append([&"theatre_side_arch",_frame(at_sv(FACE_S,ARCH_V),y0,syaw),st])
	# ---- On the floor: drums off the lines through the doorways, a fallen
	# column along the +v wing's foot, a heap where the seating is gone at the wing.
	for e: Array in [[&"agora_drum",-21.0,14.5,1.3],[&"agora_drum",-20.5,-17.0,0.2],[&"agora_drum",-14.0,46.0,1.9],
			[&"agora_drum",2.0,-42.0,0.5],[&"column_drums",-3.5,26.0,syaw],[&"aqueduct_rubble",-12.0,-50.0,0.8]]:
		var p := at_sv(float(e[1]),float(e[2]))
		out.append([e[0],_frame(p,_h(field,p.x,p.y)+0.05,float(e[3])),st])
	var hole := C+dir_at(-90.0+SECTOR_DEG*2.5)*30.5
	out.append([&"aqueduct_rubble",_frame(hole,_h(field,hole.x,hole.y)-0.3,2.4),st])
	# ---- The floor's paving, on the ground's own tilt.
	for i in range(FLOOR_ROWS):
		for j in range(FLOOR_COLS):
			if not _tile_laid(i,j): continue
			var c := at_sv(FLOOR_S0+i*TILE,(j-(FLOOR_COLS-1)*0.5)*TILE)
			var broken := (i*5+j*3)%7 < 2 or j == 0 or j >= FLOOR_COLS-3
			out.append([&"agora_paving_broken" if broken else &"agora_paving",_tile(field,c,syaw+rng.randi_range(0,3)*PI*0.5),st])
	return out

## A floor tile's frame: on the ground's plane through its corners, sunk a little, half size.
static func _tile(field: Object, c: Vector2, yaw: float) -> Transform3D:
	var h := TILE*0.5
	var hx0 := _h(field,c.x-h,c.y)
	var hx1 := _h(field,c.x+h,c.y)
	var hz0 := _h(field,c.x,c.y-h)
	var hz1 := _h(field,c.x,c.y+h)
	var hc := (_h(field,c.x,c.y)+hx0+hx1+hz0+hz1)/5.0
	var n := Vector3(-(hx1-hx0)/TILE,1.0,-(hz1-hz0)/TILE).normalized()
	var tilt := Basis()
	var ax := Vector3.UP.cross(n)
	if ax.length() > 1e-5: tilt = Basis(ax.normalized(),Vector3.UP.angle_to(n))
	return Transform3D((tilt*Basis(Vector3.UP,yaw)).scaled(Vector3(0.5,0.5,0.5)),Vector3(c.x,hc+0.05,c.y))

## The grass kept off the floor's paving, the seating that stands and the rim
## (endless_grass.gd grow_cell, over its cell's LandField.grid): every node
## there reads as a river's water (`river` -1, as the agora's). Seed 1 only.
static func grass_off(got: Dictionary, land_seed: int, x0: float, z0: float, n: int, pad: int) -> void:
	if land_seed != 1 or not wanted() or not got.has("river"): return
	var gx0 := x0-pad
	var gz0 := z0-pad
	var reach := RIM.y+4.0
	if gx0+n-1 < C.x-reach or gx0 > C.x+reach or gz0+n-1 < C.y-reach or gz0 > C.y+reach: return
	var u := _u()
	var v := _v()
	var rs: PackedFloat32Array = got.river
	var i0 := maxi(ceili(C.x-reach-gx0),0)
	var i1 := mini(floori(C.x+reach-gx0),n-1)
	var j0 := maxi(ceili(C.y-reach-gz0),0)
	var j1 := mini(floori(C.y+reach-gz0),n-1)
	for jj in range(j0,j1+1):
		for ii in range(i0,i1+1):
			var d := Vector2(gx0+ii,gz0+jj)-C
			var s := d.dot(u)
			var w := d.dot(v)
			var off := false
			var r := d.length()
			if s >= 0.0 and r >= R0 and r <= RIM.y:
				if r >= RIM.x: off = true
				else:
					var sector := clampi(int((rad_to_deg(atan2(w,s))+90.0)/SECTOR_DEG),0,SECTORS-1)
					var ring := 0
					while ring < RINGS.size()-1 and r > RINGS[ring].y: ring += 1
					off = not _seat_gone(ring,sector)
			elif s > WALL_S-3.5 and s < R0:
				# The floor between the doorways and under the wall: bare. Out
				# toward the side arches: only where a tile lies.
				if s >= 0.0 or absf(w) < 40.0: off = true
				elif s < FACE_S: off = absf(w) < 75.0
				else:
					var i := roundi((s-FLOOR_S0)/TILE)
					var j := roundi(w/TILE+(FLOOR_COLS-1)*0.5)
					off = i >= 0 and i < FLOOR_ROWS and j >= 0 and j < FLOOR_COLS and _tile_laid(i,j)
			if off:
				var k := jj*n+ii
				rs[k] = minf(rs[k],-1.0)
	got.river = rs

## One frame: the site streamed round the eye. `busy`: a temple-kit build is
## running elsewhere (one at a time). Returns whether it is building.
func step(eye: Vector3, busy: bool, here: bool) -> bool:
	var building := false
	if str(site.state) == "building":
		if WorkerThreadPool.is_task_completed(int(site.task)): _commit()
		else: building = true
	if here: breaks.step(eye,not busy and not building)
	var d := Vector2(C.x-eye.x,C.y-eye.z).length() if here else INF
	match str(site.state):
		"away":
			if d < REACH and not busy and not building:
				site.state = "building"
				site.task = WorkerThreadPool.add_task(_make,false,"Theatre")
				building = true
		"up":
			if d > FREE: _free()
	return building

## On a worker: the drawing's sets (one per piece: its frames in the root's
## frame, box and LOD ranges) and each group's boxes and solid. No resource is
## made here (as the agora: the MultiMeshes are made on the main thread).
func _make() -> void:
	var root: Transform3D = site.root
	var inv := root.affine_inverse()
	var by_id := {}
	for e: Array in site.draws:
		var id: StringName = e[0]
		if not by_id.has(id): by_id[id] = []
		(by_id[id] as Array).append(inv*(e[1] as Transform3D))
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
	var solids: Array = []
	for g: Dictionary in site.groups:
		var boxes: Array = []
		var reach := 0.0
		for e: Array in g.pieces:
			var xf: Transform3D = e[1]
			for box: AABB in TempleKit.boxes(e[0]):
				var b: AABB = xf*box
				boxes.append(b)
				for corner in [Vector2(b.position.x,b.position.z),Vector2(b.end.x,b.end.z),
						Vector2(b.position.x,b.end.z),Vector2(b.end.x,b.position.z)]:
					reach = maxf(reach,(corner as Vector2).length())
		solids.append({"boxes":boxes,"reach":reach,"solid":BoxSolid.build(boxes)})
	site.made = {"sets":sets,"solids":solids}

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

## On the main thread: the MultiMeshes, in the tree, the groups' bodies and solids.
func _commit() -> void:
	WorkerThreadPool.wait_for_task_completion(int(site.task))
	site.task = -1
	var made: Dictionary = site.made
	site.erase("made")
	var root := Node3D.new()
	root.name = "TheatreDraw"
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
	root.transform = site.root
	add_child(root)
	var nodes: Array = [root]
	var records: Array = []
	for k in range((site.groups as Array).size()):
		var solid: Dictionary = made.solids[k]
		var boxes: Array = solid.boxes
		if boxes.is_empty(): continue
		var xf: Transform3D = site.groups[k].xf
		var body := StaticBody3D.new()
		body.name = "TheatreBody%d" % k
		body.collision_layer = game.arches.LAYER
		body.collision_mask = 0
		for box: AABB in boxes:
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
		var record := {"name":"theatre/%d" % k,"kind":"way","node":body,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
			"solid":solid.solid,"reach":float(solid.reach)+BoxSolid.grow_most()+10.0,"spec":{},"no_break":true}
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
