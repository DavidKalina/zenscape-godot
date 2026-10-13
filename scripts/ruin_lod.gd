extends RefCounted
## Levels of detail for the ruin kit's built meshes (scripts/ruin_kit.gd
## "Mesh": the stone's surface and the growth's, scripts/ruin_growth.gd),
## added once a ruin is built (on its worker), so Godot's own mesh LOD draws
## less of what is far: picked per frame by how big a level's error stands
## on screen (rendering/mesh_lod/lod_change/threshold_pixels, 1 px), for the
## shadow map too. Nothing changes up close; nothing is rebuilt.
##
## - The stone: Godot's own simplifier (ImporterMesh `generate_lods`, as an
##   imported model gets), over the stone's faces welded where they already
##   share a corner, normal and colour.
## - The growth: its faces kept or let go whole, never reshaped. A face
##   group is a fan's triangles (`RuinGrowth.emit`: each face's triangles
##   share their first corner), a folded leaf its two. The thin ones (the
##   strands' three-sided stems, ribbons and curls, a couple of centimetres
##   across) go first, once they are about a fifth of a pixel across; then the
##   leaves, mats and cushions are thinned to a share, by a fixed hash of
##   the group so the same ones stay, once each is well under a pixel.
##
## The levels' errors (m, the key Godot measures on screen): at 1080 lines
## and the walker's 70 degrees, 1 px is about 1.3 mm a metre away, so the
## stems go at about 115 m (dropped at 45 m, the vine curtains read as
## broken strings of dots in the before/after captures), the shares at
## about 230, 540 and 1200 m.
## docs/design/roguelike/perf-round1.md has the numbers.

const RuinGrowth = preload("res://scripts/ruin_growth.gd")

## A growth group is thin under this across (m) and this long for its width.
const THIN_WIDTH := 0.03
const THIN_ASPECT := 4.0
## [error (m), share of the other groups kept]; the first lets the thin go.
const GROWTH_LEVELS := [[0.15,1.0],[0.3,0.5],[0.7,0.25],[1.6,0.1]]
## The stone's simplifier: normals merged within this (degrees).
const STONE_MERGE_ANGLE := 25.0

## Every kit "Mesh" under `root` (and `root` itself) given its levels, once.
## Answers {meshes, stone (triangles), growth (triangles)}. Needs the
## arrays a built mesh keeps (meta "arrays", "growth_arrays"; RuinKit
## `forget_arrays` lets them go): a mesh without them is left as it is.
## Safe on a worker, as the build is.
static func add(root: Node) -> Dictionary:
	var stats := {"meshes":0,"stone":0,"growth":0}
	var found: Array = root.find_children("Mesh","MeshInstance3D",true,false)
	if root is MeshInstance3D and root.name == &"Mesh": found.append(root)
	for node: MeshInstance3D in found:
		var mesh := node.mesh as ArrayMesh
		if mesh == null or mesh.has_meta("lods"): continue
		var leveled := leveled_mesh(mesh)
		if leveled == null: continue
		node.mesh = leveled
		stats.meshes += 1
		stats.stone += int(leveled.get_meta("lods").stone)
		stats.growth += int(leveled.get_meta("lods").growth)
	return stats

## `add` for a ruin already in the tree, off the main thread: its meshes'
## levels made on a worker, swapped in once all are made (a Node under
## `root` waits for them, then goes).
## Headless, at once: the dummy renderer's meshes aren't safe to make on a
## worker while the main thread makes its own (scripts/kit_isle/
## motif_isle.gd, godot#124183).
static func add_async(root: Node) -> void:
	if DisplayServer.get_name() == "headless":
		add(root)
		return
	var nodes: Array = root.find_children("Mesh","MeshInstance3D",true,false)
	var meshes: Array = nodes.map(func(n: MeshInstance3D) -> Mesh: return n.mesh)
	var swap := Swap.new()
	swap.name = "LodSwap"
	swap.nodes = nodes
	swap.meshes = meshes
	swap.task = WorkerThreadPool.add_task(func() -> void:
		var out: Array = []
		for mesh: Mesh in meshes: out.append(leveled_mesh(mesh) if mesh is ArrayMesh and not mesh.has_meta("lods") else null)
		swap.made = out,false,"Ruin LODs")
	root.add_child(swap)

