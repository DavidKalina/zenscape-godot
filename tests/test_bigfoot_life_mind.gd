extends SceneTree
const Mind = preload("res://scripts/bigfoot_life_mind.gd")
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var mind = Mind.new()
	var all := {"home": Vector3.ZERO, "material_needed": true, "can_gather": true, "food_count": 1, "can_fish": true, "curiosity_target": Vector3.ONE, "target_id": "stone", "ritual_target": Vector3.ONE, "can_play": true}
	check(mind.ranked({}).is_empty(), "Missing perceived opportunities cannot create actions")
	var first_check: Array[Dictionary] = mind.ranked({"home":true,"home_check_due":true})
	check(first_check[0].kind == "check_home" and first_check[0].reason == "Time to visit home and check his belongings", "First and periodic home checks do not claim an unseen disturbance")
	check(mind.disturbance_position == null, "Scheduling a home visit does not invent observed knowledge")
	mind.hunger = 1.0
	mind.fatigue = 0.1
	check(mind.ranked(all)[0].kind == "eat", "A hungry Bigfoot eats available food before gathering or playing")
	check(not _has(mind.ranked(all), "play"), "Hunger prevents starting playful stone arranging")
	var unchanged: Dictionary = mind.capture()
	mind.ranked(all)
	check(mind.capture() == unchanged, "Inspecting choices does not fulfill needs or alter memory")
	mind.completed("eat")
	check(mind.hunger < 0.5 and not _has(mind.ranked(all), "eat"), "Successful eating satisfies hunger and prevents instant repetition")
	mind.hunger = 0.1
	mind.fatigue = 1.0
	check(mind.ranked(all)[0].kind == "sleep", "Exhaustion makes sleep win over ordinary opportunities")
	check(not _has(mind.ranked(all), "play"), "Exhaustion prevents starting playful stone arranging")
	mind.fatigue = 0.1
	check(_has(mind.ranked(all), "gather"), "Unfinished bedding creates gathering opportunity")
	var comfortable := all.duplicate()
	comfortable.material_needed = false
	check(not _has(mind.ranked(comfortable), "gather"), "A completed bed stops endless gathering")
	comfortable.food_count = 3
	check(not _has(mind.ranked(comfortable), "fish"), "A stocked pantry stops endless fishing")
	check(mind.observe("stone", Vector3.ONE), "First perceived object is new")
	var novel_score := _score(mind.ranked(all), "investigate")
	for observation in range(200): mind.observe("stone", Vector3.ONE)
	check(mind.familiarity("stone") == 0.0, "Seeing an object each frame does not count as investigating it")
	mind.completed("investigate", {"target_id": "stone"})
	for second in range(23): mind.advance(1.0)
	check(mind.familiarity("stone") > 0.0 and _score(mind.ranked(all), "investigate") < novel_score, "Completed investigation habituates the specific object")
	check(mind.familiarity("unseen") == 0.0, "Investigating one object does not teach him about another")
	var migrated = Mind.new()
	migrated.observe("mesh-8:6", Vector3(2, 0, 3), "tree")
	migrated.completed("investigate", {"target_id":"mesh-8:6"})
	var original_memory: Dictionary = migrated.memories[0].duplicate(true)
	migrated.remap_observation("mesh-8:6", "object:9")
	var renamed_memory := original_memory.duplicate(true)
	renamed_memory.id = "object:9"
	check(migrated.memories == [renamed_memory], "An authoritative ID migration retains the same familiarity, observation time and position")
	var migration_state: Dictionary = migrated.capture()
	migrated.remap_observation("unseen", "object:10")
	migrated.remap_observation("object:9", "")
	migrated.remap_observation("object:9", "x".repeat(97))
	check(migrated.capture() == migration_state, "Unknown or invalid ID migrations do not fabricate or corrupt evidence")
	migrated.advance(1.0)
	migrated.observe("mesh-8:7", Vector3(4, 0, 5), "tree")
	migrated.remap_observation("mesh-8:7", "object:9")
	check(migrated.memories.size() == 1 and migrated.memories[0].position == [4.0, 0.0, 5.0] and migrated.memories[0].seen == 1.0 and migrated.familiarity("object:9") == original_memory.familiarity, "Merging duplicate identities retains latest source observation and strongest destination familiarity")
	migrated.observe("mesh-8:8", Vector3(6, 0, 7), "tree")
	migrated.completed("investigate", {"target_id":"mesh-8:8"})
	migrated.completed("investigate", {"target_id":"mesh-8:8"})
	migrated.advance(1.0)
	migrated.observe("object:9", Vector3(8, 0, 9), "tree")
	migrated.remap_observation("mesh-8:8", "object:9")
	check(migrated.memories.size() == 1 and migrated.memories[0].position == [8.0, 0.0, 9.0] and migrated.memories[0].seen == 2.0 and is_equal_approx(migrated.familiarity("object:9"), 0.68), "Merging duplicate identities retains latest destination observation and strongest source familiarity")
	check(Mind.valid(migrated.capture()), "Merged observations retain bounded valid persistence")
	mind.mark_disturbance(Vector3(2, 0, 3))
	check(mind.ranked(all)[0].kind == "check_home", "Observed home disturbance attracts attention while rested and fed")
	check(mind.ranked(all)[0].reason == "Something observed near home has changed", "An actual observed disturbance explains the inspection accurately")
	var disturbed: Dictionary = mind.capture()
	mind.completed("not_a_real_action")
	check(mind.capture() == disturbed, "Unrecognized or failed actions do not change needs or memory")
	mind.completed("check_home")
	check(mind.disturbance_position == null, "Successfully inspecting home resolves the remembered disturbance")
	mind.completed("ritual", {"ritual": "rest", "position": Vector3(1, 0, 2)})
	mind.completed("ritual", {"ritual": "rest", "position": Vector3(1, 0, 2)})
	mind.completed("ritual", {"ritual": "rest", "position": Vector3(5, 0, 2)})
	check(mind.favorite_position("rest") == Vector3(1, 0, 2), "Repeatedly used places become favorites")
	mind.enrichment = 1.0
	mind.hunger = 0.0
	mind.fatigue = 0.0
	check(mind.ranked({"home": true, "can_play": true})[0].kind == "play", "Satisfied Bigfoot chooses playful enrichment")
	var satisfied = Mind.new()
	satisfied.hunger = 0.0
	satisfied.fatigue = 0.0
	check(satisfied.ranked({"home":true,"food_count":2}).is_empty(), "Satisfied needs leave room for wandering instead of eating or sleeping without need")
	mind.completed("play")
	check(mind.enrichment < 0.5, "Completed play satisfies enrichment")
	var before_delta: Dictionary = mind.capture()
	mind.advance(NAN)
	mind.advance(INF)
	mind.advance(-4.0)
	check(mind.capture() == before_delta, "Invalid elapsed time cannot corrupt needs")
	mind.advance(99999.0)
	check(is_equal_approx(mind.elapsed - float(before_delta.elapsed), 1.0), "A long stalled frame is capped instead of fast-forwarding a life")
	var soft = Mind.new()
	var hard = Mind.new()
	soft.advance(1.0, true, 1.0)
	hard.advance(1.0, true, 0.0)
	check(soft.fatigue < hard.fatigue, "A comfortable bed makes actual resting more restorative")
	for index in range(40):
		mind.observe("object_%d" % index, Vector3(index, 0, 0))
		mind.completed("ritual", {"ritual": "spot_%d" % index, "position": Vector3(index, 0, 0)})
	check(mind.memories.size() == Mind.MAX_MEMORIES and mind.favorites.size() == Mind.MAX_FAVORITES, "Memory remains bounded in a changing garden")
	_time_of_day(all)
	mind.mark_disturbance(Vector3(3, 0, 4))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(mind.capture(), "", true, true))
	var restored = Mind.new()
	check(Mind.valid(saved) and restored.restore(saved), "Versioned memory accepts its JSON round trip")
	check(JSON.stringify(restored.capture(), "", true, true) == JSON.stringify(mind.capture(), "", true, true), "JSON round trip preserves needs, favorites, disturbance, and cooldowns")
	check(restored.ranked(all) == mind.ranked(all), "Reload preserves the next decision")
	var malformed: Array = []
	var bad := saved.duplicate(true)
	bad.hunger = NAN
	malformed.append(bad)
	bad = saved.duplicate(true)
	bad.memories[0].position = [0, INF, 0]
	malformed.append(bad)
	bad = saved.duplicate(true)
	bad.cooldowns["eat"] = 1000000
	malformed.append(bad)
	bad = saved.duplicate(true)
	bad.memories.append(bad.memories[0].duplicate())
	malformed.append(bad)
	bad = saved.duplicate(true)
	bad.favorites[0].visits = 1.5
	malformed.append(bad)
	bad = saved.duplicate(true)
	bad.version = 999
	malformed.append(bad)
	bad = saved.duplicate(true)
	bad.memories[0].unexpected_payload = {"nested": []}
	malformed.append(bad)
	var stable: Dictionary = restored.capture()
	for invalid: Dictionary in malformed:
		check(not Mind.valid(invalid) and not restored.restore(invalid) and restored.capture() == stable, "Malformed memory is rejected without partial mutation")
	check(restored.restore({}) and restored.capture() == Mind.new().capture(), "A legacy document without life state starts with fresh needs")
	print("BIGFOOT LIFE MIND failures=", failures)
	quit(1 if failures else 0)
