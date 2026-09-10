extends SceneTree
## The weather reaches Bigfoot. A storm he is out in works the real bedding
## loose, he is told nothing about it until he walks back into his cave, and the
## loose bed is what makes gathering worth doing again.
## Run with Metal Forward+; this loads the production living-world study.
const DT := 1.0 / 60.0
var failures := 0
var scene: Node
var living: RefCounted

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

## Hold the ordinary activity scheduler off so the weather, not a fresh choice,
## is what changes between the assertions.
func tick(seconds: float, until: Callable = Callable()) -> bool:
	for frame in range(ceili(seconds / DT)):
		if until.is_valid() and until.call(): return true
		scene.routine._next_action = INF
		scene._process(DT)
	return until.is_valid() and until.call()

func has(actions: Array[Dictionary], kind: String) -> bool:
	for action in actions:
		if action.kind == kind: return true
	return false

## Stand him on the real surface threshold of his own cave, the way the other
## living-world fixtures do, so a journey home is a short authored walk.
func at_entrance() -> bool:
	scene.routine.cancel("weather bed fixture repositions him at his doorway")
	var route: Dictionary = scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0])
	if route.is_empty(): return false
	scene.creature.reset_at(route.entrance)
	return true

func world_hour() -> float:
	var clock: WorldClock = scene.get("world_clock")
	return clock.day * 24.0 + clock.hour

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: quit(2))
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
	var clock: WorldClock = scene.get("world_clock")
	check(clock != null and scene.get("weather_scheduler") != null, "The living-world study inherits Fidelity's clock and weather")
	scene._celestial.cycling = true
	clock.set_time(0, 10.0)
	clock.speed = 48.0
	scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"), true)

	# He steps out with a full bed he has actually seen.
	check(at_entrance(), "The living-world cave has a reachable surface threshold")
	scene.lair.restore_living({"bed_stage": 3, "play_stage": 0})
	living._remember_home()
	check(scene.lair.bed_stage == 3 and living._observed_bed == 3, "He leaves home with a full bed he remembers")
	check(not living.sheltered(), "The fixture begins with him out of the cave")
	var context: Dictionary = living._context()
	check(context.get("weather", "") == "clear" and context.has("wet") and context.get("sheltered") == false, "The decision context carries the sky, the wet ground and whether he is under cover")
	var calm_from := world_hour()
	tick(2.0)
	check(world_hour() - calm_from > 3.0, "The fixture really runs several world hours per second")
	check(scene.lair.bed_stage == 3, "A clear sky leaves his bedding alone")

	# The storm arrives while he is outside.
	scene._precipitation.set_weather(WeatherScheduler.preset_index("storm"), true)
	scene._process(DT)
	check(living._context().get("weather", "") == "storm", "The context reports the storm the scene is showing")
	var storm_from := world_hour()
	tick(2.0)
	var hours := world_hour() - storm_from
	check(hours > 4.0, "The storm fixture covers more than two disturbance intervals")
	check(scene.lair.bed_stage < 3, "A storm he is out in works his bedding loose")
	check(living._observed_bed == 3, "The disturbance never reaches him remotely")
	check(not living._context().get("material_needed", true), "Believing his bed full, he has no reason to gather yet")

	# The study's own "Check his home" invitation is the discovery path.
	check(at_entrance(), "The home visit starts from his doorway")
	check(living.request("check_home"), "He accepts an invitation to look at his belongings")
	check(tick(60.0, func() -> bool: return scene.routine.cave.concealed), "He walks in through the real cave threshold")
	check(living.sheltered() and living._context().get("sheltered") == true, "Inside the cave he counts as sheltered")
	check(living._observed_bed == scene.lair.bed_stage and living._observed_bed < 3, "He discovers the storm damage on arrival, not before")
	check(living._context().get("material_needed", false), "The loosened bed makes gathering worth doing again")
	scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"), true)
	check(has(living.mind.ranked(living._context()), "gather"), "Once the sky clears, gathering is back among his choices")

	# The accumulator is saved, and a document written before it existed loads.
	var saved: Dictionary = living.capture()
	check(saved.has("storm_hours") and float(saved.storm_hours) >= 0.0, "The storm accumulator is part of the saved living state")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("storm_hours")
	check(living.valid(legacy) and living.valid(saved), "Living states with and without the accumulator both validate")
	living.restore(legacy)
	check(float(living.capture().storm_hours) == 0.0, "A legacy document resumes with a dry accumulator")
	living.restore(saved)
	check(living.capture() == saved, "The saved accumulator round trips")
	var broken: Dictionary = saved.duplicate(true)
	broken.storm_hours = 900.0
	check(not living.valid(broken), "An out-of-range accumulator is rejected")

	scene.queue_free()
	await process_frame
	print("PASS: the weather reaches Bigfoot's bedding" if failures == 0 else "FAIL: weather bedding")
	print("Failures: ", failures)
	quit(1 if failures else 0)
