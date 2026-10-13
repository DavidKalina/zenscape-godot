extends Node
## The kit isle's living sound (docs/design/sound-round2.md), a child of
## scripts/kit_isle/kit_audio.gd (`audio`), read off the isle each frame:
##
## - Birds by the time of day (`activity`): a distant chorus bed (busiest at
##   dawn, a dusk chorus, thin at midday, none at night); songs from the
##   isle's own songbirds or the green round the listener, excerpts of the
##   old game's recordings at their own pitch and gain, overlapping, now and
##   then answered from another spot; the near birds' chirps and twitters
##   from their perches; wings bursting as they take off or a flock flushes;
##   a raven over the rock and ruins now and then. All of it fades with the
##   isle's nearness, so the open sky stays airy.
## - Bees about the nearest flower patch by day.
## - Night crickets as voices on green spots round the listener: the
##   Electron Zenscape's (zenscape/audio.js tickCrickets), pulsed sine chirps
##   with gaps stretched by cold, each going quiet when he walks up to it.
## - Frogs on the nearest pond's banks at dusk and night (and in rain):
##   audio.js's ratcheting sawtooth croaks.
## - Waterfalls: every fall curtain (flow_fall.gdshader) and thread to the
##   cloud sea (sky_fall_thread.gdshader) is found as it enters the tree; the
##   nearest roar (or a thin spill's patter) sits on the fall's line at the
##   point nearest the listener.
const KIT := "res://assets/audio/kit/"
const OLD := "res://assets/audio/"
const FALL_SHADER := "res://shaders/flow_fall.gdshader"
const THREAD_SHADER := "res://shaders/sky_fall_thread.gdshader"

# --- Tuning ----------------------------------------------------------------------

## The bird day (the celestial phase: 0 midnight, 0.25 sunrise, 0.75 sunset)
## as [phase, singing, chorus]: how busy the songs are, how loud the bed.
const DAY := [[0.0,0.0,0.0],[0.2,0.0,0.0],[0.24,0.6,0.7],[0.3,1.0,1.0],[0.38,0.8,0.55],
	[0.47,0.35,0.18],[0.58,0.4,0.2],[0.68,0.7,0.6],[0.73,0.75,0.75],[0.79,0.1,0.1],[0.82,0.0,0.0],[1.0,0.0,0.0]]
## The chorus bed's gain at full.
const CHORUS := 0.11
## Seconds between songs, quiet and busy; a song's excerpt length; its gain.
const SONG_GAP_QUIET := Vector2(9.0,18.0)
const SONG_GAP_BUSY := Vector2(1.2,4.0)
const SONG_LENGTH := Vector2(3.5,9.0)
const SONG_GAIN := Vector2(0.09,0.2)
const SONG_REACH := 45.0
## The chance a song is answered, and from how far off the first.
const ANSWER := 0.3
const ANSWER_FROM := Vector2(16.0,35.0)
## Near birds' small talk: their reach (m), the gap between them (busy).
const CHAT_REACH := 24.0
const CHAT_GAP := Vector2(1.0,5.0)
const CHAT_GAIN := Vector2(0.05,0.11)
## Wings: how far a take-off is heard, a single bird's and a flock's gain.
const WINGS_REACH := 35.0
const WINGS := Vector2(0.08,0.16)
## The raven: seconds between its calls, its gain.
const RAVEN_GAP := Vector2(35.0,80.0)
const RAVEN := 0.13
## Bees: the patch's reach (m) and their gain.
const BEES_REACH := 30.0
const BEES := 0.05
## Crickets (audio.js): the voices, their peak gain (0.5 bus x 0.11 pulse,
## brought to this mix), how far (m) round the listener they sit, the
## approach hush's reach and its time constants down and back.
const CRICKET_VOICES := 8
const CRICKET := 0.16
const CRICKET_SPOT := Vector2(5.0,22.0)
const CRICKET_HUSH := 4.0
const CRICKET_TAU := Vector2(0.15,2.5)
const CRICKET_SLOW := [1.0,1.5,2.0,2.6]
const CRICKET_HZ := Vector2(4100.0,5000.0)
const CRICKET_BASE_HZ := 4500.0
## Frogs: the voices, their gain, how far (m) the pond may be.
const FROG_VOICES := 4
const FROG := 0.14
const FROG_REACH := 70.0
## Falls: beds for the nearest roars and spills, their gains, reach (m).
const ROARS := 3
const SPILLS := 2
const ROAR := 0.3
const SPILL := 0.16
const ROAR_REACH := 220.0
const SPILL_REACH := 70.0

