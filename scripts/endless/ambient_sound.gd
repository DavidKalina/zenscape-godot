extends Node
## Endless flight's living ground: birdsong over the meadows by day, crickets
## at dusk and by night, frogs by ponds, lakes and rivers, and now and then a
## call that passes the plane (a bird off to one side, a raven up by the rocks,
## a heron, an owl at night). A child of scripts/endless/flight_sound.gd, which
## calls `step` each frame after its own; `--ambient-sound=0` leaves it out.
##
## - Beds: three loops on the "Ambience" bus, each by its place weight (read
##   from the land under the plane a few times a second, not each frame) and
##   the hour (the look's `celestial.daylight`). Birds need a flat, low,
##   dry meadow and daylight; crickets any land at dusk and night; frogs
##   fresh water close by, louder after dark.
## - Presence: how far the beds come forward. They fade under the engine with
##   speed (FlightSound `fast`) and with height over the ground (`agl`), and
##   come forward as the plane slows or flies low, and fully while it sits
##   landed (wheels down and slow), where the place is meant to be heard.
## - Calls: sparse, one at a time (the gap shorter landed), each from a deck of
##   its group's clips shuffled so none repeats before the rest have played.
##   Placed in the world ahead of the plane and off to one side, so one
##   whips past at speed; a raven is placed up high.
##
## Loading: the clips load one a frame from the first frame on (not when first
## needed in flight); the beds sound once theirs are in. The land is read in
## two alternating slices, 0.6 s apart: the fresh water and the sea, then the
## relief. Headless there are no players, but the weights, gains and calls
## still run (for a driver to read; `--sound=on` plays headless too).

const Field = preload("res://scripts/endless/land_field.gd")

const AMBIENCE := &"Ambience"
const DIR := "res://assets/audio/"
const KIT := "res://assets/audio/kit/"

# --- Tuning ----------------------------------------------------------------------

## The beds' gain at full weight and full presence (the engine idles near
## 0.085 and runs to about 0.17).
const BIRDS := 0.14
const CRICKETS := 0.11
const FROGS := 0.11
## Frogs by day, as a share of their night (the bed is the night chorus).
const FROGS_DAY := 0.3
## What share of its landed level the flying presence tops out at (slow and
## low), and how far speed and height each take it down: `fast` between
## SPEED_FADE, metres over the ground between HEIGHT_FADE.
const FLYING_MOST := 0.6
const SPEED_FADE := Vector2(0.3,0.95)
const SPEED_FLOOR := 0.15
const HEIGHT_FADE := Vector2(12.0,160.0)
const HEIGHT_FLOOR := 0.12
## Landed: wheels down and `fast` below this.
const LANDED_FAST := Vector2(0.1,0.5)
## The land read: seconds between slices; the rings (m) of the fresh-water
## samples, the relief samples and the sea samples (the last far enough that
## a lake is not the sea), each with a count.
const READ_TICK := 0.6
const WET_RINGS := [Vector2(0.0,1.0),Vector2(40.0,6.0),Vector2(120.0,8.0)]
const RELIEF_RING := Vector2(120.0,8.0)
const SEA_RING := Vector2(600.0,8.0)
## Ponds: searched this far (m) round the plane; the distance (m) from a pond's
## edge where frogs are full and gone.
const POND_REACH := 260.0
const POND_NEAR := Vector2(25.0,220.0)
## A meadow: relief (m, highest less lowest of the relief samples) flat to
## rough, and the ground's height over the sea easy to bare.
const FLAT := Vector2(14.0,50.0)
const LOW_LAND := Vector2(260.0,620.0)
## Rock: relief where it starts and is full.
const ROCKY := Vector2(25.0,70.0)
## Daylight (the look's, 0 to 1) where birds begin and are full; where crickets
## and the dark's frogs begin to fade as day comes.
const BIRD_LIGHT := Vector2(0.15,0.7)
const DARK_LIGHT := Vector2(0.25,0.85)
## Calls: seconds between, flying and landed; the weights under which the
## groups are too weak to call (retry in CALL_RETRY s); their gain at the
## quietest presence and the loudest; the pool of players; and the distance
## ahead (seconds of flight, in metres), to the side, and up for a raven.
const CALL_GAP := Vector2(14.0,32.0)
const CALL_GAP_LANDED := Vector2(6.0,14.0)
const CALL_WEAK := 0.15
const CALL_RETRY := 3.0
const CALL_GAIN := Vector2(0.12,0.22)
const CALL_PLAYERS := 3
const CALL_LEAD := Vector2(1.2,2.0)
const CALL_LEAD_M := Vector2(18.0,130.0)
const CALL_SIDE := Vector2(22.0,55.0)
const CALL_HIGH := Vector2(14.0,40.0)
const CALL_MAX_AGL := 220.0
## The groups' clips (DIR, else KIT). Every clip is already in the project.
const GROUPS := {
	"meadow":["bluebird.mp3","chickadee.mp3","robin.mp3","kinglet.mp3","hermit-thrush.mp3","jay-1.mp3","jay-2.mp3"],
	"rock":["raven.mp3","nutcracker.mp3","raven.mp3"],
	"water":["heron-call.wav","frog-croak.wav"],
	"night":["owl.mp3"],
}

