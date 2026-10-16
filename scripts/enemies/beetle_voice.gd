extends RefCounted
## The Millstone Beetle's placeholder sounds: short synthesized calls in the
## enemy yard's style
## (studies/enemy_yard.gd `_synth`), and the wheel's rolling grind, a loop
## whose loudness follows the wheel's pace. Never heard as finished sound:
## stand-ins for a sound pass.

## [seconds, tone (Hz, 0 none), tone at the end, noise share, low-pass (0-1),
## attack (s), tremolo (Hz, 0 none)].
const VOICES := {
	# The ratchet of the wheel in its grip: the tell's clicks.
	"beetle_click":[0.07,1400.0,700.0,0.45,0.85,0.001,0.0],
	# The last click, heavier: the hold before it goes.
	"beetle_clack":[0.12,520.0,260.0,0.5,0.6,0.001,0.0],
	# Noticing him: a dry hiss through the shell's plates.
	"beetle_hiss":[0.45,0.0,0.0,1.0,0.75,0.05,0.0],
	# The launch: feet scrabbling on stone.
	"beetle_charge":[0.35,0.0,0.0,1.0,0.5,0.005,40.0],
	"beetle_scrabble":[0.5,0.0,0.0,1.0,0.5,0.01,28.0],
	# The skid: stone grinding on stone.
	"beetle_grind":[0.7,60.0,40.0,0.75,0.25,0.02,18.0],
	"beetle_thud":[0.25,55.0,35.0,0.4,0.18,0.002,0.0],
	# The wheel hitting the ground, landing far below, jamming in a gap.
	"wheel_thud":[0.35,48.0,30.0,0.45,0.15,0.002,0.0],
	"wheel_crash":[1.1,40.0,22.0,0.6,0.12,0.003,0.0],
	"wheel_jam":[0.6,70.0,38.0,0.7,0.3,0.002,12.0],
}

## How far each is heard (m, the player's unit size).
const REACH := {"beetle_click":7.0,"beetle_clack":9.0,"wheel_crash":30.0,"wheel_jam":16.0,"wheel_thud":12.0}

static var _cache := {}

static func has(key: String) -> bool:
	return VOICES.has(key)

## Plays `key` at `at` under `parent` (an AudioStreamPlayer3D freed when done).
static func play(parent: Node, key: String, at: Vector3) -> void:
	if not VOICES.has(key) or parent == null or not parent.is_inside_tree(): return
	if not _cache.has(key): _cache[key] = synth(VOICES[key])
	var player := AudioStreamPlayer3D.new()
	player.stream = _cache[key]
	parent.add_child(player)
	player.global_position = at
	player.unit_size = float(REACH.get(key,8.0))
	player.finished.connect(player.queue_free)
	player.play()

## The rolling grind: a low rumble, looped (`loop` on its stream).
static func rumble() -> AudioStreamWAV:
	if not _cache.has("_rumble"):
		var w := synth([1.0,38.0,38.0,0.8,0.08,0.0,7.0],false)
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size()/2
		_cache["_rumble"] = w
	return _cache["_rumble"]

## A short sound from its spec (`fade` off: an even loop, no envelope).
static func synth(v: Array, fade := true) -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(v[0])*rate)
	var data := PackedByteArray()
	data.resize(n*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	var low := 0.0
	var phase := 0.0
	for i in range(n):
		var t := float(i)/rate
		var k := t/float(v[0])
		var env := minf(t/maxf(float(v[5]),0.001),1.0)*pow(1.0-k,1.5) if fade else 1.0
		if float(v[6]) > 0.0: env *= 0.6+0.4*sin(TAU*float(v[6])*t)
		low = lerpf(low,rng.randf_range(-1.0,1.0),float(v[4]))
		var tone := 0.0
		if float(v[1]) > 0.0:
			phase += lerpf(float(v[1]),float(v[2]),k)/rate
			tone = fposmod(phase,1.0)*2.0-1.0
		var s := clampf((low*float(v[3])+tone*(1.0-float(v[3])))*env*0.8,-1.0,1.0)
		data.encode_s16(i*2,int(s*32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
