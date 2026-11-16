extends Node3D
## The ruined amphitheatre on the south plain below the Peak (seed 1, the
## wilderness): an oval of 30 bays, 200 m by 163 m over its outer wall, built
## from the arena's own pieces (art/blender/temple_kit/arena_build.py) and
## the temple kit's.
##
## The oval is four arcs: the ends (bays 0-6 east, 15-21 west; radius R_B)
## and the sides (7-14 south, 22-29 north; radius R_A), every bay 19.2 m on
## the outer wall's line. Inward from that line: the outer wall (5 m), the
## ring corridor (16 m clear, 16 m high at its walls and 20 m at the vault's
## crown), the inner wall (3 m), the seating (18 m), the arena (121 m by 81 m).
## Each bay's state is a letter in the rows below. It stands in four
## stretches: the north-east (bays 24-2, up to three tiers, the roofed upper
## gallery), the south (5-12, two tiers), a lone arch (16) and the north-west
## (21-22); the west end (17-20) is breached to the ground and the east (2-4),
## the south-west (13-15) and the north (23-24) are open. Bays 3 and 18 lie on
## the long axis; bays 7/22 and 10/25 are ways straight through and face
## each other across the arena.
##
## Drawn as the agora is (agora_site.gd): MultiMeshes per piece and LOD in
## groups of GROUP bays, made on the main thread. The flight's solid is one
## `loose` record and StaticBody3D a bay, in the bay's own frame (its boxes
## stay exact however the bay is turned), and one for what lies on the
## ground. Trees keep off (`tree_keepouts`); grass keeps off the arena's
## paving (`grass_off`). `--colosseum-ruin=0`: none.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const B := TempleKit.BAY
## The oval's middle (world XZ); its long axis lies along x.
const CENTRE := Vector2(-3150.0,2080.0)
## The oval (arena_build.py holds the same numbers).
const PHI := 0.9272952180016122
const H_B := PHI/7.0
const H_A := (PI*0.5-PHI)/8.0
const R_B := 72.0
const N_END := 7
const N_SIDE := 8
const N := 30
## Depths inward from the outer wall's line (m).
const SEATS_END := 39.5
## The second tier's foot over the datum.
const TIER := 22.0
## Each bay's parts, a letter a bay. F full, B broken (its standing half
## toward the next bay), b broken the other way, X both stubs; V/v the vault
## and its stub; I an arched inner wall; S/s the seating and its broken bank,
## P a way through to the arena. UPPER and TOP are the outer wall's second
## and third tiers (TIER and TOP_AT up); INNER2 and VAULT2 the upper gallery
## on the terrace: its inner arcade and its roof.
const OUTER := "FFb.BFFFFFFFFb.BFb..BFFbBFFFFF"
const UPPER := "Fb...BFFFFb.....X....BF..BFFFF"
const TOP := "b.........................BFFF"
const VAULT := "Vv...vVV.VVv....v....vV..vVVVV"
const INNER := "II...IIIIIIIII..I....III.IIIII"
const SEATS := "Ss...sSPSSPSs...s....sPS.PSSPS"
const INNER2 := "I.....II.I................IIII"
const VAULT2 := "...........................VVV"
## Fallen stone: [bay, along (m, toward the bay before), inward (m), turn].
const HEAPS := [[2,2.0,-7.0,0.4],[4,-2.0,-8.0,1.2],[2,-1.0,-24.0,2.0],[4,3.0,9.0,0.2],
	[13,-2.0,-7.0,2.6],[14,5.0,-24.0,0.9],[14,-5.0,8.0,1.7],[15,2.0,-6.0,0.3],
	[17,2.0,-7.0,2.9],[17,-1.0,9.0,1.1],[19,2.0,-28.0,0.6],[19,-5.0,-10.0,2.2],[19,-6.0,10.0,1.4],
	[20,2.0,-6.0,0.1],[17,0.0,30.0,0.8],[23,-2.0,-7.0,2.4],
	[1,0.0,33.0,1.9],[12,0.0,33.0,0.5],[21,0.0,33.0,2.7]]
