extends Node3D
## The pilot on foot, drawn: one of the sky folk, the islanders' compact body
## rigged and animated in Blender (art/blender/pilot/pilot_build.py,
## assets/models/pilot.glb), moved by scripts/pilot_motor.gd. Its clips:
##   idle  standing: breathing, the weight drifting foot to foot;
##   walk  a quick little toddle, made for WALK_SPEED m/s: a light touch on
##         the stick, and starting and stopping;
##   run   the pace he goes by default, made for RUN_SPEED m/s;
##   skid  braking hard, leant back, a boot braced ahead (when the model has
##         it).
## Walk and run are played in step, both at one gait phase, and blended by
## the speed: the phase moves on by the distance covered over the stride the
## blend has (a walk's stride is shorter than a run's), so at either clip's
## own speed the planted boots stay on the ground. A boot touches down as
## the phase passes 0 (the left) and a half (the right): `drive` tells the
## walker, which sounds the step and puffs the dust there. Standing still it
## cross-fades to idle, taken up at a random moment of its long loop so no
## two stops stand alike.
##
## In the air the stride holds where it was (jump clips are still to come);
## the third jump of a chain flips it head over heels about its hips. Thrown
## back at a run it skids, leaning back, and coming out of it whips round to
## face the new way with a little hop.
##
## Over the clips the body has a life of its own, on springs that overshoot
## and settle, as a cartoon hero's does: it dips taking off and stretches
## rising and falling (most at its fastest), squashes landing as hard as it
## came down and bounces back past standing; it tips forward setting off and
## stopping and wobbles back upright; it turns a beat behind its way and
## swings a touch past it; it banks into turns about its feet; its chest
## leans into the run (the faster the further, more up a slope and less
## down one), rolls into turns and leads them, the head lifting to look
## ahead; its head looks into turns and up and down with a jump; its arms
## fly out in the air and flop back landing. Never stiffly upright.
##
## The model's own materials are swapped for the folk's (scripts/
## person_kit.gd outfit, by surface name), so it is lit as the islanders are.
##
## Its origin is the feet, facing -Z; the walker (scripts/wanderer_eye.gd)
## puts it where the motor's feet are and turns it to its facing.

const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PersonKit = preload("res://scripts/person_kit.gd")
const Spring = PersonKit.Spring
const MODEL := preload("res://assets/models/pilot.glb")
## The clips' ground speeds (m/s) and loops (s), as pilot_build.py made them.
const WALK_SPEED := 1.4
const WALK_CYCLE := 0.5
const RUN_SPEED := 4.0
const RUN_CYCLE := 1.0/3.0
## The speeds (m/s) between which the walk gives way to the run.
const BLEND_FROM := 1.6
const BLEND_TO := 3.3
## Under this speed (m/s) it stands.
const STILL := 0.15
## Seconds a cross-fade between standing and moving takes, about.
const FADE := 0.12
## The pelvis over the feet (pilot_build.py HIPS): it flips about it.
const HIPS := 0.379
## Radians of bank per radian a second of turn at a full run, and the most.
const BANK := 0.06
const BANK_MOST := 0.35
## Radians it leans back skidding without a skid clip; with one, the clip
## leans and the spring is only kicked back as it starts (radians a second).
const SKID_LEAN := 0.3
const SKID_KICK := 1.5
## Seconds a cross-fade into a skid and out of one take.
const SKID_IN := 0.05
const SKID_OUT := 0.1
## The hop turning out of a skid: metres and seconds.
const HOP := 0.07
const HOP_TIME := 0.2
## Squash and stretch: the stretch in the air at its fastest (AIR_FAST m/s
## up or down); the dip taking off and the squash landing, as kicks to the
## spring (a second), landing's whole kick from LAND_HARD m/s; and the most
## it squashes and stretches.
const AIR_STRETCH := 0.15
const AIR_FAST := 9.0
const TAKE_OFF_DIP := 4.0
const LAND_KICK := 11.0
const LAND_HARD := 12.0
const STRETCH_MOST := Vector2(0.62,1.35)
## Radians it tips forward per m/s² setting off and stopping, and the most.
const TIP_GO := 0.008
const TIP_STOP := 0.012
const TIP_MOST := 0.24
## Radians the head turns into a turn per radian a second and the most, and
## nods per m/s of rise and the most (the neck takes some of the turn).
const LOOK := 0.05
const LOOK_MOST := 0.45
const NOD := 0.025
const NOD_MOST := 0.25
## Radians the arms fly out in the air.
const ARMS_UP := 0.7
## The chest's own lean (the legs keep the clips' planted boots): radians
## forward at a full run; forward per unit of slope climbed (back going
## down) and the most; rolled into a turn per radian a second of it at a
## full run and the most; the share of the look the chest leads a turn
## with (the neck and head turning the rest); and the share of its lean the
## head lifts back, to look ahead.
const RUN_LEAN := 0.15
const SLOPE_LEAN := 0.6
const SLOPE_MOST := 0.25
const CHEST_BANK := 0.03
const CHEST_BANK_MOST := 0.25
const CHEST_LEAD := 0.4
const HEAD_UP := 0.5

