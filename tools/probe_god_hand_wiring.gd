extends SceneTree
## Headless check of the God Hand's wiring (scripts/god_hand.gd) without the
## Fidelity scene: a stand-in scene, editor, ground, water ball and pollen
## cloud drive it through each gesture, and the probe prints which clip
## plays and where the marks are in the plate's space.
##   Godot --headless --path . --script res://tools/probe_god_hand_wiring.gd

const FakeEditor := """
extends Node
var active := true
var forming := false
var mode := "land"
var pointer_hit: Variant = Vector3(2.0,0.5,-1.0)
var gesture := ""
var ball: Node3D
var handful: Node3D
var data: Object
var work: Variant = null
func hand_gesture() -> String: return gesture
func hand_work_point() -> Variant: return work
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
var poke := Vector3.ZERO
var popping := 0.4
func pop_in() -> float: return popping
"""
const FakeCloud := """
extends Node3D
var hand_at: Variant = null
var throws: Array[Vector3] = []
func toss(velocity: Vector3) -> void: throws.append(velocity)
func stand_off() -> float: return 2.2
"""
## Ground at `level`, rising along +x by `slope` (m per m).
const FakeGround := """
extends RefCounted
var level := 0.5
var slope := 0.0
func ground_height(p: Vector2) -> Variant: return level+slope*(p.x-2.0)
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
	var cloud: Node3D = _script(FakeCloud).new()
	terrain.add_child(cloud)
	editor.handful = cloud
	var ground: Object = _script(FakeGround).new()
	editor.data = ground
	var hand: Node3D = preload("res://scripts/god_hand.gd").new()
	terrain.add_child(hand)
	hand.setup(scene)
	var pinch: int = hand.skeleton.find_bone("Pinch")
	var palm: int = hand.skeleton.find_bone("Palm")
	var mark: int = hand.skeleton.find_bone("Ball")
	var touch: int = hand.skeleton.find_bone("BallTouch")

	await _frames(40)
	_check(hand.visible and is_equal_approx(hand.opacity,1.0),"hand fades in over the pointer")
	_check(String(hand.player.current_animation).begins_with("Idle"),"idle while hovering")
	_check(hand.anchor.distance_to(editor.pointer_hit) < 0.02,"anchor settles on the pointer's ground point (%.3f)" % hand.anchor.distance_to(editor.pointer_hit))
	var toward: Vector3 = camera.position-hand.anchor
	var seen: Vector3 = hand.basis.orthonormalized()*hand.TO_CAMERA
	_check(Vector2(seen.x,seen.z).normalized().dot(Vector2(toward.x,toward.z).normalized()) > 0.97,"profile turned to the camera")
	_check(cloud.hand_at != null,"an idle hand offers its palm to the pollen")
	# Idle comes round into itself or a variation.
	hand._still = 5.0
	var variants := {}
	for i in range(40): variants[hand._next_idle("Idle")] = true
	_check(variants.size() >= 3,"Idle is followed by Idle or its variations (%s)" % ", ".join(variants.keys()))
	_check(hand._next_idle("IdlePeek") == "Idle","a variation is followed by plain Idle")
	hand._still = 0.0
	_check(hand._next_idle("Idle") == "Idle","no variation while the pointer moves")

	# Moving the pointer leans the hand into its way.
	editor.pointer_hit = Vector3(6.0,0.5,-1.0)
	await _seconds(0.12)
	var up: Vector3 = hand.basis.orthonormalized().y
	_check(up.x > 0.05,"the hand leans into the pointer's way (up %.2f, %.2f, %.2f)" % [up.x,up.y,up.z])
	editor.pointer_hit = Vector3(2.0,0.5,-1.0)
	await _seconds(1.2)

	editor.gesture = "pinch"
	await _frames(1)
	_check(hand.player.current_animation == "PinchIn","pinch plays PinchIn")
	await _seconds(0.5)
	print("  pinch tip at contact: %.3f m from the pointer" % _bone(hand,pinch).distance_to(editor.pointer_hit))
	await _seconds(0.5)
	_check(hand.player.current_animation == "PinchHold","PinchIn runs into PinchHold")
	# A rising summit elsewhere: the pinch goes there and rides it up.
	editor.work = Vector3(3.0,2.5,-0.5)
	await _seconds(0.8)
	_check(hand.anchor.distance_to(editor.work) < 0.05,"the pinch holds the rising summit (%.3f m off)" % hand.anchor.distance_to(editor.work))
	editor.work = Vector3(3.0,3.5,-0.5)
	await _frames(2)
	_check(absf(hand.anchor.y-3.5) < 0.001,"it rides the summit up with no lag")
	editor.work = null
	# Ground that rises steeply under the hand's reach: nothing but the tips go in.
	ground.level = 0.5
	ground.slope = 1.2
	await _seconds(0.8)
	var deepest := 0.0
	for bone in hand._clear:
		if bone in hand._pinching: continue
		var p: Vector3 = _bone(hand,bone)
		deepest = maxf(deepest,float(ground.ground_height(Vector2(p.x,p.z)))-p.y)
	_check(deepest < 0.02,"no knuckle goes into a steep slope (deepest %.3f m)" % deepest)
	ground.slope = 0.0
	editor.gesture = ""
	await _frames(1)
	_check(hand.player.current_animation == "PinchOut","release plays PinchOut")
	await _seconds(1.3)
	_check(String(hand.player.current_animation).begins_with("Idle"),"PinchOut runs into Idle")

	editor.gesture = "press"
	await _seconds(0.43)
	print("  palm at contact: %.3f m from the pointer" % _bone(hand,palm).distance_to(editor.pointer_hit))
	editor.gesture = ""
	await _seconds(1.5)

	ball.state = "holding"
	ball.position = editor.pointer_hit+Vector3.UP*(1.6+ball.radius)
	editor.gesture = "cup"
	await _seconds(1.3)
	_check(hand.player.current_animation == "CupHold","cup holds")
	var skin: Vector3 = _bone(hand,touch)
	_check(absf(skin.distance_to(ball.position)-ball.radius) < 0.05,"the palm holds the ball's skin (%.3f m off)" % absf(skin.distance_to(ball.position)-ball.radius))
	_check((skin-ball.position).normalized().y < -0.9,"from underneath")
	ball.radius = 1.2
	ball.position += Vector3(1.0,0.0,0.5)
	await _frames(3)
	skin = _bone(hand,touch)
	_check(absf(skin.distance_to(ball.position)-ball.radius) < 0.05,"and follows a bigger ball as it moves (%.3f m off)" % absf(skin.distance_to(ball.position)-ball.radius))
	# Let go: the ball is tossed and pops 0.4 s on; the finger pops it then.
	ball.state = "tossed"
	editor.gesture = ""
	await _frames(1)
	_check(hand.player.current_animation == "CupOut","release plays CupOut")
	print("  CupOut starts at %.2f s (pop at %.2f s)" % [hand.player.current_animation_position,hand.CUP_POP])
	var start: float = hand.player.current_animation_position
	_check(absf(start-(hand.CUP_POP-ball.popping)) < 0.05,"CupOut starts so its poke meets the pop")
	var rise := Vector3.ZERO
	while hand.player.current_animation_position < hand.CUP_POP-0.02:
		ball.position += Vector3.UP*0.01
		rise += Vector3.UP*0.01
		await process_frame
	skin = _bone(hand,touch)
	var side: Vector3 = (skin-ball.position).normalized()
	_check(absf(skin.distance_to(ball.position)-ball.radius) < 0.08,"the finger meets the tossed ball's skin (%.3f m off)" % absf(skin.distance_to(ball.position)-ball.radius))
	_check(absf(side.y) < 0.5,"from the side (%.2f, %.2f, %.2f)" % [side.x,side.y,side.z])
	_check(ball.poke.distance_to(side) < 0.1,"and tells the ball where it pokes")
	ball.state = "falling"
	await _seconds(1.8)
	_check(String(hand.player.current_animation).begins_with("Idle"),"CupOut runs into Idle")
	_check(hand._carry.length() < 0.1,"the hand is back over the pointer (%.2f m)" % hand._carry.length())
	ball.state = "idle"

	editor.gesture = "sprinkle"
	await _frames(1)
	_check(hand.player.current_animation == "SprinkleIn","sprinkle plays SprinkleIn")
	await _seconds(3.2)
	_check(hand.player.current_animation == "SprinkleHold","SprinkleIn runs into SprinkleHold")
	var reach: Vector3 = Basis(Vector3.UP,hand.yaw)*Vector3.BACK
	var back: Vector3 = Vector3(editor.pointer_hit)-hand.anchor
	_check(absf(Vector2(back.x,back.z).length()-2.2) < 0.1 and Vector2(back.x,back.z).normalized().dot(Vector2(reach.x,reach.z)) > 0.99,
		"the hand stands back and throws toward the pointer (%.2f m back)" % Vector2(back.x,back.z).length())
	_check(cloud.throws.size() >= 2,"the hand throws pollen as it sows (%d throws)" % cloud.throws.size())
	if not cloud.throws.is_empty():
		var throw: Vector3 = cloud.throws[0]
		print("  first throw %.2f m/s (%.2f, %.2f, %.2f)" % [throw.length(),throw.x,throw.y,throw.z])
		_check(throw.length() > 1.0 and throw.y > 0.2,"thrown out and up")
	var before: int = cloud.throws.size()
	editor.gesture = ""
	await _seconds(0.5)
	_check(cloud.throws.size() == before+1,"letting go throws the last of it")

	editor.pointer_hit = null
	await _seconds(0.8)
	_check(not hand.visible,"hand fades out off the land")
	_check(cloud.hand_at == null,"and takes its palm away from the pollen")
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _bone(hand: Node3D, bone: int) -> Vector3:
	return hand._bone_at(bone)

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec()+int(seconds*1000.0)
	while Time.get_ticks_msec() < until: await process_frame
