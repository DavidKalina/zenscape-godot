extends SceneTree
## The pond restocks on world time: an emptied pool refills toward its capacity
## over about two world days, faster overnight and after rain, never past the
## capacity, and the saved document carries the progress. Pure: stub scene, no
## rendering, no habitat and no wall clock.
var failures := 0
var _scenes: Array[Node] = []

const Fish := preload("res://scripts/fidelity_fish.gd")

class StubWater:
	var _stream_channels: Array = []
	func height_at(_x: float, _z: float) -> Variant: return 1.0

class StubHabitat:
	var waters: Array = [StubWater.new()]
	var ponds: Array = []
	func ground_height(_point: Vector2) -> Variant: return 0.0

class StubSurfaceWeather:
	var ground_wet := 0.0

class StubPrecipitation:
	var surface_weather := StubSurfaceWeather.new()

class StubScene extends Node:
	var habitat := StubHabitat.new()
	var world_clock: WorldClock = null
	var _precipitation: StubPrecipitation = null

func _initialize() -> void:
	# ------------------------------------------------------- seeding and slots
	var clock := WorldClock.new()
	var pond := _pond(clock)
	check(pond.capacity == 4 and pond.live_count() == 4, "Seeding fills every slot and sets the capacity")
	check(pond.available_targets().size() == 4, "Every seeded fish is a target")

	# ------------------------------------------- the base rate: two world days
	_empty(pond)
	check(pond.live_count() == 0 and pond.available_targets().is_empty(), "An emptied pond offers nothing")
	_run_world_days(pond, clock, 12.0, 1)
	check(pond.live_count() == 2, "Half the pond is back after one bright world day")
	_run_world_days(pond, clock, 12.0, 1)
	check(pond.live_count() == 4, "The pond is full again after two world days")
	check(pond.available_targets().size() == 4, "Restocked fish are catchable")
	check(pond.population.size() == 8, "Restocking spawns new identities beside the stored ones")

	# ----------------------------------------------------------- never past it
	_run_world_days(pond, clock, 12.0, 10)
	check(pond.live_count() == 4 and pond.population.size() == 8, "A full pond stops restocking")
	check(pond.restock == 0.0, "A full pond banks no progress")

	# ------------------------------------------------------- night runs faster
	var night_clock := WorldClock.new()
	var night_pond := _pond(night_clock)
	_empty(night_pond)
	_run_world_days(night_pond, night_clock, 0.0, 1)
	check(night_clock.daylight < Fish.NIGHT_DAYLIGHT, "Midnight is night by the mind's definition")
	check(night_pond.live_count() == 4, "A night refills the pond twice as fast")

	# --------------------------------------------------- rain, and its memory
	var rained := _pond(null)
	var dry := _pond(null)
	_empty(rained)
	_empty(dry)
	rained.scene._precipitation.surface_weather.ground_wet = 1.0
	for i in range(10):
		rained.advance(1.0)
		dry.advance(1.0)
	rained.scene._precipitation.surface_weather.ground_wet = 0.0
	check(rained.rain_memory > 0.0, "Rain leaves the pond a memory of itself")
	for i in range(475):
		rained.advance(1.0)
		dry.advance(1.0)
	check(dry.live_count() == 2, "A dry clockless pond keeps the same two-day rate")
	check(rained.live_count() == 3, "Rain doubles the rate for half a world day afterwards")
	check(rained.rain_memory == 0.0, "The rain bonus expires")

	# ------------------------------------------------- the year sets the pace
	var caught := {}
	for quarter: Array in [["spring", 0.125], ["summer", 0.375], ["autumn", 0.625], ["winter", 0.875]]:
		var year_clock := WorldClock.new()
		year_clock.season_override = float(quarter[1])
		var year_pond := _pond(year_clock)
		_empty(year_pond)
		_run_world_days(year_pond, year_clock, 12.0, 1)
		caught[str(quarter[0])] = year_pond.live_count()
	check(caught.spring == 2 and caught.summer == 2, "Spring and summer breed at the full two-day rate")
	check(caught.autumn == 1, "Autumn tapers to a little over half the rate")
	check(caught.winter == 0, "A single winter day is too slow to land a whole fish")
	var winter_clock := WorldClock.new()
	winter_clock.season_override = 0.875
	var winter_pond := _pond(winter_clock)
	_empty(winter_pond)
	_run_world_days(winter_pond, winter_clock, 12.0, 8)
	check(winter_pond.live_count() == 4, "A winter pond still fills completely, in about eight world days")
	check(WorldClock.season_factor(0.875, Fish.SEASON_RATE) > 0.0, "The slowest week of the year is still not a closed loop")
	check(is_equal_approx(WorldClock.season_factor(0.0, Fish.SEASON_RATE), 1.0), "Season 0 is the rate the pond has always run at")

	# --------------------------------------- a carried fish still holds a slot
	var busy_clock := WorldClock.new()
	var busy := _pond(busy_clock)
	busy.population[0].held = true
	busy.population[1].reserved = true
	_run_world_days(busy, busy_clock, 12.0, 4)
	check(busy.live_count() == 4 and busy.population.size() == 4, "Reserved and carried fish are not replaced under him")
	check(busy.store_fish(busy.population[0].id), "A carried fish leaves the pond for good")
	check(busy.live_count() == 3, "Committing one leaves a free slot")
	_run_world_days(busy, busy_clock, 12.0, 1)
	check(busy.live_count() == 4, "The freed slot fills again")

	# ------------------------------------------------------------ persistence
	var saver_clock := WorldClock.new()
	var saver := _pond(saver_clock)
	_empty(saver)
	saver_clock.set_time(0, 0.0)
	saver.advance(0.0)
	saver_clock.set_time(0, 3.0)   ## An eighth of a night: half a fish, no fish.
	saver.advance(0.0)
	check(saver.restock > 0.0 and saver.live_count() == 0, "Part of a fish is banked between spawns")
	var saved: Dictionary = saver.capture_state()
	check(Fish.valid_state(saved), "A restocking state validates")
	check(saved.has("restock") and saved.capacity == 4, "The document carries the accumulator and the capacity")
	var loaded := _pond(WorldClock.new())
	loaded.restore_state(saved)
	check(is_equal_approx(loaded.restock, saver.restock) and loaded.capacity == 4, "Restoring round-trips the accumulator and capacity")
	var json: Variant = JSON.parse_string(JSON.stringify(saved))
	check(Fish.valid_state(json), "The state survives a JSON round trip")

	# --------------------------------------------------------- legacy and junk
	check(Fish.valid_state({"version": 1, "stored_ids": []}), "A document saved before restocking validates")
	check(Fish.valid_state({"version": 1, "stored_ids": ["fish:0"], "homes": {"fish:0": [1, 0.5, 2]}}), "A document with homes but no restock validates")
	var legacy := _pond(WorldClock.new())
	legacy.restock = 0.75
	legacy.restore_state({"version": 1, "stored_ids": ["fish:1"]})
	check(legacy.restock == 0.0 and legacy.capacity == 4, "A legacy document restores a fresh accumulator and keeps the seeded capacity")
	check(legacy.live_count() == 3, "A legacy document still restores stored fish")
	check(not Fish.valid_state({"version": 1, "stored_ids": [], "surprise": 1}), "An unknown key is rejected")
	check(not Fish.valid_state({"version": 1, "stored_ids": [], "restock": 2.0}), "An out-of-range accumulator is rejected")
	check(not Fish.valid_state({"version": 1, "stored_ids": [], "capacity": "many"}), "A non-numeric capacity is rejected")

	for stub in _scenes: stub.free()
	print("PASS: the pond restocks on world time" if failures == 0 else "FAIL: fish restocking")
	print("Failures: ", failures)
	quit(1 if failures else 0)

