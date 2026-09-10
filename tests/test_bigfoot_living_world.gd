extends SceneTree
## Native integration: choices use the actual actor, cave, supplies and fish.
## Run with Metal Forward+; dummy rendering imports a different navigation map.
const DT := 1.0 / 60.0
var failures := 0
var scene: Node
var living: RefCounted
var home_entrance: Variant = null

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
	scene.routine.cancel("prepare next independent integration case")
	if home_entrance != null: scene.creature.reset_at(home_entrance)
	var route: Dictionary = scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0])
	if route.is_empty(): return false
	home_entrance = route.entrance
	scene.creature.reset_at(route.entrance)
	return true

func complete(kind: String, target: Dictionary = {}, seconds := 100.0) -> bool:
	var before: int = living.completed_actions.count(kind)
	if not living.request(kind, target): return false
	if not tick(seconds, idle):
		print("INCOMPLETE: ", kind, " current=", living.current, " phase=", living.phase, " cave=", scene.routine.cave.phase, " clip=", scene.creature.action_clip)
		return false
	return living.completed_actions.count(kind) == before + 1

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: quit(2))
	scene = load("res://studies/bigfoot_living_world.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.replaying = false
	scene._growth.publish()
	scene._precipitation.set_weather(0, true)
	living = scene.routine.living

	# The year reaches his decisions. Pinned, checked, and handed straight back
	# so the rest of this fixture lives in the neutral opening of the calendar.
	var year: WorldClock = scene.get("world_clock")
	if year != null:
		year.season_override = 0.875
		var winter_context: Dictionary = living._context()
		check(is_equal_approx(float(winter_context.get("season", -1.0)), 0.875) and str(winter_context.get("season_name", "")) == "winter", "The decision context carries the year and names it")
		check(float(winter_context.get("cold", 0.0)) > 0.5 and is_zero_approx(float(winter_context.get("harvest", 1.0))), "Deep winter reaches him as cold, not as gold")
		year.season_override = 0.625
		var autumn_context: Dictionary = living._context()
		check(float(autumn_context.get("harvest", 0.0)) > 0.5 and is_zero_approx(float(autumn_context.get("cold", 1.0))), "Autumn reaches him as gold, not as cold")
		year.season_override = 0.125
		var spring_context: Dictionary = living._context()
		check(is_zero_approx(float(spring_context.get("cold", 1.0))) and is_zero_approx(float(spring_context.get("harvest", 1.0))) and str(spring_context.get("season_name", "")) == "spring", "Spring names itself and bends nothing")
		year.season_override = -1.0
	var original_fish: Dictionary = scene.capture_fish_state()
	check(living.enabled, "Living-world study enables needs-based choices")
	living.enabled = false
	check(at_entrance(), "Living-world cave has a reachable surface threshold")
	# Legacy stone grasp refreshes its source record while retaining actor/IK
	# ownership. An idle living controller must not undo that owner's reach.
	for autonomy in [false, true]:
		living.enabled = autonomy
		check(scene.creature.perform_action("StoneThrow", 5.0), "Another owner can start the authored grasp animation with living enabled=" + str(autonomy))
		scene.creature.reach_hand(scene.creature.hand_position() + Vector3(0.1, -0.15, 0.2), 0.9)
		var hand_targets: Dictionary = scene.creature.hand_targets.duplicate(true)
		var next_action: float = scene.routine._next_action
		living.cancel()
		check(scene.creature.hand_targets == hand_targets and scene.creature.action_clip == "StoneThrow" and scene.creature.state == CreatureActor.State.ACTION and scene.routine._next_action == next_action, "Idle living cancellation preserves another owner's grasp and scheduling with enabled=" + str(autonomy))
		scene.creature.cancel_action()
		scene.creature.clear_hand_targets()

	# Pause the production scene, not merely the model's clock.
	living.enabled = true
	living.mind.fatigue = 0.85
	check(living.request("sleep"), "A tired Bigfoot accepts a real home-rest journey")
	check(tick(30.0, func() -> bool: return scene.routine.cave.concealed), "Rest crosses the doorway into the visible room")
	var before_pause: Dictionary = living.capture()
	var pose: Transform3D = scene.creature.global_transform
	var cave_clock: float = scene.routine.cave._away
	scene._paused = true
	scene._process(5.0)
	check(living.capture() == before_pause and scene.routine.cave._away == cave_clock and scene.creature.global_transform == pose, "Pause freezes needs, cave rest and the actor together")
	scene._paused = false
	living.enabled = false
	check(tick(75.0, idle) and "sleep" in living.completed_actions, "Rest completes and releases the resident onto surface navigation")
	check(living.mind.fatigue < 0.6 and scene.navigation.is_safe(scene.creature.position), "Completed rest reduces tiredness and returns to safe ground")

	# Physical bedding completion consumes the actual stored material.
	check(at_entrance(), "Bedding fixture starts from the reachable doorway")
	scene.lair.restore_stash(["leaves", "branch"])
	var bed_before: int = scene.lair.bed_stage
	var leaves_before: int = scene.lair.bedding.get_child_count()
	check(complete("tend"), "Bigfoot enters, tends his bed and finishes the visit")
	check(scene.lair.bed_stage == bed_before + 1 and scene.lair.stash == ["branch"], "Tending consumes one material and improves persistent comfort")
	check(scene.lair.bedding.get_child_count() > leaves_before and scene.lair.stockpile.get_child_count() == 1, "The improved bed and remaining supply agree with their visible geometry")

	# Consumption cannot bring an already delivered source back into the pond.
	check(at_entrance(), "Meal fixture starts from the doorway")
	var fish: Dictionary = scene.fish.population[0]
	fish.held = true
	check(scene.lair.receive_item_checked("fish", func() -> bool: return scene.fish.store_fish(fish.id)), "Meal fixture owns one real delivered fish identity")
	living.mind.hunger = 0.9
	check(complete("eat"), "Bigfoot performs and finishes a meal at home")
	check(living.mind.hunger < 0.5 and scene.lair.food_count() == 0, "Eating consumes one stored meal and satisfies hunger")
	check(fish.stored and not fish.node.visible and fish.id in scene.fish.capture_state().stored_ids, "An eaten fish remains depleted from its original pond")

	check(at_entrance(), "Play fixture starts from the doorway")
	living.mind.enrichment = 0.9
	var play_before: int = scene.lair.play_stage
	check(complete("play"), "Bigfoot completes his authored stone-arranging performance")
	check(scene.lair.play_stage == play_before + 1 and living.mind.enrichment < 0.5, "Play changes his collection and satisfies the desire for activity")
	check(scene.lair.play_stones.get_child_count() == 3, "Stone arranging rearranges a bounded collection instead of manufacturing stones")

	# Unknown events at home remain unknown while he is outside.
	check(at_entrance(), "Observation fixture begins outside the cave")
	living.mind.disturbance_position = null
	var remembered: Array = living.capture().stash.duplicate()
	scene.lair.remove_one_supply()
	check(not living.observe_home() and living.mind.disturbance_position == null and living.capture().stash == remembered, "Supply changes outside his view do not grant remote knowledge")
	check(living.request("check_home"), "A home check physically visits the changed room")
	check(tick(30.0, func() -> bool: return scene.routine.cave.concealed), "He reaches his belongings before observing the disturbance")
	check(living.mind.disturbance_position != null, "The changed supply is recognized only after entering the cave")
	check(tick(30.0, idle) and living.mind.disturbance_position == null, "Finishing his inspection resolves the noticed disturbance")

	# Use an actual perceived terrain interest and its production approach route.
	var interest := {}
	for item: Dictionary in scene.habitat.interests:
		var safe: Variant = scene.navigation.nearest_safe(item.position + Vector3(0, 0, 3))
		if safe == null: continue
		scene.creature.reset_at(safe)
		living.perceive()
		if living._curiosity.is_empty(): continue
		if scene.brain._approach_route(living._curiosity.position).is_empty(): continue
		interest = living._curiosity.duplicate(true)
		break
	check(not interest.is_empty(), "Prepared terrain supplies a visible, reachable curiosity")
	if not interest.is_empty():
		var familiarity: float = living.mind.familiarity(interest.id)
		check(complete("investigate", interest, 65.0), "Curiosity drives an approach, look and completed investigation")
		check(living.mind.familiarity(interest.id) > familiarity, "A completed investigation makes that particular object familiar")
	check(complete("ritual", {}, 70.0), "Bigfoot walks to a comfortable outdoor spot and rests there")
	check(living.mind.favorite_position("rest") != null, "The completed ritual records a place he can revisit")

	# Picking up the actor cannot finish or reward an interrupted performance.
	check(at_entrance(), "Interruption fixture starts on safe ground")
	scene.lair.restore_stash(["leaves"])
	bed_before = scene.lair.bed_stage
	check(living.request("tend"), "A second bedding journey begins before interruption")
	check(scene.creature.pick_up(), "The real resident pickup interrupts his journey")
	tick(0.2)
	check(living.current.is_empty() and scene.routine.cave.phase.is_empty() and scene.lair.bed_stage == bed_before and scene.lair.stash == ["leaves"], "Pickup releases behavior ownership without consuming supplies or awarding comfort")
	scene.creature.reset_at(scene.routine.cave.entrance)
	check(at_entrance() and living.request("tend"), "Another tending visit begins after a cancelled journey")
	check(tick(30.0, func() -> bool: return living.phase == "interior_perform"), "Interior interruption fixture reaches the real gesture before its material contact")
	check(scene.creature.pick_up(), "Pickup can interrupt the authored interior performance")
	tick(0.2)
	check(idle() and not scene.routine.cave.hold_departure and scene.lair.bed_stage == bed_before and scene.lair.stash == ["leaves"], "Interior pickup releases cave and gesture ownership before consuming supplies")
	check(scene.creature._ground_probe == scene.navigation._ground, "Interior cancellation restores the ordinary terrain ground probe")
	scene.creature.reset_at(home_entrance)
	check(at_entrance() and living.request("play"), "A new activity can begin after pickup cancellation")
	scene._geometry_changed()
	scene._refresh_habitat()
	check(idle() and not scene.routine.cave.hold_departure and scene.navigation.is_safe(scene.creature.position), "Terrain changes cancel all activity ownership and retain a safe resident")

	# State through the real scene adapters preserves facts and memories only.
	living.enabled = true
	var saved_mind: Dictionary = scene.capture_living_state()
	var saved_room: Dictionary = scene.capture_cave_state()
	var world: Dictionary = NativeGardenStore.capture(scene)
	check(NativeGardenStore.valid(scene, world), "The actual world-save schema accepts the living state")
	var invalid: Dictionary = world.duplicate(true)
	invalid.bigfoot_living.mind.hunger = 2.0
	check(not NativeGardenStore.valid(scene, invalid), "World loading rejects out-of-range saved needs")
	invalid = world.duplicate(true)
	invalid.cave_system.living.bed_stage = 4
	check(not NativeGardenStore.valid(scene, invalid), "World loading rejects unsupported bedding stages")
	var legacy: Dictionary = world.duplicate(true)
	legacy.erase("bigfoot_living")
	legacy.cave_system.erase("living")
	check(NativeGardenStore.valid(scene, legacy), "Legacy worlds without needs or bedding state still validate")
	living.mind.hunger = 0.0
	scene.lair.disturb_bed()
	scene.restore_cave_state(saved_room)
	scene.restore_living_state(saved_mind)
	check(scene.capture_living_state() == saved_mind and scene.capture_cave_state() == saved_room, "Scene restore preserves needs, familiar objects, favorite places and home consequences")
	check(idle(), "Restore resumes from safe idle ownership instead of replaying an unfinished action")

	# A real utility choice is committed while another request is rejected.
	check(at_entrance(), "Autonomous choice fixture starts safely")
	living.mind.cooldowns.clear()
	living.mind.fatigue = 1.0
	living.mind.hunger = 0.0
	check(living.choose() and living.current == "sleep", "The enabled utility chooser selects rest for an exhausted inhabitant")
	check(not living.request("ritual") and living.current == "sleep", "A competing invitation cannot replace an activity in progress")
	scene.routine.cancel("prepare full-supply choice")
	scene.creature.reset_at(home_entrance)
	var full_supply: Array = []
	for item in range(24): full_supply.append("branch")
	scene.lair.restore_stash(full_supply)
	living._remember_home()
	living.mind.cooldowns.clear()
	living.mind.fatigue = 0.0
	living.mind.hunger = 0.0
	living.mind.enrichment = 0.0
	living.mind.disturbance_position = null
	check(living.choose() and living.current == "tend", "A full stash still lets existing bedding material motivate tending")
	scene.routine.cancel("interrupt tending before arrival")
	living.choose()
	check(living.current != "tend", "An interrupted tending choice respects its retry delay after gather remapping")
	# Let the unmodified production decision cadence run from an empty home.
	# Frame yields keep render/queued callbacks realistic without waiting five
	# wall-clock minutes. No action invitations or forced score changes occur.
	scene.routine.cancel("begin autonomous observation")
	scene.creature.reset_at(home_entrance)
	scene.restore_cave_state({"genome": saved_room.genome, "stash": [], "living": {"bed_stage": 0, "play_stage": 0}})
	scene.restore_fish_state(original_fish)
	scene.routine._cooldowns.clear()
	scene.restore_living_state({})
	living.enabled = true
	scene.routine._next_action = scene.routine._clock
	# The clock runs by default, and five minutes here is fifteen world hours:
	# left alone, night falls ninety seconds in and "Night has come" sleep
	# outranks the bed work this stretch asserts. Hold a bright morning instead.
	var day_clock: WorldClock = scene.get("world_clock")
	if day_clock != null:
		day_clock.set_time(0, 9.0)
		day_clock.running = false
	Engine.max_fps = 0
	for frame in range(20 * 300):
		scene._process(0.05)
		if frame % 600 == 0:
			print("NATURAL ", frame / 20, "s current=", living.current, " phase=", living.phase, " routine=", scene.routine.active, " cave=", scene.routine.cave.phase, " position=", scene.creature.position, " last_cancel=", scene.routine.last_cancel, " scores=", living.scores, " failed_until=", living._failed_until, " brain=", scene.brain.phase, " wait=", scene.brain._wait, " choosing=", scene.brain.choosing, " routine_clock=", scene.routine._clock, " next_action=", scene.routine._next_action, " visits=", scene.routine.cave.visits)
		await process_frame
	var observed: Array = []
	for kind: String in living.completed_actions:
		if kind not in observed: observed.append(kind)
	print("AUTONOMOUS 300s: actions=", observed, " history=", living.completed_actions, " current=", living.current, " phase=", living.phase, " needs=", [living.mind.hunger, living.mind.fatigue, living.mind.enrichment], " bed=", scene.lair.bed_stage, " stash=", scene.lair.stash)
	check(observed.size() >= 3, "Five autonomous minutes produce at least three completed activity types")
	check(scene.lair.bed_stage > 0 and "gather" in observed and "tend" in observed, "Autonomous choices gather real material and turn it into a better bed")
	check("fish" in observed and "eat" in observed and not scene.capture_fish_state().stored_ids.is_empty(), "Autonomous fishing supplies a real meal and leaves its source depleted")
	check(scene.creature.global_transform.is_finite() and living.mind.elapsed >= 299.0, "The natural loop advances needs and retains a finite resident pose")
	scene.routine.cancel("test teardown")
	scene.queue_free()
	await process_frame
	RenderingServer.force_draw(false)
	print("BIGFOOT LIVING WORLD: failures=", failures)
	quit(1 if failures else 0)
