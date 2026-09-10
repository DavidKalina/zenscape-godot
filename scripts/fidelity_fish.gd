extends Node3D
## A small explicit fish population. Every fish has a persistent identity while
## alive in this scene; catching borrows that same node and returning releases it.
var scene: Node
var population: Array[Dictionary] = []
var _time := 0.0

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
				if not scene.routine._plan_approach({"position":home},"fish",false): continue
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
			_add_fish(home)
			break

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

func advance(delta: float) -> void:
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

## Commit a held identity to the lair. Keeping its node hidden allows an
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
	return {"version":1,"stored_ids":stored_ids,"homes":homes}

func restore_state(state: Dictionary) -> void:
	var stored_ids: Array = state.get("stored_ids",[]) if int(state.get("version",0)) == 1 else []
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

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=(3 if value.has("homes") else 2) or value.get("version")!=1: return false
	if not value.get("stored_ids") is Array or value.stored_ids.size()>128: return false
	var seen := {}
	for id in value.stored_ids:
		if not id is String or id.is_empty() or id.length()>64 or seen.has(id): return false
		seen[id] = true
	if value.has("homes"):
		if not value.homes is Dictionary or value.homes.size()>128: return false
		for id in value.homes:
			if not id is String or id.is_empty() or id.length()>64: return false
			var point: Variant = value.homes[id]
			if not point is Array or point.size()!=3: return false
			for coordinate in point:
				if not GardenData._number(coordinate,-64,64): return false
	return true
