extends Node
## The plane parts' own sounds (scripts/plane_arc/plane_arc.gd), made here
## and played on the world's sound bus:
##   `found`   a part taken: a small brass plate's clink, the whirr of a
##             propeller spinning up and spinning down, and a warm bell
##             leaping a fifth over it, pitched up the major pentatonic as
##             more of the six are found.
##   `seated`  a part fitted home: a low clunk, a ratchet of three quick
##             clicks and a clear ping, climbing as the plane fills.
##   `home`    all six home: the propeller's whirr spinning up and catching,
##             a bell run up the major chord into a bright held chord, a
##             soft warm swell under it.
## The samples are made once, as the tokens' are (scripts/collectibles_hud.gd).
const Audio = preload("res://scripts/genesis_audio.gd")
const TokensHud = preload("res://scripts/collectibles_hud.gd")

const RATE := TokensHud.RATE
## The clink's plate (Hz) and its partials (ratios, decays).
const PLATE := 1180.0
const PLATE_PARTIALS := [[1.0,9.0],[2.32,14.0],[4.25,22.0],[6.63,30.0]]
## The whirr: its tone and blade chop, each from x to y (Hz).
const WHIRR := Vector2(110.0,330.0)
const CHOP := Vector2(12.0,45.0)
## The found bell's two notes and the seated ping (Hz).
const BELL := [784.0,1174.7]
const PING := 1046.5
## The home run, its chord and the swell's notes under it (Hz).
const RUN := [523.3,659.3,784.0,1046.5,1318.5]
const CHORD := [784.0,1046.5,1318.5,1568.0]
const SWELL := [130.8,196.0,261.6]
## Gains (linear, under the world's sound volume) and the steps a find
## climbs (semitones), one per part.
const FOUND_GAIN := 0.24
const SEATED_GAIN := 0.28
const HOME_GAIN := 0.2
const STEPS := [0,2,4,7,9,12]

var _found: AudioStreamPlayer
var _seated: AudioStreamPlayer
var _home: AudioStreamPlayer

func _ready() -> void:
	name = "PartSounds"
	Audio.ensure_buses()
	_found = _player(_found_sound(),FOUND_GAIN)
	_seated = _player(_seated_sound(),SEATED_GAIN)
	_home = _player(_home_sound(),HOME_GAIN)

## A part taken, the `count`th of the six found (1 the first).
func found(count: int) -> void:
	_play(_found,count)

## A part fitted, the `count`th home (1 the first).
func seated(count: int) -> void:
	_play(_seated,count)

## All six home.
func home() -> void:
	if _home.is_inside_tree(): _home.play()

func _play(player: AudioStreamPlayer, count: int) -> void:
	player.pitch_scale = pow(2.0,STEPS[clampi(count-1,0,STEPS.size()-1)]/12.0)
	if player.is_inside_tree(): player.play()

func _player(stream: AudioStreamWAV, gain: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = Audio.BUS
	player.stream = stream
	player.volume_db = linear_to_db(gain)
	player.max_polyphony = 3
	add_child(player)
	return player

## A warm bell at `f` Hz from `s` s into it: the note and a soft octave and
## twelfth over it, the overtones dying first; a 3 ms rise and a fall of
## `decay`.
static func _bell(f: float, s: float, decay: float) -> float:
	if s < 0.0: return 0.0
	var env := minf(s/0.003,1.0)*exp(-s*decay)
	var v := sin(TAU*f*s)+0.35*sin(TAU*f*2.0*s)*exp(-s*6.0)+0.15*sin(TAU*f*3.0*s)*exp(-s*12.0)
	return env*v


## A part found: the clink at once, the whirr winding up under it and away,
## the bell coming in as the whirr peaks, its fifth after.
static func _found_sound() -> AudioStreamWAV:
	var n := int(1.2*RATE)
	var data := PackedFloat32Array()
	data.resize(n)
	var tone := 0.0
	var chop := 0.0
	for i in range(n):
		var t := float(i)/RATE
		var v := 0.0
		for p: Array in PLATE_PARTIALS:
			v += 0.4*sin(TAU*PLATE*float(p[0])*t)*exp(-t*float(p[1]))/float(p[0])
		v *= minf(t/0.002,1.0)
		# The whirr: up over 0.25 s, then dying.
		var up := smoothstep(0.0,0.25,t)
		tone += TAU*lerpf(WHIRR.x,WHIRR.y,up)/RATE
		chop += TAU*lerpf(CHOP.x,CHOP.y,up)/RATE
		var whirr := tanh(2.0*(sin(tone)+0.5*sin(2.0*tone)))*(0.55+0.45*sin(chop))
		v += 0.22*whirr*smoothstep(0.02,0.12,t)*exp(-maxf(t-0.25,0.0)*9.0)
		v += 0.7*_bell(BELL[0],t-0.2,4.0)
		v += 0.6*_bell(BELL[1],t-0.29,3.0)
		data[i] = v
	return TokensHud._wav(data)

## A part seated: the clunk, the ratchet's three clicks closing up, the
## ping as it locks.
static func _seated_sound() -> AudioStreamWAV:
	var n := int(1.0*RATE)
	var data := PackedFloat32Array()
	data.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var thud := 0.0
	var low := 0.0
	for i in range(n):
		var t := float(i)/RATE
		thud += TAU*lerpf(55.0,140.0,exp(-t*25.0))/RATE
		var noise := rng.randf_range(-1.0,1.0)
		low = lerpf(low,noise,0.08)
		var v := (0.9*sin(thud)+0.8*low)*minf(t/0.002,1.0)*exp(-t*18.0)
		for at: float in [0.07,0.12,0.155]:
			var s := t-at
			if s >= 0.0 and s < 0.03:
				v += (0.35*noise+0.5*sin(TAU*3200.0*s))*exp(-s*260.0)
		v += 0.6*_bell(PING,t-0.2,4.5)
		data[i] = v
	return TokensHud._wav(data)

## All six home: the whirr winding up and settling into a steady purr as
## the bells run up the chord, the chord struck bright and let ring, a
## soft swell of plain sines under it.
static func _home_sound() -> AudioStreamWAV:
	var n := int(3.0*RATE)
	var data := PackedFloat32Array()
	data.resize(n)
	var tone := 0.0
	var chop := 0.0
	for i in range(n):
		var t := float(i)/RATE
		var v := 0.0
		var up := smoothstep(0.0,0.6,t)
		tone += TAU*lerpf(WHIRR.x,WHIRR.y*0.8,up)/RATE
		chop += TAU*lerpf(CHOP.x,CHOP.y*1.3,up)/RATE
		var whirr := tanh(1.6*(sin(tone)+0.4*sin(2.0*tone)))*(0.6+0.4*sin(chop))
		v += 0.13*whirr*smoothstep(0.0,0.2,t)*exp(-maxf(t-0.7,0.0)*2.5)
		for k in range(RUN.size()):
			v += 0.45*_bell(RUN[k],t-0.08*k,5.0)
		for k in range(CHORD.size()):
			v += 0.32*_bell(CHORD[k],t-0.5-0.012*k,1.3)
		var swell := 0.0
		for f: float in SWELL: swell += sin(TAU*f*t)
		v += 0.12*swell*smoothstep(0.3,0.9,t)*exp(-maxf(t-0.9,0.0)*1.6)
		data[i] = v
	return TokensHud._wav(data)
