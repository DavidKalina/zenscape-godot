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
##            `strike_over`, `flash_inside`) behind it from the eye: far, a
##            bolt or a cloud flash a few hundred m past it; close (and far
##            in a whiteout, where it comes nearer), a flash inside the murk
##            or cloud right behind it on the line from the eye, so the murk
##            blooms round it and it stands as a silhouette. While a flash lights it (`lit`, off the lightning's
##            `flash`), it is seen; `sighted` is signalled at the first.
##   again    AGAIN of them get a second flash AGAIN_GAP s later; GONE of
##            those show it gone (the sky lit, the dragon not there).
##   strobe   (off unless --strobe=on; the spec's "The strobe") the light
##            comes instead as 3 to 5 short pulses (`_strobe`), each lit
##            PULSE_LIT s, dark PULSE_DARK s between, a flash right behind
##            it each (one stroke, falling off so it is dark by the pulse's
##            end); it is seen only in a pulse, and moves and poses in the
##            dark. A close "away" or "over" takes its pulses on the head
##            turn's beats (TURN_PULSES: the wind-up, the snap into the look,
##            the hold with the jaw open, the turn back); the others' come at
##            random. The last shows the murk empty where it was, or now and
##            then (NEARER) it nearer; a far one's last may show it still
##            there. The pulses make no thunder of their own: one thunder,
##            and now and then a growl, lands in a dark gap.
## It glides on all along (`place`, `velocity`), staged along the plane's
## line, never across the view (`_pick`, `_begin`): close, "away" (ahead,
## flying on with the plane and pulling away, seen from behind), "over"
## (right above, overtaking it: belly, spread wings, claws) or "under" (a
## little below and ahead, back and wings from above, sinking); far, going
## away with the plane or coming at it, FAR_RANGE m off where the camera
## looks. Close ones never come round the eye (the glimpse keeps them clear
## and pushes `place`).
##
## The event (`sighted`, also kept in `last`): {id, near ("far"/"close"),
## stage (see `_pick`), place (Vector3), distance (m), time (s since the weather began)}. No
## contact, no damage: a later round hangs off the signal.
##
## On their own (`step`): in a storm past FROM, at a mean of one every EVERY
## s in a full storm; a cell's or the front's core (their `storm_at` past
## CORE) and the murk (`murk`, 0 to 1: the hook whiteouts set each frame)
## make them MORE times as likely at full (the murk MURK_MORE on top), and
## close ones likelier (CLOSE_SHARE); past EVERY s of storm without one they
## grow likelier still (DUE). After one ends none comes on its own for REST s, so they
## stay rare even deep in a cell. `call_now("far" / "close")` starts one now (K, Shift+K in
## studies/sky_weather_field.gd).
##
## Drawn (scripts/dragon_glimpse.gd, `glimpse`): the rim dragon posed in
## a glide at `place`, facing its `velocity`, only while `lit` > 0.
##
## Flags:
##   --sighting-at=<frames>    one sighting that many frames in, and none on
##                             their own (with --sighting-kind=far|close)
##   --sighting-stage=<s>      every sighting staged so: close away|over|
##                             under, far away|toward
##   --sighting-every=<s>      the mean wait in a full storm (0: none on
##                             their own)
##   --murk=<x>                the murk pinned (0 to 1) until whiteouts set it
##   --sighting-log            a line per heard, flash, sighted, end
##   --sighting-hold           a sighting never ends (with --strike-hold,
##                             for stills)
##   --strobe=on|off           the strobe on, or off (the default: the user
##                             found its pulses read as glitching)
##                             (the one or two flashes, to judge against)
signal heard(event: Dictionary)
signal sighted(event: Dictionary)

