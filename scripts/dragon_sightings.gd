extends Node3D
## The dragon in the lightning (a prototype; docs/design/sky-weather/
## spec-storm-dragon.md, part 4). Made by scripts/plane_weather.gd
## (`sightings`), stepped from its `step`. In a storm the dragon is out
## there and only met in flashes. A sighting:
##   heard    first a sound from where it is: far, a long low call, muffled
##            (the bus's low-pass closes with distance) and quiet; close, the
##            whump of its downstrokes and the rustle of its wings, every
##            BEAT s. Each sound is made where the dragon is and heard the
##            distance over SOUND_SPEED later, so a far one's call after the
##            flash lags the sight. `heard` is signalled.
##   flash    HERALD s after it is heard, lightning (scripts/plane_lightning.gd
##            `strike_over`) behind it from the eye: far, a bolt or a cloud
##            flash a few hundred m past it; close, a flash in the murk past
##            it. While a flash lights it (`lit`, off the lightning's
##            `flash`), it is seen; `sighted` is signalled at the first.
##   again    AGAIN of them get a second flash AGAIN_GAP s later; GONE of
##            those show it gone (the sky lit, the dragon not there).
## It glides on all along (`place`, `velocity`): far, across the view
## FAR_SPEED m/s, FAR_RANGE m off, mostly where the camera looks; close,
## tens of m off the wing or over the canopy, sliding past the plane.
##
## The event (`sighted`, also kept in `last`): {id, near ("far"/"close"),
## place (Vector3), distance (m), time (s since the weather began)}. No
## contact, no damage: a later round hangs off the signal.
##
## On their own (`step`): in a storm past FROM, at a mean of one every EVERY
## s in a full storm; a cell's or the front's core (their `storm_at` past
## CORE) and the murk (`murk`, 0 to 1: the hook whiteouts set each frame)
## make them MORE times as likely at full, and close ones likelier
## (CLOSE_SHARE). `call_now("far" / "close")` starts one now (K, Shift+K in
## studies/sky_weather_field.gd).
##
## Drawn (scripts/dragon_glimpse.gd, `glimpse`): the rim dragon posed in
## a glide at `place`, facing its `velocity`, only while `lit` > 0.
##
## Flags:
##   --sighting-at=<frames>    one sighting that many frames in, and none on
##                             their own (with --sighting-kind=far|close)
##   --sighting-every=<s>      the mean wait in a full storm (0: none on
##                             their own)
##   --murk=<x>                the murk pinned (0 to 1) until whiteouts set it
##   --sighting-log            a line per heard, flash, sighted, end
##   --sighting-hold           a sighting never ends (with --strike-hold,
##                             for stills)
signal heard(event: Dictionary)
signal sighted(event: Dictionary)

const FROM := 0.5
const EVERY := 90.0
const CORE := 0.85
const MORE := 2.5
const CLOSE_SHARE := Vector2(0.12,0.75)
## Far: range (m), its height over the eye (m), its glide (m/s), how far
## across the view's half it may be (share), and how far behind it the
## flash is (m).
const FAR_RANGE := Vector2(320.0,820.0)
const FAR_UP := Vector2(-30.0,90.0)
const FAR_SPEED := Vector2(20.0,30.0)
const FAR_IN_VIEW := 0.7
const FAR_BEHIND := Vector2(120.0,360.0)
## Close: off the wing (m to the side, ahead or behind), over the canopy
## (m up), how fast it slides past the plane (m/s), how far behind it the
## flash is (m).
const WING_OFF := Vector2(24.0,48.0)
const CANOPY_UP := Vector2(14.0,26.0)
const CANOPY_SHARE := 0.4
const SLIDE := Vector2(9.0,16.0)
const CLOSE_BEHIND := Vector2(50.0,130.0)
## Heard to the first flash (s); a second flash's chance and gap (s); the
## chance it is gone in it; the lightning's flash that shows it.
const HERALD := Vector2(1.2,3.0)
const AGAIN := 0.55
const AGAIN_GAP := Vector2(0.45,1.3)
const GONE := 0.35
const SEEN := Vector2(0.06,0.3)
## How long past its last flash a sighting lasts (s).
const AFTER := 1.5
## The sound: the pace (m/s, plane_lightning's), the call's gain far and
## at FAR_RANGE.y, a beat's period (s) and gain, the wings' rustle's gain,
## the low-pass's cutoff near and far (Hz, closing by CUT_NEAR..CUT_FAR m).
const SOUND_SPEED := 240.0
const CALL := Vector2(0.7,0.35)
const BEAT := 1.25
const BEAT_GAIN := 0.95
const RUSTLE := 0.5
const CUT := Vector2(5200.0,600.0)
const CUT_RANGE := Vector2(30.0,450.0)
const KIT := "res://assets/audio/kit/"
const BUS := &"DragonSighting"

