extends Node3D
## The God Hand (tools/blender_hand/god_hand.py): one right hand of light
## that works the creation tools. It floats over the pointer's ground point,
## and the tool in hand decides its gesture (NativeChunkEditor `hand_gesture`):
## it pinches land up and pulls, presses it down like clay, rolls the water
## ball in its palm and pops it, and throws pollen. Each gesture plays In, a
## looping Hold and Out; in between it idles, bobbing, and now and then plays
## one of Idle's variations (a stretch, a look at its palm...). It only shows
## the work: the brushes, the ball and the pollen land where they would
## without it. `--no-hand` leaves it out.
##
## Every clip is placed against the anchor, the model's origin: the ground
## point under the pointer (or the summit of a rising mountain, which the
## pinch holds), followed on a spring. The anchor is turned so the camera
## sees the hand's three-quarter profile, the reach leading left and away
## with the thumb side toward the camera; end-on it reads as a blob. Over it,
## the hand leans into the pointer's way and rocks back when it stops, tilts
## with the slope it works on, and keeps its knuckles and palm clear of the
## land.
##
## The clips carry marks on non-deforming bones (god_hand_clips.py): Ball and
## BallTouch are where the clip takes the water ball to be and where the hand
## touches it, and the hand is carried so they sit on the real ball, of any
## size; Handful is pollen held in the palm, whose drop throws it.
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
## "shake" is a reach, not a tool: gripping the rim and shaking the diorama
## like a snow globe (scripts/snow_globe.gd). "turn" and "catch" grip the land
## to turn the world (scripts/world_turn.gd). "sun" holds the sun or the moon
## to set the hour, "rim" grips the rim to turn the season (scripts/hand_reach.gd),
## and "flip" is the same grip held through a diorama flip (scripts/diorama_flip.gd),
## a key hand_reach does not clear.
const GESTURES := {"pinch":"Pinch","press":"Press","cup":"Cup","sprinkle":"Sprinkle","shake":"Shake","turn":"Turn","catch":"Catch","sun":"Reach","rim":"Rim","flip":"Rim"}
const LOOPS := ["PinchHold","PressHold","CupHold","SprinkleHold","ShakeHold","TurnHold","CatchHold","ReachHold","RimHold"]
## Idle's variations (god_hand_clips.py IDLE_VARIANTS), each starting and
## ending on Idle's first pose, so one may follow whenever Idle comes round:
## after a plain Idle one plays with VARIANT_CHANCE, never the same one twice
## running, once the hand has hovered near still (under STILL m/s) for
## STILL_SECONDS. Idle itself is played one round at a time for this.
const IDLE_VARIANTS := ["IdleStretch","IdlePeek","IdleRipple","IdleGather","IdleDrift"]
const VARIANT_CHANCE := 0.55
const STILL := 1.5
const STILL_SECONDS := 1.0
## Leaning into the pointer's way: radians of lean per m/s the hand is
## carried at, at most MAX_LEAN, on a spring (1/s², 1/s) under critical, so
## a stop rocks it back through upright. It turns about a point LEAN_PIVOT
## hand lengths over the anchor, about the middle of the hovering hand. Only
## while the hand is free (idling or throwing pollen).
const LEAN := 0.045
const MAX_LEAN := 0.35
const LEAN_SPRING := 70.0
const LEAN_DAMP := 8.0
const LEAN_PIVOT := 0.45
## Settling onto slopes: the ground is read TILT_REACH hand lengths round the
## anchor and the hand tilts about the anchor with it, at most MAX_TILT
## radians, by each gesture's share: fully while it touches the land.
const TILT_REACH := 0.5
const MAX_TILT := 0.55
const TILT := {"":0.35,"pinch":1.0,"press":1.0,"cup":0.0,"sprinkle":0.2,"shake":0.0,"turn":1.0,"catch":1.0,"sun":0.0,"rim":0.0,"flip":0.0}
## Holding the sun, the hand turns square to the camera, however high the sun
## is: the Reach clips cup the disc for a camera level with the hand. The
## share per gesture, eased in and out at FACE_RATE (1/s).
const FACE := {"sun":1.0}
const FACE_RATE := 4.0
## No knuckle or palm goes into the land: CLEAR_BONES are kept CLEAR hand
## lengths over the ground under them by lifting the whole hand, quickly up
## and slowly back down (1/s). A pinch's tips are meant to touch (PINCHING),
## and so is a pressing palm, which is never lifted, and so are fingers hooked
## over the rim (UNLIFTED).
const CLEAR := 0.05
const LIFT_UP := 14.0
const LIFT_DOWN := 3.0
const CLEAR_BONES := ["Hand","MetaIndex","MetaMiddle","MetaRing","MetaPinky","Index1","Middle1","Ring1","Pinky1",
	"Index2","Middle2","Ring2","Pinky2","Index3","Middle3","Ring3","Pinky3","Thumb1","Thumb2","Thumb3"]
