extends SceneTree
## Headless check of the God Hand's wiring (scripts/god_hand.gd) without the
## Fidelity scene: a stand-in scene, editor and water ball drive it through
## each gesture, and the probe prints which clip plays and where the contact
## bones are in the plate's space.
##   Godot --headless --path . --script res://tools/probe_god_hand_wiring.gd

const FakeEditor := """
extends Node
var active := true
var forming := false
var mode := "land"
var pointer_hit: Variant = Vector3(2.0,0.5,-1.0)
var gesture := ""
var ball: Node3D
func hand_gesture() -> String: return gesture
"""
const FakeScene := """
extends Node3D
var _chunk_editor: Node
var camera: Camera3D
var distance := 43.0
"""
const FakeBall := """
extends Node3D
var state := "idle"
var radius := 0.6
"""

var failures := 0

func _script(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return script

func _check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node3D = _script(FakeScene).new()
	root.add_child(scene)
	var editor: Node = _script(FakeEditor).new()
	scene.add_child(editor)
	scene._chunk_editor = editor
	var camera := Camera3D.new()
	scene.add_child(camera)
	scene.camera = camera
	# The game camera: 25 degrees up, 43 m out.
	camera.position = Vector3(2.0,0.5,-1.0)+Vector3(sin(1.2),0.0,cos(1.2))*43.0*cos(deg_to_rad(25.0))+Vector3.UP*43.0*sin(deg_to_rad(25.0))
	var ball: Node3D = _script(FakeBall).new()
	var terrain := Node3D.new()
	scene.add_child(terrain)
	terrain.add_child(ball)
	editor.ball = ball
	var hand: Node3D = preload("res://scripts/god_hand.gd").new()
	terrain.add_child(hand)
	hand.setup(scene)
	var pinch: int = hand.skeleton.find_bone("Pinch")
	var palm: int = hand.skeleton.find_bone("Palm")
	var orb: int = hand.skeleton.find_bone("Orb")

	await _frames(40)
	_check(hand.visible and is_equal_approx(hand.opacity,1.0),"hand fades in over the pointer")
	_check(hand.player.current_animation == "Idle","idle while hovering")
	_check(hand.anchor.distance_to(editor.pointer_hit) < 0.02,"anchor settles on the pointer's ground point (%.3f)" % hand.anchor.distance_to(editor.pointer_hit))
	var toward: Vector3 = camera.position-hand.anchor
	var seen: Vector3 = hand.basis.orthonormalized()*hand.TO_CAMERA
	_check(Vector2(seen.x,seen.z).normalized().dot(Vector2(toward.x,toward.z).normalized()) > 0.99,"profile turned to the camera")

	editor.gesture = "pinch"
	await _frames(1)
	_check(hand.player.current_animation == "PinchIn","pinch plays PinchIn")
	await _seconds(0.4)
	print("  pinch tip at contact: %.3f m from the pointer" % _bone(hand,pinch).distance_to(editor.pointer_hit))
	await _seconds(0.6)
	_check(hand.player.current_animation == "PinchHold","PinchIn runs into PinchHold")
	editor.gesture = ""
	await _frames(1)
	_check(hand.player.current_animation == "PinchOut","release plays PinchOut")
	await _seconds(1.3)
	_check(hand.player.current_animation == "Idle","PinchOut runs into Idle")

	editor.gesture = "press"
	await _seconds(0.43)
	print("  palm at contact: %.3f m from the pointer" % _bone(hand,palm).distance_to(editor.pointer_hit))
	editor.gesture = ""
	await _seconds(1.5)

	ball.state = "holding"
	ball.position = editor.pointer_hit+Vector3.UP*(1.6+ball.radius)
	editor.gesture = "cup"
	await _seconds(1.2)
	_check(hand.player.current_animation == "CupHold","cup holds")
	var under: Vector3 = ball.position-Vector3.UP*(ball.radius-hand.ORB_R*hand.HAND_METRES)
	_check(_bone(hand,orb).distance_to(under) < 0.05,"palm carries the ball (%.3f m off)" % _bone(hand,orb).distance_to(under))
	ball.position += Vector3(1.0,0.0,0.5)
	await _frames(2)
	_check(_bone(hand,orb).distance_to(ball.position-Vector3.UP*(ball.radius-hand.ORB_R*hand.HAND_METRES)) < 0.05,"palm follows the ball as it moves")
	ball.state = "falling"
	editor.gesture = ""
	await _frames(1)
	_check(hand.player.current_animation == "CupOut","release plays CupOut")
	print("  CupOut starts at %.2f s" % hand.player.current_animation_position)

	editor.pointer_hit = null
	await _seconds(0.8)
	_check(not hand.visible,"hand fades out off the land")
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _bone(hand: Node3D, bone: int) -> Vector3:
	return hand.global_transform*hand.skeleton.get_bone_global_pose(bone).origin

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec()+int(seconds*1000.0)
	while Time.get_ticks_msec() < until: await process_frame
