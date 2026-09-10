extends RefCounted
## Needs choose an activity; existing routines retain ownership of locomotion,
## source-backed gathering and cave thresholds. Only observed changes enter memory.
const Mind = preload("res://scripts/bigfoot_life_mind.gd")
## Two world hours of storm, or four of rain, cost the bed one stage. The
## accumulator never banks more than one pending stage plus change.
const STORM_HOURS_PER_STAGE := 2.0
const MAX_STORM_HOURS := 4.0
const MAX_WEATHER_STEP := 1.0
var mind = Mind.new()
var routine: Node
var scene: Node
var enabled := false
var current := ""
var phase := ""
var reason := "Taking in the forest"
var scores: Array[Dictionary] = []
var completed_actions: Array[String] = []
var _target: Dictionary = {}
var _curiosity: Dictionary = {}
var _path := PackedVector3Array()
var _index := 0
var _elapsed := 0.0
var _observe_in := 0.0
var _observed_home := false
var _observed_stash: Array = []
var _observed_bed := 0
var _observed_play := 0
var _committed := false
var _gesture := ""
var _food_visual: MeshInstance3D
var _failed_until := {}
var _home_check_due := 65.0
var _storm_hours := 0.0
var _weather_hour := -1.0

func setup(owner_routine: Node) -> void:
	routine = owner_routine
	scene = routine.scene
	routine.cave.entry_completed.connect(_entered)
	routine.cave.visit_finished.connect(_returned)
	routine.cave.cancelled.connect(func(_why: String) -> void: cancel())
	routine.foraging.delivered.connect(_delivered)
	scene.creature.action_finished.connect(_action_finished)

func available() -> bool:
	return is_instance_valid(scene.get("lair"))

## Needs keep time while another resident behavior owns movement or animation.
## The scene calls this only when it skips the routine's ordinary advance.
func advance_needs(delta: float) -> void:
	if not enabled or not is_finite(delta) or delta<=0.0: return
	var dt := clampf(delta,0.0,0.05)
	mind.advance(dt,routine.cave.concealed and routine.cave.reason in ["sleep","rain","snow","hibernate"],float(_observed_bed)/3.0,_daylight())
	_home_check_due = maxf(0.0,_home_check_due-dt)
	_weather_wears_the_bed()

## Called only by the unpaused, visible resident clock. Surface activities own
## this tick; interior gestures share it with the existing cave clock.
func advance(delta: float) -> bool:
	if not is_finite(delta) or delta<=0.0: return not current.is_empty() and phase in ["approach","notice","surface_perform","collect"]
	if not enabled and current.is_empty(): return false
	var dt := clampf(delta,0.0,0.05)
	advance_needs(dt)
	if not current.is_empty() and scene.creature.state in [CreatureActor.State.HELD,CreatureActor.State.STUMBLING,CreatureActor.State.WIND,CreatureActor.State.SWIMMING,CreatureActor.State.SHAKING]:
		cancel()
		return false
	if phase=="journey" and routine.active.is_empty() and routine.cave.phase.is_empty():
		# A refused grasp or an invalidated route finishes the old routine without
		# a delivery. Release the decision too, so it cannot own the actor forever.
		cancel()
	_observe_in -= dt
	if enabled and _observe_in<=0.0 and not routine.cave._inside:
		_observe_in = 1.0
		perceive()
	if phase in ["approach","notice"]:
		_advance_surface(dt)
		return not current.is_empty()
	if phase == "collect":
		if scene.creature.can_roam() and routine.foraging.collect_tree_material(_target): phase = "journey"
		else: cancel()
	if phase == "surface_perform":
		if current=="gather" and scene.creature.action_clip=="Sit":
			var t: float = scene.creature._age
			scene.creature.reach_hand(scene.creature.position+scene.creature.basis*Vector3(-0.5,0.15,0.65),sin(clampf(t/5.0,0.0,1.0)*PI))
		return true
	if phase == "interior_perform":
		_advance_gesture()
	return false

func choose() -> bool:
	if not enabled or not current.is_empty(): return false
	var context := _context()
	scores = mind.ranked(context)
	for option: Dictionary in scores:
		var kind := str(option.kind)
		if kind=="gather" and _material_count()>0: kind = "tend"
		if float(_failed_until.get(kind,0.0))>mind.elapsed: continue
		var chosen := _curiosity if kind=="investigate" else {}
		if request(kind,chosen):
			reason = str(option.reason)
			return true
		_failed_until[kind] = mind.elapsed+25.0
	return false

