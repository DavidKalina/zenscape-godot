extends Node
## Genesis sound (docs/scenic/sound.md): the world answers the hand in sound.
##
## - Stroke voices follow NativeChunkEditor's stroke signals and each brush's
##   feel: a low rumble while land rises (scaled with the rise rate, like the
##   tremor), pouring water while the water brush is down, then deep glugs as
##   the pour's ponds rise and a trickle as its streams run, a leafy wind
##   swell with the forest brush (it rides `atmosphere.swell`, so it swells
##   and settles with the trees), a soft swish for meadow and a gravel scuff
##   for path. Each voice is one looping player whose gain eases toward its
##   target (ATTACK, RELEASE), so fast dabs never stack and nothing clicks.
## - Creation beds follow what exists, read from LandLife's survey (never a
##   scan of their own): leaves rustle from the nearest wood with the wind,
##   and a quiet open-ground wind fills a bare plain and thins as life comes.
##   The Nature voices (studies/nature_audio.gd) are gated the same way:
##   birdsong comes from the woods and only when there are woods or birds,
##   crickets need cover, and frogs sing only where frogs have arrived.
##   Water lapping, the stream bed and rain stay with Nature's own beds.
## - Arrivals and moments get sparse, quiet one-shots: a plop for fish, one
##   croak for a frog, a heron's call, deer steps. When Bigfoot shows, the
##   birds hush for a while, and sometimes there is a distant wood knock.
##
## Everything plays on the "Genesis" bus (the Sound volume) under Master; the
## knock goes through "GenesisFar" (low-passed, with reverb). Streams load
## once in setup; players are pooled; nothing allocates per frame.

const Feedback = preload("res://scripts/stroke_feedback.gd")
const Survey = preload("res://scripts/life_survey.gd")
const WaterBrush = preload("res://scripts/water_brush.gd")
const Emergence = preload("res://scripts/emergence.gd")

const BUS := &"Genesis"
const FAR_BUS := &"GenesisFar"
const SETTINGS_PATH := "user://sound.cfg"
## Default settings: master volume, master mute and the Sound (Genesis) volume.
const DEFAULTS := {"master":1.0,"muted":false,"sound":0.8}

# --- Stroke voices -------------------------------------------------------
## Peak linear gain of each voice, before the Sound volume.
const RUMBLE_GAIN := 0.55
const POUR_GAIN := 0.3
## A released pour keeps a little of its sound while it settles on a worker.
const POUR_SETTLING := 0.35
const FILL_GAIN := 0.26
const RUN_GAIN := 0.18
const SWELL_GAIN := 0.3
const MEADOW_GAIN := 0.16
const PATH_GAIN := 0.2
const THUMP_GAIN := 0.5
## Gain response per second, rising and falling. About 140 ms in, 400 ms out.
const ATTACK := 7.0
const RELEASE := 2.5
## Brush speed (m/s) that reads as full movement for pour, meadow and path,
## and the share a brush held still keeps.
const SPEED_FULL := 6.0
const MOVE_FLOOR := 0.3
const SPEED_RESPONSE := 6.0
## Rumble pitch: slower rises sound deeper.
const RUMBLE_PITCH := Vector2(0.85,1.1)
## The held world rumble (scripts/world_rumble.gd) plays the rumble voice at
## this share of RUMBLE_GAIN at full level, deep, and through a paused world.
const HELD_GAIN := 0.85
const HELD_PITCH := Vector2(0.78,0.95)
## A filling pond's glugs rise in pitch as its water rises.
const FILL_PITCH := Vector2(0.9,1.12)

