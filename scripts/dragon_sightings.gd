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
## It glides on all along (`place`, `velocity`), staged along the plane's
## line, never across the view (`_pick`, `_begin`): close, "wing" (only a
## wing seen: the dragon WING.scale times its size crossing right over the
## plane side on, head and tail off past the view's sides, so its wing
## sweeps across the top of the view as a dark ceiling; likeliest in the
## murk, WING_SHARE of close ones there), "wing_low" (the same wing, the
## dragon crossing under the plane and off to one side (CROSS_LOW), sliding
## out away from its line: the wing beats in a sheet beside the plane, a
## wall rising up past it and dropping away under it, then it dives off),
## "chase" (the plane tailing it: it flies on ahead the same way, CHASE,
## seen from behind, wings beating, then pulls away ahead and climbs off),
## "stalk" (it comes in from an edge of the view, `edge`: left, right,
## below or above, over STALK_EMERGE s, settles there STALK_RANGE m off and
## stays with the plane, always there as a dark shape in the murk
## (STALK_SEEN), beating slowly, for STALK_STAY s; lightning flickers
## through it now and then (STALK_FLASH, some doubled), each flash showing it
## black, never taking it away; then it sinks back out the way it came over
## STALK_LEAVE s; `--stalk-edge=` picks the edge),
## "head" (as big, its body far off
## to one side and over the plane, overtaking it: its neck and head loom
## over the plane), both seen as a dark shape all the pass (WING_SEEN),
## harder in the flashes. The wing beats (`_wing_beat`), its downwash
## pressing the plane down on each downstroke (`downwash`); the head's gust
## shoves the plane WING_GUST s after the first flash; "away" (ahead,
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
## Wing: its scale (of the glimpse's own), how far its body is off to the
## side (m), how far over the eye (m), how far behind the plane it is at the
## first flash (m), how fast it overtakes (m/s); how lit it is all the pass
## (0 to 1), the gap to its second flash (s), how long past the last it
## stays (s), its gust's delay after the first flash (s), strength and
## length (s); its share of close ones in the murk (at full).
const WING := {"scale":3.0,"aside":Vector2(150.0,175.0),"up":Vector2(18.0,30.0),
	"behind":Vector2(-10.0,15.0),"overtake":Vector2(10.0,16.0)}