## A looping voice: its gain eased toward its goal, stopped while silent and
## started again at a random point when heard. Without a player (headless) it
## only eases.
class Voice extends RefCounted:
	var player
	var gain := 0.0
	var goal := 0.0
	var attack := 0.8
	var release := 0.6
	func step(delta: float) -> void:
		gain = lerpf(gain,goal,1.0-exp(-delta*(attack if goal > gain else release)))
		if goal <= 0.0 and gain < 0.0006: gain = 0.0
		if player == null: return
		if gain <= 0.0:
			if player.playing: player.stop()
			return
		if not player.playing: player.play(randf()*player.stream.get_length())
		player.volume_db = linear_to_db(gain)

var birds := Voice.new()
var crickets := Voice.new()
var frogs := Voice.new()

# The place, public for probes (0 to 1 each).
var meadow := 0.0
var pond := 0.0
var sea := 0.0
var rocky := 0.0
var land := 0.0
var daylight := 1.0
## How far the beds are forward (0 shut away, 1 landed).
var presence := 0.0
## Calls made, by clip, and the last (clip, group, gain, position).
var played := {}
var last_call := {}
## True when there are players (a windowed run).
var audible := false

var _rng := RandomNumberGenerator.new()
var _queue: Array = []
var _streams := {}
var _loaded := false
var _players: Array[AudioStreamPlayer3D] = []
var _next_player := 0
var _decks := {}
var _last_clip := {}
var _call_wait := 0.0
var _read_wait := 0.0
var _slice := 0
var _fresh := 0.0
var _pond_near := 0.0
var _sea := 0.0
var _ground := 0.0

## Whether the layer is on: not under `--ambient-sound=0`.
static func wanted() -> bool:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--ambient-sound=0": return false
	return true

func _init() -> void:
	name = "AmbientSound"

func _ready() -> void:
	_rng.randomize()
	audible = DisplayServer.get_name() != "headless" or "--sound=on" in preload("res://scripts/launch_args.gd").user_args()
	if "--sound=0" in preload("res://scripts/launch_args.gd").user_args(): audible = false
	_call_wait = _rng.randf_range(CALL_GAP.x*0.4,CALL_GAP.x)
	if not audible: return
	for i in range(CALL_PLAYERS):
		var p := AudioStreamPlayer3D.new()
		p.bus = AMBIENCE
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 25.0
		p.max_distance = 260.0
		p.panning_strength = 1.0
		add_child(p)
		_players.append(p)
	for pair in [[birds,KIT+"bird-chorus-loop.wav"],[crickets,DIR+"cricket-bed.wav"],[frogs,DIR+"frog-bed.wav"]]:
		_queue.append(pair)
	var seen := {}
	for clips: Array in GROUPS.values():
		for clip: String in clips:
			if seen.has(clip): continue
			seen[clip] = true
			_queue.append(DIR+clip)

## One clip a frame: a bed is a looping copy of its WAV, a call's stream is
## kept by path.
func _load_one() -> void:
	var item = _queue.pop_front()
	if item is Array:
		var stream := (load(item[1]) as AudioStreamWAV).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = AMBIENCE
		player.volume_db = -80.0
		add_child(player)
		(item[0] as Voice).player = player
	else:
		_streams[item] = load(item)
	if _queue.is_empty(): _loaded = true

