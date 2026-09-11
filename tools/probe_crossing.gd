extends SceneTree
## Why a crossing does or does not exist, leg by leg.
##
## Prints, for each shore: where the bridgehead is in that ground's own frame,
## whether the grid has a safe node near it and how far away, whether a path
## reaches it from the walker's end, and what the deck does between the two.
## `tools/probe_island_camper.gd` is the trace for a camper who stalls; this is
## the one for a walker who never sets out.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tools/probe_crossing.gd
var scene: Node3D

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(300).timeout.connect(func() -> void:
		print("PROBE CROSSING: timed out")
		quit(2))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(640, 400)
	scene = load("res://studies/prototype_twin_chunks.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	await scene.rebuild_second_chunk()
	# The study now opens with the bridge unbuilt; these want the finished deck.
	scene.set_bridge_built(true)
	scene.set_process(false)
	scene._process(1.0 / 60.0)
	var crossing: CrossingRoute = scene.crossing
	if crossing == null:
		print("PROBE CROSSING: no link at all (camp %s, bridge %s)" % [scene.island_camps, scene.bridge])
		quit(1)
		return
	var entry: Dictionary = scene.island_camps.camps[scene.camp_id]
	_shore("chunk one", crossing, scene.chunk_world, scene.creature.global_position)
	_shore("the island", crossing, scene.island_world, scene.island_world.to_world(entry.home))
	var deck := crossing.deck_point(0.0)
	print("PROBE CROSSING deck: t0 %s, t0.5 %s, t1 %s, span %.2f" % [deck, crossing.deck_point(0.5), crossing.deck_point(1.0), crossing.span()])
	var plan := crossing.plan(scene.chunk_world, scene.creature.global_position, scene.island_world, scene.island_world.to_world(entry.home))
	print("PROBE CROSSING plan: %d steps, %.1f m" % [plan.size(), CrossingRoute.length_of(plan)])
	var camps: Node = scene.island_camps
	print("PROBE CROSSING bigfoot sent: %s" % scene.send_bigfoot_across())
	for frame in range(1200):
		scene._process(1.0 / 60.0)
		if frame % 120 == 0:
			await process_frame
		if frame % 20 == 0:
			var walk: CrossingWalk = camps.bigfoot_walk
			if walk == null:
				print("PROBE CROSSING bigfoot %4d: no walk, resident %s, at %s" % [frame, camps.world.resident, scene.creature.global_position.snapped(Vector3.ONE * 0.01)])
				break
			var probe: Variant = walk.probe().call(scene.creature.global_position)
			print("PROBE CROSSING bigfoot %4d: step %d/%d %s, at %s, target %s, state %d roam %s stall %.1f probe %s" % [
				frame, walk.index, walk.steps.size(), walk.step().space,
				scene.creature.global_position.snapped(Vector3.ONE * 0.01), walk.target().snapped(Vector3.ONE * 0.01),
				scene.creature.state, scene.creature.can_roam(), camps.bigfoot_stall, probe])
	print("PROBE CROSSING camper sent: %s" % scene.send_camper_across())
	for frame in range(0):
		scene._process(1.0 / 60.0)
		if frame % 120 == 0:
			await process_frame
		if frame % 60 == 0:
			var walk: CrossingWalk = entry.walk
			if walk == null:
				print("PROBE CROSSING %4d: no walk, shore %s, state %s, at %s" % [frame, "far" if entry.shore == scene.chunk_world else "home", entry.state, entry.actor.global_position.snapped(Vector3.ONE * 0.01)])
				break
			print("PROBE CROSSING %4d: step %d/%d %s, at %s, target %s" % [
				frame, walk.index, walk.steps.size(), walk.step().space,
				entry.actor.global_position.snapped(Vector3.ONE * 0.01), walk.target().snapped(Vector3.ONE * 0.01)])
	scene.queue_free()
	await process_frame
	quit(0)

func _shore(label: String, crossing: CrossingRoute, world: CampsiteWorld, walker: Vector3) -> void:
	var navigation: RefCounted = world.navigation
	var head_at: Vector3 = world.to_local(crossing.anchor_on(world))
	var head: Variant = navigation.nearest_safe(head_at)
	var here: Variant = navigation.nearest_safe(world.to_local(walker))
	print("PROBE CROSSING %s: rebuilding %s, walker local %s -> safe %s, bridgehead local %s -> safe %s (%s m away)" % [
		label, navigation.rebuilding, world.to_local(walker).snapped(Vector3.ONE * 0.01), here,
		head_at.snapped(Vector3.ONE * 0.01), head,
		"%.2f" % head_at.distance_to(head) if head is Vector3 else "-"])
	if head is Vector3 and here is Vector3:
		var path: PackedVector3Array = navigation.path(here, head)
		print("PROBE CROSSING %s: grid path %d points, %.1f m" % [label, path.size(), CrossingRoute.length_of([]) if path.is_empty() else _length(path)])
		if path.is_empty():
			var habitat: RefCounted = world.habitat if world.habitat != null else (scene.habitat if not label.begins_with("the island") else null)
			print("PROBE CROSSING %s: why the ground is refused, %d grid nodes" % [label, navigation._nodes.size()])
			for z in range(-13, 14):
				var line := ""
				for x in range(-13, 14):
					var at: Variant = navigation._ground(Vector3(float(x), 0.0, float(z)))
					if not at is Vector3:
						line += "?"
						continue
					var steep := false
					for offset: Vector2 in [Vector2(0.3, 0), Vector2(-0.3, 0), Vector2(0, 0.3), Vector2(0, -0.3)]:
						var height: Variant = navigation._data.ground_height(Vector2(at.x, at.z) + offset)
						if height == null or absf(height - at.y) > 0.3:
							steep = true
					if steep: line += "^"
					elif navigation._wet(at): line += "~"
					elif habitat != null and not bool(habitat.clear_at.call(at)): line += "T"
					elif navigation.is_safe(at): line += " "
					else: line += "x"
				print("  %+3d %s" % [z, line])

	print("PROBE CROSSING %s: leg to anchor %d steps, leg from anchor %d steps" % [
		label, crossing._leg_to_anchor(world, walker).size(), crossing._leg_from_anchor(world, walker).size()])

func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total