## The body turned about its feet (lean, yaw, bank), and in it the body
## about its hips (flip, squash and stretch).
var _tilt: Node3D
var _pivot: Node3D
var _model: Node3D
var _tree: AnimationTree
## The springs (Hz, then damping: under 1 overshoots) and their goals.
var _bank := Spring.new(2.6,0.5)
var _lean := Spring.new(3.0,0.38)
var _yaw := Spring.new(6.0,0.55)
var _stretch := Spring.new(4.0,0.3,1.0)
var _look := Spring.new(3.0,0.5)
var _nod := Spring.new(3.0,0.5)
var _arms := Spring.new(3.2,0.32)
var _hunch := Spring.new(2.5,0.45)
var _roll := Spring.new(3.0,0.45)
var _hunch_to := 0.0
var _roll_to := 0.0
## The feet last frame, for the slope climbed (INF: none yet).
var _feet_was := Vector3.INF
var _stretch_to := 1.0
var _look_to := 0.0
var _nod_to := 0.0
var _arms_to := 0.0
var _speed_was := 0.0
var _grounded_was := true
## 0 standing to 1 moving, the gait 0 walking to 1 running, and its phase
## (0 at the left boot's touchdown).
var _moving := 0.0
var _running := 0.0
var _phase := 0.0
var _facing_was := INF
## Standing (since it stopped), 0 to 1 into a skid, and the skid last frame.
var _standing := true
var _skid := 0.0
var _skidding_was := false
## The hop's seconds to go.
var _hop := 0.0
var _has_skid := false
var _idle_length := 1.0
var _skeleton: Skeleton3D
var _boots: Array[int] = []
## The bones the springs turn, and the model's axes in the skeleton's frame.
var _head := -1
var _chest := -1
var _neck := -1
var _upper_arms: Array[int] = []
var _to_skeleton := Basis.IDENTITY
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "Pilot"
	_tilt = Node3D.new()
	add_child(_tilt)
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0,HIPS,0.0)
	_tilt.add_child(_pivot)
	_model = MODEL.instantiate()
	_model.name = "Body"
	_model.position = Vector3(0.0,-HIPS,0.0)
	_pivot.add_child(_model)
	_dress()
	var player := _model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	_has_skid = player.has_animation(&"skid")
	_idle_length = player.get_animation(&"idle").length
	_skeleton = _model.find_children("*","Skeleton3D",true,false)[0]
	_boots = [_skeleton.find_bone("foot.L"),_skeleton.find_bone("foot.R")]
	_head = _skeleton.find_bone("head")
	_chest = _skeleton.find_bone("chest")
	_neck = _skeleton.find_bone("neck")
	_upper_arms = [_skeleton.find_bone("upper_arm.L"),_skeleton.find_bone("upper_arm.R")]
	var placed := Transform3D.IDENTITY
	var up: Node = _skeleton
	while up != _model:
		placed = (up as Node3D).transform*placed
		up = up.get_parent()
	_to_skeleton = placed.basis.inverse()
	_rng.randomize()
	for clip: String in ["idle","walk","run","skid"] if _has_skid else ["idle","walk","run"]:
		var animation := player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_LINEAR
		# Between the baked frames, smoothly.
		for track in range(animation.get_track_count()):
			animation.track_set_interpolation_type(track,Animation.INTERPOLATION_CUBIC)
	var blend := AnimationNodeBlendTree.new()
	for clip: StringName in [&"idle",&"walk",&"run"]:
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		blend.add_node(clip,node)
	for seek: StringName in [&"idle_at",&"walk_at",&"run_at"]: blend.add_node(seek,AnimationNodeTimeSeek.new())
	blend.add_node(&"gait",AnimationNodeBlend2.new())
	blend.add_node(&"move",AnimationNodeBlend2.new())
	blend.connect_node(&"idle_at",0,&"idle")
	blend.connect_node(&"walk_at",0,&"walk")
	blend.connect_node(&"run_at",0,&"run")
	blend.connect_node(&"gait",0,&"walk_at")
	blend.connect_node(&"gait",1,&"run_at")
	blend.connect_node(&"move",0,&"idle_at")
	blend.connect_node(&"move",1,&"gait")
	if _has_skid:
		var skid := AnimationNodeAnimation.new()
		skid.animation = &"skid"
		blend.add_node(&"skid_clip",skid)
		blend.add_node(&"skid_at",AnimationNodeTimeSeek.new())
		blend.add_node(&"skid",AnimationNodeBlend2.new())
		blend.connect_node(&"skid_at",0,&"skid_clip")
		blend.connect_node(&"skid",0,&"move")
		blend.connect_node(&"skid",1,&"skid_at")
		blend.connect_node(&"output",0,&"skid")
	else:
		blend.connect_node(&"output",0,&"move")
	_tree = AnimationTree.new()
	_tree.name = "Moves"
	_tree.tree_root = blend
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_model.add_child(_tree)
	_tree.anim_player = NodePath("../"+String(_model.get_path_to(player)))
	_tree.active = true
	_idle_anywhere()
	_apply()

