extends Node
## The beasts' sound (docs/design/sound-round3.md): the sky dragon
## (scripts/sky_dragon.gd, its gale scripts/dragon_gale.gd and breath
## scripts/dragon_breath.gd) and the rune serpent (scripts/rune_serpent.gd,
## ridden through scripts/kit_isle/serpent_rider.gd or the ride greybox).
## A child of scripts/kit_isle/kit_audio.gd on every kit isle; the serpent
## ride greybox (studies/serpent_ride.gd) makes one by itself (`attach`).
##
## Everything here reads the beasts; nothing steers them. They are found as
## they enter the tree (by their scripts), so any scene that has them gets
## their sound. The clips are baked by tools/generate_kit_audio.py.
##
## - The dragon: a deep whump on each downstroke, timed to its wing's beat
##   (`phase`, `flap_w`: the stroke's middle is where the sample peaks), the
##   membrane's rustle and flutter on the upstroke; air rushing past it as
##   it goes by; a long low call as it rises from the cloud sea, as it
##   comes in toward you and with its roars (the jaw opening); on a rim, the
##   slam and the rock coming away, a chest growl by its breath, the isle's
##   stone grinding as it tips (by the sag's speed); the long draw in (the
##   tell) and the blow, a vast rush of air (not fire); the gale howling past
##   wherever its blast and ribbons go, a buffet and a wind slam on the plane
##   as a gust strikes; letting go, a huge beat and the rubble.
## - The serpent: its stone scales grinding along its body at the ring
##   nearest you, louder and higher with its pace; the runes' deep hum
##   there too; its slow breath at its head (its own 5.2 s cycle). Riding
##   it: a rumble under the feet by its pace, a swish as a carve starts and
##   each time it changes side, a scrape while carving or sliding.
##
## The dragon's big voices go on SFX Far (under SFX: a long reverb, the
## top eased off), the rest on SFX. The Effects volume covers all of it.

const KIT := "res://assets/audio/kit/"
const OLD := "res://assets/audio/"
const SFX := &"SFX"
const FAR := &"SFX Far"
const DRAGON_SCRIPT := "res://scripts/sky_dragon.gd"
const SERPENT_SCRIPT := "res://scripts/rune_serpent.gd"
const RIDER_SCRIPT := "res://scripts/kit_isle/serpent_rider.gd"

# --- Tuning ----------------------------------------------------------------------

## The dragon's reach (m): one-shots heard at full within `x`, gone by `y`.
const DRAGON_UNIT := 60.0
const DRAGON_REACH := 1600.0
## A downstroke's whump and an upstroke's rustle (gain at a full beat);
## the whump's peak lies BEAT_PEAK s into its sample, and the stroke's
## middle at STROKE_MID of the beat (sky_dragon.gd DOWN is 0.5).
const BEAT := 0.5
const UPSTROKE := 0.16
const BEAT_PEAK := 0.35
const STROKE_MID := 0.25
const UP_AT := 0.6
## The air past it (a rush loop pitched down), by its speed (m/s).
const PASS := 0.22
const PASS_SPEED := Vector2(20.0,54.0)
## Its call: gain, reach (m), the shortest gap (s) between calls, and the
## distance (m) whose crossing inward (coming toward you) calls.
const CALL := 0.55
const CALL_UNIT := 140.0
const CALL_REACH := 2600.0
const CALL_GAP := 16.0
const APPROACH := 420.0
## On a rim: the slam, the rubble, the growl (by the breath's beat), the
## grinding stone (a base while held, more with the sag's speed, m/s),
## the draw in and the blow.
const SLAM := 0.6
const DEBRIS := 0.35
const GROWL := 0.3
const GROWL_BY := {"settle":0.8,"pant":0.6,"inhale":0.25,"blow":0.35,"recover":0.65,"pull":1.0}
const GRIND := Vector2(0.08,0.4)
const GRIND_SAG := 2.0
const INHALE := 0.4
const EXHALE := 0.55
## The gale: its howl along the blast (gain at full gust), the ribbons'
## howl round the listener (gain at RIBBON_AIR m/s of their air), how far
## (m) and how high round the listener the ribbons are felt.
const GALE := 0.4
const GALE_REACH := 900.0
const GALE_NEAR := 0.3
const RIBBON_AIR := 18.0
const RIBBON_REACH := Vector2(14.0,8.0)
## A gust on the plane: the strength that strikes (and must fall under
## BUFFET_RESET before it strikes again), the slam's and buffets' gain,
## the gap (s) between buffets at full strength.
const BUFFET_AT := 0.25
const BUFFET_RESET := 0.1
const WIND_SLAM := 0.3
const BUFFET := 0.2
const BUFFET_GAP := Vector2(0.18,0.5)
## Letting go: the launch beat's gain over a beat's, the rubble.
const LAUNCH := 1.6
## The serpent: its scales (gain at the pace's top, PACE m/s) and their
## floor at rest, the hum, the breath; the beds' reach (m) and what each
## is heard at full within; serpents further off are left silent.
const SCALES := Vector2(0.06,0.3)
const PACE := 17.0
const HUM := 0.16
const BREATH := 0.22
const SERPENT_UNIT := 10.0
const SERPENT_REACH := 260.0
## Riding it: the rumble under the feet (by its pace), the carve's swish
## and scrape.
const RIDE := Vector2(0.06,0.18)
const CARVE_SWISH := 0.12
const CARVE_SCRAPE := 0.1

