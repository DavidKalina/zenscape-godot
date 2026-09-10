extends SceneTree
## Winter and the long horizon. A simulated year walked two world hours at a
## time: the torpor need fills through the cold quarter, drains through spring,
## lifts the long sleep only when the stores are in, and pushes an outing when
## they are not. Pure — no scene, no rendering, no wall clock.
##   Godot --path . --rendering-method forward_plus --script res://tests/test_winter_torpor.gd
const Mind := preload("res://scripts/bigfoot_life_mind.gd")
const STEP_HOURS := 2.0

var failures := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

## Where a mind stands after walking `days` world days of the calendar from
## season 0. Records the torpor at every step so the shape can be read back.
func _walk(mind, days: float, log: Dictionary = {}) -> void:
	var steps := int(days * 24.0 / STEP_HOURS)
	for i in range(steps):
		var season := fposmod((float(i) * STEP_HOURS / 24.0) / float(WorldClock.YEAR_DAYS), 1.0)
		mind.drift(WeatherScheduler.season_cold(season), STEP_HOURS)
		log[snappedf(season, 0.001)] = mind.torpor

func _at(log: Dictionary, season: float) -> float:
	var best := 0.0
	var gap := 9.0
	for key: float in log:
		if absf(key - season) < gap:
			gap = absf(key - season)
			best = float(log[key])
	return best

func _top(mind, context: Dictionary) -> String:
	var ranked: Array[Dictionary] = mind.ranked(context)
	return "" if ranked.is_empty() else str(ranked[0].kind)

func _score(mind, context: Dictionary, kind: String) -> float:
	for option: Dictionary in mind.ranked(context):
		if option.kind == kind: return float(option.score)
	return -1.0

## A clear winter noon outside his own cave. `ready` is the stores he believes
## he has laid in; the caller sets what the errands can see.
func _winter(ready: float, food: int, cold := 0.9, harvest := 0.0) -> Dictionary:
	return {"home": true, "hour": 12.0, "daylight": 1.0, "weather": "clear",
		"season": 0.875, "cold": cold, "harvest": harvest, "winter_ready": ready,
		"food_count": food, "can_fish": true, "fish_available": 3,
		"material_needed": false, "can_gather": true, "comfort": 1.0,
		"curiosity_target": true, "target_id": "stone",
		"ritual_target": true, "can_play": true}

