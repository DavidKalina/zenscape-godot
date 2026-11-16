extends RefCounted
## The temple-kit ruins at the way towers' handles
## (docs/design/temple-kit/spec-temple-kit.md, trunk: Site), built from the
## temple kit (scripts/temple_kit.gd) in the old belfries' places.
## way_towers.gd streams them in and out under the same handles;
## `--temple=0` puts the belfries back.
##
## Every site's frame: origin on the platform's foot at its middle, x along the
## long side, +z the front. A platform (`_platform`) is the kit's podium bays
## round the edge (corners turn k quarter turns: 0 front right, 1 back right,
## 2 back left, 3 front left), the stair in the front middle, and three rows of
## podium_floor bays inside (paved, no steps).
##
## - `way/isle`, the temple: four bays by two. Standing: the front colonnade
##   with two lintels, an inner porch row with a lintel and the broken lintel,
##   a run down the left side with a lintel, two lone corner columns. Fallen:
##   the front right corner (its drums down the right side) and one back
##   column (its drums along the back), a stump beside it. The inner wall with
##   its doorway stands behind the porch. The line through the front's left
##   middle gap, the broken bay and the doorway is straight (x = -BAY/2).
## - `way/bay`, the colonnade: six bays by two, its front looking back up the
##   bay. The front row stands under a run of lintels, the last one broken; its
##   second column from the right is down across the floor. The back row is
##   stumps; the left end is closed, three columns under two lintels. Lines:
##   in under a front lintel and out over the stumps, or down its length
##   between the rows.
## - `way/south`, the shrine: two bays by two, its front to the bay ruin. A lone
##   doorway stands in the middle; three columns under two lintels down the
##   left, two columns and a broken lintel down the right, the back right corner
##   down along the back. The line runs straight in through the front, the
##   doorway and out the back (x = 0).
## Every id is one MultiMesh per LOD (near, mid when the kit has one, far),
## swapped whole (MID_NEAREST, FAR_NEAREST).

