extends Node3D
## The grass flush (docs/design/endless-flight/grass-birds-handoff.md): now and
## then, flying low over a meadow, a small covey goes up out of the grass
## ahead of the plane. Rare on purpose: the wait is seconds flown in the right
## place (low, fast, a meadow coming up), drawn afresh after each flush, so a
## rich meadow doesn't make it more often and no meadow has them in the same
## spot twice.
##
## This file says when, where and how a flush goes, and what the grass and the
## ear get of it. The birds themselves are a flock of the birds node
## (scripts/endless/endless_birds.gd, `put_covey`, the COVEY state), flown on
## the CPU and drawn with the other songbirds' parts, in the `starling`'s dark
## plumage. Visual only: nothing here reads into or writes to the flight.
##
## None where the world has no grass (its `grass` layer). Flags: --grass-birds=X
## how many birds over the default (1; 0 none), --flush-gap=S the mean seconds
## of low meadow between flushes (GAP), --flush-size=X the birds' size over
## SIZE, --flush-sound=N what you hear (SOUNDS).

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const FlightSound = preload("res://scripts/endless/flight_sound.gd")

## Seconds of low meadow between flushes, on average, and how far a draw goes
## to either side of that (a share of it).
const GAP := 45.0
const GAP_SPREAD := 0.34
## The first of a flight comes sooner, this share of a gap at most.
const FIRST := 0.6
## The right place, read every READ s: this high over the ground at most, off
## the wheels, this fast (medium cruise is 36.5), and meadow over MEADOW a
## second's flight ahead.
const READ := 0.25
const LOW := 24.0
const WHEELS := 1.5
const FAST := 24.0
const MEADOW := 0.45
## A spot's ground: slope under this across SLOPE_REACH m, this far from a
## river, this far over the sea.
const SLOPE := 0.14
const SLOPE_REACH := 12.0
const RIVER_CLEAR := 6.0
const SEA_CLEAR := 2.5
## The spot: this many seconds ahead along the plane's curving line, and this
## far off it (m): mostly close, OFF_SHARE of the time well out to a side.
const LEAD := Vector2(1.4,1.9)
const OFF_NEAR := 4.0
const OFF_FAR := Vector2(7.0,16.0)
const OFF_SHARE := 0.35
## A covey: its birds, the patch of grass they sit in (radius, m).
const COVEY := Vector2i(8,20)
const PATCH := Vector2(2.5,7.0)
## Its escape: birds fly on ahead of the plane, slower, and it catches them.
## It is aimed for that moment: this far off the line (m) when the plane comes
## by, on the side they rose from unless they cross the nose (CROSS_SHARE).
## This fast (m/s), up to this height (m); levelled this share of the wait
## after a bird goes, down this much later (s); the widest a bird fans from the
## way (rad), how far the ragged start stretches, and how often a covey close
## on the line splits round it.
const MISS := Vector2(1.5,10.0)
const CROSS_SHARE := 0.3
const ESCAPE_MOST := 0.95
const PACE := Vector2(13.0,19.0)
const PEAK := Vector2(2.2,6.5)
const LEVEL := Vector2(0.9,1.25)
const DROP := Vector2(1.4,3.2)
const FAN := Vector2(0.35,0.95)
const RAGGED := Vector2(0.7,1.4)
const SPLIT_SHARE := 0.35
## The birds' span over the plane's: about 0.85 m at the sizes' knobs, the
## same as the flocks in the trees, so they read from the chase camera on Boost.
const SIZE := 0.3
## What the grass gets where a bird leaves: a shake (m, share of a wash puff's
## push) and bits of chaff.
const SHAKE_REACH := 3.2
const SHAKE := 0.9
const CHAFF := 3
## --flush-sound=N: 0 nothing, then what each is made of (the handoff's list).
const SOUNDS := {0:[],1:["chatter"],2:["chatter","flutter"],3:["pips"],4:["flutter"]}
const DEFAULT_SOUND := 1
const TWITTER := "res://assets/audio/kit/twitter-%d.wav"
const CHIRP := "res://assets/audio/kit/chirp-%d.wav"
const FLUTTER := "res://assets/audio/kit/flutter-loop.wav"
## Gains (dB), low enough that the engine stays on top; the voices' reach (m),
## the voices at once.
const CHATTER_DB := -11.0
const PIP_DB := -9.0
const FLUTTER_DB := -17.0
const FLUTTER_TIME := 1.0
const VOICE_UNIT := 26.0
const VOICE_FAR := 240.0
const VOICES := 5

