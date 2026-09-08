extends Node
## Quiet procedural beds driven by the same weather and growth as the image.
var volume := 0.55
var muted := false
var wind_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var water_player: AudioStreamPlayer3D
var gains := Vector3.ZERO

func loop(name: String) -> AudioStreamWAV:
	var stream := (load("res://assets/audio/"+name+"-bed.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# Imported audio may be compressed; byte count is not a sample count.
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream

func _ready() -> void:
	wind_player = AudioStreamPlayer.new()
	wind_player.stream = loop("wind")
	rain_player = AudioStreamPlayer.new()
	rain_player.stream = loop("rain")
	water_player = AudioStreamPlayer3D.new()
	water_player.stream = loop("water")
	water_player.position = Vector3(4.8,0.45,-3.6)
	water_player.unit_size = 10.0
	water_player.max_distance = 100.0
	for player in [wind_player,rain_player,water_player]:
		add_child(player)
		player.volume_db = -80.0
		player.play()

static func target_gains(wind: float, rain: float, snow_phase: float, ice: float, terrain: float, water: float) -> Vector3:
	var air := pow(clampf(wind/3.0,0.0,1.0),1.5)*0.4
	var drops := pow(clampf(rain*(1.0-snow_phase),0.0,1.0),1.2)*0.24
	var flow := smoothstep(0.0,0.5,water)*(1.0-ice*ice)*0.3 if terrain >= 0.995 else 0.0
	return Vector3(air,drops,flow)

func update_state(delta: float, paused: bool, wind: float, rain: float, snow_phase: float, ice: float, terrain: float, water: float) -> void:
	var wanted := target_gains(wind,rain,snow_phase,ice,terrain,water)
	if not paused:
		gains = gains.lerp(wanted,1.0-exp(-maxf(0.0,delta)*4.0))
	wind_player.pitch_scale = 0.75+clampf(wind,0.0,3.0)*0.35
	water_player.pitch_scale = 1.0-ice*0.4
	for i in range(3):
		var player = [wind_player,rain_player,water_player][i]
		player.stream_paused = paused or muted
		player.volume_db = linear_to_db(maxf(0.0001,gains[i]*volume))
