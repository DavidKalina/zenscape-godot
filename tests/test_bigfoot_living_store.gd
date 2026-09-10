extends SceneTree
## Cross-scene contract: saved study terrain becomes editable main-game props,
## while the same living controller keeps resource and actor ownership.
const DT := 1.0 / 60.0
var failures := 0
var scene: Node
var living: RefCounted

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

func tick(seconds: float, until: Callable = Callable()) -> bool:
	for frame in range(ceili(seconds / DT)):
		if until.is_valid() and until.call(): return true
		scene.routine._next_action = INF
		scene._process(DT)
	return until.is_valid() and until.call()

func idle() -> bool:
	return living.current.is_empty() and scene.routine.active.is_empty() and scene.routine.cave.phase.is_empty()

func equivalent(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not equivalent(a[index], b[index]): return false
		return true
	return a == b

func settle_main_navigation() -> bool:
	for frame in range(600):
		scene.routine._next_action = INF
		scene._process(DT)
		await process_frame
		if not scene.world_play._world_dirty and not scene._habitat_changed and not scene.navigation.rebuilding: return true
	return false

func prepare() -> void:
	scene.set_process(false)
	scene._paused = false
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.replaying = false
	scene._growth.publish()
	scene._precipitation.set_weather(0, true)
	scene.routine._next_action = INF
	living = scene.routine.living

func material_target() -> Dictionary:
	var origin: Vector3 = scene.creature.position
	print("MAIN MATERIALS: origin=", origin, " count=", living._material_targets().size(), " cave=", not scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0]).is_empty())
	# Prefer a tree reachable from the actual reopened position. No terrain or
	# route mocks: both the collection stance and return path must be navigable.
	for item: Dictionary in living._material_targets():
		if not str(item.id).begins_with("object:") or origin.distance_to(item.position) > 11.0: continue
		var route: PackedVector3Array = scene.brain._approach_route(item.position)
		print("TREE CANDIDATE: ", item.id, " position=", item.position, " route=", route.size(), " stance=", not route.is_empty() and scene.routine._rest_stance(route[-1]))
		if route.is_empty() or not scene.routine._rest_stance(route[-1]): continue
		scene.creature.reset_at(route[-1])
		var home: Dictionary = scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0])
		scene.creature.reset_at(origin)
		if not home.is_empty(): return item
	return {}

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: quit(2))
	var folder := "/private/tmp/bigfoot-living-store-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	scene = load("res://studies/bigfoot_living_world.tscn").instantiate()
	root.add_child(scene)
	prepare()
	living.mind.hunger = 0.42
	living.mind.observe("known-cave-rock", scene.creature.position, "rock")
	living.mind.completed("investigate", {"target_id": "known-cave-rock"})
	var known_tree := {}
	for item: Dictionary in living._material_targets():
		if str(item.id).begins_with("mesh-8:") and scene.creature.position.distance_to(item.position) < 7.0:
			known_tree = item
			break
	check(not known_tree.is_empty(), "Study fixture can remember a real reference tree before migration")
	if not known_tree.is_empty():
		living.mind.observe(known_tree.id, known_tree.position, "tree")
		living.mind.completed("investigate", {"target_id": known_tree.id})
	scene.lair.restore_stash(["leaves", "branch"])
	check(scene.lair.tend_bed() and scene.lair.arrange_stone(), "Study fixture has persistent bedding and a stone arrangement")
	var study_mind: Dictionary = scene.capture_living_state()
	var study_room: Dictionary = scene.capture_cave_state()
	scene._chunk_editor.save_path = folder + "/living-study.json"
	check(scene._chunk_editor.save_garden(), "The new living study saves through the real garden serializer")
	scene.queue_free()
	await process_frame
	RenderingServer.force_draw(false)

	scene = load("res://studies/diorama.tscn").instantiate()
	scene.library_path = folder
	scene.recent_file = folder + "/recent.cfg"
	scene.title_seed = 37
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.set_process(false)
	check(scene.open_path(folder + "/living-study.json"), "A saved living study opens in the actual main Diorama")
	prepare()
	var expected_mind: Dictionary = study_mind.duplicate(true)
	if not known_tree.is_empty():
		var migrated_id := ""
		for memory: Dictionary in living.mind.memories:
			if memory.category == "tree" and str(memory.id).begins_with("object:"): migrated_id = memory.id
		check(not migrated_id.is_empty() and is_equal_approx(living.mind.familiarity(migrated_id), 0.34) and living.mind.familiarity(known_tree.id) == 0.0, "Reference-tree migration preserves familiarity under the new editable-object identity")
		for memory: Dictionary in expected_mind.mind.memories:
			if memory.id == known_tree.id: memory.id = migrated_id
	check(equivalent(scene.capture_living_state(), expected_mind) and equivalent(scene.capture_cave_state(), study_room), "Study-to-main loading retains needs, memory contents and timestamps, bedding, supplies and stones")
	check(scene.resident_enabled and scene.world_play.owner_scene == scene, "The reopened resident uses the main game's physical interaction owner")
	check(await settle_main_navigation(), "Editable-prop migration finishes rebuilding the actual navigation graph")
	check(scene.world_play.mischief_candidates("tree").is_empty() and scene.world_play.mischief_candidates("rock").is_empty(), "Legacy autonomous mischief yields to enabled needs-based behavior")
	var selected := material_target()
	check(not selected.is_empty(), "Migrated editable trees provide a reachable collection stance and cave return")
	if not selected.is_empty():
		var start: Vector3 = scene.creature.position
		var original_bed: int = scene.lair.bed_stage
		var original_stash: Array = scene.lair.stash.duplicate()
		check(living.request("gather", selected), "The main-game controller accepts a migrated editable tree")
		check(scene.world_play.mischief_candidates("tree").is_empty() and scene.world_play.mischief_candidates("rock").is_empty(), "Physical mischief cannot take over while a living activity owns the resident")
		check(tick(45.0, func() -> bool: return living.phase == "surface_perform"), "Gathering reaches the tree and performs the actual collection gesture")
		check(scene.creature.action_clip in ["SitDown", "Sit", "StandUp"], "Editable-tree collection uses authored actor animation")
		check(tick(20.0, func() -> bool: return scene.routine.foraging.carrying()), "The collection gesture transfers a visible branch to the existing carry contract")
		# Drive the actual drag handler after pointer-down has established a hit.
		scene._resident_play.pressed = true
		scene._resident_play.press_at = Vector2(400, 300)
		var drag := InputEventMouseMotion.new()
		drag.position = Vector2(410, 300)
		check(scene._resident_play.handle(drag), "Main-game resident dragging accepts the pickup gesture")
		tick(0.2)
		check(scene._resident_play.carrying and scene.creature.is_held() and idle() and not scene.routine.foraging.carrying(), "Player pickup owns the actor and cancels the unfinished resource carry")
		check(scene.lair.bed_stage == original_bed and scene.lair.stash == original_stash, "Interrupted gathering deposits no branch and awards no bedding improvement")
		scene._resident_play.carrying = false
		scene._resident_play.pressed = false
		scene.creature.reset_at(start)
		check(living.request("gather", selected), "The same editable tree remains usable after pickup cancellation")
		check(tick(100.0, idle), "Gathering, cave delivery, bedding work and surface return complete in the main game")
		check("gather" in living.completed_actions and "tend" in living.completed_actions and scene.lair.bed_stage == original_bed + 1, "Main-game delivery produces one lasting bedding improvement")
		check(scene.lair.stash == original_stash and not scene.routine.foraging.carrying(), "One collected branch is consumed once without duplicating the original supplies")
		check(scene.navigation.is_safe(scene.creature.position) and not scene.world_play.mischief.busy(), "The completed main-game loop returns a safe resident without competing ownership")

	var saved_mind: Dictionary = scene.capture_living_state()
	var saved_room: Dictionary = scene.capture_cave_state()
	scene._chunk_editor.save_path = folder + "/living-main.json"
	check(scene.save_current(), "The main game saves the evolved living world")
	check(scene.open_path(folder + "/living-main.json"), "The main game reopens its evolved living world")
	prepare()
	check(equivalent(scene.capture_living_state(), saved_mind) and equivalent(scene.capture_cave_state(), saved_room), "Actual second save/reopen preserves evolved needs, learned memories and room consequences")
	check(await settle_main_navigation(), "Reopened main-game terrain finishes navigation restoration")
	check(idle() and scene.navigation.is_safe(scene.creature.position), "Reopening starts with safe, unclaimed actor and cave ownership")
	scene.queue_free()
	await process_frame
	RenderingServer.force_draw(false)
	print("BIGFOOT LIVING STORE: failures=", failures)
	quit(1 if failures else 0)
