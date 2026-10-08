extends RefCounted
## The lower world's islands drawn by how far off they stand (scripts/
## sky_archipelago.gd), so a sea of eighty islands in view costs what the
## eye can see of it. Under the cloud the air takes most of a thing by
## five hundred metres (scripts/sky_haze.gd, thickest by the ocean), so
## past where the grain shows each island draws less:
##   the top: past TOP_FAR m a coarse copy of it (`coarse`) takes over, its
##     grid merged COARSE steps to a cell, its rim kept as it was so it
##     still meets the shore wall. The swap is a plain one at TOP_FAR: a
##     crossfade would draw both tops see-through for the while, under the
##     clear sea, and a low island would sink from sight in it; and play
##     each way (a margin) can leave neither drawn;
##   the plants: each kind draws out to a range by its size in the world
##     (`sight`): a grass tuft or a flower only near, a sunflower further, a
##     tree by its height, the giants furthest; past a tree's range its
##     stand-in (scripts/far_trees.gd) takes over, out to FAR_END, by when
##     the air has all but taken the island.
## Only the lower world's islands are drawn so; the sky's islets keep their
## own ranges (scripts/sky_islets.gd).

const FarTrees = preload("res://scripts/far_trees.gd")

## The coarse top: past TOP_FAR m (to the island's middle), its cells
## COARSE grid steps across.
const TOP_FAR := 280.0
const COARSE := 2.0
## Depths under the sea (m) the coarse top keeps its points apart at.
const AWASH := [0.0,0.3,1.0,3.0]
## How far each kind draws: its height in the world (m, the batch's mean)
## times SIGHT, within NEAR (m), plus a share of the island's reach
## (REACH_SHARE), since the range is to the island's middle.
const SIGHT := {"tree":16.0,"build":40.0,"stone":120.0,"plant":160.0}
const NEAR := {"tree":Vector2(100.0,260.0),"build":Vector2(120.0,260.0),"stone":Vector2(60.0,320.0),"plant":Vector2(40.0,170.0)}
const REACH_SHARE := 0.5
## The near batches' crossfade (m), as the islets' (SkyIslets `_plant`).
const MARGIN := 30.0
## The stand-ins draw out to FAR_END m, fading over FAR_MARGIN.
const FAR_END := 520.0
const FAR_MARGIN := 80.0

## The range a batch of part `key` draws to: its role's SIGHT times its
## height in the world, within its NEAR, plus REACH_SHARE of the island's
## `reach`. `mesh` is the part's, `buffer` its instances (MultiMesh
## TRANSFORM_3D with colours).
static func sight(role: String, mesh: Mesh, buffer: PackedFloat32Array, count: int, reach: float) -> float:
	var height := mesh.get_aabb().size.y*mean_scale(buffer,count)
	var near: Vector2 = NEAR.get(role,NEAR.plant)
	return clampf(height*float(SIGHT.get(role,SIGHT.plant)),near.x,near.y)+reach*REACH_SHARE

## The mean upward scale of `count` instances in a MultiMesh buffer
## (TRANSFORM_3D, with colours: 16 floats each).
static func mean_scale(buffer: PackedFloat32Array, count: int) -> float:
	var stride := 16
	if count <= 0 or buffer.size() < count*stride: return 1.0
	var total := 0.0
	for i in range(count):
		var o := i*stride
		total += Vector3(buffer[o+1],buffer[o+5],buffer[o+9]).length()
	return total/count

## Sets the ranges of an island's plant batches stood under `node` (SkyIslets
## `stand`): `plants` its flora, `catalog` the islets' catalog, `reach` the
## island's reach (m). A tree's stand-ins take over where it stops.
static func range_plants(node: Node3D, plants: Dictionary, catalog: Dictionary, reach: float) -> void:
	var meshes: Dictionary = catalog.meshes
	for key: String in plants:
		if not meshes.has(key): continue
		var batch := node.get_node_or_null(NodePath(key.replace(":","_"))) as GeometryInstance3D
		if batch == null: continue
		var role: String = catalog.roles.get(key,"plant")
		var end := sight(role,meshes[key],plants[key].buffer,int(plants[key].count),reach)
		batch.visibility_range_end = end
		batch.visibility_range_end_margin = MARGIN
		var far := node.get_node_or_null(NodePath("Far_"+key.replace(":","_"))) as GeometryInstance3D
		if far == null: continue
		far.visibility_range_begin = end
		far.visibility_range_begin_margin = MARGIN
		far.visibility_range_end = FAR_END
		far.visibility_range_end_margin = FAR_MARGIN

