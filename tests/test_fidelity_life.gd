extends SceneTree
## The full Fidelity world's life without a resident: its habitat is indexed,
## its pond's fish and the wind's wood are set up, a pause holds them, and a
## live edit reads the habitat again.
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	check(scene.get("creature") == null and scene.get("brain") == null and scene.get("routine") == null,"No Bigfoot is built in the Fidelity world")
	check(scene.navigation._nodes.size()>100,"Imported habitat has usable walkable ground")
	check(scene.habitat.waters.size()>0,"Original water surfaces are indexed")
	check(scene.habitat.solids.size()>100,"Original scenery instances are indexed")
	check(scene.fish != null and not scene.fish.population.is_empty(),"The pond is stocked with fish")
	check(scene.dead_wood != null,"The wind's fallen wood is set up")
	scene._refresh_habitat()
	scene._paused = false
	var started: float = scene.fish._time
	for i in range(30): scene._process(0.05)
	if scene._chunk_editor.data.blank:
		# The made plate has no authored pond: its fish stand down.
		check(not scene.fish.visible and scene.fish._time == started,"On a blank plate the authored pond's fish stand down")
	else:
		check(scene.fish._time > started,"The pond's fish swim on")
		scene._paused = true
		var paused_at: float = scene.fish._time
		for i in range(10): scene._process(0.05)
		check(scene.fish._time == paused_at,"Pause holds the fish")
		scene._paused = false
	scene._geometry_changed()
	check(scene._habitat_changed,"A live edit marks the habitat stale")
	scene._refresh_habitat()
	check(not scene._habitat_changed and scene.navigation._nodes.size()>100,"Refreshing reads the habitat again")
	print("FIDELITY LIFE: nodes=%d solids=%d water=%d fish=%d failures=%d" % [scene.navigation._nodes.size(),scene.habitat.solids.size(),scene.habitat.waters.size(),scene.fish.population.size(),failures])
	scene.free()
	quit(1 if failures else 0)
