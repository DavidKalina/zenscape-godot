class_name KitLand
extends RefCounted
## The kit isles' land builder (docs/scenic/kit-isle-shared.md): the ground
## of a hand-built sky isle over a height function, its cliffs, its
## collision and its hanging sides, in the kit isles' one look
## (scripts/shared/kit_look.gd). The aqueduct isle's island builder
## (scripts/shared/aqueduct_isle_art.gd) generalised, as its motifs had each copied
## it: the bell spires' turf, the cloister tarn's mother and satellites, the
## sundered gorge's halves, the colonnade spine's ridge all build on these.
##
## A ground is gathered as points (x, z) with heights: the outline's own,
## the cliffs' (`cliff_points`: along every step of the height function, a
## point on its top and at its foot, so a cliff is a crisp face and never a
## slope smeared over a cell) and a jittered grid (`grid`), finer in boxes.
## `surface` triangulates them: each face collided (one trimesh), a convex
## prism under each cliff face (so a ray started under a lip finds its top,
## and its lip is a ledge), and drawn: turf faces in the plate's ground,
## faces too steep for turf in the islets' rock. `bodies` holds the
## collision, never more than SHAPES_A_BODY shapes in one body (one compound
## of a trimesh and thousands of prisms is past what Jolt's sub-shape ids can
## number). `ring_sides` hangs the sides and keel from the outline.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const NativeIsleKernels = preload("res://scripts/native_isle_kernels.gd")

## The most shapes one body holds.
const SHAPES_A_BODY := 2048
## The cliffs' probe step (m).
const CLIFF_PROBE := 0.5

# --- Outlines ---------------------------------------------------------------------------

## Stable jitter (the spec's `stable`, the motif editor's): the shared rng
## is reseeded from the isle's seed and a point's position before that
## point's draws, so an edit that adds or drops points elsewhere (a stamp's
## cliff points) leaves every other point's jitter, shimmer and side as it
## was. Off (the default) nothing is reseeded: every isle builds as before.
static func pin(rng: RandomNumberGenerator, p: Vector2, salt := 0) -> void:
	if not rng.has_meta("stable"): return
	rng.seed = hash([int(rng.get_meta("stable")),roundi(p.x*64.0),roundi(p.y*64.0),salt])

static func perimeter(outline: Array) -> float:
	var total := 0.0
	for i in range(outline.size()): total += (outline[i] as Vector2).distance_to(outline[(i+1)%outline.size()])
	return total

## The outline resampled to `count` points evenly round it, each nudged out
## or in a little (rng), so its edge wanders.
static func resample(outline: Array, count: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var total := perimeter(outline)
	var out: Array[Vector2] = []
	var step := total/count
	var seg := 0
	var into := 0.0
	for k in range(count):
		var want := step*k
		while true:
			var a: Vector2 = outline[seg%outline.size()]
			var b: Vector2 = outline[(seg+1)%outline.size()]
			var length := a.distance_to(b)
			if want-into <= length or seg >= outline.size()*2:
				var p := a.lerp(b,clampf((want-into)/maxf(length,0.001),0.0,1.0))
				var normal := Vector2(b.y-a.y,a.x-b.x).normalized()
				pin(rng,p,1)
				out.append(p+normal*rng.randf_range(-0.35,0.35))
				break
			into += length
			seg += 1
	return out

## A small isle's outline: a wandering ring `r` round `centre`.
static func blob(centre: Vector2, r: float, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for k in range(11):
		var a := k*TAU/11.0+rng.randf_range(-0.12,0.12)
		out.append(centre+Vector2(cos(a),sin(a))*r*rng.randf_range(0.78,1.12))
	return out

static func area(ring: Array) -> float:
	var s := 0.0
	for i in range(ring.size()):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i+1)%ring.size()]
		s += a.x*b.y-b.x*a.y
	return s*0.5

## Outline checks (`island` warns, the build never reads them). The
## builder takes either winding (`outward` asks, KitFlora takes |area|),
## and the isles wind both ways: the aqueduct isle's and many greyboxes'
## run clockwise (`area` < 0), Geometry2D's clip/merge/offset hand back
## boundaries counter-clockwise (`area` > 0) and holes clockwise. So a
## winding is checked only where a spec says which it means (`winding`
## 1 or -1): a clipped piece that is a hole, or a list reversed, then warns.
## False: `island` checks nothing.
static var check_outlines := true

