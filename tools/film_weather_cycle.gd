extends SceneTree
## Accelerated climate review: rain, snow/ice, then warm clearing.
var scene: Node3D
var last_stage := -1
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._celestial.set_phase(0.35)
	scene._face_rainbow()
	process_frame.connect(step)
func step() -> void:
	if scene._processed_film_frame == scene._recorded_frames:
		return
	var frame: int = scene._recorded_frames
	var stage := 0 if frame < 180 else 1 if frame < 420 else 2
	if stage != last_stage:
		scene._precipitation.set_weather([1,3,0][stage])
		last_stage = stage
		print("Weather review stage ",stage," at frame ",frame)
	# Three ordinary simulation steps per image; the whole scene runs at 3x.
	for i in range(3):
		scene._processed_film_frame = -1
		scene._process(1.0/30.0)
	if frame % 60 == 0:
		var weather = scene._precipitation.surface_weather
		print("Weather frame ",frame," cold ",weather.cold," ice ",weather.ice," snow ",weather.snow_cover," rainbow ",scene._celestial.state.zs_bow)
