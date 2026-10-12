extends Node
## The kit isle's sound (docs/design/sound-round1.md): the air, the plane,
## the body and the place, made to follow what the isle does every frame.
## The isle (studies/kit_isle.gd) makes one and hands itself over (`isle`);
## its glue is a few calls: `thump` (the wheels' touch), `body` (the
## pilot's motor events), `surface` (what the feet are on).
##
## Everything here reads the isle; nothing steers it. The continuous voices
## are seamless loops baked by tools/generate_kit_audio.py (assets/audio/
## kit/) and the old game's beds (assets/audio/), each a `Bed`: its gain and
## pitch eased toward a goal set each frame, paused when silent. The air's
## brightness is a live low-pass on its own bus; the cloud sea's hush is a
## low-pass over all of it.
##
## - The air (the main voice): a rush whose loudness, pitch and brightness
##   follow the airspeed (the plane's, or the pilot's own falling); a
##   whistle over it when fast; a hollow howl when stone closes round the
##   plane (an arch, a gap: a ring of ray probes, `_probe`); a whoosh past
##   rock as it comes close (panned to its side); on foot a breeze bed; the
##   sail and a fall flutter.
## - The plane: the engine loop (pitch and gain on throttle, speed and the
##   engine's spin), coughing awake as it starts; the wires singing and the
##   frame creaking on the knife edge, a drift, a roll; the flaps' creak;
##   touchdown thumps, the wheels' rumble and the skid's hiss; boarding and
##   getting out (cloth, a creak, the seat); parked, the engine ticks as it
##   cools.
## - The body: the steps are scripts/wanderer_steps.gd's, by the surface
##   found here (stone, grass, worn earth, a bridge's planks, water); over them jumps
##   rustle, wall kicks and twirls swish, grabs slap the stone, the sail
##   pops and folds, slides and carves scrape, heavy landings thud, the
##   downdraft whumps, the bridges' planks creak.
## - The place: leaves where the turf is green, an owl at night, water
##   near the isle's pools and channel, rain, a thin high wind in open sky
##   away from the isle, the cloud sea's hush below; the swing ropes' creak,
##   swish and whip. The living layer (birds by the time of day, bees,
##   crickets, frogs, waterfalls) is kit_audio_life.gd's; the sky dragon
##   and the rune serpent are kit_audio_beasts.gd's (round 3).
##
## Buses (`ensure_buses`): Master > SFX (the Effects volume) > SFX Air;
## Master > Ambience (the Ambience volume) > Ambience Far; Master > Music
## (empty, for later). The old Genesis bus (steps, tokens, life's one-shots)
## sits beside SFX on the same Effects volume.