## What is wrong with `outline` (x, z points) as a land's outline, one
## line each (none: nothing): too few points or no area, edges crossing
## (a bowtie or a fold: the land's inside is ambiguous) and, with
## `winding` 1 (counter-clockwise, `area` > 0, Geometry2D's boundary) or
## -1 (clockwise), wound the other way.
static func outline_problems(outline: Array, winding := 0) -> PackedStringArray:
	var out := PackedStringArray()
	var n := outline.size()
	if n < 3:
		out.append("%d points, not a ring" % n)
		return out
	var a := area(outline)
	if absf(a) < 1e-6:
		out.append("no area")
		return out
	var crossing := _first_crossing(outline)
	if not crossing.is_empty():
		out.append("self-intersecting: edge %d crosses edge %d near (%.1f, %.1f)" % [crossing[0],crossing[1],(crossing[2] as Vector2).x,(crossing[2] as Vector2).y])
	elif winding != 0 and signf(a) != signf(winding):
		out.append("reversed: %s, signed area %.1f m², the spec wants %s (a clipped hole, or the list reversed)" % ["clockwise" if a < 0.0 else "counter-clockwise",a,"counter-clockwise" if winding > 0 else "clockwise"])
	return out

## Edges i and j of `ring` that cross (not neighbours) and where: [i, j,
## point], or [] when none do. Edges are swept along x, so a long ring
## checks only the edges whose x spans overlap.
static func _first_crossing(ring: Array) -> Array:
	var n := ring.size()
	var spans: Array = []
	for i in range(n):
		var p: Vector2 = ring[i]
		var q: Vector2 = ring[(i+1)%n]
		spans.append([minf(p.x,q.x),maxf(p.x,q.x),i])
	spans.sort_custom(func(u: Array, v: Array) -> bool: return float(u[0]) < float(v[0]))
	for s in range(spans.size()):
		var i: int = spans[s][2]
		var a0: Vector2 = ring[i]
		var a1: Vector2 = ring[(i+1)%n]
		for t in range(s+1,spans.size()):
			if float(spans[t][0]) > float(spans[s][1]): break
			var j: int = spans[t][2]
			if absi(i-j) <= 1 or absi(i-j) == n-1: continue
			var b0: Vector2 = ring[j]
			var b1: Vector2 = ring[(j+1)%n]
			# Edges meeting at a repeated point (a closing point given twice).
			if a0.is_equal_approx(b1) or a1.is_equal_approx(b0) or a0.is_equal_approx(b0) or a1.is_equal_approx(b1): continue
			var hit: Variant = Geometry2D.segment_intersects_segment(a0,a1,b0,b1)
			if hit != null: return [mini(i,j),maxi(i,j),hit]
	return []

static func edge_distance(p: Vector2, poly: PackedVector2Array) -> float:
	# The native kernel's is this very loop (native/terrain_kernels/isle_kernels.h).
	var kernel: Object = NativeIsleKernels.get_kernel()
	if kernel != null: return kernel.edge_distance(p,poly)
	var best := INF
	for i in range(poly.size()):
		var q := Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()])
		best = minf(best,p.distance_to(q))
	return best

static func centre_of(ring: Array) -> Vector2:
	var centre := Vector2.ZERO
	for p: Vector2 in ring: centre += p
	return centre/maxf(ring.size(),1)

## Each ring point's way out of the land.
static func outward(ring: Array) -> Array[Vector2]:
	var count := ring.size()
	var out: Array[Vector2] = []
	var ccw := area(ring) > 0.0
	for i in range(count):
		var tangent: Vector2 = ((ring[(i+1)%count] as Vector2)-(ring[(i-1+count)%count] as Vector2)).normalized()
		out.append(Vector2(tangent.y,-tangent.x) if ccw else Vector2(-tangent.y,tangent.x))
	return out

## Out from `centre` (x, z) through `at`, level.
static func out_from(centre: Vector2, at: Vector3) -> Vector3:
	return Vector3(at.x-centre.x,0.0,at.z-centre.y).normalized()

