extends RefCounted
## The Sundered line's pieces as the game's own Sundered hall (docs/design/
## isle-hall-line.md, round 2): what `--motif=sundered` stands in the
## default scene, built the same way, one whole piece at a time, to rise
## out of the cloud sea as one unit (scripts/hall_line.gd, scripts/
## hall_rise.gd).
##
## A line piece (scripts/hall_line_plan.gd) is turned into a Sundered piece
## record (`hall_piece`: one straight stretch, both ends torn, the same bay
## plans the greybox drew) with its island laid as Sundered lays one
## (`Sundered._islands`: long along the nave, 21-24 m half across, the torn
## ends overhanging its tips). Then, on a worker (`build`), the Sundered
## build itself:
##   the island   SunderedBuild `_isle`: a long ridge island authored as
##                the game's islets are (SkyIslet `author`), its bed
##                levelled under the hall, cleared of what grows there; its
##                arrays and meshes as SkyIslets `dress` gives them (the
##                isle's ground palette, trees, flowers, rock look);
##   near         SunderedBuild `near`: the ruin kit's bays at in-world
##                detail in the eroded basalt stone (the ruin stone's
##                default), the podium, the torn ends, all dressed in the
##                swaying overgrowth (scripts/sundered_growth.gd, shaders/
##                ruin_growth.gdshader, pushed by the plane: scripts/
##                ruin_growth_push.gd); one merged mesh, its hulls in body
##                chunks of SunderedBuild.CHUNK, held out of the tree;
##   far          SunderedBuild `far`: the same hall as one cheap mesh,
##                shown past NEAR_SHOW (the default scene's own streaming,
##                with nothing let go: a piece is kept whole till it sinks);
##   collision    the island's ground and rock as trimesh bodies, the
##                hall's hulls as built, all on the ruins' layer once still.
## The chunk is one node at its pivot (`node`), the island stood into it on
## the main thread (`stand_island`, SkyIslets `stand`), its bodies stood
## one a frame once it is still (HallRise `bodies`).
##
## Frames. Sundered's hall frame (the nave along +X, +Z its right) sits in
## a line piece's frame (the nave along -Z, +X its right) turned a quarter
## about up (HALL); its origin is the piece's origin (the first bay's start
## on the nave's middle at the floor).

const Sundered = preload("res://scripts/sundered_hall.gd")
const SunderedBuild = preload("res://scripts/sundered_build.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const HallPath = Hall.HallPath
const SkyIslets = preload("res://scripts/sky_islets.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")

## Sundered's hall frame in a line piece's frame.
const HALL := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3.ZERO)
## Near detail shown within this of the eye (m, to the nearest point of
## the piece's nave), the far mesh past it: Sundered's own.
const NEAR_SHOW := SunderedBuild.NEAR_SHOW
## Rim points round the island (where the cloud breaks), and the tiles (m)
## its ground's boxes are cut in (the plane's clear check, HallRise
## `plane_touches`).
const RIM_POINTS := 72
const TILE := 6.0
## The bodies a piece's collision comes in (each stood in a frame of its
## own): at most BODY_HULLS of the hall's hulls (Sundered's own chunks
## are SunderedBuild.CHUNK, 120: some 1.5 ms each to stand), at most
## BODY_FACES of the island's triangles.
const BODY_HULLS := 40
const BODY_FACES := 1500

## A line piece as a Sundered piece record (SunderedBuild's `near`, `far`
## and `_isle` take it): one straight stretch of its bays, both ends torn,
## its bay plans the Sundered planner's for its act (the greybox's own,
## from the same stream), its hall frame the identity, its floor at 0; and
## its island laid as Sundered `_islands` lays one.
static func hall_piece(piece: Dictionary) -> Dictionary:
	var bays := int(piece.bays)
	var layout := [{"bays":bays,"turn":0.0}]
	var path := HallPath.make(layout,Hall.BAY)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(piece.seed)
	var hp := {"index":int(piece.index),"act":str(piece.act),"bays":bays,"layout":layout,"path":path,"length":path.length,
		"frame":Transform3D.IDENTITY,"floor":0.0,"theta":0.0,"first":false,"last":false,"seed":int(piece.seed)}
	hp.plans = Sundered._plans(hp,rng)
	# The island (Sundered `_islands`, straight: its axis the nave's).
	var isle_rng := RandomNumberGenerator.new()
	isle_rng.seed = int(piece.seed)+23
	var length: float = path.length
	var back := isle_rng.randf_range(Sundered.OVERHANG.x,Sundered.OVERHANG.y)
	var front := isle_rng.randf_range(Sundered.OVERHANG.x,Sundered.OVERHANG.y)
	var lo := -length*0.5+back
	var hi := length*0.5-front
	var middle := Vector3(length*0.5+(lo+hi)*0.5,0.0,0.0)
	hp.island = {"name":"piece%d" % int(piece.index),"half":Vector2((hi-lo)*0.5,isle_rng.randf_range(Sundered.ISLE_HALF.x,Sundered.ISLE_HALF.y)),
		"axis_yaw":0.0,"middle":middle,"at":middle,"yaw":0.0,"seed":hash([int(piece.seed),"line isle"]) & 0xffffff}
	return hp

