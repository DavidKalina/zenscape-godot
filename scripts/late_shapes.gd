extends RefCounted
## Big collision bodies stood a slice of shapes a frame (perf round 2,
## docs/design/roguelike/perf-round2.md). A merged ruin run's "Body" can hold
## thousands of convex hulls (the colonnade spine's, 9254) and each hull
## costs the physics server 10-30 us to take (Jolt builds its shape): a part
## of a thousand cost 15-80 ms in one frame.
##
## `defer` (safe on a worker, the node off the tree) takes the shapes past
## the first KEEP out of each such body and keeps them in the body's meta
## "late_shapes"; once the body is in the tree, `Drain` puts them back a
## slice a frame. Every shape gets back, (in order): the wanderer's collision
## is the same, only complete a few frames later (a part is not "up" before).

const NativeIsleKernels = preload("res://scripts/native_isle_kernels.gd")

## A body keeps this many shapes while it enters the tree.
const KEEP := 16
## Only a body with more convex shapes than this has them held back (a
## smaller one costs little, and the stair isle's flora read less ground
## with its small bodies' shapes held: 2226 plants, not 3289).
const HULLS_BIG := 200
## Shapes put back per call at most, and the usual budget in microseconds.
const SLICE := 128

## Takes the shapes past KEEP out of every StaticBody3D under `root` with
## more than KEEP. Answers how many shapes were held back.
static func defer(root: Node) -> int:
	var held := 0
	for node: Node in root.find_children("*","StaticBody3D",true,false):
		held += defer_body(node as StaticBody3D)
	if root is StaticBody3D: held += defer_body(root as StaticBody3D)
	return held

## A trimesh over this many face corners (3 a triangle) is cut in pieces.
const BIG_FACES := 9000
## About this many triangles a piece.
const PIECE_TRIS := 2500

static func defer_body(body: StaticBody3D) -> int:
	if body.has_meta("late_shapes"): return 0
	var late: Array = []
	# A big trimesh (Jolt builds its tree when the body takes it: 25-45 ms for
	# the colonnade spine's 19,000 triangles) is cut along its longest side
	# into pieces of about PIECE_TRIS triangles: the first stays, the rest
	# are held. The same triangles collide.
	for child in body.get_children():
		var holder := child as CollisionShape3D
		if holder == null or not holder.shape is ConcavePolygonShape3D: continue
		var faces := (holder.shape as ConcavePolygonShape3D).get_faces()
		if faces.size() <= BIG_FACES: continue
		var pieces := _cut(faces)
		# New shapes, never the old one cut in place: it may be shared.
		var first := ConcavePolygonShape3D.new()
		first.backface_collision = (holder.shape as ConcavePolygonShape3D).backface_collision
		first.set_faces(pieces[0])
		var original := holder.shape as ConcavePolygonShape3D
		holder.shape = first
		for i in range(1,pieces.size()):
			var more := CollisionShape3D.new()
			more.name = holder.name+"Piece"+str(i)
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = original.backface_collision
			shape.set_faces(pieces[i])
			more.shape = shape
			more.transform = holder.transform
			more.disabled = holder.disabled
			late.append(more)
	if body.get_child_count() > HULLS_BIG:
		var children := body.get_children()
		for i in range(KEEP,children.size()):
			if children[i] is CollisionShape3D:
				body.remove_child(children[i])
				late.append(children[i])
	if late.is_empty(): return 0
	late.reverse()
	body.set_meta("late_shapes",late)
	return late.size()

## `faces` (triangle corners) cut into pieces of about PIECE_TRIS triangles:
## the triangles sorted by their middle along the longest side.
static func _cut(faces: PackedVector3Array) -> Array:
	# The native kernel cuts the same pieces (isle_kernels.h `cut_faces`).
	var kernel: Object = NativeIsleKernels.get_kernel()
	if kernel != null: return kernel.cut_faces(faces,PIECE_TRIS)
	var tris := faces.size()/3
	var box := AABB(faces[0],Vector3.ZERO)
	for p in faces: box = box.expand(p)
	var axis := box.get_longest_axis_index()
	var keys: Array = []
	for t in range(tris): keys.append([(faces[t*3][axis]+faces[t*3+1][axis]+faces[t*3+2][axis]),t])
	keys.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var count := maxi(int(ceil(float(tris)/PIECE_TRIS)),1)
	var out: Array = []
	for k in range(count):
		var piece := PackedVector3Array()
		for i in range(k*tris/count,(k+1)*tris/count):
			var t: int = keys[i][1]
			piece.append(faces[t*3])
			piece.append(faces[t*3+1])
			piece.append(faces[t*3+2])
		out.append(piece)
	return out

## The bodies under `root` with shapes held back.
static func held_bodies(root: Node) -> Array:
	var out: Array = []
	for node: Node in root.find_children("*","StaticBody3D",true,false):
		if node.has_meta("late_shapes"): out.append(node)
	if root.has_meta("late_shapes"): out.append(root)
	return out

## Puts the held shapes of `bodies` back, in order, for about `usec` (-1:
## all at once) and at most SLICE (when timed). Answers true once none is
## left.
static func drain(bodies: Array, usec: int) -> bool:
	var end := Time.get_ticks_usec()+usec
	var put := 0
	while not bodies.is_empty():
		var body: StaticBody3D = bodies[0]
		if not is_instance_valid(body):
			bodies.pop_front()
			continue
		var late: Array = body.get_meta("late_shapes")
		while not late.is_empty():
			body.add_child(late.pop_back())
			put += 1
			if usec >= 0 and (put >= SLICE or (put % 8 == 0 and Time.get_ticks_usec() > end)): return false
		body.remove_meta("late_shapes")
		bodies.pop_front()
	return true
