extends Node3D
## The Blender heron (tools/blender_creatures/heron.py): one skinned, faceted mesh with
## hand-keyed clips in the ambient Bigfoot's style. LifeMoments places and turns it and
## says which clip to play; the clips play in place. `--classic-life` brings back the
## code-built heron from life_models.gd for comparison.

const GLB := "res://assets/models/zenscape-heron.glb"
## Timings baked into the clips (tools/blender_creatures/heron_clips.py, 30 fps).
## Strike: seconds from its start until the bill enters the water, and how far ahead.
const STRIKE_CONTACT := 34.0 / 30.0
const STRIKE_REACH := 0.5
## Land: seconds from its start until the feet meet the ground.
const LAND_TOUCH := 36.0 / 30.0
## TakeOff: seconds of crouch before the heron leaves the ground.
const TAKEOFF_LEAD := 12.0 / 30.0
## Stalk: two steps covering this many metres forward; each foot is set down at these times.
const STALK_DISTANCE := 0.34
const STALK_STEPS: Array[float] = [56.0 / 30.0, 96.0 / 30.0]
const LOOPS := ["Stand", "Fly", "Glide"]
## A caught fish is shown this long (m) across the bill, whatever its size in the pond,
## and wriggles up to CATCH_WRIGGLE radians in bursts while it is held.
const CATCH_LENGTH := 0.15
const CATCH_WRIGGLE := 0.3

var player: AnimationPlayer
## The clip playing and how far into it, on LifeMoments' clock.
var clip := ""
var time := 0.0
var _skeleton: Skeleton3D
var _catch_bone := -1
## The Catch bone's rest in the skeleton, and the pond fish held on it in place of the
## baked silver one: swallowed as the Strike clip gulps, or kept for a carry-off.
var _catch_rest: Transform3D
var _held: MeshInstance3D
var _held_basis := Basis.IDENTITY
var _carry := false
var _latched := false

static func enabled() -> bool:
	return not ("--classic-life" in OS.get_cmdline_user_args() or "--classic-life" in OS.get_cmdline_args())

func setup(material: Material) -> void:
	name = "HeronRig"
	var model: Node3D = (load(GLB) as PackedScene).instantiate()
	add_child(model)
	# The baked colours are final, so the shared surface material must not tint them again.
	var own := material.duplicate()
	if own is ShaderMaterial: own.set_shader_parameter("base_color", Color.WHITE)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = own
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	player = model.find_child("AnimationPlayer", true, false)
	# Advanced by hand on LifeMoments' clock, so the clips pause and speed with the world.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for loop in LOOPS:
		player.get_animation(loop).loop_mode = Animation.LOOP_LINEAR
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	_catch_bone = _skeleton.find_bone("Catch")
	_catch_rest = _skeleton.get_bone_global_rest(_catch_bone)
	_held = MeshInstance3D.new()
	_held.name = "Catch"
	_held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_held.visible = false
	_skeleton.add_child(_held)

## Cross-fade to a clip over `blend` seconds, from its start.
func play(clip_name: String, blend := 0.25) -> void:
	clip = clip_name
	time = 0.0
	# A one-shot that has already played through only restarts from a stop.
	if player.assigned_animation == clip_name and not clip_name in LOOPS: player.stop()
	player.play(clip_name, blend)

func advance(step: float) -> void:
	time += step
	player.advance(step)
	_place_catch()

## Hold a caught fish (a pond fish's mesh and material, `length` m long) across the bill.
## It shows when the Strike clip brings its catch up, and goes down with the gulp, or
## with `carry` stays in the bill whatever plays next, until `let_go`.
func hold(mesh: Mesh, material: Material, length: float, mirror: bool, carry: bool) -> void:
	_held.mesh = mesh
	_held.material_override = material
	var s := CATCH_LENGTH / maxf(length, 0.01)
	# Across the bill, nose to the heron's right, as the baked catch lies.
	_held_basis = Basis(Vector3.UP, -PI / 2.0) * Basis.from_scale(Vector3(-s if mirror else s, s, s))
	_carry = carry
	_latched = false
	_held.visible = false

func let_go() -> void:
	_held.mesh = null
	_held.visible = false
	_carry = false
	_latched = false

## The baked silver catch never shows; the held fish rides the Catch bone instead, at the
## clip's catch scale (or held for good once a carried one is up).
func _place_catch() -> void:
	var baked := _skeleton.get_bone_pose_scale(_catch_bone).x
	_skeleton.set_bone_pose_scale(_catch_bone, Vector3.ONE * 0.001)
	if _held.mesh == null: return
	if _carry and clip == "Strike" and baked > 0.9: _latched = true
	if not _latched and clip != "Strike":
		let_go()
		return
	var size := 1.0 if _latched else baked
	_held.visible = size > 0.01
	if not _held.visible: return
	var pose := _skeleton.get_bone_global_pose(_catch_bone)
	pose.basis = pose.basis.orthonormalized()
	# It fights in bursts: a quick thrash that comes and goes.
	var burst := maxf(sin(time * 2.3), 0.0)
	var wriggle := CATCH_WRIGGLE * burst * burst * sin(time * 17.0)
	var basis := Basis(Vector3.UP, wriggle) * _held_basis
	_held.transform = pose * _catch_rest.affine_inverse() * Transform3D(basis.scaled(Vector3.ONE * size), _catch_rest.origin)

func length() -> float:
	return player.get_animation(clip).length

## True once a one-shot clip has played through.
func done() -> bool:
	return time >= length()
