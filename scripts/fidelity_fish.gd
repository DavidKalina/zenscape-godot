extends Node3D
## A small explicit fish population. Every fish has a persistent identity while
## alive in this scene; catching borrows that same node and returning releases it.
##
## The pond also restocks. Every seeded home is a slot; a slot emptied by a fish
## carried home fills again after a while, so the food loop never closes — slowly
## in a cold year, quickly in a warm one, but never not at all. The
## clock that drives it is world time (`scene.world_clock.elapsed`), never engine
## seconds, so a paused or slowed world holds the fish where they are and a fast
## one breeds them at the same visible pace. Scenes with no clock fall back to a
## world day of `WorldClock.DEFAULT_DAY_LENGTH` real seconds.

const RESTOCK_DAYS := 2.0    ## World days for an empty pond to refill completely.
const NIGHT_DAYLIGHT := 0.35 ## The mind's own definition of night.
const NIGHT_FACTOR := 2.0    ## Fish rise in the dark.
const RAIN_FACTOR := 2.0     ## Run-off feeds the pond.
const RAIN_WET := 0.35       ## ground_wet at or above this counts as rain.
const RAIN_MEMORY := 0.5     ## World days the rain bonus lingers after it dries.
## The pond's year, as [spring, summer, autumn, winter] multipliers on the
## restock rate, read through WorldClock.season_factor. Spring and summer breed
## at the full two-day rate, autumn tapers, and a winter pond is slow — eight
## world days to refill — but never frozen, so the food loop never closes.
const SEASON_RATE := [1.0, 1.0, 0.6, 0.25]
const MAX_STEP_DAYS := 1.0   ## A skipped or restored day must not dump a season of fish.
const MAX_FISH := 512        ## Document limit; a restocking pond outlives the old 128.

var scene: Node
var population: Array[Dictionary] = []
var home_slots: Array[Vector3] = []  ## The seeded homes; one live fish each.
var capacity := 0                    ## Live fish the pond carries, set by seeding.
var restock := 0.0                   ## Fish-fractions banked toward the next spawn, 0..1.
var rain_memory := 0.0               ## World days of lingering rain bonus left.
var _time := 0.0
var _clock_elapsed := -1.0           ## Last world-second reading; negative until first sampled.

func setup(owner_scene: Node) -> void:
	scene = owner_scene
	var homes: Array[Vector3] = []
	var candidates: Array[Vector3] = []
	for water in scene.habitat.waters:
		if not water._stream_channels.is_empty(): continue
		for x in range(-52,53):
			for z in range(-52,53):
				var point := Vector2(x*0.25,z*0.25)
				var level: Variant = water.height_at(point.x,point.y)
				var floor_height: Variant = scene.habitat.ground_height(point)
				if level == null or floor_height == null or level-floor_height < 0.15: continue
				var nearby: Variant = scene.navigation.nearest_safe(Vector3(point.x,level,point.y))
				if nearby == null or Vector2(nearby.x-point.x,nearby.z-point.y).length()>1.75: continue
				var home := Vector3(point.x,level-0.08,point.y)
				candidates.append(home)
	# Cover the whole pond instead of filling four slots along the first bank
	# visited by the scan. Different shores belong to different walkable regions.
	for direction in [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN]:
		candidates.sort_custom(func(a: Vector3,b: Vector3) -> bool: return Vector2(a.x,a.z).dot(direction)>Vector2(b.x,b.z).dot(direction))
		for home in candidates:
			var spaced := true
			for other in homes:
				if home.distance_to(other)<2.0: spaced = false
			if not spaced: continue
			homes.append(home)
			break
	seed_homes(homes)

## One fish per authored home, and those same homes become the restock slots.
func seed_homes(homes: Array[Vector3]) -> void:
	home_slots = homes.duplicate()
	capacity = homes.size()
	for home in homes: _add_fish(home)

func _add_fish(home: Vector3) -> void:
	var fish := Node3D.new()
	fish.name = "PondFish%d" % population.size()
	add_child(fish)
	fish.position = home
	var body := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.13
	shape.height = 0.26
	shape.radial_segments = 8
	shape.rings = 4
	body.mesh = shape
	body.scale = Vector3(0.65,0.45,2.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7,0.38,0.12)
	material.roughness = 0.45
	body.material_override = material
	fish.add_child(body)
	var tail := MeshInstance3D.new()
	var fin := PrismMesh.new()
	fin.size = Vector3(0.22,0.04,0.2)
	tail.mesh = fin
	tail.position.z = -0.25
	tail.material_override = material
	fish.add_child(tail)
	population.append({"id":"fish:%d" % population.size(),"node":fish,"home":home,"spawn_home":home,"held":false,"reserved":false,"returning":false,"return_age":0.0,"return_from":home,"available":true,"stored":false,"tail":tail})

