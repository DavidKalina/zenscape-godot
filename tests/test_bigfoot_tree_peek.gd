extends SceneTree
## Independently skin actual head vertices; never consult the runtime guard proxy.
const Fixture = preload("res://tests/test_bigfoot_environment.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		failures += 1
		push_error(message)

func bone_point(actor: CreatureActor, name: String) -> Vector3:
	return actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(name)).origin)

func head_data(actor: CreatureActor) -> Dictionary:
	for mesh: MeshInstance3D in actor.actor.find_children("*","MeshInstance3D",true,false):
		if "_n5_" not in mesh.name: continue
		var vertices := PackedVector3Array()
		var influences: Array = []
		var skin: Skin = mesh.skin
		check(skin != null,"Head mesh exposes imported skin binds")
		if skin == null: return {}
		var bones: Array[int] = []
		var binds: Array[Transform3D] = []
		for bind in range(skin.get_bind_count()):
			var name := skin.get_bind_name(bind)
			var bone := actor.skeleton.find_bone(name) if not name.is_empty() else skin.get_bind_bone(bind)
			bones.append(bone)
			binds.append(skin.get_bind_pose(bind))
		var rigid_head := true
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var count := indices.size()/points.size()
			for vertex in range(points.size()):
				vertices.append(points[vertex])
				var active: Array = []
				var total := 0.0
				for influence in range(count):
					var index := vertex*count+influence
					if weights[index]<0.000001: continue
					var bind: int = indices[index]
					active.append({"bone":bones[bind],"bind":binds[bind],"weight":weights[index]})
					total += weights[index]
					rigid_head = rigid_head and bones[bind]==actor.skeleton.find_bone("Head")
				if absf(total-1.0)>0.001: rigid_head = false
				influences.append(active)
		check(vertices.size()>20,"Actual head surface has enough vertices for clearance validation")
		check(rigid_head,"Imported head vertices are normalized and rigidly weighted to Head")
		var rest_error := 0.0
		for vertex in range(vertices.size()):
			var rest_point := Vector3.ZERO
			for influence: Dictionary in influences[vertex]:
				rest_point += (actor.skeleton.get_bone_global_rest(influence.bone)*influence.bind*vertices[vertex])*float(influence.weight)
			rest_error = maxf(rest_error,actor.skeleton.to_global(rest_point).distance_to(mesh.to_global(vertices[vertex])))
		check(rest_error<0.0001,"Independent skin bind transform reproduces imported mesh at skeleton rest")
		return {"vertices":vertices,"influences":influences}
	check(false,"Actual n5 head mesh exists")
	return {}

func skinned_points(actor: CreatureActor, data: Dictionary) -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in range(data.vertices.size()):
		var point := Vector3.ZERO
		for influence: Dictionary in data.influences[index]:
			point += (actor.skeleton.get_bone_global_pose(influence.bone)*influence.bind*data.vertices[index])*float(influence.weight)
		result.append(actor.skeleton.to_global(point))
	return result

func performance(radius: float, side: float) -> void:
	var world := Fixture.World.new()
	var life = Fixture.LIFE.new()
	root.add_child(world)
	for child in [world.creature,world.brain,world.routine,world._lightning,life]: world.add_child(child)
	var actor: CreatureActor = world.creature
	actor.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	actor.set_process(false)
	actor.reset_at(Vector3.ZERO)
	world.brain.setup(actor,world.navigation,Callable())
	life.setup(world)
	life.autonomous = false
	var center := Vector3(0,0,radius+0.64)
	var bounds := AABB(center+Vector3(-radius,0,-radius),Vector3(radius*2,4.4,radius*2))
	world.habitat.interests = [{"id":"peek-test","kind":"tree","position":center,"bounds":bounds}]
	life.active = "tree_hug"
	life.target = world.habitat.interests[0].duplicate()
	life.target.center = center
	life.target.radius = radius
	life.target.contact_height = 1.75
	life._look = center+Vector3.UP*1.9
	life._perform()
	life._peek_side = side
	life._peek_target = Vector3(side*2,2.5,8)
	var data := head_data(actor)
	if data.is_empty():
		world.free()
		return
	var feet := {"R":bone_point(actor,"Foot_R"),"L":bone_point(actor,"Foot_L")}
	var initial_root := actor.global_transform
	var locked := {}
	var minimum_clearance := INF
	var clearance_time := 0.0
	var max_foot_drift := 0.0
	var max_hand_drift := 0.0
	var hidden_x := 0.0
	var reveal_x := 0.0
	var retreat_x := 0.0
	var hidden_count := 0
	var reveal_count := 0
	var retreat_count := 0
	var samples := 0
	for frame in range(700):
		life.advance(1.0/60.0)
		actor.advance(1.0/60.0)
		if life.phase != "perform": break
		var normalized_time: float = actor._age/life._duration
		var canonical_time: float = normalized_time*life.TREE_HUG.DURATION
		var points := skinned_points(actor,data)
		var centroid := Vector3.ZERO
		for point in points:
			centroid += point
			if point.y<0 or point.y>4.4: continue
			var clearance := Vector2(point.x-center.x,point.z-center.z).length()-radius
			if clearance<minimum_clearance:
				minimum_clearance = clearance
				clearance_time = canonical_time
		centroid /= points.size()
		if canonical_time>2.30 and canonical_time<2.50:
			hidden_x += centroid.x*side
			hidden_count += 1
		if canonical_time>3.80 and canonical_time<4.60:
			reveal_x += centroid.x*side
			reveal_count += 1
		if canonical_time>6.00 and canonical_time<6.20:
			retreat_x += centroid.x*side
			retreat_count += 1
		for hand in ["R","L"]:
			max_foot_drift = maxf(max_foot_drift,bone_point(actor,"Foot_"+hand).distance_to(feet[hand]))
			# The right hand lingers through the full retreat; the left starts
			# its intentional release earlier and stops being a planted contact.
			var contact_end := 6.10 if hand=="R" else 5.55
			if canonical_time>2.65 and canonical_time<contact_end:
				var palm := actor.hand_position(hand)
				if not locked.has(hand): locked[hand] = palm
				max_hand_drift = maxf(max_hand_drift,palm.distance_to(locked[hand]))
		samples += 1
	var reveal := reveal_x/maxi(reveal_count,1)-hidden_x/maxi(hidden_count,1)
	var retreat := reveal_x/maxi(reveal_count,1)-retreat_x/maxi(retreat_count,1)
	print("PEEK GEOMETRY radius=",radius," side=",side," vertices=",data.vertices.size()," samples=",samples," minimum_head_clearance=",minimum_clearance," at=",clearance_time," reveal=",reveal," retreat=",retreat," hand_drift=",max_hand_drift," foot_drift=",max_foot_drift)
	check(samples>400 and minimum_clearance>=0.0,"Actual skinned head vertices never enter trunk through full peek performance")
	check(hidden_count>0 and reveal_count>0 and retreat_count>0 and reveal>0.12 and retreat>0.10,"Head deliberately reveals sideways and retreats behind cover")
	check(locked.size()==2 and max_hand_drift<0.025,"Both palms remain planted during hide, peek and retreat")
	check(max_foot_drift<0.005 and actor.global_transform.is_equal_approx(initial_root),"Peek leaves actual feet and actor root planted")
	world.free()

func run() -> void:
	for radius in [0.25,0.45]:
		for side in [-1.0,1.0]: performance(radius,side)
	print("BIGFOOT TREE PEEK: failures=",failures)
	await process_frame
	quit(1 if failures else 0)