var density := 1.0
var gap := GAP
var size := 1.0
var sound := DEFAULT_SOUND
## The numbers: flushes and birds so far, seconds flown in the right place,
## what a read and a flush cost (ms).
var stats := {"flushes":0,"birds":0,"low_s":0.0,"reads":0,"read_ms":0.0,"go_ms":0.0}
## The last flushes (for drivers): the time, seconds of low meadow since the one
## before, birds, how far ahead and off the line, height, speed, its choices.
var log_flushes: Array = []
## The grass's reaction and the motes' chaff (the study's, may stay null).
var react: Node = null
var motes: Node = null

var _field: RefCounted
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _wait := 0.0
var _due := 0.0
var _since := 0.0
var _yaw := 0.0
var _turning := 0.0
var _flock: RefCounted = null
var _voices: Array[AudioStreamPlayer3D] = []
var _voice := 0
var _twitters: Array = []
var _chirps: Array = []
var _flutter: AudioStream = null
## Calls still to come: [time, clip, gain, pitch, cut after s (0 play out)].
var _calls: Array = []
var _fading: AudioStreamPlayer3D = null
var _fade_left := 0.0

static func flags() -> Dictionary:
	var grows := bool(preload("res://scripts/endless/world/world_profile.gd").current().layer("grass",true))
	var out := {"density":1.0 if grows else 0.0,"gap":GAP,"size":1.0,"sound":DEFAULT_SOUND}
	for a: String in LaunchArgs.user_args():
		var v := a.get_slice("=",1)
		if a.begins_with("--grass-birds=") and grows: out.density = maxf(0.0,float(v))
		elif a.begins_with("--flush-gap="): out.gap = maxf(float(v),1.0)
		elif a.begins_with("--flush-size="): out.size = maxf(float(v),0.1)
		elif a.begins_with("--flush-sound="): out.sound = int(v) if SOUNDS.has(int(v)) else DEFAULT_SOUND
	return out

func setup(land_seed: int, field: RefCounted) -> void:
	var f := flags()
	density = f.density
	gap = f.gap
	size = f.size
	sound = f.sound
	_field = field
	_rng.seed = hash("grass flush%d" % land_seed)
	_due = _next_gap()*_rng.randf_range(0.3,FIRST)
	if density > 0.0 and FlightSound.wanted() and not (SOUNDS[sound] as Array).is_empty(): _add_voices()

## Seconds of low meadow to the next flush.
func _next_gap() -> float:
	return gap*_rng.randf_range(1.0-GAP_SPREAD,1.0+GAP_SPREAD)

func _add_voices() -> void:
	for i in 6: _twitters.append(load(TWITTER % (i+1)))
	for i in 8: _chirps.append(load(CHIRP % (i+1)))
	_flutter = load(FLUTTER)
	for i in VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = FlightSound.SFX
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = VOICE_UNIT
		p.max_distance = VOICE_FAR
		p.panning_strength = 0.7
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_voices.append(p)

## One frame: the calls due, a read of the place now and then.
func step(delta: float, plane: RefCounted) -> void:
	if density <= 0.0: return
	_time += delta
	if not _calls.is_empty() or _fading != null: _sing(delta)
	_wait -= delta
	if _wait > 0.0: return
	_wait = READ
	var t0 := Time.get_ticks_usec()
	_read(plane.position,plane.velocity)
	stats.reads += 1
	stats.read_ms = lerpf(float(stats.read_ms),(Time.get_ticks_usec()-t0)/1000.0,0.1)

# --- When and where -----------------------------------------------------------