func _wet(point: Vector3) -> bool:
	var height: Variant = scene.habitat.ground_height(Vector2(point.x,point.z))
	if height == null or height > point.y-0.04: return false
	for water in scene.habitat.waters:
		var level: Variant = water.height_at(point.x,point.z)
		if level != null and level > point.y: return true
	for pond: Dictionary in scene.habitat.ponds:
		if float(pond.level)>point.y and GardenWater.covers(scene.habitat.pond_surface(pond),Vector2(point.x,point.z)): return true
	return false

## Live identities, whatever they are doing. A fish in his hands still holds its
## slot, so restocking never doubles up on a catch that is only half made.
func live_count() -> int:
	var count := 0
	for fish in population:
		if not fish.get("stored",false): count += 1
	return count

## World days since the last tick, from the clock when the scene has one.
func _world_days(delta: float) -> float:
	var clock: Variant = scene.get("world_clock") if scene != null else null
	var now: Variant = clock.get("elapsed") if clock != null else null
	if (now is float or now is int) and is_finite(float(now)):
		var value := float(now)
		var previous := _clock_elapsed
		_clock_elapsed = value
		if previous < 0.0: return 0.0
		return clampf((value-previous)/WorldClock.SECONDS_PER_DAY,0.0,MAX_STEP_DAYS)
	if not is_finite(delta) or delta <= 0.0: return 0.0
	return minf(delta,1.0)/WorldClock.DEFAULT_DAY_LENGTH

func _daylight() -> float:
	var clock: Variant = scene.get("world_clock") if scene != null else null
	var value: Variant = clock.get("daylight") if clock != null else null
	return clampf(float(value),0.0,1.0) if (value is float or value is int) and is_finite(float(value)) else 1.0

## Where the world stands in its year. A scene without a clock sits at season 0,
## the opening of spring, which is the full rate the pond has always run at.
func _season() -> float:
	var clock: Variant = scene.get("world_clock") if scene != null else null
	var value: Variant = clock.get("season") if clock != null else null
	return clampf(float(value),0.0,1.0) if (value is float or value is int) and is_finite(float(value)) else 0.0

## Rain is read through the scene's precipitation study when it has one; a scene
## without weather is simply always dry.
func _ground_wet() -> float:
	var precipitation: Variant = scene.get("_precipitation") if scene != null else null
	var weather: Variant = precipitation.get("surface_weather") if precipitation != null else null
	var value: Variant = weather.get("ground_wet") if weather != null else null
	return clampf(float(value),0.0,1.0) if (value is float or value is int) and is_finite(float(value)) else 0.0

## An empty pond refills over RESTOCK_DAYS, twice as fast overnight and again
## while the ground is still wet from rain, and slower as the year turns cold
## (SEASON_RATE). The pond never passes its capacity.
func _restock(delta: float) -> void:
	var days := _world_days(delta)
	if days <= 0.0 or capacity <= 0: return
	rain_memory = RAIN_MEMORY if _ground_wet() >= RAIN_WET else maxf(0.0,rain_memory-days)
	if live_count() >= capacity:
		restock = 0.0
		return
	var rate := float(capacity)/RESTOCK_DAYS*WorldClock.season_factor(_season(),SEASON_RATE)
	if _daylight() < NIGHT_DAYLIGHT: rate *= NIGHT_FACTOR
	if rain_memory > 0.0: rate *= RAIN_FACTOR
	restock += days*rate
	while restock >= 1.0 and live_count() < capacity:
		if not _restock_one(): break
		restock -= 1.0
	restock = clampf(restock,0.0,1.0)

## Fill the first free slot that is under water right now. A drained pond banks
## its progress instead of dropping a fish onto dry ground.
func _restock_one() -> bool:
	for slot in home_slots:
		var taken := false
		for fish in population:
			if not fish.get("stored",false) and fish.spawn_home.distance_to(slot) < 0.01: taken = true
		if taken or not _wet(slot): continue
		_add_fish(slot)
		return true
	return false

func advance(delta: float) -> void:
	_restock(delta)
	_time += minf(delta,0.05)
	for i in range(population.size()):
		var fish: Dictionary = population[i]
		if fish.get("stored",false):
			fish.available = false
			fish.node.visible = false
			continue
		if fish.held: continue
		if fish.returning:
			fish.available = _wet(fish.home)
			fish.node.visible = fish.available
			fish.return_age += minf(delta,0.05)
			var progress := minf(fish.return_age/0.65,1.0)
			fish.node.position = fish.return_from.lerp(fish.home,progress)+Vector3.UP*sin(progress*PI)*0.25
			if progress >= 1.0: fish.returning = false
			continue
		fish.available = _wet(fish.home)
		fish.node.visible = fish.available
		if not fish.available: continue
		var phase := _time*0.65+float(i)*2.0
		var candidate: Vector3 = fish.home+Vector3(sin(phase)*0.3,0,cos(phase)*0.3)
		if fish.reserved: fish.node.position = fish.node.position.move_toward(fish.home,minf(delta,0.05)*0.8)
		elif _wet(candidate): fish.node.position = candidate
		fish.node.rotation.y = phase+PI*0.5
		fish.tail.rotation.y = sin(_time*7.0)*0.35

