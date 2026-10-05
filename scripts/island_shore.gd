extends RefCounted
## The earth sides of an island with an outline (scripts/island_outline.gd):
## a wall hung under every shore edge, from the land's own edge down to the
## foot of the earth (about NativeTerrainData.SLAB_BASE), and under the land
## the rock it hangs from (`keel`). It stands in for the square plate's
## authored sides (NativeChunkEditor `skirt_mesh_for` returns it), in the same
## mesh and material, so the strata (scripts/strata.gd) and the mist toward
## the foot paint it as they paint the square's sides: each wall vertex
## carries its rim top in UV (the earth-sides switch in
## shaders/reference_surface.gdshader).
##
## Each shore point hangs a ring a little under the rim, stood out from the
## land by a seeded amount, so the wall breaks into facets as the authored
## sides do instead of running down as one sheet.
##
## The rock is a height field on the plate's own points, laid on the land's
## own faces (one rock face under each), so it meets the wall's foot point
## for point and a height query on it (NativeTerrainData `underside`) is what
## is drawn. It hangs from the wall's foot, which wanders a little under and
## over SLAB_BASE along the shore (LIP), drops steeply just inside the shore
## (SHOULDER), and tapers to a faceted point a little off the island's middle
## (an upside-down pyramid of a few planes), with a spur or two hanging lower
## and shallower wedges (SHELF) under lobes the point does not reach. Its
## depth goes with the island's size (DEEP), its depths fall in ledges
## (TIER), and everything is seeded by the outline, so it never changes
## while the top is shaped.

## The facet ring: how far under the rim (m), and how far out it stands (m).
const RING_DROP := Vector2(0.55,1.5)
const RING_OUT := Vector2(0.02,0.2)
## The rock, in metres under SLAB_BASE. The point's depth from the smallest
## island to the largest (scripts/island_outline.gd AREA), give or take
## DEEP_SPREAD of it, and never more than DEEPEST.
const DEEP := Vector2(8.0,14.0)
const DEEP_SPREAD := 0.12
const DEEPEST := 18.0
## The wall's foot along the shore: from this far over SLAB_BASE to this far
## under it, wandering over LIP_WAVE metres.
const LIP := Vector2(-0.3,2.2)
const LIP_WAVE := 6.0
## The steepest the rock falls inland from the shore (m down a metre in),
## and the least (the shelf under lobes the point does not reach).
const SHOULDER := 2.6
const SHELF := 0.9
## The point: how many planes (a range), and how far each runs out before
## it meets the foot, as a share of the island's mean radius.
const PLANES := Vector2i(4,6)
const PLANE_RUN := Vector2(1.0,1.5)
## The point stands at least this share of the deepest inland distance in
## from the shore, and at least AWAY m from the island's middle.
const POINT_IN := 0.45
const AWAY := 1.5
## Spurs: how many, their own run (m), how far each hangs past the rock
## round it (share of the point's depth), and how far in they stand (m).
const SPURS := Vector2i(1,3)
const SPUR_RUN := Vector2(1.8,3.6)
const SPUR_DROP := Vector2(0.22,0.5)
const SPUR_IN := 2.5
## Ledges: depths fall in steps of this height (m), each step's riser this
## share of it, blended in by TIER_SHARE.
const TIER := Vector2(1.8,2.8)
const TIER_RISE := 0.35
const TIER_SHARE := 0.45