## The murk (0 to 1): whiteouts set it each frame; `--murk=` pins it.
var murk := 0.0
var murk_pinned := NAN
## The sighting under way ({} none): see `_begin`.
var now := {}
## Where it is, its glide, and how lit it is now (0: not seen).
var place := Vector3.ZERO
var velocity := Vector3.ZERO
var lit := 0.0
## The last sighted event ({} none), and how many there have been.
var last := {}
var count := 0
var clock := 0.0
var every := EVERY
var log_on := false
var hold := false
## The dragon as it is seen.
var glimpse: Node3D
var _weather: Node3D
var _scene: Node3D
var _rng := RandomNumberGenerator.new()
var _at_frame := -1
var _at_kind := "far"
var _frames := 0
var _clips := {}
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0
var _cut: AudioEffectLowPassFilter

func setup(scene: Node3D, weather: Node3D) -> void:
	name = "DragonSightings"
	_scene = scene
	_weather = weather
	_rng.randomize()
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--sighting-at="): _at_frame = int(arg.get_slice("=",1))
		elif arg.begins_with("--sighting-kind="): _at_kind = arg.get_slice("=",1)
		elif arg.begins_with("--sighting-every="): every = float(arg.get_slice("=",1))
		elif arg.begins_with("--murk="): murk_pinned = clampf(float(arg.get_slice("=",1)),0.0,1.0)
		elif arg == "--sighting-log": log_on = true
		elif arg == "--sighting-hold": hold = true
	_clips = {"call":_takes("dragon-call-%d.wav",3),"beat":_takes("dragon-beat-%d.wav",4),"rustle":_takes("wings-%d.wav",4)}
	_bus()
	for i in range(6):
		var voice := AudioStreamPlayer3D.new()
		voice.top_level = true
		# Its own gain and muffling (the bus's), only its side from the 3D.
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		voice.max_distance = 0.0
		voice.panning_strength = 0.7
		voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		voice.bus = BUS
		add_child(voice)
		_voices.append(voice)
	glimpse = preload("res://scripts/dragon_glimpse.gd").new()
	add_child(glimpse)

static func _takes(pattern: String, n: int) -> Array:
	var out := []
	for i in range(n): out.append(load(KIT+pattern % (i+1)))
	return out

## Its bus: a low-pass (set by distance per sighting) into the dragon's far
## bus (scripts/kit_isle/kit_audio_beasts.gd: a long reverb) where there is
## one, else SFX, else Master.
func _bus() -> void:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count-1
		AudioServer.set_bus_name(index,BUS)
		_cut = AudioEffectLowPassFilter.new()
		_cut.db = AudioEffectFilter.FILTER_24DB
		AudioServer.add_bus_effect(index,_cut)
	else:
		_cut = AudioServer.get_bus_effect(AudioServer.get_bus_index(BUS),0)
	var into := &"Master"
	for name_: StringName in [&"SFX Far",&"SFX"]:
		if AudioServer.get_bus_index(name_) >= 0:
			into = name_
			break
	AudioServer.set_bus_send(AudioServer.get_bus_index(BUS),into)

func _exit_tree() -> void:
	var index := AudioServer.get_bus_index(BUS)
	if index >= 0: AudioServer.remove_bus(index)

## The eye: the camera drawing the view (a driver's own, for stills), else
## the study's.
func _eye() -> Camera3D:
	var seen := get_viewport().get_camera_3d() if is_inside_tree() else null
	return seen if seen != null else _scene.get("camera")

func _log(text: String) -> void:
	if log_on: print("sighting: %s" % text)

## A sighting now, "far" or "close" (false if one is under way or there is
## no eye).
func call_now(near := "far") -> bool:
	if not now.is_empty() or _eye() == null: return false
	_begin(near)
	return true

func step(delta: float) -> void:
	clock += delta
	_frames += 1
	if not is_nan(murk_pinned): murk = murk_pinned
	if _at_frame >= 0:
		if _frames == _at_frame: call_now(_at_kind)
	elif now.is_empty() and every > 0.0:
		var storm: float = _weather.storm
		if storm >= FROM:
			var core := smoothstep(CORE,1.0,_core())
			var deep := maxf(core,murk)
			var rate := smoothstep(FROM,1.0,storm)/every*(1.0+MORE*deep)
			if _rng.randf() < rate*delta:
				_begin("close" if _rng.randf() < lerpf(CLOSE_SHARE.x,CLOSE_SHARE.y,deep) else "far")
	if now.is_empty(): lit = 0.0
	else: _advance(delta)
	glimpse.show_at(place,velocity,lit,delta)