func available_targets() -> Array:
	var result: Array = []
	for fish in population:
		if not fish.get("stored",false) and fish.available and not fish.held and not fish.returning and _wet(fish.home):
			result.append({"id":fish.id,"position":fish.home})
	return result

func catch_fish(id: String) -> Node3D:
	for fish in population:
		if fish.id == id and not fish.get("stored",false) and fish.available and not fish.held and not fish.returning and fish.node.position.distance_to(fish.home)<0.08 and _wet(fish.home):
			fish.held = true
			return fish.node
	return null

## Adapt a successful catch to the routine's generic carry contract. The
## callback keeps this population authoritative if the trip home is cancelled;
## a rejected catch never produces a payload or a decorative stand-in.
func catch_for_carry(id: String) -> Dictionary:
	var caught := catch_fish(id)
	if caught == null: return {}
	return {
		"kind":"fish",
		"source_id":id,
		"node":caught,
		"release":func() -> void: release_fish(id),
		"commit":func() -> bool: return store_fish(id)
	}

## Take a held fish out of the pond for good. Keeping its node hidden allows an
## in-place save restore to reactivate the same fish without manufacturing one.
func store_fish(id: String) -> bool:
	for fish in population:
		if fish.id != id or not fish.held or fish.get("stored",false): continue
		fish.held = false
		fish.reserved = false
		fish.returning = false
		fish.available = false
		fish.stored = true
		fish.node.visible = false
		return true
	return false

func capture_state() -> Dictionary:
	var stored_ids: Array[String] = []
	var homes := {}
	for fish in population:
		if fish.get("stored",false): stored_ids.append(fish.id)
		homes[fish.id] = [fish.home.x,fish.home.y,fish.home.z]
	return {"version":1,"stored_ids":stored_ids,"homes":homes,"restock":restock,"capacity":capacity}

## Documents written before the pond restocked carry neither key; they keep the
## capacity this scene seeded and start their next fish from nothing.
func restore_state(state: Dictionary) -> void:
	var stored_ids: Array = state.get("stored_ids",[]) if int(state.get("version",0)) == 1 else []
	restock = clampf(float(state.get("restock",0.0)),0.0,1.0) if _is_number(state.get("restock")) else 0.0
	rain_memory = 0.0
	if _is_number(state.get("capacity")): capacity = clampi(int(state.capacity),0,home_slots.size() if not home_slots.is_empty() else MAX_FISH)
	for fish in population:
		var home: Variant = state.get("homes",{}).get(fish.id)
		fish.home = Vector3(home[0],home[1],home[2]) if home is Array else fish.spawn_home
		var stored: bool = fish.id in stored_ids
		fish.stored = stored
		fish.held = false
		fish.reserved = false
		fish.returning = false
		fish.return_age = 0.0
		fish.node.position = fish.home
		fish.available = not stored and _wet(fish.home)
		fish.node.visible = fish.available

func release_fish(id: String) -> void:
	for fish in population:
		if fish.id == id and not fish.get("stored",false):
			fish.held = false
			fish.reserved = false
			fish.returning = true
			fish.return_age = 0.0
			fish.return_from = fish.node.position
			fish.available = _wet(fish.home)
			fish.node.visible = fish.available

func reserve_target(id: String, reserved := true) -> void:
	for fish in population:
		if fish.id == id and not fish.get("stored",false): fish.reserved = reserved

static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

## Restocking makes both lists open-ended, so the shape is checked by key rather
## than by size, and older documents that lack the restock keys still load.
static func valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1: return false
	for key in value:
		if key not in ["version","stored_ids","homes","restock","capacity"]: return false
	if not value.get("stored_ids") is Array or value.stored_ids.size()>MAX_FISH: return false
	if value.has("restock") and not GardenData._number(value.restock,0.0,1.0): return false
	if value.has("capacity") and (not GardenData._number(value.capacity,0,MAX_FISH) or floor(float(value.capacity))!=float(value.capacity)): return false
	var seen := {}
	for id in value.stored_ids:
		if not id is String or id.is_empty() or id.length()>64 or seen.has(id): return false
		seen[id] = true
	if value.has("homes"):
		if not value.homes is Dictionary or value.homes.size()>MAX_FISH: return false
		for id in value.homes:
			if not id is String or id.is_empty() or id.length()>64: return false
			var point: Variant = value.homes[id]
			if not point is Array or point.size()!=3: return false
			for coordinate in point:
				if not GardenData._number(coordinate,-64,64): return false
	return true