## A looping voice, as kit_audio.gd's Bed: gain and pitch eased to their
## goals, stopped while silent, started at a random point when heard.
class Bed extends RefCounted:
	var player
	var gain := 0.0
	var goal := 0.0
	var pitch := 1.0
	var pitch_goal := 1.0
	var attack := 4.0
	var release := 2.0
	func step(delta: float) -> void:
		gain = lerpf(gain,goal,1.0-exp(-delta*(attack if goal > gain else release)))
		if goal <= 0.0 and gain < 0.0006: gain = 0.0
		pitch = lerpf(pitch,pitch_goal,1.0-exp(-delta*6.0))
		if gain <= 0.0:
			if player.playing: player.stop()
			return
		if not player.playing: player.play(randf()*player.stream.get_length())
		player.volume_db = linear_to_db(gain)
		player.pitch_scale = clampf(pitch,0.1,4.0)

## The kit's sound (kit_audio.gd), or null standing alone (`attach`).
var audio: Node
## The scene read each frame: its `camera`, and if it has them its
## `motor`, `flying`, `plane`, `riding_on` (the ride greybox's).
var host: Node
## The beasts found (probes): dragons, serpents, the serpent's riders.
var dragons: Array[Node] = []
var serpents: Array[Node] = []
var riders: Array[Node] = []
## One-shots played, by kind (probes).
var played := {}
## The strongest gust on the plane now (probes).
var gust := 0.0

var _rng := RandomNumberGenerator.new()
var _clips := {}
var _last := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _flat: Array[AudioStreamPlayer] = []
var _next := 0
var _next_flat := 0
var _beds: Array[Bed] = []
## Per dragon (by instance id): its beds and what it was last frame.
var _d := {}
## Per serpent: its beds and its breath's phase last frame.
var _s := {}
var _gale_near: Bed
var _ride: Bed
var _carve: Bed
var _call_wait := 4.0
var _buffet_wait := 0.0
var _struck := false
var _carving_was := 0.0

## The ride greybox (or any scene with a camera and no kit sound): the
## buses and kept settings, then a beasts node under `scene`.
static func attach(scene: Node) -> Node:
	var kit: GDScript = load("res://scripts/kit_isle/kit_audio.gd")
	kit.ensure_buses()
	kit.Audio.apply_settings(kit.load_settings())
	kit.apply_settings(kit.load_settings())
	var beasts: Node = load("res://scripts/kit_isle/kit_audio_beasts.gd").new()
	beasts.host = scene
	scene.add_child(beasts)
	return beasts