const PINCHING := ["Index2","Index3","Thumb2","Thumb3"]
const UNLIFTED := ["press","cup","shake","rim","flip"]
## Turning the world (scripts/world_turn.gd): the gestures whose palm lies
## flat on the land, riding its height and never lifted clear of it; and the
## lean into the push, TURN_LEAN radians per m/s the grabbed ground moves
## across the view (`reach_push`), at most MAX_TURN_LEAN, about the palm on
## the ground rather than the middle of the hand. The lean spring rocks it
## back through upright when the push stops or lets go.
const GRIPS := ["turn","catch"]
const TURN_LEAN := 0.03
const MAX_TURN_LEAN := 0.24
## When the hand leaves the ball (a pop, or a ball gone) the offset that kept
## it there springs away on this critically damped spring (1/s).
const LET_GO := 6.0
## A throw carries the pollen on at this share of the handful's speed, at
## most MAX_THROW m/s.
const THROW_CARRY := 1.3
const MAX_THROW := 7.0
## Seconds into CupOut when the index pops the ball (the rig's cup_pop_s).
const CUP_POP := 0.4333

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
## The skeleton's transform in the hand's own space.
var _skeleton_space := Transform3D.IDENTITY
var _ball := -1
var _touch := -1
var _handful := -1
var _clear: Array[int] = []
var _pinching: Array[int] = []
## Seconds the hand has hovered near still, and the last variation played.
var _still := 0.0
var _last_variant := ""
## The lean (radians toward plate x, z) and its rate; the tilt's share.
var _lean := Vector2.ZERO
var _lean_speed := Vector2.ZERO
var _tilt := 0.0
## Metres the hand is lifted clear of the land.
var _lift := 0.0
## The offset from the anchor that keeps the Ball mark on the real ball, and
## its rate, so a let-go carries on smoothly.
var _carry := Vector3.ZERO
var _carry_speed := Vector3.ZERO
## The handful's hold on the last frame and where it was, for the throw.
var _held := 0.0
var _handful_at: Variant = null
## Reaching past the creation tools (docs/scenic/hand-world.md: the sun, the
## rim, turning the world): while `reach_gesture` is set it stands in for the
## tool's gesture, a key of GESTURES, and shows the hand wherever the tool is,
## and the hand works at `reach_point` (plate coordinates) when that is set
## instead of over the pointer. Whoever reaches sets both and clears them on
## letting go.
var reach_gesture := ""
var reach_point: Variant = null
## A reach may also turn the hand: `reach_facing` (a horizontal plate
## direction) is where its reach leads instead of keeping its profile to the
## camera (the rim grip reaches in across the lip), and `reach_pace` is how
## fast its Hold plays (a harder shake shakes faster). Cleared with the rest.
var reach_facing: Variant = null
var reach_pace := 1.0
## Which way the reach pushes what it holds (plate m/s): a turning world's
## grabbed ground. The hand leans into it while it grips (GRIPS).
var reach_push := Vector3.ZERO
## 1 while the hand grips (GRIPS), easing: its lean turns about the palm.
var _grip := 0.0
## How square the hand is turned to the camera (FACE).
var _face := 0.0

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
	_ball = skeleton.find_bone("Ball")
	_touch = skeleton.find_bone("BallTouch")
	_handful = skeleton.find_bone("Handful")
	for bone in CLEAR_BONES:
		var i := skeleton.find_bone(bone)
		if i < 0: continue
		_clear.append(i)
		if bone in PINCHING: _pinching.append(i)
	_skeleton_space = global_transform.affine_inverse()*skeleton.global_transform
	player.play("Idle")
	visible = false
	_set_opacity(0.0)

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var hit: Variant = editor.pointer_hit
	var working: String = editor.hand_gesture() if editor.active else ""
	if not reach_gesture.is_empty(): working = reach_gesture
	var wanted: bool = not reach_gesture.is_empty() or (editor.active and not editor.forming and editor.mode == "land" and (hit != null or not working.is_empty()))
	_set_opacity(move_toward(opacity,1.0 if wanted else 0.0,delta*FADE))
	visible = opacity > 0.0
	if not visible:
		_placed = false
		_carry = Vector3.ZERO
		_carry_speed = Vector3.ZERO
		_lift = 0.0
		_lean = Vector2.ZERO
		_lean_speed = Vector2.ZERO
		if not gesture.is_empty(): _play("")
		_sow(delta,false)
		return
	_play(working)
	player.speed_scale = reach_pace if not reach_gesture.is_empty() and String(player.current_animation).ends_with("Hold") else 1.0
	# The pinch holds a rising mountain by its summit, wherever the drag goes.
	var work: Variant = editor.hand_work_point() if editor.has_method("hand_work_point") else null
	var goal: Vector3 = anchor if hit == null else hit
	if work != null: goal = work
	if reach_point != null: goal = reach_point
	# Throwing seed it stands back from the pointer and lobs onto it.
	var cloud: Node3D = editor.get("handful")
	if hit != null and cloud != null and cloud.has_method("stand_off") and (gesture == "sprinkle" or String(player.current_animation).begins_with("Sprinkle")):
		goal -= Basis(Vector3.UP,yaw)*Vector3.BACK*float(cloud.stand_off())
		var data: Variant = editor.get("data")
		var h: Variant = data.ground_height(Vector2(goal.x,goal.z)) if data != null else null
		if h != null: goal.y = float(h)
	if not _placed:
		anchor = goal
		velocity = Vector3.ZERO
		yaw = _facing()
		_placed = true
	velocity += ((goal-anchor)*FOLLOW-velocity*FOLLOW_DAMP)*delta
	anchor += velocity*delta
	# While it touches the land it rides the land's height exactly, rising
	# with a pulled summit and sinking with pressed clay.
	if gesture == "pinch" or gesture == "press" or gesture in GRIPS:
		anchor.y = goal.y
		velocity.y = 0.0
	yaw = lerp_angle(yaw,_facing(),1.0-exp(-TURN*delta))
	var size: float = HAND_METRES*(scene.distance/CURSOR_DISTANCE if cursor_sized else 1.0)
	var flat := Vector2(velocity.x,velocity.z)
	_still = _still+delta if flat.length() < STILL else 0.0
	# It leans into the pointer's way and rocks back through upright on a stop.
	var free := gesture.is_empty() or gesture == "sprinkle" or gesture == "rim" or gesture == "flip"
	var lean_goal := (flat*LEAN).limit_length(MAX_LEAN) if free else Vector2.ZERO
	if gesture in GRIPS: lean_goal = (Vector2(reach_push.x,reach_push.z)*TURN_LEAN).limit_length(MAX_TURN_LEAN)
	_lean_speed += ((lean_goal-_lean)*LEAN_SPRING-_lean_speed*LEAN_DAMP)*delta
	_lean += _lean_speed*delta
	var lean := Basis.IDENTITY
	if _lean.length() > 0.0001: lean = Basis(Vector3(_lean.y,0.0,-_lean.x).normalized(),_lean.length())
	_tilt = move_toward(_tilt,float(TILT.get(gesture,0.0)),delta*3.0)
	var tilt := _slope(anchor,size)
	_grip = move_toward(_grip,1.0 if gesture in GRIPS else 0.0,delta*4.0)
	_face = move_toward(_face,float(FACE.get(gesture,0.0)),delta*FACE_RATE)
	var pivot := Vector3.UP*LEAN_PIVOT*size*(1.0-_grip)
	transform = Transform3D(lean*tilt*_square_to_camera()*Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),anchor+pivot-lean*pivot)
	position += _carried(delta)
	_rise_clear(size,delta)
	_sow(delta,true)