const FROM := 0.5
const EVERY := 60.0
const CORE := 0.85
const MORE := 1.5
## The murk (a whiteout) makes them MURK_MORE times more likely again at
## full: a whiteout is where a close one is likeliest.
const MURK_MORE := 4.0
## The longer a storm goes without one (storm-weighted s since the last
## ended, past EVERY), the likelier: DUE more per EVERY s overdue, so the
## sky is never long empty in a storm.
const DUE := 2.0
const REST := 35.0
const CLOSE_SHARE := Vector2(0.12,0.75)
## Far: range (m), its height over the eye (m), its glide along the line
## of sight (m/s, off the plane's), how far across the view's half it may
## be (share), and how far behind it the flash is (m).
const FAR_RANGE := Vector2(320.0,820.0)
const FAR_UP := Vector2(-30.0,90.0)
const FAR_SPEED := Vector2(20.0,30.0)
const FAR_IN_VIEW := 0.6
## Far: where in the view (share of its half height), and the chance it
## comes at the plane (else it flies on away, with it).
const FAR_VIEW := Vector2(-0.2,0.5)
const FAR_TOWARD := 0.3
const FAR_BEHIND := Vector2(120.0,360.0)
## In a whiteout's murk a far one is nearer (at full murk; m), or the murk
## would hide it wholly, and its height over the eye less (m); its flash is
## inside the murk right behind it from the eye, MURK_BEHIND m past it.
const MURK_RANGE := Vector2(110.0,200.0)
const MURK_UP := Vector2(-15.0,35.0)
const MURK_BEHIND := Vector2(60.0,140.0)
## Staged along the plane's line, never across it (the spec's "How it is
## staged"). Close (its root as the first flash shows it; its wings reach
## ~68 m each side, its neck and head ~70 m ahead, its tail ~110 m behind),
## per stage: how far off (m), where in the view (share of its half height
## up, of its half width either side), how fast it pulls ahead of the plane
## (m/s); under, at least `aside` of the half width off the middle. The
## shares of away and over (the rest under).
const CLOSE_STAGES := {
	"away": {"range":Vector2(115.0,150.0),"view":Vector2(0.0,0.4),"across":0.25,"slide":Vector2(3.0,7.0)},
	"over": {"range":Vector2(55.0,110.0),"view":Vector2(0.5,0.75),"across":0.15,"slide":Vector2(6.0,12.0)},
	"under": {"range":Vector2(100.0,150.0),"view":Vector2(-0.8,-0.45),"across":0.55,"aside":0.3,"slide":Vector2(3.0,7.0)},
}
const CLOSE_SHARES := Vector2(0.45,0.3)
## Away: at most this far over or under the eye (m); over: this far over
## the view's line (m), and at least OVER_LEAST m over the eye; under: this far down (m), sinking (m/s); and every one at
## least GROUND_CLEAR m over the ground.
const AWAY_UP := 40.0
const OVER_UP := Vector2(28.0,42.0)
const OVER_LEAST := 18.0
const UNDER_DOWN := Vector2(25.0,45.0)
const SINK := Vector2(1.0,3.0)
const GROUND_CLEAR := 30.0
const CLOSE_BEHIND := Vector2(50.0,130.0)
## A close one's flash a little over its line from the eye (m), so its back
## and wings stand against the bloom's core.
const CLOSE_LIFT := Vector2(0.0,20.0)
## Heard to the first flash (s); a second flash's chance and gap (s); the
## chance it is gone in it; the lightning's flash that shows it.
const HERALD := Vector2(1.2,3.0)
const AGAIN := 0.55
const AGAIN_GAP := Vector2(0.45,1.3)
const GONE := 0.35
const SEEN := Vector2(0.06,0.3)
## The strobe: how many pulses (a far or under one's), each one lit (s)
## and dark between (s); a close away/over's at the head turn's beats (s
## from the snap, scripts/dragon_glimpse.gd BEATS: wind-up, snap, hold,
## turn back), give or take TURN_JITTER, the wind-up skipped SKIP_WINDUP
## of the time, and its last (empty) pulse EMPTY_AT s from the snap. The
## last shows it nearer (close; NEARER_BY of the way to the eye, at least
## NEARER_LEAST m off) NEARER of the time, else empty; a far one's last
## empty FAR_EMPTY of the time. A growl in a dark gap GROWL of the time.
const PULSES := Vector2i(3,5)
const PULSE_LIT := Vector2(0.07,0.12)
const PULSE_DARK := Vector2(0.15,0.4)
const TURN_PULSES := [-0.27,0.02,0.5,0.98]
const TURN_JITTER := 0.015
const SKIP_WINDUP := 0.25
const EMPTY_AT := Vector2(1.32,1.42)
const NEARER := 0.25
const NEARER_BY := Vector2(0.3,0.45)
const NEARER_LEAST := 40.0
const FAR_EMPTY := 0.5
const GROWL := 0.5
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
## The strobe (`--strobe=on`; off: the one or two flashes).
var strobe := false
## The dragon as it is seen.
var glimpse: Node3D
var _weather: Node3D
var _scene: Node3D
var _rng := RandomNumberGenerator.new()
var _at_frame := -1
var _at_kind := "far"
## A stage forced for every sighting (`--sighting-stage=`; "" picked).
var staged := ""
var _frames := 0
var _rest := 0.0
## Storm-weighted s since the last sighting ended (for DUE).
var _dry := 0.0
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
		elif arg.begins_with("--sighting-stage="): staged = arg.get_slice("=",1)
		elif arg.begins_with("--sighting-every="): every = float(arg.get_slice("=",1))
		elif arg.begins_with("--murk="): murk_pinned = clampf(float(arg.get_slice("=",1)),0.0,1.0)
		elif arg == "--sighting-log": log_on = true
		elif arg == "--sighting-hold": hold = true
		elif arg.begins_with("--strobe="): strobe = arg.get_slice("=",1) == "on"
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
func call_now(near := "far", stage := "") -> bool:
	if not now.is_empty() or _eye() == null: return false
	_begin(near,stage)
	return true