func _ready() -> void:
	name = "KitAudioBeasts"
	_rng.randomize()
	_ensure_far_bus()
	for i in range(14):
		var p := AudioStreamPlayer3D.new()
		p.bus = SFX
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_pool.append(p)
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.bus = SFX
		add_child(p)
		_flat.append(p)
	_clips = {
		"dragon_beat":_takes(KIT+"dragon-beat-%d.wav",4),"dragon_up":_takes(KIT+"dragon-up-%d.wav",3),
		"dragon_call":_takes(KIT+"dragon-call-%d.wav",3),"dragon_slam":_takes(KIT+"dragon-slam-%d.wav",2),
		"debris":_takes(KIT+"rock-debris-%d.wav",3),"inhale":[load(KIT+"dragon-inhale.wav")],
		"exhale":_takes(KIT+"dragon-exhale-%d.wav",2),"buffet":_takes(KIT+"buffet-%d.wav",3),
		"wind_slam":_takes(KIT+"wind-slam-%d.wav",2),"serpent_breath":_takes(KIT+"serpent-breath-%d.wav",2),
		"swish":_takes(KIT+"swish-%d.wav",4),"whoosh":_takes(KIT+"whoosh-%d.wav",4),"thump":_takes(KIT+"thump-%d.wav",3),
	}
	_gale_near = _bed(KIT+"gale-howl-loop.wav",SFX,false)
	_gale_near.attack = 3.0
	_gale_near.release = 1.2
	_ride = _bed(KIT+"stone-grind-loop.wav",SFX,false)
	_ride.attack = 2.0
	_ride.release = 2.0
	_carve = _bed(OLD+"foley/scrape-loop.wav",SFX,false)
	_carve.attack = 8.0
	_carve.release = 4.0
	for node: Node in get_tree().root.find_children("*","Node3D",true,false): _found(node)
	get_tree().node_added.connect(_found)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_found): get_tree().node_added.disconnect(_found)

## SFX Far: under SFX (so the Effects volume and the cloud sea's hush
## hold), its top eased off and a long open reverb, for the dragon's
## voices far off over the sky.
static func _ensure_far_bus() -> void:
	if AudioServer.get_bus_index(FAR) >= 0: return
	AudioServer.add_bus()
	var index := AudioServer.bus_count-1
	AudioServer.set_bus_name(index,FAR)
	AudioServer.set_bus_send(index,SFX)
	var lpf := AudioEffectLowPassFilter.new()
	lpf.cutoff_hz = 5000.0
	AudioServer.add_bus_effect(index,lpf)
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.9
	reverb.damping = 0.45
	# The beats' and the call's sub (34-44 Hz) kept out of the tail: fed
	# into the reverb it rang up past full scale (about +21 dB on a call)
	# and the output cut out.
	reverb.hipass = 0.5
	reverb.predelay_msec = 80.0
	reverb.spread = 1.0
	reverb.dry = 0.85
	reverb.wet = 0.3
	AudioServer.add_bus_effect(index,reverb)

func _found(node: Node) -> void:
	var script: Script = node.get_script()
	if script == null: return
	match script.resource_path:
		DRAGON_SCRIPT: if not dragons.has(node): dragons.append(node)
		SERPENT_SCRIPT: if not serpents.has(node): serpents.append(node)
		RIDER_SCRIPT: if not riders.has(node): riders.append(node)

static func _takes(pattern: String, count: int) -> Array:
	var out := []
	for i in range(count): out.append(load(pattern % (i+1)))
	return out

func _bed(path: String, bus: StringName, placed: bool, unit := 10.0, reach := 200.0) -> Bed:
	var stream := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	var player
	if placed:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = unit
		p3.max_distance = reach
		p3.panning_strength = 0.8
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
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

