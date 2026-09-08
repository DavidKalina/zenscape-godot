extends SceneTree
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
	check(scene.creature != null,"Bigfoot spawns in the full Fidelity world")
	check(scene.navigation._nodes.size()>100,"Imported habitat has usable walkable ground")
	check(scene.habitat.waters.size()>0,"Original water surfaces are indexed")
	check(scene.habitat.solids.size()>100,"Original scenery instances are indexed")
	scene._refresh_habitat()
	# This is the movement/editor baseline; the full routine has its own day test.
	var start: Vector3 = scene.creature.position
	var traveled := 0.0
	var moves := 0
	for i in range(3600):
		var before: Vector3 = scene.creature.position
		scene.brain.advance(1.0/60.0)
		scene.creature.advance(1.0/60.0)
		traveled += before.distance_to(scene.creature.position)
		if scene.brain.phase == CreatureBrain.Phase.MOVE: moves += 1
		if not scene.navigation.is_safe(scene.creature.position):
			check(false,"Every simulated step remains on dry, clear, traversable ground")
			break
	check(traveled>18.0,"Active rhythm covers substantially more ground than the original baseline")
	check(moves>1400,"Default rhythm spends a substantial part of the minute moving")
	scene._paused = true
	var paused_at: Vector3 = scene.creature.position
	scene._process(0.05)
	check(scene.creature.position == paused_at,"Pause stops the roaming actor")
	print("FIDELITY LIFE: nodes=%d solids=%d water=%d traveled=%.2f moving_frames=%d spawn=%s failures=%d" % [scene.navigation._nodes.size(),scene.habitat.solids.size(),scene.habitat.waters.size(),traveled,moves,str(start),failures])
	scene._toggle_navigation()
	check(scene._nav_view.visible,"Walkable-ground overlay can be shown")
	scene._paused = false
	scene._chunk_editor.set_active(true)
	scene._geometry_changed()
	scene._refresh_habitat()
	check(scene.creature.visible,"Bigfoot remains present while building")
	# Place a small rock at a reachable nearby sample, just as the editor does.
	var placed_id := -1
	for turn in range(16):
		var point: Vector3 = scene.creature.position+Basis(Vector3.UP,float(turn)*TAU/16.0)*Vector3(0,0,1.8)
		var ground: Variant = scene.navigation._ground(point)
		if ground == null or absf(ground.y-scene.creature.position.y)>0.6: continue
		if scene.brain._approach_route(ground).is_empty(): continue
		placed_id = scene._chunk_editor.data.place("rock",Vector2(point.x,point.z),0.0,0.7)
		if placed_id>=0: break
	check(placed_id>=0,"A nearby boulder can be placed in the full world")
	scene._chunk_editor.refresh()
	scene._refresh_habitat()
	scene.brain.advance(1.0/60.0)
	check(scene.brain._interest_id == "object:%d" % placed_id,"New boulder immediately catches his attention")
	check(scene.brain.speed == CreatureBrain.EXCITED_SPEED,"Discovery prompts an excited approach")
	var before_sculpt: Vector3 = scene.creature.position
	var old_height: float = scene._chunk_editor.data.ground_height(Vector2(before_sculpt.x,before_sculpt.z))
	scene._chunk_editor.mode = "lower"
	scene._chunk_editor.dab(Vector2(before_sculpt.x,before_sculpt.z),0.3)
	scene._chunk_editor.refresh()
	scene._refresh_habitat()
	check(scene._chunk_editor.data.ground_height(Vector2(before_sculpt.x,before_sculpt.z)) < old_height,"Lower tool actually reduces terrain height")
	check(not scene._habitat_blocked,"Lowering ground leaves usable habitat")
	check(scene.navigation.is_safe(scene.creature.position),"Lowering ground reconciles Bigfoot's feet")
	for i in range(240):
		scene.brain.advance(1.0/60.0)
		scene.creature.advance(1.0/60.0)
	check(scene.navigation.is_safe(scene.creature.position),"Movement remains safe after live edits")
	print("FIDELITY LIVE EDITS: failures=%d" % failures)

	scene.free()
	quit(1 if failures else 0)