## Stands the coarse top (`arrays`, as `coarse` gives them) under `node`
## by its fine one (`body`, SkyIslets `stand`'s Body), wearing its
## material: the fine draws to TOP_FAR, the coarse from there.
static func stand_top(node: Node3D, body: MeshInstance3D, arrays: Array) -> MeshInstance3D:
	if arrays.is_empty(): return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,body.mesh.surface_get_material(0))
	var far := MeshInstance3D.new()
	far.name = "BodyFar"
	far.mesh = mesh
	far.position = body.position
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far.set_meta("skip_reflection",true)
	far.visibility_range_begin = TOP_FAR
	body.visibility_range_end = TOP_FAR
	node.add_child(far)
	return far

## A triangle list's coarse copy: its points merged into cells `cell` m
## across (vertex clustering), each cell's one point their mean, faces
## that close up dropped and those left twice kept once. The points on an
## open edge (the rim, a hole's edge) are kept where they are, so the
## coarse top meets what the fine one met. Each face keeps its own colour
## (a top's colour is its face's); normals, UVs and custom data are each
## cell's mean. Points over and under any of `levels` (the waters'
## heights in the mesh: the sea's, a lake's) never share a cell, so a low
## shore stays out of the water and the bed under it. Safe on a worker.

## The waters' heights an island's top must keep its land over (`coarse`):
## the sea's at its foot (and AWASH under it, so land lying just awash on
## a low shore, which the clear water shows, is never merged down into the
## shelf's bed), and its pond's, lake's or stream's.
static func levels_of(shape: RefCounted) -> Array:
	var out := []
	var foot: Dictionary = shape.recipe.get("sea_foot",{})
	if foot.has("level"):
		for depth: float in AWASH: out.append(float(foot.level)-depth)
	if shape.pond.z > 0.0 or not shape.lake.is_empty() or not shape.stream.is_empty(): out.append(float(shape.water_level))
	return out
