extends Node3D
## The pilot on foot, drawn: one of the sky folk, the islanders' compact body
## rigged and animated in Blender (art/blender/pilot/pilot_build.py,
## assets/models/pilot.glb), moved by scripts/pilot_motor.gd. Its clips:
##   idle  standing: breathing, the weight drifting foot to foot;
##   walk  a quick little toddle, made for WALK_SPEED m/s: a light touch on
##         the stick, and starting and stopping;
##   run   the pace he goes by default, made for RUN_SPEED m/s;
##   skid  braking hard, leant back, a boot braced ahead (when the model has
##         it);
##   hang, shimmy_left, shimmy_right, climb  on a ledge (when the model has
##         them): hanging by the mitts from a lip, swaying; hand over hand
##         along it, made for SHIMMY_SPEED m/s; up onto it, one go of
##         CLIMB_LENGTH s, which played back lowers him into the hang;
##   swim, tread  in deep water (when the model has them): a doggy paddle
##         made for SWIM_SPEED m/s, and treading water (TREAD_LENGTH s);
##   crouch, long_jump, wall_slide, wall_kick, pump, slide, twirl, side_flip
##         the motor's moves (when the model has them): crouched low; diving
##         out flat in the long jump; a hand on the wall, boots braced,
##         sliding down it; kicked off it (once); the pump's fist punched up
##         (once); boot-surfing down a slope, knees bent, arms out; twirling,
##         arms flung out; the side flip's spring, tuck and opening (once);
##   jump_rise, jump_fall  in the air (when the model has them): going up,
##         a knee driven up, and coming down, arms up and paddling, legs
##         reaching for the ground.
## Walk and run are played in step, both at one gait phase, and blended by
## the speed: the phase moves on by the distance covered over the stride the
## blend has (a walk's stride is shorter than a run's), so at either clip's
## own speed the planted boots stay on the ground. A boot touches down as
## the phase passes 0 (the left) and a half (the right): `drive` tells the
## walker, which sounds the step and puffs the dust there. Standing still it
## cross-fades to idle, taken up at a random moment of its long loop so no
## two stops stand alike.
##
## In the air the rise blends into the fall by how fast he goes up or down
## (the top of a jump half of each), faded in leaving the ground and out
## quickly landing. The motor's moves (its `move`) fade their clips in over
## everything on the ground and in the air, each with a kick to the springs
## as it starts: the pump dips deeper and stretches further, a crouch
## squashes and settles, the long jump tips forward, a wall slaps him flat
## against it, a kick off it stretches him as he whips round, a surf squats
## him onto his boots and tips him down the slope (SLIDE_TILT of it), a
## twirl stretches him and spins him round TWIRL_TURNS times about his
## middle over TWIRL_SPIN s, and the side flip springs him up and rolls him
## over sideways once over FLIP_SPIN s. Thrown back at a run it skids,
## leaning back, and coming out of it whips round to face the new way with
## a little hop.
##
## On a ledge (the motor's `hold`) it plays the hang, blended into the
## shimmy by its pace and in its step as the walk is (the gripping mitts stay
## on the lip), and the climb at the motor's place in it. A catch in the air
## fades in fast and jolts: the body stretches from the hands and swings
## under them; turning on an edge to lower over it, it whips round on its
## springs first. The climb and the lowering move the body in the clip, so
## they cut in and out without a fade, the hang's first frame being the
## climb's and the idle's first its last.
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
## In water (the motor's `wade` and `swimming`): wading, he lifts his knees
## higher through each swing and holds his arms a little up and out for
## balance, more the deeper it is (WADE_FULL); swimming, the paddle is
## blended with the treading by his pace and in step with it (each stroke
## tells the walker, "stroke"), the body bobbing gently on the water. Out
## of it he drips a while (`soak`: points the walker drops droplets from,
## off the wet mitts, the hem and the trousers) and his clothes stay dark
## where the water reached, drying back over DRY_TIME s.
##
## The model's own materials are swapped for the pilot's paint (scripts/
## pilot_paint.gd, by surface name): soft toon bands, not the islanders'
## lacquer.
##
## Its origin is the feet, facing -Z; the walker (scripts/wanderer_eye.gd)
## puts it where the motor's feet are and turns it to its facing.

