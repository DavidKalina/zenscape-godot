extends Node
## The pilot's footsteps (scripts/wanderer_eye.gd): a light little pat at each
## footfall the drawn body makes (scripts/pilot_figure.gd `drive`), so the
## sound lands as the boot does: a pitter-patter, six a second at a run. Its
## own feet, so not placed in the world: plain players on the Genesis bus (the
## Sound volume), quiet under the world, a little louder for a run, the left
## foot pitched a touch under the right so the steps go pit-ter pat-ter, each
## a little louder or softer than the last so a run never machine-guns. Soft
## soles, padded and cosy: every take swells in over ATTACK, is rounded off
## above its surface's CUTOFF and squeezed gently (`_wav`), with a low thud of
## the foot under it. What it walks on (`wanderer_eye.gd` `_surface`) sets the
## sound, each a short take of what that ground does under a small quick sole:
## - "grass" (and a wheat field's ground): a soft thud in a swish of blades;
## - "earth": bare ground and worn paths, a dull pat and a little grit;
## - "stone": rock, a muffled tock and a nudge of the toe;
## - "sand": a soft pat in a quick hush of grains;
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
const WALK_GAIN := 0.05
const RUN_GAIN := 0.07
const SLIDE_GAIN := 0.08
const LEVEL := {"grass":0.85,"earth":0.9,"stone":0.8,"sand":0.85,"snow":0.9,"wood":0.8,"water":0.9}
## Each step's gain wanders this many dB either way.
const JITTER_DB := 1.5
const PITCH := Vector2(0.96,1.04)
## The left foot's pitch and the right's, and how much higher a run's are.
const SIDE_PITCH := Vector2(0.96,1.04)
const RUN_PITCH := 0.02
## Seconds every take swells in over (a skid's swells slower), so no step
## starts on a click.
const ATTACK := 0.008
## Hz each surface's takes are rounded off above (two poles), and its skid's.
const CUTOFF := {"grass":1500.0,"earth":1300.0,"stone":1900.0,"sand":1700.0,"snow":1500.0,"wood":1600.0,"water":1400.0}
const SLIDE_CUTOFF := 1300.0
## Hz every take is thinned out below (two poles), so the thud under a step
## stays a soft pad, not a boom.
const LOW_CUT := 260.0
## How hard the gentle squeeze (tanh) drives each take's peak.
const SQUEEZE := 0.8

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
	player.volume_db = linear_to_db(lerpf(WALK_GAIN,RUN_GAIN,effort)*float(LEVEL.get(surface,1.0)))+_rng.randf_range(-JITTER_DB,JITTER_DB)
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

## The foot's padded thud under every step: a low tone (`pitch` Hz), swelling
## in over a few ms and gone in a twentieth of a second.
static func _thud(mix: PackedFloat32Array, pitch: float, loud: float, decay: float) -> void:
	for i in range(mix.size()):
		var t := float(i)/RATE
		mix[i] += loud*_env(t,0.0,0.004,decay)*sin(TAU*pitch*t*(1.0-0.15*minf(1.0,t*20.0)))

