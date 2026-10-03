extends RefCounted
## A simulated week of Bigfoot's life, fast enough for the suite. The real mind,
## living-world controller, cave, pond, world clock and weather scheduler run
## unmodified at world speed 1; only the body is stubbed. He walks in straight
## lines at his walking pace, animations are timers, and the routine's fish and
## tree trips are reduced to walk there, sit, then carry it home through the real
## cave. Pure: no rendering, safe to run headless. Used by the slice 1 and slice 2
## week tests of the world-progression plan.

const Fish := preload("res://scripts/fidelity_fish.gd")
const DT := 0.05  ## The resident clock's own step cap, so needs keep exact time.
const CAVE_ENTRANCE := Vector3.ZERO
const POND := Vector3(14, 0.5, 0)
const TREES := [Vector3(6, 0, 5), Vector3(-7, 0, 4)]

var scene: Scene
var clock: WorldClock
var scheduler: WeatherScheduler
var living: RefCounted
## Longest unbroken run of world hours with no fish or fruit in the lair.
var longest_empty_food_hours := 0.0
## Each storm the sky wore: world hours from/to and the bed stage either side.
var storms: Array[Dictionary] = []
var storm_hours := 0.0
var sheltered_storm_hours := 0.0
## Storm hours spent out of the cave, keyed by what he was doing at the time.
var exposed_storm_hours := {}
var _empty_hours := 0.0
var _last_hour := 0.0
var _storming := false

## A real CreatureActor, since the controller types its actor, with every
## movement and animation call replaced: no model, no player, no physics.
class Creature extends CreatureActor:
	const WALK_MPS := 1.0
	const ACTION_SECONDS := {"SitDown": 1.5, "StandUp": 1.5, "Idle": 4.0}
	var _action_left := 0.0

	func walking_speed(base_speed: float) -> float: return base_speed*WALK_MPS
	func can_roam() -> bool: return state in [CreatureActor.State.IDLE,CreatureActor.State.WALKING]
	func is_held() -> bool: return false
	func notice(_point: Vector3) -> void: pass
	func reach_hand(_point: Vector3, _weight: float, _side := "R", _elbow: Variant = null, _palm_basis: Variant = null, _palm_weight := 1.0) -> void: pass
	func clear_hand_targets() -> void: pass
	func hand_position(_side := "R") -> Vector3: return position+Vector3.UP

	func reset_at(point: Vector3) -> void:
		position = point
		state = CreatureActor.State.IDLE

	func walk_step(destination: Vector3, speed: float, delta: float, _gait := "Walk") -> bool:
		state = CreatureActor.State.WALKING
		position = position.move_toward(destination,walking_speed(speed)*delta)
		return position.distance_to(destination)<0.01

	func stop_walking() -> void:
		if state==CreatureActor.State.WALKING: state = CreatureActor.State.IDLE

	func perform_action(clip: String, duration := -1.0) -> bool:
		state = CreatureActor.State.ACTION
		action_clip = clip
		_age = 0.0
		_action_left = duration if duration>0.0 else float(ACTION_SECONDS.get(clip,4.0))
		return true

	func cancel_action() -> void:
		if state!=CreatureActor.State.ACTION: return
		var clip := action_clip
		state = CreatureActor.State.IDLE
		action_clip = ""
		action_finished.emit(clip,true)

	## Animations are timers; a finished clip reports the way the real actor does.
	func tick(delta: float) -> void:
		if state!=CreatureActor.State.ACTION: return
		_age += delta
		if _age<_action_left: return
		var clip := action_clip
		state = CreatureActor.State.IDLE
		action_clip = ""
		action_finished.emit(clip,false)

class Walkable extends RefCounted:
	func path(_from: Vector3, to: Vector3) -> PackedVector3Array: return PackedVector3Array([to])
	func nearest_safe(point: Vector3) -> Variant: return Vector3(point.x,0.0,point.z)
	func is_safe(_point: Vector3) -> bool: return true
	func motion_safe(_from: Vector3, _to: Vector3, _step: float) -> bool: return true

class Brain extends RefCounted:
	signal reaction(icon: String, text: String)
	var interest_choices_enabled := true
	func reset_behavior() -> void: pass
	func ready_for_activity(_dt: float) -> bool: return true
	func _approach_route(point: Vector3) -> PackedVector3Array: return PackedVector3Array([Vector3(point.x,0.0,point.z)])

## A metre of water over the pond, dry ground everywhere else.
class Water extends RefCounted:
	const CENTRE := Vector2(14,0)
	var _stream_channels: Array = []
	func height_at(x: float, z: float) -> Variant: return 1.0 if Vector2(x,z).distance_to(CENTRE)<4.0 else null