# --- Creation beds -------------------------------------------------------
const RUSTLE_GAIN := 0.15
const PLAIN_GAIN := 0.1
## A bare plain keeps this share of its open-ground wind even when full of life.
const PLAIN_FLOOR := 0.2
## Beds ease slowly, so walking the camera or a new wood fades them in and out.
const BED_RESPONSE := 0.6
## Seconds between presence updates (survey counts and nearest wood).
const BED_TICK := 0.5
## Camera distance (m) at which a bed is full, and where it has fallen to its
## floor. The creation camera usually sits about 50 m from the woods.
const NEAR := 30.0
const FAR := 90.0
const PROXIMITY_FLOOR := 0.2
## Trees that make a wood worth hearing, and the most wood points kept.
const WOOD_TREES := 12.0
const WOOD_POINTS := 160

# --- One-shots -----------------------------------------------------------
## kind -> [clips, gain, seconds before the same kind may sound again].
const ARRIVALS := {
	"fish":[["fish-plop-1","fish-plop-2"],0.16,6.0],
	"frog":[["frog-croak"],0.12,8.0],
}
## Seconds between any two arrival sounds, and the quiet after a world opens,
## loads or undoes (a settled world's arrivals land in a burst).
const SHOT_GAP := 1.5
const SHOT_QUIET := 12.0
const HERON_GAIN := 0.2
const HERON_DELAY := 1.5
const DEER_GAIN := 0.1
const BOW_GAIN := 0.08
const BOW_DELAY := 1.5
## The moonbow's swell: quieter and lower.
const MOONBOW_GAIN := 0.05
const MOONBOW_PITCH := 0.8
## Bigfoot: the birds hush this long; a knock comes with this chance, from
## KNOCK_BACK metres further into the wood, KNOCK_DELAY seconds after he shows.
const HUSH_SECONDS := 50.0
const KNOCK_CHANCE := 0.6
const KNOCK_GAIN := 0.22
const KNOCK_BACK := 8.0
const KNOCK_DELAY := Vector2(3.0,6.0)
const KNOCK_SPACING := 0.8
const THUMP_GAP := 0.3
const POOL := 4

enum {RUMBLE, POUR, FILL, RUN, SWELL, MEADOW, PATH, VOICES}
const VOICE_CLIPS := ["genesis-rumble","genesis-pour","genesis-fill","stream-bed","leaf-rustle-bed","genesis-meadow","genesis-path"]

var scene: Node3D
var editor: NativeChunkEditor
var world_rumble: Node
var life: Node3D
## Microseconds this node spent last frame and at most, for probes.
var last_usec := 0
var worst_usec := 0
## One-shots played so far by kind, for probes.
var played := {}

var _voices: Array[AudioStreamPlayer3D] = []
var _gain := PackedFloat32Array()
var _target := PackedFloat32Array()
var _rustle: AudioStreamPlayer3D
var _plain: AudioStreamPlayer
var _bow: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer3D] = []
var _far: AudioStreamPlayer3D
var _clips := {}
var _rng := RandomNumberGenerator.new()

# Stroke state.
var _stroking := false
var _mode := ""
var _rumble := 0.0
var _forest := false
var _brush := Vector3.ZERO
var _spent := 0.0
var _rate := 0.0
var _moved := 0.0
var _speed := 0.0
var _poured := false
var _thump_wait := 0.0
## The world rumble's strength over its peak, 0 when nothing holds it.
var _held := 0.0
## Emergence-clock windows of the last pour: ponds rising, stream fronts running.
var _fill := Vector2(INF,-INF)
var _run := Vector2(INF,-INF)

# Bed state.
var _active := false
var _tick := 0.0
var _survey: RefCounted
var _wood := PackedVector3Array()
var _trees := 0
var _shrubs := 0
var _damp := 0
var _water_area := 0.0
var _rustle_gain := 0.0
var _plain_gain := 0.0
var _rustle_target := 0.0
var _plain_target := 0.0
var _hush := 0.0

