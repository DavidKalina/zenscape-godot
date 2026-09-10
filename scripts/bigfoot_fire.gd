extends Node
## Bigfoot and fire. Four verbs, in priority order:
##
##   flee  — a fire starts near him, or a burning cell comes inside six metres.
##           He cancels everything, startles, then runs to the navigation node
##           that maximises distance from the flames, weighted upwind, along a
##           route that never crosses a burning cell.
##   watch — once safe he turns, holds an alert pose and tracks the nearest
##           flame with his head.
##   warm  — thirty seconds after the fire is out, if the ash is inside his
##           roam, he goes over and warms his hands at the embers.
##   temper — fire near his resting spot or the tree he is hugging offends him.
##
## Driven from `bigfoot_environment.advance`, just below the lightning branch.
## The scene's `_fire_field` may be missing or null; then nothing here runs.
## `advance` returns true only while this behaviour owns the actor. The ash
## approach is deliberately *not* owned: `CreatureBrain.investigate` walks him
## there, so `busy()` stays true while `advance` returns false.

const WARM = preload("res://scripts/bigfoot_warm_hands.gd")
## A fire that starts this close is his problem.
const START_RADIUS := 14.0
## Any burning cell inside this distance means move, now.
const CELL_RADIUS := 6.0
## Keep re-picking an escape while flames are still this close.
const RETHINK_RADIUS := 10.0
const RETHINK := 2.0
const STARTLE := 1.5
const FLEE_TEMPO := 1.4
const WATCH_SECONDS := 16.0
const CURIOSITY_DELAY := 30.0
const CURIOSITY_RANGE := 20.0
const APPROACH_TIMEOUT := 45.0
const TEMPER_RADIUS := 4.0
const TEMPER_COOLDOWN := 10.0
## One payoff per fire; long enough that he does not loiter in the ash.
const WARM_COOLDOWN := 200.0
## Nothing plans a route through a cell this close to a flame.
const ROUTE_CLEARANCE := 1.2

var scene: Node
var environment: Node
var active := ""
var phase := ""
var history: Array[String] = []
var _field: FireField = null
var _clock := 0.0
var _elapsed := 0.0
var _scan := 0.0
var _rethink := 0.0
var _hazards: Array[Vector3] = []
var _threat := Vector3.ZERO
var _threat_distance := INF
var _started := Vector3.ZERO
var _pending_start := false
var _route := PackedVector3Array()
var _waypoint := 0
var _look := Vector3.ZERO
var _facing := 0.0
var _duration := 0.0
var _tempo := 1.0
var _tempo_held := false
var _ash := Vector3.ZERO
var _ash_wait := -1.0
var _ash_due := false
var _warm_cooldown := 0.0
var _temper_wait := 0.0
var _variant := {}
var _performances := 0

func setup(world: Node, controller: Node = null) -> void:
	scene = world
	environment = controller

func busy() -> bool: return not active.is_empty()

func field() -> FireField: return _field

# ---------------------------------------------------------------- lifecycle

## `owned` is the scene's `resident_activity_owned()`. Returns true while this
## behaviour owns the actor, exactly like `bigfoot_environment.advance`.
func advance(delta: float, owned := false) -> bool:
	if scene == null: return false
	_bind()
	if _field == null:
		if busy(): cancel()
		return false
	if scene._paused or delta <= 0.0: return busy() and active != "approach"
	var dt := minf(delta,0.05)
	_clock += dt
	_warm_cooldown = maxf(0.0,_warm_cooldown-dt)
	_temper_wait = maxf(0.0,_temper_wait-dt)
	var actor: CreatureActor = scene.creature
	_scan -= dt
	if _scan <= 0.0:
		_scan = 0.25
		_survey(actor)
	_provoke()
	if _ash_wait > 0.0:
		_ash_wait -= dt
		if _ash_wait <= 0.0:
			_ash_wait = -1.0
			_ash_due = true
	if owned:
		if busy(): cancel()
		return false
	if not actor.can_roam() and actor.state != CreatureActor.State.ACTION:
		if busy(): cancel()
		return false
	if busy(): return _run(actor,dt)
	return _choose(actor)

