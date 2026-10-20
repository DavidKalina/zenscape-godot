extends Node3D
## The headless body's stone and its moves (scripts/enemies/headless_body.gd):
## the Blender model
## (art/blender/headless_body/headless_body_build.py, assets/models/
## headless_body.glb) dressed in the ruin kit's stone as the inhaler head is
## (scripts/enemies/inhaler_head_look.gd `_dressed`: the kit's stone material,
## each vertex coloured as the kit colours a face, darkened in its crevices by
## the baked occlusion, moss on what faces up), its stump's raw cut a warmer
## fresh stone that glows with its tell.
##
## Its clips are blended in an AnimationTree the body drives by hand: each
## frame it says which clips it wants and where in them (`want`), and the
## weights ease there (a cross-fade of `fade` s). Every clip is seeked, so
## the body's own clock (its phase, its state's time) sets the pace; nothing
## free-runs but the idle. Then, on top of the clips, the procedural layers
## (`reach`): a hand pulled by two-bone IK onto a real wall or lip.
##
## Built at the model's size times `k` (the head's height over HH), the feet's
## middle at the origin, the front toward -Z.
##   want(clip, time, weight)   wanted this frame (weights are normalized)
##   advance(delta, fade)       eases the weights, seeks, poses the skeleton
##   reach(side, target, w, fingers, palm)  a hand onto `target` (global)
##   seat()                     the head's seat on the stump (global transform)
##   warm(share)                the stump's cut glowing, 0 to 1

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")
const HeadLook = preload("res://scripts/enemies/inhaler_head_look.gd")
const MODEL := "res://assets/models/headless_body.glb"
## The model's head height (m): its sizes are in these (the build's HH).
const HH := 3.36
## The head's chin over the feet in the model (the build's SEAT).
const SEAT_Y := 6.7536
## The clips' measures in head heights (the build's WALK_STEP, STRIDE_STEP,
## CLIMB_RISE): the phase-driven loops cover two steps or two hand moves.
const WALK_STEP := 0.5
const STRIDE_STEP := 0.68
## The whole Olmec's shoulder-led run (the build's RUN_STEP; Olmec boss).
const RUN_STEP := 0.8
## The Olmec boss's charge run (the build's CHARGE_STEP).
const CHARGE_STEP := 1.0
const CLIMB_RISE := 0.99
const CLIPS := ["idle","listen","walk","stride","climb","haul","spawn_haul","mantle","windup",
	"jump_air","drop_air","land","drop_land","reach","triumph","feel","mantle_pull",
	"turn_open_l","turn_close_l","turn_open_r","turn_close_r","scope_lift","scope_look","scope_lower","shoulder_run",
	"charge_tell","charge_run","charge_skid","charge_stagger",
	"teeter_catch","teeter","teeter_back","topple","rim_leap","rim_land","back_hit","hunt_stride",
	"turn_45_l","turn_45_r","turn_90_l","turn_90_r","turn_180_l","turn_180_r"]
## Round 4: the turn steps (headless_body_steps.gd), blended over the trunk
## and legs only (the arms keep the clip under them), faded in and out fast.
const TURNS := ["turn_open_l","turn_close_l","turn_open_r","turn_close_r"]
## Olmec round 1: the upper arms and forearms too (they swing with the turn;
## the hands keep the clip under them).
const TURN_BONES := ["root","hips","spine","chest","neck","thigh.L","shin.L","foot.L","thigh.R","shin.R","foot.R",
	"upper_arm.L","forearm.L","upper_arm.R","forearm.R"]
const TURN_FADE := 0.06
## Olmec turn: the whole turns on the spot (the build's turn_45/90/180_l/r),
## the whole body blended, its root's yaw read off the clip
## (`turn_yaw`) and kept out of the pose (the figure turns by it instead),
## faded in and out over WHOLE_FADE s.
const WHOLE_TURNS := ["turn_45_l","turn_45_r","turn_90_l","turn_90_r","turn_180_l","turn_180_r"]
const WHOLE_FADE := 0.14
## Their roots' yaw (rad, + left) sampled every YAW_DT s.
const YAW_DT := 1.0/60.0
var _yaws := {}
var _root := -1
var _root_rest := Quaternion.IDENTITY
const Steps = preload("res://scripts/enemies/headless_body_steps.gd")
## The cut's stone and its glow.
const CUT := Color(0.66,0.5,0.4)
const CUT_GLOW := Color(1.0,0.62,0.28)

