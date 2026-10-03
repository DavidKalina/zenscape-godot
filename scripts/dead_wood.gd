extends Node3D
## Branches the weather tears out of the trees. Wind and falling water drop them
## on the walkable ground under a tree, they lie there as a visible trace, they
## rot away after a few world days, and while they lie there they are the thing
## Bigfoot gathers for his bed.
##
## Like the pond, this lives on world time (`scene.world_clock.elapsed`), never
## on engine seconds: a frozen sky drops nothing and a fast day drops branches at
## the same visible pace. A scene with no clock falls back to a world day of
## `WorldClock.DEFAULT_DAY_LENGTH` real seconds.
##
## The season reaches both rates through `WorldClock.season_factor`: autumn
## sheds the most, deep winter the least once the canopy is bare, and cold
## preserves fallen wood while a warm summer rots it.

const MAX_BRANCHES := 12       ## Visible traces at once; the ground never becomes a woodpile.
const MAX_SITES := 24          ## Drop points under trees.
const ROT_DAYS := 4.0          ## World days a branch lies there before it is gone.
const WEATHERED_DAYS := 2.5    ## When it starts visibly greying and settling.
const STORM_DROPS_PER_DAY := 6.0  ## A storm strips the canopy.
const RAIN_DROPS_PER_DAY := 2.0   ## Rain works loose what the storm would tear.
const CALM_DROPS_PER_DAY := 0.35  ## Even a fair day loses the odd dead limb.
const WIND_REFERENCE := 0.4    ## The precipitation study's resting wind.
const MAX_WIND_FACTOR := 2.0   ## A gale drops at most twice the still-air rate.
const MAX_STEP_DAYS := 1.0     ## A skipped or restored day must not bury the forest.
const GATHER_RANGE := 11.0     ## Matches the living world's own gather reach.
const SITE_SPACING := 1.1      ## Two branches never land on the same spot.
const SEASON_DROP := [1.0, 0.8, 1.6, 0.6]  ## Drop multiplier at the opening of spring, summer, autumn, winter.
const SEASON_ROT := [1.0, 0.75, 1.0, 1.5]   ## Rot-time multiplier: summer rots fast, winter keeps wood.
const TREE_KINDS := ["tree", "broadleaf", "redwood", "bigfoot_tree", "layered_tree", "birch", "willow", "juniper"]

var scene: Node
var branches: Array[Dictionary] = []  ## {id, position, age, carried, node, wood}
var sites: Array[Vector3] = []        ## Walkable ground under the trees.
var drop := 0.0                       ## Branch-fractions banked toward the next drop, 0..1.
var _next_id := 0
var _spent: Array[Node3D] = []        ## Nodes handed to a carry and already delivered.
var _clock_elapsed := -1.0            ## Last world-second reading; negative until first sampled.
var _sites_stale := false             ## A new world: the habitat still has the old trees.

func setup(owner_scene: Node) -> void:
	scene = owner_scene
	rebuild_sites()
	var editor: Variant = scene.get("_chunk_editor") if scene != null else null
	if editor != null: editor.data.state_restored.connect(_world_restored)

## A new world (`reset_flat`: the flip, a new plain, a regrow) starts with a
## bare floor. Undo and loads keep theirs; a load's own wood comes back
## through `restore_state`.
func _world_restored(state: Dictionary) -> void:
	if state.is_empty(): clear()

## Every branch goes, and the sites under the old trees with them. No new
## sites are read until the habitat is rebuilt (`rebuild_sites`, from the
## scene's `_refresh_habitat`): until then it still describes the trees that
## were, and new wood would fall under trees that are gone.
func clear() -> void:
	for branch in branches:
		if is_instance_valid(branch.node): branch.node.queue_free()
	branches.clear()
	sites.clear()
	drop = 0.0
	_sites_stale = true