func _context() -> Dictionary:
	var has_home: bool = available() and not scene._chunk_editor.data.tunnels.is_empty()
	return {"home":has_home,"material_needed":_observed_bed<3,"food_count":_food_count(),
		"can_gather":has_home and (_material_count()>0 or (_observed_stash.size()<24 and not _material_targets().is_empty())),
		"can_fish":has_home and _observed_stash.size()<24 and not scene.fish.available_targets().is_empty(),
		"curiosity_target":not _curiosity.is_empty(),"target_id":str(_curiosity.get("id","")),
		"ritual_target":true,"home_check_due":_home_check_due<=0.0 or not _observed_home,
		"can_play":has_home and _observed_play<3,"comfort":float(_observed_bed)/3.0,
		"hour":_hour(),"daylight":_daylight(),"weather":_weather(),"wet":_wetness(),
		"sheltered":sheltered()}

## The world clock is optional; without it he lives in a permanent bright noon.
func _clock() -> Variant:
	return scene.get("world_clock") if scene != null else null

func _hour() -> float:
	var clock: Variant = _clock()
	if clock == null: return 12.0
	var value: Variant = clock.get("hour")
	return fposmod(float(value),24.0) if (value is float or value is int) and is_finite(float(value)) else 12.0

func _daylight() -> float:
	var clock: Variant = _clock()
	if clock == null: return 1.0
	var value: Variant = clock.get("daylight")
	return clampf(float(value),0.0,1.0) if (value is float or value is int) and is_finite(float(value)) else 1.0

## Weather is optional in the same way the clock is: a study without a sky lives
## in permanent clear, dry conditions and scores exactly as it always did.
func _precipitation() -> Variant:
	return scene.get("_precipitation") if scene != null else null

func _weather() -> String:
	var sky: Variant = _precipitation()
	if sky == null: return "clear"
	var index: Variant = sky.get("preset_index")
	if not (index is int or index is float) or not is_finite(float(index)): return "clear"
	var slot := int(index)
	var names: Array = WeatherScheduler.PRESET_NAMES
	return str(names[slot]) if slot>=0 and slot<names.size() else "clear"

func _wetness() -> float:
	var sky: Variant = _precipitation()
	if sky == null: return 0.0
	var surface: Variant = sky.get("surface_weather")
	if surface == null: return 0.0
	var value: Variant = surface.get("ground_wet")
	return clampf(float(value),0.0,1.0) if (value is float or value is int) and is_finite(float(value)) else 0.0

## Standing in his cave, not merely owning one.
func sheltered() -> bool:
	return routine != null and routine.cave != null and routine.cave.sheltered()

## Absolute world hours, so a saved and reopened garden keeps counting weather
## in world time rather than in the engine seconds the player happened to watch.
func _world_hour() -> float:
	var clock: Variant = _clock()
	if clock == null: return -1.0
	var day: Variant = clock.get("day")
	var hour: Variant = clock.get("hour")
	if not (day is int or day is float) or not (hour is float or hour is int): return -1.0
	if not is_finite(float(day)) or not is_finite(float(hour)): return -1.0
	return float(day)*24.0+float(hour)

## Rain and storms work the bedding loose while he is out. He is not told: the
## room simply changes, and he discovers it on his next observe_home().
func _weather_wears_the_bed() -> void:
	var now := _world_hour()
	if now<0.0:
		_weather_hour = -1.0
		return
	var previous := _weather_hour
	_weather_hour = now
	if previous<0.0 or now<=previous: return
	var span := minf(now-previous,MAX_WEATHER_STEP)
	if sheltered() or not available(): return
	var falling := 1.0 if _weather()=="storm" else (0.5 if _weather()=="rain" else 0.0)
	if falling<=0.0: return
	_storm_hours = minf(_storm_hours+span*falling,MAX_STORM_HOURS)
	while _storm_hours>=STORM_HOURS_PER_STAGE:
		_storm_hours -= STORM_HOURS_PER_STAGE
		if not scene.lair.disturb_bed():
			_storm_hours = 0.0
			return

