extends RefCounted
## Decisions and remembered experiences, independent of movement and world edits.
## Callers supply perceived opportunities and commit only successfully performed actions.
const ACTIONS := ["sleep", "gather", "eat", "fish", "investigate", "ritual", "check_home", "play"]
const MAX_MEMORIES := 24
const MAX_FAVORITES := 8
const MAX_DELTA := 1.0
const LIMIT := 1000000000.0
var hunger := 0.28
var fatigue := 0.30
var enrichment := 0.35
var curiosity := 0.65
var caution := 0.40
var elapsed := 0.0
var cooldowns: Dictionary = {}
var memories: Array[Dictionary] = []
var favorites: Array[Dictionary] = []
var disturbance_position: Variant = null

## Darkness tires him a little faster and offers a little less to enjoy. Both
## effects stay within 30% so the existing need-timing expectations still hold.
func advance(delta: float, resting := false, comfort := 0.0, daylight := 1.0) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	var step := minf(delta, MAX_DELTA)
	var dark := _darkness(daylight)
	elapsed = minf(elapsed + step, LIMIT)
	hunger = clampf(hunger + step * 0.0030, 0.0, 1.0)
	fatigue = clampf(fatigue + step * (-0.020 * (0.5 + clampf(comfort, 0.0, 1.0)) if resting else 0.0020 * (1.0 + dark * 0.30)), 0.0, 1.0)
	enrichment = clampf(enrichment + step * 0.0035 * (1.0 - dark * 0.25), 0.0, 1.0)
	for kind in cooldowns.keys():
		cooldowns[kind] = maxf(0.0, float(cooldowns[kind]) - step)
		if cooldowns[kind] <= 0.0: cooldowns.erase(kind)

