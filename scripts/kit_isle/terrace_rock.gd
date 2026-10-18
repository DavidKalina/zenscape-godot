class_name TerraceRock
extends RefCounted
## Terraced rock: a stepped mesa built as ONE closed solid (docs/design/
## terrace-rock/spec-terrace-rock.md). Beside KitLand, which draws a
## heightfield and hangs faces off it; nothing here hangs: every face shares
## its edges with its neighbours, so there is nothing to fail to meet, and
## the collision is the drawn faces themselves.
##
## The input is a set of tiers, each an outline (x, z, either winding) at a
## height `y`. Where tiers overlap, the higher one's top wins. The outlines
## are cut at every crossing and shared stretch into one plan (a planar
## graph: `_Plan`); each face of the plan is a flat top at the height of the
## highest tier over it. Every edge of the plan is then one of:
##   internal  the same height both sides (or a bridge, see below): nothing
##   riser     two heights: faceted rock from the high top's lip to the low
##             top's edge, in rows at the shared heights `rows`
##   rim       a top on one side, the sky on the other: rock from the top
##             down to the skirt's ring (`SKIRT` under the lowest top), then
##             rings tapering in to a keel `depth` under it
## A riser's or rim's column at a plan vertex is the same points whichever
## face it belongs to (the rows are global heights, the points' facet jitter
## a function of the vertex and the height only), so where three risers or a
## riser and the rim meet they share every point: no T-junction, no slot.
## A plan piece inside another (a tier nested in a lower one) is bridged to
## its surround by two internal edges, so every face is a simple polygon.
##
## Out: a Node3D "Terrace" with "Turf" (KitLook.GroundMesh: drawn
## GroundMesh.DROP under its collision, as all the kit's turf), "Rock"
## (KitLook.RockMesh, drawn DROP under too) and "Body" (one
## ConcavePolygonShape3D of exactly the turf's and rock's faces, DROP over
## where they are drawn, both sides solid). Meta:
##   outline        the footprint (the first rim loop, PackedVector2Array)
##   terrace_tops   [{poly: PackedVector2Array, y}] each flat top face
##   terrace_rims   [PackedVector2Array] every rim loop
##   rows, keel_y, stats
## tools/terrace_check.gd sweeps a built terrace for see-in gaps, floor
## holes and collision off the drawn rock.
##
## The spec:
##   tiers   [{outline: Array of Vector2, y: float}]
##   seed    the facets' jitter (0)
##   step    the longest plan edge (STEP): risers' columns, tops' cells
##   row     the tallest riser row (ROW)
##   facet   how far a riser's inner points sit into or out of the rock (FACET)
##   skirt   the skirt ring under the lowest top (SKIRT)
##   depth   the keel under the skirt ring (DEPTH)
##   tone    (mid (x, z), normal, shimmer, y) -> Color: the turf (KitLook.turf)

const STEP := 1.6
const ROW := 2.4
const FACET := 0.32
const SKIRT := 2.6
const DEPTH := 16.0
## Points closer than this (m) are one point.
const SNAP := 0.002
## The keel's rings under the skirt: [share of depth down, share inset toward the middle].
const KEEL_RINGS := [[0.18,0.1],[0.42,0.32],[0.68,0.58],[0.88,0.82]]

static func build(spec: Dictionary) -> Node3D:
	var b := _Build.new(spec)
	return b.run()

