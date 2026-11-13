extends RefCounted
## The temple ruin on the wooded island at `way/isle`
## (docs/design/temple-kit/spec-temple-kit.md, trunk: Site), built from the
## temple kit (scripts/temple_kit.gd) in the belfry's place. way_towers.gd
## streams it in and out under the same handle; `--temple=0` puts the belfry
## back.
##
## The frame: origin on the platform's foot at its middle, x along the long
## side (four bays), +z the front (two bays deep). The platform is the kit's
## podium bays round the edge and three rows of bays inside for the floor
## (podium_floor bays, paved with no steps). Standing: the front
## colonnade with two lintels, an inner porch row with a lintel and the broken
## lintel, a run down the left side with a lintel, two lone corner columns.
## Fallen: the front right corner (its drums down the right side) and one back
## column (its drums along the back), a stump beside it. The inner wall with
## its doorway stands behind the porch. The line through the front's left
## middle gap, the broken bay and the doorway is straight (x = -BAY/2).
## Every id is one MultiMesh per LOD (near, mid when the kit has one, far),
## swapped whole (MID_NEAREST, FAR_NEAREST).

const TempleKit = preload("res://scripts/temple_kit.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## Where it stands (world XZ) and its turn: the island's highest ground the
## footprint fits, long side along the island's ridge, front to the bay.
const AT := Vector2(930.0,2690.0)
const YAW := PI
## The trees' keep-out, half across (x) and half along (z), m.
const CLEAR := Vector2(50.0,32.0)
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
## The footprint sampled for the platform's foot (half x, half z, m).
const FOOT_HALF := Vector2(44.0,25.0)

const B := TempleKit.BAY
const S := TempleKit.PODIUM_H

## [id, local position, quarter turns about y].
static func layout() -> Array:
	var out: Array = []
	# The platform's edge: corners turn k quarter turns (TempleKit podium notes).
	out.append([&"podium_corner",Vector3(2*B,0,B),0])
	out.append([&"podium_corner",Vector3(2*B,0,-B),1])
	out.append([&"podium_corner",Vector3(-2*B,0,-B),2])
	out.append([&"podium_corner",Vector3(-2*B,0,B),3])
	out.append([&"podium",Vector3(-B,0,B),0])
	out.append([&"podium_stair",Vector3(0,0,B),0])
	out.append([&"podium",Vector3(B,0,B),0])
	for x in [-B,0.0,B]: out.append([&"podium",Vector3(x,0,-B),2])
	out.append([&"podium",Vector3(2*B,0,0),1])
	out.append([&"podium",Vector3(-2*B,0,0),3])
	# The floor: rows of paved bays (podium_floor: a podium bay with no steps,
	# same origin and top) facing front, the last a hair low under the back row.
	for row: Vector2 in [Vector2(9.5,0.0),Vector2(0.5,0.0),Vector2(-8.5,-0.05)]:
		for x in [-B,0.0,B]: out.append([&"podium_floor",Vector3(x,row.y,row.x),0])
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

static func wanted() -> bool:
	return not ("--temple=0" in LaunchArgs.user_args())

## The platform's foot: the median ground over the footprint (the footings
## reach 6 m down, so the low side is covered and the high side buries steps).
static func foot_y(field: Object) -> float:
	var hs: Array[float] = []
	var c := cos(YAW)
	var s := sin(YAW)
	for i in range(-4,5):
		for j in range(-3,4):
			var lx := FOOT_HALF.x*i/4.0
			var lz := FOOT_HALF.y*j/3.0
			var wx := AT.x+lx*c+lz*s
			var wz := AT.y-lx*s+lz*c
			hs.append(float(field.call("height",wx,wz)))
	hs.sort()
	return hs[hs.size()/2]

## The trees' keep-out entry (TreePlan `_by_arch`).
static func keepout() -> Array:
	return [AT,cos(YAW),sin(YAW),CLEAR.x,CLEAR.y]

## Built off the tree (a worker may call it): {node, boxes (its solids in the
## site's frame), reach (m from the origin in XZ)}.
static func build() -> Dictionary:
	var root := Node3D.new()
	root.name = "Temple"
	var by_id := {}
	var boxes: Array = []
	var reach := 0.0
	for e: Array in layout():
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
	return {"node":root,"boxes":boxes,"reach":reach}