## The yaw that turns the hand's profile to the camera, or its reach along
## `reach_facing` (the model's reach is its +z).
func _facing() -> float:
	if reach_facing != null:
		var along: Vector3 = reach_facing
		return atan2(along.x,along.z)
	var camera: Vector3 = get_parent().to_local(scene.camera.global_position)-anchor
	if Vector2(camera.x,camera.z).length_squared() < 0.0001: return yaw
	return atan2(camera.x,camera.z)-atan2(TO_CAMERA.x,TO_CAMERA.z)

## The turn, about the anchor, that points the hand's camera side (TO_CAMERA)
## straight at the camera, up or down, by `_face`.
func _square_to_camera() -> Basis:
	if _face <= 0.0: return Basis.IDENTITY
	var side := Basis(Vector3.UP,yaw)*TO_CAMERA
	var camera: Vector3 = get_parent().to_local(scene.camera.global_position)-anchor
	if camera.length_squared() < 0.0001: return Basis.IDENTITY
	var axis := side.cross(camera.normalized())
	if axis.length_squared() < 0.000001: return Basis.IDENTITY
	return Basis(axis.normalized(),side.angle_to(camera)*_face)

## The turn that stands the hand on the slope round `at`, by the gesture's
## share (`_tilt`).
func _slope(at: Vector3, size: float) -> Basis:
	var data: Variant = editor.get("data")
	if _tilt <= 0.0 or data == null: return Basis.IDENTITY
	var r := TILT_REACH*size
	var heights := []
	for p in [Vector2(at.x-r,at.z),Vector2(at.x+r,at.z),Vector2(at.x,at.z-r),Vector2(at.x,at.z+r)]:
		var h: Variant = data.ground_height(p)
		if h == null: return Basis.IDENTITY
		heights.append(float(h))
	var normal := Vector3(heights[0]-heights[1],2.0*r,heights[2]-heights[3]).normalized()
	var angle := minf(Vector3.UP.angle_to(normal),MAX_TILT)*_tilt
	var axis := Vector3.UP.cross(normal)
	if angle < 0.001 or axis.length_squared() < 0.000001: return Basis.IDENTITY
	return Basis(axis.normalized(),angle)

