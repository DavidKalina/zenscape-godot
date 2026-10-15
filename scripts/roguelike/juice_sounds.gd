extends RefCounted
## [juice] The run's few feel-sounds, synthesised here (the game has no
## recorded assets; same method as scripts/collectibles_hud.gd): a muffled
## thud for a hit, a longer one for the last heart, a slow heartbeat, a warm
## chord for a find (fuller the rarer), a bell for the gate. Mono, 16-bit,
## each brought to a stated peak so the player's gain is the volume.
const RATE := 22050

static func _wav(samples: PackedFloat32Array, peak_to := 0.85) -> AudioStreamWAV:
	var peak := 0.0
	for v in samples: peak = maxf(peak,absf(v))
	var gain := peak_to/peak if peak > 0.0 else 1.0
	var data := PackedByteArray()
	data.resize(samples.size()*2)
	for i in range(samples.size()):
		data.encode_s16(i*2,int(clampf(samples[i]*gain,-1.0,1.0)*32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream

static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds*float(RATE)))
	return b

## A soft sine partial: `f` Hz from `at` s, decaying at `rate`, with a
## `attack` s ease in.
static func _tone(b: PackedFloat32Array, f: float, at: float, rate: float, amp: float, attack := 0.01, drop := 0.0) -> void:
	var start := int(at*float(RATE))
	var phase := 0.0
	for i in range(maxi(start,0),b.size()):
		var t := float(i-start)/float(RATE)
		var env := minf(t/attack,1.0)*exp(-rate*t)
		if env < 0.0004 and t > attack: break
		phase += TAU*(f*(1.0-drop*minf(t*4.0,1.0)))/float(RATE)
		b[i] += sin(phase)*env*amp

## Low-passed noise (a muffled body of sound) over `seconds`, decaying.
static func _thump(b: PackedFloat32Array, at: float, rate: float, amp: float, smooth: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var start := int(at*float(RATE))
	var lp := 0.0
	for i in range(maxi(start,0),b.size()):
		var t := float(i-start)/float(RATE)
		lp += (rng.randf_range(-1.0,1.0)-lp)*smooth
		b[i] += lp*exp(-rate*t)*amp

## A hit taken, heard through a wall: a low thump falling in pitch.
static func thud() -> AudioStreamWAV:
	var b := _buf(0.34)
	_tone(b,118.0,0.0,13.0,1.0,0.004,0.55)
	_tone(b,62.0,0.0,9.0,0.8,0.006,0.3)
	_thump(b,0.0,24.0,1.5,0.07)
	return _wav(b)

## The last heart: the thud, then a long low swell that hangs.
static func thud_last() -> AudioStreamWAV:
	var b := _buf(1.6)
	_tone(b,104.0,0.0,9.0,1.0,0.004,0.6)
	_tone(b,52.0,0.0,5.0,1.0,0.01,0.25)
	_tone(b,48.0,0.05,2.2,0.7,0.12)
	_tone(b,72.0,0.05,2.6,0.35,0.15)
	_thump(b,0.0,14.0,1.4,0.05)
	return _wav(b)

## One heartbeat: lub, dub, felt more than heard.
static func beat() -> AudioStreamWAV:
	var b := _buf(0.5)
	_tone(b,58.0,0.0,20.0,1.0,0.006,0.25)
	_tone(b,92.0,0.0,26.0,0.3,0.004)
	_tone(b,50.0,0.19,24.0,0.7,0.006,0.25)
	return _wav(b)

## A find: a warm chord, fuller for the rarer (`rarity` 1..3): a triad, then
## a seventh, then a ninth and a high glint, strummed a breath apart.
static func chord(rarity: int) -> AudioStreamWAV:
	var base := 220.0
	var ratios := [1.0,1.25,1.5]
	if rarity >= 2: ratios.append(15.0/8.0)
	if rarity >= 3: ratios.append_array([2.25,3.0])
	var b := _buf(1.7+0.5*float(rarity))
	for i in range(ratios.size()):
		var f: float = base*float(ratios[i])
		var at := 0.045*float(i)
		var rate := 2.1-0.25*float(rarity)
		_tone(b,f,at,rate,0.8,0.03)
		_tone(b,f*2.0,at,rate*1.5,0.22,0.03)
		_tone(b,f*1.004,at,rate,0.4,0.03)
	_tone(b,2093.0,0.05*float(ratios.size()),7.0-float(rarity),0.07+0.04*float(rarity),0.004)
	return _wav(b)

## The gate's light coming up: a soft rising breath.
static func gate_rise() -> AudioStreamWAV:
	var b := _buf(0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	for i in range(b.size()):
		var t := float(i)/float(RATE)
		var env := smoothstep(0.0,0.45,t)*(1.0-smoothstep(0.45,0.9,t))
		lp += (rng.randf_range(-1.0,1.0)-lp)*lerpf(0.03,0.2,t/0.9)
		b[i] = lp*env*0.9+sin(TAU*(280.0*t+260.0*t*t))*env*0.12
	return _wav(b)

## Arrival through the gate: a low bell and its fifth, ringing out.
static func gate_bell() -> AudioStreamWAV:
	var b := _buf(2.6)
	_tone(b,392.0,0.0,2.2,0.8,0.006)
	_tone(b,784.0,0.0,3.2,0.3,0.006)
	_tone(b,587.3,0.12,2.0,0.5,0.01)
	_tone(b,1175.0,0.12,4.0,0.12,0.006)
	_tone(b,196.0,0.0,1.8,0.45,0.02)
	return _wav(b)