var audio
var isle
var _rng := RandomNumberGenerator.new()
var _songs: Array = []
var _raven: AudioStream
var _voices: Array[AudioStreamPlayer3D] = []
## Songs playing: [player, seconds left, its gain].
var _singing: Array = []
var _answers: Array = []
var chorus
var bees
var _roars: Array = []
var _spills: Array = []
## The falls found: [MeshInstance3D, thread?].
var falls: Array = []
var _crickets: Array = []
var _cricket_takes := {}
var _frogs: Array = []
var _frog_takes: Array = []
var _song_wait := 2.0
var _chat_wait := 1.5
var _raven_wait := 20.0
var _bird_states := {}
var _meadow_spots: Array = []
var _meadows_read := false
## The bird day now (probes): its singing and its chorus.
var singing := 0.0
var chorus_level := 0.0
var night := 0.0

func _ready() -> void:
	name = "KitAudioLife"
	_rng.randomize()
	for s: String in audio.SONGS: _songs.append(load(OLD+s))
	_raven = load(OLD+"raven.mp3")
	for i in range(10):
		var p := AudioStreamPlayer3D.new()
		p.bus = audio.FAR
		p.unit_size = 10.0
		p.max_distance = 120.0
		p.panning_strength = 0.6
		add_child(p)
		_voices.append(p)
	chorus = audio._bed(KIT+"bird-chorus-loop.wav",audio.FAR)
	chorus.attack = 0.3
	chorus.release = 0.3
	bees = audio._bed(KIT+"insect-hum-loop.wav",audio.AMBIENCE,true)
	(bees.player as AudioStreamPlayer3D).unit_size = 4.0
	(bees.player as AudioStreamPlayer3D).max_distance = BEES_REACH
	for i in range(ROARS):
		var bed = audio._bed(KIT+"fall-roar-loop.wav",audio.AMBIENCE,true)
		(bed.player as AudioStreamPlayer3D).unit_size = 14.0
		(bed.player as AudioStreamPlayer3D).max_distance = ROAR_REACH
		bed.attack = 1.0
		bed.release = 1.0
		_roars.append(bed)
	for i in range(SPILLS):
		var bed = audio._bed(KIT+"fall-spill-loop.wav",audio.AMBIENCE,true)
		(bed.player as AudioStreamPlayer3D).unit_size = 5.0
		(bed.player as AudioStreamPlayer3D).max_distance = SPILL_REACH
		bed.attack = 1.0
		bed.release = 1.0
		_spills.append(bed)
	for pulses in [3,4]:
		for k in range(CRICKET_SLOW.size()): _cricket_takes["%d-%d" % [pulses,k]] = load(KIT+"cricket-%d-%d.wav" % [pulses,k+1])
	for i in range(CRICKET_VOICES):
		var p := AudioStreamPlayer3D.new()
		p.bus = audio.AMBIENCE
		p.unit_size = 2.5
		p.max_distance = 45.0
		p.panning_strength = 0.8
		add_child(p)
		_crickets.append({"player":p,"at":Vector3.INF,"next":_rng.randf()*2.0,"hush":1.0,"pitch":_rng.randf_range(CRICKET_HZ.x,CRICKET_HZ.y)/CRICKET_BASE_HZ})
	for i in range(6): _frog_takes.append(load(KIT+"frog-%d.wav" % (i+1)))
	for i in range(FROG_VOICES):
		var p := AudioStreamPlayer3D.new()
		p.bus = audio.AMBIENCE
		p.unit_size = 3.0
		p.max_distance = FROG_REACH
		add_child(p)
		_frogs.append({"player":p,"at":Vector3.INF,"next":_rng.randf()*5.0,"take":i%_frog_takes.size()})
	# The falls: those standing now, and those built later (motif isles).
	if isle != null:
		for node: Node in isle.find_children("*","MeshInstance3D",true,false): _found(node)
	get_tree().node_added.connect(_found)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_found): get_tree().node_added.disconnect(_found)
	for p: AudioStreamPlayer3D in _voices: p.stop()
	_singing.clear()
	_answers.clear()