## How worn the ground is near `paths` (world polylines of (x, z)): a
## callable (x, z) -> 0..1, 1 on a path's middle, 0 from about `reach`*1.9
## m off it (the aqueduct isle's `path_wear`).
static func wear_of(paths: Array, reach := 1.5) -> Callable:
	return func(at: Vector2) -> float:
		var best := INF
		for path: Array in paths:
			for i in range(path.size()-1):
				best = minf(best,at.distance_to(Geometry2D.get_closest_point_to_segment(at,path[i],path[i+1])))
		return clampf(1.25-best/reach,0.0,1.0)

# --- Ground points -----------------------------------------------------------------------

## The ground points along every step of `ground` (world (x, z) -> y) inside
## `box` (probed on a CLIFF_PROBE grid from its corner nudged off the round
## numbers, the step found by halving): a point just on its top, one at its
## foot (its width by the drop, at most `foot_most`), a row either side, and
## on a tall one a point between pushed in or out (`wobble`), so its face is
## a crag's facets. `walled` (world (x, z) -> bool): a face kept inside a
## retaining wall's thickness. `nudge`: the probes' start off the box's
## corner (off the round numbers, where a ray is likely cast). `min_drop`:
## the least change across a probe step that is a cliff (0.3; a steep
## slope's own rise is under a larger one). `skip` (world (x, z) -> bool):
## where no cliff is laid (the editor's smooth stamps; none: everywhere).
## {points, heights}.
static func cliff_points(ground: Callable, box: Rect2, rng: RandomNumberGenerator, walled := Callable(), foot_most := 0.8, wobble := 0.22, nudge := Vector2(0.137,0.213), min_drop := 0.3, skip := Callable()) -> Dictionary:
	var points := PackedVector2Array()
	var heights := PackedFloat32Array()
	var seen := {}
	var x := box.position.x+nudge.x
	while x < box.end.x:
		var z := box.position.y+nudge.y
		while z < box.end.y:
			var a := Vector2(x,z)
			var ha: float = ground.call(a.x,a.y)
			for way: Vector2 in [Vector2(CLIFF_PROBE,0.0),Vector2(0.0,CLIFF_PROBE)]:
				var c := a+way
				var hc: float = ground.call(c.x,c.y)
				if absf(ha-hc) < min_drop: continue
				var lo := a
				var hi := c
				for k in range(14):
					var m := (lo+hi)*0.5
					var hm: float = ground.call(m.x,m.y)
					if absf(hm-ha) < absf(hm-hc): lo = m
					else: hi = m
				var e := (lo+hi)*0.5
				if skip.is_valid() and bool(skip.call(e)): continue
				var key := Vector2i(floori(e.x/0.3),floori(e.y/0.3))
				if seen.has(key): continue
				seen[key] = true
				var h0: float = ground.call(e.x,e.y)
				var down := Vector2.ZERO
				for k in range(8):
					var d := Vector2.from_angle(k*TAU/8.0)
					down -= d*(float(ground.call(e.x+d.x*0.35,e.y+d.y*0.35))-h0)
				if down.length() < 0.01: continue
				down = down.normalized()
				pin(rng,e,2)
				e += down.orthogonal()*rng.randf_range(-0.04,0.04)
				var top := e-down*0.04
				var is_walled: bool = walled.is_valid() and bool(walled.call(e))
				var drop := absf(ha-hc)
				var w := 0.18 if is_walled else clampf(0.1*drop,0.2,foot_most)*rng.randf_range(0.8,1.25)
				var foot := e+down*w
				var ht: float = ground.call(top.x,top.y)
				var hf: float = ground.call(foot.x,foot.y)
				points.append(top)
				heights.append(ht)
				points.append(foot)
				heights.append(hf)
				# A row either side, so no face of the ground spans the lip.
				for q: Vector2 in [e-down*0.5,foot+down*0.45]:
					points.append(q)
					heights.append(float(ground.call(q.x,q.y)))
				if drop > 1.5 and not is_walled:
					var mid := e+down*w*rng.randf_range(0.2,0.8)+down.orthogonal()*rng.randf_range(-wobble,wobble)
					points.append(mid)
					heights.append(lerpf(ht,hf,rng.randf_range(0.3,0.7)))
			z += CLIFF_PROBE
		x += CLIFF_PROBE
	return {"points":points,"heights":heights}

