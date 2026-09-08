extends SceneTree
var failures := 0
var scene: Node
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func tick(seconds: float) -> void:
	for i in range(int(seconds*60)):
		if scene._habitat_changed: scene._refresh_habitat()
		if not scene.routine.advance(1.0/60.0): scene.brain.advance(1.0/60.0)
		scene.creature.advance(1.0/60.0)
		scene.fish.advance(1.0/60.0)
func _run() -> void:
	scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._refresh_habitat()
	print("ROUTINE WORLD initial fish=",scene.fish.population.size()," stones=",scene.routine._targets("stone").size()," trees=",scene.routine._targets("tree").size())
	check(scene.routine._targets("stone").size()>0,"World has actual loose stones")
	check(scene.routine._targets("tree").size()>0,"World has actual tree targets")
	check(scene.routine.request("stone"),"A reachable stone can be selected")
	tick(28.0)
	print("ROUTINE WORLD history=",scene.routine.history," active=",scene.routine.active," cancel=",scene.routine.last_cancel)
	check("stone" in scene.routine.history,"Stone action completes after approach")
	scene.routine.cancel()
	scene.creature.reset_at(scene.navigation.nearest_safe(scene.creature.position))
	# Direct lifecycle tests avoid depending on a particular random clearing.
	scene.routine.active = "sit"
	scene.routine._start_performance()
	tick(7.0)
	check("sit" in scene.routine.history,"Sit sequence includes standing back up")
	scene.routine.active = "sleep"
	scene.routine._start_performance()
	tick(3.0)
	check(scene.creature.action_clip == "Sleep","Settles into the sleeping loop")
	check(scene.routine._sleep_marks[0].visible,"Sleeping emits visible Zs")
	scene._geometry_changed()
	check(scene.routine.active.is_empty(),"Editing interrupts sleep")
	check(not scene.routine._sleep_marks[0].visible,"Wake cancels sleep effects")
	print("ROUTINE WORLD failures=",failures)
	scene.free()
	quit(1 if failures else 0)