const Audio = preload("res://scripts/genesis_audio.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const KitAudioLife = preload("res://scripts/kit_isle/kit_audio_life.gd")
const KitAudioBeasts = preload("res://scripts/kit_isle/kit_audio_beasts.gd")

const SFX := &"SFX"
const AIR := &"SFX Air"
const AMBIENCE := &"Ambience"
const FAR := &"Ambience Far"
const MUSIC := &"Music"
const DEFAULT_AMBIENCE := 0.8
## The downdraft's touch: the low thump's gain and the wind's, at full.
const DOWNDRAFT_WHUMP := 0.75
const DOWNDRAFT_WIND := 0.3
const KIT := "res://assets/audio/kit/"
const OLD := "res://assets/audio/"

# --- Tuning ----------------------------------------------------------------------

## Air speeds (m/s) where the rush starts and is full: the plane's, and the
## pilot's own (a fall; a jump stays under it).
const PLANE_AIR := Vector2(5.0,30.0)
const BODY_AIR := Vector2(7.0,18.0)
## The rush's gain at the quiet end and the full end, and what rock close
## by adds; its low-pass (Hz) closed and open, and what rock close adds.
const RUSH := Vector2(0.025,0.3)
const RUSH_NEAR := 0.16
const RUSH_CUT := Vector2(450.0,5200.0)
const RUSH_CUT_NEAR := 3000.0
const WHISTLE := 0.07
const WHISTLE_NEAR := 0.06
const HOWL := 0.17
## The whoosh past rock: `near` rising through this starts one, at this
## gain, no sooner than WHOOSH_GAP s after the last.
const WHOOSH_AT := 0.42
const WHOOSH_GAIN := 0.22
const WHOOSH_GAP := 0.7
## The ray ring round the plane: its reach (m) and rays a frame.
const PROBE_REACH := 9.0
const PROBE_RAYS := 3
const PROBE_DIRS := [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(0.7,0.7),Vector2(-0.7,0.7),Vector2(0.7,-0.7),Vector2(-0.7,-0.7)]
## The engine: its gain at a cruise, what full throttle adds, its pitch at
## rest and per m/s, what the throttle adds to it, and its pitch spun down.
const ENGINE := 0.085
const ENGINE_THROTTLE := 0.05
const ENGINE_PITCH := 0.78
const ENGINE_PER := 0.016
const ENGINE_PITCH_THROTTLE := 0.16
const ENGINE_SPUN_DOWN := 0.45
const ENGINE_START := 0.16
## Strain: the wires' gain at a full knife edge, and the seconds between
## creaks at a full lean (more apart when less).
const WIRES := 0.07
const CREAK_GAP := Vector2(0.9,2.2)
## Wheels on the turf: the rumble's and skid's gain at full.
const RUMBLE := 0.2
const SKID := 0.16
## Parked: seconds the engine ticks as it cools, the ticks' gain.
const COOL := 50.0
const TICK := 0.09
## The sail's and a fall's flutter.
const FLUTTER := Vector2(0.05,0.16)
## The breeze on foot (and its share flying), the high thin wind, the
## cloud sea's hush, the leaves, the crickets, the rain, the water.
const BREEZE := Vector2(0.03,0.07)
const BREEZE_FLYING := 0.3
const THIN := 0.07
const HUSH := 0.15
const LEAVES := 0.055
const RAIN := 0.12
const STREAM := 0.32
const POND := 0.16
## The cloud sea's top lies the plane's floor under the isle; its hush is
## full this far (m) over it and gone by HUSH_OVER; the low-pass over
## everything closes to MUFFLE_CUT (Hz) deep in.
const HUSH_OVER := 30.0
const MUFFLE_CUT := 1300.0
const OPEN_CUT := 18000.0
## Birdsong, crickets, frogs, bees and falls are kit_audio_life.gd's (its
## own tuning); the owl's gap is here.
const OWL_GAP := Vector2(25.0,55.0)
const SONGS := ["bluebird.mp3","chickadee.mp3","hermit-thrush.mp3","kinglet.mp3","robin.mp3","jay-1.mp3","jay-2.mp3","nutcracker.mp3"]
## The swing rope: its creak's gain and gap (s) at a full swing and at
## rest, the swish past the plumb, the whip let go.
const ROPE_CREAK := Vector2(0.03,0.09)
const ROPE_CREAK_GAP := Vector2(0.45,1.8)
const ROPE_SWISH := Vector2(0.04,0.12)
const ROPE_WHIP := 0.12
## Seconds between place reads (green round the listener, the water).
const PLACE_TICK := 0.4

## A looping voice: its gain and pitch eased toward their goals (per second
## rates up and down), stopped while silent and started again at a random
## point of its loop when heard: a silent bed holds no playback in the
## AudioServer (paused ones did, and some were caught mid-teardown at quit:
## the "ObjectDB instances leaked" warning).
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
		var silent := gain <= 0.0
		if silent:
			if player.playing: player.stop()
			return
		if not player.playing: player.play(randf()*player.stream.get_length())
		player.volume_db = linear_to_db(gain)
		player.pitch_scale = clampf(pitch,0.1,4.0)

## The isle (studies/kit_isle.gd or one extending it), read each frame.
var isle
var _rng := RandomNumberGenerator.new()
var _beds: Array[Bed] = []
var _clips := {}
var _last := {}
var _pool2: Array[AudioStreamPlayer] = []
var _pool3: Array[AudioStreamPlayer3D] = []
var _next2 := 0
var _next3 := 0

# Voices.
var rush: Bed
var whistle: Bed
var howl: Bed
var flutter: Bed
var engine: Bed
var wires: Bed
var rumble: Bed
var skid: Bed
var scrape: Bed
var swish_loop: Bed
var breeze: Bed
var thin: Bed
var hush: Bed
var leaves: Bed
var rain: Bed
var stream: Bed
var pond: Bed

# State read each frame (public for probes).
## How close stone is round the plane (0 open air, 1 skimming it), how
## closed in it is (0 open, 1 threading a gap), the nearer side (-1 left).
var near := 0.0
var enclosed := 0.0
var side := 0.0
## The cloud sea's muffle now (0 open air, 1 deep in cloud).
var muffle := 0.0
## How green the turf round the listener is (0 to 1) and how close the isle is.
var green := 0.0
var isle_near := 0.0
## One-shots played, by kind (probes).
var played := {}
## The nearest wide pool (its Rect2 and top), for the frogs; zero if none.
var pond_rect := Rect2()
var pond_top := 0.0
## The living layer (birds, bees, crickets, frogs, falls).
var life: KitAudioLife
## The beasts (the sky dragon, the rune serpent): round 3's.
var beasts: KitAudioBeasts

var _probe := PackedFloat32Array()
var _probe_next := 0
var _ray: PhysicsRayQueryParameters3D
var _whoosh_wait := 0.0
var _creak_wait := 0.0
var _flying_was := false
var _engine_was := 0.0
var _rolling_was := false
var _flaps_was := -1
var _cool_left := 0.0
var _tick_wait := 0.0
var _rope_creak := 0.0
var _rope_side := 0.0
var _owl_wait := 20.0
var _place_wait := 0.0
var _deck_wait := 0.0
var _surface := "stone"
var _surface_at := Vector3.INF
var _surface_age := 0.0
var _seat_left := -1.0
var _air_lpf: AudioEffectLowPassFilter
var _hush_lpf: Array[AudioEffectLowPassFilter] = []
## The isle's cloud floor under its top (kit_isle.gd FLOOR_BELOW).
var _floor_below := 50.0

# --- Buses and settings --------------------------------------------------------

## SFX and Ambience under Master (each with a low-pass at index 0 for the
## cloud sea's hush), SFX Air under SFX (its own low-pass, the air's
## brightness), Ambience Far under Ambience (low-passed, a wide reverb, for
## distant voices), Music under Master. The Genesis bus too
## (scripts/genesis_audio.gd).
static func ensure_buses() -> void:
	Audio.ensure_buses()
	_bus(SFX,&"Master",[_lpf(OPEN_CUT)])
	_bus(AIR,SFX,[_lpf(2000.0)])
	_bus(AMBIENCE,&"Master",[_lpf(OPEN_CUT)])
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.85
	reverb.damping = 0.6
	reverb.predelay_msec = 50.0
	reverb.spread = 1.0
	reverb.dry = 0.7
	reverb.wet = 0.35
	reverb.hipass = 0.3
	_bus(FAR,AMBIENCE,[_lpf(3200.0),reverb])
	_bus(MUSIC,&"Master",[])
	# A ceiling on everything, so no pile-up can overload the output.
	for i in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0,i) is AudioEffectHardLimiter: return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0,limiter)

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