## A ground being gathered: its outline (`poly`), its points and heights,
## which of them are a cliff's, and where the cliffs are (a 0.5 m grid).
class Gather extends RefCounted:
	var poly: PackedVector2Array
	var points := PackedVector2Array()
	var heights := PackedFloat32Array()
	var cliff_ids := PackedInt32Array()
	var near := {}

	func _init(ring: Array, ground: Callable) -> void:
		poly = PackedVector2Array(ring)
		points = PackedVector2Array(ring)
		for p: Vector2 in ring: heights.append(float(ground.call(p.x,p.y)))

	## The cliffs' points ({points, heights}, `cliff_points`) inside the
	## outline (`edge` m in from it at least), never two nearly on one
	## another (the triangulation drops faces round them).
	func add_cliffs(found: Dictionary, edge := 0.5) -> void:
		var cp: PackedVector2Array = found.points
		var ch: PackedFloat32Array = found.heights
		var taken := {}
		for i in range(cp.size()):
			if not Geometry2D.is_point_in_polygon(cp[i],poly) or KitLand.edge_distance(cp[i],poly) < edge: continue
			var key := Vector2i(floori(cp[i].x/0.15),floori(cp[i].y/0.15))
			var crowded := false
			for dx in range(-1,2):
				for dz in range(-1,2):
					var other: Variant = taken.get(key+Vector2i(dx,dz))
					if other != null and (other as Vector2).distance_to(cp[i]) < 0.12: crowded = true
			if crowded: continue
			taken[key] = cp[i]
			points.append(cp[i])
			heights.append(ch[i])
			cliff_ids.append(points.size()-1)
			near[Vector2i(floori(cp[i].x/0.5),floori(cp[i].y/0.5))] = true

	func near_cliff(p: Vector2) -> bool:
		var k := Vector2i(floori(p.x/0.5),floori(p.y/0.5))
		for dx in range(-1,2):
			for dz in range(-1,2):
				if near.has(k+Vector2i(dx,dz)): return true
		return false

	## A jittered grid over the outline's box (rng, every cell drawn whether
	## kept or not), `cell` m: kept inside the outline (more than 0.45 of a
	## cell in), inside `rects` (or outside them, `inside` false; none: all),
	## off the cliffs' points where `off_cliffs`.
	func grid(cell: float, rng: RandomNumberGenerator, ground: Callable, rects: Array = [], inside := true, off_cliffs := true) -> void:
		var box := Rect2(poly[0],Vector2.ZERO)
		for p in poly: box = box.expand(p)
		var stable := rng.has_meta("stable")
		# Stable: the lattice on world multiples of the cell, not the box.
		var x0 := floorf(box.position.x/cell)*cell+cell*0.5 if stable else box.position.x+cell*0.5
		var z0 := floorf(box.position.y/cell)*cell+cell*0.5 if stable else box.position.y+cell*0.5
		var gx := x0
		while gx < box.end.x:
			var gz := z0
			while gz < box.end.y:
				KitLand.pin(rng,Vector2(gx,gz),3)
				var p := Vector2(gx+rng.randf_range(-0.3,0.3)*cell,gz+rng.randf_range(-0.3,0.3)*cell)
				gz += cell
				if not rects.is_empty():
					var within := false
					for r: Rect2 in rects:
						if r.has_point(p): within = true
					if within != inside: continue
				if not Geometry2D.is_point_in_polygon(p,poly) or KitLand.edge_distance(p,poly) <= cell*0.45: continue
				if off_cliffs and near_cliff(p): continue
				points.append(p)
				heights.append(float(ground.call(p.x,p.y)))
			gx += cell

	## A byte a point: 1 for a cliff's.
	func cliffy() -> PackedByteArray:
		var out := PackedByteArray()
		if cliff_ids.is_empty(): return out
		out.resize(points.size())
		out.fill(0)
		for i in cliff_ids: out[i] = 1
		return out

# --- The surface --------------------------------------------------------------------------