## The folk's materials on the model, by its surfaces' names (on its own
## copy of the mesh, so the imported one keeps its own).
func _dress() -> void:
	var outfit := PersonKit.outfit()
	for node: MeshInstance3D in _model.find_children("*","MeshInstance3D",true,false):
		var mesh := node.mesh.duplicate() as ArrayMesh
		for i in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(i)
			var key := material.resource_name if material != null else ""
			if outfit.has(key): mesh.surface_set_material(i,outfit[key])
		node.mesh = mesh

## One frame of the motor's state. Returns what the body did this frame:
## "footfall" (0 the left boot touched down, 1 the right), "set_off" (moving
## from a stand), "turned" (whipped round out of a skid).
func drive(motor: RefCounted, delta: float) -> Dictionary:
	var out := {}
	var turned := 0.0
	if _facing_was != INF:
		# The body keeps facing where it did; its spring swings it round
		# after the motor's way (out of a skid, all the way round at once).
		var swung := angle_difference(_facing_was,motor.facing)
		_yaw.x = wrapf(_yaw.x-swung,-PI,PI)
		if _skidding_was and not motor.skidding and absf(swung) > 1.0:
			_hop = HOP_TIME
			out["turned"] = true
		elif delta > 0.0: turned = swung/delta
	_facing_was = motor.facing
	if _has_skid and motor.skidding and not _skidding_was:
		_tree.set(&"parameters/skid_at/seek_request",0.0)
		_lean.v += SKID_KICK
	_skidding_was = motor.skidding
	var speed: float = motor.speed()
	if motor.grounded and not motor.skidding:
		var moving := speed > STILL
		_moving = move_toward(_moving,1.0 if moving else 0.0,delta/FADE)
		if moving:
			if _standing: out["set_off"] = true
			_standing = false
			_running = smoothstep(BLEND_FROM,BLEND_TO,speed)
			var was := _phase
			_phase = fmod(_phase+speed/stride(_running)*delta,1.0)
			if _phase < was: out["footfall"] = 0
			elif was < 0.5 and _phase >= 0.5: out["footfall"] = 1
		elif not _standing:
			_standing = true
			_idle_anywhere()
	_skid = move_toward(_skid,1.0 if motor.skidding else 0.0,delta/(SKID_IN if motor.skidding else SKID_OUT))
	# Setting off and stopping, it tips forward, and wobbles back upright.
	var accel := (speed-_speed_was)/delta if delta > 0.0 and motor.grounded else 0.0
	_speed_was = speed
	var tip := -minf(absf(accel)*(TIP_GO if accel > 0.0 else TIP_STOP),TIP_MOST)
	var pace := clampf(speed/RUN_SPEED,0.0,1.0)
	var bank := _bank.step(clampf(turned*BANK*pace,-BANK_MOST,BANK_MOST) if motor.grounded else 0.0,delta)
	var lean := _lean.step((0.0 if _has_skid else SKID_LEAN) if motor.skidding else tip,delta)
	_tilt.rotation = Vector3(lean,_yaw.step(0.0,delta),bank)
	var flip := -TAU*smoothstep(0.0,1.0,motor.flip) if motor.flip >= 0.0 else 0.0
	_pivot.rotation = Vector3(flip,0.0,0.0)
	# Off the ground: a dip taking off, then stretched along the way it
	# goes; the head nods with it and the arms fly out.
	var rise: float = motor.velocity.y
	if not motor.grounded and _grounded_was and rise > 0.0: _stretch.v -= TAKE_OFF_DIP
	_grounded_was = motor.grounded
	_stretch_to = 1.0 if motor.grounded else 1.0+AIR_STRETCH*clampf(absf(rise)/AIR_FAST,0.0,1.0)
	_nod_to = 0.0 if motor.grounded else clampf(rise*NOD,-NOD_MOST,NOD_MOST)
	_arms_to = 0.0 if motor.grounded else 1.0
	_look_to = clampf(turned*LOOK,-LOOK_MOST,LOOK_MOST) if motor.grounded else 0.0
	# The chest leans into the run and the slope climbed, and rolls into a
	# turn.
	var feet: Vector3 = motor.feet
	var across := Vector2(feet.x-_feet_was.x,feet.z-_feet_was.z).length() if _feet_was.is_finite() else 0.0
	var climb := clampf((feet.y-_feet_was.y)/across,-1.0,1.0) if motor.grounded and across > 0.001 else 0.0
	_feet_was = feet
	_hunch_to = -(RUN_LEAN*pace+clampf(climb*SLOPE_LEAN,-SLOPE_MOST,SLOPE_MOST)) if motor.grounded and not motor.skidding else 0.0
	_roll_to = clampf(turned*CHEST_BANK*pace,-CHEST_BANK_MOST,CHEST_BANK_MOST) if motor.grounded else 0.0
	_advance(delta)
	return out