func _bind() -> void:
	var found: Variant = scene.get("_fire_field")
	var next: FireField = found if found is FireField else null
	if next == _field: return
	_field = next
	_ash_wait = -1.0
	_ash_due = false
	_hazards.clear()
	_threat_distance = INF
	_pending_start = false
	if _field != null:
		if not _field.fire_started.is_connected(_on_started): _field.fire_started.connect(_on_started)
		if not _field.fire_extinguished.is_connected(_on_extinguished): _field.fire_extinguished.connect(_on_extinguished)

func _on_started(point: Vector3) -> void:
	# Latch like the lightning strike: a pause defers the reaction, it never
	# swallows it.
	if scene == null or not bool(scene.get("resident_enabled")): return
	if not _pending_start or point.distance_to(scene.creature.position) < _started.distance_to(scene.creature.position):
		_started = point
	_pending_start = true

func _on_extinguished() -> void:
	if _warm_cooldown > 0.0: return
	_ash_wait = CURIOSITY_DELAY
	_ash_due = false

# ------------------------------------------------------------------- survey

## Down-sampled flame positions. A big fire has hundreds of burning cells and
## every scoring pass is O(nodes * hazards); sixty-four sample points describe
## a front well enough to run away from it.
func _survey(actor: CreatureActor) -> void:
	_hazards.clear()
	var cells: PackedInt32Array = _field.burning_cells()
	var stride := maxi(1,int(ceil(float(cells.size())/24.0)))
	for i in range(0,cells.size(),stride):
		_hazards.append(_field.cell_center(cells[i]))
	for id: int in _field.objects_state:
		var state: Dictionary = _field.objects_state[id]
		if float(state.burn) > 0.0: _hazards.append(state.position)
	var origin := actor.global_position
	_threat_distance = INF
	for point in _hazards:
		var distance := origin.distance_to(point)
		if distance < _threat_distance:
			_threat_distance = distance
			_threat = point

func _distance_to_fire(point: Vector3) -> float:
	var best := INF
	for hazard in _hazards:
		best = minf(best,Vector2(point.x-hazard.x,point.z-hazard.z).length())
	return best

func _wind(point: Vector3) -> Vector3:
	var resident: Variant = scene.get("_resident_wind")
	if resident != null and resident.get("field") != null:
		var value: Variant = resident.field.sample(point)
		if value is Vector3: return value
	var air: Variant = scene.get("_atmosphere")
	if air != null:
		var angle: Variant = air.get("_air_angle")
		var strength: Variant = air.get("_air_strength")
		if angle != null and strength != null:
			return Vector3(sin(float(angle)),0.0,cos(float(angle)))*float(strength)
	return Vector3.ZERO

# ------------------------------------------------------------------ choices

func _choose(actor: CreatureActor) -> bool:
	var alarmed := _threat_distance <= CELL_RADIUS
	if _pending_start:
		_pending_start = false
		var distance := actor.global_position.distance_to(_started)
		if distance <= START_RADIUS:
			alarmed = true
			if _threat_distance == INF:
				_threat = _started
				_threat_distance = distance
	if alarmed and actor.can_roam():
		_flee(actor)
		return true
	if _ash_due:
		_ash_due = false
		if _curiosity(actor): return false
	return false

func _flee(actor: CreatureActor) -> void:
	_clear_owners()
	active = "flee"
	phase = "startle"
	_elapsed = 0.0
	_rethink = 0.0
	_route.clear()
	_waypoint = 0
	# Remember the tempo he arrived with, so an enraged Bigfoot does not come
	# out of a flee walking calmly.
	if not _tempo_held:
		_tempo = actor.locomotion_tempo
		_tempo_held = true
	_look = _threat+Vector3.UP*1.2
	actor.stop_walking()
	var offset := _threat-actor.global_position
	_facing = atan2(offset.x,offset.z)
	actor.notice(_look)
	if actor.perform_action("Idle",STARTLE):
		actor.environment_pose = "startle"
	_react("fire_fright","Fire!")

