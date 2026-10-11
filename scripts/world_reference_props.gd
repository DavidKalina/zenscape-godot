extends RefCounted
const Plate = preload("res://scripts/plate.gd")
## Upgrade legacy reference scenery into ordinary saved object records once.
## Individual source parts are suppressed only after a replacement is accepted.
## The editor (scripts/native_chunk_editor.gd) is passed in untyped: the
## land's data (scripts/native_terrain_data.gd) checks `valid` here, and the
## isles read that data without reaching the editor.
const GROUPS := {
	"tree":["mesh-8","mesh-9"], "broadleaf":["mesh-11","broadleaf-canopies"],
	"log":["logs"], "stump":["stumps"], "snag":["snags"],
	"boulder_1":["mesh-4"], "boulder_2":["mesh-5"], "boulder_3":["mesh-6"], "boulder_4":["mesh-7"]
}
static func valid(value: Variant) -> bool:
	if not value is Array or value.size()>20000: return false
	var names := []
	for group in GROUPS.values(): names.append_array(group)
	for key in value:
		if not key is String: return false
		var pair: PackedStringArray = key.split(":")
		if pair.size()!=2 or pair[0] not in names or not pair[1].is_valid_int() or int(pair[1]) < 0 or int(pair[1])>20000: return false
	return true

static func migrate(editor: Node) -> bool:
	if editor.data.blank: return false
	var changed := false
	var reference: Node = editor.scene.get_node("Reference")
	for kind in GROUPS:
		var names: Array = GROUPS[kind]
		var node: Node3D = reference.get_node(names[0])
		var count: int = node.multimesh.instance_count if node is MultiMeshInstance3D else 1
		for i in range(count):
			if "%s:%d" % [names[0],i] in editor.data.source_replacements: continue
			var source_pose: Transform3D = node.global_transform*(node.multimesh.get_instance_transform(i) if node is MultiMeshInstance3D else Transform3D.IDENTITY)
			var mesh: Mesh = node.multimesh.mesh if node is MultiMeshInstance3D else node.mesh
			var pivot := Transform3D.IDENTITY if kind == "tree" else NativeAssetCatalog.part_pose(kind+":"+names[0],node,mesh)
			var record_pose: Transform3D = editor.terrain.global_transform.affine_inverse()*source_pose*pivot.affine_inverse()
			var point := Vector2(record_pose.origin.x,record_pose.origin.z)
			var ground: Variant = editor.data.ground_height(point)
			if ground == null or absf(point.x)>Plate.HALF or absf(point.y)>Plate.HALF: continue
			var pose := NativeObjectPose.make(record_pose.basis,record_pose.origin.y-ground)
			var color_node: Node3D = reference.get_node(names[-1])
			var tint := ""
			if color_node is MultiMeshInstance3D and color_node.multimesh.use_colors and i<color_node.multimesh.instance_count:
				tint = NativeObjectPose.encode_tint(color_node.multimesh.get_instance_color(i))
			var id: int = editor.data.place(kind,point,0.0,clampf(record_pose.basis.get_scale().x,0.1,5.0),pose,tint)
			if id < 0: continue
			for name in names: editor.data.source_replacements.append("%s:%d" % [name,i])
			changed = true
	return changed

static func hide_replaced(editor: Node) -> void:
	if editor.data.source_replacements.is_empty(): return
	var reference: Node = editor.scene.get_node("Reference")
	var groups: Dictionary = editor.get_meta("play_source_groups",{})
	if groups.is_empty():
		for key in editor.data.source_replacements:
			var pair: PackedStringArray = key.split(":")
			if not groups.has(pair[0]): groups[pair[0]] = []
			groups[pair[0]].append(int(pair[1]))
		editor.set_meta("play_source_groups",groups)
	for name in groups:
		var node: Node3D = reference.get_node(name)
		if node is MultiMeshInstance3D:
			if node.has_meta("play_private_multimesh") and node.get_meta("play_private_multimesh") == node.multimesh and node.get_meta("play_hidden_applied",false): continue
			# Never mutate the imported resource reused by another scene/world.
			if not node.has_meta("play_private_multimesh") or node.get_meta("play_private_multimesh") != node.multimesh: node.multimesh = node.multimesh.duplicate()
			node.set_meta("play_private_multimesh",node.multimesh)
			node.set_meta("play_hidden_applied",true)
			for index in groups[name]:
				if index<node.multimesh.instance_count: node.multimesh.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
		elif node.visible: node.hide()

static func before_refresh(editor: Node) -> void:
	if editor.has_meta("play_source_groups"): editor.remove_meta("play_source_groups")
	var reference: Node = editor.scene.get_node("Reference")
	for names in GROUPS.values():
		for name in names:
			var node := reference.get_node(name)
			if node.has_meta("play_hidden_applied"): node.set_meta("play_hidden_applied",false)
