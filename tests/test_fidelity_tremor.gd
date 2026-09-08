extends SceneTree
var failures := 0
var scene: Node
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func tick(seconds: float) -> void:
	for i in range(int(seconds*60)): scene._process(1.0/60.0)
func _run() -> void:
	scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._refresh_habitat()
	scene.routine._next_action = INF
	check(scene.routine.request("stone"),"A real stone approach can start")
	for i in range(1200):
		tick(1.0/60.0)
		if scene.routine._held != null: break
	check(scene.routine._held != null,"Fixture reaches actual stone grasp")
	var count: int = scene._chunk_editor.data.objects.size()
	scene._tremor.add(0.7)
	tick(1.0/60.0)
	check(scene.creature.state==CreatureActor.State.STUMBLING,"Full Fidelity tremor reaches Bigfoot")
	check(scene.routine.active.is_empty() and scene.routine._held==null,"Stumbling interrupts the activity and releases its held stone")
	check(scene.routine._projectiles.size()==1 and scene._chunk_editor.data.objects.size()==count,"The same stone drops without duplication")
	tick(4.0)
	check(scene.creature.can_roam() and scene.navigation.is_safe(scene.creature.position),"Recovery leaves him on safe ground")
	check(scene.routine.request("sleep"),"Can settle into a real rest after recovering")
	for i in range(1200):
		tick(1.0/60.0)
		if scene.creature.action_clip=="Sleep": break
	tick(0.1)
	check(scene.creature.action_clip=="Sleep" and scene.routine._sleep_marks[0].visible,"Fixture is asleep with Zs")
	scene._paused = true
	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.pressed = true
	scene._unhandled_input(key)
	tick(0.5)
	check(scene.creature.action_clip=="Sleep","Paused tremor does not advance the response")
	scene._paused = false
	tick(1.0/60.0)
	check(scene.creature.state==CreatureActor.State.STUMBLING,"T shortcut triggers balance loss on resume")
	check(scene.routine.active.is_empty() and not scene.routine._sleep_marks[0].visible,"Tremor wakes sleep and clears Zs")
	check(scene.creature.basis.y.is_equal_approx(Vector3.UP),"Interrupted hillside rest restores upright footing")
	tick(4.0)
	check(scene.creature.can_roam(),"Activity can resume after the wake-up stumble")
	print("Fidelity tremor: ",failures," failures")
	scene.free()
	quit(1 if failures else 0)