## Called again whenever the habitat is rebuilt. Existing branches keep the
## ground they are already lying on; only future drops follow the new trees.
func rebuild_sites() -> void:
	sites.clear()
	_sites_stale = false
	if scene == null: return
	var habitat: Variant = scene.get("habitat")
	var navigation: Variant = scene.get("navigation")
	if habitat == null or navigation == null: return
	for item: Dictionary in habitat.interests:
		if sites.size() >= MAX_SITES: break
		if not _is_tree(item): continue
		for turn in range(6):
			var offset := Basis(Vector3.UP, float(turn) * TAU / 6.0) * Vector3(0, 0, 2.1)
			var candidate: Variant = navigation.nearest_safe(item.position + offset)
			if candidate == null: continue
			var point: Vector3 = candidate
			var reach := Vector2(point.x - item.position.x, point.z - item.position.z).length()
			if reach < 0.8 or reach > 4.0: continue
			var spaced := true
			for other in sites:
				if other.distance_to(point) < SITE_SPACING * 1.5: spaced = false
			if not spaced: continue
			sites.append(_on_ground(point))
			break

static func _is_tree(item: Dictionary) -> bool:
	var id := str(item.get("id", ""))
	return id.begins_with("mesh-8:") or id.begins_with("mesh-11:") or item.get("kind", "") in TREE_KINDS

func _on_ground(point: Vector3) -> Vector3:
	var habitat: Variant = scene.get("habitat") if scene != null else null
	var height: Variant = habitat.ground_height(Vector2(point.x, point.z)) if habitat != null else null
	return Vector3(point.x, float(height) + 0.06, point.z) if (height is float or height is int) and is_finite(float(height)) else point

## World days since the last tick, from the clock when the scene has one.
func _world_days(delta: float) -> float:
	var clock: Variant = scene.get("world_clock") if scene != null else null
	var now: Variant = clock.get("elapsed") if clock != null else null
	if (now is float or now is int) and is_finite(float(now)):
		var value := float(now)
		var previous := _clock_elapsed
		_clock_elapsed = value
		if previous < 0.0: return 0.0
		return clampf((value - previous) / WorldClock.SECONDS_PER_DAY, 0.0, MAX_STEP_DAYS)
	if not is_finite(delta) or delta <= 0.0: return 0.0
	return minf(delta, 1.0) / WorldClock.DEFAULT_DAY_LENGTH

func _precipitation() -> Variant:
	return scene.get("_precipitation") if scene != null else null

## The sky's preset name, read the same defensive way the living world reads it:
## a study with no weather lives in permanent calm.
func weather() -> String:
	var sky: Variant = _precipitation()
	var index: Variant = sky.get("preset_index") if sky != null else null
	if not (index is int or index is float) or not is_finite(float(index)): return "clear"
	var slot := int(index)
	var names: Array = WeatherScheduler.PRESET_NAMES
	return str(names[slot]) if slot >= 0 and slot < names.size() else "clear"

func wind() -> float:
	var sky: Variant = _precipitation()
	var value: Variant = sky.get("wind") if sky != null else null
	return clampf(float(value), 0.0, 4.0) if (value is float or value is int) and is_finite(float(value)) else WIND_REFERENCE

## Branches per world day. Storm high, rain lower, calm days barely at all, and
## all three scale with the wind the sky is carrying and with the season.
func _drop_rate() -> float:
	var sky := weather()
	var base := CALM_DROPS_PER_DAY
	if sky == "storm": base = STORM_DROPS_PER_DAY
	elif sky == "rain": base = RAIN_DROPS_PER_DAY
	var gust := clampf(wind() / WIND_REFERENCE, 0.0, MAX_WIND_FACTOR) if WIND_REFERENCE > 0.0 else 1.0
	return base * (0.4 + 0.6 * gust) * WorldClock.season_factor(season(), SEASON_DROP)

## World days a branch survives on the ground: the cold keeps it, summer takes it.
func rot_days() -> float:
	return ROT_DAYS * WorldClock.season_factor(season(), SEASON_ROT)

## The year, read the same defensive way the pond reads it: no clock, no season.
func season() -> float:
	var clock: Variant = scene.get("world_clock") if scene != null else null
	var value: Variant = clock.get("season") if clock != null else null
	return clampf(float(value), 0.0, 1.0) if (value is float or value is int) and is_finite(float(value)) else 0.0