# One-shot state.
var _shot_wait := 0.0
var _kind_wait := {}
var _quiet := SHOT_QUIET
## Sounds waiting for their moment: [seconds left, clip, position, gain, pitch, far].
var _pending: Array = []

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "GenesisAudio"
	editor = scene._chunk_editor
	life = scene.get("land_life")
	world_rumble = scene.get("world_rumble")
	_rng.randomize()
	ensure_buses()
	apply_settings(load_settings())
	for clip: String in VOICE_CLIPS:
		var player := _player3d(_loop(clip),false)
		player.volume_db = -80.0
		player.play(_rng.randf()*player.stream.get_length())
		player.stream_paused = true
		_voices.append(player)
	_gain.resize(VOICES)
	_target.resize(VOICES)
	_rustle = _player3d(_loop("leaf-rustle-bed"),false)
	_plain = AudioStreamPlayer.new()
	_plain.stream = _loop("plain-air-bed")
	_plain.bus = BUS
	add_child(_plain)
	for player in [_rustle,_plain]:
		player.volume_db = -80.0
		player.play(_rng.randf()*player.stream.get_length())
		player.stream_paused = true
	_bow = AudioStreamPlayer.new()
	_bow.bus = BUS
	add_child(_bow)
	for i in range(POOL): _pool.append(_player3d(null,true))
	_far = _player3d(null,true)
	_far.bus = FAR_BUS
	for clip: String in ["genesis-thump","fish-plop-1","fish-plop-2","frog-croak","heron-call","wood-knock","bow-swell","footstep-1","footstep-2","footstep-3","footstep-4"]:
		_clips[clip] = load(_path(clip))
	editor.stroke_started.connect(_on_stroke_started)
	editor.stroke_moved.connect(_on_stroke_moved)
	editor.stroke_finished.connect(func(_center: Vector3, _radius: float, _mode_name: String) -> void: _stroking = false)
	editor.water_settled.connect(_on_water_settled)
	editor.data.state_restored.connect(func(_state: Dictionary) -> void: _world_changed())
	if life != null:
		life.arrived.connect(_on_arrived)
		life.moment.connect(_on_moment)

static func _path(clip: String) -> String:
	return "res://assets/audio/"+clip+".wav"

## A looping copy of a baked bed (the WAVs import unlooped).
func _loop(clip: String) -> AudioStreamWAV:
	var stream := (load(_path(clip)) as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# Imported audio may be compressed; byte count is not a sample count.
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	return stream

## Stroke voices and beds place themselves but set their own level
## (attenuation off, gentle panning). One-shots fall off with distance.
func _player3d(stream: AudioStream, falloff: bool) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = BUS
	player.panning_strength = 0.6
	if falloff:
		player.unit_size = 10.0
		player.max_distance = 90.0
	else:
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	add_child(player)
	return player

# --- Buses and settings --------------------------------------------------

## The Genesis bus under Master (a hard limiter keeps a busy moment calm), and
## GenesisFar under it for distant sounds: low-passed, with a wide reverb.
static func ensure_buses() -> void:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count-1
		AudioServer.set_bus_name(index,BUS)
		AudioServer.set_bus_send(index,&"Master")
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.5
		AudioServer.add_bus_effect(index,limiter)
	if AudioServer.get_bus_index(FAR_BUS) < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count-1
		AudioServer.set_bus_name(index,FAR_BUS)
		AudioServer.set_bus_send(index,BUS)
		var lowpass := AudioEffectLowPassFilter.new()
		lowpass.cutoff_hz = 1600.0
		AudioServer.add_bus_effect(index,lowpass)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.9
		reverb.damping = 0.55
		reverb.predelay_msec = 60.0
		reverb.spread = 1.0
		reverb.dry = 0.6
		reverb.wet = 0.45
		AudioServer.add_bus_effect(index,reverb)

static func load_settings() -> Dictionary:
	var settings := DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) == OK:
		settings.master = clampf(float(file.get_value("sound","master",settings.master)),0.0,1.0)
		settings.muted = bool(file.get_value("sound","muted",settings.muted))
		settings.sound = clampf(float(file.get_value("sound","sound",settings.sound)),0.0,1.0)
	return settings

