extends SceneTree
## Exercise the current diorama's configured brain, rather than library defaults.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
func run() -> void:
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.library_path = "/private/tmp/zs-deliberation-test"
	scene.recent_file = "/private/tmp/zs-deliberation-test/recent.cfg"
	root.add_child(scene)
	await process_frame
	scene.new_diorama()
	scene._paused = true
	check(scene.invite_bigfoot(Vector3.ZERO),"Flat world admits Bigfoot")
	var brain: CreatureBrain = scene.brain
	var actor: CreatureActor = scene.creature
	var walks: Array[float] = []
	var rests: Array[float] = []
	var walk_time := 0.0
	var rest_time := 0.0
	for frame in range(90*30):
		var moving := brain.phase == CreatureBrain.Phase.MOVE
		brain.advance(1.0/30.0)
		actor.advance(1.0/30.0)
		if brain.phase == CreatureBrain.Phase.MOVE:
			walk_time += 1.0/30.0
			if not moving and rest_time>0.0:
				rests.append(rest_time)
				rest_time = 0.0
		else:
			rest_time += 1.0/30.0
			if moving:
				walks.append(walk_time)
				walk_time = 0.0
	var average := 0.0
	for duration in walks: average += duration/maxi(1,walks.size())
	print("DELIBERATION walks=",walks," rests=",rests," average_walk_seconds=",average)
	check(walks.size()>=3,"Still explores multiple destinations")
	check(average>=6.0,"Open-ground walks average at least six seconds")
	for i in range(1,rests.size()): check(rests[i]>=4.0,"Arrival gets at least four seconds to observe")
	actor.reset_at(Vector3.ZERO)
	check(brain.investigate(Vector3(8,0,0)),"Start a committed journey")
	for i in range(40):
		brain.advance(1.0/30.0)
		actor.advance(1.0/30.0)
	var destination := brain._destination
	scene.routine._next_action = 0.0
	check(not scene.routine.advance(0.05) and scene.routine.active.is_empty(),"Automatic activity cannot interrupt a journey")
	var nearby: Array = [{"id":"new-tree","position":Vector3(0,0,4),"kind":"tree"}]
	brain.interest_provider = func() -> Array: return nearby
	brain.world_changed()
	brain.advance(0.05)
	check(brain._destination==destination and brain.phase==CreatureBrain.Phase.MOVE,"New scenery waits until the current journey finishes")
	brain.reset_behavior()
	brain._wait = 4.0
	check(not scene.routine.advance(0.05),"Automatic activity respects the observation pause")
	brain._wait = 0.02
	scene.routine._choice = 2
	check(scene.routine.advance(0.05) and scene.routine.active=="sit","Due activity starts after observing; it is not starved")
	scene.routine.cancel("test finished")
	var nav := CreatureNavigation.new()
	nav.rebuild(scene._chunk_editor.data,func(p: Vector3) -> bool: return Vector2(p.x,p.z).length()>2.2,0.35,0.3)
	var route := nav.path(Vector3(-6,0,-3),Vector3(6,0,3))
	print("DELIBERATION obstacle_route_points=",route.size())
	check(not route.is_empty() and route.size()<=6,"Obstacle route uses purposeful legs, not grid-cell turns")
	for i in range(1,route.size()): check(nav.segment_safe(route[i-1],route[i]),"Simplified route preserves swept clearance")
	if route.size()>1:
		nav.reject_segment(route[0],route[1])
		var recovered := nav.path(route[0],route[-1])
		check(not recovered.is_empty(),"Rejected shortcut retains a reachable grid route")
		for i in range(1,recovered.size()):
			check(recovered[i].distance_to(recovered[i-1])<0.7,"Recovery does not immediately retry a long rejected shortcut")
	check(not nav.motion_safe(Vector3(-2.3,0,0),Vector3(2.3,0,0),0.2),"Next-step safety catches entry into a thin obstacle")
	nav.rebuild(scene._chunk_editor.data,func(_p: Vector3) -> bool: return true,0.35,0.3)
	var off_grid := Vector3(0.12,0,0.13)
	var goal := Vector3(6,0,2)
	nav.reject_segment(off_grid,goal)
	var connected := nav.path(off_grid,goal)
	check(connected.size()>2,"Grid recovery connects a position between cells")
	if connected.size()>2:
		nav.reject_segment(connected[0],connected[1])
		var alternative := nav.path(off_grid,goal)
		check(alternative.size()>2 and alternative[1]!=connected[1],"Replanning avoids a rejected off-grid connector")
	scene.free()
	print("DELIBERATION failures=",failures)
	quit(1 if failures else 0)
