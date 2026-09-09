extends SceneTree

class PlayScene extends Node3D:
	var camera := Camera3D.new()
	var _paused := false
	var gust_tool := false
	var _carrying := false
	var mischief: Node = null
	func _over_controls(_mouse: Vector2) -> bool: return false
	func _probe_ground(_point: Vector3) -> Variant: return null
	func _show_reaction(_symbol: String, _message: String) -> void: pass

var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(1440,900)
	var scene := PlayScene.new()
	root.add_child(scene)
	scene.add_child(scene.camera)
	var props = preload("res://scripts/world_loose_props.gd").new()
	scene.add_child(props)
	props.setup(scene)
	for camera_position in [Vector3(12,10,16),Vector3(-12,10,16)]:
		scene.camera.position = camera_position
		scene.camera.look_at(Vector3.ZERO)
		for kind in ["stone","log","boulder"]:
			var body = preload("res://scripts/play_loose_body.gd").new()
			body.setup(kind,SphereMesh.new(),StandardMaterial3D.new())
			scene.add_child(body)
			body.position = Vector3(2,1,0)
			var original: Transform3D = body.global_transform
			props.bodies.append(body)
			var mouse := scene.camera.unproject_position(body.position)+Vector2(8,0)
			props.begin_grab(body,mouse)
			for step in 240: props.advance(1.0/60.0)
			check(scene.camera.unproject_position(body.position).distance_to(mouse)<0.1,kind+" centers under cursor after pickup")
			mouse += Vector2(70,-20)
			props.move_grab(mouse)
			for step in 240: props.advance(1.0/60.0)
			check(scene.camera.unproject_position(body.position).distance_to(mouse)<0.1,kind+" follows cursor without a persistent offset")
			props.cancel()
			check(body.global_transform.is_equal_approx(original),"Cancel restores original pose")
			props.bodies.erase(body)
			props._previous.erase(body)
			body.free()
	scene.free()
	print("LOOSE PROP CURSOR failures=",failures)
	quit(failures)
