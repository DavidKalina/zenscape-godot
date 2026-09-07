extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var audio = load("res://studies/thunder_audio.gd").new()
	root.add_child(audio)
	var buses := AudioServer.bus_count
	check(audio._clips.size() == 3 and audio._clips[0].get_length() > 10.0, "Original recordings decode")
	var near: Vector3 = audio.treatment(6.0, 1.0)
	var far: Vector3 = audio.treatment(34.0, 1.0)
	check(near.is_equal_approx(Vector3(1.1, 1.0, 7900.0)), "Near source treatment")
	check(far.is_equal_approx(Vector3(0.605, 0.85, 900.0)), "Distant source treatment")
	audio.play_thunder(6, 1)
	audio.play_thunder(34, 0.7)
	check(audio.voices.size() == 2 and AudioServer.bus_count == buses + 2, "Overlapping strikes have isolated filters")
	check(audio.voices[0].player.playing and audio.voices[1].player.playing, "Both voices start")
	audio.update_state(true)
	check(audio.voices[0].player.stream_paused and audio.voices[1].player.stream_paused, "Pause holds existing thunder")
	audio.muted = true
	audio.update_state(false)
	check(not audio.voices[0].player.stream_paused and AudioServer.is_bus_mute(AudioServer.get_bus_index(audio.voices[0].bus)), "Mute keeps playback progressing silently")
	audio._retire(audio.voices[0].player)
	check(audio.voices.size() == 1 and AudioServer.bus_count == buses + 1, "Finished voice removes its bus")
	audio.queue_free()
	await process_frame
	await process_frame
	check(AudioServer.bus_count == buses, "Scene teardown restores audio buses")
	print("PASS: thunder decode, distance filtering, overlap, pause, mute and cleanup" if failures == 0 else "FAIL: thunder audio")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
