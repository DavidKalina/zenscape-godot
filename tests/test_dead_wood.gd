extends SceneTree
## Dead wood on world time: wind and storms drop branches under the trees, they
## lie there for a few world days, they rot away, and a frozen sky changes
## nothing. Pure: stub scene, no rendering, no habitat and no wall clock.
var failures := 0
var _scenes: Array[Node] = []

const Wood := preload("res://scripts/dead_wood.gd")
const Mind := preload("res://scripts/bigfoot_life_mind.gd")

class StubHabitat:
	var interests: Array[Dictionary] = []
	func ground_height(_point: Vector2) -> Variant: return 0.0

class StubNavigation:
	## Every point of this flat stub world is walkable ground.
	func nearest_safe(point: Vector3) -> Variant: return point

class StubPrecipitation:
	var preset_index := 0
	var wind := Wood.WIND_REFERENCE

class StubScene extends Node:
	var habitat := StubHabitat.new()
	var navigation := StubNavigation.new()
	var world_clock: WorldClock = null
	var _precipitation: StubPrecipitation = null

func _initialize() -> void:
	# ------------------------------------------------------------------ sites
	var clock := WorldClock.new()
	var wood := _forest(clock)
	check(wood.sites.size() == 10, "Every tree gets one walkable drop site under it")
	check(wood.count() == 0 and wood.targets().is_empty(), "A fresh forest floor is bare")
	check(wood.weather() == "clear" and is_equal_approx(wood.wind(), Wood.WIND_REFERENCE), "The stub sky reads as calm with the study's resting wind")

	# -------------------------------------------------------------- the storm
	_sky(wood, "storm")
	_run_hours(wood, clock, 25.0)
	check(wood.count() == 6, "A world day of storm drops six branches")
	check(wood.targets().size() == 6, "Every fallen branch is a gather target")
	check(wood.nearby(Vector3.ZERO, 3.0) < wood.count(), "Only the branches within reach count as nearby")
	check(wood.nearby(Vector3.ZERO, 1000.0) == 6, "A wide enough reach finds them all")

	# ------------------------------------------------- rain and calm are lower
	var rain_clock := WorldClock.new()
	var rained := _forest(rain_clock)
	_sky(rained, "rain")
	_run_hours(rained, rain_clock, 25.0)
	check(rained.count() == 2, "A world day of rain drops two branches")
	var calm_clock := WorldClock.new()
	var calm := _forest(calm_clock)
	_run_hours(calm, calm_clock, 49.0)
	check(calm.count() == 0 and calm.drop > 0.6, "Two calm days drop nothing but bank most of a branch")

	# -------------------------------------------------------------- the gale
	var gale_clock := WorldClock.new()
	var gale := _forest(gale_clock)
	gale.scene._precipitation.wind = 1.6
	_run_hours(gale, gale_clock, 49.0)
	check(gale.count() == 1, "The same two days of a gale shake one down out of a clear sky")

	# ------------------------------------------------------------ the season
	var autumn_clock := WorldClock.new()
	autumn_clock.season_override = 0.5
	var autumn := _forest(autumn_clock)
	_sky(autumn, "storm")
	_run_hours(autumn, autumn_clock, 25.0)
	check(autumn.count() == 10, "The same storm at the opening of autumn drops ten: %d" % autumn.count())
	var winter_clock := WorldClock.new()
	winter_clock.season_override = 0.75
	var winter := _forest(winter_clock)
	_sky(winter, "storm")
	_run_hours(winter, winter_clock, 25.0)
	check(winter.count() == 3, "A bare winter canopy gives the storm only three: %d" % winter.count())
	check(is_equal_approx(winter.rot_days(), Wood.ROT_DAYS * 1.5), "Winter keeps a branch half again as long")
	var summer_clock := WorldClock.new()
	summer_clock.season_override = 0.25
	check(is_equal_approx(_forest(summer_clock).rot_days(), Wood.ROT_DAYS * 0.75), "Summer rots it in three quarters of the time")
	check(is_equal_approx(wood.rot_days(), Wood.ROT_DAYS), "Spring, and a scene with no calendar, keep today's four days")

	# ------------------------------------------------------------ frozen time
	var frozen_before := int(wood.count())
	var frozen_drop := float(wood.drop)
	for frame in range(600): wood.advance(1.0 / 60.0)
	check(wood.count() == frozen_before and is_equal_approx(wood.drop, frozen_drop), "A frozen clock drops nothing however long the engine runs")

	# ------------------------------------------------------------ the big step
	var jump_clock := WorldClock.new()
	var jumped := _forest(jump_clock)
	_sky(jumped, "storm")
	jump_clock.season_override = 0.0  # Day 5 is late spring, where the summer taper has begun; pin the rate.
	jump_clock.set_time(5, 0.0)
	jumped.advance(0.0)
	check(jumped.count() == 6, "A five-day jump credits at most one world day of storm")

	# -------------------------------------------------------------- they rot
	var rot_clock := WorldClock.new()
	var rotting := _forest(rot_clock)
	_sky(rotting, "storm")
	_run_hours(rotting, rot_clock, 13.0)
	var fell: Array[String] = []
	for target: Dictionary in rotting.targets(): fell.append(str(target.id))
	check(fell.size() == 3, "Half a day of storm leaves three branches on the ground")
	_sky(rotting, "clear")
	_run_hours(rotting, rot_clock, Wood.ROT_DAYS * 24.0)
	var still_there: Array[String] = []
	for target: Dictionary in rotting.targets(): still_there.append(str(target.id))
	var survivor := false
	for id in fell:
		if id in still_there: survivor = true
	check(not survivor, "Every storm-fallen branch is gone four world days later")
	check(rotting.count() < fell.size(), "The count really falls back")

	# ------------------------------------ the week: it rises and it falls back
	var week_clock := WorldClock.new()
	var week := _forest(week_clock)
	var peak := 0
	var low_after_peak := 999
	var counts: Array[int] = []
	for day in range(7):
		# A windy night on days 1 and 2, then the sky clears for the rest.
		_sky(week, "storm" if day == 1 else ("rain" if day == 2 else "clear"))
		_run_hours(week, week_clock, 24.0)
		counts.append(week.count())
		peak = maxi(peak, week.count())
		if peak > 0: low_after_peak = mini(low_after_peak, week.count())
	check(peak >= 6, "Over a week the branch count rises well above zero: " + str(counts))
	check(low_after_peak < peak, "And it falls again once the wood has rotted: " + str(counts))
	check(counts[0] == 0 and counts[-1] < peak, "It neither starts nor ends at its peak")

	# ------------------------------------------------------------- the carry
	var carry_clock := WorldClock.new()
	var carried := _forest(carry_clock)
	_sky(carried, "storm")
	_run_hours(carried, carry_clock, 24.0)
	var id: String = str(carried.targets()[0].id)
	var before := int(carried.count())
	var carry: Dictionary = carried.take_for_carry(id)
	check(not carry.is_empty() and carry.kind == "branch" and carry.node is Node3D, "A branch hands its own node to the carry")
	check(carried.count() == before - 1 and carried.take_for_carry(id).is_empty(), "A branch already in his hands is nobody else's target")
	carry.release.call()
	check(carried.count() == before, "An abandoned carry puts the branch back where it lay")
	carry = carried.take_for_carry(id)
	check(bool(carry.commit.call()) and carried.count() == before - 1, "A delivered branch is gone from the forest floor")
	check(not bool(carried.consume(id)), "The same branch cannot be delivered twice")

	# ----------------------------------------------------------- persistence
	var saved: Dictionary = carried.capture_state()
	check(Wood.valid_state(saved), "A forest floor with branches on it validates")
	check(saved.branches.size() == carried.count() and saved.has("drop"), "The document carries every branch and the accumulator")
	var loaded := _forest(WorldClock.new())
	loaded.restore_state(saved)
	check(loaded.count() == carried.count() and is_equal_approx(loaded.drop, carried.drop), "Restoring round-trips the branches and the accumulator")
	check(loaded.capture_state().branches == saved.branches, "The restored branches keep their ids, ages and places")
	var json: Variant = JSON.parse_string(JSON.stringify(saved))
	check(Wood.valid_state(json), "The state survives a JSON round trip")

	# --------------------------------------------------------- legacy and junk
	var legacy_clock := WorldClock.new()
	var legacy := _forest(legacy_clock)
	_sky(legacy, "storm")
	_run_hours(legacy, legacy_clock, 25.0)
	check(legacy.count() > 0, "The legacy fixture has wood on the ground to lose")
	legacy.restore_state({})
	check(legacy.count() == 0 and legacy.drop == 0.0, "A document written before dead wood loads a bare forest floor")
	check(not Wood.valid_state({"version": 1, "branches": [], "surprise": 1}), "An unknown key is rejected")
	check(not Wood.valid_state({"version": 1, "drop": 4.0}), "An out-of-range accumulator is rejected")
	check(not Wood.valid_state({"version": 1, "branches": [{"id": "branch:0", "position": [0, 0, 0], "age": 99.0}]}), "A branch older than rot is rejected")
	check(not Wood.valid_state({"version": 2, "branches": []}), "A future version is rejected")

	# ------------------------------------------------- the mind sees the wood
	var mind := Mind.new()
	var base := _gather_score(mind, {})
	check(is_equal_approx(_gather_score(mind, {"branches_nearby": 0}), base), "A bare forest floor scores exactly as before dead wood existed")
	var invitation := _gather_score(mind, {"branches_nearby": 3}) - base
	check(invitation > 0.07 and invitation < 0.09, "Branches on the ground make gathering a little more attractive")
	check(invitation < 0.22, "Fallen wood never outweighs the comfort spread it decorates")
	check(is_equal_approx(_gather_score(mind, {"branches_nearby": 9}), _gather_score(mind, {"branches_nearby": 3})), "The invitation saturates")
	check(_gather_reason(mind, {"branches_nearby": 2}) == "Branches are down under the trees", "He names the wood he can see")
	check(_gather_reason(mind, {}) == "The bed could be more comfortable", "Without wood he gathers for the old reason")

	for stub in _scenes: stub.free()
	print("PASS: the wind drops branches and they rot" if failures == 0 else "FAIL: dead wood")
	print("Failures: ", failures)
	quit(1 if failures else 0)