## The wall and rock for `data`'s outline in the earth sides' own space:
## `placing` takes that space to the terrain's (NativeChunkEditor's skirt
## placing; translation only). Empty without an outline. The rock depends on
## the outline alone and is laid once per outline and placing (`data`
## keeps it); only the wall follows the shore's heights.
static func build(data: NativeTerrainData, placing: Transform3D, material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if data.outline.is_empty(): return mesh
	var into := placing.affine_inverse()
	var lift := into.origin.y
	var points := data.points
	var heights := data.heights
	var edges := data.shore_edges
	var outward := _outward(points,edges)
	var keel := data.keel
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var base := NativeTerrainData.SLAB_BASE
	for k in range(0,edges.size(),3):
		var a := edges[k]
		var b := edges[k+1]
		var pa := points[a]
		var pb := points[b]
		var out: Vector2 = (outward[a]+outward[b]).normalized()
		var top_a := Vector3(pa.x,heights[a],pa.y)
		var top_b := Vector3(pb.x,heights[b],pb.y)
		var ring_a := _ring(a,top_a,outward[a])
		var ring_b := _ring(b,top_b,outward[b])
		var foot_a := Vector3(pa.x,base-keel[a],pa.y)
		var foot_b := Vector3(pb.x,base-keel[b],pb.y)
		var face := Vector3(out.x,0.0,out.y)
		var ha := heights[a]
		var hb := heights[b]
		_add(vertices,uvs,into,[top_a,top_b,ring_b],face,[ha,hb,hb],lift)
		_add(vertices,uvs,into,[top_a,ring_b,ring_a],face,[ha,hb,ha],lift)
		_add(vertices,uvs,into,[ring_a,ring_b,foot_b],face,[ha,hb,hb],lift)
		_add(vertices,uvs,into,[ring_a,foot_b,foot_a],face,[ha,hb,ha],lift)
	# The rock: every land face again, hung at its corners' depths, facing
	# down.
	if data.underside_laid.size() != 3 or data.underside_laid[0] != into:
		var rock := PackedVector3Array()
		var rock_uvs := PackedVector2Array()
		var ids := data.vertex_ids
		for f in range(data.outline.size()):
			if data.outline[f] != 0: continue
			var tri := []
			for j in range(3):
				var p := points[ids[f*3+j]]
				tri.append(Vector3(p.x,base-keel[ids[f*3+j]],p.y))
			_add(rock,rock_uvs,into,tri,Vector3.DOWN,[],lift)
		data.underside_laid = [into,rock,rock_uvs]
	vertices.append_array(data.underside_laid[1])
	uvs.append_array(data.underside_laid[2])
	if vertices.is_empty(): return mesh
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3): normals[i+j] = normal
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,material)
	return mesh

## A triangle into the soup, wound to face `face` (the terrain's frame), in
## the sides' own space. `tops` are the rim heights over its corners (the
## terrain's frame); none for the rock, which reads `earth_sides_top`.
static func _add(vertices: PackedVector3Array, uvs: PackedVector2Array, into: Transform3D, tri: Array, face: Vector3, tops: Array, lift: float) -> void:
	var a: Vector3 = tri[0]
	var b: Vector3 = tri[1]
	var c: Vector3 = tri[2]
	var order := [0,1,2]
	# The shader's front: (c-a)×(b-a), as the terrain's own faces.
	if (c-a).cross(b-a).dot(face) < 0.0: order = [0,2,1]
	for j: int in order:
		vertices.append(into*(tri[j] as Vector3))
		uvs.append(Vector2(float(tops[j])+lift,1.0) if not tops.is_empty() else Vector2.ZERO)

## The facet ring's point under shore point `i`: under its top, stood out.
static func _ring(i: int, top: Vector3, out: Vector2) -> Vector3:
	var drop := lerpf(RING_DROP.x,RING_DROP.y,_hash(i,3))
	var reach := lerpf(RING_OUT.x,RING_OUT.y,_hash(i,7))
	return Vector3(top.x+out.x*reach,maxf(top.y-drop,NativeTerrainData.SLAB_BASE+0.5),top.z+out.y*reach)

## Each shore point's way out from the land: the mean of its shore edges'
## outward normals (away from the land face's third corner).
static func _outward(points: PackedVector2Array, edges: PackedInt32Array) -> Dictionary:
	var sums := {}
	for k in range(0,edges.size(),3):
		var a := points[edges[k]]
		var b := points[edges[k+1]]
		var c := points[edges[k+2]]
		var along := (b-a).normalized()
		var normal := Vector2(along.y,-along.x)
		if normal.dot(a-c) < 0.0: normal = -normal
		for i in [edges[k],edges[k+1]]: sums[i] = sums.get(i,Vector2.ZERO)+normal
	for i in sums: sums[i] = (sums[i] as Vector2).normalized()
	return sums