class Swap extends Node:
	var nodes: Array
	var meshes: Array
	var made: Array = []
	var task := -1
	func _process(_delta: float) -> void:
		if task < 0 or not WorkerThreadPool.is_task_completed(task): return
		WorkerThreadPool.wait_for_task_completion(task)
		task = -1
		for i in range(made.size()):
			var node: MeshInstance3D = nodes[i]
			if made[i] != null and is_instance_valid(node) and node.mesh == meshes[i]: node.mesh = made[i]
		queue_free()
	func _exit_tree() -> void:
		if task >= 0:
			WorkerThreadPool.wait_for_task_completion(task)
			task = -1

## `mesh` again with its levels (its surfaces, materials and kept arrays as
## they were), or null if it isn't a kit mesh with its arrays kept.
static func leveled_mesh(mesh: ArrayMesh) -> ArrayMesh:
	var growth_material: Material = RuinGrowth.material()
	var stone: Array = mesh.get_meta("arrays",[])
	var growth: Array = mesh.get_meta("growth_arrays",[])
	var count := mesh.get_surface_count()
	if count == 0 or count > 2: return null
	var out := ArrayMesh.new()
	var info := {"stone":0,"growth":0}
	for i in range(count):
		var material := mesh.surface_get_material(i)
		var is_growth := material == growth_material
		var arrays: Array = growth if is_growth else stone
		if arrays.is_empty() or arrays[Mesh.ARRAY_INDEX] != null: return null
		var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if n != mesh.surface_get_array_len(i): return null
		if is_growth:
			var withindex := arrays.duplicate()
			var index := PackedInt32Array()
			index.resize(n)
			for k in range(n): index[k] = k
			withindex[Mesh.ARRAY_INDEX] = index
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,withindex,[],growth_lods(arrays[Mesh.ARRAY_VERTEX]),RuinGrowth.FORMAT)
			info.growth += n/3
		else:
			var weld := SurfaceTool.new()
			weld.create_from_arrays(arrays)
			weld.index()
			var importer := ImporterMesh.new()
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,weld.commit_to_arrays())
			importer.generate_lods(STONE_MERGE_ANGLE,60.0,[])
			var lods := {}
			for l in range(importer.get_surface_lod_count(0)):
				lods[importer.get_surface_lod_size(0,l)] = importer.get_surface_lod_indices(0,l)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,importer.get_surface_arrays(0),[],lods)
			info.stone += n/3
		out.surface_set_material(i,material)
	for key: StringName in mesh.get_meta_list(): out.set_meta(key,mesh.get_meta(key))
	out.set_meta("lods",info)
	return out

## The growth's levels as {error: indices}: whole face groups kept or let
## go (see the header).
static func growth_lods(v: PackedVector3Array) -> Dictionary:
	# The groups: runs of triangles sharing their first corner.
	var starts := PackedInt32Array()
	var thin := PackedByteArray()
	var tris := v.size()/3
	var k := 0
	while k < tris:
		var first := v[k*3]
		var end := k+1
		while end < tris and v[end*3] == first: end += 1
		var area := 0.0
		var longest := 0.0
		for t in range(k,end):
			var a := v[t*3]
			var b := v[t*3+1]
			var c := v[t*3+2]
			area += (b-a).cross(c-a).length()*0.5
			longest = maxf(longest,maxf((b-a).length(),maxf((c-b).length(),(a-c).length())))
		var width := area/maxf(longest,1e-6)
		starts.append(k)
		thin.append(1 if width < THIN_WIDTH and longest > width*THIN_ASPECT else 0)
		k = end
	starts.append(tris)
	var lods := {}
	for level: Array in GROWTH_LEVELS:
		var share: float = level[1]
		var index := PackedInt32Array()
		for g in range(starts.size()-1):
			if thin[g] == 1: continue
			if share < 1.0 and _hash(g) >= share: continue
			for t in range(starts[g],starts[g+1]):
				index.append_array([t*3,t*3+1,t*3+2])
		# A level no smaller than the last is no level.
		if index.size() >= tris*3 or (not lods.is_empty() and index.size() >= (lods.values()[-1] as PackedInt32Array).size()): continue
		if index.is_empty(): break
		lods[float(level[0])] = index
	return lods

## A fixed share (0..1) for group `g`.
static func _hash(g: int) -> float:
	var h := (g*2654435761) & 0xffffffff
	h = (h ^ (h >> 15))*2246822519 & 0xffffffff
	h = h ^ (h >> 13)
	return float(h % 10007)/10007.0
