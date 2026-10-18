extends RefCounted
## The terrace check: sweeps a built terraced solid (scripts/kit_isle/
## terrace_rock.gd, any node with the meta "terrace_tops") for
##   see_in    sight rays from walker eyes over every top and from high
##             cameras round it whose first drawn face is a back face (you
##             see into the solid: a gap, a slot, a missing face)
##   through   sight rays that pass under a top's turf, inside the rock, before
##             they meet anything drawn (a hole you see the sky or the far
##             side through)
##   holes     down rays over every top that find no collision at the turf
##             (a hole in the floor, or a floor set off the drawn one)
##   standoff  rays at the body band where the collision stands more than
##             STAND off the drawn faces (an invisible wall, or rock you walk
##             into)
## The drawn faces are every MeshInstance3D under the terrace (and under
## `opts.drawn`, more nodes: the pieces seated on it), as a pair of check
## bodies on their own layers: one solid from both sides, one only from the
## front, so a ray that meets the first sooner met a back face. The game's
## collision is every body under the terrace (and `opts.bodies`).
##
##   const TerraceCheck = preload("res://tools/terrace_check.gd")
##   var got: Dictionary = await TerraceCheck.sweep(terrace, {"grid": 1.5})
## Or a whole scene: python tools/drive.py tools/terrace_check_run.gd -- --scene=studies/x.tscn
## Opts: grid (the floor samples' spacing, 1.5), eye_every (3.0), eyes
## ([1.1, 2.6] over the turf), reach (45), cameras (8), drawn, bodies, quiet.
## A sample under a seated piece (`drawn`: a stair in its cut) is lifted
## onto the piece's drawn top, so its eyes stand on the stair, and its floor
## is the piece's (within PIECE_OFF: a worn nosing).
## Returns {samples, rays, see_in, through, holes, standoff, *_at: the first
## positions of each}.

const LAYER_BOTH := 1 << 22
const LAYER_FRONT := 1 << 23
## The seated pieces' drawn faces alone: a floor sample under one is lifted
## onto it (he stands on the stair, not in it).
const LAYER_PIECE := 1 << 21
## How high over a top a seated piece may stand (m): a grand stair's head.
const PIECE_REACH := 6.0
## A lifted sample's floor: the collision within this of the drawn piece
## (a worn nosing's chamfer lies a few cm under the step's walked top; a
## hole is a step's riser or more).
const PIECE_OFF := 0.15
## The most a collision hit may stand off the drawn one (m).
const STAND := 0.3
## The floor: collision this far under or over the turf's own height is a hole.
const FLOOR_OFF := 0.08
const KEEP := 24

