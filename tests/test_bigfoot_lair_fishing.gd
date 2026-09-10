extends SceneTree
## End-to-end ownership of one real pond fish: authored catch, carried cave
## entry, source depletion, persisted identity, and safe cancellation.
var failures := 0
var scene: Node

func _initialize() -> void: _run.call_deferred()

func check(ok: bool,message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1

func tick(seconds: float, stop: Callable = Callable()) -> bool:
	for frame in range(ceili(seconds*60.0)):
		scene._process(1.0/60.0)
		if stop.is_valid() and stop.call(): return true
	return stop.is_valid() and stop.call()

func fish_entry(id: String) -> Dictionary:
	for entry: Dictionary in scene.fish.population:
		if entry.id == id: return entry
	return {}

func reachable_fish() -> Dictionary:
	for target: Dictionary in scene.fish.available_targets():
		for offset in [Vector3(0,0,2),Vector3(2,0,0),Vector3(0,0,-2),Vector3(-2,0,0)]:
			var nearby: Variant = scene.navigation.nearest_safe(target.position+offset)
			if nearby == null: continue
			scene.creature.reset_at(nearby)
			if not scene.routine._plan_approach(target,"fish"): continue
			var stance: Vector3 = scene.routine._approach_path[-1]
			scene.creature.reset_at(stance)
			if scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0]).is_empty(): continue
			return {"target":target,"stance":stance}
	return {}

func reset_fish(entry: Dictionary) -> void:
	scene.fish.restore_state({"version":1,"stored_ids":[]})
	entry.node.position = entry.home
	entry.available = true

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: quit(2))
	scene = load("res://studies/bigfoot_lair.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.replaying = false
	scene._growth.publish()
	scene._precipitation.set_weather(0,true)
	scene.routine._next_action = INF

	var initial_surface_position: Vector3 = scene.creature.position
	var selection := reachable_fish()
	check(not selection.is_empty(),"Prepared woodland has a navigable approach to a real pond fish")
	if selection.is_empty():
		scene.queue_free()
		await process_frame
		quit(1)
		return
	var target: Dictionary = selection.target
	check(not scene.navigation.path(initial_surface_position,selection.stance).is_empty(),"Prepared cave and selected pond shore share the surface navigation component")
	# Begin at the selected shore stance so this bounded integration test does
	# not depend on the wanderer's random route before requesting an activity.
	scene.creature.reset_at(selection.stance)
	var entry := fish_entry(target.id)
	var original_node: Node3D = entry.node
	var initial_stash: int = scene.lair.stash.size()
	check(scene.routine.request("fish",target),"Real fish target starts the authored fishing activity")
	var began_carry := tick(45.0,func() -> bool: return scene.routine.foraging.carrying())
	check(began_carry and scene.routine.active=="forage" and entry.held,"Completed FishCatch transfers the exact pond fish into carrying")
	check(scene.routine.foraging.held==original_node,"Carry keeps the caught population node")
	scene.routine.cancel("test interruption")
	check(not scene.routine.foraging.carrying() and not entry.held and entry.returning,"Cancelling the trip returns ownership to the pond")
	check(scene.lair.stash.size()==initial_stash and not entry.stored,"Cancelled fish never reaches the stockpile")
	tick(1.0)
	check(not entry.returning and entry.node==original_node and entry.available,"Returned fish resumes as the same available identity")

	# Retry the same real source and allow the entire route through the cave and
	# back out to complete.
	entry.node.position = entry.home
	check(scene.routine.request("fish",target),"Returned fish can be caught for a second real trip")
	var deposited := tick(90.0,func() -> bool: return entry.stored)
	check(deposited and scene.lair.stash.size()==initial_stash+1 and scene.lair.stash[-1]=="fish","Cave entry deposits one fish and commits source depletion")
	check(entry.node==original_node and not entry.node.visible,"Deposit retains and hides the exact source identity")
	var exited := tick(20.0,func() -> bool: return scene.routine.cave.phase.is_empty() and scene.routine.active.is_empty())
	check(exited and scene.navigation.is_safe(scene.creature.position),"Fish delivery exits the cave onto safe surface ground")
	check(scene.fish.available_targets().all(func(item: Dictionary) -> bool: return item.id != entry.id),"Stored source cannot be selected again")

	var saved: Dictionary = scene.capture_fish_state()
	check(preload("res://scripts/fidelity_fish.gd").valid_state(saved) and entry.id in saved.stored_ids,"Saved fish state records the depleted identity")
	reset_fish(entry)
	check(not entry.stored and entry.available,"Control restore can reactivate the original identity")
	scene.restore_fish_state(saved)
	check(entry.stored and not entry.available and not entry.node.visible,"Reloading fish state restores source depletion")

	scene.queue_free()
	await process_frame
	print("BIGFOOT LAIR FISHING: failures=",failures)
	quit(1 if failures else 0)