## Four slots in a metre of water, with an optional clock and a dry sky.
func _pond(clock: WorldClock) -> Node3D:
	var scene := StubScene.new()
	scene.world_clock = clock
	scene._precipitation = StubPrecipitation.new()
	var pond: Node3D = Fish.new()
	pond.scene = scene
	scene.add_child(pond)
	var homes: Array[Vector3] = []
	for i in range(4): homes.append(Vector3(float(i) * 2.0, 0.5, 0.0))
	pond.seed_homes(homes)
	pond.advance(0.0)  # Sample the clock once, the way the first scene frame does.
	_scenes.append(scene)
	return pond

## Every fish carried home and committed, the way a week of fishing ends today.
func _empty(pond: Node3D) -> void:
	for fish: Dictionary in pond.population:
		fish.stored = true
		fish.available = false
		fish.node.visible = false

## Whole world days at a fixed hour, so daylight stays where the test put it.
func _run_world_days(pond: Node3D, clock: WorldClock, hour: float, days: int) -> void:
	clock.set_time(clock.day, hour)
	pond._clock_elapsed = -1.0  # Move onto the hour without crediting the jump.
	pond.advance(0.0)
	for i in range(days):
		clock.set_time(clock.day + 1, hour)
		pond.advance(1.0 / 30.0)

func check(ok: bool, message: String) -> void:
	if ok:
		return
	failures += 1
	print("FAIL: ", message)
	push_error(message)
