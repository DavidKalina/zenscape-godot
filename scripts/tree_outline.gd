extends Node3D
## The golden outline round the tree under the pointer (docs/scenic/sky-cloud.md
## "Seeds"): a tree the hand could bend and flick. Gold when its spores are
## ready, a pale straw while it rests.
##
## Each of the tree's parts is drawn again as an inverted hull
## (shaders/tree_outline.gdshader), pushed out WIDTH pixels along smoothed
## normals so faceted meshes stay closed. The hull does not follow the tree's
## wind sway, so it is a pixel or two off at the crown in a strong wind.
##
## Owned by the hand's reach (scripts/hand_reach.gd `_outline_tree`).

## Pixels of outline, and seconds to fade in.
const WIDTH := 3.0
const FADE := 0.12
const READY := Color(1.0,0.76,0.24)
const RESTING := Color(0.82,0.76,0.56)

## The tree outlined (world play's object id), or -1.
var tree_id := -1
var spores_ready := true
var _shown := 0.0
var _nodes: Array[MeshInstance3D] = []
var _material: ShaderMaterial
static var _hulls := {}

func _ready() -> void:
	top_level = true
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/tree_outline.gdshader")

## Outline tree `id` from its `parts` ([{"mesh", "transform" (world)}]), or
## nothing for an id of -1.
func show_tree(id: int, parts: Array) -> void:
	tree_id = id
	if id <= 0: parts = []
	if parts.is_empty(): _shown = 0.0
	for i in range(maxi(parts.size(),_nodes.size())):
		if i >= parts.size():
			_nodes[i].visible = false
			continue
		if i >= _nodes.size():
			var node := MeshInstance3D.new()
			node.material_override = _material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.top_level = true
			add_child(node)
			_nodes.append(node)
		var part: Dictionary = parts[i]
		_nodes[i].mesh = _hull(part.mesh)
		_nodes[i].global_transform = part.transform
		_nodes[i].visible = true

func _process(delta: float) -> void:
	if tree_id <= 0: return
	_shown = minf(1.0,_shown+delta/FADE)
	_material.set_shader_parameter("colour",READY if spores_ready else RESTING)
	_material.set_shader_parameter("width",WIDTH*_shown)

## `mesh` with its normals smoothed across coincident vertices, built once.
static func _hull(mesh: Mesh) -> Mesh:
	if _hulls.has(mesh): return _hulls[mesh]
	var hull := ArrayMesh.new()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		if normals.size() != vertices.size(): continue
		var sums := {}
		for i in range(vertices.size()):
			var key := vertices[i].snapped(Vector3.ONE*0.001)
			sums[key] = sums.get(key,Vector3.ZERO)+normals[i]
		var smooth := PackedVector3Array()
		smooth.resize(vertices.size())
		for i in range(vertices.size()):
			var sum: Vector3 = sums[vertices[i].snapped(Vector3.ONE*0.001)]
			smooth[i] = sum.normalized() if sum.length_squared() > 1e-8 else normals[i]
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = vertices
		out[Mesh.ARRAY_NORMAL] = smooth
		out[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		hull.add_surface_from_arrays(mesh.surface_get_primitive_type(s),out)
	_hulls[mesh] = hull
	return hull
