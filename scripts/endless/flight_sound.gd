extends Node
## Endless flight's sound: the plane and the open air, made to follow what
## the flight does every frame. Ported from the kit isle's soundscape
## (git tag archive/before-the-cut, scripts/kit_isle/kit_audio.gd) without
## the walker, rope, beasts, boarding and the isles' place beds.
##
## The study makes one (`FlightSound.new()`), adds it as a child and calls
## `step(delta, study, events, boost)` each frame next to the pad's rumble.
## It only reads the study (`plane`, `hand_landing`, `ground_scale`, `field`
## and its physics world); nothing here steers anything.
##
## - Engine: a loop whose gain and pitch follow the throttle (Boost lifts
##   both) and the speed; `engine-start` when the engine comes on while on
##   the wheels (the game starts in the air and never switches it off, so it
##   waits for a game that does).
## - Air: a rush, a whistle and a hollow howl by airspeed (as a share of the
##   plane's cruise), more in a dive and in a hard pull (the wingtip
##   vapour's own turn rate), brighter the faster (a live low-pass on the
##   "SFX Air" bus); the wires sing on the knife edge, a drift and a pull.
## - Whoosh: a ring of ray probes round the plane against the physics world
##   (the land, arches, halls, trees, tunnels: layer 1) reaching further the
##   faster it flies; stone coming close rises `near` (rush and whistle swell,
##   a whoosh panned to its side), stone on several sides rises `enclosed`
##   (the howl).
## - Wheels: the landing's events (scripts/manual_landing.gd `step`, the dict
##   scripts/endless/flight_rumble.gd reads): a touch's thump by its `k`, a
##   greaser's tap, a hop (`bounce`), a `hit`, a slide breaking loose; the
##   rumble by ground speed and the skid by the landing's grit.
## - Ambience: a breeze that grows with height over the ground and swells with
##   the wind where the plane is (the wind field's, hushed in calm), a thin high
##   wind up near the ceiling, and a shore bed near the sea (a ring of land
##   samples: water on one side and land on the other is a coast; open sea
##   a lesser surf), low only.
##
## - The bore: inside a bore or under rock closed in round the plane (`_bore`),
##   the plane's voices (engine, wires, the air and its whooshes) and the bore's
##   own (`bore_burst`, `bore_tell`) go through a short stone room: a reverb and
##   an EQ (low-mid boom, the hiss damped) on "SFX Bore", eased in over
##   BORE_IN s and out over BORE_OUT s (`bore_wet`, 0 to 1).
##
## Buses (`ensure_buses`): Master > SFX (the Effects volume) > SFX Bore (the
## stone room) > SFX Air; Master > Ambience (the Ambience volume). Settings are user://sound.cfg's
## ("sound", "ambience"; master and mute are genesis_audio's).
##
## Plays only in a windowed run: headless there are no buses and no players,
## but every layer's goal, gain and pitch still run (for a driver to read).
## `--sound=0` is silent, `--sound=on` plays headless too (a proof's).

