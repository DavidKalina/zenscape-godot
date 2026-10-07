extends Node
## The pilot's footsteps (scripts/wanderer_eye.gd): a light little pat at each
## footfall the drawn body makes (scripts/pilot_figure.gd `drive`), so the
## sound lands as the boot does: a pitter-patter, six a second at a run. Its
## own feet, so not placed in the world: plain players on the Genesis bus (the
## Sound volume), a little louder for a run, the left foot pitched a touch
## under the right so the steps go pit-ter pat-ter. What it walks on
## (`wanderer_eye.gd` `_surface`) sets the sound, each a short take of what
## that ground does under a small quick sole:
## - "grass": a soft pat and a crisp brush of blades;
## - "earth": bare ground and worn paths, a dull pat and a little grit;
## - "stone": rock, a dry tap and a tick of the toe;
## - "sand": a soft pat in a quick hiss of grains;
## - "snow": a short packed crunch;
## - "wood": a footbridge's planks, a small hollow knock;
## - "water": wading, a plip and a bubble.
## Each is VARIANTS takes, synthesized once and shared; a step never repeats
## the take before it and is pitched a little apart. A skid (`slide`) scrapes
## the same ground for as long as one lasts.

const Audio = preload("res://scripts/genesis_audio.gd")
const SURFACES := ["grass","earth","stone","sand","snow","wood","water"]
const RATE := 22050
const VARIANTS := 4
## Seconds a step's take lasts, and a skid's.
const SECONDS := 0.16
const SLIDE_SECONDS := 0.42
## Linear gain at a walk and at a full run, before the Sound volume, and each
## surface's share of it: grass hushes a step, stone and planks carry it.
const WALK_GAIN := 0.12
const RUN_GAIN := 0.17
const SLIDE_GAIN := 0.2
const LEVEL := {"grass":0.8,"earth":0.9,"stone":0.85,"sand":0.8,"snow":0.9,"wood":1.0,"water":1.0}
const PITCH := Vector2(0.97,1.03)
## The left foot's pitch and the right's, and how much higher a run's are.
const SIDE_PITCH := Vector2(0.95,1.05)
const RUN_PITCH := 0.04

static var _takes := {}
static var _slides := {}

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := -1
var _slider: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
## Steps sounded, for probes.
var count := 0
var slides := 0
var last_surface := ""

func _ready() -> void:
	name = "WandererSteps"
	Audio.ensure_buses()
	_rng.randomize()
	# Three players, so a quick step never cuts the last ones' tails.
	for i in range(3):
		var player := AudioStreamPlayer.new()
		player.bus = Audio.BUS
		add_child(player)
		_players.append(player)
	_slider = AudioStreamPlayer.new()
	_slider.bus = Audio.BUS
	add_child(_slider)

## One footfall on `surface`, at `effort` (0 a stroll, 1 a full run), by the
## left foot (`side` 0), the right (1), or either (-1: a jump, a landing).
func step(surface: String, effort: float, side := -1) -> void:
	var takes: Array = takes_for(surface)
	var pick := _rng.randi_range(0,takes.size()-1)
	if pick == _last: pick = (pick+1)%takes.size()
	_last = pick
	var player := _players[_next]
	_next = (_next+1)%_players.size()
	effort = clampf(effort,0.0,1.0)
	var foot := 1.0 if side < 0 else (SIDE_PITCH.x if side == 0 else SIDE_PITCH.y)
	player.stream = takes[pick]
	player.pitch_scale = foot*(1.0+RUN_PITCH*effort)*_rng.randf_range(PITCH.x,PITCH.y)
	player.volume_db = linear_to_db(lerpf(WALK_GAIN,RUN_GAIN,effort)*float(LEVEL.get(surface,1.0)))
	player.play()
	count += 1
	last_surface = surface

## A skid's scrape over `surface`, from a run as fast as `effort` (0 to 1).
func slide(surface: String, effort: float) -> void:
	var takes: Array = slides_for(surface)
	_slider.stream = takes[_rng.randi_range(0,takes.size()-1)]
	_slider.pitch_scale = _rng.randf_range(PITCH.x,PITCH.y)
	_slider.volume_db = linear_to_db(SLIDE_GAIN*lerpf(0.6,1.0,clampf(effort,0.0,1.0))*float(LEVEL.get(surface,1.0)))
	_slider.play()
	slides += 1

static func takes_for(surface: String) -> Array:
	if not _takes.has(surface):
		var takes := []
		for i in range(VARIANTS): takes.append(_synth(surface,7717+i*131+absi(surface.hash())%997))
		_takes[surface] = takes
	return _takes[surface]

static func slides_for(surface: String) -> Array:
	if not _slides.has(surface):
		var takes := []
		for i in range(2): takes.append(_synth_slide(surface,5303+i*173+absi(surface.hash())%991))
		_slides[surface] = takes
	return _slides[surface]

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