const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PersonKit = preload("res://scripts/person_kit.gd")
const PilotPaint = preload("res://scripts/pilot_paint.gd")
const Spring = PersonKit.Spring
const MODEL := preload("res://assets/models/pilot.glb")
## The clips' ground speeds (m/s) and loops (s), as pilot_build.py made them.
const WALK_SPEED := 1.4
const WALK_CYCLE := 0.5
const RUN_SPEED := 4.8
const RUN_CYCLE := 0.3
const HANG_LENGTH := 4.0
const SHIMMY_SPEED := 0.7
const SHIMMY_CYCLE := 0.5
const CLIMB_LENGTH := 0.4
## Seconds the hang fades in catching a lip in the air, the climb fades in
## from the hang, the hang back from the end of a lowering, and the
## shimmy's turn of way.
const GRAB_FADE := 0.08
const CLIMB_FADE := 0.1
const HUNG_FADE := 0.12
const SHIMMY_TURN := 0.1
## The catch's jolt: a kick to the stretch (hanging from the hands) and a
## swing of the legs out from the wall (radians a second).
const GRAB_KICK := 3.0
const GRAB_SWING := -1.6
## Where the hands grip, hanging (the body sways and stretches about them).
const GRIP := Vector3(0.0,PilotMotor.HANG_DROP,-PilotMotor.HANG_OUT-0.03)
## The speeds (m/s) between which the walk gives way to the run.
const BLEND_FROM := 1.9
const BLEND_TO := 4.0
## Under this speed (m/s) it stands.
const STILL := 0.15
## Seconds a cross-fade between standing and moving takes, about.
const FADE := 0.12
## The swim's ground speed (m/s) and stroke loop (s), the tread's loop, as
## pilot_build.py made them; seconds the swim fades in and out, the pace's
## share of SWIM_SPEED at which the paddle has taken over from the tread; the
## bob on the water (m, Hz).
const SWIM_SPEED := 1.2
const SWIM_CYCLE := 0.8
const TREAD_LENGTH := 1.6
const SWIM_FADE := 0.25
const SWIM_BLEND := 0.5
const BOB := 0.018
const BOB_RATE := 0.45
## Wading: the depth (m) of the fullest wading gait; the thigh lifted and
## the shin tucked through a swing (radians), and the arms up and out.
const WADE_FULL := 0.5
const WADE_KNEE := 0.55
const WADE_SHIN := 0.75
const WADE_ARMS := 0.45
const WADE_ELBOWS := 0.35
## Out of the water: seconds he drips, drips a second at first, seconds his
## clothes take to dry; the wet line's rest height (m) per metre of water at
## the feet (rest stands the hips higher than play does), and where the
## drips come from, in rest heights (m): the mitts, the jacket's hem, the
## trousers at the knee; the highest it wets, the shoulders (the head stays
## out, swimming).
const DRIP_TIME := 4.0
const DRIP_RATE := 22.0
const DRY_TIME := 15.0
const WET_REST := 1.17
const DRIP_MITTS := 0.4
const DRIP_HEM := 0.48
const DRIP_KNEES := 0.2
const WET_MOST := 0.8
## The moves' clips (pilot_build.py "the moves"): the motor's move each
## stands for, its clip and length (s); seconds they fade in and out. The
## springs' kicks as one starts (a second): the pump's deeper dip and its
## stretch, a crouch's squash, the long jump's tip forward (and the lean it
## holds, radians), the slap onto a wall, the stretch of a kick off it.
const MOVE_CLIPS := {"crouch":["crouch",1.0],"long":["long_jump",0.5],"wall":["wall_slide",0.5],"kick":["wall_kick",0.4],"pump":["pump",0.5],
	"slide":["slide",0.8],"twirl":["twirl",0.4],"flip":["side_flip",0.7]}