## Time of day bends the same scores it always produced. Without a clock, or at
## noon under full daylight, every number matches the original formulas exactly.
func _time_of_day(all: Dictionary) -> void:
	var noon := all.duplicate()
	noon.hour = 12.0
	noon.daylight = 1.0
	var quiet = Mind.new()
	quiet.hunger = 0.5
	quiet.fatigue = 0.4
	var timeless: Array[Dictionary] = quiet.ranked(all)
	check(timeless == quiet.ranked(noon), "A world without a clock ranks exactly like bright noon")
	var original := {"sleep": 0.53, "gather": 0.692, "eat": 0.75, "fish": 0.60, "investigate": 0.486, "ritual": 0.387, "play": 0.167}
	for kind: String in original:
		check(absf(_score(timeless, kind) - float(original[kind])) < 0.0005, "Absent time keys leave the %s score at its original value" % kind)
	var night := all.duplicate()
	night.hour = 23.0
	night.daylight = 0.0
	var dark: Array[Dictionary] = quiet.ranked(night)
	check(is_equal_approx(_score(dark, "sleep"), _score(timeless, "sleep") + 0.45), "Darkness raises the pull of a familiar bed")
	check(_reason(dark, "sleep") == "Night has come; returning to a familiar bed", "The night sleep reason names the night")
	check(_score(dark, "investigate") < _score(timeless, "investigate") and _score(dark, "play") < _score(timeless, "play") and _score(dark, "gather") < _score(timeless, "gather"), "Curiosity, play and gathering grow cautious in the dark")
	check(is_equal_approx(_score(dark, "check_home"), _score(timeless, "check_home")), "Checking home is indifferent to the hour")
	var wary = Mind.new()
	wary.caution = 1.0
	var bold = Mind.new()
	bold.caution = 0.0
	check(_score(bold.ranked(noon), "investigate") - _score(bold.ranked(night), "investigate") < _score(wary.ranked(noon), "investigate") - _score(wary.ranked(night), "investigate"), "Caution amplifies the night penalty on curiosity")
	var drowsy = Mind.new()
	drowsy.fatigue = 0.22
	check(not _has(drowsy.ranked(noon), "sleep") and _has(drowsy.ranked(night), "sleep"), "Night lowers the tiredness needed before bed is worth considering")
	var dawn := all.duplicate()
	dawn.hour = 6.0
	dawn.daylight = 0.5
	var dusk := all.duplicate()
	dusk.hour = 18.0
	dusk.daylight = 0.5
	check(is_equal_approx(_score(quiet.ranked(dawn), "fish"), _score(timeless, "fish") + 0.28), "Fish are worth more at the daylight crossover")
	check(_reason(quiet.ranked(dawn), "fish") == "The fish bite at dawn" and _reason(quiet.ranked(dusk), "fish") == "The fish bite at dusk", "The crossover fishing reason names dawn or dusk")
	check(is_equal_approx(_score(quiet.ranked(dusk), "ritual"), _score(timeless, "ritual") + 0.12) and is_equal_approx(_score(quiet.ranked(dawn), "ritual"), _score(timeless, "ritual")), "A quiet ritual is an evening habit, not a morning one")
	check(quiet.time_note(2.0, 0.0) == "night" and quiet.time_note(6.0, 0.5) == "dawn" and quiet.time_note(13.0, 1.0) == "day" and quiet.time_note(18.0, 0.5) == "dusk", "The light has a name a watcher can read")
	check(quiet.time_note(NAN, NAN) == "day" and quiet.time_note(30.0, 0.5) == "dawn", "Nonsense clock readings fall back to plain daylight")
	var starving = Mind.new()
	starving.hunger = 0.9
	starving.fatigue = 0.5
	check(starving.ranked(night)[0].kind == "eat", "Real hunger still overrides the night's pull toward bed")
	var exhausted = Mind.new()
	exhausted.hunger = 0.1
	exhausted.fatigue = 0.95
	check(exhausted.ranked(noon)[0].kind == "sleep", "Real exhaustion still chooses sleep in broad daylight")
	var lit = Mind.new()
	var unlit = Mind.new()
	lit.advance(1.0, false, 0.0, 1.0)
	unlit.advance(1.0, false, 0.0, 0.0)
	check(unlit.fatigue > lit.fatigue and unlit.fatigue - Mind.new().fatigue < (lit.fatigue - Mind.new().fatigue) * 1.31, "Darkness tires him faster by a bounded amount")
	check(unlit.enrichment < lit.enrichment and unlit.enrichment - Mind.new().enrichment > (lit.enrichment - Mind.new().enrichment) * 0.70, "The dark offers slightly less to enjoy, by a bounded amount")
	var unspecified = Mind.new()
	unspecified.advance(1.0, false, 0.0)
	check(unspecified.capture() == lit.capture(), "An unspecified daylight keeps the original bright-day need timing")
func _reason(actions: Array[Dictionary], kind: String) -> String:
	for action in actions:
		if action.kind == kind: return str(action.reason)
	return ""
func _has(actions: Array[Dictionary], kind: String) -> bool:
	for action in actions:
		if action.kind == kind: return true
	return false
func _score(actions: Array[Dictionary], kind: String) -> float:
	for action in actions:
		if action.kind == kind: return action.score
	return -1.0
