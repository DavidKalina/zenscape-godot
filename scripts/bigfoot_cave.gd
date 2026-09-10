extends RefCounted
## Walk through the approved cave threshold, disappear during rest, and return.
## Surface navigation hands over only for the short path behind the black mouth.
var scene: Node
var phase := ""
var reason := ""
var tunnel := {}
var entrance := Vector3.ZERO
var chamber := Vector3.ZERO
var visits := 0
var _path := PackedVector3Array()
var _index := 0
var _elapsed := 0.0
var _away := 0.0
var _weather_time := 0.0
var _clear_time := 0.0
var _cooldown := 20.0
var _old_probe: Callable
var _interior_path := PackedVector3Array()
var concealed := false
var _inside := false

func setup(owner_scene: Node) -> void:
	scene = owner_scene

func sheltered() -> bool:
	return concealed

func advance(dt: float) -> bool:
	_cooldown = maxf(0.0,_cooldown-dt)
	var weather: Vector4 = scene._precipitation.state
	var wet := weather.x>0.25 or weather.y>0.25
	_weather_time = _weather_time+dt if wet else 0.0
	if phase.is_empty():
		if _weather_time>4.0 and _cooldown<=0.0 and scene.routine.active.is_empty() and scene.creature.can_roam():
			if not request("snow" if scene._precipitation.surface_weather.cold>0.6 else "rain"): _cooldown = 12.0
		return not phase.is_empty()
	_elapsed += dt
	if phase in ["approach","entering","leaving"]:
		if not scene.creature.can_roam():
			cancel()
			return false
		if _elapsed>70.0:
			cancel()
			return false
		if _index>=_path.size():
			scene.creature.stop_walking()
			if phase == "approach":
				_inside = true
				_old_probe = scene.creature._ground_probe
				scene.creature._ground_probe = floor_at
				_begin_path("entering",_interior_path)
			elif phase == "entering":
				concealed = true
				phase = "resting"
			else: _finish()
		else:
			var next := _path[_index]
			if phase == "approach" and not scene.navigation.motion_safe(scene.creature.position,next,scene.creature.walking_speed(0.85)*dt):
				cancel()
			elif scene.creature.walk_step(next,0.85,dt): _index += 1
	elif phase == "resting":
		_away += dt
		_clear_time = 0.0 if wet else _clear_time+dt
		var done := _away>=45.0
		if reason == "rain": done = _away>=20.0 and _clear_time>=6.0
		if reason in ["snow","hibernate"]: done = _away>=100.0
		if done and concealed:
			concealed = false
			_leave()
	return not phase.is_empty()

func request(why := "sleep") -> bool:
	if not phase.is_empty() or not scene.creature.can_roam() or not scene.routine.active.is_empty(): return false
	for item: Dictionary in scene._chunk_editor.data.tunnels:
		var route := plan(item)
		if route.is_empty(): continue
		tunnel = item.duplicate(true)
		entrance = route.entrance
		chamber = route.chamber
		_interior_path = route.get("interior",PackedVector3Array([chamber]))
		reason = why
		_away = 0.0
		_clear_time = 0.0
		scene.brain.reset_behavior()
		_begin_path("approach",route.path)
		return true
	return false

func floor_at(point: Vector3) -> Variant:
	return _asset_floor(tunnel,point)

func _begin_path(next_phase: String, path: PackedVector3Array) -> void:
	phase = next_phase
	_path = path
	_index = 0
	_elapsed = 0.0

func _leave() -> void:
	var reverse := _interior_path.duplicate()
	reverse.reverse()
	reverse.append(entrance)
	_begin_path("leaving",reverse)

func cancel() -> void:
	if phase.is_empty(): return
	var was_inside := _inside
	# Clear ownership before cancelling the actor (which emits callbacks).
	phase = ""
	if scene.creature.state == CreatureActor.State.ACTION: scene.creature.cancel_action()
	if was_inside and not scene.creature.is_held():
		var safe: Variant = scene.navigation.nearest_safe(entrance)
		if safe != null: scene.creature.reset_at(safe)
	_finish(false)

func _finish(completed := true) -> void:
	if _inside: scene.creature._ground_probe = _old_probe
	_inside = false
	concealed = false
	phase = ""
	tunnel = {}
	_path.clear()
	scene.creature.stop_walking()
	scene.brain.reset_behavior()
	_cooldown = 90.0
	_weather_time = 0.0
	scene.routine._next_action = scene.routine._clock+9.0
	if completed:
		visits += 1
		scene.routine.history.append("hibernate" if reason in ["snow","hibernate"] else "sleep")

## Only prepared cave sites are homes; ordinary mining tunnels are unchanged.
func plan(item: Dictionary) -> Dictionary:
	if not item.get("cave",false) or item.sealed or item.width<6.4 or item.height<4.8 or item.length<7.2: return {}
	var pose := preload("res://scripts/bigfoot_cave_site.gd").pose(item)
	var outside := pose*Vector3(0,0,1.3)
	var safe: Variant = scene.navigation.nearest_safe(outside)
	if safe == null or Vector2(safe.x-outside.x,safe.z-outside.z).length()>0.7: return {}
	var inside := PackedVector3Array()
	for point in [Vector3(0,0,0.4),Vector3(0.15,0,-1.25)]: inside.append(pose*point)
	var previous: Vector3 = safe
	for destination in inside:
		var start := previous
		var count := maxi(1,ceili(start.distance_to(destination)/0.15))
		for i in range(count+1):
			var sample: Variant = _asset_floor(item,start.lerp(destination,float(i)/count))
			if sample == null or absf(sample.y-previous.y)>0.16: return {}
			previous = sample
	var path: PackedVector3Array = scene.navigation.path(scene.creature.position,safe)
	if path.is_empty(): return {}
	return {"entrance":safe,"chamber":inside[-1],"path":path,"interior":inside}

func _asset_floor(item: Dictionary, point: Vector3) -> Variant:
	var pose := preload("res://scripts/bigfoot_cave_site.gd").pose(item)
	var local := pose.affine_inverse()*point
	var center := clampf(-local.z/5.0,0.0,1.0)*1.1
	if absf(local.x-center)>0.8 or local.z< -5.3 or local.z>2.5: return null
	var surface: Variant = scene.habitat.ground_height(Vector2(point.x,point.z))
	if surface == null: return null
	var feet := Vector3(point.x,float(surface) if local.z>0.2 else pose.origin.y+0.025,point.z)
	if not scene.habitat.clear_at(feet,true) or scene.navigation._wet(feet): return null
	# The terrain cut and asset floor share an elevation. World edits cancel
	# ownership before rebuilding navigation and considering another visit.
	return feet