## Where a bone is, plate coordinates, as the hand stands now.
func _bone_at(bone: int) -> Vector3:
	return position+basis*(_skeleton_space*skeleton.get_bone_global_pose(bone).origin)

## A bone mark's weight: the clips carry it on the bone's scale.
func _weight(bone: int) -> float:
	return clampf(skeleton.get_bone_global_pose(bone).basis.get_scale().x,0.0,1.0)

## The offset that keeps the clip's Ball mark on the real ball while a ball
## is held or tossed: the clip's ball centre goes to the real centre, pushed
## out along the touch by the difference in radius, so the palm stays under
## a ball of any size and the finger meets its skin. As the mark lets go (a
## pop) or the ball is gone, the offset springs back to the pointer.
func _carried(delta: float) -> Vector3:
	var ball: Node3D = editor.get("ball")
	_carry_speed += (-_carry*LET_GO*LET_GO-_carry_speed*2.0*LET_GO)*delta
	var loose := _carry+_carry_speed*delta
	var weight := 0.0
	var want := Vector3.ZERO
	if ball != null and _ball >= 0 and (ball.state == "holding" or ball.state == "tossed"):
		weight = _weight(_ball)
		if weight > 0.002:
			var centre := _bone_at(_ball)-position
			var reach := _bone_at(_touch)-position-centre
			var toward := reach.normalized()
			want = ball.position+toward*(float(ball.radius)-reach.length())-centre-position
			if "poke" in ball: ball.poke = toward
	if weight > 0.002:
		var held := loose.lerp(want,weight)
		_carry_speed = ((held-_carry)/maxf(delta,0.001)).limit_length(30.0)
		_carry = held
	else:
		_carry = loose
	return _carry