## Time of day bends the scores; it never dictates the action. A hungry or
## exhausted Bigfoot still overrides the rhythm. See docs/bigfoot-living-world.
func ranked(context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var home := _available(context.get("home"))
	var food := maxi(0, int(context.get("food_count", 0)))
	var hour := _hour(context.get("hour", 12.0))
	var daylight := _daylight(context.get("daylight", 1.0))
	var dark := _darkness(daylight)
	var note := time_note(hour, daylight)
	# A smooth bump around the light/dark crossover, the hours when fish rise.
	var twilight := clampf(1.0 - absf(daylight - 0.5) / 0.25, 0.0, 1.0)
	var wary := dark * (1.0 + caution)
	if home and fatigue >= 0.30 - dark * 0.12:
		_candidate(result, "sleep", 0.05 + fatigue * 1.20 + dark * 0.45, "Night has come; returning to a familiar bed" if note == "night" else "Tired; returning to a familiar bed")
	if home and context.get("material_needed", false) and context.get("can_gather", false):
		_candidate(result, "gather", 0.52 + (1.0 - clampf(float(context.get("comfort", 0.0)), 0.0, 1.0)) * 0.22 - fatigue * 0.12 - wary * 0.14, "The bed could be more comfortable")
	if food > 0 and hunger >= 0.20:
		_candidate(result, "eat", hunger * 1.50, "Hungry; food is stored at home")
	# A well-stocked pond is worth the walk, by less than any other term here: a
	# full pond must never outweigh an uncomfortable bed. An absent count adds
	# nothing, so every score predating restocking is unchanged.
	var pool: Variant = context.get("fish_available", 0)
	var plenty := clampf(float(pool) / 3.0, 0.0, 1.0) if (pool is int or pool is float) and is_finite(float(pool)) else 0.0
	if home and context.get("can_fish", false) and food < 3:
		_candidate(result, "fish", 0.30 + hunger * 0.60 + (0.16 if food == 0 else 0.0) + twilight * 0.28 + plenty * 0.05,("The fish bite at %s" % note) if twilight > 0.5 and note in ["dawn", "dusk"] else "Bring food home for later")
	if _available(context.get("curiosity_target")):
		var familiar := familiarity(str(context.get("target_id", "")))
		_candidate(result, "investigate", 0.22 + curiosity * 0.60 - caution * 0.16 - familiar * 0.38 - hunger * 0.12 - wary * 0.26, "An unfamiliar thing deserves a closer look" if familiar < 0.5 else "Checking something familiar")
	if _available(context.get("ritual_target")):
		_candidate(result, "ritual", 0.22 + enrichment * 0.34 + fatigue * 0.12 + (twilight * 0.12 if note == "dusk" else 0.0), "A quiet evening ritual at a favorite place" if note == "dusk" else "Visit a favorite place for a quiet ritual")
	var observed_change := disturbance_position != null or bool(context.get("disturbance", false))
	if home and (observed_change or context.get("home_check_due", false)):
		_candidate(result, "check_home", 0.85 + caution * 0.20, "Something observed near home has changed" if observed_change else "Time to visit home and check his belongings")
	if home and context.get("can_play", false) and hunger < 0.65 and fatigue < 0.70:
		_candidate(result, "play", 0.12 + enrichment * 0.72 - hunger * 0.25 - fatigue * 0.20 - wary * 0.20, "Fed enough to spend time arranging stones")
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	return result

## A watcher-facing name for the current light. Callers may show it in reasons.
func time_note(hour: float, daylight: float) -> String:
	var light := _daylight(daylight)
	if light < 0.35: return "night"
	if light > 0.85: return "day"
	return "dawn" if _hour(hour) < 12.0 else "dusk"

static func _darkness(daylight: Variant) -> float:
	return 1.0 - _daylight(daylight)

static func _daylight(value: Variant) -> float:
	if not (value is float or value is int) or not is_finite(float(value)): return 1.0
	return clampf(float(value), 0.0, 1.0)

static func _hour(value: Variant) -> float:
	if not (value is float or value is int) or not is_finite(float(value)): return 12.0
	return fposmod(float(value), 24.0)

func _candidate(result: Array[Dictionary], kind: String, score: float, reason: String) -> void:
	if cooldowns.get(kind, 0.0) > 0.0: return
	result.append({"kind": kind, "score": maxf(0.0, score), "reason": reason})

static func _available(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is Dictionary or value is Array: return not value.is_empty()
	return true

func completed(kind: String, context: Dictionary = {}) -> void:
	if kind not in ACTIONS: return
	match kind:
		"sleep":
			fatigue = maxf(0.0, fatigue - 0.45)
			cooldowns[kind] = 32.0
		"gather": cooldowns[kind] = 20.0
		"eat":
			hunger = maxf(0.0, hunger - clampf(float(context.get("food_amount", 0.55)), 0.0, 1.0))
			cooldowns[kind] = 12.0
		"fish": cooldowns[kind] = 35.0
		"investigate":
			var id := str(context.get("target_id", ""))
			for memory in memories:
				if memory.id == id:
					memory.familiarity = minf(1.0, float(memory.familiarity) + 0.34)
					memory.seen = elapsed
					break
			enrichment = maxf(0.0, enrichment - 0.18)
			cooldowns[kind] = 22.0
		"ritual":
			enrichment = maxf(0.0, enrichment - 0.35)
			if context.get("ritual", "") == "rest": fatigue = maxf(0.0, fatigue - 0.12)
			_remember_favorite(str(context.get("ritual", "rest")), context.get("position"))
			cooldowns[kind] = 48.0
		"check_home":
			disturbance_position = null
			cooldowns[kind] = 28.0
		"play":
			enrichment = maxf(0.0, enrichment - 0.60)
			cooldowns[kind] = 55.0

func observe(id: String, position: Vector3, category := "object") -> bool:
	if id.is_empty() or id.length() > 96 or category.is_empty() or category.length() > 48 or not _valid_vector(position): return false
	for memory in memories:
		if memory.id == id:
			memory.position = _point(position)
			memory.seen = elapsed
			return false
	if memories.size() >= MAX_MEMORIES:
		memories.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.seen < b.seen)
		memories.pop_front()
	memories.append({"id": id, "position": _point(position), "category": category, "familiarity": 0.0, "seen": elapsed})
	return true

## An authoritative world-ID migration preserves knowledge of the same object.
## Never infer identity from position, or create evidence for an unknown source.
func remap_observation(old_id: String, new_id: String) -> void:
	if old_id == new_id or not _text(new_id, 96): return
	var source := -1
	var destination := -1
	for index in range(memories.size()):
		if memories[index].id == old_id: source = index
		if memories[index].id == new_id: destination = index
	if source < 0: return
	if destination < 0:
		memories[source].id = new_id
		return
	var old: Dictionary = memories[source]
	var merged: Dictionary = memories[destination]
	merged.familiarity = maxf(float(old.familiarity), float(merged.familiarity))
	if float(old.seen) > float(merged.seen):
		merged.seen = old.seen
		merged.position = old.position.duplicate()
		merged.category = old.category
	memories.remove_at(source)

func familiarity(id: String) -> float:
	for memory in memories:
		if memory.id == id: return float(memory.familiarity)
	return 0.0

func mark_disturbance(position: Vector3) -> void:
	if _valid_vector(position): disturbance_position = position

func _remember_favorite(ritual: String, position: Variant) -> void:
	if ritual.is_empty() or ritual.length() > 48 or not position is Vector3 or not _valid_vector(position): return
	for favorite in favorites:
		if favorite.ritual == ritual and _vector(favorite.position).distance_to(position) < 0.75:
			favorite.visits = mini(1000000, int(favorite.visits) + 1)
			return
	if favorites.size() >= MAX_FAVORITES:
		favorites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.visits < b.visits)
		favorites.pop_front()
	favorites.append({"ritual": ritual, "position": _point(position), "visits": 1})

