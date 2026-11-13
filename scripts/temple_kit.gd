extends RefCounted
## The temple kit (docs/design/temple-kit/spec-temple-kit.md): pieces of a
## classical temple ruin modelled in Blender (art/blender/temple_kit/), one
## .glb each under assets/models/temple_kit/, drawn with one stone shader.
##
##   const TempleKit = preload("res://scripts/temple_kit.gd")
##   var col: Node3D = TempleKit.piece(&"column")     # Mesh + Far children
##   var solids: Array[AABB] = TempleKit.boxes(&"column")
##   var m: Mesh = TempleKit.mesh(&"column")           # for a MultiMesh
##
## A piece's origin is on the ground at its snap point; column centres sit
## on a BAY grid. The numbers are temple_lib.py's (the spec's contract).

## Every piece the kit has; a lane adds its ids here and the gallery shows them.
const PIECES: Array[StringName] = [&"column",
	&"podium",
	&"podium_corner",
	&"podium_stair",
]

const DIR := "res://assets/models/temple_kit/"
const MATERIAL_SHADER := preload("res://shaders/temple_stone.gdshader")

## The contract (temple_lib.py), metres.
const BAY := 18.5
const COLUMN_D := 4.0
const COLUMN_H := 30.5
const ENTABLATURE_H := 7.5
const STEP_H := 1.0
const STEP_TREAD := 1.6
const PODIUM_H := 3.0
const WALL_T := 2.4
const COURSE_H := 1.25

## Where a piece swaps to its far LOD (m from the camera).
const FAR_AT := 170.0

static var _meshes := {}
static var _boxes := {}
static var _material: ShaderMaterial

## The kit's one stone material.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = MATERIAL_SHADER
	return _material

## A piece's mesh (`far` its LOD), loaded once from its .glb.
static func mesh(id: StringName, far := false) -> Mesh:
	var key := String(id)+("_far" if far else "")
	if not _meshes.has(key): _load(id)
	return _meshes.get(key)

static func _load(id: StringName) -> void:
	var scene: PackedScene = load(DIR+String(id)+".glb")
	if scene == null:
		push_error("temple_kit: no model for %s" % id)
		return
	var root := scene.instantiate()
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mi := node as MeshInstance3D
		var far := mi.name.ends_with("_far")
		var m: Mesh = mi.mesh.duplicate()
		for s in m.get_surface_count(): m.surface_set_material(s,material())
		_meshes[String(id)+("_far" if far else "")] = m
	root.free()

## A piece as a Node3D: a `Mesh` child drawn near, a `Far` child past FAR_AT.
static func piece(id: StringName) -> Node3D:
	var node := Node3D.new()
	node.name = String(id)
	var near := MeshInstance3D.new()
	near.name = "Mesh"
	near.mesh = mesh(id)
	near.visibility_range_end = FAR_AT
	node.add_child(near)
	var far_mesh := mesh(id,true)
	if far_mesh != null:
		var far := MeshInstance3D.new()
		far.name = "Far"
		far.mesh = far_mesh
		far.visibility_range_begin = FAR_AT
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(far)
	return node

## The piece's solids in its own frame, written by the Blender export
## (<piece>.boxes.json beside the model).
static func boxes(id: StringName) -> Array[AABB]:
	if not _boxes.has(id):
		var out: Array[AABB] = []
		var text := FileAccess.get_file_as_string(DIR+String(id)+".boxes.json")
		var data: Variant = JSON.parse_string(text)
		if data is Dictionary:
			for b in (data as Dictionary).get("boxes",[]):
				var a: Array = b
				out.append(AABB(Vector3(a[0],a[1],a[2]),Vector3(a[3],a[4],a[5])))
		else: push_error("temple_kit: no boxes for %s" % id)
		_boxes[id] = out
	return _boxes[id]