## Whole bays of wall lying where they fell: [bay, along, inward (the foot), fell inward].
## The long axis (bays 3 and 18) is left clear.
const FALLEN := [[2,1.0,-5.0,false],[4,-1.0,24.0,true],[14,0.0,-5.0,false],[19,-1.0,-5.0,false],
	[19,-1.0,22.0,true],[24,3.0,-22.0,false]]
const TOP_AT := 38.0
## The arena's paving: tile centres CENTRE + (i-3, j-2)*B.
const PAVE_N := Vector2i(7,5)
const KEEP_HALF := Vector2(114.0,96.0)
const GROUP := 4
const REACH := 3000.0
const FREE := 3400.0
const MID_NEAREST := 50.0
const FAR_NEAREST := 280.0

var game: Node3D
## The bays' solids and the ground's: {xf, pieces ([id, local xf]), name}.
var parts: Array = []
## The drawn groups: {xf, pieces ([id, local xf]), name}.
var groups: Array = []
var state := "away"
var task := -1
var made: Dictionary = {}
var todo: Array = []
var nodes: Array = []
var records: Array = []
var _piece_box := {}

static func wanted() -> bool:
	return not ("--colosseum-ruin=0" in LaunchArgs.user_args())

## TreePlan's keep-outs near a world rectangle, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	if CENTRE.x < x0-500.0 or CENTRE.x > x1+500.0 or CENTRE.y < z0-500.0 or CENTRE.y > z1+500.0: return []
	return [[CENTRE,1.0,0.0,KEEP_HALF.x,KEEP_HALF.y]]

static func r_a() -> float:
	return R_B*tan(H_B)/tan(H_A)

## The bays: [origin (XZ from CENTRE, on the outer wall's line), outward, "a" or "b"].
static func bays() -> Array:
	var ra := r_a()
	var d := ra-R_B
	var c := Vector2(0.6*d,0.8*d)
	var out: Array = []
	for arc in 4:
		var end := arc%2 == 0
		var n := N_END if end else N_SIDE
		var h := H_B if end else H_A
		var r := R_B if end else ra
		var mid: Vector2 = [Vector2(c.x,0),Vector2(0,-c.y),Vector2(-c.x,0),Vector2(0,c.y)][arc]
		var a0: float = [-PHI,PHI,PI-PHI,PI+PHI][arc]
		for k in n:
			var a := a0+(k+0.5)*2.0*h
			var dir := Vector2(cos(a),sin(a))
			out.append([mid+dir*r,dir,"b" if end else "a"])
	return out

## How far inside the outer wall's line a point (XZ from CENTRE) lies.
static func depth(p: Vector2) -> float:
	var ra := r_a()
	var d := ra-R_B
	var c := Vector2(0.6*d,0.8*d)
	var q := p.abs()
	if (q.x-c.x)*c.y-q.y*c.x > 0.0: return R_B-q.distance_to(Vector2(c.x,0.0))
	return ra-q.distance_to(Vector2(0.0,-c.y))

static func _h(field: Object, x: float, z: float) -> float:
	return float(field.call("height",x,z))

static func _at(p: Vector2, y: float, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw),Vector3(p.x,y,p.y))

## A bay's frame: +x along the wall (toward the bay before), +z outward.
static func bay_xf(bay: Array, y: float) -> Transform3D:
	var o: Vector2 = CENTRE+(bay[0] as Vector2)
	var dir: Vector2 = bay[1]
	return _at(o,y,atan2(dir.x,dir.y))

## The floor's level: the highest ground under the walls' piers, less a little.
static func datum(field: Object) -> float:
	var top := -INF
	for bay: Array in bays():
		var xf := bay_xf(bay,0.0)
		for s: float in [0.0,20.0]:
			for x: float in [-9.0,9.0]:
				var w := xf*Vector3(x,0.0,-s)
				top = maxf(top,_h(field,w.x,w.z))
	return top-0.4

## Whether the arena's tile (i, j) is laid.
static func tile_laid(i: int, j: int) -> bool:
	if (i == 1 and j == 3) or (i == 4 and j == 1) or (i == 5 and j == 3) or (i == 0 and j == 2): return false
	return depth(Vector2((i-3)*B,(j-2)*B)) > SEATS_END+2.0