const TempleKit = preload("res://scripts/temple_kit.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The sites: where each stands (world XZ) and its turn, the footprint sampled
## for the platform's foot (half x, half z, m) and the trees' keep-out (half
## across x, half along z, m). The isle: the island's highest ground the
## footprint fits, long side along the island's ridge, front to the bay. The
## bay and the south: the old towers' feet (4-6 m of rise under the footprint
## at any turn), `high`: seated near the footprint's highest ground (FOOT_TOP)
## so no grass comes up through the floor.
const SITES := {
	"way/isle":{"at":Vector2(930.0,2690.0),"yaw":PI,"foot":Vector2(44.0,25.0),"clear":Vector2(50.0,32.0)},
	"way/bay":{"at":Vector2(130.0,1540.0),"yaw":PI,"foot":Vector2(62.0,25.0),"clear":Vector2(68.0,32.0),"high":true},
	"way/south":{"at":Vector2(-600.0,2480.0),"yaw":2.48,"foot":Vector2(25.0,25.0),"clear":Vector2(32.0,32.0),"high":true},
}
## Where the site's sets swap LODs, as the least distance (m) from the camera
## to any of the set's pieces. Each set is one MultiMesh and Godot swaps it
## whole by the camera's distance to its box centre, so a set's ranges are
## these plus its radius (the farthest piece corner from that centre): a mid
## or far model is never drawn closer than this. Mids (the trim lanes' stills)
## read the same as near from 50 m out. The far models popped at the kit's
## 170 m (smooth darker tubes for columns, captures/shots/swap_before_*), so
## the far swap stays where the last iteration's 320 m to the centre put the
## columns' nearest piece.
const MID_NEAREST := 50.0
const FAR_NEAREST := 280.0
## A `high` site's foot: this far (m) under the footprint's highest ground, but
## never more than FOOT_REACH over its lowest (the footings reach 6.5 m down).
const FOOT_TOP := 0.5
const FOOT_REACH := 6.0

const B := TempleKit.BAY
const S := TempleKit.PODIUM_H

## Whether a handle has a ruin.
static func has(handle: String) -> bool:
	return SITES.has(handle)

## [id, local position, quarter turns about y] for a site.
static func layout(handle: String) -> Array:
	match handle:
		"way/bay": return _colonnade()
		"way/south": return _shrine()
	return _temple()

## A platform `w` bays long (even) by two deep.
static func _platform(w: int) -> Array:
	var out: Array = []
	var h := w*0.5*B
	out.append([&"podium_corner",Vector3(h,0,B),0])
	out.append([&"podium_corner",Vector3(h,0,-B),1])
	out.append([&"podium_corner",Vector3(-h,0,-B),2])
	out.append([&"podium_corner",Vector3(-h,0,B),3])
	for k in range(1,w):
		var x := -h+k*B
		out.append([&"podium_stair" if is_zero_approx(x) else &"podium",Vector3(x,0,B),0])
	for k in range(1,w): out.append([&"podium",Vector3(-h+k*B,0,-B),2])
	out.append([&"podium",Vector3(h,0,0),1])
	out.append([&"podium",Vector3(-h,0,0),3])
	# The floor: rows of paved bays (podium_floor: a podium bay with no steps,
	# same origin and top) facing front, the last a hair low under the back row.
	for row: Vector2 in [Vector2(9.5,0.0),Vector2(0.5,0.0),Vector2(-8.5,-0.05)]:
		for k in range(1,w): out.append([&"podium_floor",Vector3(-h+k*B,row.y,row.x),0])
	# The strips between the rows' ends and the side bays (3.25 m, grass showed
	# through): a bay turned along each side, a hair low under the edge.
	for z in [0.5*B,-0.5*B]:
		out.append([&"podium_floor",Vector3(h-9.0,-0.05,z),1])
		out.append([&"podium_floor",Vector3(-h+9.0,-0.05,z),3])
	return out

## The temple on the isle.
static func _temple() -> Array:
	var out := _platform(4)
	# Standing columns.
	for p: Vector2 in [Vector2(-2*B,B),Vector2(-B,B),Vector2(0,B),Vector2(B,B),
			Vector2(-B,0.5),Vector2(0,0.5),Vector2(B,0.5),
			Vector2(-2*B,0),Vector2(-2*B,-B),Vector2(2*B,-B)]:
		out.append([&"column",Vector3(p.x,S,p.y),0])
	# Lintels: two on the front, one on the porch, one down the left side.
	out.append([&"lintel",Vector3(-1.5*B,S,B),0])
	out.append([&"lintel",Vector3(-0.5*B,S,B),0])
	out.append([&"lintel",Vector3(0.5*B,S,0.5),0])
	out.append([&"lintel",Vector3(-2*B,S,-0.5*B),1])
	# The broken porch bay: stub on the column at x 0, leaning on x -B.
	out.append([&"lintel_broken",Vector3(-0.5*B,S,0.5),2])
	# Fallen: the front right corner down the right side, a back column along the back.
	out.append([&"column_broken",Vector3(2*B,S,B),1])
	out.append([&"column_drums",Vector3(2*B-1.0,S,B),1])
	out.append([&"column_broken",Vector3(-B,S,-B),0])
	out.append([&"column_drums",Vector3(-B,S,-B),0])
	out.append([&"column_broken",Vector3(B,S,-B),2])
	# The inner wall, its doorway on the line x = -B/2.
	out.append([&"wall_door",Vector3(-0.5*B,S,-12.0),0])
	out.append([&"wall_broken",Vector3(0.5*B,S,-12.0),0])
	out.append([&"wall_broken",Vector3(-1.5*B,S,-12.0),2])
	return out

## The colonnade at the bay's end.
static func _colonnade() -> Array:
	var out := _platform(6)
	# The front row: all standing but the second from the right, down inward.
	for x in [-3*B,-2*B,-B,0.0,B,3*B]: out.append([&"column",Vector3(x,S,B),0])
	out.append([&"column_broken",Vector3(2*B,S,B),1])
	out.append([&"column_drums",Vector3(2*B-1.0,S,B),1])
	for x in [-2.5*B,-1.5*B,-0.5*B]: out.append([&"lintel",Vector3(x,S,B),0])
	# The last of the run: its stub on the column at x 0, leaning on x B.
	out.append([&"lintel_broken",Vector3(0.5*B,S,B),0])
	# The left end closed: three columns under two lintels.
	out.append([&"column",Vector3(-3*B,S,0),0])
	out.append([&"column",Vector3(-3*B,S,-B),0])
	out.append([&"lintel",Vector3(-3*B,S,0.5*B),1])
	out.append([&"lintel",Vector3(-3*B,S,-0.5*B),1])
	# The back row: stumps, one down along the back.
	out.append([&"column_broken",Vector3(-B,S,-B),0])
	out.append([&"column_drums",Vector3(-B,S,-B),0])
	out.append([&"column_broken",Vector3(B,S,-B),2])
	out.append([&"column_broken",Vector3(3*B,S,-B),3])
	return out

## The shrine on the way south.
static func _shrine() -> Array:
	var out := _platform(2)
	# The lone doorway in the middle, on the line x = 0.
	out.append([&"wall_door",Vector3(0,S,0),0])
	# Down the left: three columns under two lintels.
	for z in [B,0.0,-B]: out.append([&"column",Vector3(-B,S,z),0])
	out.append([&"lintel",Vector3(-B,S,0.5*B),1])
	out.append([&"lintel",Vector3(-B,S,-0.5*B),1])
	# Down the right: two columns, the broken lintel's stub on the middle one.
	out.append([&"column",Vector3(B,S,B),0])
	out.append([&"column",Vector3(B,S,0),0])
	out.append([&"lintel_broken",Vector3(B,S,0.5*B),3])
	# The back right corner, down along the back.
	out.append([&"column_broken",Vector3(B,S,-B),2])
	out.append([&"column_drums",Vector3(B,S,-B),2])
	return out

static func wanted() -> bool:
	return not ("--temple=0" in LaunchArgs.user_args())

## The platform's foot: the median ground over the footprint (the footings
## reach 6 m down, so the low side is covered and the high side buries steps),
## or for a `high` site its highest ground less FOOT_TOP (FOOT_REACH over the
## lowest at most).
static func foot_y(field: Object, handle: String) -> float:
	var site: Dictionary = SITES[handle]
	var at: Vector2 = site.at
	var half: Vector2 = site.foot
	var hs: Array[float] = []
	var c := cos(float(site.yaw))
	var s := sin(float(site.yaw))
	for i in range(-4,5):
		for j in range(-3,4):
			var lx := half.x*i/4.0
			var lz := half.y*j/3.0
			var wx := at.x+lx*c+lz*s
			var wz := at.y-lx*s+lz*c
			hs.append(float(field.call("height",wx,wz)))
	hs.sort()
	if site.get("high",false): return minf(hs[-1]-FOOT_TOP,hs[0]+FOOT_REACH)
	return hs[hs.size()/2]

## The site's frame on the land (world).
static func xform(field: Object, handle: String) -> Transform3D:
	var site: Dictionary = SITES[handle]
	var at: Vector2 = site.at
	return Transform3D(Basis(Vector3.UP,float(site.yaw)),Vector3(at.x,foot_y(field,handle),at.y))

## The trees' keep-out entry (TreePlan `_by_arch`).
static func keepout(handle: String) -> Array:
	var site: Dictionary = SITES[handle]
	var clear: Vector2 = site.clear
	return [site.at,cos(float(site.yaw)),sin(float(site.yaw)),clear.x,clear.y]

## Built off the tree (a worker may call it): {node, boxes (its solids in the
## site's frame), reach (m from the origin in XZ)}.
static func build(handle: String) -> Dictionary:
	var root := Node3D.new()
	root.name = "Temple"
	var by_id := {}
	var boxes: Array = []
	var reach := 0.0
	for e: Array in layout(handle):
		var id: StringName = e[0]
		var xf := Transform3D(Basis(Vector3.UP,PI*0.5*int(e[2])),e[1])
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
		var meshes: Array = [TempleKit.lod(id,TempleKit.NEAR),TempleKit.lod(id,TempleKit.MID),
				TempleKit.lod(id,TempleKit.FAR)]
		# One box for all three LODs, so the three swap at the same distance.
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
			if meshes[level] == null: continue
			# Made into a MultiMesh on the main thread (TempleKit.fill).
			sets.append([meshes[level],xfs,set_box,String(id)+(["","_mid","_far"][level] as String),ranges[level]])
	# On a worker the sets are left for the main thread (way_towers.gd _commit).
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		TempleKit.fill(root,sets)
		sets = []
	return {"node":root,"boxes":boxes,"reach":reach,"sets":sets}