class Habitat extends RefCounted:
	var waters: Array = [Water.new()]
	var ponds: Array = []
	var solids: Array = []
	var interests: Array[Dictionary] = []
	func ground_height(_point: Vector2) -> Variant: return 0.0

class Surface extends RefCounted:
	var ground_wet := 0.0
	var cold := 0.0

## The precipitation study's slow state and the real ground-wetness curve,
## advanced on engine seconds exactly as studies/precipitation.gd does.
class Weather extends RefCounted:
	const SurfaceWeather := preload("res://studies/surface_weather.gd")
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/weather-profiles.json"))
	var preset_index := 0
	var state := Vector4(0,0,0.06,0)
	var target := Vector4(0,0,0.06,0)
	var surface_weather := Surface.new()

	func set_weather(index: int) -> void:
		preset_index = index
		var profile: Dictionary = profiles[WeatherScheduler.PRESET_NAMES[index]]
		target = Vector4(profile.rain,0.0,profile.cloud,profile.storm)

	func advance(delta: float) -> void:
		state = state.lerp(target,1.0-exp(-delta*0.55))
		surface_weather.ground_wet = SurfaceWeather.wet_after(surface_weather.ground_wet,minf(1.0,state.x+state.y),0.0,state.z,0.4,delta)

## The lair room's stash and bed rules without its meshes.
class Lair extends Node3D:
	const MAX_LIVING_STAGE := 3
	var stash: Array = []
	var bed_stage := 0
	var play_stage := 0
	var bed := Node3D.new()

	func _init() -> void: add_child(bed)
	func can_receive_item(kind: String) -> bool: return kind in ["branch","leaves","fish","fruit"] and stash.size()<24
	func food_count() -> int: return stash.count("fruit")+stash.count("fish")
	func material_count() -> int: return stash.count("leaves")+stash.count("branch")
	func comfort() -> float: return float(bed_stage)/MAX_LIVING_STAGE
	func supply_point() -> Vector3: return Vector3(2.35,0.2,-0.4)
	func play_point() -> Vector3: return Vector3(-0.75,0.2,0.85)
	func capture_living() -> Dictionary: return {"bed_stage":bed_stage,"play_stage":play_stage}

	func receive_item_checked(kind: String, commit: Callable) -> bool:
		if not can_receive_item(kind) or not commit.is_valid(): return false
		if commit.call()!=true: return false
		return receive_item(kind)

	func receive_item(kind: String) -> bool:
		if not can_receive_item(kind): return false
		stash.append(kind)
		return true

	func tend_bed() -> bool:
		if bed_stage>=MAX_LIVING_STAGE or material_count()==0: return false
		stash.erase("leaves" if stash.has("leaves") else "branch")
		bed_stage += 1
		return true

	func eat_food() -> String:
		var kind := "fruit" if stash.has("fruit") else "fish" if stash.has("fish") else ""
		if not kind.is_empty(): stash.erase(kind)
		return kind

	func arrange_stone() -> bool:
		if play_stage>=MAX_LIVING_STAGE: return false
		play_stage += 1
		return true

	func disturb_bed() -> bool:
		if bed_stage==0: return false
		bed_stage -= 1
		return true

class Tunnels extends RefCounted:
	var tunnels: Array = [{"cave":true}]

class ChunkEditor extends RefCounted:
	var data := Tunnels.new()

## The real cave with a fixed threshold: a straight walk to the mouth, then a
## short interior path to the chamber.
class HomeCave extends "res://scripts/bigfoot_cave.gd":
	const ENTRANCE := Vector3.ZERO
	const CHAMBER := Vector3(0,0,-2.5)
	func plan(_item: Dictionary) -> Dictionary:
		return {"entrance":ENTRANCE,"chamber":CHAMBER,"path":scene.navigation.path(scene.creature.position,ENTRANCE),"interior":PackedVector3Array([CHAMBER])}

## Every choice he completes, stamped with the absolute world hour.
class WeekLiving extends "res://scripts/bigfoot_living_world.gd":
	var timeline: Array[Dictionary] = []
	func _complete(kind: String) -> void:
		var world: WorldClock = scene.world_clock
		timeline.append({"kind":kind,"hour":world.day*24.0+world.hour})
		super(kind)