## Under the pocket sail: the arms' turn up overhead and the elbows' bend
## (radians), and the seconds they take to go up.
const SAIL_ARMS := Vector2(2.6,0.3)
const SAIL_ARMS_TIME := 0.12
## The moves' clips played once (held on their last frame).
const ONCE := ["kick","pump","flip"]
const MOVE_IN := 0.07
const MOVE_OUT := 0.15
const PUMP_DIP := 3.0
const PUMP_STRETCH := 6.0
const CROUCH_SQUASH := 4.0
const LONG_TIP := 2.5
const LONG_LEAN := -0.12
const WALL_SLAP := 5.0
const KICK_STRETCH := 4.0
## The tricks: the surf's squash onto the boots and its tip down the slope
## (a share of the slope's angle, the most forward); the twirl's stretch,
## its turns and seconds (fast, then easing); the side flip's spring, and
## its one roll's seconds (the tuck at its middle).
const SLIDE_SQUASH := 3.0
const SLIDE_TILT := 0.5
const SLIDE_TIP_MOST := 0.45
const TWIRL_STRETCH := 3.0
const TWIRL_TURNS := 2.0
const TWIRL_SPIN := 0.4
const FLIP_STRETCH := 5.0
const FLIP_SPIN := 0.55
## The air's clips (pilot_build.py JUMP_LENGTH), seconds they fade in leaving
## the ground and out landing, the rise (m/s) by which the fall has taken
## over (and from which the rise has), and the arms' spring's share in the
## air over them.
const AIR_LENGTH := 0.5
const AIR_IN := 0.1
const AIR_OUT := 0.06
const AIR_RISEN := 1.5
const AIR_FALLEN := -2.0
const AIR_ARMS := 0.3
## The pelvis over the feet (pilot_build.py HIPS).
const HIPS := 0.4329
## Radians of bank per radian a second of turn at a full run, and the most.
const BANK := 0.06
const BANK_MOST := 0.35
## Radians he leans off a wall run along (his feet to the wall).
const WALLRUN_BANK := 0.45
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
## forward at a full run, on the clip's own few degrees (as the walk gives
## way to the run, none walking: a cartoon run stays fairly upright, about
## 11 degrees in all); forward per unit of slope climbed (back going
## down) and the most; rolled into a turn per radian a second of it at a
## full run and the most; the share of the look the chest leads a turn
## with (the neck and head turning the rest); and the share of its lean the
## head lifts back, to look ahead.
const RUN_LEAN := 0.08
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
var _has_ledge := false
## The moves: the model has their clips; each clip's weight (0 to 1) and
## seconds into it (held where it was as it fades out); the move last frame.
var _has_moves := false
var _move_weights := {}
var _move_times := {}
var _move_was := ""
## The air: the model has its clips; 0 to 1 into them, the fall's share over
## the rise, and the loops' time. The spins: the yaw's and the roll's angle
## now, where each started, its seconds in and its whole (turns, seconds).
var _has_air := false
var _air := 0.0
var _air_fall := 0.0
var _air_time := 0.0
var _spin := Vector2.ZERO
var _spin_from := Vector2.ZERO
var _spin_t := Vector2(INF,INF)
var _spin_of := Vector4.ZERO
## On a ledge: the motor's hold last frame, 0 to 1 onto the ledge's clips,
## into the climb, into the shimmy, its way (0 left, 1 right) and its
## phase, and the hang's own time.
var _hold_was := ""
var _ledge := 0.0
var _climbing := 0.0
var _shimmying := 0.0
var _shimmy_way := 1.0
var _shimmy_phase := 0.0
var _hang_time := 0.0
var _climb_at := 0.0
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
## In water: the swim's clips there, 0 to 1 into them, the paddle's share
## over the tread, the paddle's phase and the tread's time, the bob's clock,
## swimming last frame; the wading gait's share; wet (1 soaked to 0 dry) and
## up to where (rest height, m), seconds of dripping left and drips due; the
## paint's materials; the legs', forearms' and hands' bones.
var _has_swim := false
var _swim := 0.0
var _paddle := 0.0
var _swim_phase := 0.0
var _tread_time := 0.0
var _bob_time := 0.0
var _swimming_was := false
var _wade := 0.0
var wet := 0.0
var wet_line := 0.0
var drip_left := 0.0
var _drip_due := 0.0
var _paints: Array[ShaderMaterial] = []
var _thighs: Array[int] = []
var _shins: Array[int] = []
var _hands: Array[int] = []
var _forearms: Array[int] = []
## Skydiving (`dive`): the pose eased to, as Vector4s of (upper arms out,
## elbows bent, thighs forward, shins tucked) and (legs apart, head up,
## unused, unused); seconds into the pop's flail.
var _dive_a := Vector4.ZERO
## How far the arms are up holding the pocket sail (0 to 1).
var _sail := 0.0
var _dive_b := Vector4.ZERO
var _dive_time := 0.0

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
	_has_ledge = player.has_animation(&"hang") and player.has_animation(&"climb")
	_has_swim = player.has_animation(&"swim") and player.has_animation(&"tread")
	_has_moves = MOVE_CLIPS.values().all(func(c: Array) -> bool: return player.has_animation(StringName(c[0])))
	_has_air = player.has_animation(&"jump_rise") and player.has_animation(&"jump_fall")
	_idle_length = player.get_animation(&"idle").length
	_skeleton = _model.find_children("*","Skeleton3D",true,false)[0]
	_boots = [_skeleton.find_bone("foot.L"),_skeleton.find_bone("foot.R")]
	_head = _skeleton.find_bone("head")
	_chest = _skeleton.find_bone("chest")
	_neck = _skeleton.find_bone("neck")
	_upper_arms = [_skeleton.find_bone("upper_arm.L"),_skeleton.find_bone("upper_arm.R")]
	_thighs = [_skeleton.find_bone("thigh.L"),_skeleton.find_bone("thigh.R")]
	_shins = [_skeleton.find_bone("shin.L"),_skeleton.find_bone("shin.R")]
	_hands = [_skeleton.find_bone("hand.L"),_skeleton.find_bone("hand.R")]
	_forearms = [_skeleton.find_bone("forearm.L"),_skeleton.find_bone("forearm.R")]
	var placed := Transform3D.IDENTITY
	var up: Node = _skeleton
	while up != _model:
		placed = (up as Node3D).transform*placed
		up = up.get_parent()
	_to_skeleton = placed.basis.inverse()
	_rng.randomize()
	var clips: Array[String] = ["idle","walk","run"]
	if _has_skid: clips.append("skid")
	if _has_ledge: clips.append_array(["hang","shimmy_left","shimmy_right","climb"])
	if _has_swim: clips.append_array(["swim","tread"])
	if _has_moves:
		for move: String in MOVE_CLIPS: clips.append(MOVE_CLIPS[move][0])
	if _has_air: clips.append_array(["jump_rise","jump_fall"])
	for clip: String in clips:
		var animation := player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_NONE if clip in ["climb","wall_kick","pump","side_flip"] else Animation.LOOP_LINEAR
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
	var ground := &"skid" if _has_skid else &"move"
	if _has_air:
		# In the air: the rise blended into the fall, over the ground's.
		for clip: StringName in [&"jump_rise",&"jump_fall"]:
			var node := AnimationNodeAnimation.new()
			node.animation = clip
			blend.add_node(StringName(String(clip)+"_clip"),node)
			blend.add_node(StringName(String(clip)+"_at"),AnimationNodeTimeSeek.new())
			blend.connect_node(StringName(String(clip)+"_at"),0,StringName(String(clip)+"_clip"))
		blend.add_node(&"air_way",AnimationNodeBlend2.new())
		blend.add_node(&"air",AnimationNodeBlend2.new())
		blend.connect_node(&"air_way",0,&"jump_rise_at")
		blend.connect_node(&"air_way",1,&"jump_fall_at")
		blend.connect_node(&"air",0,ground)
		blend.connect_node(&"air",1,&"air_way")
		ground = &"air"
	if _has_moves:
		# Each move's clip blended in over what comes before it.
		for move: String in MOVE_CLIPS:
			var node := AnimationNodeAnimation.new()
			node.animation = StringName(MOVE_CLIPS[move][0])
			blend.add_node(StringName(move+"_clip"),node)
			blend.add_node(StringName(move+"_at"),AnimationNodeTimeSeek.new())
			blend.connect_node(StringName(move+"_at"),0,StringName(move+"_clip"))
			blend.add_node(StringName(move+"_mix"),AnimationNodeBlend2.new())
			blend.connect_node(StringName(move+"_mix"),0,ground)
			blend.connect_node(StringName(move+"_mix"),1,StringName(move+"_at"))
			ground = StringName(move+"_mix")
			_move_weights[move] = 0.0
			_move_times[move] = 0.0
	var top := ground
	if _has_ledge:
		for clip: StringName in [&"hang",&"shimmy_left",&"shimmy_right",&"climb"]:
			var node := AnimationNodeAnimation.new()
			node.animation = clip
			blend.add_node(StringName(String(clip)+"_clip"),node)
			blend.add_node(StringName(String(clip)+"_at"),AnimationNodeTimeSeek.new())
			blend.connect_node(StringName(String(clip)+"_at"),0,StringName(String(clip)+"_clip"))
		for mix: StringName in [&"shimmy_way",&"shimmy",&"climbing",&"ledge"]: blend.add_node(mix,AnimationNodeBlend2.new())
		blend.connect_node(&"shimmy_way",0,&"shimmy_left_at")
		blend.connect_node(&"shimmy_way",1,&"shimmy_right_at")
		blend.connect_node(&"shimmy",0,&"hang_at")
		blend.connect_node(&"shimmy",1,&"shimmy_way")
		blend.connect_node(&"climbing",0,&"shimmy")
		blend.connect_node(&"climbing",1,&"climb_at")
		blend.connect_node(&"ledge",0,ground)
		blend.connect_node(&"ledge",1,&"climbing")
		top = &"ledge"
	if _has_swim:
		# In deep water: the tread blended into the paddle by the pace, over
		# everything else.
		for clip: StringName in [&"swim",&"tread"]:
			var node := AnimationNodeAnimation.new()
			node.animation = clip
			blend.add_node(StringName(String(clip)+"_clip"),node)
			blend.add_node(StringName(String(clip)+"_at"),AnimationNodeTimeSeek.new())
			blend.connect_node(StringName(String(clip)+"_at"),0,StringName(String(clip)+"_clip"))
		blend.add_node(&"paddle",AnimationNodeBlend2.new())
		blend.add_node(&"water",AnimationNodeBlend2.new())
		blend.connect_node(&"paddle",0,&"tread_at")
		blend.connect_node(&"paddle",1,&"swim_at")
		blend.connect_node(&"water",0,top)
		blend.connect_node(&"water",1,&"paddle")
		top = &"water"
	blend.connect_node(&"output",0,top)
	_tree = AnimationTree.new()
	_tree.name = "Moves"
	_tree.tree_root = blend
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_model.add_child(_tree)
	_tree.anim_player = NodePath("../"+String(_model.get_path_to(player)))
	_tree.active = true
	_idle_anywhere()
	_apply()