func step(delta: float) -> void:
	clock += delta
	_frames += 1
	if not is_nan(murk_pinned): murk = murk_pinned
	if _at_frame >= 0:
		if _frames == _at_frame: call_now(_at_kind)
	elif now.is_empty() and every > 0.0 and _rest > 0.0: _rest -= delta
	elif now.is_empty() and every > 0.0:
		# A whiteout is storm air even once the plane is out of the core
		# that dropped it (it outlives the core by seconds).
		var storm: float = maxf(_weather.storm,murk)
		if storm >= FROM:
			var core := smoothstep(CORE,1.0,_core())
			var deep := maxf(core,murk)
			var stormy := smoothstep(FROM,1.0,storm)
			_dry += stormy*delta
			var rate := stormy/every*(1.0+MORE*deep+MURK_MORE*murk)*(1.0+DUE*maxf(_dry-every,0.0)/every)
			if _rng.randf() < rate*delta:
				_begin("close" if _rng.randf() < lerpf(CLOSE_SHARE.x,CLOSE_SHARE.y,deep) else "far")
	if now.is_empty(): lit = 0.0
	else: _advance(delta)
	glimpse.murk = murk
	# The look's clock: s since the first flash (the head is round by it).
	glimpse.stage = "" if now.is_empty() else str(now.stage)
	glimpse.beat = -INF if now.is_empty() else float(now.t)-float(now.flashes[0])-float(now.zero)
	var close := not now.is_empty() and str(now.near) == "close"
	var eye := _eye()
	if close and eye != null: place += glimpse.show_at(place,velocity,lit,delta,eye.global_position,1.0)
	else: glimpse.show_at(place,velocity,lit,delta)

## The storm of the cell's or the front's core where the plane is.
func _core() -> float:
	var p: Vector3 = _weather.probe()
	return maxf(_weather.front.storm_at(p),_weather.cells.storm_at(p))

func _plane_velocity() -> Vector3:
	if _scene.get("flying") and _scene.get("plane") != null: return _scene.plane.velocity
	return Vector3.ZERO

