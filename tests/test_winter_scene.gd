extends SceneTree
## Winter reaches the resident. With the Season slider pinned to deep winter the
## real living-world study fills his long drive off its own clock, the decision
## context carries the cold, the larder and the drive, and he walks into his own
## cave for the long sleep.
## Run with Metal Forward+; this loads the production living-world study:
##   Godot --path . --rendering-method forward_plus --script res://tests/test_winter_scene.gd
const DT := 1.0 / 60.0
var failures := 0
var scene: Node
var living: RefCounted

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

## Hold the ordinary activity scheduler off so the season, not a fresh choice,
## is what changes between the assertions.
func tick(seconds: float, until: Callable = Callable()) -> bool:
	for frame in range(ceili(seconds / DT)):
		if until.is_valid() and until.call(): return true
		scene.routine._next_action = INF
		scene._process(DT)
	return until.is_valid() and until.call()

## Stand him on the real surface threshold of his own cave, the way the other
## living-world fixtures do, so a journey home is a short authored walk.
func at_entrance() -> bool:
	scene.routine.cancel("winter fixture repositions him at his doorway")
	var route: Dictionary = scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0])
	if route.is_empty(): return false
	scene.creature.reset_at(route.entrance)
	return true

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
	check(clock != null, "The living-world study inherits Fidelity's clock")
	scene._celestial.cycling = true
	clock.set_time(0, 10.0)
	scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"), true)

	# A midsummer garden has no long drive at all.
	check(at_entrance(), "The living-world cave has a reachable surface threshold")
	scene.lair.restore_living({"bed_stage": 3, "play_stage": 0})
	scene.lair.restore_stash(["fish", "fish", "fish", "fish"])
	living._remember_home()
	clock.season_override = 0.5
	clock.speed = 240.0
	tick(1.0)
	var summer: Dictionary = living._context()
	check(is_zero_approx(float(summer.cold)) and is_zero_approx(float(summer.torpor)), "Midsummer keeps him wide awake")
	check(is_equal_approx(float(summer.winter_ready), 1.0), "Four meals and a finished bed are a winter's worth of stores")
	check(not _has(living.mind.ranked(summer), "hibernate"), "A summer garden never offers the long sleep")

	# The Season slider is pinned to deep winter; his own clock fills the drive.
	clock.season_override = 0.875
	tick(1.0)
	var chilled: Dictionary = living._context()
	check(chilled.has("cold") and chilled.has("torpor") and chilled.has("winter_ready"), "The decision context carries the cold, the drive and the larder")
	check(float(chilled.cold) > 0.85 and str(chilled.season_name) == "winter", "Pinning the slider puts the study in deep winter")
	check(float(chilled.torpor) > 0.0, "The drive starts filling from the scene's own world hours")
	check(tick(30.0, func() -> bool: return living.mind.torpor >= 0.75), "A few world days of cold fill the drive: %.2f" % living.mind.torpor)

	# Frozen at a clear winter noon, the long sleep is what he chooses.
	clock.set_time(clock.day, 12.0)
	clock.speed = 0.0
	scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"), true)
	scene._process(DT)
	var deep: Dictionary = living._context()
	check(float(deep.torpor) >= 0.75 and float(deep.winter_ready) > 0.9, "He faces the winter deeply drowsy and fully stocked")
	var ranked: Array[Dictionary] = living.mind.ranked(deep)
	check(not ranked.is_empty() and str(ranked[0].kind) == "hibernate", "In deep winter with the stores in he chooses the long sleep, not an errand")
	check(at_entrance(), "The long sleep starts from his doorway")
	check(living.choose() and living.current == "hibernate", "The living world accepts the choice: %s" % living.current)
	# A chosen action keeps the mind's own reason; only an invited one falls back
	# to the living world's plainer sentence.
	check(living.reason == "The year has gone cold; time to sleep it out", "He says why he is going: %s" % living.reason)
	check(tick(90.0, func() -> bool: return scene.routine.cave.concealed), "He walks in through the real cave threshold")
	check(scene.routine.cave.reason == "hibernate", "It is the cave's own long visit, not an ordinary nap")
	check(living.sheltered(), "The winter is outside and he is not")

	# The drive is saved with the rest of the living state.
	var saved: Dictionary = living.capture()
	check(float(saved.mind.torpor) >= 0.75, "The long drive rides along in the saved living state")
	check(living.valid(saved), "The saved state validates")
	living.restore(saved)
	check(living.mind.torpor >= 0.75 and living.capture().mind.torpor == saved.mind.torpor, "It round trips through a save")

	scene.queue_free()
	await process_frame
	print("PASS: winter reaches the resident" if failures == 0 else "FAIL: winter scene")
	print("Failures: ", failures)
	quit(1 if failures else 0)

func _has(actions: Array[Dictionary], kind: String) -> bool:
	for action in actions:
		if action.kind == kind: return true
	return false