class _Build extends RefCounted:
	var spec: Dictionary
	var tiers: Array = []
	var seed_value := 0
	var step := STEP
	var row := ROW
	var facet := FACET
	var skirt := SKIRT
	var depth := DEPTH
	var tone: Callable
	# The plan: points, undirected edges "a,b" (a < b) -> kind ("" plain, "bridge").
	var pts: Array[Vector2] = []
	var keys := {}
	var edges := {}
	var nbrs: Array = []
	# Half-edge (a, b) "a,b" -> face index (-1 outside).
	var face_of := {}
	var faces: Array = []
	var face_y: Array = []
	var rim_loops: Array = []
	var rows: Array[float] = []
	var base_y := 0.0
	var min_y := 0.0
	# Per vertex: the heights of the tops round it, plain (exactly two boundary edges of one kind), its facet direction.
	var tops_at: Array = []
	var plain: Array = []
	var dir: Array = []
	var stats := {}

	func _init(s: Dictionary) -> void:
		spec = s
		tiers = s.tiers
		seed_value = int(s.get("seed",0))
		step = float(s.get("step",STEP))
		row = float(s.get("row",ROW))
		facet = float(s.get("facet",FACET))
		skirt = float(s.get("skirt",SKIRT))
		depth = float(s.get("depth",DEPTH))
		tone = s.get("tone",KitLook.turf(seed_value))

	func run() -> Node3D:
		var began := Time.get_ticks_usec()
		_plan()
		_bridge()
		_densify()
		_walk()
		_classify()
		_rows()
		var node := Node3D.new()
		node.name = "Terrace"
		var ground := KitLook.GroundMesh.new()
		var rock := KitLook.RockMesh.new()
		var solid := PackedVector3Array()
		var tops: Array = []
		for f in range(faces.size()):
			if face_y[f] == null: continue
			var poly: PackedVector2Array = faces[f]
			var y: float = face_y[f]
			tops.append({"poly":poly,"y":y})
			for tri: Array in _top_tris(poly,f):
				var a := Vector3(tri[0].x,y,tri[0].y)
				var b := Vector3(tri[1].x,y,tri[1].y)
				var c := Vector3(tri[2].x,y,tri[2].y)
				var mid: Vector2 = (tri[0]+tri[1]+tri[2])/3.0
				var shimmer := _rand(mid,4)*0.07-0.035
				ground.add(a,b,c,tone.call(mid,Vector3.UP,shimmer,y))
				solid.append_array([a,b,c])
		_walls(rock)
		_keel(rock)
		solid.append_array(rock.faces())
		var g: MeshInstance3D = ground.node("Turf")
		if g != null: node.add_child(g)
		var r: MeshInstance3D = rock.node("Rock")
		if r != null:
			# The whole rock drawn as the turf is, DROP under its collision, so
			# a riser's foot meets the drawn turf (and the drawn solid is the
			# collided one, DROP down).
			r.position.y = -KitLook.GroundMesh.DROP
			node.add_child(r)
		var body := StaticBody3D.new()
		body.name = "Body"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(solid)
		shape.backface_collision = true
		var holder := CollisionShape3D.new()
		holder.shape = shape
		body.add_child(holder)
		node.add_child(body)
		stats["faces"] = solid.size()/3
		stats["plan_points"] = pts.size()
		stats["tops"] = tops.size()
		stats["ms"] = (Time.get_ticks_usec()-began)/1000.0
		node.set_meta("outline",rim_loops[0] if not rim_loops.is_empty() else PackedVector2Array())
		node.set_meta("terrace_tops",tops)
		node.set_meta("terrace_rims",rim_loops)
		node.set_meta("rows",rows)
		node.set_meta("keel_y",base_y-depth)
		node.set_meta("stats",stats)
		return node

	# --- The plan ---------------------------------------------------------------------

	func _vid(p: Vector2) -> int:
		var k := Vector2i(roundi(p.x/SNAP),roundi(p.y/SNAP))
		if keys.has(k): return keys[k]
		# A point a hair over a rounding line: look round it.
		for dx in [-1,0,1]:
			for dy in [-1,0,1]:
				var k2 := k+Vector2i(dx,dy)
				if keys.has(k2) and (pts[keys[k2]] as Vector2).distance_to(p) < SNAP: return keys[k2]
		keys[k] = pts.size()
		pts.append(p)
		return pts.size()-1

	static func _ek(a: int, b: int) -> String:
		return "%d,%d" % [mini(a,b),maxi(a,b)]

	func _add_edge(a: int, b: int, kind := "") -> void:
		if a == b: return
		var k := _ek(a,b)
		if not edges.has(k) or kind == "bridge": edges[k] = kind

	func _ends(k: String) -> Array:
		var s := k.split(",")
		return [int(s[0]),int(s[1])]

	## Every tier's outline cut at every crossing, every shared stretch made one.
	func _plan() -> void:
		var segs: Array = []
		for tier: Dictionary in tiers:
			var o: Array = tier.outline
			for i in range(o.size()):
				var a: Vector2 = o[i]
				var b: Vector2 = o[(i+1)%o.size()]
				if a.distance_to(b) > SNAP: segs.append([a,b])
		var boxes: Array = []
		for s: Array in segs: boxes.append(Rect2(s[0],Vector2.ZERO).expand(s[1]).grow(SNAP*4.0))
		for i in range(segs.size()):
			var a: Vector2 = segs[i][0]
			var b: Vector2 = segs[i][1]
			var d := b-a
			var len2 := d.length_squared()
			var ts: Array[float] = [0.0,1.0]
			for j in range(segs.size()):
				if j == i or not (boxes[i] as Rect2).intersects(boxes[j]): continue
				var c: Vector2 = segs[j][0]
				var e: Vector2 = segs[j][1]
				var x: Variant = Geometry2D.segment_intersects_segment(a,b,c,e)
				if x != null: ts.append(clampf((x as Vector2-a).dot(d)/len2,0.0,1.0))
				# The other's ends on this one (a shared stretch, a T).
				for q: Vector2 in [c,e]:
					var t := (q-a).dot(d)/len2
					if t > 0.0 and t < 1.0 and (a+d*t).distance_to(q) < SNAP*2.0: ts.append(t)
			ts.sort()
			var prev := _vid(a)
			for t in ts:
				var id := _vid(a+d*t)
				_add_edge(prev,id)
				prev = id

	func _adjacency() -> void:
		nbrs = []
		nbrs.resize(pts.size())
		for i in range(pts.size()): nbrs[i] = []
		for k: String in edges:
			var e := _ends(k)
			(nbrs[e[0]] as Array).append(e[1])
			(nbrs[e[1]] as Array).append(e[0])

	func _find(parent: Array, i: int) -> int:
		while parent[i] != i:
			parent[i] = parent[parent[i]]
			i = parent[i]
		return i

	## Each plan piece inside another joined to what is round it by two
	## internal edges, one off its leftmost point going -x, one off its
	## rightmost going +x, so every face is a simple polygon (a ring of top
	## round a higher tier is cut in two).
	func _bridge() -> void:
		var parent: Array = []
		for i in range(pts.size()): parent.append(i)
		for k: String in edges:
			var e := _ends(k)
			parent[_find(parent,e[0])] = _find(parent,e[1])
		var lefts := {}
		var rights := {}
		for i in range(pts.size()):
			var r := _find(parent,i)
			if not lefts.has(r) or _before(pts[i],pts[lefts[r]]): lefts[r] = i
			if not rights.has(r) or _before(pts[rights[r]],pts[i]): rights[r] = i
		var bridges := 0
		for r: int in lefts:
			for side in [-1.0,1.0]:
				var v: int = lefts[r] if side < 0.0 else rights[r]
				var hit := _ray_x(v,side)
				if hit.is_empty(): break
				var to: int
				if hit.has("at"): to = hit.at
				else:
					var e := _ends(hit.edge)
					var kind: String = edges[hit.edge]
					edges.erase(hit.edge)
					to = _vid(hit.p)
					_add_edge(e[0],to,kind)
					_add_edge(to,e[1],kind)
				_add_edge(v,to,"bridge")
				bridges += 1
		stats["bridges"] = bridges

	static func _before(p: Vector2, q: Vector2) -> bool:
		return p.x < q.x or (p.x == q.x and p.y < q.y)

	## The nearest plan edge a ray from point `v` along x `side` meets:
	## {edge, p} or {at: a point it meets}, {} if none.
	func _ray_x(v: int, side: float) -> Dictionary:
		var o := pts[v]
		var best := INF
		var out := {}
		for k: String in edges:
			var e := _ends(k)
			if e[0] == v or e[1] == v: continue
			var a := pts[e[0]]
			var b := pts[e[1]]
			if (a.y-o.y)*(b.y-o.y) > 0.0: continue
			if absf(a.y-b.y) < 1e-9: continue
			var t := (o.y-a.y)/(b.y-a.y)
			var x := a.x+(b.x-a.x)*t
			var dist := (x-o.x)*side
			if dist <= SNAP or dist >= best: continue
			best = dist
			if t < 0.01 and a.distance_to(Vector2(x,o.y)) < 0.05: out = {"at":e[0]}
			elif t > 0.99 and b.distance_to(Vector2(x,o.y)) < 0.05: out = {"at":e[1]}
			else: out = {"edge":k,"p":Vector2(x,o.y)}
		return out

	## Edges longer than `step` cut evenly (bridges left whole).
	func _densify() -> void:
		for k: String in edges.keys():
			if edges[k] == "bridge": continue
			var e := _ends(k)
			var a := pts[e[0]]
			var b := pts[e[1]]
			var n := ceili(a.distance_to(b)/step)
			if n <= 1: continue
			edges.erase(k)
			var prev: int = e[0]
			for i in range(1,n+1):
				var id: int = e[1] if i == n else _vid(a.lerp(b,float(i)/n))
				_add_edge(prev,id)
				prev = id

	## The plan's faces: each half-edge walked with its face on its left.
	## Bounded faces wind counter-clockwise (positive area); the outside's
	## cycles are the rim loops.
	func _walk() -> void:
		_adjacency()
		for i in range(pts.size()):
			var o := pts[i]
			(nbrs[i] as Array).sort_custom(func(a: int, b: int) -> bool: return (pts[a]-o).angle() < (pts[b]-o).angle())
		for start_v in range(pts.size()):
			for w: int in nbrs[start_v]:
				if face_of.has("%d,%d" % [start_v,w]): continue
				var cycle: Array[int] = []
				var u := start_v
				var v: int = w
				var guard := 0
				while true:
					face_of["%d,%d" % [u,v]] = faces.size()
					cycle.append(u)
					var around: Array = nbrs[v]
					var k := around.find(u)
					var nxt: int = around[(k-1+around.size())%around.size()]
					u = v
					v = nxt
					guard += 1
					if (u == start_v and v == w) or guard > 200000: break
				var poly := PackedVector2Array()
				for c in cycle: poly.append(pts[c])
				faces.append(poly)
				face_y.append(_area(poly))
		# Faces: area > 0 a top (its height that of the highest tier over it); else the outside.
		for f in range(faces.size()):
			var poly: PackedVector2Array = faces[f]
			if float(face_y[f]) <= 0.0:
				face_y[f] = null
				rim_loops.append(poly)
				continue
			var y: Variant = _tier_at(_inside_point(poly))
			if y == null: push_warning("TerraceRock: a face no tier covers (a courtyard) near %s: left open" % poly[0])
			face_y[f] = y
		for f in range(faces.size()):
			if face_y[f] == null:
				for k: String in face_of.keys():
					if face_of[k] == f: face_of[k] = -1

	static func _area(poly: PackedVector2Array) -> float:
		var s := 0.0
		for i in range(poly.size()):
			var a := poly[i]
			var b := poly[(i+1)%poly.size()]
			s += a.x*b.y-b.x*a.y
		return s*0.5

	## A point well inside a face: the middle of its largest triangle.
	func _inside_point(poly: PackedVector2Array) -> Vector2:
		var idx := Geometry2D.triangulate_polygon(poly)
		var best := -1.0
		var at := poly[0]
		for t in range(0,idx.size(),3):
			var a := poly[idx[t]]
			var b := poly[idx[t+1]]
			var c := poly[idx[t+2]]
			var ar := absf((b-a).cross(c-a))
			if ar > best:
				best = ar
				at = (a+b+c)/3.0
		return at

	func _tier_at(p: Vector2) -> Variant:
		var best: Variant = null
		for tier: Dictionary in tiers:
			var y := float(tier.y)
			if (best == null or y > float(best)) and Geometry2D.is_point_in_polygon(p,PackedVector2Array(tier.outline)): best = y
		return best

	func _y_of(face: int) -> Variant:
		return null if face < 0 else face_y[face]

	# --- Edges and their rock -------------------------------------------------------------

	## Each vertex: the tops round it, whether it is plain (two boundary
	## edges of one kind: its points may be jittered), its facet direction.
	func _classify() -> void:
		tops_at.resize(pts.size())
		plain.resize(pts.size())
		dir.resize(pts.size())
		var kinds: Array = []
		var into: Array = []
		kinds.resize(pts.size())
		into.resize(pts.size())
		for i in range(pts.size()):
			tops_at[i] = {}
			kinds[i] = []
			into[i] = Vector2.ZERO
		for k: String in edges:
			var e := _ends(k)
			var l: Variant = _y_of(face_of.get("%d,%d" % [e[0],e[1]],-1))
			var r: Variant = _y_of(face_of.get("%d,%d" % [e[1],e[0]],-1))
			for v in e:
				if l != null: tops_at[v][snappedf(float(l),0.001)] = true
				if r != null: tops_at[v][snappedf(float(r),0.001)] = true
			if l == r: continue
			# The rock's side: the higher top (a rim: the top).
			var d := (pts[e[1]]-pts[e[0]]).normalized()
			var left := Vector2(-d.y,d.x)
			var hi_left := r == null or (l != null and float(l) > float(r))
			var n := left if hi_left else -left
			var kind := "%s/%s" % [str(l),str(r)] if hi_left else "%s/%s" % [str(r),str(l)]
			for v in e:
				(kinds[v] as Array).append(kind)
				into[v] += n
		for i in range(pts.size()):
			var ks: Array = kinds[i]
			plain[i] = ks.size() == 2 and ks[0] == ks[1]
			var n: Vector2 = into[i]
			dir[i] = n.normalized() if n.length() > 1e-6 else Vector2.ZERO

	## The rows: every top's height, rows no taller than `row` between,
	## and down to the skirt's ring.
	func _rows() -> void:
		var ys: Array[float] = []
		for y: Variant in face_y:
			if y != null and not ys.has(snappedf(float(y),0.001)): ys.append(snappedf(float(y),0.001))
		ys.sort()
		min_y = ys[0] if not ys.is_empty() else 0.0
		base_y = min_y-skirt
		var marks: Array[float] = [base_y]
		marks.append_array(ys)
		rows = []
		for i in range(marks.size()-1):
			var a := marks[i]
			var b := marks[i+1]
			var n := maxi(ceili((b-a)/row-0.001),1)
			for j in range(n): rows.append(a+(b-a)*j/n)
		rows.append(marks[marks.size()-1])

	func _rows_between(lo: float, hi: float) -> Array[float]:
		var out: Array[float] = []
		for g in rows:
			if g >= lo-0.0005 and g <= hi+0.0005: out.append(g)
		return out

	## Stable 0..1 at a plan point.
	func _rand(p: Vector2, salt: int) -> float:
		return float(absi(hash([seed_value,roundi(p.x*64.0),roundi(p.y*64.0),salt]))%100000)/100000.0

	## A wall's point over plan vertex `v` at height `g`: the vertex itself
	## at every top's height round it; between, at a plain vertex (or under
	## the lowest top, the skirt alone), set into or out of the rock.
	func _at(v: int, g: float) -> Vector3:
		var p := pts[v]
		var lip := (tops_at[v] as Dictionary).has(snappedf(g,0.001))
		if not lip and (plain[v] or g < min_y-0.001):
			var u := _rand(p+Vector2(g*7.31,g*3.17),11)
			p += (dir[v] as Vector2)*lerpf(-0.35,1.0,u)*facet
		return Vector3(p.x,g,p.y)

	## Every riser and rim face, in rows.
	func _walls(rock: KitLook.RockMesh) -> void:
		var risers := 0
		var rims := 0
		for k: String in edges:
			var e := _ends(k)
			var l: Variant = _y_of(face_of.get("%d,%d" % [e[0],e[1]],-1))
			var r: Variant = _y_of(face_of.get("%d,%d" % [e[1],e[0]],-1))
			if l == r: continue
			var hi: float
			var lo: float
			var d := (pts[e[1]]-pts[e[0]]).normalized()
			var left := Vector2(-d.y,d.x)
			var hi_left := r == null or (l != null and float(l) > float(r))
			var out := -left if hi_left else left
			hi = float(l) if hi_left else float(r)
			var lo_v: Variant = r if hi_left else l
			if lo_v == null:
				lo = base_y
				rims += 1
			else:
				lo = float(lo_v)
				risers += 1
			var gs := _rows_between(lo,hi)
			var toward := Vector3(out.x,0.0,out.y)
			for j in range(gs.size()-1):
				var q0 := _at(e[0],gs[j])
				var q1 := _at(e[1],gs[j])
				var q2 := _at(e[1],gs[j+1])
				var q3 := _at(e[0],gs[j+1])
				var mid := (pts[e[0]]+pts[e[1]])*0.5
				var shade := 0.88+0.22*_rand(mid+Vector2(gs[j],0.0),12)
				if _rand(mid+Vector2(0.0,gs[j]),13) < 0.5:
					rock.add([q0,q1,q2],hi,toward,shade)
					rock.add([q0,q2,q3],hi,toward,shade*0.97)
				else:
					rock.add([q0,q1,q3],hi,toward,shade)
					rock.add([q1,q2,q3],hi,toward,shade*0.97)
		stats["riser_edges"] = risers
		stats["rim_edges"] = rims

	## Under each rim loop: rings tapering in from the skirt's ring to a keel.
	func _keel(rock: KitLook.RockMesh) -> void:
		for loop: PackedVector2Array in rim_loops:
			var ids: Array[int] = []
			for p in loop: ids.append(_vid(p))
			var centre := Vector2.ZERO
			for p in loop: centre += p
			centre /= maxf(loop.size(),1)
			var top_y := -INF
			for v in ids:
				for y: float in tops_at[v]: top_y = maxf(top_y,y)
			var rings: Array = []
			var first: Array[Vector3] = []
			for v in ids: first.append(_at(v,base_y))
			rings.append(first)
			for spec_k: Array in KEEL_RINGS:
				var ring: Array[Vector3] = []
				for v in ids:
					var p := pts[v]
					var u := _rand(p,20+rings.size())
					var q := p.lerp(centre,clampf(float(spec_k[1])+(u-0.5)*0.08,0.0,0.95))
					ring.append(Vector3(q.x,base_y-depth*float(spec_k[0])*lerpf(0.88,1.12,_rand(p,30+rings.size())),q.y))
				rings.append(ring)
			var keel := Vector3(centre.x,base_y-depth,centre.y)
			var c3 := Vector3(centre.x,0.0,centre.y)
			var n := ids.size()
			for k in range(rings.size()):
				var upper: Array = rings[k]
				var last := k == rings.size()-1
				for i in range(n):
					var a: Vector3 = upper[i]
					var b: Vector3 = upper[(i+1)%n]
					var shade := 0.88+0.22*_rand(pts[ids[i]],40+k)
					if last:
						var m := (a+b+keel)/3.0
						rock.add([a,keel,b],top_y,Vector3(m.x-c3.x,-1.0,m.z-c3.z),shade)
						continue
					var lower: Array = rings[k+1]
					var c: Vector3 = lower[(i+1)%n]
					var d: Vector3 = lower[i]
					var m2 := (a+b+c+d)/4.0
					var toward := Vector3(m2.x-c3.x,-0.4,m2.z-c3.z)
					rock.add([a,b,c],top_y,toward,shade)
					rock.add([a,c,d],top_y,toward,shade*0.97)

	# --- The tops ---------------------------------------------------------------------

	## A top face's triangles ([Vector2 x3]): its edge points and a jittered
	## grid inside, Delaunay, kept if every edge of the face is a triangle's
	## edge (else the face's own ear-clipping).
	func _top_tris(poly: PackedVector2Array, f: int) -> Array:
		var n := poly.size()
		var points := PackedVector2Array(poly)
		var seen := {}
		var dup := false
		for p in poly:
			var k := Vector2i(roundi(p.x/SNAP),roundi(p.y/SNAP))
			if seen.has(k): dup = true
			seen[k] = true
		var box := Rect2(poly[0],Vector2.ZERO)
		for p in poly: box = box.expand(p)
		var cell := step
		var x := box.position.x+cell*0.5
		while x < box.end.x:
			var y := box.position.y+cell*0.5
			while y < box.end.y:
				var q := Vector2(x,y)+Vector2(_rand(Vector2(x,y),1)-0.5,_rand(Vector2(x,y),2)-0.5)*cell*0.5
				if Geometry2D.is_point_in_polygon(q,poly) and _edge_distance(q,poly) > cell*0.75: points.append(q)
				y += cell
			x += cell
		var out: Array = []
		if not dup:
			var idx := Geometry2D.triangulate_delaunay(points)
			var have := {}
			var area := 0.0
			for t in range(0,idx.size(),3):
				var a := points[idx[t]]
				var b := points[idx[t+1]]
				var c := points[idx[t+2]]
				if not Geometry2D.is_point_in_polygon((a+b+c)/3.0,poly): continue
				out.append([a,b,c])
				area += absf((b-a).cross(c-a))*0.5
				for pair in [[idx[t],idx[t+1]],[idx[t+1],idx[t+2]],[idx[t+2],idx[t]]]:
					have[_ek(pair[0],pair[1])] = true
			var whole := absf(area-_area(poly)) < maxf(0.002*_area(poly),0.01)
			for i in range(n):
				if not whole or not have.has(_ek(i,(i+1)%n)):
					whole = false
					break
			if whole: return out
		stats["ear_clipped"] = int(stats.get("ear_clipped",0))+1
		out = []
		var ears := Geometry2D.triangulate_polygon(poly)
		if ears.is_empty(): push_warning("TerraceRock: top face %d near %s could not be triangulated" % [f,poly[0]])
		for t in range(0,ears.size(),3): out.append([poly[ears[t]],poly[ears[t+1]],poly[ears[t+2]]])
		return out

	static func _edge_distance(p: Vector2, poly: PackedVector2Array) -> float:
		var best := INF
		for i in range(poly.size()):
			var c: Vector2 = Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()])
			best = minf(best,c.distance_to(p))
		return best