## One take of `kind` (never the one before) at `at` in the world, heard at
## full within `unit` m and gone by `reach`; on the listener if `at` is INF.
func shot(kind: String, gain: float, pitch := 1.0, at := Vector3.INF, unit := 8.0, reach := 120.0, bus := SFX) -> void:
	var takes: Array = _clips.get(kind,[])
	if takes.is_empty() or gain <= 0.0: return
	var pick := _rng.randi_range(0,takes.size()-1)
	if takes.size() > 1 and pick == int(_last.get(kind,-1)): pick = (pick+1)%takes.size()
	_last[kind] = pick
	var player
	if at == Vector3.INF:
		player = _free(_flat,_next_flat)
		_next_flat = (_next_flat+1)%_flat.size()
	else:
		var p3 := _free(_pool,_next) as AudioStreamPlayer3D
		_next = (_next+1)%_pool.size()
		p3.global_position = at
		p3.unit_size = unit
		p3.max_distance = reach
		p3.panning_strength = 0.8
		player = p3
	player.stream = takes[pick]
	player.bus = bus
	player.volume_db = linear_to_db(gain)+_rng.randf_range(-1.0,1.0)
	player.pitch_scale = pitch*_rng.randf_range(0.95,1.05)
	player.play()
	played[kind] = int(played.get(kind,0))+1

func _free(pool: Array, next: int) -> Node:
	for p: Node in pool:
		if not p.playing: return p
	return pool[next]

# --- Every frame --------------------------------------------------------------------

func _process(delta: float) -> void:
	if host == null or not is_instance_valid(host) or delta <= 0.0: return
	var camera: Camera3D = host.get("camera")
	if camera == null or not camera.is_inside_tree(): return
	step(delta,camera.global_position)

## One frame of every beast's sound, heard from `listener`.
func step(delta: float, listener: Vector3) -> void:
	_call_wait -= delta
	var ribbons := 0.0
	gust = 0.0
	for dragon: Node in dragons.duplicate():
		if not is_instance_valid(dragon) or not dragon.is_inside_tree():
			dragons.erase(dragon)
			continue
		ribbons = maxf(ribbons,_dragon(dragon,delta,listener))
	_plane_gust(delta)
	_gale_near.goal = GALE_NEAR*clampf(maxf(ribbons/RIBBON_AIR,gust),0.0,1.2)
	_gale_near.pitch_goal = 0.85+0.25*clampf(ribbons/RIBBON_AIR,0.0,1.0)
	for serpent: Node in serpents.duplicate():
		if not is_instance_valid(serpent) or not serpent.is_inside_tree():
			serpents.erase(serpent)
			continue
		_serpent(serpent,listener)
	_riding(delta)
	for bed in _beds: bed.step(delta)

# --- The dragon --------------------------------------------------------------------

func _dragon_beds(dragon: Node) -> Dictionary:
	var id := dragon.get_instance_id()
	if _d.has(id): return _d[id]
	var air := _bed(KIT+"air-rush-loop.wav",SFX,true,25.0,500.0)
	air.attack = 2.0
	air.release = 1.0
	var growl := _bed(KIT+"dragon-growl-loop.wav",FAR,true,30.0,900.0)
	growl.attack = 2.5
	growl.release = 1.5
	var grind := _bed(KIT+"stone-grind-loop.wav",FAR,true,35.0,900.0)
	grind.attack = 6.0
	grind.release = 1.5
	var gale := _bed(KIT+"gale-howl-loop.wav",SFX,true,40.0,GALE_REACH)
	gale.attack = 3.0
	gale.release = 0.8
	var beds := {"air":air,"growl":growl,"grind":grind,"gale":gale,"phase":-1.0,"roar":-1.0,"state":"waiting","breath":"","dist":INF,"launched":0}
	_d[id] = beds
	return beds

