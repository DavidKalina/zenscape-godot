extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var atmosphere = load("res://studies/atmosphere.gd").new()
	root.add_child(atmosphere)
	atmosphere.setup_wind_trails(func(_p: Vector2) -> float: return 0.0)
	var trails = atmosphere.wind_trails
	atmosphere.strength = 0.0
	atmosphere._air_strength = 0.0
	for i in range(120): atmosphere.advance(1.0/60.0,false)
	check(trails.parcels.is_empty(),"Calm weather creates no visible wind")
	atmosphere.strength = 1.2
	atmosphere._air_strength = 1.2
	for i in range(90): atmosphere.advance(1.0/60.0,false)
	check(not trails.parcels.is_empty(),"Weather spawns wind trails without any user gust")
	if not trails.parcels.is_empty():
		var parcel: Dictionary = trails.parcels[0]
		var pose: Transform3D = parcel.node.transform
		var position: Vector3 = parcel.node.position
		var clock: float = parcel.node.material_override.get_shader_parameter("clock")
		atmosphere.advance(10.0,true)
		check(parcel.node.position==position and parcel.node.material_override.get_shader_parameter("clock")==clock,"Pause freezes both drift and shader animation")
		# Changing terrain and wind may affect new wisps, but cannot translate
		# or rotate an already visible curve. Only its drawing clock advances.
		trails.ground_height = func(p: Vector2) -> float: return 4.0+sin(p.x)*3.0
		atmosphere.direction_angle += 90.0
		for i in range(60): atmosphere.advance(1.0/60.0,false)
		check(parcel.node.transform.is_equal_approx(pose),"Existing curve stays fixed over uneven terrain and changing wind")
		check(parcel.node.material_override.get_shader_parameter("clock")>clock,"Stroke continues drawing along the anchored curve")
	for i in range(3600):
		atmosphere.advance(1.0/60.0,false)
		check(trails.parcels.size()<=trails.CAPACITY,"Weather trail population stays bounded")
		if i%120==0: await process_frame
	for puff in atmosphere.puffs.parcels: check(puff.w==0.0,"Visual weather never injects physical gust events")
	atmosphere.strength = 0.0
	atmosphere._air_strength = 0.0
	for i in range(480): atmosphere.advance(1.0/60.0,false)
	await process_frame
	check(trails.parcels.is_empty() and trails.get_child_count()==0,"Returning to calm cleans up every trail")
	trails.ground_height = func(_p: Vector2) -> Variant: return null
	atmosphere.strength = 1.2
	atmosphere._air_strength = 1.2
	for i in range(120): atmosphere.advance(1.0/60.0,false)
	check(trails.parcels.is_empty(),"No trails are spawned over missing terrain")
	print("Weather wind trails: ",failures," failures")
	atmosphere.free()
	quit(1 if failures else 0)
