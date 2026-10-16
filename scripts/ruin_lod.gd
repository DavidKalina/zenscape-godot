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
##
## Round 2: the growth is lifted out of the "Mesh" into
## its own instance under it ("Growth", the very levels above, so it looks as
## it did) drawn without casting shadows, and shadows-only twins ("Shade0",
## ...) in chunks GROWTH_CELL across, at full detail, each seen only within
## SHADOW_RANGE of the eye: far growth casts no shadow. SHADOW_RANGE is a knob
## (`shadow_range`, 0 for the old way: every shadow cast at every distance).

const RuinGrowth = preload("res://scripts/ruin_growth.gd")
const NativeIsleKernels = preload("res://scripts/native_isle_kernels.gd")

## A growth group is thin under this across (m) and this long for its width.
const THIN_WIDTH := 0.03
const THIN_ASPECT := 4.0
## [error (m), share of the other groups kept]; the first lets the thin go.
const GROWTH_LEVELS := [[0.15,1.0],[0.3,0.5],[0.7,0.25],[1.6,0.1]]
## Growth chunks are about this wide (m), by the groups' first corners.
const GROWTH_CELL := 24.0
## Growth casts shadows only within this of the eye (m), measured to a
## chunk's middle.
const SHADOW_RANGE := 40.0
## The range in force (m); 0 leaves the growth casting its shadows as it
## did (one instance, the levels for the shadow map too).
static var shadow_range := _shadow_arg()

## `--growth-shadow-range=M` on the command line (0: the old way).
static func _shadow_arg() -> float:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--growth-shadow-range="): return float(a.trim_prefix("--growth-shadow-range="))
	return SHADOW_RANGE
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
		attach(node,leveled)
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

## `node` given the levelled `mesh` (its stone), and its growth chunks as
## instances under it.
static func attach(node: MeshInstance3D, mesh: ArrayMesh) -> void:
	node.mesh = mesh
	if not mesh.has_meta("growth_mesh"): return
	var grown: ArrayMesh = mesh.get_meta("growth_mesh")
	var colour := MeshInstance3D.new()
	colour.name = "Growth"
	colour.mesh = grown
	node.add_child(colour)
	var chunks: Array = mesh.get_meta("shade_chunks",[])
	if chunks.is_empty(): return
	colour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(chunks.size()):
		var shade := MeshInstance3D.new()
		shade.name = "Shade"+str(i)
		shade.mesh = chunks[i]
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shade.visibility_range_end = shadow_range
		node.add_child(shade)

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
			if made[i] != null and is_instance_valid(node) and node.mesh == meshes[i]: load("res://scripts/ruin_lod.gd").attach(node,made[i])
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
	var growth_mesh: ArrayMesh = null
	var shade: Array = []
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
			var levels := {}
			# The native kernel's index and levels are these loops'
			# (native/terrain_kernels/isle_kernels.h `growth_levels`).
			var kernel: Object = NativeIsleKernels.get_kernel()
			if kernel != null:
				var made: Dictionary = kernel.growth_levels(arrays[Mesh.ARRAY_VERTEX],GROWTH_LEVELS,THIN_WIDTH,THIN_ASPECT)
				index = made.index
				levels = made.lods
			else:
				index.resize(n)
				for k in range(n): index[k] = k
				levels = growth_lods(arrays[Mesh.ARRAY_VERTEX])
			withindex[Mesh.ARRAY_INDEX] = index
			var grown := ArrayMesh.new()
			grown.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,withindex,[],levels,RuinGrowth.FORMAT)
			grown.surface_set_material(0,material)
			growth_mesh = grown
			if shadow_range > 0.0: shade = shade_chunks(arrays)
			info.growth += n/3
			continue
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
		out.surface_set_material(out.get_surface_count()-1,material)
	if growth_mesh != null: out.set_meta("growth_mesh",growth_mesh)
	out.set_meta("shade_chunks",shade)
	for key: StringName in mesh.get_meta_list(): out.set_meta(key,mesh.get_meta(key))
	out.set_meta("lods",info)
	return out

## The growth `arrays` (one surface's) as shadow meshes, no levels: its
## face groups binned by their first corner into cells GROWTH_CELL wide (one
## mesh when it all lies within about a cell and a half), each a surface of
## the surface's own arrays, in the growth's format.
static func shade_chunks(arrays: Array) -> Array:
	# The native kernel splits the arrays as below (isle_kernels.h `growth_chunks`).
	var kernel: Object = NativeIsleKernels.get_kernel()
	if kernel != null:
		var meshes: Array = []
		for part: Array in kernel.growth_chunks(arrays,GROWTH_CELL):
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part,[],{},RuinGrowth.FORMAT)
			mesh.surface_set_material(0,RuinGrowth.material())
			meshes.append(mesh)
		return meshes
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var groups := _groups(v)
	var starts: PackedInt32Array = groups[0]
	var box := AABB(v[0],Vector3.ZERO)
	for q in v: box = box.expand(q)
	var bins := {}
	var one := box.size.x < GROWTH_CELL*1.5 and box.size.z < GROWTH_CELL*1.5 and box.size.y < GROWTH_CELL*1.5
	for g in range(starts.size()-1):
		var key := Vector3i.ZERO
		if not one:
			var at := v[starts[g]*3]
			key = Vector3i(floori(at.x/GROWTH_CELL),floori(at.y/GROWTH_CELL),floori(at.z/GROWTH_CELL))
		if not bins.has(key): bins[key] = []
		bins[key].append(g)
	var keys := bins.keys()
	keys.sort()
	var out: Array = []
	for key: Vector3i in keys:
		var picked: Array = bins[key]
		# The chunk's arrays: each per-vertex array's rows for its groups.
		var part := []
		part.resize(Mesh.ARRAY_MAX)
		for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_CUSTOM0]:
			if arrays[slot] != null: part[slot] = arrays[slot].duplicate() if one else _rows(arrays[slot],picked,starts,4 if slot == Mesh.ARRAY_CUSTOM0 else 1)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part,[],{},RuinGrowth.FORMAT)
		mesh.surface_set_material(0,RuinGrowth.material())
		out.append(mesh)
	return out

## `source`'s rows (`width` values a vertex) for the triangles of `picked`
## groups (`starts` are triangle indices).
static func _rows(source: Variant, picked: Array, starts: PackedInt32Array, width: int) -> Variant:
	var out: Variant = source.duplicate()
	out.clear()
	for g: int in picked:
		var a := starts[g]*3*width
		var b := starts[g+1]*3*width
		out.append_array(source.slice(a,b))
	return out

## [group starts (triangle indices, then the end), thin flags]: a growth
## group is a fan's triangles (they share their first corner).
static func _groups(v: PackedVector3Array) -> Array:
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
	return [starts,thin]

## The growth's levels as {error: indices}: whole face groups kept or let
## go (see the header).
static func growth_lods(v: PackedVector3Array) -> Dictionary:
	var groups := _groups(v)
	var starts: PackedInt32Array = groups[0]
	var thin: PackedByteArray = groups[1]
	var tris := v.size()/3
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