## The pilot's paint on the model, by its surfaces' names (on its own copy
## of the mesh, so the imported one keeps its own).
func _dress() -> void:
	var outfit := PilotPaint.outfit()
	for node: MeshInstance3D in _model.find_children("*","MeshInstance3D",true,false):
		var mesh := node.mesh.duplicate() as ArrayMesh
		for i in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(i)
			var key := material.resource_name if material != null else ""
			if outfit.has(key): mesh.surface_set_material(i,outfit[key])
		node.mesh = mesh
	for key: String in outfit: _paints.append(outfit[key])

## One frame of the motor's state. Returns what the body did this frame:
## "footfall" (0 the left boot touched down, 1 the right), "set_off" (moving
## from a stand), "turned" (whipped round out of a skid).
func drive(motor: RefCounted, delta: float) -> Dictionary:
	var swimming: bool = "swimming" in motor and motor.swimming
	var depth := float(motor.get("wade")) if "wade" in motor else 0.0
	_wade = move_toward(_wade,0.0 if swimming else clampf(depth/WADE_FULL,0.0,1.0),delta*4.0)
	if _has_swim and swimming:
		_moves("",delta)
		return _drive_swim(motor,delta)
	_swimming_was = false
	_swim = move_toward(_swim,0.0,delta/SWIM_FADE)
	var hold: String = motor.hold if _has_ledge and "hold" in motor else ""
	var move: String = motor.move if "move" in motor and hold == "" else ""
	_moves(move,delta)
	if hold != "" or _hold_was != "": return _drive_ledge(motor,hold,delta)
	_ledge = move_toward(_ledge,0.0,delta/GRAB_FADE)
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
	# Running along a wall runs as on the ground.
	if (motor.grounded or move == "wallrun") and not motor.skidding and move != "crouch" and move != "slide":
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
	var feet: Vector3 = motor.feet
	var across := Vector2(feet.x-_feet_was.x,feet.z-_feet_was.z).length() if _feet_was.is_finite() else 0.0
	var climb := clampf((feet.y-_feet_was.y)/across,-1.5,1.5) if motor.grounded and across > 0.001 else 0.0
	_feet_was = feet
	var bank_to := clampf(turned*BANK*pace,-BANK_MOST,BANK_MOST) if motor.grounded else 0.0
	if move == "wallrun":
		# Leant off the wall, the head away from it: rolled left with the
		# wall on his right.
		var f: Vector2 = motor.forward(motor.facing)
		var right := Vector2(-f.y,f.x)
		bank_to = WALLRUN_BANK if (motor.wall_out as Vector2).dot(right) < 0.0 else -WALLRUN_BANK
	var bank := _bank.step(bank_to,delta)
	var lean_to := tip
	if motor.skidding: lean_to = 0.0 if _has_skid else SKID_LEAN
	elif move == "long": lean_to = LONG_LEAN
	elif move == "slide": lean_to = clampf(atan(climb)*SLIDE_TILT,-SLIDE_TIP_MOST,0.15)
	var lean := _lean.step(lean_to,delta)
	_tilt.rotation = Vector3(lean,_yaw.step(0.0,delta),bank)
	# Off the ground: a dip taking off, then stretched along the way it
	# goes; the head nods with it and the arms fly out (the air's clips
	# throw them most of the way).
	var rise: float = motor.velocity.y
	if not motor.grounded and _grounded_was and rise > 0.0: _stretch.v -= TAKE_OFF_DIP
	_grounded_was = motor.grounded
	var aloft: bool = not motor.grounded and (move == "" or move == "jump")
	# Under the sail, the arms up over the idle (as the dive's are), not
	# over the air's clips, whose arms are already up.
	_sail = move_toward(_sail,1.0 if move == "sail" else 0.0,delta/SAIL_ARMS_TIME)
	if move == "sail": _moving = move_toward(_moving,0.0,delta/FADE)
	_air = move_toward(_air,1.0 if aloft else 0.0,delta/(AIR_IN if aloft else AIR_OUT))
	_air_fall = move_toward(_air_fall,clampf((AIR_RISEN-rise)/(AIR_RISEN-AIR_FALLEN),0.0,1.0),delta*5.0)
	_air_time = fmod(_air_time+delta,AIR_LENGTH)
	_stretch_to = 1.0 if motor.grounded else 1.0+AIR_STRETCH*clampf(absf(rise)/AIR_FAST,0.0,1.0)
	_nod_to = 0.0 if motor.grounded else clampf(rise*NOD,-NOD_MOST,NOD_MOST)
	_arms_to = 0.0 if motor.grounded or move == "sail" or (_has_moves and not aloft) else (AIR_ARMS if _has_air else 1.0)
	_look_to = clampf(turned*LOOK,-LOOK_MOST,LOOK_MOST) if motor.grounded else 0.0
	# The chest leans into the run and the slope climbed, and rolls into a
	# turn.
	_hunch_to = -(RUN_LEAN*pace*_running+clampf(climb*SLOPE_LEAN,-SLOPE_MOST,SLOPE_MOST)) if motor.grounded and not motor.skidding and move != "crouch" and move != "slide" else 0.0
	_roll_to = clampf(turned*CHEST_BANK*pace,-CHEST_BANK_MOST,CHEST_BANK_MOST) if motor.grounded else 0.0
	_pivot.rotation = _spun(delta)
	_advance(delta)
	return out