## Wing (crossing): its body at the first flash this far off the plane's
## line to the side it comes from (m), this far over the eye (m), this far
## ahead of the plane (m: behind it, so the body and legs pass over and
## behind the eye and only the forward wing reaches over the view),
## crossing at this speed (m/s), the plane's own way added so it keeps over
## it.
const CROSS := {"off":Vector2(0.0,15.0),"up":Vector2(16.0,22.0),"ahead":Vector2(-55.0,-45.0),"speed":Vector2(22.0,30.0)}
## Wing low: the same, under the plane (`up` negative), off to the side and
## ahead of it, farther than a wing's length (~200 m at this size), so its
## wings are seen whole and far off, not a wall; faint in the murk till lit,
## sliding out away from its line (`speed` m/s), so its wing beats beside
## the plane and never through it; it dives off (LEAVE_CLIMB down).
## Its wing's trailing edge (its chord ~60 m at this size) points in toward
## the plane, so `off` keeps that clear of it.
## Chase: off the plane's line to the side (m), over the eye (m), ahead of
## the plane at the first flash (m: past its tail's length, ~110 m at
## scale 1), how fast it gains on the plane (m/s), its scale.
const CHASE := {"off":Vector2(-15.0,15.0),"up":Vector2(5.0,20.0),"ahead":Vector2(240.0,280.0),"speed":Vector2(2.0,5.0),"scale":1.5}
## Stalk: how long it takes to come in, how long it stays, how long to go
## (s); how far off it settles (m) and its scale; where it settles per edge
## (across, up: shares of the view's half width and half height) and how
## far past the edge it starts (share); how lit it is all along (0 to 1);
## the gap between its flashes (s) and the chance one is doubled (and its
## gap, s); its beat (s).
const STALK_EMERGE := 3.5
const STALK_STAY := Vector2(10.0,20.0)
const STALK_LEAVE := 3.0
const STALK_RANGE := Vector2(200.0,240.0)
const STALK_SCALE := 1.5
const STALK_AT := {"left":Vector2(-0.55,0.1),"right":Vector2(0.55,0.1),"below":Vector2(0.15,-0.55),"above":Vector2(-0.1,0.55)}
const STALK_OUT := 1.5
const STALK_SEEN := 0.3
const STALK_FLASH := Vector2(2.0,4.5)
const STALK_DOUBLE := 0.35
const STALK_DOUBLE_GAP := 0.18
const STALK_BEAT := 1.9
const CROSS_LOW := {"off":Vector2(110.0,130.0),"up":Vector2(-45.0,-35.0),"ahead":Vector2(160.0,200.0),"speed":Vector2(6.0,10.0),"scale":1.5}
const WING_SEEN := 0.18
const WING_GAP := Vector2(1.3,1.9)
const WING_AFTER := 1.2
const WING_GUST := 0.6
const WING_GUST_K := 1.0
const WING_GUST_LENGTH := 2.5
const WING_SHARE := 0.5
## The wing pass's beat (s from the first flash): the wing lifts to the top
## over the RAISE s before LIFT, then beats every WING_BEAT s from LIFT, so
## the first flash lands at the bottom of its first stroke (LIFT is half a
## beat before it). After LEAVE s it
## leaves: over LEAVE_EASE s it turns ahead of the plane and climbs off
## (low: dives off out to its side)
## (LEAVE_AHEAD m/s on the plane's own, LEAVE_CLIMB m/s up, its crossing
## kept), whole again (legs and tail back), and its dark shape fades out
## over FADE s from LEAVE.
const WING_LIFT := -0.7
const WING_RAISE := 0.6
const WING_BEAT := 1.4
const WING_LEAVE := 0.5
const LEAVE_EASE := 1.2
const LEAVE_AHEAD := 22.0
const LEAVE_CLIMB := 12.0
const WING_FADE := Vector2(0.6,2.2)
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
## The way it faces when not its glide's (a crossing wing; zero: its glide).
var facing := Vector3.ZERO
## A wing pass's own numbers (CROSS's, drawn; {} none).
var _cross := {}
## A stalk's edge forced (`--stalk-edge=left|right|below|above`; "" picked).
var stalk_edge := ""
## A wing pass's downwash (scripts/dragon_downwash.gd, the aqueduct
## dragon's): its wings' air pressing the plane down under it, hard on each
## downstroke; read by plane_weather.gd `air_at` through `plane_air`.
var downwash := preload("res://scripts/dragon_downwash.gd").new()
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
		elif arg.begins_with("--stalk-edge="): stalk_edge = arg.get_slice("=",1)
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
	glimpse.beat = -INF if now.is_empty() else float(now.t)-float(now.flashes[0])
	var close := not now.is_empty() and str(now.near) == "close"
	var eye := _eye()
	var face := facing if facing != Vector3.ZERO else velocity
	if close and eye != null: place += glimpse.show_at(place,face,lit,delta,eye.global_position,1.0)
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
	var big := stage in ["wing","wing_low","chase","stalk","head"]
	if big: near = "close"
	if not ((CLOSE_STAGES.has(stage) or big) if near == "close" else stage in ["away","toward"]): stage = _pick(near)
	big = stage in ["wing","wing_low","chase","stalk","head"]
	if big:
		flashes = [flashes[0],float(flashes[0])+_rng.randf_range(WING_GAP.x,WING_GAP.y)]
	var half_v := deg_to_rad(camera.fov)*0.5
	var half_h := atan(tan(half_v)*_aspect())
	var ground := _ground_below(eye)
	if stage == "under" and eye.y-ground < UNDER_DOWN.x+GROUND_CLEAR: stage = "away"
	var slide := Vector3.ZERO
	var side := 0.0
	var right := flat.cross(Vector3.UP)
	var plane: Vector3 = _scene.plane.position if _scene.get("plane") != null else eye
	facing = Vector3.ZERO
	if stage == "stalk":
		var edges := STALK_AT.keys()
		var edge: String = stalk_edge if STALK_AT.has(stalk_edge) else str(edges[_rng.randi_range(0,edges.size()-1)])
		var stay := _rng.randf_range(STALK_STAY.x,STALK_STAY.y)
		# Flashes through its stay: the first as it comes in, then every
		# STALK_FLASH, some doubled.
		var fl: Array = []
		var ft := STALK_EMERGE*0.7
		while ft < STALK_EMERGE+stay:
			fl.append(ft)
			if _rng.randf() < STALK_DOUBLE: fl.append(ft+STALK_DOUBLE_GAP)
			ft += _rng.randf_range(STALK_FLASH.x,STALK_FLASH.y)
		flashes = fl
		_cross = {"edge":edge,"stay":stay,"range":_rng.randf_range(STALK_RANGE.x,STALK_RANGE.y),
			"jitter":Vector2(_rng.randf_range(-0.08,0.08),_rng.randf_range(-0.06,0.06))}
		facing = flat
	elif stage == "chase":
		side = 1.0
		var c: Dictionary = CHASE
		var cross := {"off":_rng.randf_range(c.off.x,c.off.y),"ahead":_rng.randf_range(c.ahead.x,c.ahead.y),
			"up":_rng.randf_range(c.up.x,c.up.y),"vel":_rng.randf_range(c.speed.x,c.speed.y)}
		_cross = cross
		place = plane+right*float(cross.off)+flat*float(cross.ahead)
		place.y = eye.y+float(cross.up)
		slide = flat*float(cross.vel)
		facing = flat
	elif stage in ["wing","wing_low"]:
		side = 1.0 if _rng.randf() < 0.5 else -1.0
		# Kept in the plane's frame until the first flash (`_keep_over`), so
		# a turn meanwhile doesn't carry the plane out from under it. `vel`:
		# its crossing along `side` (under 0: in toward the plane's line).
		var c: Dictionary = CROSS if stage == "wing" else CROSS_LOW
		var speed := _rng.randf_range(c.speed.x,c.speed.y)
		var cross := {"off":_rng.randf_range(c.off.x,c.off.y),"ahead":_rng.randf_range(c.ahead.x,c.ahead.y),
			"up":_rng.randf_range(c.up.x,c.up.y),"vel":-speed if stage == "wing" else speed}
		_cross = cross
		place = plane+right*side*float(cross.off)+flat*float(cross.ahead)
		place.y = eye.y+float(cross.up)
		slide = right*side*float(cross.vel)
		facing = slide
	elif stage == "head":
		# Its body off to one side of the plane and over it, a little behind
		# at the first flash, overtaking: the near wing reaches over the
		# plane's way and slides past overhead and beside.
		side = 1.0 if _rng.randf() < 0.5 else -1.0
		place = plane+right*side*_rng.randf_range(WING.aside.x,WING.aside.y)-flat*_rng.randf_range(WING.behind.x,WING.behind.y)
		place.y = eye.y+_rng.randf_range(WING.up.x,WING.up.y)
		slide = flat*_rng.randf_range(WING.overtake.x,WING.overtake.y)
	elif near == "close":
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
		"sounds":[],"distance":distance,"sighted":false,"stage":stage,"side":side,"gusted":false}
	var scale := STALK_SCALE if stage == "stalk" else float(CROSS_LOW.scale) if stage == "wing_low" else (float(CHASE.scale) if stage == "chase" else (float(WING.scale) if big else 1.0))
	glimpse.model.scale = Vector3.ONE*glimpse.SIZE*scale
	glimpse.only_wings = stage in ["wing","wing_low"]
	glimpse.lowest = glimpse.LOWEST if stage == "wing" else -INF
	_cut.cutoff_hz = lerpf(CUT.x,CUT.y,smoothstep(CUT_RANGE.x,CUT_RANGE.y,distance))
	_sounds(near,distance,flashes)
	var event := {"id":now.id,"near":near,"stage":stage,"place":place,"distance":distance,"time":clock}
	_log("heard %s %s %.0f m off at %s" % [near,stage,distance,place.round()])
	heard.emit(event)