static func apply_settings(settings: Dictionary) -> void:
	ensure_buses()
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,float(settings.master))))
	AudioServer.set_bus_mute(0,bool(settings.muted))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS),linear_to_db(maxf(0.0001,float(settings.sound))))

## Change one setting ("master", "muted" or "sound"), apply and keep it.
static func change(key: String, value: Variant) -> void:
	var settings := load_settings()
	settings[key] = value
	apply_settings(settings)
	var file := ConfigFile.new()
	for entry: String in settings: file.set_value("sound",entry,settings[entry])
	file.save(SETTINGS_PATH)

# --- Strokes -------------------------------------------------------------

func _on_stroke_started(center: Vector3, _radius: float, mode: String) -> void:
	_mode = mode
	var feel: Dictionary = Feedback.BRUSH_FEEL.get(mode,{})
	_rumble = float(feel.get("rumble",Feedback.RUMBLE_MODE.get(mode,0.0)))
	_forest = mode == "forest"
	_poured = mode == "water"
	_stroking = true
	_brush = center
	_spent = 0.0
	_moved = 0.0
	if mode == "mountain" and _thump_wait <= 0.0 and not scene._paused:
		_thump_wait = THUMP_GAP
		_shot("genesis-thump",center,THUMP_GAIN,1.0)

func _on_stroke_moved(center: Vector3, _radius: float, _mode_name: String, amount: float) -> void:
	if not _stroking: return
	_spent += amount
	_moved += Vector2(center.x-_brush.x,center.z-_brush.z).length()
	_brush = center

## A pour has landed: its ponds rise and its stream fronts run on the
## emergence clock (GardenView.water_births), so the glugs and trickle last
## exactly as long as the water is seen to move.
func _on_water_settled(bounds: Rect2) -> void:
	var now: float = Emergence.time
	_fill = Vector2(INF,-INF)
	_run = Vector2(INF,-INF)
	for birth: Dictionary in editor.content.water_births.values():
		var born := float(birth.born)
		# A pour's water starts while the hand pours; only water still moving.
		if born+(float(birth.seconds) if birth.has("seconds") else WaterBrush.FILL_SECONDS) < now: continue
		if birth.has("seconds"):
			_run = Vector2(minf(_run.x,born),maxf(_run.y,born+float(birth.seconds)))
		else:
			_fill = Vector2(minf(_fill.x,born),maxf(_fill.y,born+WaterBrush.FILL_SECONDS))
	var middle := bounds.get_center()
	var ground: Variant = editor.data.ground_height(middle)
	var at: Vector3 = editor.terrain.global_transform*Vector3(middle.x,float(ground) if ground != null else 0.0,middle.y)
	_voices[FILL].global_position = at
	_voices[RUN].global_position = at
	_poured = false

func _world_changed() -> void:
	_quiet = SHOT_QUIET
	_fill = Vector2(INF,-INF)
	_run = Vector2(INF,-INF)
	_pending.clear()

# --- Arrivals and moments ------------------------------------------------

func _on_arrived(kind: String, position: Vector3) -> void:
	if not ARRIVALS.has(kind) or _quiet > 0.0 or _shot_wait > 0.0 or float(_kind_wait.get(kind,0.0)) > 0.0: return
	var entry: Array = ARRIVALS[kind]
	var clips: Array = entry[0]
	if _shot(clips[_rng.randi_range(0,clips.size()-1)],position,float(entry[1]),_rng.randf_range(0.93,1.07)):
		_shot_wait = SHOT_GAP
		_kind_wait[kind] = float(entry[2])
		played[kind] = int(played.get(kind,0))+1

