extends Node
## Wildlife is a property of the hour, independent of visible animal actors.
const SONGS := ["chickadee","kinglet","bluebird","robin","jay-1","jay-2"]
var clips := {}
var beds := {}
var calls: Array[Dictionary] = []
var steps: Array[AudioStreamPlayer3D] = []
var step_clips: Array[AudioStream] = []
var rng := RandomNumberGenerator.new()
var song_in := 2.0
var owl_in := 8.0
var flight_in := 15.0
var paused := false
var muted := false
var volume := 0.55
## Set by scripts/genesis_audio.gd on blank worlds, so the Genesis plain's
## wildlife follows what exists there: songs need woods or birds, crickets
## need cover, frogs need frogs. 1 (as before) everywhere else.
var song_presence := 1.0
var cricket_presence := 1.0
var frog_presence := 1.0
## When set, songs come from these points (the woods) instead of around the listener.
var song_points := PackedVector3Array()

func _ready() -> void:
	rng.randomize()
	for name in SONGS + ["hermit-thrush","owl","raven","nutcracker"]:
		clips[name] = load("res://assets/audio/"+name+".mp3")
	for name in ["stream","shore","cricket","frog"]:
		var player := AudioStreamPlayer3D.new()
		player.stream = get_parent().loop(name)
		player.unit_size = 10.0
		player.max_distance = 100.0
		player.volume_db = -80.0
		add_child(player)
		player.play()
		beds[name] = player
	for i in range(4):
		step_clips.append(load("res://assets/audio/footstep-%d.wav" % (i+1)))
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 5.0
		player.max_distance = 28.0
		add_child(player)
		steps.append(player)

func footstep(point: Vector3) -> void:
	if paused or muted: return
	for player in steps:
		if player.playing: continue
		player.global_position = point
		player.stream = step_clips[rng.randi_range(0,step_clips.size()-1)]
		player.pitch_scale = rng.randf_range(0.92,1.08)
		player.volume_db = linear_to_db(maxf(0.0001,volume*0.7))
		player.play()
		return

func call_bird(name: String, point: Vector3, gain: float) -> void:
	if paused or muted or calls.size() >= 3: return
	var player := AudioStreamPlayer3D.new()
	player.stream = clips[name]
	player.unit_size = 12.0
	player.max_distance = 100.0
	player.volume_db = -80.0
	add_child(player)
	player.global_position = point
	var length := minf(player.stream.get_length(),rng.randf_range(4.0,8.0))
	player.play(rng.randf_range(0.0,maxf(0.0,player.stream.get_length()-length)))
	calls.append({"player":player,"age":0.0,"length":length,"gain":gain})

func update_state(delta: float, stopped: bool, silence: bool, level: float, daylight: float, cold: float, rain: float, wind: float, ice: float, growth: float, water_growth: float, listener: Vector3, water_points: Dictionary) -> void:
	paused = stopped
	muted = silence
	volume = level
	var dt := maxf(delta,0.0) if not paused and not muted else 0.0
	for player in steps:
		player.stream_paused = paused or muted
		player.volume_db = linear_to_db(maxf(0.0001,volume*0.7))
	for i in range(calls.size()-1,-1,-1):
		var call: Dictionary = calls[i]
		call.age += dt
		var player: AudioStreamPlayer3D = call.player
		if call.age >= call.length:
			player.queue_free()
			calls.remove_at(i)
			continue
		player.stream_paused = paused or muted
		var fade := minf(clampf(call.age/0.3,0.0,1.0),clampf((call.length-call.age)/0.5,0.0,1.0))
		player.volume_db = linear_to_db(maxf(0.0001,call.gain*fade*volume))
	var night := 1.0-smoothstep(0.18,0.55,daylight)
	var warm := 1.0-smoothstep(0.25,0.6,cold)
	for name in beds:
		var player: AudioStreamPlayer3D = beds[name]
		var gain := 0.0
		var point := listener+Vector3(-6,0,-9)
		if name == "cricket": gain = 0.22*night*warm*growth*cricket_presence
		elif name == "frog":
			gain = 0.18*maxf(night,rain*0.8)*warm*water_growth*frog_presence if water_points.has("shore") else 0.0
			point = water_points.get("shore",point)
		elif water_points.has(name):
			point = water_points[name]
			gain = (0.5 if name == "stream" else 0.45*(0.25+0.75*smoothstep(0.15,2.2,wind)))*water_growth*(1.0-smoothstep(0.2,0.85,ice))
		player.global_position = point
		player.stream_paused = paused or muted
		player.volume_db = linear_to_db(maxf(0.0001,gain*volume))
		if name == "cricket": player.pitch_scale = lerpf(1.0,0.65,cold)
	if dt <= 0.0 or growth <= 0.0: return
	song_in -= dt
	owl_in -= dt
	flight_in -= dt
	var point := listener+Vector3(rng.randf_range(-12,12),rng.randf_range(-1,3),-10)
	if not song_points.is_empty(): point = song_points[rng.randi_range(0,song_points.size()-1)]
	# A sparse world skips most of its chances to sing, rather than singing quieter.
	var sings := rng.randf() < song_presence
	if daylight > 0.12 and song_in <= 0.0:
		var dusk := (1.0-smoothstep(0.35,0.6,daylight))*smoothstep(0.1,0.3,daylight)
		if sings: call_bird("hermit-thrush" if rng.randf() < dusk else SONGS[rng.randi_range(0,SONGS.size()-1)],point,0.32)
		song_in = rng.randf_range(6,20)
	if daylight < 0.165 and owl_in <= 0.0:
		if sings: call_bird("owl",point,0.38)
		owl_in = rng.randf_range(30,90)
	if daylight > 0.3 and flight_in <= 0.0:
		if sings: call_bird("raven" if rng.randf()<0.5 else "nutcracker",point,0.28)
		flight_in = rng.randf_range(25,55)