## The foraging owner's contract: carry the item into the cave and commit it to
## the lair on entry, before the living controller hears about the visit.
class Foraging extends RefCounted:
	signal delivered(kind: String, source_id: String)
	var routine: Node
	var scene: Node
	var kind := ""
	var source_id := ""
	var release_source := Callable()
	var commit_source := Callable()

	func setup(owner_routine: Node) -> void:
		routine = owner_routine
		scene = routine.scene
		routine.cave.entry_completed.connect(_cave_entry_completed)
		routine.cave.cancelled.connect(_cave_cancelled)

	func carrying() -> bool: return not kind.is_empty()

	func begin(item_kind: String, item_id: String, release: Callable, commit: Callable) -> bool:
		if carrying() or not scene.creature.can_roam(): return false
		kind = item_kind
		source_id = item_id
		release_source = release
		commit_source = commit
		var previous_active: String = routine.active
		var previous_target: Dictionary = routine.target
		var previous_phase: String = routine._phase
		routine.active = "forage"
		routine.target = {"id":item_id}
		routine._phase = "carry_home"
		if routine.cave.request("forage"): return true
		_clear()
		routine.active = previous_active
		routine.target = previous_target
		routine._phase = previous_phase
		return false

	func cancel() -> void:
		if carrying(): _cancel_source()

	func _cave_entry_completed(reason: String) -> void:
		if reason!="forage" or not carrying(): return
		var accepted: bool = scene.lair.receive_item_checked(kind,commit_source) if commit_source.is_valid() else scene.lair.receive_item(kind)
		if not accepted:
			_cancel_source()
			return
		routine.history.append(kind)
		delivered.emit(kind,source_id)
		_clear()
		routine.active = ""
		routine.target = {}
		routine._phase = ""

	func _cave_cancelled(reason: String) -> void:
		if reason=="forage" and carrying(): _cancel_source()

	func _cancel_source() -> void:
		if release_source.is_valid(): release_source.call()
		_clear()
		if routine.active=="forage":
			routine.active = ""
			routine.target = {}
			routine._phase = ""

	func _clear() -> void:
		kind = ""
		source_id = ""
		release_source = Callable()
		commit_source = Callable()

## The routine's ownership seam and decision cadence, with its fish and tree
## trips reduced to walk, sit, and hand the catch to foraging.
class Routine extends Node:
	var cave = HomeCave.new()
	var foraging = Foraging.new()
	var living = WeekLiving.new()
	var scene: Node
	var active := ""
	var target := {}
	var _phase := ""
	var _clock := 0.0
	var _next_action := 8.0
	var _elapsed := 0.0
	var _payload := {}
	var history: Array[String] = []

	func setup(owner_scene: Node) -> void:
		scene = owner_scene
		cave.setup(scene)
		foraging.setup(self)
		living.setup(self)
		scene.creature.action_finished.connect(_action_finished)

	func _rest_stance(_point: Vector3) -> bool: return true

	func advance(delta: float) -> bool:
		var dt := minf(delta,0.05)
		_clock += dt
		if living.advance(dt): return true
		if cave.advance(dt): return true
		if not active.is_empty():
			_elapsed += dt
			if _phase=="approach":
				if _elapsed>30.0: cancel("target changed or approach timeout")
				elif scene.creature.walk_step(target.position,0.85,dt):
					scene.creature.stop_walking()
					_phase = "perform"
					scene.creature.perform_action("SitDown")
			return true
		if _clock<_next_action or not scene.creature.can_roam(): return false
		if not scene.brain.ready_for_activity(dt): return false
		if not living.choose(): _next_action = _clock+3.0
		return not living.current.is_empty()

	func request(kind: String, chosen: Dictionary = {}, _invited := false) -> bool:
		if not cave.phase.is_empty(): return false
		if kind in ["sleep","hibernate"] and cave.request(kind): return true
		if not active.is_empty() or not scene.creature.can_roam(): return false
		match kind:
			"fish":
				var targets: Array = scene.fish.available_targets()
				if chosen.is_empty() and targets.is_empty(): return false
				target = (chosen if not chosen.is_empty() else targets[0]).duplicate(true)
				scene.fish.reserve_target(str(target.id))
			"tree":
				if chosen.is_empty(): return false
				target = chosen.duplicate(true)
			_: return false
		active = kind
		_phase = "approach"
		_elapsed = 0.0
		return true

	func _action_finished(clip: String, cancelled: bool) -> void:
		if active not in ["fish","tree"] or _phase!="perform": return
		if cancelled:
			_finish()
			return
		if clip=="SitDown":
			scene.creature.perform_action("Sit",4.0)
			return
		if clip=="Sit":
			if active=="fish": _payload = scene.fish.catch_for_carry(str(target.id))
			scene.creature.perform_action("StandUp")
			return
		if active=="fish":
			scene.fish.reserve_target(str(target.id),false)
			if not _payload.is_empty() and foraging.begin("fish",str(_payload.source_id),_payload.release,_payload.commit):
				_payload = {}
				return
		elif foraging.begin("branch",str(target.get("id","tree")),Callable(),Callable()): return
		history.append(active)
		_finish()

	func cancel(_reason := "") -> void:
		living.cancel()
		cave.cancel()
		foraging.cancel()
		if scene.creature.state==CreatureActor.State.ACTION: scene.creature.cancel_action()
		_finish()

	func _finish() -> void:
		if active=="fish" and not target.is_empty(): scene.fish.reserve_target(str(target.id),false)
		if not _payload.is_empty(): _payload.release.call()
		_payload = {}
		active = ""
		target = {}
		_phase = ""
		scene.creature.stop_walking()
		_next_action = _clock+9.0

