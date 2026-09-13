extends Node
## A small environmental wish: see a quiet bank, wait for a route, remember
## only a completed rest. Existing routines own locomotion and interruptions.
var routine: Node
var destination: Variant = null
var travelling := false
var _next := 12.0
var _noticing := 0.0
var _planning := false
var _plan_serial := 0
var _planned := {}
var _plan_generation := -1
var last_query_peak_usec := 0
var last_query_slices := 0
var _marker := Label3D.new()

func setup(owner_routine: Node) -> void:
	routine = owner_routine
	_marker.text = "A quiet spot"
	_marker.font_size = 24
	_marker.pixel_size = 0.008
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.modulate = Color("ede3bf")
	_marker.no_depth_test = false
	_marker.hide()
	add_child(_marker)

func reset() -> void:
	_plan_serial += 1
	_planning = false
	_planned.clear()
	destination = null
	travelling = false
	_noticing = 0.0
	_next = routine._clock+12.0
	_marker.hide()

func interrupted() -> void:
	_plan_serial += 1
	_planning = false
	_planned.clear()
	travelling = false
	_noticing = 0.0
	_next = routine._clock+5.0

func rested(point: Vector3) -> void:
	if not travelling or destination == null or point.distance_to(destination)>0.2: return
	routine.habits.remember_outing(point)
	routine.scene.brain.reaction.emit("Lovely","A new favorite place" if routine.habits.outing_visits==1 else "Back at his favorite place")
	travelling = false
	destination = null
	_marker.hide()
	_next = routine._clock+75.0

func advance(dt: float) -> bool:
	var scene: Node = routine.scene
	if scene._paused or scene.navigation.rebuilding or not scene.creature.can_roam(): return false
	if _planning: return true
	if not _planned.is_empty():
		var plan: Dictionary = _planned
		_planned = {}
		if scene.navigation.generation == _plan_generation and destination != null and routine.request("sit",{"rest_point":destination,"stepping":plan}):
			travelling = true
			_marker.hide()
			return true
	if _noticing>0.0:
		_noticing -= dt
		scene.creature.track_gaze(destination+Vector3.UP*0.3)
		return true
	if routine._clock<_next: return false
	_next = routine._clock+8.0
	if destination != null and not _valid_spot(destination):
		destination = null
		_marker.hide()
	if destination == null:
		var favorite: Variant = routine.habits.preferred_outing()
		if favorite != null:
			if favorite.distance_to(scene.creature.position)<2.0: return false
			destination = favorite
		else:
			_prepare(true)
			return _planning or _noticing>0.0
	_prepare(false)
	return _planning or not _planned.is_empty()

func _prepare(discover: bool) -> void:
	var scene: Node = routine.scene
	var origin: Vector3 = scene.creature.position
	_plan_serial += 1
	var serial := _plan_serial
	_planning = true
	scene.brain.reset_behavior()
	scene.creature.stop_walking()
	var began: float = routine._clock
	var valid := func() -> bool:
		return serial == _plan_serial and not scene._paused and scene.creature.can_roam() and scene.creature.position.distance_to(origin)<0.02 and routine._clock-began<8.0
	var query = preload("res://scripts/creature_route_query.gd").new()
	query.setup(scene.navigation,get_tree(),valid)
	var spot: Variant = await _discover(query) if discover else destination
	if spot != null and query.current():
		var route: PackedVector3Array = await query.path(origin,spot)
		if discover:
			# Accessible scenery needs no player-built crossing. Discovering and
			# checking reachability share the same cancellable frame budget.
			if route.is_empty() and query.current():
				destination = spot
				_marker.position = destination+Vector3.UP*0.65
				_marker.show()
				scene.creature.notice(destination)
				scene.brain.reaction.emit("Over there…","A quiet spot on the other bank")
				_noticing = 2.5
		else:
			var plan := {"points":route,"hops":{}} if not route.is_empty() else {}
			if plan.is_empty() and query.current():
				var planner = preload("res://scripts/stepping_route.gd").new()
				plan = await planner.plan(scene.navigation,get_tree(),origin,spot,valid,query)
			if query.current():
				_planned = plan
				_plan_generation = scene.navigation.generation
	query.finish_slice()
	last_query_peak_usec = query.peak_slice_usec
	last_query_slices = query.slices
	if serial == _plan_serial: _planning = false

func _valid_spot(point: Vector3) -> bool:
	var ground: Variant = routine.scene.navigation._ground(point)
	return ground != null and ground.distance_to(point)<0.18 and routine._rest_stance(point)

func _discover(query: RefCounted) -> Variant:
	var scene: Node = routine.scene
	var origin: Vector3 = scene.creature.position
	if scene._chunk_editor.data.void_faces.is_empty() and not scene.navigation._courses.any(func(course: Dictionary) -> bool: return course.radius<=1.4 and is_finite(course.level)): return null
	var best: Variant = null
	var score := INF
	# First rank cheap geometric candidates, then test a bounded shortlist for
	# a full seated footprint. A nearby plant or scenic prop makes it a place.
	var candidates: Array[Dictionary] = []
	var nearby: Array[Dictionary] = []
	for interest: Dictionary in scene.habitat.interests:
		if not await query.checkpoint(): return null
		if interest.kind in ["tree","broadleaf","layered_tree","redwood","shrub","boulder_1","boulder_2","boulder_3","boulder_4","log"] and origin.distance_to(interest.position)<10.0:
			nearby.append(interest)
	if nearby.is_empty(): return null
	nearby.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return origin.distance_squared_to(a.position)<origin.distance_squared_to(b.position))
	if nearby.size()>64: nearby.resize(64)
	for point: Vector3 in scene.navigation._nodes:
		if not await query.checkpoint(): return null
		var distance := origin.distance_to(point)
		if distance<3.0 or distance>7.0 or not _across_gap(origin,point): continue
		var scenery := INF
		for interest: Dictionary in nearby:
			scenery = minf(scenery,point.distance_to(interest.position))
		if scenery<3.0: candidates.append({"point":point,"score":distance+absf(scenery-1.6)})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.score<b.score)
	for i in range(mini(12,candidates.size())):
		if not await query.checkpoint(): return null
		var item: Dictionary = candidates[i]
		if item.score<score and _valid_spot(item.point):
			best = item.point
			score = item.score
	return best

func _across_gap(a: Vector3, b: Vector3) -> bool:
	var data: NativeTerrainData = routine.scene._chunk_editor.data
	if not data.void_faces.is_empty():
		var genome: Dictionary = data._recipe.inland.genome
		var shape = preload("res://scripts/inland_genome.gd")
		var da: float = shape.chasm_distance(genome,Vector2(a.x,a.z))
		var db: float = shape.chasm_distance(genome,Vector2(b.x,b.z))
		if da*db<0.0 and absf(db)>float(genome.chasm.width)*0.5+1.75: return true
	for course: Dictionary in routine.scene.navigation._courses:
		if course.radius>1.4 or not is_finite(course.level): continue
		var bank := Vector2(b.x,b.z)
		if bank.distance_to(Geometry2D.get_closest_point_to_segment(bank,course.a,course.b))<course.radius+1.75: continue
		if Geometry2D.segment_intersects_segment(Vector2(a.x,a.z),Vector2(b.x,b.z),course.a,course.b) != null: return true
	return false
