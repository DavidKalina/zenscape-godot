extends SceneTree

class HeldCreature extends Node3D:
	var grasp_height := 2.7
	func move_held(at: Vector3, _delta: float) -> void: global_position = at

class Editor extends RefCounted:
	var terrain := Node3D.new()
	var hit: Variant = Vector3(4,8,0)
	func pointer_in_world(_mouse: Vector2) -> bool: return true
	func pick(_mouse: Vector2) -> Variant: return hit

class Habitat extends RefCounted:
	func ground_height(point: Vector2) -> Variant:
		return 8.0 if point.x >= 2.0 else 0.0

class CarryScene extends Node3D:
	var creature := HeldCreature.new()
	var camera := Camera3D.new()
	var _chunk_editor := Editor.new()
	var habitat := Habitat.new()
	var resident_enabled := false
	var _paused := false
	var world_play: Node = null

var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var scene := CarryScene.new()
	root.add_child(scene)
	scene.add_child(scene.creature)
	scene.add_child(scene.camera)
	scene.add_child(scene._chunk_editor.terrain)
	scene.camera.position = Vector3(0,20,20)
	scene.camera.look_at(Vector3.ZERO)
	var carry = preload("res://scripts/resident_interaction.gd").new()
	carry.setup(scene)
	carry.carrying = true
	carry.hold_plane = Plane(Vector3.UP,3.6)
	for step in 60:
		carry.update(1.0/60.0)
		var p: Vector3 = scene.creature.global_position
		check(p.y >= scene.habitat.ground_height(Vector2(p.x,p.z)),"Held feet stay above terrain during uphill smoothing")
	check(scene.creature.position.distance_to(Vector3(4,8.9,0)) < 0.01,"Carry follows the mountain under the cursor")
	scene._chunk_editor.hit = Vector3.ZERO
	for step in 60: carry.update(1.0/60.0)
	check(scene.creature.position.distance_to(Vector3(0,0.9,0)) < 0.01,"Carry descends to low terrain again")
	scene.free()
	print("RESIDENT CARRY TERRAIN failures=",failures)
	quit(failures)
