extends SceneTree
## Unprompted four-minute routine: no action requests, teleports or clock skips.
var scene: Node
var frame := 0
var previous := ""
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._ui.visible = false
	scene._auto_orbit = false
	scene._refresh_habitat()
	process_frame.connect(_frame)
func _frame() -> void:
	frame += 1
	scene._process(1.0/60.0)
	var state: String = scene.routine.active+":"+scene.routine._phase
	if state!=previous:
		print("FILM DAY ",frame/60.0," ",state," history=",scene.routine.history)
		if scene.routine._phase == "perform": scene.frame_creature(8.0,scene.creature.rotation.y-0.65)
		previous = state
	if frame>=60*240:
		print("FILM DAY COMPLETE ",scene.routine.history)
		quit()