func favorite_position(ritual: String) -> Variant:
	var best: Dictionary = {}
	for favorite in favorites:
		if favorite.ritual == ritual and (best.is_empty() or favorite.visits > best.visits): best = favorite
	return null if best.is_empty() else _vector(best.position)

func capture() -> Dictionary:
	return {"version": 1, "hunger": hunger, "fatigue": fatigue, "enrichment": enrichment, "curiosity": curiosity, "caution": caution, "elapsed": elapsed, "cooldowns": cooldowns.duplicate(true), "memories": memories.duplicate(true), "favorites": favorites.duplicate(true), "disturbance": [] if disturbance_position == null else _point(disturbance_position)}

func restore(value: Dictionary) -> bool:
	if value.is_empty():
		hunger = 0.28
		fatigue = 0.30
		enrichment = 0.35
		curiosity = 0.65
		caution = 0.40
		elapsed = 0.0
		cooldowns.clear()
		memories.clear()
		favorites.clear()
		disturbance_position = null
		return true
	if not valid(value): return false
	for key in ["hunger", "fatigue", "enrichment", "curiosity", "caution", "elapsed"]: set(key, float(value[key]))
	cooldowns = value.cooldowns.duplicate(true)
	memories.clear()
	for memory: Dictionary in value.memories: memories.append(memory.duplicate(true))
	favorites.clear()
	for favorite: Dictionary in value.favorites:
		var copy := favorite.duplicate(true)
		copy.visits = int(copy.visits)
		favorites.append(copy)
	disturbance_position = null if value.disturbance.is_empty() else _vector(value.disturbance)
	return true

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or value.size() != 11: return false
	for key in ["hunger", "fatigue", "enrichment", "curiosity", "caution"]:
		if not _number(value.get(key), 0.0, 1.0): return false
	if not _number(value.get("elapsed"), 0.0, LIMIT): return false
	if not value.get("cooldowns") is Dictionary or value.cooldowns.size() > ACTIONS.size(): return false
	for key in value.cooldowns:
		if key not in ACTIONS or not _number(value.cooldowns[key], 0.0, 120.0): return false
	if not value.get("memories") is Array or value.memories.size() > MAX_MEMORIES: return false
	var ids: Dictionary = {}
	for memory in value.memories:
		if not memory is Dictionary or memory.size() != 5: return false
		if not _text(memory.get("id"), 96) or ids.has(memory.id): return false
		ids[memory.id] = true
		if not _text(memory.get("category"), 48) or not _valid_point(memory.get("position")): return false
		if not _number(memory.get("familiarity"), 0.0, 1.0) or not _number(memory.get("seen"), 0.0, value.elapsed): return false
	if not value.get("favorites") is Array or value.favorites.size() > MAX_FAVORITES: return false
	for favorite in value.favorites:
		if not favorite is Dictionary or favorite.size() != 3 or not _text(favorite.get("ritual"), 48) or not _valid_point(favorite.get("position")): return false
		if not _number(favorite.get("visits"), 1, 1000000) or floor(float(favorite.visits)) != float(favorite.visits): return false
	if not value.get("disturbance") is Array: return false
	if not value.disturbance.is_empty() and not _valid_point(value.disturbance): return false
	return true

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= minimum and value <= maximum

static func _text(value: Variant, maximum: int) -> bool:
	return value is String and not value.is_empty() and value.length() <= maximum

static func _valid_point(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	for coordinate in value:
		if not _number(coordinate, -1000.0, 1000.0): return false
	return true

static func _valid_vector(value: Vector3) -> bool:
	return value.is_finite() and absf(value.x) <= 1000.0 and absf(value.y) <= 1000.0 and absf(value.z) <= 1000.0

static func _point(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