class Scene extends Node:
	var creature := Creature.new()
	var navigation := Walkable.new()
	var brain := Brain.new()
	var habitat := Habitat.new()
	var lair := Lair.new()
	var routine := Routine.new()
	var world_clock := WorldClock.new()
	var _precipitation := Weather.new()
	var _chunk_editor := ChunkEditor.new()
	var fish: Node3D

## Starts at midnight on day 0, the same origin tools/simulate_weather.gd uses,
## so a seed here shows the week that tool prints. `bed` seeds the bed stage.
func _init(tree_root: Node, weather_seed: int, bed := 0) -> void:
	scene = Scene.new()
	tree_root.add_child(scene)
	for node: Node in [scene.creature,scene.lair,scene.routine]: scene.add_child(node)
	clock = scene.world_clock
	clock.set_time(0,0.0)
	scene.creature.position = CAVE_ENTRANCE+Vector3(0,0,1.5)
	var pond: Node3D = Fish.new()
	pond.scene = scene
	scene.add_child(pond)
	var homes: Array[Vector3] = []
	for i in range(4): homes.append(POND+Vector3(float(i)-1.5,0,0))
	pond.seed_homes(homes)
	scene.fish = pond
	pond.advance(0.0)
	for i in range(TREES.size()): scene.habitat.interests.append({"id":"tree:%d" % i,"kind":"tree","position":TREES[i]})
	scene.lair.bed_stage = bed
	scene.routine.setup(scene)
	living = scene.routine.living
	living.enabled = true
	scene.routine._next_action = scene.routine._clock+3.0
	scheduler = WeatherScheduler.new(weather_seed,"clear",0.0)
	scheduler.enabled = true
	scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"))
	scene._precipitation.state = scene._precipitation.target

func hour() -> float:
	return clock.day*24.0+clock.hour

## Whole world days at speed 1, one resident step at a time.
func run(days: float) -> void:
	for i in range(roundi(days*clock.day_length/DT)): _step()

func _step() -> void:
	clock.advance(DT,false)
	var now := hour()
	for preset in scheduler.advance(now): scene._precipitation.set_weather(WeatherScheduler.preset_index(preset))
	scene._precipitation.advance(DT)
	scene.fish.advance(DT)
	scene.creature.tick(DT)
	scene.routine.advance(DT)
	_record(now)

func _record(now: float) -> void:
	var span := maxf(0.0,now-_last_hour)
	_last_hour = now
	if scene.lair.food_count()==0:
		_empty_hours += span
		longest_empty_food_hours = maxf(longest_empty_food_hours,_empty_hours)
	else: _empty_hours = 0.0
	var storming := scheduler.current=="storm"
	if storming:
		storm_hours += span
		if living.sheltered(): sheltered_storm_hours += span
		else:
			var doing: String = living.current if not living.current.is_empty() else scene.routine.active if not scene.routine.active.is_empty() else "cave "+scene.routine.cave.reason if not scene.routine.cave.phase.is_empty() else "idle"
			exposed_storm_hours[doing] = float(exposed_storm_hours.get(doing,0.0))+span
		if not _storming: storms.append({"from":now,"to":now,"bed_before":scene.lair.bed_stage,"bed_after":scene.lair.bed_stage})
		storms[-1].to = now
		storms[-1].bed_after = scene.lair.bed_stage
	_storming = storming

## World hours at which he completed any of these choices.
func completed(kinds: Array) -> Array[float]:
	var hours: Array[float] = []
	for entry: Dictionary in living.timeline:
		if entry.kind in kinds: hours.append(float(entry.hour))
	return hours

func dispose() -> void:
	scene.free()