## How far under SLAB_BASE the rock hangs at each of the plate's points (m),
## for the outline `outline` (a byte a face, scripts/island_outline.gd) with
## `distance` its shore distance (`shore_distance`); 0 off the island.
## Seeded by the outline itself: the same outline hangs the same rock.
static func keel(points: PackedVector2Array, ids: PackedInt32Array, outline: PackedByteArray, distance: PackedFloat32Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(points.size())
	if outline.is_empty(): return result
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([outline,"island keel"])
	# The island's size, middle and reach.
	var land := 0.0
	var total := 0.0
	var middle := Vector2.ZERO
	for f in range(outline.size()):
		var a := points[ids[f*3]]
		var b := points[ids[f*3+1]]
		var c := points[ids[f*3+2]]
		var area := absf((b-a).cross(c-a))*0.5
		total += area
		if outline[f] != 0: continue
		land += area
		middle += (a+b+c)/3.0*area
	if land <= 0.0: return result
	middle /= land
	var area_range: Vector2 = preload("res://scripts/island_outline.gd").AREA
	var size := clampf(inverse_lerp(area_range.x,area_range.y,land/total),0.0,1.0)
	var radius := sqrt(land/PI)
	var deepest_in := 0.0
	for d in distance: deepest_in = maxf(deepest_in,d)
	# The point: a land point well inland, off the middle.
	var choices := PackedInt32Array()
	var fallback := PackedInt32Array()
	for i in range(points.size()):
		if distance[i] < deepest_in*POINT_IN: continue
		fallback.append(i)
		if points[i].distance_to(middle) >= AWAY: choices.append(i)
	if choices.is_empty(): choices = fallback
	var at := points[choices[rng.randi_range(0,choices.size()-1)]]
	var depth := lerpf(DEEP.x,DEEP.y,size)*rng.randf_range(1.0-DEEP_SPREAD,1.0+DEEP_SPREAD)
	var pyramids: Array[_Pyramid] = [_Pyramid.new(rng,at,depth,radius*PLANE_RUN.x,radius*PLANE_RUN.y,PLANES)]
	# Spurs: inland points away from the point and from each other, each
	# hanging past the rock round it.
	var spots := PackedInt32Array()
	for i in range(points.size()):
		if distance[i] >= SPUR_IN: spots.append(i)
	for k in range(rng.randi_range(SPURS.x,SPURS.y)):
		for attempt in range(12):
			if spots.is_empty(): break
			var spot := points[spots[rng.randi_range(0,spots.size()-1)]]
			var clear := true
			for pyramid in pyramids: clear = clear and spot.distance_to(pyramid.apex) >= radius*0.35
			if not clear: continue
			var run := rng.randf_range(SPUR_RUN.x,SPUR_RUN.y)
			var past := pyramids[0].depth_at(spot)+depth*rng.randf_range(SPUR_DROP.x,SPUR_DROP.y)
			pyramids.append(_Pyramid.new(rng,spot,past,run*0.8,run*1.2,Vector2i(3,4)))
			break
	var lip := FastNoiseLite.new()
	lip.seed = rng.randi()
	lip.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	lip.frequency = 1.0/LIP_WAVE
	var step := rng.randf_range(TIER.x,TIER.y)
	for i in range(points.size()):
		var s := distance[i]
		if s < 0.0: continue
		var p := points[i]
		var foot := lerpf(LIP.x,LIP.y,clampf(lip.get_noise_2d(p.x,p.y)*0.75+0.5,0.0,1.0))
		var d := foot+SHELF*s
		for pyramid in pyramids: d = maxf(d,pyramid.depth_at(p))
		d = minf(d,foot+SHOULDER*s)
		# Ledges: the depth eased toward a stair of the same slope.
		var t := d/step
		var stair := (floorf(t)+clampf((t-floorf(t)-(1.0-TIER_RISE))/TIER_RISE,0.0,1.0))*step
		result[i] = minf(lerpf(d,stair,TIER_SHARE) if s > 0.0 else foot,DEEPEST)
	return result

## An upside-down pyramid: `depth` m deep at its apex, each of its planes
## rising to 0 a seeded run out from it.
class _Pyramid:
	var apex: Vector2
	var depth: float
	## Each plane's way out, over its run.
	var slopes := PackedVector2Array()

	func _init(rng: RandomNumberGenerator, at: Vector2, deep: float, run_low: float, run_high: float, planes: Vector2i) -> void:
		apex = at
		depth = deep
		var count := rng.randi_range(planes.x,planes.y)
		var turn := rng.randf()*TAU
		for k in range(count):
			var way := Vector2.from_angle(turn+TAU*(k+rng.randf_range(-0.3,0.3))/count)
			slopes.append(way/rng.randf_range(run_low,run_high))

	## Its depth under `p`, 0 beyond its planes.
	func depth_at(p: Vector2) -> float:
		var out := 0.0
		for slope in slopes: out = maxf(out,(p-apex).dot(slope))
		return maxf(depth*(1.0-out),0.0)

static func _hash(i: int, salt: int) -> float:
	return float(hash([i,salt,"shore"])%10000)/10000.0