func advance(delta: float) -> void:
	_sweep()
	var days := _world_days(delta)
	if days <= 0.0: return
	_rot(days)
	if sites.is_empty() and not _sites_stale: rebuild_sites()
	if branches.size() >= MAX_BRANCHES:
		drop = 0.0
		return
	drop += days * _drop_rate()
	while drop >= 1.0 and branches.size() < MAX_BRANCHES:
		if not _drop_one(): break
		drop -= 1.0
	drop = clampf(drop, 0.0, 1.0)

## A delivered branch's node belongs to the carry until the carry lets go of it,
## so it is freed on the next tick rather than under the caller's feet.
func _sweep() -> void:
	for node in _spent:
		if is_instance_valid(node): node.queue_free()
	_spent.clear()

func _rot(days: float) -> void:
	var limit := rot_days()
	for index in range(branches.size() - 1, -1, -1):
		var branch: Dictionary = branches[index]
		branch.age = float(branch.age) + days
		if bool(branch.get("carried", false)): continue
		if float(branch.age) >= limit:
			if is_instance_valid(branch.node): branch.node.queue_free()
			branches.remove_at(index)
			continue
		_weather_look(branch)

## Old wood greys and settles into the leaf litter before it disappears, so a
## watcher can tell a fresh fall from one that is about to rot away.
func _weather_look(branch: Dictionary) -> void:
	if not is_instance_valid(branch.node): return
	var wear := clampf((float(branch.age) - WEATHERED_DAYS) / maxf(0.01, rot_days() - WEATHERED_DAYS), 0.0, 1.0)
	var wood: MeshInstance3D = branch.get("wood")
	if is_instance_valid(wood) and wood.material_override is StandardMaterial3D:
		wood.material_override.albedo_color = Color("59432f").lerp(Color("6d675c"), wear)
	branch.node.position = Vector3(branch.position.x, float(branch.position.y) - wear * 0.05, branch.position.z)

func _drop_one() -> bool:
	if sites.is_empty(): return false
	var free: Array[Vector3] = []
	for site in sites:
		var taken := false
		for branch in branches:
			if Vector3(branch.position).distance_to(site) < SITE_SPACING: taken = true
		if not taken: free.append(site)
	if free.is_empty(): return false
	# Deterministic without an rng of its own: the accumulator's fractional part
	# and the branch count pick the site, so a restored garden drops where the
	# same weather would have dropped.
	var choice: Vector3 = free[(_next_id + branches.size()) % free.size()]
	_add_branch(choice, 0.0)
	return true

func _add_branch(point: Vector3, age: float) -> Dictionary:
	var node := Node3D.new()
	node.name = "FallenBranch%d" % _next_id
	add_child(node)
	node.position = point
	node.rotation.y = float(_next_id) * 1.1
	var wood := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.028
	mesh.bottom_radius = 0.05
	mesh.height = 0.9
	mesh.radial_segments = 6
	wood.mesh = mesh
	wood.rotation.z = PI * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("59432f")
	material.roughness = 0.95
	wood.material_override = material
	node.add_child(wood)
	var twig := MeshInstance3D.new()
	var fork := CylinderMesh.new()
	fork.top_radius = 0.014
	fork.bottom_radius = 0.024
	fork.height = 0.42
	fork.radial_segments = 5
	twig.mesh = fork
	twig.rotation = Vector3(0, 0, PI * 0.5)
	twig.rotate_y(0.8)
	twig.position = Vector3(0.22, 0.01, 0.1)
	twig.material_override = material
	node.add_child(twig)
	var branch := {"id": "branch:%d" % _next_id, "position": point, "age": age, "carried": false, "node": node, "wood": wood}
	_next_id += 1
	branches.append(branch)
	_weather_look(branch)
	return branch

## Every branch a gatherer may walk to right now, in the shape the living world's
## other target lists use.
func targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for branch in branches:
		if bool(branch.get("carried", false)): continue
		result.append({"id": str(branch.id), "position": Vector3(branch.position), "kind": "branch"})
	return result

func count() -> int:
	var total := 0
	for branch in branches:
		if not bool(branch.get("carried", false)): total += 1
	return total

## How many lie within his gather reach; the decision context's branches_nearby.
func nearby(point: Vector3, radius := GATHER_RANGE) -> int:
	var total := 0
	for branch in branches:
		if bool(branch.get("carried", false)): continue
		if Vector3(branch.position).distance_to(point) <= radius: total += 1
	return total