## A stage for a sighting: close "away" (ahead, flying on away from the
## plane, seen from behind), "over" (right above, overtaking it: belly,
## wings and claws) or "under" (a little below and ahead: back and wings
## from above); far "away" or "toward" (coming at the plane).
func _pick(near: String) -> String:
	var r := _rng.randf()
	if near == "far": return "toward" if r < FAR_TOWARD else "away"
	if _rng.randf() < WING_SHARE*clampf(murk,0.0,1.0): return "wing"
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
	if str(now.stage) in ["wing","wing_low","chase"] and int(now.struck) == 0: _keep_over(float(now.flashes[0])-t)
	var stalk := str(now.stage) == "stalk"
	var stalk_in := 1.0
	if stalk: stalk_in = _stalk(t)
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
	if stalk:
		# Always there: a dark shape in the murk from the first, the flashes
		# showing it harder; going, it fades as it sinks out.
		shown = true
		lit = maxf(lit*stalk_in,STALK_SEEN*stalk_in)
	var wing := str(now.stage) in ["wing","wing_low","chase","head"]
	var pass_ := str(now.stage) in ["wing","wing_low","chase"]
	var rel := t-float(flashes[0])
	if pass_: _wing_beat(rel,delta)
	_wash(delta)
	if wing:
		# A dark shape all the pass, harder in the flashes; a wing pass's
		# fading as it leaves.
		var fade := 1.0-smoothstep(WING_FADE.x,WING_FADE.y,rel) if pass_ else 1.0
		lit = maxf(lit,WING_SEEN*fade)
		if str(now.stage) == "head" and not bool(now.gusted) and t >= float(flashes[0])+WING_GUST:
			now.gusted = true
			_wing_gust()
	if shown and lit > 0.0 and not bool(now.sighted):
		now.sighted = true
		count += 1
		var eye := _eye().global_position if _eye() != null else place
		last = {"id":now.id,"near":now.near,"stage":now.stage,"place":place,"distance":eye.distance_to(place),"time":clock}
		_log("sighted %s %.0f m off at %s, t %.1f" % [now.near,float(last.distance),place.round(),clock])
		sighted.emit(last)
	var over := t > STALK_EMERGE+float(_cross.stay)+STALK_LEAVE if stalk else t > float(flashes[-1])+(WING_AFTER if wing else AFTER) and sounds.is_empty()
	if over and not hold:
		_log("end %d" % int(now.id))
		now = {}
		glimpse.model.scale = Vector3.ONE*glimpse.SIZE
		glimpse.flap = 0.0
		glimpse.only_wings = false
		_wash(0.0)
		lit = 0.0
		_rest = REST
		_dry = 0.0