## Lift the hand clear where a knuckle or the palm would go into the land.
## Not while it presses (the palm is meant to be down) or holds a ball.
func _rise_clear(size: float, delta: float) -> void:
	var data: Variant = editor.get("data")
	var need := 0.0
	if data != null and not gesture in UNLIFTED and not gesture in GRIPS:
		for bone in _clear:
			if gesture == "pinch" and bone in _pinching: continue
			var p := _bone_at(bone)
			var h: Variant = data.ground_height(Vector2(p.x,p.z))
			if h != null: need = maxf(need,float(h)+CLEAR*size-p.y)
	_lift = lerpf(_lift,need,1.0-exp(-(LIFT_UP if need > _lift else LIFT_DOWN)*delta))
	position.y += _lift

## Pollen (scripts/pollen_cloud.gd) gathers in the palm while the hand is
## free, and is thrown when a Sprinkle clip's Handful mark drops, at the
## handful's speed.
func _sow(delta: float, shown: bool) -> void:
	var cloud: Node3D = editor.get("handful")
	if cloud == null or not "hand_at" in cloud or _handful < 0: return
	var clip := String(player.current_animation)
	if not shown or not (gesture.is_empty() or gesture == "sprinkle" or clip.begins_with("Sprinkle")):
		cloud.hand_at = null
		_handful_at = null
		return
	var at := _bone_at(_handful)
	var held := _weight(_handful)
	if _handful_at != null and _held >= 0.5 and held < 0.5 and clip.begins_with("Sprinkle"):
		cloud.toss(((at-Vector3(_handful_at))/maxf(delta,0.001)*THROW_CARRY).limit_length(MAX_THROW))
	cloud.hand_at = at
	_handful_at = at
	_held = held

## Start `next`'s In, or the last gesture's Out when `next` is "".
func _play(next: String) -> void:
	if next == gesture: return
	var last := gesture
	gesture = next
	if not next.is_empty():
		player.play(GESTURES[next]+"In",BLEND)
	elif not last.is_empty():
		player.play(GESTURES[last]+"Out",BLEND)
		# The index pops the ball as the ball pops: start CupOut so its poke
		# lands on the ball's own beat (scripts/water_ball.gd POP_SECONDS).
		var ball: Node3D = editor.get("ball")
		if last == "cup" and ball != null and ball.has_method("pop_in"):
			player.seek(maxf(CUP_POP-float(ball.pop_in()),0.0))

## An In runs into its Hold, an Out into Idle, and Idle into itself or one of
## its variations; the clips meet with no gap.
func _finished(clip: StringName) -> void:
	var clip_name := String(clip)
	if clip_name.ends_with("In") and not gesture.is_empty() and clip_name == GESTURES[gesture]+"In":
		player.play(GESTURES[gesture]+"Hold",0.0)
	elif clip_name.ends_with("Out") or clip_name.begins_with("Idle"):
		player.play(_next_idle(clip_name),0.0)

## After a plain Idle, sometimes one of its variations; after anything else,
## Idle.
func _next_idle(last: String) -> String:
	if last != "Idle" or _still < STILL_SECONDS or randf() > VARIANT_CHANCE: return "Idle"
	var choices := IDLE_VARIANTS.filter(func(v: String) -> bool: return v != _last_variant and player.has_animation(v))
	if choices.is_empty(): return "Idle"
	_last_variant = choices[randi()%choices.size()]
	return _last_variant

func _set_opacity(value: float) -> void:
	if value == opacity and value > 0.0: return
	opacity = value
	material.set_shader_parameter("hand_opacity",value)
	depth_material.set_shader_parameter("hand_opacity",value)
