extends RefCounted
## The temple kit (docs/design/temple-kit/spec-temple-kit.md): pieces of a
## classical temple ruin modelled in Blender (art/blender/temple_kit/), one
## .glb each under assets/models/temple_kit/, drawn with one stone shader.
##
##   const TempleKit = preload("res://scripts/temple_kit.gd")
##   var col: Node3D = TempleKit.piece(&"column")     # Mesh (+ Mid) + Far children
##   var solids: Array[AABB] = TempleKit.boxes(&"column")
##   var m: Mesh = TempleKit.mesh(&"column")           # for a MultiMesh
##   var mid: Mesh = TempleKit.lod(&"column",TempleKit.MID)  # null without a mid
##
## LODs: NEAR is <id>.glb's mesh, FAR its `<id>_far` mesh, MID the one mesh
## in <id>_mid.glb when that file exists (a piece without one draws near
## until FAR_AT, as before). A new _mid.glb is picked up with no code change.
##
## A piece's origin is on the ground at its snap point; column centres sit
## on a BAY grid. The numbers are temple_lib.py's (the spec's contract).

## Every piece the kit has; a lane adds its ids here and the gallery shows them.
const PIECES: Array[StringName] = [
	&"column",
	&"column_broken",
	&"column_drums",
	&"lintel",
	&"lintel_broken",
	&"podium",
	&"podium_corner",
	&"podium_stair",
	&"podium_floor",
	&"wall_door",
	&"wall_broken",
	# The aqueduct (art/blender/temple_kit/aqueduct_build.py; scripts/endless/aqueduct_site.gd).
	&"aqueduct_pier",
	&"aqueduct_arch",
	&"aqueduct_arch_b",
	&"aqueduct_arch_broken",
	&"aqueduct_pier_broken",
	&"aqueduct_rubble",
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
## Where a piece with a mid swaps near -> mid (m): the trim lanes' stills read
## the same at 50 and 90 m and show the mid's facets at 30 m.
const MID_AT := 60.0

## LOD levels for lod().
enum {NEAR, MID, FAR}

static var _meshes := {}
static var _boxes := {}
static var _material: ShaderMaterial
## Held round every load: the way sites build on workers, several at once.
static var _lock := Mutex.new()

## The kit's one stone material.
static func material() -> ShaderMaterial:
	_lock.lock()
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = MATERIAL_SHADER
	_lock.unlock()
	return _material

## A piece's mesh (`far` its LOD), loaded once from its .glb.
static func mesh(id: StringName, far := false) -> Mesh:
	return lod(id,FAR if far else NEAR)

## A piece's mesh at one LOD (NEAR, MID, FAR); null when it has none (MID
## without a _mid.glb).
static func lod(id: StringName, level: int) -> Mesh:
	var key := String(id)+(["","_mid","_far"][level] as String)
	_lock.lock()
	if not _meshes.has(key): _load(id)
	var m: Mesh = _meshes.get(key)
	_lock.unlock()
	return m

## Whether the piece has a mid LOD (<id>_mid.glb).
static func has_mid(id: StringName) -> bool:
	return lod(id,MID) != null

static func _load(id: StringName) -> void:
	_meshes[String(id)] = null
	_meshes[String(id)+"_mid"] = null
	_meshes[String(id)+"_far"] = null
	var scene: PackedScene = load(DIR+String(id)+".glb")
	if scene == null:
		push_error("temple_kit: no model for %s" % id)
		return
	_take(scene,String(id),false)
	var mid_path := DIR+String(id)+"_mid.glb"
	if ResourceLoader.exists(mid_path):
		_take(load(mid_path) as PackedScene,String(id),true)

## Files a model's meshes under their keys (a _mid.glb's one mesh as `<id>_mid`).
static func _take(scene: PackedScene, id: String, mid: bool) -> void:
	if scene == null: return
	var root := scene.instantiate()
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mi := node as MeshInstance3D
		var key := id+("_mid" if mid else ("_far" if mi.name.ends_with("_far") else ""))
		var m: Mesh = mi.mesh.duplicate()
		for s in m.get_surface_count(): m.surface_set_material(s,material())
		_meshes[key] = m
	root.free()

## A piece as a Node3D: a `Mesh` child drawn near, a `Mid` child from MID_AT
## when the piece has one, a `Far` child past FAR_AT.
static func piece(id: StringName) -> Node3D:
	var node := Node3D.new()
	node.name = String(id)
	var mid_mesh := lod(id,MID)
	var near := MeshInstance3D.new()
	near.name = "Mesh"
	near.mesh = mesh(id)
	near.visibility_range_end = MID_AT if mid_mesh != null else FAR_AT
	node.add_child(near)
	if mid_mesh != null:
		var mid := MeshInstance3D.new()
		mid.name = "Mid"
		mid.mesh = mid_mesh
		mid.visibility_range_begin = MID_AT
		mid.visibility_range_end = FAR_AT
		node.add_child(mid)
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
	_lock.lock()
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
	var got: Array[AABB] = _boxes[id]
	_lock.unlock()
	return got