const Audio = preload("res://scripts/genesis_audio.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const AmbientSound = preload("res://scripts/endless/ambient_sound.gd")

const SFX := &"SFX"
const AIR := &"SFX Air"
const BORE := &"SFX Bore"
const AMBIENCE := &"Ambience"
const DEFAULT_AMBIENCE := 0.8
const KIT := "res://assets/audio/kit/"
const FOLEY := "res://assets/audio/foley/"
const BURROWER := "res://assets/audio/burrower/"
const BORE_AUDIO := "res://assets/audio/bore/"
const OLD := "res://assets/audio/"

# --- Tuning ----------------------------------------------------------------------

## Airspeed as a share of the plane's cruise where the rush starts and is
## full (cruise is about 0.44 of the way, Boost about 0.78, a dive's top 1).
## The cruise is today's (the plane's over its pace, scripts/flight_pace.gd),
## so a faster pace sounds faster. Past the full end, `over` runs 0 to 1 over
## AIR_OVER more shares (a fast pace's Boost and surge): the rush and whistle
## rise OVER_PITCH higher, the whistle gains WHISTLE_OVER and the air opens
## OVER_CUT Hz more.
const AIR_SPEED := Vector2(0.3,1.85)
const AIR_OVER := 1.3
const OVER_PITCH := 0.15
const WHISTLE_OVER := 0.04
const OVER_CUT := 3000.0
## The rush's gain at the quiet end and the full end, and what rock close
## by, a dive and a hard pull add; its low-pass (Hz) closed and open, and
## what rock close by and a dive add.
const RUSH := Vector2(0.025,0.3)
const RUSH_NEAR := 0.16
const RUSH_DIVE := 0.12
const RUSH_PULL := 0.05
const RUSH_BOOST := 0.04
const RUSH_CUT := Vector2(450.0,5200.0)
const RUSH_CUT_NEAR := 3000.0
const RUSH_CUT_DIVE := 1500.0
const WHISTLE := 0.07
const WHISTLE_NEAR := 0.06
const WHISTLE_PULL := 0.05
const WHISTLE_DIVE := 0.05
const HOWL := 0.17
## The wingtip vapour's own turn rate (rad/s) where a pull starts and is full.
const PULL_TURN := Vector2(0.7,1.5)
## The nose-down share of the speed where a dive starts and is full.
const DIVE_SINK := Vector2(0.15,0.7)
## The whoosh past rock: `near` rising through WHOOSH_AT starts one, at
## WHOOSH_GAIN, no sooner than WHOOSH_GAP s after the last, only above
## WHOOSH_SPEED m/s.
const WHOOSH_AT := 0.4
const WHOOSH_GAIN := 0.22
const WHOOSH_GAP := 0.7
const WHOOSH_SPEED := 9.0
## The ray ring round the plane: its reach is the larger of PROBE_SPANS
## wingspans and PROBE_LEAD seconds of flight (m), PROBE_RAYS rays a frame;
## the ray straight down counts PROBE_DOWN of a side's (skimming the land is
## a gentler pass than a cliff). Physics layer 1: the land and every ruin.
const PROBE_SPANS := 3.2
const PROBE_LEAD := 0.45
const PROBE_RAYS := 3
const PROBE_DOWN := 0.7
const PROBE_MASK := 1
const PROBE_DIRS := [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(0.7,0.7),Vector2(-0.7,0.7),Vector2(0.7,-0.7),Vector2(-0.7,-0.7)]
## The engine: its gain at a cruise, what full throttle adds (braking takes
## ENGINE_BRAKE), what speed adds; its pitch idling, per cruise of speed,
## and what the throttle adds.
const ENGINE := 0.085
const ENGINE_THROTTLE := 0.05
const ENGINE_BRAKE := 0.025
const ENGINE_FAST := 0.03
const ENGINE_PITCH := 0.78
const ENGINE_PER_CRUISE := 0.26
const ENGINE_PITCH_THROTTLE := 0.16
const ENGINE_SPUN_DOWN := 0.45
const ENGINE_START := 0.16
## Strain: the wires' gain at a full knife edge, drift or pull.
const WIRES := 0.07
## Wheels on the land: the rumble's and skid's gain at full, the ground speed
## (m/s) the rumble is full at, and the skid's floor while sliding.
const RUMBLE := 0.2
const SKID := 0.16
const RUMBLE_FULL := 12.0
const SKID_SLIDING := 0.4
## A touch's thump: gain and pitch (a hard one lower, louder); a greaser's
## tap; a hop's, by its sink (m/s) over HOP_SINK; a hit's.
const THUMP := Vector2(0.22,0.6)
const THUMP_PITCH := Vector2(1.05,0.93)
const TAP := 0.12
const TAP_PITCH := 1.2
const HOP := Vector2(0.3,0.7)
const HOP_SINK := 9.0
const HIT := 0.5
## Near the land (scripts/endless/near_miss.gd, flight_contact.gd): a scored
## moment's sharp swish and a whoosh over it, louder and higher by its
## closeness (NEAR gain from k 0 to 1, NEAR_PITCH); a scrape's grind
## (SCRAPE, with leaves off a tree, a splash off the water, debris off
## stone); a crash's break and debris (CRASH).
const NEAR := Vector2(0.14,0.32)
const NEAR_PITCH := Vector2(1.05,1.35)
## The bells of the line's multiplier stepping up (`_near`).
const LINE_SWITCH := 0.1
const LINE_FLOURISH := 0.3
const SCRAPE := 0.4
const CRASH := 0.7
## A tree knocked down (`events` "knock"): its crack, branches and needles
## (the fall's creak and thud are scripts/endless/tree_knock.gd's, at the tree).
const KNOCK := 0.45
## The air over the ground: the breeze's gain on the ground and well up (m
## over the land), the thin high wind's (over the sea, up to the ceiling),
## the shore's.
const BREEZE := Vector2(0.03,0.08)
const BREEZE_HEIGHT := Vector2(2.0,120.0)
## The breeze by the wind where the plane is (EndlessLook wind_here: the wind
## field's, on top of the height's bed): the bed's share in a still hollow and
## at full wind (`WIND_SHARE`, by the wind between `WIND_AT`), and the gain the
## wind adds over it (`WIND_SWELL`, by the wind between `SWELL_AT`), its pitch
## lift. With no field (other worlds, --wind=off) the height's bed alone.
const WIND_SHARE := Vector2(0.45,1.0)
const WIND_AT := Vector2(0.1,0.6)
const WIND_SWELL := 0.07
const SWELL_AT := Vector2(0.45,1.4)
const WIND_PITCH := 0.08
const THIN := 0.07
const THIN_HEIGHT := Vector2(50.0,215.0)
const SHORE := 0.14
## Open sea's share of the shore bed, and the height over the sea it fades out
## between.
const SURF := 0.45
const SHORE_HEIGHT := Vector2(30.0,130.0)
## The bore's stone room (`_bore`, the "SFX Bore" bus): the time (s) it eases in
## and out over; the reverb's room (0 to 1), damping, pre-delay (ms) and its wet
## and dry in full; the EQ's gains in full (dB, AudioEffectEQ6's bands: 32, 100,
## 320, 1000, 3200, 10000 Hz); what's left of the air's low-pass cutoff in full
## (the high hiss damped). Closed in: rock overhead (NearMiss `overhead`) with
## `enclosed` past BORE_SIDES counts as in a bore too (a hall, a long arch run).
const BORE_IN := 0.45
const BORE_OUT := 0.55
const BORE_ROOM := 0.32
const BORE_DAMP := 0.55
const BORE_PREDELAY := 14.0
const BORE_WET := 0.34
const BORE_DRY := 0.85
const BORE_EQ := [0.0,2.5,4.0,0.5,-3.0,-6.0]
const BORE_AIR_CUT := 0.6
const BORE_SIDES := 0.3
## A spur bursting out of the rock (`bore_burst`): the three layers' gains, and
## how far its 3D voice carries: full within BORE_UNIT m, falling off to
## nothing at BORE_REACH m (the plane hears it ahead and to the side; he runs
## some 40-150 m ahead of it). The tell's grind (`bore_tell`) and its reach.
const BURST_THUMP := 1.4
const BURST_CRACK := 1.0
const BURST_DEBRIS := 0.7
const BORE_UNIT := 45.0
const BORE_REACH := 260.0
const TELL := 0.45
const TELL_REACH := 180.0
## The place read: seconds between, the land samples' rings (m, count).
const PLACE_TICK := 0.4
const PLACE_RINGS := [Vector2(0.0,1.0),Vector2(50.0,6.0),Vector2(130.0,8.0)]

## A looping voice: its gain and pitch eased toward their goals (per second
## rates up and down), stopped while silent and started again at a random
## point of its loop when heard (a silent bed holds no playback in the
## AudioServer). Without a player (headless) it only eases.
class Bed extends RefCounted:
	var player
	var gain := 0.0
	var goal := 0.0
	var pitch := 1.0
	var pitch_goal := 1.0
	var attack := 5.0
	var release := 2.5
	func step(delta: float) -> void:
		gain = lerpf(gain,goal,1.0-exp(-delta*(attack if goal > gain else release)))
		if goal <= 0.0 and gain < 0.0006: gain = 0.0
		pitch = lerpf(pitch,pitch_goal,1.0-exp(-delta*6.0))
		if player == null: return
		if gain <= 0.0:
			if player.playing: player.stop()
			return
		if not player.playing: player.play(randf()*player.stream.get_length())
		player.volume_db = linear_to_db(gain)
		player.pitch_scale = clampf(pitch,0.1,4.0)

# Voices.
var rush: Bed
var whistle: Bed
var howl: Bed
var engine: Bed
var wires: Bed
var rumble: Bed
var skid: Bed
var breeze: Bed
var thin: Bed
var shore: Bed
## The weather's rain (scripts/endless/weather_rain.gd `rain_to`): made on
## its first call with rain, so a run with no rain builds none.
var rain: Bed
## The living ground's beds and calls (scripts/endless/ambient_sound.gd); null under --ambient-sound=0.
var ambient: Node

# State read each frame (public for probes).
## How close stone is round the plane (0 open air, 1 skimming it), how
## closed in it is (0 open, 1 threading a gap), the nearer side (-1 left).
var near := 0.0
var enclosed := 0.0
var side := 0.0
## A hard pull (0 to 1: the flight path's turn rate) and a dive (0 to 1).
var pull := 0.0
var dive := 0.0
## Airspeed as the rush reads it (0 to 1), the height over the ground and
## over the sea (m), and the share of water round the plane (0 to 1).
var fast := 0.0
var over := 0.0
var agl := 0.0
var alt := 0.0
var water := 0.0
## The wind where the plane is (the field's, eased; 0..2) and how far in its
## land (0..1); -1 with no field.
var wind := -1.0
var wind_reach := 0.0
## One-shots played, by kind, and the last (kind, gain, pitch, at): for probes.
var played := {}
var last_shot := {}
## The bore's room eased in (0 open air, 1 in a bore: `_bore`), and whether this
## frame counts as in one. The bore's voices heard, the latest last (at most 64):
## {kind, at, msec}, for probes.
var bore_wet := 0.0
var in_bore := false
var bore_heard: Array[Dictionary] = []
## True when there are players (a windowed run).
var audible := false
## Muffled (0 to 1, set from outside: scripts/endless/water_contact.gd when
## the screen is doused): the air's low-pass closed down to MUFFLE_CUT of it.
var muffle := 0.0
const MUFFLE_CUT := 0.12

var _rng := RandomNumberGenerator.new()
var _beds: Array[Bed] = []
var _clips := {}
var _last := {}
var _pool2: Array[AudioStreamPlayer] = []
var _pool3: Array[AudioStreamPlayer3D] = []
var _next2 := 0
var _next3 := 0
var _probe := PackedFloat32Array()
var _probe_next := 0
var _ray: PhysicsRayQueryParameters3D
var _whoosh_wait := 0.0
var _place_wait := 0.0
var _engine_was := -1.0
var _last_way := Vector3.ZERO
var _air_lpf: AudioEffectLowPassFilter
var _reverb: AudioEffectReverb
var _eq: AudioEffectEQ6
var _off := false

# --- Buses and settings --------------------------------------------------------

## SFX and Ambience under Master, SFX Air under SFX (a low-pass at index 0:
## the air's brightness), and a ceiling on Master so no pile-up can overload
## the output. The Genesis bus too (scripts/genesis_audio.gd).
static func ensure_buses() -> void:
	Audio.ensure_buses()
	_bus(SFX,&"Master",[])
	if AudioServer.get_bus_index(BORE) < 0:
		_bus(BORE,SFX,[AudioEffectEQ6.new(),_bore_reverb()])
		for i in range(2): AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(BORE),i,false)
	_bus(AIR,BORE,[_lpf(2000.0)])
	_bus(AMBIENCE,&"Master",[])
	for i in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0,i) is AudioEffectHardLimiter: return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0,limiter)