## One dragon's frame; returns its ribbons' air round the listener (m/s).
func _dragon(dragon: Node, delta: float, listener: Vector3) -> float:
	var b := _dragon_beds(dragon)
	var state := str(dragon.state)
	var model: Node3D = dragon.get("model")
	var shown := model != null and model.visible and state != "waiting"
	if not shown:
		for k: String in ["air","growl","grind","gale"]: (b[k] as Bed).goal = 0.0
		b.state = state
		return 0.0
	var at: Vector3 = (dragon as Node3D).global_position
	var dist := at.distance_to(listener)
	var was_state: String = b.state
	# Risen from the cloud sea: a call far below.
	if was_state == "waiting" and state != "waiting": _call(at)
	# Coming in toward you.
	if dist < APPROACH and float(b.dist) >= APPROACH: _call(at)
	b.dist = dist
	_wings(dragon,b,at,delta)
	# The air past it.
	var air: Bed = b.air
	(air.player as Node3D).global_position = at
	var spd := float(dragon.speed) if state != "clinging" else 0.0
	air.goal = PASS*smoothstep(PASS_SPEED.x,PASS_SPEED.y,spd) if dist < 500.0 else 0.0
	air.pitch_goal = 0.5+0.2*smoothstep(PASS_SPEED.x,PASS_SPEED.y,spd)
	# Its roars: the call as the jaw opens.
	var roar: float = dragon.roar_time() if dragon.has_method("roar_time") else -1.0
	if state != "clinging" and float(b.roar) < 0.45 and roar >= 0.45: _call(dragon.mouth_at())
	b.roar = roar
	var ribbons := _rim(dragon,b,state,was_state,listener)
	b.state = state
	return ribbons

## The wingbeat: the whump fired ahead of the downstroke's middle by its
## sample's lead, the rustle on the way up.
func _wings(dragon: Node, b: Dictionary, at: Vector3, delta: float) -> void:
	var phase := float(dragon.phase)
	var flap := float(dragon.flap_w)
	var was := float(b.phase)
	b.phase = phase
	if was < 0.0: return
	var moved := fposmod(phase-was,1.0)
	if moved <= 0.0 or moved > 0.5: return
	var hz := moved/maxf(delta,0.001)
	var down := fposmod(STROKE_MID-BEAT_PEAK*hz,1.0)
	var state := str(dragon.state)
	var heavy := 1.0
	if state == "grabbing": heavy = 1.25
	elif str(dragon.mode) == "climb": heavy = 1.15
	if _crossed(was,phase,down) and flap > 0.15:
		shot("dragon_beat",BEAT*heavy*(0.3+0.7*flap),_rng.randf_range(0.9,1.02)/sqrt(heavy),at,DRAGON_UNIT,DRAGON_REACH,FAR)
	if _crossed(was,phase,UP_AT) and flap > 0.25:
		shot("dragon_up",UPSTROKE*flap,_rng.randf_range(0.9,1.1),at,DRAGON_UNIT*0.6,DRAGON_REACH*0.6)

## Whether going from `a` to `b` (forward, wrapping at 1) passes `mark`.
static func _crossed(a: float, b: float, mark: float) -> bool:
	if b >= a: return a < mark and mark <= b
	return mark > a or mark <= b

func _call(at: Vector3) -> void:
	if _call_wait > 0.0: return
	_call_wait = CALL_GAP*_rng.randf_range(1.0,1.5)
	shot("dragon_call",CALL,_rng.randf_range(0.92,1.04),at,CALL_UNIT,CALL_REACH,FAR)

