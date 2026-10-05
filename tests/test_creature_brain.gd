extends SceneTree
const Brain = preload("res://scripts/creature_brain.gd")
const Navigation = preload("res://scripts/creature_navigation.gd")
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0
var symbols: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
func _run() -> void:
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	data.reset_flat()
	var nav := Navigation.new()
	nav.rebuild(data,func(_point: Vector3) -> bool: return true)
	var actor := CreatureActor.new()
	root.add_child(actor)
	actor.setup("res://assets/models/zenscape-bigfoot-interactions.glb")
	actor.set_process(false)
	actor.set_physics_process(false)
	var brain := Brain.new()
	root.add_child(brain)
	var interests: Array = [{"id":"tree","position":Vector3(5,0,0),"kind":"tree"}]
	brain.setup(actor,nav,func() -> Array: return interests)
	brain.reaction.connect(func(symbol: String,_text: String) -> void: symbols.append(symbol))
	check(brain.investigate(Vector3(5,0,0),false,"tree"),"Curiosity finds a reachable approach")
	check(symbols.back()=="?","Curiosity shows question mark")
	var curious_time := travel_time(brain,actor)
	check(brain.phase==Brain.Phase.INSPECT,"Curious route ends in inspection")
	actor.reset_at(Vector3.ZERO)
	check(brain.investigate(Vector3(5,0,0),true,"tree"),"Excitement finds reachable approach")
	check(symbols.back()=="!","Excitement shows exclamation")
	var excited_time := travel_time(brain,actor)
	check(excited_time<curious_time*0.65,"Excited approach is materially quicker than curious approach")
	actor.reset_at(Vector3.ZERO)
	brain.investigate(Vector3(5,0,0),false,"tree")
	actor.pick_up()
	var held_position := actor.global_position
	for i in range(180):
		brain.advance(1.0/60.0)
		actor.advance(1.0/60.0)
	check(actor.global_position==held_position and actor.is_held(),"Roaming does not fight a held actor")
	actor.release_at(Vector3.ZERO)
	for i in range(500):
		await process_frame # Allow budgeted route work to resume, as in live play.
		actor.advance(1.0/60.0)
		brain.advance(1.0/60.0)
	check(actor.global_position.distance_to(Vector3.ZERO)>0.3,"Roaming resumes after safe drop")
	actor.reset_at(Vector3.ZERO)
	brain.investigate(Vector3(5,0,0),false,"tree")
	nav.rebuild(data,func(point: Vector3) -> bool: return point.x<1.0 or point.x>2.0)
	brain.world_changed()
	check(brain.phase==Brain.Phase.BLOCKED,"New solid barrier interrupts planned route")
	check(symbols.back()=="?","Blocked route has readable uncertainty")
	check(actor.state!=CreatureActor.State.WALKING,"Blocked actor stops walking immediately")
	nav.rebuild(data,func(_point: Vector3) -> bool: return true)
	actor.reset_at(Vector3.ZERO)
	brain.investigate(Vector3(5,0,0),false,"tree")
	interests[0].position = Vector3(5,0,2)
	brain.world_changed()
	check(brain._look_at==Vector3(5,0,2),"Moving an inspected object updates its target")
	interests.clear()
	brain.world_changed()
	check(brain.phase==Brain.Phase.REST and brain._route.is_empty(),"Deleting inspected object cancels stale route")
	interests.append({"id":"tree","position":Vector3(5,0,2),"kind":"tree"})
	brain.world_changed()
	check(brain._pending_interest.is_empty(),"Undo restoration respects existing interest cooldown")
	actor.pick_up()
	interests.append({"id":"new-rock","position":Vector3(3,0,2),"kind":"rock"})
	brain.world_changed()
	check(not brain._pending_interest.is_empty(),"New discovery can wait while held")
	interests.pop_back()
	brain.world_changed()
	check(brain._pending_interest.is_empty(),"Deleting pending discovery cancels stale held reaction")
	print("Creature brain: ",failures," failures; curious ",curious_time,"s excited ",excited_time,"s")
	quit(1 if failures else 0)
func travel_time(brain: Node,actor: Node) -> float:
	var time := 0.0
	for i in range(1200):
		brain.advance(1.0/60.0)
		actor.advance(1.0/60.0)
		time += 1.0/60.0
		if brain.phase==Brain.Phase.INSPECT: break
	return time