static func sweep(terrace: Node3D, opts := {}) -> Dictionary:
	var tree := terrace.get_tree()
	var tops: Array = terrace.get_meta("terrace_tops",[])
	var drawn_roots: Array = [terrace]
	drawn_roots.append_array(opts.get("drawn",[]))
	var body_roots: Array = [terrace]
	body_roots.append_array(opts.get("bodies",[]))
	var faces := PackedVector3Array()
	var piece_faces := PackedVector3Array()
	for root: Node in drawn_roots:
		for mi: MeshInstance3D in _meshes(root):
			if mi.mesh == null or not mi.is_visible_in_tree(): continue
			var xf := mi.global_transform
			for p in mi.mesh.get_faces():
				faces.append(xf*p)
				if root != terrace: piece_faces.append(xf*p)
	var game := {}
	var mask := 0
	for root: Node in body_roots:
		for b: CollisionObject3D in _bodies(root):
			game[b.get_rid()] = true
			mask |= b.collision_layer
	var both := _check_body(faces,true,LAYER_BOTH)
	var front := _check_body(faces,false,LAYER_FRONT)
	tree.root.add_child(both)
	tree.root.add_child(front)
	var pieces: StaticBody3D = null
	if not piece_faces.is_empty():
		pieces = _check_body(piece_faces,true,LAYER_PIECE)
		tree.root.add_child(pieces)
	await tree.physics_frame
	await tree.physics_frame
	var space := terrace.get_world_3d().direct_space_state
	var got := {"samples":0,"rays":0,"see_in":0,"through":0,"holes":0,"standoff":0,
		"see_in_at":[],"through_at":[],"holes_at":[],"standoff_at":[],"faces":faces.size()/3}
	var raster := _Raster.new(tops,0.75)
	var grid := float(opts.get("grid",1.5))
	var eye_every := float(opts.get("eye_every",3.0))
	var eyes: Array = opts.get("eyes",[1.1,2.6])
	var reach := float(opts.get("reach",45.0))
	var samples: Array = []
	var eye_at: Array = []
	var top_most := -INF
	var box := Rect2()
	for top: Dictionary in tops:
		var poly: PackedVector2Array = top.poly
		var y := float(top.y)
		top_most = maxf(top_most,y)
		var b := Rect2(poly[0],Vector2.ZERO)
		for p in poly: b = b.expand(p)
		box = b if box.size == Vector2.ZERO else box.merge(b)
		var x := b.position.x+grid*0.5
		while x < b.end.x:
			var z := b.position.y+grid*0.5
			while z < b.end.y:
				var q := Vector2(x,z)
				if Geometry2D.is_point_in_polygon(q,poly) and _edge_distance(q,poly) > 0.25:
					samples.append(Vector3(q.x,y,q.y))
					if fmod(x-b.position.x,eye_every) < grid and fmod(z-b.position.y,eye_every) < grid: eye_at.append(Vector3(q.x,y,q.y))
				z += grid
			x += grid
	# Samples under a seated piece lifted onto it.
	if pieces != null:
		await tree.physics_frame
		var lifted := 0
		var on_piece := {}
		for list: Array in [samples,eye_at]:
			for i in range(list.size()):
				var s: Vector3 = list[i]
				var hit := _ray(space,s+Vector3.UP*PIECE_REACH,s+Vector3.UP*0.05,LAYER_PIECE)
				if not hit.is_empty():
					list[i] = hit.position
					lifted += 1
					if list == samples: on_piece[i] = true
		got["lifted"] = lifted
		got["on_piece"] = on_piece
	got.samples = samples.size()
	# The floor: down rays.
	var on: Dictionary = got.get("on_piece",{})
	got.erase("on_piece")
	for i in range(samples.size()):
		var s: Vector3 = samples[i]
		var col := _game_ray(space,s+Vector3.UP*1.0,s+Vector3.DOWN*1.5,mask,game)
		var drawn := _ray(space,s+Vector3.UP*1.0,s+Vector3.DOWN*1.5,LAYER_BOTH)
		got.rays += 2
		if col.is_empty() or absf((col.position as Vector3).y-s.y) > (PIECE_OFF if on.has(i) else FLOOR_OFF):
			_flag(got,"holes",s)
		elif not drawn.is_empty() and absf((col.position as Vector3).y-(drawn.position as Vector3).y) > STAND:
			_flag(got,"standoff",s)
	# Eyes over the tops.
	var dirs: Array[Vector3] = []
	for el in [-60.0,-30.0,-12.0,0.0,12.0]:
		for k in range(16):
			var az := TAU*k/16.0+deg_to_rad(el)*0.37
			dirs.append(Vector3(cos(az)*cos(deg_to_rad(el)),sin(deg_to_rad(el)),sin(az)*cos(deg_to_rad(el))))
	for s: Vector3 in eye_at:
		for h: float in eyes:
			var eye: Vector3 = s+Vector3.UP*h
			for d in dirs:
				_sight(space,got,raster,eye,eye+d*reach)
				# The body band: the collision against the drawn faces.
				if h == eyes[0] and absf(d.y) < 0.25:
					var drawn := _ray(space,eye,eye+d*reach,LAYER_BOTH)
					var col := _game_ray(space,eye,eye+d*reach,mask,game)
					got.rays += 2
					# Each hit must have the other surface within STAND across it
					# (along its normal: a grazing ray's hits lie far apart along it).
					var off := false
					if not col.is_empty() and not _near(space,col.position,col.normal,LAYER_BOTH,{}): off = true
					if not drawn.is_empty() and not _near(space,drawn.position,drawn.normal,mask,game): off = true
					got.rays += 2
					if off: _flag(got,"standoff",(col.position if not col.is_empty() else drawn.position) as Vector3,eye)
	# High cameras round it, looking at the tops.
	var centre := box.get_center()
	var radius := box.size.length()*0.5
	var cams: Array[Vector3] = [Vector3(centre.x,top_most+radius*0.8,centre.y)]
	for k in range(int(opts.get("cameras",8))):
		var a := TAU*k/float(opts.get("cameras",8))
		cams.append(Vector3(centre.x+cos(a)*radius*1.3,top_most+radius*0.5,centre.y+sin(a)*radius*1.3))
	for cam in cams:
		for i in range(0,samples.size(),2):
			var s: Vector3 = samples[i]
			var to := s+(s-cam).normalized()*2.0
			_sight(space,got,raster,cam,to)
	both.queue_free()
	front.queue_free()
	if pieces != null: pieces.queue_free()
	if not bool(opts.get("quiet",false)):
		print("terrace check %s: %d samples (%d on seated pieces), %d rays, %d faces: see_in %d, through %d, holes %d, standoff %d" % [terrace.name,got.samples,int(got.get("lifted",0)),got.rays,got.faces,got.see_in,got.through,got.holes,got.standoff])
		for key in ["see_in","through","holes","standoff"]:
			if int(got[key]) > 0:
				print("  %s at %s" % [key,str((got[key+"_at"] as Array).slice(0,8))])
				print("    seen from %s" % str((got.get(key+"_from",[]) as Array).slice(0,8)))
	return got