var k := 1.0
var model: Node3D
var skeleton: Skeleton3D
var lengths := {}
var _tree: AnimationTree
var _weights := {}
var _times := {}
var _want := {}
var _cut_mat := StandardMaterial3D.new()
var _arm := {}
var _neck := -1
var _seat_off := Transform3D.IDENTITY
var _leg := {}
## An arm lost ("L" or "R"; "" none): reaches on that side do nothing (its
## bones are collapsed by the owner, scripts/olmec_boss/boss_body.gd).
var lost := ""
## Its turns and feet (round 4).
var steps: Steps
static var _dressed_mesh: ArrayMesh = null

## Builds the body at `scale` times the model's size.
func build(scale_k: float) -> void:
	k = scale_k
	model = (load(MODEL) as PackedScene).instantiate()
	model.scale = Vector3.ONE*k
	add_child(model)
	skeleton = model.find_children("*","Skeleton3D",true,false)[0]
	var body := skeleton.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	if _dressed_mesh == null:
		var stone := Style.stone_of(7) if Style.ruled() else Color("5a5d63")
		_dressed_mesh = HeadLook._dressed(body.mesh,stone,Vector3.ZERO)
	body.mesh = _dressed_mesh
	body.set_surface_override_material(0,HeadLook.stone_material())
	_cut_mat.albedo_color = CUT
	_cut_mat.roughness = 1.0
	_cut_mat.vertex_color_use_as_albedo = true
	_cut_mat.emission_enabled = true
	_cut_mat.emission = CUT_GLOW
	_cut_mat.emission_energy_multiplier = 0.0
	if _dressed_mesh.get_surface_count() > 1: body.set_surface_override_material(1,_cut_mat)
	for side in ["L","R"]:
		_arm[side] = [skeleton.find_bone("upper_arm."+side),skeleton.find_bone("forearm."+side),
			skeleton.find_bone("hand."+side),skeleton.find_bone("fingers."+side)]
	for side in ["L","R"]:
		_leg[side] = [skeleton.find_bone("thigh."+side),skeleton.find_bone("shin."+side),skeleton.find_bone("foot."+side)]
	_neck = skeleton.find_bone("neck")
	_seat_off = skeleton.get_bone_global_rest(_neck).affine_inverse()*Transform3D(Basis.IDENTITY,Vector3(0.0,SEAT_Y,0.0))
	_root = skeleton.find_bone("root")
	_root_rest = skeleton.get_bone_rest(_root).basis.get_rotation_quaternion()
	_build_tree(model.find_child("AnimationPlayer",true,false) as AnimationPlayer)
	steps = Steps.new(self)

## Every clip seeked, chained in Blend2s so any weights can be had: the
## k-th mix's amount is the k-th clip's weight over the sum to it.
func _build_tree(player: AnimationPlayer) -> void:
	var blend := AnimationNodeBlendTree.new()
	var last := StringName()
	for i in CLIPS.size():
		var clip: String = CLIPS[i]
		var animation := player.get_animation(clip)
		lengths[clip] = animation.length
		animation.loop_mode = Animation.LOOP_NONE
		for track in range(animation.get_track_count()):
			animation.track_set_interpolation_type(track,Animation.INTERPOLATION_CUBIC)
		var node := AnimationNodeAnimation.new()
		node.animation = StringName(clip)
		blend.add_node(StringName(clip+"_clip"),node)
		blend.add_node(StringName(clip+"_at"),AnimationNodeTimeSeek.new())
		blend.connect_node(StringName(clip+"_at"),0,StringName(clip+"_clip"))
		if i == 0: last = StringName(clip+"_at")
		else:
			var mix := StringName(clip+"_mix")
			var mixer := AnimationNodeBlend2.new()
			if clip in TURNS:
				mixer.filter_enabled = true
				for track in range(animation.get_track_count()):
					var path := animation.track_get_path(track)
					if path.get_concatenated_subnames() in TURN_BONES: mixer.set_filter_path(path,true)
			blend.add_node(mix,mixer)
			blend.connect_node(mix,0,last)
			blend.connect_node(mix,1,StringName(clip+"_at"))
			last = mix
		_weights[clip] = 1.0 if clip == "idle" else 0.0
		_times[clip] = 0.0
		if clip in WHOLE_TURNS: _yaws[clip] = _yaw_samples(animation)
	blend.connect_node(&"output",0,last)
	_tree = AnimationTree.new()
	_tree.name = "Moves"
	_tree.tree_root = blend
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.active = true