## Where boot `side` (0 the left, 1 the right) stands, in the world: under
## its ankle, at the feet's height.
func boot(side: int) -> Vector3:
	var at := _skeleton.global_transform*_skeleton.get_bone_global_pose(_boots[side]).origin
	return Vector3(at.x,global_position.y,at.z)

## Metres a full gait cycle (both feet) covers, `running` 0 walking to 1
## running.
static func stride(running: float) -> float:
	return lerpf(WALK_SPEED*WALK_CYCLE,RUN_SPEED*RUN_CYCLE,running)

## A hop not driven by the motor (in and out of the plane): `rise` 1 going
## up to -1 coming down.
func hop(_rise: float, delta: float) -> void:
	_moving = move_toward(_moving,0.0,delta/FADE)
	_skid = 0.0
	_tilt.rotation = Vector3.ZERO
	_pivot.rotation = Vector3.ZERO
	_stretch_to = 1.0
	_look_to = 0.0
	_nod_to = 0.0
	_arms_to = 0.6
	_hunch_to = 0.0
	_roll_to = 0.0
	_advance(delta)

## Came down `hard` metres a second: squashed as hard, springing back.
func land(hard: float) -> void:
	_stretch.v -= LAND_KICK*clampf(hard/LAND_HARD,0.0,1.0)

