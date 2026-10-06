extends SceneTree
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func tick(nature: Node, day: float, stopped := false, muted := false, ice := 0.0, points := {}) -> void:
	nature.update_state(0.05,stopped,muted,0.55,day,ice,0.0,1.0,ice,1.0,1.0,Vector3.ZERO,points)
func clear_calls(nature: Node) -> void:
	for call in nature.calls: call.player.free()
	nature.calls.clear()
func run() -> void:
	var ambience = load("res://studies/ambient_audio.gd").new()
	root.add_child(ambience)
	await physics_frame
	await process_frame
	var nature = ambience.nature
	nature.rng.seed = 42
	check(nature.clips.size() == 10,"All ten original wildlife recordings load")
	for clip in nature.clips.values(): check(clip.get_length()>0.0,"Wildlife clip has samples")
	nature.song_in = 0.0
	nature.flight_in = 100.0
	tick(nature,1.0)
	check(nature.calls.size() == 1,"Day birds sing without any bird actors or water")
	clear_calls(nature)
	nature.song_in = 0.0
	tick(nature,0.35)
	check(nature.calls.size() == 1 and nature.calls[0].player.stream == nature.clips["hermit-thrush"],"Twilight selects the original thrush")
	clear_calls(nature)
	nature.owl_in = 0.0
	tick(nature,0.0)
	check(nature.calls.size() == 1 and nature.calls[0].player.stream == nature.clips["owl"],"Night selects the original owl")
	check(nature.owl_in >= 30.0,"Owls remain occasional")
	await physics_frame
	await process_frame
	var age: float = nature.calls[0].age
	tick(nature,0.0,true)
	check(nature.calls[0].age == age and nature.calls[0].player.stream_paused,"Pause freezes call envelopes and playback")
	for player in nature.beds.values(): check(player.stream_paused,"Pause covers every new bed")
	tick(nature,0.0,false,true)
	check(nature.calls[0].player.stream_paused,"Mute silences wildlife")
	nature.footstep(Vector3.ONE)
	for player in nature.steps: check(not player.playing,"Mute rejects new footsteps")
	tick(nature,1.0,false,false,0.0,{"stream":Vector3(2,0,0),"shore":Vector3(-2,0,0)})
	check(nature.beds.stream.volume_db > -70 and nature.beds.shore.volume_db > -70,"Streams and shores have audible gain")
	check(nature.beds.stream.global_position == Vector3(2,0,0),"Water plays at its emitter")
	tick(nature,0.0,false,false,1.0,{"stream":Vector3.ZERO,"shore":Vector3.ZERO})
	for player in nature.beds.values(): check(player.volume_db <= -79,"Ice and cold silence water and insects")
	tick(nature,1.0)
	nature.footstep(Vector3(3,0,4))
	await physics_frame
	await process_frame
	check(nature.steps[0].playing and nature.steps[0].global_position == Vector3(3,0,4),"Footstep starts at the foot")
	tick(nature,1.0,true)
	check(nature.steps[0].stream_paused,"Pause silences footsteps already playing")
	ambience.queue_free()
	await process_frame
	print("PASS: original wildlife, water, controls and footsteps" if failures == 0 else "FAIL: nature audio")
	quit(1 if failures else 0)