## The site: {y (the datum), bays: [[[id, world xf]]], loose: [[id, world xf]]}.
static func layout(field: Object) -> Dictionary:
	var y := datum(field)
	var all := bays()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4051
	var by_bay: Array = []
	var turned := Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO)
	var up := Transform3D(Basis(),Vector3(0.0,TIER,0.0))
	for i in N:
		var xf := bay_xf(all[i],y)
		var v: String = all[i][2]
		var mine: Array = []
		for tier in 3:
			var c: String = ([OUTER,UPPER,TOP][tier] as String)[i]
			var base := xf*Transform3D(Basis(),Vector3(0.0,[0.0,TIER,TOP_AT][tier],0.0))
			var id: StringName = &"arena_outer" if tier == 0 else &"arena_upper"
			var broken := StringName(String(id)+"_broken")
			if c == "F": mine.append([id,base])
			if c == "B" or c == "X": mine.append([broken,base])
			if c == "b" or c == "X": mine.append([broken,base*turned])
		if VAULT[i] == "V": mine.append([StringName("arena_vault_"+v),xf])
		elif VAULT[i] == "v": mine.append([StringName("arena_vault_broken_"+v),xf])
		if INNER[i] == "I": mine.append([StringName("arena_inner_"+v),xf])
		if SEATS[i] == "S": mine.append([StringName("arena_seats_"+v),xf])
		elif SEATS[i] == "s": mine.append([StringName("arena_seats_broken_"+v),xf])
		if INNER2[i] == "I": mine.append([StringName("arena_inner_"+v),xf*up])
		if VAULT2[i] == "V": mine.append([StringName("arena_vault_"+v),xf*up])
		for e: Array in FALLEN:
			if int(e[0]) != i: continue
			var w: Vector3 = xf*Vector3(float(e[1]),0.0,-float(e[2]))
			var at := Transform3D(Basis(Vector3.UP,PI if e[3] else 0.0),Vector3(float(e[1]),_h(field,w.x,w.z)-y-0.2,-float(e[2])))
			mine.append([&"arena_fallen",xf*at])
		by_bay.append(mine)
	var loose: Array = []
	for e: Array in HEAPS:
		var w: Vector3 = bay_xf(all[int(e[0])],0.0)*Vector3(float(e[1]),0.0,-float(e[2]))
		loose.append([&"aqueduct_rubble",_on_ground(field,Vector2(w.x,w.z),float(e[3]),6.0,0.5)])
	# ---- In the arena: two stumps, one's shaft lying out from it, drums.
	for e: Array in [[&"column_broken",Vector2(24.0,-9.25),0.3],[&"column_broken",Vector2(24.0,9.25),1.9],
			[&"agora_drum",Vector2(-6.0,-21.0),1.0],[&"agora_drum",Vector2(38.0,14.0),2.3],[&"agora_drum",Vector2(8.0,24.0),0.45]]:
		var p: Vector2 = CENTRE+(e[1] as Vector2)
		loose.append([e[0],_at(p,_h(field,p.x,p.y)-0.15,float(e[2]))])
	var fallen := CENTRE+Vector2(24.0,-9.25)
	loose.append([&"column_drums",_at(fallen,_h(field,fallen.x-15.0,fallen.y+3.0)-0.05,PI+0.2)])
	# ---- The paving, on the ground's own tilt, broken toward the breach.
	for i in PAVE_N.x:
		for j in PAVE_N.y:
			if not tile_laid(i,j): continue
			var broken := i <= 1 or rng.randf() < 0.3
			var q := 1 if i <= 1 else rng.randi_range(0,3)
			loose.append([&"agora_paving_broken" if broken else &"agora_paving",_tile(field,CENTRE+Vector2((i-3)*B,(j-2)*B),q)])
	return {"y":y,"bays":by_bay,"loose":loose}

## A heap's frame on the ground: sunk by the fall across its reach.
static func _on_ground(field: Object, p: Vector2, yaw: float, reach: float, sink: float) -> Transform3D:
	var mid := _h(field,p.x,p.y)
	var lo := mid
	for dx: float in [-1.0,1.0]:
		for dz: float in [-1.0,1.0]: lo = minf(lo,_h(field,p.x+dx*reach,p.y+dz*reach))
	return _at(p,mid-minf(mid-lo,2.0)*0.6-sink,yaw)

## A paving tile's frame (as agora_site.gd's): on the ground's plane, turned `q` quarters.
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