## `clip` wanted this frame at `time` s into it (clamped; loops wrap it
## themselves), `weight` of the frame's wants.
func want(clip: String, time: float, weight := 1.0) -> void:
	_want[clip] = float(_want.get(clip,0.0))+weight
	_times[clip] = time

## The clip with the most weight now.
func clip_now() -> String:
	var best := "idle"
	for c: String in _weights:
		if _weights[c] > _weights[best]: best = c
	return best

## The weights eased to this frame's wants over `fade` s, the clips seeked,
## the skeleton posed. The wants are cleared for the next frame.
func advance(delta: float, fade: float) -> void:
	var total := 0.0
	for c: String in _want: total += float(_want[c])
	var step := 1.0 if fade <= 0.0 else delta/fade
	for c: String in CLIPS:
		var goal: float = float(_want.get(c,0.0))/total if total > 0.0 else _weights[c]
		var fade_step := step
		if c in TURNS: fade_step = maxf(step,delta/TURN_FADE)
		elif c in WHOLE_TURNS: fade_step = delta/WHOLE_FADE
		_weights[c] = move_toward(_weights[c],goal,fade_step)
	var sum := 0.0
	for i in CLIPS.size():
		var c: String = CLIPS[i]
		var w: float = _weights[c]
		sum += w
		if i > 0: _tree.set(StringName("parameters/%s_mix/blend_amount" % c),w/sum if sum > 0.0001 else 0.0)
		var length: float = lengths[c]
		var t: float = _times[c]
		_tree.set(StringName("parameters/%s_at/seek_request" % c),clampf(t,0.0,length-0.001))
	_want.clear()
	_tree.advance(delta)
	# The whole turns' root yaw is the figure's (headless_body_steps.gd), not the pose's.
	if whole_turn_weight() > 0.0: skeleton.set_bone_pose_rotation(_root,_root_rest)

## How much of the pose the whole turns hold now (0 none).
func whole_turn_weight() -> float:
	var w := 0.0
	for c: String in WHOLE_TURNS: w += float(_weights[c])
	return w

## A whole turn's root yaw at `t` s into it (rad, + left; 0 at its start).
func turn_yaw(clip: String, t: float) -> float:
	var a: PackedFloat32Array = _yaws[clip]
	var x := clampf(t/YAW_DT,0.0,float(a.size()-1))
	var i := mini(int(x),a.size()-2)
	return lerpf(a[i],a[i+1],x-float(i))

## The root's yaw through `animation`, unwrapped, every YAW_DT s.
func _yaw_samples(animation: Animation) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var track := -1
	for tr in animation.get_track_count():
		if animation.track_get_type(tr) == Animation.TYPE_ROTATION_3D and animation.track_get_path(tr).get_concatenated_subnames() == "root": track = tr
	var n := int(ceil(animation.length/YAW_DT))+1
	var last := 0.0
	for i in n:
		var y := 0.0
		if track >= 0:
			var q: Quaternion = animation.rotation_track_interpolate(track,minf(i*YAW_DT,animation.length))*_root_rest.inverse()
			var fwd := Basis(q)*Vector3.FORWARD
			y = atan2(-fwd.x,-fwd.z)
		if i > 0: y = last+angle_difference(last,y)
		out.append(y)
		last = y
	return out

## The yaw (rad, + left) the clips have turned foot `side` off its rest.
func foot_yaw(side: String) -> float:
	var b: int = _leg[side][2]
	var q := skeleton.get_bone_global_pose(b).basis.get_rotation_quaternion()*skeleton.get_bone_global_rest(b).basis.get_rotation_quaternion().inverse()
	var fwd := Basis(q)*Vector3.FORWARD
	return atan2(-fwd.x,-fwd.z)

## How much of the pose the turn steps hold now (0 none).
func turn_weight() -> float:
	var w := 0.0
	for c: String in TURNS: w += float(_weights[c])
	return w

## Loops: where `phase` (in loop units, one loop each `per` of it) falls in `clip`.
func loop_time(clip: String, phase: float, per := 1.0) -> float:
	return fposmod(phase/per,1.0)*float(lengths[clip])

# --- On top of the clips ---------------------------------------------------------------

## The wrist of `side` ("L"/"R"), global.
func wrist(side: String) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(_arm[side][2]).origin

