extends Node3D
## The grit a sliding plane's wheels throw (scripts/manual_landing.gd
## `grit`): soft low-poly balls of dust or turf kicked up off the ground
## behind and outside the slide, thicker and further the harder it slides,
## with a scrubbing hiss under it; and `burst`, the dust a hard touch
## throws out all round. The landing study (studies/landing_study.gd) and
## the game under `--manual-landing` (scripts/wanderer_eye.gd) both use it.
## Add it anywhere (it works in global space) and call `update` each frame:
##   var spray := WheelSpray.new()
##   add_child(spray)
##   spray.update(delta,wheels_at,plane.velocity,ml.grit,Color("8fa266"))

## The stream: balls alive at once at full grit, their life (s), size (m),
## and how fast they fly off (m/s at full grit, and up).
const AMOUNT := 64
const LIFE := 0.75
const SIZE := Vector2(0.12,0.34)
const KICK := 4.5
const LIFT := 2.2
## Under this grit nothing is thrown.
const LEAST := 0.04
## The hiss: its loudest (dB at full grit) and how much its pitch rises.
const HISS_DB := -8.0
const HISS_PITCH := 0.35
## The burst: balls, and how fast they fly out (m/s at a full hit).
const BURST := 22
const BURST_KICK := 5.0

var _stream: CPUParticles3D
var _material: StandardMaterial3D
var _hiss: AudioStreamPlayer
var _grit := 0.0

func _ready() -> void:
	_stream = _particles(AMOUNT,false)
	add_child(_stream)
	_hiss = AudioStreamPlayer.new()
	_hiss.stream = hiss_sound()
	_hiss.volume_db = -80.0
	add_child(_hiss)

## A stream (or a one-shot burst) of soft balls, tinted by its colour.
func _particles(count: int, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.top_level = true
	p.amount = count
	p.lifetime = LIFE
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.emitting = one_shot
	p.local_coords = false
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 6
	ball.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	ball.material = m
	if not one_shot: _material = m
	p.mesh = ball
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.spread = 35.0
	p.gravity = Vector3(0.0,-6.0,0.0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = SIZE.x
	p.scale_amount_max = SIZE.y
	var grow := Curve.new()
	grow.add_point(Vector2(0.0,0.4))
	grow.add_point(Vector2(0.35,1.0))
	grow.add_point(Vector2(1.0,1.3))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0,Color(1.0,1.0,1.0,0.85))
	fade.set_color(1,Color(1.0,1.0,1.0,0.0))
	p.color_ramp = fade
	return p

## One frame: the wheels at `at` (global, on the ground), going `velocity`,
## sliding as hard as `grit` (0 to 1), over ground of `tint`.
func update(delta: float, at: Vector3, velocity: Vector3, grit: float, tint: Color) -> void:
	_grit = lerpf(_grit,grit,1.0-exp(-delta/0.05))
	var on := _grit > LEAST
	if on != _stream.emitting: _stream.emitting = on
	if on:
		var flat := Vector3(velocity.x,0.0,velocity.z)
		var back := -flat.normalized() if flat.length() > 0.3 else Vector3.BACK
		_stream.global_position = at+Vector3.UP*0.1
		_stream.direction = (back+Vector3.UP*0.6).normalized()
		_stream.initial_velocity_min = KICK*_grit*0.5
		_stream.initial_velocity_max = KICK*_grit+flat.length()*0.15
		_stream.scale_amount_max = lerpf(SIZE.x,SIZE.y,_grit)
		_stream.color = tint
	var loud := clampf(_grit/0.6,0.0,1.0)
	if loud > 0.02:
		if not _hiss.playing: _hiss.play()
		_hiss.volume_db = HISS_DB+linear_to_db(loud)
		_hiss.pitch_scale = 1.0+HISS_PITCH*_grit
	elif _hiss.playing:
		_hiss.stop()

## A hard touch's dust out all round from `at` (global), as hard as `k`.
func burst(at: Vector3, k: float, tint: Color) -> void:
	var p := _particles(int(BURST*clampf(0.4+k,0.0,1.4)),true)
	p.color = tint
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = BURST_KICK*k*0.4
	p.initial_velocity_max = BURST_KICK*(0.3+k)
	add_child(p)
	p.global_position = at+Vector3.UP*0.1
	p.emitting = true
	p.finished.connect(p.queue_free)

## How hard it is sliding now (0 to 1, eased).
func grit() -> float:
	return _grit

## A loop of soft noise, low-passed: the wheels scrubbing.
static func hiss_sound() -> AudioStreamWAV:
	var rate := 22050
	var count := rate
	var data := PackedByteArray()
	data.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var low := 0.0
	var lower := 0.0
	for i in range(count):
		low = lerpf(low,rng.randf_range(-1.0,1.0),0.35)
		lower = lerpf(lower,low,0.5)
		var wobble := 0.75+0.25*sin(TAU*7.0*float(i)/rate)
		data.encode_s16(i*2,int(clampf(lower*wobble*1.6,-1.0,1.0)*20000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	wav.data = data
	return wav