## The stone room's reverb, dry in full and no wet (`_bore` eases it).
static func _bore_reverb() -> AudioEffectReverb:
	var r := AudioEffectReverb.new()
	r.room_size = BORE_ROOM
	r.damping = BORE_DAMP
	r.spread = 0.7
	r.hipass = 0.08
	r.predelay_msec = BORE_PREDELAY
	r.predelay_feedback = 0.3
	r.dry = 1.0
	r.wet = 0.0
	return r

static func _lpf(hz: float) -> AudioEffectLowPassFilter:
	var f := AudioEffectLowPassFilter.new()
	f.cutoff_hz = hz
	return f

static func _bus(bus: StringName, send: StringName, effects: Array) -> void:
	if AudioServer.get_bus_index(bus) >= 0: return
	AudioServer.add_bus()
	var index := AudioServer.bus_count-1
	AudioServer.set_bus_name(index,bus)
	AudioServer.set_bus_send(index,send)
	for effect: AudioEffect in effects: AudioServer.add_bus_effect(index,effect)

## The Effects volume (`sound`, the Genesis bus's too) on SFX and `ambience`
## on Ambience. Master and mute are genesis_audio's (`Audio.apply_settings`).
static func apply_settings(settings: Dictionary) -> void:
	ensure_buses()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX),linear_to_db(maxf(0.0001,float(settings.get("sound",0.8)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(AMBIENCE),linear_to_db(maxf(0.0001,float(settings.get("ambience",DEFAULT_AMBIENCE)))))

## The kept settings (user://sound.cfg: master, sound, ambience, muted).
static func load_settings(path := Audio.SETTINGS_PATH) -> Dictionary:
	var settings := Audio.DEFAULTS.duplicate()
	settings["ambience"] = DEFAULT_AMBIENCE
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for key: String in ["master","sound","ambience"]:
			settings[key] = clampf(float(file.get_value("sound",key,settings[key])),0.0,1.0)
		settings.muted = bool(file.get_value("sound","muted",settings.muted))
	return settings

## Whether this run plays sound: windowed, unless `--sound=0` (never) or
## `--sound=on` (headless too).
static func wanted() -> bool:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--sound=0": return false
		if arg == "--sound=on": return true
	return DisplayServer.get_name() != "headless"

# --- Setup ------------------------------------------------------------------------

func _init() -> void:
	name = "FlightSound"

func _ready() -> void:
	_rng.randomize()
	_probe.resize(PROBE_DIRS.size())
	audible = wanted()
	if audible:
		ensure_buses()
		Audio.apply_settings(Audio.load_settings())
		apply_settings(load_settings())
		_air_lpf = AudioServer.get_bus_effect(AudioServer.get_bus_index(AIR),0) as AudioEffectLowPassFilter
		_eq = AudioServer.get_bus_effect(AudioServer.get_bus_index(BORE),0) as AudioEffectEQ6
		_reverb = AudioServer.get_bus_effect(AudioServer.get_bus_index(BORE),1) as AudioEffectReverb
	rush = _bed(KIT+"air-rush-loop.wav",AIR)
	whistle = _bed(KIT+"air-whistle-loop.wav",AIR)
	howl = _bed(KIT+"air-howl-loop.wav",AIR)
	engine = _bed(KIT+"engine-loop.wav",BORE)
	engine.attack = 3.0
	engine.release = 1.2
	wires = _bed(KIT+"wire-sing-loop.wav",BORE)
	rumble = _bed(KIT+"wheel-rumble-loop.wav",SFX)
	skid = _bed(KIT+"skid-loop.wav",SFX)
	breeze = _bed(OLD+"wind-bed.wav",AMBIENCE)
	thin = _bed(KIT+"thin-wind-loop.wav",AMBIENCE)
	shore = _bed(OLD+"shore-bed.wav",AMBIENCE)
	for bed in [breeze,thin,shore]:
		bed.attack = 0.7
		bed.release = 0.6
	if AmbientSound.wanted():
		ambient = AmbientSound.new()
		add_child(ambient)
	if not audible: return
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = SFX
		add_child(p)
		_pool2.append(p)
	for i in range(16):
		var p := AudioStreamPlayer3D.new()
		p.bus = SFX
		add_child(p)
		_pool3.append(p)
	_clips = {
		"thump":_takes(KIT+"thump-%d.wav",3),"creak":_takes(KIT+"creak-%d.wav",6),
		"whoosh":_takes(KIT+"whoosh-%d.wav",4),"start":[load(KIT+"engine-start.wav")],
		"swish":_takes(KIT+"swish-%d.wav",4),"grind":_takes(FOLEY+"land-grind-%d.wav",6),
		"crash":_takes(FOLEY+"mesa-break-%d.wav",6),"debris":_takes(KIT+"rock-debris-%d.wav",3),
		"splash":_takes(FOLEY+"water-splash-%d.wav",6),"leaves":_takes(FOLEY+"trees-%d.wav",6),
		# A tree knocked down (scripts/endless/tree_knock.gd): broken branches,
		# a rock crack pitched up for the trunk, a heavy body fall on dirt.
		"snap":[load(FOLEY+"trees-6.wav")],"crack":_takes(FOLEY+"mesa-break-%d.wav",2),
		"thud":[load(FOLEY+"pat-4.wav"),load(FOLEY+"pat-6.wav")],
		# The rival race's beats (scripts/endless/rival_race.gd).
		"race-count":[load(KIT+"race-count.wav")],"race-go":[load(KIT+"race-go.wav")],
		"race-win":[load(KIT+"race-win.wav")],"race-lose":[load(KIT+"race-lose.wav")],
		# The line's multiplier stepping up: a switch's light bell, a flourish's full one.
		"line-switch":[load(BURROWER+"bell-417300.mp3")],"line-flourish":[load(BURROWER+"bell-531031.mp3")],
		# The bore (tools/generate_bore_audio.py): a spur's three layers, the tell's grind.
		"bore-thump":_takes(BORE_AUDIO+"bore-thump-%d.wav",4),"bore-crack":_takes(BORE_AUDIO+"bore-crack-%d.wav",4),
		"bore-debris":_takes(BORE_AUDIO+"bore-debris-%d.wav",4),"bore-grind":_takes(BORE_AUDIO+"bore-grind-%d.wav",3),
	}

static func _takes(pattern: String, count: int) -> Array:
	var out := []
	for i in range(count): out.append(load(pattern % (i+1)))
	return out

## A looping copy of a WAV (they import unlooped), started at a random point
## when heard, on `bus`; no player when this run is silent.
func _bed(path: String, bus: StringName, world := false) -> Bed:
	var bed := Bed.new()
	_beds.append(bed)
	if not audible: return bed
	var stream := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	var player: Node
	if world:
		var p3 := AudioStreamPlayer3D.new()
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		p3.panning_strength = 1.0
		player = p3
	else: player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = -80.0
	add_child(player)
	bed.player = player
	return bed

## A looping voice in the world: the caller moves its `player` (null headless) and sets
## its goals, and gain carries no fall-off with distance.
func bed_in_world(path: String, bus := SFX) -> Bed:
	return _bed(path,bus,true)

## The quit leak ("ObjectDB instances leaked at exit"): a playback still in
## the AudioServer's list when the engine tears down is reported leaked. A
## window close stops every voice, lets three frames pass, then quits.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and audible and not _off: _quit()

func _quit() -> void:
	_off = true
	var tree := get_tree()
	for node: Node in tree.root.find_children("*","",true,false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.set_process(false)
			node.call("stop")
	process_mode = Node.PROCESS_MODE_DISABLED
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	tree.quit()

func _enter_tree() -> void:
	if wanted(): get_tree().auto_accept_quit = false

func _exit_tree() -> void:
	if audible: get_tree().auto_accept_quit = true

# --- One-shots ----------------------------------------------------------------

## One take of `kind` (never the one before), `gain` linear, `pitch` the
## centre of a little spread; in the world at `at` (flat: not falling off
## with distance), else on the listener.
## `reach` (m): where a world voice falls off to nothing (and `unit`: full
## within it), 0 the default (70, 4).
func shot(kind: String, gain: float, pitch := 1.0, at := Vector3.INF, bus := SFX, flat := false, reach := 0.0, unit := 0.0) -> void:
	if gain <= 0.0: return
	played[kind] = int(played.get(kind,0))+1
	last_shot = {"kind":kind,"gain":gain,"pitch":pitch,"at":at}
	var takes: Array = _clips.get(kind,[])
	if not audible or takes.is_empty(): return
	var pick := _rng.randi_range(0,takes.size()-1)
	if takes.size() > 1 and pick == int(_last.get(kind,-1)): pick = (pick+1)%takes.size()
	_last[kind] = pick
	var player
	if at == Vector3.INF:
		player = _free(_pool2,_next2)
		_next2 = (_next2+1)%_pool2.size()
	else:
		var p3 := _free(_pool3,_next3) as AudioStreamPlayer3D
		_next3 = (_next3+1)%_pool3.size()
		p3.global_position = at
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED if flat else AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.unit_size = unit if unit > 0.0 else 4.0
		p3.max_distance = reach if reach > 0.0 else 70.0
		p3.panning_strength = 0.8
		player = p3
	player.stream = takes[pick]
	player.bus = bus
	player.volume_db = linear_to_db(gain)+_rng.randf_range(-1.5,1.5)
	player.pitch_scale = pitch*_rng.randf_range(0.94,1.06)
	player.play()

## A spur bursting out of the rock at `at` (world): a thump, a crack and a debris
## tail, each its own take and pitch round `pitch` (a big spur lower), `gain`
## on top of the BURST_ gains; heard BORE_REACH m off, through the bore's room.
func bore_burst(at: Vector3, gain := 1.0, pitch := 1.0) -> void:
	_heard("burst",at)
	shot("bore-thump",BURST_THUMP*gain,pitch*_rng.randf_range(0.92,1.08),at,BORE,false,BORE_REACH,BORE_UNIT)
	shot("bore-crack",BURST_CRACK*gain,pitch*_rng.randf_range(0.88,1.12),at,BORE,false,BORE_REACH,BORE_UNIT)
	shot("bore-debris",BURST_DEBRIS*gain,pitch*_rng.randf_range(0.9,1.1),at,BORE,false,BORE_REACH,BORE_UNIT)

## The tell at `at`: the rock grinding as the crack opens, `gain` on top of TELL.
func bore_tell(at: Vector3, gain := 1.0, pitch := 1.0) -> void:
	_heard("tell",at)
	shot("bore-grind",TELL*gain,pitch,at,BORE,false,TELL_REACH,BORE_UNIT)

func _heard(kind: String, at: Vector3) -> void:
	bore_heard.append({"kind":kind,"at":at,"msec":Time.get_ticks_msec()})
	if bore_heard.size() > 64: bore_heard.pop_front()

## A player not playing, else the next in turn.
func _free(pool: Array, next: int) -> Node:
	for p: Node in pool:
		if not p.playing: return p
	return pool[next]

# --- Every frame --------------------------------------------------------------------

## One frame. `game` is the endless flight study (`plane`, `hand_landing`,
## `ground_scale`, `field`), `events` what `hand_landing.step` returned this
## frame, `boost` the Boost held (0 to 1).
func step(delta: float, game: Node3D, events: Dictionary, boost: float) -> void:
	if delta <= 0.0 or game.plane == null or _off or rush == null: return
	var plane = game.plane
	var landing = game.hand_landing
	var on_wheels: bool = landing.on_ground()
	var velocity: Vector3 = plane.velocity
	var speed: float = landing.roll_speed() if on_wheels else velocity.length()
	var paced: Variant = plane.get("pace_scale")
	var cruise: float = maxf(float(plane.cruise())/(maxf(float(paced),0.1) if paced != null else 1.0),1.0)
	fast = clampf((speed/cruise-AIR_SPEED.x)/(AIR_SPEED.y-AIR_SPEED.x),0.0,1.0)
	over = clampf((speed/cruise-AIR_SPEED.y)/AIR_OVER,0.0,1.0)
	_flight(delta,velocity,speed,on_wheels)
	if on_wheels:
		_settle_probe(delta)
	else:
		_probe_step(delta,game,speed)
	_bore(delta,game)
	_air(boost,not on_wheels)
	_engine(plane,landing,boost,speed,cruise,on_wheels)
	_wheels(landing,speed,on_wheels)
	_landing(events)
	var look = game.get("look")
	var here: Vector2 = look.wind_here() if look != null and look.has_method("wind_here") else Vector2(-1.0,0.0)
	wind = here.x
	wind_reach = here.y
	_place_wait -= delta
	if _place_wait <= 0.0:
		_place_wait = PLACE_TICK
		_read_place(game)
	_ambience(on_wheels)
	for bed in _beds: bed.step(delta)
	if ambient != null: ambient.step(delta,game,self)

## The pull and the dive: the flight path's turn rate and its sink.
func _flight(delta: float, velocity: Vector3, speed: float, on_wheels: bool) -> void:
	var way := velocity.normalized() if speed > 1.0 else Vector3.ZERO
	var turn := 0.0
	if _last_way != Vector3.ZERO and way != Vector3.ZERO: turn = _last_way.angle_to(way)/delta
	_last_way = way
	var want := 0.0
	var sink := 0.0
	if not on_wheels and way != Vector3.ZERO:
		want = smoothstep(PULL_TURN.x,PULL_TURN.y,turn)*(0.5+0.5*fast)
		sink = smoothstep(DIVE_SINK.x,DIVE_SINK.y,-way.y)
	pull = lerpf(pull,want,1.0-exp(-delta/0.15))
	dive = lerpf(dive,sink,1.0-exp(-delta/0.3))

## The rush, whistle and howl, and the air's brightness.
func _air(boost: float, flying: bool) -> void:
	rush.goal = lerpf(RUSH.x,RUSH.y,pow(fast,1.6))*(1.0 if fast > 0.0 or flying else 0.0)+RUSH_NEAR*near+RUSH_DIVE*dive+RUSH_PULL*pull+RUSH_BOOST*boost*fast
	rush.pitch_goal = 0.85+0.3*fast+0.08*near+0.06*dive+OVER_PITCH*over
	if _air_lpf != null: _air_lpf.cutoff_hz = clampf((RUSH_CUT.x+(RUSH_CUT.y-RUSH_CUT.x)*pow(fast,1.3)+RUSH_CUT_NEAR*near+RUSH_CUT_DIVE*dive+OVER_CUT*over)*lerpf(1.0,MUFFLE_CUT,clampf(muffle,0.0,1.0))*lerpf(1.0,BORE_AIR_CUT,_bore_k()),200.0,18000.0)
	whistle.goal = WHISTLE*smoothstep(0.4,1.0,fast)+WHISTLE_NEAR*near*fast+WHISTLE_PULL*pull*fast+WHISTLE_DIVE*dive*(0.4+0.6*fast)+WHISTLE_OVER*over
	whistle.pitch_goal = 0.9+0.25*fast+0.08*dive+OVER_PITCH*over
	howl.goal = HOWL*enclosed+0.04*near
	howl.pitch_goal = 0.8+0.4*fast

## In a bore (the study's `plane_figure.bore`: the tube's open middle), or
## closed in under rock (NearMiss `overhead`, last frame's, and `enclosed`):
## `bore_wet` eased toward 1 over BORE_IN s, else toward 0 over BORE_OUT s, at a
## steady rate; the room's wet, dry and EQ follow it on an S-curve, and the two
## effects sit off while it's 0.
func _bore(delta: float, game: Node3D) -> void:
	var figure: Variant = game.get("plane_figure")
	var near_miss: Variant = game.get("near")
	in_bore = (figure != null and bool(figure.get("bore"))) or (near_miss != null and bool(near_miss.get("overhead")) and enclosed > BORE_SIDES)
	var was := bore_wet
	bore_wet = move_toward(bore_wet,1.0 if in_bore else 0.0,delta/(BORE_IN if in_bore else BORE_OUT))
	if _reverb == null or (was == bore_wet and bore_wet == 0.0): return
	var k := _bore_k()
	var bus := AudioServer.get_bus_index(BORE)
	for i in range(2): AudioServer.set_bus_effect_enabled(bus,i,bore_wet > 0.0)
	_reverb.wet = BORE_WET*k
	_reverb.dry = lerpf(1.0,BORE_DRY,k)
	for i in range(6): _eq.set_band_gain_db(i,float(BORE_EQ[i])*k)

func _bore_k() -> float:
	return smoothstep(0.0,1.0,bore_wet)

## The engine: the throttle and the speed; wires on the knife edge, a drift
## and a hard pull.
func _engine(plane, landing, boost: float, speed: float, cruise: float, on_wheels: bool) -> void:
	var running := clampf(float(plane.engine),0.0,1.0)
	var throttle := float(landing.throttle) if on_wheels else float(plane.throttle)
	if throttle >= 0.0: throttle = maxf(throttle,boost)
	# Switched on while on the wheels it coughs awake; the first frame only
	# learns whether it was already running.
	if _engine_was >= 0.0 and running > 0.02 and _engine_was <= 0.02 and on_wheels: shot("start",ENGINE_START)
	_engine_was = running
	engine.goal = running*(ENGINE+ENGINE_THROTTLE*maxf(throttle,0.0)-ENGINE_BRAKE*maxf(-throttle,0.0)+ENGINE_FAST*fast)
	engine.pitch_goal = clampf(ENGINE_PITCH+ENGINE_PER_CRUISE*speed/cruise+ENGINE_PITCH_THROTTLE*throttle,0.6,1.7)*lerpf(ENGINE_SPUN_DOWN,1.0,running)
	var strain := 0.0
	if not on_wheels: strain = maxf(maxf(absf(float(plane.knife)),clampf(float(plane.drift),0.0,1.0)),pull)
	wires.goal = WIRES*strain*(0.4+0.6*fast)
	wires.pitch_goal = 0.95+0.15*fast+0.05*clampf(float(plane.drift),0.0,1.0)

## On the wheels: the rumble by the roll's pace, the skid by the grit.
func _wheels(landing, speed: float, on_wheels: bool) -> void:
	rumble.goal = RUMBLE*smoothstep(0.3,RUMBLE_FULL,speed) if on_wheels else 0.0
	rumble.pitch_goal = 0.8+0.025*minf(speed,16.0)
	var grit := clampf(float(landing.grit),0.0,1.0)
	if bool(landing.sliding) and speed > 2.0: grit = maxf(grit,SKID_SLIDING)
	skid.goal = SKID*grit if on_wheels else 0.0
	skid.pitch_goal = 0.9+0.015*minf(speed,16.0)

## The landing's events (the dict `hand_landing.step` returned): a hit, a
## hop, a touch that sticks (a greaser's tap, a thump by its `k`), a slide
## breaking loose. One thump a frame.
func _landing(events: Dictionary) -> void:
	if events.is_empty(): return
	if events.has("hit"):
		shot("thump",HIT,0.8)
		shot("creak",0.1,0.8)
	elif events.has("bounce"):
		var hop: Dictionary = events.bounce
		var k := clampf(float(hop.get("sink",0.0))/HOP_SINK,0.0,1.0)
		shot("thump",lerpf(HOP.x,HOP.y,k),lerpf(THUMP_PITCH.x,THUMP_PITCH.y,k))
		if k > 0.4: shot("creak",0.05+0.08*k,0.9)
	elif events.has("greaser"):
		shot("thump",TAP,TAP_PITCH)
	elif events.has("settled"):
		var k := clampf(float((events.settled as Dictionary).get("k",0.0)),0.0,1.0)
		shot("thump",lerpf(THUMP.x,THUMP.y,k),lerpf(THUMP_PITCH.x,THUMP_PITCH.y,k))
		if k > 0.45: shot("creak",0.06+0.08*k,0.9)
	if events.has("slide"): shot("creak",0.05,1.1)
	_near(events)

## The near misses' events: a scored moment's swish and whoosh, a scrape's
## grind and what it hit, a crash.
func _near(events: Dictionary) -> void:
	var m: Variant = events.get("near")
	if m is Dictionary:
		var k := clampf(float((m as Dictionary).get("k",0.0)),0.0,1.0)
		shot("swish",lerpf(NEAR.x,NEAR.y,k),lerpf(NEAR_PITCH.x,NEAR_PITCH.y,k),Vector3.INF,AIR)
		shot("whoosh",lerpf(NEAR.x,NEAR.y,k)*0.8,lerpf(NEAR_PITCH.x,NEAR_PITCH.y,k)+0.1,Vector3.INF,AIR)
		if float((m as Dictionary).get("line_step",0.0)) > 0.0:
			if bool((m as Dictionary).get("flourish",false)): shot("line-flourish",LINE_FLOURISH,1.0)
			else: shot("line-switch",LINE_SWITCH,1.3)
		_whoosh_wait = WHOOSH_GAP
		if str((m as Dictionary).get("surface","")) == "tree": shot("leaves",SCRAPE*0.5,1.1)
	var k: Variant = events.get("knock")
	if k is Dictionary:
		# Through a tree: the trunk's crack, branches and a burst of needles.
		var heft := clampf(float((k as Dictionary).get("heft",0.0)),0.0,1.0)
		shot("crack",KNOCK*lerpf(0.5,1.0,heft),1.7)
		shot("snap",KNOCK,lerpf(1.1,0.9,heft))
		shot("leaves",KNOCK*1.2,0.95)
	for key: String in ["scrape","crash"]:
		var h: Variant = events.get(key)
		if not h is Dictionary: continue
		var hard := key == "crash"
		var what := str((h as Dictionary).get("what","land"))
		if hard:
			shot("crash",CRASH,0.85)
			shot("debris",CRASH*0.6,0.9)
		else: shot("grind",SCRAPE,1.0)
		match what:
			"tree": shot("leaves",SCRAPE*(1.4 if hard else 1.0),1.0)
			"water": shot("splash",SCRAPE*(1.6 if hard else 1.0),0.9)
			"stone": shot("debris",SCRAPE*0.7,1.1)

# --- The probes ---------------------------------------------------------------------

## The ring of rays round the plane's path: how close stone is, how many
## sides it closes in from, which side is nearer; a whoosh as it comes close.
func _probe_step(delta: float, game: Node3D, speed: float) -> void:
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
		_ray.collision_mask = PROBE_MASK
	var plane = game.plane
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var ahead: Vector3 = plane.forward()
	var right := ahead.cross(Vector3.UP)
	if right.length_squared() < 0.0001: right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(ahead).normalized()
	var from: Vector3 = (plane.position as Vector3)+(plane.velocity as Vector3)*0.1
	var span := WorldScale.TOY_SPAN*float(game.ground_scale.size())
	var reach := maxf(PROBE_SPANS*span,PROBE_LEAD*speed)
	for n in range(PROBE_RAYS):
		var i := _probe_next
		_probe_next = (i+1)%PROBE_DIRS.size()
		var d: Vector2 = PROBE_DIRS[i]
		_ray.from = from
		_ray.to = from+(right*d.x+up*d.y)*reach
		var hit: Dictionary = space.intersect_ray(_ray)
		var close := 0.0 if hit.is_empty() else 1.0-from.distance_to(hit.position)/reach
		# The ray straight down counts for less: skimming the land is a
		# gentler pass than a cliff.
		_probe[i] = close*(PROBE_DOWN if i == 3 else 1.0)
	var most := 0.0
	var count := 0
	var lean := 0.0
	for i in range(_probe.size()):
		most = maxf(most,_probe[i])
		if _probe[i] > 0.15: count += 1
		lean += _probe[i]*(PROBE_DIRS[i] as Vector2).x
	var quick := smoothstep(6.0,20.0,speed)
	var want := most*quick
	var was := near
	near = lerpf(near,want,1.0-exp(-delta/(0.1 if want > near else 0.6)))
	var closed := clampf((count-1)/3.0,0.0,1.0)*quick
	enclosed = lerpf(enclosed,closed,1.0-exp(-delta/(0.12 if closed > enclosed else 0.5)))
	side = lerpf(side,clampf(lean,-1.0,1.0),1.0-exp(-delta/0.2))
	_whoosh_wait -= delta
	if was < WHOOSH_AT and near >= WHOOSH_AT and _whoosh_wait <= 0.0 and speed > WHOOSH_SPEED:
		_whoosh_wait = WHOOSH_GAP
		shot("whoosh",WHOOSH_GAIN*(0.6+0.4*fast),0.9+0.2*fast,from+right*side*5.0,AIR,true)

func _settle_probe(delta: float) -> void:
	var k := 1.0-exp(-delta/0.5)
	near = lerpf(near,0.0,k)
	enclosed = lerpf(enclosed,0.0,k)

# --- The place ------------------------------------------------------------------------

## The height over the ground and the sea, and the share of water in rings of
## land samples round the plane (the field's height at or under the sea is water).
func _read_place(game: Node3D) -> void:
	var field = game.field
	if field == null: return
	var p: Vector3 = game.plane.position
	var ground: float = maxf(float(field.height(p.x,p.z)),Field.SEA_Y)
	agl = p.y-ground
	alt = p.y-Field.SEA_Y
	var wet := 0
	var count := 0
	for ring: Vector2 in PLACE_RINGS:
		for i in range(int(ring.y)):
			var q := Vector2(p.x,p.z)
			if ring.x > 0.0: q += Vector2.from_angle(TAU*i/ring.y)*ring.x
			count += 1
			if float(field.height(q.x,q.y)) < Field.SEA_Y+0.2: wet += 1
	water = float(wet)/maxf(count,1)

func _ambience(on_wheels: bool) -> void:
	var up := smoothstep(BREEZE_HEIGHT.x,BREEZE_HEIGHT.y,agl)
	breeze.goal = lerpf(BREEZE.x,BREEZE.y,up)
	breeze.pitch_goal = 0.9+0.2*up
	if wind >= 0.0:
		# The wind by place and hour: a still hollow hushes the bed, a windy
		# ridge swells it.
		var share := lerpf(WIND_SHARE.x,WIND_SHARE.y,smoothstep(WIND_AT.x,WIND_AT.y,wind))
		var swell := smoothstep(SWELL_AT.x,SWELL_AT.y,wind)
		breeze.goal = lerpf(breeze.goal,breeze.goal*share+WIND_SWELL*swell,wind_reach)
		breeze.pitch_goal += WIND_PITCH*swell*wind_reach
	thin.goal = THIN*smoothstep(THIN_HEIGHT.x,THIN_HEIGHT.y,alt)
	thin.pitch_goal = 0.9+0.15*smoothstep(THIN_HEIGHT.x,THIN_HEIGHT.y,alt)
	# A coast (water on some sides, land on others) is a shore; open sea a
	# lesser surf; both fade with height over the water.
	var coast := 4.0*water*(1.0-water)
	var low := 1.0-smoothstep(SHORE_HEIGHT.x,SHORE_HEIGHT.y,alt)
	shore.goal = SHORE*low*maxf(coast,SURF*water)
	shore.pitch_goal = 0.95+0.1*(1.0-low)

## The rain bed (weather lane rain): `amount` the rain at the eye (0 to 1,
## Weather.rain_here), `air` the speed as a share of cruise. Louder and a
## touch brighter at speed, the drops drumming on the plane. Made on the
## first call with rain.
const RAIN := 0.25
const RAIN_FAST := 0.45
func rain_to(amount: float, air: float) -> void:
	if rain == null:
		if amount <= 0.0: return
		rain = _bed(OLD+"rain-bed.wav",AMBIENCE)
		rain.attack = 1.2
		rain.release = 0.8
	rain.goal = RAIN*amount*(1.0+RAIN_FAST*clampf(air,0.0,1.5))
	rain.pitch_goal = 0.95+0.12*clampf(air,0.0,1.5)

## Every layer's goal, gain and pitch now: {name: [goal, gain, pitch]} (for a
## driver or a debug line).
func layers() -> Dictionary:
	var out := {}
	for pair in [["rush",rush],["whistle",whistle],["howl",howl],["engine",engine],["wires",wires],["rumble",rumble],["skid",skid],["breeze",breeze],["thin",thin],["shore",shore]]:
		var bed: Bed = pair[1]
		out[pair[0]] = [bed.goal,bed.gain,bed.pitch]
	return out
