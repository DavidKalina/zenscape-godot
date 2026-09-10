extends SceneTree
## Native integration: a storm over the real Fidelity world leaves branches on
## the actual ground, the decision context counts the ones within his reach, and
## a gather walks to one of them, picks it up and carries it into the cave.
## Run with Metal Forward+; dummy rendering imports a different navigation map.
const DT := 1.0 / 60.0
var failures := 0
var scene: Node
var living: RefCounted
var wood: Node

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

func at_entrance() -> bool:
	scene.routine.cancel("dead wood fixture repositions him at his doorway")
	var route: Dictionary = scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0])
	if route.is_empty(): return false
	scene.creature.reset_at(route.entrance)
	return true

## A branch on real walkable ground he can reach, with him standing at the far
## end of a route to it, and the whole errand kept near his cave so the carry
## home is a short authored walk. Returns the branch target, or {}.
func plant_branch() -> Dictionary:
	scene.routine.cancel("dead wood fixture plants a branch")
	var route: Dictionary = scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0])
	if route.is_empty(): return {}
	var entrance: Vector3 = route.entrance
	var near: Array[Vector3] = wood.sites.duplicate()
	near.sort_custom(func(a: Vector3, b: Vector3) -> bool: return entrance.distance_to(a) < entrance.distance_to(b))
	for site: Vector3 in near:
		if entrance.distance_to(site) > 10.0 or not scene.navigation.is_safe(site): continue
		scene.creature.reset_at(entrance)
		var path: PackedVector3Array = scene.brain._approach_route(site)
		if path.is_empty() or not scene.routine._rest_stance(path[-1]): continue
		var branch: Dictionary = wood._add_branch(site, 0.0)
		return {"id": str(branch.id), "position": site, "kind": "branch"}
	return {}

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1280, 800)
	scene = load("res://studies/bigfoot_living_world.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.replaying = false
	scene._growth.publish()
	living = scene.routine.living
	living.enabled = false
	wood = scene.get("dead_wood")
	check(wood != null, "The living-world study carries a forest floor")
	check(not wood.sites.is_empty(), "Fidelity's trees offer walkable places for wood to fall")
	check(wood.count() == 0, "It starts bare")

	# ------------------------------------------------- a storm drops real wood
	var clock: WorldClock = scene.get("world_clock")
	check(clock != null, "The living-world study inherits Fidelity's clock")
	scene._celestial.cycling = true
	clock.set_time(0, 10.0)
	clock.speed = 48.0
	check(at_entrance(), "The dead-wood fixture starts him at his doorway")
	scene._precipitation.set_weather(WeatherScheduler.preset_index("storm"), true)
	tick(6.0)
	check(wood.count() > 0, "A storm over the real world drops branches under its trees")
	var fallen: Dictionary = wood.branches[0]
	check(is_instance_valid(fallen.node) and fallen.node.visible, "Each branch is a visible trace on the ground")
	var ground: Variant = scene.habitat.ground_height(Vector2(fallen.position.x, fallen.position.z))
	check(ground != null and absf(float(ground) - fallen.position.y) < 0.5, "It lies on the terrain, not in the air")
	scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"), true)
	clock.speed = 0.0

	# ------------------------------------------------------- the context key
	for branch: Dictionary in wood.branches:
		if is_instance_valid(branch.node): branch.node.queue_free()
	wood.branches.clear()
	check(wood.count() == 0, "The gather fixture starts from a cleared floor")
	scene.lair.restore_living({"bed_stage": 1, "play_stage": 0})
	living._remember_home()
	var context: Dictionary = living._context()
	check(context.has("branches_nearby"), "The decision context carries a nearby-branch count")
	check(int(context.branches_nearby) == 0, "A bare floor reports no branches")
	var target: Dictionary = plant_branch()
	check(not target.is_empty(), "A branch can be planted on walkable ground beside him")
	context = living._context()
	check(int(context.branches_nearby) >= 1, "He counts the branch that fell within his reach")
	check(bool(context.can_gather), "Wood on the ground is something to gather")

	# ------------------------------------------------ it is the gather source
	var targets: Array = living._material_targets()
	check(not targets.is_empty(), "The gather source offers the branch")
	var only_wood := true
	for item: Dictionary in targets:
		if not str(item.id).begins_with("branch:"): only_wood = false
	check(only_wood, "With wood on the ground he no longer works the trees")
	var reason := ""
	for option: Dictionary in living.mind.ranked(context):
		if option.kind == "gather": reason = str(option.reason)
	check(reason == "Branches are down under the trees", "The mind names the fallen wood in its reason")

	# --------------------------------------------- he clears one, and it is gone
	var stash_before: int = scene.lair.stash.size()
	var bed_before: int = scene.lair.bed_stage
	check(living.request("gather", target), "He accepts the walk to a fallen branch")
	check(tick(160.0, idle), "The gather journey finishes")
	check("gather" in living.completed_actions, "The gather completes")
	check("branch" in scene.routine.history, "A branch crossed the cave threshold")
	# Arriving with wood and an unfinished bed, he may lay it straight into the
	# bedding before this fixture looks, so either outcome is a delivered branch.
	check(scene.lair.stash.size() == stash_before + 1 or scene.lair.bed_stage > bed_before, "The branch is in his stockpile, or already worked into his bed")
	check(wood.count() == 0, "And it is gone from the forest floor")
	check(living._material_targets().size() > 0, "With the floor bare again he falls back to the trees")

	# ------------------------------------------------------- the saved garden
	var saved: Dictionary = scene.capture_wood_state()
	check(preload("res://scripts/dead_wood.gd").valid_state(saved), "The scene's wood state validates")
	var planted: Dictionary = plant_branch()
	check(not planted.is_empty() and wood.count() == 1, "One more branch to save")
	saved = scene.capture_wood_state()
	scene.restore_wood_state({})
	check(wood.count() == 0, "A garden saved before dead wood restores a bare floor")
	scene.restore_wood_state(saved)
	check(wood.count() == 1 and wood.targets()[0].id == planted.id, "The saved branch comes back where it lay")

	scene.queue_free()
	await process_frame
	print("PASS: dead wood falls, shows and is gathered in the real world" if failures == 0 else "FAIL: dead wood scene")
	print("Failures: ", failures)
	quit(1 if failures else 0)