func _begin(near: String, stage := "") -> void:
	var camera := _eye()
	var eye := camera.global_position
	var forward := -camera.global_basis.z
	var flat := Vector3(forward.x,0.0,forward.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var moving := _plane_velocity()
	# With the plane: its speed along the view, so the dragon's heading is
	# the camera's (never across it).
	var base := flat*maxf(moving.dot(flat),0.0)+Vector3.UP*moving.y
	var flashes: Array = [_rng.randf_range(HERALD.x,HERALD.y)]
	if _rng.randf() < AGAIN: flashes.append(float(flashes[0])+_rng.randf_range(AGAIN_GAP.x,AGAIN_GAP.y))
	var herald: float = flashes[0]
	if stage == "": stage = staged
	if not (CLOSE_STAGES.has(stage) if near == "close" else stage in ["away","toward"]): stage = _pick(near)
	# The look's clock starts at the first flash; a strobe's at its snap.
	var light := {"flashes":flashes,"lens":[],"zero":herald,"last":""}
	if strobe:
		light = _strobe(near,stage,herald)
		flashes = light.flashes
	var half_v := deg_to_rad(camera.fov)*0.5
	var half_h := atan(tan(half_v)*_aspect())
	var ground := _ground_below(eye)
	if stage == "under" and eye.y-ground < UNDER_DOWN.x+GROUND_CLEAR: stage = "away"
	var slide := Vector3.ZERO
	if near == "close":
		var st: Dictionary = CLOSE_STAGES[stage]
		# Under sits off to one side (`aside`, a share of the half width), so
		# the plane is not drawn over its neck.
		var across := (1.0 if _rng.randf() < 0.5 else -1.0)*_rng.randf_range(float(st.get("aside",0.0)),float(st.across))*half_h
		var up := _rng.randf_range(float(st.view.x),float(st.view.y))*half_v
		place = _in_view(camera,across,up,_rng.randf_range(float(st.range.x),float(st.range.y)))
		if stage == "over":
			# OVER_UP m over the view's line, as far out as puts it that high
			# in the view's top: belly and spread wings across the top.
			var depth := clampf(_rng.randf_range(OVER_UP.x,OVER_UP.y)/tan(up),float(st.range.x),float(st.range.y))
			place = camera.global_position+camera.global_basis*Vector3(tan(across)*depth,tan(up)*depth,-depth)
			place.y = maxf(place.y,eye.y+OVER_LEAST)
		elif stage == "under": place.y = eye.y-_rng.randf_range(UNDER_DOWN.x,UNDER_DOWN.y)
		else: place.y = clampf(place.y,eye.y-AWAY_UP,eye.y+AWAY_UP)
		slide = flat*_rng.randf_range(float(st.slide.x),float(st.slide.y))
		if stage == "under": slide += Vector3.DOWN*_rng.randf_range(SINK.x,SINK.y)
	else:
		var k := clampf(murk,0.0,1.0)
		var span := FAR_RANGE.lerp(MURK_RANGE,k)
		var range_ := _rng.randf_range(span.x,span.y)
		if stage == "toward": range_ = maxf(range_,lerpf(span.x,span.y,0.6))
		place = _in_view(camera,_rng.randf_range(-1.0,1.0)*FAR_IN_VIEW*half_h,_rng.randf_range(FAR_VIEW.x,FAR_VIEW.y)*half_v,range_)
		var up := FAR_UP.lerp(MURK_UP,k)
		place.y = clampf(place.y,eye.y+up.x,eye.y+up.y)
		# Along the line of sight: going away with the plane, or coming at it.
		var way := Vector3(place.x-eye.x,0.0,place.z-eye.z).normalized()
		var speed := _rng.randf_range(FAR_SPEED.x,FAR_SPEED.y)
		slide = way*speed if stage == "away" else -way*speed-base
	place.y = maxf(place.y,_ground_below(place)+GROUND_CLEAR)
	velocity = base+slide
	# Back along its own way from the plane to where it is heard, so the
	# first flash finds it where it was staged.
	place -= slide*herald
	var distance := eye.distance_to(place)
	now = {"id":count+1,"near":near,"t":0.0,"flashes":flashes,"struck":0,"gone":false,
		"sounds":[],"distance":distance,"sighted":false,"stage":stage,
		"lens":light.lens,"zero":float(light.zero)-float(flashes[0]),"last":light.last}
	_cut.cutoff_hz = lerpf(CUT.x,CUT.y,smoothstep(CUT_RANGE.x,CUT_RANGE.y,distance))
	_sounds(near,distance,flashes)
	if strobe: _gap_sounds(near)
	var event := {"id":now.id,"near":near,"stage":stage,"place":place,"distance":distance,"time":clock}
	_log("heard %s %s %.0f m off at %s" % [near,stage,distance,place.round()])
	heard.emit(event)

## The strobe's pulses from `herald` s in: {flashes (s into the sighting),
## lens (s lit each), zero (the look's clock's start, s), last ("empty",
## "nearer" or "": what the last pulse shows)}.
func _strobe(near: String, stage: String, herald: float) -> Dictionary:
	var flashes: Array = []
	var zero := herald
	if near == "close" and stage in ["away","over"]:
		var beats: Array = TURN_PULSES.duplicate()
		if _rng.randf() < SKIP_WINDUP: beats.pop_front()
		zero = herald-float(beats[0])
		for b in beats:
			# The snap's exact (the look's turned by it); the rest a little loose.
			var jitter := 0.0 if absf(float(b)-TURN_PULSES[1]) < 0.001 else _rng.randf_range(-TURN_JITTER,TURN_JITTER)
			flashes.append(zero+float(b)+jitter)
		flashes.append(zero+_rng.randf_range(EMPTY_AT.x,EMPTY_AT.y))
	else:
		var t := herald
		for i in range(_rng.randi_range(PULSES.x,PULSES.y)):
			flashes.append(t)
			t += _rng.randf_range(PULSE_LIT.x,PULSE_LIT.y)+_rng.randf_range(PULSE_DARK.x,PULSE_DARK.y)
	var lens: Array = []
	for i in range(flashes.size()): lens.append(_rng.randf_range(PULSE_LIT.x,PULSE_LIT.y))
	# Never less dark between than PULSE_DARK.x: the pulse before cut short.
	for i in range(1,flashes.size()):
		lens[i-1] = clampf(float(flashes[i])-float(flashes[i-1])-PULSE_DARK.x,0.04,float(lens[i-1]))
	var last := ""
	if near == "close": last = "nearer" if _rng.randf() < NEARER else "empty"
	elif _rng.randf() < FAR_EMPTY: last = "empty"
	return {"flashes":flashes,"lens":lens,"zero":zero,"last":last}

## The strobe's thunder (and now and then a growl), heard in its dark gaps:
## the thunder in the gap after the snap (close away/over) or the first
## pulse, the growl in a later one.
func _gap_sounds(near: String) -> void:
	var flashes: Array = now.flashes
	var lens: Array = now.lens
	if flashes.size() < 2: return
	var gaps: Array = []
	for i in range(flashes.size()-1):
		var from := float(flashes[i])+float(lens[i])
		gaps.append(from+(float(flashes[i+1])-from)*_rng.randf_range(0.3,0.6))
	var first := 1 if near == "close" and str(now.stage) in ["away","over"] and flashes.size() >= 5 else 0
	var sounds: Array = now.sounds
	sounds.append([gaps[mini(first,gaps.size()-1)],"thunder",1.0,1.0])
	if gaps.size() > first+1 and _rng.randf() < GROWL:
		sounds.append([gaps[_rng.randi_range(first+1,gaps.size()-1)],"call",CALL.x*(0.7 if near == "close" else 0.45),_rng.randf_range(0.7,0.82)])
	sounds.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

## A stage for a sighting: close "away" (ahead, flying on away from the
## plane, seen from behind), "over" (right above, overtaking it: belly,
## wings and claws) or "under" (a little below and ahead: back and wings
## from above); far "away" or "toward" (coming at the plane).
func _pick(near: String) -> String:
	var r := _rng.randf()
	if near == "far": return "toward" if r < FAR_TOWARD else "away"
	return "away" if r < CLOSE_SHARES.x else ("over" if r < CLOSE_SHARES.x+CLOSE_SHARES.y else "under")

## The point `range_` m out from the camera, `across` rad right and `up`
## rad up of the view's middle.
static func _in_view(camera: Camera3D, across: float, up: float, range_: float) -> Vector3:
	var dir := (camera.global_basis*Vector3(tan(across),tan(up),-1.0)).normalized()
	return camera.global_position+dir*range_

## The ground's (or the sea's, an isle's) height under a point; -INF none.
func _ground_below(at: Vector3) -> float:
	if not is_inside_tree(): return -INF
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*600.0,at+Vector3.DOWN*2000.0))
	return (hit.position as Vector3).y if not hit.is_empty() else -INF

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
	# A strobe's only in a pulse: never by another strike in its dark.
	if shown and strobe and not (now.lens as Array).is_empty():
		var k := int(now.struck)-1
		shown = t < float(flashes[k])+float(now.lens[k])
	var light: float = _weather.lightning.flash
	lit = smoothstep(SEEN.x,SEEN.y,light) if shown else 0.0
	if shown and lit > 0.0 and not bool(now.sighted):
		now.sighted = true
		count += 1
		var eye := _eye().global_position if _eye() != null else place
		last = {"id":now.id,"near":now.near,"stage":now.stage,"place":place,"distance":eye.distance_to(place),"time":clock}
		_log("sighted %s %.0f m off at %s, t %.1f" % [now.near,float(last.distance),place.round(),clock])
		sighted.emit(last)
	if t > float(flashes[-1])+AFTER and sounds.is_empty() and not hold:
		_log("end %d" % int(now.id))
		now = {}
		lit = 0.0
		_rest = REST
		_dry = 0.0