func _found(node: Node) -> void:
	if not node is MeshInstance3D: return
	var material := (node as MeshInstance3D).material_override as ShaderMaterial
	if material == null or material.shader == null: return
	var path := material.shader.resource_path
	if path == FALL_SHADER or path == THREAD_SHADER: falls.append([node,path == THREAD_SHADER])

# --- The bird day -------------------------------------------------------------------

## The DAY curve at `phase`: [singing, chorus].
static func activity(phase: float) -> Vector2:
	phase = fposmod(phase,1.0)
	for i in range(DAY.size()-1):
		var a: Array = DAY[i]
		var b: Array = DAY[i+1]
		if phase <= float(b[0]):
			var k := (phase-float(a[0]))/maxf(float(b[0])-float(a[0]),0.0001)
			return Vector2(lerpf(a[1],b[1],k),lerpf(a[2],b[2],k))
	return Vector2.ZERO

func _phase() -> float:
	var celestial: Variant = isle.get("_celestial")
	if celestial == null: return 0.4
	return float(celestial.phase)

func _cold() -> float:
	var celestial: Variant = isle.get("_celestial")
	return clampf(float(celestial.cold),0.0,1.0) if celestial != null else 0.0

## Every frame (kit_audio.gd `_ambience`): `daylight` 0 to 1, `open` the
## cloud sea's muffle let through, `rain` 0 to 1.
func step(delta: float, listener: Vector3, daylight: float, open: float, rain: float) -> void:
	var day := activity(_phase())
	# Daylight dims the songs in a storm's dark too.
	var lit := smoothstep(0.15,0.45,daylight)
	singing = day.x*lit*(1.0-0.6*rain)
	chorus_level = day.y*lit*(1.0-0.7*rain)
	var near: float = audio.isle_near
	var green: float = audio.green
	var leafy := clampf(green*2.0,0.3,1.0)
	# Birds fade with the isle's nearness: open sky stays airy.
	var reach := near*near
	chorus.goal = CHORUS*chorus_level*leafy*reach*open
	chorus.pitch_goal = 1.0
	_songs_step(delta,listener,reach*open,leafy)
	_chat(delta,listener,open)
	_wings(listener,open)
	_raven_step(delta,listener,lit,reach*open)
	_bees(listener,daylight,open,rain)
	var cold := _cold()
	var warm := 1.0-smoothstep(0.25,0.6,cold)
	night = 1.0-smoothstep(0.18,0.55,daylight)
	_crickets_step(delta,listener,night*warm*near*open,cold)
	var dusk := maxf(1.0-smoothstep(0.2,0.55,daylight),0.8*smoothstep(0.15,0.6,rain))
	_frogs_step(delta,listener,dusk*(1.0-smoothstep(0.3,0.65,cold))*open)
	_falls(listener,open)
	_fade(delta)

func _songs_step(delta: float, listener: Vector3, reach: float, leafy: float) -> void:
	_song_wait -= delta
	for i in range(_answers.size()-1,-1,-1):
		var a: Array = _answers[i]
		a[0] -= delta
		if a[0] <= 0.0:
			_answers.remove_at(i)
			if reach > 0.05: _sing(a[1],a[2],a[3],a[4])
	if _song_wait > 0.0: return
	var busy := singing
	_song_wait = lerpf(_rng.randf_range(SONG_GAP_QUIET.x,SONG_GAP_QUIET.y),_rng.randf_range(SONG_GAP_BUSY.x,SONG_GAP_BUSY.y),busy)
	if busy < 0.05 or reach < 0.08 or audio.muffle > 0.5: return
	var song: AudioStream = _songs[_rng.randi_range(0,_songs.size()-1)]
	var at := singer(listener)
	var gain := _rng.randf_range(SONG_GAIN.x,SONG_GAIN.y)*reach*lerpf(0.6,1.0,leafy)
	var pitch := _rng.randf_range(0.93,1.07)
	_sing(song,at,gain,pitch)
	# Another of its kind answers from across the isle.
	if _rng.randf() < ANSWER*(0.5+busy):
		var other := at+Vector3.FORWARD.rotated(Vector3.UP,_rng.randf()*TAU)*_rng.randf_range(ANSWER_FROM.x,ANSWER_FROM.y)
		_answers.append([_rng.randf_range(1.8,4.0),song,other,gain*_rng.randf_range(0.6,0.95),pitch*_rng.randf_range(0.96,1.04)])

