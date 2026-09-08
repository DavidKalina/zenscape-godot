extends SceneTree
var failures := 0
var geometry_events := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var scene = load("res://studies/bigfoot_life.tscn").instantiate()
	root.add_child(scene)
	for i in range(3): await physics_frame
	scene.set_physics_process(false)
	scene.set_process(false)
	var editor = scene._chunk_editor
	check(not editor.update_encounter_ground, "Life scene skips unused original encounter terrain rebuilds")
	editor.play_geometry_changed.connect(func() -> void: geometry_events += 1)
	scene.toggle_build()
	scene._process(0.0)
	check(scene.building and scene.creature.is_physics_processing(), "Build keeps creature simulation enabled")
	var events := geometry_events
	editor.data.paint_grass(Vector2(8, 8), 1.0, 0.1)
	editor.refresh()
	check(geometry_events == events, "Painting grass does not rebuild physical habitat")
	var record: Dictionary = editor.data.objects[0]
	editor.select_object(record.id)
	editor.begin_selection_edit()
	editor.update_selected({"x":float(record.x)+0.2})
	check(geometry_events > events and scene._world_dirty, "Live object preview invalidates habitat before gesture ends")
	editor.end_selection_edit()
	scene._physics_process(1.0/60.0)
	check(scene._refresh_phase == 1, "Collision and navigation rebuild are separated by physics boundary")
	await physics_frame
	scene._physics_process(1.0/60.0)
	check(not scene._world_dirty and scene._refresh_phase == 0, "Navigation rebuild completes on following boundary")
	scene.creature.pick_up()
	var held: Vector3 = scene.creature.global_position
	editor.data.heights.fill(1.0)
	editor.data.ponds.clear()
	editor.refresh()
	scene._drop(Vector2(-1,-1))
	check(scene.creature.is_held(), "Pending geometry rebuild cannot release to stale fallback")
	scene._physics_process(1.0/60.0)
	await physics_frame
	scene._physics_process(1.0/60.0)
	check(scene.creature.is_held() and scene.creature.global_position == held, "Editing ground never teleports held creature")
	check(is_equal_approx(scene.creature._safe_position.y, 1.0), "Held invalid-release fallback tracks edited ground")
	# A barrier covering his feet relocates him visibly, and undo/redo updates
	# the same navigation/physics support rather than leaving ghost obstacles.
	scene.creature.reset_at(scene.creature._safe_position)
	var before_barrier: Vector3 = scene.creature.global_position
	editor.data.begin_stroke()
	editor.data.place("rock", Vector2(before_barrier.x,before_barrier.z), 0.0, 3.0)
	editor.data.end_stroke()
	editor.refresh()
	await rebuild(scene)
	check(not scene.navigation.is_safe(before_barrier), "Placed barrier blocks its occupied ground")
	check(scene.creature.global_position.distance_to(before_barrier) > 0.5 and scene._reaction.text == "!", "Forced relocation has a visible reaction")
	editor.undo()
	await rebuild(scene)
	check(scene.navigation.is_safe(before_barrier), "Undo removes barrier from live navigation")
	editor.redo()
	await rebuild(scene)
	check(not scene.navigation.is_safe(before_barrier), "Redo restores barrier in live navigation")
	# A uniformly steep floor has no valid standing cells anywhere. He waits,
	# remains pickable, and manual carrying survives the habitat returning.
	editor.data.begin_stroke()
	for i in range(editor.data.points.size()):
		editor.data.heights[i] = 12.0 + editor.data.points[i].x*0.8
	editor.data.end_stroke()
	editor.refresh()
	await rebuild(scene)
	check(scene._habitat_blocked and scene.creature.is_held() and scene._waiting_for_ground, "No safe ground enters explicit waiting state")
	scene._begin_carry(Vector2.ZERO)
	check(scene._carrying and not scene._waiting_for_ground, "Waiting creature can be manually carried")
	var held_without_ground: Vector3 = scene.creature.global_position
	scene._drop(Vector2(-1,-1))
	check(scene._carrying and scene.creature.is_held(), "No-safe-ground release remains held instead of using stale fallback")
	editor.undo()
	await rebuild(scene)
	check(not scene._habitat_blocked and scene._carrying and scene.creature.global_position == held_without_ground, "Restoring ground preserves manual carry")
	check(scene.navigation.is_safe(scene.creature._safe_position), "Restored ground replaces held fallback with safe destination")
	scene._drop(Vector2(-1,-1))
	check(not scene._carrying and scene.navigation.is_safe(scene.creature.land_position), "Invalid pointer release uses refreshed safe fallback")
	# A recovery target can become blocked even while current feet are clear.
	scene.creature.reset_at(scene.creature._safe_position)
	var destination: Vector3 = scene.navigation.nearest_safe(scene.creature.global_position+Vector3(4,0,0))
	scene.creature._recover_to = Transform3D(Basis.IDENTITY,destination)
	scene.creature.state = CreatureActor.State.RECOVERING
	editor.data.begin_stroke()
	editor.data.place("rock", Vector2(destination.x,destination.z), 0.0, 2.0)
	editor.data.end_stroke()
	editor.refresh()
	await rebuild(scene)
	check(scene.creature.state != CreatureActor.State.RECOVERING and scene.navigation.is_safe(scene.creature.global_position), "Edited recovery destination cannot finish inside a new obstacle")
	# Placement and wind recovery must share navigation's stream exclusion.
	editor.data.reset_flat()
	editor.data.streams.append({"pts":[{"x":0.0,"z":-10.0,"h":0.0},{"x":0.0,"z":10.0,"h":0.0}],"width":1.0,"depth":0.1,"surface":0.1,"capHead":false,"capTail":false})
	editor.refresh()
	await rebuild(scene)
	check(not scene.valid_landing(Vector3.ZERO) and scene._probe_safe(Vector3.ZERO) == null, "Stream rejects both held placement and wind recovery probes")
	scene.creature.reset_at(Vector3(3,0,0))
	scene.creature.pick_up()
	check(not scene.creature.release_at(Vector3.ZERO) and scene.creature.land_position == Vector3(3,0,0), "Release onto stream returns to dry fallback")
	scene.creature.reset_at(Vector3(3,0,0))
	scene.creature.wind_body.start(Transform3D(Basis.IDENTITY,Vector3.ZERO))
	scene.creature._begin_recovery()
	check(scene.creature._recover_to.origin == Vector3(3,0,0), "Wind recovery on stream chooses dry fallback")
	# R during an edit must not teleport him back to an obsolete home height.
	var before_pending_reset: Vector3 = scene.creature.global_position
	editor.data.streams.clear()
	editor.data.heights.fill(2.0)
	editor.refresh()
	scene.reset_creature()
	check(scene._reset_pending and scene.creature.global_position == before_pending_reset, "Reset is deferred while edited habitat is pending")
	await rebuild(scene)
	check(not scene._reset_pending and is_equal_approx(scene.creature.global_position.y,2.0) and scene.navigation.is_safe(scene.creature.global_position), "Deferred reset uses reconciled safe home")
	scene._show_reaction("!", "Something new")
	scene._on_creature_state(CreatureActor.State.ALERT)
	check(scene._reaction.text == "!", "Actor ALERT callback preserves brain excitement symbol")
	print("Life collision rebuild: ",scene.last_collision_rebuild_usec/1000.0," ms")
	scene.queue_free()
	await process_frame
	print("PASS Bigfoot live editor integration" if failures == 0 else "FAIL Bigfoot live editor integration")
	quit(1 if failures else 0)

func rebuild(scene: Node) -> void:
	scene._physics_process(1.0/60.0)
	await physics_frame
	scene._physics_process(1.0/60.0)