## One step's take. Every layer swells in and dies away inside SECONDS, so
## nothing clicks; all are quick, for a small sole and a quick step, and soft
## (`_wav` rounds off their tops).
static func _synth(surface: String, seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var total := int(RATE*SECONDS)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var noise := Bands.new(rng)
	match surface:
		"grass":
			# A soft thud in a swish of blades parting round the boot, both
			# gone inside a tenth of a second.
			noise.low_k = 0.07
			noise.fast_k = 0.3
			noise.slow_k = 0.08
			var lean := rng.randf_range(0.0,0.008)
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 1.0*_env(t,0.0,0.006,60.0)*noise.low+0.3*_env(t,0.004+lean,0.018,30.0)*noise.band
			_thud(mix,rng.randf_range(95.0,125.0),0.1,55.0)
		"earth":
			# A dull pat, then the sole's grit: a few dull ticks.
			noise.low_k = 0.07
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 2.0*_env(t,0.0,0.004,60.0)*noise.low+0.1*_env(t,0.01,0.008,45.0)*noise.band
			_grains(mix,rng,rng.randi_range(2,3),0.008,0.035,Vector2(500.0,1100.0),0.025,600.0)
			_thud(mix,rng.randf_range(90.0,120.0),0.12,50.0)
		"stone":
			# A muffled tock with a little ring, and a nudge of the toe after.
			var toe := rng.randf_range(0.025,0.04)
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				var tap := _env(t,0.0,0.003,150.0)+0.35*_env(t,toe,0.003,170.0)
				mix[i] = 0.35*tap*noise.band+0.9*_env(t,0.0,0.004,70.0)*noise.low
			for strike: float in [0.0,toe]:
				var ring := rng.randf_range(900.0,1400.0)
				var from := int(strike*RATE)
				for j in range(int(0.025*RATE)):
					if from+j >= total: break
					var age := float(j)/RATE
					mix[from+j] += 0.06*minf(1.0,age*RATE/30.0)*exp(-age*240.0)*sin(TAU*ring*age)
			_thud(mix,rng.randf_range(110.0,140.0),0.08,60.0)
		"sand":
			# A soft pat in a quick fine hiss of grains.
			noise.low_k = 0.07
			noise.fast_k = 0.7
			noise.slow_k = 0.25
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 1.1*_env(t,0.0,0.005,55.0)*noise.low+0.25*_env(t,0.006,0.012,32.0)*noise.band
			_grains(mix,rng,rng.randi_range(18,28),0.004,0.07,Vector2(1200.0,2400.0),0.035,1600.0)
			_thud(mix,rng.randf_range(90.0,115.0),0.08,55.0)
		"snow":
			# A short packed crunch, the grains squeaking low.
			noise.low_k = 0.06
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = 0.9*_env(t,0.0,0.006,40.0)*noise.low+0.16*_env(t,0.01,0.03,26.0)*noise.band
			_grains(mix,rng,rng.randi_range(25,35),0.008,0.09,Vector2(400.0,1100.0),0.07,400.0)
			_thud(mix,rng.randf_range(90.0,115.0),0.08,50.0)
		"wood":
			# A small plank's knock: the board's body and its rap, over a
			# breath of grit.
			var body := rng.randf_range(200.0,280.0)
			var rap := rng.randf_range(550.0,800.0)
			noise.slow_k = 0.1
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				var attack := minf(1.0,t*RATE/8.0)
				mix[i] = attack*(0.8*exp(-t*50.0)*sin(TAU*body*t)+0.2*exp(-t*130.0)*sin(TAU*rap*t)+0.15*exp(-t*160.0)*noise.band)
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
				mix[i] += 0.22*minf(1.0,age*RATE/30.0)*exp(-age*70.0)*sin(phase)
	return _wav(mix,float(CUTOFF.get(surface,1500.0)),ATTACK)

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
				mix[i] = shape.call(t)*(0.45*noise.band+0.6*noise.low)
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
			for i in range(total):
				var t := float(i)/RATE
				noise.next()
				mix[i] = shape.call(t)*(0.4*noise.band+0.6*noise.low)
			var tone := Vector2(400.0,1000.0) if surface == "snow" else Vector2(700.0,1600.0)
			_grains(mix,rng,rng.randi_range(25,40),0.01,SLIDE_SECONDS*0.7,tone,0.03,900.0)
	return _wav(mix,SLIDE_CUTOFF,0.03)

## Samples as a 16-bit take, softened: rounded off above `cutoff` Hz (two
## poles), swelled in over `attack` s, the tail faded to nothing, squeezed
## gently (tanh, SQUEEZE) so the first moment stands less proud of the rest,
## the loudest moment at 0.9.
static func _wav(mix: PackedFloat32Array, cutoff: float, attack: float) -> AudioStreamWAV:
	var total := mix.size()
	var k := 1.0-exp(-TAU*cutoff/RATE)
	var a := 0.0
	var b := 0.0
	for i in range(total):
		a = lerpf(a,mix[i],k)
		b = lerpf(b,a,k)
		mix[i] = b
	# Then the lows thinned out: the take less what a low-pass at LOW_CUT
	# keeps of it, twice.
	var low_k := 1.0-exp(-TAU*LOW_CUT/RATE)
	for _round in range(2):
		var under := 0.0
		for i in range(total):
			under = lerpf(under,mix[i],low_k)
			mix[i] -= under
	var swell := maxi(1,int(attack*RATE))
	for i in range(mini(swell,total)): mix[i] *= 0.5-0.5*cos(float(i)/swell*PI)
	var tail := int(total*0.25)
	for i in range(tail): mix[total-tail+i] *= cos(float(i)/tail*PI*0.5)
	var peak := 0.0001
	for v in mix: peak = maxf(peak,absf(v))
	var squeezed := tanh(SQUEEZE)
	var samples := PackedByteArray()
	samples.resize(total*2)
	for i in range(total): samples.encode_s16(i*2,int(clampf(0.9*tanh(SQUEEZE*mix[i]/peak)/squeezed,-1.0,1.0)*32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = samples
	return sound
