extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._ui.hide()
	scene._thunder_audio.muted = true
	scene._ambient_audio.volume = 0.8
	AudioServer.add_bus()
	var bus := AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,"AmbienceReview")
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus,recorder)
	for player in [scene._ambient_audio.wind_player,scene._ambient_audio.rain_player,scene._ambient_audio.water_player]:
		player.bus = "AmbienceReview"
	recorder.set_recording_active(true)
	print("Ambience: calm, 0–4 seconds")
	await create_timer(4.0).timeout
	scene._precipitation.set_weather(1)
	print("Ambience: rain building, 4–8 seconds")
	await create_timer(4.0).timeout
	scene._paused = true
	print("Ambience: paused, 8–12 seconds")
	await create_timer(4.0).timeout
	scene._paused = false
	scene._precipitation.set_weather(3,true)
	scene._precipitation.surface_weather.ice = 1.0
	print("Ambience: frozen snowfall, 12–16 seconds")
	await create_timer(4.0).timeout
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	var result := recording.save_to_wav("res://docs/fidelity/ambient-review.wav")
	print("Ambience recording result ",result)
	scene.queue_free()
	await process_frame
	AudioServer.remove_bus(bus)
	quit(result)