## An excerpt of `song` at `at`: from a random point, faded out after a few
## seconds, so the same recording comes back as different phrases.
func _sing(song: AudioStream, at: Vector3, gain: float, pitch: float) -> void:
	var player: AudioStreamPlayer3D = null
	for p in _voices:
		if not p.playing:
			player = p
			break
	if player == null: return
	var length := song.get_length()
	var take := minf(_rng.randf_range(SONG_LENGTH.x,SONG_LENGTH.y),length)
	var from := _rng.randf_range(0.0,maxf(length-take,0.0))
	player.stream = song
	player.global_position = at
	player.volume_db = linear_to_db(maxf(gain,0.0001))
	player.pitch_scale = pitch
	player.play(from)
	_singing.append([player,take/pitch,gain])
	audio.played["song"] = int(audio.played.get("song",0))+1

## The songs' tails: faded out over their last second.
func _fade(delta: float) -> void:
	for i in range(_singing.size()-1,-1,-1):
		var s: Array = _singing[i]
		s[1] -= delta
		var p: AudioStreamPlayer3D = s[0]
		if s[1] <= 0.0 or not p.playing:
			p.stop()
			_singing.remove_at(i)
		elif s[1] < 1.0:
			p.volume_db = linear_to_db(maxf(float(s[2])*s[1],0.0001))

## Where a song comes from: one of the isle's songbirds within SONG_REACH
## m, else a spot in the green round the listener.
func singer(listener: Vector3) -> Vector3:
	var near_ones := _birds_near(listener,SONG_REACH)
	if not near_ones.is_empty() and _rng.randf() < 0.6: return (near_ones[_rng.randi_range(0,near_ones.size()-1)] as Dictionary).p
	return _spot(listener,Vector2(12.0,35.0),2.0,false)

func _flock() -> Variant:
	var life = isle.get("life")
	var flock = life.get("birds") if life != null else null
	return flock if flock != null and is_instance_valid(flock) else null

func _birds_near(listener: Vector3, reach: float, sitting := false) -> Array:
	var out := []
	var flock: Variant = _flock()
	if flock == null: return out
	for bird: Dictionary in flock.get("birds"):
		if not bird.has("p") or (bird.p as Vector3).distance_to(listener) > reach: continue
		if sitting and not str(bird.get("state","")) in ["perched","hopping","ground"]: continue
		if str(bird.get("state","")) == "gone": continue
		out.append(bird)
	return out

## A spot round the listener `r` m off, `up` m over the turf; on the grass
## when `grassy` (tried a few times).
func _spot(listener: Vector3, r: Vector2, up: float, grassy: bool) -> Vector3:
	var life = isle.get("life")
	var best := Vector3.INF
	for attempt in range(6 if grassy else 1):
		var p := Vector2(listener.x,listener.z)+Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(r.x,r.y)
		var y := listener.y
		var ok := not grassy
		if life != null and life.is_set_up():
			var g: Variant = life.ground_at(p)
			if g != null:
				y = float(g)
				if grassy and absf(y-listener.y) < 25.0 and life.grass_at(p) > 0.5: ok = true
			elif grassy: continue
		best = Vector3(p.x,y+up,p.y)
		if ok: return best
	return Vector3.INF if grassy else best

## The near birds' small talk: a chirp or a twitter from a perched one.
func _chat(delta: float, listener: Vector3, open: float) -> void:
	_chat_wait -= delta
	if _chat_wait > 0.0: return
	var sitting := _birds_near(listener,CHAT_REACH,true)
	var busy := singing*clampf(sitting.size()/4.0,0.0,1.0)
	_chat_wait = lerpf(CHAT_GAP.y*2.0,CHAT_GAP.x,busy)*_rng.randf_range(0.6,1.4)
	if sitting.is_empty() or singing < 0.05 or open < 0.4: return
	var bird: Dictionary = sitting[_rng.randi_range(0,sitting.size()-1)]
	var kind := "twitter" if _rng.randf() < 0.4 else "chirp"
	audio.shot(kind,_rng.randf_range(CHAT_GAIN.x,CHAT_GAIN.y)*open,_rng.randf_range(0.9,1.12),(bird.p as Vector3)+Vector3.UP*0.1,audio.AMBIENCE)