## Lift one branch off the ground for the carry home. The ground copy hides
## rather than dying, so a cancelled trip puts the same branch back where it lay.
func take_for_carry(id: String) -> Dictionary:
	for branch in branches:
		if branch.id != id or bool(branch.get("carried", false)): continue
		if not is_instance_valid(branch.node): return {}
		branch.carried = true
		return {
			"kind": "branch",
			"source_id": id,
			"node": branch.node,
			"release": func() -> void: release(id),
			"commit": func() -> bool: return consume(id)
		}
	return {}

## The carry was abandoned: the branch is on the ground again, as old as it was.
func release(id: String) -> void:
	for branch in branches:
		if branch.id != id or not bool(branch.get("carried", false)): continue
		branch.carried = false
		if not is_instance_valid(branch.node): continue
		if branch.node.get_parent() != self: branch.node.reparent(self)
		branch.node.position = Vector3(branch.position)
		branch.node.visible = true

## Branches lying within `radius` of `point` (world) are taken off the ground
## for good (the trash can sweeping them up). Returns their nodes, still
## shown, for the caller to send off and free.
func sweep(point: Vector3, radius: float) -> Array[Node3D]:
	var here := to_local(point)
	var nodes: Array[Node3D] = []
	var kept: Array[Dictionary] = []
	for branch in branches:
		if bool(branch.get("carried", false)) or Vector3(branch.position).distance_to(here) > radius:
			kept.append(branch)
			continue
		if is_instance_valid(branch.node): nodes.append(branch.node)
	branches = kept
	return nodes

## The carry reached the lair: this branch is gone from the world for good.
func consume(id: String) -> bool:
	for index in range(branches.size()):
		var branch: Dictionary = branches[index]
		if branch.id != id or not bool(branch.get("carried", false)): continue
		if is_instance_valid(branch.node):
			branch.node.visible = false
			_spent.append(branch.node)
		branches.remove_at(index)
		return true
	return false

func capture_state() -> Dictionary:
	var saved: Array = []
	for branch in branches:
		saved.append({"id": str(branch.id), "position": [branch.position.x, branch.position.y, branch.position.z], "age": float(branch.age)})
	return {"version": 1, "branches": saved, "drop": drop, "next_id": _next_id}

## Documents written before the wind dropped anything carry no branches at all;
## they load into a clean forest floor rather than being rejected.
func restore_state(state: Dictionary) -> void:
	if not state.is_empty() and not valid_state(state): return
	for branch in branches:
		if is_instance_valid(branch.node): branch.node.queue_free()
	branches.clear()
	drop = clampf(float(state.get("drop", 0.0)), 0.0, 1.0)
	_next_id = int(state.get("next_id", 0))
	_clock_elapsed = -1.0
	for entry: Dictionary in state.get("branches", []):
		var point: Array = entry.position
		var restored := _add_branch(Vector3(float(point[0]), float(point[1]), float(point[2])), clampf(float(entry.age), 0.0, ROT_DAYS))
		restored.id = str(entry.id)
	_next_id = maxi(_next_id, branches.size())

## Checked key by key rather than by size, so a later slice may add a key and
## every document written today still loads.
static func valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1: return false
	for key in value:
		if key not in ["version", "branches", "drop", "next_id"]: return false
	if value.has("drop") and not GardenData._number(value.drop, 0.0, 1.0): return false
	if value.has("next_id") and (not GardenData._integer(value.next_id) or not GardenData._number(value.next_id, 0, 1000000)): return false
	var entries: Variant = value.get("branches", [])
	if not entries is Array or entries.size() > MAX_BRANCHES: return false
	var seen := {}
	for entry in entries:
		if not entry is Dictionary or entry.size() != 3: return false
		var id: Variant = entry.get("id")
		if not id is String or id.is_empty() or id.length() > 64 or seen.has(id): return false
		seen[id] = true
		if not GardenData._number(entry.get("age"), 0.0, ROT_DAYS): return false
		var point: Variant = entry.get("position")
		if not point is Array or point.size() != 3: return false
		for coordinate in point:
			if not GardenData._number(coordinate, -1000, 1000): return false
	return true