func _on_moment(kind: String, position: Vector3) -> void:
	match kind:
		"heron":
			_pending.append([HERON_DELAY,"heron-call",position,HERON_GAIN,_rng.randf_range(0.95,1.03),false])
		"deer":
			# A few soft steps in the litter as they come out of the trees.
			var at := 0.4
			for i in range(4):
				var step := position+Vector3(_rng.randf_range(-0.4,0.4),0.0,_rng.randf_range(-0.4,0.4))
				_pending.append([at,"footstep-%d" % _rng.randi_range(1,4),step,DEER_GAIN,_rng.randf_range(1.2,1.35),false])
				at += _rng.randf_range(0.45,0.7)
		"rainbow":
			_pending.append([BOW_DELAY,"bow-swell",Vector3.ZERO,BOW_GAIN,1.0,false])
		"moonbow":
			_pending.append([BOW_DELAY,"bow-swell",Vector3.ZERO,MOONBOW_GAIN,MOONBOW_PITCH,false])
		"bigfoot":
			# The wood goes quiet. Sometimes, from further in, a knock and another.
			_hush = HUSH_SECONDS
			if _rng.randf() < KNOCK_CHANCE:
				var away: Vector3 = position-scene.camera.global_position
				away.y = 0.0
				var from: Vector3 = position+away.normalized()*KNOCK_BACK if away.length() > 0.01 else position
				var delay := _rng.randf_range(KNOCK_DELAY.x,KNOCK_DELAY.y)
				_pending.append([delay,"wood-knock",from,KNOCK_GAIN,1.0,true])
				_pending.append([delay+KNOCK_SPACING+_rng.randf_range(-0.1,0.15),"wood-knock",from,KNOCK_GAIN*0.85,0.96,true])
		_:
			return
	played[kind] = int(played.get(kind,0))+1

## Play a one-shot from the pool; false when every player is busy.
func _shot(clip: String, position: Vector3, gain: float, pitch: float, far := false) -> bool:
	var stream: AudioStream = _clips[clip]
	if clip == "bow-swell":
		if _bow.playing: return false
		_bow.stream = stream
		_bow.volume_db = linear_to_db(gain)
		_bow.play()
		return true
	var player: AudioStreamPlayer3D = null
	if far:
		player = _far if not _far.playing else null
	else:
		for candidate in _pool:
			if not candidate.playing:
				player = candidate
				break
	if player == null: return false
	player.stream = stream
	player.global_position = position
	player.volume_db = linear_to_db(gain)
	player.pitch_scale = pitch
	player.play()
	return true

# --- Every frame ---------------------------------------------------------

func _process(delta: float) -> void:
	if scene == null or delta <= 0.0: return
	var began := Time.get_ticks_usec()
	var paused: bool = scene._paused
	_thump_wait -= delta
	_shot_wait -= delta
	_quiet -= delta
	for kind: String in _kind_wait: _kind_wait[kind] = float(_kind_wait[kind])-delta
	_stroke_targets(delta)
	for i in range(VOICES):
		var target := _target[i]
		var gain := lerpf(_gain[i],target,1.0-exp(-delta*(ATTACK if target > _gain[i] else RELEASE)))
		if target == 0.0 and gain < 0.0005: gain = 0.0
		_gain[i] = gain
		_level(_voices[i],gain,paused and not (i == RUMBLE and _held > 0.0))
	var active: bool = life != null and bool(life.active)
	if active != _active: _set_active(active)
	_tick -= delta
	if _tick <= 0.0:
		_tick = BED_TICK
		if _active: _bed_targets()
	_hush = maxf(0.0,_hush-delta)
	var bed := 1.0-exp(-delta*BED_RESPONSE)
	_rustle_gain = lerpf(_rustle_gain,_rustle_target,bed)
	_plain_gain = lerpf(_plain_gain,_plain_target,bed)
	if not _active and _rustle_gain < 0.0005: _rustle_gain = 0.0
	if not _active and _plain_gain < 0.0005: _plain_gain = 0.0
	_level(_rustle,_rustle_gain,paused)
	_level(_plain,_plain_gain,paused)
	for i in range(_pending.size()-1,-1,-1):
		var entry: Array = _pending[i]
		if not paused: entry[0] = float(entry[0])-delta
		if float(entry[0]) > 0.0: continue
		_pending.remove_at(i)
		_shot(entry[1],entry[2],entry[3],entry[4],entry[5])
	last_usec = Time.get_ticks_usec()-began
	worst_usec = maxi(worst_usec,last_usec)