## Wings: birds that left a perch this frame near the listener; a flock
## bursting off together is a flurry and a few alarm chirps.
func _wings(listener: Vector3, open: float) -> void:
	var flock: Variant = _flock()
	if flock == null: return
	var off := []
	var birds: Array = flock.get("birds")
	for i in range(birds.size()):
		var bird: Dictionary = birds[i]
		var state := str(bird.get("state",""))
		var was := str(_bird_states.get(i,state))
		_bird_states[i] = state
		if was in ["perched","hopping","ground"] and state in ["flying","wheeling"] and (bird.p as Vector3).distance_to(listener) < WINGS_REACH:
			off.append(bird.p)
	if off.is_empty() or open < 0.3: return
	var centre := Vector3.ZERO
	for p: Vector3 in off: centre += p
	centre /= off.size()
	var many := off.size() >= 3
	audio.shot("wings",(WINGS.y if many else WINGS.x)*open,_rng.randf_range(0.92,1.1),centre,audio.AMBIENCE)
	if many:
		for k in range(mini(off.size(),3)):
			audio.shot("chirp",_rng.randf_range(0.05,0.09)*open,_rng.randf_range(1.1,1.3),off[k],audio.AMBIENCE)

## A raven or crow from the rock and ruins: high over the isle, off a way.
func _raven_step(delta: float, listener: Vector3, lit: float, reach: float) -> void:
	_raven_wait -= delta
	if _raven_wait > 0.0: return
	_raven_wait = _rng.randf_range(RAVEN_GAP.x,RAVEN_GAP.y)
	if lit < 0.4 or reach < 0.15: return
	var at := _spot(listener,Vector2(30.0,60.0),_rng.randf_range(8.0,22.0),false)
	var keep := _singing.size()
	_sing(_raven,at,RAVEN*reach,_rng.randf_range(0.88,1.04))
	if _singing.size() > keep: audio.played["raven"] = int(audio.played.get("raven",0))+1

# --- Bees, crickets, frogs, falls ---------------------------------------------------

## The flower patches' middles (kit_life.gd's meadows), read once they stand.
func _meadows() -> Array:
	if _meadows_read: return _meadow_spots
	var life = isle.get("life")
	if life == null or not life.is_set_up(): return _meadow_spots
	_meadows_read = true
	for meadow: Node in life.get("meadows"):
		var survey = meadow.get("survey")
		if survey == null: continue
		var spots: PackedVector2Array = survey.flower_spots
		if spots.is_empty(): continue
		var mid := Vector2.ZERO
		for s in spots: mid += s
		mid /= spots.size()
		var g: Variant = life.ground_at(mid)
		if g != null: _meadow_spots.append(Vector3(mid.x,float(g)+0.6,mid.y))
	return _meadow_spots

func _bees(listener: Vector3, daylight: float, open: float, rain: float) -> void:
	var best := Vector3.INF
	var d := INF
	for p: Vector3 in _meadows():
		var e := p.distance_to(listener)
		if e < d:
			d = e
			best = p
	if best == Vector3.INF or d > BEES_REACH:
		bees.goal = 0.0
		return
	(bees.player as Node3D).global_position = best
	bees.goal = BEES*smoothstep(0.45,0.75,daylight)*(1.0-rain)*open

## The crickets: each voice on a grassy spot round the listener (a new one
## once he has left it behind), its chirps scheduled a pulse train at a
## time, quiet as he comes within CRICKET_HUSH m of it.
func _crickets_step(delta: float, listener: Vector3, on: float, cold: float) -> void:
	var slow := 1.0+1.6*cold
	var take := 0
	for k in range(CRICKET_SLOW.size()):
		if absf(float(CRICKET_SLOW[k])-slow) < absf(float(CRICKET_SLOW[take])-slow): take = k
	for c: Dictionary in _crickets:
		var p: AudioStreamPlayer3D = c.player
		if on < 0.02:
			c.at = Vector3.INF
			continue
		if c.at == Vector3.INF or (c.at as Vector3).distance_to(listener) > CRICKET_SPOT.y*1.6:
			c.at = _spot(listener,CRICKET_SPOT,0.1,true)
			if c.at == Vector3.INF: continue
			p.global_position = c.at
		var dist := (c.at as Vector3).distance_to(listener)
		var want := 0.0 if dist < CRICKET_HUSH else 1.0
		c.hush = lerpf(c.hush,want,1.0-exp(-delta/(CRICKET_TAU.x if want < c.hush else CRICKET_TAU.y)))
		c.next -= delta
		if c.next > 0.0: continue
		var pulses := _rng.randi_range(3,4)
		c.next = pulses*0.055*slow+_rng.randf_range(0.25,1.15)*slow
		if c.hush < 0.03: continue
		p.stream = _cricket_takes["%d-%d" % [pulses,take]]
		p.pitch_scale = c.pitch
		p.volume_db = linear_to_db(CRICKET*on*c.hush)
		p.play()
		audio.played["cricket"] = int(audio.played.get("cricket",0))+1