func _read(pp: Vector3, pv: Vector3) -> void:
	var flat := Vector3(pv.x,0.0,pv.z)
	if flat.length() < 1.0: return
	var fwd := flat.normalized()
	# The line's bend, smoothed, for where it will be in a moment.
	var yaw := atan2(-fwd.x,-fwd.z)
	_turning = lerpf(_turning,angle_difference(_yaw,yaw)/READ,0.25)
	_yaw = yaw
	var speed := pv.length()
	if speed < FAST: return
	var over := pp.y-maxf(_field.height(pp.x,pp.z),Field.SEA_Y)
	if over > LOW or over < WHEELS: return
	var ahead := pp+fwd*speed
	var here: Dictionary = _field.shape(ahead.x,ahead.z)
	if float(here.meadow) < MEADOW: return
	stats.low_s += READ
	_since += READ
	_due -= READ
	if _due > 0.0: return
	_try(pp,fwd,speed,over)

## A spot ahead on the line, in view, or wait for the next read.
func _try(pp: Vector3, fwd: Vector3, speed: float, over: float) -> void:
	var t0 := Time.get_ticks_usec()
	var lead := _rng.randf_range(LEAD.x,LEAD.y)
	var dir := fwd.rotated(Vector3.UP,clampf(_turning*lead*0.5,-1.0,1.0))
	var along := speed*lead
	var on_line := pp+dir*along
	on_line.y = pp.y
	var right := dir.cross(Vector3.UP)
	var off := _rng.randf_range(-OFF_NEAR,OFF_NEAR)
	if _rng.randf() < OFF_SHARE: off = _rng.randf_range(OFF_FAR.x,OFF_FAR.y)*(1.0 if _rng.randf() < 0.5 else -1.0)
	var c := on_line+right*off
	var site := _ground(c.x,c.z)
	if site.is_empty(): return
	var at := Vector3(c.x,float(site.y),c.z)
	if not _in_view(at): return
	var host := get_parent()
	var n := clampi(roundi(_rng.randi_range(COVEY.x,COVEY.y)*density),1,40)
	if not host.covey_room(n): return
	var side := signf(off) if absf(off) > 2.0 else (1.0 if _rng.randf() < 0.5 else -1.0)
	var crossing := _rng.randf() < CROSS_SHARE
	var split := absf(off) < OFF_NEAR and _rng.randf() < SPLIT_SHARE
	var pace := _rng.randf_range(PACE.x,PACE.y)
	# When the plane catches them, and the slant that has them there by then.
	var wait := along/maxf(speed-pace*0.93,6.0)
	var miss := _rng.randf_range(MISS.x,MISS.y)*(-side if crossing else side)
	var slant := asin(clampf((miss-off)/maxf(pace*0.85*(wait-0.4),1.0),-sin(ESCAPE_MOST),sin(ESCAPE_MOST)))
	if absf(slant) < 0.1: slant = 0.1*signf(miss)
	var way := dir.rotated(Vector3.UP,-slant)
	var level := wait*_rng.randf_range(LEVEL.x,LEVEL.y)
	var patch := _rng.randf_range(PATCH.x,PATCH.y)
	var plan := {"way":way,"line":dir,"pace":pace,"peak":_rng.randf_range(PEAK.x,PEAK.y),
		"level":level,"drop":level+_rng.randf_range(DROP.x,DROP.y),"fan":_rng.randf_range(FAN.x,FAN.y),
		"ragged":_rng.randf_range(RAGGED.x,RAGGED.y),"split":split,"size":SIZE*size,"patch":patch}
	# Nearest the plane's line first: the point it will cross, a little short.
	_flock = host.put_covey(at,Vector2(site.gx,site.gz),n,on_line-dir*patch+Vector3.DOWN*(pp.y-at.y),plan)
	_cry(n)
	stats.flushes += 1
	stats.birds += n
	stats.go_ms = (Time.get_ticks_usec()-t0)/1000.0
	log_flushes.append({"t":_time,"low":_since,"n":n,"ahead":along,"off":off,"over":over,"speed":speed,"crossing":crossing,"split":split,
		"peak":plan.peak,"pace":pace,"patch":patch,"at":at,"wait":wait,"miss":miss,"slant":slant})
	if log_flushes.size() > 128: log_flushes.pop_front()
	_since = 0.0
	_due = _next_gap()