## One frame. `sound` is the FlightSound (its `fast`, `agl`, `alt`), `game` the
## endless flight study (`plane`, `hand_landing`, `field`, `look`).
func step(delta: float, game: Node3D, sound: Node) -> void:
	if delta <= 0.0 or game.plane == null: return
	if not _queue.is_empty(): _load_one()
	_read_wait -= delta
	if _read_wait <= 0.0:
		_read_wait = READ_TICK
		_read(game)
	daylight = _daylight(game)
	var wheels: bool = game.hand_landing.on_ground()
	var fast: float = sound.fast
	var agl: float = sound.agl
	var flying := FLYING_MOST*lerpf(1.0,SPEED_FLOOR,smoothstep(SPEED_FADE.x,SPEED_FADE.y,fast))*lerpf(1.0,HEIGHT_FLOOR,smoothstep(HEIGHT_FADE.x,HEIGHT_FADE.y,agl))
	var landed := (1.0-smoothstep(LANDED_FAST.x,LANDED_FAST.y,fast)) if wheels else 0.0
	presence = lerpf(flying,1.0,landed)
	var go := _loaded or not audible
	var by_day := smoothstep(BIRD_LIGHT.x,BIRD_LIGHT.y,daylight)
	var dark := 1.0-smoothstep(DARK_LIGHT.x,DARK_LIGHT.y,daylight)
	birds.goal = BIRDS*presence*by_day*meadow if go else 0.0
	crickets.goal = CRICKETS*presence*dark*land if go else 0.0
	frogs.goal = FROGS*presence*pond*lerpf(FROGS_DAY,1.0,dark) if go else 0.0
	for v in [birds,crickets,frogs]: (v as Voice).step(delta)
	_call_wait -= delta
	if _call_wait <= 0.0 and go: _call(game,wheels,by_day,dark,agl)

# --- The place ------------------------------------------------------------------------

## The look's daylight (1 when there is no look).
func _daylight(game: Node3D) -> float:
	var look: Variant = game.get("look")
	if look == null: return 1.0
	var celestial: Variant = look.get("celestial")
	return clampf(float(celestial.daylight),0.0,1.0) if celestial != null else 1.0

## One slice of the land under the plane: the fresh water round it and the sea
## beyond (river_y is a number on a river's or pond's water, NAN off it; a
## height under the sea inland is a lake), then the relief and the ground. The
## weights ease on the next slice's numbers.
func _read(game: Node3D) -> void:
	var field = game.field
	if field == null: return
	var p: Vector3 = game.plane.position
	var at := Vector2(p.x,p.z)
	if _slice == 0:
		var wet := 0.0
		var count := 0.0
		for ring: Vector2 in WET_RINGS:
			for i in range(int(ring.y)):
				var q := at + (Vector2.from_angle(TAU*i/ring.y)*ring.x if ring.x > 0.0 else Vector2.ZERO)
				count += 1.0
				if not is_nan(float(field.river_y(q.x,q.y))) or float(field.height(q.x,q.y)) < Field.SEA_Y+0.2: wet += 1.0
		_fresh = wet/maxf(count,1.0)
		var salt := 0.0
		for i in range(int(SEA_RING.y)):
			var q := at + Vector2.from_angle(TAU*i/SEA_RING.y)*SEA_RING.x
			if float(field.height(q.x,q.y)) < Field.SEA_Y+0.2: salt += 1.0
		_sea = salt/SEA_RING.y
		# Ponds are small (a pond's width is under the rings' spacing): by the
		# distance to the nearest pond's edge instead.
		_pond_near = 0.0
		for pd: PackedFloat32Array in field.ponds_in(p.x-POND_REACH,p.z-POND_REACH,p.x+POND_REACH,p.z+POND_REACH):
			var d := (at-Vector2(pd[0],pd[1])).length()-pd[2]
			_pond_near = maxf(_pond_near,1.0-smoothstep(POND_NEAR.x,POND_NEAR.y,d))
	else:
		var low := INF
		var high := -INF
		for i in range(int(RELIEF_RING.y)):
			var q := at + Vector2.from_angle(TAU*i/RELIEF_RING.y)*RELIEF_RING.x
			var h := float(field.height(q.x,q.y))
			low = minf(low,h)
			high = maxf(high,h)
		var here := float(field.height(at.x,at.y))
		_ground = here-Field.SEA_Y
		low = minf(low,here)
		high = maxf(high,here)
		var relief := high-low
		var dry := 1.0-smoothstep(0.1,0.5,_fresh)
		sea = smoothstep(0.3,0.7,_sea)
		land = (1.0-sea)*(1.0 if here >= Field.SEA_Y+0.2 else 0.0)
		var flat := 1.0-smoothstep(FLAT.x,FLAT.y,relief)
		var lowland := 1.0-smoothstep(LOW_LAND.x,LOW_LAND.y,_ground)
		meadow = land*flat*lowland*lerpf(0.5,1.0,dry)
		rocky = land*smoothstep(ROCKY.x,ROCKY.y,relief)
		# Water close by, not the open sea (the shore has its own bed).
		pond = maxf(smoothstep(0.02,0.2,_fresh),_pond_near)*(1.0-sea)
	_slice = 1-_slice

