extends SceneTree
const Plate = preload("res://scripts/plate.gd")
const NAV = preload("res://scripts/creature_navigation.gd")
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	data.reset_flat()
	var nav := NAV.new()
	var wall := func(p: Vector3) -> bool: return not (absf(p.x)<0.75 and absf(p.z)<3.0)
	nav.rebuild(data,wall)
	check(nav._nodes.size() <= 1681,"Navigation graph remains bounded")
	var began := Time.get_ticks_usec()
	var route := nav.path(Vector3(-3,0,0),Vector3(3,0,0))
	var route_usec := Time.get_ticks_usec()-began
	check(route.size()>2,"Route detours around solid wall")
	for i in range(route.size()-1): check(nav.segment_safe(route[i],route[i+1]),"Every returned leg clears geometry")
	check(not nav.segment_safe(Vector3(-3,0,0),Vector3(3,0,0)),"Straight segment cannot cross wall")
	check(not nav.is_safe(Vector3(13.8,0,0)),"Capsule keeps away from chunk edge")
	check(nav.nearest_safe(Vector3(20,0,0)) != null,"Outside click can resolve to a safe edge destination")
	nav.rebuild(data,func(p: Vector3) -> bool: return absf(p.x)>0.75)
	check(nav.path(Vector3(-3,0,0),Vector3(3,0,0)).is_empty(),"A complete wall has no route")
	# A diagonal-only corner connection must not be treated as a doorway.
	nav.rebuild(data,func(p: Vector3) -> bool: return p.x*p.z > 0.01)
	check(nav.path(Vector3(-2,0,-2),Vector3(2,0,2)).is_empty(),"No diagonal corner cutting")
	# An obstacle narrower than the cell spacing can leave both endpoint nodes
	# safe. Candidate-edge validation must reject it and reroute, not tunnel.
	nav.rebuild(data,func(p: Vector3) -> bool: return not (p.x>0.2 and p.x<0.55 and absf(p.z)<2.0))
	var thin_route := nav.path(Vector3(-2.1,0,0),Vector3(2.1,0,0))
	check(thin_route.size()>2,"Subcell obstacle causes an alternative route")
	for i in range(thin_route.size()-1): check(nav.segment_safe(thin_route[i],thin_route[i+1]),"Lazy candidate validation never returns an unsafe edge")
	# The old 20 cm samples skipped this sliver and allowed the moving actor
	# to enter an unsafe point from which all future routes were rejected.
	nav.rebuild(data,func(p: Vector3) -> bool: return not (p.x>0.085 and p.x<0.125 and absf(p.z)<2.0))
	check(not nav.segment_safe(Vector3.ZERO,Vector3(1,0,0)),"Swept checks detect hazards between old coarse samples")
	data.streams = [{"pts":[{"x":0.0,"z":-Plate.HALF,"h":0.0},{"x":0.0,"z":Plate.HALF,"h":0.0}],"width":1.0,"depth":0.1,"surface":0.1,"capHead":false,"capTail":false}]
	nav.rebuild(data,Callable())
	check(not nav.is_safe(Vector3.ZERO),"Flowing stream excludes the creature footprint")
	check(nav.path(Vector3(-3,0,0),Vector3(3,0,0)).is_empty(),"Cannot route across a full-width stream")
	data.streams.clear()
	# Real native basin/pond polygons are prepared once per rebuild.
	for i in range(data.points.size()):
		data.heights[i] = -1.0*(1.0-smoothstep(0.0,3.5,data.points[i].length()))
	check(data.add_pond(Vector2.ZERO,-0.2),"Pond test fixture is bounded")
	nav.rebuild(data,Callable())
	check(not nav.is_safe(Vector3(0,data.ground_height(Vector2.ZERO),0)),"Submerged pond floor is unwalkable")
	data.reset_flat()
	for i in range(data.points.size()): data.heights[i] = data.points[i].x*1.0
	nav.rebuild(data,Callable())
	check(not nav.is_safe(Vector3.ZERO),"Steep hillside rejected by footprint slope test")
	data.reset_flat()
	nav.rebuild(data,Callable())
	check(nav.path(Vector3(-3,0,0),Vector3(3,0,0)).size()==2,"Terrain edits invalidate prior obstacles/slopes after rebuild")
	check(nav.path(Vector3(NAN,0,0),Vector3.ZERO).is_empty(),"Invalid coordinates cannot enter path search")
	print("Navigation flat rebuild: %s ms; detour search: %s ms; nodes: %s" % [nav.last_rebuild_usec/1000.0,route_usec/1000.0,nav._nodes.size()])
	var collisions = preload("res://scripts/native_play_collisions.gd").new()
	root.add_child(collisions)
	data.place("rock",Vector2.ZERO,0,2.0)
	collisions.rebuild(data)
	await physics_frame
	await physics_frame
	nav.rebuild(data,collisions.can_stand)
	var actual_began := Time.get_ticks_usec()
	var physical_route := nav.path(Vector3(-3,0,0),Vector3(3,0,0))
	var actual_route_usec := Time.get_ticks_usec()-actual_began
	check(physical_route.size()>2,"Real physics clearance routes around rock")
	for i in range(physical_route.size()-1): check(nav.segment_safe(physical_route[i],physical_route[i+1]),"Physical route clears collider")
	print("Navigation physical rebuild: %s ms; rock detour: %s ms" % [nav.last_rebuild_usec/1000.0,actual_route_usec/1000.0])
	collisions.queue_free()
	await process_frame
	print("PASS: bounded creature navigation, detours, barriers, water, slopes and edited terrain" if failures == 0 else "FAIL: creature navigation")
	quit(1 if failures else 0)
