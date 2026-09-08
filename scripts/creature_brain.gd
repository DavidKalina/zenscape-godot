class_name CreatureBrain
extends Node
## Small, interruptible choices. Navigation owns reachability; the actor owns
## motion/animation and physical interruptions. The scene advances this clock.
signal reaction(symbol: String, text: String)
enum Phase { REST, NOTICE, MOVE, INSPECT, BLOCKED }
const CURIOUS_SPEED := 0.50
const WANDER_SPEED := 0.85
const EXCITED_SPEED := 1.50
var phase := Phase.REST
var actor: Node3D
var navigation: RefCounted
var interest_provider: Callable
var enabled := true
var speed := WANDER_SPEED
var _route := PackedVector3Array()
var _waypoint := 0
var _wait := 1.5
var _clock := 0.0
var _look_at := Vector3.ZERO
var _destination := Vector3.ZERO
var _interest_id := ""
var _tracks_object := false
var _cooldowns: Dictionary = {}
var _known: Dictionary = {}
var _pending_interest: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _interrupted := false
var _blocked_cooldown := 0.0

func setup(inhabitant: Node3D, routes: RefCounted, interests: Callable) -> void:
	actor = inhabitant
	navigation = routes
	interest_provider = interests
	_rng.seed = 4707
	for interest: Dictionary in _interests(): _known[str(interest.id)] = true

func _interests() -> Array:
	return interest_provider.call() if interest_provider.is_valid() else []

func advance(delta: float) -> void:
	if not enabled or actor == null or navigation == null or delta <= 0.0: return
	var dt := minf(delta,0.1)
	_clock += dt
	_blocked_cooldown = maxf(0.0,_blocked_cooldown-dt)
	if not actor.can_roam():
		_route.clear()
		phase = Phase.REST
		_wait = 1.5
		_interrupted = true
		return
	if _interrupted:
		_interrupted = false
		actor.stop_walking()
		_wait = 1.5
	if not _pending_interest.is_empty() and phase == Phase.REST:
		var interest := _pending_interest
		_pending_interest = {}
		if investigate(interest.position,true,str(interest.id)): return
	if phase == Phase.MOVE:
		_move(dt)
		return
	_wait -= dt
	if _wait > 0.0: return
	match phase:
		Phase.NOTICE:
			phase = Phase.MOVE
		Phase.INSPECT, Phase.BLOCKED:
			_rest(_rng.randf_range(2.0,4.0))
		Phase.REST:
			_choose_next()

func investigate(point: Vector3, excited := false, id := "") -> bool:
	if actor == null or not actor.can_roam() or not point.is_finite(): return false
	var route := _approach_route(point)
	if route.is_empty(): return false
	actor.stop_walking()
	_route = route
	_waypoint = 0
	_destination = route[route.size()-1]
	_look_at = point
	_interest_id = id
	_tracks_object = _known.has(id)
	speed = EXCITED_SPEED if excited else CURIOUS_SPEED
	phase = Phase.NOTICE
	_wait = 0.65 if excited else 1.1
	actor.notice(point+Vector3.UP*0.8)
	reaction.emit("!" if excited else "?", "Oh! Something new." if excited else "What's over there?")
	if not id.is_empty(): _cooldowns[id] = _clock+25.0
	return true

func _approach_route(point: Vector3) -> PackedVector3Array:
	var toward := Vector2(actor.global_position.x-point.x,actor.global_position.z-point.z)
	var angle := toward.angle()
	# Inspect from outside the object's collision hull, trying the near side first.
	for i in range(8):
		var offset := Vector2.from_angle(angle+i*TAU/8.0)*1.6
		var candidate: Variant = navigation.nearest_safe(point+Vector3(offset.x,0,offset.y))
		if candidate == null or Vector2(candidate.x-point.x,candidate.z-point.z).length()>3.0: continue
		var route: PackedVector3Array = navigation.path(actor.global_position,candidate)
		if route.is_empty(): continue
		return route
	return PackedVector3Array()

