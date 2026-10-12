extends Node3D
## A start that won't catch (docs/design/plane-arc/round1.md): the pilot
## climbs at a broken plane's controls and the engine coughs, sputters and
## dies. Three coughs over TIME s, each fainter and lower: the engine's own
## start (assets/audio/kit/engine-start.wav) cut off after COUGH s, the
## plane shuddering on its wheels, the propeller (or, lost, the bare shaft's
## stumps: scripts/plane_figure.gd `twitch_prop`) kicking round a little
## and falling back, and a puff of grey smoke out of the nose. Then still.
## Nothing moves the plane; its parked pose comes back as it was.
const KitAudio = preload("res://scripts/kit_isle/kit_audio.gd")
## Loaded when the player is made, not preloaded: a const would hold the
## stream past the scene's teardown (scripts/desktop_build_check.gd).
const START := "res://assets/audio/kit/engine-start.wav"

## The beat's length and its coughs (s in), each one's length, loudness
## (linear) and pitch; how far the propeller kicks round (rad) and the
## shudder (rad of pitch and roll at full).
const TIME := 1.8
const COUGHS := [0.08,0.62,1.2]
const COUGH := 0.3
const GAIN := [0.55,0.4,0.26]
const PITCH := [0.82,0.72,0.6]
const KICK := 0.9
const SHUDDER := Vector2(0.025,0.018)
## The nose in the figure's frame (scripts/plane_figure.gd SEATS.propeller).
const NOSE := Vector3(0.0,0.0,-0.78)
const SMOKE := Color(0.42,0.4,0.38,0.75)

var figure: Node3D
## Seconds into the beat, below 0 when not playing.
var t := -1.0
var coughs := 0
var _rest := Transform3D.IDENTITY
var _player: AudioStreamPlayer3D
var _smoke: CPUParticles3D
var _next := 0

func _init() -> void:
	name = "PlaneCough"
	_player = AudioStreamPlayer3D.new()
	_player.stream = load(START)
	_player.bus = KitAudio.SFX
	_player.unit_size = 6.0
	_player.max_distance = 80.0
	add_child(_player)
	_smoke = _make_smoke()
	add_child(_smoke)

## Plays on parked figure `on` (a scripts/plane_figure.gd), from its pose now.
func play(on: Node3D) -> void:
	if on == null: return
	if playing(): _settle()
	figure = on
	_rest = figure.transform
	t = 0.0
	coughs = 0
	_next = 0

func playing() -> bool:
	return t >= 0.0

func _process(delta: float) -> void:
	advance(delta)

## One frame of the beat.
func advance(delta: float) -> void:
	if t < 0.0 or figure == null or not is_instance_valid(figure): return
	t += delta
	if _next < COUGHS.size() and t >= float(COUGHS[_next]): _cough(_next)
	if _player.playing and t > float(COUGHS[maxi(_next-1,0)])+COUGH: _player.stop()
	# Each cough: a shudder and the propeller kicking round, easing back.
	var k := 0.0
	var kick := 0.0
	for i in range(COUGHS.size()):
		var since := t-float(COUGHS[i])
		if since < 0.0: continue
		var fade := exp(-since*7.0)*float(GAIN[i])/float(GAIN[0])
		k += sin(since*48.0)*fade
		kick += sin(minf(since*9.0,PI))*exp(-since*3.0)*float(GAIN[i])/float(GAIN[0])
	figure.transform = _rest*Transform3D(Basis.from_euler(Vector3(SHUDDER.x*k,0.0,SHUDDER.y*k)),Vector3.ZERO)
	if figure.has_method("twitch_prop"): figure.twitch_prop(KICK*kick)
	if t >= TIME: _settle()

func _cough(i: int) -> void:
	_next = i+1
	coughs += 1
	_player.global_position = figure.global_transform*NOSE
	_player.volume_db = linear_to_db(float(GAIN[i]))
	_player.pitch_scale = float(PITCH[i])
	if is_inside_tree(): _player.play()
	_smoke.global_position = figure.global_transform*NOSE
	_smoke.amount = 10-i*2
	_smoke.restart()

## Back as it was, still.
func _settle() -> void:
	t = -1.0
	if _player.playing: _player.stop()
	if figure != null and is_instance_valid(figure):
		figure.transform = _rest
		if figure.has_method("twitch_prop"): figure.twitch_prop(0.0)

func _make_smoke() -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.name = "Smoke"
	puff.one_shot = true
	puff.emitting = false
	puff.amount = 10
	puff.lifetime = 1.4
	puff.explosiveness = 0.85
	puff.local_coords = false
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 0.12
	puff.direction = Vector3(0.0,1.0,-0.4)
	puff.spread = 35.0
	puff.gravity = Vector3(0.0,0.35,0.0)
	puff.initial_velocity_min = 0.4
	puff.initial_velocity_max = 0.9
	puff.damping_min = 0.6
	puff.damping_max = 1.0
	puff.scale_amount_min = 0.6
	puff.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0,0.3))
	grow.add_point(Vector2(1.0,1.6))
	puff.scale_amount_curve = grow
	var ball := SphereMesh.new()
	ball.radius = 0.11
	ball.height = 0.22
	ball.radial_segments = 6
	ball.rings = 3
	var smoke := StandardMaterial3D.new()
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.vertex_color_use_as_albedo = true
	smoke.albedo_color = SMOKE
	ball.material = smoke
	puff.mesh = ball
	var fade := Gradient.new()
	fade.set_color(0,Color(1.0,1.0,1.0,0.9))
	fade.set_color(1,Color(1.0,1.0,1.0,0.0))
	puff.color_ramp = fade
	return puff