## Stood still, as set down.
func settle() -> void:
	_facing_was = INF
	_moving = 0.0
	_skid = 0.0
	_skidding_was = false
	_hop = 0.0
	_standing = true
	_speed_was = 0.0
	_grounded_was = true
	_feet_was = Vector3.INF
	_hunch_to = 0.0
	_roll_to = 0.0
	for spring: Spring in [_bank,_lean,_yaw,_look,_nod,_arms,_hunch,_roll]:
		spring.x = 0.0
		spring.v = 0.0
	_stretch.x = 1.0
	_stretch.v = 0.0
	_stretch_to = 1.0
	_look_to = 0.0
	_nod_to = 0.0
	_arms_to = 0.0
	_tilt.rotation = Vector3.ZERO
	_idle_anywhere()
	_apply()
	_tree.advance(0.0)

## The blend and the gait's place in its clips, for the next advance.
func _apply() -> void:
	_tree.set(&"parameters/move/blend_amount",smoothstep(0.0,1.0,_moving))
	_tree.set(&"parameters/gait/blend_amount",_running)
	_tree.set(&"parameters/walk_at/seek_request",_phase*WALK_CYCLE)
	_tree.set(&"parameters/run_at/seek_request",_phase*RUN_CYCLE)
	if _has_skid: _tree.set(&"parameters/skid/blend_amount",smoothstep(0.0,1.0,_skid))

## The idle taken up at a random moment of its loop.
func _idle_anywhere() -> void:
	_tree.set(&"parameters/idle_at/seek_request",_rng.randf()*_idle_length)

func _advance(delta: float) -> void:
	_apply()
	_tree.advance(delta)
	_springs(delta)
	# Squashed and stretched about the hips, its volume kept and its feet
	# on the ground.
	var stretch := clampf(_stretch.step(_stretch_to,delta),STRETCH_MOST.x,STRETCH_MOST.y)
	_pivot.scale = Vector3(1.0/sqrt(stretch),stretch,1.0/sqrt(stretch))
	# The hop out of a skid's turn.
	_hop = maxf(0.0,_hop-delta)
	var hop := HOP*sin(PI*(1.0-_hop/HOP_TIME)) if _hop > 0.0 else 0.0
	_pivot.position = Vector3(0.0,HIPS*stretch+hop,0.0)

## The springs' turns on the clips' pose, this frame: the chest leaning
## and rolling, and leading a turn the head (and a little the neck) looks
## into, the head nodding with a jump and lifting to look ahead, the arms
## flown out (and, flopping back, a touch in, never into the body).
func _springs(delta: float) -> void:
	var look := _look.step(_look_to,delta)
	var nod := _nod.step(_nod_to,delta)
	var arms := maxf(_arms.step(_arms_to,delta),-0.15)*ARMS_UP
	var hunch := _hunch.step(_hunch_to,delta)
	var roll := _roll.step(_roll_to,delta)
	if _head < 0 or _neck < 0 or _chest < 0 or _upper_arms.has(-1): return
	_turn_bone(_chest,Vector3.RIGHT,hunch)
	_turn_bone(_chest,Vector3.BACK,roll)
	_turn_bone(_chest,Vector3.UP,look*CHEST_LEAD)
	_turn_bone(_neck,Vector3.UP,look*(1.0-CHEST_LEAD)*0.4)
	_turn_bone(_head,Vector3.UP,look*(1.0-CHEST_LEAD)*0.6)
	_turn_bone(_head,Vector3.RIGHT,nod-hunch*HEAD_UP)
	# Out is down the -X side for the left arm, +X for the right.
	_turn_bone(_upper_arms[0],Vector3.BACK,-arms)
	_turn_bone(_upper_arms[1],Vector3.BACK,arms)

## Turns `bone` by `angle` about `axis` (the model's), on top of its pose.
func _turn_bone(bone: int, axis: Vector3, angle: float) -> void:
	if absf(angle) < 0.0005: return
	var local := (_skeleton.get_bone_global_pose(bone).basis.inverse()*(_to_skeleton*axis)).normalized()
	_skeleton.set_bone_pose_rotation(bone,_skeleton.get_bone_pose_rotation(bone)*Quaternion(local,angle))