## Lightning behind it from the eye, to light it; the second flash may show
## it gone.
func _flash(k: int) -> void:
	var camera := _eye()
	if k > 0 and _rng.randf() < GONE and not str(now.stage) in ["wing","wing_low","chase","stalk","head"]: now.gone = true
	if camera == null: return
	var eye := camera.global_position
	_flash_at(camera,eye)
	_log("flash %d%s, %.0f m off" % [k+1," (gone)" if bool(now.gone) else "",eye.distance_to(place)])

## The flash behind it from the eye.
func _flash_at(camera: Camera3D, eye: Vector3) -> void:
	var away := Vector3(place.x-eye.x,0.0,place.z-eye.z)
	away = away.normalized() if away.length() > 0.5 else -camera.global_basis.z
	var lightning: Node3D = _weather.lightning
	# Right behind it from the eye: the murk (or the cloud and the sky) blooms
	# round it and it stands black against the bloom.
	var line := (place-eye).normalized()
	if str(now.stage) == "wing_low":
		# Behind the forward wing's middle from the eye (it lies along the
		# plane's way, beside it, under): the wing stands against the bloom.
		var f := -camera.global_basis.z
		var mid := place+Vector3(f.x,0.0,f.z).normalized()*110.0
		lightning.flash_inside(eye+(mid-eye).normalized()*(eye.distance_to(mid)+_rng.randf_range(CLOSE_BEHIND.x,CLOSE_BEHIND.y)))
	elif str(now.stage) == "wing":
		# Over the plane, a little ahead: the wing across the top of the
		# view stands against the bloom.
		lightning.flash_inside(eye+(place+Vector3.UP*40.0-eye).normalized()*(eye.distance_to(place)+_rng.randf_range(CLOSE_BEHIND.x,CLOSE_BEHIND.y)))
	elif str(now.stage) == "head":
		# Behind the near wing's middle from the eye (the body is far off to
		# the side): the wing stands against the bloom.
		var to_plane := Vector3(eye.x-place.x,0.0,eye.z-place.z).normalized()
		var mid := place+to_plane*float(WING.aside.x)*0.55
		lightning.flash_inside(eye+(mid-eye).normalized()*(eye.distance_to(mid)+_rng.randf_range(CLOSE_BEHIND.x,CLOSE_BEHIND.y)))
	elif str(now.near) == "close":
		lightning.flash_inside(place+line*_rng.randf_range(CLOSE_BEHIND.x,CLOSE_BEHIND.y)+Vector3.UP*_rng.randf_range(CLOSE_LIFT.x,CLOSE_LIFT.y))
	elif murk > 0.5:
		lightning.flash_inside(place+line*_rng.randf_range(MURK_BEHIND.x,MURK_BEHIND.y))
	else:
		var ground := place+away*_rng.randf_range(FAR_BEHIND.x,FAR_BEHIND.y)+away.cross(Vector3.UP)*_rng.randf_range(-80.0,80.0)
		if _rng.randf() < 0.55: lightning.strike_over(ground,"bolt",place.y+_rng.randf_range(90.0,180.0),lightning.SEA_TOP)
		else: lightning.strike_over(ground,"inside",place.y-170.0,lightning.SEA_TOP)