func _level(player, gain: float, paused: bool) -> void:
	var silent := gain <= 0.0 or paused
	if player.stream_paused != silent: player.stream_paused = silent
	if not silent: player.volume_db = linear_to_db(gain)

func _stroke_targets(delta: float) -> void:
	var follow := 1.0-exp(-delta*Feedback.RATE_RESPONSE)
	_rate = lerpf(_rate,_spent/delta,follow) if _stroking else 0.0
	_speed = lerpf(_speed,_moved/delta,1.0-exp(-delta*SPEED_RESPONSE)) if _stroking else 0.0
	_spent = 0.0
	_moved = 0.0
	var move := MOVE_FLOOR+(1.0-MOVE_FLOOR)*clampf(_speed/SPEED_FULL,0.0,1.0)
	var rise := clampf(_rate/Feedback.RUMBLE_FULL_RATE,0.0,1.0)
	_target.fill(0.0)
	if _stroking:
		_voices[_voice_for(_mode)].global_position = _brush
		if _rumble > 0.0: _target[RUMBLE] = RUMBLE_GAIN*minf(1.0,_rumble)*rise
		match _mode:
			"water": _target[POUR] = POUR_GAIN*move
			"path": _target[PATH] = PATH_GAIN*move
			_:
				if _mode == "meadow" or _mode in Feedback.GROWTH_MODES: _target[MEADOW] = MEADOW_GAIN*move
	elif _poured and editor.water_settling:
		_target[POUR] = POUR_GAIN*POUR_SETTLING
	_voices[RUMBLE].global_position = _brush
	_voices[RUMBLE].pitch_scale = lerpf(RUMBLE_PITCH.x,RUMBLE_PITCH.y,rise)
	# A held world rumble follows its swelling strength, and wins when louder.
	_held = 0.0 if world_rumble == null else float(world_rumble.strength)/float(world_rumble.PEAK)
	var held := RUMBLE_GAIN*HELD_GAIN*minf(1.0,_held)
	if held > _target[RUMBLE]:
		_target[RUMBLE] = held
		_voices[RUMBLE].global_position = scene.target
		_voices[RUMBLE].pitch_scale = lerpf(HELD_PITCH.x,HELD_PITCH.y,clampf(_held,0.0,1.0))
	# The forest's leafy swell rides the same eased swell the trees sway to.
	if _forest:
		_voices[SWELL].global_position = _brush
		_target[SWELL] = SWELL_GAIN*clampf(float(scene._atmosphere.swell)/float(Feedback.BRUSH_FEEL.forest.swell),0.0,1.0)
		if not _stroking and _target[SWELL] < 0.01: _forest = false
	var now: float = Emergence.time
	if now >= _fill.x and now <= _fill.y:
		var t := (now-_fill.x)/maxf(0.001,_fill.y-_fill.x)
		_target[FILL] = FILL_GAIN*smoothstep(0.0,0.15,t)
		_voices[FILL].pitch_scale = lerpf(FILL_PITCH.x,FILL_PITCH.y,t)
	if now >= _run.x and now <= _run.y:
		_target[RUN] = RUN_GAIN

func _voice_for(mode: String) -> int:
	match mode:
		"water": return POUR
		"path": return PATH
		"forest": return SWELL
	return MEADOW if mode == "meadow" or mode in Feedback.GROWTH_MODES else RUMBLE

# --- Beds ----------------------------------------------------------------

