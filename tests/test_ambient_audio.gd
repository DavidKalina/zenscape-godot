extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	# Spatial playback starts on the physics tick, after the node's _ready.
	await physics_frame
	await process_frame
	var ambience = scene._ambient_audio
	var calm: Vector3 = ambience.target_gains(0.4,0,0,0,1,1)
	var rain: Vector3 = ambience.target_gains(2,1,0,0,1,1)
	var frozen: Vector3 = ambience.target_gains(2,1,1,1,1,1)
	check(rain.x > calm.x and rain.y > calm.y,"Wind and rain increase the native mix")
	check(frozen.y == 0.0 and frozen.z == 0.0,"Snow is quiet and frozen falls stop")
	check(ambience.target_gains(1,0,0,0,1,0).z == 0.0,"Empty water has no waterfall sound")
	check(ambience.target_gains(1,0,0,0,0.5,1).z == 0.0,"Unfinished land has no floating waterfall sound")
	ambience.update_state(1.0,false,2,1,0,0,1,1)
	var before: Vector3 = ambience.gains
	ambience.update_state(1.0,true,0,0,1,1,1,1)
	check(ambience.gains == before,"Pause freezes mix envelopes")
	for player in [ambience.wind_player,ambience.rain_player,ambience.water_player]:
		check(player.stream_paused,"Pause stops each audio stream")
		check(player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and player.stream.loop_end > 0,"Native bed is a populated looping stream")
	ambience.muted = true
	ambience.update_state(0.1,false,2,1,0,0,1,1)
	check(ambience.wind_player.stream_paused and ambience.rain_player.stream_paused and ambience.water_player.stream_paused,"Ambient mute covers every bed")
	ambience.muted = false
	ambience.update_state(0.1,false,2,1,0,0,1,1)
	check(not ambience.water_player.stream_paused,"Unmuting resumes ambience")
	scene.queue_free()
	await process_frame
	print("PASS: ambience weather, growth, loops, pause and mute" if failures == 0 else "FAIL: ambience")
	quit(1 if failures else 0)