## The ground over `points` (x, z) and `heights`, triangulated, inside
## `poly`: {ground (KitLook.GroundMesh), rock (KitLook.RockMesh), faces (the
## collided trimesh), solid (the cliffs' prisms)}. Each face takes one
## shimmer off `rng` (-0.035..0.035), in the faces' order. A face is rock
## where `rocky` (mid (x, z), its normal -> bool) says so (default: steeper
## than the palette's rock slope), else turf of `tone` (mid (x, z), its
## normal, shimmer, its mean height -> Color, linear). A prism hangs under
## each face touching a cliff point (`cliffy`, a byte a point) or, with
## `steep` > 0, under each face whose normal's y is under it.
## A cliff prism's depth under its face's lowest corner (m); within
## PRISM_RIM of the outline, PRISM_RIM_DROP.
const PRISM_DROP := 1.5
const PRISM_RIM := 2.0
const PRISM_RIM_DROP := 0.3
static func surface(points: PackedVector2Array, heights: PackedFloat32Array, poly: PackedVector2Array, rng: RandomNumberGenerator,
		tone: Callable, rocky := Callable(), cliffy := PackedByteArray(), steep := 0.0, prism_drop := PRISM_DROP) -> Dictionary:
	var tris := Geometry2D.triangulate_delaunay(points)
	var pal := KitLook.palette()
	var ground := KitLook.GroundMesh.new()
	var rock := KitLook.RockMesh.new()
	var faces := PackedVector3Array()
	var solid: Array[PackedVector3Array] = []
	for t in range(0,tris.size(),3):
		var a := points[tris[t]]
		var b := points[tris[t+1]]
		var c := points[tris[t+2]]
		var mid := (a+b+c)/3.0
		if not Geometry2D.is_point_in_polygon(mid,poly): continue
		var pa := Vector3(a.x,heights[tris[t]],a.y)
		var pb := Vector3(b.x,heights[tris[t+1]],b.y)
		var pc := Vector3(c.x,heights[tris[t+2]],c.y)
		faces.append_array([pa,pb,pc])
		var normal := (pb-pa).cross(pc-pa).normalized()
		if normal.y < 0.0: normal = -normal
		var prism := (not cliffy.is_empty() and (cliffy[tris[t]] or cliffy[tris[t+1]] or cliffy[tris[t+2]])) or (steep > 0.0 and normal.y < steep)
		if prism:
			# Under the rim (within PRISM_RIM of the outline) a prism hangs
			# only PRISM_RIM_DROP: the sides drawn below the rim turn in, and
			# a deep one stood out under the lip in the air, invisible.
			var drop := prism_drop if edge_distance(mid,poly) > PRISM_RIM else PRISM_RIM_DROP
			var deep := minf(pa.y,minf(pb.y,pc.y))-drop
			var hull := PackedVector3Array([pa,pb,pc,Vector3(pa.x,deep,pa.z),Vector3(pb.x,deep,pb.z),Vector3(pc.x,deep,pc.z)])
			if RuinKit.hull_thickness(hull) >= RuinKit.HULL_THIN: solid.append(hull)
		pin(rng,mid,4)
		var shimmer := rng.randf_range(-0.035,0.035)
		var is_rock: bool = bool(rocky.call(mid,normal)) if rocky.is_valid() else KitLook.is_rock(normal,pal)
		if is_rock:
			# Drawn a hair under where it collides, as the turf is.
			var drop := Vector3(0.0,KitLook.GroundMesh.DROP,0.0)
			rock.add([pa-drop,pb-drop,pc-drop],maxf(pa.y,maxf(pb.y,pc.y)),normal,1.0+shimmer*3.0)
		else:
			ground.add(pa,pb,pc,tone.call(mid,normal,shimmer,(pa.y+pb.y+pc.y)/3.0))
	return {"ground":ground,"rock":rock,"faces":faces,"solid":solid}

## The surface drawn under `node`: "Ground" (turf), "Crags" (its rock).
static func draw(node: Node3D, built: Dictionary) -> void:
	var g: MeshInstance3D = (built.ground as KitLook.GroundMesh).node("Ground")
	if g != null: node.add_child(g)
	var r: MeshInstance3D = (built.rock as KitLook.RockMesh).node("Crags")
	if r != null: node.add_child(r)