## The spins this frame (a twirl's about up, a side flip's about forward),
## each run through to its whole turns whatever the motor does meanwhile:
## the pivot's turn.
func _spun(delta: float) -> Vector3:
	for i in range(2):
		if _spin_t[i] == INF: continue
		_spin_t[i] += delta
		var u := clampf(_spin_t[i]/_spin_of[i*2+1],0.0,1.0)
		# The twirl whips round and eases; the flip springs, tucks and opens.
		var eased := 1.0-(1.0-u)*(1.0-u) if i == 0 else smoothstep(0.0,1.0,u)
		_spin[i] = _spin_from[i]+TAU*_spin_of[i*2]*eased
		if u >= 1.0:
			_spin[i] = 0.0
			_spin_t[i] = INF
	return Vector3(0.0,_spin.x,_spin.y)

## A spin started: about up (0) or forward (1), `turns` round (the way by
## its sign) over `seconds`.
func _spin_up(i: int, turns: float, seconds: float) -> void:
	_spin_from[i] = fposmod(_spin[i],TAU)
	_spin_t[i] = 0.0
	_spin_of[i*2] = turns
	_spin_of[i*2+1] = seconds

## The moves' clips faded to `move` (the motor's), each kicking the springs
## as it starts.
func _moves(move: String, delta: float) -> void:
	if move != _move_was:
		if _move_times.has(move): _move_times[move] = 0.0
		match move:
			"slide": _stretch.v -= SLIDE_SQUASH
			"twirl":
				_stretch.v += TWIRL_STRETCH
				_spin_up(0,TWIRL_TURNS,TWIRL_SPIN)
			"flip":
				_stretch.v += FLIP_STRETCH
				_spin_up(1,-1.0,FLIP_SPIN)
			"pump": _stretch.v += PUMP_STRETCH-PUMP_DIP
			"crouch": _stretch.v -= CROUCH_SQUASH
			"long": _lean.v -= LONG_TIP
			"wall": _stretch.v -= WALL_SLAP
			"kick": _stretch.v += KICK_STRETCH
		if _move_was == "crouch" and move == "": _stretch.v += CROUCH_SQUASH*0.5
		_move_was = move
	if _move_times.has(move): _move_times[move] += delta
	for key: String in _move_weights:
		var on := key == move
		_move_weights[key] = move_toward(_move_weights[key],1.0 if on else 0.0,delta/(MOVE_IN if on else MOVE_OUT))

## One frame afloat: the tread blended into the paddle by the pace, the
## paddle in step with it; turning a beat behind its way as on foot, banked
## a little into a turn, bobbing on the water. Returns "stroke" (0 the left
## mitt's pull, 1 the right's) as the paddle or the tread pushes the water.
func _drive_swim(motor: RefCounted, delta: float) -> Dictionary:
	var out := {}
	if not _swimming_was:
		# Into the water: the run's and the air's springs let go of.
		for spring: Spring in [_bank,_look,_nod,_arms,_hunch,_roll,_lean]:
			spring.x = 0.0
			spring.v = 0.0
		_skid = 0.0
		_skidding_was = false
		_hold_was = ""
		_spin_t = Vector2(INF,INF)
		_spin = Vector2.ZERO
		_air = 0.0
		_tread_time = _rng.randf()*TREAD_LENGTH
	_swimming_was = true
	_ledge = move_toward(_ledge,0.0,delta/GRAB_FADE)
	_climbing = 0.0
	var turned := 0.0
	if _facing_was != INF:
		var swung := angle_difference(_facing_was,motor.facing)
		_yaw.x = wrapf(_yaw.x-swung,-PI,PI)
		if delta > 0.0: turned = swung/delta
	_facing_was = motor.facing
	var speed: float = motor.speed()
	_swim = move_toward(_swim,1.0,delta/SWIM_FADE)
	_moving = move_toward(_moving,0.0,delta/FADE)
	_standing = true
	_paddle = move_toward(_paddle,clampf(speed/(SWIM_SPEED*SWIM_BLEND),0.0,1.0),delta*3.0)
	var was := _swim_phase
	_swim_phase = fmod(_swim_phase+speed/(SWIM_SPEED*SWIM_CYCLE)*delta,1.0)
	var tread_was := _tread_time
	_tread_time = fmod(_tread_time+delta,TREAD_LENGTH)
	if _paddle > 0.5:
		if _swim_phase < was: out["stroke"] = 0
		elif was < 0.5 and _swim_phase >= 0.5: out["stroke"] = 1
	elif _tread_time < tread_was: out["stroke"] = 0
	elif tread_was < TREAD_LENGTH*0.5 and _tread_time >= TREAD_LENGTH*0.5: out["stroke"] = 1
	_bob_time += delta
	var pace := clampf(speed/SWIM_SPEED,0.0,1.0)
	var bank := _bank.step(clampf(turned*BANK*pace,-BANK_MOST,BANK_MOST),delta)
	_tilt.rotation = Vector3(_lean.step(0.0,delta),_yaw.step(0.0,delta),bank)
	_tilt.position = Vector3.ZERO
	_pivot.rotation = Vector3.ZERO
	_stretch_to = 1.0
	_nod_to = 0.0
	_arms_to = 0.0
	_look_to = clampf(turned*LOOK,-LOOK_MOST,LOOK_MOST)
	_hunch_to = 0.0
	_roll_to = 0.0
	_speed_was = speed
	_grounded_was = false
	_feet_was = Vector3.INF
	_advance(delta)
	# Bobbing gently on the water.
	_pivot.position.y += BOB*sin(TAU*BOB_RATE*_bob_time)
	return out

