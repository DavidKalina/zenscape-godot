extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._refresh_habitat()
	var routine = scene.routine
	var data = scene._chunk_editor.data
	var stones: Array = routine._targets("stone")
	check(not stones.is_empty(),"Fixture contains loose stones")
	if stones.is_empty():
		scene.free()
		quit(1)
		return
	var count: int = data.objects.size()
	routine.active = "stone"
	routine.target = stones[0]
	routine._start_performance()
	routine._grasp_stone()
	check(data.objects.size()==count-1 and routine._held != null,"Grasp transfers one actual stone out of the garden")
	data.undo()
	scene._chunk_editor.refresh()
	check(data.objects.size()==count and routine._held == null,"Undo restores the record and removes its held representation")
	routine.active = "stone"
	routine.target = routine._targets("stone")[0]
	routine._start_performance()
	routine._grasp_stone()
	routine._throw_stone()
	check(routine._projectiles.size()==1,"Throw transfers the held stone to one projectile")
	data.undo()
	scene._chunk_editor.refresh()
	check(routine._projectiles.is_empty(),"Undo cannot duplicate an airborne stone")
	routine.cancel()
	var tree: Dictionary = routine._targets("tree")[0]
	routine.active = "tree"
	routine.target = tree
	routine._start_performance()
	routine._shake_tree(1.15)
	var part: Dictionary = routine._tree_parts[0].duplicate()
	check(not part.last.is_equal_approx(part.rest),"Shaking moves the actual tree instance")
	routine.cancel()
	check(part.node.multimesh.get_instance_transform(part.index).is_equal_approx(part.rest),"Ordinary cancellation restores the tree exactly")
	routine.active = "tree"
	routine.target = tree
	routine._start_performance()
	routine._shake_tree(1.15)
	var edited: Transform3D = part.rest
	edited.origin.y += 0.2
	part.node.multimesh.set_instance_transform(part.index,edited)
	routine.world_changed()
	check(part.node.multimesh.get_instance_transform(part.index).is_equal_approx(edited),"Cancellation preserves a newer editor transform")
	part.node.multimesh.set_instance_transform(part.index,part.rest)
	var airborne := MeshInstance3D.new()
	routine.add_child(airborne)
	airborne.position = scene.creature.position+Vector3.UP*100.0
	routine._projectiles.append({"node":airborne,"velocity":Vector3.ZERO,"age":5.99,"source_id":99999,"settled":false})
	routine._advance_projectiles(0.05)
	check(routine._projectiles.size()==1,"An in-world airborne stone is not deleted by a lifetime timer")
	airborne.position.x = 15.0
	routine._advance_projectiles(0.05)
	check(routine._projectiles.is_empty(),"An old stone beyond the world is cleaned up")
	var fish = scene.fish
	check(not fish.population.is_empty(),"Pond contains actual fish")
	if not fish.population.is_empty():
		var original_count: int = fish.population.size()
		var entry: Dictionary = fish.population[0]
		entry.node.position = entry.home
		var held: Node3D = fish.catch_fish(entry.id)
		check(held == entry.node,"Catch borrows the same fish node")
		check(fish.catch_fish(entry.id)==null,"A held fish cannot be caught twice")
		fish.release_fish(entry.id)
		for i in range(60): fish.advance(1.0/60.0)
		check(fish.population.size()==original_count and not entry.held and not entry.returning,"Return preserves population and resumes swimming")
		entry.available = false
		check(fish.catch_fish(entry.id)==null,"An unavailable fish cannot be conjured")
		# Drying/removing water immediately invalidates catch and return, even
		# before the normal availability refresh has run.
		entry.available = true
		entry.node.position = entry.home
		check(fish.catch_fish(entry.id)==entry.node,"Fish can be caught again after returning")
		fish.release_fish(entry.id)
		scene.habitat.waters.clear()
		scene.habitat.ponds.clear()
		fish.advance(1.0/60.0)
		check(not entry.node.visible,"Removing water hides a returning fish immediately")
		for i in range(60): fish.advance(1.0/60.0)
		check(fish.available_targets().is_empty() and fish.catch_fish(entry.id)==null,"Empty or deleted water cannot supply fish")
	print("ROUTINE OWNERSHIP: failures=",failures)
	scene.free()
	quit(1 if failures else 0)
