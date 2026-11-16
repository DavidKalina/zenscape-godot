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
	# The colonnaded street (art/blender/temple_kit/street_build.py; scripts/endless/street_site.gd).
	&"street_kerb",
	&"street_paving",
	&"street_paving_broken",
	&"street_arch",
	&"street_lintel_cross",
	&"street_stump",
	# The agora (art/blender/temple_kit/agora_build.py; scripts/endless/agora_site.gd).
	&"agora_stoa_wall",
	&"agora_stoa_roof",
	&"agora_stoa_roof_broken",
	&"agora_roof_rubble",
	&"agora_gate",
	&"agora_paving",
	&"agora_paving_broken",
	&"agora_altar",
	&"agora_plinth",
	&"agora_drum",
	# The round temple (art/blender/temple_kit/tholos_build.py; scripts/endless/tholos_site.gd).
	&"tholos_base",
	&"tholos_lintel",
	&"tholos_lintel_l",
	&"tholos_lintel_r",
	# The theatre (art/blender/temple_kit/theatre_build.py; scripts/endless/theatre_site.gd).
	&"theatre_seat_0",
	&"theatre_seat_1",
	&"theatre_seat_2",
	&"theatre_seat_3",
	&"theatre_seat_4",
	&"theatre_seat_broken_0",
	&"theatre_seat_broken_1",
	&"theatre_seat_broken_2",
	&"theatre_seat_broken_3",
	&"theatre_seat_broken_4",
	&"theatre_rim",
	&"theatre_stage_mid",
	&"theatre_stage_door",
	&"theatre_stage_wall",
	&"theatre_stage_end",
	&"theatre_stage_fallen",
	&"theatre_side_arch",
	# The amphitheatre (art/blender/temple_kit/arena_build.py; scripts/endless/arena_site.gd).
	&"arena_outer",
	&"arena_outer_broken",
	&"arena_upper",
	&"arena_upper_broken",
	&"arena_inner_a",
	&"arena_inner_b",
	&"arena_vault_a",
	&"arena_vault_b",
	&"arena_vault_broken_a",
	&"arena_vault_broken_b",
	&"arena_seats_a",
	&"arena_seats_b",
	&"arena_seats_broken_a",
	&"arena_seats_broken_b",
	&"arena_fallen",
	# The bath house (art/blender/temple_kit/baths_build.py; scripts/endless/baths_site.gd).
	&"baths_rotunda",
	&"baths_rotunda_cut",
	&"baths_dome",
	&"baths_floor",
	&"baths_hall",
	&"baths_hall_broken",
	&"baths_hall_end",
	&"baths_rubble",
	&"baths_fragment",
	# The hillside sanctuary (art/blender/temple_kit/sanctuary_build.py; scripts/endless/sanctuary_site.gd).
	&"sanctuary_wall",
	&"sanctuary_wall_burst",
	&"sanctuary_wall_stump",
	&"sanctuary_wall_cracked",
	&"sanctuary_wall_holed",
	&"sanctuary_arch",
	&"sanctuary_arch_broken",
	&"sanctuary_slot_open",
	&"sanctuary_deck",
	&"sanctuary_deck_broken",
	&"sanctuary_stair",
	&"sanctuary_stair_arch",
	&"sanctuary_spill",
	# The citadel (art/blender/temple_kit/citadel_build.py; scripts/endless/citadel_site.gd).
	&"citadel_wall",
	&"citadel_wall_gallery",
	&"citadel_wall_end",
	&"citadel_wall_low",
	&"citadel_rubble",
	&"citadel_postern",
	&"citadel_blocking",
	&"citadel_blocking_cracked",
	&"citadel_blocking_left",
	&"citadel_tower_base",
	&"citadel_tower_storey",
	&"citadel_tower_crown",
	&"citadel_tower_ruin",
	&"citadel_tower_split",
	&"citadel_bastion",
	&"citadel_bastion_tall",
	&"citadel_gate",
	&"citadel_keep",
	&"citadel_cistern",
	# The road of tombs (art/blender/temple_kit/tombs_build.py; scripts/endless/tombs_site.gd).
	&"tombs_house",
	&"tombs_house_broken",
	&"tombs_tower",
	&"tombs_tower_cracked",
	&"tombs_tower_stump",
	&"tombs_exedra",
	&"tombs_pillar",
	&"tombs_sarcophagus",
	&"tombs_step",
	&"tombs_step_broken",
	&"tombs_arch_cracked",
	&"tombs_arch_broken",
	# The harbour (art/blender/temple_kit/harbour_build.py; scripts/endless/harbour_site.gd).
	&"harbour_colossus",
	&"harbour_colossus_head",
	&"harbour_colossus_arm",
	&"harbour_mole",
	&"harbour_mole_broken",
	&"harbour_quay",
	&"harbour_quay_steps",
	&"harbour_shed",
	&"harbour_shed_broken",
	&"harbour_shed_end",
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

static var _warm_at := 0

## Every piece in PIECES loaded ahead of use, on the main thread only, a few
## per call inside udget_usec (a call always loads at least one). True once
## all are in. The way sites hold their builds until then (way_towers.gd
## step), so a build's worker only ever reads the cache. A worker that loaded a
## model itself, holding _lock, hung the game when the main thread asked the
## kit for a mesh or waited for the worker at quit; and a model's meshes made
## off the main thread (a worker, or the engine's loader threads) broke RIDs
## in headless runs.
static func warm(budget_usec := 3000) -> bool:
	var t0 := Time.get_ticks_usec()
	while _warm_at < PIECES.size():
		var id := PIECES[_warm_at]
		_lock.lock()
		if not _meshes.has(String(id)): _load(id)
		_lock.unlock()
		_warm_at += 1
		if Time.get_ticks_usec()-t0 > budget_usec: break
	return _warm_at >= PIECES.size()

## A site's sets made into MultiMeshes under `root`, on the main thread: each
## set is [mesh, frames, box, name, Vector2(visible from, to)], gathered by the
## site's build on a worker. A MultiMesh made on the worker itself broke RIDs
## now and then (headless: "uninitialized RID", "multimesh is null").
static func fill(root: Node3D, sets: Array) -> void:
	for s: Array in sets:
		var xfs: Array = s[1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = s[0]
		mm.instance_count = xfs.size()
		for i in range(xfs.size()): mm.set_instance_transform(i,xfs[i])
		mm.custom_aabb = s[2]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = s[3]
		var span: Vector2 = s[4]
		mmi.visibility_range_begin = span.x
		mmi.visibility_range_end = span.y
		root.add_child(mmi)

static func _load(id: StringName) -> void:
	# A piece missing from PIECES isn't warmed, and loads here on whoever asks.
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		push_error("temple_kit: %s loaded on a worker; add it to PIECES so warm() loads it" % id)
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