## On a rim: the slam, the growl and the stone, the breath, the gale, the
## let go. Returns the ribbons' air round the listener.
func _rim(dragon: Node, b: Dictionary, state: String, was_state: String, listener: Vector3) -> float:
	var gale: Node = dragon.get("gale")
	var grip: Dictionary = dragon.get("grip")
	var growl: Bed = b.growl
	var grind: Bed = b.grind
	var howl: Bed = b.gale
	var rim := Vector3.INF
	if not grip.is_empty() and grip.has("rim"):
		rim = grip.rim
		# The rim as the isle stands now (tipped and sagged).
		if gale != null and gale.isle != null and is_instance_valid(gale.isle):
			rim = (gale.isle.transform*(gale.isle_rest as Transform3D).affine_inverse())*rim
	if state == "clinging" and was_state != "clinging" and rim != Vector3.INF:
		shot("dragon_slam",SLAM,_rng.randf_range(0.92,1.02),rim,DRAGON_UNIT,DRAGON_REACH,FAR)
		shot("debris",DEBRIS,1.0,rim,30.0,800.0)
	if state == "leaving" and was_state == "clinging":
		var at: Vector3 = (dragon as Node3D).global_position
		shot("dragon_beat",BEAT*LAUNCH,0.82,at,DRAGON_UNIT,DRAGON_REACH,FAR)
		shot("wind_slam",0.3,0.7,at,40.0,700.0)
		if rim != Vector3.INF:
			shot("debris",DEBRIS*1.2,0.9,rim,30.0,800.0)
			shot("debris",DEBRIS*0.8,1.1,rim+Vector3.DOWN*6.0,30.0,800.0)
	var breath := str(dragon.breath) if state == "clinging" else ""
	var mouth: Vector3 = dragon.mouth_at() if state in ["clinging","grabbing","leaving"] else (dragon as Node3D).global_position
	if breath != str(b.breath):
		if breath == "inhale": shot("inhale",INHALE,_rng.randf_range(0.9,1.0),mouth,40.0,1100.0,FAR)
		elif breath == "blow": shot("exhale",EXHALE,_rng.randf_range(0.9,1.0),mouth,50.0,1400.0,FAR)
	b.breath = breath
	(growl.player as Node3D).global_position = mouth
	growl.goal = GROWL*float(GROWL_BY.get(breath,0.0))
	growl.pitch_goal = 1.15 if breath == "pull" else 1.0
	# The stone grinds while the isle is held and as it moves (the sag's speed).
	var held := gale != null and str(gale.phase) in ["held","snap"]
	if held and rim != Vector3.INF:
		(grind.player as Node3D).global_position = rim
		var moving := clampf(absf(float(gale.sag_v))/GRIND_SAG,0.0,1.0)
		grind.goal = lerpf(GRIND.x,GRIND.y,maxf(moving,1.0 if breath == "pull" else 0.0))
		grind.pitch_goal = 0.75+0.3*moving
	else:
		grind.goal = 0.0
	# The pilot flung off the springing isle.
	var launched := int(dragon.get("launched"))
	if launched > int(b.launched):
		shot("wind_slam",0.25,1.0)
		shot("whoosh",0.2,0.8)
	b.launched = launched
	if gale == null: return 0.0
	# The gale: along the blast's line, at its point nearest the listener.
	var env := float(gale.gust_env)
	if env > 0.01 and state == "clinging":
		var way: Vector3 = dragon.blast_way()
		var along := clampf((listener-mouth).dot(way),0.0,170.0)
		(howl.player as Node3D).global_position = mouth+way*along
		howl.goal = GALE*env
		howl.pitch_goal = 0.8+0.25*env
	else:
		howl.goal = 0.0
	# Its ribbons round the listener.
	var ribbon_node: Node = gale.get("breath")
	if ribbon_node != null and int(ribbon_node.count()) > 0:
		return (ribbon_node.air_near(listener,RIBBON_REACH.x,RIBBON_REACH.y) as Vector3).length()
	return 0.0

## A gust on the plane (dragon_gale.gd `plane_gust`, as the plane reads it):
## the strike (a wind slam and a buffet), then buffets while it holds.
func _plane_gust(delta: float) -> void:
	var plane = host.get("plane") if host != null else null
	var flying := bool(host.get("flying")) if host != null and host.get("flying") != null else false
	if not flying or plane == null or not plane.has_method("forward"):
		_struck = false
		return
	for dragon: Node in dragons:
		var gale: Node = dragon.get("gale")
		if gale == null: continue
		var g: Dictionary = gale.plane_gust(plane.position,plane.forward())
		if not g.is_empty(): gust = maxf(gust,float(g.gust))
	if gust >= BUFFET_AT and not _struck:
		_struck = true
		shot("wind_slam",WIND_SLAM*clampf(gust,0.5,1.2))
		shot("buffet",BUFFET*1.4,0.9)
		_buffet_wait = BUFFET_GAP.x
	elif gust < BUFFET_RESET:
		_struck = false
	_buffet_wait -= delta
	if gust > 0.15 and _buffet_wait <= 0.0:
		_buffet_wait = _rng.randf_range(BUFFET_GAP.x,BUFFET_GAP.y)/clampf(gust,0.3,1.2)
		shot("buffet",BUFFET*clampf(gust,0.0,1.2),_rng.randf_range(0.9,1.15))