## Lightning behind it from the eye, to light it; the second flash may show
## it gone.
func _flash(k: int) -> void:
	var pulsed := strobe and not (now.lens as Array).is_empty()
	var camera := _eye()
	if pulsed and k == (now.flashes as Array).size()-1:
		if str(now.last) == "empty": now.gone = true
		elif str(now.last) == "nearer" and camera != null:
			# Nearer: drawn in toward the eye along the line, in the dark.
			var eye_at := camera.global_position
			var off := place-eye_at
			var keep := maxf(off.length()*(1.0-_rng.randf_range(NEARER_BY.x,NEARER_BY.y)),NEARER_LEAST)
			place = eye_at+off.normalized()*minf(keep,off.length())
	elif not pulsed and k > 0 and _rng.randf() < GONE: now.gone = true
	if camera == null: return
	var eye := camera.global_position
	var lightning: Node3D = _weather.lightning
	if pulsed and str(now.near) == "close": _keep_in_view(camera,k)
	if pulsed:
		# One stroke, falling off to the dragon's SEEN.x by the pulse's end.
		lightning.pulse_decay = log(1.25/SEEN.x)/(float(now.lens[k])+0.02)
		lightning.quiet = true
	_flash_at(camera,eye)
	lightning.pulse_decay = 0.0
	lightning.quiet = false
	_log("flash %d%s, %.0f m off" % [k+1," (gone)" if bool(now.gone) else "",eye.distance_to(place)])