## The grass kept off the arena's paving (endless_grass.gd grow_cell), as
## agora_site.gd's: every node on a laid tile reads as a river's water.
static func grass_off(got: Dictionary, land_seed: int, x0: float, z0: float, n: int, pad: int) -> void:
	if land_seed != 1 or not wanted() or not got.has("river"): return
	var gx0 := x0-pad
	var gz0 := z0-pad
	var gx1 := gx0+n-1
	var gz1 := gz0+n-1
	var h := B*0.5
	var lo0 := CENTRE-Vector2(3*B+h,2*B+h)
	var hi0 := CENTRE+Vector2(3*B+h,2*B+h)
	if gx1 < lo0.x or gx0 > hi0.x or gz1 < lo0.y or gz0 > hi0.y: return
	var rs: PackedFloat32Array = got.river
	for i in PAVE_N.x:
		for j in PAVE_N.y:
			if not tile_laid(i,j): continue
			var c := CENTRE+Vector2((i-3)*B,(j-2)*B)
			var lo := c-Vector2(h,h)
			var hi := c+Vector2(h,h)
			if i <= 1: lo.x += 4.0
			var i0 := maxi(ceili(lo.x-gx0),0)
			var i1 := mini(floori(hi.x-gx0),n-1)
			var j0 := maxi(ceili(lo.y-gz0),0)
			var j1 := mini(floori(hi.y-gz0),n-1)
			for jj in range(j0,j1+1):
				for ii in range(i0,i1+1):
					var k := jj*n+ii
					rs[k] = minf(rs[k],-1.0)
	got.river = rs

func setup(g: Node3D) -> void:
	game = g
	var lay := layout(game.field)
	var y: float = lay.y
	var all := bays()
	var ngroup := ceili(float(N)/GROUP)
	# The drawn groups: GROUP bays each, then the arena's west and east halves.
	for k in ngroup+2:
		var c := Vector2.ZERO
		if k < ngroup:
			var n := 0
			for i in range(k*GROUP,mini(N,(k+1)*GROUP)):
				c += CENTRE+(all[i][0] as Vector2)
				n += 1
			c /= n
		else: c = CENTRE+Vector2(-30.0 if k == ngroup else 30.0,0.0)
		groups.append({"xf":_at(c,y),"pieces":[],"name":"Arena%d" % k})
	for i in N:
		var xf := bay_xf(all[i],y)
		var inv := xf.affine_inverse()
		var pieces: Array = []
		for e: Array in lay.bays[i]: pieces.append([e[0],inv*(e[1] as Transform3D)])
		parts.append({"xf":xf,"pieces":pieces,"name":"arena/%d" % i})
		var grp: Dictionary = groups[i/GROUP]
		var ginv := (grp.xf as Transform3D).affine_inverse()
		for e: Array in lay.bays[i]: (grp.pieces as Array).append([e[0],ginv*(e[1] as Transform3D)])
	var floor_xf := _at(CENTRE,y)
	var floor_inv := floor_xf.affine_inverse()
	var on_floor: Array = []
	for e: Array in lay.loose:
		var w: Transform3D = e[1]
		on_floor.append([e[0],floor_inv*w])
		# Drawn with the nearest bay's group, or the arena's half.
		var at := Vector2(w.origin.x,w.origin.z)
		var best := -1
		var bd := 45.0
		for i in N:
			var dd := at.distance_to(CENTRE+(all[i][0] as Vector2))
			if dd < bd:
				bd = dd
				best = i/GROUP
		if best < 0: best = ngroup if at.x < CENTRE.x else ngroup+1
		var grp: Dictionary = groups[best]
		(grp.pieces as Array).append([e[0],(grp.xf as Transform3D).affine_inverse()*w])
	parts.append({"xf":floor_xf,"pieces":on_floor,"name":"arena/floor"})
	for grp: Dictionary in groups:
		for e: Array in grp.pieces:
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