## The wing pass's downwash, laid round the dragon as posed this frame (off
## but in a wing pass).
func _wash(delta: float) -> void:
	var on := not now.is_empty() and str(now.stage) in ["wing","wing_low","chase"]
	var size: float = glimpse.model.scale.x
	downwash.update(delta,on,glimpse.global_position,glimpse.get("_yaw"),size,glimpse.phase,glimpse.flap,1.0/WING_BEAT,-INF,false)

## The downwash as the plane's air at `p` ({} none).
func plane_air(p: Vector3, nose: Vector3) -> Dictionary:
	return downwash.plane_air(p,nose)

## A stalk at `t` s in: where it is (coming in from its edge, settled, or
## sinking back out), held in the view, its
## beat (its heading the plane's, level); returns how far in it is (0 to 1:
## 0 gone past the edge).
func _stalk(t: float) -> float:
	var camera := _eye()
	if camera == null: return 0.0
	var f := -camera.global_basis.z
	var flat := Vector3(f.x,0.0,f.z)
	if flat.length() < 0.01: return 0.0
	flat = flat.normalized()
	var right := flat.cross(Vector3.UP)
	var stay: float = _cross.stay
	var k := smoothstep(0.0,STALK_EMERGE,t)*(1.0-smoothstep(STALK_EMERGE+stay,STALK_EMERGE+stay+STALK_LEAVE,t))
	var settle: Vector2 = STALK_AT[_cross.edge]+(_cross.jitter as Vector2)
	# Past the edge it comes from: the same line, STALK_OUT of the half view
	# out, so it slides in across the edge.
	var out := settle.normalized()*STALK_OUT if settle.length() > 0.01 else Vector2(STALK_OUT,0.0)
	if str(_cross.edge) in ["left","right"]: out = Vector2(signf(settle.x)*STALK_OUT,settle.y)
	else: out = Vector2(settle.x,signf(settle.y)*STALK_OUT)
	var at := out.lerp(settle,k)
	var half_v := deg_to_rad(camera.fov)*0.5
	var half_h := atan(tan(half_v)*_aspect())
	var a := at.x*half_h
	var e := at.y*half_v
	var range_: float = _cross.range
	var eye := camera.global_position
	# Where it sits in the view (the camera's own frame, so it holds its
	# place on the screen as the camera pitches and turns).
	place = eye+(camera.global_basis*Vector3(tan(a),tan(e),-1.0)).normalized()*range_
	var moving := _plane_velocity()
	velocity = flat*maxf(moving.dot(flat),0.0)+Vector3.UP*moving.y
	facing = flat*maxf(moving.dot(flat),8.0)
	glimpse.flap = 1.0
	glimpse.phase = fposmod(t/STALK_BEAT,1.0)
	return k