## Explicit invitations and autonomous choices cross this same ownership seam.
func request(kind: String, target: Dictionary = {}) -> bool:
	if not current.is_empty() or not routine.active.is_empty() or not routine.cave.phase.is_empty() or not scene.creature.can_roam(): return false
	var environment: Variant = scene.get("environment_life")
	if environment != null and (environment.busy() or (environment.fire != null and environment.fire.busy())): return false
	var accepted := false
	match kind:
		"gather": accepted = available() and _request_gather(target)
		"fish": accepted = available() and routine.request("fish",target,true)
		"sleep": accepted = routine.cave.request("sleep")
		"tend","eat","check_home","play":
			if not available(): return false
			if kind=="tend" and (scene.lair.material_count()==0 or scene.lair.comfort()>=1.0): return false
			if kind=="eat" and scene.lair.food_count()==0: return false
			if kind=="play" and scene.lair.capture_living().play_stage>=3: return false
			accepted = routine.cave.request(kind)
		"investigate","ritual":
			accepted = _start_surface(kind,target)
	if not accepted: return false
	current = kind
	if phase.is_empty(): phase = "journey"
	_committed = false
	_target = target.duplicate(true) if kind not in ["investigate","ritual","gather"] else _target
	scene.brain.reset_behavior()
	reason = {"gather":"Gathering material for his bed","fish":"Finding a meal to bring home","sleep":"Returning home to rest","tend":"Making his bed comfortable","eat":"Having a meal at home","check_home":"Checking his familiar belongings","play":"Arranging his little stone collection","ritual":"Returning to a quiet spot","investigate":"Taking a cautious closer look"}.get(kind,kind)
	return true

func _material_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in scene.habitat.interests:
		if str(item.id).begins_with("mesh-8:") or str(item.id).begins_with("mesh-11:") or item.get("kind","") in ["tree","broadleaf","redwood","bigfoot_tree","layered_tree"]:
			result.append(item)
	return result

func _request_gather(target: Dictionary) -> bool:
	var candidates: Array = [target] if not target.is_empty() else _material_targets()
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return scene.creature.position.distance_squared_to(a.position)<scene.creature.position.distance_squared_to(b.position))
	for item: Dictionary in candidates:
		if scene.creature.position.distance_to(item.position)>11.0: continue
		# Imported trees retain the authored shake. Editable trees have a distinct
		# render/physics owner, so gather fallen material beside them instead.
		if not scene.has_method("resident_activity_owned") and not str(item.id).begins_with("object:"):
			if routine.request("tree",item): return true
		elif _start_surface("gather",item): return true
	return false

func _start_surface(kind: String, target: Dictionary) -> bool:
	var point: Variant = target.get("position")
	if kind in ["investigate","gather"]:
		if point==null: return false
		_path = scene.brain._approach_route(point)
		if kind=="gather" and not _path.is_empty() and not routine._rest_stance(_path[-1]): return false
	else:
		if point==null: point = mind.favorite_position("rest")
		if point!=null and (not scene.navigation.is_safe(point) or not routine._rest_stance(point)): point = null
		if point==null:
			for offset in [Vector3(2.5,0,1.5),Vector3(-2.5,0,1.5),Vector3(0,0,-3.0),Vector3.ZERO]:
				var candidate: Variant = scene.navigation.nearest_safe(scene.creature.position+offset)
				if candidate!=null and routine._rest_stance(candidate):
					point = candidate
					break
		if point==null: return false
		_path = scene.navigation.path(scene.creature.position,point)
	if _path.is_empty(): return false
	_target = target.duplicate(true)
	_target.position = point
	_index = 0
	_elapsed = 0.0
	phase = "approach"
	return true

func _advance_surface(dt: float) -> void:
	_elapsed += dt
	if _elapsed>60.0:
		cancel()
		return
	if phase=="notice":
		scene.creature.notice(_target.position+Vector3.UP*0.5)
		if _elapsed<2.0: return
		phase = "surface_perform"
		if not scene.creature.perform_action("SitDown" if current in ["ritual","gather"] else "Idle",-1.0 if current in ["ritual","gather"] else 4.0): cancel()
		return
	if not scene.creature.can_roam():
		cancel()
		return
	while _index<_path.size() and scene.creature.position.distance_to(_path[_index])<0.02: _index += 1
	if _index>=_path.size():
		scene.creature.stop_walking()
		if current=="investigate": mind.observe(str(_target.get("id","")),_target.position,str(_target.get("kind","object")))
		phase = "notice"
		_elapsed = 0.0
		scene.brain.reaction.emit("?" if current=="investigate" else "…",reason)
		return
	if not scene.navigation.motion_safe(scene.creature.position,_path[_index],scene.creature.walking_speed(0.65)*dt):
		cancel()
		return
	if scene.creature.walk_step(_path[_index],0.65,dt): _index += 1