## The frogs: on the nearest wide pool's banks (kit_audio.gd `pond_rect`).
func _frogs_step(delta: float, listener: Vector3, on: float) -> void:
	var rect: Rect2 = audio.pond_rect
	var top: float = audio.pond_top
	var far := rect.size == Vector2.ZERO or Vector3(clampf(listener.x,rect.position.x,rect.end.x),top,clampf(listener.z,rect.position.y,rect.end.y)).distance_to(listener) > FROG_REACH
	for i in range(_frogs.size()):
		var f: Dictionary = _frogs[i]
		if on < 0.02 or far:
			f.at = Vector3.INF
			continue
		if f.at == Vector3.INF or not rect.grow(1.5).has_point(Vector2(f.at.x,f.at.z)):
			# A bank spot: round the pool's rim.
			var u := _rng.randf()
			var e := rect.position
			match i%4:
				0: e += Vector2(rect.size.x*u,0.0)
				1: e += Vector2(rect.size.x*u,rect.size.y)
				2: e += Vector2(0.0,rect.size.y*u)
				_: e += Vector2(rect.size.x,rect.size.y*u)
			f.at = Vector3(e.x,top+0.1,e.y)
			(f.player as AudioStreamPlayer3D).global_position = f.at
		f.next -= delta
		if f.next > 0.0: continue
		var take: AudioStream = _frog_takes[(int(f.take)+(1 if _rng.randf() < 0.2 else 0))%_frog_takes.size()]
		f.next = take.get_length()+_rng.randf_range(1.4,5.9)/(0.4+on)
		var p: AudioStreamPlayer3D = f.player
		p.stream = take
		p.pitch_scale = _rng.randf_range(0.96,1.04)
		p.volume_db = linear_to_db(FROG*on)
		p.play()
		audio.played["frog"] = int(audio.played.get("frog",0))+1

## The falls: each fall's line (its bounds' middle, top to bottom), the
## nearest point on it to the listener; the nearest roars and spills get
## the beds there, by the fall's size.
func _falls(listener: Vector3, open: float) -> void:
	var roars := []
	var spills := []
	for i in range(falls.size()-1,-1,-1):
		var node: Variant = falls[i][0]
		if not is_instance_valid(node):
			falls.remove_at(i)
			continue
		var mesh := node as MeshInstance3D
		if not mesh.is_inside_tree() or not mesh.is_visible_in_tree(): continue
		var box := mesh.custom_aabb
		if box.size == Vector3.ZERO: continue
		box = mesh.global_transform*box
		var mid := box.get_center()
		var top := Vector3(mid.x,box.end.y,mid.z)
		var bottom := Vector3(mid.x,box.position.y,mid.z)
		var at := Geometry3D.get_closest_point_to_segment(listener,top,bottom)
		var d := at.distance_to(listener)
		var width := maxf(box.size.x,box.size.z)
		var thread: bool = falls[i][1]
		# A channel's thin spill (ruin_kit_aqueduct.gd "Spill") patters; a
		# curtain off an isle's lip, or its thread to the sea, roars.
		var big := thread or (str(node.name) != "Spill" and (width > 2.5 or box.size.y > 12.0))
		var strength := clampf(box.size.y/25.0,0.35,1.0)*(0.55 if thread else 1.0)
		if big and d < ROAR_REACH: roars.append([d,at,strength])
		elif not big and d < SPILL_REACH: spills.append([d,at,strength])
	roars.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	spills.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in range(_roars.size()):
		var bed = _roars[k]
		if k < roars.size():
			(bed.player as Node3D).global_position = roars[k][1]
			bed.goal = ROAR*float(roars[k][2])*lerpf(0.5,1.0,open)
		else: bed.goal = 0.0
	for k in range(_spills.size()):
		var bed = _spills[k]
		if k < spills.size():
			(bed.player as Node3D).global_position = spills[k][1]
			bed.goal = SPILL*float(spills[k][2])*lerpf(0.5,1.0,open)
		else: bed.goal = 0.0
