extends Node
## The original thunder clips and audio.js distance treatment, on isolated voice buses.
var volume := 0.55
var muted := false
var paused := false
var played_count := 0
var voices: Array[Dictionary] = []
var _clips: Array[AudioStream] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 17
	for i in range(1, 4):
		_clips.append(load("res://assets/audio/thunder-%d.mp3" % i) as AudioStreamMP3)

static func treatment(distance: float, energy: float) -> Vector3:
	var near := smoothstep(34.0, 6.0, distance)
	return Vector3(energy * (0.55 + 0.45 * near) * 1.1, 0.85 + 0.15 * near, 900.0 + 7000.0 * near)

func play_thunder(distance: float, energy: float) -> void:
	var mix := treatment(distance, energy)
	var player := AudioStreamPlayer.new()
	add_child(player)
	var bus_name := "ZenThunder_%d" % player.get_instance_id()
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, bus_name)
	AudioServer.set_bus_send(bus, "Master")
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = mix.z
	lowpass.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(bus, lowpass)
	var pan := AudioEffectPanner.new()
	pan.pan = _rng.randf_range(-0.5, 0.5)
	AudioServer.add_bus_effect(bus, pan)
	player.bus = bus_name
	player.stream = _clips[_rng.randi_range(0, _clips.size() - 1)]
	player.pitch_scale = mix.y
	var voice := {"player": player, "bus": bus_name, "gain": mix.x, "cutoff": mix.z}
	voices.append(voice)
	player.volume_db = linear_to_db(maxf(0.000001, mix.x * volume))
	AudioServer.set_bus_mute(bus, muted)
	player.finished.connect(_retire.bind(player))
	player.play()
	player.stream_paused = paused
	played_count += 1

func update_state(is_paused: bool) -> void:
	paused = is_paused
	for voice in voices:
		var player: AudioStreamPlayer = voice.player
		player.stream_paused = paused
		player.volume_db = linear_to_db(maxf(0.000001, voice.gain * volume))
		AudioServer.set_bus_mute(AudioServer.get_bus_index(voice.bus), muted)

func _retire(player: AudioStreamPlayer) -> void:
	for i in range(voices.size() - 1, -1, -1):
		if voices[i].player == player:
			var bus := AudioServer.get_bus_index(voices[i].bus)
			player.stop()
			if bus >= 0:
				AudioServer.remove_bus(bus)
			voices.remove_at(i)
			player.queue_free()
			return

func _exit_tree() -> void:
	for voice in voices.duplicate():
		_retire(voice.player)