## A close strobe's dragon kept where the view is: if the camera has swung
## round (the plane turning) since the last pulse, it is swung round the eye
## with it, in the dark, so each pulse still finds it ahead.
func _keep_in_view(camera: Camera3D, k: int) -> void:
	var f := -camera.global_basis.z
	var yaw := atan2(f.x,f.z)
	if k > 0 and now.has("yaw"):
		var turn := wrapf(yaw-float(now.yaw),-PI,PI)
		var eye := camera.global_position
		place = eye+(place-eye).rotated(Vector3.UP,turn)
		velocity = velocity.rotated(Vector3.UP,turn)
	now.yaw = yaw

## The flash behind it from the eye.
func _flash_at(camera: Camera3D, eye: Vector3) -> void:
	var away := Vector3(place.x-eye.x,0.0,place.z-eye.z)
	away = away.normalized() if away.length() > 0.5 else -camera.global_basis.z
	var lightning: Node3D = _weather.lightning
	# Right behind it from the eye: the murk (or the cloud and the sky) blooms
	# round it and it stands black against the bloom.
	var line := (place-eye).normalized()
	if str(now.near) == "close":
		lightning.flash_inside(place+line*_rng.randf_range(CLOSE_BEHIND.x,CLOSE_BEHIND.y)+Vector3.UP*_rng.randf_range(CLOSE_LIFT.x,CLOSE_LIFT.y))
	elif murk > 0.5:
		lightning.flash_inside(place+line*_rng.randf_range(MURK_BEHIND.x,MURK_BEHIND.y))
	else:
		var ground := place+away*_rng.randf_range(FAR_BEHIND.x,FAR_BEHIND.y)+away.cross(Vector3.UP)*_rng.randf_range(-80.0,80.0)
		if _rng.randf() < 0.55: lightning.strike_over(ground,"bolt",place.y+_rng.randf_range(90.0,180.0),lightning.SEA_TOP)
		else: lightning.strike_over(ground,"inside",place.y-170.0,lightning.SEA_TOP)

func _play(kind: String, gain: float, pitch: float) -> void:
	if kind == "thunder":
		var eye := _eye()
		_weather.lightning.thunder_now(eye.global_position.distance_to(place)+100.0 if eye != null else 200.0)
		_log("thunder at t %.2f" % float(now.t))
		return
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