func _run() -> void:
	# ------------------------------------------------------------ the year
	var mind = Mind.new()
	check(mind.torpor == 0.0, "A fresh mind opens the year wide awake")
	var log := {}
	_walk(mind, float(WorldClock.YEAR_DAYS), log)
	check(_at(log, 0.20) < 0.01 and _at(log, 0.50) < 0.01, "Spring and summer never pull him toward the long sleep")
	check(_at(log, 0.70) < 0.02, "Autumn is for stocking up, not for sleeping")
	check(_at(log, 0.80) > 0.05 and _at(log, 0.80) < Mind.TORPOR_THRESHOLD, "The first days of winter grow him slow without bedding him in: %.2f" % _at(log, 0.80))
	check(_at(log, 0.875) > 0.70, "Deep winter fills the need: %.2f" % _at(log, 0.875))
	var peak := 0.0
	var peak_at := 0.0
	for key: float in log:
		if float(log[key]) > peak:
			peak = float(log[key])
			peak_at = key
	check(peak > 0.75 and peak_at > 0.875, "The need peaks a little after deep winter, at season %.3f" % peak_at)
	check(mind.torpor > 0.30, "He is still heavy as the year turns: %.2f" % mind.torpor)

	# Spring drains it, slower than winter filled it.
	var spring := {}
	_walk(mind, 4.0, spring)
	check(mind.torpor < 0.20, "Four days of spring drain the need away: %.2f" % mind.torpor)
	_walk(mind, 3.0, spring)
	check(mind.torpor < 0.02, "By the end of spring the long drive is gone: %.3f" % mind.torpor)

	# ------------------------------------------------- deep winter, stocked
	var winter = Mind.new()
	_walk(winter, float(WorldClock.YEAR_DAYS) * 0.88, {})
	check(winter.torpor > 0.70, "The winter fixture is deep in the cold: %.2f" % winter.torpor)
	var stocked := _winter(1.0, 4)
	check(_top(winter, stocked) == "hibernate", "With the stores in, the long sleep wins deep winter")
	check(_score(winter, stocked, "hibernate") > _score(winter, stocked, "sleep") + 0.5, "It wins by a clear margin over an ordinary nap")
	var reason := ""
	for option: Dictionary in winter.ranked(stocked):
		if option.kind == "hibernate": reason = str(option.reason)
	check(reason == "The year has gone cold; time to sleep it out", "The long sleep says why: %s" % reason)

	# The leisure of the year fades first; the errands that feed him do not.
	var summer = Mind.new()
	var mild := stocked.duplicate()
	mild.cold = 0.0
	mild.season = 0.5
	check(_score(summer, mild, "play") > _score(winter, mild, "play"), "Torpor takes the play out of him")
	check(_score(summer, mild, "investigate") > _score(winter, mild, "investigate"), "Torpor takes the curiosity out of him")

	# --------------------------------------------- deep winter, empty stash
	var empty := _winter(0.4, 0)
	check(_top(winter, empty) == "fish", "An empty stash in deep winter sends him out rather than under")
	check(not _has(winter.ranked(empty), "hibernate") or _score(winter, empty, "hibernate") < _score(winter, empty, "fish"), "The long sleep is still on offer, it simply loses")
	var bare := _winter(0.0, 0)
	bare.material_needed = true
	bare.comfort = 0.0
	check(_top(winter, bare) in ["gather", "fish"], "No bed and no food sends him out too, never to sleep hungry")
	var short_reason := ""
	for option: Dictionary in winter.ranked(empty):
		if option.kind == "fish": short_reason = str(option.reason)
	check(short_reason == "Winter is coming; the stash is too thin for it", "The stocking errand says why: %s" % short_reason)

	# Autumn is when the shortfall starts to count.
	var autumn = Mind.new()
	var short_autumn := _winter(0.4, 0, 0.0, 0.9)
	var full_autumn := _winter(1.0, 0, 0.0, 0.9)
	check(_score(autumn, short_autumn, "fish") > _score(autumn, full_autumn, "fish") + 0.2, "A thin larder makes autumn fishing worth more")
	short_autumn.material_needed = true
	short_autumn.comfort = 0.5
	full_autumn.material_needed = true
	full_autumn.comfort = 0.5
	check(_score(autumn, short_autumn, "gather") > _score(autumn, full_autumn, "gather") + 0.1, "A thin larder makes autumn gathering worth more")

	# ------------------------------------------------------------- outings
	winter.completed("hibernate", {"cold": 0.9})
	check(winter.fatigue < 0.01, "A long sleep takes the tiredness with it")
	check(not _has(winter.ranked(stocked), "hibernate"), "He does not fall straight back into it")
	check(not winter.ranked(stocked).is_empty(), "The waking outing always has something to do")
	var deep_outing: float = winter.cooldowns.hibernate
	for second in range(int(Mind.OUTING_DEEP) + 2): winter.advance(1.0)
	check(_top(winter, stocked) == "hibernate", "After a short outing the long sleep takes him back")
	var thawing = Mind.new()
	thawing.torpor = 0.6
	thawing.completed("hibernate", {"cold": 0.15})
	check(thawing.cooldowns.hibernate > deep_outing + 10.0, "A thawing year keeps him out longer: %.1fs against %.1fs" % [thawing.cooldowns.hibernate, deep_outing])

	# ---------------------------------------------------- nothing else moved
	var plain = Mind.new()
	var neutral := {"home": true, "hour": 12.0, "daylight": 1.0, "food_count": 1, "can_fish": true,
		"material_needed": true, "can_gather": true, "comfort": 0.5, "ritual_target": true, "can_play": true}
	check(not _has(plain.ranked(neutral), "hibernate"), "A world with no calendar never offers the long sleep")
	var before := plain.ranked(neutral)
	var with_keys := neutral.duplicate()
	with_keys.winter_ready = 1.0
	with_keys.torpor = 0.0
	check(_same(before, plain.ranked(with_keys)), "A stocked, seasonless world ranks exactly as it always did")

	# ------------------------------------------------------------ the save
	plain.torpor = 0.63
	var saved: Dictionary = plain.capture()
	check(float(saved.get("torpor", -1.0)) == 0.63, "The long drive is part of the saved mind")
	var loaded = Mind.new()
	check(loaded.restore(saved) and loaded.torpor == 0.63, "It round trips through a save")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("torpor")
	check(Mind.valid(legacy) and Mind.valid(saved), "Minds written before and after the drive both validate")
	check(loaded.restore(legacy) and loaded.torpor == 0.0, "A document from before winter loads wide awake")
	var broken: Dictionary = saved.duplicate(true)
	broken.torpor = 4.0
	check(not Mind.valid(broken), "An out-of-range drive is rejected")
	check(loaded.restore({}) and loaded.torpor == 0.0, "A cleared mind forgets the winter too")

	print("PASS: winter fills, drains and decides" if failures == 0 else "FAIL: winter torpor")
	print("Failures: ", failures)
	quit(1 if failures else 0)

func _has(ranked: Array[Dictionary], kind: String) -> bool:
	for option: Dictionary in ranked:
		if option.kind == kind: return true
	return false

func _same(first: Array[Dictionary], second: Array[Dictionary]) -> bool:
	if first.size() != second.size(): return false
	for index in range(first.size()):
		if first[index].kind != second[index].kind: return false
		if absf(float(first[index].score) - float(second[index].score)) > 0.0000001: return false
	return true