## The fingertips of `side` (the fingers' far end), global (Olmec round 1).
func fingertip(side: String) -> Vector3:
	var t := skeleton.global_transform*skeleton.get_bone_global_pose(_arm[side][3])
	return t.origin+t.basis.y*0.72

## The thumb's tip of `side`, global (Olmec round 1).
func thumbtip(side: String) -> Vector3:
	var b := skeleton.find_bone("thumb."+side)
	var t := skeleton.global_transform*skeleton.get_bone_global_pose(b)
	return t.origin+t.basis.y*0.5

## The elbow of `side`, global.
func elbow(side: String) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(_arm[side][1]).origin

## The shoulder of `side`, global.
func shoulder(side: String) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(_arm[side][0]).origin

## The arm's reach, shoulder to wrist (m, global).
func arm_reach() -> float:
	var a := skeleton.get_bone_global_rest(_arm["L"][0]).origin
	var b := skeleton.get_bone_global_rest(_arm["L"][2]).origin
	return a.distance_to(b)*k

## The hand of `side` pulled `w` of the way onto `target` (its wrist; global)
## by two-bone IK, the elbow kept in the clip's plane; `fingers` (global, unit)
## and `palm` (the way the palm faces), if given, turn the hand `w` to them.
func reach(side: String, target: Vector3, w: float, fingers := Vector3.ZERO, palm := Vector3.ZERO) -> void:
	if w <= 0.0 or side == lost: return
	var to_sk := skeleton.global_transform.affine_inverse()
	var hand := Basis()
	if fingers != Vector3.ZERO and palm != Vector3.ZERO: hand = _hand_basis(side,to_sk.basis*fingers,to_sk.basis*palm)
	_two_bone(_arm[side],to_sk*target,w,hand,fingers != Vector3.ZERO and palm != Vector3.ZERO)

