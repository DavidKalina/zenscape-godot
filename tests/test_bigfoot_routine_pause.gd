extends SceneTree
var failures := 0
var scene: Node
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
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
	check(scene.routine.request("stone"),"Can start a real stone approach")
	for i in range(1800):
		tick(1.0/60.0)
		if not scene.routine._projectiles.is_empty(): break
	check(not scene.routine._projectiles.is_empty(),"Stone reaches airborne phase")
	if not scene.routine._projectiles.is_empty():
		var projectile: Node3D = scene.routine._projectiles[0].node
		var position := projectile.position
		var clock: float = scene.routine._clock
		var age: float = scene.creature._age
		var fish_time: float = scene.fish._time
		scene._paused = true
		tick(2.0)
		check(projectile.position==position and scene.routine._clock==clock and scene.creature._age==age and scene.fish._time==fish_time,"Pause freezes actor, projectile, routine and fish")
		scene._paused = false
		tick(0.2)
		check(projectile.position!=position,"Projectile resumes after pause")
	scene.routine.cancel()
	check(scene.routine.request("hibernate"),"A reachable dry resting spot is available")
	for i in range(1800):
		tick(1.0/60.0)
		if scene.creature.action_clip == "Sleep": break
	check(scene.creature.action_clip=="Sleep","Hibernation enters sleeping loop")
	tick(0.5)
	var mark: Label3D = scene.routine._sleep_marks[0]
	var position := mark.position
	var alpha := mark.modulate.a
	var age: float = scene.creature._age
	scene._paused = true
	tick(2.0)
	check(mark.visible and mark.position==position and mark.modulate.a==alpha and scene.creature._age==age,"Pause freezes the sleep animation and drifting Zs")
	scene._paused = false
	scene._geometry_changed()
	check(scene.routine.active.is_empty() and not mark.visible,"Live editing wakes hibernation and removes Zs")
	check(scene.creature.basis.y.is_equal_approx(Vector3.UP),"Interrupted terrain-aligned rest restores upright orientation")
	print("ROUTINE PAUSE: failures=",failures)
	scene.free()
	quit(1 if failures else 0)
