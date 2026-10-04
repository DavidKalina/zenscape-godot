extends Node
## The wanderer's footsteps (scripts/wanderer_eye.gd): one soft step at each
## footfall while you walk in its eyes. Its own feet, so not placed in the
## world: a plain player on the Genesis bus (the Sound volume), a little
## louder for a run. What it walks on (`wanderer_eye.gd` `_surface`) sets the
## sound, and each is built from what that ground does under a sole:
## - "grass": a hushed swish of blades and a faint soft thud;
## - "earth": bare ground and worn paths, a muffled heel and a little grit;
## - "stone": rock, a dry tap of heel then toe with a short scuff;
## - "sand": a soft heel sinking into a fine dry hiss of grains;
## - "snow": a slow packed crunch, grains squeaking as they give;
## - "wood": a footbridge's planks, a short hollow knock;
## - "water": wading, a soft slosh with a bubble or two.
## Each is VARIANTS takes, synthesized once and shared; a step never repeats
## the take before it and is pitched a little apart.

const Audio = preload("res://scripts/genesis_audio.gd")
const SURFACES := ["grass","earth","stone","sand","snow","wood","water"]
const RATE := 22050
const VARIANTS := 4
const SECONDS := 0.26
## Linear gain at a walk and at a full run, before the Sound volume, and each
## surface's share of it: grass hushes a step, stone and planks carry it.
const WALK_GAIN := 0.12
const RUN_GAIN := 0.2
const LEVEL := {"grass":0.75,"earth":0.9,"stone":0.85,"sand":0.8,"snow":0.9,"wood":1.0,"water":1.0}
const PITCH := Vector2(0.9,1.1)

static var _takes := {}

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := -1
var _rng := RandomNumberGenerator.new()
## Steps sounded, for probes.
var count := 0
var last_surface := ""

func _ready() -> void:
	name = "WandererSteps"
	Audio.ensure_buses()
	_rng.randomize()
	# Two players, so a step never cuts the last one's tail.
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = Audio.BUS
		add_child(player)
		_players.append(player)

## One footfall on `surface`, at `effort` (0 a stroll, 1 a full run).
func step(surface: String, effort: float) -> void:
	var takes: Array = takes_for(surface)
	var pick := _rng.randi_range(0,takes.size()-1)
	if pick == _last: pick = (pick+1)%takes.size()
	_last = pick
	var player := _players[_next]
	_next = (_next+1)%_players.size()
	player.stream = takes[pick]
	player.pitch_scale = _rng.randf_range(PITCH.x,PITCH.y)
	player.volume_db = linear_to_db(lerpf(WALK_GAIN,RUN_GAIN,clampf(effort,0.0,1.0))*float(LEVEL.get(surface,1.0)))
	player.play()
	count += 1
	last_surface = surface

static func takes_for(surface: String) -> Array:
	if not _takes.has(surface):
		var takes := []
		for i in range(VARIANTS): takes.append(_synth(surface,7717+i*131+absi(surface.hash())%997))
		_takes[surface] = takes
	return _takes[surface]

## Noise in three bands, one sample at a time: `low` (two poles at `low_k`),
## `band` (the difference of a fast and a slow pole) and `high` (white less
## a fast pole).
class Bands:
	var rng: RandomNumberGenerator
	var low_k := 0.06
	var fast_k := 0.5
	var slow_k := 0.12
	var _a := 0.0
	var _b := 0.0
	var _fast := 0.0
	var _slow := 0.0
	var _hi := 0.0
	var low := 0.0
	var band := 0.0
	var high := 0.0
	func _init(source: RandomNumberGenerator) -> void: rng = source
	func next() -> void:
		var white := rng.randf_range(-1.0,1.0)
		_a = lerpf(_a,white,low_k)
		_b = lerpf(_b,_a,low_k)
		_fast = lerpf(_fast,white,fast_k)
		_slow = lerpf(_slow,white,slow_k)
		_hi = lerpf(_hi,white,0.7)
		low = _b
		band = _fast-_slow
		high = white-_hi

## A rise over `attack` s, then a fall at `decay` a second, from `from` s.
static func _env(t: float, from: float, attack: float, decay: float) -> float:
	var age := t-from
	if age < 0.0: return 0.0
	return minf(1.0,age/maxf(attack,0.0001))*exp(-age*decay)

## Grains: `count` tiny ringing ticks (`tone` Hz range, each `size` at most)
## scattered through `span` s from `from`, thickest early.
static func _grains(mix: PackedFloat32Array, noise: RandomNumberGenerator, count: int, from: float, span: float, tone: Vector2, size: float, ring: float) -> void:
	for k in range(count):
		var at := from+span*pow(noise.randf(),1.6)
		var pitch := noise.randf_range(tone.x,tone.y)
		var loud := size*noise.randf_range(0.3,1.0)
		var start := int(at*RATE)
		for j in range(int(0.008*RATE)):
			if start+j >= mix.size(): break
			var age := float(j)/RATE
			mix[start+j] += loud*minf(1.0,age*RATE/2.0)*exp(-age*ring)*sin(TAU*pitch*age)