## The sound settings on the kit's buses: the Effects volume (`sound`, the
## Genesis bus's too) on SFX, `ambience` on Ambience. Master and mute are
## genesis_audio's (`Audio.apply_settings`).
static func apply_settings(settings: Dictionary) -> void:
	ensure_buses()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX),linear_to_db(maxf(0.0001,float(settings.get("sound",0.8)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(AMBIENCE),linear_to_db(maxf(0.0001,float(settings.get("ambience",DEFAULT_AMBIENCE)))))

## The kept settings, as scripts/kit_isle/game_settings.gd keeps them.
static func load_settings(path := Audio.SETTINGS_PATH) -> Dictionary:
	var settings := Audio.DEFAULTS.duplicate()
	settings["ambience"] = DEFAULT_AMBIENCE
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for key: String in ["master","sound","ambience"]:
			settings[key] = clampf(float(file.get_value("sound",key,settings[key])),0.0,1.0)
		settings.muted = bool(file.get_value("sound","muted",settings.muted))
	return settings

# --- Setup ------------------------------------------------------------------------

func _ready() -> void:
	name = "KitAudio"
	_rng.randomize()
	ensure_buses()
	Audio.apply_settings(load_settings())
	apply_settings(load_settings())
	_air_lpf = AudioServer.get_bus_effect(AudioServer.get_bus_index(AIR),0) as AudioEffectLowPassFilter
	for bus in [SFX,AMBIENCE]: _hush_lpf.append(AudioServer.get_bus_effect(AudioServer.get_bus_index(bus),0) as AudioEffectLowPassFilter)
	var consts: Dictionary = isle.get_script().get_script_constant_map() if isle != null else {}
	_floor_below = float(consts.get("FLOOR_BELOW",50.0))
	_probe.resize(PROBE_DIRS.size())
	rush = _bed(KIT+"air-rush-loop.wav",AIR)
	whistle = _bed(KIT+"air-whistle-loop.wav",AIR)
	howl = _bed(KIT+"air-howl-loop.wav",AIR)
	flutter = _bed(KIT+"flutter-loop.wav",SFX)
	engine = _bed(KIT+"engine-loop.wav",SFX)
	engine.attack = 3.0
	engine.release = 1.2
	wires = _bed(KIT+"wire-sing-loop.wav",SFX)
	rumble = _bed(KIT+"wheel-rumble-loop.wav",SFX)
	skid = _bed(KIT+"skid-loop.wav",SFX)
	scrape = _bed(OLD+"foley/scrape-loop.wav",SFX)
	swish_loop = _bed(OLD+"genesis-meadow.wav",SFX)
	breeze = _bed(OLD+"wind-bed.wav",AMBIENCE)
	breeze.attack = 0.8
	breeze.release = 0.8
	thin = _bed(KIT+"thin-wind-loop.wav",AMBIENCE)
	hush = _bed(KIT+"cloud-hush-loop.wav",AMBIENCE)
	leaves = _bed(OLD+"leaf-rustle-bed.wav",AMBIENCE)
	rain = _bed(OLD+"rain-bed.wav",AMBIENCE)
	for bed in [thin,hush,leaves,rain]:
		bed.attack = 0.6
		bed.release = 0.5
	stream = _bed(OLD+"stream-bed.wav",AMBIENCE,true)
	pond = _bed(OLD+"water-bed.wav",AMBIENCE,true)
	for bed in [stream,pond]:
		bed.attack = 1.0
		bed.release = 1.0
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = SFX
		add_child(p)
		_pool2.append(p)
	for i in range(14):
		var p := AudioStreamPlayer3D.new()
		p.bus = SFX
		add_child(p)
		_pool3.append(p)
	_clips = {
		"thump":_takes(KIT+"thump-%d.wav",3),"creak":_takes(KIT+"creak-%d.wav",6),"tick":_takes(KIT+"tick-%d.wav",6),
		"swish":_takes(KIT+"swish-%d.wav",4),"whoosh":_takes(KIT+"whoosh-%d.wav",4),"pop":_takes(KIT+"sail-pop-%d.wav",3),
		"fold":_takes(KIT+"sail-fold-%d.wav",2),"grab":_takes(KIT+"grab-%d.wav",4),"start":[load(KIT+"engine-start.wav")],
		"cloth":_takes(OLD+"foley/ui-cloth-%d.wav",5),"pat":_takes(OLD+"foley/pat-%d.wav",6),
		"splash":_takes(OLD+"foley/water-splash-%d.wav",6),"plop":_takes(OLD+"foley/water-pop-%d.wav",6),
		"owl":[load(OLD+"owl.mp3")],
		"chirp":_takes(KIT+"chirp-%d.wav",8),"twitter":_takes(KIT+"twitter-%d.wav",6),"wings":_takes(KIT+"wings-%d.wav",4),
		"rope_creak":_takes(KIT+"rope-creak-%d.wav",4),"whip":_takes(KIT+"rope-whip-%d.wav",3),
		"wind_slam":_takes(KIT+"wind-slam-%d.wav",2),
	}
	life = KitAudioLife.new()
	life.audio = self
	life.isle = isle
	add_child(life)
	beasts = KitAudioBeasts.new()
	beasts.audio = self
	beasts.host = isle
	add_child(beasts)

## The quit leak ("ObjectDB instances leaked at exit"): a playback still in
## the AudioServer's list when the engine tears down is reported leaked; a
## stopped one leaves the list only on a later main-loop frame, so stopping
## it in _exit_tree (or waiting on the mix thread) is too late. `quit`
## stops every voice in the tree, lets two frames pass, then quits; the
## game's quits go through it (pause menu, title, window close).
static func quit(tree: SceneTree, code := 0) -> void:
	for node: Node in tree.root.find_children("*","",true,false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.set_process(false)
			node.call("stop")
	# Nothing restarts them meanwhile.
	for node: Node in tree.root.find_children("KitAudio","",true,false): node.process_mode = Node.PROCESS_MODE_DISABLED
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	tree.quit(code)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit(get_tree())

func _enter_tree() -> void:
	get_tree().auto_accept_quit = false

func _exit_tree() -> void:
	get_tree().auto_accept_quit = true

static func _takes(pattern: String, count: int) -> Array:
	var out := []
	for i in range(count): out.append(load(pattern % (i+1)))
	return out

## A looping copy of a WAV (they import unlooped), started at a random
## point when heard, on `bus`; placed in the world when `placed`.
func _bed(path: String, bus: StringName, placed := false) -> Bed:
	var stream := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	var player
	if placed:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 6.0
		p3.max_distance = 80.0
		p3.panning_strength = 0.7
		player = p3
	else:
		player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = -80.0
	add_child(player)
	var bed := Bed.new()
	bed.player = player
	_beds.append(bed)
	return bed

# --- One-shots ----------------------------------------------------------------

## One take of `kind` (never the one before), `gain` linear, `pitch` the
## centre of a little spread; in the world at `at` (falling off with
## distance unless `flat`), else on the listener.
func shot(kind: String, gain: float, pitch := 1.0, at := Vector3.INF, bus := SFX, flat := false) -> void:
	var takes: Array = _clips.get(kind,[])
	if takes.is_empty() or gain <= 0.0: return
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
		p3.unit_size = 4.0
		p3.max_distance = 70.0
		p3.panning_strength = 0.8
		player = p3
	player.stream = takes[pick]
	player.bus = bus
	player.volume_db = linear_to_db(gain)+_rng.randf_range(-1.5,1.5)
	player.pitch_scale = pitch*_rng.randf_range(0.94,1.06)
	player.play()
	played[kind] = int(played.get(kind,0))+1

## A player not playing, else the next in turn.
func _free(pool: Array, next: int) -> Node:
	for p: Node in pool:
		if not p.playing: return p
	return pool[next]

# --- The isle's hooks ---------------------------------------------------------------

## The wheels' touch, thump or knock (kit_isle.gd `_thump`), by `k` (0 to 1).
func thump(k: float) -> void:
	shot("thump",0.22+0.38*k,1.05-0.12*k)
	if k > 0.45: shot("creak",0.06+0.08*k,0.9)

## The pilot's motor events this frame (character_study.gd `_motor_events`).
func body(events: Dictionary) -> void:
	if isle == null: return
	var motor: PilotMotor = isle.motor
	if events.has("jumped"):
		shot("cloth",0.035,_rng.randf_range(1.0,1.2))
		if events.has("wall_jump"):
			shot("swish",0.07,1.1)
			shot("grab",0.06,0.9)
		elif events.has("side_flip") or events.has("long") or int(events.jumped) > 1:
			shot("swish",0.05,1.0)
		# Off a bridge's planks: they spring back.
		if _surface == "wood": shot("creak",0.05,1.25)
	if events.has("twirl"): shot("swish",0.1,_rng.randf_range(0.95,1.1))
	if events.has("sail"):
		if events.sail: shot("pop",0.16)
		else: shot("fold",0.09)
	if events.has("grabbed"):
		shot("grab",0.13)
		shot("cloth",0.04)
	if events.has("climbed"): shot("cloth",0.05,0.9)
	if events.has("let_go"): shot("cloth",0.03,1.1)
	if events.get("wall",false): shot("grab",0.07,1.05)
	if events.has("landed"):
		var hard := float(events.landed)
		if hard > 6.5: shot("pat",clampf((hard-6.5)/12.0,0.0,1.0)*0.12,1.1)
		if _surface == "wood": shot("creak",0.04+0.06*clampf(hard/10.0,0.0,1.0),1.15)
	# The downdraft (scripts/downdraft.gd): a breath of wind drawn in, a
	# rush down, and on the touch a deep whump, the thump pitched low under
	# a slam of wind.
	if events.has("downdraft_gather"): shot("whoosh",0.07,1.4)
	if events.has("downdraft_slam"): shot("swish",0.11,0.72)
	if events.has("downdraft"):
		var k := clampf(float(events.downdraft.strength),0.0,1.0)
		shot("thump",DOWNDRAFT_WHUMP*(0.6+0.4*k),0.5-0.08*k)
		shot("wind_slam",DOWNDRAFT_WIND*(0.5+0.5*k),0.8)
		if _surface == "wood": shot("creak",0.12,0.8)
	if events.has("swam"): shot("splash",0.08+0.1*clampf(float(events.swam)/8.0,0.0,1.0))
	if events.has("hopped"): shot("plop",0.06)
	# The swing rope: caught, the hands slap it and it takes his weight; let
	# go, its slack end whips.
	if events.has("swing"):
		var rope = motor.rider if events.swing else null
		var at: Vector3 = rope.anchor if rope != null and "anchor" in rope else motor.feet+Vector3.UP*2.0
		if events.swing:
			shot("grab",0.11,0.85)
			shot("rope_creak",0.09,0.9,at)
			_rope_creak = 0.6
		else:
			shot("whip",ROPE_WHIP,_rng.randf_range(0.92,1.08),motor.feet+Vector3.UP*1.5)
			shot("cloth",0.04,1.1)

## What the feet are on, for the steps and puffs (scripts/wanderer_steps.gd
## SURFACES): water wading or swimming, a bridge's planks, open grass (the
## isle's flora, scripts/kit_isle/kit_life.gd `grass_at`) or a worn path's
## earth on the turf, else stone (the ruins, the rock).
## Read again only once the feet have moved a little.
func surface(motor: PilotMotor) -> String:
	if motor.swimming or motor.wade >= 0.03: return "water"
	if _surface_at != Vector3.INF and motor.feet.distance_squared_to(_surface_at) < 0.09 and _surface_age < 0.5: return _surface
	_surface_at = motor.feet
	_surface_age = 0.0
	_surface = _read_surface(motor.feet)
	return _surface

func _read_surface(feet: Vector3) -> String:
	var p := Vector2(feet.x,feet.z)
	var ground: Variant = isle.get("ground")
	if ground != null and (ground as Object).has_method("deck_at"):
		var deck: float = ground.deck_at(p,feet.y+0.6)
		if deck > -INF and absf(deck-feet.y) < 0.35: return "wood"
	var life = isle.get("life")
	if life != null and life.is_set_up():
		var turf: Variant = life.ground_at(p)
		if turf != null and absf(float(turf)-feet.y) < 0.3 and not life.standing_at(p):
			return "grass" if life.grass_at(p) > 0.5 else "earth"
	return "stone"

# --- Every frame --------------------------------------------------------------------

func _process(delta: float) -> void:
	if isle == null or delta <= 0.0 or not is_instance_valid(isle): return
	var camera: Camera3D = isle.get("camera")
	if camera == null: return
	var listener := camera.global_position
	_surface_age += delta
	_hush(delta,listener)
	var flying := bool(isle.flying) and isle.plane != null
	if flying: _plane(delta)
	else: _plane_quiet()
	_board(flying)
	_parked(delta)
	_air(delta,flying)
	_body_loops(delta,flying)
	_rope(delta)
	_place_wait -= delta
	if _place_wait <= 0.0:
		_place_wait = PLACE_TICK
		_read_place(listener)
	_ambience(delta,listener,flying)
	for bed in _beds: bed.step(delta)

## The cloud sea's hush: deep under the isle's cloud floor, or in a cloud's
## body, everything closes down.
func _hush(delta: float, listener: Vector3) -> void:
	var floor_y: float = float(isle.isle_top())-_floor_below
	var over := listener.y-floor_y
	var sea := 1.0-smoothstep(0.0,HUSH_OVER,over)
	var want := sea*(0.55 if over > 0.0 else 1.0)
	var host = isle.cloud_host() if isle.has_method("cloud_host") else null
	if host != null and is_instance_valid(host) and host.has_method("cloud_body"):
		want = maxf(want,clampf(float(host.cloud_body(listener)),0.0,1.0))
	muffle = lerpf(muffle,want,1.0-exp(-delta*2.0))
	var cut := OPEN_CUT*pow(MUFFLE_CUT/OPEN_CUT,muffle)
	for f in _hush_lpf:
		if f != null: f.cutoff_hz = cut
	hush.goal = HUSH*smoothstep(0.05,0.6,muffle)

## The air past the plane, or the pilot's own falling.
func _air(delta: float, flying: bool) -> void:
	var speed := 0.0
	var fast := 0.0
	var knife := 0.0
	var motor: PilotMotor = isle.motor
	var sail := false
	if flying:
		var plane = isle.plane
		speed = (plane.velocity as Vector3).length()
		fast = clampf((speed-PLANE_AIR.x)/(PLANE_AIR.y-PLANE_AIR.x),0.0,1.0)
		knife = absf(float(plane.knife))
		if isle.hand_landing.flying(): _probe_step(delta,plane,speed)
		else: _settle_probe(delta)
	else:
		_settle_probe(delta)
		sail = motor.move == "sail"
		if not motor.grounded and not motor.on_ledge() and not motor.swimming:
			speed = motor.velocity.length()
			fast = clampf((speed-BODY_AIR.x)/(BODY_AIR.y-BODY_AIR.x),0.0,1.0)
	var open := 1.0-0.5*muffle
	rush.goal = (lerpf(RUSH.x,RUSH.y,pow(fast,1.6))*(1.0 if fast > 0.0 or flying else 0.0)+RUSH_NEAR*near)*open
	rush.pitch_goal = 0.85+0.3*fast+0.08*near
	if _air_lpf != null: _air_lpf.cutoff_hz = clampf(RUSH_CUT.x+(RUSH_CUT.y-RUSH_CUT.x)*pow(fast,1.3)+RUSH_CUT_NEAR*near,200.0,OPEN_CUT)
	whistle.goal = (WHISTLE*smoothstep(0.4,1.0,fast)+WHISTLE_NEAR*near*fast+0.04*knife*fast)*open
	whistle.pitch_goal = 0.9+0.25*fast
	howl.goal = (HOWL*enclosed+0.04*near)*open
	howl.pitch_goal = 0.8+0.4*fast
	# The sail flutters by its pace; a long fall flaps the coat.
	if sail: flutter.goal = lerpf(FLUTTER.x,FLUTTER.y,clampf(motor.velocity.length()/10.0,0.0,1.0))
	elif not flying: flutter.goal = FLUTTER.y*0.6*fast
	else: flutter.goal = 0.0
	flutter.pitch_goal = 0.9+0.25*clampf(motor.velocity.length()/14.0,0.0,1.0)

## The ring of rays round the plane's path: how close stone is, how many
## sides it closes in from, which side is nearer; a whoosh as it comes close.
func _probe_step(delta: float, plane, speed: float) -> void:
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
		_ray.collision_mask = int(isle.plane_mask()) if isle.has_method("plane_mask") else 1
	var space: PhysicsDirectSpaceState3D = isle.get_world_3d().direct_space_state
	var ahead: Vector3 = plane.forward()
	var right := ahead.cross(Vector3.UP)
	if right.length_squared() < 0.0001: right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(ahead).normalized()
	var from: Vector3 = (plane.position as Vector3)+(plane.velocity as Vector3)*0.1
	for n in range(PROBE_RAYS):
		var i := _probe_next
		_probe_next = (i+1)%PROBE_DIRS.size()
		var d: Vector2 = PROBE_DIRS[i]
		_ray.from = from
		_ray.to = from+(right*d.x+up*d.y)*PROBE_REACH
		var hit: Dictionary = space.intersect_ray(_ray)
		_probe[i] = 0.0 if hit.is_empty() else 1.0-from.distance_to(hit.position)/PROBE_REACH
	var most := 0.0
	var count := 0
	var lean := 0.0
	for i in range(_probe.size()):
		most = maxf(most,_probe[i])
		if _probe[i] > 0.15: count += 1
		lean += _probe[i]*(PROBE_DIRS[i] as Vector2).x
	var fast := smoothstep(6.0,20.0,speed)
	var want := most*fast
	var was := near
	near = lerpf(near,want,1.0-exp(-delta/(0.1 if want > near else 0.6)))
	var closed := clampf((count-1)/3.0,0.0,1.0)*fast
	enclosed = lerpf(enclosed,closed,1.0-exp(-delta/(0.12 if closed > enclosed else 0.5)))
	side = lerpf(side,clampf(lean,-1.0,1.0),1.0-exp(-delta/0.2))
	_whoosh_wait -= delta
	if was < WHOOSH_AT and near >= WHOOSH_AT and _whoosh_wait <= 0.0 and speed > 9.0:
		_whoosh_wait = WHOOSH_GAP
		var at: Vector3 = from+right*side*5.0
		shot("whoosh",WHOOSH_GAIN*(0.6+0.4*fast),0.9+0.2*fast,at,AIR,true)

func _settle_probe(delta: float) -> void:
	var k := 1.0-exp(-delta/0.5)
	near = lerpf(near,0.0,k)
	enclosed = lerpf(enclosed,0.0,k)

## The plane in hand: its engine, strain, flaps and wheels.
func _plane(delta: float) -> void:
	var plane = isle.plane
	var landing = isle.hand_landing
	var takeoff = isle.takeoff
	var running := clampf(float(plane.engine),0.0,1.0)
	var throttle := float(takeoff.throttle if takeoff != null else landing.throttle)
	var speed := (plane.velocity as Vector3).length()
	var fast := clampf((speed-PLANE_AIR.x)/(PLANE_AIR.y-PLANE_AIR.x),0.0,1.0)
	var on_wheels: bool = takeoff != null or landing.on_ground()
	# Started on the turf it coughs awake; boarded in the air it is running.
	if running > 0.02 and _engine_was <= 0.02 and on_wheels: shot("start",ENGINE_START)
	_engine_was = running
	engine.goal = running*(ENGINE+ENGINE_THROTTLE*maxf(throttle,0.0)-0.025*maxf(-throttle,0.0)+0.03*fast)*(1.0-0.3*muffle)
	engine.pitch_goal = clampf(ENGINE_PITCH+ENGINE_PER*speed+ENGINE_PITCH_THROTTLE*throttle,0.6,1.7)*lerpf(ENGINE_SPUN_DOWN,1.0,running)
	# Strain: the wires sing on the knife edge and in a drift; the frame
	# creaks now and then while it is held, and as a roll starts.
	var knife := absf(float(plane.knife))
	var drift := clampf(float(plane.drift),0.0,1.0)
	var strain := maxf(knife,drift)
	wires.goal = WIRES*strain*(0.4+0.6*fast)
	wires.pitch_goal = 0.95+0.15*fast+0.05*drift
	_creak_wait -= delta
	if strain > 0.5 and _creak_wait <= 0.0:
		_creak_wait = _rng.randf_range(CREAK_GAP.x,CREAK_GAP.y)/(0.5+strain)
		shot("creak",0.04+0.05*strain,_rng.randf_range(0.85,1.15))
	var rolling := bool(plane.rolling)
	if rolling and not _rolling_was:
		shot("creak",0.08,1.0)
		shot("swish",0.07,0.7)
	_rolling_was = rolling
	var flaps := int(plane.flaps)
	if _flaps_was >= 0 and flaps != _flaps_was:
		shot("creak",0.07,0.8)
		shot("swish",0.05,0.6)
	_flaps_was = flaps
	# On the wheels: the rumble by the roll's pace, the skid by the grit.
	rumble.goal = RUMBLE*smoothstep(0.3,12.0,speed) if on_wheels else 0.0
	rumble.pitch_goal = 0.8+0.025*minf(speed,16.0)
	skid.goal = SKID*clampf(float(landing.grit),0.0,1.0) if on_wheels and takeoff == null else 0.0
	skid.pitch_goal = 0.9+0.015*minf(speed,16.0)

func _plane_quiet() -> void:
	engine.goal = 0.0
	wires.goal = 0.0
	rumble.goal = 0.0
	skid.goal = 0.0
	_engine_was = 0.0
	_flaps_was = -1
	_rolling_was = false

## Climbing in and getting out: cloth, a creak, the seat taking him.
func _board(flying: bool) -> void:
	if flying != _flying_was:
		shot("cloth",0.06,0.95)
		shot("creak",0.06,_rng.randf_range(0.9,1.05))
		_seat_left = 0.35 if flying else 0.2
		if not flying and bool(isle.get("parked")): _cool_left = COOL
	_flying_was = flying

## Parked after a flight: the engine ticks as it cools, sparser as it goes.
func _parked(delta: float) -> void:
	if _seat_left >= 0.0:
		_seat_left -= get_process_delta_time()
		if _seat_left < 0.0: shot("thump",0.07,1.6)
	if _cool_left <= 0.0 or not bool(isle.get("parked")):
		_cool_left = 0.0
		return
	_cool_left -= delta
	_tick_wait -= delta
	if _tick_wait > 0.0: return
	var left := _cool_left/COOL
	_tick_wait = _rng.randf_range(0.4,2.0)*lerpf(3.0,1.0,left)
	var at: Vector3 = (isle.parked_at as Vector3)+Vector3.UP*1.2
	shot("tick",TICK*(0.4+0.6*left),1.0,at)

## On a swing rope: it creaks over its ring, more and quicker as the swing
## grows; each pass through the plumb swishes.
func _rope(delta: float) -> void:
	var motor: PilotMotor = isle.motor
	var rope = motor.rider if motor != null else null
	if rope == null or not ("anchor" in rope and "velocity" in rope and "hands" in rope):
		_rope_side = 0.0
		return
	var v: Vector3 = rope.velocity
	var anchor: Vector3 = rope.anchor
	var hands: Vector3 = rope.hands
	var k := clampf(v.length()/10.0,0.0,1.0)
	_rope_creak -= delta
	if _rope_creak <= 0.0 and v.length() > 0.8:
		_rope_creak = lerpf(ROPE_CREAK_GAP.y,ROPE_CREAK_GAP.x,k)*_rng.randf_range(0.8,1.25)
		shot("rope_creak",lerpf(ROPE_CREAK.x,ROPE_CREAK.y,k),_rng.randf_range(0.85,1.15),anchor)
	var out := Vector2(hands.x-anchor.x,hands.z-anchor.z).dot(Vector2(v.x,v.z))
	if _rope_side < 0.0 and out >= 0.0 and v.length() > 3.0:
		shot("swish",lerpf(ROPE_SWISH.x,ROPE_SWISH.y,k),lerpf(0.6,0.85,k))
		if k > 0.7: shot("whoosh",0.06*k,0.8,hands,AIR,true)
	_rope_side = out

## Sliding and carving scrape the ground; the bridge's planks creak.
func _body_loops(delta: float, flying: bool) -> void:
	var motor: PilotMotor = isle.motor
	var pace := Vector2(motor.velocity.x,motor.velocity.z).length()
	var scraping := not flying and motor.grounded and (motor.move == "slide" or (motor.carving > 0.2 and pace > 3.0))
	var walling := not flying and motor.move == "wall" and motor.velocity.y < -0.5
	var on_grass := _surface == "grass"
	var k := clampf(pace/12.0,0.0,1.0)
	scrape.goal = (0.03+0.08*k if scraping and not on_grass else 0.0)+(0.04 if walling else 0.0)
	scrape.pitch_goal = 0.85+0.3*k
	swish_loop.goal = 0.05+0.1*k if scraping and on_grass else 0.0
	swish_loop.pitch_goal = 0.9+0.3*k
	_deck_wait -= delta*pace
	if not flying and motor.grounded and _surface == "wood" and pace > 0.6 and _deck_wait <= 0.0:
		_deck_wait = _rng.randf_range(1.2,3.0)
		shot("creak",0.03+0.03*clampf(pace/PilotMotor.RUN,0.0,1.0),_rng.randf_range(1.1,1.35),motor.feet)

## How green the ground round the listener is (a ring of samples of the
## isle's grass), how near the isle is, and where its water is nearest.
func _read_place(listener: Vector3) -> void:
	var life = isle.get("life")
	var greens := 0.0
	if life != null and life.is_set_up():
		var origin := Vector2(listener.x,listener.z)
		var count := 0
		for ring in [0.0,8.0,18.0]:
			for i in range(1 if ring == 0.0 else 6):
				var p: Vector2 = origin+Vector2.from_angle(TAU*i/6.0+ring)*ring
				var g: Variant = life.ground_at(p)
				count += 1
				if g != null and absf(float(g)-listener.y) < 40.0: greens += life.grass_at(p)
		greens /= maxf(count,1)
	green = lerpf(green,clampf(greens*1.6,0.0,1.0),0.5)
	var circle: Vector3 = isle.isle_circle() if isle.has_method("isle_circle") else Vector3(0,0,60)
	var off := Vector2(listener.x-circle.x,listener.z-circle.y).length()-circle.z
	var high := listener.y-float(isle.isle_top())
	isle_near = (1.0-smoothstep(0.0,120.0,off))*(1.0-smoothstep(40.0,160.0,high))
	_water(listener)

## The stream bed at the nearest narrow water (a channel, a run) and the
## lapping bed at the nearest wide pool (the ground's pools: Rect2 and top).
func _water(listener: Vector3) -> void:
	var ground: Variant = isle.get("ground")
	var pools: Array = ground.get("pools") if ground != null else []
	var best := {"stream":[INF,Vector3.ZERO],"pond":[INF,Vector3.ZERO]}
	var pond_d := INF
	pond_rect = Rect2()
	for pool: Dictionary in pools:
		var rect: Rect2 = pool.rect
		var top := float(pool.top)
		var p := Vector2(clampf(listener.x,rect.position.x,rect.end.x),clampf(listener.z,rect.position.y,rect.end.y))
		var at := Vector3(p.x,top,p.y)
		var d := at.distance_to(listener)
		var kind := "stream" if minf(rect.size.x,rect.size.y) < 3.0 else "pond"
		if d < float(best[kind][0]): best[kind] = [d,at]
		if kind == "pond" and d < pond_d:
			pond_d = d
			pond_rect = rect
			pond_top = top
	for kind: String in best:
		var bed: Bed = stream if kind == "stream" else pond
		var d: float = best[kind][0]
		if d < 80.0:
			(bed.player as Node3D).global_position = best[kind][1]
			bed.goal = STREAM if kind == "stream" else POND
		else:
			bed.goal = 0.0

func _ambience(delta: float, listener: Vector3, flying: bool) -> void:
	var atmosphere: Node = isle.get("_atmosphere")
	var wind := 0.4
	if atmosphere != null: wind = clampf((float(atmosphere.get("_air_strength"))+float(atmosphere.get("swell")))/1.2,0.0,1.0)
	var open := 1.0-muffle
	breeze.goal = lerpf(BREEZE.x,BREEZE.y,wind)*(BREEZE_FLYING if flying else 1.0)*open
	breeze.pitch_goal = 0.9+0.2*wind
	thin.goal = THIN*(1.0-isle_near)*open
	leaves.goal = LEAVES*green*(0.4+0.6*wind)*isle_near
	var daylight := 1.0
	var celestial: Variant = isle.get("_celestial")
	if celestial != null: daylight = clampf(float(celestial.state.get("zs_daylight",1.0)),0.0,1.0)
	var night := 1.0-smoothstep(0.15,0.45,daylight)
	var precipitation: Variant = isle.get("_precipitation")
	var wet := clampf(float(precipitation.state.x),0.0,1.0) if precipitation != null else 0.0
	rain.goal = RAIN*wet
	# The living layer: birds by the time of day, bees, crickets, frogs, falls.
	if life != null: life.step(delta,listener,daylight,open,wet)
	# An owl now and then at night.
	_owl_wait -= delta
	if _owl_wait <= 0.0:
		_owl_wait = _rng.randf_range(OWL_GAP.x,OWL_GAP.y)
		if night > 0.7 and isle_near > 0.5 and life != null: shot("owl",0.1,1.0,life.singer(listener),FAR)