## The collision under `node`: "Body", the trimesh `faces` and, `together`,
## as many of the prisms `solid` as it holds (SHAPES_A_BODY in all); the
## rest in "Cliffs0", "Cliffs1"... of SHAPES_A_BODY each. Returns "Body".
static func bodies(node: Node3D, faces: PackedVector3Array, solid: Array, together := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	node.add_child(body)
	var into: StaticBody3D = body if together else null
	var held := 1 if together else SHAPES_A_BODY
	var more: Array = []
	for hull: PackedVector3Array in solid:
		if held >= SHAPES_A_BODY:
			into = StaticBody3D.new()
			into.name = "Cliffs%d" % more.size()
			more.append(into)
			node.add_child(into)
			held = 0
		var prism := ConvexPolygonShape3D.new()
		prism.points = hull
		var c := CollisionShape3D.new()
		c.shape = prism
		into.add_child(c)
		held += 1
	node.set_meta("cliff_prisms",solid.size())
	node.set_meta("cliff_bodies",more)
	return body

## A land's ground bodies: its "Body" and the bodies holding the rest of its
## cliffs' prisms (`bodies`), the turf the plants and the plane read.
static func turf_bodies(land: Node3D) -> Array:
	var out: Array = [land.get_node("Body")]
	out.append_array(land.get_meta("cliff_bodies",[]))
	return out

# --- The sides -------------------------------------------------------------------------------

## The sides and keel under `ring` (the outline, x z): rings of rock down
## from the rim (`rim_y`, a height a ring point) to a keel `depth` under
## `top` near `centre`: the turf's lip (0.45 m), the earth (2.1 m), then
## inset rings tapering in, each every `stride` points (a spur or two
## hanging lower where `spurs`); with `hang`, the lip and earth hang from a
## high rim's own height, the rock from `top`. Draws the islets' rock. The
## rng is drawn as the aqueduct isle drew its sides.
static func ring_sides(ring: Array, rim_y: PackedFloat32Array, centre: Vector2, top: float, depth: float, rng: RandomNumberGenerator,
		spurs := true, hang := false, stop_small := true, whole := true) -> KitLook.RockMesh:
	var count := ring.size()
	var out := outward(ring)
	var rims: Array = []
	var top_ring: Array[Vector3] = []
	for i in range(count): top_ring.append(Vector3((ring[i] as Vector2).x,rim_y[i]-0.02,(ring[i] as Vector2).y))
	rims.append(top_ring)
	var strides: Array[int] = [1]
	# Each ring: [inset toward the middle, drop under the top, push out, stride].
	var specs := [[0.0,0.45,0.28,1],[0.0,2.1,0.35,1],[0.1,depth*0.22,0.0,2],[0.32,depth*0.48,0.0,4],[0.6,depth*0.74,0.0,8],[0.82,depth*0.92,0.0,16]]
	var hanging := {}
	pin(rng,centre,5)
	if spurs:
		for i in range(3): hanging[rng.randi_range(0,maxi(count/16-1,0))] = rng.randf_range(0.15,0.3)*depth
	for spec: Array in specs:
		var stride: int = spec[3]
		if stop_small and count/stride < 4: break
		var r: Array[Vector3] = []
		for i in range(0,count,stride):
			var p: Vector2 = ring[i]
			pin(rng,p,10+stride)
			var inset: float = float(spec[0])+rng.randf_range(-0.05,0.05)*float(spec[0] > 0.0)
			var q := p.lerp(centre,clampf(inset,0.0,0.95))+out[i]*float(spec[2])*rng.randf_range(0.3,1.2)
			var drop: float = float(spec[1])*rng.randf_range(0.85,1.15)
			if stride == 16 and hanging.has(i/16): drop += hanging[i/16]
			var base_y := top
			if hang: base_y = minf(top,top_ring[i].y) if float(spec[1]) >= 3.0 else top_ring[i].y
			r.append(Vector3(q.x,base_y-drop,q.y))
		rims.append(r)
		strides.append(stride)
	pin(rng,centre,6)
	var keel := Vector3(centre.x+rng.randf_range(-2.0,2.0),top-depth,centre.y+rng.randf_range(-2.0,2.0))
	var rock := KitLook.RockMesh.new()
	for k in range(rims.size()-1):
		var upper: Array = rims[k]
		var lower: Array = rims[k+1]
		var su: int = strides[k]
		var sl: int = strides[k+1]
		# Lower point j fans to upper.size()/lower.size() upper points (a
		# whole number when `count` is a multiple of the strides, 16). With
		# `whole`, stitched by the ring's own index instead: lower point j
		# (ring index j*sl) fans to the upper points from its index to the
		# next lower one's, the last taking the rest. The same faces when
		# `count` is a multiple of 16; with any other count the plain ratio
		# leaves part of the upper ring unstitched and spans the keel with
		# long faces (a sheet across a ravine cut under it, collided:
		# spec-editor-traps item 13). Whole is the default for every isle
		# (item 17); `whole` false keeps the old stitch for a comparison.
		var ratio := upper.size()/lower.size()
		for j in range(lower.size()):
			var l0: Vector3 = lower[j]
			var l1: Vector3 = lower[(j+1)%lower.size()]
			var next := mini((j+1)*sl,count) if whole else (j+1)*ratio*su
			var u := j*sl if whole else j*ratio*su
			while u < next:
				var u0: Vector3 = upper[u/su]
				var u1: Vector3 = upper[((u+su)/su)%upper.size()] if u+su < count else upper[0]
				var m := (u0+u1+l0)/3.0
				pin(rng,Vector2(m.x,m.z),7)
				rock.add([u0,l0,u1],rim_y[u%count],out_from(centre,m),rng.randf_range(0.88,1.1))
				u += su
			var ue: Vector3 = upper[(next/su)%upper.size()] if next < count or not whole else upper[0]
			var m2 := (ue+l0+l1)/3.0
			pin(rng,Vector2(m2.x,m2.z),8)
			rock.add([ue,l0,l1],rim_y[(j*sl)%count],out_from(centre,m2),rng.randf_range(0.88,1.1))
	var last: Array = rims[rims.size()-1]
	var mean_rim := 0.0
	for y in rim_y: mean_rim += y
	mean_rim /= maxf(rim_y.size(),1)
	for j in range(last.size()):
		var a: Vector3 = last[j]
		var b: Vector3 = last[(j+1)%last.size()]
		var mid := (a+b+keel)/3.0
		pin(rng,Vector2(mid.x,mid.z),9)
		rock.add([a,keel,b],mean_rim,out_from(centre,mid)+Vector3.DOWN,rng.randf_range(0.88,1.1))
	return rock

# --- An island ---------------------------------------------------------------------------------

## An island (the aqueduct isle's): its top the plate's ground over
## `spec.ground` (world (x, z) -> y), collided, its crags in rock, its sides
## and keel of hanging rock `spec.depth` under `spec.top`. The spec:
##   outline   world (x, z) points round it (resampled: `resample`
##             [perimeter over which, points then, points else])
##   seed, ground, top, depth
##   cliffs    a box (Rect2) its steps are laid in as cliff points (none:
##             no cliffs), `walled` keeping faces inside a wall,
##             `cliffs_nudge` the probes' start off its corner,
##             `cliff_drop` the least step that is a cliff (0.3),
##             `cliff_skip` (x, z) -> bool where none is laid
##   rocky     (mid (x, z), normal) -> bool: a face drawn rock (none: past
##             the palette's rock slope, `surface`)
##   cell      its grid (2 m); `fine` the finer cell inside `fine_box` (or
##             everywhere with cliffs and no fine_box)
##   tone      (mid (x, z), normal, shimmer, mean y) -> Color: its turf
##   hang      the lip and earth hang from a high rim's own height
##   apart     the cliffs' prisms in bodies apart from the ground's
##   stable    jitter pinned to positions, not drawn in turn (`pin`): an
##             edit changes the land only where it changed (the editor's)
##   prism_drop  how far the cliffs' prisms hang under their faces away from
##             the rim (PRISM_DROP)
##   whole_sides  the sides stitched whole for any ring count (ring_sides'
##             `whole`, the default; false: the old stitch, holes and long
##             faces at counts not a multiple of 16)
##   sides     false: no hanging sides drawn ("Mesh"; a caller that draws
##             its own skirt, the Stair to the Clouds' mesa)
##   winding   1 (counter-clockwise, Geometry2D's boundary) or -1: the
##             outline is checked for it (`outline_problems`; none: either)
##   name      what the outline warnings call it (or `motif`, `id`)
##   solid_more  more convex hulls (PackedVector3Array) collided with the
##             cliffs' prisms (a ramp's solid core: MotifAuthored Slope.hull)
##   collide_sides  the hanging sides collided as drawn ("Sides", last
##             child: the bodies climb them, a fall past a flank meets it),
##             `sides_backface` (true) its faces solid from both sides
## Meta: outline, ground_points, cliff_prisms.
static func island(spec: Dictionary) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.seed)
	if bool(spec.get("stable",false)): rng.set_meta("stable",int(spec.seed))
	var outline: Array = spec.outline
	if check_outlines:
		for problem in outline_problems(outline,int(spec.get("winding",0))):
			push_warning("KitLand.island %s: outline %s" % [_label(spec),problem])
	var ground: Callable = spec.ground
	var top: float = spec.top
	var depth: float = spec.depth
	var resampling: Array = spec.get("resample",[60.0,96,32])
	var ring := resample(outline,int(resampling[1]) if perimeter(outline) > float(resampling[0]) else int(resampling[2]),rng)
	var node := Node3D.new()
	node.name = "Island"
	var centre := centre_of(ring)
	var g := Gather.new(ring,ground)
	var cliffs: Rect2 = spec.get("cliffs",Rect2())
	var has_cliffs := cliffs.size != Vector2.ZERO
	if has_cliffs: g.add_cliffs(cliff_points(ground,cliffs,rng,spec.get("walled",Callable()),0.8,0.22,spec.get("cliffs_nudge",Vector2(0.137,0.213)),float(spec.get("cliff_drop",0.3)),spec.get("cliff_skip",Callable())))
	var cell: float = spec.get("cell",2.0)
	var fine: float = spec.get("fine",1.2)
	var fine_box: Rect2 = spec.get("fine_box",Rect2())
	if fine_box.size != Vector2.ZERO:
		g.grid(cell,rng,ground,[fine_box],false,false)
		g.grid(fine,rng,ground,[fine_box],true,true)
	else:
		g.grid(fine if has_cliffs else cell,rng,ground,[],true,has_cliffs)
	var built := surface(g.points,g.heights,g.poly,rng,spec.tone,spec.get("rocky",Callable()),g.cliffy(),0.0,float(spec.get("prism_drop",PRISM_DROP)))
	draw(node,built)
	var rims := PackedFloat32Array()
	for p: Vector2 in ring: rims.append(float(ground.call(p.x,p.y)))
	var drawn: MeshInstance3D = null
	if bool(spec.get("sides",true)):
		var sides := ring_sides(ring,rims,centre,top,depth,rng,true,bool(spec.get("hang",false)),true,bool(spec.get("whole_sides",true)))
		drawn = sides.node("Mesh")
		if drawn != null: node.add_child(drawn)
	var solid: Array = built.solid
	if spec.has("solid_more"): solid = solid+(spec.solid_more as Array)
	bodies(node,built.faces,solid,not bool(spec.get("apart",false)))
	node.set_meta("outline",g.poly)
	node.set_meta("ground_points",g.points.size())
	if bool(spec.get("collide_sides",false)): collide_sides(node,drawn,bool(spec.get("sides_backface",true)))
	return node

## The island's name in a warning: the spec's `name` (or `motif`, `id`)
## if it has one, its seed, and its outline's first point.
static func _label(spec: Dictionary) -> String:
	var bits := PackedStringArray()
	for key in ["motif","name","id"]:
		if spec.has(key): bits.append("%s=%s" % [key,str(spec[key])])
	bits.append("seed=%s" % str(spec.get("seed","?")))
	var outline: Array = spec.get("outline",[])
	if not outline.is_empty(): bits.append("from (%.1f, %.1f)" % [(outline[0] as Vector2).x,(outline[0] as Vector2).y])
	return "[%s]" % ", ".join(bits)

## `drawn` (an island's hanging sides) collided as drawn: "Sides" under `node`.
static func collide_sides(node: Node3D, drawn: MeshInstance3D, backface := true) -> void:
	if drawn == null or drawn.mesh == null: return
	var body := StaticBody3D.new()
	body.name = "Sides"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(drawn.mesh.get_faces())
	shape.backface_collision = backface
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	node.add_child(body)