## The ground at (x, z) as a covey needs it: {y, gx, gz}, or {} if it won't do.
func _ground(x: float, z: float) -> Dictionary:
	var here: Dictionary = _field.shape(x,z)
	var y := float(here.height)
	if float(here.meadow) < MEADOW or y-Field.SEA_Y < SEA_CLEAR or float(here.river) < RIVER_CLEAR: return {}
	var gx: float = (float(_field.height(x+SLOPE_REACH,z))-float(_field.height(x-SLOPE_REACH,z)))/(2.0*SLOPE_REACH)
	var gz: float = (float(_field.height(x,z+SLOPE_REACH))-float(_field.height(x,z-SLOPE_REACH)))/(2.0*SLOPE_REACH)
	if absf(gx) > SLOPE or absf(gz) > SLOPE: return {}
	return {"y":y,"gx":gx,"gz":gz}

## On screen, and no rise of the land between the eye and it.
func _in_view(at: Vector3) -> bool:
	var view := get_viewport().get_camera_3d()
	if view == null: return true
	var top := at+Vector3.UP*2.0
	if not view.is_position_in_frustum(top): return false
	var eye := view.global_position
	for k: float in [0.3,0.55,0.8]:
		var p := eye.lerp(top,k)
		if float(_field.height(p.x,p.z)) > p.y: return false
	return true

# --- What the grass gets ---------------------------------------------------------

## A bird left the grass at `at`: it shakes there, and a little chaff comes up.
func lifted(at: Vector3) -> void:
	var there := Vector2(at.x,at.z)
	if react != null: react.shake(there,SHAKE_REACH,SHAKE)
	if motes != null: motes.puff(there,CHAFF)

# --- What the ear gets -----------------------------------------------------------

## The flush's calls, laid out over its ragged start.
func _cry(n: int) -> void:
	if _voices.is_empty(): return
	var parts: Array = SOUNDS[sound]
	var t := _time
	if parts.has("chatter"):
		# One alarm first, then the rest of them in over it.
		_call(t,_pick(_chirps),PIP_DB,1.05)
		for i in 2+int(n > 13):
			t += _rng.randf_range(0.1,0.34)
			_call(t,_pick(_twitters),CHATTER_DB,_rng.randf_range(1.0,1.22))
	if parts.has("pips"):
		for i in 3+int(n > 13):
			_call(t,_pick(_chirps),PIP_DB,_rng.randf_range(1.0,1.2))
			t += _rng.randf_range(0.09,0.32)
	if parts.has("flutter"):
		_call(_time+0.05,_flutter,FLUTTER_DB,_rng.randf_range(0.95,1.1),FLUTTER_TIME)

func _pick(list: Array) -> AudioStream:
	return list[_rng.randi_range(0,list.size()-1)]

func _call(at: float, clip: AudioStream, db: float, pitch: float, cut := 0.0) -> void:
	_calls.append([at,clip,db,pitch,cut])

func _sing(delta: float) -> void:
	var there: Vector3 = _flock.a if _flock != null else Vector3.ZERO
	for i in range(_calls.size()-1,-1,-1):
		var c: Array = _calls[i]
		if float(c[0]) > _time: continue
		_calls.remove_at(i)
		var p := _voices[_voice]
		_voice = (_voice+1)%_voices.size()
		p.global_position = there
		p.stream = c[1]
		p.volume_db = float(c[2])+_rng.randf_range(-1.5,1.5)
		p.pitch_scale = float(c[3])
		p.play(_rng.randf_range(0.0,2.4) if c[1] == _flutter else 0.0)
		if float(c[4]) > 0.0:
			_fading = p
			_fade_left = float(c[4])
	if _fading == null: return
	_fade_left -= delta
	_fading.global_position = there
	# The loop fades in its last third, so it never ends on a cut.
	if _fade_left < FLUTTER_TIME/3.0: _fading.volume_db -= delta*60.0
	if _fade_left <= 0.0:
		_fading.stop()
		_fading = null

## The numbers line (F1).
func note() -> String:
	if density <= 0.0: return ""
	return "\ngrass flush: %d flushes, %d birds  ·  %.0f s of low meadow, %.0f s to the next  ·  read %.2f ms" % [
		int(stats.flushes),int(stats.birds),float(stats.low_s),_due,float(stats.read_ms)]