func _choose_next() -> void:
	var interests := _interests()
	# Rotate selection with a local seeded generator, without affecting scenery RNG.
	if not interests.is_empty() and _rng.randf()<0.7:
		var start := _rng.randi_range(0,interests.size()-1)
		for n in range(interests.size()):
			var interest: Dictionary = interests[(start+n)%interests.size()]
			var id := str(interest.id)
			if float(_cooldowns.get(id,0.0))>_clock: continue
			if actor.global_position.distance_to(interest.position)>10.0: continue
			if investigate(interest.position,false,id): return
	for attempt in range(8):
		var angle := _rng.randf()*TAU
		var radius := _rng.randf_range(2.0,4.5)
		var candidate: Variant = navigation.nearest_safe(actor.global_position+Vector3(cos(angle)*radius,0,sin(angle)*radius))
		if candidate == null or actor.global_position.distance_to(candidate)<1.0: continue
		var route: PackedVector3Array = navigation.path(actor.global_position,candidate)
		if route.is_empty(): continue
		_route = route
		_waypoint = 0
		_destination = route[route.size()-1]
		_interest_id = ""
		_tracks_object = false
		speed = WANDER_SPEED
		phase = Phase.MOVE
		return
	_blocked()

func _move(delta: float) -> void:
	if _waypoint >= _route.size():
		actor.stop_walking()
		if _interest_id.is_empty():
			_rest(_rng.randf_range(2.0,4.0))
		else:
			phase = Phase.INSPECT
			_wait = 2.8
			actor.notice(_look_at+Vector3.UP*0.8)
			reaction.emit("?","Taking a closer look.")
		return
	var destination := _route[_waypoint]
	if not navigation.segment_safe(actor.global_position,destination):
		_blocked()
		return
	if actor.walk_step(destination,speed,delta): _waypoint += 1

func _rest(duration: float) -> void:
	actor.stop_walking()
	_route.clear()
	phase = Phase.REST
	_wait = duration

func reset_behavior() -> void:
	_pending_interest.clear()
	_interrupted = false
	_interest_id = ""
	_tracks_object = false
	_rest(1.5)

func _blocked() -> void:
	actor.stop_walking()
	_route.clear()
	phase = Phase.BLOCKED
	_wait = 1.5
	if _blocked_cooldown <= 0.0:
		actor.notice(_destination+Vector3.UP)
		reaction.emit("?","That way changed. Let's try somewhere else.")
		_blocked_cooldown = 8.0

func world_changed() -> void:
	# Keep only current IDs; a newly placed nearby object can become a discovery.
	var current := {}
	for interest: Dictionary in _interests():
		var id := str(interest.id)
		current[id] = interest
		if not _known.has(id) and float(_cooldowns.get(id,0.0))<=_clock and actor.global_position.distance_to(interest.position)<9.0:
			_pending_interest = interest.duplicate()
	if not _pending_interest.is_empty():
		_pending_interest = current.get(str(_pending_interest.id),{}).duplicate()
	_known = current
	if _tracks_object:
		if not current.has(_interest_id):
			_tracks_object = false
			_interest_id = ""
			if actor.can_roam(): _rest(1.5)
		elif not _look_at.is_equal_approx(current[_interest_id].position):
			_look_at = current[_interest_id].position
			if actor.can_roam() and phase in [Phase.NOTICE,Phase.MOVE,Phase.INSPECT]:
				var route := _approach_route(_look_at)
				if route.is_empty():
					_blocked()
				else:
					actor.stop_walking()
					_route = route
					_waypoint = 0
					_destination = route[route.size()-1]
					phase = Phase.NOTICE
					_wait = 0.3
					actor.notice(_look_at+Vector3.UP*0.8)
	if not actor.can_roam():
		_route.clear()
		return
	if phase == Phase.MOVE or phase == Phase.NOTICE:
		var previous := actor.global_position
		for i in range(_waypoint,_route.size()):
			if not navigation.segment_safe(previous,_route[i]):
				_blocked()
				return
			previous = _route[i]