## One take. Every layer starts with a few-sample attack and dies away inside
## SECONDS, so nothing clicks.
static func _synth(surface: String, seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var total := int(RATE*SECONDS)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var noise := Bands.new(rng)
	match surface:
		"grass":
			# Blades parting: a band of noise that swells over 20 ms and
			# fades over a tenth of a second, over a faint soft thud.
			noise.fast_k = 0.35
			noise.slow_k = 0.05
			noise.low_k = 0.04
			var lean := rng.randf_range(0.0,0.02)
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 0.9*_env(t,0.0,0.004,40.0)*noise.low+0.5*_env(t,0.01+lean,0.02,14.0)*noise.band+0.12*_env(t,0.03+lean,0.03,18.0)*noise.high
		"earth":
			# A muffled heel, then the sole's grit: a few dull ticks.
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 2.2*_env(t,0.0,0.0014,30.0)*noise.low+0.12*_env(t,0.012,0.01,30.0)*noise.band
			_grains(mix,rng,rng.randi_range(3,6),0.012,0.05,Vector2(900.0,2000.0),0.04,700.0)
		"stone":
			# Heel then toe, each a dry tap: a short bright click with a
			# little ring, a scrape of grit after, and only a touch of body.
			var toe := rng.randf_range(0.05,0.08)
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				var tap := _env(t,0.0,0.001,160.0)+0.6*_env(t,toe,0.001,190.0)
				mix[i] = 0.9*tap*noise.high+0.5*_env(t,0.0,0.002,70.0)*noise.low+0.08*_env(t,toe+0.01,0.01,25.0)*noise.band
			for strike: float in [0.0,toe]:
				var ring := rng.randf_range(1900.0,3200.0)
				var from := int(strike*RATE)
				for j in range(int(0.03*RATE)):
					if from+j >= total: break
					var age := float(j)/RATE
					mix[from+j] += 0.18*minf(1.0,age*RATE/2.0)*exp(-age*220.0)*sin(TAU*ring*age)
			_grains(mix,rng,rng.randi_range(3,5),toe+0.01,0.06,Vector2(2500.0,4500.0),0.05,900.0)
		"sand":
			# The heel sinks softly; the grains hiss and crunch fine and dense.
			noise.fast_k = 0.7
			noise.slow_k = 0.25
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 1.2*_env(t,0.0,0.004,38.0)*noise.low+0.35*_env(t,0.008,0.012,20.0)*noise.band
			_grains(mix,rng,rng.randi_range(40,70),0.006,0.11,Vector2(2200.0,5000.0),0.06,1400.0)
		"snow":
			# Packed snow: the crunch builds as the sole presses in and
			# breaks off, grains squeaking low and many, over a muffled base.
			noise.low_k = 0.05
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 1.0*_env(t,0.0,0.01,26.0)*noise.low+0.18*_env(t,0.02,0.05,16.0)*noise.band
			_grains(mix,rng,rng.randi_range(45,70),0.015,0.14,Vector2(500.0,1500.0),0.09,350.0)
		"wood":
			# A plank's knock: two damped tones, the board's body and its
			# rap, over a breath of grit.
			var body := rng.randf_range(170.0,240.0)
			var rap := rng.randf_range(650.0,1000.0)
			noise.slow_k = 0.1
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				var attack := minf(1.0,t*RATE/8.0)
				mix[i] = attack*(0.8*exp(-t*38.0)*sin(TAU*body*t)+0.35*exp(-t*90.0)*sin(TAU*rap*t)+0.25*exp(-t*140.0)*noise.band)
		"water":
			# A slosh: low noise swelling and falling, and a bubble or two
			# rising.
			noise.low_k = 0.12
			noise.fast_k = 0.45
			noise.slow_k = 0.08
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = _env(t,0.0,0.02,14.0)*(1.6*noise.low+0.3*noise.band)
			for b in range(rng.randi_range(1,2)):
				var from := rng.randf_range(0.03,0.09)
				var pitch := rng.randf_range(380.0,560.0)
				var phase := 0.0
				for i in range(int(from*RATE),total):
					var age := float(i)/RATE-from
					phase += TAU*pitch*(1.0+age*9.0)/RATE
					mix[i] += 0.3*minf(1.0,age*RATE/6.0)*exp(-age*55.0)*sin(phase)
	# The tail fades to nothing; the loudest moment at 0.9.
	var tail := int(total*0.25)
	for i in range(tail): mix[total-tail+i] *= cos(float(i)/tail*PI*0.5)
	var peak := 0.0001
	for v in mix: peak = maxf(peak,absf(v))
	var samples := PackedByteArray()
	samples.resize(total*2)
	for i in range(total): samples.encode_s16(i*2,int(clampf(mix[i]*0.9/peak,-1.0,1.0)*32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = samples
	return sound