## One step's take. Every layer starts with a few-sample attack and dies
## away inside SECONDS, so nothing clicks; all are quick, for a small sole
## and a quick step.
static func _synth(surface: String, seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var total := int(RATE*SECONDS)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var noise := Bands.new(rng)
	match surface:
		"grass":
			# A soft pat under a crisp brush of blades parting, both gone
			# inside a tenth of a second.
			noise.low_k = 0.08
			noise.fast_k = 0.5
			noise.slow_k = 0.1
			var lean := rng.randf_range(0.0,0.006)
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 1.0*_env(t,0.0,0.002,70.0)*noise.low+0.5*_env(t,0.004+lean,0.004,38.0)*noise.band+0.15*_env(t,0.008+lean,0.006,55.0)*noise.high
		"earth":
			# A dull pat, then the sole's grit: a few dull ticks.
			noise.low_k = 0.07
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 2.0*_env(t,0.0,0.0012,60.0)*noise.low+0.12*_env(t,0.01,0.006,45.0)*noise.band
			_grains(mix,rng,rng.randi_range(2,4),0.008,0.035,Vector2(900.0,2000.0),0.04,800.0)
		"stone":
			# A dry tap with a little ring, and a tick of the toe after.
			var toe := rng.randf_range(0.025,0.04)
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				var tap := _env(t,0.0,0.001,180.0)+0.4*_env(t,toe,0.001,200.0)
				mix[i] = 0.9*tap*noise.high+0.5*_env(t,0.0,0.002,80.0)*noise.low
			for strike: float in [0.0,toe]:
				var ring := rng.randf_range(2100.0,3400.0)
				var from := int(strike*RATE)
				for j in range(int(0.025*RATE)):
					if from+j >= total: break
					var age := float(j)/RATE
					mix[from+j] += 0.12*minf(1.0,age*RATE/2.0)*exp(-age*240.0)*sin(TAU*ring*age)
			_grains(mix,rng,rng.randi_range(2,3),toe+0.005,0.04,Vector2(2500.0,4500.0),0.04,1000.0)
		"sand":
			# A soft pat in a quick fine hiss of grains.
			noise.low_k = 0.07
			noise.fast_k = 0.7
			noise.slow_k = 0.25
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 1.1*_env(t,0.0,0.003,55.0)*noise.low+0.3*_env(t,0.006,0.008,32.0)*noise.band
			_grains(mix,rng,rng.randi_range(25,40),0.004,0.07,Vector2(2200.0,5000.0),0.06,1600.0)
		"snow":
			# A short packed crunch, the grains squeaking low.
			noise.low_k = 0.06
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 0.9*_env(t,0.0,0.006,40.0)*noise.low+0.16*_env(t,0.01,0.03,26.0)*noise.band
			_grains(mix,rng,rng.randi_range(30,45),0.008,0.09,Vector2(500.0,1500.0),0.09,400.0)
		"wood":
			# A small plank's knock: the board's body and its rap, over a
			# breath of grit.
			var body := rng.randf_range(200.0,280.0)
			var rap := rng.randf_range(700.0,1100.0)
			noise.slow_k = 0.1
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				var attack := minf(1.0,t*RATE/8.0)
				mix[i] = attack*(0.8*exp(-t*50.0)*sin(TAU*body*t)+0.35*exp(-t*110.0)*sin(TAU*rap*t)+0.25*exp(-t*160.0)*noise.band)
		"water":
			# A plip: low noise swelling and falling quickly, and a bubble
			# rising.
			noise.low_k = 0.12
			noise.fast_k = 0.45
			noise.slow_k = 0.08
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = _env(t,0.0,0.008,28.0)*(1.4*noise.low+0.35*noise.band)
			var from := rng.randf_range(0.015,0.04)
			var pitch := rng.randf_range(500.0,750.0)
			var phase := 0.0
			for i in range(int(from*RATE),total):
				var age := float(i)/RATE-from
				phase += TAU*pitch*(1.0+age*10.0)/RATE
				mix[i] += 0.3*minf(1.0,age*RATE/6.0)*exp(-age*70.0)*sin(phase)
	return _wav(mix)

## A skid's take: the sole dragged over the ground for SLIDE_SECONDS, juddering
## as it catches and slips, swelling in and dying as it stops.
static func _synth_slide(surface: String, seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var total := int(RATE*SLIDE_SECONDS)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var noise := Bands.new(rng)
	var judder := rng.randf_range(22.0,30.0)
	var at := rng.randf_range(0.0,TAU)
	var shape := func(t: float) -> float: return _env(t,0.0,0.02,6.5)*(0.72+0.28*sin(TAU*judder*t+at))
	match surface:
		"grass", "wood":
			# Blades (or boards) brushed flat: a long swish over a low rub.
			noise.fast_k = 0.4 if surface == "grass" else 0.25
			noise.slow_k = 0.06
			noise.low_k = 0.06
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = shape.call(t)*(0.6*noise.band+0.5*noise.low+0.06*noise.high)
		"water":
			# A long slosh, a bubble or two.
			noise.low_k = 0.12
			noise.fast_k = 0.45
			noise.slow_k = 0.08
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = shape.call(t)*(1.4*noise.low+0.4*noise.band)
		_:
			# Grit dragged: a scrape and a spray of grains through it.
			noise.fast_k = 0.6
			noise.slow_k = 0.15
			var bright := 0.25 if surface == "stone" else 0.1
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = shape.call(t)*(0.5*noise.band+0.4*noise.low+bright*noise.high)
			var tone := Vector2(500.0,1500.0) if surface == "snow" else Vector2(1500.0,4000.0)
			_grains(mix,rng,rng.randi_range(40,70),0.01,SLIDE_SECONDS*0.7,tone,0.05,900.0)
	return _wav(mix)

## Samples as a 16-bit take: the tail faded to nothing, the loudest moment
## at 0.9.
static func _wav(mix: PackedFloat32Array) -> AudioStreamWAV:
	var total := mix.size()
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
