extends RefCounted
## The cabin (docs/scenic/cabin.md): a small one-room log cabin with a shake
## roof and a stacked-stone chimney, set from the case. Its model is the
## sky-island branch's settler cabin (art/blender/cabin_build.py,
## assets/models/cabin.glb), drawn here at UNIT of its real size and baked
## into one vertex-coloured mesh, so GardenView draws every cabin in one batch
## on the stones' material (flat faces, the scene palette), as the stone lamp
## and the campfire are. A ring of faceted footing stones under the walls is
## added here, so it can sit on gently sloping ground without a gap.
##
## The windows' warm glow, their light and the chimney's thin smoke are not
## here but in scripts/cabin_lights.gd.
##
## Also where a cabin may stand (`refusal`) and which way it faces (`facing`):
## the hand asks both before it sets one down.

const MODEL := "res://assets/models/cabin.glb"
## The model is real size (a 2.6 x 3.2 m cabin, ridge 3.35 m); drawn at this.
const UNIT := 0.8
## The window pane's surface in the model; by day it is drawn this dark
## glass, and scripts/cabin_lights.gd lays a warm pane over it at night.
const GLOW_SURFACE := "glow"
const GLASS := Color("4a4038")
## The footing: faceted stones under the walls, from FOOTING_DEPTH m below
## the ground up to just under the sill, so a downhill corner never floats.
const FOOTING_DEPTH := 0.4
const FOOTING_TONES := [Color("7f776e"),Color("6a635b"),Color("8a8279")]

## Where it may not stand. Every SAMPLE m over its footprint (and the door's
## apron, APRON m before it): on the plate, dry, and the ground no more than
## SPREAD m from its highest to its lowest point (the footing hides that
## much). A tree's foot keeps TREE_CLEAR m times its scale (at least TREE_MIN
## m) from the footprint, so no roof is set into a crown; another cabin keeps
## CLEAR m; any other standing thing (LOW plants aside) keeps ROOM m.
const SAMPLE := 0.45
const APRON := 0.7
const SPREAD := 0.45
const TREE_CLEAR := 1.2
const TREE_MIN := 0.8
const CLEAR := 1.2
const ROOM := 0.25
const TREES := ["tree","layered_tree","redwood","broadleaf","bigfoot_tree","joshua","birch","willow","juniper","snag","cactus"]
## Low plants the cabin's floor simply covers.
const LOW := ["flower","button_flower","spike_flower","umbel_flower","daisy_flower","grass_tuft","bank_grass","oxeye_daisy","buttercup","dandelion","dandelion_clock","poppy","lupine","cosmos","fern","leaf_bed","mushroom"]
## Which way the door faces: down the slope where the land falls more than
## FACE_SLOPE (rise over run across the footprint), else toward the camera.
const FACE_SLOPE := 0.04

static var _mesh: ArrayMesh
static var _info: Dictionary

## The cabin, built once and shared: every stage of the model merged, its
## materials' colours on its vertices, the footing added.
static func mesh() -> ArrayMesh:
	if _mesh != null: return _mesh
	_build()
	return _mesh

## The model's measures at UNIT, cabin-local (door toward +Z): "box" (AABB of
## the whole), "pane" (AABB of the window glass), "smoke" (the flue's mouth),
## "door" (the door step on the ground).
static func info() -> Dictionary:
	if _info.is_empty(): _build()
	return _info