static func coarse(arrays: Array, cell: float, levels: Array = []) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n := vertices.size()
	if n < 3 or cell <= 0.0: return arrays
	# One id a distinct point.
	var weld := {}
	var ids := PackedInt32Array()
	ids.resize(n)
	var count := 0
	for i in range(n):
		var q := Vector3i((vertices[i]*1000.0).round())
		var id: int = weld.get(q,-1)
		if id < 0:
			id = count
			weld[q] = id
			count += 1
		ids[i] = id
	# An edge not shared by exactly two faces is open: its points stay.
	var edges := {}
	for f in range(0,n-2,3):
		for k in range(3):
			var a := ids[f+k]
			var b := ids[f+(k+1)%3]
			var key := mini(a,b)*count+maxi(a,b)
			edges[key] = int(edges.get(key,0))+1
	var fixed := PackedByteArray()
	fixed.resize(count)
	for key: int in edges:
		if edges[key] == 2: continue
		fixed[key/count] = 1
		fixed[key%count] = 1
	# Each point's cell: its own if fixed, else the cell it falls in.
	var of := PackedInt32Array()
	of.resize(count)
	var first := PackedInt32Array()
	first.resize(count)
	first.fill(-1)
	for i in range(n):
		if first[ids[i]] < 0: first[ids[i]] = i
	var cells := {}
	var clusters := 0
	var offset := Vector3.ONE*cell*0.25
	for id in range(count):
		var key: Variant = -1-id
		if fixed[id] == 0:
			var p := vertices[first[id]]
			var g := Vector3i(((p+offset)/cell).floor())
			var side := 0
			for k in range(levels.size()):
				if p.y < float(levels[k]): side |= 1 << k
			key = Vector4i(g.x,g.y,g.z,side)
		var c: int = cells.get(key,-1)
		if c < 0:
			c = clusters
			cells[key] = c
			clusters += 1
		of[id] = c
	# Each cell's means.
	var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
	var has_normals := normals is PackedVector3Array and (normals as PackedVector3Array).size() == n
	var spot := PackedVector3Array()
	spot.resize(clusters)
	var turn := PackedVector3Array()
	turn.resize(clusters)
	var weight := PackedFloat32Array()
	weight.resize(clusters)
	for id in range(count):
		var c := of[id]
		spot[c] += vertices[first[id]]
		if has_normals: turn[c] += (normals as PackedVector3Array)[first[id]]
		weight[c] += 1.0
	for c in range(clusters):
		spot[c] /= weight[c]
		if has_normals: turn[c] = turn[c].normalized()
	var uv := _mean2(arrays[Mesh.ARRAY_TEX_UV],n,count,clusters,first,of,weight)
	var uv2 := _mean2(arrays[Mesh.ARRAY_TEX_UV2],n,count,clusters,first,of,weight)
	var custom0 := _mean4(arrays[Mesh.ARRAY_CUSTOM0],n,count,clusters,first,of,weight)
	var custom1 := _mean4(arrays[Mesh.ARRAY_CUSTOM1],n,count,clusters,first,of,weight)
	# The faces left: none closed up, none twice.
	var colors: Variant = arrays[Mesh.ARRAY_COLOR]
	var has_colors := colors is PackedColorArray and (colors as PackedColorArray).size() == n
	var source_colors: PackedColorArray = colors if has_colors else PackedColorArray()
	var corners := PackedInt32Array()
	var out_colors := PackedColorArray()
	var seen := {}
	for f in range(0,n-2,3):
		var a := of[ids[f]]
		var b := of[ids[f+1]]
		var c := of[ids[f+2]]
		if a == b or b == c or a == c: continue
		var lo := mini(a,mini(b,c))
		var hi := maxi(a,maxi(b,c))
		var face := Vector3i(lo,a+b+c-lo-hi,hi)
		if seen.has(face): continue
		seen[face] = true
		corners.append(a)
		corners.append(b)
		corners.append(c)
		if has_colors:
			for k in range(3): out_colors.append(source_colors[f+k])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = _pick3(spot,corners)
	if has_normals: out[Mesh.ARRAY_NORMAL] = _pick3(turn,corners)
	if has_colors: out[Mesh.ARRAY_COLOR] = out_colors
	if not uv.is_empty(): out[Mesh.ARRAY_TEX_UV] = _pick2(uv,corners)
	if not uv2.is_empty(): out[Mesh.ARRAY_TEX_UV2] = _pick2(uv2,corners)
	if not custom0.is_empty(): out[Mesh.ARRAY_CUSTOM0] = _pick4(custom0,corners)
	if not custom1.is_empty(): out[Mesh.ARRAY_CUSTOM1] = _pick4(custom1,corners)
	return out

## Each cell's mean of a per-point Vector2 array (empty if there is none).
static func _mean2(source: Variant, n: int, count: int, clusters: int, first: PackedInt32Array, of: PackedInt32Array, weight: PackedFloat32Array) -> PackedVector2Array:
	var sums := PackedVector2Array()
	if not source is PackedVector2Array or (source as PackedVector2Array).size() != n: return sums
	var values: PackedVector2Array = source
	sums.resize(clusters)
	for id in range(count): sums[of[id]] += values[first[id]]
	for c in range(clusters): sums[c] /= weight[c]
	return sums

## The same of a four-float custom array.
static func _mean4(source: Variant, n: int, count: int, clusters: int, first: PackedInt32Array, of: PackedInt32Array, weight: PackedFloat32Array) -> PackedFloat32Array:
	var sums := PackedFloat32Array()
	if not source is PackedFloat32Array or (source as PackedFloat32Array).size() != n*4: return sums
	var values: PackedFloat32Array = source
	sums.resize(clusters*4)
	for id in range(count):
		for k in range(4): sums[of[id]*4+k] += values[first[id]*4+k]
	for c in range(clusters):
		for k in range(4): sums[c*4+k] /= weight[c]
	return sums

static func _pick3(values: PackedVector3Array, corners: PackedInt32Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(corners.size())
	for i in range(corners.size()): out[i] = values[corners[i]]
	return out

static func _pick2(values: PackedVector2Array, corners: PackedInt32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(corners.size())
	for i in range(corners.size()): out[i] = values[corners[i]]
	return out

static func _pick4(values: PackedFloat32Array, corners: PackedInt32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(corners.size()*4)
	for i in range(corners.size()):
		for k in range(4): out[i*4+k] = values[corners[i]*4+k]
	return out
