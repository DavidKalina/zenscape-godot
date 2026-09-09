extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var data := NativeTerrainData.new()
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.reset_flat()
	var nav := CreatureNavigation.new()
	var walls := [
		func(p: Vector3) -> bool: return not (absf(p.x)<0.75 and absf(p.z)<3.0),
		func(p: Vector3) -> bool: return absf(p.x)>0.75,
		func(p: Vector3) -> bool: return not (p.x>0.2 and p.x<0.55 and absf(p.z)<2.0)]
	for wall in walls:
		nav.rebuild(data,wall)
		var from := Vector3(-3,0,0)
		var to := Vector3(3,0,0)
		var expected := nav.path(from,to)
		# Use a fresh graph so this test also covers first-use edge validation.
		nav.rebuild(data,wall)
		var query := preload("res://scripts/creature_route_query.gd").new()
		query.setup(nav,self,func() -> bool: return true)
		var route: PackedVector3Array = await query.path(from,to)
		assert(route.is_empty() == expected.is_empty(),"Budgeted query preserves reachability")
		for i in range(route.size()-1): assert(nav.segment_safe(route[i],route[i+1]),"Every published leg clears the same obstacles")
	var habitat = preload("res://scripts/fidelity_habitat.gd").new()
	habitat.solids.assign([AABB(Vector3(-3,-1,-0.01),Vector3(6,3,0.02)),AABB(Vector3(-2.5,4,-2.5),Vector3(1,1,1)),AABB(Vector3(1.4,-1,-4),Vector3(0.2,8,8))])
	habitat._index_solids()
	for x in range(-25,26):
		for z in range(-25,26):
			for y in [-1.0,0.0,2.0,6.0]:
				var point := Vector3(x*0.2,y,z*0.2)
				var expected := true
				for box in habitat.solids:
					if point.y+2.8<box.position.y or point.y>box.end.y: continue
					if Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(0.5).has_point(Vector2(point.x,point.z)): expected = false
				assert(habitat.clear_at(point) == expected,"Spatial index preserves exact old clearance at boundaries and heights")
	print("PASS: budgeted routes, thin barriers, unreachable destinations and exact indexed clearance")
	quit()