func _curiosity(actor: CreatureActor) -> bool:
	var center: Vector3 = _field.ash_center()
	if center.is_equal_approx(Vector3.ZERO): return false
	if actor.global_position.distance_to(center) > CURIOSITY_RANGE: return false
	if scene.navigation.nearest_safe(center) == null: return false
	_clear_owners()
	_ash = center
	if not scene.brain.investigate(center,false,"fire_ash"): return false
	active = "approach"
	phase = "travel"
	_elapsed = 0.0
	return true

func _clear_owners() -> void:
	if scene.routine != null: scene.routine.cancel("fire")
	if environment != null and environment.busy(): environment.cancel()
	scene.brain.reset_behavior()

func _react(symbol: String, text: String) -> void:
	if scene.brain != null: scene.brain.reaction.emit(symbol,text)

# -------------------------------------------------------------------- verbs

func _run(actor: CreatureActor, dt: float) -> bool:
	_elapsed += dt
	match active:
		"flee": return _run_flee(actor,dt)
		"watch": return _run_watch(actor,dt)
		"approach": return _run_approach(actor,dt)
		"warm": return _run_warm(actor,dt)
	cancel()
	return false

func _run_flee(actor: CreatureActor, dt: float) -> bool:
	if phase == "startle":
		actor.track_gaze(_look)
		if _elapsed >= STARTLE or actor.state != CreatureActor.State.ACTION:
			actor.environment_pose = ""
			actor.clear_hand_targets()
			if actor.state == CreatureActor.State.ACTION: actor.cancel_action()
			if not _launch(actor):
				_finish("flee")
				return false
		return true
	actor.locomotion_tempo = maxf(_tempo,FLEE_TEMPO)
	actor.track_gaze(actor.global_position+actor.global_basis.z*8.0+Vector3.UP*1.4)
	_rethink -= dt
	if _rethink <= 0.0 and _threat_distance < RETHINK_RADIUS:
		_rethink = RETHINK
		var replacement := _escape_route(actor)
		if not replacement.is_empty():
			_route = replacement
			_waypoint = 0
	while _waypoint < _route.size() and actor.global_position.distance_squared_to(_route[_waypoint]) < 0.000001:
		_waypoint += 1
	if _elapsed > 40.0 or _waypoint >= _route.size():
		_settle(actor)
		return busy()
	var destination := _route[_waypoint]
	if not scene.navigation.motion_safe(actor.global_position,destination,actor.walking_speed(0.9)*dt):
		if not _launch(actor): _settle(actor)
		return busy()
	if actor.walk_step(destination,0.9,dt): _waypoint += 1
	return true

## Arrived somewhere safe: watch the flames if there are still any, otherwise
## hand him back to ordinary life.
func _settle(actor: CreatureActor) -> void:
	actor.stop_walking()
	if _tempo_held:
		actor.locomotion_tempo = _tempo
		_tempo_held = false
	if _hazards.is_empty():
		_finish("flee")
		return
	history.append("flee")
	active = "watch"
	phase = "turn"
	_elapsed = 0.0
	_look = _threat+Vector3.UP*1.0
	var offset := _threat-actor.global_position
	_facing = atan2(offset.x,offset.z)
	actor.notice(_look)

func _run_watch(actor: CreatureActor, dt: float) -> bool:
	if _threat_distance <= CELL_RADIUS and actor.can_roam():
		_flee(actor)
		return true
	if _hazards.is_empty() or _elapsed > WATCH_SECONDS:
		_finish("watch")
		return false
	_look = _threat+Vector3.UP*1.0
	if phase == "turn":
		actor.track_gaze(_look)
		if actor.turn_step(_facing,dt):
			phase = "perform"
			_elapsed = 0.0
			_duration = WATCH_SECONDS
			if not actor.perform_action("Idle",_duration):
				_finish("watch")
				return false
			actor.environment_pose = "fire_watch"
			_react("fire_watch","Watching the fire.")
		return true
	# Reuse the horizon watch: head tracks the flame, one hand shades the eyes.
	var t := actor._age+minf(dt,0.05)*actor.action_tempo
	var weight := smoothstep(0.0,0.9,t)*(1.0-smoothstep(_duration-1.2,_duration,t))
	actor.clear_hand_targets()
	actor.track_gaze(_look)
	actor.reach_hand(actor.to_global(Vector3(-0.32,2.65,0.4)),weight*0.95,"R",
		actor.to_global(Vector3(-1.0,2.1,0.2)),Basis(-actor.basis.z,actor.basis.x,-actor.basis.y))
	return true