## Ten trees in a row on flat walkable ground, with an optional clock.
func _forest(clock: WorldClock) -> Node3D:
	var scene := StubScene.new()
	scene.world_clock = clock
	scene._precipitation = StubPrecipitation.new()
	for i in range(10):
		scene.habitat.interests.append({"id": "mesh-8:%d" % i, "position": Vector3(float(i) * 6.0, 0.0, 0.0), "kind": "tree"})
	var wood: Node3D = Wood.new()
	scene.add_child(wood)
	wood.setup(scene)
	wood.advance(0.0)  # Sample the clock once, the way the first scene frame does.
	_scenes.append(scene)
	return wood

func _sky(wood: Node3D, name: String) -> void:
	wood.scene._precipitation.preset_index = WeatherScheduler.preset_index(name)

## World hours at one tick an hour, so drops spread through the day the way the
## scene's frames spread them.
func _run_hours(wood: Node3D, clock: WorldClock, hours: float) -> void:
	var steps := int(hours)
	for step in range(steps):
		var total := float(clock.day) * 24.0 + clock.hour + 1.0
		clock.set_time(int(total / 24.0), fposmod(total, 24.0))
		wood.advance(1.0 / 30.0)

func _gather_context(extra: Dictionary) -> Dictionary:
	var context := {"home": true, "material_needed": true, "can_gather": true, "comfort": 0.0, "hour": 12.0, "daylight": 1.0}
	context.merge(extra, true)
	return context

func _gather_score(mind: RefCounted, extra: Dictionary) -> float:
	for option: Dictionary in mind.ranked(_gather_context(extra)):
		if option.kind == "gather": return float(option.score)
	return -1.0

func _gather_reason(mind: RefCounted, extra: Dictionary) -> String:
	for option: Dictionary in mind.ranked(_gather_context(extra)):
		if option.kind == "gather": return str(option.reason)
	return ""

func check(ok: bool, message: String) -> void:
	if ok:
		return
	failures += 1
	print("FAIL: ", message)
	push_error(message)