## A piece built whole (on a worker; `palette` the islets' ground palette,
## SkyIslets `prepare_authored`, which must have run on the main thread):
## {node (the chunk's root, at its pivot, out of the tree), bodies (its
## StaticBody3Ds, no layer, out of the tree), island (SkyIslets `dress`'s
## out, stood by `stand_island`), island_at (the island's frame in the
## chunk's), pivot, lo, hi, boxes, rim (the rise's frame: the piece's),
## samples (points down its nave, the rise's frame: the near/far swap),
## usec, near_usec, island_usec, hulls, triangles}.
static func build(piece: Dictionary, palette: Dictionary) -> Dictionary:
	var began := Time.get_ticks_usec()
	var hp := hall_piece(piece)
	var member: Dictionary = SunderedBuild._isle({},hp)
	var shape: RefCounted = member.shape
	# The island's frame in the piece's (its node's place, as SkyClusters
	# stands a member: at its offset, turned by its yaw).
	var island_frame := HALL*Transform3D(Basis(Vector3.UP,float(member.yaw)),member.offset)
	var home_y := float((piece.origin as Vector3).y)+island_frame.origin.y
	var dressed := SkyIslets.dress(shape,palette,home_y)
	var island_usec := Time.get_ticks_usec()-began
	var near_began := Time.get_ticks_usec()
	var near: Node3D = SunderedBuild.near(hp)
	var far_mesh: ArrayMesh = SunderedBuild.far(hp)
	var near_usec := Time.get_ticks_usec()-near_began
	var bodies := _regroup(near.get_meta("bodies",[]))
	near.remove_meta("bodies")
	# The extent, the boxes: every hull's, and the island's ground and rock
	# cut in tiles.
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var boxes: Array = []
	var hulls := 0
	for body: StaticBody3D in bodies:
		for holder in body.get_children():
			var hull := (holder as CollisionShape3D).shape as ConvexPolygonShape3D
			if hull == null: continue
			var box := _box_of(hull.points,HALL)
			boxes.append(box)
			lo = lo.min(box.position)
			hi = hi.max(box.end)
			hulls += 1
	var island_faces: Array[PackedVector3Array] = []
	for part: String in ["top","sides"]:
		var faces := _faces(dressed[part],-SkyIslets.OFF_MAP if part == "top" else Vector3.ZERO)
		var placed := PackedVector3Array()
		placed.resize(faces.size())
		for i in range(faces.size()): placed[i] = island_frame*faces[i]
		island_faces.append(placed)
		for box: AABB in _tiles(placed):
			boxes.append(box)
			lo = lo.min(box.position)
			hi = hi.max(box.end)
	var pivot := (lo+hi)*0.5
	var root := Node3D.new()
	root.name = "piece"
	root.position = pivot
	var at := Transform3D(Basis.IDENTITY,-pivot)
	near.transform = at*HALL
	near.name = "Near"
	root.add_child(near)
	var far := MeshInstance3D.new()
	far.name = "Far"
	far.mesh = far_mesh
	far.transform = at*HALL
	far.visible = false
	root.add_child(far)
	# The island's collision: its ground and its rock as trimeshes, cut
	# into bodies of at most BODY_FACES triangles, tile by tile.
	var faces_all := PackedVector3Array()
	for faces: PackedVector3Array in island_faces: faces_all.append_array(faces)
	for part: PackedVector3Array in _cut(faces_all):
		var moved := PackedVector3Array()
		moved.resize(part.size())
		for i in range(part.size()): moved[i] = part[i]-pivot
		var shape_k := ConcavePolygonShape3D.new()
		shape_k.set_faces(moved)
		var holder := CollisionShape3D.new()
		holder.shape = shape_k
		var body := StaticBody3D.new()
		body.name = "Island%d" % bodies.size()
		body.collision_layer = 0
		body.collision_mask = 0
		body.add_child(holder)
		bodies.append(body)
	# The hall's hull chunks stand in the near node's frame.
	for body: StaticBody3D in bodies:
		if body.name.begins_with("Hall"): body.transform = at*HALL
		body.collision_layer = 0
	# Where the cloud breaks: round the island's rim at the top.
	var rim := PackedVector3Array()
	for k in range(RIM_POINTS):
		var p: Vector2 = shape.rim_point(TAU*k/RIM_POINTS)
		rim.append(island_frame*Vector3(p.x,0.0,p.y))
	var samples: Array[Vector3] = []
	var s := 0.0
	while s <= float(hp.length)+0.1:
		samples.append(HALL*Vector3(s,0.0,0.0))
		s += Hall.BAY*2.0
	var tris := 0
	var merged := near.get_node_or_null(^"Mesh") as MeshInstance3D
	if merged != null and merged.mesh != null:
		for k in range(merged.mesh.get_surface_count()): tris += merged.mesh.surface_get_array_len(k)/3
	return {"node":root,"bodies":bodies,"island":dressed,"island_at":at*island_frame,"pivot":pivot,"lo":lo,"hi":hi,"boxes":boxes,"rim":rim,
		"samples":samples,"usec":Time.get_ticks_usec()-began,"near_usec":near_usec,"island_usec":island_usec,"hulls":hulls,"triangles":tris,"hall":hp}