## One frame of the water on him (the motor's `wade` and `swimming`): in it
## he is soaked up to where it reaches; out of it he drips for DRIP_TIME s,
## less and less, and dries over DRY_TIME s. Returns the points (world) a
## drip falls from this frame: off the wet mitts, the jacket's hem and the
## trousers.
func soak(motor: RefCounted, delta: float) -> PackedVector3Array:
	var drips := PackedVector3Array()
	var depth := float(motor.get("wade")) if "wade" in motor else 0.0
	var swimming: bool = "swimming" in motor and motor.swimming
	if swimming or depth > 0.02:
		wet = 1.0
		wet_line = minf(maxf(wet_line,depth*WET_REST+0.03),WET_MOST)
		drip_left = DRIP_TIME
		_drip_due = 0.0
	else:
		var dripping := drip_left > 0.0
		drip_left = maxf(0.0,drip_left-delta)
		wet = maxf(0.0,wet-delta/DRY_TIME)
		if wet <= 0.0: wet_line = 0.0
		if dripping and _skeleton != null:
			_drip_due += DRIP_RATE*pow(drip_left/DRIP_TIME,1.5)*delta
			var from := _drip_sources()
			while _drip_due >= 1.0 and not from.is_empty():
				_drip_due -= 1.0
				drips.append(from[_rng.randi()%from.size()])
	for paint in _paints:
		paint.set_shader_parameter("wet",wet)
		paint.set_shader_parameter("wet_line",wet_line)
	return drips

## Where the wet parts drip from now (world), one point each, a little
## scattered round its part.
func _drip_sources() -> PackedVector3Array:
	var out := PackedVector3Array()
	var to_world := _skeleton.global_transform
	if wet_line > DRIP_MITTS:
		for bone in _hands: if bone >= 0: out.append(to_world*_skeleton.get_bone_global_pose(bone).origin+_scatter()*0.03)
	if wet_line > DRIP_HEM and _chest >= 0:
		out.append(to_world*_skeleton.get_bone_global_pose(_chest).origin+_scatter().normalized()*0.12)
	if wet_line > DRIP_KNEES:
		for bone in _shins: if bone >= 0: out.append(to_world*_skeleton.get_bone_global_pose(bone).origin+_scatter()*0.05)
	return out

## A random flat way, at most 1 long.
func _scatter() -> Vector3:
	return Vector3(_rng.randf_range(-1.0,1.0),0.0,_rng.randf_range(-1.0,1.0)).limit_length(1.0)

## One frame on a ledge (and the one coming off it).
func _drive_ledge(motor: RefCounted, hold: String, delta: float) -> Dictionary:
	var was := _hold_was
	_hold_was = hold
	if was == "":
		# Onto the ledge: the springs of the run let go of, a spin ended.
		for spring: Spring in [_bank,_look,_nod,_arms,_hunch,_roll]:
			spring.x = 0.0
			spring.v = 0.0
		_skid = 0.0
		_skidding_was = false
		_spin_t = Vector2(INF,INF)
		_spin = Vector2.ZERO
		_air = 0.0
	if _facing_was != INF:
		_yaw.x = wrapf(_yaw.x-angle_difference(_facing_was,motor.facing),-PI,PI)
	_facing_was = motor.facing
	match hold:
		"":
			if was == "climb":
				# Up on top: the climb's last frame is the idle's first.
				_ledge = 0.0
				_climbing = 0.0
				_moving = 0.0
				_standing = true
				_tree.set(&"parameters/idle_at/seek_request",0.0)
				_still_springs()
			# Let go, it fades back to the air's pose as it falls.
		"catch":
			# Turning round on the edge, standing.
			if was == "": _tree.set(&"parameters/idle_at/seek_request",0.0)
			_moving = move_toward(_moving,0.0,delta/FADE)
		"lower", "climb":
			if hold == "lower" or was == "lower" or was == "":
				_ledge = 1.0
				_climbing = 1.0
				_still_springs()
			_ledge = 1.0
			_climbing = move_toward(_climbing,1.0,delta/CLIMB_FADE)
			_climb_at = clampf(float(motor.hold_t),0.0,1.0)*CLIMB_LENGTH
		"hang":
			if was == "lower": _hang_time = 0.0
			if was == "":
				# Caught in the air: a jolt, hanging from the hands.
				_stretch.v += GRAB_KICK
				_lean.v += GRAB_SWING
				_hang_time = 0.0
			_ledge = move_toward(_ledge,1.0,delta/GRAB_FADE)
			_climbing = move_toward(_climbing,0.0,delta/HUNG_FADE)
			_hang_time = fmod(_hang_time+delta,HANG_LENGTH)
			var pace := absf(float(motor.shimmy))
			if pace > 0.01: _shimmy_way = move_toward(_shimmy_way,1.0 if float(motor.shimmy) > 0.0 else 0.0,delta/SHIMMY_TURN)
			_shimmying = clampf(pace/(SHIMMY_SPEED*0.4),0.0,1.0)
			_shimmy_phase = fmod(_shimmy_phase+pace/(SHIMMY_SPEED*SHIMMY_CYCLE)*delta,1.0)
	var hanging := hold == "hang"
	_stretch_to = 1.0
	_nod_to = 0.0
	_arms_to = 0.0
	_look_to = 0.0
	_hunch_to = 0.0
	_roll_to = 0.0
	_speed_was = 0.0
	_grounded_was = hold == ""
	_feet_was = Vector3.INF
	var lean := _lean.step(0.0,delta)
	var yaw := _yaw.step(0.0,delta)
	_tilt.rotation = Vector3(lean,yaw,_bank.step(0.0,delta))
	# Hanging, it sways, turns and stretches about the hands, otherwise about
	# the feet (moving over as the hang fades in).
	var about := GRIP*smoothstep(0.0,1.0,_ledge) if hanging else Vector3.ZERO
	_tilt.position = about-_tilt.basis*about
	_pivot.rotation = Vector3.ZERO
	_advance(delta)
	if hanging:
		var stretch := _pivot.scale.y
		_pivot.position = Vector3(0.0,about.y-(about.y-HIPS)*stretch,0.0)
	return {}