## Bones `bones` (upper, lower, end) pulled `w` of the way to `target`
## (skeleton space) by two-bone IK, the bend kept in the clip's plane; with
## `turn_end` the end bone turned `w` to `end` (skeleton space), else it
## keeps its turn under the lower bone.
func _two_bone(bones: Array, target: Vector3, w: float, end: Basis, turn_end: bool) -> void:
	var up_g := skeleton.get_bone_global_pose(bones[0])
	var fo_g := skeleton.get_bone_global_pose(bones[1])
	var hd_g := skeleton.get_bone_global_pose(bones[2])
	var s := up_g.origin
	var e := fo_g.origin
	var wr := hd_g.origin
	var t := wr.lerp(target,clampf(w,0.0,1.0))
	var a := s.distance_to(e)
	var b := e.distance_to(wr)
	var to := t-s
	if to.length() < 0.001: return
	var d := clampf(to.length(),absf(a-b)+0.001,(a+b)*0.999)
	var n := to.normalized()
	# The bend: the elbow's way off the line, as the clip has it.
	var bend := (e-s)-n*(e-s).dot(n)
	if bend.length() < 0.001: bend = Vector3(0.0,-0.4,0.6)-n*Vector3(0.0,-0.4,0.6).dot(n)
	bend = bend.normalized()
	var along := (a*a-b*b+d*d)/(2.0*d)
	var e2 := s+n*along+bend*sqrt(maxf(a*a-along*along,0.0))
	var w2 := s+n*d
	var r1 := Basis(_arc(e-s,e2-s))
	var r2 := Basis(_arc(r1*(wr-e),w2-e2))
	var up_new := Transform3D(r1*up_g.basis,s)
	var fo_new := Transform3D(r2*r1*fo_g.basis,e2)
	var hd_basis := r2*r1*hd_g.basis
	if turn_end:
		hd_basis = Basis(hd_basis.get_rotation_quaternion().slerp(end.get_rotation_quaternion(),clampf(w,0.0,1.0)))
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bones[0]))
	skeleton.set_bone_pose_rotation(bones[0],(parent.basis.inverse()*up_new.basis).get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(bones[1],(up_new.basis.inverse()*fo_new.basis).get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(bones[2],(fo_new.basis.inverse()*hd_basis).get_rotation_quaternion())

# --- Round 4: turns and feet (headless_body_steps.gd) ------------------------------------

## Before the clips: the figure turned off `facing` and a turn step wanted
## (`mode` Steps.OFF, STAND or WALK; walking, `gait_u` its cycle's place).
func turn(facing: float, mode: int, delta: float, gait_u := 0.0, striding := false, want := NAN) -> void:
	steps.turn(facing,mode,delta,gait_u,striding,want)

## After the clips: the feet held or carried by IK.
func plant_feet(delta: float) -> void:
	steps.plant(delta)

## The ankle of `side`, global.
func ankle(side: String) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(_leg[side][2]).origin

## The leg of `side` pulled so its ankle is at `target` (global), the foot
## turned `turn` rad about up off the clip's.
func leg(side: String, target: Vector3, turn_by: float) -> void:
	var bones: Array = _leg[side]
	var foot := skeleton.get_bone_global_pose(bones[2]).basis
	_two_bone(bones,skeleton.global_transform.affine_inverse()*target,1.0,Basis(Vector3.UP,turn_by)*foot,true)

## The slab foot's sole corners (the build's foot block: 0.78 either side,
## 1.44 ahead of the ankle to 0.72 behind, at the ground; model m).
const SOLE := [Vector3(-0.78,0.0,-1.44),Vector3(0.78,0.0,-1.44),Vector3(-0.78,0.0,0.72),Vector3(0.78,0.0,0.72)]

## The sole of `side`'s corners as posed (global; Olmec round 1).
func sole(side: String) -> PackedVector3Array:
	var b: int = _leg[side][2]
	var rest := skeleton.get_bone_global_rest(b)
	var pose := skeleton.global_transform*skeleton.get_bone_global_pose(b)*rest.affine_inverse()
	var ankle := rest.origin
	var out := PackedVector3Array()
	for c: Vector3 in SOLE: out.append(pose*Vector3(ankle.x+c.x,c.y,ankle.z+c.z))
	return out

## How far the sole of `side` is under `floor_y` (global; 0 none): its
## lowest corner as posed (Olmec round 1).
func sole_under(side: String, floor_y: float) -> float:
	var low := INF
	for p: Vector3 in sole(side): low = minf(low,p.y)
	return maxf(0.0,floor_y-low)

## Bone `bone` (a trunk bone) twisted `a` rad about its own length (+ left).
func twist(bone: String, a: float) -> void:
	var b := skeleton.find_bone(bone)
	skeleton.set_bone_pose_rotation(b,skeleton.get_bone_pose_rotation(b)*Quaternion(Vector3.UP,a))

## Bone `bone` (a trunk bone) leaned `a` rad to its left.
func lean(bone: String, a: float) -> void:
	var b := skeleton.find_bone(bone)
	skeleton.set_bone_pose_rotation(b,skeleton.get_bone_pose_rotation(b)*Quaternion(Vector3.BACK,a))

## Bone `bone` (a trunk bone) pitched `a` rad forward (Olmec periscope).
func pitch(bone: String, a: float) -> void:
	var b := skeleton.find_bone(bone)
	skeleton.set_bone_pose_rotation(b,skeleton.get_bone_pose_rotation(b)*Quaternion(Vector3.RIGHT,-a))

## A hand's global frame (skeleton space) with its fingers along `fingers`
## and its palm facing `palm`: the rest frame turned so its fingers (down)
## and palm (toward the body's middle) go there.
func _hand_basis(side: String, fingers: Vector3, palm: Vector3) -> Basis:
	var rest := skeleton.get_bone_global_rest(_arm[side][2]).basis.orthonormalized()
	var p_rest := Vector3(1.0 if side == "L" else -1.0,0.0,0.0)
	var f_rest := Vector3.DOWN
	var from := Basis(p_rest,f_rest,p_rest.cross(f_rest))
	var y := fingers.normalized()
	var x := (palm-y*palm.dot(y)).normalized()
	var to := Basis(x,y,x.cross(y))
	return to*from.inverse()*rest

static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	var a := from.normalized()
	var b := to.normalized()
	if a.dot(b) > 0.99999: return Quaternion.IDENTITY
	if a.dot(b) < -0.99999:
		var axis := a.cross(Vector3.RIGHT)
		if axis.length() < 0.01: axis = a.cross(Vector3.UP)
		return Quaternion(axis.normalized(),PI)
	return Quaternion(a,b)

# --- The head's seat, the tell -------------------------------------------------------------

## Where the head's chin sits on the stump (global), turned as the stump is.
func seat() -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(_neck)*_seat_off

## The stump's cut glowing `share` (the tell).
func warm(share: float) -> void:
	_cut_mat.emission_energy_multiplier = 1.8*clampf(share,0.0,1.0)
