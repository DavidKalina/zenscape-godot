extends RefCounted
signal delivered(kind: String, source_id: String)
## Owns one gathered object from grasp through the cave threshold. The source
## remains responsible for restoring an uncommitted object on cancellation.
var routine: Node
var scene: Node
var kind := ""
var source_id := ""
var held: Node3D
var release_source := Callable()
var commit_source := Callable()

func setup(owner_routine: Node) -> void:
	routine = owner_routine
	scene = routine.scene
	_install_carry_clip()
	routine.cave.entry_completed.connect(_cave_entry_completed)
	routine.cave.cancelled.connect(_cave_cancelled)

func _install_carry_clip() -> void:
	var library: AnimationLibrary = scene.creature.player.get_animation_library("")
	if library.has_animation("LogCarry"): return
	var source := preload("res://assets/models/zenscape-bigfoot-log.glb").instantiate()
	var source_player: AnimationPlayer = source.find_child("AnimationPlayer",true,false)
	var animation: Animation = source_player.get_animation("LogCarry").duplicate()
	animation.loop_mode = Animation.LOOP_LINEAR
	library.add_animation("LogCarry",animation)
	source.free()
	# Register the newly available original before the personality library swaps
	# in its matching authored carry variant.
	scene.creature.install_action_personality()

func carrying() -> bool:
	return is_instance_valid(held)

## Returns true only after a valid lair route has accepted ownership.
func begin(item_kind: String, item_id: String, visual: Node3D, release: Callable = Callable(), commit: Callable = Callable()) -> bool:
	if carrying() or visual == null or not is_instance_valid(visual): return false
	if item_kind not in ["branch","leaves","fruit","fish"]: return false
	if not scene.get("lair") is Node or not scene.lair.has_method("receive_item"): return false
	if not scene.creature.can_roam(): return false
	kind = item_kind
	source_id = item_id
	held = visual
	release_source = release
	commit_source = commit
	_reparent_preserving_transform(held,routine)
	var previous_active: String = routine.active
	var previous_target: Dictionary = routine.target
	var previous_phase: String = routine._phase
	routine.active = "forage"
	routine.target = {"id":item_id}
	routine._phase = "carry_home"
	routine._elapsed = 0.0
	if not routine.cave.request("forage"):
		_reparent_preserving_transform(held,scene)
		_clear()
		routine.active = previous_active
		routine.target = previous_target
		routine._phase = previous_phase
		return false
	scene.brain.reset_behavior()
	return true

func collect_tree_material(tree: Dictionary) -> bool:
	var branch := Node3D.new()
	branch.name = "GatheredBranch"
	var wood := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.045
	mesh.height = 0.72
	wood.mesh = mesh
	wood.rotation.z = PI*0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("59432f")
	material.roughness = 0.95
	wood.material_override = material
	branch.add_child(wood)
	routine.add_child(branch)
	branch.global_position = scene.creature.hand_position()
	if begin("branch",str(tree.get("id","tree")),branch): return true
	branch.queue_free()
	return false

func advance(_dt: float) -> void:
	if not carrying(): return
	# Authored TreeShake hands the branch into the normal walking hand. During
	# the threshold transfer the cave may teleport the actor to its real bed.
	held.global_position = scene.creature.hand_position()
	var scale := held.global_basis.get_scale()
	held.global_basis = (Basis(Vector3.UP,scene.creature.global_rotation.y)*Basis(Vector3.FORWARD,PI*0.5)).scaled(scale)

func cancel() -> void:
	if kind.is_empty(): return
	_cancel_source()

func _cave_entry_completed(reason: String) -> void:
	if reason != "forage" or kind.is_empty(): return
	var accepted: bool
	if commit_source.is_valid():
		accepted = bool(scene.lair.receive_item_checked(kind,commit_source))
	else:
		accepted = bool(scene.lair.receive_item(kind))
	if accepted:
		if commit_source.is_valid():
			_reparent_preserving_transform(held,scene)
		elif is_instance_valid(held): held.queue_free()
		routine.history.append(kind)
		delivered.emit(kind,source_id)
		_clear()
		routine.active = ""
		routine.target = {}
		routine._phase = ""
	else:
		_cancel_source()

func _cave_cancelled(reason: String) -> void:
	if reason == "forage" and not kind.is_empty(): _cancel_source()

func _cancel_source() -> void:
	if is_instance_valid(held): _reparent_preserving_transform(held,scene)
	if release_source.is_valid(): release_source.call()
	elif is_instance_valid(held): held.queue_free()
	_clear()
	if routine.active == "forage":
		routine.active = ""
		routine.target = {}
		routine._phase = ""

func _clear() -> void:
	held = null
	kind = ""
	source_id = ""
	release_source = Callable()
	commit_source = Callable()

func _reparent_preserving_transform(node: Node3D, parent: Node) -> void:
	var pose := node.global_transform
	if node.get_parent() != null: node.reparent(parent)
	else: parent.add_child(node)
	node.global_transform = pose