func perceive() -> void:
	if routine.cave._inside: return
	var nearest := 49.0
	var found := {}
	for item: Dictionary in scene.habitat.interests:
		var distance: float = scene.creature.position.distance_squared_to(item.position)
		if distance>nearest or distance<0.5 or not _visible(item): continue
		var id := str(item.id)
		mind.observe(id,item.position,str(item.get("kind","object")))
		if mind.familiarity(id)>=0.75: continue
		nearest = distance
		found = item.duplicate(true)
	_curiosity = found

func _visible(item: Dictionary) -> bool:
	var eye: Vector3 = scene.creature.position+Vector3.UP*1.8
	var end: Vector3 = item.position+Vector3.UP*0.8
	for step in range(1,8):
		var p := eye.lerp(end,float(step)/8.0)
		var height: Variant = scene.habitat.ground_height(Vector2(p.x,p.z))
		if height==null or float(height)>p.y: return false
	for box: AABB in scene.habitat.solids:
		if box.has_point(end) or box.has_point(item.position): continue
		if box.intersects_segment(eye,end)!=null: return false
	return true

func observe_home() -> bool:
	if not available() or not routine.cave.concealed: return false
	var room: Dictionary = scene.lair.capture_living()
	var changed: bool = _observed_home and (_observed_stash!=scene.lair.stash or _observed_bed!=int(room.bed_stage) or _observed_play!=int(room.play_stage))
	if changed:
		mind.mark_disturbance(scene.creature.position)
		scene.brain.reaction.emit("?","Something at home has changed")
		reason = "His belongings look different"
	_remember_home()
	return changed

func _remember_home() -> void:
	if not available(): return
	_observed_home = true
	_observed_stash = scene.lair.stash.duplicate()
	var room: Dictionary = scene.lair.capture_living()
	_observed_bed = int(room.bed_stage)
	_observed_play = int(room.play_stage)
	_home_check_due = 90.0

func _entered(why: String) -> void:
	if not enabled and current.is_empty(): return
	var changed := observe_home()
	if why in ["tend","eat","check_home","play"]:
		_begin_gesture(why)
	elif why=="forage" and available():
		# Delivery is already committed by the foraging owner before this callback.
		if scene.lair.material_count()>0 and scene.lair.comfort()<1.0: _begin_gesture("tend")
		elif scene.lair.food_count()>0 and mind.hunger>0.45: _begin_gesture("eat")
		elif changed: _begin_gesture("check_home")

func _begin_gesture(kind: String) -> void:
	_gesture = kind
	phase = "interior_perform"
	_committed = false
	routine.cave.hold_departure = true
	scene.creature.rotation.y = 0.0
	if not scene.creature.perform_action("Idle" if kind=="check_home" else "SitDown",5.0 if kind=="check_home" else -1.0):
		cancel()

func _advance_gesture() -> void:
	var actor: CreatureActor = scene.creature
	var t: float = actor._age
	if _gesture=="check_home":
		actor.notice(scene.lair.to_global(scene.lair.supply_point()) if t<2.5 else scene.lair.bed.global_position)
		return
	if actor.action_clip!="Sit": return
	var contact: Vector3 = actor.position+actor.basis*Vector3(-0.5,0.2,0.65)
	if _gesture=="play": contact = scene.lair.to_global(scene.lair.play_point())
	if _gesture=="eat": contact = actor.position+actor.basis*Vector3(-0.16,1.28,0.4)
	actor.reach_hand(contact,smoothstep(0.0,0.7,t)*(1.0-smoothstep(3.0,4.0,t)))
	if t>=1.4 and not _committed:
		var success := false
		match _gesture:
			"tend": success = scene.lair.tend_bed()
			"play": success = scene.lair.arrange_stone()
			"eat":
				var food: String = scene.lair.eat_food()
				success = not food.is_empty()
				if success: _show_food(food)
		if success:
			_committed = true
			_complete(_gesture)
			_remember_home()
		else:
			cancel()
			return
	if is_instance_valid(_food_visual):
		_food_visual.global_position = actor.hand_position()
		if t>3.0: _clear_food()

func _show_food(kind: String) -> void:
	_clear_food()
	_food_visual = MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.16
	shape.height = 0.32
	shape.radial_segments = 6
	shape.rings = 3
	_food_visual.mesh = shape
	_food_visual.scale = Vector3(1.8,0.5,0.7) if kind=="fish" else Vector3.ONE
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("7eabb2") if kind=="fish" else Color("a36349")
	_food_visual.material_override = material
	routine.add_child(_food_visual)

