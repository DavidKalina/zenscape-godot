extends Node3D
## What the glide (scripts/sky_glide.gd) feels like round the eye: the air
## streaking past and the wind's sound.
##
## The streaks are faint motes in a box that wraps round the eye
## (shaders/glide_streaks.gdshader). At a glide they barely show; in a dive
## they draw out into soft lines.
##
## The wind is noise made here, through two low-passes: a breathy hiss that
## opens up with speed, and a low roar under it in a dive. At the float, at
## the top of an arc, it drops almost to nothing. Each flap is a soft
## whoosh of cloth on air (`flap`).
##
## Close past something big (scripts/glide_vapour.gd `near`), the air
## thickens: the streaks brighten and the hiss rises and opens, a rush of
## breath along the rock.
##
## In a towering cumulus (scripts/sky_towers.gd `fade`), the air goes soft:
## the hiss closes down to a hush and quietens, and the streaks thicken
## into the cloud's own wisps flying past.

const COUNT := 420
const BOX := 36.0
## Speeds (m/s) where the streaks and wind start to show and where they are full.
const QUIET := 6.0
const LOUD := 30.0
const RATE := 22050.0
## The wind's loudness at a glide and at full speed, in linear gain.
const GAIN := Vector2(0.05,0.55)
const EASE := 0.12
## Close past rock, at full `near`: the streaks' extra strength, the
## wind's extra gain, and how much brighter the hiss opens.
const NEAR_STREAKS := 0.45
const NEAR_GAIN := 0.22
const NEAR_OPEN := 0.18
## Deep in a cloud: how much the hiss closes, how much quieter it is, and
## the streaks' extra strength.
const MUFFLE_OPEN := 0.8
const MUFFLE_GAIN := 0.45
const CLOUD_STREAKS := 0.35
## A flap's whoosh: its loudness, and how fast it swells and dies (per sample).
const WHOOSH := 0.32
const WHOOSH_IN := 0.0035
const WHOOSH_OUT := 0.99975

var _streaks: MultiMeshInstance3D
var _material: ShaderMaterial
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
## Filter state and the current, eased loudness and brightness.
var _hiss := 0.0
var _roar := 0.0
var _roar2 := 0.0
var _gain := 0.0
var _open := 0.0
var _deep := 0.0
var _shown := 0.0
## The whoosh: its envelope, where it is heading, and its filter.
var _whoosh := 0.0
var _whoosh_goal := 0.0
var _whoosh_f := 0.0
var _whoosh_f2 := 0.0

func _ready() -> void:
	name = "GlideAir"
	_rng.seed = 7
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = COUNT
	for i in range(COUNT):
		var at := Vector3(_rng.randf(),_rng.randf(),_rng.randf())*BOX
		multimesh.set_instance_transform(i,Transform3D(Basis(),at))
		multimesh.set_instance_custom_data(i,Color(_rng.randf(),_rng.randf_range(0.025,0.06),_rng.randf_range(0.3,1.0),0.0))
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/glide_streaks.gdshader")
	_material.set_shader_parameter("box",BOX)
	_streaks = MultiMeshInstance3D.new()
	_streaks.name = "Streaks"
	_streaks.multimesh = multimesh
	_streaks.material_override = _material
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The motes are moved in the shader; never cull them.
	_streaks.custom_aabb = AABB(Vector3.ONE*-1e5,Vector3.ONE*2e5)
	add_child(_streaks)
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = RATE
	stream.buffer_length = 0.15
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	add_child(_player)
	visible = false

func start() -> void:
	visible = true
	_gain = 0.0
	_shown = 0.0
	_player.volume_db = 0.0
	_player.play()
	_playback = _player.get_stream_playback()

func stop() -> void:
	visible = false
	_player.stop()
	_playback = null

## Each frame of the glide: its velocity, its float (0 to 1), whether it is
## tucked in a dive, how close it is passing to rock and how deep it is in
## a tower's cloud (0 to 1 each).
func advance(delta: float, velocity: Vector3, hang: float, dive: float, near := 0.0, cloud := 0.0) -> void:
	var speed := velocity.length()
	var fast := clampf((speed-QUIET)/(LOUD-QUIET),0.0,1.0)
	var k := 1.0-exp(-delta/EASE)
	_shown = lerpf(_shown,minf(smoothstep(0.0,1.0,fast)*(1.0-hang*0.8)+NEAR_STREAKS*near+CLOUD_STREAKS*cloud,1.0),k)
	_material.set_shader_parameter("velocity",velocity)
	_material.set_shader_parameter("strength",0.12+0.75*_shown)
	_gain = lerpf(_gain,(lerpf(GAIN.x,GAIN.y,fast*fast)*(1.0-0.9*hang)+NEAR_GAIN*near)*(1.0-MUFFLE_GAIN*cloud),k)
	_open = lerpf(_open,(0.04+0.4*fast+NEAR_OPEN*near)*(1.0-MUFFLE_OPEN*cloud),k)
	_deep = lerpf(_deep,clampf(dive*fast*1.4,0.0,1.0),k)
	_fill()

## A flap: a whoosh.
func flap() -> void:
	_whoosh_goal = 1.0

## Fills the audio buffer with shaped noise.
func _fill() -> void:
	if _playback == null: return
	var frames := _playback.get_frames_available()
	if frames <= 0: return
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	for i in range(frames):
		var white := _rng.randf()*2.0-1.0
		_hiss += (white-_hiss)*_open
		_roar += (white-_roar)*0.02
		_roar2 += (_roar-_roar2)*0.05
		# The whoosh swells, then dies away; low and breathy.
		if _whoosh_goal > 0.0:
			_whoosh += (1.0-_whoosh)*WHOOSH_IN
			if _whoosh > 0.95: _whoosh_goal = 0.0
		else:
			_whoosh *= WHOOSH_OUT
		_whoosh_f += (white-_whoosh_f)*0.06
		_whoosh_f2 += (_whoosh_f-_whoosh_f2)*0.12
		var s := (_hiss*0.8+_roar2*6.0*_deep)*_gain+_whoosh_f2*_whoosh*WHOOSH*3.0
		buffer[i] = Vector2(s,s)
	_playback.push_buffer(buffer)