## The brain owns the journey. Keep the routine off him while it runs, and take
## over the moment he is standing at the ash.
func _run_approach(actor: CreatureActor, _dt: float) -> bool:
	if scene.routine != null:
		if not scene.routine.active.is_empty(): scene.routine.cancel("fire")
		if "_next_action" in scene.routine and "_clock" in scene.routine:
			scene.routine._next_action = maxf(scene.routine._next_action,scene.routine._clock+2.0)
	if _elapsed > APPROACH_TIMEOUT or not actor.can_roam():
		_finish("approach")
		return false
	var reached: bool = scene.brain.phase == CreatureBrain.Phase.INSPECT or scene.brain.phase == CreatureBrain.Phase.BLOCKED
	if not reached or actor.global_position.distance_to(_ash) > 4.0: return false
	if scene.brain.phase == CreatureBrain.Phase.BLOCKED:
		_finish("approach")
		return false
	scene.brain.reset_behavior()
	actor.stop_walking()
	_performances += 1
	_variant = WARM.make_variant(_performances*911+int(_ash.x*97.0)+int(_ash.z*13.0))
	_duration = WARM.duration(_variant)
	active = "warm"
	phase = "turn"
	_elapsed = 0.0
	_look = _ash+Vector3.UP*0.15
	var offset := _ash-actor.global_position
	_facing = atan2(offset.x,offset.z)
	actor.notice(_look)
	return true

func _run_warm(actor: CreatureActor, dt: float) -> bool:
	if phase == "turn":
		actor.track_gaze(_look)
		if actor.turn_step(_facing,dt):
			phase = "perform"
			_elapsed = 0.0
			if not actor.perform_action("Idle",_duration):
				_finish("warm")
				return false
			actor.environment_pose = "fire_warm"
			_react("fire_warm","Still warm.")
		return true
	if actor.state != CreatureActor.State.ACTION:
		_warm_cooldown = WARM_COOLDOWN
		_finish("warm_hands")
		return false
	_pose_warm(actor,dt)
	return true

func _pose_warm(actor: CreatureActor, dt: float) -> void:
	var t := actor._age+minf(dt,0.05)*actor.action_tempo
	var motion: Dictionary = WARM.sample(t,_variant)
	actor.environment_motion = motion
	actor.clear_hand_targets()
	# Look at the embers, not at the ground under them: a gaze straight down
	# folds the neck to its clamp and buries the face.
	actor.track_gaze(_ash+Vector3.UP*0.55)
	var crouch: float = motion.crouch
	# Anchor the palms to the embers, not to his chest. A hand held a little
	# above and short of the ash, turned to face it, reads as warming from any
	# angle; a body-local offset only reads from the one he happens to stand at.
	var focus := _ash+Vector3.UP*(0.30+0.60*crouch)-actor.basis.z*0.30
	var reach: Dictionary = motion.reach
	for side in ["R","L"]:
		var sign := -1.0 if side == "R" else 1.0
		var weight: float = reach[side]
		var point := focus+actor.basis.x*sign*0.34
		var normal := (_ash-point).normalized()
		if normal.length_squared() < 0.5: normal = -actor.basis.y
		# Fingers keep pointing the way he faces, squared off against the palm.
		var fingers := (actor.basis.z-normal*normal.dot(actor.basis.z)).normalized()
		var palm := Basis(fingers.cross(normal).normalized(),fingers,normal)
		var elbow := actor.to_global(Vector3(sign*0.72,1.52-0.36*crouch,0.08))
		actor.reach_hand(point,weight,side,elbow,palm,weight)

# ------------------------------------------------------------------- temper

