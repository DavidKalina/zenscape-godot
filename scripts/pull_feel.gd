extends Node
## The edge pull's overlap (docs/scenic/modeless-spring.md, "Pull feel
## (experiment)"): what trails the block while the rim is pulled down and
## after it is let go, under `--pull-cam` a, b or c (scripts/modeless_input.gd
## `pull_cam`; nothing of this exists under "old"). The camera's own beats are
## in scripts/camera_rig.gd (`_pull_step`) and the block's squash and stretch
## in scripts/diorama_flip.gd (`_dip_squash`).
##
## - **Plants trail the block.** Their tips lag its vertical motion on a soft
##   spring: dropping, they stretch up; shot back up, they shrink behind it;
##   when it stops they whip on past rest and ring down, which lands as the
##   range bursts. Published as the global `zs_heave` (a share of each plant's
##   height above its bend), read by the wind tool's bend (shaders/
##   reference_wind.gdshaderinc `zs_blow_bend`) and the conifers' sway
##   (shaders/conifer_wind.gdshaderinc), so the snapshot's copies and the real
##   plants after the hand-back move alike. Grass does not trail.
## - **The strain.** While the rim is held down a low creak of earth and roots
##   under load plays, louder and higher as the pull goes on (a loop baked by
##   `tools/generate_nature_audio.py --strain`), and it cuts off at the
##   release, so the snap is heard as silence breaking.

const Flip = preload("res://scripts/diorama_flip.gd")
## Plants: the tip's lag target is HEAVE_PER_SPEED of the plant's height per
## m/s of the block's vertical speed (down stretches it), followed on a spring
## of HEAVE_W 1/s and HEAVE_ZETA (under 1 rings on), and never more than
## HEAVE_MOST either way. The block's speed is taken halfway between its
## middle and its grabbed edge.
const HEAVE_PER_SPEED := 0.03
const HEAVE_W := 10.0
const HEAVE_ZETA := 0.32
const HEAVE_MOST := 0.14
## The strain: its clip, its gain at a full pull (before the Sound volume),
## silent under STRAIN_FROM of the pull, and its pitch from the least to a
## full pull (a deep pull goes up to STRAIN_PITCH_DEEP). Its gain eases in at
## STRAIN_ATTACK and out at STRAIN_RELEASE (1/s).
const STRAIN_CLIP := "edge-strain"
const STRAIN_GAIN := 0.6
const STRAIN_FROM := 0.05
const STRAIN_PITCH := Vector2(0.72,1.12)
const STRAIN_PITCH_DEEP := 1.32
const STRAIN_ATTACK := 6.0
const STRAIN_RELEASE := 22.0

var flip: Node
var spring: Node
var scene: Node3D
## The plants' trail (share of height) and its rate, for the probe.
var heave := 0.0
var heave_v := 0.0
## The strain's gain now, for the probe.
var strain := 0.0
var _published := false
var _voice: AudioStreamPlayer

func setup(edge_spring: Node) -> void:
	spring = edge_spring
	flip = edge_spring.flip
	scene = edge_spring.scene
	name = "PullFeel"
	var path := "res://assets/audio/"+STRAIN_CLIP+".wav"
	if ResourceLoader.exists(path):
		var audio := preload("res://scripts/genesis_audio.gd")
		audio.ensure_buses()
		var stream := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
		_voice = AudioStreamPlayer.new()
		_voice.name = "Strain"
		_voice.stream = stream
		_voice.bus = audio.BUS
		add_child(_voice)

func _process(delta: float) -> void:
	if flip == null: return
	delta = minf(delta,0.05)
	_trail(delta)
	_strain(delta)

func _trail(delta: float) -> void:
	var speed := 0.0
	if flip.phase in [Flip.Phase.DIP,Flip.Phase.RISE]:
		speed = -(Flip.DIP_DROP+Flip.DIP_TILT*float(flip._half)*0.5)*float(flip.dip_speed)
	var goal := clampf(-HEAVE_PER_SPEED*speed,-HEAVE_MOST,HEAVE_MOST)
	if goal == 0.0 and absf(heave) < 0.0002 and absf(heave_v) < 0.002:
		heave = 0.0
		heave_v = 0.0
	else:
		var remaining := delta
		while remaining > 0.0:
			var h := minf(remaining,1.0/240.0)
			remaining -= h
			heave_v += (HEAVE_W*HEAVE_W*(goal-heave)-2.0*HEAVE_ZETA*HEAVE_W*heave_v)*h
			heave += heave_v*h
	var shown := clampf(heave,-HEAVE_MOST,HEAVE_MOST)
	if shown != 0.0 or _published:
		RenderingServer.global_shader_parameter_set(&"zs_heave",shown)
		_published = shown != 0.0

func _strain(delta: float) -> void:
	if _voice == null: return
	var held: bool = spring.state == spring.State.PULLING and not spring.waiting and flip.phase == Flip.Phase.DIP
	var tension: float = spring.shown if held else 0.0
	var deep: float = spring.deep if held else 0.0
	var goal := STRAIN_GAIN*smoothstep(STRAIN_FROM,1.0,tension)*(1.0+0.3*deep)
	strain = lerpf(strain,goal,1.0-exp(-delta*(STRAIN_ATTACK if goal > strain else STRAIN_RELEASE)))
	if goal == 0.0 and strain < 0.0005: strain = 0.0
	var paused: bool = strain <= 0.0
	if paused:
		if _voice.playing: _voice.stop()
		return
	if not _voice.playing: _voice.play(randf()*maxf(_voice.stream.get_length()-0.5,0.0))
	_voice.volume_db = linear_to_db(strain)
	_voice.pitch_scale = lerpf(STRAIN_PITCH.x,STRAIN_PITCH.y,clampf(tension,0.0,1.0))+(STRAIN_PITCH_DEEP-STRAIN_PITCH.y)*deep
