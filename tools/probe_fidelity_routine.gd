extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._refresh_habitat()
	print("NAV nodes=",scene.navigation._nodes.size()," spawn=",scene.creature.position," options=",scene.spawn_options)
	var reachable_nodes := 0
	for node in scene.navigation._nodes:
		if not scene.navigation.path(scene.creature.position,node).is_empty(): reachable_nodes += 1
	print("REACHABLE NODES ",reachable_nodes," connect=",scene.navigation._connect(scene.creature.position))
	for water in scene.habitat.waters:
		print("WATER channels=",water._stream_channels.size()," tri=",water._triangles[0])
	var deepest := 0.0
	var deep_at := Vector3.ZERO
	var shore_count := 0
	for x in range(-52,53):
		for z in range(-52,53):
			var px := float(x)*0.25
			var pz := float(z)*0.25
			var level: Variant = scene.habitat.waters[0].height_at(px,pz)
			var floor_height: Variant = scene.habitat.ground_height(Vector2(px,pz))
			if level == null or floor_height == null: continue
			if level-floor_height>deepest:
				deepest = level-floor_height
				deep_at = Vector3(px,level,pz)
			if level-floor_height>0.15 and scene.routine._plan_approach({"position":Vector3(px,level-0.08,pz)},"fish",false): shore_count += 1
	print("LAKE maxdepth=",deepest," at=",deep_at," catchable=",shore_count)
	for kind in ["stone","tree","fish"]:
		var reachable := 0
		var nearby := 0
		for item: Dictionary in scene.routine._targets(kind):
			if scene.creature.position.distance_to(item.position)>11: continue
			nearby += 1
			if scene.routine._plan_approach(item,kind):
				reachable += 1
				if kind != "tree": print("REACHABLE ",kind," ",item," stance ",scene.routine._approach_path[-1])
		print("TARGETS ",kind," total=",scene.routine._targets(kind).size()," nearby=",nearby," reachable=",reachable)
	for item: Dictionary in scene.fish.available_targets():
		print("FISH ",item," nearestsafe ",scene.navigation.nearest_safe(item.position))
	for clip in ["StoneThrow","TreeShake","FishCatch"]:
		scene.creature.cancel_action()
		scene.creature.perform_action(clip)
		scene.creature.player.seek(1.05,true)
		scene.creature.skeleton.force_update_all_bone_transforms()
		print("HAND ",clip," local=",scene.creature.to_local(scene.creature.hand_position()))
	scene.free()
	quit()