## What offends him is fire reaching what he owns, not fire near his feet: his
## resting spot and the tree he currently has his arms around.
func _provoke() -> void:
	if _temper_wait > 0.0 or _hazards.is_empty(): return
	var temper: Variant = null
	var play: Variant = scene.get("world_play")
	if play != null: temper = play.get("temper")
	if temper == null: return
	var places: Array[Vector3] = []
	if scene.routine != null and scene.routine.get("habits") != null:
		var home: Variant = scene.routine.habits.preferred()
		if home is Vector3: places.append(home)
	if environment != null and environment.active in ["tree_hug","tree_touch"] and not environment.target.is_empty():
		places.append(environment.target.center)
	for place in places:
		if _distance_to_fire(place) <= TEMPER_RADIUS:
			_temper_wait = TEMPER_COOLDOWN
			temper.provoke(0.6)
			return

# ----------------------------------------------------------------- planning

func _launch(actor: CreatureActor) -> bool:
	var route := _escape_route(actor)
	if route.is_empty(): return false
	_route = route
	_waypoint = 0
	_rethink = RETHINK
	phase = "run"
	actor.locomotion_tempo = maxf(_tempo,FLEE_TEMPO)
	return true

## Maximise distance from the nearest flame, weighted toward upwind, along a
## route that stays clear of burning ground the whole way.
func _escape_route(actor: CreatureActor) -> PackedVector3Array:
	if _hazards.is_empty(): return PackedVector3Array()
	var origin := actor.global_position
	var wind := _wind(origin)
	var flat := Vector3(wind.x,0.0,wind.z)
	var upwind := Vector3.ZERO if flat.length() < 0.05 else -flat.normalized()
	var here := _distance_to_fire(origin)
	var scored: Array = []
	# Scoring is O(nodes * hazards) and runs every two seconds. Six hundred
	# samples over the plot is under a metre of granularity, which is finer
	# than the difference between two good escapes.
	var nodes: PackedVector3Array = scene.navigation._nodes
	var stride := maxi(1,int(ceil(float(nodes.size())/600.0)))
	for i in range(0,nodes.size(),stride):
		var point := nodes[i]
		var travel := origin.distance_to(point)
		if travel < 2.0 or travel > 18.0: continue
		var away := _distance_to_fire(point)
		if away <= here+0.5: continue
		var offset := Vector3(point.x-_threat.x,0.0,point.z-_threat.z)
		var bias := 0.0 if offset.length() < 0.001 else offset.normalized().dot(upwind)
		scored.append([away+2.6*bias-0.12*travel,point])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for entry: Array in scored.slice(0,12):
		var route: PackedVector3Array = scene.navigation.path(origin,entry[1])
		if route.is_empty() or not route_clear(route): continue
		return route
	return PackedVector3Array()

## True when no point along the route stands on or beside burning ground.
func route_clear(route: PackedVector3Array) -> bool:
	if _field == null: return true
	for i in range(1,route.size()):
		var from := route[i-1]
		var to := route[i]
		var span := from.distance_to(to)
		var steps := maxi(1,int(ceil(span/0.4)))
		for s in range(steps+1):
			var point := from.lerp(to,float(s)/float(steps))
			if _distance_to_fire(point) < ROUTE_CLEARANCE: return false
			var cell: int = _field.cell_at(point)
			if cell >= 0 and _field.burn[cell] > 0.0: return false
	return true

# --------------------------------------------------------------- completion

func _finish(kind: String) -> void:
	if not kind.is_empty() and kind not in ["flee","approach"]: history.append(kind)
	cancel()

func cancel() -> void:
	if scene == null: return
	var actor: CreatureActor = scene.creature
	if _tempo_held:
		actor.locomotion_tempo = _tempo
		_tempo_held = false
	if not active.is_empty():
		actor.clear_hand_targets()
		actor.environment_pose = ""
		actor.environment_motion = {}
		if phase == "perform" and actor.state == CreatureActor.State.ACTION: actor.cancel_action()
		if actor.state == CreatureActor.State.WALKING: actor.stop_walking()
	active = ""
	phase = ""
	_route.clear()
	_waypoint = 0
	_elapsed = 0.0

func world_changed() -> void:
	cancel()
	_pending_start = false
	_hazards.clear()
	_threat_distance = INF