static func _build() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pane := AABB()
	var box := AABB()
	var seen := false
	var seen_pane := false
	var markers := {}
	var scene: PackedScene = load(MODEL)
	var root: Node3D = scene.instantiate()
	var scale := Transform3D(Basis.from_scale(Vector3.ONE*UNIT),Vector3.ZERO)
	for node in root.find_children("*","Node3D",true,false):
		var pose := scale*_pose(root,node)
		if not node is MeshInstance3D:
			markers[str(node.name)] = pose.origin
			continue
		var model: Mesh = (node as MeshInstance3D).mesh
		for s in range(model.get_surface_count()):
			var material := model.surface_get_material(s)
			var named := material.resource_name if material != null else ""
			var colour: Color = (material as BaseMaterial3D).albedo_color if material is BaseMaterial3D else Color.WHITE
			var glass := named == GLOW_SURFACE
			if glass: colour = GLASS
			var arrays := model.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				indices.resize(vertices.size())
				for i in range(vertices.size()): indices[i] = i
			var linear := colour.srgb_to_linear()
			for i in indices:
				var at: Vector3 = pose*vertices[i]
				surface.set_color(linear)
				surface.add_vertex(at)
				box = box.expand(at) if seen else AABB(at,Vector3.ZERO)
				seen = true
				if glass:
					pane = pane.expand(at) if seen_pane else AABB(at,Vector3.ZERO)
					seen_pane = true
	root.free()
	_footing(surface)
	surface.generate_normals()
	_mesh = surface.commit()
	_info = {"box":box,"pane":pane,"smoke":markers.get("smoke",Vector3(-1.2,2.9,-0.36)),"door":markers.get("door_step",Vector3(0.0,0.0,1.68))}

## `node`'s pose in `root`'s space.
static func _pose(root: Node3D, node: Node3D) -> Transform3D:
	var pose := Transform3D.IDENTITY
	var n: Node = node
	while n != root and n is Node3D:
		pose = (n as Node3D).transform*pose
		n = n.get_parent()
	return pose

## Faceted footing stones round the wall line, from FOOTING_DEPTH below the
## ground to just under the sill logs.
static func _footing(surface: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4021
	# The walls' line: the log walls are 2.6 x 3.2 m less a log's radius.
	var half := Vector2(1.16,1.46)*UNIT
	var corners := [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)]
	var k := 0
	for side in range(4):
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side+1)%4]
		var count := maxi(2,int(a.distance_to(b)/0.55))
		for i in range(count):
			var at := a.lerp(b,(i+0.5)/count)+Vector2(rng.randf_range(-0.04,0.04),rng.randf_range(-0.04,0.04))
			var size := Vector3(rng.randf_range(0.2,0.26),(FOOTING_DEPTH+0.1)*0.5,rng.randf_range(0.17,0.22))
			var turn := Basis(Vector3.UP,(b-a).angle()+rng.randf_range(-0.25,0.25))
			_stone(surface,at,size,turn,-FOOTING_DEPTH*0.5+0.04,FOOTING_TONES[k%FOOTING_TONES.size()])
			k += 1

