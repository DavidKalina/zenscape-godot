extends Node3D
## The whale's body (docs/design/whale/spec-whale.md, the contract): the rigged
## model (art/blender/whale/whale_build.py) with its one clip, `dive`, a surface
## roll into a fluke-up dive. Its frame: the origin on the still water where the
## tail stock goes under, -Z the way it swims.
##
## The mind (scripts/endless/whale.gd) calls only this: `play`, `advance`,
## `time`, `stop`, `socket`, `set_effect`. The clip is stepped by hand
## (`advance`), so nothing here runs while no whale is staged.

const MODEL := "res://assets/models/whale/whale.glb"
const SKIN := "res://assets/models/whale/whale_skin.png"
const SHADER := "res://shaders/whale_skin.gdshader"

const CLIP := &"dive"
## The clip's length (s) and its beats (s), as whale_build.py bakes them.
const LENGTH := 16.0
const BEATS := {"blow":0.4,"back.show":3.0,"fluke.up":7.5,"fluke.top":10.0,"fluke.slide":12.0,"gone":15.0}
## The sockets: bones of the rig. `blowhole` on the head; `tail2`, `tail3`,
## `fluke` down the tail stock (the flukes' root last); `tip_l`, `tip_r` the
## flukes' tips; `root` the chest, `lumbar` behind it.
const SOCKETS: Array[StringName] = [&"blowhole",&"root",&"lumbar",&"tail1",&"tail2",&"tail3",&"fluke",&"tip_l",&"tip_r"]
## The shape, for the mind's own measures (m): nose to the tail stock's end, the
## flukes tip to tip, the tail stock's half thickness at `tail2`, `tail3` and
## `fluke`, a fluke's half chord.
const LONG := 56.0
const FLUKE_SPAN := 26.0
const STOCK_R := Vector3(2.4,1.7,1.1)
const LOBE_R := 1.4
## The back's top over the spine at the chest (m).
const BACK := 5.0

var anim: AnimationPlayer
var skeleton: Skeleton3D
var mesh: MeshInstance3D
var material: ShaderMaterial
var _bones := {}
var _time := 0.0

func _init() -> void:
	var scene := (load(MODEL) as PackedScene).instantiate()
	add_child(scene)
	anim = scene.find_child("AnimationPlayer",true,false) as AnimationPlayer
	skeleton = scene.find_child("Skeleton3D",true,false) as Skeleton3D
	for node in scene.find_children("*","MeshInstance3D",true,false):
		mesh = node as MeshInstance3D
	material = ShaderMaterial.new()
	material.shader = load(SHADER)
	material.set_shader_parameter("skin",load(SKIN))
	if mesh != null:
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 80.0
	if anim != null:
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		anim.active = false
	if skeleton != null:
		for s in SOCKETS: _bones[s] = skeleton.find_bone(s)
	visible = false

## True when the model, its rig and its clip are all there.
func whole() -> bool:
	return anim != null and skeleton != null and mesh != null and anim.has_animation(CLIP)

## From the clip's start, shown.
func play() -> void:
	_time = 0.0
	visible = true
	if anim == null: return
	anim.active = true
	anim.play(CLIP)
	anim.seek(0.0,true)

## `seconds` further through the clip.
func advance(seconds: float) -> void:
	_time = minf(_time+seconds,LENGTH)
	if anim != null and anim.active: anim.advance(seconds)

func time() -> float:
	return _time

func done() -> bool:
	return _time >= LENGTH

## Hidden, the clip stopped.
func stop() -> void:
	visible = false
	if anim == null: return
	anim.stop()
	anim.active = false

## A socket's place in the world now.
func socket(named: StringName) -> Vector3:
	var i: int = _bones.get(named,-1)
	if skeleton == null or i < 0: return global_position
	return skeleton.global_transform*skeleton.get_bone_global_pose(i).origin

## The body's switches: `sheet` (water running off it, 0 to 1), `surface_y`
## (the water's level, world y).
func set_effect(named: String, value: float) -> void:
	material.set_shader_parameter(named,value)