## The tilt and stretch at rest, at once (the body's origin jumps under a
## clip that moves the body itself).
func _still_springs() -> void:
	for spring: Spring in [_bank,_lean,_yaw]:
		spring.x = 0.0
		spring.v = 0.0
	_stretch.x = 1.0
	_stretch.v = 0.0
	_tilt.rotation = Vector3.ZERO
	_tilt.position = Vector3.ZERO

## Where boot `side` (0 the left, 1 the right) stands, in the world: under
## its ankle, at the feet's height.
func boot(side: int) -> Vector3:
	var at := _skeleton.global_transform*_skeleton.get_bone_global_pose(_boots[side]).origin
	return Vector3(at.x,global_position.y,at.z)

## Where mitt `side` (0 the left, 1 the right) is, in the world.
func mitt(side: int) -> Vector3:
	if _hands.size() <= side or _hands[side] < 0: return global_position
	return _skeleton.global_transform*_skeleton.get_bone_global_pose(_hands[side]).origin

## Metres a full gait cycle (both feet) covers, `running` 0 walking to 1
## running.
static func stride(running: float) -> float:
	return lerpf(WALK_SPEED*WALK_CYCLE,RUN_SPEED*RUN_CYCLE,running)

## Skydiving (scripts/sky_dive.gd), posed over the idle by the dive's own
## state: `spread` and `tuck` (0 to 1 each) falling, `sail` (0 falling to 1
## holding the pocket sail overhead) and `pop` (1 just out of the plane,
## flailing). Falling belly-down it is the classic box: arms out and bent
## up at the elbows, knees bent and boots up behind, head up to look ahead;
## spread, wider; tucked, arms swept back along the body and legs straight
## for the dive. Under the sail his mitts are up overhead on its bar and his
## legs hang. The walker turns the whole figure (onto the belly, upright
## under the sail): this is the limbs alone.
func dive(spread: float, tuck: float, sail: float, pop: float, delta: float) -> void:
	_moving = move_toward(_moving,0.0,delta/FADE)
	_swim = move_toward(_swim,0.0,delta/SWIM_FADE)
	_swimming_was = false
	_skid = 0.0
	_ledge = 0.0
	_climbing = 0.0
	_hold_was = ""
	_tilt.rotation = Vector3.ZERO
	_tilt.position = Vector3.ZERO
	_pivot.rotation = Vector3.ZERO
	_stretch_to = 1.0
	_look_to = 0.0
	_nod_to = 0.0
	_arms_to = 0.0
	_hunch_to = 0.0
	_roll_to = 0.0
	_feet_was = Vector3.INF
	_grounded_was = false
	_sail = 0.0
	_dive_time = _dive_time+delta if pop > 0.0 else 0.0
	# Falling: the box, widened by the spread, swept back by the tuck.
	var box := Vector4(1.35,1.1,-0.15,-1.25)
	box = box.lerp(Vector4(1.6,0.6,-0.1,-0.75),spread)
	box = box.lerp(Vector4(0.3,0.05,0.0,-0.15),tuck)
	var box_b := Vector4(0.25,-0.55,0.0,0.0).lerp(Vector4(0.45,-0.6,0.0,0.0),spread).lerp(Vector4(0.02,-0.3,0.0,0.0),tuck)
	# Under the sail: mitts up overhead on its bar, legs hanging.
	var hang := Vector4(SAIL_ARMS.x,SAIL_ARMS.y,0.15,-0.2)
	var hang_b := Vector4(0.06,0.0,0.0,0.0)
	var want := box.lerp(hang,sail)
	var want_b := box_b.lerp(hang_b,sail)
	if pop > 0.0:
		# Just out: flailing, arms up, a kick of the legs.
		var t := _dive_time
		want = want.lerp(Vector4(2.1+0.35*sin(t*13.0),0.5,0.35*sin(t*11.0),-0.6),pop)
	var k := 1.0-exp(-delta/0.18)
	_dive_a = _dive_a.lerp(want,k)
	_dive_b = _dive_b.lerp(want_b,k)
	_advance(delta)
	if _upper_arms.has(-1) or _thighs.has(-1) or _shins.has(-1): return
	_turn_bone(_upper_arms[0],Vector3.BACK,-_dive_a.x)
	_turn_bone(_upper_arms[1],Vector3.BACK,_dive_a.x)
	if not _forearms.has(-1):
		_turn_bone(_forearms[0],Vector3.BACK,-_dive_a.y)
		_turn_bone(_forearms[1],Vector3.BACK,_dive_a.y)
	for side in range(2):
		_turn_bone(_thighs[side],Vector3.RIGHT,_dive_a.z)
		_turn_bone(_shins[side],Vector3.RIGHT,_dive_a.w)
	_turn_bone(_thighs[0],Vector3.BACK,-_dive_b.x)
	_turn_bone(_thighs[1],Vector3.BACK,_dive_b.x)
	if _head >= 0: _turn_bone(_head,Vector3.RIGHT,_dive_b.y)

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
	_sail = 0.0
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
	_tilt.position = Vector3.ZERO
	_hold_was = ""
	_ledge = 0.0
	_climbing = 0.0
	for key: String in _move_weights:
		_move_weights[key] = 0.0
		_move_times[key] = 0.0
	_move_was = ""
	_air = 0.0
	_spin = Vector2.ZERO
	_spin_t = Vector2(INF,INF)
	_pivot.rotation = Vector3.ZERO
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
	if _has_ledge:
		_tree.set(&"parameters/ledge/blend_amount",smoothstep(0.0,1.0,_ledge))
		_tree.set(&"parameters/climbing/blend_amount",smoothstep(0.0,1.0,_climbing))
		_tree.set(&"parameters/shimmy/blend_amount",smoothstep(0.0,1.0,_shimmying))
		_tree.set(&"parameters/shimmy_way/blend_amount",_shimmy_way)
		_tree.set(&"parameters/hang_at/seek_request",_hang_time)
		_tree.set(&"parameters/shimmy_left_at/seek_request",_shimmy_phase*SHIMMY_CYCLE)
		_tree.set(&"parameters/shimmy_right_at/seek_request",_shimmy_phase*SHIMMY_CYCLE)
		_tree.set(&"parameters/climb_at/seek_request",_climb_at)
	for key: String in _move_weights:
		var length: float = MOVE_CLIPS[key][1]
		var t: float = _move_times[key]
		_tree.set(StringName("parameters/%s_mix/blend_amount" % key),smoothstep(0.0,1.0,_move_weights[key]))
		_tree.set(StringName("parameters/%s_at/seek_request" % key),minf(t,length-0.001) if key in ONCE else fmod(t,length))
	if _has_air:
		_tree.set(&"parameters/air/blend_amount",smoothstep(0.0,1.0,_air))
		_tree.set(&"parameters/air_way/blend_amount",smoothstep(0.0,1.0,_air_fall))
		_tree.set(&"parameters/jump_rise_at/seek_request",_air_time)
		_tree.set(&"parameters/jump_fall_at/seek_request",_air_time)
	if _has_swim:
		_tree.set(&"parameters/water/blend_amount",smoothstep(0.0,1.0,_swim))
		_tree.set(&"parameters/paddle/blend_amount",smoothstep(0.0,1.0,_paddle))
		_tree.set(&"parameters/swim_at/seek_request",_swim_phase*SWIM_CYCLE)
		_tree.set(&"parameters/tread_at/seek_request",_tread_time)

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
	if _sail > 0.001: _holding_sail()
	if _wade > 0.001: _wading()