# --- Calls ------------------------------------------------------------------------------

## One call: a group by its weight, its next clip from the shuffled deck, put
## ahead of the plane and to a side (up high for a raven).
func _call(game: Node3D, wheels: bool, by_day: float, dark: float, agl: float) -> void:
	var landed := wheels and presence > 0.9
	var gap := CALL_GAP_LANDED if landed else CALL_GAP
	if agl > CALL_MAX_AGL:
		_call_wait = CALL_RETRY
		return
	var weights := {
		"meadow":meadow*by_day,
		"rock":rocky*maxf(by_day,0.25*(1.0-dark)),
		"water":pond*lerpf(0.5,1.0,dark),
		"night":dark*land*0.7,
	}
	var total := 0.0
	for w: float in weights.values(): total += w
	if total < CALL_WEAK:
		_call_wait = CALL_RETRY
		return
	var pick := _rng.randf()*total
	var group := "meadow"
	for key: String in weights:
		pick -= float(weights[key])
		if pick <= 0.0:
			group = key
			break
	var clip := _next_clip(group,dark)
	_call_wait = _rng.randf_range(gap.x,gap.y)
	var plane = game.plane
	var pos: Vector3 = plane.position
	var way: Vector3 = (plane.velocity as Vector3)
	var speed := way.length()
	way = way.normalized() if speed > 3.0 else (plane.forward() as Vector3)
	way.y = 0.0
	way = way.normalized() if way.length_squared() > 0.0001 else Vector3.FORWARD
	var right := way.cross(Vector3.UP)
	var side := (1.0 if _rng.randf() < 0.5 else -1.0)*_rng.randf_range(CALL_SIDE.x,CALL_SIDE.y)
	var lead := 0.0 if landed else clampf(speed*_rng.randf_range(CALL_LEAD.x,CALL_LEAD.y),CALL_LEAD_M.x,CALL_LEAD_M.y)
	var at := pos+way*lead+right*side
	at.y += _rng.randf_range(CALL_HIGH.x,CALL_HIGH.y) if group == "rock" else _rng.randf_range(-6.0,10.0)
	var gain := lerpf(CALL_GAIN.x,CALL_GAIN.y,presence)
	var pitch := _rng.randf_range(0.96,1.04)
	played[clip] = int(played.get(clip,0))+1
	last_call = {"clip":clip,"group":group,"gain":gain,"at":at}
	if not audible or not _streams.has(DIR+clip) or _players.is_empty(): return
	var player := _players[_next_player]
	for q in _players:
		if not q.playing:
			player = q
			break
	_next_player = (_next_player+1)%_players.size()
	player.stream = _streams[DIR+clip]
	player.global_position = at
	player.volume_db = linear_to_db(gain)
	player.pitch_scale = pitch
	player.play()

## The group's next clip: a shuffled deck, refilled when spent, never the clip
## just played first. Frogs only croak after the light goes (and a heron only
## by day).
func _next_clip(group: String, dark: float) -> String:
	var deck: Array = _decks.get(group,[])
	var tries := 0
	while true:
		if deck.is_empty():
			deck = (GROUPS[group] as Array).duplicate()
			for i in range(deck.size()-1,0,-1):
				var j := _rng.randi_range(0,i)
				var t: Variant = deck[i]
				deck[i] = deck[j]
				deck[j] = t
		var clip: String = deck.pop_back()
		tries += 1
		var wrong := (clip == "frog-croak.wav" and dark < 0.3) or (clip == "heron-call.wav" and dark > 0.7)
		if (clip != str(_last_clip.get(group,"")) and not wrong) or tries > 8:
			_last_clip[group] = clip
			_decks[group] = deck
			return clip
	return ""

## Every bed's goal and gain, the place read and the presence now (for a
## driver or a debug line).
func layers() -> Dictionary:
	return {"birds":[birds.goal,birds.gain],"crickets":[crickets.goal,crickets.gain],"frogs":[frogs.goal,frogs.gain],
		"meadow":meadow,"pond":pond,"sea":sea,"rocky":rocky,"land":land,"daylight":daylight,"presence":presence}
