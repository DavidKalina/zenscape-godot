extends Node3D
## The God Hand (tools/blender_hand/god_hand.py): one right hand of light
## that works the creation tools. It hovers over the pointer's ground point,
## and the tool in hand decides its gesture (NativeChunkEditor `hand_gesture`):
## it pinches land up, presses it down like clay, cups the water ball and
## sprinkles pollen. Each gesture plays In, a looping Hold and Out; Idle
## plays in between. It only shows the work: the brushes, the ball and the
## pollen behave exactly as they do without it. `--no-hand` leaves it out.
##
## Every clip is placed against the anchor, the model's origin: the ground
## point under the pointer, followed on a spring. The anchor is turned so the
## camera sees the hand's three-quarter profile, the reach leading left and
## away with the thumb side toward the camera; end-on it reads as a blob.
##
## Lives under the terrain node, so its coordinates are the plate's, like the
## water ball's.

const GLB := "res://assets/models/zenscape-god-hand.glb"
## The light, drawn over a depth-only first pass: the display fog repaints
## anything that writes no depth as the ground behind it
## (shaders/god_hand_depth.gdshader). After the water ball and its beads.
const SHADER := "res://shaders/god_hand.gdshader"
const DEPTH_SHADER := "res://shaders/god_hand_depth.gdshader"
## The model is 1.0 from wrist to middle fingertip; the hand is this many
## metres long, about right for a half-metre ball.
const HAND_METRES := 2.5
## `--hand-cursor` keeps the hand one size on screen instead: it scales with
## the camera's distance, and is HAND_METRES long at this distance.
const CURSOR_DISTANCE := 43.0
## Hand-space direction (horizontal) from the anchor toward the camera the
## clips were made for: the thumb side, a little behind the reach
## (god_hand_review.py GAME_DIR, in Godot's axes).
const TO_CAMERA := Vector3(0.958,0.0,-0.287)
## The follow spring (1/s²) and damping (1/s): a little softer than the
## ball's, so the hand trails a quick pointer and settles over it.
const FOLLOW := 100.0
const FOLLOW_DAMP := 16.0
## How quickly (1/s) the hand turns to keep its profile to the camera.
const TURN := 5.0
## Opacity per second as the hand comes and goes.
const FADE := 4.0
## Seconds of crossfade into a gesture's In or Out from wherever it is.
const BLEND := 0.18
const GESTURES := {"pinch":"Pinch","press":"Press","cup":"Cup","sprinkle":"Sprinkle"}
const LOOPS := ["Idle","PinchHold","PressHold","CupHold","SprinkleHold"]
## The orb's radius in the cupped palm, in hand lengths (god_hand_clips.py ORB_R).
const ORB_R := 0.2
## Seconds into CupIn when the palm has formed under the ball, and into
## CupOut when the hand tosses it (the rig's cup_formed_s, cup_release_s).
const CUP_FORMED := 0.7
const CUP_RELEASE := 0.3
## The ball leaves when the button does, so CupOut starts this many seconds
## short of its toss rather than from its anticipation.
const CUP_TOSS_LEAD := 0.08

var scene: Node3D
var editor: Node
var player: AnimationPlayer
var skeleton: Skeleton3D
var material: ShaderMaterial
var depth_material: ShaderMaterial
## The gesture in hand ("" is Idle) and the ground point the clips stand on.
var gesture := ""
var anchor := Vector3.ZERO
var velocity := Vector3.ZERO
var yaw := 0.0
var opacity := 0.0
var cursor_sized := "--hand-cursor" in OS.get_cmdline_user_args()
var _placed := false
var _orb := -1
## The skeleton's transform in the hand's own space.
var _skeleton_space := Transform3D.IDENTITY
## 0 to 1 while the palm is carried by a held ball.
var _cup := 0.0