## The storm of the cell's or the front's core where the plane is.
func _core() -> float:
	var p: Vector3 = _weather.probe()
	return maxf(_weather.front.storm_at(p),_weather.cells.storm_at(p))

func _plane_velocity() -> Vector3:
	if _scene.get("flying") and _scene.get("plane") != null: return _scene.plane.velocity
	return Vector3.ZERO

func _begin(near: String) -> void:
	var camera := _eye()
	var eye := camera.global_position
	var forward := -camera.global_basis.z
	var flat := Vector3(forward.x,0.0,forward.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var right := flat.cross(Vector3.UP)
	var moving := _plane_velocity()
	if near == "close":
		if _rng.randf() < CANOPY_SHARE:
			# Over the canopy, crossing it.
			place = eye+Vector3.UP*_rng.randf_range(CANOPY_UP.x,CANOPY_UP.y)+flat*_rng.randf_range(-6.0,22.0)
			var across := right*(1.0 if _rng.randf() < 0.5 else -1.0)
			place -= across*_rng.randf_range(20.0,32.0)
			velocity = moving+(across*1.6+flat*_rng.randf_range(-0.4,0.4)).normalized()*_rng.randf_range(SLIDE.x,SLIDE.y)*1.6
		else:
			# Off the wing, sliding past along it.
			var side := right*(1.0 if _rng.randf() < 0.5 else -1.0)
			var ahead := 1.0 if _rng.randf() < 0.5 else -1.0
			place = eye+side*_rng.randf_range(WING_OFF.x,WING_OFF.y)+flat*ahead*_rng.randf_range(18.0,34.0)+Vector3.UP*_rng.randf_range(-8.0,10.0)
			velocity = moving-flat*ahead*_rng.randf_range(SLIDE.x,SLIDE.y)
	else:
		var half := atan(tan(deg_to_rad(camera.fov)*0.5)*_aspect())
		var yaw := atan2(flat.z,flat.x)+_rng.randf_range(-half,half)*FAR_IN_VIEW
		var way := Vector3(cos(yaw),0.0,sin(yaw))
		place = eye+way*_rng.randf_range(FAR_RANGE.x,FAR_RANGE.y)
		place.y = eye.y+_rng.randf_range(FAR_UP.x,FAR_UP.y)
		# Across the line of sight, a little toward or away.
		var across := way.cross(Vector3.UP)*(1.0 if _rng.randf() < 0.5 else -1.0)
		velocity = (across+way*_rng.randf_range(-0.35,0.35)).normalized()*_rng.randf_range(FAR_SPEED.x,FAR_SPEED.y)
	var distance := eye.distance_to(place)
	var flashes: Array = [_rng.randf_range(HERALD.x,HERALD.y)]
	if _rng.randf() < AGAIN: flashes.append(float(flashes[0])+_rng.randf_range(AGAIN_GAP.x,AGAIN_GAP.y))
	now = {"id":count+1,"near":near,"t":0.0,"flashes":flashes,"struck":0,"gone":false,
		"sounds":[],"distance":distance,"sighted":false}
	_cut.cutoff_hz = lerpf(CUT.x,CUT.y,smoothstep(CUT_RANGE.x,CUT_RANGE.y,distance))
	_sounds(near,distance,flashes)
	var event := {"id":now.id,"near":near,"place":place,"distance":distance,"time":clock}
	_log("heard %s %.0f m off at %s" % [near,distance,place.round()])
	heard.emit(event)

func _aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	return size.x/maxf(size.y,1.0)

## The sighting's sounds, each [heard at (s into it), kind, gain, pitch]:
## the first is heard now; the rest are made later where it is then and
## heard the distance over SOUND_SPEED after.
func _sounds(near: String, distance: float, flashes: Array) -> void:
	var lag := distance/SOUND_SPEED
	var sounds: Array = now.sounds
	var end: float = flashes[-1]
	if near == "far":
		var gain := lerpf(CALL.x,CALL.y,smoothstep(FAR_RANGE.x,FAR_RANGE.y,distance))
		sounds.append([0.0,"call",gain,_rng.randf_range(0.82,0.95)])
		# Now and then a second, fainter call, made as the flash comes.
		if _rng.randf() < 0.4: sounds.append([float(flashes[0])+lag,"call",gain*0.6,_rng.randf_range(0.78,0.9)])
	else:
		# Its wings: a downstroke every BEAT, from the first heard through
		# the last flash.
		var t := 0.0
		while t < end+BEAT:
			var heard_at := t if t == 0.0 else t+lag
			sounds.append([heard_at,"beat",BEAT_GAIN*_rng.randf_range(0.85,1.0),_rng.randf_range(0.75,0.85)])
			sounds.append([heard_at+BEAT*0.55,"rustle",RUSTLE,_rng.randf_range(0.6,0.75)])
			t += BEAT*_rng.randf_range(0.92,1.08)
		if _rng.randf() < 0.5: sounds.append([float(flashes[0])*0.5,"call",CALL.x*0.5,_rng.randf_range(0.7,0.8)])
	sounds.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _advance(delta: float) -> void:
	now.t += delta
	var t: float = now.t
	place += velocity*delta
	var sounds: Array = now.sounds
	while not sounds.is_empty() and float(sounds[0][0]) <= t:
		var s: Array = sounds.pop_front()
		_play(str(s[1]),float(s[2]),float(s[3]))
	for voice in _voices:
		if voice.playing: voice.global_position = place
	var flashes: Array = now.flashes
	if int(now.struck) < flashes.size() and t >= float(flashes[now.struck]):
		_flash(int(now.struck))
		now.struck += 1
	var shown := int(now.struck) > 0 and not bool(now.gone)
	var light: float = _weather.lightning.flash
	lit = smoothstep(SEEN.x,SEEN.y,light) if shown else 0.0
	if shown and lit > 0.0 and not bool(now.sighted):
		now.sighted = true
		count += 1
		var eye := _eye().global_position if _eye() != null else place
		last = {"id":now.id,"near":now.near,"place":place,"distance":eye.distance_to(place),"time":clock}
		_log("sighted %s %.0f m off at %s, t %.1f" % [now.near,float(last.distance),place.round(),clock])
		sighted.emit(last)
	if t > float(flashes[-1])+AFTER and sounds.is_empty() and not hold:
		_log("end %d" % int(now.id))
		now = {}
		lit = 0.0

## Lightning behind it from the eye, to light it; the second flash may show
## it gone.
func _flash(k: int) -> void:
	if k > 0 and _rng.randf() < GONE: now.gone = true
	var camera := _eye()
	if camera == null: return
	var eye := camera.global_position
	var away := Vector3(place.x-eye.x,0.0,place.z-eye.z)
	away = away.normalized() if away.length() > 0.5 else -camera.global_basis.z
	var lightning: Node3D = _weather.lightning
	if str(now.near) == "far":
		var ground := place+away*_rng.randf_range(FAR_BEHIND.x,FAR_BEHIND.y)+away.cross(Vector3.UP)*_rng.randf_range(-80.0,80.0)
		if _rng.randf() < 0.55: lightning.strike_over(ground,"bolt",place.y+_rng.randf_range(90.0,180.0),lightning.SEA_TOP)
		else: lightning.strike_over(ground,"inside",place.y-170.0,lightning.SEA_TOP)
	else:
		var ground := place+away*_rng.randf_range(CLOSE_BEHIND.x,CLOSE_BEHIND.y)
		lightning.strike_over(ground,"inside",place.y-120.0,lightning.SEA_TOP)
	_log("flash %d%s, %.0f m off" % [k+1," (gone)" if bool(now.gone) else "",eye.distance_to(place)])

func _play(kind: String, gain: float, pitch: float) -> void:
	var takes: Array = _clips.get(kind,[])
	if takes.is_empty(): return
	var voice := _voices[_next_voice]
	for v in _voices:
		if not v.playing:
			voice = v
			break
	_next_voice = (_next_voice+1)%_voices.size()
	voice.global_position = place
	voice.stream = takes[_rng.randi_range(0,takes.size()-1)]
	voice.volume_db = linear_to_db(maxf(gain,0.0001))
	voice.pitch_scale = pitch
	voice.play()
	now.played = int(now.get("played",0))+1

## A line for the readout ("" none).
func describe() -> String:
	if not now.is_empty():
		var eye := _eye().global_position if _eye() != null else place
		var d := eye.distance_to(place)
		if int(now.struck) == 0: return "Dragon heard (%s, %d m)" % [now.near,roundi(d)]
		return "Dragon %s (%s, %d m)" % ["gone" if bool(now.gone) else ("seen" if lit > 0.0 else "in the dark"),now.near,roundi(d)]
	if not last.is_empty() and clock-float(last.time) < 6.0: return "Dragon sighted (%s, %d m)  %d so far" % [last.near,roundi(float(last.distance)),count]
	return ""