## One frame: the site streamed round the eye. `busy`: a temple-kit build is
## running elsewhere (one at a time). Returns whether this one is building.
func step(eye: Vector3, busy: bool, here: bool) -> bool:
	var d := Vector2(CENTRE.x-eye.x,CENTRE.y-eye.z).length() if here else INF
	match state:
		"away":
			if d < REACH and not busy:
				state = "building"
				task = WorkerThreadPool.add_task(_make,false,"Arena")
				return true
		"building":
			if not WorkerThreadPool.is_task_completed(task): return true
			WorkerThreadPool.wait_for_task_completion(task)
			task = -1
			todo = []
			for s: Dictionary in made.sets: todo.append(s)
			for s: Dictionary in made.solids: todo.append(s)
			made = {}
			state = "commit"
		"commit":
			# A few a frame: a group's MultiMeshes, or a bay's body and solid.
			for k in 3:
				if todo.is_empty(): break
				_commit(todo.pop_front())
			if todo.is_empty(): state = "up"
		"up":
			if d > FREE: _free()
	return false

## On a worker: each group's sets (a piece's frames, box and LOD ranges) and
## each part's boxes and solid. No resource is made here (agora_site.gd).
func _make() -> void:
	var sets: Array = []
	for grp: Dictionary in groups:
		var by_id := {}
		for e: Array in grp.pieces:
			if not by_id.has(e[0]): by_id[e[0]] = []
			(by_id[e[0]] as Array).append(e[1])
		var rows: Array = []
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
			rows.append({"id":id,"xfs":xfs,"box":set_box,"ranges":[Vector2(0.0,mid_at),Vector2(mid_at,far_at),Vector2(far_at,0.0)]})
		sets.append({"group":grp,"rows":rows})
	var solids: Array = []
	for part: Dictionary in parts:
		var boxes: Array = []
		var reach := 0.0
		for e: Array in part.pieces:
			var xf: Transform3D = e[1]
			for box: AABB in TempleKit.boxes(e[0]):
				var b: AABB = xf*box
				boxes.append(b)
				for corner in [Vector2(b.position.x,b.position.z),Vector2(b.end.x,b.end.z),
						Vector2(b.position.x,b.end.z),Vector2(b.end.x,b.position.z)]:
					reach = maxf(reach,(corner as Vector2).length())
		if boxes.is_empty(): continue
		solids.append({"part":part,"boxes":boxes,"reach":reach,"solid":BoxSolid.build(boxes)})
	made = {"sets":sets,"solids":solids}

## On the main thread: a group's MultiMeshes, or a part's body and solid.
func _commit(s: Dictionary) -> void:
	var root := Node3D.new()
	if s.has("group"):
		var grp: Dictionary = s.group
		root.name = str(grp.name)
		for r: Dictionary in s.rows:
			var id: StringName = r.id
			var xfs: Array = r.xfs
			for level in 3:
				var m: Mesh = TempleKit.lod(id,level)
				if m == null: continue
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = m
				mm.instance_count = xfs.size()
				for i in range(xfs.size()): mm.set_instance_transform(i,xfs[i])
				mm.custom_aabb = r.box
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.name = String(id)+(["","_mid","_far"][level] as String)
				mmi.visibility_range_begin = (r.ranges[level] as Vector2).x
				mmi.visibility_range_end = (r.ranges[level] as Vector2).y
				root.add_child(mmi)
		root.transform = grp.xf
		add_child(root)
		nodes.append(root)
		return
	var part: Dictionary = s.part
	var xf: Transform3D = part.xf
	root.name = str(part.name).replace("/","_")
	root.transform = xf
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = game.arches.LAYER
	body.collision_mask = 0
	for box: AABB in s.boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	root.add_child(body)
	add_child(root)
	nodes.append(root)
	var yaw := xf.basis.get_euler().y
	var record := {"name":part.name,"kind":"way","node":root,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
		"solid":s.solid,"reach":float(s.reach)+BoxSolid.grow_most()+10.0,"spec":{},"no_break":true}
	records.append(record)
	game.arches.loose.append(record)
	GroundNative.bump_loose()

func _free() -> void:
	for r: Dictionary in records: game.arches.loose.erase(r)
	if not records.is_empty(): GroundNative.bump_loose()
	records.clear()
	for n: Node in nodes:
		if is_instance_valid(n): n.queue_free()
	nodes.clear()
	todo.clear()
	state = "away"

func _exit_tree() -> void:
	if task >= 0: WorkerThreadPool.wait_for_task_completion(task)
	task = -1
	made = {}