static func _stone(surface: SurfaceTool, at: Vector2, size: Vector3, turn: Basis, y: float, colour: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var pose := Transform3D(turn*Basis.from_scale(size),Vector3(at.x,y,at.y))
	var linear := colour.srgb_to_linear()
	for vertex in sphere.get_faces():
		surface.set_color(linear)
		surface.add_vertex(pose*vertex)

## The footprint, cabin-local (x, z): the roof and chimney's reach, and in
## front the door step.
static func footprint() -> Rect2:
	var box: AABB = info().box
	var door: Vector3 = info().door
	var rect := Rect2(box.position.x,box.position.z,box.size.x,box.size.z)
	return rect.expand(Vector2(0.0,door.z))

## Plate point of cabin-local (x, z) `local` for a cabin at `p` turned `angle`.
static func to_plate(p: Vector2, angle: float, local: Vector2) -> Vector2:
	var turned := Basis(Vector3.UP,angle)*Vector3(local.x,0.0,local.y)
	return p+Vector2(turned.x,turned.z)

## Cabin-local (x, z) of plate point `q`, for a cabin at `p` turned `angle`.
static func to_local(p: Vector2, angle: float, q: Vector2) -> Vector2:
	var back := Basis(Vector3.UP,-angle)*Vector3(q.x-p.x,0.0,q.y-p.y)
	return Vector2(back.x,back.z)

## How far plate point `q` is from the footprint of a cabin at `p` turned
## `angle` (0 inside).
static func distance(p: Vector2, angle: float, q: Vector2, size := 1.0) -> float:
	var local := to_local(p,angle,q)/size
	var rect := footprint()
	var near := Vector2(clampf(local.x,rect.position.x,rect.end.x),clampf(local.y,rect.position.y,rect.end.y))
	return near.distance_to(local)*size

## The angle (about up, plate space) that turns the door (+Z) toward `towards`.
static func angle_to(towards: Vector2) -> float:
	return atan2(towards.x,towards.y)

## Which way a cabin at `p` faces: its door down the slope if the land there
## falls, else toward `eye` (the camera, plate space). Returns an angle.
static func facing(data: NativeTerrainData, p: Vector2, eye: Variant) -> float:
	var reach := 1.5
	var hx0: Variant = data.ground_height(p-Vector2(reach,0.0))
	var hx1: Variant = data.ground_height(p+Vector2(reach,0.0))
	var hz0: Variant = data.ground_height(p-Vector2(0.0,reach))
	var hz1: Variant = data.ground_height(p+Vector2(0.0,reach))
	if hx0 != null and hx1 != null and hz0 != null and hz1 != null:
		var rise := Vector2(float(hx1)-float(hx0),float(hz1)-float(hz0))/(2.0*reach)
		if rise.length() > FACE_SLOPE: return angle_to(-rise)
	if eye is Vector2 and (eye as Vector2).distance_to(p) > 0.01: return angle_to(eye-p)
	return 0.0

## Why a cabin may not stand at plate point `p` turned `angle` in `editor`'s
## world, or "" when it may: "edge" (off the plate), "water", "steep" (the
## ground under it rises more than SPREAD), "tree" (into a crown or trunk),
## "near" (another cabin) or "room" (something else stands there: a stone,
## a lamp, a campfire, a fence, a bridge, tall plants).
static func refusal(editor: Node, p: Vector2, angle: float, size := 1.0) -> String:
	var data: NativeTerrainData = editor.data
	var dry: Callable = editor.fence_dry()
	var rect := footprint()
	rect = Rect2(rect.position*size,rect.size*size).grow_individual(0.0,0.0,0.0,APRON*size)
	var low := INF
	var high := -INF
	var nx := maxi(2,ceili(rect.size.x/SAMPLE))
	var nz := maxi(2,ceili(rect.size.y/SAMPLE))
	var wet := false
	for i in range(nx+1):
		for j in range(nz+1):
			var local := rect.position+Vector2(rect.size.x*i/nx,rect.size.y*j/nz)
			var q := to_plate(p,angle,local)
			if data.sample(q,data.heights) == null: return "edge"
			var h: Variant = data.ground_height(q)
			if h == null or not dry.call(q):
				wet = true
				continue
			low = minf(low,float(h))
			high = maxf(high,float(h))
	if wet: return "water"
	if high-low > SPREAD*size: return "steep"
	# Another cabin is the likeliest reason, then a tree, then anything else.
	var found := {}
	for item: Dictionary in data.objects:
		var asset := str(item.asset)
		if asset in LOW: continue
		var foot := Vector2(float(item.x),float(item.z))
		if asset == "cabin":
			if _overlap(p,angle,size,foot,float(item.angle),float(item.scale),CLEAR): return "near"
		elif asset in TREES:
			if distance(p,angle,foot,size) < maxf(TREE_MIN,TREE_CLEAR*float(item.scale)): found["tree"] = true
		elif asset == "bridge" and item.has("end_x"):
			var far := Vector2(float(item.end_x),float(item.end_z))
			for k in range(9):
				if distance(p,angle,foot.lerp(far,k/8.0),size) < ROOM: found["room"] = true
		elif distance(p,angle,foot,size) < ROOM: found["room"] = true
	if found.has("tree"): return "tree"
	if found.has("room"): return "room"
	for fence: Dictionary in data.fences:
		var posts: Array = Array(fence.posts)
		for k in range(0,posts.size()-1,2):
			if distance(p,angle,Vector2(float(posts[k]),float(posts[k+1])),size) < ROOM: return "room"
	return ""

## Whether two cabins' footprints come within `gap` m of each other.
static func _overlap(p: Vector2, angle: float, size: float, q: Vector2, other_angle: float, other_size: float, gap: float) -> bool:
	var rect := footprint()
	for cabin in [[p,angle,size,q,other_angle,other_size],[q,other_angle,other_size,p,angle,size]]:
		var r := Rect2(rect.position*float(cabin[5]),rect.size*float(cabin[5]))
		for corner in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y),r.get_center()]:
			if distance(cabin[0],cabin[1],to_plate(cabin[3],cabin[4],corner),cabin[2]) < gap: return true
	return false
