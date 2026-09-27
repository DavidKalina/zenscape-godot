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

var player: AnimationPlayer
## The clip playing and how far into it, on LifeMoments' clock.
var clip := ""
var time := 0.0

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

func length() -> float:
	return player.get_animation(clip).length

## True once a one-shot clip has played through.
func done() -> bool:
	return time >= length()