## One sight ray: a back face met first, or the rock passed through.
static func _sight(space: PhysicsDirectSpaceState3D, got: Dictionary, raster: _Raster, from: Vector3, to: Vector3) -> void:
	var both := _ray(space,from,to,LAYER_BOTH)
	var front := _ray(space,from,to,LAYER_FRONT)
	got.rays += 2
	var end := to
	if not both.is_empty():
		end = both.position
		var d_both := from.distance_to(both.position)
		if front.is_empty() or from.distance_to(front.position) > d_both+0.02:
			_flag(got,"see_in",end,from)
			return
	var length := from.distance_to(end)
	var step := 0.4
	var t := step
	while t < length-0.1:
		var q := from.lerp(end,t/length)
		var y := raster.deep_top(Vector2(q.x,q.z))
		if not is_nan(y) and q.y < y-0.15 and q.y > y-4.0:
			_flag(got,"through",q,from)
			return
		t += step

## A fault at `at`, seen `from` there (kept in `<key>_from`).
static func _flag(got: Dictionary, key: String, at: Vector3, from := Vector3.INF) -> void:
	got[key] = int(got[key])+1
	var list: Array = got[key+"_at"]
	if list.size() >= KEEP: return
	list.append(at.snapped(Vector3.ONE*0.01))
	if not got.has(key+"_from"): got[key+"_from"] = []
	(got[key+"_from"] as Array).append(from.snapped(Vector3.ONE*0.01) if from != Vector3.INF else at.snapped(Vector3.ONE*0.01))

## A surface (on `mask`; of `game` if given) within STAND of `p` (`_n`
## unused: a ball, so a hit at a lip or a riser's foot finds the other
## surface DROP away whichever way it lies).
static func _near(space: PhysicsDirectSpaceState3D, p: Vector3, _n: Vector3, mask: int, game: Dictionary) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = STAND
	q.shape = ball
	q.transform = Transform3D(Basis.IDENTITY,p)
	q.collision_mask = mask
	for hit: Dictionary in space.intersect_shape(q,16):
		if game.is_empty() or game.has(hit.rid): return true
	return false

static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from,to,mask)
	q.hit_back_faces = true
	return space.intersect_ray(q)

## The first of the game's own bodies (`game`, rid -> true) a ray meets.
static func _game_ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, game: Dictionary) -> Dictionary:
	var skip: Array[RID] = []
	for i in range(6):
		var q := PhysicsRayQueryParameters3D.create(from,to,mask,skip)
		q.hit_back_faces = true
		var hit := space.intersect_ray(q)
		if hit.is_empty() or game.has(hit.rid): return hit
		skip.append(hit.rid)
	return {}

static func _check_body(faces: PackedVector3Array, backface: bool, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TerraceCheck%s" % ("Both" if backface else "Front")
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = backface
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	return body

static func _meshes(root: Node) -> Array:
	var out: Array = []
	if root is MeshInstance3D: out.append(root)
	for c in root.find_children("*","MeshInstance3D",true,false): out.append(c)
	return out

static func _bodies(root: Node) -> Array:
	var out: Array = []
	if root is CollisionObject3D: out.append(root)
	for c in root.find_children("*","CollisionObject3D",true,false): out.append(c)
	return out

static func _edge_distance(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in range(poly.size()):
		best = minf(best,Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()]).distance_to(p))
	return best

## The tops' heights on a grid: `deep_top` is a top's height where the cell
## and its eight neighbours are all that top (a cell clear of its edges), NAN else.
class _Raster extends RefCounted:
	var cell := 0.75
	var origin := Vector2.ZERO
	var w := 0
	var h := 0
	var ids := PackedInt32Array()
	var ys := PackedFloat32Array()

	func _init(tops: Array, c: float) -> void:
		cell = c
		var box := Rect2()
		for top: Dictionary in tops:
			for p: Vector2 in top.poly: box = Rect2(p,Vector2.ZERO) if box.size == Vector2.ZERO and box.position == Vector2.ZERO else box.expand(p)
		origin = box.position-Vector2.ONE*cell*2.0
		w = int(ceil(box.size.x/cell))+5
		h = int(ceil(box.size.y/cell))+5
		ids.resize(w*h)
		ids.fill(-1)
		var boxes: Array = []
		for top: Dictionary in tops:
			var b := Rect2((top.poly as PackedVector2Array)[0],Vector2.ZERO)
			for p: Vector2 in top.poly: b = b.expand(p)
			boxes.append(b)
		for top: Dictionary in tops: ys.append(float(top.y))
		for j in range(h):
			for i in range(w):
				var p := origin+Vector2(i+0.5,j+0.5)*cell
				for t in range(tops.size()):
					if (boxes[t] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p,tops[t].poly):
						ids[j*w+i] = t
						break

	func deep_top(p: Vector2) -> float:
		var i := int(floor((p.x-origin.x)/cell))
		var j := int(floor((p.y-origin.y)/cell))
		if i < 1 or j < 1 or i >= w-1 or j >= h-1: return NAN
		var t := ids[j*w+i]
		if t < 0: return NAN
		for dj in [-1,0,1]:
			for di in [-1,0,1]:
				if ids[(j+dj)*w+i+di] != t: return NAN
		return ys[t]
