extends RefCounted
## Blender-authored creatures for the life that answers the land
## (tools/blender_creatures): a rigged doe and fawn whose baked clips replace
## the code-built pivots of life_models.gd. Each keeps the life material (flat
## faces, scene palette) and its own vertex colours. Clips advance on the life
## clock, so they pause and speed up with it. `--classic-life` restores the
## code-built deer for comparison.

const DEER_GLB := "res://assets/models/zenscape-deer.glb"
## Metres per second the Walk clip covers at scale 1 (deer_clips.WALK_SPEED).
const DEER_WALK_SPEED := 0.42
## Clips that loop; the others play once and hand over to what is queued.
const LOOPS := ["Idle","Graze","Walk"]
const BLEND := 0.2

static var _scene: PackedScene

static func enabled() -> bool:
	return not ("--classic-life" in preload("res://scripts/launch_args.gd").user_args() or "--classic-life" in OS.get_cmdline_args())

## A deer, hidden until shown; `fawn` wears the lighter, spotted coat.
static func deer(material: Material, fawn: bool) -> Rig:
	if _scene == null:
		_scene = load(DEER_GLB)
	var root: Node3D = _scene.instantiate()
	root.name = "Fawn" if fawn else "Deer"
	var keep := root.find_child("Fawn" if fawn else "Deer",true,false) as MeshInstance3D
	var drop := root.find_child("Deer" if fawn else "Fawn",true,false) as MeshInstance3D
	assert(keep != null and drop != null, "%s has no Deer and Fawn meshes" % DEER_GLB)
	drop.get_parent().remove_child(drop)
	drop.free()
	keep.material_override = material
	keep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var player := root.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	for clip in LOOPS:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.playback_default_blend_time = BLEND
	root.visible = false
	return Rig.new(root,player)

## The white stag's coat, a cream every doe colour is pushed to (life_models
## `hex`: vertex colours are stored sRGB-encoded).
const STAG_COAT := "#ece5d4"

## `material` with its colour scaled so the doe's mean vertex colour comes out
## STAG_COAT: the same mesh and clips, pale, with its darker hooves and nose
## still darker. The rig has no antlers, so this is a white doe-shaped deer.
static func stag_material(material: Material, rig: Rig) -> Material:
	var mesh := rig.root.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	var colors: PackedColorArray = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var mean := Color(0,0,0)
	for c in colors: mean += c
	mean = Color(mean.r/maxf(colors.size(),1),mean.g/maxf(colors.size(),1),mean.b/maxf(colors.size(),1))
	var coat := Color.html(STAG_COAT).srgb_to_linear()
	var pale: ShaderMaterial = material.duplicate()
	pale.set_shader_parameter("base_color",Color(coat.r/maxf(mean.r,0.01),coat.g/maxf(mean.g,0.01),coat.b/maxf(mean.b,0.01)))
	return pale

class Rig:
	var root: Node3D
	var player: AnimationPlayer
	## Playback rate on top of the clock, for syncing the walk to ground speed.
	var speed := 1.0

	func _init(node: Node3D, animation: AnimationPlayer) -> void:
		root = node
		player = animation

	## Crossfade to a clip over `blend` seconds, dropping anything queued.
	func play(clip: String, blend := BLEND) -> void:
		player.clear_queue()
		player.play(clip,blend)

	## Play a clip once the current one-shot ends.
	func then(clip: String) -> void:
		player.queue(clip)

	func current() -> String:
		return player.current_animation

	func length(clip: String) -> float:
		return player.get_animation(clip).length

	func advance(step: float) -> void:
		player.advance(step*speed)