static func enabled() -> bool:
	return not "--no-hand" in OS.get_cmdline_user_args()

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	name = "GodHand"
	var model: Node3D = (load(GLB) as PackedScene).instantiate()
	add_child(model)
	material = ShaderMaterial.new()
	material.shader = load(SHADER)
	material.render_priority = 4
	depth_material = ShaderMaterial.new()
	depth_material.shader = load(DEPTH_SHADER)
	depth_material.render_priority = 3
	depth_material.next_pass = material
	# Light casts no sun shadow: the handful's mark is the only shape below.
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = depth_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player = model.find_child("AnimationPlayer",true,false)
	for loop in LOOPS: player.get_animation(loop).loop_mode = Animation.LOOP_LINEAR
	player.animation_finished.connect(_finished)
	skeleton = model.find_children("*","Skeleton3D",true,false)[0]
	_orb = skeleton.find_bone("Orb")
	_skeleton_space = global_transform.affine_inverse()*skeleton.global_transform
	player.play("Idle")
	visible = false
	_set_opacity(0.0)

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var hit: Variant = editor.pointer_hit
	var working: String = editor.hand_gesture() if editor.active else ""
	var wanted: bool = editor.active and not editor.forming and editor.mode == "land" and (hit != null or not working.is_empty())
	_set_opacity(move_toward(opacity,1.0 if wanted else 0.0,delta*FADE))
	visible = opacity > 0.0
	if not visible:
		_placed = false
		_cup = 0.0
		if not gesture.is_empty(): _play("")
		return
	_play(working)
	var goal := anchor if hit == null else (hit as Vector3)
	if not _placed:
		anchor = goal
		velocity = Vector3.ZERO
		yaw = _facing()
		_placed = true
	velocity += ((goal-anchor)*FOLLOW-velocity*FOLLOW_DAMP)*delta
	anchor += velocity*delta
	yaw = lerp_angle(yaw,_facing(),1.0-exp(-TURN*delta))
	var size: float = HAND_METRES*(scene.distance/CURSOR_DISTANCE if cursor_sized else 1.0)
	transform = Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),anchor)
	# While a ball is held the palm rides under it: the ball keeps its own
	# spring and its promise, and the hand goes where the ball is.
	var ball: Node3D = editor.ball
	var holding: bool = gesture == "cup" and ball != null and ball.state == "holding"
	_cup = move_toward(_cup,1.0 if holding else 0.0,delta/CUP_FORMED)
	if _cup > 0.0 and ball != null:
		var orb := basis*(_skeleton_space*skeleton.get_bone_global_pose(_orb).origin)
		var carried: Vector3 = ball.position-Vector3.UP*(ball.radius-ORB_R*size)-orb
		position = anchor.lerp(carried,smoothstep(0.0,1.0,_cup))

## The yaw that turns the hand's profile to the camera.
func _facing() -> float:
	var camera: Vector3 = get_parent().to_local(scene.camera.global_position)-anchor
	if Vector2(camera.x,camera.z).length_squared() < 0.0001: return yaw
	return atan2(camera.x,camera.z)-atan2(TO_CAMERA.x,TO_CAMERA.z)

## Start `next`'s In, or the last gesture's Out when `next` is "".
func _play(next: String) -> void:
	if next == gesture: return
	var last := gesture
	gesture = next
	if not next.is_empty():
		player.play(GESTURES[next]+"In",BLEND)
	elif not last.is_empty():
		player.play(GESTURES[last]+"Out",BLEND)
		if last == "cup": player.seek(CUP_RELEASE-CUP_TOSS_LEAD)

## An In runs into its Hold, an Out into Idle; the clips meet with no gap.
func _finished(clip: StringName) -> void:
	var clip_name := String(clip)
	if clip_name.ends_with("In") and not gesture.is_empty() and clip_name == GESTURES[gesture]+"In":
		player.play(GESTURES[gesture]+"Hold",0.0)
	elif clip_name.ends_with("Out"):
		player.play("Idle",0.0)

func _set_opacity(value: float) -> void:
	if value == opacity and value > 0.0: return
	opacity = value
	material.set_shader_parameter("hand_opacity",value)
	depth_material.set_shader_parameter("hand_opacity",value)