## Under the pocket sail (the motor's move "sail"): both arms up overhead
## holding its bar, the elbows a little bent, by how far it is out.
func _holding_sail() -> void:
	var up := smoothstep(0.0,1.0,_sail)
	_turn_bone(_upper_arms[0],Vector3.BACK,-SAIL_ARMS.x*up)
	_turn_bone(_upper_arms[1],Vector3.BACK,SAIL_ARMS.x*up)
	if _forearms.has(-1): return
	_turn_bone(_forearms[0],Vector3.BACK,-SAIL_ARMS.y*up)
	_turn_bone(_forearms[1],Vector3.BACK,SAIL_ARMS.y*up)

## The wading gait over the walk and the run: each knee lifted higher
## through its swing (the shin tucked under, so the boot clears the water
## rather than reaching), the arms held a little up and out for balance,
## the elbows bent; all by how deep he wades.
func _wading() -> void:
	if _thighs.has(-1) or _shins.has(-1): return
	var wade := smoothstep(0.0,1.0,_wade)*_moving
	# The share of the gait each boot is planted (pilot_build.py WALK_STANCE,
	# RUN_STANCE); the left swings after it, the right half a cycle on.
	var stance := lerpf(0.58,0.28,_running)
	for side in range(2):
		var q := fmod(_phase+0.5*side,1.0)
		var swing := sin(PI*(q-stance)/(1.0-stance)) if q > stance else 0.0
		_turn_bone(_thighs[side],Vector3.RIGHT,WADE_KNEE*wade*swing)
		_turn_bone(_shins[side],Vector3.RIGHT,-WADE_SHIN*wade*swing)
	var arms := smoothstep(0.0,1.0,_wade)
	_turn_bone(_upper_arms[0],Vector3.BACK,-WADE_ARMS*arms)
	_turn_bone(_upper_arms[1],Vector3.BACK,WADE_ARMS*arms)
	if not _forearms.has(-1):
		for bone in _forearms: _turn_bone(bone,Vector3.RIGHT,WADE_ELBOWS*arms)

## Turns `bone` by `angle` about `axis` (the model's), on top of its pose.
func _turn_bone(bone: int, axis: Vector3, angle: float) -> void:
	if absf(angle) < 0.0005: return
	var local := (_skeleton.get_bone_global_pose(bone).basis.inverse()*(_to_skeleton*axis)).normalized()
	_skeleton.set_bone_pose_rotation(bone,_skeleton.get_bone_pose_rotation(bone)*Quaternion(local,angle))