func _action_finished(clip: String, cancelled: bool) -> void:
	if phase not in ["surface_perform","interior_perform"]: return
	if cancelled:
		cancel()
		return
	if clip=="SitDown":
		scene.creature.perform_action("Sit",5.0)
	elif clip=="Sit":
		scene.creature.clear_hand_targets()
		scene.creature.perform_action("StandUp")
	else:
		if phase=="surface_perform":
			if current=="gather": phase = "collect"
			else:
				_complete(current)
				_clear()
		else:
			if _gesture=="check_home":
				_complete("check_home")
				_remember_home()
			_clear_food()
			phase = "journey"
			_gesture = ""
			routine.cave.hold_departure = false

func _delivered(kind: String, _id: String) -> void:
	if not enabled and current.is_empty(): return
	# Account for our own incoming supply so its deposit is not an intrusion.
	if _observed_home: _observed_stash.append(kind)
	_complete("fish" if kind in ["fish","fruit"] else "gather")

func _returned(why: String) -> void:
	if not enabled and current.is_empty(): return
	if why in ["sleep","rain","snow","hibernate"]: _complete("sleep")
	_clear()

func _complete(kind: String) -> void:
	var context := {"target_id":str(_target.get("id","")),"position":_target.get("position",scene.creature.position),"ritual":"rest"}
	mind.completed("gather" if kind=="tend" else kind,context)
	completed_actions.append(kind)
	if completed_actions.size()>40: completed_actions.pop_front()
	if kind=="investigate": _curiosity.clear()
	routine._next_action = routine._clock+6.0

func cancel() -> void:
	# A source edit during a legacy grasp is protected by the routine owner.
	# An idle controller must not clear that owner's hand targets or movement.
	if current.is_empty() and phase.is_empty(): return
	var visiting: bool = not current.is_empty() and not routine.cave.phase.is_empty()
	var owned := phase in ["surface_perform","interior_perform"]
	if not current.is_empty(): _failed_until[current] = mind.elapsed+20.0
	_clear()
	if visiting: routine.cave.cancel()
	if owned and scene.creature.state==CreatureActor.State.ACTION: scene.creature.cancel_action()
	scene.creature.clear_hand_targets()

func _clear() -> void:
	current = ""
	phase = ""
	_gesture = ""
	_path.clear()
	_target.clear()
	routine.cave.hold_departure = false
	_clear_food()
	scene.creature.stop_walking()
	routine._next_action = routine._clock+6.0

func _clear_food() -> void:
	if is_instance_valid(_food_visual): _food_visual.queue_free()
	_food_visual = null

func _food_count() -> int:
	return _observed_stash.count("fruit")+_observed_stash.count("fish")

func _material_count() -> int:
	return _observed_stash.count("branch")+_observed_stash.count("leaves")

func capture() -> Dictionary:
	return {"version":1,"enabled":enabled,"mind":mind.capture(),"observed_home":_observed_home,"stash":_observed_stash.duplicate(),"bed":_observed_bed,"play":_observed_play,"check_in":_home_check_due,"storm_hours":_storm_hours}

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if value.get("version")!=1 or not value.get("enabled") is bool or not Mind.valid(value.get("mind")): return false
	if not value.get("observed_home") is bool or not value.get("stash") is Array or value.stash.size()>24: return false
	for item in value.stash:
		if item not in ["branch","leaves","fish","fruit"]: return false
	for key in ["bed","play"]:
		if not GardenData._integer(value.get(key)) or not GardenData._number(value[key],0,3): return false
	# Documents written before the weather could touch the bed carry no
	# accumulator; they resume with a dry slate rather than being rejected.
	if not GardenData._number(value.get("storm_hours",0.0),0,MAX_STORM_HOURS): return false
	return GardenData._number(value.get("check_in"),0,90)

func restore(value: Dictionary) -> void:
	if not valid(value): return
	cancel()
	mind.restore(value.get("mind",{}))
	enabled = value.get("enabled",false)
	_observed_home = value.get("observed_home",false)
	_observed_stash = value.get("stash",[]).duplicate()
	_observed_bed = int(value.get("bed",0))
	_observed_play = int(value.get("play",0))
	_home_check_due = float(value.get("check_in",65.0))
	_storm_hours = float(value.get("storm_hours",0.0))
	_weather_hour = -1.0
	_curiosity.clear()
	_failed_until.clear()
	completed_actions.clear()
