extends Node3D
## The headless body's stone and its moves (scripts/enemies/headless_body.gd,
## docs/design/roguelike/headless-body-round3-anim.md): the Blender model
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
const CLIMB_RISE := 0.99
const CLIPS := ["idle","listen","walk","stride","climb","haul","spawn_haul","mantle","windup",
	"jump_air","drop_air","land","drop_land","reach","triumph"]
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
	body.set_surface_override_material(0,RuinKit.materials().stone)
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
	_neck = skeleton.find_bone("neck")
	_seat_off = skeleton.get_bone_global_rest(_neck).affine_inverse()*Transform3D(Basis.IDENTITY,Vector3(0.0,SEAT_Y,0.0))
	_build_tree(model.find_child("AnimationPlayer",true,false) as AnimationPlayer)

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
			blend.add_node(mix,AnimationNodeBlend2.new())
			blend.connect_node(mix,0,last)
			blend.connect_node(mix,1,StringName(clip+"_at"))
			last = mix
		_weights[clip] = 1.0 if clip == "idle" else 0.0
		_times[clip] = 0.0
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
		_weights[c] = move_toward(_weights[c],goal,step)
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

## Loops: where `phase` (in loop units, one loop each `per` of it) falls in `clip`.
func loop_time(clip: String, phase: float, per := 1.0) -> float:
	return fposmod(phase/per,1.0)*float(lengths[clip])

# --- On top of the clips ---------------------------------------------------------------

## The wrist of `side` ("L"/"R"), global.
func wrist(side: String) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(_arm[side][2]).origin

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
	if w <= 0.0: return
	var bones: Array = _arm[side]
	var to_sk := skeleton.global_transform.affine_inverse()
	var up_g := skeleton.get_bone_global_pose(bones[0])
	var fo_g := skeleton.get_bone_global_pose(bones[1])
	var hd_g := skeleton.get_bone_global_pose(bones[2])
	var s := up_g.origin
	var e := fo_g.origin
	var wr := hd_g.origin
	var t := wr.lerp(to_sk*target,clampf(w,0.0,1.0))
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
	if fingers != Vector3.ZERO and palm != Vector3.ZERO:
		var goal := _hand_basis(side,to_sk.basis*fingers,to_sk.basis*palm)
		hd_basis = Basis(hd_basis.get_rotation_quaternion().slerp(goal.get_rotation_quaternion(),clampf(w,0.0,1.0)))
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bones[0]))
	skeleton.set_bone_pose_rotation(bones[0],(parent.basis.inverse()*up_new.basis).get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(bones[1],(up_new.basis.inverse()*fo_new.basis).get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(bones[2],(fo_new.basis.inverse()*hd_basis).get_rotation_quaternion())

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