## A built piece as the hall rise's plan (scripts/hall_rise_plan.gd's
## shape): one chunk, the built root its `node` (HallRise takes it as
## made), its bodies to stand once still. Not timed (HallRise `setup`
## times it, RisePlan.remake).
static func template(piece: Dictionary, made: Dictionary) -> Dictionary:
	var lo: Vector3 = made.lo
	var hi: Vector3 = made.hi
	var chunk := {"id":"piece","title":"the %s, %d bays" % [piece.act,int(piece.bays)],"bays":[0,int(piece.bays)-1],"solids":[],"extra":[],
		"lo":lo,"hi":hi,"pivot":made.pivot,"boxes":made.boxes,"top":hi.y-(lo.y+hi.y)*0.5,"rim":made.rim,"node":made.node,"bodies":made.bodies}
	return {"solids":[],"chunks":[chunk],"length":0.0,"sea":-100.0,"real":true}

## Stands a built piece's island into its node (main thread): SkyIslets
## `stand` under the chunk's root, at its frame there. `islets` is the
## islets' host (its materials, catalog and plants).
static func stand_island(islets: Node3D, made: Dictionary, root: Node3D) -> Node3D:
	var at: Transform3D = made.island_at
	var b: Dictionary = islets.stand("Island",at.origin,made.island,root)
	var node: Node3D = b.node
	node.basis = at.basis
	return node

## Frees what a built piece holds that is in no tree (a piece never stood:
## the line reset, or let go).
static func release(made: Dictionary) -> void:
	for body: Node in made.get("bodies",[]):
		if is_instance_valid(body) and not body.is_inside_tree(): body.free()
	var node: Variant = made.get("node")
	if node != null and is_instance_valid(node) and not (node as Node).is_inside_tree(): (node as Node).free()

## The near build's hull bodies (SunderedBuild CHUNK hulls each) cut into
## bodies of BODY_HULLS (the old ones freed).
static func _regroup(given: Array) -> Array:
	var holders: Array = []
	for body: StaticBody3D in given:
		for holder in body.get_children():
			body.remove_child(holder)
			holders.append(holder)
		body.free()
	var out: Array = []
	for k in range(0,holders.size(),BODY_HULLS):
		var body := StaticBody3D.new()
		body.name = "Hall%d" % out.size()
		body.collision_layer = 0
		body.collision_mask = 0
		for j in range(k,mini(k+BODY_HULLS,holders.size())): body.add_child(holders[j])
		out.append(body)
	return out

## Triangles cut into parts of at most BODY_FACES, tile by tile (TILE
## squares across, by each triangle's middle), so each part is compact.
static func _cut(faces: PackedVector3Array) -> Array:
	var tiles := {}
	for i in range(0,faces.size()-2,3):
		var m := (faces[i]+faces[i+1]+faces[i+2])/3.0
		var key := Vector2i(floori(m.x/(TILE*3.0)),floori(m.z/(TILE*3.0)))
		if not tiles.has(key): tiles[key] = PackedVector3Array()
		var t: PackedVector3Array = tiles[key]
		t.append(faces[i])
		t.append(faces[i+1])
		t.append(faces[i+2])
		tiles[key] = t
	var keys := tiles.keys()
	keys.sort()
	var out: Array = []
	var part := PackedVector3Array()
	for key: Vector2i in keys:
		var t: PackedVector3Array = tiles[key]
		if not part.is_empty() and (part.size()+t.size())/3 > BODY_FACES:
			out.append(part)
			part = PackedVector3Array()
		part.append_array(t)
	if not part.is_empty(): out.append(part)
	return out

## A shape's points' box once moved by `xf`.
static func _box_of(points: PackedVector3Array, xf: Transform3D) -> AABB:
	var a := Vector3.INF
	var b := -Vector3.INF
	for p in points:
		var q := xf*p
		a = a.min(q)
		b = b.max(q)
	return AABB(a,b-a)

## An array mesh's triangles (its arrays, indexed or not), each point
## moved by `shift`.
static func _faces(arrays: Array, shift: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if arrays.is_empty(): return out
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: Variant = arrays[Mesh.ARRAY_INDEX]
	if index is PackedInt32Array and not (index as PackedInt32Array).is_empty():
		for i: int in index: out.append(v[i]+shift)
	else:
		for p in v: out.append(p+shift)
	return out

## Triangles' boxes, gathered in TILE squares (by each triangle's middle).
static func _tiles(faces: PackedVector3Array) -> Array:
	var tiles := {}
	for i in range(0,faces.size()-2,3):
		var a := faces[i]
		var b := faces[i+1]
		var c := faces[i+2]
		var m := (a+b+c)/3.0
		var key := Vector3i(floori(m.x/TILE),floori(m.y/TILE),floori(m.z/TILE))
		var box: AABB = AABB(a,Vector3.ZERO).expand(b).expand(c)
		tiles[key] = (tiles[key] as AABB).merge(box) if tiles.has(key) else box
	return tiles.values()