func _set_active(value: bool) -> void:
	_active = value
	_survey = null
	_wood.clear()
	_rustle_target = 0.0
	_plain_target = 0.0
	var nature: Node = _nature()
	if nature == null: return
	# Off a blank world, Nature plays as it always has.
	nature.song_presence = 1.0
	nature.cricket_presence = 1.0
	nature.frog_presence = 1.0
	nature.song_points = PackedVector3Array()

func _nature() -> Node:
	var ambient: Variant = scene.get("_ambient_audio")
	return ambient.nature if ambient != null else null

## Counts and the nearest wood from LandLife's last survey; what has arrived
## from its sites. Runs every BED_TICK seconds, never per frame.
func _bed_targets() -> void:
	if life.survey != _survey:
		_survey = life.survey
		_read_survey()
	var birds := _here("bird")
	var frogs := _here("frog")
	var spawn := _here("spawn")
	var rain: float = scene._precipitation.state.x
	var atmosphere: Node = scene._atmosphere
	var wind := clampf(0.35+0.65*(float(atmosphere._air_strength)+float(atmosphere.swell))/1.2,0.0,1.0)
	var listener: Vector3 = scene.camera.global_position
	var woods := clampf(_trees/WOOD_TREES,0.0,1.0)
	var near := INF
	var nearest := Vector3.ZERO
	for point in _wood:
		var distance := listener.distance_squared_to(point)
		if distance < near:
			near = distance
			nearest = point
	if not _wood.is_empty():
		_rustle.global_position = nearest
		_rustle_target = RUSTLE_GAIN*woods*wind*_proximity(sqrt(near))*(1.0-0.4*rain)
	else:
		_rustle_target = 0.0
	var alive := clampf(_trees/10.0+_shrubs/30.0+_water_area/10.0,0.0,1.0)
	_plain_target = PLAIN_GAIN*lerpf(1.0,PLAIN_FLOOR,alive)*(0.55+0.45*wind)*(1.0-0.5*rain)
	var nature: Node = _nature()
	if nature == null: return
	# 1 while Bigfoot's hush holds, easing back over its last ten seconds.
	var hush := smoothstep(0.0,10.0,_hush)
	nature.song_presence = clampf(_trees/8.0+_shrubs/40.0+birds/4.0,0.0,1.0)*(1.0-0.85*rain)*(1.0-hush)
	nature.cricket_presence = clampf(0.15+_shrubs/25.0+_trees/15.0+_damp/80.0,0.0,1.0)*(1.0-0.7*hush)
	nature.frog_presence = 1.0 if frogs > 0 else (0.35 if spawn > 0 else 0.0)
	nature.song_points = _wood

func _proximity(distance: float) -> float:
	return lerpf(1.0,PROXIMITY_FLOOR,smoothstep(NEAR,FAR,distance))

func _here(kind: String) -> int:
	var count := 0
	for site: Dictionary in life.sites[kind].values():
		if site.here and not site.leaving: count += 1
	return count

func _read_survey() -> void:
	_wood.clear()
	_trees = 0
	_shrubs = 0
	_damp = 0
	_water_area = 0.0
	if _survey == null: return
	_trees = int(_survey.tree_count)
	_shrubs = int(_survey.shrub_count)
	_damp = _survey.damp.size()
	for record: Dictionary in _survey.bodies: _water_area += float(record.area)
	var plate: Transform3D = editor.terrain.global_transform
	var grid: PackedInt32Array = _survey.tree_grid
	# Every wooded metre, thinned evenly to at most WOOD_POINTS.
	var every := maxi(1,ceili((grid.size()-grid.count(0))/float(WOOD_POINTS)))
	var seen := 0
	for index in range(grid.size()):
		if grid[index] <= 0: continue
		seen += 1
		if seen%every != 0: continue
		var p := Vector2((index%Survey.COARSE)+0.5,(index/Survey.COARSE)+0.5)-Vector2(Survey.HALF,Survey.HALF)
		var ground: float = _survey.ground_at(p)
		_wood.append(plate*Vector3(p.x,(0.0 if is_nan(ground) else ground)+1.5,p.y))