## A wing pass's beat and its leaving, `rel` s from its first flash.
func _wing_beat(rel: float, delta: float) -> void:
	if rel < WING_LIFT:
		# Gliding in, then the wing lifting to the top of its stroke.
		glimpse.phase = 0.0
		glimpse.flap = smoothstep(WING_LIFT-WING_RAISE,WING_LIFT,rel)
	else:
		glimpse.flap = 1.0
		glimpse.phase = fposmod((rel-WING_LIFT)/WING_BEAT,1.0)
	if rel < WING_LEAVE: return
	# Leaving: turning ahead of the plane and climbing off (diving, low),
	# whole again.
	glimpse.only_wings = false
	var camera := _eye()
	if camera == null: return
	var f := -camera.global_basis.z
	var flat := Vector3(f.x,0.0,f.z)
	if flat.length() < 0.01: return
	flat = flat.normalized()
	var right := flat.cross(Vector3.UP)
	var k := smoothstep(WING_LEAVE,WING_LEAVE+LEAVE_EASE,rel)
	var moving := _plane_velocity()
	var chase := str(now.stage) == "chase"
	var cross := flat*float(_cross.vel) if chase else right*float(now.side)*float(_cross.vel)
	# Chased, it pulls away ahead and climbs; low, it dives off out to its side, still side on (turned ahead, its
	# wing would swing in over the plane); over, it turns ahead and climbs.
	var away := right*float(now.side)*LEAVE_AHEAD+Vector3.DOWN*LEAVE_CLIMB if str(now.stage) == "wing_low" else flat*LEAVE_AHEAD+Vector3.UP*LEAVE_CLIMB*(0.6 if chase else 1.0)
	var own := cross.lerp(cross+away,k)
	var target := flat*maxf(moving.dot(flat),0.0)+own
	velocity = velocity.lerp(target,1.0-exp(-delta*3.0))
	facing = own

## A wing pass before its first flash, `left` s off: where it would be in
## the plane's frame now, crossing toward its line, so it is over the plane
## at the flash however the plane has turned meanwhile.
func _keep_over(left: float) -> void:
	var camera := _eye()
	if camera == null or _scene.get("plane") == null: return
	var f := -camera.global_basis.z
	var flat := Vector3(f.x,0.0,f.z)
	if flat.length() < 0.01: return
	flat = flat.normalized()
	var right := flat.cross(Vector3.UP)
	var side: float = now.side
	var plane: Vector3 = _scene.plane.position
	var moving := _plane_velocity()
	if str(now.stage) == "chase":
		place = plane+right*float(_cross.off)+flat*(float(_cross.ahead)-float(_cross.vel)*left)
		place.y = camera.global_position.y+float(_cross.up)
		velocity = flat*(maxf(moving.dot(flat),0.0)+float(_cross.vel))+Vector3.UP*moving.y
		facing = flat
		return
	place = plane+right*side*(float(_cross.off)-float(_cross.vel)*left)+flat*float(_cross.ahead)
	place.y = camera.global_position.y+float(_cross.up)
	velocity = flat*maxf(moving.dot(flat),0.0)+Vector3.UP*moving.y+right*side*float(_cross.vel)
	facing = right*side*float(_cross.vel)

## The wing's downstroke reaching the plane: a shove away from its side.
func _wing_gust() -> void:
	var eye := _eye()
	if eye == null: return
	var from := Vector3(eye.global_position.x-place.x,0.0,eye.global_position.z-place.z).normalized()
	_weather.set("_gust",{"way":from,"k":WING_GUST_K,"t":0.0,"length":WING_GUST_LENGTH})
	_log("wing gust")

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
