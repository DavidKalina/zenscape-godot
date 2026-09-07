extends SceneTree
## One deterministic day, advancing once per captured frame.
var scene: Node3D
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	process_frame.connect(step)
func step() -> void:
	if scene._film_frames > 0 and scene._processed_film_frame == scene._recorded_frames:
		return
	var fraction: float = scene._recorded_frames / float(maxi(scene._film_frames,1))
	scene._celestial.set_phase(fposmod(0.2+fraction,1.0))
	scene._process(1.0/30.0)