# --- The serpent ---------------------------------------------------------------

func _serpent_beds(serpent: Node) -> Dictionary:
	var id := serpent.get_instance_id()
	if _s.has(id): return _s[id]
	var scales := _bed(KIT+"serpent-scales-loop.wav",SFX,true,SERPENT_UNIT,SERPENT_REACH)
	scales.attack = 2.0
	scales.release = 1.5
	var hum := _bed(KIT+"serpent-hum-loop.wav",SFX,true,SERPENT_UNIT*1.2,SERPENT_REACH)
	hum.attack = 1.5
	hum.release = 1.5
	var beds := {"scales":scales,"hum":hum,"breath":-1.0}
	_s[id] = beds
	return beds

## Its scales and hum at the ring nearest the listener, its breath at the
## head.
func _serpent(serpent: Node, listener: Vector3) -> void:
	var b := _serpent_beds(serpent)
	var scales: Bed = b.scales
	var hum: Bed = b.hum
	var rings: PackedVector3Array = serpent.rings()
	if rings.is_empty() or not (serpent as Node3D).visible:
		scales.goal = 0.0
		hum.goal = 0.0
		return
	var xf := (serpent as Node3D).global_transform
	var best := INF
	var near := Vector3.ZERO
	var k := 0
	for i in range(0,rings.size()):
		var p := xf*rings[i]
		var d := p.distance_squared_to(listener)
		if d < best:
			best = d
			near = p
			k = i
	var dist := sqrt(best)
	var pace := clampf(float(serpent.speed())/PACE,0.0,1.2)
	var heard := dist < SERPENT_REACH
	(scales.player as Node3D).global_position = near
	scales.goal = lerpf(SCALES.x,SCALES.y,pace) if heard else 0.0
	scales.pitch_goal = 0.8+0.3*pace
	# The runes hum a little off the scales' spot (toward the head), so
	# near the body the two sit apart.
	(hum.player as Node3D).global_position = xf*rings[maxi(k-2,0)]
	hum.goal = HUM if heard else 0.0
	hum.pitch_goal = 0.97+0.06*pace
	var breath: float = serpent.breath_phase() if serpent.has_method("breath_phase") else -1.0
	if breath >= 0.0 and float(b.breath) >= 0.0 and breath < float(b.breath) and heard:
		shot("serpent_breath",BREATH,_rng.randf_range(0.92,1.04),xf*rings[0],SERPENT_UNIT*1.5,SERPENT_REACH)
	b.breath = breath

## On its back: the rumble under the feet, the carve's swish and scrape.
func _riding(_delta: float) -> void:
	var on: Node = null
	if host != null and str(host.get("riding_on")) == "serpent": on = host.get("serpent")
	for rider: Node in riders:
		if is_instance_valid(rider) and str(rider.riding_on) == "serpent": on = rider.serpent
	var motor = host.get("motor") if host != null else null
	if on == null or not is_instance_valid(on) or motor == null:
		_ride.goal = 0.0
		_carve.goal = 0.0
		_carving_was = 0.0
		return
	var pace := clampf(float(on.speed())/PACE,0.0,1.2)
	_ride.goal = lerpf(RIDE.x,RIDE.y,pace)
	_ride.pitch_goal = 0.5+0.15*pace
	var carving := float(motor.carving) if bool(motor.grounded) else 0.0
	var sliding := bool(motor.grounded) and str(motor.move) == "slide"
	var k := clampf(Vector2(motor.velocity.x,motor.velocity.z).length()/12.0,0.0,1.0)
	_carve.goal = CARVE_SCRAPE*(0.4+0.6*k) if sliding or absf(carving) > 0.2 else 0.0
	_carve.pitch_goal = 0.8+0.35*k
	# A carve begun, or swung to the other side.
	if absf(carving) > 0.2 and (absf(_carving_was) <= 0.2 or signf(carving) != signf(_carving_was)):
		shot("swish",CARVE_SWISH*(0.5+0.5*k),_rng.randf_range(0.8,0.95))
		if k > 0.6: shot("whoosh",0.08*k,0.75)
	_carving_was = carving
